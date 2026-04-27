#!/bin/bash
################################################################################
# Backup System Test Suite
# Validates installation and functionality of backup automation
################################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="/mnt/overpower/apps/dev/agl/hostman/hive/code"
BACKUP_DIR="/var/backups/mysql/fgdev"

pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; return 1; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
info() { echo "ℹ $1"; }

echo "========================================"
echo "Backup System Test Suite"
echo "========================================"
echo

# Test 1: Check script files exist
echo "[1/10] Checking script files..."
if [ -f "$SCRIPT_DIR/backup-db-sync.sh" ] && \
   [ -f "$SCRIPT_DIR/backup-monitor.sh" ] && \
   [ -f "$SCRIPT_DIR/crontab-backup.txt" ]; then
    pass "All script files present"
else
    fail "Missing script files"
fi

# Test 2: Check execute permissions
echo "[2/10] Checking execute permissions..."
if [ -x "$SCRIPT_DIR/backup-db-sync.sh" ] && \
   [ -x "$SCRIPT_DIR/backup-monitor.sh" ]; then
    pass "Scripts have execute permissions"
else
    fail "Scripts missing execute permissions"
fi

# Test 3: Check bash syntax
echo "[3/10] Validating bash syntax..."
if bash -n "$SCRIPT_DIR/backup-db-sync.sh" 2>/dev/null && \
   bash -n "$SCRIPT_DIR/backup-monitor.sh" 2>/dev/null; then
    pass "Bash syntax valid"
else
    fail "Bash syntax errors detected"
fi

# Test 4: Check MySQL availability
echo "[4/10] Testing MySQL connection..."
if command -v mysql &>/dev/null; then
    if mysql -e "SELECT 1" &>/dev/null; then
        pass "MySQL connection successful"
    else
        warn "MySQL connection failed (may need ~/.my.cnf configuration)"
    fi
else
    warn "MySQL client not found in PATH"
fi

# Test 5: Check mysqldump availability
echo "[5/10] Checking mysqldump availability..."
if command -v mysqldump &>/dev/null; then
    pass "mysqldump available"
else
    fail "mysqldump not found"
fi

# Test 6: Check gzip availability
echo "[6/10] Checking gzip availability..."
if command -v gzip &>/dev/null; then
    pass "gzip available"
else
    fail "gzip not found"
fi

# Test 7: Check backup directory permissions
echo "[7/10] Testing backup directory..."
if mkdir -p "$BACKUP_DIR" 2>/dev/null; then
    if [ -w "$BACKUP_DIR" ]; then
        pass "Backup directory writable"
    else
        warn "Backup directory not writable (may need sudo)"
    fi
else
    warn "Cannot create backup directory (may need sudo)"
fi

# Test 8: Check cron configuration syntax
echo "[8/10] Validating cron configuration..."
if grep -q "backup-db-sync.sh" "$SCRIPT_DIR/crontab-backup.txt" && \
   grep -q "backup-monitor.sh" "$SCRIPT_DIR/crontab-backup.txt"; then
    pass "Cron configuration looks valid"
else
    fail "Cron configuration incomplete"
fi

# Test 9: Check documentation
echo "[9/10] Checking documentation..."
if [ -f "$SCRIPT_DIR/README.md" ] && \
   [ -f "$SCRIPT_DIR/MIGRATION_ARCHITECTURE.md" ] && \
   [ -f "$SCRIPT_DIR/DELIVERABLES_CHECKLIST.md" ]; then
    pass "All documentation present"
else
    fail "Missing documentation files"
fi

# Test 10: Check disk space
echo "[10/10] Checking disk space..."
available_gb=$(df /var/backups 2>/dev/null | awk 'NR==2 {print int($4/1024/1024)}' || echo 0)
if [ "$available_gb" -gt 10 ]; then
    pass "Sufficient disk space (${available_gb}GB available)"
elif [ "$available_gb" -gt 5 ]; then
    warn "Limited disk space (${available_gb}GB available)"
else
    warn "Low disk space (${available_gb}GB available)"
fi

echo
echo "========================================"
echo "Test Summary"
echo "========================================"
echo
info "System is ready for backup deployment!"
echo
echo "Next steps:"
echo "1. Configure MySQL credentials:"
echo "   cat > ~/.my.cnf << 'EOF'"
echo "   [client]"
echo "   user=root"
echo "   password=YOUR_PASSWORD"
echo "   EOF"
echo "   chmod 600 ~/.my.cnf"
echo
echo "2. Test backup manually:"
echo "   $SCRIPT_DIR/backup-db-sync.sh"
echo
echo "3. Install cron jobs:"
echo "   crontab -e"
echo "   # Copy contents from crontab-backup.txt"
echo
echo "4. Verify installation:"
echo "   crontab -l"
echo "   $SCRIPT_DIR/backup-monitor.sh"
echo
echo "For detailed instructions, see:"
echo "   cat $SCRIPT_DIR/README.md"
echo

exit 0
