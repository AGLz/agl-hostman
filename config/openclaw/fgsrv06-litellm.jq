# fgsrv06 (ou qualquer host com LiteLLM em localhost:4000):
# substituir apenas baseUrl que apontam ao gateway central agldv03 — preserva o resto do objeto (ex.: moonshot.models).
#
# Uso: jq -f config/openclaw/fgsrv06-litellm.jq ~/.openclaw/openclaw.json > /tmp/oc.json && mv /tmp/oc.json ~/.openclaw/openclaw.json
# Depois: systemctl --user restart openclaw-gateway
walk(
  if type == "object" and (.baseUrl? | type == "string") and (.baseUrl | contains("100.94.221.87:4000"))
  then .baseUrl = "http://127.0.0.1:4000"
  else .
  end
)
