'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const SCRIPT = path.join(__dirname, '../../scripts/litellm/validate-groq-keys.sh');
const SYNC = path.join(__dirname, '../../scripts/openclaw/sync-systemd-openclaw-env.sh');
const ENV_EXAMPLE = path.join(__dirname, '../../config/litellm/.env.example');
const BASH = process.platform === 'win32' && fs.existsSync('C:\\Program Files\\Git\\bin\\bash.exe')
  ? 'C:\\Program Files\\Git\\bin\\bash.exe'
  : 'bash';

test('validate-groq-keys.sh existe e aponta para API Groq', () => {
  const src = fs.readFileSync(SCRIPT, 'utf8');
  assert.match(src, /GROQ_API_KEY2/);
  assert.match(src, /api\.groq\.com\/openai\/v1/);
  assert.match(src, /--from-zshrc/);
});

test('sync-systemd-openclaw-env inclui GROQ_API_KEY2 no grep e write_kv', () => {
  const src = fs.readFileSync(SYNC, 'utf8');
  assert.match(src, /GROQ_API_KEY2/);
  assert.ok(src.includes('write_kv GROQ_API_KEY2'));
});

test('.env.example documenta GROQ_API_KEY2', () => {
  const src = fs.readFileSync(ENV_EXAMPLE, 'utf8');
  assert.match(src, /^GROQ_API_KEY2=/m);
});

test('validate-groq-keys.sh sem chaves no env: exit 2', () => {
  const r = spawnSync(BASH, [SCRIPT], {
    encoding: 'utf8',
    env: { ...process.env, GROQ_API_KEY: '', GROQ_API_KEY2: '' },
  });
  assert.strictEqual(r.status, 2, r.stderr || r.stdout);
});
