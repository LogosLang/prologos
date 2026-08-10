#lang racket/base

;;; test-vec-index-ws.rkt — `vindex` COMPUTES, at Level 3.
;;;
;;; QTT P5 residual 1: `whnf` had computation rules for `vhead` and `vtail` on
;;; a canonical `vcons` but NONE for `vindex`, which existed only as an `nf`
;;; congruence arm. So `vindex` type-checked, multiplicity-checked, and then
;;; sat there as a stuck term — the residual was filed precisely so that "Vec
;;; is supported now" would not be over-read.
;;;
;;; `test-reduction.rkt` pins the iota rules at the `whnf` unit level. This
;;; file pins the thing a user would notice: a `.prologos` file that indexes a
;;; vector prints values. The distinction matters here because the unit tests
;;; construct `expr-vindex` directly, and a rule that fires on hand-built terms
;;; can still be unreachable through the elaborator.
;;;
;;; Level 3 (a real file through `process-file`) rather than Level 1, per
;;; `testing.md` § Three-level WS validation — this is the level that catches
;;; "works in tests, broken for users".

(require rackunit
         racket/list
         racket/file
         "test-support.rkt"
         "../errors.rkt"
         "../driver.rkt")

(define (run-file str)
  (define tmp (make-temporary-file "prologos-vidx-~a.prologos"))
  (call-with-output-file tmp #:exists 'truncate
    (lambda (out) (display str out)))
  (begin0 (process-file tmp) (delete-file tmp)))

;; The annotation is REQUIRED and is not part of what is under test: `vcons` is
;; check-only (typing-core has no `infer` arm for it), so an unannotated `def`
;; cannot infer the vector's type. Getting this wrong reads like a vindex
;; failure — the def errors and every later command reports an unbound `v3`.
(define source
  (string-append
   "ns vidxws\n"
   "def v3 : <Vec Int 3N> := (vcons Int 2N 10 (vcons Int 1N 20 (vcons Int 0N 30 (vnil Int))))\n"
   "(vindex Int 3N (fzero 2N) v3)\n"
   "(vindex Int 3N (fsuc 2N (fzero 1N)) v3)\n"
   "(vindex Int 3N (fsuc 2N (fsuc 1N (fzero 0N))) v3)\n"))

(define results (run-file source))

(test-case "vindex-ws/the file has no errors"
  (check-false (ormap prologos-error? results)
               (format "~v" results)))

(test-case "vindex-ws/each index yields its ELEMENT, not a stuck term"
  ;; Asserting the value, not merely the absence of an error: a stuck
  ;; `[vindex Int 3N …]` is not an error either, and that is exactly what this
  ;; printed before the iota rules landed.
  (check-equal? (length results) 4 (format "~v" results))
  (check-true (regexp-match? #rx"^10 : Int" (format "~a" (second results)))
              (format "position 0: ~a" (second results)))
  (check-true (regexp-match? #rx"^20 : Int" (format "~a" (third results)))
              (format "position 1: ~a" (third results)))
  ;; Position 2 needs the recursive arm to fire TWICE. An implementation that
  ;; only handled `fzero` would pass position 0 and fail here.
  (check-true (regexp-match? #rx"^30 : Int" (format "~a" (fourth results)))
              (format "position 2: ~a" (fourth results))))

(test-case "vindex-ws/vhead still agrees with vindex at 0"
  ;; The two eliminators must not disagree — vhead already computed, so it is
  ;; the available oracle for position 0.
  (define rs (run-file
    (string-append
     "ns vidxws2\n"
     "def v2 : <Vec Int 2N> := (vcons Int 1N 7 (vcons Int 0N 9 (vnil Int)))\n"
     "(vhead Int 1N v2)\n"
     "(vindex Int 2N (fzero 1N) v2)\n")))
  (check-false (ormap prologos-error? rs) (format "~v" rs))
  (check-equal? (format "~a" (third rs)) (format "~a" (second rs))
                "vindex at 0 must print exactly what vhead prints"))
