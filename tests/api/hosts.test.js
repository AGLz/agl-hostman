'use strict';

const { test } = require('node:test');
const { build } = require('../../src/api/app');

test('GET /api/hosts returns hosts array', async (t) => {
  const app = await build({ logger: false, apiKey: '' });
  t.after(() => app.close());

  const res = await app.inject({
    method: 'GET',
    url: '/api/hosts',
  });

  t.assert.strictEqual(res.statusCode, 200);
  const body = res.json();
  t.assert.ok(Array.isArray(body.hosts));
  t.assert.ok(typeof body.total === 'number');
  t.assert.ok(body.hosts.length >= 1);
  t.assert.ok(body.hosts[0].id);
  t.assert.ok(body.hosts[0].name);
  t.assert.ok(body.timestamp);
});
