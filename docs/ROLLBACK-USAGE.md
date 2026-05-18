# Deployment Rollback — Guia de Uso

> **Branch:** `chore/phase3-frente-c-rollback`  
> **Implementado em:** 2026-05-18 (Fase 3 — Frente C)  
> **Arquivos principais:**
> - `src/app/Services/Deployment/DeploymentWorkflowService.php` — `rollback()` + `rollbackUAT()`
> - `src/app/Console/Commands/RollbackDeployment.php` — artisan command
> - `src/config/deployment.php` — configuração de rollback
> - `src/tests/Feature/Services/DeploymentRollbackTest.php` — 8 testes Pest

---

## O que faz o rollback

O rollback reverte um deployment falhado re-deployando a **imagem Docker anterior** que está no Harbor (`harbor.aglz.io`). A estratégia utilizada é **previous-image-tag**: encontra o deployment bem-sucedido mais recente para a mesma aplicação e chama `DokployService::deployApplication()` com esse ID.

### O que o rollback NÃO faz

> **Atenção:** O rollback **NÃO reverte migrations de base de dados.** Se o deployment incluiu alterações de schema, a imagem anterior vai correr com o schema novo. Garante que as migrations são backward-compatible antes de deployar.

---

## Fluxo automático (QA e UAT)

Quando um deployment falha e `DEPLOYMENT_ROLLBACK_ON_FAILURE=true` (default), o rollback automático é acionado:

```
deployToQA() → falha → rollback('Automatic rollback after QA deployment failure')
deployToUAT() → falha → rollbackUAT() → rollback('Automatic rollback from failed UAT deployment')
```

O rollback automático não propaga excepções — se ele também falhar, fica registado em log e a excepção original do deployment é relançada.

---

## Uso manual via artisan

### Rollback por ID de deployment

```bash
# Rollback de um deployment específico
php artisan deployment:rollback-deployment <deployment-id>

# Com razão explícita (fica no audit log)
php artisan deployment:rollback-deployment 42 --reason="Versão bugada reportada por QA"
```

### Rollback do último deployment falhado de um ambiente

```bash
# Rollback do último falhado em QA
php artisan deployment:rollback-deployment --latest --env=qa

# Rollback do último falhado em UAT com razão
php artisan deployment:rollback-deployment --latest --env=uat --reason="Regressão de performance"
```

### Dry-run (sem executar)

```bash
# Ver o que seria feito sem alterar nada
php artisan deployment:rollback-deployment 42 --dry-run
php artisan deployment:rollback-deployment --latest --env=qa --dry-run
```

Saída do dry-run:
```
[DRY-RUN] Rolling back deployment #42
DRY-RUN: Rollback would restore:
+--------------+----------------------------+
| Field        | Value                      |
+--------------+----------------------------+
| Deployment ID| 38                         |
| Tag          | qa-abc1234                 |
| Commit       | abc1234def5678901234567890 |
| Completed at | 2026-05-18 10:32:15        |
+--------------+----------------------------+
DRY-RUN: No changes made.
```

---

## Uso programático (PHP)

```php
use App\Services\Deployment\DeploymentWorkflowService;

$service = app(DeploymentWorkflowService::class);

// Rollback genérico (qualquer environment)
$result = $service->rollback($deploymentId, 'Motivo do rollback');

// Rollback específico para UAT (delega para rollback() com razão padrão)
$result = $service->rollbackUAT($deploymentId);

// Verificar resultado
if ($result['success']) {
    echo "Rollback para deployment #{$result['rolled_back_to_deployment']}";
    echo "Tag: {$result['rolled_back_to_tag']}";
    echo "Commit: {$result['rolled_back_to_commit']}";
    echo "Novo registro de audit: #{$result['rollback_deployment_id']}";
} else {
    echo "Rollback falhou: {$result['error']}";
}
```

---

## Audit trail

Cada rollback cria um novo registo `DokployDeployment` com:

| Campo | Valor |
|-------|-------|
| `status` | `'rollback'` |
| `triggered_by` | `'rollback'` |
| `tag` | tag da versão para a qual se voltou |
| `commit_hash` | commit hash da versão alvo |
| `metadata.rollback_from_deployment_id` | ID do deployment falhado |
| `metadata.rollback_to_deployment_id` | ID do deployment de destino |
| `metadata.span_deployments` | Quantos deployments foram "saltados" |

### Consultar rollbacks via Eloquent

```php
// Todos os rollbacks
DokployDeployment::rollback()->orderBy('created_at', 'desc')->get();

// Rollbacks por aplicação
DokployDeployment::rollback()
    ->where('application_id', $appId)
    ->with('application')
    ->get();
```

---

## Configuração

Variáveis de ambiente em `src/.env` (ou `config/deployment.php`):

| Variável | Default | Descrição |
|----------|---------|-----------|
| `DEPLOYMENT_ROLLBACK_ON_FAILURE` | `true` | Ativa rollback automático em falhas QA/UAT |
| `DOKPLOY_ROLLBACK_ENABLED` | `true` | Master switch — desativa todos os rollbacks se `false` |
| `DOKPLOY_MAX_ROLLBACK_SPAN` | `5` | Warning quando rollback salta mais de N deployments |

---

## Proteções e limitações

| Proteção | Comportamento |
|----------|--------------|
| **Sem deployment anterior** | Retorna `['success' => false, 'error' => 'No previous successful deployment found...']` |
| **Rollback desactivado** | Artisan command rejeita com `exit(1)` se `DOKPLOY_ROLLBACK_ENABLED=false` |
| **Span > max_rollback_span** | Log `warning` mas prossegue (não bloqueia) |
| **Falha Dokploy API** | Captura excepção, retorna `['success' => false, 'error' => '...']` |
| **Rollback automático falha** | Não propaga excepção — regista `Log::error`, deployment original lança a excepção |

---

## Pré-requisitos Harbor

Para que o rollback funcione, o Harbor (`harbor.aglz.io`) deve manter as imagens anteriores. Verificar política de retenção:

```bash
# Verificar se a imagem alvo ainda existe
docker manifest inspect harbor.aglz.io/agl/hostman:qa-abc1234

# Listar imagens disponíveis via Harbor API
curl -u admin:PASSWORD https://harbor.aglz.io/api/v2.0/projects/agl/repositories/hostman/artifacts
```

**Recomendação:** Política de retenção mínima de 10 imagens por repositório.

---

## Verificação pós-rollback

```bash
# Health check
curl -f https://qa-agl.aglz.io/api/health
curl -f https://uat-agl.aglz.io/api/health

# Verificar versão (se endpoint disponível)
curl https://qa-agl.aglz.io/api/version
```

---

## Testes

```bash
# Executar apenas os testes de rollback
cd src/
vendor/bin/pest tests/Feature/Services/DeploymentRollbackTest.php --no-coverage

# Executar todos os testes de Feature
vendor/bin/pest tests/Feature/ --no-coverage
```

**Cobertura dos testes:**

| Cenário | Teste |
|---------|-------|
| Rollback bem-sucedido com deployment anterior | `it finds the previous successful deployment` |
| Sem deployment anterior | `it returns success=false when no previous...` |
| Cria registo de audit com status rollback | `it creates a rollback deployment record` |
| Escolhe o deployment mais recente | `it picks the most recent successful deployment` |
| Falha do Dokploy tratada graciosamente | `it handles dokploy service failure gracefully` |
| `rollbackUAT()` delega para `rollback()` | `it rollbackUAT() delegates to the generic rollback` |
| Warning de span > max | `it logs a warning when rollback spans...` |
| `scopeRollback()` no model | `it filters deployments with status rollback` |
