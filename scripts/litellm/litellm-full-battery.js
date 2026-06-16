#!/usr/bin/env node
'use strict';

/**
 * Bateria LiteLLM: health, /v1/models (capacidades/contexto), chat paralelo com timeouts por modelo.
 *
 * Uso:
 *   node scripts/litellm/litellm-full-battery.js [--base URL] [--tier quick|standard|full] [--concurrency N] [--json] [--dry-probe]
 * Env: LITELLM_MASTER_KEY, LITELLM_GATEWAY_URL (fallback base)
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const {
  analyzeChatCompletion,
  looksLikeRateLimit,
  summarizeModelListItem,
} = require('./lib/litellm-battery-analyze.js');
const {
  exportBatteryTimings,
  writeBatteryMarkdownSummary,
  stampFromRunAt,
} = require('./lib/litellm-battery-export.js');

const REPO_ROOT = path.join(__dirname, '../..');
const DEFAULT_MANIFEST = path.join(__dirname, 'litellm-battery-manifest.json');

function getApiKey() {
  if (process.env.LITELLM_MASTER_KEY) return process.env.LITELLM_MASTER_KEY.trim();
  const helper = path.join(REPO_ROOT, '.claude/helpers/get-litellm-key.sh');
  try {
    if (fs.existsSync(helper)) {
      return execSync(`sh "${helper}"`, { encoding: 'utf8' }).trim();
    }
  } catch (_) {
    /* ignore */
  }
  return 'sk-litellm-default';
}

function parseArgs(argv) {
  let base = process.env.LITELLM_GATEWAY_URL || process.env.LITELLM_BASE_URL || 'http://localhost:4000';
  let tier = 'standard';
  let concurrency = 6;
  let jsonOut = false;
  let dryProbe = false;
  let manifestPath = DEFAULT_MANIFEST;
  let exportDir = process.env.LITELLM_BATTERY_EXPORT_DIR || path.join(REPO_ROOT, 'docs/litellm-battery');
  let filterProvider = '';

  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--base' && argv[i + 1]) {
      base = argv[++i];
    } else if (a === '--tier' && argv[i + 1]) {
      tier = argv[++i];
    } else if (a === '--concurrency' && argv[i + 1]) {
      concurrency = Math.max(1, parseInt(argv[++i], 10) || 6);
    } else if (a === '--json') {
      jsonOut = true;
    } else if (a === '--dry-probe') {
      dryProbe = true;
    } else if (a === '--manifest' && argv[i + 1]) {
      manifestPath = path.resolve(argv[++i]);
    } else if (a === '--export-dir' && argv[i + 1]) {
      exportDir = path.resolve(argv[++i]);
    } else if (a === '--no-export') {
      exportDir = '';
    } else if (a === '--filter-provider' && argv[i + 1]) {
      filterProvider = argv[++i].trim().toLowerCase();
    } else if (a === '--help' || a === '-h') {
      console.log(`Usage: node litellm-full-battery.js [--base URL] [--tier quick|standard|full] [--concurrency N] [--json] [--manifest path] [--export-dir path] [--no-export] [--filter-provider name] [--dry-probe]`);
      process.exit(0);
    }
  }

  if (!['quick', 'standard', 'full'].includes(tier)) {
    console.error(`Tier inválido: ${tier}`);
    process.exit(2);
  }

  const baseTrim = base.replace(/\/$/, '');
  const chatUrl = baseTrim.endsWith('/v1') ? `${baseTrim}/chat/completions` : `${baseTrim}/v1/chat/completions`;
  const modelsUrl = baseTrim.endsWith('/v1') ? `${baseTrim}/models` : `${baseTrim}/v1/models`;

  return { base: baseTrim, chatUrl, modelsUrl, tier, concurrency, jsonOut, dryProbe, manifestPath, exportDir, filterProvider };
}

function matchTier(row, tier) {
  if (tier === 'full') return true;
  if (tier === 'standard') return row.runFor.includes('standard');
  return row.runFor.includes('quick');
}

function loadManifest(manifestPath) {
  const raw = fs.readFileSync(manifestPath, 'utf8');
  const data = JSON.parse(raw);
  if (!Array.isArray(data.models)) {
    throw new Error('manifest.models deve ser array');
  }
  return data.models;
}

async function timedFetch(url, init) {
  const t0 = Date.now();
  let res;
  let text = '';
  try {
    res = await fetch(url, init);
    text = await res.text();
  } catch (err) {
    return {
      ok: false,
      status: 0,
      ms: Date.now() - t0,
      error: err.message || String(err),
      body: null,
      text: '',
    };
  }
  let body = null;
  try {
    body = JSON.parse(text);
  } catch {
    body = null;
  }
  return {
    ok: res.ok,
    status: res.status,
    ms: Date.now() - t0,
    error: null,
    body,
    text: text.slice(0, 4000),
  };
}

async function runPool(items, limit, fn) {
  const results = new Array(items.length);
  let next = 0;
  async function worker() {
    for (;;) {
      const i = next;
      if (i >= items.length) return;
      next = i + 1;
      results[i] = await fn(items[i], i);
    }
  }
  const n = Math.min(limit, Math.max(1, items.length));
  await Promise.all(Array.from({ length: n }, () => worker()));
  return results;
}

async function main() {
  const opts = parseArgs(process.argv);
  const key = getApiKey();
  const PROMPT =
    'Responde apenas com a palavra OK, sem pontuação nem explicação.';

  const manifest = loadManifest(opts.manifestPath);
  const modelsToRun = manifest
    .filter((r) => matchTier(r, opts.tier))
    .filter((r) => !opts.filterProvider || (r.provider || '').toLowerCase() === opts.filterProvider);

  const report = {
    gateway: opts.base,
    tier: opts.tier,
    concurrency: opts.concurrency,
    startedAt: new Date().toISOString(),
    manifest: opts.manifestPath,
    modelsPlanned: modelsToRun.length,
    health: null,
    readiness: null,
    modelList: null,
    contextStats: null,
    chats: [],
    summary: { pass: 0, fail: 0, warn: 0 },
  };

  const [health, readiness, modelList] = await Promise.all([
    timedFetch(`${opts.base}/health`, { signal: AbortSignal.timeout(8000) }),
    timedFetch(`${opts.base}/health/readiness`, { signal: AbortSignal.timeout(8000) }),
    timedFetch(opts.modelsUrl, {
      headers: { Authorization: `Bearer ${key}` },
      signal: AbortSignal.timeout(30000),
    }),
  ]);

  report.health = { http: health.status, ms: health.ms, ok: health.status === 200, error: health.error };
  report.readiness = {
    http: readiness.status,
    ms: readiness.ms,
    ok: readiness.status === 200,
    error: readiness.error,
  };

  const listedIds = new Set();
  const contextLengths = [];
  if (modelList.body && Array.isArray(modelList.body.data)) {
    for (const item of modelList.body.data) {
      const s = summarizeModelListItem(item);
      if (s.id) listedIds.add(s.id);
      if (s.contextLength != null) contextLengths.push(s.contextLength);
    }
  }
  report.modelList = {
    http: modelList.status,
    ms: modelList.ms,
    count: listedIds.size,
    ok: modelList.ok && listedIds.size > 0,
    error: modelList.error,
  };

  if (contextLengths.length) {
    contextLengths.sort((a, b) => a - b);
    const p = (q) => contextLengths[Math.floor((q / 100) * (contextLengths.length - 1))];
    report.contextStats = {
      min: contextLengths[0],
      max: contextLengths[contextLengths.length - 1],
      p50: p(50),
      modelsWithContextField: contextLengths.length,
    };
  } else {
    report.contextStats = null;
  }

  if (opts.dryProbe) {
    if (opts.jsonOut) console.log(JSON.stringify(report, null, 2));
    else {
      console.log('Dry probe: health + readiness + model list only.');
      console.log(JSON.stringify(report, null, 2));
    }
    const gatewayOk = report.health.ok || report.readiness.ok;
    process.exit(gatewayOk ? 0 : 1);
  }

  const chatResults = await runPool(modelsToRun, opts.concurrency, async (spec) => {
    const t0 = Date.now();
    const timeoutMs = Math.max(5000, (spec.timeoutSec || 60) * 1000);
    /** @type {Record<string, unknown>} */
    const row = {
      id: spec.id,
      provider: spec.provider || 'unknown',
      optional: !!spec.optional,
      expectUsage: spec.expectUsage !== false,
      maxTokens: spec.maxTokens,
      timeoutSec: spec.timeoutSec,
      httpStatus: 0,
      ms: 0,
      listed: listedIds.has(spec.id),
      analysis: {
        ok: false,
        contentLength: 0,
        usage: null,
        finishReason: null,
        errorMessage: null,
        hasChoices: false,
        hadReasoning: false,
      },
      rawSnippet: '',
      ok: false,
      softWarn: false,
    };

    try {
      const res = await fetch(opts.chatUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${key}`,
        },
        body: JSON.stringify({
          model: spec.id,
          messages: [{ role: 'user', content: PROMPT }],
          max_tokens: spec.maxTokens || 24,
        }),
        signal: AbortSignal.timeout(timeoutMs),
      });

      row.httpStatus = res.status;
      const text = await res.text();
      row.rawSnippet = text.slice(0, 400);
      let body;
      try {
        body = JSON.parse(text);
      } catch {
        body = { error: { message: 'JSON inválido na resposta' } };
      }

      if (body.model) row.modelReturned = body.model;

      row.analysis = analyzeChatCompletion(body);
      row.ms = Date.now() - t0;

      const errMsg = row.analysis.errorMessage || '';
      if (row.analysis.ok) {
        if (spec.expectUsage !== false && !row.analysis.usage) {
          row.ok = false;
          row.analysis.errorMessage = 'usage ausente (espelhava contagem de tokens)';
        } else {
          row.ok = true;
        }
      } else if (spec.optional) {
        const blob = `${errMsg} ${text}`;
        const rateOrAuth =
          looksLikeRateLimit(errMsg, text) || [401, 402, 429].includes(res.status);
        const modelIndisponivel =
          !row.listed ||
          res.status === 404 ||
          (res.status === 400 && /invalid model|unknown model|not available|\/v1\/models/i.test(blob));
        if (rateOrAuth || modelIndisponivel) {
          row.softWarn = true;
          row.ok = true;
        } else {
          row.ok = false;
        }
      } else {
        row.ok = false;
      }
    } catch (err) {
      row.ms = Date.now() - t0;
      row.analysis = analyzeChatCompletion({
        error: { message: err.name === 'TimeoutError' ? 'timeout' : err.message },
      });
      if (spec.optional) {
        row.softWarn = true;
        row.ok = true;
      } else {
        row.ok = false;
      }
    }

    return row;
  });

  report.chats = chatResults;

  report.responseTimes = chatResults.map((c) => ({
    modelId: c.id,
    provider: c.provider,
    latencyMs: c.ms,
    httpStatus: c.httpStatus,
    ok: c.ok,
    softWarn: c.softWarn,
  }));

  for (const c of chatResults) {
    if (c.ok && c.softWarn) report.summary.warn++;
    else if (c.ok) report.summary.pass++;
    else report.summary.fail++;
  }

  if (!opts.jsonOut) {
    console.log(`\n=== LiteLLM bateria — ${opts.tier} — ${opts.base} ===\n`);
    console.log(
      `Health: ${report.health.http} (${report.health.ms}ms) | Readiness: ${report.readiness.http} (${report.readiness.ms}ms)`,
    );
    console.log(
      `Model list: HTTP ${report.modelList.http}, ${report.modelList.count} ids (${report.modelList.ms}ms)`,
    );
    if (report.contextStats) {
      console.log(
        `Context window field (amostra): min=${report.contextStats.min} max=${report.contextStats.max} p50≈${report.contextStats.p50} (modelos com campo: ${report.contextStats.modelsWithContextField})`,
      );
    }
    console.log('');
    for (const c of chatResults) {
      const u = c.analysis.usage;
      const usageStr = u
        ? `usage prompt=${u.prompt_tokens ?? '—'} completion=${u.completion_tokens ?? '—'} total=${u.total_tokens ?? '—'}`
        : 'usage —';
      const listed = c.listed ? 'listed' : 'NOT in /v1/models';
      const tag = c.ok ? (c.softWarn ? 'WARN' : 'OK ') : 'FAIL';
      const fin = c.analysis.finishReason || '—';
      console.log(
        `[${tag}] ${c.id}  ${c.ms}ms  http=${c.httpStatus}  finish=${fin}  ${listed}  ${usageStr}`,
      );
      if (!c.ok) {
        console.log(`      erro: ${c.analysis.errorMessage || c.rawSnippet.slice(0, 160)}`);
      }
    }
    console.log(
      `\nResumo: ${report.summary.pass} ok | ${report.summary.fail} falha(s) | ${report.summary.warn} aviso(s) opcional/429\n`,
    );
  } else {
    console.log(JSON.stringify(report, null, 2));
  }

  if (opts.exportDir && !opts.dryProbe) {
    const exported = exportBatteryTimings(report, manifest, opts.exportDir);
    const stamp = stampFromRunAt(report.startedAt);
    const mdPath = path.join(opts.exportDir, `battery-${stamp}.md`);
    writeBatteryMarkdownSummary(report, mdPath);
    if (!opts.jsonOut) {
      console.log(`Tempos guardados: ${exported.csvPath}`);
      console.log(`Latest CSV: ${exported.latestPath}`);
      console.log(`Histórico JSONL: ${exported.historyPath}`);
      console.log(`Relatório MD: ${mdPath}`);
    }
    report.export = exported;
  }

  process.exit(report.summary.fail > 0 ? 1 : 0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
