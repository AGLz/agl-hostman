// Usage:
// <HostGrid hosts={[
//   { id: 'aglsrv1', name: 'AGLSRV1', role: 'Proxmox VE - Main', tailscale: '100.107.113.33', status: 'active' }
// ]} />

import React from 'react'

const STATUS_DOT = {
  active:   'bg-green-400',
  reachable: 'bg-green-400',
  online:   'bg-green-400',
  offline:  'bg-red-400',
  down:     'bg-red-400',
  unknown:  'bg-gray-500'
}

function statusDot(status) {
  const key = (status ?? 'unknown').toLowerCase()
  return STATUS_DOT[key] ?? 'bg-gray-500'
}

function statusLabel(status) {
  const s = (status ?? 'unknown').toLowerCase()
  if (['active', 'reachable', 'online'].includes(s)) return 'reachable'
  if (['offline', 'down'].includes(s)) return 'offline'
  return 'unknown'
}

function HostCard({ host }) {
  const dot = statusDot(host.status)
  const label = statusLabel(host.status)

  return (
    <div className="bg-gray-800 rounded-lg p-4 flex flex-col gap-2">
      <div className="flex items-center justify-between">
        <span className="font-bold text-white text-sm">{host.name ?? host.id}</span>
        <span className={`inline-block w-2.5 h-2.5 rounded-full ${dot}`} aria-label={label} />
      </div>
      <span className="text-gray-400 text-xs">{host.role ?? 'Unknown role'}</span>
      {host.tailscale && (
        <span className="text-gray-500 text-xs font-mono">{host.tailscale}</span>
      )}
      <span className={`text-xs mt-1 ${
        label === 'reachable' ? 'text-green-400' :
        label === 'offline'   ? 'text-red-400' :
        'text-gray-500'
      }`}>
        {label}
      </span>
    </div>
  )
}

export default function HostGrid({ hosts }) {
  if (!hosts || hosts.length === 0) {
    return <p className="text-gray-500 text-sm">No hosts found.</p>
  }

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
      {hosts.map((host) => (
        <HostCard key={host.id ?? host.name} host={host} />
      ))}
    </div>
  )
}
