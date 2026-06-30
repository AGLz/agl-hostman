---
name: agl-video-analysis
description: |
  Pipeline AGL para analisar vídeos YouTube: transcrição (vtd.js), síntese estruturada,
  aplicação ao projeto (Ponytail/Improve/arsenal), ingest opcional llm-wiki.
  Usar quando o utilizador partilhar URL YouTube ou pedir análise de vídeo/transcrição.
---

# AGL Video Analysis

Pipeline alinhado com Hermes (terminal + skills) e Cursor.

## 1. Obter transcrição

Preferir `youtube-transcript-plus` via `vtd.js` (evita rate-limit yt-dlp):

```bash
VTD="${VTD:-$HOME/.cursor/skills/video-transcript-downloader/scripts/vtd.js}"
[[ -f "$VTD" ]] || VTD=".agents/skills/video-transcript-downloader/scripts/vtd.js"

node "$VTD" transcript --url 'https://www.youtube.com/watch?v=VIDEO_ID'
# Com timestamps: acrescentar --timestamps
```

Se falhar: `--lang pt` ou `--lang en`; fallback `yt-dlp` só como último recurso.

## 2. Metadados

```bash
yt-dlp --no-update --skip-download --print "%(title)s :: %(channel)s :: %(duration_string)s" 'URL'
```

## 3. Análise estruturada

Criar ou actualizar ficheiro em `projects/video-analises/youtube_NNN.md` seguindo o template de `youtube_001.md` / `youtube_002.md`:

- Resumo executivo
- Conceitos centrais
- Ferramentas/repos mencionados (com links)
- Checklist de boas práticas
- **Aplicação AGL** (ficheiros, skills, gaps)
- Metadados do vídeo

Incrementar `NNN` (próximo livre na pasta).

## 4. Arsenal de guerra (quando aplicável)

| Ferramenta       | Quando usar                                                         |
| ---------------- | ------------------------------------------------------------------- |
| **Ponytail**     | Antes/durante implementação — diff mínimo                           |
| **Improve**      | Auditoria read-only pós-implementação (`/improve` ou skill improve) |
| **SkillSpector** | Antes de instalar skills de terceiros                               |
| **draw.io**      | Mapear arquitetura quando o vídeo fala de estrutura                 |

## 5. Segundo cérebro (opcional)

Decisões duráveis → ingest `llm-wiki` via Curator ou MCP `llm-wiki-fs`. Não duplicar runbooks em `docs/` solto.

## 6. Hermes

No CT188 o mesmo fluxo corre via toolset `terminal` + skill `video-transcript-downloader` em `profiles/*/skills/`.

```bash
bash scripts/proxmox/install-hermes-arsenal-skills-ct188.sh
```

## Referências

- `projects/video-analises/ARSENAL_WAR_APPLICATION_PLAN.md`
- `scripts/skills/install-arsenal-war-skills.sh`
- Skill `video-transcript-downloader`
