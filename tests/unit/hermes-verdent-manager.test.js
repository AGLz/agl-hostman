"use strict";

const { test } = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.join(__dirname, "../..");
const P = (...p) => path.join(ROOT, ...p);
const read = (...p) => fs.readFileSync(P(...p), "utf8");

const JARVIS = "docker/hermes/profiles/jarvis/SOUL.md";
const VERIFIER = "docker/hermes/profiles/verifier/SOUL.md";
const SECOND_BRAIN = "docker/hermes/profiles/SECOND-BRAIN.md";
const COMPOSE = "docker/hermes/docker-compose.aglz-quartet.ct188.yml";
const RQ = "scripts/proxmox/hermes-review-queue.sh";
const MIGRATE = "scripts/proxmox/migrate-hermes-jarvis-crons-ct188.sh";
const STANDUP = "scripts/proxmox/setup-hermes-jarvis-standup-cron-ct188.sh";
const BOOTSTRAP = "scripts/proxmox/bootstrap-hermes-verifier-profile-ct188.sh";

test("Jarvis SOUL codifica modelo Manager (Plan->Execute->Verify, delega nao executa)", () => {
  const s = read(JARVIS);
  assert.match(s, /Manager/);
  assert.match(s, /Plan\s*→\s*Execute\s*→\s*Verify/);
  assert.match(s, /acceptance criteria/i);
  assert.match(s, /read_agent_context/);
  assert.match(s, /Verifier/);
  assert.match(s, /review-queue/i);
  assert.match(s, /gestor, n[aã]o executor/i);
});

test("Verifier SOUL existe como gate PASS/FAIL", () => {
  const s = read(VERIFIER);
  assert.match(s, /Verifier/);
  assert.match(s, /PASS/);
  assert.match(s, /FAIL/);
  assert.match(s, /acceptance criteria/i);
  assert.match(s, /review-queue/i);
});

test("Verifier nao implementa correcoes (so verifica)", () => {
  const s = read(VERIFIER);
  assert.match(s, /N[aã]o fazes:.*implementar/i);
});

test("SECOND-BRAIN tem papel Verifier e seccao Review-Queue", () => {
  const s = read(SECOND_BRAIN);
  assert.match(s, /\*\*Verifier\*\*/);
  assert.match(s, /Review-Queue/);
  assert.match(s, /to_review/);
  assert.match(s, /verifier_verdict/);
  assert.match(s, /llm-wiki\/raw\/hermes\/review-queue\/queue\.json/);
});

test("compose define servico hermes-verifier", () => {
  const s = read(COMPOSE);
  assert.match(s, /hermes-verifier:/);
  assert.match(s, /agl-hermes-verifier/);
  assert.match(s, /VERIFIER_DATA_DIR/);
});

test("review-queue helper suporta add/set-status/verdict/list", () => {
  const s = read(RQ);
  for (const a of ["add", "set-status", "verdict", "list"]) {
    assert.match(s, new RegExp(`action == "${a}"`));
  }
  assert.match(s, /VALID = \{[^}]*to_review[^}]*\}/);
});

test("migracao mapeia crons executor para Werner/Elon/Satya e corrige scripts partidos", () => {
  const s = read(MIGRATE);
  assert.match(s, /"hermes-ct188-daily-maintenance": "werner"/);
  assert.match(s, /"hermes-ct188-health-check": "werner"/);
  assert.match(s, /"AI Opportunity Research — scan expandido": "elon"/);
  assert.match(s, /"makemoney-git-sync": "satya"/);
  assert.match(s, /SCRIPT_FIX = \{/);
  assert.match(s, /hermes-makemoney-sync-crons-fixed\.sh": "hermes-makemoney-sync-crons\.sh"/);
  assert.match(s, /makemoney-pipeline-report-wrapper\.sh": "hermes-makemoney-pipeline-report\.sh"/);
  assert.match(s, /DRY_RUN/);
});

test("migracao NAO move emails nem briefing (mantem em Jarvis)", () => {
  const s = read(MIGRATE);
  assert.doesNotMatch(s, /"email-manha-analise":/);
  assert.doesNotMatch(s, /"hermes-ct188-daily-briefing":/);
});

test("stand-up cron usa cadencia 2h por defeito e usa read_agent_context", () => {
  const s = read(STANDUP);
  assert.match(s, /STANDUP_SCHEDULE:-0 \*\/2 \* \* \*/);
  assert.match(s, /read_agent_context/);
  assert.match(s, /jarvis-standup-2h/);
  assert.match(s, /hermes-review-queue\.sh list/);
});

test("bootstrap Verifier usa models free e review-queue", () => {
  const s = read(BOOTSTRAP);
  assert.match(s, /VERIFIER_MODEL:-or-nemotron-ultra-free/);
  assert.match(s, /or-owl-alpha/);
  assert.match(s, /llm-wiki\/raw\/hermes\/review-queue/);
});
