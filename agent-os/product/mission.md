# Product Mission

## Pitch

AGL Hostman is an **Infrastructure Management Platform** that helps **DevOps engineers, system administrators, and infrastructure teams** **manage complex Proxmox-based containerized environments** by providing **centralized control, real-time monitoring, and AI-powered automation** across distributed multi-location infrastructure.

## Users

### Primary Customers

- **DevOps Engineers**: Managing production containerized infrastructure (70+ LXC containers) across multiple Proxmox hosts
- **System Administrators**: Responsible for day-to-day host management, maintenance, and monitoring of homelab or SMB infrastructure
- **Infrastructure Teams**: Coordinating multi-location deployments and ensuring high availability across distributed sites
- **Homelab Enthusiasts**: Self-hosting infrastructure management for personal projects and learning

### User Personas

**DevOps Engineer** (25-45 years old)
- **Role:** Senior DevOps Engineer or Infrastructure Lead at SMB/Mid-size company
- **Context:** Managing production infrastructure with 50-200 containers across 3-5 physical hosts across multiple locations. Team of 2-5 engineers. Need to ensure 99.9% uptime while maintaining rapid deployment velocity.
- **Pain Points:**
  - Fragmented management across different hosts and locations
  - Manual deployment processes leading to downtime
  - Lack of real-time visibility into container health
  - Time-consuming incident response and troubleshooting
  - Difficulty maintaining consistent configurations across environments
- **Goals:**
  - Single pane of glass for all infrastructure management
  - Zero-downtime CI/CD deployments
  - Proactive monitoring with predictive maintenance
  - Automated backup and disaster recovery
  - Reduce time spent on routine maintenance by 60%

**System Administrator** (30-50 years old)
- **Role:** SysAdmin or IT Manager managing on-premise infrastructure
- **Context:** Managing 10-100 servers/containers for business operations. Limited team size (1-3 people). Responsible for uptime, security, and cost optimization.
- **Pain Points:**
  - Too many tools to manage (Proxmox, Docker, monitoring, backups)
  - Manual script-based maintenance is error-prone
  - No central dashboard for infrastructure health
  - Difficult to track and audit changes
  - Reactive rather than proactive issue management
- **Goals:**
  - Unified dashboard replacing multiple tools
  - Automated routine maintenance tasks
  - Easy container deployment and scaling
  - Quick disaster recovery (RTO < 1 hour)
  - Simplified onboarding for team members

**Infrastructure Lead** (35-55 years old)
- **Role:** Director/VP of Infrastructure or CTO at growing company
- **Context:** Managing infrastructure across 3-5 physical locations. Budget-conscious but scaling rapidly. Team of 5-15 people. Need to balance stability, security, and innovation.
- **Pain Points:**
  - Lack of visibility across distributed locations
  - Inconsistent processes and configurations between sites
  - Manual coordination for cross-site deployments
  - Difficult capacity planning and resource optimization
  - Security and compliance concerns
- **Goals:**
  - Multi-site visibility and control from single interface
  - Standardized deployment processes across locations
  - Automated failover and disaster recovery
  - Cost optimization through better resource utilization
  - Audit trail and compliance reporting

**Homelab Enthusiast** (20-40 years old)
- **Role:** Technology enthusiast running self-hosted infrastructure for personal projects
- **Context:** Managing homelab with 10-50 containers across 1-3 hosts. Learning and experimenting with new technologies. Time-constrained (evenings/weekends).
- **Pain Points:**
  - Complex setup and configuration required for each service
  - Fragmented tools for monitoring and management
  - Time-consuming manual updates and maintenance
  - Difficulty restoring from backups when things break
  - Learning curve for enterprise tools
- **Goals:**
  - Easy container deployment (one-click installs)
  - Automated backups and disaster recovery
  - Central monitoring dashboard
  - Community support and documentation
  - Professional-grade tools accessible to individuals

## The Problem

### Fragmented Infrastructure Management

Managing complex containerized infrastructure across multiple Proxmox hosts requires juggling numerous disconnected tools: Proxmox web UI for LXC containers, Docker CLI for container orchestration, separate monitoring systems (Observium, Grafana), manual backup scripts, and SSH for remote management. This fragmentation leads to **inefficient workflows, increased error rates, and extended incident response times**.

**Typical Pain Points:**
- Deploying a new application requires logging into 3-5 different systems
- Monitoring requires checking multiple dashboards (Proxmox, Docker, Observium, Grafana)
- Manual SSH-based management at scale is time-consuming and error-prone
- Backup processes are fragmented and often fail silently
- No unified audit trail across systems
- Cross-site coordination is manual and communication-heavy
- Reactive rather than proactive incident management

**Impact:** Teams spend **60-70% of their time on routine maintenance** instead of strategic improvements. Mean Time to Recovery (MTTR) averages **2-4 hours** for container failures. Configuration drift between environments causes **30% of production incidents**.

**Our Solution:** AGL Hostman provides a **unified platform** that integrates Proxmox LXC management, Docker orchestration, deployment automation (Dokploy), monitoring, backup management, and AI-powered knowledge base (Archon) into a single cohesive interface with role-based access control, real-time dashboards, and automated workflows.

## Differentiators

### Unified Multi-System Integration

Unlike **traditional infrastructure tools** (Portainer, Proxmox UI, Cockpit) that focus on a single aspect of infrastructure, AGL Hostman provides **deep integration across Proxmox LXC, Docker, Dokploy, Harbor, monitoring systems, and AI services** in a single platform with consistent UI/UX and unified authentication.

This results in:
- **70% reduction** in context-switching between tools
- **50% faster** deployments through integrated workflows
- **Single pane of glass** for complete infrastructure visibility
- **Consistent RBAC** across all systems (WorkOS + Spatie permissions)
- **Unified audit trail** for compliance and troubleshooting

### AI-Powered Knowledge & Automation

Unlike **generic infrastructure platforms**, AGL Hostman includes **Archon MCP integration** with 28 specialized tools for knowledge base search (RAG), task tracking, documentation indexing, and code examples—making tribal knowledge accessible and enabling intelligent automation.

This results in:
- **80% faster** incident resolution with AI-powered knowledge search
- **Automated documentation** generation from infrastructure changes
- **Natural language interface** for common infrastructure tasks
- **Predictive maintenance** using AI/ML on resource trends
- **Reduced onboarding time** for new team members (from weeks to days)

### Zero-Downtime Deployment Pipeline

Unlike **manual deployment processes** or basic CI/CD tools, AGL Hostman integrates **Dokploy + Harbor** for automated zero-downtime deployments with built-in image registry, vulnerability scanning, and blue-green deployments.

This results in:
- **99.9% uptime** maintained during deployments
- **Automated rollback** capability in < 30 seconds
- **79% faster** builds (150s vs 720s) through optimized CI/CD
- **Vulnerability scanning** built into deployment pipeline
- **Multi-environment support** (dev, staging, production)

### Distributed Multi-Site Architecture

Unlike **single-location infrastructure tools**, AGL Hostman is **built for distributed infrastructure** across multiple physical locations with WireGuard mesh networking (14 nodes, <5ms latency), Tailscale VPN backup, and intelligent routing.

This results in:
- **Unified management** of containers across 3+ locations
- **Automatic failover** between network paths (WireGuard → Tailscale → LAN)
- **Sub-5ms latency** for inter-container communication
- **Cross-site backup** and disaster recovery
- **Location-aware routing** for optimal performance

## Key Features

### Core Features

- **Proxmox LXC Management:** Unified control for 70+ LXC containers across 3 hosts with lifecycle management (create, start, stop, migrate), resource monitoring (CPU, RAM, disk, network), and bulk operations for efficient scaling.
- **Docker Orchestration:** Complete Docker container management with compose file support, image registry integration (Harbor), log aggregation, and resource limit enforcement for containerized workloads.
- **Real-Time Monitoring Dashboard:** Live infrastructure health metrics with container status, resource utilization graphs (CPU, memory, disk I/O, network), alert rules configuration, and historical trend analysis for capacity planning.
- **Centralized Authentication:** WorkOS OAuth2/OIDC SSO integration with enterprise identity providers (Okta, Azure AD, Google), Spatie Laravel Permission RBAC with role-based access control, API token authentication (Laravel Sanctum), and multi-location session management via Redis.

### Collaboration Features

- **Team Access Control:** Granular permissions for different user roles (Admin, Operator, Viewer) with per-host and per-container access restrictions, audit logging for all actions, and temporary access tokens for contractors.
- **Deployment Automation:** Dokploy integration for zero-downtime deployments with GitHub webhooks, automated testing integration, blue-green deployments, and instant rollback capabilities.
- **Shared Knowledge Base:** Archon MCP-powered documentation with 28 specialized tools for RAG search, task tracking, runbook indexing, code examples repository, and AI-powered incident response assistance.
- **Activity Feed:** Real-time activity stream showing deployments, container changes, system events, team actions, and automated maintenance tasks with filtering and search capabilities.

### Advanced Features

- **Predictive Maintenance:** AI/ML-powered resource trend analysis with anomaly detection, capacity forecasting (predict resource exhaustion 30+ days in advance), automated scaling recommendations, and preventative maintenance scheduling.
- **Automated Backup & Disaster Recovery:** Multi-layer backup system with snapshot-based LXC backups, Docker volume backups to Harbor/external storage, automated backup scheduling with retention policies, one-click restore functionality, and cross-site backup replication for disaster recovery.
- **Infrastructure as Code:** Docker Compose template library for common services (databases, web servers, monitoring), version-controlled infrastructure configurations, drift detection and auto-remediation, and multi-environment support (dev, staging, production).
- **Network Mesh Management:** WireGuard VPN mesh network monitoring (14 nodes), automated peer configuration, network health checks with <5ms latency verification, failover to Tailscale backup network, and network topology visualization.
- **API & Integrations:** RESTful API for all infrastructure operations, webhook integrations (GitHub, GitLab, Bitbucket), Prometheus metrics export, Grafana dashboard integration, and MCP server for AI agent orchestration.
- **Security & Compliance:** Container vulnerability scanning via Harbor, automated security patch management, SSH key rotation, audit log export for compliance (SOC2, ISO27001), and secrets management integration.
