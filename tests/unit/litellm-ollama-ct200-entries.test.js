"use strict";

const { test } = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const CONFIG = path.join(__dirname, "../../config/litellm/config.yaml");
const CONFIG_REMOTE = path.join(
  __dirname,
  "../../config/litellm/config-remote.yaml",
);

const VM310_TS_OLLAMA = "100.67.253.52:11434";
const VM110_TS_OLLAMA = "100.74.118.51:11434";
const LEGACY_CT200_LAN = "192.168.0.200:11434";
const LEGACY_VM110_TS = "100.116.57.111:11434";

function escapeForRegex(ipHost) {
  return ipHost.replaceAll(".", "\\.");
}

function assertNoOllamaCloudAliases(yaml, label) {
  assert.doesNotMatch(yaml, /ollama\/nemotron-3-nano/, label);
  assert.doesNotMatch(yaml, /ollama-nemotron-3-nano-4b/, label);
  assert.doesNotMatch(yaml, /:cloud/, label);
  assert.doesNotMatch(yaml, /ollama-glm-4\.7-cloud/, label);
  assert.doesNotMatch(yaml, /ollama-qwen3\.5-cloud/, label);
  assert.doesNotMatch(yaml, /ollama-deepseek-v3\.2-cloud/, label);
  assert.doesNotMatch(yaml, /ollama-gemma4-31b-cloud/, label);
  assert.doesNotMatch(yaml, /ollama-kimi-k2\.6-cloud/, label);
  assert.doesNotMatch(yaml, /ollama-minimax-m2\.7-cloud/, label);
  assert.doesNotMatch(yaml, /ollama-gpt-oss-20b-cloud/, label);
}

test("LiteLLM: agl-primary — Ollama local (VMs ativas) OU cloud ZDR (VMs suspensas)", () => {
  const yaml = fs.readFileSync(CONFIG, "utf8");
  // 2026-06-29: VMs GPU (VM310/VM110) suspensas → aliases redirecionados p/ cloud ZDR.
  const gpuSuspended = yaml.includes("VMs GPU Ollama SUSPENSAS");
  const vm110Failover = yaml.includes("VM110 Ollama");

  assertNoOllamaCloudAliases(yaml, "config.yaml");

  if (gpuSuspended) {
    // agl-primary aponta para cloud ZDR no-logging (data_collection=deny + zdr)
    assert.match(
      yaml,
      /model:\s*openrouter\/qwen\/qwen3-next-80b-a3b-instruct:free[\s\S]*?model_name:\s*agl-primary\b/,
      "config.yaml: agl-primary usa cloud ZDR (Qwen3 Next) enquanto GPU suspensa",
    );
    assert.match(yaml, /data_policy:\s*zdr-no-logging-cloud/, "config.yaml: política ZDR presente");
    // nenhum endpoint Ollama local ATIVO (api_base) — só menções em notas/comentários
    const active = yaml
      .split("\n")
      .filter((l) => !l.trimStart().startsWith("#") && !l.includes("note:"))
      .join("\n");
    assert.doesNotMatch(active, new RegExp(`api_base:\\s*http://${escapeForRegex(VM310_TS_OLLAMA)}`), "VM310 ainda ativa");
    assert.doesNotMatch(active, new RegExp(`api_base:\\s*http://${escapeForRegex(VM110_TS_OLLAMA)}`), "VM110 ainda ativa");
  } else if (vm110Failover) {
    assert.match(
      yaml,
      /model:\s*ollama\/qwen3:4b[\s\S]*?model_name:\s*agl-primary/,
      "config.yaml: agl-primary usa ollama/qwen3:4b VM110",
    );
    assert.match(yaml, new RegExp(escapeForRegex(VM110_TS_OLLAMA), "g"), "config.yaml: api_base Tailscale VM110");
  } else {
    assert.match(
      yaml,
      /model:\s*ollama\/gemma4-qat[\s\S]*?model_name:\s*agl-primary/,
      "config.yaml: agl-primary usa ollama/gemma4-qat VM310 GPU0",
    );
    assert.match(
      yaml,
      /model:\s*ollama\/qwen3:8b[\s\S]*?model_name:\s*agl-primary-strong/,
      "config.yaml: agl-primary-strong usa ollama/qwen3:8b VM310 GPU1",
    );
    assert.match(yaml, new RegExp(escapeForRegex(VM310_TS_OLLAMA), "g"), "config.yaml: api_base Tailscale VM310");
  }

  assert.doesNotMatch(
    yaml,
    new RegExp(escapeForRegex(LEGACY_CT200_LAN)),
    "config.yaml: não deve usar LAN CT200 legado",
  );
});

test("LiteLLM remote: agl-primary Groq e aliases ollama legados sem Ollama real", () => {
  const yaml = fs.readFileSync(CONFIG_REMOTE, "utf8");

  assertNoOllamaCloudAliases(yaml, "config-remote.yaml");
  assert.match(
    yaml,
    /model_name:\s*"agl-primary"[\s\S]*?model:\s*"groq\/llama-3\.1-8b-instant"/,
    "config-remote.yaml: agl-primary aponta para Groq (VM110 suspenso)",
  );
  assert.match(
    yaml,
    /model_name:\s*"ollama-qwen3-4b"[\s\S]*?model:\s*"groq\/llama-3\.1-8b-instant"/,
    "config-remote.yaml: alias legado ollama-qwen3-4b → Groq",
  );
  assert.doesNotMatch(
    yaml,
    /api_base:\s*"?http:\/\/100\.(74|86)\./,
    "config-remote.yaml: sem api_base Ollama Tailscale",
  );
});
