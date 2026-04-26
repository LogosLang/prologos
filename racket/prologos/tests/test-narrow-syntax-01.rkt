#lang racket/base

;;;
;;; Tests for Phase 1e: WS-Mode Narrowing Syntax (Part 1 of 2)
;;; Sections A-C: Parser unit tests, sexp-mode narrowing, WS-mode infix =.
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
