# wk45 / clientes Windows sem LiteLLM local: alinhar openclaw.json ao proxy agldv03.
#
# Uso: ver scripts/openclaw/wk45-sync-openclaw-litellm.sh
#   jq --arg k "$LITELLM_MASTER_KEY" --arg url "$LITELLM_PROXY_BASE_URL" \
#      -f wk45-sync-openclaw-litellm.jq ~/.openclaw/openclaw.json > /tmp/oc.json && mv /tmp/oc.json ~/.openclaw/openclaw.json
#
# Reason: apiKey "sk-litellm-default" → 401 se LITELLM_MASTER_KEY no agldv03 for outra;
# localhost:4000 na VM sem proxy local → usar URL Tailscale/LAN do agldv03.

walk(
  if type == "object" then
    (if .apiKey == "sk-litellm-default" then .apiKey = $k else . end)
    | (if (.baseUrl? | type == "string") and (.baseUrl | test("localhost:4000|127\\.0\\.0\\.1:4000"))
       then .baseUrl = $url
       else . end)
  else . end
)
