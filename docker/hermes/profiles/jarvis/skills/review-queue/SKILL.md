---
name: review-queue
description: Registar e acompanhar tasks delegadas (modelo Verdent To Review)
---

# Review-Queue — obrigatório em cada delegação

Sempre que **delegares** (`delegate_task`) ou planificares trabalho:

1. **Antes de delegar:**  
   `bash /opt/agl-hostman/scripts/proxmox/hermes-review-queue.sh add <id-curto> <agente> "<objetivo>" "<critério1;critério2>"`

2. **Após iniciar execução:**  
   `set-status <id> in_progress`

3. **Quando o agente terminar:**  
   `set-status <id> to_review` → delega ao **Verifier** com os mesmos acceptance criteria.

4. **Após veredito Verifier:**  
   `verdict <id> PASS|FAIL "<evidência>"` ou Jarvis fecha com `set-status done`.

5. **Stand-up / acompanhamento:**  
   `bash /opt/agl-hostman/scripts/proxmox/hermes-review-queue.sh list`

Path: `/opt/llm-wiki/raw/hermes/review-queue/queue.json`
