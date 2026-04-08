'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const CONFIG = path.join(__dirname, '../../config/litellm/config.yaml');
const CONFIG_REMOTE = path.join(__dirname, '../../config/litellm/config-remote.yaml');

const LAN_OLLAMA = '192.168.0.200:11434';
const TS_OLLAMA = '100.116.57.111:11434';

function assertOllamaModels(yaml, label) {
  // Nemotron-3-Nano 4B — modelo principal
  assert.match(yaml, /ollama-nemotron-3-nano-4b/, label);
  assert.match(yaml, /ollama\/nemotron-3-nano:4b/, label);
  // Gemma 4 (2026-03-31) — só e2b (4GB VRAM GTX 1650)
  assert.match(yaml, /ollama-gemma4-e2b/, label);
  assert.match(yaml, /ollama\/gemma4:e2b/, label);
  // Não deve ter gemma4-e4b (excede 4GB)
  assert.doesNotMatch(yaml, /ollama-gemma4-e4b/, label);
}

function escapeForRegex(ipHost) {
  return ipHost.replaceAll('.', '\\.');
}

test('LiteLLM local: Ollama CT200 via LAN em config.yaml', () => {
  const yaml = fs.readFileSync(CONFIG, 'utf8');
  assertOllamaModels(yaml, 'config.yaml');
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

test('LiteLLM remote: Ollama CT200 via Tailscale em config-remote.yaml', () => {
  const yaml = fs.readFileSync(CONFIG_REMOTE, 'utf8');
  assertOllamaModels(yaml, 'config-remote.yaml');
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
