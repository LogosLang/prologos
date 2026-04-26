#lang racket/base

;;;
;;; Tests for Phase 2a: Static Generic Operator Resolution for Narrowing
;;; Verifies that generic operators (+, -, *) dispatch to concrete functions
;;; during narrowing, enabling equations like `1N + ?y = 3N` to solve.
;;;

(require rackunit
         racket/list
         racket/string
         racket/path
         racket/file
         racket/port
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../reduction.rkt"
         "../narrowing.rkt"
         "../namespace.rkt"
         "../trait-resolution.rkt")

;; ========================================
;; Shared Fixture (prelude loaded once)
;; ========================================

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-bundle-reg)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    (process-string "(ns test-trait-narrowing)")
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-bundle-registry))))

;; Run sexp code using shared environment
(define (run s)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
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
    (parameterize ([current-prelude-env shared-global-env]
                   [current-ns-context shared-ns-context]
                   [current-module-registry shared-module-reg]
                   [current-lib-paths (list prelude-lib-dir)]
                   [current-preparse-registry prelude-preparse-registry]
                   [current-trait-registry shared-trait-reg]
                   [current-impl-registry shared-impl-reg]
                   [current-param-impl-registry shared-param-impl-reg]
                   [current-bundle-registry shared-bundle-reg])
      (process-file tmp)))
  (delete-file tmp)
  result)

(define (run-ws-last s) (last (run-ws s)))

;; Count solution maps in pretty-printed output
(define (count-answers result-str)
  (length (regexp-match* #rx"\\{:" result-str)))

;; ========================================
;; A. Sexp-mode: generic operator narrowing
;; ========================================

(test-case "narrow/generic/sexp: (+ 1 ?y) = 3 → 1 solution"
  (define result (run-last "(= (+ 1 ?y) 3)"))
  (check-equal? (count-answers result) 1)
  (check-true (string-contains? result ":y")))

(test-case "narrow/generic/sexp: (+ ?x ?y) = 5 → 6 solutions (target-inferred type)"
  (define result (run-last "(= (+ ?x ?y) 5)"))
  (check-equal? (count-answers result) 6))

(test-case "narrow/generic/sexp: (+ ?x ?y) = 0 → 1 solution"
  (define result (run-last "(= (+ ?x ?y) 0)"))
  (check-equal? (count-answers result) 1))

;; ========================================
;; B. WS-mode: narrowing with generic ops via sexp (WS infix + not yet supported)
;; ========================================
;; Note: WS-mode infix `+` is not yet registered in the WS preparse pipeline,
;; so WS tests use the prefix `add` form for narrowing. The generic operator
;; dispatch is exercised via sexp-mode tests above.

(test-case "narrow/ws: [add 1N ?y] = 3N → 1 solution"
  (define result (run-ws-last "ns test-ws1\n[add 1N ?y] = 3N\n"))
  (check-equal? (count-answers result) 1)
  (check-true (string-contains? result ":y")))

(test-case "narrow/ws: [add ?x ?y] = 5N → 6 solutions"
  (define result (run-ws-last "ns test-ws2\n[add ?x ?y] = 5N\n"))
  (check-equal? (count-answers result) 6))

;; ========================================
;; C. Regression: existing narrowing unaffected
;; ========================================

(test-case "narrow/regression: (add ?x ?y) = 3 → 4 solutions (direct name)"
  (define result (run-last "(= (add ?x ?y) 3)"))
  (check-equal? (count-answers result) 4))

(test-case "narrow/regression: (not ?b) = true → 1 solution"
  (define result (run-last "(= (not ?b) true)"))
  (check-equal? (count-answers result) 1))
