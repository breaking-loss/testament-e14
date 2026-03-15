# testament-e14

Guix System configuration for **ThinkPad E14** (AMD/Intel iGPU, UEFI, ZFS).
Adapted from [hako/Testament `dorphine`](https://codeberg.org/hako/Testament).

## What's different from dorphine

| dorphine | thinkpad-e14 |
|---|---|
| NVIDIA dGPU (nvdb, open-beta) | amdgpu (automatic, no config needed) |
| `linux/dolly` (hako's custom kernel) | `linux` from nonguix |
| `Etc/GMT-8` / dvorak | `Asia/Kolkata` / us |
| username: hako | username: abram |
| cuirass CI worker | removed |
| alloy monitoring | removed |
| SOPS secrets (email, alloy) | removed |
| nftables: minecraft/warframe/CI ports | stripped to basics |

Everything else — niri, noctalia-shell, GDM, ZFS impermanence pattern,
Guix Home, fish shell, TLP power management — is preserved.

---

## Step-by-step installation

### 1. Copy the Testament live CD ISO to the Ventoy drive

```bash
sudo mount /dev/sda1 /mnt
sudo cp testament-desktop-*.iso /mnt/
sudo umount /mnt
```

Get the desktop ISO from: <https://files.boiledscript.com/livecd/>

### 2. Boot the Testament desktop live CD

From the Ventoy menu, select the Testament ISO. It boots into a GNOME-like
desktop with fish as the login shell and NetworkManager available.

Connect to WiFi:
```bash
nmtui
```

### 3. Clone this repo onto the live system

```bash
git clone https://github.com/YOUR_USERNAME/testament-e14.git
cd testament-e14
```

### 4. Pull Guix channels

This fetches the exact channel versions needed (nonguix, rosenthal, etc.):

```bash
guix pull --channels=channels.scm
hash guix    # refresh PATH to the newly pulled guix
```

This will take a while the first time.

### 5a. Repartition the disk manually

You cannot run `parted --script` on the disk you're booted from — it will fail with "partition(s) being used". Instead, use interactive `parted`:

```bash
sudo parted /dev/nvme0n1
```

Inside parted, delete the existing CachyOS partitions and recreate for Guix:

```
(parted) print          # confirm current layout
(parted) rm 1           # delete EFI/boot partition
(parted) rm 2           # delete CachyOS root
(parted) mklabel gpt    # only if you want a fresh GPT (optional if already GPT)
(parted) mkpart ESP fat32 1MiB 513MiB
(parted) set 1 esp on
(parted) mkpart swap linux-swap 513MiB 4609MiB
(parted) mkpart zfs 4609MiB 100%
(parted) quit
```

This gives you:
- `nvme0n1p1` — 512M EFI
- `nvme0n1p2` — 4G Swap
- `nvme0n1p3` — ~470G ZFS

### 5b. Run the ZFS setup script

```bash
sudo bash setup/zfs-setup.sh
```

The script verifies the partitions exist, formats them, creates the ZFS pool and datasets, authorizes substitute keys, and mounts everything under `/mnt`.

### 6. Update UUIDs in the config

The script prints the UUIDs. Open `config/thinkpad-e14.scm` and update:

```scheme
(define %efi-uuid  "XXXX-XXXX")                            ;; ← replace
(define %swap-uuid "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx") ;; ← replace
```

### 7. Initialize the system

```bash
guix system init config/thinkpad-e14.scm /mnt
```

This builds or downloads the entire system closure. Expect 30–90 minutes
depending on substitute availability. The rosenthal and nonguix substitute
servers help significantly.

### 8. First boot

```bash
zpool export Mentha
reboot
```

Remove the pendrive when prompted (or let it boot from the UEFI default).
At the GDM login screen, log in as `abram`. niri starts automatically.

---

## Post-install notes

### Set your password

```bash
passwd abram
```

### Reconfigure after edits

```bash
# On the live system during install:
guix system init config/thinkpad-e14.scm /mnt

# After first boot, to reconfigure:
sudo guix system reconfigure config/thinkpad-e14.scm
```

### ThinkPad battery thresholds

TLP is configured to stop charging at 80% and resume at 75%. Adjust in
`thinkpad-e14.scm`:

```scheme
(start-charge-thresh-bat0 75)
(stop-charge-thresh-bat0  80)
```

Check current threshold status after boot:
```bash
sudo tlp-stat -b
```

### ZFS snapshots

Hourly snapshots are taken automatically (72-hour rolling window).
Weekly scrub runs every Sunday at midnight.

Manual snapshot:
```bash
zfs snapshot Mentha/Home@manual-$(date +%Y%m%d)
```

List snapshots:
```bash
zfs list -t snapshot
```

### Impermanence

The root `/` is a tmpfs — anything written outside the ZFS-mounted paths
(`/home`, `/etc`, `/gnu`, `/var/guix`) is **lost on reboot**. This is
intentional (same as dorphine). Put persistent config in `/etc` or home.

---

## Channels

| Channel | Purpose |
|---|---|
| `guix` | Core Guix |
| `nonguix` | Blob-inclusive Linux kernel + firmware |
| `rosenthal` | niri, noctalia-shell, ZFS services, limine bootloader |
| `sops-guix` | SOPS secrets (optional, included for future use) |
