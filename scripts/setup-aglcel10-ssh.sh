#!/bin/bash
# Script para configurar acesso SSH ao aglcel10 (Android device via Tailscale)
# Uso: ./setup-aglcel10-ssh.sh

set -e

TAILSCALE_IP="100.80.84.69"
DEVICE_NAME="aglcel10"
SSH_PORT=8022  # Porta padrão do Termux

echo "======================================"
echo "🔧 Configuração de SSH - $DEVICE_NAME"
echo "======================================"
echo ""
echo "📱 Dispositivo Android detectado via Tailscale"
echo "🌐 IP Tailscale: $TAILSCALE_IP"
echo ""

# Verificar conectividade
echo "1️⃣ Verificando conectividade Tailscale..."
if tailscale ping $TAILSCALE_IP >/dev/null 2>&1; then
    echo "   ✅ Dispositivo acessível via Tailscale"
else
    echo "   ❌ Dispositivo não responde ao ping"
    exit 1
fi

# Verificar portas SSH
echo ""
echo "2️⃣ Verificando portas SSH..."
if command -v nmap >/dev/null 2>&1; then
    SSH_STATUS=$(nmap -p 22,2222,8022 $TAILSCALE_IP 2>/dev/null | grep -E "open|closed" || echo "")
    if echo "$SSH_STATUS" | grep -q "open"; then
        echo "   ✅ Porta SSH detectada"
        echo "$SSH_STATUS"
    else
        echo "   ❌ Nenhuma porta SSH aberta (22, 2222, 8022)"
        echo ""
        echo "📋 INSTRUÇÕES PARA CONFIGURAR SSH NO ANDROID:"
        echo ""
        echo "   Opção 1: Termux (Recomendado)"
        echo "   ──────────────────────────────────"
        echo "   1. Instalar o app Termux no Android"
        echo "   2. Abrir o Termux e executar:"
        echo "      pkg update && pkg upgrade"
        echo "      pkg install openssh"
        echo "      sshd"
        echo "   3. Definir senha:"
        echo "      passwd"
        echo "   4. Verificar usuário e IP:"
        echo "      whoami  # anotar usuário (geralmente 'u0_aXXX')"
        echo "      ip addr show wlan0"
        echo ""
        echo "   Opção 2: UserLAnd (Alternativa)"
        echo "   ───────────────────────────────"
        echo "   1. Instalar o app UserLAnd"
        echo "   2. Escolher 'Ubuntu' ou 'Arch'"
        echo "   3. Ativar o serviço SSH"
        echo ""
        exit 1
    fi
else
    echo "   ⚠️  nmap não instalado, pulando verificação de portas"
fi

echo ""
echo "3️⃣ Configurando acesso SSH..."
echo ""

# Perguntar usuário
echo "👤 Qual o usuário SSH no Android? (ex: u0_a363, root)"
read -r SSH_USER

if [ -z "$SSH_USER" ]; then
    echo "❌ Usuário não informado"
    exit 1
fi

echo ""
echo "🔑 Qual porta SSH? (padrão Termux: 8022)"
read -r SSH_PORT_INPUT
if [ -n "$SSH_PORT_INPUT" ]; then
    SSH_PORT=$SSH_PORT_INPUT
fi

# Testar conexão SSH
echo ""
echo "4️⃣ Testando conexão SSH..."
if timeout 5 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -p $SSH_PORT ${SSH_USER}@${TAILSCALE_IP} "echo 'Conexão SSH OK'" >/dev/null 2>&1; then
    echo "   ✅ Conexão SSH funcionando!"
else
    echo "   ❌ Falha na conexão SSH"
    echo "   Verifique:"
    echo "   - Servidor SSH está rodando no Android"
    echo "   - Senha/chave configurada corretamente"
    echo "   - Firewall não está bloqueando"
    exit 1
fi

# Configurar ~/.ssh/config
echo ""
echo "5️⃣ Configurando ~/.ssh/config..."
if ! grep -q "Host $DEVICE_NAME" ~/.ssh/config 2>/dev/null; then
    cat >> ~/.ssh/config <<EOF

# AGLCEL10 - Android Device via Tailscale
Host $DEVICE_NAME
    HostName $TAILSCALE_IP
    User $SSH_USER
    Port $SSH_PORT
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
    echo "   ✅ Configuração adicionada ao ~/.ssh/config"
else
    echo "   ⚠️  Configuração já existe em ~/.ssh/config"
fi

echo ""
echo "✅ Configuração concluída!"
echo ""
echo "📝 Como usar:"
echo "   ssh $DEVICE_NAME           # Conectar ao dispositivo"
echo "   scp arquivo $DEVICE_NAME:~  # Copiar arquivo"
echo ""
echo "🔧 Para copiar o .zshrc:"
echo "   scp /root/.zshrc $DEVICE_NAME:~/.zshrc"
echo ""

# Oferecer para copiar o .zshrc imediatamente
echo "📦 Deseja copiar o .zshrc agora? (s/n)"
read -r COPY_ZSHRC

if [ "$COPY_ZSHRC" = "s" ] || [ "$COPY_ZSHRC" = "S" ]; then
    echo ""
    echo "📋 Copiando .zshrc para $DEVICE_NAME..."
    scp /root/.zshrc $DEVICE_NAME:~/.zshrc
    echo "   ✅ .zshrc copiado com sucesso!"
    echo ""
    echo "💡 Para aplicar as configurações:"
    echo "   ssh $DEVICE_NAME 'source ~/.zshrc'"
    echo "   Ou reconecte ao terminal"
fi

echo ""
echo "======================================"
