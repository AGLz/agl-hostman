# Archon MCP Integration Guide

> **Version**: 1.0.0
> **Last Updated**: 2025-11-20
> **Archon Instance**: CT183 (archon @ AGLSRV1) — **não** confundir com **agldv07** (CT547 @ FGSRV7)

## Table of Contents

1. [Overview](#overview)
2. [MCP Protocol](#mcp-protocol)
3. [Architecture](#architecture)
4. [Available Tools](#available-tools)
5. [Usage Examples](#usage-examples)
6. [Sync Strategy](#sync-strategy)
7. [Configuration](#configuration)
8. [Testing](#testing)
9. [Troubleshooting](#troubleshooting)

---

## Overview

This Laravel application integrates bidirectionally with **Archon MCP** (CT183), providing:

- **AI-powered task management** via 28 MCP tools
- **Semantic knowledge base search** (RAG)
- **Project tracking** with GitHub integration
- **Bidirectional sync** between Laravel and Archon
- **Real-time event-driven updates**

**Archon Instance Details:**
- **Container**: CT183 (archon @ AGLSRV1)
- **WireGuard**: 10.6.0.21:8051 (fastest, production)
- **Tailscale**: 100.80.30.59:8051 (backup)
- **LAN**: 192.168.0.183:8052 (development only)
- **Public**: https://archon.aglz.io (admin/ArchonPass2025)

---

## MCP Protocol

### What is MCP?

**MCP (Model Context Protocol)** is a JSON-RPC 2.0 protocol for tool-based AI integrations. It allows applications to invoke remote AI tools and services.

### JSON-RPC 2.0 Format

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": "find_projects-20251120035700-abc123",
  "method": "tools/call",
  "params": {
    "name": "find_projects",
    "arguments": {
      "query": "infrastructure"
    }
  }
}
```

**Response (Success):**
```json
{
  "jsonrpc": "2.0",
  "id": "find_projects-20251120035700-abc123",
  "result": {
    "success": true,
    "projects": [
      {
        "id": "proj-123",
        "title": "Infrastructure Upgrade",
        "description": "Migrate to Laravel 12",
        "created_at": "2025-11-15T10:00:00Z"
      }
    ]
  }
}
```

**Response (Error):**
```json
{
  "jsonrpc": "2.0",
  "id": "find_projects-20251120035700-abc123",
  "error": {
    "code": 404,
    "message": "Project not found",
    "data": {
      "project_id": "proj-999"
    }
  }
}
```

---

## Architecture

### Components

```
┌─────────────────────────────────────────────────────────────┐
│                   Laravel Application                       │
│                                                             │
│  ┌─────────────────┐  ┌──────────────────┐                │
│  │  Controllers    │  │  Event Listeners │                │
│  │  (API/Web)      │  │  (Bidirectional) │                │
│  └────────┬────────┘  └────────┬─────────┘                │
│           │                     │                          │
│           v                     v                          │
│  ┌─────────────────────────────────────────┐              │
│  │     ArchonMcpService (Facade)           │              │
│  └───────────────┬─────────────────────────┘              │
│                  │                                         │
│                  v                                         │
│  ┌─────────────────────────────────────────┐              │
│  │   ArchonMcpClient (JSON-RPC 2.0)        │              │
│  │   - Request building                    │              │
│  │   - Retry logic                         │              │
│  │   - Caching                             │              │
│  └───────────────┬─────────────────────────┘              │
└──────────────────┼─────────────────────────────────────────┘
                   │ HTTP POST (JSON-RPC 2.0)
                   v
┌─────────────────────────────────────────────────────────────┐
│              Archon MCP Server (CT183)                      │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  MCP Tools (28 available)                           │  │
│  │  - Knowledge Base (6 tools)                         │  │
│  │  - Project Management (3 tools)                     │  │
│  │  - Task Management (2 tools)                        │  │
│  │  - Document Management (2 tools)                    │  │
│  │  - Version Control (2 tools)                        │  │
│  │  - System (3 tools)                                 │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  PostgreSQL Database                                │  │
│  │  - Projects, Tasks, Documents                       │  │
│  │  - pgvector for RAG embeddings                      │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

**1. Pull (Archon → Laravel):**
```
Scheduled Job → ArchonMcpService → Get Projects/Tasks → Update Local DB
```

**2. Push (Laravel → Archon):**
```
Model Event → Event Listener → Queue Job → ArchonMcpService → Update Archon
```

---

## Available Tools

### Knowledge Base (6 tools)

| Tool | Description | Arguments | Returns |
|------|-------------|-----------|---------|
| `rag_get_available_sources` | List knowledge sources | - | Array of sources |
| `rag_search_knowledge_base` | Semantic search | query, source_id?, match_count | Search results |
| `rag_search_code_examples` | Code search | query, source_id?, match_count | Code snippets |
| `rag_list_pages_for_source` | List pages | source_id, section? | Page list |
| `rag_read_full_page` | Get full page | page_id?, url? | Full content |
| `archon_search_knowledge` | Quick search | query, limit | Search results |

### Project Management (3 tools)

| Tool | Description | Arguments | Returns |
|------|-------------|-----------|---------|
| `find_projects` | List/search | project_id?, query?, page, per_page | Projects |
| `manage_project` | CRUD | action, project_id?, title?, description?, github_repo? | Project |
| `get_project_features` | Get features | project_id | Features array |

### Task Management (2 tools)

| Tool | Description | Arguments | Returns |
|------|-------------|-----------|---------|
| `find_tasks` | List/search | query?, task_id?, filter_by?, filter_value?, project_id? | Tasks |
| `manage_task` | CRUD | action, task_id?, project_id?, title?, description?, status?, assignee? | Task |

**Task Statuses:** `todo`, `doing`, `review`, `done`

---

## Usage Examples

### Knowledge Base Search

```php
use App\Services\ArchonMcpService;

$archon = app(ArchonMcpService::class);

// Search documentation
$results = $archon->searchKnowledgeBase('Laravel 12 features', matchCount: 5);

foreach ($results as $result) {
    echo "Title: {$result->title}\n";
    echo "Preview: {$result->preview}\n";
    echo "Similarity: {$result->similarity}\n\n";
}

// Search code examples
$codeResults = $archon->searchCodeExamples('Laravel middleware', matchCount: 3);

foreach ($codeResults as $code) {
    echo "Code:\n{$code->content}\n\n";
}

// Get available sources
$sources = $archon->getAvailableSources();
print_r($sources);
```

### Project Management

```php
// Create project
$project = $archon->createProject(
    'Infrastructure Upgrade',
    'Migrate to Laravel 12 with PHP 8.4',
    'https://github.com/agl/agl-hostman'
);

// Get all projects
$projects = $archon->getProjects();

// Search projects
$filtered = $archon->getProjects(['query' => 'infrastructure']);

// Update project
$updated = $archon->updateProject($project->id, [
    'description' => 'Updated description',
]);

// Delete project
$archon->deleteProject($project->id);
```

### Task Management

```php
// Create task
$task = $archon->createTask(
    $projectId,
    'Setup WireGuard mesh',
    [
        'description' => 'Configure CT184 in mesh network',
        'status' => 'todo',
        'assignee' => 'DevOps Team',
        'task_order' => 1,
    ]
);

// Update task status
$archon->updateTaskStatus($task->id, 'doing');
$archon->updateTaskStatus($task->id, 'review');
$archon->updateTaskStatus($task->id, 'done');

// Get project tasks
$tasks = $archon->getTasks(['project_id' => $projectId]);

// Filter tasks by status
$todoTasks = $archon->getTasks([
    'filter_by' => 'status',
    'filter_value' => 'todo',
]);
```

### System Health

```php
// Check connectivity
if ($archon->ping()) {
    echo "Connected to Archon MCP\n";
}

// Health check
$health = $archon->healthCheck();
print_r($health);

// System status
$status = $archon->getStatus();
echo "Service: {$status['service']}\n";
echo "Version: {$status['version']}\n";
```

---

## Sync Strategy

### Bidirectional Sync

**Direction 1: Archon → Laravel (Pull)**

- **Scheduled**: Every 5 minutes via `SyncArchonProjectsJob` and `SyncArchonTasksJob`
- **Manual**: `php artisan archon:sync`
- **Conflict Resolution**: Last-write-wins (configurable)

**Direction 2: Laravel → Archon (Push)**

- **Event-driven**: On model create/update
- **Queued**: `PushToArchonJob` processes in background
- **Tracked**: All syncs logged in `archon_sync_log`

### Sync Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Sync Cycle                               │
│                                                             │
│  1. Scheduled Job Triggers (every 5 min)                   │
│         │                                                   │
│         v                                                   │
│  2. SyncArchonProjectsJob → Pull projects from Archon      │
│         │                                                   │
│         v                                                   │
│  3. Update local Sprint models                             │
│         │                                                   │
│         v                                                   │
│  4. SyncArchonTasksJob → Pull tasks from Archon            │
│         │                                                   │
│         v                                                   │
│  5. Update local Task models                               │
│                                                             │
│  -----------------------------------------------------------│
│                                                             │
│  6. Local Sprint/Task created/updated                       │
│         │                                                   │
│         v                                                   │
│  7. Event listener triggers                                │
│         │                                                   │
│         v                                                   │
│  8. PushToArchonJob queued                                 │
│         │                                                   │
│         v                                                   │
│  9. Update Archon via MCP                                  │
│         │                                                   │
│         v                                                   │
│ 10. Log sync in archon_sync_log                            │
└─────────────────────────────────────────────────────────────┘
```

---

## Configuration

### Environment Variables

Add to `.env`:

```bash
# Archon MCP Configuration
ARCHON_ENABLED=true
ARCHON_MCP_URL=http://10.6.0.21:8051/mcp  # WireGuard (fastest)
# ARCHON_MCP_URL=http://100.80.30.59:8051/mcp  # Tailscale (backup)
# ARCHON_MCP_URL=http://192.168.0.183:8052/mcp  # LAN (dev only)

ARCHON_WEB_URL=https://archon.aglz.io
ARCHON_TIMEOUT=30
ARCHON_RETRY_TIMES=3
ARCHON_RETRY_DELAY=1000

# Sync Configuration
ARCHON_SYNC_ENABLED=true
ARCHON_SYNC_INTERVAL=300  # 5 minutes

# Cache Configuration
ARCHON_CACHE_ENABLED=true
ARCHON_CACHE_TTL=3600  # 1 hour

# Conflict Resolution
ARCHON_CONFLICT_RESOLUTION=last-write-wins  # or: manual, archon-wins, laravel-wins

# Logging
ARCHON_LOGGING_ENABLED=true
ARCHON_LOG_CHANNEL=stack
ARCHON_LOG_LEVEL=info
```

### Scheduler Setup

Add to `app/Console/Kernel.php`:

```php
protected function schedule(Schedule $schedule): void
{
    // Sync projects every 5 minutes
    $schedule->job(new \App\Jobs\Archon\SyncArchonProjectsJob)
        ->everyFiveMinutes()
        ->onOneServer();

    // Sync tasks every 5 minutes
    $schedule->job(new \App\Jobs\Archon\SyncArchonTasksJob)
        ->everyFiveMinutes()
        ->onOneServer();
}
```

---

## Testing

### Manual Testing

```bash
# 1. Check connectivity
php artisan archon:health

# 2. Manual sync (foreground)
php artisan archon:sync --type=all

# 3. Manual sync (background queue)
php artisan archon:sync --type=all --async

# 4. Sync specific project
php artisan archon:sync --type=projects --project=proj-123

# 5. Sync specific task
php artisan archon:sync --type=tasks --task=task-456
```

### PHP Tinker

```bash
php artisan tinker
```

```php
// Test MCP client
$client = app(\App\Services\Archon\ArchonMcpClient::class);
$result = $client->call('health_check');
print_r($result);

// Test service
$archon = app(\App\Services\ArchonMcpService::class);

// Search knowledge base
$results = $archon->searchKnowledgeBase('Laravel 12');
print_r($results);

// Get projects
$projects = $archon->getProjects();
print_r($projects);

// Create project
$project = $archon->createProject('Test Project', 'Description');
print_r($project);
```

### Unit Tests

Create `tests/Feature/ArchonMcpTest.php`:

```php
<?php

namespace Tests\Feature;

use App\Services\ArchonMcpService;
use Tests\TestCase;

class ArchonMcpTest extends TestCase
{
    public function test_can_connect_to_archon(): void
    {
        $archon = app(ArchonMcpService::class);
        $this->assertTrue($archon->ping());
    }

    public function test_can_search_knowledge_base(): void
    {
        $archon = app(ArchonMcpService::class);
        $results = $archon->searchKnowledgeBase('test', matchCount: 1);
        $this->assertNotNull($results);
    }

    public function test_can_get_projects(): void
    {
        $archon = app(ArchonMcpService::class);
        $projects = $archon->getProjects();
        $this->assertInstanceOf(\Illuminate\Support\Collection::class, $projects);
    }
}
```

Run tests:

```bash
php artisan test --filter=ArchonMcpTest
```

---

## Troubleshooting

### Connection Issues

**Problem**: Connection timeout or refused

**Solution**:
```bash
# 1. Check Archon is running
ssh root@10.6.0.21 'docker ps | grep archon'

# 2. Check MCP endpoint
curl -v http://10.6.0.21:8051/mcp

# 3. Try Tailscale as backup
ARCHON_MCP_URL=http://100.80.30.59:8051/mcp php artisan archon:health

# 4. Restart Archon MCP container
ssh root@10.6.0.21 'cd /root/archon && docker-compose restart archon-mcp'
```

### Sync Errors

**Problem**: Sync jobs failing

**Solution**:
```bash
# 1. Check queue workers
php artisan queue:work --verbose

# 2. Check sync logs
php artisan db:table archon_sync_log --where "status=failed"

# 3. Retry failed jobs
php artisan queue:retry all

# 4. Clear cache
php artisan cache:clear
php artisan config:clear
```

### Invalid JSON-RPC Response

**Problem**: `Invalid JSON-RPC 2.0 response`

**Solution**:
```bash
# 1. Check Archon version
ssh root@10.6.0.21 'cd /root/archon && git log -1'

# 2. Test MCP endpoint directly
curl -X POST http://10.6.0.21:8051/mcp \
  -H 'Content-Type: application/json' \
  -d '{
    "jsonrpc": "2.0",
    "id": "test-1",
    "method": "tools/call",
    "params": {
      "name": "health_check",
      "arguments": {}
    }
  }'

# 3. Check Archon logs
ssh root@10.6.0.21 'docker logs archon-mcp --tail 50'
```

### Rate Limiting

**Problem**: Too many requests

**Solution**:
```bash
# Increase sync interval
ARCHON_SYNC_INTERVAL=600  # 10 minutes

# Enable caching
ARCHON_CACHE_ENABLED=true
ARCHON_CACHE_TTL=7200  # 2 hours

# Reduce retry attempts
ARCHON_RETRY_TIMES=2
```

---

## Next Steps

1. **UI Integration**: Add Livewire components for knowledge base search
2. **Real-time Sync**: Implement WebSocket for instant updates
3. **Conflict Resolution UI**: Build interface for manual conflict resolution
4. **Advanced Search**: Add filters, facets, and search history
5. **Bulk Operations**: Batch project/task creation and updates
6. **Analytics**: Track MCP usage, response times, and sync success rates

---

**For more information, see:**
- `docs/ARCHON.md` - Archon MCP documentation
- `docs/INFRA.md` - Infrastructure overview
- `config/archon.php` - Configuration reference
