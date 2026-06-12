import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';
import assert from 'node:assert/strict';

const root = process.cwd();

const required = [
  'scripts/proxmox/pct-create-agl-obsidian.sh',
  'scripts/proxmox/bootstrap-ct193-obsidian.sh',
  'scripts/obsidian/install-obsidian-hub.sh',
  'scripts/obsidian/bridge-llm-wiki-git.sh',
  'scripts/obsidian/verify-obsidian-ct.sh',
  'scripts/obsidian/setup-github-gh.sh',
  'scripts/obsidian/propagate-gh-auth-to-ct193.sh',
  'docker/obsidian/docker-compose.couchdb.yml',
  'docker/obsidian/.env.example',
  'config/systemd/obsidian-hub.service',
  'config/systemd/agl-llm-wiki-bridge.service',
  'config/systemd/agl-llm-wiki-bridge-pull.service',
  'config/systemd/agl-llm-wiki-bridge.timer',
  'docs/OBSIDIAN-CT-AGL.md',
];

for (const rel of required) {
  test(`obsidian CT artefact exists: ${rel}`, () => {
    assert.ok(existsSync(join(root, rel)), `missing ${rel}`);
  });
}

test('bridge script exposes pull push watch', async () => {
  const { readFile } = await import('node:fs/promises');
  const content = await readFile(join(root, 'scripts/obsidian/bridge-llm-wiki-git.sh'), 'utf8');
  assert.match(content, /cmd_pull/);
  assert.match(content, /cmd_push/);
  assert.match(content, /cmd_watch/);
  assert.match(content, /ensure_github_auth/);
});

test('setup-github-gh uses gh auth setup-git', async () => {
  const { readFile } = await import('node:fs/promises');
  const content = await readFile(join(root, 'scripts/obsidian/setup-github-gh.sh'), 'utf8');
  assert.match(content, /gh auth setup-git/);
  assert.match(content, /https:\/\/github\.com/);
});
