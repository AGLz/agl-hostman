'use strict';

// Disable SSL verification for self-signed Proxmox certificates
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

const PROXMOX_HOST = process.env.PROXMOX_HOST || null;
const TOKEN_ID = process.env.PROXMOX_TOKEN_ID || null;
const TOKEN_SECRET = process.env.PROXMOX_TOKEN_SECRET || null;

let fetch;
try {
  fetch = require('node-fetch');
} catch {
  fetch = null;
}

/**
 * Returns true if Proxmox credentials are configured.
 */
function isConfigured() {
  return !!(PROXMOX_HOST && TOKEN_ID && TOKEN_SECRET);
}

/**
 * Build the Authorization header for Proxmox API token auth.
 */
function authHeader() {
  return `PVEAPIToken=${TOKEN_ID}=${TOKEN_SECRET}`;
}

/**
 * Make a GET request to the Proxmox API.
 * Returns null on any error.
 */
async function apiGet(path) {
  if (!isConfigured()) return null;
  if (!fetch) return null;

  const url = `https://${PROXMOX_HOST}:8006/api2/json${path}`;

  try {
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        Authorization: authHeader(),
        'Content-Type': 'application/json',
      },
      timeout: 5000,
    });

    if (!response.ok) {
      return null;
    }

    const json = await response.json();
    return json.data || null;
  } catch {
    return null;
  }
}

/**
 * Get the status of a Proxmox node.
 * @param {string} nodeName - e.g. 'aglsrv1'
 * @returns {object|null}
 */
async function getNodeStatus(nodeName) {
  return apiGet(`/nodes/${nodeName}/status`);
}

/**
 * Get all LXC containers on a Proxmox node.
 * @param {string} nodeName - e.g. 'aglsrv1'
 * @returns {Array|null}
 */
async function getContainers(nodeName) {
  return apiGet(`/nodes/${nodeName}/lxc`);
}

module.exports = {
  isConfigured,
  getNodeStatus,
  getContainers,
};
