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
         racket/runtime-path
         "../racket/prologos/driver.rkt")

(define runs (make-parameter 1))

(define input-path-str
  (command-line
   #:program "pnet-bench"
   #:once-each
   [("--runs") n "Number of timed runs to average (default 1)" (runs (string->number n))]
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

(define (time-native-compile out-bin)
  (define racket-exe (find-executable-path "racket"))
  (define start (current-inexact-milliseconds))
  (define ok?
    (parameterize ([current-output-port (open-output-nowhere)]
                   [current-error-port (open-output-nowhere)])
      (system* racket-exe pnet-compile-script "--no-run" "-o" out-bin
               input-path-str)))
  (define elapsed (- (current-inexact-milliseconds) start))
  (unless ok?
    (error 'pnet-bench "compile failed for ~a" input-path-str))
  elapsed)

(define (time-native-run out-bin)
  (define abs-path (path->complete-path out-bin))
  (define start (current-inexact-milliseconds))
  (parameterize ([current-output-port (open-output-nowhere)]
                 [current-error-port (open-output-nowhere)])
    (system*/exit-code abs-path))
  (- (current-inexact-milliseconds) start))

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
    (define m (time-native-compile out-bin))
    (printf "  compile run ~a: ~ams~n" (+ i 1) (round m))
    m))

(printf "~nRacket-reduce-time runs:~n")
(define reduce-ms-list
  (for/list ([i (in-range (runs))])
    (define m (time-racket-reduce))
    (printf "  racket-reduce run ~a: ~ams~n" (+ i 1) (round m))
    m))

(printf "~nNative-run-time runs:~n")
(define run-ms-list
  (for/list ([i (in-range (runs))])
    (define m (time-native-run out-bin))
    (printf "  native-run run ~a: ~ams~n" (+ i 1) (round m))
    m))

(delete-file out-bin)

(printf "~n--- Summary (averages over ~a run(s)) ---~n" (runs))
(printf "Racket reduce  : ~a ms~n" (round (avg reduce-ms-list)))
(printf "Native compile : ~a ms (build-time only; not part of speedup math)~n"
        (round (avg compile-ms-list)))
(printf "Native run     : ~a ms~n" (round (avg run-ms-list)))
(define speedup (/ (avg reduce-ms-list) (max 0.001 (avg run-ms-list))))
(printf "Speedup (racket-reduce / native-run): ~ax~n" (real->decimal-string speedup 1))
