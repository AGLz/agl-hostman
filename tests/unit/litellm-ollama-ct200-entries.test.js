'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const CONFIG = path.join(__dirname, '../../config/litellm/config.yaml');
const CONFIG_REMOTE = path.join(__dirname, '../../config/litellm/config-remote.yaml');

const VM310_TS_OLLAMA = '100.67.253.52:11434';
const LEGACY_CT200_LAN = '192.168.0.200:11434';
const LEGACY_VM110_TS = '100.116.57.111:11434';

function escapeForRegex(ipHost) {
  return ipHost.replaceAll('.', '\\.');
}

function assertNoOllamaCloudAliases(yaml, label) {
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

test('LiteLLM local: agl-primary via Ollama VM310 Tailscale (qwen3:8b)', () => {
  const yaml = fs.readFileSync(CONFIG, 'utf8');

  assertNoOllamaCloudAliases(yaml, 'config.yaml');
  assert.match(
    yaml,
    /model:\s*ollama\/qwen3:8b[\s\S]*?model_name:\s*agl-primary/,
    'config.yaml: agl-primary usa ollama/qwen3:8b VM310',
  );
  assert.match(
    yaml,
    new RegExp(escapeForRegex(VM310_TS_OLLAMA), 'g'),
    'config.yaml: api_base Tailscale VM310',
  );
  assert.doesNotMatch(
    yaml,
    new RegExp(escapeForRegex(LEGACY_CT200_LAN)),
    'config.yaml: não deve usar LAN CT200 legado',
  );
  assert.doesNotMatch(
    yaml,
    new RegExp(escapeForRegex(LEGACY_VM110_TS)),
    'config.yaml: não deve usar Tailscale VM110 legado',
  );
});

test('LiteLLM remote: agl-primary Groq e aliases ollama legados sem Ollama real', () => {
  const yaml = fs.readFileSync(CONFIG_REMOTE, 'utf8');

  assertNoOllamaCloudAliases(yaml, 'config-remote.yaml');
  assert.match(
    yaml,
    /model_name:\s*"agl-primary"[\s\S]*?model:\s*"groq\/llama-3\.1-8b-instant"/,
    'config-remote.yaml: agl-primary aponta para Groq (VM110 suspenso)',
  );
  assert.match(
    yaml,
    /model_name:\s*"ollama-qwen3-4b"[\s\S]*?model:\s*"groq\/llama-3\.1-8b-instant"/,
    'config-remote.yaml: alias legado ollama-qwen3-4b → Groq',
  );
  assert.doesNotMatch(
    yaml,
    /api_base:\s*"?http:\/\/100\.(74|86)\./,
    'config-remote.yaml: sem api_base Ollama Tailscale',
  );
});
