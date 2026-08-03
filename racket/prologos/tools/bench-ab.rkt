#lang racket/base

;; bench-ab.rkt — Comparative A/B benchmark framework
;;
;; Usage:
;;   racket tools/bench-ab.rkt benchmarks/comparative/ --runs 15
;;   racket tools/bench-ab.rkt benchmarks/comparative/simple-typed.prologos --runs 10
;;   racket tools/bench-ab.rkt --refs HEAD~1 benchmarks/comparative/       # vs one commit
;;   racket tools/bench-ab.rkt --refs HEAD~1,HEAD~5 benchmarks/comparative/ # multi-way
;;   racket tools/bench-ab.rkt benchmarks/comparative/ --runs 15 --output results.json
;;   racket tools/bench-ab.rkt --refs HEAD~1 --md report.md benchmarks/comparative/
;;
;; Runs each program N times per variant, collects wall-time and heartbeat
;; distributions, computes Mann-Whitney U against the working tree.
;;
;; Default (no --refs): compare the working tree against ITSELF — a stability
;; test, and nothing more. That is worth saying plainly, because this tool's
;; documented flag for comparing against another commit (`--ref`) NEVER EXISTED:
;; the header advertised it, `workflow.md` instructed its use, and the B leg ran
;; against the same tree. Anyone following the documentation measured identical
;; code twice and read the difference as a result.
;;
;; `--refs` is that flag, built the only safe way. Each ref gets its OWN GIT
;; WORKTREE, built there and run from there; the benchmark PROGRAMS always come
;; from the working tree, so every variant is measured on identical input. No
;; stash, no checkout: the working tree is never touched, which matters because
;; it routinely holds uncommitted work (`workflow.md`: "NEVER `git stash`").
;;
;; With --output: persist JSON results (timestamp, commit, per-variant distributions).
;; With --md: write a markdown comparison table.

(require racket/cmdline
         racket/list
         racket/string
         racket/path
         racket/port
         racket/system
         racket/math
         racket/file
         json
         "bench-lib.rkt"
         "bench-micro.rkt")

;; Compile-limit adoption (Rel T1 SUB.2, owner-blessed 2026-07-24): raise the
;; CS machine-code compile limit for every build/run this tool spawns, so A/B
;; comparisons run under the production compile mode (interpreted-vs-compiled
;; rankings demonstrably invert). Full rationale + measurements: the twin
;; putenv in run-affected-tests.rkt + the defect doc §4.2.
(void
 (unless (getenv "PLT_CS_COMPILE_LIMIT")
   (putenv "PLT_CS_COMPILE_LIMIT" "1000000")))

;; Benchmarks want the PRECISE retained-bytes figure, which needs a major GC on
;; each side of a command. That forced GC is off by default because it cost the
;; test suite 2.3x wall time for numbers nothing read (see
;; performance-counters.rkt § mem-stats-force-gc?) — but here it is the point,
;; so turn it back on for everything this tool spawns.
(void
 (unless (getenv "PROLOGOS_MEM_STATS_GC")
   (putenv "PROLOGOS_MEM_STATS_GC" "1")))

;; ============================================================
;; Path anchoring
;; ============================================================

(define tools-dir
  (let ([src (resolved-module-path-name
              (variable-reference->resolved-module-path
               (#%variable-reference)))])
    (simplify-path (path-only src))))

(define project-root
  (path->string (simplify-path (build-path tools-dir ".."))))

;; ============================================================
;; Mann-Whitney U test (exact, for small N)
;; ============================================================

;; Compute the U statistic for two samples.
;; Returns (values U1 U2 z-approx p-approx).
;; For N ≤ 20, uses normal approximation with continuity correction.
(define (mann-whitney-u xs ys)
  (define n1 (length xs))
  (define n2 (length ys))
  ;; Combine and rank
  (define combined
    (sort (append (for/list ([x (in-list xs)] [i (in-naturals)])
                    (list x 'a i))
                  (for/list ([y (in-list ys)] [i (in-naturals)])
                    (list y 'b i)))
          < #:key car))
  ;; Assign ranks (average for ties)
  (define ranks (make-vector (+ n1 n2) 0.0))
  (let loop ([i 0])
    (when (< i (length combined))
      ;; Find extent of tie group
      (define val (car (list-ref combined i)))
      (define j
        (let scan ([j (add1 i)])
          (if (and (< j (length combined))
                   (= (car (list-ref combined j)) val))
              (scan (add1 j))
              j)))
      ;; Average rank for positions i..j-1 (1-indexed)
      (define avg-rank (/ (+ (for/sum ([k (in-range i j)]) (+ k 1.0))) (- j i)))
      (for ([k (in-range i j)])
        (vector-set! ranks k avg-rank))
      (loop j)))
  ;; Sum ranks for group A
  (define R1
    (for/sum ([k (in-range (length combined))])
      (if (eq? (cadr (list-ref combined k)) 'a)
          (vector-ref ranks k)
          0.0)))
  ;; U statistics
  (define U1 (- R1 (/ (* n1 (+ n1 1)) 2.0)))
  (define U2 (- (* n1 n2) U1))
  ;; Normal approximation (valid for n1,n2 ≥ 5)
  (define mu (/ (* n1 n2) 2.0))
  (define sigma (sqrt (/ (* n1 n2 (+ n1 n2 1)) 12.0)))
  (define z (if (zero? sigma) 0.0 (/ (- (min U1 U2) mu) sigma)))
  ;; Two-tailed p-value approximation via standard normal CDF
  (define p (* 2.0 (normal-cdf (- (abs z)))))
  (values U1 U2 z p))

;; Standard normal CDF approximation (Abramowitz & Stegun 26.2.17)
(define (normal-cdf x)
  (cond
    [(< x -8.0) 0.0]
    [(> x 8.0) 1.0]
    [else
     (define b1 0.319381530)
     (define b2 -0.356563782)
     (define b3 1.781477937)
     (define b4 -1.821255978)
     (define b5 1.330274429)
     (define p 0.2316419)
     (define c 0.39894228)
     (define abs-x (abs x))
     (define t (/ 1.0 (+ 1.0 (* p abs-x))))
     (define val (- 1.0 (* c (exp (* -0.5 abs-x abs-x))
                              t (+ b1 (* t (+ b2 (* t (+ b3 (* t (+ b4 (* t b5)))))))))))
     (if (>= x 0.0) val (- 1.0 val))]))

;; ============================================================
;; Single-program benchmark runner
;; ============================================================

;; Run a single .prologos program via driver subprocess, return wall_ms.
(define (bench-program-once program-path [driver-root project-root])
  (define driver-path (path->string (build-path driver-root "driver.rkt")))
  (define t0 (current-inexact-monotonic-milliseconds))
  (define-values (proc stdout-port stdin-port stderr-port)
    (subprocess #f #f #f racket-path driver-path program-path))
  (close-output-port stdin-port)
  (subprocess-wait proc)
  (define t1 (current-inexact-monotonic-milliseconds))
  (define wall-ms (- t1 t0))
  ;; Extract heartbeat count from stderr
  (define err-output (port->string stderr-port))
  (close-input-port stdout-port)
  (close-input-port stderr-port)
  (define hb (extract-perf-counters err-output))
  (define total-hb
    (if (and hb (hash? hb))
        (for/sum ([(k v) (in-hash hb)]) v)
        0))
  (hasheq 'wall_ms wall-ms
          'total_heartbeats total-hb
          'status (if (zero? (subprocess-status proc)) "ok" "fail")))

;; Run a program N times, return list of result hashes
(define (bench-program program-path n [driver-root project-root])
  ;; Warmup run (not counted)
  (bench-program-once program-path driver-root)
  ;; Measured runs
  (for/list ([_ (in-range n)])
    (collect-garbage 'major)
    (bench-program-once program-path driver-root)))


;; ============================================================
;; Variant worktrees (--refs)
;; ============================================================
;;
;; One git worktree per ref, built in place, torn down at the end. Worktrees
;; and not `git stash` + `git checkout`: the working tree routinely holds
;; uncommitted work, and a benchmark run must not be able to disturb it — the
;; standing rule in `workflow.md`. It also means a variant can be built ONCE and
;; measured repeatedly without re-checking-out between samples.

(define repo-root
  (path->string (simplify-path (build-path project-root ".." ".."))))

(define (git-ok? . args)
  (define out (open-output-string))
  (define ok?
    (parameterize ([current-output-port out] [current-error-port out])
      (apply system* (find-executable-path "git") args)))
  (unless ok? (printf "~a" (get-output-string out)))
  ok?)

;; A ref may contain characters a directory name should not.
(define (ref->dirname ref)
  (regexp-replace* #rx"[^A-Za-z0-9._-]" ref "_"))

;; (values label driver-root cleanup-thunk), or #f if the ref could not be
;; prepared — a variant that will not BUILD must be reported and skipped, never
;; silently measured against the working tree's driver (which is what a missing
;; `--ref` did for the life of this tool).
(define (prepare-variant ref base-dir)
  (define wt (build-path base-dir (ref->dirname ref)))
  (printf "  preparing ~a … " ref)
  (flush-output)
  (cond
    [(not (git-ok? "-C" repo-root "worktree" "add" "--detach"
                   (path->string wt) ref))
     (printf "FAILED (worktree add)\n")
     #f]
    [else
     (define driver-root (path->string (build-path wt "racket" "prologos")))
     (define built?
       (parameterize ([current-directory driver-root])
         (define out (open-output-string))
         (parameterize ([current-output-port out] [current-error-port out])
           (system* (find-executable-path "raco") "make" "driver.rkt"))))
     (cond
       [built? (printf "ok\n") (list ref driver-root wt)]
       [else
        (printf "FAILED (raco make)\n")
        (git-ok? "-C" repo-root "worktree" "remove" "--force" (path->string wt))
        #f])]))

(define (cleanup-variant v)
  (when (and v (= (length v) 3))
    (git-ok? "-C" repo-root "worktree" "remove" "--force"
             (path->string (caddr v)))))

;; ============================================================
;; A/B comparison
;; ============================================================

;; Run A/B comparison, printing results and returning a list of per-program
;; result hashes for serialization.

;; Multi-variant comparison: the working tree plus one built worktree per ref.
;; Every variant runs the SAME programs — the .prologos files always come from
;; the working tree — so what is being compared is the compiler, not the input.
(define (run-multi-comparison programs num-runs refs md-file)
  (printf "\n═══ Multi-Variant Benchmark Comparison ═══\n")
  (printf "Runs per program per variant: ~a (+ 1 warmup)\n" num-runs)
  (printf "Programs: ~a   Variants: ~a\n" (length programs) (add1 (length refs)))
  (printf "\nBuilding variants:\n")
  (define base-dir (make-temporary-directory))
  (define prepared (filter values (for/list ([r (in-list refs)]) (prepare-variant r base-dir))))
  (when (< (length prepared) (length refs))
    (printf "\n⚠  ~a of ~a refs could not be prepared and are EXCLUDED.\n"
            (- (length refs) (length prepared)) (length refs)))
  (define variants (cons (list "WORKING" project-root #f) prepared))
  (define rows
    (for/list ([prog (in-list programs)])
      (define name (path->string (file-name-from-path (string->path prog))))
      (printf "\n── ~a ──\n" name)
      (define per-variant
        (for/list ([v (in-list variants)])
          (printf "  ~a …" (car v))
          (flush-output)
          (define rs (bench-program prog num-runs (cadr v)))
          (define times (map (λ (r) (hash-ref r 'wall_ms)) rs))
          (printf " median ~a ms (CV ~a%)\n"
                  (real->decimal-string (median times) 1)
                  (real->decimal-string (* 100 (cv times)) 1))
          (hasheq 'variant (car v)
                  'median_ms (median times)
                  'cv (cv times)
                  'wall_ms times)))
      ;; Ratio + significance against the working tree, which is variant 0.
      (define base-times (hash-ref (car per-variant) 'wall_ms))
      (define base-med (hash-ref (car per-variant) 'median_ms))
      (define annotated
        (for/list ([pv (in-list per-variant)] [i (in-naturals)])
          (cond
            [(zero? i) (hash-set* pv 'ratio 1.0 'p_value 1.0)]
            [else
             (define-values (_u1 _u2 _z p) (mann-whitney-u base-times (hash-ref pv 'wall_ms)))
             (hash-set* pv
                        'ratio (if (zero? base-med) 0.0 (/ (hash-ref pv 'median_ms) base-med))
                        'p_value p)])))
      (hasheq 'program name 'variants annotated)))
  (for-each cleanup-variant prepared)
  (with-handlers ([exn:fail? void]) (delete-directory base-dir))
  (print-multi-table rows)
  (when md-file (write-multi-markdown rows md-file num-runs))
  rows)

;; The table is the deliverable — a multi-way run is unreadable as a stream of
;; per-variant lines.
(define (print-multi-table rows)
  (printf "\n═══ Summary (median ms, ratio vs WORKING) ═══\n")
  (for ([row (in-list rows)])
    (printf "\n~a\n" (hash-ref row 'program))
    (for ([v (in-list (hash-ref row 'variants))])
      (printf "  ~a~a  ~a ms   ×~a~a\n"
              (hash-ref v 'variant)
              (make-string (max 1 (- 18 (string-length (hash-ref v 'variant)))) #\space)
              (real->decimal-string (hash-ref v 'median_ms) 1)
              (real->decimal-string (hash-ref v 'ratio) 3)
              (if (< (hash-ref v 'p_value) 0.05) "  (p<0.05)" "")))))

(define (write-multi-markdown rows md-file num-runs)
  (make-directory* (path-only (string->path md-file)))
  (call-with-output-file md-file #:exists 'replace
    (lambda (out)
      (fprintf out "# Benchmark comparison\n\n")
      (fprintf out "~a runs per program per variant. Ratio is median wall vs the working tree; " num-runs)
      (fprintf out "`p` is Mann-Whitney against the working tree's samples.\n\n")
      (for ([row (in-list rows)])
        (fprintf out "## ~a\n\n" (hash-ref row 'program))
        (fprintf out "| variant | median ms | CV | ratio | p |\n")
        (fprintf out "|---|---:|---:|---:|---:|\n")
        (for ([v (in-list (hash-ref row 'variants))])
          (fprintf out "| ~a | ~a | ~a% | ×~a | ~a |\n"
                   (hash-ref v 'variant)
                   (real->decimal-string (hash-ref v 'median_ms) 1)
                   (real->decimal-string (* 100 (hash-ref v 'cv)) 1)
                   (real->decimal-string (hash-ref v 'ratio) 3)
                   (real->decimal-string (hash-ref v 'p_value) 4)))
        (fprintf out "\n"))))
  (printf "\nMarkdown table written to ~a\n" md-file))

(define (run-ab-comparison programs num-runs)
  (printf "\n═══ A/B Benchmark Comparison ═══\n")
  (printf "Runs per program: ~a (+ 1 warmup)\n" num-runs)
  (printf "Programs: ~a\n\n" (length programs))

  (for/list ([prog (in-list programs)])
    (define name (path->string (file-name-from-path (string->path prog))))
    (printf "── ~a ──\n" name)

    ;; Run A samples (current code)
    (printf "  Running A samples...")
    (define a-results (bench-program prog num-runs))
    (define a-times (map (λ (r) (hash-ref r 'wall_ms)) a-results))
    (define a-hbs (map (λ (r) (hash-ref r 'total_heartbeats)) a-results))
    (printf " done.\n")

    ;; Run B samples (same code for now; with --ref would checkout different code)
    (printf "  Running B samples...")
    (define b-results (bench-program prog num-runs))
    (define b-times (map (λ (r) (hash-ref r 'wall_ms)) b-results))
    (define b-hbs (map (λ (r) (hash-ref r 'total_heartbeats)) b-results))
    (printf " done.\n")

    ;; Statistics
    (define a-med (median a-times))
    (define b-med (median b-times))
    (define a-cv-val (cv a-times))
    (define b-cv-val (cv b-times))
    (define speedup (if (zero? b-med) 0.0 (- (/ a-med b-med) 1.0)))

    ;; Mann-Whitney U test
    (define-values (U1 U2 z p) (mann-whitney-u a-times b-times))
    (define significant? (< p 0.05))

    (printf "  A: median=~ams  cv=~a%\n"
            (exact->inexact (round a-med))
            (exact->inexact (/ (round (* a-cv-val 10)) 10.0)))
    (printf "  B: median=~ams  cv=~a%\n"
            (exact->inexact (round b-med))
            (exact->inexact (/ (round (* b-cv-val 10)) 10.0)))
    (printf "  Speedup: ~a%  U=~a  z=~a  p=~a  ~a\n\n"
            (exact->inexact (/ (round (* speedup 1000)) 10.0))
            (exact->inexact (round (min U1 U2)))
            (exact->inexact (/ (round (* z 100)) 100.0))
            (exact->inexact (/ (round (* p 10000)) 10000.0))
            (if significant? "*** SIGNIFICANT ***" "(not significant)"))

    ;; Return structured result for serialization
    (hasheq 'program name
            'a_wall_ms (map exact->inexact a-times)
            'b_wall_ms (map exact->inexact b-times)
            'a_heartbeats a-hbs
            'b_heartbeats b-hbs
            'a_median_ms (exact->inexact a-med)
            'b_median_ms (exact->inexact b-med)
            'a_cv (exact->inexact a-cv-val)
            'b_cv (exact->inexact b-cv-val)
            'speedup (exact->inexact speedup)
            'U (exact->inexact (min U1 U2))
            'z (exact->inexact z)
            'p (exact->inexact p)
            'significant significant?)))

;; ============================================================
;; CLI
;; ============================================================

(define num-runs (make-parameter 15))
(define output-file (make-parameter #f))

;; Pre-process args: reorder so flags come before positional args.
;; racket/cmdline requires flags before positional args — silently treating
;; misplaced flags as paths caused a hard-to-diagnose "no output" bug.
(define (reorder-args args)
  (define flags '())
  (define paths '())
  (let loop ([rest (vector->list args)])
    (cond
      [(null? rest) (list->vector (append (reverse flags) (reverse paths)))]
      [(string-prefix? (car rest) "--")
       ;; Flag + its value (next arg)
       (if (null? (cdr rest))
           (loop '()) ;; dangling flag, let command-line handle the error
           (begin
             (set! flags (cons (cadr rest) (cons (car rest) flags)))
             (loop (cddr rest))))]
      [else
       (set! paths (cons (car rest) paths))
       (loop (cdr rest))])))

(define ref-list (make-parameter '()))
(define md-file (make-parameter #f))

(current-command-line-arguments (reorder-args (current-command-line-arguments)))

(define program-paths
  (command-line
   #:program "bench-ab"
   #:once-each
   ["--runs" n "Number of measured runs per program (default: 15)"
    (num-runs (string->number n))]
   ["--output" file "Write JSON results to FILE"
    (output-file file)]
   ["--refs" refs "Comma-separated git refs to compare against the working tree (each gets its own worktree)"
    (ref-list (filter (lambda (r) (not (string=? r "")))
                      (map string-trim (string-split refs ","))))]
   ["--md" file "Write a markdown comparison table to FILE (with --refs)"
    (md-file file)]
   #:args paths
   (apply append
          (for/list ([p (in-list paths)])
            (cond
              [(directory-exists? p)
               ;; Collect all .prologos files in directory
               (sort (for/list ([f (in-directory p)]
                                #:when (regexp-match? #rx"\\.prologos$"
                                                     (path->string (file-name-from-path f))))
                       (path->string f))
                     string<?)]
              [(file-exists? p) (list p)]
              [else
               (printf "Warning: ~a not found, skipping.\n" p)
               '()])))))

(cond
  [(null? program-paths)
   (printf "No programs to benchmark.\n")
   (printf "Usage: racket tools/bench-ab.rkt benchmarks/comparative/\n")]
  [(pair? (ref-list))
   (define results (run-multi-comparison program-paths (num-runs) (ref-list) (md-file)))
   (when (output-file)
     (define out-path (output-file))
     (make-directory* (path-only (string->path out-path)))
     (call-with-output-file out-path #:exists 'replace
       (lambda (out)
         (write-json (hasheq 'timestamp (current-iso-timestamp)
                             'commit (current-commit)
                             'runs_per_program (num-runs)
                             'refs (ref-list)
                             'programs results)
                     out)))
     (printf "\nJSON results written to ~a\n" out-path))]
  [else
   (define results (run-ab-comparison program-paths (num-runs)))
   ;; Persist results if --output was given
   (when (output-file)
     (define out-path (output-file))
     (make-directory* (path-only (string->path out-path)))
     (define record
       (hasheq 'timestamp (current-iso-timestamp)
               'commit (current-commit)
               'runs_per_program (num-runs)
               'programs results))
     (call-with-output-file out-path
       (λ (port) (write-json record port) (newline port))
       #:exists 'replace)
     (printf "Results written to ~a\n" out-path))])
