#lang racket/base

;;;
;;; elab-speculation-bridge.rkt — Bridge between imperative speculation and propagator network
;;;
;;; Wraps the existing save-meta-state/restore-meta-state! mechanism with
;;; network fork/restore and ATMS failure tracking. At each speculation site
;;; in typing-core.rkt and qtt.rkt, `with-speculative-rollback` replaces the
;;; manual save/restore pattern, adding:
;;;
;;;   1. Shadow network fork/restore (precise state — no leaks)
;;;   2. Speculation failure recording (for future error enrichment)
;;;
;;; Phase 5 of the type inference refactoring.
;;; Design reference: docs/tracking/2026-02-25_TYPE_INFERENCE_ON_LOGIC_ENGINE_DESIGN.md §5.5
;;;

(require "metavar-store.rkt"
         "elab-shadow.rkt")

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
  (define box (current-speculation-failures))
  (when box
    (set-box! box (cons (speculation-failure label) (unbox box)))))

;; Retrieve all recorded failures (newest first).
(define (get-speculation-failures)
  (define box (current-speculation-failures))
  (if box (reverse (unbox box)) '()))

;; ========================================
;; Core speculation helper
;; ========================================

;; Speculative rollback with network fork/restore.
;;
;; Saves meta-state + forks shadow network. Runs thunk.
;; If (success? result) → returns result, keeping all mutations.
;; Otherwise → restores meta-state + network, records failure, returns #f.
;;
;; thunk: (→ any) — the speculative computation
;; success?: (any → boolean) — predicate for success (e.g., identity for #t/#f)
;; label: string — label for failure recording
(define (with-speculative-rollback thunk success? label)
  ;; 1. Save meta-state (imperative snapshot)
  (define saved (save-meta-state))
  ;; 2. Fork shadow network (O(1) — just read the persistent CHAMP value)
  (define net-box (current-shadow-network))
  (define enet-saved (and net-box (unbox net-box)))
  ;; 3. Run the speculation
  (define result (thunk))
  (cond
    [(success? result) result]
    [else
     ;; 4. Restore meta-state
     (restore-meta-state! saved)
     ;; 5. Restore network to fork point
     (when enet-saved (set-box! net-box enet-saved))
     ;; 6. Record failure
     (record-speculation-failure! label)
     #f]))
