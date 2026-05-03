#lang racket/base

;; bench-lowering.rkt — Lowering pipeline performance + correctness
;; suite. Replaces tools/bench-{native,suite}.rkt.
;;
;; What it does:
;;   For each .prologos file in racket/prologos/benchmarks/lowering/,
;;     1. Compile through pnet-compile (with PROLOGOS_STATS=1).
;;     2. Time the COMPILE step (wall ms).
;;     3. Run the resulting binary `--runs` times (default 5).
;;     4. Capture wall ms for each run + parse PNET-STATS from stderr
;;        (rounds, fires, cells, props, run_ns).
;;     5. Verify the binary's exit code matches the file's :expect-exit.
;;     6. Emit a markdown table with per-program min/avg/max wall,
;;        kernel sched ns/iter, and a PASS/FAIL correctness flag.
;;
;; Design departures from the previous bench-{native,suite}.rkt:
;;   - No N-sweep. Each program ships at one fixed input size that
;;     was chosen to be representative.
;;   - No hand-rolled propagator networks (no gen-fib unrolled
;;     let-binding chain). All inputs are real Prologos source files
;;     under version control.
;;   - Correctness is a first-class column: a program that runs in
;;     6ms but returns the wrong exit code is a FAIL, not a PASS.
;;
;; Usage:
;;   racket tools/bench-lowering.rkt
;;   racket tools/bench-lowering.rkt --runs 10
;;   racket tools/bench-lowering.rkt --filter tailrec
;;   racket tools/bench-lowering.rkt --out /tmp/bench.md
;;   racket tools/bench-lowering.rkt --run-timeout 30 --compile-timeout 120
;;
;; Exit code:
;;   0 if every program PASSes correctness.
;;   1 if any program FAILs correctness or hits compile/run timeout.

(require racket/cmdline
         racket/system
         racket/port
         racket/list
         racket/file
         racket/format
         racket/path
         racket/runtime-path
         racket/string)

(define-runtime-path repo-root "..")
(define BENCH-DIR
  (build-path repo-root "racket" "prologos" "benchmarks" "lowering"))
(define PNET-COMPILE-SCRIPT
  (build-path repo-root "tools" "pnet-compile.rkt"))
(define RUNTIME-OBJ
  (or (getenv "PROLOGOS_RUNTIME_OBJ")
      (path->string (build-path repo-root "runtime" "prologos-runtime.o"))))

(define racket-exe (find-executable-path "racket"))

(define runs              (make-parameter 5))
(define run-timeout-s     (make-parameter 10))
(define compile-timeout-s (make-parameter 60))
(define out-path          (make-parameter #f))
(define filter-pat        (make-parameter #f))

(command-line
 #:program "bench-lowering"
 #:once-each
 [("--runs") n "Native runs to average per program (default 5)"
  (runs (string->number n))]
 [("--run-timeout") n "Per-native-run wall timeout in seconds (default 10)"
  (run-timeout-s (string->number n))]
 [("--compile-timeout") n "Per-config compile timeout in seconds (default 60)"
  (compile-timeout-s (string->number n))]
 [("--out") f "Mirror table output to this file" (out-path f)]
 [("--filter") s "Only run programs whose path matches this substring"
  (filter-pat s)])

;; ============================================================
;; Subprocess plumbing
;; ============================================================

(define (run-with-timeout/capture proc-args timeout-s [extra-env '()])
  ;; Spawn `proc-args` (a list starting with the executable). Wait
  ;; up to `timeout-s` seconds for completion. Returns:
  ;;   (values 'ok ec wall-ms stdout-bytes stderr-bytes)
  ;;   (values 'timeout #f wall-ms #"" #"")
  ;; extra-env is a list of (key value) pairs to inject into the
  ;; subprocess's env (key + value are both strings). Doesn't mutate
  ;; the parent's env.
  (define old-vals
    (for/list ([kv (in-list extra-env)])
      (define k (car kv)) (define v (cadr kv))
      (define old (getenv k))
      (putenv k v)
      (cons k old)))
  (define-values (proc proc-out proc-in proc-err)
    (apply subprocess #f #f #f proc-args))
  (close-output-port proc-in)
  ;; Drain output ports concurrently so the child doesn't block on
  ;; full pipe buffers (LLVM IR can be large).
  (define out-ch (make-channel))
  (define err-ch (make-channel))
  (define t-out (thread (lambda () (channel-put out-ch (port->bytes proc-out)))))
  (define t-err (thread (lambda () (channel-put err-ch (port->bytes proc-err)))))
  (define t0 (current-inexact-milliseconds))
  (define deadline (+ t0 (* 1000 timeout-s)))
  (define status
    (let loop ()
      (cond
        [(eq? (subprocess-status proc) 'running)
         (cond
           [(> (current-inexact-milliseconds) deadline)
            (subprocess-kill proc #t) (sync proc) 'timeout]
           [else (sleep 0.005) (loop)])]
        [else 'done])))
  (define wall-ms (- (current-inexact-milliseconds) t0))
  (define out-bytes (channel-get out-ch))
  (define err-bytes (channel-get err-ch))
  (close-input-port proc-out)
  (close-input-port proc-err)
  (for ([kv (in-list old-vals)])
    (putenv (car kv) (or (cdr kv) "")))
  (cond
    [(eq? status 'timeout) (values 'timeout #f wall-ms #"" #"")]
    [else (values 'ok (subprocess-status proc) wall-ms out-bytes err-bytes)]))

;; ============================================================
;; Per-program measurement
;; ============================================================

(struct prog-r
  (name path expected-exit
   compile-ms compile-status      ;; 'ok 'timeout 'crash
   wall-min wall-avg wall-max
   kernel-ns                      ;; from PNET-STATS run_ns (avg)
   rounds fires cells props
   correct?                       ;; #t if every run's exit == expected
   actual-exit                    ;; first run's exit (for diagnosis)
   note)
  #:transparent)

(define (parse-stat key stderr-str)
  (define rx (regexp (format "\"~a\":([0-9]+)" (regexp-quote key))))
  (define m (regexp-match rx stderr-str))
  (and m (string->number (cadr m))))

(define (read-expect-exit path)
  (define content (file->string path))
  (define m (regexp-match #px":expect-exit (-?[0-9]+)" content))
  (and m (string->number (cadr m))))

(define (mn xs) (and (pair? xs) (apply min xs)))
(define (mx xs) (and (pair? xs) (apply max xs)))
(define (avg xs) (and (pair? xs) (/ (apply + xs) (length xs))))

(define (measure-program path)
  (define name (path->string (file-name-from-path path)))
  (define expected (read-expect-exit path))
  (define out-bin (make-temporary-file (format "bench-~a-~~a" name)))

  ;; ---- compile ----
  (define t0 (current-inexact-milliseconds))
  (define-values (cs cec _cwall _cout cerr)
    (run-with-timeout/capture
     (list racket-exe (path->string PNET-COMPILE-SCRIPT)
           "--no-run" "-o" (path->string out-bin) (path->string path))
     (compile-timeout-s)
     '(("PROLOGOS_STATS" "1"))))
  (define compile-ms (- (current-inexact-milliseconds) t0))
  (cond
    [(eq? cs 'timeout)
     (when (file-exists? out-bin) (delete-file out-bin))
     (prog-r name path expected compile-ms 'timeout
             #f #f #f #f #f #f #f #f #f
             expected (format "compile timeout > ~as" (compile-timeout-s)))]
    [(not (zero? cec))
     (when (file-exists? out-bin) (delete-file out-bin))
     (prog-r name path expected compile-ms 'crash
             #f #f #f #f #f #f #f #f #f
             expected (format "compile exit ~a: ~a"
                              cec
                              (let ([s (bytes->string/utf-8 cerr #\?)])
                                (substring s 0 (min 80 (string-length s))))))]
    [else
     ;; ---- runs ----
     ;; Warm-up to defeat OS-level cold-cache penalty.
     (run-with-timeout/capture (list (path->string out-bin)) (run-timeout-s))
     (define rs
       (for/list ([_ (in-range (runs))])
         (call-with-values
          (lambda () (run-with-timeout/capture
                      (list (path->string out-bin)) (run-timeout-s)))
          list)))
     (define statuses (map car rs))
     (define exits    (map cadr rs))
     (define walls    (map caddr rs))
     (define stderrs  (map (lambda (r) (cadddr (cdr r))) rs)) ; 5th = stderr-bytes
     (define stderr-strs
       (map (lambda (b) (bytes->string/utf-8 b #\?)) stderrs))
     (define any-timeout? (memq 'timeout statuses))
     (define ok-walls (for/list ([s (in-list statuses)]
                                  [w (in-list walls)]
                                  #:when (eq? s 'ok))
                         w))
     (define ok-stderrs (for/list ([s (in-list statuses)]
                                    [e (in-list stderr-strs)]
                                    #:when (eq? s 'ok))
                          e))
     (define run-nses (filter values (map (lambda (s) (parse-stat "run_ns" s))
                                          ok-stderrs)))
     (define ok-exits (for/list ([s (in-list statuses)]
                                  [e (in-list exits)]
                                  #:when (eq? s 'ok))
                         e))
     (define correct? (and (not any-timeout?)
                           (pair? ok-exits)
                           (andmap (lambda (e) (eqv? e expected)) ok-exits)))
     (when (file-exists? out-bin) (delete-file out-bin))
     (prog-r name path expected compile-ms 'ok
             (mn ok-walls) (avg ok-walls) (mx ok-walls)
             (avg run-nses)
             (and (pair? ok-stderrs) (parse-stat "rounds" (last ok-stderrs)))
             (and (pair? ok-stderrs) (parse-stat "fires"  (last ok-stderrs)))
             (and (pair? ok-stderrs) (parse-stat "cells"  (last ok-stderrs)))
             (and (pair? ok-stderrs) (parse-stat "props"  (last ok-stderrs)))
             correct?
             (and (pair? ok-exits) (car ok-exits))
             (cond [any-timeout? "run timeout"]
                   [(not correct?)
                    (format "exit mismatch (got ~v vs expected ~v)"
                            (and (pair? ok-exits) (car ok-exits)) expected)]
                   [else ""]))]))

;; ============================================================
;; Driver + table emission
;; ============================================================

(define (collect-programs)
  (define raw
    (for/list ([p (in-directory BENCH-DIR)]
               #:when (and (file-exists? p)
                           (regexp-match? #px"\\.prologos$" (path->string p))))
      p))
  (define filtered
    (cond [(filter-pat)
           (filter (lambda (p) (regexp-match? (filter-pat) (path->string p))) raw)]
          [else raw]))
  (sort filtered path<?))

(define (fmt-num x [precision 2])
  (cond [(not x) "—"]
        [(integer? x) (number->string x)]
        [(rational? x) (real->decimal-string (exact->inexact x) precision)]
        [else (~v x)]))

(define (fmt-ns x)
  (cond [(not x) "—"]
        [(< x 1000) (format "~ans" (round x))]
        [(< x 1000000) (format "~aμs" (real->decimal-string (/ x 1000.0) 1))]
        [else (format "~ams" (real->decimal-string (/ x 1000000.0) 1))]))

(define (emit-table out results)
  (define (P fmt . args) (apply fprintf out fmt args))
  (P "~n# Lowering Perf Suite — wall-time + correctness across ~a Prologos programs~n"
     (length results))
  (P "~nRuns per program: ~a (warm-up + ~a measured runs).~n" (runs) (runs))
  (P "Correctness: each run's exit code must match the file's `:expect-exit`.~n")
  (P "All programs live in `racket/prologos/benchmarks/lowering/`.~n~n")

  (P "## Per-program measurements~n~n")
  (P "| Program | Compile ms | Wall min/avg/max ms | Kernel ns/iter | Cells | Props | Rounds | Exit | OK |~n")
  (P "|---|---|---|---|---|---|---|---|---|~n")
  (for ([r (in-list results)])
    (define n (prog-r-name r))
    (define wall
      (cond [(prog-r-wall-min r)
             (format "~a / ~a / ~a"
                     (fmt-num (prog-r-wall-min r) 2)
                     (fmt-num (prog-r-wall-avg r) 2)
                     (fmt-num (prog-r-wall-max r) 2))]
            [else "—"]))
    (P "| `~a` | ~a | ~a | ~a | ~a | ~a | ~a | ~a/~a | ~a |~n"
       n
       (fmt-num (prog-r-compile-ms r) 0)
       wall
       (fmt-ns (prog-r-kernel-ns r))
       (fmt-num (prog-r-cells r) 0)
       (fmt-num (prog-r-props r) 0)
       (fmt-num (prog-r-rounds r) 0)
       (fmt-num (prog-r-actual-exit r) 0)
       (fmt-num (prog-r-expected-exit r) 0)
       (cond [(prog-r-correct? r) "✓"]
             [else (format "✗ — ~a" (prog-r-note r))])))

  (P "~n## Summary~n~n")
  (define passes
    (length (filter prog-r-correct? results)))
  (define fails (- (length results) passes))
  (P "  - PASS: ~a / ~a~n" passes (length results))
  (P "  - FAIL: ~a / ~a~n" fails (length results))

  ;; Quick categorization by prefix in the filename.
  (P "~n## By category (folded vs propagator-network)~n~n")
  (P "Programs whose `Cells = 1` and `Rounds = 0` were entirely~n")
  (P "static-folded by the lowering pipeline (Gate 2 + Gate 1 rev 1.5).~n")
  (P "Programs with `Rounds > 0` ran through the BSP scheduler.~n~n")
  (define folded
    (filter (lambda (r) (and (eq? (prog-r-compile-status r) 'ok)
                              (eqv? (prog-r-rounds r) 0)))
            results))
  (define live
    (filter (lambda (r) (and (eq? (prog-r-compile-status r) 'ok)
                              (number? (prog-r-rounds r))
                              (> (prog-r-rounds r) 0)))
            results))
  (P "  - Static-folded: ~a programs.~n" (length folded))
  (P "  - Propagator-network: ~a programs.~n" (length live))
  (when (pair? live)
    (P "~n  Propagator-network programs (real runtime work):~n")
    (for ([r (in-list live)])
      (P "    - `~a` — ~a rounds, ~a fires, ~a cells, ~a wall ms avg.~n"
         (prog-r-name r)
         (prog-r-rounds r)
         (prog-r-fires r)
         (prog-r-cells r)
         (fmt-num (prog-r-wall-avg r) 2)))))

(define (emit out results)
  (emit-table out results))

;; ============================================================
;; Main
;; ============================================================

(printf "bench-lowering: discovering programs in ~a~n"
        (path->string BENCH-DIR))
(define programs (collect-programs))
(printf "  ~a programs.~n" (length programs))
(when (filter-pat)
  (printf "  filter: ~v~n" (filter-pat)))

(define results
  (for/list ([p (in-list programs)] [i (in-naturals 1)])
    (define name (path->string (file-name-from-path p)))
    (printf "  [~a/~a] ~a... " i (length programs) name)
    (flush-output)
    (define r (measure-program p))
    (define tag
      (cond [(prog-r-correct? r)
             (format "OK (~ams compile, ~ams wall avg)"
                     (fmt-num (prog-r-compile-ms r) 0)
                     (fmt-num (prog-r-wall-avg r) 1))]
            [else
             (format "FAIL (~a)" (prog-r-note r))]))
    (printf "~a~n" tag)
    (flush-output)
    r))

(emit (current-output-port) results)
(when (out-path)
  (call-with-output-file (out-path) #:exists 'truncate
    (lambda (out) (emit out results)))
  (printf "~nReport mirrored to ~a~n" (out-path)))

(exit (cond [(andmap prog-r-correct? results) 0] [else 1]))
