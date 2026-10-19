#lang racket/base
;;; C3 probe (PAR 4 D.3, critic C3). Read-only use of the worktree's compiled modules.
;;; One .prologos file per process.  Usage: racket home_fence_probe.rkt FILE.prologos
;;; Under BSP's observer, for every fired propagator:
;;;   - its home under D.2 §6.7's rule (owner of FIRST declared output, round-robin K=8);
;;;   - the merge of that first output (is it the attribute map, whose :type facet composes
;;;     type-unify-or-top via merge-classify-inhabit, classify-inhabit.rkt:171?);
;;;   - whether ANY output has merge attribute-map-merge-fn  => the fire is FENCED under D.2 §6.3's
;;;     per-cell fence while O-12 (ii) is open (lower bound on the fenced set).
;;; Per outermost elaborator quiescence call: rounds, rounds containing a fenced fire, and the number
;;; of maximal fenced/unfenced phase switches in BSP round order (a proxy, not the alternation count).
(require racket/list json racket/port
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt") process-file)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt") current-bsp-observer bsp-round-network-snapshot bsp-round-propagators-fired prop-network-merge-fns prop-network-propagators propagator-outputs cell-id-hash prop-id-hash cell-id-n)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/champ.rkt") champ-lookup)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/metavar-store.rkt") current-quiescence-scheduler))
(define the-file (vector-ref (current-command-line-arguments) 0))
(define K 8)
(define (fn-name f) (let ([n (and (procedure? f) (object-name f))]) (if n (format "~a" n) "anon")))
(define (merge-of snap cid)
  (define mf (champ-lookup (prop-network-merge-fns snap) (cell-id-hash cid) cid))
  (if (eq? mf 'none) "none" (fn-name mf)))
(define (inc! h k [d 1]) (hash-set! h k (+ d (hash-ref h k 0))))
(define FENCED "attribute-map-merge-fn")

(define home-hist (make-hasheqv))          ; executor -> fires
(define first-out-merge (make-hash))       ; merge name of first output -> fires
(define first-out-cell (make-hash))        ; (cell-n . merge) -> fires (top list)
(define fenced-fires 0) (define all-fires 0)
(define run-idx 0) (define depth 0)
(define runs (make-hasheqv))               ; run -> (vector rounds rounds-with-fenced switches last-kind fires fenced-fires)
(define (cur-run) (hash-ref! runs run-idx (λ () (vector 0 0 0 #f 0 0))))

(define (observe r)
  (define snap (bsp-round-network-snapshot r))
  (define props (prop-network-propagators snap))
  (define v (cur-run))
  (vector-set! v 0 (add1 (vector-ref v 0)))
  (define any-f #f) (define any-u #f)
  (for ([pid (in-list (bsp-round-propagators-fired r))])
    (define p (champ-lookup props (prop-id-hash pid) pid))
    (unless (eq? p 'none)
      (define outs (propagator-outputs p))
      (set! all-fires (add1 all-fires))
      (vector-set! v 4 (add1 (vector-ref v 4)))
      (cond
        [(pair? outs)
         (define c0 (car outs))
         (inc! home-hist (modulo (cell-id-n c0) K))
         (define m0 (merge-of snap c0))
         (inc! first-out-merge m0)
         (inc! first-out-cell (format "~a:~a" (cell-id-n c0) m0))]
        [else (inc! home-hist 'no-output) (inc! first-out-merge "no-output")])
      (define fenced? (for/or ([c (in-list outs)]) (equal? (merge-of snap c) FENCED)))
      (if fenced?
          (begin (set! fenced-fires (add1 fenced-fires)) (vector-set! v 5 (add1 (vector-ref v 5))) (set! any-f #t))
          (set! any-u #t))))
  (when any-f (vector-set! v 1 (add1 (vector-ref v 1))))
  ;; phase-kind of this round: F (only fenced), U (only unfenced), M (both)
  (define kind (cond [(and any-f any-u) 'M] [any-f 'F] [any-u 'U] [else #f]))
  (when (and kind (vector-ref v 3) (not (eq? kind (vector-ref v 3))))
    (vector-set! v 2 (add1 (vector-ref v 2))))
  (when kind (vector-set! v 3 kind)))

(define orig (current-quiescence-scheduler))
(define (wrapped pnet)
  (cond [(> depth 0) (orig pnet)]
        [else (set! depth 1) (set! run-idx (add1 run-idx))
              (dynamic-wind void (λ () (orig pnet)) (λ () (set! depth 0)))]))

(parameterize ([current-output-port (open-output-nowhere)]
               [current-bsp-observer observe]
               [current-quiescence-scheduler wrapped])
  (process-file the-file))

(define (top h n) (take (sort (hash->list h) > #:key cdr) (min n (hash-count h))))
(define productive (for/list ([(k v) runs] #:when (> (vector-ref v 4) 0)) (cons k v)))
(printf "file ~a\n" the-file)
(printf "fires ~a  fenced-fires(any output attribute-map) ~a  share ~a\n"
        all-fires fenced-fires (if (> all-fires 0) (exact->inexact (/ fenced-fires all-fires)) 0))
(printf "home histogram (K=8 RR, home = owner of first output): ~s\n"
        (sort (hash->list home-hist) > #:key cdr))
(printf "max-home share ~a\n" (if (> all-fires 0) (exact->inexact (/ (apply max (hash-values home-hist)) all-fires)) 0))
(printf "first-output merge (top 6): ~s\n" (top first-out-merge 6))
(printf "first-output cell (top 6): ~s\n" (top first-out-cell 6))
(printf "runs with fires ~a (of ~a observed)\n" (length productive) (hash-count runs))
(printf "per productive run: (run rounds rounds-with-fenced-fire phase-switches fires fenced-fires)\n")
(for ([kv (in-list (sort productive > #:key (λ (kv) (vector-ref (cdr kv) 4))))]
      [i (in-range 12)])
  (define v (cdr kv))
  (printf "  ~a ~a ~a ~a ~a ~a\n" (car kv) (vector-ref v 0) (vector-ref v 1) (vector-ref v 2) (vector-ref v 4) (vector-ref v 5)))
(printf "totals: rounds ~a rounds-with-fenced ~a phase-switches ~a\n"
        (for/sum ([kv productive]) (vector-ref (cdr kv) 0))
        (for/sum ([kv productive]) (vector-ref (cdr kv) 1))
        (for/sum ([kv productive]) (vector-ref (cdr kv) 2)))
