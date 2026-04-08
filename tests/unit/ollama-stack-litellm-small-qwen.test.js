'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const LITELLM_OLLAMA = path.join(__dirname, '../../config/ollama-stack/litellm-config.yaml');
const VERIFY = path.join(__dirname, '../../scripts/ollama-stack/verify-ollama.sh');
const PULL = path.join(__dirname, '../../scripts/ollama-stack/pull-small-qwen-models.sh');

test('ollama-stack litellm-config: modelos cabem em GTX 1650 4GB com Nemotron principal', () => {
  const y = fs.readFileSync(LITELLM_OLLAMA, 'utf8');
  // Nemotron-3-Nano como modelo principal
  assert.match(y, /ollama\/nemotron-3-nano:4b/);
  assert.match(y, /ollama-nemotron-3-nano-4b/);
  assert.match(y, /completion_model:\s*ollama-nemotron-3-nano-4b/);
  // Outros modelos que cabem
  assert.match(y, /ollama\/qwen3:0\.6b/);
  assert.match(y, /ollama\/qwen3:1\.7b/);
  assert.match(y, /ollama\/gemma4:e2b/);
  // Fallbacks do Nemotron usam apenas modelos pequenos
  assert.match(y, /ollama-nemotron-3-nano-4b:\s*\[ollama-qwen3-1\.7b/);
  // Não deve ter modelos que excedem 4GB no fallback
  assert.doesNotMatch(y, /ollama-qwen3-8b/);
  assert.doesNotMatch(y, /ollama-gemma4-e4b/);
});

test('scripts ollama-stack verify + pull existem', () => {
  assert.ok(fs.existsSync(VERIFY));
  assert.ok(fs.existsSync(PULL));
  const v = fs.readFileSync(VERIFY, 'utf8');
  assert.match(v, /\/api\/tags/);
  const p = fs.readFileSync(PULL, 'utf8');
  assert.match(p, /nemotron-3-nano:4b/);
  assert.match(p, /GTX 1650/);
});
