'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const MANIFEST = path.join(__dirname, '../../scripts/litellm/litellm-battery-manifest.json');

function load() {
  return JSON.parse(fs.readFileSync(MANIFEST, 'utf8'));
}

function matchTier(row, tier) {
  if (tier === 'full') return true;
  if (tier === 'standard') return row.runFor.includes('standard');
  return row.runFor.includes('quick');
}

test('litellm-battery-manifest.json: modelos únicos e runFor válido', () => {
  const { models } = load();
  const ids = models.map((m) => m.id);
  assert.strictEqual(ids.length, new Set(ids).size, 'ids duplicados');
  for (const m of models) {
    for (const t of m.runFor) {
      assert.ok(['quick', 'standard', 'full'].includes(t), `runFor inválido: ${t}`);
    }
    assert.ok(typeof m.timeoutSec === 'number' && m.timeoutSec > 0);
    assert.ok(typeof m.maxTokens === 'number' && m.maxTokens > 0);
  }
});

test('tier full inclui todas as entradas do manifest', () => {
  const { models } = load();
  const nFull = models.filter((m) => matchTier(m, 'full')).length;
  assert.strictEqual(nFull, models.length);
});

test('tier standard inclui núcleo cursor-composer e glm-flash', () => {
  const { models } = load();
  const std = models.filter((m) => matchTier(m, 'standard')).map((m) => m.id);
  assert.ok(std.includes('cursor-composer'));
  assert.ok(std.includes('glm-flash'));
});
