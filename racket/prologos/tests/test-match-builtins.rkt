#lang racket/base

;;;
;;; Tests for Sprint 4: Native Pattern Matching on Built-in Types (Nat/Bool)
;;;
;;; Tests that `match` (expr-reduce with structural PM) works correctly
;;; on built-in Nat and Bool types, not just user-defined data types.
;;;

(require rackunit
         racket/path
         racket/string
         racket/list
         "test-support.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../macros.rkt"
         "../metavar-store.rkt")

;; Helper: run prologos code with namespace system active
(define (run-ns s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry])
    (install-module-loader!)
    (process-string s)))

;; Helper: run code and return the last result line
(define (run-last s)
  (last (run-ns s)))

;; ========================================
;; Match on Nat: zero and suc
;; ========================================

(test-case "match-nat/zero-to-true"
  ;; match zero | zero -> true | suc _ -> false  →  true : Bool
  (check-equal?
   (run-last "(ns mn1)\n(eval (the Bool (match zero (zero -> true) (suc _ -> false))))")
   "true : Bool"))

(test-case "match-nat/suc-to-pred"
  ;; match (suc zero) | zero -> zero | suc k -> k  →  zero : Nat
  (check-equal?
   (run-last "(ns mn2)\n(eval (the Nat (match (suc zero) (zero -> zero) (suc k -> k))))")
   "0N : Nat"))

(test-case "match-nat/suc-two"
  ;; match (suc (suc zero)) | zero -> zero | suc k -> k  →  1 : Nat
  (check-equal?
   (run-last "(ns mn3)\n(eval (the Nat (match (suc (suc zero)) (zero -> zero) (suc k -> k))))")
   "1N : Nat"))

(test-case "match-nat/zero-base-case"
  ;; match zero | zero -> (suc (suc zero)) | suc _ -> zero  →  2 : Nat
  (check-equal?
   (run-last "(ns mn4)\n(eval (the Nat (match zero (zero -> (suc (suc zero))) (suc _ -> zero))))")
   "2N : Nat"))

;; ========================================
;; Match on Bool: true and false
;; ========================================

(test-case "match-bool/true-to-zero"
  ;; match true | true -> zero | false -> (suc zero)  →  zero : Nat
  (check-equal?
   (run-last "(ns mb1)\n(eval (the Nat (match true (true -> zero) (false -> (suc zero)))))")
   "0N : Nat"))

(test-case "match-bool/false-to-one"
  ;; match false | true -> zero | false -> (suc zero)  →  1 : Nat
  (check-equal?
   (run-last "(ns mb2)\n(eval (the Nat (match false (true -> zero) (false -> (suc zero)))))")
   "1N : Nat"))

(test-case "match-bool/true-to-false"
  ;; match true | true -> false | false -> true  →  false : Bool
  (check-equal?
   (run-last "(ns mb3)\n(eval (the Bool (match true (true -> false) (false -> true))))")
   "false : Bool"))

(test-case "match-bool/false-to-true"
  ;; match false | true -> false | false -> true  →  true : Bool
  (check-equal?
   (run-last "(ns mb4)\n(eval (the Bool (match false (true -> false) (false -> true))))")
   "true : Bool"))

;; ========================================
;; Defn using match on Nat (recursive)
;; ========================================

(test-case "match-nat/defn-pred"
  ;; Define pred via match, then eval
  (check-equal?
   (run-last "(ns md1)\n(defn pred2 [n : Nat] : Nat\n  (match n (zero -> zero) (suc k -> k)))\n(eval (pred2 (suc (suc (suc zero)))))")
   "2N : Nat"))

(test-case "match-nat/defn-double-recursive"
  ;; Define double recursively via match
  (check-equal?
   (run-last "(ns md2)\n(defn double2 [n : Nat] : Nat\n  (match n (zero -> zero) (suc k -> (suc (suc (double2 k))))))\n(eval (double2 (suc (suc zero))))")
   "4N : Nat"))

(test-case "match-nat/defn-add-recursive"
  ;; Define add recursively via match on second arg
  (check-equal?
   (run-last "(ns md3)\n(defn add2 [x : Nat, y : Nat] : Nat\n  (match y (zero -> x) (suc k -> (suc (add2 x k)))))\n(eval (add2 (suc (suc zero)) (suc (suc (suc zero)))))")
   "5N : Nat"))

;; ========================================
;; Defn using match on Bool
;; ========================================

(test-case "match-bool/defn-not"
  ;; Define not via match
  (check-equal?
   (run-last "(ns md4)\n(defn not2 [b : Bool] : Bool\n  (match b (true -> false) (false -> true)))\n(eval (not2 true))")
   "false : Bool"))

(test-case "match-bool/defn-and"
  ;; Define and via match
  (check-equal?
   (run-last "(ns md5)\n(defn and2 [a : Bool, b : Bool] : Bool\n  (match a (true -> b) (false -> false)))\n(eval (and2 true false))")
   "false : Bool"))

;; ========================================
;; Backward compatibility: natrec/boolrec still work
;; ========================================

(test-case "match-compat/natrec-still-works"
  ;; Raw natrec still works (no match)
  (check-equal?
   (run-last "(ns mc1)\n(eval (natrec Nat (suc zero) (fn (_ : Nat) (fn (r : Nat) (suc r))) (suc (suc zero))))")
   "3N : Nat"))

(test-case "match-compat/boolrec-still-works"
  ;; Raw boolrec still works (no match)
  (check-equal?
   (run-last "(ns mc2)\n(eval (boolrec Nat (suc zero) zero true))")
   "1N : Nat"))

;; ========================================
;; Nested match: match on Bool inside match on Nat
;; ========================================

(test-case "match-nested/nat-in-bool"
  ;; Nested: match on bool, inside match on nat
  (check-equal?
   (run-last "(ns mn5)\n(defn f [n : Nat, b : Bool] : Nat\n  (match b (true -> (match n (zero -> zero) (suc k -> k))) (false -> n)))\n(eval (f (suc (suc zero)) true))")
   "1N : Nat"))

;; ========================================
;; Numeric literal patterns
;; ========================================

(test-case "match-nat/literal-0-pattern"
  ;; | 0 -> ... is equivalent to | zero -> ...
  (check-equal?
   (run-last "(ns nlp1)\n(eval (the Bool (match zero (0N -> true) (suc _ -> false))))")
   "true : Bool"))

(test-case "match-nat/literal-0-non-match"
  ;; | 0 -> ... does NOT match suc zero
  (check-equal?
   (run-last "(ns nlp2)\n(eval (the Bool (match (suc zero) (0N -> false) (suc _ -> true))))")
   "true : Bool"))

(test-case "match-nat/literal-1-pattern"
  ;; | 1 -> ... matches suc(zero)
  (check-equal?
   (run-last "(ns nlp3)\n(eval (the Bool (match (suc zero) (0N -> false) (1N -> true) (suc _ -> false))))")
   "true : Bool"))

(test-case "match-nat/literal-2-pattern"
  ;; | 2 -> ... matches suc(suc(zero))
  (check-equal?
   (run-last "(ns nlp4)\n(eval (the Bool (match (suc (suc zero)) (0N -> false) (1N -> false) (2N -> true) (suc _ -> false))))")
   "true : Bool"))

(test-case "match-nat/literal-3-pattern"
  ;; | 3 -> ... matches 3
  (check-equal?
   (run-last "(ns nlp5)\n(eval (the Nat (match 3N (0N -> 0N) (1N -> 10N) (2N -> 20N) (3N -> 30N) (suc _ -> 99N))))")
   "30N : Nat"))

(test-case "match-nat/mixed-literal-and-ctor"
  ;; Mix numeric literal (0) with constructor pattern (suc k)
  (check-equal?
   (run-last "(ns nlp6)\n(eval (the Nat (match 5N (0N -> 0N) (suc k -> k))))")
   "4N : Nat"))

(test-case "match-nat/literal-in-defn"
  ;; Numeric patterns in a defn
  (check-equal?
   (run-last "(ns nlp7)\n(defn classify [n : Nat] : Nat\n  (match n (0N -> 0N) (1N -> 1N) (suc k -> k)))\n(eval (classify 1N))")
   "1N : Nat"))

(test-case "match-nat/literal-0-returns-computed"
  ;; | 0 -> (suc (suc zero)) returns 2
  (check-equal?
   (run-last "(ns nlp8)\n(eval (the Nat (match 0N (0N -> 2N) (suc _ -> 0N))))")
   "2N : Nat"))
