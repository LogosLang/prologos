#lang racket/base

;;; test-solver-collection-terms.rkt — a collection literal survives the
;;; AST↔solver-term round trip.
;;;
;;; Unifying a relational variable with a collection LITERAL produced the
;;; runtime value `unknown` while the static row type was derived correctly:
;;;
;;;   defr mp [?x ?m]
;;;     &> (edge x z) (= m {:a 1})
;;;   solve (mp x m)
;;;   ;; @[{:x 1, :m unknown}] : [PVec {:m {:a Int} :x Int}]
;;;   ;;             ^^^^^^^ runtime      ^^^^^^^^^ static — they disagreed
;;;
;;; The one place the static row type and the actual row provably disagreed,
;;; which is exactly the key/type agreement the row work exists to preserve.
;;;
;;; Cause: `ground->prologos-expr` (reduction.rkt) filtered AST nodes through a
;;; hand-enumerated list of thirteen predicates in front of an `unknown`
;;; fallback. Maps and vectors were not on it. That is the exhaustive-walker
;;; shape — a node kind not on the list falls through and the fallback does the
;;; wrong thing quietly — and the fix is structural: `expr?`, since the fallback
;;; exists to catch RAW RACKET values from the solver boundary, not to filter
;;; AST nodes.
;;;
;;; Scalars were always fine, which is why this survived: a test using a string
;;; or an integer literal passes either way.

(require rackunit
         racket/string
         "test-support.rkt"
         "../errors.rkt")

(define edge-decl "ns sct\ndefr edge [?a ?b]\n  || 1 2\n")

(define (solve-with binding)
  (run-ns-ws-last
   (string-append edge-decl
                  "defr r [?x ?v]\n  &> (edge x z) (= v " binding ")\n"
                  "solve (r x v)\n")))

(test-case "solver/a MAP literal survives the round trip"
  (define r (solve-with "{:a 1}"))
  (check-false (prologos-error? r) (format "got: ~v" r))
  (define text (format "~a" r))
  (check-false (string-contains? text "unknown")
               (format "the map came back as `unknown`: ~v" r))
  (check-true (string-contains? text ":a 1") (format "got: ~v" r)))

(test-case "solver/a LIST literal survives the round trip"
  (define r (solve-with "'[1 2]"))
  (check-false (prologos-error? r) (format "got: ~v" r))
  (check-false (string-contains? (format "~a" r) "unknown")
               (format "the list came back as `unknown`: ~v" r)))

(test-case "solver/a PVEC literal survives the round trip"
  (define r (solve-with "@[7 8]"))
  (check-false (prologos-error? r) (format "got: ~v" r))
  (define text (format "~a" r))
  (check-false (string-contains? text "unknown")
               (format "the pvec came back as `unknown`: ~v" r))
  (check-true (string-contains? text "7") (format "got: ~v" r)))

(test-case "solver/scalars still survive — the case that always worked"
  ;; The control. A test written with a scalar would have passed throughout the
  ;; defect, which is how it lasted.
  (define r (solve-with "\"lit\""))
  (check-false (prologos-error? r) (format "got: ~v" r))
  (check-true (string-contains? (format "~a" r) "lit") (format "got: ~v" r)))

(test-case "solver/the runtime row AGREES with the static row type"
  ;; The property the entry was really about: not "no `unknown` appears" but
  ;; "the value and its declared type describe the same thing". A map field
  ;; typed `{:a Int}` must not hold a bare symbol.
  (define r (solve-with "{:a 1}"))
  (define text (format "~a" r))
  (check-true (string-contains? text "{:v {:a Int}")
              (format "static row type changed shape — update this pin: ~v" r))
  (check-true (string-contains? text ":v {:a 1}")
              (format "runtime value does not match the static type: ~v" r)))
