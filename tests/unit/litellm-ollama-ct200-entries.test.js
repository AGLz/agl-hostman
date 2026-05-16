'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const CONFIG = path.join(__dirname, '../../config/litellm/config.yaml');
const CONFIG_REMOTE = path.join(__dirname, '../../config/litellm/config-remote.yaml');

const LAN_OLLAMA = '192.168.0.200:11434';
const TS_OLLAMA = '100.116.57.111:11434';

function escapeRegex(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function assertOllamaCt200QwenOnly(yaml, label) {
  assert.match(yaml, /ollama-qwen3-4b/, label);
  assert.match(yaml, /ollama\/qwen3:4b/, label);
  assert.match(yaml, /openai\/ollama-qwen3-4b/, label);
  assert.doesNotMatch(yaml, /ollama\/nemotron-3-nano/, label);
  assert.doesNotMatch(yaml, /ollama-nemotron-3-nano-4b/, label);
  assert.doesNotMatch(yaml, /:cloud/, label);
  assert.doesNotMatch(yaml, /ollama-glm-4\.7-cloud/, label);
  assert.doesNotMatch(yaml, /ollama-qwen3\.5-cloud/, label);
  assert.doesNotMatch(yaml, /ollama-deepseek-v3\.2-cloud/, label);
  assert.doesNotMatch(yaml, /ollama-gemma4-31b-cloud/, label);
  assert.doesNotMatch(yaml, /ollama-kimi-k2\.6-cloud/, label);
  assert.doesNotMatch(yaml, /ollama-minimax-m2\.7-cloud/, label);
  assert.doesNotMatch(yaml, /ollama-gpt-oss-20b-cloud/, label);
}

function escapeForRegex(ipHost) {
  return ipHost.replaceAll('.', '\\.');
}

test('LiteLLM local: Ollama CT200 via LAN — só qwen3:4b', () => {
  const yaml = fs.readFileSync(CONFIG, 'utf8');
  assertOllamaCt200QwenOnly(yaml, 'config.yaml');
  assert.match(
    yaml,
    /model:\s*ollama\/qwen3:4b[\s\S]*?model_name:\s*agl-primary/,
    'config.yaml: agl-primary usa ollama/qwen3:4b',
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

test('LiteLLM remote: Ollama CT200 via Tailscale — só qwen3:4b', () => {
  const yaml = fs.readFileSync(CONFIG_REMOTE, 'utf8');
  assertOllamaCt200QwenOnly(yaml, 'config-remote.yaml');
  assert.match(yaml, /model_name:\s*"ollama-qwen3-4b"/, 'config-remote.yaml: alias ollama-qwen3-4b');
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
