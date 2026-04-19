# Infrastructure Topology Diagrams

> **Last Updated**: 2025-11-08 | **Version**: 1.0.0
> **Format**: Mermaid diagrams (render in GitHub, VSCode, or Mermaid Live Editor)

---

## 📍 Physical Location Topology

```mermaid
graph TB
    subgraph AGLHQ["🏢 AGLHQ (Headquarters)<br/>192.168.0.0/24"]
        AGLSRV1["AGLSRV1<br/>Proxmox VE<br/>192.168.0.245<br/>WG: 10.6.0.10<br/>TS: 100.107.113.33"]
        AGLSRV3["AGLSRV3<br/>Proxmox VE<br/>⚠️ OFFLINE"]
        AGLHQ11["AGLHQ11<br/>Physical Machine<br/>TS: 100.75.205.122"]
        AGLFA02["AGLFA02<br/>Physical Machine<br/>LAN only"]

        CT179["CT179 (agldv03)<br/>Development<br/>48GB RAM<br/>LAN: 192.168.0.179<br/>WG: 10.6.0.19<br/>TS: 100.94.221.87"]
        CT180["CT180 (dokploy)<br/>Deployment Platform<br/>https://dok.aglz.io"]
        CT183["CT183 (archon)<br/>AI Command Center<br/>WG: 10.6.0.21<br/>TS: 100.80.30.59"]

        AGLSRV1 --> CT179
        AGLSRV1 --> CT180
        AGLSRV1 --> CT183
    end

    subgraph AGLFG["🏠 AGLFG (Remote Site)<br/>192.168.15.0/24 + 172.2.2.0/24"]
        AGLSRV5["AGLSRV5<br/>Proxmox VE<br/>LAN1: 192.168.15.222<br/>LAN2: 172.2.2.222<br/>WG: 10.6.0.17<br/>TS: 100.119.223.113"]
    end

    subgraph AGLALD["🏘️ AGLALD (Remote Site)<br/>192.168.0.0/24 + 192.168.1.0/24 + 192.168.60.0/24"]
        AGLSRV6["AGLSRV6<br/>Proxmox VE<br/>External: 192.168.0.202<br/>Proxmox: 192.168.60.202<br/>PRIMARY: 192.168.1.202<br/>WG: 10.6.0.12<br/>TS: 100.98.108.66"]
        AGLSRV6C["AGLSRV6C<br/>Proxmox VE<br/>External: 192.168.0.233<br/>PRIMARY: 192.168.1.233<br/>WG: 10.6.0.22<br/>TS: 100.124.53.91"]
        AGLSRV6D["AGLSRV6D<br/>Proxmox VE<br/>Failsafe Backup<br/>LAN: 192.168.0.234<br/>WG: 10.6.0.23<br/>TS: 100.76.201.83"]

        AGLSRV6 -.->|"192.168.1.x<br/>PRIMARY"| AGLSRV6C
        AGLSRV6 -.->|"192.168.60.x<br/>Corosync"| AGLSRV6C
    end

    subgraph CLOUD["☁️ AGLFG-VPS (Cloud Infrastructure)<br/>Public IPs"]
        FGSRV6["FGSRV6 🌟<br/>WireGuard Hub<br/>Public: 186.202.57.120<br/>WG: 10.6.0.5:51823<br/>TS: 100.83.51.9"]
        FGSRV5["FGSRV5<br/>NFS Storage<br/>Public: 191.252.200.20<br/>WG: 10.6.0.11<br/>TS: 100.71.107.26"]
        FGSRV4["FGSRV4<br/>General Purpose<br/>WG: 10.6.0.16<br/>TS: 100.111.79.2"]
        FGSRV3["FGSRV3<br/>General Purpose<br/>Public: 191.252.201.205<br/>WG: 10.6.0.18<br/>TS: 100.67.99.115"]
    end

    %% WireGuard Mesh Connections (via Hub)
    AGLSRV1 -.->|"WG Mesh<br/>30ms"| FGSRV6
    AGLSRV5 -.->|"WG Mesh<br/>27ms"| FGSRV6
    AGLSRV6 -.->|"WG Mesh<br/>31ms"| FGSRV6
    AGLSRV6C -.->|"WG Mesh<br/>32ms"| FGSRV6
    CT179 -.->|"WG Mesh<br/>13ms"| FGSRV6

    %% Tailscale Overlay (backup)
    AGLHQ ~~~ AGLFG
    AGLFG ~~~ AGLALD
    AGLALD ~~~ CLOUD

    style FGSRV6 fill:#ffcccc,stroke:#ff0000,stroke-width:3px
    style CT179 fill:#ccffcc,stroke:#00ff00,stroke-width:2px
    style CT183 fill:#ccccff,stroke:#0000ff,stroke-width:2px
    style AGLSRV6 fill:#ffffcc,stroke:#ffaa00,stroke-width:2px
    style AGLSRV6C fill:#ffffcc,stroke:#ffaa00,stroke-width:2px
```

---

## 🔗 WireGuard Mesh Topology

```mermaid
graph TD
    subgraph Hub["☁️ WireGuard Hub"]
        FGSRV6["FGSRV6<br/>10.6.0.5:51823<br/>186.202.57.120<br/>🌟 CENTRAL HUB"]
    end

    subgraph AGLHQ_WG["AGLHQ Nodes"]
        WG_SRV1["AGLSRV1<br/>10.6.0.10:51810<br/>Latency: 30ms"]
        WG_CT179["CT179<br/>10.6.0.19:51819<br/>Latency: 13ms ⚡"]
        WG_CT183["CT183<br/>10.6.0.21:51821"]
    end

    subgraph AGLFG_WG["AGLFG Nodes"]
        WG_SRV5["AGLSRV5<br/>10.6.0.17:51817<br/>Latency: 27ms"]
    end

    subgraph AGLALD_WG["AGLALD Nodes"]
        WG_SRV6["AGLSRV6<br/>10.6.0.12:51812<br/>Latency: 31ms"]
        WG_SRV6C["AGLSRV6C<br/>10.6.0.22:51822<br/>Latency: 32ms"]
        WG_SRV6D["AGLSRV6D<br/>10.6.0.23:51823"]
        WG_CT111["CT111 (NFS)<br/>10.6.0.20"]
    end

    subgraph CLOUD_WG["Cloud VPS Nodes"]
        WG_FGSRV3["FGSRV3<br/>10.6.0.18"]
        WG_FGSRV4["FGSRV4<br/>10.6.0.16"]
        WG_FGSRV5["FGSRV5 (NFS)<br/>10.6.0.11"]
    end

    %% All nodes connect to Hub (star topology)
    FGSRV6 ---|Encrypted| WG_SRV1
    FGSRV6 ---|Encrypted| WG_CT179
    FGSRV6 ---|Encrypted| WG_CT183
    FGSRV6 ---|Encrypted| WG_SRV5
    FGSRV6 ---|Encrypted| WG_SRV6
    FGSRV6 ---|Encrypted| WG_SRV6C
    FGSRV6 ---|Encrypted| WG_SRV6D
    FGSRV6 ---|Encrypted| WG_CT111
    FGSRV6 ---|Encrypted| WG_FGSRV3
    FGSRV6 ---|Encrypted| WG_FGSRV4
    FGSRV6 ---|Encrypted| WG_FGSRV5

    %% Peer-to-peer connections (dotted - routed via hub)
    WG_CT179 -.->|"via Hub"| WG_SRV6
    WG_CT179 -.->|"via Hub"| WG_SRV5
    WG_SRV6 -.->|"via Hub"| WG_SRV6C

    style FGSRV6 fill:#ffcccc,stroke:#ff0000,stroke-width:4px
    style WG_CT179 fill:#ccffcc,stroke:#00ff00,stroke-width:2px
    style WG_SRV6 fill:#ffffcc,stroke:#ffaa00,stroke-width:2px
    style WG_SRV6C fill:#ffffcc,stroke:#ffaa00,stroke-width:2px
```

---

## 🎯 PRIMARY Network (192.168.1.x) - AGLALD Inter-Host Communication

```mermaid
graph LR
    subgraph AGLALD_PRIMARY["AGLALD - PRIMARY Network (192.168.1.0/24)"]
        direction TB

        SRV6["AGLSRV6<br/>192.168.1.202<br/>vmbr2"]
        SRV6C["AGLSRV6C<br/>192.168.1.233<br/>vmbr2"]

        subgraph SRV6_CTS["AGLSRV6 Containers"]
            CT111["CT111 (aluzdivina)<br/>NFS Server"]
            CT108["CT108 (agldv06)<br/>Development"]
        end

        subgraph SRV6C_CTS["AGLSRV6C Containers"]
            CT_X["Container X"]
            CT_Y["Container Y"]
        end

        SRV6 ===|"0.195ms ⚡<br/>PRIMARY"| SRV6C
        SRV6 --> CT111
        SRV6 --> CT108
        SRV6C --> CT_X
        SRV6C --> CT_Y

        CT111 -.-|"Container<br/>Communication"| CT_X
        CT108 -.-|"Container<br/>Communication"| CT_Y
    end

    subgraph EXTERNAL["External LAN (192.168.0.x)"]
        EXT_SRV6["AGLSRV6<br/>192.168.0.202"]
        EXT_SRV6C["AGLSRV6C<br/>192.168.0.233"]

        EXT_SRV6 -.->|"0.315ms<br/>62% slower"| EXT_SRV6C
    end

    SRV6 -.->|"Also available<br/>via External"| EXT_SRV6
    SRV6C -.->|"Also available<br/>via External"| EXT_SRV6C

    style SRV6 fill:#ffffcc,stroke:#ffaa00,stroke-width:3px
    style SRV6C fill:#ffffcc,stroke:#ffaa00,stroke-width:3px
    style CT111 fill:#ccffff,stroke:#00aaff,stroke-width:2px
```

---

## 📊 Network Performance Hierarchy

```mermaid
graph TD
    subgraph Performance["Network Performance (Latency)"]
        LAN["Local LAN<br/>0.07ms<br/>⚡⚡⚡ 400x faster"]
        PRIMARY["PRIMARY Inter-host<br/>192.168.1.x<br/>0.20ms<br/>⚡⚡⚡ Best local"]
        EXT_LAN["External LAN<br/>192.168.0.x<br/>0.32ms<br/>⚡⚡ Local alt"]
        WG_CLOUD["WireGuard Cloud<br/>FGSRV6 Hub<br/>13.5ms<br/>⚡⚡ Excellent"]
        TS_AGLFG["Tailscale AGLFG<br/>22.5ms<br/>⚡ Best for AGLSRV5"]
        WG_AGLFG["WireGuard AGLFG<br/>26.7ms<br/>⚡ Alternative"]
        WG_AGLALD["WireGuard AGLALD<br/>30-32ms<br/>⚡ Best for remote"]
        TS_AGLALD["Tailscale AGLALD<br/>37ms<br/>✅ Reliable fallback"]
    end

    LAN --> PRIMARY
    PRIMARY --> EXT_LAN
    EXT_LAN --> WG_CLOUD
    WG_CLOUD --> TS_AGLFG
    TS_AGLFG --> WG_AGLFG
    WG_AGLFG --> WG_AGLALD
    WG_AGLALD --> TS_AGLALD

    style LAN fill:#00ff00,stroke:#006600,stroke-width:3px
    style PRIMARY fill:#66ff66,stroke:#009900,stroke-width:3px
    style WG_CLOUD fill:#99ff99,stroke:#00cc00,stroke-width:2px
    style TS_AGLALD fill:#ffcccc,stroke:#ff6666,stroke-width:2px
```

---

## 🔄 Connection Decision Flow

```mermaid
flowchart TD
    Start([Need to connect to host?]) --> CheckLoc{Same physical<br/>location?}

    CheckLoc -->|Yes| UseLAN[Use Local LAN<br/>⚡⚡⚡ 0.07ms]
    CheckLoc -->|No| CheckSite{Which site?}

    CheckSite -->|AGLALD| CheckAGLALD{AGLSRV6 ↔ AGLSRV6C?}
    CheckAGLALD -->|Yes| UsePRIMARY[Use PRIMARY 192.168.1.x<br/>⚡⚡⚡ 0.20ms]
    CheckAGLALD -->|No| UseWG_ALD[Use WireGuard<br/>⚡ 30-32ms]

    CheckSite -->|AGLFG/AGLSRV5| CheckAGLFG{Need SSH?}
    CheckAGLFG -->|Yes| UseTS_FG[Use Tailscale<br/>⚡ 22.5ms<br/>SSH works!]
    CheckAGLFG -->|No| UseWG_FG[Use WireGuard<br/>⚡ 26.7ms<br/>⚠️ SSH issue]

    CheckSite -->|Cloud VPS| UseWG_VPS[Use WireGuard<br/>⚡⚡ 13.5ms]

    UseLAN --> Success([Connected ✅])
    UsePRIMARY --> Success
    UseWG_ALD --> CheckTS{Connection<br/>failed?}
    UseWG_FG --> CheckTS
    UseWG_VPS --> CheckTS
    UseTS_FG --> Success

    CheckTS -->|Yes| Fallback[Fallback to Tailscale<br/>✅ Reliable]
    CheckTS -->|No| Success
    Fallback --> Success

    style UseLAN fill:#00ff00,stroke:#006600,stroke-width:3px
    style UsePRIMARY fill:#66ff66,stroke:#009900,stroke-width:3px
    style UseWG_VPS fill:#99ff99,stroke:#00cc00,stroke-width:2px
    style UseTS_FG fill:#ffff99,stroke:#ffcc00,stroke-width:2px
    style Success fill:#ccffcc,stroke:#00ff00,stroke-width:2px
```

---

## 🗺️ Complete Network Stack View

```mermaid
graph TB
    subgraph Stack["Network Layer Stack"]
        direction TB

        subgraph Layer1["Layer 1: Local LAN (Physical Location)"]
            L1_HQ["AGLHQ: 192.168.0.0/24"]
            L1_FG["AGLFG: 192.168.15.0/24 + 172.2.2.0/24"]
            L1_ALD["AGLALD: 192.168.0.0/24 + 192.168.1.0/24 + 192.168.60.0/24"]
        end

        subgraph Layer2["Layer 2: WireGuard Mesh (10.6.0.0/24)"]
            L2_Hub["FGSRV6 Hub: 10.6.0.5<br/>🌟 Central Router"]
            L2_Nodes["15 Active Nodes<br/>Star Topology<br/>Encrypted"]
        end

        subgraph Layer3["Layer 3: Tailscale Overlay (100.64.0.0/10)"]
            L3_Cloud["Tailscale Cloud<br/>Mesh Network<br/>Universal Access"]
        end

        subgraph Layer4["Layer 4: Public Internet"]
            L4_Public["Public IPs<br/>External Access<br/>Cloudflare Tunnels"]
        end
    end

    L1_HQ -.-> L2_Hub
    L1_FG -.-> L2_Hub
    L1_ALD -.-> L2_Hub

    L2_Nodes -.-> L3_Cloud
    L3_Cloud -.-> L4_Public

    style L2_Hub fill:#ffcccc,stroke:#ff0000,stroke-width:3px
    style L3_Cloud fill:#ccccff,stroke:#0000ff,stroke-width:2px
    style L4_Public fill:#ffccff,stroke:#ff00ff,stroke-width:2px
```

---

## 📍 AGLSRV6 Network Architecture (Triple Network)

```mermaid
graph TB
    subgraph AGLSRV6_HOST["AGLSRV6 Host - Triple Network Configuration"]
        direction TB

        HOST["AGLSRV6<br/>Proxmox VE 8.3.2"]

        subgraph Interfaces["Network Interfaces"]
            VMBR0["vmbr0<br/>192.168.0.202/24<br/>External LAN"]
            VMBR1["vmbr1<br/>192.168.60.202/24<br/>Proxmox Internal"]
            VMBR2["vmbr2<br/>192.168.1.202/24<br/>⭐ PRIMARY Inter-host"]
            WG0["wg0<br/>10.6.0.12/24<br/>WireGuard Mesh"]
            TS0["tailscale0<br/>100.98.108.66<br/>Tailscale Overlay"]
        end

        HOST --> VMBR0
        HOST --> VMBR1
        HOST --> VMBR2
        HOST --> WG0
        HOST --> TS0
    end

    subgraph External["External Access"]
        EXT_NET["192.168.0.0/24<br/>Public LAN"]
        INTERNET["Internet Access"]
    end

    subgraph Proxmox_Cluster["Proxmox Cluster"]
        COROSYNC["Corosync<br/>Cluster Communication<br/>192.168.60.0/24"]
    end

    subgraph InterHost["Inter-Host Communication"]
        SRV6C_PRIMARY["AGLSRV6C<br/>192.168.1.233<br/>⚡ 0.195ms"]
        CONTAINERS["Containers<br/>192.168.1.x"]
    end

    subgraph Remote["Remote Networks"]
        WG_MESH["WireGuard Mesh<br/>10.6.0.0/24<br/>via FGSRV6 Hub"]
        TS_OVERLAY["Tailscale Overlay<br/>100.64.0.0/10"]
    end

    VMBR0 --> EXT_NET
    EXT_NET --> INTERNET
    VMBR1 --> COROSYNC
    VMBR2 ===|"PRIMARY"| SRV6C_PRIMARY
    VMBR2 --> CONTAINERS
    WG0 --> WG_MESH
    TS0 --> TS_OVERLAY

    style VMBR2 fill:#ffff99,stroke:#ffaa00,stroke-width:4px
    style SRV6C_PRIMARY fill:#ffff99,stroke:#ffaa00,stroke-width:3px
    style HOST fill:#ffffcc,stroke:#ffaa00,stroke-width:3px
```

---

## 🎨 Diagram Legend

### Node Types
- 🏢 **AGLHQ**: Headquarters (primary production)
- 🏠 **AGLFG**: Remote standalone site
- 🏘️ **AGLALD**: Remote site with backup/failover
- ☁️ **AGLFG-VPS**: Cloud infrastructure
- 🌟 **Hub**: Critical infrastructure component

### Connection Types
- `───` Solid line: Direct connection
- `===` Double line: PRIMARY/fastest connection
- `-.->` Dashed line: Routed/indirect connection
- `~~~` Wavy line: Logical relationship

### Performance Indicators
- ⚡⚡⚡ Excellent (<1ms)
- ⚡⚡ Very Good (1-20ms)
- ⚡ Good (20-40ms)
- ✅ Acceptable (40ms+)
- ⚠️ Warning/Issue

### Network Colors
- 🟢 Green: Best performance
- 🟡 Yellow: PRIMARY networks
- 🔴 Red: Critical infrastructure
- 🔵 Blue: Overlay networks
- 🟣 Purple: Public/external

---

## 📚 Related Documentation

- **Network Topology**: `TOPOLOGY.md` - Physical locations and network architecture
- **Host Configuration**: `HOSTS.md` - Detailed host network configurations
- **Connection Matrix**: `CONNECTIONS.md` - Connection methods and priorities
- **Network Tests**: `NETWORK-TESTS.md` - Validation and performance benchmarks
- **WireGuard Mesh**: `WIREGUARD.md` - Complete mesh configuration

---

## 🔧 Rendering These Diagrams

### In GitHub
All Mermaid diagrams render automatically in GitHub markdown files.

### In VSCode
1. Install "Markdown Preview Mermaid Support" extension
2. Open this file and use Markdown Preview (Ctrl+Shift+V)

### In Mermaid Live Editor
1. Visit https://mermaid.live
2. Copy any diagram code block
3. Paste to edit and export

### In Documentation Sites
Most modern documentation generators (MkDocs, Docusaurus, etc.) support Mermaid natively.

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-08
**Maintainer**: Claude Code (agl-hostman project)

**Diagram Count**: 8 diagrams covering complete infrastructure topology
