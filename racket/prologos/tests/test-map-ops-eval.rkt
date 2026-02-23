#lang racket/base

;;;
;;; Correctness tests for map-ops functions.
;;; Verifies that operations type-check correctly on concrete inputs.
;;;
;;; NOTE: Full eval of map-ops is blocked by the same List-conversion
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
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
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

(define preamble "(ns map-ops-eval-test)\n")

;; Helper Map definitions
(define mk-map
  (string-append
    "(def m1 (map-assoc (map-empty Keyword Nat) :x (suc zero)))\n"
    "(def m2 (map-assoc (map-assoc (map-empty Keyword Nat) :x (suc zero)) :y (suc (suc zero))))\n"))

;; ========================================
;; map-map-vals — type correctness on concrete inputs
;; ========================================

(test-case "map-ops-eval/map-map-vals-result-type-nat"
  ;; map-map-vals suc preserves Map Keyword Nat
  (define result (run-last (string-append preamble mk-map
    "(check (map-map-vals (fn (v : Nat) (suc v)) m2) : (Map Keyword Nat))")))
  (check-equal? result "OK"))

(test-case "map-ops-eval/map-map-vals-result-type-bool"
  ;; map-map-vals (zero?) changes value type to Map Keyword Bool
  (define result (run-last (string-append preamble mk-map
    "(check (map-map-vals (fn (v : Nat) (zero? v)) m2) : (Map Keyword Bool))")))
  (check-equal? result "OK"))

(test-case "map-ops-eval/map-map-vals-infer-applied"
  (define result (run-last (string-append preamble mk-map
    "(infer (map-map-vals (fn (v : Nat) (suc v)) m2))")))
  (check-contains result "Map")
  (check-contains result "Keyword")
  (check-contains result "Nat"))

;; ========================================
;; map-filter-vals — type correctness
;; ========================================

(test-case "map-ops-eval/map-filter-vals-result-type"
  (define result (run-last (string-append preamble mk-map
    "(check (map-filter-vals (fn (v : Nat) (zero? v)) m2) : (Map Keyword Nat))")))
  (check-equal? result "OK"))

(test-case "map-ops-eval/map-filter-vals-infer"
  (define result (run-last (string-append preamble mk-map
    "(infer (map-filter-vals (fn (v : Nat) (zero? v)) m2))")))
  (check-contains result "Map")
  (check-contains result "Keyword"))

;; ========================================
;; map-fold-entries — type correctness
;; ========================================

(test-case "map-ops-eval/map-fold-entries-result-nat"
  ;; Fold over entries summing values → Nat result
  (define result (run-last (string-append preamble mk-map
    "(check (map-fold-entries (fn (acc : Nat) (fn (_ : Keyword) (fn (v : Nat) (suc acc)))) zero m2) : Nat)")))
  (check-equal? result "OK"))

(test-case "map-ops-eval/map-fold-entries-cross-type"
  ;; Fold to Bool result
  (define result (run-last (string-append preamble mk-map
    "(check (map-fold-entries (fn (acc : Bool) (fn (_ : Keyword) (fn (_ : Nat) acc))) true m2) : Bool)")))
  (check-equal? result "OK"))

;; ========================================
;; map-keys-list / map-vals-list — type correctness
;; ========================================

(test-case "map-ops-eval/map-keys-list-type"
  (define result (run-last (string-append preamble mk-map
    "(check (map-keys-list m2) : (List Keyword))")))
  (check-equal? result "OK"))

(test-case "map-ops-eval/map-vals-list-type"
  (define result (run-last (string-append preamble mk-map
    "(check (map-vals-list m2) : (List Nat))")))
  (check-equal? result "OK"))

;; ========================================
;; map-merge — type correctness
;; ========================================

(test-case "map-ops-eval/map-merge-result-type"
  (define result (run-last (string-append preamble mk-map
    "(check (map-merge m1 m2) : (Map Keyword Nat))")))
  (check-equal? result "OK"))

(test-case "map-ops-eval/map-merge-infer"
  (define result (run-last (string-append preamble mk-map
    "(infer (map-merge m1 m2))")))
  (check-contains result "Map")
  (check-contains result "Keyword")
  (check-contains result "Nat"))

;; ========================================
;; Direct AST keyword eval (these DO fully reduce)
;; ========================================

(test-case "map-ops-eval/map-get-eval"
  (define result (run-last (string-append preamble
    "(eval (map-get (map-assoc (map-empty Keyword Nat) :x (suc (suc zero))) :x))")))
  (check-equal? result "2N : Nat"))

(test-case "map-ops-eval/map-size-eval"
  (define result (run-last (string-append preamble
    "(eval (map-size (map-assoc (map-assoc (map-empty Keyword Nat) :x zero) :y (suc zero))))")))
  (check-equal? result "2N : Nat"))

(test-case "map-ops-eval/map-has-key-eval"
  (define result (run-last (string-append preamble
    "(eval (map-has-key? (map-assoc (map-empty Keyword Nat) :x zero) :x))")))
  (check-equal? result "true : Bool"))
