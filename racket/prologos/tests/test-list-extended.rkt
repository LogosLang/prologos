#lang racket/base

;;;
;;; Tests for extended List standard library operations (Phase 2b)
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
   "(require [prologos.data.list :refer [List nil cons reduce foldr length map filter append\n"
   "   head tail singleton elem reverse sum product any? all? find nth last\n"
   "   replicate range concat concat-map take drop split-at take-while drop-while\n"
   "   partition zip-with zip unzip intersperse halve merge sort\n"
   "   reduce1 foldr1 foldr1-step init init-helper\n"
   "   span span-helper break break-helper intercalate\n"
   "   dedup dedup-helper prefix-of? suffix-of? delete\n"
   "   find-index find-index-helper count count-helper\n"
   "   scanl iterate-n sort-on]])\n"
   "(require [prologos.data.option :refer [Option none some unwrap-or]])\n"
   "(require [prologos.data.nat :refer [add mult pred zero?]])\n"
   "(require [prologos.core.eq-trait :refer [nat-eq]])\n"))

;; ========================================
;; reduce1 — Non-empty left fold
;; ========================================

(test-case "reduce1/empty"
  (check-equal?
   (last (run-ns (string-append "(ns tle1)\n" preamble
     "(eval (reduce1 add '[])) ")))
   "[prologos.data.option::none Nat] : [prologos.data.option::Option Nat]"))

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
   "[prologos.data.option::none Nat] : [prologos.data.option::Option Nat]"))

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
   "[prologos.data.option::none [prologos.data.list::List Nat]] : [prologos.data.option::Option [prologos.data.list::List Nat]]"))

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
   "[prologos.data.option::none Nat] : [prologos.data.option::Option Nat]"))

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
   "[prologos.data.option::none Nat] : [prologos.data.option::Option Nat]"))

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
;; Uses le? from prologos.data.nat as the comparator.

(test-case "sort-on/empty"
  (check-equal?
   (last (run-ns (string-append "(ns tle48)\n" preamble
     "(require [prologos.data.nat :refer [le?]])\n"
     "(eval (length (sort-on le? (fn (x : Nat) x) '[])))")))
   "0N : Nat"))

(test-case "sort-on/identity-key"
  ;; sort-on le? id [3 1 2] = [1 2 3], head = 1
  (check-equal?
   (last (run-ns (string-append "(ns tle49)\n" preamble
     "(require [prologos.data.nat :refer [le?]])\n"
     "(eval (head zero (sort-on le? (fn (x : Nat) x) '[3N 1N 2N])))")))
   "1N : Nat"))
