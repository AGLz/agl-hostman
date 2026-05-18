#!/bin/bash
# Benchmark Comparativo: SMB vs NFS vs SSHFS
# Data: 2025-10-21
# Servidor: aglfs1 (192.168.0.178)
# Objetivo: Comparar performance dos 3 protocolos de acesso remoto

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuracao
TEST_SIZE_MB=500
LOG_FILE="/tmp/protocol-benchmark-$(date +%Y%m%d-%H%M%S).log"
RESULTS_FILE="/root/agl-hostman/docs/test-reports/benchmark-protocols-$(date +%Y%m%d-%H%M%S).md"

# Criar diretorio de reports se nao existir
mkdir -p /root/agl-hostman/docs/test-reports

# Arrays para armazenar resultados
declare -A WRITE_SPEEDS
declare -A READ_SPEEDS

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}BENCHMARK COMPARATIVO DE PROTOCOLOS${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "${YELLOW}Data:${NC} $(date)"
echo -e "${YELLOW}Teste:${NC} ${TEST_SIZE_MB}MB por operação"
echo -e "${YELLOW}Protocolos:${NC} SMB, NFS, SSHFS"
echo -e "${YELLOW}Log:${NC} $LOG_FILE"
echo -e "${YELLOW}Relatório:${NC} $RESULTS_FILE"
echo ""

# Inicializar log
{
    echo "========================================="
    echo "BENCHMARK COMPARATIVO DE PROTOCOLOS"
    echo "========================================="
    echo "Data: $(date)"
    echo "Tamanho de teste: ${TEST_SIZE_MB}MB"
    echo ""
} > "$LOG_FILE"

# Funcao para extrair velocidade do dd
extract_speed() {
    local output="$1"
    # Tentar pegar MB/s direto
    local speed=$(echo "$output" | grep -oP '\d+(\.\d+)?\s+MB/s' | grep -oP '\d+(\.\d+)?')

    if [ -z "$speed" ]; then
        # Calcular manualmente
        local bytes=$(echo "$output" | grep -oP '\d+\s+bytes' | head -1 | grep -oP '\d+')
        local seconds=$(echo "$output" | grep -oP '\d+\.\d+\s+s' | head -1 | grep -oP '\d+\.\d+')

        if [ -n "$bytes" ] && [ -n "$seconds" ]; then
            speed=$(echo "scale=2; ($bytes / 1024 / 1024) / $seconds" | bc)
        else
            speed="0"
        fi
    fi

    echo "$speed"
}

# Funcao principal de benchmark
run_benchmark() {
    local protocol=$1
    local mount_point=$2
    local test_name=$3
    local color=$4

    echo -e "${color}========================================${NC}"
    echo -e "${color}TESTE: $test_name ($protocol)${NC}"
    echo -e "${color}========================================${NC}"
    echo ""

    # Verificar se mount existe
    if [ ! -d "$mount_point" ]; then
        echo -e "${RED}ERRO: $mount_point não existe ou não está montado${NC}"
        echo "$test_name - ERRO: Mount point não existe" >> "$LOG_FILE"
        WRITE_SPEEDS[$protocol]="N/A"
        READ_SPEEDS[$protocol]="N/A"
        echo ""
        return 1
    fi

    # Verificar acesso
    if ! ls "$mount_point" >/dev/null 2>&1; then
        echo -e "${RED}ERRO: Sem acesso a $mount_point${NC}"
        echo "$test_name - ERRO: Sem acesso" >> "$LOG_FILE"
        WRITE_SPEEDS[$protocol]="N/A"
        READ_SPEEDS[$protocol]="N/A"
        echo ""
        return 1
    fi

    # Teste de ESCRITA
    echo -e "${YELLOW}[1/2] Testando ESCRITA de ${TEST_SIZE_MB}MB...${NC}"
    local write_file="$mount_point/benchmark-write-$$.tmp"

    local write_output=$(dd if=/dev/zero of="$write_file" bs=1M count=$TEST_SIZE_MB conv=fdatasync 2>&1)
    local write_exit=$?

    # Limpar arquivo
    rm -f "$write_file" 2>/dev/null

    if [ $write_exit -eq 0 ]; then
        local write_speed=$(extract_speed "$write_output")
        echo -e "${GREEN}      Escrita: ${write_speed} MB/s${NC}"
        echo "$test_name - Escrita: ${write_speed} MB/s" >> "$LOG_FILE"
        WRITE_SPEEDS[$protocol]="$write_speed"
    else
        echo -e "${RED}      ERRO na escrita${NC}"
        echo "$test_name - Escrita: ERRO" >> "$LOG_FILE"
        WRITE_SPEEDS[$protocol]="ERRO"
    fi

    # Teste de LEITURA
    echo -e "${YELLOW}[2/2] Testando LEITURA...${NC}"

    # Procurar arquivo grande existente
    local read_file=$(find "$mount_point" -maxdepth 2 -type f -size +100M 2>/dev/null | head -1)

    if [ -z "$read_file" ]; then
        echo -e "${YELLOW}      Criando arquivo de teste para leitura...${NC}"
        read_file="$mount_point/benchmark-read-$$.tmp"
        dd if=/dev/zero of="$read_file" bs=1M count=$TEST_SIZE_MB 2>/dev/null
        local created_read_file=1
    fi

    # Limpar cache
    sync
    sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches' 2>/dev/null || true
    sleep 1

    # Executar leitura
    local read_output=$(dd if="$read_file" of=/dev/null bs=1M 2>&1)
    local read_exit=$?

    # Limpar arquivo se foi criado
    if [ -n "$created_read_file" ]; then
        rm -f "$read_file" 2>/dev/null
    fi

    if [ $read_exit -eq 0 ]; then
        local read_speed=$(extract_speed "$read_output")
        echo -e "${GREEN}      Leitura: ${read_speed} MB/s${NC}"
        echo "$test_name - Leitura: ${read_speed} MB/s" >> "$LOG_FILE"
        READ_SPEEDS[$protocol]="$read_speed"
    else
        echo -e "${RED}      ERRO na leitura${NC}"
        echo "$test_name - Leitura: ERRO" >> "$LOG_FILE"
        READ_SPEEDS[$protocol]="ERRO"
    fi

    echo ""
}

# ===========================================
# TESTES PROTOCOLOS
# ===========================================

# 1. SMB (via /mnt/r e /mnt/s - acesso Windows)
echo -e "${CYAN}>>> PROTOCOLO 1: SMB (via Windows mount)${NC}"
echo ""

if [ -d "/mnt/r" ] && [ "$(ls -A /mnt/r 2>/dev/null)" ]; then
    run_benchmark "SMB-R" "/mnt/r" "SMB - Overpower (R:)" "$BLUE"
else
    echo -e "${YELLOW}AVISO: /mnt/r (SMB Overpower) não disponível${NC}"
    echo ""
fi

if [ -d "/mnt/s" ] && [ "$(ls -A /mnt/s 2>/dev/null)" ]; then
    run_benchmark "SMB-S" "/mnt/s" "SMB - Power/Spark (S:)" "$BLUE"
else
    echo -e "${YELLOW}AVISO: /mnt/s (SMB Spark) não disponível${NC}"
    echo ""
fi

# 2. NFS (via /mnt/y e /mnt/z - se montados)
echo -e "${CYAN}>>> PROTOCOLO 2: NFS (mounts diretos WSL)${NC}"
echo ""

if mountpoint -q /mnt/y 2>/dev/null; then
    run_benchmark "NFS-Y" "/mnt/y" "NFS - Power/Spark (Y:)" "$MAGENTA"
elif [ -d "/mnt/y" ] && [ "$(ls -A /mnt/y 2>/dev/null)" ]; then
    run_benchmark "NFS-Y" "/mnt/y" "NFS - Power/Spark (Y:)" "$MAGENTA"
else
    echo -e "${YELLOW}AVISO: /mnt/y (NFS Spark) não disponível${NC}"
    echo "  Para ativar: wsl --shutdown (reiniciar WSL)"
    echo ""
fi

if mountpoint -q /mnt/z 2>/dev/null; then
    run_benchmark "NFS-Z" "/mnt/z" "NFS - Overpower (Z:)" "$MAGENTA"
elif [ -d "/mnt/z" ] && [ "$(ls -A /mnt/z 2>/dev/null)" ]; then
    run_benchmark "NFS-Z" "/mnt/z" "NFS - Overpower (Z:)" "$MAGENTA"
else
    echo -e "${YELLOW}AVISO: /mnt/z (NFS Overpower) não disponível${NC}"
    echo "  Para ativar: wsl --shutdown (reiniciar WSL)"
    echo ""
fi

# 3. SSHFS (mounts diretos WSL)
echo -e "${CYAN}>>> PROTOCOLO 3: SSHFS (mounts nativos WSL)${NC}"
echo ""

if mountpoint -q /mnt/nfs-overpower-base 2>/dev/null; then
    run_benchmark "SSHFS-OVP" "/mnt/nfs-overpower-base" "SSHFS - Overpower" "$GREEN"
else
    echo -e "${YELLOW}AVISO: /mnt/nfs-overpower-base (SSHFS) não montado${NC}"
    echo "  Para ativar: /usr/local/bin/wsl-mount-nfs-shares.sh"
    echo ""
fi

if mountpoint -q /mnt/nfs-spark-base 2>/dev/null; then
    run_benchmark "SSHFS-SPARK" "/mnt/nfs-spark-base" "SSHFS - Spark" "$GREEN"
elif mountpoint -q /mnt/spark-sshfs 2>/dev/null; then
    run_benchmark "SSHFS-SPARK" "/mnt/spark-sshfs" "SSHFS - Spark" "$GREEN"
else
    echo -e "${YELLOW}AVISO: /mnt/nfs-spark-base ou /mnt/spark-sshfs não montado${NC}"
    echo "  Para ativar: /usr/local/bin/wsl-mount-nfs-shares.sh"
    echo ""
fi

# ===========================================
# GERAR RELATORIO
# ===========================================

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}GERANDO RELATÓRIO${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Criar relatório markdown
cat > "$RESULTS_FILE" << 'EOFMD'
# Benchmark Comparativo de Protocolos
**Data**: $(date +%Y-%m-%d)
**Servidor**: aglfs1 (192.168.0.178)
**Cliente**: WSL2 no Windows 11
**Tamanho de teste**: $(echo $TEST_SIZE_MB)MB por operação

---

## 📊 Resultados

### Tabela Comparativa

| Protocolo | Mount Point | Escrita (MB/s) | Leitura (MB/s) | Média (MB/s) |
|-----------|-------------|----------------|----------------|--------------|
EOFMD

# Preencher tabela com resultados
for protocol in "${!WRITE_SPEEDS[@]}"; do
    write="${WRITE_SPEEDS[$protocol]}"
    read="${READ_SPEEDS[$protocol]}"

    # Calcular média (se ambos numéricos)
    if [[ "$write" =~ ^[0-9]+\.?[0-9]*$ ]] && [[ "$read" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        avg=$(echo "scale=2; ($write + $read) / 2" | bc)
    else
        avg="N/A"
    fi

    # Determinar mount point
    case $protocol in
        SMB-R) mount="/mnt/r (R:)" ;;
        SMB-S) mount="/mnt/s (S:)" ;;
        NFS-Y) mount="/mnt/y (Y:)" ;;
        NFS-Z) mount="/mnt/z (Z:)" ;;
        SSHFS-OVP) mount="/mnt/nfs-overpower-base" ;;
        SSHFS-SPARK) mount="/mnt/spark-sshfs" ;;
        *) mount="N/A" ;;
    esac

    echo "| $protocol | $mount | $write | $read | $avg |" >> "$RESULTS_FILE"
done

# Adicionar análise
cat >> "$RESULTS_FILE" << 'EOFMD'

---

## 🎯 Análise de Performance

### Vencedores por Categoria

**Escrita Mais Rápida**:
EOFMD

# Encontrar melhor escrita
best_write_speed=0
best_write_protocol=""
for protocol in "${!WRITE_SPEEDS[@]}"; do
    speed="${WRITE_SPEEDS[$protocol]}"
    if [[ "$speed" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        if (( $(echo "$speed > $best_write_speed" | bc -l) )); then
            best_write_speed="$speed"
            best_write_protocol="$protocol"
        fi
    fi
done

if [ -n "$best_write_protocol" ]; then
    echo "- **$best_write_protocol**: ${best_write_speed} MB/s" >> "$RESULTS_FILE"
fi

echo "" >> "$RESULTS_FILE"
echo "**Leitura Mais Rápida**:" >> "$RESULTS_FILE"

# Encontrar melhor leitura
best_read_speed=0
best_read_protocol=""
for protocol in "${!READ_SPEEDS[@]}"; do
    speed="${READ_SPEEDS[$protocol]}"
    if [[ "$speed" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        if (( $(echo "$speed > $best_read_speed" | bc -l) )); then
            best_read_speed="$speed"
            best_read_protocol="$protocol"
        fi
    fi
done

if [ -n "$best_read_protocol" ]; then
    echo "- **$best_read_protocol**: ${best_read_speed} MB/s" >> "$RESULTS_FILE"
fi

# Continuar relatório
cat >> "$RESULTS_FILE" << 'EOFMD'

### Comparação por Protocolo

#### SMB (Windows → WSL)
- **Vantagens**: Integração nativa Windows + WSL, persistência automática, status correto no Explorer
- **Desvantagens**: Passa por camada Windows DrvFs
- **Uso recomendado**: Acesso geral de arquivos via WSL em máquinas Windows

#### NFS (Windows NFS Client → WSL)
- **Vantagens**: Performance nativa NFS, protocolo otimizado para UNIX
- **Desvantagens**: Problemas de estabilidade no WSL, status "Disconnected" no Explorer, não visível nativamente no WSL
- **Uso recomendado**: Apenas se NFS for requisito específico (não recomendado para WSL)

#### SSHFS (WSL → Servidor)
- **Vantagens**: Independente do Windows, auto-reconnect, criptografia SSH, estável no WSL
- **Desvantagens**: ~20-30% mais lento que protocolos nativos
- **Uso recomendado**: Quando WSL precisa acesso direto sem depender do Windows

---

## 📋 Recomendações

### Para Uso Geral no WSL
EOFMD

# Determinar recomendação baseada em performance
if [ -n "$best_write_protocol" ]; then
    if [[ "$best_write_protocol" == SMB-* ]]; then
        cat >> "$RESULTS_FILE" << 'EOFMD'
**SMB** apresentou melhor performance. Recomenda-se:
1. Manter drives SMB (R:, S:, T:, U:)
2. Se Y: e Z: estiverem em NFS, migrar para SMB
3. Acessar via `/mnt/r`, `/mnt/s`, etc no WSL
EOFMD
    elif [[ "$best_write_protocol" == NFS-* ]]; then
        cat >> "$RESULTS_FILE" << 'EOFMD'
**NFS** apresentou melhor performance, MAS:
- Problemas de estabilidade conhecidos no WSL
- Serviço NfsClnt trava ao reiniciar
- Não recomendado apesar da performance
EOFMD
    elif [[ "$best_write_protocol" == SSHFS-* ]]; then
        cat >> "$RESULTS_FILE" << 'EOFMD'
**SSHFS** apresentou melhor performance nativa do WSL. Recomenda-se:
1. Usar SSHFS para acesso direto do WSL
2. Independente de configurações Windows
3. Auto-reconnect em caso de problemas de rede
EOFMD
    fi
fi

cat >> "$RESULTS_FILE" << 'EOFMD'

### Para Casos Específicos

**Cenário 1: Máximo desempenho**
- Usar o protocolo com melhor média geral
- Considerar trade-offs de estabilidade

**Cenário 2: Máxima estabilidade**
- SMB (integração Windows) ou SSHFS (nativo WSL)
- Evitar NFS devido a problemas conhecidos

**Cenário 3: Independência do Windows**
- SSHFS direto do WSL
- Não depende de configurações Windows

---

## 🔧 Como Executar Este Teste

```bash
# No WSL
/root/agl-hostman/scripts/benchmark-all-protocols.sh
```

**Pré-requisitos**:
- Pelo menos um protocolo configurado (SMB, NFS ou SSHFS)
- Espaço suficiente nos mounts (mínimo $(echo $TEST_SIZE_MB)MB)
- Permissões de escrita nos mount points

---

**Relatório gerado em**: $(date)
**Script**: benchmark-all-protocols.sh
EOFMD

echo -e "${GREEN}Relatório salvo em: $RESULTS_FILE${NC}"
echo -e "${GREEN}Log detalhado em: $LOG_FILE${NC}"

# ===========================================
# EXIBIR RESUMO NA TELA
# ===========================================

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}RESUMO COMPARATIVO${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

printf "${YELLOW}%-15s${NC} | ${YELLOW}%-15s${NC} | ${YELLOW}%-15s${NC}\n" "Protocolo" "Escrita (MB/s)" "Leitura (MB/s)"
echo "----------------+----------------+----------------"

for protocol in $(echo "${!WRITE_SPEEDS[@]}" | tr ' ' '\n' | sort); do
    write="${WRITE_SPEEDS[$protocol]}"
    read="${READ_SPEEDS[$protocol]}"

    # Colorir baseado em performance
    if [[ "$write" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        if (( $(echo "$write > 150" | bc -l) )); then
            write_color="$GREEN"
        elif (( $(echo "$write > 75" | bc -l) )); then
            write_color="$YELLOW"
        else
            write_color="$RED"
        fi
    else
        write_color="$RED"
    fi

    if [[ "$read" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        if (( $(echo "$read > 150" | bc -l) )); then
            read_color="$GREEN"
        elif (( $(echo "$read > 75" | bc -l) )); then
            read_color="$YELLOW"
        else
            read_color="$RED"
        fi
    else
        read_color="$RED"
    fi

    printf "%-15s | ${write_color}%-15s${NC} | ${read_color}%-15s${NC}\n" "$protocol" "$write" "$read"
done

echo ""
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "${GREEN}✓ Benchmark completo!${NC}"
echo -e "${GREEN}✓ Relatório detalhado: $RESULTS_FILE${NC}"
echo ""
