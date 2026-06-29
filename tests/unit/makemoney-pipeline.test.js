"use strict";

const { test } = require("node:test");
const assert = require("node:assert");
const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "../..");
const MAKEMONEY = path.join(ROOT, "../makemoney01");
const PARSE = path.join(MAKEMONEY, "scripts/parse_cron_output.py");

const SAMPLE = `# Cron Job: test

## Response

**Pesquisa diária**

1. **Gestão Financeira PMEs**
   - Problema: Fluxo de caixa manual
   - Cliente: PMEs
   - Monetização: R$ 99/mês
   - Stack: Python + LLM
   - MVP: 2 semanas | Risco: Baixo

**Prioridade do dia:**
Validar com 5 gestores.
`;

test("parse_cron_output extrai response e ignora SILENT", () => {
  assert.ok(fs.existsSync(PARSE), "parse_cron_output.py");
  const tmp = path.join(MAKEMONEY, "data/cron-sync/test-sample.md");
  fs.mkdirSync(path.dirname(tmp), { recursive: true });
  fs.writeFileSync(tmp, SAMPLE);
  const out = execSync(`python3 "${PARSE}" "${tmp}"`, { encoding: "utf8" });
  assert.ok(out.includes("Gestão Financeira PMEs"));
  assert.ok(out.includes("Prioridade do dia"));
  fs.writeFileSync(tmp, "## Response\n\n[SILENT]\n");
  const silent = execSync(`python3 "${PARSE}" "${tmp}"`, { encoding: "utf8" }).trim();
  assert.strictEqual(silent, "SILENT");
});

test("makemoney01 README e pipeline existem", () => {
  assert.ok(fs.existsSync(path.join(MAKEMONEY, "README.md")));
  assert.ok(fs.existsSync(path.join(MAKEMONEY, "data/pipeline/board.json")));
});

test("hermes-makemoney-git-sync.sh existe", () => {
  const gitSync = path.join(ROOT, "scripts/monitoring/hermes-makemoney-git-sync.sh");
  assert.ok(fs.existsSync(gitSync));
  const stat = fs.statSync(gitSync);
  assert.ok((stat.mode & 0o111) !== 0, "executável");
});
