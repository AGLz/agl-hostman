#!/usr/bin/env node

/**
 * Test Runner Script
 * Works around pnpm Jest + write-file-atomic compatibility issues
 */

const { spawn } = require('child_process');
const path = require('path');

// Set environment variables for Jest
const env = {
  ...process.env,
  NODE_ENV: 'test',
  NODE_OPTIONS: '--max-old-space-size=4096',
  JEST_PUPPETEER_SKIP_DOWNLOAD: '1',
};

// Get Jest args
const args = process.argv.slice(2);

// Run jest using npx with proper isolation
const jestPath = path.join(__dirname, '../node_modules/.pnpm/jest-cli@29.7.0_@types+node@18.19.130/node_modules/jest-cli/bin/jest.js');

const child = spawn('node', [jestPath, ...args], {
  env,
  stdio: 'inherit',
  cwd: process.cwd(),
});

child.on('exit', (code) => {
  process.exit(code ?? 0);
});

child.on('error', (err) => {
  console.error('Failed to start Jest:', err);
  process.exit(1);
});
