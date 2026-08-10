#lang racket/base

;;; test-validate-match-scrutinee.rkt — where an INLINE `validate` scrutinee
;;; works and where it does not, pinned as a BOUNDARY.
;;;
;;; The filed symptom was "`match [validate S e] | ok v -> … | err es -> …`
;;; fails to infer the scrutinee's `Result S E` type inline; def-bind first
;;; works", diagnosed as "route-sensitivity in the checker's inline-vs-def-bound
;;; scrutinee inference". Probing (2026-08-03) narrowed it considerably, and the
;;; original framing is too broad in two directions:
;;;
;;;   - it is NOT about inline scrutinees. An inline APPLICATION scrutinee
;;;     (`match [cons 1N nil] | nil -> … | cons h t -> …`) infers fine.
;;;   - it is NOT only fixed by def-binding. ANNOTATING the match
;;;     (`def m : String := match [validate S e] …`) also works, because that
;;;     re-enters CHECK mode.
;;;
;;; The actual mechanism is an interaction between three deliberate designs:
;;;
;;;   1. `expr-validate` is registered with return-type #f
;;;      (typing-propagators.rkt: "position stays ⊥ → the refusal checks
;;;      re-route to the imperative checker (which owns the rule)").
;;;   2. `untyped-interior-position` (CIU T6 F1b.2, D26 route-soundness) walks
;;;      the command's expr tree after quiescence and, on finding ANY interior
;;;      position still at ⊥, re-routes the WHOLE command to the imperative
;;;      checker. A validate node inside the tree is exactly such a position.
;;;   3. The imperative `infer` has NO `expr-reduce` case — reduce is
;;;      check-only there by design.
;;;
;;; So the network declines the command because of (1)+(2), and the imperative
;;; checker cannot take it because of (3). Each design is defensible alone; the
;;; composition has no route. Anything else with a #f typing rule inside a
;;; `match` tree hits the same wall, so this is not a validate-specific bug.
;;;
;;; That makes the remedy an owner typing-policy call — the same one already
;;; recorded as the QTT track's deliberate option-(c) deferral, "an
;;; `expr-reduce` arm for `infer`/`inferQ`". These tests therefore pin the
;;; BOUNDARY rather than assert a fix: three routes that must keep working, and
;;; one that must keep failing LOUDLY (a per-command error naming the term, not
;;; a wrong type and not a crash). If the policy call ever lands, the last case
;;; is the one to flip.

(require rackunit
         racket/list
         racket/file
         "test-support.rkt"
         "../errors.rkt"
         "../driver.rkt")

(define prelude
  (string-append
   "schema S\n"
   "  :n Int\n"
   "\n"
   "def e := {:n 3}\n"))

(define (run-file ns-line body)
  (define tmp (make-temporary-file "prologos-valmatch-~a.prologos"))
  (call-with-output-file tmp #:exists 'truncate
    (lambda (out) (display (string-append ns-line "\n\n" prelude "\n" body) out)))
  (begin0 (process-file tmp) (delete-file tmp)))

(define (errors rs) (filter prologos-error? rs))

(test-case "validate-match/def-bound scrutinee WORKS"
  (define rs (run-file "ns vm1"
    (string-append
     "def r := [validate S e]\n"
     "match r\n"
     "  | ok v  -> \"good\"\n"
     "  | err x -> \"bad\"\n")))
  (check-equal? (errors rs) '() (format "~v" rs))
  (check-true (regexp-match? #rx"good" (format "~a" (last rs))) (format "~v" (last rs))))

(test-case "validate-match/ANNOTATING the match works too — not only def-binding"
  ;; The filed workaround was "def-bind first". Annotating re-enters check
  ;; mode and is equally sufficient; recording it because a user hitting this
  ;; is likelier to reach for an annotation.
  (define rs (run-file "ns vm2"
    (string-append
     "def m : String := match [validate S e]\n"
     "  | ok v  -> \"good\"\n"
     "  | err x -> \"bad\"\n")))
  (check-equal? (errors rs) '() (format "~v" rs))
  (check-true (regexp-match? #rx"m : String" (format "~a" (last rs))) (format "~v" (last rs))))

(test-case "validate-match/an inline APPLICATION scrutinee infers fine"
  ;; This is what shows the filing's "inline vs def-bound" framing is wrong.
  ;; Inline is not the problem; a #f-typed node in the tree is.
  (define rs (run-file "ns vm3"
    (string-append
     "match [cons 1N nil]\n"
     "  | nil -> \"a\"\n"
     "  | cons h t -> \"b\"\n")))
  (check-equal? (errors rs) '() (format "~v" rs))
  (check-true (regexp-match? #rx"\"b\"" (format "~a" (last rs))) (format "~v" (last rs))))

(test-case "validate-match/inline in INFER position fails, loudly and per-command"
  ;; The open case. What is pinned is the FAILURE MODE, not the failure: a
  ;; per-command error that names the term, with the surrounding commands
  ;; intact. A wrong type here would be far worse than an error, and this is
  ;; the assertion that would catch it.
  (define rs (run-file "ns vm4"
    (string-append
     "def before := 1\n"
     "match [validate S e]\n"
     "  | ok v  -> \"good\"\n"
     "  | err x -> \"bad\"\n"
     "def after := 2\n")))
  (define errs (errors rs))
  (check-equal? (length errs) 1 (format "expected exactly one error, got: ~v" rs))
  (check-true (regexp-match? #rx"Could not infer type" (format "~a" (first errs)))
              (format "~v" (first errs)))
  ;; the commands on either side survive — this is not a whole-file abort
  (check-true (regexp-match? #rx"before : Int" (format "~a" rs)) (format "~v" rs))
  (check-true (regexp-match? #rx"after : Int" (format "~a" rs)) (format "~v" rs)))
