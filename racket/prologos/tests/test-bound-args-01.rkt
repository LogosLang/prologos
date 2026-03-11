#lang racket/base

;;;
;;; Tests for Phase 2a: Bound Variable Output
;;;
;;; Verifies that narrowing (`=` operator) and `solve` output includes
;;; bound parameter names with `_` suffix alongside solved query variables.
;;;
;;; Example: `add ?a 3N = 5N` should produce `'{:a 2N, :y_ 3N}`
;;;   - :a is the solved query variable (= 2N)
;;;   - :y_ is the bound parameter y (was passed 3N)
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
         "../reader.rkt"
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
;; 1. Narrowing: bound args with prelude functions
;; ========================================

(test-case "bound-args/narrowing: add ?a 3N = 5N shows :y_ bound arg"
  (define result
    (run-ns-ws-last "ns test\nadd ?a 3N = 5N"))
  (check-true (string? result) "should produce a string result")
  ;; Should have :a (query var) and :y_ (bound arg)
  (check-true (string-contains? result ":a")
              "should contain query var :a")
  (check-true (string-contains? result ":y_")
              "should contain bound arg :y_")
  (check-true (string-contains? result "2N")
              "query var :a should be 2N")
  (check-true (string-contains? result "3N")
              "bound arg :y_ should be 3N"))

(test-case "bound-args/narrowing: no bound args when all args are query vars"
  (define result
    (run-ns-ws-last "ns test\nadd ?a ?b = 5N"))
  (check-true (string? result) "should produce a string result")
  ;; Both args are query vars, so no bound args should appear
  (check-true (string-contains? result ":a")
              "should contain query var :a")
  (check-true (string-contains? result ":b")
              "should contain query var :b")
  ;; No _-suffixed keys expected (both args are free)
  (check-false (string-contains? result ":x_")
               "should not have :x_ bound arg")
  (check-false (string-contains? result ":y_")
               "should not have :y_ bound arg"))

(test-case "bound-args/narrowing: add 2N ?b = 5N shows :x_ bound arg"
  (define result
    (run-ns-ws-last "ns test\nadd 2N ?b = 5N"))
  (check-true (string? result) "should produce a string result")
  ;; :b is the query var, :x_ is the bound first param
  (check-true (string-contains? result ":b")
              "should contain query var :b")
  (check-true (string-contains? result ":x_")
              "should contain bound arg :x_")
  (check-true (string-contains? result "2N")
              "bound arg :x_ should be 2N"))

(test-case "bound-args/narrowing: add ?x ?y = 3N has no bound args (all query)"
  ;; Confirms that when multiple narrowing results exist, bound args
  ;; are absent because both params are query vars
  (define result
    (run-ns-ws-last "ns test\nadd ?x ?y = 3N"))
  (check-true (string? result) "should produce a string result")
  ;; 4 solutions for add ?x ?y = 3N: (0,3), (1,2), (2,1), (3,0)
  (check-true (string-contains? result ":x")
              "should contain query var :x")
  (check-true (string-contains? result ":y")
              "should contain query var :y")
  (check-false (string-contains? result ":x_")
               "no bound arg :x_ when x is query var")
  (check-false (string-contains? result ":y_")
               "no bound arg :y_ when y is query var"))

;; ========================================
;; 2. Solve: bound args with relations
;; ========================================

(test-case "bound-args/solve: ground arg shows as bound"
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
  ;; Should have :y (query var) and :a_ (bound arg = "alice")
  (check-true (string-contains? solve-result ":y")
              "should contain query var :y")
  (check-true (string-contains? solve-result ":a_")
              "should contain bound arg :a_")
  (check-true (string-contains? solve-result "\"alice\"")
              "bound arg :a_ should be \"alice\""))

(test-case "bound-args/solve: no bound args when all query vars"
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
  ;; Both args are query vars — no bound args
  (check-false (string-contains? solve-result ":a_")
               "should not have :a_ when a is a query var")
  (check-false (string-contains? solve-result ":b_")
               "should not have :b_ when b is a query var"))

(test-case "bound-args/solve: multiple ground args all shown"
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
  ;; :w is query var, :x_ and :y_ are bound
  (check-true (string-contains? solve-result ":w")
              "should contain query var :w")
  (check-true (string-contains? solve-result ":x_")
              "should contain bound arg :x_")
  (check-true (string-contains? solve-result ":y_")
              "should contain bound arg :y_"))

(test-case "bound-args/solve-one: ground arg shows as bound"
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
  ;; Should have :h (query var) and :name_ (bound arg = "red")
  (check-true (string-contains? result ":h")
              "should contain query var :h")
  (check-true (string-contains? result ":name_")
              "should contain bound arg :name_"))
