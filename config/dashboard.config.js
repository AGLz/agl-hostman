/**
 * Dashboard Configuration
 * Central configuration for agl-hostman dashboard
 */

require('dotenv').config();

module.exports = {
  // Application
  env: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT, 10) || 3000,
  version: require('../package.json').version || '1.0.0',

  // Logging
  logging: {
    level: process.env.LOG_LEVEL || 'info',
    format: process.env.LOG_FORMAT || 'json',
    file: process.env.LOG_FILE_PATH || '/app/logs/app.log',
    maxSize: process.env.LOG_MAX_SIZE || '10m',
    maxFiles: parseInt(process.env.LOG_MAX_FILES, 10) || 5,
  },

  // CORS
  cors: {
    origin: process.env.CORS_ORIGIN || '*',
    methods: (process.env.CORS_METHODS || 'GET,POST').split(','),
  },

  // Proxmox Configuration
  proxmox: {
    primary: {
      host: process.env.PROXMOX_HOST || '192.168.0.245',
      port: parseInt(process.env.PROXMOX_PORT, 10) || 8006,
      username: process.env.PROXMOX_USER || 'root@pam',
      tokenId: process.env.PROXMOX_TOKEN_ID,
      tokenSecret: process.env.PROXMOX_TOKEN_SECRET,
      password: process.env.PROXMOX_PASSWORD, // Fallback
      verifySSL: process.env.PROXMOX_VERIFY_SSL === 'true',
    },
    secondary: {
      enabled: !!process.env.PROXMOX_SECONDARY_HOST,
      host: process.env.PROXMOX_SECONDARY_HOST || '10.6.0.12',
      port: parseInt(process.env.PROXMOX_SECONDARY_PORT, 10) || 8006,
      username: process.env.PROXMOX_SECONDARY_USER || 'root@pam',
      tokenId: process.env.PROXMOX_SECONDARY_TOKEN_ID,
      tokenSecret: process.env.PROXMOX_SECONDARY_TOKEN_SECRET,
      verifySSL: process.env.PROXMOX_SECONDARY_VERIFY_SSL === 'true',
    },
  },

  // Network Monitoring
  network: {
    wireguard: {
      enabled: process.env.WIREGUARD_ENABLED === 'true',
      interface: process.env.WIREGUARD_INTERFACE || 'wg0',
      network: process.env.WIREGUARD_NETWORK || '10.6.0.0/24',
    },
    tailscale: {
      enabled: process.env.TAILSCALE_ENABLED === 'true',
    },
  },

  // Dashboard Settings
  dashboard: {
    refreshInterval: parseInt(process.env.REFRESH_INTERVAL, 10) || 30000,
    enableRealtimeUpdates: process.env.ENABLE_REALTIME_UPDATES === 'true',
    maxHistoryPoints: parseInt(process.env.MAX_HISTORY_POINTS, 10) || 100,
  },

  // Monitoring Thresholds
  monitoring: {
    healthCheckInterval: parseInt(process.env.HEALTH_CHECK_INTERVAL, 10) || 60000,
    thresholds: {
      cpu: parseInt(process.env.ALERT_THRESHOLD_CPU, 10) || 90,
      memory: parseInt(process.env.ALERT_THRESHOLD_MEMORY, 10) || 85,
      disk: parseInt(process.env.ALERT_THRESHOLD_DISK, 10) || 80,
    },
  },

  // Storage Configuration
  storage: {
    nfsMounts: (process.env.NFS_MOUNTS || '').split(',').filter(Boolean),
  },

  // Security
  security: {
    enableAuth: process.env.ENABLE_AUTH === 'true',
    adminUsername: process.env.ADMIN_USERNAME || 'admin',
    adminPassword: process.env.ADMIN_PASSWORD,
  },

  // Integration with other services
  integrations: {
    archon: {
      enabled: process.env.ARCHON_ENABLED === 'true',
      host: process.env.ARCHON_HOST || '10.6.0.21',
      port: parseInt(process.env.ARCHON_PORT, 10) || 8051,
    },
    harbor: {
      enabled: process.env.HARBOR_ENABLED === 'true',
      url: process.env.HARBOR_URL,
      username: process.env.HARBOR_USERNAME,
      password: process.env.HARBOR_PASSWORD,
    },
  },
};
