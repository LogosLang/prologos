#lang racket/base

;;;
;;; Tests for cond Macro
;;;
;;; Verifies:
;;; - cond syntax: cond | guard -> body | ...
;;; - Multi-way conditional dispatch
;;; - Fallthrough to last arm
;;; - cond in defn body
;;; - cond with various guard expressions
;;; - WS-mode integration
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt")

;; ========================================
;; A. Basic cond usage
;; ========================================

(test-case "cond/basic-true"
  ;; First arm with true guard fires immediately
  (check-equal?
   (run-ns-ws-last
    "(ns c1)\neval\n  cond\n    | true -> 1\n    | true -> 2")
   "1 : Int"))

(test-case "cond/fallthrough"
  ;; False guards fall through to next arm
  (check-equal?
   (run-ns-ws-last
    "(ns c2)\neval\n  cond\n    | false -> 1\n    | false -> 2\n    | true -> 3")
   "3 : Int"))

;; ========================================
;; B. cond in defn body
;; ========================================

(test-case "cond/defn-classify-zero"
  ;; cond inside defn for multi-way dispatch
  (check-equal?
   (run-ns-ws-last
    "(ns c3)\ndefn classify [n : Int] : Int\n  cond\n    | [int-eq n 0] -> 0\n    | [int-lt n 0] -> -1\n    | true -> 1\neval [classify 0]")
   "0 : Int"))

(test-case "cond/defn-classify-negative"
  (check-equal?
   (run-ns-ws-last
    "(ns c4)\ndefn classify2 [n : Int] : Int\n  cond\n    | [int-eq n 0] -> 0\n    | [int-lt n 0] -> -1\n    | true -> 1\neval [classify2 -5]")
   "-1 : Int"))

(test-case "cond/defn-classify-positive"
  (check-equal?
   (run-ns-ws-last
    "(ns c5)\ndefn classify3 [n : Int] : Int\n  cond\n    | [int-eq n 0] -> 0\n    | [int-lt n 0] -> -1\n    | true -> 1\neval [classify3 5]")
   "1 : Int"))

(test-case "cond/defn-abs-val"
  ;; cond for absolute value
  (check-equal?
   (run-ns-ws-last
    "(ns c6)\ndefn abs-c [n : Int] : Int\n  cond\n    | [int-lt n 0] -> [int-neg n]\n    | true -> n\neval [abs-c -7]")
   "7 : Int")
  (check-equal?
   (run-ns-ws-last
    "(ns c7)\ndefn abs-c2 [n : Int] : Int\n  cond\n    | [int-lt n 0] -> [int-neg n]\n    | true -> n\neval [abs-c2 3]")
   "3 : Int"))

;; ========================================
;; C. cond with Bool result
;; ========================================

(test-case "cond/bool-result"
  ;; cond returning Bool values
  (check-equal?
   (run-ns-ws-last
    "(ns c8)\ndefn is-zero [n : Int] : Bool\n  cond\n    | [int-eq n 0] -> true\n    | true -> false\neval [is-zero 0]")
   "true : Bool")
  (check-equal?
   (run-ns-ws-last
    "(ns c9)\ndefn is-zero2 [n : Int] : Bool\n  cond\n    | [int-eq n 0] -> true\n    | true -> false\neval [is-zero2 5]")
   "false : Bool"))

(displayln "All cond tests passed!")
