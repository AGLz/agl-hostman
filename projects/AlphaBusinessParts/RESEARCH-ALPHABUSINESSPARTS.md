# Research — Alpha Business Parts

**Cliente:** José Abdalla · Alpha Business Parts  
**Fornecedor comercial:** B&M Smart TECH  
**Parceiro técnico (dev + IA):** AGLz  
**Data:** 2026-07-14 · **Atualizado:** 2026-07-14 (v1.1 fornecedor B&M)

> Documento interno de suporte à proposta comercial. Não contém secrets/API tokens.

---

## 1. Perfil do negócio

| Item | Evidência pública |
|------|-------------------|
| Nome | Alpha Business Parts (`schema.org` AutoPartsStore) |
| Segmento | Peças para **caminhões e ônibus** (Mercedes-Benz, Volvo, Scania) |
| Oferta | Peças usadas, recondicionadas e remanufaturadas; desmanche **credenciado DETRAN-SP** |
| Extra | Jateamento com gelo seco (CO₂) — `/jateamento` |
| Endereço | Rua Júlio Mesquita, 122 — Vila Morellato, Barueri/SP — CEP 06408-030 |
| Contato | (11) 93413-6692 / (11) 94209-4357 · WhatsApp como CTA principal |
| Site | https://alphabusinessparts.com.br |

**Modelo de venda:** e-commerce + orçamento consultivo (carrinho, frete por CEP, Pix/cartão/boleto; conversão forte via WhatsApp).

**Catálogo (sitemap ~2026-06-26):** ~154 SKUs públicos; categorias motores, transmissão, eixos, direção, arrefecimento, injeção, elétricos, remanufaturado, etc.

**Desambiguação:** não confundir com **Alpha Business Imóveis** (lead makemoney01 / Alphaville).

---

## 2. Pegada técnica pública

| Camada | Achado |
|--------|--------|
| App | **CodeIgniter** (`ci_session`, rotas `index.php/...`) |
| Runtime | PHP **8.3.0** (`X-Powered-By`) |
| Front | Bootstrap 5.3.8, jQuery 3.7.1 |
| DNS / CDN | **Cloudflare** (NS `jo`/`woz.ns.cloudflare.com`) — migração DNS já feita |
| Origin | **Locaweb** (`lw-x-id`; MX ainda `mx*.locaweb.com.br`) |
| Admin público | Paths comuns (`/admin`, `/login`) → 404 (backoffice provavelmente privado) |
| Analytics | GA4 `G-0412B3HS0Z` · Meta Pixel `1115619420099362` · GSC (vários TXT) |
| Social | facebook.com/alphabusinessparts · instagram.com/alphabusinessparts |

**Riscos técnicos visíveis:** CSRF fraco no form de carrinho; typo SEO “Bussiness”; tracking e URLs devem ser preservados no cutover.

---

## 3. Anexo A — Laravel + IA

### Migração CodeIgniter → Laravel

- Padrão recomendado: **Strangler Fig** — Laravel ao lado do CI, base de dados partilhada, roteamento por path (Nginx/Cloudflare).
- Evitar big-bang; migrar módulos com testes de regressão.
- **Discovery prioritário:** admin/estoque, gateway de pagamento, cálculo de frete, autenticação/hashes legados, sessões, conformidade DETRAN / rastreabilidade de peças.

### Stack alvo (execução AGLz sob contrato B&M)

| Camada | Tecnologia |
|-------|------------|
| Backend | Laravel 12 |
| Frontend | Inertia + React + shadcn/ui |
| DB | PostgreSQL (ou Eloquent sobre schema legado na fase de transição) |
| Qualidade | Pest, CI, cobertura >80% no núcleo |

### IA na aplicação

- Pacote first-party **Laravel AI SDK** (`laravel/ai`): agentes, tools, filas, embeddings, structured output.
- Casos de uso alinhados ao negócio:
  1. Matching OE / aplicação (ex.: OM 457, Axor, Actros)
  2. Assistente de orçamento / WhatsApp
  3. Enrichment de descrições PDP e SEO
  4. Classificação de fotos de desmanche → SKU/categoria

### Agente de ops (fora da app)

- Monitorização: uptime, frete, checkout, estoque zerado
- Canais digitais: SEO/GSC, Google Business, Mercado Livre, redes sociais
- Runtime de agentes: parceria AGLz (Hermes / agency) — escopo congelado no Discovery; fornecedor do cliente = B&M
- As **2 melhorias** pedidas pelo cliente são definidas na Fase 0 (não inventadas neste research)

---

## 4. Anexo B — Hardware Dell Precision T7500 + 2.º servidor

### Memória (upgrade em curso)

| Item | Spec / decisão |
|------|----------------|
| Estado anterior | 6× 2 GB DDR3 |
| Upgrade | **4× 16 GB DDR3 ECC RDIMM** (stock B&M) |
| Compatibilidade | **Oficial** — Dell lista módulos 1–16 GB; máx. **192 GB** com 2 CPUs + RDIMM |
| Cuidados | Só RDIMM ECC (sem misturar UDIMM); preferir **2Rx4**; remover todos os 2 GB; popular DIMM1→4; 1600 MHz desce para ≤1333 |
| Custo peças | **R$ 0** (stock) — cobrança apenas de mão de obra |

### Cooler frontal (a cotar)

| PN Dell | Notas |
|---------|--------|
| **WN845 / 0WN845** | Dual fan + shroud (mais citado) |
| **T133N / 0T133N** | Fan + shroud T7500 |
| **U859H / 0U859H** | Alternativo |

Não substituir por fan PC genérico (conector/shroud proprietários). Faixa BR estimada: **R$ 250–600**.

### 2.º servidor Dell (ainda não ligado)

Inventário declarado: 2× Xeon, 3× SAS 600 GB, 10× 8 GB DDR3 ECC (~80 GB).

**Checklist pré power-on:**

1. Circuito elétrico adequado + UPS senoidal se existir  
2. Heatsinks CPU assentados; fans OK  
3. Memória: todos RDIMM ou todos UDIMM — sem mistura; BIOS confirma tamanho/speed  
4. Identificar HBA/PERC; decidir RAID (5 vs 1+spare vs JBOD) **antes** de Clear Foreign  
5. BIOS / firmware storage; bateria CMOS; diagnóstico Dell no 1.º boot  
6. Stress curto (memória + SMART SAS) antes de produção  

---

## 5. Anexo C — GCP + saída da Locaweb

### Recomendação Fase 1 (produção)

| Fazer | Evitar |
|-------|--------|
| VM **GCE** `southamerica-east1` (e2 ou n2-standard-4) + Debian + **Docker/Dokploy** | **Proxmox nested** dentro de VM GCP em produção |
| Cloudflare (Tunnel ou orange + Full Strict / Origin CA) | Flexible SSL |

- Nested virt no GCP: possível (Intel Haswell+, **não** E2/AMD); overhead ≥10%; ok para lab, frágil para prod e para HA futuro.
- Custo orientativo SP: **~US$ 180–280/mês** (VM + disco 100–200 GB + egress leve) — no cartão do cliente.

### Fase 4 (HA multi-cloud)

- Proxmox em **bare metal** (GCP Bare Metal / Equinix / OVH + futuros AWS/Azure dedicados)
- Cloudflare como plano de controlo (DNS, Tunnel, Load Balancing / failover)
- Backup tertiary: provider ainda **TBD**

**Posição técnica (B&M; stack recomenda AGLz para o Laravel):**  
*Proxmox-on-GCP é viável como laboratório; para produção Laravel recomendamos Compute Engine + contentores na Fase 1. A arquitetura Proxmox multi-cloud HA fica na Fase 4 em hardware bare metal.*

---

## 6. Implicações comerciais

1. Catálogo público ~150 SKUs → migração de dados viável; risco real está no **backoffice/estoque físico** e compliance DETRAN.  
2. Funil WhatsApp + GA4/Meta → cutover deve preservar tracking e conversões.  
3. Saída Locaweb: DNS já na Cloudflare; falta origin app + MX → Workspace.  
4. Hardware: RAM validada; cooler sob cotação; 2.º Dell = inventário + power-on checklist.  
5. Tooling SAAS (Workspace, CF Pro, Claude/Cursor/Codex/Lovable) já no cartão do cliente.

---

## 7. Referências

- Dell Precision T7500 spec sheet / service manual (memória até 192 GB RDIMM, PNs fan)
- Google Cloud Nested Virtualization docs
- Laravel AI SDK — blog oficial Laravel
- Runbook wiki: [[Google Workspace — migrar e-mail sem mover o site]]
- Proposta irmã (formato): `projects/ERP-Alphaville01/`
