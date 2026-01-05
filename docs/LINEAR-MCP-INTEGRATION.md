# Linear MCP Integration

## Overview

Linear provides a Model Context Protocol (MCP) server that enables Claude Code to interact with Linear's project management features through a standardized interface. This integration allows Claude to find, create, and update Linear objects like issues, projects, and comments directly from coding sessions.

## Configuration Status

✅ **Linear MCP Server Added**: `https://mcp.linear.app/mcp`

The server has been configured and is ready for authentication.

## Setup Steps Completed

1. **MCP Server Registration**:
   ```bash
   claude mcp add --transport http linear https://mcp.linear.app/mcp
   ```

2. **Configuration Location**: `/root/.claude.json`

## Authentication Required

⚠️ **Current Status**: Needs authentication

### How to Authenticate

In any Claude Code session, run:
```
/mcp
```

This will:
1. Display available MCP servers
2. Prompt you to authenticate with Linear using OAuth 2.1
3. Store credentials securely in `~/.mcp-auth`

### Alternative: Direct Token Authentication

You can also authenticate using a Linear API token:
1. Get your Linear API key from: https://linear.app/settings/api
2. Use the token in API requests with header: `Authorization: Bearer <token>`

## Available Capabilities

Once authenticated, Claude Code can:

- **Find Issues**: Search and retrieve Linear issues
- **Create Issues**: Create new issues with details
- **Update Issues**: Modify existing issue properties
- **Manage Projects**: Access and manage Linear projects
- **Handle Comments**: Add and read comments on issues

## Technical Details

### Transport Configuration
- **Protocol**: HTTP (Streamable) - Recommended
- **Endpoint**: `https://mcp.linear.app/mcp`
- **Alternative**: SSE endpoint available at `https://mcp.linear.app/sse`

### Authentication Method
- **OAuth 2.1**: Dynamic client registration
- **Token Auth**: Direct API token via Authorization header

### Connection Health
Check MCP server status:
```bash
claude mcp list
```

Expected output for Linear:
```
linear: https://mcp.linear.app/mcp (HTTP) - ⚠ Needs authentication
```

After authentication:
```
linear: https://mcp.linear.app/mcp (HTTP) - ✓ Connected
```

## Usage Examples

### Example 1: Search for Issues
```
"Search Linear for issues related to authentication in the current sprint"
```

### Example 2: Create an Issue
```
"Create a Linear issue titled 'Implement OAuth flow' in the Backend project with priority High"
```

### Example 3: Update Issue Status
```
"Update Linear issue AGL-123 status to 'In Progress' and assign to me"
```

### Example 4: Add Comments
```
"Add a comment to Linear issue AGL-123: 'Completed initial implementation, ready for review'"
```

## Integration with Project Workflow

### SPARC Methodology Integration
Linear MCP works seamlessly with the SPARC workflow:

1. **Specification**: Fetch Linear issue requirements
2. **Pseudocode**: Link design decisions to Linear comments
3. **Architecture**: Document architecture in Linear project docs
4. **Refinement**: Update issue status during TDD cycles
5. **Completion**: Auto-close issues when tasks complete

### Swarm Coordination
Linear MCP integrates with Claude Flow swarm coordination:
- Agents can update issue status independently
- Progress tracking across multiple parallel agents
- Automatic issue creation for discovered subtasks

## Troubleshooting

### Issue: "Needs authentication"
**Solution**: Run `/mcp` in a Claude Code session and complete OAuth flow

### Issue: Internal server errors
**Solution**: Clear saved auth and retry:
```bash
rm -rf ~/.mcp-auth
```
Then re-authenticate via `/mcp`

### Issue: WSL/Windows connection problems
**Solution**: Use SSE transport instead:
```bash
claude mcp add --transport sse-only linear https://mcp.linear.app/sse
```

## MCP Servers Ecosystem

The project now has multiple MCP integrations:

### Connected Servers (20):
- **context7**: General context management
- **github**: GitHub repository operations
- **sqlite**: Database queries
- **memory**: Persistent memory storage
- **filesystem**: File system access
- **azure-devops**: Azure DevOps integration
- **minecraft**: Minecraft server management (if applicable)
- **playwright**: Browser automation testing
- **dokploy-mcp**: Dokploy deployment platform
- **flow-nexus**: AI swarm orchestration cloud
- **agentic-payments**: Payment processing
- **docker**: Container management
- **harbor**: Container registry management
- **proxmox**: Proxmox VE infrastructure
- **portainer**: Container orchestration UI
- **cloudflare-dns**: DNS management
- **linear**: Project management (pending auth)

### Failed/Unavailable (5):
- claude-flow (local)
- ruv-swarm (local)
- archon (192.168.0.183:8052)
- archon-tailscale (100.80.30.59:8051)
- exa (search)

## Best Practices

1. **Issue Creation**: Always include project, title, and description
2. **Status Updates**: Use Linear's standard status names
3. **Searching**: Use specific keywords and filters
4. **Batch Operations**: Claude can handle multiple Linear operations concurrently
5. **Authentication**: Keep OAuth tokens secure, refresh when needed

## Next Steps

1. ✅ Linear MCP server configured
2. ⏳ Authenticate with Linear via `/mcp` command
3. ⏳ Test basic operations (search, create, update)
4. ⏳ Integrate with existing SPARC workflows
5. ⏳ Configure team-wide Linear workspace settings

## Resources

- **Linear MCP Documentation**: https://linear.app/docs/mcp
- **Linear API Reference**: https://developers.linear.app/docs/graphql/working-with-the-graphql-api
- **MCP Protocol Specification**: https://spec.modelcontextprotocol.io/
- **Claude Code MCP Guide**: https://docs.claude.com/en/docs/claude-code/mcp

## Related Documentation

- [CLAUDE.md](../CLAUDE.md) - Main project configuration
- [TASKS.md](../TASKS.md) - Active development tasks
- [docs/FGSRV6-STATUSLINE-DEPLOYMENT.md](./FGSRV6-STATUSLINE-DEPLOYMENT.md) - Deployment guides

---

**Last Updated**: 2026-01-04
**Status**: Configured, awaiting authentication
**Maintainer**: Development team
