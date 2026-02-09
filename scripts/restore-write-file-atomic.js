#!/usr/bin/env node

/**
 * Restore write-file-atomic to working state
 */

const fs = require('fs');
const path = require('path');

const waPath = path.resolve(__dirname, '../node_modules/.pnpm/node_modules/write-file-atomic');
const indexPath = path.join(waPath, 'lib/index.js');

console.log('Restoring write-file-atomic...');

// Read the current (broken) file
const content = fs.readFileSync(indexPath, 'utf8');

// Remove any PATCHED_FOR_JEST blocks
let restored = content.replace(/\/\/ PATCHED_FOR_JEST[\s\S]*?\/\* END_PATCH \*\//g, '// PATCHED_FOR_JEST removed');

// Fix the specific broken line
restored = restored.replace(
  /const removeOnExitHandler = onExit\(\(\) => \{\}, \{ alwaysLast: false \}\);/,
  'const removeOnExitHandler = onExit(cleanupOnExit(() => tmpfile));'
);

fs.writeFileSync(indexPath, restored, 'utf8');
console.log('Restored write-file-atomic');
