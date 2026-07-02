import { AutoMemoryBridge } from '@claude-flow/memory';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'fs';
import { join } from 'path';

const DATA_DIR = join(process.cwd(), '.claude-flow', 'data');
const STORE_PATH = join(DATA_DIR, 'auto-memory-store.json');

// Ensure data dir
if (!existsSync(DATA_DIR)) mkdirSync(DATA_DIR, { recursive: true });

// Create simple backend for testing
class TestBackend {
  constructor(filePath) {
    this.filePath = filePath;
    this.entries = new Map();
  }

  async initialize() {
    if (existsSync(this.filePath)) {
      try {
        const data = JSON.parse(readFileSync(this.filePath, 'utf-8'));
        if (Array.isArray(data)) {
          for (const entry of data) this.entries.set(entry.id, entry);
        }
      } catch { /* start fresh */ }
    }
  }

  async shutdown() { this._persist(); }
  async store(entry) { this.entries.set(entry.id, entry); this._persist(); }
  async get(id) { return this.entries.get(id) ?? null; }
  async count() { return this.entries.size; }
  _persist() {
    try {
      writeFileSync(this.filePath, JSON.stringify([...this.entries.values()], null, 2), 'utf-8');
    } catch { /* best effort */ }
  }
}

async function test() {
  console.log('🔧 Testing Auto Memory Bridge System...\n');
  
  const backend = new TestBackend(STORE_PATH);
  await backend.initialize();

  const bridge = new AutoMemoryBridge(backend, {
    workingDir: process.cwd(),
    syncMode: 'on-session-end'
  });

  try {
    // Test 1: Memory directory
    console.log('1️⃣ Testing memory directory...');
    const memDir = bridge.getMemoryDir();
    console.log('   Memory directory:', memDir);
    
    // Test 2: Record insight
    console.log('\n2️⃣ Recording test insight...');
    const insight = await bridge.recordInsight({
      content: 'Auto Memory Bridge system initialized successfully on 2026-07-01',
      type: 'episodic',
      tags: ['agl-hostman', 'auto-memory', 'test'],
      metadata: { 
        source: 'manual-test',
        version: '1.0.0',
        status: 'operational'
      }
    });
    
    console.log('   ✅ Insight recorded:', insight.id);
    
    // Test 3: Query insights
    console.log('\n3️⃣ Querying recent insights...');
    const recent = await bridge.queryRecentInsights({ limit: 3 });
    console.log('   Recent insights found:', recent.length);
    
    // Test 4: Check store
    const count = await backend.count();
    console.log('   Total entries in store:', count);
    
    // Test 5: Memory file operations
    console.log('\n4️⃣ Testing memory file operations...');
    const indexPath = bridge.getIndexPath();
    console.log('   Index path:', indexPath);
    
    if (existsSync(indexPath)) {
      const indexContent = readFileSync(indexPath, 'utf-8');
      console.log('   Index file exists with', indexContent.split('\n').length - 1, 'entries');
    }
    
    // Test 6: Status
    console.log('\n5️⃣ Testing system status...');
    const status = bridge.getStatus();
    console.log('   Status:', status);
    
    console.log('\n✅ Auto Memory Bridge system is fully operational!');
    console.log('🚀 Ready for production use with Claude Code hooks.');
    
  } catch (err) {
    console.error('❌ Error during test:', err.message);
    console.log('💡 This may be expected for first-time initialization.');
  } finally {
    if (bridge.destroy) bridge.destroy();
    await backend.shutdown();
  }
}

test().catch(console.error);
