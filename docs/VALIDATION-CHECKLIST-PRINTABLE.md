# ✅ CHECKLIST DE VALIDAÇÃO - VPS TIMEOUT FIX
## Para imprimir e usar durante monitoramento (2025-10-23)

---

## 📅 INFORMAÇÕES DA SESSÃO

**Data:** ____/____/______
**Responsável:** __________________________
**Horário início:** ______
**Horário fim:** ______

---

## 🎯 PRÉ-REQUISITOS (08:30-08:55)

### Preparação (08:30)
- [ ] 3 terminais SSH abertos
  - [ ] Terminal 1: fgsrv3 (MySQL)
  - [ ] Terminal 2: fgsrv4 (nginx/PHP5)
  - [ ] Terminal 3: fgsrv5 (Laravel)
- [ ] Arquivo COPY-PASTE-TEMPLATES.md aberto
- [ ] Este checklist impresso em mãos
- [ ] Cronômetro/relógio visível

### Baseline (08:50)
- [ ] Diretórios criados em todos os hosts: `/tmp/validation-YYYYMMDD/`
- [ ] Baseline coletado fgsrv3 (MySQL)
  - [ ] CPU & Memory snapshot
  - [ ] MySQL connections status
  - [ ] Confirmado: **BACKUP NÃO RODANDO**
- [ ] Baseline coletado fgsrv4 (nginx/PHP5)
  - [ ] CPU & Memory snapshot
  - [ ] PHP-FPM process count: ____
  - [ ] nginx connections: ____
- [ ] Baseline coletado fgsrv5 (Laravel)
  - [ ] CPU & Memory snapshot
  - [ ] PHP-FPM process count: ____
  - [ ] Queue workers: ____

### Monitores Ativos (08:55)
- [ ] Monitor MySQL iniciado (fgsrv3) - PID: ____
- [ ] Monitor nginx iniciado (fgsrv4) - PID: ____
- [ ] Monitor Laravel iniciado (fgsrv5) - PID: ____

---

## ⏰ JANELA CRÍTICA (09:00-10:00)

### 09:00 - Início da Janela Crítica

#### Verificações Imediatas:
- [ ] **fgsrv3:** Backup MySQL NÃO está rodando
  ```bash
  ps aux | grep mysqldump | grep -v grep
  ```
  **Resultado:** [ ] ✅ SEM BACKUP  [ ] ⚠️ BACKUP DETECTADO

- [ ] **fgsrv4:** Site https://falg.com.br respondendo
  **Response time:** ____ segundos
  **HTTP Status:** ____

- [ ] **fgsrv5:** API https://api.falg.com.br respondendo
  **Response time:** ____ segundos
  **HTTP Status:** ____

### 09:05 - Checkpoint 1
- [ ] Sites acessíveis
- [ ] Sem timeouts em logs
- [ ] Load average OK: ____

### 09:10 - Checkpoint 2
- [ ] Sites acessíveis
- [ ] Sem timeouts em logs
- [ ] MySQL connections: ____
- [ ] PHP-FPM processes (fgsrv4): ____
- [ ] PHP-FPM processes (fgsrv5): ____

### 09:15 - Checkpoint 3
- [ ] Sites acessíveis
- [ ] Sem timeouts em logs
- [ ] Load average OK: ____

### 09:20 - Checkpoint 4
- [ ] Sites acessíveis
- [ ] Sem timeouts em logs
- [ ] MySQL connections: ____

### 09:25 - Checkpoint 5
- [ ] Sites acessíveis
- [ ] Sem timeouts em logs
- [ ] PHP-FPM processes OK

### 09:30 - MEIO DA JANELA (Snapshot Detalhado)

#### fgsrv3 (MySQL):
- [ ] Snapshot coletado
- [ ] Threads_connected: ____ / ____ (____%)
- [ ] Active queries: ____
- [ ] Slow queries detectadas: ____

#### fgsrv4 (nginx/PHP5):
- [ ] Snapshot coletado
- [ ] PHP-FPM processes: ____
- [ ] nginx connections: ____
- [ ] Memory usage: ____

#### fgsrv5 (Laravel):
- [ ] Snapshot coletado
- [ ] PHP-FPM processes: ____
- [ ] Queue workers: ____
- [ ] Memory usage: ____

### 09:35 - Checkpoint 6
- [ ] Sites acessíveis
- [ ] Sem timeouts em logs
- [ ] Load average OK: ____

### 09:40 - Checkpoint 7
- [ ] Sites acessíveis
- [ ] Sem timeouts em logs
- [ ] MySQL connections: ____

### 09:45 - Checkpoint 8
- [ ] Sites acessíveis
- [ ] Sem timeouts em logs
- [ ] PHP-FPM processes OK

### 09:50 - Checkpoint 9
- [ ] Sites acessíveis
- [ ] Sem timeouts em logs
- [ ] Load average OK: ____

### 09:55 - Checkpoint 10 (Pré-finalização)
- [ ] Sites acessíveis
- [ ] Sem timeouts em logs
- [ ] MySQL connections: ____
- [ ] PHP-FPM processes: ____

### 10:00 - FIM DA JANELA CRÍTICA

#### Verificação Final:
- [ ] **ZERO TIMEOUTS detectados** durante janela completa
- [ ] Sites responderam durante 100% do tempo
- [ ] Logs nginx sem erros 502/504
- [ ] MySQL não saturou (< 70% connections)
- [ ] PHP-FPM não saturou (< pm.max_children)

**Sites Status:**
- [ ] falg.com.br: HTTP ____ (Tempo: ____ s)
- [ ] api.falg.com.br: HTTP ____ (Tempo: ____ s)

---

## 📦 PÓS-MONITORAMENTO (10:05-10:30)

### Parar Monitores (10:05)
- [ ] Monitor MySQL parado (fgsrv3)
- [ ] Monitor nginx parado (fgsrv4)
- [ ] Monitor Laravel parado (fgsrv5)

### Coletar Evidências (10:10)
- [ ] Tarball criado fgsrv3: validation-evidence-fgsrv3-YYYYMMDD.tar.gz
- [ ] Tarball criado fgsrv4: validation-evidence-fgsrv4-YYYYMMDD.tar.gz
- [ ] Tarball criado fgsrv5: validation-evidence-fgsrv5-YYYYMMDD.tar.gz

### Download Evidências (10:15)
- [ ] Evidências baixadas para máquina local
- [ ] Tarballs extraídos
- [ ] Diretório: ~/vps-timeout-evidence/

---

## 📊 ANÁLISE DE RESULTADOS (10:30-11:00)

### Critérios de Sucesso

#### ✅ Critérios Primários (MUST HAVE):
- [ ] **ZERO timeouts** em falg.com.br
- [ ] **ZERO timeouts** em api.falg.com.br
- [ ] **ZERO erros 502/504** nos logs nginx

**Status:** [ ] ✅ TODOS OK  [ ] ⚠️ ALGUM FALHOU

#### ✅ Critérios Secundários (SHOULD HAVE):
- [ ] MySQL Threads_connected < 70% do max_connections
  - Pico observado: ____ / ____ (____%)
- [ ] PHP-FPM active processes < 25
  - Pico fgsrv4: ____
  - Pico fgsrv5: ____
- [ ] Response time < 500ms
  - falg.com.br: ____ ms
  - api.falg.com.br: ____ ms
- [ ] CPU usage < 80%
  - fgsrv3: ____%
  - fgsrv4: ____%
  - fgsrv5: ____%
- [ ] Memory usage < 85%
  - fgsrv3: ____%
  - fgsrv4: ____%
  - fgsrv5: ____%

**Status:** [ ] ✅ TODOS OK  [ ] ⚠️ ALGUM FALHOU

#### ✅ Critérios de Validação:
- [ ] Backup MySQL NÃO rodou às 09:00
- [ ] Cron jobs distribuídos (não todos às 09:00)
- [ ] PHP-FPM workers < pm.max_children

**Status:** [ ] ✅ TODOS OK  [ ] ⚠️ ALGUM FALHOU

### Análise Automatizada
- [ ] Script analyze-results.sh executado
- [ ] Relatório gerado
- [ ] Anomalias identificadas: ____

---

## 🎯 RESULTADO FINAL

### Validação Geral
Marque apenas UMA opção:

- [ ] ✅ **SUCESSO TOTAL**
  - Zero timeouts detectados
  - Todos os critérios primários OK
  - Todos os critérios secundários OK
  - **PROBLEMA RESOLVIDO!**

- [ ] ⚠️ **SUCESSO PARCIAL**
  - Timeouts reduzidos mas não eliminados
  - Alguns critérios falharam
  - Necessário ajuste fino
  - **INVESTIGAR:** ______________________

- [ ] ❌ **FALHA**
  - Timeouts ainda presentes
  - Múltiplos critérios falharam
  - Necessário investigação profunda
  - **AÇÃO:** Consultar /docs/research/morning-timeout-analysis.md

### Observações Adicionais
```
_____________________________________________________________

_____________________________________________________________

_____________________________________________________________

_____________________________________________________________

_____________________________________________________________
```

---

## 📝 PRÓXIMOS PASSOS

### Se SUCESSO (Zero timeouts):
- [ ] Monitorar por mais 7 dias consecutivos
- [ ] Analisar slow query log MySQL
- [ ] Implementar monitoring permanente (Prometheus/Grafana)
- [ ] Documentar lições aprendidas
- [ ] Celebrar! 🎉

### Se FALHA (Timeouts persistem):
- [ ] Analisar logs detalhados em /tmp/validation-*/
- [ ] Verificar se todas as implementações foram aplicadas corretamente
- [ ] Consultar /docs/research/morning-timeout-analysis.md
- [ ] Revisar hipótese 4 (Infraestrutura Locaweb - 20%)
- [ ] Abrir ticket com Locaweb se necessário
- [ ] Consultar /docs/analysis/diagnostic-framework.md

---

## 📞 CONTATOS DE EMERGÊNCIA

**Locaweb Suporte:** ____________________
**DBA:** ____________________
**DevOps:** ____________________
**Gerente:** ____________________

---

## ✍️ ASSINATURAS

**Executado por:** __________________________
**Revisado por:** __________________________
**Data:** ____/____/______

---

**Preparado por:** Hive Mind Collective Intelligence
**Projeto:** VPS Timeout Troubleshooting
**Data de criação:** 2025-10-22
**Versão:** 1.0 Printable

---

**💡 INSTRUÇÕES DE USO:**
1. Imprima este documento antes do dia de validação
2. Use caneta para marcar checkboxes durante monitoramento
3. Anote métricas nos campos indicados
4. Anexe ao relatório final como evidência física
5. Arquive com as evidências digitais coletadas
