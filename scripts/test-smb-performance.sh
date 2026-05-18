#!/bin/bash
# SMB Performance Test Script
# Tests file transfer speeds to CT178 file server

set -e

SERVER="192.168.0.178"
SHARE="overpower"
MOUNT_POINT="/mnt/smb-test"
TEST_SIZE_MB=1000  # 1GB test file

echo "=== CT178 SMB Performance Test ==="
echo "Server: $SERVER"
echo "Share: $SHARE"
echo "Test file size: ${TEST_SIZE_MB}MB"
echo ""

# Create mount point
mkdir -p "$MOUNT_POINT"

# Mount SMB share
echo "Mounting SMB share..."
if ! mount -t cifs //$SERVER/$SHARE "$MOUNT_POINT" -o guest,vers=3.1.1,cache=strict,actimeo=60; then
    echo "❌ Failed to mount SMB share"
    exit 1
fi

echo "✅ SMB share mounted"
echo ""

# Create test file
echo "Creating ${TEST_SIZE_MB}MB test file..."
TEST_FILE="/tmp/smb-test-file.bin"
dd if=/dev/zero of="$TEST_FILE" bs=1M count=$TEST_SIZE_MB 2>&1 | tail -1

echo ""
echo "=== Upload Test (Write to SMB) ==="
START=$(date +%s.%N)
cp "$TEST_FILE" "$MOUNT_POINT/test-upload.bin"
sync
END=$(date +%s.%N)

UPLOAD_TIME=$(echo "$END - $START" | bc)
UPLOAD_SPEED=$(echo "scale=2; $TEST_SIZE_MB / $UPLOAD_TIME" | bc)

echo "Upload time: ${UPLOAD_TIME}s"
echo "Upload speed: ${UPLOAD_SPEED} MB/s"
echo ""

echo "=== Download Test (Read from SMB) ==="
# Clear cache
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

START=$(date +%s.%N)
cp "$MOUNT_POINT/test-upload.bin" /tmp/test-download.bin
sync
END=$(date +%s.%N)

DOWNLOAD_TIME=$(echo "$END - $START" | bc)
DOWNLOAD_SPEED=$(echo "scale=2; $TEST_SIZE_MB / $DOWNLOAD_TIME" | bc)

echo "Download time: ${DOWNLOAD_TIME}s"
echo "Download speed: ${DOWNLOAD_SPEED} MB/s"
echo ""

# Cleanup
echo "Cleaning up..."
rm -f "$TEST_FILE" /tmp/test-download.bin "$MOUNT_POINT/test-upload.bin"
umount "$MOUNT_POINT"

echo ""
echo "=== Summary ==="
echo "Upload:   ${UPLOAD_SPEED} MB/s"
echo "Download: ${DOWNLOAD_SPEED} MB/s"
echo ""

# Calculate improvement percentage (baseline 210 MB/s)
BASELINE=210
if (( $(echo "$UPLOAD_SPEED > $BASELINE" | bc -l) )); then
    IMPROVEMENT=$(echo "scale=1; ($UPLOAD_SPEED - $BASELINE) / $BASELINE * 100" | bc)
    echo "🚀 Improvement: +${IMPROVEMENT}% faster than before!"
else
    echo "⚠️ Speed similar to baseline (${BASELINE} MB/s)"
fi

echo ""
echo "✅ Test complete!"
