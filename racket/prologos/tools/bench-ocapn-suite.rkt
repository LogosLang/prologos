#lang racket/base

;;; bench-ocapn-suite.rkt
;;;
;;; Wall-time comparison: pure Racket reducers (reduction.rkt) vs
;;; the hybrid kernel (preduce-hybrid + Zig BSP scheduler) across
;;; the 12 OCapN example programs. Each program is loaded once via
;;; process-file (the elaborator pipeline), then `main` is reduced
;;; multiple ways, multiple iterations.
;;;
;;; Three reducers compared (each computes a slightly different
;;; output, so per-call times reflect different work):
;;;
;;;   * whnf         — Racket-side weak-head normalization. Stops at
;;;                    the top-level ctor; field sub-terms remain
;;;                    un-reduced. Closest semantic equivalent to
;;;                    preduce-hybrid below.
;;;   * nf           — Racket-side full normalization. Recurses into
;;;                    structure; produces a fully-reduced AST.
;;;   * preduce-hybrid — Zig kernel via the propagator network.
;;;                     Computes WHNF; result is a value carrying
;;;                     CELL-IDs for field sub-terms.
;;;
;;; Usage:
;;;   racket racket/prologos/tools/bench-ocapn-suite.rkt
;;;   racket racket/prologos/tools/bench-ocapn-suite.rkt --runs N
;;;   racket racket/prologos/tools/bench-ocapn-suite.rkt --files glob
;;;
;;; Notes:
;;; - process-file is called ONCE per program (the elaborator
;;;   pipeline is the same on both backends).
;;; - The reducer step is what's compared. Each run includes:
;;;   * nf: full normalization via reduction.rkt's reducer.
;;;   * preduce-hybrid: kernel-reset → install propagators → run
;;;     to quiescence → read result.
;;; - Cell store is reset between hybrid runs via prologos_kernel_reset.
;;; - First run amortizes JIT warm-up; later runs report steady-state.

(require racket/cmdline
         racket/format
         racket/file
         racket/list
         racket/path
         racket/runtime-path
         "../preduce-hybrid.rkt"
         "../runtime-bridge.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         (only-in "../reduction.rkt" nf whnf))

(define runs (make-parameter 5))
(define files-glob (make-parameter "racket/prologos/examples/ocapn/ocapn-hybrid-*.prologos"))

(command-line
 #:program "bench-ocapn-suite"
 #:once-each
 [("--runs") n "iterations per program per backend" (runs (string->number n))]
 [("--files") g "glob for .prologos files" (files-glob g)])

(unless (hybrid-runtime-available?)
  (eprintf "kernel .so not loaded; build via tools/build-hybrid-binary.sh~n")
  (exit 1))

(define (microseconds-since t0)
  (/ (- (current-inexact-monotonic-milliseconds) t0) 1.0))

(define (run-one program-file)
  ;; Load program ONCE (this populates global-env with main).
  (process-file program-file)
  (define main-body (global-env-lookup-value 'main))
  (unless main-body
    (error 'bench-ocapn-suite "no 'main in ~a" program-file))
  (define (time-fn fn iters)
    (define ms-list
      (for/list ([_ (in-range iters)])
        (define t0 (current-inexact-monotonic-milliseconds))
        (fn main-body)
        (- (current-inexact-monotonic-milliseconds) t0)))
    (rest ms-list))                     ; drop warm-up
  (define (avg xs) (if (null? xs) 0.0 (/ (apply + xs) (length xs))))
  (define (med xs)
    (define s (sort xs <))
    (list-ref s (quotient (length s) 2)))
  ;; whnf timing
  (define whnf-warm (time-fn whnf (runs)))
  ;; nf timing
  (define nf-warm (time-fn nf (runs)))
  ;; hybrid timing — reset kernel between runs to start clean
  (define hyb-warm
    (let ()
      (define ms-list
        (for/list ([_ (in-range (runs))])
          (prologos_kernel_reset)
          (define t0 (current-inexact-monotonic-milliseconds))
          (preduce-hybrid main-body)
          (- (current-inexact-monotonic-milliseconds) t0)))
      (rest ms-list)))
  (values (avg whnf-warm) (med whnf-warm)
          (avg nf-warm)   (med nf-warm)
          (avg hyb-warm)  (med hyb-warm)))

;; Find files matching the glob pattern. Use directory-list since
;; racket/file doesn't expose `glob` in older Rackets.
(define (find-files g)
  (define dir (path-only g))
  (define name-pattern (file-name-from-path g))
  ;; Strip "*" from the pattern; allow simple prefix-* matches.
  (define name-str (path->string name-pattern))
  (define pat (regexp (string-append "^" (regexp-replace* #rx"[*]" name-str ".*") "$")))
  (for/list ([entry (in-list (directory-list dir #:build? #t))]
             #:when (regexp-match pat (path->string (file-name-from-path entry))))
    entry))

(define files
  (sort (find-files (files-glob))
        (lambda (a b) (string<? (path->string a) (path->string b)))))

(printf "OCapN-suite reducer comparison — ~a runs per program (first dropped as warm-up)~n"
        (runs))
(printf "All times in ms. Caveat: the three reducers compute DIFFERENT things —~n")
(printf "  nf:    full normal form, recurses through structure~n")
(printf "  whnf:  weak-head normal form, stops at outermost ctor (often a no-op for ctor-shaped main)~n")
(printf "  hyb:   preduce-hybrid, network reduction; field sub-terms are valued but held by cell-id~n")
(printf "Net comparison (hyb vs nf) measures both semantic-difference + native-vs-callback speedup.~n~n")
(printf "~a ~a ~a ~a ~a~n"
        (~a "program" #:min-width 32)
        (~a "whnf med" #:min-width 10 #:align 'right)
        (~a "nf med" #:min-width 10 #:align 'right)
        (~a "hyb med" #:min-width 10 #:align 'right)
        (~a "nf/hyb" #:min-width 10 #:align 'right))
(printf "~a~n" (make-string 80 #\-))

(define totals-whnf (box 0.0))
(define totals-nf (box 0.0))
(define totals-hyb (box 0.0))

(for ([f (in-list files)])
  (define name (path->string (file-name-from-path f)))
  (with-handlers ([exn:fail?
                   (lambda (e)
                     (printf "~a FAIL: ~a~n" name (exn-message e)))])
    (define-values (whnf-avg whnf-med nf-avg nf-med hyb-avg hyb-med) (run-one f))
    (set-box! totals-whnf (+ (unbox totals-whnf) whnf-avg))
    (set-box! totals-nf (+ (unbox totals-nf) nf-avg))
    (set-box! totals-hyb (+ (unbox totals-hyb) hyb-avg))
    (printf "~a ~a ~a ~a ~a~n"
            (~a name #:min-width 32)
            (~r whnf-med #:precision '(= 3) #:min-width 10)
            (~r nf-med   #:precision '(= 3) #:min-width 10)
            (~r hyb-med  #:precision '(= 3) #:min-width 10)
            (~r (if (zero? hyb-med) 0.0 (/ nf-med hyb-med))
                #:precision '(= 1) #:min-width 10))))

(printf "~a~n" (make-string 80 #\-))
(printf "~a ~a ~a ~a ~a~n"
        (~a "TOTAL (sum of avgs)" #:min-width 32)
        (~r (unbox totals-whnf) #:precision '(= 2) #:min-width 10)
        (~r (unbox totals-nf)   #:precision '(= 2) #:min-width 10)
        (~r (unbox totals-hyb)  #:precision '(= 2) #:min-width 10)
        (~r (if (zero? (unbox totals-hyb)) 0.0
                (/ (unbox totals-nf) (unbox totals-hyb)))
            #:precision '(= 1) #:min-width 10))
