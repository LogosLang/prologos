#lang racket/base

;;;
;;; Tests for HKT Phase 4: Coherence and Instance Safety
;;; Verifies duplicate detection, most-specific-wins, and overlap warnings.
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         racket/port
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt")

;; ========================================
;; Helpers
;; ========================================

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

(define (run-ns-last s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)])
    (install-module-loader!)
    (last (process-string s))))

;; ========================================
;; 1. Duplicate detection in register-impl!
;; ========================================

(test-case "coherence: duplicate impl with different dict name is error"
  (parameterize ([current-impl-registry (hasheq)])
    (register-impl! 'Nat--Eq (impl-entry 'Eq '(Nat) 'Nat--Eq--dict))
    ;; Re-register with DIFFERENT dict name → error
    (check-exn exn:fail?
      (lambda ()
        (register-impl! 'Nat--Eq (impl-entry 'Eq '(Nat) 'other-dict))))))

(test-case "coherence: benign re-registration with same dict name is OK"
  (parameterize ([current-impl-registry (hasheq)])
    (register-impl! 'Nat--Eq (impl-entry 'Eq '(Nat) 'Nat--Eq--dict))
    ;; Re-register with SAME dict name → no error (prelude loading scenario)
    (check-not-exn
      (lambda ()
        (register-impl! 'Nat--Eq (impl-entry 'Eq '(Nat) 'Nat--Eq--dict))))))

(test-case "coherence: duplicate HKT impl with different dict name is error"
  (parameterize ([current-impl-registry (hasheq)])
    (register-impl! 'List--Seqable (impl-entry 'Seqable '(List) 'List--Seqable--dict))
    (check-exn exn:fail?
      (lambda ()
        (register-impl! 'List--Seqable (impl-entry 'Seqable '(List) 'alt-seqable))))))

(test-case "coherence: different type args register separately"
  (parameterize ([current-impl-registry (hasheq)])
    (register-impl! 'Nat--Eq (impl-entry 'Eq '(Nat) 'Nat--Eq--dict))
    ;; Bool--Eq is a different key → no conflict
    (check-not-exn
      (lambda ()
        (register-impl! 'Bool--Eq (impl-entry 'Eq '(Bool) 'Bool--Eq--dict))))
    ;; Both should exist
    (check-true (impl-entry? (lookup-impl 'Nat--Eq)))
    (check-true (impl-entry? (lookup-impl 'Bool--Eq)))))

;; ========================================
;; 2. Overlap detection in register-param-impl!
;; ========================================

(test-case "coherence: overlapping parametric impls produce warning"
  (parameterize ([current-param-impl-registry (hasheq)])
    ;; First: impl Eq (List A) where (Eq A)
    (register-param-impl! 'Eq
      (param-impl-entry 'Eq '((List A)) '(A) 'List--Eq--dict '((Eq A))))
    ;; Second: impl Eq (List Nat) — overlaps with first on (List Nat)
    ;; This should emit a warning to stderr
    (define output
      (with-output-to-string
        (lambda ()
          (parameterize ([current-error-port (current-output-port)])
            (register-param-impl! 'Eq
              (param-impl-entry 'Eq '((List Nat)) '() 'List-Nat--Eq--dict '()))))))
    (check-true (string-contains? output "overlapping"))))

(test-case "coherence: non-overlapping parametric impls — no warning"
  (parameterize ([current-param-impl-registry (hasheq)])
    ;; impl Eq (List A) where (Eq A)
    (register-param-impl! 'Eq
      (param-impl-entry 'Eq '((List A)) '(A) 'List--Eq--dict '((Eq A))))
    ;; impl Eq (PVec A) where (Eq A) — different constructor, no overlap
    (define output
      (with-output-to-string
        (lambda ()
          (parameterize ([current-error-port (current-output-port)])
            (register-param-impl! 'Eq
              (param-impl-entry 'Eq '((PVec A)) '(A) 'PVec--Eq--dict '((Eq A))))))))
    (check-equal? output "")))

;; ========================================
;; 3. could-overlap? helper tests
;; ========================================

(test-case "coherence: could-overlap (List A) vs (List Nat)"
  (define e1 (param-impl-entry 'Eq '((List A)) '(A) 'x '()))
  (define e2 (param-impl-entry 'Eq '((List Nat)) '() 'y '()))
  (check-true (parametric-impls-could-overlap? e1 e2)))

(test-case "coherence: could-overlap (List A) vs (PVec B)"
  (define e1 (param-impl-entry 'Eq '((List A)) '(A) 'x '()))
  (define e2 (param-impl-entry 'Eq '((PVec B)) '(B) 'y '()))
  (check-false (parametric-impls-could-overlap? e1 e2)))

(test-case "coherence: could-overlap A vs B (both variables)"
  (define e1 (param-impl-entry 'Show '(A) '(A) 'x '()))
  (define e2 (param-impl-entry 'Show '(B) '(B) 'y '()))
  (check-true (parametric-impls-could-overlap? e1 e2)))

(test-case "coherence: could-overlap Nat vs Bool (both ground)"
  (define e1 (param-impl-entry 'Show '(Nat) '() 'x '()))
  (define e2 (param-impl-entry 'Show '(Bool) '() 'y '()))
  (check-false (parametric-impls-could-overlap? e1 e2)))

;; ========================================
;; 4. Backward compatibility
;; ========================================

(test-case "coherence: prelude loads without duplicate errors"
  ;; Loading the full prelude should not trigger any duplicate instance errors
  (define result
    (run-ns-last
      (string-append
        "(ns test-coherence-compat)\n"
        "(eval (suc zero))\n")))
  (check-equal? result "1N : Nat"))

(test-case "coherence: existing trait instances work after coherence changes"
  (define result
    (run-ns-last
      (string-append
        "(ns test-coherence-compat2)\n"
        "(require [prologos::core::eq-trait :refer [Nat--Eq--dict]])\n"
        "(eval (Nat--Eq--dict (suc zero) (suc zero)))\n")))
  (check-equal? result "true : Bool"))

(test-case "coherence: existing numeric traits all work"
  (define result
    (run-ns-last
      (string-append
        "(ns test-coherence-compat3)\n"
        "(eval (add (suc zero) (suc (suc zero))))\n")))
  (check-equal? result "3N : Nat"))
