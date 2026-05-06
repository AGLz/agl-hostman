'use strict';

const { exec } = require('child_process');
const { promisify } = require('util');

const execAsync = promisify(exec);

const LITELLM_BASE_URL = process.env.LITELLM_BASE_URL || 'http://100.125.249.8:4000';
const OPENCLAW_BASE_URL = process.env.OPENCLAW_BASE_URL || 'http://100.123.184.125:28789';
const HTTP_TIMEOUT_MS = parseInt(process.env.HOSTMAN_HTTP_TIMEOUT_MS || '5000', 10);
const RUFLO_COMMAND = process.env.RUFLO_COMMAND || 'ruflo';

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
 * Check LiteLLM health via its readiness endpoint.
 * @returns {{ status: string, details: object }}
 */
async function getLiteLLMStatus() {
  const fetchFn = await getFetch();
  if (!fetchFn) {
    return { status: 'unknown', details: { error: 'node-fetch not available' } };
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), HTTP_TIMEOUT_MS);

  try {
    const url = `${LITELLM_BASE_URL}/health/readiness`;
    const response = await fetchFn(url, { signal: controller.signal });

    if (response.ok) {
      let details = {};
      try {
        details = await response.json();
      } catch {
        details = { http_status: response.status };
      }
      return { status: 'online', details };
    }

    return {
      status: 'degraded',
      details: { http_status: response.status, url },
    };
  } catch (err) {
    return {
      status: 'offline',
      details: { error: err.message, url: `${LITELLM_BASE_URL}/health/readiness` },
    };
  } finally {
    clearTimeout(timeout);
  }
}

/**
 * Check OpenClaw gateway health on CT187.
 * @returns {{ status: string, details: object }}
 */
async function getOpenClawStatus() {
  const fetchFn = await getFetch();
  if (!fetchFn) {
    return { status: 'unknown', details: { error: 'node-fetch not available' } };
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), HTTP_TIMEOUT_MS);
  const url = `${OPENCLAW_BASE_URL}/healthz`;

  try {
    const response = await fetchFn(url, { signal: controller.signal });

    if (response.ok) {
      let details = {};
      try {
        details = await response.json();
      } catch {
        details = { http_status: response.status };
      }
      return { status: 'online', details: { ...details, url } };
    }

    return {
      status: 'degraded',
      details: { http_status: response.status, url },
    };
  } catch (err) {
    return {
      status: 'offline',
      details: { error: err.message, url },
    };
  } finally {
    clearTimeout(timeout);
  }
}

/**
 * Check Ruflo daemon status via CLI.
 * @returns {{ status: string, details: object }}
 */
async function getRufloStatus() {
  try {
    const { stdout, stderr } = await execAsync(`${RUFLO_COMMAND} daemon status`, {
      timeout: 10000,
    });

    const output = (stdout + stderr).toLowerCase();
    const running = output.includes('running') || output.includes('active');

    return {
      status: running ? 'running' : 'stopped',
      details: { output: (stdout + stderr).trim() },
    };
  } catch (err) {
    const output = (err.stdout || '') + (err.stderr || '');
    const stopped = output.toLowerCase().includes('not running') ||
      output.toLowerCase().includes('stopped') ||
      output.toLowerCase().includes('inactive');

    return {
      status: stopped ? 'stopped' : 'unknown',
      details: { error: err.message, output: output.trim() },
    };
  }
}

module.exports = {
  getLiteLLMStatus,
  getOpenClawStatus,
  getRufloStatus,
};
