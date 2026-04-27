#!/usr/bin/env node

/**
 * Greeting Module Demo
 *
 * Demonstrates all features of the greeting module with practical examples.
 * Run with: node examples/greeting-demo.js
 */

'use strict';

const greeting = require('../src/greeting');

// Utility for formatted output
function logSection(title) {
  console.log('\n' + '='.repeat(60));
  console.log(`  ${title}`);
  console.log('='.repeat(60));
}

function logResult(label, result) {
  console.log(`\n${label}:`);
  console.log(`  Message: "${result.message}"`);
  console.log(`  Format: ${result.format}`);
  console.log(`  Timestamp: ${result.timestamp.toISOString()}`);
  if (result.metadata) {
    console.log(`  Metadata:`, JSON.stringify(result.metadata, null, 4));
  }
}

// Main demo
function runDemo() {
  console.log('\n🎯 Greeting Module - Interactive Demo\n');

  // Demo 1: Simple Greetings
  logSection('1. Simple Greetings');

  const simple1 = greeting.simpleGreeting();
  logResult('Default simple greeting', simple1);

  const simple2 = greeting.simpleGreeting('hi there');
  logResult('Custom simple greeting', simple2);

  // Demo 2: Enhanced Greetings
  logSection('2. Enhanced Greetings');

  const enhanced1 = greeting.enhancedGreeting({ recipient: 'World' });
  logResult('Enhanced with recipient', enhanced1);

  const enhanced2 = greeting.enhancedGreeting({
    recipient: 'Dr. Smith',
    formal: true
  });
  logResult('Enhanced formal greeting', enhanced2);

  const enhanced3 = greeting.enhancedGreeting({ message: 'Welcome' });
  logResult('Enhanced custom message', enhanced3);

  // Demo 3: Creative Greetings
  logSection('3. Creative Greetings (Time-aware)');

  const creative1 = greeting.creativeGreeting({
    recipient: 'Team',
    style: 'enthusiastic'
  });
  logResult('Creative enthusiastic (current time)', creative1);

  const morningTime = new Date('2025-11-01T08:00:00');
  const creative2 = greeting.creativeGreeting({
    recipient: 'Early Birds',
    time: morningTime,
    style: 'friendly'
  });
  logResult('Creative morning greeting', creative2);

  const eveningTime = new Date('2025-11-01T19:00:00');
  const creative3 = greeting.creativeGreeting({
    recipient: 'Night Owls',
    time: eveningTime,
    style: 'casual'
  });
  logResult('Creative evening greeting', creative3);

  // Demo 4: Factory Pattern
  logSection('4. Factory Pattern');

  const factory1 = greeting.greetingFactory('simple');
  logResult('Factory simple', factory1);

  const factory2 = greeting.greetingFactory('enhanced', {
    recipient: 'Factory User',
    formal: true
  });
  logResult('Factory enhanced', factory2);

  const factory3 = greeting.greetingFactory('creative', {
    style: 'enthusiastic'
  });
  logResult('Factory creative', factory3);

  // Demo 5: Error Handling
  logSection('5. Error Handling');

  try {
    greeting.simpleGreeting(123);
  } catch (error) {
    console.log(`\n✗ Type error caught: ${error.message}`);
  }

  try {
    greeting.greetingFactory('invalid-format');
  } catch (error) {
    console.log(`✗ Invalid format caught: ${error.message}`);
  }

  // Demo 6: Batch Processing
  logSection('6. Batch Processing');

  const batchConfigs = [
    { format: 'simple' },
    { format: 'enhanced', options: { recipient: 'Team A', formal: true } },
    { format: 'creative', options: { recipient: 'Team B', style: 'casual' } },
    { format: 'enhanced', options: { message: 'Greetings', recipient: 'Everyone' } }
  ];

  const batchResults = greeting.batchGreeting(batchConfigs);

  console.log(`\nGenerated ${batchResults.length} greetings:`);
  batchResults.forEach((result, index) => {
    console.log(`  ${index + 1}. [${result.format}] "${result.message}"`);
  });

  // Demo 7: Real-world Use Cases
  logSection('7. Real-world Use Cases');

  console.log('\nUse Case: Multi-language Support');
  const languages = [
    { format: 'simple', options: { message: 'hello' } },
    { format: 'simple', options: { message: 'hola' } },
    { format: 'simple', options: { message: 'bonjour' } },
    { format: 'simple', options: { message: 'こんにちは' } }
  ];

  const multiLang = greeting.batchGreeting(languages.map(lang => ({
    format: lang.format,
    options: lang.options
  })));

  multiLang.forEach((result, index) => {
    console.log(`  ${['English', 'Spanish', 'French', 'Japanese'][index]}: "${result.message}"`);
  });

  console.log('\nUse Case: Time-based User Onboarding');
  const onboardingGreeting = greeting.creativeGreeting({
    recipient: 'New User',
    style: 'enthusiastic'
  });
  console.log(`  Onboarding: "${onboardingGreeting.message}"`);
  console.log(`  Time context: ${onboardingGreeting.metadata.timeOfDay}`);

  console.log('\nUse Case: Formal Business Communication');
  const businessGreeting = greeting.enhancedGreeting({
    message: 'Welcome',
    recipient: 'Board Members',
    formal: true
  });
  console.log(`  Business: "${businessGreeting.message}"`);

  // Summary
  logSection('Demo Complete');
  console.log('\n✅ All greeting formats demonstrated successfully');
  console.log('📦 Module exports:', Object.keys(greeting).join(', '));
  console.log('📚 See README.md for complete API documentation\n');
}

// Run the demo
if (require.main === module) {
  runDemo();
}

module.exports = { runDemo };
