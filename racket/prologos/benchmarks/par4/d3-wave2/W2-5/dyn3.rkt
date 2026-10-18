#lang racket/base
;; W2-5 dynamic probe 3 (PAR 4 D.3 wave 2, CL-13): PER-PARAMETER attribution of stale-value
;; dependence, on the real S0 fires, no rebuild.
;; At harness start (after module load, before process-file) a thread records every production
;; parameter's value as that thread sees it: the CREATION-TIME value, i.e. what a persistent
;; executor created once per process holds when nothing re-installs the parameterization.
;; For every BSP round (sequential executor on the main thread):
;;   R1 = fire every pid against the snapshot (the result the run continues with);
;;   R2 = again (determinism control);
;;   for every parameter p whose creation-time value is not eq? to main's current value:
;;     Rp = fire every pid with ONLY p re-bound (parameterize) to its creation-time value;
;;     a fire DEPENDS ON p when Rp_i ≠ R1_i (equal?) while R2_i = R1_i.
;;   Power row: WV-POISON = current-worldview-bitmask re-bound to bit 60.
;; usage: racket dyn3.rkt <census-params.tsv> <file.prologos>
(require racket/list racket/string racket/port racket/file
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
                  prop-network-propagators prop-id-hash propagator-fire-fn)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/champ.rkt")
                  champ-lookup))
(define ROOT "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/")
(define (dr m n) (dynamic-require (list 'file (string-append ROOT m)) n))
(define process-file (dr "driver.rkt" 'process-file))
(define current-parallel-executor (dr "propagator.rkt" 'current-parallel-executor))
(define current-worldview-bitmask (dr "propagator.rkt" 'current-worldview-bitmask))
(define fire-and-collect-writes (dr "propagator.rkt" 'fire-and-collect-writes))
(define tsv (vector-ref (current-command-line-arguments) 0))
(define file (vector-ref (current-command-line-arguments) 1))

(define PARAMS
  (for/fold ([acc '()] #:result (reverse acc))
            ([ln (in-list (cdr (file->lines tsv)))])
    (define cols (string-split ln "\t" #:trim? #f))
    (define name (string->symbol (car cols)))
    (define mp (list 'file (string-append ROOT (car (string-split (cadr cols) ":")))))
    (define v (with-handlers ([exn:fail? (lambda (e) (with-handlers ([exn:fail? (lambda (e2) #f)])
                                                       (parameterize ([current-namespace (module->namespace mp)])
                                                         (namespace-variable-value name #t))))])
                (dynamic-require mp name)))
    (if (parameter? v) (cons (cons name v) acc) acc)))
;; creation-time values, read on a thread created now
(define creation
  (let ([ch (make-channel)])
    (thread #:pool 'own (lambda () (channel-put ch (for/list ([p (in-list PARAMS)]) ((cdr p))))))
    (channel-get ch)))

(define (fire-all snap pids)
  (for/list ([pid (in-list pids)] [idx (in-naturals 1)])
    (with-handlers ([(lambda (e) #t) (lambda (e) (list 'EXN (if (exn? e) (exn-message e) e)))])
      (fire-and-collect-writes snap pid idx))))
(define (fn-name snap pid)
  (define p (champ-lookup (prop-network-propagators snap) (prop-id-hash pid) pid))
  (if (eq? p 'none) "?" (format "~a" (or (object-name (propagator-fire-fn p)) "anon"))))

(define dep (make-hash))       ; param -> divergent fire count
(define dep-fns (make-hash))   ; param -> hash fn-name -> count
(define stale-rounds (make-hash)) ; param -> rounds where creation value not eq? to main's
(define rounds 0) (define nfires 0) (define ctrl 0) (define nested 0)
(define in-exec (make-parameter #f))
(define (note! key snap pids R1 R2 Rp)
  (for ([pid (in-list pids)] [a (in-list R1)] [b (in-list R2)] [x (in-list Rp)])
    (when (and (equal? a b) (not (equal? a x)))
      (hash-update! dep key add1 0)
      (hash-update! (hash-ref! dep-fns key make-hash) (fn-name snap pid) add1 0))))

(define (exec snap pids)
  (cond
    [(in-exec) (set! nested (add1 nested)) (fire-all snap pids)]
    [else
     (parameterize ([in-exec #t])
       (set! rounds (add1 rounds))
       (set! nfires (+ nfires (length pids)))
       (define R1 (fire-all snap pids))
       (define R2 (fire-all snap pids))
       (for ([a (in-list R1)] [b (in-list R2)]) (unless (equal? a b) (set! ctrl (add1 ctrl))))
       (for ([p (in-list PARAMS)] [cv (in-list creation)])
         (define param (cdr p))
         (unless (eq? (param) cv)
           (hash-update! stale-rounds (car p) add1 0)
           (define Rp (parameterize ([param cv]) (fire-all snap pids)))
           (note! (car p) snap pids R1 R2 Rp)))
       ;; power row
       (define Rw (parameterize ([current-worldview-bitmask (arithmetic-shift 1 60)]) (fire-all snap pids)))
       (note! 'WV-POISON snap pids R1 R2 Rw)
       (for ([a (in-list R1)]) (when (and (pair? a) (eq? (car a) 'EXN)) (error 'fire (cadr a))))
       R1)]))

(define t0 (current-inexact-milliseconds))
(define results
  (with-handlers ([(lambda (e) #t) (lambda (e) (list (format "HARNESS-EXCEPTION: ~a" (if (exn? e) (exn-message e) e))))])
    (parameterize ([current-parallel-executor exec] [current-output-port (open-output-nowhere)])
      (process-file file))))
(printf "STATS3 file=~a results=~a rounds=~a fires=~a control-divergent=~a nested=~a stale-params=~a ms=~a\n"
        file (length results) rounds nfires ctrl nested (hash-count stale-rounds) (round (- (current-inexact-milliseconds) t0)))
(for ([(k v) (in-hash dep)])
  (printf "DEP ~a fires=~a stale-rounds=~a fns=~a\n" k v (hash-ref stale-rounds k 'n/a)
          (string-join (for/list ([(f n) (in-hash (hash-ref dep-fns k))]) (format "~a×~a" f n)) ", ")))
