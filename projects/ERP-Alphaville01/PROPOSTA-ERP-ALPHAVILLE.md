# Proposta de Implementação e Manutenção — ERP sob medida

**Cliente:** [NOME DO CLIENTE] — Comércio/Varejo · Alphaville, Barueri/SP
**Fornecedor:** [SUA EMPRESA]
**Data:** Junho/2026 · **Validade:** 30 dias · **Versão:** 1.0

> Placeholders entre `[ ]` devem ser preenchidos antes do envio. Valores são estimativas
> orientadas pelo research de mercado (`../research/ERP-ALPHAVILLE-MARKET-RESEARCH.md`) e
> serão refinados após o _discovery_ (Fase 0).

---

## 1. Apresentação

A [SUA EMPRESA] propõe o desenvolvimento de um **ERP sob medida**, de propriedade do cliente,
desenhado especificamente para a operação de varejo da [NOME DO CLIENTE]. Diferente de produtos
de prateleira, o sistema é construído em torno dos **processos reais** da empresa, sem licença
por usuário e com liberdade total de evolução.

Adotamos uma **abordagem faseada com MVP**, que reduz risco, antecipa retorno e mantém o
investimento sob controle — alinhada às melhores práticas para PMEs comerciais.

---

## 2. Entendimento da necessidade

A [NOME DO CLIENTE] busca integrar, num único sistema, as áreas de **Vendas, Estoque,
Financeiro, Fiscal, BI** (e, em fases futuras, **RH e Produção**), eliminando planilhas e
sistemas desconexos, com **conformidade fiscal** já preparada para a **Reforma Tributária
(CBS/IBS)**.

### Recomendação técnica (transparência)

Para um varejo deste porte, recomendamos **não desenvolver do zero** as áreas de **Folha de
Pagamento** (integrar com solução homologada) e **emissão fiscal** (usar gateway/integrador
homologado de NF-e/NFC-e). Isso reduz custo e, principalmente, **risco de manutenção legal**.
"Produção/PCP" só entra no escopo se houver processo industrial confirmado.

---

## 3. Escopo por fase

### Fase 1 — MVP (núcleo de varejo) — _prioridade_

- **Vendas/CRM:** cadastro de clientes, pedidos, condições comerciais, histórico, funil básico.
- **Estoque/Compras:** produtos, saldos, entradas/saídas, pedidos de compra, inventário.
- **Financeiro:** contas a pagar/receber, fluxo de caixa, conciliação básica.
- **Fiscal essencial:** emissão de **NF-e/NFC-e** via integrador homologado, já compatível com CBS/IBS.
- **Dashboard operacional:** indicadores de vendas, estoque e caixa.
- **Base técnica:** autenticação, perfis/permissões, auditoria, multiusuário.

### Fase 2 — Evolução

- **BI executivo:** dashboards gerenciais, DRE simplificado, relatórios customizados.
- **Integrações:** e-commerce/marketplace, gateway de pagamento, conciliação bancária.
- **Fiscal avançado:** apuração e relatórios **SPED**.

### Fase 3 — Opcional (sob confirmação)

- **RH:** ponto/escala e integração com folha (não desenvolvimento de folha do zero).
- **Produção/PCP:** apenas se houver processo industrial/montagem de kits.

> **Escopo congelado por fase:** mudanças durante uma fase entram no backlog da fase seguinte
> ou são tratadas como _change request_ (ver §8).

---

## 4. Abordagem técnica

| Camada        | Tecnologia proposta                                        |
| ------------- | ---------------------------------------------------------- |
| Backend       | Laravel 12 (PHP)                                           |
| Frontend      | Inertia + React + shadcn/ui                                |
| Base de dados | PostgreSQL                                                 |
| Fiscal        | Integrador homologado de NF-e/NFC-e (terceiro)             |
| Infra         | Cloud (Docker); deploy via [Dokploy/parceiro]              |
| Qualidade     | Testes automatizados (Pest), CI, cobertura > 80% no núcleo |

Princípios: código de propriedade do cliente, documentação, segurança (validação de inputs,
controle de acesso), e _design system_ consistente.

---

## 5. Cronograma estimado

| Fase                   | Duração      | Marco                                                           |
| ---------------------- | ------------ | --------------------------------------------------------------- |
| **Fase 0 — Discovery** | 2–3 semanas  | Levantamento de processos, escopo detalhado, protótipo de telas |
| **Fase 1 — MVP**       | 8–12 semanas | Go-live do núcleo (Vendas/Estoque/Financeiro/Fiscal)            |
| **Fase 2 — Evolução**  | 6–10 semanas | BI + integrações + SPED                                         |
| **Fase 3 — Opcional**  | a definir    | RH/Produção conforme necessidade                                |

Prazo total estimado até Fase 2: **~4–6 meses**.

---

## 6. Investimento — Implementação

> Faixas estimadas; valor fechado após Fase 0 (Discovery).

| Item                   | Investimento estimado    |
| ---------------------- | ------------------------ |
| **Fase 0 — Discovery** | R$ [5.000–10.000]        |
| **Fase 1 — MVP**       | R$ [60.000–110.000]      |
| **Fase 2 — Evolução**  | R$ [40.000–80.000]       |
| **Fase 3 — Opcional**  | sob orçamento            |
| **Total (Fases 0–2)**  | **R$ [105.000–200.000]** |

**Condições de pagamento (sugestão):** Discovery à vista; demais fases em parcelas atreladas a
marcos (ex.: 30% início / 40% homologação / 30% go-live).

> O Discovery pode ser contratado isoladamente e seu valor abatido caso o projeto avance.

---

## 7. Manutenção e sustentação (recorrente)

Após o go-live, oferecemos contrato mensal de manutenção e evolução. Planos sugeridos:

| Plano          | Mensalidade           | Inclui                                                                                              |
| -------------- | --------------------- | --------------------------------------------------------------------------------------------------- |
| **Essencial**  | R$ [3.000–4.000]/mês  | Correções, suporte em horário comercial, atualizações fiscais/legais (CBS/IBS), backups monitorados |
| **Evolutivo**  | R$ [5.000–7.000]/mês  | Tudo do Essencial + banco de horas para novas funcionalidades + SLA prioritário                     |
| **Gerenciado** | R$ [8.000–10.000]/mês | Tudo do Evolutivo + roadmap dedicado + monitoramento proativo                                       |

### SLA (plano Evolutivo, referência)

| Severidade                                  | Primeiro retorno | Resolução-alvo     |
| ------------------------------------------- | ---------------- | ------------------ |
| Crítica (sistema parado / fiscal bloqueado) | 2h úteis         | 8h úteis           |
| Alta (função importante indisponível)       | 4h úteis         | 2 dias úteis       |
| Média/baixa (ajustes, dúvidas)              | 1 dia útil       | backlog priorizado |

> A manutenção fiscal contínua (acompanhamento da Reforma Tributária) é parte central do
> contrato — é o que mantém o ERP legalmente válido ao longo do tempo.

---

## 8. Premissas e exclusões

**Premissas:**

- Disponibilidade de um ponto focal do cliente durante o Discovery e homologações.
- Acesso aos dados/sistemas atuais para migração.
- Contratação de integrador fiscal e infraestrutura cloud (repassados ou inclusos — definir).

**Exclusões (salvo contratação adicional):**

- Desenvolvimento de folha de pagamento do zero.
- Licenças de terceiros (integrador fiscal, gateway de pagamento, cloud).
- Hardware (PDV, impressoras fiscais, leitores).
- Migração de dados além do escopo acordado no Discovery.

**Change requests:** alterações fora do escopo congelado são estimadas e cobradas à parte
(banco de horas ou orçamento pontual).

---

## 9. Por que sob medida (e quando reavaliar)

Apresentamos, com transparência, que existem alternativas de prateleira (Bling, Omie, Tiny) e
open-source (Odoo) com menor custo inicial. O **sob medida** se justifica quando há
**diferenciação de processo**, recusa a licença por usuário e necessidade de **iteração rápida**.
Caso, no Discovery, concluamos que um produto de prateleira atende melhor, **diremos isso** —
nosso compromisso é com o resultado do cliente, não com o número de horas.

---

## 10. Próximos passos

1. Aprovação desta proposta (ou da **Fase 0 — Discovery** isolada).
2. Agendamento do Discovery (2–3 semanas).
3. Entrega do escopo detalhado + orçamento fechado das Fases 1–2.
4. Início do desenvolvimento.

---

**Contato:** [NOME] · [E-MAIL] · [TELEFONE] · [SUA EMPRESA]
