"use strict";

const { test } = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.join(__dirname, "../..");
const P = (...p) => path.join(ROOT, ...p);
const read = (...p) => fs.readFileSync(P(...p), "utf8");

const SOUL = "docker/hermes/profiles/composio/SOUL.md";
const COMPOSE = "docker/hermes/docker-compose.aglz-quartet.ct188.yml";
const BOOTSTRAP = "scripts/proxmox/bootstrap-hermes-composio-profile-ct188.sh";
const CONFIGURE = "scripts/proxmox/configure-hermes-composio-ct188.sh";
const JARVIS = "docker/hermes/profiles/jarvis/SOUL.md";
const DOCS = "docs/HERMES-AGENCY-AGENTS.md";

test("Composio SOUL define missão integrations + Composio MCP", () => {
  const s = read(SOUL);
  assert.match(s, /Composio/);
  assert.match(s, /Composio MCP/);
  assert.match(s, /or-qwen3-next-free/);
  assert.match(s, /no-logging/i);
});

test("compose define hermes-composio com contentor agl-hermes-composio", () => {
  const s = read(COMPOSE);
  assert.match(s, /hermes-composio:/);
  assert.match(s, /agl-hermes-composio/);
  assert.match(s, /COMPOSIO_DATA_DIR/);
});

test("bootstrap composio cria config com mcp_servers.composio", () => {
  const s = read(BOOTSTRAP);
  assert.match(s, /connect\.composio\.dev/);
  assert.match(s, /enabled.*False/s);
});

test("configure composio integra bootstrap + secondbrain + compose up", () => {
  const s = read(CONFIGURE);
  assert.match(s, /bootstrap-hermes-composio-profile/);
  assert.match(s, /fix-hermes-llm-wiki-secondbrain/);
  assert.match(s, /hermes-composio/);
  assert.match(s, /TELEGRAM_TOKEN_COMPOSIO/);
});

test("Jarvis SOUL delega integrações SaaS ao Composio", () => {
  const s = read(JARVIS);
  assert.match(s, /\*\*Composio\*\*/);
});

test("docs HERMES-AGENCY listam composio no mapa", () => {
  const s = read(DOCS);
  assert.match(s, /`composio`/);
  assert.match(s, /hermes-composio/);
  assert.match(s, /nove perfis/);
});

test("secondbrain inclui composio no array AGENTS", () => {
  const s = read("scripts/proxmox/fix-hermes-llm-wiki-secondbrain-ct188.sh");
  assert.match(s, /AGENTS=\(.*composio.*\)/);
  assert.match(s, /verifier/);
});
