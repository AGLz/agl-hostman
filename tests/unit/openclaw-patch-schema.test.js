'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const PATCH = path.join(__dirname, '../../config/openclaw/openclaw-patch.json');

test('openclaw-patch.json é JSON válido e inclui defaults AGL (agl-primary + fallbacks LiteLLM)', () => {
  const patch = JSON.parse(fs.readFileSync(PATCH, 'utf8'));

  assert.strictEqual(patch.gateway?.mode, 'local');
  assert.strictEqual(patch.commands?.bash, false);
  assert.strictEqual(patch.commands?.restart, false);
  assert.strictEqual(patch.channels?.defaults?.heartbeat?.showAlerts, true);

  const d = patch.agents?.defaults;
  assert.strictEqual(d?.model?.primary, 'openai/agl-primary');
  assert.ok(d?.model?.fallbacks?.includes('openrouter/z-ai/glm-4.5-air:free'));
  assert.ok(d?.model?.fallbacks?.includes('openrouter/meta-llama/llama-3.3-70b-instruct:free'));
  assert.ok(Array.isArray(d?.model?.fallbacks) && d.model.fallbacks.length >= 3);
  assert.ok(!d?.model?.fallbacks?.includes('zai/glm-4.7-flash'), 'sem Z.AI direto');
  assert.ok(!d?.model?.fallbacks?.includes('zai/glm-5'), 'sem Z.AI direto');

  assert.ok(d?.imageModel?.primary);
  assert.ok(Array.isArray(d?.imageModel?.fallbacks));
  assert.strictEqual(typeof d?.timeoutSeconds, 'number');
  assert.strictEqual(typeof d?.maxConcurrent, 'number');

  assert.ok(d?.models?.['openai/agl-primary'], 'patch inclui alias agl-primary LiteLLM');
  assert.ok(d?.models?.['dashscope/qwen3.5-flash'], 'patch inclui qwen3.5-flash alias');
  assert.ok(d?.models?.['dashscope/qwen-coder'], 'patch inclui qwen-coder alias');
  assert.ok(d?.models?.['dashscope/qwen-flash'], 'patch inclui qwen-flash alias');
  assert.ok(d?.models?.['dashscope/qwq-plus'], 'patch inclui qwq-plus alias');
  assert.strictEqual(d?.models?.['zai/glm-4.7-flash'], undefined, 'sem Z.AI models');
  assert.strictEqual(patch.models, undefined, 'patch não inclui models.providers (evita merge Cerebras/Groq legacy)');
});
