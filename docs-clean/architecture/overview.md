# Architecture Overview

This document provides a comprehensive overview of the AGL Hostman architecture, including system components, data flow, and design principles.

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     AGL Hostman Architecture                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐       │
│  │   Web UI    │    │    API      │    │  CLI Tools  │       │
│  │             │    │             │    │             │       │
│  └─────────────┘    └─────────────┘    └─────────────┘       │
│           │                 │                 │                │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                  Application Layer                      │    │
│  └─────────────────────────────────────────────────────────┘    │
│           │                 │                 │                │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                   Business Logic                        │    │
│  │ - Storage Management    - Monitoring & Alerting         │    │
│  │ - Backup Operations    - User Management                │    │
│  │ - Network Config      - API Gateway                   │    │
│  └─────────────────────────────────────────────────────────┘    │
│           │                 │                 │                │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                   Data Access Layer                     │    │
│  │ - Database (PostgreSQL)    - Cache (Redis)            │    │
│  │ - File System    - External APIs                       │    │
│  └─────────────────────────────────────────────────────────┘    │
│           │                 │                 │                │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                  Infrastructure Layer                    │    │
│  │ - Storage (NFS/iSCSI)    - Monitoring Stack            │    │
│  │ - Network (Tailscale)    - Backup Systems            │    │
│  └─────────────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│            ┌─────────────┐    ┌─────────────┐                 │
│            │   AGLSRV1   │    │   AGLSRV6   │                 │
│            │ (Storage     │    │ (Compute    │                 │
│            │  Server)     │    │  Host)      │                 │
│            └─────────────┘    └─────────────┘                 │
│            ┌─────────────┐    ┌─────────────┐                 │
│            │  AGLSRV6b   │    │  FGSRV5     │                 │
│            │ (Storage     │    │ (Compute    │                 │
│            │  Host)      │    │  Host)      │                 │
│            └─────────────┘    └─────────────┘                 │
│            ┌─────────────┐    ┌─────────────┐                 │
│            │  FGSRV6     │    │             │                 │
│            │ (Compute    │    │             │                 │
│            │  Host)      │    │             │                 │
│            └─────────────┘    └─────────────┘                 │
└─────────────────────────────────────────────────────────────────┘
```

### Core Components

#### 1. Application Layer

The application layer consists of three main interfaces:

- **Web UI**: Modern React-based interface for system management
- **REST API**: RESTful API for programmatic access
- **CLI Tools**: Command-line interface for automation

#### 2. Business Logic Layer

Handles core business operations:

- **Storage Management**: NFS, iSCSI, and PBS management
- **Monitoring & Alerting**: Performance monitoring and alerting
- **Backup Operations**: Automated backup and recovery
- **User Management**: Authentication and authorization
- **API Gateway**: Central API management and routing

#### 3. Data Access Layer

Manages data persistence:

- **PostgreSQL**: Primary database for system data
- **Redis**: Caching layer and session storage
- **File System**: Configuration and log storage
- **External APIs**: Integration with third-party services

#### 4. Infrastructure Layer

The foundation layer providing:

- **Storage Systems**: NFS, iSCSI, and PBS storage
- **Monitoring Stack**: Prometheus, Grafana, Loki
- **Network**: Tailscale VPN for secure connectivity
- **Backup Systems**: Automated backup and replication

## Data Flow

### 1. User Request Flow

```
User Request
    ↓
Web UI / API / CLI
    ↓
Application Layer
    ↓
Business Logic Layer
    ↓
Data Access Layer
    ↓
Infrastructure Layer
    ↓
Response
    ↓
User
```

### 2. Data Storage Flow

```
Data Creation
    ↓
Validation
    ↓
Business Logic Processing
    ↓
Database Write (PostgreSQL)
    ↓
Cache Update (Redis)
    ↓
File Storage
    ↓
Backup
    ↓
Offsite Replication
```

### 3. Monitoring Data Flow

```
Metrics Collection
    ↓
Prometheus Exporters
    ↓
Prometheus Storage
    ↓
Alert Evaluation
    ↓
Alertmanager Routing
    ↓
Notification (Email/Webhook)
    ↓
Grafana Visualization
```

## Design Principles

### 1. Microservices Architecture

The system follows a microservices architecture with the following principles:

- **Single Responsibility**: Each service has a single, well-defined responsibility
- **Decoupling**: Services are loosely coupled and can be developed independently
- **Scalability**: Services can be scaled independently based on demand
- **Resilience**: Failure in one service doesn't affect others

### 2. Containerization

All services are containerized using Docker:

- **Consistent Environment**: Ensures consistency across development, staging, and production
- **Isolation**: Services run in isolated containers
- **Portability**: Easy to deploy and migrate across environments
- **Resource Efficiency**: Efficient resource utilization

### 3. Infrastructure as Code

Infrastructure is managed as code:

- **Terraform**: Infrastructure provisioning and management
- **Ansible**: Configuration management and deployment
- **Version Control**: All infrastructure code is version controlled
- **Automation**: Automated provisioning and deployment

### 4. Security First

Security is built into the architecture:

- **Zero Trust**: All traffic is authenticated and authorized
- **Encryption**: Data is encrypted at rest and in transit
- **Network Security**: Secure network segmentation and firewall rules
- **Access Control**: Role-based access control and least privilege

### 5. Observability

Comprehensive observability is built-in:

- **Metrics**: Prometheus for metrics collection
- **Logging**: Loki for log aggregation
- **Tracing**: Jaeger for distributed tracing
- **Alerting**: Prometheus Alertmanager for alert routing

## Storage Architecture

### 1. Storage Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│                          Storage Hierarchy                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Primary Storage (AGLSRV1)                                    │
│  ├─ NFS Storage (File-based)                                   │
│  │  ├─ /mnt/aglsrv1/data (VM Storage)                          │
│  │  ├─ /mnt/aglsrv1/backups (Backup Storage)                   │
│  │  └─ /mnt/aglsrv1/iso (ISO Storage)                         │
│  │                                                              │
│  ├─ iSCSI Storage (Block-based)                                │
│  │  ├─ LUN 0 (500GB) - Main Storage                            │
│  │  ├─ LUN 1 (1TB) - Backup Storage                            │
│  │  └─ LUN 2 (2TB) - Archive Storage                           │
│  │                                                              │
│  └─ PBS Storage (Backup Storage)                               │
│     ├─ agl-backups (Daily Backups)                             │
│     └─ agl-archive (Monthly Archives)                          │
│                                                                 │
│  Secondary Storage (AGLSRV6/6b)                                │
│  ├─ Local Storage (Tier 2)                                     │
│  └─ Replicated Storage                                         │
│                                                                 │
│  Compute Storage (FGSRV5/6)                                    │
│  └─ Local Storage + NFS Mounts                                │
└─────────────────────────────────────────────────────────────────┘
```

### 2. Storage Protocol Comparison

| Protocol | Use Case | Performance | Complexity | Features |
|----------|----------|-------------|------------|----------|
| **NFS** | File sharing | High | Medium | Directory operations, file locking |
| **iSCSI** | Block storage | Very High | High | Raw block access, LUN management |
| **PBS** | Backup storage | Medium | High | Incremental backups, deduplication |

### 3. Storage Optimization

- **Caching**: Redis for frequently accessed data
- **Compression**: Zstandard for backup compression
- **Deduplication**: PBS for backup deduplication
- **Tiering**: Hot/warm/cold storage tiers
- **Replication**: Real-time replication across hosts

## Network Architecture

### 1. Network Topology

```
┌─────────────────────────────────────────────────────────────────┐
│                         Network Topology                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│                           Tailscale                            │
│                           VPN Mesh                              │
│                           100.64.x.x/32                        │
│                                 │                              │
│    ┌─────────────────────────────────────────────────────────┐  │
│    │                    AGLSRV1                              │  │
│    │                  100.x.x.x                               │  │
│    │                                                         │  │
│    │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │  │
│    │  │   NFS       │  │   iSCSI     │  │     PBS     │     │  │
│    │  │   Server    │  │   Target    │  │   Server    │     │  │
│    │  │ Port 2049   │  │ Port 3260  │  │ Port 8007   │     │  │
│    │  └─────────────┘  └─────────────┘  └─────────────┘     │  │
│    │                                                         │  │
│    └─────────────────────────────────────────────────────────┘  │
│                                 │                              │
│    ┌─────────────────────────────────────────────────────────┐  │
│    │                    AGLSRV6/6b                           │  │
│    │                  100.x.x.x                               │  │
│    │                                                         │  │
│    │  ┌─────────────┐  ┌─────────────┐                       │  │
│    │  │   NFS       │  │   iSCSI     │                       │  │
│    │  │   Client    │  │   Initiator │                       │  │
│    │  └─────────────┘  └─────────────┘                       │  │
│    │                                                         │  │
│    └─────────────────────────────────────────────────────────┘  │
│                                 │                              │
│    ┌─────────────────────────────────────────────────────────┐  │
│    │                    FGSRV5/6                             │  │
│    │                  100.x.x.x                               │  │
│    │                                                         │  │
│    │  ┌─────────────┐  ┌─────────────┐                       │  │
│    │  │   Proxmox   │  │   Compute   │                       │  │
│    │  │   VMs       │  │   Workload  │                       │  │
│    │  └─────────────┘  └─────────────┘                       │  │
│    │                                                         │  │
│    └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 2. Network Security

- **Tailscale VPN**: Encrypted mesh network
- **Firewall Rules**: Restrict access to specific ports
- **Network Segmentation**: Separate networks for storage and compute
- **Load Balancing**: HAProxy for load distribution

### 3. Network Optimization

- **Jumbo Frames**: 9000 MTU for high-throughput transfers
- **QoS**: Quality of service for storage traffic
- **Bonding**: Network teaming for redundancy
- **Caching**: DNS and file caching

## Monitoring Architecture

### 1. Monitoring Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                        Monitoring Stack                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │   Metrics   │  │    Logs     │  │  Tracing    │            │
│  │             │  │             │  │             │            │
│  └─────────────┘  └─────────────┘  └─────────────┘            │
│         │                 │                 │                 │
│         ▼                 ▼                 ▼                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                   Collection Layer                       │  │
│  │ - Prometheus Exporters    - Log Forwarders             │  │
│  │ - Node Exporters         - Fluentd Agents              │  │
│  │ - Application Exporters   - Jaeger Agents               │  │
│  └─────────────────────────────────────────────────────────┘  │
│         │                 │                 │                 │
│         ▼                 ▼                 ▼                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                   Storage Layer                        │  │
│  │ - Prometheus TSDB        - Loki Log Storage             │  │
│  │ - Alert Rules            - Indexing & Processing       │  │
│  └─────────────────────────────────────────────────────────┘  │
│         │                 │                 │                 │
│         ▼                 ▼                 ▼                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                   Visualization Layer                   │  │
│  │ - Grafana Dashboards    - Log Queries                 │  │
│  │ - Alert Notifications   - Trace Visualization        │  │
│  └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 2. Monitoring Metrics

#### System Metrics
- **CPU Usage**: Per-core and aggregate CPU usage
- **Memory Usage**: RAM and swap usage
- **Disk Usage**: Disk space and I/O metrics
- **Network Usage**: Bandwidth and latency metrics

#### Application Metrics
- **API Response Times**: API endpoint performance
- **Error Rates**: Application error rates
- **Database Metrics**: Query performance and connection counts
- **Cache Metrics**: Hit rates and performance

#### Storage Metrics
- **NFS Performance**: Read/write speeds and latency
- **iSCSI Performance**: Block device performance
- **PBS Metrics**: Backup progress and success rates

### 3. Alerting Configuration

#### Critical Alerts
- Service health issues
- High resource usage (>90%)
- Backup failures
- Network connectivity issues

#### Warning Alerts
- Medium resource usage (>70%)
- Disk space warnings (>80%)
- Performance degradation
- Certificate expiration

## Backup Architecture

### 1. Backup Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                          Backup Strategy                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │   Daily     │  │   Weekly   │  │   Monthly   │            │
│  │   Backups   │  │   Backups  │  │   Backups   │            │
│  └─────────────┘  └─────────────┘  └─────────────┘            │
│         │                 │                 │                 │
│         ▼                 ▼                 ▼                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                 Backup Storage                         │  │
│  │ - AGLSRV1 (Local)    - AGLSRV6 (Replicated)           │  │
│  │ - Offsite Storage    - Cloud Storage                  │  │
│  └─────────────────────────────────────────────────────────┘  │
│         │                 │                 │                 │
│         ▼                 ▼                 ▼                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                 Backup Verification                     │  │
│  │ - Integrity Checks    - Recovery Testing               │  │
│  │ - Automated Testing   - Compliance Verification        │  │
│  └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 2. Backup Types

#### Full Backups
- Complete system state
- All data and configurations
- Scheduled monthly

#### Incremental Backups
- Changes since last backup
- Faster and more efficient
- Scheduled daily

#### Differential Backups
- Changes since last full backup
- Balance between full and incremental
- Scheduled weekly

### 3. Backup Retention

| Backup Type | Retention Period | Purpose |
|-------------|------------------|---------|
| Hourly | 24 hours | Point-in-time recovery |
| Daily | 7 days | Recent data recovery |
| Weekly | 4 weeks | Weekly recovery points |
| Monthly | 12 months | Long-term retention |
| Yearly | 7 years | Archival purposes |

## Security Architecture

### 1. Security Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                          Security Layers                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │   Physical  │  │   Network   │  │    Host     │            │
│  │   Security   │  │   Security  │  │   Security  │            │
│  └─────────────┘  └─────────────┘  └─────────────┘            │
│         │                 │                 │                 │
│         ▼                 ▼                 ▼                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                Application Security                       │  │
│  │ - Input Validation    - Output Encoding               │  │
│  │ - Session Management  - API Security                  │  │
│  └─────────────────────────────────────────────────────────┘  │
│         │                 │                 │                 │
│         ▼                 ▼                 ▼                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                Data Security                           │  │
│  │ - Encryption at Rest   - Encryption in Transit       │  │
│  │ - Access Control      - Data Masking                │  │
│  └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 2. Authentication Methods

- **JWT (JSON Web Tokens)**: Stateless authentication
- **OAuth 2.0**: Third-party authentication
- **LDAP/Active Directory**: Enterprise authentication
- **API Keys**: Programmatic access

### 3. Authorization Levels

| Role | Permissions | Description |
|------|-------------|-------------|
| **Administrator** | Full system access | Can manage all aspects |
| **Storage Admin** | Storage management | Can manage storage systems |
| **Monitoring Admin** | Monitoring access | Can view monitoring data |
| **Backup Admin** | Backup management | Can manage backups |
| **Viewer** | Read-only access | Can view system status |

## Deployment Architecture

### 1. Deployment Types

#### Production Deployment
- Load balancers for high availability
- Multiple instances for redundancy
- Monitoring and alerting
- Regular backups

#### Staging Deployment
- Mirror production environment
- Testing for new features
- Performance testing
- Integration testing

#### Development Deployment
- Simplified configuration
- Development tools
- Local testing
- Rapid iteration

### 2. Scaling Strategy

#### Horizontal Scaling
- Add more application instances
- Load balancing across instances
- Database sharding
- Caching layer

#### Vertical Scaling
- Increase server resources
- CPU and memory upgrades
- Storage expansion
- Network capacity

### 3. Disaster Recovery

#### High Availability
- Redundant components
- Failover mechanisms
- Load balancing
- Health checks

#### Backup and Recovery
- Regular backups
- Point-in-time recovery
- Offsite storage
- Testing procedures

## Performance Architecture

### 1. Performance Optimization

#### Caching Strategy
- **Redis**: Session data and frequently accessed data
- **CDN**: Static assets delivery
- **Browser Caching**: Client-side caching
- **Database Caching**: Query result caching

#### Database Optimization
- **Indexing**: Strategic indexes for fast queries
- **Partitioning**: Large table partitioning
- **Connection Pooling**: Efficient database connections
- **Query Optimization**: Efficient query execution

#### Network Optimization
- **Compression**: Data compression for transfers
- **Connection Pooling**: Reuse network connections
- **Load Balancing**: Distribute network traffic
- **Protocol Optimization**: Efficient protocols

### 2. Performance Monitoring

#### Key Metrics
- **Response Times**: API and application response times
- **Throughput**: Requests per second
- **Resource Usage**: CPU, memory, disk, network
- **Error Rates**: Application and system errors

#### Performance Testing
- **Load Testing**: High concurrent users
- **Stress Testing**: Beyond capacity limits
- **Spike Testing**: Sudden load increases
- **Endurance Testing**: Long-term performance

## Future Architecture

### 1. Planned Enhancements

#### Cloud Integration
- Hybrid cloud architecture
- Cloud storage integration
- Multi-region deployment
- Cloud-native services

#### AI/ML Integration
- Predictive analytics
- Anomaly detection
- Automated optimization
- Intelligent backup scheduling

#### Edge Computing
- Edge node deployment
- Local processing
- Reduced latency
- Distributed storage

### 2. Technology Roadmap

#### Short Term (6 months)
- Enhanced monitoring
- Improved backup system
- Performance optimization
- Security enhancements

#### Medium Term (12 months)
- Cloud integration
- AI/ML capabilities
- Edge computing
- Advanced analytics

#### Long Term (24 months)
- Complete cloud-native architecture
- Full AI automation
- Global deployment
- Advanced security features

---

*Next: [Storage Protocols](storage-protocols.md)*

*Previous: [Installation Guide](../getting-started/installation.md)*