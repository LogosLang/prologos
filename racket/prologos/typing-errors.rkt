#lang racket/base

;;;
;;; PROLOGOS TYPING-ERRORS
;;; Error-accumulating wrappers around the core type checker.
;;; The core kernel functions (infer, check, etc.) are preserved unchanged
;;; for Maude cross-validation. These wrappers add structured error reporting.
;;;
;;; Sprint 9: Added optional `names` parameter for de Bruijn → user name recovery.
;;;

(require racket/match
         racket/string
         "prelude.rkt"
         "syntax.rkt"
         "reduction.rkt"
         "typing-core.rkt"
         "qtt.rkt"
         "source-location.rkt"
         "errors.rkt"
         "pretty-print.rkt"
         "global-env.rkt"
         "elab-speculation-bridge.rkt")

(provide infer/err
         check/err
         is-type/err
         checkQ-top/err)

;; ========================================
;; Infer with error reporting
;; ========================================
;; Returns (or/c Expr? prologos-error?)
;; Sprint 9: optional `names` for de Bruijn recovery in error messages
(define (infer/err ctx e [loc srcloc-unknown] [names '()])
  (let ([result (infer ctx e)])
    (if (expr-error? result)
        (inference-failed-error loc
                                "Could not infer type"
                                (pp-expr e names))
        result)))

;; ========================================
;; Check with error reporting
;; ========================================

;; Flatten nested union types into a list of branches.
;; (A | (B | C)) → (list A B C)
(define (flatten-union-local t)
  (if (expr-union? t)
      (append (flatten-union-local (expr-union-left t))
              (flatten-union-local (expr-union-right t)))
      (list t)))

;; Returns (or/c #t prologos-error?)
;; Sprint 9: optional `names` for de Bruijn recovery in error messages
;; Phase 6: union types produce enriched union-exhaustion-error (E1006)
;; Phase 7a: per-branch re-checking — each branch gets its own speculative check
;;           for branch-specific "got: ..." messages
;; Phase D3: derivation chains from sub-failures within each branch
(define (check/err ctx e t [loc srcloc-unknown] [names '()])
  (if (check ctx e t)
      #t
      ;; Check failed — is this a union type?
      (let ([t* (whnf t)])
        (if (expr-union? t*)
            ;; Union: produce enriched error with per-branch details
            (let* ([branches (flatten-union-local t*)]
                   [branch-strs (map (lambda (b) (pp-expr b names)) branches)]
                   ;; Phase D3: collect per-branch mismatch AND derivation chain
                   [branch-info
                    (for/list ([br (in-list branches)])
                      ;; Try check against this specific branch (speculatively)
                      (define ok?
                        (with-speculative-rollback
                          (lambda () (check ctx e br))
                          values  ;; identity: #t = success, #f = failure
                          (format "union-branch-~a" (pp-expr br names))))
                      (if ok?
                          (list "matched" '())
                          ;; Per-branch failure: get sub-failures + infer actual type
                          (let* ([latest (get-latest-speculation-failure)]
                                 [sub-failures
                                  (if latest
                                      (speculation-failure-sub-failures latest)
                                      '())]
                                 [chain (build-derivation-chain sub-failures)]
                                 [actual (infer ctx e)])
                            (list (if (expr-error? actual)
                                      "<could not infer>"
                                      (pp-expr actual names))
                                  chain))))]
                   [branch-mismatches (map car branch-info)]
                   [derivation-chain (map cadr branch-info)])
              (union-exhaustion-error
               loc
               (pp-expr t names)  ;; message field = full union type string (for help line)
               branch-strs
               branch-mismatches
               (pp-expr e names)
               derivation-chain))
            ;; Non-union: existing behavior
            (let ([actual (infer ctx e)])
              (type-mismatch-error
               loc
               "Type mismatch"
               (pp-expr t names)
               (if (expr-error? actual) "<could not infer>" (pp-expr actual names))
               (pp-expr e names)))))))

;; Phase D3: Build a human-readable derivation chain from nested speculation failures.
;; Returns a list of strings, one per sub-failure, showing the speculation path.
(define (build-derivation-chain sub-failures)
  (for/list ([sf (in-list sub-failures)])
    (define label (speculation-failure-label sf))
    (define nested (speculation-failure-sub-failures sf))
    (define base (format-speculation-label label))
    (if (pair? nested)
        (format "~a (also tried: ~a)"
                base
                (string-join (map (lambda (n)
                                    (format-speculation-label
                                     (speculation-failure-label n)))
                                  nested)
                             ", "))
        base)))

;; Phase D3: Convert internal speculation labels to human-readable strings.
(define (format-speculation-label label)
  (cond
    [(string-prefix? label "union-check-left")
     "nested union left branch failed"]
    [(string-prefix? label "union-checkQ-left")
     "nested QTT union left branch failed"]
    [(string-prefix? label "map-value-widening")
     "map value widening attempted"]
    [(string-prefix? label "union-map-get-component")
     "union map key check failed"]
    [(string-prefix? label "union-branch-")
     (format "tried branch ~a" (substring label 13))]
    [else label]))

;; ========================================
;; Is-type with error reporting
;; ========================================
;; Returns (or/c #t prologos-error?)
;; Sprint 9: optional `names` for de Bruijn recovery in error messages
(define (is-type/err ctx e [loc srcloc-unknown] [names '()])
  (if (is-type ctx e)
      #t
      (not-a-type-error loc
                         "Expression is not a valid type"
                         (pp-expr e names))))

;; ========================================
;; QTT multiplicity check with error reporting
;; ========================================
;; Returns (or/c #t prologos-error?)
;; Runs checkQ-top to verify that variable usage matches declared multiplicities.
;; For v1, error message is generic (checkQ-top returns boolean only).
(define (checkQ-top/err ctx e t [loc srcloc-unknown] [names '()])
  (if (checkQ-top ctx e t)
      #t
      (multiplicity-error loc
                          "Multiplicity violation"
                          (pp-expr e names)
                          "declared"
                          "actual")))
