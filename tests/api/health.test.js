'use strict';

const { test } = require('node:test');
const { build } = require('../../src/api/app');

test('GET /api/health returns 200 and status ok', async (t) => {
  const app = await build({ logger: false, apiKey: '' });
  t.after(() => app.close());

  const res = await app.inject({
    method: 'GET',
    url: '/api/health',
  });

  t.assert.strictEqual(res.statusCode, 200);
  const body = res.json();
  t.assert.strictEqual(body.status, 'ok');
  t.assert.strictEqual(body.service, 'agl-hostman');
  t.assert.ok(body.timestamp);
});
