#lang racket/base

;;;
;;; Tests for compile-match-tree field-name aliasing (issue #18).
;;;
;;; Pre-fix: a multi-clause `defn` whose pattern decomposes a compound
;;; parameter (e.g. `cons r rest`) and whose body recurses on a sub-binding
;;; produced silent wrong results when a sibling clause further dispatched
;;; the same constructor (e.g. `cons r nil` alongside `cons r rest`).
;;;
;;; The compiler generated field-binding names from (ctor-name + index)
;;; only — "__cons_0", "__cons_1" — so a second dispatch on the same
;;; constructor lexically shadowed the outer dispatch's bindings, and
;;; let-bindings created BEFORE the inner dispatch silently re-aliased to
;;; the inner scrutinee's components.
;;;
;;; Fix: gensym the field names per dispatch site (commit 6d5f9d1).
;;;
;;; All tests use the bracketed pattern form `[[cons r rest]]`. The
;;; bare-token form (`| cons r rest`) is a separate parser concern
;;; tracked in PR #16/#17 and out of scope here.
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
         "../parse-reader.rkt"
         "../multi-dispatch.rkt")

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
    (process-string "(ns test-match-tree-alias)")
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-bundle-registry))))

;; Run WS code via temp file using shared environment
(define (run-ws s)
  (define tmp (make-temporary-file "match-tree-alias-~a.prologos"))
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

;; ========================================
;; A. The original reproducer
;; ========================================

(test-case "issue-18/sum-rows-3-clause-recursive (alias trigger)"
  ;; Three clauses force the inner cons dispatch. Pre-fix: 5N. Post-fix: 6N.
  (check-equal?
   (run-ws-last
    (string-append
     "spec sum-rows [List Nat] -> Nat\n"
     "defn sum-rows\n"
     "  | [nil]            -> 0N\n"
     "  | [[cons r nil]]   -> r\n"
     "  | [[cons r rest]]  -> [+ r [sum-rows rest]]\n"
     "[sum-rows '[1N 2N 3N]]\n"))
   "6N : Nat"))

(test-case "issue-18/sum-rows-larger-input"
  (check-equal?
   (run-ws-last
    (string-append
     "spec sum-rows [List Nat] -> Nat\n"
     "defn sum-rows\n"
     "  | [nil]            -> 0N\n"
     "  | [[cons r nil]]   -> r\n"
     "  | [[cons r rest]]  -> [+ r [sum-rows rest]]\n"
     "[sum-rows '[1N 2N 3N 4N 5N]]\n"))
   "15N : Nat"))

(test-case "issue-18/sum-rows-single-element"
  ;; Hits the `cons r nil` arm directly — must return r.
  (check-equal?
   (run-ws-last
    (string-append
     "spec sum-rows [List Nat] -> Nat\n"
     "defn sum-rows\n"
     "  | [nil]            -> 0N\n"
     "  | [[cons r nil]]   -> r\n"
     "  | [[cons r rest]]  -> [+ r [sum-rows rest]]\n"
     "[sum-rows '[42N]]\n"))
   "42N : Nat"))

(test-case "issue-18/sum-rows-empty"
  (check-equal?
   (run-ws-last
    (string-append
     "spec sum-rows [List Nat] -> Nat\n"
     "defn sum-rows\n"
     "  | [nil]            -> 0N\n"
     "  | [[cons r nil]]   -> r\n"
     "  | [[cons r rest]]  -> [+ r [sum-rows rest]]\n"
     "[sum-rows '[]]\n"))
   "0N : Nat"))

;; ========================================
;; B. Length-style traversal idioms
;; ========================================

(test-case "issue-18/my-length-3-clause"
  ;; Wildcard heads + recursion under same dispatch.
  (check-equal?
   (run-ws-last
    (string-append
     "spec my-length [List Nat] -> Nat\n"
     "defn my-length\n"
     "  | [nil]            -> 0N\n"
     "  | [[cons _ nil]]   -> 1N\n"
     "  | [[cons _ rest]]  -> [suc [my-length rest]]\n"
     "[my-length '[10N 20N 30N 40N]]\n"))
   "4N : Nat"))

(test-case "issue-18/sum-uses-head-in-recursion"
  ;; Forces the head binding `r` to flow through the recursion result —
  ;; verifies r is the OUTER cons-head, not the inner.
  (check-equal?
   (run-ws-last
    (string-append
     "spec product-rows [List Nat] -> Nat\n"
     "defn product-rows\n"
     "  | [nil]            -> 1N\n"
     "  | [[cons r nil]]   -> r\n"
     "  | [[cons r rest]]  -> [* r [product-rows rest]]\n"
     "[product-rows '[2N 3N 4N]]\n"))
   "24N : Nat"))

;; ========================================
;; C. Regression control: 2-clause form (alias does not trigger)
;; ========================================

(test-case "issue-18/sum-list-2-clause (alias does not trigger)"
  ;; Without the middle `cons r nil` clause, there's no second dispatch on
  ;; the same ctor. This MUST still work — it's the canonical recursive
  ;; pattern and the most common shape in the prelude.
  (check-equal?
   (run-ws-last
    (string-append
     "spec sum-list [List Nat] -> Nat\n"
     "defn sum-list\n"
     "  | [nil]            -> 0N\n"
     "  | [[cons r rest]]  -> [+ r [sum-list rest]]\n"
     "[sum-list '[1N 2N 3N 4N 5N]]\n"))
   "15N : Nat"))

(test-case "issue-18/length-2-clause (alias does not trigger)"
  (check-equal?
   (run-ws-last
    (string-append
     "spec my-length [List Nat] -> Nat\n"
     "defn my-length\n"
     "  | [nil]            -> 0N\n"
     "  | [[cons _ rest]]  -> [suc [my-length rest]]\n"
     "[my-length '[10N 20N 30N]]\n"))
   "3N : Nat"))

;; ========================================
;; D. Shadowed variable names across clauses
;; ========================================

(test-case "issue-18/shadowed-name-rest"
  ;; The variable name 'r' bound in two clauses with different roles —
  ;; head in one (inner cons), unused in another. Must not cross-pollute.
  (check-equal?
   (run-ws-last
    (string-append
     "spec sum-or-zero [List Nat] -> Nat\n"
     "defn sum-or-zero\n"
     "  | [nil]            -> 0N\n"
     "  | [[cons r nil]]   -> r\n"
     "  | [[cons r rest]]  -> [+ r [sum-or-zero rest]]\n"
     "[sum-or-zero '[7N]]\n"))
   "7N : Nat"))

(test-case "issue-18/same-name-in-cons-and-cons-r-nil"
  ;; Variable 'r' has the SAME name in both clauses — both pre-fix it
  ;; would still bind to __cons_0; with the inner dispatch on cons in
  ;; the third clause, the alias is what corrupted the result.
  (check-equal?
   (run-ws-last
    (string-append
     "spec second [List Nat] -> Nat\n"
     "defn second\n"
     "  | [nil]                        -> 0N\n"
     "  | [[cons _ nil]]               -> 0N\n"
     "  | [[cons _ [cons r _]]]        -> r\n"
     "  | [[cons _ [cons r rest]]]     -> r\n"
     "[second '[10N 20N 30N 40N]]\n"))
   "20N : Nat"))

;; ========================================
;; E. Deeper nested decomposition
;; ========================================

(test-case "issue-18/deeper-nesting-three-deep"
  ;; Three-level deep cons dispatch via explicit nested patterns — exercises
  ;; the alias mechanism three deep.
  (check-equal?
   (run-ws-last
    (string-append
     "spec take3-sum [List Nat] -> Nat\n"
     "defn take3-sum\n"
     "  | [nil]                         -> 0N\n"
     "  | [[cons a nil]]                -> a\n"
     "  | [[cons a [cons b nil]]]       -> [+ a b]\n"
     "  | [[cons a [cons b [cons c _]]]] -> [+ a [+ b c]]\n"
     "[take3-sum '[1N 2N 3N 4N 5N]]\n"))
   "6N : Nat"))

;; ========================================
;; F. Non-recursive multi-clause with multiple ctors
;; ========================================

(test-case "issue-18/non-recursive-three-clauses (regression)"
  ;; Multi-clause defn on different ctor patterns at the same column —
  ;; alias does not trigger, just verifies normal dispatch still works.
  (check-equal?
   (run-ws-last
    (string-append
     "spec describe [List Nat] -> Nat\n"
     "defn describe\n"
     "  | [nil]            -> 0N\n"
     "  | [[cons _ nil]]   -> 1N\n"
     "  | [[cons _ _]]     -> 2N\n"
     "[describe '[5N 6N 7N]]\n"))
   "2N : Nat"))

(test-case "issue-18/non-recursive-single-elem (regression)"
  (check-equal?
   (run-ws-last
    (string-append
     "spec describe [List Nat] -> Nat\n"
     "defn describe\n"
     "  | [nil]            -> 0N\n"
     "  | [[cons _ nil]]   -> 1N\n"
     "  | [[cons _ _]]     -> 2N\n"
     "[describe '[5N]]\n"))
   "1N : Nat"))

(test-case "issue-18/non-recursive-empty (regression)"
  (check-equal?
   (run-ws-last
    (string-append
     "spec describe [List Nat] -> Nat\n"
     "defn describe\n"
     "  | [nil]            -> 0N\n"
     "  | [[cons _ nil]]   -> 1N\n"
     "  | [[cons _ _]]     -> 2N\n"
     "[describe '[]]\n"))
   "0N : Nat"))

;; ========================================
;; G. Nat dispatch (different ctor — sanity)
;; ========================================

(test-case "issue-18/nat-dispatch-suc-zero (regression)"
  ;; Nat addition with zero/suc dispatch — the alias mechanism would only
  ;; trigger on doubly-nested suc decomposition. This is a regression
  ;; control: the non-aliasing case still works.
  (check-equal?
   (run-ws-last
    (string-append
     "spec addp Nat -> Nat -> Nat\n"
     "defn addp\n"
     "  | [zero n]      -> n\n"
     "  | [[suc m] n]   -> [suc [addp m n]]\n"
     "[addp 2N 3N]\n"))
   "5N : Nat"))
