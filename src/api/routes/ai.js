'use strict';

const { exec } = require('child_process');
const { promisify } = require('util');
const { getLiteLLMStatus, getRufloStatus } = require('../../services/ai-stack');

const execAsync = promisify(exec);

const OPENCLAW_INFO = {
  name: 'OpenClaw',
  version: '1.0.0',
  description: 'AGL Orchestration Layer for Claude AI integration',
  config_path: '/mnt/overpower/apps/dev/agl/agl-hostman/config/openclaw',
  status: 'configured',
};

async function aiRoutes(fastify) {
  fastify.get('/ai/status', async (request, reply) => {
    const [litellm, ruflo] = await Promise.all([
      getLiteLLMStatus(),
      getRufloStatus(),
    ]);

    return {
      litellm,
      ruflo,
      openclaw: OPENCLAW_INFO,
      timestamp: new Date().toISOString(),
    };
  });

  fastify.post('/ai/daemon', async (request, reply) => {
    const { action } = request.body || {};

    if (!action || !['start', 'stop'].includes(action)) {
      return reply.code(400).send({
        error: 'BadRequest',
        message: "action must be 'start' or 'stop'",
      });
    }

    try {
      const cmd = action === 'start'
        ? 'npx ruflo@latest daemon start'
        : 'npx ruflo@latest daemon stop';

      const { stdout, stderr } = await execAsync(cmd, { timeout: 15000 });

      return {
        action,
        success: true,
        output: stdout.trim() || stderr.trim(),
        timestamp: new Date().toISOString(),
      };
    } catch (err) {
      return reply.code(500).send({
        action,
        success: false,
        error: err.message,
        timestamp: new Date().toISOString(),
      });
    }
  });
}

module.exports = aiRoutes;
