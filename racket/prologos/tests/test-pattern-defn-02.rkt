#lang racket/base

;;;
;;; Tests for Pattern-Based defn Clauses + Head-Tail List Patterns
;;; Part 2: WS-mode + mixed arity + validation + params syntax
;;;
;;; Verifies:
;;; - WS-mode integration for pattern defn
;;; - Mixed arity + pattern dispatch
;;; - Validation errors for conflicting clause kinds
;;; - defn f [params] | arms syntax (params+patterns)
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
                 [current-module-definitions-content (hasheq)]
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
    (process-string "(ns test-pattern-defn)")
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
;; D. WS-mode integration tests
;; ========================================

(test-case "pattern/ws-is-zero"
  (check-equal?
   (run-ws-last "defn is-zero-ws\n  | [zero] -> true\n  | [n] -> false\neval [is-zero-ws zero]")
   "true : Bool")
  (check-equal?
   (run-ws-last "defn is-zero-ws2\n  | [zero] -> true\n  | [n] -> false\neval [is-zero-ws2 1N]")
   "false : Bool"))

(test-case "pattern/ws-add"
  ;; Recursive pattern function needs spec for pre-registration type
  (check-equal?
   (run-ws-last
    "spec addp-ws Nat -> Nat -> Nat\ndefn addp-ws\n  | [zero n] -> n\n  | [[suc m] n] -> suc [addp-ws m n]\neval [addp-ws 2N 3N]")
   "5N : Nat"))

(test-case "pattern/ws-bool-not"
  (check-equal?
   (run-ws-last
    "defn notp-ws\n  | [true] -> false\n  | [false] -> true\neval [notp-ws true]")
   "false : Bool"))

(test-case "pattern/ws-head-tail-match"
  ;; Head-tail in WS match expression — wrapped in defn because
  ;; standalone match needs type context (infer has no expr-reduce case)
  (check-equal?
   (run-ws-last
    (string-append
     "defn list-head [xs : List Nat] : Nat\n"
     "  match xs\n"
     "    | [a | rest] -> a\n"
     "    | nil -> 0N\n"
     "eval [list-head '[1N 2N 3N]]\n"))
   "1N : Nat"))

(test-case "pattern/ws-variable-catch-all"
  ;; All-variable pattern requires a spec for type resolution
  (check-equal?
   (run-ws-last
    "spec idf Nat -> Nat\ndefn idf\n  | [n] -> n\neval [idf 42N]")
   "42N : Nat"))

(test-case "pattern/ws-wildcard"
  (check-equal?
   (run-ws-last
    "defn const-zero\n  | [_] -> zero\neval [const-zero 5N]")
   "0N : Nat"))

;; ========================================
;; E. Mixed arity + pattern dispatch
;; ========================================

(test-case "pattern/mixed-arity-and-pattern"
  ;; Arity 1: pattern clauses (is-zero-like)
  ;; Arity 2: arity clause (addition)
  (check-equal?
   (run-last
    (string-append
     "(defn mf"
     " ($pipe (zero) -> true)"
     " ($pipe (n) -> false)"
     " ($pipe [x <Nat> y <Nat>] <Nat> (suc x)))\n"
     "(eval (mf zero))"))
   "true : Bool")
  (check-equal?
   (run-last
    (string-append
     "(defn mf2"
     " ($pipe (zero) -> true)"
     " ($pipe (n) -> false)"
     " ($pipe [x <Nat> y <Nat>] <Nat> (suc x)))\n"
     "(eval (mf2 (suc zero) zero))"))
   "2N : Nat"))

;; ========================================
;; F. Validation errors
;; ========================================

(test-case "pattern/error-mixed-kinds-same-arity"
  ;; Same arity group with both arity and pattern clauses -> error
  (define results
    (run
     (string-append
      "(defn badf"
      " ($pipe (zero) -> true)"        ;; pattern clause, arity 1
      " ($pipe [x <Nat>] <Bool> false)" ;; arity clause, arity 1
      ")")))
  (check-true (prologos-error? (car results))))

;; ========================================
;; G. defn f [params] | arms syntax (params+patterns)
;; ========================================

(test-case "params+arms/sexp-arity1-pred"
  ;; Sexp mode: defn f (params) ($pipe pat -> body) ...
  (check-equal?
   (run-last
    (string-append
     "(defn pred-pp (n)"
     " ($pipe suc zero -> zero)"
     " ($pipe suc (suc k) -> (suc k))"
     " ($pipe zero -> zero))\n"
     "(eval (pred-pp (suc (suc (suc zero)))))"))
   "2N : Nat"))

(test-case "params+arms/sexp-arity2-add"
  ;; Sexp mode: arity 2, recursive
  (check-equal?
   (run-last
    (string-append
     "(spec add-pp Nat -> Nat -> Nat)\n"
     "(defn add-pp (m n)"
     " ($pipe zero n -> n)"
     " ($pipe (suc m2) n2 -> (suc (add-pp m2 n2))))\n"
     "(eval (add-pp (suc (suc zero)) (suc zero)))"))
   "3N : Nat"))

(test-case "params+arms/ws-arity1-pred"
  ;; WS mode: defn pred [n] | suc zero -> zero | ...
  (check-equal?
   (run-ws-last
    "defn pred-ws [n]\n  | suc zero -> zero\n  | suc [suc k] -> suc k\n  | zero -> zero\neval [pred-ws 3N]")
   "2N : Nat")
  (check-equal?
   (run-ws-last
    "defn pred-ws2 [n]\n  | suc zero -> zero\n  | suc [suc k] -> suc k\n  | zero -> zero\neval [pred-ws2 1N]")
   "0N : Nat")
  (check-equal?
   (run-ws-last
    "defn pred-ws3 [n]\n  | suc zero -> zero\n  | suc [suc k] -> suc k\n  | zero -> zero\neval [pred-ws3 0N]")
   "0N : Nat"))

(test-case "params+arms/ws-arity2-add"
  ;; WS mode: defn add [m n] | zero n -> n | [suc m'] n' -> suc [add m' n']
  (check-equal?
   (run-ws-last
    "spec add-ws2 Nat -> Nat -> Nat\ndefn add-ws2 [m n]\n  | zero n -> n\n  | [suc m'] n' -> suc [add-ws2 m' n']\neval [add-ws2 2N 3N]")
   "5N : Nat"))

(test-case "params+arms/ws-bool-not"
  ;; WS mode: defn not [b] | true -> false | false -> true
  (check-equal?
   (run-ws-last
    "defn not-ws [b]\n  | true -> false\n  | false -> true\neval [not-ws true]")
   "false : Bool")
  (check-equal?
   (run-ws-last
    "defn not-ws2 [b]\n  | true -> false\n  | false -> true\neval [not-ws2 false]")
   "true : Bool"))

(test-case "params+arms/ws-head-tail"
  ;; WS mode: defn with head-tail pattern and typed params
  (check-true
   (let ([result
          (run-last
           (string-append
            "(spec safe-head (List Nat) -> (Option Nat))\n"
            "(defn safe-head (xs)"
            " ($pipe (x $pipe rest) -> (some x))"
            " ($pipe nil -> none))\n"
            "(def mylist : (List Nat) (cons (suc zero) (cons (suc (suc zero)) nil)))\n"
            "(eval (safe-head mylist))"))])
     (and (string-contains? result "some")
          (string-contains? result "1N"))))
  ;; Test none case
  (check-true
   (let ([result
          (run-last
           (string-append
            "(spec safe-head2 (List Nat) -> (Option Nat))\n"
            "(defn safe-head2 (xs)"
            " ($pipe (x $pipe rest) -> (some x))"
            " ($pipe nil -> none))\n"
            "(eval (safe-head2 (the (List Nat) nil)))"))])
     (or (equal? result "none : Option Nat")
         (string-contains? result "none")))))
