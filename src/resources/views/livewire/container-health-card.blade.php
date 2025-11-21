<div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-gray-200 dark:border-gray-700 hover:shadow-md transition-shadow">
    @if (isset($containerData['error']))
        <div class="p-4">
            <div class="flex items-center text-gray-500 dark:text-gray-400">
                <svg class="h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <span class="text-sm">{{ $containerData['error'] }}</span>
            </div>
        </div>
    @else
        <!-- Container Header -->
        <div class="p-4 border-b border-gray-200 dark:border-gray-700">
            <div class="flex items-center justify-between">
                <div class="flex items-center space-x-3">
                    <!-- Health Status Icon -->
                    <div class="flex-shrink-0">
                        <span class="inline-flex items-center justify-center h-10 w-10 rounded-full bg-{{ $this->getSeverityColor($containerData['severity'] ?? 'info') }}-100 dark:bg-{{ $this->getSeverityColor($containerData['severity'] ?? 'info') }}-900">
                            <svg class="h-6 w-6 text-{{ $this->getSeverityColor($containerData['severity'] ?? 'info') }}-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                @if (($containerData['health_status'] ?? 'healthy') === 'healthy')
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                                @elseif (($containerData['health_status'] ?? 'healthy') === 'warning')
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                                @else
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                                @endif
                            </svg>
                        </span>
                    </div>

                    <!-- Container Info -->
                    <div class="flex-1 min-w-0">
                        <p class="text-sm font-medium text-gray-900 dark:text-white truncate">
                            {{ $containerData['name'] ?? 'Unknown' }}
                        </p>
                        <p class="text-sm text-gray-500 dark:text-gray-400">
                            VMID: {{ $vmid }}
                        </p>
                    </div>
                </div>

                <!-- Expand Button -->
                <button wire:click="toggleExpanded"
                        class="flex-shrink-0 p-1 rounded-full hover:bg-gray-100 dark:hover:bg-gray-700">
                    <svg class="h-5 w-5 text-gray-400 transform {{ $expanded ? 'rotate-180' : '' }} transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                    </svg>
                </button>
            </div>
        </div>

        <!-- Metrics -->
        <div class="p-4 space-y-3">
            @if (isset($containerData['metrics']))
                <!-- CPU -->
                <div>
                    <div class="flex justify-between text-sm mb-1">
                        <span class="text-gray-600 dark:text-gray-400">CPU</span>
                        <span class="font-medium text-gray-900 dark:text-white">
                            {{ $this->formatMetric($containerData['metrics']['cpu_percent'], 'percent') }}
                        </span>
                    </div>
                    <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2">
                        <div class="bg-blue-600 h-2 rounded-full transition-all" style="width: {{ min($containerData['metrics']['cpu_percent'], 100) }}%"></div>
                    </div>
                </div>

                <!-- Memory -->
                <div>
                    <div class="flex justify-between text-sm mb-1">
                        <span class="text-gray-600 dark:text-gray-400">Memory</span>
                        <span class="font-medium text-gray-900 dark:text-white">
                            {{ $this->formatMetric($containerData['metrics']['memory_percent'], 'percent') }}
                        </span>
                    </div>
                    <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2">
                        <div class="bg-green-600 h-2 rounded-full transition-all" style="width: {{ min($containerData['metrics']['memory_percent'], 100) }}%"></div>
                    </div>
                </div>

                <!-- Disk -->
                <div>
                    <div class="flex justify-between text-sm mb-1">
                        <span class="text-gray-600 dark:text-gray-400">Disk</span>
                        <span class="font-medium text-gray-900 dark:text-white">
                            {{ $this->formatMetric($containerData['metrics']['disk_percent'], 'percent') }}
                        </span>
                    </div>
                    <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2">
                        <div class="bg-orange-600 h-2 rounded-full transition-all" style="width: {{ min($containerData['metrics']['disk_percent'], 100) }}%"></div>
                    </div>
                </div>

                <!-- Uptime -->
                <div class="pt-2 border-t border-gray-200 dark:border-gray-700">
                    <div class="flex justify-between text-sm">
                        <span class="text-gray-600 dark:text-gray-400">Uptime</span>
                        <span class="font-medium text-gray-900 dark:text-white">
                            {{ $containerData['metrics']['uptime'] ?? 'N/A' }}
                        </span>
                    </div>
                </div>
            @endif
        </div>

        <!-- Issues (if any) -->
        @if (!empty($containerData['issues']))
            <div class="px-4 pb-4">
                <div class="bg-{{ $this->getSeverityColor($containerData['severity'] ?? 'info') }}-50 dark:bg-{{ $this->getSeverityColor($containerData['severity'] ?? 'info') }}-900 border-l-4 border-{{ $this->getSeverityColor($containerData['severity'] ?? 'info') }}-400 p-3">
                    <div class="flex">
                        <div class="flex-shrink-0">
                            <svg class="h-5 w-5 text-{{ $this->getSeverityColor($containerData['severity'] ?? 'info') }}-400" fill="currentColor" viewBox="0 0 20 20">
                                <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                            </svg>
                        </div>
                        <div class="ml-3">
                            <h3 class="text-sm font-medium text-{{ $this->getSeverityColor($containerData['severity'] ?? 'info') }}-800 dark:text-{{ $this->getSeverityColor($containerData['severity'] ?? 'info') }}-200">
                                Issues Detected
                            </h3>
                            <div class="mt-2 text-sm text-{{ $this->getSeverityColor($containerData['severity'] ?? 'info') }}-700 dark:text-{{ $this->getSeverityColor($containerData['severity'] ?? 'info') }}-300">
                                <ul class="list-disc list-inside space-y-1">
                                    @foreach ($containerData['issues'] as $issue)
                                        <li>{{ $issue }}</li>
                                    @endforeach
                                </ul>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        @endif

        <!-- Expanded View (History Chart) -->
        @if ($expanded)
            <div class="border-t border-gray-200 dark:border-gray-700 p-4">
                <div class="text-sm text-gray-600 dark:text-gray-400 mb-2">
                    24-Hour History
                </div>
                <!-- Placeholder for mini chart - would integrate with Chart.js -->
                <div class="h-32 bg-gray-100 dark:bg-gray-900 rounded flex items-center justify-center">
                    <span class="text-sm text-gray-500">Chart coming soon</span>
                </div>
            </div>
        @endif
    @endif
</div>
