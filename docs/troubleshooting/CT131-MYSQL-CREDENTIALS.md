# CT131 (mysql) - MySQL Credentials and Access Configuration

**Data**: 2025-01-27 (Atualizado)
**CT**: 131 (mysql - Debian 11)
**Host**: AGLSRV1 (192.168.0.245)
**IP**: 192.168.0.131
**Status**: ✅ **MySQL Server Ativo**

---

## 📋 Sumário Executivo

Servidor MySQL/MariaDB no container CT131 do host AGLSRV1, configurado para acesso local e remoto.

---

## 🎯 Configuração do MySQL

### Informações do Container

- **Host**: AGLSRV1 (Proxmox VE)
- **Container ID**: 131
- **Nome**: mysql
- **IP LAN**: 192.168.0.131
- **Sistema Operacional**: Debian 11
- **MySQL/MariaDB**: Versão ativa

### Acesso ao Container

```bash
# Acesso SSH ao container
ssh root@192.168.0.245 "pct enter 131"

# Executar comandos MySQL
ssh root@192.168.0.245 "pct exec 131 -- mysql -e 'SHOW DATABASES'"
```

---

## 🔑 Credenciais de Acesso

### Usuários MySQL Configurados

| Usuário | Host | Acesso | Senha | Observações |
|---------|------|--------|-------|-------------|
| **root** | localhost | Local apenas | - | Acesso via socket Unix (sem senha) |
| **sys** | % | Remoto | `Power@12345` | ✅ **Acesso remoto completo com privilégios totais** |


### Usuários do Sistema

| Usuário | Host | Propósito |
|---------|------|-----------|
| adminer | localhost | Adminer web interface |
| mysql | localhost | Sistema MySQL |
| mariadb.sys | localhost | Sistema MariaDB |


---

## 🔌 Conexão Remota

### Usuário Recomendado: `sys`

**Credenciais**:
- **Host**: 192.168.0.131
- **Usuário**: `sys`
- **Senha**: `Power@12345`
- **Porta**: 3306 (padrão)

**Exemplo de Conexão**:

```bash
# Via linha de comando
mysql -h 192.168.0.131 -u sys -p'Power@12345'

# Via cliente MySQL com prompt de senha
mysql -h 192.168.0.131 -u sys -p
# Digite: Power@12345

# Teste rápido
mysql -h 192.168.0.131 -u sys -p'Power@12345' -e "SHOW DATABASES;"
```

---

## 🔒 Privilégios do Usuário `sys`

O usuário `sys` foi criado com privilégios administrativos completos:

```sql
GRANT ALL PRIVILEGES ON *.* TO 'sys'@'%' WITH GRANT OPTION;
```

**Capacidades**:

- ✅ Acesso a todos os databases
- ✅ Criação e exclusão de databases
- ✅ Criação e gerenciamento de usuários
- ✅ Concessão e revogação de privilégios
- ✅ Acesso remoto de qualquer host (%)

---

## 📊 Databases Disponíveis

### Databases do Sistema
- `information_schema` - Metadados do MySQL
- `mysql` - Database do sistema MySQL
- `performance_schema` - Métricas de performance

### Databases de Aplicação
*(Adicionar databases de aplicação quando identificados)*

---

## 🛠️ Comandos Úteis

### Verificação de Usuários

```bash
# Listar usuários MySQL
ssh root@192.168.0.245 "pct exec 131 -- mysql -e \"SELECT user, host FROM mysql.user;\""

# Verificar usuário específico
ssh root@192.168.0.245 "pct exec 131 -- mysql -e \"SELECT user, host FROM mysql.user WHERE user='sys';\""
```

### Gerenciamento de Usuários

```bash
# Acessar MySQL localmente (como root)
ssh root@192.168.0.245 "pct exec 131 -- mysql"

# Criar novo usuário (dentro do MySQL)
CREATE USER 'novousuario'@'%' IDENTIFIED BY 'senha_segura';
GRANT ALL PRIVILEGES ON *.* TO 'novousuario'@'%';
FLUSH PRIVILEGES;
```

### Teste de Conexão Remota

```bash
# Teste com usuário sys
mysql -h 192.168.0.131 -u sys -p'Power@12345' -e "SELECT USER(), DATABASE();"
```

---

## 📝 Notas Importantes

### Acesso Root Local

O usuário `root` do MySQL **não permite acesso remoto** por padrão. Para acesso administrativo remoto, use o usuário `sys` que possui privilégios completos.

**Acesso root funciona apenas localmente**:

```bash
# Dentro do container (local)
ssh root@192.168.0.245 "pct exec 131 -- mysql"
# Não pede senha - acesso via socket Unix
```

### Segurança

⚠️ **Recomendações de Segurança**:

- O usuário `sys` tem privilégios totais - use com cuidado
- Considere criar usuários específicos para cada aplicação
- Implemente firewall para restringir acesso à porta 3306 se necessário
- Mantenha senhas seguras e altere-as periodicamente

### Backup

Para scripts de backup, use o usuário `sys` que possui privilégios completos.


---

## 🔗 Relacionado

- **Documentação de Containers**: `docs/CONTAINERS.md`
- **Infraestrutura AGLSRV1**: `docs/AGLSRV1_INFRASTRUCTURE_ANALYSIS.md`
- **Outros MySQL**: CT135 (AGLSRV5) - `docs/troubleshooting/CT135-MYSQL5-BACKUP-COMPLETE.md`

---

## 📚 Histórico

- **2025-01-27**: Documentação criada, usuário `sys` criado com senha `Power@12345`

---

**Document Version**: 1.0.0  
**Last Updated**: 2025-01-27  
**Maintainer**: Claude Code (agl-hostman project)


