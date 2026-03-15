#!/usr/bin/env bash
# setup/zfs-setup.sh
#
# Run this from the Testament live CD AFTER booting it.
# Sets up partitions and ZFS datasets for thinkpad-e14.
#
# TARGET DISK — change if needed (check with: lsblk)
DISK="/dev/nvme0n1"
POOL="zpool"

set -euo pipefail

echo "==> Partitioning $DISK"
echo "    This WILL WIPE the disk. Ctrl-C now to abort."
sleep 5

# GPT layout:
#   p1 — 512M  EFI (FAT32)
#   p2 — 4G    Swap
#   p3 — rest  ZFS
parted --script "$DISK" \
  mklabel gpt \
  mkpart ESP fat32   1MiB   513MiB \
  set 1 esp on \
  mkpart swap linux-swap  513MiB  4609MiB \
  mkpart zfs  zfs         4609MiB 100%

echo "==> Formatting EFI partition"
mkfs.fat -F 32 -n EFI "${DISK}p1"

echo "==> Formatting swap partition"
mkswap -L swap "${DISK}p2"
swapon "${DISK}p2"

# Get the real UUIDs — you'll need these in the config
EFI_UUID=$(blkid -s UUID -o value "${DISK}p1")
SWAP_UUID=$(blkid -s UUID -o value "${DISK}p2")
echo ""
echo "==> UUIDs to put in thinkpad-e14.scm:"
echo "    %efi-uuid  = \"$EFI_UUID\""
echo "    %swap-uuid = \"$SWAP_UUID\""
echo ""

echo "==> Generating ZFS host ID"
zgenhostid

echo "==> Creating ZFS pool: $POOL"
zpool create \
  -o ashift=12 \
  -O compression=zstd \
  -O atime=off \
  -O xattr=sa \
  -O acltype=posixacl \
  -O mountpoint=none \
  -O com.sun:auto-snapshot=false \
  "$POOL" "${DISK}p3"

echo "==> Creating datasets"

# Guix store — no compression (store items are pre-compressed)
zfs create -o mountpoint=legacy -o compression=off              "$POOL/Store"

# Guix var
zfs create -o mountpoint=legacy                                  "$POOL/Guix"

# /etc — persistent system config, auto-snapshot on
zfs create -o mountpoint=legacy -o com.sun:auto-snapshot=true   "$POOL/Config"

# /home — persistent home, auto-snapshot on
zfs create -o mountpoint=legacy -o com.sun:auto-snapshot=true   "$POOL/Home"

# /boot (limine EFI grabs files from /efi, but keep a /boot dataset for initrd)
zfs create -o mountpoint=/boot                                   "$POOL/Boot"

# /var/log
zfs create -o mountpoint=legacy                                  "$POOL/Log"
# /var/tmp
zfs create -o mountpoint=legacy                                  "$POOL/Tmp"
# /var/lib and persistent service state
zfs create -o mountpoint=legacy                                  "$POOL/Data"
zfs create -o mountpoint=legacy -o com.sun:auto-snapshot=true   "$POOL/Data/Bluetooth"
zfs create -o mountpoint=legacy -o com.sun:auto-snapshot=true   "$POOL/Data/Tailscale"

echo "==> Authorizing substitute server keys"
# Authorize nonguix so guix system init can download binaries instead of
# compiling everything from source (kernel build alone takes hours).
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

# Copy hostid so ZFS can import the pool on next boot
cp /etc/hostid /mnt/etc/hostid 2>/dev/null || true

echo ""
echo "==> Done. Update thinkpad-e14.scm with:"
echo "    (define %efi-uuid  \"$EFI_UUID\")"
echo "    (define %swap-uuid \"$SWAP_UUID\")"
echo ""
echo "    Then run:"
echo "    guix system init config/thinkpad-e14.scm /mnt \\"
echo "      --substitute-urls='https://cache-cdn.guix.moe https://substitutes.nonguix.org https://ci.guix.gnu.org https://bordeaux.guix.gnu.org'"
