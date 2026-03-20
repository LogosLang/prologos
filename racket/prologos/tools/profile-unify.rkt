#lang racket/base

;;; profile-unify.rkt — Profile type-level unification for PUnify design
;;;
;;; Runs .prologos files with unify-profile enabled and prints a breakdown
;;; of classification distribution, timing, and depth statistics.
;;;
;;; Usage:
;;;   racket tools/profile-unify.rkt FILE.prologos [FILE2.prologos ...]
;;;   racket tools/profile-unify.rkt --all-comparative
;;;   racket tools/profile-unify.rkt --acceptance

(require racket/cmdline
         racket/format
         racket/list
         racket/string
         (only-in "../driver.rkt" process-file)
         (only-in "../errors.rkt" prologos-error? prologos-error-message)
         (only-in "../performance-counters.rkt"
                  make-unify-profile
                  current-unify-profile
                  unify-profile->hasheq
                  unify-profile-total-classifications
                  print-unify-profile-report!
                  ;; Phase timing
                  phase-timings
                  current-phase-timings
                  phase-timings->hasheq
                  ;; Perf counters (for total unify-steps)
                  perf-counters
                  current-perf-counters
                  perf-counters->hasheq))

;; ============================================================
;; Pretty-print a unify profile
;; ============================================================

(define (print-profile-summary label up-hash total-classifications pt-hash pc-hash wall-ms)
  (printf "\n~a\n~a\n" label (make-string (string-length label) #\=))

  ;; Wall time breakdown
  (define elab-ms (hash-ref pt-hash 'elaborate_ms 0))
  (define tc-ms (hash-ref pt-hash 'type_check_ms 0))
  (define trait-ms (hash-ref pt-hash 'trait_resolve_ms 0))
  (define zonk-ms (hash-ref pt-hash 'zonk_ms 0))
  (define reduce-ms (hash-ref pt-hash 'reduce_ms 0))
  (define parse-ms (hash-ref pt-hash 'parse_ms 0))
  (define qtt-ms (hash-ref pt-hash 'qtt_ms 0))
  (define unify-us (hash-ref up-hash 'unify_wall_us 0))
  (define unify-ms (/ unify-us 1000.0))

  (printf "\n--- Phase Timing (wall-clock ms) ---\n")
  (printf "  Total wall:        ~a ms\n" (inexact->exact (round wall-ms)))
  (printf "  Parse:             ~a ms\n" parse-ms)
  (printf "  Elaborate:         ~a ms\n" elab-ms)
  (printf "  Type-check:        ~a ms\n" tc-ms)
  (printf "  Trait resolve:     ~a ms\n" trait-ms)
  (printf "  QTT:               ~a ms\n" qtt-ms)
  (printf "  Zonk:              ~a ms\n" zonk-ms)
  (printf "  Reduce:            ~a ms\n" reduce-ms)
  (printf "  Unify (measured):  ~a ms (~a% of wall)\n"
          (~r unify-ms #:precision '(= 1))
          (~r (* 100.0 (if (> wall-ms 0) (/ unify-ms wall-ms) 0)) #:precision '(= 1)))

  ;; Classification distribution
  (printf "\n--- Unify Classification Distribution (n=~a) ---\n" total-classifications)
  (define classifications
    '((ok          "ok (equal/wildcard/same-meta)")
      (conv        "conv (structural mismatch)")
      (flex_rigid  "flex-rigid (meta vs concrete)")
      (flex_app    "flex-app (applied meta)")
      (sub         "sub (structural decomposition)")
      (pi          "pi (Pi binder)")
      (binder      "binder (Sigma/lam)")
      (level       "level (universe)")
      (union       "union")
      (retry       "retry (HKT/ann)")))
  (for ([c (in-list classifications)])
    (define key (car c))
    (define label (cadr c))
    (define count (hash-ref up-hash key 0))
    (define pct (if (> total-classifications 0) (* 100.0 (/ count total-classifications)) 0))
    (when (> count 0)
      (printf "  ~a~a  ~a (~a%)\n"
              (~a label #:min-width 40)
              ""
              count
              (~r pct #:precision '(= 1)))))

  ;; Sub-classification breakdown
  (printf "\n--- Structural Decomposition Sub-counts ---\n")
  (define sub-keys
    '((sub_app  "app (rigid-rigid)")
      (sub_suc  "suc")
      (sub_nat  "nat cross-repr")
      (sub_eq   "Eq")
      (sub_vec  "Vec")
      (sub_fin  "Fin")
      (sub_pair "pair")))
  (for ([s (in-list sub-keys)])
    (define count (hash-ref up-hash (car s) 0))
    (when (> count 0)
      (printf "  ~a  ~a\n" (~a (cadr s) #:min-width 30) count)))

  ;; Depth and postponement
  (printf "\n--- Depth & Postponement ---\n")
  (printf "  Max recursive depth:  ~a\n" (hash-ref up-hash 'max_depth 0))
  (printf "  Postponements:        ~a\n" (hash-ref up-hash 'postpone 0))
  (printf "  Total unify calls:    ~a\n" (hash-ref pc-hash 'unify_steps 0))
  (printf "  Metas created:        ~a\n" (hash-ref pc-hash 'meta_created 0))
  (printf "  Metas solved:         ~a\n" (hash-ref pc-hash 'meta_solved 0))
  (printf "  Constraints:          ~a\n" (hash-ref pc-hash 'constraint_count 0))
  (printf "  Prop firings:         ~a\n" (hash-ref pc-hash 'prop_firings 0)))

;; ============================================================
;; Run a single file with profiling
;; ============================================================

(define (profile-file path)
  (define up (make-unify-profile))
  (define pt (phase-timings 0 0 0 0 0 0 0))
  (define pc (perf-counters 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0))
  (define t0 (current-inexact-monotonic-milliseconds))
  (define results
    (parameterize ([current-unify-profile up]
                   [current-phase-timings pt]
                   [current-perf-counters pc])
      (process-file path)))
  (define wall-ms (- (current-inexact-monotonic-milliseconds) t0))

  ;; Count errors
  (define error-count
    (for/sum ([r (in-list results)])
      (if (prologos-error? r) 1 0)))

  (define up-hash (unify-profile->hasheq up))
  (define total (unify-profile-total-classifications up))
  (define pt-hash (phase-timings->hasheq pt))
  (define pc-hash (perf-counters->hasheq pc))

  (print-profile-summary
   (format "~a (~a commands, ~a errors)" path (length results) error-count)
   up-hash total pt-hash pc-hash wall-ms)

  ;; Return raw data for aggregation
  (hasheq 'path path
          'commands (length results)
          'errors error-count
          'wall_ms wall-ms
          'unify_profile up-hash
          'phase_timings pt-hash
          'perf_counters pc-hash
          'total_classifications total))

;; ============================================================
;; Aggregate multiple profiles
;; ============================================================

(define (print-aggregate profiles)
  (printf "\n\n")
  (printf "AGGREGATE SUMMARY\n")
  (printf "=================\n")
  (define total-wall (for/sum ([p (in-list profiles)]) (hash-ref p 'wall_ms)))
  (define total-commands (for/sum ([p (in-list profiles)]) (hash-ref p 'commands)))
  (define total-errors (for/sum ([p (in-list profiles)]) (hash-ref p 'errors)))
  (define total-classif (for/sum ([p (in-list profiles)]) (hash-ref p 'total_classifications)))

  ;; Sum unify profile fields
  (define agg-up (make-hash))
  (for ([p (in-list profiles)])
    (for ([(k v) (in-hash (hash-ref p 'unify_profile))])
      (hash-update! agg-up k (λ (old) (+ old v)) 0)))

  ;; Sum phase timings
  (define agg-pt (make-hash))
  (for ([p (in-list profiles)])
    (for ([(k v) (in-hash (hash-ref p 'phase_timings))])
      (hash-update! agg-pt k (λ (old) (+ old v)) 0)))

  ;; Sum perf counters
  (define agg-pc (make-hash))
  (for ([p (in-list profiles)])
    (for ([(k v) (in-hash (hash-ref p 'perf_counters))])
      (hash-update! agg-pc k (λ (old) (+ old v)) 0)))

  (printf "\n~a files, ~a commands, ~a errors, ~a ms total wall\n"
          (length profiles) total-commands total-errors (inexact->exact (round total-wall)))

  (print-profile-summary
   "Aggregate"
   (for/hasheq ([(k v) (in-hash agg-up)]) (values k v))
   total-classif
   (for/hasheq ([(k v) (in-hash agg-pt)]) (values k v))
   (for/hasheq ([(k v) (in-hash agg-pc)]) (values k v))
   total-wall))

;; ============================================================
;; Main
;; ============================================================

(define all-comparative? (make-parameter #f))
(define acceptance? (make-parameter #f))

(define files
  (command-line
   #:program "profile-unify"
   #:once-each
   ["--all-comparative" "Profile all comparative benchmarks"
    (all-comparative? #t)]
   ["--acceptance" "Profile the PUnify acceptance file"
    (acceptance? #t)]
   #:args files files))

;; Build file list
(define all-files
  (append
   files
   (if (acceptance?)
       '("examples/2026-03-19-punify-acceptance.prologos")
       '())
   (if (all-comparative?)
       (let ()
         (define dir "benchmarks/comparative/")
         (for/list ([f (in-list (directory-list dir))]
                    #:when (regexp-match? #rx"\\.prologos$" (path->string f)))
           (build-path dir f)))
       '())))

(when (null? all-files)
  (eprintf "No files specified. Use --acceptance, --all-comparative, or pass file paths.\n")
  (exit 1))

;; Run profiles
(define profiles
  (for/list ([f (in-list all-files)])
    (profile-file (if (path? f) (path->string f) f))))

;; Print aggregate if multiple files
(when (> (length profiles) 1)
  (print-aggregate profiles))

(printf "\n")
