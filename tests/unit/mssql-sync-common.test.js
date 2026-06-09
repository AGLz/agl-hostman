'use strict';

const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '../..');

const requiredFiles = [
  'config/mssql-sync/mssql-sync.env.example',
  'scripts/mssql-sync/_mssql-sync-common.sh',
  'scripts/mssql-sync/inventory.sh',
  'scripts/mssql-sync/enable-sqlagent-ct610.sh',
  'scripts/mssql-sync/apply-repl-logins.sh',
  'scripts/mssql-sync/deploy-symmetricds.sh',
  'scripts/mssql-sync/monitor-sync.sh',
  'scripts/mssql-sync/create-repl-logins.sql',
  'docker/mssql-sync/docker-compose.yml',
  'docs/maint/MSSQL-SYNC-AGLSRV6-INVENTORY.md',
  'docs/maint/MSSQL-SYNC-AGLSRV6-ARCHITECTURE.md',
  'docs/maint/MSSQL-DR-RUNBOOK-AGLSRV6.md',
];

for (const rel of requiredFiles) {
  test(`mssql-sync: existe ${rel}`, () => {
    assert.ok(fs.existsSync(path.join(ROOT, rel)));
  });
}

test('mssql-sync common carrega credenciais ald-sys8', () => {
  const content = fs.readFileSync(
    path.join(ROOT, 'scripts/mssql-sync/_mssql-sync-common.sh'),
    'utf8',
  );
  assert.match(content, /ald-sys8\/src\/\.env/);
  assert.match(content, /DB_PASSWORD_SYS/);
});

test('mssql-sync sqlcmd usa SQLCMDPASSWORD em vez de -P', () => {
  const common = fs.readFileSync(
    path.join(ROOT, 'scripts/mssql-sync/_mssql-sync-common.sh'),
    'utf8',
  );
  const apply = fs.readFileSync(
    path.join(ROOT, 'scripts/mssql-sync/apply-repl-logins.sh'),
    'utf8',
  );
  assert.match(common, /SQLCMDPASSWORD/);
  assert.doesNotMatch(common, /-P \"/);
  assert.match(apply, /envsubst/);
});

test('mssql-sync env example documenta VM620 SA distinto', () => {
  const content = fs.readFileSync(
    path.join(ROOT, 'config/mssql-sync/mssql-sync.env.example'),
    'utf8',
  );
  assert.match(content, /MSSQL_VM620_SA_PASSWORD/);
  assert.match(content, /MSSQL_CT610_SA_PASSWORD/);
  assert.match(content, /repl_mssql/);
});

test('create-repl-logins cobre bases piloto', () => {
  const sql = fs.readFileSync(
    path.join(ROOT, 'scripts/mssql-sync/create-repl-logins.sql'),
    'utf8',
  );
  for (const db of ['SILD', 'ALD-SYS8', 'DB_IDE_Associacao', 'CEP_Brasil']) {
    assert.match(sql, new RegExp(`\\[${db.replace('-', '\\-')}\\]`));
  }
});

test('scripts mssql-sync são executáveis', () => {
  for (const script of [
    'inventory.sh',
    'enable-sqlagent-ct610.sh',
    'apply-repl-logins.sh',
    'deploy-symmetricds.sh',
    'monitor-sync.sh',
  ]) {
    const p = path.join(ROOT, 'scripts/mssql-sync', script);
    assert.ok(fs.statSync(p).mode & 0o111, `${script} deve ser executável`);
  }
});
