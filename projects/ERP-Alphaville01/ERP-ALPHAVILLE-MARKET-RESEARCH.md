# Research de Mercado — ERP sob medida para cliente em Alphaville/SP

> Documento de fundamentação para a proposta comercial. Reúne panorama de mercado,
> contexto regional, análise de abordagens (sob medida vs. produto) e recomendação
> estratégica. **Data:** Jun/2026. **Fontes:** ver secção final.

---

## 1. Sumário executivo

O cliente (comércio/varejo, porte pequeno, < R$ 15 MM de faturamento, ~até 20 usuários)
solicitou o **desenvolvimento de um ERP sob medida** cobrindo Financeiro, Fiscal, Estoque,
Vendas/CRM, RH, Produção e BI.

**Conclusão honesta deste research:** o pedido, como formulado, está **super-dimensionado**
para o porte do cliente. Construir 7 áreas funcionais do zero é território de R$ 150–400 mil
e 6–12 meses — perfil de empresa de R$ 30–100 MM, não de uma PME comercial pequena. A própria
literatura de mercado aponta este como o erro clássico ("PME tenta sob medida sem processo
definido → vira refatoração eterna").

**Recomendação:** abordagem **faseada com MVP enxuto** focado no núcleo que dá ROI imediato
ao varejo (Vendas/CRM + Estoque + Financeiro + Fiscal essencial), deixando RH, Produção e BI
avançado para fases seguintes — **e apresentar ao cliente, com transparência, a alternativa
de produto de prateleira** (Bling/Omie/Tiny ou Odoo) como benchmark de decisão. Isso protege a
relação de longo prazo e posiciona a nossa empresa como consultora, não apenas fornecedora de horas.

---

## 2. Panorama do mercado ERP no Brasil (2026)

| Indicador                                 | Dado                                                                             |
| ----------------------------------------- | -------------------------------------------------------------------------------- |
| Liderança de mercado                      | TOTVS e SAP empatadas com **34%** cada; Oracle 10%; outros 22% (FGVcia, 36ª ed.) |
| Share TOTVS em PMEs (até ~170 "teclados") | **~50–52%** — domínio por aderência fiscal nativa                                |
| Tamanho do mercado BR                     | ~US$ 1,24 bi (2025) → projeção US$ 3,04 bi até 2033 (**CAGR ~12%**)              |
| Crescimento investimento ERP BR           | **+11%** em 2025                                                                 |
| Intenção de troca/aquisição               | **>33%** das empresas planejam adquirir/substituir ERP até fim de 2026           |
| Driver dominante 2026                     | **Reforma Tributária (CBS/IBS)** força modernização fiscal                       |

**Leitura:** o mercado está em janela de troca acelerada, puxada pela reforma tributária.
Qualquer ERP — sob medida ou produto — **tem de nascer já preparado para CBS/IBS**, sob pena
de obsolescência em 24 meses. Este é um argumento de venda forte e um requisito não-negociável.

---

## 3. Contexto regional — Alphaville / Barueri (SP)

| Indicador                     | Dado                                                                           |
| ----------------------------- | ------------------------------------------------------------------------------ |
| Empresas ativas em Alphaville | **~26 mil** (≈42,7% das sediadas em Barueri)                                   |
| PIB de Barueri                | ~R$ 71,6 bi; **81,9%** do valor adicionado vem de **serviços**                 |
| Perfil dominante              | Apoio administrativo, promoção de vendas, consultoria, holdings, TI, logística |
| Base empresarial              | Maioria micro/pequenas + sedes de multinacionais                               |
| Renda                         | Entre as mais altas da RMSP (Tamboré, Aldeia da Serra, Alphaville)             |
| Vantagem fiscal local         | ISS reduzido (em revisão por conta da reforma tributária)                      |
| Infra                         | Acesso a Castelo Branco/Rodoanel/Anhanguera; polos logísticos e office parks   |

**Leitura para o varejo do cliente:** região de **alto poder de compra** e densidade
empresarial elevada. Para um comércio, isto significa pressão por: integração com
**marketplaces/e-commerce**, gestão de estoque ágil, emissão fiscal volumosa (NFC-e/NF-e) e
CRM para fidelização de um público de ticket alto. Estes vetores devem orientar a priorização
de módulos.

---

## 4. Perfil do cliente e implicações

- **Setor:** comércio / varejo / distribuição.
- **Porte:** pequeno (< R$ 15 MM; até ~20 usuários).
- **Escopo pedido:** Financeiro, Fiscal, Estoque, Vendas/CRM, RH, Produção, BI.

Implicações diretas:

1. **"Produção" raramente faz sentido em comércio puro.** Se houver montagem de kits,
   industrialização leve ou private label, o escopo se justifica parcialmente; caso contrário,
   é candidato a corte.
2. **RH/Folha sob medida é mau negócio.** Folha é altamente regulada (eSocial, FGTS, encargos)
   e muda constantemente. Construir do zero é caro e arriscado — melhor **integrar** com folha
   de prateleira (ou terceirizar contabilidade) do que desenvolver.
3. **Fiscal é o maior risco técnico.** NF-e/NFC-e/SPED + reforma tributária exigem
   manutenção legal contínua. Aqui, ou usamos bibliotecas/gateways fiscais homologados
   (ex.: integradores de NF-e) ou o custo de manutenção explode.
4. **Núcleo de valor real:** Vendas/Estoque/Financeiro integrados + emissão fiscal + dashboards.
   É aqui que o varejo pequeno ganha eficiência imediata.

---

## 5. Análise comparativa — Sob medida vs. Produto

### 5.1 Faixas de investimento (referências de mercado 2026)

| Abordagem                               | Implementação inicial | Recorrência             | Go-live      |
| --------------------------------------- | --------------------- | ----------------------- | ------------ |
| **Sob medida (MVP)**                    | R$ 25–50 mil          | manut. R$ 3–6 mil/mês   | 60–120 dias  |
| **Sob medida (completo, 8–12 módulos)** | R$ 50–150 mil         | manut. R$ 3–10 mil/mês  | 90–180 dias  |
| **Sob medida + integrações complexas**  | R$ 150–400 mil        | manut. R$ 5–10 mil/mês  | 6–12 meses   |
| **Bling/Omie/Tiny (SaaS prateleira)**   | R$ 0–10 mil (setup)   | R$ 200–2 mil/mês        | dias/semanas |
| **Odoo (open-source + consultoria)**    | R$ 40–150 mil         | licença + suporte       | 3–6 meses    |
| **TOTVS/Sankhya (produto)**             | R$ 80–300 mil         | licença R$ 4–12 mil/mês | 6–18 meses   |

> **Regra de ouro do TCO:** em produtos, a implementação custa tipicamente **2–5×** o valor
> da licença no 1º ano. Em sob medida, o risco está no **escopo mal definido**, não na licença.

### 5.2 Quando o sob medida ganha

- Processo de negócio **diferenciado** que é vantagem competitiva.
- Recusa a pagar licença por usuário eternamente (escala "de graça").
- Necessidade de **iteração rápida** (feature nova em 1–2 semanas vs. 1–3 meses com consultoria de produto).
- Propriedade do código e dos dados.

### 5.3 Quando o produto ganha

- Processos padrão de varejo já resolvidos por SaaS barato.
- Fiscal/folha que o cliente não quer manter.
- Orçamento e equipe internos limitados.

### 5.4 Matriz de decisão para ESTE cliente

| Critério                    | Peso         | Sob medida               | Prateleira (Bling/Omie)   | Odoo híbrido |
| --------------------------- | ------------ | ------------------------ | ------------------------- | ------------ |
| Custo inicial               | Alto         | ▼ caro                   | ▲ barato                  | ◆ médio      |
| TCO 36 meses                | Alto         | ◆ médio                  | ▲ baixo (se pouco custom) | ◆ médio      |
| Aderência fiscal BR         | Crítico      | ▼ risco (manter sozinho) | ▲ nativo                  | ▲ nativo     |
| Diferenciação/flexibilidade | Médio        | ▲ total                  | ▼ limitada                | ▲ alta       |
| Velocidade de go-live       | Médio        | ▼ lento                  | ▲ rápido                  | ◆ médio      |
| Propriedade do código       | Baixo p/ PME | ▲ sim                    | ▼ não                     | ◆ parcial    |

**Veredito técnico:** para um varejo pequeno, **prateleira ou Odoo híbrido** seriam o caminho
de menor risco/custo. O **sob medida puro** só se justifica se houver um diferencial de processo
real e orçamento para sustentá-lo. Devemos apresentar isto com honestidade — e, se o cliente
ainda assim optar por sob medida, mitigar o risco com **MVP faseado**.

---

## 6. Alerta estratégico (transparência com o cliente)

> Construir RH/Folha, Fiscal completo e Produção do zero para uma PME comercial é o cenário
> que o mercado mais associa a **estouro de orçamento e refatoração eterna**. Recomendamos
> registrar formalmente este alerta na proposta para alinhar expectativas e proteger ambos os lados.

Mitigações propostas:

- **Fiscal** via integrador/gateway homologado (não reinventar SPED/NF-e).
- **RH/Folha** via integração com solução existente, não desenvolvimento próprio na fase 1.
- **Produção** só se confirmado processo industrial; senão, fora do escopo inicial.

---

## 7. Recomendação final

**Abordagem faseada, sob medida, com núcleo enxuto:**

- **Fase 1 — MVP (núcleo de varejo):** Vendas/CRM + Estoque/Compras + Financeiro (CP/CR/caixa)
  - Emissão fiscal NF-e/NFC-e via integrador + Dashboard operacional. **Já preparado para CBS/IBS.**
- **Fase 2 — Evolução:** BI executivo, integrações (e-commerce/marketplace), relatórios fiscais SPED.
- **Fase 3 — Opcional:** RH (via integração) e Produção/PCP (se aplicável).

Stack sugerida (a confirmar na proposta): **Laravel 12 + Inertia/React + PostgreSQL**,
alinhada às competências do nosso time, com gateway fiscal de terceiros homologado.

---

## 8. Riscos e premissas

| Risco                                   | Impacto | Mitigação                                                |
| --------------------------------------- | ------- | -------------------------------------------------------- |
| Escopo aberto ("quero tudo")            | Alto    | MVP faseado + escopo congelado por fase                  |
| Manutenção fiscal (reforma tributária)  | Alto    | Integrador homologado + contrato de manutenção evolutiva |
| Folha de pagamento sob medida           | Alto    | Integrar, não desenvolver                                |
| Cliente comparar com SaaS barato depois | Médio   | Apresentar TCO 36 meses e diferenciação desde já         |
| Migração de dados do sistema atual      | Médio   | Discovery dedicado + validação com usuário               |

---

## 9. Fontes consultadas (Jun/2026)

- FGVcia — 36ª Pesquisa Anual de Uso de TI (via ConvergenciaDigital; Bee IT).
- Grand View Research / ABES-IDC — tamanho e CAGR do mercado ERP BR.
- Comparativos TOTVS × SAP × Sankhya × Odoo (fintechnode, uaitech, ecosire, algoritmodiario).
- Custos sob medida vs. produto (nFactory, Meypi, Mind Consulting, Logos Technology).
- Perfil econômico Alphaville/Barueri (EmpresAqui, Caravela, BuscaDeEmpresas, Triceleads, Vale Vitória).

> Observação: valores são faixas de referência de mercado; a precificação final da nossa proposta
> está no documento `ai-docs/propostas/PROPOSTA-ERP-ALPHAVILLE.md`.
