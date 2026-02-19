#lang racket/base

;;;
;;; Tests for Phase 6: Generic Collection Functions
;;; Tests coll-map, coll-filter, coll-length, coll-to-list
;;; These use the Seq-centric architecture: to-seq → transform → from-seq
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
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
         "../namespace.rkt"
         "../multi-dispatch.rkt")

;; ========================================
;; Helpers
;; ========================================

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string s)))

(define (run-ns-last s)
  (last (run-ns s)))

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))

;; ========================================
;; Preamble
;; ========================================

(define preamble
  "(ns test)
(require (prologos.core.collection-ops :refer (coll-map coll-filter coll-length coll-to-list)))
(require (prologos.data.list :refer (List nil cons)))
(require (prologos.data.nat :refer (zero?)))
(def my-suc : (-> Nat Nat) (fn (n : Nat) (suc n)))
")

;; ========================================
;; Type checks
;; ========================================

(test-case "generic-ops/coll-map-type"
  (define result (run-ns-last (string-append preamble "(infer coll-map)")))
  (check-contains result "Pi")
  (check-contains result "List")
  (check-contains result "->"))

(test-case "generic-ops/coll-filter-type"
  (define result (run-ns-last (string-append preamble "(infer coll-filter)")))
  (check-contains result "Bool")
  (check-contains result "List"))

(test-case "generic-ops/coll-length-type"
  (define result (run-ns-last (string-append preamble "(infer coll-length)")))
  (check-contains result "List")
  (check-contains result "Nat"))

(test-case "generic-ops/coll-to-list-type"
  (define result (run-ns-last (string-append preamble "(infer coll-to-list)")))
  (check-contains result "List")
  (check-contains result "->"))

;; ========================================
;; coll-map tests
;; ========================================

(test-case "generic-ops/map-suc"
  ;; coll-map suc [1,2,3] = [2,3,4]
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (coll-map Nat Nat my-suc (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))"))
   "'[2N 3N 4N]"))

(test-case "generic-ops/map-empty"
  ;; coll-map suc [] = []
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (coll-map Nat Nat my-suc (nil Nat)))"))
   "nil"))

(test-case "generic-ops/map-singleton"
  ;; coll-map suc [5] = [6]
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (coll-map Nat Nat my-suc (cons Nat (suc (suc (suc (suc (suc zero))))) (nil Nat))))"))
   "6"))

;; ========================================
;; coll-filter tests
;; ========================================

(test-case "generic-ops/filter-zero"
  ;; coll-filter zero? [0,1,2,0] = [0,0]
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (coll-filter Nat zero? (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat zero (nil Nat)))))))"))
   "0N"))

(test-case "generic-ops/filter-all-pass"
  ;; coll-filter zero? [0,0] = [0,0]
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (coll-filter Nat zero? (cons Nat zero (cons Nat zero (nil Nat)))))"))
   "0N"))

(test-case "generic-ops/filter-none-pass"
  ;; coll-filter zero? [1,2] = []
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (coll-filter Nat zero? (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))"))
   "nil"))

(test-case "generic-ops/filter-empty"
  ;; coll-filter zero? [] = []
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (coll-filter Nat zero? (nil Nat)))"))
   "nil"))

;; ========================================
;; coll-length tests
;; ========================================

(test-case "generic-ops/length-three"
  ;; coll-length [1,2,3] = 3
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (coll-length Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))"))
   "3"))

(test-case "generic-ops/length-empty"
  ;; coll-length [] = 0
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (coll-length Nat (nil Nat)))"))
   "0N"))

(test-case "generic-ops/length-singleton"
  ;; coll-length [42] = 1
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (coll-length Nat (cons Nat zero (nil Nat))))"))
   "1"))

;; ========================================
;; coll-to-list tests
;; ========================================

(test-case "generic-ops/to-list-roundtrip"
  ;; coll-to-list [1,2,3] = [1,2,3]
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (coll-to-list Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))"))
   "'[1N 2N 3N]"))

(test-case "generic-ops/to-list-empty"
  ;; coll-to-list [] = []
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (coll-to-list Nat (nil Nat)))"))
   "nil"))

;; ========================================
;; Module loading test
;; ========================================

(test-case "generic-ops/module-load"
  ;; Verify collection-ops module loads with all 4 functions
  (define results (run-ns (string-append preamble
    "(infer coll-map)
     (infer coll-filter)
     (infer coll-length)
     (infer coll-to-list)")))
  (define type-results (filter string? results))
  (check-true (>= (length type-results) 4)
              "Expected at least 4 type-string results"))
