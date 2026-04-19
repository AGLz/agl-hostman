-- MySQL 8.0 Initialization Script
-- AGL Hostman - Multi-Database Setup
--
-- This script creates additional databases and users for the application

-- Create additional databases if specified
CREATE DATABASE IF NOT EXISTS \`agl_hostman_cache\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS \`agl_hostman_queue\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS \`agl_hostman_sessions\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Grant privileges on all databases
GRANT ALL PRIVILEGES ON \`agl_hostman%\`.* TO '${MYSQL_USER:-agl_user}'@'%';
FLUSH PRIVILEGES;

-- Display created databases
SHOW DATABASES;
