#lang racket/base
;; C9 (g): the :usage lean of D.2 §6.3 row 4 ("writes carry totals computed inside the fire; the cell merge
;; is the pointwise join on the multiplicity information order"), using the REAL qtt.rkt / prelude.rkt ops.
;; G1  monotonicity of +, ·, ⊔ on the chain m0 < m1 < mw (exhaustive): settles D2L-5's arity question.
;; G2  x used in THREE children (f x x y) and in TWO sibling branches (if c then x else y), linear x:
;;     the fire-computed totals, the lean's merge if those usages met in the cell, today's merge
;;     (add-usage across successive writes) and the linear-per-path gate (qtt.rkt:130-182).
(require racket/list
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/prelude.rkt")
                  mult-add mult-mul mult-join mult-leq compatible)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/qtt.rkt")
                  add-usage join-usage single-usage zero-usage))
;; join-branches is not provided: read it from the same module instance
(define-namespace-anchor anchor)
(define join-branches
  (parameterize ([current-namespace (namespace-anchor->namespace anchor)])
    (eval 'join-branches
          (module->namespace '(file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/qtt.rkt")))))
(define M '(m0 m1 mw))
(define (leq a b) (mult-leq a b))
(define (monotone2? op)
  (for*/and ([a M] [a2 M] [b M] [b2 M] #:when (and (leq a a2) (leq b b2)))
    (leq (op a b) (op a2 b2))))
(printf "== G1: monotone on m0<m1<mw (all 81 pairs of pairs): + ~a  · ~a  ⊔ ~a\n"
        (monotone2? mult-add) (monotone2? mult-mul) (monotone2? mult-join))
(printf "   ⊔ is the max of the chain (mult-join a b = max): ~a ; + is NOT idempotent: m1+m1 = ~a\n"
        (for*/and ([a M] [b M]) (eq? (mult-join a b) (if (leq a b) b a))) (mult-add 'm1 'm1))

;; context: one binder x (declared m1). Usage vectors have length 1.
(define ux (single-usage 0 1)) (define u0 (zero-usage 1))
(printf "== G2: linear x (declared m1)\n")
(define three (list ux ux u0))                              ; f x x y : x in two of three children
(printf "  three children, fire-computed total (foldl add-usage, typing-propagators.rkt:1796): ~a  compatible(m1,·)=~a\n"
        (foldl add-usage (car three) (cdr three)) (compatible 'm1 (car (foldl add-usage (car three) (cdr three)))))
(printf "  same three usages if they MET IN THE CELL under the lean's max merge: ~a  compatible=~a  (under-count)\n"
        (foldl join-usage (car three) (cdr three)) (compatible 'm1 (car (foldl join-usage (car three) (cdr three)))))
(printf "  today's merge on a re-write of the same total (add-usage old new): ~a (the equal? guard at typing-propagators.rkt:466 hides it)\n"
        (add-usage ux ux))
(define ctx (list (cons 'X 'm1)))
(printf "  sibling branches b1 uses x, b2 does not: join-branches (linear-per-path gate) = ~a ; max/mult-join = ~a (affine leak)\n"
        (join-branches ctx ux u0) (join-usage ux u0))
(printf "  sibling branches both use x once: join-branches = ~a ; add-usage = ~a (over-count)\n"
        (join-branches ctx ux ux) (add-usage ux ux))
