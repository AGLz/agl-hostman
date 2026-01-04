/**
 * Safe Memory Operations Wrapper
 * Provides injection-safe memory operations with comprehensive validation
 *
 * Security Features:
 * - Input validation for all parameters
 * - Namespace whitelist enforcement
 * - Key sanitization (prevents path traversal and injection)
 * - Value size limits (prevents memory overflow)
 * - Rate limiting (prevents abuse)
 * - Comprehensive error handling and recovery
 */

import { memory_usage } from 'mcp__claude-flow-alpha';

/**
 * Configuration constants
 */
const CONFIG = {
  // Maximum size for JSON stringified values (1MB default)
  MAX_VALUE_SIZE: 1024 * 1024,

  // Rate limiting: max operations per minute
  MAX_OPS_PER_MINUTE: 100,

  // Allowed namespaces (whitelist approach)
  ALLOWED_NAMESPACES: new Set([
    'coordination',
    'session',
    'cache',
    'state',
    'config'
  ]),

  // Key pattern validation
  KEY_PATTERN: /^[a-zA-Z0-9_\-\/]+$/,

  // Max key length
  MAX_KEY_LENGTH: 256
};

/**
 * Rate limiter state
 */
const rateLimiter = new Map();

/**
 * Sanitizes a memory key to prevent injection attacks
 *
 * @param {string} key - The key to sanitize
 * @returns {object} { valid: boolean, sanitized: string|null, error: string|null }
 */
export function sanitizeKey(key) {
  if (typeof key !== 'string') {
    return { valid: false, sanitized: null, error: 'Key must be a string' };
  }

  if (key.length === 0) {
    return { valid: false, sanitized: null, error: 'Key cannot be empty' };
  }

  if (key.length > CONFIG.MAX_KEY_LENGTH) {
    return { valid: false, sanitized: null, error: `Key exceeds maximum length of ${CONFIG.MAX_KEY_LENGTH}` };
  }

  // Check for path traversal attempts
  if (key.includes('..') || key.includes('~')) {
    return { valid: false, sanitized: null, error: 'Key contains path traversal sequences' };
  }

  // Check for null bytes
  if (key.includes('\0')) {
    return { valid: false, sanitized: null, error: 'Key contains null bytes' };
  }

  // Validate against allowed pattern
  if (!CONFIG.KEY_PATTERN.test(key)) {
    return { valid: false, sanitized: null, error: 'Key contains invalid characters' };
  }

  return { valid: true, sanitized: key, error: null };
}

/**
 * Validates namespace against whitelist
 *
 * @param {string} namespace - The namespace to validate
 * @returns {object} { valid: boolean, error: string|null }
 */
export function validateNamespace(namespace) {
  if (typeof namespace !== 'string') {
    return { valid: false, error: 'Namespace must be a string' };
  }

  if (!CONFIG.ALLOWED_NAMESPACES.has(namespace)) {
    return {
      valid: false,
      error: `Namespace not allowed. Allowed: ${Array.from(CONFIG.ALLOWED_NAMESPACES).join(', ')}`
    };
  }

  return { valid: true, error: null };
}

/**
 * Validates value size
 *
 * @param {any} value - The value to validate
 * @returns {object} { valid: boolean, size: number, error: string|null }
 */
export function validateValueSize(value) {
  try {
    const serialized = JSON.stringify(value);
    const size = Buffer.byteLength(serialized, 'utf8');

    if (size > CONFIG.MAX_VALUE_SIZE) {
      return {
        valid: false,
        size,
        error: `Value exceeds maximum size of ${CONFIG.MAX_VALUE_SIZE} bytes`
      };
    }

    return { valid: true, size, error: null };
  } catch (error) {
    return { valid: false, size: 0, error: `Failed to serialize value: ${error.message}` };
  }
}

/**
 * Checks rate limit for a given key
 *
 * @param {string} identifier - Identifier for rate limiting (e.g., agent name)
 * @returns {object} { allowed: boolean, error: string|null }
 */
export function checkRateLimit(identifier) {
  const now = Date.now();
  const minute = 60 * 1000;

  // Clean old entries
  for (const [key, data] of rateLimiter.entries()) {
    if (now - data.timestamp > minute) {
      rateLimiter.delete(key);
    }
  }

  // Get or create rate limit entry
  let entry = rateLimiter.get(identifier);
  if (!entry || now - entry.timestamp > minute) {
    entry = { count: 0, timestamp: now };
    rateLimiter.set(identifier, entry);
  }

  // Check limit
  if (entry.count >= CONFIG.MAX_OPS_PER_MINUTE) {
    return {
      allowed: false,
      error: `Rate limit exceeded: ${CONFIG.MAX_OPS_PER_MINUTE} operations per minute`
    };
  }

  // Increment counter
  entry.count++;
  return { allowed: true, error: null };
}

/**
 * Comprehensive validation for memory operations
 *
 * @param {object} params - Parameters to validate
 * @returns {object} { valid: boolean, errors: string[] }
 */
export function validateMemoryParams(params) {
  const errors = [];

  // Validate action
  if (!params.action || typeof params.action !== 'string') {
    errors.push('Action is required and must be a string');
  } else if (
!['store', 'retrieve', 'delete', 'search', 'list'].includes(params.action)
) {
    errors.push(`Invalid action: ${params.action}. Must be one of: store, retrieve, delete, search, list`);
  }

  // Validate key
  if (params.action !== 'list' && params.action !== 'search') {
    if (!params.key) {
      errors.push('Key is required for this action');
    } else {
      const keyValidation = sanitizeKey(params.key);
      if (!keyValidation.valid) {
        errors.push(`Invalid key: ${keyValidation.error}`);
      }
    }
  }

  // Validate namespace
  if (params.action !== 'list') {
    if (!params.namespace) {
      errors.push('Namespace is required');
    } else {
      const nsValidation = validateNamespace(params.namespace);
      if (!nsValidation.valid) {
        errors.push(`Invalid namespace: ${nsValidation.error}`);
      }
    }
  }

  // Validate value for store action
  if (params.action === 'store' && params.value !== undefined) {
    const sizeValidation = validateValueSize(params.value);
    if (!sizeValidation.valid) {
      errors.push(`Invalid value: ${sizeValidation.error}`);
    }
  }

  return {
    valid: errors.length === 0,
    errors
  };
}

/**
 * Safe memory store operation
 *
 * @param {string} key - Memory key
 * @param {string} namespace - Memory namespace
 * @param {any} value - Value to store
 * @param {object} options - Additional options
 * @returns {Promise<object>} Result object
 */
export async function safeMemoryStore(key, namespace, value, options = {}) {
  const identifier = options.identifier || 'anonymous';

  // Check rate limit
  const rateLimit = checkRateLimit(identifier);
  if (!rateLimit.allowed) {
    throw new Error(`Rate limit error: ${rateLimit.error}`);
  }

  // Validate parameters
  const validation = validateMemoryParams({
    action: 'store',
    key,
    namespace,
    value
  });

  if (!validation.valid) {
    throw new Error(`Validation failed: ${validation.errors.join(', ')}`);
  }

  // Perform the operation
  try {
    const result = await memory_usage({
      action: 'store',
      key,
      namespace,
      value: typeof value === 'string' ? value : JSON.stringify(value),
      ttl: options.ttl
    });

    return {
      success: true,
      result,
      timestamp: Date.now()
    };
  } catch (error) {
    throw new Error(`Memory store failed: ${error.message}`);
  }
}

/**
 * Safe memory retrieve operation
 *
 * @param {string} key - Memory key
 * @param {string} namespace - Memory namespace
 * @param {object} options - Additional options
 * @returns {Promise<object>} Result object
 */
export async function safeMemoryRetrieve(key, namespace, options = {}) {
  const identifier = options.identifier || 'anonymous';

  // Check rate limit
  const rateLimit = checkRateLimit(identifier);
  if (!rateLimit.allowed) {
    throw new Error(`Rate limit error: ${rateLimit.error}`);
  }

  // Validate parameters
  const validation = validateMemoryParams({
    action: 'retrieve',
    key,
    namespace
  });

  if (!validation.valid) {
    throw new Error(`Validation failed: ${validation.errors.join(', ')}`);
  }

  // Perform the operation
  try {
    const result = await memory_usage({
      action: 'retrieve',
      key,
      namespace
    });

    // Try to parse JSON if possible
    let parsedResult = result;
    if (result && typeof result === 'string') {
      try {
        parsedResult = JSON.parse(result);
      } catch {
        // Not JSON, keep as string
        parsedResult = result;
      }
    }

    return {
      success: true,
      result: parsedResult,
      found: result !== null && result !== undefined,
      timestamp: Date.now()
    };
  } catch (error) {
    throw new Error(`Memory retrieve failed: ${error.message}`);
  }
}

/**
 * Safe memory delete operation
 *
 * @param {string} key - Memory key
 * @param {string} namespace - Memory namespace
 * @param {object} options - Additional options
 * @returns {Promise<object>} Result object
 */
export async function safeMemoryDelete(key, namespace, options = {}) {
  const identifier = options.identifier || 'anonymous';

  // Check rate limit
  const rateLimit = checkRateLimit(identifier);
  if (!rateLimit.allowed) {
    throw new Error(`Rate limit error: ${rateLimit.error}`);
  }

  // Validate parameters
  const validation = validateMemoryParams({
    action: 'delete',
    key,
    namespace
  });

  if (!validation.valid) {
    throw new Error(`Validation failed: ${validation.errors.join(', ')}`);
  }

  // Perform the operation
  try {
    const result = await memory_usage({
      action: 'delete',
      key,
      namespace
    });

    return {
      success: true,
      deleted: true,
      timestamp: Date.now()
    };
  } catch (error) {
    throw new Error(`Memory delete failed: ${error.message}`);
  }
}

/**
 * Safe memory search operation
 *
 * @param {string} pattern - Search pattern
 * @param {string} namespace - Memory namespace
 * @param {object} options - Additional options
 * @returns {Promise<object>} Result object
 */
export async function safeMemorySearch(pattern, namespace, options = {}) {
  const identifier = options.identifier || 'anonymous';

  // Check rate limit
  const rateLimit = checkRateLimit(identifier);
  if (!rateLimit.allowed) {
    throw new Error(`Rate limit error: ${rateLimit.error}`);
  }

  // Validate namespace (pattern can be flexible for search)
  const nsValidation = validateNamespace(namespace);
  if (!nsValidation.valid) {
    throw new Error(`Invalid namespace: ${nsValidation.error}`);
  }

  // Perform the operation
  try {
    const result = await memory_usage({
      action: 'search',
      pattern,
      namespace,
      limit: options.limit
    });

    return {
      success: true,
      results: result || [],
      count: Array.isArray(result) ? result.length : 0,
      timestamp: Date.now()
    };
  } catch (error) {
    throw new Error(`Memory search failed: ${error.message}`);
  }
}

/**
 * Safe memory list operation
 *
 * @param {string} namespace - Memory namespace
 * @param {object} options - Additional options
 * @returns {Promise<object>} Result object
 */
export async function safeMemoryList(namespace, options = {}) {
  const identifier = options.identifier || 'anonymous';

  // Check rate limit
  const rateLimit = checkRateLimit(identifier);
  if (!rateLimit.allowed) {
    throw new Error(`Rate limit error: ${rateLimit.error}`);
  }

  // Validate namespace
  const nsValidation = validateNamespace(namespace);
  if (!nsValidation.valid) {
    throw new Error(`Invalid namespace: ${nsValidation.error}`);
  }

  // Perform the operation
  try {
    const result = await memory_usage({
      action: 'list',
      namespace
    });

    return {
      success: true,
      keys: result || [],
      count: Array.isArray(result) ? result.length : 0,
      timestamp: Date.now()
    };
  } catch (error) {
    throw new Error(`Memory list failed: ${error.message}`);
  }
}

/**
 * Get rate limiter stats (for monitoring)
 *
 * @returns {object} Rate limiter statistics
 */
export function getRateLimiterStats() {
  return {
    totalTracked: rateLimiter.size,
    entries: Array.from(rateLimiter.entries()).map(([key, data]) => ({
      key,
      count: data.count,
      timestamp: data.timestamp,
      age: Date.now() - data.timestamp
    }))
  };
}

/**
 * Reset rate limiter (for testing/admin)
 *
 * @param {string} identifier - Optional specific identifier to reset
 */
export function resetRateLimiter(identifier = null) {
  if (identifier) {
    rateLimiter.delete(identifier);
  } else {
    rateLimiter.clear();
  }
}

export default {
  sanitizeKey,
  validateNamespace,
  validateValueSize,
  checkRateLimit,
  validateMemoryParams,
  safeMemoryStore,
  safeMemoryRetrieve,
  safeMemoryDelete,
  safeMemorySearch,
  safeMemoryList,
  getRateLimiterStats,
  resetRateLimiter,
  CONFIG
};
