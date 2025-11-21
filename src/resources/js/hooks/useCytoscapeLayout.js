import { useEffect, useRef, useState, useCallback } from 'react';
import cytoscape from 'cytoscape';
import dagre from 'cytoscape-dagre';
import cola from 'cytoscape-cola';
import coseBilkent from 'cytoscape-cose-bilkent';

// Register layout extensions
cytoscape.use(dagre);
cytoscape.use(cola);
cytoscape.use(coseBilkent);

/**
 * Get latency-based color for edges
 */
function getLatencyColor(latencyMs) {
    if (latencyMs < 20) return '#10B981'; // green
    if (latencyMs < 50) return '#F59E0B'; // yellow
    if (latencyMs < 100) return '#F97316'; // orange
    return '#EF4444'; // red
}

/**
 * Get health-based color for nodes
 */
function getHealthColor(health) {
    if (health >= 90) return '#10B981'; // green
    if (health >= 70) return '#F59E0B'; // yellow
    if (health >= 50) return '#F97316'; // orange
    return '#EF4444'; // red
}

/**
 * Custom hook for managing Cytoscape.js instance
 */
export function useCytoscapeLayout(containerRef, graphData, options = {}) {
    const cyRef = useRef(null);
    const [selectedNode, setSelectedNode] = useState(null);
    const [selectedEdge, setSelectedEdge] = useState(null);
    const [hoveredNode, setHoveredNode] = useState(null);
    const [layout, setLayout] = useState(options.defaultLayout || 'cose-bilkent');
    const [showLabels, setShowLabels] = useState(true);
    const [showEdges, setShowEdges] = useState(true);
    const [latencyHeatmap, setLatencyHeatmap] = useState(true);

    /**
     * Initialize Cytoscape instance
     */
    useEffect(() => {
        if (!containerRef.current || !graphData) return;

        // Convert graph data to Cytoscape format
        const elements = [
            ...graphData.nodes.map(node => ({
                data: {
                    id: node.id,
                    label: node.name,
                    ...node,
                },
            })),
            ...graphData.edges.map(edge => ({
                data: {
                    id: edge.id,
                    source: edge.source,
                    target: edge.target,
                    ...edge,
                },
            })),
        ];

        const cy = cytoscape({
            container: containerRef.current,
            elements,
            style: getCytoscapeStyle(showLabels, showEdges, latencyHeatmap),
            layout: getLayoutConfig(layout),
            minZoom: 0.1,
            maxZoom: 3,
            wheelSensitivity: 0.2,
        });

        // Event handlers
        cy.on('tap', 'node', (event) => {
            const node = event.target;
            setSelectedNode(node.data());
            setSelectedEdge(null);
        });

        cy.on('tap', 'edge', (event) => {
            const edge = event.target;
            setSelectedEdge(edge.data());
            setSelectedNode(null);
        });

        cy.on('tap', (event) => {
            if (event.target === cy) {
                setSelectedNode(null);
                setSelectedEdge(null);
            }
        });

        cy.on('mouseover', 'node', (event) => {
            const node = event.target;
            setHoveredNode(node.data());

            // Highlight connected nodes
            const connectedEdges = node.connectedEdges();
            const connectedNodes = connectedEdges.connectedNodes();

            cy.elements().addClass('dimmed');
            node.removeClass('dimmed').addClass('highlighted');
            connectedNodes.removeClass('dimmed').addClass('highlighted');
            connectedEdges.removeClass('dimmed').addClass('highlighted');
        });

        cy.on('mouseout', 'node', () => {
            setHoveredNode(null);
            cy.elements().removeClass('dimmed highlighted');
        });

        // Store instance
        cyRef.current = cy;

        // Cleanup
        return () => {
            if (cyRef.current) {
                cyRef.current.destroy();
                cyRef.current = null;
            }
        };
    }, [containerRef, graphData, layout, showLabels, showEdges, latencyHeatmap]);

    /**
     * Update layout
     */
    const changeLayout = useCallback((newLayout) => {
        if (!cyRef.current) return;

        setLayout(newLayout);
        const layoutConfig = getLayoutConfig(newLayout);
        const layoutInstance = cyRef.current.layout(layoutConfig);
        layoutInstance.run();
    }, []);

    /**
     * Fit graph to viewport
     */
    const fitToViewport = useCallback(() => {
        if (!cyRef.current) return;
        cyRef.current.fit(null, 50);
    }, []);

    /**
     * Center on specific node
     */
    const centerOnNode = useCallback((nodeId) => {
        if (!cyRef.current) return;
        const node = cyRef.current.getElementById(nodeId);
        if (node) {
            cyRef.current.animate({
                center: { eles: node },
                zoom: 2,
                duration: 500,
            });
        }
    }, []);

    /**
     * Export graph as image
     */
    const exportAsImage = useCallback((format = 'png') => {
        if (!cyRef.current) return null;

        if (format === 'png') {
            return cyRef.current.png({ full: true, scale: 2 });
        } else if (format === 'svg') {
            return cyRef.current.svg({ full: true });
        } else if (format === 'json') {
            return JSON.stringify(cyRef.current.json(), null, 2);
        }

        return null;
    }, []);

    /**
     * Search and highlight nodes
     */
    const searchNodes = useCallback((query) => {
        if (!cyRef.current || !query) {
            cyRef.current?.elements().removeClass('search-match');
            return [];
        }

        const matches = cyRef.current.nodes().filter(node => {
            const data = node.data();
            const searchText = `${data.name} ${data.id} ${Object.values(data.ips || {}).join(' ')}`.toLowerCase();
            return searchText.includes(query.toLowerCase());
        });

        cyRef.current.elements().removeClass('search-match');
        matches.addClass('search-match');

        return matches.map(node => node.data());
    }, []);

    /**
     * Update graph data dynamically
     */
    const updateGraphData = useCallback((newGraphData) => {
        if (!cyRef.current || !newGraphData) return;

        // Batch updates for better performance
        cyRef.current.startBatch();

        // Update nodes
        newGraphData.nodes.forEach(node => {
            const existingNode = cyRef.current.getElementById(node.id);
            if (existingNode.length > 0) {
                existingNode.data(node);
            } else {
                cyRef.current.add({ data: { id: node.id, label: node.name, ...node } });
            }
        });

        // Update edges
        newGraphData.edges.forEach(edge => {
            const existingEdge = cyRef.current.getElementById(edge.id);
            if (existingEdge.length > 0) {
                existingEdge.data(edge);
            } else {
                cyRef.current.add({ data: edge });
            }
        });

        cyRef.current.endBatch();

        // Update style to reflect new data
        cyRef.current.style(getCytoscapeStyle(showLabels, showEdges, latencyHeatmap));
    }, [showLabels, showEdges, latencyHeatmap]);

    return {
        cy: cyRef.current,
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
    };
}

/**
 * Get Cytoscape.js style configuration
 */
function getCytoscapeStyle(showLabels, showEdges, latencyHeatmap) {
    return [
        // Default node style
        {
            selector: 'node',
            style: {
                'background-color': (ele) => getHealthColor(ele.data('health') || 90),
                'width': (ele) => {
                    if (ele.data('type') === 'server') return 80;
                    if (ele.data('type') === 'network') return 70;
                    return 60;
                },
                'height': (ele) => {
                    if (ele.data('type') === 'server') return 80;
                    if (ele.data('type') === 'network') return 70;
                    return 60;
                },
                'label': showLabels ? 'data(label)' : '',
                'text-valign': 'bottom',
                'text-halign': 'center',
                'text-margin-y': 5,
                'font-size': '12px',
                'color': '#fff',
                'text-outline-color': '#000',
                'text-outline-width': 2,
            },
        },
        // Server nodes
        {
            selector: 'node[type="server"]',
            style: {
                'shape': 'ellipse',
                'border-width': 3,
                'border-color': '#7C3AED',
            },
        },
        // Container nodes
        {
            selector: 'node[type="container"]',
            style: {
                'shape': 'ellipse',
                'border-width': 2,
                'border-color': '#3B82F6',
            },
        },
        // Network device nodes
        {
            selector: 'node[type="network"]',
            style: {
                'shape': 'hexagon',
                'border-width': 3,
                'border-color': '#10B981',
            },
        },
        // Default edge style
        {
            selector: 'edge',
            style: {
                'width': showEdges ? 2 : 0,
                'line-color': (ele) => {
                    if (!latencyHeatmap) return '#6B7280';
                    return getLatencyColor(ele.data('latency_ms') || 25);
                },
                'curve-style': 'bezier',
                'target-arrow-shape': 'none',
                'opacity': showEdges ? 0.6 : 0,
            },
        },
        // WireGuard connections
        {
            selector: 'edge[type="wireguard"]',
            style: {
                'line-style': 'solid',
                'width': 3,
            },
        },
        // LAN connections
        {
            selector: 'edge[type="lan"]',
            style: {
                'line-style': 'dashed',
                'width': 2,
            },
        },
        // Tailscale connections
        {
            selector: 'edge[type="tailscale"]',
            style: {
                'line-style': 'dotted',
                'width': 2,
            },
        },
        // Highlighted elements
        {
            selector: '.highlighted',
            style: {
                'opacity': 1,
                'z-index': 999,
            },
        },
        // Dimmed elements
        {
            selector: '.dimmed',
            style: {
                'opacity': 0.2,
            },
        },
        // Search matches
        {
            selector: '.search-match',
            style: {
                'border-width': 5,
                'border-color': '#FBBF24',
                'z-index': 998,
            },
        },
    ];
}

/**
 * Get layout configuration based on layout name
 */
function getLayoutConfig(layoutName) {
    const layouts = {
        'dagre': {
            name: 'dagre',
            rankDir: 'TB', // Top to bottom
            animate: true,
            animationDuration: 1000,
            spacingFactor: 1.5,
            nodeSep: 100,
            rankSep: 150,
        },
        'cola': {
            name: 'cola',
            animate: true,
            animationDuration: 1000,
            maxSimulationTime: 4000,
            nodeSpacing: 100,
            edgeLength: 150,
            randomize: false,
        },
        'cose-bilkent': {
            name: 'cose-bilkent',
            animate: true,
            animationDuration: 1000,
            nodeRepulsion: 8000,
            idealEdgeLength: 200,
            edgeElasticity: 0.45,
            nestingFactor: 0.1,
            gravity: 0.25,
            numIter: 2500,
            tile: true,
            randomize: false,
        },
        'circle': {
            name: 'circle',
            animate: true,
            animationDuration: 1000,
            radius: 300,
            spacingFactor: 1.5,
        },
    };

    return layouts[layoutName] || layouts['cose-bilkent'];
}
