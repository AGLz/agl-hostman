"use strict";

const { test } = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.join(__dirname, "../..");
const SCRIPT = path.join(ROOT, "scripts/proxmox/hermes-openrouter-free-ct188.sh");
const CONFIG = path.join(ROOT, "config/litellm/config.yaml");

test("hermes-openrouter-free-ct188.sh existe e reparte criticos vs restantes", () => {
  assert.ok(fs.existsSync(SCRIPT));
  const content = fs.readFileSync(SCRIPT, "utf8");
  assert.match(content, /CRITICAL_AGENTS=\(jarvis curator\)/);
  assert.match(content, /OTHER_AGENTS=\(elon satya werner orion\)/);
  assert.match(content, /or-nemotron-ultra-free/);
  assert.match(content, /or-owl-alpha/);
  assert.match(content, /groq-llama-31-8b/);
  assert.match(content, /agl-primary-vm110/);
});

test("config.yaml define aliases or-nemotron-ultra-free e or-owl-alpha", () => {
  const content = fs.readFileSync(CONFIG, "utf8");
  assert.match(content, /model_name: or-nemotron-ultra-free/);
  assert.match(content, /model: openrouter\/nvidia\/nemotron-3-ultra-550b-a55b:free/);
  assert.match(content, /model_name: or-owl-alpha/);
  assert.match(content, /model: openrouter\/openrouter\/owl-alpha/);
});

test("fallbacks or-nemotron-ultra-free e or-owl-alpha nao usam paid", () => {
  const content = fs.readFileSync(CONFIG, "utf8");
  for (const alias of ["or-nemotron-ultra-free", "or-owl-alpha"]) {
    const block = content.split(`- ${alias}:\n`)[1]?.split(/\n    - /)[0] ?? "";
    assert.ok(block.length > 0, `bloco fallbacks ${alias} ausente`);
    assert.doesNotMatch(block, /or-nemotron-super[^-]/);
    assert.doesNotMatch(block, /or-minimax-m2\.5[^-]/);
    assert.doesNotMatch(block, /or-gpt-4o-mini/);
  }
});
