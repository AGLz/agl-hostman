#!/usr/bin/env python3
"""ADW: Good Morning — sync EvoNexus + briefing com contexto canónico da DB."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "custom"))

from evonexus_ops import build_operational_snapshot, load_dotenv, sync_all_agent_docs  # noqa: E402
from runner import banner, run_claude, summary  # noqa: E402


def main() -> None:
    banner("☀️  Good Morning", "EvoNexus + agenda | @clawdia")

    sync = sync_all_agent_docs()
    print(sync.get("summary", sync))
    snapshot = build_operational_snapshot()

    prompt = f"""Execute the skill /prod-good-morning in full.

## EvoNexus — estado operacional (fonte canónica, já sincronizado em ai-docs/tasks/TASKS.md)

{snapshot}

## Regras adicionais AGLz

1. Para **tarefas e prioridades do dia**, use `ai-docs/tasks/TASKS.md` e o snapshot acima.
2. Se Todoist/calendário/Gmail **não** estiverem configurados, **não** diga apenas que "sistemas não estão configurados" — entregue briefing com dados EvoNexus (tickets, metas, goal_tasks).
3. Responda em **pt-BR**. Recomendação final: uma frase clara com base nos tickets/metas mais urgentes.
4. Após concluir **todos** os passos da skill, envie **uma** notificação Telegram (reply) conforme instrução abaixo.
"""
    chat_id = os.environ.get("TELEGRAM_CHAT_ID") or load_dotenv().get("TELEGRAM_CHAT_ID", "")
    if chat_id:
        prompt += (
            f"\n\n---\n"
            f"NOTIFICAÇÃO TELEGRAM — executar SOMENTE após concluir TODOS os passos acima.\n"
            f"Use a ferramenta Telegram reply com chat_id={chat_id} e um texto compacto:\n"
            f"  emoji + Good Morning + data + principais resultados em 2-3 linhas.\n"
            f"REGRA ABSOLUTA: chame a ferramenta reply UMA ÚNICA VEZ, no final de tudo.\n"
            f"---"
        )

    results = [
        run_claude(
            prompt,
            log_name="good-morning",
            timeout=600,
            agent="clawdia-assistant",
        )
    ]
    summary(results, "Good Morning")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n⚠ Cancelado.")
