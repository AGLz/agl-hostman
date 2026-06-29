"use strict";

const { test } = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.join(__dirname, "../..");
const SECURE = path.join(ROOT, "scripts/proxmox/hermes-secure-routing-ct188.sh");
const CRON = path.join(ROOT, "scripts/proxmox/fix-hermes-cron-models-ct188.sh");
const QUARTET = path.join(ROOT, "scripts/proxmox/fix-hermes-quartet-models-ct188.sh");
const CONFIG = path.join(ROOT, "config/litellm/config.yaml");

// VMs GPU (VM110/VM310) SUSPENSAS 2026-06-29 → tier sensível usa cloud ZDR no-logging.
// Modelos que LOGAM/TREINAM prompts — proibidos em qualquer caminho sensível.
// (groq e or-*-free com data_collection=deny são ZDR/no-logging → permitidos.)
const LOGGING = [/or-owl-alpha/, /or-nemotron/, /zai-/, /glm-/, /gpt-/, /claude-/];

// Modelos ZDR/no-logging aceitáveis para dados sensíveis enquanto não há local.
const ZDR_SAFE = ["or-qwen3-next-free", "or-qwen3-coder-free", "or-hermes-free", "or-llama-3.3-70b-free", "groq-llama-31-8b"];

test("hermes-secure-routing roteia o swarm p/ agl-sensitive com fallback ZDR cloud (VMs GPU suspensas)", () => {
  assert.ok(fs.existsSync(SECURE), "script de routing sensível ausente");
  const c = fs.readFileSync(SECURE, "utf8");
  assert.match(c, /ALL_AGENTS=\(jarvis curator elon satya werner orion argus verifier\)/);
  assert.match(c, /agl-sensitive/);
  // fallbacks agora ZDR cloud (era agl-primary-strong,agl-primary-vm110,agl-primary-fast)
  assert.match(c, /or-qwen3-next-free,or-hermes-free,or-llama-3.3-70b-free,groq-llama-31-8b/);
});

test("routing sensível não contém NENHUM modelo que loga/treina", () => {
  const c = fs.readFileSync(SECURE, "utf8");
  // remover comentários para não apanhar menções em avisos/REVERTER
  const code = c
    .split("\n")
    .filter((l) => !l.trimStart().startsWith("#"))
    .join("\n");
  for (const re of LOGGING) {
    assert.doesNotMatch(code, re, `modelo logging proibido no caminho sensível: ${re}`);
  }
});

test("config.yaml: agl-sensitive = ZDR no-logging cloud (data_collection=deny + zdr)", () => {
  const c = fs.readFileSync(CONFIG, "utf8");
  assert.match(c, /model_name: agl-sensitive/);
  assert.match(c, /data_policy: zdr-no-logging-cloud/);
  // cadeia de fallback do router só pode conter modelos ZDR/no-logging
  const block = c.split("- agl-sensitive:\n")[1]?.split(/\n    - [a-z]/)[0] ?? "";
  assert.ok(block.length > 0, "fallback agl-sensitive ausente no router");
  const lines = block
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l.startsWith("- "))
    .map((l) => l.replace(/^- /, ""));
  assert.ok(lines.length >= 2, "cadeia de fallback demasiado curta");
  for (const m of lines) {
    assert.ok(ZDR_SAFE.includes(m), `fallback não-ZDR na cadeia sensível: ${m}`);
  }
});

test("config.yaml: nenhum endpoint Ollama local ativo (VMs GPU suspensas)", () => {
  const c = fs.readFileSync(CONFIG, "utf8");
  const code = c
    .split("\n")
    .filter((l) => !l.trimStart().startsWith("#") && !l.includes("note:"))
    .join("\n");
  assert.doesNotMatch(code, /api_base:\s*http:\/\/100\.67\.253\.52/, "endpoint VM310 ainda ativo");
  assert.doesNotMatch(code, /api_base:\s*http:\/\/100\.74\.118\.51/, "endpoint VM110 ainda ativo");
});

test("crons: default agl-sensitive (ZDR cloud) + fallback ZDR (sem VM local)", () => {
  const c = fs.readFileSync(CRON, "utf8");
  assert.match(c, /CRON_MODEL="\$\{CRON_MODEL:-agl-sensitive\}"/);
  assert.match(c, /CRON_FALLBACK="\$\{CRON_FALLBACK:-or-qwen3-next-free\}"/);
});

test("fix-hermes-quartet: default --no-logging, tiers --local e --logging-public", () => {
  const q = fs.readFileSync(QUARTET, "utf8");
  assert.match(q, /MODE="\$\{1:---no-logging\}"/);
  assert.match(q, /--no-logging\|--secure\|--openrouter-free\)/);
  assert.match(q, /--local\|--secure-local\)/);
  assert.match(q, /--logging-public\)/);
  assert.match(q, /hermes-secure-routing-ct188\.sh/);
  assert.match(q, /HERMES_USE_LOGGING_FREE=1/);
});
