#lang racket/base

;;; test-multiarity-nullary-dispatch.rkt — a multi-arity `defn` must dispatch on
;;; EVERY column, not just the first.
;;;
;;; THE BUG (fixed 2026-08-05, macros.rkt `expand-defn-pattern-group`):
;;; `param-names` decided "are all these patterns variables?" using
;;; `pattern-is-variable?` on the RAW clause patterns — before
;;; `normalize-pattern` had consulted `lookup-ctor`. A bare nullary constructor
;;; pattern is a `pat-atom` of kind 'var at that moment, so every bare
;;; constructor counted as a variable, `all-var?` came out #t, and the generated
;;; parameters were named after the PATTERNS. `| ka ka -> …` therefore produced
;;; TWO parameters BOTH NAMED `ka`; `compile-match-tree` took
;;; `(list-ref param-names col)` per dispatch column, got the same name twice,
;;; and the second dispatch re-read the FIRST argument.
;;;
;;; `[keq ka kb]` returned `true`. Compiles, type-checks, 0 errors.
;;;
;;; WHY IT NEEDS ITS OWN FILE. It was found by ONE assertion in the entire tree —
;;; `test-ocapn-bridge`'s "refr-eq? different kinds => false even with same id" —
;;; which existed only because OCapN brand-check happens to need it. 165 of that
;;; file's 166 cases passed, the full suite passed, and the 24/24 conformance
;;; gate passed, because none of them compare two different nullary constructors
;;; at the same second argument. A language-level defect should not depend on an
;;; application test for its only witness.
;;;
;;; WHAT TO VARY IF THIS EVER REGRESSES. The discriminating shape is: two or more
;;; columns, BARE (unbracketed) nullary constructor patterns, and at least one
;;; call whose arguments differ between columns. Bracketed patterns
;;; (`| [ka] [ka] ->`) always worked — the reader emits `pat-compound` for those,
;;; so no lookup is needed — which is exactly why the bug read as a bracketing
;;; rule rather than a normalization-order bug, and why the first "root cause"
;;; recorded for it (a parser splitting failure) was wrong. Both spellings are
;;; pinned below so that difference can never silently return.

(require rackunit
         racket/string
         "test-support.rkt")

;; `run-ns-all` wraps the program in a fresh `ns` with the prelude and returns
;; every result; the assertions below index the ones they care about by
;; searching, so an extra `defined.` line ahead of them is harmless.
(define (run-prog src) (string-join (run-ns-all src) "\n"))

;; ---------------------------------------------------------------------------
;; Two constructors, bare patterns — the original repro
;; ---------------------------------------------------------------------------

(define SETUP2
  (string-append
   "(data K2 (a2) (b2)) "
   "(spec bare2 K2 K2 -> Bool) "
   "(defn bare2 | a2 a2 -> true | b2 b2 -> true | _ _ -> false) "))

(test-case "bare nullary patterns dispatch on the SECOND column too (2 ctors)"
  (check-regexp-match #rx"true"  (run-prog (string-append SETUP2 "(eval (bare2 a2 a2))")))
  ;; The bug: this returned `true`.
  (check-regexp-match #rx"false" (run-prog (string-append SETUP2 "(eval (bare2 a2 b2))")))
  (check-regexp-match #rx"false" (run-prog (string-append SETUP2 "(eval (bare2 b2 a2))")))
  (check-regexp-match #rx"true"  (run-prog (string-append SETUP2 "(eval (bare2 b2 b2))"))))

;; ---------------------------------------------------------------------------
;; Three constructors — constructor COUNT was a confound in the original
;; diagnosis (the bracketed probe used 2 ctors, the bare probe used 3), so both
;; counts are pinned rather than assumed equivalent.
;; ---------------------------------------------------------------------------

(define SETUP3
  (string-append
   "(data K3 (a3) (b3) (c3)) "
   "(spec bare3 K3 K3 -> Bool) "
   "(defn bare3 | a3 a3 -> true | b3 b3 -> true | c3 c3 -> true | _ _ -> false) "))

(test-case "bare nullary patterns dispatch on the SECOND column too (3 ctors)"
  (check-regexp-match #rx"true"  (run-prog (string-append SETUP3 "(eval (bare3 a3 a3))")))
  (check-regexp-match #rx"false" (run-prog (string-append SETUP3 "(eval (bare3 a3 b3))")))
  (check-regexp-match #rx"false" (run-prog (string-append SETUP3 "(eval (bare3 c3 a3))")))
  (check-regexp-match #rx"true"  (run-prog (string-append SETUP3 "(eval (bare3 c3 c3))"))))

;; ---------------------------------------------------------------------------
;; Bracketed patterns — the spelling that always worked. Pinned so the two
;; spellings cannot diverge again.
;; ---------------------------------------------------------------------------

(define SETUPB
  (string-append
   "(data KB (ab) (bb)) "
   "(spec brk KB KB -> Bool) "
   "(defn brk | [ab] [ab] -> true | [bb] [bb] -> true | _ _ -> false) "))

(test-case "bracketed nullary patterns agree with bare ones"
  (check-regexp-match #rx"true"  (run-prog (string-append SETUPB "(eval (brk ab ab))")))
  (check-regexp-match #rx"false" (run-prog (string-append SETUPB "(eval (brk ab bb))")))
  (check-regexp-match #rx"false" (run-prog (string-append SETUPB "(eval (brk bb ab))"))))

;; ---------------------------------------------------------------------------
;; A non-first column that discriminates while the first is constant. This is
;; the case that returned the CATCH-ALL rather than the wrong arm — the second
;; of the two distinct wrong behaviours, and the one that ruled out
;; "first-arm-eats-everything" as an explanation.
;; ---------------------------------------------------------------------------

(define SETUPF
  (string-append
   "(data KF (af) (bf)) "
   "(spec ff KF KF -> Nat) "
   "(defn ff | af af -> 1N | af bf -> 2N | _ _ -> 9N) "))

(test-case "a discriminating SECOND column is reached when the first is constant"
  (check-regexp-match #rx"1N" (run-prog (string-append SETUPF "(eval (ff af af))")))
  ;; The bug: this returned `9N` — the catch-all — instead of `2N`.
  (check-regexp-match #rx"2N" (run-prog (string-append SETUPF "(eval (ff af bf))")))
  (check-regexp-match #rx"9N" (run-prog (string-append SETUPF "(eval (ff bf af))"))))

;; ---------------------------------------------------------------------------
;; The all-variables path must still name parameters after the patterns — that
;; optimization is what the fix touched, and it is load-bearing (an extra
;; indirection there triggers QTT false positives, per the comment at its site).
;; ---------------------------------------------------------------------------

(test-case "an all-variable clause still binds its own parameter names"
  (check-regexp-match
   #rx"7N"
   (run-prog "(spec pick Nat Nat -> Nat) (defn pick | x y -> x) (eval (pick 7N 3N))"))
  (check-regexp-match
   #rx"3N"
   (run-prog "(spec pick2 Nat Nat -> Nat) (defn pick2 | x y -> y) (eval (pick2 7N 3N))")))
