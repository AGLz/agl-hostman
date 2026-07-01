# Homologação Bradesco (offline)

Gera **1 arquivo `.rem`** (CNAB400) e **1 PDF** de boleto para envio ao banco por e-mail.

## Pré-requisitos

- PHP 5.6 (CLI)
- Copiar `config.homolog.php.example` → `config.homolog.php` e preencher credenciais (conforme `instructions.md`; ficheiro real não vai para o Git)

## Gerar

```bash
cd /var/www/fg_antigo/BRAD
php gerar_homologacao.php
```

Opções:

```bash
php gerar_homologacao.php --seq=1 --nn=1
```

- `--seq` — sequencial MX do header (nunca repetir em produção)
- `--nn` — nosso número base (sem DV; DV calculado automaticamente)

## Saída

Ficheiros em `BRAD/output/`:

- `FALG{timestamp}.rem` — remessa CNAB400
- `boleto-homolog-{timestamp}.pdf` — boleto para homologação visual
- `boleto-homolog-{timestamp}.html` — cópia HTML (backup)

## Enviar ao banco

1. Anexar **1** `.rem` e **1** PDF
2. Aguardar validação da estrutura
3. Só após OK: produção (WebTA / Net Empresa)

## Ajustes

Editar `config.homolog.php` se o banco devolver observações sobre convênio, carteira, espécie ou instruções.
