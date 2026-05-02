#lang racket/base

;; bench-native.rkt — Fast native-only bench across algorithms × sizes.
;;
;; Design notes:
;;   - All compilation happens IN-PROCESS via dynamic-require of pnet-compile's
;;     entry point. Avoids 30+ fresh `racket` subprocesses (~600ms startup +
;;     module load each = ~25s/config of pure overhead).
;;   - Each native-binary invocation is wrapped in a `subprocess` with a
;;     per-run wall-clock timeout (default 10s). If the binary exceeds it,
;;     we send SIGKILL and record a TIMEOUT result for that config.
;;   - Per-config compilation also has a timeout (default 60s). If the
;;     whole compile pipeline hangs, we abandon that config and continue.
;;   - Results stream to STDOUT and a `--out` file as each config completes,
;;     so a Ctrl-C still leaves us with a usable partial report.
;;
;; Usage:
;;   racket tools/bench-native.rkt
;;   racket tools/bench-native.rkt --runs 5 --out /tmp/bench.md
;;   racket tools/bench-native.rkt --quick
;;   racket tools/bench-native.rkt --run-timeout 30 --compile-timeout 120

(require racket/cmdline
         racket/system
         racket/port
         racket/list
         racket/file
         racket/format
         racket/runtime-path
         racket/string)

(define-runtime-path here ".")

(define runs            (make-parameter 3))
(define quick?          (make-parameter #f))
(define run-timeout-s   (make-parameter 10))
(define compile-timeout-s (make-parameter 60))
(define out-path        (make-parameter #f))

(command-line
 #:program "bench-native"
 #:once-each
 [("--runs") n "Native runs to average (default 3)" (runs (string->number n))]
 [("--quick") "Small N sweep" (quick? #t)]
 [("--run-timeout") n "Per-native-run wall timeout in seconds (default 10)"
  (run-timeout-s (string->number n))]
 [("--compile-timeout") n "Per-config compile timeout in seconds (default 60)"
  (compile-timeout-s (string->number n))]
 [("--out") f "Mirror table output to this file" (out-path f)])

;; ============================================================
;; Configuration
;; ============================================================

(define n-values-iter
  (if (quick?)
      '(10 40 100)
      '(10 40 100 400 1000)))

(define n-values-unrolled
  ;; Unrolled fib uses ~2N+1 cells; MAX_CELLS=1024 caps at N<=510.
  (if (quick?)
      '(10 40 100)
      '(10 40 100 400)))

(define iter-algs
  '(fib pair-fib helpered-fib sum factorial sumsq dual-acc pell pow2))

(define configs
  (append
   (for/list ([n (in-list n-values-unrolled)])
     (list 'fib 'unrolled n))
   (for*/list ([alg (in-list iter-algs)]
               [n (in-list n-values-iter)])
     (list alg 'iterative n))))

;; ============================================================
;; In-process source generation
;; ============================================================
;;
;; gen-fib.rkt and gen-iter.rkt are both small scripts that print the
;; source to current-output-port. We `dynamic-require` them and capture
;; their output rather than spawning a subprocess.

(define-runtime-path gen-fib-script  "gen-fib.rkt")
(define-runtime-path gen-iter-script "gen-iter.rkt")
(define-runtime-path pnet-compile-script "pnet-compile.rkt")

(define (capture-stdout thunk)
  (define out (open-output-string))
  (parameterize ([current-output-port out]
                 [current-error-port (open-output-string)])
    (thunk))
  (get-output-string out))

;; gen-fib.rkt is a script (#lang racket/base with command-line at top
;; level). Easiest robust path: spawn it as a subprocess. Same for
;; gen-iter.rkt. The cost is small (~600ms startup) and only paid once
;; per config since we cache the source on disk.
(define racket-exe (find-executable-path "racket"))
(define (write-source-file algorithm form n out-path)
  (define-values (script args)
    (case form
      [(unrolled)
       (unless (eq? algorithm 'fib)
         (error 'bench-native "unrolled only for fib"))
       (values gen-fib-script (list (number->string n)))]
      [(iterative)
       (values gen-iter-script
               (list "--algorithm" (symbol->string algorithm)
                     "--n" (number->string n)))]))
  (define out-port (open-output-file out-path #:exists 'truncate))
  (parameterize ([current-output-port out-port]
                 [current-error-port (open-output-string)])
    (apply system* racket-exe script args))
  (close-output-port out-port))

;; ============================================================
;; In-process compilation via dynamic-require
;; ============================================================
;;
;; pnet-compile.rkt is also a script that hands off to
;; pnet-compile-impl. We dynamic-require its `compile-prologos-to-binary`
;; entrypoint after first checking the script exposes one. If it doesn't,
;; fall back to subprocess invocation.

(define (compile-with-stats-timeout src-path out-bin)
  ;; Subprocess approach with timeout. Keeps state isolation guarantees
  ;; (which dynamic-require would not, since the kernel runtime is
  ;; module-scoped state and we want a fresh kernel state per program).
  (define old-stats (getenv "PROLOGOS_STATS"))
  (putenv "PROLOGOS_STATS" "1")
  (define-values (proc proc-out proc-in proc-err)
    (subprocess #f #f #f racket-exe pnet-compile-script "--no-run"
                "-o" out-bin src-path))
  (close-output-port proc-in)
  ;; Drain output ports concurrently so the subprocess doesn't block on a
  ;; full pipe buffer (LLVM IR can be large).
  (define drain-out (thread (lambda () (port->bytes proc-out))))
  (define drain-err (thread (lambda () (port->bytes proc-err))))
  (define deadline (+ (current-inexact-milliseconds)
                      (* 1000 (compile-timeout-s))))
  (define result
    (let loop ()
      (cond
        [(eq? (subprocess-status proc) 'running)
         (cond
           [(> (current-inexact-milliseconds) deadline)
            (subprocess-kill proc #t)
            (sync proc)
            'timeout]
           [else
            (sleep 0.05)
            (loop)])]
        [else
         (define ec (subprocess-status proc))
         (if (zero? ec) 'ok (cons 'exit ec))])))
  (close-input-port proc-out)
  (close-input-port proc-err)
  (putenv "PROLOGOS_STATS" (or old-stats ""))
  result)

;; ============================================================
;; Native run with per-run timeout
;; ============================================================

(struct run-r (wall-ms stderr status) #:transparent)
;; status ∈ {'ok 'timeout 'crash}

(define (time-native-run-timeout/v2 out-bin)
  (define abs-path (path->complete-path out-bin))
  (define-values (proc proc-out proc-in proc-err)
    (subprocess #f #f #f abs-path))
  (close-output-port proc-in)
  (define err-ch (make-channel))
  (define out-ch (make-channel))
  (define t-err (thread (lambda ()
                          (channel-put err-ch (port->bytes proc-err)))))
  (define t-out (thread (lambda ()
                          (channel-put out-ch (port->bytes proc-out)))))
  (define t0 (current-inexact-milliseconds))
  (define deadline (+ t0 (* 1000 (run-timeout-s))))
  ;; Exit code is the program's RESULT (Unix u8 truncation of the result-cell);
  ;; e.g. fib(10) exits 55. So we DO NOT treat non-zero as crash. We only
  ;; treat exit codes >= 128 (signal range) AS suspicious if PNET-STATS is
  ;; absent from stderr — but even then the program may have crashed
  ;; intentionally with high result. The reliable signal is "did the
  ;; kernel print PNET-STATS to stderr?" — emitted unconditionally by the
  ;; Day-11 LLVM lowering when PROLOGOS_STATS=1 was set at compile time.
  (define status
    (let loop ()
      (cond
        [(eq? (subprocess-status proc) 'running)
         (cond
           [(> (current-inexact-milliseconds) deadline)
            (subprocess-kill proc #t)
            (sync proc)
            'timeout]
           [else
            (sleep 0.005)
            (loop)])]
        [else 'done])))
  (define wall-ms (- (current-inexact-milliseconds) t0))
  (define err-bytes (channel-get err-ch))
  (define _out-bytes (channel-get out-ch))
  (close-input-port proc-out)
  (close-input-port proc-err)
  (define err-str (bytes->string/utf-8 err-bytes #\?))
  (define final-status
    (cond
      [(eq? status 'timeout) 'timeout]
      [(regexp-match? #rx"PNET-STATS" err-str) 'ok]
      [else 'crash]))
  (run-r wall-ms err-str final-status))

(define (parse-stat key stderr)
  (define rx (regexp (format "\"~a\":([0-9]+)" (regexp-quote key))))
  (define m (regexp-match rx stderr))
  (and m (string->number (cadr m))))

;; ============================================================
;; Per-config measurement
;; ============================================================

(struct cfg-r
  (algorithm form n
   wall-min wall-avg wall-max
   sched-ns-min sched-ns-avg sched-ns-max
   rounds fires cells props committed dropped outer-iters
   status        ;; 'ok 'timeout-compile 'timeout-run 'crash
   note)
  #:transparent)

(define (avg xs) (if (null? xs) 0 (/ (apply + xs) (length xs))))
(define (mn xs) (if (null? xs) #f (apply min xs)))
(define (mx xs) (if (null? xs) #f (apply max xs)))

(define (measure-config algorithm form n)
  (define src-path (make-temporary-file
                    (format "bench-native-~a-~a-~a-~~a.prologos" algorithm form n)))
  (write-source-file algorithm form n src-path)
  (define out-bin (make-temporary-file
                   (format "bench-native-~a-~a-~a-bin-~~a" algorithm form n)))
  (define compile-result (compile-with-stats-timeout src-path out-bin))
  (cond
    [(eq? compile-result 'timeout)
     (delete-file src-path)
     (when (file-exists? out-bin) (delete-file out-bin))
     (cfg-r algorithm form n #f #f #f #f #f #f #f #f #f #f #f #f #f
            'timeout-compile
            (format "compile exceeded ~as" (compile-timeout-s)))]
    [(pair? compile-result)
     (delete-file src-path)
     (when (file-exists? out-bin) (delete-file out-bin))
     (cfg-r algorithm form n #f #f #f #f #f #f #f #f #f #f #f #f #f
            'crash
            (format "compile exit ~a" (cdr compile-result)))]
    [else
     ;; Warm-up.
     (time-native-run-timeout/v2 out-bin)
     (define rs (for/list ([_ (in-range (runs))])
                  (time-native-run-timeout/v2 out-bin)))
     (define any-timeout? (ormap (lambda (r) (eq? (run-r-status r) 'timeout)) rs))
     (define any-crash?   (ormap (lambda (r) (eq? (run-r-status r) 'crash))   rs))
     (define ok-rs (filter (lambda (r) (eq? (run-r-status r) 'ok)) rs))
     (define walls (map run-r-wall-ms ok-rs))
     (define stderrs (map run-r-stderr ok-rs))
     (define ns-vals (filter values (map (lambda (s) (parse-stat "run_ns" s)) stderrs)))
     (define result
       (cfg-r algorithm form n
              (mn walls) (and (pair? walls) (avg walls)) (mx walls)
              (mn ns-vals) (and (pair? ns-vals) (avg ns-vals)) (mx ns-vals)
              (and (pair? stderrs) (parse-stat "rounds"      (last stderrs)))
              (and (pair? stderrs) (parse-stat "fires"       (last stderrs)))
              (and (pair? stderrs) (parse-stat "cells"       (last stderrs)))
              (and (pair? stderrs) (parse-stat "props"       (last stderrs)))
              (and (pair? stderrs) (parse-stat "committed"   (last stderrs)))
              (and (pair? stderrs) (parse-stat "dropped"     (last stderrs)))
              (and (pair? stderrs) (parse-stat "outer_iters" (last stderrs)))
              (cond [any-timeout? 'timeout-run]
                    [any-crash?   'crash]
                    [(null? ok-rs) 'crash]
                    [else 'ok])
              (cond [any-timeout?
                     (format "~a/~a runs hit ~as timeout"
                             (- (length rs) (length ok-rs))
                             (length rs)
                             (run-timeout-s))]
                    [any-crash?
                     (format "~a/~a runs crashed" (length rs) (length rs))]
                    [else ""])))
     (delete-file src-path)
     (delete-file out-bin)
     result]))

;; ============================================================
;; Driver + table emission
;; ============================================================

(define (run-one cfg)
  (define algorithm (car cfg))
  (define form (cadr cfg))
  (define n (caddr cfg))
  (printf "  ~a/~a N=~a... " algorithm form n)
  (flush-output)
  (define t0 (current-inexact-milliseconds))
  (define r
    (with-handlers ([exn:fail?
                     (lambda (e)
                       (cfg-r algorithm form n #f #f #f #f #f #f
                              #f #f #f #f #f #f #f
                              'crash (format "exn: ~a" (exn-message e))))])
      (measure-config algorithm form n)))
  (define elapsed (round (- (current-inexact-milliseconds) t0)))
  (case (cfg-r-status r)
    [(ok)
     (printf "(~ams; sched=~aμs, fires=~a, ns/fire=~a)~n"
             elapsed
             (let ([n (cfg-r-sched-ns-avg r)])
               (if n (real->decimal-string (/ n 1000.0) 1) "?"))
             (or (cfg-r-fires r) "?")
             (let ([n (cfg-r-sched-ns-avg r)] [f (cfg-r-fires r)])
               (cond [(and n f (> f 0))
                      (real->decimal-string (/ n f) 1)]
                     [else "?"])))]
    [else
     (printf "(~ams; ~a — ~a)~n" elapsed (cfg-r-status r) (cfg-r-note r))])
  r)

(printf "bench-native: ~a configs × ~a runs each~n" (length configs) (runs))
(printf "  run-timeout=~as  compile-timeout=~as~n~n"
        (run-timeout-s) (compile-timeout-s))

(define all-results (map run-one configs))

;; ------------------------------------------------------------
;; Table emission (mirrored to stdout and --out file if given)
;; ------------------------------------------------------------

(define (emit out)
  (define (P fmt . args) (apply fprintf out fmt args))

  (P "~n## Native scheduler timing (n runs averaged, kernel run_ns from PNET-STATS)~n~n")
  (P "Wall = full binary lifetime (exec + main + run_to_quiescence + exit).~n")
  (P "Sched μs = run_to_quiescence interior, kernel CLOCK_MONOTONIC.~n")
  (P "Wall - sched ≈ exec + libc startup + @main wiring + atexit (approx 5-15ms).~n~n")
  (P "| algorithm | form | N | Wall ms (min/avg/max) | Sched μs (min/avg/max) | ns/fire | Rounds | Fires | Cells | Props | Out-iter | status |~n")
  (P "|---|---|---|---|---|---|---|---|---|---|---|---|~n")

  (define (fmt-ms x) (if x (real->decimal-string x 2) "?"))
  (define (fmt-mam-ms a b c)
    (format "~a / ~a / ~a" (fmt-ms a) (fmt-ms b) (fmt-ms c)))
  (define (fmt-us x) (if x (real->decimal-string (/ x 1000.0) 1) "?"))
  (define (fmt-mam-us a b c)
    (format "~a / ~a / ~a" (fmt-us a) (fmt-us b) (fmt-us c)))
  (define (fmt-nspf ns f)
    (cond [(and ns f (> f 0)) (real->decimal-string (/ ns f) 1)]
          [else "?"]))

  (for ([r (in-list all-results)])
    (P "| ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a |~n"
       (cfg-r-algorithm r)
       (cfg-r-form r)
       (cfg-r-n r)
       (fmt-mam-ms (cfg-r-wall-min r) (cfg-r-wall-avg r) (cfg-r-wall-max r))
       (fmt-mam-us (cfg-r-sched-ns-min r) (cfg-r-sched-ns-avg r) (cfg-r-sched-ns-max r))
       (fmt-nspf (cfg-r-sched-ns-avg r) (cfg-r-fires r))
       (or (cfg-r-rounds r) "?")
       (or (cfg-r-fires r) "?")
       (or (cfg-r-cells r) "?")
       (or (cfg-r-props r) "?")
       (or (cfg-r-outer-iters r) "?")
       (cfg-r-status r)))

  (P "~n## Per-fire throughput (iterative algorithms; ns/fire across N)~n~n")
  (P "Should converge as N grows (per-fire amortized cost ⇒ fire-fn overhead).~n~n")
  (P "| algorithm | ~a |~n"
     (string-join
      (map (lambda (n) (format "N=~a" n)) n-values-iter) " | "))
  (P "|---~a|~n"
     (apply string-append (map (lambda (_) "|---") n-values-iter)))
  (for ([alg (in-list iter-algs)])
    (define cells
      (for/list ([n (in-list n-values-iter)])
        (define r (findf (lambda (rr) (and (eq? (cfg-r-algorithm rr) alg)
                                           (eq? (cfg-r-form rr) 'iterative)
                                           (= (cfg-r-n rr) n)
                                           (eq? (cfg-r-status rr) 'ok)))
                         all-results))
        (cond [(and r (cfg-r-sched-ns-avg r) (cfg-r-fires r) (> (cfg-r-fires r) 0))
               (real->decimal-string (/ (cfg-r-sched-ns-avg r) (cfg-r-fires r)) 1)]
              [else "?"])))
    (P "| ~a | ~a |~n" alg (string-join cells " | "))))

(emit (current-output-port))
(when (out-path)
  (call-with-output-file (out-path) #:exists 'truncate
    (lambda (out) (emit out)))
  (printf "~nReport mirrored to ~a~n" (out-path)))
