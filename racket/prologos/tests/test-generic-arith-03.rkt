#lang racket/base

;;;
;;; Tests for Generic Arithmetic Operators: >, >=, mod
;;; Verifies: parser keywords gt/ge/mod, type checking,
;;;           reduction for Int, Rat, Nat.
;;; Also: WS-mode tests and relational context (is-goals, guards).
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../reader.rkt")

;; ========================================
;; Helpers
;; ========================================

;; sexp mode (no prelude)
(define (run s)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
    (car (process-string s))))

;; Shared fixture for WS-mode tests (prelude loaded once)
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
    (process-string "(ns test-generic-arith-03)")
    (values (current-global-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-bundle-registry))))

(define (run-ws s)
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
    (process-string-ws s)))

(define (run-ws-last s) (last (run-ws s)))

;; ========================================
;; A. Int: gt, ge, mod (sexp mode)
;; ========================================

(test-case "generic-arith/int-gt-true"
  (check-true (string-contains? (run "(eval (gt 4 3))") "true")))

(test-case "generic-arith/int-gt-false"
  (check-true (string-contains? (run "(eval (gt 3 4))") "false")))

(test-case "generic-arith/int-gt-equal"
  (check-true (string-contains? (run "(eval (gt 3 3))") "false")))

(test-case "generic-arith/int-ge-true"
  (check-true (string-contains? (run "(eval (ge 4 3))") "true")))

(test-case "generic-arith/int-ge-equal"
  (check-true (string-contains? (run "(eval (ge 3 3))") "true")))

(test-case "generic-arith/int-ge-false"
  (check-true (string-contains? (run "(eval (ge 3 4))") "false")))

(test-case "generic-arith/int-mod"
  (check-equal? (run "(eval (mod 10 3))") "1 : Int"))

(test-case "generic-arith/int-mod-exact"
  (check-equal? (run "(eval (mod 9 3))") "0 : Int"))

(test-case "generic-arith/int-mod-divzero"
  ;; mod by zero is stuck (undefined) — returns unreduced expression
  (check-true (string-contains? (run "(eval (mod 7 0))") "mod")))

;; ========================================
;; B. Rat: gt, ge, mod (sexp mode)
;; ========================================

(test-case "generic-arith/rat-gt-true"
  (check-true (string-contains? (run "(eval (gt 3/4 1/2))") "true")))

(test-case "generic-arith/rat-gt-false"
  (check-true (string-contains? (run "(eval (gt 1/3 1/2))") "false")))

(test-case "generic-arith/rat-ge-true"
  (check-true (string-contains? (run "(eval (ge 1/2 1/2))") "true")))

(test-case "generic-arith/rat-ge-false"
  (check-true (string-contains? (run "(eval (ge 1/3 1/2))") "false")))

;; Rat mod is not supported (Racket's remainder requires integers).

;; ========================================
;; C. Nat: gt, ge, mod (sexp mode)
;; ========================================

(test-case "generic-arith/nat-gt-true"
  (check-true (string-contains?
    (run "(eval (gt (suc (suc (suc zero))) (suc zero)))") "true")))

(test-case "generic-arith/nat-gt-false"
  (check-true (string-contains?
    (run "(eval (gt (suc zero) (suc (suc zero))))") "false")))

(test-case "generic-arith/nat-ge-equal"
  (check-true (string-contains?
    (run "(eval (ge (suc (suc zero)) (suc (suc zero))))") "true")))

(test-case "generic-arith/nat-mod"
  (check-equal?
    (run "(eval (mod (suc (suc (suc (suc (suc zero))))) (suc (suc zero))))")
    "1N : Nat"))

;; ========================================
;; D. Type inference
;; ========================================

(test-case "generic-arith/infer-int-gt"
  (check-true (string-contains? (run "(infer (gt 3 4))") "Bool")))

(test-case "generic-arith/infer-int-ge"
  (check-true (string-contains? (run "(infer (ge 3 4))") "Bool")))

(test-case "generic-arith/infer-int-mod"
  (check-true (string-contains? (run "(infer (mod 10 3))") "Int")))

;; Rat mod inference skipped — mod not supported for Rat

;; ========================================
;; E. WS-mode: generic operators in expressions
;; ========================================

;; NOTE: In WS mode, `<` and `>` are angle-bracket delimiters (Pi/Sigma types),
;; so generic comparison operators use keyword names: lt, le, gt, ge, eq.
;; Arithmetic operators (+, -, *, /) and `mod` work directly.

(test-case "generic-arith-ws/gt-int"
  (check-true (string-contains?
    (run-ws-last "eval [gt 5 3]") "true")))

(test-case "generic-arith-ws/ge-int"
  (check-true (string-contains?
    (run-ws-last "eval [ge 5 5]") "true")))

(test-case "generic-arith-ws/mod-int"
  (check-equal?
    (run-ws-last "eval [mod 10 3]") "1 : Int"))

(test-case "generic-arith-ws/gt-nat"
  (check-true (string-contains?
    (run-ws-last "eval [gt 3N 1N]") "true")))

(test-case "generic-arith-ws/mod-nat"
  (check-equal?
    (run-ws-last "eval [mod 5N 2N]") "1N : Nat"))

;; ========================================
;; F. Relational context: is-goals with generic +
;; ========================================

(test-case "generic-arith-ws/is-goal-generic-plus"
  (define result (run-ws-last "
defr add-one [?n ?result]
  &> (is result [+ n 1])

solve (add-one 5 r)
"))
  (check-true (string-contains? (format "~a" result) "6")))

;; ========================================
;; G. Relational context: guard with generic >
;; ========================================

(test-case "generic-arith-ws/guard-generic-gt"
  (define result (run-ws-last "
defr weighted [?from ?to ?w]
  || \"a\" \"b\" 3
     \"b\" \"c\" 0
     \"c\" \"d\" 5

defr positive [?from ?to ?w]
  &> (weighted from to w) (guard [gt w 0])

solve (positive from to w)
"))
  ;; Should get 2 answers: a→b (w=3) and c→d (w=5), not b→c (w=0)
  (define s (format "~a" result))
  (check-true (string-contains? s "3") "should contain weight 3")
  (check-true (string-contains? s "5") "should contain weight 5")
  (check-false (string-contains? s "{:w 0") "should NOT contain weight 0 answer"))
