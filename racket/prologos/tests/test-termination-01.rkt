#lang racket/base

;;;
;;; Tests for Phase 2b: Size-Based Termination Analysis (LJBA)
;;; Tests termination-analysis.rkt — size-change matrices, LJBA criterion,
;;; termination classification, and integration with narrowing search.
;;;
;;; Covers: struct construction, recursive call extraction, size-change
;;; matrix building, LJBA criterion, integration with prelude functions,
;;; per-function fuel in narrowing pipeline.
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         "test-support.rkt"
         "../termination-analysis.rkt"
         "../confluence-analysis.rkt"
         "../definitional-tree.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../narrowing.rkt"
         "../namespace.rkt"
         "../trait-resolution.rkt"
         "../multi-dispatch.rkt")

;; ========================================
;; Shared Fixture (prelude loaded once)
;; ========================================

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-ctor-reg
                shared-type-meta)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string "(ns test-termination)")
    (values (current-global-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-ctor-registry)
            (current-type-meta))))

;; Helper: extract DT and analyze termination for a prelude function.
(define (analyze-prelude-func fqn)
  (parameterize ([current-global-env shared-global-env]
                 [current-ctor-registry shared-ctor-reg]
                 [current-type-meta shared-type-meta])
    (define body (global-env-lookup-value fqn))
    (and body
         (let ()
           (define tree (extract-definitional-tree body))
           (define-values (arity _) (peel-lambdas body))
           (analyze-termination fqn tree arity)))))

;; Helper: run sexp code using shared environment.
(define (run s)
  (parameterize ([current-global-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-termination-registry (hasheq)]
                 [current-confluence-registry (hasheq)])
    (process-string s)))

(define (run-last s) (last (run s)))

(define (count-answers result-str)
  (length (regexp-match* #rx"\\{:" result-str)))

;; ========================================
;; A. Struct unit tests
;; ========================================

(test-case "struct/size-change-entry: construction"
  (define e (size-change-entry 0 1 'decreasing))
  (check-equal? (size-change-entry-from-arg e) 0)
  (check-equal? (size-change-entry-to-arg e) 1)
  (check-equal? (size-change-entry-change e) 'decreasing))

(test-case "struct/size-change-matrix: construction"
  (define m (size-change-matrix 2 (vector (vector 'decreasing 'unknown)
                                          (vector 'unknown 'non-increasing))))
  (check-equal? (size-change-matrix-arity m) 2)
  (check-equal? (vector-ref (vector-ref (size-change-matrix-entries m) 0) 0) 'decreasing)
  (check-equal? (vector-ref (vector-ref (size-change-matrix-entries m) 1) 1) 'non-increasing))

(test-case "struct/termination-result: terminating"
  (define r (termination-result 'terminating #f '()))
  (check-equal? (termination-result-class r) 'terminating)
  (check-false (termination-result-fuel-bound r)))

(test-case "struct/termination-result: bounded with fuel"
  (define r (termination-result 'bounded 50 '()))
  (check-equal? (termination-result-class r) 'bounded)
  (check-equal? (termination-result-fuel-bound r) 50))

;; ========================================
;; B. Size-change classification unit tests
;; ========================================

(test-case "classify/bvar-same: non-increasing"
  ;; arg = bvar(5), param-bvar-idx = 5 → non-increasing (same var)
  (check-equal? (classify-arg-change (expr-bvar 5) 5 0) 'non-increasing))

(test-case "classify/bvar-different-no-match-info: unknown"
  ;; arg = bvar(3), param-bvar-idx = 5, no matched-info → unknown
  (check-equal? (classify-arg-change (expr-bvar 3) 5 0) 'unknown))

(test-case "classify/bvar-sub-field-with-match-info: decreasing"
  ;; Simulates: arity 2, param 0 at bvar(2), depth=1 (suc match on param 0)
  ;; arg = bvar(0) which is in [0,1) = sub-field range of param 0
  ;; matched-info: param 0 was matched, 1 sub-field binding
  (check-equal? (classify-arg-change (expr-bvar 0) 2 1 0 (list (cons 0 1)))
                'decreasing))

(test-case "classify/bvar-sub-field-wrong-param: unknown"
  ;; Same setup but comparing to param 1 (not the matched param)
  ;; bvar(0) is a sub-field of param 0, not param 1
  (check-equal? (classify-arg-change (expr-bvar 0) 1 1 1 (list (cons 0 1)))
                'unknown))

(test-case "classify/bvar-below-depth-no-match: unknown"
  ;; arg = bvar(1), param-bvar-idx = 5, depth = 3, no matched-info
  (check-equal? (classify-arg-change (expr-bvar 1) 5 3) 'unknown))

(test-case "classify/suc-wrapping-param: increasing"
  ;; arg = suc(bvar(5)), param = bvar(5) → increasing
  (check-equal? (classify-arg-change (expr-suc (expr-bvar 5)) 5 0) 'increasing))

(test-case "classify/zero: unknown"
  (check-equal? (classify-arg-change (expr-zero) 5 0) 'unknown))

(test-case "classify/true: unknown"
  (check-equal? (classify-arg-change (expr-true) 3 0) 'unknown))

(test-case "classify/complex-expr: unknown"
  ;; arg = app(fvar f, bvar 0) → unknown
  (check-equal? (classify-arg-change (expr-app (expr-fvar 'f) (expr-bvar 0)) 5 0) 'unknown))

;; ========================================
;; C. Matrix operations
;; ========================================

(test-case "matrix/multiply: identity-like"
  ;; M = [[non-increasing]] → M*M = [[non-increasing]]
  (define m (size-change-matrix 1 (vector (vector 'non-increasing))))
  (define m2 (scm-multiply m m))
  (check-equal? (vector-ref (vector-ref (size-change-matrix-entries m2) 0) 0)
                'non-increasing))

(test-case "matrix/multiply: decreasing propagates"
  ;; M = [[decreasing]] → M*M = [[decreasing]]
  (define m (size-change-matrix 1 (vector (vector 'decreasing))))
  (define m2 (scm-multiply m m))
  (check-equal? (vector-ref (vector-ref (size-change-matrix-entries m2) 0) 0)
                'decreasing))

(test-case "matrix/multiply: unknown absorbs"
  ;; M1 = [[decreasing]], M2 = [[unknown]] → M1*M2 = [[unknown]]
  (define m1 (size-change-matrix 1 (vector (vector 'decreasing))))
  (define m2 (size-change-matrix 1 (vector (vector 'unknown))))
  (define m3 (scm-multiply m1 m2))
  (check-equal? (vector-ref (vector-ref (size-change-matrix-entries m3) 0) 0)
                'unknown))

(test-case "matrix/multiply: 2x2"
  ;; M = [[decreasing, unknown], [unknown, non-increasing]]
  ;; M*M[0][0] = meet(compose(dec,dec), compose(unk,unk)) = meet(dec, unk) = dec
  (define m (size-change-matrix 2
              (vector (vector 'decreasing 'unknown)
                      (vector 'unknown 'non-increasing))))
  (define m2 (scm-multiply m m))
  (check-equal? (vector-ref (vector-ref (size-change-matrix-entries m2) 0) 0)
                'decreasing)
  (check-equal? (vector-ref (vector-ref (size-change-matrix-entries m2) 1) 1)
                'non-increasing))

(test-case "matrix/transitive-closure: single decreasing"
  (define m (size-change-matrix 1 (vector (vector 'decreasing))))
  (define closure (scm-transitive-closure (list m)))
  ;; M*M = M (idempotent), so closure = {M}
  (check-true (>= (length closure) 1)))

(test-case "matrix/transitive-closure: two matrices"
  (define m1 (size-change-matrix 1 (vector (vector 'decreasing))))
  (define m2 (size-change-matrix 1 (vector (vector 'non-increasing))))
  (define closure (scm-transitive-closure (list m1 m2)))
  ;; Should contain at least m1, m2, and their products
  (check-true (>= (length closure) 2)))

;; ========================================
;; D. LJBA criterion tests
;; ========================================

(test-case "ljba/single-decreasing: terminates"
  ;; One recursive call with decreasing arg → terminates
  (define m (size-change-matrix 1 (vector (vector 'decreasing))))
  (check-true (ljba-check (list m) 1)))

(test-case "ljba/single-non-increasing: does NOT terminate"
  ;; Non-increasing only → LJBA not satisfied
  (define m (size-change-matrix 1 (vector (vector 'non-increasing))))
  (check-false (ljba-check (list m) 1)))

(test-case "ljba/single-unknown: does NOT terminate"
  (define m (size-change-matrix 1 (vector (vector 'unknown))))
  (check-false (ljba-check (list m) 1)))

(test-case "ljba/two-args-one-decreasing: terminates"
  ;; M = [[decreasing, unknown], [unknown, non-increasing]]
  ;; Diagonal has 'decreasing at [0][0] → terminates
  (define m (size-change-matrix 2
              (vector (vector 'decreasing 'unknown)
                      (vector 'unknown 'non-increasing))))
  (check-true (ljba-check (list m) 2)))

(test-case "ljba/no-matrices: terminates (no recursion)"
  (check-true (ljba-check '() 1)))

(test-case "ljba/two-calls-both-decrease: terminates"
  ;; Two recursive calls, each decreases arg 0
  (define m1 (size-change-matrix 1 (vector (vector 'decreasing))))
  (define m2 (size-change-matrix 1 (vector (vector 'decreasing))))
  (check-true (ljba-check (list m1 m2) 1)))

(test-case "ljba/lexicographic: terminates"
  ;; Call 1 decreases arg 0, call 2 decreases arg 1
  ;; The transitive closure should produce a matrix with decreasing diagonal
  (define m1 (size-change-matrix 2
               (vector (vector 'decreasing 'unknown)
                       (vector 'unknown 'non-increasing))))
  (define m2 (size-change-matrix 2
               (vector (vector 'non-increasing 'unknown)
                       (vector 'unknown 'decreasing))))
  (check-true (ljba-check (list m1 m2) 2)))

;; ========================================
;; E. Full analysis with manual trees
;; ========================================

(test-case "analyze/no-tree: non-narrowable"
  (define result (analyze-termination 'f #f 1))
  (check-equal? (termination-result-class result) 'non-narrowable))

(test-case "analyze/no-recursion: terminating"
  ;; fn [x] -> match x | true -> false | false -> true (no recursive call)
  (parameterize ([current-ctor-registry shared-ctor-reg])
    (define tree (dt-branch 0 'Bool
                   (list (cons 'true (dt-rule (expr-false)))
                         (cons 'false (dt-rule (expr-true))))))
    (define result (analyze-termination 'not tree 1))
    (check-equal? (termination-result-class result) 'terminating)
    (check-equal? (termination-result-matrices result) '())))

(test-case "analyze/simple-decreasing: terminating"
  ;; fn [x y] -> match x | zero -> y | suc n -> (f n y)
  ;; Arity 2. After suc match on param 0 (depth=1):
  ;;   bvar(0) = n (sub-field of x), bvar(1) = y (param 1), bvar(2) = x (param 0)
  ;; Recursive call: (f n y) = (app (app (fvar 'f) (bvar 0)) (bvar 1))
  ;; param 0 (x) at bvar(2), param 1 (y) at bvar(1)
  ;; arg 0 = bvar(0): sub-field of param 0 → decreasing
  ;; arg 1 = bvar(1): same as param 1 → non-increasing
  (parameterize ([current-ctor-registry shared-ctor-reg])
    (define rhs (expr-app (expr-app (expr-fvar 'f) (expr-bvar 0)) (expr-bvar 1)))
    (define tree (dt-branch 0 'Nat
                   (list (cons 'zero (dt-rule (expr-bvar 1)))
                         (cons 'suc (dt-rule rhs)))))
    (define result (analyze-termination 'f tree 2))
    (check-equal? (termination-result-class result) 'terminating)
    (check-equal? (length (termination-result-matrices result)) 1)))

;; ========================================
;; F. Integration with prelude functions
;; ========================================

(test-case "integration/not: no recursion → terminating"
  (define result (analyze-prelude-func 'prologos::data::bool::not))
  (check-not-false result)
  (check-equal? (termination-result-class result) 'terminating))

(test-case "integration/add: decreasing first arg → terminating"
  (define result (analyze-prelude-func 'prologos::data::nat::add))
  (check-not-false result)
  (check-equal? (termination-result-class result) 'terminating))

(test-case "integration/sub: terminating"
  (define result (analyze-prelude-func 'prologos::data::nat::sub))
  (check-not-false result)
  ;; sub has recursive calls; should be terminating or bounded
  (check-not-false (memq (termination-result-class result) '(terminating bounded))))

(test-case "integration/append: decreasing first arg → terminating"
  (define result (analyze-prelude-func 'prologos::data::list::append))
  (check-not-false result)
  (check-equal? (termination-result-class result) 'terminating))

(test-case "integration/map: terminating"
  (define result (analyze-prelude-func 'prologos::data::list::map))
  (check-not-false result)
  (check-equal? (termination-result-class result) 'terminating))

(test-case "integration/head: no recursion → terminating"
  (define result (analyze-prelude-func 'prologos::data::list::head))
  (check-not-false result)
  (check-equal? (termination-result-class result) 'terminating))

(test-case "integration/no-function: returns #f"
  (define result (analyze-prelude-func 'nonexistent-func))
  (check-false result))

;; ========================================
;; G. Registry tests
;; ========================================

(test-case "registry/lookup-miss: returns #f"
  (parameterize ([current-termination-registry (hasheq)])
    (check-false (lookup-termination 'nonexistent))))

(test-case "registry/register-and-lookup"
  (parameterize ([current-termination-registry (hasheq)])
    (define tr (termination-result 'terminating #f '()))
    (register-termination! 'my-func tr)
    (define found (lookup-termination 'my-func))
    (check-not-false found)
    (check-equal? (termination-result-class found) 'terminating)))

;; ========================================
;; H. Pipeline tests — narrowing with termination
;; ========================================

(test-case "pipeline/terminating: not ?b = true still works"
  (define result (run-last "(= (not ?b) true)"))
  (check-equal? (count-answers result) 1))

(test-case "pipeline/terminating: add ?x ?y = 3 still works"
  (define result (run-last "(= (add ?x ?y) 3)"))
  (check-equal? (count-answers result) 4))

(test-case "pipeline/terminating: add ?x ?y = 0 still works"
  (define result (run-last "(= (add ?x ?y) 0)"))
  (check-equal? (count-answers result) 1))

(test-case "pipeline/no-solution: not ?b = ?b still works"
  (define result (run-last "(= (not ?b) ?b)"))
  (check-true (string-contains? result "nil")))

(test-case "pipeline/get-termination-class: caches result"
  (parameterize ([current-global-env shared-global-env]
                 [current-termination-registry (hasheq)]
                 [current-ctor-registry shared-ctor-reg]
                 [current-type-meta shared-type-meta])
    (define class1 (get-termination-class 'prologos::data::nat::add))
    (check-equal? class1 'terminating)
    ;; Should be cached now
    (check-not-false (lookup-termination 'prologos::data::nat::add))
    ;; Second call uses cache
    (define class2 (get-termination-class 'prologos::data::nat::add))
    (check-equal? class2 'terminating)))

(test-case "pipeline/get-function-fuel: terminating gets full fuel"
  (parameterize ([current-global-env shared-global-env]
                 [current-termination-registry (hasheq)]
                 [current-ctor-registry shared-ctor-reg]
                 [current-type-meta shared-type-meta])
    (define fuel (get-function-fuel 'prologos::data::nat::add))
    (check-equal? fuel 50)))  ;; NARROW-DEPTH-LIMIT

(test-case "pipeline/get-termination-class: unknown for missing"
  (parameterize ([current-global-env shared-global-env]
                 [current-termination-registry (hasheq)])
    (define class (get-termination-class 'no-such-function))
    (check-equal? class 'non-narrowable)))
