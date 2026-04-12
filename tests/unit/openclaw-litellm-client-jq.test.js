'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const JQ = path.join(__dirname, '../../config/openclaw/openclaw-litellm-client.jq');

test('openclaw-litellm-client.jq: localhost:4000 → agldv03', () => {
  const input = JSON.stringify({
    models: {
      providers: {
        anthropic: { baseUrl: 'http://localhost:4000', apiKey: 'sk-litellm-default' },
        z: { nested: { baseUrl: 'http://127.0.0.1:4000' } },
      },
    },
  });
  const out = execFileSync('jq', ['-f', JQ], { input, encoding: 'utf8' });
  const data = JSON.parse(out);
  assert.strictEqual(data.models.providers.anthropic.baseUrl, 'http://100.94.221.87:4000');
  assert.strictEqual(data.models.providers.z.nested.baseUrl, 'http://100.94.221.87:4000');
});

test('openclaw-litellm-client.jq: ficheiro existe', () => {
  assert.ok(fs.existsSync(JQ));
});
