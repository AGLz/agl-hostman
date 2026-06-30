import { readFileSync } from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import test from "node:test";
import assert from "node:assert/strict";

const ROOT = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../..",
);
const INSTALL = path.join(ROOT, "scripts/skills/install-arsenal-war-skills.sh");
const SCAN = path.join(ROOT, "scripts/skills/scan-skill-security.sh");
const HERMES = path.join(
  ROOT,
  "scripts/proxmox/install-hermes-arsenal-skills-ct188.sh",
);
const INSTALL_SKILLSPECTOR = path.join(
  ROOT,
  "scripts/skills/install-skillspector.sh",
);

test("install-arsenal-war-skills referencia ponytail, improve e video-transcript", () => {
  const content = readFileSync(INSTALL, "utf8");
  assert.match(content, /DietrichGebert\/ponytail/);
  assert.match(content, /shadcn\/improve/);
  assert.match(content, /video-transcript-downloader/);
  assert.match(content, /drawio-skill/);
  assert.match(content, /agl-architecture-diagram/);
  assert.match(content, /--global-only/);
});

test("scan-skill-security usa skillspector ou docker fallback", () => {
  const content = readFileSync(SCAN, "utf8");
  assert.match(content, /skillspector/);
  assert.match(content, /docker/);
  assert.match(content, /--no-llm/);
});

test("install-hermes-arsenal liga skills nos profiles quartet+", () => {
  const content = readFileSync(HERMES, "utf8");
  for (const agent of [
    "jarvis",
    "elon",
    "satya",
    "werner",
    "curator",
    "orion",
  ]) {
    assert.match(content, new RegExp(agent));
  }
  assert.match(content, /video-transcript-downloader/);
  assert.match(content, /improve/);
  assert.match(content, /agl-video-analysis/);
  assert.match(content, /agl-architecture-diagram/);
  assert.match(content, /drawio-skill/);
  assert.match(content, /ponytail/);
});

test("youtube_002 documenta as 4 pérolas", () => {
  const md = readFileSync(
    path.join(ROOT, "projects/video-analises/youtube_002.md"),
    "utf8",
  );
  assert.match(md, /Ponytail/);
  assert.match(md, /Improve/);
  assert.match(md, /SkillSpector/);
  assert.match(md, /draw\.io/);
});

test("scripts passam bash -n", () => {
  for (const script of [INSTALL, SCAN, HERMES, INSTALL_SKILLSPECTOR]) {
    const { status, stderr } = spawnSync("bash", ["-n", script], {
      encoding: "utf8",
    });
    assert.strictEqual(status, 0, `${path.basename(script)}: ${stderr}`);
  }
});
