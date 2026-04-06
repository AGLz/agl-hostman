'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const LITELLM_OLLAMA = path.join(__dirname, '../../config/ollama-stack/litellm-config.yaml');
const VERIFY = path.join(__dirname, '../../scripts/ollama-stack/verify-ollama.sh');
const PULL = path.join(__dirname, '../../scripts/ollama-stack/pull-small-qwen-models.sh');

test('ollama-stack litellm-config: Qwen3/Qwen2.5 pequenos e fallbacks', () => {
  const y = fs.readFileSync(LITELLM_OLLAMA, 'utf8');
  assert.match(y, /ollama\/qwen3:4b/);
  assert.match(y, /ollama\/qwen3:0\.6b/);
  assert.match(y, /ollama\/qwen2\.5:7b/);
  assert.match(y, /ollama-qwen3-4b:\s*\[ollama-qwen2\.5-7b/);
  assert.match(y, /qwen2\.5-32b:\s*\[ollama-qwen3-8b/);
});

test('scripts ollama-stack verify + pull existem', () => {
  assert.ok(fs.existsSync(VERIFY));
  assert.ok(fs.existsSync(PULL));
  const v = fs.readFileSync(VERIFY, 'utf8');
  assert.match(v, /\/api\/tags/);
  const p = fs.readFileSync(PULL, 'utf8');
  assert.match(p, /qwen3:4b/);
});
