-- Criação de Aplicações Dokploy (Corrigido v5)

-- QA App
INSERT INTO application (
    "applicationId", name, "environmentId", "createdAt", 
    "appName", 
    "autoDeploy", "refreshToken"
) VALUES (
    'app_qa_123456789', 'agl-hostman-qa', 'env_qa_123456789', NOW(),
    'agl-hostman-qa', 
    true, 'token_qa_123456789'
);

-- UAT App
INSERT INTO application (
    "applicationId", name, "environmentId", "createdAt", 
    "appName", 
    "autoDeploy", "refreshToken"
) VALUES (
    'app_uat_123456789', 'agl-hostman-uat', 'env_uat_123456789', NOW(),
    'agl-hostman-uat', 
    true, 'token_uat_123456789'
);

-- Production App
INSERT INTO application (
    "applicationId", name, "environmentId", "createdAt", 
    "appName", 
    "autoDeploy", "refreshToken"
) VALUES (
    'app_prod_123456789', 'agl-hostman-production', 'w7EumvSDLYorq1fjruuSR', NOW(),
    'agl-hostman-production', 
    true, 'token_prod_123456789'
);
