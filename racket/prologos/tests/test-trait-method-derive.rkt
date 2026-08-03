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
     "eval [reduce int+ 0 '[1 2 3]]")
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
  (check-equal? (list-ref ev 6) "6 : Int"))

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
