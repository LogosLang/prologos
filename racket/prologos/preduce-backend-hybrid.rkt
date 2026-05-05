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
;; Must match runtime/core/profile.zig:N_TAGS. Bumped 2026-05-05
;; from 256 -> 4096 to unblock realistic recursive workloads
;; (W14 prime-count at N>=7 was hitting the old 256-tag limit).
(define MAX-N-TAGS 4096)
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
;; Callback wrapping (Fix C, 2026-05-05)
;; ====================================================================
;;
;; BSP correctness contract: native fire-fns read inputs from the
;; round's snapshot (store.read_snapshot) and return their result;
;; the kernel pends (cid, value) and merge_pending_writes commits +
;; schedules subscribers at the barrier. Callback fire-fns must
;; honor the same contract — otherwise reads/writes within a round
;; are non-coherent (callback A's mid-round live write becomes
;; visible to callback B's b-read in the same round).
;;
;; The original 2026-05-04 wrapper had fire-fn read LIVE state
;; (b-read -> prologos_cell_read) and write LIVE (b-write ->
;; prologos_cell_write). That violated BSP. Fix A' (the dirtied-
;; buffer hack) addressed only the schedule-skip half; reads
;; remained inconsistent. Fix C (this) makes b-read snapshot-read
;; AND b-write capture (per-fire-fn pending), so within-round
;; coherence is restored.
;;
;; Per-fire-fn pending: while inside a callback wrapper, b-write
;; appends to current-fire-fn-pending; the wrapper extracts the
;; final captured (cid, value) and returns it boxed. The kernel's
;; pending machinery then commits and schedules at the barrier.
;; Multi-output callbacks panic — preduce.rkt's fire-fns are all
;; single-output (per fire-once).

;; Per-fire-fn write-capture box. Set by make-callback-wrapper to
;; a fresh mutable box during fire-fn execution; #f outside any
;; fire-fn (initialization, allocation, post-run reads).
(define current-fire-fn-pending (make-parameter #f))

(define (make-callback-wrapper outputs fire-fn)
  (when (or (null? outputs) (not (null? (cdr outputs))))
    (error 'make-callback-wrapper
           "BSP-correct callback supports exactly 1 output cell, got ~a" (length outputs)))
  (define cid-out (car outputs))
  (lambda boxed-inputs
    (define captured (box #f))
    (parameterize ([current-backend backend-hybrid]
                   [current-fire-fn-pending captured])
      (fire-fn 'hybrid))
    ;; Wrapper returns the captured value (already boxed). Kernel
    ;; pends it and schedules subscribers at the barrier.
    (cond
      [(unbox captured) => cdr]
      [else
       ;; fire-fn returned without writing. Read the live cell as a
       ;; fallback (preserves prior behavior for any fire-fn that
       ;; doesn't actually write — defensive).
       (prologos_cell_read cid-out)])))

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
   ;; Inside a fire-fn (current-fire-fn-pending set), reads from
   ;; the round's snapshot for BSP coherence. Outside, reads live.
   (lambda (net cid)
     (cond
       [(current-fire-fn-pending)
        (unbox-prologos-value (prologos_cell_read_snapshot cid))]
       [else
        (unbox-prologos-value (prologos_cell_read cid))]))

   ;; write-cell : net × cid × value → net'
   ;; Inside a fire-fn (current-fire-fn-pending set), captures the
   ;; (cid, boxed-value) pair instead of writing live. The wrapper
   ;; extracts and returns it; the kernel pends and merges at the
   ;; barrier. Outside any fire-fn, writes live (init/setup path).
   (lambda (net cid v)
     (define pend (current-fire-fn-pending))
     (cond
       [pend
        (set-box! pend (cons cid (box-prologos-value v)))
        'hybrid]
       [else
        (prologos_cell_write cid (box-prologos-value v))
        'hybrid]))

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
   ;; Hard-fails when the kernel exhausts fuel (max_rounds). The
   ;; kernel sets prof.fuel_exhausted=1 and breaks; without this
   ;; check, Racket would silently return whatever value the result
   ;; cell happened to have at that point — a silent correctness
   ;; violation. Stat key 5 = fuel_exhausted (see prologos_get_stat
   ;; in runtime/prologos-runtime-hybrid.zig).
   (lambda (net)
     (prologos_run_to_quiescence)
     (when (= (prologos_get_stat 5) 1)
       (error 'backend-hybrid
              (string-append
               "kernel fuel exhausted (max_rounds reached); "
               "result cells may be incomplete. "
               "raise the round budget via prologos_set_max_rounds "
               "or reduce the program's recursion depth.")))
     'hybrid)

   ;; fresh-net : () → net
   (lambda ()
     (reset-callback-tags!)
     (reset-handle-table!)  ;; resets kernel state too
     'hybrid)))
