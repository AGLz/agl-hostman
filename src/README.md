# Source Directory

Application source code and utilities.

## Structure

### utils/
Utility scripts and configuration:
- `statusline-utilities.py` - Statusline display utilities
- `statusline-config.yaml` - Statusline configuration
- `statusline-templates.yaml` - Statusline templates

### validation/
Code validation and quality tools:
- `burn-rate-engine.py` - Token burn rate analysis engine
- `error-handling-validation.py` - Error handling validation framework

## Development Guidelines

See `/docs/RULES.md` for complete coding standards and best practices.

### Key Principles

1. **File Organization**: Never save files to root folder
2. **Concurrent Execution**: Batch related operations in single messages
3. **Error Handling**: Implement robust error handling with user-friendly messages
4. **Testing**: Write strategic, minimal tests for core flows
5. **Documentation**: Update docs when changing functionality

## Integration

This source code integrates with:
- Agent OS workflows (spec-driven development)
- SPARC methodology (test-driven development)
- Archon MCP (task management and knowledge base)
- Claude-Flow (multi-agent coordination)

---
**Last Updated**: 2025-10-31
