'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const CONFIG = path.join(__dirname, '../../config/litellm/config.yaml');

test('LiteLLM: cursor-composer e cursor-composer-2-fast configurados', () => {
  const yaml = fs.readFileSync(CONFIG, 'utf8');
  // Aceitar com ou sem aspas (formato YAML pode variar)
  assert.match(yaml, /model_name:\s*"?cursor-composer"?/);
  assert.match(yaml, /model_name:\s*"?cursor-composer-2-fast"?/);
  // Verificar que existem entradas para ambos
  const composerMatches = [...yaml.matchAll(/model_name:\s*"?cursor-composer"?/g)];
  const composerFastMatches = [...yaml.matchAll(/model_name:\s*"?cursor-composer-2-fast"?/g)];
  assert.ok(composerMatches.length >= 1, 'esperado cursor-composer');
  assert.ok(composerFastMatches.length >= 1, 'esperado cursor-composer-2-fast');
});
