#lang racket/base

;;;
;;; Tests for FFI lambda passing — Prologos lambdas crossing the Racket FFI
;;; boundary as live closures.
;;;
;;; See: docs/tracking/2026-04-28_FFI_LAMBDA_PASSING.md
;;;
;;; The marshalling layer recognises Pi (function) types in argument
;;; positions and wraps the incoming Prologos value as a Racket procedure
;;; that bridges Racket-side calls back into the Prologos reducer.
;;;

(require rackunit
         racket/list
         racket/string
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

(define (run-ns-last s) (last (run-ns s)))

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))

;; ========================================
;; Unit tests: parse-foreign-type recognises function-type parameters
;; ========================================

(test-case "callback/parse-fn-arg-type"
  ;; (Nat -> Nat) -> Nat -> Nat
  ;;   parses as Pi (Pi Nat Nat) (Pi Nat Nat), so parsed-type's first arg
  ;;   should be (cons 'fn ((Nat) . Nat)).
  (define inner (expr-Pi 'w (expr-Nat) (expr-Nat)))
  (define ty (expr-Pi 'w inner (expr-Pi 'w (expr-Nat) (expr-Nat))))
  (define parsed (parse-foreign-type ty))
  (check-equal? (length (car parsed)) 2)
  (check-equal? (car (car parsed)) (cons 'fn (cons (list 'Nat) 'Nat))
                "first arg should be tagged 'fn with inner ((Nat) . Nat)")
  (check-equal? (cadr (car parsed)) 'Nat)
  (check-equal? (cdr parsed) 'Nat))

(test-case "callback/parse-bare-fn-type-passes-through-as-base"
  ;; A bare top-level Nat -> Nat is not a "function-typed parameter" —
  ;; parse-foreign-type already strips the outer Pi into (arg . ret).
  (define ty (expr-Pi 'w (expr-Nat) (expr-Nat)))
  (define parsed (parse-foreign-type ty))
  (check-equal? (car parsed) '(Nat))
  (check-equal? (cdr parsed) 'Nat))

(test-case "callback/parse-nested-fn-type"
  ;; ((Nat -> Nat) -> Nat) -> Nat
  ;;   The outer arg is itself a function type whose domain is Nat -> Nat.
  (define inner-inner (expr-Pi 'w (expr-Nat) (expr-Nat))) ;; Nat -> Nat
  (define inner (expr-Pi 'w inner-inner (expr-Nat)))      ;; (Nat -> Nat) -> Nat
  (define ty (expr-Pi 'w inner (expr-Nat)))               ;; ((Nat -> Nat) -> Nat) -> Nat
  (define parsed (parse-foreign-type ty))
  ;; First arg is (cons 'fn (((fn (Nat) . Nat)) . Nat))
  (define a0 (car (car parsed)))
  (check-equal? (car a0) 'fn)
  (define inner-parsed (cdr a0))
  (check-equal? (length (car inner-parsed)) 1)
  (check-equal? (car (car inner-parsed)) (cons 'fn (cons (list 'Nat) 'Nat)))
  (check-equal? (cdr inner-parsed) 'Nat))

;; ========================================
;; Unit tests: marshal-prologos->racket wraps a Prologos lambda
;; ========================================

(test-case "callback/wraps-as-procedure"
  ;; (fn [x : Nat] x) marshalled with spec '(fn (Nat) . Nat) should yield
  ;; a Racket procedure of arity 1 that returns its arg unchanged.
  (define id-lam (expr-lam 'w (expr-Nat) (expr-bvar 0)))
  (define wrapped (marshal-prologos->racket
                   (cons 'fn (cons (list 'Nat) 'Nat))
                   id-lam))
  (check-true (procedure? wrapped))
  (check-equal? (wrapped 0) 0)
  (check-equal? (wrapped 5) 5)
  (check-equal? (wrapped 42) 42))

(test-case "callback/wraps-arity-checked"
  ;; Wrapper should error if called with wrong number of args.
  (define id-lam (expr-lam 'w (expr-Nat) (expr-bvar 0)))
  (define wrapped (marshal-prologos->racket
                   (cons 'fn (cons (list 'Nat) 'Nat))
                   id-lam))
  (check-exn exn:fail?
             (lambda () (wrapped 1 2))
             "calling with 2 args when arity is 1 should raise"))

(test-case "callback/wraps-bool-returning"
  ;; (fn [x : Nat] true) — a Nat -> Bool callback
  (define const-true (expr-lam 'w (expr-Nat) (expr-true)))
  (define wrapped (marshal-prologos->racket
                   (cons 'fn (cons (list 'Nat) 'Bool))
                   const-true))
  (check-equal? (wrapped 0) #t)
  (check-equal? (wrapped 99) #t))

(test-case "callback/marshal-out-fn-type-errors-clearly"
  ;; Returning a Racket procedure to Prologos as a function value is reserved.
  ;; The marshaller should error with a clear message rather than silently
  ;; producing nonsense.
  (check-exn exn:fail?
             (lambda ()
               (marshal-racket->prologos
                (cons 'fn (cons (list 'Nat) 'Nat))
                add1))))

;; ========================================
;; Integration tests: end-to-end via the foreign declaration
;; ========================================
;; A small Racket helper module ships in lib/examples/lambda-ffi-helper.rkt
;; with `apply-twice : (Nat -> Nat) -> Nat -> Nat` and other shapes.

(test-case "callback/apply-twice-nat-nat"
  ;; (apply-twice f x) = (f (f x)). With f = (fn [x] (suc x)) and x = 3,
  ;; result is 5.
  (check-contains
   (run-ns-last
    "(foreign racket \"lib/examples/lambda-ffi-helper.rkt\" :as helper
        (apply-twice : [Nat -> Nat] Nat -> Nat))
     (eval (helper/apply-twice (fn [x : Nat] (suc x))
                               (suc (suc (suc zero)))))")
   "5N : Nat"))

(test-case "callback/apply-twice-with-named-lambda"
  ;; def the Prologos lambda first, then pass it across the FFI.
  (check-contains
   (run-ns-last
    "(foreign racket \"lib/examples/lambda-ffi-helper.rkt\" :as helper
        (apply-twice : [Nat -> Nat] Nat -> Nat))
     (def my-inc : (-> Nat Nat) (fn [x : Nat] (suc x)))
     (eval (helper/apply-twice my-inc (suc zero)))")
   "3N : Nat"))

(test-case "callback/compose-via-ffi"
  ;; Compose a Prologos function with itself THREE times by chaining apply-twice
  ;; with a single inner application.
  (check-contains
   (run-ns-last
    "(foreign racket \"lib/examples/lambda-ffi-helper.rkt\" :as helper
        (apply-twice : [Nat -> Nat] Nat -> Nat))
     (def my-inc : (-> Nat Nat) (fn [x : Nat] (suc x)))
     (eval (helper/apply-twice my-inc
                               (helper/apply-twice my-inc zero)))")
   "4N : Nat"))