/**
 * Greeting Module - Modular and extensible greeting system
 *
 * Provides multiple greeting formats with clean interfaces and proper error handling.
 * Follows SOLID principles and best practices for maintainable code.
 *
 * @module greeting
 * @version 1.0.0
 */

'use strict';

const { sanitizeInput } = require('./sanitizer');

/**
 * Configuration object for greeting behavior
 * @typedef {Object} GreetingConfig
 * @property {string} defaultMessage - Default greeting message
 * @property {boolean} includeTimestamp - Whether to include timestamp
 * @property {string} locale - Locale for internationalization
 */
const defaultConfig = {
  defaultMessage: 'hello',
  includeTimestamp: false,
  locale: 'en-US'
};

/**
 * Greeting result object
 * @typedef {Object} GreetingResult
 * @property {string} message - The greeting message
 * @property {string} format - Format type used
 * @property {Date} [timestamp] - Optional timestamp
 * @property {Object} [metadata] - Additional metadata
 */

/**
 * Simple greeting - Returns basic hello message
 *
 * @param {string} [message='hello'] - Custom message to return
 * @returns {GreetingResult} Simple greeting result
 * @example
 * const result = simpleGreeting();
 * console.log(result.message); // 'hello'
 */
function simpleGreeting(message = defaultConfig.defaultMessage) {
  if (typeof message !== 'string') {
    throw new TypeError('Message must be a string');
  }

  return {
    message: message.trim(),
    format: 'simple',
    timestamp: new Date()
  };
}

/**
 * Enhanced greeting - Returns greeting with additional context
 *
 * @param {Object} options - Greeting options
 * @param {string} [options.message='hello'] - Base message
 * @param {string} [options.recipient] - Optional recipient name
 * @param {boolean} [options.formal=false] - Use formal tone
 * @returns {GreetingResult} Enhanced greeting result
 * @example
 * const result = enhancedGreeting({ recipient: 'World', formal: true });
 * console.log(result.message); // 'Good day, World'
 */
function enhancedGreeting(options = {}) {
  const {
    message = defaultConfig.defaultMessage,
    recipient = null,
    formal = false
  } = options;

  let enhancedMessage = message;

  if (formal && message === 'hello') {
    enhancedMessage = 'Good day';
  }

  // Sanitize recipient input before using it
  const sanitizedRecipient = recipient ? sanitizeInput(recipient, { allowEmpty: true }) : null;

  if (sanitizedRecipient) {
    enhancedMessage = `${enhancedMessage}, ${sanitizedRecipient}`;
  }

  return {
    message: enhancedMessage,
    format: 'enhanced',
    timestamp: new Date(),
    metadata: {
      recipient: sanitizedRecipient,
      formal,
      hasRecipient: !!sanitizedRecipient
    }
  };
}

/**
 * Creative greeting - Returns contextual greeting based on time of day
 *
 * @param {Object} options - Greeting options
 * @param {string} [options.recipient] - Optional recipient name
 * @param {Date} [options.time=new Date()] - Time for context
 * @param {string} [options.style='friendly'] - Greeting style
 * @returns {GreetingResult} Creative greeting result
 * @example
 * const result = creativeGreeting({ recipient: 'Team', style: 'enthusiastic' });
 * console.log(result.message); // Time-appropriate greeting
 */
function creativeGreeting(options = {}) {
  const {
    recipient = null,
    time = new Date(),
    style = 'friendly'
  } = options;

  const hour = time.getHours();
  let baseGreeting;

  // Determine time-appropriate greeting
  if (hour >= 5 && hour < 12) {
    baseGreeting = 'Good morning';
  } else if (hour >= 12 && hour < 17) {
    baseGreeting = 'Good afternoon';
  } else if (hour >= 17 && hour < 22) {
    baseGreeting = 'Good evening';
  } else {
    baseGreeting = 'Hello';
  }

  // Apply style modifier
  const styleModifiers = {
    enthusiastic: '!',
    friendly: '',
    formal: '.',
    casual: ' 👋'
  };

  const modifier = styleModifiers[style] || '';
  let finalMessage = baseGreeting + modifier;

  // Sanitize recipient input before using it
  const sanitizedRecipient = recipient ? sanitizeInput(recipient, { allowEmpty: true }) : null;

  if (sanitizedRecipient) {
    finalMessage = `${baseGreeting}, ${sanitizedRecipient}${modifier}`;
  }

  return {
    message: finalMessage,
    format: 'creative',
    timestamp: time,
    metadata: {
      recipient: sanitizedRecipient,
      style,
      timeOfDay: hour < 12 ? 'morning' : hour < 17 ? 'afternoon' : 'evening',
      hasRecipient: !!sanitizedRecipient
    }
  };
}

/**
 * Greeting factory - Creates greeting based on format type
 *
 * @param {string} format - Format type ('simple', 'enhanced', 'creative')
 * @param {Object} [options={}] - Format-specific options
 * @returns {GreetingResult} Greeting result
 * @throws {Error} If format is not supported
 * @example
 * const result = greetingFactory('creative', { recipient: 'World' });
 */
function greetingFactory(format, options = {}) {
  const formatMap = {
    simple: (opts) => simpleGreeting(opts.message),
    enhanced: enhancedGreeting,
    creative: creativeGreeting
  };

  const greetingFunction = formatMap[format.toLowerCase()];

  if (!greetingFunction) {
    throw new Error(`Unsupported greeting format: ${format}. Supported formats: ${Object.keys(formatMap).join(', ')}`);
  }

  return greetingFunction(options);
}

/**
 * Batch greeting - Generate multiple greetings
 *
 * @param {Array<Object>} greetingConfigs - Array of greeting configurations
 * @returns {Array<GreetingResult>} Array of greeting results
 * @example
 * const results = batchGreeting([
 *   { format: 'simple' },
 *   { format: 'enhanced', options: { recipient: 'Team' } }
 * ]);
 */
function batchGreeting(greetingConfigs) {
  if (!Array.isArray(greetingConfigs)) {
    throw new TypeError('greetingConfigs must be an array');
  }

  return greetingConfigs.map(config => {
    const { format = 'simple', options = {} } = config;
    return greetingFactory(format, options);
  });
}

// Export public API
module.exports = {
  simpleGreeting,
  enhancedGreeting,
  creativeGreeting,
  greetingFactory,
  batchGreeting,
  defaultConfig
};
