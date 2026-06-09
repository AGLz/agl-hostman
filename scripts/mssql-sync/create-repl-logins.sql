-- Login de replicação MSSQL (CT610 e VM620)
-- Executar com SA em cada nó; password via variável MSSQL_REPL_PASSWORD no script apply-repl-logins.sh

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'repl_mssql')
BEGIN
    CREATE LOGIN [repl_mssql] WITH PASSWORD = N'${MSSQL_REPL_PASSWORD}', CHECK_POLICY = OFF;
END
GO

-- Permissões mínimas para SymmetricDS / merge futuro
ALTER SERVER ROLE [setupadmin] ADD MEMBER [repl_mssql];
GO

USE [SILD];
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'repl_mssql')
    CREATE USER [repl_mssql] FOR LOGIN [repl_mssql];
ALTER ROLE [db_datareader] ADD MEMBER [repl_mssql];
ALTER ROLE [db_datawriter] ADD MEMBER [repl_mssql];
GO

USE [ALD-SYS8];
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'repl_mssql')
    CREATE USER [repl_mssql] FOR LOGIN [repl_mssql];
ALTER ROLE [db_datareader] ADD MEMBER [repl_mssql];
ALTER ROLE [db_datawriter] ADD MEMBER [repl_mssql];
GO

USE [DB_IDE_Associacao];
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'repl_mssql')
    CREATE USER [repl_mssql] FOR LOGIN [repl_mssql];
ALTER ROLE [db_datareader] ADD MEMBER [repl_mssql];
ALTER ROLE [db_datawriter] ADD MEMBER [repl_mssql];
GO

USE [CEP_Brasil];
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'repl_mssql')
    CREATE USER [repl_mssql] FOR LOGIN [repl_mssql];
ALTER ROLE [db_datareader] ADD MEMBER [repl_mssql];
ALTER ROLE [db_datawriter] ADD MEMBER [repl_mssql];
GO
