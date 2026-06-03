#!/usr/bin/env python3
"""Benchmark Deluge via daemon RPC (CT157)."""
import base64
import os
import re
import sys
import time

from deluge.ui.client import client
from twisted.internet import reactor

TORRENT = "/tmp/bench-test.torrent"
OUT = "/mnt/overpower/downs/bench-deluge"
TNAME = sys.argv[1] if len(sys.argv) > 1 else "debian-13.5.0-amd64-netinst.iso"
PASS = os.environ.get("DL_DAEMON_PASS", "del4936klfap")

CONNECT_ERR: list[str] = []
deadline = time.time() + 1200
connect_guard = None
download_start: float | None = None
peak_rate = 0
completed_bytes = 0
bench_start = time.time()


def _cancel_connect_guard():
    global connect_guard
    if connect_guard is not None and connect_guard.active():
        connect_guard.cancel()
    connect_guard = None


def _fail(failure):
    CONNECT_ERR.append(str(failure.value))
    print(f"RESULT ERROR {failure.value}")
    reactor.stop()


def _done():
    elapsed = (
        time.time() - download_start) if download_start else (time.time() - bench_start)
    avg_bps = 0
    iso = f"{OUT}/{TNAME}"
    if elapsed > 0:
        if completed_bytes > 0:
            avg_bps = int(completed_bytes / elapsed)
        elif os.path.isfile(iso):
            avg_bps = int(os.path.getsize(iso) / elapsed)
    print(
        f"RESULT COMPLETE name={TNAME} peak_MiBs={peak_rate / 1048576:.2f} "
        f"avg_MiBs={avg_bps / 1048576:.2f} download_elapsed_sec={elapsed:.0f}"
    )
    reactor.stop()


def _status_val(status: dict, key: str):
    """Deluge RPC may return str or bytes keys depending on version."""
    if key in status:
        return status[key]
    bkey = key.encode()
    if bkey in status:
        return status[bkey]
    raise KeyError(key)


def _poll(tid):
    if time.time() > deadline:
        print("RESULT TIMEOUT")
        reactor.stop()
        return

    def _got_status(t):
        global download_start, peak_rate, completed_bytes
        prog = float(_status_val(t, "progress"))
        if prog > 1.0:
            prog /= 100.0
        rate = int(_status_val(t, "download_payload_rate"))
        state_raw = _status_val(t, "state")
        state = state_raw.decode() if isinstance(state_raw, bytes) else str(state_raw)
        if prog < 0.99 and rate > 0:
            if download_start is None:
                download_start = time.time()
            peak_rate = max(peak_rate, rate)
        print(
            f"state={state} progress={prog:.4f} rate_MiBs={rate / 1048576:.2f}")
        if prog >= 0.995:
            iso = f"{OUT}/{TNAME}"
            if os.path.isfile(iso):
                completed_bytes = os.path.getsize(iso)
            client.core.remove_torrent(tid, False).addBoth(lambda _: _done())
        else:
            reactor.callLater(5, lambda: _poll(tid))

    client.core.get_torrent_status(
        tid, ["state", "progress", "download_payload_rate", "name"]
    ).addCallback(_got_status).addErrback(_fail)


def _begin_poll(tid):
    print(f"torrent_id={tid}")
    client.core.resume_torrent([tid]).addCallback(
        lambda _: _poll(tid)).addErrback(_fail)


def _added(tid):
    _begin_poll(tid)


def _reuse_existing(failure):
    msg = str(failure.value)
    match = re.search(r"\(([a-f0-9]{40})\)", msg)
    if "already in session" in msg and match:
        tid = match.group(1)
        print(f"torrent_id={tid} (already in session — remove+re-add fresh)")
        client.core.remove_torrent(tid, True).addCallback(
            lambda _: _run_benchmark(None)
        ).addErrback(_fail)
        return
    _fail(failure)


def _run_benchmark(_result=None):
    _cancel_connect_guard()
    with open(TORRENT, "rb") as handle:
        filedump = base64.b64encode(handle.read()).decode("ascii")
    client.core.add_torrent_file(
        os.path.basename(TORRENT),
        filedump,
        {"download_location": OUT},
    ).addCallback(_added).addErrback(_reuse_existing)


def _connect_timeout():
    if reactor.running:
        _fail(type("E", (), {"value": "connect timeout"})())


client.connect("127.0.0.1", 58846, "localclient", PASS).addCallback(
    _run_benchmark
).addErrback(_fail)
connect_guard = reactor.callLater(90, _connect_timeout)
reactor.run()
if CONNECT_ERR:
    sys.exit(1)
