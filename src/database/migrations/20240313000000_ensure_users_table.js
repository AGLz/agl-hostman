'use strict';

/**
 * Garante que a tabela users existe com schema compatível.
 * Compatível com schema Laravel existente.
 */
async function up(db) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
      name VARCHAR NOT NULL,
      email VARCHAR NOT NULL,
      email_verified_at DATETIME,
      password VARCHAR NOT NULL,
      remember_token VARCHAR,
      created_at DATETIME,
      updated_at DATETIME
    )
  `);
  db.exec('CREATE UNIQUE INDEX IF NOT EXISTS users_email_unique ON users (email)');
}

async function down(db) {
  db.exec('DROP TABLE IF EXISTS users');
}

module.exports = { up, down };
