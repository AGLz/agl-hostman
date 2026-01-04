/**
 * Memory Validation Utilities
 * Provides validation functions for memory coordination protocol testing
 */

export class MemoryValidator {
  constructor() {
    this.validationErrors = [];
    this.validationResults = [];
  }

  /**
   * Validate memory structure
   */
  validateMemoryStructure(memoryData) {
    const errors = [];

    if (!memoryData) {
      errors.push('Memory data is null or undefined');
      return { valid: false, errors };
    }

    // Check for required fields
    if (typeof memoryData !== 'object') {
      errors.push('Memory data must be an object');
      return { valid: false, errors };
    }

    // Validate action field
    if (!memoryData.action || !['store', 'retrieve', 'delete', 'search', 'list'].includes(memoryData.action)) {
      errors.push(`Invalid action: ${memoryData.action}`);
    }

    // Validate namespace
    if (!memoryData.namespace || memoryData.namespace !== 'coordination') {
      errors.push(`Invalid or missing namespace: ${memoryData.namespace}`);
    }

    // Validate key pattern
    if (!memoryData.key) {
      errors.push('Memory key is required');
    } else if (!this.isValidKeyPattern(memoryData.key)) {
      errors.push(`Invalid key pattern: ${memoryData.key}`);
    }

    // Validate value for store operations
    if (memoryData.action === 'store' && !memoryData.value) {
      errors.push('Value is required for store operations');
    }

    const valid = errors.length === 0;
    const result = { valid, errors, timestamp: Date.now() };

    this.validationResults.push(result);
    if (!valid) {
      this.validationErrors.push(...errors);
    }

    return result;
  }

  /**
   * Check if key follows swarm pattern
   */
  isValidKeyPattern(key) {
    // Valid patterns: swarm/[agent]/status|progress|waiting|complete
    // or swarm/shared/[component]
    const patterns = [
      /^swarm\/[\w-]+\/(status|progress|waiting|complete)$/,
      /^swarm\/shared\/[\w-]+$/
    ];
    return patterns.some(pattern => pattern.test(key));
  }

  /**
   * Validate agent status structure
   */
  validateAgentStatus(statusData) {
    const errors = [];
    const required = ['agent', 'status', 'timestamp'];

    for (const field of required) {
      if (!statusData[field]) {
        errors.push(`Missing required field: ${field}`);
      }
    }

    // Validate status values
    const validStatuses = ['starting', 'working', 'waiting', 'complete', 'error'];
    if (statusData.status && !validStatuses.includes(statusData.status)) {
      errors.push(`Invalid status: ${statusData.status}`);
    }

    // Validate timestamp
    if (statusData.timestamp && typeof statusData.timestamp !== 'number') {
      errors.push('Timestamp must be a number');
    }

    return {
      valid: errors.length === 0,
      errors,
      timestamp: Date.now()
    };
  }

  /**
   * Detect memory corruption
   */
  detectCorruption(memoryData, originalChecksum) {
    const currentChecksum = this.calculateChecksum(JSON.stringify(memoryData));
    const isCorrupted = currentChecksum !== originalChecksum;

    return {
      isCorrupted,
      checksum: currentChecksum,
      originalChecksum,
      timestamp: Date.now()
    };
  }

  /**
   * Calculate checksum for data integrity
   */
  calculateChecksum(data) {
    // Simple hash for demonstration
    let hash = 0;
    for (let i = 0; i < data.length; i++) {
      const char = data.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32-bit integer
    }
    return hash.toString(16);
  }

  /**
   * Validate namespace isolation
   */
  validateNamespaceIsolation(memories) {
    const namespaces = new Map();

    for (const memory of memories) {
      const ns = memory.namespace;
      if (!namespaces.has(ns)) {
        namespaces.set(ns, []);
      }
      namespaces.get(ns).push(memory.key);
    }

    // Check if coordination namespace is isolated
    const coordinationKeys = namespaces.get('coordination') || [];
    const otherNamespaces = Array.from(namespaces.keys()).filter(ns => ns !== 'coordination');

    const leaks = [];
    for (const ns of otherNamespaces) {
      const keys = namespaces.get(ns);
      for (const key of keys) {
        if (coordinationKeys.includes(key)) {
          leaks.push({ namespace: ns, key });
        }
      }
    }

    return {
      isolated: leaks.length === 0,
      leaks,
      totalNamespaces: namespaces.size,
      timestamp: Date.now()
    };
  }

  /**
   * Get validation report
   */
  getValidationReport() {
    return {
      totalValidations: this.validationResults.length,
      failedValidations: this.validationErrors.length,
      successRate: this.validationResults.length > 0
        ? ((this.validationResults.length - this.validationErrors.length) / this.validationResults.length * 100).toFixed(2) + '%'
        : 'N/A',
      recentErrors: this.validationErrors.slice(-10),
      timestamp: Date.now()
    };
  }

  /**
   * Clear validation history
   */
  clearHistory() {
    this.validationErrors = [];
    this.validationResults = [];
  }
}

export default MemoryValidator;
