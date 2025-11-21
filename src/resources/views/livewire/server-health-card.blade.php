<div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6" wire:poll.{{ config('monitoring.poll_interval', 10) }}s="loadMetrics">
    {{-- Header --}}
    <div class="flex items-center justify-between mb-4">
        <div class="flex items-center space-x-3">
            <div class="flex-shrink-0">
                <div class="w-12 h-12 rounded-full flex items-center justify-center {{
                    $this->getHealthBadgeColor() === 'green' ? 'bg-green-100 text-green-600' : (
                    $this->getHealthBadgeColor() === 'yellow' ? 'bg-yellow-100 text-yellow-600' : (
                    $this->getHealthBadgeColor() === 'red' ? 'bg-red-100 text-red-600' : 'bg-gray-100 text-gray-600'
                )) }}">
                    <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0 00-2-2m-2-4h.01M17 16h.01" />
                    </svg>
                </div>
            </div>
            <div>
                <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
                    {{ $metrics['server']['name'] ?? $serverCode }}
                </h3>
                <p class="text-sm text-gray-500 dark:text-gray-400">
                    {{ $metrics['server']['code'] ?? $serverCode }} • {{ $metrics['server']['ip_address'] ?? 'N/A' }}
                </p>
            </div>
        </div>

        <div class="flex items-center space-x-2">
            {{-- Health Badge --}}
            <span class="px-3 py-1 text-xs font-semibold rounded-full {{
                $this->getHealthBadgeColor() === 'green' ? 'bg-green-100 text-green-800' : (
                $this->getHealthBadgeColor() === 'yellow' ? 'bg-yellow-100 text-yellow-800' : (
                $this->getHealthBadgeColor() === 'red' ? 'bg-red-100 text-red-800' : 'bg-gray-100 text-gray-800'
            )) }}">
                {{ $this->getHealthStatusText() }}
            </span>

            {{-- Refresh Button --}}
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
            <span class="ml-3 text-gray-600 dark:text-gray-400">Loading metrics...</span>
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
            {{-- Quick Stats Grid --}}
            <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
                {{-- CPU --}}
                <div class="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                    <div class="flex items-center justify-between mb-2">
                        <span class="text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">CPU</span>
                        <span class="{{ $this->getCpuUsageClass() }} text-lg font-bold">
                            {{ number_format($metrics['metrics']['cpu']['usage_percent'] ?? 0, 1) }}%
                        </span>
                    </div>
                    <div class="w-full bg-gray-200 dark:bg-gray-600 rounded-full h-2">
                        <div class="h-2 rounded-full {{
                            ($metrics['metrics']['cpu']['usage_percent'] ?? 0) > 85 ? 'bg-red-600' : (
                            ($metrics['metrics']['cpu']['usage_percent'] ?? 0) > 70 ? 'bg-yellow-500' : 'bg-green-500'
                        ) }}" style="width: {{ min($metrics['metrics']['cpu']['usage_percent'] ?? 0, 100) }}%"></div>
                    </div>
                    <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
                        {{ $metrics['metrics']['cpu']['cores'] ?? 0 }} cores
                    </p>
                </div>

                {{-- Memory --}}
                <div class="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                    <div class="flex items-center justify-between mb-2">
                        <span class="text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">Memory</span>
                        <span class="{{ $this->getMemoryUsageClass() }} text-lg font-bold">
                            {{ number_format($metrics['metrics']['memory']['usage_percent'] ?? 0, 1) }}%
                        </span>
                    </div>
                    <div class="w-full bg-gray-200 dark:bg-gray-600 rounded-full h-2">
                        <div class="h-2 rounded-full {{
                            ($metrics['metrics']['memory']['usage_percent'] ?? 0) > 90 ? 'bg-red-600' : (
                            ($metrics['metrics']['memory']['usage_percent'] ?? 0) > 80 ? 'bg-yellow-500' : 'bg-green-500'
                        ) }}" style="width: {{ min($metrics['metrics']['memory']['usage_percent'] ?? 0, 100) }}%"></div>
                    </div>
                    <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
                        {{ number_format($metrics['metrics']['memory']['used_gb'] ?? 0, 1) }} / {{ number_format($metrics['metrics']['memory']['total_gb'] ?? 0, 1) }} GB
                    </p>
                </div>

                {{-- Load Average --}}
                <div class="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                    <div class="flex items-center justify-between mb-2">
                        <span class="text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">Load Avg</span>
                        <span class="text-lg font-bold text-gray-900 dark:text-white">
                            {{ number_format($metrics['metrics']['load']['1min'] ?? 0, 2) }}
                        </span>
                    </div>
                    <p class="text-xs text-gray-500 dark:text-gray-400">
                        1m: {{ number_format($metrics['metrics']['load']['1min'] ?? 0, 2) }} •
                        5m: {{ number_format($metrics['metrics']['load']['5min'] ?? 0, 2) }} •
                        15m: {{ number_format($metrics['metrics']['load']['15min'] ?? 0, 2) }}
                    </p>
                </div>

                {{-- Uptime --}}
                <div class="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                    <div class="flex items-center justify-between mb-2">
                        <span class="text-xs font-medium text-gray-500 dark:text-gray-400 uppercase">Uptime</span>
                        <span class="text-lg font-bold text-gray-900 dark:text-white">
                            {{ $metrics['metrics']['uptime']['formatted'] ?? 'N/A' }}
                        </span>
                    </div>
                    <p class="text-xs text-gray-500 dark:text-gray-400">
                        {{ number_format($metrics['metrics']['uptime']['seconds'] ?? 0) }} seconds
                    </p>
                </div>
            </div>

            {{-- Detailed Metrics (Collapsible) --}}
            @if ($showDetails)
                <div class="border-t border-gray-200 dark:border-gray-700 pt-4 mt-4">
                    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
                        <div>
                            <h4 class="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-2">CPU Details</h4>
                            <dl class="space-y-1">
                                <div class="flex justify-between text-sm">
                                    <dt class="text-gray-500 dark:text-gray-400">Model:</dt>
                                    <dd class="text-gray-900 dark:text-white font-mono text-xs">{{ $metrics['metrics']['cpu']['model'] ?? 'Unknown' }}</dd>
                                </div>
                                <div class="flex justify-between text-sm">
                                    <dt class="text-gray-500 dark:text-gray-400">Cores:</dt>
                                    <dd class="text-gray-900 dark:text-white">{{ $metrics['metrics']['cpu']['cores'] ?? 0 }}</dd>
                                </div>
                            </dl>
                        </div>

                        <div>
                            <h4 class="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-2">Memory Details</h4>
                            <dl class="space-y-1">
                                <div class="flex justify-between text-sm">
                                    <dt class="text-gray-500 dark:text-gray-400">Total:</dt>
                                    <dd class="text-gray-900 dark:text-white">{{ number_format($metrics['metrics']['memory']['total_gb'] ?? 0, 2) }} GB</dd>
                                </div>
                                <div class="flex justify-between text-sm">
                                    <dt class="text-gray-500 dark:text-gray-400">Used:</dt>
                                    <dd class="text-gray-900 dark:text-white">{{ number_format($metrics['metrics']['memory']['used_gb'] ?? 0, 2) }} GB</dd>
                                </div>
                                <div class="flex justify-between text-sm">
                                    <dt class="text-gray-500 dark:text-gray-400">Free:</dt>
                                    <dd class="text-gray-900 dark:text-white">{{ number_format($metrics['metrics']['memory']['free_gb'] ?? 0, 2) }} GB</dd>
                                </div>
                            </dl>
                        </div>
                    </div>
                </div>
            @endif

            {{-- Toggle Details Button --}}
            <div class="text-center pt-2">
                <button wire:click="toggleDetails" class="text-sm text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300 font-medium">
                    {{ $showDetails ? 'Hide Details' : 'Show Details' }}
                </button>
            </div>
        </div>
    @endif
</div>
