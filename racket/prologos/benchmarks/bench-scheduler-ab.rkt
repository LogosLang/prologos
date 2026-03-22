#lang racket/base

;;;
;;; Track 8 C5a: Gauss-Seidel vs BSP scheduler A/B comparison
;;;
;;; Runs each comparative benchmark file under both schedulers,
;;; collects wall-time and reports comparison.
;;;
;;; Uses current-use-bsp-scheduler? (propagator.rkt level) to override
;;; ALL run-to-quiescence calls globally — not just the stratified loop,
;;; but also unify.rkt, elab-speculation.rkt, bridges, tabling, etc.
;;;

(require racket/list
         racket/string
         racket/format
         racket/path
         "../driver.rkt"
         "../propagator.rkt"
         "../metavar-store.rkt")

(define RUNS 5)

;; Resolve benchmark directory relative to this script's location
(define script-dir (path-only (resolved-module-path-name (variable-reference->resolved-module-path (#%variable-reference)))))
(define BENCHMARK-DIR (build-path script-dir "comparative"))

;; Collect all .prologos files in the benchmark directory
(define benchmark-files
  (sort
   (for/list ([f (in-directory BENCHMARK-DIR)]
              #:when (regexp-match? #rx"\\.prologos$" (path->string f)))
     f)
   string<? #:key path->string))

(define (median lst)
  (define sorted (sort lst <))
  (define n (length sorted))
  (if (odd? n)
      (list-ref sorted (quotient n 2))
      (/ (+ (list-ref sorted (sub1 (quotient n 2)))
            (list-ref sorted (quotient n 2)))
         2.0)))

;; use-bsp?: when #t, overrides ALL run-to-quiescence calls globally (propagator.rkt level)
(define (run-benchmark file use-bsp? scheduler-name)
  (define times
    (for/list ([_ (in-range RUNS)])
      (collect-garbage)
      (collect-garbage)
      (define t0 (current-inexact-milliseconds))
      (parameterize ([current-use-bsp-scheduler? use-bsp?])
        (process-file (path->string file)))
      (- (current-inexact-milliseconds) t0)))
  (define med (median times))
  (values med times))

(printf "Track 8 C5a: Scheduler A/B Comparison\n")
(printf "======================================\n")
(printf "Runs per benchmark: ~a\n\n" RUNS)
(printf "~a  ~a  ~a  ~a\n"
        (~a "Benchmark" #:width 40)
        (~a "GS (ms)" #:width 12)
        (~a "BSP (ms)" #:width 12)
        "Ratio")
(printf "~a\n" (make-string 76 #\-))

(define gs-totals '())
(define bsp-totals '())

(for ([f (in-list benchmark-files)])
  (define name (path->string (file-name-from-path f)))
  (define-values (gs-med gs-times) (run-benchmark f #f "GS"))
  (define-values (bsp-med bsp-times) (run-benchmark f #t "BSP"))
  (define ratio (if (> gs-med 0) (/ bsp-med gs-med) +inf.0))
  (set! gs-totals (cons gs-med gs-totals))
  (set! bsp-totals (cons bsp-med bsp-totals))
  (printf "~a  ~a  ~a  ~a\n"
          (~a name #:width 40)
          (~a (~r gs-med #:precision '(= 1)) #:width 12)
          (~a (~r bsp-med #:precision '(= 1)) #:width 12)
          (~r ratio #:precision '(= 3))))

(printf "~a\n" (make-string 76 #\-))
(define gs-total (apply + gs-totals))
(define bsp-total (apply + bsp-totals))
(printf "~a  ~a  ~a  ~a\n"
        (~a "TOTAL" #:width 40)
        (~a (~r gs-total #:precision '(= 1)) #:width 12)
        (~a (~r bsp-total #:precision '(= 1)) #:width 12)
        (~r (/ bsp-total gs-total) #:precision '(= 3)))
(printf "\nVerdict: ~a\n"
        (cond [(< (/ bsp-total gs-total) 0.95) "BSP faster (>5% improvement)"]
              [(> (/ bsp-total gs-total) 1.05) "Gauss-Seidel faster (>5% improvement)"]
              [else "Within noise (<5% difference)"]))
