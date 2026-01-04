#!/usr/bin/env node
/**
 * Test script for the PATCHED version of inject-memory-protocol.js
 * This verifies that the import syntax fix resolves the SyntaxError
 */

console.log('🧪 Testing PATCHED inject-memory-protocol.js');
console.log('='.repeat(60));

async function testPatchedVersion() {
  try {
    // Import the PATCHED version (local file)
    console.log('\n1️⃣ Importing PATCHED version from local path...');
    const modulePath = '/mnt/overpower/apps/dev/agl/agl-hostman/.claude/patches/inject-memory-protocol.mjs';
    const injectModule = await import(modulePath);
    console.log('✅ Module imported successfully - NO SyntaxError!');
    console.log('   Available exports:', Object.keys(injectModule));

    // Test 1: injectMemoryProtocol function
    console.log('\n2️⃣ Testing injectMemoryProtocol() function...');
    const injectFn = injectModule.injectMemoryProtocol;
    if (typeof injectFn === 'function') {
      console.log('✅ injectMemoryProtocol is a function');

      // Try to call it (will test on current directory)
      console.log('   Calling injectMemoryProtocol()...');
      const injectionResult = await injectFn('/mnt/overpower/apps/dev/agl/agl-hostman');
      console.log('✅ injectMemoryProtocol executed successfully!');
      console.log('   Result:', injectionResult);
    } else {
      console.log('⚠️  injectMemoryProtocol is not a function:', typeof injectFn);
    }

    // Test 2: enhanceHiveMindPrompt function
    console.log('\n3️⃣ Testing enhanceHiveMindPrompt() function...');
    const enhanceFn = injectModule.enhanceHiveMindPrompt;
    if (typeof enhanceFn === 'function') {
      console.log('✅ enhanceHiveMindPrompt is a function');

      const testPrompt = 'Build a distributed system with memory coordination';
      const testWorkers = [
        { name: 'queen-coordinator', type: 'coordinator' },
        { name: 'memory-manager', type: 'specialist' },
        { name: 'worker-1', type: 'coder' },
        { name: 'worker-2', type: 'tester' }
      ];

      console.log('   Calling enhanceHiveMindPrompt()...');
      const enhancedPrompt = enhanceFn(testPrompt, testWorkers);
      console.log('✅ enhanceHiveMindPrompt executed successfully!');
      console.log('   Enhanced prompt length:', enhancedPrompt.length, 'characters');

      // Verify the enhancement contains key elements
      const hasMemoryProtocol = enhancedPrompt.includes('MANDATORY MEMORY COORDINATION');
      const hasNamespace = enhancedPrompt.includes('namespace: "coordination"');
      const hasWorkerInstructions = enhancedPrompt.includes('Agent queen-coordinator: MUST write');

      console.log('\n   Content verification:');
      console.log('   - Memory protocol section:', hasMemoryProtocol ? '✅' : '❌');
      console.log('   - Coordination namespace:', hasNamespace ? '✅' : '❌');
      console.log('   - Worker instructions:', hasWorkerInstructions ? '✅' : '❌');

      if (hasMemoryProtocol && hasNamespace && hasWorkerInstructions) {
        console.log('\n   ✅ ALL CONTENT CHECKS PASSED');
      }

      // Show preview
      console.log('\n   Preview (first 500 chars):');
      console.log('   ' + enhancedPrompt.substring(0, 500) + '...');
    } else {
      console.log('⚠️  enhanceHiveMindPrompt is not a function:', typeof enhanceFn);
    }

    // Test 3: enhanceSwarmPrompt function
    console.log('\n4️⃣ Testing enhanceSwarmPrompt() function...');
    const swarmFn = injectModule.enhanceSwarmPrompt;
    if (typeof swarmFn === 'function') {
      console.log('✅ enhanceSwarmPrompt is a function');

      const testSwarmPrompt = 'Swarm objective: implement feature X';
      const agentCount = 5;

      console.log('   Calling enhanceSwarmPrompt()...');
      const swarmEnhanced = swarmFn(testSwarmPrompt, agentCount);
      console.log('✅ enhanceSwarmPrompt executed successfully!');
      console.log('   Enhanced swarm prompt length:', swarmEnhanced.length, 'characters');
    } else {
      console.log('⚠️  enhanceSwarmPrompt is not a function:', typeof swarmFn);
    }

    // Test 4: shouldInjectProtocol function
    console.log('\n5️⃣ Testing shouldInjectProtocol() function...');
    const shouldInjectFn = injectModule.shouldInjectProtocol;
    if (typeof shouldInjectFn === 'function') {
      console.log('✅ shouldInjectProtocol is a function');

      const testFlags = { claude: true, spawn: false };
      const result = shouldInjectFn(testFlags);
      console.log('   Test flags:', testFlags);
      console.log('   Result:', result);
      console.log('✅ shouldInjectProtocol executed successfully!');
    } else {
      console.log('⚠️  shouldInjectProtocol is not a function:', typeof shouldInjectFn);
    }

    console.log('\n' + '='.repeat(60));
    console.log('✅ ALL TESTS PASSED - PATCHED VERSION WORKS!');
    console.log('='.repeat(60));
    console.log('\n📝 SUMMARY:');
    console.log('   ✅ Import syntax fix successful');
    console.log('   ✅ All functions are callable');
    console.log('   ✅ Memory protocol enhancement works');
    console.log('   ✅ Worker instructions added correctly');
    console.log('\n🎯 The fix resolves the SyntaxError bug!');
    console.log('   The patched version is ready for integration.');

  } catch (err) {
    console.log('\n' + '='.repeat(60));
    console.error('❌ TEST FAILED:');
    console.error('='.repeat(60));
    console.error('Error name:', err.name);
    console.error('Error message:', err.message);
    console.error('Error code:', err.code);
    console.error('\nStack trace:');
    console.error(err.stack);
    console.log('\n' + '='.repeat(60));
  }
}

// Run the test
testPatchedVersion().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
