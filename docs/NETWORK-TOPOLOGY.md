# Network Topology Visualizer - User Guide

> **Last Updated**: 2025-01-20 | **Version**: 1.0.0 | **Phase**: 3

## Overview

The Network Topology Visualizer provides an interactive 3D/2D visualization of the AGL WireGuard mesh network infrastructure, featuring real-time health monitoring, latency heatmaps, and intelligent network path analysis.

**Key Features**:
- **Interactive Visualization**: Pan, zoom, drag nodes, multiple layout algorithms
- **Real-Time Updates**: WebSocket-powered live metrics (30-second refresh)
- **Network Health Monitoring**: CPU, RAM, network I/O, latency tracking
- **Latency Heatmap**: Color-coded connection quality visualization
- **Intelligent Filtering**: Filter by type, status, network (WireGuard/LAN/Tailscale)
- **Path Analysis**: Calculate shortest network paths with Dijkstra's algorithm
- **Export Capabilities**: PNG, SVG, JSON export formats
- **Search**: Find nodes by name, ID, or IP address

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [User Interface](#user-interface)
3. [Network Elements](#network-elements)
4. [Interactive Features](#interactive-features)
5. [Filtering & Search](#filtering--search)
6. [Layout Algorithms](#layout-algorithms)
7. [Export Options](#export-options)
8. [Troubleshooting](#troubleshooting)
9. [Performance Tips](#performance-tips)
10. [API Reference](#api-reference)

---

## Quick Start

### Accessing the Visualizer

**URL**: `https://your-domain.com/network/topology`

**Requirements**:
- Authenticated user (WorkOS SSO)
- Modern browser (Chrome 90+, Firefox 88+, Safari 14+)
- Minimum 1920x1080 resolution recommended

### First Look

Upon loading, you'll see:
1. **Network Health Dashboard** (top) - Overall metrics
2. **Cytoscape Visualization** (center) - Interactive graph
3. **Control Panel** (top-left) - Search, filters, layout controls
4. **Legend** (bottom) - Node types, connection types, latency scale

---

## User Interface

### Network Health Dashboard

Located at the top of the screen, displays:

| Metric | Description | Thresholds |
|--------|-------------|------------|
| **Total Nodes** | Active/Total nodes | Green: 100%, Yellow: 80-99%, Red: <80% |
| **Avg Latency** | Network average | Green: <30ms, Yellow: 30-60ms, Red: >60ms |
| **Health Score** | Overall network health | Green: >90%, Yellow: 70-90%, Red: <70% |
| **Connections** | Healthy/Total edges | Green: 100%, Yellow: 80-99%, Red: <80% |

**Issues Panel** (shown when problems detected):
- Critical issues (red): Node offline, connection lost
- Warning issues (yellow): High latency (>100ms), packet loss (>5%)

### Control Panel

**Search Bar**:
- Search by: Node name, ID, IP address
- Auto-highlight: Matches highlighted with gold border
- Auto-center: First match centered in viewport

**Main Controls** (left to right):
1. **Layout Selector**: Change graph layout algorithm
2. **Toggle Labels**: Show/hide node names
3. **Toggle Edges**: Show/hide connection lines
4. **Latency Heatmap**: Color-code edges by latency
5. **Filters**: Advanced filtering options
6. **Fit to Viewport**: Reset zoom and center graph
7. **Refresh**: Manual data refresh
8. **Export**: Download graph as PNG/SVG/JSON

---

## Network Elements

### Node Types

#### 1. Server Nodes (Purple)
- **Shape**: Large circle (80px)
- **Border**: 3px purple (#7C3AED)
- **Examples**: AGLSRV1, AGLSRV6
- **Info**: Proxmox hosts, main infrastructure

#### 2. Container Nodes (Blue)
- **Shape**: Medium circle (60px)
- **Border**: 2px blue (#3B82F6)
- **Examples**: CT179, CT180, CT183
- **Info**: LXC containers, services, applications

#### 3. Network Hub (Green Hexagon)
- **Shape**: Hexagon (70px)
- **Border**: 3px green (#10B981)
- **Example**: WireGuard Hub (CT111)
- **Info**: Central networking node, fileserver

### Connection Types

#### 1. WireGuard Connections (Green, Solid)
- **Width**: 3px
- **Style**: Solid line
- **Latency**: Typically 15-40ms
- **Use**: Primary mesh network

#### 2. LAN Connections (Gray, Dashed)
- **Width**: 2px
- **Style**: Dashed line
- **Latency**: Typically 1-5ms
- **Use**: Local container-to-host

#### 3. Tailscale Connections (Blue, Dotted)
- **Width**: 2px
- **Style**: Dotted line
- **Latency**: Typically 40-80ms
- **Use**: Cross-site VPN overlay

### Node Colors (Health Status)

| Health | Color | Range | Meaning |
|--------|-------|-------|---------|
| **Excellent** | Green (#10B981) | 90-100% | All systems normal |
| **Good** | Yellow (#F59E0B) | 70-89% | Minor issues, operational |
| **Fair** | Orange (#F97316) | 50-69% | Performance degraded |
| **Poor** | Red (#EF4444) | 0-49% | Critical issues, attention needed |

### Edge Colors (Latency Heatmap)

When **Latency Heatmap** is enabled:

| Latency | Color | Range | Meaning |
|---------|-------|-------|---------|
| **Excellent** | Green (#10B981) | <20ms | Local network speed |
| **Good** | Yellow (#F59E0B) | 20-50ms | Normal WireGuard latency |
| **Fair** | Orange (#F97316) | 50-100ms | Elevated latency, usable |
| **Poor** | Red (#EF4444) | >100ms | High latency, investigate |

---

## Interactive Features

### Click Node

Opens **Node Details Panel** (slides in from right):

**Information Displayed**:
- Node name, type, role
- Status badge (online/offline)
- Health score with progress bar
- IP addresses (WireGuard, LAN, Tailscale)
- Specifications (CPU cores, RAM, storage)
- Real-time metrics (CPU %, RAM %, network I/O)
- Uptime in days
- Location information

**Quick Actions**:
- **SSH Connect**: Open WebSSH terminal (coming soon)
- **Monitor**: Open monitoring dashboard
- **Restart**: Restart container (servers excluded)

### Click Edge

Opens **Edge Details Panel** (centered overlay):

**Information Displayed**:
- Source and target nodes
- Connection type (WireGuard/LAN/Tailscale)
- Bidirectional indicator
- Latency (current, with status)
- Bandwidth capacity
- Packet loss percentage
- Last handshake time (WireGuard only)
- Connection status and health score

### Hover Node

**Visual Effects**:
- Connected nodes and edges highlighted
- Unconnected elements dimmed (20% opacity)
- Hover info tooltip (bottom-left)

**Tooltip Shows**:
- Node name and type
- Primary IP addresses (WireGuard, LAN)

### Double-Click Node

**Action**: Zoom to node and center view
- Zoom level: 2x
- Animation: 500ms smooth transition
- Useful for: Focusing on specific infrastructure area

### Right-Click Node

**Action**: Context menu (planned)
- View detailed information
- SSH to node
- Open monitoring dashboard
- Restart/stop container
- Configure alerts

### Drag Node

**Action**: Manual repositioning
- Nodes can be dragged to new positions
- Layout preserved until refresh
- Saved to localStorage (coming soon)
- Useful for: Custom logical grouping

### Zoom/Pan

**Mouse Controls**:
- **Scroll Wheel**: Zoom in/out (sensitivity: 0.2)
- **Click + Drag Background**: Pan viewport
- **Zoom Range**: 0.1x to 3x
- **Reset**: Click "Fit to Viewport" button

**Keyboard Shortcuts** (coming soon):
- `+` / `-`: Zoom in/out
- Arrow keys: Pan viewport
- `0`: Reset zoom to 1x
- `F`: Fit to viewport

---

## Filtering & Search

### Search Bar

**How to Use**:
1. Type query in search box (top-left)
2. Results auto-highlight with gold border
3. First match auto-centers in view
4. Clear search: Click `×` button or delete text

**Search Supports**:
- Node names: `CT179`, `AGLSRV1`, `WireGuard Hub`
- Node IDs: `ct179`, `aglsrv1`, `wg-hub`
- IP addresses: `10.6.0.15`, `192.168.0.245`, `100.107.113.33`
- Partial matches: `srv`, `179`, `10.6`

**Examples**:
```
Search: "179"
Matches: ct179, ct179 (192.168.0.179)

Search: "10.6.0"
Matches: All WireGuard nodes (10.6.0.x)

Search: "srv"
Matches: aglsrv1, aglsrv6, fgsrv6, omaysrv1
```

### Filters Panel

**Accessing**: Click **Filter** icon in control panel

#### Filter by Node Type

| Option | Shows |
|--------|-------|
| **All Types** | All nodes (default) |
| **Servers** | AGLSRV1, AGLSRV6 only |
| **Containers** | All LXC containers |
| **Network Devices** | WireGuard hub, switches (if discovered) |

#### Filter by Status

| Option | Shows |
|--------|-------|
| **All Status** | All nodes (default) |
| **Online** | Active, healthy nodes only |
| **Offline** | Disconnected nodes only |
| **Degraded** | Nodes with performance issues |

#### Filter by Network Type

| Option | Shows |
|--------|-------|
| **All Networks** | All connections (default) |
| **WireGuard** | Only WireGuard mesh connections |
| **LAN** | Only local container-to-host |
| **Tailscale** | Only Tailscale overlay connections |

**Reset Filters**: Click "Reset Filters" button at bottom of panel

---

## Layout Algorithms

### 1. Force-Directed (Cose-Bilkent) - **Default**

**Best For**: Discovering natural clusters and relationships

**Characteristics**:
- Physics-based positioning (nodes repel, edges attract)
- Iterative optimization (2500 iterations)
- Auto-spacing (node repulsion: 8000)
- Edge length: 200px ideal
- Gravity: 0.25 (weak center pull)

**Use When**:
- Exploring network structure organically
- Finding unexpected connections
- General overview (default view)

### 2. Hierarchical (Dagre Tree)

**Best For**: Logical top-down infrastructure view

**Characteristics**:
- Top-to-bottom tree layout
- Servers at top, containers below
- Fixed spacing (node: 100px, rank: 150px)
- No overlaps
- Clear parent-child relationships

**Use When**:
- Viewing infrastructure hierarchy
- Seeing container-to-host relationships
- Presenting to non-technical stakeholders

### 3. Constrained (Cola)

**Best For**: Dense networks with many connections

**Characteristics**:
- Force-directed with constraints
- Faster than Cose (4-second max)
- Good for 50+ nodes
- Node spacing: 100px
- Edge length: 150px

**Use When**:
- Large networks (50+ nodes)
- Performance is priority
- Need faster layout computation

### 4. Circular

**Best For**: Hub-and-spoke visualization

**Characteristics**:
- Nodes arranged in concentric circles
- Hub at center
- Radius: 300px
- Spacing factor: 1.5

**Use When**:
- Visualizing hub-and-spoke topology
- Emphasizing central nodes (WireGuard hub)
- Comparing node distances from hub

**Switching Layouts**:
1. Click **Layout** button in control panel
2. Select desired algorithm
3. Graph animates to new layout (1 second)

---

## Export Options

### Export as PNG

**Format**: Raster image
**Resolution**: 2x viewport (high quality)
**Transparency**: No
**Use For**: Reports, presentations, documentation

**How to Export**:
1. Click **Export** icon (download)
2. Select "Export as PNG"
3. File downloads: `network-topology-{timestamp}.png`

**Tips**:
- Zoom to desired view before exporting
- Hide unnecessary labels/edges for clarity
- Use "Fit to Viewport" for full network capture

### Export as SVG

**Format**: Vector image (scalable)
**Resolution**: Infinite (vector)
**Transparency**: Yes
**Use For**: High-quality prints, posters, scalable graphics

**How to Export**:
1. Click **Export** icon
2. Select "Export as SVG"
3. File downloads: `network-topology-{timestamp}.svg`

**Tips**:
- Best for large-format printing
- Editable in Inkscape, Adobe Illustrator
- Smallest file size for simple graphs

### Export as JSON

**Format**: Graph data (Cytoscape.js format)
**Content**: Nodes, edges, positions, metadata
**Use For**: Data analysis, importing to other tools, backups

**How to Export**:
1. Click **Export** icon
2. Select "Export as JSON"
3. File downloads: `network-topology-{timestamp}.json`

**JSON Structure**:
```json
{
  "nodes": [
    {
      "data": {
        "id": "aglsrv1",
        "label": "AGLSRV1",
        "type": "server",
        "health": 95,
        "ips": { "wireguard": "10.6.0.10", "lan": "192.168.0.245" }
      },
      "position": { "x": 100, "y": 200 }
    }
  ],
  "edges": [
    {
      "data": {
        "id": "wg_wg-hub_aglsrv1",
        "source": "wg-hub",
        "target": "aglsrv1",
        "type": "wireguard",
        "latency_ms": 18
      }
    }
  ]
}
```

**Use Cases**:
- Import to Python/R for network analysis
- Backup current topology
- Share with other teams
- Compare topology over time

---

## Troubleshooting

### Common Issues

#### Issue: Visualization Not Loading

**Symptoms**: Blank screen, loading spinner forever

**Solutions**:
1. Check browser console for errors (F12)
2. Verify authentication (logged in?)
3. Refresh page (Ctrl+R)
4. Clear browser cache
5. Check network connectivity

**API Check**:
```bash
curl -H "Authorization: Bearer {token}" \
  https://your-domain.com/api/network/graph
```

---

#### Issue: Nodes Overlapping

**Symptoms**: Nodes positioned on top of each other

**Solutions**:
1. Change layout algorithm (try Dagre or Circle)
2. Increase spacing factor (edit layout config)
3. Manually drag nodes apart
4. Fit to viewport (may auto-space)
5. Filter to reduce node count

---

#### Issue: Slow Performance

**Symptoms**: Lag when panning/zooming, delayed updates

**Solutions**:
1. **Filter Network**: Show only WireGuard (hide LAN/Tailscale)
2. **Disable Labels**: Toggle off node labels
3. **Disable Heatmap**: Turn off latency coloring
4. **Use Simpler Layout**: Switch to Circle or Dagre
5. **Reduce Auto-Refresh**: Increase interval in config
6. **Close Details Panels**: Click background to close

**Performance Metrics**:
- Target: 60 FPS
- Max nodes tested: 500
- Recommended: <100 nodes visible

---

#### Issue: Real-Time Updates Not Working

**Symptoms**: Metrics not updating, stale data

**Solutions**:
1. Check WebSocket connection (browser console)
2. Verify Reverb server running: `php artisan reverb:start`
3. Refresh page to reconnect
4. Check firewall rules (port 8080)
5. Manual refresh: Click refresh button

**WebSocket Debug**:
```javascript
// Browser console
window.Echo.connector.socket.connected
// Should return: true
```

---

#### Issue: Search Not Finding Nodes

**Symptoms**: No results for valid node names

**Solutions**:
1. Check exact spelling (case-insensitive)
2. Try partial match (`srv` instead of `aglsrv1`)
3. Try IP address (`10.6.0.10`)
4. Clear filters (may be hiding matches)
5. Refresh graph data

---

#### Issue: Connection Details Not Showing

**Symptoms**: Click edge but no panel appears

**Solutions**:
1. Click directly on edge (not near it)
2. Close node details panel first
3. Zoom in for easier clicking
4. Check if edge exists in filtered view
5. Try clicking different edge

---

### Debug Mode

**Enable Debug Logging**:
```javascript
// Browser console
localStorage.setItem('network_topology_debug', 'true');
location.reload();
```

**View Debug Logs**:
```javascript
// Browser console (after enabling)
// Check for detailed Cytoscape.js events
```

**Disable Debug**:
```javascript
localStorage.removeItem('network_topology_debug');
location.reload();
```

---

## Performance Tips

### Optimizing Visualization

1. **Limit Visible Elements**:
   - Filter to specific network (WireGuard only)
   - Filter to specific type (Containers only)
   - Search narrows focus automatically

2. **Reduce Visual Complexity**:
   - Disable labels when zoomed out
   - Hide edges when viewing structure
   - Use solid colors (disable heatmap)

3. **Choose Efficient Layouts**:
   - **Fastest**: Circle (instant)
   - **Fast**: Dagre (< 1 second)
   - **Medium**: Cola (2-4 seconds)
   - **Slow**: Cose-Bilkent (1-2 seconds per iteration)

4. **Batch Updates**:
   - Auto-refresh collects changes for 1 second
   - Then applies all at once (smooth)
   - Manual refresh: Click refresh button

5. **Hardware Acceleration**:
   - Enable in browser settings (chrome://settings)
   - Use dedicated GPU if available
   - Close background tabs/apps

### Cache Management

**Graph Data Cache**:
- TTL: 5 minutes (300 seconds)
- Clear: `php artisan cache:clear`
- Disable: Set `NETWORK_TOPOLOGY_CACHE_TTL=0`

**Layout Positions** (coming soon):
- Saved to localStorage
- Persists across sessions
- Clear: Browser developer tools > Application > Local Storage

---

## API Reference

### Endpoints

#### GET `/api/network/graph`

Get complete network graph (nodes + edges + metadata).

**Response**:
```json
{
  "nodes": [...],
  "edges": [...],
  "metadata": {
    "total_nodes": 14,
    "online_nodes": 14,
    "offline_nodes": 0,
    "total_edges": 42,
    "healthy_edges": 40,
    "degraded_edges": 2,
    "avg_latency_ms": 25.3,
    "network_health_score": 95.2
  },
  "timestamp": "2025-01-20T12:34:56Z"
}
```

---

#### GET `/api/network/nodes/{nodeId}`

Get real-time metrics for specific node.

**Parameters**:
- `nodeId`: Node identifier (e.g., `aglsrv1`, `ct179`)

**Response**:
```json
{
  "node_id": "aglsrv1",
  "metrics": {
    "status": "online",
    "health": 95,
    "cpu_percent": 45.2,
    "ram_percent": 62.8,
    "network_io_mbps": 125.5,
    "disk_io_mbps": 45.2,
    "uptime_days": 127
  },
  "timestamp": "2025-01-20T12:34:56Z"
}
```

---

#### GET `/api/network/connections/{sourceId}/{targetId}`

Get connection health between two nodes.

**Parameters**:
- `sourceId`: Source node ID
- `targetId`: Target node ID

**Response**:
```json
{
  "source_id": "aglsrv1",
  "target_id": "ct179",
  "health": {
    "latency_ms": 18,
    "packet_loss_percent": 0.1,
    "last_handshake": "2025-01-20T12:30:00Z",
    "status": "online",
    "health": 98.5
  },
  "timestamp": "2025-01-20T12:34:56Z"
}
```

---

#### GET `/api/network/health`

Get overall network health metrics.

**Response**:
```json
{
  "metadata": {
    "total_nodes": 14,
    "online_nodes": 14,
    "avg_latency_ms": 25.3,
    "network_health_score": 95.2
  },
  "timestamp": "2025-01-20T12:34:56Z"
}
```

---

#### GET `/api/network/issues`

Detect network issues (high latency, packet loss, offline nodes).

**Response**:
```json
[
  {
    "severity": "warning",
    "type": "high_latency",
    "edge_id": "wg_aglsrv1_aglsrv6",
    "source": "aglsrv1",
    "target": "aglsrv6",
    "latency_ms": 105,
    "message": "High latency (105ms) between aglsrv1 and aglsrv6",
    "timestamp": "2025-01-20T12:34:56Z"
  }
]
```

---

#### POST `/api/network/path`

Calculate shortest network path between two nodes (Dijkstra's algorithm).

**Request Body**:
```json
{
  "from": "aglsrv1",
  "to": "ct179"
}
```

**Response**:
```json
{
  "found": true,
  "path": ["aglsrv1", "wg-hub", "ct179"],
  "total_latency_ms": 38,
  "hops": 2
}
```

---

#### GET `/api/network/wireguard/peers`

Get all WireGuard peer information.

**Response**:
```json
[
  {
    "id": "ct111",
    "name": "CT111",
    "wg_ip": "10.6.0.5",
    "lan_ip": "192.168.0.111",
    "role": "Hub & Fileserver"
  }
]
```

---

## Configuration

### Environment Variables

Add to `.env`:

```bash
# Network Topology Visualizer Configuration
NETWORK_TOPOLOGY_CACHE_TTL=300                # Graph cache (seconds)
NETWORK_TOPOLOGY_MAX_NODES=500                # Max nodes to render
NETWORK_TOPOLOGY_LAYOUT_DEFAULT=cose-bilkent  # Default layout
NETWORK_TOPOLOGY_ENABLE_3D=false              # 3D mode (requires extra lib)
NETWORK_TOPOLOGY_LATENCY_THRESHOLD_GOOD=20    # Good latency (ms)
NETWORK_TOPOLOGY_LATENCY_THRESHOLD_FAIR=50    # Fair latency (ms)
NETWORK_TOPOLOGY_LATENCY_THRESHOLD_POOR=100   # Poor latency (ms)
NETWORK_TOPOLOGY_PACKET_LOSS_THRESHOLD=5      # Packet loss warning (%)
NETWORK_TOPOLOGY_AUTO_REFRESH_INTERVAL=30     # Auto-refresh (seconds)
NETWORK_TOPOLOGY_ANIMATION_DURATION=1000      # Animation duration (ms)
```

---

## Support

**Documentation**: `docs/NETWORK-TOPOLOGY.md` (this file)

**Related Docs**:
- Infrastructure: `docs/INFRA.md`
- WireGuard: `docs/WIREGUARD.md`
- Monitoring: `docs/MONITORING.md`

**Reporting Issues**:
1. Check [Troubleshooting](#troubleshooting) section
2. Enable [Debug Mode](#debug-mode)
3. Capture browser console logs (F12)
4. Submit issue with logs + reproduction steps

---

**Document Version**: 1.0.0
**Last Updated**: 2025-01-20
**Author**: AGL Infrastructure Team
**Maintainer**: Claude Code (agl-hostman project)
