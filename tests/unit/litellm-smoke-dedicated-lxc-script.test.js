'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const SCRIPT = path.join(__dirname, '../../scripts/litellm/smoke-dedicated-lxc.sh');

test('smoke-dedicated-lxc.sh existe e é executável', () => {
  assert.ok(fs.existsSync(SCRIPT));
  const mode = fs.statSync(SCRIPT).mode;
  assert.ok(mode & 0o111, 'script deve ser executável');
});
