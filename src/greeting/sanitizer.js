/**
 * Input Sanitization Module
 * Provides security utilities for sanitizing user inputs
 *
 * @module greeting/sanitizer
 * @version 1.0.0
 */

'use strict';

/**
 * HTML entity encoding map for XSS prevention
 */
const HTML_ENTITIES = {
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  '"': '&quot;',
  "'": '&#x27;',
  '/': '&#x2F;'
};

/**
 * Escapes HTML entities to prevent XSS attacks
 *
 * @param {string} str - String to escape
 * @returns {string} Escaped string
 */
function escapeHtml(str) {
  if (typeof str !== 'string') {
    return '';
  }
  return str.replace(/[&<>"'/]/g, (char) => HTML_ENTITIES[char] || char);
}

/**
 * Removes potentially dangerous characters for SQL/Command injection
 *
 * @param {string} str - String to sanitize
 * @returns {string} Sanitized string
 */
function sanitizeDangerousChars(str) {
  if (typeof str !== 'string') {
    return '';
  }

  // Remove SQL/command injection patterns
  return str
    .replace(/[;$`\\]/g, '') // Remove command injection chars
    .replace(/--/g, '')      // Remove SQL comment
    .replace(/DROP|DELETE|INSERT|UPDATE|SELECT|EXEC|UNION/gi, '') // Remove SQL keywords
    .replace(/\.\./g, '')    // Remove path traversal
    .replace(/\0/g, '');     // Remove null bytes
}

/**
 * Validates and sanitizes user input for greeting system
 *
 * @param {string} input - User input to sanitize
 * @param {Object} [options={}] - Sanitization options
 * @param {boolean} [options.allowEmpty=false] - Allow empty strings
 * @param {boolean} [options.htmlSafe=true] - Apply HTML escaping
 * @param {number} [options.maxLength=100] - Maximum length (0 = no limit)
 * @returns {string} Sanitized input
 */
function sanitizeInput(input, options = {}) {
  const {
    allowEmpty = false,
    htmlSafe = true,
    maxLength = 100
  } = options;

  // Handle non-string inputs
  if (typeof input !== 'string') {
    return allowEmpty ? '' : 'User';
  }

  // Trim whitespace
  let sanitized = input.trim();

  // Handle empty strings
  if (sanitized.length === 0) {
    return allowEmpty ? '' : 'User';
  }

  // Remove dangerous characters
  sanitized = sanitizeDangerousChars(sanitized);

  // Truncate if too long
  if (maxLength > 0 && sanitized.length > maxLength) {
    sanitized = sanitized.substring(0, maxLength);
  }

  // Apply HTML escaping if requested
  if (htmlSafe) {
    sanitized = escapeHtml(sanitized);
  }

  // Final check - if sanitization removed everything, return default
  return sanitized.length > 0 ? sanitized : (allowEmpty ? '' : 'User');
}

/**
 * Validates that input is safe for use in greetings
 *
 * @param {string} input - Input to validate
 * @returns {boolean} True if input is safe
 */
function isInputSafe(input) {
  if (typeof input !== 'string') {
    return false;
  }

  const dangerous = [
    /<script/i,
    /<img/i,
    /javascript:/i,
    /on\w+=/i,  // Event handlers (onclick, onerror, etc.)
    /;.*DROP/i,
    /\$\(.*\)/,  // Command substitution
    /\.\./,      // Path traversal
    /\0/         // Null bytes
  ];

  return !dangerous.some(pattern => pattern.test(input));
}

module.exports = {
  escapeHtml,
  sanitizeDangerousChars,
  sanitizeInput,
  isInputSafe
};
