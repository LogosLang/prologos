#lang racket/base
;; C8 probe: D.2 §6.3 says E "is evaluated once per merge function, not per cell, so its cost is a registration-time
;; cost", and E's verdict keys the fence. promote-cell-to-tagged (propagator.rkt:1804) installs
;; (make-tagged-merge domain-merge) (decision-cell.rkt:526), a fresh closure, at every promotion. BSP-LE 3's seed
;; needs promotion of table/scope cells (seed :37-41; relations.rkt has 5 promotion sites; typing-propagators.rkt:1211).
;; Question: do two promotions over the SAME domain merge install the same merge object (so a per-function E verdict
;; would carry over), or a fresh one each time?
(require (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))
(define champ-lookup (dynamic-require (string->path "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/champ.rkt") 'champ-lookup))
(define mx (lambda (a b) (max a b)))
(define net0 (make-prop-network))
(define-values (n1 a) (net-new-cell net0 0 mx))
(define-values (n2 b) (net-new-cell n1 0 mx))
(define (merge-of net cid) (champ-lookup (prop-network-merge-fns net) (cell-id-hash cid) cid))
(printf "before promotion: merge(a) eq? merge(b): ~a ; eq? mx: ~a\n" (eq? (merge-of n2 a) (merge-of n2 b)) (eq? (merge-of n2 a) mx))
(define n3 (promote-cell-to-tagged (promote-cell-to-tagged n2 a) b))
(printf "after promotion:  merge(a) eq? merge(b): ~a ; merge(a) eq? mx: ~a\n" (eq? (merge-of n3 a) (merge-of n3 b)) (eq? (merge-of n3 a) mx))
(printf "re-promote a (idempotent?): merge unchanged: ~a\n" (eq? (merge-of (promote-cell-to-tagged n3 a) a) (merge-of n3 a)))
