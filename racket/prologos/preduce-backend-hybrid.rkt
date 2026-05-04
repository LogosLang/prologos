#lang racket/base

;;;
;;; preduce-backend-hybrid.rkt — Zig-kernel backend for preduce-core.
;;;
;;; Wraps the runtime-bridge.rkt FFI primitives as a preduce-backend
;;; instance. `net` is the sentinel symbol 'hybrid (purely formal
;;; threading; the kernel state mutates underneath).
;;;
;;; Key bridging: when compile-expr installs a fire-once propagator
;;; via `b-install-fire-once net inputs outputs fire-fn`, the
;;; backend allocates a fresh kernel callback tag, registers a
;;; wrapper that:
;;;
;;;   1. Receives boxed input values from the kernel (per the
;;;      callback ABI: shape 1/2/3 take that many _int64 args).
;;;   2. Invokes the fire-fn with `net = 'hybrid`. The fire-fn
;;;      uses (b-read 'hybrid cid) and (b-write 'hybrid cid v)
;;;      internally — these reach back into THIS backend's
;;;      read-cell / write-cell, which call prologos_cell_read /
;;;      prologos_cell_write through box-/unbox-prologos-value.
;;;   3. Returns the boxed value from the FIRST output cell. The
;;;      kernel auto-writes this; cells.zig:write_unchecked sees
;;;      no change since our fire-fn already wrote via b-write.
;;;
;;; The fire-fn's threading discipline (`net → net'`) is preserved;
;;; the 'hybrid sentinel flows through unchanged. This is the
;;; formal threading that maps to real dataflow when compile-expr
;;; eventually runs natively (SH Track 9 endpoint, where `net`
;;; becomes a cell-id pointing to the network value being built).
;;;
;;; Cross-references:
;;;   docs/tracking/2026-05-04_PREDUCE_BACKEND_REFACTOR_DESIGN.md
;;;   racket/prologos/runtime-bridge.rkt (FFI + box/unbox helpers)
;;;   racket/prologos/preduce-core.rkt (the backend struct)

(require "preduce-core.rkt"
         "runtime-bridge.rkt")

(provide backend-hybrid)

;; ====================================================================
;; Tag allocation (mirrors preduce-hybrid.rkt's machinery)
;; ====================================================================

(define KERNEL-NATIVE-TAG-COUNT 8)
(define MAX-N-TAGS 256)
(define next-callback-tag (box KERNEL-NATIVE-TAG-COUNT))

;; Symbolic native-op names → kernel dispatch tags. The kernel reserves
;; tags 0-7 for built-in native fire-fns (compiled into the .so). When
;; preduce.rkt installs a fire-fn with #:native-op set to one of these
;; symbols, we install at the native tag instead of allocating a fresh
;; callback tag — restoring the pre-refactor native dispatch for int
;; arithmetic + the identity-bridge.
;;
;; Note: tag 0 serves DOUBLE duty in the kernel — KERNEL-INT-ADD-TAG
;; and KERNEL-IDENTITY-TAG both alias to 0. The kernel's native fire-fn
;; at tag 0 is the int-add implementation; the identity-bridge migration
;; (Phase 10 of the original hybrid track) reused it because identity
;; happens to be expressible as "fire-fn returns its first input" which
;; is what int-add-with-zero-rhs does. See runtime/prologos-runtime-
;; hybrid.zig for the actual native fire-fn definitions.
(define NATIVE-OP-TAGS
  (hasheq 'int-add  0    ;; KERNEL-INT-ADD-TAG (also KERNEL-IDENTITY-TAG)
          'identity 0    ;; same kernel tag — see note above
          'int-sub  1
          'int-mul  2
          'int-div  3
          'int-eq   4
          'int-lt   5
          'int-le   6))

(define (next-tag!)
  (define tag (unbox next-callback-tag))
  (when (>= tag MAX-N-TAGS)
    (error 'backend-hybrid
           "kernel callback tag space exhausted (~a allocated, max ~a)"
           tag MAX-N-TAGS))
  (set-box! next-callback-tag (+ tag 1))
  tag)

(define (reset-callback-tags!)
  (set-box! next-callback-tag KERNEL-NATIVE-TAG-COUNT))

;; ====================================================================
;; Callback wrapping
;; ====================================================================
;;
;; Wrap a Racket fire-fn (signature: net → net') as a kernel-side
;; C callback (signature: boxed-inputs → boxed-output). The wrapper
;; ignores the boxed inputs (the fire-fn fetches them via b-read);
;; invokes fire-fn under (current-backend = backend-hybrid); reads
;; back the output cell to satisfy the kernel ABI.

(define (make-callback-wrapper outputs fire-fn)
  (lambda boxed-inputs
    ;; Ignore boxed-inputs: fire-fn fetches via b-read.
    (parameterize ([current-backend backend-hybrid])
      (fire-fn 'hybrid))
    ;; Return the first output cell's current boxed value. The kernel
    ;; auto-writes this; cells.zig:write_unchecked sees no change.
    (cond
      [(null? outputs) (prologos_cell_box_bot)]   ;; defensive
      [else (prologos_cell_read (car outputs))])))

;; ====================================================================
;; Backend instance
;; ====================================================================

(define backend-hybrid
  (preduce-backend
   ;; alloc-cell : net × value → (values cid net')
   (lambda (net v)
     (define cid (prologos_cell_alloc))
     (prologos_cell_write cid (box-prologos-value v))
     (values cid 'hybrid))

   ;; read-cell : net × cid → value
   (lambda (net cid)
     (unbox-prologos-value (prologos_cell_read cid)))

   ;; write-cell : net × cid × value → net'
   (lambda (net cid v)
     (prologos_cell_write cid (box-prologos-value v))
     'hybrid)

   ;; install-fire-once : net × inputs × outputs × fire-fn × #:native-op → net'
   ;;   #:native-op (symbol) — when set to a name in NATIVE-OP-TAGS,
   ;;   install at the kernel's built-in native tag (tags 0-7) instead
   ;;   of allocating a fresh callback tag. This skips register-fire-fn!
   ;;   entirely; the kernel uses its compiled-in native fire-fn for
   ;;   the dispatch. Restores the int-arith + identity-bridge native
   ;;   path that the swappable-backend refactor lost.
   (lambda (net inputs outputs fire-fn #:native-op [native-op #f])
     (define n-inputs (length inputs))
     (when (> n-inputs 3)
       (error 'backend-hybrid
              "N-1 propagator install (n=~a) not yet supported" n-inputs))
     (define shape n-inputs)
     (define native-tag (and native-op (hash-ref NATIVE-OP-TAGS native-op #f)))
     (define tag
       (cond
         [native-tag
          ;; Native path: skip register-fire-fn!; use the kernel's
          ;; built-in fire-fn at the native tag. fire-fn is unused.
          native-tag]
         [else
          ;; Callback path: allocate fresh tag, register Racket wrapper.
          (define wrapper (make-callback-wrapper outputs fire-fn))
          (define t (next-tag!))
          (register-fire-fn! t shape wrapper)
          t]))
     (cond
       [(= shape 1)
        (prologos_propagator_install_1_1 tag (car inputs) (car outputs))]
       [(= shape 2)
        (prologos_propagator_install_2_1 tag (car inputs) (cadr inputs) (car outputs))]
       [(= shape 3)
        (prologos_propagator_install_3_1 tag (car inputs) (cadr inputs) (caddr inputs) (car outputs))]
       [else (error 'backend-hybrid "unsupported shape ~a" shape)])
     'hybrid)

   ;; install-propagator : same as install-fire-once today (kernel only
   ;; has fire-once; preduce.rkt's compile-expr never installs re-fireable)
   (lambda (net inputs outputs fire-fn #:native-op [native-op #f])
     (((preduce-backend-install-fire-once backend-hybrid))
      net inputs outputs fire-fn #:native-op native-op))

   ;; run-to-quiescence : net → net'
   (lambda (net)
     (prologos_run_to_quiescence)
     'hybrid)

   ;; fresh-net : () → net
   (lambda ()
     (reset-callback-tags!)
     (reset-handle-table!)  ;; resets kernel state too
     'hybrid)))
