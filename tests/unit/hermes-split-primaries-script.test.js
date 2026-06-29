"use strict";

const { test } = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.join(__dirname, "../..");
const SCRIPT = path.join(ROOT, "scripts/proxmox/hermes-split-primaries-ct188.sh");

test("hermes-split-primaries-ct188.sh existe e é executável", () => {
  assert.ok(fs.existsSync(SCRIPT));
  assert.ok(fs.statSync(SCRIPT).mode & 0o111);
});

test("reparte Z.AI (jarvis/curator) vs non-Z.AI (elon/satya/werner/orion)", () => {
  const content = fs.readFileSync(SCRIPT, "utf8");
  assert.match(content, /ZAI_AGENTS=\(jarvis curator\)/);
  assert.match(content, /NONZAI_AGENTS=\(elon satya werner orion\)/);
});

test("primários: Z.AI=zai-coding-glm-4.7 e restantes=or-nemotron-super-free", () => {
  const content = fs.readFileSync(SCRIPT, "utf8");
  assert.match(content, /"zai-coding-glm-4\.7" "or-nemotron-super-free"/);
  assert.match(content, /"or-nemotron-super-free" "or-minimax-m2\.5-free"/);
});

test("cadeias de fallback sem OpenAI, terminam em Ollama local", () => {
  const content = fs.readFileSync(SCRIPT, "utf8");
  // Reason: gpt-5.4-mini (OpenAI) esgotado gerava "quota exceeded"
  assert.doesNotMatch(content, /gpt-5\.4-mini/);
  assert.match(content, /agl-primary-vm110/);
  assert.match(content, /groq-llama-31-8b/);
});

test("fallback_providers herdam api_key do model (evita 401)", () => {
  const content = fs.readFileSync(SCRIPT, "utf8");
  assert.match(content, /entry\["api_key"\] = key/);
});
