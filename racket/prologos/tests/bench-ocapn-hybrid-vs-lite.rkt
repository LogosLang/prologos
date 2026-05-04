#lang racket/base

;;; bench-ocapn-hybrid-vs-lite.rkt
;;;
;;; Benchmark: OCapN-shape AST workloads under preduce-lite (Racket
;;; backend) vs the hybrid kernel (Zig backend). Measures wall time
;;; for each + the kernel's native-vs-callback ns breakdown.
;;;
;;; Workloads are hand-built ASTs that mirror what the OCapN syrup
;;; tests produce after elaboration (Phase 10b user-defined-ctor
;;; pattern matching). Avoids the elaborator pipeline so the
;;; measurement is pure reduction time.

(require "../preduce.rkt"
         "../preduce-core.rkt"
         "../preduce-backend-hybrid.rkt"
         "../runtime-bridge.rkt"
         "../syntax.rkt"
         "../macros.rkt"
         (only-in "../reduction.rkt" nf))

(unless (hybrid-runtime-available?)
  (eprintf "kernel .so not available — build via tools/build-hybrid-binary.sh~n")
  (exit 1))

;; Register synthetic types matching syrup's nullary + unary cases.
(register-ctor! 'bench-null (ctor-meta 'Bench '() '()         '()  0))
(register-ctor! 'bench-tag  (ctor-meta 'Bench '() (list 'Nat) '(#f) 1))

;; ====================================================================
;; Workloads
;; ====================================================================

;; W1: bare nullary user ctor (lightest case — single alloc).
;;     Mirrors `(eval syrup-null)`.
(define W1-bare-null (expr-fvar 'bench-null))

;; W2: unary ctor application (one cell + one alloc).
;;     Mirrors `(eval (syrup-nat (suc (suc zero))))`.
(define W2-unary-app
  (expr-app (expr-fvar 'bench-tag) (expr-suc (expr-suc (expr-zero)))))

;; W3: match selecting nullary arm (one expr-reduce + arm dispatch).
;;     Mirrors `(eval (null? syrup-null))`.
(define W3-match-nullary
  (expr-reduce (expr-fvar 'bench-null)
               (list (expr-reduce-arm 'bench-null 0 (expr-int 42))
                     (expr-reduce-arm 'bench-tag 1 (expr-int 99)))
               #t))

;; W4: match selecting unary arm + extracting field.
;;     Mirrors `(eval (get-nat (syrup-nat (suc (suc (suc zero))))))`.
;;     This is the headline OCapN-shape case.
(define W4-match-unary-extract
  (expr-reduce (expr-app (expr-fvar 'bench-tag) (expr-suc (expr-suc (expr-suc (expr-zero)))))
               (list (expr-reduce-arm 'bench-null 0 (expr-int 0))
                     (expr-reduce-arm 'bench-tag 1 (expr-bvar 0)))
               #t))

(define WORKLOADS
  (list (cons "W1 bare-null" W1-bare-null)
        (cons "W2 unary-app" W2-unary-app)
        (cons "W3 match-nullary" W3-match-nullary)
        (cons "W4 match-unary-extract" W4-match-unary-extract)))

;; ====================================================================
;; Measurement
;; ====================================================================

(define ITERATIONS 1000)

(define (measure-preduce e)
  ;; Wall-time-ms for ITERATIONS runs of (preduce e).
  (define start (current-inexact-milliseconds))
  (for ([i (in-range ITERATIONS)])
    (preduce e))
  (- (current-inexact-milliseconds) start))

(define (measure-preduce-hybrid e)
  ;; Wall-time-ms for ITERATIONS runs of compile-expr + b-run-to-quiescence
  ;; through backend-hybrid.
  (define start (current-inexact-milliseconds))
  (for ([i (in-range ITERATIONS)])
    (with-backend backend-hybrid
      (define net0 (b-fresh-net))
      (define-values (cid net1) (compile-expr e '() net0))
      (b-run-to-quiescence net1)
      (b-read 'hybrid cid)))
  (- (current-inexact-milliseconds) start))

(define (capture-kernel-profile e)
  ;; Run once with profiling enabled; return (hash 'total-ns N
  ;; 'callback-ns N 'native-ns N 'total-fires N 'callback-fires N).
  (prologos_set_profile_per_tag 1)
  (prologos_reset_stats)
  (with-backend backend-hybrid
    (define net0 (b-fresh-net))
    (define-values (cid net1) (compile-expr e '() net0))
    (b-run-to-quiescence net1)
    (b-read 'hybrid cid))
  (define run-ns (prologos_get_stat 8))   ;; STAT-RUN-NS
  (define total-fires (prologos_get_stat 1)) ;; STAT-FIRES-TOTAL
  (define total-ns
    (for/sum ([t (in-range 256)]) (prologos_get_stat (+ 2048 t))))
  (define callback-fires
    (for/sum ([t (in-range 256)]) (prologos_get_stat (+ 3072 t))))
  (define callback-ns
    (for/sum ([t (in-range 256)]) (prologos_get_stat (+ 4096 t))))
  (hash 'run-ns run-ns
        'total-fires total-fires
        'total-ns total-ns
        'callback-fires callback-fires
        'callback-ns callback-ns
        'native-ns (max 0 (- total-ns callback-ns))
        'native-fires (max 0 (- total-fires callback-fires))))

;; ====================================================================
;; Run
;; ====================================================================

(printf "Iterations per workload: ~a~n" ITERATIONS)
(printf "Calibrating...~n")

;; Warm-up
(for ([w (in-list WORKLOADS)])
  (preduce (cdr w))
  (with-backend backend-hybrid
    (define net0 (b-fresh-net))
    (define-values (cid net1) (compile-expr (cdr w) '() net0))
    (b-run-to-quiescence net1)))

(define (pad s n)
  (define str (if (string? s) s (format "~a" s)))
  (define len (string-length str))
  (if (>= len n) str (string-append str (make-string (- n len) #\space))))

(printf "~n=== Wall-time comparison (~a iterations) ===~n" ITERATIONS)
(printf "~a  ~a  ~a  ~a  ~a~n"
        (pad "workload" 28) (pad "lite (ms)" 10) (pad "hybrid (ms)" 12)
        (pad "lite µs/run" 12) (pad "hybrid µs/run" 14))
(for ([w (in-list WORKLOADS)])
  (define name (car w))
  (define e    (cdr w))
  (define lite-ms   (measure-preduce e))
  (define hybrid-ms (measure-preduce-hybrid e))
  (printf "~a  ~a  ~a  ~a  ~a~n"
          (pad name 28)
          (pad (real->decimal-string lite-ms 2) 10)
          (pad (real->decimal-string hybrid-ms 2) 12)
          (pad (real->decimal-string (* 1000.0 (/ lite-ms ITERATIONS)) 2) 12)
          (pad (real->decimal-string (* 1000.0 (/ hybrid-ms ITERATIONS)) 2) 14)))

(printf "~n=== Hybrid kernel native-vs-callback breakdown (single run each) ===~n")
(printf "~a  ~a  ~a  ~a  ~a  ~a~n"
        (pad "workload" 28) (pad "fires" 8) (pad "cb fires" 10)
        (pad "total ns" 10) (pad "cb ns" 10) (pad "native ns" 10))
(for ([w (in-list WORKLOADS)])
  (define name (car w))
  (define e    (cdr w))
  (define p (capture-kernel-profile e))
  (printf "~a  ~a  ~a  ~a  ~a  ~a~n"
          (pad name 28)
          (pad (hash-ref p 'total-fires) 8)
          (pad (hash-ref p 'callback-fires) 10)
          (pad (hash-ref p 'total-ns) 10)
          (pad (hash-ref p 'callback-ns) 10)
          (pad (hash-ref p 'native-ns) 10)))

(printf "~n=== Notes ===~n")
(printf "- Wall time is measured over ~a iterations to amortize one-time overhead.~n" ITERATIONS)
(printf "- Hybrid wall time includes Racket→FFI roundtrip + kernel BSP scheduler + callback dispatch.~n")
(printf "- Kernel profile (run-ns) measures only kernel-side time (BSP fire loop).~n")
(printf "- Native ns = total ns - callback ns. Today all fire-fns are callbacks~n")
(printf "  (post-refactor backend-hybrid wraps every fire-fn as KIND_RACKET_CALLBACK);~n")
(printf "  Phase 7 migration replaces the heaviest with native Zig fire-fns.~n")
