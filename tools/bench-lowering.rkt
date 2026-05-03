#lang racket/base

;; bench-lowering.rkt — Lowering pipeline performance + correctness
;; suite. Replaces tools/bench-{native,suite}.rkt.
;;
;; What it does:
;;   For each .prologos file in racket/prologos/benchmarks/lowering/,
;;     1. Compile through pnet-compile (with PROLOGOS_STATS=1).
;;     2. Time the COMPILE step (wall ms).
;;     3. For each declared input (or one no-arg run for closed-form),
;;        run the resulting binary `--runs` times and capture both
;;        wall-time and stdout (M5: parameterised main prints result).
;;     4. Verify correctness against the file's annotations:
;;          :expect-stdout-for N = V  for each declared input N
;;          :expect-exit V            for closed-form (no :inputs)
;;     5. Emit a markdown table with one row per (program, input)
;;        with min/avg/max wall, kernel sched ns/iter, and PASS/FAIL.
;;
;; Annotations recognized in `.prologos` source comments (anywhere):
;;
;;   ;; :expect-exit N           — expected process exit code (legacy)
;;   ;; :inputs A B C            — argv values to sweep through
;;   ;; :expect-stdout-for A = V — expected stdout when run with `A`
;;
;; Each input is run independently; per-input stats are reported.
;;
;; Usage:
;;   racket tools/bench-lowering.rkt
;;   racket tools/bench-lowering.rkt --runs 10
;;   racket tools/bench-lowering.rkt --filter tailrec
;;   racket tools/bench-lowering.rkt --out /tmp/bench.md
;;   racket tools/bench-lowering.rkt --run-timeout 30 --compile-timeout 120
;;
;; Exit code:
;;   0 if every (program, input) PASSes correctness.
;;   1 if any FAILs correctness or hits compile/run timeout.

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
 [("--runs") n "Native runs to average per (program, input) (default 5)"
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
;; Annotation parsing
;; ============================================================
;;
;; All annotations live in source comments and are matched anywhere
;; in the file.

(define (read-expect-exit content)
  ;; ;; :expect-exit N
  (define m (regexp-match #px":expect-exit\\s+(-?[0-9]+)" content))
  (and m (string->number (cadr m))))

(define (read-inputs content)
  ;; ;; :inputs A B C
  ;; Returns list of input strings (possibly empty).
  (define m (regexp-match #px":inputs\\s+([^\n]+)" content))
  (cond [(not m) '()]
        [else
         (define raw (cadr m))
         ;; Split on whitespace, strip blanks.
         (filter (lambda (s) (positive? (string-length s)))
                 (regexp-split #px"\\s+" (string-trim raw)))]))

(define (read-expect-stdouts content)
  ;; ;; :expect-stdout-for A = V
  ;; Returns list of (input-string . expected-stdout-string).
  ;; Multiple lines are accumulated.
  (for/list ([m (in-list (regexp-match*
                          #px":expect-stdout-for\\s+(\\S+)\\s*=\\s*([^\n]+)"
                          content #:match-select cdr))])
    (cons (string-trim (car m))
          (string-trim (cadr m)))))

;; ============================================================
;; Per-(program,input) measurement
;; ============================================================

(struct row
  (name              ;; program name (from filename)
   input             ;; #f for closed-form, string for parameterised
   expected-display  ;; string shown in "Expected" column
   compile-ms compile-status
   wall-min wall-avg wall-max
   kernel-ns
   rounds fires cells props
   correct?
   actual-display
   note)
  #:transparent)

(define (parse-stat key stderr-str)
  (define rx (regexp (format "\"~a\":([0-9]+)" (regexp-quote key))))
  (define m (regexp-match rx stderr-str))
  (and m (string->number (cadr m))))

(define (mn xs) (and (pair? xs) (apply min xs)))
(define (mx xs) (and (pair? xs) (apply max xs)))
(define (avg xs) (and (pair? xs) (/ (apply + xs) (length xs))))

(define (truncate-display s [n 24])
  (define s* (string-trim s))
  (cond [(> (string-length s*) n)
         (string-append (substring s* 0 (max 0 (- n 1))) "…")]
        [else s*]))

;; Run the binary `runs` times with the given (possibly empty) argv
;; list, returning a list of (status exit wall stdout-str stderr-str).
(define (run-binary-n out-bin argv)
  (for/list ([_ (in-range (runs))])
    (define-values (s ec wall stdout-bytes stderr-bytes)
      (run-with-timeout/capture
       (cons (path->string out-bin) argv)
       (run-timeout-s)))
    (list s ec wall
          (bytes->string/utf-8 stdout-bytes #\?)
          (bytes->string/utf-8 stderr-bytes #\?))))

;; Build a row for a single (program, input) measurement. `argv`
;; is '() for closed-form, or (list input-str) for parameterised.
;; `expected-stdout` is #f if we're checking exit-code, else the
;; expected stdout string.
(define (measure-one name out-bin input expected-exit expected-stdout
                     compile-ms compile-status)
  (define argv (cond [input (list input)] [else '()]))
  (cond
    [(not (eq? compile-status 'ok))
     ;; Already failed at compile time; bail with placeholder row.
     (row name input
          (if expected-stdout
              (format "stdout=~v" (truncate-display expected-stdout))
              (format "exit=~a" expected-exit))
          compile-ms compile-status
          #f #f #f #f #f #f #f #f
          #f "—"
          (format "compile ~a" compile-status))]
    [else
     ;; Warm-up.
     (run-with-timeout/capture
      (cons (path->string out-bin) argv) (run-timeout-s))
     (define rs (run-binary-n out-bin argv))
     (define statuses (map car rs))
     (define exits    (map cadr rs))
     (define walls    (map caddr rs))
     (define stdouts  (map cadddr rs))
     (define stderrs  (map (lambda (r) (list-ref r 4)) rs))
     (define any-timeout? (and (memq 'timeout statuses) #t))
     (define ok-mask (map (lambda (s) (eq? s 'ok)) statuses))
     (define (filter-ok lst) (for/list ([m (in-list ok-mask)] [v (in-list lst)] #:when m) v))
     (define ok-walls   (filter-ok walls))
     (define ok-stderrs (filter-ok stderrs))
     (define ok-exits   (filter-ok exits))
     (define ok-stdouts (filter-ok stdouts))
     (define run-nses (filter values (map (lambda (s) (parse-stat "run_ns" s))
                                          ok-stderrs)))
     ;; Decide pass/fail.
     (define-values (correct? actual-display expected-display note)
       (cond
         [any-timeout?
          (values #f "—"
                  (if expected-stdout
                      (format "stdout=~v" (truncate-display expected-stdout))
                      (format "exit=~a" expected-exit))
                  "run timeout")]
         [expected-stdout
          (define got-set (remove-duplicates (map string-trim ok-stdouts)))
          (define got-display
            (cond [(null? got-set) "—"]
                  [(= 1 (length got-set)) (truncate-display (car got-set))]
                  [else (string-join (map truncate-display got-set) "|")]))
          (define ok? (and (pair? ok-stdouts)
                           (andmap (lambda (s)
                                     (string=? (string-trim s) expected-stdout))
                                   ok-stdouts)))
          (values ok? got-display
                  (format "stdout=~v" (truncate-display expected-stdout))
                  (cond [ok? ""]
                        [else (format "stdout mismatch (got ~v vs expected ~v)"
                                      (truncate-display
                                       (or (and (pair? ok-stdouts) (car ok-stdouts))
                                           ""))
                                      (truncate-display expected-stdout))]))]
         [else
          ;; exit-code check.
          (define ok? (and (pair? ok-exits) expected-exit
                           (andmap (lambda (e) (eqv? e expected-exit)) ok-exits)))
          (values ok?
                  (cond [(pair? ok-exits) (number->string (car ok-exits))]
                        [else "—"])
                  (cond [expected-exit (format "exit=~a" expected-exit)]
                        [else "—"])
                  (cond [ok? ""]
                        [(not expected-exit) "no expectation declared"]
                        [else (format "exit mismatch (got ~v vs expected ~v)"
                                      (and (pair? ok-exits) (car ok-exits))
                                      expected-exit)]))]))
     (row name input
          expected-display
          compile-ms compile-status
          (mn ok-walls) (avg ok-walls) (mx ok-walls)
          (avg run-nses)
          (and (pair? ok-stderrs) (parse-stat "rounds" (last ok-stderrs)))
          (and (pair? ok-stderrs) (parse-stat "fires"  (last ok-stderrs)))
          (and (pair? ok-stderrs) (parse-stat "cells"  (last ok-stderrs)))
          (and (pair? ok-stderrs) (parse-stat "props"  (last ok-stderrs)))
          correct?
          actual-display
          note)]))

;; Compile the program to a temp binary, then measure across all
;; declared inputs (or one no-arg run for closed-form).
(define (measure-program path)
  (define name (path->string (file-name-from-path path)))
  (define content (file->string path))
  (define expected-exit (read-expect-exit content))
  (define inputs (read-inputs content))
  (define expects (read-expect-stdouts content))
  (define out-bin (make-temporary-file (format "bench-~a-~~a" name)))

  ;; ---- compile (one shared binary across all inputs) ----
  (define t0 (current-inexact-milliseconds))
  (define-values (cs cec _cwall _cout cerr)
    (run-with-timeout/capture
     (list racket-exe (path->string PNET-COMPILE-SCRIPT)
           "--no-run" "-o" (path->string out-bin) (path->string path))
     (compile-timeout-s)
     '(("PROLOGOS_STATS" "1"))))
  (define compile-ms (- (current-inexact-milliseconds) t0))
  (define compile-status
    (cond [(eq? cs 'timeout) 'timeout]
          [(not (zero? cec))  'crash]
          [else 'ok]))
  (define compile-note
    (cond [(eq? compile-status 'timeout)
           (format "compile timeout > ~as" (compile-timeout-s))]
          [(eq? compile-status 'crash)
           (format "compile exit ~a: ~a"
                   cec
                   (let ([s (bytes->string/utf-8 cerr #\?)])
                     (substring s 0 (min 80 (string-length s)))))]
          [else ""]))

  (define rows
    (cond
      [(pair? inputs)
       ;; Parameterised: one row per declared input.
       (for/list ([inp (in-list inputs)])
         (define expected-stdout
           (let ([m (assoc inp expects)])
             (and m (cdr m))))
         (define r (measure-one name out-bin inp expected-exit expected-stdout
                                compile-ms compile-status))
         ;; Tack on compile-note if compile failed and note empty.
         (cond [(eq? compile-status 'ok) r]
               [else (struct-copy row r [note compile-note])]))]
      [else
       ;; Closed-form: one row, no input, exit-code check.
       (define r (measure-one name out-bin #f expected-exit #f
                              compile-ms compile-status))
       (list (cond [(eq? compile-status 'ok) r]
                   [else (struct-copy row r [note compile-note])]))]))
  (when (file-exists? out-bin) (delete-file out-bin))
  rows)

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

(define (emit-table out all-rows)
  (define (P fmt . args) (apply fprintf out fmt args))
  (P "~n# Lowering Perf Suite — wall-time + correctness across ~a measurements~n"
     (length all-rows))
  (P "~nRuns per (program, input): ~a (warm-up + ~a measured runs).~n"
     (runs) (runs))
  (P "Correctness: parameterised programs check stdout against `:expect-stdout-for`;~n")
  (P "closed-form programs check exit code against `:expect-exit`.~n")
  (P "All programs live in `racket/prologos/benchmarks/lowering/`.~n~n")

  (P "## Per-(program, input) measurements~n~n")
  (P "| Program | Input | Compile ms | Wall min/avg/max ms | Kernel ns/iter | Cells | Props | Rounds | Got | Expected | OK |~n")
  (P "|---|---|---|---|---|---|---|---|---|---|---|~n")
  (for ([r (in-list all-rows)])
    (define wall
      (cond [(row-wall-min r)
             (format "~a / ~a / ~a"
                     (fmt-num (row-wall-min r) 2)
                     (fmt-num (row-wall-avg r) 2)
                     (fmt-num (row-wall-max r) 2))]
            [else "—"]))
    (P "| `~a` | ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a |~n"
       (row-name r)
       (or (row-input r) "—")
       (fmt-num (row-compile-ms r) 0)
       wall
       (fmt-ns (row-kernel-ns r))
       (fmt-num (row-cells r) 0)
       (fmt-num (row-props r) 0)
       (fmt-num (row-rounds r) 0)
       (row-actual-display r)
       (row-expected-display r)
       (cond [(row-correct? r) "✓"]
             [else (format "✗ — ~a" (row-note r))])))

  (P "~n## Summary~n~n")
  (define passes (length (filter row-correct? all-rows)))
  (define fails (- (length all-rows) passes))
  (P "  - PASS: ~a / ~a~n" passes (length all-rows))
  (P "  - FAIL: ~a / ~a~n" fails (length all-rows))

  (P "~n## By category (folded vs propagator-network)~n~n")
  (P "Programs whose `Cells = 1` and `Rounds = 0` were entirely~n")
  (P "static-folded by the lowering pipeline (Gate 2 + Gate 1 rev 1.5).~n")
  (P "Programs with `Rounds > 0` ran through the BSP scheduler~n")
  (P "(typically because `:inputs` makes the input opaque at compile time).~n~n")
  (define folded
    (filter (lambda (r) (and (eq? (row-compile-status r) 'ok)
                              (eqv? (row-rounds r) 0)))
            all-rows))
  (define live
    (filter (lambda (r) (and (eq? (row-compile-status r) 'ok)
                              (number? (row-rounds r))
                              (> (row-rounds r) 0)))
            all-rows))
  (P "  - Static-folded: ~a measurements.~n" (length folded))
  (P "  - Propagator-network: ~a measurements.~n" (length live))
  (when (pair? live)
    (P "~n  Propagator-network measurements (real runtime work):~n")
    (for ([r (in-list live)])
      (P "    - `~a` n=~a — ~a rounds, ~a fires, ~a cells, ~a wall ms avg.~n"
         (row-name r)
         (or (row-input r) "—")
         (row-rounds r)
         (row-fires r)
         (row-cells r)
         (fmt-num (row-wall-avg r) 2)))))

(define (emit out all-rows) (emit-table out all-rows))

;; ============================================================
;; Main
;; ============================================================

(printf "bench-lowering: discovering programs in ~a~n"
        (path->string BENCH-DIR))
(define programs (collect-programs))
(printf "  ~a programs.~n" (length programs))
(when (filter-pat)
  (printf "  filter: ~v~n" (filter-pat)))

(define all-rows
  (apply
   append
   (for/list ([p (in-list programs)] [i (in-naturals 1)])
     (define name (path->string (file-name-from-path p)))
     (printf "  [~a/~a] ~a... " i (length programs) name)
     (flush-output)
     (define rows (measure-program p))
     (define passes (length (filter row-correct? rows)))
     (define total (length rows))
     (printf "~a/~a OK"
             passes total)
     (for ([r (in-list rows)])
       (cond [(row-correct? r)
              (printf " | ~a→~a (~ams)"
                      (or (row-input r) "—")
                      (row-actual-display r)
                      (fmt-num (row-wall-avg r) 1))]
             [else
              (printf " | ~a→FAIL(~a)"
                      (or (row-input r) "—")
                      (row-note r))]))
     (printf "~n")
     (flush-output)
     rows)))

(emit (current-output-port) all-rows)
(when (out-path)
  (call-with-output-file (out-path) #:exists 'truncate
    (lambda (out) (emit out all-rows)))
  (printf "~nReport mirrored to ~a~n" (out-path)))

(exit (cond [(andmap row-correct? all-rows) 0] [else 1]))
