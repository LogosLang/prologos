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

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
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
  (check-equal? (integer->nat 0) (expr-zero))
  (check-equal? (integer->nat 1) (expr-suc (expr-zero)))
  (check-equal? (integer->nat 3) (expr-suc (expr-suc (expr-suc (expr-zero))))))

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
     (eval (add1 (inc (inc zero))))")
   "3 : Nat"))

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
     (eval (sub1 (inc (inc (inc zero)))))")
   "2 : Nat"))

(test-case "foreign/multi-arg-plus"
  ;; Import Racket's + as a 2-arg function: Nat -> Nat -> Nat
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (+ : Nat -> Nat -> Nat))
     (eval (+ (inc (inc zero)) (inc (inc (inc zero)))))")
   "5 : Nat"))

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
     (eval (zero? (inc (inc zero))))")
   "false : Bool"))

(test-case "foreign/multiple-decls"
  ;; Multiple declarations in one foreign block
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (add1 : Nat -> Nat) (sub1 : Nat -> Nat))
     (eval (sub1 (add1 (inc (inc zero)))))")
   "2 : Nat"))

(test-case "foreign/partial-application"
  ;; Partially apply a 2-arg foreign fn, then apply the rest
  (define result
    (run-ns-last
     "(foreign racket \"racket/base\" (+ : Nat -> Nat -> Nat))
      (def add2 : (-> Nat Nat) (+ (inc (inc zero))))
      (eval (add2 (inc (inc (inc zero)))))"))
  (check-contains result "5 : Nat"))

(test-case "foreign/used-in-def"
  ;; Foreign fn used in a regular def body
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (add1 : Nat -> Nat))
     (def three : Nat (add1 (inc (inc zero))))
     (eval three)")
   "3 : Nat"))

(test-case "foreign/compose-with-native"
  ;; Compose foreign add1 with native inc
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (add1 : Nat -> Nat))
     (eval (add1 (inc (add1 zero))))")
   "3 : Nat"))

;; ========================================
;; Symbol-level :as alias tests
;; ========================================

(test-case "foreign/symbol-alias-eval"
  ;; Import add1 as increment, eval with alias name
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (add1 :as increment : Nat -> Nat))
     (eval (increment (inc (inc zero))))")
   "3 : Nat"))

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
     (eval (rkt/add1 (inc (inc zero))))")
   "3 : Nat"))

(test-case "foreign/module-alias-multiple"
  ;; Multiple declarations with module alias, compose them
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" :as rkt (add1 : Nat -> Nat) (sub1 : Nat -> Nat))
     (eval (rkt/sub1 (rkt/add1 (inc (inc zero)))))")
   "2 : Nat"))

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
     (eval (rkt/increment (inc (inc zero))))")
   "3 : Nat"))

(test-case "foreign/combined-mixed"
  ;; Module alias with one symbol aliased, one not
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" :as rkt (add1 :as increment : Nat -> Nat) (sub1 : Nat -> Nat))
     (eval (rkt/increment (rkt/sub1 (inc (inc (inc zero))))))")
   "3 : Nat"))

;; ========================================
;; Backward compatibility
;; ========================================

(test-case "foreign/no-alias-unchanged"
  ;; Original syntax without any alias still works
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (add1 : Nat -> Nat))
     (eval (add1 (inc zero)))")
   "2 : Nat"))

;; ========================================
;; Uncurried type syntax tests
;; ========================================

(test-case "foreign/uncurried-two-args"
  ;; Nat Nat -> Nat is equivalent to Nat -> Nat -> Nat
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (+ : Nat Nat -> Nat))
     (eval (+ (inc (inc zero)) (inc (inc (inc zero)))))")
   "5 : Nat"))

(test-case "foreign/uncurried-three-args"
  ;; Nat Nat Nat -> Nat uncurries to Nat -> Nat -> Nat -> Nat
  ;; Use a Racket fn that takes 3 args (+ handles variable arity)
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (+ : Nat Nat Nat -> Nat))
     (eval (+ (inc zero) (inc (inc zero)) (inc (inc (inc zero)))))")
   "6 : Nat"))

(test-case "foreign/uncurried-partial-application"
  ;; Uncurried Nat Nat -> Nat should allow partial application
  (define result
    (run-ns-last
     "(foreign racket \"racket/base\" (+ : Nat Nat -> Nat))
      (def add2 : (-> Nat Nat) (+ (inc (inc zero))))
      (eval (add2 (inc (inc (inc zero)))))"))
  (check-contains result "5 : Nat"))

(test-case "foreign/uncurried-with-alias"
  ;; Uncurried syntax works with :as alias
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (+ :as plus : Nat Nat -> Nat))
     (eval (plus (inc zero) (inc (inc zero))))")
   "3 : Nat"))

(test-case "foreign/uncurried-with-module-alias"
  ;; Uncurried syntax works with module-level :as alias
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" :as math (+ : Nat Nat -> Nat))
     (eval (math/+ (inc zero) (inc (inc zero))))")
   "3 : Nat"))

(test-case "foreign/uncurried-bool-return"
  ;; Nat Nat -> Bool
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (= : Nat Nat -> Bool))
     (eval (= (inc (inc zero)) (inc (inc zero))))")
   "true : Bool"))

(test-case "foreign/curried-still-works"
  ;; Existing curried syntax unchanged
  (check-contains
   (run-ns-last
    "(foreign racket \"racket/base\" (+ : Nat -> Nat -> Nat))
     (eval (+ (inc (inc zero)) (inc (inc (inc zero)))))")
   "5 : Nat"))

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
