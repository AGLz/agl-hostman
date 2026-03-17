#!/usr/bin/env node

/**
 * AGL Search MCP Server - Connection Validation
 * Tests PostgreSQL and pgvector connectivity
 */

import pg from 'pg';
import dotenv from 'dotenv';

dotenv.config();

async function testConnection() {
  const client = new pg.Client({
    connectionString: process.env.RUVECTOR_DATABASE_URL ||
      'postgresql://admin:agl_ruvector_2026@localhost:5433/agl_ruvector?sslmode=disable'
  });

  try {
    await client.connect();
    console.error('✅ PostgreSQL connection successful');
    console.error('📊 Testing pgvector extension...');

    const result = await client.query("SELECT extname FROM pg_extension WHERE extname = 'vector'");

    if (result.rows.length > 0 && result.rows[0].extname === 'vector') {
      console.error('✅ pgvector extension is available');

      // List tables
      const tables = await client.query(`
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
      `);
      console.error('📊 Tables found:', tables.rows.map(r => r.table_name).join(', '));
    } else {
      console.error('❌ pgvector extension not found');
      process.exit(1);
    }

    await client.end();
    console.error('\n✅ All validations passed!');
  } catch (error) {
    console.error('❌ Connection failed:', error.message);
    process.exit(1);
  }
}

testConnection().catch(err => {
  console.error('Connection test failed:', err);
  process.exit(1);
});
