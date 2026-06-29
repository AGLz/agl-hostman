"use strict";

const { test } = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.join(__dirname, "../..");
const SECURE = path.join(ROOT, "scripts/proxmox/hermes-secure-routing-ct188.sh");
const FREE = path.join(ROOT, "scripts/proxmox/hermes-openrouter-free-ct188.sh");
const CRON = path.join(ROOT, "scripts/proxmox/fix-hermes-cron-models-ct188.sh");
const QUARTET = path.join(ROOT, "scripts/proxmox/fix-hermes-quartet-models-ct188.sh");
const CONFIG = path.join(ROOT, "config/litellm/config.yaml");

// Modelos que retêm/logam prompts (externos). Proibidos em qualquer caminho sensível.
const LOGGING = [/or-owl-alpha/, /or-nemotron/, /groq/, /zai-/, /glm-/, /openrouter\//, /gpt-/, /claude-/];

test("hermes-secure-routing existe e roteia todo o swarm para agl-sensitive (local)", () => {
  assert.ok(fs.existsSync(SECURE), "script de routing seguro ausente");
  const c = fs.readFileSync(SECURE, "utf8");
  assert.match(c, /ALL_AGENTS=\(jarvis curator elon satya werner orion argus verifier\)/);
  assert.match(c, /agl-sensitive/);
  assert.match(c, /agl-primary-strong,agl-primary-vm110,agl-primary-fast/);
});

test("routing seguro nao contem NENHUM modelo externo/logging", () => {
  const c = fs.readFileSync(SECURE, "utf8");
  // remover comentarios para nao apanhar mencoes em avisos
  const code = c
    .split("\n")
    .filter((l) => !l.trimStart().startsWith("#"))
    .join("\n");
  for (const re of LOGGING) {
    assert.doesNotMatch(code, re, `modelo logging proibido no caminho sensivel: ${re}`);
  }
});

test("config.yaml define agl-sensitive como local-only zero-logging", () => {
  const c = fs.readFileSync(CONFIG, "utf8");
  assert.match(c, /model_name: agl-sensitive/);
  assert.match(c, /data_policy: local-only-zero-logging/);
  const block = c.split("- agl-sensitive:\n")[1]?.split(/\n    - [a-z]/)[0] ?? "";
  assert.ok(block.length > 0, "fallback agl-sensitive ausente no router");
  // toda a cadeia tem de ser agl-primary* (local)
  const lines = block
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l.startsWith("- "))
    .map((l) => l.replace(/^- /, ""));
  assert.ok(lines.length >= 2, "cadeia de fallback demasiado curta");
  for (const m of lines) {
    assert.match(m, /^agl-primary/, `fallback nao-local na cadeia sensivel: ${m}`);
  }
});

test("crons usam modelo local por default (leem segundo cerebro/leads)", () => {
  const c = fs.readFileSync(CRON, "utf8");
  assert.match(c, /CRON_MODEL="\$\{CRON_MODEL:-agl-sensitive\}"/);
  assert.match(c, /CRON_FALLBACK="\$\{CRON_FALLBACK:-agl-primary-vm110\}"/);
});

test("fix-hermes-quartet: default --no-logging, tiers --local e --logging-public", () => {
  const q = fs.readFileSync(QUARTET, "utf8");
  assert.match(q, /MODE="\$\{1:---no-logging\}"/);
  assert.match(q, /--no-logging\|--secure\|--openrouter-free\)/);
  assert.match(q, /--local\|--secure-local\)/);
  assert.match(q, /--logging-public\)/);
  // --local roteia para o script 100% on-prem
  assert.match(q, /hermes-secure-routing-ct188\.sh/);
  // --logging-public ativa o opt-in dos modelos que logam
  assert.match(q, /HERMES_USE_LOGGING_FREE=1/);
});
