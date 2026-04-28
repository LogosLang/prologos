#lang racket/base

;;;
;;; Tests for Foreign Racket Imports
;;; Tests the `foreign racket "module" (name : type)` directive.
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         racket/match
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../multi-dispatch.rkt"
         "../foreign.rkt")

;; ========================================
;; Helpers
;; ========================================

(define (run-ns s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string s)))

(define (run-ns-last s)
  (last (run-ns s)))

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))

;; ========================================
;; Unit tests: marshalling layer
;; ========================================

(test-case "foreign/marshal-nat->integer"
  (check-equal? (nat->integer (expr-zero)) 0)
  (check-equal? (nat->integer (expr-suc (expr-zero))) 1)
  (check-equal? (nat->integer (expr-suc (expr-suc (expr-suc (expr-zero))))) 3))

(test-case "foreign/marshal-integer->nat"
  (check-equal? (integer->nat 0) (expr-nat-val 0))
  (check-equal? (integer->nat 1) (expr-nat-val 1))
  (check-equal? (integer->nat 3) (expr-nat-val 3)))

(test-case "foreign/marshal-roundtrip-nat"
  ;; integer->nat->integer roundtrip
  (for ([n (in-range 0 10)])
    (check-equal? (nat->integer (integer->nat n)) n)))

(test-case "foreign/marshal-bool->boolean"
  (check-equal? (bool->boolean (expr-true)) #t)
  (check-equal? (bool->boolean (expr-false)) #f))

(test-case "foreign/marshal-boolean->prologos"
  (check-equal? (marshal-racket->prologos 'Bool #t) (expr-true))
  (check-equal? (marshal-racket->prologos 'Bool #f) (expr-false)))

(test-case "foreign/parse-foreign-type-nat->nat"
  ;; (-> Nat Nat) → ((Nat) . Nat)
  (define ty (expr-Pi 'w (expr-Nat) (expr-Nat)))
  (define parsed (parse-foreign-type ty))
  (check-equal? (car parsed) '(Nat))
  (check-equal? (cdr parsed) 'Nat))

(test-case "foreign/parse-foreign-type-nat->nat->bool"
  ;; (-> Nat (-> Nat Bool)) → ((Nat Nat) . Bool)
  (define ty (expr-Pi 'w (expr-Nat) (expr-Pi 'w (expr-Nat) (expr-Bool))))
  (define parsed (parse-foreign-type ty))
  (check-equal? (car parsed) '(Nat Nat))
  (check-equal? (cdr parsed) 'Bool))

(test-case "foreign/parse-foreign-type-bare"
  ;; Nat (no arrows) → (() . Nat)
  (define parsed (parse-foreign-type (expr-Nat)))
  (check-equal? (car parsed) '())
  (check-equal? (cdr parsed) 'Nat))

;; ========================================
;; Integration tests: foreign racket directive
;; ========================================

(test-case "foreign/add1-eval"
  ;; Import Racket's add1 (exact integer → exact integer, maps to Nat → Nat)
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (add1 : Nat -> Nat))
     (eval (add1 (suc (suc zero))))")
   "3N : Nat"))

(test-case "foreign/add1-type"
  ;; add1 should have type Nat -> Nat
  (define result
    (run-ns-last
     "(foreign racket \"racket/base\" (add1 : Nat -> Nat))
      (infer add1)"))
  (check-contains result "Nat")
  (check-contains result "->"))

(test-case "foreign/add1-check"
  ;; (add1 zero) should type-check as Nat → returns "OK"
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (add1 : Nat -> Nat))
     (check (add1 zero) : Nat)")
   "OK"))

(test-case "foreign/sub1-eval"
  ;; Import Racket's sub1
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (sub1 : Nat -> Nat))
     (eval (sub1 (suc (suc (suc zero)))))")
   "2N : Nat"))

(test-case "foreign/multi-arg-plus"
  ;; Import Racket's + as a 2-arg function: Nat -> Nat -> Nat
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (+ : Nat -> Nat -> Nat))
     (eval (+ (suc (suc zero)) (suc (suc (suc zero)))))")
   "5N : Nat"))

(test-case "foreign/zero?-true"
  ;; Import Racket's zero? : Nat -> Bool
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (zero? : Nat -> Bool))
     (eval (zero? zero))")
   "true : Bool"))

(test-case "foreign/zero?-false"
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (zero? : Nat -> Bool))
     (eval (zero? (suc (suc zero))))")
   "false : Bool"))

(test-case "foreign/multiple-decls"
  ;; Multiple declarations in one foreign block
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (add1 : Nat -> Nat) (sub1 : Nat -> Nat))
     (eval (sub1 (add1 (suc (suc zero)))))")
   "2N : Nat"))

(test-case "foreign/partial-application"
  ;; Partially apply a 2-arg foreign fn, then apply the rest
  (define result
    (run-ns-last
     "(foreign racket \"racket/base\" (+ : Nat -> Nat -> Nat))
      (def add2 : (-> Nat Nat) (+ (suc (suc zero))))
      (eval (add2 (suc (suc (suc zero)))))"))
  (check-contains result "5N : Nat"))

(test-case "foreign/used-in-def"
  ;; Foreign fn used in a regular def body
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (add1 : Nat -> Nat))
     (def three : Nat (add1 (suc (suc zero))))
     (eval three)")
   "3N : Nat"))

(test-case "foreign/compose-with-native"
  ;; Compose foreign add1 with native suc
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (add1 : Nat -> Nat))
     (eval (add1 (suc (add1 zero))))")
   "3N : Nat"))

;; ========================================
;; Symbol-level :as alias tests
;; ========================================

(test-case "foreign/symbol-alias-eval"
  ;; Import add1 as increment, eval with alias name
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (add1 :as increment : Nat -> Nat))
     (eval (increment (suc (suc zero))))")
   "3N : Nat"))

(test-case "foreign/symbol-alias-type"
  ;; Aliased name has correct type
  (define result
    (run-ns-last
     "(foreign racket \"racket/base\" (add1 :as increment : Nat -> Nat))
      (infer increment)"))
  (check-contains result "Nat")
  (check-contains result "->"))

(test-case "foreign/symbol-alias-original-hidden"
  ;; Original Racket name should NOT be available under its original name
  (check-contains
   (format "~a"
    (run-ns-last
     "(foreign racket \"racket/base\" (add1 :as increment : Nat -> Nat))
      (eval (add1 zero))"))
   "Unbound variable"))

(test-case "foreign/symbol-alias-bool"
  ;; Alias a Bool-returning function
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (zero? :as is-zero : Nat -> Bool))
     (eval (is-zero zero))")
   "true : Bool"))

;; ========================================
;; Module-level :as alias tests
;; ========================================

(test-case "foreign/module-alias-eval"
  ;; Module alias: rkt/add1
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" :as rkt (add1 : Nat -> Nat))
     (eval (rkt/add1 (suc (suc zero))))")
   "3N : Nat"))

(test-case "foreign/module-alias-multiple"
  ;; Multiple declarations with module alias, compose them
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" :as rkt (add1 : Nat -> Nat) (sub1 : Nat -> Nat))
     (eval (rkt/sub1 (rkt/add1 (suc (suc zero)))))")
   "2N : Nat"))

(test-case "foreign/module-alias-type"
  ;; Module-aliased name has correct type
  (define result
    (run-ns-last
     "(foreign racket \"racket/base\" :as rkt (add1 : Nat -> Nat))
      (infer rkt/add1)"))
  (check-contains result "Nat")
  (check-contains result "->"))

(test-case "foreign/module-alias-original-hidden"
  ;; Bare name should NOT be available when module alias is used
  (check-contains
   (format "~a"
    (run-ns-last
     "(foreign racket \"racket/base\" :as rkt (add1 : Nat -> Nat))
      (eval (add1 zero))"))
   "Unbound variable"))

;; ========================================
;; Combined (module + symbol) alias tests
;; ========================================

(test-case "foreign/combined-alias"
  ;; Module alias + symbol alias → rkt/increment
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" :as rkt (add1 :as increment : Nat -> Nat))
     (eval (rkt/increment (suc (suc zero))))")
   "3N : Nat"))

(test-case "foreign/combined-mixed"
  ;; Module alias with one symbol aliased, one not
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" :as rkt (add1 :as increment : Nat -> Nat) (sub1 : Nat -> Nat))
     (eval (rkt/increment (rkt/sub1 (suc (suc (suc zero))))))")
   "3N : Nat"))

;; ========================================
;; Backward compatibility
;; ========================================

(test-case "foreign/no-alias-unchanged"
  ;; Original syntax without any alias still works
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (add1 : Nat -> Nat))
     (eval (add1 (suc zero)))")
   "2N : Nat"))

;; ========================================
;; Uncurried type syntax tests
;; ========================================

(test-case "foreign/uncurried-two-args"
  ;; Nat Nat -> Nat is equivalent to Nat -> Nat -> Nat
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (+ : Nat Nat -> Nat))
     (eval (+ (suc (suc zero)) (suc (suc (suc zero)))))")
   "5N : Nat"))

(test-case "foreign/uncurried-three-args"
  ;; Nat Nat Nat -> Nat uncurries to Nat -> Nat -> Nat -> Nat
  ;; Use a Racket fn that takes 3 args (+ handles variable arity)
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (+ : Nat Nat Nat -> Nat))
     (eval (+ (suc zero) (suc (suc zero)) (suc (suc (suc zero)))))")
   "6N : Nat"))

(test-case "foreign/uncurried-partial-application"
  ;; Uncurried Nat Nat -> Nat should allow partial application
  (define result
    (run-ns-last
     "(foreign racket \"racket/base\" (+ : Nat Nat -> Nat))
      (def add2 : (-> Nat Nat) (+ (suc (suc zero))))
      (eval (add2 (suc (suc (suc zero)))))"))
  (check-contains result "5N : Nat"))

(test-case "foreign/uncurried-with-alias"
  ;; Uncurried syntax works with :as alias
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (+ :as plus : Nat Nat -> Nat))
     (eval (plus (suc zero) (suc (suc zero))))")
   "3N : Nat"))

(test-case "foreign/uncurried-with-module-alias"
  ;; Uncurried syntax works with module-level :as alias
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" :as math (+ : Nat Nat -> Nat))
     (eval (math/+ (suc zero) (suc (suc zero))))")
   "3N : Nat"))

(test-case "foreign/uncurried-bool-return"
  ;; Nat Nat -> Bool — use :as to avoid = keyword interception (= now desugars to eq-check)
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" :as rkt (= : Nat Nat -> Bool))
     (eval (rkt/= (suc (suc zero)) (suc (suc zero))))")
   "true : Bool"))

(test-case "foreign/curried-still-works"
  ;; Existing curried syntax unchanged
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (+ : Nat -> Nat -> Nat))
     (eval (+ (suc (suc zero)) (suc (suc (suc zero)))))")
   "5N : Nat"))

;; ========================================
;; Error cases
;; ========================================

(test-case "foreign/module-alias-no-decls"
  ;; Module alias with no declarations → error
  (check-exn
   exn:fail?
   (lambda ()
     (run-ns
      "(foreign racket \"racket/base\" :as rkt)"))))

;; ========================================
;; Integration tests: Int, Posit, and List FFI types
;; ========================================
;; These exercise marshal-prologos->racket / marshal-racket->prologos through
;; the full elaborator pipeline, complementing the pure unit tests in
;; test-foreign-marshal-ext.rkt. Tests that need `List` in scope use a `ns`
;; prefix to trigger prelude auto-import.

(define list-prelude "(ns t-foreign-list)\n")

(test-case "foreign/Int-add1-eval"
  ;; add1 imported as Int -> Int (Racket's add1 works on any exact integer).
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (add1 : Int -> Int))
     (eval (add1 (int 5)))")
   "6 : Int"))

(test-case "foreign/Int-plus-two-args"
  ;; Two-arg Int -> Int -> Int aliased to int+ to avoid clashing with the
  ;; macro-resolved `+` reduction rule on Int literals.
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (+ :as int-plus : Int -> Int -> Int))
     (eval (int-plus (int 3) (int 4)))")
   "7 : Int"))

(test-case "foreign/Int-negative"
  ;; Negative Int input/output round-trip through marshalling.
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (- :as int-sub : Int -> Int -> Int))
     (eval (int-sub (int 3) (int 10)))")
   "-7 : Int"))

(test-case "foreign/Int-bignum-roundtrip"
  ;; Racket bignum × bignum should preserve precision through marshalling.
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (* :as int-mul : Int -> Int -> Int))
     (eval (int-mul (int 1000000) (int 1000000)))")
   "1000000000000 : Int"))

(test-case "foreign/Posit8-add1"
  ;; Racket's add1 works on rationals (1 + bits-decoded-as-rational).
  ;; (posit8 64) is the value 1.0; add1 → 2.0; encoded back to bits.
  (define result
    (run-ns-last
     "(foreign racket \"racket/base\" (add1 :as p8-rat-inc : Posit8 -> Posit8))
      (check (p8-rat-inc (posit8 64)) <Posit8>)"))
  (check-contains result "OK"))

(test-case "foreign/Posit16-roundtrip-via-identity"
  ;; values: (posit16 16384) = 1.0 exact in posit16.
  ;; Use Racket's identity-style call: we go IR → rational → IR through marshal.
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (add1 :as p16-rat-inc : Posit16 -> Posit16))
     (check (p16-rat-inc (posit16 16384)) <Posit16>)")
   "OK"))

(test-case "foreign/Posit32-add"
  ;; Two-arg Racket + on rationals through Posit32 marshalling.
  ;; (posit32 1073741824) = 1.0 in posit32.
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (+ :as p32-rat-add : Posit32 -> Posit32 -> Posit32))
     (check (p32-rat-add (posit32 1073741824) (posit32 1073741824)) <Posit32>)")
   "OK"))

(test-case "foreign/Posit64-passes-through"
  ;; Type-check only: ensures Posit64 is accepted in foreign type positions
  ;; and the marshaller pair is built without error.
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (add1 :as p64-rat-inc : Posit64 -> Posit64))
     (infer p64-rat-inc)")
   "Posit64"))

(test-case "foreign/List-Int-length"
  ;; Pass a List of Ints to Racket's `length`, get back a Nat.
  (check-contains
   (run-ns-last
    (string-append list-prelude
     "(foreign racket \"racket/base\" (length :as rkt-length : (List Int) -> Nat))
      (eval (rkt-length (cons Int (int 1) (cons Int (int 2) (cons Int (int 3) (nil Int))))))"))
   "3N : Nat"))

(test-case "foreign/List-Int-empty"
  ;; Empty list of Ints should marshal as () and length should be 0.
  (check-contains
   (run-ns-last
    (string-append list-prelude
     "(foreign racket \"racket/base\" (length :as rkt-length : (List Int) -> Nat))
      (eval (rkt-length (nil Int)))"))
   "0N : Nat"))

(test-case "foreign/List-Nat-length"
  ;; Nat element marshalling inside a list.
  (check-contains
   (run-ns-last
    (string-append list-prelude
     "(foreign racket \"racket/base\" (length :as rkt-length : (List Nat) -> Nat))
      (eval (rkt-length (cons Nat zero (cons Nat (suc zero) (nil Nat)))))"))
   "2N : Nat"))

(test-case "foreign/List-Int-infer-type"
  ;; Type checks: foreign declaration with (List Int) in arg position
  ;; produces a function with that signature.
  (check-contains
   (run-ns-last
    (string-append list-prelude
     "(foreign racket \"racket/base\" (length :as rkt-length : (List Int) -> Nat))
      (infer rkt-length)"))
   "List"))

(test-case "foreign/List-Int-return-from-racket"
  ;; Racket's `list` returns a list — typed as (List Int).
  ;; (list 10 20 30) on the Racket side returns a 3-element list, which the
  ;; marshaller encodes back into a Prologos cons/nil chain.
  (check-contains
   (run-ns-last
    (string-append list-prelude
     "(foreign racket \"racket/base\" (list :as rkt-list-of-3 : Int -> Int -> Int -> (List Int)))
      (foreign racket \"racket/base\" (length :as rkt-length : (List Int) -> Nat))
      (eval (rkt-length (rkt-list-of-3 (int 10) (int 20) (int 30))))"))
   "3N : Nat"))

(test-case "foreign/List-Int-roundtrip-via-reverse"
  ;; Send a Prologos list to Racket's `reverse`, then count the result.
  (check-contains
   (run-ns-last
    (string-append list-prelude
     "(foreign racket \"racket/base\" (reverse :as rkt-reverse : (List Int) -> (List Int)))
      (foreign racket \"racket/base\" (length :as rkt-length : (List Int) -> Nat))
      (eval (rkt-length (rkt-reverse (cons Int (int 1) (cons Int (int 2) (cons Int (int 3) (nil Int)))))))"))
   "3N : Nat"))
