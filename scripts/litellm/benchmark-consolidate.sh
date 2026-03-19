#!/usr/bin/env bash
# =============================================================================
# Benchmark consolidado — executa em todos os hosts e gera tabela comparativa
# Uso: ./scripts/litellm/benchmark-consolidate.sh [--free] [output_dir]
# Saída: docs/litellm-benchmark/benchmark-YYYYMMDD-HHMMSS.md e .csv
# Tempo estimado: ~5-10 min (4 hosts × N modelos × ~30s/modelo)
# =============================================================================
set -euo pipefail

declare -A HOSTS
HOSTS[agldv03]="100.94.221.87"
HOSTS[agldv04]="100.113.9.98"
HOSTS[agldv12]="100.71.217.115"
HOSTS[fgsrv06]="100.83.51.9"

MODELS_FULL="glm-flash glm deepseek claude-haiku gemini-2.0 qwen-turbo qwen-plus glm-air qwen3.5-plus"
MODELS_FREE="glm-flash glm-air qwen-turbo qwen-plus qwen3.5-plus"

[[ "${1:-}" == "--free" ]] && { MODELS="$MODELS_FREE"; shift; } || MODELS="$MODELS_FULL"
OUTPUT_DIR="${1:-}"
[[ -n "$OUTPUT_DIR" ]] || OUTPUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/docs/litellm-benchmark"
mkdir -p "$OUTPUT_DIR"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
CSV_FILE="$OUTPUT_DIR/benchmark-$TIMESTAMP.csv"
MD_FILE="$OUTPUT_DIR/benchmark-$TIMESTAMP.md"

declare -A RESULTS

echo "=== Benchmark consolidado — coletando dados ==="
echo "Modelos: $MODELS"
echo ""

# Uma SSH por host, todos os modelos em paralelo no remote (mais rápido)
for host in agldv03 agldv04 agldv12 fgsrv06; do
  ip="${HOSTS[$host]}"
  echo "  Coletando $host ($ip)..."

  raw=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "root@${ip}" bash -s -- $MODELS <<'REMOTE'
    KEY=$(grep "^LITELLM_MASTER_KEY=" /opt/litellm/.env 2>/dev/null | cut -d= -f2-)
    KEY="${KEY:-sk-litellm-default}"
    for m in "$@"; do
      p="{\"model\":\"$m\",\"messages\":[{\"role\":\"user\",\"content\":\"Responda apenas: OK\"}],\"max_tokens\":10}"
      start=$(date +%s%3N)
      code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 45 -X POST http://localhost:4000/chat/completions \
        -H "Content-Type: application/json" -H "Authorization: Bearer $KEY" -d "$p" 2>/dev/null)
      end=$(date +%s%3N)
      elapsed=$((end - start))
      [[ "$code" == "200" ]] && echo "$m $elapsed" || echo "$m FAIL:$code"
    done
REMOTE
  ) 2>/dev/null || raw=""

  while read -r line; do
    [[ -z "$line" ]] && continue
    m="${line%% *}"
    v="${line#* }"
    RESULTS["${host}:${m}"]="$v"
  done <<< "$raw"
done

echo ""
echo "=== Gerando relatório consolidado ==="

# CSV
echo "model,agldv03,agldv04,agldv12,fgsrv06" > "$CSV_FILE"

# Markdown
{
  echo "# Benchmark LiteLLM — Comparativo Multi-Host"
  echo ""
  echo "**Data:** $(date -Iseconds)"
  echo "**Modelos:** $MODELS"
  echo ""
  echo "| Modelo | agldv03 | agldv04 | agldv12 | fgsrv06 |"
  echo "|--------|---------|---------|---------|--------|"
} > "$MD_FILE"

for m in $MODELS; do
  row=" $m "
  csv_row="$m"
  for host in agldv03 agldv04 agldv12 fgsrv06; do
    v="${RESULTS["${host}:${m}"]:--}"
    if [[ "$v" =~ ^[0-9]+$ ]]; then
      cell=" ${v}ms "
    else
      cell=" $v "
    fi
    row="${row}|${cell}"
    csv_row="$csv_row,$v"
  done
  echo "|${row}|" >> "$MD_FILE"
  echo "$csv_row" >> "$CSV_FILE"
done

{
  echo ""
  echo "---"
  echo ""
  echo "**Legenda:** valores em ms (menor = mais rápido). FAIL = HTTP error. - = não coletado."
  echo ""
  echo "**Arquivos:** \`$MD_FILE\` | \`$CSV_FILE\`"
} >> "$MD_FILE"

cat "$MD_FILE"
echo ""
echo "Salvo: $MD_FILE | $CSV_FILE"
