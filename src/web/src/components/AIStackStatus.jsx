// Usage:
// <AIStackStatus aiStatus={{ litellm: { status: 'running', models: 12 },
//   ruflo: { status: 'running', daemon: 'active' },
//   openclaw: { status: 'running', version: '1.2.0' } }} onRefresh={fn} />

import React, { useState } from 'react'

function StatusBadge({ status }) {
  const s = (status ?? 'unknown').toLowerCase()
  const isOk = ['running', 'ok', 'active', 'healthy'].includes(s)
  const isWarn = ['starting', 'degraded', 'partial'].includes(s)

  const cls = isOk
    ? 'bg-green-900 text-green-400'
    : isWarn
      ? 'bg-yellow-900 text-yellow-400'
      : 'bg-gray-700 text-gray-400'

  return (
    <span className={`text-xs px-2 py-0.5 rounded font-medium ${cls}`}>
      {status ?? 'unknown'}
    </span>
  )
}

function LiteLLMCard({ data }) {
  return (
    <div className="bg-gray-800 rounded-lg p-4 flex flex-col gap-2">
      <div className="flex items-center justify-between">
        <span className="font-semibold text-white text-sm">LiteLLM</span>
        <StatusBadge status={data?.status} />
      </div>
      <span className="text-gray-400 text-xs">
        {data?.models != null ? `${data.models} models loaded` : 'Model count unavailable'}
      </span>
    </div>
  )
}

function RufloCard({ data, onRefresh }) {
  const [busy, setBusy] = useState(false)
  const [feedback, setFeedback] = useState(null)

  async function handleStart() {
    setBusy(true)
    setFeedback(null)
    try {
      const res = await fetch('/api/ai/daemon', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'start' })
      })
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      setFeedback({ ok: true, msg: 'Daemon start requested.' })
      setTimeout(() => { onRefresh?.() }, 1500)
    } catch (err) {
      setFeedback({ ok: false, msg: err.message })
    } finally {
      setBusy(false)
    }
  }

  const isDaemonInactive = !['active', 'running'].includes(
    (data?.daemon ?? '').toLowerCase()
  )

  return (
    <div className="bg-gray-800 rounded-lg p-4 flex flex-col gap-2">
      <div className="flex items-center justify-between">
        <span className="font-semibold text-white text-sm">Ruflo</span>
        <StatusBadge status={data?.status} />
      </div>
      <span className="text-gray-400 text-xs">
        Daemon: {data?.daemon ?? 'unknown'}
      </span>
      {isDaemonInactive && (
        <button
          onClick={handleStart}
          disabled={busy}
          className="mt-1 text-xs bg-green-700 hover:bg-green-600 disabled:opacity-50
                     text-white px-3 py-1.5 rounded transition-colors self-start"
        >
          {busy ? 'Starting...' : 'Start Daemon'}
        </button>
      )}
      {feedback && (
        <span className={`text-xs ${feedback.ok ? 'text-green-400' : 'text-red-400'}`}>
          {feedback.msg}
        </span>
      )}
    </div>
  )
}

function OpenClawCard({ data }) {
  return (
    <div className="bg-gray-800 rounded-lg p-4 flex flex-col gap-2">
      <div className="flex items-center justify-between">
        <span className="font-semibold text-white text-sm">OpenClaw</span>
        <StatusBadge status={data?.status} />
      </div>
      <span className="text-gray-400 text-xs">
        {data?.version ? `v${data.version}` : 'Version unavailable'}
      </span>
    </div>
  )
}

export default function AIStackStatus({ aiStatus, onRefresh }) {
  if (!aiStatus) {
    return <p className="text-gray-500 text-sm">No AI status available.</p>
  }

  return (
    <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
      <LiteLLMCard data={aiStatus.litellm} />
      <RufloCard data={aiStatus.ruflo} onRefresh={onRefresh} />
      <OpenClawCard data={aiStatus.openclaw} />
    </div>
  )
}
