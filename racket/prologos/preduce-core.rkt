#lang racket/base

;;;
;;; preduce-core.rkt — backend-agnostic compile-expr for PReduce-lite.
;;;
;;; PHASE 1 (this commit): defines the preduce-backend struct + accessor
;;; shorthands + current-backend parameter. No backend instances yet;
;;; no compile-expr extraction yet. Just the foundation.
;;;
;;; The backend interface threads `net` through every primitive
;;; (functional discipline preserved from preduce.rkt). For
;;; backend-racket, net is the actual prop-network struct; for
;;; backend-hybrid, net is a sentinel symbol ('hybrid). Future
;;; backend-native (SH Track 9) uses a cell-id pointing to the network
;;; value being built.
;;;
;;; Why functional threading: the SH endpoint (compiler-in-Prologos)
;;; runs compile-expr natively as a propagator program over network-
;;; valued cells. Native fire-fns can't side-effect networks they
;;; don't hold; they must take net as input and produce net' as
;;; output. Side-effecting via a current-prop-net parameter would be
;;; a dead-end at the SH endpoint. See
;;; docs/tracking/2026-05-04_PREDUCE_BACKEND_REFACTOR_DESIGN.md §2.3.
;;;
;;; Cross-references:
;;;   docs/tracking/2026-05-04_PREDUCE_BACKEND_REFACTOR_DESIGN.md (the plan)
;;;   docs/tracking/2026-05-04_PREDUCE_LITE_PIR.md (preduce.rkt's terminal state)
;;;   docs/tracking/2026-05-04_HYBRID_RUNTIME_PIR.md (hybrid kernel's terminal state)
;;;

(provide
 ;; The backend interface struct
 (struct-out preduce-backend)

 ;; Accessor shorthands — the canonical way compile-expr calls the backend
 b-alloc
 b-read
 b-write
 b-install-fire-once
 b-install-propagator
 b-run-to-quiescence
 b-fresh-net

 ;; The current-backend parameter
 current-backend

 ;; with-backend — convenience wrapper
 with-backend)

;; ============================================================
;; The backend interface
;; ============================================================
;;
;; A backend exposes seven operations. All threading discipline is
;; functional: net is taken as input and net' returned as output.
;;
;; Field signatures:
;;   alloc-cell           : net × value → (values cid net')
;;   read-cell            : net × cell-id → value
;;   write-cell           : net × cell-id × value → net'
;;   install-fire-once    : net × inputs × outputs × fire-fn → net'
;;   install-propagator   : net × inputs × outputs × fire-fn → net'
;;   run-to-quiescence    : net → net'
;;   fresh-net            : () → net
;;
;; Where:
;;   net           is the threaded network token (backend-specific shape)
;;   value         is a Racket value (preduce-bot, expr-int, expr-true, ...)
;;   cid / cell-id is a cell identifier (backend-specific shape)
;;   inputs        is (listof cid)
;;   outputs       is (listof cid)
;;   fire-fn       is (net → net')   — net-threaded; reads inputs + writes outputs
;;
;; The fire-fn signature is unchanged from preduce.rkt today. fire-fns
;; read inputs via (b-read backend net cid), write outputs via
;; (b-write backend net cid value), and return the threaded net'.
;; This means existing make-X-fire factories work as-is when the
;; backend's read/write are wired in.

(struct preduce-backend
  (alloc-cell         ;; net × value → (values cid net')
   read-cell          ;; net × cid → value
   write-cell         ;; net × cid × value → net'
   install-fire-once  ;; net × (listof cid) × (listof cid) × (net → net') → net'
   install-propagator ;; net × (listof cid) × (listof cid) × (net → net') → net'
   run-to-quiescence  ;; net → net'
   fresh-net)         ;; () → net
  #:transparent)

;; ============================================================
;; current-backend parameter
;; ============================================================
;;
;; Set by the entry-point function (preduce e in preduce.rkt;
;; preduce-hybrid e in preduce-hybrid.rkt) before calling
;; compile-expr. compile-expr and all helper fns reach into
;; (current-backend) to invoke the backend's primitives via the
;; b-* accessor shorthands below.

(define current-backend (make-parameter #f))

(define-syntax-rule (with-backend b body ...)
  (parameterize ([current-backend b]) body ...))

;; ============================================================
;; Accessor shorthands
;; ============================================================
;;
;; Mechanical wrappers around the struct accessors that automatically
;; consult (current-backend). The shorthand form:
;;
;;   (b-alloc net v)
;;
;; expands to roughly:
;;
;;   ((preduce-backend-alloc-cell (current-backend)) net v)
;;
;; The compile-expr translation guideline:
;;
;;   (net-new-cell net v preduce-merge #:domain 'preduce-value)
;;     → (b-alloc net v)
;;
;;   (net-add-fire-once-propagator net inputs outputs fire-fn)
;;     → (b-install-fire-once net inputs outputs fire-fn)
;;
;;   (net-cell-read net cid)            → (b-read net cid)
;;   (net-cell-write net cid v)         → (b-write net cid v)
;;   (run-to-quiescence net)            → (b-run-to-quiescence net)
;;
;; Phase 2 (next commit) does this rewrite mechanically across the
;; ~80 primitive call sites in preduce.rkt and moves the result to
;; preduce-core.rkt.

(define (b-alloc net v)
  ((preduce-backend-alloc-cell (current-backend)) net v))

(define (b-read net cid)
  ((preduce-backend-read-cell (current-backend)) net cid))

(define (b-write net cid v)
  ((preduce-backend-write-cell (current-backend)) net cid v))

(define (b-install-fire-once net inputs outputs fire-fn
                             #:native-op [native-op #f])
  ;; #:native-op (optional symbol) is a hint for backends that have a
  ;; corresponding kernel-native fire-fn (e.g. backend-hybrid maps
  ;; 'int-add → KERNEL-INT-ADD-TAG). When the hint matches, the backend
  ;; can install at the native dispatch tag instead of registering
  ;; another callback. backend-racket ignores the hint (no native tags
  ;; on the Racket side). Symbol values: 'int-add, 'int-sub, 'int-mul,
  ;; 'int-div, 'int-eq, 'int-lt, 'int-le, 'identity (matches the kernel's
  ;; 8 built-in fire-fns at tags 0-7).
  ((preduce-backend-install-fire-once (current-backend))
   net inputs outputs fire-fn #:native-op native-op))

(define (b-install-propagator net inputs outputs fire-fn
                              #:native-op [native-op #f])
  ((preduce-backend-install-propagator (current-backend))
   net inputs outputs fire-fn #:native-op native-op))

(define (b-run-to-quiescence net)
  ((preduce-backend-run-to-quiescence (current-backend)) net))

(define (b-fresh-net)
  ((preduce-backend-fresh-net (current-backend))))
