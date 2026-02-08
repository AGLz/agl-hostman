# 🚀 AI Model Commands - Quick Start

## ✅ Comandos Implementados

Agora você tem acesso direto a **3 modelos de IA** via linha de comando!

### 📦 Comandos Disponíveis

```powershell
ccz "seu prompt aqui"        # Claude 3.5 Sonnet (conversação)
cccl "seu prompt aqui"       # Claude Code (programação)
gpt "seu prompt aqui"        # GPT-4 Turbo (OpenAI)
gemini "seu prompt aqui"     # Gemini Pro (Google)
ai-compare "seu prompt"      # Compara todos os modelos
```

---

## 🎯 Exemplos Rápidos

### Claude (Anthropic)
```powershell
# Conversação geral
ccz "Explique o que é recursão"

# Código e programação
cccl "Crie uma função Python para validar email"
```

### GPT-4 (OpenAI)
```powershell
# Criatividade e análise
gpt "Escreva um README para meu projeto"
```

### Gemini (Google)
```powershell
# Pesquisa e educação
gemini "Explique a diferença entre TCP e UDP"
```

### Comparação
```powershell
# Compare respostas de todos os modelos
ai-compare "Qual a melhor forma de aprender programação?"
```

---

## ⚙️ Configuração Rápida

### 1. Instalar o Perfil

```powershell
Copy-Item config\windows\Microsoft.PowerShell_profile.ps1 $PROFILE -Force
. $PROFILE
```

### 2. Configurar API Keys

```powershell
notepad $PROFILE
```

Substitua os placeholders:
```powershell
$env:ANTHROPIC_API_KEY = "sk-ant-api03-..."  # Sua chave Anthropic
$env:OPENAI_API_KEY = "sk-proj-..."          # Sua chave OpenAI
$env:GOOGLE_API_KEY = "AIza..."              # Sua chave Google
```

### 3. Verificar

```powershell
cf-check
```

Você deve ver:
```
=== API Keys Status ===
Anthropic: [OK] Configured
OpenAI: [OK] Configured
Gemini: [OK] Configured

=== AI Model Commands ===
ccz 'prompt'        - Call Claude (Anthropic)
cccl 'prompt'       - Call Claude Code (Anthropic)
gpt 'prompt'        - Call GPT-4 (OpenAI)
gemini 'prompt'     - Call Gemini Pro (Google)
ai-compare 'prompt' - Compare all models
```

---

## 🔑 Obter API Keys

### Anthropic Claude
1. Acesse: https://console.anthropic.com/
2. Crie uma conta
3. Vá em **Settings → API Keys**
4. Clique em **Create Key**
5. Copie a chave (começa com `sk-ant-api03-`)

### OpenAI GPT-4
1. Acesse: https://platform.openai.com/
2. Crie uma conta
3. Vá em **API Keys**
4. Clique em **Create new secret key**
5. Copie a chave (começa com `sk-proj-`)

### Google Gemini
1. Acesse: https://makersuite.google.com/app/apikey
2. Faça login com sua conta Google
3. Clique em **Create API Key**
4. Copie a chave (começa com `AIza`)

---

## 💡 Casos de Uso

### Desenvolvimento
```powershell
# Debugar código
cccl "Por que este código dá erro: const x = [1,2,3]; x.map()"

# Refatorar
cccl "Refatore este código para usar async/await"

# Criar função
cccl "Crie uma função TypeScript para validar CPF"
```

### Aprendizado
```powershell
# Explicações
ccz "Explique o padrão Observer com exemplos"

# Comparar conceitos
gemini "Diferença entre REST e GraphQL"

# Tutoriais
gpt "Como começar com Docker?"
```

### Produtividade
```powershell
# Documentação
gpt "Crie documentação para esta API"

# Análise
ccz "Analise os prós e contras desta arquitetura"

# Decisões
ai-compare "Devo usar MongoDB ou PostgreSQL?"
```

---

## 📊 Características dos Modelos

| Modelo | Melhor Para | Max Tokens | Custo |
|--------|-------------|------------|-------|
| **Claude** | Conversação, análise | 4096 | $0.018/1K |
| **Claude Code** | Programação, debug | 8192 | $0.018/1K |
| **GPT-4** | Criatividade, planejamento | 4096 | $0.040/1K |
| **Gemini** | Pesquisa, educação | Auto | **GRÁTIS** |

**Dica:** Use Gemini para testes e desenvolvimento!

---

## 🔒 Segurança

### ✅ Boas Práticas

- ✅ Mantenha suas API keys **privadas**
- ✅ Não commite o perfil com chaves reais
- ✅ Revogue chaves comprometidas imediatamente
- ✅ Monitore uso de tokens
- ✅ Use `.gitignore` para arquivos de configuração

### ❌ Nunca Faça

- ❌ Compartilhe suas API keys
- ❌ Commite chaves no Git
- ❌ Use chaves em código público
- ❌ Exponha chaves em logs

---

## 📚 Documentação Completa

Para documentação detalhada, veja:
- **[AI_COMMANDS.md](./AI_COMMANDS.md)** - Guia completo dos comandos
- **[README.md](./README.md)** - Documentação do perfil PowerShell
- **[QUICK_START.md](./QUICK_START.md)** - Guia de instalação rápida

---

## 🐛 Troubleshooting

### Comando não encontrado
```powershell
# Recarregue o perfil
. $PROFILE
```

### API Key não configurada
```powershell
# Verifique a configuração
cf-check

# Edite o perfil
notepad $PROFILE
```

### Erro 401 Unauthorized
```powershell
# Chave inválida - gere uma nova no console do provedor
```

### Erro 429 Rate Limit
```powershell
# Aguarde alguns segundos e tente novamente
```

---

## 🎉 Pronto para Usar!

Agora você tem acesso a **3 modelos de IA** diretamente do PowerShell:

```powershell
# Teste agora!
ccz "Olá! Como você pode me ajudar?"
```

---

**Criado**: 2025-01-24  
**Versão**: 1.0  
**Status**: ✅ Production Ready
