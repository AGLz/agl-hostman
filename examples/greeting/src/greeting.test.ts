/**
 * Greeting Module Tests
 *
 * Comprehensive test suite for the Greeter class covering:
 * - All greeting styles
 * - Color options
 * - Custom messages and targets
 * - Edge cases and error handling
 */

import { Greeter, GreetingStyle } from './greeting';

describe('Greeter', () => {
  let greeter: Greeter;

  beforeEach(() => {
    greeter = new Greeter();
  });

  describe('Simple Style', () => {
    it('should output simple greeting', () => {
      const result = greeter.greet({ style: GreetingStyle.SIMPLE });
      expect(result).toContain('Hello');
      expect(result).toContain('!');
    });

    it('should include target when provided', () => {
      const result = greeter.greet({
        style: GreetingStyle.SIMPLE,
        target: 'World',
      });
      expect(result).toContain('Hello, World!');
    });

    it('should support custom message', () => {
      const result = greeter.greet({
        style: GreetingStyle.SIMPLE,
        message: 'Hi',
      });
      expect(result).toContain('Hi!');
    });

    it('should handle empty target gracefully', () => {
      const result = greeter.greet({
        style: GreetingStyle.SIMPLE,
        target: '',
      });
      expect(result).toBeTruthy();
    });
  });

  describe('Elaborate Style', () => {
    it('should output boxed greeting', () => {
      const result = greeter.greet({ style: GreetingStyle.ELABORATE });
      expect(result).toContain('GREETING SYSTEM');
      expect(result).toContain('Message:');
      expect(result).toContain('Style:');
    });

    it('should include custom message in box', () => {
      const result = greeter.greet({
        style: GreetingStyle.ELABORATE,
        message: 'Welcome',
      });
      expect(result).toContain('Welcome');
    });

    it('should display correct style name', () => {
      const result = greeter.greet({ style: GreetingStyle.ELABORATE });
      expect(result).toContain('Elaborate');
    });
  });

  describe('Artistic Style', () => {
    it('should output ASCII art greeting', () => {
      const result = greeter.greet({ style: GreetingStyle.ARTISTIC });
      // ASCII art characters for HELLO
      expect(result).toContain('██');
      expect(result).toContain('█');
      expect(result).toMatch(/\n.*\n.*\n.*\n.*\n/); // Multiple lines
    });

    it('should include target below ASCII art', () => {
      const result = greeter.greet({
        style: GreetingStyle.ARTISTIC,
        target: 'TestUser',
      });
      expect(result).toContain('TestUser');
    });

    it('should work without target', () => {
      const result = greeter.greet({
        style: GreetingStyle.ARTISTIC,
        useColors: false,
      });
      expect(result).toBeTruthy();
      expect(result.length).toBeGreaterThan(0);
    });
  });

  describe('Color Options', () => {
    it('should include ANSI colors when enabled', () => {
      const result = greeter.greet({
        style: GreetingStyle.SIMPLE,
        useColors: true,
      });
      expect(result).toContain('\x1b['); // ANSI escape sequence
    });

    it('should exclude colors when disabled', () => {
      const result = greeter.greet({
        style: GreetingStyle.SIMPLE,
        useColors: false,
      });
      expect(result).not.toContain('\x1b[');
    });

    it('should use colors by default', () => {
      const result = greeter.greet({ style: GreetingStyle.SIMPLE });
      expect(result).toContain('\x1b[');
    });
  });

  describe('Console Output', () => {
    it('should output to console without error', () => {
      const consoleSpy = jest.spyOn(console, 'log').mockImplementation();
      greeter.consoleGreet({ style: GreetingStyle.SIMPLE });
      expect(consoleSpy).toHaveBeenCalled();
      consoleSpy.mockRestore();
    });

    it('should pass through all options', () => {
      const consoleSpy = jest.spyOn(console, 'log').mockImplementation();
      greeter.consoleGreet({
        style: GreetingStyle.ELABORATE,
        target: 'Test',
        useColors: false,
      });
      expect(consoleSpy).toHaveBeenCalledWith(
        expect.stringContaining('Test')
      );
      consoleSpy.mockRestore();
    });
  });

  describe('Static Methods', () => {
    describe('getAvailableStyles', () => {
      it('should return all available styles', () => {
        const styles = Greeter.getAvailableStyles();
        expect(styles).toEqual([
          GreetingStyle.SIMPLE,
          GreetingStyle.ELABORATE,
          GreetingStyle.ARTISTIC,
        ]);
      });

      it('should return array of strings', () => {
        const styles = Greeter.getAvailableStyles();
        expect(styles).toHaveLength(3);
        expect(typeof styles[0]).toBe('string');
      });
    });

    describe('isValidStyle', () => {
      it('should validate correct styles', () => {
        expect(Greeter.isValidStyle('simple')).toBe(true);
        expect(Greeter.isValidStyle('elaborate')).toBe(true);
        expect(Greeter.isValidStyle('artistic')).toBe(true);
      });

      it('should reject invalid styles', () => {
        expect(Greeter.isValidStyle('invalid')).toBe(false);
        expect(Greeter.isValidStyle('')).toBe(false);
        expect(Greeter.isValidStyle('SIMPLE')).toBe(false); // Case sensitive
      });

      it('should act as type guard', () => {
        const style: string = 'simple';
        if (Greeter.isValidStyle(style)) {
          // TypeScript should know style is GreetingStyle here
          expect(style).toBe(GreetingStyle.SIMPLE);
        }
      });
    });
  });

  describe('Edge Cases', () => {
    it('should handle very long messages', () => {
      const longMessage = 'A'.repeat(1000);
      const result = greeter.greet({
        style: GreetingStyle.SIMPLE,
        message: longMessage,
      });
      expect(result).toContain(longMessage);
    });

    it('should handle special characters', () => {
      const result = greeter.greet({
        style: GreetingStyle.SIMPLE,
        message: 'Hello@#$%',
      });
      expect(result).toContain('Hello@#$%');
    });

    it('should handle unicode characters', () => {
      const result = greeter.greet({
        style: GreetingStyle.SIMPLE,
        message: '👋 Hello 🌍',
      });
      expect(result).toContain('👋');
      expect(result).toContain('🌍');
    });

    it('should handle null-like targets', () => {
      const result1 = greeter.greet({
        style: GreetingStyle.SIMPLE,
        target: undefined as any,
      });
      expect(result1).toContain('Hello!');

      const result2 = greeter.greet({
        style: GreetingStyle.SIMPLE,
        target: null as any,
      });
      expect(result2).toContain('Hello!');
    });
  });

  describe('Return Values', () => {
    it('should always return string', () => {
      const result = greeter.greet({ style: GreetingStyle.SIMPLE });
      expect(typeof result).toBe('string');
    });

    it('should return non-empty string', () => {
      const result = greeter.greet({ style: GreetingStyle.SIMPLE });
      expect(result.length).toBeGreaterThan(0);
    });

    it('should be consistent for same inputs', () => {
      const options = { style: GreetingStyle.SIMPLE, target: 'Test' };
      const result1 = greeter.greet(options);
      const result2 = greeter.greet(options);
      expect(result1).toBe(result2);
    });
  });

  describe('Integration Tests', () => {
    it('should handle all style combinations', () => {
      const styles = Greeter.getAvailableStyles();
      const targets = [undefined, 'World', 'Alice', 'Bob'];

      styles.forEach((style) => {
        targets.forEach((target) => {
          expect(() => {
            greeter.greet({ style, target });
          }).not.toThrow();
        });
      });
    });

    it('should work in batch operations', () => {
      const results: string[] = [];
      for (let i = 0; i < 100; i++) {
        results.push(greeter.greet({ style: GreetingStyle.SIMPLE }));
      }
      expect(results).toHaveLength(100);
      results.forEach((result) => {
        expect(result).toContain('Hello');
      });
    });
  });

  describe('Type Safety', () => {
    it('should enforce GreetingStyle enum', () => {
      // This test validates TypeScript compilation
      const validStyle: GreetingStyle = GreetingStyle.SIMPLE;
      expect(() => {
        greeter.greet({ style: validStyle });
      }).not.toThrow();
    });

    it('should accept partial options', () => {
      const partialOptions = { style: GreetingStyle.SIMPLE };
      expect(() => {
        greeter.greet(partialOptions);
      }).not.toThrow();
    });
  });
});
