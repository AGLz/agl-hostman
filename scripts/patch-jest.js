#!/usr/bin/env node

/**
 * Patch write-file-atomic to fix signal-exit compatibility issue
 * This script patches the node_modules directly to work around the issue
 */

const fs = require('fs');
const path = require('path');

// Find the write-file-atomic package
const waPath = path.resolve(__dirname, '../node_modules/.pnpm/node_modules/write-file-atomic');
const indexPath = path.join(waPath, 'lib/index.js');

if (!fs.existsSync(indexPath)) {
  console.log('write-file-atomic not found at expected path:', indexPath);
  process.exit(0);
}

console.log('Patching write-file-atomic at:', indexPath);

// Read the file
let content = fs.readFileSync(indexPath, 'utf8');

// Check if already patched
if (content.includes('PATCHED_FOR_JEST')) {
  console.log('Already patched');
  process.exit(0);
}

// Patch the onExit call to handle both v3 and v4 APIs
// Original: const removeOnExitHandler = onExit(cleanupOnExit(() => tmpfile))
// Patched: Wrap in try-catch to handle v4 API differences
content = content.replace(
  /(const removeOnExitHandler = onExit\()(cleanupOnExit\(\(\) => tmpfile\)\))/g,
  `// PATCHED_FOR_JEST\n    try {\n      $1$2\n    } catch (e) {\n      // Fallback for signal-exit v4 compatibility\n      const onExit = require('signal-exit');\n      $1(() => {}, { alwaysLast: false });\n    }\n    /* END_PATCH */`
);

// Write the patched file
fs.writeFileSync(indexPath, content, 'utf8');
console.log('Patched successfully');
