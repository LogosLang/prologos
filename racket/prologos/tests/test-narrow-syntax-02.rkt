#lang racket/base

;;;
;;; Tests for Phase 1e: WS-Mode Narrowing Syntax (Part 2 of 2)
;;; Sections D-F: Result format, edge cases, WS-mode multi-line with definitions.
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
         "../parse-reader.rkt")

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
  (parameterize ([current-prelude-env (hasheq)]
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
    (process-string "(ns test-narrow-syntax)")
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
    (parameterize ([current-prelude-env shared-global-env]
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

;; Helper: count solution maps in output
(define (count-answers result-str)
  (length (regexp-match* #rx"\\{:" result-str)))

;; ========================================
;; D. Result format — narrowing produces solution maps
;; ========================================

(test-case "narrow/result: single solution has one map"
  (define result (run-last "(= (not ?b) true)"))
  ;; not ?b = true → 1 solution {b: false}
  (check-equal? (count-answers result) 1))

(test-case "narrow/result: Bool negation both ways"
  ;; not ?b = false → 1 solution {b: true}
  (define result (run-last "(= (not ?b) false)"))
  (check-equal? (count-answers result) 1))

(test-case "narrow/result: add produces multiple solutions"
  ;; add ?x ?y = 2 → 3 solutions: (0,2), (1,1), (2,0)
  (define result (run-last "(= (add ?x ?y) 2)"))
  (check-equal? (count-answers result) 3))

(test-case "narrow/result: type annotation is hole"
  ;; Narrowing results are type-unsafe (hole/underscore)
  (define result (run-last "(= (not ?b) true)"))
  (check-true (string-contains? result ": _")))

;; ========================================
;; E. Edge cases
;; ========================================

(test-case "narrow/edge: single ?-var no function call"
  ;; (= ?x 5) — LHS is just a var, constructor inversion binds ?x = 5
  (define result (run-last "(= ?x 5)"))
  (check-true (string? result))
  ;; Constructor inversion: ?x unifies with 5
  (check-true (string-contains? result "{:x")))

(test-case "narrow/edge: nested ctor in arg"
  ;; (= (add (suc ?x) ?y) 5) — fixed first arg shape, narrows second
  (define result (run-last "(= (add (suc ?x) ?y) 5)"))
  (check-true (string? result))
  (check-true (string-contains? result "{:")))

(test-case "narrow/edge: ?-var appears in both sides"
  ;; (= (not ?b) ?b) — same var on both sides → no solution
  ;; not(false) = true ≠ false; not(true) = false ≠ true
  (define result (run-last "(= (not ?b) ?b)"))
  (check-true (string? result))
  (check-true (string-contains? result "nil")))

;; ========================================
;; F. WS-mode integration — multi-line with definitions
;; ========================================

(test-case "narrow/ws: narrowing after definitions"
  ;; defn double [n] : Nat [add n n]
  ;; Phase 3a: non-matching functions get trivial dt-rule, enabling narrowing.
  ;; [double ?x] = 6N → add(?x, ?x) = 6 → x = 3
  (define result
    (run-ws-last
     (string-append
      "ns test-ws-n4\n"
      "defn double [n] : Nat [add n n]\n"
      "[double ?x] = 6N\n")))
  (check-true (string? result))
  ;; Should find solutions (not nil)
  (check-false (string-contains? result "nil")))
