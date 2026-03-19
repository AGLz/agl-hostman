'use strict';

const { checkStoragePools, getAlerts } = require('../../services/storage-monitor');

const ALERT_THRESHOLD = parseInt(process.env.STORAGE_ALERT_THRESHOLD || '90', 10);

async function storageRoutes(fastify) {
  fastify.get('/storage', async (_request, _reply) => {
    let pools = [];
    let source = 'static';

    try {
      const liveData = await checkStoragePools();
      if (liveData && liveData.length > 0) {
        pools = liveData;
        source = 'live';
      }
    } catch {
      // Fall through to static data
    }

    const alerts = getAlerts(pools, ALERT_THRESHOLD);

    return {
      pools,
      alerts,
      alert_threshold: ALERT_THRESHOLD,
      source,
      timestamp: new Date().toISOString(),
    };
  });
}

module.exports = storageRoutes;
