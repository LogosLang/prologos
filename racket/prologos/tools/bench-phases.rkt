#lang racket/base

;;; tools/bench-phases.rkt --- aggregate PHASE-TIMINGS across N runs
;;;
;;; For each given .prologos file, run `racket driver.rkt FILE` N times,
;;; extract the PHASE-TIMINGS line from stderr, and report the median
;;; per phase plus the leftover "prelude + overhead" (wall - sum-of-phases).
;;;
;;; Usage:
;;;   racket tools/bench-phases.rkt [--runs N] FILE.prologos [FILE.prologos ...]
;;;
;;; Example:
;;;   racket tools/bench-phases.rkt --runs 3 \
;;;     benchmarks/comparative/eigentrust-list-rat.prologos \
;;;     benchmarks/comparative/eigentrust-pvec-posit.prologos

(require racket/cmdline
         racket/list
         racket/port
         racket/path
         racket/system
         json)

;; ============================================================
;; Path anchoring (mirrors bench-ab.rkt)
;; ============================================================

(define tools-dir
  (let ([src (resolved-module-path-name
              (variable-reference->resolved-module-path
               (#%variable-reference)))])
    (simplify-path (path-only src))))

(define project-root
  (path->string (simplify-path (build-path tools-dir ".."))))

(define driver-path
  (path->string (build-path project-root "driver.rkt")))

(define racket-path
  (or (find-executable-path "racket") "racket"))

;; ============================================================
;; One-shot run
;; ============================================================

;; Run driver.rkt PATH once. Capture stderr. Parse PHASE-TIMINGS.
;; Return (values wall-ms phases-hash), where phases-hash has keys:
;;   'parse_ms 'elaborate_ms 'type_check_ms 'trait_resolve_ms
;;   'qtt_ms 'zonk_ms 'reduce_ms
(define (run-once program-path)
  (define t0 (current-inexact-monotonic-milliseconds))
  (define-values (proc stdout-port stdin-port stderr-port)
    (subprocess #f #f #f racket-path driver-path program-path))
  (close-output-port stdin-port)
  (subprocess-wait proc)
  (define t1 (current-inexact-monotonic-milliseconds))
  (define wall-ms (- t1 t0))
  (define err-text (port->string stderr-port))
  (close-input-port stdout-port)
  (close-input-port stderr-port)
  (values wall-ms (extract-phases err-text)))

(define phase-re
  #rx"PHASE-TIMINGS:(\\{[^}]*\\})")

;; Extract the PHASE-TIMINGS JSON from the stderr text. Because process-file
;; emits one cumulative PHASE-TIMINGS per file, we take the LAST match (the
;; summary) and ignore earlier ones (which are per-preload zeroes).
(define (extract-phases err-text)
  (define matches (regexp-match* phase-re err-text #:match-select cadr))
  (cond
    [(null? matches) (hasheq)]
    [else
     (define last-json (last matches))
     (string->jsexpr last-json)]))

;; ============================================================
;; Median over N runs
;; ============================================================

(define (median xs)
  (define sorted (sort xs <))
  (define n (length sorted))
  (cond
    [(zero? n) 0]
    [(odd? n)  (list-ref sorted (quotient n 2))]
    [else      (/ (+ (list-ref sorted (sub1 (quotient n 2)))
                     (list-ref sorted (quotient n 2)))
                  2)]))

(define (run-n program-path n)
  ;; Warmup (not counted).
  (run-once program-path)
  (for/list ([_ (in-range n)])
    (collect-garbage 'major)
    (define-values (wall phases) (run-once program-path))
    (hasheq 'wall_ms wall 'phases phases)))

;; ============================================================
;; Reporting
;; ============================================================

(define phase-keys
  '(parse_ms elaborate_ms type_check_ms trait_resolve_ms qtt_ms zonk_ms reduce_ms))

(define (report-one program-path runs)
  (define walls (map (λ (r) (hash-ref r 'wall_ms 0)) runs))
  (define walls-median (median walls))
  (define walls-min (apply min walls))
  (define walls-max (apply max walls))
  (printf "\n── ~a ──\n" program-path)
  (printf "  wall_ms      : median ~a (min ~a, max ~a, n=~a)\n"
          (exact-round walls-median)
          (exact-round walls-min)
          (exact-round walls-max)
          (length runs))
  ;; Per-phase medians.
  (define phase-samples
    (for/hasheq ([k (in-list phase-keys)])
      (values k
              (for/list ([r (in-list runs)])
                (hash-ref (hash-ref r 'phases (hasheq)) k 0)))))
  (define phase-medians
    (for/hasheq ([k (in-list phase-keys)])
      (values k (median (hash-ref phase-samples k)))))
  (define phase-sum
    (for/sum ([k (in-list phase-keys)])
      (hash-ref phase-medians k 0)))
  (printf "  Phase totals (median ms of ~a runs):\n" (length runs))
  (for ([k (in-list phase-keys)])
    (define v (hash-ref phase-medians k 0))
    (define pct (if (zero? walls-median) 0 (* 100.0 (/ v walls-median))))
    (printf "    ~a : ~a ms  (~a%% of wall)\n"
            (~a k #:width 18)
            (~a (exact-round v) #:width 6 #:align 'right)
            (real->decimal-string pct 1)))
  (printf "    ~a : ~a ms  (~a%% of wall)  -- sum of phases above\n"
          (~a "[all user phases]" #:width 18)
          (~a (exact-round phase-sum) #:width 6 #:align 'right)
          (real->decimal-string
           (if (zero? walls-median) 0 (* 100.0 (/ phase-sum walls-median))) 1))
  (define overhead (max 0 (- walls-median phase-sum)))
  (printf "    ~a : ~a ms  (~a%% of wall)  -- prelude load + Racket startup + I/O\n"
          (~a "[outside phases]" #:width 18)
          (~a (exact-round overhead) #:width 6 #:align 'right)
          (real->decimal-string
           (if (zero? walls-median) 0 (* 100.0 (/ overhead walls-median))) 1)))

(define (~a v #:width [w 0] #:align [align 'left])
  (define s (format "~a" v))
  (define pad (max 0 (- w (string-length s))))
  (case align
    [(right) (string-append (make-string pad #\space) s)]
    [else    (string-append s (make-string pad #\space))]))

(define (exact-round v)
  (inexact->exact (round v)))

;; ============================================================
;; CLI
;; ============================================================

(define num-runs (make-parameter 3))

(define files
  (command-line
   #:program "bench-phases"
   #:once-each
   [("--runs") N "Measured runs per program (default: 3, plus 1 warmup)"
    (num-runs (string->number N))]
   #:args program-paths
   program-paths))

(when (null? files)
  (eprintf "usage: racket tools/bench-phases.rkt [--runs N] FILE.prologos ...\n")
  (exit 1))

(printf "═══ Phase-timing benchmark (runs=~a per file) ═══\n" (num-runs))
(for ([f (in-list files)])
  (define runs (run-n f (num-runs)))
  (report-one f runs))
(newline)
