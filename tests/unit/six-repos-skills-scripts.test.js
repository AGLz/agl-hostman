'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const ROOT = path.join(__dirname, '../..');
const SYNC = path.join(ROOT, 'scripts/skills/sync-six-repos.sh');
const VERIFY = path.join(ROOT, 'scripts/skills/verify-six-repos.sh');
const LLM_WIKI = process.env.LLM_WIKI_DIR || '/mnt/overpower/apps/dev/agl/llm-wiki';

test('sync-six-repos.sh existe, é executável e aceita --dry-run', () => {
  assert.ok(fs.existsSync(SYNC));
  assert.ok(fs.statSync(SYNC).mode & 0o111);
  const out = execFileSync(SYNC, ['--dry-run', '--repo', 'obsidian'], { encoding: 'utf8' });
  assert.match(out, /obsidian-cli/);
  assert.match(out, /dry-run/);
});

test('sync-six-repos.sh --repo ecc --dry-run menciona perfil minimal', () => {
  const out = execFileSync(SYNC, ['--dry-run', '--repo', 'ecc', '--harness', 'claude,codex,hostman'], {
    encoding: 'utf8',
  });
  assert.match(out, /everything-claude-code|ECC/);
  assert.match(out, /minimal/);
  assert.match(out, /dry-run/);
});

test('sync-six-repos.sh --repo open-design --dry-run menciona od- prefix', () => {
  const out = execFileSync(SYNC, ['--dry-run', '--repo', 'open-design'], { encoding: 'utf8' });
  assert.match(out, /open-design/);
  assert.match(out, /od-design-md|od-/);
});

test('propagate-six-repos.sh --host all --dry-run lista hosts', () => {
  const propagate = path.join(ROOT, 'scripts/skills/propagate-six-repos.sh');
  assert.ok(fs.existsSync(propagate));
  const out = execFileSync(propagate, ['--dry-run', '--host', 'all'], { encoding: 'utf8' });
  assert.match(out, /agldv03/);
  assert.match(out, /ct188/);
  assert.match(out, /aglwk45/);
  assert.match(out, /dry-run/);
});

test('verify-six-repos.sh passa após sync obsidian (obsidian-cli skill paths)', () => {
  assert.ok(fs.existsSync(VERIFY));
  assert.ok(fs.statSync(VERIFY).mode & 0o111);
  const obsidianSkill = path.join(LLM_WIKI, '.claude/skills/obsidian-cli/SKILL.md');
  if (!fs.existsSync(obsidianSkill)) {
    execFileSync(SYNC, ['--repo', 'obsidian'], { stdio: 'pipe' });
  }
  const out = execFileSync(VERIFY, [], {
    encoding: 'utf8',
    env: { ...process.env, LLM_WIKI_DIR: LLM_WIKI },
  });
  assert.match(out, /obsidian-cli \(llm-wiki\).*OK/s);
  assert.match(out, /FAIL=0/);
});
