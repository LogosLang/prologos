#lang racket/base

;;;
;;; Tests for Phase 1d: DT-Guided Narrowing Search (Part 1)
;;; Sections A-B: Direct search API + Full pipeline sexp mode
;;;
;;; Covers: Bool narrowing, Nat narrowing (add/sub), recursive narrowing,
;;; multi-solution enumeration, nested constructor args, sexp pipeline.
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
    (process-string "(ns test-narrowing-search)")
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

;; Count solution maps in pretty-printed output
(define (count-answers result-str)
  (length (regexp-match* #rx"\\{:" result-str)))

;; ========================================
;; A. Direct search API tests (run-narrowing-search)
;; ========================================

(test-case "search/bool: not ?b = true → {b: false}"
  (parameterize ([current-global-env shared-global-env])
    (define sols
      (run-narrowing-search
       'prologos::data::bool::not
       (list (expr-logic-var 'b 'free))
       (expr-true)
       '(b)))
    (check-equal? (length sols) 1)
    (check-true (expr-false? (hash-ref (car sols) 'b)))))

(test-case "search/bool: not ?b = false → {b: true}"
  (parameterize ([current-global-env shared-global-env])
    (define sols
      (run-narrowing-search
       'prologos::data::bool::not
       (list (expr-logic-var 'b 'free))
       (expr-false)
       '(b)))
    (check-equal? (length sols) 1)
    (check-true (expr-true? (hash-ref (car sols) 'b)))))

(test-case "search/nat: add ?x ?y = 0 → 1 solution (0,0)"
  (parameterize ([current-global-env shared-global-env])
    (define sols
      (run-narrowing-search
       'prologos::data::nat::add
       (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
       (expr-zero)
       '(x y)))
    (check-equal? (length sols) 1)
    (check-true (expr-zero? (hash-ref (car sols) 'x)))
    (check-true (expr-zero? (hash-ref (car sols) 'y)))))

(test-case "search/nat: add ?x ?y = 1 → 2 solutions"
  (parameterize ([current-global-env shared-global-env])
    (define sols
      (run-narrowing-search
       'prologos::data::nat::add
       (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
       (expr-suc (expr-zero))
       '(x y)))
    (check-equal? (length sols) 2)))

(test-case "search/nat: add ?x ?y = 3 → 4 solutions"
  (parameterize ([current-global-env shared-global-env])
    (define sols
      (run-narrowing-search
       'prologos::data::nat::add
       (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
       (expr-suc (expr-suc (expr-suc (expr-zero))))
       '(x y)))
    (check-equal? (length sols) 4)))

(test-case "search/nat: add (suc ?x) ?y = 3 → 3 solutions"
  (parameterize ([current-global-env shared-global-env])
    (define target (expr-suc (expr-suc (expr-suc (expr-zero)))))
    (define sols
      (run-narrowing-search
       'prologos::data::nat::add
       (list (expr-suc (expr-logic-var 'x 'free))
             (expr-logic-var 'y 'free))
       target
       '(x y)))
    (check-equal? (length sols) 3)))

(test-case "search/nat: add zero ?y = 5 → 1 solution (y=5)"
  (parameterize ([current-global-env shared-global-env])
    (define target (expr-suc (expr-suc (expr-suc (expr-suc (expr-suc (expr-zero)))))))
    (define sols
      (run-narrowing-search
       'prologos::data::nat::add
       (list (expr-zero)
             (expr-logic-var 'y 'free))
       target
       '(y)))
    (check-equal? (length sols) 1)))

;; ========================================
;; B. Full pipeline tests — sexp mode
;; ========================================

(test-case "pipeline/sexp: not ?b = true → 1 solution"
  (define result (run-last "(= (not ?b) true)"))
  (check-equal? (count-answers result) 1))

(test-case "pipeline/sexp: not ?b = false → 1 solution"
  (define result (run-last "(= (not ?b) false)"))
  (check-equal? (count-answers result) 1))

(test-case "pipeline/sexp: add ?x ?y = 0 → 1 solution"
  (define result (run-last "(= (add ?x ?y) 0)"))
  (check-equal? (count-answers result) 1))

(test-case "pipeline/sexp: add ?x ?y = 2 → 3 solutions"
  (define result (run-last "(= (add ?x ?y) 2)"))
  (check-equal? (count-answers result) 3))

(test-case "pipeline/sexp: add ?x ?y = 3 → 4 solutions"
  (define result (run-last "(= (add ?x ?y) 3)"))
  (check-equal? (count-answers result) 4))

(test-case "pipeline/sexp: add (suc ?x) ?y = 5 → 5 solutions"
  (define result (run-last "(= (add (suc ?x) ?y) 5)"))
  (check-equal? (count-answers result) 5))

(test-case "pipeline/sexp: not ?b = ?b → nil (no solution)"
  ;; not(false)=true≠false, not(true)=false≠true
  (define result (run-last "(= (not ?b) ?b)"))
  (check-true (string-contains? result "nil")))

(test-case "pipeline/sexp: bare ?x = 5 → binds x (constructor inversion)"
  (define result (run-last "(= ?x 5)"))
  (check-true (string-contains? result "{:x")))
