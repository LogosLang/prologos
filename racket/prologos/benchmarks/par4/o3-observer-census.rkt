#lang racket/base
;;; benchmarks/par4/o3-observer-census.rkt — PAR 4 O-3 evidence (D.1 Appendix A, re-posed 2026-10-14).
;;;
;;; What the production observer records when it is installed the way the LSP installs it (one observer
;;; over a whole process-file, lsp/server.rkt), and what observing costs. ONE .prologos file per process:
;;;
;;;   P0_PRELOAD=benchmarks/par4/preload-empty.prologos racket benchmarks/par4/o3-observer-census.rkt FILE
;;;
;;; prints one line "O3:{json}":
;;;   records       bsp-round records received (BSP Tier-2 rounds; Tier-1 flushes emit none)
;;;   s0_runs       records with round-number 0 = S0 runs that emitted ≥1 round (the accumulator the LSP uses
;;;                 re-stamps round numbers, so its timeline has no run boundaries)
;;;   max_round     longest S0 run, in rounds
;;;   writes        diff records (one per write)
;;;   noop_writes   writes after which the cell holds what it held before the round (no ascent)
;;;   shown_not_held writes whose new-value ≠ the value the cell holds after the round (what the editor's
;;;                 scrubber would display wrongly)
;;;   fanin_pairs   (round, cell) pairs written by ≥2 propagators in one round
;;;   epoch_cells   Σ over S0 runs of the cells whose value changed in the run (the size of a per-run summary)
;;;   forks         fork-prop-network calls (speculation; their rounds are interleaved into the same stream)
;;;   cost          median of 3 interleaved pairs: wall ms and allocated MB, unobserved vs observed with
;;;                 records retained (as make-trace-accumulator retains them); retained_mb after a major GC
(require racket/list racket/port racket/path json
         (only-in "../../driver.rkt" process-file)
         (only-in "../../propagator.rkt"
                  current-bsp-observer bsp-round-round-number bsp-round-network-snapshot
                  bsp-round-cell-diffs cell-diff-cell-id cell-diff-old-value cell-diff-new-value
                  net-cell-read par4-enable-counters! par4-fork-count))

(define file (vector-ref (current-command-line-arguments) 0))
(define (run-file* f)
  (parameterize ([current-output-port (open-output-nowhere)]
                 [current-error-port (open-output-nowhere)])
    (void (process-file f))))
(let ([pre (getenv "P0_PRELOAD")]) (when (and pre (not (equal? pre ""))) (run-file* pre)))
(par4-enable-counters!)

;; ── census (one observed run) ────────────────────────────────────────────────────────
(define records '())
(define f0 (unbox par4-fork-count))
(parameterize ([current-bsp-observer (λ (r) (set! records (cons r records)))]) (run-file* file))
(define forks (- (unbox par4-fork-count) f0))
(define rs (reverse records))
(define writes 0) (define noop 0) (define shown 0) (define fanin 0) (define epoch-cells 0)
(define s0-runs 0) (define max-round 0) (define shown-single 0) (define shown-kinds (make-hash))
(define (kind v) (cond [(struct? v) (let-values ([(st _) (struct-info v)]) (if st (call-with-values (λ () (struct-type-info st)) (λ (n . _r) n)) 'opaque-struct))]
                       [(pair? v) 'pair] [(null? v) 'null] [(symbol? v) 'symbol] [(number? v) 'number]
                       [(boolean? v) 'boolean] [(hash? v) 'hash] [(vector? v) 'vector] [else 'other]))
(define run-changed (make-hash))
(define (close-run!) (set! epoch-cells (+ epoch-cells (hash-count run-changed))) (hash-clear! run-changed))
(for ([r (in-list rs)])
  (define n (bsp-round-round-number r))
  (when (zero? n) (close-run!) (set! s0-runs (add1 s0-runs)))
  (set! max-round (max max-round (add1 n)))
  (define snap (bsp-round-network-snapshot r))
  (define per-cell (make-hash))
  (for ([d (in-list (bsp-round-cell-diffs r))]) (hash-update! per-cell (cell-diff-cell-id d) add1 0))
  (for ([d (in-list (bsp-round-cell-diffs r))])
    (define cid (cell-diff-cell-id d))
    (define held (net-cell-read snap cid))
    (set! writes (add1 writes))
    (if (equal? held (cell-diff-old-value d))
        (set! noop (add1 noop))
        (hash-set! run-changed cid #t))
    (unless (equal? held (cell-diff-new-value d))
      (set! shown (add1 shown))
      (when (= 1 (hash-ref per-cell cid))
        (set! shown-single (add1 shown-single))
        (hash-update! shown-kinds (format "~a→~a" (kind (cell-diff-new-value d)) (kind held)) add1 0))))
  (set! fanin (+ fanin (for/sum ([(k v) (in-hash per-cell)]) (if (>= v 2) 1 0)))))
(close-run!)
(define n-records (length rs))
(set! records #f) (set! rs #f)

;; ── cost: unobserved vs observed (records retained), interleaved ─────────────────────
(define (measure observed?)
  (collect-garbage 'major)
  (define acc '())
  (define b0 (current-memory-use 'cumulative))
  (define t0 (current-inexact-monotonic-milliseconds))
  (parameterize ([current-bsp-observer (and observed? (λ (r) (set! acc (cons r acc))))]) (run-file* file))
  (define t1 (current-inexact-monotonic-milliseconds))
  (define b1 (current-memory-use 'cumulative))
  (collect-garbage 'major)
  (define live-with (current-memory-use))
  (define n (length acc))
  (set! acc #f)
  (collect-garbage 'major)
  (define live-without (current-memory-use))
  (list (- t1 t0) (/ (- b1 b0) 1e6) (/ (- live-with live-without) 1e6) n))
(define pairs (for/list ([i 3]) (cons (measure #f) (measure #t))))
(define (med xs) (list-ref (sort xs <) (quotient (length xs) 2)))
(define (r2 x) (/ (round (* 100 x)) 100.0))
(define (col sel k) (r2 (med (map (λ (p) (list-ref (sel p) k)) pairs))))

(printf "O3:~a\n"
  (jsexpr->string
   (hasheq 'file (path->string (file-name-from-path file))
           'records n-records 's0_runs s0-runs 'max_round max-round 'writes writes 'noop_writes noop
           'shown_not_held shown 'shown_single_writer shown-single
           'shown_single_kinds (for/hasheq ([(k v) (in-hash shown-kinds)]) (values (string->symbol k) v))
           'fanin_pairs fanin 'epoch_cells epoch-cells 'forks forks
           'wall_ms_off (col car 0) 'wall_ms_on (col cdr 0)
           'alloc_mb_off (col car 1) 'alloc_mb_on (col cdr 1)
           'retained_mb_on (col cdr 2))))
