#!/usr/bin/env bash
###############################################################################
# Redis CLI Helper
# A comprehensive Redis management tool for common operations.
#
# Powered by BytesAgain | bytesagain.com | hello@bytesagain.com
#
# Requirements: redis-cli
#
# Usage: script.sh <command> [arguments...]
#
# Commands:
#   ping                  Test Redis connectivity
#   info [section]        Show Redis server info (optionally filtered by section)
#   get <key>             Get value for a key
#   set <key> <value>     Set a key-value pair
#   del <key> [key...]    Delete one or more keys
#   keys [pattern]        List keys matching pattern (default: *)
#   monitor               Live monitor of all Redis commands
#   stats                 Show key statistics and memory usage
#   flush-confirm         Flush all keys (requires confirmation)
#   export <file>         Export all keys to a file (key-value dump)
#   import <file>         Import keys from an export file
#   ttl <key>             Get TTL for a key
#   type <key>            Get the type of a key
#   dbsize                Show number of keys in current database
#   slowlog [count]       Show slow queries log
#   help                  Show this help message
###############################################################################
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
DATA_DIR="${HOME}/.local/share/redis-helper"
EXPORT_DIR="${DATA_DIR}/exports"
LOG_FILE="${DATA_DIR}/redis-helper.log"

# Redis connection defaults
REDIS_HOST="${REDIS_HOST:-127.0.0.1}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_DB="${REDIS_DB:-0}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"

BRAND="Powered by BytesAgain | bytesagain.com | hello@bytesagain.com"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

###############################################################################
# Utility functions
###############################################################################

_init() {
    mkdir -p "$DATA_DIR" "$EXPORT_DIR"
    touch "$LOG_FILE"
}

_log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$ts] $*" >> "$LOG_FILE"
}

_info()  { echo -e "${GREEN}[✓]${NC} $*"; }
_warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
_error() { echo -e "${RED}[✗]${NC} $*" >&2; }
_header(){ echo -e "${BOLD}${CYAN}═══ $* ═══${NC}"; }

_check_redis_cli() {
    if ! command -v redis-cli &>/dev/null; then
        _error "redis-cli is not installed or not in PATH."
        echo ""
        echo "Install redis-cli:"
        echo "  Ubuntu/Debian: sudo apt-get install redis-tools"
        echo "  CentOS/RHEL:   sudo yum install redis"
        echo "  macOS:         brew install redis"
        echo "  Alpine:        apk add redis"
        echo ""
        echo "Or download from: https://redis.io/download"
        exit 1
    fi
}

_build_redis_cmd() {
    local cmd=(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -n "$REDIS_DB")
    if [[ -n "$REDIS_PASSWORD" ]]; then
        cmd+=(-a "$REDIS_PASSWORD" --no-auth-warning)
    fi
    echo "${cmd[@]}"
}

_redis() {
    local rcmd
    rcmd="$(_build_redis_cmd)"
    # shellcheck disable=SC2086
    $rcmd "$@"
}

_redis_raw() {
    local rcmd
    rcmd="$(_build_redis_cmd)"
    # shellcheck disable=SC2086
    $rcmd --raw "$@"
}

_check_connection() {
    local result
    result="$(_redis PING 2>&1)" || true
    if [[ "$result" != "PONG" ]]; then
        _error "Cannot connect to Redis at ${REDIS_HOST}:${REDIS_PORT} (db ${REDIS_DB})"
        _error "Response: $result"
        echo ""
        echo "Check that:"
        echo "  1. Redis server is running"
        echo "  2. Host/port are correct (set REDIS_HOST, REDIS_PORT env vars)"
        echo "  3. Password is correct (set REDIS_PASSWORD env var)"
        exit 1
    fi
}

_format_bytes() {
    local bytes=$1
    if (( bytes >= 1073741824 )); then
        echo "$(awk "BEGIN {printf \"%.2f GB\", $bytes/1073741824}")"
    elif (( bytes >= 1048576 )); then
        echo "$(awk "BEGIN {printf \"%.2f MB\", $bytes/1048576}")"
    elif (( bytes >= 1024 )); then
        echo "$(awk "BEGIN {printf \"%.2f KB\", $bytes/1024}")"
    else
        echo "${bytes} B"
    fi
}

###############################################################################
# Command implementations
###############################################################################

cmd_ping() {
    _check_connection
    local latency_result
    latency_result="$(_redis --latency -c 5 2>&1)" || true
    _info "PONG — Redis is alive at ${REDIS_HOST}:${REDIS_PORT}"
    if [[ -n "$latency_result" ]]; then
        echo -e "  ${BLUE}Latency:${NC} $latency_result"
    fi
    _log "PING: success"
}

cmd_info() {
    _check_connection
    local section="${1:-}"
    _header "Redis Server Info"
    if [[ -n "$section" ]]; then
        echo -e "${BLUE}Section:${NC} $section"
        echo ""
        _redis INFO "$section"
    else
        local version uptime_s clients memory keys
        version="$(_redis_raw INFO server | grep -E '^redis_version:' | cut -d: -f2 | tr -d '[:space:]')"
        uptime_s="$(_redis_raw INFO server | grep -E '^uptime_in_seconds:' | cut -d: -f2 | tr -d '[:space:]')"
        clients="$(_redis_raw INFO clients | grep -E '^connected_clients:' | cut -d: -f2 | tr -d '[:space:]')"
        memory="$(_redis_raw INFO memory | grep -E '^used_memory_human:' | cut -d: -f2 | tr -d '[:space:]')"
        keys="$(_redis_raw INFO keyspace | grep -E '^db' || echo '(none)')"

        echo -e "  ${BOLD}Version:${NC}     ${version:-unknown}"
        if [[ -n "$uptime_s" && "$uptime_s" =~ ^[0-9]+$ ]]; then
            local days=$(( uptime_s / 86400 ))
            local hours=$(( (uptime_s % 86400) / 3600 ))
            local mins=$(( (uptime_s % 3600) / 60 ))
            echo -e "  ${BOLD}Uptime:${NC}      ${days}d ${hours}h ${mins}m"
        fi
        echo -e "  ${BOLD}Clients:${NC}     ${clients:-unknown}"
        echo -e "  ${BOLD}Memory:${NC}      ${memory:-unknown}"
        echo -e "  ${BOLD}Keyspace:${NC}"
        if [[ "$keys" == "(none)" ]]; then
            echo "    (no databases with keys)"
        else
            echo "$keys" | while IFS= read -r line; do
                echo "    $line"
            done
        fi
    fi
    _log "INFO: section=${section:-all}"
}

cmd_get() {
    local key="${1:?Usage: $SCRIPT_NAME get <key>}"
    _check_connection

    local key_type
    key_type="$(_redis_raw TYPE "$key")"

    case "$key_type" in
        string)
            local val
            val="$(_redis_raw GET "$key")"
            local ttl
            ttl="$(_redis_raw TTL "$key")"
            echo -e "${BOLD}Key:${NC}   $key"
            echo -e "${BOLD}Type:${NC}  string"
            echo -e "${BOLD}TTL:${NC}   $( [[ "$ttl" == "-1" ]] && echo "no expiry" || echo "${ttl}s" )"
            echo -e "${BOLD}Value:${NC} $val"
            ;;
        list)
            local len
            len="$(_redis_raw LLEN "$key")"
            echo -e "${BOLD}Key:${NC}  $key"
            echo -e "${BOLD}Type:${NC} list (length: $len)"
            echo -e "${BOLD}Values:${NC}"
            _redis_raw LRANGE "$key" 0 -1 | head -100
            [[ "$len" -gt 100 ]] && echo "  ... (showing 100 of $len)"
            ;;
        set)
            local len
            len="$(_redis_raw SCARD "$key")"
            echo -e "${BOLD}Key:${NC}  $key"
            echo -e "${BOLD}Type:${NC} set (members: $len)"
            echo -e "${BOLD}Members:${NC}"
            _redis_raw SMEMBERS "$key" | head -100
            [[ "$len" -gt 100 ]] && echo "  ... (showing 100 of $len)"
            ;;
        hash)
            local len
            len="$(_redis_raw HLEN "$key")"
            echo -e "${BOLD}Key:${NC}  $key"
            echo -e "${BOLD}Type:${NC} hash (fields: $len)"
            echo -e "${BOLD}Fields:${NC}"
            _redis_raw HGETALL "$key" | paste - - | head -100
            ;;
        zset)
            local len
            len="$(_redis_raw ZCARD "$key")"
            echo -e "${BOLD}Key:${NC}  $key"
            echo -e "${BOLD}Type:${NC} sorted set (members: $len)"
            echo -e "${BOLD}Members (score → value):${NC}"
            _redis_raw ZRANGE "$key" 0 -1 WITHSCORES | paste - - | head -100
            ;;
        none)
            _warn "Key '$key' does not exist"
            return 1
            ;;
        *)
            _warn "Key '$key' has unsupported type: $key_type"
            _redis_raw GET "$key" 2>/dev/null || _redis_raw DUMP "$key" 2>/dev/null || echo "(cannot display)"
            ;;
    esac
    _log "GET: key=$key type=$key_type"
}

cmd_set() {
    local key="${1:?Usage: $SCRIPT_NAME set <key> <value> [EX seconds]}"
    local value="${2:?Usage: $SCRIPT_NAME set <key> <value> [EX seconds]}"
    shift 2
    _check_connection

    local extra_args=("$@")
    local result
    result="$(_redis SET "$key" "$value" "${extra_args[@]}" 2>&1)"
    if [[ "$result" == "OK" ]]; then
        _info "Set '$key' = '$value'"
        [[ ${#extra_args[@]} -gt 0 ]] && echo "  Options: ${extra_args[*]}"
    else
        _error "Failed to set key: $result"
        return 1
    fi
    _log "SET: key=$key"
}

cmd_del() {
    [[ $# -eq 0 ]] && { _error "Usage: $SCRIPT_NAME del <key> [key...]"; return 1; }
    _check_connection

    local count
    count="$(_redis DEL "$@")"
    if [[ "$count" -gt 0 ]]; then
        _info "Deleted $count key(s): $*"
    else
        _warn "No keys deleted (keys may not exist): $*"
    fi
    _log "DEL: keys=$* count=$count"
}

cmd_keys() {
    local pattern="${1:-*}"
    _check_connection

    _header "Keys matching: $pattern"
    local keys_output count
    keys_output="$(_redis_raw KEYS "$pattern")"
    if [[ -z "$keys_output" ]]; then
        echo "(no keys found)"
        return 0
    fi

    count="$(echo "$keys_output" | wc -l)"
    echo -e "${BLUE}Found:${NC} $count key(s)"
    echo ""

    echo "$keys_output" | while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        local ktype
        ktype="$(_redis_raw TYPE "$key")"
        local ttl
        ttl="$(_redis_raw TTL "$key")"
        local ttl_str
        ttl_str="$( [[ "$ttl" == "-1" ]] && echo "∞" || echo "${ttl}s" )"
        printf "  %-40s  %-8s  TTL: %s\n" "$key" "[$ktype]" "$ttl_str"
    done
    _log "KEYS: pattern=$pattern count=$count"
}

cmd_monitor() {
    _check_connection
    _header "Redis Monitor (live)"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""
    # shellcheck disable=SC2086
    $(_build_redis_cmd) MONITOR
}

cmd_stats() {
    _check_connection
    _header "Redis Statistics"

    local mem_used mem_peak mem_frag hit miss ratio dbsize
    mem_used="$(_redis_raw INFO memory | grep -E '^used_memory:' | cut -d: -f2 | tr -d '[:space:]')"
    mem_peak="$(_redis_raw INFO memory | grep -E '^used_memory_peak:' | cut -d: -f2 | tr -d '[:space:]')"
    mem_frag="$(_redis_raw INFO memory | grep -E '^mem_fragmentation_ratio:' | cut -d: -f2 | tr -d '[:space:]')"
    hit="$(_redis_raw INFO stats | grep -E '^keyspace_hits:' | cut -d: -f2 | tr -d '[:space:]')"
    miss="$(_redis_raw INFO stats | grep -E '^keyspace_misses:' | cut -d: -f2 | tr -d '[:space:]')"
    dbsize="$(_redis_raw DBSIZE | grep -oE '[0-9]+')"

    echo ""
    echo -e "  ${BOLD}Memory Used:${NC}       $(_format_bytes "${mem_used:-0}")"
    echo -e "  ${BOLD}Memory Peak:${NC}       $(_format_bytes "${mem_peak:-0}")"
    echo -e "  ${BOLD}Fragmentation:${NC}     ${mem_frag:-N/A}"
    echo ""

    if [[ -n "$hit" && -n "$miss" ]]; then
        local total=$(( hit + miss ))
        if (( total > 0 )); then
            ratio="$(awk "BEGIN {printf \"%.2f\", ($hit / $total) * 100}")"
            echo -e "  ${BOLD}Cache Hits:${NC}        $hit"
            echo -e "  ${BOLD}Cache Misses:${NC}      $miss"
            echo -e "  ${BOLD}Hit Ratio:${NC}         ${ratio}%"
        else
            echo -e "  ${BOLD}Cache Hits:${NC}        0"
            echo -e "  ${BOLD}Cache Misses:${NC}      0"
        fi
    fi
    echo ""
    echo -e "  ${BOLD}Total Keys:${NC}        ${dbsize:-0}"

    # Show per-db breakdown
    local keyspace
    keyspace="$(_redis_raw INFO keyspace | grep -E '^db')" || true
    if [[ -n "$keyspace" ]]; then
        echo ""
        echo -e "  ${BOLD}Keyspace:${NC}"
        echo "$keyspace" | while IFS= read -r line; do
            echo "    $line"
        done
    fi

    # Connected clients info
    local clients_connected blocked
    clients_connected="$(_redis_raw INFO clients | grep -E '^connected_clients:' | cut -d: -f2 | tr -d '[:space:]')"
    blocked="$(_redis_raw INFO clients | grep -E '^blocked_clients:' | cut -d: -f2 | tr -d '[:space:]')"
    echo ""
    echo -e "  ${BOLD}Connected Clients:${NC} ${clients_connected:-0}"
    echo -e "  ${BOLD}Blocked Clients:${NC}   ${blocked:-0}"

    # Ops per second
    local ops
    ops="$(_redis_raw INFO stats | grep -E '^instantaneous_ops_per_sec:' | cut -d: -f2 | tr -d '[:space:]')"
    echo -e "  ${BOLD}Ops/sec:${NC}           ${ops:-0}"

    _log "STATS: dbsize=$dbsize"
}

cmd_flush_confirm() {
    _check_connection
    local dbsize
    dbsize="$(_redis_raw DBSIZE | grep -oE '[0-9]+')"

    _warn "This will delete ALL ${dbsize:-0} keys in database ${REDIS_DB} on ${REDIS_HOST}:${REDIS_PORT}"
    echo ""
    read -rp "Type 'YES FLUSH' to confirm: " confirm
    if [[ "$confirm" == "YES FLUSH" ]]; then
        _redis FLUSHDB
        _info "Database ${REDIS_DB} flushed."
        _log "FLUSHDB: confirmed, dbsize was $dbsize"
    else
        _warn "Aborted. No data was deleted."
        _log "FLUSHDB: aborted by user"
    fi
}

cmd_export() {
    local outfile="${1:?Usage: $SCRIPT_NAME export <file>}"
    _check_connection

    # Resolve relative paths to export dir
    if [[ "$outfile" != /* ]]; then
        outfile="${EXPORT_DIR}/${outfile}"
    fi

    _header "Exporting keys to: $outfile"
    mkdir -p "$(dirname "$outfile")"

    local count=0
    local tmpfile
    tmpfile="$(mktemp)"

    _redis_raw KEYS '*' | while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        local ktype
        ktype="$(_redis_raw TYPE "$key")"
        local ttl
        ttl="$(_redis_raw TTL "$key")"

        case "$ktype" in
            string)
                local val
                val="$(_redis_raw GET "$key")"
                echo "STRING|${key}|${ttl}|${val}" >> "$tmpfile"
                ;;
            list)
                local vals
                vals="$(_redis_raw LRANGE "$key" 0 -1 | paste -sd ',' -)"
                echo "LIST|${key}|${ttl}|${vals}" >> "$tmpfile"
                ;;
            set)
                local vals
                vals="$(_redis_raw SMEMBERS "$key" | paste -sd ',' -)"
                echo "SET|${key}|${ttl}|${vals}" >> "$tmpfile"
                ;;
            hash)
                local vals
                vals="$(_redis_raw HGETALL "$key" | paste - - | tr '\t' '=' | paste -sd ',' -)"
                echo "HASH|${key}|${ttl}|${vals}" >> "$tmpfile"
                ;;
            zset)
                local vals
                vals="$(_redis_raw ZRANGE "$key" 0 -1 WITHSCORES | paste - - | tr '\t' ':' | paste -sd ',' -)"
                echo "ZSET|${key}|${ttl}|${vals}" >> "$tmpfile"
                ;;
            *)
                echo "# SKIP|${key}|unsupported type: ${ktype}" >> "$tmpfile"
                ;;
        esac
    done

    mv "$tmpfile" "$outfile"
    count="$(grep -cv '^#' "$outfile" 2>/dev/null || echo 0)"
    _info "Exported $count key(s) to $outfile"
    _log "EXPORT: file=$outfile count=$count"
}

cmd_import() {
    local infile="${1:?Usage: $SCRIPT_NAME import <file>}"
    _check_connection

    if [[ "$infile" != /* ]]; then
        infile="${EXPORT_DIR}/${infile}"
    fi

    if [[ ! -f "$infile" ]]; then
        _error "File not found: $infile"
        return 1
    fi

    _header "Importing keys from: $infile"
    local imported=0 skipped=0

    while IFS='|' read -r ktype key ttl value; do
        [[ -z "$ktype" || "$ktype" == \#* ]] && continue

        case "$ktype" in
            STRING)
                _redis SET "$key" "$value" >/dev/null
                ;;
            LIST)
                _redis DEL "$key" >/dev/null
                IFS=',' read -ra items <<< "$value"
                for item in "${items[@]}"; do
                    [[ -n "$item" ]] && _redis RPUSH "$key" "$item" >/dev/null
                done
                ;;
            SET)
                _redis DEL "$key" >/dev/null
                IFS=',' read -ra items <<< "$value"
                for item in "${items[@]}"; do
                    [[ -n "$item" ]] && _redis SADD "$key" "$item" >/dev/null
                done
                ;;
            HASH)
                _redis DEL "$key" >/dev/null
                IFS=',' read -ra pairs <<< "$value"
                for pair in "${pairs[@]}"; do
                    local field="${pair%%=*}"
                    local val="${pair#*=}"
                    [[ -n "$field" ]] && _redis HSET "$key" "$field" "$val" >/dev/null
                done
                ;;
            ZSET)
                _redis DEL "$key" >/dev/null
                IFS=',' read -ra pairs <<< "$value"
                for pair in "${pairs[@]}"; do
                    local member="${pair%%:*}"
                    local score="${pair#*:}"
                    [[ -n "$member" ]] && _redis ZADD "$key" "$score" "$member" >/dev/null
                done
                ;;
            *)
                (( skipped++ ))
                continue
                ;;
        esac

        # Set TTL if applicable
        if [[ "$ttl" =~ ^[0-9]+$ && "$ttl" -gt 0 ]]; then
            _redis EXPIRE "$key" "$ttl" >/dev/null
        fi
        (( imported++ ))
    done < "$infile"

    _info "Imported $imported key(s), skipped $skipped"
    _log "IMPORT: file=$infile imported=$imported skipped=$skipped"
}

cmd_ttl() {
    local key="${1:?Usage: $SCRIPT_NAME ttl <key>}"
    _check_connection
    local ttl
    ttl="$(_redis_raw TTL "$key")"
    case "$ttl" in
        -2) _warn "Key '$key' does not exist" ;;
        -1) _info "Key '$key' has no expiry (persistent)" ;;
        *)  _info "Key '$key' expires in ${ttl} seconds" ;;
    esac
}

cmd_type() {
    local key="${1:?Usage: $SCRIPT_NAME type <key>}"
    _check_connection
    local ktype
    ktype="$(_redis_raw TYPE "$key")"
    if [[ "$ktype" == "none" ]]; then
        _warn "Key '$key' does not exist"
    else
        _info "Key '$key' is of type: $ktype"
    fi
}

cmd_dbsize() {
    _check_connection
    local result
    result="$(_redis DBSIZE)"
    _info "$result"
}

cmd_slowlog() {
    local count="${1:-10}"
    _check_connection
    _header "Slow Log (last $count entries)"
    _redis SLOWLOG GET "$count"
}

cmd_help() {
    cat <<EOF

${BOLD}Redis CLI Helper${NC}
${BRAND}

${BOLD}Usage:${NC} $SCRIPT_NAME <command> [arguments...]

${BOLD}Connection:${NC}
  Set environment variables to configure connection:
    REDIS_HOST     (default: 127.0.0.1)
    REDIS_PORT     (default: 6379)
    REDIS_DB       (default: 0)
    REDIS_PASSWORD (default: none)

${BOLD}Commands:${NC}
  ping                    Test Redis connectivity and latency
  info [section]          Server info (sections: server, clients, memory, stats, etc.)
  get <key>               Get value (auto-detects type: string, list, set, hash, zset)
  set <key> <val> [opts]  Set a key-value pair (extra opts passed to Redis SET)
  del <key> [key...]      Delete one or more keys
  keys [pattern]          List keys matching pattern (default: *)
  monitor                 Live stream of all Redis commands
  stats                   Comprehensive server statistics
  flush-confirm           Flush current database (with confirmation)
  export <file>           Export all keys to a file
  import <file>           Import keys from an export file
  ttl <key>               Check TTL of a key
  type <key>              Check type of a key
  dbsize                  Show number of keys
  slowlog [count]         Show slow query log (default: 10 entries)
  help                    Show this help message

${BOLD}Requirements:${NC}
  redis-cli must be installed and in PATH.

${BOLD}Examples:${NC}
  $SCRIPT_NAME ping
  $SCRIPT_NAME set mykey "hello world"
  $SCRIPT_NAME get mykey
  $SCRIPT_NAME keys "user:*"
  $SCRIPT_NAME export backup.dat
  REDIS_HOST=10.0.0.5 $SCRIPT_NAME stats

EOF
}

###############################################################################
# Main dispatcher
###############################################################################

main() {
    _init

    local cmd="${1:-help}"
    shift 2>/dev/null || true

    case "$cmd" in
        ping)           _check_redis_cli; cmd_ping "$@" ;;
        info)           _check_redis_cli; cmd_info "$@" ;;
        get)            _check_redis_cli; cmd_get "$@" ;;
        set)            _check_redis_cli; cmd_set "$@" ;;
        del|delete)     _check_redis_cli; cmd_del "$@" ;;
        keys)           _check_redis_cli; cmd_keys "$@" ;;
        monitor)        _check_redis_cli; cmd_monitor "$@" ;;
        stats)          _check_redis_cli; cmd_stats "$@" ;;
        flush-confirm)  _check_redis_cli; cmd_flush_confirm "$@" ;;
        export)         _check_redis_cli; cmd_export "$@" ;;
        import)         _check_redis_cli; cmd_import "$@" ;;
        ttl)            _check_redis_cli; cmd_ttl "$@" ;;
        type)           _check_redis_cli; cmd_type "$@" ;;
        dbsize)         _check_redis_cli; cmd_dbsize "$@" ;;
        slowlog)        _check_redis_cli; cmd_slowlog "$@" ;;
        help|--help|-h) cmd_help ;;
        *)
            _error "Unknown command: $cmd"
            echo "Run '$SCRIPT_NAME help' for usage."
            exit 1
            ;;
    esac
}

main "$@"
