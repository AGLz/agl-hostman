"use strict";

const { test } = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.join(__dirname, "../..");
const SCRIPT = path.join(
  ROOT,
  "scripts/proxmox/fix-hermes-jarvis-curator-resilience-ct188.sh",
);
const CURATOR_CRON = path.join(
  ROOT,
  "scripts/proxmox/setup-hermes-curator-crons-ct188.sh",
);

test("fix-hermes-jarvis-curator-resilience-ct188.sh existe e cobre jarvis/curator", () => {
  assert.ok(fs.existsSync(SCRIPT));
  assert.ok(fs.statSync(SCRIPT).mode & 0o111);
  const content = fs.readFileSync(SCRIPT, "utf8");
  assert.match(content, /or-nemotron-super-free/);
  assert.match(content, /jarvis/);
  assert.match(content, /curator/);
  assert.match(content, /openai/);
  assert.match(content, /MEMORY\.md/);
  assert.match(content, /fallback_providers/);
});

test("fallback_providers herdam api_key (evita 401 no-key-required)", () => {
  const content = fs.readFileSync(SCRIPT, "utf8");
  // Reason: provider custom exige sk-litellm-...; sem key o LiteLLM devolve 401
  assert.match(content, /for entry in fp:/);
  assert.match(content, /entry\["api_key"\] = api_key/);
  assert.match(content, /providers", \{\}\)\.setdefault\("custom"/);
});

test("cadeia de fallback sem OpenAI termina em Ollama local (sem quota)", () => {
  const content = fs.readFileSync(SCRIPT, "utf8");
  // Reason: gpt-5.4-mini (OpenAI) esgotado gerava "quota exceeded" ao utilizador
  assert.doesNotMatch(content, /"model": "gpt-5\.4-mini"/);
  assert.match(content, /agl-primary-vm110/);
});

test("primario default GLM Coding Plan (zai-coding-glm-4.7)", () => {
  const content = fs.readFileSync(SCRIPT, "utf8");
  assert.match(content, /PRIMARY_MODEL="\$\{PRIMARY_MODEL:-zai-coding-glm-4\.7\}"/);
  assert.match(content, /m\["default"\] = primary/);
  assert.match(content, /jarvis curator elon satya werner orion/);
});

test("setup-hermes-curator-crons usa schedule 6h e modelo fora Z.AI", () => {
  const content = fs.readFileSync(CURATOR_CRON, "utf8");
  assert.match(content, /or-nemotron-super-free/);
  assert.match(content, /0 4,10,16,22 \* \* \*/);
  assert.match(content, /CURATOR_CRON_EXPR/);
});
