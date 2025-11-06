/**
 * Proxmox API Client
 * Interface for Proxmox VE API
 */

const axios = require('axios');
const https = require('https');
const logger = require('../utils/logger');

class ProxmoxAPI {
  constructor(config) {
    this.config = config.primary;
    this.baseURL = `https://${this.config.host}:${this.config.port}/api2/json`;

    // Create axios instance with SSL verification disabled (for self-signed certs)
    this.client = axios.create({
      baseURL: this.baseURL,
      httpsAgent: new https.Agent({
        rejectUnauthorized: this.config.verifySSL || false,
      }),
      timeout: 10000,
    });

    // Token for authentication
    this.token = null;
    this.tokenExpiry = null;
  }

  /**
   * Authenticate with Proxmox API
   */
  async authenticate() {
    try {
      // Use API token if available (recommended)
      if (this.config.tokenId && this.config.tokenSecret) {
        this.token = `PVEAPIToken=${this.config.username}!${this.config.tokenId}=${this.config.tokenSecret}`;
        this.tokenExpiry = Date.now() + (7200 * 1000); // 2 hours
        logger.debug('Using API token authentication');
        return;
      }

      // Fallback to username/password
      if (this.config.password) {
        const response = await this.client.post('/access/ticket', {
          username: this.config.username,
          password: this.config.password,
        });

        this.token = response.data.data.ticket;
        this.tokenExpiry = Date.now() + (7200 * 1000); // 2 hours
        logger.debug('Authenticated with username/password');
        return;
      }

      throw new Error('No authentication credentials provided');
    } catch (error) {
      logger.error('Proxmox authentication failed:', error.message);
      throw error;
    }
  }

  /**
   * Check if token is valid
   */
  isTokenValid() {
    return this.token && this.tokenExpiry && Date.now() < this.tokenExpiry;
  }

  /**
   * Make authenticated API request
   */
  async request(method, endpoint, data = null) {
    // Ensure we're authenticated
    if (!this.isTokenValid()) {
      await this.authenticate();
    }

    const config = {
      method,
      url: endpoint,
      headers: this.config.tokenId
        ? { Authorization: this.token }
        : { Cookie: `PVEAuthCookie=${this.token}` },
    };

    if (data) {
      config.data = data;
    }

    try {
      const response = await this.client.request(config);
      return response.data.data;
    } catch (error) {
      logger.error(`Proxmox API request failed: ${method} ${endpoint}`, error.message);
      throw error;
    }
  }

  /**
   * Get infrastructure overview
   */
  async getOverview() {
    try {
      const nodes = await this.request('GET', '/nodes');
      const overview = {
        nodes: [],
        totalCPU: 0,
        totalMemory: 0,
        totalDisk: 0,
        containers: 0,
        vms: 0,
      };

      for (const node of nodes) {
        const nodeStatus = await this.request('GET', `/nodes/${node.node}/status`);
        const containers = await this.request('GET', `/nodes/${node.node}/lxc`);
        const vms = await this.request('GET', `/nodes/${node.node}/qemu`);

        overview.nodes.push({
          name: node.node,
          status: node.status,
          cpu: nodeStatus.cpu,
          memory: {
            used: nodeStatus.memory.used,
            total: nodeStatus.memory.total,
            percent: (nodeStatus.memory.used / nodeStatus.memory.total) * 100,
          },
          uptime: nodeStatus.uptime,
          containers: containers.length,
          vms: vms.length,
        });

        overview.containers += containers.length;
        overview.vms += vms.length;
      }

      return overview;
    } catch (error) {
      logger.error('Failed to get Proxmox overview:', error.message);
      throw error;
    }
  }

  /**
   * Get list of containers
   */
  async getContainers() {
    try {
      const nodes = await this.request('GET', '/nodes');
      const allContainers = [];

      for (const node of nodes) {
        const containers = await this.request('GET', `/nodes/${node.node}/lxc`);
        allContainers.push(...containers.map(ct => ({
          ...ct,
          node: node.node,
          type: 'lxc',
        })));
      }

      return allContainers;
    } catch (error) {
      logger.error('Failed to get containers:', error.message);
      throw error;
    }
  }

  /**
   * Get storage status
   */
  async getStorage() {
    try {
      const nodes = await this.request('GET', '/nodes');
      const allStorage = [];

      for (const node of nodes) {
        const storage = await this.request('GET', `/nodes/${node.node}/storage`);
        allStorage.push(...storage.map(s => ({
          ...s,
          node: node.node,
          usedPercent: (s.used / s.total) * 100,
        })));
      }

      return allStorage;
    } catch (error) {
      logger.error('Failed to get storage:', error.message);
      throw error;
    }
  }
}

module.exports = ProxmoxAPI;
