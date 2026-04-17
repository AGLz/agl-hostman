'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const {
  analyzeChatCompletion,
  normalizeUsage,
  looksLikeRateLimit,
  summarizeModelListItem,
} = require('../../scripts/litellm/lib/litellm-battery-analyze.js');

test('analyzeChatCompletion: sucesso com content', () => {
  const r = analyzeChatCompletion({
    choices: [
      {
        finish_reason: 'stop',
        message: { role: 'assistant', content: 'OK' },
      },
    ],
    usage: { prompt_tokens: 5, completion_tokens: 1, total_tokens: 6 },
  });
  assert.strictEqual(r.ok, true);
  assert.strictEqual(r.finishReason, 'stop');
  assert.strictEqual(r.contentLength >= 2, true);
  assert.strictEqual(r.usage?.total_tokens, 6);
});

test('analyzeChatCompletion: reasoning_content conta como sucesso', () => {
  const r = analyzeChatCompletion({
    choices: [
      {
        message: { role: 'assistant', content: '', reasoning_content: 'thinking...' },
      },
    ],
  });
  assert.strictEqual(r.ok, true);
  assert.strictEqual(r.hadReasoning, true);
});

test('analyzeChatCompletion: erro OpenAI-style', () => {
  const r = analyzeChatCompletion({
    error: { message: 'invalid model' },
  });
  assert.strictEqual(r.ok, false);
  assert.match(r.errorMessage || '', /invalid model/);
});

test('normalizeUsage: filtra apenas campos numéricos conhecidos', () => {
  const u = normalizeUsage({ prompt_tokens: 1, completion_tokens: 2, total_tokens: 3, foo: 'x' });
  assert.deepStrictEqual(u, {
    prompt_tokens: 1,
    completion_tokens: 2,
    total_tokens: 3,
  });
});

test('looksLikeRateLimit: 429 e texto rate limit', () => {
  assert.strictEqual(looksLikeRateLimit('Too many requests', ''), true);
  assert.strictEqual(looksLikeRateLimit('', '{"error":{"code":429}}'), true);
  assert.strictEqual(looksLikeRateLimit('not found', ''), false);
});

test('summarizeModelListItem: id e context_length', () => {
  const s = summarizeModelListItem({
    id: 'glm-flash',
    object: 'model',
    created: 1,
    owned_by: 'litellm',
    context_length: 128000,
  });
  assert.strictEqual(s.id, 'glm-flash');
  assert.strictEqual(s.contextLength, 128000);
});
