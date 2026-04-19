'use strict';

const { test } = require('node:test');
const { build } = require('../../src/api/app');

test('GET /api/unknown returns 404', async (t) => {
  const app = await build({ logger: false, apiKey: '' });
  t.after(() => app.close());

  const res = await app.inject({
    method: 'GET',
    url: '/api/unknown',
  });

  t.assert.strictEqual(res.statusCode, 404);
  const body = res.json();
  t.assert.strictEqual(body.error, 'NotFound');
});
