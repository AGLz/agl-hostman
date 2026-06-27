'use strict';

/**
 * Callback LiteLLM agl_glm_flash_params: alem do glm-flash, os primarios GLM
 * (zai-glm-5, zai-coding-glm-4.7) tambem devem ter thinking off por default.
 * Reason: com thinking on o GLM gasta o budget em reasoning_content e devolve
 * content vazio ("empty response") sob carga. Ver wiki GLM Coding Plan (Z.AI).
 */
const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('path');

const CB = path.join(
  __dirname,
  '../../config/litellm/custom_callbacks/agl_glm_flash_params.py',
);

test('callback cobre primarios GLM (zai-glm-5, zai-coding-glm-4.7)', () => {
  const src = fs.readFileSync(CB, 'utf8');
  assert.match(src, /_GLM_THINKING_PATTERN/, 'define pattern thinking');
  assert.match(src, /zai-glm-5/, 'cobre zai-glm-5');
  assert.match(src, /zai-coding-glm-4\\\.7/, 'cobre zai-coding-glm-4.7');
  assert.match(src, /def _is_glm_thinking_route/, 'helper thinking route');
});

test('callback injeta thinking disabled preservando override enabled', () => {
  const src = fs.readFileSync(CB, 'utf8');
  assert.match(src, /_is_glm_thinking_route\(model_str\)/, 'usa helper no hook');
  assert.match(src, /extra\["thinking"\] = \{"type": "disabled"\}/);
  assert.match(src, /get\("type"\) == "enabled"/, 'preserva enabled explicito');
});
