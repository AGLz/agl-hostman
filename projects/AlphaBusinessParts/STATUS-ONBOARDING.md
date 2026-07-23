# Status Onboarding — Alpha Business Parts

**Cliente:** José Abdalla · Alpha Business Parts  
**Fornecedor:** B&M Smart TECH  
**Parceiro técnico (dev + IA):** AGLz  
**Atualizado:** 2026-07-23

Checklist operacional vivo (semana 1+). Sem secrets/API tokens neste ficheiro.

---

## Resumo

| Frente | Estado | Notas |
|--------|--------|-------|
| DNS Cloudflare | Concluído | Site/origin ainda Locaweb |
| Google Workspace | Em curso | Falta validação Google + 5 mailboxes |
| iMac 15,1 → Windows 10 | Concluído | OneDrive configurado e validado |
| Dell Precision T7500 | Em curso | Upgrade RAM; cooler a cotar |
| Servidor Dell 2× Xeon | Pendente | Ainda não ligado |
| SAAS / tooling | Parcial | Lovable token em falta |
| VPS GCP | Não iniciado | Fase 1 — GCE + Dokploy (não Proxmox nested) |
| **Código-fonte CI** | **Pendente** | **Bloqueia Discovery / plano de migração** |
| **Base de dados** | **Pendente** | **Bloqueia Discovery / plano de migração** |
| Pagamento implantação | Em curso | 10× R$ 1.500/quarta · 1/10 paga (22/07) · total R$ 15.000 |
| Migração Laravel | Aguardando Discovery | Detalhe pós acesso código+DB |

---

## 1. Cloudflare DNS

- [x] Migração DNS Locaweb → Cloudflare
- [x] Site responde via Cloudflare (`server: cloudflare`)
- [ ] Origin deixou de ser Locaweb (cutover app → GCP)
- [ ] Preferência: Cloudflare Tunnel ou Full (Strict) + Origin CA

**Caixas MX atuais (público):** ainda Locaweb (`mx*.locaweb.com.br`).

---

## 2. Google Workspace (`@alphabusinessparts.com.br`)

- [x] Contratação Workspace (cartão do cliente)
- [ ] Validação / ativação do domínio na Google
- [ ] Criação das 5 mailboxes:
  - [ ] `diretoria@`
  - [ ] `financeiro@`
  - [ ] `vendas@`
  - [ ] `contato@`
  - [ ] `admin@`
- [ ] Cutover MX (apontar para Google) **após** caixas criadas
- [ ] SPF / DKIM / DMARC
- [ ] Migração IMAP do histórico Locaweb (se aplicável)
- [ ] Inventário de remetentes transacionais (site, alertas, etc.)

Runbook: [[Google Workspace — migrar e-mail sem mover o site]]

---

## 3. iMac 15,1 — Windows 10

- [x] Instalação Windows 10
- [x] Validação OK
- [x] OneDrive configurado
- [x] Pastas/ficheiros validados (restore via OneDrive)

---

### Servidores Dell — cobrança à parte (fora do pacote digital)

- [ ] Orçamento / proposta hardware dedicada (aprovação do cliente)
- Ver secções T7500 e 2.º Dell abaixo — **não** entram nos R$ 15.000 da implantação

---

## 4. Dell Precision T7500

- [x] Equipamento em mãos / em manutenção
- [ ] Remover 6× 2 GB DDR3
- [ ] Instalar 4× 16 GB DDR3 ECC RDIMM (stock) — preferir kit homogéneo 2Rx4
- [ ] POST: confirmar 64 GB e velocidade ≤1333
- [ ] Cotar cooler frontal OEM: **WN845 / T133N / U859H** (faixa ~R$ 250–600)
- [ ] Substituir cooler após peça chegar
- [ ] Stress térmico curto pós-cooler
- [ ] Faturar labor + peças (**à parte**)

Detalhe técnico: `RESEARCH-ALPHABUSINESSPARTS.md` §4.

---

## 5. Servidor Dell (2× Xeon · 3× SAS 600 GB · 10× 8 GB ECC)

- [ ] Local físico + circuito elétrico / UPS
- [ ] Inspeção visual (CPU heatsinks, cabos SAS, PSU)
- [ ] 1.º power-on isolado
- [ ] BIOS: CPU, memória (~80 GB), serial discos
- [ ] Identificar controlador RAID / HBA
- [ ] Decisão de array (documentar antes de Clear Foreign)
- [ ] Firmware BIOS / storage
- [ ] Diagnóstico Dell + SMART
- [ ] Definir uso (lab / backup / futuro Proxmox bare metal?)
- [ ] Faturar labor + peças (**à parte**)

---

## 6. Contratações SAAS (cartão do cliente)

| Serviço | Contrato | API Token / acesso |
|---------|----------|--------------------|
| Google Workspace | Sim | Admin OK |
| Cloudflare Pro | Sim | Token OK |
| Claude Code Pro | Sim | Token OK |
| Cursor Pro | Sim | Token OK |
| Codex Code Pro | Sim | Token OK |
| Lovable Pro | Sim | **Token em falta** |

> Tokens ficam apenas em gestão de secrets B&M / cliente — **não** versionar neste repo.  
> **GCP:** billing na conta do cliente — B&M só faz setup/ops.

---

## 7. Infra cloud app (próximo)

- [ ] Projeto GCP na **conta/billing do cliente**
- [ ] VM GCE `southamerica-east1` (e2 ou n2-standard-4)
- [ ] Debian 12 + Docker / Dokploy
- [ ] Staging CI atual → cutover produção
- [ ] Cancelar/reduzir hospedagem Locaweb após validação

**Não fazer em produção Fase 1:** Proxmox nested na VM GCP.

---

## 8. Software / IA (próximo)

- [ ] **Obter acesso ao código-fonte CodeIgniter**
- [ ] **Obter acesso à base de dados (read-only ou dump)**
- [ ] Discovery: inventário + plano detalhado de migração
- [ ] Congelar 2 melhorias
- [ ] Executar Laravel + IA conforme plano (implantação R$ 15k em 10× R$ 1,5k/quarta + mensalidade R$ 2,2k após)

---

## Contacto interno

| Papel | Quem |
|-------|------|
| Cliente / decisório | José Abdalla |
| Entrega comercial | B&M Smart TECH |
| Dev + IA | AGLz (via B&M) |
| Custos GCP / SAAS | **Cliente** |
| Ponto focal técnico cliente | TBD |
