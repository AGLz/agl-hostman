"use strict";

const { test } = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const ROOT = path.join(__dirname, "../..");
const EXPORT = path.join(ROOT, "scripts/cursor/export-cursor-sessions.py");
const SYNC = path.join(ROOT, "scripts/cursor/sync-cursor-to-wiki.sh");

test("export-cursor-sessions.py existe", () => {
  assert.ok(fs.existsSync(EXPORT));
});

test("export incremental gera markdown a partir de jsonl", () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "cursor-wiki-"));
  const wiki = path.join(tmp, "llm-wiki");
  const projects = path.join(
    tmp,
    "projects",
    "mnt-overpower-apps-dev-agl-agl-hostman",
    "agent-transcripts",
    "abc123",
  );
  fs.mkdirSync(projects, { recursive: true });
  const jsonl = path.join(projects, "abc123.jsonl");
  fs.writeFileSync(
    jsonl,
    JSON.stringify({
      role: "user",
      message: {
        content: [
          {
            type: "text",
            text: "<user_query>\nTeste Hermes CT188 llm-wiki\n</user_query>",
          },
        ],
      },
    }) + "\n",
  );

  const env = {
    ...process.env,
    HOME: tmp,
    LLM_WIKI_DIR: wiki,
    CURSOR_EXPORT_HOST: "testhost",
    CURSOR_EXPORT_ALL_HOSTS: "0",
    CURSOR_PROJECTS_DIRS: path.join(tmp, "projects"),
    AGL_HOME_SYNC_ROOT: path.join(tmp, "empty-sync"),
  };
  const out = execFileSync(
    "python3",
    [EXPORT, "--wiki", wiki, "--full", "--filter", "agl"],
    {
      encoding: "utf8",
      env,
    },
  );
  const result = JSON.parse(out);
  assert.equal(result.exported_agents, 1);
  const mdPath = path.join(
    wiki,
    "raw/cursor/live/agent-transcripts/testhost/mnt-overpower-apps-dev-agl-agl-hostman_abc123.md",
  );
  assert.ok(fs.existsSync(mdPath));
  const md = fs.readFileSync(mdPath, "utf8");
  assert.match(md, /Hermes CT188/);
  assert.ok(fs.existsSync(path.join(wiki, "raw/cursor/.export-state.json")));
});

test("export descobre múltiplos hosts em agl-home-sync", () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "cursor-wiki-mh-"));
  const wiki = path.join(tmp, "llm-wiki");
  const sync = path.join(tmp, "agl-home-sync");

  for (const host of ["agldv03", "agldv04"]) {
    const projects = path.join(
      sync,
      host,
      "cursor/dot-cursor/projects/proj/agent-transcripts/sess1",
    );
    fs.mkdirSync(projects, { recursive: true });
    fs.writeFileSync(
      path.join(projects, "sess1.jsonl"),
      JSON.stringify({
        role: "user",
        message: {
          content: [
            {
              type: "text",
              text: "<user_query>\nAGL hostman llm-wiki sync\n</user_query>",
            },
          ],
        },
      }) + "\n",
    );
  }

  const env = {
    ...process.env,
    HOME: path.join(tmp, "empty-home"),
    LLM_WIKI_DIR: wiki,
    AGL_HOME_SYNC_ROOT: sync,
    CURSOR_EXPORT_ALL_HOSTS: "1",
    CURSOR_EXPORT_HOST: "aggregator",
  };
  const out = execFileSync(
    "python3",
    [EXPORT, "--wiki", wiki, "--full", "--filter", "agl"],
    { encoding: "utf8", env },
  );
  const result = JSON.parse(out);
  assert.equal(result.exported_agents, 2);
  assert.ok(
    fs.existsSync(
      path.join(wiki, "raw/cursor/live/agent-transcripts/agldv03/proj_sess1.md"),
    ),
  );
  assert.ok(
    fs.existsSync(
      path.join(wiki, "raw/cursor/live/agent-transcripts/agldv04/proj_sess1.md"),
    ),
  );
});

test("propagate-cursor-wiki-sync.sh é executável", () => {
  const propagate = path.join(
    ROOT,
    "scripts/cursor/propagate-cursor-wiki-sync.sh",
  );
  assert.ok(fs.existsSync(propagate));
  assert.ok(fs.statSync(propagate).mode & 0o111);
});

test("sync-cursor-to-wiki.sh é executável", () => {
  assert.ok(fs.existsSync(SYNC));
  assert.ok(fs.statSync(SYNC).mode & 0o111);
});

test("llm-wiki-ingest skill e comando existem", () => {
  assert.ok(
    fs.existsSync(path.join(ROOT, ".cursor/skills/llm-wiki-ingest/SKILL.md")),
  );
  assert.ok(
    fs.existsSync(path.join(ROOT, ".cursor/commands/llm-wiki-ingest.md")),
  );
});

test("hook llm-wiki-export ligado ao session-end", () => {
  const sessionEnd = fs.readFileSync(
    path.join(ROOT, ".cursor/hooks/session-end.js"),
    "utf8",
  );
  assert.match(sessionEnd, /llm-wiki-export/);
});
