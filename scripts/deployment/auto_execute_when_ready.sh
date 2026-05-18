#!/bin/bash
# Auto-execute AGLSRV1 recovery plan when server comes online
# Monitors server and executes all phases automatically

TARGET="AGLSRV1"
MAX_WAIT=600  # 10 minutes max wait
SLEEP_INTERVAL=10

echo "=================================="
echo "AUTO-EXECUTION MONITOR"
echo "=================================="
echo "Target: $TARGET (192.168.0.245)"
echo "Max wait: ${MAX_WAIT}s (~$(($MAX_WAIT/60)) minutes)"
echo "Check interval: ${SLEEP_INTERVAL}s"
echo ""

# Monitor function
wait_for_server() {
    echo ">>> Monitoring server availability..."
    ELAPSED=0

    while [ $ELAPSED -lt $MAX_WAIT ]; do
        echo -n "[$ELAPSED/${MAX_WAIT}s] Checking... "

        if ping -c 1 -W 2 192.168.0.245 &>/dev/null; then
            echo "✓ Server responding to ping"

            # Check SSH
            if ssh -o ConnectTimeout=5 -o BatchMode=yes $TARGET "echo OK" &>/dev/null; then
                echo "✓ SSH accessible"

                # Check Proxmox
                if ssh $TARGET "pveversion" &>/dev/null 2>&1; then
                    echo "✓ Proxmox services ready"
                    return 0
                else
                    echo "⏳ Proxmox services still starting..."
                fi
            else
                echo "⏳ SSH not ready yet..."
            fi
        else
            echo "⏳ Server not responding..."
        fi

        sleep $SLEEP_INTERVAL
        ELAPSED=$((ELAPSED + SLEEP_INTERVAL))
    done

    echo "✗ Timeout: Server did not come online within ${MAX_WAIT}s"
    return 1
}

# Execute phases
execute_phases() {
    echo ""
    echo "=================================="
    echo "SERVER ONLINE - EXECUTING PHASES"
    echo "=================================="
    echo ""

    # Phase 1: Cleanup
    echo ">>> PHASE 1: SURGICAL CLEANUP"
    echo "Starting at $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    if ssh $TARGET 'bash -s' < /root/host-admin/phase1_cleanup_surgical.sh; then
        echo ""
        echo "✓ PHASE 1: COMPLETE"

        # Phase 2: Optimization
        echo ""
        echo ">>> PHASE 2: OPTIMIZATION PLAN"
        echo "Starting at $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""

        if ssh $TARGET 'bash -s' < /root/host-admin/optimization_plan.sh; then
            echo ""
            echo "✓ PHASE 2: COMPLETE"

            # Phase 3: Verification
            echo ""
            echo ">>> PHASE 3: VERIFICATION"
            echo "Starting at $(date '+%Y-%m-%d %H:%M:%S')"
            echo ""

            if ssh $TARGET 'bash -s' < /root/host-admin/verify_backup_system.sh; then
                echo ""
                echo "✓ PHASE 3: COMPLETE"
                echo ""
                echo "=================================="
                echo "ALL PHASES COMPLETED SUCCESSFULLY"
                echo "=================================="
                echo "Completed at $(date '+%Y-%m-%d %H:%M:%S')"
                return 0
            else
                echo "✗ PHASE 3 FAILED"
                return 3
            fi
        else
            echo "✗ PHASE 2 FAILED"
            return 2
        fi
    else
        echo "✗ PHASE 1 FAILED"
        return 1
    fi
}

# Main execution
if wait_for_server; then
    execute_phases
    EXIT_CODE=$?

    echo ""
    echo "=================================="
    echo "EXECUTION SUMMARY"
    echo "=================================="

    case $EXIT_CODE in
        0)
            echo "Status: ✓ SUCCESS"
            echo "All phases completed successfully"
            echo ""
            echo "Next steps:"
            echo "1. Monitor next backup cycle"
            echo "2. Review backup schedule in Proxmox GUI"
            echo "3. Consider removing recovery-full if no longer needed"
            ;;
        1)
            echo "Status: ✗ FAILED AT PHASE 1 (Cleanup)"
            echo "Check logs above for errors"
            ;;
        2)
            echo "Status: ✗ FAILED AT PHASE 2 (Optimization)"
            echo "Phase 1 completed, but optimization failed"
            ;;
        3)
            echo "Status: ✗ FAILED AT PHASE 3 (Verification)"
            echo "Phases 1-2 completed, but verification failed"
            ;;
    esac

    exit $EXIT_CODE
else
    echo ""
    echo "=================================="
    echo "EXECUTION ABORTED"
    echo "=================================="
    echo "Server did not come online within timeout period"
    echo "You can run phases manually when server is ready"
    exit 99
fi
