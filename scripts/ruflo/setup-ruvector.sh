#!/usr/bin/env bash
# RuVector Vector Store Setup - PostgreSQL + HNSW + Multi-host Sync
# Uso: ./scripts/ruflo/setup-ruvector.sh [--remote fgsrv06]
# Deps: PostgreSQL 15+ com pgvector, psql, npx

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="$REPO_ROOT/config/ruflo"
RUVECTOR_ENV="$CONFIG_DIR/ruvector.env"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Remote host (opcional)
REMOTE_HOST="${1:-}"
REMOTE_HOST="${REMOTE_HOST#--remote}"

# Carregar configuração
if [[ -f "$RUVECTOR_ENV" ]]; then
  set -a
  source "$RUVECTOR_ENV"
  set +a
fi

# Defaults
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-ruflo}"
DB_USER="${DB_USER:-ruflo}"
DB_PASSWORD="${DB_PASSWORD:-}"

RUVECTOR_HNSW_M="${RUVECTOR_HNSW_M:-16}"
RUVECTOR_HNSW_EF_CONSTRUCTION="${RUVECTOR_HNSW_EF_CONSTRUCTION:-64}"
RUVECTOR_EMBEDDING_DIM="${RUVECTOR_EMBEDDING_DIM:-1536}"
RUVECTOR_DEFAULT_TTL="${RUVECTOR_DEFAULT_TTL:-604800}"
RUVECTOR_NAMESPACES="${RUVECTOR_NAMESPACES:-agents,patterns,infrastructure,docs}"

RUVECTOR_PRIMARY_HOST="${RUVECTOR_PRIMARY_HOST:-agldv03}"
RUVECTOR_REPLICA_HOSTS="${RUVECTOR_REPLICA_HOSTS:-fgsrv06}"
RUVECTOR_SYNC_PORT="${RUVECTOR_SYNC_PORT:-9889}"

# Executar comando (local ou remoto)
run_cmd() {
  if [[ -n "$REMOTE_HOST" ]]; then
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$REMOTE_HOST" "$*"
  else
    "$@"
  fi
}

run_sql() {
  local sql="$1"
  if [[ -n "$REMOTE_HOST" ]]; then
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$REMOTE_HOST" \
      "PGPASSWORD='$DB_PASSWORD' psql -h '$DB_HOST' -p '$DB_PORT' -U '$DB_USER' -d '$DB_NAME' -c \"$sql\""
  else
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "$sql"
  fi
}

run_sql_file() {
  local sql="$1"
  if [[ -n "$REMOTE_HOST" ]]; then
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$REMOTE_HOST" \
      "PGPASSWORD='$DB_PASSWORD' psql -h '$DB_HOST' -p '$DB_PORT' -U '$DB_USER' -d '$DB_NAME'" <<< "$sql"
  else
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<< "$sql"
  fi
}

echo "========================================"
echo "  RuVector Vector Store Setup"
echo "========================================"
echo "Host: ${REMOTE_HOST:-local}"
echo "PostgreSQL: $DB_HOST:$DB_PORT/$DB_NAME"
echo "HNSW: M=$RUVECTOR_HNSW_M, ef_construction=$RUVECTOR_HNSW_EF_CONSTRUCTION"
echo "Embedding Dim: $RUVECTOR_EMBEDDING_DIM"
echo "TTL Padrão: ${RUVECTOR_DEFAULT_TTL}s ($(python3 -c "print($RUVECTOR_DEFAULT_TTL / 86400)" 2>/dev/null || echo "7") dias)"
echo "Namespaces: $RUVECTOR_NAMESPACES"
echo "Sync: $RUVECTOR_PRIMARY_HOST <-> $RUVECTOR_REPLICA_HOSTS"
echo ""

# ============================================
# 1. Verificar PostgreSQL disponível
# ============================================
log_info "1. Verificando PostgreSQL..."

# Verificar psql
if ! run_cmd which psql &>/dev/null; then
  log_error "psql não encontrado. Instale: apt install postgresql-client"
  exit 1
fi

# Testar conexão
if run_sql "SELECT 1" &>/dev/null; then
  log_ok "PostgreSQL conectado em $DB_HOST:$DB_PORT/$DB_NAME"
else
  log_error "Falha ao conectar PostgreSQL"
  log_info "Verifique: DB_HOST, DB_PORT, DB_USER, DB_PASSWORD"
  exit 1
fi

# Verificar versão
PG_VERSION=$(run_sql "SELECT setting FROM pg_settings WHERE name = 'server_version'" -t 2>/dev/null | tr -d ' ')
log_ok "PostgreSQL versão: $PG_VERSION"

# ============================================
# 2. Verificar/instalar extensão pgvector
# ============================================
log_info "2. Verificando pgvector..."

if run_sql "SELECT * FROM pg_extension WHERE extname = 'vector'" -t 2>/dev/null | grep -q "vector"; then
  log_ok "pgvector já instalado"
else
  log_warn "pgvector não encontrado. Tentando instalar..."

  if run_sql "CREATE EXTENSION IF NOT EXISTS vector" 2>/dev/null; then
    log_ok "pgvector instalado com sucesso"
  else
    log_error "Falha ao instalar pgvector"
    log_info "Instale no servidor: apt install postgresql-15-pgvector (ou versão correspondente)"
    exit 1
  fi
fi

# ============================================
# 3. Criar tabelas vetoriais
# ============================================
log_info "3. Criando tabelas vetoriais..."

SQL_SCHEMA=$(cat <<'EOSQL'
-- Schema ruvector
CREATE SCHEMA IF NOT EXISTS ruvector;

-- Tabela principal de embeddings
CREATE TABLE IF NOT EXISTS ruvector.embeddings (
  id BIGSERIAL PRIMARY KEY,
  namespace VARCHAR(64) NOT NULL,
  key VARCHAR(512) NOT NULL,
  embedding vector({DIM}),
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  UNIQUE(namespace, key)
);

-- Tabela de sync state
CREATE TABLE IF NOT EXISTS ruvector.sync_state (
  id SERIAL PRIMARY KEY,
  host VARCHAR(64) NOT NULL UNIQUE,
  last_sync_seq BIGINT DEFAULT 0,
  last_sync_at TIMESTAMPTZ,
  status VARCHAR(16) DEFAULT 'idle'
);

-- Tabela de changelog para replicação
CREATE TABLE IF NOT EXISTS ruvector.changelog (
  id BIGSERIAL PRIMARY KEY,
  operation VARCHAR(8) NOT NULL,
  namespace VARCHAR(64) NOT NULL,
  key VARCHAR(512) NOT NULL,
  embedding vector({DIM}),
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  synced BOOLEAN DEFAULT FALSE
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_embeddings_namespace ON ruvector.embeddings(namespace);
CREATE INDEX IF NOT EXISTS idx_embeddings_expires ON ruvector.embeddings(expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_changelog_created ON ruvector.changelog(created_at);
CREATE INDEX IF NOT EXISTS idx_changelog_synced ON ruvector.changelog(synced) WHERE NOT synced;

-- Índice HNSW para busca vetorial
CREATE INDEX IF NOT EXISTS idx_embeddings_vector ON ruvector.embeddings
  USING hnsw (embedding vector_cosine_ops)
  WITH (m = {M}, ef_construction = {EF});

-- Trigger para updated_at
CREATE OR REPLACE FUNCTION ruvector.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_embeddings_updated ON ruvector.embeddings;
CREATE TRIGGER trg_embeddings_updated
  BEFORE UPDATE ON ruvector.embeddings
  FOR EACH ROW EXECUTE FUNCTION ruvector.update_updated_at();

-- Trigger para changelog
CREATE OR REPLACE FUNCTION ruvector.log_changes()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO ruvector.changelog (operation, namespace, key, embedding, metadata)
    VALUES ('INSERT', NEW.namespace, NEW.key, NEW.embedding, NEW.metadata);
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO ruvector.changelog (operation, namespace, key, embedding, metadata)
    VALUES ('UPDATE', NEW.namespace, NEW.key, NEW.embedding, NEW.metadata);
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO ruvector.changelog (operation, namespace, key)
    VALUES ('DELETE', OLD.namespace, OLD.key);
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_embeddings_changes ON ruvector.embeddings;
CREATE TRIGGER trg_embeddings_changes
  AFTER INSERT OR UPDATE OR DELETE ON ruvector.embeddings
  FOR EACH ROW EXECUTE FUNCTION ruvector.log_changes();

-- Função de limpeza de expirados
CREATE OR REPLACE FUNCTION ruvector.cleanup_expired()
RETURNS void AS $$
BEGIN
  DELETE FROM ruvector.embeddings WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Função de busca HNSW
CREATE OR REPLACE FUNCTION ruvector.search(
  query_embedding vector({DIM}),
  search_namespace VARCHAR(64),
  limit_count INTEGER DEFAULT 10,
  ef_search INTEGER DEFAULT 64
)
RETURNS TABLE (
  key VARCHAR(512),
  embedding vector({DIM}),
  metadata JSONB,
  similarity FLOAT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    e.key,
    e.embedding,
    e.metadata,
    1 - (e.embedding <=> query_embedding) AS similarity
  FROM ruvector.embeddings e
  WHERE e.namespace = search_namespace
    AND (e.expires_at IS NULL OR e.expires_at > NOW())
  ORDER BY e.embedding <=> query_embedding
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT ALL ON SCHEMA ruvector TO {USER};
GRANT ALL ON ALL TABLES IN SCHEMA ruvector TO {USER};
GRANT ALL ON ALL SEQUENCES IN SCHEMA ruvector TO {USER};
EOSQL
)

# Substituir variáveis
SQL_SCHEMA="${SQL_SCHEMA//\{DIM\}/$RUVECTOR_EMBEDDING_DIM}"
SQL_SCHEMA="${SQL_SCHEMA//\{M\}/$RUVECTOR_HNSW_M}"
SQL_SCHEMA="${SQL_SCHEMA//\{EF\}/$RUVECTOR_HNSW_EF_CONSTRUCTION}"
SQL_SCHEMA="${SQL_SCHEMA//\{USER\}/$DB_USER}"

if run_sql_file "$SQL_SCHEMA" 2>&1 | grep -i "error" | head -5; then
  log_error "Erro ao criar tabelas"
  exit 1
else
  log_ok "Tabelas vetoriais criadas/verificadas"
fi

# Criar namespaces
log_info "Criando namespaces..."
IFS=',' read -ra NS <<< "$RUVECTOR_NAMESPACES"
for ns in "${NS[@]}"; do
  ns=$(echo "$ns" | xargs)  # trim
  run_sql "INSERT INTO ruvector.embeddings (namespace, key, embedding) VALUES ('$ns', '__init__', ARRAY_FILL(0.0::float8, ARRAY[$RUVECTOR_EMBEDDING_DIM])) ON CONFLICT DO NOTHING" 2>/dev/null || true
done
log_ok "Namespaces: ${RUVECTOR_NAMESPACES}"

# ============================================
# 4. Configurar replicação entre hosts
# ============================================
log_info "4. Configurando replicação multi-host..."

# Registrar hosts
PRIMARY_IP=$(getent hosts "$RUVECTOR_PRIMARY_HOST" 2>/dev/null | awk '{print $1}' | head -1)
if [[ -z "$PRIMARY_IP" ]]; then
  PRIMARY_IP="100.94.221.87"  # agldv03 Tailscale fallback
fi

run_sql "INSERT INTO ruvector.sync_state (host, status) VALUES ('$RUVECTOR_PRIMARY_HOST', 'primary') ON CONFLICT (host) DO UPDATE SET status = 'primary'"

IFS=',' read -ra REPLICAS <<< "$RUVECTOR_REPLICA_HOSTS"
for replica in "${REPLICAS[@]}"; do
  replica=$(echo "$replica" | xargs)
  run_sql "INSERT INTO ruvector.sync_state (host, status) VALUES ('$replica', 'replica') ON CONFLICT (host) DO UPDATE SET status = 'replica'"
done

log_ok "Hosts registrados: $RUVECTOR_PRIMARY_HOST (primary), $RUVECTOR_REPLICA_HOSTS (replicas)"

# Criar script de sync
SYNC_SCRIPT="$HOME/.ruflo/ruvector-sync.sh"
cat > "$SYNC_SCRIPT" << 'EOSYNC'
#!/usr/bin/env bash
# RuVector Sync Script - Executado via cron ou systemd timer
set -euo pipefail

source ~/.ruflo/ruvector.env 2>/dev/null || true

PRIMARY="${RUVECTOR_PRIMARY_HOST:-agldv03}"
REPLICAS="${RUVECTOR_REPLICA_HOSTS:-fgsrv06}"
SYNC_PORT="${RUVECTOR_SYNC_PORT:-9889}"

for replica in ${REPLICAS//,/ }; do
  echo "Syncing to $replica..."

  # Buscar changelog não sincronizado
  PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -F'|' \
    -c "SELECT id, operation, namespace, key, encode(embedding::text::bytea, 'base64'), metadata FROM ruvector.changelog WHERE NOT synced ORDER BY id LIMIT 100" | \
  while IFS='|' read -r id op ns key emb meta; do
    # Enviar para replica via HTTP API ou SSH
    curl -s -X POST "http://${replica}:${SYNC_PORT}/vectors" \
      -H "Content-Type: application/json" \
      -d "{\"namespace\":\"$ns\",\"key\":\"$key\",\"embedding\":\"$emb\",\"metadata\":$meta}" 2>/dev/null || \
    ssh "$replica" "PGPASSWORD='$DB_PASSWORD' psql -h '$DB_HOST' -p '$DB_PORT' -U '$DB_USER' -d '$DB_NAME' -c \"UPDATE ruvector.embeddings SET embedding='$emb'::vector, metadata='$meta'::jsonb WHERE namespace='$ns' AND key='$key'\"" 2>/dev/null || true

    # Marcar como sincronizado
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
      -c "UPDATE ruvector.changelog SET synced = true WHERE id = $id" 2>/dev/null || true
  done

  echo "Sync to $replica complete"
done
EOSYNC

chmod +x "$SYNC_SCRIPT"
log_ok "Script de sync criado: $SYNC_SCRIPT"

# ============================================
# 5. Validar conectividade
# ============================================
log_info "5. Validando conectividade..."

# Testar funções
if run_sql "SELECT ruvector.search(ARRAY_FILL(0.0::float8, ARRAY[$RUVECTOR_EMBEDDING_DIM]), 'agents', 1)" &>/dev/null; then
  log_ok "Função de busca HNSW operacional"
else
  log_warn "Função de busca pode precisar de dados"
fi

# Testar sync_state
SYNC_COUNT=$(run_sql "SELECT COUNT(*) FROM ruvector.sync_state" -t 2>/dev/null | tr -d ' ')
log_ok "Sync state: $SYNC_COUNT hosts registrados"

# Testar conectividade com replicas
IFS=',' read -ra REPLICAS <<< "$RUVECTOR_REPLICA_HOSTS"
for replica in "${REPLICAS[@]}"; do
  replica=$(echo "$replica" | xargs)
  if ping -c 1 -W 2 "$replica" &>/dev/null; then
    log_ok "Replica $replica: alcançável"
  else
    log_warn "Replica $replica: não alcançável (verifique rede/VPN)"
  fi
done

# ============================================
# 6. Resumo
# ============================================
echo ""
echo "========================================"
echo "  Setup Completo"
echo "========================================"
echo "PostgreSQL: $DB_HOST:$DB_PORT/$DB_NAME"
echo "Extensão: pgvector ativo"
echo "HNSW Index: M=$RUVECTOR_HNSW_M, ef_construction=$RUVECTOR_HNSW_EF_CONSTRUCTION"
echo "Embedding Dim: $RUVECTOR_EMBEDDING_DIM"
echo "Namespaces: $RUVECTOR_NAMESPACES"
echo "TTL Padrão: ${RUVECTOR_DEFAULT_TTL}s"
echo ""
echo "Sync Config:"
echo "  Primary: $RUVECTOR_PRIMARY_HOST"
echo "  Replicas: $RUVECTOR_REPLICA_HOSTS"
echo "  Sync Port: $RUVECTOR_SYNC_PORT"
echo "  Script: $SYNC_SCRIPT"
echo ""
echo "Próximos passos:"
echo "  1. Configure cron para sync: */5 * * * * $SYNC_SCRIPT"
echo "  2. Execute em replicas: ./setup-ruvector.sh --remote fgsrv06"
echo "  3. Teste busca: SELECT * FROM ruvector.search(array[...], 'agents', 5);"
echo ""
