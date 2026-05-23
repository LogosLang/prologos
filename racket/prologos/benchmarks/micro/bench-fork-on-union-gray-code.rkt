#lang racket/base

;; ============================================================================
;; bench-fork-on-union-gray-code.rkt — PPN 4C Phase 3B.0 A/B harness
;; ============================================================================
;;
;; Design reference: D.3 §9.4.2.3 (Phase 3B.0 mini-design — A/B harness plan)
;; + §9.4.1.5 (workloads W1-W5) + §9.4.1.6 (pre-committed falsification criteria).
;;
;; Empirical test of the Hyperlattice Conjecture's claim under Realization B:
;;   Does Gray-code aid bit-position assignment produce measurable benefit vs
;;   sequential allocation for fork-on-union elaboration?
;;
;; Per Realization B (Phase 3A's non-committing in-place tagging), there is no
;; fork-prop-network chain between branches — they live on the SAME network
;; with worldview-bitmask-tagged writes. The BSP-LE 2 D.6 "CHAMP structural
;; sharing" argument is mechanism-coupled to fork-and-rejoin, so its predicted
;; benefit may NOT transfer. This harness empirically falsifies or supports
;; the Conjecture for Realization B specifically.
;;
;; Variants:
;;   A (control):   current-gray-code-aid-ordering? = #f (current Phase 3A)
;;   B (treatment): current-gray-code-aid-ordering? = #t (Gray-code-permuted)
;;
;; Workloads (per §9.4.1.5):
;;   W1: single binary union (2 branches; baseline)
;;   W2: single 4-ary union (4 branches; small-N)
;;   W3: nested binary unions (function returning + accepting unions)
;;   W4: deeply nested unions (aids approach D-3A-bit-budget ≤30)
;;   W5: worst-case adversarial (many forks at varying depths)
;;
;; Pre-committed falsification criteria (§9.4.1.6) at W4/W5:
;;   Variant B beats A by ≥10%  → 3B.B implements Gray-code aid ordering
;;   5-10%                       → investigate before implementing
;;   Variants within ±5%         → DOCUMENTED-DEFER with negative finding
;;   Variant B slower than A     → DEFER + flag primitive-keepalive risk
;;
;; Usage:
;;   "/Applications/Racket v9.0/bin/racket" benchmarks/micro/bench-fork-on-union-gray-code.rkt
;;
;; Phase 3B.0 Pre-0 measurement scaffolding (retires at 3B.B per outcome).

(require racket/list
         racket/string
         racket/math
         racket/format
         racket/port
         "../../atms.rkt"
         "../../tests/test-support.rkt")

;; ============================================================================
;; Workloads — Prologos source strings exercising fork-on-union
;; ============================================================================
;;
;; Each workload is a multi-line WS-mode .prologos source. Annotated unions
;; (`def x : <T1 | T2> := v`) trigger process-fork-on-union via R7's
;; centralized inline-emit at type-map-write. Each annotated union
;; corresponds to one solver-amb invocation → N aids allocated → N branch
;; propagators installed.

(define W1-source
  ;; Single binary union — 2 branches
  (string-append
   "def x : <Int | String> := 42\n"
   "x\n"))

(define W2-source
  ;; Single 4-ary union — 4 branches
  (string-append
   "def x : <Int | String | Bool | Nat> := 42\n"
   "x\n"))

(define W3-source
  ;; Multiple binary unions in sequence — 5 forks × 2 branches each
  (string-append
   "def x1 : <Int | String> := 42\n"
   "def x2 : <Int | Bool> := 42\n"
   "def x3 : <Int | Nat> := 42\n"
   "def x4 : <Bool | Nat> := false\n"
   "def x5 : <String | Bool> := \"hi\"\n"
   "x1\n"))

(define W4-source
  ;; Deeply nested adversarial — 10 unions, 4-ary each
  ;; Approaches D-3A-bit-budget gate (≤30 aids per command);
  ;; ten 4-ary forks = 40 total aids if all in one command,
  ;; but each `def` is its own command-scoped fork.
  (string-append
   "def x1 : <Int | String | Bool | Nat> := 42\n"
   "def x2 : <Int | String | Bool | Nat> := 42\n"
   "def x3 : <Int | String | Bool | Nat> := 42\n"
   "def x4 : <Int | String | Bool | Nat> := 42\n"
   "def x5 : <Int | String | Bool | Nat> := 42\n"
   "def x6 : <Int | String | Bool | Nat> := 42\n"
   "def x7 : <Int | String | Bool | Nat> := 42\n"
   "def x8 : <Int | String | Bool | Nat> := 42\n"
   "def x9 : <Int | String | Bool | Nat> := 42\n"
   "def x10 : <Int | String | Bool | Nat> := 42\n"
   "x1\n"))

(define W5-source
  ;; Worst-case adversarial — mix of widths + depths
  ;; designed to give Gray-code its best shot at structural sharing.
  ;; If Gray-code shows any benefit anywhere under Realization B, W5 surfaces it.
  (string-append
   "def x1 : <Int | String> := 42\n"
   "def x2 : <Int | String | Bool> := 42\n"
   "def x3 : <Int | String | Bool | Nat> := 42\n"
   "def x4 : <Int | String> := 42\n"
   "def x5 : <Int | Bool | Nat> := 42\n"
   "def x6 : <Int | String | Bool | Nat> := 42\n"
   "def x7 : <Bool | Nat> := false\n"
   "def x8 : <String | Bool | Nat> := \"hi\"\n"
   "def x9 : <Int | String | Bool | Nat> := 42\n"
   "def x10 : <Int | Bool> := 42\n"
   "x1\n"))

(define workloads
  (list
    (list 'W1 W1-source "single binary union (2 branches)")
    (list 'W2 W2-source "single 4-ary union (4 branches)")
    (list 'W3 W3-source "5 sequential binary unions (10 branches total)")
    (list 'W4 W4-source "10 sequential 4-ary unions (40 branches total)")
    (list 'W5 W5-source "worst-case adversarial (35 branches; varied widths)")))

;; ============================================================================
;; Statistical helpers — median + IQR
;; ============================================================================

(define (percentile sorted-xs p)
  ;; Linear interpolation between order statistics.
  (define n (length sorted-xs))
  (cond
    [(zero? n) 0.0]
    [(= n 1) (car sorted-xs)]
    [else
     (define rank (* p (- n 1)))
     (define lo-idx (inexact->exact (floor rank)))
     (define hi-idx (inexact->exact (ceiling rank)))
     (define lo (list-ref sorted-xs lo-idx))
     (define hi (list-ref sorted-xs hi-idx))
     (define frac (- rank lo-idx))
     (+ lo (* frac (- hi lo)))]))

(define (median xs) (percentile (sort xs <) 0.5))
(define (q25    xs) (percentile (sort xs <) 0.25))
(define (q75    xs) (percentile (sort xs <) 0.75))
(define (iqr    xs) (- (q75 xs) (q25 xs)))

;; ============================================================================
;; Bench helper
;; ============================================================================
;; Returns (values median-ms iqr-ms times-list).
;; warmup runs are NOT included in the timing distribution; they stabilize
;; JIT / cache state before measurement.

(define (bench-runs thunk #:warmup [n-warmup 2] #:iter [n-iter 10])
  (collect-garbage) (collect-garbage)
  ;; Warmup
  (for ([_ (in-range n-warmup)]) (thunk))
  (collect-garbage) (collect-garbage)
  ;; Timed iterations
  (define times
    (for/list ([_ (in-range n-iter)])
      (collect-garbage)
      (define t0 (current-inexact-monotonic-milliseconds))
      (thunk)
      (- (current-inexact-monotonic-milliseconds) t0)))
  (values (median times) (iqr times) times))

;; ============================================================================
;; Variant runner
;; ============================================================================

(define (run-variant variant-name gray-code-on? source)
  (parameterize ([current-gray-code-aid-ordering? gray-code-on?])
    ;; run-ns-ws-all sets up fresh prelude env + fork network per call.
    ;; Suppress output to keep bench output clean.
    (parameterize ([current-output-port (open-output-nowhere)])
      (run-ns-ws-all source))))

;; ============================================================================
;; Main A/B sweep
;; ============================================================================

(define (run-bench #:warmup [n-warmup 2] #:iter [n-iter 10])
  (printf "\n=== PPN 4C Phase 3B.0 A/B Harness: Gray-code aid ordering under Realization B ===\n")
  (printf "Pre-committed falsification criteria (§9.4.1.6):\n")
  (printf "  ≥10%% benefit at W4/W5 → 3B.B implements Gray-code\n")
  (printf "  5-10%%                  → investigate before implementing\n")
  (printf "  ±5%%                    → DOCUMENTED-DEFER with negative finding\n")
  (printf "  slower                 → DEFER + flag primitive-keepalive risk\n")
  (printf "Config: warmup=~a, iter=~a per variant per workload\n\n" n-warmup n-iter)

  (printf "~a\n" (make-string 90 #\-))
  (printf "~a  ~a  ~a  ~a\n"
          (~a "Workload" #:min-width 6)
          (~a "A (control)" #:min-width 24)
          (~a "B (Gray-code)" #:min-width 24)
          (~a "Delta (B/A)" #:min-width 20))
  (printf "~a\n" (make-string 90 #\-))

  (for ([wl (in-list workloads)])
    (define name (car wl))
    (define source (cadr wl))
    (define descr (caddr wl))

    (printf "~a  " (~a name #:min-width 6))

    ;; Variant A
    (define-values (a-median a-iqr a-times)
      (bench-runs (lambda () (run-variant 'A #f source))
                  #:warmup n-warmup #:iter n-iter))

    ;; Variant B
    (define-values (b-median b-iqr b-times)
      (bench-runs (lambda () (run-variant 'B #t source))
                  #:warmup n-warmup #:iter n-iter))

    (define delta-ms (- b-median a-median))
    (define delta-pct (if (zero? a-median) 0.0 (* 100.0 (/ delta-ms a-median))))

    (printf "~a  ~a  ~a\n"
            (~a (format "~a±~a ms" (real->decimal-string a-median 1)
                        (real->decimal-string a-iqr 1)) #:min-width 24)
            (~a (format "~a±~a ms" (real->decimal-string b-median 1)
                        (real->decimal-string b-iqr 1)) #:min-width 24)
            (~a (format "~a ms (~a%)" (real->decimal-string delta-ms 1)
                        (real->decimal-string delta-pct 1)) #:min-width 20))
    (printf "        (~a)\n" descr))

  (printf "~a\n\n" (make-string 90 #\-))
  (printf "Falsification evaluation lives in §9.4.2.9 (forthcoming after measurement run).\n"))

;; Default: run with n-warmup=2, n-iter=10. Quick smoke test mode: --quick (n-iter=3).
(define args (current-command-line-arguments))
(cond
  [(and (positive? (vector-length args)) (string=? (vector-ref args 0) "--quick"))
   (printf "[QUICK MODE — n-iter=3 for smoke test; not for measurement use]\n")
   (run-bench #:warmup 1 #:iter 3)]
  [else
   (run-bench)])
