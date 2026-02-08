-- MySQL 8.0 Performance Tuning
-- AGL Hostman - Multi-Database Setup

-- Set global variables for performance
SET GLOBAL max_connections = 1000;
SET GLOBAL innodb_buffer_pool_size = 1073741824; -- 1GB
SET GLOBAL innodb_log_file_size = 268435456; -- 256MB
SET GLOBAL innodb_flush_log_at_trx_commit = 2;
SET GLOBAL innodb_flush_method = O_DIRECT;

-- Enable query cache (deprecated in MySQL 8.0, but keeping for reference)
-- SET GLOBAL query_cache_size = 67108864; -- 64MB
-- SET GLOBAL query_cache_limit = 2097152; -- 2MB

-- Set timezone
SET GLOBAL time_zone = 'UTC';
