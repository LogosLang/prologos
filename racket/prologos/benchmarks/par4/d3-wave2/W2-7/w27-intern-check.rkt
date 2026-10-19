#lang racket/base
;; W2-7: are leaf expressions interned (so two occurrences share ONE attribute-map position, i.e. two :usage writers)?
(require (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/syntax.rkt")
                  expr-Nat expr-zero expr-bvar expr-Bool expr-fvar))
(printf "eq? (expr-Nat) (expr-Nat): ~a\n" (eq? (expr-Nat) (expr-Nat)))
(printf "eq? (expr-zero) (expr-zero): ~a\n" (eq? (expr-zero) (expr-zero)))
(printf "eq? (expr-bvar 0) (expr-bvar 0): ~a\n" (eq? (expr-bvar 0) (expr-bvar 0)))
(printf "eq? (expr-fvar 'f) (expr-fvar 'f): ~a\n" (eq? (expr-fvar 'f) (expr-fvar 'f)))
