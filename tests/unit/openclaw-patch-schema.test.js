'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const PATCH = path.join(__dirname, '../../config/openclaw/openclaw-patch.json');

test('openclaw-patch.json é JSON válido e inclui defaults AGL (Z.AI flash)', () => {
  const patch = JSON.parse(fs.readFileSync(PATCH, 'utf8'));

  assert.strictEqual(patch.gateway?.mode, 'local');
  assert.strictEqual(patch.commands?.bash, false);
  assert.strictEqual(patch.commands?.restart, false);
  assert.strictEqual(patch.channels?.defaults?.heartbeat?.showAlerts, true);

  const d = patch.agents?.defaults;
  assert.strictEqual(d?.model?.primary, 'zai/glm-4.7-flash');
  assert.strictEqual(d?.model?.fallbacks?.[0], 'openrouter/deepseek/deepseek-chat');
  assert.ok(d?.model?.fallbacks?.includes('openrouter/z-ai/glm-4.5-air:free'));
  assert.ok(d?.model?.fallbacks?.includes('openrouter/meta-llama/llama-3.3-70b-instruct:free'));
  assert.ok(Array.isArray(d?.model?.fallbacks) && d.model.fallbacks.length >= 4);

  assert.ok(d?.imageModel?.primary);
  assert.ok(Array.isArray(d?.imageModel?.fallbacks));
  assert.strictEqual(typeof d?.timeoutSeconds, 'number');
  assert.strictEqual(typeof d?.maxConcurrent, 'number');

  assert.strictEqual(patch.models, undefined, 'patch não inclui models.providers (evita merge Cerebras/Groq legacy)');
});
