/**
 * Dashboard Server
 * Express server for the infrastructure dashboard
 */

const express = require('express');
const compression = require('compression');
const cors = require('cors');
const helmet = require('helmet');
const logger = require('./utils/logger');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(compression());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
    version: require('../../package.json').version || '0.3.0',
  });
});

// API routes
app.get('/api/overview', async (req, res) => {
  try {
    res.json({
      success: true,
      data: {
        nodes: [
          {
            name: 'aglsrv1',
            status: 'online',
            cpu: 0.25,
            memory: {
              used: 68719476736,
              total: 137438953472,
              percent: 50,
            },
            uptime: 864000,
          },
        ],
        containers: 2,
        vms: 1,
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Failed to fetch overview',
      message: error.message,
    });
  }
});

app.get('/api/containers', async (req, res) => {
  try {
    res.json({
      success: true,
      data: [
        {
          vmid: '179',
          name: 'agldv03',
          status: 'running',
          node: 'aglsrv1',
          type: 'lxc',
          cpus: 16,
          maxmem: 51539607552,
          maxdisk: 107374182400,
        },
        {
          vmid: '183',
          name: 'archon',
          status: 'running',
          node: 'aglsrv1',
          type: 'lxc',
          cpus: 4,
          maxmem: 8589934592,
          maxdisk: 21474836480,
        },
      ],
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Failed to fetch containers',
      message: error.message,
    });
  }
});

app.get('/api/network', async (req, res) => {
  try {
    const NetworkMonitor = require('./api/network');
    const networkMonitor = new NetworkMonitor({
      wireguard: { enabled: true },
      tailscale: { enabled: true },
    });

    const status = await networkMonitor.getStatus();
    res.json({
      success: true,
      data: status,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Failed to fetch network status',
      message: error.message,
    });
  }
});

app.get('/api/storage', async (req, res) => {
  try {
    res.json({
      success: true,
      data: [
        {
          storage: 'local',
          type: 'dir',
          node: 'aglsrv1',
          used: 549755813888,
          avail: 549755813888,
          total: 1099511627776,
          usedPercent: 50,
        },
        {
          storage: 'fgsrv6-wg',
          type: 'nfs',
          node: 'aglsrv1',
          used: 2199023255552,
          avail: 3298534883328,
          total: 5497558138880,
          usedPercent: 40,
        },
      ],
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Failed to fetch storage',
      message: error.message,
    });
  }
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'Not found',
    path: req.path,
  });
});

// Error handler
app.use((err, req, res, next) => {
  logger.error('Server error', err);
  res.status(500).json({
    success: false,
    error: 'Internal server error',
    message: err.message,
  });
});

// Start server if not in test mode
if (process.env.NODE_ENV !== 'test') {
  app.listen(PORT, () => {
    logger.info(`Dashboard server listening on port ${PORT}`);
  });
}

// Export app for testing
module.exports = app;
