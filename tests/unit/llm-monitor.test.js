"use strict";

const { test } = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const ROOT = path.join(__dirname, "../..");
const CLI = path.join(ROOT, "scripts/agl/llm-monitor.sh");
const PLAN = path.join(ROOT, "ai-docs/planning/LLM-PROVIDER-MONITOR-PLAN.md");
const SKILL = path.join(ROOT, ".claude/skills/agl-llm-monitor/SKILL.md");
const EXAMPLE_STATE = path.join(
  ROOT,
  "config/monitoring/quota-governor-state.example.json",
);

function run(args, env = {}) {
  return execFileSync(CLI, args, {
    encoding: "utf8",
    env: { ...process.env, ...env },
  });
}

test("llm-monitor.sh existe e é executável", () => {
  assert.ok(fs.existsSync(CLI));
  assert.ok(fs.statSync(CLI).mode & 0o111);
});

test("plano e skill agl-llm-monitor existem", () => {
  assert.ok(fs.existsSync(PLAN));
  assert.ok(fs.existsSync(SKILL));
  const skill = fs.readFileSync(SKILL, "utf8");
  assert.match(skill, /llm-monitor\.sh/);
  assert.match(skill, /free-tier/);
  assert.match(skill, /contexto menor/i);
});

test("llm-monitor status com estado example emite bloco PROVIDER", () => {
  const out = run(["status"], {
    GOVERNOR_STATE_FILE: EXAMPLE_STATE,
  });
  assert.match(out, /^PROVIDER:/m);
  assert.match(out, /^STATUS:/m);
  assert.match(out, /^RECOMMEND:/m);
  assert.match(out, /^NEXT:/m);
});

test("llm-monitor status --json lê estado example", () => {
  const out = run(["status", "--json"], {
    GOVERNOR_STATE_FILE: EXAMPLE_STATE,
  });
  const parsed = JSON.parse(out.trim());
  assert.ok(parsed.action || parsed.timestamp);
});

test("llm-monitor why-blocked com estado example", () => {
  const out = run(["why-blocked"], {
    GOVERNOR_STATE_FILE: EXAMPLE_STATE,
  });
  assert.match(out, /ACTION:/);
  assert.match(out, /NEXT:/);
});

test("llm-monitor check provider desconhecido falha", () => {
  assert.throws(
    () => run(["check", "provider-inexistente-xyz"]),
    (err) => err.status === 2,
  );
});

test("configure-hermes-argus-ct188.sh existe e referencia argus", () => {
  const script = path.join(
    ROOT,
    "scripts/proxmox/configure-hermes-argus-ct188.sh",
  );
  assert.ok(fs.existsSync(script));
  const content = fs.readFileSync(script, "utf8");
  assert.match(content, /hermes-argus/);
  assert.match(content, /TELEGRAM_TOKEN_ARGUS/);
});
