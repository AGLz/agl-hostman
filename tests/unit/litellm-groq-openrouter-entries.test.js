'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const CONFIG = path.join(__dirname, '../../config/litellm/config.yaml');

test('LiteLLM: entradas Groq e OpenRouter free (config.yaml)', () => {
  const yaml = fs.readFileSync(CONFIG, 'utf8');
  assert.match(yaml, /model_name:\s*"groq-llama-33"/);
  assert.match(yaml, /model:\s*"groq\/llama-3\.3-70b-versatile"/);
  assert.match(yaml, /model_name:\s*"groq-gpt-oss-120b"/);
  assert.match(yaml, /model:\s*"groq\/openai\/gpt-oss-120b"/);
  assert.match(yaml, /model_name:\s*"openrouter-free"/);
  assert.match(yaml, /model:\s*"openrouter\/openrouter\/free"/);
  assert.match(yaml, /model_name:\s*"openrouter-llama-3\.2-3b-free"/);
  assert.match(yaml, /model:\s*"openrouter\/meta-llama\/llama-3\.2-3b-instruct:free"/);
  assert.match(yaml, /GROQ_API_KEY/);
});
