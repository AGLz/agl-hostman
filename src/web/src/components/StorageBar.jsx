// Usage:
// <StorageBar pools={[
//   { id: 'spark', size: '7.1TB', used_pct: 91.54, alert: true }
// ]} />

import React from 'react'

function barColor(pct) {
  if (pct >= 90) return 'bg-red-400'
  if (pct >= 70) return 'bg-yellow-400'
  return 'bg-green-400'
}

function textColor(pct) {
  if (pct >= 90) return 'text-red-400'
  if (pct >= 70) return 'text-yellow-400'
  return 'text-green-400'
}

function PoolRow({ pool }) {
  const pct = typeof pool.used_pct === 'number'
    ? Math.min(Math.max(pool.used_pct, 0), 100)
    : 0
  const display = pct.toFixed(1)

  return (
    <div className="bg-gray-800 rounded-lg p-4 flex flex-col gap-2">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="font-semibold text-white text-sm">{pool.id ?? pool.name}</span>
          {pool.alert && (
            <span className="bg-red-500 text-white text-xs px-1.5 py-0.5 rounded font-medium">
              ALERT
            </span>
          )}
        </div>
        <span className={`text-sm font-mono font-semibold ${textColor(pct)}`}>
          {display}%
        </span>
      </div>

      {pool.size && (
        <span className="text-gray-400 text-xs">{pool.size}</span>
      )}

      <div
        className="w-full bg-gray-700 rounded-full h-2"
        role="progressbar"
        aria-valuenow={pct}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-label={`${pool.id ?? pool.name} usage: ${display}%`}
      >
        <div
          className={`h-2 rounded-full transition-all duration-500 ${barColor(pct)}`}
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  )
}

export default function StorageBar({ pools }) {
  if (!pools || pools.length === 0) {
    return <p className="text-gray-500 text-sm">No storage pools found.</p>
  }

  return (
    <div className="flex flex-col gap-3">
      {pools.map((pool) => (
        <PoolRow key={pool.id ?? pool.name} pool={pool} />
      ))}
    </div>
  )
}
