#lang racket/base

;;;
;;; Tests for eigentrust pitfalls doc #3:
;;;   `0/1` and `1/1` inside nested list literals silently became Int.
;;;
;;; Root cause: the WS reader called `string->number "0/1"` which Racket
;;; simplifies to the integer 0, losing the user's `Rat`-literal intent.
;;; Downstream typing then saw a mix of Int and Rat in `'[0/1 1/2 ...]`
;;; and either picked Int or rejected the outer `[List Rat]` annotation.
;;;
;;; Fix shape (a — preserve at parse time): a number-token lexeme that
;;; contains `/` is wrapped in a `($rat-literal val)` sentinel by the
;;; WS reader, mirroring `($nat-literal val)` for `42N`. Both surface
;;; parsers (parser.rkt for the preparse path, tree-parser.rkt for the
;;; cell pipeline path) then route the sentinel / slash-lexeme to
;;; `surf-rat-lit`, preserving Rat-ness even when the simplified value
;;; is an integer.
;;;
;;; Files touched:
;;;   - racket/prologos/parse-reader.rkt   (emit $rat-literal sentinel)
;;;   - racket/prologos/parser.rkt         (handle $rat-literal sentinel)
;;;   - racket/prologos/tree-parser.rkt    (slash-lexeme → surf-rat-lit;
;;;                                         flatten-ws-datum exemption)
;;;

(require rackunit
         racket/string
         "test-support.rkt")

;; ========================================
;; A. The eigentrust reproducer
;; ========================================
;; The original failing form, scaled to 2x2 to keep the test small.
;; Before the fix this raised "Type mismatch [List [List Rat]] ...
;; '['[0 1/2] '[1/2 0]]" because `0/1` had been collapsed to Int 0.

(test-case "rat-literal-in-list/eigentrust-reproducer-2x2"
  ;; Before the fix this raised "Type mismatch [List [List Rat]] ...".
  ;; After: elaborates and evaluates cleanly, and the inferred type is
  ;; the annotated `[List [List Rat]]`. (Pretty-print collapses 0/1 → 0
  ;; in the value display, but the surrounding type is what matters.)
  (define out
    (run-ns-ws-last
     "ns rl1\ndef C : [List [List Rat]] := \x27[\x27[0/1 1/2] \x27[1/2 0/1]]\neval C"))
  (check-true (string-contains? out "List [prologos::data::list::List Rat]"))
  (check-false (string-contains? out "Type mismatch")))

(test-case "rat-literal-in-list/eigentrust-reproducer-3x3"
  ;; The exact 3x3 form from the eigentrust pitfalls doc.
  (check-equal?
   (run-ns-ws-last
    "ns rl2\ndef C : [List [List Rat]]\n  := \x27[\x27[0/1 1/2 1/2] \x27[1/2 0/1 1/2] \x27[1/2 1/2 0/1]]\ninfer C")
   "[prologos::data::list::List [prologos::data::list::List Rat]]"))

;; ========================================
;; B. Top-level Rat literal regressions
;; ========================================
;; Bare `0/1` and `1/1` outside a list must still be Rat (not Int).

(test-case "rat-literal-in-list/bare-zero-over-one-is-rat"
  (check-equal? (run-ns-ws-last "ns rl3\ninfer 0/1") "Rat"))

(test-case "rat-literal-in-list/bare-one-over-one-is-rat"
  (check-equal? (run-ns-ws-last "ns rl4\ninfer 1/1") "Rat"))

(test-case "rat-literal-in-list/bare-half-is-rat"
  (check-equal? (run-ns-ws-last "ns rl5\ninfer 1/2") "Rat"))

(test-case "rat-literal-in-list/bare-negative-rat"
  (check-equal? (run-ns-ws-last "ns rl6\ninfer -3/7") "Rat"))

(test-case "rat-literal-in-list/bare-negative-zero-over-one"
  (check-equal? (run-ns-ws-last "ns rl7\ninfer -0/1") "Rat"))

;; ========================================
;; C. Bare integer regression: `0` and `42` are still Int
;; ========================================
;; The fix MUST NOT promote bare integers to Rat — only slash-containing
;; lexemes are Rat literals.

(test-case "rat-literal-in-list/bare-zero-is-int"
  (check-equal? (run-ns-ws-last "ns ri1\ninfer 0") "Int"))

(test-case "rat-literal-in-list/bare-42-is-int"
  (check-equal? (run-ns-ws-last "ns ri2\ninfer 42") "Int"))

(test-case "rat-literal-in-list/bare-negative-int"
  (check-equal? (run-ns-ws-last "ns ri3\ninfer -7") "Int"))

;; ========================================
;; D. Single-level list literals
;; ========================================
;; The simplest list-literal case: `'[0/1 1/2]` should be `List Rat`,
;; not `List Int`.

(test-case "rat-literal-in-list/single-list-zero-and-half"
  (check-equal?
   (run-ns-ws-last "ns rl8\ninfer \x27[0/1 1/2]")
   "[prologos::data::list::List Rat]"))

(test-case "rat-literal-in-list/single-list-with-one-over-one"
  (check-equal?
   (run-ns-ws-last "ns rl9\ninfer \x27[1/1 1/2 0/1]")
   "[prologos::data::list::List Rat]"))

;; ========================================
;; E. PVec literals — companion path
;; ========================================
;; Per the eigentrust pitfalls doc #10, `@[0/1 1/2]` already worked for PVec.
;; Confirm it continues to work and that this fix doesn't regress the PVec path.

(test-case "rat-literal-in-list/pvec-zero-and-half"
  (check-equal?
   (run-ns-ws-last "ns rp1\ninfer @[0/1 1/2]")
   "(PVec Rat)"))

(test-case "rat-literal-in-list/pvec-with-one-over-one"
  (check-equal?
   (run-ns-ws-last "ns rp2\ninfer @[1/1 1/2 0/1]")
   "(PVec Rat)"))

;; ========================================
;; F. Annotated def with mixed simplifying / non-simplifying rationals
;; ========================================
;; The annotation `[List Rat]` declares the target type. Before the fix,
;; `0/1` collapsed to Int and the annotation check failed. After the fix,
;; the slash sentinel preserves Rat-ness and the def elaborates cleanly.

(test-case "rat-literal-in-list/annotated-list-with-zero-over-one"
  (check-true
   (string-contains?
    (run-ns-ws-last
     "ns rl10\ndef xs : [List Rat] := \x27[0/1 1/2 1/1]\neval xs")
    "List Rat")))

;; ========================================
;; G. Sexp-mode (rat ...) constructor still works
;; ========================================
;; Defensive: the explicit `(rat 0/1)` constructor was never affected,
;; but confirm the explicit-constructor path remains intact.

(test-case "rat-literal-in-list/explicit-rat-zero-over-one"
  (check-equal? (run-ns-last "(ns rs1)\n(infer (rat 0/1))") "Rat"))

(test-case "rat-literal-in-list/explicit-rat-one-over-one"
  (check-equal? (run-ns-last "(ns rs2)\n(infer (rat 1/1))") "Rat"))
