/**
 * Hive Mind Memory Injection Wrapper
 *
 * This wrapper fixes the broken inject-memory-protocol import in hive-mind.js
 * by providing a patched version of the module.
 *
 * The original module has a SyntaxError at line 4:
 *   import { promises as fs } from 'fs/promises';
 *
 * This wrapper intercepts the import and returns the corrected module.
 */

import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Path to the patched inject-memory-protocol module
const PATCHED_MODULE_PATH = path.join(__dirname, 'inject-memory-protocol.mjs');

/**
 * Monkey patch for the inject-memory-protocol module
 *
 * This function loads our patched version and makes it available
 * as if it were the original module.
 */
export async function getPatchedMemoryProtocol() {
  try {
    // Import the patched version
    const patchedModule = await import(PATCHED_MODULE_PATH);

    console.log('✅ Using patched inject-memory-protocol module');
    return patchedModule;
  } catch (err) {
    console.error('❌ Failed to load patched module:', err.message);
    throw err;
  }
}

// Export all functions from the patched module
export async function injectMemoryProtocol(projectPath) {
  const module = await getPatchedMemoryProtocol();
  return module.injectMemoryProtocol(projectPath);
}

export async function enhanceHiveMindPrompt(originalPrompt, workers) {
  const module = await getPatchedMemoryProtocol();
  return module.enhanceHiveMindPrompt(originalPrompt, workers);
}

export async function enhanceSwarmPrompt(originalPrompt, agentCount) {
  const module = await getPatchedMemoryProtocol();
  return module.enhanceSwarmPrompt(originalPrompt, agentCount);
}

export function shouldInjectProtocol(flags) {
  // This is synchronous, so we can't use await
  // Import it synchronously by creating a require-like import
  try {
    // For the synchronous version, we'll need to handle differently
    const { shouldInjectProtocol } = require(PATCHED_MODULE_PATH.replace('.mjs', ''));
    return shouldInjectProtocol(flags);
  } catch (err) {
    // Fallback to default behavior
    console.warn('⚠️  Using default protocol injection logic');
    return flags?.claude || flags?.spawn || flags?.['auto-spawn'];
  }
}

export default {
  injectMemoryProtocol,
  enhanceHiveMindPrompt,
  enhanceSwarmPrompt,
  shouldInjectProtocol
};
