#lang racket/base

;;;
;;; measure-production-n.rkt
;;; PPN 4C Tropical Quantale Addendum D.4 — Phase 1C-vi auxiliary measurement
;;;
;;; PURPOSE: capture the distribution of "fires per BSP round" during a
;;; representative production elaboration workload (e.g., the S4 probe file).
;;; This produces a "production-realistic N" value that the A/B/C report
;;; (1C-vi Commit 2) uses to compute the Option 13 amortized cost AT
;;; PRODUCTION-REALISTIC N, rather than synthetic N=100/1000.
;;;
;;; ORIGIN: user question at 1C-vi Commit 1 checkpoint surfaced the gap —
;;; bench-tropical-fuel.rkt's Section 4.5 measures amortization at synthetic
;;; N=100/1000, but production workloads have a different N distribution.
;;; The bench numbers (6.82 ns/cycle at N=100; 1.72 at N=1000) are anchored;
;;; the actual production cost depends on the actual N distribution.
;;;
;;; SCOPE: Variant A (parallel BSP main loop) — current-bsp-observer fires only
;;; for run-to-quiescence-bsp. Variant B (sequential schedulers
;;; #1/#2/#4/#5) does NOT go through this observer; per-phase N for Variant B
;;; would require separate instrumentation (out of scope for 1C-vi; deferred
;;; to Phase 1V or future measurement work if needed).
;;;
;;; Usage:
;;;   "/Applications/Racket v9.0/bin/racket" \
;;;     racket/prologos/tools/measure-production-n.rkt \
;;;     racket/prologos/examples/2026-04-22-1A-iii-probe.prologos
;;;

(require racket/cmdline
         racket/list
         racket/format
         (only-in "../driver.rkt"
                  process-file)
         (only-in "../propagator.rkt"
                  current-bsp-observer
                  bsp-round-propagators-fired))

;; Accumulate fires-per-round counts
(define rounds-fires (box '()))

(define (observer round)
  ;; round is a bsp-round struct; propagators-fired is the list of fired prop-ids
  (set-box! rounds-fires
            (cons (length (bsp-round-propagators-fired round))
                  (unbox rounds-fires))))

(define probe-file
  (command-line
    #:program "measure-production-n.rkt"
    #:args (file)
    file))

(displayln (format "Running probe: ~a" probe-file))
(displayln "Setting current-bsp-observer to accumulate fires per BSP round...")
(displayln "")

(parameterize ([current-bsp-observer observer])
  (process-file probe-file))

(define fires (reverse (unbox rounds-fires)))
(define rounds-count (length fires))
(define total-fires (apply + fires))
(define mean-N (if (zero? rounds-count) 0.0
                   (exact->inexact (/ total-fires rounds-count))))
(define sorted-fires (sort fires <))
(define (percentile p)
  (cond
    [(null? sorted-fires) 0]
    [else
     (define idx (max 0 (min (- (length sorted-fires) 1)
                             (inexact->exact (floor (* p (length sorted-fires)))))))
     (list-ref sorted-fires idx)]))

;; Histogram bucketing (powers-of-2)
(define (bucket-of n)
  (cond
    [(= n 0) "0"]
    [(= n 1) "1"]
    [(<= n 5) "2-5"]
    [(<= n 10) "6-10"]
    [(<= n 25) "11-25"]
    [(<= n 50) "26-50"]
    [(<= n 100) "51-100"]
    [(<= n 250) "101-250"]
    [(<= n 500) "251-500"]
    [(<= n 1000) "501-1000"]
    [else ">1000"]))

(define bucket-counts (make-hasheq))
(for ([n (in-list fires)])
  (define b (bucket-of n))
  (hash-update! bucket-counts b add1 (lambda () 0)))

(displayln "")
(displayln "============================================================")
(displayln "BSP-ROUND FIRES DISTRIBUTION (Variant A; parallel BSP main loop)")
(displayln "============================================================")
(displayln (format "BSP rounds executed:    ~a" rounds-count))
(displayln (format "Total propagator fires: ~a" total-fires))
(displayln "")
(displayln "Fires per round summary:")
(displayln (format "  Mean:  ~a" (~r mean-N #:precision '(= 2))))
(displayln (format "  Min:   ~a" (percentile 0)))
(displayln (format "  P25:   ~a" (percentile 0.25)))
(displayln (format "  P50:   ~a" (percentile 0.50)))
(displayln (format "  P75:   ~a" (percentile 0.75)))
(displayln (format "  P95:   ~a" (percentile 0.95)))
(displayln (format "  Max:   ~a" (percentile 1.0)))
(displayln "")
(displayln "Distribution histogram (fires-per-round bucket → round count):")
(define ordered-buckets
  '("0" "1" "2-5" "6-10" "11-25" "26-50" "51-100" "101-250" "251-500" "501-1000" ">1000"))
(for ([b (in-list ordered-buckets)])
  (define count (hash-ref bucket-counts b 0))
  (when (> count 0)
    (define bar (make-string (min count 60) #\█))
    (displayln (format "  ~a~a: ~a  ~a"
                       b
                       (make-string (max 0 (- 9 (string-length b))) #\space)
                       (~r count #:precision 0 #:min-width 5)
                       bar))))
(displayln "")
(displayln "Cross-reference:")
(displayln "  - bench-tropical-fuel.rkt Section 4.5: amortized cost at synthetic N")
(displayln "  - A/B/C report (1C-vi Commit 2): use these N values to compute")
(displayln "    production-realistic amortized cost")
(displayln "============================================================")
