'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const LITELLM_OLLAMA = path.join(__dirname, '../../config/ollama-stack/litellm-config.yaml');
const VERIFY = path.join(__dirname, '../../scripts/ollama-stack/verify-ollama.sh');
const PULL = path.join(__dirname, '../../scripts/ollama-stack/pull-small-qwen-models.sh');

test('ollama-stack: SOMENTE reasoning models na GTX 1650 4GB', () => {
  const y = fs.readFileSync(LITELLM_OLLAMA, 'utf8');
  // Qwen3 — thinking mode
  assert.match(y, /ollama\/qwen3:0\.6b/);
  assert.match(y, /ollama\/qwen3:1\.7b/);
  // DeepSeek-R1 — reasoning puro
  assert.match(y, /ollama\/deepseek-r1:1\.5b/);
  // Não deve ter modelos sem reasoning
  assert.doesNotMatch(y, /ollama-nemotron/);
  assert.doesNotMatch(y, /ollama-gemma4/);
  assert.doesNotMatch(y, /ollama-qwen3-8b/);
  assert.doesNotMatch(y, /ollama-qwen3-4b/);
  assert.doesNotMatch(y, /ollama-qwen25-coder/);
  assert.doesNotMatch(y, /ollama-gemma2/);
  assert.doesNotMatch(y, /ollama-llama32/);
  assert.doesNotMatch(y, /ollama-mistral/);
  assert.doesNotMatch(y, /ollama-phi3/);
  assert.doesNotMatch(y, /deepseek-coder-33b/);
  assert.doesNotMatch(y, /llama3\.3/);
  assert.doesNotMatch(y, /qwen2\.5-32b/);
  assert.doesNotMatch(y, /nomic-embed/);
  // Default é reasoning model
  assert.match(y, /completion_model:\s*ollama-qwen3-1\.7b/);
});

test('scripts ollama-stack verify + pull — reasoning only', () => {
  assert.ok(fs.existsSync(VERIFY));
  assert.ok(fs.existsSync(PULL));
  const p = fs.readFileSync(PULL, 'utf8');
  assert.match(p, /qwen3:0\.6b/);
  assert.match(p, /qwen3:1\.7b/);
  assert.match(p, /deepseek-r1:1\.5b/);
  assert.match(p, /reasoning/);
  assert.match(p, /GTX 1650/);
});
