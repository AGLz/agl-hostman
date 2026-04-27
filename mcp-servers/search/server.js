#!/usr/bin/env node
/**
 * AGL Search MCP Server
 *
 * Unified search tools for:
 * - Semantic search with HNSW (via ruv-swarm)
 * - Code search (grep patterns)
 * - Documentation search (RAG)
 * - Memory search (AgentDB)
 *
 * Integrates with:
 * - Claude-Flow memory system
 * - RuVector (if available)
 * - SQLite local database
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ErrorCode,
  McpError,
} from '@modelcontextprotocol/sdk/types.js';
import { exec } from 'child_process';
import { promisify } from 'util';
import { readFile, writeFile, access, readdir, stat } from 'fs/promises';
import { createRequire } from 'module';
import path from 'path';
import pg from 'pg';

const execAsync = promisify(exec);
const require = createRequire(import.meta.url);

// Configuration
const CONFIG = {
  projectRoot: process.env.AGL_PROJECT_ROOT || '/mnt/overpower/apps/dev/agl/agl-hostman',
  sqlitePath: process.env.AGL_SQLITE_PATH || path.join(process.env.AGL_PROJECT_ROOT || '/mnt/overpower/apps/dev/agl/agl-hostman', 'src/database/database.sqlite'),
  docsPath: process.env.AGL_DOCS_PATH || path.join(process.env.AGL_PROJECT_ROOT || '/mnt/overpower/apps/dev/agl/agl-hostman', 'docs'),
  hnswIndexPath: process.env.AGL_HNSW_INDEX_PATH || path.join(process.env.AGL_PROJECT_ROOT || '/mnt/overpower/apps/dev/agl/agl-hostman', '.agl/hnsw/index'),
  maxResults: parseInt(process.env.AGL_MAX_RESULTS || '50', 10),
  searchTimeout: parseInt(process.env.AGL_SEARCH_TIMEOUT || '30000', 10),
  // RuVector PostgreSQL Configuration
  ruvectorPg: {
    host: process.env.AGL_RUVECTOR_PG_HOST || 'localhost',
    port: parseInt(process.env.AGL_RUVECTOR_PG_PORT || '5433', 10),
    user: process.env.AGL_RUVECTOR_PG_USER || 'admin',
    password: process.env.AGL_RUVECTOR_PG_PASSWORD || 'agl_ruvector_2026',
    database: process.env.AGL_RUVECTOR_PG_DATABASE || 'agl_ruvector',
  },
};

// Lazy-loaded modules
let sqliteDb = null;
let hnswIndex = null;
let pgPool = null;

/**
 * Get or initialize PostgreSQL connection pool for RuVector
 */
function getPgPool() {
  if (!pgPool) {
    try {
      pgPool = new pg.Pool({
        host: CONFIG.ruvectorPg.host,
        port: CONFIG.ruvectorPg.port,
        user: CONFIG.ruvectorPg.user,
        password: CONFIG.ruvectorPg.password,
        database: CONFIG.ruvectorPg.database,
        max: 10,
        idleTimeoutMillis: 30000,
        connectionTimeoutMillis: 5000,
      });
      console.error('[RuVector PG] Pool created for', CONFIG.ruvectorPg.host + ':' + CONFIG.ruvectorPg.port);
    } catch (err) {
      console.error('[RuVector PG] Pool creation failed:', err.message);
      return null;
    }
  }
  return pgPool;
}

/**
 * Get or initialize SQLite database connection
 */
function getSqliteDb() {
  if (!sqliteDb) {
    try {
      const Database = require('better-sqlite3');
      sqliteDb = new Database(CONFIG.sqlitePath, { readonly: true, fileMustExist: false });
      sqliteDb.pragma('journal_mode = WAL');
    } catch (err) {
      console.error('[SQLite] Connection failed:', err.message);
      return null;
    }
  }
  return sqliteDb;
}

/**
 * Search RuVector PostgreSQL with pgvector (HNSW)
 */
async function searchRuVectorPg(query, options = {}) {
  const pool = getPgPool();
  if (!pool) {
    return { success: false, error: 'PostgreSQL pool not available', results: [], query };
  }

  const { k = 10, threshold = 0.0, namespace = null } = options;

  try {
    // First, try full-text search on content (since we may not have embeddings yet)
    const searchTerms = query.split(/\s+/).filter(t => t.length > 2).join(' & ');

    let sqlQuery;
    let params;

    if (namespace) {
      sqlQuery = `
        SELECT
          id, namespace, key, content, metadata, created_at,
          ts_rank_cd(to_tsvector('english', content), plainto_tsquery('english', $1)) as rank
        FROM ruvector_embeddings
        WHERE namespace = $2
          AND to_tsvector('english', content) @@ plainto_tsquery('english', $1)
        ORDER BY rank DESC
        LIMIT $3
      `;
      params = [query, namespace, k];
    } else {
      sqlQuery = `
        SELECT
          id, namespace, key, content, metadata, created_at,
          ts_rank_cd(to_tsvector('english', content), plainto_tsquery('english', $1)) as rank
        FROM ruvector_embeddings
        WHERE to_tsvector('english', content) @@ plainto_tsquery('english', $1)
        ORDER BY rank DESC
        LIMIT $2
      `;
      params = [query, k];
    }

    const result = await pool.query(sqlQuery, params);

    return {
      success: true,
      source: 'ruvector-pgvector',
      query,
      results: result.rows.map(row => ({
        id: row.id,
        namespace: row.namespace,
        key: row.key,
        content: row.content,
        metadata: row.metadata,
        created_at: row.created_at,
        score: parseFloat(row.rank) || 0,
        type: 'semantic-match',
      })),
      total: result.rows.length,
      namespace,
      k,
    };
  } catch (err) {
    return {
      success: false,
      source: 'ruvector-pgvector',
      error: err.message,
      results: [],
      query,
    };
  }
}

/**
 * Execute Claude-Flow memory search command
 */
async function searchClaudeFlowMemory(query, options = {}) {
  const limit = options.limit || 10;
  const namespace = options.namespace || '';

  try {
    let cmd = `npx @claude-flow/cli@latest memory search --query "${query.replace(/"/g, '\\"')}" --limit ${limit}`;
    if (namespace) {
      cmd += ` --namespace "${namespace}"`;
    }

    const { stdout, stderr } = await execAsync(cmd, {
      timeout: CONFIG.searchTimeout,
      cwd: CONFIG.projectRoot,
    });

    const output = stdout + stderr;

    // Parse JSON output from CLI
    try {
      const result = JSON.parse(output);
      return {
        success: true,
        source: 'claude-flow-memory',
        results: result.results || result.items || [],
        total: result.total || (result.results || result.items || []).length,
        query,
      };
    } catch {
      // Return raw output if not JSON
      return {
        success: true,
        source: 'claude-flow-memory',
        results: [{ content: output.trim(), type: 'raw' }],
        total: 1,
        query,
      };
    }
  } catch (err) {
    return {
      success: false,
      source: 'claude-flow-memory',
      error: err.message,
      results: [],
      query,
    };
  }
}

/**
 * Search SQLite database for stored patterns/memories
 */
async function searchSqliteMemory(query, options = {}) {
  const db = getSqliteDb();
  if (!db) {
    return { success: false, error: 'SQLite database not available', results: [] };
  }

  const limit = options.limit || 20;

  try {
    // Search in memory-related tables if they exist
    const tables = db.prepare("SELECT name FROM sqlite_master WHERE type='table'").all();
    const tableNames = tables.map(t => t.name);

    const results = [];

    // Check for common memory table patterns
    const memoryTables = ['memories', 'patterns', 'embeddings', 'sessions', 'agents', 'tasks'];
    const availableMemoryTables = memoryTables.filter(t => tableNames.includes(t));

    for (const table of availableMemoryTables) {
      try {
        // Get table info to find searchable columns
        const columns = db.pragma(`table_info(${table})`);
        const searchColumns = columns
          .filter(c => ['TEXT', 'VARCHAR'].includes(c.type?.toUpperCase()))
          .map(c => c.name);

        if (searchColumns.length === 0) continue;

        // Build search query
        const whereClause = searchColumns
          .map(col => `${col} LIKE ?`)
          .join(' OR ');

        const rows = db.prepare(`
          SELECT * FROM ${table}
          WHERE ${whereClause}
          LIMIT ?
        `).all(...searchColumns.map(() => `%${query}%`), limit);

        results.push(...rows.map(row => ({
          table,
          data: row,
          type: 'sqlite-record',
        })));
      } catch {
        // Skip table if query fails
      }
    }

    return {
      success: true,
      source: 'sqlite-memory',
      results,
      total: results.length,
      query,
      tables_searched: availableMemoryTables,
    };
  } catch (err) {
    return {
      success: false,
      source: 'sqlite-memory',
      error: err.message,
      results: [],
      query,
    };
  }
}

/**
 * Search code files using grep patterns
 */
async function searchCode(pattern, options = {}) {
  const {
    path: searchPath = CONFIG.projectRoot,
    fileType = '*',
    caseSensitive = false,
    context = 2,
    limit = 50,
  } = options;

  try {
    const grepArgs = [
      '-r',                          // recursive
      '-n',                          // line numbers
      caseSensitive ? '' : '-i',     // case insensitive
      `-C${context}`,                // context lines
      `--include=${fileType}`,       // file filter
      '-E',                          // extended regex
    ].filter(Boolean).join(' ');

    const cmd = `grep ${grepArgs} "${pattern.replace(/"/g, '\\"')}" "${searchPath}" 2>/dev/null | head -${limit}`;

    const { stdout } = await execAsync(cmd, {
      timeout: CONFIG.searchTimeout,
      maxBuffer: 10 * 1024 * 1024, // 10MB buffer
    });

    const lines = stdout.trim().split('\n').filter(Boolean);
    const results = lines.map(line => {
      // Parse grep output: filename:linenum:content
      const match = line.match(/^(.+?):(\d+):(.*)$/s);
      if (match) {
        return {
          file: match[1],
          line: parseInt(match[2], 10),
          content: match[3],
          type: 'code-match',
        };
      }
      return { raw: line, type: 'code-match' };
    });

    return {
      success: true,
      source: 'code-search',
      pattern,
      results,
      total: results.length,
      path: searchPath,
    };
  } catch (err) {
    // grep returns exit code 1 when no matches found
    if (err.code === 1 || err.stdout === '') {
      return {
        success: true,
        source: 'code-search',
        pattern,
        results: [],
        total: 0,
        path: searchPath,
      };
    }
    return {
      success: false,
      source: 'code-search',
      error: err.message,
      results: [],
      pattern,
    };
  }
}

/**
 * Search documentation files (RAG-style)
 */
async function searchDocs(query, options = {}) {
  const {
    path: docsPath = CONFIG.docsPath,
    limit = 20,
    includeContent = true,
  } = options;

  try {
    // Check if docs path exists
    await access(docsPath);

    // Read all markdown files
    const files = await readdir(docsPath);
    const mdFiles = files.filter(f => f.endsWith('.md'));

    const results = [];

    for (const file of mdFiles) {
      if (results.length >= limit) break;

      const filePath = path.join(docsPath, file);
      const content = await readFile(filePath, 'utf-8');
      const lowerContent = content.toLowerCase();
      const lowerQuery = query.toLowerCase();

      // Simple keyword matching (can be enhanced with embedding search)
      const score = calculateRelevanceScore(lowerContent, lowerQuery);

      if (score > 0) {
        // Find relevant excerpt
        const excerpt = findRelevantExcerpt(content, query, 200);

        results.push({
          file,
          path: filePath,
          score,
          excerpt: includeContent ? excerpt : null,
          type: 'doc-match',
        });
      }
    }

    // Sort by relevance score
    results.sort((a, b) => b.score - a.score);

    return {
      success: true,
      source: 'doc-search',
      query,
      results: results.slice(0, limit),
      total: Math.min(results.length, limit),
      path: docsPath,
    };
  } catch (err) {
    return {
      success: false,
      source: 'doc-search',
      error: err.message,
      results: [],
      query,
    };
  }
}

/**
 * Calculate simple relevance score based on keyword frequency
 */
function calculateRelevanceScore(content, query) {
  const keywords = query.split(/\s+/).filter(k => k.length > 2);
  let score = 0;

  for (const keyword of keywords) {
    const regex = new RegExp(keyword, 'gi');
    const matches = content.match(regex);
    if (matches) {
      score += matches.length;
    }
  }

  return score;
}

/**
 * Find relevant excerpt around query keywords
 */
function findRelevantExcerpt(content, query, maxLength = 200) {
  const keywords = query.split(/\s+/).filter(k => k.length > 2);
  const lowerContent = content.toLowerCase();

  let bestIndex = -1;
  let bestScore = 0;

  // Find the position with most keyword matches
  for (const keyword of keywords) {
    const index = lowerContent.indexOf(keyword.toLowerCase());
    if (index !== -1) {
      const contextStart = Math.max(0, index - 100);
      const contextEnd = Math.min(content.length, index + 100);
      const context = lowerContent.slice(contextStart, contextEnd);

      let score = 0;
      for (const kw of keywords) {
        if (context.includes(kw.toLowerCase())) score++;
      }

      if (score > bestScore) {
        bestScore = score;
        bestIndex = index;
      }
    }
  }

  if (bestIndex === -1) {
    return content.slice(0, maxLength) + '...';
  }

  const start = Math.max(0, bestIndex - Math.floor(maxLength / 2));
  const end = Math.min(content.length, start + maxLength);

  let excerpt = content.slice(start, end);
  if (start > 0) excerpt = '...' + excerpt;
  if (end < content.length) excerpt = excerpt + '...';

  return excerpt;
}

/**
 * Unified semantic search using HNSW
 * Priority: RuVector PostgreSQL + pgvector > Claude-Flow CLI fallback
 */
async function searchSemantic(query, options = {}) {
  const {
    k = 10,
    threshold = 0.0,
    namespace = null,
  } = options;

  // Try RuVector PostgreSQL first (fastest, most accurate)
  const ruvectorResult = await searchRuVectorPg(query, { k, threshold, namespace });
  if (ruvectorResult.success && ruvectorResult.results.length > 0) {
    return {
      ...ruvectorResult,
      threshold,
      k,
    };
  }

  // Fallback to Claude-Flow CLI
  try {
    const cmd = `npx @claude-flow/cli@latest memory search --query "${query.replace(/"/g, '\\"')}" --limit ${k} --threshold ${threshold}`;

    const { stdout, stderr } = await execAsync(cmd, {
      timeout: CONFIG.searchTimeout,
      cwd: CONFIG.projectRoot,
    });

    const output = stdout + stderr;

    try {
      const result = JSON.parse(output);
      return {
        success: true,
        source: 'semantic-hnsw',
        query,
        results: (result.results || result.items || []).map(item => ({
          ...item,
          type: 'semantic-match',
        })),
        total: result.total || (result.results || result.items || []).length,
        threshold,
        k,
        fallback: true,
      };
    } catch {
      return {
        success: true,
        source: 'semantic-hnsw',
        query,
        results: [{ content: output.trim(), type: 'raw' }],
        total: 1,
        fallback: true,
      };
    }
  } catch (err) {
    return {
      success: false,
      source: 'semantic-hnsw',
      error: err.message,
      results: [],
      query,
    };
  }
}

/**
 * Combined search across all sources
 */
async function searchAll(query, options = {}) {
  const results = await Promise.allSettled([
    searchSemantic(query, options),
    searchCode(query, options),
    searchDocs(query, options),
    searchClaudeFlowMemory(query, options),
    searchSqliteMemory(query, options),
  ]);

  const combined = {
    success: true,
    source: 'unified-search',
    query,
    results: {},
    total: 0,
  };

  const sources = ['semantic', 'code', 'docs', 'claude-flow-memory', 'sqlite-memory'];

  results.forEach((result, index) => {
    const source = sources[index];
    if (result.status === 'fulfilled') {
      combined.results[source] = result.value;
      combined.total += result.value.total || 0;
    } else {
      combined.results[source] = {
        success: false,
        error: result.reason?.message || 'Unknown error',
        results: [],
      };
    }
  });

  return combined;
}

// MCP Server setup
const server = new Server(
  {
    name: 'agl-search-mcp-server',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// List available tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: 'search_semantic',
        description: 'Semantic search using HNSW indexing (via Claude-Flow memory system). Best for finding conceptually similar content.',
        inputSchema: {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description: 'Search query (natural language or keywords)',
            },
            k: {
              type: 'number',
              description: 'Number of results to return (default: 10)',
              default: 10,
            },
            threshold: {
              type: 'number',
              description: 'Minimum similarity threshold 0-1 (default: 0.7)',
              default: 0.7,
            },
            namespace: {
              type: 'string',
              description: 'Memory namespace to search (default: default)',
              default: 'default',
            },
          },
          required: ['query'],
        },
      },
      {
        name: 'search_code',
        description: 'Search code files using grep patterns. Best for finding exact code matches, function names, or patterns.',
        inputSchema: {
          type: 'object',
          properties: {
            pattern: {
              type: 'string',
              description: 'Regex pattern to search for',
            },
            path: {
              type: 'string',
              description: 'Directory path to search (default: project root)',
            },
            fileType: {
              type: 'string',
              description: 'File type filter glob (default: *)',
              default: '*',
            },
            caseSensitive: {
              type: 'boolean',
              description: 'Case sensitive search (default: false)',
              default: false,
            },
            context: {
              type: 'number',
              description: 'Lines of context around matches (default: 2)',
              default: 2,
            },
            limit: {
              type: 'number',
              description: 'Maximum results (default: 50)',
              default: 50,
            },
          },
          required: ['pattern'],
        },
      },
      {
        name: 'search_docs',
        description: 'Search documentation files (RAG-style keyword matching). Best for finding information in markdown docs.',
        inputSchema: {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description: 'Search query for documentation',
            },
            path: {
              type: 'string',
              description: 'Docs directory path (default: project docs/)',
            },
            limit: {
              type: 'number',
              description: 'Maximum results (default: 20)',
              default: 20,
            },
            includeContent: {
              type: 'boolean',
              description: 'Include content excerpts (default: true)',
              default: true,
            },
          },
          required: ['query'],
        },
      },
      {
        name: 'search_memory',
        description: 'Search AgentDB memory (Claude-Flow + SQLite). Best for finding stored patterns, sessions, and agent data.',
        inputSchema: {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description: 'Search query for memory',
            },
            sources: {
              type: 'array',
              items: {
                type: 'string',
                enum: ['claude-flow', 'sqlite', 'all'],
              },
              description: 'Memory sources to search (default: all)',
              default: ['all'],
            },
            limit: {
              type: 'number',
              description: 'Maximum results per source (default: 20)',
              default: 20,
            },
            namespace: {
              type: 'string',
              description: 'Memory namespace (Claude-Flow only)',
            },
          },
          required: ['query'],
        },
      },
      {
        name: 'search_all',
        description: 'Unified search across all sources (semantic, code, docs, memory). Returns combined results from all search types.',
        inputSchema: {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description: 'Search query',
            },
            limit: {
              type: 'number',
              description: 'Maximum results per source (default: 20)',
              default: 20,
            },
            threshold: {
              type: 'number',
              description: 'Minimum similarity threshold for semantic search (default: 0.7)',
              default: 0.7,
            },
          },
          required: ['query'],
        },
      },
    ],
  };
});

// Handle tool execution
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  let result;

  switch (name) {
    case 'search_semantic':
      result = await searchSemantic(args.query, {
        k: args.k,
        threshold: args.threshold,
        namespace: args.namespace,
      });
      break;

    case 'search_code':
      result = await searchCode(args.pattern, {
        path: args.path,
        fileType: args.fileType,
        caseSensitive: args.caseSensitive,
        context: args.context,
        limit: args.limit,
      });
      break;

    case 'search_docs':
      result = await searchDocs(args.query, {
        path: args.path,
        limit: args.limit,
        includeContent: args.includeContent,
      });
      break;

    case 'search_memory':
      result = {
        success: true,
        source: 'memory-search',
        query: args.query,
        results: {},
      };

      const sources = args.sources?.includes('all')
        ? ['claude-flow', 'sqlite']
        : args.sources || ['all'];

      if (sources.includes('claude-flow') || sources.includes('all')) {
        const cfResult = await searchClaudeFlowMemory(args.query, {
          limit: args.limit,
          namespace: args.namespace,
        });
        result.results['claude-flow'] = cfResult;
      }

      if (sources.includes('sqlite') || sources.includes('all')) {
        const sqliteResult = await searchSqliteMemory(args.query, {
          limit: args.limit,
        });
        result.results['sqlite'] = sqliteResult;
      }

      result.total = Object.values(result.results).reduce(
        (sum, r) => sum + (r.total || 0),
        0
      );
      break;

    case 'search_all':
      result = await searchAll(args.query, {
        limit: args.limit,
        threshold: args.threshold,
      });
      break;

    default:
      throw new McpError(ErrorCode.MethodNotFound, `Unknown tool: ${name}`);
  }

  return {
    content: [
      {
        type: 'text',
        text: JSON.stringify(result, null, 2),
      },
    ],
  };
});

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('[AGL Search MCP Server] Started');
}

main().catch((error) => {
  console.error('[AGL Search MCP Server] Fatal error:', error);
  process.exit(1);
});
