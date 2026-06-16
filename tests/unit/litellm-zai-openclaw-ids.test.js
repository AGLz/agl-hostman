'use strict';

/**
 * OpenClaw (fallback GLM): zai/glm-4.7-flash, zai/glm-5, zai/glm-4.7, zai/glm-4.5-flash
 * e corpos sem prefixo glm-4.5-flash / glm-4.7-flash.
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
  assert.match(yaml, /model_name:\s*"?zai\/glm-5"?/, `${label}: zai/glm-5`);
  assert.match(yaml, /model_name:\s*"?zai\/glm-4\.7"?/, `${label}: zai/glm-4.7`);
  assert.match(yaml, /model_name:\s*"?zai\/glm-4\.5-flash"?/, `${label}: zai/glm-4.5-flash`);
  assert.match(yaml, /model_name:\s*"?zai\/glm-4\.7-flash"?/, `${label}: zai/glm-4.7-flash`);
  assert.match(yaml, /model_name:\s*"?glm-4\.5-flash"?/, `${label}: glm-4.5-flash (OpenClaw zai sem prefixo)`);
  assert.match(yaml, /model_name:\s*"?glm-4\.7-flash"?/, `${label}: glm-4.7-flash (OpenClaw zai sem prefixo)`);
}

test('LiteLLM: IDs zai/glm-* (OpenClaw) em config.yaml', () => {
  assertZaiIds(fs.readFileSync(CONFIG, 'utf8'), 'config.yaml');
});

test('LiteLLM: rotas OpenAI económicas (gpt-4o-mini, gpt-5-mini, gpt-5.4-nano)', () => {
  const yaml = fs.readFileSync(CONFIG, 'utf8');
  assert.match(yaml, /model_name:\s*gpt-4o-mini/, 'config.yaml: gpt-4o-mini');
  assert.doesNotMatch(yaml, /model_name:\s*gpt-4\.4-mini/, 'config.yaml: gpt-4.4-mini removido');
  assert.match(yaml, /model_name:\s*gpt-5-mini/, 'config.yaml: gpt-5-mini');
  assert.match(yaml, /model_name:\s*gpt-5\.4-nano/, 'config.yaml: gpt-5.4-nano');
});

test('LiteLLM: DeepSeek e Gemini API directos removidos de config.yaml', () => {
  const yaml = fs.readFileSync(CONFIG, 'utf8');
  assert.doesNotMatch(yaml, /model_name:\s*deepseek\s*$/, 'sem alias deepseek');
  assert.doesNotMatch(yaml, /model_name:\s*cursor-deepseek/, 'sem cursor-deepseek');
  assert.doesNotMatch(yaml, /DEEPSEEK_API_KEY/, 'sem DEEPSEEK_API_KEY no model_list');
  assert.doesNotMatch(yaml, /model_name:\s*gemini-lite/, 'sem gemini-lite');
});

test('LiteLLM: config-remote.yaml sem Z.AI direto (usa OpenRouter free)', () => {
  const remote = fs.readFileSync(CONFIG_REMOTE, 'utf8');
  // config-remote usa OpenRouter free tier, nao Z.AI direto (removido por design)
  assert.ok(!remote.includes('api.z.ai'), 'config-remote: sem api_base Z.AI direto');
  assert.match(remote, /openrouter\/z-ai\/glm-4\.5-air:free/, 'config-remote: usa OpenRouter free tier');
});
