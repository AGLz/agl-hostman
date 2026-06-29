"use strict";

const { test } = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.join(__dirname, "../..");
const SYNC = path.join(
  ROOT,
  "scripts/monitoring/hermes-makemoney-sync-crons.sh",
);
const SETUP = path.join(
  ROOT,
  "scripts/proxmox/setup-hermes-satya-makemoney-crons-ct188.sh",
);
const COMPOSE = path.join(
  ROOT,
  "docker/hermes/docker-compose.aglz-quartet.ct188.yml",
);

test("sync-crons lê outputs do Elon após migração Manager", () => {
  const s = fs.readFileSync(SYNC, "utf8");
  assert.match(s, /ELON_CRON_OUTPUT/);
  assert.match(
    s,
    /sync_job "\$\{JOB_RESEARCH\}" "research" "\$\{ELON_CRON_OUTPUT\}"/,
  );
  assert.match(
    s,
    /sync_job "\$\{JOB_IMPL\}" "impl-sprint" "\$\{ELON_CRON_OUTPUT\}"/,
  );
});

test("compose satya monta elon cron output read-only", () => {
  const s = fs.readFileSync(COMPOSE, "utf8");
  const satyaBlock = s.split("hermes-satya:")[1].split("hermes-werner:")[0];
  assert.match(satyaBlock, /elon-cron-output:ro/);
});

test("setup satya makemoney instala scripts e env", () => {
  const s = fs.readFileSync(SETUP, "utf8");
  assert.match(s, /hermes-makemoney-sync-crons\.sh/);
  assert.match(s, /MAKEMONEY_LLM_MODEL=agl-primary-zai-glm-flash/);
  assert.match(s, /ELON_CRON_OUTPUT/);
});
