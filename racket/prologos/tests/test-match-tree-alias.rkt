#lang racket/base

;;;
;;; Tests for issue #18: compile-match-tree variable bindings in compound
;;; patterns aliased outer-param storage in recursive bodies.
;;;
;;; Bug summary
;;; -----------
;;; In a multi-clause `defn` whose pattern dispatch decomposes a compound
;;; parameter (e.g. `cons r rest`) and whose body recurses on a sub-binding
;;; (e.g. `[recurse rest]`), `compile-match-tree` lowered variable bindings
;;; to positional `let v := __cons_N` references. The field-name symbols
;;; were derived from `(format "__~a_~a" ctor i)` and shared across nested
;;; dispatch sites with the same constructor — the inner reduce-arm's
;;; binders SHADOWED the outer arm's binders, so the let-references
;;; silently re-resolved to inner (sub-list) values at runtime.
;;;
;;; The bug was silent: no error, no contradiction. `[sum-rows '[1N 2N 3N]]`
;;; quietly returned 5N instead of 6N.
;;;
;;; Fix (commit see issue #18 PR): gensym each dispatch site's field names
;;; so they are globally unique. The Racket lexical resolver then always
;;; picks up the intended outer/inner scope.
;;;
;;; Why the bug surfaces only for some shapes
;;; -----------------------------------------
;;; `dbl-all` and `last-elem` (single cons clause) do NOT trigger the bug:
;;; their inner `compile-match-tree` recursion lands on an "all-variable"
;;; row (the only specialized row), wraps via `wrap-variable-bindings`
;;; directly, and never builds an inner reduce-arm whose binders shadow
;;; the outer's. The bug requires TWO cons-shaped clauses where the inner
;;; column dispatches on a SUB-pattern of the same constructor — the
;;; canonical case is `cons r nil` + `cons r rest`.
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
;; A. Canonical reproducer from the issue
;; ========================================
;; sum-rows: nil → 0N, cons r nil → r, cons r rest → r + sum-rows(rest)
;; Pre-fix: sum-rows '[1N 2N 3N] returned 5N. Expected: 6N.

(test-case "alias/sum-rows-3-elem"
  (check-equal?
   (run-ws-last
    (string-append
     "spec sum-rows-a [List Nat] -> Nat\n"
     "defn sum-rows-a\n"
     "  | nil          -> 0N\n"
     "  | cons r nil   -> r\n"
     "  | cons r rest  -> [+ r [sum-rows-a rest]]\n"
     "eval [sum-rows-a '[1N 2N 3N]]"))
   "6N : Nat"))

(test-case "alias/sum-rows-5-elem"
  (check-equal?
   (run-ws-last
    (string-append
     "spec sum-rows-b [List Nat] -> Nat\n"
     "defn sum-rows-b\n"
     "  | nil          -> 0N\n"
     "  | cons r nil   -> r\n"
     "  | cons r rest  -> [+ r [sum-rows-b rest]]\n"
     "eval [sum-rows-b '[1N 2N 3N 4N 5N]]"))
   "15N : Nat"))

(test-case "alias/sum-rows-singleton"
  ;; Singleton dispatches to the second clause (`cons r nil`). The bug
  ;; only manifests on the third-clause path; this test confirms the
  ;; second-clause path is unchanged.
  (check-equal?
   (run-ws-last
    (string-append
     "spec sum-rows-c [List Nat] -> Nat\n"
     "defn sum-rows-c\n"
     "  | nil          -> 0N\n"
     "  | cons r nil   -> r\n"
     "  | cons r rest  -> [+ r [sum-rows-c rest]]\n"
     "eval [sum-rows-c '[42N]]"))
   "42N : Nat"))

(test-case "alias/sum-rows-empty"
  ;; nil clause unaffected by the alias bug, but covered for completeness.
  (check-equal?
   (run-ws-last
    (string-append
     "spec sum-rows-d [List Nat] -> Nat\n"
     "defn sum-rows-d\n"
     "  | nil          -> 0N\n"
     "  | cons r nil   -> r\n"
     "  | cons r rest  -> [+ r [sum-rows-d rest]]\n"
     "eval [sum-rows-d [the [List Nat] nil]]"))
   "0N : Nat"))

;; ========================================
;; B. List length with the same alias-shape
;; ========================================
;; Pre-fix: my-length '[1N 2N 3N] returned 2N. Expected: 3N.

(test-case "alias/my-length-3-elem"
  (check-equal?
   (run-ws-last
    (string-append
     "spec my-length-a [List Nat] -> Nat\n"
     "defn my-length-a\n"
     "  | nil          -> 0N\n"
     "  | cons _ nil   -> 1N\n"
     "  | cons _ rest  -> [+ 1N [my-length-a rest]]\n"
     "eval [my-length-a '[1N 2N 3N]]"))
   "3N : Nat"))

(test-case "alias/my-length-7-elem"
  (check-equal?
   (run-ws-last
    (string-append
     "spec my-length-b [List Nat] -> Nat\n"
     "defn my-length-b\n"
     "  | nil          -> 0N\n"
     "  | cons _ nil   -> 1N\n"
     "  | cons _ rest  -> [+ 1N [my-length-b rest]]\n"
     "eval [my-length-b '[1N 2N 3N 4N 5N 6N 7N]]"))
   "7N : Nat"))

;; ========================================
;; C. Filter / accumulator: head-bind correctness
;; ========================================
;; Variant where `r` (the head binding) is consumed alongside the
;; recursive call on `rest`. If the field-name aliasing were still
;; live, `r` would bind to the wrong element (off-by-one).

(test-case "alias/sum-rows-confirms-head-binding"
  ;; sum-rows '[10N 20N 30N] = 60N. If r bound to the inner head (20N
  ;; for a 3-element list), the result would be 20+30 = 50N. If r bound
  ;; to the inner head (20N for a 3-elem list with rest=[30N]), the
  ;; recursive call would also be wrong → 20 + 30 = 50N. Verifying 60N
  ;; pins both head and tail to the correct outer values.
  (check-equal?
   (run-ws-last
    (string-append
     "spec sum-rows-h [List Nat] -> Nat\n"
     "defn sum-rows-h\n"
     "  | nil          -> 0N\n"
     "  | cons r nil   -> r\n"
     "  | cons r rest  -> [+ r [sum-rows-h rest]]\n"
     "eval [sum-rows-h '[10N 20N 30N]]"))
   "60N : Nat"))

;; ========================================
;; D. Triple-nested decomposition
;; ========================================
;; Two cons clauses where the inner column dispatches further on a
;; nested cons (the second-clause's `cons _ nil` already dispatches
;; the rest's structure; here we add a third level).

(test-case "alias/three-arm-pairs-then-rest"
  ;; defn classify
  ;;   | nil                       -> 0N
  ;;   | cons _ nil                -> 1N         ;; one element
  ;;   | cons _ [cons _ nil]       -> 2N         ;; two elements
  ;;   | cons _ [cons _ rest]      -> [+ 2N [classify rest]]  ;; ≥ 2 elements + recurse
  (check-equal?
   (run-ws-last
    (string-append
     "spec classify-a [List Nat] -> Nat\n"
     "defn classify-a\n"
     "  | nil                  -> 0N\n"
     "  | cons _ nil           -> 1N\n"
     "  | cons _ [cons _ nil]  -> 2N\n"
     "  | cons _ [cons _ rest] -> [+ 2N [classify-a rest]]\n"
     "eval [classify-a '[1N 2N 3N 4N]]"))
   "4N : Nat"))

;; ========================================
;; E. Edge case: shadowed variable name `rest` in two clauses
;; ========================================
;; Both cons clauses bind a variable named `rest`. Only one is recursive;
;; the alias bug, if present, would surface as wrong values regardless
;; of the lexical name chosen.

(test-case "alias/shadowed-rest-name"
  ;; Same name `rest` in two clauses; only the third recurses.
  (check-equal?
   (run-ws-last
    (string-append
     "spec last-or-zero [List Nat] -> Nat\n"
     "defn last-or-zero\n"
     "  | nil           -> 0N\n"
     "  | cons r nil    -> r\n"
     "  | cons _ rest   -> [last-or-zero rest]\n"
     "eval [last-or-zero '[7N 8N 9N]]"))
   "9N : Nat"))

;; ========================================
;; F. Recursive map (cons head reconstruction)
;; ========================================
;; Doubles every element. This SHAPE (single cons clause) is unaffected
;; by the bug and serves as a regression check that the gensym fix
;; doesn't break the simpler path.

(test-case "alias/dbl-all-regression"
  (check-equal?
   (run-ws-last
    (string-append
     "spec dbl-all-a [List Nat] -> [List Nat]\n"
     "defn dbl-all-a\n"
     "  | nil          -> [the [List Nat] nil]\n"
     "  | cons x rest  -> [cons [+ x x] [dbl-all-a rest]]\n"
     "eval [dbl-all-a '[1N 2N 3N]]"))
   "'[2N 4N 6N] : [prologos::data::list::List Nat]"))

;; ========================================
;; G. Non-recursive compound patterns (regression coverage)
;; ========================================
;; Verify the fix does not affect pattern dispatch that doesn't recurse.

(test-case "alias/non-recursive-pair-classify"
  ;; Single-level dispatch on cons; head value is the answer. No
  ;; recursion through `rest`, so no nested cons reduce-arm — but the
  ;; field-name gensym applies regardless. Regression check.
  (check-equal?
   (run-ws-last
    (string-append
     "spec head-or-zero [List Nat] -> Nat\n"
     "defn head-or-zero\n"
     "  | nil          -> 0N\n"
     "  | cons h _     -> h\n"
     "eval [head-or-zero '[100N 200N 300N]]"))
   "100N : Nat"))

(test-case "alias/non-recursive-second-element"
  ;; Two-level dispatch but no recursion: pull the second element if
  ;; present. Exercises nested cons reduce-arm without a recursive call.
  (check-equal?
   (run-ws-last
    (string-append
     "spec second-or-zero [List Nat] -> Nat\n"
     "defn second-or-zero\n"
     "  | nil                  -> 0N\n"
     "  | cons _ nil           -> 0N\n"
     "  | cons _ [cons s _]    -> s\n"
     "eval [second-or-zero '[1N 2N 3N]]"))
   "2N : Nat"))

;; ========================================
;; H. Larger payload, deeper recursion
;; ========================================
;; Stress the fix on a longer list. If the alias bug were still live,
;; the off-by-one would compound with depth.

(test-case "alias/sum-rows-10-elem"
  (check-equal?
   (run-ws-last
    (string-append
     "spec sum-rows-l [List Nat] -> Nat\n"
     "defn sum-rows-l\n"
     "  | nil          -> 0N\n"
     "  | cons r nil   -> r\n"
     "  | cons r rest  -> [+ r [sum-rows-l rest]]\n"
     "eval [sum-rows-l '[1N 2N 3N 4N 5N 6N 7N 8N 9N 10N]]"))
   "55N : Nat"))

;; ========================================
;; I. Multi-arg defn with compound patterns on both args
;; ========================================
;; Exercises the alias path under a multi-arg shape: TWO compound
;; parameters, both with the same constructor (cons) at multiple
;; clauses. The fix must keep field-names per-arg distinct as well.

(test-case "alias/multiarg-zip-sum"
  ;; zip-sum xs ys: pairwise add until either runs out.
  ;;   | nil          ys           -> 0N
  ;;   | xs           nil          -> 0N
  ;;   | [cons x xr]  [cons y yr]  -> [+ [+ x y] [zip-sum xr yr]]
  (check-equal?
   (run-ws-last
    (string-append
     "spec zip-sum-a [List Nat] -> [List Nat] -> Nat\n"
     "defn zip-sum-a\n"
     "  | nil          ys           -> 0N\n"
     "  | xs           nil          -> 0N\n"
     "  | [cons x xr]  [cons y yr]  -> [+ [+ x y] [zip-sum-a xr yr]]\n"
     "eval [zip-sum-a '[1N 2N 3N] '[10N 20N 30N]]"))
   "66N : Nat"))
