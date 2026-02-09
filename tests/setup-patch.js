/**
 * Jest Setup Patch
 * Patches write-file-atomic to fix onExit compatibility issue
 */

// Patch write-file-atomic to handle missing onExit function
const fs = require('fs');
const originalWriteFileSync = fs.writeFileSync;

// Store the original before any module loads it
const Module = require('module');
const originalRequire = Module.prototype.require;

Module.prototype.require = function(id) {
  const module = originalRequire.apply(this, arguments);

  // Patch write-file-atomic if loaded
  if (id === 'write-file-atomic') {
    const originalSync = module.sync || module.writeFileSync;
    if (originalSync) {
      return {
        ...module,
        sync: function(file, data, options) {
          try {
            return originalSync.call(this, file, data, { ...options, fsync: false });
          } catch (err) {
            // If onExit is the issue, write directly
            if (err.message && err.message.includes('onExit')) {
              return fs.writeFileSync(file, data, options);
            }
            throw err;
          }
        },
      };
    }
  }

  return module;
};

// Now load the actual setup
require('./setup');
