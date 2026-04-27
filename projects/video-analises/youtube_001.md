# 🎬 Análise: "The Secret Poison Killing Your Claude Code Performance"
**Canal:** Chase AI  
**Data de publicação:** 14 de Janeiro de 2026  
**Duração:** 12:48  
**Link:** https://www.youtube.com/watch?v=-xHprsdG4ME  
**Visualizações:** ~6.700 | **Likes:** 230  
**Estudo referenciado:** [Chroma Context Rot Study](https://research.trychroma.com/context-rot)
---
## 📌 Resumo Executivo
O vídeo aborda o fenômeno chamado **"context rot"** (deterioração de contexto) — um problema silencioso e confirmado por múltiplos estudos científicos que faz com que a performance de qualquer LLM (Claude, GPT, Gemini) piore progressivamente **a cada mensagem enviada** numa mesma sessão. O autor explica o mecanismo por trás disso e apresenta estratégias práticas para mitigar o problema.
---
## 🧠 Conceitos Centrais
### 1. O que é Context Rot?
- **Definição:** Quanto mais você preenche a janela de contexto de um sistema de IA — ou seja, quanto mais longa a sessão — pior ele performa.
- **Não é opinião:** É comprovado por múltiplos estudos científicos, incluindo o **Estudo da Chroma** (publicado no verão de 2025).
- **Afeta todos os modelos:** Claude, GPT, Gemini — qualquer LLM sofre desse efeito.
- **Problema silencioso:** A maioria dos usuários não percebe porque a degradação é gradual.
---
## 🔢 Como Funcionam as Context Windows e Tokens
### Tokens
- **Definição prática:** 1 token ≈ 1 palavra (simplificação de 99% — a matemática real é mais complexa).
- Os tokens são a **"moeda"** dos LLMs.
- As context windows são o **"orçamento"** de cada modelo.
### Tamanhos de Context Window por Modelo
| Modelo | Context Window |
|--------|--------------|
| Claude Opus 4.5 | 200.000 tokens |
| Gemini | até 2.000.000 tokens |
| Outros | ainda maiores |
> ⚠️ **"Bigger isn't always better"** — uma janela maior não resolve o context rot.
### Como o Context Window é Preenchido (Exemplo Prático)
O autor usa uma conversa de exemplo com três elementos para rastrear:
1. **Input tokens** — tokens da mensagem enviada
2. **Output tokens** — tokens da resposta do modelo
3. **Context window total** — acumulado de tudo
**Exemplo passo a passo:**
- Você diz "Hi Claude" → 2 tokens de input
- Claude responde com algo simples → ex: 14 tokens de output
- **Context window agora = 16 tokens** (input + output)
- Na próxima mensagem, você envia 10 tokens → mas o **input real** é 10 + 16 (histórico) = **26 tokens**
- Claude responde com 100 tokens → context window passa para **116 tokens**
- Após 100 mensagens, context window pode estar em **50.000 tokens** (25% de 200k usado)
- O próximo "Pode explicar context windows de novo?" + 6 tokens de sua mensagem → input real = **50.006 tokens**
- Claude responde com 5.000 tokens → context window agora = **55.000 tokens**
**Conclusão:** Cada nova mensagem não é só o que você escreveu — é tudo que foi dito antes, acumulado.
### O que mais preenche o Context Window além das mensagens?
O autor mostra um exemplo real do **Claude Code** e lista:
- 📨 Mensagens (back-and-forth)
- ⚙️ System prompts
- 🛠️ Ferramentas (Tools)
- 🔌 **MCP Tools** — potencialmente as mais pesadas de todas
---
## ⚔️ Estratégias para Combater o Context Rot
### Arma #1 — Task Management (Gestão de Tarefas)
**Princípio:** Dar ao LLM tarefas discretas, específicas e pequenas — não vagas e amplas.
**Errado ❌:**
> "Crie um produto SaaS de gestão de projetos para criadores de conteúdo."
**Certo ✅:**
> Quebre em partes menores e menores até chegar no menor nível possível.
**Exemplo de decomposição progressiva:**
```
Quero construir um website
→ Quero construir uma landing page
→ Quero construir um formulário de contato
→ Quero construir a lógica específica que valida se o e-mail inserido é legítimo
```
**No contexto do Claude Code:**
- Ter um **PRD (Product Requirements Document)** bem definido antes de começar
- Usar o **modo plan** para fazer um back-and-forth significativo e quebrar a ideia em partes discretas
- Exemplo mencionado: PRD de um **Kanban board para criadores de vídeo** — cada coluna, cada card, cada função = tarefa separada
- Quanto menor a tarefa → menos contexto usado → melhor a performance
**Benefícios:**
- Menos tokens consumidos por tarefa
- Outputs de maior qualidade
- Menos context rot acumulado
---
### Arma #2 — Session Management (Gestão de Sessões)
**Princípio:** Não deixar uma conversa arrastar por horas sem gestão ativa.
**Para chatbots (Claude.ai, ChatGPT, etc.):**
1. Após uma longa sessão, peça ao Claude: *"Crie um resumo de tudo que conversamos"*
2. Abra uma nova janela/chat
3. Cole o resumo como contexto inicial
4. Continue de onde parou com uma janela limpa
**Para Claude Code:**
- **Autocompact feature:** Quando o context window atinge ~150.000–155.000 tokens, Claude Code automaticamente:
  1. Inicia uma nova sessão
  2. Pede ao Claude que gere um resumo do que foi feito
  3. Começa nova sessão com esse resumo como ponto de partida
- **Manualmente:** Pedir um resumo explicitamente OU usar o comando `/clear` para iniciar nova sessão
> 💡 **Apenas essas duas estratégias (task management + session management) já resolvem ~90% do problema de context rot.**
---
### Arma #3 — Frameworks de Scaffolding (Ralph Loop e GSD)
Ambos os frameworks foram construídos especificamente para resolver o context rot em projetos complexos de agentic coding.
#### Ralph Loop
- Pega o PRD + tarefas específicas
- Ataca uma tarefa por vez
- **Inicia uma nova sessão a cada tentativa**
- Resultado: Menos context rot, outputs melhores
#### GSD Framework
- Pega a ideia inicial e a transforma em PRD
- Quebra o PRD em **atomic tasks** (tarefas atômicas)
- Lança **sub-agents**, cada um com seu próprio context window limpo
- Sub-agents completam tarefas independentes com contexto fresco
**O que ambos têm em comum:**
- Gerenciam contexto via novas sessões ou sub-agents
- Dão ao AI **apenas uma tarefa específica** por sessão
- Resultado: menor context rot → outputs de maior qualidade
---
### Arma #4 — Uso Consciente de MCPs
**O problema com MCPs:**
- MCPs são extremamente pesados — consomem uma parcela enorme do context window
- No início (2024-2025), a tendência era usar 30+ MCPs ao mesmo tempo
- Anthropic publicou um artigo (4 de novembro) alertando que MCPs são bloated (inchados) e que existem melhores alternativas
**Recomendação:**
- Use MCPs com moderação
- Não ative MCPs que você não precisa na sessão atual
- Prefira Skills ou Custom Instructions para substituir MCPs quando possível
---
## 📊 Insights do Estudo Chroma
- Múltiplos estudos confirmam o mesmo padrão: performance degrada à medida que o contexto cresce
- O estudo da Chroma tem um vídeo de ~7 minutos explicando a metodologia
- Link disponível na descrição do vídeo e no site deles
---
## 🔗 Frameworks e Recursos Mencionados
| Recurso | Tipo | Descrição |
|---------|------|-----------|
| [Chroma Study](https://research.trychroma.com/context-rot) | Estudo científico | Pesquisa sobre context rot em LLMs |
| Ralph Loop | Framework/Scaffolding | Loop de tarefas com sessões frescas |
| GSD Framework | Framework/Scaffolding | Decomposição em atomic tasks + sub-agents |
| Claude Code Autocompact | Feature nativa | Compactação automática ao atingir limite |
| `/clear` command | Comando Claude Code | Inicia nova sessão manualmente |
---
## 💬 Comentários Relevantes da Comunidade
- **@PeterTrevathan:** Confirma o problema na prática — passou a usar README files como "memória externa" antes de escrever qualquer código. *"Sometimes it takes days before we write any code... but it gets it right!"*
- **@uc_sandman7882:** O vídeo o motivou a criar uma extensão que funciona como uma "barra de vida" para o chat, indicando quando é hora de abrir uma nova conversa.
- **@TheFeintOfHearts:** Ironiza: *"The thing killing my Claude Code performance is usage limits"* (6 likes).
- **@jlad4ever:** Importante correção técnica: `/clear` **não limpa o context window** — é preciso encerrar a sessão com `Ctrl+C` duas vezes para realmente limpar.
- **@CraigHollabaugh:** Perguntou como salvar progresso antes do `/clear` — a resposta implícita é: pedir o resumo ao Claude primeiro.
---
## ✅ Checklist de Boas Práticas
- [x] Quebrar projetos grandes em tarefas mínimas antes de começar
- [x] Criar um PRD detalhado no modo plan antes de codificar
- [x] Monitorar uso do context window durante a sessão
- [x] Pedir resumo ao Claude antes de abrir nova sessão
- [x] Usar autocompact do Claude Code ou `/clear` + restart para sessões longas
- [x] Usar MCPs apenas quando necessário e desativá-los quando não precisar
- [x] Considerar adotar Ralph Loop ou GSD para projetos complexos

---

## 🚀 APLICAÇÃO NO PROJETO AGL (2026-02-18)

### Status: IMPLEMENTADO

**Arquivos Criados/Atualizados**:
| Arquivo | Ação | Descrição |
|---------|------|-----------|
| `docs/RULES.md` | Atualizado | v2.0.0 - Adicionado Context Rot Mitigation, Session Management, MCP Conscious Usage, PRD Requirements |
| `.claude/skills/context-rot-mitigation/SKILL.md` | Criado | Skill completo com as 4 armas contra context rot |
| `projects/video-analises/CONTEXT_ROT_APPLICATION_PLAN.md` | Criado | Plano de implementação detalhado |

### Melhorias Implementadas

1. **Session Management** - Diretrizes claras para reset de sessão
2. **MCP Consciousness** - Limite de 3-4 MCPs por sessão
3. **PRD Requirements** - Obrigatório antes de qualquer codificação
4. **Atomic Task Decomposition** - Checklist e padrões de decomposição
5. **Skill Registry** - Skill `context-rot-mitigation` disponível globalmente

### Gap Analysis Final

| Prática | Status | Localização |
|---------|--------|-------------|
| Modular Documentation | ✅ Já existia | CLAUDE.md |
| Mandatory Subagents | ✅ Já existia | RULES.md |
| Session Management | ✅ **NOVO** | RULES.md:170-220 |
| MCP Consciousness | ✅ **NOVO** | RULES.md:222-280 |
| PRD Requirements | ✅ **NOVO** | RULES.md:282-340 |
| Context Rot Awareness | ✅ **NOVO** | RULES.md:105-170 |
| Skill Disponível | ✅ **NOVO** | `.claude/skills/context-rot-mitigation/` |
---
## 📝 Metadados do Vídeo
- **Título:** The Secret Poison Killing Your Claude Code Performance
- **Canal:** Chase AI (44.6k inscritos)
- **Tags:** #ai #claudecode #coding
- **Capítulos:**
  - `0:00` — O Assassino Secreto (The Secret Killer)
  - `1:46` — Janelas de Contexto e Tokens (Context Windows & Tokens)
  - `7:44` — Combatendo a Degradação de Contexto (Fighting Context Rot)
  - `12:34` — Considerações Finais (Final Thoughts)