/**
 * Greeting Module
 * Main entry point for greeting functionality
 */

class GreetingService {
  constructor(config = {}) {
    this.supportedLanguages = config.languages || ['en', 'es', 'fr', 'de', 'zh', 'ja'];
    this.maxNameLength = config.maxNameLength || 100;
    this.greetings = {
      en: { morning: 'Good morning', afternoon: 'Good afternoon', evening: 'Good evening', default: 'Hello' },
      es: { morning: 'Buenos días', afternoon: 'Buenas tardes', evening: 'Buenas noches', default: 'Hola' },
      fr: { morning: 'Bonjour', afternoon: 'Bon après-midi', evening: 'Bonsoir', default: 'Bonjour' },
      de: { morning: 'Guten Morgen', afternoon: 'Guten Tag', evening: 'Guten Abend', default: 'Hallo' },
      zh: { morning: '早上好', afternoon: '下午好', evening: '晚上好', default: '你好' },
      ja: { morning: 'おはよう', afternoon: 'こんにちは', evening: 'こんばんは', default: 'こんにちは' }
    };
  }

  sanitizeInput(input) {
    if (typeof input !== 'string') {
      if (!input) return '';
      input = String(input);
    }

    if (input.trim().length === 0) return '';

    let sanitized = input;

    sanitized = sanitized
      .replace(/[<>]/g, '')
      .replace(/[;&|`$()\\]/g, '')
      .replace(/--/g, '')
      .replace(/DROP|DELETE|INSERT|UPDATE|SELECT|EXEC|UNION/gi, '')
      .replace(/\.\./g, '')
      .replace(/\0/g, '')
      .replace(/rm\s+-rf/gi, '')
      .replace(/on\w+\s*=/gi, '')
      .replace(/script|alert|eval|iframe/gi, '');

    sanitized = sanitized.trim().substring(0, this.maxNameLength);

    return sanitized.length > 0 ? sanitized : '';
  }

  getTimeOfDay(hour) {
    if (hour < 0 || hour > 23) return 'default';
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 18) return 'afternoon';
    if (hour >= 18 && hour < 22) return 'evening';
    return 'default';
  }

  greet(name = '', options = {}) {
    const { language = 'en', time = null, format = 'text' } = options;

    if (!this.supportedLanguages.includes(language)) {
      throw new Error(`Unsupported language: ${language}`);
    }

    const hour = time !== null ? time : new Date().getHours();
    const timeOfDay = this.getTimeOfDay(hour);

    const greeting = this.greetings[language][timeOfDay];

    if (format === 'html') {
      const escapedName = name ? this.escapeHtml(String(name).trim()) : '';
      const message = escapedName ? `${greeting}, ${escapedName}!` : `${greeting}!`;
      return `<p class="greeting">${message}</p>`;
    } else {
      const safeName = this.sanitizeInput(name);
      const message = safeName ? `${greeting}, ${safeName}!` : `${greeting}!`;

      if (format === 'json') {
        return { greeting: message, language, timeOfDay, timestamp: new Date().toISOString() };
      }
      return message;
    }
  }

  escapeHtml(text) {
    return text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }
}

module.exports = { GreetingService };
