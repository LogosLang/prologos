#lang racket/base

;;;
;;; Tests for Phase 1c: Narrowing Propagator
;;; Tests narrowing.rkt — propagator installation from definitional trees,
;;; deterministic evaluation (ground args), residuation (bot cells),
;;; contradiction detection (exempt branches), and demand analysis.
;;;

(require rackunit
         racket/match
         racket/list
         "../propagator.rkt"
         "../term-lattice.rkt"
         "../definitional-tree.rkt"
         "../narrowing.rkt"
         "../macros.rkt"
         "../syntax.rkt")

;; ========================================
;; Helpers
;; ========================================

;; Make a read function for term-walk from a network
(define (make-reader net)
  (lambda (cid) (net-cell-read net cid)))

;; Read a cell's walked value
(define (read-walked net cid)
  (term-walk (net-cell-read net cid) (make-reader net)))

;; Convert a cell value to a datum (for readable assertions)
(define (cell->datum net cid)
  (term->datum (net-cell-read net cid) (make-reader net)))

;; ========================================
;; A. Manual definitional trees — unit tests
;; ========================================

;; Build a DT for `not`:
;;   not true  = false
;;   not false = true
;; DT:
;;   Branch(0, Bool, [(true → Rule(false)), (false → Rule(true))])
(define not-tree
  (dt-branch
   0 'Bool
   (list (cons 'true  (dt-rule (expr-false)))
         (cons 'false (dt-rule (expr-true))))))

(test-case "narrow/not-true"
  ;; not(true) = false
  (define net0 (make-prop-network))
  (define-values (net1 arg-cells result-cell)
    (narrow-function net0 'not not-tree 1))
  ;; Write true to arg[0]
  (define net2 (net-cell-write net1 (car arg-cells) (term-ctor 'true '())))
  (define net3 (run-to-quiescence net2))
  (check-false (net-contradiction? net3))
  (check-equal? (cell->datum net3 result-cell) 'false))

(test-case "narrow/not-false"
  ;; not(false) = true
  (define net0 (make-prop-network))
  (define-values (net1 arg-cells result-cell)
    (narrow-function net0 'not not-tree 1))
  (define net2 (net-cell-write net1 (car arg-cells) (term-ctor 'false '())))
  (define net3 (run-to-quiescence net2))
  (check-false (net-contradiction? net3))
  (check-equal? (cell->datum net3 result-cell) 'true))

(test-case "narrow/not-residuate"
  ;; not(bot) — should residuate (result stays bot)
  (define net0 (make-prop-network))
  (define-values (net1 arg-cells result-cell)
    (narrow-function net0 'not not-tree 1))
  (define net2 (run-to-quiescence net1))
  (check-false (net-contradiction? net2))
  (check-true (term-bot? (read-walked net2 result-cell))))

;; ========================================
;; B. is-zero: Nat → Bool  (mixing types in branch/rule)
;; ========================================

;; is-zero zero    = true
;; is-zero (suc _) = false
(define is-zero-tree
  (dt-branch
   0 'Nat
   (list (cons 'zero (dt-rule (expr-true)))
         (cons 'suc  (dt-rule (expr-false))))))

(test-case "narrow/is-zero-zero"
  (define net0 (make-prop-network))
  (define-values (net1 arg-cells result-cell)
    (narrow-function net0 'is-zero is-zero-tree 1))
  (define net2 (net-cell-write net1 (car arg-cells) (term-ctor 'zero '())))
  (define net3 (run-to-quiescence net2))
  (check-false (net-contradiction? net3))
  (check-equal? (cell->datum net3 result-cell) 'true))

(test-case "narrow/is-zero-suc"
  (define net0 (make-prop-network))
  (define-values (net1 arg-cells result-cell)
    (narrow-function net0 'is-zero is-zero-tree 1))
  ;; suc needs a sub-cell
  (define-values (net1a sub-cid) (net-new-cell net1 (term-ctor 'zero '()) term-merge term-contradiction?))
  (define net2 (net-cell-write net1a (car arg-cells) (term-ctor 'suc (list sub-cid))))
  (define net3 (run-to-quiescence net2))
  (check-false (net-contradiction? net3))
  (check-equal? (cell->datum net3 result-cell) 'false))

;; ========================================
;; C. Exempt (partial function)
;; ========================================

;; A partial function: only handles 'true', exempt for 'false'
(define partial-tree
  (dt-branch
   0 'Bool
   (list (cons 'true (dt-rule (expr-zero)))
         (cons 'false (dt-exempt)))))

(test-case "narrow/exempt-contradiction"
  (define net0 (make-prop-network))
  (define-values (net1 arg-cells result-cell)
    (narrow-function net0 'partial partial-tree 1))
  ;; Exempt branch installs contradiction immediately during tree walk.
  ;; When we write 'false', the branch propagator fires and hits the exempt child.
  (define net2 (net-cell-write net1 (car arg-cells) (term-ctor 'false '())))
  (define net3 (run-to-quiescence net2))
  (check-true (net-contradiction? net3)))

(test-case "narrow/exempt-non-exempt-branch-ok"
  (define net0 (make-prop-network))
  (define-values (net1 arg-cells result-cell)
    (narrow-function net0 'partial partial-tree 1))
  (define net2 (net-cell-write net1 (car arg-cells) (term-ctor 'true '())))
  (define net3 (run-to-quiescence net2))
  (check-false (net-contradiction? net3))
  (check-equal? (cell->datum net3 result-cell) 'zero))

;; ========================================
;; D. Or-branches (non-deterministic)
;; ========================================

;; A non-deterministic function with overlapping patterns:
;; f true  = zero   (branch 1)
;; f true  = suc(zero)  (branch 2)
;; f false = zero
(define or-tree
  (dt-branch
   0 'Bool
   (list (cons 'true (dt-or (list (dt-rule (expr-zero))
                                  (dt-rule (expr-suc (expr-zero))))))
         (cons 'false (dt-rule (expr-zero))))))

(test-case "narrow/or-branch-false"
  ;; false case is deterministic
  (define net0 (make-prop-network))
  (define-values (net1 arg-cells result-cell)
    (narrow-function net0 'f or-tree 1))
  (define net2 (net-cell-write net1 (car arg-cells) (term-ctor 'false '())))
  (define net3 (run-to-quiescence net2))
  (check-false (net-contradiction? net3))
  (check-equal? (cell->datum net3 result-cell) 'zero))

(test-case "narrow/or-branch-true"
  ;; true case: both branches install propagators, both fire.
  ;; Without ATMS amb (Phase 1d), both write to the same result cell:
  ;; zero ⊔ suc(zero) = top (contradiction).  This is expected —
  ;; non-deterministic functions require ATMS worldview semantics
  ;; to enumerate solutions.  Phase 1c detects the conflict correctly.
  (define net0 (make-prop-network))
  (define-values (net1 arg-cells result-cell)
    (narrow-function net0 'f or-tree 1))
  (define net2 (net-cell-write net1 (car arg-cells) (term-ctor 'true '())))
  (define net3 (run-to-quiescence net2))
  ;; Contradiction because both branches write incompatible values
  (check-true (net-contradiction? net3)))

;; Or-branches where both branches agree (same result → no contradiction)
(define or-agree-tree
  (dt-branch
   0 'Bool
   (list (cons 'true (dt-or (list (dt-rule (expr-zero))
                                  (dt-rule (expr-zero)))))
         (cons 'false (dt-rule (expr-zero))))))

(test-case "narrow/or-branch-compatible"
  ;; Both or-branches return zero → zero ⊔ zero = zero (no contradiction)
  (define net0 (make-prop-network))
  (define-values (net1 arg-cells result-cell)
    (narrow-function net0 'f or-agree-tree 1))
  (define net2 (net-cell-write net1 (car arg-cells) (term-ctor 'true '())))
  (define net3 (run-to-quiescence net2))
  (check-false (net-contradiction? net3))
  (check-equal? (cell->datum net3 result-cell) 'zero))

;; ========================================
;; E. Demand analysis
;; ========================================

(test-case "narrow/demands-all-bot"
  ;; All args are bot → all are demands
  (define net0 (make-prop-network))
  (define-values (net1 arg-cells result-cell)
    (narrow-function net0 'not not-tree 1))
  (check-equal? (length (narrowing-demands net1 arg-cells)) 1))

(test-case "narrow/demands-all-determined"
  ;; Arg is determined → no demands
  (define net0 (make-prop-network))
  (define-values (net1 arg-cells result-cell)
    (narrow-function net0 'not not-tree 1))
  (define net2 (net-cell-write net1 (car arg-cells) (term-ctor 'true '())))
  (check-equal? (length (narrowing-demands net2 arg-cells)) 0))

;; ========================================
;; F. Two-argument function: and
;; ========================================

;; and true  true  = true
;; and true  false = false
;; and false _     = false
;;
;; DT:
;;   Branch(0, Bool,
;;     [(true → Branch(1, Bool,
;;                [(true → Rule(true)),
;;                 (false → Rule(false))])),
;;      (false → Rule(false))])
(define and-tree
  (dt-branch
   0 'Bool
   (list
    (cons 'true
          (dt-branch
           1 'Bool
           (list (cons 'true  (dt-rule (expr-true)))
                 (cons 'false (dt-rule (expr-false))))))
    (cons 'false (dt-rule (expr-false))))))

(test-case "narrow/and-true-true"
  (define net0 (make-prop-network))
  (define-values (net1 arg-cells result-cell)
    (narrow-function net0 'and and-tree 2))
  (define net2 (net-cell-write
                (net-cell-write net1 (first arg-cells) (term-ctor 'true '()))
                (second arg-cells) (term-ctor 'true '())))
  (define net3 (run-to-quiescence net2))
  (check-false (net-contradiction? net3))
  (check-equal? (cell->datum net3 result-cell) 'true))

(test-case "narrow/and-true-false"
  (define net0 (make-prop-network))
  (define-values (net1 arg-cells result-cell)
    (narrow-function net0 'and and-tree 2))
  (define net2 (net-cell-write
                (net-cell-write net1 (first arg-cells) (term-ctor 'true '()))
                (second arg-cells) (term-ctor 'false '())))
  (define net3 (run-to-quiescence net2))
  (check-false (net-contradiction? net3))
  (check-equal? (cell->datum net3 result-cell) 'false))

(test-case "narrow/and-false-bot"
  ;; and(false, _) = false  — second arg doesn't matter
  (define net0 (make-prop-network))
  (define-values (net1 arg-cells result-cell)
    (narrow-function net0 'and and-tree 2))
  (define net2 (net-cell-write net1 (first arg-cells) (term-ctor 'false '())))
  (define net3 (run-to-quiescence net2))
  (check-false (net-contradiction? net3))
  (check-equal? (cell->datum net3 result-cell) 'false))

(test-case "narrow/and-residuate-first-arg"
  ;; Both args bot → result should be bot (residuate)
  (define net0 (make-prop-network))
  (define-values (net1 arg-cells result-cell)
    (narrow-function net0 'and and-tree 2))
  (define net2 (run-to-quiescence net1))
  (check-false (net-contradiction? net2))
  (check-true (term-bot? (read-walked net2 result-cell))))

(test-case "narrow/and-demands-two-args"
  (define net0 (make-prop-network))
  (define-values (net1 arg-cells result-cell)
    (narrow-function net0 'and and-tree 2))
  (check-equal? (length (narrowing-demands net1 arg-cells)) 2))

(test-case "narrow/and-demands-one-arg"
  ;; After setting first arg to true, second arg is still a demand
  (define net0 (make-prop-network))
  (define-values (net1 arg-cells result-cell)
    (narrow-function net0 'and and-tree 2))
  (define net2 (run-to-quiescence
                (net-cell-write net1 (first arg-cells) (term-ctor 'true '()))))
  (check-equal? (length (narrowing-demands net2 arg-cells)) 1)
  (check-equal? (car (narrowing-demands net2 arg-cells)) (second arg-cells)))

;; ========================================
;; G. Rule with bound variable in RHS
;; ========================================

;; identity: id x = x
;; DT: Rule(bvar 0)  (trivially, no branching needed)
;; But since there's no match, it's not a dt-branch — it's a dt-rule with
;; an identity RHS.  However, extract-definitional-tree returns #f for
;; non-matching functions.  For testing narrowing, we build a tree that
;; branches on Bool and returns the bound value:
;;
;; echo true  = true
;; echo false = false
;; (same as id restricted to Bool, but with explicit branches)
(define echo-tree
  (dt-branch
   0 'Bool
   (list (cons 'true  (dt-rule (expr-true)))
         (cons 'false (dt-rule (expr-false))))))

;; This is just `not`-style but identity, already tested.
;; More interesting: a function that RETURNS its bound pattern variable.

;; suc-of: suc-of (suc x) = x  (extract the predecessor)
;; DT: Branch(0, Nat, [(suc → Rule(bvar 0))])
;; When the branch matches suc(sub-cell), bvar 0 refers to sub-cell.
(define pred-tree
  (dt-branch
   0 'Nat
   (list (cons 'zero (dt-exempt))
         (cons 'suc (dt-rule (expr-bvar 0))))))

(test-case "narrow/pred-suc-zero"
  ;; pred(suc(zero)) = zero
  (define net0 (make-prop-network))
  (define-values (net1 arg-cells result-cell)
    (narrow-function net0 'pred pred-tree 1))
  ;; Build suc(zero): create sub-cell for zero, then write suc to arg
  (define-values (net2 zero-cid)
    (net-new-cell net1 (term-ctor 'zero '()) term-merge term-contradiction?))
  (define net3 (net-cell-write net2 (car arg-cells) (term-ctor 'suc (list zero-cid))))
  (define net4 (run-to-quiescence net3))
  (check-false (net-contradiction? net4))
  (check-equal? (cell->datum net4 result-cell) 'zero))

(test-case "narrow/pred-suc-suc-zero"
  ;; pred(suc(suc(zero))) = suc(zero)
  (define net0 (make-prop-network))
  (define-values (net1 arg-cells result-cell)
    (narrow-function net0 'pred pred-tree 1))
  (define-values (net2 zero-cid)
    (net-new-cell net1 (term-ctor 'zero '()) term-merge term-contradiction?))
  (define-values (net3 suc-zero-cid)
    (net-new-cell net2 (term-ctor 'suc (list zero-cid)) term-merge term-contradiction?))
  (define net4 (net-cell-write net3 (car arg-cells) (term-ctor 'suc (list suc-zero-cid))))
  (define net5 (run-to-quiescence net4))
  (check-false (net-contradiction? net5))
  (check-equal? (cell->datum net5 result-cell) '(suc zero)))

(test-case "narrow/pred-zero-exempt"
  ;; pred(zero) → exempt → contradiction
  (define net0 (make-prop-network))
  (define-values (net1 arg-cells result-cell)
    (narrow-function net0 'pred pred-tree 1))
  (define net2 (net-cell-write net1 (car arg-cells) (term-ctor 'zero '())))
  (define net3 (run-to-quiescence net2))
  (check-true (net-contradiction? net3)))

;; ========================================
;; H. RHS with constructor application (suc of bvar)
;; ========================================

;; suc-of: suc-of x = suc(x)
;; We model this as: Branch(0, Nat, [(zero → Rule(suc(zero))), (suc → Rule(suc(suc(bvar 0))))])
;; Simpler: just test suc(zero) as constant
(define always-suc-zero-tree
  (dt-branch
   0 'Bool
   (list (cons 'true  (dt-rule (expr-suc (expr-zero))))
         (cons 'false (dt-rule (expr-suc (expr-zero)))))))

(test-case "narrow/rule-with-suc-ctor"
  (define net0 (make-prop-network))
  (define-values (net1 arg-cells result-cell)
    (narrow-function net0 'f always-suc-zero-tree 1))
  (define net2 (net-cell-write net1 (car arg-cells) (term-ctor 'true '())))
  (define net3 (run-to-quiescence net2))
  (check-false (net-contradiction? net3))
  (check-equal? (cell->datum net3 result-cell) '(suc zero)))

;; ========================================
;; I. nat->term and term-from-ground-expr
;; ========================================

(test-case "narrow/nat-to-term-zero"
  (define-values (net term) (nat->term 0 (make-prop-network)))
  (check-equal? (term-ctor-tag term) 'zero)
  (check-equal? (term-ctor-sub-cells term) '()))

(test-case "narrow/nat-to-term-three"
  (define net0 (make-prop-network))
  (define-values (net term) (nat->term 3 net0))
  (check-equal? (term-ctor-tag term) 'suc)
  ;; Verify it's suc(suc(suc(zero))) by walking
  (check-equal? (term->datum term (make-reader net)) '(suc (suc (suc zero)))))

(test-case "narrow/term-from-ground-expr-zero"
  (define-values (net term) (term-from-ground-expr (expr-zero) (make-prop-network)))
  (check-equal? term (term-ctor 'zero '())))

(test-case "narrow/term-from-ground-expr-nat-val"
  (define-values (net term) (term-from-ground-expr (expr-nat-val 2) (make-prop-network)))
  (check-equal? (term->datum term (make-reader net)) '(suc (suc zero))))

;; ========================================
;; J. Backward compatibility: ground args produce same result as reducer
;; ========================================

;; Verify that when all args are ground, the narrowing propagator produces
;; the expected result (same as direct reduction would).

(test-case "narrow/ground-not-true-eq-false"
  (define net0 (make-prop-network))
  (define-values (net1 args res) (narrow-function net0 'not not-tree 1))
  (define net2 (run-to-quiescence (net-cell-write net1 (car args) (term-ctor 'true '()))))
  (check-equal? (cell->datum net2 res) 'false))

(test-case "narrow/ground-and-true-true-eq-true"
  (define net0 (make-prop-network))
  (define-values (net1 args res) (narrow-function net0 'and and-tree 2))
  (define net2 (run-to-quiescence
                (net-cell-write
                 (net-cell-write net1 (first args) (term-ctor 'true '()))
                 (second args) (term-ctor 'true '()))))
  (check-equal? (cell->datum net2 res) 'true))

(test-case "narrow/ground-is-zero-suc-eq-false"
  (define net0 (make-prop-network))
  (define-values (net1 args res) (narrow-function net0 'is-zero is-zero-tree 1))
  (define-values (net2 sub-cid) (net-new-cell net1 (term-ctor 'zero '()) term-merge term-contradiction?))
  (define net3 (run-to-quiescence (net-cell-write net2 (car args) (term-ctor 'suc (list sub-cid)))))
  (check-equal? (cell->datum net3 res) 'false))

;; ========================================
;; K. Nested branching: two levels deep
;; ========================================

;; f (suc (suc _)) = true
;; f (suc zero)    = false
;; f zero           = false
;;
;; DT:
;;   Branch(0, Nat,
;;     [(zero → Rule(false)),
;;      (suc → Branch(0', Nat,  [nested: scrutinee is the suc's sub-cell]
;;               [(zero → Rule(false)),
;;                (suc → Rule(true))]))])
;;
;; NOTE: In the nested branch, the "position" refers to which sub-cell
;; of the outer constructor is being scrutinized.  Since the outer match
;; already decomposed arg[0] into suc(sub-cell), the inner match is on
;; the sub-cell.  We model this by having the inner branch's watched cell
;; be the sub-cell from the outer binding.
;;
;; However, our current install-narrowing-propagators uses arg-cells[pos]
;; for the watched cell, which won't work for nested matches.  For nested
;; branches, we need a different approach — the bindings list.
;;
;; Actually, looking at how extract-definitional-tree works: nested
;; dt-branch nodes have position=0 which refers to the first binding
;; from the outer match.  But our implementation uses arg-cells[pos],
;; not bindings[pos].  This is a subtlety.
;;
;; For Phase 1c, we test the basic cases that work (single-level branching).
;; Nested branching requires the branch fire-fn to use bindings, which
;; is a refinement.

;; Test: nested match via a manually constructed tree where the inner
;; branch's position still refers to arg-cells (position 0).
;; This works for the `and` case above (Branch(0) → Branch(1)).

(test-case "narrow/nested-branch-and-false-true"
  ;; and(false, true) = false
  (define net0 (make-prop-network))
  (define-values (net1 args res) (narrow-function net0 'and and-tree 2))
  (define net2 (run-to-quiescence
                (net-cell-write
                 (net-cell-write net1 (first args) (term-ctor 'false '()))
                 (second args) (term-ctor 'true '()))))
  (check-equal? (cell->datum net2 res) 'false))

(test-case "narrow/nested-branch-and-false-false"
  ;; and(false, false) = false
  (define net0 (make-prop-network))
  (define-values (net1 args res) (narrow-function net0 'and and-tree 2))
  (define net2 (run-to-quiescence
                (net-cell-write
                 (net-cell-write net1 (first args) (term-ctor 'false '()))
                 (second args) (term-ctor 'false '()))))
  (check-equal? (cell->datum net2 res) 'false))
