'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const SETTINGS = path.join(__dirname, '../../.claude/settings.json');

test('Claude Code settings: ANTHROPIC_BASE_URL e LITELLM_GATEWAY_URL → CT186 LiteLLM', () => {
  const raw = fs.readFileSync(SETTINGS, 'utf8');
  const j = JSON.parse(raw);
  assert.strictEqual(j.env.ANTHROPIC_BASE_URL, 'http://100.125.249.8:4000');
  assert.strictEqual(j.env.LITELLM_GATEWAY_URL, 'http://100.125.249.8:4000');
});
