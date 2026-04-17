import React, { useState, useEffect, useRef } from 'react';
import { useDeploymentLogs } from '@/hooks/useDeploymentLogs';
import { Download, Pause, Play, Filter, Search, Maximize2, Minimize2 } from 'lucide-react';

const logLevels = {
    info: { color: 'text-blue-600', bg: 'bg-blue-50 dark:bg-blue-900/20' },
    warn: { color: 'text-yellow-600', bg: 'bg-yellow-50 dark:bg-yellow-900/20' },
    error: { color: 'text-red-600', bg: 'bg-red-50 dark:bg-red-900/20' },
    debug: { color: 'text-gray-600', bg: 'bg-gray-50 dark:bg-gray-900/20' },
};

export default function DeploymentLogs({ applicationId }) {
    const { logs, isConnected, error } = useDeploymentLogs(applicationId);
    const [isPaused, setIsPaused] = useState(false);
    const [searchQuery, setSearchQuery] = useState('');
    const [levelFilter, setLevelFilter] = useState('all');
    const [isFullscreen, setIsFullscreen] = useState(false);
    const logsEndRef = useRef(null);
    const logsContainerRef = useRef(null);

    const scrollToBottom = () => {
        if (!isPaused && logsEndRef.current) {
            logsEndRef.current.scrollIntoView({ behavior: 'smooth' });
        }
    };

    useEffect(() => {
        scrollToBottom();
    }, [logs, isPaused]);

    const filteredLogs = logs.filter(log => {
        // Search filter
        if (searchQuery && !log.message.toLowerCase().includes(searchQuery.toLowerCase())) {
            return false;
        }

        // Level filter
        if (levelFilter !== 'all' && log.level !== levelFilter) {
            return false;
        }

        return true;
    });

    const downloadLogs = () => {
        const logText = logs.map(log =>
            `[${new Date(log.timestamp).toISOString()}] [${log.level.toUpperCase()}] ${log.message}`
        ).join('\n');

        const blob = new Blob([logText], { type: 'text/plain' });
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `deployment-logs-${applicationId}-${Date.now()}.txt`;
        a.click();
    };

    const parseAnsiColors = (text) => {
        // Simple ANSI color code parser
        const ansiRegex = /\x1b\[(\d+)m/g;
        const colorMap = {
            '30': 'text-gray-900',
            '31': 'text-red-600',
            '32': 'text-green-600',
            '33': 'text-yellow-600',
            '34': 'text-blue-600',
            '35': 'text-purple-600',
            '36': 'text-cyan-600',
            '37': 'text-gray-100',
        };

        return text.replace(ansiRegex, (match, code) => {
            const colorClass = colorMap[code] || '';
            return `<span class="${colorClass}">`;
        }) + '</span>';
    };

    return (
        <div className={`flex flex-col ${isFullscreen ? 'fixed inset-0 z-50 bg-gray-900' : 'h-[600px]'}`}>
            {/* Controls */}
            <div className="flex items-center justify-between p-4 bg-gray-100 dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700">
                <div className="flex items-center gap-4">
                    {/* Status Indicator */}
                    <div className="flex items-center gap-2">
                        <div className={`w-2 h-2 rounded-full ${isConnected ? 'bg-green-500 animate-pulse' : 'bg-red-500'}`} />
                        <span className="text-sm text-gray-600 dark:text-gray-400">
                            {isConnected ? 'Live' : 'Disconnected'}
                        </span>
                    </div>

                    {/* Pause/Play */}
                    <button
                        onClick={() => setIsPaused(!isPaused)}
                        className="p-2 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700 transition"
                        title={isPaused ? 'Resume auto-scroll' : 'Pause auto-scroll'}
                    >
                        {isPaused ? (
                            <Play className="w-4 h-4 text-gray-600 dark:text-gray-400" />
                        ) : (
                            <Pause className="w-4 h-4 text-gray-600 dark:text-gray-400" />
                        )}
                    </button>

                    {/* Search */}
                    <div className="relative">
                        <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
                        <input
                            type="text"
                            placeholder="Search logs..."
                            value={searchQuery}
                            onChange={(e) => setSearchQuery(e.target.value)}
                            className="pl-9 pr-4 py-1.5 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500"
                        />
                    </div>

                    {/* Level Filter */}
                    <div className="flex items-center gap-2">
                        <Filter className="w-4 h-4 text-gray-400" />
                        <select
                            value={levelFilter}
                            onChange={(e) => setLevelFilter(e.target.value)}
                            className="px-3 py-1.5 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500"
                        >
                            <option value="all">All Levels</option>
                            <option value="info">Info</option>
                            <option value="warn">Warning</option>
                            <option value="error">Error</option>
                            <option value="debug">Debug</option>
                        </select>
                    </div>
                </div>

                <div className="flex items-center gap-2">
                    <span className="text-sm text-gray-500 dark:text-gray-400">
                        {filteredLogs.length} lines
                    </span>
                    <button
                        onClick={downloadLogs}
                        className="flex items-center gap-2 px-3 py-1.5 text-sm border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700 transition"
                    >
                        <Download className="w-4 h-4" />
                        Download
                    </button>
                    <button
                        onClick={() => setIsFullscreen(!isFullscreen)}
                        className="p-2 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700 transition"
                    >
                        {isFullscreen ? (
                            <Minimize2 className="w-4 h-4" />
                        ) : (
                            <Maximize2 className="w-4 h-4" />
                        )}
                    </button>
                </div>
            </div>

            {/* Logs Container */}
            <div
                ref={logsContainerRef}
                className="flex-1 overflow-y-auto bg-gray-900 text-gray-100 p-4 font-mono text-sm"
            >
                {error && (
                    <div className="mb-4 p-4 bg-red-900/20 border border-red-500 rounded-lg text-red-300">
                        Error: {error}
                    </div>
                )}

                {filteredLogs.length === 0 ? (
                    <div className="text-center py-12 text-gray-500">
                        {logs.length === 0 ? 'No logs available yet' : 'No logs match the current filters'}
                    </div>
                ) : (
                    <div className="space-y-1">
                        {filteredLogs.map((log, index) => {
                            const levelStyle = logLevels[log.level] || logLevels.info;

                            return (
                                <div
                                    key={index}
                                    className={`flex gap-3 px-2 py-1 rounded ${levelStyle.bg}`}
                                >
                                    <span className="text-gray-500 flex-shrink-0">
                                        {new Date(log.timestamp).toLocaleTimeString()}
                                    </span>
                                    <span className={`font-semibold flex-shrink-0 uppercase ${levelStyle.color}`}>
                                        [{log.level}]
                                    </span>
                                    <span
                                        className="flex-1 whitespace-pre-wrap break-all"
                                        dangerouslySetInnerHTML={{ __html: parseAnsiColors(log.message) }}
                                    />
                                </div>
                            );
                        })}
                        <div ref={logsEndRef} />
                    </div>
                )}
            </div>

            {/* Footer */}
            <div className="p-2 bg-gray-100 dark:bg-gray-800 border-t border-gray-200 dark:border-gray-700 text-xs text-gray-500 dark:text-gray-400 text-center">
                {isPaused && (
                    <span className="text-yellow-600 dark:text-yellow-400 font-medium">
                        Auto-scroll paused - Click play to resume
                    </span>
                )}
            </div>
        </div>
    );
}
