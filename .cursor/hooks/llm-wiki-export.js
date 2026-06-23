#!/usr/bin/env node
/**
 * Exporta a sessão Cursor actual para llm-wiki (raw/cursor/live).
 * Invocado por session-end.js / stop.js — não bloqueia a IDE.
 */
const { spawn } = require("child_process");
const path = require("path");
const fs = require("fs");

const REPO = path.resolve(__dirname, "..", "..");
const SCRIPT = path.join(
  REPO,
  "scripts",
  "cursor",
  "export-cursor-sessions.py",
);
const LOG = path.join(REPO, ".cursor", "logs", "llm-wiki-export.log");

function log(line) {
  try {
    fs.mkdirSync(path.dirname(LOG), { recursive: true });
    fs.appendFileSync(LOG, `${new Date().toISOString()} ${line}\n`);
  } catch (_) {
    /* ignore */
  }
}

function runExport(transcriptPath) {
  if (!fs.existsSync(SCRIPT)) {
    return;
  }
  if (process.env.AGL_CURSOR_WIKI_SYNC === "0") {
    return;
  }
  const args = [SCRIPT, "--quiet"];
  if (transcriptPath) {
    args.push("--session", transcriptPath);
  }
  const child = spawn(process.env.PYTHON || "python3", args, {
    cwd: REPO,
    detached: true,
    stdio: "ignore",
    env: {
      ...process.env,
      LLM_WIKI_DIR:
        process.env.LLM_WIKI_DIR || "/mnt/overpower/apps/dev/agl/llm-wiki",
      AGL_HOME_SYNC_ROOT:
        process.env.AGL_HOME_SYNC_ROOT ||
        "/mnt/overpower/apps/dev/agl/agl-home-sync",
    },
  });
  child.unref();
  log(`spawn pid=${child.pid} session=${transcriptPath || "all"}`);
}

module.exports = { runExport };

if (require.main === module) {
  const transcriptPath = process.argv[2] || "";
  runExport(transcriptPath || undefined);
}
