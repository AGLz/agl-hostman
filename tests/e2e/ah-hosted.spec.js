// @ts-check
const { test, expect } = require('@playwright/test')

const HOSTED_ORIGIN = 'https://ah.aglz.io'
const DASHBOARD_PATHS = [
  '/dashboard',
  '/mission-control',
  '/mission-control/openclaw',
]

function hostedBaseURL() {
  return (process.env.PLAYWRIGHT_BASE_URL || HOSTED_ORIGIN).replace(/\/$/, '')
}

async function login(page) {
  const email = process.env.AH_E2E_EMAIL
  const password = process.env.AH_E2E_PASSWORD

  test.skip(!email || !password, 'Set AH_E2E_EMAIL and AH_E2E_PASSWORD to run authenticated hosted checks')

  await page.goto('/auth/login')
  await page.getByLabel(/email/i).fill(email)
  await page.getByLabel(/password/i).fill(password)
  await page.getByRole('button', { name: /sign in|log in|login|entrar/i }).click()
  await expect(page).not.toHaveURL(/\/auth\/login(?:$|\?)/, { timeout: 15000 })
}

test.describe('ah.aglz.io hosted smoke', () => {
  test.use({ baseURL: hostedBaseURL() })

  test('root redirects unauthenticated users to the login route', async ({ request }) => {
    const response = await request.get('/', { maxRedirects: 0 })

    expect(response.status()).toBe(302)
    expect(response.headers().location).toContain('/auth/login')
    expect(response.headers()['strict-transport-security']).toContain('max-age=')
    expect(response.headers()['x-frame-options']).toContain('DENY')
  })

  test('login page renders the expected form', async ({ page }) => {
    await page.goto('/auth/login')

    await expect(page).toHaveURL(/\/auth\/login$/)
    await expect(page).toHaveTitle(/Login.*AGL-Hostman/i)
    await expect(page.getByLabel(/email/i)).toBeVisible()
    await expect(page.getByLabel(/password/i)).toBeVisible()
    await expect(page.getByRole('button', { name: /sign in|log in|login|entrar/i })).toBeVisible()
    await expect(page.locator('form[action$="/auth/login"]')).toBeVisible()
  })

  for (const path of DASHBOARD_PATHS) {
    test(`${path} is protected when unauthenticated`, async ({ page }) => {
      await page.goto(path)
      await expect(page).toHaveURL(/\/auth\/login$/)
      await expect(page.getByLabel(/email/i)).toBeVisible()
    })
  }

  test('OpenClaw status API is available after the hosted app is updated', async ({ request }) => {
    test.skip(process.env.AH_EXPECT_OPENCLAW_API !== '1', 'Set AH_EXPECT_OPENCLAW_API=1 after deploying the OpenClaw API routes')

    const response = await request.get('/api/openclaw/status')
    expect(response.ok()).toBeTruthy()

    const data = await response.json()
    expect(data).toMatchObject({
      status: expect.stringMatching(/online|offline/),
      gateway: expect.any(String),
      checked_at: expect.any(String),
    })
    expect(Object.keys(data.agents || {}).length).toBeGreaterThan(0)
  })

  test('authenticated OpenClaw dashboard loads with agent chat controls', async ({ page }) => {
    await login(page)
    await page.goto('/mission-control/openclaw')

    await expect(page.getByText(/OpenClaw|Teams/i).first()).toBeVisible({ timeout: 20000 })
    await expect(page.getByRole('button', { name: /test chat/i }).first()).toBeVisible({ timeout: 20000 })
  })
})
