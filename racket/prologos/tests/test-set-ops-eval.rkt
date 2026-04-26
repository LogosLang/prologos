#lang racket/base

;;;
;;; Correctness tests for set-ops functions.
;;; Verifies that operations type-check correctly on concrete inputs.
;;;
;;; NOTE: Full eval of set-ops is blocked by the same List-conversion
;;; reduction limitation as pvec-ops. See test-pvec-ops-eval.rkt header.
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt"
         "../macros.rkt"
         "../syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../multi-dispatch.rkt")

;; ========================================
;; Helpers
;; ========================================

(define (run-ns s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string s)))

(define (run-last s)
  (last (run-ns s)))

(define (check-contains actual substr [msg #f])
  (check-true (and (string? actual) (string-contains? actual substr))
              (or msg (format "Expected ~s to contain ~s" actual substr))))

(define preamble "(ns set-ops-eval-test)\n")

;; Helper Set definitions
(define mk-set
  (string-append
    "(def s1 (set-insert (set-empty Nat) zero))\n"
    "(def s2 (set-insert (set-insert (set-empty Nat) zero) (suc zero)))\n"))

;; ========================================
;; set-map — type correctness on concrete inputs
;; ========================================

(test-case "set-ops-eval/set-map-result-type-nat"
  (define result (run-last (string-append preamble mk-set
    "(check (set-map (fn (x : Nat) (suc x)) s2) : (Set Nat))")))
  (check-equal? result "OK"))

(test-case "set-ops-eval/set-map-result-type-bool"
  (define result (run-last (string-append preamble mk-set
    "(check (set-map (fn (x : Nat) (zero? x)) s2) : (Set Bool))")))
  (check-equal? result "OK"))

(test-case "set-ops-eval/set-map-infer-applied"
  (define result (run-last (string-append preamble mk-set
    "(infer (set-map (fn (x : Nat) (suc x)) s2))")))
  (check-contains result "Set")
  (check-contains result "Nat"))

;; ========================================
;; set-filter — type correctness
;; ========================================

(test-case "set-ops-eval/set-filter-result-type"
  (define result (run-last (string-append preamble mk-set
    "(check (set-filter (fn (x : Nat) (zero? x)) s2) : (Set Nat))")))
  (check-equal? result "OK"))

(test-case "set-ops-eval/set-filter-infer"
  (define result (run-last (string-append preamble mk-set
    "(infer (set-filter (fn (x : Nat) (zero? x)) s2))")))
  (check-contains result "Set")
  (check-contains result "Nat"))

;; ========================================
;; set-fold — type correctness
;; ========================================

(test-case "set-ops-eval/set-fold-result-nat"
  (define result (run-last (string-append preamble mk-set
    "(check (set-fold (fn (acc : Nat) (fn (x : Nat) (suc acc))) zero s2) : Nat)")))
  (check-equal? result "OK"))

(test-case "set-ops-eval/set-fold-cross-type"
  (define result (run-last (string-append preamble mk-set
    "(check (set-fold (fn (acc : Bool) (fn (_ : Nat) acc)) true s2) : Bool)")))
  (check-equal? result "OK"))

;; ========================================
;; set-any? / set-all? — type correctness
;; ========================================

(test-case "set-ops-eval/set-any-result-type"
  (define result (run-last (string-append preamble mk-set
    "(check (set-any? (fn (x : Nat) (zero? x)) s2) : Bool)")))
  (check-equal? result "OK"))

(test-case "set-ops-eval/set-all-result-type"
  (define result (run-last (string-append preamble mk-set
    "(check (set-all? (fn (x : Nat) (zero? x)) s2) : Bool)")))
  (check-equal? result "OK"))

;; ========================================
;; set-from-list-fn / set-to-list-fn — type correctness
;; ========================================

(test-case "set-ops-eval/set-from-list-fn-type"
  (define result (run-last (string-append preamble
    "(check (set-from-list-fn (cons Nat zero (nil Nat))) : (Set Nat))")))
  (check-equal? result "OK"))

(test-case "set-ops-eval/set-to-list-fn-type"
  (define result (run-last (string-append preamble mk-set
    "(check (set-to-list-fn s1) : (List Nat))")))
  (check-equal? result "OK"))

;; ========================================
;; Direct AST keyword eval (these DO fully reduce)
;; ========================================

(test-case "set-ops-eval/set-insert-member-eval"
  (define result (run-last (string-append preamble
    "(eval (set-member? (set-insert (set-empty Nat) (suc zero)) (suc zero)))")))
  (check-equal? result "true : Bool"))

(test-case "set-ops-eval/set-size-eval"
  (define result (run-last (string-append preamble
    "(eval (set-size (set-insert (set-insert (set-empty Nat) zero) (suc zero))))")))
  (check-equal? result "2N : Nat"))
