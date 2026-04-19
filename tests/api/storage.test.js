'use strict';

const { test } = require('node:test');
const { build } = require('../../src/api/app');

test('GET /api/storage returns pools and alerts', async (t) => {
  const app = await build({ logger: false, apiKey: '' });
  t.after(() => app.close());

  const res = await app.inject({
    method: 'GET',
    url: '/api/storage',
  });

  t.assert.strictEqual(res.statusCode, 200);
  const body = res.json();
  t.assert.ok(Array.isArray(body.pools));
  t.assert.ok(Array.isArray(body.alerts));
  t.assert.ok(typeof body.alert_threshold === 'number');
  t.assert.ok(body.timestamp);
});
