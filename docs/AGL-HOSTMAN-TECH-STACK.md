# AGL Hostman - Technology Stack & Tools

> **Project**: AGL Hostman
> **Last Updated**: 2026-01-04
> **Type**: Infrastructure Management Platform

---

## 🎯 Backend Stack

### Core Framework
**Laravel 12** (PHP 8.4)
- Modern PHP framework for web artisans
- Robust MVC architecture
- Eloquent ORM for database operations
- Blade templating engine
- Artisan CLI tool

**Key Dependencies**:
```json
{
  "laravel/framework": "^12.0",
  "laravel/horizon": "^5.39",           // Queue management
  "laravel/reverb": "^1.6",             // Real-time WebSocket
  "laravel/sanctum": "^4.2",            // API authentication
  "laravel/socialite": "*",             // OAuth2 integration
  "laravel/telescope": "^5.15",         // Debug assistant
  "laravel/tinker": "^2.10.1"           // REPL console
}
```

### Authentication & Authorization
**WorkOS** (v4.27.0)
- Enterprise-grade identity provider
- OAuth2/OIDC authentication
- SSO integration
- User management

**Spatie Laravel Permission** (v6.23)
- Role-based access control (RBAC)
- Permission management
- User-role assignments

**Laravel Sanctum** (v4.2)
- API token authentication
- SPA authentication
- Mobile app support

---

### Frontend Stack

**React 18** with Modern Build Tools
```json
{
  "@inertiajs/react": "^2.0.1",         // Server-side routing
  "@dnd-kit/core": "^6.1.0",            // Drag & drop
  "@radix-ui/react-*": "latest",        // UI components
  "tailwindcss": "^4.0.0",              // Utility CSS
  "vite": "^7.2.2"                      // Build tool
}
```

**UI Component Libraries**:
- Radix UI (headless components)
- Tailwind CSS (styling)
- shadcn (component templates)

**Build Tools**:
- Vite 7.2.2 (fast HMR)
- Laravel Vite Plugin
- Tailwind Vite Plugin

---

## 🗄️ Database Layer

### Primary Databases
**MySQL 8.0** (Planned - TASK-006)
- Primary data storage
- Business logic data
- User information
- Transactional data

**Redis 7** (Configured)
- Caching layer
- Session storage
- Queue management
- Real-time data

**PostgreSQL 15** (Supabase - CT184)
- Archon MCP knowledge base
- Vector similarity search (PGVector)
- JSON document storage
- Full-text search

**SQLite** (Development)
- Local development fallback
- Testing database
- Lightweight prototyping

---

## 🐳 Container & Orchestration

### Docker Environment
**Docker Compose V2**
- Multi-container orchestration
- Service definition
- Volume management
- Network configuration

**LXC Containers** (Proxmox)
- 70 total containers across 3 hosts
- Lightweight virtualization
- Resource isolation
- Fast deployment

**Key Configuration** (for LXC with Docker):
```ini
features: keyctl=1,nesting=1,fuse=1
lxc.apparmor.profile = unconfined
lxc.cgroup2.devices.allow: c *:* rwm
lxc.cap.drop:
```

---

## 🚀 DevOps & CI/CD

### Deployment Platform
**Dokploy** (CT180)
- Continuous deployment
- GitHub integration
- Zero-downtime deployments
- Application management

**Harbor Registry** (CT182)
- Docker image registry
- Image vulnerability scanning
- Replication management
- Access control

### CI/CD Pipeline
**GitHub Actions**
- Automated builds (150s, 79% improvement)
- Parallel test execution (2.8-4.4x faster)
- Deployment automation
- DORA metrics tracking

**Performance Metrics**:
- Build time: 150s (down from 720s)
- Image size: 280MB (down from 450MB)
- Cache hit rate: 80%+

---

## 🤖 AI & Automation

### Archon MCP (CT183)
**28 Tools Available**:
- Knowledge base search (RAG)
- Project management
- Task tracking
- Document indexing
- Code examples repository

**Technology Stack**:
- Python 3.12
- FastAPI (REST + WebSocket)
- Supabase (PostgreSQL + PGVector)
- OpenAI embeddings
- Crawl4AI (web crawling)

**Endpoints**:
- MCP Server: `http://192.168.0.183:8051/mcp`
- API: `http://192.168.0.183:8181`
- UI: `http://192.168.0.183:3737`

### Supabase Self-Hosted (CT184)
**13 Containers**:
- PostgreSQL 15.8
- Kong API Gateway
- PostgREST
- GoTrue Auth
- Storage API
- Realtime
- Studio Dashboard

---

## 🌐 Networking

### VPN & Overlay Networks
**WireGuard Mesh** (Primary)
- Fast, low-latency (< 5ms)
- 14 active nodes
- Network: 10.6.0.0/24
- Hub: AGLFS1 (10.6.0.5)

**Tailscale** (Backup/Cross-site)
- Remote access
- Cross-site VPN
- Network: 100.x.x.x
- Fallback connectivity

### DNS & DHCP
**Pi-hole** (CT102)
- DNS server: 192.168.0.102
- DHCP configuration
- Ad blocking
- Network monitoring

---

## 📊 Monitoring & Observability

### Infrastructure Monitoring
**Observium** (CT132)
- Network monitoring
- Device discovery
- Alerting
- Traffic analysis

### Application Monitoring
**Laravel Telescope**
- Debug assistant
- Request tracking
- Query monitoring
- Exception handling

**Laravel Horizon**
- Queue management
- Job monitoring
- Failed job tracking
- Performance metrics

---

## 🔒 Security

### Authentication
- WorkOS OAuth2 (production)
- Laravel Sanctum (API tokens)
- Redis session storage
- JWT tokens (Supabase)

### Authorization
- Spatie Laravel Permission (RBAC)
- Role-based access control
- Permission middleware
- User-role assignments

### Infrastructure Security
- LXC container isolation
- WireGuard encryption
- Tailscale VPN
- Proxmox security updates

---

## 🛠️ Development Tools

### IDE & Editors
- **Claude Code** (Primary AI assistant)
- **Cursor** (AI-powered IDE)
- **VS Code** (Backend development)

### Version Control
- **Git** (version control)
- **GitHub** (code hosting)
- **GitHub Actions** (CI/CD)

### Package Managers
- **Composer** (PHP packages)
- **npm/pnpm** (Node.js packages)
- **Docker Hub** (container images)

---

## 📚 Documentation

### Primary Documentation
- `INFRA.md` - Infrastructure overview
- `QUICK-START.md` - Quick start guide
- `CONTAINERS.md` - Container inventory
- `ARCHON.md` - Archon MCP integration
- `DEPLOYMENT-GUIDE.md` - Deployment procedures

### Task Documentation
- `TASK-006` - Multi-database setup
- `TASK-007` - WorkOS authentication
- `TASK-008` - RBAC implementation

### Troubleshooting
- `docker-in-lxc-apparmor-solution.md` - Docker fixes
- `ARCHON-SUPABASE-FIX-2026-01.md` - Archon troubleshooting

---

## 🎯 Best Practices

### Development
- **Test-Driven Development**: Write tests first
- **Code Reviews**: Peer review process
- **Documentation**: Document as you code
- **Git Workflow**: Feature branches, PR reviews

### Deployment
- **Zero-Downtime**: Blue-green deployments
- **Rollback Ready**: Quick reversion capability
- **Automated Testing**: Parallel test execution
- **Monitoring**: Real-time metrics

### Infrastructure
- **Container First**: Dockerize everything
- **LXC Isolation**: Separate concerns
- **Mesh Networking**: WireGuard for speed
- **Backup Strategy**: Multiple backup layers

---

## 📈 Performance Optimizations

### Build Performance
- **Multi-stage builds**: Reduce image size
- **Layer caching**: 80%+ hit rate
- **Parallel execution**: 2.8-4.4x faster tests
- **Build time**: 150s (79% improvement)

### Runtime Performance
- **Redis caching**: Fast data access
- **Connection pooling**: Database efficiency
- **Queue workers**: Asynchronous processing
- **CDN ready**: Static asset delivery

---

## 🔧 Configuration Files

### Backend
- `.env` - Environment variables
- `composer.json` - PHP dependencies
- `config/*.php` - Laravel configs

### Frontend
- `package.json` - Node dependencies
- `vite.config.js` - Build configuration
- `tailwind.config.js` - Styling config

### Infrastructure
- `docker-compose.yml` - Container orchestration
- `/etc/pve/lxc/*.conf` - LXC configurations
- WireGuard peer configs

---

## 🎓 Learning Resources

### Official Documentation
- [Laravel 12 Docs](https://laravel.com/docs/12.x)
- [React 18 Docs](https://react.dev)
- [Supabase Docs](https://supabase.com/docs)
- [Docker Docs](https://docs.docker.com)

### Internal Documentation
- `docs/` - Complete project docs
- `.claude/commands/` - Custom commands
- `src/ai-docs/` - AI assistant prompts

---

**Version**: 1.0.0
**Last Updated**: 2026-01-04
**Maintained By**: Development Team
**Next Review**: Monthly
