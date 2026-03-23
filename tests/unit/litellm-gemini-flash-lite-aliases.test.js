'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const CONFIG = path.join(__dirname, '../../config/litellm/config.yaml');
const CONFIG_REMOTE = path.join(__dirname, '../../config/litellm/config-remote.yaml');

function assertGeminiAliases(yaml, label) {
  assert.match(yaml, /model_name:\s*"google\/gemini-2\.5-flash-lite"/, label);
  assert.match(yaml, /model_name:\s*"google\/gemini-2\.5-flash-lite:free"/, label);
  assert.match(yaml, /model_name:\s*"openrouter\/google\/gemini-2\.5-flash-lite:free"/, label);
  assert.match(yaml, /model:\s*"gemini\/gemini-2\.5-flash-lite"/, label);
}

test('LiteLLM: aliases google/gemini-2.5-flash-lite (+ :free) em config.yaml', () => {
  const yaml = fs.readFileSync(CONFIG, 'utf8');
  assertGeminiAliases(yaml, 'config.yaml');
});

test('LiteLLM: mesmos aliases em config-remote.yaml', () => {
  const yaml = fs.readFileSync(CONFIG_REMOTE, 'utf8');
  assertGeminiAliases(yaml, 'config-remote.yaml');
});
