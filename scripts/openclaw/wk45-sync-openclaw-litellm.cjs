#!/usr/bin/env node
/**
 * Equivalente a config/openclaw/openclaw-litellm-local.jq (sem jq no Windows).
 * Substitui sk-litellm-default + localhost:4000, força models.providers.* → LiteLLM
 * (remove dependência de ${ZAI_API_KEY}, ${OPENROUTER_API_KEY}, etc.).
 *
 * Uso: LITELLM_MASTER_KEY=... LITELLM_PROXY_BASE_URL=http://100.125.249.8:4000 node wk45-sync-openclaw-litellm.cjs [openclaw.json]
 */
'use strict';

const fs = require('fs');
const path = require('path');

const cfgPath =
  process.argv[2] ||
  process.env.OPENCLAW_JSON ||
  path.join(process.env.USERPROFILE || 'C:\\Users\\Administrator', '.openclaw', 'openclaw.json');

const key = process.env.LITELLM_MASTER_KEY || '';
const proxyUrl = process.env.LITELLM_PROXY_BASE_URL || 'http://100.125.249.8:4000';

if (!key) {
  console.error('Missing LITELLM_MASTER_KEY');
  process.exit(1);
}

if (!fs.existsSync(cfgPath)) {
  console.error('Missing config:', cfgPath);
  process.exit(2);
}

const j = JSON.parse(fs.readFileSync(cfgPath, 'utf8').replace(/^\uFEFF/, ''));

function walk(node) {
  if (node === null || node === undefined) {
    return;
  }
  if (Array.isArray(node)) {
    for (const item of node) {
      walk(item);
    }
    return;
  }
  if (typeof node !== 'object') {
    return;
  }
  if (Object.prototype.hasOwnProperty.call(node, 'apiKey') && node.apiKey === 'sk-litellm-default') {
    node.apiKey = key;
  }
  if (
    Object.prototype.hasOwnProperty.call(node, 'baseUrl') &&
    typeof node.baseUrl === 'string' &&
    /localhost:4000|127\.0\.0\.1:4000|192\.168\.0\.179:4000/.test(node.baseUrl)
  ) {
    node.baseUrl = proxyUrl;
  }
  for (const k of Object.keys(node)) {
    walk(node[k]);
  }
}

walk(j);

/**
 * Alinha com config/openclaw/openclaw-litellm-local.jq: providers deixam de usar ${ZAI_API_KEY}
 * e URLs directos — tudo via LiteLLM (master key + proxy).
 */
const LITELLM_PROVIDER_NAMES = [
  'zai',
  'anthropic',
  'deepseek',
  'google',
  'openai',
  'kimi',
  'moonshot',
  'qwen',
  'openrouter',
  'dashscope',
];

function patchProvidersForLitellm(providers) {
  if (!providers || typeof providers !== 'object') {
    return;
  }
  for (const name of LITELLM_PROVIDER_NAMES) {
    const p = providers[name];
    if (!p || typeof p !== 'object') {
      continue;
    }
    p.baseUrl = proxyUrl;
    p.apiKey = key;
    if (name === 'zai') {
      p.api = 'openai-completions';
    }
  }
}

if (j.models && j.models.providers) {
  patchProvidersForLitellm(j.models.providers);
}

/** Evita aviso "plugin disabled but config is present" (ex.: Brave). */
function pruneDisabledBravePlugin(plugins) {
  if (!plugins || typeof plugins !== 'object' || !plugins.entries || typeof plugins.entries !== 'object') {
    return;
  }
  const b = plugins.entries.brave;
  if (!b || typeof b !== 'object') {
    return;
  }
  const disabledTop = Array.isArray(plugins.disabled)
    ? plugins.disabled.some((x) => /brave/i.test(String(x)))
    : false;
  if (disabledTop || b.disabled === true || b.enabled === false) {
    delete plugins.entries.brave;
  }
}

pruneDisabledBravePlugin(j.plugins);

// OpenClaw ≥2026.3 exige models:[] em vários providers; jq/deploy pode criar só baseUrl/apiKey.
const KIMI_MOONSHOT_MODELS = [
  { id: 'kimi-k2.5', name: 'Kimi K2.5', contextWindow: 262144, maxTokens: 16384 },
  { id: 'kimi-k2-thinking', name: 'Kimi K2 Thinking', contextWindow: 262144, maxTokens: 16384 },
  { id: 'moonshot-v1-128k', name: 'Kimi 128k', contextWindow: 131072, maxTokens: 8192 },
];
const GOOGLE_DEFAULT_MODELS = [
  { id: 'gemini-3.1-pro-preview', name: 'Gemini 3.1 Pro Preview', contextWindow: 1048576, maxTokens: 65536 },
  { id: 'gemini-2.5-pro', name: 'Gemini 2.5 Pro', contextWindow: 2097152, maxTokens: 65536 },
  { id: 'gemini-2.5-flash', name: 'Gemini 2.5 Flash', contextWindow: 1048576, maxTokens: 8192 },
  { id: 'gemini-2.5-flash-lite', name: 'Gemini 2.5 Flash-Lite', contextWindow: 1048576, maxTokens: 65536 },
];

function ensureProviderModels(providers) {
  if (!providers || typeof providers !== 'object') {
    return;
  }
  const fix = (name, defaults) => {
    const p = providers[name];
    if (!p || typeof p !== 'object') {
      return;
    }
    if (!Array.isArray(p.models)) {
      p.models = defaults;
    }
  };
  fix('kimi', KIMI_MOONSHOT_MODELS);
  fix('moonshot', KIMI_MOONSHOT_MODELS);
  fix('google', GOOGLE_DEFAULT_MODELS);
}

if (j.models && j.models.providers) {
  ensureProviderModels(j.models.providers);
}

fs.writeFileSync(cfgPath, JSON.stringify(j, null, 2), 'utf8');
console.log('OK wk45-sync-openclaw-litellm', cfgPath);
