// @ts-check
const { test, expect } = require('@playwright/test')

const SECTION_TITLES = ['System Health', 'Hosts', 'Storage Pools', 'AI Stack']

test.describe('AGL Hostman Dashboard', () => {
  test('page loads with correct title', async ({ page }) => {
    await page.goto('/')
    await expect(page).toHaveTitle('AGL Hostman')
  })

  test('header shows AGL Hostman branding', async ({ page }) => {
    await page.goto('/')
    await expect(page.getByText('AGL', { exact: true })).toBeVisible()
    await expect(page.getByRole('heading', { name: 'Hostman' })).toBeVisible()
  })

  test('all dashboard sections are visible', async ({ page }) => {
    await page.goto('/')
    for (const title of SECTION_TITLES) {
      await expect(page.getByRole('heading', { name: title })).toBeVisible()
    }
  })

  test('sections show loading, error, or content', async ({ page }) => {
    await page.goto('/')
    for (const title of SECTION_TITLES) {
      const section = page.locator('section').filter({ has: page.getByRole('heading', { name: title }) })
      await expect(section).toBeVisible()
      await expect(
        section.locator('p, [role="progressbar"], .bg-gray-800, .grid').first()
      ).toBeVisible({ timeout: 15000 })
    }
  })

  test('main dashboard flow - full page structure', async ({ page }) => {
    await page.goto('/')
    await expect(page).toHaveTitle('AGL Hostman')
    await expect(page.locator('header')).toBeVisible()
    await expect(page.locator('main')).toBeVisible()
    await expect(page.getByText(/Updated \d/)).toBeVisible({ timeout: 5000 })
    for (const title of SECTION_TITLES) {
      await expect(page.getByRole('heading', { name: title })).toBeVisible()
    }
  })

  test('displays host data when API is available', async ({ page }) => {
    await page.goto('/')
    await expect(page.getByRole('heading', { name: 'Hosts' })).toBeVisible()
    await expect(page.getByText('AGLSRV1')).toBeVisible({ timeout: 10000 })
  })
})
