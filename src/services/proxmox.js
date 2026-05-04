'use strict';

const https = require('https');

const PROXMOX_HOST = process.env.PROXMOX_HOST || null;
const TOKEN_ID = process.env.PROXMOX_TOKEN_ID || null;
const TOKEN_SECRET = process.env.PROXMOX_TOKEN_SECRET || null;
const REQUEST_TIMEOUT_MS = parseInt(process.env.PROXMOX_TIMEOUT_MS || '5000', 10);
const TLS_VERIFY = process.env.PROXMOX_TLS_VERIFY === 'true';

let fetchClient;

async function getFetch() {
  if (fetchClient) return fetchClient;
  if (typeof fetch === 'function') {
    fetchClient = fetch;
    return fetchClient;
  }

  try {
    const mod = await import('node-fetch');
    fetchClient = mod.default;
    return fetchClient;
  } catch {
    return null;
  }
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

  const fetchFn = await getFetch();
  if (!fetchFn) return null;

  const url = `https://${PROXMOX_HOST}:8006/api2/json${path}`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  try {
    const response = await fetchFn(url, {
      method: 'GET',
      headers: {
        Authorization: authHeader(),
        'Content-Type': 'application/json',
      },
      agent: new https.Agent({ rejectUnauthorized: TLS_VERIFY }),
      signal: controller.signal,
    });

    if (!response.ok) {
      return null;
    }

    const json = await response.json();
    return json.data || null;
  } catch {
    return null;
  } finally {
    clearTimeout(timeout);
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
