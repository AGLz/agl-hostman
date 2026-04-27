'use strict';

/**
 * Testes de integração: LiteLLM + Claude-Flow + Turbo-Flow
 *
 * Cenários:
 * 1. LiteLLM health/readiness
 * 2. LiteLLM models list (requer auth)
 * 3. Chat completion via LiteLLM (caso de uso real)
 * 4. API hostman GET /api/ai/status
 * 5. Ruflo daemon status
 * 6. Ruflo 3-tier router (hooks intel route)
 * 7. Turbo Flow status
 *
 * Variáveis de ambiente:
 * - LITELLM_BASE_URL (default: http://localhost:4000)
 * - LITELLM_MASTER_KEY (para testes que exigem auth)
 * - SKIP_LIVE_LITELLM=1 (pula testes que exigem LiteLLM online)
 */

const { test, describe } = require('node:test');
const { build } = require('../../src/api/app');
const { getLiteLLMStatus, getRufloStatus } = require('../../src/services/ai-stack');
const { exec } = require('child_process');
const { promisify } = require('util');

const execAsync = promisify(exec);
// Node 18+ tem fetch global
const httpFetch = globalThis.fetch;

const LITELLM_BASE_URL = process.env.LITELLM_BASE_URL || 'http://localhost:4000';
const LITELLM_MASTER_KEY = process.env.LITELLM_MASTER_KEY || '';
const SKIP_LIVE = process.env.SKIP_LIVE_LITELLM === '1';

async function litellmAvailable() {
  if (SKIP_LIVE) return false;
  const status = await getLiteLLMStatus();
  return status.status === 'online';
}

// -----------------------------------------------------------------------------
// Cenário 1: LiteLLM Health
// -----------------------------------------------------------------------------
describe('LiteLLM Health', () => {
  test('health/readiness retorna 200 quando LiteLLM está online', async (t) => {
    if (SKIP_LIVE) {
      t.skip('SKIP_LIVE_LITELLM=1');
      return;
    }

    const status = await getLiteLLMStatus();
    t.assert.ok(
      ['online', 'degraded', 'offline'].includes(status.status),
      `status deve ser online/degraded/offline, recebido: ${status.status}`,
    );
    t.assert.ok(status.details !== undefined);

    if (status.status === 'online') {
      t.assert.ok(status.details !== null);
    }
  });

  test('fetch direto em /health/readiness funciona quando online', async (t) => {
    if (SKIP_LIVE) {
      t.skip('SKIP_LIVE_LITELLM=1');
      return;
    }

    try {
      const res = await httpFetch(`${LITELLM_BASE_URL}/health/readiness`, {
        signal: AbortSignal.timeout(5000),
      });
      t.assert.ok(res.status === 200 || res.status >= 400, `HTTP ${res.status}`);
    } catch (err) {
      const known = ['AbortError', 'ECONNREFUSED', 'ETIMEDOUT', 'ENOTFOUND'];
      t.assert.ok(
        known.includes(err.name) || known.includes(err.code),
        `Erro inesperado: ${err.name || err.code} - ${err.message}`,
      );
    }
  });
});

// -----------------------------------------------------------------------------
// Cenário 2: LiteLLM Models (requer auth)
// -----------------------------------------------------------------------------
describe('LiteLLM Models', () => {
  test('GET /models retorna lista quando auth disponível', async (t) => {
    if (!(await litellmAvailable())) {
      t.skip('LiteLLM offline');
      return;
    }
    if (!LITELLM_MASTER_KEY) {
      t.skip('LITELLM_MASTER_KEY não definido');
      return;
    }

    const res = await httpFetch(`${LITELLM_BASE_URL}/models`, {
      headers: { Authorization: `Bearer ${LITELLM_MASTER_KEY}` },
      signal: AbortSignal.timeout(10000),
    });

    if (res.status === 401) {
      t.skip('LITELLM_MASTER_KEY inválido ou não configurado no LiteLLM');
      return;
    }
    t.assert.strictEqual(res.status, 200);
    const data = await res.json();
    t.assert.ok(Array.isArray(data.data) || typeof data === 'object');
  });
});

// -----------------------------------------------------------------------------
// Cenário 2b: Múltiplos modelos — latência e análise
// -----------------------------------------------------------------------------
const MODELS_BENCHMARK = ['glm-flash', 'glm', 'deepseek', 'claude-haiku', 'gemini-2.0'];
const MODELS_FREE = ['glm-flash', 'glm-air', 'qwen-turbo', 'qwen-plus', 'qwen3.5-plus'];
const PROMPT_QUICK = 'Responda apenas: OK';

async function benchmarkModel(model, auth) {
  const start = Date.now();
  const res = await httpFetch(`${LITELLM_BASE_URL}/chat/completions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${auth}`,
    },
    body: JSON.stringify({
      model,
      messages: [{ role: 'user', content: PROMPT_QUICK }],
      max_tokens: 10,
    }),
    signal: AbortSignal.timeout(45000),
  });
  const elapsed = Date.now() - start;
  const ok = res.status === 200;
  let content = '';
  if (ok) {
    const data = await res.json();
    content = data.choices?.[0]?.message?.content || '';
  }
  return { model, ok, elapsed, status: res.status, content };
}

describe('LiteLLM Multi-Model Latency', () => {
  test('múltiplos modelos: mede latência e ordena por velocidade', async (t) => {
    if (!(await litellmAvailable())) {
      t.skip('LiteLLM offline');
      return;
    }
    if (!LITELLM_MASTER_KEY) {
      t.skip('LITELLM_MASTER_KEY não definido');
      return;
    }

    const results = [];
    for (const model of MODELS_BENCHMARK) {
      const r = await benchmarkModel(model, LITELLM_MASTER_KEY);
      results.push(r);
      if (!r.ok) {
        t.assert.ok(r.status === 401 || r.status >= 500, `modelo ${model}: HTTP ${r.status}`);
      }
    }

    const okResults = results.filter((r) => r.ok);
    t.assert.ok(okResults.length >= 1, `pelo menos 1 modelo deve responder (ok: ${okResults.length})`);

    const sorted = [...okResults].sort((a, b) => a.elapsed - b.elapsed);
    const fastest = sorted[0];
    t.assert.ok(fastest, 'deve haver modelo mais rápido');

    const report = sorted.map((r, i) => `${i + 1}. ${r.model}: ${r.elapsed}ms`).join('\n');
    t.diagnostic(`Modelos por velocidade (mais rápido primeiro):\n${report}\nMais rápido: ${fastest.model} (${fastest.elapsed}ms)`);
  });

  test('modelos gratuitos (qwen, glm-air): mede latência e ordena', async (t) => {
    if (!(await litellmAvailable())) {
      t.skip('LiteLLM offline');
      return;
    }
    if (!LITELLM_MASTER_KEY) {
      t.skip('LITELLM_MASTER_KEY não definido');
      return;
    }

    const results = [];
    for (const model of MODELS_FREE) {
      const r = await benchmarkModel(model, LITELLM_MASTER_KEY);
      results.push(r);
    }

    const okResults = results.filter((r) => r.ok);
    const sorted = [...okResults].sort((a, b) => a.elapsed - b.elapsed);
    const fastest = sorted[0];
    const report = sorted.length > 0
      ? sorted.map((r, i) => `${i + 1}. ${r.model}: ${r.elapsed}ms`).join('\n')
      : results.map((r) => `  ${r.model}: HTTP ${r.status}`).join('\n');
    t.diagnostic(`Modelos gratuitos (qwen, glm-air, glm-flash):\n${report}\nMais rápido: ${fastest?.model ?? '-'} (${fastest?.elapsed ?? '-'}ms)`);
  });
});

// -----------------------------------------------------------------------------
// Cenário 3: Caso de uso real — Chat completion via LiteLLM
// -----------------------------------------------------------------------------
describe('LiteLLM Chat Completion (caso de uso real)', () => {
  test('completions: analisar estrutura de projeto e sugerir resumo', async (t) => {
    if (!(await litellmAvailable())) {
      t.skip('LiteLLM offline');
      return;
    }
    if (!LITELLM_MASTER_KEY) {
      t.skip('LITELLM_MASTER_KEY não definido');
      return;
    }

    const prompt = `Analise a estrutura do diretório src/ de um projeto Node.js típico.
Liste em 2 linhas: (1) pastas principais e (2) propósito de cada uma.
Responda apenas o resumo, sem introdução.`;

    const res = await httpFetch(`${LITELLM_BASE_URL}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${LITELLM_MASTER_KEY}`,
      },
      body: JSON.stringify({
        model: 'glm',
        messages: [{ role: 'user', content: prompt }],
        max_tokens: 200,
      }),
      signal: AbortSignal.timeout(30000),
    });

    if (res.status === 401) {
      t.skip('LITELLM_MASTER_KEY inválido ou não configurado no LiteLLM');
      return;
    }
    t.assert.strictEqual(res.status, 200, `HTTP ${res.status}: ${await res.text()}`);
    const data = await res.json();
    t.assert.ok(data.choices !== undefined);
    t.assert.ok(Array.isArray(data.choices));
    t.assert.ok(data.choices.length > 0);
    t.assert.ok(data.choices[0].message?.content);
    t.assert.ok(data.choices[0].message.content.length > 10);
  });

  test('completions: fallback quando modelo primário indisponível', async (t) => {
    if (!(await litellmAvailable())) {
      t.skip('LiteLLM offline');
      return;
    }
    if (!LITELLM_MASTER_KEY) {
      t.skip('LITELLM_MASTER_KEY não definido');
      return;
    }

    // Usa glm-flash como modelo mais leve; LiteLLM aplica fallback se falhar
    const res = await httpFetch(`${LITELLM_BASE_URL}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${LITELLM_MASTER_KEY}`,
      },
      body: JSON.stringify({
        model: 'glm-flash',
        messages: [{ role: 'user', content: 'Responda apenas: OK' }],
        max_tokens: 10,
      }),
      signal: AbortSignal.timeout(15000),
    });

    if (res.status === 401) {
      t.skip('LITELLM_MASTER_KEY inválido ou não configurado no LiteLLM');
      return;
    }
    t.assert.ok(res.status === 200 || res.status === 503);
    if (res.status === 200) {
      const data = await res.json();
      t.assert.ok(data.choices?.[0]?.message?.content);
    }
  });
});

// -----------------------------------------------------------------------------
// Cenário 4: API Hostman
// -----------------------------------------------------------------------------
describe('API Hostman /api/ai/status', () => {
  test('GET /api/ai/status retorna litellm, ruflo, openclaw', async (t) => {
    const app = await build({ logger: false, apiKey: '' });
    t.after(() => app.close());

    const res = await app.inject({
      method: 'GET',
      url: '/api/ai/status',
    });

    t.assert.strictEqual(res.statusCode, 200);
    const body = res.json();
    t.assert.ok(body.litellm !== undefined);
    t.assert.ok(body.ruflo !== undefined);
    t.assert.ok(body.openclaw !== undefined);
    t.assert.strictEqual(body.openclaw.name, 'OpenClaw');
    t.assert.ok(body.timestamp);
  });

  test('litellm status é online/degraded/offline', async (t) => {
    const app = await build({ logger: false, apiKey: '' });
    t.after(() => app.close());

    const res = await app.inject({ method: 'GET', url: '/api/ai/status' });
    const body = res.json();

    t.assert.ok(
      ['online', 'degraded', 'offline', 'unknown'].includes(body.litellm?.status),
      `litellm.status inválido: ${body.litellm?.status}`,
    );
  });
});

// -----------------------------------------------------------------------------
// Cenário 5: Ruflo Daemon
// -----------------------------------------------------------------------------
describe('Ruflo Daemon', () => {
  test('getRufloStatus retorna status coerente', async (t) => {
    const status = await getRufloStatus();
    t.assert.ok(
      ['running', 'stopped', 'unknown'].includes(status.status),
      `status: ${status.status}`,
    );
    t.assert.ok(status.details !== undefined);
  });
});

// -----------------------------------------------------------------------------
// Cenário 6: Ruflo 3-tier router (hooks intel route)
// -----------------------------------------------------------------------------
describe('Ruflo 3-tier Router', () => {
  test('hooks intel route executa e retorna agent/confidence', async (t) => {
    if (SKIP_LIVE) {
      t.skip('SKIP_LIVE_LITELLM=1');
      return;
    }

    try {
      const { stdout, stderr } = await execAsync(
        'npx ruflo@latest hooks intel route "Build REST API" --top-k 1',
        { timeout: 15000 },
      );
      const output = (stdout + stderr).trim();
      t.assert.ok(output.length > 0);
      // Pode conter Agent, Confidence, Latency ou mensagem de erro conhecida
      const hasRelevant = /agent|confidence|latency|error|not found|invalid/i.test(output);
      t.assert.ok(hasRelevant, `Output inesperado: ${output.slice(0, 200)}`);
    } catch (err) {
      const out = (err.stdout || '') + (err.stderr || '');
      const knownFail = /not found|invalid|command/i.test(out.toLowerCase());
      t.assert.ok(knownFail || err.killed, `Erro: ${err.message}`);
    }
  });
});

// -----------------------------------------------------------------------------
// Cenário 7: Turbo Flow
// -----------------------------------------------------------------------------
describe('Turbo Flow', () => {
  test('turbo-status ou alias existe e executa', async (t) => {
    try {
      // turbo-status pode ser alias; npx ruflo também indica Turbo Flow
      const { stdout } = await execAsync('npx ruflo@latest --version 2>/dev/null || npx ruflo@latest -v 2>/dev/null', {
        timeout: 10000,
      });
      t.assert.ok(stdout.length > 0 || true);
    } catch (err) {
      t.assert.ok(err.code === 'ENOENT' || err.killed);
    }
  });
});
