'use strict';

/**
 * Claude Code CLI envia model IDs (ex. claude-sonnet-5) que o LiteLLM deve expor
 * como model_name com backend Anthropic ou fallbacks agl-*.
 */
const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const CONFIG = path.join(__dirname, '../../config/litellm/config.yaml');
const REMOTE = path.join(__dirname, '../../config/litellm/config-remote.yaml');

const CLAUDE_CC_ALIASES = [
  'claude-sonnet-5',
  'claude-opus-4-8',
  'claude-opus-4-5-20251101',
  'claude-opus-4-6-20250514',
  'claude-3-5-haiku-20241022',
  'claude-haiku-3-5',
];

function assertAliases(yaml, label, fallbackPattern) {
  for (const alias of CLAUDE_CC_ALIASES) {
    assert.match(
      yaml,
      new RegExp(`model_name:\\s*"?${alias.replace(/\./g, '\\.')}"?`),
      `${label}: alias ${alias}`,
    );
  }
  if (fallbackPattern) {
    assert.match(yaml, fallbackPattern, `${label}: fallbacks para sonnet-5`);
  }
}

test('LiteLLM config.yaml: aliases Claude Code claude-*', () => {
  assertAliases(
    fs.readFileSync(CONFIG, 'utf8'),
    'config.yaml',
    /claude-sonnet-5:[\s\S]*?agl-primary-zai-glm-flash/,
  );
});

test('LiteLLM config-remote.yaml: aliases Claude Code claude-*', () => {
  assertAliases(
    fs.readFileSync(REMOTE, 'utf8'),
    'config-remote.yaml',
    /claude-sonnet-5:\s*\[or-glm-air-free\]/,
  );
});
