#lang racket/base

;;;
;;; Tests for Phase 2c: Critical Pair / Confluence Analysis
;;; Tests confluence-analysis.rkt — classify functions as confluent or
;;; non-confluent based on their definitional trees.
;;;
;;; Covers: struct construction, fast path (no dt-or), slow path (critical pairs),
;;; joinability checking, helper functions, integration with prelude functions,
;;; pipeline with narrowing search.
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         "test-support.rkt"
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
    (process-string "(ns test-confluence)")
    (values (current-global-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-ctor-registry)
            (current-type-meta))))

;; Helper: extract a definitional tree from a prelude function.
(define (get-prelude-tree fqn)
  (parameterize ([current-global-env shared-global-env]
                 [current-ctor-registry shared-ctor-reg]
                 [current-type-meta shared-type-meta])
    (define body (global-env-lookup-value fqn))
    (and body (extract-definitional-tree body))))

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
                 [current-confluence-registry (hasheq)])
    (process-string s)))

(define (run-last s) (last (run s)))

;; Count solution maps in pretty-printed output.
(define (count-answers result-str)
  (length (regexp-match* #rx"\\{map" result-str)))

;; ========================================
;; A. Struct unit tests
;; ========================================

(test-case "struct/critical-pair: construction and accessors"
  (define cp (critical-pair 0 1 (expr-true) (expr-false) #f))
  (check-equal? (critical-pair-branch1-idx cp) 0)
  (check-equal? (critical-pair-branch2-idx cp) 1)
  (check-true (expr-true? (critical-pair-rhs1 cp)))
  (check-true (expr-false? (critical-pair-rhs2 cp)))
  (check-false (critical-pair-joinable? cp)))

(test-case "struct/critical-pair: joinable pair"
  (define cp (critical-pair 0 1 (expr-zero) (expr-zero) #t))
  (check-true (critical-pair-joinable? cp)))

(test-case "struct/confluence-result: confluent"
  (define cr (confluence-result 'confluent '()))
  (check-equal? (confluence-result-class cr) 'confluent)
  (check-equal? (confluence-result-critical-pairs cr) '()))

(test-case "struct/confluence-result: non-confluent with pairs"
  (define cp (critical-pair 0 1 (expr-true) (expr-false) #f))
  (define cr (confluence-result 'non-confluent (list cp)))
  (check-equal? (confluence-result-class cr) 'non-confluent)
  (check-equal? (length (confluence-result-critical-pairs cr)) 1))

;; ========================================
;; B. Fast path — no dt-or → confluent
;; ========================================

(test-case "fast/dt-rule: single rule → confluent"
  (define tree (dt-rule (expr-true)))
  (define result (analyze-confluence tree))
  (check-equal? (confluence-result-class result) 'confluent)
  (check-equal? (confluence-result-critical-pairs result) '()))

(test-case "fast/dt-exempt: exempt → confluent"
  (define tree (dt-exempt))
  (define result (analyze-confluence tree))
  (check-equal? (confluence-result-class result) 'confluent))

(test-case "fast/#f: no tree → unknown"
  (define result (analyze-confluence #f))
  (check-equal? (confluence-result-class result) 'unknown))

(test-case "fast/dt-branch: bool match no overlap → confluent"
  (define tree (dt-branch 0 'Bool
                 (list (cons 'true (dt-rule (expr-false)))
                       (cons 'false (dt-rule (expr-true))))))
  (define result (analyze-confluence tree))
  (check-equal? (confluence-result-class result) 'confluent)
  (check-equal? (confluence-result-critical-pairs result) '()))

(test-case "fast/dt-branch: nat match no overlap → confluent"
  (define tree (dt-branch 0 'Nat
                 (list (cons 'zero (dt-rule (expr-zero)))
                       (cons 'suc (dt-rule (expr-bvar 0))))))
  (define result (analyze-confluence tree))
  (check-equal? (confluence-result-class result) 'confluent))

(test-case "fast/dt-branch: nested branches, no or → confluent"
  (define inner (dt-branch 1 'Nat
                   (list (cons 'zero (dt-rule (expr-zero)))
                         (cons 'suc (dt-rule (expr-bvar 0))))))
  (define tree (dt-branch 0 'Nat
                 (list (cons 'zero (dt-rule (expr-zero)))
                       (cons 'suc inner))))
  (define result (analyze-confluence tree))
  (check-equal? (confluence-result-class result) 'confluent))

(test-case "fast/dt-branch: with exempt, no or → confluent"
  (define tree (dt-branch 0 'Nat
                 (list (cons 'zero (dt-rule (expr-true)))
                       (cons 'suc (dt-exempt)))))
  (define result (analyze-confluence tree))
  (check-equal? (confluence-result-class result) 'confluent))

;; ========================================
;; C. Slow path — dt-or analysis
;; ========================================

(test-case "slow/dt-or: identical RHS → confluent"
  ;; Two branches with the same RHS are joinable
  (define tree (dt-or (list (dt-rule (expr-true))
                            (dt-rule (expr-true)))))
  (define result (analyze-confluence tree))
  (check-equal? (confluence-result-class result) 'confluent)
  ;; Should have 1 critical pair, and it's joinable
  (check-equal? (length (confluence-result-critical-pairs result)) 1)
  (check-true (critical-pair-joinable? (car (confluence-result-critical-pairs result)))))

(test-case "slow/dt-or: different RHS → non-confluent"
  ;; Two branches with different RHS are not joinable
  (define tree (dt-or (list (dt-rule (expr-true))
                            (dt-rule (expr-false)))))
  (define result (analyze-confluence tree))
  (check-equal? (confluence-result-class result) 'non-confluent)
  (check-equal? (length (confluence-result-critical-pairs result)) 1)
  (check-false (critical-pair-joinable? (car (confluence-result-critical-pairs result)))))

(test-case "slow/dt-or: three branches, two identical → non-confluent"
  ;; 3 branches: (true, true, false) → pairs: (0,1 join), (0,2 no), (1,2 no)
  (define tree (dt-or (list (dt-rule (expr-true))
                            (dt-rule (expr-true))
                            (dt-rule (expr-false)))))
  (define result (analyze-confluence tree))
  (check-equal? (confluence-result-class result) 'non-confluent)
  ;; 3 critical pairs: C(3,2) = 3
  (check-equal? (length (confluence-result-critical-pairs result)) 3))

(test-case "slow/dt-or: three identical branches → confluent"
  (define tree (dt-or (list (dt-rule (expr-zero))
                            (dt-rule (expr-zero))
                            (dt-rule (expr-zero)))))
  (define result (analyze-confluence tree))
  (check-equal? (confluence-result-class result) 'confluent)
  (check-equal? (length (confluence-result-critical-pairs result)) 3))

(test-case "slow/dt-or: nested inside branch → detected"
  ;; dt-branch with one child containing a dt-or
  (define or-node (dt-or (list (dt-rule (expr-true))
                               (dt-rule (expr-false)))))
  (define tree (dt-branch 0 'Nat
                 (list (cons 'zero (dt-rule (expr-zero)))
                       (cons 'suc or-node))))
  (define result (analyze-confluence tree))
  (check-equal? (confluence-result-class result) 'non-confluent)
  (check-equal? (length (confluence-result-critical-pairs result)) 1))

(test-case "slow/dt-or: nested identical inside branch → confluent"
  (define or-node (dt-or (list (dt-rule (expr-true))
                               (dt-rule (expr-true)))))
  (define tree (dt-branch 0 'Nat
                 (list (cons 'zero (dt-rule (expr-zero)))
                       (cons 'suc or-node))))
  (define result (analyze-confluence tree))
  (check-equal? (confluence-result-class result) 'confluent))

;; ========================================
;; D. Joinability tests
;; ========================================

(test-case "join/dt-rule: same RHS → joinable"
  (check-true (branches-joinable? (dt-rule (expr-zero))
                                  (dt-rule (expr-zero)))))

(test-case "join/dt-rule: different RHS → not joinable"
  (check-false (branches-joinable? (dt-rule (expr-true))
                                   (dt-rule (expr-false)))))

(test-case "join/dt-rule: complex same RHS → joinable"
  (define rhs (expr-app (expr-fvar 'f) (expr-bvar 0)))
  (check-true (branches-joinable? (dt-rule rhs) (dt-rule rhs))))

(test-case "join/dt-exempt: both exempt → joinable"
  (check-true (branches-joinable? (dt-exempt) (dt-exempt))))

(test-case "join/mismatch: rule vs exempt → not joinable"
  (check-false (branches-joinable? (dt-rule (expr-true)) (dt-exempt))))

(test-case "join/mismatch: rule vs branch → not joinable"
  (define branch (dt-branch 0 'Bool
                   (list (cons 'true (dt-rule (expr-true))))))
  (check-false (branches-joinable? (dt-rule (expr-true)) branch)))

(test-case "join/dt-branch: same structure and RHS → joinable"
  (define b1 (dt-branch 0 'Bool
               (list (cons 'false (dt-rule (expr-zero)))
                     (cons 'true (dt-rule (expr-suc (expr-zero)))))))
  (define b2 (dt-branch 0 'Bool
               (list (cons 'true (dt-rule (expr-suc (expr-zero))))
                     (cons 'false (dt-rule (expr-zero))))))
  ;; Order-independent: should be joinable despite different child ordering
  (check-true (branches-joinable? b1 b2)))

(test-case "join/dt-branch: same structure, different RHS → not joinable"
  (define b1 (dt-branch 0 'Bool
               (list (cons 'true (dt-rule (expr-true)))
                     (cons 'false (dt-rule (expr-false))))))
  (define b2 (dt-branch 0 'Bool
               (list (cons 'true (dt-rule (expr-false)))
                     (cons 'false (dt-rule (expr-true))))))
  (check-false (branches-joinable? b1 b2)))

(test-case "join/dt-branch: different positions → not joinable"
  (define b1 (dt-branch 0 'Bool (list (cons 'true (dt-rule (expr-true))))))
  (define b2 (dt-branch 1 'Bool (list (cons 'true (dt-rule (expr-true))))))
  (check-false (branches-joinable? b1 b2)))

(test-case "join/dt-branch: different child count → not joinable"
  (define b1 (dt-branch 0 'Bool
               (list (cons 'true (dt-rule (expr-true))))))
  (define b2 (dt-branch 0 'Bool
               (list (cons 'true (dt-rule (expr-true)))
                     (cons 'false (dt-rule (expr-false))))))
  (check-false (branches-joinable? b1 b2)))

(test-case "join/dt-or: matching nested or → joinable"
  (define b1 (dt-or (list (dt-rule (expr-zero)) (dt-rule (expr-zero)))))
  (define b2 (dt-or (list (dt-rule (expr-zero)) (dt-rule (expr-zero)))))
  (check-true (branches-joinable? b1 b2)))

;; ========================================
;; E. Helper function tests
;; ========================================

(test-case "helper/extract-or-rules: dt-or → indexed branches"
  (define tree (dt-or (list (dt-rule (expr-true))
                            (dt-rule (expr-false)))))
  (define rules (extract-or-rules tree))
  (check-equal? (length rules) 2)
  (check-equal? (car (car rules)) 0)
  (check-equal? (car (cadr rules)) 1)
  (check-pred dt-rule? (cadr (car rules)))
  (check-pred dt-rule? (cadr (cadr rules))))

(test-case "helper/extract-or-rules: non-dt-or → empty"
  (check-equal? (extract-or-rules (dt-rule (expr-true))) '())
  (check-equal? (extract-or-rules (dt-exempt)) '())
  (check-equal? (extract-or-rules
                  (dt-branch 0 'Bool
                    (list (cons 'true (dt-rule (expr-true)))))) '()))

(test-case "helper/collect-all-or-groups: no or → empty"
  (define tree (dt-branch 0 'Nat
                 (list (cons 'zero (dt-rule (expr-zero)))
                       (cons 'suc (dt-rule (expr-bvar 0))))))
  (check-equal? (collect-all-or-groups tree) '()))

(test-case "helper/collect-all-or-groups: one or → one group"
  (define tree (dt-or (list (dt-rule (expr-true))
                            (dt-rule (expr-false)))))
  (define groups (collect-all-or-groups tree))
  (check-equal? (length groups) 1)
  (check-equal? (length (car groups)) 2))

(test-case "helper/collect-all-or-groups: nested or → multiple groups"
  (define inner-or (dt-or (list (dt-rule (expr-zero))
                                (dt-rule (expr-zero)))))
  (define outer-or (dt-or (list inner-or (dt-rule (expr-true)))))
  (define groups (collect-all-or-groups outer-or))
  ;; Outer or-group + inner or-group = 2
  (check-equal? (length groups) 2))

(test-case "helper/extract-leaf-rules: collects all RHS"
  (define tree (dt-branch 0 'Nat
                 (list (cons 'zero (dt-rule (expr-zero)))
                       (cons 'suc (dt-rule (expr-true))))))
  (define rules (extract-leaf-rules tree))
  (check-equal? (length rules) 2)
  (check-true (expr-zero? (car rules)))
  (check-true (expr-true? (cadr rules))))

(test-case "helper/extract-leaf-rules: skips exempt"
  (define tree (dt-branch 0 'Nat
                 (list (cons 'zero (dt-rule (expr-zero)))
                       (cons 'suc (dt-exempt)))))
  (define rules (extract-leaf-rules tree))
  (check-equal? (length rules) 1))

(test-case "helper/extract-leaf-rules: traverses dt-or"
  (define tree (dt-or (list (dt-rule (expr-true))
                            (dt-rule (expr-false)))))
  (define rules (extract-leaf-rules tree))
  (check-equal? (length rules) 2))

(test-case "helper/extract-representative-rhs: dt-rule → RHS"
  (check-true (expr-true? (extract-representative-rhs (dt-rule (expr-true))))))

(test-case "helper/extract-representative-rhs: dt-exempt → #f"
  (check-false (extract-representative-rhs (dt-exempt))))

(test-case "helper/extract-representative-rhs: dt-branch → first leaf"
  (define tree (dt-branch 0 'Nat
                 (list (cons 'zero (dt-rule (expr-zero)))
                       (cons 'suc (dt-rule (expr-true))))))
  (check-true (expr-zero? (extract-representative-rhs tree))))

(test-case "helper/compute-critical-pairs: two branches → 1 pair"
  (define branches (list (dt-rule (expr-true)) (dt-rule (expr-false))))
  (define pairs (compute-critical-pairs branches))
  (check-equal? (length pairs) 1)
  (check-equal? (critical-pair-branch1-idx (car pairs)) 0)
  (check-equal? (critical-pair-branch2-idx (car pairs)) 1))

(test-case "helper/compute-critical-pairs: three branches → 3 pairs"
  (define branches (list (dt-rule (expr-true))
                         (dt-rule (expr-false))
                         (dt-rule (expr-zero))))
  (define pairs (compute-critical-pairs branches))
  (check-equal? (length pairs) 3))

;; ========================================
;; F. Registry tests
;; ========================================

(test-case "registry/lookup-miss: returns #f"
  (parameterize ([current-confluence-registry (hasheq)])
    (check-false (lookup-confluence 'nonexistent))))

(test-case "registry/register-and-lookup"
  (parameterize ([current-confluence-registry (hasheq)])
    (define cr (confluence-result 'confluent '()))
    (register-confluence! 'my-func cr)
    (define found (lookup-confluence 'my-func))
    (check-not-false found)
    (check-equal? (confluence-result-class found) 'confluent)))

(test-case "registry/overwrite"
  (parameterize ([current-confluence-registry (hasheq)])
    (register-confluence! 'f (confluence-result 'confluent '()))
    (register-confluence! 'f (confluence-result 'non-confluent '()))
    (check-equal? (confluence-result-class (lookup-confluence 'f)) 'non-confluent)))

;; ========================================
;; G. Integration with prelude functions
;; ========================================

(test-case "integration/not: Bool negation → confluent"
  (define tree (get-prelude-tree 'prologos::data::bool::not))
  (check-not-false tree)
  (define result (analyze-confluence tree))
  (check-equal? (confluence-result-class result) 'confluent)
  (check-equal? (confluence-result-critical-pairs result) '()))

(test-case "integration/add: Nat addition → confluent"
  (define tree (get-prelude-tree 'prologos::data::nat::add))
  (check-not-false tree)
  (define result (analyze-confluence tree))
  (check-equal? (confluence-result-class result) 'confluent))

(test-case "integration/sub: Nat subtraction → confluent"
  (define tree (get-prelude-tree 'prologos::data::nat::sub))
  (check-not-false tree)
  (define result (analyze-confluence tree))
  (check-equal? (confluence-result-class result) 'confluent))

(test-case "integration/append: List append → confluent"
  (define tree (get-prelude-tree 'prologos::data::list::append))
  (check-not-false tree)
  (define result (analyze-confluence tree))
  (check-equal? (confluence-result-class result) 'confluent))

(test-case "integration/map: List map → confluent"
  (define tree (get-prelude-tree 'prologos::data::list::map))
  (check-not-false tree)
  (define result (analyze-confluence tree))
  (check-equal? (confluence-result-class result) 'confluent))

(test-case "integration/head: List head → confluent"
  (define tree (get-prelude-tree 'prologos::data::list::head))
  (check-not-false tree)
  (define result (analyze-confluence tree))
  (check-equal? (confluence-result-class result) 'confluent))

(test-case "integration/no-dt: identity function → unknown"
  ;; A function without pattern matching has no DT
  (define tree (get-prelude-tree 'nonexistent-function))
  (check-false tree)
  (define result (analyze-confluence tree))
  (check-equal? (confluence-result-class result) 'unknown))

(test-case "integration/fast-path-no-or: prelude functions have no dt-or"
  ;; Verify that standard library functions don't produce dt-or
  (for ([name '(prologos::data::bool::not
                prologos::data::nat::add
                prologos::data::nat::sub
                prologos::data::list::append
                prologos::data::list::map)])
    (define tree (get-prelude-tree name))
    (when tree
      (check-false (def-tree-has-or? tree)
                   (format "~a should have no dt-or" name)))))

;; ========================================
;; H. Pipeline tests — narrowing with confluence
;; ========================================

(test-case "pipeline/confluent: not ?b = true still works"
  (define result (run-last "(= (not ?b) true)"))
  (check-equal? (count-answers result) 1))

(test-case "pipeline/confluent: add ?x ?y = 3 still works"
  (define result (run-last "(= (add ?x ?y) 3)"))
  (check-equal? (count-answers result) 4))

(test-case "pipeline/confluent: add ?x ?y = 0 still works"
  (define result (run-last "(= (add ?x ?y) 0)"))
  (check-equal? (count-answers result) 1))

(test-case "pipeline/confluent: no solution still works"
  (define result (run-last "(= (not ?b) ?b)"))
  (check-true (string-contains? result "nil")))

(test-case "pipeline/get-confluence-class: caches result"
  (parameterize ([current-global-env shared-global-env]
                 [current-confluence-registry (hasheq)]
                 [current-ctor-registry shared-ctor-reg]
                 [current-type-meta shared-type-meta])
    ;; First call computes
    (define class1 (get-confluence-class 'prologos::data::bool::not))
    (check-equal? class1 'confluent)
    ;; Should be cached now
    (check-not-false (lookup-confluence 'prologos::data::bool::not))
    ;; Second call uses cache
    (define class2 (get-confluence-class 'prologos::data::bool::not))
    (check-equal? class2 'confluent)))

(test-case "pipeline/get-confluence-class: unknown for missing function"
  (parameterize ([current-global-env shared-global-env]
                 [current-confluence-registry (hasheq)])
    (define class (get-confluence-class 'no-such-function))
    (check-equal? class 'unknown)))
