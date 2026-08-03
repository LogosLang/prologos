#lang racket/base

;;; test-hof-def-seam.rkt — a higher-order stdlib call works on a `def` RHS.
;;;
;;; The symptom was a bare command and a `def` disagreeing about the same
;;; expression:
;;;
;;;     reduce + 0 '[1 2 3]             ;; => 6 : Int
;;;     def a := reduce + 0 '[1 2 3]    ;; => ERROR: Multiplicity violation
;;;     def c := map inc '[1 2]         ;; => ERROR: Expression is not a valid type
;;;
;;; Two independent faults, both of which made their diagnostic name a
;;; subsystem that was working correctly.
;;;
;;; 1. "Multiplicity violation" was a KIND mismatch. A type constructor's kind
;;;    is `Pi m0 Type Type` — its type argument really is erased — while a
;;;    spec's `{C : Type -> Type}` writes an unannotated arrow, which defaults
;;;    to `mw`. `subtype?` demanded the two multiplicities be identical, so
;;;    `List` did not fit `C`.
;;;
;;;    It reached only the QTT pass because typing-core sees `C` as an unsolved
;;;    META, and meta-solving never compares multiplicities. Only the
;;;    post-freeze QTT check meets the concrete `List`. That is the
;;;    `pipeline.md` § "infer / inferQ Are Twins" shape — a generic
;;;    "Multiplicity violation" on a `def` whose body is not a lambda.
;;;
;;;    The fix is not new policy: Pi multiplicity is an UPPER BOUND on the
;;;    function's use of its argument, and `compatible 'mw 'm0` is already #t
;;;    everywhere else. `subtype?` now applies that same predicate structurally.
;;;
;;; 2. "Expression is not a valid type" ran `is-type` on an UNZONKED type. An
;;;    implicit higher-kinded argument leaves a meta-headed application behind,
;;;    which is not a type by inspection. The tell was in the message: it
;;;    renders with `pp-expr`, which DOES follow solutions, so it printed
;;;    "not a valid type: [List Int]" — naming a valid type. A diagnostic that
;;;    pretty-prints through a resolution its own predicate did not perform will
;;;    always read as nonsense.
;;;
;;; The bare-command form passed throughout and proves nothing here: it does
;;; not run either check. Every case below is therefore a `def`.

(require rackunit
         racket/list
         racket/file
         "test-support.rkt"
         "../errors.rkt"
         "../driver.rkt")

(define (run-file str)
  (define tmp (make-temporary-file "prologos-hof-~a.prologos"))
  (call-with-output-file tmp #:exists 'truncate
    (lambda (out) (display str out)))
  (begin0 (process-file tmp) (delete-file tmp)))

(define (describe r) (if (prologos-error? r) (format "ERROR ~a" r) (format "~a" r)))

(define (check-all-ok rs)
  (check-false (ormap prologos-error? rs)
               (format "~v" (map describe rs))))

(test-case "hof-def/Reducible-dispatched calls on a def RHS"
  ;; `reduce` and `length` both take `(Reducible C)`, so both instantiate the
  ;; higher-kinded implicit `{C : Type -> Type}` with `List`. This is fault 1.
  (define rs (run-file
    (string-append
     "ns hofd1\n"
     "def a := reduce + 0 '[1 2 3]\n"
     "def b := reduce int+ 0 '[1 2 3]\n"
     "def n := length '[1 2 3]\n"
     "a\n")))
  (check-all-ok rs)
  (check-true (regexp-match? #rx"^a : Int" (format "~a" (first rs))) (describe (first rs)))
  (check-true (regexp-match? #rx"^b : Int" (format "~a" (second rs))) (describe (second rs)))
  (check-true (regexp-match? #rx"6" (format "~a" (fourth rs)))
              (format "the value must still be right, not merely accepted: ~a"
                      (describe (fourth rs)))))

(test-case "hof-def/Seqable+Buildable calls on a def RHS"
  ;; `map` and `filter` carry TWO dicts and leave a meta-headed result type —
  ;; this is fault 2, and it survives fault 1's fix on its own.
  (define rs (run-file
    (string-append
     "ns hofd2\n"
     "spec inc Int -> Int\n"
     "defn inc [x] [int+ x 1]\n"
     "def c := map inc '[1 2 3]\n"
     "def d := filter [fn [x : Int] [int-lt x 3]] '[1 2 3]\n"
     "c\n")))
  (check-all-ok rs)
  (check-true (regexp-match? #rx"List" (format "~a" (third rs))) (describe (third rs)))
  (check-true (regexp-match? #rx"2 3 4" (format "~a" (last rs)))
              (format "wrong value: ~a" (describe (last rs)))))

(test-case "hof-def/the def and the bare command agree"
  ;; The defect WAS the disagreement. Asserting the def alone would not have
  ;; captured it, and asserting the command alone passed the whole time.
  (define rs (run-file
    (string-append
     "ns hofd3\n"
     "reduce + 0 '[1 2 3]\n"
     "def a := reduce + 0 '[1 2 3]\n"
     "a\n")))
  (check-all-ok rs)
  (check-equal? (format "~a" (first rs)) (format "~a" (third rs))
                "a def'd value must print exactly as the bare command's"))

(test-case "hof-def/a HOF inside a spec'd defn returns a VALUE, not a stuck term"
  ;; The entry claimed the definition was accepted but the CALL left a stuck
  ;; unreduced term. Pinned on the value, not on the absence of an error.
  (define rs (run-file
    (string-append
     "ns hofd4\n"
     "spec sum-all [List Int] -> Int\n"
     "defn sum-all [xs] [reduce + 0 xs]\n"
     "spec double-all [List Int] -> [List Int]\n"
     "defn double-all [xs] [map [int* _ 2] xs]\n"
     "def s := sum-all '[1 2 3]\n"
     "s\n"
     "double-all '[1 2 3]\n")))
  (check-all-ok rs)
  (check-true (regexp-match? #rx"^6 : Int" (format "~a" (fourth rs)))
              (format "stuck term instead of a value: ~a" (describe (fourth rs))))
  (check-true (regexp-match? #rx"2 4 6" (format "~a" (last rs)))
              (format "stuck term instead of a value: ~a" (describe (last rs)))))

(test-case "hof-def/annotating the def still works"
  ;; The annotated path is a DIFFERENT def seam (driver.rkt's two checkQ-top
  ;; sites). The entry recorded that annotating did not help; check the fix
  ;; covers both.
  (define rs (run-file
    (string-append
     "ns hofd5\n"
     "def a : Int := reduce + 0 '[1 2 3]\n"
     "def c : [List Int] := map [int* _ 2] '[1 2 3]\n"
     "c\n")))
  (check-all-ok rs)
  (check-true (regexp-match? #rx"2 4 6" (format "~a" (last rs))) (describe (last rs))))

;; ---------------------------------------------------------------------------
;; The multiplicity relation itself, at the unit level.
;; ---------------------------------------------------------------------------

(require (only-in "../subtype-predicate.rkt" subtype?)
         (only-in "../syntax.rkt" expr-Pi expr-Type)
         (only-in "../prelude.rkt" lzero))

(test-case "hof-def/Pi multiplicity subtyping is one-directional"
  ;; The loosening must go exactly as far as `compatible` and no further —
  ;; accepting `mw <: m1` would let an unrestricted function stand in for a
  ;; linear one, which is the unsoundness this ordering exists to prevent.
  (define T (expr-Type (lzero)))
  (define (pi m) (expr-Pi m T T))
  (check-true  (subtype? (pi 'm0) (pi 'mw)) "a function using its arg 0 times fits mw")
  (check-true  (subtype? (pi 'm1) (pi 'mw)) "…and so does a linear one")
  (check-false (subtype? (pi 'mw) (pi 'm1)) "unrestricted must NOT satisfy linear")
  (check-false (subtype? (pi 'mw) (pi 'm0)) "unrestricted must NOT satisfy erased")
  (check-false (subtype? (pi 'm0) (pi 'm1)) "erased must NOT satisfy linear")
  (check-false (subtype? (pi 'm1) (pi 'm0)) "linear must NOT satisfy erased"))
