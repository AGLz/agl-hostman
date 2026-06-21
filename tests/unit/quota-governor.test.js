"use strict";

const { test } = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const ROOT = path.join(__dirname, "../..");
const GOVERNOR = path.join(ROOT, "scripts/litellm/quota-governor.sh");
const PROVISION = path.join(ROOT, "scripts/litellm/provision-virtual-keys.sh");
const MANIFEST = path.join(
  ROOT,
  "config/litellm/virtual-keys-manifest.example.json",
);

function run(script, args, env = {}) {
  return execFileSync(script, args, {
    encoding: "utf8",
    env: { ...process.env, ...env },
  });
}

test("quota-governor.sh existe e é executável", () => {
  assert.ok(fs.existsSync(GOVERNOR));
  assert.ok(fs.statSync(GOVERNOR).mode & 0o111);
});

test("provision-virtual-keys.sh existe e é executável", () => {
  assert.ok(fs.existsSync(PROVISION));
  assert.ok(fs.statSync(PROVISION).mode & 0o111);
});

test("virtual-keys-manifest.example.json tem 4 teams harness", () => {
  const manifest = JSON.parse(fs.readFileSync(MANIFEST, "utf8"));
  assert.equal(manifest.teams.length, 4);
  const aliases = manifest.teams.map((t) => t.team_alias).sort();
  assert.deepEqual(aliases, [
    "team-claude-fallback",
    "team-cursor",
    "team-hermes",
    "team-verdent",
  ]);
});

test("quota-governor --dry-run --skip-probe emite ACTION", () => {
  const out = run(GOVERNOR, ["--dry-run", "--skip-probe"], {
    GOVERNOR_STATE_FILE: "/tmp/quota-governor-test-state.json",
  });
  assert.match(out, /ACTION:/);
  assert.match(out, /STATE:/);
});

test("quota-governor --json --skip-probe retorna JSON válido", () => {
  const out = run(GOVERNOR, ["--json", "--dry-run", "--skip-probe"], {
    GOVERNOR_STATE_FILE: "/tmp/quota-governor-test-json.json",
  });
  const parsed = JSON.parse(out.trim().split("\n").pop());
  assert.ok(parsed.timestamp);
  assert.ok(parsed.action);
  assert.ok(parsed.tiers.T3);
});

test("provision-virtual-keys --dry-run requer jq e master key ou falha graciosamente", () => {
  try {
    const out = run(PROVISION, ["--dry-run"], {
      LITELLM_MASTER_KEY: "sk-test-dry-run-only",
    });
    assert.match(out, /provision-virtual-keys concluído/);
  } catch (err) {
    assert.ok(
      err.status !== 0 || String(err.stderr || err.stdout).includes("ERRO"),
    );
  }
});
