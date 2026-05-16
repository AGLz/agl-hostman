'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const ENDPOINTS_JSON = path.join(
  __dirname,
  '../../config/monitoring/jarvis-openclaw-http-endpoints.example.json',
);

test('jarvis-openclaw-http-endpoints.example.json: estrutura e URLs canónicos', () => {
  const raw = fs.readFileSync(ENDPOINTS_JSON, 'utf8');
  const data = JSON.parse(raw);

  assert.strictEqual(typeof data.version, 'number');
  assert.ok(Array.isArray(data.endpoints));
  assert.ok(data.endpoints.length >= 3);

  const n8n = data.endpoints.find((e) => e.id === 'n8n-ct202-aglsrv1');
  assert.ok(n8n, 'entrada n8n-ct202-aglsrv1');
  assert.match(n8n.primary, /^http:\/\/192\.168\.0\.202:/);
  assert.match(n8n.primary, /\/healthz$/);

  const wge = data.endpoints.find((e) => e.id === 'wg-easy-fgsrv6');
  assert.ok(wge, 'entrada wg-easy-fgsrv6');
  assert.strictEqual(wge.primary, 'http://10.6.0.5:51821/');
  assert.ok(wge.fallbacks.includes('http://100.83.51.9:51821/'));

  const block = data.doNotUseForTheseServices.find((x) => x.ip === '100.72.240.65');
  assert.ok(block, 'proibição explícita do IP cloudflared7');
  assert.match(block.reason, /n8n|wg-easy/i);

  const cut = data.cutoverDedicatedLxc;
  assert.ok(cut && Array.isArray(cut.lanChecksFromAgldv03), 'cutoverDedicatedLxc.lanChecksFromAgldv03');
  assert.strictEqual(cut.lanChecksFromAgldv03.length, 2);
  const llm186 = cut.lanChecksFromAgldv03.find((e) => e.id === 'litellm-ct186-lan');
  const oc187 = cut.lanChecksFromAgldv03.find((e) => e.id === 'openclaw-ct187-lan');
  assert.ok(llm186?.url?.includes('192.168.0.186:4000'), 'LiteLLM CT186');
  assert.ok(oc187?.url?.includes('192.168.0.187:28789'), 'OpenClaw CT187 gateway');
});
