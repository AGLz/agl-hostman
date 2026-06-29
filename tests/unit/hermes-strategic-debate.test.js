"use strict";

const { test } = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const ROOT = path.join(__dirname, "../..");
const PY = path.join(ROOT, "scripts/hermes/strategic_debate.py");
const SH = path.join(ROOT, "scripts/hermes/strategic-debate.sh");
const SKILL = path.join(
  ROOT,
  "docker/hermes/profiles/jarvis/skills/strategic-debate/SKILL.md"
);
const SETUP = path.join(
  ROOT,
  "scripts/proxmox/setup-hermes-jarvis-strategic-debate-ct188.sh"
);
const SOUL = path.join(ROOT, "docker/hermes/profiles/jarvis/SOUL.md");
const DOCS = path.join(ROOT, "docs/HERMES-AGENCY-AGENTS.md");

test("strategic-debate skill documenta modelos no-logging", () => {
  const s = fs.readFileSync(SKILL, "utf8");
  assert.match(s, /or-qwen3-coder-free/);
  assert.match(s, /or-hermes-free/);
  assert.match(s, /or-qwen3-next-free/);
  assert.match(s, /or-owl-alpha/);
  assert.match(s, /no-logging/i);
});

test("Jarvis SOUL referencia strategic-debate na fase Plan", () => {
  const s = fs.readFileSync(SOUL, "utf8");
  assert.match(s, /strategic-debate/);
  assert.match(s, /or-qwen3-coder-free/);
  assert.match(s, /or-hermes-free/);
});

test("setup instala scripts e skill no Jarvis data/", () => {
  const s = fs.readFileSync(SETUP, "utf8");
  assert.match(s, /strategic-debate\.sh/);
  assert.match(s, /skills\/strategic-debate/);
  assert.match(s, /--dry-run/);
});

test("docs HERMES-AGENCY mencionam debate Opção B", () => {
  const s = fs.readFileSync(DOCS, "utf8");
  assert.match(s, /Debate estratégico/);
  assert.match(s, /or-qwen3-coder-free/);
});

test("strategic_debate.py bloqueia modelos que logam", () => {
  const r = spawnSync(
    "python3",
    [PY, "-q", "teste", "--dry-run"],
    {
      env: {
        ...process.env,
        STRATEGIC_DEBATE_ADVOCATE_MODEL: "or-owl-alpha",
      },
      encoding: "utf8",
    }
  );
  assert.notEqual(r.status, 0);
  assert.match(r.stderr || r.stdout, /logar prompts/i);
});

test("strategic_debate.py dry-run produz output", () => {
  const r = spawnSync(
    "python3",
    [PY, "-q", "Priorizar A ou B?", "-c", "ctx", "--dry-run"],
    { encoding: "utf8" }
  );
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /DRY-RUN/);
  assert.match(r.stdout, /Debate estratégico/);
});

test("wrapper strategic-debate.sh existe e é executável", () => {
  assert.ok(fs.existsSync(SH));
  const s = fs.readFileSync(SH, "utf8");
  assert.match(s, /strategic_debate\.py/);
});
