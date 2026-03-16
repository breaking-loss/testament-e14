# testament-e14: Guix System on ThinkPad E14

This repository contains a Guix System configuration optimized for the
**ThinkPad E14** (AMD/Intel iGPU) using ZFS with an impermanence pattern.
It provides a modern Wayland desktop using the **niri** compositor and
**noctalia-shell**.

## Hardware & System Overview

- **Kernel:** Linux with non-free firmware via NonGuix for Wi-Fi and Bluetooth compatibility.
- **Graphics:** Native `amdgpu` support — no extra configuration needed.
- **Filesystem:** ZFS-on-root with a volatile `tmpfs` root `/`. Only `/etc`, `/home`, `/var/guix`, and `/gnu` persist across reboots.
- **Power Management:** TLP configured with battery charge thresholds (75%–80%) to preserve battery health.
- **Greeter:** greetd + regreet (GTK4).
- **Browser:** Zen Browser (set as XDG default).
- **Terminal:** Foot.

## Repository Structure

```
testament-e14/
├── channels.scm              ← guix pull with this
├── config/
│   ├── thinkpad-e14.scm      ← system config
│   └── niri.kdl              ← niri compositor config
├── home/
│   ├── abram.scm             ← top-level home-environment
│   ├── desktop.scm           ← niri, foot, zen, regreet, XDG
│   ├── shell.scm             ← fish + plugins
│   └── fonts.scm             ← fontconfig
└── setup/
    └── zfs-setup.sh          ← formats partitions + creates ZFS
```

---

## Installation

This guide assumes you are in a **CachyOS live environment** and have
already partitioned `/dev/nvme0n1` as follows:

- `nvme0n1p1` — 512M EFI (FAT32)
- `nvme0n1p2` — 4G Swap
- `nvme0n1p3` — rest ZFS

### Step 5a. Repartition the disk manually

You cannot run `parted --script` on the disk you are booted from. Use
interactive parted instead:

```bash
sudo parted /dev/nvme0n1
```

Inside parted (delete old partitions and recreate):

```
(parted) rm 2
(parted) rm 1
(parted) mkpart ESP fat32 1MiB 513MiB
(parted) set 1 esp on
(parted) mkpart swap linux-swap 513MiB 4609MiB
(parted) mkpart zfs 4609MiB 100%
(parted) quit
```

Then force the kernel to reload the partition table:

```bash
sudo partprobe /dev/nvme0n1
lsblk /dev/nvme0n1   # should show p1, p2, p3
```

### 1. Bootstrap Guix in the live environment

```bash
cd /tmp
wget https://guix.gnu.org/guix-install.sh
chmod +x guix-install.sh
sudo ./guix-install.sh
```

Then start the daemon:

```bash
sudo systemctl start guix-daemon
source ~/.bashrc
hash guix
```

### 2. Clone and prepare channels

```bash
git clone https://github.com/breaking-loss/testament-e14.git
cd testament-e14
guix pull --channels=channels.scm \
  --substitute-urls='https://cache-cdn.guix.moe https://substitutes.nonguix.org https://ci.guix.gnu.org https://bordeaux.guix.gnu.org'
hash guix
```

This pulls nonguix, rosenthal, saayix, and sops-guix channels. Expect
20–40 minutes on first run.

### 3. Initialize ZFS layout

```bash
sudo bash setup/zfs-setup.sh
```

This script formats the EFI and swap partitions, creates the ZFS pool
(`zpool`), sets up datasets for persistence, authorizes substitute keys,
and mounts everything under `/mnt`. The UUIDs for your EFI and swap
partitions will be printed at the end.

### 4. Update system configuration

Open `config/thinkpad-e14.scm` and replace the placeholder UUIDs near
the top with the values printed by the script:

```scheme
(define %efi-uuid  "YOUR-EFI-UUID")   ;; ← update this
(define %swap-uuid "YOUR-SWAP-UUID")  ;; ← update this
```

### 5. Perform the installation

```bash
sudo guix system init config/thinkpad-e14.scm /mnt \
  --substitute-urls='https://cache-cdn.guix.moe https://substitutes.nonguix.org https://ci.guix.gnu.org https://bordeaux.guix.gnu.org'
```

This downloads pre-built binaries from substitute mirrors. Expect
30 minutes to a few hours. Do not close the terminal or let the laptop
sleep during this step.

---

## Post-Installation

### First boot

```bash
sudo zpool export zpool
sudo reboot
```

Select the NVMe from the ThinkPad boot menu. The regreet greeter will
appear. Log in as `abram`.

### Set your password

```bash
passwd abram
```

### Clean up UEFI boot entries

Previous installs leave stale entries in the UEFI boot menu. Clean them
up after the Guix bootloader (limine) has been installed:

```bash
efibootmgr          # list all entries and their numbers
sudo efibootmgr -b XXXX -B   # delete by number, repeat for each stale entry
```

Keep only the limine entry created by Guix.

### Reconfigure after edits

```bash
sudo guix system reconfigure config/thinkpad-e14.scm
```

For home environment changes:

```bash
guix home reconfigure home/abram.scm
```

---

## Persistence & Snapshots

- **Impermanence:** Files written outside the persistent ZFS datasets
  (`/home`, `/etc`, `/gnu`, `/var/guix`) are wiped on reboot. This is
  intentional — the system state is always derived from the config.
- **Snapshots:** Hourly ZFS snapshots with a 72-hour rolling window.
  Weekly scrub runs every Sunday at midnight.

Manual snapshot:

```bash
zfs snapshot zpool/Home@manual-$(date +%Y%m%d)
zfs list -t snapshot
```

---

## Desktop Shortcuts (niri)

| Key | Action |
|-----|--------|
| `Mod+Return` | Terminal (foot) |
| `Mod+O` | Launcher |
| `Mod+A` | Control center |
| `Mod+S` | Settings |
| `Mod+L` | Lock screen |
| `Mod+E` | Emacs |
| `Mod+F` | Maximize column |
| `Mod+V` | Toggle floating |
| `Mod+Shift+Q` | Close window |
| `Mod+Tab` | Overview |
| `Print` | Screenshot |
