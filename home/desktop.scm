;; home/desktop.scm — Graphical desktop home services.
;; Covers: niri, noctalia-shell, polkit agent, icon/cursor theme,
;;         XDG env vars, foot terminal config, Zen browser as default.
;;
;; Exports: %desktop-packages  %desktop-home-services

(define-module (home desktop)
  #:use-module (gnu home services)
  #:use-module (gnu home services xdg)
  #:use-module (gnu services)
  #:use-module (gnu packages)
  #:use-module (gnu packages gnome-xyz)
  #:use-module (gnu packages gnupg)
  #:use-module (gnu packages terminals)
  #:use-module (rosenthal services keyboard)
  #:use-module (rosenthal)
  #:use-module (saayix packages binaries)  ;; zen-browser-bin
  #:use-module (saayix packages wm)        ;; regreet
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:export (%desktop-packages %desktop-home-services %keyboard-layout))

(define %keyboard-layout
  (keyboard-layout "us"))

(define %desktop-packages
  (specifications->packages
   '(;; Wayland / display
     "xwayland-satellite"
     "wl-clipboard"
     "xdg-desktop-portal-gnome"
     "xdg-desktop-portal-gtk"
     "xdg-utils"
     "dconf"
     ;; Terminal: foot — lightweight, Wayland-native
     "foot"
     ;; Browser: Zen Browser (binary, from saayix channel)
     ;; Package name is zen-browser-bin in (saayix packages web)
     "zen-browser-bin")))

;; ── Foot terminal config ─────────────────────────────────────────────────────
;; ~/.config/foot/foot.ini — placed via home-xdg-configuration-files-service-type
(define %foot-config
  (plain-file "foot.ini"
    "[main]\n"
    "term=foot\n"
    "font=Victor Mono:size=11\n"
    "dpi-aware=yes\n"
    "\n"
    "[colors]\n"
    "# Catppuccin Mocha\n"
    "background=1e1e2e\n"
    "foreground=cdd6f4\n"
    "regular0=45475a\n"
    "regular1=f38ba8\n"
    "regular2=a6e3a1\n"
    "regular3=f9e2af\n"
    "regular4=89b4fa\n"
    "regular5=f5c2e7\n"
    "regular6=94e2d5\n"
    "regular7=bac2de\n"
    "bright0=585b70\n"
    "bright1=f38ba8\n"
    "bright2=a6e3a1\n"
    "bright3=f9e2af\n"
    "bright4=89b4fa\n"
    "bright5=f5c2e7\n"
    "bright6=94e2d5\n"
    "bright7=a6adc8\n"
    "\n"
    "[cursor]\n"
    "style=beam\n"
    "blink=yes\n"
    "\n"
    "[key-bindings]\n"
    "spawn-terminal=ctrl+shift+n\n"
    "search-start=ctrl+shift+f\n"))

(define %desktop-home-services
  (list
   ;; ── Keyboard layout ───────────────────────────────────────────────────
   (service home-keyboard-service-type %keyboard-layout)

   ;; ── niri compositor ───────────────────────────────────────────────────
   ;; niri.kdl is in config/ — referenced from the top-level abram.scm.
   ;; The service itself is instantiated there since local-file paths
   ;; are relative to the file calling (local-file ...).
   ;; (home-niri-service-type is added in home/abram.scm)

   ;; ── Noctalia shell ────────────────────────────────────────────────────
   (service home-noctalia-shell-service-type)

   ;; ── Polkit agent ──────────────────────────────────────────────────────
   (service home-polkit-gnome-service-type)

   ;; ── GPG agent with SSH support ────────────────────────────────────────
   (service home-gpg-agent-service-type
     (home-gpg-agent-configuration
       (pinentry-program
        (file-append pinentry-qt "/bin/pinentry-qt"))
       (ssh-support? #t)))

   ;; ── Icon / cursor theme ───────────────────────────────────────────────
   (service home-theme-service-type
     (home-theme-configuration
       (packages (list qogir-icon-theme))
       (icon-theme "Qogir")
       (cursor-theme "Qogir")))

   ;; ── Default applications (XDG MIME) ──────────────────────────────────
   ;; Sets Zen as the default browser and foot as the default terminal.
   (simple-service 'xdg-defaults home-xdg-mime-applications-service-type
     (home-xdg-mime-applications-configuration
       (default
         '((text/html                  . zen-browser-bin.desktop)
           (x-scheme-handler/http      . zen-browser-bin.desktop)
           (x-scheme-handler/https     . zen-browser-bin.desktop)
           (x-scheme-handler/about     . zen-browser-bin.desktop)
           (x-scheme-handler/unknown   . zen-browser-bin.desktop)
           (x-scheme-handler/terminal  . foot.desktop)))))

   ;; ── Foot terminal config ──────────────────────────────────────────────
   (simple-service 'foot-config home-xdg-configuration-files-service-type
     `(("foot/foot.ini" ,%foot-config)))

   ;; ── XDG base directory env vars ───────────────────────────────────────
   (simple-service 'xdg-base-directory
     home-environment-variables-service-type
     %xdg-base-directory-env-vars)

   ;; ── Steam sandbox ─────────────────────────────────────────────────────
   (simple-service 'nonguix-sandbox-home
     home-environment-variables-service-type
     '(("GUIX_SANDBOX_HOME" . "/var/lib/Sandbox")))))
