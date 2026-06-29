"use strict";

const { test } = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.join(__dirname, "../..");
const SCRIPT = path.join(ROOT, "scripts/proxmox/hermes-openrouter-free-ct188.sh");
const CONFIG = path.join(ROOT, "config/litellm/config.yaml");

// Modelos free que LOGAM prompts (stealth/feedback). Não devem ser o default.
const LOGGING = [/or-owl-alpha/, /or-nemotron-ultra-free/, /or-nemotron-super-free/];

test("hermes-openrouter-free usa no-logging por default e reparte criticos vs restantes", () => {
  assert.ok(fs.existsSync(SCRIPT));
  const content = fs.readFileSync(SCRIPT, "utf8");
  assert.match(content, /CRITICAL_AGENTS=\(jarvis curator\)/);
  assert.match(content, /OTHER_AGENTS=\(elon satya werner orion\)/);
  // primários no-logging
  assert.match(content, /CRIT_PRIMARY="or-qwen3-coder-free"/);
  assert.match(content, /OTHER_PRIMARY="or-qwen3-next-free"/);
  // fallback final agl-sensitive (ZDR cloud enquanto VMs GPU suspensas)
  assert.match(content, /agl-sensitive/);
});

test("ramo no-logging (default) NAO usa owl-alpha/nemotron", () => {
  const content = fs.readFileSync(SCRIPT, "utf8");
  // isolar o bloco else (no-logging) do if HERMES_USE_LOGGING_FREE
  const elseBlock = content.split("else")[1]?.split("fi")[0] ?? "";
  assert.ok(elseBlock.length > 0, "bloco no-logging ausente");
  for (const re of LOGGING) {
    assert.doesNotMatch(elseBlock, re, `modelo logging no ramo no-logging: ${re}`);
  }
});

test("modelos que logam só via opt-in HERMES_USE_LOGGING_FREE (tarefas públicas)", () => {
  const content = fs.readFileSync(SCRIPT, "utf8");
  assert.match(content, /HERMES_USE_LOGGING_FREE/);
  // os aliases logging vivem no ramo do opt-in
  const ifBlock = content.split('HERMES_USE_LOGGING_FREE:-0}" == "1"')[1]?.split("else")[0] ?? "";
  assert.match(ifBlock, /or-owl-alpha/);
  assert.match(ifBlock, /or-nemotron-ultra-free/);
});

test("config define no-logging free aliases com data_collection=deny", () => {
  const content = fs.readFileSync(CONFIG, "utf8");
  for (const alias of [
    "or-qwen3-coder-free",
    "or-qwen3-next-free",
    "or-hermes-free",
    "or-llama-3.3-70b-free",
  ]) {
    assert.match(content, new RegExp(`model_name: ${alias.replace(/\./g, "\\.")}`), `alias ${alias} ausente`);
  }
  // pelo menos 3 ocorrências de data_collection: deny (aliases no-logging)
  const denies = content.match(/data_collection: deny/g) || [];
  assert.ok(denies.length >= 4, `esperado >=4 data_collection: deny, obtido ${denies.length}`);
});

test("fallbacks dos no-logging free nunca encadeiam owl-alpha/nemotron", () => {
  const content = fs.readFileSync(CONFIG, "utf8");
  for (const alias of ["or-qwen3-coder-free", "or-qwen3-next-free", "or-hermes-free", "or-llama-3.3-70b-free"]) {
    const block = content.split(`- ${alias}:\n`)[1]?.split(/\n    - [a-z]/)[0] ?? "";
    assert.ok(block.length > 0, `fallback ${alias} ausente`);
    for (const re of LOGGING) {
      assert.doesNotMatch(block, re, `${alias} encadeia modelo logging: ${re}`);
    }
    assert.match(block, /agl-sensitive/, `${alias} sem fallback agl-sensitive final`);
  }
});
