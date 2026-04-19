# 📊 ANÁLISE DE LIMITES DE MEMÓRIA PHP

**Data:** 2025-10-22
**Verificação realizada em:** fgsrv4, fgsrv5

---

## 🎯 REQUISITOS DO USUÁRIO

| Versão PHP | Memory Limit Mínimo | Motivo |
|------------|---------------------|--------|
| **PHP 5.x** | **1 GB (1024M)** | Implementações antigas |
| **PHP 7.x** | **2 GB (2048M)** | Laravel - tarefas grandes/demoradas |
| **PHP 8.x** | **2 GB (2048M)** | Laravel - tarefas grandes/demoradas |

---

## 📋 SITUAÇÃO ATUAL

### FGSRV4

| Versão | Runtime Atual | php.ini | Pool Override | Status | Ação |
|--------|---------------|---------|---------------|--------|------|
| **PHP 5.6** | **2048M** | 128M | Nenhum | ✅ **OK** | - |
| PHP 7.4 | N/A | 128M | Nenhum | ℹ️ Não usado | - |
| **PHP 8.2** | **-1 (ilimitado)** | 128M | Nenhum | ⚠️ **Ilimitado** | Definir 2048M |

**Notas fgsrv4:**
- PHP 5.6 tem 2048M configurado em algum lugar (atende requisito ✅)
- PHP 8.2 está ilimitado (-1) - recomendo definir 2048M explicitamente
- PHP 7.4 instalado mas não em uso

---

### FGSRV5

| Versão | Runtime Atual | php.ini | Pool Override | Status | Ação |
|--------|---------------|---------|---------------|--------|------|
| **PHP 7.1** | **512M** | 2048M | **512M** (www.conf) | ❌ **ABAIXO** | **Corrigir para 2048M** |
| **PHP 7.4** | **-1 (ilimitado)** | 2048M | **2048M** (fg_old2_new.conf) | ✅ **OK** | - |
| **PHP 8.0** | **-1 (ilimitado)** | 128M | Nenhum | ⚠️ **Ilimitado** | Definir 2048M |
| **PHP 8.1** | **-1 (ilimitado)** | 2G | Nenhum | ⚠️ **Ilimitado** | Definir 2048M |
| **PHP 8.2** | **-1 (ilimitado)** | 2G | Nenhum | ⚠️ **Ilimitado** | Definir 2048M |
| **PHP 8.4** | **-1 (ilimitado)** | 128M | **256M** (fg_old3.conf) | ❌ **MUITO ABAIXO** | **Corrigir para 2048M** |

**Notas fgsrv5:**
- PHP 7.1: Pool define 512M, sobrescrevendo php.ini de 2048M ❌
- PHP 7.4: Pool fg_old2_new.conf define 2048M ✅
- PHP 8.4: Pool fg_old3.conf define apenas 256M ❌
- PHPs 8.0, 8.1, 8.2: Ilimitado (funciona mas não é ideal)

---

## 🚨 PROBLEMAS CRÍTICOS IDENTIFICADOS

### ❌ Problema 1: PHP 7.1 (fgsrv5) - 512M (requisito: 2048M)

**Arquivo:** `/etc/php/7.1/fpm/pool.d/www.conf`

```ini
# Linha atual:
php_admin_value[memory_limit] = 512M

# Deve ser:
php_admin_value[memory_limit] = 2048M
```

**Impacto:** Laravel pode falhar em tarefas grandes/demoradas

---

### ❌ Problema 2: PHP 8.4 (fgsrv5) - 256M (requisito: 2048M)

**Arquivo:** `/etc/php/8.4/fpm/pool.d/fg_old3.conf`

```ini
# Linha atual:
php_value[memory_limit] = 256M

# Deve ser:
php_value[memory_limit] = 2048M
```

**Impacto:** Laravel definitivamente falhará em tarefas grandes

---

## ⚠️ RECOMENDAÇÕES ADICIONAIS

### PHP 8.2 (fgsrv4) - Definir limite explícito

Atualmente ilimitado (-1). Recomendo definir explicitamente:

**Arquivo:** `/etc/php/8.2/fpm/php.ini`

```ini
memory_limit = 2048M
```

---

### PHPs 8.0, 8.1, 8.2 (fgsrv5) - Definir limites explícitos

Todos estão ilimitados (-1). Recomendo definir nos php.ini:

```bash
# PHP 8.0
/etc/php/8.0/fpm/php.ini: memory_limit = 2048M

# PHP 8.1
/etc/php/8.1/fpm/php.ini: memory_limit = 2048M

# PHP 8.2
/etc/php/8.2/fpm/php.ini: memory_limit = 2048M
```

---

## 🔧 CORREÇÕES NECESSÁRIAS

### Prioridade ALTA (Não atendem requisitos):

1. **FGSRV5 - PHP 7.1:** 512M → 2048M (pool)
2. **FGSRV5 - PHP 8.4:** 256M → 2048M (pool)

### Prioridade MÉDIA (Boas práticas):

3. **FGSRV4 - PHP 8.2:** -1 → 2048M (php.ini)
4. **FGSRV5 - PHP 8.0:** -1 → 2048M (php.ini)
5. **FGSRV5 - PHP 8.1:** -1 → 2048M (php.ini)
6. **FGSRV5 - PHP 8.2:** -1 → 2048M (php.ini)

---

## 📊 RESUMO

| Host | Total PHPs | ✅ OK | ⚠️ Ilimitado | ❌ Abaixo |
|------|-----------|-------|--------------|-----------|
| fgsrv4 | 2 ativos | 1 | 1 | 0 |
| fgsrv5 | 6 ativos | 1 | 4 | 2 |
| **TOTAL** | **8** | **2** | **5** | **2** |

**Status geral:** 🔴 **2 CRÍTICOS** + 🟡 **5 RECOMENDADOS**

---

## 💡 OBSERVAÇÃO IMPORTANTE

**Memory limit -1 (ilimitado) funciona**, mas:
- ❌ Não é recomendado em produção
- ❌ Um script com memory leak pode derrubar o servidor
- ❌ Dificulta debug de problemas de memória
- ✅ Melhor definir um limite alto mas explícito (2048M)

---

## 🎯 PRÓXIMA AÇÃO RECOMENDADA

Corrigir os 2 problemas críticos imediatamente:
1. PHP 7.1 (fgsrv5): 512M → 2048M
2. PHP 8.4 (fgsrv5): 256M → 2048M

E opcionalmente definir limites explícitos nos PHPs com -1 (ilimitado).
