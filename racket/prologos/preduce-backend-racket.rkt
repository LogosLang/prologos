#lang racket/base

;;;
;;; preduce-backend-racket.rkt — Racket-side backend for preduce-core.
;;;
;;; Wraps the propagator.rkt primitives as a preduce-backend instance.
;;; net is the actual prop-network struct; the preduce-merge / preduce-bot
;;; lattice values come from preduce.rkt (re-exported here as imports
;;; from preduce-lattice.rkt — wait, lattice still lives in preduce.rkt
;;; until Phase 2c when the move happens).
;;;
;;; For now (Phase 2a), this file imports preduce.rkt's lattice values
;;; directly. After Phase 2c the lattice + helpers live in
;;; preduce-core.rkt and this file imports from there.
;;;
;;; See docs/tracking/2026-05-04_PREDUCE_BACKEND_REFACTOR_DESIGN.md.

(require (only-in "propagator.rkt"
                  make-prop-network
                  net-new-cell
                  net-cell-read
                  net-cell-write
                  net-add-propagator
                  net-add-fire-once-propagator
                  run-to-quiescence)
         "preduce-core.rkt")

(provide
 backend-racket
 ;; Re-exported for convenience
 (struct-out preduce-backend))

;; preduce-merge / preduce-bot live in preduce.rkt today. Phase 2c
;; moves them to preduce-core.rkt. Until then, this module exposes
;; an init-fn that the Racket entry point calls with a merge-fn and
;; default value, so we don't introduce a circular dep.
;;
;; backend-racket-with-lattice : merge-fn × bot-value → preduce-backend
;;
;; This deferred-binding shape means preduce.rkt constructs the actual
;; backend instance using its own preduce-merge + preduce-bot, and
;; passes it via parameterize to compile-expr.

(define (backend-racket-with-lattice merge-fn bot-value initial-fuel)
  (preduce-backend
   ;; alloc-cell : net × value → (values cid net')
   ;;   Wraps net-new-cell with the preduce-value domain and merge-fn.
   ;;   Note: net-new-cell returns (values net cid); we swap to (values cid net).
   (lambda (net v)
     (define-values (net* cid)
       (net-new-cell net v merge-fn #:domain 'preduce-value))
     (values cid net*))

   ;; read-cell : net × cid → value
   net-cell-read

   ;; write-cell : net × cid × value → net'
   net-cell-write

   ;; install-fire-once : net × inputs × outputs × fire-fn × #:native-op → net'
   ;;   net-add-fire-once-propagator returns (values net pid); we discard pid.
   ;;   #:native-op hint is ignored: Racket-side has no kernel-native tags.
   (lambda (net inputs outputs fire-fn #:native-op [_op #f])
     (define-values (net* _pid)
       (net-add-fire-once-propagator net inputs outputs fire-fn))
     net*)

   ;; install-propagator : same shape; #:native-op ignored.
   (lambda (net inputs outputs fire-fn #:native-op [_op #f])
     (define-values (net* _pid)
       (net-add-propagator net inputs outputs fire-fn))
     net*)

   ;; run-to-quiescence : net → net'
   run-to-quiescence

   ;; fresh-net : () → net
   ;;   Constructs a fresh prop-network with the given fuel budget.
   (lambda ()
     (make-prop-network initial-fuel))))

;; backend-racket : preduce-backend
;;   Default Racket-backend instance, lazy in the lattice + fuel.
;;   Phase 2c will pre-bind these once preduce-core.rkt owns the
;;   lattice. For Phase 2a/b, callers construct their own backend
;;   via backend-racket-with-lattice.
;;
;;   This default instance is NOT usable directly — it's a sentinel
;;   that signals "lattice not bound yet." preduce.rkt's entry point
;;   constructs the real instance via backend-racket-with-lattice.
(define backend-racket
  (preduce-backend
   (lambda (net v) (error 'backend-racket "lattice not bound; use backend-racket-with-lattice"))
   (lambda (net cid) (error 'backend-racket "lattice not bound"))
   (lambda (net cid v) (error 'backend-racket "lattice not bound"))
   (lambda (net inputs outputs fire-fn #:native-op [_ #f]) (error 'backend-racket "lattice not bound"))
   (lambda (net inputs outputs fire-fn #:native-op [_ #f]) (error 'backend-racket "lattice not bound"))
   (lambda (net) (error 'backend-racket "lattice not bound"))
   (lambda () (error 'backend-racket "lattice not bound"))))

(provide backend-racket-with-lattice)
