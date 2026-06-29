#!/usr/bin/env bash
# Fase 0: comparar contagens DB_IDE_Associacao VM620 vs CT610 → CSV
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=_mssql-sync-common.sh
source "${SCRIPT_DIR}/_mssql-sync-common.sh"

require_both_nodes
load_mssql_sync_env

DATE_STAMP="$(date +%Y%m%d)"
OUT_DIR="${REPO_ROOT}/docs/maint/reconcile"
CSV="${OUT_DIR}/DB_IDE_Associacao-reconcile-${DATE_STAMP}.csv"
TMP_CT610="$(mktemp)"
TMP_VM620="$(mktemp)"
ROWCOUNT_SQL="$(mktemp)"
trap 'rm -f "${TMP_CT610}" "${TMP_VM620}" "${ROWCOUNT_SQL}"' EXIT

cat > "${ROWCOUNT_SQL}" <<EOF
USE [${MSSQL_IDE_DATABASE}];
SET NOCOUNT ON;
SELECT t.name AS table_name, SUM(p.rows) AS row_count
FROM sys.tables t
INNER JOIN sys.partitions p ON t.object_id = p.object_id
WHERE t.is_ms_shipped = 0 AND p.index_id IN (0, 1)
GROUP BY t.name
ORDER BY t.name;
EOF

echo "A recolher contagens CT610..."
run_sql_file_ct610 "${ROWCOUNT_SQL}" > "${TMP_CT610}.raw"
echo "A recolher contagens VM620..."
run_sql_file_vm620 "${ROWCOUNT_SQL}" > "${TMP_VM620}.raw"

python3 - "${TMP_CT610}.raw" "${TMP_VM620}.raw" "${CSV}" <<'PY'
import csv
import re
import sys
from pathlib import Path

ct610_path, vm620_path, csv_path = sys.argv[1:4]

def parse_sqlcmd_rows(path: Path) -> dict[str, int]:
    rows: dict[str, int] = {}
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line or line.startswith("Changed database"):
            continue
        if line.startswith("-") or line.lower().startswith("table_name"):
            continue
        if line.startswith("(") and "rows affected" in line:
            continue
        # table_name|31687  ou  table_name 31687
        if "|" in line:
            parts = [p.strip() for p in line.split("|")]
            if len(parts) >= 2 and parts[0] and parts[-1].replace(",", "").isdigit():
                rows[parts[0]] = int(parts[-1].replace(",", ""))
            continue
        m = re.match(r"^(\S+)\s+(\d[\d,]*)$", line)
        if m:
            rows[m.group(1)] = int(m.group(2).replace(",", ""))
    return rows

ct610 = parse_sqlcmd_rows(Path(ct610_path))
vm620 = parse_sqlcmd_rows(Path(vm620_path))
all_tables = sorted(set(ct610) | set(vm620))

with Path(csv_path).open("w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["table_name", "rows_ct610", "rows_vm620", "delta_vm620_minus_ct610", "status"])
    only_ct610 = only_vm620 = diverged = match = 0
    for t in all_tables:
        r610 = ct610.get(t)
        r620 = vm620.get(t)
        if r610 is None:
            only_vm620 += 1
            status = "only_vm620"
            delta = ""
        elif r620 is None:
            only_ct610 += 1
            status = "only_ct610"
            delta = ""
        else:
            delta = r620 - r610
            if delta == 0:
                match += 1
                status = "match"
            else:
                diverged += 1
                status = "diverged"
        w.writerow([t, r610 if r610 is not None else "", r620 if r620 is not None else "", delta, status])

print(f"CSV: {csv_path}")
print(f"Tabelas: {len(all_tables)} | match={match} diverged={diverged} only_ct610={only_ct610} only_vm620={only_vm620}")
PY

echo "Concluído: ${CSV}"
