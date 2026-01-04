/**
 * Greeting Module Demo
 *
 * Demonstrates all features of the Greeter class including:
 * - Multiple greeting styles
 * - Color customization
 * - Target personalization
 * - Error handling
 *
 * Run with: npx ts-node src/demo.ts
 */

import { Greeter, GreetingStyle, GreetingOptions } from './greeting';

/**
 * Demo function showing all greeting styles
 */
function runDemos(): void {
  const greeter = new Greeter();

  console.log('\n' + '='.repeat(60));
  console.log('🎭 GREETING MODULE DEMONSTRATION');
  console.log('='.repeat(60) + '\n');

  // Demo 1: Simple greeting
  console.log('📌 Demo 1: Simple Greeting');
  console.log('-'.repeat(60));
  greeter.consoleGreet({ style: GreetingStyle.SIMPLE });

  // Demo 2: Simple with target
  console.log('\n📌 Demo 2: Simple Greeting with Target');
  console.log('-'.repeat(60));
  greeter.consoleGreet({
    style: GreetingStyle.SIMPLE,
    target: 'Hive Mind',
  });

  // Demo 3: Elaborate greeting
  console.log('\n📌 Demo 3: Elaborate Greeting');
  console.log('-'.repeat(60));
  greeter.consoleGreet({ style: GreetingStyle.ELABORATE });

  // Demo 4: Artistic greeting
  console.log('\n📌 Demo 4: Artistic Greeting');
  console.log('-'.repeat(60));
  greeter.consoleGreet({ style: GreetingStyle.ARTISTIC });

  // Demo 5: Custom message
  console.log('\n📌 Demo 5: Custom Message');
  console.log('-'.repeat(60));
  greeter.consoleGreet({
    style: GreetingStyle.SIMPLE,
    message: 'Welcome to the Hive Mind',
  });

  // Demo 6: No colors
  console.log('\n📌 Demo 6: Greeting without Colors');
  console.log('-'.repeat(60));
  greeter.consoleGreet({
    style: GreetingStyle.ELABORATE,
    useColors: false,
  });

  // Demo 7: Full custom greeting
  console.log('\n📌 Demo 7: Full Custom Greeting');
  console.log('-'.repeat(60));
  greeter.consoleGreet({
    style: GreetingStyle.ARTISTIC,
    message: 'Greetings',
    target: 'Developer',
    useColors: true,
  });

  // Demo 8: Style validation
  console.log('\n📌 Demo 8: Style Validation');
  console.log('-'.repeat(60));
  console.log('Available styles:', Greeter.getAvailableStyles());
  console.log('Is "simple" valid?', Greeter.isValidStyle('simple'));
  console.log('Is "invalid" valid?', Greeter.isValidStyle('invalid'));

  // Demo 9: Getting output as string
  console.log('\n📌 Demo 9: Getting Output as String');
  console.log('-'.repeat(60));
  const output = greeter.greet({
    style: GreetingStyle.SIMPLE,
    target: 'Claude',
  });
  console.log('Captured output:', output);
  console.log('Output length:', output.length, 'characters');

  // Demo 10: Batch greetings
  console.log('\n📌 Demo 10: Batch Greetings');
  console.log('-'.repeat(60));
  const batchOptions: GreetingOptions[] = [
    { style: GreetingStyle.SIMPLE, target: 'Alice' },
    { style: GreetingStyle.ELABORATE, target: 'Bob' },
    { style: GreetingStyle.ARTISTIC, target: 'Charlie' },
  ];

  batchOptions.forEach((options, index) => {
    console.log(`\nBatch ${index + 1}:`);
    greeter.consoleGreet(options);
  });

  console.log('\n' + '='.repeat(60));
  console.log('✅ DEMONSTRATION COMPLETE');
  console.log('='.repeat(60) + '\n');
}

/**
 * Example of using Greeter in a real application
 */
function realWorldExample(): void {
  const greeter = new Greeter();

  // Web server greeting simulation
  function greetUser(username: string, style: GreetingStyle = GreetingStyle.SIMPLE): string {
    return greeter.greet({
      style,
      target: username,
      useColors: false, // No colors in web responses
    });
  }

  console.log('🌐 Real-world Example: Web Service Greetings');
  console.log('-'.repeat(60));
  console.log(greetUser('alice@example.com'));
  console.log(greetUser('bob@example.com', GreetingStyle.ELABORATE));
}

/**
 * Performance demonstration
 */
function performanceDemo(): void {
  console.log('\n⚡ Performance Demo');
  console.log('-'.repeat(60));

  const greeter = new Greeter();
  const iterations = 1000;

  // Simple greeting performance
  console.time('Simple (1000 iterations)');
  for (let i = 0; i < iterations; i++) {
    greeter.greet({ style: GreetingStyle.SIMPLE });
  }
  console.timeEnd('Simple (1000 iterations)');

  // Elaborate greeting performance
  console.time('Elaborate (1000 iterations)');
  for (let i = 0; i < iterations; i++) {
    greeter.greet({ style: GreetingStyle.ELABORATE });
  }
  console.timeEnd('Elaborate (1000 iterations)');

  // Artistic greeting performance
  console.time('Artistic (1000 iterations)');
  for (let i = 0; i < iterations; i++) {
    greeter.greet({ style: GreetingStyle.ARTISTIC });
  }
  console.timeEnd('Artistic (1000 iterations)');
}

// Run all demos
if (require.main === module) {
  runDemos();
  realWorldExample();
  performanceDemo();
}

export { runDemos, realWorldExample, performanceDemo };
