'use strict';

/**
 * Spike auth2api: compose bind localhost + scripts + snippet LiteLLM lab off-by-default.
 */
const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '../..');
const COMPOSE = path.join(ROOT, 'docker/auth2api/docker-compose.yml');
const DOCKERFILE = path.join(ROOT, 'docker/auth2api/Dockerfile');
const SNIPPET = path.join(ROOT, 'config/litellm/auth2api-lab-snippet.yaml');
const MAIN_LITELLM = path.join(ROOT, 'config/litellm/config.yaml');

test('auth2api spike: ficheiros base existem', () => {
  for (const f of [
    COMPOSE,
    DOCKERFILE,
    path.join(ROOT, 'docker/auth2api/config.example.yaml'),
    path.join(ROOT, 'scripts/auth2api/bootstrap.sh'),
    path.join(ROOT, 'scripts/auth2api/login.sh'),
    path.join(ROOT, 'scripts/auth2api/up.sh'),
    path.join(ROOT, 'scripts/auth2api/smoke-test.sh'),
    path.join(ROOT, 'scripts/auth2api/enable-litellm-lab.sh'),
    path.join(ROOT, 'scripts/auth2api/enable-litellm-ct186.sh'),
    path.join(ROOT, 'scripts/auth2api/deploy-ct186.sh'),
    path.join(ROOT, 'scripts/auth2api/disable-litellm-lab.sh'),
    path.join(ROOT, 'scripts/auth2api/smoke-litellm-lab.sh'),
    path.join(ROOT, 'scripts/proxmox/apply-hermes-auth2api-jew-ct188.sh'),
    path.join(ROOT, 'scripts/proxmox/apply-hermes-auth2api-fleet-ct188.sh'),
    path.join(ROOT, 'scripts/monitoring/auth2api-quota-monitor.sh'),
    path.join(ROOT, 'config/systemd/agl-auth2api-quota.timer'),
    path.join(ROOT, 'docker/auth2api/docker-compose.ct186.yml'),
    SNIPPET,
    path.join(ROOT, 'docs/AUTH2API-SPIKE.md'),
  ]) {
    assert.ok(fs.existsSync(f), f);
  }
});

test('auth2api spike: bind localhost + Tailscale/LAN (não 0.0.0.0)', () => {
  const yaml = fs.readFileSync(COMPOSE, 'utf8');
  assert.match(yaml, /127\.0\.0\.1:\$\{AUTH2API_PORT:-8317\}:8317/);
  assert.match(yaml, /AUTH2API_TS_IP/);
  assert.match(yaml, /AUTH2API_LAN_IP/);
  assert.ok(!/"0\.0\.0\.0:/.test(yaml), 'ports não usa 0.0.0.0');
});

test('auth2api ct186: rede LiteLLM canónica + bind sem 0.0.0.0', () => {
  const yaml = fs.readFileSync(
    path.join(ROOT, 'docker/auth2api/docker-compose.ct186.yml'),
    'utf8',
  );
  assert.match(yaml, /agl-litellm_litellm-net/);
  assert.match(yaml, /127\.0\.0\.1:\$\{AUTH2API_PORT:-8317\}:8317/);
  assert.match(yaml, /100\.125\.249\.8/);
  assert.ok(!/"0\.0\.0\.0:/.test(yaml), 'ports CT186 não usa 0.0.0.0');
});

test('auth2api spike: Dockerfile pina SHA completo', () => {
  const df = fs.readFileSync(DOCKERFILE, 'utf8');
  assert.match(df, /AUTH2API_REF=[a-f0-9]{40}/);
  assert.match(df, /CODEX_CLIENT_VERSION=/);
  assert.match(df, /codex-models\.ts/);
});

test('auth2api spike: snippet lab não está no config CT186', () => {
  const main = fs.readFileSync(MAIN_LITELLM, 'utf8');
  assert.ok(!main.includes('auth2api-claude'), 'não misturar auth2api no config.yaml prod');
  assert.ok(!main.includes('AUTH2API_API_KEY'), 'sem AUTH2API no config prod');
});

test('auth2api spike: compose usa rede litellm externa', () => {
  const yaml = fs.readFileSync(COMPOSE, 'utf8');
  assert.match(yaml, /litellm_litellm-net/);
  assert.match(yaml, /external:\s*true/);
});

test('auth2api spike: snippet lab tem marcadores e sem cursor chat', () => {
  const snip = fs.readFileSync(SNIPPET, 'utf8');
  assert.match(snip, /AUTH2API_LAB_BEGIN/);
  assert.match(snip, /auth2api-claude-fable-5/);
  assert.match(snip, /auth2api-claude-sonnet/);
  assert.match(snip, /auth2api-claude-opus/);
  assert.match(snip, /auth2api-gpt-5\.5/);
  assert.match(snip, /auth2api-gpt-5\.6/);
  assert.match(snip, /auth2api-gpt-codex/);
  assert.ok(!snip.includes('auth2api-cursor'), 'cursor omitido do lab activo');
});

test('auth2api fleet: Jarvis Fable 5 único; enable CT186 usa agl-auth2api', () => {
  const fleet = fs.readFileSync(
    path.join(ROOT, 'scripts/proxmox/apply-hermes-auth2api-fleet-ct188.sh'),
    'utf8',
  );
  assert.match(fleet, /JARVIS_MODEL=.*auth2api-claude-fable-5/);
  assert.ok(
    !/ELON_MODEL=.*fable|WERNER_MODEL=.*fable|SATYA_MODEL=.*fable/.test(fleet),
    'só Jarvis usa Fable 5',
  );
  const enable = fs.readFileSync(
    path.join(ROOT, 'scripts/auth2api/enable-litellm-ct186.sh'),
    'utf8',
  );
  assert.match(enable, /agl-auth2api:8317/);
});
