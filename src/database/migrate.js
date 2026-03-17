#!/usr/bin/env node
/**
 * Migration runner para SQLite.
 * Uso: node src/database/migrate.js [up|down|status]
 */

'use strict';

const path = require('path');
const fs = require('fs');
const Database = require('better-sqlite3');

const DB_PATH = path.join(__dirname, 'database.sqlite');
const MIGRATIONS_DIR = path.join(__dirname, 'migrations');

function getDb() {
  return new Database(DB_PATH);
}

function ensureMigrationsTable(db) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS migrations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      migration VARCHAR NOT NULL,
      batch INTEGER NOT NULL
    )
  `);
}

function getRanMigrations(db) {
  const rows = db.prepare('SELECT migration FROM migrations ORDER BY batch').all();
  return rows.map((r) => r.migration);
}

function getMigrationFiles() {
  if (!fs.existsSync(MIGRATIONS_DIR)) return [];
  return fs
    .readdirSync(MIGRATIONS_DIR)
    .filter((f) => f.endsWith('.js'))
    .sort();
}

function getNextBatch(db) {
  const row = db.prepare('SELECT MAX(batch) as max FROM migrations').get();
  return (row?.max ?? 0) + 1;
}

async function runUp() {
  const db = getDb();
  ensureMigrationsTable(db);

  const ran = getRanMigrations(db);
  const files = getMigrationFiles();
  const pending = files.filter((f) => !ran.includes(f));

  if (pending.length === 0) {
    console.log('No migrations to run.');
    db.close();
    return;
  }

  const batch = getNextBatch(db);
  const insert = db.prepare('INSERT INTO migrations (migration, batch) VALUES (?, ?)');

  for (const file of pending) {
    const mod = require(path.join(MIGRATIONS_DIR, file));
    if (typeof mod.up === 'function') {
      await mod.up(db);
      insert.run(file, batch);
      console.log('  ✓', file);
    }
  }

  db.close();
  console.log(`Ran ${pending.length} migration(s).`);
}

async function runDown() {
  const db = getDb();
  ensureMigrationsTable(db);

  const ran = getRanMigrations(db);
  if (ran.length === 0) {
    console.log('No migrations to rollback.');
    db.close();
    return;
  }

  const lastFile = ran[ran.length - 1];
  const mod = require(path.join(MIGRATIONS_DIR, lastFile));
  if (typeof mod.down === 'function') {
    await mod.down(db);
  }
  db.prepare('DELETE FROM migrations WHERE migration = ?').run(lastFile);
  db.close();
  console.log('  ✓ Rolled back:', lastFile);
}

function runStatus() {
  const db = getDb();
  ensureMigrationsTable(db);

  const ran = getRanMigrations(db);
  const files = getMigrationFiles();
  const pending = files.filter((f) => !ran.includes(f));

  console.log('Migrations:');
  for (const f of files) {
    const status = ran.includes(f) ? '✓' : ' ';
    console.log(`  [${status}] ${f}`);
  }
  if (pending.length > 0) {
    console.log(`\n${pending.length} pending migration(s).`);
  }
  db.close();
}

const cmd = process.argv[2] || 'status';
(async () => {
  try {
    if (cmd === 'up') await runUp();
    else if (cmd === 'down') await runDown();
    else if (cmd === 'status') runStatus();
    else {
      console.error('Usage: node migrate.js [up|down|status]');
      process.exit(1);
    }
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
})();
