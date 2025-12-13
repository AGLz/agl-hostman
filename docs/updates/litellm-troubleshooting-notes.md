# LiteLLM Troubleshooting Notes - 2025-12-12

## Problem Summary

LiteLLM on CT200 cannot be updated to latest version due to mandatory PostgreSQL database requirement.

## Current Status

- **Container**: Removed (was exited for 5 weeks)
- **Image**: `ghcr.io/berriai/litellm:main-latest` (2025-12-08) - incompatible
- **Configuration**: `/opt/ollama-stack/litellm-config.yaml` - YAML-only config without database
- **Models**: qwen2.5-32b, llama3.3, deepseek-r1-32b, deepseek-coder-33b, mistral-7b, nomic-embed-text

## Root Cause

**Breaking change in LiteLLM architecture**:
- **Old behavior**: Could run with config file only, optional database
- **New behavior**: Requires Prisma Client with PostgreSQL database connection
- **Error**: `Prisma schema validation - the URL must start with the protocol 'postgresql://' or 'postgres://'`

## Error Details

```
LiteLLM Proxy: LiteLLM Prisma Client Exception connect(): Could not connect to the query engine
ERROR: Prisma schema validation - (get-config wasm)
Error code: P1012
error: Error validating datasource `client`: the URL must start with the protocol `postgresql://` or `postgres://`.
```

## Configuration Analysis

### Current Setup (YAML-only)
```yaml
# File: /opt/ollama-stack/litellm-config.yaml
model_list:
  - model_name: qwen2.5-32b
    litellm_params:
      model: ollama/qwen2.5:32b
      api_base: http://localhost:11434
# ... 6 models configured
```

### Environment Variables
```bash
DATABASE_URL=sqlite:////app/data/litellm.db  # ❌ Not supported in new versions
LITELLM_MASTER_KEY=sk-b70fbd1f57caa6c3afa8014e66da177d40bfd9177061be4d
LITELLM_REQUEST_TIMEOUT=600
LITELLM_NUM_WORKERS=4
```

## Resolution Options

### Option 1: Deploy PostgreSQL Database (Recommended for Production)

1. **Deploy PostgreSQL container** on CT200:
   ```bash
   docker run -d \
     --name litellm-db \
     --restart unless-stopped \
     -e POSTGRES_PASSWORD=litellm_secure_pass \
     -e POSTGRES_USER=litellm \
     -e POSTGRES_DB=litellm \
     -v litellm_postgres_data:/var/lib/postgresql/data \
     -p 127.0.0.1:5433:5432 \
     postgres:16-alpine
   ```

2. **Update LiteLLM environment**:
   ```bash
   DATABASE_URL=postgresql://litellm:litellm_secure_pass@localhost:5433/litellm
   ```

3. **Run migrations and start LiteLLM**:
   ```bash
   docker run -d \
     --name litellm \
     --restart unless-stopped \
     -p 4000:4000 \
     -v /opt/ollama-stack/litellm-logs:/app/logs \
     -v /opt/ollama-stack/litellm-config.yaml:/app/config.yaml:ro \
     -e DATABASE_URL=postgresql://litellm:litellm_secure_pass@localhost:5433/litellm \
     -e LITELLM_MASTER_KEY=sk-b70fbd1f57caa6c3afa8014e66da177d40bfd9177061be4d \
     -e LITELLM_REQUEST_TIMEOUT=600 \
     -e LITELLM_NUM_WORKERS=4 \
     ghcr.io/berriai/litellm:main-latest
   ```

### Option 2: Use Older LiteLLM Version (Temporary Workaround)

Use last version that supported config-only mode (before Prisma migration):
```bash
docker run -d \
  --name litellm \
  --restart unless-stopped \
  -p 4000:4000 \
  -v /opt/ollama-stack/litellm-config.yaml:/app/config.yaml:ro \
  -e LITELLM_MASTER_KEY=sk-b70fbd1f57caa6c3afa8014e66da177d40bfd9177061be4d \
  --entrypoint litellm \
  ghcr.io/berriai/litellm:main-v1.48.4 \
  --config /app/config.yaml --port 4000 --host 0.0.0.0
```

**Note**: This version is from September 2024 and will miss security updates.

### Option 3: Use Alternative Proxy (Future)

Consider alternatives that don't require database:
- **Oterm**: Terminal-based Ollama manager
- **Open WebUI**: Already deployed, provides unified interface
- **Custom proxy**: Simple Python/Node.js proxy for Ollama

## Disk Space Constraints

CT200 has **32GB total capacity** - insufficient for:
- Open WebUI: 4.3GB
- Ollama models: 13GB (native installation)
- LiteLLM: 2.2GB
- PostgreSQL: 500MB (minimal) + growth
- System and logs: 2-3GB

**Action needed**: Either expand disk quota or deploy LiteLLM on different container.

## Temporary Workaround

**LiteLLM is NOT RUNNING** - using Open WebUI directly with Ollama:
- **Open WebUI**: Running on port 3000 (healthy, v0.6.41)
- **Ollama API**: Native installation on port 11434
- **Access**: http://10.6.0.17:3000

Users can access all Ollama models through Open WebUI without LiteLLM proxy.

## Priority

🟡 **MEDIUM-LOW** - Not blocking AI functionality, Open WebUI provides similar capabilities.

**Recommendation**:
1. Continue using Open WebUI + Ollama directly
2. Plan PostgreSQL deployment if LiteLLM proxy features are needed
3. Consider expanding CT200 disk quota to 64GB

## Last Updated

2025-12-12 17:40 UTC
