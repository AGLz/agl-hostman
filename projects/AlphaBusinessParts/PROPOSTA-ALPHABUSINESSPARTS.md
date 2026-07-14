# Proposta Comercial — Alpha Business Parts

**Cliente:** José Abdalla — Alpha Business Parts · Barueri/SP  
**Fornecedor:** B&M Smart TECH  
**Data:** Julho/2026 · **Validade:** 30 dias · **Versão:** 1.1  
**Site:** alphabusinessparts.com.br

> Valores são faixas estimadas (research técnico + mercado). Orçamento fechado após a **Fase 0 — Discovery**. Detalhe técnico em `RESEARCH-ALPHABUSINESSPARTS.md`.

---

## 1. Apresentação

A **B&M Smart TECH** propõe modernizar a operação digital da Alpha Business Parts: migrar o sistema atual (PHP/CodeIgniter na Locaweb) para **Laravel**, incorporar **IA** na aplicação, operar um **Agente** de infra e canais digitais, e concluir a saída da Locaweb (e-mail Google Workspace, origin em cloud moderna), mantendo a **Cloudflare** como frente.

Somos um centro técnico premium em Alphaville/Barueri (smartphones, MacBook, notebooks e periféricos), com capacidade para projetos de TI empresarial — infraestrutura, cloud, e-mail, hardware e acompanhamento contínuo.

Nas frentes de **desenvolvimento de software** e **implementação de IA**, a B&M conta com a parceria tecnológica da **AGLz** (metodologia, stack Laravel e agentes de IA).

Trabalhamos de forma **faseada**, com transparência sobre o que já foi feito na primeira semana e o que vem a seguir — reduzindo risco e mantendo o investimento sob controlo.

---

## 2. Entendimento da necessidade

A Alpha Business Parts é um desmanche **DETRAN-SP** especializado em peças de caminhões e ônibus (Mercedes-Benz, Volvo, Scania), com e-commerce e venda consultiva (WhatsApp), além de serviço de jateamento com gelo seco.

Pedidos confirmados:

1. Migração CodeIgniter → **Laravel** + **2 melhorias** (a detalhar no Discovery)
2. **IA** dentro da aplicação
3. **Agente** de infra/ops (uptime, SEO, Google, Mercado Livre, redes sociais, etc.)
4. E-mails `@alphabusinessparts.com.br`: Locaweb → **Google Workspace**
5. DNS já na **Cloudflare**; aplicação ainda na Locaweb — objetivo: **sair da Locaweb**
6. Hospedagem futura em **GCP** (com visão de HA multi-cloud)
7. Hardware: iMac (Windows 10), Dell Precision T7500 (upgrade), inventário de 2.º servidor Dell

---

## 3. Status — Onboarding / Quick Wins (semana 1)

| Item | Estado | Observação |
|------|--------|------------|
| DNS Cloudflare | **Concluído** | Site/origin ainda Locaweb |
| Google Workspace | **Em curso** | Falta validação Google + 5 caixas |
| Windows 10 no iMac 15,1 + OneDrive | **Concluído** | Validado |
| Dell Precision T7500 | **Em curso** | 4×16 GB DDR3 ECC (stock); cooler a cotar |
| Servidor Dell 2× Xeon | **Pendente** | Power-on / inventário |
| SAAS (GW, CF Pro, Claude, Cursor, Codex, Lovable) | **Parcial** | Tokens OK exceto Lovable |
| VPS GCP | **Não iniciado** | Ver §5 — recomendação GCE + Dokploy |

Mailboxes Workspace a criar: `diretoria`, `financeiro`, `vendas`, `contato`, `admin`.

---

## 4. Escopo por fase

### Fase 0 — Discovery (prioridade)

- Inventário do código CodeIgniter, admin/estoque, DB, frete, gateway de pagamento
- Mapeamento DETRAN / rastreabilidade e regras de negócio
- Congelamento das **2 melhorias**
- Protótipo de arquitetura Strangler Fig + backlog priorizado
- Orçamento fechado das fases seguintes

### Fase 1 — Fundação (sair da Locaweb)

- Conclusão Google Workspace: validação, 5 mailboxes, cutover MX, SPF/DKIM/DMARC
- Provisionar **GCP Compute Engine** (`southamerica-east1`) + Debian + **Docker/Dokploy**
- Staging da app atual; cutover de origin (Locaweb → GCP) com Cloudflare na frente
- Monitorização básica e backups

> **Recomendação técnica:** em produção, **não** instalar Proxmox *nested* dentro de uma VM GCP. Nested virt é aceitável para laboratório; para Laravel em produção usamos GCE + contentores. **Proxmox multi-cloud HA** fica na **Fase 4**, em **bare metal**.

### Fase 2 — Migração Laravel + 2 melhorias *(dev com AGLz)*

- App Laravel 12 + Inertia/React + PostgreSQL, em paralelo ao CI (**Strangler Fig**)
- Migração modular (catálogo, carrinho, frete, checkout, admin)
- Preservação SEO (301), GA4, Meta Pixel e conversões WhatsApp
- Implementação das 2 melhorias acordadas no Discovery
- Go-live gradual; desligar CI quando estável

### Fase 3 — IA na aplicação + Agente ops *(IA/AGLz)*

- **IA in-app** (Laravel AI SDK, implementação AGLz): matching OE/aplicação, assistente de orçamento, enrichment SEO/PDP, apoio a classificação de fotos
- **Agente ops** (stack de agentes AGLz): infra, alertas, SEO/GSC, Google, Mercado Livre, redes sociais — roadmap congelado no Discovery
- Piloto 90 dias com métricas e revisão

### Fase 4 — HA multi-cloud (opcional)

- Nós Proxmox em **bare metal** (GCP Bare Metal / parceiros + futuros AWS/Azure)
- Sync entre sites; entrada Cloudflare (failover)
- Backup tertiary (provider TBD)

> Escopo congelado por fase: mudanças durante uma fase entram no backlog da seguinte ou como *change request* (§8).

---

## 5. Abordagem técnica

| Camada | Proposta | Responsável |
|--------|----------|-------------|
| Infra, cloud, e-mail, hardware | GCE, Cloudflare, Workspace, workstations/servidores | **B&M Smart TECH** |
| App futura (Laravel 12, Inertia/React, Pest) | Strangler Fig sobre CI | **B&M** · execução técnica **AGLz** |
| IA in-app + Agente ops | Laravel AI SDK, tools/filas, agentes | **AGLz** (via B&M) |
| DNS / borda | Cloudflare Pro (já contratado) — Tunnel ou Full Strict | B&M |
| E-mail | Google Workspace | B&M |
| Fase 1 infra | GCE São Paulo + Debian + Docker/Dokploy (~US$ 180–280/mês) | B&M |
| Fase 4 infra | Proxmox em bare metal + Cloudflare HA | B&M |
| Hardware | T7500: 4×16 GB DDR3 ECC RDIMM **suportado**; cooler OEM WN845/T133N/U859H sob cotação | B&M |

**Hardware — transparência:** os 4×16 GB DDR3 ECC em stock são compatíveis com o Precision T7500 (Dell documenta até 192 GB com RDIMM). O cooler frontal deve ser o assembly OEM (não fan genérico). O 2.º servidor Dell só entra em serviço após checklist elétrico/RAID/firmware.

---

## 6. Cronograma estimado

| Fase | Duração | Marco |
|------|---------|-------|
| Onboarding / Quick Wins | Em curso | Workspace + T7500 + inventário Dell |
| **Fase 0 — Discovery** | 2–3 semanas | Escopo fechado + 2 melhorias |
| **Fase 1 — Fundação** | 3–5 semanas | MX Google + app na GCP + fora da Locaweb |
| **Fase 2 — Laravel** | 10–16 semanas | Go-live Laravel + 2 melhorias |
| **Fase 3 — IA + Agente** | 6–10 semanas (piloto) | IA produtiva + agente ops |
| **Fase 4 — HA** | a definir | Multi-cloud bare metal |

Prazo orientativo até go-live Laravel (Fases 0–2): **~4–7 meses**, sujeito ao Discovery.

---

## 7. Investimento — Implementação

| Item | Investimento estimado |
|------|------------------------|
| Pacote Onboarding / Quick Wins (labor já iniciado + T7500 + inventário Dell) | R$ 3.000–8.000 + peças (cooler sob cotação; RAM stock = R$ 0) |
| **Fase 0 — Discovery** | R$ 5.000–12.000 |
| **Fase 1 — Fundação** | R$ 15.000–35.000 |
| **Fase 2 — Laravel + 2 melhorias** | R$ 80.000–160.000 |
| **Fase 3 — IA + Agente (setup piloto)** | R$ 25.000–60.000 |
| **Fase 4 — HA** | sob orçamento |
| **Total orientativo (0–3, excl. HA)** | **R$ 128.000–275.000** |

**Cloud / SAAS (cartão do cliente, estimativa mensal):** GCP ~US$ 180–280 · Workspace + Cloudflare Pro + tooling AI conforme contratos já ativos.

**Pagamento (sugestão):** Discovery à vista ou 50/50; demais fases 30% início / 40% homologação / 30% go-live. Discovery isolável e abatível se o projeto avançar.

---

## 8. Manutenção e sustentação (recorrente)

Após go-live (ou desde a Fundação, se preferir suporte contínuo):

| Plano | Mensalidade | Inclui |
|-------|-------------|--------|
| **Essencial** | R$ 4.000–6.000 | Correções, suporte horário comercial, backups monitorados |
| **Evolutivo** | R$ 7.000–12.000 | Essencial + banco de horas + SLA prioritário |
| **Gerenciado (+ Agente)** | R$ 12.000–20.000 | Evolutivo + agente ops/SEO/ML/social + roadmap dedicado |

### SLA (plano Evolutivo, referência)

| Severidade | Primeiro retorno | Resolução-alvo |
|------------|------------------|----------------|
| Crítica (site/checkout parado) | 2 h úteis | 8 h úteis |
| Alta | 4 h úteis | 2 dias úteis |
| Média/baixa | 1 dia útil | backlog priorizado |

---

## 9. Premissas e exclusões

**Premissas:**

- Ponto focal do cliente no Discovery e homologações
- Acesso ao código, admin, DB e painéis (Locaweb, Cloudflare, Workspace, GCP)
- Licenças cloud/SAAS no cartão do cliente (já em curso)
- Cutover MX só após as 5 caixas criadas e validadas

**Exclusões (salvo contratação adicional):**

- Peças hardware não stock (cooler T7500, discos, PSUs) — cotação à parte
- Anúncios pagos (Google Ads / Meta Ads) e comissões marketplace
- Desenvolvimento de folha/fiscal genérico fora do âmbito do e-commerce atual
- HA multi-cloud e backup tertiary (Fase 4) sem descoberta de custo bare metal
- Conteúdo editorial contínuo redes sociais além do escopo do Agente acordado

**Change requests:** fora do escopo congelado → estimativa à parte.

---

## 10. Próximos passos

1. Aprovação desta proposta (ou só **Fase 0 — Discovery** + fecho do Onboarding)
2. Concluir Workspace: validação Google + 5 mailboxes + cutover MX
3. Fechar cotação do cooler T7500 (PN WN845 / T133N / U859H) e power-on do 2.º Dell
4. Provisionar GCP (GCE + Dokploy) e planear cutover origin
5. Kickoff Discovery do código CodeIgniter

---

**B&M Smart TECH**  
Praça das Paineiras, 66 — Centro Comercial de Alphaville, Barueri/SP  
(11) 96381-1921 · contato@bwlmtecnologia.com.br · Instagram @bmsmarttech

*Desenvolvimento de software e IA: parceria tecnológica AGLz.*
