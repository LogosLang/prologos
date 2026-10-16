#lang racket/base
;; C8 probe: the BSP-LE master defines SLG completion as "a tabled predicate is complete when its table cell has
;; quiesced (no new answers after a full round)" (2026-03-21_BSP_LE_MASTER.md:149, :154). Is per-cell, one-round
;; stability sound even under BSP? Chain a -> b -> c -> t plus a -> t; t is a set-union "table" cell.
;; The observer prints, per BSP round, whether t changed and t's held value.
(require racket/set
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))
(define mx (lambda (a b) (max a b)))
(define net0 (make-prop-network))
(define-values (n1 a) (net-new-cell net0 0 mx))
(define-values (n2 b) (net-new-cell n1 0 mx))
(define-values (n3 c) (net-new-cell n2 0 mx))
(define-values (n4 t) (net-new-cell n3 (set) set-union))
(define (when-pos src f) (lambda (net) (let ([v (net-cell-read net src)]) (if (> v 0) (f net v) net))))
(define-values (n5 pid0) (net-add-propagator n4 (list a) (list t) (when-pos a (lambda (net v) (net-cell-write net t (set 'direct))))))
(define-values (n6 pid1) (net-add-propagator n5 (list a) (list b) (when-pos a (lambda (net v) (net-cell-write net b v)))))
(define-values (n7 pid2) (net-add-propagator n6 (list b) (list c) (when-pos b (lambda (net v) (net-cell-write net c v)))))
(define-values (n8 pid3) (net-add-propagator n7 (list c) (list t) (when-pos c (lambda (net v) (net-cell-write net t (set 'via-chain))))))
(define n9 (net-cell-write n8 a 1))
;; make the run Tier 2 (not the Tier-1 flush): propagators have inputs, so the Tier-1 test fails anyway.
(define rounds '())
(define final
  (parameterize ([current-bsp-observer (lambda (r) (set! rounds (cons r rounds)))])
    (run-to-quiescence-bsp n9)))
(for ([r (in-list (reverse rounds))])
  (define changed (for/list ([d (in-list (bsp-round-cell-diffs r))]) (cell-diff-cell-id d)))
  (define t-changed? (and (member t changed) #t))
  (printf "round ~a: t changed? ~a   t held = ~s   cells written = ~s\n"
          (bsp-round-round-number r) t-changed?
          (set->list (net-cell-read (bsp-round-network-snapshot r) t))
          changed))
(printf "final t = ~s\n" (set->list (net-cell-read final t)))
