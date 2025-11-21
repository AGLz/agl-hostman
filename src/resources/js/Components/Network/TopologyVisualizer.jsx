import React, { useRef, useState, useEffect } from 'react';
import { useNetworkGraph, useNetworkHealth, useNetworkIssues } from '../../hooks/useNetworkTopology';
import { useCytoscapeLayout } from '../../hooks/useCytoscapeLayout';
import NodeDetailsPanel from './NodeDetailsPanel';
import EdgeDetailsPanel from './EdgeDetailsPanel';
import NetworkHealthDashboard from './NetworkHealthDashboard';
import TopologyControls from './TopologyControls';

export default function TopologyVisualizer() {
    const containerRef = useRef(null);
    const [searchQuery, setSearchQuery] = useState('');
    const [filterType, setFilterType] = useState('all');
    const [filterStatus, setFilterStatus] = useState('all');
    const [filterNetwork, setFilterNetwork] = useState('all');

    // Fetch network data
    const { graph, loading: graphLoading, error: graphError, refetch: refetchGraph } = useNetworkGraph();
    const { health, loading: healthLoading } = useNetworkHealth();
    const { issues, loading: issuesLoading } = useNetworkIssues();

    // Cytoscape layout hook
    const {
        cy,
        selectedNode,
        selectedEdge,
        hoveredNode,
        layout,
        showLabels,
        showEdges,
        latencyHeatmap,
        changeLayout,
        setShowLabels,
        setShowEdges,
        setLatencyHeatmap,
        fitToViewport,
        centerOnNode,
        exportAsImage,
        searchNodes,
        updateGraphData,
    } = useCytoscapeLayout(containerRef, graph, {
        defaultLayout: 'cose-bilkent',
    });

    // Filter graph data based on current filters
    const filteredGraph = React.useMemo(() => {
        if (!graph) return null;

        let filteredNodes = graph.nodes;
        let filteredEdges = graph.edges;

        // Filter by type
        if (filterType !== 'all') {
            filteredNodes = filteredNodes.filter(node => node.type === filterType);
        }

        // Filter by status
        if (filterStatus !== 'all') {
            filteredNodes = filteredNodes.filter(node => node.status === filterStatus);
        }

        // Filter by network
        if (filterNetwork !== 'all') {
            filteredEdges = filteredEdges.filter(edge => edge.type === filterNetwork);
        }

        // Only show edges that connect visible nodes
        const visibleNodeIds = new Set(filteredNodes.map(n => n.id));
        filteredEdges = filteredEdges.filter(
            edge => visibleNodeIds.has(edge.source) && visibleNodeIds.has(edge.target)
        );

        return {
            nodes: filteredNodes,
            edges: filteredEdges,
            metadata: graph.metadata,
        };
    }, [graph, filterType, filterStatus, filterNetwork]);

    // Update graph when filtered data changes
    useEffect(() => {
        if (filteredGraph && cy) {
            updateGraphData(filteredGraph);
        }
    }, [filteredGraph, cy, updateGraphData]);

    // Handle search
    useEffect(() => {
        if (searchQuery) {
            const matches = searchNodes(searchQuery);
            if (matches.length > 0) {
                centerOnNode(matches[0].id);
            }
        } else {
            searchNodes('');
        }
    }, [searchQuery, searchNodes, centerOnNode]);

    // Handle export
    const handleExport = (format) => {
        const data = exportAsImage(format);
        if (!data) return;

        if (format === 'json') {
            const blob = new Blob([data], { type: 'application/json' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `network-topology-${Date.now()}.json`;
            a.click();
            URL.revokeObjectURL(url);
        } else if (format === 'png') {
            const a = document.createElement('a');
            a.href = data;
            a.download = `network-topology-${Date.now()}.png`;
            a.click();
        } else if (format === 'svg') {
            const blob = new Blob([data], { type: 'image/svg+xml' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `network-topology-${Date.now()}.svg`;
            a.click();
            URL.revokeObjectURL(url);
        }
    };

    if (graphLoading) {
        return (
            <div className="flex items-center justify-center h-screen bg-gray-900">
                <div className="text-center">
                    <div className="animate-spin rounded-full h-16 w-16 border-b-2 border-blue-500 mx-auto"></div>
                    <p className="mt-4 text-gray-300">Loading network topology...</p>
                </div>
            </div>
        );
    }

    if (graphError) {
        return (
            <div className="flex items-center justify-center h-screen bg-gray-900">
                <div className="text-center">
                    <div className="text-red-500 text-xl mb-4">Failed to load network topology</div>
                    <p className="text-gray-400">{graphError}</p>
                    <button
                        onClick={refetchGraph}
                        className="mt-4 px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
                    >
                        Retry
                    </button>
                </div>
            </div>
        );
    }

    return (
        <div className="h-screen flex flex-col bg-gray-900">
            {/* Network Health Dashboard */}
            <NetworkHealthDashboard
                health={health}
                issues={issues}
                loading={healthLoading || issuesLoading}
            />

            {/* Main Visualization Area */}
            <div className="flex-1 flex relative">
                {/* Cytoscape Container */}
                <div
                    ref={containerRef}
                    className="flex-1 bg-gray-800"
                    style={{ height: '100%' }}
                />

                {/* Controls Overlay */}
                <TopologyControls
                    layout={layout}
                    showLabels={showLabels}
                    showEdges={showEdges}
                    latencyHeatmap={latencyHeatmap}
                    filterType={filterType}
                    filterStatus={filterStatus}
                    filterNetwork={filterNetwork}
                    searchQuery={searchQuery}
                    onLayoutChange={changeLayout}
                    onShowLabelsChange={setShowLabels}
                    onShowEdgesChange={setShowEdges}
                    onLatencyHeatmapChange={setLatencyHeatmap}
                    onFilterTypeChange={setFilterType}
                    onFilterStatusChange={setFilterStatus}
                    onFilterNetworkChange={setFilterNetwork}
                    onSearchChange={setSearchQuery}
                    onFitToViewport={fitToViewport}
                    onExport={handleExport}
                    onRefresh={refetchGraph}
                />

                {/* Node Details Panel */}
                {selectedNode && (
                    <NodeDetailsPanel
                        node={selectedNode}
                        onClose={() => cy?.nodes().unselect()}
                    />
                )}

                {/* Edge Details Tooltip */}
                {selectedEdge && !selectedNode && (
                    <EdgeDetailsPanel
                        edge={selectedEdge}
                        onClose={() => cy?.edges().unselect()}
                    />
                )}

                {/* Hover Info */}
                {hoveredNode && !selectedNode && (
                    <div className="absolute bottom-4 left-4 bg-gray-800 border border-gray-700 rounded-lg p-4 shadow-lg max-w-sm">
                        <h3 className="text-white font-semibold">{hoveredNode.name}</h3>
                        <p className="text-gray-400 text-sm">{hoveredNode.type}</p>
                        {hoveredNode.ips && (
                            <div className="mt-2 text-xs text-gray-500">
                                {hoveredNode.ips.wireguard && (
                                    <div>WG: {hoveredNode.ips.wireguard}</div>
                                )}
                                {hoveredNode.ips.lan && (
                                    <div>LAN: {hoveredNode.ips.lan}</div>
                                )}
                            </div>
                        )}
                    </div>
                )}
            </div>

            {/* Legend */}
            <div className="bg-gray-800 border-t border-gray-700 px-4 py-2 flex items-center justify-between">
                <div className="flex items-center space-x-6 text-sm">
                    <div className="flex items-center">
                        <div className="w-4 h-4 rounded-full bg-purple-600 border-2 border-purple-400 mr-2"></div>
                        <span className="text-gray-300">Server</span>
                    </div>
                    <div className="flex items-center">
                        <div className="w-4 h-4 rounded-full bg-blue-600 border-2 border-blue-400 mr-2"></div>
                        <span className="text-gray-300">Container</span>
                    </div>
                    <div className="flex items-center">
                        <div className="w-4 h-4 bg-green-600 border-2 border-green-400 mr-2" style={{ clipPath: 'polygon(50% 0%, 100% 25%, 100% 75%, 50% 100%, 0% 75%, 0% 25%)' }}></div>
                        <span className="text-gray-300">Network Hub</span>
                    </div>
                    <div className="border-l border-gray-700 pl-6 flex items-center space-x-4">
                        <div className="flex items-center">
                            <div className="w-8 h-0.5 bg-green-500 mr-2"></div>
                            <span className="text-gray-300">WireGuard</span>
                        </div>
                        <div className="flex items-center">
                            <div className="w-8 h-0.5 bg-gray-500 mr-2 border-dashed border-b-2"></div>
                            <span className="text-gray-300">LAN</span>
                        </div>
                        <div className="flex items-center">
                            <div className="w-8 h-0.5 bg-blue-500 mr-2" style={{ backgroundImage: 'linear-gradient(to right, currentColor 50%, transparent 50%)', backgroundSize: '4px 2px' }}></div>
                            <span className="text-gray-300">Tailscale</span>
                        </div>
                    </div>
                    {latencyHeatmap && (
                        <div className="border-l border-gray-700 pl-6 flex items-center space-x-2">
                            <span className="text-gray-400 text-xs">Latency:</span>
                            <div className="flex items-center space-x-1">
                                <div className="w-3 h-3 bg-green-500"></div>
                                <span className="text-gray-500 text-xs">&lt;20ms</span>
                            </div>
                            <div className="flex items-center space-x-1">
                                <div className="w-3 h-3 bg-yellow-500"></div>
                                <span className="text-gray-500 text-xs">20-50ms</span>
                            </div>
                            <div className="flex items-center space-x-1">
                                <div className="w-3 h-3 bg-orange-500"></div>
                                <span className="text-gray-500 text-xs">50-100ms</span>
                            </div>
                            <div className="flex items-center space-x-1">
                                <div className="w-3 h-3 bg-red-500"></div>
                                <span className="text-gray-500 text-xs">&gt;100ms</span>
                            </div>
                        </div>
                    )}
                </div>
                <div className="text-xs text-gray-500">
                    Last updated: {graph?.metadata?.timestamp || 'Unknown'}
                </div>
            </div>
        </div>
    );
}
