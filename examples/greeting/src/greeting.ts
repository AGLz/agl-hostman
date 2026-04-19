/**
 * Greeting Module
 *
 * A flexible, well-structured utility for outputting greetings in multiple formats.
 * Supports simple, elaborate, and artistic styles with proper TypeScript typing.
 *
 * @module greeting
 * @author Hive Mind Coder Agent
 * @version 1.0.0
 * @license MIT
 */

/**
 * Supported greeting styles
 */
export enum GreetingStyle {
  /** Simple, straightforward output */
  SIMPLE = 'simple',
  /** Elaborate, descriptive output */
  ELABORATE = 'elaborate',
  /** Artistic, ASCII-art based output */
  ARTISTIC = 'artistic',
}

/**
 * Color codes for terminal output (ANSI escape sequences)
 */
const Colors = {
  RESET: '\x1b[0m',
  BRIGHT: '\x1b[1m',
  DIM: '\x1b[2m',
  RED: '\x1b[31m',
  GREEN: '\x1b[32m',
  YELLOW: '\x1b[33m',
  BLUE: '\x1b[34m',
  MAGENTA: '\x1b[35m',
  CYAN: '\x1b[36m',
  WHITE: '\x1b[37m',
} as const;

/**
 * Configuration options for greeting output
 */
export interface GreetingOptions {
  /** The style of greeting to output */
  style: GreetingStyle;
  /** Whether to use colors in output (default: true) */
  useColors?: boolean;
  /** Custom greeting message (default: "Hello") */
  message?: string;
  /** Target audience name (optional) */
  target?: string;
}

/**
 * Greeting class providing multiple output formats
 *
 * @example
 * ```typescript
 * const greeter = new Greeter();
 * greeter.greet({ style: GreetingStyle.SIMPLE });
 * greeter.greet({ style: GreetingStyle.ARTISTIC, target: 'World' });
 * ```
 */
export class Greeter {
  private readonly defaultOptions: Required<Pick<GreetingOptions, 'useColors' | 'message'>> = {
    useColors: true,
    message: 'Hello',
  };

  /**
   * Output a greeting in the specified style
   *
   * @param options - Configuration options for the greeting
   * @returns Formatted greeting string
   */
  public greet(options: GreetingOptions): string {
    const config = { ...this.defaultOptions, ...options };

    switch (config.style) {
      case GreetingStyle.SIMPLE:
        return this.renderSimple(config);
      case GreetingStyle.ELABORATE:
        return this.renderElaborate(config);
      case GreetingStyle.ARTISTIC:
        return this.renderArtistic(config);
      default:
        // Exhaustiveness check - TypeScript will error if new styles added
        const _exhaustive: never = config.style;
        return _exhaustive;
    }
  }

  /**
   * Output greeting directly to console
   *
   * @param options - Configuration options for the greeting
   */
  public consoleGreet(options: GreetingOptions): void {
    const output = this.greet(options);
    console.log(output);
  }

  /**
   * Render simple greeting style
   *
   * @example
   * Hello, World!
   *
   * @param config - Greeting configuration
   * @returns Formatted simple greeting
   */
  private renderSimple(config: Required<GreetingOptions>): string {
    const target = config.target ? `, ${config.target}` : '';
    const colored = config.useColors
      ? `${Colors.GREEN}${config.message}${Colors.RESET}${target}!`
      : `${config.message}${target}!`;

    return colored;
  }

  /**
   * Render elaborate greeting style with descriptive formatting
   *
   * @example
   * ╔══════════════════════════════╗
   * ║   GREETING SYSTEM v1.0.0    ║
   * ╠══════════════════════════════╣
   * ║  Message: Hello, World!     ║
   * ║  Style: Elaborate            ║
   * ╚══════════════════════════════╝
   *
   * @param config - Greeting configuration
   * @returns Formatted elaborate greeting
   */
  private renderElaborate(config: Required<GreetingOptions>): string {
    const target = config.target ? `, ${config.target}` : '';
    const fullMessage = `${config.message}${target}!`;
    const border = '═'.repeat(fullMessage.length + 16);

    let output = '\n';
    output += config.useColors ? `${Colors.CYAN}╔${border}╗${Colors.RESET}\n` : `╔${border}╗\n`;
    output += config.useColors ? `${Colors.CYAN}║${Colors.RESET}   ${Colors.BRIGHT}GREETING SYSTEM v1.0.0${Colors.RESET}   ${Colors.CYAN}║${Colors.RESET}\n` : `║   GREETING SYSTEM v1.0.0   ║\n`;
    output += config.useColors ? `${Colors.CYAN}╠${border}╣${Colors.RESET}\n` : `╠${border}╣\n`;
    output += config.useColors
      ? `${Colors.CYAN}║${Colors.RESET}  ${Colors.YELLOW}Message:${Colors.RESET} ${Colors.BRIGHT}${fullMessage}${Colors.RESET}  ${Colors.CYAN}║${Colors.RESET}\n`
      : `║  Message: ${fullMessage}  ║\n`;
    output += config.useColors
      ? `${Colors.CYAN}║${Colors.RESET}  ${Colors.YELLOW}Style:${Colors.RESET} ${config.style.charAt(0).toUpperCase() + config.style.slice(1)}  ${Colors.CYAN}║${Colors.RESET}\n`
      : `║  Style: ${config.style.charAt(0).toUpperCase() + config.style.slice(1)}  ║\n`;
    output += config.useColors ? `${Colors.CYAN}╚${border}╝${Colors.RESET}\n` : `╚${border}╝\n`;

    return output;
  }

  /**
   * Render artistic greeting style using ASCII art
   *
   * @example
   *   ██╗   ██╗█████████╗██╗   ██╗██████╗ ███████╗
   *   ██║   ██║╚══██╔══╝╝██║   ██║██╔══██╗██╔════╝
   *   ██║   ██║   ██║   ██║   ██║██████╔╝█████╗
   *   ██║   ██║   ██║   ██║   ██║██╔══██╗██╔══╝
   *   ╚██████╔╝   ██║   ╚██████╔╝██║  ██║███████╗
   *    ╚═════╝    ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝
   *
   * @param config - Greeting configuration
   * @returns Formatted artistic greeting
   */
  private renderArtistic(config: Required<GreetingOptions>): string {
    const helloArt = [
      '  ██╗   ██╗█████████╗██╗   ██╗██████╗ ███████╗',
      '  ██║   ██║╚══██╔══╝╝██║   ██║██╔══██╗██╔════╝',
      '  ██║   ██║   ██║   ██║   ██║██████╔╝█████╗  ',
      '  ██║   ██║   ██║   ██║   ██║██╔══██╗██╔══╝  ',
      '  ╚██████╔╝   ██║   ╚██████╔╝██║  ██║███████╗',
      '   ╚═════╝    ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝',
    ];

    const target = config.target ? `  >>> ${config.target} <<<` : '';

    let output = '\n';
    for (const line of helloArt) {
      output += config.useColors ? `${Colors.MAGENTA}${line}${Colors.RESET}\n` : `${line}\n`;
    }
    if (target) {
      output += config.useColors ? `${Colors.BRIGHT}${Colors.CYAN}${target}${Colors.RESET}\n` : `${target}\n`;
    }

    return output;
  }

  /**
   * Get all available greeting styles
   *
   * @returns Array of available greeting styles
   */
  public static getAvailableStyles(): GreetingStyle[] {
    return Object.values(GreetingStyle);
  }

  /**
   * Validate if a given style is supported
   *
   * @param style - Style to validate
   * @returns True if style is valid, false otherwise
   */
  public static isValidStyle(style: string): style is GreetingStyle {
    return Object.values(GreetingStyle).includes(style as GreetingStyle);
  }
}

/**
 * Default export for convenient importing
 */
export default Greeter;
