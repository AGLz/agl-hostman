/**
 * Jest Prelude - Monkey-patch for write-file-atomic signal-exit compatibility issue
 * This must be loaded before any other Jest modules
 */

// Monkey-patch signal-exit to handle both v3 and v4 APIs
const Module = require('module');
const originalRequire = Module.prototype.require;

let signalExitPatched = false;

Module.prototype.require = function(id) {
  const result = originalRequire.apply(this, arguments);

  // Patch signal-exit when it's first loaded
  if (!signalExitPatched && (id === 'signal-exit' || id.endsWith('signal-exit/index.js'))) {
    signalExitPatched = true;

    // Check if it's v4 (has different API)
    if (result && typeof result === 'function') {
      // v4 API: onExit(fn, options)
      // We need to make it compatible with v3 usage: onExit(fn)
      const originalOnExit = result;
      module.exports = function onExit(fn, options) {
        // v3 API: onExit(fn)
        // v4 API: onExit(fn, options)
        // Call with backward compatibility
        try {
          return originalOnExit(fn, options || {});
        } catch (err) {
          // If the call fails, return a no-op cleanup function
          return () => {};
        }
      };
      // Copy all properties from original
      Object.assign(module.exports, originalOnExit);
    }
  }

  return result;
};

// Also patch write-file-atomic if loaded
let writeFileAtomicPatched = false;
const originalRequire2 = Module.prototype.require;

Module.prototype.require = function(id) {
  const result = originalRequire2.apply(this, arguments);

  if (!writeFileAtomicPatched && (id === 'write-file-atomic' || id.endsWith('write-file-atomic/index.js'))) {
    writeFileAtomicPatched = true;

    // Patch the sync function to handle onExit errors
    if (result && result.sync) {
      const originalSync = result.sync;
      result.sync = function(file, data, options) {
        try {
          return originalSync.call(this, file, data, options);
        } catch (err) {
          // If onExit is the issue, try with modified options
          if (err.message && err.message.includes('onExit')) {
            // Try with fsync disabled
            try {
              return originalSync.call(this, file, data, { ...options, fsync: false });
            } catch (err2) {
              // Last resort: write directly with fs
              const fs = require('fs');
              return fs.writeFileSync(file, data, options);
            }
          }
          throw err;
        }
      };
    }
  }

  return result;
};
