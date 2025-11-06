# 🎯 Portainer - Guia Rápido para Adicionar Agents Manualmente

**Status Atual**: 3/7 agents já conectados
**Faltam**: 5 agents (CT180, CT181, CT183, CT200, CT202)

---

## ✅ Agents Já Conectados

| ID | Nome | IP | Status |
|----|------|----|--------|
| 10 | agldv03 | 192.168.0.179 | ✓ UP |
| 11 | aglwk51 | 192.168.0.166 | ✗ DOWN (desconhecido) |
| 12 | gms1 | 192.168.0.161 | ✓ UP (gameserver) |

---

## 🚀 Adicionar os 5 Agents Faltantes

### **Acesse o Portainer**
```
URL: https://portainer.aglz.io
Usuário: admin
Senha: lx4936@klfap
```

### **Passo a Passo (Para Cada Agent)**

1. **No menu lateral esquerdo**, clique em **"Environments"**

2. Clique no botão azul **"+ Add environment"** (canto superior direito)

3. Selecione:
   - **Docker Standalone**
   - Método de conexão: **Agent**

4. Preencha os campos:
   - **Name**: (use os nomes abaixo)
   - **Environment address**: (use os IPs:porta abaixo)
   - **Public IP**: (deixe em branco ou repita o IP)

5. **Marque a opção**: ☑ Skip TLS Verification (importante!)

6. Clique em **"Add environment"**

---

## 📋 Agents para Adicionar (Copie e Cole)

### **1. agldv04 (CT181)**
```
Name: agldv04
Environment address: 192.168.0.181:9001
Public IP: (deixe em branco)
☑ Skip TLS Verification
```

### **2. dokploy (CT180)**
```
Name: dokploy
Environment address: 192.168.0.180:9001
Public IP: (deixe em branco)
☑ Skip TLS Verification
```

### **3. archon (CT183)**
```
Name: archon
Environment address: 192.168.0.183:9001
Public IP: (deixe em branco)
☑ Skip TLS Verification
```

### **4. n8n (CT202)**
```
Name: n8n
Environment address: 192.168.0.202:9001
Public IP: (deixe em branco)
☑ Skip TLS Verification
```

### **5. ollama2 (CT200)**
```
Name: ollama2
Environment address: 192.168.0.200:9001
Public IP: (deixe em branco)
☑ Skip TLS Verification
```

---

## ✅ Verificação

Após adicionar cada agent:

1. **Status Verde** = Conectado com sucesso ✓
2. **Status Vermelho** = Erro de conexão (verifique IP/porta)

### **Testar Conectividade (Opcional)**

Se algum agent não conectar:

```bash
# SSH para AGLSRV1
ssh root@192.168.0.245

# Verificar se agent está rodando
pct exec <CT_ID> -- docker ps | grep portainer

# Exemplo para CT181:
pct exec 181 -- docker ps | grep portainer
pct exec 181 -- docker logs portainer_agent --tail 10

# Testar conectividade
curl -k https://192.168.0.181:9001
```

---

## 🎯 Resultado Esperado

Após adicionar todos os 5 agents, você terá:

| Nome | Container | IP:Porta | Status Esperado |
|------|-----------|----------|-----------------|
| agldv03 | CT179 | 192.168.0.179:9001 | ✓ Já conectado |
| aglwk51 | CT166 | 192.168.0.166:9001 | ✓ Já conectado |
| gms1 | CT161 | 192.168.0.161:9001 | ✓ Já conectado |
| **agldv04** | **CT181** | **192.168.0.181:9001** | 🆕 **Adicionar** |
| **dokploy** | **CT180** | **192.168.0.180:9001** | 🆕 **Adicionar** |
| **archon** | **CT183** | **192.168.0.183:9001** | 🆕 **Adicionar** |
| **n8n** | **CT202** | **192.168.0.202:9001** | 🆕 **Adicionar** |
| **ollama2** | **CT200** | **192.168.0.200:9001** | 🆕 **Adicionar** |

**Total**: 8 environments (incluindo o Portainer local)

---

## 🔧 Troubleshooting

### **Erro: "Unable to connect"**

**Solução**:
1. Verifique se o agent está rodando:
   ```bash
   ssh root@192.168.0.245
   pct exec <CT_ID> -- docker ps | grep portainer
   ```

2. Verifique os logs:
   ```bash
   pct exec <CT_ID> -- docker logs portainer_agent --tail 20
   ```

3. Reinicie o agent se necessário:
   ```bash
   pct exec <CT_ID> -- docker restart portainer_agent
   ```

### **Erro: "TLS verification failed"**

**Solução**: Certifique-se de marcar ☑ **Skip TLS Verification**

---

## ⏱️ Tempo Estimado

- **Por agent**: ~2 minutos
- **Total (5 agents)**: ~10 minutos

---

## 📝 Checklist Final

Após terminar, verifique:

- [ ] agldv04 (CT181) - Status verde
- [ ] dokploy (CT180) - Status verde
- [ ] archon (CT183) - Status verde
- [ ] n8n (CT202) - Status verde
- [ ] ollama2 (CT200) - Status verde
- [ ] Todos os containers visíveis no dashboard
- [ ] Consegue start/stop containers via UI

---

## 🎉 Pronto!

Com todos os agents conectados, você poderá:

✅ Gerenciar todos os containers de um único lugar
✅ Ver logs de qualquer container
✅ Start/Stop/Restart containers remotamente
✅ Criar novos containers em qualquer host
✅ Monitorar recursos (CPU, RAM, Network)

---

**Última Atualização**: 2025-11-05 22:45 UTC
**Status**: Todos os 7 agents prontos, aguardando conexão via Web UI

**Tempo total para setup completo**: < 15 minutos 🚀
