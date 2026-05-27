#!/usr/bin/env node
/**
 * Configura OpenClaw para usar LiteLLM local (localhost:4000)
 * Uso: node scripts/openclaw/use-litellm-local.mjs
 */
import { readFileSync, writeFileSync, mkdirSync, copyFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dirname, '..', '..');
const openclawDir = process.env.OPENCLAW_CONFIG_DIR || join(process.env.USERPROFILE || process.env.HOME, '.openclaw');
const openclawJson = join(openclawDir, 'openclaw.json');

const LITELLM_URL = 'http://localhost:4000';
const LITELLM_KEY = 'sk-litellm-default';

const providers = ['zai', 'anthropic', 'deepseek', 'google', 'openai', 'kimi', 'moonshot', 'qwen', 'openrouter'];

const patch = {
  baseUrl: LITELLM_URL,
  apiKey: LITELLM_KEY,
  api: 'openai-completions'
};

function main() {
  console.log('=== OpenClaw -> LiteLLM local (localhost:4000) ===');
  console.log('  Config:', openclawJson);
  console.log('');

  mkdirSync(openclawDir, { recursive: true });

  const patchPath = join(repoRoot, 'config', 'openclaw', 'openclaw-patch.json');
  const base = JSON.parse(readFileSync(patchPath, 'utf8'));
  const current = existsSync(openclawJson)
    ? JSON.parse(readFileSync(openclawJson, 'utf8'))
    : {};

  const merged = deepMerge(current, base);
  if (!merged.models) merged.models = {};
  if (!merged.models.providers) merged.models.providers = {};

  for (const p of providers) {
    const existing = merged.models.providers[p] || {};
    merged.models.providers[p] = { ...existing, baseUrl: LITELLM_URL, apiKey: LITELLM_KEY };
    if (p === 'zai') merged.models.providers[p].api = 'openai-completions';
    else if (!merged.models.providers[p].api) merged.models.providers[p].api = 'openai-completions';
  }

  writeFileSync(openclawJson, JSON.stringify(merged, null, 2), 'utf8');
  console.log('  OK: openclaw.json atualizado');

  const localEnv = join(repoRoot, 'config', 'openclaw', 'litellm-gateway-local.env');
  copyFileSync(localEnv, join(openclawDir, 'litellm-gateway.env'));
  console.log('  OK: litellm-gateway.env');

  console.log('');
  console.log('=== Concluído ===');
  console.log('  Reinicie o gateway: openclaw gateway restart');
  console.log('  Verifique: openclaw models list');
}

function deepMerge(target, source) {
  const out = { ...target };
  for (const k of Object.keys(source)) {
    if (source[k] && typeof source[k] === 'object' && !Array.isArray(source[k])) {
      out[k] = deepMerge(target[k] || {}, source[k]);
    } else {
      out[k] = source[k];
    }
  }
  return out;
}

main();
