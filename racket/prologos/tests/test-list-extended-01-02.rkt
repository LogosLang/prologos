#lang racket/base

;;;
;;; Tests for extended List standard library operations (Phase 2b) — Part 1
;;; reduce1, foldr1, init, scanl, iterate-n, span, break, intercalate
;;;

(require rackunit
         racket/string
         racket/list
         racket/path
         "../errors.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../macros.rkt")

;; ================================================================
;; Helpers
;; ================================================================

;; Compute lib directory path
(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

;; Run prologos code with full namespace/module system
(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    (process-string s)))

;; Common preamble for tests
(define preamble
  (string-append
   "(require [prologos::data::list :refer [List nil cons reduce foldr length map filter append\n"
   "   head tail singleton elem reverse sum product any? all? find nth last\n"
   "   replicate range concat concat-map take drop split-at take-while drop-while\n"
   "   partition zip-with zip unzip intersperse halve merge sort\n"
   "   reduce1 foldr1 foldr1-step init init-helper\n"
   "   span span-helper break break-helper intercalate\n"
   "   dedup dedup-helper prefix-of? suffix-of? delete\n"
   "   find-index find-index-helper count count-helper\n"
   "   scanl iterate-n sort-on]])\n"
   "(require [prologos::data::option :refer [Option none some unwrap-or]])\n"
   "(require [prologos::data::nat :refer [add mult pred zero?]])\n"
   "(require [prologos::core::eq-trait :refer [nat-eq]])\n"))


;; ========================================
;; scanl — Fold with intermediate results
;; ========================================

(test-case "scanl/empty"
  ;; scanl f z [] = [z]
  (check-equal?
   (last (run-ns (string-append "(ns tle10)\n" preamble
     "(eval (length (scanl add zero '[])))")))
   "1N : Nat"))


(test-case "scanl/running-sum"
  ;; scanl add 0 [1 2 3] = [0 1 3 6], sum = 10
  (check-equal?
   (last (run-ns (string-append "(ns tle11)\n" preamble
     "(eval (sum (scanl add zero '[1N 2N 3N])))")))
   "10N : Nat"))


(test-case "scanl/length"
  ;; scanl add 0 [1 2 3] has 4 elements
  (check-equal?
   (last (run-ns (string-append "(ns tle12)\n" preamble
     "(eval (length (scanl add zero '[1N 2N 3N])))")))
   "4N : Nat"))


;; ========================================
;; iterate-n — Repeated function application
;; ========================================

(test-case "iterate-n/zero"
  (check-equal?
   (last (run-ns (string-append "(ns tle13)\n" preamble
     "(defn succ [n <Nat>] <Nat> (suc n))\n"
     "(eval (length (iterate-n zero succ zero)))")))
   "0N : Nat"))


(test-case "iterate-n/four"
  ;; iterate-n 4 succ 0 = [0 1 2 3], sum = 6
  (check-equal?
   (last (run-ns (string-append "(ns tle14)\n" preamble
     "(defn succ [n <Nat>] <Nat> (suc n))\n"
     "(eval (sum (iterate-n (suc (suc (suc (suc zero)))) succ zero)))")))
   "6N : Nat"))


(test-case "iterate-n/length"
  (check-equal?
   (last (run-ns (string-append "(ns tle15)\n" preamble
     "(defn succ [n <Nat>] <Nat> (suc n))\n"
     "(eval (length (iterate-n (suc (suc (suc zero))) succ zero)))")))
   "3N : Nat"))


;; ========================================
;; span — Split where predicate first fails
;; ========================================

(test-case "span/all-pass"
  ;; span zero? [0 0 0] = pair [0 0 0] []
  (check-equal?
   (last (run-ns (string-append "(ns tle16)\n" preamble
     "(eval (length (first (span zero? '[0N 0N 0N]))))")))
   "3N : Nat"))


(test-case "span/none-pass"
  ;; span zero? [1 2 3] = pair [] [1 2 3]
  (check-equal?
   (last (run-ns (string-append "(ns tle17)\n" preamble
     "(eval (length (first (span zero? '[1N 2N 3N]))))")))
   "0N : Nat"))


(test-case "span/mid-split"
  ;; span zero? [0 0 1 2] — prefix length 2, suffix sum 3
  (check-equal?
   (last (run-ns (string-append "(ns tle18)\n" preamble
     "(eval (length (first (span zero? '[0N 0N 1N 2N]))))")))
   "2N : Nat")
  (check-equal?
   (last (run-ns (string-append "(ns tle18b)\n" preamble
     "(eval (sum (second (span zero? '[0N 0N 1N 2N]))))")))
   "3N : Nat"))


;; ========================================
;; break — Split where predicate first succeeds
;; ========================================

(test-case "break/none-match"
  ;; break zero? [1 2 3] = pair [1 2 3] []
  (check-equal?
   (last (run-ns (string-append "(ns tle19)\n" preamble
     "(eval (sum (first (break zero? '[1N 2N 3N]))))")))
   "6N : Nat"))


(test-case "break/immediate-match"
  ;; break zero? [0 1 2] = pair [] [0 1 2]
  (check-equal?
   (last (run-ns (string-append "(ns tle20)\n" preamble
     "(eval (length (first (break zero? '[0N 1N 2N]))))")))
   "0N : Nat"))


(test-case "break/mid-split"
  ;; break zero? [1 2 0 3] — prefix sum 3, suffix length 2
  (check-equal?
   (last (run-ns (string-append "(ns tle21)\n" preamble
     "(eval (sum (first (break zero? '[1N 2N 0N 3N]))))")))
   "3N : Nat")
  (check-equal?
   (last (run-ns (string-append "(ns tle21b)\n" preamble
     "(eval (length (second (break zero? '[1N 2N 0N 3N]))))")))
   "2N : Nat"))


;; ========================================
;; intercalate — Concat with separator
;; ========================================

(test-case "intercalate/empty-list"
  ;; intercalate [0] [] = []
  (check-equal?
   (last (run-ns (string-append "(ns tle22)\n" preamble
     "(eval (length (intercalate '[0N] '[])))")))
   "0N : Nat"))


(test-case "intercalate/single-list"
  ;; intercalate [0] [[1 2]] = [1 2]
  (check-equal?
   (last (run-ns (string-append "(ns tle23)\n" preamble
     "(eval (sum (intercalate '[0N] (cons '[1N 2N] nil))))")))
   "3N : Nat"))


(test-case "intercalate/multi-list"
  ;; intercalate [0] [[1],[2],[3]] = [1,0,2,0,3], sum = 6
  (check-equal?
   (last (run-ns (string-append "(ns tle24)\n" preamble
     "(eval (sum (intercalate '[0N] (cons '[1N] (cons '[2N] (cons '[3N] nil))))))")))
   "6N : Nat"))
