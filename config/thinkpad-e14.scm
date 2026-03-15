;; Guix System configuration for ThinkPad E14 (AMD/Intel iGPU, UEFI, ZFS).
;; Adapted from hako/Testament dorphine.org (x86_64-linux, UEFI, ZFS, NVIDIA).
;;
;; Key differences from dorphine:
;;   - No NVIDIA; amdgpu used as-is (no blacklisting)
;;   - Kernel: nonguix `linux` instead of custom linux/dolly
;;   - Locale: en_IN.UTF-8 / Asia/Kolkata
;;   - Username: abram
;;   - TLP added for ThinkPad battery/power management
;;   - cuirass-remote-worker and alloy monitoring removed (server-only)
;;   - SOPS secrets stub present but disabled; enable if you set up GPG key
;;
;; BEFORE RUNNING `guix system init`:
;;   1. Update EFI_UUID below with the real UUID from `blkid /dev/nvme0n1p1`
;;   2. Update SWAP_UUID with UUID from `blkid /dev/nvme0n1p2`
;;   3. Replace ZFS pool name "zpool" everywhere if you chose a different name
;;   4. Set a password hash in (password "...") or leave #f for passwordless root

(use-modules
 ;; Testament common
 (common)
 ;; Home environment for abram
 (home abram)
 ;; Guile
 (ice-9 match)
 ;; Guix core
 (gnu)
 (guix packages)
 ;; Nonguix — blob kernel + firmware
 (nonguix)
 ;; Rosenthal — niri, noctalia-shell, ZFS services, rosenthal desktop
 (rosenthal)
 ;; System
 (gnu system accounts)
 ;; Services
 (gnu services greetd)
 (gnu services linux)
 (gnu services networking)
 (gnu services security)
 (gnu services security-token)
 (gnu services ssh)
 (gnu services syncthing)
 (gnu services sysctl)
 (rosenthal services file-systems)
 (rosenthal services keyboard)
 (rosenthal services shellutils)
 ;; Home services (needed for guix-home-service-type)
 (gnu home)
 ;; Packages
 (gnu packages android)
 (gnu packages fcitx5)
 (gnu packages file-systems)
 (gnu packages gnome-xyz)
 (gnu packages gnupg)
 (gnu packages guile)
 (gnu packages java)
 (gnu packages linux)
 (gnu packages security-token)
 (gnu packages shells)
 (gnu packages ssh)
 (gnu packages terminals)
 (gnu packages video)
 (gnu packages xorg)
 ;; regreet greeter (from saayix channel)
 (saayix packages wm))

;; ── Placeholders ────────────────────────────────────────────────────────────
;; Run `blkid` after partitioning and update these two values.
(define %efi-uuid  "XXXX-XXXX")   ;; FAT32 EFI partition UUID  (e.g. "1A2B-3C4D")
(define %swap-uuid "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx") ;; Swap partition UUID

;; ZFS pool name — must match what you used in `zpool create`.
(define %pool "zpool")
;; ────────────────────────────────────────────────────────────────────────────

(define %keyboard-layout
  (keyboard-layout "us"))

(operating-system
  (host-name "thinkpad-e14")
  (timezone "Asia/Kolkata")
  (locale "en_IN.UTF-8")
  (keyboard-layout %keyboard-layout)

  ;; ── Bootloader ─────────────────────────────────────────────────────────
  ;; Uses limine from rosenthal channel (same as dorphine).
  (bootloader
   (bootloader-configuration
    (bootloader limine-efi-removable-bootloader)
    (targets '("/efi"))))

  ;; ── Kernel ─────────────────────────────────────────────────────────────
  ;; nonguix `linux` = upstream kernel with proprietary firmware blobs.
  ;; Needed for Intel/AMD WiFi (iwlwifi, mt7921, etc.) on E14.
  (kernel linux)
  (firmware (cons* linux-firmware %base-firmware))
  ;; ZFS module loaded from store, not built into initrd.
  (kernel-loadable-modules (list `(,zfs "module")))

  (kernel-arguments
   (cons* "kernel.sysrq=1"
          "memtest=3"
          "zswap.enabled=1"
          "zswap.max_pool_percent=90"
          %default-kernel-arguments))

  (initrd microcode-initrd)

  ;; ── File Systems ────────────────────────────────────────────────────────
  ;; Layout:
  ;;   /efi        — FAT32 EFI partition (nvme0n1p1)
  ;;   /           — tmpfs (impermanence; volatile state is lost on reboot)
  ;;   /var/lock   — tmpfs
  ;;   /gnu        — ZFS zpool/Store   (Guix store, atime=off)
  ;;   /var/guix   — ZFS zpool/Guix
  ;;   /etc        — ZFS zpool/Config  (persistent system config)
  ;;   /home       — ZFS zpool/Home    (persistent home)
  (file-systems
   (append
    (list
     (file-system
       (device (uuid %efi-uuid 'fat))
       (mount-point "/efi")
       (type "vfat")
       (flags '(no-exec no-suid no-dev))
       (options "fmask=0177,dmask=0077")
       (create-mount-point? #t))

     ;; Volatile root — everything outside the ZFS mounts is wiped on reboot.
     ;; Persistent state lives in /etc, /home, /var/guix, /gnu.
     (file-system
       (device "tmpfs")
       (mount-point "/")
       (type "tmpfs")
       (options "mode=0755,nr_inodes=1m,size=25%")
       (check? #f))

     (file-system
       (device "tmpfs")
       (mount-point "/var/lock")
       (type "tmpfs")
       (flags '(no-suid no-dev))
       (options "mode=1777,nr_inodes=800k,size=20%")
       (create-mount-point? #t)
       (check? #f)))

    (map (match-lambda
           ((dataset . mount-point)
            (file-system
              (device (string-append "zfs:" dataset))
              (mount-point mount-point)
              (type "zfs")
              (create-mount-point? #t)
              (check? (string=? mount-point "/gnu"))
              (needed-for-boot?
               (member mount-point '("/gnu" "/var/guix" "/etc"))))))
         `((,(string-append %pool "/Store")  . "/gnu")
           (,(string-append %pool "/Guix")   . "/var/guix")
           (,(string-append %pool "/Config") . "/etc")
           (,(string-append %pool "/Home")   . "/home")))

    %base-file-systems))

  (swap-devices
   (list (swap-space
          (target (uuid %swap-uuid)))))

  ;; ── Users ───────────────────────────────────────────────────────────────
  (users
   (cons* (user-account
           (inherit %root-account)
           (password #f)            ;; Set a hash here for root login
           (shell (file-append fish "/bin/fish")))
          (user-account
           (name "abram")
           (group "users")
           (supplementary-groups
            '("adbusers" "audio" "cgroup" "kvm" "plugdev" "video" "wheel"))
           (shell (file-append fish "/bin/fish")))
          %base-user-accounts))

  ;; ── Packages ────────────────────────────────────────────────────────────
  (packages
   ;; System-level packages only — user apps are in home/abram.scm.
   (cons* (specifications->packages
           '(;; Shell (needed system-wide for root + login)
             "fish"
             ;; ZFS userspace tools
             "zfs"))
          %testament-cli-packages
          %base-packages))

  ;; ── Services ────────────────────────────────────────────────────────────
  (services
   (cons*
    ;; ZFS service + weekly scrub
    (service zfs-service-type)
    (simple-service 'zfs-scrub shepherd-root-service-type
      (list (shepherd-timer '(zfs-scrub)
              #~(calendar-event #:days-of-week '(sunday) #:hours '(0) #:minutes '(0))
              #~(#$(file-append zfs "/sbin/zpool") "scrub" "-w" #$%pool)
              #:requirement '(user-processes))))

    ;; Hourly ZFS snapshots (72-hour rolling window)
    (simple-service 'zfs-snapshot-hourly shepherd-root-service-type
      (list (shepherd-timer '(zfs-snapshot-hourly)
              #~(calendar-event #:minutes '(0))
              #~(#$(program-file "zfs-snapshot-hourly"
                    (with-imported-modules '((guix build utils))
                      #~(begin
                          (use-modules (guix build utils))
                          (setenv "PATH"
                                  "/run/current-system/profile/bin:/run/current-system/profile/sbin")
                          (invoke #$(file-append zfs-auto-snapshot "/sbin/zfs-auto-snapshot")
                                  "--default-exclude" "--skip-scrub"
                                  "--keep=72" "--label=hourly" "//")))))
              #:requirement '(user-processes))))

    ;; Kernel networking tuning
    (simple-service 'extend-kernel-module-loader kernel-module-loader-service-type
      '("sch_fq_pie" "tcp_bbr"))
    (simple-service 'extend-sysctl sysctl-service-type
      '(("net.core.default_qdisc"         . "fq_pie")
        ("net.ipv4.tcp_congestion_control" . "bbr")
        ("net.core.rmem_max"               . "7500000")
        ("net.core.wmem_max"               . "7500000")))

    ;; ── Power Management ─────────────────────────────────────────────────
    ;; TLP: ThinkPad-specific battery thresholds + power profiles.
    ;; Charge stops at 80% on battery, resumes at 75% — adjustable.
    (service tlp-service-type
      (tlp-configuration
        (cpu-scaling-governor-on-ac  '("performance"))
        (cpu-scaling-governor-on-bat '("powersave"))
        (usb-autosuspend?            #t)
        ;; ThinkPad ACPI charge thresholds (requires tp_smapi or thinkpad_acpi)
        (start-charge-thresh-bat0 75)
        (stop-charge-thresh-bat0  80)))

    (modify-services (list (service upower-service-type))
      (upower-service-type config =>
        (upower-configuration
          (inherit config)
          (critical-power-action 'power-off))))

    ;; ── Networking ───────────────────────────────────────────────────────
    (modify-services (list (service network-manager-service-type))
      (network-manager-service-type config =>
        (network-manager-configuration
          (inherit config)
          (extra-configuration-files
           (list %network-manager-ipv6-privacy
                 %network-manager-random-mac-address)))))

    (service tailscale-service-type)

    (service openssh-service-type
      (openssh-configuration
        (openssh openssh-sans-x)
        (permit-root-login 'prohibit-password)
        (password-authentication? #f)))

    (service fail2ban-service-type
      (fail2ban-configuration
        (extra-jails
         (list (fail2ban-jail-configuration
                 (name "sshd")
                 (enabled? #t))))))

    ;; ── Guix Daemon ──────────────────────────────────────────────────────
    (modify-services (list (service guix-service-type))
      (guix-service-type config =>
        (guix-configuration
          (inherit config)
          (discover? #t)
          (tmpdir "/var/tmp"))))

    (simple-service 'extend-guix guix-service-type
      (guix-extension
        ;; Authorize substitute servers so Guix doesn't build everything
        ;; from source. The nonguix key is embedded inline to avoid needing
        ;; a separate file. cache-cdn.guix.moe uses %guix-keys from rosenthal.
        (authorized-keys
         (cons*
          ;; nonguix substitute server signing key
          ;; Source: https://substitutes.nonguix.org/signing-key.pub
          (plain-file "non-guix.pub"
            "(public-key\n (ecc\n  (curve Ed25519)\n  (q #C1FD53E5D4CE971933EC50C9F307AE2171A2D3B52C804642A7A35F84F3A4EA98#)\n )\n)\n")
          %guix-keys))  ;; %guix-keys from rosenthal covers cache-cdn.guix.moe
        (substitute-urls
         '("https://cache-cdn.guix.moe"
           "https://substitutes.nonguix.org"))))

    ;; ── Security Tokens ──────────────────────────────────────────────────
    (service pcscd-service-type)
    (udev-rules-service 'u2f libfido2 #:groups '("plugdev"))

    ;; ── Android / ADB ────────────────────────────────────────────────────
    (udev-rules-service 'android android-udev-rules #:groups '("adbusers"))

    ;; ── Steam controller udev rules ──────────────────────────────────────
    (udev-rules-service 'steam-devices steam-devices-udev-rules)

    ;; ── Syncthing ────────────────────────────────────────────────────────
    (service syncthing-service-type
      (syncthing-configuration
        (user "abram")))

    ;; ── Graphical Session: greetd + regreet + niri ────────────────────────
    ;; greetd is a minimal session manager. regreet is a GTK4 greeter for it.
    ;; On login, greetd runs niri as the session.
    ;;
    ;; regreet config lives at /etc/regreet.toml (created below).
    ;; greetd config lives at /etc/greetd/config.toml (managed by service).
    (service greetd-service-type
      (greetd-configuration
        (greeter-supplementary-groups '("video" "input"))
        (terminals
         (list (greetd-terminal-configuration
                 (terminal-vt "1")
                 (terminal-switch #t)
                 (default-session-command
                   (greetd-agreety-session
                     (command (file-append regreet "/bin/regreet"))
                     (command-args '()))))))))

    ;; regreet configuration file
    (simple-service 'regreet-config etc-service-type
      `(("regreet.toml"
         ,(plain-file "regreet.toml"
            "[GTK]\n"
            "application_id = \"regreet\"\n"
            "cursor_theme_name = \"Qogir\"\n"
            "font_name = \"SF Pro Display 11\"\n"
            "icon_theme_name = \"Qogir\"\n"
            "theme_name = \"adw-gtk3-dark\"\n"
            "\n"
            "[background]\n"
            "# Set a wallpaper path here, e.g.:\n"
            "# path = \"/etc/regreet-background.jpg\"\n"
            "fit = \"Cover\"\n"
            "\n"
            "[env]\n"
            "# Environment variables passed to the greeter session\n"))))

    ;; Guix Home for abram — delegates to home/abram.scm
    (service guix-home-service-type
      `(("abram" ,%abram-home)))

    (modify-services %rosenthal-desktop-services
      ;; Drop GDM from the rosenthal desktop services — we use greetd instead.
      (delete gdm-service-type))))

  (name-service-switch %mdns-host-lookup-nss))

  (name-service-switch %mdns-host-lookup-nss))
