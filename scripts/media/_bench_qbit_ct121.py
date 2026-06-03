#!/usr/bin/env python3
"""Benchmark qBittorrent CT121 — download fresco com métricas de velocidade."""

from __future__ import annotations

import json
import os
import shutil
import sys
import time
import urllib.parse
import urllib.request

TNAME = sys.argv[1] if len(sys.argv) > 1 else "debian-13.5.0-amd64-netinst.iso"
INFO_HASH = os.environ["TORRENT_HASH"].lower()
USER = os.environ["QB_USER"]
PASSWORD = os.environ["QB_PASS"]
HOST, PORT = "127.0.0.1", 8090
BENCH_TAG = "agl-bench"
BENCH_DIR = "/mnt/overpower/downs/bench-qbit"
TORRENT_PATH = "/tmp/bench-test.torrent"


def main() -> None:
    jar = urllib.request.HTTPCookieProcessor()
    opener = urllib.request.build_opener(jar)

    def post(path: str, data: dict | None = None, raw: bytes | None = None, headers: dict | None = None):
        url = f"http://{HOST}:{PORT}/api/v2{path}"
        if raw is not None:
            req = urllib.request.Request(
                url, data=raw, method="POST", headers=headers or {})
        else:
            req = urllib.request.Request(url, data=urllib.parse.urlencode(
                data or {}).encode(), method="POST")
        return opener.open(req, timeout=120)

    def torrent_by_hash():
        url = f"http://{HOST}:{PORT}/api/v2/torrents/info?hashes={INFO_HASH}"
        resp = opener.open(url, timeout=30)
        items = json.loads(resp.read())
        return items[0] if items else None

    post("/auth/login", {"username": USER, "password": PASSWORD})

    print(f"prep: limpar {BENCH_DIR} e torrent {INFO_HASH[:8]}…")
    existing = torrent_by_hash()
    if existing:
        post("/torrents/delete", {"hashes": INFO_HASH, "deleteFiles": "true"})
        for _ in range(60):
            if torrent_by_hash() is None:
                break
            time.sleep(1)
        else:
            print("AVISO: torrent ainda na sessão após delete")

    shutil.rmtree(BENCH_DIR, ignore_errors=True)
    os.makedirs(BENCH_DIR, exist_ok=True)

    with open(TORRENT_PATH, "rb") as handle:
        body = handle.read()
    boundary = "----aglbench"
    parts: list[bytes] = []
    for field, value in (
        ("tags", BENCH_TAG),
        ("category", BENCH_TAG),
        ("paused", "false"),
        ("savepath", BENCH_DIR),
        ("autoTMM", "false"),
    ):
        parts.append(
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"{field}\"\r\n\r\n{value}\r\n".encode()
        )
    parts.append(
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"torrents\"; filename=\"b.torrent\"\r\n"
        f"Content-Type: application/x-bittorrent\r\n\r\n".encode()
    )
    parts.append(body)
    parts.append(f"\r\n--{boundary}--\r\n".encode())
    payload = b"".join(parts)
    post(
        "/torrents/add",
        raw=payload,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    )
    print(f"torrent added fresh tag={BENCH_TAG} savepath={BENCH_DIR}")

    deadline = time.time() + 1200
    download_start: float | None = None
    peak_bps = 0
    last = ""

    while time.time() < deadline:
        torrent = torrent_by_hash()
        if not torrent:
            time.sleep(3)
            continue

        dl = int(torrent.get("dlspeed", 0))
        prog = float(torrent.get("progress", 0))
        state = torrent.get("state", "")
        size = int(torrent.get("size", 0) or 0)

        if state in ("downloading", "stalledDL", "forcedDL", "metaDL") and prog < 0.99:
            if download_start is None and dl > 0:
                download_start = time.time()
            peak_bps = max(peak_bps, dl)

        last = f"state={state} progress={prog:.4f} dlspeed_MiBs={dl / 1048576:.2f}"
        print(last)

        if state == "missingFiles":
            post("/torrents/setLocation",
                 {"hashes": INFO_HASH, "location": BENCH_DIR})
            post("/torrents/recheck", {"hashes": INFO_HASH})
            post("/torrents/resume", {"hashes": INFO_HASH})
            print("retry missingFiles: relocate+recheck")
            time.sleep(5)
            continue

        if prog >= 0.995 or state in ("uploading", "stalledUP", "pausedUP", "forcedUP"):
            elapsed = (time.time() - download_start) if download_start else 0.0
            avg_bps = int(size / elapsed) if elapsed > 0 and size > 0 else 0
            print(
                f"RESULT COMPLETE name={torrent.get('name')} size={size} "
                f"peak_MiBs={peak_bps / 1048576:.2f} avg_MiBs={avg_bps / 1048576:.2f} "
                f"download_elapsed_sec={elapsed:.0f}"
            )
            sys.exit(0)

        time.sleep(5)

    print("RESULT TIMEOUT")
    print(last)
    sys.exit(2)


if __name__ == "__main__":
    main()
