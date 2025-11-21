<div wire:poll.{{ config('monitoring.poll_interval', 10) }}s="$refresh">
    {{-- Filters and Search --}}
    <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-4 mb-4">
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
            {{-- Search --}}
            <div class="col-span-1 md:col-span-2">
                <label for="search" class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Search</label>
                <input
                    wire:model.live.debounce.300ms="search"
                    type="text"
                    id="search"
                    placeholder="Search by name, hostname, or ID..."
                    class="w-full rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white shadow-sm focus:border-blue-500 focus:ring-blue-500"
                >
            </div>

            {{-- Server Filter --}}
            <div>
                <label for="filterServer" class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Server</label>
                <select
                    wire:model.live="filterServer"
                    id="filterServer"
                    class="w-full rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white shadow-sm focus:border-blue-500 focus:ring-blue-500"
                >
                    <option value="">All Servers</option>
                    @foreach ($servers as $code => $name)
                        <option value="{{ $code }}">{{ $name }}</option>
                    @endforeach
                </select>
            </div>

            {{-- Status Filter --}}
            <div>
                <label for="filterStatus" class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Status</label>
                <select
                    wire:model.live="filterStatus"
                    id="filterStatus"
                    class="w-full rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white shadow-sm focus:border-blue-500 focus:ring-blue-500"
                >
                    <option value="">All Status</option>
                    <option value="running">Running</option>
                    <option value="stopped">Stopped</option>
                    <option value="error">Error</option>
                </select>
            </div>
        </div>

        {{-- Additional Filters Row --}}
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mt-4">
            {{-- Usage Filter --}}
            <div>
                <label for="filterUsage" class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Resource Usage</label>
                <select
                    wire:model.live="filterUsage"
                    id="filterUsage"
                    class="w-full rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white shadow-sm focus:border-blue-500 focus:ring-blue-500"
                >
                    <option value="">All</option>
                    <option value="normal">Normal</option>
                    <option value="high">High</option>
                    <option value="critical">Critical</option>
                </select>
            </div>

            {{-- Clear Filters --}}
            <div class="flex items-end">
                <button
                    wire:click="clearFilters"
                    class="px-4 py-2 bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300 rounded-md hover:bg-gray-300 dark:hover:bg-gray-600 transition-colors"
                >
                    Clear Filters
                </button>
            </div>

            {{-- Refresh --}}
            <div class="flex items-end">
                <button
                    wire:click="refreshContainers"
                    class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors flex items-center"
                >
                    <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                    </svg>
                    Refresh
                </button>
            </div>

            {{-- Export --}}
            <div class="flex items-end">
                <button
                    wire:click="exportMetrics"
                    class="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 transition-colors flex items-center"
                >
                    <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                    Export JSON
                </button>
            </div>
        </div>

        {{-- Results Count --}}
        <div class="mt-4 text-sm text-gray-600 dark:text-gray-400">
            Showing <span class="font-semibold">{{ $containers->count() }}</span> containers
        </div>
    </div>

    {{-- Container Grid --}}
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
        @forelse ($containers as $container)
            <div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg overflow-hidden hover:shadow-xl transition-shadow">
                {{-- Header with Status --}}
                <div class="bg-{{ $this->getStatusBadgeColor($container['status'] ?? 'unknown') }}-50 dark:bg-{{ $this->getStatusBadgeColor($container['status'] ?? 'unknown') }}-900/20 px-4 py-3 border-b border-{{ $this->getStatusBadgeColor($container['status'] ?? 'unknown') }}-200 dark:border-{{ $this->getStatusBadgeColor($container['status'] ?? 'unknown') }}-800">
                    <div class="flex items-center justify-between">
                        <div class="flex items-center space-x-2">
                            <span class="px-2 py-1 text-xs font-semibold rounded-full bg-{{ $this->getStatusBadgeColor($container['status'] ?? 'unknown') }}-600 text-white">
                                CT{{ $container['vmid'] ?? '?' }}
                            </span>
                            <span class="px-2 py-1 text-xs font-semibold rounded-full bg-{{ $this->getHealthBadgeColor($container['health_status'] ?? 'unknown') }}-100 text-{{ $this->getHealthBadgeColor($container['health_status'] ?? 'unknown') }}-800">
                                {{ ucfirst($container['status'] ?? 'unknown') }}
                            </span>
                        </div>
                    </div>
                </div>

                {{-- Container Info --}}
                <div class="p-4">
                    <h3 class="text-lg font-semibold text-gray-900 dark:text-white truncate" title="{{ $container['name'] ?? 'Unknown' }}">
                        {{ $container['name'] ?? 'Unknown' }}
                    </h3>
                    <p class="text-sm text-gray-500 dark:text-gray-400 truncate" title="{{ $container['hostname'] ?? 'N/A' }}">
                        {{ $container['hostname'] ?? 'N/A' }}
                    </p>

                    @if (isset($container['uptime_formatted']))
                        <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
                            Uptime: {{ $container['uptime_formatted'] }}
                        </p>
                    @endif

                    {{-- Resource Metrics --}}
                    @if (isset($container['cpu']) && isset($container['memory']))
                        <div class="mt-4 space-y-3">
                            {{-- CPU --}}
                            <div>
                                <div class="flex justify-between text-xs mb-1">
                                    <span class="text-gray-600 dark:text-gray-400">CPU</span>
                                    <span class="font-semibold {{
                                        $container['cpu']['usage_percent'] > 80 ? 'text-red-600' : (
                                        $container['cpu']['usage_percent'] > 60 ? 'text-yellow-600' : 'text-green-600'
                                    ) }}">
                                        {{ number_format($container['cpu']['usage_percent'], 1) }}%
                                    </span>
                                </div>
                                <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-1.5">
                                    <div class="h-1.5 rounded-full {{
                                        $container['cpu']['usage_percent'] > 80 ? 'bg-red-600' : (
                                        $container['cpu']['usage_percent'] > 60 ? 'bg-yellow-500' : 'bg-green-500'
                                    ) }}" style="width: {{ min($container['cpu']['usage_percent'], 100) }}%"></div>
                                </div>
                            </div>

                            {{-- Memory --}}
                            <div>
                                <div class="flex justify-between text-xs mb-1">
                                    <span class="text-gray-600 dark:text-gray-400">Memory</span>
                                    <span class="font-semibold {{
                                        $container['memory']['usage_percent'] > 90 ? 'text-red-600' : (
                                        $container['memory']['usage_percent'] > 75 ? 'text-yellow-600' : 'text-green-600'
                                    ) }}">
                                        {{ number_format($container['memory']['usage_percent'], 1) }}%
                                    </span>
                                </div>
                                <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-1.5">
                                    <div class="h-1.5 rounded-full {{
                                        $container['memory']['usage_percent'] > 90 ? 'bg-red-600' : (
                                        $container['memory']['usage_percent'] > 75 ? 'bg-yellow-500' : 'bg-green-500'
                                    ) }}" style="width: {{ min($container['memory']['usage_percent'], 100) }}%"></div>
                                </div>
                                <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
                                    {{ number_format($container['memory']['used_mb']) }} / {{ number_format($container['memory']['total_mb']) }} MB
                                </p>
                            </div>
                        </div>
                    @endif

                    {{-- Error Message --}}
                    @if (isset($container['error']))
                        <div class="mt-4 p-2 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded text-xs text-red-700 dark:text-red-400">
                            {{ $container['error'] }}
                        </div>
                    @endif
                </div>

                {{-- Actions Footer --}}
                <div class="bg-gray-50 dark:bg-gray-900 px-4 py-3 flex justify-between items-center">
                    <a href="/monitoring/container/{{ $container['id'] ?? '' }}" class="text-sm text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300 font-medium">
                        View Details →
                    </a>
                </div>
            </div>
        @empty
            <div class="col-span-full">
                <div class="bg-gray-50 dark:bg-gray-800 rounded-lg p-8 text-center">
                    <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
                    </svg>
                    <h3 class="mt-2 text-sm font-medium text-gray-900 dark:text-white">No containers found</h3>
                    <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                        Try adjusting your filters or search query.
                    </p>
                </div>
            </div>
        @endforelse
    </div>

    {{-- Sorting Headers (Table Alternative - Hidden for now) --}}
    {{-- Can be added later for table view mode --}}
</div>
