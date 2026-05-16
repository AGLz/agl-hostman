// @ts-check
const { test, expect } = require('@playwright/test')
const { attachEvoNexusNetworkMonitor } = require('./helpers/evonexus-network-monitor')

const TERMINAL_WS_URL = 'wss://evo.aglz.io/terminal/ws'

test.describe('EvoNexus terminal WebSocket', () => {
  test('terminal WS handshake opens (no invalid frame header)', async ({ page }) => {
    const monitor = attachEvoNexusNetworkMonitor(page, {
      terminalWsUrl: TERMINAL_WS_URL,
      getTestInfo: () => test.info(),
    })
    const consoleMessages = []
    page.on('console', (msg) => {
      consoleMessages.push(`${msg.type()}: ${msg.text()}`)
    })

    await page.goto('/', { waitUntil: 'domcontentloaded' })

    const wsResult = await page.evaluate((wsUrl) => {
      return new Promise((resolve) => {
        const ws = new WebSocket(wsUrl)
        let settled = false

        const finish = (result) => {
          if (settled) {
            return
          }
          settled = true
          try {
            ws.close()
          } catch {
            // ignore
          }
          resolve(result)
        }

        ws.addEventListener('open', () => finish({ ok: true }))
        ws.addEventListener('error', () => finish({ ok: false, error: 'error event' }))
        ws.addEventListener('close', (ev) => finish({ ok: false, error: `close ${ev.code} ${ev.reason || ''}`.trim() }))

        setTimeout(() => finish({ ok: false, error: 'timeout' }), 7000)
      })
    }, TERMINAL_WS_URL)

    await monitor.flush()

    if (!wsResult.ok) {
      test.info().attach('ws-result', { body: JSON.stringify(wsResult, null, 2), contentType: 'application/json' })
      test.info().attach('page-console', { body: consoleMessages.join('\n'), contentType: 'text/plain' })
    }

    expect(wsResult.ok, `WebSocket não abriu: ${wsResult.error || 'erro desconhecido'}`).toBe(true)
    expect(consoleMessages.join('\n')).not.toContain('Invalid frame header')
  })
})
