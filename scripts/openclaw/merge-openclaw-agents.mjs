#!/usr/bin/env node
/**
 * Aplica config/openclaw/openclaw-agents-list.fragment.json em ~/.openclaw/openclaw.json
 * preservando o resto do ficheiro (ex.: agents.defaults, models, channels.telegram).
 *
 * Uso:
 *   node scripts/openclaw/merge-openclaw-agents.mjs
 *   node scripts/openclaw/merge-openclaw-agents.mjs --dry-run
 *   node scripts/openclaw/merge-openclaw-agents.mjs --no-bindings   # só agents.list
 */
import { readFileSync, writeFileSync, mkdirSync, existsSync, copyFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dirname, '..', '..');
const fragmentPath = join(repoRoot, 'config', 'openclaw', 'openclaw-agents-list.fragment.json');
const openclawDir = process.env.OPENCLAW_CONFIG_DIR || join(process.env.HOME || process.env.USERPROFILE, '.openclaw');
const openclawJson = join(openclawDir, 'openclaw.json');

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

function main() {
  const dry = process.argv.includes('--dry-run');
  const noBindings = process.argv.includes('--no-bindings');

  const fragment = JSON.parse(readFileSync(fragmentPath, 'utf8'));
  const current = existsSync(openclawJson)
    ? JSON.parse(readFileSync(openclawJson, 'utf8'))
    : {};

  const toApply = noBindings ? (() => {
    const { bindings: _b, ...rest } = fragment;
    return rest;
  })() : fragment;

  const merged = deepMerge(current, toApply);

  if (dry) {
    console.log(JSON.stringify(merged, null, 2));
    return;
  }

  mkdirSync(openclawDir, { recursive: true });
  if (existsSync(openclawJson)) {
    copyFileSync(openclawJson, `${openclawJson}.bak`);
    console.log('Backup:', `${openclawJson}.bak`);
  }

  writeFileSync(openclawJson, JSON.stringify(merged, null, 2), 'utf8');
  console.log('OK:', openclawJson);
  console.log('Reinicie o gateway: openclaw gateway restart');
  console.log('Edite bindings no JSON se usar Telegram: substitua -100REPLACE_WITH_TELEGRAM_GROUP_ID');
}

main();
