#lang racket/base

;;;
;;; Tests for Guard Clauses (when keyword)
;;;
;;; Verifies:
;;; - Guard syntax: | pattern when guard-expr -> body
;;; - Guard in match expressions
;;; - Guard in defn pattern clauses
;;; - Guard fallthrough (guard fails → next arm fires)
;;; - Guard + Int literal pattern interaction
;;; - Guard + variable binding (guard references pattern var)
;;; - WS-mode integration
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt")

;; ========================================
;; A. Guards in defn pattern clauses
;; ========================================

(test-case "guard/defn-abs-val-negative"
  ;; abs-val with guard: negative input → int-neg
  (check-equal?
   (run-ns-ws-last
    "(ns g1)\ndefn abs-val [n : Int] : Int\n  | n when [int-lt n 0] -> [int-neg n]\n  | n -> n\neval [abs-val -5]")
   "5 : Int"))

(test-case "guard/defn-abs-val-positive"
  ;; abs-val with guard: positive input → fallthrough to default
  (check-equal?
   (run-ns-ws-last
    "(ns g2)\ndefn abs-val2 [n : Int] : Int\n  | n when [int-lt n 0] -> [int-neg n]\n  | n -> n\neval [abs-val2 5]")
   "5 : Int"))

(test-case "guard/defn-abs-val-zero"
  ;; abs-val with guard: zero → not negative, fallthrough
  (check-equal?
   (run-ns-ws-last
    "(ns g3)\ndefn abs-val3 [n : Int] : Int\n  | n when [int-lt n 0] -> [int-neg n]\n  | n -> n\neval [abs-val3 0]")
   "0 : Int"))

(test-case "guard/defn-wildcard-default"
  ;; Guard with wildcard default arm
  (check-true
   (string-prefix?
    (run-ns-ws-last
     "(ns g4)\ndefn abs-bare [n : Int] : Int\n  | n when [int-lt n 0] -> [int-neg n]\n  | _ -> 0\neval [abs-bare -5]")
    "5 : ")))

;; ========================================
;; B. Guards in match expressions
;; ========================================

(test-case "guard/match-classify"
  ;; Multi-arm guard in match expression (wrapped in defn for type context)
  (check-equal?
   (run-ns-ws-last
    "(ns g5)\ndefn abs-m [n : Int] : Int\n  match n\n    | x when [int-lt x 0] -> [int-neg x]\n    | x -> x\neval [abs-m -3]")
   "3 : Int"))

(test-case "guard/match-classify-positive"
  ;; Guard doesn't fire → fallthrough to next arm
  (check-equal?
   (run-ns-ws-last
    "(ns g6)\ndefn abs-m2 [n : Int] : Int\n  match n\n    | x when [int-lt x 0] -> [int-neg x]\n    | x -> x\neval [abs-m2 7]")
   "7 : Int"))

;; ========================================
;; C. Guard + Int literal interaction
;; ========================================

(test-case "guard/int-lit-plus-guard"
  ;; Int literal arms combined with guarded arms
  (check-equal?
   (run-ns-ws-last
    "(ns g7)\ndefn classify [n : Int] : Int\n  | 0 -> 0\n  | n when [int-lt n 0] -> -1\n  | _ -> 1\neval [classify 0]")
   "0 : Int")
  (check-equal?
   (run-ns-ws-last
    "(ns g8)\ndefn classify2 [n : Int] : Int\n  | 0 -> 0\n  | n when [int-lt n 0] -> -1\n  | _ -> 1\neval [classify2 -5]")
   "-1 : Int")
  (check-equal?
   (run-ns-ws-last
    "(ns g9)\ndefn classify3 [n : Int] : Int\n  | 0 -> 0\n  | n when [int-lt n 0] -> -1\n  | _ -> 1\neval [classify3 5]")
   "1 : Int"))

;; ========================================
;; D. Direct boolrec comparison (regression)
;; ========================================

(test-case "guard/direct-boolrec-baseline"
  ;; Manually-written boolrec should still work
  (check-true
   (string-prefix?
    (run-ns-ws-last
     "(ns g10)\ndefn g [n : Int] : Int\n  boolrec _ [int-neg n] 0 [int-lt n 0]\neval [g -5]")
    "5 : ")))

;; ========================================
;; E. if-body comparison
;; ========================================

(test-case "guard/if-body-equivalent"
  ;; Guards should give same result as if-body approach
  (check-true
   (string-prefix?
    (run-ns-ws-last
     "(ns g11)\ndefn abs-if [n : Int] : Int\n  if [int-lt n 0] [int-neg n] 0\neval [abs-if -5]")
    "5 : ")))

(displayln "All guard tests passed!")
