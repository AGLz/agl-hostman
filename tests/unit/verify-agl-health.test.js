"use strict";

const { test } = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const REPO = path.join(__dirname, "../..");
const TARGETS = path.join(REPO, "config/monitoring/agl-health-targets.json");
const SCRIPT = path.join(REPO, "scripts/infra/verify-agl-health.sh");

test("agl-health-targets.json é JSON válido com secções obrigatórias", () => {
  const cfg = JSON.parse(fs.readFileSync(TARGETS, "utf8"));
  assert.ok(cfg.hosts?.aglsrv1?.tailscale);
  assert.ok(cfg.litellm?.readiness_primary);
  assert.ok(cfg.ollama?.vm110?.tailscale_api);
  assert.ok(cfg.ollama?.vm310?.tailscale_gpu0);
  assert.ok(Array.isArray(cfg.services));
});

test("verify-agl-health.sh dry-run lista checks sem rede", () => {
  assert.ok(fs.existsSync(SCRIPT));
  const out = execFileSync("bash", [SCRIPT, "--dry-run", "--quick"], {
    cwd: REPO,
    encoding: "utf8",
    env: { ...process.env, VERIFY_AGL_DRY_RUN: "1" },
  });
  assert.match(out, /host-aglsrv1/);
  assert.match(out, /litellm-readiness/);
  assert.match(out, /vm110-ollama/);
  assert.match(out, /vm310-ollama-gpu0/);
});

test("verify-agl-health.sh --json dry-run emite summary", () => {
  const out = execFileSync("bash", [SCRIPT, "--dry-run", "--quick", "--json"], {
    cwd: REPO,
    encoding: "utf8",
  });
  const lines = out.trim().split("\n");
  const jsonLine = lines[lines.length - 1];
  const payload = JSON.parse(jsonLine);
  assert.ok(payload.summary);
  assert.ok(Array.isArray(payload.checks));
  assert.ok(payload.checks.length >= 5);
});
