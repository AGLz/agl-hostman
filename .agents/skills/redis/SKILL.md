---
name: redis
version: "3.0.2"
author: BytesAgain
homepage: https://bytesagain.com
source: https://github.com/bytesagain/ai-skills
license: MIT-0
tags: [redis, tool, utility]
description: "Connect, query, and monitor Redis instances. Use when checking key health, validating data types, generating backups, formatting results, linting configs."
---

# redis

Connect, query, and monitor Redis instances. Use when checking key health, validating data types, generating backups, formatting results, linting configs.

## Commands

### `REDIS_HOST`

(default: 127.0.0.1)

```bash
scripts/script.sh REDIS_HOST
```

### `REDIS_PORT`

(default: 6379)

```bash
scripts/script.sh REDIS_PORT
```

### `REDIS_DB`

(default: 0)

```bash
scripts/script.sh REDIS_DB
```

### `ping`

Test Redis connectivity and latency

```bash
scripts/script.sh ping
```

### `info`

Server info (sections: server, clients, memory, stats, etc.)

```bash
scripts/script.sh info [section]
```

### `get`

Get value (auto-detects type: string, list, set, hash, zset)

```bash
scripts/script.sh get <key>
```

### `set`

Set a key-value pair (extra opts passed to Redis SET)

```bash
scripts/script.sh set <key> <val> [opts]
```

### `del`

Delete one or more keys

```bash
scripts/script.sh del <key> [key...]
```

### `keys`

List keys matching pattern (default: *)

```bash
scripts/script.sh keys [pattern]
```

### `monitor`

Live stream of all Redis commands

```bash
scripts/script.sh monitor
```

### `stats`

Comprehensive server statistics

```bash
scripts/script.sh stats
```

### `flush-confirm`

Flush current database (with confirmation)

```bash
scripts/script.sh flush-confirm
```

### `export`

Export all keys to a file

```bash
scripts/script.sh export <file>
```

### `import`

Import keys from an export file

```bash
scripts/script.sh import <file>
```

### `ttl`

Check TTL of a key

```bash
scripts/script.sh ttl <key>
```

### `type`

Check type of a key

```bash
scripts/script.sh type <key>
```

### `dbsize`

Show number of keys

```bash
scripts/script.sh dbsize
```

### `slowlog`

Show slow query log (default: 10 entries)

```bash
scripts/script.sh slowlog [count]
```

## Requirements

- redis-cli

---

*Powered by BytesAgain | bytesagain.com | hello@bytesagain.com*

## Configuration

| Variable | Required | Description |
|----------|----------|-------------|
| `REDIS_HOST` | No | Redis host (default: 127.0.0.1) |
| `REDIS_PORT` | No | Redis port (default: 6379) |
| `REDIS_DB` | No | Redis database number (default: 0) |
| `REDIS_PASSWORD` | No | Redis authentication password |

## Data Storage

Connection history and command logs are saved to `~/.local/share/redis-helper/`.

## Security

Redis credentials are passed via environment variables. The password is used in redis-cli command-line arguments as required by the redis-cli interface.
