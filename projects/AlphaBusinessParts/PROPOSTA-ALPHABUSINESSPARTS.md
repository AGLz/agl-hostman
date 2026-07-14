# Proposta Comercial — Alpha Business Parts

**Cliente:** José Abdalla — Alpha Business Parts · Barueri/SP  
**Fornecedor:** B&M Smart TECH  
**Data:** Julho/2026 · **Validade:** 30 dias · **Versão:** 1.5  
**Site:** alphabusinessparts.com.br

> Pacote digital: **R$ 35.000** nos **primeiros 4 meses**; a partir do **5.º mês**, mensalidade **R$ 5.000**.  
> **GCP e demais cloud/SAAS:** custos **pagos pelo cliente** (cartão / billing próprio).  
> **Servidores Dell** (T7500 + 2.º Dell): **cobrança à parte** (§8).  
> Migração Laravel detalhada após Discovery com **código-fonte + DB**.

---

## 1. Apresentação

A **B&M Smart TECH** propõe modernizar a operação digital da Alpha Business Parts: migrar o sistema atual (PHP/CodeIgniter na Locaweb) para **Laravel**, incorporar **IA** na aplicação, operar um **Agente** de infra e canais digitais, e concluir a saída da Locaweb (e-mail Google Workspace, origin em cloud moderna), mantendo a **Cloudflare** como frente.

Somos um centro técnico premium em Alphaville/Barueri (smartphones, MacBook, notebooks e periféricos), com capacidade para projetos de TI empresarial — infraestrutura, cloud, e-mail, hardware e acompanhamento contínuo.

Nas frentes de **desenvolvimento de software** e **implementação de IA**, a B&M conta com a parceria tecnológica da **AGLz** (metodologia, stack Laravel e agentes de IA).

Trabalhamos de forma **faseada**, com transparência sobre o que já foi feito na primeira semana e o que vem a seguir — reduzindo risco e mantendo o investimento sob controlo.

---

## 2. Entendimento da necessidade

A Alpha Business Parts é um desmanche **DETRAN-SP** especializado em peças de caminhões e ônibus (Mercedes-Benz, Volvo, Scania), com e-commerce e venda consultiva (WhatsApp), além de serviço de jateamento com gelo seco.

**Projeto digital (esta proposta — R$ 35.000 + mensalidade):**

1. Migração CodeIgniter → **Laravel** + **2 melhorias** (detalhe após Discovery)
2. **IA** dentro da aplicação
3. **Agente** de infra/ops (uptime, SEO, Google, Mercado Livre, redes sociais, etc.)
4. E-mails `@alphabusinessparts.com.br`: Locaweb → **Google Workspace**
5. DNS já na **Cloudflare**; aplicação ainda na Locaweb — objetivo: **sair da Locaweb**
6. Hospedagem em **GCP** (provisionamento B&M; **valores GCP a cargo do cliente**)
7. Workstation: iMac 15,1 (Windows 10 + OneDrive) — incluído no onboarding digital

**Hardware de servidores (proposta / fatura separada — §8):**

8. Dell Precision T7500 (upgrade memória + cooler)
9. Servidor Dell 2× Xeon (power-on / inventário)

---

## 3. Status — Onboarding / Quick Wins (semana 1)

### Projeto digital (pacote R$ 35.000)

| Item | Estado | Observação |
|------|--------|------------|
| DNS Cloudflare | **Concluído** | Site/origin ainda Locaweb |
| Google Workspace | **Em curso** | Falta validação Google + 5 caixas |
| Windows 10 no iMac 15,1 + OneDrive | **Concluído** | Validado |
| SAAS (GW, CF Pro, Claude, Cursor, Codex, Lovable) | **Parcial** | Tokens OK exceto Lovable · **fatura no cartão do cliente** |
| VPS GCP | **Não iniciado** | Setup B&M · **billing GCP do cliente** |
| **Acesso ao código-fonte (CI)** | **Pendente** | **Bloqueia o Discovery** |
| **Acesso à base de dados** | **Pendente** | **Bloqueia o Discovery** |

Mailboxes Workspace a criar: `diretoria`, `financeiro`, `vendas`, `contato`, `admin`.

### Servidores Dell — cobrança à parte (§8)

| Equipamento | Estado | Observação |
|-------------|--------|------------|
| Dell Precision T7500 | **Em curso** | Upgrade 4×16 GB DDR3 ECC; cooler frontal a cotar |
| Servidor Dell 2× Xeon | **Pendente** | Power-on / inventário (ainda não ligado) |

---

## 4. Escopo por fase (projeto digital)

### Fase 0 — Discovery (prioridade)

**Pré-requisitos (ainda em falta):**

1. Acesso ao **código-fonte** da aplicação CodeIgniter (repositório / dump completo)
2. Acesso à **base de dados** (credenciais read-only ou dump + schema)

Sem estes itens não é possível inventariar o sistema nem detalhar a migração Laravel.

**Com acesso liberado, o Discovery cobre:**

- Inventário do código, admin/estoque, schema DB, frete, gateway de pagamento
- Mapeamento DETRAN / rastreabilidade e regras de negócio
- Congelamento das **2 melhorias**
- **Plano detalhado de migração** (módulos, ordem Strangler Fig, riscos, marcos)
- Backlog priorizado para execução dentro do pacote inicial

### Fase 1 — Fundação (sair da Locaweb)

- Conclusão Google Workspace: validação, 5 mailboxes, cutover MX, SPF/DKIM/DMARC
- Provisionar **GCP Compute Engine** (`southamerica-east1`) + Debian + **Docker/Dokploy**
- Staging da app atual; cutover de origin (Locaweb → GCP) com Cloudflare na frente
- Monitorização básica e backups

> **GCP:** a B&M configura e opera a infraestrutura; os **custos de cloud (VM, disco, rede, etc.) são integralmente do cliente**, via conta/billing GCP própria (cartão já usado nas contratações SAAS). Estimativa orientativa: ~US$ 180–280/mês para um ambiente pequeno em São Paulo — valor real conforme uso.

> **Recomendação técnica:** em produção, **não** instalar Proxmox *nested* dentro de uma VM GCP. Nested virt é aceitável para laboratório; para Laravel em produção usamos GCE + contentores. **Proxmox multi-cloud HA** fica como evolução futura (fora do pacote de R$ 35.000), em **bare metal**.

### Fase 2 — Migração Laravel + 2 melhorias *(dev com AGLz)*

> Escopo **detalhado após o Discovery** (código + DB). Abaixo fica a direção técnica, não o desenho final.

- App Laravel 12 + Inertia/React + PostgreSQL, em paralelo ao CI (**Strangler Fig**)
- Migração modular conforme plano do Discovery
- Preservação SEO (301), GA4, Meta Pixel e conversões WhatsApp
- Implementação das 2 melhorias acordadas no Discovery

### Fase 3 — IA na aplicação + Agente ops *(IA/AGLz)*

- **IA in-app** (Laravel AI SDK, implementação AGLz): matching OE/aplicação, assistente de orçamento, enrichment SEO/PDP, classificação de fotos — prioridade conforme Discovery
- **Agente ops** (stack AGLz): infra, alertas, SEO/GSC, Google, Mercado Livre, redes — roadmap congelado no Discovery

### Evolução futura (fora do pacote inicial)

- HA multi-cloud com Proxmox em bare metal + Cloudflare failover + backup tertiary  
- Orçamentado à parte quando fizer sentido operacional

> Escopo congelado por fase: mudanças durante uma fase entram no backlog da seguinte ou como *change request* (§10).

---

## 5. Abordagem técnica

| Camada | Proposta | Quem paga | Responsável técnico |
|--------|----------|-----------|---------------------|
| E-mail / DNS | Workspace + Cloudflare Pro | **Cliente** (já contratado) | B&M |
| GCP (VM, disco, egress) | GCE SP + Docker/Dokploy | **Cliente** (billing GCP) | B&M (setup/ops) |
| Tooling AI (Claude, Cursor, etc.) | Licenças já ativas | **Cliente** | — |
| App Laravel + IA | Stack AGLz | Incluso no pacote / mensalidade B&M | B&M · AGLz |
| Servidores Dell | T7500 + 2.º Dell | **À parte** (§8) | B&M |

---

## 6. Cronograma estimado

| Frente | Duração | Marco |
|--------|---------|-------|
| Onboarding digital | Em curso | Workspace + iMac |
| **Liberação código + DB** | **ASAP** | Desbloqueia Discovery |
| **Fase 0 — Discovery** | 2–3 semanas | Plano de migração + 2 melhorias |
| **Fase 1 — Fundação** | 3–5 semanas | MX Google + app na GCP |
| **Fases 2–3 — Laravel / IA** | a detalhar no Discovery | Marcos do plano técnico |
| Servidores Dell | paralelo | Orçamento e entrega §8 |

---

## 7. Investimento — Pacote digital (R$ 35.000)

**Total do projeto digital: R$ 35.000**, faturado por fases:

| Fase | Escopo resumido | Valor |
|------|-----------------|-------|
| **Onboarding / Quick Wins** | DNS CF, Workspace (em curso), iMac Windows/OneDrive | R$ 5.000 |
| **Fase 0 — Discovery** | Inventário código+DB, plano de migração, 2 melhorias | R$ 5.000 |
| **Fase 1 — Fundação** | Workspace cutover, setup GCP + Dokploy, cutover Locaweb | R$ 12.000 |
| **Fases 2–3 — Laravel + IA (base)** | Execução conforme plano do Discovery (dev AGLz + IA) | R$ 13.000 |
| **Total** | | **R$ 35.000** |

**Explicitamente fora dos R$ 35.000:**

| Item | Quem paga |
|------|-----------|
| **GCP** (VM, disco, rede, snapshots, etc.) | **Cliente** |
| Workspace, Cloudflare Pro, Claude/Cursor/Codex/Lovable | **Cliente** (já no cartão) |
| **Servidores Dell** (mão de obra + peças) | **À parte** — §8 |
| HA multi-cloud (evolução futura) | Orçamento futuro |

### Cronograma de pagamento (pacote digital + mensalidade)

| Período | O que fatura | Valor |
|---------|--------------|-------|
| **Meses 1 a 4** | Pacote inicial de R$ 35.000 (4 parcelas iguais) | **R$ 8.750 / mês** |
| **A partir do 5.º mês** | Manutenção e suporte (§9) | **R$ 5.000 / mês** |

- **Total nos primeiros 4 meses:** R$ 35.000 (4 × R$ 8.750)  
- A mensalidade de R$ 5.000 **não** se soma ao pacote nos meses 1–4 — entra **somente a partir do mês 5**.  
- As fases do escopo (Discovery, Fundação, Laravel/IA) correm em paralelo a este calendário de faturação; o progresso técnico segue os marcos das fases, independentemente da divisão mensal do pagamento.  
- GCP / SAAS (cliente) e servidores Dell (§8) são faturas à parte, fora desta tabela.

---

## 8. Servidores Dell — cobrança à parte

Este bloco **não** faz parte dos R$ 35.000 nem da mensalidade de R$ 5.000. Será orçado e faturado separadamente.

### 8.1 Dell Precision T7500

| Trabalho | Notas |
|----------|--------|
| Upgrade memória | Remover 6×2 GB; instalar 4×16 GB DDR3 ECC RDIMM (stock — peça R$ 0) |
| Cooler frontal | Cotação OEM **WN845 / T133N / U859H** (~R$ 250–600 estimado) + instalação |
| Mão de obra | Orçamento à parte (labor + validação POST/térmica) |

### 8.2 Servidor Dell 2× Xeon

| Trabalho | Notas |
|----------|--------|
| Power-on / inventário | 2× Xeon, 3× SAS 600 GB, 10× 8 GB DDR3 ECC |
| Checklist | Elétrico, RAID/HBA, firmware, stress inicial |
| Peças / reparos | Se necessário após diagnóstico — cotação à parte |
| Mão de obra | Orçamento à parte |

> Valores de labor e peças dos Dell serão enviados em **proposta/anexo hardware** dedicado, para aprovação do cliente antes da continuidade.

---

## 9. Manutenção e suporte (recorrente)

Após o pacote digital (ou desde a Fundação, se preferir cobertura contínua):

| | |
|--|--|
| **Mensalidade** | **R$ 5.000 / mês** |
| **Inclui** | Manutenção, suporte em horário comercial, evolução controlada, acompanhamento de infra/DevOps e das entregas Laravel/IA |

**Porquê este valor:** a mensalidade cobre a **expertise especializada** — não inclui o consumo de cloud:

- **Laravel** — manutenção e evolução da aplicação pós-migração  
- **IA** — agentes, integrações e operação assistida (parceria AGLz)  
- **Infra / DevOps** — operação em GCP/Cloudflare, deploys, backups, monitorização e incidentes  

**Não inclui:** fatura GCP, Workspace, Cloudflare Pro, tooling AI, nem manutenção física dos servidores Dell (salvo acordo à parte).

### SLA (referência)

| Severidade | Primeiro retorno | Resolução-alvo |
|------------|------------------|----------------|
| Crítica (site/checkout parado) | 2 h úteis | 8 h úteis |
| Alta | 4 h úteis | 2 dias úteis |
| Média/baixa | 1 dia útil | backlog priorizado |

---

## 10. Premissas e exclusões

**Premissas:**

- Ponto focal do cliente no Discovery e homologações
- **Acesso ao código-fonte e à base de dados** para o Discovery (obrigatório)
- Acesso a painéis (Locaweb, Cloudflare, Workspace, **billing GCP do cliente**)
- **Cliente arca com todos os custos GCP e SAAS** (cartão / conta própria)
- Cutover MX só após as 5 caixas criadas e validadas

**Exclusões (salvo contratação adicional):**

- **Servidores Dell** — ver §8 (proposta hardware separada)
- Consumo/billing **GCP** e demais cloud/SAAS — **cliente**
- Anúncios pagos (Google Ads / Meta Ads) e comissões marketplace
- HA multi-cloud e backup tertiary (evolução futura)
- Escopo Laravel além do plano do Discovery dentro dos R$ 35.000 — *change request* ou ajuste via mensalidade sob acordo

**Change requests:** fora do escopo congelado → estimativa à parte.

---

## 11. Próximos passos

1. Aprovar pacote digital (**R$ 35.000** em 4× R$ 8.750; mensalidade **R$ 5.000** a partir do 5.º mês)
2. Confirmar que **billing GCP** (e SAAS) permanece no **cartão/conta do cliente**
3. **Liberar acesso ao código-fonte e ao DB** (desbloqueia Discovery)
4. Concluir Workspace: validação Google + 5 mailboxes + cutover MX
5. Receber / aprovar **orçamento separado dos servidores Dell** (§8)
6. Kickoff Discovery → plano detalhado de migração Laravel/IA
7. Provisionar GCP na conta do cliente e planear cutover origin

---

**B&M Smart TECH**  
Praça das Paineiras, 66 — Centro Comercial de Alphaville, Barueri/SP  
(11) 96381-1921 · contato@bwlmtecnologia.com.br · Instagram @bmsmarttech

*Desenvolvimento de software e IA: parceria tecnológica AGLz.*
