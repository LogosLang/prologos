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
;;; Phase D: Optional ATMS integration for dependency-directed error messages.
;;; When current-command-atms is set (boxed atms), each speculation branch
;;; creates an ATMS hypothesis. On failure, a nogood is recorded. This enables
;;; downstream error formatting to show derivation chains ("type mismatch
;;; because X at line Y, but Z at line W").
;;;
;;; Phase 5+8b+D of the type inference refactoring.
;;; Design reference: docs/tracking/2026-02-25_TYPE_INFERENCE_ON_LOGIC_ENGINE_DESIGN.md §5.5
;;;

(require "metavar-store.rkt"
         "atms.rkt")

(provide
 ;; Core speculation helper
 with-speculative-rollback
 ;; Failure tracking
 (struct-out speculation-failure)
 current-speculation-failures
 init-speculation-tracking!
 get-speculation-failures
 record-speculation-failure!
 ;; Phase D: ATMS integration
 current-command-atms)

;; ========================================
;; Speculation failure tracking
;; ========================================

;; A recorded speculation failure.
;; Phase D: Added optional hypothesis-id for ATMS derivation chains.
;;   hypothesis-id: assumption-id | #f — the ATMS assumption for this branch
(struct speculation-failure (label hypothesis-id) #:transparent)

;; Per-command list of speculation failures (for error enrichment).
;; #f when tracking is not active; box of (listof speculation-failure) when active.
(define current-speculation-failures (make-parameter #f))

;; Phase D: Per-command ATMS (for dependency tracking).
;; #f when not active; box of atms when active.
;; The boxed value is mutated as hypotheses and nogoods are added.
(define current-command-atms (make-parameter #f))

;; Initialize per-command speculation tracking.
;; Phase D: Also initializes a fresh ATMS when ATMS support is requested.
(define (init-speculation-tracking!)
  (current-speculation-failures (box '()))
  ;; Phase D: create a fresh ATMS per command if ATMS box exists
  (define atms-box (current-command-atms))
  (when atms-box
    (set-box! atms-box (atms-empty))))

;; Record a speculation failure.
;; Phase D: With optional hypothesis-id for ATMS tracking.
(define (record-speculation-failure! label [hypothesis-id #f])
  (define b (current-speculation-failures))
  (when b
    (set-box! b (cons (speculation-failure label hypothesis-id) (unbox b)))))

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
;; Phase D: When current-command-atms is active, creates an ATMS hypothesis
;; for each speculation branch. On failure, records a nogood (the hypothesis
;; alone is inconsistent) so that error messages can trace which assumptions
;; led to the failure.
;;
;; thunk: (→ any) — the speculative computation
;; success?: (any → boolean) — predicate for success (e.g., identity for #t/#f)
;; label: string — label for failure recording
(define (with-speculative-rollback thunk success? label)
  ;; Phase D: Create ATMS hypothesis if tracking is active
  (define-values (atms-box hyp-id)
    (let ([ab (current-command-atms)])
      (if ab
          (let-values ([(a* aid) (atms-assume (unbox ab) (string->symbol label) label)])
            (set-box! ab a*)
            (values ab aid))
          (values #f #f))))
  ;; 1. Save meta-state (immutable CHAMP snapshot — O(1) for network)
  (define saved (save-meta-state))
  ;; 2. Run the speculation
  (define result (thunk))
  (cond
    [(success? result) result]
    [else
     ;; 3. Restore meta-state (O(1) for network)
     (restore-meta-state! saved)
     ;; Phase D: Record nogood in ATMS (this hypothesis alone is inconsistent)
     (when (and atms-box hyp-id)
       (set-box! atms-box
                 (atms-add-nogood (unbox atms-box)
                                  (hasheq hyp-id #t))))
     ;; 4. Record failure with hypothesis-id
     (record-speculation-failure! label hyp-id)
     #f]))
