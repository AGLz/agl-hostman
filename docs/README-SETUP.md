# 🚀 WSL & PowerShell Setup Completo

## ✅ O que foi configurado

### 1. **WSL (Ubuntu)**
- ✨ **Zsh** com **Oh My Zsh** e tema Powerlevel10k
- 🔧 **Ferramentas instaladas:**
  - `htop` - Monitor de sistema
  - `neofetch` - Informações do sistema
  - `bat` - Cat com syntax highlighting
  - `eza` - Substituto moderno do ls com ícones
  - `fzf` - Fuzzy finder
  - `ripgrep` - Busca rápida em arquivos
  - `fd-find` - Find moderno
  - `ncdu` - Analisador de uso de disco
  - `tldr` - Man pages simplificadas
  - `neovim` - Editor de texto avançado
  - `tmux` - Multiplexador de terminal
  - `tree` - Visualização em árvore
  - `jq` - Processador JSON

### 2. **PowerShell**
- 🎨 Script de configuração com **Oh My Posh**
- 📦 Módulos úteis: PSReadLine, Terminal-Icons, z, PSFzf
- ⚡ Aliases e funções personalizadas

### 3. **Windows Terminal**
- 🎨 Configurações otimizadas com temas
- ⌨️ Atalhos de teclado configurados
- 🖼️ Perfis para WSL, PowerShell, CMD e Git Bash

## 📝 Como usar

### No WSL

1. **Recarregar configurações do Zsh:**
   ```bash
   source ~/.zshrc
   ```

2. **Ver comandos WSL úteis:**
   ```bash
   wsl-help
   ```

3. **Comandos úteis disponíveis:**
   - `explorer` - Abrir Explorer do Windows
   - `code` - Abrir VS Code
   - `clip` - Copiar para clipboard
   - `open <arquivo>` - Abrir no Windows
   - `monitor` - Ver recursos do sistema
   - `backup-configs` - Fazer backup das configurações

### No PowerShell

1. **Executar script de setup (como Administrador):**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   .\setup-powershell.ps1
   ```

2. **Recarregar perfil:**
   ```powershell
   . $PROFILE
   ```

### Windows Terminal

1. **Importar configurações:**
   - Abra Windows Terminal
   - Pressione `Ctrl+,` para abrir configurações
   - Clique em "Abrir arquivo JSON"
   - Copie o conteúdo de `windows-terminal-settings.json`

## 🎯 Aliases Configurados

### Git
- `gs` - git status
- `ga` - git add
- `gc` - git commit
- `gp` - git push
- `gl` - git log (formatado)
- `gaa` - git add .
- `gcm` - git commit -m

### Navegação
- `ll` - Lista detalhada com ícones
- `..` - Subir um diretório
- `...` - Subir dois diretórios
- `dev` - Ir para ~/dev
- `docs` - Ir para Documents

### Docker
- `dps` - docker ps
- `di` - docker images
- `dlog` - docker logs
- `dprune` - Limpar sistema Docker

### Sistema
- `update` - Atualizar sistema
- `myip` - Ver IP externo
- `ports` - Ver portas abertas
- `disk` - Ver uso de disco
- `clean-wsl` - Limpar cache WSL

## 🔧 Opcional: Instalar Starship

Para um prompt ainda mais moderno:

```bash
./install-starship.sh
```

Depois adicione ao `.zshrc`:
```bash
eval "$(starship init zsh)"
```

## 📚 Recursos Adicionais

- [Oh My Zsh](https://ohmyz.sh/)
- [Oh My Posh](https://ohmyposh.dev/)
- [Windows Terminal Docs](https://docs.microsoft.com/windows/terminal/)
- [WSL Docs](https://docs.microsoft.com/windows/wsl/)

## 🎉 Aproveite sua nova configuração!

Seu ambiente está otimizado para produtividade com:
- ✅ Autocompletar inteligente
- ✅ Histórico melhorado
- ✅ Navegação rápida
- ✅ Visualização colorida
- ✅ Integração WSL-Windows
- ✅ Ferramentas modernas