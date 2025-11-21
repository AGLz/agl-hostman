<div class="space-y-6" wire:poll.30s="loadDashboardData">
    <!-- Cluster Statistics Cards -->
    <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
        <!-- Total Servers -->
        <div class="bg-white dark:bg-gray-800 overflow-hidden shadow rounded-lg">
            <div class="p-5">
                <div class="flex items-center">
                    <div class="flex-shrink-0">
                        <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0 00-2-2m-2-4h.01M17 16h.01" />
                        </svg>
                    </div>
                    <div class="ml-5 w-0 flex-1">
                        <dl>
                            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400 truncate">
                                Online Servers
                            </dt>
                            <dd class="flex items-baseline">
                                <div class="text-2xl font-semibold text-gray-900 dark:text-white">
                                    {{ $clusterStats['servers']['online'] ?? 0 }}
                                </div>
                                <div class="ml-2 text-sm text-gray-500 dark:text-gray-400">
                                    / {{ $clusterStats['servers']['total'] ?? 0 }}
                                </div>
                            </dd>
                        </dl>
                    </div>
                </div>
            </div>
        </div>

        <!-- Total Containers -->
        <div class="bg-white dark:bg-gray-800 overflow-hidden shadow rounded-lg">
            <div class="p-5">
                <div class="flex items-center">
                    <div class="flex-shrink-0">
                        <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
                        </svg>
                    </div>
                    <div class="ml-5 w-0 flex-1">
                        <dl>
                            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400 truncate">
                                Total Containers
                            </dt>
                            <dd class="text-2xl font-semibold text-gray-900 dark:text-white">
                                {{ $clusterStats['containers']['total'] ?? 0 }}
                            </dd>
                        </dl>
                    </div>
                </div>
            </div>
        </div>

        <!-- Health Score -->
        <div class="bg-white dark:bg-gray-800 overflow-hidden shadow rounded-lg">
            <div class="p-5">
                <div class="flex items-center">
                    <div class="flex-shrink-0">
                        <svg class="h-6 w-6 text-{{ $this->getHealthScoreColor($clusterStats['health_score'] ?? 100) }}-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
                        </svg>
                    </div>
                    <div class="ml-5 w-0 flex-1">
                        <dl>
                            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400 truncate">
                                Health Score
                            </dt>
                            <dd class="text-2xl font-semibold text-{{ $this->getHealthScoreColor($clusterStats['health_score'] ?? 100) }}-600">
                                {{ $clusterStats['health_score'] ?? 100 }}%
                            </dd>
                        </dl>
                    </div>
                </div>
            </div>
        </div>

        <!-- Critical Alerts -->
        <div class="bg-white dark:bg-gray-800 overflow-hidden shadow rounded-lg">
            <div class="p-5">
                <div class="flex items-center">
                    <div class="flex-shrink-0">
                        <svg class="h-6 w-6 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                        </svg>
                    </div>
                    <div class="ml-5 w-0 flex-1">
                        <dl>
                            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400 truncate">
                                Critical Incidents (24h)
                            </dt>
                            <dd class="text-2xl font-semibold text-gray-900 dark:text-white">
                                {{ $clusterStats['alerts']['critical_incidents'] ?? 0 }}
                            </dd>
                        </dl>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Container Health Status Grid -->
    <div class="bg-white dark:bg-gray-800 shadow overflow-hidden sm:rounded-lg">
        <div class="px-4 py-5 sm:px-6 flex justify-between items-center">
            <div>
                <h3 class="text-lg leading-6 font-medium text-gray-900 dark:text-white">
                    Container Health Status
                </h3>
                <p class="mt-1 max-w-2xl text-sm text-gray-500 dark:text-gray-400">
                    Real-time monitoring of all containers across the cluster
                </p>
            </div>
            <div class="flex space-x-2">
                <button wire:click="setViewMode('grid')"
                        class="px-3 py-1 text-sm rounded {{ $viewMode === 'grid' ? 'bg-blue-600 text-white' : 'bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300' }}">
                    Grid
                </button>
                <button wire:click="setViewMode('list')"
                        class="px-3 py-1 text-sm rounded {{ $viewMode === 'list' ? 'bg-blue-600 text-white' : 'bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300' }}">
                    List
                </button>
            </div>
        </div>
        <div class="border-t border-gray-200 dark:border-gray-700 px-4 py-5 sm:p-6">
            <div class="mb-4">
                <label class="inline-flex items-center mr-4">
                    <input type="radio" wire:model.live="healthFilter" value="all" class="form-radio">
                    <span class="ml-2 text-sm text-gray-700 dark:text-gray-300">All</span>
                </label>
                <label class="inline-flex items-center mr-4">
                    <input type="radio" wire:model.live="healthFilter" value="healthy" class="form-radio">
                    <span class="ml-2 text-sm text-green-600">Healthy</span>
                </label>
                <label class="inline-flex items-center mr-4">
                    <input type="radio" wire:model.live="healthFilter" value="warning" class="form-radio">
                    <span class="ml-2 text-sm text-yellow-600">Warning</span>
                </label>
                <label class="inline-flex items-center">
                    <input type="radio" wire:model.live="healthFilter" value="critical" class="form-radio">
                    <span class="ml-2 text-sm text-red-600">Critical</span>
                </label>
            </div>

            <!-- Grid/List Container Display -->
            @if (!empty($nodes))
                @foreach ($nodes as $node)
                    <div class="mb-6">
                        <h4 class="text-md font-semibold text-gray-700 dark:text-gray-300 mb-3">
                            Node: {{ $node['name'] }} ({{ $node['code'] }})
                        </h4>
                        <div class="grid gap-4 {{ $viewMode === 'grid' ? 'md:grid-cols-2 lg:grid-cols-3' : 'grid-cols-1' }}">
                            @for ($vmid = 100; $vmid <= 110; $vmid++)
                                @livewire('container-health-card', ['node' => $node['code'], 'vmid' => $vmid], key('container-'.$node['code'].'-'.$vmid))
                            @endfor
                        </div>
                    </div>
                @endforeach
            @else
                <p class="text-center text-gray-500 dark:text-gray-400 py-8">
                    No online nodes found. Please check your Proxmox servers.
                </p>
            @endif
        </div>
    </div>

    <!-- Resource Trends & Alerts Grid -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <!-- Resource Trend Chart -->
        <div class="bg-white dark:bg-gray-800 shadow overflow-hidden sm:rounded-lg">
            <div class="px-4 py-5 sm:px-6">
                <h3 class="text-lg leading-6 font-medium text-gray-900 dark:text-white">
                    Resource Trends
                </h3>
            </div>
            <div class="border-t border-gray-200 dark:border-gray-700 px-4 py-5 sm:p-6">
                @livewire('resource-trend-chart', ['metricType' => 'cluster_health', 'metricName' => 'avg_cpu_usage', 'hours' => 24])
            </div>
        </div>

        <!-- Predictive Maintenance Widget -->
        <div class="bg-white dark:bg-gray-800 shadow overflow-hidden sm:rounded-lg">
            <div class="px-4 py-5 sm:px-6">
                <h3 class="text-lg leading-6 font-medium text-gray-900 dark:text-white">
                    Predictive Maintenance
                </h3>
            </div>
            <div class="border-t border-gray-200 dark:border-gray-700 px-4 py-5 sm:p-6">
                @livewire('predictive-maintenance-widget')
            </div>
        </div>
    </div>

    <!-- Alert History Panel -->
    <div class="bg-white dark:bg-gray-800 shadow overflow-hidden sm:rounded-lg">
        <div class="px-4 py-5 sm:px-6">
            <h3 class="text-lg leading-6 font-medium text-gray-900 dark:text-white">
                Alert History
            </h3>
        </div>
        <div class="border-t border-gray-200 dark:border-gray-700">
            @livewire('alert-history-panel')
        </div>
    </div>

    <!-- Last Updated Timestamp -->
    <div class="text-center text-sm text-gray-500 dark:text-gray-400">
        Last updated: <span x-text="new Date('{{ $lastUpdated }}').toLocaleString()"></span>
        <span wire:loading class="ml-2">
            <svg class="animate-spin inline h-4 w-4 text-gray-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            Refreshing...
        </span>
    </div>
</div>

@push('scripts')
<script>
    // Listen for dashboard events
    document.addEventListener('livewire:initialized', () => {
        Livewire.on('dashboardUpdated', (event) => {
            console.log('Dashboard updated:', event);
        });

        Livewire.on('alert', (event) => {
            // Show toast notification
            showToast(event.type, event.title, event.message);
        });
    });

    function showToast(type, title, message) {
        // Simple toast notification (can be replaced with your preferred notification library)
        const color = type === 'critical' ? 'red' : type === 'warning' ? 'yellow' : 'blue';
        console.log(`[${type.toUpperCase()}] ${title}: ${message}`);
        // TODO: Implement actual toast UI
    }
</script>
@endpush
