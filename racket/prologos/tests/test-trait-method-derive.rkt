#lang racket/base

;;;
;;; Numerics N6d-i: auto-derived bare-name constrained method wrappers.
;;;
;;; `trait T {A}` with method `m : ... A ...(arg position)` now derives a
;;; top-level generic `m` (the accessor's type + body under the bare name)
;;; plus a bare-name spec entry whose where-constraints drive call-site
;;; implicit-hole insertion (type vars + dict). Bare method calls resolve
;;; their instance from argument types — no dict ceremony.
;;;
;;; Rule: derive iff EVERY trait param occurs in a domain position.
;;; Constants (zero/one/top) + output-only methods (from/from-integer/...)
;;; are excluded structurally. Skip-set {add sub join reduce} protects
;;; existing bindings (DEFERRED.md § "Numerics N6d-i follow-ups").
;;; Cross-module exposure: spec propagation is refer-gated, so the derived
;;; names were added to the curated prelude refers (namespace.rkt).
;;;

(require rackunit
         racket/list
         racket/string
         racket/runtime-path
         "test-support.rkt"
         "../driver.rkt")

(define-runtime-path derive-fixture "trait-derive-fixture.prologos")

(define (check-has actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "expected ~s to contain ~s" actual substr))))

;; One env load: prelude-derived wrappers (cross-module spec propagation).
;; NOTE: local trait+impl declarations don't parse in string mode (L2) —
;; a pre-existing multi-line impl limitation — so local-trait derive
;; coverage runs at L3 via the fixture file (LAST test in this module:
;; process-file pollutes the global context-cell; see memory/testing notes).
(define results
  (run-ns-ws-all
   (string-join
    (list
     "ns t"
     "eval [mul 3 4]"
     "eval [mul 1.5 2.0]"
     "eval [eq? 3 3]"
     "eval [eq? 3 4]"
     "eval [compare 1 2]"
     "eval [neg 5]"
     ;; skip-set: list's reduce is NOT clobbered by Reducible's method
     "eval [reduce int+ 0 '[1 2 3]]"
     ;; skip-set: string-ops `join` is NOT clobbered by the Monoid-ish method.
     ;;
     ;; ⚠ ADDED 2026-08-03 BECAUSE THE SUITE DID NOT COVER IT. A per-method
     ;; A/B of the skip set (lift one, run the 24 affected files) reported
     ;; `join` and `reduce` as both liftable — and `join` is NOT: with it
     ;; lifted, `[join "-" '["x" "y"]]` fails outright with "Could not infer
     ;; type" and cascades to "Unbound variable". The green suite said
     ;; otherwise because nothing in it called `join` at all.
     ;;
     ;; This is the case that makes the skip-set entry's own reason for
     ;; `join` ("string-ops join — spec clobber; heavily used") executable
     ;; instead of a comment. `reduce`'s neighbour above does NOT do that job:
     ;; verified by A/B, `[reduce int+ 0 '[1 2 3]]` is byte-identical with the
     ;; reduce skip lifted, so it protects nothing.
     "eval [join \"-\" '[\"x\" \"y\"]]"
     ;; …and the other two hand-listed skips, for the same reason. The skip set
     ;; became MOSTLY COMPUTED on 2026-08-03 — `derivable-method?` now declines
     ;; to derive over a name something else already binds, which replaced
     ;; `add`/`sub`/`reduce` in the hand list. These four calls were verified
     ;; byte-identical against the pre-change baseline; pinning them is what
     ;; makes "the guard replaced the list without changing anything" a fact
     ;; rather than a claim.
     "eval [add 2N 3N]"
     "eval [sub 5N 2N]")
    "\n")))

(define (evals-only rs)
  ;; keep only "value : Type" result strings (drop "... defined." lines)
  (filter (lambda (r) (and (string? r) (not (string-contains? r "defined."))))
          rs))

(define ev (evals-only results))

(test-case "derive/prelude-methods-bare-callable"
  (check-equal? (list-ref ev 0) "12 : Int")
  (check-equal? (list-ref ev 1) "3.0 : Posit32")
  (check-equal? (list-ref ev 2) "true : Bool")
  (check-equal? (list-ref ev 3) "false : Bool")
  (check-has    (list-ref ev 4) "lt-ord")
  (check-equal? (list-ref ev 5) "-5 : Int"))

(test-case "derive/skip-set-preserves-list-reduce"
  ;; NOTE: this one is a documentation pin, not a guard — A/B shows it passes
  ;; with the `reduce` skip lifted too. The guard that bites is the `join` one
  ;; below.
  (check-equal? (list-ref ev 6) "6 : Int"))

(test-case "derive/skip-set-preserves-string-join"
  ;; THE guard. Lifting `join` from the skip set breaks this outright, and
  ;; nothing else in the suite notices. It is also the ONE skip that cannot be
  ;; computed away: when its trait is processed, `string-ops` has not loaded,
  ;; so there is no binding for `derivable-method?`'s guard to see.
  (check-equal? (list-ref ev 7) "\"x-y\" : String"))

(test-case "derive/computed-skip-preserves-nat-add-and-sub"
  ;; `add`/`sub` left the hand list and are now handled by the computed guard.
  ;; Byte-identical to the hand-list baseline, which is the assertion.
  (check-equal? (list-ref ev 8) "5N : Nat")
  (check-equal? (list-ref ev 9) "3N : Nat"))

;; --- structural exclusions stay unbound (constants / output-only) ---
(test-case "derive/exclusions-remain-unbound"
  ;; `one` (MultiplicativeIdentity, no domains) and `from` (From {A B},
  ;; B output-only) must NOT derive. Unbound references come back as error
  ;; STRUCTS in the results (string mode returns, not raises).
  (check-has (format "~a" (run-ns-ws-last "one"))  "Unbound")
  (check-has (format "~a" (run-ns-ws-last "from")) "Unbound"))

;; --- L3: local trait declarations derive (single- and multi-method) ---
;; LAST test in the module: process-file is not fixture-safe.
(test-case "derive/local-traits-at-L3"
  (define results-l3
    (with-handlers ([exn:fail? (lambda (e) (fail (exn-message e)))])
      (process-file (path->string derive-fixture))))
  (define ev3 (evals-only (filter string? results-l3)))
  (check-equal? (list-ref ev3 0) "42 : Int")   ;; dbl 21
  (check-equal? (list-ref ev3 1) "42 : Int")   ;; scale-up 21
  (check-equal? (list-ref ev3 2) "5 : Int"))   ;; scale-down 10
