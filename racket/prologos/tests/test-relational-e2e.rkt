#lang racket/base

;;;
;;; E2E Tests for Phase 7: Relational Language (defr, solve)
;;;
;;; Tests the full pipeline: WS reader -> parser -> elaborator ->
;;; type-check -> zonk -> driver registration -> solve reduction.
;;;
;;; Each test creates an independent temp .prologos file, processes it
;;; with process-file, and checks the resulting strings for correctness.
;;; All tests use :no-prelude for speed.
;;;

(require rackunit
         racket/list
         racket/string
         racket/path
         racket/file
         racket/port
         "../driver.rkt"
         "../errors.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../metavar-store.rkt"
         "../relations.rkt"
         "../trait-resolution.rkt"
         "../reader.rkt"
         "../macros.rkt")

;; ========================================
;; Test Infrastructure
;; ========================================

;; Compute lib directory from this file's location
(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

;; Run a .prologos string through the full pipeline (WS reader + driver).
;; Returns a list of result strings (or prologos-error structs).
(define (run-prologos-string content)
  (define tmp (make-temporary-file "prologos-e2e-~a.prologos"))
  (call-with-output-file tmp
    (lambda (out) (display content out))
    #:exists 'truncate)
  (define results
    (parameterize ([current-global-env (hasheq)]
                   [current-ns-context #f]
                   [current-module-registry (hasheq)]
                   [current-lib-paths (list lib-dir)]
                   [current-mult-meta-store (make-hasheq)]
                   [current-relation-store (make-relation-store)]
                   [current-preparse-registry (current-preparse-registry)]
                   [current-trait-registry (current-trait-registry)]
                   [current-impl-registry (current-impl-registry)]
                   [current-param-impl-registry (current-param-impl-registry)]
                   [current-bundle-registry (current-bundle-registry)])
      (install-module-loader!)
      (process-file (path->string tmp))))
  (delete-file tmp)
  results)

;; Assert that no result in the list is an error.
(define (check-no-errors results)
  (for ([r (in-list results)])
    (when (prologos-error? r)
      (fail (format "Unexpected error: ~a" (prologos-error-message r))))))

;; Count occurrences of "{map" in a result string to determine answer count.
(define (count-answers result-str)
  (length (regexp-match* #rx"\\{map" result-str)))

;; Get the last non-error result from the results list.
(define (last-result results)
  (last results))

;; ========================================
;; 1. Fact-only defr: basic fact registration + solve
;; ========================================

(test-case "e2e/fact-only-defr: parent facts + solve returns 1 answer"
  (define results
    (run-prologos-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr parent [?x ?y]\n"
      "  || \"alice\" \"bob\"\n"
      "  || \"bob\" \"carol\"\n\n"
      "eval (solve (parent \"alice\" y))\n")))
  (check-no-errors results)
  (define solve-result (last-result results))
  (check-true (string? solve-result)
              "solve result should be a string")
  (check-true (string-contains? solve-result "{map")
              "solve result should contain answer maps")
  (check-equal? (count-answers solve-result) 1
                "should find exactly 1 answer for parent alice ?y"))

;; ========================================
;; 2. Recursive relation: ancestor via parent + transitivity
;; ========================================

(test-case "e2e/recursive-ancestor: 3 transitive ancestors"
  (define results
    (run-prologos-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr parent [?x ?y]\n"
      "  || \"alice\" \"bob\"\n"
      "  || \"bob\" \"carol\"\n"
      "  || \"carol\" \"dave\"\n\n"
      "defr ancestor [?x ?y]\n"
      "  &> (parent x y)\n"
      "  &> (parent x z) (ancestor z y)\n\n"
      "eval (solve (ancestor \"alice\" y))\n")))
  (check-no-errors results)
  (define solve-result (last-result results))
  (check-true (string? solve-result))
  ;; alice -> bob (direct), alice -> carol (via bob), alice -> dave (via bob->carol)
  (check-equal? (count-answers solve-result) 3
                "ancestor alice ?y should find 3 answers (bob, carol, dave)"))

;; ========================================
;; 3. Multiple defr: define two relations, query the second
;; ========================================

(test-case "e2e/multiple-defr: query second of two relations"
  (define results
    (run-prologos-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr color [?x]\n"
      "  || \"red\"\n"
      "  || \"blue\"\n\n"
      "defr shape [?x]\n"
      "  || \"circle\"\n"
      "  || \"square\"\n\n"
      "eval (solve (shape y))\n")))
  (check-no-errors results)
  (define solve-result (last-result results))
  (check-true (string? solve-result))
  (check-equal? (count-answers solve-result) 2
                "shape query should return 2 answers (circle, square)"))

;; ========================================
;; 4. Unification goal: defr with (= x y) goal
;; ========================================

(test-case "e2e/unification-goal: (= x y) unifies variables"
  (define results
    (run-prologos-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr same [?x ?y]\n"
      "  &> (= x y)\n\n"
      "eval (solve (same \"hello\" y))\n")))
  (check-no-errors results)
  (define solve-result (last-result results))
  (check-true (string? solve-result))
  (check-equal? (count-answers solve-result) 1
                "(= x y) with ground x should produce 1 answer"))

;; ========================================
;; 5. Negation as failure: (not (goal)) with ground arguments
;; ========================================
;;
;; Note: negation-as-failure currently works with ground arguments in the
;; inner goal. Variable-carrying negation requires substitution walking
;; through the AST expression, which is not yet implemented (Phase 7 future).

(test-case "e2e/negation-ground: not (bad ...) succeeds when inner fails"
  (define results
    (run-prologos-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr bad [?x]\n"
      "  || \"evil\"\n\n"
      "defr check-ok [?x]\n"
      "  &> (not (bad \"alice\"))\n\n"
      "eval (solve (check-ok y))\n")))
  (check-no-errors results)
  (define solve-result (last-result results))
  (check-true (string? solve-result))
  ;; bad("alice") fails, so not succeeds -> 1 answer
  (check-equal? (count-answers solve-result) 1
                "not (bad \"alice\") should succeed (alice is not bad)"))

(test-case "e2e/negation-ground-fails: not (bad ...) fails when inner succeeds"
  (define results
    (run-prologos-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr bad [?x]\n"
      "  || \"evil\"\n\n"
      "defr check-ok [?x]\n"
      "  &> (not (bad \"evil\"))\n\n"
      "eval (solve (check-ok y))\n")))
  (check-no-errors results)
  (define solve-result (last-result results))
  (check-true (string? solve-result))
  ;; bad("evil") succeeds, so not fails -> empty list
  (check-equal? solve-result "nil : _"
                "not (bad \"evil\") should fail (evil IS bad)"))

;; ========================================
;; 6. Empty facts: relation with no data returns empty solve
;; ========================================

(test-case "e2e/empty-facts: empty fact block returns nil"
  (define results
    (run-prologos-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr empty-rel [?x]\n"
      "  || \n\n"
      "eval (solve (empty-rel y))\n")))
  (check-no-errors results)
  (define solve-result (last-result results))
  (check-true (string? solve-result))
  (check-equal? solve-result "nil : _"
                "empty relation should return nil"))

;; ========================================
;; 7. Mode annotations: +key (in) and -val (out) modes
;; ========================================

(test-case "e2e/mode-annotations: +key -val lookup"
  (define results
    (run-prologos-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr lookup [+key -val]\n"
      "  || \"a\" 1N\n"
      "  || \"b\" 2N\n\n"
      "eval (solve (lookup \"a\" val))\n")))
  (check-no-errors results)
  (define solve-result (last-result results))
  (check-true (string? solve-result))
  (check-equal? (count-answers solve-result) 1
                "lookup with ground key should return 1 answer"))

;; ========================================
;; 8. Multi-fact partial query: ground first arg, free second
;; ========================================

(test-case "e2e/partial-query: ground first arg filters facts"
  (define results
    (run-prologos-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr mapping [?x ?y]\n"
      "  || \"a\" \"1\"\n"
      "  || \"a\" \"2\"\n"
      "  || \"b\" \"3\"\n\n"
      "eval (solve (mapping \"a\" y))\n")))
  (check-no-errors results)
  (define solve-result (last-result results))
  (check-true (string? solve-result))
  (check-equal? (count-answers solve-result) 2
                "query mapping 'a' ?y should return 2 answers"))

;; ========================================
;; 9. Defr registration: verify defined message format
;; ========================================

(test-case "e2e/defr-registration: produces correct defined message"
  (define results
    (run-prologos-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr my-rel [?x]\n"
      "  || \"hello\"\n")))
  (check-no-errors results)
  ;; Last result should be the "defined" message
  (define def-result (last-result results))
  (check-true (string? def-result))
  (check-true (string-contains? def-result "my-rel")
              "defined message should contain the relation name")
  (check-true (string-contains? def-result "defined.")
              "defined message should end with 'defined.'"))

;; ========================================
;; 10. Clause with conjunction: multiple goals in a single &> clause
;; ========================================

(test-case "e2e/clause-conjunction: two goals in one clause"
  (define results
    (run-prologos-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr edge [?x ?y]\n"
      "  || \"a\" \"b\"\n"
      "  || \"b\" \"c\"\n"
      "  || \"c\" \"d\"\n\n"
      "defr two-hop [?x ?z]\n"
      "  &> (edge x y) (edge y z)\n\n"
      "eval (solve (two-hop \"a\" z))\n")))
  (check-no-errors results)
  (define solve-result (last-result results))
  (check-true (string? solve-result))
  ;; a->b->c is the only 2-hop path from "a"
  (check-equal? (count-answers solve-result) 1
                "two-hop from a should find exactly 1 path (a->b->c)"))

;; ========================================
;; 11. Mixed facts and clauses in a single relation
;; ========================================

(test-case "e2e/mixed-facts-clauses: facts + rule clauses"
  (define results
    (run-prologos-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr base [?x]\n"
      "  || \"alpha\"\n"
      "  || \"beta\"\n\n"
      "defr derived [?x]\n"
      "  || \"gamma\"\n"
      "  &> (base x)\n\n"
      "eval (solve (derived y))\n")))
  (check-no-errors results)
  (define solve-result (last-result results))
  (check-true (string? solve-result))
  ;; gamma (fact) + alpha (via base) + beta (via base) = 3
  (check-equal? (count-answers solve-result) 3
                "derived should find gamma + alpha + beta = 3 answers"))

;; ========================================
;; 12. Multiple fact rows: 4+ facts in a single relation
;; ========================================

(test-case "e2e/many-facts: 5 fact rows"
  (define results
    (run-prologos-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr fruit [?x]\n"
      "  || \"apple\"\n"
      "  || \"banana\"\n"
      "  || \"cherry\"\n"
      "  || \"date\"\n"
      "  || \"elderberry\"\n\n"
      "eval (solve (fruit y))\n")))
  (check-no-errors results)
  (define solve-result (last-result results))
  (check-true (string? solve-result))
  (check-equal? (count-answers solve-result) 5
                "fruit should enumerate all 5 facts"))

;; ========================================
;; 13. Ground query: all args ground, check if fact exists
;; ========================================

(test-case "e2e/ground-query: check membership succeeds"
  (define results
    (run-prologos-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr member [?x]\n"
      "  || \"alice\"\n"
      "  || \"bob\"\n\n"
      "eval (solve (member \"alice\"))\n")))
  (check-no-errors results)
  (define solve-result (last-result results))
  (check-true (string? solve-result))
  ;; Ground query with matching fact should return 1 empty-binding answer
  (check-false (string=? solve-result "nil : _")
               "ground query for existing fact should not return nil"))

(test-case "e2e/ground-query-miss: check membership fails"
  (define results
    (run-prologos-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr member [?x]\n"
      "  || \"alice\"\n"
      "  || \"bob\"\n\n"
      "eval (solve (member \"charlie\"))\n")))
  (check-no-errors results)
  (define solve-result (last-result results))
  (check-true (string? solve-result))
  (check-equal? solve-result "nil : _"
                "ground query for missing fact should return nil"))
