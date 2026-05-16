'use strict';

/**
 * Z.AI GLM Coding Plan usa base dedicada (docs.z.ai): https://api.z.ai/api/coding/paas/v4
 * LiteLLM: modelo proxy `zai-coding-glm-4.7` para testes sem misturar com api/openai/v1.
 */
const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('path');

const CONFIG = path.join(__dirname, '../../config/litellm/config.yaml');

test('LiteLLM: entrada Z.AI Coding endpoint (paas coding v4)', () => {
  const yaml = fs.readFileSync(CONFIG, 'utf8');
  assert.match(
    yaml,
    /api_base:\s*https:\/\/api\.z\.ai\/api\/coding\/paas\/v4/,
    'config.yaml: api_base coding paas v4',
  );
  assert.match(yaml, /model_name:\s*zai-coding-glm-4\.7/, 'config.yaml: alias zai-coding-glm-4.7');
});
