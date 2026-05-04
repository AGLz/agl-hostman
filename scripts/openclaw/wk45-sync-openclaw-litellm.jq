# Uso (Git Bash / Linux):
#   export LITELLM_MASTER_KEY="$(ssh root@100.94.221.87 'grep ^LITELLM_MASTER_KEY= /opt/litellm/.env | cut -d= -f2-')"
#   export LITELLM_PROXY_BASE_URL="${LITELLM_PROXY_BASE_URL:-http://100.125.249.8:4000}"
#   jq --arg k "$LITELLM_MASTER_KEY" --arg url "$LITELLM_PROXY_BASE_URL" \
#      -f wk45-sync-openclaw-litellm.jq ~/.openclaw/openclaw.json > /tmp/oc.json && mv /tmp/oc.json ~/.openclaw/openclaw.json
#
# Reason: apiKey "sk-litellm-default" → 401 se LITELLM_MASTER_KEY no agldv03 for outra; localhost:4000 → URL do gateway.

walk(
  if type == "object" then
    (if .apiKey == "sk-litellm-default" then .apiKey = $k else . end
     | if (.baseUrl? | type == "string") and (.baseUrl | test("localhost:4000|127\\.0\\.0\\.1:4000|192\\.168\\.0\\.179:4000")) then .baseUrl = $url else . end)
  else . end
)
