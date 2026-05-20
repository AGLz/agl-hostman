#!/usr/bin/env python3
"""Idempotente: adiciona _check_telegram ao services.routes.py já patcheado (Docker sem `screen`)."""

from __future__ import annotations

from pathlib import Path


def main() -> None:
    path = Path("/opt/evonexus/services.routes.py")
    if not path.is_file():
        raise SystemExit(f"ficheiro inexistente: {path}")

    lines = path.read_text(encoding="utf-8").splitlines()

    if any(line.startswith("def _check_telegram") for line in lines):
        print("OK: _check_telegram já existe — nada a fazer")
        return

    idx_services_route = next(
        i for i, line in enumerate(lines) if line.startswith('@bp.route("/api/services")')
    )

    telegram_fn = [
        "",
        "def _check_telegram() -> dict:",
        '    """Telegram: sessão screen (legado) ou stack Docker Compose (hostname do serviço)."""',
        '    if shutil.which("screen"):',
        '        result = _check_process(["screen", "-list"], pipe_grep="telegram")',
        '        if result["running"]:',
        "            return result",
        '    host = os.environ.get("EVONEXUS_TELEGRAM_SERVICE_HOST", "telegram")',
        "    try:",
        "        import socket",
        "",
        "        socket.getaddrinfo(host, None)",
        '        return {"running": True, "detail": f"Compose: hostname `{host}` resolve na rede Docker"}',
        "    except OSError:",
        "        pass",
        '    return {"running": False, "detail": ""}',
        "",
    ]
    lines = lines[:idx_services_route] + telegram_fn + lines[idx_services_route:]

    replaced_svc = False
    for i, line in enumerate(lines):
        if line == '            **_check_process(["screen", "-list"], pipe_grep="telegram"),':
            lines[i] = "            **_check_telegram(),"
            replaced_svc = True
            break
    if not replaced_svc:
        raise SystemExit("não encontrei list_services telegram")

    replaced_logs = False
    for i, line in enumerate(lines):
        if line == '            result = _check_process(["screen", "-list"], pipe_grep="telegram")':
            lines[i] = "            result = _check_telegram()"
            replaced_logs = True
            break
    if not replaced_logs:
        raise SystemExit("não encontrei service_logs telegram screen fallback")

    tg_block_start = next(
        i for i, line in enumerate(lines) if line.strip() == 'if service_id == "telegram":'
    )
    tg_block_end = next(
        i for i in range(tg_block_start + 1, len(lines)) if lines[i].startswith("    elif ")
    )
    for i in range(tg_block_start, tg_block_end):
        if 'f"Screen: {result' in lines[i]:
            lines[i] = lines[i].replace("Screen:", "Detection:")
            break

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"OK escrito: {path}")


if __name__ == "__main__":
    main()
