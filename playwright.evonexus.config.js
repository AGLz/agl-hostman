const { defineConfig, devices } = require('@playwright/test')

module.exports = defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  reporter: [['list']],
  timeout: 30000,
  expect: { timeout: 10000 },
  use: {
    baseURL: 'https://evo.aglz.io',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
})

