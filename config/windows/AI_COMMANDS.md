# 🤖 AI Model Commands - Quick Reference

## 📋 Comandos Disponíveis

### Claude (Anthropic)

#### `ccz` - Claude Chat
Chama o modelo Claude 3.5 Sonnet para conversação geral.

```powershell
ccz "Explique o que é recursão em programação"
ccz "Qual a diferença entre let e const em JavaScript?"
ccz "Como funciona o protocolo HTTP?"
```

**Características:**
- Modelo: `claude-3-5-sonnet-20241022`
- Max Tokens: 4096
- Melhor para: Conversação, explicações, análises

#### `cccl` - Claude Code
Chama o Claude otimizado para programação com contexto de código.

```powershell
cccl "Crie uma função Python para ordenar uma lista"
cccl "Refatore este código para usar async/await"
cccl "Explique este algoritmo de busca binária"
```

**Características:**
- Modelo: `claude-3-5-sonnet-20241022`
- Max Tokens: 8192
- System Prompt: Expert programmer
- Melhor para: Código, debugging, refatoração

---

### GPT-4 (OpenAI)

#### `gpt` - GPT-4 Turbo
Chama o modelo GPT-4 Turbo da OpenAI.

```powershell
gpt "Escreva um poema sobre programação"
gpt "Crie um plano de estudos para aprender Python"
gpt "Analise este código e sugira melhorias"
```

**Características:**
- Modelo: `gpt-4-turbo-preview`
- Max Tokens: 4096
- Temperature: 0.7
- Melhor para: Criatividade, análise, planejamento

---

### Gemini (Google)

#### `gemini` - Gemini Pro
Chama o modelo Gemini Pro do Google.

```powershell
gemini "Explique machine learning para iniciantes"
gemini "Quais são as melhores práticas de segurança web?"
gemini "Como otimizar performance de banco de dados?"
```

**Características:**
- Modelo: `gemini-pro`
- Safety Ratings: Ativado
- Melhor para: Explicações técnicas, pesquisa, educação

---

### Comparação de Modelos

#### `ai-compare` - Comparar Todos os Modelos
Envia o mesmo prompt para todos os modelos e compara as respostas.

```powershell
ai-compare "Qual a melhor forma de aprender programação?"
ai-compare "Explique o conceito de closure em JavaScript"
ai-compare "Como implementar autenticação JWT?"
```

**Características:**
- Executa sequencialmente: Claude → GPT-4 → Gemini
- Mostra tokens usados por cada modelo
- Útil para comparar qualidade e estilo de respostas

---

## 🔧 Configuração

### 1. Configurar API Keys

Edite o perfil PowerShell:

```powershell
notepad $PROFILE
```

Substitua os placeholders pelas suas chaves reais:

```powershell
$env:ANTHROPIC_API_KEY = "sk-ant-api03-..."
$env:OPENAI_API_KEY = "sk-proj-..."
$env:GOOGLE_API_KEY = "AIza..."
```

### 2. Verificar Configuração

```powershell
cf-check
```

Saída esperada:
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

## 📊 Exemplos de Uso

### Exemplo 1: Debugging de Código

```powershell
# Claude Code é melhor para análise de código
cccl "Analise este erro: TypeError: Cannot read property 'map' of undefined"
```

### Exemplo 2: Criação de Conteúdo

```powershell
# GPT-4 é melhor para criatividade
gpt "Escreva um README.md para um projeto de API REST"
```

### Exemplo 3: Pesquisa Técnica

```powershell
# Gemini é bom para explicações técnicas
gemini "Explique a diferença entre TCP e UDP"
```

### Exemplo 4: Comparação de Soluções

```powershell
# Compare as respostas de todos os modelos
ai-compare "Qual a melhor forma de implementar cache em uma API?"
```

---

## 🎯 Casos de Uso por Modelo

### Use `ccz` (Claude) quando:
- ✅ Precisar de conversação natural
- ✅ Análise de texto longo
- ✅ Raciocínio complexo
- ✅ Seguir instruções detalhadas

### Use `cccl` (Claude Code) quando:
- ✅ Escrever código
- ✅ Debugar problemas
- ✅ Refatorar código existente
- ✅ Explicar algoritmos

### Use `gpt` (GPT-4) quando:
- ✅ Criar conteúdo criativo
- ✅ Brainstorming de ideias
- ✅ Planejamento de projetos
- ✅ Análise de dados

### Use `gemini` (Gemini Pro) quando:
- ✅ Pesquisa técnica
- ✅ Explicações educacionais
- ✅ Análise de segurança
- ✅ Documentação técnica

### Use `ai-compare` quando:
- ✅ Não souber qual modelo usar
- ✅ Quiser múltiplas perspectivas
- ✅ Comparar qualidade de respostas
- ✅ Validar informações

---

## 🔒 Segurança

### Boas Práticas:

1. **Nunca compartilhe suas API keys**
   ```powershell
   # ❌ ERRADO - Não commite o perfil com chaves reais
   git add $PROFILE
   
   # ✅ CORRETO - Mantenha as chaves locais
   ```

2. **Use variáveis de ambiente**
   ```powershell
   # As chaves ficam em $env:ANTHROPIC_API_KEY
   # Não são expostas em comandos ou logs
   ```

3. **Monitore uso de tokens**
   ```powershell
   # Cada comando mostra tokens usados
   # === Tokens Used: 1234 ===
   ```

4. **Revogue chaves comprometidas**
   - Anthropic: https://console.anthropic.com/settings/keys
   - OpenAI: https://platform.openai.com/api-keys
   - Google: https://makersuite.google.com/app/apikey

---

## 💰 Custos Estimados

### Anthropic Claude
- Entrada: $3.00 / 1M tokens
- Saída: $15.00 / 1M tokens
- Exemplo: 1000 tokens = $0.018

### OpenAI GPT-4 Turbo
- Entrada: $10.00 / 1M tokens
- Saída: $30.00 / 1M tokens
- Exemplo: 1000 tokens = $0.040

### Google Gemini Pro
- **GRÁTIS** até 60 requisições/minuto
- Entrada: $0.50 / 1M tokens (após limite)
- Saída: $1.50 / 1M tokens (após limite)

**Dica:** Use `gemini` para testes e desenvolvimento!

---

## 🐛 Troubleshooting

### Erro: "API Key not configured"

```powershell
# Verifique se a chave está configurada
cf-check

# Edite o perfil e configure a chave
notepad $PROFILE

# Recarregue o perfil
. $PROFILE
```

### Erro: "401 Unauthorized"

```powershell
# Chave inválida ou expirada
# Gere uma nova chave no console do provedor
```

### Erro: "429 Too Many Requests"

```powershell
# Rate limit excedido
# Aguarde alguns segundos e tente novamente
```

### Erro: "Network error"

```powershell
# Verifique sua conexão com a internet
# Verifique se o firewall não está bloqueando
Test-NetConnection api.anthropic.com -Port 443
Test-NetConnection api.openai.com -Port 443
```

---

## 📚 Recursos Adicionais

### Documentação Oficial:
- **Anthropic Claude**: https://docs.anthropic.com/
- **OpenAI GPT-4**: https://platform.openai.com/docs
- **Google Gemini**: https://ai.google.dev/docs

### Obter API Keys:
- **Anthropic**: https://console.anthropic.com/
- **OpenAI**: https://platform.openai.com/api-keys
- **Google**: https://makersuite.google.com/app/apikey

### Limites e Preços:
- **Anthropic**: https://docs.anthropic.com/claude/reference/rate-limits
- **OpenAI**: https://platform.openai.com/docs/guides/rate-limits
- **Google**: https://ai.google.dev/pricing

---

## 🎉 Exemplos Práticos

### 1. Criar uma função Python

```powershell
cccl "Crie uma função Python que valida CPF"
```

### 2. Explicar um conceito

```powershell
ccz "Explique o padrão de design Singleton com exemplos"
```

### 3. Gerar documentação

```powershell
gpt "Crie documentação API para um endpoint de login"
```

### 4. Pesquisar tecnologia

```powershell
gemini "Quais são as vantagens do Docker sobre VMs?"
```

### 5. Comparar abordagens

```powershell
ai-compare "Qual a melhor forma de implementar autenticação: JWT ou Sessions?"
```

---

## 📝 Notas

- Todos os comandos suportam prompts com múltiplas palavras
- Use aspas para prompts com espaços: `ccz "meu prompt aqui"`
- Os comandos mostram tokens usados para monitorar custos
- Respostas longas podem ser truncadas pelo terminal
- Use `| Out-File response.txt` para salvar respostas longas

---

**Criado**: 2025-01-24  
**Versão**: 1.0  
**Baseado em**: agldv03 (CT179) .zshrc configuration  
**Status**: ✅ Production Ready
