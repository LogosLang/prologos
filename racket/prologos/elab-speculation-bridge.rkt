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
    [atms-box (set-box! atms-box (atms-empty))]
    [else (current-command-atms (box (atms-empty)))])
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
  ;; Phase 4c: ATMS hypothesis is mandatory. Lazily initialize if absent
  ;; (tests using with-fresh-meta-env bypass process-command's init).
  ;; Track 6 BUG fix: lazy init replaces hard error.
  (define atms-box
    (or (current-command-atms)
        (let ([b (box (atms-empty))])
          (current-command-atms b)
          (current-speculation-failures (box '()))
          (current-context-assumptions (box '()))
          b)))
  (define-values (_a* hyp-id)
    (let-values ([(a* aid) (atms-assume (unbox atms-box) (string->symbol label) label)])
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
    [(not (atms-consistent? (unbox atms-box) proposed-set))
     ;; Branch pruned by a learned nogood — skip entirely.
     (perf-inc-speculation-pruned!)
     (record-speculation-failure! label hyp-id #f '())
     #f]
    [else
     ;; Phase D2: Snapshot failure count for sub-failure capture
     (define failures-before-count
       (let ([b (current-speculation-failures)])
         (if b (length (unbox b)) 0)))
     ;; 1. Save meta-state (immutable CHAMP snapshot — O(1) for network)
     ;; Track 1 Phase 6d: Network is always present (network-everywhere).
     ;; save-meta-state captures the elab-network (prop-network + structural state).
     ;; restore-meta-state! reverts all cell contents AND structural state
     ;; (meta-info, id-map, next-meta-id) which aren't TMS-managed.
     ;; TMS retraction handles cell branch cleanup; restore handles structural state.
     (define saved (save-meta-state))
     ;; 2. Run the speculation with TMS stack push (Track 6 Phases 2–4)
     ;; Push hyp-id onto the speculation stack so cell writes are routed to
     ;; TMS branches at this depth. On success, commit-on-success promotes
     ;; branch values to base. On failure, TMS retraction removes the branch,
     ;; then network-box restore handles rollback (belt-and-suspenders).
     ;;
     ;; Track 6 Phase 4: Push at ALL depths (nested speculation too).
     ;; The tms-read nested fallback bug is now fixed — on branch miss,
     ;; tms-read checks outer hypotheses instead of falling to base.
     (define result
       (parameterize ([current-speculation-stack
                       (cons hyp-id (current-speculation-stack))])
         (thunk)))
     (cond
       [(success? result)
        ;; Track 6 Phase 3: Commit-on-success — promote TMS branch values to base.
        ;; All cell writes during the thunk went to TMS branches at hyp-id depth.
        ;; Now promote them so depth-0 reads see the committed values.
        ;; The box holds an elab-network; unwrap to prop-network, commit, rewrap.
        (define net-box (current-prop-net-box))
        (when net-box
          (define enet (unbox net-box))
          (define committed-pnet
            (net-commit-assumption (elab-network-prop-net enet) hyp-id))
          (set-box! net-box (struct-copy elab-network enet [prop-net committed-pnet])))
        result]
       [else
        ;; Track 6 Phase 4: TMS retraction — remove the failed assumption's branches.
        ;; This cleans TMS branch metadata. restore-meta-state! follows to handle
        ;; full structural rollback (meta-info, id-map, infrastructure cells).
        ;; Phase 5b finding: TMS retraction alone is insufficient because:
        ;; - Infrastructure cells (constraint store, unsolved-metas) use accumulative
        ;;   merge, not TMS branches — constraints added during speculation aren't retracted
        ;; - meta-info CHAMP in elab-network isn't TMS-managed — solved metas persist
        ;; Full retirement requires making all speculation-scoped state TMS-aware.
        (let ([net-box (current-prop-net-box)])
          (when net-box
            (define enet (unbox net-box))
            (define retracted-pnet
              (net-retract-assumption (elab-network-prop-net enet) hyp-id))
            (set-box! net-box (struct-copy elab-network enet [prop-net retracted-pnet]))))
        ;; 3. Restore meta-state — handles structural state that TMS doesn't cover
        (restore-meta-state! saved)
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
                             (atms-add-nogood (unbox atms-box) nogood-set))
                   (perf-inc-atms-nogood!)
                   nogood-set))
               (values subs ss)])))
        ;; 4. Record failure with sub-failures and support-set
        (record-speculation-failure! label hyp-id support-set sub-failures)
        #f])]))
