#!/usr/bin/env node
/**
 * Diagnostic script to test the exact import pattern from hive-mind.js
 * This will help identify the specific error being caught at runtime
 */

import { fileURLToPath } from 'url';
import path from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

console.log('🔍 Runtime Import Diagnostic Script');
console.log('='.repeat(70));

async function diagnoseRuntimeImport() {
  console.log('\n📍 Working Directory:', process.cwd());
  console.log('📍 Script Location:', __dirname);

  // Change to hive-mind.js directory to match runtime context
  const hiveMindDir = '/root/.pnpm/global/5/node_modules/claude-flow/src/cli/simple-commands';
  console.log('\n🔄 Changing to hive-mind.js directory...');
  console.log('   Target:', hiveMindDir);
  process.chdir(hiveMindDir);
  console.log('   ✅ Changed directory to:', process.cwd());

  // Test 1: Check if inject-memory-protocol.js exists
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('TEST 1: Check if ./inject-memory-protocol.js file exists');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  try {
    const fs = await import('fs');
    const exists = fs.existsSync('./inject-memory-protocol.js');
    console.log('   File exists:', exists);

    if (exists) {
      const stats = fs.statSync('./inject-memory-protocol.js');
      console.log('   File stats:', {
        isFile: stats.isFile(),
        isSymbolicLink: stats.isSymbolicLink(),
        size: stats.size,
        mode: stats.mode.toString(8)
      });

      if (stats.isSymbolicLink()) {
        const target = fs.readlinkSync('./inject-memory-protocol.js');
        console.log('   Symlink target:', target);
      }
    }
  } catch (err) {
    console.error('   ❌ Error checking file:', err.message);
    console.error('   Stack:', err.stack);
  }

  // Test 2: Try the exact import pattern from hive-mind.js
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('TEST 2: Test exact import pattern from hive-mind.js');
  console.log('   Pattern: await import("./inject-memory-protocol.js")');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  try {
    console.log('   Attempting import...');
    const module = await import('./inject-memory-protocol.js');
    console.log('   ✅ Import succeeded!');
    console.log('   Available exports:', Object.keys(module));
    console.log('   Export types:', {
      injectMemoryProtocol: typeof module.injectMemoryProtocol,
      enhanceHiveMindPrompt: typeof module.enhanceHiveMindPrompt,
      enhanceSwarmPrompt: typeof module.enhanceSwarmPrompt,
      shouldInjectProtocol: typeof module.shouldInjectProtocol,
      default: typeof module.default
    });
  } catch (err) {
    console.error('   ❌ Import failed!');
    console.error('   Error name:', err.name);
    console.error('   Error message:', err.message);
    console.error('   Error code:', err.code);
    console.error('   Stack trace:');
    console.error('   ' + err.stack.split('\n').join('\n   '));

    // Don't continue if import failed
    console.log('\n⚠️  Cannot continue with function tests due to import failure');
    return;
  }

  // Test 3: Load module again for function tests
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('TEST 3: Test injectMemoryProtocol() function call');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  try {
    const { injectMemoryProtocol } = await import('./inject-memory-protocol.js');
    console.log('   Function loaded, calling with projectPath:', process.cwd());

    const result = await injectMemoryProtocol('/mnt/overpower/apps/dev/agl/agl-hostman');
    console.log('   ✅ injectMemoryProtocol() succeeded!');
    console.log('   Result:', result);
  } catch (err) {
    console.error('   ❌ injectMemoryProtocol() failed!');
    console.error('   Error name:', err.name);
    console.error('   Error message:', err.message);
    console.error('   Error code:', err.code);
    console.error('   Stack trace:');
    console.error('   ' + err.stack.split('\n').join('\n   '));
  }

  // Test 4: Test enhanceHiveMindPrompt() function call
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('TEST 4: Test enhanceHiveMindPrompt() function call');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  try {
    const { enhanceHiveMindPrompt } = await import('./inject-memory-protocol.js');
    console.log('   Function loaded, calling with test data...');

    const testPrompt = 'Test objective for hive mind';
    const testWorkers = [
      { name: 'worker-1', type: 'researcher' },
      { name: 'worker-2', type: 'coder' }
    ];

    const enhancedPrompt = enhanceHiveMindPrompt(testPrompt, testWorkers);
    console.log('   ✅ enhanceHiveMindPrompt() succeeded!');
    console.log('   Enhanced prompt length:', enhancedPrompt.length, 'characters');

    // Verify content
    const hasCoordination = enhancedPrompt.includes('HIVE MIND COORDINATION REQUIREMENTS');
    const hasWorkerInstructions = enhancedPrompt.includes('Agent worker-1:');
    console.log('   Content verification:');
    console.log('   - Coordination section:', hasCoordination ? '✅' : '❌');
    console.log('   - Worker instructions:', hasWorkerInstructions ? '✅' : '❌');
  } catch (err) {
    console.error('   ❌ enhanceHiveMindPrompt() failed!');
    console.error('   Error name:', err.name);
    console.error('   Error message:', err.message);
    console.error('   Error code:', err.code);
    console.error('   Stack trace:');
    console.error('   ' + err.stack.split('\n').join('\n   '));
  }

  // Test 5: Combined test (exact pattern from hive-mind.js)
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('TEST 5: Combined test (exact hive-mind.js pattern)');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  try {
    console.log('   Loading both functions...');
    const { injectMemoryProtocol, enhanceHiveMindPrompt } = await import('./inject-memory-protocol.js');

    console.log('   Calling injectMemoryProtocol()...');
    const projectPath = '/mnt/overpower/apps/dev/agl/agl-hostman';
    await injectMemoryProtocol(projectPath);

    console.log('   Calling enhanceHiveMindPrompt()...');
    const hiveMindPrompt = 'Test hive mind objective';
    const workers = [
      { name: 'queen-coordinator', type: 'coordinator' },
      { name: 'worker-1', type: 'coder' },
      { name: 'worker-2', type: 'tester' }
    ];

    const enhancedPrompt = enhanceHiveMindPrompt(hiveMindPrompt, workers);

    console.log('   ✅ BOTH functions succeeded!');
    console.log('   Enhanced prompt length:', enhancedPrompt.length, 'characters');
    console.log('   Worker count:', workers.length);
  } catch (err) {
    console.error('   ❌ Combined test failed!');
    console.error('   Error name:', err.name);
    console.error('   Error message:', err.message);
    console.error('   Error code:', err.code);
    console.error('   Stack trace:');
    console.error('   ' + err.stack.split('\n').join('\n   '));
  }

  console.log('\n' + '='.repeat(70));
  console.log('✅ Diagnostic complete!');
  console.log('='.repeat(70));
}

// Run diagnostics
diagnoseRuntimeImport().catch(err => {
  console.error('\n💥 Fatal error in diagnostic script:');
  console.error('Error:', err);
  console.error('Stack:', err.stack);
  process.exit(1);
});
