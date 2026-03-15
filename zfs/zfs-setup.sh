#!/usr/bin/env bash
# setup/zfs-setup.sh
#
# Run this FROM A LIVE ENVIRONMENT (e.g. CachyOS live USB).
#
# IMPORTANT: Partitioning must be done MANUALLY before running this script.
# See README step 5a for exact parted commands.
#
# Expected partition layout on /dev/nvme0n1:
#   p1 — 512M   EFI  (FAT32)
#   p2 — 4G     Swap
#   p3 — rest   ZFS

DISK="/dev/nvme0n1"
POOL="zpool"

set -euo pipefail

# Verify partitions exist before proceeding
for part in "${DISK}p1" "${DISK}p2" "${DISK}p3"; do
  if [ ! -b "$part" ]; then
    echo "Error: $part not found. Did you repartition manually first?"
    echo "See README step 5a for instructions."
    exit 1
  fi
done

echo "==> Formatting EFI partition (${DISK}p1)"
mkfs.fat -F 32 -n EFI "${DISK}p1"

echo "==> Formatting swap partition (${DISK}p2)"
mkswap -L swap "${DISK}p2"
swapon "${DISK}p2"

EFI_UUID=$(blkid -s UUID -o value "${DISK}p1")
SWAP_UUID=$(blkid -s UUID -o value "${DISK}p2")
echo ""
echo "==> UUIDs (update these in config/thinkpad-e14.scm):"
echo "    %efi-uuid  \"$EFI_UUID\""
echo "    %swap-uuid \"$SWAP_UUID\""
echo ""

echo "==> Generating ZFS host ID"
zgenhostid

echo "==> Creating ZFS pool: $POOL on ${DISK}p3"
# -f forces creation even if the partition has old pool metadata
zpool create -f \
  -o ashift=12 \
  -O compression=zstd \
  -O atime=off \
  -O xattr=sa \
  -O acltype=posixacl \
  -O mountpoint=none \
  -O com.sun:auto-snapshot=false \
  "$POOL" "${DISK}p3"

echo "==> Creating datasets"
zfs create -o mountpoint=legacy -o compression=off              "$POOL/Store"
zfs create -o mountpoint=legacy                                  "$POOL/Guix"
zfs create -o mountpoint=legacy -o com.sun:auto-snapshot=true   "$POOL/Config"
zfs create -o mountpoint=legacy -o com.sun:auto-snapshot=true   "$POOL/Home"
zfs create -o mountpoint=/boot                                   "$POOL/Boot"
zfs create -o mountpoint=legacy                                  "$POOL/Log"
zfs create -o mountpoint=legacy                                  "$POOL/Tmp"
zfs create -o mountpoint=legacy                                  "$POOL/Data"
zfs create -o mountpoint=legacy -o com.sun:auto-snapshot=true   "$POOL/Data/Bluetooth"
zfs create -o mountpoint=legacy -o com.sun:auto-snapshot=true   "$POOL/Data/Tailscale"

echo "==> Authorizing substitute server keys"
wget -q https://substitutes.nonguix.org/signing-key.pub -O /tmp/nonguix.pub
guix archive --authorize < /tmp/nonguix.pub
echo "    nonguix key authorized"

echo "==> Mounting datasets under /mnt"
mount -t zfs "$POOL/Store"  /mnt
mkdir -p /mnt/{efi,home,etc,var/guix,var/log,var/tmp,var/lib}
mount "${DISK}p1"            /mnt/efi
mount -t zfs "$POOL/Guix"   /mnt/var/guix
mount -t zfs "$POOL/Config" /mnt/etc
mount -t zfs "$POOL/Home"   /mnt/home
mount -t zfs "$POOL/Log"    /mnt/var/log
mount -t zfs "$POOL/Tmp"    /mnt/var/tmp
mount -t zfs "$POOL/Data"   /mnt/var/lib

cp /etc/hostid /mnt/etc/hostid 2>/dev/null || true

echo ""
echo "==> All done. Now:"
echo "    1. Update config/thinkpad-e14.scm:"
echo "         (define %efi-uuid  \"$EFI_UUID\")"
echo "         (define %swap-uuid \"$SWAP_UUID\")"
echo ""
echo "    2. Run:"
echo "       guix system init config/thinkpad-e14.scm /mnt \\"
echo "         --substitute-urls='https://cache-cdn.guix.moe https://substitutes.nonguix.org https://ci.guix.gnu.org https://bordeaux.guix.gnu.org'"
