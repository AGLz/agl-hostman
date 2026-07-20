# Spike AGL — auth2api (AmazingAng): OAuth Claude/Codex → OpenAI-compatible
# Build: docker compose -f docker/auth2api/docker-compose.yml build
# Pin: alterar AUTH2API_REF para tag/SHA estável após validação.

ARG AUTH2API_REF=a34c011f9fda1013ff3f9299160694c2ab62e4db
FROM node:20-alpine AS builder
ARG AUTH2API_REF
RUN apk add --no-cache git
WORKDIR /src
# Reason: fetch por SHA (shallow) — pin estável sem clonar todo o histórico.
RUN git init \
  && git remote add origin https://github.com/AmazingAng/auth2api.git \
  && git fetch --depth 1 origin "${AUTH2API_REF}" \
  && git checkout FETCH_HEAD
# Reason: upstream manda client_version=auth2api/1.0.0 em /codex/models;
# o backend ChatGPT passou a exigir semver (Invalid client_version format).
# Alinhar ao cloaking.codex.cli-version (npm @openai/codex).
ARG CODEX_CLIENT_VERSION=0.142.5
RUN sed -i "s|const CLIENT_VERSION = \"auth2api/1.0.0\"|const CLIENT_VERSION = \"${CODEX_CLIENT_VERSION}\"|" \
  src/upstream/codex-models.ts
RUN npm install && npx tsc

FROM node:20-alpine
RUN apk add --no-cache wget
WORKDIR /app
COPY --from=builder /src/dist dist/
COPY --from=builder /src/node_modules node_modules/
COPY --from=builder /src/package.json ./
EXPOSE 8317
VOLUME ["/data", "/config"]
ENV NODE_ENV=production
CMD ["node", "dist/index.js", "--config=/config/config.yaml"]
