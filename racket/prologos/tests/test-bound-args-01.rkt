#lang racket/base

;;;
;;; Solution-shape negative gate (CIU T6 F1b.1 / D25)
;;;
;;; HISTORY: this file was born as the Phase 2a "bound variable output" test,
;;; asserting that narrowing (`=`) and `solve` output ECHOED ground call-site
;;; values under '_'-suffixed param-name keys (e.g. `add ?a 3N = 5N` =>
;;; `'{:a 2N, :y_ 3N}`). D25 DELETED that echo: solution maps carry ONLY
;;; query-var keys. The file is now the INVERTED gate — the same scenarios
;;; assert the echo keys are ABSENT (protecting against echo resurrection) —
;;; plus the D25.4 solve-one bare-map/none shape gate and the D25.2 explain
;;; reserved-key clobber guard.
;;;
;;; Example: `add ?a 3N = 5N` produces `'[{:a 2N}]` — no :y_, no echoed 3N.
;;;

(require rackunit
         racket/list
         racket/string
         racket/path
         racket/file
         racket/port
         "test-support.rkt"
         "../driver.rkt"
         "../errors.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../metavar-store.rkt"
         "../relations.rkt"
         "../trait-resolution.rkt"
         "../parse-reader.rkt"
         "../macros.rkt")

;; ========================================
;; Infrastructure for relational tests (needs relation-store)
;; ========================================

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

;; Run a :no-prelude .prologos string through the full pipeline with relation store.
(define (run-rel-string content)
  (define tmp (make-temporary-file "bound-args-~a.prologos"))
  (call-with-output-file tmp
    (lambda (out) (display content out))
    #:exists 'truncate)
  (define results
    (parameterize ([current-ns-context #f]
                   [current-module-registry (hasheq)]
                   [current-lib-paths (list lib-dir)]
                   [current-relation-store (make-relation-store)]
                   [current-preparse-registry (current-preparse-registry)]
                   [current-trait-registry (current-trait-registry)]
                   [current-impl-registry (current-impl-registry)]
                   [current-param-impl-registry (current-param-impl-registry)]
                   [current-bundle-registry (current-bundle-registry)]
                   [current-defn-param-names (hasheq)])
      (install-module-loader!)
      (process-file (path->string tmp))))
  (delete-file tmp)
  results)

(define (last-result results)
  (last results))

(define (check-no-errors results)
  (for ([r (in-list results)])
    (when (prologos-error? r)
      (fail (format "Unexpected error: ~a" (prologos-error-message r))))))

;; ========================================
;; 1. Narrowing: solutions carry query-var keys ONLY (echo keys absent)
;; ========================================

(test-case "solution-shape/narrowing: add ?a 3N = 5N carries :a only (no :y_ echo)"
  (define result
    (run-ns-ws-last "ns test\nadd ?a 3N = 5N"))
  (check-true (string? result) "should produce a string result")
  (check-true (string-contains? result ":a")
              "should contain query var :a")
  (check-true (string-contains? result "2N")
              "query var :a should be 2N")
  (check-false (string-contains? result ":y_")
               "the :y_ bound-arg echo must NOT resurface (D25)")
  (check-false (string-contains? result "3N")
               "the echoed ground value 3N must NOT appear in the solution"))

(test-case "solution-shape/narrowing: no echo keys when all args are query vars"
  (define result
    (run-ns-ws-last "ns test\nadd ?a ?b = 5N"))
  (check-true (string? result) "should produce a string result")
  (check-true (string-contains? result ":a")
              "should contain query var :a")
  (check-true (string-contains? result ":b")
              "should contain query var :b")
  (check-false (string-contains? result ":x_")
               "should not have :x_ echo key")
  (check-false (string-contains? result ":y_")
               "should not have :y_ echo key"))

(test-case "solution-shape/narrowing: add 2N ?b = 5N carries :b only (no :x_ echo)"
  (define result
    (run-ns-ws-last "ns test\nadd 2N ?b = 5N"))
  (check-true (string? result) "should produce a string result")
  (check-true (string-contains? result ":b")
              "should contain query var :b")
  (check-true (string-contains? result "3N")
              "query var :b should be 3N")
  (check-false (string-contains? result ":x_")
               "the :x_ bound-arg echo must NOT resurface (D25)")
  (check-false (string-contains? result "2N")
               "the echoed ground value 2N must NOT appear in the solution"))

(test-case "solution-shape/narrowing: add ?x ?y = 3N has no echo keys (all query)"
  (define result
    (run-ns-ws-last "ns test\nadd ?x ?y = 3N"))
  (check-true (string? result) "should produce a string result")
  ;; 4 solutions for add ?x ?y = 3N: (0,3), (1,2), (2,1), (3,0)
  (check-true (string-contains? result ":x")
              "should contain query var :x")
  (check-true (string-contains? result ":y")
              "should contain query var :y")
  (check-false (string-contains? result ":x_")
               "no echo key :x_")
  (check-false (string-contains? result ":y_")
               "no echo key :y_"))

;; ========================================
;; 2. Solve: solutions carry query-var keys ONLY
;; ========================================

(test-case "solution-shape/solve: ground arg does NOT echo into solutions"
  (define results
    (run-rel-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr parent [?a ?b]\n"
      "  || \"alice\" \"bob\"\n"
      "  || \"alice\" \"charlie\"\n"
      "  || \"bob\" \"dave\"\n\n"
      "eval (solve (parent \"alice\" y))\n")))
  (check-no-errors results)
  (define solve-result (last-result results))
  (check-true (string? solve-result)
              "solve result should be a string")
  (check-true (string-contains? solve-result ":y")
              "should contain query var :y")
  (check-true (string-contains? solve-result "\"bob\"")
              "solutions should contain the answer \"bob\"")
  (check-true (string-contains? solve-result "\"charlie\"")
              "solutions should contain the answer \"charlie\"")
  (check-false (string-contains? solve-result ":a_")
               "the :a_ bound-arg echo must NOT resurface (D25)")
  (check-false (string-contains? solve-result "\"alice\"")
               "the echoed ground value \"alice\" must NOT appear in solutions"))

(test-case "solution-shape/solve: no echo keys when all query vars"
  (define results
    (run-rel-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr parent [?a ?b]\n"
      "  || \"alice\" \"bob\"\n"
      "  || \"bob\" \"carol\"\n\n"
      "eval (solve (parent x y))\n")))
  (check-no-errors results)
  (define solve-result (last-result results))
  (check-true (string? solve-result)
              "solve result should be a string")
  (check-false (string-contains? solve-result ":a_")
               "should not have :a_ echo key")
  (check-false (string-contains? solve-result ":b_")
               "should not have :b_ echo key"))

(test-case "solution-shape/solve: multiple ground args — none echo"
  (define results
    (run-rel-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr triple [?x ?y ?z]\n"
      "  || \"a\" \"b\" \"c\"\n"
      "  || \"a\" \"b\" \"d\"\n\n"
      ;; Two ground args, one query var
      "eval (solve (triple \"a\" \"b\" w))\n")))
  (check-no-errors results)
  (define solve-result (last-result results))
  (check-true (string? solve-result)
              "solve result should be a string")
  (check-true (string-contains? solve-result ":w")
              "should contain query var :w")
  (check-false (string-contains? solve-result ":x_")
               "the :x_ echo must NOT resurface")
  (check-false (string-contains? solve-result ":y_")
               "the :y_ echo must NOT resurface"))

;; ========================================
;; 3. solve-one: BARE solution map (D25.4) — no some-wrap, no echo, none on miss
;; ========================================

(test-case "solution-shape/solve-one: bare solution map, no some-wrap, no echo"
  (define results
    (run-rel-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr color [?name ?hex]\n"
      "  || \"red\" \"#ff0000\"\n"
      "  || \"green\" \"#00ff00\"\n"
      "  || \"blue\" \"#0000ff\"\n\n"
      "eval (solve-one (color \"red\" h))\n")))
  (check-no-errors results)
  (define result (last-result results))
  (check-true (string? result)
              "solve-one result should be a string")
  (check-true (string-contains? result "{:h")
              "solve-one should return the BARE solution map (D25.4)")
  (check-true (string-contains? result "\"#ff0000\"")
              "the solution value should be present")
  (check-false (string-contains? result "some")
               "the some-wrapper must NOT resurface (D25.4)")
  (check-false (string-contains? result ":name_")
               "the :name_ bound-arg echo must NOT resurface (D25)"))

(test-case "solution-shape/solve-one: no solution yields none (never {})"
  (define results
    (run-rel-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr color [?name ?hex]\n"
      "  || \"red\" \"#ff0000\"\n\n"
      "eval (solve-one (color \"magenta\" h))\n")))
  (check-no-errors results)
  (define result (last-result results))
  (check-true (string? result)
              "solve-one result should be a string")
  (check-true (string-contains? result "none")
              "no-solution should be none")
  (check-false (string-contains? result "{")
               "no-solution must NOT be a map — {} is a legitimate empty dyn row (D17)"))

;; ========================================
;; 4. Explain: no echo keys; reserved-key clobber guard (D25.2)
;; ========================================

(test-case "solution-shape/explain: bindings + metadata, no echo keys"
  (define results
    (run-rel-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr parent [?a ?b]\n"
      "  || \"alice\" \"bob\"\n\n"
      "eval (explain (parent \"alice\" who))\n")))
  (check-no-errors results)
  (define result (last-result results))
  (check-true (string? result)
              "explain result should be a string")
  (check-true (string-contains? result ":who")
              "should contain the query var :who")
  (check-true (string-contains? result "\"bob\"")
              "should contain the answer")
  (check-true (string-contains? result ":provenance")
              "default semantics attaches :provenance metadata")
  (check-false (string-contains? result ":a_")
               "the :a_ bound-arg echo must NOT resurface on the explain path"))

(test-case "solution-shape/explain: a query var named 'provenance' is NOT clobbered by metadata"
  ;; D25.2 interim guard: reserved metadata keys (:certainty/:cycle/:provenance)
  ;; skip insertion when a query var claims the name — the user's binding wins.
  ;; :provenance is the LIVE reserved key under default semantics; :certainty
  ;; and :cycle (WF semantics) ride the identical memq guard in
  ;; answer-result->prologos-expr.
  (define results
    (run-rel-string
     (string-append
      "ns test :no-prelude\n\n"
      "defr parent [?a ?b]\n"
      "  || \"alice\" \"bob\"\n\n"
      "eval (explain (parent \"alice\" provenance))\n")))
  (check-no-errors results)
  (define result (last-result results))
  (check-true (string? result)
              "explain result should be a string")
  (check-true (string-contains? result "\"bob\"")
              "the USER's binding for the var named 'provenance' must survive")
  (check-false (string-contains? result ":clause-id")
               "the provenance metadata map must be SKIPPED on name collision"))
