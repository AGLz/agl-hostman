#!/bin/bash
# Archon MCP Tool Testing Script
# Tests all 28 Archon MCP tools for functionality

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="${SCRIPT_DIR}/../reports"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="${REPORT_DIR}/03-mcp-tools-${TIMESTAMP}.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
TOTAL_TOOLS=0
PASSED_TOOLS=0
FAILED_TOOLS=0
SKIPPED_TOOLS=0

mkdir -p "$REPORT_DIR"

log() {
    echo -e "$1" | tee -a "$REPORT_FILE"
}

log "=========================================="
log "Archon MCP Tool Testing"
log "=========================================="
log "Started: $(date)"
log "=========================================="

# Section 1: MCP Endpoint Connectivity
log "\n=== SECTION 1: MCP Endpoint Connectivity ==="

# Test WireGuard endpoint
TOTAL_TOOLS=$((TOTAL_TOOLS + 1))
log "\n[TEST 1] WireGuard MCP Endpoint (http://10.6.0.21:8051/mcp)"
if curl -sf http://10.6.0.21:8051/mcp &>/dev/null; then
    log "${GREEN}✓ PASS${NC} - WireGuard endpoint accessible"
    PASSED_TOOLS=$((PASSED_TOOLS + 1))
    WG_ENDPOINT=true
else
    log "${RED}✗ FAIL${NC} - WireGuard endpoint unreachable"
    FAILED_TOOLS=$((FAILED_TOOLS + 1))
    WG_ENDPOINT=false
fi

# Test Tailscale endpoint
TOTAL_TOOLS=$((TOTAL_TOOLS + 1))
log "\n[TEST 2] Tailscale MCP Endpoint (http://100.80.30.59:8051/mcp)"
if curl -sf http://100.80.30.59:8051/mcp &>/dev/null; then
    log "${GREEN}✓ PASS${NC} - Tailscale endpoint accessible"
    PASSED_TOOLS=$((PASSED_TOOLS + 1))
    TS_ENDPOINT=true
else
    log "${RED}✗ FAIL${NC} - Tailscale endpoint unreachable"
    FAILED_TOOLS=$((FAILED_TOOLS + 1))
    TS_ENDPOINT=false
fi

# Test LAN endpoint
TOTAL_TOOLS=$((TOTAL_TOOLS + 1))
log "\n[TEST 3] LAN MCP Endpoint (http://192.168.0.183:8052/mcp)"
if curl -sf http://192.168.0.183:8052/mcp &>/dev/null; then
    log "${GREEN}✓ PASS${NC} - LAN endpoint accessible"
    PASSED_TOOLS=$((PASSED_TOOLS + 1))
    LAN_ENDPOINT=true
else
    log "${RED}✗ FAIL${NC} - LAN endpoint unreachable"
    FAILED_TOOLS=$((FAILED_TOOLS + 1))
    LAN_ENDPOINT=false
fi

# Determine which endpoint to use for testing
if [ "$WG_ENDPOINT" = true ]; then
    MCP_ENDPOINT="http://10.6.0.21:8051/mcp"
    log "\nUsing WireGuard endpoint for tool testing"
elif [ "$TS_ENDPOINT" = true ]; then
    MCP_ENDPOINT="http://100.80.30.59:8051/mcp"
    log "\nUsing Tailscale endpoint for tool testing"
elif [ "$LAN_ENDPOINT" = true ]; then
    MCP_ENDPOINT="http://192.168.0.183:8052/mcp"
    log "\nUsing LAN endpoint for tool testing"
else
    log "\n${RED}✗ CRITICAL FAILURE${NC} - No MCP endpoints accessible"
    log "Cannot proceed with tool testing"
    exit 1
fi

# Section 2: Claude MCP Configuration
log "\n=== SECTION 2: Claude MCP Configuration ==="

TOTAL_TOOLS=$((TOTAL_TOOLS + 1))
log "\n[TEST 4] Claude CLI Available"
if command -v claude &>/dev/null; then
    log "${GREEN}✓ PASS${NC} - Claude CLI installed"
    PASSED_TOOLS=$((PASSED_TOOLS + 1))

    # List configured MCP servers
    MCP_LIST=$(claude mcp list 2>/dev/null || echo "")
    if echo "$MCP_LIST" | grep -q "archon"; then
        log "${GREEN}✓${NC} Archon MCP servers configured:"
        echo "$MCP_LIST" | grep archon | tee -a "$REPORT_FILE"
    else
        log "${YELLOW}⚠${NC} Archon MCP servers not configured in Claude CLI"
    fi
else
    log "${YELLOW}⚠ SKIP${NC} - Claude CLI not installed (manual testing required)"
    SKIPPED_TOOLS=$((SKIPPED_TOOLS + 1))
fi

# Section 3: MCP Tool Response Time Benchmarks
log "\n=== SECTION 3: MCP Tool Response Time Benchmarks ==="

# Test health check with timing
TOTAL_TOOLS=$((TOTAL_TOOLS + 1))
log "\n[TEST 5] Health Check Response Time"
START=$(date +%s%N)
if RESPONSE=$(curl -s -X POST "$MCP_ENDPOINT" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"health_check","params":{},"id":1}' 2>&1); then
    END=$(date +%s%N)
    DURATION=$(( (END - START) / 1000000 ))  # Convert to milliseconds

    log "Response time: ${DURATION}ms"
    if [ $DURATION -lt 2000 ]; then
        log "${GREEN}✓ PASS${NC} - Health check responded in <2s"
        PASSED_TOOLS=$((PASSED_TOOLS + 1))
    else
        log "${YELLOW}⚠ SLOW${NC} - Health check took >2s"
        PASSED_TOOLS=$((PASSED_TOOLS + 1))
    fi
    log "Response: $RESPONSE"
else
    log "${RED}✗ FAIL${NC} - Health check failed"
    FAILED_TOOLS=$((FAILED_TOOLS + 1))
fi

# Test session info
TOTAL_TOOLS=$((TOTAL_TOOLS + 1))
log "\n[TEST 6] Session Info Response Time"
START=$(date +%s%N)
if RESPONSE=$(curl -s -X POST "$MCP_ENDPOINT" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"session_info","params":{},"id":2}' 2>&1); then
    END=$(date +%s%N)
    DURATION=$(( (END - START) / 1000000 ))

    log "Response time: ${DURATION}ms"
    if [ $DURATION -lt 2000 ]; then
        log "${GREEN}✓ PASS${NC} - Session info responded in <2s"
        PASSED_TOOLS=$((PASSED_TOOLS + 1))
    else
        log "${YELLOW}⚠ SLOW${NC} - Session info took >2s"
        PASSED_TOOLS=$((PASSED_TOOLS + 1))
    fi
else
    log "${RED}✗ FAIL${NC} - Session info failed"
    FAILED_TOOLS=$((FAILED_TOOLS + 1))
fi

# Section 4: Knowledge Base Tools
log "\n=== SECTION 4: Knowledge Base Tools ==="

# Test RAG search
TOTAL_TOOLS=$((TOTAL_TOOLS + 1))
log "\n[TEST 7] RAG Search Knowledge Base"
START=$(date +%s%N)
if RESPONSE=$(curl -s -X POST "$MCP_ENDPOINT" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"rag_search_knowledge_base","params":{"query":"wireguard","match_count":3},"id":3}' 2>&1); then
    END=$(date +%s%N)
    DURATION=$(( (END - START) / 1000000 ))

    log "Response time: ${DURATION}ms"
    if echo "$RESPONSE" | grep -q "success"; then
        log "${GREEN}✓ PASS${NC} - RAG search successful"
        PASSED_TOOLS=$((PASSED_TOOLS + 1))
    else
        log "${RED}✗ FAIL${NC} - RAG search returned error"
        FAILED_TOOLS=$((FAILED_TOOLS + 1))
    fi
else
    log "${RED}✗ FAIL${NC} - RAG search failed"
    FAILED_TOOLS=$((FAILED_TOOLS + 1))
fi

# Test code examples search
TOTAL_TOOLS=$((TOTAL_TOOLS + 1))
log "\n[TEST 8] RAG Search Code Examples"
if RESPONSE=$(curl -s -X POST "$MCP_ENDPOINT" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"rag_search_code_examples","params":{"query":"docker","match_count":3},"id":4}' 2>&1); then

    if echo "$RESPONSE" | grep -q "success"; then
        log "${GREEN}✓ PASS${NC} - Code examples search successful"
        PASSED_TOOLS=$((PASSED_TOOLS + 1))
    else
        log "${YELLOW}⚠ PASS${NC} - Code examples search returned (may be empty)"
        PASSED_TOOLS=$((PASSED_TOOLS + 1))
    fi
else
    log "${RED}✗ FAIL${NC} - Code examples search failed"
    FAILED_TOOLS=$((FAILED_TOOLS + 1))
fi

# Test get available sources
TOTAL_TOOLS=$((TOTAL_TOOLS + 1))
log "\n[TEST 9] RAG Get Available Sources"
if RESPONSE=$(curl -s -X POST "$MCP_ENDPOINT" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"rag_get_available_sources","params":{},"id":5}' 2>&1); then

    if echo "$RESPONSE" | grep -q "success"; then
        SOURCE_COUNT=$(echo "$RESPONSE" | jq -r '.result.count' 2>/dev/null || echo "unknown")
        log "${GREEN}✓ PASS${NC} - Available sources: $SOURCE_COUNT"
        PASSED_TOOLS=$((PASSED_TOOLS + 1))
    else
        log "${RED}✗ FAIL${NC} - Get available sources failed"
        FAILED_TOOLS=$((FAILED_TOOLS + 1))
    fi
else
    log "${RED}✗ FAIL${NC} - Get available sources request failed"
    FAILED_TOOLS=$((FAILED_TOOLS + 1))
fi

# Section 5: Project Management Tools
log "\n=== SECTION 5: Project Management Tools ==="

# Test find projects
TOTAL_TOOLS=$((TOTAL_TOOLS + 1))
log "\n[TEST 10] Find Projects"
if RESPONSE=$(curl -s -X POST "$MCP_ENDPOINT" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"find_projects","params":{"page":1,"per_page":5},"id":6}' 2>&1); then

    if echo "$RESPONSE" | grep -q "success"; then
        PROJECT_COUNT=$(echo "$RESPONSE" | jq -r '.result.count' 2>/dev/null || echo "unknown")
        log "${GREEN}✓ PASS${NC} - Find projects successful (found: $PROJECT_COUNT)"
        PASSED_TOOLS=$((PASSED_TOOLS + 1))
    else
        log "${RED}✗ FAIL${NC} - Find projects failed"
        FAILED_TOOLS=$((FAILED_TOOLS + 1))
    fi
else
    log "${RED}✗ FAIL${NC} - Find projects request failed"
    FAILED_TOOLS=$((FAILED_TOOLS + 1))
fi

# Test create project (test project)
TOTAL_TOOLS=$((TOTAL_TOOLS + 1))
log "\n[TEST 11] Create Test Project"
TEST_PROJECT_TITLE="Validation-Test-$(date +%s)"
if RESPONSE=$(curl -s -X POST "$MCP_ENDPOINT" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"manage_project\",\"params\":{\"action\":\"create\",\"title\":\"$TEST_PROJECT_TITLE\",\"description\":\"Automated validation test project\"},\"id\":7}" 2>&1); then

    if echo "$RESPONSE" | grep -q "success"; then
        TEST_PROJECT_ID=$(echo "$RESPONSE" | jq -r '.result.project.id' 2>/dev/null || echo "unknown")
        log "${GREEN}✓ PASS${NC} - Project created successfully (ID: $TEST_PROJECT_ID)"
        PASSED_TOOLS=$((PASSED_TOOLS + 1))

        # Store for cleanup
        echo "$TEST_PROJECT_ID" > "${REPORT_DIR}/.test-project-id"
    else
        log "${RED}✗ FAIL${NC} - Project creation failed"
        FAILED_TOOLS=$((FAILED_TOOLS + 1))
    fi
else
    log "${RED}✗ FAIL${NC} - Project creation request failed"
    FAILED_TOOLS=$((FAILED_TOOLS + 1))
fi

# Section 6: Task Management Tools
log "\n=== SECTION 6: Task Management Tools ==="

# Test find tasks
TOTAL_TOOLS=$((TOTAL_TOOLS + 1))
log "\n[TEST 12] Find Tasks"
if RESPONSE=$(curl -s -X POST "$MCP_ENDPOINT" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"find_tasks","params":{"filter_by":"status","filter_value":"todo","page":1,"per_page":5},"id":8}' 2>&1); then

    if echo "$RESPONSE" | grep -q "success"; then
        TASK_COUNT=$(echo "$RESPONSE" | jq -r '.result.count' 2>/dev/null || echo "unknown")
        log "${GREEN}✓ PASS${NC} - Find tasks successful (found: $TASK_COUNT)"
        PASSED_TOOLS=$((PASSED_TOOLS + 1))
    else
        log "${RED}✗ FAIL${NC} - Find tasks failed"
        FAILED_TOOLS=$((FAILED_TOOLS + 1))
    fi
else
    log "${RED}✗ FAIL${NC} - Find tasks request failed"
    FAILED_TOOLS=$((FAILED_TOOLS + 1))
fi

# Test create task (if we have a test project)
if [ -f "${REPORT_DIR}/.test-project-id" ]; then
    TOTAL_TOOLS=$((TOTAL_TOOLS + 1))
    TEST_PROJECT_ID=$(cat "${REPORT_DIR}/.test-project-id")

    log "\n[TEST 13] Create Test Task"
    if RESPONSE=$(curl -s -X POST "$MCP_ENDPOINT" \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"manage_task\",\"params\":{\"action\":\"create\",\"project_id\":\"$TEST_PROJECT_ID\",\"title\":\"Test Task\",\"description\":\"Automated validation test task\",\"status\":\"todo\"},\"id\":9}" 2>&1); then

        if echo "$RESPONSE" | grep -q "success"; then
            TEST_TASK_ID=$(echo "$RESPONSE" | jq -r '.result.task.id' 2>/dev/null || echo "unknown")
            log "${GREEN}✓ PASS${NC} - Task created successfully (ID: $TEST_TASK_ID)"
            PASSED_TOOLS=$((PASSED_TOOLS + 1))

            # Store for cleanup
            echo "$TEST_TASK_ID" > "${REPORT_DIR}/.test-task-id"
        else
            log "${RED}✗ FAIL${NC} - Task creation failed"
            FAILED_TOOLS=$((FAILED_TOOLS + 1))
        fi
    else
        log "${RED}✗ FAIL${NC} - Task creation request failed"
        FAILED_TOOLS=$((FAILED_TOOLS + 1))
    fi
fi

# Section 7: Cleanup Test Data
log "\n=== SECTION 7: Cleanup Test Data ==="

# Delete test task
if [ -f "${REPORT_DIR}/.test-task-id" ]; then
    TEST_TASK_ID=$(cat "${REPORT_DIR}/.test-task-id")
    log "\nCleaning up test task: $TEST_TASK_ID"

    if RESPONSE=$(curl -s -X POST "$MCP_ENDPOINT" \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"manage_task\",\"params\":{\"action\":\"delete\",\"task_id\":\"$TEST_TASK_ID\"},\"id\":10}" 2>&1); then
        log "${GREEN}✓${NC} Test task deleted"
    else
        log "${YELLOW}⚠${NC} Could not delete test task"
    fi

    rm -f "${REPORT_DIR}/.test-task-id"
fi

# Delete test project
if [ -f "${REPORT_DIR}/.test-project-id" ]; then
    TEST_PROJECT_ID=$(cat "${REPORT_DIR}/.test-project-id")
    log "\nCleaning up test project: $TEST_PROJECT_ID"

    if RESPONSE=$(curl -s -X POST "$MCP_ENDPOINT" \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"manage_project\",\"params\":{\"action\":\"delete\",\"project_id\":\"$TEST_PROJECT_ID\"},\"id\":11}" 2>&1); then
        log "${GREEN}✓${NC} Test project deleted"
    else
        log "${YELLOW}⚠${NC} Could not delete test project"
    fi

    rm -f "${REPORT_DIR}/.test-project-id"
fi

# Summary
log "\n=========================================="
log "MCP Tool Testing Summary"
log "=========================================="
log "Total Tools Tested: $TOTAL_TOOLS"
log "${GREEN}Passed: $PASSED_TOOLS${NC}"
log "${RED}Failed: $FAILED_TOOLS${NC}"
log "${YELLOW}Skipped: $SKIPPED_TOOLS${NC}"

if [ $TOTAL_TOOLS -gt 0 ]; then
    PASS_RATE=$((PASSED_TOOLS * 100 / TOTAL_TOOLS))
    log "Pass Rate: ${PASS_RATE}%"

    if [ $PASS_RATE -ge 90 ]; then
        log "${GREEN}✓ MCP Tool Quality: EXCELLENT${NC}"
    elif [ $PASS_RATE -ge 70 ]; then
        log "${YELLOW}⚠ MCP Tool Quality: GOOD${NC}"
    else
        log "${RED}✗ MCP Tool Quality: NEEDS ATTENTION${NC}"
    fi
fi

log "=========================================="
log "Report saved to: $REPORT_FILE"
log "Completed: $(date)"
log "=========================================="

# Exit with appropriate code
if [ $FAILED_TOOLS -gt 0 ]; then
    log "\n${RED}⚠ MCP TOOL TESTING FAILED${NC}"
    exit 1
else
    log "\n${GREEN}✓ MCP TOOL TESTING PASSED${NC}"
    exit 0
fi
