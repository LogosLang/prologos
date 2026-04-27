#lang racket/base

;;;
;;; Tests for pretty-printing of type-applied forms (eigentrust pitfalls doc #14)
;;;
;;; The reader accepts type applications written as `[T A]` (e.g.,
;;; `[PVec Rat]`, `[List Rat]`, `[Map Keyword Nat]`), per the Prologos
;;; syntax convention that `[]` is the universal functional/type-context
;;; delimiter and `()` is reserved for parser keywords (match, the, def,
;;; relational goals).
;;;
;;; Pre-fix, the pretty-printer produced `(PVec Rat)`, `(Set Nat)`, etc.
;;; — a cosmetic divergence between read and printed syntax. This test
;;; locks in the post-fix behavior: type applications round-trip with the
;;; `[T A]` form.
;;;

(require rackunit
         "../syntax.rkt"
         "../pretty-print.rkt")

;; ========================================
;; Type-application forms — primary fix
;; ========================================

(test-case "pp: PVec Nat -> [PVec Nat]"
  (check-equal? (pp-expr (expr-PVec (expr-Nat)) '())
                "[PVec Nat]"))

(test-case "pp: PVec Bool -> [PVec Bool]"
  (check-equal? (pp-expr (expr-PVec (expr-Bool)) '())
                "[PVec Bool]"))

(test-case "pp: PVec of fvar (e.g., Rat) -> [PVec Rat]"
  ;; Rat isn't a primitive expr-* form; using fvar 'Rat exercises the
  ;; same code path as the eigentrust pitfalls doc observation.
  (check-equal? (pp-expr (expr-PVec (expr-fvar 'Rat)) '())
                "[PVec Rat]"))

(test-case "pp: Set Nat -> [Set Nat]"
  (check-equal? (pp-expr (expr-Set (expr-Nat)) '())
                "[Set Nat]"))

(test-case "pp: Map Keyword Nat -> [Map Keyword Nat]"
  (check-equal? (pp-expr (expr-Map (expr-Keyword) (expr-Nat)) '())
                "[Map Keyword Nat]"))

(test-case "pp: TVec Nat -> [TVec Nat]"
  (check-equal? (pp-expr (expr-TVec (expr-Nat)) '())
                "[TVec Nat]"))

(test-case "pp: TMap Keyword Nat -> [TMap Keyword Nat]"
  (check-equal? (pp-expr (expr-TMap (expr-Keyword) (expr-Nat)) '())
                "[TMap Keyword Nat]"))

(test-case "pp: TSet Nat -> [TSet Nat]"
  (check-equal? (pp-expr (expr-TSet (expr-Nat)) '())
                "[TSet Nat]"))

;; ========================================
;; Nested type applications — composition with [T A] form
;; ========================================

(test-case "pp: nested Map of PVec -> [Map Keyword [PVec Nat]]"
  (check-equal? (pp-expr (expr-Map (expr-Keyword)
                                   (expr-PVec (expr-Nat)))
                         '())
                "[Map Keyword [PVec Nat]]"))

(test-case "pp: nested PVec of Set -> [PVec [Set Nat]]"
  (check-equal? (pp-expr (expr-PVec (expr-Set (expr-Nat))) '())
                "[PVec [Set Nat]]"))

;; ========================================
;; pvec-empty annotation form — uses [PVec ~a]
;; ========================================

(test-case "pp: pvec-empty annotation uses [PVec ~a]"
  (check-equal? (pp-expr (expr-pvec-empty (expr-Nat)) '())
                "@[] : [PVec Nat]"))

;; ========================================
;; Set/PVec/TVec operation forms — also use [op ...]
;; ========================================

(test-case "pp: set-empty -> [set-empty Nat]"
  (check-equal? (pp-expr (expr-set-empty (expr-Nat)) '())
                "[set-empty Nat]"))

(test-case "pp: set-insert -> [set-insert s a]"
  (check-equal? (pp-expr (expr-set-insert (expr-fvar 's) (expr-fvar 'a)) '())
                "[set-insert s a]"))

(test-case "pp: set-member -> [set-member? s a]"
  (check-equal? (pp-expr (expr-set-member (expr-fvar 's) (expr-fvar 'a)) '())
                "[set-member? s a]"))

;; ========================================
;; Cross-check with already-correct forms (regression guard)
;; ========================================

(test-case "pp: Vec already uses [Vec ...] (regression guard)"
  (check-equal? (pp-expr (expr-Vec (expr-Nat) (expr-suc (expr-zero))) '())
                "[Vec Nat 1N]"))

(test-case "pp: simple application uses [f x] (regression guard)"
  (check-equal? (pp-expr (expr-app (expr-fvar 'f) (expr-zero)) '())
                "[f 0N]"))
