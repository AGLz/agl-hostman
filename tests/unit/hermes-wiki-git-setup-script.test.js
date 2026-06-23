'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '../..');
const SCRIPT = path.join(ROOT, 'scripts/proxmox/setup-hermes-wiki-git-ct188.sh');

test('setup-hermes-wiki-git-ct188.sh configura safe.directory e perfis', () => {
  assert.ok(fs.existsSync(SCRIPT));
  assert.ok(fs.statSync(SCRIPT).mode & 0o111);
  const content = fs.readFileSync(SCRIPT, 'utf8');
  assert.match(content, /safe\.directory/);
  assert.match(content, /\.git-credentials/);
  assert.match(content, /curator/);
  assert.match(content, /--push/);
});
