'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const CONFIG = path.join(__dirname, '../../config/litellm/config.yaml');
const CONFIG_REMOTE = path.join(__dirname, '../../config/litellm/config-remote.yaml');

function assertGroqOpenrouterStack(yaml, label) {
  assert.match(yaml, /model_name:\s*"openrouter-free"/, label);
  assert.match(yaml, /model:\s*"openrouter\/openrouter\/free"/, label);
  assert.match(yaml, /OPENROUTER_API_KEY/, label);
  assert.match(yaml, /GROQ_API_KEY/, label);
  assert.match(yaml, /GROQ_API_KEY2/, label);
  assert.match(yaml, /groq\/llama-3\.3-70b-versatile/, label);
  assert.match(yaml, /groq\/openai\/gpt-oss-120b/, label);
  assert.match(yaml, /CEREBRAS_API_KEY/, label);
  assert.match(yaml, /cerebras\/llama-3\.3-70b/, label);
  assert.match(yaml, /cerebras\/gpt-oss-120b/, label);
}

test('LiteLLM: OpenRouter :free + Groq + Cerebras em config.yaml', () => {
  assertGroqOpenrouterStack(fs.readFileSync(CONFIG, 'utf8'), 'config.yaml');
});

test('LiteLLM: OpenRouter :free + Groq + Cerebras em config-remote.yaml', () => {
  assertGroqOpenrouterStack(fs.readFileSync(CONFIG_REMOTE, 'utf8'), 'config-remote.yaml');
});
