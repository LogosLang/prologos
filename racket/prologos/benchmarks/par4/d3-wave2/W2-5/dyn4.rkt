#lang racket/base
;; W2-5 dynamic probe 4: do S0 fires WRITE the shared boxes reached through parameters
;; (set-box! side channels: retry bridge resolution.rkt:386, solve-meta-core! metavar-store.rkt:2075-2108,
;; add-constraint! :1002-1066, punify unify.rkt:342/393/433)? Sequential executor on main; per round,
;; compare (unbox box) eq? before vs after the round's fires, for each box-valued parameter below.
;; Power row: POWER=1 adds one synthetic round whose fire set-box!es current-prop-net-box.
;; usage: racket dyn4.rkt <file.prologos>
(require racket/port)
(define ROOT "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/")
(define (dr m n) (dynamic-require (list 'file (string-append ROOT m)) n))
(define process-file (dr "driver.rkt" 'process-file))
(define current-parallel-executor (dr "propagator.rkt" 'current-parallel-executor))
(define sequential-fire-all (dr "propagator.rkt" 'sequential-fire-all))
(define boxes
  (list (cons 'current-prop-net-box (dr "metavar-store.rkt" 'current-prop-net-box))
        (cons 'current-prop-meta-info-box (dr "metavar-store.rkt" 'current-prop-meta-info-box))
        (cons 'current-persistent-registry-net-box (dr "metavar-store.rkt" 'current-persistent-registry-net-box))))
(define changed (make-hasheq)) (define rounds 0) (define fires 0)
(define (peek) (for/list ([b (in-list boxes)]) (let ([v ((cdr b))]) (and (box? v) (unbox v)))))
(define (exec snap pids)
  (set! rounds (add1 rounds)) (set! fires (+ fires (length pids)))
  (define before (peek))
  (define r (sequential-fire-all snap pids))
  (for ([b (in-list boxes)] [x (in-list before)] [y (in-list (peek))])
    (unless (eq? x y) (hash-update! changed (car b) add1 0)))
  r)
;; power row: one synthetic network whose fire set-box!es the box current-prop-net-box holds
(when (getenv "POWER")
  (define make-prop-network (dr "propagator.rkt" 'make-prop-network))
  (define net-new-cell (dr "propagator.rkt" 'net-new-cell))
  (define net-add-propagator (dr "propagator.rkt" 'net-add-propagator))
  (define net-cell-write (dr "propagator.rkt" 'net-cell-write))
  (define run-to-quiescence (dr "propagator.rkt" 'run-to-quiescence))
  (define cpnb (cdr (car boxes)))
  (define-values (n1 a) (net-new-cell (make-prop-network) 0 max))
  (define-values (n2 b) (net-new-cell n1 0 max))
  (define-values (n3 _) (net-add-propagator n2 (list a) (list b)
                                            (lambda (n) (set-box! (cpnb) 'written-in-fire) (net-cell-write n b 1))))
  (parameterize ([cpnb (box 'before)] [current-parallel-executor exec]) (run-to-quiescence n3))
  (printf "POWER ~s\n" changed))
(void (with-handlers ([(lambda (e) #t) (lambda (e) (printf "HARNESS-EXCEPTION ~a\n" (if (exn? e) (exn-message e) e)))])
        (parameterize ([current-parallel-executor exec] [current-output-port (open-output-nowhere)])
          (process-file (vector-ref (current-command-line-arguments) 0)))))
(printf "BOXWRITES rounds=~a fires=~a changed-during-fires=~s\n" rounds fires changed)
