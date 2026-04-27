#!/bin/bash
#
# API Performance Benchmark Script
# ================================
#
# Benchmarks critical API endpoints using Apache Bench (ab)
# Compares PHP 7.4 (API1) vs PHP 8.1 (API8) performance
#
# Requirements:
#   - Apache Bench (ab): apt-get install apache2-utils
#   - JWT token for authenticated endpoints
#
# Usage:
#   ./api-benchmark.sh [endpoint] [requests] [concurrency]
#
# Examples:
#   ./api-benchmark.sh all          # Benchmark all endpoints
#   ./api-benchmark.sh recibo       # Benchmark receipt endpoint
#   ./api-benchmark.sh custom /api/health 100 10
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
API_URL="${API_URL:-https://api.falg.com.br}"
API_STAGING_URL="${API_STAGING_URL:-https://api.falg.com.br:8081}"
AUTH_TOKEN="${AUTH_TOKEN:-}"

# Default parameters
REQUESTS=${2:-100}
CONCURRENCY=${3:-10}

# Benchmark results directory
RESULTS_DIR="benchmark-results"
mkdir -p $RESULTS_DIR
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Print banner
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   API Performance Benchmark Suite     ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check for ab
if ! command -v ab &> /dev/null; then
    echo -e "${RED}Apache Bench (ab) not found.${NC}"
    echo "Install with: apt-get install apache2-utils"
    exit 1
fi

# Function to run benchmark
run_benchmark() {
    local name=$1
    local url=$2
    local method=${3:-GET}
    local data=${4:-}

    echo -e "${YELLOW}Benchmarking: $name${NC}"
    echo "URL: $url"
    echo "Requests: $REQUESTS, Concurrency: $CONCURRENCY"
    echo ""

    local output_file="$RESULTS_DIR/${name}_${TIMESTAMP}.txt"
    local headers="-H 'Authorization: Bearer $AUTH_TOKEN' -H 'Accept: application/json'"

    if [ "$method" = "POST" ] && [ -n "$data" ]; then
        headers="$headers -H 'Content-Type: application/json' -p data"
        echo "$data" > /tmp/post_data.json
        ab -n $REQUESTS -c $CONCURRENCY -p /tmp/post_data.json -T 'application/json' \
           -H "Authorization: Bearer $AUTH_TOKEN" \
           -H "Accept: application/json" \
           "$url" > "$output_file" 2>&1
    else
        ab -n $REQUESTS -c $CONCURRENCY \
           -H "Authorization: Bearer $AUTH_TOKEN" \
           -H "Accept: application/json" \
           "$url" > "$output_file" 2>&1
    fi

    # Extract key metrics
    local rps=$(grep "Requests per second" "$output_file" | awk '{print $4}')
    local mean=$(grep "Time per request" "$output_file" | head -1 | awk '{print $4}')
    local p95=$(grep "95%" "$output_file" | awk '{print $2}')

    echo -e "${GREEN}Results:${NC}"
    echo "  Requests/sec: $rps"
    echo "  Mean time: ${mean}ms"
    echo "  95th percentile: ${p95}ms"
    echo "  Full report: $output_file"
    echo ""

    # Check against thresholds
    if [ -n "$p95" ]; then
        local p95_int=${p95%.*}
        if [ "$p95_int" -gt 500 ]; then
            echo -e "${RED}[!] WARNING: p95 exceeds 500ms threshold${NC}"
        elif [ "$p95_int" -gt 200 ]; then
            echo -e "${YELLOW}[!] p95 above 200ms target${NC}"
        else
            echo -e "${GREEN}[✓] p95 within acceptable range${NC}"
        fi
    fi
    echo ""
}

# Function to compare PHP versions
compare_versions() {
    local endpoint=$1

    echo -e "${BLUE}Comparing PHP 7.4 vs PHP 8.1 for: $endpoint${NC}"
    echo ""

    echo -e "${YELLOW}=== PHP 7.4 (Production) ===${NC}"
    run_benchmark "php74_${endpoint}" "$API_URL$endpoint"

    echo -e "${YELLOW}=== PHP 8.1 (Staging) ===${NC}"
    run_benchmark "php81_${endpoint}" "$API_STAGING_URL$endpoint"
}

# Main logic
ENDPOINT=${1:-all}

case $ENDPOINT in
    all)
        echo -e "${BLUE}Running all benchmarks...${NC}"
        echo ""

        # Public endpoints
        run_benchmark "health" "$API_URL/api/health"

        if [ -n "$AUTH_TOKEN" ]; then
            # Authenticated endpoints
            run_benchmark "cobrancas_list" "$API_URL/api/cobrancas"
            run_benchmark "recibos_list" "$API_URL/api/recibos"

            # Critical single resource endpoints
            run_benchmark "recibo_single" "$API_URL/api/recibo/1"
            run_benchmark "boleto_single" "$API_URL/api/boletoitau/1"
        else
            echo -e "${YELLOW}[!] No AUTH_TOKEN set. Skipping authenticated endpoints.${NC}"
            echo "Set with: export AUTH_TOKEN=your_token"
        fi
        ;;

    compare)
        if [ -z "$AUTH_TOKEN" ]; then
            echo -e "${RED}AUTH_TOKEN required for comparison benchmarks${NC}"
            exit 1
        fi

        compare_versions "/api/cobrancas"
        compare_versions "/api/recibo/1"
        ;;

    health)
        run_benchmark "health" "$API_URL/api/health"
        ;;

    cobrancas)
        run_benchmark "cobrancas_list" "$API_URL/api/cobrancas"
        ;;

    recibos)
        run_benchmark "recibos_list" "$API_URL/api/recibos"
        ;;

    recibo)
        run_benchmark "recibo_single" "$API_URL/api/recibo/1"
        ;;

    boleto)
        run_benchmark "boleto_single" "$API_URL/api/boletoitau/1"
        ;;

    payment)
        run_benchmark "payment" "$API_URL/api/cobrancas/pagto/1" "POST" '{"valor":100.00}'
        ;;

    custom)
        if [ -z "$2" ]; then
            echo -e "${RED}Usage: $0 custom <endpoint> [requests] [concurrency]${NC}"
            exit 1
        fi
        run_benchmark "custom" "$API_URL$2"
        ;;

    stress)
        echo -e "${RED}Running STRESS TEST with high load...${NC}"
        REQUESTS=1000
        CONCURRENCY=50
        run_benchmark "stress_cobrancas" "$API_URL/api/cobrancas"
        ;;

    *)
        echo -e "${RED}Unknown benchmark: $ENDPOINT${NC}"
        echo ""
        echo "Available benchmarks:"
        echo "  all         - Run all benchmarks"
        echo "  compare     - Compare PHP 7.4 vs PHP 8.1"
        echo "  health      - Health check endpoint"
        echo "  cobrancas   - Charges list endpoint"
        echo "  recibos     - Receipts list endpoint"
        echo "  recibo      - Single receipt endpoint"
        echo "  boleto      - Single boleto endpoint"
        echo "  payment     - Payment processing endpoint"
        echo "  stress      - High load stress test"
        echo "  custom      - Custom endpoint"
        exit 1
        ;;
esac

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Benchmark Complete!                 ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Results saved to: $RESULTS_DIR/"
ls -la $RESULTS_DIR/*${TIMESTAMP}*.txt 2>/dev/null || true
