#!/usr/bin/env python3
"""SHA1 info-hash (hex) de ficheiro .torrent — só stdlib."""

from __future__ import annotations

import hashlib
import sys


def _decode(data: bytes, index: int = 0) -> tuple[object, int]:
    if index >= len(data):
        raise ValueError("unexpected end of bencode")

    char = data[index: index + 1]
    if char and char[0:1].isdigit():
        colon = data.index(b":", index)
        length = int(data[index:colon])
        start = colon + 1
        return data[start: start + length], start + length
    if char == b"d":
        index += 1
        result: dict[bytes, object] = {}
        while data[index: index + 1] != b"e":
            key, index = _decode(data, index)
            value, index = _decode(data, index)
            result[key] = value
        return result, index + 1
    if char == b"l":
        index += 1
        result_list: list[object] = []
        while data[index: index + 1] != b"e":
            item, index = _decode(data, index)
            result_list.append(item)
        return result_list, index + 1
    if char == b"i":
        end = data.index(b"e", index)
        return int(data[index + 1: end]), end + 1

    raise ValueError(f"invalid bencode at {index}")


def info_hash_from_bytes(torrent_bytes: bytes) -> str:
    root, _ = _decode(torrent_bytes)
    if not isinstance(root, dict) or b"info" not in root:
        raise ValueError("torrent sem dicionário info")

    info = root[b"info"]
    if not isinstance(info, dict):
        raise ValueError("info inválido")

    encoded, _ = _encode(info)
    return hashlib.sha1(encoded).hexdigest()


def _encode(value: object) -> tuple[bytes, int]:
    if isinstance(value, bytes):
        return f"{len(value)}:".encode() + value, 0
    if isinstance(value, str):
        b = value.encode()
        return f"{len(b)}:".encode() + b, 0
    if isinstance(value, int):
        return f"i{value}e".encode(), 0
    if isinstance(value, list):
        parts = [b"l"]
        for item in value:
            chunk, _ = _encode(item)
            parts.append(chunk)
        parts.append(b"e")
        return b"".join(parts), 0
    if isinstance(value, dict):
        parts = [b"d"]
        for key in sorted(value.keys(), key=lambda k: (isinstance(k, bytes), k)):
            key_chunk, _ = _encode(key)
            val_chunk, _ = _encode(value[key])
            parts.extend([key_chunk, val_chunk])
        parts.append(b"e")
        return b"".join(parts), 0

    raise TypeError(type(value))


def main() -> None:
    path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/bench-test.torrent"
    data = open(path, "rb").read()
    print(info_hash_from_bytes(data))


if __name__ == "__main__":
    main()
