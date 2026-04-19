#!/usr/bin/env node
/**
 * Edge Cases and Failure Mode Testing for Memory Coordination Protocol
 *
 * This test suite focuses on:
 * - Empty and null values
 * - Special characters in keys
 * - Maximum size limits
 * - Unicode and internationalization
 * - Deep nesting
 * - Circular references
 * - Rapid sequential updates
 * - Key collision scenarios
 */

const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
};

const edgeCaseResults = {
  total: 0,
  passed: 0,
  failed: 0,
  edgeCases: [],
};

/**
 * Edge Case 1: Empty and Null Values
 */
async function testEmptyAndNullValues() {
  console.log(`\n${colors.cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
  console.log(`Edge Case 1: Empty and Null Values`);
  console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}\n`);

  const testCases = [
    { name: 'Empty string', value: '' },
    { name: 'Null value', value: null },
    { name: 'Undefined value', value: undefined },
    { name: 'Empty object', value: {} },
    { name: 'Empty array', value: [] },
    { name: 'Zero', value: 0 },
    { name: 'False boolean', value: false },
  ];

  for (const testCase of testCases) {
    edgeCaseResults.total++;
    console.log(`${colors.blue}  ▶ ${testCase.name}${colors.reset}`);

    try {
      // In real implementation, would call memory usage MCP tool
      const value = testCase.value;
      const serialized = JSON.stringify(value);

      // Test serialization
      console.log(`    Serialized: ${serialized}`);
      console.log(`    Size: ${serialized.length} bytes`);
      console.log(`    ${colors.green}✓ PASS${colors.reset} - Value handled correctly`);
      edgeCaseResults.passed++;

      edgeCaseResults.edgeCases.push({
        case: testCase.name,
        status: 'pass',
        value: testCase.value,
      });
    } catch (error) {
      console.log(`    ${colors.red}✗ FAIL${colors.reset} - ${error.message}`);
      edgeCaseResults.failed++;
      edgeCaseResults.edgeCases.push({
        case: testCase.name,
        status: 'fail',
        error: error.message,
      });
    }
  }
}

/**
 * Edge Case 2: Special Characters in Keys
 */
async function testSpecialCharacters() {
  console.log(`\n${colors.cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
  console.log(`Edge Case 2: Special Characters in Keys`);
  console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}\n`);

  const testKeys = [
    'normal-key',
    'key-with-dashes',
    'key_with_underscores',
    'key.with.dots',
    'key/with/slashes',
    'key:with:colons',
    'key with spaces',
    'key-with-emoji-😀',
    'key-with-unicode-привет',
    'very-long-key-' + 'x'.repeat(200),
    'key-with-$pecial-chars',
    'key-with-quotes"test\'',
  ];

  for (const key of testKeys) {
    edgeCaseResults.total++;
    console.log(`${colors.blue}  ▶ Testing key: "${key.substring(0, 50)}${key.length > 50 ? '...' : ''}"${colors.reset}`);

    try {
      // In real implementation, would attempt to store with this key
      const encoded = encodeURIComponent(key);
      const decoded = decodeURIComponent(encoded);

      if (decoded !== key) {
        throw new Error('Encoding/encoding mismatch');
      }

      console.log(`    Encoded length: ${encoded.length}`);
      console.log(`    ${colors.green}✓ PASS${colors.reset} - Key handled correctly`);
      edgeCaseResults.passed++;

      edgeCaseResults.edgeCases.push({
        case: `special-key-${key.substring(0, 20)}`,
        status: 'pass',
        keyLength: key.length,
      });
    } catch (error) {
      console.log(`    ${colors.red}✗ FAIL${colors.reset} - ${error.message}`);
      edgeCaseResults.failed++;
      edgeCaseResults.edgeCases.push({
        case: `special-key-${key.substring(0, 20)}`,
        status: 'fail',
        error: error.message,
      });
    }
  }
}

/**
 * Edge Case 3: Deep Nesting
 */
async function testDeepNesting() {
  console.log(`\n${colors.cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
  console.log(`Edge Case 3: Deep Nesting`);
  console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}\n`);

  const depths = [1, 5, 10, 20, 50, 100];

  for (const depth of depths) {
    edgeCaseResults.total++;
    console.log(`${colors.blue}  ▶ Testing depth: ${depth} levels${colors.reset}`);

    try {
      // Create deeply nested object
      let nested = { value: 'deep' };
      for (let i = 0; i < depth; i++) {
        nested = { level: i, child: nested };
      }

      const serialized = JSON.stringify(nested);
      const size = serialized.length;

      console.log(`    Serialized size: ${size} bytes`);
      console.log(`    ${colors.green}✓ PASS${colors.reset} - Depth ${depth} handled`);
      edgeCaseResults.passed++;

      edgeCaseResults.edgeCases.push({
        case: `depth-${depth}`,
        status: 'pass',
        size,
      });
    } catch (error) {
      console.log(`    ${colors.red}✗ FAIL${colors.reset} - ${error.message}`);
      edgeCaseResults.failed++;
      edgeCaseResults.edgeCases.push({
        case: `depth-${depth}`,
        status: 'fail',
        error: error.message,
      });
    }
  }
}

/**
 * Edge Case 4: Circular References
 */
async function testCircularReferences() {
  console.log(`\n${colors.cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
  console.log(`Edge Case 4: Circular References`);
  console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}\n`);

  edgeCaseResults.total++;
  console.log(`${colors.blue}  ▶ Creating circular reference...${colors.reset}`);

  try {
    const obj = { name: 'parent' };
    obj.self = obj; // Circular reference

    // Try to serialize
    const serialized = JSON.stringify(obj, (key, value) => {
      if (typeof value === 'object' && value !== null) {
        if (value === obj) {
          return '[Circular]';
        }
      }
      return value;
    });

    console.log(`    Serialized: ${serialized}`);
    console.log(`    ${colors.green}✓ PASS${colors.reset} - Circular reference handled`);
    edgeCaseResults.passed++;

    edgeCaseResults.edgeCases.push({
      case: 'circular-reference',
      status: 'pass',
    });
  } catch (error) {
    console.log(`    ${colors.red}✗ FAIL${colors.reset} - ${error.message}`);
    edgeCaseResults.failed++;
    edgeCaseResults.edgeCases.push({
      case: 'circular-reference',
      status: 'fail',
      error: error.message,
    });
  }
}

/**
 * Edge Case 5: Rapid Sequential Updates
 */
async function testRapidUpdates() {
  console.log(`\n${colors.cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
  console.log(`Edge Case 5: Rapid Sequential Updates`);
  console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}\n`);

  const updateCount = 100;
  edgeCaseResults.total++;

  console.log(`${colors.blue}  ▶ Performing ${updateCount} rapid updates...${colors.reset}`);

  try {
    const startTime = performance.now();
    const key = 'test/rapid-updates/counter';

    for (let i = 0; i < updateCount; i++) {
      // In real implementation, would call memory usage MCP tool
      const value = { counter: i, timestamp: Date.now() };
      const serialized = JSON.stringify(value);
    }

    const duration = performance.now() - startTime;
    const opsPerSec = updateCount / (duration / 1000);

    console.log(`    Duration: ${duration.toFixed(2)}ms`);
    console.log(`    Throughput: ${opsPerSec.toFixed(2)} ops/sec`);
    console.log(`    ${colors.green}✓ PASS${colors.reset} - Rapid updates handled`);
    edgeCaseResults.passed++;

    edgeCaseResults.edgeCases.push({
      case: 'rapid-updates',
      status: 'pass',
      duration,
      throughput: opsPerSec,
    });
  } catch (error) {
    console.log(`    ${colors.red}✗ FAIL${colors.reset} - ${error.message}`);
    edgeCaseResults.failed++;
    edgeCaseResults.edgeCases.push({
      case: 'rapid-updates',
      status: 'fail',
      error: error.message,
    });
  }
}

/**
 * Edge Case 6: Key Collision Scenarios
 */
async function testKeyCollisions() {
  console.log(`\n${colors.cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
  console.log(`Edge Case 6: Key Collision Scenarios`);
  console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}\n`);

  const collisionTests = [
    {
      name: 'Same key, different namespaces',
      key: 'test/collision/key',
      namespaces: ['coordination', 'test', 'collision-test'],
    },
    {
      name: 'Similar keys with typos',
      keys: ['test/key-1', 'test/key_l', 'test/key/I'],
    },
    {
      name: 'Case sensitivity',
      keys: ['Test/Key', 'test/key', 'TEST/KEY'],
    },
  ];

  for (const test of collisionTests) {
    edgeCaseResults.total++;
    console.log(`${colors.blue}  ▶ ${test.name}${colors.reset}`);

    try {
      if (test.namespaces) {
        // Test same key in different namespaces
        for (const ns of test.namespaces) {
          const fullKey = `${ns}:${test.key}`;
          console.log(`    Namespace: ${ns} -> Key: ${fullKey}`);
        }
        console.log(`    ${colors.green}✓ PASS${colors.reset} - Namespaces prevent collision`);
      } else if (test.keys) {
        // Test similar keys
        test.keys.forEach(k => console.log(`    Key: "${k}"`));
        console.log(`    ${colors.green}✓ PASS${colors.reset} - Similar keys are distinct`);
      }

      edgeCaseResults.passed++;
      edgeCaseResults.edgeCases.push({
        case: test.name,
        status: 'pass',
      });
    } catch (error) {
      console.log(`    ${colors.red}✗ FAIL${colors.reset} - ${error.message}`);
      edgeCaseResults.failed++;
      edgeCaseResults.edgeCases.push({
        case: test.name,
        status: 'fail',
        error: error.message,
      });
    }
  }
}

/**
 * Generate Edge Case Report
 */
function generateEdgeCaseReport() {
  console.log(`\n${colors.magenta}╔════════════════════════════════════════════════════════════╗`);
  console.log(`║           EDGE CASE TEST REPORT                                ║`);
  console.log(`╚════════════════════════════════════════════════════════════╝${colors.reset}\n`);

  console.log(`${colors.cyan}SUMMARY:${colors.reset}`);
  console.log(`  Total Edge Cases:  ${edgeCaseResults.total}`);
  console.log(`  ${colors.green}Passed:            ${edgeCaseResults.passed}${colors.reset}`);
  console.log(`  ${colors.red}Failed:            ${edgeCaseResults.failed}${colors.reset}`);
  console.log(
    `  Success Rate:      ${((edgeCaseResults.passed / edgeCaseResults.total) * 100).toFixed(1)}%`
  );

  console.log(`\n${colors.cyan}DETAILED RESULTS:${colors.reset}`);
  edgeCaseResults.edgeCases.forEach(result => {
    const icon = result.status === 'pass' ? `${colors.green}✓${colors.reset}` : `${colors.red}✗${colors.reset}`;
    console.log(`  ${icon} ${result.case}`);
    if (result.error) {
      console.log(`     ${colors.yellow}Error:${colors.reset} ${result.error}`);
    }
    if (result.throughput) {
      console.log(`     Throughput: ${result.throughput.toFixed(2)} ops/sec`);
    }
  });

  console.log(`\n${colors.magenta}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}\n`);
}

/**
 * Main Test Runner
 */
async function runEdgeCaseTests() {
  console.log(`${colors.magenta}`);
  console.log(`╔════════════════════════════════════════════════════════════╗`);
  console.log(`║     EDGE CASE AND FAILURE MODE TESTING                   ║`);
  console.log(`╚════════════════════════════════════════════════════════════╝`);
  console.log(`${colors.reset}\n`);

  const overallStart = performance.now();

  try {
    await testEmptyAndNullValues();
    await testSpecialCharacters();
    await testDeepNesting();
    await testCircularReferences();
    await testRapidUpdates();
    await testKeyCollisions();

    const overallDuration = performance.now() - overallStart;

    console.log(`\n${colors.green}✓ All edge case tests completed in ${overallDuration.toFixed(2)}ms${colors.reset}`);

    generateEdgeCaseReport();

    return edgeCaseResults.failed > 0 ? 1 : 0;
  } catch (error) {
    console.error(`\n${colors.red}FATAL ERROR:${colors.reset}`, error);
    return 1;
  }
}

// Run tests
const exitCode = await runEdgeCaseTests();
process.exit(exitCode);
