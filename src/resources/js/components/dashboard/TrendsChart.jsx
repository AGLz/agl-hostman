import React, { useState, useEffect, useMemo } from 'react';
import {
  LineChart,
  Line,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
  ReferenceLine,
} from 'recharts';
import { Calendar, TrendingUp, AlertTriangle } from 'lucide-react';

/**
 * TrendsChart Component
 *
 * Historical trend visualization with customizable date ranges and anomaly detection.
 *
 * @param {Object} props - Component props
 * @param {Array} props.data - Time-series data points
 * @param {String} props.metric - Metric being displayed
 * @param {String} props.chartType - Type of chart ('line' or 'bar')
 * @param {String} props.aggregation - Aggregation method ('avg', 'max', 'min', 'sum')
 * @param {Boolean} props.showAnomalies - Whether to highlight anomalies
 * @param {Function} props.onDataPointClick - Callback when clicking a data point
 */
export default function TrendsChart({
  data = [],
  metric = 'cpu_usage',
  chartType = 'line',
  aggregation = 'avg',
  showAnomalies = true,
  onDataPointClick,
}) {
  const [dateRange, setDateRange] = useState('7d');
  const [comparisonMode, setComparisonMode] = useState(false);
  const [processedData, setProcessedData] = useState([]);
  const [anomalies, setAnomalies] = useState([]);

  // Date range presets
  const dateRanges = [
    { id: '1h', label: 'Last Hour', hours: 1 },
    { id: '24h', label: 'Last 24 Hours', hours: 24 },
    { id: '7d', label: 'Last 7 Days', days: 7 },
    { id: '30d', label: 'Last 30 Days', days: 30 },
    { id: 'custom', label: 'Custom Range' },
  ];

  // Aggregate data based on selected range
  useEffect(() => {
    if (!data || data.length === 0) return;

    const aggregated = aggregateData(data, dateRange, aggregation);
    setProcessedData(aggregated);

    if (showAnomalies) {
      const detectedAnomalies = detectAnomalies(aggregated);
      setAnomalies(detectedAnomalies);
    }
  }, [data, dateRange, aggregation, showAnomalies]);

  // Aggregate raw data by time period
  const aggregateData = (rawData, range, method) => {
    const grouped = {};

    rawData.forEach((point) => {
      const timestamp = new Date(point.timestamp);
      const key = getGroupingKey(timestamp, range);

      if (!grouped[key]) {
        grouped[key] = [];
      }

      grouped[key].push(point.value);
    });

    // Calculate aggregation
    return Object.entries(grouped).map(([key, values]) => {
      const aggregatedValue = calculateAggregation(values, method);
      return {
        timestamp: key,
        value: aggregatedValue,
        originalValues: values,
      };
    }).sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));
  };

  // Get grouping key based on date range
  const getGroupingKey = (date, range) => {
    if (range === '1h') {
      return date.toISOString().substring(0, 16); // Minute precision
    } else if (range === '24h') {
      return date.toISOString().substring(0, 13); // Hour precision
    } else if (range === '7d' || range === '30d') {
      return date.toISOString().substring(0, 10); // Day precision
    }
    return date.toISOString().substring(0, 10);
  };

  // Calculate aggregation method
  const calculateAggregation = (values, method) => {
    switch (method) {
      case 'avg':
        return values.reduce((sum, val) => sum + val, 0) / values.length;
      case 'max':
        return Math.max(...values);
      case 'min':
        return Math.min(...values);
      case 'sum':
        return values.reduce((sum, val) => sum + val, 0);
      case 'p95':
        return percentile(values, 95);
      default:
        return values[0];
    }
  };

  // Calculate percentile
  const percentile = (arr, p) => {
    const sorted = [...arr].sort((a, b) => a - b);
    const index = Math.ceil((p / 100) * sorted.length) - 1;
    return sorted[index];
  };

  // Detect anomalies using statistical methods
  const detectAnomalies = (data) => {
    if (data.length < 5) return [];

    const values = data.map((d) => d.value);
    const mean = values.reduce((sum, val) => sum + val, 0) / values.length;
    const stdDev = Math.sqrt(
      values.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / values.length
    );

    // Detect points beyond 2 standard deviations
    return data
      .map((point, index) => ({
        ...point,
        zScore: Math.abs((point.value - mean) / stdDev),
      }))
      .filter((point) => point.zScore > 2)
      .map((point) => ({
        timestamp: point.timestamp,
        value: point.value,
        expected: mean,
        deviation: point.value - mean,
      }));
  };

  // Chart colors based on metric
  const getColor = () => {
    const colors = {
      cpu_usage: '#3b82f6',
      memory_usage: '#10b981',
      disk_usage: '#f59e0b',
      network_io: '#8b5cf6',
    };
    return colors[metric] || '#6b7280';
  };

  // Custom tooltip
  const CustomTooltip = ({ active, payload, label }) => {
    if (!active || !payload || !payload.length) return null;

    const data = payload[0].payload;

    return (
      <div className="bg-white dark:bg-gray-800 p-3 rounded border shadow-lg">
        <p className="text-sm font-medium">{label}</p>
        <p className="text-lg font-bold">{data.value?.toFixed(2)}%</p>
        {data.originalValues && (
          <p className="text-xs text-gray-500 mt-1">
            Based on {data.originalValues.length} data points
          </p>
        )}
      </div>
    );
  };

  return (
    <div className="trends-chart bg-white dark:bg-gray-800 rounded-lg shadow p-6">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-4 mb-6">
        <div className="flex items-center space-x-2">
          <TrendingUp className="w-5 h-5 text-gray-600 dark:text-gray-400" />
          <h3 className="text-lg font-semibold">Historical Trends</h3>
        </div>

        <div className="flex items-center space-x-2">
          {/* Date Range Selector */}
          <div className="flex items-center space-x-1">
            {dateRanges.map((range) => (
              <button
                key={range.id}
                onClick={() => setDateRange(range.id)}
                className={`px-3 py-1 text-sm rounded ${
                  dateRange === range.id
                    ? 'bg-blue-600 text-white'
                    : 'bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600'
                }`}
              >
                {range.label}
              </button>
            ))}
          </div>

          {/* Aggregation Selector */}
          <select
            value={aggregation}
            onChange={(e) => setAggregation(e.target.value)}
            className="px-3 py-1 text-sm border rounded dark:bg-gray-700 dark:border-gray-600"
          >
            <option value="avg">Average</option>
            <option value="max">Maximum</option>
            <option value="min">Minimum</option>
            <option value="p95">95th Percentile</option>
          </select>

          {/* Comparison Mode Toggle */}
          {dateRange !== '1h' && (
            <button
              onClick={() => setComparisonMode(!comparisonMode)}
              className={`px-3 py-1 text-sm rounded ${
                comparisonMode
                  ? 'bg-purple-600 text-white'
                  : 'bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600'
              }`}
            >
              {comparisonMode ? 'Comparing' : 'Compare Periods'}
            </button>
          )}

          {/* Chart Type Toggle */}
          <select
            value={chartType}
            onChange={(e) => setChartType(e.target.value)}
            className="px-3 py-1 text-sm border rounded dark:bg-gray-700 dark:border-gray-600"
          >
            <option value="line">Line Chart</option>
            <option value="bar">Bar Chart</option>
          </select>
        </div>
      </div>

      {/* Anomaly Warning */}
      {anomalies.length > 0 && (
        <div className="mb-4 p-3 bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded flex items-start space-x-2">
          <AlertTriangle className="w-5 h-5 text-yellow-600 dark:text-yellow-500 mt-0.5" />
          <div>
            <p className="font-medium text-sm">Anomalies Detected</p>
            <p className="text-xs text-gray-600 dark:text-gray-400">
              Found {anomalies.length} unusual data points outside normal range
            </p>
          </div>
        </div>
      )}

      {/* Chart */}
      <div className="h-80">
        {processedData.length > 0 ? (
          <ResponsiveContainer width="100%" height="100%">
            {chartType === 'line' ? (
              <LineChart data={processedData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
                <XAxis
                  dataKey="timestamp"
                  stroke="#6b7280"
                  tickFormatter={(str) => {
                    const date = new Date(str);
                    if (dateRange === '1h') return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
                    if (dateRange === '24h') return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
                    return date.toLocaleDateString([], { month: 'short', day: 'numeric' });
                  }}
                />
                <YAxis
                  stroke="#6b7280"
                  tickFormatter={(value) => `${value.toFixed(1)}%`}
                />
                <Tooltip content={<CustomTooltip />} />
                <Legend />
                <Line
                  type="monotone"
                  dataKey="value"
                  stroke={getColor()}
                  strokeWidth={2}
                  dot={{ r: 4 }}
                  activeDot={{ r: 6 }}
                  onClick={(data) => onDataPointClick && onDataPointClick(data)}
                />
                {showAnomalies &&
                  anomalies.map((anomaly, index) => (
                    <ReferenceLine
                      key={index}
                      x={anomaly.timestamp}
                      stroke="#ef4444"
                      strokeDasharray="3 3"
                      label="Anomaly"
                    />
                  ))}
              </LineChart>
            ) : (
              <BarChart data={processedData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
                <XAxis
                  dataKey="timestamp"
                  stroke="#6b7280"
                  tickFormatter={(str) => {
                    const date = new Date(str);
                    return date.toLocaleDateString([], { month: 'short', day: 'numeric' });
                  }}
                />
                <YAxis tickFormatter={(value) => `${value.toFixed(1)}%`} />
                <Tooltip content={<CustomTooltip />} />
                <Legend />
                <Bar dataKey="value" fill={getColor()} onClick={(data) => onDataPointClick && onDataPointClick(data)} />
              </BarChart>
            )}
          </ResponsiveContainer>
        ) : (
          <div className="h-full flex items-center justify-center text-gray-500">
            <div className="text-center">
              <Calendar className="w-12 h-12 mx-auto mb-2 opacity-50" />
              <p>No data available for selected range</p>
            </div>
          </div>
        )}
      </div>

      {/* Anomalies List */}
      {showAnomalies && anomalies.length > 0 && (
        <div className="mt-4 border-t dark:border-gray-700 pt-4">
          <h4 className="text-sm font-medium mb-2">Anomalies</h4>
          <div className="space-y-2 max-h-40 overflow-y-auto">
            {anomalies.map((anomaly, index) => (
              <div
                key={index}
                className="flex items-center justify-between text-xs p-2 bg-red-50 dark:bg-red-900/20 rounded"
              >
                <span>{new Date(anomaly.timestamp).toLocaleString()}</span>
                <span className="font-mono">
                  {anomaly.value.toFixed(2)}% (expected: {anomaly.expected.toFixed(2)}%)
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Statistics */}
      {processedData.length > 0 && (
        <div className="mt-4 grid grid-cols-4 gap-4 border-t dark:border-gray-700 pt-4">
          <div>
            <p className="text-xs text-gray-500">Average</p>
            <p className="text-lg font-semibold">
              {calculateAggregation(processedData.map((d) => d.value), 'avg').toFixed(2)}%
            </p>
          </div>
          <div>
            <p className="text-xs text-gray-500">Peak</p>
            <p className="text-lg font-semibold">
              {calculateAggregation(processedData.map((d) => d.value), 'max').toFixed(2)}%
            </p>
          </div>
          <div>
            <p className="text-xs text-gray-500">Lowest</p>
            <p className="text-lg font-semibold">
              {calculateAggregation(processedData.map((d) => d.value), 'min').toFixed(2)}%
            </p>
          </div>
          <div>
            <p className="text-xs text-gray-500">95th Percentile</p>
            <p className="text-lg font-semibold">
              {calculateAggregation(processedData.map((d) => d.value), 'p95').toFixed(2)}%
            </p>
          </div>
        </div>
      )}
    </div>
  );
}
