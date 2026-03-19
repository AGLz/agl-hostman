# Troubleshooting — agldv12 (CT185)

> Soluções baseadas em pesquisa web (2025-2026) para os problemas encontrados na validação.

---

## 1. Ruflo — "Invalid Version" ao rodar `rf-doctor` ou `npx ruflo doctor`

### Causa
O erro ocorre na resolução de dependências do Ruflo (agentic-flow, @claude-flow/cli). O SemVer encontra uma `version` vazia ou inválida na árvore de dependências — frequentemente em cache ou lock file corrompido.

### Soluções (em ordem de tentativa)

#### A. Limpar cache npx e npm
```bash
# Limpar cache do npx (onde ruflo é instalado temporariamente)
rm -rf ~/.npm/_npx

# Limpar cache npm
npm cache clean --force

# Tentar novamente
npx ruflo@latest doctor --fix
```

#### B. Usar registry oficial (evitar mirror com metadados incompletos)
```bash
npm exec --registry=https://registry.npmjs.org ruflo@latest doctor --fix
```

#### C. Instalar Ruflo localmente (evita cache npx)
```bash
npm install --save-dev ruflo@latest
npx ruflo doctor --fix
```

#### D. Se o projeto tiver package-lock.json corrompido
```bash
rm -rf node_modules package-lock.json
npm install
```

#### E. Se nada funcionar (bug no pacote publicado)
O erro pode estar em metadados do pacote `ruflo` ou `agentic-flow` no registry (version vazia em dependência). Nesse caso:
- Usar Ruflo no agldv03 (já instalado e funcional)
- Ou abrir issue em [ruvnet/ruflo](https://github.com/ruvnet/ruflo/issues)

**Referências**: [ruflo#1235](https://github.com/ruvnet/ruflo/issues/1235), [npm Invalid Version](https://corner.buka.sh/when-npm-install-fails-with-invalid-version/), [Stack Overflow](https://stackoverflow.com/questions/71383116/npm-err-invalid-version-on-npm-install)

---

## 2. Beads — "beads-cli" não encontrado (404)

### Causa
O pacote correto não é `beads-cli`, e sim **`@beads/bd`**.

### Solução
```bash
# Instalação global
npm install -g @beads/bd

# Inicializar no projeto
bd init
```

Comandos úteis:
```bash
bd ready --json    # Trabalho pronto
bd create "Tarefa" -t bug -p 1
bd list --json
```

**Se `bd binary not found`**: O postinstall baixa o binário nativo. Se falhar (rede/firewall), tente:
```bash
cd $(npm root -g)/@beads/bd && npm run postinstall
# Ou reinstale com rede estável
npm install -g @beads/bd
```

**Referência**: [@beads/bd no npm](https://www.npmjs.com/package/@beads/bd), [Beads Documentation](https://steveyegge.github.io/beads/)

---

## 3. Docker / Trivy — "Client.Timeout exceeded while awaiting headers"

### Causa
O daemon Docker não consegue conectar ao `registry-1.docker.io` dentro do timeout padrão (~30s). Comum em: DNS lento, IPv6 mal configurado, rede instável, firewall.

### Soluções

#### A. Configurar DNS no Docker daemon
Editar `/etc/docker/daemon.json`:
```json
{
  "dns": ["8.8.8.8", "8.8.4.4"]
}
```

Depois:
```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

#### B. Usar registry mirror
```json
{
  "registry-mirrors": ["https://mirror.gcr.io"]
}
```

#### C. Desabilitar IPv6 (se a rede não suportar)
```json
{
  "ipv6": false,
  "fixed-cidr-v6": ""
}
```

#### D. Pré-pull da imagem Trivy (evita timeout no security-check)
```bash
docker pull aquasec/trivy:latest
./scripts/security-check.sh
```

#### E. Pular Trivy no validate
```bash
./scripts/validate-agldv12.sh --skip-docker
```

**Referências**: [Docker CLI#4761](https://github.com/docker/cli/issues/4761), [CodeGenes - Docker Timeout](https://www.codegenes.net/blog/how-to-solve-i-o-timeout-error-in-docker-pull/)

---

## 4. npm — Warnings "cache-min deprecated", "network-timeout unknown"

### Causa
O `~/.npmrc` do usuário usa opções deprecadas ou inexistentes no npm 11+.

### Solução
Editar `~/.npmrc` e substituir:
- `cache-min=86400` → `prefer-offline=true`
- `network-timeout=300000` → `fetch-timeout=300000` (ou remover)

O projeto já tem `.npmrc` que sobrescreve com `prefer-offline=true` e `fetch-timeout=300000`.

---

## Resumo rápido

| Problema | Comando rápido |
|----------|----------------|
| Ruflo Invalid Version | `rm -rf ~/.npm/_npx && npm cache clean --force && npx ruflo@latest doctor` |
| Beads | `npm install -g @beads/bd && bd init` |
| Trivy timeout | `docker pull aquasec/trivy:latest` ou `--skip-docker` |
| npm warnings | Usar `.npmrc` do projeto (já configurado) |
