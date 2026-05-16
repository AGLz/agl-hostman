'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const SCRIPT = path.join(__dirname, '../../scripts/proxmox/patch-openclaw-litellm-baseurl.py');

test('patch-openclaw-litellm-baseurl.py aplica baseUrl', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'oc-patch-'));
  const jsonPath = path.join(dir, 'openclaw.json');
  fs.writeFileSync(
    jsonPath,
    JSON.stringify({ models: { providers: { openai: { apiKey: 'old', baseUrl: 'http://old:1' } } } }),
    'utf8'
  );

  const r = spawnSync('python3', [SCRIPT, jsonPath, 'http://litellm:4000', 'sk-new'], {
    encoding: 'utf8',
  });
  assert.equal(r.status, 0, r.stderr);

  const data = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
  assert.equal(data.models.providers.openai.baseUrl, 'http://litellm:4000');
  assert.equal(data.models.providers.openai.apiKey, 'sk-new');
});
