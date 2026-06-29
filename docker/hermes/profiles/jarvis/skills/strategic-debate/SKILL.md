---
name: strategic-debate
description: Debate estratégico Advocate vs Skeptic (no-logging) antes de delegar decisões de alto impacto
---

# strategic-debate — Debate estratégico (Jarvis)

Ferramenta **Opção B**: duas personas LLM debatem uma decisão estratégica; tu (Jarvis) sintetizas e decides o que delegar. **Sem contentores novos.**

## Quando usar (fase Plan)

- Fork estratégico (prioridade, arquitectura, investimento, go/no-go)
- Trade-offs com custo alto de erro
- **Antes** de `delegate_task` quando a decisão não é óbvia

**Não usar** para tarefas operacionais triviais ou quando os acceptance criteria já estão claros.

## Modelos (no-logging — obrigatório)

| Persona   | Modelo                 | Papel                          |
| --------- | ---------------------- | ------------------------------ |
| Advocate  | `or-qwen3-coder-free`  | Defende a direcção / oportunidade |
| Skeptic   | `or-hermes-free`       | Riscos, premissas, alternativas |
| Síntese   | `or-qwen3-next-free`   | Recomendação equilibrada       |

**Proibido** neste fluxo: `or-owl-alpha`, `or-nemotron-*`, Sonoma, Horizon (logam prompts). O script bloqueia por defeito.

## Privacidade

- Podes incluir **contexto interno** (wiki, pipeline, infra) no `--context` — os modelos são **no-logging** (`data_collection=deny`).
- O script **não** lê repos, crons nem wiki automaticamente; **tu** escolhes o que passar.

## Comando

```bash
bash /opt/data/scripts/strategic-debate.sh \
  --question "Devemos priorizar X vs Y nos próximos 90 dias?" \
  --context "Capacidades: Hermes 8 agentes, LiteLLM CT186, makemoney pipeline verde. Constraints: ..." \
  --output /opt/llm-wiki/raw/hermes/jarvis/debate-$(date +%Y%m%d-%H%M).md
```

Opções úteis:

- `--context-file /caminho/notas.md`
- `--json` — stdout estruturado
- `--dry-run` — smoke sem LiteLLM

## Fluxo recomendado (Plan → Execute)

1. Clarificar questão com o humano se necessário.
2. Correr `strategic-debate.sh` com contexto relevante do wiki/pipeline.
3. Ler a **Síntese** + secção "Decisão humana necessária".
4. Se precisar de OK humano → trazer só esses bullets (Deliver).
5. Se aprovado → `review-queue add` + `delegate_task` com acceptance criteria derivados do debate.
6. Opcional: ingest resumo no wiki (`log.md` + stub em `raw/hermes/jarvis/`).

## Referências

- `docs/HERMES-AGENCY-AGENTS.md` § Debate estratégico
- Wiki: [[Hermes — Strategic Debate (Jarvis)]]
