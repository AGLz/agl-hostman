'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const PATCH = path.join(__dirname, '../../config/openclaw/openclaw-patch.json');

test('openclaw-patch.json é JSON válido e inclui defaults AGL', () => {
  const patch = JSON.parse(fs.readFileSync(PATCH, 'utf8'));

  assert.strictEqual(patch.gateway?.mode, 'local');
  assert.strictEqual(patch.commands?.bash, false);
  assert.strictEqual(patch.commands?.restart, false);
  assert.strictEqual(patch.channels?.defaults?.heartbeat?.showAlerts, true);

  const d = patch.agents?.defaults;
  assert.strictEqual(d?.model?.primary, 'zai/glm-5');
  assert.ok(Array.isArray(d?.model?.fallbacks) && d.model.fallbacks.length >= 1);

  assert.ok(d?.imageModel?.primary);
  assert.ok(Array.isArray(d?.imageModel?.fallbacks));
  assert.strictEqual(typeof d?.timeoutSeconds, 'number');
  assert.strictEqual(typeof d?.maxConcurrent, 'number');
});
