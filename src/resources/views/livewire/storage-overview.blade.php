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
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4m0 5c0 2.21-3.582 4-8 4s-8-1.79-8-4" />
                </svg>
            </div>
            <div>
                <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Storage Overview</h3>
                <p class="text-sm text-gray-500 dark:text-gray-400">NFS Mounts & Local Storage</p>
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
            <span class="ml-3 text-gray-600 dark:text-gray-400">Loading storage metrics...</span>
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
                {{-- Total Capacity --}}
                <div class="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                    <div class="text-xs font-medium text-gray-500 dark:text-gray-400 uppercase mb-1">Total Capacity</div>
                    <div class="text-2xl font-bold text-gray-900 dark:text-white">
                        {{ number_format($metrics['summary']['total_capacity_gb'] ?? 0, 0) }} GB
                    </div>
                </div>

                {{-- Used --}}
                <div class="bg-blue-50 dark:bg-blue-900/20 rounded-lg p-4">
                    <div class="text-xs font-medium text-blue-600 dark:text-blue-400 uppercase mb-1">Used</div>
                    <div class="text-2xl font-bold text-blue-600 dark:text-blue-400">
                        {{ number_format($metrics['summary']['total_used_gb'] ?? 0, 0) }} GB
                    </div>
                </div>

                {{-- Available --}}
                <div class="bg-green-50 dark:bg-green-900/20 rounded-lg p-4">
                    <div class="text-xs font-medium text-green-600 dark:text-green-400 uppercase mb-1">Available</div>
                    <div class="text-2xl font-bold text-green-600 dark:text-green-400">
                        {{ number_format($metrics['summary']['total_available_gb'] ?? 0, 0) }} GB
                    </div>
                </div>

                {{-- Mount Count --}}
                <div class="bg-purple-50 dark:bg-purple-900/20 rounded-lg p-4">
                    <div class="text-xs font-medium text-purple-600 dark:text-purple-400 uppercase mb-1">Mounts</div>
                    <div class="text-2xl font-bold text-purple-600 dark:text-purple-400">
                        {{ $metrics['summary']['mount_count'] ?? 0 }}
                    </div>
                </div>
            </div>

            {{-- Overall Usage Progress Bar --}}
            <div>
                <div class="flex justify-between text-sm mb-2">
                    <span class="text-gray-600 dark:text-gray-400">Overall Usage</span>
                    <span class="font-semibold text-gray-900 dark:text-white">{{ $this->getOverallUsagePercentage() }}%</span>
                </div>
                <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-3">
                    <div class="h-3 rounded-full {{
                        $this->getOverallUsagePercentage() > 85 ? 'bg-red-500' : (
                        $this->getOverallUsagePercentage() > 70 ? 'bg-yellow-500' : 'bg-green-500'
                    ) }}" style="width: {{ $this->getOverallUsagePercentage() }}%"></div>
                </div>
            </div>

            {{-- Mount Details (Collapsible) --}}
            @if ($showMountDetails && !empty($metrics['mounts']))
                <div class="border-t border-gray-200 dark:border-gray-700 pt-4 mt-4">
                    <h4 class="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3">Storage Mounts</h4>
                    <div class="space-y-3">
                        @foreach ($metrics['mounts'] as $mount)
                            <div class="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                                {{-- Mount Header --}}
                                <div class="flex items-center justify-between mb-3">
                                    <div>
                                        <div class="text-sm font-semibold text-gray-900 dark:text-white">{{ $mount['name'] ?? 'Unknown' }}</div>
                                        <div class="text-xs text-gray-500 dark:text-gray-400">
                                            {{ $mount['server'] ?? 'unknown' }} • {{ $mount['type'] ?? 'unknown' }}
                                            @if (isset($mount['active']) && $mount['active'])
                                                <span class="ml-2 px-2 py-0.5 bg-green-100 text-green-800 rounded-full text-xs font-medium">Active</span>
                                            @endif
                                        </div>
                                    </div>
                                    <span class="px-3 py-1 text-xs font-semibold rounded-full {{
                                        $this->getMountUsageColor($mount['percent_used'] ?? 0) === 'red' ? 'bg-red-100 text-red-800' : (
                                        $this->getMountUsageColor($mount['percent_used'] ?? 0) === 'yellow' ? 'bg-yellow-100 text-yellow-800' : 'bg-green-100 text-green-800'
                                    ) }}">
                                        {{ number_format($mount['percent_used'] ?? 0, 1) }}%
                                    </span>
                                </div>

                                {{-- Usage Bar --}}
                                <div class="mb-2">
                                    <div class="w-full bg-gray-200 dark:bg-gray-600 rounded-full h-2">
                                        <div class="h-2 rounded-full {{
                                            ($mount['percent_used'] ?? 0) > 85 ? 'bg-red-600' : (
                                            ($mount['percent_used'] ?? 0) > 70 ? 'bg-yellow-500' : 'bg-green-500'
                                        ) }}" style="width: {{ min($mount['percent_used'] ?? 0, 100) }}%"></div>
                                    </div>
                                </div>

                                {{-- Storage Stats --}}
                                <div class="grid grid-cols-3 gap-2 text-xs">
                                    <div>
                                        <span class="text-gray-500 dark:text-gray-400">Used:</span>
                                        <span class="{{ $this->getMountUsageClass($mount['percent_used'] ?? 0) }} font-semibold">
                                            {{ number_format($mount['used_gb'] ?? 0, 1) }} GB
                                        </span>
                                    </div>
                                    <div>
                                        <span class="text-gray-500 dark:text-gray-400">Total:</span>
                                        <span class="text-gray-900 dark:text-white font-semibold">
                                            {{ number_format($mount['total_gb'] ?? 0, 1) }} GB
                                        </span>
                                    </div>
                                    <div>
                                        <span class="text-gray-500 dark:text-gray-400">Free:</span>
                                        <span class="text-green-600 dark:text-green-400 font-semibold">
                                            {{ number_format($mount['available_gb'] ?? 0, 1) }} GB
                                        </span>
                                    </div>
                                </div>
                            </div>
                        @endforeach
                    </div>
                </div>
            @endif

            {{-- Toggle Mount Details Button --}}
            <div class="text-center pt-2">
                <button wire:click="toggleMountDetails" class="text-sm text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300 font-medium">
                    {{ $showMountDetails ? 'Hide Mount Details' : 'Show Mount Details' }}
                </button>
            </div>
        </div>
    @endif
</div>
