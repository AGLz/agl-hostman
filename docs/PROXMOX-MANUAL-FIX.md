# CT183 Emergency Fix - Proxmox Console

## 🚨 Problema

API do Proxmox em 192.168.0.245:8006 não está respondendo (Status 596).
**Solução**: Executar correção manualmente via console do Proxmox.

---

## 📋 Procedimento Passo a Passo

### Opção 1: Via Console Proxmox (RECOMENDADO)

1. **Acessar interface web do Proxmox**
   - URL: `https://192.168.0.245:8006`
   - Login: root (com senha)

2. **Localizar VM CT183**
   - Navegar para: **Node aglsrv1** → **VMs**
   - Encontrar a VM com nome contendo "ct183" ou "archon"
   - Anotar o VMID

3. **Abrir Console da VM**
   - Clicar na VM CT183
   - Clicar em **Console**
   - O console VNC/SPICE abrirá

4. **Fazer login na VM**
   ```bash
   # Se aparecer tela de login, use:
   Username: root
   Password: [senha do root]
   ```

5. **Baixar e executar script de correção**
   ```bash
   # Opção A: Se a VM tiver acesso à internet
   curl -o /tmp/fix.sh https://raw.githubusercontent.com/seu-repo/agl-hostman/main/scripts/ct183-emergency-fix.sh
   bash /tmp/fix.sh

   # Opção B: Copiar e colar o script diretamente no console
   # (Ver script completo abaixo)
   ```

### Opção 2: Via SSH (Se disponível)

```bash
# 1. SSH no CT183
ssh root@192.168.0.183

# 2. Baixar script
curl -o /tmp/fix.sh https://seu-servidor/scripts/ct183-emergency-fix.sh

# 3. Executar
bash /tmp/fix.sh
```

---

## 📜 Script Completo (Copiar e Colar)

Se a VM CT183 não tiver acesso à internet, copie e cole este script inteiro no console:

```bash
#!/bin/bash
set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  CT183 Emergency Fix - Archon + Supabase                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check Docker
echo "[*] Checking Docker..."
if ! command -v docker &> /dev/null; then
    echo "[ERROR] Docker not found"
    exit 1
fi

systemctl start docker || service docker start
sleep 3

# Find directories
SUPABASE_DIR="/root/supabase-self-hosted/supabase/docker"
ARCHON_DIR="/root/Archon"

if [[ ! -d "$SUPABASE_DIR" ]]; then
    SUPABASE_DIR=$(find /root -name "docker-compose.yml" -path "*/supabase/*" 2>/dev/null | head -1 | xargs dirname)
fi

if [[ ! -d "$ARCHON_DIR" ]]; then
    ARCHON_DIR=$(find /root -name "docker-compose.yml" -path "*/Archon/*" 2>/dev/null | head -1 | xargs dirname)
fi

echo "[✓] Supabase: $SUPABASE_DIR"
echo "[✓] Archon: $ARCHON_DIR"
echo ""

# Stop containers
echo "[*] Stopping containers..."
cd "$ARCHON_DIR" && docker compose down 2>/dev/null || true
cd "$SUPABASE_DIR" && docker compose down 2>/dev/null || true
echo "[✓] Stopped"
echo ""

# Start Supabase
echo "[*] Starting Supabase..."
cd "$SUPABASE_DIR"
docker compose up -d 2>/dev/null || docker-compose up -d

echo "[*] Waiting for Supabase (60s)..."
sleep 30
docker ps --filter "name=supabase" --format "table {{.Names}}\t{{.Status}}"
echo ""

# Start Archon
echo "[*] Starting Archon..."
cd "$ARCHON_DIR"
docker compose up -d 2>/dev/null || docker-compose up -d

echo "[*] Waiting for Archon (30s)..."
sleep 15
docker ps --filter "name=archon" --format "table {{.Names}}\t{{.Status}}"
echo ""

# Verify
echo "[*] Checking ports..."
for port in 3737 8051 8181 8000 5432; do
    if timeout 2 bash -c "echo >/dev/tcp/127.0.0.1/$port" 2>/dev/null; then
        echo "[✓] Port $port OK"
    else
        echo "[✗] Port $port FAILED"
    fi
done

echo ""
echo "[✓] Done! Check services above."
```

---

## 🔍 Verificação Manual

Se o script não funcionar, execute manualmente:

```bash
# 1. Verificar Docker
docker ps -a

# 2. Iniciar Supabase
cd /root/supabase-self-hosted/supabase/docker  # ou o diretório encontrado
docker compose up -d

# 3. Aguardar 30-60 segundos
sleep 30

# 4. Verificar Supabase
docker ps | grep supabase

# 5. Iniciar Archon
cd /root/Archon  # ou o diretório encontrado
docker compose up -d

# 6. Aguardar 15-30 segundos
sleep 15

# 7. Verificar Archon
docker ps | grep archon

# 8. Testar portas
curl http://localhost:3737/  # Archon UI
curl http://localhost:8051/mcp  # Archon MCP
curl http://localhost:8181/  # Archon API
curl http://localhost:8000/  # Supabase API
```

---

## 📊 Status Esperado Após Fix

### Containers Rodando
```bash
docker ps
```

Deve mostrar:
- **Supabase**: 13+ containers (supabase-*)
- **Archon**: 3 containers (archon-ui, archon-mcp, archon-server)

### Portas Abertas
```bash
netstat -tulpn | grep -E "3737|8051|8181|8000|5432"
```

Todas as 5 portas devem estar LISTEN.

### Acesso Externo
Do agldv03 ou outra máquina:
```bash
./scripts/ct183-diagnose.sh
```

Deve mostrar todos serviços UP.

---

## 🆘 Troubleshooting

### Problema: "docker: command not found"
```bash
# Instalar Docker
curl -fsSL https://get.docker.com | sh
systemctl start docker
```

### Problema: "Cannot find docker-compose.yml"
```bash
# Encontrar instalação
find /root -name "docker-compose.yml" | grep -E "supabase|Archon"

# Usar o diretório encontrado
cd /caminho/encontrado
```

### Problema: "Permission denied"
```bash
# Executar como root
sudo -i
# Re-executar o script
```

### Problema: Containers não iniciam
```bash
# Verificar logs
docker logs supabase-kong
docker logs archon-server

# Verificar espaço em disco
df -h

# Verificar memória
free -h

# Reiniciar Docker
systemctl restart docker
```

---

## ✅ Sucesso!

Quando tudo estiver funcionando:

```bash
✓ Supabase: 13/13 containers UP
✓ Archon: 3/3 containers UP
✓ All ports: OPEN
✓ MCP: Connected
✓ API: Responding
```

**Endpoints**:
- Archon UI: http://192.168.0.183:3737
- Archon MCP: http://192.168.0.183:8051/mcp
- Supabase API: http://192.168.0.183:8000

---

**Última atualização**: 2025-01-05
**Status**: 🔴 Aguardando execução via console Proxmox
