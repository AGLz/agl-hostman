#!/usr/bin/env python3
"""
Patches ao @claude-flow/cli para o Claude Code funcionar via Ruflo como via shell:

1) Headless workers: `claude --dangerously-skip-permissions --print` (não só --print).
2) Headless + hive-mind: injetar IS_SANDBOX=1 no env do filho quando o pai não tem
   (ex.: MCP arrancado pelo Cursor/systemd sem login shell → ~/.zshrc não corre).

Sem (2), root + --dangerously-skip-permissions falha: o CLI exige IS_SANDBOX para
opt-in em ambiente sandbox (issues anthropics/claude-code).

Uso: python3 scripts/ruflo/apply-claude-flow-headless-dsp.py
Reexecutar após: npm i -g @claude-flow/cli ruflo
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

OLD_SPAWN = "const child = spawn('claude', ['--print', prompt], {"
NEW_SPAWN = "const child = spawn('claude', ['--dangerously-skip-permissions', '--print', prompt], {"

HEADLESS_BEFORE = """                CLAUDE_CODE_HEADLESS: 'true',
                CLAUDE_CODE_SANDBOX_MODE: options.sandbox,
                // Fix #1395 Bug 2:"""

HEADLESS_AFTER = """                CLAUDE_CODE_HEADLESS: 'true',
                CLAUDE_CODE_SANDBOX_MODE: options.sandbox,
                IS_SANDBOX: process.env.IS_SANDBOX && process.env.IS_SANDBOX !== '0' ? process.env.IS_SANDBOX : '1',
                // Fix #1395 Bug 2:"""

HIVE_BEFORE = """            const claudeProcess = childSpawn('claude', claudeArgs, {
                stdio: 'inherit',
                shell: false,
            });"""

HIVE_AFTER = """            const claudeProcess = childSpawn('claude', claudeArgs, {
                stdio: 'inherit',
                shell: false,
                env: {
                    ...process.env,
                    IS_SANDBOX: process.env.IS_SANDBOX && process.env.IS_SANDBOX !== '0' ? process.env.IS_SANDBOX : '1',
                },
            });"""

# Versões recentes do claude-flow podem fazer [INFO] Skipping --dangerously-skip-permissions (root/sudo)
# se IS_SANDBOX não existir no *processo Node* (Ruflo/MCP não carrega ~/.zshrc). O filho já recebia env;
# isto corrige o *check no pai* antes de montar claudeArgs.
HIVE_SPAWN_FN_BEFORE = """async function spawnClaudeCodeInstance(swarmId, swarmName, objective, workers, flags) {
    output.writeln();"""

HIVE_SPAWN_FN_AFTER = """async function spawnClaudeCodeInstance(swarmId, swarmName, objective, workers, flags) {
    // agl-hostman patch: IS_SANDBOX no processo Node (root+DSP; Ruflo/MCP sem login shell) — anthropics/claude-code#3490
    if (process.env.IS_SANDBOX === undefined || process.env.IS_SANDBOX === '')
        process.env.IS_SANDBOX = '1';
    output.writeln();"""

HIVE_SKIP_LINE = "Skipping --dangerously-skip-permissions (not allowed with root/sudo)"


def npm_global_root() -> Path:
    root = subprocess.check_output(["npm", "root", "-g"], text=True).strip()
    return Path(root)


def patch_headless(path: Path) -> list[str]:
    msgs: list[str] = []
    text = path.read_text(encoding="utf-8")
    orig = text

    if OLD_SPAWN in text:
        text = text.replace(OLD_SPAWN, NEW_SPAWN, 1)
        msgs.append("headless: spawn +--dangerously-skip-permissions")
    elif "['--dangerously-skip-permissions', '--print'" in text or "--dangerously-skip-permissions', '--print'" in text:
        msgs.append("headless: spawn DSP já presente")
    else:
        print(f"Aviso: padrão spawn não reconhecido em {path}", file=sys.stderr)

    if (
        "CLAUDE_CODE_SANDBOX_MODE: options.sandbox,\n                IS_SANDBOX:"
        in text
    ):
        msgs.append("headless: env IS_SANDBOX já presente")
    elif HEADLESS_BEFORE in text:
        text = text.replace(HEADLESS_BEFORE, HEADLESS_AFTER, 1)
        msgs.append("headless: env IS_SANDBOX default para filho")
    else:
        print(f"Aviso: bloco env headless não reconhecido em {path}", file=sys.stderr)

    if text != orig:
        path.write_text(text, encoding="utf-8")
    return msgs


def patch_hive_mind(path: Path) -> list[str]:
    msgs: list[str] = []
    if not path.is_file():
        return [f"hive-mind: omitido ({path} inexistente)"]
    text = path.read_text(encoding="utf-8")
    orig = text

    if "agl-hostman patch: IS_SANDBOX no processo Node" in text:
        msgs.append("hive-mind: inject IS_SANDBOX no processo Node já presente")
    elif HIVE_SPAWN_FN_BEFORE in text:
        text = text.replace(HIVE_SPAWN_FN_BEFORE, HIVE_SPAWN_FN_AFTER, 1)
        msgs.append("hive-mind: inject IS_SANDBOX no processo Node (antes checks root)")

    if HIVE_SKIP_LINE in text:
        text = text.replace(
            f"output.printInfo('{HIVE_SKIP_LINE}');\n", "", 1
        )
        text = text.replace(
            f'output.printInfo("{HIVE_SKIP_LINE}");\n', "", 1
        )
        if HIVE_SKIP_LINE not in text:
            msgs.append("hive-mind: removida linha printInfo Skipping (root/sudo)")

    if "childSpawn('claude', claudeArgs, {" not in text:
        if text != orig:
            path.write_text(text, encoding="utf-8")
        return msgs + [f"hive-mind: padrão childSpawn não encontrado em {path}"]

    idx = text.find("childSpawn('claude', claudeArgs")
    chunk = text[idx : idx + 450] if idx != -1 else ""
    if "env: {" in chunk and "IS_SANDBOX: process.env.IS_SANDBOX" in chunk:
        msgs.append("hive-mind: env IS_SANDBOX já presente")
    elif HIVE_BEFORE in text:
        text = text.replace(HIVE_BEFORE, HIVE_AFTER, 1)
        msgs.append("hive-mind: env IS_SANDBOX no spawn")
    else:
        print(f"Aviso: bloco childSpawn hive-mind não reconhecido em {path}", file=sys.stderr)

    if text != orig:
        path.write_text(text, encoding="utf-8")
    return msgs


def main() -> int:
    try:
        root = npm_global_root()
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        print(f"npm root -g falhou: {e}", file=sys.stderr)
        return 1

    headless = root / "@claude-flow" / "cli" / "dist" / "src" / "services" / "headless-worker-executor.js"
    hive = root / "@claude-flow" / "cli" / "dist" / "src" / "commands" / "hive-mind.js"

    if not headless.is_file():
        print(f"Ficheiro inexistente: {headless}", file=sys.stderr)
        return 1

    for m in patch_headless(headless):
        print(m)
    for m in patch_hive_mind(hive):
        print(m)

    print(f"OK: {headless}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
