#!/usr/bin/env node
/**
 * Add Documentation Embeddings to RuVector
 * Scans docs directory and adds embeddings for AGL documentation
 */

import pg from 'pg';
import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';

dotenv.config();

const DOCS_PATH = process.env.AGL_DOCS_PATH || path.join(process.cwd(), '../../docs');
const DB_URL = process.env.RUVECTOR_DATABASE_URL ||
  'postgresql://admin:agl_ruvector_2026@localhost:5433/agl_ruvector?sslmode=disable';

const client = new pg.Client({ connectionString: DB_URL });

// Simple text hash for generating deterministic IDs
function hashText(text) {
  let hash = 0;
  for (let i = 0; i < text.length; i++) {
    const char = text.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash;
  }
  return Math.abs(hash).toString(16);
}

// Generate pseudo-embedding from text (placeholder - in production use real embeddings)
function generatePseudoEmbedding(text) {
  const embedding = new Array(1536).fill(0);
  const words = text.toLowerCase().split(/\s+/);

  words.forEach((word, idx) => {
    const seed = word.split('').reduce((a, c) => a + c.charCodeAt(0), 0);
    const pos = (seed * (idx + 1)) % 1536;
    embedding[pos] = Math.sin(seed * 0.1) * 0.5 + 0.5;
  });

  // Normalize
  const mag = Math.sqrt(embedding.reduce((a, b) => a + b * b, 0));
  return embedding.map(v => v / mag);
}

async function scanDocs(dir, files = []) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      await scanDocs(fullPath, files);
    } else if (entry.name.endsWith('.md')) {
      files.push(fullPath);
    }
  }
  return files;
}

async function addEmbedding(namespace, key, content, metadata = {}) {
  const embedding = generatePseudoEmbedding(content);
  const embeddingStr = `[${embedding.join(',')}]`;

  const query = `
    INSERT INTO ruvector_embeddings (namespace, key, content, embedding, metadata)
    VALUES ($1, $2, $3, $4::vector, $5)
    ON CONFLICT (namespace, key) DO UPDATE SET
      content = EXCLUDED.content,
      embedding = EXCLUDED.embedding,
      metadata = EXCLUDED.metadata,
      created_at = NOW()
    RETURNING id
  `;

  const result = await client.query(query, [namespace, key, content, embeddingStr, metadata]);
  return result.rows[0].id;
}

async function main() {
  console.error('📚 Scanning documentation directory:', DOCS_PATH);

  await client.connect();
  console.error('✅ Connected to PostgreSQL');

  const docFiles = await scanDocs(DOCS_PATH);
  console.error(`📄 Found ${docFiles.length} markdown files`);

  let added = 0;
  let errors = 0;

  for (const file of docFiles) {
    try {
      const content = fs.readFileSync(file, 'utf8');
      const relativePath = path.relative(DOCS_PATH, file);
      const key = `doc:${hashText(content)}:${relativePath}`;

      // Skip very large files (> 50KB)
      if (content.length > 50000) {
        console.error(`⚠️  Skipping large file: ${relativePath}`);
        continue;
      }

      // Extract title from first heading
      const titleMatch = content.match(/^#\s+(.+)$/m);
      const title = titleMatch ? titleMatch[1] : path.basename(file, '.md');

      await addEmbedding('agl-docs', key, content, {
        source: 'docs',
        path: relativePath,
        title: title,
        size: content.length,
        indexed_at: new Date().toISOString()
      });

      added++;
      console.error(`✅ ${relativePath}`);
    } catch (err) {
      errors++;
      console.error(`❌ ${file}: ${err.message}`);
    }
  }

  // Add some example code patterns
  const codePatterns = [
    {
      key: 'pattern:postgres-connection',
      content: 'PostgreSQL connection with pgvector for semantic search using HNSW indexing',
      metadata: { category: 'database', type: 'pattern' }
    },
    {
      key: 'pattern:wireguard-setup',
      content: 'WireGuard VPN mesh configuration with Tailscale fallback for AGL infrastructure',
      metadata: { category: 'networking', type: 'pattern' }
    },
    {
      key: 'pattern:docker-compose',
      content: 'Docker Compose configuration for running PostgreSQL with pgvector extension in container',
      metadata: { category: 'containers', type: 'pattern' }
    },
    {
      key: 'pattern:mcp-server',
      content: 'MCP server implementation providing semantic search, code search, and documentation search tools',
      metadata: { category: 'ai', type: 'pattern' }
    },
    {
      key: 'pattern:proxmox-ct',
      content: 'Proxmox container management via API including start, stop, restart, and status monitoring',
      metadata: { category: 'infrastructure', type: 'pattern' }
    }
  ];

  for (const pattern of codePatterns) {
    await addEmbedding('agl-patterns', pattern.key, pattern.content, pattern.metadata);
    added++;
  }

  console.error(`\n📊 Summary:`);
  console.error(`   Added/Updated: ${added}`);
  console.error(`   Errors: ${errors}`);

  // Verify count
  const countResult = await client.query('SELECT namespace, COUNT(*) FROM ruvector_embeddings GROUP BY namespace');
  console.error('\n📊 Embeddings by namespace:');
  countResult.rows.forEach(row => {
    console.error(`   ${row.namespace}: ${row.count}`);
  });

  await client.end();
  console.error('\n✅ Done!');
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
