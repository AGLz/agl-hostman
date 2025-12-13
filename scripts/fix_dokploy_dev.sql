-- Validação e Correção Dokploy: Criar Dev e Mover App

-- 1. Criar ambiente development
INSERT INTO environment ("environmentId", name, "projectId", "createdAt", description)
VALUES ('env_dev_123456789', 'development', 'gaKJ1iCnNXNZRukaeleqV', NOW(), 'Development Environment')
ON CONFLICT DO NOTHING;

-- 2. Mover aplicação agl-hostman-dev para o ambiente correto e padronizar token
UPDATE application 
SET "environmentId" = 'env_dev_123456789',
    "refreshToken" = 'token_dev_123456789'
WHERE name = 'agl-hostman-dev';

-- 3. Verificar resultado final
SELECT e.name as env_name, a.name as app_name, a."refreshToken" as token 
FROM environment e 
LEFT JOIN application a ON e."environmentId" = a."environmentId" 
ORDER BY env_name;
