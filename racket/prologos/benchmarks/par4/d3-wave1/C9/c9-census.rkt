#lang racket/base
;; C9 census: on ONE .prologos file (argv[0]), with the production BSP observer installed the way
;; o3-observer-census.rkt installs it, measure:
;;   - the share of S0 writes and of productive fires that land in the SINGLE most-written cell,
;;     and whether that cell is the module-level attribute map (current-attribute-map-cell-id);
;;     D.2 §6.3 fences per CELL and homes a fire on the owner of its first output (§6.7);
;;   - nested S0 runs: rounds observed while another run-to-quiescence-bsp is on the stack
;;     (stack frames named run-to-quiescence-bsp, via continuation-mark-set->context);
;;   - fork-prop-network calls (par4-fork-count).
;; Run: P0_PRELOAD=<preload> racket c9-census.rkt FILE
(require racket/list racket/port racket/string
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt")
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/typing-propagators.rkt")
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
                  current-bsp-observer bsp-round-round-number bsp-round-cell-diffs bsp-round-propagators-fired
                  cell-diff-cell-id cell-diff-source-propagator par4-enable-counters! par4-fork-count))

(define file (vector-ref (current-command-line-arguments) 0))
(define (run-file* f)
  (parameterize ([current-output-port (open-output-nowhere)]
                 [current-error-port (open-output-nowhere)])
    (void (process-file f))))
(let ([pre (getenv "P0_PRELOAD")]) (when (and pre (not (equal? pre ""))) (run-file* pre)))
(par4-enable-counters!)

(define writes-by-cell (make-hash))       ; cell-id -> writes
(define writers-by-cell (make-hash))      ; cell-id -> count of (round, pid) writer pairs
(define rounds 0) (define fires 0) (define productive 0)
(define nested-rounds 0) (define max-depth 0)
(define attr-ids (make-hash))             ; attribute-map cell ids seen (parameter read during the run)
(define (bsp-depth)
  (for/sum ([fr (in-list (continuation-mark-set->context (current-continuation-marks)))])
    (define n (car fr))
    (if (and n (regexp-match? #rx"^run-to-quiescence-bsp$" (symbol->string n))) 1 0)))
(define f0 (unbox par4-fork-count))
(parameterize ([current-bsp-observer
                (λ (r)
                  (set! rounds (add1 rounds))
                  (define d (bsp-depth))
                  (set! max-depth (max max-depth d))
                  (when (>= d 2) (set! nested-rounds (add1 nested-rounds)))
                  (let ([a (current-attribute-map-cell-id)]) (when a (hash-set! attr-ids a #t)))
                  (set! fires (+ fires (length (bsp-round-propagators-fired r))))
                  (define srcs (make-hash))
                  (for ([df (in-list (bsp-round-cell-diffs r))])
                    (define cid (cell-diff-cell-id df))
                    (hash-update! writes-by-cell cid add1 0)
                    (hash-set! srcs (cell-diff-source-propagator df) #t)
                    (hash-update! writers-by-cell cid (λ (s) (hash-set s (cons rounds (cell-diff-source-propagator df)) #t)) (hash)))
                  (set! productive (+ productive (hash-count srcs))))])
  (run-file* file))
(define forks (- (unbox par4-fork-count) f0))
(define total-writes (for/sum ([(k v) (in-hash writes-by-cell)]) v))
(define sorted (sort (hash->list writes-by-cell) > #:key cdr))
(define top (and (pair? sorted) (car sorted)))
(define top-writer-pairs (if top (hash-count (hash-ref writers-by-cell (car top))) 0))
(define productive-pairs (for/sum ([(k s) (in-hash writers-by-cell)]) 0))
(printf "C9-CENSUS file=~a rounds=~a fires=~a productive_fires=~a writes=~a distinct_cells_written=~a\n"
        file rounds fires productive total-writes (hash-count writes-by-cell))
(when top
  (printf "  top cell ~a: ~a writes (~a % of writes), ~a productive (round,propagator) writer pairs (~a % of productive fires); attribute-map cell? ~a\n"
          (car top) (cdr top) (real->decimal-string (* 100.0 (/ (cdr top) (max 1 total-writes))) 1)
          top-writer-pairs (real->decimal-string (* 100.0 (/ top-writer-pairs (max 1 productive))) 1)
          (and (hash-ref attr-ids (car top) #f) #t))
  (printf "  next cells: ~a\n" (for/list ([p (in-list (take sorted (min 4 (length sorted))))]) p)))
(printf "  nested S0: rounds observed with >=2 run-to-quiescence-bsp frames on the stack = ~a of ~a (max depth ~a); forks = ~a\n"
        nested-rounds rounds max-depth forks)
