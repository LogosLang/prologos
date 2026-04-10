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
;;; Phase 4b→6d→7: Constraint state is now fully captured by the propagator
;;; network snapshot (save-meta-state/restore-meta-state!). All constraint
;;; writes go to cells (Phase 6); all 8 infrastructure cells are captured
;;; by the network box snapshot (Phase 7). No separate parameter save/restore needed.
;;;
;;; Phase 5+8b+D+D2 of the type inference refactoring.
;;; Design reference: docs/tracking/2026-02-25_TYPE_INFERENCE_ON_LOGIC_ENGINE_DESIGN.md §5.5
;;;

(require "metavar-store.rkt"
         "atms.rkt"
         "propagator.rkt"
         "elaborator-network.rkt"
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
 ;; Track 4 Phase 1: Speculation stack (TMS cell navigation)
 ;; Re-exported from propagator.rkt (defined there to avoid circular deps)
 current-speculation-stack
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

;; Track 4 Phase 1: current-speculation-stack is defined in propagator.rkt
;; and re-exported here. See propagator.rkt for documentation.

;; Initialize per-command speculation tracking.
;; Phase D: Also initializes a fresh ATMS for dependency-directed errors.
;; Phase 4c: ATMS initialization is now mandatory — always creates the box
;; if absent, always resets to empty. This removes the conditional code path
;; in with-speculative-rollback and ensures every speculation branch has
;; an ATMS hypothesis for error derivation chains.
(define (init-speculation-tracking!)
  (current-speculation-failures (box '()))
  ;; Phase 4c: Always ensure ATMS box exists and is fresh.
  ;; Cheap: empty ATMS = ~3 hasheq allocations.
  (define atms-box (current-command-atms))
  (cond
    [atms-box (set-box! atms-box (make-solver-state (make-prop-network)))]
    [else (current-command-atms (box (make-solver-state (make-prop-network))))])
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
     (define-values (a* aid) (solver-state-assume (unbox atms-box) name datum))
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
  ;; Phase 4c: ATMS hypothesis is mandatory. Lazily initialize if absent
  ;; (tests using with-fresh-meta-env bypass process-command's init).
  ;; Track 6 BUG fix: lazy init replaces hard error.
  (define atms-box
    (or (current-command-atms)
        (let ([b (box (make-solver-state (make-prop-network)))])
          (current-command-atms b)
          (current-speculation-failures (box '()))
          (current-context-assumptions (box '()))
          b)))
  (define-values (_a* hyp-id)
    (let-values ([(a* aid) (solver-state-assume (unbox atms-box) (string->symbol label) label)])
      (set-box! atms-box a*)
      (perf-inc-atms-hypothesis!)
      (values a* aid)))
  ;; Track 4 Phase 5: Learned-clause pruning.
  ;; Before running the thunk, check if the new hypothesis combined with
  ;; context assumptions subsumes any known nogood. If so, skip the branch
  ;; entirely — the combination is already known to be inconsistent.
  ;; This avoids redundant type-checking work for branches proven infeasible.
  (define ctx-aids (get-context-assumption-ids))
  (define proposed-set
    (for/fold ([s (hasheq hyp-id #t)])
              ([aid (in-list ctx-aids)])
      (hash-set s aid #t)))
  (cond
    [(not (solver-state-consistent? (unbox atms-box) proposed-set))
     ;; Branch pruned by a learned nogood — skip entirely.
     (perf-inc-speculation-pruned!)
     (record-speculation-failure! label hyp-id #f '())
     #f]
    [else
     ;; Phase D2: Snapshot failure count for sub-failure capture
     (define failures-before-count
       (let ([b (current-speculation-failures)])
         (if b (length (unbox b)) 0)))
     ;; Track 8 Phase B1: save-meta-state RETIRED.
     ;; Worldview-aware reads (cell-ops.rkt) filter tagged entries by the current
     ;; speculation stack. Entries from sibling branches are invisible to reads —
     ;; no synchronous restore needed, no timing gap. The speculation stack IS the
     ;; worldview. S(-1) becomes GC (cleaning invisible entries), not correctness.
     ;;
     ;; Phase 11.4-6: UNIFIED speculation via worldview cache.
     ;; TMS path REMOVED. Tagged-cell-value is the sole mechanism.
     ;;
     ;; Write assumption's bit to the elaboration network's worldview cache.
     ;; This tags all cell writes during the thunk via net-cell-write's tagged path.
     ;; Commit = worldview cache retains the bit (no explicit operation).
     ;; Retract = clear the bit from worldview cache (one cell write).
     (define elab-net-box (current-prop-net-box))
     (define hyp-bit
       (and (assumption-id? hyp-id)
            (arithmetic-shift 1 (assumption-id-n hyp-id))))
     (when (and elab-net-box (unbox elab-net-box) hyp-bit)
       (define enet (unbox elab-net-box))
       (define pnet (elab-network-prop-net enet))
       (define current-wv (net-cell-read-raw pnet worldview-cache-cell-id))
       (define new-wv (bitwise-ior (if (number? current-wv) current-wv 0) hyp-bit))
       (define pnet* (net-cell-write pnet worldview-cache-cell-id new-wv))
       (set-box! elab-net-box (struct-copy elab-network enet [prop-net pnet*])))
     ;;
     ;; Run the speculation thunk with worldview bitmask set.
     ;; current-worldview-bitmask enables net-cell-read/write to use the bit
     ;; for tagged-cell-value operations during the thunk.
     (define result
       (if hyp-bit
           (parameterize ([current-worldview-bitmask
                           (bitwise-ior (current-worldview-bitmask) hyp-bit)])
             (thunk))
           (thunk)))
     (cond
       [(success? result)
        ;; Phase 11.4: Commit = NOTHING.
        ;; Worldview cache retains the assumption's bit. Future reads via
        ;; net-cell-read find tagged entries visible under the committed worldview.
        ;; No net-commit-assumption. No fold. O(1).
        result]
       [else
        ;; Phase 11.5: Retract = clear the bit from worldview cache.
        ;; Tagged entries from the failed branch become invisible (bitmask
        ;; not ⊆ worldview). S(-1) can clean up dead entries lazily.
        (when (and elab-net-box (unbox elab-net-box) hyp-bit)
          (define enet (unbox elab-net-box))
          (define pnet (elab-network-prop-net enet))
          (define current-wv (net-cell-read-raw pnet worldview-cache-cell-id))
          (define cleared-wv (bitwise-and (if (number? current-wv) current-wv 0)
                                           (bitwise-not hyp-bit)))
          (define pnet* (net-cell-write pnet worldview-cache-cell-id cleared-wv))
          (set-box! elab-net-box (struct-copy elab-network enet [prop-net pnet*])))
        ;; Record retraction for S(-1) GC pass.
        (record-assumption-retraction! hyp-id)
        ;; Track 8 Phase B1: restore-meta-state! RETIRED.
        ;; Worldview-aware reads filter by speculation stack — sibling branch
        ;; entries are invisible. No synchronous restore needed.
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
               ;; Phase 4c: Always record nogoods (ATMS is always available).
               (define ss
                 (let* ([ctx-aids (get-context-assumption-ids)]
                        [nogood-set
                         (for/fold ([s (hasheq hyp-id #t)])
                                   ([aid (in-list ctx-aids)])
                           (hash-set s aid #t))])
                   (set-box! atms-box
                             (solver-state-add-nogood (unbox atms-box) nogood-set))
                   (perf-inc-atms-nogood!)
                   nogood-set))
               (values subs ss)])))
        ;; 4. Record failure with sub-failures and support-set
        (record-speculation-failure! label hyp-id support-set sub-failures)
        #f])]))
