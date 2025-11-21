<div class="min-h-screen bg-gray-100 dark:bg-gray-900" wire:poll.{{ $refreshInterval }}s="loadDashboard">
    {{-- Header --}}
    <div class="bg-white dark:bg-gray-800 shadow">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
            <div class="flex items-center justify-between">
                <div>
                    <h1 class="text-3xl font-bold text-gray-900 dark:text-white">Infrastructure Monitoring</h1>
                    <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                        Real-time infrastructure metrics and health status
                        @if ($lastUpdated)
                            • Last updated: {{ \Carbon\Carbon::parse($lastUpdated)->diffForHumans() }}
                        @endif
                    </p>
                </div>

                <div class="flex items-center space-x-3">
                    {{-- Overall Health Badge --}}
                    <span class="px-4 py-2 text-sm font-semibold rounded-lg {{
                        $this->getOverallHealthColor() === 'green' ? 'bg-green-100 text-green-800' : (
                        $this->getOverallHealthColor() === 'yellow' ? 'bg-yellow-100 text-yellow-800' : (
                        $this->getOverallHealthColor() === 'red' ? 'bg-red-100 text-red-800' : 'bg-gray-100 text-gray-800'
                    )) }}">
                        Health Score: {{ $this->getHealthScore() }}%
                    </span>

                    {{-- Auto-Refresh Toggle --}}
                    <button
                        wire:click="toggleAutoRefresh"
                        class="px-4 py-2 rounded-lg {{ $autoRefresh ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800' }} hover:bg-opacity-80 transition-colors"
                    >
                        <span class="flex items-center">
                            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                            </svg>
                            Auto-Refresh {{ $autoRefresh ? 'ON' : 'OFF' }}
                        </span>
                    </button>

                    {{-- Manual Refresh --}}
                    <button
                        wire:click="refreshAllMetrics"
                        class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors flex items-center"
                    >
                        <svg class="w-4 h-4 mr-2 {{ $loading ? 'animate-spin' : '' }}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                        </svg>
                        Refresh
                    </button>

                    {{-- Export --}}
                    <button
                        wire:click="exportAllMetrics"
                        class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors flex items-center"
                    >
                        <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                        </svg>
                        Export
                    </button>
                </div>
            </div>
        </div>
    </div>

    {{-- Main Content --}}
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        {{-- Error State --}}
        @if ($error && !$loading)
            <div class="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-6 mb-6">
                <div class="flex">
                    <svg class="w-6 h-6 text-red-600 dark:text-red-400" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
                    </svg>
                    <div class="ml-3">
                        <h3 class="text-sm font-medium text-red-800 dark:text-red-400">Dashboard Error</h3>
                        <p class="mt-1 text-sm text-red-700 dark:text-red-300">{{ $error }}</p>
                    </div>
                </div>
            </div>
        @endif

        {{-- Summary Cards --}}
        @if (!empty($summary))
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-6">
                {{-- Servers --}}
                <div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6">
                    <div class="flex items-center justify-between">
                        <div>
                            <p class="text-sm font-medium text-gray-500 dark:text-gray-400 uppercase">Servers</p>
                            <p class="mt-2 text-3xl font-bold text-gray-900 dark:text-white">
                                {{ $summary['online_servers'] ?? 0 }}<span class="text-lg text-gray-500">/ {{ $summary['total_servers'] ?? 0 }}</span>
                            </p>
                        </div>
                        <div class="p-3 bg-blue-100 dark:bg-blue-900/20 rounded-full">
                            <svg class="w-8 h-8 text-blue-600 dark:text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0 00-2-2m-2-4h.01M17 16h.01" />
                            </svg>
                        </div>
                    </div>
                </div>

                {{-- Containers --}}
                <div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6">
                    <div class="flex items-center justify-between">
                        <div>
                            <p class="text-sm font-medium text-gray-500 dark:text-gray-400 uppercase">Containers</p>
                            <p class="mt-2 text-3xl font-bold text-gray-900 dark:text-white">
                                {{ $summary['running_containers'] ?? 0 }}<span class="text-lg text-gray-500">/ {{ $summary['total_containers'] ?? 0 }}</span>
                            </p>
                        </div>
                        <div class="p-3 bg-green-100 dark:bg-green-900/20 rounded-full">
                            <svg class="w-8 h-8 text-green-600 dark:text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
                            </svg>
                        </div>
                    </div>
                </div>

                {{-- Warnings --}}
                <div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6">
                    <div class="flex items-center justify-between">
                        <div>
                            <p class="text-sm font-medium text-gray-500 dark:text-gray-400 uppercase">Warnings</p>
                            <p class="mt-2 text-3xl font-bold text-yellow-600 dark:text-yellow-400">
                                {{ $summary['warning_containers'] ?? 0 }}
                            </p>
                        </div>
                        <div class="p-3 bg-yellow-100 dark:bg-yellow-900/20 rounded-full">
                            <svg class="w-8 h-8 text-yellow-600 dark:text-yellow-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                            </svg>
                        </div>
                    </div>
                </div>

                {{-- Critical --}}
                <div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6">
                    <div class="flex items-center justify-between">
                        <div>
                            <p class="text-sm font-medium text-gray-500 dark:text-gray-400 uppercase">Critical</p>
                            <p class="mt-2 text-3xl font-bold text-red-600 dark:text-red-400">
                                {{ $summary['critical_containers'] ?? 0 }}
                            </p>
                        </div>
                        <div class="p-3 bg-red-100 dark:bg-red-900/20 rounded-full">
                            <svg class="w-8 h-8 text-red-600 dark:text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                            </svg>
                        </div>
                    </div>
                </div>
            </div>
        @endif

        {{-- Server Health Cards --}}
        <div class="mb-6">
            <h2 class="text-xl font-bold text-gray-900 dark:text-white mb-4">Server Health</h2>
            <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                <livewire:server-health-card serverCode="aglsrv1" />
                <livewire:server-health-card serverCode="aglsrv6" />
            </div>
        </div>

        {{-- Network and Storage Overview --}}
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
            <livewire:network-metrics />
            <livewire:storage-overview />
        </div>

        {{-- Container Grid --}}
        <div class="mb-6">
            <h2 class="text-xl font-bold text-gray-900 dark:text-white mb-4">Container Overview</h2>
            <livewire:container-grid />
        </div>
    </div>
</div>

@push('scripts')
<script>
    // Listen for download-json event
    Livewire.on('download-json', (event) => {
        const data = event.content || event[0].content;
        const filename = event.filename || event[0].filename;

        const blob = new Blob([data], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = filename;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);
    });

    // Listen for alert-toast events
    Livewire.on('alert-toast', (event) => {
        const type = event.type || event[0].type;
        const message = event.message || event[0].message;

        // Simple toast notification (you can replace with your preferred notification library)
        console.log(`[${type.toUpperCase()}] ${message}`);
    });

    // Pause polling when tab is inactive (save resources)
    let pollingEnabled = true;

    document.addEventListener('visibilitychange', () => {
        if (document.hidden) {
            pollingEnabled = false;
            console.log('Dashboard polling paused (tab inactive)');
        } else {
            pollingEnabled = true;
            console.log('Dashboard polling resumed (tab active)');
            // Trigger immediate refresh when tab becomes active
            Livewire.dispatch('refreshDashboard');
        }
    });
</script>
@endpush
