'use strict';

require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

const fastify = require('fastify')({ logger: true });
const cors = require('@fastify/cors');

const hostsRoutes = require('./routes/hosts');
const storageRoutes = require('./routes/storage');
const aiRoutes = require('./routes/ai');

const PORT = parseInt(process.env.HOSTMAN_PORT || '3030', 10);
const API_KEY = process.env.HOSTMAN_API_KEY || '';

// Register CORS
fastify.register(cors, {
  origin: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
});

// Bearer token auth hook — skips /api/health
fastify.addHook('onRequest', async (request, reply) => {
  if (!API_KEY) return; // No key configured — open access
  if (request.url === '/api/health') return; // Health check is public

  const authHeader = request.headers['authorization'] || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';

  if (token !== API_KEY) {
    reply.code(401).send({ error: 'Unauthorized', message: 'Valid Bearer token required' });
  }
});

// Health check — no auth required
fastify.get('/api/health', async (request, reply) => {
  return { status: 'ok', timestamp: new Date().toISOString(), service: 'agl-hostman' };
});

// Mount route modules
fastify.register(hostsRoutes, { prefix: '/api' });
fastify.register(storageRoutes, { prefix: '/api' });
fastify.register(aiRoutes, { prefix: '/api' });

// Global error handler
fastify.setErrorHandler((error, request, reply) => {
  fastify.log.error(error);
  const code = error.statusCode || 500;
  reply.code(code).send({
    error: error.name || 'InternalServerError',
    message: error.message || 'An unexpected error occurred',
  });
});

// 404 handler
fastify.setNotFoundHandler((request, reply) => {
  reply.code(404).send({ error: 'NotFound', message: `Route ${request.method} ${request.url} not found` });
});

const start = async () => {
  try {
    await fastify.listen({ port: PORT, host: '0.0.0.0' });
    fastify.log.info(`agl-hostman API listening on port ${PORT}`);
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};

start();
