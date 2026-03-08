#lang racket/base

;;;
;;; Tests for Unified Pattern Matching in match Arms
;;;
;;; Verifies:
;;; - Rich patterns in match: nested ctor, numeric, head-tail, wildcard
;;; - Constructor disambiguation via registry (zero as ctor, not var)
;;; - Sexp-mode integration
;;; - WS-mode integration
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         racket/port
         racket/file
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
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../namespace.rkt"
         "../trait-resolution.rkt"
         "../reader.rkt"
         "../multi-dispatch.rkt")

;; ========================================
;; Shared Fixture (prelude loaded once)
;; ========================================

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-bundle-reg)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    (process-string "(ns test-unified-match)")
    (values (current-global-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-bundle-registry))))

;; Run sexp code using shared environment
(define (run s)
  (parameterize ([current-global-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-bundle-registry shared-bundle-reg])
    (process-string s)))

(define (run-last s) (last (run s)))

;; Run WS code via temp file using shared environment
(define (run-ws s)
  (define tmp (make-temporary-file "prologos-test-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (out) (display s out)))
  (define result
    (parameterize ([current-global-env shared-global-env]
                   [current-ns-context shared-ns-context]
                   [current-module-registry shared-module-reg]
                   [current-lib-paths (list lib-dir)]
                   [current-mult-meta-store (make-hasheq)]
                   [current-preparse-registry (current-preparse-registry)]
                   [current-trait-registry shared-trait-reg]
                   [current-impl-registry shared-impl-reg]
                   [current-param-impl-registry shared-param-impl-reg]
                   [current-bundle-registry shared-bundle-reg])
      (process-file tmp)))
  (delete-file tmp)
  result)

(define (run-ws-last s) (last (run-ws s)))

;; ========================================
;; A. Sexp-mode: constructor disambiguation in match
;; ========================================

(test-case "match/sexp-ctor-zero"
  ;; zero recognized as constructor, not variable
  (check-equal?
   (run-last
    "(eval (the Bool (match zero (zero -> true) (suc _ -> false))))")
   "true : Bool")
  (check-equal?
   (run-last
    "(eval (the Bool (match (suc zero) (zero -> true) (suc _ -> false))))")
   "false : Bool"))

(test-case "match/sexp-nested-ctor"
  ;; suc zero = nested constructor pattern
  (check-equal?
   (run-last
    "(eval (the Bool (match (suc zero) (suc zero -> true) (_ -> false))))")
   "true : Bool")
  (check-equal?
   (run-last
    "(eval (the Bool (match (suc (suc zero)) (suc zero -> true) (_ -> false))))")
   "false : Bool"))

(test-case "match/sexp-deeply-nested"
  ;; (suc (suc k)) extracts k
  (check-equal?
   (run-last
    "(eval (the Nat (match (suc (suc (suc zero))) ((suc (suc k)) -> k) (n -> n))))")
   "1N : Nat"))

(test-case "match/sexp-numeric-literal"
  ;; 0N, 1N as patterns
  (check-equal?
   (run-last
    "(eval (the Bool (match (suc zero) (0N -> false) (1N -> true) (_ -> false))))")
   "true : Bool")
  (check-equal?
   (run-last
    "(eval (the Bool (match zero (0N -> true) (_ -> false))))")
   "true : Bool"))

(test-case "match/sexp-head-tail"
  ;; (a $pipe rest) head-tail pattern
  (check-equal?
   (run-last
    (string-append
     "(def xs : (List Nat) (cons (suc zero) (cons (suc (suc zero)) nil)))\n"
     "(eval (the Nat (match xs ((a $pipe rest) -> a) (nil -> zero))))"))
   "1N : Nat"))

(test-case "match/sexp-wildcard"
  ;; _ matches anything
  (check-equal?
   (run-last
    "(eval (the Nat (match (suc (suc zero)) (_ -> zero))))")
   "0N : Nat"))

(test-case "match/sexp-variable-binding"
  ;; x as variable binding in default arm
  (check-equal?
   (run-last
    "(eval (the Nat (match zero (suc n -> n) (x -> x))))")
   "0N : Nat"))

(test-case "match/sexp-bool-match"
  ;; true/false constructor disambiguation
  (check-equal?
   (run-last
    "(eval (the Nat (match true (true -> (suc zero)) (false -> zero))))")
   "1N : Nat"))

(test-case "match/sexp-option-match"
  ;; some/none constructor patterns
  (check-equal?
   (run-last
    "(eval (the Nat (match (some (suc zero)) ((some x) -> x) (none -> zero))))")
   "1N : Nat")
  (check-equal?
   (run-last
    "(eval (the Nat (match (the (Option Nat) none) ((some x) -> x) (none -> zero))))")
   "0N : Nat"))

;; ========================================
;; B. WS-mode: rich patterns in match
;; ========================================

(test-case "match/ws-ctor-zero"
  ;; WS mode: zero as constructor in match arm
  (check-equal?
   (run-ws-last
    "defn test-zero [x : Nat] : Bool\n  match x\n    | zero -> true\n    | suc _ -> false\neval [test-zero zero]")
   "true : Bool"))

(test-case "match/ws-nested-ctor"
  ;; WS mode: suc zero recognized as nested ctor pattern
  (check-equal?
   (run-ws-last
    "defn is-one [x : Nat] : Bool\n  match x\n    | suc zero -> true\n    | _ -> false\neval [is-one 1N]")
   "true : Bool")
  (check-equal?
   (run-ws-last
    "defn is-one2 [x : Nat] : Bool\n  match x\n    | suc zero -> true\n    | _ -> false\neval [is-one2 2N]")
   "false : Bool"))

(test-case "match/ws-deeply-nested"
  ;; WS mode: suc [suc k] extracts k
  (check-equal?
   (run-ws-last
    "defn pred2 [x : Nat] : Nat\n  match x\n    | suc [suc k] -> k\n    | _ -> 0N\neval [pred2 3N]")
   "1N : Nat"))

(test-case "match/ws-head-tail"
  ;; WS mode: [x | rest] head-tail pattern
  (check-equal?
   (run-ws-last
    "defn list-head [xs : List Nat] : Nat\n  match xs\n    | [x | rest] -> x\n    | nil -> 0N\neval [list-head '[1N 2N 3N]]")
   "1N : Nat"))

(test-case "match/ws-numeric-literal"
  ;; WS mode: numeric literal patterns
  (check-equal?
   (run-ws-last
    "defn test-lit [x : Nat] : Bool\n  match x\n    | 0N -> true\n    | 1N -> false\n    | _ -> false\neval [test-lit 0N]")
   "true : Bool"))

(test-case "match/ws-option"
  ;; WS mode: option match with some/none
  (check-equal?
   (run-ws-last
    "defn unwrap-or-zero [x : Option Nat] : Nat\n  match x\n    | some v -> v\n    | none -> 0N\neval [unwrap-or-zero [some 42N]]")
   "42N : Nat"))
