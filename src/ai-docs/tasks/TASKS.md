# Tasks - AGL Infrastructure Admin

## 📊 Sprint Atual: Sprint 1 (Fundação)

### 🔄 Em Progresso
*No tasks in progress*

## ✅ Concluído
- [x] **TASK-INFRA-LITELLM-OPENCLAW-LXC-186-187**: LXC dedicados AGLSRV1 — CT186 LiteLLM + CT187 OpenClaw (VMIDs 186/187; 150/151 reservados a QEMU); composes `docker-compose.ct186/ct187.yml`; bootstraps + wrappers 150/151; `pct-create` com `fuse`/`mknod`; runbook `docs/LITELLM-OPENCLAW-DEDICATED-LXC.md` (GPU/espelho CT185, AppArmor `unconfined`, healthz 18789 vs 28789); teste Node `dedicated-lxc-compose-files`; `jarvis-openclaw-http-endpoints.example.json` → `cutoverDedicatedLxc` + linha na tabela em `ops/runbooks/jarvis-operations.md` (2026-05-01)
- [x] **TASK-INFRA-MYSQL-HA-OPS-2026-04**: HA MariaDB — topologia CT235 master / CT135 slave no `README` + `PROXMOX-CLUSTER-AGLSRV5-FGSRV7.md` + `docs/maint/MYSQL-HA-POST-RESET-2026-04.md`; `mysql-failover.sh` alinhado (DNS pós-promoção → túnel AGLSRV5); template `mysql-failover.conf` para CT135; `install-failover-on-ct135.sh`; `setup-failover.sh` sed `MASTER_MYSQL_IP`/`CF_API_KEY`; redacção de passwords em troubleshooting CT135 e PRD (2026-04-29)
- [x] **TASK-INFRA-CT179-OPENCLAW-VERIFY**: OpenClaw CT179 — script `scripts/openclaw/verify-ct179-openclaw-infra-access.sh` em LF (CRLF quebrava o bash no contentor); verificação de pré-requisitos (Tailscale, wg0, LAN/SSH, LiteLLM, processo) documentada em `ops/runbooks/jarvis-operations.md` com nota CRLF + `.gitattributes` `*.sh` (2026-04-27)
- [x] **TASK-INFRA-LITELLM-OLLAMA-NEMOTRON-ONLY**: LiteLLM — Ollama só no CT200 (AGLSRV1); `config/litellm/config.yaml`: um modelo Ollama (`ollama/nemotron-3-nano:4b`), `agl-primary` alinhado a Nemotron; removidos aliases Qwen3/DeepSeek Ollama e entradas OpenRouter `or-qwen3-coder-free` / `or-step-3.5-free`; fallbacks corrigidos (`or-nemotron-super-free`, `or-minimax-m2.5-free`, `or-llama-3.3-70b-free`, sem `or-step-free`). `config-remote.yaml` e testes `litellm-ollama-ct200-entries` atualizados (2026-04-19)
- [x] **TASK-INFRA-OLLAMA-CT200-QWEN3-4B-ONLY**: CT200 + LiteLLM — apenas `qwen3:4b` no disco (`ollama rm` dos restantes, incl. cloud); override `OLLAMA_MAX_LOADED_MODELS=1` / `OLLAMA_NUM_PARALLEL=1`; `config/litellm/config.yaml` + `config-remote.yaml` só `ollama/qwen3:4b` e aliases `ollama-qwen3-4b`; deploy em CT186 (`/opt/agl-litellm/config.yaml`); warm no boot só Qwen; testes `litellm-ollama-ct200-entries` + `litellm-smoke-test-remote.sh` (2026-05-11)
- [x] **TASK-INFRA-OLLAMA-CLOUD-LITELLM-CT200**: *(histórico 2026-05-09 — revertido)* CT200 chegou a ter 7 modelos Ollama Cloud + overrides alargados; consolidado em **TASK-INFRA-OLLAMA-CT200-QWEN3-4B-ONLY**.
- [x] **TASK-INFRA-CT200-OLLAMA-WARM-BOOT**: CT200 — `ollama-warm-cloud.service` (oneshot, `After=ollama.service`, sleep 15s, `ExecStart=/usr/local/sbin/warm-ollama-cloud-models.sh`), `enabled` em `multi-user.target`; instalação via `install-ct200-ollama-warm-boot.sh` no AGLSRV1 (`pct 200`) (2026-05-11)
- [x] **TASK-INFRA-LITELLM-SCRIPTS-MASTER-KEY**: Scripts `scripts/litellm/*` passam a usar `_litellm-master-key.sh` (env → `.env` → `docker exec`); `curl` sem `Authorization` se chave vazia; `config/litellm/.env.example` com `LITELLM_MASTER_KEY`. Docs em `LITELLM-MULTI-HOST-DEPLOYMENT.md` (2026-04-19)
- [x] **TASK-INFRA-LITELLM-AGL-PRIMARY-QWEN3**: (substituído por TASK-INFRA-LITELLM-OLLAMA-NEMOTRON-ONLY) — histórico: `agl-primary` chegou a usar `ollama/qwen3:4b` antes da consolidação Nemotron-only
- [x] **TASK-INFRA-CT200-GPU-509**: CT200 Ollama GPU — adicionado `lxc.cgroup2.devices.allow: c 509:* rwm` (nvidia-uvm), override `OLLAMA_LLM_LIBRARY=cuda_v12`; CUDA detetada, `ollama ps` 100% GPU (2026-04-19)
- [x] **TASK-INFRA-DOCS-CT200**: Documentação e scripts alinhados CT200 `ollama-gpu` → `ollama` + Portainer `ollama2` → `ollama` (2026-03-31)
- [x] **TASK-001**: Research Laravel 12 best practices - DONE
- [x] **TASK-002**: Research N8N integration patterns - DONE
- [x] **TASK-003**: Backup existing src folder - DONE
- [x] **TASK-004**: Initialize Laravel 12 project - DONE
- [x] **TASK-005**: Setup Docker configuration - DONE
- [x] **TASK-006**: Configure multi-database (MySQL + Redis) - DONE ✅
  - Status: COMPLETED
  - Assignee: Claude
  - Priority: HIGH
  - Tests: 3/3 PASSED

### 📋 Backlog Sprint
- [x] **TASK-007**: Setup authentication with WorkOS - DONE ✅
  - Status: COMPLETED
  - Assignee: Claude
  - Priority: HIGH
  - Implementation: OAuth2 flow complete
- [x] **TASK-008**: Create role-based access control system - DONE ✅
  - Status: COMPLETED
  - Assignee: Claude
  - Priority: HIGH
  - Implementation: Full RBAC with Spatie Laravel Permission
  - Files: 15+ created (models, controllers, views, tests, seeder)
- [x] **TASK-009**: Design shadcn UI dashboard - DONE ✅
  - Status: COMPLETED
  - Assignee: Gemini
  - Implementation: Premium dashboard with Sidebar, glassmorphism, and framer-motion animations. Integrated Shadcn UI components and WorkOS auth info.

### ✅ Concluído
- [x] **TASK-001**: Research Laravel 12 best practices - DONE
- [x] **TASK-002**: Research N8N integration patterns - DONE
- [x] **TASK-003**: Backup existing src folder - DONE
- [x] **TASK-004**: Initialize Laravel 12 project - DONE
- [x] **TASK-005**: Setup Docker configuration - DONE

## 📈 Sprint 2 (Integração) - COMPLETED ✅
- [x] **TASK-010**: Setup N8N integration - DONE ✅
  - Status: COMPLETED
  - Assignee: Claude (Hive Mind)
  - Implementation: N8NService with retry logic, circuit breaker, webhook handling, N8NController with 14 API endpoints, N8NWorkflow models
- [x] **TASK-011**: Configure AI models integration - DONE ✅
  - Status: COMPLETED
  - Assignee: Claude (Hive Mind)
  - Implementation: AIService with OpenAI/Claude/Ollama support, AIController with prediction/analysis/chat endpoints, AIModelUsage tracking
- [x] **TASK-012**: Setup monitoring system - DONE ✅
  - Status: COMPLETED
  - Assignee: Claude (Hive Mind)
  - Implementation: MonitoringService with metrics collection and alert generation, MonitoringController with 10 API endpoints, CollectMetricsCommand

## 🚀 Sprint 3 (Automação & Monitoramento) - COMPLETED ✅
- [x] **TASK-013**: Configure Harbor and Dokploy - DONE ✅
  - Status: COMPLETED
  - Assignee: Claude (Hive Mind)
  - Implementation: HarborService with 13 API endpoints, HarborProject/Repository models, DokployController with 15+ endpoints, vulnerability scanning
- [x] **TASK-014**: Create queue and job system - DONE ✅
  - Status: COMPLETED
  - Assignee: Claude (Hive Mind)
  - Implementation: 7 job classes, Laravel Horizon integration, 3 queue management commands, QueueMonitoringService
- [x] **TASK-015**: Implement Scrum board - DONE ✅
  - Status: COMPLETED
  - Assignee: Claude (Hive Mind)
  - Implementation: ScrumController with 25+ endpoints, Story/Bug/SprintMember models, burndown/velocity reports, kanban board
- [x] **TASK-016**: Setup CI/CD pipeline - DONE ✅
  - Status: COMPLETED
  - Assignee: Claude (Hive Mind)
  - Implementation: 5 GitHub Actions workflows, deployment scripts, blue-green deployments, DeploymentService

## 🔥 Sprint 4 (Produção & Escalabilidade)
- [ ] **TASK-017**: Create API documentation
- [ ] **TASK-018**: Implement real-time notifications
- [ ] **TASK-019**: Setup automated testing
- [ ] **TASK-020**: Configure backup system

## 📊 Métricas Sprint 3
- **Velocity**: 16 story points
- **Burndown**: Ahead of schedule
- **Blockers**: None
- **Progress**: 100% (4/4 tasks completed)
- **Recent Wins**: Sprint 3 completed with Harbor, Queues, Scrum board, and CI/CD ✅

## 📊 Métricas Gerais (Sprint 1 + 2 + 3)
- **Total Tasks Completed**: 19/19
- **Overall Progress**: 100% of Sprint 1 + 2 + 3 tasks
- **Commits**: 6 major feature commits
- **Test Coverage**: Comprehensive test factories added
- **Integrations**: N8N, AI (OpenAI/Claude/Ollama), Harbor, Dokploy, Horizon, GitHub Actions

## 🚀 Definition of Done
1. Código implementado e testado
2. Documentação atualizada
3. Code review aprovado
4. Testes passando (>80% coverage)
5. Deployed em ambiente de desenvolvimento