---
name: cursor-cli-agl
description: >
  Manage Cursor IDE and cursor-agent CLI on AGL infrastructure. Use when working with Cursor IDE
  configuration, cursor-agent CLI commands, MCP servers, LiteLLM integration with Cursor,
  Composer 2 model setup, or syncing Cursor settings across AGL hosts. Covers Cursor-Composer
  integration via LiteLLM proxy (cursor-composer, cursor-composer-2-fast → gpt-5.3-chat-latest).
---
# Cursor CLI & IDE — AGL Infrastructure

## LiteLLM + Cursor Integration

Cursor's **Composer 2** model is proprietary. On the AGL LiteLLM proxy, public names are mapped:

| Cursor Model Name       | LiteLLM Model Mapping                |
|------------------------|--------------------------------------|
| `cursor-composer`      | `openai/gpt-5.3-chat-latest`         |
| `cursor-composer-2-fast` | `openai/gpt-5.3-chat-latest`       |

Config: `config/litellm/config.yaml`

## Cursor IDE Configuration

### Connect Cursor to LiteLLM

```
Settings → Models → Add Custom Model
- Provider: OpenAI
- Model: cursor-composer
- API Key: (from LiteLLM)
- API Base URL: http://<host>:4000
```

### Cursor Agent CLI

```bash
# Install cursor-agent (Node.js)
npm install -g @anthropic-ai/cursor-agent

# Configure
cursor-agent config set --base-url http://localhost:4000
cursor-agent config set --api-key <litellm-key>

# Use
cursor-agent "refactor the auth module"
```

## AGL Hosts with Cursor/Claude Code

| Host     | Tailscale IP      | Cursor/Claude Code | LiteLLM       |
|----------|-------------------|--------------------|---------------|
| agldv03  | 100.94.221.87     | ✅ Full            | Local :4000   |
| agldv04  | 100.113.9.98      | ✅ Full            | Local :4000   |
| agldv05  | 100.119.41.63     | ✅ Full            | Remote (03)   |
| agldv06  | 100.71.229.12     | ✅ Full            | Remote (03)   |
| agldv07  | 100.64.139.79     | ✅ Full            | Remote (CT186) |
| agldv12  | 100.71.217.115    | ✅ Full            | Local :4000   |
| fgsrv06  | 100.83.51.9       | ✅ Full            | Local :4000   |

## MCP Server Configuration

Cursor supports MCP servers. AGL MCP endpoints:

```json
{
  "mcpServers": {
    "litellm": {
      "url": "http://localhost:4000/v1"
    },
    "archon": {
      "url": "http://100.80.30.59:8052"
    }
  }
}
```

## Cursor Settings Sync

### Settings file locations
```bash
# Cursor settings
~/.cursor/settings.json

# Claude Code settings (related)
~/.claude/settings.json
~/.claude/plugins.json
```

### Sync across AGL hosts
```bash
# From agldv03 (source of truth)
scp ~/.cursor/settings.json root@100.113.9.98:~/.cursor/
scp ~/.cursor/settings.json root@100.71.217.115:~/.cursor/
scp ~/.cursor/settings.json root@100.83.51.9:~/.cursor/
```

## Common Operations

### Test Cursor connectivity
```bash
# Test LiteLLM proxy
curl -s http://localhost:4000/v1/models | jq '.data[] | select(.id | contains("cursor"))'

# Test cursor-composer model
curl -s http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "cursor-composer", "messages": [{"role": "user", "content": "hello"}]}'
```

### Check model mappings
```bash
# On agldv03
cat /opt/litellm/config.yaml | grep -A5 cursor-composer
```

## Troubleshooting

### Cursor can't connect to LiteLLM
```bash
# 1. Check LiteLLM is running
ssh root@100.94.221.87 "systemctl --user status litellm"

# 2. Check model config
ssh root@100.94.221.87 "cat /opt/litellm/config.yaml | grep cursor"

# 3. Test endpoint
curl -v http://100.94.221.87:4000/health
```

### Cursor agent CLI not working
```bash
# Check installation
which cursor-agent
cursor-agent --version

# Check config
cursor-agent config list
```

## References
- `docs/CURSOR-LITELLM-INTEGRATION.md` — Full setup guide
- `config/litellm/config.yaml` — LiteLLM model mappings
- https://docs.litellm.ai/docs/tutorials/cursor_integration
