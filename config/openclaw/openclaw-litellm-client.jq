# Satélites OpenClaw sem LiteLLM local: apontar providers ao gateway central CT186.
# Uso: jq -f config/openclaw/openclaw-litellm-client.jq openclaw.json
# Aplicar após copiar ~/.openclaw/openclaw.json desde agldv03 (origem com localhost:4000).
walk(
  if type == "object" and (.baseUrl? | type == "string") and (.baseUrl | test("localhost:4000|127\\.0\\.0\\.1:4000|192\\.168\\.0\\.179:4000"))
  then .baseUrl = "http://100.125.249.8:4000"
  else .
  end
)
