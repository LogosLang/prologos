#lang racket/base

;;;
;;; elab-speculation-bridge.rkt — Bridge between imperative speculation and propagator network
;;;
;;; Wraps the existing save-meta-state/restore-meta-state! mechanism with
;;; failure tracking. At each speculation site in typing-core.rkt and qtt.rkt,
;;; `with-speculative-rollback` replaces the manual save/restore pattern.
;;;
;;; Since Phase 8b, save-meta-state captures both the propagator network and
;;; the hash-based meta-info in O(1) (immutable CHAMP snapshots). Rollback
;;; restores the network state precisely — no shadow forking needed.
;;;
;;; Phase 5+8b of the type inference refactoring.
;;; Design reference: docs/tracking/2026-02-25_TYPE_INFERENCE_ON_LOGIC_ENGINE_DESIGN.md §5.5
;;;

(require "metavar-store.rkt")

(provide
 ;; Core speculation helper
 with-speculative-rollback
 ;; Failure tracking
 (struct-out speculation-failure)
 current-speculation-failures
 init-speculation-tracking!
 get-speculation-failures
 record-speculation-failure!)

;; ========================================
;; Speculation failure tracking
;; ========================================

;; A recorded speculation failure.
(struct speculation-failure (label) #:transparent)

;; Per-command list of speculation failures (for error enrichment).
;; #f when tracking is not active; box of (listof speculation-failure) when active.
(define current-speculation-failures (make-parameter #f))

;; Initialize per-command speculation tracking.
(define (init-speculation-tracking!)
  (current-speculation-failures (box '())))

;; Record a speculation failure.
(define (record-speculation-failure! label)
  (define b (current-speculation-failures))
  (when b
    (set-box! b (cons (speculation-failure label) (unbox b)))))

;; Retrieve all recorded failures (newest first).
(define (get-speculation-failures)
  (define b (current-speculation-failures))
  (if b (reverse (unbox b)) '()))

;; ========================================
;; Core speculation helper
;; ========================================

;; Speculative rollback with O(1) immutable snapshot.
;;
;; Saves meta-state (O(1) for propagator network, O(N) for hash compat).
;; Runs thunk.
;; If (success? result) → returns result, keeping all mutations.
;; Otherwise → restores meta-state, records failure, returns #f.
;;
;; thunk: (→ any) — the speculative computation
;; success?: (any → boolean) — predicate for success (e.g., identity for #t/#f)
;; label: string — label for failure recording
(define (with-speculative-rollback thunk success? label)
  ;; 1. Save meta-state (immutable CHAMP snapshot — O(1) for network)
  (define saved (save-meta-state))
  ;; 2. Run the speculation
  (define result (thunk))
  (cond
    [(success? result) result]
    [else
     ;; 3. Restore meta-state (O(1) for network)
     (restore-meta-state! saved)
     ;; 4. Record failure
     (record-speculation-failure! label)
     #f]))
