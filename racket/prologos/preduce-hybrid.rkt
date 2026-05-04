#lang racket/base

;;;
;;; preduce-hybrid.rkt — PReduce-lite compile-expr targeting the hybrid
;;; Racket-Zig runtime instead of the Racket-side propagator.rkt.
;;;
;;; Phase 8 (load-bearing) deliverable: demonstrate end-to-end that an
;;; elaborated Prologos AST compiles to a propagator network in the
;;; Zig kernel, runs to quiescence, and produces a result identical
;;; to what (preduce e) and (nf e) produce on the Racket-side runtime.
;;;
;;; This module currently supports a narrow subset (literals + Int
;;; arithmetic + ann); full coverage matching preduce.rkt's ~120 AST
;;; cases is a fast-follow expansion. The minimum-viable scope proves
;;; the architecture and unlocks the differential-gate methodology.
;;;
;;; Architecture:
;;;   1. compile-expr-hybrid : expr × env × () → cell-id (kernel-side)
;;;      Recurses on AST, calls kernel APIs to alloc cells / install
;;;      propagators. For each unique fire-fn pattern, we register a
;;;      Racket callback at a fresh tag the first time it's needed.
;;;   2. preduce-hybrid : expr → expr
;;;      Resets kernel state, compiles, runs to quiescence, reads
;;;      the result cell, unboxes back to a Prologos AST value.
;;;
;;; Cross-references:
;;;   docs/tracking/2026-05-03_HYBRID_RUNTIME_DESIGN.md (the design)
;;;   racket/prologos/preduce.rkt (the Racket-side reducer; reference)
;;;   racket/prologos/runtime-bridge.rkt (FFI layer)

(require racket/match
         "syntax.rkt"
         "runtime-bridge.rkt")

(provide preduce-hybrid
         preduce-hybrid-supported?)

;; ====================================================================
;; Tag registry — assign a fresh kernel tag per fire-fn pattern
;; ====================================================================
;;
;; We reserve tag 0 for kernel-native int-add (already built in to
;; the Zig kernel; no callback overhead). Tags 1..7 are kernel-native
;; for sub/mul/div/eq/lt/le/select. Tags 8..15 are Racket callbacks
;; we register on first use. (N_TAGS=16 in the kernel; if we exceed
;; this we'd need to bump the kernel limit.)

;; Built-in tags (must match prologos-runtime-hybrid.zig):
(define KERNEL-INT-ADD-TAG  0)
(define KERNEL-INT-SUB-TAG  1)
(define KERNEL-INT-MUL-TAG  2)
(define KERNEL-INT-DIV-TAG  3)
(define KERNEL-INT-EQ-TAG   4)
(define KERNEL-INT-LT-TAG   5)
(define KERNEL-INT-LE-TAG   6)

;; Tags 8+ allocated dynamically for Racket callbacks.
;; CRITICAL: we must keep Racket-side references to wrapped fn-ptrs to
;; prevent GC. The hash stores BOTH the tag (so we don't re-register)
;; AND the wrapped procedure (so Racket's GC doesn't collect it while
;; the kernel still holds the fn-ptr). See ffi/unsafe `function-ptr`
;; docs: callbacks must be kept reachable from Racket-side roots for
;; their entire callable lifetime.
(define next-callback-tag (box 8))
(define registered-callbacks (make-hash))  ;; (cons name shape) -> (cons tag closure-keeper)

(define (allocate-callback-tag! name shape rkt-fire-fn)
  (define key (cons name shape))
  (cond
    [(hash-ref registered-callbacks key #f)
     => (lambda (entry) (car entry))]
    [else
     (define tag (unbox next-callback-tag))
     (set-box! next-callback-tag (+ tag 1))
     (when (>= tag 16)
       (error 'preduce-hybrid
              "callback tag space exhausted (>16); raise N_TAGS in kernel"))
     ;; Keep Racket-side reference to rkt-fire-fn (and the wrapped fn-ptr)
     ;; via the hash so GC doesn't free them while the kernel holds the
     ;; fn-ptr in its dispatch table.
     (register-fire-fn! tag shape rkt-fire-fn)
     (hash-set! registered-callbacks key (cons tag rkt-fire-fn))
     tag]))

;; ====================================================================
;; Per-program cell-allocator (always via kernel)
;; ====================================================================

(define (alloc-cell-with-value boxed-value)
  (define cid (prologos_cell_alloc))
  (prologos_cell_write cid boxed-value)
  cid)

;; ====================================================================
;; compile-expr-hybrid
;; ====================================================================
;;
;; Returns a kernel cell-id whose value (after run_to_quiescence) is
;; the WHNF of expr. env is a list of cell-ids indexed by de Bruijn
;; (innermost-first), same convention as preduce.rkt.

(define (compile-expr-hybrid e env)
  (match e
    ;; Literals: alloc cell with boxed value.
    [(? expr-int?) (alloc-cell-with-value (box-prologos-value e))]
    [(? expr-true?)
     (alloc-cell-with-value (prologos_cell_box_bool 1))]
    [(? expr-false?)
     (alloc-cell-with-value (prologos_cell_box_bool 0))]
    [(? expr-nat-val?) (alloc-cell-with-value (box-prologos-value e))]
    [(? expr-zero?) (alloc-cell-with-value (prologos_cell_box_nat 0))]

    ;; Annotation erasure
    [(expr-ann inner _) (compile-expr-hybrid inner env)]

    ;; Bound variable
    [(expr-bvar i)
     (when (or (< i 0) (>= i (length env)))
       (error 'preduce-hybrid "bvar ~a out of range (env depth ~a)" i (length env)))
     (list-ref env i)]

    ;; Int arithmetic — use kernel-native built-ins (zero callback overhead)
    [(expr-int-add a b) (compile-int-binary a b env KERNEL-INT-ADD-TAG)]
    [(expr-int-sub a b) (compile-int-binary a b env KERNEL-INT-SUB-TAG)]
    [(expr-int-mul a b) (compile-int-binary a b env KERNEL-INT-MUL-TAG)]
    [(expr-int-div a b) (compile-int-binary a b env KERNEL-INT-DIV-TAG)]
    [(expr-int-eq  a b) (compile-int-binary a b env KERNEL-INT-EQ-TAG)]
    [(expr-int-lt  a b) (compile-int-binary a b env KERNEL-INT-LT-TAG)]
    [(expr-int-le  a b) (compile-int-binary a b env KERNEL-INT-LE-TAG)]

    ;; expr-suc — simple pattern: same kernel as int-add of (inner, 1).
    ;; We register a small Racket callback for the nat-val/zero collapse logic.
    [(expr-suc inner)
     (define cid-in (compile-expr-hybrid inner env))
     (define cid-out (prologos_cell_alloc))
     (prologos_cell_write cid-out (prologos_cell_box_bot))
     (define tag
       (allocate-callback-tag! 'suc 1
         (lambda (boxed-in)
           ;; Decode to Prologos value; run the suc rule; re-encode.
           (define v (unbox-prologos-value boxed-in))
           (define result
             (cond
               [(expr-nat-val? v) (expr-nat-val (+ (expr-nat-val-n v) 1))]
               [(expr-zero? v) (expr-nat-val 1)]
               [else (expr-suc v)]))
           (box-prologos-value result))))
     (prologos_propagator_install_1_1 tag cid-in cid-out)
     cid-out]

    [_ (error 'preduce-hybrid
              "unsupported AST node ~v (Phase 8 minimum scope: int arithmetic + literals)"
              e)]))

(define (compile-int-binary a b env tag)
  (define cid-a (compile-expr-hybrid a env))
  (define cid-b (compile-expr-hybrid b env))
  (define cid-out (prologos_cell_alloc))
  (prologos_cell_write cid-out (prologos_cell_box_bot))
  (prologos_propagator_install_2_1 tag cid-a cid-b cid-out)
  cid-out)

;; ====================================================================
;; Top-level entry point
;; ====================================================================

(define (preduce-hybrid e)
  (reset-handle-table!)
  (define result-cid (compile-expr-hybrid e '()))
  (prologos_run_to_quiescence)
  (define result-boxed (prologos_cell_read result-cid))
  (unbox-prologos-value result-boxed))

;; preduce-hybrid-supported? — quick check for whether this expression
;; is in the Phase 8 minimum-viable subset (no nodes that would error).
;; Used by tests that may run on the hybrid runtime when supported,
;; or fall back to the Racket-side preduce otherwise.
(define (preduce-hybrid-supported? e)
  (match e
    [(? expr-int?) #t]
    [(? expr-true?) #t]
    [(? expr-false?) #t]
    [(? expr-nat-val?) #t]
    [(? expr-zero?) #t]
    [(expr-ann inner _) (preduce-hybrid-supported? inner)]
    [(expr-bvar _) #t]
    [(expr-int-add a b) (and (preduce-hybrid-supported? a) (preduce-hybrid-supported? b))]
    [(expr-int-sub a b) (and (preduce-hybrid-supported? a) (preduce-hybrid-supported? b))]
    [(expr-int-mul a b) (and (preduce-hybrid-supported? a) (preduce-hybrid-supported? b))]
    [(expr-int-div a b) (and (preduce-hybrid-supported? a) (preduce-hybrid-supported? b))]
    [(expr-int-eq  a b) (and (preduce-hybrid-supported? a) (preduce-hybrid-supported? b))]
    [(expr-int-lt  a b) (and (preduce-hybrid-supported? a) (preduce-hybrid-supported? b))]
    [(expr-int-le  a b) (and (preduce-hybrid-supported? a) (preduce-hybrid-supported? b))]
    [(expr-suc inner) (preduce-hybrid-supported? inner)]
    [_ #f]))
