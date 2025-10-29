/**
 * agl-hostman Dashboard Server
 * Lightweight monitoring dashboard for AGL infrastructure
 */

const express = require('express');
const path = require('path');
const cors = require('cors');
const compression = require('compression');
const helmet = require('helmet');

// Configuration
const config = require('../../config/dashboard.config');
const logger = require('./utils/logger');
const ProxmoxAPI = require('./api/proxmox');
const NetworkMonitor = require('./api/network');

// Initialize Express app
const app = express();

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));

// CORS configuration
app.use(cors({
  origin: config.cors.origin,
  methods: config.cors.methods,
}));

// Compression
app.use(compression());

// Body parsing
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Static files (dashboard UI)
app.use(express.static(path.join(__dirname, 'public')));

// ============================================================================
// Health Check Endpoint
// ============================================================================
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: config.env,
    version: config.version,
  });
});

// ============================================================================
// API Endpoints
// ============================================================================

// Get infrastructure overview
app.get('/api/overview', async (req, res) => {
  try {
    const proxmox = new ProxmoxAPI(config.proxmox);
    const overview = await proxmox.getOverview();

    res.json({
      success: true,
      data: overview,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('Failed to fetch overview:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch infrastructure overview',
      message: error.message,
    });
  }
});

// Get container list
app.get('/api/containers', async (req, res) => {
  try {
    const proxmox = new ProxmoxAPI(config.proxmox);
    const containers = await proxmox.getContainers();

    res.json({
      success: true,
      data: containers,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('Failed to fetch containers:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch container list',
      message: error.message,
    });
  }
});

// Get network status (WireGuard, Tailscale)
app.get('/api/network', async (req, res) => {
  try {
    const network = new NetworkMonitor(config.network);
    const status = await network.getStatus();

    res.json({
      success: true,
      data: status,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('Failed to fetch network status:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch network status',
      message: error.message,
    });
  }
});

// Get storage status
app.get('/api/storage', async (req, res) => {
  try {
    const proxmox = new ProxmoxAPI(config.proxmox);
    const storage = await proxmox.getStorage();

    res.json({
      success: true,
      data: storage,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('Failed to fetch storage status:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch storage status',
      message: error.message,
    });
  }
});

// ============================================================================
// Error Handling
// ============================================================================
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  res.status(500).json({
    success: false,
    error: 'Internal server error',
    message: config.env === 'development' ? err.message : 'An error occurred',
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'Not found',
    path: req.path,
  });
});

// ============================================================================
// Server Startup
// ============================================================================
const PORT = config.port;
const server = app.listen(PORT, '0.0.0.0', () => {
  logger.info(`agl-hostman dashboard started on port ${PORT}`);
  logger.info(`Environment: ${config.env}`);
  logger.info(`Health check: http://localhost:${PORT}/health`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully...');
  server.close(() => {
    logger.info('Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully...');
  server.close(() => {
    logger.info('Server closed');
    process.exit(0);
  });
});

module.exports = app;
