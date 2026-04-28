#lang racket/base

;;;
;;; Minimal Racket helper module for FFI lambda passing tests / acceptance.
;;;
;;; All exports take a Racket procedure as their first argument — they exist
;;; specifically to drive the Prologos→Racket→Prologos callback bridge added
;;; in the 2026-04-28 FFI lambda passing track.
;;;
;;;   See: docs/tracking/2026-04-28_FFI_LAMBDA_PASSING.md
;;;

(provide apply-twice
         apply-twice-p32
         compose-and-call)

;; (apply-twice f n) = (f (f n))
;; Used to demonstrate that a Prologos lambda passed across the FFI is a
;; live, callable Racket procedure.
(define (apply-twice f n)
  (f (f n)))

;; Same shape on Posit32 — exercises a non-Nat callback spec end-to-end.
(define (apply-twice-p32 f x)
  (f (f x)))

;; Compose two Racket procedures, then apply to a value.
;; (compose-and-call f g x) = (f (g x)). Used to test that two function-typed
;; callback parameters in the same signature work.
(define (compose-and-call f g x)
  (f (g x)))
