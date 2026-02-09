#lang racket/base

;;;
;;; PROLOGOS REPL SUPPORT
;;; Runtime functions for REPL interaction.
;;; Separate module to avoid circular dependency between main.rkt and expander.rkt.
;;;

(require "parser.rkt"
         "driver.rkt"
         "errors.rkt"
         "global-env.rkt"
         "macros.rkt")

(provide the-prologos-env
         prologos-init-repl-env
         prologos-repl-eval)

;; Persistent env box — survives across REPL interactions.
;; Populated by prologos-init-repl-env when a module is loaded.
(define the-prologos-env (box (hasheq)))

;; Initialize the REPL env by re-processing module forms at runtime.
;; Called from the generated #%module-begin expansion.
(define (prologos-init-repl-env form-stxs)
  (parameterize ([current-global-env (hasheq)])
    (for ([stx (in-list form-stxs)])
      (define parsed (parse-datum stx))
      (unless (prologos-error? parsed)
        (define result (process-command parsed))
        (void)))
    (set-box! the-prologos-env (current-global-env))))

;; Process a single REPL interaction at runtime.
(define (prologos-repl-eval form-stx)
  (define saved-env (unbox the-prologos-env))
  (parameterize ([current-global-env saved-env])
    (with-handlers
      ([exn:fail? (lambda (e) (displayln (exn-message e)))])
      ;; Pre-parse macro expansion
      (define datum (syntax->datum form-stx))
      (cond
        ;; defmacro — register and consume
        [(and (pair? datum) (eq? (car datum) 'defmacro))
         (process-defmacro datum)
         (displayln "Macro defined.")]
        ;; deftype — register and consume
        [(and (pair? datum) (eq? (car datum) 'deftype))
         (process-deftype datum)
         (displayln "Type alias defined.")]
        [else
         ;; Expand pre-parse macros
         (define expanded-datum (preparse-expand-form datum))
         ;; Preserve original syntax if no change (keeps paren-shape etc.)
         (define expanded-stx
           (if (equal? expanded-datum datum) form-stx (datum->syntax #f expanded-datum form-stx)))
         (define parsed (parse-datum expanded-stx))
         (cond
           [(prologos-error? parsed)
            (displayln (format-error parsed))]
           [else
            (define result (process-command parsed))
            ;; Save updated env (process-command may have added definitions)
            (set-box! the-prologos-env (current-global-env))
            (if (prologos-error? result)
                (displayln (format-error result))
                (displayln result))])]))))
