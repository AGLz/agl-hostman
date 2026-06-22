"use strict";

const { test } = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const ROOT = path.join(__dirname, "../..");
const DISPATCH = path.join(ROOT, "scripts/agl/harness-dispatch.sh");

function runDispatch(args, env = {}) {
  return execFileSync(DISPATCH, args, {
    encoding: "utf8",
    env: { ...process.env, ...env },
  });
}

test("harness-dispatch.sh existe e é executável", () => {
  assert.ok(fs.existsSync(DISPATCH));
  assert.ok(fs.statSync(DISPATCH).mode & 0o111);
});

test("harness-dispatch --dry-run claude-code max-direct emite bloco HARNESS", () => {
  const out = runDispatch([
    "--dry-run",
    "--harness",
    "claude-code",
    "--auth",
    "max-direct",
    "--task",
    "smoke test",
    "--skip-probe",
  ]);
  assert.match(out, /HARNESS: claude-code/);
  assert.match(out, /AUTH: max-direct/);
  assert.match(out, /SKILL: agl-claude-code-agent/);
  assert.match(out, /claude -p/);
});

test("harness-dispatch --json cursor cursor-pro", () => {
  const out = runDispatch([
    "--dry-run",
    "--json",
    "--harness",
    "cursor",
    "--auth",
    "cursor-pro",
    "--task",
    "UI fix",
    "--skip-probe",
  ]);
  const parsed = JSON.parse(out.trim());
  assert.equal(parsed.harness, "cursor");
  assert.equal(parsed.auth, "cursor-pro");
  assert.equal(parsed.skill, "agl-cursor-agent");
  assert.match(parsed.next, /Cursor/);
});

test("harness-dispatch --print-env litellm-free", () => {
  const out = runDispatch([
    "--print-env",
    "--auth",
    "free",
    "--harness",
    "claude-code",
  ]);
  assert.match(out, /ENV_FILE=.*litellm-free/);
  assert.match(out, /LITELLM_GATEWAY_URL/);
});

test("harness-dispatch aliases auth direct e harness claude", () => {
  const out = runDispatch([
    "--dry-run",
    "--harness",
    "claude",
    "--auth",
    "direct",
    "--task",
    "x",
    "--skip-probe",
  ]);
  assert.match(out, /AUTH: max-direct/);
});

test("harness-dispatch --json escapa task com aspas", () => {
  const out = runDispatch([
    "--dry-run",
    "--json",
    "--harness",
    "claude-code",
    "--auth",
    "max-direct",
    "--task",
    'fix "auth" bug',
    "--skip-probe",
  ]);
  const parsed = JSON.parse(out.trim());
  assert.equal(parsed.harness, "claude-code");
  assert.match(parsed.next, /auth/);
});

test("harness-dispatch --dry-run ruflo e verdent", () => {
  const ruflo = runDispatch([
    "--dry-run",
    "--harness",
    "ruflo",
    "--auth",
    "litellm",
    "--task",
    "swarm task",
    "--skip-probe",
  ]);
  assert.match(ruflo, /HARNESS: ruflo/);
  assert.match(ruflo, /(ruflo hive-mind|npx ruflo@latest hive-mind)/);

  const verdent = runDispatch([
    "--dry-run",
    "--harness",
    "verdent",
    "--auth",
    "litellm",
    "--task",
    "parallel",
    "--skip-probe",
  ]);
  assert.match(verdent, /HARNESS: verdent/);
  assert.match(verdent, /Verdent/);
});

test("harness-dispatch rejeita harness e auth inválidos", () => {
  assert.throws(
    () =>
      runDispatch([
        "--dry-run",
        "--harness",
        "invalid",
        "--auth",
        "max-direct",
        "--task",
        "x",
        "--skip-probe",
      ]),
    (err) => err.status !== 0,
  );
  assert.throws(
    () =>
      runDispatch([
        "--dry-run",
        "--harness",
        "claude-code",
        "--auth",
        "bad-auth",
        "--task",
        "x",
        "--skip-probe",
      ]),
    (err) => err.status !== 0,
  );
});

test("harness-dispatch rejeita HARNESS_CONFIG_DIR fora do repo", () => {
  assert.throws(
    () =>
      runDispatch(
        ["--print-env", "--auth", "max-direct", "--harness", "claude-code"],
        { HARNESS_CONFIG_DIR: "/tmp" },
      ),
    (err) => err.status !== 0,
  );
});

test("harness-dispatch falha sem --task quando não dry-run", () => {
  assert.throws(
    () =>
      runDispatch([
        "--harness",
        "claude-code",
        "--auth",
        "max-direct",
        "--skip-probe",
      ]),
    (err) => err.status !== 0,
  );
});
