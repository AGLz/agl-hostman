const { defineConfig, devices } = require('@playwright/test')
const path = require('path')

// PLAYWRIGHT_BASE_URL — ex.: https://ah.aglz.io (tunnel → agl-hostman)
// PW_SKIP_WEBSERVER=1 — não arranca npm na raiz nem Vite em src/web (tests contra URL remota)
const customBase = process.env.PLAYWRIGHT_BASE_URL
const localhostLike =
  !customBase ||
  customBase.includes('localhost') ||
  customBase.includes('127.0.0.1')
const skipWebServer =
  process.env.PW_SKIP_WEBSERVER === '1' || (customBase && !localhostLike)

module.exports = defineConfig({
  testDir: path.join(__dirname, 'tests/e2e'),
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [['html', { open: 'never' }], ['list']],
  timeout: 45000,
  expect: { timeout: 12000 },
  use: {
    baseURL: customBase || 'http://localhost:5173',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  ...(skipWebServer
    ? {}
    : {
        webServer: [
          {
            command: 'npm start',
            cwd: __dirname,
            url: 'http://localhost:3030/api/health',
            reuseExistingServer: !process.env.CI,
            timeout: 15000,
          },
          {
            command: 'npm run dev',
            cwd: path.join(__dirname, 'src/web'),
            url: 'http://localhost:5173',
            reuseExistingServer: !process.env.CI,
            timeout: 60000,
          },
        ],
      }),
})
