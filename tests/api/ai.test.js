'use strict';

const { test } = require('node:test');
const { build } = require('../../src/api/app');

test('GET /api/ai/status returns litellm, ruflo, openclaw', async (t) => {
  const app = await build({ logger: false, apiKey: '' });
  t.after(() => app.close());

  const res = await app.inject({
    method: 'GET',
    url: '/api/ai/status',
  });

  t.assert.strictEqual(res.statusCode, 200);
  const body = res.json();
  t.assert.ok(body.litellm !== undefined);
  t.assert.ok(body.ruflo !== undefined);
  t.assert.ok(body.openclaw !== undefined);
  t.assert.ok(body.openclaw.name === 'OpenClaw');
  t.assert.ok(body.timestamp);
});
