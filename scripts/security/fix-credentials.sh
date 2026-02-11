#!/usr/bin/env bash

# =============================================================================
# Security Remediation Script
# =============================================================================
# Description: Fix identified security vulnerabilities
# Usage: ./scripts/security/fix-credentials.sh
# =============================================================================

set -e

readonly CLAUDE_MCP_CONFIG="$HOME/.config/claude/mcp.json"
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "============================================================"
echo "  AGL Security Remediation"
echo "============================================================"
echo

# Backup original config
if [[ -f "$CLAUDE_MCP_CONFIG" ]]; then
    echo "Backing up Claude MCP config..."
    cp "$CLAUDE_MCP_CONFIG" "${CLAUDE_MCP_CONFIG}.backup.$(date +%s)"
    echo "Backup created: ${CLAUDE_MCP_CONFIG}.backup.$(date +%s)"
    echo
fi

# Create updated config with environment variable reference
echo "Creating fixed Claude MCP configuration..."
cat > "$CLAUDE_MCP_CONFIG" << 'EOF'
{
  "mcpServers": {
    "linear": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-linear"],
      "env": {
        "LINEAR_API_TOKEN": "${LINEAR_API_TOKEN}"
      }
    }
  }
}
EOF

echo "Updated Claude MCP config to use environment variable"
echo

# Instructions for setting up the environment variable
cat << 'INSTRUCTIONS'
============================================================
  NEXT STEPS REQUIRED
============================================================

1. Set up the LINEAR_API_TOKEN environment variable:

   # For current session:
   export LINEAR_API_TOKEN="your_actual_token_here"

   # For persistence (add to ~/.bashrc or ~/.zshrc):
   echo 'export LINEAR_API_TOKEN="your_actual_token_here"' >> ~/.bashrc
   source ~/.bashrc

2. Restart Claude Code to pick up the new configuration

3. Verify the Linear MCP server is working:
   - Check Claude Code MCP server status
   - Test Linear integration

============================================================
  SECURITY NOTES
============================================================

- The actual token value should be stored in a secure location
- Consider using a secret manager (1Password, HashiCorp Vault, etc.)
- Never commit .env files or actual tokens to git
- Add Claude MCP config to .gitignore if not already

============================================================
INSTRUCTIONS

echo
echo "Remediation complete!"
echo "Please follow the steps above to complete the setup."
