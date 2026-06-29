"use strict";

const { test } = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.join(__dirname, "../..");
const SCRIPT = path.join(ROOT, "scripts/proxmox/hermes-glm45-balance-ct188.sh");
const CONFIG = path.join(ROOT, "config/litellm/config.yaml");
const CALLBACK = path.join(ROOT, "config/litellm/custom_callbacks/agl_glm_flash_params.py");

test("hermes-glm45-balance-ct188.sh existe e cobre os 6 agentes", () => {
  assert.ok(fs.existsSync(SCRIPT));
  assert.ok(fs.statSync(SCRIPT).mode & 0o111);
  const content = fs.readFileSync(SCRIPT, "utf8");
  assert.match(content, /PRIMARY="glm-4\.5"/);
  assert.match(content, /AUX_MODEL="glm-air"/);
  assert.match(content, /jarvis elon satya werner curator orion/);
});

test("config.yaml define alias glm-4.5 na rota balance openai/v1", () => {
  const content = fs.readFileSync(CONFIG, "utf8");
  assert.match(content, /model_name: glm-4\.5/);
  assert.match(content, /model: openai\/glm-4\.5/);
  assert.match(content, /api_base: https:\/\/api\.z\.ai\/api\/openai\/v1/);
});

test("fallbacks glm-4.5 evitam zai-coding-glm-4.7 e glm-4.7-flash", () => {
  const content = fs.readFileSync(CONFIG, "utf8");
  const block = content.split("- glm-4.5:\n")[1]?.split(/\n    - /)[0] ?? "";
  assert.ok(block.length > 0, "bloco fallbacks glm-4.5 ausente");
  assert.doesNotMatch(block, /zai-coding-glm-4\.7/);
  assert.doesNotMatch(block, /glm-4\.7-flash/);
  assert.match(block, /or-nemotron-super-free/);
});

test("callback thinking inclui glm-4.5 e glm-air", () => {
  const content = fs.readFileSync(CALLBACK, "utf8");
  // Reason: no fonte Python o ponto esta escapado (glm-4\.5)
  assert.match(content, /glm-4\\.5/);
  assert.match(content, /glm-air/);
});
