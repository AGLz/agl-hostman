// Usage:
// <HealthCard health={{ status: 'OK', uptime: '5d 3h', hosts_total: 6, hosts_reachable: 5, checked_at: '...' }} />

import React from 'react'

const STATUS_STYLES = {
  ok:       { bar: 'bg-green-400', text: 'text-green-400', label: 'OK' },
  healthy:  { bar: 'bg-green-400', text: 'text-green-400', label: 'OK' },
  degraded: { bar: 'bg-yellow-400', text: 'text-yellow-400', label: 'DEGRADED' },
  critical: { bar: 'bg-red-400', text: 'text-red-400', label: 'CRITICAL' }
}

function resolveStyle(status) {
  const key = (status ?? 'unknown').toLowerCase()
  return STATUS_STYLES[key] ?? { bar: 'bg-gray-500', text: 'text-gray-400', label: status ?? 'UNKNOWN' }
}

export default function HealthCard({ health }) {
  if (!health) {
    return <p className="text-gray-500 text-sm">No health data available.</p>
  }

  const style = resolveStyle(health.status)
  const total = health.hosts_total ?? health.total ?? null
  const reachable = health.hosts_reachable ?? health.reachable ?? null

  const checkedAt = health.checked_at
    ? new Date(health.checked_at).toLocaleTimeString()
    : null

  return (
    <div className="bg-gray-800 rounded-lg p-4 flex flex-col sm:flex-row sm:items-center gap-4">
      <div className={`w-1 self-stretch rounded-full ${style.bar} hidden sm:block`} />

      <div className="flex-1 grid grid-cols-1 sm:grid-cols-3 gap-3">
        <div className="flex flex-col gap-1">
          <span className="text-gray-400 text-xs uppercase tracking-wide">Status</span>
          <span className={`font-bold text-lg ${style.text}`}>{style.label}</span>
        </div>

        {total !== null && reachable !== null && (
          <div className="flex flex-col gap-1">
            <span className="text-gray-400 text-xs uppercase tracking-wide">Hosts</span>
            <span className="text-white font-semibold text-lg">
              {reachable}
              <span className="text-gray-500 font-normal text-sm"> / {total}</span>
            </span>
          </div>
        )}

        <div className="flex flex-col gap-1">
          <span className="text-gray-400 text-xs uppercase tracking-wide">
            {health.uptime ? 'Uptime' : 'Last Check'}
          </span>
          <span className="text-white text-sm">
            {health.uptime ?? checkedAt ?? 'N/A'}
          </span>
        </div>
      </div>
    </div>
  )
}
