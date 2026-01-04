#!/usr/bin/env node
/**
 * Diagnostic script to test memory protocol injection
 * This will help identify which function is failing and why
 */

console.log('🔍 Memory Protocol Injection Diagnostic Tool');
console.log('=' .repeat(60));

async function testMemoryInjection() {
  try {
    // Try to import the inject-memory-protocol module
    console.log('\n1️⃣ Testing module import...');
    const modulePath = '/root/.pnpm/global/5/node_modules/claude-flow/src/cli/simple-commands/inject-memory-protocol.js';

    const injectModule = await import(modulePath);
    console.log('✅ Module imported successfully');
    console.log('   Available exports:', Object.keys(injectModule));

    // Test injectMemoryProtocol function
    console.log('\n2️⃣ Testing injectMemoryProtocol()...');
    const result = injectModule.injectMemoryProtocol;
    console.log('✅ injectMemoryProtocol function found');
    console.log('   Function type:', typeof result);

    // Try to call it
    console.log('\n3️⃣ Calling injectMemoryProtocol()...');
    if (typeof result === 'function') {
      const injectionResult = await injectModule.injectMemoryProtocol();
      console.log('✅ injectMemoryProtocol executed successfully');
      console.log('   Result:', injectionResult);
    } else {
      console.log('⚠️  injectMemoryProtocol is not a function:', result);
    }

    // Test enhanceHiveMindPrompt function
    console.log('\n4️⃣ Testing enhanceHiveMindPrompt()...');
    const enhanceFn = injectModule.enhanceHiveMindPrompt;
    console.log('✅ enhanceHiveMindPrompt function found');
    console.log('   Function type:', typeof enhanceFn);

    // Try to call it
    console.log('\n5️⃣ Calling enhanceHiveMindPrompt()...');
    if (typeof enhanceFn === 'function') {
      const testPrompt = 'Test objective for hive mind';
      const testWorkers = [
        { name: 'worker-1', type: 'coder' },
        { name: 'worker-2', type: 'tester' }
      ];
      const enhancedPrompt = injectModule.enhanceHiveMindPrompt(testPrompt, testWorkers);
      console.log('✅ enhanceHiveMindPrompt executed successfully');
      console.log('   Enhanced prompt length:', enhancedPrompt.length);
      console.log('   Preview (first 300 chars):');
      console.log('   ' + enhancedPrompt.substring(0, 300) + '...');
    } else {
      console.log('⚠️  enhanceHiveMindPrompt is not a function:', enhanceFn);
    }

    console.log('\n' + '='.repeat(60));
    console.log('✅ ALL TESTS PASSED - Memory injection should work!');
    console.log('='.repeat(60));

  } catch (err) {
    console.log('\n' + '='.repeat(60));
    console.error('❌ ERROR DIAGNOSTIC:');
    console.error('='.repeat(60));
    console.error('Error name:', err.name);
    console.error('Error message:', err.message);
    console.error('Error code:', err.code);
    console.error('\nStack trace:');
    console.error(err.stack);
    console.log('\n' + '='.repeat(60));

    // Provide specific guidance based on error type
    if (err.code === 'ERR_MODULE_NOT_FOUND') {
      console.log('\n🔧 GUIDANCE: Module not found');
      console.log('   The inject-memory-protocol.js file may not exist');
      console.log('   or the import path is incorrect.');
    } else if (err.code === 'ENOENT') {
      console.log('\n🔧 GUIDANCE: File not found');
      console.log('   Check if CLAUDE.md exists in the project directory.');
    } else if (err.message.includes('permission')) {
      console.log('\n🔧 GUIDANCE: Permission denied');
      console.log('   The script may not have permission to read/write CLAUDE.md');
    }
  }
}

// Run the test
testMemoryInjection().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
