<div class="space-y-4">
    <!-- Chart Controls -->
    <div class="flex flex-wrap items-center justify-between gap-4">
        <!-- Time Range Selector -->
        <div class="flex items-center space-x-2">
            <label class="text-sm font-medium text-gray-700 dark:text-gray-300">Time Range:</label>
            <select wire:model.live="hours" class="rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-700 text-sm">
                <option value="1">1 Hour</option>
                <option value="6">6 Hours</option>
                <option value="24">24 Hours</option>
                <option value="72">3 Days</option>
                <option value="168">7 Days</option>
            </select>
        </div>

        <!-- Chart Type Selector -->
        <div class="flex items-center space-x-2">
            <button wire:click="setChartType('line')"
                    class="px-3 py-1 text-sm rounded {{ $chartType === 'line' ? 'bg-blue-600 text-white' : 'bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300' }}">
                Line
            </button>
            <button wire:click="setChartType('area')"
                    class="px-3 py-1 text-sm rounded {{ $chartType === 'area' ? 'bg-blue-600 text-white' : 'bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300' }}">
                Area
            </button>
            <button wire:click="setChartType('bar')"
                    class="px-3 py-1 text-sm rounded {{ $chartType === 'bar' ? 'bg-blue-600 text-white' : 'bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300' }}">
                Bar
            </button>
        </div>

        <!-- Export Button -->
        <button wire:click="exportCsv" class="px-3 py-1 text-sm bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300 rounded hover:bg-gray-300 dark:hover:bg-gray-600">
            Export CSV
        </button>
    </div>

    <!-- Statistics -->
    @if (!empty($statistics) && $statistics['count'] > 0)
        <div class="grid grid-cols-2 md:grid-cols-5 gap-4">
            <div class="bg-gray-50 dark:bg-gray-900 rounded-lg p-3">
                <div class="text-xs text-gray-500 dark:text-gray-400">Min</div>
                <div class="text-lg font-semibold text-gray-900 dark:text-white">{{ $statistics['min'] }}%</div>
            </div>
            <div class="bg-gray-50 dark:bg-gray-900 rounded-lg p-3">
                <div class="text-xs text-gray-500 dark:text-gray-400">Max</div>
                <div class="text-lg font-semibold text-gray-900 dark:text-white">{{ $statistics['max'] }}%</div>
            </div>
            <div class="bg-gray-50 dark:bg-gray-900 rounded-lg p-3">
                <div class="text-xs text-gray-500 dark:text-gray-400">Avg</div>
                <div class="text-lg font-semibold text-gray-900 dark:text-white">{{ $statistics['avg'] }}%</div>
            </div>
            <div class="bg-gray-50 dark:bg-gray-900 rounded-lg p-3">
                <div class="text-xs text-gray-500 dark:text-gray-400">Current</div>
                <div class="text-lg font-semibold text-gray-900 dark:text-white">{{ $statistics['current'] }}%</div>
            </div>
            <div class="bg-gray-50 dark:bg-gray-900 rounded-lg p-3">
                <div class="text-xs text-gray-500 dark:text-gray-400">Trend</div>
                <div class="text-lg font-semibold {{ $statistics['trend'] === 'increasing' ? 'text-red-600' : ($statistics['trend'] === 'decreasing' ? 'text-green-600' : 'text-gray-600') }}">
                    {{ ucfirst($statistics['trend']) }}
                </div>
            </div>
        </div>
    @endif

    <!-- Chart Canvas -->
    <div class="relative" style="height: 300px;" wire:ignore>
        @if (!empty($chartData) && !isset($chartData['error']))
            <canvas id="trend-chart-{{ $metricType }}-{{ $metricName }}"
                    data-chart='@json($chartData)'
                    data-config='@json($chartConfig)'>
            </canvas>
        @else
            <div class="h-full flex items-center justify-center bg-gray-50 dark:bg-gray-900 rounded">
                <p class="text-gray-500 dark:text-gray-400">
                    {{ $chartData['error'] ?? 'No data available for this time range' }}
                </p>
            </div>
        @endif
    </div>
</div>

@push('scripts')
<script>
document.addEventListener('livewire:initialized', () => {
    // Initialize Chart.js for this component
    const canvas = document.getElementById('trend-chart-{{ $metricType }}-{{ $metricName }}');
    if (canvas && typeof Chart !== 'undefined') {
        try {
            const chartData = JSON.parse(canvas.dataset.chart);
            const chartConfig = JSON.parse(canvas.dataset.config);

            new Chart(canvas, {
                type: chartConfig.type,
                data: chartData,
                options: chartConfig.options
            });
        } catch (e) {
            console.error('Failed to initialize chart:', e);
        }
    }
});
</script>
@endpush
