#lang racket/base

;;;
;;; Tests for extended List standard library operations (Phase 2b) — Part 1
;;; reduce1, foldr1, init, scanl, iterate-n, span, break, intercalate
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
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
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
   "(imports [prologos::data::list :refer [List nil cons reduce foldr length map filter append\n"
   "   head tail singleton elem reverse sum product any? all? find nth last\n"
   "   replicate range concat concat-map take drop split-at take-while drop-while\n"
   "   partition zip-with zip unzip intersperse halve merge sort\n"
   "   reduce1 foldr1 foldr1-step init init-helper\n"
   "   span span-helper break break-helper intercalate\n"
   "   dedup dedup-helper prefix-of? suffix-of? delete\n"
   "   find-index find-index-helper count count-helper\n"
   "   scanl iterate-n sort-on]])\n"
   "(imports [prologos::data::option :refer [Option none some unwrap-or]])\n"
   "(imports [prologos::data::nat :refer [add mult pred zero?]])\n"
   "(imports [prologos::core::eq :refer [nat-eq]])\n"))


;; ========================================
;; reduce1 — Non-empty left fold
;; ========================================

(test-case "reduce1/empty"
  (check-equal?
   (last (run-ns (string-append "(ns tle1)\n" preamble
     "(eval (reduce1 add '[])) ")))
   "[prologos::data::option::none Nat] : [prologos::data::option::Option Nat]"))


(test-case "reduce1/single"
  (check-equal?
   (last (run-ns (string-append "(ns tle2)\n" preamble
     "(eval (unwrap-or zero (reduce1 add '[5N])))")))
   "5N : Nat"))


(test-case "reduce1/multi"
  (check-equal?
   (last (run-ns (string-append "(ns tle3)\n" preamble
     "(eval (unwrap-or zero (reduce1 add '[1N 2N 3N])))")))
   "6N : Nat"))


;; ========================================
;; foldr1 — Non-empty right fold
;; ========================================

(test-case "foldr1/empty"
  (check-equal?
   (last (run-ns (string-append "(ns tle4)\n" preamble
     "(eval (foldr1 add '[]))")))
   "[prologos::data::option::none Nat] : [prologos::data::option::Option Nat]"))


(test-case "foldr1/single"
  (check-equal?
   (last (run-ns (string-append "(ns tle5)\n" preamble
     "(eval (unwrap-or zero (foldr1 add '[5N])))")))
   "5N : Nat"))


(test-case "foldr1/multi"
  (check-equal?
   (last (run-ns (string-append "(ns tle6)\n" preamble
     "(eval (unwrap-or zero (foldr1 add '[1N 2N 3N])))")))
   "6N : Nat"))


;; ========================================
;; init — All elements except last
;; ========================================

(test-case "init/empty"
  (check-equal?
   (last (run-ns (string-append "(ns tle7)\n" preamble
     "(eval (init Nat '[]))")))
   "[prologos::data::option::none [prologos::data::list::List Nat]] : [prologos::data::option::Option [prologos::data::list::List Nat]]"))


(test-case "init/single"
  (check-equal?
   (last (run-ns (string-append "(ns tle8)\n" preamble
     "(eval (length (unwrap-or nil (init '[1N]))))")))
   "0N : Nat"))


(test-case "init/multi"
  ;; init '[1N 2N 3N] = some '[1N 2N], sum = 3
  (check-equal?
   (last (run-ns (string-append "(ns tle9)\n" preamble
     "(eval (sum (unwrap-or nil (init '[1N 2N 3N]))))")))
   "3N : Nat"))
