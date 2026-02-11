/**
 * Direct Test Runner
 *
 * Bypasses pnpm/Jest compatibility issues with write-file-atomic
 * Run tests directly without cache
 */

const { execSync } = require('child_process');
const path = require('path');

const jestPath = path.join(
  __dirname,
  '../../node_modules/.pnpm/jest-cli@29.7.0_@types+node@18.19.130/node_modules/jest-cli/bin/jest.js'
);

// Set environment to bypass cache issues
process.env.JEST_CACHE = 'false';
process.env.JEST_USE_CACHE = 'false';

const args = process.argv.slice(2);
const defaultArgs = [
  '--no-cache',
  '--cacheDirectory=/tmp/jest-cache-direct',
  '--testPathIgnorePatterns=node_modules',
  '--coverage',
];

const allArgs = [...args, ...defaultArgs.filter(a => !args.includes(a))];
const command = `NODE_ENV=test node "${jestPath}" ${allArgs.join(' ')}`;

try {
  console.log(`Running: ${command}`);
  execSync(command, {
    stdio: 'inherit',
    cwd: path.join(__dirname, '..'),
    env: {
      ...process.env,
      NODE_ENV: 'test',
      JEST_CACHE: 'false',
    },
  });
} catch (error) {
  process.exit(error.status || 1);
}
