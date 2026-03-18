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
;; dedup — Remove consecutive duplicates
;; ========================================

(test-case "dedup/empty"
  (check-equal?
   (last (run-ns (string-append "(ns tle25)\n" preamble
     "(eval (length (dedup nat-eq '[])))")))
   "0N : Nat"))


(test-case "dedup/no-duplicates"
  (check-equal?
   (last (run-ns (string-append "(ns tle26)\n" preamble
     "(eval (length (dedup nat-eq '[1N 2N 3N])))")))
   "3N : Nat"))


(test-case "dedup/with-duplicates"
  ;; [1 1 2 2 2 3] → [1 2 3], length 3
  (check-equal?
   (last (run-ns (string-append "(ns tle27)\n" preamble
     "(eval (length (dedup nat-eq '[1N 1N 2N 2N 2N 3N])))")))
   "3N : Nat"))


(test-case "dedup/all-same"
  ;; [5 5 5 5] → [5], length 1
  (check-equal?
   (last (run-ns (string-append "(ns tle28)\n" preamble
     "(eval (length (dedup nat-eq '[5N 5N 5N 5N])))")))
   "1N : Nat"))


;; ========================================
;; prefix-of? — Prefix check
;; ========================================

(test-case "prefix-of?/empty-prefix"
  (check-equal?
   (last (run-ns (string-append "(ns tle29)\n" preamble
     "(eval (prefix-of? nat-eq '[] '[1N 2N 3N]))")))
   "true : Bool"))


(test-case "prefix-of?/match"
  (check-equal?
   (last (run-ns (string-append "(ns tle30)\n" preamble
     "(eval (prefix-of? nat-eq '[1N 2N] '[1N 2N 3N]))")))
   "true : Bool"))


(test-case "prefix-of?/no-match"
  (check-equal?
   (last (run-ns (string-append "(ns tle31)\n" preamble
     "(eval (prefix-of? nat-eq '[1N 3N] '[1N 2N 3N]))")))
   "false : Bool"))


(test-case "prefix-of?/longer-prefix"
  (check-equal?
   (last (run-ns (string-append "(ns tle32)\n" preamble
     "(eval (prefix-of? nat-eq '[1N 2N 3N 4N] '[1N 2N 3N]))")))
   "false : Bool"))


;; ========================================
;; suffix-of? — Suffix check
;; ========================================

(test-case "suffix-of?/empty-suffix"
  (check-equal?
   (last (run-ns (string-append "(ns tle33)\n" preamble
     "(eval (suffix-of? nat-eq '[] '[1N 2N 3N]))")))
   "true : Bool"))


(test-case "suffix-of?/match"
  (check-equal?
   (last (run-ns (string-append "(ns tle34)\n" preamble
     "(eval (suffix-of? nat-eq '[2N 3N] '[1N 2N 3N]))")))
   "true : Bool"))


(test-case "suffix-of?/no-match"
  (check-equal?
   (last (run-ns (string-append "(ns tle35)\n" preamble
     "(eval (suffix-of? nat-eq '[1N 3N] '[1N 2N 3N]))")))
   "false : Bool"))
