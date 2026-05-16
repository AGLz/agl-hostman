/**
 * Monitorização de rede EvoNexus para testes Playwright (HTTP *aglz.io* + WebSockets da página).
 * @typedef {{ kind: string, url?: string, method?: string, status?: number, [key: string]: unknown }} HttpEntry
 * @typedef {{ phase: string, url?: string, [key: string]: unknown }} WsEntry
 */

const DEFAULT_HOST_HINT = 'aglz.io'
const MAX_HTTP_LOG = 100
const MAX_WS_FRAME_PREVIEW = 240
const MAX_WS_FRAMES_LOGGED_EACH_WAY = 5

/**
 * @param {string} terminalWsUrl
 * @param {HttpEntry[]} http
 * @param {WsEntry[]} websockets
 * @returns {Record<string, unknown>}
 */
function serializeMonitorPayload(terminalWsUrl, http, websockets) {
  return {
    terminalWsUrl,
    http,
    websockets,
    httpTruncated: http.length >= MAX_HTTP_LOG,
  }
}

/**
 * @param {import('@playwright/test').Page} page
 * @param {object} opts
 * @param {string} [opts.hostHint]
 * @param {string} opts.terminalWsUrl
 * @param {() => import('@playwright/test').TestInfo} opts.getTestInfo
 */
function attachEvoNexusNetworkMonitor(page, opts) {
  const hostHint = opts.hostHint ?? DEFAULT_HOST_HINT
  const terminalWsUrl = opts.terminalWsUrl
  const getTestInfo = opts.getTestInfo

  /** @type {HttpEntry[]} */
  const http = []
  /** @type {WsEntry[]} */
  const websockets = []

  const pushHttp = (entry) => {
    if (http.length >= MAX_HTTP_LOG) {
      return
    }
    http.push(entry)
  }

  page.on('request', (req) => {
    const url = req.url()
    if (!url.includes(hostHint)) {
      return
    }
    pushHttp({ kind: 'request', method: req.method(), url, resourceType: req.resourceType() })
  })

  page.on('response', (res) => {
    const url = res.url()
    if (!url.includes(hostHint)) {
      return
    }
    const entry = { kind: 'response', status: res.status(), url }
    try {
      const headers = res.headers()
      entry['content-type'] = headers['content-type'] || headers['Content-Type'] || ''
    } catch {
      // ignore
    }
    pushHttp(entry)
  })

  page.on('websocket', (ws) => {
    const url = ws.url()
    let framesIn = 0
    let framesOut = 0
    websockets.push({ phase: 'socket', url, time: new Date().toISOString() })
    ws.on('framereceived', (e) => {
      framesIn++
      const p = e.payload
      const preview =
        typeof p === 'string'
          ? p.length > MAX_WS_FRAME_PREVIEW
            ? `${p.slice(0, MAX_WS_FRAME_PREVIEW)}…`
            : p
          : '[binary]'
      if (framesIn <= MAX_WS_FRAMES_LOGGED_EACH_WAY) {
        websockets.push({ phase: 'frame_in', url, n: framesIn, preview })
      }
    })
    ws.on('framesent', (e) => {
      framesOut++
      const p = e.payload
      const preview =
        typeof p === 'string'
          ? p.length > MAX_WS_FRAME_PREVIEW
            ? `${p.slice(0, MAX_WS_FRAME_PREVIEW)}…`
            : p
          : '[binary]'
      if (framesOut <= MAX_WS_FRAMES_LOGGED_EACH_WAY) {
        websockets.push({ phase: 'frame_out', url, n: framesOut, preview })
      }
    })
    ws.on('close', () => {
      websockets.push({ phase: 'close', url, framesIn, framesOut })
    })
  })

  return {
    http,
    websockets,
    async flush() {
      const body = JSON.stringify(serializeMonitorPayload(terminalWsUrl, http, websockets), null, 2)
      await getTestInfo().attach('evonexus-network-monitor', {
        body,
        contentType: 'application/json',
      })
    },
  }
}

module.exports = {
  attachEvoNexusNetworkMonitor,
  serializeMonitorPayload,
  DEFAULT_HOST_HINT,
  MAX_HTTP_LOG,
}
