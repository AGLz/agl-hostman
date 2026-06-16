'use strict';

const fs = require('fs');
const path = require('path');

/**
 * @param {string} runAt ISO timestamp
 * @returns {string}
 */
function stampFromRunAt(runAt) {
  const d = new Date(runAt);
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getUTCFullYear()}${pad(d.getUTCMonth() + 1)}${pad(d.getUTCDate())}-${pad(d.getUTCHours())}${pad(d.getUTCMinutes())}${pad(d.getUTCSeconds())}`;
}

/**
 * @param {Record<string, unknown>} report
 * @param {Array<{ id: string, provider?: string, tier?: string }>} manifest
 * @returns {Array<Record<string, unknown>>}
 */
function buildTimingRows(report, manifest) {
  const specById = new Map(manifest.map((m) => [m.id, m]));
  const runAt = report.startedAt || new Date().toISOString();
  const gateway = report.gateway || '';
  const tier = report.tier || 'full';

  return (report.chats || []).map((c) => {
    const spec = specById.get(c.id) || {};
    const u = c.analysis?.usage || null;
    return {
      runAt,
      gateway,
      tier,
      modelId: c.id,
      provider: spec.provider || 'unknown',
      modelTier: spec.tier || '',
      httpStatus: c.httpStatus ?? 0,
      latencyMs: c.ms ?? 0,
      ok: !!c.ok,
      softWarn: !!c.softWarn,
      optional: !!c.optional,
      listed: !!c.listed,
      finishReason: c.analysis?.finishReason || '',
      promptTokens: u?.prompt_tokens ?? '',
      completionTokens: u?.completion_tokens ?? '',
      totalTokens: u?.total_tokens ?? '',
      reasoningTokens: u?.reasoning_tokens ?? '',
      error: c.analysis?.errorMessage || '',
    };
  });
}

const CSV_COLUMNS = [
  'runAt',
  'gateway',
  'tier',
  'modelId',
  'provider',
  'modelTier',
  'httpStatus',
  'latencyMs',
  'ok',
  'softWarn',
  'optional',
  'listed',
  'finishReason',
  'promptTokens',
  'completionTokens',
  'totalTokens',
  'reasoningTokens',
  'error',
];

/**
 * @param {unknown} v
 * @returns {string}
 */
function csvCell(v) {
  const s = v === null || v === undefined ? '' : String(v);
  if (/[",\n\r]/.test(s)) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

/**
 * @param {Array<Record<string, unknown>>} rows
 * @returns {string}
 */
function rowsToCsv(rows) {
  const lines = [CSV_COLUMNS.join(',')];
  for (const row of rows) {
    lines.push(CSV_COLUMNS.map((col) => csvCell(row[col])).join(','));
  }
  return `${lines.join('\n')}\n`;
}

/**
 * @param {Record<string, unknown>} report
 * @param {Array<{ id: string, provider?: string, tier?: string }>} manifest
 * @param {string} exportDir
 * @returns {{ csvPath: string, latestPath: string, historyPath: string, jsonPath: string, rowCount: number }}
 */
function exportBatteryTimings(report, manifest, exportDir) {
  fs.mkdirSync(exportDir, { recursive: true });
  const rows = buildTimingRows(report, manifest);
  const stamp = stampFromRunAt(report.startedAt || new Date().toISOString());
  const csvPath = path.join(exportDir, `timings-${stamp}.csv`);
  const latestPath = path.join(exportDir, 'timings-latest.csv');
  const historyPath = path.join(exportDir, 'timings-history.jsonl');
  const jsonPath = path.join(exportDir, `battery-${stamp}.json`);

  const csv = rowsToCsv(rows);
  fs.writeFileSync(csvPath, csv, 'utf8');
  fs.writeFileSync(latestPath, csv, 'utf8');

  const historyChunk = rows.map((r) => `${JSON.stringify(r)}\n`).join('');
  fs.appendFileSync(historyPath, historyChunk, 'utf8');

  const payload = {
    ...report,
    responseTimes: rows.map((r) => ({
      modelId: r.modelId,
      provider: r.provider,
      latencyMs: r.latencyMs,
      httpStatus: r.httpStatus,
      ok: r.ok,
      softWarn: r.softWarn,
    })),
  };
  fs.writeFileSync(jsonPath, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');

  return { csvPath, latestPath, historyPath, jsonPath, rowCount: rows.length };
}

/**
 * @param {Record<string, unknown>} report
 * @param {string} mdPath
 */
function writeBatteryMarkdownSummary(report, mdPath) {
  const chats = report.chats || [];
  const byProvider = new Map();
  for (const c of chats) {
    const p = c.provider || 'unknown';
    if (!byProvider.has(p)) {
      byProvider.set(p, { ok: 0, warn: 0, fail: 0, latencies: [] });
    }
    const bucket = byProvider.get(p);
    if (c.ok && c.softWarn) bucket.warn++;
    else if (c.ok) bucket.ok++;
    else bucket.fail++;
    if (typeof c.ms === 'number' && c.ms > 0) bucket.latencies.push(c.ms);
  }

  const lines = [
    `# Bateria LiteLLM — ${report.tier || 'full'}`,
    '',
    `**Gerado:** ${report.startedAt || '—'}`,
    `**Gateway:** \`${report.gateway || '—'}\``,
    `**Modelos:** ${report.modelsPlanned ?? chats.length}`,
    `**Resumo:** ${report.summary?.pass ?? 0} OK · ${report.summary?.warn ?? 0} aviso · ${report.summary?.fail ?? 0} falha`,
    '',
    '## Latência por provider (ms, modelos com resposta)',
    '',
    '| Provider | OK | Aviso | Falha | p50 | p95 | max |',
    '|----------|-----|-------|-------|-----|-----|-----|',
  ];

  for (const [provider, b] of [...byProvider.entries()].sort((a, b) => a[0].localeCompare(b[0]))) {
    const lat = [...b.latencies].sort((x, y) => x - y);
    const p = (q) => (lat.length ? lat[Math.floor((q / 100) * (lat.length - 1))] : '—');
    lines.push(
      `| ${provider} | ${b.ok} | ${b.warn} | ${b.fail} | ${p(50)} | ${p(95)} | ${lat.length ? lat[lat.length - 1] : '—'} |`,
    );
  }

  lines.push('', '## Tempos por modelo (ordenado por latência)', '', '| Modelo | ms | HTTP | Estado |', '|--------|-----|------|--------|');
  const sorted = [...chats].sort((a, b) => (a.ms || 0) - (b.ms || 0));
  for (const c of sorted) {
    const tag = c.ok ? (c.softWarn ? 'WARN' : 'OK') : 'FAIL';
    lines.push(`| \`${c.id}\` | ${c.ms ?? '—'} | ${c.httpStatus ?? '—'} | ${tag} |`);
  }
  lines.push('');

  fs.writeFileSync(mdPath, `${lines.join('\n')}\n`, 'utf8');
}

module.exports = {
  buildTimingRows,
  rowsToCsv,
  exportBatteryTimings,
  writeBatteryMarkdownSummary,
  stampFromRunAt,
};
