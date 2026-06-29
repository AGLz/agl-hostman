-- Inventário DB_IDE_Associacao — contagens e PKs (executar com sqlcmd -i)
SET NOCOUNT ON;
USE [DB_IDE_Associacao];

PRINT '===SUMMARY===';
SELECT
  COUNT(*) AS table_count,
  SUM(CASE WHEN pk.object_id IS NOT NULL THEN 1 ELSE 0 END) AS tables_with_pk,
  SUM(CASE WHEN pk.object_id IS NULL THEN 1 ELSE 0 END) AS tables_without_pk
FROM sys.tables t
LEFT JOIN (
  SELECT object_id FROM sys.indexes WHERE is_primary_key = 1
) pk ON pk.object_id = t.object_id
WHERE t.is_ms_shipped = 0;

DECLARE @total_rows BIGINT;
SELECT @total_rows = SUM(p.rows)
FROM sys.tables t
INNER JOIN sys.partitions p ON t.object_id = p.object_id
WHERE t.is_ms_shipped = 0 AND p.index_id IN (0, 1);
SELECT @total_rows AS approx_total_rows;

PRINT '===TABLES_NO_PK===';
SELECT t.name AS table_name
FROM sys.tables t
WHERE t.is_ms_shipped = 0
  AND NOT EXISTS (
    SELECT 1 FROM sys.indexes i
    WHERE i.object_id = t.object_id AND i.is_primary_key = 1
  )
ORDER BY t.name;

PRINT '===TABLE_ROWS===';
SELECT
  t.name AS table_name,
  MAX(CASE WHEN i.is_primary_key = 1 THEN 1 ELSE 0 END) AS has_pk,
  SUM(p.rows) AS row_count
FROM sys.tables t
INNER JOIN sys.partitions p ON t.object_id = p.object_id
LEFT JOIN sys.indexes i ON i.object_id = t.object_id AND i.is_primary_key = 1
WHERE t.is_ms_shipped = 0 AND p.index_id IN (0, 1)
GROUP BY t.name
ORDER BY t.name;
