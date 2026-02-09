#lang racket/base

;;;
;;; PROLOGOS EXPANDER
;;; Compile-time helpers for the #lang prologos module language.
;;; This module is required for-syntax by main.rkt, so all functions
;;; here run at phase 1 (compile time) of the user's module.
;;;
;;; Provides:
;;;   expand-prologos-module : syntax? -> syntax?
;;;     Takes the full #%module-begin syntax and returns expanded module.
;;;
;;; The logic is a direct adaptation of driver.rkt process-command,
;;; except errors raise exn:fail:prologos instead of being returned.
;;;

(require racket/match
         syntax/parse
         "source-location.rkt"
         "surface-syntax.rkt"
         "errors.rkt"
         "parser.rkt"
         "elaborator.rkt"
         "prelude.rkt"
         "syntax.rkt"
         "typing-core.rkt"
         "typing-errors.rkt"
         "reduction.rkt"
         "pretty-print.rkt"
         "global-env.rkt"
         "lang-error.rkt"
         "macros.rkt"
         (for-template racket/base
                      "repl-support.rkt"))

(provide expand-prologos-module)

;; ========================================
;; Extract source location from surface AST
;; ========================================
(define (surf-loc surf)
  (cond
    [(surf-def? surf)   (surf-def-srcloc surf)]
    [(surf-defn? surf)  (surf-defn-srcloc surf)]
    [(surf-check? surf) (surf-check-srcloc surf)]
    [(surf-eval? surf)  (surf-eval-srcloc surf)]
    [(surf-infer? surf) (surf-infer-srcloc surf)]
    [else               srcloc-unknown]))

;; ========================================
;; Process a single parsed surface form
;; ========================================
;; Returns: (list 'def name type-string)
;;        | (list 'output string)
;; Raises: exn:fail:prologos on any error
(define (process-form surf)
  (define loc (surf-loc surf))
  (define elab-result (elaborate-top-level surf))
  (when (prologos-error? elab-result)
    (raise-prologos-error elab-result))

  (match elab-result
    ;; (def name type body)
    [(list 'def name type body)
     (let ([ty-ok (is-type/err ctx-empty type loc)])
       (when (prologos-error? ty-ok)
         (raise-prologos-error ty-ok))
       (let ([chk (check/err ctx-empty body type loc)])
         (when (prologos-error? chk)
           (raise-prologos-error chk))
         ;; Update the global environment for subsequent forms
         (current-global-env
          (global-env-add (current-global-env) name type body))
         (list 'def name (pp-expr type))))]

    ;; (check expr type)
    [(list 'check expr type)
     (let ([chk (check/err ctx-empty expr type loc)])
       (when (prologos-error? chk)
         (raise-prologos-error chk))
       (list 'output "OK"))]

    ;; (eval expr)
    [(list 'eval expr)
     (let ([ty (infer/err ctx-empty expr loc)])
       (when (prologos-error? ty)
         (raise-prologos-error ty))
       (let ([val (nf expr)]
             [ty-nf (nf ty)])
         (list 'output (format "~a : ~a" (pp-expr val) (pp-expr ty-nf)))))]

    ;; (infer expr)
    [(list 'infer expr)
     (let ([ty (infer/err ctx-empty expr loc)])
       (when (prologos-error? ty)
         (raise-prologos-error ty))
       (list 'output (pp-expr ty)))]

    [_ (raise-prologos-error
        (prologos-error srcloc-unknown
                        (format "Unknown top-level form: ~a" elab-result)))]))

;; ========================================
;; Expand an entire #lang prologos module
;; ========================================
;; Called from the define-syntax form in main.rkt.
;; Receives the full (#%module-begin form ...) syntax.
;; Returns expanded (#%module-begin out-expr ...) syntax.
(define (expand-prologos-module stx)
  (syntax-parse stx
    [(_ form ...)
     (parameterize ([current-global-env (hasheq)]
                    [current-preparse-registry (current-preparse-registry)])
       ;; Pre-parse macro expansion: expand defmacro/let/do/if/deftype
       (define expanded-stxs (preparse-expand-all (syntax->list #'(form ...))))
       (define output-exprs
         (for/list ([form-stx (in-list expanded-stxs)])
           ;; Parse the syntax object into surface AST
           (define parsed (parse-datum form-stx))
           (when (prologos-error? parsed)
             (raise-prologos-error parsed))
           ;; Expand macros (defn → def, the-fn, implicit eval, etc.)
           (define expanded (expand-top-level parsed))
           (when (prologos-error? expanded)
             (raise-prologos-error expanded))
           ;; Process the form (type check, elaborate, etc.)
           (define result (process-form expanded))
           ;; Generate runtime code
           (match result
             [(list 'def name type-str)
              #`(displayln #,(format "~a : ~a defined." name type-str))]
             [(list 'output str)
              #`(displayln #,str)])))
       ;; Wrap in the real #%module-begin
       ;; Include prologos-init-repl-env to populate runtime env for REPL
       ;; Pass expanded syntax (after pre-parse) for REPL replay
       (with-syntax ([(out-expr ...) output-exprs]
                     [(form-stx ...) expanded-stxs])
         #'(#%module-begin
            out-expr ...
            (prologos-init-repl-env
             (list (quote-syntax form-stx) ...)))))]))
