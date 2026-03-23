'use strict';

/**
 * OpenClaw (openclaw-patch.json) usa IDs zai/glm-5, zai/glm-4.7, zai/glm-4.7-flash.
 * O LiteLLM deve expor o mesmo model_name ou /chat/completions falha e o gateway
 * cai nos fallbacks (ex.: mensagem confusa com gemini ... :free).
 */
const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const CONFIG = path.join(__dirname, '../../config/litellm/config.yaml');
const CONFIG_REMOTE = path.join(__dirname, '../../config/litellm/config-remote.yaml');

function assertZaiIds(yaml, label) {
  assert.match(yaml, /model_name:\s*"zai\/glm-5"/, `${label}: zai/glm-5`);
  assert.match(yaml, /model_name:\s*"zai\/glm-4\.7"/, `${label}: zai/glm-4.7`);
  assert.match(yaml, /model_name:\s*"zai\/glm-4\.7-flash"/, `${label}: zai/glm-4.7-flash`);
}

test('LiteLLM: IDs zai/glm-* (OpenClaw) em config.yaml', () => {
  assertZaiIds(fs.readFileSync(CONFIG, 'utf8'), 'config.yaml');
});

test('LiteLLM: IDs zai/glm-* em config-remote.yaml (fgsrv06)', () => {
  assertZaiIds(fs.readFileSync(CONFIG_REMOTE, 'utf8'), 'config-remote.yaml');
});
