#lang racket/base

;;;
;;; PROLOGOS INDUCTIVE
;;; Built-in inductive families: Vec (length-indexed vectors) and Fin (bounded naturals).
;;;
;;; In the Maude specification, prologos-inductive.maude extends earlier modules
;;; with new constructors and equations. Since Racket's `match` doesn't support
;;; post-hoc extension, all Vec/Fin constructors and their typing/reduction rules
;;; are defined directly in the base modules:
;;;
;;;   syntax.rkt         — Vec, vnil, vcons, Fin, fzero, fsuc, vhead, vtail, vindex
;;;   substitution.rkt   — shift/subst clauses for all Vec/Fin constructors
;;;   reduction.rkt      — vhead(vcons(...)), vtail(vcons(...)) reductions
;;;   typing-core.rkt    — Vec/Fin formation, intro, and elimination typing rules
;;;
;;; This module serves as documentation and a convenience re-export of
;;; the Vec/Fin subset of the language.
;;;

(require "syntax.rkt"
         "typing-core.rkt")

(provide
 ;; Vec type and constructors
 (struct-out expr-Vec)
 (struct-out expr-vnil)
 (struct-out expr-vcons)

 ;; Fin type and constructors
 (struct-out expr-Fin)
 (struct-out expr-fzero)
 (struct-out expr-fsuc)

 ;; Vec eliminators
 (struct-out expr-vhead)
 (struct-out expr-vtail)
 (struct-out expr-vindex))

;;; ========================================
;;; Typing Rules Summary (implemented in typing-core.rkt)
;;; ========================================
;;;
;;; Formation:
;;;   Vec(A, n) : Type(level(A))  when A : Type(l), n : Nat
;;;   Fin(n)    : Type(0)         when n : Nat
;;;
;;; Introduction:
;;;   vnil(A)              : Vec(A, zero)           when isType(A)
;;;   vcons(A, n, hd, tl)  : Vec(A, suc(n))         when hd : A, tl : Vec(A, n)
;;;   fzero(n)             : Fin(suc(n))             when n : Nat
;;;   fsuc(n, i)           : Fin(suc(n))             when i : Fin(n)
;;;
;;; Elimination:
;;;   vhead(A, n, v) : A          when v : Vec(A, suc(n))
;;;   vtail(A, n, v) : Vec(A, n)  when v : Vec(A, suc(n))
;;;   vindex(A, n, i, v) : A      when i : Fin(n), v : Vec(A, n)
;;;
;;; Reduction (implemented in reduction.rkt):
;;;   vhead(A, n, vcons(A, n, hd, tl)) → hd
;;;   vtail(A, n, vcons(A, n, hd, tl)) → tl
