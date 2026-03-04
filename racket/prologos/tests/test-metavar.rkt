#lang racket/base

;;;
;;; Tests for metavariable infrastructure (Sprint 1)
;;;   - metavar-store.rkt: creation, solving, reset, isolation
;;;   - substitution.rkt: shift/subst treat expr-meta as opaque
;;;   - reduction.rkt: whnf follows solved metas, nf/conv handle metas
;;;   - zonk.rkt: recursive substitution of solved metas
;;;   - pretty-print.rkt: display of solved/unsolved metas
;;;   - syntax.rkt: expr? predicate recognizes expr-meta
;;;

(require rackunit
         racket/string
         "../prelude.rkt"
         "../syntax.rkt"
         "../metavar-store.rkt"
         "../substitution.rkt"
         "../reduction.rkt"
         "../pretty-print.rkt"
         "../zonk.rkt"
         "../global-env.rkt")

;; ========================================
;; Meta store basics
;; ========================================

(test-case "fresh-meta creates expr-meta with symbol ID"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat) "test"))
    (check-true (expr-meta? m))
    (check-true (symbol? (expr-meta-id m)))))

(test-case "fresh-meta registers in the store"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat) "test"))
    (define id (expr-meta-id m))
    (define info (meta-lookup id))
    (check-not-false info)
    (check-eq? (meta-info-status info) 'unsolved)
    (check-equal? (meta-info-type info) (expr-Nat))
    (check-false (meta-info-solution info))
    (check-equal? (meta-info-constraints info) '())
    (check-equal? (meta-info-source info) "test")))

(test-case "meta-solved? returns #f for unsolved"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat) "test"))
    (check-false (meta-solved? (expr-meta-id m)))))

(test-case "solve-meta! marks as solved"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat) "test"))
    (define id (expr-meta-id m))
    (solve-meta! id (expr-zero))
    (check-true (meta-solved? id))
    (check-equal? (meta-solution id) (expr-zero))))

(test-case "solve-meta! on already-solved raises error"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat) "test"))
    (define id (expr-meta-id m))
    (solve-meta! id (expr-zero))
    (check-exn exn:fail?
               (lambda () (solve-meta! id (expr-suc (expr-zero)))))))

(test-case "all-unsolved-metas counts correctly"
  (with-fresh-meta-env
    (define m1 (fresh-meta ctx-empty (expr-Nat) "a"))
    (define m2 (fresh-meta ctx-empty (expr-Bool) "b"))
    (define m3 (fresh-meta ctx-empty (expr-Nat) "c"))
    (check-equal? (length (all-unsolved-metas)) 3)
    (solve-meta! (expr-meta-id m2) (expr-true))
    (check-equal? (length (all-unsolved-metas)) 2)))

(test-case "reset-meta-store! clears everything"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat) "test"))
    (define id (expr-meta-id m))
    (solve-meta! id (expr-zero))
    (reset-meta-store!)
    (check-equal? (all-unsolved-metas) '())
    (check-false (meta-lookup id))))

(test-case "with-fresh-meta-env isolates stores"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat) "outer"))
    (define id (expr-meta-id m))
    (with-fresh-meta-env
      ;; Inner store is empty
      (check-false (meta-lookup id))
      ;; Create a meta in inner store
      (define m2 (fresh-meta ctx-empty (expr-Bool) "inner"))
      (check-equal? (length (all-unsolved-metas)) 1))
    ;; Outer store still has original meta
    (check-not-false (meta-lookup id))
    (check-equal? (length (all-unsolved-metas)) 1)))

;; ========================================
;; Shift/subst treat expr-meta as opaque
;; ========================================

(test-case "shift: expr-meta unchanged"
  (define m (expr-meta 'test-id))
  (check-equal? (shift 1 0 m) m))

(test-case "subst: expr-meta unchanged"
  (define m (expr-meta 'test-id))
  (check-equal? (subst 0 (expr-zero) m) m))

(test-case "shift: expr-meta inside app"
  (define m (expr-meta 'test-id))
  ;; Meta stays, but bvar(0) shifts to bvar(1)
  (check-equal? (shift 1 0 (expr-app m (expr-bvar 0)))
                (expr-app m (expr-bvar 1))))

;; ========================================
;; whnf follows solved metas
;; ========================================

(test-case "whnf: unsolved meta is stuck"
  (with-fresh-meta-env
    (parameterize ([current-global-env (hasheq)])
      (define m (fresh-meta ctx-empty (expr-Nat) "test"))
      (check-equal? (whnf m) m))))

(test-case "whnf: solved meta reduces to solution"
  (with-fresh-meta-env
    (parameterize ([current-global-env (hasheq)])
      (define m (fresh-meta ctx-empty (expr-Nat) "test"))
      (solve-meta! (expr-meta-id m) (expr-zero))
      (check-equal? (whnf m) (expr-zero)))))

(test-case "whnf: solved meta with reducible solution"
  (with-fresh-meta-env
    (parameterize ([current-global-env (hasheq)])
      (define m (fresh-meta ctx-empty (expr-Nat) "test"))
      ;; Solve to a beta-redex: ((fn [x : Nat] x) zero) → zero
      (solve-meta! (expr-meta-id m)
                   (expr-app (expr-lam 'mw (expr-Nat) (expr-bvar 0))
                             (expr-zero)))
      (check-equal? (whnf m) (expr-zero)))))

(test-case "whnf: nested meta chain"
  (with-fresh-meta-env
    (parameterize ([current-global-env (hasheq)])
      (define m1 (fresh-meta ctx-empty (expr-Nat) "first"))
      (define m2 (fresh-meta ctx-empty (expr-Nat) "second"))
      (solve-meta! (expr-meta-id m1) m2)
      (solve-meta! (expr-meta-id m2) (expr-suc (expr-zero)))
      (check-equal? (whnf m1) (expr-nat-val 1)))))

;; ========================================
;; nf handles metas
;; ========================================

(test-case "nf: unsolved meta stays"
  (with-fresh-meta-env
    (parameterize ([current-global-env (hasheq)])
      (define m (fresh-meta ctx-empty (expr-Nat) "test"))
      (check-equal? (nf m) m))))

(test-case "nf: solved meta normalizes"
  (with-fresh-meta-env
    (parameterize ([current-global-env (hasheq)])
      (define m (fresh-meta ctx-empty (expr-Nat) "test"))
      ;; Solve to a beta-redex
      (solve-meta! (expr-meta-id m)
                   (expr-app (expr-lam 'mw (expr-Nat) (expr-suc (expr-bvar 0)))
                             (expr-zero)))
      (check-equal? (nf m) (expr-nat-val 1)))))

;; ========================================
;; conv handles metas
;; ========================================

(test-case "conv: same unsolved meta equals itself"
  (with-fresh-meta-env
    (parameterize ([current-global-env (hasheq)])
      (define m (fresh-meta ctx-empty (expr-Nat) "test"))
      (check-true (conv m m)))))

(test-case "conv: different unsolved metas are unequal"
  (with-fresh-meta-env
    (parameterize ([current-global-env (hasheq)])
      (define m1 (fresh-meta ctx-empty (expr-Nat) "a"))
      (define m2 (fresh-meta ctx-empty (expr-Nat) "b"))
      (check-false (conv m1 m2)))))

(test-case "conv: solved meta compared to its solution"
  (with-fresh-meta-env
    (parameterize ([current-global-env (hasheq)])
      (define m (fresh-meta ctx-empty (expr-Nat) "test"))
      (solve-meta! (expr-meta-id m) (expr-zero))
      (check-true (conv m (expr-zero))))))

(test-case "conv: unsolved meta vs non-meta"
  (with-fresh-meta-env
    (parameterize ([current-global-env (hasheq)])
      (define m (fresh-meta ctx-empty (expr-Nat) "test"))
      (check-false (conv m (expr-zero))))))

;; ========================================
;; Zonk
;; ========================================

(test-case "zonk: unsolved meta unchanged"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat) "test"))
    (check-equal? (zonk m) m)))

(test-case "zonk: solved meta replaced by solution"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat) "test"))
    (solve-meta! (expr-meta-id m) (expr-zero))
    (check-equal? (zonk m) (expr-zero))))

(test-case "zonk: recursive (solution contains another meta)"
  (with-fresh-meta-env
    (define m1 (fresh-meta ctx-empty (expr-Nat) "first"))
    (define m2 (fresh-meta ctx-empty (expr-Nat) "second"))
    (solve-meta! (expr-meta-id m1) (expr-suc m2))
    (solve-meta! (expr-meta-id m2) (expr-zero))
    (check-equal? (zonk m1) (expr-suc (expr-zero)))))

(test-case "zonk: meta inside compound expression"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat) "test"))
    (solve-meta! (expr-meta-id m) (expr-Nat))
    (check-equal? (zonk (expr-Pi 'mw m (expr-bvar 0)))
                  (expr-Pi 'mw (expr-Nat) (expr-bvar 0)))))

(test-case "zonk: expr-hole unchanged"
  (with-fresh-meta-env
    (check-equal? (zonk (expr-hole)) (expr-hole))))

(test-case "zonk-ctx: zonks types in context"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat) "test"))
    (solve-meta! (expr-meta-id m) (expr-Nat))
    (define ctx (ctx-extend ctx-empty m 'mw))
    (define zonked (zonk-ctx ctx))
    (check-equal? (car (car zonked)) (expr-Nat))
    (check-equal? (cdr (car zonked)) 'mw)))

;; ========================================
;; Pretty-print
;; ========================================

(test-case "pp-expr: unsolved meta prints as ?meta..."
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat) "test"))
    (define output (pp-expr m))
    (check-true (string-prefix? output "?"))))

(test-case "pp-expr: solved meta prints its solution"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat) "test"))
    (solve-meta! (expr-meta-id m) (expr-zero))
    (check-equal? (pp-expr m) "0N")))

;; ========================================
;; expr? predicate
;; ========================================

(test-case "expr?: expr-meta is recognized as expression"
  (check-true (expr? (expr-meta 'test-id))))
