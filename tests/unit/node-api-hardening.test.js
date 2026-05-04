'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const PROXMOX_SERVICE = path.join(__dirname, '../../src/services/proxmox.js');
const AI_STACK_SERVICE = path.join(__dirname, '../../src/services/ai-stack.js');
const AI_ROUTES = path.join(__dirname, '../../src/api/routes/ai.js');

test('Proxmox service does not disable TLS verification globally', () => {
  const src = fs.readFileSync(PROXMOX_SERVICE, 'utf8');

  assert.doesNotMatch(src, /NODE_TLS_REJECT_UNAUTHORIZED\s*=\s*['"]0['"]/);
  assert.match(src, /rejectUnauthorized:\s*TLS_VERIFY/);
});

test('Node API uses installed Ruflo command instead of npx latest', () => {
  const aiStack = fs.readFileSync(AI_STACK_SERVICE, 'utf8');
  const aiRoutes = fs.readFileSync(AI_ROUTES, 'utf8');

  assert.doesNotMatch(aiStack, /npx\s+ruflo@latest/);
  assert.doesNotMatch(aiRoutes, /npx\s+ruflo@latest/);
  assert.match(aiStack, /RUFLO_COMMAND/);
  assert.match(aiRoutes, /RUFLO_COMMAND/);
});
