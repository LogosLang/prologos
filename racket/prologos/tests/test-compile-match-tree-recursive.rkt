#lang racket/base

;;;
;;; Tests for issue #18: compile-match-tree variable-binding aliasing in
;;; recursive structural-decomposition patterns.
;;;
;;; PRE-FIX BUG: compile-match-tree generated positional field names of
;;; the form `__cons_0`, `__cons_1`, etc. — STABLE per constructor, NOT
;;; per destructure level. Nested cons destructures (the recursive case
;;; in `defn sum-rows | cons r rest -> [add r [sum-rows rest]]`) shadow
;;; outer destructures' field names, so the leaf body's `let r := __cons_0`
;;; reads the INNER cons's head instead of the OUTER cons's head.
;;;
;;; Concretely, for [1, 2, 3]:
;;;   - Outer cons: __cons_0=1, __cons_1=[2,3]
;;;   - Inner reduce on [2,3]: matches third clause again
;;;   - Inner cons: __cons_0=2 (shadows!), __cons_1=[3]
;;;   - Leaf: r := __cons_0 reads 2 (wrong; should be 1)
;;;   - Result: add 2 (sum-rows [3]) = add 2 3 = 5 (wrong; should be 6)
;;;
;;; FIX: macros.rkt — switch from `string->symbol (format ...)` to
;;; `gensym (format ...)`. Each destructure level gets unique names
;;; (`__cons_0_g142`, `__cons_0_g158`), eliminating the shadowing.
;;;

(require rackunit
         "test-support.rkt")

;; ========================================
;; A. Eigentrust reproducer (the issue #18 motivating case)
;; ========================================
;; sum-rows: structural recursion with `cons r rest` destructuring + recursive
;; call on `rest`. Pre-fix returns 5 (wrong); post-fix returns 6.

(test-case "issue-18/sum-rows-3-elements"
  ;; [1, 2, 3] → 1 + 2 + 3 = 6
  (check-equal?
   (run-ns-ws-last
    "ns sumrows3\nspec sum-rows [List Nat] -> Nat\ndefn sum-rows\n  | nil            -> 0N\n  | cons r nil     -> r\n  | cons r rest    -> [add r [sum-rows rest]]\n[sum-rows '[1N 2N 3N]]")
   "6N : Nat"))

(test-case "issue-18/sum-rows-5-elements"
  ;; [1, 2, 3, 4, 5] → 15
  (check-equal?
   (run-ns-ws-last
    "ns sumrows5\nspec sum-rows [List Nat] -> Nat\ndefn sum-rows\n  | nil            -> 0N\n  | cons r nil     -> r\n  | cons r rest    -> [add r [sum-rows rest]]\n[sum-rows '[1N 2N 3N 4N 5N]]")
   "15N : Nat"))

(test-case "issue-18/sum-rows-empty"
  ;; [] → 0 (first clause matches; no compound destructure; was always working)
  (check-equal?
   (run-ns-ws-last
    "ns sumrowse\nspec sum-rows [List Nat] -> Nat\ndefn sum-rows\n  | nil            -> 0N\n  | cons r nil     -> r\n  | cons r rest    -> [add r [sum-rows rest]]\n[sum-rows [the [List Nat] nil]]")
   "0N : Nat"))

(test-case "issue-18/sum-rows-singleton"
  ;; [42] → 42 (second clause matches; outer cons destructure but no recursion;
  ;; was always working — but pin it as a regression)
  (check-equal?
   (run-ns-ws-last
    "ns sumrows1\nspec sum-rows [List Nat] -> Nat\ndefn sum-rows\n  | nil            -> 0N\n  | cons r nil     -> r\n  | cons r rest    -> [add r [sum-rows rest]]\n[sum-rows '[42N]]")
   "42N : Nat"))

;; ========================================
;; B. Both bound variables used non-trivially in body
;; ========================================
;; The shadowing affects ANY pattern where the leaf body references variables
;; bound at multiple destructure levels. These tests verify both `r` and `rest`
;; are correctly resolved.

(test-case "issue-18/list-len-cons-rest"
  ;; A length function that recurses on rest; r is unused (wildcard would also
  ;; work, but using `r` exercises the variable-binding path).
  ;; [10, 20, 30] → 3
  (check-equal?
   (run-ns-ws-last
    "ns listlen3\nspec list-len [List Nat] -> Nat\ndefn list-len\n  | nil            -> 0N\n  | cons r rest    -> [suc [list-len rest]]\n[list-len '[10N 20N 30N]]")
   "3N : Nat"))

(test-case "issue-18/double-each-via-recursion"
  ;; Map-style: cons (double r) (double-each rest). Verifies r is the OUTER
  ;; cons's head, not the inner's.
  ;; [1, 2, 3] → [2, 4, 6]
  (check-equal?
   (run-ns-ws-last
    "ns doubleeach\nspec double-each [List Nat] -> [List Nat]\ndefn double-each\n  | nil          -> nil\n  | cons r rest  -> [cons Nat [add r r] [double-each rest]]\n[double-each '[1N 2N 3N]]")
   "'[2N 4N 6N] : [prologos::data::list::List Nat]"))

;; ========================================
;; C. Different constructor (suc) — fix generalizes beyond cons
;; ========================================

(test-case "issue-18/nat-depth-via-suc-recursion"
  ;; Recursion on Nat via suc; the same shadowing pattern would affect
  ;; multi-clause defns over Nat with `suc n` patterns.
  (check-equal?
   (run-ns-ws-last
    "ns natdepth\nspec depth Nat -> Nat\ndefn depth\n  | zero    -> 0N\n  | suc n   -> [suc [depth n]]\n[depth 5N]")
   "5N : Nat"))

;; ========================================
;; D. Mixed: arity-2 with recursion
;; ========================================
;; Verifies the field-name uniqueness holds with multiple parameters.

(test-case "issue-18/arity-2-append-with-recursion"
  ;; Append: cons-recursion with TWO parameters. ys is unchanged
  ;; (parameter), xs recurses.
  ;; append [1,2] [3,4,5] → [1,2,3,4,5]
  (check-equal?
   (run-ns-ws-last
    "ns appendtest\nspec my-append [List Nat] [List Nat] -> [List Nat]\ndefn my-append\n  | nil rest          -> rest\n  | [cons x xs] rest  -> [cons Nat x [my-append xs rest]]\n[my-append '[1N 2N] '[3N 4N 5N]]")
   "'[1N 2N 3N 4N 5N] : [prologos::data::list::List Nat]"))
