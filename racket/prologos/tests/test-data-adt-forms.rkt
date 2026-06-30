#lang racket/base

;;;
;;; E2E tests for user `data` ADT constructor binding at WS Level 3.
;;;
;;; Regression for gap #3 (DEMO Track 1, 2026-06-29): a `data` declaration using
;;; the `:=` or `|` separator form bound its TYPE but its field-bearing
;;; CONSTRUCTORS bound with the wrong arity (and field types leaked as phantom
;;; nullary ctors), because `process-data` mapped `parse-data-ctor` over the raw
;;;   (:= c1 $pipe c2 ...)   /   ($pipe c1 $pipe c2 ...)   /   (| c1 | c2 ...)
;;; token stream without stripping the separators. `defn` normalizes via
;;; `group-defn-pipes`/`split-on-pipe`; `data` had no equivalent.
;;;
;;; Fixed by `normalize-data-ctor-clauses` (macros.rkt): strip a leading `:=`,
;;; canonicalize literal `|` -> `$pipe` (the cell/process-string-ws reader keeps
;;; `|` literal; the merge/process-file reader emits `$pipe`), split on `$pipe`
;;; into proper (Name field...) clauses, and unwrap single-list segments so
;;; `(suc Nat)` is not double-wrapped into `((suc Nat))`.
;;;
;;; Validated at L3 via BOTH process-file (merge) AND process-string-ws
;;; (cell / LSP REPL) — the recurring two-context trap. Each case constructs a
;;; field-bearing constructor WITH an argument; if the ctor bound nullary (the
;;; bug), the application would error.
;;;

(require rackunit
         racket/list
         racket/path
         racket/file
         "../driver.rkt"
         "../errors.rkt"
         "../namespace.rkt"
         "../metavar-store.rkt"
         "../relations.rkt"
         "../trait-resolution.rkt"
         "../macros.rkt")

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

;; Run content through process-file (the MERGE pipeline).
(define (run-file-pipeline content)
  (define tmp (make-temporary-file "prologos-adt-~a.prologos"))
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
                   [current-bundle-registry (current-bundle-registry)])
      (install-module-loader!)
      (process-file (path->string tmp))))
  (delete-file tmp)
  results)

;; Run content through process-string-ws (the CELL / LSP-REPL pipeline).
(define (run-ws-pipeline content)
  (parameterize ([current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-relation-store (make-relation-store)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    (process-string-ws content)))

(define (errors-of results)
  (filter prologos-error? results))

;; Assert the content binds + constructs without error in BOTH pipelines.
(define (check-adt-ok content label)
  (let ([fe (errors-of (run-file-pipeline content))])
    (check-equal? fe '()
                  (format "~a [process-file]: ~a" label (map prologos-error-message fe))))
  (let ([we (errors-of (run-ws-pipeline content))])
    (check-equal? we '()
                  (format "~a [process-string-ws]: ~a" label (map prologos-error-message we)))))

;; -- `:=` form with field-bearing constructors (the demo's exact `data Json`) --
(test-case "data := form: field-bearing ctors bind with correct arity (both pipelines)"
  (check-adt-ok
   "data Json := JNull | JBool Bool | JNum Int\n[JBool true]\n[JNum 7]\nJNull\n"
   "data Json :="))

;; -- pipe-leader form (no `:=`) --
(test-case "data pipe-leader form: field-bearing ctors bind (both pipelines)"
  (check-adt-ok
   "data J2 | jnull | jbool Bool | jnum Int\n[jbool true]\n[jnum 7]\njnull\n"
   "data J2 |"))

;; -- indented bare-juxtaposition form (must still work — regression guard) --
(test-case "data indented form: nullary ctors bind (both pipelines)"
  (check-adt-ok
   "data Color\n  red\n  green\n  blue\nred\ngreen\n"
   "data Color indented"))

;; -- `:=` single constructor with a field --
(test-case "data := single field-bearing ctor: mk-box Int (both pipelines)"
  (check-adt-ok
   "data Box := mk-box Int\n[mk-box 5]\n"
   "data Box := mk-box Int"))

;; -- recursive / single parenthesized clause (the split-on-pipe double-wrap) --
(test-case "data recursive ctor (suc Nat): single-list segment not double-wrapped (both pipelines)"
  (check-adt-ok
   "data Nat2 | zero2 | (suc2 Nat2)\n[suc2 zero2]\n"
   "data Nat2 | zero2 | (suc2 Nat2)"))

;; -- colon field form (implicit-append, monomorphic): fields-only, return implicit --
;; NOTE (convention): the colon form lists FIELDS; the return type is implicit
;; (always the data type). Do NOT append the data type (e.g. `c : Bool -> T`) —
;; under implicit-append that adds an extra field. Full GADT-style explicit
;; returns are deferred.
;;
;; ORTHOGONAL KNOWN BUG (filed, NOT gap #3): a *polymorphic* colon-field ctor at
;; top level — `data Lst {A}` with `cns : A -> Lst A` — binds via process-file but
;; FAILS in the cell/process-string-ws pipeline ("Expression is not a valid type
;; A [Lst A] -> Lst"; cns unbound). normalize-data-ctor-clauses is a verified
;; no-op for this form (no `:=`/`|`/`$pipe`), so it is pre-existing and separate
;; from the separator fix. Asserted here only in the monomorphic case.
(test-case "data colon field form (monomorphic): implicit-append binds (both pipelines)"
  (check-adt-ok
   "data Pr\n  nilp\n  one : Int\n  two : Int -> Bool\n[one 5]\n[two 1 true]\nnilp\n"
   "data Pr colon-field"))
