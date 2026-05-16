'use strict';

const fastify = require('fastify');
const cors = require('@fastify/cors');
const hostsRoutes = require('./routes/hosts');
const storageRoutes = require('./routes/storage');
const aiRoutes = require('./routes/ai');
const { parseCorsOrigin } = require('./cors-origin');

/**
 * Build Fastify app for server or testing.
 * @param {Object} opts - Options (logger, apiKey, etc.)
 * @returns {Promise<import('fastify').FastifyInstance>}
 */
async function build(opts = {}) {
  const logger = opts.logger !== false;
  const apiKey = opts.apiKey ?? process.env.HOSTMAN_API_KEY ?? '';
  const corsOrigin = opts.corsOrigin ?? parseCorsOrigin(process.env.HOSTMAN_CORS_ORIGIN) ?? true;

  const app = fastify({ logger });
  await app.register(cors, {
    origin: corsOrigin,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  });

  if (apiKey) {
    app.addHook('onRequest', async (request, reply) => {
      if (request.url === '/api/health') return;
      const authHeader = request.headers['authorization'] || '';
      const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
      if (token !== apiKey) {
        reply.code(401).send({ error: 'Unauthorized', message: 'Valid Bearer token required' });
      }
    });
  }

  app.get('/api/health', async () => ({
    status: 'ok',
    timestamp: new Date().toISOString(),
    service: 'agl-hostman',
  }));

  await app.register(hostsRoutes, { prefix: '/api' });
  await app.register(storageRoutes, { prefix: '/api' });
  await app.register(aiRoutes, { prefix: '/api' });

  app.setErrorHandler((error, request, reply) => {
    app.log.error(error);
    reply.code(error.statusCode || 500).send({
      error: error.name || 'InternalServerError',
      message: error.message || 'An unexpected error occurred',
    });
  });

  app.setNotFoundHandler((request, reply) => {
    reply.code(404).send({
      error: 'NotFound',
      message: `Route ${request.method} ${request.url} not found`,
    });
  });

  return app;
}

module.exports = { build, parseCorsOrigin };
