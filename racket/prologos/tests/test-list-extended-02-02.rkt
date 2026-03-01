#lang racket/base

;;;
;;; Tests for extended List standard library operations (Phase 2b) — Part 2
;;; dedup, prefix-of?, suffix-of?, delete, find-index, count, sort-on
;;;

(require rackunit
         racket/string
         racket/list
         racket/path
         "test-support.rkt"
         "../errors.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../macros.rkt")

;; ================================================================
;; Helpers
;; ================================================================

;; Compute lib directory path
;; Run prologos code with full namespace/module system
(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
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
   "(require [prologos::core::eq :refer [nat-eq]])\n"))


;; ========================================
;; delete — Remove first occurrence
;; ========================================

(test-case "delete/empty"
  (check-equal?
   (last (run-ns (string-append "(ns tle36)\n" preamble
     "(eval (length (delete nat-eq (suc (suc zero)) '[])))")))
   "0N : Nat"))


(test-case "delete/found"
  ;; delete 2 from [1 2 3 2] = [1 3 2], sum = 6
  (check-equal?
   (last (run-ns (string-append "(ns tle37)\n" preamble
     "(eval (sum (delete nat-eq (suc (suc zero)) '[1N 2N 3N 2N])))")))
   "6N : Nat"))


(test-case "delete/not-found"
  ;; delete 5 from [1 2 3] = [1 2 3], length 3
  (check-equal?
   (last (run-ns (string-append "(ns tle38)\n" preamble
     "(eval (length (delete nat-eq (suc (suc (suc (suc (suc zero))))) '[1N 2N 3N])))")))
   "3N : Nat"))


(test-case "delete/removes-only-first"
  ;; delete 2 from [2 2 2] = [2 2], length 2
  (check-equal?
   (last (run-ns (string-append "(ns tle39)\n" preamble
     "(eval (length (delete nat-eq (suc (suc zero)) '[2N 2N 2N])))")))
   "2N : Nat"))


;; ========================================
;; find-index — Index of first match
;; ========================================

(test-case "find-index/empty"
  (check-equal?
   (last (run-ns (string-append "(ns tle40)\n" preamble
     "(eval (find-index zero? '[]))")))
   "[prologos::data::option::none Nat] : [prologos::data::option::Option Nat]"))


(test-case "find-index/found"
  ;; find-index zero? [3 2 0 1] = some 2
  (check-equal?
   (last (run-ns (string-append "(ns tle41)\n" preamble
     "(eval (unwrap-or zero (find-index zero? '[3N 2N 0N 1N])))")))
   "2N : Nat"))


(test-case "find-index/not-found"
  (check-equal?
   (last (run-ns (string-append "(ns tle42)\n" preamble
     "(eval (find-index zero? '[1N 2N 3N]))")))
   "[prologos::data::option::none Nat] : [prologos::data::option::Option Nat]"))


(test-case "find-index/first-element"
  (check-equal?
   (last (run-ns (string-append "(ns tle43)\n" preamble
     "(eval (unwrap-or (suc (suc (suc zero))) (find-index zero? '[0N 1N 2N])))")))
   "0N : Nat"))


;; ========================================
;; count — Count matching elements
;; ========================================

(test-case "count/empty"
  (check-equal?
   (last (run-ns (string-append "(ns tle44)\n" preamble
     "(eval (count zero? '[]))")))
   "0N : Nat"))


(test-case "count/all-match"
  (check-equal?
   (last (run-ns (string-append "(ns tle45)\n" preamble
     "(eval (count zero? '[0N 0N 0N]))")))
   "3N : Nat"))


(test-case "count/some-match"
  (check-equal?
   (last (run-ns (string-append "(ns tle46)\n" preamble
     "(eval (count zero? '[0N 1N 0N 2N 0N]))")))
   "3N : Nat"))


(test-case "count/none-match"
  (check-equal?
   (last (run-ns (string-append "(ns tle47)\n" preamble
     "(eval (count zero? '[1N 2N 3N]))")))
   "0N : Nat"))


;; ========================================
;; sort-on — Sort by derived key
;; ========================================

;; Test sort-on with identity key (equivalent to plain sort).
;; Uses le? from prologos::data::nat as the comparator.

(test-case "sort-on/empty"
  (check-equal?
   (last (run-ns (string-append "(ns tle48)\n" preamble
     "(require [prologos::data::nat :refer [le?]])\n"
     "(eval (length (sort-on le? (fn (x : Nat) x) '[])))")))
   "0N : Nat"))


(test-case "sort-on/identity-key"
  ;; sort-on le? id [3 1 2] = [1 2 3], head = 1
  (check-equal?
   (last (run-ns (string-append "(ns tle49)\n" preamble
     "(require [prologos::data::nat :refer [le?]])\n"
     "(eval (head zero (sort-on le? (fn (x : Nat) x) '[3N 1N 2N])))")))
   "1N : Nat"))
