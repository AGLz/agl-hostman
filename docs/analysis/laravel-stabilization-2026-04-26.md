# Laravel Stabilization Notes - 2026-04-26

## Context

The project is being stabilized from the `agldv03` clone:

`/mnt/overpower/apps/dev/agl/agl-hostman`

The first pass focused on reducing duplicated routes, making the Node API safer, and getting the fast Node test suite green.

## Completed

- Extracted OpenClaw API routes to `src/routes/api/openclaw.php`.
- Removed duplicate OpenClaw route blocks from `src/routes/api.php`.
- Removed duplicate `mc-test` and `mc-test-public` route definitions from `src/routes/web.php`.
- Hardened Node API runtime behavior:
  - no global `NODE_TLS_REJECT_UNAUTHORIZED=0`
  - dynamic/native fetch support for Node 18+
  - configurable `RUFLO_COMMAND`
  - configurable CORS origin through `HOSTMAN_CORS_ORIGIN`
- Added `tests/unit/node-api-hardening.test.js`.
- Fixed quick-test blockers:
  - `config/openclaw/openclaw-litellm-client.jq` line endings/comments for host jq compatibility
  - `config/litellm/.env.example` missing `GROQ_API_KEY2`
  - invalid PHP interpolation in `Security/ComplianceChecker.php`
  - PHP 8.4 `use Mockery;` warnings promoted to errors

## Verified Before This Note

- `npm run test:node`: 41 passing, 0 failing.
- `php artisan route:list --path=openclaw`: 5 OpenClaw routes.
- `php artisan route:list`: route bootstrap succeeds.
- `php -l` on touched PHP files: syntax clean.

## Laravel Test Failure Themes

`composer test` progressed past bootstrap and executed the suite. The remaining failures were broad and clustered around:

- Security middleware tests receiving redirects instead of expected HTTP status codes.
- Test/default config drift:
  - session encryption default
  - auth rate-limiting config
  - auth verification config
  - database username default
  - env ignore expectations
- Authentication route drift:
  - `/logout` expected by tests, while the implemented route was under `/auth/logout`
  - `/admin/users` redirect target contained a stale login redirect before the intended dashboard redirect
- User factory default remember token differing from test expectations.

## Applied Follow-Up Fixes

- `src/config/session.php`: default `SESSION_ENCRYPT` to true.
- `src/config/database.php`: default MySQL username to `forge`, matching the test expectation.
- `src/config/auth.php`: added `rate_limiting`, `verification`, and `verification_routes` defaults.
- `src/database/factories/UserFactory.php`: default `remember_token` to null.
- `src/app/Http/Middleware/CheckRole.php`: use `$request->user()` for direct middleware tests.
- `src/app/Http/Middleware/CheckPermission.php`: use `$request->user()` for direct middleware tests.
- `src/app/Http/Middleware/CheckRole.php`: replaced redirect-oriented behavior with explicit `401`/`403` responses and deterministic `any`/`all` role parsing.
- `src/app/Http/Middleware/CheckPermission.php`: replaced redirect-oriented behavior with explicit `401`/`403` responses and Spatie-compatible permission checks.
- `src/routes/web.php`: added root `/logout` route and removed stale `/admin/users` login redirect.
- `src/.gitignore`: added `.env.local`.

## Next Validation Commands

Run on `agldv03`:

```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman
npm run test:node

cd /mnt/overpower/apps/dev/agl/agl-hostman/src
php artisan route:list --path=openclaw
php artisan test --testsuite=Unit --filter=Security --no-coverage
composer test
```

## Next Implementation Cuts

1. Stabilize Laravel security/auth tests until the security subset is green.
2. Split `src/routes/api.php` further by bounded area:
   - `n8n`
   - `scrum`
   - `infrastructure`
   - `deployment`
   - `rbac`
3. Consolidate GitHub Actions into fewer intent-based workflows.
4. Refactor oversized Laravel services one domain at a time, starting with security services.
5. Decide how to handle legacy Jest-style JS tests that are currently outside `npm run test:node`.
