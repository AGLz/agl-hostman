'use strict';

const { exec } = require('child_process');
const { promisify } = require('util');
const { getLiteLLMStatus, getOpenClawStatus, getRufloStatus } = require('../../services/ai-stack');

const execAsync = promisify(exec);

const RUFLO_COMMAND = process.env.RUFLO_COMMAND || 'ruflo';

const OPENCLAW_INFO = {
  name: 'OpenClaw',
  version: '1.0.0',
  description: 'AGL OpenClaw/Jarvis runtime on AGLSRV1 CT187',
  ct: 'CT187',
  host: 'agl-openclaw',
  tailscale_ip: '100.123.184.125',
  lan_ip: '192.168.0.187',
  base_url: process.env.OPENCLAW_BASE_URL || 'http://100.123.184.125:28789',
  config_path: '/mnt/overpower/apps/dev/agl/agl-hostman/config/openclaw',
  status: 'configured',
};

async function aiRoutes(fastify) {
  fastify.get('/ai/status', async (_request, _reply) => {
    const [litellm, openclawStatus, ruflo] = await Promise.all([
      getLiteLLMStatus(),
      getOpenClawStatus(),
      getRufloStatus(),
    ]);

    return {
      litellm,
      ruflo,
      openclaw: {
        ...OPENCLAW_INFO,
        status: openclawStatus.status,
        details: openclawStatus.details,
      },
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
      const cmd = `${RUFLO_COMMAND} daemon ${action}`;

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
