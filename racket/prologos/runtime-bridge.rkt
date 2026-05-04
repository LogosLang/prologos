#lang racket/base

;;;
;;; runtime-bridge.rkt — Racket FFI bindings for libprologos-runtime-hybrid.so
;;;
;;; The Phase 6 layer of the hybrid Racket-Zig runtime. Provides
;;; (a) raw FFI bindings to the kernel's exported C ABI, plus
;;; (b) the per-call Racket-side handle table for boxing Racket
;;;     values into the kernel's tagged-i64 cell values.
;;;
;;; Cross-references:
;;;   docs/tracking/2026-05-03_HYBRID_RUNTIME_DESIGN.md (the design doc)
;;;   runtime/prologos-runtime-hybrid.zig (the kernel)
;;;
;;; The .so is loaded via ffi-lib using a path relative to this
;;; module so it works both in-tree and after `raco distribute`.

(require ffi/unsafe
         ffi/unsafe/define
         racket/runtime-path)

(define-runtime-path RUNTIME-DIR "../../runtime")

;; Lib resolution: try LD_LIBRARY_PATH-resolved lookup FIRST (so the
;; raco-distribute bundle finds lib/libprologos-runtime-hybrid.so via
;; the launcher's LD_LIBRARY_PATH). Fall back to the in-tree runtime/
;; directory for development. Both paths are #:fail-soft so module
;; loads cleanly even with no .so built — consumers gate on
;; `hybrid-runtime-available?`.
(define libprologos-runtime-hybrid
  (or (ffi-lib "libprologos-runtime-hybrid" #:fail (lambda () #f))
      (with-handlers ([exn:fail? (lambda _ #f)])
        (ffi-lib (build-path RUNTIME-DIR "libprologos-runtime-hybrid")
                 #:fail (lambda () #f)))))

(define (hybrid-runtime-available?)
  (and libprologos-runtime-hybrid #t))

;; When lib is #f (unavailable), use a stub-installing definer so module
;; loads cleanly. Each FFI binding is a procedure that errors loudly
;; when called. Tests gate via `hybrid-runtime-available?` to skip
;; entirely when unavailable.
(define-syntax-rule (define-rt name ftype)
  (define name
    (if libprologos-runtime-hybrid
        (get-ffi-obj 'name libprologos-runtime-hybrid ftype)
        (lambda args
          (error 'name
                 "libprologos-runtime-hybrid.so not loaded; build the kernel via zig build-lib first")))))

;; ====================================================================
;; Cell + propagator API
;; ====================================================================

(define-rt prologos_cell_alloc            (_fun -> _uint32))
(define-rt prologos_cell_write            (_fun _uint32 _int64 -> _void))
(define-rt prologos_cell_read             (_fun _uint32 -> _int64))

(define-rt prologos_propagator_install_1_1 (_fun _uint32 _uint32 _uint32 -> _uint32))
(define-rt prologos_propagator_install_2_1 (_fun _uint32 _uint32 _uint32 _uint32 -> _uint32))
(define-rt prologos_propagator_install_3_1 (_fun _uint32 _uint32 _uint32 _uint32 _uint32 -> _uint32))
(define-rt prologos_propagator_install_n_1
  (_fun _uint32 (_list i _uint32) _uint32 _uint32 -> _uint32))

(define-rt prologos_run_to_quiescence     (_fun -> _void))
(define-rt prologos_set_max_rounds        (_fun _uint64 -> _void))
(define-rt prologos_kernel_reset          (_fun -> _void))

;; ====================================================================
;; Tagged-i64 marshaling
;; ====================================================================

(define-rt prologos_cell_box_int     (_fun _int64 -> _int64))
(define-rt prologos_cell_box_bool    (_fun _uint8 -> _int64))
(define-rt prologos_cell_box_nat     (_fun _int64 -> _int64))
(define-rt prologos_cell_box_handle  (_fun _uint64 -> _int64))
(define-rt prologos_cell_box_bot     (_fun -> _int64))
(define-rt prologos_cell_box_top     (_fun -> _int64))
(define-rt prologos_cell_value_kind  (_fun _int64 -> _uint32))
(define-rt prologos_cell_unbox_payload (_fun _int64 -> _int64))

;; Tag constants (must match prologos-runtime-hybrid.zig).
(define TAG-INT    0)
(define TAG-BOOL   1)
(define TAG-NAT    2)
(define TAG-BOT    3)
(define TAG-TOP    4)
(define TAG-HANDLE 5)

;; ====================================================================
;; Dynamic fire-fn registration
;; ====================================================================

(define KIND-KERNEL          0)
(define KIND-RACKET-CALLBACK 1)

(define-rt prologos_register_fire_fn
  (_fun _uint32 _uint32 _uint32 _fpointer -> _uint32))

;; Wrap a Racket procedure as a C function pointer with the given shape.
;; Shape 1 / 2 / 3 take that many _int64 args. Shape 4 (N) takes
;; (uint32, ptr-to-int64-array). Each returns _int64 (a tagged i64).
(define (wrap-fire-fn shape rkt-proc)
  (case shape
    [(1) (function-ptr
          (lambda (a) (rkt-proc a))
          (_fun #:atomic? #t _int64 -> _int64))]
    [(2) (function-ptr
          (lambda (a b) (rkt-proc a b))
          (_fun #:atomic? #t _int64 _int64 -> _int64))]
    [(3) (function-ptr
          (lambda (a b c) (rkt-proc a b c))
          (_fun #:atomic? #t _int64 _int64 _int64 -> _int64))]
    [(4) (function-ptr
          (lambda (n inputs-ptr)
            (define inputs
              (for/list ([i (in-range n)])
                (ptr-ref inputs-ptr _int64 i)))
            (rkt-proc inputs))
          (_fun #:atomic? #t _uint32 _pointer -> _int64))]
    [else (error 'wrap-fire-fn "bad shape ~v (must be 1/2/3/4)" shape)]))

;; Module-level keepalive table to prevent Racket from GC'ing wrapped
;; fn-ptrs while the kernel's dispatch table still holds them. Without
;; this, segfaults appear after GC moves/frees the underlying closures
;; — the kernel calls back into Racket through a stale pointer.
;; Keyed by (tag . shape); value is (cons rkt-proc c-fn-ptr).
(define registered-fire-fns (make-hash))

;; Register a Racket fire-fn at the given tag/shape. kind defaults to
;; KIND-RACKET-CALLBACK (so callback profiling tracks it). Pass kind
;; KIND-KERNEL only if you know the fn is fast Racket code that
;; semantically counts as a kernel-quality op.
(define (register-fire-fn! tag shape rkt-proc
                           #:kind [kind KIND-RACKET-CALLBACK])
  (define c-fn (wrap-fire-fn shape rkt-proc))
  (define rc (prologos_register_fire_fn tag shape kind c-fn))
  (unless (zero? rc)
    (error 'register-fire-fn! "kernel returned error code ~a" rc))
  ;; Pin the wrapped fn-ptr Racket-side so GC doesn't free it while
  ;; the kernel holds the C pointer.
  (hash-set! registered-fire-fns (cons tag shape) (cons rkt-proc c-fn))
  (void))

;; ====================================================================
;; Profiling APIs
;; ====================================================================

(define-rt prologos_set_profile_per_tag    (_fun _uint32 -> _void))
(define-rt prologos_get_stat               (_fun _uint32 -> _uint64))
(define-rt prologos_reset_stats            (_fun -> _void))
(define-rt prologos_print_stats            (_fun -> _void))
(define-rt prologos_print_callback_summary (_fun -> _void))
(define-rt prologos_set_round_callback     (_fun _fpointer -> _void))

;; Stat key constants
(define STAT-ROUNDS              0)
(define STAT-FIRES-TOTAL         1)
(define STAT-WRITES-COMMITTED    2)
(define STAT-WRITES-DROPPED      3)
(define STAT-MAX-WORKLIST        4)
(define STAT-FUEL-EXHAUSTED      5)
(define STAT-NUM-CELLS           6)
(define STAT-NUM-PROPS           7)
(define STAT-RUN-NS              8)
(define (stat-fires-by-tag tag)        (+ 100 tag))
(define (stat-ns-by-tag tag)           (+ 200 tag))
(define (stat-callbacks-by-tag tag)    (+ 300 tag))
(define (stat-callback-ns-by-tag tag)  (+ 400 tag))

;; ====================================================================
;; Racket-side handle table for boxing Racket values
;; ====================================================================
;;
;; The kernel's tagged-i64 cells can hold:
;;   - Tag 0 (INT): a 56-bit signed int directly (fits ints up to ±2^55)
;;   - Tag 1 (BOOL): 0 or 1
;;   - Tag 2 (NAT): a 56-bit unsigned int
;;   - Tag 3 (BOT): no payload
;;   - Tag 4 (TOP): no payload
;;   - Tag 5 (HANDLE): index into THIS handle table (Racket-side)
;;
;; The handle table is per-call: reset-handle-table! before each
;; (preduce e) call. Stores arbitrary Racket values; lookups return
;; them. 4096 entries is the default capacity.

(define HANDLE-TABLE-SIZE 4096)
(define handle-table (make-vector HANDLE-TABLE-SIZE #f))
(define handle-next 0)

(define (reset-handle-table!)
  ;; Clear the handle table. Called at start of each (preduce e).
  ;; Also resets the kernel state (cells/props/profile).
  (vector-fill! handle-table #f)
  (set! handle-next 0)
  (prologos_kernel_reset))

(define (box-racket-value v)
  ;; Allocate a fresh handle slot, store v, return the kernel-side
  ;; tagged i64 pointing to that slot.
  (when (>= handle-next HANDLE-TABLE-SIZE)
    (error 'box-racket-value
           "handle table full (~a entries); program may be too large for current limit"
           HANDLE-TABLE-SIZE))
  (define i handle-next)
  (vector-set! handle-table i v)
  (set! handle-next (+ i 1))
  (prologos_cell_box_handle i))

(define (unbox-racket-handle boxed-i64)
  ;; Read the handle slot pointed to by boxed-i64; return the Racket value.
  (define i (prologos_cell_unbox_payload boxed-i64))
  (vector-ref handle-table i))

;; ====================================================================
;; High-level box/unbox dispatching on tag
;; ====================================================================
;;
;; box-prologos-value/unbox-prologos-value bridge between Prologos AST
;; and tagged-i64. Keeps small-int-like values inline (zero handle-table
;; cost); other values go through the handle table.

(require "syntax.rkt")

(define (box-prologos-value v)
  (cond
    ;; Inline cases: int, bool, nat-val, zero
    [(expr-int? v)
     (define n (expr-int-val v))
     (if (and (>= n (- (expt 2 55))) (< n (expt 2 55)))
         (prologos_cell_box_int n)
         (box-racket-value v))]
    [(expr-true? v)  (prologos_cell_box_bool 1)]
    [(expr-false? v) (prologos_cell_box_bool 0)]
    [(expr-nat-val? v)
     (define n (expr-nat-val-n v))
     (if (and (>= n 0) (< n (expt 2 56)))
         (prologos_cell_box_nat n)
         (box-racket-value v))]
    [(expr-zero? v) (prologos_cell_box_nat 0)]
    ;; Sentinels
    [(eq? v 'preduce-bot) (prologos_cell_box_bot)]
    [(eq? v 'preduce-top) (prologos_cell_box_top)]
    ;; Everything else: handle table
    [else (box-racket-value v)]))

(define (unbox-prologos-value boxed-i64)
  (define kind (prologos_cell_value_kind boxed-i64))
  (cond
    [(= kind TAG-INT)    (expr-int (prologos_cell_unbox_payload boxed-i64))]
    [(= kind TAG-BOOL)   (if (= (prologos_cell_unbox_payload boxed-i64) 1)
                              (expr-true) (expr-false))]
    [(= kind TAG-NAT)    (expr-nat-val (prologos_cell_unbox_payload boxed-i64))]
    [(= kind TAG-BOT)    'preduce-bot]
    [(= kind TAG-TOP)    'preduce-top]
    [(= kind TAG-HANDLE) (unbox-racket-handle boxed-i64)]
    [else (error 'unbox-prologos-value "unknown tag ~a" kind)]))

(provide
 ;; Availability
 hybrid-runtime-available?

 ;; Cell + propagator API
 prologos_cell_alloc
 prologos_cell_write
 prologos_cell_read
 prologos_propagator_install_1_1
 prologos_propagator_install_2_1
 prologos_propagator_install_3_1
 prologos_propagator_install_n_1
 prologos_run_to_quiescence
 prologos_set_max_rounds
 prologos_kernel_reset

 ;; Marshaling
 prologos_cell_box_int
 prologos_cell_box_bool
 prologos_cell_box_nat
 prologos_cell_box_handle
 prologos_cell_box_bot
 prologos_cell_box_top
 prologos_cell_value_kind
 prologos_cell_unbox_payload

 TAG-INT TAG-BOOL TAG-NAT TAG-BOT TAG-TOP TAG-HANDLE

 ;; Dispatch
 prologos_register_fire_fn
 register-fire-fn!
 wrap-fire-fn
 KIND-KERNEL KIND-RACKET-CALLBACK

 ;; Profiling
 prologos_set_profile_per_tag
 prologos_get_stat
 prologos_reset_stats
 prologos_print_stats
 prologos_print_callback_summary

 STAT-ROUNDS STAT-FIRES-TOTAL STAT-WRITES-COMMITTED STAT-WRITES-DROPPED
 STAT-MAX-WORKLIST STAT-FUEL-EXHAUSTED STAT-NUM-CELLS STAT-NUM-PROPS STAT-RUN-NS
 stat-fires-by-tag stat-ns-by-tag stat-callbacks-by-tag stat-callback-ns-by-tag

 ;; Handle table + high-level box/unbox
 reset-handle-table!
 box-racket-value
 unbox-racket-handle
 box-prologos-value
 unbox-prologos-value)
