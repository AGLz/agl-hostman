#!/usr/bin/env bash
# Rename storage ct138-nfs → fileserver5-nfs on AGLSRV5
# Execute on AGLSRV5: ssh root@100.119.223.113 'bash -s' < scripts/storage-rename-ct138-to-fileserver5.sh
# Or copy and run directly on AGLSRV5

set -euo pipefail

OLD_NAME="ct138-nfs"
NEW_NAME="fileserver5-nfs"
OLD_PATH="/mnt/pve/${OLD_NAME}"
NEW_PATH="/mnt/pve/${NEW_NAME}"
BACKUP_SUFFIX="backup-rename-$(date +%Y%m%d-%H%M%S)"

echo "=== Storage Rename: ${OLD_NAME} → ${NEW_NAME} ==="

# Check if old storage exists (mounted or directory)
if ! mount | grep -q "${OLD_PATH}" && [[ ! -d "${OLD_PATH}" ]]; then
  echo "ERROR: ${OLD_PATH} not found (not mounted, no directory). Check storage.cfg."
  exit 1
fi

# Backup
echo "Creating backups..."
cp /etc/fstab "/etc/fstab.${BACKUP_SUFFIX}"
cp /etc/pve/storage.cfg "/etc/pve/storage.cfg.${BACKUP_SUFFIX}"

# Unmount
echo "Unmounting ${OLD_PATH}..."
umount "${OLD_PATH}" 2>/dev/null || true

# Rename directory (create if was only in fstab)
if [[ -d "${OLD_PATH}" ]]; then
  mv "${OLD_PATH}" "${NEW_PATH}"
  echo "Renamed ${OLD_PATH} → ${NEW_PATH}"
elif [[ ! -d "${NEW_PATH}" ]]; then
  mkdir -p "${NEW_PATH}"
  echo "Created ${NEW_PATH}"
fi

# Update fstab
sed -i "s|${OLD_NAME}|${NEW_NAME}|g; s|${OLD_PATH}|${NEW_PATH}|g" /etc/fstab
echo "Updated /etc/fstab"

# Update storage.cfg
sed -i "s|${OLD_NAME}|${NEW_NAME}|g; s|${OLD_PATH}|${NEW_PATH}|g" /etc/pve/storage.cfg
echo "Updated /etc/pve/storage.cfg"

# Remount
echo "Remounting ${NEW_PATH}..."
mount "${NEW_PATH}"

# Verify
echo ""
echo "=== Verification ==="
pvesm status -storage "${NEW_NAME}" 2>/dev/null || echo "pvesm: storage ${NEW_NAME}"
df -h | grep -E "fileserver5|${NEW_PATH}" || true
ls -la "${NEW_PATH}" | head -5

echo ""
echo "=== Done. Rename complete. ==="
