'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const SCRIPT = path.join(__dirname, '../../scripts/openclaw/replace-openrouter-gemini-free-fallback.py');
const WANT = 'zai/glm-4.7-flash';

test('replace-openrouter-gemini-free-fallback.py substitui google/... e openrouter/google/... :free', () => {
  const tmp = path.join(os.tmpdir(), `oc-gemini-free-${process.pid}.json`);
  fs.writeFileSync(
    tmp,
    JSON.stringify({
      x: 'google/gemini-2.5-flash-lite:free',
      y: ['openrouter/google/gemini-2.5-flash-lite:free', 'keep-me'],
      z: { m: 'openrouter/google/gemini-2.5-flash-lite:free' },
    }),
    'utf8',
  );

  const r = spawnSync('python3', [SCRIPT, tmp], { encoding: 'utf8' });
  assert.strictEqual(r.status, 0, r.stderr || r.stdout);

  const data = JSON.parse(fs.readFileSync(tmp, 'utf8'));
  assert.strictEqual(data.x, WANT);
  assert.deepStrictEqual(data.y, [WANT, 'keep-me']);
  assert.strictEqual(data.z.m, WANT);

  fs.unlinkSync(tmp);
});
