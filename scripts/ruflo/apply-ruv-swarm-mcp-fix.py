#!/usr/bin/env python3
"""
Aplica correção ao dispatch de tools/call no ruv-swarm (npm global).

Bug: handleMcpRequest recebia mcpTools inicializado com RuvSwarm, mas executava
sempre mcpToolsEnhanced (singleton com ruvSwarm=null) → swarm_status quebra com
getGlobalMetrics de null.

Uso: python3 scripts/ruflo/apply-ruv-swarm-mcp-fix.py
Reexecutar após: npm i -g ruv-swarm@...
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

OLD_SECURE = r"""                // Try regular MCP tools first (use mcpToolsEnhanced.tools)
                if (mcpToolsEnhanced.tools && typeof mcpToolsEnhanced.tools[toolName] === 'function') {
                    try {
                        logger.debug('Executing MCP tool (NO TIMEOUT VERSION)', { tool: toolName, args: toolArgs });
                        result = await mcpToolsEnhanced.tools[toolName](toolArgs);"""

NEW_SECURE = r"""                // Instância de initializeSystem() (com RuvSwarm), não o singleton default export.
                const toolsHost = mcpTools?.tools ? mcpTools : mcpToolsEnhanced;
                if (toolsHost.tools && typeof toolsHost.tools[toolName] === 'function') {
                    try {
                        logger.debug('Executing MCP tool (NO TIMEOUT VERSION)', { tool: toolName, args: toolArgs });
                        result = await toolsHost.tools[toolName](toolArgs);"""

OLD_HEARTBEAT = r"""                // Try regular MCP tools first (use mcpToolsEnhanced.tools)
                if (mcpToolsEnhanced.tools && typeof mcpToolsEnhanced.tools[toolName] === 'function') {
                    try {
                        logger.debug('Executing MCP tool', { tool: toolName, args: toolArgs });
                        result = await mcpToolsEnhanced.tools[toolName](toolArgs);"""

NEW_HEARTBEAT = r"""                const toolsHost = mcpTools?.tools ? mcpTools : mcpToolsEnhanced;
                if (toolsHost.tools && typeof toolsHost.tools[toolName] === 'function') {
                    try {
                        logger.debug('Executing MCP tool', { tool: toolName, args: toolArgs });
                        result = await toolsHost.tools[toolName](toolArgs);"""


def npm_global_root() -> Path:
    out = subprocess.run(
        ["npm", "root", "-g"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()
    return Path(out)


def main() -> int:
    root = npm_global_root() / "ruv-swarm" / "bin"
    if not root.is_dir():
        print(f"ruv-swarm não encontrado em {root}", file=sys.stderr)
        return 1

    files = {
        root / "ruv-swarm-secure.js": (OLD_SECURE, NEW_SECURE),
        root / "ruv-swarm-secure-heartbeat.js": (OLD_HEARTBEAT, NEW_HEARTBEAT),
    }

    for path, (old, new) in files.items():
        if not path.is_file():
            print(f"SKIP ausente: {path}")
            continue
        text = path.read_text(encoding="utf-8")
        if "const toolsHost = mcpTools?.tools ? mcpTools : mcpToolsEnhanced" in text:
            print(f"OK já corrigido: {path.name}")
            continue
        if old not in text:
            print(
                f"AVISO: padrão antigo não encontrado em {path.name} (versão diferente do pacote?)",
                file=sys.stderr,
            )
            continue
        path.write_text(text.replace(old, new, 1), encoding="utf-8")
        print(f"PATCH aplicado: {path.name}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
