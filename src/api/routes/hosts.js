'use strict';

const proxmox = require('../../services/proxmox');

const KNOWN_HOSTS = [
  { id: 'aglsrv1', name: 'AGLSRV1', ip: '192.168.0.245', tailscale: '100.107.113.33', role: 'Proxmox VE - Main' },
  { id: 'aglsrv5', name: 'AGLSRV5', ip: null, tailscale: '100.119.223.113', role: 'Proxmox VE' },
  { id: 'aglsrv6', name: 'AGLSRV6', ip: null, tailscale: '100.98.108.66', role: 'Proxmox VE - Secondary' },
  { id: 'fgsrv3', name: 'FGSRV3', ip: '191.252.201.205', tailscale: '100.67.99.115', role: 'Cloud VPS' },
  { id: 'fgsrv5', name: 'FGSRV5', ip: '191.252.200.20', tailscale: '100.71.107.26', role: 'Cloud VPS / NFS' },
  { id: 'fgsrv6', name: 'FGSRV6', ip: '186.202.57.120', tailscale: '100.83.51.9', role: 'WireGuard Hub' },
  { id: 'fgsrv7', name: 'FGSRV7', ip: '191.252.93.227', tailscale: '100.109.181.93', role: 'Cloud VPS / Cluster' },
];

/**
 * Attempt to fetch live status from Proxmox for a host.
 * Returns null if Proxmox is unreachable or not configured.
 */
async function fetchLiveStatus(host) {
  try {
    // Only Proxmox-backed hosts have node status
    if (!host.id.startsWith('aglsrv')) return null;
    const nodeName = host.id; // e.g. 'aglsrv1'
    const status = await proxmox.getNodeStatus(nodeName);
    if (!status) return null;
    return {
      status: 'online',
      uptime: status.uptime,
      cpu: status.cpu,
      memory: status.memory,
    };
  } catch {
    return null;
  }
}

async function hostsRoutes(fastify) {
  fastify.get('/hosts', async (request, reply) => {
    const results = await Promise.all(
      KNOWN_HOSTS.map(async (host) => {
        const live = await fetchLiveStatus(host);
        return {
          ...host,
          status: live ? live.status : 'unknown',
          live: live || null,
        };
      })
    );

    return {
      hosts: results,
      total: results.length,
      timestamp: new Date().toISOString(),
    };
  });
}

module.exports = hostsRoutes;
