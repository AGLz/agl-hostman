/**
 * Mock MCP Memory Server
 * Provides memory_usage function for testing when MCP server is unavailable
 * Implements in-memory storage with JSON serialization
 */

// In-memory storage
const memoryStore = new Map();

/**
 * Mock memory_usage function matching MCP server interface
 * @param {object} params - Memory operation parameters
 * @returns {Promise<any>} Result of memory operation
 */
export async function memory_usage(params) {
  const { action, key, namespace, value, pattern, limit } = params;

  // Create composite key for namespacing
  const compositeKey = namespace ? `${namespace}:${key}` : key;

  switch (action) {
    case 'store':
      // Store value
      memoryStore.set(compositeKey, value);
      return value;

    case 'retrieve':
      // Retrieve value
      return memoryStore.get(compositeKey) || null;

    case 'delete':
      // Delete value
      const deleted = memoryStore.has(compositeKey);
      memoryStore.delete(compositeKey);
      return deleted ? compositeKey : null;

    case 'search':
      // Search for keys matching pattern
      const searchResults = [];
      const regex = new RegExp(pattern, 'i');
      const count = limit || 10;

      for (const [storedKey, storedValue] of memoryStore.entries()) {
        if (searchResults.length >= count) break;

        if (namespace && !storedKey.startsWith(`${namespace}:`)) continue;
        if (regex.test(storedKey)) {
          searchResults.push({
            key: storedKey.replace(`${namespace}:`, ''),
            namespace,
            value: storedValue
          });
        }
      }

      return searchResults;

    case 'list':
      // List all keys in namespace
      const keys = [];
      for (const storedKey of memoryStore.keys()) {
        if (namespace && storedKey.startsWith(`${namespace}:`)) {
          keys.push(storedKey.replace(`${namespace}:`, ''));
        }
      }
      return keys;

    default:
      throw new Error(`Unknown action: ${action}`);
  }
}

/**
 * Clear all memory (for testing)
 */
export function clearMemory() {
  memoryStore.clear();
}

/**
 * Get memory store size (for debugging)
 */
export function getMemorySize() {
  return memoryStore.size;
}
