;; home/fonts.scm — Fontconfig aliases and font packages.
;;
;; Exports: %font-packages  %font-home-services

(define-module (home fonts)
  #:use-module (gnu home services fontutils)
  #:use-module (gnu services)
  #:use-module (guix packages)
  #:use-module (gnu packages)
  #:export (%font-packages %font-home-services))

(define %font-packages
  (specifications->packages
   '("font-apple-new-york"
     "font-apple-sf-pro"
     "font-google-noto"
     "font-google-noto-emoji"
     "font-nerd-symbols"
     "font-sarasa-gothic"
     "font-victor-mono")))

(define %font-home-services
  (list
   (simple-service 'extend-fontconfig home-fontconfig-service-type
     (let ((sans  "SF Pro Display")
           (serif "New York Medium")
           (mono  "Victor Mono")
           (emoji "Noto Color Emoji"))
       `((alias (family "sans-serif")
                (prefer (family ,sans)
                        (family "Sarasa Gothic CL")
                        (family ,emoji)))
         (alias (family "serif")
                (prefer (family ,serif)
                        (family "Sarasa Gothic CL")
                        (family ,emoji)))
         (alias (family "monospace")
                (prefer (family ,mono)
                        (family "Sarasa Gothic CL")
                        (family ,emoji)))
         ;; Web font aliases → SF Pro so sites using system-ui look good
         ,@(map (lambda (name)
                  `(alias (family ,name)
                          (prefer (family ,sans)
                                  (family "sans-serif"))))
                '("BlinkMacSystemFont"
                  "-apple-system"
                  "system-ui"
                  "ui-sans-serif"))
         (alias (family "ui-serif")
                (prefer (family ,serif) (family "serif")))
         (alias (family "ui-monospace")
                (prefer (family ,mono) (family "monospace"))))))))
