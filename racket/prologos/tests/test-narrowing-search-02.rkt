#lang racket/base

;;;
;;; Tests for Phase 1d: DT-Guided Narrowing Search (Part 2)
;;; Sections C-D: Full pipeline WS mode + Edge cases
;;;
;;; Covers: WS-mode narrowing pipeline, RHS function narrowing,
;;; nested constructor args in WS, non-matching function narrowing,
;;; expr-int normalization, zero-target edge case.
;;;

(require rackunit
         racket/list
         racket/string
         racket/path
         racket/file
         racket/port
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../reduction.rkt"
         "../narrowing.rkt"
         "../definitional-tree.rkt"
         "../namespace.rkt"
         "../trait-resolution.rkt")

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
    (process-string "(ns test-narrowing-search)")
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

;; Count solution maps in pretty-printed output
(define (count-answers result-str)
  (length (regexp-match* #rx"\\{:" result-str)))

;; ========================================
;; C. Full pipeline tests — WS mode
;; ========================================

(test-case "pipeline/ws: [not ?b] = true → 1 solution"
  (define result (run-ws-last "ns test-ns-ws1\n[not ?b] = true\n"))
  (check-equal? (count-answers result) 1))

(test-case "pipeline/ws: [add ?x ?y] = 2N → 3 solutions"
  (define result (run-ws-last "ns test-ns-ws2\n[add ?x ?y] = 2N\n"))
  (check-equal? (count-answers result) 3))

(test-case "pipeline/ws: RHS function — true = [not ?b] → 1 solution"
  (define result (run-ws-last "ns test-ns-ws3\ntrue = [not ?b]\n"))
  (check-equal? (count-answers result) 1))

(test-case "pipeline/ws: [add [suc ?x] ?y] = 4N → 4 solutions"
  (define result (run-ws-last "ns test-ns-ws4\n[add [suc ?x] ?y] = 4N\n"))
  (check-equal? (count-answers result) 4))

;; ========================================
;; D. Edge cases
;; ========================================

(test-case "edge/no-dt: function without pattern matching narrowed via Phase 3a"
  ;; defn double [n] : Nat [add n n]
  ;; Phase 3a: non-matching functions get trivial dt-rule, enabling narrowing
  ;; through function body. [double ?x] = 4N → add(?x, ?x) = 4 → x = 2
  (define result
    (run-ws-last
     (string-append "ns test-ns-nodt\n"
                    "defn double [n] : Nat [add n n]\n"
                    "[double ?x] = 4N\n")))
  ;; Should find solutions (not nil)
  (check-false (string-contains? result "nil")))

(test-case "edge/nat-val-target: expr-int normalized to Peano"
  ;; Pipeline uses expr-int for bare numeric literals
  (define result (run-last "(= (add ?x ?y) 1)"))
  (check-equal? (count-answers result) 2))

(test-case "edge/zero-target: add ?x ?y = zero → 1 solution"
  (define result (run-last "(= (add ?x ?y) zero)"))
  (check-equal? (count-answers result) 1))
