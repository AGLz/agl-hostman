#!/usr/bin/env node
/**
 * Seed usuário de teste para testes manuais.
 * Insere user no database.sqlite (tabela users estilo Laravel).
 *
 * Uso: node scripts/seed-test-user.js
 * Credenciais: test@agl.local / password
 */

'use strict';

const path = require('path');
const Database = require('better-sqlite3');

const DB_PATH = path.join(__dirname, '../src/database/database.sqlite');

// Hash bcrypt de "password" (Laravel default) - compatível com PHP/Laravel
const PASSWORD_HASH = '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi';

const TEST_USER = {
  name: 'Test User',
  email: 'test@agl.local',
  email_verified_at: new Date().toISOString(),
  password: PASSWORD_HASH,
  remember_token: null,
  created_at: new Date().toISOString(),
  updated_at: new Date().toISOString(),
};

function seed() {
  const db = new Database(DB_PATH);

  const existing = db.prepare('SELECT id FROM users WHERE email = ?').get(TEST_USER.email);
  if (existing) {
    console.log('✓ Usuário test@agl.local já existe (id:', existing.id, ')');
    db.close();
    return;
  }

  db.prepare(`
    INSERT INTO users (name, email, email_verified_at, password, remember_token, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `).run(
    TEST_USER.name,
    TEST_USER.email,
    TEST_USER.email_verified_at,
    TEST_USER.password,
    TEST_USER.remember_token,
    TEST_USER.created_at,
    TEST_USER.updated_at
  );

  const row = db.prepare('SELECT id FROM users WHERE email = ?').get(TEST_USER.email);
  console.log('✓ Usuário de teste criado:');
  console.log('  Email: test@agl.local');
  console.log('  Senha: password');
  console.log('  ID:', row.id);
  db.close();
}

try {
  seed();
} catch (err) {
  console.error('Erro ao criar usuário:', err.message);
  process.exit(1);
}
