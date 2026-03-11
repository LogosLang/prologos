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
;;; Phase D2: Sub-failure capture. When a speculation branch itself triggers
;;; nested speculations, the inner failures are captured as `sub-failures`
;;; of the outer failure. This builds a tree of failures for derivation chains.
;;;
;;; Phase 4b (propagator-first migration): save/restore `current-constraint-store`
;;; alongside the 6 CHAMP boxes. Audit found that `add-constraint!` in unify.rkt
;;; is reachable during speculation (via check → unify → pattern-check failure)
;;; but was not captured by save-meta-state. The constraint parameter leaked
;;; spurious constraints on failed speculation branches.
;;;
;;; Phase 5+8b+D+D2 of the type inference refactoring.
;;; Design reference: docs/tracking/2026-02-25_TYPE_INFERENCE_ON_LOGIC_ENGINE_DESIGN.md §5.5
;;;

(require "metavar-store.rkt"
         "atms.rkt"
         "performance-counters.rkt")

(provide
 ;; Core speculation helper
 with-speculative-rollback
 ;; Failure tracking
 (struct-out speculation-failure)
 current-speculation-failures
 init-speculation-tracking!
 get-speculation-failures
 get-latest-speculation-failure
 record-speculation-failure!
 ;; Phase D: ATMS integration
 current-command-atms
 ;; GDE-1: Context assumptions (user annotations)
 current-context-assumptions
 add-context-assumption!
 get-context-assumption-ids)

;; ========================================
;; Speculation failure tracking
;; ========================================

;; A recorded speculation failure.
;; Phase D: Added hypothesis-id for ATMS derivation chains.
;; Phase D2: Added support-set (ATMS nogood) and sub-failures (nested failures
;;   from speculations triggered within this branch).
;;   hypothesis-id: assumption-id | #f — the ATMS assumption for this branch
;;   support-set: hasheq | #f — the ATMS assumptions that made this branch inconsistent
;;   sub-failures: (listof speculation-failure) — nested failures from within this branch
(struct speculation-failure (label hypothesis-id support-set sub-failures) #:transparent)

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
    (set-box! atms-box (atms-empty)))
  ;; GDE-1: initialize context assumptions tracking
  (current-context-assumptions (box '())))

;; Record a speculation failure.
;; Phase D2: With optional hypothesis-id, support-set, and sub-failures.
(define (record-speculation-failure! label [hypothesis-id #f] [support-set #f] [sub-failures '()])
  (define b (current-speculation-failures))
  (when b
    (set-box! b (cons (speculation-failure label hypothesis-id support-set sub-failures) (unbox b)))))

;; Retrieve all recorded failures (chronological order, oldest first).
(define (get-speculation-failures)
  (define b (current-speculation-failures))
  (if b (reverse (unbox b)) '()))

;; Phase D2: Get the most recently recorded failure (or #f if none).
;; Useful for extracting sub-failures immediately after with-speculative-rollback.
(define (get-latest-speculation-failure)
  (define b (current-speculation-failures))
  (if (and b (pair? (unbox b)))
      (car (unbox b))  ;; newest is at the front (cons'ed on)
      #f))

;; ========================================
;; GDE-1: Context assumptions (user annotations)
;; ========================================
;; Non-speculation ATMS assumptions created for user-provided type annotations.
;; These are included in nogoods when speculation fails, enabling error messages
;; like "because: user annotated x : Nat at foo.prologos:3".
;;
;; current-context-assumptions: #f | box of (listof assumption-id)
;; Tracks assumption-ids created for user annotations in the current command.
(define current-context-assumptions (make-parameter #f))

;; Create an ATMS assumption for a user annotation.
;; name: symbol — e.g., 'def-type-annotation
;; datum: any — descriptive data (e.g., "x : Nat at line 3")
;; Returns: assumption-id | #f (if ATMS not active)
(define (add-context-assumption! name datum)
  (define atms-box (current-command-atms))
  (define ctx-box (current-context-assumptions))
  (cond
    [(and atms-box ctx-box)
     (define-values (a* aid) (atms-assume (unbox atms-box) name datum))
     (set-box! atms-box a*)
     (set-box! ctx-box (cons aid (unbox ctx-box)))
     (perf-inc-atms-hypothesis!)
     aid]
    [else #f]))

;; Get all context assumption ids for the current command.
(define (get-context-assumption-ids)
  (define ctx-box (current-context-assumptions))
  (if ctx-box (reverse (unbox ctx-box)) '()))

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
  ;; E3d: count speculation entries
  (perf-inc-speculation!)
  ;; Phase D: Create ATMS hypothesis if tracking is active
  (define-values (atms-box hyp-id)
    (let ([ab (current-command-atms)])
      (if ab
          (let-values ([(a* aid) (atms-assume (unbox ab) (string->symbol label) label)])
            (set-box! ab a*)
            (perf-inc-atms-hypothesis!)
            (values ab aid))
          (values #f #f))))
  ;; Phase D2: Snapshot failure count for sub-failure capture
  (define failures-before-count
    (let ([b (current-speculation-failures)])
      (if b (length (unbox b)) 0)))
  ;; 1. Save meta-state (immutable CHAMP snapshot — O(1) for network)
  (define saved (save-meta-state))
  ;; Phase 4b: Save constraint store (parameter, not captured by save-meta-state).
  ;; add-constraint! in unify.rkt is reachable during speculation via
  ;; check → unify → pattern-check failure. Without this, failed speculation
  ;; leaks spurious constraints to the parameter while the prop-net cell reverts.
  (define saved-constraints (current-constraint-store))
  ;; 2. Run the speculation
  (define result (thunk))
  (cond
    [(success? result) result]
    [else
     ;; 3. Restore meta-state (O(1) for network)
     (restore-meta-state! saved)
     ;; Phase 4b: Restore constraint store parameter
     (current-constraint-store saved-constraints)
     ;; Phase D2: Extract sub-failures (failures added during this thunk)
     ;; The box stores newest-first, so new failures are at the front.
     (define-values (sub-failures support-set)
       (let ([b (current-speculation-failures)])
         (cond
           [(not b) (values '() #f)]
           [else
            (define all-now (unbox b))
            (define new-count (- (length all-now) failures-before-count))
            (define subs
              (if (> new-count 0)
                  (let ([raw (for/list ([f (in-list all-now)]
                                        [_ (in-range new-count)])
                               f)])
                    (reverse raw))  ;; chronological order
                  '()))
            ;; Remove sub-failures from main list (they'll be nested)
            (when (> new-count 0)
              (set-box! b (list-tail all-now new-count)))
            ;; GDE-1: Build multi-hypothesis nogood including context assumptions.
            ;; The nogood set contains the speculation hypothesis AND any context
            ;; assumptions (user annotations), enabling diagnoses like
            ;; "because: user annotated x : Nat".
            (define ss
              (if (and atms-box hyp-id)
                  (let* ([ctx-aids (get-context-assumption-ids)]
                         [nogood-set
                          (for/fold ([s (hasheq hyp-id #t)])
                                    ([aid (in-list ctx-aids)])
                            (hash-set s aid #t))])
                    (set-box! atms-box
                              (atms-add-nogood (unbox atms-box) nogood-set))
                    (perf-inc-atms-nogood!)
                    nogood-set)
                  #f))
            (values subs ss)])))
     ;; 4. Record failure with sub-failures and support-set
     (record-speculation-failure! label hyp-id support-set sub-failures)
     #f]))
