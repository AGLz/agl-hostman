import React, { useState, useEffect, useCallback } from 'react'
import HostGrid from './components/HostGrid'
import StorageBar from './components/StorageBar'
import AIStackStatus from './components/AIStackStatus'
import HealthCard from './components/HealthCard'

const REFRESH_INTERVAL = 30000

function useFetch(url) {
  const [data, setData] = useState(null)
  const [error, setError] = useState(null)
  const [loading, setLoading] = useState(true)

  const fetchData = useCallback(async () => {
    try {
      const res = await fetch(url)
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      const json = await res.json()
      setData(json)
      setError(null)
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }, [url])

  useEffect(() => {
    fetchData()
    const id = setInterval(fetchData, REFRESH_INTERVAL)
    return () => clearInterval(id)
  }, [fetchData])

  return { data, error, loading, refetch: fetchData }
}

function SectionWrapper({ title, children, error, loading }) {
  return (
    <section>
      <h2 className="text-gray-400 text-xs font-semibold uppercase tracking-widest mb-3">
        {title}
      </h2>
      {loading && (
        <p className="text-gray-500 text-sm">Loading...</p>
      )}
      {error && !loading && (
        <p className="text-red-400 text-sm">Error: {error}</p>
      )}
      {!loading && !error && children}
    </section>
  )
}

export default function App() {
  const hosts = useFetch('/api/hosts')
  const storage = useFetch('/api/storage')
  const aiStatus = useFetch('/api/ai/status')
  const health = useFetch('/api/health')

  const [updatedAt, setUpdatedAt] = useState(new Date())

  useEffect(() => {
    const id = setInterval(() => setUpdatedAt(new Date()), REFRESH_INTERVAL)
    return () => clearInterval(id)
  }, [])

  return (
    <div className="min-h-screen bg-gray-900 text-white">
      <header className="border-b border-gray-700 px-6 py-4 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <span className="text-green-400 text-xl font-bold">AGL</span>
          <h1 className="text-white font-semibold text-lg">Hostman</h1>
        </div>
        <span className="text-gray-500 text-xs">
          Updated {updatedAt.toLocaleTimeString()}
        </span>
      </header>

      <main className="px-6 py-6 grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-6">
        <div className="xl:col-span-4">
          <SectionWrapper
            title="System Health"
            loading={health.loading}
            error={health.error}
          >
            <HealthCard health={health.data} />
          </SectionWrapper>
        </div>

        <div className="md:col-span-2 xl:col-span-2">
          <SectionWrapper
            title="Hosts"
            loading={hosts.loading}
            error={hosts.error}
          >
            <HostGrid hosts={hosts.data?.hosts ?? hosts.data ?? []} />
          </SectionWrapper>
        </div>

        <div className="md:col-span-2 xl:col-span-2">
          <SectionWrapper
            title="Storage Pools"
            loading={storage.loading}
            error={storage.error}
          >
            <StorageBar pools={storage.data?.pools ?? storage.data ?? []} />
          </SectionWrapper>
        </div>

        <div className="md:col-span-2 xl:col-span-4">
          <SectionWrapper
            title="AI Stack"
            loading={aiStatus.loading}
            error={aiStatus.error}
          >
            <AIStackStatus
              aiStatus={aiStatus.data}
              onRefresh={aiStatus.refetch}
            />
          </SectionWrapper>
        </div>
      </main>
    </div>
  )
}
