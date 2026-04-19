#!/bin/bash
# Benchmark Completo SMB - aglfs1
# Data: 2025-10-21
# Compara performance de R: (overpower) e S: (power) via SMB

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuracao
R_MOUNT="/mnt/r"  # overpower via SMB
S_MOUNT="/mnt/s"  # power (spark) via SMB
TEST_SIZE_MB=500
LOG_FILE="/tmp/smb-benchmark-$(date +%Y%m%d-%H%M%S).log"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}BENCHMARK SMB - AGLFS1${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "${YELLOW}Data:${NC} $(date)"
echo -e "${YELLOW}Teste:${NC} $TEST_SIZE_MB MB por operação"
echo -e "${YELLOW}Log:${NC} $LOG_FILE"
echo ""

# Funcao para formatar velocidade
format_speed() {
    local bytes_per_sec=$1
    local mb_per_sec=$(echo "scale=2; $bytes_per_sec / 1024 / 1024" | bc)
    echo "$mb_per_sec MB/s"
}

# Funcao para realizar teste
run_test() {
    local mount_point=$1
    local test_name=$2
    local operation=$3  # read ou write

    echo -e "${CYAN}=== $test_name ===${NC}"

    # Verificar se mount existe
    if [ ! -d "$mount_point" ]; then
        echo -e "${RED}ERRO: $mount_point nao existe${NC}"
        return 1
    fi

    # Verificar se tem espaco (apenas para escrita)
    if [ "$operation" == "write" ]; then
        local free_space=$(df "$mount_point" | tail -1 | awk '{print $4}')
        local needed_space=$((TEST_SIZE_MB * 1024))

        if [ "$free_space" -lt "$needed_space" ]; then
            echo -e "${RED}ERRO: Espaco insuficiente (precisa ${TEST_SIZE_MB}MB, tem ${free_space}KB)${NC}"
            return 1
        fi
    fi

    if [ "$operation" == "write" ]; then
        # Teste de ESCRITA
        echo -e "${YELLOW}Testando escrita de ${TEST_SIZE_MB}MB...${NC}"
        local test_file="$mount_point/benchmark-test-$$.tmp"

        # Executar dd e capturar output
        local dd_output=$(dd if=/dev/zero of="$test_file" bs=1M count=$TEST_SIZE_MB conv=fdatasync 2>&1)
        local exit_code=$?

        # Limpar arquivo de teste
        rm -f "$test_file" 2>/dev/null

        if [ $exit_code -eq 0 ]; then
            # Extrair velocidade
            local speed=$(echo "$dd_output" | grep -oP '\d+(\.\d+)? MB/s' | tail -1)
            if [ -z "$speed" ]; then
                # Tentar calcular manualmente
                local bytes=$(echo "$dd_output" | grep -oP '\d+ bytes' | grep -oP '\d+')
                local seconds=$(echo "$dd_output" | grep -oP '\d+\.\d+ s' | grep -oP '\d+\.\d+')
                if [ -n "$bytes" ] && [ -n "$seconds" ]; then
                    speed=$(format_speed $(echo "scale=2; $bytes / $seconds" | bc))
                else
                    speed="N/A"
                fi
            fi

            echo -e "${GREEN}Escrita: $speed${NC}"
            echo "$test_name - Escrita: $speed" >> "$LOG_FILE"
        else
            echo -e "${RED}ERRO na escrita${NC}"
            echo "$test_name - Escrita: ERRO" >> "$LOG_FILE"
        fi

    elif [ "$operation" == "read" ]; then
        # Teste de LEITURA
        echo -e "${YELLOW}Testando leitura...${NC}"

        # Procurar arquivo grande para teste
        local test_file=$(find "$mount_point" -type f -size +100M 2>/dev/null | head -1)

        if [ -z "$test_file" ]; then
            echo -e "${YELLOW}Criando arquivo de teste para leitura...${NC}"
            test_file="$mount_point/benchmark-read-test-$$.tmp"
            dd if=/dev/zero of="$test_file" bs=1M count=$TEST_SIZE_MB conv=fdatasync 2>/dev/null
            local created_file=1
        fi

        # Limpar cache
        sync
        echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true

        # Executar leitura
        local dd_output=$(dd if="$test_file" of=/dev/null bs=1M 2>&1)
        local exit_code=$?

        # Limpar arquivo se foi criado
        if [ -n "$created_file" ]; then
            rm -f "$test_file" 2>/dev/null
        fi

        if [ $exit_code -eq 0 ]; then
            # Extrair velocidade
            local speed=$(echo "$dd_output" | grep -oP '\d+(\.\d+)? MB/s' | tail -1)
            if [ -z "$speed" ]; then
                # Tentar calcular manualmente
                local bytes=$(echo "$dd_output" | grep -oP '\d+ bytes' | grep -oP '\d+')
                local seconds=$(echo "$dd_output" | grep -oP '\d+\.\d+ s' | grep -oP '\d+\.\d+')
                if [ -n "$bytes" ] && [ -n "$seconds" ]; then
                    speed=$(format_speed $(echo "scale=2; $bytes / $seconds" | bc))
                else
                    speed="N/A"
                fi
            fi

            echo -e "${GREEN}Leitura: $speed${NC}"
            echo "$test_name - Leitura: $speed" >> "$LOG_FILE"
        else
            echo -e "${RED}ERRO na leitura${NC}"
            echo "$test_name - Leitura: ERRO" >> "$LOG_FILE"
        fi
    fi

    echo ""
}

# Inicio dos testes
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}TESTE 1: R: (OVERPOWER - SMB)${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

run_test "$R_MOUNT" "R: (overpower) SMB" "write"
run_test "$R_MOUNT" "R: (overpower) SMB" "read"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}TESTE 2: S: (POWER/SPARK - SMB)${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

run_test "$S_MOUNT" "S: (power) SMB" "write"
run_test "$S_MOUNT" "S: (power) SMB" "read"

# Comparacao com SSHFS (se disponivel)
if mountpoint -q /mnt/spark-sshfs 2>/dev/null; then
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}TESTE 3: SSHFS (COMPARACAO)${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""

    run_test "/mnt/spark-sshfs" "SSHFS (power)" "write"
    run_test "/mnt/spark-sshfs" "SSHFS (power)" "read"
fi

# Resumo final
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}RESUMO DOS TESTES${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

cat "$LOG_FILE"

echo ""
echo -e "${GREEN}Log completo salvo em: $LOG_FILE${NC}"
echo -e "${CYAN}========================================${NC}"
