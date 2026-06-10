# Proxy legado Archon v0.4 (porta 3737)

Workaround enquanto o ingress **remoto** do túnel Cloudflare `aglsrv1b` (CT117) aponta `archon.aglz.io` para `:3737`.

## Ficheiros

| Ficheiro | Destino no CT183 |
|----------|------------------|
| `nginx-archon-v04-proxy.conf` | `/opt/archon/proxy/` |
| `manage-legacy-proxy.sh` | `/opt/archon/proxy/` |
| `archon-v04-proxy.service` | `/etc/systemd/system/` |

## Instalação

```bash
# No CT183 (copiar patches/archon/proxy/ para o CT primeiro, ou usar repo montado)
bash /opt/archon/proxy/install-on-ct183.sh
# ou manualmente:
systemctl enable --now archon-v04-proxy.service
curl -sf http://127.0.0.1:3737/api/health
```

## Remover (após actualizar Zero Trust para :3000)

```bash
systemctl disable --now archon-v04-proxy.service
```
