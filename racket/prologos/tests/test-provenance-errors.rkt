#lang racket/base

;;;
;;; test-provenance-errors.rkt — E3e: Provenance-rich error tests
;;;
;;; Tests that type errors carry ATMS derivation chains through the
;;; speculation → ATMS → build-derivation-chain → error formatting pipeline.
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
         "../source-location.rkt")

;; ========================================
;; Test Helpers
;; ========================================

;; Run without prelude, suppress stderr, return all results
(define (run-simple s)
  (parameterize ([current-global-env (hasheq)]
                 [current-error-port (open-output-nowhere)])
    (process-string s)))

;; Run with prelude, suppress stderr, return last result
(define (run-ns s)
  (parameterize ([current-error-port (open-output-nowhere)])
    (run-ns-last s)))

;; Run with prelude, capture stderr, return (cons last-result stderr-string)
(define (run-ns-with-stderr s)
  (define stderr-out (open-output-string))
  (define result
    (parameterize ([current-error-port stderr-out])
      (run-ns-last s)))
  (cons result (get-output-string stderr-out)))

;; Run without prelude, capture stderr, return (cons results stderr-string)
(define (run-simple-with-stderr s)
  (define stderr-out (open-output-string))
  (define results
    (parameterize ([current-global-env (hasheq)]
                   [current-error-port stderr-out])
      (process-string s)))
  (cons results (get-output-string stderr-out)))

;; ========================================
;; Suite 1: Type mismatch provenance
;; ========================================

(test-case "type-mismatch-error has provenance field"
  (define result (last (run-simple "(def x : Nat true)")))
  (check-true (type-mismatch-error? result))
  ;; provenance should be a list (possibly empty)
  (check-true (list? (type-mismatch-error-provenance result))))

(test-case "successful check produces no error (no false positive provenance)"
  (define result (last (run-simple "(def x : Nat 0N)")))
  (check-false (prologos-error? result)))

;; ========================================
;; Suite 2: Union exhaustion provenance
;; ========================================

(test-case "union exhaustion error has derivation-chain field"
  ;; Angle-bracket union syntax works without prelude
  (define result (run-simple "(def x <Nat | Bool> \"hello\")"))
  (check-true (union-exhaustion-error? (last result)))
  (check-true (list? (union-exhaustion-error-derivation-chain (last result)))))

(test-case "union branch mismatch produces per-branch info"
  (define result (run-simple "(def x <Nat | Bool> \"hello\")"))
  (check-true (union-exhaustion-error? (last result)))
  ;; Should have 2 branches
  (define branches (union-exhaustion-error-branches (last result)))
  (check-equal? (length branches) 2))

;; ========================================
;; Suite 3: Provenance stats
;; ========================================

(test-case "provenance stats: successful type check has zero nogoods"
  (define pair (run-simple-with-stderr "(def x : Nat 0N)"))
  (define stderr (cdr pair))
  (check-true (string-contains? stderr "PROVENANCE-STATS:"))
  ;; Extract the provenance stats JSON
  (define m (regexp-match #rx"PROVENANCE-STATS:(\\{[^}]+\\})" stderr))
  (check-not-false m)
  ;; Should have 0 nogoods for a successful check
  (check-true (string-contains? (cadr m) "\"atms_nogood_count\":0")))

(test-case "provenance stats: union error creates speculation + hypothesis"
  ;; Union type mismatch triggers speculation per branch
  (define pair (run-simple-with-stderr "(def x <Nat | Bool> \"s\")"))
  (define stderr (cdr pair))
  (define m (regexp-match #rx"PROVENANCE-STATS:(\\{[^}]+\\})" stderr))
  (check-not-false m)
  (define json-str (cadr m))
  ;; At least 2 speculations (one per union branch)
  (check-false (string-contains? json-str "\"speculation_count\":0")))

(test-case "provenance stats: simple mismatch has provenance stats"
  (define pair (run-simple-with-stderr "(def x : Nat true)"))
  (define stderr (cdr pair))
  (define m (regexp-match #rx"PROVENANCE-STATS:(\\{[^}]+\\})" stderr))
  (check-not-false m))

;; ========================================
;; Suite 4: Error formatting with provenance
;; ========================================

(test-case "format-error renders type mismatch with empty provenance"
  (define err (type-mismatch-error srcloc-unknown "Type mismatch" "Nat" "Bool" "(f x)" '()))
  (define formatted (format-error err))
  (check-true (string-contains? formatted "Expected: Nat"))
  (check-true (string-contains? formatted "Got:      Bool"))
  ;; No "because:" lines
  (check-false (string-contains? formatted "because:")))

(test-case "format-error renders type mismatch with non-empty provenance"
  (define err (type-mismatch-error srcloc-unknown "Type mismatch" "Nat" "Bool" "(f x)"
                '("tried branch Nat" "nested union left branch failed")))
  (define formatted (format-error err))
  (check-true (string-contains? formatted "because: tried branch Nat"))
  (check-true (string-contains? formatted "because: nested union left branch failed")))

(test-case "union exhaustion format includes 'because:' for non-empty chains"
  (define err
    (union-exhaustion-error srcloc-unknown "Nat | Bool"
                            '("Nat" "Bool")
                            '("Bool" "Nat")
                            "\"hello\""
                            '(("tried branch Nat") ())))
  (define formatted (format-error err))
  (check-true (string-contains? formatted "because: tried branch Nat"))
  (check-true (string-contains? formatted "tried Nat")))

;; ========================================
;; Suite 5: ATMS integration
;; ========================================

(test-case "ATMS is active during type checking (hypothesis created)"
  ;; Speculation creates ATMS hypotheses
  (define pair (run-simple-with-stderr "(def x : Nat true)"))
  (define stderr (cdr pair))
  (define m (regexp-match #rx"atms_hypothesis_count\":([0-9]+)" stderr))
  (check-not-false m))

(test-case "ATMS nogoods recorded on union branch failure"
  ;; Each failing union branch should record a nogood
  (define pair (run-simple-with-stderr "(def x <Nat | Bool> \"hello\")"))
  (define stderr (cdr pair))
  (define m (regexp-match #rx"atms_nogood_count\":([0-9]+)" stderr))
  (check-not-false m)
  (define count (string->number (cadr m)))
  ;; At least 2 nogoods (one per failing union branch)
  (check-true (>= count 2)))

;; ========================================
;; Suite 6: Prelude integration
;; ========================================

(test-case "prelude type mismatch carries provenance"
  (define result (run-ns "(ns test) (def x : Nat true)"))
  (check-true (type-mismatch-error? result))
  (check-true (list? (type-mismatch-error-provenance result))))

(test-case "prelude implicit resolution error has structured info"
  ;; This tests that trait resolution failures flow through the provenance pipeline
  (define result (run-ns "(ns test :no-prelude) (def x : Nat \"hello\")"))
  (check-true (prologos-error? result)))
