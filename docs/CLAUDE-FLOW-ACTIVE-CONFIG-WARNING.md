# ⚠️ CLAUDE FLOW - CONFIGURAÇÃO ATIVA COM AUTOMAÇÃO TOTAL

> **ATENÇÃO**: Esta configuração habilita automação completa de Git e execução de shell.
> **Data de Ativação**: 2025-11-01
> **Status**: 🔴 **AUTOMAÇÃO TOTAL ATIVA**

---

## 🚨 AVISOS CRÍTICOS DE SEGURANÇA

### ⚡ Recursos Ativos (ALTO RISCO)

```bash
✅ CLAUDE_FLOW_AUTO_COMMIT="true"        # ⚠️ COMMITS AUTOMÁTICOS ATIVOS
✅ CLAUDE_FLOW_AUTO_PUSH="true"          # 🔴 PUSH AUTOMÁTICO PARA REMOTE ATIVO
✅ CLAUDE_FLOW_ALLOW_SHELL_EXEC="true"   # 🔴 EXECUÇÃO DE SHELL PERMITIDA
```

### 🔴 Implicações de Segurança

#### 1. **Auto-Commit Ativo**
- ✅ **Benefício**: Não perde trabalho, histórico completo de mudanças
- ⚠️ **Risco**: Pode commitar arquivos sensíveis automaticamente
- 🛡️ **Mitigação**: Sempre use `.gitignore` para arquivos sensíveis

#### 2. **Auto-Push Ativo** (MAIOR RISCO)
- ✅ **Benefício**: Backup automático no remote, colaboração instantânea
- 🔴 **RISCO CRÍTICO**:
  - Código não revisado vai para remote automaticamente
  - Impossível "desfazer" push sem reescrever histórico
  - Pode expor credenciais/secrets se esquecido em código
- 🛡️ **Mitigação Obrigatória**:
  - Revisar `.gitignore` ANTES de trabalhar
  - Nunca commitar `.env`, `credentials.json`, `*.key`, etc.
  - Usar branch separada para desenvolvimento

#### 3. **Shell Execution Permitida** (RISCO EXTREMO)
- ✅ **Benefício**: Claude Flow pode executar comandos do sistema
- 🔴 **RISCO EXTREMO**:
  - Comandos maliciosos podem ser executados
  - Acesso total ao sistema operacional
  - Possível vazamento de dados
- 🛡️ **Mitigação**:
  - Revisar comandos sugeridos antes de aceitar
  - Monitorar logs do sistema
  - Usar apenas em ambiente controlado

---

## 📋 Checklist de Segurança Obrigatório

### Antes de Usar Esta Configuração:

- [ ] **`.gitignore` Configurado**
  ```bash
  # Verificar .gitignore
  cat .gitignore

  # Adicionar padrões sensíveis
  echo ".env" >> .gitignore
  echo "*.key" >> .gitignore
  echo "credentials.json" >> .gitignore
  echo "secrets/" >> .gitignore
  ```

- [ ] **Branch de Desenvolvimento Separada**
  ```bash
  # Nunca usar auto-push em main/master
  git checkout -b dev/auto-flow
  ```

- [ ] **Remote Configurado Corretamente**
  ```bash
  # Verificar remote
  git remote -v

  # Testar push manual primeiro
  git push
  ```

- [ ] **Backup Manual Antes de Ativar**
  ```bash
  # Fazer backup do repositório
  cp -r . ../backup-$(date +%Y%m%d)
  ```

- [ ] **Alertas Configurados**
  ```bash
  # Verificar notificações ativas
  echo $CLAUDE_FLOW_NOTIFICATIONS  # Deve ser: true
  echo $CLAUDE_FLOW_ALERT_ON_ERROR # Deve ser: true
  ```

---

## 🛡️ Proteções Ativas

### Configurações de Segurança Mantidas

```bash
✅ CLAUDE_FLOW_SECURE_MODE="true"           # Modo seguro ativo
✅ CLAUDE_FLOW_SANITIZE_LOGS="true"         # Logs sanitizados
✅ CLAUDE_FLOW_COMMIT_VERIFY="true"         # Verificação antes do push
✅ CLAUDE_FLOW_BRANCH_PROTECTION="true"     # Respeita proteção de branch
✅ CLAUDE_FLOW_BACKUP_ENABLED="true"        # Backups automáticos ativos
```

### Proteções Adicionais Recomendadas

1. **Git Hooks de Validação**
   ```bash
   # Criar pre-commit hook
   cat > .git/hooks/pre-commit << 'EOF'
   #!/bin/bash
   # Verificar se há secrets
   if git diff --cached | grep -i 'password\|secret\|api.key'; then
       echo "⚠️ AVISO: Possível secret detectado!"
       exit 1
   fi
   EOF
   chmod +x .git/hooks/pre-commit
   ```

2. **Monitoramento de Logs**
   ```bash
   # Criar alias para monitorar logs
   alias cf-logs='tail -f $CLAUDE_FLOW_LOG_DIR/claude-flow.log'
   ```

3. **Revisão Periódica**
   ```bash
   # Revisar commits do dia
   git log --since="today" --oneline

   # Revisar arquivos modificados
   git status
   ```

---

## 🔄 Como Desativar em Caso de Emergência

### Método 1: Script Rápido (RECOMENDADO)
```bash
# Desativar TUDO imediatamente
claude-flow-git disable all

# Recarregar shell
source ~/.zshrc

# Verificar
claude-flow-git status
```

### Método 2: Manual
```bash
# Editar .zshrc
nano ~/.zshrc

# Encontrar e mudar para false:
# CLAUDE_FLOW_AUTO_COMMIT="false"
# CLAUDE_FLOW_AUTO_PUSH="false"
# CLAUDE_FLOW_ALLOW_SHELL_EXEC="false"

# Recarregar
source ~/.zshrc
```

### Método 3: Temporário (Apenas Sessão Atual)
```bash
# Desativar apenas nesta sessão
export CLAUDE_FLOW_AUTO_COMMIT="false"
export CLAUDE_FLOW_AUTO_PUSH="false"
export CLAUDE_FLOW_ALLOW_SHELL_EXEC="false"
```

---

## 📊 Monitoramento Recomendado

### Comandos de Monitoramento

```bash
# 1. Verificar status atual
claude-flow-git status

# 2. Ver últimos commits
git log --oneline -10

# 3. Ver mudanças não commitadas
git status

# 4. Ver diferenças antes de commit
git diff

# 5. Monitorar backups
ls -lh $CLAUDE_FLOW_BACKUP_DIRECTORY

# 6. Verificar logs
tail -f $CLAUDE_FLOW_LOG_DIR/claude-flow.log
```

### Alertas Automáticos (Configurados)

```bash
CLAUDE_FLOW_NOTIFICATIONS="true"        # Notificações do sistema ativas
CLAUDE_FLOW_ALERT_ON_ERROR="true"       # Alertas em erros ativos
```

### Integração com Slack/Discord (Opcional)

```bash
# Para habilitar alertas no Slack:
export CLAUDE_FLOW_SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# Para habilitar alertas no Discord:
export CLAUDE_FLOW_DISCORD_WEBHOOK="https://discord.com/api/webhooks/YOUR/WEBHOOK/URL"

# Recarregar
source ~/.zshrc
```

---

## 🎯 Casos de Uso Recomendados

### ✅ SEGURO para usar com automação total:

1. **Branch de desenvolvimento pessoal**
   - Branch: `dev/seu-nome`
   - Remote: Repositório pessoal
   - Risco: Baixo (apenas você acessa)

2. **Protótipos rápidos**
   - Repositório: Projeto de teste
   - Dados: Sem informações sensíveis
   - Risco: Baixo (descartável)

3. **Documentação**
   - Arquivos: Apenas `.md`, `.txt`
   - Conteúdo: Público
   - Risco: Mínimo

### ⚠️ CUIDADO ao usar:

1. **Projetos de clientes**
   - Desativar auto-push
   - Revisar cada commit
   - Usar branch protegida

2. **Repositórios com API keys**
   - Verificar `.gitignore`
   - Usar variáveis de ambiente
   - Nunca commitar `.env`

### 🔴 NUNCA usar com:

1. **Branch `main` ou `master`**
   - Sempre usar branch de feature
   - Requer revisão manual

2. **Repositórios com credenciais**
   - Alto risco de vazamento
   - Desativar auto-push

3. **Projetos críticos em produção**
   - Requer testes manuais
   - Zero tolerância a erros

---

## 🚨 Plano de Resposta a Incidentes

### Se Commitou Algo Sensível:

1. **Pare Imediatamente**
   ```bash
   claude-flow-git disable all
   ```

2. **Verifique o Que Foi Commitado**
   ```bash
   git log -1 --stat
   git show HEAD
   ```

3. **Se Ainda Não Foi Pushed**
   ```bash
   # Desfazer último commit (mantém mudanças)
   git reset HEAD~1

   # Ou desfazer e apagar mudanças (CUIDADO!)
   git reset --hard HEAD~1
   ```

4. **Se Já Foi Pushed**
   ```bash
   # ATENÇÃO: Reescreve histórico público
   git revert HEAD
   git push

   # OU (se souber o que está fazendo)
   git push --force origin +HEAD~1:branch-name

   # DEPOIS: Avisar time sobre reescrita de histórico
   ```

5. **Rotacionar Credenciais Expostas**
   - Trocar senhas imediatamente
   - Gerar novas API keys
   - Atualizar secrets no CI/CD

---

## 📝 Log de Ativação

```yaml
Data: 2025-11-01
Hora: Atual
Usuario: admin
Host: AGLHQ11 (macOS)
Repositório: agl-hostman
Branch: develop

Configurações Ativadas:
  - AUTO_COMMIT: false → true
  - AUTO_PUSH: false → true
  - ALLOW_SHELL_EXEC: false → true

Justificativa: [PREENCHER SE NECESSÁRIO]

Aprovação: [PREENCHER SE NECESSÁRIO]
```

---

## 🔗 Referências Rápidas

| Ação | Comando |
|------|---------|
| Ver status | `claude-flow-git status` |
| Desativar tudo | `claude-flow-git disable all` |
| Habilitar só commit | `claude-flow-git enable commit` |
| Modo seguro | `cf-safe` |
| Ver últimos commits | `git log --oneline -10` |
| Desfazer último commit | `git reset HEAD~1` |

---

## ⚖️ Termo de Responsabilidade

**IMPORTANTE**: Ao usar esta configuração, você assume total responsabilidade por:

1. ✅ Manter `.gitignore` atualizado
2. ✅ Não commitar informações sensíveis
3. ✅ Monitorar commits e pushes automáticos
4. ✅ Revisar código antes que vá para produção
5. ✅ Rotacionar credenciais se exposta

**Esta configuração é adequada para ambientes de desenvolvimento controlados.**
**NÃO é recomendada para produção ou projetos críticos sem supervisão.**

---

**Última Revisão**: 2025-11-01
**Próxima Revisão Recomendada**: Semanal
**Status**: 🔴 **ATIVO - AUTOMAÇÃO TOTAL**

---

## 🎯 Ação Imediata Recomendada

```bash
# 1. Verificar configuração
claude-flow-git status

# 2. Revisar .gitignore
cat .gitignore

# 3. Ver branch atual
git branch

# 4. Confirmar remote
git remote -v

# 5. Fazer commit de teste (seguro)
echo "# Test" >> TEST.md
# (Vai commitar e pushar automaticamente)

# 6. Verificar se funcionou
git log -1
git status

# 7. Limpar teste
rm TEST.md
git add TEST.md
git commit -m "chore: remove test file"
git push
```

---

**Mantenha este documento acessível para referência rápida!**
