'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const CONFIG = path.join(__dirname, '../../config/litellm/config.yaml');
const CONFIG_REMOTE = path.join(__dirname, '../../config/litellm/config-remote.yaml');

function assertGroqOpenrouterStack(yaml, label, requireCerebras = false) {
  assert.match(yaml, /model_name:\s*"?openrouter-free"?/, label);
  assert.match(yaml, /model:\s*"?openrouter\/openrouter\/free"?/, label);
  assert.match(yaml, /OPENROUTER_API_KEY/, label);
  assert.match(yaml, /GROQ_API_KEY/, label);
  assert.match(yaml, /GROQ_API_KEY2/, label);
  assert.match(yaml, /groq\/llama-3\.3-70b-versatile/, label);
  assert.match(yaml, /groq\/openai\/gpt-oss-120b/, label);
  // Cerebras opcional — nem sempre presente em todas as variants
  if (requireCerebras) {
    assert.match(yaml, /CEREBRAS_API_KEY/, label);
    assert.match(yaml, /cerebras\/llama-3\.3-70b/, label);
    assert.match(yaml, /cerebras\/gpt-oss-120b/, label);
  }
}

test('LiteLLM: OpenRouter :free + Groq em config.yaml (Cerebras opcional)', () => {
  assertGroqOpenrouterStack(fs.readFileSync(CONFIG, 'utf8'), 'config.yaml', false);
});

test('LiteLLM: OpenRouter :free + Groq + Cerebras em config-remote.yaml (fgsrv06)', () => {
  assertGroqOpenrouterStack(fs.readFileSync(CONFIG_REMOTE, 'utf8'), 'config-remote.yaml', true);
});
