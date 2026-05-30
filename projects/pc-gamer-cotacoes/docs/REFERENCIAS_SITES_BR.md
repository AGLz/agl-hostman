# Referências — sites brasileiros de cotação PC gamer

Pesquisa para basear o projeto `pc-gamer-cotacoes`: fluxo de montagem, categorias de peças e comparação de preços.

## Mapa rápido

| Site | Tipo | URL | Melhor para |
|------|------|-----|-------------|
| **MEUPC.NET** | Agregador | [meupc.net/build](https://meupc.net/build) | **Comparar preços** entre KaBuM, Pichau, Terabyte, ML |
| **KaBuM!** | Loja | [kabum.com.br/monte-seu-pc](https://www.kabum.com.br/monte-seu-pc) | Compatibilidade + montagem Customiza |
| **Pichau** | Loja | [pichau.com.br/monte-seu-pc](https://www.pichau.com.br/monte-seu-pc) | Wizard clássico; custo-benefício |
| **Terabyteshop** | Loja | [terabyteshop.com.br/pc-gamer/full-custom](https://www.terabyteshop.com.br/pc-gamer/full-custom) | Full Custom por plataforma (AM5, etc.) |
| **Rocketz** | Loja | [rocketz.com.br/monte-seu-pc](https://rocketz.com.br/monte-seu-pc) | UX visual + total em tempo real |
| **StudioPC** | Pré-montado | [studiopc.com.br](https://www.studiopc.com.br) | Tiers fechados (Supreme…) + opcionais |
| **PC Builder SP** | Serviço | [pcbuilder.com.br/build-personalizada](https://pcbuilder.com.br/build-personalizada) | Orçamento consultivo + montagem Moema |
| **4Gamers** | Loja | [4gamers.com.br/monte-seu-computador](https://www.4gamers.com.br/monte-seu-computador) | Linhas Starter→Colosseum; wizard Nuvemshop |
| **Mercado Livre** | Marketplace | [mercadolivre.com.br](https://www.mercadolivre.com.br) | Preços variados; API `sites/MLB/search` |
| **AliExpress** | Importação | [pt.aliexpress.com](https://pt.aliexpress.com) | Peças importadas; API afiliados IOP |

---

## 1. MEUPC.NET — referência principal para **comparar valores**

**Por que usar como base:** não é loja; agrega preços de várias lojas BR e mostra o menor preço por peça.

Funcionalidades relevantes:

- ~24 mil peças no catálogo
- Compatibilidade automática (soquete, chipset, RAM, formato)
- **Comparação multi-loja** (KaBuM!, Pichau, Terabyte, Mercado Livre, etc.)
- Ofertas com histórico (“menor preço em 90 dias”, mediana)
- Fluxo: montar → validar compatibilidade → escolher loja por peça

Limitação conhecida: validação M.2 não é completa (peças listadas para acompanhamento de preço).

**Como replicamos:** tabela `market_prices` + comando `compare-build` + loja `meupc` como fonte `preset_reference`.

---

## 2. KaBuM! — Monte seu PC

**Validações automáticas** (documentação oficial):

- Soquete CPU ↔ placa-mãe
- Chipset
- Padrão RAM (DDR4/DDR5)
- Espaço no gabinete
- Potência da fonte

**Montagem opcional:** parceiro Customiza, testes OCCT, complexo em Viana/ES.

**Modelo de negócio:** peças separadas ou PC montado; mesmo configurador.

---

## 3. Pichau — Monte seu PC

Wizard em **passos fixos** (ordem que adotámos no projeto):

1. Processador (+ cooler)
2. Placa-mãe
3. Memória RAM
4. Placa de vídeo
5. HD & SSD
6. Gabinete
7. Fonte
8. Periféricos *(excluímos monitor/teclado/rato)*
9. Revisão

**Atenção:** configuração personalizada nesta ferramenta **não é enviada montada** (aviso no site).

Fortes em: marcas próprias (Mancer, TGT), entrada/intermediário.

---

## 4. Terabyteshop — Full Custom

Escolha inicial de **plataforma**, depois peças compatíveis:

- AMD Ryzen 9000 DDR5 AM5
- AMD Ryzen 7000 DDR5 AM5
- AMD Ryzen 5000
- Intel 12ª/13ª/14ª DDR4 ou DDR5 LGA1700
- Intel Core Ultra LGA1851

Durante a montagem: preço total atualiza; alertas de incompatibilidade.

Entrega: **montado e certificado**, frete grátis em várias configs.

Considerada por reviews BR como configurador mais flexível para entusiastas.

---

## 5. Rocketz — configurador visual

- Preço atualizado em tempo real a cada peça
- Visualização do gabinete selecionado
- Fluxo orientado ao objetivo (jogos, estudo, trabalho, conteúdo)

Bom referencial de **UX** para uma futura UI web nossa.

---

## 6. StudioPC — PCs pré-configurados

Exemplo tier alto: Ryzen 7900X + 32GB DDR5 + RTX 5070 + NVMe 1TB.

Opcionais típicos: mais RAM, SSD extra, cooler, Windows (trial/OEM).

Referência para **presets por faixa** (entry / mid / high / enthusiast).

---

## 7. PC Builder (Moema) — serviço, não configurador

Modelo **consultivo**:

- Formulário de uso (FPS, MOBA, edição, stream…)
- Orçamento em 24h com alternativas
- Montagem com peças do cliente (~R$549+) ou grátis na build completa
- Cable management, BIOS/XMP, benchmark, garantia 1 ano do serviço

Inspirou o nosso fluxo de **efetivação** (`approved → ordered → assembly → completed`).

---

## O que implementámos no projeto

| Conceito BR | Implementação local |
|-------------|---------------------|
| Passos Pichau/KaBuM | `BUILD_WIZARD_STEPS` em `src/catalog/reference_sites.py` |
| Tiers StudioPC/Terabyte | 4 presets AMD em `src/catalog/presets.py` |
| Compare MEUPC | `market_prices` + `compare-build` |
| Lojas cadastradas | tabela `retailers` (7 entradas) |
| Preços indicativos | `seed-market` a partir dos presets |

### CLI novo

```bash
python scripts/cli.py sites              # lista sites de referência
python scripts/cli.py wizard-steps       # ordem de slots
python scripts/cli.py presets            # tiers entry→enthusiast
python scripts/cli.py preset amd-mid-7800x3d-5070
python scripts/cli.py new-from-preset amd-mid-7800x3d-5070 --customer "Maria"
python scripts/cli.py seed-market        # baseline preços (MEUPC ref)
python scripts/cli.py market-prices --category placa_video
python scripts/cli.py add-market-price --retailer kabum --category nvme \
  --product "Samsung 990 EVO 1TB" --cost 549.90 --url "https://..."
python scripts/cli.py compare-build 1    # sua cotação vs mercado + Telegram
```

---

## Estratégia de preços recomendada

1. **Baseline:** presets com valores indicativos (atualizar trimestralmente)
2. **Automação:** `fetch-market` para Mercado Livre, AliExpress e 4Gamers → `market_prices`
3. **Mercado manual:** após simular no MEUPC/KaBuM, gravar com `add-market-price`
4. **Ofertas:** sync Telegram para promoções relâmpago
5. **Cotação cliente:** `compare-build` mostra Δ por slot vs melhor fonte

Ver [MARKET_FETCH.md](MARKET_FETCH.md) para cron, `.env` e limitações (403/WAF/captcha).

## Próxima fase (opcional)

- Import CSV exportado manualmente do MEUPC (sem API pública)
- Scraper ético só com autorização / uso pessoal
- Validação AM5 automática (`COMPAT_RULES_AMD_AM5`)
- Link direto “abrir no configurador” por slot (KaBuM/Terabyte)

## Fontes

- [MEUPC.NET](https://meupc.net/build)
- [KaBuM! Monte seu PC](https://www.kabum.com.br/monte-seu-pc)
- [Pichau Monte seu PC](https://www.pichau.com.br/monte-seu-pc)
- [Terabyte Full Custom](https://www.terabyteshop.com.br/pc-gamer/full-custom)
- [Rocketz Monte seu PC](https://rocketz.com.br/monte-seu-pc)
- [StudioPC](https://www.studiopc.com.br)
- [PC Builder Build Personalizada](https://pcbuilder.com.br/build-personalizada)
- [4Gamers Monte seu Computador](https://www.4gamers.com.br/monte-seu-computador)
- [Mercado Livre](https://www.mercadolivre.com.br)
- [AliExpress PT](https://pt.aliexpress.com)
