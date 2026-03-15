;; home/shell.scm — Fish shell configuration and plugins.
;;
;; Exports: %shell-home-services

(define-module (home shell)
  #:use-module (gnu home services shells)
  #:use-module (rosenthal services shellutils)
  #:use-module (guix gexp)
  #:use-module (gnu packages shells)
  #:export (%shell-home-services))

(define %shell-home-services
  (list
   ;; Fish config: merge Guix profile search paths on login shells.
   ;; Without this, packages from guix home/user profiles aren't on PATH.
   (service home-fish-service-type
     (home-fish-configuration
       (config
        (list
         (mixed-text-file "merge-search-paths.fish"
           "status is-login\nand begin\n"
           "  set --prepend fish_function_path "
           fish-foreign-env "/share/fish/functions\n"
           "  fenv eval \"$(guix package --search-paths \\\n"
           "    --profile=$HOME/.config/guix/current \\\n"
           "    --profile=$HOME/.guix-profile \\\n"
           "    --profile=$HOME/.guix-home/profile \\\n"
           "    --profile=/run/current-system/profile)\"\n"
           "  set --prepend PATH /run/privileged/bin\n"
           "  set --erase fish_function_path[1]\n"
           "end\n")
         ;; Emacs eat terminal integration
         (plain-file "emacs-eat.fish"
           "if test -n \"$EAT_SHELL_INTEGRATION_DIR\"\n"
           "  source $EAT_SHELL_INTEGRATION_DIR/fish\n"
           "end\n")))))

   ;; Fish plugins (provided by rosenthal channel)
   (service home-fish-plugin-atuin-service-type)   ;; searchable shell history
   (service home-fish-plugin-direnv-service-type)  ;; per-directory env vars
   (service home-fish-plugin-zoxide-service-type))) ;; smart cd (z)
