'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const FRAGMENT = path.join(__dirname, '../../config/openclaw/openclaw-agents-list.fragment.json');

test('openclaw-agents-list.fragment.json: lista multi-agente AGL', () => {
  const frag = JSON.parse(fs.readFileSync(FRAGMENT, 'utf8'));
  const list = frag.agents?.list;
  assert.ok(Array.isArray(list) && list.length >= 5);

  const ids = list.map((a) => a.id);
  for (const id of ['main', 'infra', 'storage', 'harbor', 'net']) {
    assert.ok(ids.includes(id), `falta id ${id}`);
  }

  const defaults = list.filter((a) => a.default === true);
  assert.strictEqual(defaults.length, 1);
  assert.strictEqual(defaults[0].id, 'main');

  const main = list.find((a) => a.id === 'main');
  assert.ok(main.subagents?.allowAgents?.includes('infra'));

  assert.ok(Array.isArray(frag.bindings));
  assert.ok(
    frag.bindings.some((b) => b.match?.channel === 'telegram' && b.agentId === 'infra'),
    'exemplo de binding telegram→infra',
  );
});
