'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const CONFIG = path.join(__dirname, '../../config/litellm/config.yaml');
const CONFIG_REMOTE = path.join(__dirname, '../../config/litellm/config-remote.yaml');

const LAN_OLLAMA = '192.168.0.200:11434';
const TS_OLLAMA = '100.116.57.111:11434';

function assertOllamaSingleNemotron(yaml, label) {
  assert.match(yaml, /ollama-nemotron-3-nano-4b/, label);
  assert.match(yaml, /ollama\/nemotron-3-nano:4b/, label);
  assert.match(yaml, /openai\/ollama-nemotron-3-nano-4b/, label);
  assert.doesNotMatch(yaml, /ollama-qwen3-0\.6b/, label);
  assert.doesNotMatch(yaml, /ollama-qwen3-1\.7b/, label);
  assert.doesNotMatch(yaml, /ollama-qwen3-4b/, label);
  assert.doesNotMatch(yaml, /ollama-deepseek-r1-1\.5b/, label);
  assert.doesNotMatch(yaml, /ollama-gemma4/, label);
  assert.doesNotMatch(yaml, /ollama-qwen3-8b/, label);
  assert.doesNotMatch(yaml, /ollama-gemma2/, label);
}

function escapeForRegex(ipHost) {
  return ipHost.replaceAll('.', '\\.');
}

test('LiteLLM local: Ollama CT200 via LAN em config.yaml (só Nemotron)', () => {
  const yaml = fs.readFileSync(CONFIG, 'utf8');
  assertOllamaSingleNemotron(yaml, 'config.yaml');
  assert.match(
    yaml,
    /model:\s*ollama\/nemotron-3-nano:4b[\s\S]*?model_name:\s*agl-primary/,
    'config.yaml: agl-primary usa ollama/nemotron-3-nano:4b',
  );
  assert.match(
    yaml,
    new RegExp(escapeForRegex(LAN_OLLAMA), 'g'),
    'config.yaml: api_base LAN',
  );
  assert.doesNotMatch(
    yaml,
    new RegExp(escapeForRegex(TS_OLLAMA)),
    'config.yaml: não deve usar Tailscale para Ollama',
  );
});

test('LiteLLM remote: Ollama CT200 via Tailscale em config-remote.yaml (só Nemotron)', () => {
  const yaml = fs.readFileSync(CONFIG_REMOTE, 'utf8');
  assertOllamaSingleNemotron(yaml, 'config-remote.yaml');
  assert.match(
    yaml,
    new RegExp(escapeForRegex(TS_OLLAMA), 'g'),
    'config-remote.yaml: api_base Tailscale',
  );
  assert.doesNotMatch(
    yaml,
    new RegExp(escapeForRegex(LAN_OLLAMA)),
    'config-remote.yaml: não deve usar LAN para Ollama',
  );
});
