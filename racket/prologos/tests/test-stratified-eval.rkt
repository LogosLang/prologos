#lang racket/base

;;;
;;; Tests for stratified-eval.rkt — Stratified Evaluation for the Logic Engine
;;;
;;; Unit tests for:
;;;   - Dependency extraction (relation-info → dep-info)
;;;   - Cached stratification (version-based invalidation)
;;;   - Stratified solver (single-stratum fast path)
;;;   - Variable-carrying negation helpers
;;;   - E2E through process-file for recursive + negation cases
;;;

(require rackunit
         racket/list
         racket/string
         racket/path
         racket/file
         racket/port
         "../syntax.rkt"
         "../relations.rkt"
         "../stratified-eval.rkt"
         "../stratify.rkt"
         "../solver.rkt"
         "../driver.rkt"
         "../errors.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../metavar-store.rkt"
         "../trait-resolution.rkt"
         "../reader.rkt"
         "../macros.rkt")

;; ========================================
;; E2E Test Infrastructure
;; ========================================

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

(define (run-prologos-string content)
  (define tmp (make-temporary-file "prologos-strat-~a.prologos"))
  (call-with-output-file tmp
    (lambda (out) (display content out))
    #:exists 'truncate)
  (define results
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                   [current-ns-context #f]
                   [current-module-registry (hasheq)]
                   [current-lib-paths (list lib-dir)]
                   [current-mult-meta-store (make-hasheq)]
                   [current-relation-store (make-relation-store)]
                   [current-relation-store-version 0]
                   [current-strata-cache #f]
                   [current-preparse-registry (current-preparse-registry)]
                   [current-trait-registry (current-trait-registry)]
                   [current-impl-registry (current-impl-registry)]
                   [current-param-impl-registry (current-param-impl-registry)]
                   [current-bundle-registry (current-bundle-registry)])
      (install-module-loader!)
      (process-file (path->string tmp))))
  (delete-file tmp)
  results)

(define (check-no-errors results)
  (for ([r (in-list results)])
    (when (prologos-error? r)
      (fail (format "Unexpected error: ~a" (prologos-error-message r))))))

(define (count-answers result-str)
  (length (regexp-match* #rx"\\{:" result-str)))

;; ========================================
;; Phase S1: Dependency Extraction
;; ========================================

(test-case "dep extraction: facts-only relation has no deps"
  (define ri (relation-info 'color 1
               (list (variant-info
                      (list (param-info 'X 'free))
                      '()
                      (list (fact-row (list "red"))
                            (fact-row (list "blue")))))
               #f #f))
  (define di (relation-info->dep-info ri))
  (check-equal? (dep-info-name di) 'color)
  (check-equal? (dep-info-pos-deps di) '())
  (check-equal? (dep-info-neg-deps di) '()))

(test-case "dep extraction: positive deps from app goals"
  (define ri (relation-info 'ancestor 2
               (list (variant-info
                      (list (param-info 'X 'free) (param-info 'Y 'free))
                      (list (clause-info
                             (list (goal-desc 'app (list 'parent (list 'X 'Y)))))
                            (clause-info
                             (list (goal-desc 'app (list 'parent (list 'X 'Z)))
                                   (goal-desc 'app (list 'ancestor (list 'Z 'Y))))))
                      '()))
               #f #f))
  (define di (relation-info->dep-info ri))
  (check-equal? (dep-info-name di) 'ancestor)
  (check-not-false (member 'parent (dep-info-pos-deps di)))
  (check-not-false (member 'ancestor (dep-info-pos-deps di)))
  (check-equal? (dep-info-neg-deps di) '()))

(test-case "dep extraction: negative deps from not goals"
  (define inner-goal (expr-goal-app 'ancestor (list (expr-logic-var 'X #f)
                                                     (expr-logic-var 'Y #f))))
  (define ri (relation-info 'not-ancestor 2
               (list (variant-info
                      (list (param-info 'X 'free) (param-info 'Y 'free))
                      (list (clause-info
                             (list (goal-desc 'not (list inner-goal)))))
                      '()))
               #f #f))
  (define di (relation-info->dep-info ri))
  (check-equal? (dep-info-name di) 'not-ancestor)
  (check-equal? (dep-info-pos-deps di) '())
  (check-not-false (member 'ancestor (dep-info-neg-deps di))))

(test-case "dep extraction: mixed positive and negative deps"
  (define inner-goal (expr-goal-app 'bad (list (expr-logic-var 'X #f))))
  (define ri (relation-info 'safe-path 2
               (list (variant-info
                      (list (param-info 'X 'free) (param-info 'Y 'free))
                      (list (clause-info
                             (list (goal-desc 'app (list 'edge (list 'X 'Y)))
                                   (goal-desc 'not (list inner-goal)))))
                      '()))
               #f #f))
  (define di (relation-info->dep-info ri))
  (check-equal? (dep-info-name di) 'safe-path)
  (check-not-false (member 'edge (dep-info-pos-deps di)))
  (check-not-false (member 'bad (dep-info-neg-deps di))))

(test-case "extract-all-dep-infos: multiple relations"
  (define store
    (hasheq 'parent
            (relation-info 'parent 2
              (list (variant-info
                     (list (param-info 'X 'free) (param-info 'Y 'free))
                     '()
                     (list (fact-row '("alice" "bob")))))
              #f #f)
            'ancestor
            (relation-info 'ancestor 2
              (list (variant-info
                     (list (param-info 'X 'free) (param-info 'Y 'free))
                     (list (clause-info
                            (list (goal-desc 'app (list 'parent (list 'X 'Y))))))
                     '()))
              #f #f)))
  (define dep-infos (extract-all-dep-infos store))
  (check-equal? (length dep-infos) 2)
  (define names (map dep-info-name dep-infos))
  (check-not-false (member 'parent names))
  (check-not-false (member 'ancestor names)))

;; ========================================
;; Phase S2: Cached Stratification
;; ========================================

(test-case "strata cache: computes on first call"
  (parameterize ([current-relation-store-version 0]
                 [current-strata-cache #f])
    (define store
      (hasheq 'parent
              (relation-info 'parent 2
                (list (variant-info
                       (list (param-info 'X 'free) (param-info 'Y 'free))
                       '()
                       (list (fact-row '("a" "b")))))
                #f #f)))
    (define strata (get-or-compute-strata store))
    (check-true (list? strata))
    (check-true (pair? (current-strata-cache)))))

(test-case "strata cache: reuses on same version"
  (parameterize ([current-relation-store-version 1]
                 [current-strata-cache (cons 1 '((dummy)))])
    (define store (hasheq))
    (define strata (get-or-compute-strata store))
    (check-equal? strata '((dummy)))))

(test-case "strata cache: invalidates on version bump"
  (parameterize ([current-relation-store-version 2]
                 [current-strata-cache (cons 1 '((old)))])
    (define store (hasheq))
    (define strata (get-or-compute-strata store))
    (check-equal? strata '())))

(test-case "version bump: increments correctly"
  (parameterize ([current-relation-store-version 0])
    (check-equal? (current-relation-store-version) 0)
    (bump-relation-store-version!)
    (check-equal? (current-relation-store-version) 1)
    (bump-relation-store-version!)
    (check-equal? (current-relation-store-version) 2)))

;; ========================================
;; Phase S3: Stratified Solver (unit: facts-only)
;; ========================================

;; NOTE: The solver uses symbols as logic variables and non-symbols (strings,
;; AST nodes) as ground constants. Fact-row terms must be strings/numbers/etc.
;; for the solver to distinguish them from variables.

(test-case "stratified-solve-goal: single-stratum fast path (facts only)"
  (define store
    (hasheq 'color
            (relation-info 'color 1
              (list (variant-info
                     (list (param-info 'X 'free))
                     '()
                     (list (fact-row (list "red"))
                           (fact-row (list "blue"))
                           (fact-row (list "green")))))
              #f #f)))
  (parameterize ([current-relation-store store]
                 [current-relation-store-version 0]
                 [current-strata-cache #f])
    (define answers
      (stratified-solve-goal default-solver-config store 'color '() '(X)))
    (check-equal? (length answers) 3)
    (for ([a (in-list answers)])
      (check-true (hash-has-key? a 'X)))))

(test-case "stratified-solve-goal: ground query on facts"
  (define store
    (hasheq 'color
            (relation-info 'color 1
              (list (variant-info
                     (list (param-info 'X 'free))
                     '()
                     (list (fact-row (list "red"))
                           (fact-row (list "blue")))))
              #f #f)))
  (parameterize ([current-relation-store store]
                 [current-relation-store-version 0]
                 [current-strata-cache #f])
    (define answers
      (stratified-solve-goal default-solver-config store 'color (list "red") '()))
    (check-true (>= (length answers) 1))))

;; ========================================
;; Phase S5: Variable-Carrying Negation Helpers
;; ========================================

(test-case "rename-ast-vars: renames logic vars in expr-goal-app"
  (define expr (expr-goal-app 'parent (list (expr-logic-var 'X #f) (expr-logic-var 'Y #f))))
  (define fresh-map (make-hasheq))
  (hash-set! fresh-map 'X 'X_1)
  (hash-set! fresh-map 'Y 'Y_1)
  (define renamed (rename-ast-vars expr fresh-map))
  (check-true (expr-goal-app? renamed))
  (check-equal? (expr-goal-app-name renamed) 'parent)
  (define args (expr-goal-app-args renamed))
  (check-equal? (expr-logic-var-name (car args)) 'X_1)
  (check-equal? (expr-logic-var-name (cadr args)) 'Y_1))

(test-case "rename-ast-vars: renames in nested not"
  (define inner (expr-goal-app 'p (list (expr-logic-var 'X #f))))
  (define expr (expr-not-goal inner))
  (define fresh-map (make-hasheq))
  (hash-set! fresh-map 'X 'X_fresh)
  (define renamed (rename-ast-vars expr fresh-map))
  (check-true (expr-not-goal? renamed))
  (define renamed-inner (expr-not-goal-goal renamed))
  (check-true (expr-goal-app? renamed-inner))
  (check-equal? (expr-logic-var-name (car (expr-goal-app-args renamed-inner))) 'X_fresh))

(test-case "collect-ast-vars: collects from goal-app"
  (define expr (expr-goal-app 'test (list (expr-logic-var 'A #f)
                                           (expr-logic-var 'B #f))))
  (define vars (make-hasheq))
  (collect-ast-vars expr vars)
  (check-true (hash-has-key? vars 'A))
  (check-true (hash-has-key? vars 'B)))

;; ========================================
;; E2E: Stratified solve through full pipeline
;; ========================================

(test-case "e2e/stratified: facts-only works through stratified layer"
  (define results
    (run-prologos-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr color [?x]\n"
      "  || \"red\"\n"
      "  || \"blue\"\n\n"
      "eval (solve (color x))\n")))
  (check-no-errors results)
  (define solve-result (last results))
  (check-true (string? solve-result))
  (check-equal? (count-answers solve-result) 2))

(test-case "e2e/stratified: recursive ancestor works through stratified layer"
  (define results
    (run-prologos-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr parent [?x ?y]\n"
      "  || \"alice\" \"bob\"\n"
      "  || \"bob\" \"carol\"\n\n"
      "defr ancestor [?x ?y]\n"
      "  &> (parent x y)\n"
      "  &> (parent x z) (ancestor z y)\n\n"
      "eval (solve (ancestor \"alice\" y))\n")))
  (check-no-errors results)
  (define solve-result (last results))
  (check-true (string? solve-result))
  ;; alice → bob (direct), alice → carol (transitive via bob)
  (check-equal? (count-answers solve-result) 2
                "ancestor alice ?y should find 2 answers (bob, carol)"))

(test-case "e2e/stratified: negation-as-failure through stratified layer"
  (define results
    (run-prologos-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr edge [?x ?y]\n"
      "  || \"a\" \"b\"\n"
      "  || \"b\" \"c\"\n\n"
      "defr safe-edge [?x ?y]\n"
      "  &> (edge x y) (not (edge y x))\n\n"
      "eval (solve (safe-edge x y))\n")))
  (check-no-errors results)
  (define solve-result (last results))
  (check-true (string? solve-result))
  ;; edge a→b and b→c exist; neither b→a nor c→b exist as edges
  ;; So both (a,b) and (b,c) are safe edges
  (check-equal? (count-answers solve-result) 2
                "safe-edge should find 2 answers (both edges are safe)"))

(test-case "e2e/stratified: version counter bumps on defr"
  ;; Verify that defining multiple relations bumps the version counter
  ;; (checked indirectly by correct results — cache invalidation works)
  (define results
    (run-prologos-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr color [?x]\n"
      "  || \"red\"\n\n"
      "defr shape [?x]\n"
      "  || \"circle\"\n"
      "  || \"square\"\n\n"
      "eval (solve (shape y))\n")))
  (check-no-errors results)
  (define solve-result (last results))
  (check-true (string? solve-result))
  (check-equal? (count-answers solve-result) 2))
