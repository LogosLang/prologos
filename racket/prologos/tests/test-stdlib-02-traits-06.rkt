#lang racket/base

;;;
;;; Tests for prologos trait and pattern matching features:
;;;   match, Eq trait, Ord trait, elem, recursive-defn,
;;;   native constructors, implicit arguments, structural PM.
;;;
;;; Split from test-stdlib.rkt (part 2 of 3)
;;;

(require rackunit
         racket/path
         racket/string
         racket/list
         "../driver.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../macros.rkt")

;; Compute the lib directory path
(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

;; Helper: run prologos code with namespace system active
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

;; Helper: run two prologos module strings sequentially,
;; sharing the module registry so the second can require the first.
;; Returns the results from the second module.
(define (run-ns-pair s1 s2)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    ;; Process the first module (sets up ns-context, registers module)
    (process-string s1)
    ;; Capture the module info from the first module's namespace
    (let ([ctx (current-ns-context)])
      (when ctx
        (let* ([ns-sym (ns-context-current-ns ctx)]
               [exports (cond
                          [(not (null? (ns-context-exports ctx)))
                           (ns-context-exports ctx)]
                          [(not (null? (ns-context-auto-exports ctx)))
                           (reverse (ns-context-auto-exports ctx))]
                          [else '()])]
               [mi (module-info ns-sym exports (current-global-env) #f (hasheq) (hasheq) (hasheq))])
          (register-module! ns-sym mi))))
    ;; Reset for second module
    (current-global-env (hasheq))
    (current-ns-context #f)
    (process-string s2)))


;; ========================================
;; match — Structural pattern matching (sexp mode)
;; ========================================

;; match on Option — some case (sexp mode)
(test-case "match/option-some"
  (check-equal?
   (last (run-ns "(ns ro1)\n(require [prologos::data::option :refer [Option none some]])\n(eval (the Nat (match (some Nat zero) (none -> (suc zero)) (some x -> x))))"))
   "0N : Nat"))


;; match on Option — none case
(test-case "match/option-none"
  (check-equal?
   (last (run-ns "(ns ro2)\n(require [prologos::data::option :refer [Option none some]])\n(eval (the Nat (match (none Nat) (none -> (suc zero)) (some x -> x))))"))
   "1N : Nat"))


;; match on Ordering — nullary constructors
(test-case "match/ordering-lt"
  (check-equal?
   (last (run-ns "(ns ro3)\n(require [prologos::data::ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match (lt-ord) (lt-ord -> zero) (eq-ord -> (suc zero)) (gt-ord -> (suc (suc zero))))))"))
   "0N : Nat"))


(test-case "match/ordering-gt"
  (check-equal?
   (last (run-ns "(ns ro4)\n(require [prologos::data::ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match (gt-ord) (lt-ord -> zero) (eq-ord -> (suc zero)) (gt-ord -> (suc (suc zero))))))"))
   "2N : Nat"))


;; match on Result — ok case
(test-case "match/result-ok"
  (check-equal?
   (last (run-ns "(ns ro5)\n(require [prologos::data::result :refer [Result ok err]])\n(eval (the Nat (match (ok Nat Bool zero) (ok x -> x) (err _ -> (suc zero)))))"))
   "0N : Nat"))


;; match on Result — err case
(test-case "match/result-err"
  (check-equal?
   (last (run-ns "(ns ro6)\n(require [prologos::data::result :refer [Result ok err]])\n(eval (the Nat (match (err Nat Bool true) (ok x -> (suc zero)) (err _ -> zero))))"))
   "0N : Nat"))


;; match on List — nil case (structural PM)
(test-case "match/list-nil"
  ;; Match on nil list returns nil-branch value
  (check-equal?
   (last (run-ns "(ns ro7)\n(require [prologos::data::list :refer [List nil cons]])\n(eval (the Nat (match (nil Nat) (nil -> zero) (cons _ rest -> zero))))"))
   "0N : Nat"))


;; match on List — structural PM: cons gives raw tail, need explicit recursion for length
(test-case "match/length-via-match"
  (check-equal?
   (last (run-ns "(ns ro8)\n(require [prologos::data::list :refer [List nil cons length]])\n(eval (length Nat (cons Nat zero (cons Nat (suc zero) (nil Nat)))))"))
   "2N : Nat"))


;; ========================================
;; Recursive defn — self-referential function definitions
;; ========================================

;; Simple recursion: count-down n = natrec on n, calling self on predecessor
(test-case "recursive-defn/count-down"
  ;; count-down just recurses to zero (using natrec, calling itself on k)
  (check-equal?
   (last (run-ns "(ns rec1)\n(def count-down : (-> Nat Nat)\n  (fn (n : Nat) (natrec Nat zero (fn (k : Nat) (fn (_ : Nat) (count-down k))) n)))\n(eval (count-down (suc (suc (suc zero)))))"))
   "0N : Nat"))


;; Recursive defn: factorial using natrec + self-reference
;; fact 0 = 1, fact (suc k) = (suc k) * fact(k)
(test-case "recursive-defn/factorial"
  (check-equal?
   (last (run-ns "(ns rec2)\n(require [prologos::data::nat :refer [mult]])\n(def fact : (-> Nat Nat)\n  (fn (n : Nat) (natrec Nat (suc zero) (fn (k : Nat) (fn (_ : Nat) (mult (suc k) (fact k)))) n)))\n(eval (fact (suc (suc (suc zero)))))"))
   "6N : Nat")
  ;; fact(4) = 24
  (check-equal?
   (last (run-ns "(ns rec2b)\n(require [prologos::data::nat :refer [mult]])\n(def fact : (-> Nat Nat)\n  (fn (n : Nat) (natrec Nat (suc zero) (fn (k : Nat) (fn (_ : Nat) (mult (suc k) (fact k)))) n)))\n(eval (fact (suc (suc (suc (suc zero))))))"))
   "24N : Nat"))


;; Recursive defn with defn syntax
(test-case "recursive-defn/defn-syntax"
  ;; defn double-it [n : Nat] : Nat uses natrec and calls itself
  (check-equal?
   (last (run-ns "(ns rec3)\n(defn my-double [n : Nat] : Nat\n  (natrec Nat zero (fn (k : Nat) (fn (_ : Nat) (suc (suc (my-double k)))) ) n))\n(eval (my-double (suc (suc (suc zero)))))"))
   "6N : Nat"))


;; Recursive defn with match (the key use case!)
;; Sum a list of Nats using match + recursion
(test-case "recursive-defn/list-sum-with-match"
  ;; Structural match: cons gives raw tail, need explicit recursion
  (check-equal?
   (last (run-ns "(ns rec4)\n(require [prologos::data::list :refer [List nil cons]])\n(require [prologos::data::nat :refer [add]])\n(defn my-sum [xs : List Nat] : Nat\n  (match xs (nil -> zero) (cons a rest -> (add a (my-sum rest)))))\n(eval (my-sum (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))"))
   "6N : Nat"))


;; Non-recursive def still works (regression check)
(test-case "recursive-defn/non-recursive-still-works"
  (check-equal?
   (last (run-ns "(ns rec5)\n(def id-nat : (-> Nat Nat) (fn (n : Nat) n))\n(eval (id-nat (suc (suc zero))))"))
   "2N : Nat"))


;; ========================================
;; Native Constructor Verification Tests
;; Tests that validate the unfold-guarded constructor architecture:
;; - User-defined types at Type 0 (not Type 1)
;; - Nested types like Option (List Nat) well-typed
;; - Composed functions work correctly
;; ========================================

(test-case "native-ctor/list-type-0"
  ;; List Nat : Type 0 (not Type 1 from Church encoding)
  (check-equal?
   (last (run-ns "(ns nc1)\n(require [prologos::data::list :refer [List]])\n(check (List Nat) : (Type 0))"))
   "OK"))


(test-case "native-ctor/option-type-0"
  ;; Option Nat : Type 0
  (check-equal?
   (last (run-ns "(ns nc2)\n(require [prologos::data::option :refer [Option]])\n(check (Option Nat) : (Type 0))"))
   "OK"))


(test-case "native-ctor/option-list-nat"
  ;; Option (List Nat) is well-typed — was ill-typed before due to universe inflation
  (check-equal?
   (last (run-ns "(ns nc3)\n(require [prologos::data::list :refer [List nil cons]])\n(require [prologos::data::option :refer [Option some none]])\n(check (some (List Nat) (cons Nat zero (nil Nat))) : (Option (List Nat)))"))
   "OK"))


(test-case "native-ctor/list-list-nat"
  ;; List (List Nat) is well-typed — was ill-typed before due to universe inflation
  (check-equal?
   (last (run-ns "(ns nc4)\n(require [prologos::data::list :refer [List nil cons]])\n(check (cons (List Nat) (cons Nat zero (nil Nat)) (nil (List Nat))) : (List (List Nat)))"))
   "OK"))


(test-case "native-ctor/compose-sum-reverse"
  ;; sum (reverse [1,2,3]) = 6 — composition works without reification
  (check-equal?
   (last (run-ns "(ns nc5)\n(require [prologos::data::list :refer [List nil cons sum reverse]])\n(eval (sum (reverse Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "6N : Nat"))


(test-case "native-ctor/compose-sum-map"
  ;; sum (map suc [1,2,3]) = 9 — composition works without reification
  (check-equal?
   (last (run-ns "(ns nc6)\n(require [prologos::data::list :refer [List nil cons sum map]])\n(require [prologos::data::nat :refer [add]])\n(def my-suc : (-> Nat Nat) (fn (n : Nat) (suc n)))\n(eval (sum (map Nat Nat my-suc (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "9N : Nat"))
