# AGL Hostman Skills Registry

This document serves as a central registry for all Claude Code skills available in the agl-hostman project. Skills are specialized instruction sets that guide Claude Code in adhering to specific coding standards, best practices, and architectural patterns.

## What Are Skills?

Skills are modular instruction files (stored in `.claude/skills/*/SKILL.md`) that provide Claude Code with domain-specific guidance. Each skill contains:

- **Name**: Clear identifier for the skill
- **Description**: When and how to use the skill
- **Instructions**: Links to standards documentation
- **Examples**: Usage patterns and expected outcomes

## Available Skills

### Backend Development

| Skill | Description |
|-------|-------------|
| `pest-testing` | Pest PHP testing framework patterns including unit vs integration tests, mocking, factories, and test organization |
| `laravel-migrations` | Laravel migration design patterns, index strategies, rollback safety, and data seeding |
| `laravel-performance-optimization` | Comprehensive Laravel performance optimization covering caching strategies, query optimization, eager loading, lazy evaluation, and HTTP caching |
| `rest-api-design` | REST API design principles, resource naming, HTTP methods, status codes, pagination, and filtering |
| `database-migration-optimization` | Safe database migrations with zero-downtime strategies, rollback procedures, and testing for MySQL, PostgreSQL, and SQLite |
| `php-modern-standards` | Modern PHP 8+ features including typed properties, named arguments, enums, PSR standards compliance, and static analysis tools |
| `laravel-best-practices` | Laravel best practices for service patterns, repository pattern, middleware, request validation, form requests, and API standards |
| `backend-api` | Design and implement RESTful API endpoints following REST principles with proper HTTP methods, status codes, and resource-based conventions |
| `backend-migrations` | Create and manage database schema migrations with proper rollback support, versioning, and data integrity considerations |
| `backend-models` | Define database models and ORM entities with proper naming conventions, relationships, validation rules, and indexing strategies |
| `backend-queries` | Write efficient, secure database queries with proper parameterization, optimization, N+1 prevention, and transaction handling |

### Frontend Development

| Skill | Description |
|-------|-------------|
| `frontend-accessibility` | Implement accessible user interfaces following WCAG 2.1 AA standards with proper ARIA labels, keyboard navigation, focus management, and screen reader support |
| `frontend-components` | Design and build reusable, composable UI components with clear props, event handling, state management, and documentation |
| `frontend-css` | Write and maintain CSS following the project's chosen methodology (BEM, CSS-in-JS, Tailwind) with consistent naming, organization, and responsive design |
| `frontend-responsive` | Implement responsive designs using mobile-first development with fluid typography, flexible grids, breakpoint strategies, and touch-friendly interactions |

### GitHub & Repository Management

| Skill | Description |
|-------|-------------|
| `github-code-review` | Comprehensive GitHub pull request code review with AI-powered analysis, security checks, performance assessment, and best practice validation |
| `github-multi-repo` | Multi-repository coordination, synchronization, and architecture management across related projects and monorepo structures |
| `github-project-management` | Comprehensive GitHub project management with swarm-coordinated task tracking, milestone planning, and progress visualization |
| `github-release-management` | Complete GitHub release orchestration with version tagging, changelog generation, and distribution across platforms |
| `github-workflow-automation` | Advanced GitHub Actions workflow automation with AI swarm coordination for CI/CD pipelines, testing, and deployment |

### Global Standards

| Skill | Description |
|-------|-------------|
| `global-coding-style` | Maintain consistent code formatting, naming conventions, and style guidelines across all programming languages and file types in the codebase |
| `global-commenting` | Write self-documenting code with minimal, helpful comments explaining complex logic, algorithms, workarounds, and architectural decisions |
| `global-conventions` | Follow team-wide development conventions including project structure, version control practices, environment configuration, and documentation standards |
| `global-error-handling` | Implement robust error handling with user-friendly messages, proper logging, error recovery strategies, and appropriate HTTP status codes |
| `global-infrastructure-management` | Manage and configure AGL infrastructure including multi-server setup, networking, storage, monitoring, and deployment orchestration |
| `global-tech-stack` | Define and maintain the project's technical stack including languages, frameworks, databases, tools, and their version requirements |
| `global-validation` | Implement comprehensive input validation with server-side checks, sanitization, type checking, and user-friendly error messages for all user inputs |

### Swarm & Coordination

| Skill | Description |
|-------|-------------|
| `agent-spawning` | Worker agent creation, specialization patterns, resource allocation, and load balancing for hierarchical swarm systems |
| `byzantine-consensus` | Byzantine fault tolerance, voting mechanisms, conflict resolution, and agreement protocols for distributed agent systems |
| `hive-mind-coordinator` | Hive Mind coordination, queen agent orchestration, strategic decision making, and swarm-level optimization |
| `task-distribution` | Task distribution across swarm agents, workload balancing, priority queues, and dependency management |
| `swarm-communication` | Agent-to-agent communication protocols, message passing, event broadcasting, and memory coordination |
| `hive-mind-advanced` | Advanced Hive Mind collective intelligence system for query optimization, pattern recognition, and distributed decision-making across agents |
| `hive-mind-consensus` | Build consensus across multiple Hive Mind agents using voting mechanisms, conflict resolution, and agreement protocols for coordinated decisions |
| `hooks-automation` | Automated coordination, formatting, and learning from Claude Code hooks integration for workflow automation and skill development |
| `pair-programming` | AI-assisted pair programming with multiple collaboration modes including driver-navigator, ping-pong, and mob programming patterns |
| `swarm-advanced` | Advanced swarm orchestration patterns for distributed resource management, adaptive topologies, and large-scale parallel task execution |
| `swarm-orchestration` | Coordinate multiple AI agents in a hierarchical structure with clear command chains, responsibility delegation, and synchronized execution |

### Claude Flow V3

| Skill | Description |
|-------|-------------|
| `v3-cli-modernization` | CLI modernization and hooks system enhancement for claude-flow v3 with interactive prompts, command decomposition, and workflow automation |
| `v3-core-implementation` | Core module implementation for claude-flow v3 including domain models, services, repositories, and business logic layer |
| `v3-ddd-architecture` | Domain-Driven Design architecture for claude-flow v3 with bounded contexts, aggregates, entities, value objects, and domain events |
| `v3-integration-deep` | Deep agentic-flow@alpha integration implementing ADR-001 architecture decisions with MCP tool coordination |
| `v3-mcp-optimization` | MCP server optimization and transport layer enhancement for improved performance and reliability |
| `v3-memory-unification` | Unify 6+ memory systems into AgentDB with HNSW indexing for fast semantic search and cross-system pattern matching |
| `v3-performance-optimization` | Achieve aggressive v3 performance targets: 2.49x-7.47x Flow improvement, sub-100M memory usage, <200ms command response |
| `v3-security-overhaul` | Complete security architecture overhaul for claude-flow v3 including authentication, authorization, encryption, and audit logging |
| `v3-swarm-coordination` | 15-agent hierarchical mesh coordination for v3 implementation with memory sharing and distributed task execution |

### AI & Learning

| Skill | Description |
|-------|-------------|
| `agentdb-advanced` | Master advanced AgentDB features including QUIC synchronization, HNSW vector search, distributed transactions, and performance tuning |
| `agentdb-learning` | Create and train AI learning plugins with AgentDB's 9 reinforcement learning algorithms and integrated optimization strategies |
| `agentdb-memory-patterns` | Implement advanced memory pattern recognition, storage, and retrieval using AgentDB's vector embeddings and semantic search |
| `agentdb-optimization` | Optimize AgentDB performance with quantization techniques, caching strategies, indexing methods, and query optimization |
| `agentdb-vector-search` | Implement high-performance vector similarity search using AgentDB's HNSW indexing for semantic pattern matching |
| `flow-nexus-neural` | Train and deploy neural networks in distributed E2B sandboxes with GPU acceleration, model versioning, and A/B testing |
| `flow-nexus-platform` | Comprehensive Flow Nexus platform management covering user management, project organization, resource allocation, and billing |
| `flow-nexus-swarm` | Deploy and manage cloud-based AI agent swarms with event-driven coordination, auto-scaling, and monitoring dashboards |
| `reasoningbank-agentdb` | Implement ReasoningBank adaptive learning with AgentDB's pattern storage and retrieval for contextual decision support |
| `reasoningbank-intelligence` | Implement adaptive learning with ReasoningBank for pattern recognition, decision optimization, and continuous improvement |

### Methodology

| Skill | Description |
|-------|-------------|
| `sparc-methodology` | SPARC (Specification, Pseudocode, Architecture, Refinement, Completion) systematic development methodology with TDD workflow |
| `stream-chain` | Stream-JSON chaining for multi-agent pipelines enabling sequential data processing, transformation, and validation |

### Testing & Quality

| Skill | Description |
|-------|-------------|
| `testing-test-writing` | Write strategic, behavior-focused tests that cover core user behaviors, edge cases, and acceptance criteria with clear test names |
| `verification-quality` | Comprehensive truth scoring, code quality verification, and validation against project standards and requirements |

### DevOps & Infrastructure

| Skill | Description |
|-------|-------------|
| `docker-container-orchestration` | Docker container orchestration, multi-container management, networking, volume management, and Docker Compose |
| `infrastructure-as-code` | Infrastructure as Code with Ansible, Terraform, configuration management, and environment provisioning |
| `harbor-registry-operations` | Harbor registry operations including image pushing, pulling, tagging, retention policies, and webhook integration |
| `wireguard-network-management` | WireGuard VPN setup, peer management, network routing, firewall configuration, and secure tunneling |
| `backup-automation-verification` | Automated backup systems, backup verification, disaster recovery, and restoration procedures |
| `infrastructure-diagnostics` | Infrastructure diagnostics, health checks, system monitoring, log analysis, and troubleshooting procedures |
| `database-high-availability` | Database high availability setup, replication, failover, clustering, and backup strategies for MySQL and PostgreSQL |
| `proxmox-infrastructure-management` | Proxmox VE management, VM/CT operations, storage management, clustering, and resource allocation |
| `browser` | Web browser automation with AI-optimized snapshots for crawling, testing, and data extraction from web applications |
| `devops` | DevOps practices including CI/CD pipelines, infrastructure as code, container orchestration, monitoring, and incident response |

### Utility

| Skill | Description |
|-------|-------------|
| `performance-analysis` | Comprehensive performance analysis, bottleneck detection, optimization opportunities, and monitoring strategy recommendations |
| `skill-builder` | Create production-ready Claude Code Skills with proper YAML frontmatter, descriptions, examples, and validation |

## Skill Management

### List All Skills

```bash
# List all skills in table format
python scripts/skills/list_skills.py

# List as JSON
python scripts/skills/list_skills.py --format json

# List by category
python scripts/skills/list_skills.py --category "Backend Development"

# Simple list format
python scripts/skills/list_skills.py --format simple
```

### Search Skills

```bash
# Search by keyword
python scripts/skills/search_skills.py "API"

# Search in specific fields
python scripts/skills/search_skills.py "testing" --fields name,description

# Fuzzy search
python scripts/skills/search_skills.py "pr" --fuzzy

# Output as JSON
python scripts/skills/search_skills.py "github" --format json
```

### Validate Skills

```bash
# Validate a specific skill
python scripts/skills/validate_skill.py backend-api

# Validate all skills
python scripts/skills/validate_skill.py --all

# Show warnings and info
python scripts/skills/validate_skill.py --all --verbose

# Output as JSON
python scripts/skills/validate_skill.py --all --json
```

### Create New Skill

```bash
# Create a new skill from template
python scripts/skills/init_skill.py "API Design" --category backend

# With custom description and tags
python scripts/skills/init_skill.py "React Hooks" \
  --description "Best practices for React hooks" \
  --category frontend \
  --tags react,hooks,frontend

# Available categories: backend, frontend, devops, testing,
# documentation, security, performance, methodology
```

## Skill Structure

Each skill follows this structure:

```markdown
---
name: Skill Name
description: Detailed description of when and how to use this skill
tags: tag1, tag2, tag3
version: 1.0.0
---

# Skill Name

This Skill provides Claude Code with specific guidance...

## When to use this skill:

- Bullet list of scenarios
- When this skill applies
- What triggers its use

## Instructions

For details, refer to the information provided in this file:
[reference](../../../path/to/standards/reference.md)

## Examples

### Example 1
```bash
# Command example
```

**Outcome**: What this accomplishes

## Related Skills

- `related-skill` - Description
```

## Contributing

When adding new skills:

1. Use the init script: `python scripts/skills/init_skill.py "Name" --category CATEGORY`
2. Edit the generated SKILL.md with specific instructions
3. Validate the skill: `python scripts/skills/validate_skill.py skill-name`
4. Update this registry with the new skill

## Skills Directory Structure

```
.claude/skills/
├── backend-api/
│   └── SKILL.md
├── frontend-components/
│   └── SKILL.md
├── global-conventions/
│   └── SKILL.md
└── ...
```

## Antigravity Awesome Skills (Cursor)

713+ skills disponíveis em `~/.cursor/skills` — use `@skill-name` no chat do Cursor.

Ver **ai-docs/ANTIGRAVITY_SKILLS_RECOMMENDED.md** para a lista de skills recomendadas ao parque tecnológico (Docker, Node.js, Laravel, Vue, Tailwind, AgentDB, etc.).

## Related Documentation

- **CLAUDE.md**: Main project configuration and agent instructions
- **agent-os/standards/**: Detailed coding standards and best practices
- **scripts/skills/**: Skill management utilities
- **docs/skills/implementation-summary.md**: Complete skills implementation summary
- **.agent/skills/skills_index.json**: Machine-readable skills index with all 27 skills
- **ai-docs/ANTIGRAVITY_SKILLS_RECOMMENDED.md**: Skills Antigravity recomendadas para o parque tecnológico

## AGL Hostman Skills (Phase 1-3)

### Phase 1: Core Development Skills (7 skills)

1. **pest-testing** - Pest PHP testing framework patterns
2. **laravel-migrations** - Laravel migration design patterns
3. **laravel-performance-optimization** - Comprehensive performance optimization
4. **rest-api-design** - REST API design principles
5. **database-migration-optimization** - Zero-downtime database migrations
6. **php-modern-standards** - Modern PHP 8+ features
7. **laravel-best-practices** - Laravel best practices

### Phase 2: Monitoring & Infrastructure Skills (12 skills)

8. **alert-management** - Alert lifecycle and notifications
9. **query-optimization** - Database query optimization
10. **redis-caching** - Redis caching strategies
11. **monitoring-analytics-predictive** - Predictive analytics
12. **harbor-registry** - Container registry integration
13. **performance-monitoring** - Performance metrics tracking
14. **wireguard-network-management** - VPN configuration
15. **backup-automation-verification** - Backup systems
16. **infrastructure-diagnostics** - Health monitoring
17. **database-high-availability** - HA database setup
18. **proxmox-infrastructure-management** - Proxmox operations
19. **network-traffic-analysis-optimization** - Network traffic monitoring

### Phase 3: DevOps & Swarm Coordination Skills (8 skills)

20. **docker-container-orchestration** - Docker management
21. **infrastructure-as-code** - IaC with Ansible/Terraform
22. **harbor-registry-operations** - Registry operations
23. **agent-spawning** - Worker agent management
24. **byzantine-consensus** - Fault tolerance
25. **hive-mind-coordinator** - Swarm orchestration
26. **task-distribution** - Workload distribution
27. **swarm-communication** - Agent communication

## Related Documentation

- **CLAUDE.md**: Main project configuration and agent instructions
- **agent-os/standards/**: Detailed coding standards and best practices
- **scripts/skills/**: Skill management utilities
- **docs/skills/implementation-summary.md**: Complete skills implementation summary
- **.agent/skills/skills_index.json**: Machine-readable skills index with all 27 skills
