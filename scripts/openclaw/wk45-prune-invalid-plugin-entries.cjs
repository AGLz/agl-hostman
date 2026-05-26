#!/usr/bin/env node
/**
 * Remove entradas de plugins que bloqueiam o gateway após upgrade OpenClaw ≥2026.5.
 * Mantém telegram (wk45) e duckduckgo; remove entradas com manifest inválido.
 */
const fs = require('fs');
const path = require('path');

/** wk45: guest exec corre como SYSTEM — usar sempre o perfil Administrator. */
const cfgPath =
  process.env.OPENCLAW_CONFIG ||
  'C:\\Users\\Administrator\\.openclaw\\openclaw.json';

const KEEP_ENTRIES = new Set(['telegram', 'duckduckgo']);

function main() {
  if (!fs.existsSync(cfgPath)) {
    console.error('ERRO: config inexistente:', cfgPath);
    process.exit(1);
  }
  const raw = fs.readFileSync(cfgPath, 'utf8');
  const j = JSON.parse(raw);
  const bak = `${cfgPath}.bak.prune-plugins-${new Date().toISOString().replace(/[:.]/g, '-')}`;
  fs.writeFileSync(bak, raw, 'utf8');

  if (!j.plugins || typeof j.plugins !== 'object') {
    j.plugins = {};
  }
  const entries = j.plugins.entries;
  if (entries && typeof entries === 'object') {
    const removed = [];
    for (const name of Object.keys(entries)) {
      if (!KEEP_ENTRIES.has(name)) {
        delete entries[name];
        removed.push(name);
      }
    }
    console.log('Removidas plugins.entries:', removed.join(', ') || '(nenhuma)');
  }

  if (Array.isArray(j.plugins.load)) {
    const before = j.plugins.load.length;
    j.plugins.load = j.plugins.load.filter(
      (p) => !String(p).includes('openclaw.plugin.json'),
    );
    if (j.plugins.load.length !== before) {
      console.log('Limpou plugins.load (manifest root inválido)');
    }
    if (j.plugins.load.length === 0) {
      delete j.plugins.load;
    }
  }

  if (!Array.isArray(j.plugins.disabled)) {
    j.plugins.disabled = [];
  }
  const extraDisabled = [
    'amazon-bedrock-mantle',
    'anthropic-vertex',
    'codex',
    'kilocode',
    'kimi',
    'runway',
    'stepfun',
  ];
  for (const id of extraDisabled) {
    if (!j.plugins.disabled.includes(id)) {
      j.plugins.disabled.push(id);
    }
  }

  if (!j.gateway || typeof j.gateway !== 'object') {
    j.gateway = {};
  }
  if (!j.gateway.mode) {
    j.gateway.mode = 'local';
  }

  fs.writeFileSync(cfgPath, JSON.stringify(j, null, 2), 'utf8');
  console.log('OK prune-plugins', cfgPath, 'backup:', bak);
}

main();
