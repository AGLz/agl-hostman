'use strict';

const { test } = require('node:test');
const { build } = require('../../src/api/app');

test('when API_KEY set, /api/health is public', async (t) => {
  const app = await build({ logger: false, apiKey: 'secret123' });
  t.after(() => app.close());

  const res = await app.inject({
    method: 'GET',
    url: '/api/health',
  });

  t.assert.strictEqual(res.statusCode, 200);
});

test('when API_KEY set, /api/hosts without token returns 401', async (t) => {
  const app = await build({ logger: false, apiKey: 'secret123' });
  t.after(() => app.close());

  const res = await app.inject({
    method: 'GET',
    url: '/api/hosts',
  });

  t.assert.strictEqual(res.statusCode, 401);
});

test('when API_KEY set, /api/hosts with Bearer token returns 200', async (t) => {
  const app = await build({ logger: false, apiKey: 'secret123' });
  t.after(() => app.close());

  const res = await app.inject({
    method: 'GET',
    url: '/api/hosts',
    headers: { authorization: 'Bearer secret123' },
  });

  t.assert.strictEqual(res.statusCode, 200);
});
