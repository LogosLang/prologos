#lang racket/base
;; W2-10 user-level harness: run ONE .prologos file through process-file under one scheduler leg and print
;; one line per command result (errors with message + line:col), plus the BSP run/round census the LSP's
;; observer would have accumulated.
;; usage: racket run-leg.rkt FILE.prologos prod|seq|drain [eval|check]
;;   prod  = the executor driver.rkt:567 installs at load (make-parallel-thread-fire-all)
;;   seq   = sequential-fire-all injected through current-parallel-executor
;;   drain = current-use-bsp-scheduler? #f (Gauss-Seidel drain; reaches only run-to-quiescence callers)
(require racket/port racket/list racket/string
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt")
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/errors.rkt")
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))
(define args (current-command-line-arguments))
(define file (vector-ref args 0))
(define leg (string->symbol (vector-ref args 1)))
(define mode (if (> (vector-length args) 2) (vector-ref args 2) "eval"))
(define prod (current-parallel-executor))
;; observer: record (original round-number, #diffs, contradiction?) per BSP round, like the LSP's accumulator
(define rounds '())
(define (obs r)
  (set! rounds (cons (list (bsp-round-round-number r) (length (bsp-round-cell-diffs r))
                           (and (bsp-round-contradiction r) #t))
                     rounds)))
(define (show r)
  (cond [(prologos-error? r)
         (define loc (prologos-error-srcloc r))
         (format "ERROR@~a: ~a"
                 (if (srcloc? loc) (format "~a:~a" (srcloc-line loc) (srcloc-column loc)) "?")
                 (string-replace (prologos-error-message r) "\n" " ⏎ "))]
        [else (string-replace (format "~a" r) "\n" " ⏎ ")]))
(define t0 (current-inexact-monotonic-milliseconds))
(define rs
  (parameterize ([current-parallel-executor (case leg [(prod) prod] [(seq drain) sequential-fire-all])]
                 [current-use-bsp-scheduler? (not (eq? leg 'drain))]
                 [current-bsp-observer obs]
                 [current-error-port (open-output-nowhere)])
    (process-file file #:evaluate? (equal? mode "eval"))))
(define t1 (current-inexact-monotonic-milliseconds))
(for ([r rs] [i (in-naturals)]) (printf "~a: ~a\n" i (show r)))
(define rs* (reverse rounds))
(define runs (for/sum ([r rs*]) (if (zero? (car r)) 1 0)))
;; a run "ended in contradiction" if its last round carried one
(define run-ends
  (let loop ([xs rs*] [cur #f] [acc '()])
    (cond [(null? xs) (reverse (if cur (cons cur acc) acc))]
          [(zero? (car (car xs))) (loop (cdr xs) (car xs) (if cur (cons cur acc) acc))]
          [else (loop (cdr xs) (car xs) acc)])))
(eprintf "")
(printf "-- leg ~a: ~a results, ~a ms | observer: ~a BSP rounds in ~a runs, ~a diffs, ~a runs ending contradicted\n"
        leg (length rs) (round (- t1 t0)) (length rs*) runs (for/sum ([r rs*]) (cadr r))
        (for/sum ([e run-ends]) (if (caddr e) 1 0)))
