"use strict";

const { test } = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const ROOT = path.join(__dirname, "../..");
const DISPATCH = path.join(ROOT, "scripts/agl/agent-os-ruflo-dispatch.sh");
const HOOK = path.join(ROOT, "scripts/agl/agent-os-post-task-hook.sh");
const PARSER = path.join(ROOT, "scripts/agl/lib/parse-agent-os-tasks.py");
const TASKS = path.join(
  ROOT,
  "agent-os/specs/infrastructure/wireguard-peer-setup/tasks.md",
);

function run(script, args) {
  return execFileSync(script, args, { encoding: "utf8", cwd: ROOT });
}

test("parse-agent-os-tasks extrai fases wireguard", () => {
  const out = execFileSync("python3", [PARSER, TASKS], { encoding: "utf8" });
  const parsed = JSON.parse(out);
  assert.ok(parsed.summary.groups >= 5);
  assert.ok(
    parsed.task_groups.some((g) => g.name === "pre-deployment-validation"),
  );
  assert.equal(typeof parsed.task_groups[0].ruflo_worker, "string");
});

test("agent-os-ruflo-dispatch --json wireguard", () => {
  const out = run(DISPATCH, [
    "--spec",
    "infrastructure/wireguard-peer-setup",
    "--json",
    "--dry-run",
  ]);
  const parsed = JSON.parse(out);
  assert.equal(parsed.spec, "wireguard-peer-setup");
  assert.ok(parsed.ruflo_task.includes("wireguard-peer-setup"));
  assert.ok(parsed.task_groups.length >= 5);
});

test("agent-os-ruflo-dispatch --dry-run emite PLAN", () => {
  const out = run(DISPATCH, [
    "--spec",
    "infrastructure/wireguard-peer-setup",
    "--dry-run",
  ]);
  assert.match(out, /SPEC: wireguard-peer-setup/);
  assert.match(out, /RUflo_TASK:/);
  assert.match(out, /harness-dispatch/);
});

test("agent-os-post-task-hook falha se grupo tem tarefas abertas", () => {
  assert.throws(
    () =>
      run(HOOK, [
        "--spec",
        "infrastructure/wireguard-peer-setup",
        "--group",
        "pre-deployment-validation",
        "--dry-run",
      ]),
    (err) => err.status !== 0,
  );
});

test("scripts Fase 4 são executáveis", () => {
  for (const f of [
    DISPATCH,
    HOOK,
    path.join(ROOT, "scripts/agl/smoke-harness-agent-os.sh"),
  ]) {
    assert.ok(fs.existsSync(f));
    assert.ok(fs.statSync(f).mode & 0o111, f);
  }
});
