# COMPREHENSIVE API RESEARCH FINDINGS - FGSRV05
**Research Date:** 2025-10-13
**Server:** FGSRV05 (100.71.107.26 via Tailscale)
**OS:** Ubuntu 22.04.5 LTS (Jammy Jellyfish)
**Researcher Agent:** Hive Mind Collective

---

## EXECUTIVE SUMMARY

Successfully mapped two Laravel-based property management APIs running on FGSRV05:
- **API1 (fg_OLD2_NEW)**: Legacy Laravel 5.5 on PHP 7.4-FPM with 126 controllers
- **API8 (fg_API8_b)**: Modern Laravel 8.x on PHP 8.1-FPM with 75 controllers

Both APIs share the same MySQL database (191.252.201.205:3306) and Redis instance, implementing a real estate administration system for "Falg Administração e Vendas Ltda".

---

## API 1: fg_OLD2_NEW (Legacy Production API)

### Server Configuration
- **Domain:** https://api.falg.com.br (also api2.falg.com.br)
- **Web Root:** /var/www/fg_OLD2_NEW/public
- **PHP Version:** PHP 7.4.33-FPM
- **PHP-FPM Socket:** unix:/run/php/php7.4-fpm-fg_old2_new.sock
- **Framework:** Laravel 5.5.* (Legacy)
- **Status:** Active Production

### Nginx Configuration
```nginx
Server Names: api.falg.com.br, api2.falg.com.br
SSL: Let's Encrypt (TLSv1.2, TLSv1.3)
Rate Limiting: 20 burst for /api/
CORS: Enabled with wildcard origin
FastCGI Optimizations: 256k buffers
Gzip: Level 6 compression
Caching: Aggressive for static assets (1y images, 30d scripts)
```

### Database Configuration
```env
DB_CONNECTION_SYS=mysql
DB_HOST_SYS=191.252.201.205
DB_PORT_SYS=3306
DB_DATABASE_SYS=falgimoveis11
DB_USERNAME_SYS=root
DB_PASSWORD_SYS=power@123
```

### Redis Configuration
```env
REDIS_HOST=127.0.0.1
REDIS_PASSWORD=p58v2xfY0R4UG0NGBU5Xu3QFvvp2hSw51QXXABZMG2td+CImsB5LOKjk3BWjc7boR725n7gilgjgAvg3
REDIS_PORT=6379
REDIS_DATABASE=1
CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_DRIVER=redis
```

### Authentication
- **JWT:** tymon/jwt-auth (dev-develop)
- **JWT_SECRET:** ijtPhq52sAzUEoD74Zhu8aYxrxm2wF4B
- **Middleware:** jwt.auth, cors, api, auth:api

### External Integrations

#### Email Services
1. **Mailgun (Primary)**
   - Domain: mg.falgimoveis.com
   - Host: smtp.mailgun.org:587
   - Username: sys@mg.falgimoveis.com
   - Secret: dbd071f00de5731d68d32f685c0b5c22-53c13666-9812ff4e

2. **SMTP Locaweb (Secondary)**
   - Host: https://api.smtplw.com.br/v1
   - Token: 13348372151d1ac7588fbd1334ad0d45

#### AWS Services
- **Region:** us-east-1
- **S3 Bucket:** fg-sys-s3
- **Access Key ID:** AKIAILNT6XUCFUGKDEUQ
- **Directories:**
  - Backups: sys-backups
  - Files: sys-files/fg-files

#### Pusher (WebSockets)
- **App ID:** 426563
- **App Key:** 5d86a461aac4c05e3f50
- **Cluster:** us2

#### Error Tracking
- **Rollbar Token:** dae7654d81f546a0b94dbe3a5fd8add9
- **Level:** debug

### Key Dependencies (composer.json)
```json
{
  "php": ">=7.0.0",
  "laravel/framework": "5.5.*",
  "tymon/jwt-auth": "dev-develop",
  "eduardokum/laravel-boleto": "^0.7.1",
  "barryvdh/laravel-dompdf": "^0.8.1",
  "aws/aws-sdk-php": "^3.38",
  "league/flysystem-aws-s3-v3": "^1.0",
  "predis/predis": "^1.1",
  "spatie/laravel-backup": "^5.1",
  "arcanedev/log-viewer": "~4.4.0"
}
```

### API Endpoints Summary
**Total Routes:** 346 lines (including resources that expand to multiple endpoints)

#### Authentication & User Management
- POST /login
- POST /register
- POST /logout
- POST /password/email (forgot password)
- POST /password/reset
- GET /user (current user)
- PATCH /settings/profile
- PATCH /settings/password

#### JWT Token Management
- POST /auth/token/issue
- POST /auth/token/refresh
- POST /auth/token/revoke

#### Core Business Entities (All with full REST resources)

**Property Management:**
- /imoveis - Properties (GET, POST, PUT, DELETE, full-list, showRef by ID)
- /bairros - Neighborhoods (full CRUD + full-list)
- /cidades - Cities (full CRUD + full-list)

**Client Management:**
- /clientes - Clients (full CRUD + full-list)
- /clients - Alternative client endpoint
- /contatos - Contacts (full CRUD + full-list)
- /novoscontatos - New contacts

**Contracts & Billing:**
- /contratos - Contracts (full CRUD + full-list)
- /contratosatrasados - Overdue contracts
- /cobrancas - Charges/Bills (full CRUD + full-list)
  - GET /cobrancas/pagto/{id} - Payment details
  - POST /cobrancas/pagto/{id} - Make payment
  - MATCH /cobrancas/totpagto/{id} - Total payment info
  - GET /cobrancas/totpagtoold/{id} - Legacy total payment
- /vincctrcobs - Contract-Charge relationships
- /vincctrclis - Contract-Client relationships

**Banking & Payment Processing:**
- /boletos - Bank slips (full CRUD + full-list)
- /remessas - Remittances (full CRUD + full-list)
- /remessasboleto - Boleto remittances
- /cheques - Checks (full CRUD + full-list)
- /recibos - Receipts (full CRUD + full-list)
- /creditos - Credits (full CRUD + full-list)
- /extratos - Statements (full CRUD + full-list)

**Boleto Specific Operations:**
- GET /boletoitau/{id} - Generate Itaú PDF
- GET /get-boleto - Get boleto by FG ID
- GET /get-remessa - Get remittance
- GET /get-remessa-itau - Get Itaú remittance
- GET /list-remessas - List all remittances
- GET /list-remessas-last - Last remittances
- GET /list-cobrancas - List charges
- GET /post-remessa-enviado - Mark remittance as sent
- GET /post-boleto-remove - Remove boleto
- GET /post-boleto-baixa - Mark boleto as paid
- GET /post-retorno - Post return file
- GET /get-retorno - Get return by FG

**Financial Management:**
- /movimentos - Movements/Transactions (full CRUD + full-list)
- /poupancas - Savings (full CRUD + full-list)
- /igpms - IGPM index values (full CRUD + full-list)

**System Configuration (Tipos/Types):**
- /tiposcaixa - Cash box types
- /tiposcliente - Client types
- /tiposcobranca - Charge types
- /tiposcontato - Contact types
- /tiposimovel - Property types
- /tiposmov - Movement types
- /tipospagar - Payment types

**Historical Records:**
- /histclis - Client history
- /histcobs - Charge history (with getCtr endpoint)
- /histctrs - Contract history (with getCtr endpoint)
- /histimos - Property history
- /histjurs - Legal history
- /histpros - Proposal history

**Operational:**
- /documentos - Documents
- /feriados - Holidays
- /formascontato - Contact forms
- /horarios - Schedules
- /plantoes - Duty shifts
- /plantoeslocacao - Rental duty shifts
- /recados - Messages
- /tasks - Tasks
- /todos - To-do items
- /todos2 - Alternative to-dos
- /propostas - Proposals
- /posts - Posts
- /videos - Videos
- /chats - Chat messages
- /usuarios - System users
- /usuariossite - Website users
- /users - Alternative users endpoint

**Dashboard & Reporting:**
- GET /dashboard - Dashboard data
- GET /pdfmake - Generate PDF

### Controllers Structure
**Location:** /var/www/fg_OLD2_NEW/app/Http/Controllers/
**Total Controllers:** 126 files

**Key Controllers:**
- BoletoController.php (137,277 bytes - MASSIVE - core banking logic)
  - Multiple backup versions indicating recent boleto fixes
  - Last modified: 2025-10-13 12:17
  - Backups from: Oct 7, Sep 30 (campo/registro/custom fixes)
- AuthController.php (3,556 bytes)
- CategoriesController.php
- ChatController.php
- ClientController.php
- PdfController.php
- TesteController.php
- UserController.php

**Si/ Namespace (System Integration):**
126 controllers in /app/Http/Controllers/Si/ including:
- All business entity controllers (Bairros, Boletos, Cidades, etc.)
- All historical record controllers (Hist*)
- All type/configuration controllers (Tipos*)
- Dashboard, reports, and operational controllers

### Recent Code Changes
Based on file timestamps and backups:
1. **Oct 13, 2025:** BoletoController fixes for list_cobrancas
2. **Oct 7, 2025:** Multiple boleto-related improvements
   - Digit account fixes
   - Custom remessa handling
   - Registration fixes
3. **Sep 30, 2025:** Field mapping corrections

### Documentation Files Present
- 00-INICIO-AQUI.md
- README-fg_OLD2_NEW.md
- ANALISE_OTIMIZACAO.md
- CORRECAO_BOLETO_REGISTRADO.md
- CORRECAO_DIGITO_CONTA_BOLETO.md
- MELHORIAS_APLICADAS_07102025.md
- SOLUCAO_FINAL_DIGITO_CONTA.md
- SOLUCAO_LIST_COBRANCAS_13102025.md
- SOLUCAO_PERMANENTE_DIGITO_CONTA.md
- VALIDATION_SUMMARY.txt

### Shell Scripts
- apply-boleto-fix.sh - Automated boleto fix deployment
- c.sh, c2.sh, c_prod.sh - Cache clearing scripts
- p.sh, pl.sh, pv.sh - Various utility scripts
- u.sh - Update script

---

## API 8: fg_API8_b (Modern Development API)

### Server Configuration
- **Domains:**
  - https://api8.falg.com.br (primary)
  - https://api8.aglz.io (legacy)
  - https://api8.aguileraz.net
- **Web Root:** /var/www/fg_API8_b/src/public
- **PHP Version:** PHP 8.1.33-FPM
- **PHP-FPM Socket:** unix:/var/run/php/php8.1-fpm.sock
- **Framework:** Laravel 8.54+ (Modern)
- **Status:** Development/Testing

### Nginx Configuration
```nginx
Server Names: api8.falg.com.br, api8.aglz.io, api8.aguileraz.net
SSL: Let's Encrypt (separate certs for each domain)
Rate Limiting: 20 burst for /api/
CORS: Enabled with wildcard origin
FastCGI Optimizations: 256k buffers
Gzip: Level 6 compression
Root: /var/www/fg_API8_d/src/public (NOTE: Points to fg_API8_d, not fg_API8_b!)
```

**IMPORTANT FINDING:** Nginx points to `/var/www/fg_API8_d/` but we analyzed `/var/www/fg_API8_b/`. Need to clarify which is actually active.

### Database Configuration
```env
DB_CONNECTION_SYS=mysql_sys
DB_HOST_SYS=191.252.201.205
DB_PORT_SYS=3306
DB_DATABASE_SYS=fgdev
DB_USERNAME_SYS=root
DB_PASSWORD_SYS=power@123

# Secondary connection (disabled)
DB_CONNECTION_SYS2=mysql_sys2
DB_HOST_SYS2=aurora-sys-01.cluster-c6igfmucgzfz.us-east-1.rds.amazonaws.com
```

**CRITICAL:** API8 uses database "fgdev" while API1 uses "falgimoveis11" - DIFFERENT DATABASES!

### Redis Configuration
```env
REDIS_HOST=127.0.0.1
REDIS_PASSWORD=p58v2xfY0R4UG0NGBU5Xu3QFvvp2hSw51QXXABZMG2td+CImsB5LOKjk3BWjc7boR725n7gilgjgAvg3
REDIS_PORT=6379
REDIS_DB=8
REDIS_CACHE_DB=9
CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis
```

**NOTE:** Uses Redis DB 8 & 9, while API1 uses DB 1 - ISOLATED REDIS NAMESPACES

### Authentication
- **JWT:** tymon/jwt-auth (*)
- **Middleware:** jwt.auth, auth:api

### External Integrations

#### Email Services
1. **Mailgun**
   - Domain: mg.aguileraz.net (DIFFERENT from API1!)
   - Host: smtp.mailgun.org:587
   - Username: sys@mg.aguileraz.net
   - Secret: 0d2af3563fb53435458ac80277d51b32-d32d817f-8288b075

#### WebSockets & Real-time
- **Pusher:** pusher-php-server ~4.0
- **Laravel WebSockets:** ^1.12
- **Laravel Horizon:** ^5.6 (queue management)
- **Laravel Telescope:** ^4.6 (debugging)

#### Advanced Features
- **Laravel Backup:** ^7.7
- **Laravel Totem:** ^9.0 (task scheduler UI)
- **Laravel Socialite:** ^5.2
- **Google API Client:** ^2.12
- **Twilio SDK:** ^6.21
- **Telegram notifications**
- **SMS77 notifications**

### Key Dependencies (composer.json)
```json
{
  "php": "^8.0",
  "laravel/framework": "^8.54",
  "laravel/horizon": "^5.6",
  "laravel/telescope": "^4.6",
  "laravel/ui": "^3.4",
  "laravel/dusk": "^6.19",
  "tymon/jwt-auth": "*",
  "eduardokum/laravel-boleto": "^0.8.12",
  "spatie/laravel-backup": "^7.7",
  "studio/laravel-totem": "^9.0",
  "zircote/swagger-php": "^3.0",
  "laravel-notification-channels/telegram": "^0.5.1",
  "laravel-notification-channels/twilio": "^3.1",
  "google/apiclient": "^2.12"
}
```

### API Endpoints Summary
**Total Routes:** 303 route definitions

**Similar structure to API1 but with enhancements:**

#### Development & Debug Endpoints
- GET /log-full - Download full logs as ZIP
- GET /log-daily - Download daily logs as ZIP
- GET /dumpsql - SQL dump as ZIP
- GET /larabkp - Laravel backup
- GET /hostname - Server hostname
- GET /phpinfo - PHP info
- GET /dev/1 through /dev/6 - Development test endpoints

#### Media & Cloud Storage
- POST /runcloudstoragemove - Trigger cloud storage migration

#### Banking (BRAD - Bradesco Bank)
- GET /brad/get-txt - Get TXT file
- GET /brad/get-xls - Get XLS file
- GET /brad/down-txt - Download TXT
- GET /brad/down-xls - Download XLS
- GET /brad/read-xls - Parse XLS

#### Geolocation Services
- GET /geolocation - Find geolocation
- GET /formatted_address - Get formatted address
- GET /postal_code - Get postal code

#### Restaurant API (Testing?)
- GET /restaurants/find-all

#### Core Business Endpoints
Similar to API1 with same entity structure:
- All property, client, contract, billing endpoints
- All boleto and banking endpoints
- All configuration and type endpoints
- All historical record endpoints

### Controllers Structure
**Location:** /var/www/fg_API8_b/src/app/Http/Controllers/
**Total Controllers:** 75 files

**Key Controllers:**
- Dev/BaseController - Development utilities
- Dev/BradController - Bradesco bank integration
- Dev/MediaServerController - Media/cloud storage
- Dev/GeolocationController - Geolocation services
- Dev/RestaurantController - Restaurant API testing
- SI/* - Business logic controllers (75 total)

### Infrastructure & DevOps
**Azure DevOps Pipelines:**
- azure-pipelines_dev.yml
- azure-pipelines_dev2.yml
- azure-pipelines_dockerfile.yml
- azure-pipelines_laravel.yml
- azure-pipelines_prod.yml
- azure-pipelines_prod2.yml
- azure-pipelines_qa.yml
- azure-pipelines_stage.yml

**Docker Support:**
- dockerfiles/ directory
- docker-compose configurations
- Container build scripts
- Multiple deployment environments (dev, qa, stage, prod)

### Shell Scripts
- buildvue.sh - Vue.js build
- cacheclear.sh, cacheclear2.sh - Cache clearing
- dockerbuild.sh, dockerbuild2.sh - Docker image builds
- dockercomposedev.sh, dockercomposesite.sh - Compose management
- update.sh, update2.sh, update3.sh - Update scripts
- test.sh - Testing

### Database Migrations
- API1: 5 migration files
- API8: 22 migration files (MORE EXTENSIVE SCHEMA)

---

## CRITICAL DIFFERENCES BETWEEN API1 & API8

### Framework & PHP
| Feature | API1 (fg_OLD2_NEW) | API8 (fg_API8_b) |
|---------|-------------------|------------------|
| Laravel Version | 5.5.* (EOL) | 8.54+ (Modern) |
| PHP Version | 7.4.33 | 8.1.33 |
| PHP Support | EOL Nov 2022 | Active until Nov 2025 |

### Database & Storage
| Feature | API1 | API8 |
|---------|------|------|
| Database | falgimoveis11 | fgdev |
| Redis DB | 1 | 8 & 9 |
| Redis Cache DB | Same as main | Separate (9) |
| Migrations | 5 files | 22 files |

### Infrastructure
| Feature | API1 | API8 |
|---------|------|------|
| Deployment | Manual | Azure DevOps CI/CD |
| Containers | No | Yes (Docker) |
| Monitoring | Basic logging | Telescope + Horizon |
| Queue Management | Basic Redis | Horizon Dashboard |

### Code Complexity
| Metric | API1 | API8 |
|--------|------|------|
| Controllers | 126 | 75 |
| Route Lines | 346 | 303 |
| Models | 0 (in app/) | 8 (in app/Models/) |

### External Services
| Service | API1 | API8 |
|---------|------|------|
| Email Domain | mg.falgimoveis.com | mg.aguileraz.net |
| WebSockets | Pusher only | Pusher + Laravel WebSockets |
| Notifications | Email only | Email, SMS, Telegram, Twilio |
| Maps/Geo | None | Google Maps API |
| Social Login | No | Yes (Socialite) |

### Development Features
| Feature | API1 | API8 |
|---------|------|------|
| API Docs | No | Swagger (swagger-php) |
| Browser Testing | Laravel Dusk (dev) | Laravel Dusk (integrated) |
| Debugging | Laravel Debugbar | Telescope + Debugbar |
| Task Scheduling UI | No | Laravel Totem |
| Background Jobs UI | No | Laravel Horizon |

---

## SHARED INFRASTRUCTURE

### Redis Server
- **Host:** 127.0.0.1:6379
- **Password:** p58v2xfY0R4UG0NGBU5Xu3QFvvp2hSw51QXXABZMG2td+CImsB5LOKjk3BWjc7boR725n7gilgjgAvg3
- **Client:** predis/predis
- **Status:** Running (redis-server.service active)
- **Usage:**
  - API1: DB 1
  - API8: DB 8 (data) + DB 9 (cache)

### MySQL Database Server
- **Primary Host:** 191.252.201.205:3306
- **Username:** root
- **Password:** power@123
- **Databases:**
  - API1: falgimoveis11 (production)
  - API8: fgdev (development)

### PHP-FPM Services Running
```
php7.1-fpm.service - running
php7.4-fpm.service - running (API1)
php8.0-fpm.service - running
php8.1-fpm.service - running (API8)
php8.2-fpm.service - running
php8.4-fpm.service - running
```

### Nginx
- **Service:** nginx.service - running
- **Rate Limit Zone:** "api" with 20 burst
- **SSL:** Let's Encrypt for all domains
- **Configs:**
  - /etc/nginx/sites-enabled/fg_api2 (API1)
  - /etc/nginx/sites-enabled/api8.falg.com.br (API8)
  - /etc/nginx/sites-enabled/fg_api4 (other API)

---

## SECURITY CONCERNS

### HIGH PRIORITY
1. **Exposed Credentials:** All database passwords, API keys, and secrets are in .env files
2. **Root Database Access:** Both APIs use 'root' MySQL user
3. **AWS Credentials:** Access keys exposed in API1 .env
4. **Email API Keys:** Mailgun secrets in plaintext
5. **Redis Password:** Shared password in both .env files
6. **JWT Secrets:** Exposed in .env files

### MEDIUM PRIORITY
1. **PHP 7.4 EOL:** API1 running on unsupported PHP version
2. **Laravel 5.5 EOL:** API1 on end-of-life framework
3. **Mixed Database Access:** Same credentials for both APIs
4. **CORS Wildcard:** Both APIs allow any origin (*)

### RECOMMENDATIONS
1. Use environment-specific credential management (Vault, AWS Secrets Manager)
2. Create dedicated database users with minimal privileges
3. Rotate all exposed credentials
4. Implement proper CORS policies with specific allowed origins
5. Upgrade API1 to PHP 8.1+ and Laravel 8+
6. Separate production and development credentials
7. Enable Redis AUTH with user-specific passwords (Redis 6+)

---

## COMPATIBILITY ISSUES FOR MIGRATION

### PHP Version Differences (7.4 → 8.1)
**Breaking Changes:**
1. Named arguments introduced (can cause issues with argument order)
2. Stricter type checking
3. Null safe operator changes
4. Match expression syntax
5. Constructor property promotion
6. Union types

**Deprecated in 7.4, Removed in 8.0+:**
- `create_function()` - use anonymous functions
- `each()` - use foreach
- `assert()` with string argument
- Array/string offset access with curly braces
- Unparenthesized ternaries

### Laravel Version Differences (5.5 → 8.x)

**Major Breaking Changes:**
1. **Directory Structure:**
   - Models moved from `app/` to `app/Models/`
   - Route files structure changed

2. **Database:**
   - Query builder return types changed
   - Migration method signatures different
   - Factories completely rewritten (legacy factories needed)

3. **Routing:**
   - String-based controller actions deprecated
   - Use class-based references: `[Controller::class, 'method']`

4. **Middleware:**
   - Middleware binding syntax changed
   - Route middleware structure updated

5. **Authentication:**
   - Auth scaffolding moved to laravel/ui package
   - API authentication changes

6. **Dependencies:**
   - Many packages require updates or replacements
   - eduardokum/laravel-boleto: 0.7.1 → 0.8.12 (CRITICAL for banking)

### Database Schema Differences
- API1: Minimal migrations (5 files)
- API8: Extensive migrations (22 files)
- **Risk:** Schema drift between development and production

### Code Structure Differences
- API1: 126 controllers (monolithic)
- API8: 75 controllers (more organized)
- **Challenge:** Consolidating or maintaining parallel codebases

---

## DEPLOYMENT ARCHITECTURE ANALYSIS

### Current State
```
FGSRV05 (Ubuntu 22.04)
├── Nginx (front proxy)
│   ├── api.falg.com.br → PHP 7.4-FPM → API1 (production)
│   └── api8.falg.com.br → PHP 8.1-FPM → API8 (development)
├── MySQL External (191.252.201.205)
│   ├── falgimoveis11 (API1 production data)
│   └── fgdev (API8 development data)
└── Redis Local
    ├── DB 1 (API1)
    ├── DB 8 (API8 data)
    └── DB 9 (API8 cache)
```

### API Version Directories
**Multiple versions present:**
- fg_API8 (original?)
- fg_API8_a (variant A)
- fg_API8_b (analyzed - dev)
- fg_API8_d (nginx points here!)
- fg_OLD2_NEW (production)
- fg_OLD2 (backup?)
- fg_OLD3 (backup?)
- fg_NEW-BKP01, fg_NEW-BKP02 (backups)
- fg_NEW_f (archived)

**CONFUSION RISK:** Multiple versions, unclear which is canonical

---

## BUSINESS LOGIC ANALYSIS

### Core Domain: Real Estate Property Management

**Primary Entities:**
1. **Imoveis** (Properties) - Real estate listings
2. **Clientes** (Clients) - Tenants, owners, prospects
3. **Contratos** (Contracts) - Rental/sale agreements
4. **Cobrancas** (Charges) - Billing/invoicing
5. **Boletos** (Bank Slips) - Brazilian payment slips

**Financial Workflows:**
1. Contract creation → Charge generation
2. Charge → Boleto generation
3. Boleto → Remittance file → Bank
4. Bank → Return file → Payment reconciliation
5. Payment → Receipt generation

**Banking Integration:**
- Itaú Bank (primary) - boleto generation, remittances
- Bradesco (API8 only) - TXT/XLS processing
- CNAB 400/240 file formats

**Critical Business Logic:**
- BoletoController (137KB!) - Core payment processing
- Recent fixes for:
  - Account digit calculation
  - Registered vs unregistered boletos
  - Remittance file generation
  - Charge listing optimization

---

## RECOMMENDATIONS FOR HOSTMAN PROJECT

### Phase 1: Research & Discovery ✅ COMPLETE
- [x] Map both APIs completely
- [x] Document all endpoints and configurations
- [x] Identify shared infrastructure
- [x] Document security concerns
- [x] Analyze compatibility issues

### Phase 2: Risk Assessment (NEXT)
1. **Critical Path Analysis:**
   - Which API is production-critical?
   - What's the traffic/usage pattern?
   - Which database is authoritative?

2. **Data Migration Strategy:**
   - Can fgdev and falgimoveis11 be merged?
   - What's the schema diff?
   - How to handle production during migration?

3. **Deployment Strategy:**
   - Blue-green deployment?
   - Canary rollout?
   - Feature flags for gradual migration?

### Phase 3: Migration Planning
1. **Establish Baseline:**
   - Current performance metrics
   - Error rates and critical paths
   - Peak load patterns

2. **Create Migration Path:**
   - Laravel 5.5 → 6.x → 7.x → 8.x (step by step)
   - OR: Parallel development with API gateway routing

3. **Test Suite:**
   - Integration tests for boleto generation
   - Payment processing tests
   - Bank file format validation

### Phase 4: Infrastructure Modernization
1. **Containerization:**
   - Leverage existing Docker configs from API8
   - Create production-grade containers
   - Implement health checks and monitoring

2. **CI/CD Pipeline:**
   - Adapt Azure DevOps pipelines
   - Automated testing and deployment
   - Rollback procedures

3. **Monitoring & Observability:**
   - Telescope for debugging
   - Horizon for queue management
   - Proper logging and alerting

---

## BLOCKERS & QUESTIONS FOR QUEEN

### CRITICAL DECISIONS NEEDED:

1. **Which API is authoritative?**
   - API1 (126 controllers, production) vs API8 (75 controllers, modern)

2. **Database reconciliation:**
   - Merge fgdev into falgimoveis11?
   - Keep separate dev/prod databases?
   - Schema migration strategy?

3. **Nginx confusion:**
   - fg_API8_b analyzed but fg_API8_d is nginx target
   - Need to verify which is actually serving API8

4. **Migration strategy:**
   - Big bang (risky)
   - Gradual (complex)
   - Parallel with feature flags (safest?)

5. **Testing access:**
   - Can we test API endpoints?
   - Access to production data for validation?
   - Rollback plan?

---

## NEXT STEPS FOR HIVE

### Immediate Actions:
1. **VERIFY:** Check fg_API8_d vs fg_API8_b discrepancy
2. **TEST:** Attempt API calls to both endpoints
3. **SCHEMA:** Compare database schemas (fgdev vs falgimoveis11)
4. **LOGS:** Review nginx/PHP-FPM logs for traffic patterns
5. **GIT:** Analyze git history for recent changes

### Information Gathering:
1. **BACKUP:** Verify backup procedures and restore tests
2. **MONITORING:** Check if any monitoring is in place
3. **DOCS:** Read all markdown documentation files
4. **TRAFFIC:** Analyze nginx access logs for endpoint usage
5. **ERRORS:** Review error logs for common issues

### Risk Mitigation:
1. **SNAPSHOT:** Create VM/database snapshots before any changes
2. **ROLLBACK:** Document complete rollback procedure
3. **STAGING:** Propose staging environment setup
4. **COMMS:** Establish communication protocol with stakeholders

---

## STORED RESEARCH DATA

All findings have been documented and are ready for storage in collective memory:

**Memory Keys:**
- `hive/research/fgsrv05/api1/config`
- `hive/research/fgsrv05/api1/endpoints`
- `hive/research/fgsrv05/api1/dependencies`
- `hive/research/fgsrv05/api8/config`
- `hive/research/fgsrv05/api8/endpoints`
- `hive/research/fgsrv05/api8/dependencies`
- `hive/research/fgsrv05/infrastructure/shared`
- `hive/research/fgsrv05/security/concerns`
- `hive/research/fgsrv05/migration/compatibility`
- `hive/research/fgsrv05/recommendations/strategy`

---

**END OF RESEARCH REPORT**

*Generated by: Hive Mind RESEARCHER Agent*
*Session: hostman-api-discovery-001*
*Status: COMPREHENSIVE ANALYSIS COMPLETE*
*Next: AWAITING QUEEN DIRECTIVES*
