# AGL Search MCP Server

Unified search tools MCP server for the AGL Hostman project.

## Architecture

```
┌───────────────────────────────────────────────────────────────┐
│                    Claude Code / Cursor                                │
│                  (via MCP Protocol)                                │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    MCP Server (server.js)                                │
│  ┌───────────────────┬───────────────────┬───────────────────┐   │
│    search_semantic  │    search_code    │    search_docs    │   │
│        (HNSW)          │    (grep)         │   (keyword)      │
│  └───────────────────┴───────────────────┴───────────────────┘   │
│                          │                                        │
│                          ▼                                        │
│           ┌───────────────────────────────────────────────────┐      │
│           │         PostgreSQL + pgvector          │      │
│           │         (ruvector-postgres:5433)             │      │
│           └───────────────────────────────────────────────────┘      │
```

## Components

### 1. RuVector PostgreSQL (Docker)

Container PostgreSQL com pgvector extension for semantic memory storage.

```bash
# Start container
docker compose up -d

# Connection details
Host: localhost
Port: 5433
Database: agl_ruvector
User: admin
Password: agl_ruvector_2026
```

### 2. MCP Server (Node.js)

MCP server providing 5 search tools:

```bash
# Start server
node server.js

# Or add to Claude Code
claude mcp add agl-search -- node /path/to/server.js
```

## Installation

```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman/mcp-servers/search
npm install
```

## Configuration

### Environment Variables (.env)

| Variable | Description | Default |
|----------|-------------|---------|
| `RUVECTOR_DATABASE_URL` | PostgreSQL connection string | `postgresql://admin:agl_ruvector_2026@localhost:5433/agl_ruvector?sslmode=disable` |
| `AGL_SQLITE_PATH` | SQLite database path | `{PROJECT_ROOT}/src/database/database.sqlite` |
| `AGL_DOCS_PATH` | Documentation directory | `{PROJECT_ROOT}/docs` |
| `AGL_HNSW_INDEX_PATH` | HNSW index path | `{PROJECT_ROOT}/.agl/hnsw/index` |
| `AGL_MAX_RESULTS` | Maximum search results | `50` |
| `AGL_SEARCH_TIMEOUT` | Search timeout in ms | `30000` |

## Available Tools

### search_semantic

Semantic search using HNSW indexing via RuVector PostgreSQL.

```json
{
  "query": "authentication patterns",
  "k": 10,
  "threshold": 0.7,
  "namespace": "default"
}
```

**Parameters:**
- `query` (required): Natural language search query
- `k` (optional): Number of results (default: 10)
- `threshold` (optional): Minimum similarity 0-1 (default: 0.7)
- `namespace` (optional): Memory namespace (default: "default")

### search_code

Search code files using grep patterns.

```json
{
  "pattern": "async function.*handler",
  "path": "/path/to/search",
  "fileType": "*.js",
  "caseSensitive": false,
  "context": 2,
  "limit": 50
}
```

**Parameters:**
- `pattern` (required): Regex pattern to search
- `path` (optional): Directory to search (default: project root)
- `fileType` (optional): File type filter (default: "*")
- `caseSensitive` (optional): Case sensitive (default: false)
- `context` (optional): Context lines (default: 2)
- `limit` (optional): Max results (default: 50)

### search_docs

Search documentation files (RAG-style keyword matching).

```json
{
  "query": "proxmox configuration",
  "path": "/path/to/docs",
  "limit": 20,
  "includeContent": true
}
```

**Parameters:**
- `query` (required): Search query for documentation
- `path` (optional): Docs directory (default: project docs/)
- `limit` (optional): Max results (default: 20)
- `includeContent` (optional): Include excerpts (default: true)

### search_memory

Search AgentDB memory (Claude-Flow + SQLite).

```json
{
  "query": "hive-mind patterns",
  "sources": ["claude-flow", "sqlite"],
  "limit": 20,
  "namespace": "patterns"
}
```

**Parameters:**
- `query` (required): Search query for memory
- `sources` (optional): Memory sources (default: ["all"])
- `limit` (optional): Max results per source (default: 20)
- `namespace` (optional): Memory namespace

### search_all

Unified search across all sources (semantic, code, docs, memory).

```json
{
  "query": "wireguard setup",
  "limit": 20,
  "threshold": 0.7
}
```

**Parameters:**
- `query` (required): Search query
- `limit` (optional): Max results per source (default: 20)
- `threshold` (optional): Similarity threshold (default: 0.7)

## Docker Compose

### Start RuVector PostgreSQL

```bash
# From mcp-servers/search directory
docker compose up -d
```

### Check container status

```bash
docker ps --filter "name=ruvector-postgres"
docker logs ruvector-postgres
```

### Stop container

```bash
docker compose down
```

## Integration with Claude Code

Add to your Claude Code MCP settings:

```bash
claude mcp add agl-search -- node /mnt/overpower/apps/dev/agl/agl-hostman/mcp-servers/search/server.js
```

## Integration with Claude Desktop

Add to your Claude Desktop config (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "agl-search": {
      "command": "node",
      "args": ["/mnt/overpower/apps/dev/agl/agl-hostman/mcp-servers/search/server.js"],
      "env": {
        "AGL_PROJECT_ROOT": "/mnt/overpower/apps/dev/agl/agl-hostman",
        "RUVECTOR_DATABASE_URL": "postgresql://admin:agl_ruvector_2026@localhost:5433/agl_ruvector?sslmode=disable"
      }
    }
  }
}
```

## Database Schema

### ruvector_embeddings table

```sql
CREATE TABLE ruvector_embeddings (
    id SERIAL PRIMARY KEY,
    namespace VARCHAR(255) NOT NULL,
    key VARCHAR(512) NOT NULL,
    content TEXT NOT NULL,
    embedding vector(1536),    -- OpenAI embedding dimension
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP,
    UNIQUE(namespace, key)
);

-- HNSW index for fast similarity search
CREATE INDEX ruvector_hnsw_idx
ON ruvector_embeddings
USING hnsw (embedding vector_cosine_ops)
WITH (M = 16, ef_construction = 64);

-- Namespace index
CREATE INDEX ruvector_namespace_idx
ON ruvector_embeddings (namespace);
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| PostgreSQL connection fails | Check `RUVECTOR_DATABASE_URL` in `.env` |
| pgvector extension not found | Container uses `pgvector/pgvector:pg16` image |
| MCP server not starting | Run `node server.js` manually to see errors |
| Search returns no results | Check namespace and query terms |
| Docker port conflict | Stop conflicting containers on port 5433 |

## Related Documentation

- [RuVector + LiteLLM + OpenClaw](../../docs/RUVECTOR-LITELLM-OPENCLAW.md)
- [Cursor + LiteLLM Integration](../../docs/CURSOR-LITELLM-INTEGRATION.md)
- [AGL Infrastructure](../../docs/INFRA.md)

## License

MIT
