import React, { useState } from 'react';
import {
    Search,
    Filter,
    Eye,
    EyeOff,
    Download,
    RefreshCw,
    Layout,
    Tag,
    Network,
    Maximize2,
} from 'lucide-react';

export default function TopologyControls({
    layout,
    showLabels,
    showEdges,
    latencyHeatmap,
    filterType,
    filterStatus,
    filterNetwork,
    searchQuery,
    onLayoutChange,
    onShowLabelsChange,
    onShowEdgesChange,
    onLatencyHeatmapChange,
    onFilterTypeChange,
    onFilterStatusChange,
    onFilterNetworkChange,
    onSearchChange,
    onFitToViewport,
    onExport,
    onRefresh,
}) {
    const [showFilters, setShowFilters] = useState(false);
    const [showExportMenu, setShowExportMenu] = useState(false);

    return (
        <div className="absolute top-4 left-4 flex flex-col space-y-2 z-10">
            {/* Search Bar */}
            <div className="bg-gray-800 border border-gray-700 rounded-lg shadow-lg p-2 flex items-center">
                <Search className="w-4 h-4 text-gray-400 mr-2" />
                <input
                    type="text"
                    placeholder="Search nodes (name, IP)..."
                    value={searchQuery}
                    onChange={(e) => onSearchChange(e.target.value)}
                    className="bg-transparent text-white text-sm outline-none w-64"
                />
                {searchQuery && (
                    <button
                        onClick={() => onSearchChange('')}
                        className="ml-2 text-gray-400 hover:text-white"
                    >
                        ×
                    </button>
                )}
            </div>

            {/* Main Controls */}
            <div className="bg-gray-800 border border-gray-700 rounded-lg shadow-lg p-2 flex items-center space-x-2">
                {/* Layout Selector */}
                <div className="relative group">
                    <button className="flex items-center px-3 py-2 hover:bg-gray-700 rounded transition-colors">
                        <Layout className="w-4 h-4 text-gray-300 mr-2" />
                        <span className="text-sm text-white">
                            {layout === 'cose-bilkent' ? 'Force' : layout === 'dagre' ? 'Tree' : layout === 'cola' ? 'Cola' : 'Circle'}
                        </span>
                    </button>
                    <div className="absolute left-0 mt-1 w-48 bg-gray-800 border border-gray-700 rounded-lg shadow-lg hidden group-hover:block">
                        <button
                            onClick={() => onLayoutChange('cose-bilkent')}
                            className={`w-full text-left px-4 py-2 text-sm ${
                                layout === 'cose-bilkent' ? 'bg-blue-600 text-white' : 'text-gray-300 hover:bg-gray-700'
                            }`}
                        >
                            Force-Directed (Cose)
                        </button>
                        <button
                            onClick={() => onLayoutChange('dagre')}
                            className={`w-full text-left px-4 py-2 text-sm ${
                                layout === 'dagre' ? 'bg-blue-600 text-white' : 'text-gray-300 hover:bg-gray-700'
                            }`}
                        >
                            Hierarchical (Tree)
                        </button>
                        <button
                            onClick={() => onLayoutChange('cola')}
                            className={`w-full text-left px-4 py-2 text-sm ${
                                layout === 'cola' ? 'bg-blue-600 text-white' : 'text-gray-300 hover:bg-gray-700'
                            }`}
                        >
                            Constrained (Cola)
                        </button>
                        <button
                            onClick={() => onLayoutChange('circle')}
                            className={`w-full text-left px-4 py-2 text-sm ${
                                layout === 'circle' ? 'bg-blue-600 text-white' : 'text-gray-300 hover:bg-gray-700'
                            }`}
                        >
                            Circular
                        </button>
                    </div>
                </div>

                <div className="w-px h-6 bg-gray-700"></div>

                {/* Toggle Labels */}
                <button
                    onClick={() => onShowLabelsChange(!showLabels)}
                    className={`p-2 rounded transition-colors ${
                        showLabels ? 'bg-blue-600 text-white' : 'hover:bg-gray-700 text-gray-400'
                    }`}
                    title="Toggle Labels"
                >
                    <Tag className="w-4 h-4" />
                </button>

                {/* Toggle Edges */}
                <button
                    onClick={() => onShowEdgesChange(!showEdges)}
                    className={`p-2 rounded transition-colors ${
                        showEdges ? 'bg-blue-600 text-white' : 'hover:bg-gray-700 text-gray-400'
                    }`}
                    title="Toggle Edges"
                >
                    <Network className="w-4 h-4" />
                </button>

                {/* Toggle Latency Heatmap */}
                <button
                    onClick={() => onLatencyHeatmapChange(!latencyHeatmap)}
                    className={`p-2 rounded transition-colors ${
                        latencyHeatmap ? 'bg-blue-600 text-white' : 'hover:bg-gray-700 text-gray-400'
                    }`}
                    title="Latency Heatmap"
                >
                    {latencyHeatmap ? <Eye className="w-4 h-4" /> : <EyeOff className="w-4 h-4" />}
                </button>

                <div className="w-px h-6 bg-gray-700"></div>

                {/* Filters */}
                <button
                    onClick={() => setShowFilters(!showFilters)}
                    className={`p-2 rounded transition-colors ${
                        showFilters ? 'bg-blue-600 text-white' : 'hover:bg-gray-700 text-gray-400'
                    }`}
                    title="Filters"
                >
                    <Filter className="w-4 h-4" />
                </button>

                {/* Fit to Viewport */}
                <button
                    onClick={onFitToViewport}
                    className="p-2 hover:bg-gray-700 rounded transition-colors text-gray-400"
                    title="Fit to Viewport"
                >
                    <Maximize2 className="w-4 h-4" />
                </button>

                {/* Refresh */}
                <button
                    onClick={onRefresh}
                    className="p-2 hover:bg-gray-700 rounded transition-colors text-gray-400"
                    title="Refresh"
                >
                    <RefreshCw className="w-4 h-4" />
                </button>

                <div className="w-px h-6 bg-gray-700"></div>

                {/* Export */}
                <div className="relative">
                    <button
                        onClick={() => setShowExportMenu(!showExportMenu)}
                        className="p-2 hover:bg-gray-700 rounded transition-colors text-gray-400"
                        title="Export"
                    >
                        <Download className="w-4 h-4" />
                    </button>
                    {showExportMenu && (
                        <div className="absolute right-0 mt-1 w-40 bg-gray-800 border border-gray-700 rounded-lg shadow-lg">
                            <button
                                onClick={() => {
                                    onExport('png');
                                    setShowExportMenu(false);
                                }}
                                className="w-full text-left px-4 py-2 text-sm text-gray-300 hover:bg-gray-700"
                            >
                                Export as PNG
                            </button>
                            <button
                                onClick={() => {
                                    onExport('svg');
                                    setShowExportMenu(false);
                                }}
                                className="w-full text-left px-4 py-2 text-sm text-gray-300 hover:bg-gray-700"
                            >
                                Export as SVG
                            </button>
                            <button
                                onClick={() => {
                                    onExport('json');
                                    setShowExportMenu(false);
                                }}
                                className="w-full text-left px-4 py-2 text-sm text-gray-300 hover:bg-gray-700"
                            >
                                Export as JSON
                            </button>
                        </div>
                    )}
                </div>
            </div>

            {/* Filters Panel */}
            {showFilters && (
                <div className="bg-gray-800 border border-gray-700 rounded-lg shadow-lg p-3 w-80">
                    <h3 className="text-white font-semibold mb-3">Filters</h3>

                    {/* Filter by Type */}
                    <div className="mb-3">
                        <label className="text-gray-400 text-xs mb-1 block">Node Type</label>
                        <select
                            value={filterType}
                            onChange={(e) => onFilterTypeChange(e.target.value)}
                            className="w-full bg-gray-700 border border-gray-600 text-white text-sm rounded px-3 py-2 outline-none"
                        >
                            <option value="all">All Types</option>
                            <option value="server">Servers</option>
                            <option value="container">Containers</option>
                            <option value="network">Network Devices</option>
                        </select>
                    </div>

                    {/* Filter by Status */}
                    <div className="mb-3">
                        <label className="text-gray-400 text-xs mb-1 block">Status</label>
                        <select
                            value={filterStatus}
                            onChange={(e) => onFilterStatusChange(e.target.value)}
                            className="w-full bg-gray-700 border border-gray-600 text-white text-sm rounded px-3 py-2 outline-none"
                        >
                            <option value="all">All Status</option>
                            <option value="online">Online</option>
                            <option value="offline">Offline</option>
                            <option value="degraded">Degraded</option>
                        </select>
                    </div>

                    {/* Filter by Network */}
                    <div>
                        <label className="text-gray-400 text-xs mb-1 block">Network Type</label>
                        <select
                            value={filterNetwork}
                            onChange={(e) => onFilterNetworkChange(e.target.value)}
                            className="w-full bg-gray-700 border border-gray-600 text-white text-sm rounded px-3 py-2 outline-none"
                        >
                            <option value="all">All Networks</option>
                            <option value="wireguard">WireGuard</option>
                            <option value="lan">LAN</option>
                            <option value="tailscale">Tailscale</option>
                        </select>
                    </div>

                    {/* Reset Filters */}
                    <button
                        onClick={() => {
                            onFilterTypeChange('all');
                            onFilterStatusChange('all');
                            onFilterNetworkChange('all');
                        }}
                        className="w-full mt-3 px-3 py-2 bg-gray-700 hover:bg-gray-600 text-white text-sm rounded transition-colors"
                    >
                        Reset Filters
                    </button>
                </div>
            )}
        </div>
    );
}
