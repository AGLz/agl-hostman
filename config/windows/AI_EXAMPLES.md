# 🎯 Exemplos Práticos - AI Model Commands

## 📚 Índice
1. [Desenvolvimento](#desenvolvimento)
2. [Debugging](#debugging)
3. [Aprendizado](#aprendizado)
4. [Documentação](#documentação)
5. [Análise de Código](#análise-de-código)
6. [Criação de Conteúdo](#criação-de-conteúdo)
7. [Comparações](#comparações)

---

## 💻 Desenvolvimento

### Criar Função Python
```powershell
cccl "Crie uma função Python que valida se um email é válido usando regex"
```

**Resposta esperada:**
```python
import re

def validar_email(email):
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(pattern, email) is not None
```

---

### Criar Componente React
```powershell
cccl "Crie um componente React de botão com TypeScript que aceita props de cor e tamanho"
```

**Resposta esperada:**
```typescript
interface ButtonProps {
  color: 'primary' | 'secondary' | 'danger';
  size: 'small' | 'medium' | 'large';
  children: React.ReactNode;
  onClick?: () => void;
}

const Button: React.FC<ButtonProps> = ({ color, size, children, onClick }) => {
  return (
    <button className={`btn btn-${color} btn-${size}`} onClick={onClick}>
      {children}
    </button>
  );
};
```

---

### Criar API Endpoint
```powershell
cccl "Crie um endpoint Express.js para login com validação de email e senha"
```

**Resposta esperada:**
```javascript
app.post('/api/login', async (req, res) => {
  const { email, password } = req.body;
  
  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password required' });
  }
  
  const user = await User.findOne({ email });
  if (!user || !(await user.comparePassword(password))) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }
  
  const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET);
  res.json({ token, user: { id: user.id, email: user.email } });
});
```

---

## 🐛 Debugging

### Analisar Erro JavaScript
```powershell
cccl "Por que este código dá erro: const arr = null; arr.map(x => x * 2)"
```

**Resposta esperada:**
```
O erro ocorre porque você está tentando chamar .map() em null.
O método .map() só existe em arrays.

Solução:
const arr = null;
const result = arr?.map(x => x * 2) ?? [];
// ou
const result = Array.isArray(arr) ? arr.map(x => x * 2) : [];
```

---

### Debugar Async/Await
```powershell
cccl "Este código não funciona, por quê? async function test() { const data = await fetch('/api'); console.log(data); }"
```

**Resposta esperada:**
```
O problema é que fetch() retorna uma Response, não os dados diretamente.
Você precisa chamar .json() ou .text() para extrair os dados.

Correto:
async function test() {
  const response = await fetch('/api');
  const data = await response.json();
  console.log(data);
}
```

---

### Analisar Performance
```powershell
cccl "Por que este código é lento? for(let i=0; i<arr.length; i++) { arr.push(i); }"
```

**Resposta esperada:**
```
O problema é que você está modificando o array enquanto itera sobre ele,
causando um loop infinito. arr.length aumenta a cada iteração.

Solução:
const length = arr.length;
for(let i=0; i<length; i++) {
  arr.push(i);
}
```

---

## 📖 Aprendizado

### Explicar Conceito
```powershell
ccz "Explique o que é closure em JavaScript com exemplos práticos"
```

**Resposta esperada:**
```
Closure é quando uma função "lembra" das variáveis do escopo onde foi criada,
mesmo depois que esse escopo terminou de executar.

Exemplo:
function criarContador() {
  let count = 0;
  return function() {
    count++;
    return count;
  };
}

const contador = criarContador();
console.log(contador()); // 1
console.log(contador()); // 2
```

---

### Comparar Tecnologias
```powershell
gemini "Qual a diferença entre REST e GraphQL? Quando usar cada um?"
```

**Resposta esperada:**
```
REST:
- Múltiplos endpoints (/users, /posts)
- Over-fetching ou under-fetching de dados
- Mais simples de implementar
- Melhor para APIs simples

GraphQL:
- Um único endpoint
- Cliente pede exatamente o que precisa
- Mais complexo de implementar
- Melhor para aplicações complexas com muitas relações
```

---

### Tutorial Passo a Passo
```powershell
gpt "Como criar um projeto React com TypeScript do zero?"
```

**Resposta esperada:**
```
1. Instalar Node.js e npm
2. Criar projeto: npx create-react-app my-app --template typescript
3. Entrar na pasta: cd my-app
4. Instalar dependências: npm install
5. Iniciar servidor: npm start
6. Abrir http://localhost:3000
```

---

## 📝 Documentação

### Criar README
```powershell
gpt "Crie um README.md para uma API REST de gerenciamento de tarefas"
```

**Resposta esperada:**
```markdown
# Task Manager API

API REST para gerenciamento de tarefas.

## Endpoints

### GET /api/tasks
Lista todas as tarefas

### POST /api/tasks
Cria uma nova tarefa

### PUT /api/tasks/:id
Atualiza uma tarefa

### DELETE /api/tasks/:id
Remove uma tarefa

## Instalação

npm install
npm start
```

---

### Documentar Função
```powershell
cccl "Documente esta função: function calcularIMC(peso, altura) { return peso / (altura * altura); }"
```

**Resposta esperada:**
```javascript
/**
 * Calcula o Índice de Massa Corporal (IMC)
 * 
 * @param {number} peso - Peso em quilogramas
 * @param {number} altura - Altura em metros
 * @returns {number} IMC calculado
 * 
 * @example
 * calcularIMC(70, 1.75) // 22.86
 */
function calcularIMC(peso, altura) {
  return peso / (altura * altura);
}
```

---

### Criar Changelog
```powershell
gpt "Crie um CHANGELOG.md para a versão 2.0.0 com as seguintes mudanças: adicionado suporte a TypeScript, removido jQuery, corrigido bug de login"
```

**Resposta esperada:**
```markdown
# Changelog

## [2.0.0] - 2025-01-24

### Added
- Suporte completo a TypeScript
- Tipagem estática em todos os componentes

### Removed
- Dependência do jQuery
- Código legado em JavaScript puro

### Fixed
- Bug que impedia login com emails longos
```

---

## 🔍 Análise de Código

### Code Review
```powershell
cccl "Analise este código e sugira melhorias: function getUserData(id) { var user = db.query('SELECT * FROM users WHERE id = ' + id); return user; }"
```

**Resposta esperada:**
```
Problemas encontrados:

1. SQL Injection: Concatenação direta de strings
2. Uso de 'var' ao invés de 'const/let'
3. Sem tratamento de erros
4. Sem validação de entrada

Código melhorado:
async function getUserData(id) {
  if (!id || typeof id !== 'number') {
    throw new Error('Invalid user ID');
  }
  
  try {
    const user = await db.query(
      'SELECT * FROM users WHERE id = ?',
      [id]
    );
    return user;
  } catch (error) {
    console.error('Error fetching user:', error);
    throw error;
  }
}
```

---

### Refatoração
```powershell
cccl "Refatore este código para usar async/await: function getData() { fetch('/api').then(res => res.json()).then(data => console.log(data)).catch(err => console.error(err)); }"
```

**Resposta esperada:**
```javascript
async function getData() {
  try {
    const response = await fetch('/api');
    const data = await response.json();
    console.log(data);
  } catch (error) {
    console.error(error);
  }
}
```

---

### Otimização
```powershell
cccl "Otimize este código: const result = []; for(let i=0; i<arr.length; i++) { if(arr[i] > 10) { result.push(arr[i] * 2); } }"
```

**Resposta esperada:**
```javascript
// Mais conciso e funcional
const result = arr
  .filter(x => x > 10)
  .map(x => x * 2);

// Ou em uma linha
const result = arr.filter(x => x > 10).map(x => x * 2);
```

---

## ✍️ Criação de Conteúdo

### Escrever Artigo
```powershell
gpt "Escreva um artigo de 200 palavras sobre as vantagens do TypeScript"
```

---

### Criar Apresentação
```powershell
gpt "Crie um outline para uma apresentação de 10 slides sobre Docker"
```

**Resposta esperada:**
```
1. Título: Docker - Containerização Moderna
2. O que é Docker?
3. Problemas que o Docker resolve
4. Conceitos básicos: Containers vs VMs
5. Arquitetura do Docker
6. Dockerfile e imagens
7. Docker Compose
8. Casos de uso práticos
9. Melhores práticas
10. Conclusão e recursos
```

---

### Gerar Dados de Teste
```powershell
cccl "Gere um array JSON com 5 usuários de teste contendo id, nome, email e idade"
```

**Resposta esperada:**
```json
[
  { "id": 1, "nome": "João Silva", "email": "joao@example.com", "idade": 28 },
  { "id": 2, "nome": "Maria Santos", "email": "maria@example.com", "idade": 34 },
  { "id": 3, "nome": "Pedro Costa", "email": "pedro@example.com", "idade": 22 },
  { "id": 4, "nome": "Ana Oliveira", "email": "ana@example.com", "idade": 41 },
  { "id": 5, "nome": "Carlos Souza", "email": "carlos@example.com", "idade": 19 }
]
```

---

## 🔄 Comparações

### Comparar Abordagens
```powershell
ai-compare "Qual a melhor forma de gerenciar estado em React: Context API ou Redux?"
```

**Resultado:**
- Claude: Análise detalhada de prós e contras
- GPT-4: Recomendações baseadas em tamanho do projeto
- Gemini: Comparação técnica com exemplos

---

### Comparar Linguagens
```powershell
ai-compare "Python ou JavaScript para backend?"
```

**Resultado:**
- Claude: Análise de performance e ecossistema
- GPT-4: Casos de uso específicos
- Gemini: Comparação de sintaxe e curva de aprendizado

---

### Comparar Frameworks
```powershell
ai-compare "Next.js ou Remix para aplicação React?"
```

**Resultado:**
- Claude: Análise de features e DX
- GPT-4: Comparação de performance
- Gemini: Casos de uso e comunidade

---

## 🎯 Casos de Uso Avançados

### Chain de Comandos
```powershell
# 1. Gerar código
cccl "Crie uma função de validação de CPF" | Out-File cpf.js

# 2. Revisar código
cccl "Revise este código: $(Get-Content cpf.js)"

# 3. Criar testes
cccl "Crie testes Jest para: $(Get-Content cpf.js)"
```

---

### Salvar Respostas
```powershell
# Salvar resposta em arquivo
ccz "Explique SOLID principles" | Out-File solid.md

# Salvar múltiplas respostas
ai-compare "Melhor banco de dados para e-commerce?" | Out-File db-comparison.txt
```

---

### Processar Arquivos
```powershell
# Analisar código existente
$code = Get-Content src/app.js -Raw
cccl "Analise este código e sugira melhorias: $code"

# Gerar documentação
$functions = Get-Content src/utils.js -Raw
cccl "Documente estas funções: $functions" | Out-File docs/utils.md
```

---

## 💡 Dicas e Truques

### 1. Use Prompts Específicos
```powershell
# ❌ Ruim
cccl "código python"

# ✅ Bom
cccl "Crie uma função Python que valida CPF com testes unitários"
```

---

### 2. Contextualize
```powershell
# ❌ Ruim
ccz "como fazer isso?"

# ✅ Bom
ccz "Como implementar autenticação JWT em Express.js com refresh tokens?"
```

---

### 3. Peça Exemplos
```powershell
# ❌ Ruim
ccz "explique promises"

# ✅ Bom
ccz "Explique JavaScript Promises com 3 exemplos práticos de uso"
```

---

### 4. Use o Modelo Certo
```powershell
# Para código
cccl "criar função"

# Para explicações
ccz "explicar conceito"

# Para criatividade
gpt "escrever artigo"

# Para pesquisa
gemini "comparar tecnologias"
```

---

### 5. Compare Quando em Dúvida
```powershell
# Não sabe qual abordagem usar?
ai-compare "Melhor forma de implementar cache em Node.js?"
```

---

## 📊 Métricas de Uso

### Monitorar Tokens
Todos os comandos mostram tokens usados:
```
=== Tokens Used: 1234 ===
```

### Estimar Custos
```powershell
# Claude: ~$0.018 por 1000 tokens
# GPT-4: ~$0.040 por 1000 tokens
# Gemini: GRÁTIS (até 60 req/min)
```

---

## 🎉 Conclusão

Agora você tem **5 comandos poderosos** para:
- ✅ Escrever código
- ✅ Debugar problemas
- ✅ Aprender conceitos
- ✅ Criar documentação
- ✅ Analisar código
- ✅ Comparar soluções

**Comece agora:**
```powershell
ccz "Olá! Como você pode me ajudar?"
```

---

**Criado**: 2025-01-24  
**Versão**: 1.0  
**Status**: ✅ Production Ready
