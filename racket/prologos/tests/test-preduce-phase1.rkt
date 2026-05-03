#lang racket/base

;;; test-preduce-phase1.rkt
;;;
;;; Phase 1 regression tests for PReduce-lite.
;;; Covers: discrete value lattice, SRE domain registration, opaque-value
;;; rule for type-formers, top-level (preduce e) entry point,
;;; exn:fail:preduce-unsupported error path.
;;;
;;; Phase 1 has no reduction-active AST cases; reduction tests start
;;; in test-preduce-phase2.rkt.

(require rackunit
         "../syntax.rkt"
         "../preduce.rkt")

;; ====================================================================
;; Lattice
;; ====================================================================

(test-case "merge bot + value = value"
  (check-equal? (preduce-merge preduce-bot 5) 5)
  (check-equal? (preduce-merge 5 preduce-bot) 5))

(test-case "merge equal values = idempotent"
  (check-equal? (preduce-merge 5 5) 5)
  (check-equal? (preduce-merge 'foo 'foo) 'foo)
  (check-equal? (preduce-merge (expr-int 42) (expr-int 42)) (expr-int 42)))

(test-case "merge unequal values = top (contradiction)"
  (check-equal? (preduce-merge 5 6) preduce-top)
  (check-equal? (preduce-merge (expr-int 1) (expr-int 2)) preduce-top))

(test-case "merge top dominates"
  (check-equal? (preduce-merge preduce-top 5) preduce-top)
  (check-equal? (preduce-merge 5 preduce-top) preduce-top)
  (check-equal? (preduce-merge preduce-bot preduce-top) preduce-top))

(test-case "preduce-bot? and preduce-top? predicates"
  (check-true  (preduce-bot? preduce-bot))
  (check-false (preduce-bot? 'preduce-top))
  (check-false (preduce-bot? 5))
  (check-true  (preduce-top? preduce-top))
  (check-false (preduce-top? preduce-bot))
  (check-false (preduce-top? 5)))

;; ====================================================================
;; Opaque-value rule (type formers reduce to themselves)
;; ====================================================================

(test-case "preduce on type atoms returns the atom itself"
  (check-equal? (preduce (expr-Nat))  (expr-Nat))
  (check-equal? (preduce (expr-Bool)) (expr-Bool))
  (check-equal? (preduce (expr-Int))  (expr-Int))
  (check-equal? (preduce (expr-Unit)) (expr-Unit))
  (check-equal? (preduce (expr-Nil))  (expr-Nil)))

(test-case "preduce on Type(n) returns the same"
  (check-equal? (preduce (expr-Type 0)) (expr-Type 0))
  (check-equal? (preduce (expr-Type 5)) (expr-Type 5)))

;; ====================================================================
;; Hard-error policy: unsupported nodes raise structured error
;; ====================================================================

;; Phase-pinned negative tests use nodes that are PERMANENTLY out of
;; scope for PReduce-lite (per design doc § 3): expr-error, expr-hole,
;; expr-meta. These should never become supported, so the assertions
;; stay valid as later phases land.

(test-case "expr-error always raises preduce-unsupported"
  (check-exn preduce-unsupported-node-error?
             (lambda () (preduce (expr-error)))))

(test-case "expr-hole always raises preduce-unsupported"
  (check-exn preduce-unsupported-node-error?
             (lambda () (preduce (expr-hole)))))

(test-case "exn carries node-kind and phase fields"
  (define e
    (with-handlers ([preduce-unsupported-node-error? values])
      (preduce (expr-error))))
  (check-true  (preduce-unsupported-node-error? e))
  (check-equal? (exn:fail:preduce-unsupported-node-kind e) 'expr-error)
  (check-true  (symbol? (exn:fail:preduce-unsupported-phase e))))

;; ====================================================================
;; preduce-or-nf diagnostic helper
;; ====================================================================
;;
;; Catches the unsupported error and falls back to nf. We test that the
;; helper exists and dispatches; full validation comes in later phases
;; once nf can produce the expected value.

(test-case "preduce-or-nf falls back to nf on unsupported node"
  ;; expr-error is permanently out of scope; preduce raises; nf returns
  ;; it as-is (an error literal IS its own normal form per nf-whnf).
  (define result (preduce-or-nf (expr-error)))
  (check-equal? result (expr-error)))

;; ====================================================================
;; Parameters exist with sensible defaults
;; ====================================================================

(test-case "current-use-preduce? defaults to #f"
  (check-false (current-use-preduce?)))

(test-case "current-preduce-fuel defaults to a large positive integer"
  (check-true (and (exact-integer? (current-preduce-fuel))
                   (positive? (current-preduce-fuel)))))
