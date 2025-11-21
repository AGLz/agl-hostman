<div class="space-y-4 p-6">
    <!-- Filters and Controls -->
    <div class="flex flex-wrap items-center justify-between gap-4">
        <!-- Search -->
        <div class="flex-1 min-w-0 max-w-md">
            <input type="text"
                   wire:model.live.debounce.500ms="searchTerm"
                   placeholder="Search by container name, VMID, or node..."
                   class="w-full rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-700 text-sm">
        </div>

        <!-- Filters -->
        <div class="flex items-center space-x-2">
            <select wire:model.live="hours" class="rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-700 text-sm">
                <option value="1">Last Hour</option>
                <option value="6">Last 6 Hours</option>
                <option value="24">Last 24 Hours</option>
                <option value="72">Last 3 Days</option>
                <option value="168">Last 7 Days</option>
            </select>

            <select wire:model.live="severityFilter" class="rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-700 text-sm">
                <option value="all">All Severity</option>
                <option value="critical">Critical Only</option>
                <option value="warning">Warning Only</option>
                <option value="unhealthy">Warning + Critical</option>
            </select>

            <button wire:click="clearFilters" class="px-3 py-2 text-sm bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300 rounded hover:bg-gray-300 dark:hover:bg-gray-600">
                Clear Filters
            </button>

            <button wire:click="exportCsv" class="px-3 py-2 text-sm bg-blue-600 text-white rounded hover:bg-blue-700">
                Export CSV
            </button>
        </div>
    </div>

    <!-- Alert Statistics -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div class="bg-gray-50 dark:bg-gray-900 rounded-lg p-4">
            <div class="text-sm text-gray-500 dark:text-gray-400">Total Alerts</div>
            <div class="text-2xl font-bold text-gray-900 dark:text-white">{{ $totalAlerts }}</div>
        </div>
        <div class="bg-red-50 dark:bg-red-900 rounded-lg p-4">
            <div class="text-sm text-red-600 dark:text-red-300">Critical</div>
            <div class="text-2xl font-bold text-red-700 dark:text-red-200">{{ $criticalCount }}</div>
        </div>
        <div class="bg-yellow-50 dark:bg-yellow-900 rounded-lg p-4">
            <div class="text-sm text-yellow-600 dark:text-yellow-300">Warning</div>
            <div class="text-2xl font-bold text-yellow-700 dark:text-yellow-200">{{ $warningCount }}</div>
        </div>
    </div>

    <!-- Alerts Table -->
    <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
            <thead class="bg-gray-50 dark:bg-gray-800">
                <tr>
                    <th wire:click="sortBy('created_at')"
                        class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider cursor-pointer hover:bg-gray-100 dark:hover:bg-gray-700">
                        Timestamp
                        @if ($sortBy === 'created_at')
                            <span class="ml-1">{{ $sortDirection === 'asc' ? '↑' : '↓' }}</span>
                        @endif
                    </th>
                    <th wire:click="sortBy('health_status')"
                        class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider cursor-pointer hover:bg-gray-100 dark:hover:bg-gray-700">
                        Severity
                        @if ($sortBy === 'health_status')
                            <span class="ml-1">{{ $sortDirection === 'asc' ? '↑' : '↓' }}</span>
                        @endif
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                        Node
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                        Container
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                        Metrics
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                        Issues
                    </th>
                </tr>
            </thead>
            <tbody class="bg-white dark:bg-gray-900 divide-y divide-gray-200 dark:divide-gray-700">
                @forelse ($alerts as $alert)
                    <tr class="hover:bg-gray-50 dark:hover:bg-gray-800">
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-300">
                            {{ $alert->created_at->format('M d, H:i:s') }}
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap">
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-{{ $this->getSeverityColor($alert->health_status) }}-100 dark:bg-{{ $this->getSeverityColor($alert->health_status) }}-900 text-{{ $this->getSeverityColor($alert->health_status) }}-800 dark:text-{{ $this->getSeverityColor($alert->health_status) }}-200">
                                {{ ucfirst($alert->health_status) }}
                            </span>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-300">
                            {{ $alert->node_code }}
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap">
                            <div class="text-sm font-medium text-gray-900 dark:text-white">{{ $alert->container_name }}</div>
                            <div class="text-sm text-gray-500 dark:text-gray-400">VMID: {{ $alert->vmid }}</div>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-300">
                            <div>CPU: {{ number_format($alert->cpu_usage_percent, 1) }}%</div>
                            <div>MEM: {{ number_format($alert->memory_usage_percent, 1) }}%</div>
                            <div>DISK: {{ number_format($alert->disk_usage_percent, 1) }}%</div>
                        </td>
                        <td class="px-6 py-4 text-sm text-gray-500 dark:text-gray-400">
                            @if ($alert->issues && count($alert->issues) > 0)
                                <ul class="list-disc list-inside">
                                    @foreach ($alert->issues as $issue)
                                        <li>{{ $issue }}</li>
                                    @endforeach
                                </ul>
                            @else
                                <span class="text-gray-400">No issues</span>
                            @endif
                        </td>
                    </tr>
                @empty
                    <tr>
                        <td colspan="6" class="px-6 py-12 text-center text-gray-500 dark:text-gray-400">
                            No alerts found for the selected filters
                        </td>
                    </tr>
                @endforelse
            </tbody>
        </table>
    </div>

    <!-- Pagination -->
    <div class="mt-4">
        {{ $alerts->links() }}
    </div>
</div>
