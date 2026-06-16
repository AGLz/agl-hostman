'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const CONFIG = path.join(__dirname, '../../config/litellm/config.yaml');

test('LiteLLM: aliases cursor* removidos do config.yaml', () => {
  const yaml = fs.readFileSync(CONFIG, 'utf8');
  assert.doesNotMatch(yaml, /model_name:\s*"?cursor-/, 'sem model_name cursor-*');
  assert.doesNotMatch(yaml, /^\s+- cursor-/m, 'sem fallbacks cursor-*');
});
