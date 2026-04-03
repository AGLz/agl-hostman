'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const CONFIG = path.join(__dirname, '../../config/litellm/config.yaml');

test('LiteLLM: cursor-composer usa Z.AI GLM-4.7-Flash (anthropic/glm-4.7-flash)', () => {
  const yaml = fs.readFileSync(CONFIG, 'utf8');
  assert.match(yaml, /model_name:\s*"cursor-composer"/);
  assert.match(yaml, /model_name:\s*"cursor-composer-2-fast"/);
  const composerBlocks = [...yaml.matchAll(
    /model_name:\s*"cursor-composer(?:-2-fast)?"[\s\S]*?model:\s*"([^"]+)"/g,
  )];
  assert.ok(composerBlocks.length >= 2, 'esperado cursor-composer e cursor-composer-2-fast');
  for (const m of composerBlocks) {
    assert.strictEqual(m[1], 'anthropic/glm-4.7-flash');
  }
});
