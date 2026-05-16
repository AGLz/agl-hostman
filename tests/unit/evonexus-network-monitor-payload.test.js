const { test } = require('node:test')
const assert = require('node:assert')
const {
  serializeMonitorPayload,
  DEFAULT_HOST_HINT,
  MAX_HTTP_LOG,
} = require('../e2e/helpers/evonexus-network-monitor')

test('serializeMonitorPayload inclui URL do WS e flag de truncagem', () => {
  const http = Array.from({ length: MAX_HTTP_LOG }, (_, i) => ({
    kind: 'request',
    url: `https://evo.aglz.io/r${i}`,
  }))
  const p = serializeMonitorPayload('wss://evo.aglz.io/terminal/ws', http, [{ phase: 'socket', url: 'wss://x' }])
  assert.strictEqual(p.terminalWsUrl, 'wss://evo.aglz.io/terminal/ws')
  assert.strictEqual(p.http.length, MAX_HTTP_LOG)
  assert.strictEqual(p.httpTruncated, true)
  assert.ok(Array.isArray(p.websockets))
})

test('DEFAULT_HOST_HINT cobre evo.aglz.io', () => {
  assert.ok('https://evo.aglz.io/'.includes(DEFAULT_HOST_HINT))
})
