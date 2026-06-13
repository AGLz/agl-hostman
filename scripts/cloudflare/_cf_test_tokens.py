#!/usr/bin/env python3
import json
import os
import urllib.error
import urllib.request


def test_token(t: str) -> tuple[str, str]:
    req = urllib.request.Request(
        "https://api.cloudflare.com/client/v4/user/tokens/verify",
        headers={"Authorization": f"Bearer {t}"},
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            d = json.loads(r.read())
        return "OK", str(d.get("result", {}).get("status"))
    except urllib.error.HTTPError as e:
        return "FAIL", str(e.code)


def tokens_from_zshrc(path: str) -> list[str]:
    if not os.path.isfile(path):
        return []
    out: list[str] = []
    for line in open(path):
        if "export CLOUDFLARE_API_TOKEN=" in line and not line.strip().startswith("#"):
            out.append(line.split("=", 1)[1].strip().strip('"').strip("'"))
    return out


def tokens_from_json(path: str) -> list[str]:
    if not os.path.isfile(path):
        return []
    out: list[str] = []

    def find(obj) -> None:
        if isinstance(obj, dict):
            for k, v in obj.items():
                if k == "CLOUDFLARE_API_TOKEN" and isinstance(v, str) and len(v) > 15:
                    out.append(v)
                find(v)
        elif isinstance(obj, list):
            for i in obj:
                find(i)

    try:
        with open(path) as f:
            find(json.load(f))
    except (json.JSONDecodeError, OSError):
        return []
    return out


def main() -> None:
    files = [
        "/root/.zshrc",
        "/root/.zshrc.backup.20260124_144301",
        "/root/.claude.json",
        "/root/.claude.json.backup",
    ]
    seen: set[str] = set()
    for f in files:
        for t in tokens_from_zshrc(f) + tokens_from_json(f):
            if t in seen:
                continue
            seen.add(t)
            status, detail = test_token(t)
            print(f"{f}: len={len(t)} {status} {detail}")


if __name__ == "__main__":
    main()
