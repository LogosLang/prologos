#lang racket/base
;; C2 probe: does the Tier-1 flush (propagator.rkt:3431-3445) drop the dependents its writes enqueue?
;; Network: cell A, cell B (max merge). P1: A -> B copy (normal propagator), installed and run first.
;; Then install P0: fire-once, EMPTY inputs, writes A := 7. Worklist = [P0] only => Tier-1 eligible.
;; Expected (any correct scheduler): B = 7. Control: same with P0 as a normal (non-fire-once) empty-input propagator (Tier 2).
(require (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))
(define (build fire-once?)
  (define net0 (make-prop-network))
  (define-values (net1 a) (net-new-cell net0 0 max))
  (define-values (net2 b) (net-new-cell net1 0 max))
  (define-values (net3 _p1) (net-add-propagator net2 (list a) (list b)
                               (lambda (n) (net-cell-write n b (net-cell-read n a)))))
  (define net4 (run-to-quiescence net3))           ; P1 fires once on A=0; quiescent
  (define-values (net5 _p0)
    (if fire-once?
        (net-add-fire-once-propagator net4 '() (list a) (lambda (n) (net-cell-write n a 7)))
        (net-add-propagator net4 '() (list a) (lambda (n) (net-cell-write n a 7)))))
  (printf "  worklist before run: ~a (worldview cell-1 = ~a)\n" (prop-network-worklist net5) (net-cell-read net5 worldview-cache-cell-id))
  (define out (run-to-quiescence net5))
  (printf "  after run: A = ~a, B = ~a, worklist = ~a\n" (net-cell-read out a) (net-cell-read out b) (prop-network-worklist out))
  (define out2 (run-to-quiescence out))
  (printf "  after a SECOND run-to-quiescence: B = ~a\n" (net-cell-read out2 b)))
(printf "fire-once + empty inputs (Tier-1 path):\n") (build #t)
(printf "control: plain propagator, empty inputs (Tier-2 path):\n") (build #f)
(printf "drain (current-use-bsp-scheduler? #f), fire-once:\n")
(parameterize ([current-use-bsp-scheduler? #f]) (build #t))
