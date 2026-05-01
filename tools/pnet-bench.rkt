#lang racket/base

;; pnet-bench.rkt — Native (.pnet) vs Racket-interpreter timing.
;;
;; Given a .prologos source file, this driver runs three measurements:
;;
;;   1. RACKET-REDUCE-TIME — how long Racket takes to elaborate +
;;      reduce the source via `process-file`. This is the default
;;      "Racket interpreter" path (Tier 0).
;;
;;   2. NATIVE-COMPILE-TIME — how long it takes to translate from
;;      .prologos → .pnet → .ll → linked binary. (Compile-time cost
;;      that the Racket-interpreter path doesn't pay; reported for
;;      transparency, not as a fair head-to-head.)
;;
;;   3. NATIVE-RUN-TIME — how long the linked native binary takes
;;      to execute. THIS is the apples-to-apples comparison with (1):
;;      both numbers measure the time to evaluate the same program.
;;
;; Usage:
;;   racket tools/pnet-bench.rkt FILE.prologos
;;     prints a small table to stdout.
;;
;;   racket tools/pnet-bench.rkt --runs 5 FILE.prologos
;;     averages over 5 runs of each measurement.
;;
;; Caveats:
;;   - Racket-side timing includes module-load time on first run; we
;;     do a warm-up call before measuring.
;;   - Native run timing is dominated by exec / startup for tiny
;;     programs. For meaningful benchmarks pick fib(N) with N large
;;     enough that the work outweighs startup (N >= 1000 typical).
;;   - Both implementations may overflow i64 at large N; values can
;;     diverge while timings stay informative.

(require racket/cmdline
         racket/system
         racket/file
         racket/port
         racket/path
         racket/string
         racket/runtime-path
         "../racket/prologos/driver.rkt")

(define runs (make-parameter 1))
(define profile? (make-parameter #f))

(define input-path-str
  (command-line
   #:program "pnet-bench"
   #:once-each
   [("--runs") n "Number of timed runs to average (default 1)" (runs (string->number n))]
   [("--profile") "Enable per-tag profiling (60ns overhead per fire)"
    (profile? #t)]
   #:args (file)
   file))

;; ----- Racket-side reduction time -----
;; process-file ELABORATES the source AND runs the type checker / reducer
;; for any (eval ...) forms. For our pnet-compile inputs the body of
;; main is reduced as part of typing (the elaborator's NbE path), so
;; total process-file time is a fair "Racket interpreter time" proxy
;; for these small literal-shaped programs.

(define (warm-up!)
  (with-handlers ([exn? (lambda (_) (void))])
    (parameterize ([current-output-port (open-output-nowhere)]
                   [current-error-port (open-output-nowhere)])
      (process-file input-path-str))))

(define (open-output-nowhere)
  ;; Racket has no built-in /dev/null sink; this is the standard idiom.
  (open-output-string))

(define (time-racket-reduce)
  (define start (current-inexact-milliseconds))
  (parameterize ([current-output-port (open-output-nowhere)]
                 [current-error-port (open-output-nowhere)])
    (process-file input-path-str))
  (- (current-inexact-milliseconds) start))

;; ----- Native compile + run time -----
;; We run pnet-compile.rkt as a SUBPROCESS with --no-run, time its
;; total wall (compile = elaboration + .pnet emit + clang link). Then
;; time the binary alone.

(define-runtime-path pnet-compile-script "pnet-compile.rkt")

(define (time-native-compile out-bin #:stats? [stats? #f] #:profile? [profile? #f])
  (define racket-exe (find-executable-path "racket"))
  (define start (current-inexact-milliseconds))
  (define ok?
    (parameterize ([current-output-port (open-output-nowhere)]
                   [current-error-port (open-output-nowhere)])
      ;; Pass through PROLOGOS_STATS / PROLOGOS_PROFILE env vars by
      ;; setting them in the subprocess. Racket inherits the parent's
      ;; environment, so a temporary putenv is sufficient.
      (define old-stats   (getenv "PROLOGOS_STATS"))
      (define old-profile (getenv "PROLOGOS_PROFILE"))
      (when stats?   (putenv "PROLOGOS_STATS"   "1"))
      (when profile? (putenv "PROLOGOS_PROFILE" "1"))
      (define r (system* racket-exe pnet-compile-script "--no-run"
                         "-o" out-bin input-path-str))
      (when stats?   (putenv "PROLOGOS_STATS"   (or old-stats "")))
      (when profile? (putenv "PROLOGOS_PROFILE" (or old-profile "")))
      r))
  (define elapsed (- (current-inexact-milliseconds) start))
  (unless ok?
    (error 'pnet-bench "compile failed for ~a" input-path-str))
  elapsed)

;; Runs the binary, captures its stderr (which contains the
;; PNET-STATS JSON line if compiled with PROLOGOS_STATS=1), and
;; returns (values wall-ms stderr-string).
(define (time-native-run-capture out-bin)
  (define abs-path (path->complete-path out-bin))
  (define stderr-bytes (open-output-bytes))
  (define start (current-inexact-milliseconds))
  (parameterize ([current-output-port (open-output-nowhere)]
                 [current-error-port stderr-bytes])
    (system*/exit-code abs-path))
  (define elapsed (- (current-inexact-milliseconds) start))
  (values elapsed (bytes->string/utf-8 (get-output-bytes stderr-bytes))))

(define (time-native-run out-bin)
  (define-values (ms _) (time-native-run-capture out-bin))
  ms)

;; Parse a single integer from the JSON object returned by
;; prologos_print_stats. The format is fixed (one-line, no nested
;; objects of the relevant numeric fields), so a simple regex
;; suffices — no full JSON parser dependency.
(define (parse-stat key stderr)
  (define rx (regexp (format "\"~a\":([0-9]+)" (regexp-quote key))))
  (define m (regexp-match rx stderr))
  (and m (string->number (cadr m))))

;; ----- Driver -----

(define (avg xs)
  (/ (apply + xs) (length xs)))

(printf "Benchmarking ~a (~a run(s) per measurement)~n" input-path-str (runs))
(printf "~n")

(printf "Warming up Racket-side path...~n")
(warm-up!)

(printf "Compiling native binary (this is also a measurement, run #1):~n")
(define out-bin (make-temporary-file "pnet-bench-~a"))
(define compile-ms-list
  (for/list ([i (in-range (runs))])
    ;; Compile WITH stats enabled so the binary self-reports kernel
    ;; counters on stderr. Compile cost slightly higher (one extra
    ;; @prologos_print_stats call lowered into @main); negligible vs
    ;; overall compile time.
    (define m (time-native-compile out-bin
                                   #:stats? #t
                                   #:profile? (profile?)))
    (printf "  compile run ~a: ~ams~n" (+ i 1) (round m))
    m))

(printf "~nRacket-reduce-time runs:~n")
(define reduce-ms-list
  (for/list ([i (in-range (runs))])
    (define m (time-racket-reduce))
    (printf "  racket-reduce run ~a: ~ams~n" (+ i 1) (round m))
    m))

(printf "~nNative-run-time runs:~n")
(define-values (run-ms-list last-stderr)
  (for/fold ([accum '()] [last ""])
            ([i (in-range (runs))])
    (define-values (m err) (time-native-run-capture out-bin))
    (printf "  native-run run ~a: ~ams~n" (+ i 1) (round m))
    (values (append accum (list m)) err)))

;; Extract kernel stats from the LAST run's stderr.
(define stat-rounds        (parse-stat "rounds"        last-stderr))
(define stat-fires         (parse-stat "fires"         last-stderr))
(define stat-committed     (parse-stat "committed"     last-stderr))
(define stat-dropped       (parse-stat "dropped"       last-stderr))
(define stat-max-worklist  (parse-stat "max_worklist"  last-stderr))
(define stat-fuel-out      (parse-stat "fuel_out"      last-stderr))
(define stat-cells         (parse-stat "cells"         last-stderr))
(define stat-props         (parse-stat "props"         last-stderr))
(define stat-run-ns        (parse-stat "run_ns"        last-stderr))

;; by_tag and ns_by_tag are arrays. Rather than parse JSON, just split
;; the bracketed segment.
(define (parse-array key stderr)
  (define rx (regexp (format "\"~a\":\\[([0-9,]*)\\]" (regexp-quote key))))
  (define m (regexp-match rx stderr))
  (and m (map string->number (string-split (cadr m) ","))))
(define stat-by-tag    (parse-array "by_tag"    last-stderr))
(define stat-ns-by-tag (parse-array "ns_by_tag" last-stderr))

;; Tag-id → human name; mirrors low-pnet-to-llvm.rkt's FIRE-FN-TAG-REGISTRY.
;; (2,1) tags 0..6 are int-add, sub, mul, div, eq, lt, le.
;; (3,1) tag 0 is select — but the kernel uses the same numeric space
;; for both shapes so by_tag[0] aggregates int-add AND select fires.
;; This is a known limitation of the current single tag space; reports
;; print "tag 0" rather than a name when ambiguity is possible.
(define TAG-NAMES
  (list "int-add/select" "int-sub" "int-mul" "int-div"
        "int-eq" "int-lt" "int-le" "tag7"
        "tag8" "tag9" "tag10" "tag11"
        "tag12" "tag13" "tag14" "tag15"))

(delete-file out-bin)

(printf "~n--- Summary (averages over ~a run(s)) ---~n" (runs))
(printf "Racket reduce  : ~a ms~n" (round (avg reduce-ms-list)))
(printf "Native compile : ~a ms (build-time only; not part of speedup math)~n"
        (round (avg compile-ms-list)))
(printf "Native run     : ~a ms~n" (round (avg run-ms-list)))
(define speedup (/ (avg reduce-ms-list) (max 0.001 (avg run-ms-list))))
(printf "Speedup (racket-reduce / native-run): ~ax~n" (real->decimal-string speedup 1))

;; Kernel-side detail. The `run_ns` figure is what the BSP scheduler
;; ACTUALLY spent firing propagators (excludes binary startup,
;; cell_alloc/cell_write at init time, exit overhead). For tiny
;; programs `Native run` is dominated by binary startup; `run_ns` is
;; the apples-to-apples figure for scheduler throughput.
(printf "~n--- Kernel diagnostics (last run) ---~n")
(when stat-run-ns
  (printf "Scheduler time    : ~a us (~a ns; binary startup is the rest of native-run)~n"
          (real->decimal-string (/ stat-run-ns 1000.0) 2)
          stat-run-ns))
(when stat-rounds
  (printf "BSP rounds        : ~a~n" stat-rounds))
(when stat-fires
  (printf "Propagator fires  : ~a (~a fires/round avg)~n"
          stat-fires
          (real->decimal-string (/ stat-fires (max 1 stat-rounds)) 1)))
(when stat-committed
  (printf "Cell writes       : ~a committed, ~a dropped (~a% effective)~n"
          stat-committed stat-dropped
          (real->decimal-string
           (* 100 (/ stat-committed (max 1 (+ stat-committed stat-dropped))))
           0)))
(when stat-max-worklist
  (printf "Max worklist size : ~a (~a cells, ~a propagators)~n"
          stat-max-worklist stat-cells stat-props))
(when (and stat-fuel-out (= stat-fuel-out 1))
  (printf "WARNING: fuel exhausted — result is from a partial run~n"))

(when stat-by-tag
  (printf "~nPer-tag fire counts (only nonzero shown):~n")
  (for ([count (in-list stat-by-tag)]
        [name  (in-list TAG-NAMES)]
        [i     (in-naturals)]
        #:when (> count 0))
    (printf "  ~a (tag ~a): ~a fires" name i count)
    (when (and stat-ns-by-tag (> (list-ref stat-ns-by-tag i) 0))
      (define ns (list-ref stat-ns-by-tag i))
      (printf "  ~ans total  ~ans/fire"
              ns
              (real->decimal-string (/ ns count) 1)))
    (printf "~n")))

(when (and (profile?) (not (and stat-ns-by-tag (ormap positive? stat-ns-by-tag))))
  (printf "~nNote: --profile was requested but no per-tag ns recorded.~n")
  (printf "      (Stats output not captured? Re-run with PROLOGOS_PROFILE=1 set explicitly.)~n"))
