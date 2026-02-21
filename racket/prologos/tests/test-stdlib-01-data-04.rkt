#lang racket/base

;;;
;;; Tests for prologos standard library data modules:
;;;   prologos::data::nat, prologos::data::bool, prologos::data::pair,
;;;   prologos::data::eq, prologos::data::option, prologos::data::result,
;;;   prologos::data::ordering, and inline data definitions.
;;;
;;; Split from test-stdlib.rkt (part 1 of 3)
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
;; prologos::data::pair — bimap
;; ========================================

(test-case "pair/bimap"
  ;; Auto-implicit order: A C B D (first-occurrence in spec [A -> C] [B -> D] [Sigma [_ <A>] B] -> ...)
  (check-equal?
   (run-ns "(ns pb1)\n(require [prologos::data::pair :refer [bimap]])\n(eval (first (bimap Nat Nat Bool Bool (fn (x : Nat) (suc x)) (fn (b : Bool) (boolrec Bool false true b)) (pair (suc zero) true))))")
   '("2N : Nat"))
  (check-equal?
   (run-ns "(ns pb2)\n(require [prologos::data::pair :refer [bimap]])\n(eval (second (bimap Nat Nat Bool Bool (fn (x : Nat) (suc x)) (fn (b : Bool) (boolrec Bool false true b)) (pair (suc zero) true))))")
   '("false : Bool")))


;; ========================================
;; prologos::core — on combinator
;; ========================================

(test-case "core/on"
  ;; Auto-implicit order: B C A (first-occurrence in spec [B -> B -> C] [A -> B] A A -> C)
  ;; (on nat-eq? id) should compare two nats for equality: on(nat-eq?, id, 3, 3) = true
  (check-equal?
   (run-ns "(ns co1)\n(require [prologos::data::nat :refer [nat-eq?]])\n(eval (on Nat Bool Nat nat-eq? (fn (x : Nat) x) (suc (suc (suc zero))) (suc (suc (suc zero)))))")
   '("true : Bool"))
  ;; on(nat-eq?, id, 2, 3) = false
  (check-equal?
   (run-ns "(ns co2)\n(require [prologos::data::nat :refer [nat-eq?]])\n(eval (on Nat Bool Nat nat-eq? (fn (x : Nat) x) (suc (suc zero)) (suc (suc (suc zero)))))")
   '("false : Bool")))


;; ========================================
;; Cross-module tests with new functions
;; ========================================

(test-case "cross-module: sub + le? + not"
  (check-equal?
   (run-ns "(ns cx1)\n(require [prologos::data::nat :refer [sub le?]])\n(require [prologos::data::bool :refer [not]])\n(eval (not (le? (suc (suc (suc (suc (suc zero))))) (suc (suc (suc zero))))))")
   '("true : Bool")))


;; ========================================
;; prologos::data::eq — Module Loading
;; ========================================

(test-case "load prologos::data::eq"
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)])
    (install-module-loader!)
    (define mod (load-module 'prologos::data::eq #f))
    (check-not-false (module-info? mod))
    (define exports (module-info-exports mod))
    (check-not-false (member 'sym exports) "exports sym")
    (check-not-false (member 'cong exports) "exports cong")
    (check-not-false (member 'trans exports) "exports trans")))


;; ========================================
;; prologos::data::eq — sym (symmetry)
;; ========================================

(test-case "eq/sym"
  ;; sym : Eq(Nat, 0, 0) -> Eq(Nat, 0, 0)
  (check-equal?
   (run-ns "(ns es1)\n(require [prologos::data::eq :refer [sym]])\n(check (sym Nat zero zero (the (Eq Nat zero zero) refl)) : (Eq Nat zero zero))")
   '("OK"))
  ;; sym : Eq(Nat, 1, 1) -> Eq(Nat, 1, 1)
  (check-equal?
   (run-ns "(ns es2)\n(require [prologos::data::eq :refer [sym]])\n(check (sym Nat (suc zero) (suc zero) (the (Eq Nat (suc zero) (suc zero)) refl)) : (Eq Nat (suc zero) (suc zero)))")
   '("OK"))
  ;; sym evaluates to refl
  (check-equal?
   (run-ns "(ns es3)\n(require [prologos::data::eq :refer [sym]])\n(eval (sym Nat zero zero (the (Eq Nat zero zero) refl)))")
   '("refl : [Eq Nat 0N 0N]")))


;; ========================================
;; prologos::data::eq — cong (congruence)
;; ========================================

(test-case "eq/cong"
  ;; cong suc : Eq(Nat, 0, 0) -> Eq(Nat, 1, 1)
  (check-equal?
   (run-ns "(ns ec1)\n(require [prologos::data::eq :refer [cong]])\n(check (cong Nat Nat zero zero (fn (x : Nat) (suc x)) (the (Eq Nat zero zero) refl)) : (Eq Nat (suc zero) (suc zero)))")
   '("OK"))
  ;; cong evaluates to refl
  (check-equal?
   (run-ns "(ns ec2)\n(require [prologos::data::eq :refer [cong]])\n(eval (cong Nat Nat zero zero (fn (x : Nat) (suc x)) (the (Eq Nat zero zero) refl)))")
   '("refl : [Eq Nat 1N 1N]")))


;; ========================================
;; prologos::data::eq — trans (transitivity)
;; ========================================

(test-case "eq/trans"
  ;; trans : Eq(Nat, 0, 0) -> Eq(Nat, 0, 0) -> Eq(Nat, 0, 0)
  (check-equal?
   (run-ns "(ns et1)\n(require [prologos::data::eq :refer [trans]])\n(check (trans Nat zero zero zero (the (Eq Nat zero zero) refl) (the (Eq Nat zero zero) refl)) : (Eq Nat zero zero))")
   '("OK"))
  ;; trans evaluates to refl
  (check-equal?
   (run-ns "(ns et2)\n(require [prologos::data::eq :refer [trans]])\n(eval (trans Nat zero zero zero (the (Eq Nat zero zero) refl) (the (Eq Nat zero zero) refl)))")
   '("refl : [Eq Nat 0N 0N]")))


;; ========================================
;; prologos::data::option — Module Loading
;; ========================================

(test-case "load prologos::data::option"
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)])
    (install-module-loader!)
    (define mod (load-module 'prologos::data::option #f))
    (check-not-false (module-info? mod))
    (define exports (module-info-exports mod))
    (check-not-false (member 'Option exports) "exports Option")
    (check-not-false (member 'none exports) "exports none")
    (check-not-false (member 'some exports) "exports some")
    (check-not-false (member 'map exports) "exports map")
    (check-not-false (member 'flat-map exports) "exports flat-map")
    (check-not-false (member 'unwrap-or exports) "exports unwrap-or")))


;; ========================================
;; prologos::data::option — Constructors
;; ========================================

(test-case "option/constructors"
  (check-equal?
   (run-ns "(ns oc1)\n(require [prologos::data::option :refer [Option none some]])\n(check (none Nat) : (Option Nat))")
   '("OK"))
  (check-equal?
   (run-ns "(ns oc2)\n(require [prologos::data::option :refer [Option none some]])\n(check (some Nat zero) : (Option Nat))")
   '("OK"))
  (check-equal?
   (run-ns "(ns oc3)\n(require [prologos::data::option :refer [Option none some]])\n(check (some Bool true) : (Option Bool))")
   '("OK")))


;; ========================================
;; prologos::data::option — Elimination
;; ========================================

(test-case "option/elimination"
  ;; Eliminate some: extract value via match
  (check-equal?
   (run-ns "(ns oe1)\n(require [prologos::data::option :refer [Option none some]])\n(eval (the Nat (match (some Nat (suc zero)) (none -> zero) (some x -> (suc x)))))")
   '("2N : Nat"))
  ;; Eliminate none: get default via match
  (check-equal?
   (run-ns "(ns oe2)\n(require [prologos::data::option :refer [Option none some]])\n(eval (the Nat (match (none Nat) (none -> (suc (suc zero))) (some x -> (suc x)))))")
   '("2N : Nat")))


;; ========================================
;; prologos::data::option — Combinators
;; ========================================

(test-case "option/map"
  ;; Map over some
  (check-equal?
   (run-ns "(ns om1)\n(require [prologos::data::option :refer [Option none some map unwrap-or]])\n(eval (unwrap-or Nat zero (map Nat Nat (fn (x : Nat) (suc x)) (some Nat (suc zero)))))")
   '("2N : Nat"))
  ;; Map over none
  (check-equal?
   (run-ns "(ns om2)\n(require [prologos::data::option :refer [Option none some map unwrap-or]])\n(eval (unwrap-or Nat zero (map Nat Nat (fn (x : Nat) (suc x)) (none Nat))))")
   '("0N : Nat")))


(test-case "option/flat-map"
  ;; Flat-map some -> some
  (check-equal?
   (run-ns "(ns ofm1)\n(require [prologos::data::option :refer [Option none some flat-map unwrap-or]])\n(eval (unwrap-or Nat zero (flat-map Nat Nat (fn (x : Nat) (some Nat (suc x))) (some Nat (suc zero)))))")
   '("2N : Nat"))
  ;; Flat-map none
  (check-equal?
   (run-ns "(ns ofm2)\n(require [prologos::data::option :refer [Option none some flat-map unwrap-or]])\n(eval (unwrap-or Nat zero (flat-map Nat Nat (fn (x : Nat) (some Nat (suc x))) (none Nat))))")
   '("0N : Nat")))


(test-case "option/unwrap-or"
  (check-equal?
   (run-ns "(ns ou1)\n(require [prologos::data::option :refer [Option none some unwrap-or]])\n(eval (unwrap-or Nat (suc (suc zero)) (some Nat zero)))")
   '("0N : Nat"))
  (check-equal?
   (run-ns "(ns ou2)\n(require [prologos::data::option :refer [Option none some unwrap-or]])\n(eval (unwrap-or Nat (suc (suc zero)) (none Nat)))")
   '("2N : Nat")))


;; ========================================
;; prologos::data::result — Module Loading
;; ========================================

(test-case "load prologos::data::result"
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)])
    (install-module-loader!)
    (define mod (load-module 'prologos::data::result #f))
    (check-not-false (module-info? mod))
    (define exports (module-info-exports mod))
    (check-not-false (member 'Result exports) "exports Result")
    (check-not-false (member 'ok exports) "exports ok")
    (check-not-false (member 'err exports) "exports err")
    (check-not-false (member 'map exports) "exports map")
    (check-not-false (member 'map-err exports) "exports map-err")
    (check-not-false (member 'unwrap-or exports) "exports unwrap-or")))


;; ========================================
;; prologos::data::result — Constructors + Combinators
;; ========================================

(test-case "result/constructors"
  (check-equal?
   (run-ns "(ns rc1)\n(require [prologos::data::result :refer [Result ok err]])\n(check (ok Nat Bool zero) : (Result Nat Bool))")
   '("OK"))
  (check-equal?
   (run-ns "(ns rc2)\n(require [prologos::data::result :refer [Result ok err]])\n(check (err Nat Bool true) : (Result Nat Bool))")
   '("OK")))


(test-case "result/elimination"
  ;; Eliminate ok: extract value via match
  (check-equal?
   (run-ns "(ns re1)\n(require [prologos::data::result :refer [Result ok err]])\n(eval (the Nat (match (ok Nat Bool (suc zero)) (ok x -> (suc x)) (err e -> zero))))")
   '("2N : Nat"))
  ;; Eliminate err: handle error via match
  (check-equal?
   (run-ns "(ns re2)\n(require [prologos::data::result :refer [Result ok err]])\n(eval (the Nat (match (err Nat Bool true) (ok x -> (suc x)) (err e -> zero))))")
   '("0N : Nat")))


(test-case "result/map"
  ;; Auto-implicit order: A B E (first-occurrence in spec [A -> B] [Result A E] -> Result B E)
  (check-equal?
   (run-ns "(ns rm1)\n(require [prologos::data::result :refer [Result ok err map unwrap-or]])\n(eval (unwrap-or Nat Bool zero (map Nat Nat Bool (fn (x : Nat) (suc x)) (ok Nat Bool (suc zero)))))")
   '("2N : Nat"))
  (check-equal?
   (run-ns "(ns rm2)\n(require [prologos::data::result :refer [Result ok err map unwrap-or]])\n(eval (unwrap-or Nat Bool zero (map Nat Nat Bool (fn (x : Nat) (suc x)) (err Nat Bool false))))")
   '("0N : Nat")))


(test-case "result/unwrap-or"
  (check-equal?
   (run-ns "(ns ruo1)\n(require [prologos::data::result :refer [Result ok err unwrap-or]])\n(eval (unwrap-or Nat Bool (suc (suc zero)) (ok Nat Bool zero)))")
   '("0N : Nat"))
  (check-equal?
   (run-ns "(ns ruo2)\n(require [prologos::data::result :refer [Result ok err unwrap-or]])\n(eval (unwrap-or Nat Bool (suc (suc zero)) (err Nat Bool true)))")
   '("2N : Nat")))


;; ========================================
;; prologos::data::ordering — Module Loading + Tests
;; ========================================

(test-case "load prologos::data::ordering"
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)])
    (install-module-loader!)
    (define mod (load-module 'prologos::data::ordering #f))
    (check-not-false (module-info? mod))
    (define exports (module-info-exports mod))
    (check-not-false (member 'Ordering exports) "exports Ordering")
    (check-not-false (member 'lt-ord exports) "exports lt-ord")
    (check-not-false (member 'eq-ord exports) "exports eq-ord")
    (check-not-false (member 'gt-ord exports) "exports gt-ord")))


(test-case "ordering/constructors"
  (check-equal?
   (run-ns "(ns ord1)\n(require [prologos::data::ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(check lt-ord : Ordering)")
   '("OK"))
  (check-equal?
   (run-ns "(ns ord2)\n(require [prologos::data::ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(check eq-ord : Ordering)")
   '("OK"))
  (check-equal?
   (run-ns "(ns ord3)\n(require [prologos::data::ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(check gt-ord : Ordering)")
   '("OK")))


(test-case "ordering/elimination"
  ;; Each constructor selects the corresponding branch via match
  (check-equal?
   (run-ns "(ns oe1)\n(require [prologos::data::ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match lt-ord (lt-ord -> zero) (eq-ord -> (suc zero)) (gt-ord -> (suc (suc zero))))))")
   '("0N : Nat"))
  (check-equal?
   (run-ns "(ns oe2)\n(require [prologos::data::ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match eq-ord (lt-ord -> zero) (eq-ord -> (suc zero)) (gt-ord -> (suc (suc zero))))))")
   '("1N : Nat"))
  (check-equal?
   (run-ns "(ns oe3)\n(require [prologos::data::ordering :refer [Ordering lt-ord eq-ord gt-ord]])\n(eval (the Nat (match gt-ord (lt-ord -> zero) (eq-ord -> (suc zero)) (gt-ord -> (suc (suc zero))))))")
   '("2N : Nat")))


;; ========================================
;; data keyword — Inline ADT definition
;; ========================================

(test-case "data/inline-enum"
  ;; Define and use an ADT inline (not from library)
  ;; data generates def forms, so we get "defined." messages
  (define result1
    (run-ns "(ns di1)\n(data (MyBool) (my-true) (my-false))\n(check my-true : MyBool)"))
  (check-equal? (last result1) "OK")
  ;; Eliminate via structural match
  (define result2
    (run-ns "(ns di2)\n(data (MyBool) (my-true) (my-false))\n(eval (the Nat (match my-true (my-true -> zero) (my-false -> (suc zero)))))"))
  (check-equal? (last result2) "0N : Nat")
  (define result3
    (run-ns "(ns di3)\n(data (MyBool) (my-true) (my-false))\n(eval (the Nat (match my-false (my-true -> zero) (my-false -> (suc zero)))))"))
  (check-equal? (last result3) "1N : Nat"))


(test-case "data/inline-parameterized"
  ;; Parameterized ADT
  (define result1
    (run-ns "(ns dp1)\n(data (Maybe (A : (Type 0))) (nothing) (just A))\n(check (nothing Nat) : (Maybe Nat))"))
  (check-equal? (last result1) "OK")
  (define result2
    (run-ns "(ns dp2)\n(data (Maybe (A : (Type 0))) (nothing) (just A))\n(check (just Nat zero) : (Maybe Nat))"))
  (check-equal? (last result2) "OK")
  ;; Eliminate via structural match
  (define result3
    (run-ns "(ns dp3)\n(data (Maybe (A : (Type 0))) (nothing) (just A))\n(eval (the Nat (match (just Nat (suc zero)) (nothing -> zero) (just x -> (suc x)))))"))
  (check-equal? (last result3) "2N : Nat"))
