#lang racket/base

;;;
;;; Tests for pretty-print.rkt
;;;

(require rackunit
         racket/string
         "../prelude.rkt"
         "../syntax.rkt"
         "../sessions.rkt"
         "../pretty-print.rkt")

;; ========================================
;; Atoms
;; ========================================

(test-case "pp: zero"
  (check-equal? (pp-expr (expr-zero)) "zero"))

(test-case "pp: Nat"
  (check-equal? (pp-expr (expr-Nat)) "Nat"))

(test-case "pp: Bool"
  (check-equal? (pp-expr (expr-Bool)) "Bool"))

(test-case "pp: true"
  (check-equal? (pp-expr (expr-true)) "true"))

(test-case "pp: false"
  (check-equal? (pp-expr (expr-false)) "false"))

(test-case "pp: refl"
  (check-equal? (pp-expr (expr-refl)) "refl"))

(test-case "pp: error"
  (check-equal? (pp-expr (expr-error)) "<error>"))

;; ========================================
;; Numerals
;; ========================================

(test-case "pp: suc(zero) -> 1"
  (check-equal? (pp-expr (expr-suc (expr-zero))) "1"))

(test-case "pp: suc(suc(zero)) -> 2"
  (check-equal? (pp-expr (expr-suc (expr-suc (expr-zero)))) "2"))

(test-case "pp: nat->expr 5 -> 5"
  (check-equal? (pp-expr (nat->expr 5)) "5"))

(test-case "pp: suc(bvar(0)) — not a literal"
  (check-equal? (pp-expr (expr-suc (expr-bvar 0)) '("n")) "(suc n)"))

;; ========================================
;; Variables
;; ========================================

(test-case "pp: bvar(0) with name"
  (check-equal? (pp-expr (expr-bvar 0) '("x")) "x"))

(test-case "pp: bvar(1) with names"
  (check-equal? (pp-expr (expr-bvar 1) '("y" "x")) "x"))

(test-case "pp: fvar"
  (check-equal? (pp-expr (expr-fvar 'id)) "id"))

;; ========================================
;; Type
;; ========================================

(test-case "pp: Type(0)"
  (check-equal? (pp-expr (expr-Type (lzero))) "(Type 0)"))

(test-case "pp: Type(1)"
  (check-equal? (pp-expr (expr-Type (lsuc (lzero)))) "(Type 1)"))

;; ========================================
;; Pi — non-dependent arrow
;; ========================================

(test-case "pp: non-dependent Pi -> arrow"
  ;; Pi(mw, Nat, Nat) where body doesn't use bvar(0)
  (check-equal? (pp-expr (expr-Pi 'mw (expr-Nat) (expr-Nat)))
                "(-> Nat Nat)"))

(test-case "pp: dependent Pi"
  ;; Pi(mw, Nat, bvar(0)) — body uses bvar(0)
  (let ([result (pp-expr (expr-Pi 'mw (expr-Nat) (expr-bvar 0)))])
    (check-true (string-contains? result "Pi"))
    (check-true (string-contains? result "Nat"))))

(test-case "pp: erased Pi"
  (let ([result (pp-expr (expr-Pi 'm0 (expr-Type (lzero)) (expr-bvar 0)))])
    (check-true (string-contains? result ":0"))))

;; ========================================
;; Lambda
;; ========================================

(test-case "pp: lambda"
  (let ([result (pp-expr (expr-lam 'mw (expr-Nat) (expr-suc (expr-bvar 0))))])
    (check-true (string-contains? result "lam"))
    (check-true (string-contains? result "Nat"))
    (check-true (string-contains? result "suc"))))

(test-case "pp: linear lambda"
  (let ([result (pp-expr (expr-lam 'm1 (expr-Nat) (expr-bvar 0)))])
    (check-true (string-contains? result ":1"))))

;; ========================================
;; Application
;; ========================================

(test-case "pp: simple app"
  (let ([result (pp-expr (expr-app (expr-fvar 'f) (expr-zero)))])
    (check-equal? result "(f zero)")))

(test-case "pp: multi-arg app flattened"
  (let ([result (pp-expr (expr-app (expr-app (expr-fvar 'f) (expr-zero)) (expr-true)))])
    (check-equal? result "(f zero true)")))

;; ========================================
;; Pair, fst, snd
;; ========================================

(test-case "pp: pair"
  (check-equal? (pp-expr (expr-pair (expr-zero) (expr-refl)))
                "(pair zero refl)"))

(test-case "pp: fst"
  (check-equal? (pp-expr (expr-fst (expr-fvar 'p)))
                "(fst p)"))

(test-case "pp: snd"
  (check-equal? (pp-expr (expr-snd (expr-fvar 'p)))
                "(snd p)"))

;; ========================================
;; Annotation
;; ========================================

(test-case "pp: annotation"
  (check-equal? (pp-expr (expr-ann (expr-zero) (expr-Nat)))
                "(the Nat zero)"))

;; ========================================
;; Eq
;; ========================================

(test-case "pp: Eq"
  (check-equal? (pp-expr (expr-Eq (expr-Nat) (expr-zero) (expr-zero)))
                "(Eq Nat zero zero)"))

;; ========================================
;; Vec/Fin
;; ========================================

(test-case "pp: Vec"
  (check-equal? (pp-expr (expr-Vec (expr-Nat) (expr-suc (expr-zero))))
                "(Vec Nat 1)"))

(test-case "pp: vnil"
  (check-equal? (pp-expr (expr-vnil (expr-Nat)))
                "(vnil Nat)"))

(test-case "pp: Fin"
  (check-equal? (pp-expr (expr-Fin (expr-suc (expr-suc (expr-zero)))))
                "(Fin 2)"))

;; ========================================
;; Multiplicity formatting
;; ========================================

(test-case "pp-mult: 0"
  (check-equal? (pp-mult 'm0) "0"))

(test-case "pp-mult: 1"
  (check-equal? (pp-mult 'm1) "1"))

(test-case "pp-mult: w"
  (check-equal? (pp-mult 'mw) "w"))

;; ========================================
;; Session types
;; ========================================

(test-case "pp: session end"
  (check-equal? (pp-session (sess-end)) "end"))

(test-case "pp: session send"
  (check-equal? (pp-session (sess-send (expr-Nat) (sess-end)))
                "(!Nat . end)"))

(test-case "pp: session recv"
  (check-equal? (pp-session (sess-recv (expr-Bool) (sess-end)))
                "(?Bool . end)"))

(test-case "pp: session choice"
  (let ([result (pp-session (sess-choice (list (cons 'ping (sess-send (expr-Nat) (sess-end)))
                                               (cons 'quit (sess-end)))))])
    (check-true (string-contains? result "ping"))
    (check-true (string-contains? result "quit"))))
