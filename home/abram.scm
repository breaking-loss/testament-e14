;; home/abram.scm — Top-level Guix Home environment for user abram.
;;
;; Imports submodules from home/ and wires them together.
;; Referenced by config/thinkpad-e14.scm via guix-home-service-type.
;;
;; Submodules:
;;   home/shell.scm   — fish + plugins
;;   home/fonts.scm   — fontconfig + font packages
;;   home/desktop.scm — niri, noctalia-shell, foot, Zen, XDG, theme

(define-module (home abram)
  #:use-module (home shell)
  #:use-module (home fonts)
  #:use-module (home desktop)
  #:use-module (gnu home)
  #:use-module (gnu home services)
  #:use-module (gnu home services dotfiles)
  #:use-module (gnu services)
  #:use-module (gnu packages)
  #:use-module (gnu packages containers)
  #:use-module (gnu packages syncthing)
  #:use-module (rosenthal)
  #:use-module (rosenthal services file-systems)
  #:use-module (guix gexp)
  #:export (%abram-home))

(define %abram-home
  (home-environment
    ;; ── User packages ──────────────────────────────────────────────────
    (packages
     (append
      %font-packages
      %desktop-packages
      (specifications->packages
       '(;; Apps
         "digikam"
         "gimp"
         "imv"
         "kdenlive"
         "libreoffice"
         "obs"
         "telegram-desktop"
         "zathura"
         "zathura-pdf-poppler"
         ;; Dev
         "emacs"
         "git"
         "gdb"
         "wget"
         "nano"
         ;; Media
         "mpv"
         ;; Games
         "mangohud"
         "steam"
         "prismlauncher"
         ;; File manager
         "thunar"
         "exo"
         "file-roller"
         "thunar-archive-plugin"
         "thunar-media-tags-plugin"
         "thunar-volman"
         "ffmpegthumbnailer"
         "tumbler"
         "webp-pixbuf-loader"))))

    ;; ── Home services ───────────────────────────────────────────────────
    (services
     (cons*
      ;; ── niri compositor ─────────────────────────────────────────────
      ;; Wired here (not in desktop.scm) because (local-file ...) resolves
      ;; relative to THIS file's location, so niri.kdl must be reachable
      ;; from here. Place niri.kdl at config/niri.kdl and reference it:
      (service home-niri-service-type
        (home-niri-configuration
          (config
           (computed-substitution-with-inputs "niri.kdl"
             (local-file "../config/niri.kdl")
             (list xwayland-satellite)))))

      ;; ── Rootless Podman ──────────────────────────────────────────────
      (service rootless-podman-service-type
        (rootless-podman-configuration
          (subgids (list (subid-range (name "abram"))))
          (subuids (list (subid-range (name "abram"))))))

      ;; ── Syncthing ────────────────────────────────────────────────────
      ;; Runs as a user service. Web UI at http://localhost:8384
      (service home-syncthing-service-type)

      ;; ── Stitch in submodule services ─────────────────────────────────
      (append %shell-home-services
              %font-home-services
              %desktop-home-services
              %rosenthal-desktop-home-services)))))
