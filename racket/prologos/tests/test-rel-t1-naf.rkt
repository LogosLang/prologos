#lang racket/base

;;;
;;; Rel Track 1 — Aspect-A (NAF/guard correctness) tests.
;;;
;;; A.1: a top-level bare `not` goal now RUNS via the DFS engine instead of
;;;      being echoed unevaluated (reduction.rkt run-solve-goal/-one/-explain).
;;;
;;; Grows as A.2 (per-binding belief-clear), A.3 (static floundering gate),
;;; and A.4 (guard) land. E2E fixture mirrors test-relational-e2e.rkt.
;;;

(require rackunit
         racket/list
         racket/string
         racket/path
         racket/file
         "../driver.rkt"
         "../errors.rkt"
         "../namespace.rkt"
         "../relations.rkt")

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

;; Run a .prologos string through the full pipeline; return result strings.
(define (run-prologos-string content)
  (define tmp (make-temporary-file "rel-t1-~a.prologos"))
  (call-with-output-file tmp
    (lambda (out) (display content out))
    #:exists 'truncate)
  (define results
    (parameterize ([current-ns-context #f]
                   [current-module-registry (hasheq)]
                   [current-lib-paths (list lib-dir)]
                   [current-relation-store (make-relation-store)])
      (install-module-loader!)
      (process-file (path->string tmp))))
  (delete-file tmp)
  results)

(define (last-result results) (last results))

;; A small vehicle/license world reused across cases.
(define world
  (string-append
   "ns t :no-prelude\n\n"
   "defr vehicle [?type]\n  || \"bicycle\"\n     \"automobile\"\n\n"
   "defr license [?v]\n  || \"automobile\"\n\n"))

;; ========================================
;; A.1 — top-level bare `not` goal runs (was echoed)
;; ========================================

(test-case "A.1: solve (not G) for an UNLICENSED ground arg — NAF succeeds, not echoed"
  (define results
    (run-prologos-string
     (string-append world "eval (solve (not (license \"bicycle\")))\n")))
  (define r (last-result results))
  (check-true (string? r))
  ;; the echo would have printed the goal back: "(solve (not (license ...)))"
  (check-false (string-contains? r "solve")
               "top-level (not G) must not be echoed unevaluated")
  ;; bicycle is not licensed => NAF succeeds => one empty-binding answer {}
  (check-true (string-contains? r "{}")
              "NAF over an unlicensed ground arg should succeed with an empty answer"))

(test-case "A.1: solve (not G) for a LICENSED ground arg — NAF fails (nil), not echoed"
  (define results
    (run-prologos-string
     (string-append world "eval (solve (not (license \"automobile\")))\n")))
  (define r (last-result results))
  (check-true (string? r))
  (check-false (string-contains? r "solve")
               "top-level (not G) must not be echoed unevaluated")
  (check-true (string-contains? r "nil")
              "NAF over a licensed ground arg should fail (nil)"))

(test-case "A.1: solve-one (not G) — runs, returns none for a failed NAF"
  (define results
    (run-prologos-string
     (string-append world "eval (solve-one (not (license \"automobile\")))\n")))
  (define r (last-result results))
  (check-true (string? r))
  (check-false (string-contains? r "solve-one")
               "top-level solve-one (not G) must not be echoed unevaluated")
  (check-true (string-contains? r "none")
              "solve-one of a failed NAF should be none"))

;; ========================================
;; A.2 — clause-body NAF per-binding belief-clear (FACT generator)
;; ========================================

(test-case "A.2: clause-body NAF over a FACT generator — only the unblocked binding survives"
  ;; light-vehicle(v) :- vehicle(v), not(license(v))
  ;; vehicle={bicycle,automobile}, license={automobile} => {bicycle} only.
  ;; Pre-A.2 the single-shared-bit collapse over-included BOTH ({both}).
  (define results
    (run-prologos-string
     (string-append world
       "defr light-vehicle [?v]\n  &> (vehicle v) (not (license v))\n\n"
       "eval (solve (light-vehicle lv))\n")))
  (define r (last-result results))
  (check-true (string? r))
  (check-true (string-contains? r "bicycle")
              "the unlicensed vehicle should be in the solution")
  (check-false (string-contains? r "automobile")
               "the licensed vehicle must NOT leak (A.2 per-binding belief-clear)"))

(test-case "A.2: ground clause-body NAF queries route to DFS and stay correct"
  (define results
    (run-prologos-string
     (string-append world
       "defr light-vehicle [?v]\n  &> (vehicle v) (not (license v))\n\n"
       "eval (solve (light-vehicle \"bicycle\"))\n"      ;; unlicensed => succeeds
       "eval (solve (light-vehicle \"automobile\"))\n"))) ;; licensed => fails
  (check-true (>= (length results) 2))
  (define bicycle-r (list-ref results (- (length results) 2)))
  (define auto-r (last results))
  (check-true (string-contains? bicycle-r "{}")
              "ground unlicensed vehicle succeeds")
  (check-true (string-contains? auto-r "nil")
              "ground licensed vehicle fails"))

