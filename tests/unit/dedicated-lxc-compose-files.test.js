'use strict';

/**
 * Garante que os composes dedicados CT186/CT187 existem e que o OpenClaw CT187
 * não depende de rede Docker externa LiteLLM (CTs separados).
 */
const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '../..');
const COMPOSE_LITELLM = path.join(ROOT, 'docker/litellm/docker-compose.ct186.yml');
const COMPOSE_OPENCLAW = path.join(ROOT, 'docker/openclaw/docker-compose.ct187.yml');

test('dedicated LXC: ficheiros compose existem', () => {
  assert.ok(fs.existsSync(COMPOSE_LITELLM), 'docker-compose.ct186.yml');
  assert.ok(fs.existsSync(COMPOSE_OPENCLAW), 'docker-compose.ct187.yml');
});

test('dedicated LXC: CT187 OpenClaw sem rede litellm external', () => {
  const yaml = fs.readFileSync(COMPOSE_OPENCLAW, 'utf8');
  assert.ok(!yaml.includes('external: true'), 'não usar rede Docker external no CT187');
  assert.ok(!yaml.includes('litellm_litellm-net'), 'sem nome fixo litellm_litellm-net');
});

test('dedicated LXC: CT186 monta config.yaml local', () => {
  const yaml = fs.readFileSync(COMPOSE_LITELLM, 'utf8');
  assert.match(yaml, /\.\/config\.yaml/, 'volume ./config.yaml');
});
