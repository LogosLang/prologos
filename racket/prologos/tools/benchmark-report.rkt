#lang racket/base

;; benchmark-report.rkt — Static HTML benchmark report with Vega-Lite charts
;;
;; Usage:
;;   racket tools/benchmark-report.rkt                    # report from last 10 runs
;;   racket tools/benchmark-report.rkt --last 20          # last 20 runs
;;   racket tools/benchmark-report.rkt --output report.html  # custom output path
;;   racket tools/benchmark-report.rkt --compare HEAD~3   # highlight comparison commit
;;
;; Reads data/benchmarks/timings.jsonl, generates a self-contained HTML file
;; with embedded Vega-Lite specs for:
;;   1. Suite wall-time trend (line chart)
;;   2. Per-file timing heatmap (top slowest files across runs)
;;   3. Phase breakdown (stacked bar, when phase data available)
;;   4. Heartbeat trends (when heartbeat data available)
;;   5. Regression table (files with largest wall-time increases)
;;   6. Memory trend (when memory data available)

(require racket/cmdline
         racket/list
         racket/string
         racket/path
         racket/port
         racket/file
         json
         "bench-lib.rkt")

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

(define default-output
  (path->string (build-path project-root "data" "benchmarks" "report.html")))

(define timings-file (make-timings-path project-root))

;; ============================================================
;; Data loading and processing
;; ============================================================

(define (load-runs last-n)
  (define all-runs (read-all-runs timings-file))
  (define n (min last-n (length all-runs)))
  (take-right all-runs n))

;; Extract per-file wall_ms from a run, as a list of (file . wall_ms)
(define (run->file-times run)
  (define results (hash-ref run 'results '()))
  (for/list ([r (in-list results)])
    (cons (hash-ref r 'file "") (hash-ref r 'wall_ms 0))))

;; Get all unique file names across runs
(define (all-files runs)
  (define seen (make-hash))
  (for* ([run (in-list runs)]
         [r (in-list (hash-ref run 'results '()))])
    (hash-set! seen (hash-ref r 'file "") #t))
  (sort (hash-keys seen) string<?))

;; Find the N slowest files (by max wall_ms across all runs)
(define (slowest-files runs n)
  (define file-maxes (make-hash))
  (for* ([run (in-list runs)]
         [r (in-list (hash-ref run 'results '()))])
    (define f (hash-ref r 'file ""))
    (define ms (hash-ref r 'wall_ms 0))
    (hash-update! file-maxes f (λ (old) (max old ms)) 0))
  (define sorted (sort (hash->list file-maxes) > #:key cdr))
  (map car (take sorted (min n (length sorted)))))

;; Check if any run has phase data
(define (has-phase-data? runs)
  (for/or ([run (in-list runs)])
    (for/or ([r (in-list (hash-ref run 'results '()))])
      (hash-has-key? r 'phases))))

;; Check if any run has heartbeat data
(define (has-heartbeat-data? runs)
  (for/or ([run (in-list runs)])
    (for/or ([r (in-list (hash-ref run 'results '()))])
      (hash-has-key? r 'heartbeats))))

;; Check if any run has memory data
(define (has-memory-data? runs)
  (for/or ([run (in-list runs)])
    (for/or ([r (in-list (hash-ref run 'results '()))])
      (hash-has-key? r 'memory))))

;; ============================================================
;; Vega-Lite spec builders (produce JSON-serializable hasheqs)
;; ============================================================

;; 1. Suite wall-time trend: total_wall_ms per run
(define (vl-suite-trend runs compare-commit)
  (define data
    (for/list ([run (in-list runs)]
               [i (in-naturals)])
      (define commit (hash-ref run 'commit "?"))
      (define ts (hash-ref run 'timestamp ""))
      (hasheq 'run i
              'commit commit
              'timestamp ts
              'total_wall_s (/ (hash-ref run 'total_wall_ms 0) 1000.0)
              'total_tests (hash-ref run 'total_tests 0)
              'highlight (if (and compare-commit (string=? commit compare-commit))
                             "compare" "normal"))))
  (hasheq '$schema "https://vega.github.io/schema/vega-lite/v5.json"
          'title "Suite Wall Time Trend"
          'width 600
          'height 250
          'data (hasheq 'values data)
          'mark (hasheq 'type "line" 'point #t)
          'encoding (hasheq
                     'x (hasheq 'field "run" 'type "ordinal"
                                'axis (hasheq 'title "Run #"))
                     'y (hasheq 'field "total_wall_s" 'type "quantitative"
                                'axis (hasheq 'title "Wall Time (s)"))
                     'tooltip (list (hasheq 'field "commit" 'type "nominal")
                                    (hasheq 'field "timestamp" 'type "nominal")
                                    (hasheq 'field "total_wall_s" 'type "quantitative")
                                    (hasheq 'field "total_tests" 'type "quantitative"))
                     'color (hasheq 'field "highlight" 'type "nominal"
                                    'scale (hasheq 'domain (list "normal" "compare")
                                                   'range (list "#4c78a8" "#e45756"))
                                    'legend 'null))))

;; 2. Per-file heatmap: wall_ms for top N slowest files
(define (vl-file-heatmap runs top-n)
  (define top-files (slowest-files runs top-n))
  (define indexed-runs (for/list ([run (in-list runs)] [i (in-naturals)]) (cons i run)))
  (define data
    (for*/list ([ir (in-list indexed-runs)]
                [r (in-list (hash-ref (cdr ir) 'results '()))]
                #:when (member (hash-ref r 'file "") top-files))
      (hasheq 'run (car ir)
              'commit (hash-ref (cdr ir) 'commit "?")
              'file (hash-ref r 'file "")
              'wall_s (/ (hash-ref r 'wall_ms 0) 1000.0))))
  (hasheq '$schema "https://vega.github.io/schema/vega-lite/v5.json"
          'title (format "Top ~a Slowest Files Across Runs" top-n)
          'width 600
          'height (* 20 (length top-files))
          'data (hasheq 'values data)
          'mark "rect"
          'encoding (hasheq
                     'x (hasheq 'field "run" 'type "ordinal"
                                'axis (hasheq 'title "Run #"))
                     'y (hasheq 'field "file" 'type "nominal"
                                'sort top-files
                                'axis (hasheq 'title #f))
                     'color (hasheq 'field "wall_s" 'type "quantitative"
                                    'scale (hasheq 'scheme "orangered")
                                    'legend (hasheq 'title "Wall (s)"))
                     'tooltip (list (hasheq 'field "file" 'type "nominal")
                                    (hasheq 'field "commit" 'type "nominal")
                                    (hasheq 'field "wall_s" 'type "quantitative"
                                            'format ".1f")))))

;; 3. Phase breakdown: stacked bar chart per run
(define (vl-phase-breakdown runs)
  (define phase-keys '(parse_ms elaborate_ms type_check_ms trait_resolve_ms
                                qtt_ms zonk_ms reduce_ms))
  (define indexed-runs (for/list ([run (in-list runs)] [i (in-naturals)]) (cons i run)))
  (define data
    (for*/list ([ir (in-list indexed-runs)]
                [pk (in-list phase-keys)])
      (define run (cdr ir))
      (define total-phase-ms
        (for/sum ([r (in-list (hash-ref run 'results '()))]
                  #:when (hash-has-key? r 'phases))
          (define phases (hash-ref r 'phases))
          (if (hash? phases) (hash-ref phases pk 0) 0)))
      (hasheq 'run (car ir)
              'commit (hash-ref run 'commit "?")
              'phase (symbol->string pk)
              'ms total-phase-ms)))
  (hasheq '$schema "https://vega.github.io/schema/vega-lite/v5.json"
          'title "Phase Breakdown Across Runs"
          'width 600
          'height 300
          'data (hasheq 'values data)
          'mark "bar"
          'encoding (hasheq
                     'x (hasheq 'field "run" 'type "ordinal"
                                'axis (hasheq 'title "Run #"))
                     'y (hasheq 'field "ms" 'type "quantitative"
                                'axis (hasheq 'title "Cumulative Phase Time (ms)"))
                     'color (hasheq 'field "phase" 'type "nominal"
                                    'scale (hasheq 'scheme "tableau10")
                                    'legend (hasheq 'title "Phase"))
                     'tooltip (list (hasheq 'field "phase" 'type "nominal")
                                    (hasheq 'field "ms" 'type "quantitative")
                                    (hasheq 'field "commit" 'type "nominal")))))

;; 4. Heartbeat trends: total heartbeats per run
(define (vl-heartbeat-trend runs)
  (define hb-keys '(unify_steps reduce_steps elaborate_steps infer_steps
                                meta_created meta_solved zonk_steps))
  (define indexed-runs (for/list ([run (in-list runs)] [i (in-naturals)]) (cons i run)))
  (define data
    (for*/list ([ir (in-list indexed-runs)]
                [hk (in-list hb-keys)])
      (define run (cdr ir))
      (define total-hb
        (for/sum ([r (in-list (hash-ref run 'results '()))]
                  #:when (hash-has-key? r 'heartbeats))
          (define hb (hash-ref r 'heartbeats))
          (if (hash? hb) (hash-ref hb hk 0) 0)))
      (hasheq 'run (car ir)
              'commit (hash-ref run 'commit "?")
              'counter (symbol->string hk)
              'count total-hb)))
  (hasheq '$schema "https://vega.github.io/schema/vega-lite/v5.json"
          'title "Heartbeat Counter Trends"
          'width 600
          'height 300
          'data (hasheq 'values data)
          'mark (hasheq 'type "line" 'point #t)
          'encoding (hasheq
                     'x (hasheq 'field "run" 'type "ordinal"
                                'axis (hasheq 'title "Run #"))
                     'y (hasheq 'field "count" 'type "quantitative"
                                'axis (hasheq 'title "Total Count"))
                     'color (hasheq 'field "counter" 'type "nominal"
                                    'legend (hasheq 'title "Counter"))
                     'tooltip (list (hasheq 'field "counter" 'type "nominal")
                                    (hasheq 'field "count" 'type "quantitative")
                                    (hasheq 'field "commit" 'type "nominal")))))

;; 5. Regression table data: compare last two runs
(define (compute-regressions runs)
  (cond
    [(< (length runs) 2) '()]
    [else
     (define prev (list-ref runs (- (length runs) 2)))
     (define curr (last runs))
     (define prev-map (make-hash))
     (for ([r (in-list (hash-ref prev 'results '()))])
       (hash-set! prev-map (hash-ref r 'file "") (hash-ref r 'wall_ms 0)))
     (define diffs
       (for/list ([r (in-list (hash-ref curr 'results '()))]
                  #:when (hash-has-key? prev-map (hash-ref r 'file "")))
         (define f (hash-ref r 'file ""))
         (define curr-ms (hash-ref r 'wall_ms 0))
         (define prev-ms (hash-ref prev-map f 0))
         (define delta (- curr-ms prev-ms))
         (define pct (if (zero? prev-ms) 0 (* 100.0 (/ delta prev-ms))))
         (list f prev-ms curr-ms delta pct)))
     ;; Sort by absolute delta descending
     (sort diffs > #:key (λ (d) (abs (list-ref d 3))))]))

;; 6. Memory trend: retained bytes per run
(define (vl-memory-trend runs)
  (define data
    (for/list ([run (in-list runs)]
               [i (in-naturals)])
      (define total-retained
        (for/sum ([r (in-list (hash-ref run 'results '()))]
                  #:when (hash-has-key? r 'memory))
          (define mem (hash-ref r 'memory))
          (if (hash? mem) (hash-ref mem 'mem_retained_bytes 0) 0)))
      (define total-gc
        (for/sum ([r (in-list (hash-ref run 'results '()))]
                  #:when (hash-has-key? r 'memory))
          (define mem (hash-ref r 'memory))
          (if (hash? mem) (hash-ref mem 'gc_ms 0) 0)))
      (hasheq 'run i
              'commit (hash-ref run 'commit "?")
              'retained_mb (/ total-retained 1048576.0)
              'gc_s (/ total-gc 1000.0))))
  (hasheq '$schema "https://vega.github.io/schema/vega-lite/v5.json"
          'title "Memory Trends"
          'width 600
          'height 250
          'data (hasheq 'values data)
          'layer (list
                  (hasheq 'mark (hasheq 'type "line" 'point #t 'color "#4c78a8")
                          'encoding (hasheq
                                     'x (hasheq 'field "run" 'type "ordinal"
                                                'axis (hasheq 'title "Run #"))
                                     'y (hasheq 'field "retained_mb" 'type "quantitative"
                                                'axis (hasheq 'title "Retained Memory (MB)"))
                                     'tooltip (list (hasheq 'field "commit" 'type "nominal")
                                                    (hasheq 'field "retained_mb"
                                                            'type "quantitative"
                                                            'format ".1f")))))))

;; ============================================================
;; HTML generation
;; ============================================================

(define (json->string v)
  (with-output-to-string (λ () (write-json v))))

(define (generate-html runs compare-commit output-path)
  (define latest (if (null? runs) #f (last runs)))
  (define commit (if latest (hash-ref latest 'commit "?") "?"))
  (define timestamp (if latest (hash-ref latest 'timestamp "") ""))
  (define total-tests (if latest (hash-ref latest 'total_tests 0) 0))
  (define file-count (if latest (hash-ref latest 'file_count 0) 0))
  (define total-wall-s (if latest (/ (hash-ref latest 'total_wall_ms 0) 1000.0) 0))

  ;; Build specs
  (define suite-spec (vl-suite-trend runs compare-commit))
  (define heatmap-spec (vl-file-heatmap runs 15))
  (define regressions (compute-regressions runs))

  ;; Optional specs
  (define phase-spec (and (has-phase-data? runs) (vl-phase-breakdown runs)))
  (define hb-spec (and (has-heartbeat-data? runs) (vl-heartbeat-trend runs)))
  (define mem-spec (and (has-memory-data? runs) (vl-memory-trend runs)))

  ;; Regression HTML table
  (define reg-html
    (string-append
     "<table class='reg-table'>"
     "<tr><th>File</th><th>Prev (ms)</th><th>Curr (ms)</th><th>Δ (ms)</th><th>Δ%</th></tr>"
     (apply string-append
            (for/list ([r (in-list (take regressions (min 20 (length regressions))))])
              (define f (list-ref r 0))
              (define prev-ms (list-ref r 1))
              (define curr-ms (list-ref r 2))
              (define delta (list-ref r 3))
              (define pct (list-ref r 4))
              (define cls (cond [(> pct 10) "regression"]
                                [(< pct -10) "improvement"]
                                [else "stable"]))
              (format "<tr class='~a'><td>~a</td><td>~a</td><td>~a</td><td>~a</td><td>~a%</td></tr>"
                      cls f prev-ms curr-ms
                      (if (>= delta 0) (format "+~a" delta) delta)
                      (let ([s (format "~a" (exact->inexact (round (* pct 10))))])
                        ;; manual 1-decimal formatting
                        (format "~a" (/ (round (* pct 10)) 10.0))))))
     "</table>"))

  ;; Assemble HTML
  (define html
    (string-append
     "<!DOCTYPE html>\n<html lang='en'>\n<head>\n"
     "<meta charset='UTF-8'>\n"
     "<title>Prologos Benchmark Report — " commit "</title>\n"
     "<script src='https://cdn.jsdelivr.net/npm/vega@5'></script>\n"
     "<script src='https://cdn.jsdelivr.net/npm/vega-lite@5'></script>\n"
     "<script src='https://cdn.jsdelivr.net/npm/vega-embed@6'></script>\n"
     "<style>\n"
     "body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;\n"
     "  max-width: 900px; margin: 0 auto; padding: 20px; background: #fafafa; }\n"
     "h1 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 8px; }\n"
     "h2 { color: #34495e; margin-top: 30px; }\n"
     ".meta { color: #7f8c8d; font-size: 0.9em; margin-bottom: 20px; }\n"
     ".chart { background: white; border-radius: 8px; padding: 16px; margin: 16px 0;\n"
     "  box-shadow: 0 1px 3px rgba(0,0,0,0.12); }\n"
     ".reg-table { width: 100%; border-collapse: collapse; font-size: 0.85em; }\n"
     ".reg-table th { background: #34495e; color: white; padding: 8px; text-align: left; }\n"
     ".reg-table td { padding: 6px 8px; border-bottom: 1px solid #ecf0f1; }\n"
     ".reg-table .regression td { background: #fde8e8; }\n"
     ".reg-table .improvement td { background: #e8fde8; }\n"
     ".reg-table .stable td { background: white; }\n"
     ".summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));\n"
     "  gap: 12px; margin: 16px 0; }\n"
     ".stat-card { background: white; border-radius: 8px; padding: 16px; text-align: center;\n"
     "  box-shadow: 0 1px 3px rgba(0,0,0,0.12); }\n"
     ".stat-card .value { font-size: 1.8em; font-weight: bold; color: #2c3e50; }\n"
     ".stat-card .label { font-size: 0.8em; color: #7f8c8d; margin-top: 4px; }\n"
     "</style>\n</head>\n<body>\n"

     ;; Header
     "<h1>Prologos Benchmark Report</h1>\n"
     "<div class='meta'>Commit: <strong>" commit "</strong>"
     " &middot; " timestamp
     " &middot; " (format "~a runs analyzed" (length runs))
     "</div>\n"

     ;; Summary cards
     "<div class='summary'>\n"
     "<div class='stat-card'><div class='value'>" (format "~a" total-tests) "</div>"
     "<div class='label'>Tests</div></div>\n"
     "<div class='stat-card'><div class='value'>" (format "~a" file-count) "</div>"
     "<div class='label'>Files</div></div>\n"
     "<div class='stat-card'><div class='value'>"
     (format "~as" (/ (round (* total-wall-s 10)) 10.0))
     "</div><div class='label'>Wall Time</div></div>\n"
     "<div class='stat-card'><div class='value'>" (format "~a" (length runs)) "</div>"
     "<div class='label'>Runs</div></div>\n"
     "</div>\n"

     ;; Charts
     "<h2>Suite Wall Time</h2>\n"
     "<div class='chart' id='suite-trend'></div>\n"

     "<h2>Slowest Files Heatmap</h2>\n"
     "<div class='chart' id='file-heatmap'></div>\n"

     ;; Conditional phase section
     (if phase-spec
         (string-append
          "<h2>Phase Breakdown</h2>\n"
          "<div class='chart' id='phase-breakdown'></div>\n")
         "")

     ;; Conditional heartbeat section
     (if hb-spec
         (string-append
          "<h2>Heartbeat Counter Trends</h2>\n"
          "<div class='chart' id='heartbeat-trend'></div>\n")
         "")

     ;; Conditional memory section
     (if mem-spec
         (string-append
          "<h2>Memory Trends</h2>\n"
          "<div class='chart' id='memory-trend'></div>\n")
         "")

     ;; Regression table
     "<h2>Timing Changes (Last vs Previous Run)</h2>\n"
     (if (null? regressions)
         "<p>Insufficient data for regression comparison.</p>\n"
         reg-html)

     ;; Vega-Lite embed scripts
     "\n<script>\n"
     "vegaEmbed('#suite-trend', " (json->string suite-spec) ");\n"
     "vegaEmbed('#file-heatmap', " (json->string heatmap-spec) ");\n"
     (if phase-spec
         (format "vegaEmbed('#phase-breakdown', ~a);\n" (json->string phase-spec))
         "")
     (if hb-spec
         (format "vegaEmbed('#heartbeat-trend', ~a);\n" (json->string hb-spec))
         "")
     (if mem-spec
         (format "vegaEmbed('#memory-trend', ~a);\n" (json->string mem-spec))
         "")
     "</script>\n"

     ;; Footer
     "<div class='meta' style='margin-top: 30px; text-align: center;'>"
     "Generated by Prologos benchmark-report.rkt</div>\n"
     "</body>\n</html>\n"))

  ;; Ensure output directory exists
  (define out-dir (path-only (string->path output-path)))
  (when (and out-dir (not (directory-exists? out-dir)))
    (make-directory* out-dir))

  ;; Write file
  (call-with-output-file output-path #:exists 'replace
    (λ (out) (display html out)))

  (printf "Report written to ~a (~a runs, ~a files)\n"
          output-path (length runs) file-count))

;; ============================================================
;; CLI
;; ============================================================

(define last-n (make-parameter 10))
(define output-path (make-parameter default-output))
(define compare-commit (make-parameter #f))

(command-line
 #:program "benchmark-report"
 #:once-each
 ["--last" n "Number of runs to include" (last-n (string->number n))]
 ["--output" path "Output HTML file path" (output-path path)]
 ["--compare" ref "Highlight a specific commit" (compare-commit ref)]
 #:args ()
 (define runs (load-runs (last-n)))
 (cond
   [(null? runs)
    (printf "No benchmark data found at ~a\n" timings-file)]
   [else
    (generate-html runs (compare-commit) (output-path))]))
