#lang racket/base

;;;
;;; PROLOGOS DRIVER
;;; Processes top-level commands (def, check, eval, infer).
;;; Manages the global definition environment.
;;;

(require racket/match
         racket/port
         "prelude.rkt"
         "syntax.rkt"
         "reduction.rkt"
         "typing-core.rkt"
         "source-location.rkt"
         "surface-syntax.rkt"
         "errors.rkt"
         "parser.rkt"
         "elaborator.rkt"
         "pretty-print.rkt"
         "typing-errors.rkt"
         "global-env.rkt")

(provide process-command
         process-file
         process-string)

;; ========================================
;; Process a single top-level command
;; ========================================
;; Returns a result string, or a prologos-error.
;; Side effect: may update current-global-env for 'def'.
(define (process-command surf)
  (define elab-result (elaborate-top-level surf))
  (if (prologos-error? elab-result)
      elab-result
      (match elab-result
        ;; (def name type body)
        [(list 'def name type body)
         (let ([ty-ok (is-type/err ctx-empty type)])
           (if (prologos-error? ty-ok) ty-ok
               (let ([chk (check/err ctx-empty body type)])
                 (if (prologos-error? chk) chk
                     (begin
                       (current-global-env
                        (global-env-add (current-global-env) name type body))
                       (format "~a : ~a defined." name (pp-expr type)))))))]

        ;; (check expr type)
        [(list 'check expr type)
         (let ([chk (check/err ctx-empty expr type)])
           (if (prologos-error? chk) chk
               "OK"))]

        ;; (eval expr)
        [(list 'eval expr)
         (let ([ty (infer/err ctx-empty expr)])
           (if (prologos-error? ty) ty
               (let ([val (nf expr)])
                 (format "~a : ~a" (pp-expr val) (pp-expr ty)))))]

        ;; (infer expr)
        [(list 'infer expr)
         (let ([ty (infer/err ctx-empty expr)])
           (if (prologos-error? ty) ty
               (pp-expr ty)))]

        [_ (prologos-error srcloc-unknown (format "Unknown command: ~a" elab-result))])))

;; ========================================
;; Process all commands from a string
;; ========================================
(define (process-string s)
  (define port (open-input-string s))
  (port-count-lines! port)
  (define surfs (parse-port port "<string>"))
  (for/list ([surf (in-list surfs)])
    (if (prologos-error? surf)
        surf
        (process-command surf))))

;; ========================================
;; Process all commands from a file
;; ========================================
(define (process-file path)
  (define port (open-input-file path))
  (port-count-lines! port)
  (define surfs (parse-port port path))
  (close-input-port port)
  (for/list ([surf (in-list surfs)])
    (if (prologos-error? surf)
        surf
        (process-command surf))))
