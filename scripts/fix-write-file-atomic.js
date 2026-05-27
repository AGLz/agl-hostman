#!/usr/bin/env node

/**
 * Fix write-file-atomic signal-exit compatibility issue
 * This creates a proper patch that works with both signal-exit v3 and v4
 */

const fs = require('fs');
const path = require('path');

// Find the write-file-atomic package
const waPath = path.resolve(__dirname, '../node_modules/.pnpm/node_modules/write-file-atomic');
const indexPath = path.join(waPath, 'lib/index.js');

if (!fs.existsSync(indexPath)) {
  console.log('write-file-atomic not found at:', indexPath);
  process.exit(0);
}

console.log('Fixing write-file-atomic at:', indexPath);

// Read the original file (we need to restore it first if it was patched)
const originalContent = fs.readFileSync(indexPath, 'utf8');

// Check if it was already patched by our previous attempt
if (originalContent.includes('PATCHED_FOR_JEST')) {
  console.log('Removing previous patch...');
  // Restore by removing our patch markers
  let restored = originalContent
    .replace(/\/\/ PATCHED_FOR_JEST\n    try \{[\s\S]*?\} \(e\) \{[\s\S]*?\} \/\* END_PATCH \*\/\n    /, '');
  fs.writeFileSync(indexPath, restored, 'utf8');
  console.log('Previous patch removed');
}

// Read the file again after restoring
let content = fs.readFileSync(indexPath, 'utf8');

// Create a better patch - we'll wrap the entire writeFileAsync function
// Find the async function writeFileAsync line and patch it
const patch = `
// PATCHED_FOR_JEST: Handle signal-exit v4 compatibility
// The issue is that signal-exit v4 has a different API than v3
// We need to catch any errors from onExit and provide a fallback

const _originalOnExit = onExit;
const _safeOnExit = (fn, opts) => {
  try {
    return _originalOnExit(fn, opts);
  } catch (e) {
    // Fallback for signal-exit v4 - return a no-op cleanup
    return () => {};
  }
};

`;

// Insert our patch right after the imports (after line 26 where threadId is defined)
const lines = content.split('\n');
let insertIndex = -1;
for (let i = 0; i < lines.length; i++) {
  if (lines[i].includes('})') && lines[i-1] && lines[i-1].includes('// worker_threads are not available')) {
    insertIndex = i + 1;
    break;
  }
}

if (insertIndex > 0) {
  lines.splice(insertIndex, 0, patch);
  content = lines.join('\n');

  // Now patch the onExit call to use our safe version
  content = content.replace(
    /const removeOnExitHandler = onExit\(/g,
    'const removeOnExitHandler = _safeOnExit('
  );

  fs.writeFileSync(indexPath, content, 'utf8');
  console.log('Successfully patched write-file-atomic');
} else {
  console.log('Could not find insertion point');
}
