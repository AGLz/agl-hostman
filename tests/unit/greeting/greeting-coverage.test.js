/**
 * Greeting Module Coverage Tests
 *
 * Tests the actual GreetingService from src/greeting/index.js
 * These tests directly import the module for proper coverage reporting
 */

const { GreetingService } = require('../../../src/greeting/index');

describe('Greeting Module - Coverage Tests', () => {
  let service;

  beforeEach(() => {
    service = new GreetingService();
  });

  describe('Coverage: Core Methods', () => {
    test('should greet with name', () => {
      const result = service.greet('Alice');
      expect(result).toContain('Alice');
    });

    test('should greet without name', () => {
      const result = service.greet();
      expect(result).toBeDefined();
    });

    test('should greet in Spanish', () => {
      const result = service.greet('Bob', { language: 'es', time: 10 });
      expect(result).toContain('Buenos días');
    });

    test('should return JSON format', () => {
      const result = service.greet('Charlie', { format: 'json' });
      expect(result).toHaveProperty('greeting');
      expect(result).toHaveProperty('language');
      expect(result).toHaveProperty('timestamp');
    });

    test('should return HTML format', () => {
      const result = service.greet('Diana', { format: 'html' });
      expect(result).toMatch(/<p class="greeting">/);
    });

    test('should sanitize input', () => {
      const result = service.greet('<script>alert("XSS")</script>');
      expect(result).not.toContain('<script>');
    });

    test('should escape HTML in HTML format', () => {
      const result = service.greet('<b>Bold</b>', { format: 'html' });
      expect(result).toContain('&lt;b&gt;');
    });

    test('should handle time of day', () => {
      expect(service.greet('Test', { time: 8 })).toContain('morning');
      expect(service.greet('Test', { time: 14 })).toContain('afternoon');
      expect(service.greet('Test', { time: 20 })).toContain('evening');
    });

    test('should throw on invalid language', () => {
      expect(() => service.greet('Test', { language: 'xx' })).toThrow();
    });

    test('should handle custom configuration', () => {
      const customService = new GreetingService({
        maxNameLength: 50,
        languages: ['en', 'es']
      });
      const result = customService.greet('Test');
      expect(result).toBeDefined();
    });

    test('getTimeOfDay should handle all hours', () => {
      expect(service.getTimeOfDay(4)).toBe('default');
      expect(service.getTimeOfDay(8)).toBe('morning');
      expect(service.getTimeOfDay(14)).toBe('afternoon');
      expect(service.getTimeOfDay(20)).toBe('evening');
      expect(service.getTimeOfDay(23)).toBe('default');
    });

    test('should handle null input', () => {
      expect(service.greet(null)).toBeDefined();
    });

    test('should handle undefined input', () => {
      expect(service.greet(undefined)).toBeDefined();
    });

    test('should handle number input', () => {
      expect(service.greet(123)).toBeDefined();
    });

    test('should truncate long names', () => {
      const longName = 'A'.repeat(200);
      const result = service.greet(longName);
      expect(result.length).toBeLessThan(120);
    });
  });
});
