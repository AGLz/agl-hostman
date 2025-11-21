<div class="space-y-4">
    <!-- View Toggle -->
    <div class="flex items-center justify-between">
        <h4 class="text-sm font-medium text-gray-700 dark:text-gray-300">
            {{ $showClusterView ? 'Cluster Forecasts' : 'Container Prediction' }}
        </h4>
        <button wire:click="toggleView"
                class="px-3 py-1 text-sm bg-blue-600 text-white rounded hover:bg-blue-700">
            {{ $showClusterView ? 'View Container' : 'View Cluster' }}
        </button>
    </div>

    @if ($loading)
        <div class="flex items-center justify-center py-12">
            <svg class="animate-spin h-8 w-8 text-blue-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
        </div>
    @elseif ($showClusterView)
        <!-- Cluster Forecasts View -->
        @if (!empty($clusterForecasts))
            <div class="space-y-3">
                @foreach ($clusterForecasts as $forecast)
                    <div class="bg-{{ $this->getPredictionSeverity($forecast['predicted_value'] ?? 0) === 'critical' ? 'red' : ($this->getPredictionSeverity($forecast['predicted_value'] ?? 0) === 'warning' ? 'yellow' : 'gray') }}-50 dark:bg-{{ $this->getPredictionSeverity($forecast['predicted_value'] ?? 0) === 'critical' ? 'red' : ($this->getPredictionSeverity($forecast['predicted_value'] ?? 0) === 'warning' ? 'yellow' : 'gray') }}-900 border border-{{ $this->getPredictionSeverity($forecast['predicted_value'] ?? 0) === 'critical' ? 'red' : ($this->getPredictionSeverity($forecast['predicted_value'] ?? 0) === 'warning' ? 'yellow' : 'gray') }}-200 dark:border-{{ $this->getPredictionSeverity($forecast['predicted_value'] ?? 0) === 'critical' ? 'red' : ($this->getPredictionSeverity($forecast['predicted_value'] ?? 0) === 'warning' ? 'yellow' : 'gray') }}-700 rounded-lg p-4">
                        <div class="flex items-center justify-between">
                            <div class="flex-1">
                                <h5 class="text-sm font-medium text-gray-900 dark:text-white">
                                    {{ $forecast['node'] ?? 'Unknown' }} - {{ $forecast['resource_type'] ?? 'N/A' }}
                                </h5>
                                <p class="text-xs text-gray-600 dark:text-gray-400 mt-1">
                                    VMID: {{ $forecast['vmid'] ?? 'N/A' }} | Horizon: {{ $this->getHorizonLabel($forecast['horizon'] ?? 'medium_term') }}
                                </p>
                            </div>
                            <div class="text-right">
                                <div class="text-2xl font-bold text-{{ $this->getPredictionSeverity($forecast['predicted_value'] ?? 0) === 'critical' ? 'red' : ($this->getPredictionSeverity($forecast['predicted_value'] ?? 0) === 'warning' ? 'yellow' : 'gray') }}-700 dark:text-{{ $this->getPredictionSeverity($forecast['predicted_value'] ?? 0) === 'critical' ? 'red' : ($this->getPredictionSeverity($forecast['predicted_value'] ?? 0) === 'warning' ? 'yellow' : 'gray') }}-300">
                                    {{ number_format($forecast['predicted_value'] ?? 0, 1) }}%
                                </div>
                                <div class="text-xs text-gray-600 dark:text-gray-400">
                                    Confidence: {{ number_format(($forecast['confidence'] ?? 0) * 100, 0) }}%
                                </div>
                            </div>
                        </div>
                        @if (isset($forecast['prediction']))
                            <div class="mt-2 text-sm text-gray-700 dark:text-gray-300">
                                {{ $this->getRecommendation($forecast['prediction']) }}
                            </div>
                        @endif
                    </div>
                @endforeach
            </div>
        @else
            <div class="text-center py-8 text-gray-500 dark:text-gray-400">
                No cluster forecasts available
            </div>
        @endif
    @else
        <!-- Container Prediction View -->
        @if (!empty($prediction) && !isset($prediction['error']))
            <div class="space-y-4">
                <!-- Controls -->
                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Resource Type</label>
                        <select wire:model.live="resourceType" class="w-full rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-700 text-sm">
                            <option value="cpu">CPU</option>
                            <option value="memory">Memory</option>
                            <option value="disk">Disk</option>
                        </select>
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Forecast Horizon</label>
                        <select wire:model.live="horizon" class="w-full rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-700 text-sm">
                            <option value="short_term">4 Hours</option>
                            <option value="medium_term">24 Hours</option>
                            <option value="long_term">7 Days</option>
                        </select>
                    </div>
                </div>

                <!-- Prediction Result -->
                <div class="bg-{{ $this->getConfidenceColor($prediction['confidence'] ?? 0) }}-50 dark:bg-{{ $this->getConfidenceColor($prediction['confidence'] ?? 0) }}-900 border-2 border-{{ $this->getConfidenceColor($prediction['confidence'] ?? 0) }}-200 dark:border-{{ $this->getConfidenceColor($prediction['confidence'] ?? 0) }}-700 rounded-lg p-6">
                    <div class="text-center mb-4">
                        <div class="text-5xl font-bold text-{{ $this->getConfidenceColor($prediction['confidence'] ?? 0) }}-700 dark:text-{{ $this->getConfidenceColor($prediction['confidence'] ?? 0) }}-300">
                            {{ number_format($prediction['predicted_value'] ?? 0, 1) }}%
                        </div>
                        <div class="text-sm text-gray-600 dark:text-gray-400 mt-2">
                            Predicted {{ $this->getResourceLabel($resourceType) }} Usage
                        </div>
                    </div>

                    <!-- Confidence Badge -->
                    <div class="flex items-center justify-center mb-4">
                        <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-{{ $this->getConfidenceColor($prediction['confidence'] ?? 0) }}-100 dark:bg-{{ $this->getConfidenceColor($prediction['confidence'] ?? 0) }}-800 text-{{ $this->getConfidenceColor($prediction['confidence'] ?? 0) }}-800 dark:text-{{ $this->getConfidenceColor($prediction['confidence'] ?? 0) }}-200">
                            {{ $this->getConfidenceText($prediction['confidence'] ?? 0) }}
                            ({{ number_format(($prediction['confidence'] ?? 0) * 100, 0) }}%)
                        </span>
                    </div>

                    <!-- Recommendation -->
                    <div class="bg-white dark:bg-gray-800 rounded-lg p-4 border border-{{ $this->getConfidenceColor($prediction['confidence'] ?? 0) }}-200 dark:border-{{ $this->getConfidenceColor($prediction['confidence'] ?? 0) }}-700">
                        <h5 class="text-sm font-medium text-gray-900 dark:text-white mb-2">Recommendation</h5>
                        <p class="text-sm text-gray-700 dark:text-gray-300">
                            {{ $this->getRecommendation($prediction) }}
                        </p>
                    </div>

                    <!-- Trend Analysis -->
                    @if (isset($prediction['trend_analysis']))
                        <div class="mt-4 grid grid-cols-3 gap-4 text-center">
                            <div>
                                <div class="text-xs text-gray-500 dark:text-gray-400">Trend Type</div>
                                <div class="text-sm font-medium text-gray-900 dark:text-white">
                                    {{ ucfirst($prediction['trend_analysis']['type'] ?? 'unknown') }}
                                </div>
                            </div>
                            <div>
                                <div class="text-xs text-gray-500 dark:text-gray-400">Rate</div>
                                <div class="text-sm font-medium text-gray-900 dark:text-white">
                                    {{ number_format($prediction['trend_analysis']['rate'] ?? 0, 4) }}/hr
                                </div>
                            </div>
                            <div>
                                <div class="text-xs text-gray-500 dark:text-gray-400">R-Squared</div>
                                <div class="text-sm font-medium text-gray-900 dark:text-white">
                                    {{ number_format($prediction['trend_analysis']['r_squared'] ?? 0, 3) }}
                                </div>
                            </div>
                        </div>
                    @endif
                </div>

                <!-- Export Button -->
                <div class="text-center">
                    <button wire:click="exportJson" class="px-4 py-2 text-sm bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300 rounded hover:bg-gray-300 dark:hover:bg-gray-600">
                        Export Prediction
                    </button>
                </div>
            </div>
        @else
            <div class="text-center py-8 text-gray-500 dark:text-gray-400">
                {{ $prediction['error'] ?? 'Select a container to view predictions' }}
            </div>
        @endif
    @endif
</div>
