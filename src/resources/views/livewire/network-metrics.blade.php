<div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6" wire:poll.{{ config('monitoring.poll_interval', 10) }}s="loadMetrics">
    {{-- Header --}}
    <div class="flex items-center justify-between mb-4">
        <div class="flex items-center space-x-3">
            <div class="w-12 h-12 rounded-full flex items-center justify-center {{
                $this->getHealthBadgeColor() === 'green' ? 'bg-green-100 text-green-600' : (
                $this->getHealthBadgeColor() === 'yellow' ? 'bg-yellow-100 text-yellow-600' : (
                $this->getHealthBadgeColor() === 'red' ? 'bg-red-100 text-red-600' : 'bg-gray-100 text-gray-600'
            )) }}">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9" />
                </svg>
            </div>
            <div>
                <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Network Status</h3>
                <p class="text-sm text-gray-500 dark:text-gray-400">WireGuard Mesh (10.6.0.0/24)</p>
            </div>
        </div>

        <div class="flex items-center space-x-2">
            <span class="px-3 py-1 text-xs font-semibold rounded-full {{
                $this->getHealthBadgeColor() === 'green' ? 'bg-green-100 text-green-800' : (
                $this->getHealthBadgeColor() === 'yellow' ? 'bg-yellow-100 text-yellow-800' : (
                $this->getHealthBadgeColor() === 'red' ? 'bg-red-100 text-red-800' : 'bg-gray-100 text-gray-800'
            )) }}">
                @if ($metrics)
                    {{ ucfirst($metrics['health_status']) }}
                @else
                    Unknown
                @endif
            </span>

            <button wire:click="refresh" class="p-2 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 transition-colors">
                <svg class="w-5 h-5 {{ $loading ? 'animate-spin' : '' }}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                </svg>
            </button>
        </div>
    </div>

    {{-- Loading State --}}
    @if ($loading)
        <div class="flex justify-center items-center py-8">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
            <span class="ml-3 text-gray-600 dark:text-gray-400">Loading network metrics...</span>
        </div>
    @endif

    {{-- Error State --}}
    @if ($error && !$loading)
        <div class="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-4">
            <div class="flex">
                <svg class="w-5 h-5 text-red-600 dark:text-red-400" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
                </svg>
                <div class="ml-3">
                    <p class="text-sm text-red-800 dark:text-red-400">{{ $error }}</p>
                </div>
            </div>
        </div>
    @endif

    {{-- Metrics Display --}}
    @if ($metrics && !$loading && !$error)
        <div class="space-y-4">
            {{-- Summary Stats --}}
            <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
                {{-- Total Peers --}}
                <div class="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                    <div class="text-xs font-medium text-gray-500 dark:text-gray-400 uppercase mb-1">Total Peers</div>
                    <div class="text-2xl font-bold text-gray-900 dark:text-white">
                        {{ $metrics['summary']['total_peers'] ?? 0 }}
                    </div>
                </div>

                {{-- Connected --}}
                <div class="bg-green-50 dark:bg-green-900/20 rounded-lg p-4">
                    <div class="text-xs font-medium text-green-600 dark:text-green-400 uppercase mb-1">Connected</div>
                    <div class="text-2xl font-bold text-green-600 dark:text-green-400">
                        {{ $metrics['summary']['connected_peers'] ?? 0 }}
                    </div>
                </div>

                {{-- Disconnected --}}
                <div class="bg-red-50 dark:bg-red-900/20 rounded-lg p-4">
                    <div class="text-xs font-medium text-red-600 dark:text-red-400 uppercase mb-1">Disconnected</div>
                    <div class="text-2xl font-bold text-red-600 dark:text-red-400">
                        {{ $metrics['summary']['disconnected_peers'] ?? 0 }}
                    </div>
                </div>

                {{-- Avg Latency --}}
                <div class="bg-blue-50 dark:bg-blue-900/20 rounded-lg p-4">
                    <div class="text-xs font-medium text-blue-600 dark:text-blue-400 uppercase mb-1">Avg Latency</div>
                    <div class="text-2xl font-bold text-blue-600 dark:text-blue-400">
                        {{ number_format($metrics['summary']['avg_latency_ms'] ?? 0, 1) }}ms
                    </div>
                </div>
            </div>

            {{-- Connection Progress Bar --}}
            <div>
                <div class="flex justify-between text-sm mb-2">
                    <span class="text-gray-600 dark:text-gray-400">Connection Status</span>
                    <span class="font-semibold text-gray-900 dark:text-white">{{ $this->getConnectionPercentage() }}%</span>
                </div>
                <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-3">
                    <div class="h-3 rounded-full {{
                        $this->getConnectionPercentage() >= 95 ? 'bg-green-500' : (
                        $this->getConnectionPercentage() >= 80 ? 'bg-yellow-500' : 'bg-red-500'
                    ) }}" style="width: {{ $this->getConnectionPercentage() }}%"></div>
                </div>
            </div>

            {{-- Peer Details (Collapsible) --}}
            @if ($showPeerDetails && !empty($metrics['peers']))
                <div class="border-t border-gray-200 dark:border-gray-700 pt-4 mt-4">
                    <h4 class="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3">Peer Details</h4>
                    <div class="space-y-2">
                        @foreach ($metrics['peers'] as $peer)
                            <div class="flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-700 rounded-lg">
                                <div class="flex items-center space-x-3">
                                    <div class="w-3 h-3 rounded-full {{
                                        $this->getPeerStatusColor($peer['status'] ?? 'unknown') === 'green' ? 'bg-green-500' : (
                                        $this->getPeerStatusColor($peer['status'] ?? 'unknown') === 'yellow' ? 'bg-yellow-500' : 'bg-red-500'
                                    ) }}"></div>
                                    <div>
                                        <div class="text-sm font-medium text-gray-900 dark:text-white">{{ $peer['name'] ?? 'Unknown' }}</div>
                                        <div class="text-xs text-gray-500 dark:text-gray-400 font-mono">{{ $peer['ip'] ?? 'N/A' }}</div>
                                    </div>
                                </div>
                                <div class="flex items-center space-x-4">
                                    <span class="px-2 py-1 text-xs font-semibold rounded-full {{
                                        $this->getPeerStatusColor($peer['status'] ?? 'unknown') === 'green' ? 'bg-green-100 text-green-800' : (
                                        $this->getPeerStatusColor($peer['status'] ?? 'unknown') === 'yellow' ? 'bg-yellow-100 text-yellow-800' : 'bg-red-100 text-red-800'
                                    ) }}">
                                        {{ ucfirst($peer['status'] ?? 'unknown') }}
                                    </span>
                                    @if (isset($peer['latency_ms']))
                                        <span class="{{ $this->getLatencyClass($peer['latency_ms']) }} text-sm font-semibold">
                                            {{ number_format($peer['latency_ms'], 1) }}ms
                                        </span>
                                    @endif
                                </div>
                            </div>
                        @endforeach
                    </div>
                </div>
            @endif

            {{-- Toggle Peer Details Button --}}
            <div class="text-center pt-2">
                <button wire:click="togglePeerDetails" class="text-sm text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300 font-medium">
                    {{ $showPeerDetails ? 'Hide Peer Details' : 'Show Peer Details' }}
                </button>
            </div>
        </div>
    @endif
</div>
