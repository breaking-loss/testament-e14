#!/usr/bin/env bash
# setup/zfs-setup.sh (Optimized)

DISK="/dev/nvme0n1"
POOL="zpool"

set -euo pipefail

# Verify partitions exist
for part in "${DISK}p1" "${DISK}p2" "${DISK}p3"; do
  if [ ! -b "$part" ]; then
    echo "Error: $part not found. Run parted manually as per README 5a."
    exit 1
  fi
done

echo "==> Formatting EFI and Swap"
mkfs.fat -F 32 -n EFI "${DISK}p1"
swapoff "${DISK}p2" 2>/dev/null || true
mkswap -L swap "${DISK}p2"
swapon "${DISK}p2"

EFI_UUID=$(blkid -s UUID -o value "${DISK}p1")
SWAP_UUID=$(blkid -s UUID -o value "${DISK}p2")

echo "==> Creating ZFS pool: $POOL"
zpool create -f \
  -o ashift=12 \
  -O compression=zstd \
  -O atime=off \
  -O xattr=sa \
  -O acltype=posixacl \
  -O mountpoint=none \
  "$POOL" "${DISK}p3"

echo "==> Creating datasets"
zfs create -o mountpoint=legacy -o compression=off              "$POOL/Store"
zfs create -o mountpoint=legacy                                  "$POOL/Guix"
zfs create -o mountpoint=legacy -o com.sun:auto-snapshot=true   "$POOL/Config"
zfs create -o mountpoint=legacy -o com.sun:auto-snapshot=true   "$POOL/Home"
zfs create -o mountpoint=/boot                                   "$POOL/Boot"

echo "==> Authorizing keys for speed"
# [span_2](start_span)Ensure we have the nonguix key for binary blobs[span_2](end_span)
wget -q https://substitutes.nonguix.org/signing-key.pub -O /tmp/nonguix.pub
guix archive --authorize < /tmp/nonguix.pub

echo "==> Mounting under /mnt"
mount -t zfs "$POOL/Store"  /mnt
mkdir -p /mnt/{efi,home,etc,var/guix}
mount "${DISK}p1"            /mnt/efi
mount -t zfs "$POOL/Guix"   /mnt/var/guix
mount -t zfs "$POOL/Config" /mnt/etc
mount -t zfs "$POOL/Home"   /mnt/home

echo "==> Setup complete. Update config/thinkpad-e14.scm with:"
echo "    %efi-uuid  \"$EFI_UUID\""
echo "    %swap-uuid \"$SWAP_UUID\""
