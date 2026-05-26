#!/usr/bin/env node
const fs = require('fs');
const cfg = 'C:\\Users\\Administrator\\.openclaw\\openclaw.json';
const raw = fs.readFileSync(cfg, 'utf8');
const j = JSON.parse(raw);
const bak = `${cfg}.bak.fix-plugins-schema-${Date.now()}`;
fs.writeFileSync(bak, raw, 'utf8');

if (!j.plugins || typeof j.plugins !== 'object') {
  j.plugins = { entries: {} };
}

const entries = j.plugins.entries;
if (!entries || typeof entries !== 'object') {
  j.plugins.entries = { telegram: { enabled: true } };
} else {
  const keep = {};
  if (entries.telegram) {
    keep.telegram = { enabled: true };
  }
  j.plugins.entries = keep;
}

delete j.plugins.disabled;
delete j.plugins.load;

fs.writeFileSync(cfg, `${JSON.stringify(j, null, 2)}\n`, 'utf8');
console.log('OK fix-plugins-schema', Object.keys(j.plugins.entries).join(','), 'backup', bak);
