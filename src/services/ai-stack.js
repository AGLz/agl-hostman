'use strict';

const { exec } = require('child_process');
const { promisify } = require('util');

const execAsync = promisify(exec);

const LITELLM_BASE_URL = process.env.LITELLM_BASE_URL || 'http://localhost:4000';

let fetch;
try {
  fetch = require('node-fetch');
} catch {
  fetch = null;
}

/**
 * Check LiteLLM health via its readiness endpoint.
 * @returns {{ status: string, details: object }}
 */
async function getLiteLLMStatus() {
  if (!fetch) {
    return { status: 'unknown', details: { error: 'node-fetch not available' } };
  }

  try {
    const url = `${LITELLM_BASE_URL}/health/readiness`;
    const response = await fetch(url, { timeout: 5000 });

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
  }
}

/**
 * Check Ruflo daemon status via CLI.
 * @returns {{ status: string, details: object }}
 */
async function getRufloStatus() {
  try {
    const { stdout, stderr } = await execAsync('npx ruflo@latest daemon status', {
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
  getRufloStatus,
};
