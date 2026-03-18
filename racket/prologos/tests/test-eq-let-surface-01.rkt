#lang racket/base

;;;
;;; Tests for Surface Ergonomics Batch 1:
;;; Phase 1a: = without ?vars → eq? (Bool check)
;;; Phase 1b: let with = in value position
;;; Phase 1c: Sequential let blocks
;;; Phase 1d: Flat-pair let [x v1 y v2] body
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         racket/port
         racket/file
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
         "../reader.rkt")

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
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    (process-string "(ns test-eq-let-surface)")
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
                 [current-preparse-registry prelude-preparse-registry]
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
                   [current-preparse-registry prelude-preparse-registry]
                   [current-trait-registry shared-trait-reg]
                   [current-impl-registry shared-impl-reg]
                   [current-param-impl-registry shared-param-impl-reg]
                   [current-bundle-registry shared-bundle-reg])
      (process-file tmp)))
  (delete-file tmp)
  result)

(define (run-ws-last s) (last (run-ws s)))

;; ========================================
;; A. Phase 1a: = without ?vars → eq? (Bool check)
;; ========================================

(test-case "eq-surface/sexp: (= true true) → true"
  (define result (run-last "(= true true)"))
  (check-true (string? result))
  (check-true (string-contains? result "true")))

(test-case "eq-surface/sexp: (= true false) → false"
  (define result (run-last "(= true false)"))
  (check-true (string? result))
  (check-true (string-contains? result "false")))

(test-case "eq-surface/ws: Nat equality true"
  ;; [plus 1N 2N] = 3N → true
  (define result
    (run-ws-last "ns test-eq-nat-t\n[plus 1N 2N] = 3N\n"))
  (check-true (string? result))
  (check-true (string-contains? result "true")))

(test-case "eq-surface/ws: Nat equality false"
  ;; 1N = 2N → false
  (define result
    (run-ws-last "ns test-eq-nat-f\n1N = 2N\n"))
  (check-true (string? result))
  (check-true (string-contains? result "false")))

(test-case "eq-surface/ws: Bool equality"
  (define result
    (run-ws-last "ns test-eq-bool\ntrue = false\n"))
  (check-true (string? result))
  (check-true (string-contains? result "false")))

(test-case "eq-surface/ws: zero = zero → true"
  (define result
    (run-ws-last "ns test-eq-zero\nzero = zero\n"))
  (check-true (string? result))
  (check-true (string-contains? result "true")))

;; Regression: narrowing still works when ?-vars present
(test-case "eq-surface/ws: narrowing with ?-vars preserved"
  (define result
    (run-ws-last "ns test-eq-narrow\n[add ?x ?y] = 3N\n"))
  (check-true (string? result))
  ;; Should return solution map(s) with {:
  (check-true (string-contains? result "{:")))

;; ========================================
;; B. Phase 1b: let with = in value position
;; ========================================

(test-case "let-eq/ws: let with Bool equality in value"
  ;; Inside a function body: let r := 1N = 1N → r is true
  (define result
    (run-ws-last "ns test-let-eq1\nspec test-fn1 Nat -> Bool\ndefn test-fn1 [u]\n  let r := 1N = 1N\n  r\n[test-fn1 zero]\n"))
  (check-true (string? result))
  (check-true (string-contains? result "true")))

(test-case "let-eq/ws: let with plus equality in value"
  ;; Inside a function body: let r := [plus 1N 2N] = 3N → r is true
  (define result
    (run-ws-last "ns test-let-eq2\nspec test-fn2 Nat -> Bool\ndefn test-fn2 [u]\n  let r := [plus 1N 2N] = 3N\n  r\n[test-fn2 zero]\n"))
  (check-true (string? result))
  (check-true (string-contains? result "true")))

;; ========================================
;; C. Phase 1c: Sequential let blocks (inside defn body)
;; ========================================

(test-case "seq-let/ws: sequential lets in defn body"
  ;; defn with two sequential let bindings + body expression
  (define result
    (run-ws-last "ns test-seq-let1\nspec test-seq Nat -> Nat\ndefn test-seq [u]\n  let x := 2N\n  let y := 3N\n  [add x y]\n[test-seq zero]\n"))
  (check-true (string? result))
  (check-true (string-contains? result "5N")))

(test-case "seq-let/sexp: nested lets in sexp"
  ;; Sexp-mode: nested lets — already works
  (define result
    (run-last "(defn test-seq-sexp [u : Nat] : Nat (let x := (suc (suc zero)) (let y := (suc (suc (suc zero))) (add x y))))\n(eval (test-seq-sexp zero))"))
  (check-true (string-contains? result "5N")))

;; ========================================
;; D. Phase 1d: Flat-pair let [x v1 y v2] body
;; ========================================

(test-case "flat-let/sexp: flat-pair let bindings"
  ;; (let (x (suc zero) y (suc (suc zero))) (add x y))
  (define result
    (run-last "(let (x (suc zero) y (suc (suc zero))) (add x y))"))
  (check-true (string-contains? result "3N")))

(test-case "flat-let/sexp: flat-pair let with 3 bindings"
  (define result
    (run-last "(let (x (suc zero) y (suc (suc zero)) z (suc (suc (suc zero)))) (add (add x y) z))"))
  (check-true (string-contains? result "6N")))
