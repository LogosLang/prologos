#lang racket/base

;;;
;;; Tests for Phase 1e: WS-Mode Narrowing Syntax
;;; Tests the syntax pipeline for narrowing expressions:
;;; WS reader (infix =) → parser (?-var detection) → elaborator (surf-narrow → expr-narrow)
;;; → type-checker → reduction (DT-guided search) → pretty-printer.
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
;; A. Parser unit tests — ?-variable detection
;; ========================================

(test-case "narrow-var-symbol?: valid ?x"
  (check-true (narrow-var-symbol? '?x)))

(test-case "narrow-var-symbol?: valid ?foo"
  (check-true (narrow-var-symbol? '?foo)))

(test-case "narrow-var-symbol?: invalid bare ?"
  (check-false (narrow-var-symbol? '?)))

(test-case "narrow-var-symbol?: invalid ?1 (numeric)"
  (check-false (narrow-var-symbol? '?1)))

(test-case "narrow-var-symbol?: non-symbol"
  (check-false (narrow-var-symbol? 42)))

(test-case "narrow-var-symbol?: regular symbol"
  (check-false (narrow-var-symbol? 'add)))

(test-case "collect-narrow-vars: finds ?-vars in datum"
  (define vars (collect-narrow-vars '(add ?x ?y)))
  (check-equal? vars '(?x ?y)))

(test-case "collect-narrow-vars: nested ?-vars"
  (define vars (collect-narrow-vars '(add (suc ?x) ?y)))
  (check-equal? vars '(?x ?y)))

(test-case "collect-narrow-vars: no duplicates"
  (define vars (collect-narrow-vars '(add ?x ?x)))
  (check-equal? vars '(?x)))

(test-case "collect-narrow-vars: no ?-vars"
  (define vars (collect-narrow-vars '(add x y)))
  (check-equal? vars '()))

;; ========================================
;; B. Sexp-mode — narrowing through full pipeline
;; ========================================

;; Helper: count solution maps in output
(define (count-answers result-str)
  (length (regexp-match* #rx"\\{:" result-str)))

(test-case "narrow/sexp: single ?-var produces solution"
  ;; (= (not ?b) true) — one ?-variable → narrowing finds {b: false}
  (define result (run-last "(= (not ?b) true)"))
  (check-true (string? result))
  (check-true (string-contains? result "{:")))

(test-case "narrow/sexp: two ?-vars"
  ;; (= (add ?x ?y) 3) — four solutions: (0,3), (1,2), (2,1), (3,0)
  (define result (run-last "(= (add ?x ?y) 3)"))
  (check-true (string? result))
  (check-true (string-contains? result "{:")))

(test-case "narrow/sexp: no ?-vars → not narrowing"
  ;; (= true true) without ?-vars: = is treated as a function application.
  ;; Parser produces surf-app (not surf-narrow) since no ?-prefixed vars.
  ;; We verify at parse level since the full pipeline errors on unbound =.
  (define parsed (parse-string "(= true true)"))
  ;; parse-string returns a single surf struct (not a list)
  (check-true (surf-app? parsed))
  (check-false (surf-narrow? parsed)))

;; ========================================
;; C. WS-mode — infix = rewriting
;; ========================================

(test-case "narrow/ws: basic infix = with ?-vars"
  (define result
    (run-ws-last "ns test-ws-n1\n[not ?b] = true\n"))
  (check-true (string? result))
  (check-true (string-contains? result "{:")))

(test-case "narrow/ws: two ?-vars with infix ="
  (define result
    (run-ws-last "ns test-ws-n2\n[add ?x ?y] = 3N\n"))
  (check-true (string? result))
  (check-true (string-contains? result "{:")))

(test-case "narrow/ws: ?-var on RHS"
  ;; true = [not ?b] — ?-var appears on RHS
  (define result
    (run-ws-last "ns test-ws-n3\ntrue = [not ?b]\n"))
  (check-true (string? result))
  (check-true (string-contains? result "{:")))

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
  ;; (= ?x 5) — LHS is just a var, no function application → no narrowing
  (define result (run-last "(= ?x 5)"))
  (check-true (string? result))
  ;; No function to narrow → nil (empty answer list)
  (check-true (string-contains? result "nil")))

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
