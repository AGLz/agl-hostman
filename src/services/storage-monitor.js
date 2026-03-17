'use strict';

const { exec } = require('child_process');
const { promisify } = require('util');

const execAsync = promisify(exec);

const STATIC_POOLS = [
  { id: 'spark', path: '/mnt/spark', size: '7.1TB', used_pct: 91.54, host: 'aglsrv1', alert: true },
  { id: 'overpower', path: '/mnt/overpower', size: '9.8TB', used_pct: 92.54, host: 'aglsrv1', alert: true },
  { id: 'local-zfs', path: null, size: '1.7TB', used_pct: null, host: 'aglsrv1', alert: false },
  { id: 'fgsrv6-wg', path: '/mnt/pve/fgsrv6-wg', size: '197GB', used_pct: null, host: 'aglsrv1', alert: false },
  { id: 'ct111-sistema', path: '/mnt/pve/ct111-sistema', size: '818GB', used_pct: null, host: 'aglsrv1', alert: false },
];

const KNOWN_PATHS = STATIC_POOLS
  .filter((p) => p.path !== null)
  .map((p) => p.path);

/**
 * Parse `df -h` output into a map of { path -> { size, used_pct } }.
 */
function parseDfOutput(output) {
  const result = {};
  const lines = output.trim().split('\n').slice(1); // skip header

  for (const line of lines) {
    const parts = line.trim().split(/\s+/);
    if (parts.length < 6) continue;

    // df -h columns: Filesystem, Size, Used, Avail, Use%, Mounted on
    const filesystem = parts[0];
    const size = parts[1];
    const usePctStr = parts[4];
    const mountPoint = parts[5];

    const usePct = usePctStr ? parseFloat(usePctStr.replace('%', '')) : null;

    result[mountPoint] = { filesystem, size, used_pct: usePct };
  }

  return result;
}

/**
 * Tries to get live storage data via `df -h`.
 * Falls back to static data on any error.
 * @returns {Array} array of pool objects
 */
async function checkStoragePools() {
  try {
    const { stdout } = await execAsync('df -h', { timeout: 5000 });
    const dfMap = parseDfOutput(stdout);

    return STATIC_POOLS.map((pool) => {
      if (!pool.path || !dfMap[pool.path]) {
        return { ...pool };
      }

      const live = dfMap[pool.path];
      return {
        ...pool,
        size: live.size || pool.size,
        used_pct: live.used_pct !== null ? live.used_pct : pool.used_pct,
        filesystem: live.filesystem,
      };
    });
  } catch {
    // Return static data if df fails
    return STATIC_POOLS.map((p) => ({ ...p }));
  }
}

/**
 * Return pools that exceed the usage threshold.
 * @param {Array} pools
 * @param {number} threshold - percentage (0-100)
 * @returns {Array}
 */
function getAlerts(pools, threshold) {
  return pools.filter(
    (pool) => pool.used_pct !== null && pool.used_pct >= threshold
  );
}

module.exports = {
  checkStoragePools,
  getAlerts,
};
