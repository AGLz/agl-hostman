'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const {
  buildTimingRows,
  rowsToCsv,
  exportBatteryTimings,
} = require('../../scripts/litellm/lib/litellm-battery-export.js');
const { analyzeChatCompletion } = require('../../scripts/litellm/lib/litellm-battery-analyze.js');

test('analyzeChatCompletion: reasoning_tokens em usage conta como sucesso', () => {
  const r = analyzeChatCompletion({
    choices: [{ finish_reason: 'length', message: { role: 'assistant', content: null } }],
    usage: {
      prompt_tokens: 1,
      completion_tokens: 5,
      total_tokens: 6,
      completion_tokens_details: { reasoning_tokens: 5, text_tokens: 0 },
    },
  });
  assert.strictEqual(r.ok, true);
  assert.strictEqual(r.hadReasoning, true);
  assert.strictEqual(r.usage?.reasoning_tokens, 5);
});

test('buildTimingRows inclui latencyMs e provider', () => {
  const report = {
    startedAt: '2026-06-16T02:00:00.000Z',
    gateway: 'http://example:4000',
    tier: 'full',
    chats: [
      {
        id: 'gemini-lite',
        ms: 432,
        httpStatus: 200,
        ok: true,
        softWarn: false,
        optional: true,
        listed: true,
        analysis: { finishReason: 'stop', usage: { prompt_tokens: 5, completion_tokens: 1, total_tokens: 6 } },
      },
    ],
  };
  const manifest = [{ id: 'gemini-lite', provider: 'google', tier: 'paid' }];
  const rows = buildTimingRows(report, manifest);
  assert.strictEqual(rows.length, 1);
  assert.strictEqual(rows[0].modelId, 'gemini-lite');
  assert.strictEqual(rows[0].provider, 'google');
  assert.strictEqual(rows[0].latencyMs, 432);
});

test('exportBatteryTimings escreve CSV, latest e history', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'battery-export-'));
  const report = {
    startedAt: '2026-06-16T02:00:00.000Z',
    gateway: 'http://example:4000',
    tier: 'full',
    summary: { pass: 1, fail: 0, warn: 0 },
    chats: [
      {
        id: 'gpt-5.4-mini',
        provider: 'openai',
        ms: 1200,
        httpStatus: 200,
        ok: true,
        softWarn: false,
        optional: false,
        listed: true,
        analysis: { finishReason: 'stop', usage: { prompt_tokens: 10, completion_tokens: 2, total_tokens: 12 } },
      },
    ],
  };
  const manifest = [{ id: 'gpt-5.4-mini', provider: 'openai', tier: 'paid' }];
  const out = exportBatteryTimings(report, manifest, tmp);
  assert.ok(fs.existsSync(out.csvPath));
  assert.ok(fs.existsSync(out.latestPath));
  assert.ok(fs.existsSync(out.historyPath));
  assert.ok(fs.existsSync(out.jsonPath));
  const csv = fs.readFileSync(out.latestPath, 'utf8');
  assert.match(csv, /latencyMs/);
  assert.match(csv, /gpt-5\.4-mini/);
  assert.match(csv, /1200/);
  const history = fs.readFileSync(out.historyPath, 'utf8').trim().split('\n');
  assert.strictEqual(history.length, 1);
  const json = JSON.parse(fs.readFileSync(out.jsonPath, 'utf8'));
  assert.strictEqual(json.responseTimes[0].latencyMs, 1200);
});

test('rowsToCsv escapa vírgulas', () => {
  const csv = rowsToCsv([
    {
      runAt: 't',
      gateway: 'g',
      tier: 'full',
      modelId: 'm',
      provider: 'p',
      modelTier: '',
      httpStatus: 200,
      latencyMs: 1,
      ok: false,
      softWarn: false,
      optional: false,
      listed: true,
      finishReason: '',
      promptTokens: '',
      completionTokens: '',
      totalTokens: '',
      reasoningTokens: '',
      error: 'foo, bar',
    },
  ]);
  assert.match(csv, /"foo, bar"/);
});
