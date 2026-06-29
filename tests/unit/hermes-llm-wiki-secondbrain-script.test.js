"use strict";

const { test } = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.join(__dirname, "../..");
const SCRIPT = path.join(
  ROOT,
  "scripts/proxmox/fix-hermes-llm-wiki-secondbrain-ct188.sh",
);
const PROTOCOL = path.join(ROOT, "docker/hermes/profiles/SECOND-BRAIN.md");

test("fix-hermes-llm-wiki-secondbrain-ct188.sh existe e cobre os 7 agentes", () => {
  assert.ok(fs.existsSync(SCRIPT));
  assert.ok(fs.statSync(SCRIPT).mode & 0o111);
  const content = fs.readFileSync(SCRIPT, "utf8");
  for (const agent of [
    "jarvis",
    "elon",
    "satya",
    "werner",
    "curator",
    "orion",
    "argus",
  ]) {
    assert.match(content, new RegExp(agent));
  }
  assert.match(content, /WIKI_PATH/);
  assert.match(content, /wiki-ingest/);
  assert.match(content, /raw\/hermes/);
});

test("SECOND-BRAIN.md define fluxo bidireccional query + ingest", () => {
  assert.ok(fs.existsSync(PROTOCOL));
  const content = fs.readFileSync(PROTOCOL, "utf8");
  assert.match(content, /index\.md/);
  assert.match(content, /log\.md/);
  assert.match(content, /bidireccional|todos os agentes/i);
});
