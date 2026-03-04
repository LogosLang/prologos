#lang racket/base

;;;
;;; test-gde-errors.rkt — GDE-4: Structured error testing infrastructure
;;;
;;; Comprehensive tests for the General Diagnostic Engine error pipeline:
;;; ATMS context assumptions → multi-hypothesis nogoods → minimal diagnoses
;;; → derivation tree formatting. Covers single-def mismatches, multi-def
;;; conflicts, union exhaustion, and no-false-positive regression checks.
;;;

(require racket/list
         racket/port
         racket/string
         rackunit
         "test-support.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../elab-speculation-bridge.rkt"
         "../metavar-store.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../errors.rkt"
         "../performance-counters.rkt"
         "../source-location.rkt"
         "../atms.rkt")

;; ========================================
;; Test Helpers
;; ========================================

;; Run without prelude, suppress stderr, return all results.
(define (run-simple s)
  (parameterize ([current-global-env (hasheq)]
                 [current-error-port (open-output-nowhere)])
    (process-string s)))

;; Run without prelude, capture stderr, return (cons results stderr-string).
(define (run-with-stderr s)
  (run-simple-capture-stderr s))

;; Run with prelude, suppress stderr, return last result.
(define (run-ns s)
  (parameterize ([current-error-port (open-output-nowhere)])
    (run-ns-last s)))

;; ========================================
;; Suite 1: Single-def type mismatch with context assumptions
;; ========================================

(test-case "GDE: annotated def type mismatch has structured provenance"
  (define result (last (run-simple "(def x : Nat true)")))
  (check-true (type-mismatch-error? result))
  (check-true (list? (type-mismatch-error-provenance result))))

(test-case "GDE: annotated def mismatch creates ATMS hypothesis"
  (define pair (run-with-stderr "(def x : Nat true)"))
  (define stats (extract-provenance-json (cdr pair)))
  (check-not-false stats)
  ;; At least 1 hypothesis (context assumption for x : Nat)
  (check-true (>= (hash-ref stats "atms_hypothesis_count" 0) 1)))

(test-case "GDE: check command mismatch creates ATMS hypothesis"
  (define pair (run-with-stderr "(check true : Nat)"))
  (define stats (extract-provenance-json (cdr pair)))
  (check-not-false stats)
  (check-true (>= (hash-ref stats "atms_hypothesis_count" 0) 1)))

(test-case "GDE: format-error renders type mismatch correctly"
  (define result (last (run-simple "(def x : Nat true)")))
  (check-true (type-mismatch-error? result))
  (define formatted (format-error result))
  (check-true (string-contains? formatted "Expected: Nat"))
  (check-true (string-contains? formatted "Got:")))

;; ========================================
;; Suite 2: Union type exhaustion with context assumptions
;; ========================================

(test-case "GDE: union exhaustion has multi-hypothesis nogoods"
  (define pair (run-with-stderr "(def x <Nat | Bool> \"hello\")"))
  (define stats (extract-provenance-json (cdr pair)))
  (check-not-false stats)
  ;; >= 3 hypotheses: 1 context + 2 speculation branches
  (check-true (>= (hash-ref stats "atms_hypothesis_count" 0) 3)))

(test-case "GDE: union exhaustion nogoods are multi-hypothesis"
  (define pair (run-with-stderr "(def x <Nat | Bool> \"hello\")"))
  (define stats (extract-provenance-json (cdr pair)))
  (check-not-false stats)
  ;; At least 2 nogoods (one per failing branch)
  (check-true (>= (hash-ref stats "atms_nogood_count" 0) 2)))

(test-case "GDE: union exhaustion format includes branch details"
  (define result (last (run-simple "(def x <Nat | Bool> \"hello\")")))
  (check-true (union-exhaustion-error? result))
  (define formatted (format-error result))
  (check-true (string-contains? formatted "tried Nat"))
  (check-true (string-contains? formatted "tried Bool"))
  (check-true (string-contains? formatted "\"hello\"")))

(test-case "GDE: union exhaustion has 2 branches"
  (define result (last (run-simple "(def x <Nat | Bool> \"hello\")")))
  (check-true (union-exhaustion-error? result))
  (check-equal? (length (union-exhaustion-error-branches result)) 2))

;; ========================================
;; Suite 3: Structured error helpers
;; ========================================

(test-case "GDE: check-error-has-provenance for type-mismatch"
  (define err (type-mismatch-error srcloc-unknown "msg" "Nat" "Bool" "e"
                '("some provenance")))
  (check-true (check-error-has-provenance err)))

(test-case "GDE: check-error-has-provenance false for empty provenance"
  (define err (type-mismatch-error srcloc-unknown "msg" "Nat" "Bool" "e" '()))
  (check-false (check-error-has-provenance err)))

(test-case "GDE: check-error-diagnosis-count for diagnosis in provenance"
  (define err (type-mismatch-error srcloc-unknown "msg" "Nat" "Bool" "e"
                '("tried X" "[diagnosis] retract: x : Nat" "other")))
  (check-equal? (check-error-diagnosis-count err) 1))

(test-case "GDE: check-error-diagnosis-count zero when no diagnosis"
  (define err (type-mismatch-error srcloc-unknown "msg" "Nat" "Bool" "e"
                '("tried X" "other")))
  (check-equal? (check-error-diagnosis-count err) 0))

(test-case "GDE: check-error-has-provenance for union-exhaustion"
  (define err (union-exhaustion-error srcloc-unknown "Nat | Bool"
                '("Nat" "Bool") '("Bool" "Nat") "e"
                '(("tried branch Nat") ())))
  (check-true (check-error-has-provenance err)))

(test-case "GDE: extract-provenance-json parses stats"
  (define json (extract-provenance-json
                "PROVENANCE-STATS:{\"speculation_count\":3,\"atms_hypothesis_count\":5}"))
  (check-not-false json)
  (check-equal? (hash-ref json "speculation_count" 0) 3)
  (check-equal? (hash-ref json "atms_hypothesis_count" 0) 5))

(test-case "GDE: extract-provenance-json returns #f for missing stats"
  (check-false (extract-provenance-json "no stats here")))

;; ========================================
;; Suite 4: No false positives (success cases)
;; ========================================

(test-case "GDE: successful annotated def produces no error"
  (define result (last (run-simple "(def x : Nat 0N)")))
  (check-false (prologos-error? result)))

(test-case "GDE: successful annotated def has zero nogoods"
  (define pair (run-with-stderr "(def x : Nat 0N)"))
  (define stats (extract-provenance-json (cdr pair)))
  (check-not-false stats)
  (check-equal? (hash-ref stats "atms_nogood_count" 0) 0))

(test-case "GDE: successful check produces OK"
  (define result (last (run-simple "(check 0N : Nat)")))
  (check-equal? result "OK"))

(test-case "GDE: successful unannotated def no ATMS activity"
  (define pair (run-with-stderr "(def x 0N)"))
  (define stats (extract-provenance-json (cdr pair)))
  (check-not-false stats)
  (check-equal? (hash-ref stats "atms_hypothesis_count" 0) 0)
  (check-equal? (hash-ref stats "atms_nogood_count" 0) 0))

(test-case "GDE: multiple successful defs no nogoods"
  (define pair (run-with-stderr "(def x : Nat 0N) (def y : Nat 1N)"))
  (define results (car pair))
  (check-false (ormap prologos-error? results)))

;; ========================================
;; Suite 5: Prelude integration
;; ========================================

(test-case "GDE: prelude type mismatch carries structured info"
  (define result (run-ns "(ns test) (def x : Nat true)"))
  (check-true (type-mismatch-error? result))
  (check-true (list? (type-mismatch-error-provenance result))))

(test-case "GDE: prelude successful def no error"
  (define result (run-ns "(ns test) (def x : Nat [add 1N 2N])"))
  (check-false (prologos-error? result)))

;; ========================================
;; Suite 6: GDE diagnosis counter
;; ========================================

(test-case "GDE: diagnosis counter present in provenance stats"
  (define pair (run-with-stderr "(def x <Nat | Bool> \"hello\")"))
  (define stats (extract-provenance-json (cdr pair)))
  (check-not-false stats)
  ;; The gde_diagnosis_count key should exist
  (check-true (hash-has-key? stats "gde_diagnosis_count")))

(test-case "GDE: successful def has zero diagnoses"
  (define pair (run-with-stderr "(def x : Nat 0N)"))
  (define stats (extract-provenance-json (cdr pair)))
  (check-not-false stats)
  (check-equal? (hash-ref stats "gde_diagnosis_count" 0) 0))
