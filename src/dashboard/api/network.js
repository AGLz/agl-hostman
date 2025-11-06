/**
 * Network Monitor
 * Monitor WireGuard, Tailscale, and network connectivity
 */

const { exec } = require('child_process');
const { promisify } = require('util');
const logger = require('../utils/logger');

const execAsync = promisify(exec);

class NetworkMonitor {
  constructor(config) {
    this.config = config;
  }

  /**
   * Execute command safely
   */
  async execCommand(command) {
    try {
      const { stdout, stderr } = await execAsync(command);
      if (stderr) {
        logger.warn(`Command stderr: ${stderr}`);
      }
      return stdout.trim();
    } catch (error) {
      logger.error(`Command failed: ${command}`, error.message);
      return null;
    }
  }

  /**
   * Get WireGuard status
   */
  async getWireGuardStatus() {
    if (!this.config.wireguard.enabled) {
      return { enabled: false };
    }

    try {
      const output = await this.execCommand('wg show');
      if (!output) {
        return { enabled: true, status: 'unavailable' };
      }

      // Parse WireGuard output
      const peers = [];
      const lines = output.split('\n');
      let currentPeer = null;

      for (const line of lines) {
        if (line.startsWith('peer:')) {
          if (currentPeer) peers.push(currentPeer);
          currentPeer = { publicKey: line.split(':')[1].trim() };
        } else if (line.includes('endpoint:') && currentPeer) {
          currentPeer.endpoint = line.split(':').slice(1).join(':').trim();
        } else if (line.includes('allowed ips:') && currentPeer) {
          currentPeer.allowedIPs = line.split(':')[1].trim();
        } else if (line.includes('latest handshake:') && currentPeer) {
          currentPeer.latestHandshake = line.split(':').slice(1).join(':').trim();
        }
      }

      if (currentPeer) peers.push(currentPeer);

      return {
        enabled: true,
        status: 'active',
        interface: this.config.wireguard.interface,
        peers: peers.length,
        details: peers,
      };
    } catch (error) {
      logger.error('Failed to get WireGuard status:', error.message);
      return { enabled: true, status: 'error', error: error.message };
    }
  }

  /**
   * Get Tailscale status
   */
  async getTailscaleStatus() {
    if (!this.config.tailscale.enabled) {
      return { enabled: false };
    }

    try {
      const output = await this.execCommand('tailscale status --json');
      if (!output) {
        return { enabled: true, status: 'unavailable' };
      }

      const status = JSON.parse(output);
      return {
        enabled: true,
        status: 'active',
        self: status.Self,
        peers: Object.keys(status.Peer || {}).length,
      };
    } catch (error) {
      logger.error('Failed to get Tailscale status:', error.message);
      return { enabled: true, status: 'error', error: error.message };
    }
  }

  /**
   * Get network interfaces
   */
  async getInterfaces() {
    try {
      const output = await this.execCommand('ip -j addr show');
      if (!output) return [];

      const interfaces = JSON.parse(output);
      return interfaces
        .filter(iface => iface.operstate === 'UP')
        .map(iface => ({
          name: iface.ifname,
          state: iface.operstate,
          addresses: iface.addr_info.map(addr => ({
            address: addr.local,
            family: addr.family,
            prefixlen: addr.prefixlen,
          })),
        }));
    } catch (error) {
      logger.error('Failed to get network interfaces:', error.message);
      return [];
    }
  }

  /**
   * Get complete network status
   */
  async getStatus() {
    const [wireguard, tailscale, interfaces] = await Promise.all([
      this.getWireGuardStatus(),
      this.getTailscaleStatus(),
      this.getInterfaces(),
    ]);

    return {
      wireguard,
      tailscale,
      interfaces,
      timestamp: new Date().toISOString(),
    };
  }
}

module.exports = NetworkMonitor;
