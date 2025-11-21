import React, { useEffect, useRef, useState, useCallback } from 'react';
import * as d3 from 'd3';
import { ZoomIn, ZoomOut, Maximize, RefreshCw } from 'lucide-react';

/**
 * Network Topology Visualization Component
 *
 * Interactive D3.js-powered network topology visualization.
 * Features:
 * - Force-directed graph layout
 * - Node clustering by location/type
 * - Interactive zoom and pan
 * - Real-time updates
 * - Connection status indicators
 * - Custom node styling by type
 *
 * @component
 */
const NetworkTopologyVisualization = ({
    width = 1200,
    height = 800,
    refreshInterval = 60000,
}) => {
    const svgRef = useRef(null);
    const [topology, setTopology] = useState({ nodes: [], links: [] });
    const [selectedNode, setSelectedNode] = useState(null);
    const [simulation, setSimulation] = useState(null);
    const [loading, setLoading] = useState(true);

    /**
     * Fetch topology data from API
     */
    const fetchTopology = useCallback(async () => {
        try {
            const response = await fetch('/api/network/topology');
            const data = await response.json();

            setTopology({
                nodes: data.data.nodes || [],
                links: data.data.links || [],
            });
            setLoading(false);
        } catch (error) {
            console.error('Failed to fetch topology:', error);
            setLoading(false);
        }
    }, []);

    /**
     * Initialize and update D3 visualization
     */
    useEffect(() => {
        if (!svgRef.current || topology.nodes.length === 0) return;

        const svg = d3.select(svgRef.current);
        svg.selectAll('*').remove();

        // Create main group for zooming/panning
        const g = svg.append('g');

        // Setup zoom behavior
        const zoom = d3.zoom()
            .scaleExtent([0.1, 4])
            .on('zoom', (event) => {
                g.attr('transform', event.transform);
            });

        svg.call(zoom);

        // Define arrow markers for links
        svg.append('defs').selectAll('marker')
            .data(['end'])
            .enter().append('marker')
            .attr('id', 'arrow')
            .attr('viewBox', '0 -5 10 10')
            .attr('refX', 20)
            .attr('refY', 0)
            .attr('markerWidth', 6)
            .attr('markerHeight', 6)
            .attr('orient', 'auto')
            .append('path')
            .attr('d', 'M0,-5L10,0L0,5')
            .attr('fill', '#999');

        // Create force simulation
        const sim = d3.forceSimulation(topology.nodes)
            .force('link', d3.forceLink(topology.links)
                .id(d => d.id)
                .distance(150))
            .force('charge', d3.forceManyBody().strength(-300))
            .force('center', d3.forceCenter(width / 2, height / 2))
            .force('collision', d3.forceCollide().radius(50));

        // Create links
        const link = g.append('g')
            .attr('class', 'links')
            .selectAll('line')
            .data(topology.links)
            .enter().append('line')
            .attr('stroke', d => getLinkColor(d))
            .attr('stroke-width', d => d.bandwidth ? Math.max(1, Math.log(d.bandwidth)) : 2)
            .attr('stroke-opacity', 0.6)
            .attr('marker-end', 'url(#arrow)');

        // Create link labels
        const linkLabel = g.append('g')
            .attr('class', 'link-labels')
            .selectAll('text')
            .data(topology.links)
            .enter().append('text')
            .attr('font-size', 10)
            .attr('fill', '#666')
            .attr('text-anchor', 'middle')
            .text(d => d.label || '');

        // Create node groups
        const node = g.append('g')
            .attr('class', 'nodes')
            .selectAll('g')
            .data(topology.nodes)
            .enter().append('g')
            .attr('class', 'node')
            .call(d3.drag()
                .on('start', dragStarted)
                .on('drag', dragging)
                .on('end', dragEnded))
            .on('click', (event, d) => {
                event.stopPropagation();
                setSelectedNode(d);
            });

        // Add circles to nodes
        node.append('circle')
            .attr('r', d => getNodeRadius(d))
            .attr('fill', d => getNodeColor(d))
            .attr('stroke', d => d.status === 'offline' ? '#ef4444' : '#10b981')
            .attr('stroke-width', 3);

        // Add status indicators
        node.append('circle')
            .attr('r', 4)
            .attr('cx', 15)
            .attr('cy', -15)
            .attr('fill', d => d.status === 'online' ? '#10b981' : '#ef4444')
            .attr('stroke', '#fff')
            .attr('stroke-width', 2);

        // Add icons/labels
        node.append('text')
            .attr('dy', 5)
            .attr('font-size', 20)
            .attr('text-anchor', 'middle')
            .text(d => getNodeIcon(d));

        // Add node labels
        node.append('text')
            .attr('dy', 35)
            .attr('font-size', 12)
            .attr('text-anchor', 'middle')
            .attr('fill', '#374151')
            .attr('font-weight', 'bold')
            .text(d => d.name);

        // Add node type labels
        node.append('text')
            .attr('dy', 48)
            .attr('font-size', 10)
            .attr('text-anchor', 'middle')
            .attr('fill', '#6b7280')
            .text(d => d.type);

        // Tooltip
        const tooltip = d3.select('body').append('div')
            .attr('class', 'topology-tooltip')
            .style('position', 'absolute')
            .style('visibility', 'hidden')
            .style('background-color', 'rgba(0, 0, 0, 0.8)')
            .style('color', '#fff')
            .style('padding', '10px')
            .style('border-radius', '4px')
            .style('font-size', '12px')
            .style('pointer-events', 'none')
            .style('z-index', '1000');

        node.on('mouseenter', (event, d) => {
            tooltip.html(getTooltipContent(d))
                .style('visibility', 'visible');
        })
        .on('mousemove', (event) => {
            tooltip.style('top', (event.pageY - 10) + 'px')
                .style('left', (event.pageX + 10) + 'px');
        })
        .on('mouseleave', () => {
            tooltip.style('visibility', 'hidden');
        });

        // Update positions on simulation tick
        sim.on('tick', () => {
            link
                .attr('x1', d => d.source.x)
                .attr('y1', d => d.source.y)
                .attr('x2', d => d.target.x)
                .attr('y2', d => d.target.y);

            linkLabel
                .attr('x', d => (d.source.x + d.target.x) / 2)
                .attr('y', d => (d.source.y + d.target.y) / 2);

            node.attr('transform', d => `translate(${d.x},${d.y})`);
        });

        setSimulation(sim);

        // Drag functions
        function dragStarted(event, d) {
            if (!event.active) sim.alphaTarget(0.3).restart();
            d.fx = d.x;
            d.fy = d.y;
        }

        function dragging(event, d) {
            d.fx = event.x;
            d.fy = event.y;
        }

        function dragEnded(event, d) {
            if (!event.active) sim.alphaTarget(0);
            d.fx = null;
            d.fy = null;
        }

        // Cleanup
        return () => {
            sim.stop();
            tooltip.remove();
        };
    }, [topology, width, height]);

    /**
     * Auto-refresh topology
     */
    useEffect(() => {
        fetchTopology();
        const interval = setInterval(fetchTopology, refreshInterval);
        return () => clearInterval(interval);
    }, [fetchTopology, refreshInterval]);

    /**
     * Get node color based on type
     */
    const getNodeColor = (node) => {
        const colors = {
            'server': '#3b82f6',
            'container': '#8b5cf6',
            'switch': '#10b981',
            'router': '#f59e0b',
            'firewall': '#ef4444',
            'storage': '#14b8a6',
            'gateway': '#ec4899',
        };
        return colors[node.type] || '#6b7280';
    };

    /**
     * Get node radius based on importance/size
     */
    const getNodeRadius = (node) => {
        if (node.type === 'server') return 25;
        if (node.type === 'container') return 20;
        return 22;
    };

    /**
     * Get node icon (emoji for simplicity, can be replaced with SVG)
     */
    const getNodeIcon = (node) => {
        const icons = {
            'server': '🖥️',
            'container': '📦',
            'switch': '🔀',
            'router': '📡',
            'firewall': '🛡️',
            'storage': '💾',
            'gateway': '🚪',
        };
        return icons[node.type] || '⚫';
    };

    /**
     * Get link color based on status
     */
    const getLinkColor = (link) => {
        if (link.status === 'active') return '#10b981';
        if (link.status === 'degraded') return '#f59e0b';
        if (link.status === 'down') return '#ef4444';
        return '#9ca3af';
    };

    /**
     * Generate tooltip content
     */
    const getTooltipContent = (node) => {
        return `
            <strong>${node.name}</strong><br/>
            Type: ${node.type}<br/>
            Status: ${node.status}<br/>
            ${node.ip ? `IP: ${node.ip}<br/>` : ''}
            ${node.location ? `Location: ${node.location}<br/>` : ''}
            ${node.containers ? `Containers: ${node.containers}<br/>` : ''}
        `;
    };

    /**
     * Zoom controls
     */
    const handleZoomIn = () => {
        const svg = d3.select(svgRef.current);
        svg.transition().call(
            d3.zoom().scaleBy,
            1.3
        );
    };

    const handleZoomOut = () => {
        const svg = d3.select(svgRef.current);
        svg.transition().call(
            d3.zoom().scaleBy,
            0.7
        );
    };

    const handleReset = () => {
        const svg = d3.select(svgRef.current);
        svg.transition().call(
            d3.zoom().transform,
            d3.zoomIdentity
        );
    };

    if (loading) {
        return (
            <div className="flex items-center justify-center h-full">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
            </div>
        );
    }

    return (
        <div className="relative bg-white rounded-lg shadow-sm border border-gray-200">
            {/* Controls */}
            <div className="absolute top-4 right-4 z-10 flex gap-2">
                <button
                    onClick={handleZoomIn}
                    className="p-2 bg-white rounded-lg border border-gray-200 hover:bg-gray-50 transition-colors"
                    title="Zoom In"
                >
                    <ZoomIn className="w-5 h-5 text-gray-600" />
                </button>
                <button
                    onClick={handleZoomOut}
                    className="p-2 bg-white rounded-lg border border-gray-200 hover:bg-gray-50 transition-colors"
                    title="Zoom Out"
                >
                    <ZoomOut className="w-5 h-5 text-gray-600" />
                </button>
                <button
                    onClick={handleReset}
                    className="p-2 bg-white rounded-lg border border-gray-200 hover:bg-gray-50 transition-colors"
                    title="Reset View"
                >
                    <Maximize className="w-5 h-5 text-gray-600" />
                </button>
                <button
                    onClick={fetchTopology}
                    className="p-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                    title="Refresh"
                >
                    <RefreshCw className="w-5 h-5" />
                </button>
            </div>

            {/* Legend */}
            <div className="absolute top-4 left-4 z-10 bg-white rounded-lg border border-gray-200 p-4">
                <h3 className="text-sm font-semibold text-gray-900 mb-3">Legend</h3>
                <div className="space-y-2">
                    <LegendItem color="#3b82f6" label="Server" />
                    <LegendItem color="#8b5cf6" label="Container" />
                    <LegendItem color="#10b981" label="Switch" />
                    <LegendItem color="#f59e0b" label="Router" />
                    <LegendItem color="#ef4444" label="Firewall" />
                </div>
                <div className="mt-4 pt-4 border-t border-gray-200 space-y-2">
                    <div className="flex items-center gap-2 text-xs">
                        <div className="w-3 h-3 rounded-full bg-green-500"></div>
                        <span className="text-gray-600">Online</span>
                    </div>
                    <div className="flex items-center gap-2 text-xs">
                        <div className="w-3 h-3 rounded-full bg-red-500"></div>
                        <span className="text-gray-600">Offline</span>
                    </div>
                </div>
            </div>

            {/* SVG Canvas */}
            <svg
                ref={svgRef}
                width={width}
                height={height}
                className="cursor-move"
            />

            {/* Selected Node Details */}
            {selectedNode && (
                <div className="absolute bottom-4 left-4 z-10 bg-white rounded-lg border border-gray-200 p-4 w-80">
                    <div className="flex items-start justify-between mb-3">
                        <div>
                            <h3 className="text-lg font-semibold text-gray-900">{selectedNode.name}</h3>
                            <p className="text-sm text-gray-500">{selectedNode.type}</p>
                        </div>
                        <button
                            onClick={() => setSelectedNode(null)}
                            className="text-gray-400 hover:text-gray-600"
                        >
                            ✕
                        </button>
                    </div>
                    <div className="space-y-2 text-sm">
                        <DetailRow label="Status" value={selectedNode.status} />
                        {selectedNode.ip && <DetailRow label="IP Address" value={selectedNode.ip} />}
                        {selectedNode.location && <DetailRow label="Location" value={selectedNode.location} />}
                        {selectedNode.containers && <DetailRow label="Containers" value={selectedNode.containers} />}
                        {selectedNode.uptime && <DetailRow label="Uptime" value={selectedNode.uptime} />}
                    </div>
                </div>
            )}

            {/* Statistics */}
            <div className="absolute bottom-4 right-4 z-10 bg-white rounded-lg border border-gray-200 p-4">
                <div className="space-y-2 text-sm">
                    <div className="flex items-center justify-between gap-8">
                        <span className="text-gray-600">Nodes:</span>
                        <span className="font-semibold text-gray-900">{topology.nodes.length}</span>
                    </div>
                    <div className="flex items-center justify-between gap-8">
                        <span className="text-gray-600">Links:</span>
                        <span className="font-semibold text-gray-900">{topology.links.length}</span>
                    </div>
                    <div className="flex items-center justify-between gap-8">
                        <span className="text-gray-600">Online:</span>
                        <span className="font-semibold text-green-600">
                            {topology.nodes.filter(n => n.status === 'online').length}
                        </span>
                    </div>
                </div>
            </div>
        </div>
    );
};

/**
 * Legend Item Component
 */
const LegendItem = ({ color, label }) => (
    <div className="flex items-center gap-2 text-xs">
        <div className="w-4 h-4 rounded-full" style={{ backgroundColor: color }}></div>
        <span className="text-gray-600">{label}</span>
    </div>
);

/**
 * Detail Row Component
 */
const DetailRow = ({ label, value }) => (
    <div className="flex items-center justify-between">
        <span className="text-gray-600">{label}:</span>
        <span className="font-medium text-gray-900">{value}</span>
    </div>
);

export default NetworkTopologyVisualization;
