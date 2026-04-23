#lang racket/base

;;;
;;; elab-speculation-bridge.rkt — Speculation via tagged-cell-value substrate
;;;                                + elab-net snapshot for off-network residue
;;;
;;; `with-speculative-rollback` provides the speculative-check pattern for
;;; typing-core.rkt + qtt.rkt + typing-errors.rkt use cases: run a predicate
;;; thunk under a fresh ATMS assumption; on success, commit the assumption
;;; (visibility preserved via worldview-cache); on failure, record a nogood
;;; and restore pre-speculation state.
;;;
;;; =============================================================================
;;; ARCHITECTURAL STATE (post PPN 4C Track 1A-iii-a-wide Step 1, 2026-04-22)
;;; =============================================================================
;;;
;;; On-network worldview tagging (PERMANENT mechanism, BSP-LE 2/2B substrate):
;;; - Each speculation creates an ATMS hypothesis → bit in worldview bitmask
;;; - Writes during the thunk are tagged with the speculation's bit via
;;;   `current-worldview-bitmask` parameterize + tagged-cell-value write path
;;; - On success: bit committed to `worldview-cache-cell-id` → tagged entries
;;;   remain visible under worldviews containing the bit
;;; - On failure: nogood recorded in solver-state; bit cleared from
;;;   worldview-cache → tagged entries structurally invisible
;;; - This is the "ATMS branch exploration" substrate that also serves
;;;   NAF, union-type checking, and (future) Phase 3 fork-on-union
;;;
;;; Off-network `elab-net` snapshot (SCAFFOLDING, retirement plan below):
;;; - elab-network struct fields include meta-info CHAMP, constraint store,
;;;   id-map, cell-info — these DON'T participate in worldview filtering
;;;   because they're not cell-values
;;; - On failure, snapshot/restore reverts these off-network fields
;;; - This scaffolding exists ONLY to cover those off-network stores
;;; - SCAFFOLDING RETIREMENT PLAN:
;;;     * main-track Phase 4 (PPN 4C) retires meta-info CHAMP; migrates meta
;;;       storage to AttributeMap :type facet (on-network, worldview-filtered)
;;;     * PM Track 12 retires constraint store + id-map (on-network registries
;;;       via cell-based module loading; identity-or-error semantics per
;;;       submodule-scope; see PM 12 design inputs from PPN 4C 1e-α and
;;;       1A-iii-a-wide Step 1 + T-1)
;;;   When BOTH land, `with-speculative-rollback` itself retires; callers
;;;   migrate to `speculate label thunk` form (pure assumption-tagged write
;;;   + nogood recording, no snapshot). Expected: ~20-30 min mechanical
;;;   sub-phase at the end of PM 12 per PM 12 master §Track 12 light cleanup.
;;;
;;; =============================================================================
;;;
;;; ATMS integration (Phase D): each speculation creates an ATMS hypothesis;
;;; failures record nogoods for error derivation chains ("type mismatch because
;;; X at line Y, but Z at line W"). Sub-failure capture (Phase D2) builds tree
;;; of nested failures.
;;;
;;; Design references:
;;;   PPN 4C D.3 §7.5.10 — charter-alignment: this mechanism as stepping stone
;;;   PPN 4C D.3 §7.5.11 — Step 1 delivery (substrate migration)
;;;   PPN 4C D.3 §6.3 — Phase 4 meta-info CHAMP retirement (next gate)
;;;   PM Track 12 master — scaffolding retirement gate + PM 12 light cleanup
;;;   2026-02-25_TYPE_INFERENCE_ON_LOGIC_ENGINE_DESIGN.md §5.5 — original design
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

;; Historical note: earlier versions re-exported current-speculation-stack
;; from propagator.rkt. Both TMS mechanism and current-speculation-stack
;; RETIRED 2026-04-22 (PPN 4C 1A-iii-a-wide Step 1 sub-phases S1.a-d).
;; Speculation-tagging now flows exclusively through current-worldview-bitmask
;; + worldview-cache-cell-id + tagged-cell-value (BSP-LE 2/2B substrate).

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
     ;; =============================================================
     ;; Speculation flow — 3 stages (see module docstring for architecture)
     ;; =============================================================
     ;;
     ;; Stage 1 — Save elab-net snapshot (SCAFFOLDING).
     ;;   Covers off-network stores (meta-info CHAMP, constraint store, id-map).
     ;;   These retire in main-track Phase 4 (meta-info CHAMP) and PM Track 12
     ;;   (constraint store, id-map). When both land, this snapshot + restore
     ;;   block can be deleted entirely; `with-speculative-rollback` itself
     ;;   retires and is replaced by a `speculate` form with pure ATMS
     ;;   tagging + nogood recording.
     ;;
     ;; Stage 2 — Write hypothesis bit to worldview-cache (ON-NETWORK, permanent).
     ;;   Tags all writes during the thunk via net-cell-write's tagged-cell-value
     ;;   path. Commit = cache retains the bit (no explicit op). Retract =
     ;;   clear bit + replay snapshot-restore.
     ;;
     ;; Stage 3 — Run thunk under the full worldview bitmask (ON-NETWORK).
     ;;   Parameterize combines prior-committed bits + outer-active + hyp-bit
     ;;   so the thunk sees all currently-valid tagged entries.
     ;;
     ;; Stage 1 — scaffolding snapshot:
     (define elab-net-box (current-prop-net-box))
     (define saved-enet (and elab-net-box (unbox elab-net-box)))
     (define hyp-bit
       (and (assumption-id? hyp-id)
            (arithmetic-shift 1 (assumption-id-n hyp-id))))
     ;; Compute the FULL worldview bitmask (prior committed bits + hyp-bit)
     ;; to parameterize for the thunk. PPN 4C 1A-iii-a-wide Step 1 Sub-phase
     ;; S1.a (2026-04-22): fix for the 4th "accidentally-load-bearing mechanism"
     ;; finding. Pre-S1.a, type meta cells were TMS-wrapped; writes during
     ;; speculation went through `tms-write` with empty stack which updated
     ;; BASE (not a tagged entry), making prior-committed speculation bits
     ;; trivially visible regardless of the bitmask parameterize. Under
     ;; tagged-cell-value (S1.a), the bitmask parameterize ACTIVATES — but
     ;; using ONLY hyp-bit would OVERRIDE the worldview-cache in net-cell-read
     ;; (propagator.rkt:968-975 per-propagator-bitmask-takes-priority design
     ;; for BSP-LE 2/2B clause-propagator isolation), losing visibility of
     ;; prior-committed speculation results (e.g., back-to-back `map-assoc`
     ;; where the first commit solved a meta). Fix: parameterize with the
     ;; FULL worldview = prior committed + outer-active + hyp-bit, so reads
     ;; during the thunk see all currently-valid tagged entries. Per-site
     ;; correction, NOT global read-logic change — preserves clause-propagator
     ;; isolation semantic.
     (define new-wv-cache-value 0)
     (when (and elab-net-box (unbox elab-net-box) hyp-bit)
       (define enet (unbox elab-net-box))
       (define pnet (elab-network-prop-net enet))
       (define current-wv (net-cell-read-raw pnet worldview-cache-cell-id))
       (define new-wv (bitwise-ior (if (number? current-wv) current-wv 0) hyp-bit))
       (set! new-wv-cache-value new-wv)
       (define pnet* (net-cell-write pnet worldview-cache-cell-id new-wv))
       (set-box! elab-net-box (struct-copy elab-network enet [prop-net pnet*])))
     ;;
     ;; Run the speculation thunk with FULL worldview bitmask set.
     ;; Reads during thunk filter tagged entries by (committed | outer-active |
     ;; hyp-bit); prior-committed speculative writes remain visible.
     (define result
       (if hyp-bit
           (parameterize ([current-worldview-bitmask
                           (bitwise-ior (or (current-worldview-bitmask) 0)
                                        new-wv-cache-value)])
             (thunk))
           (thunk)))
     (cond
       [(success? result)
        ;; Commit = NOTHING at the network level.
        ;; Worldview-cache retains the hypothesis bit (set in Stage 2).
        ;; Future reads via net-cell-read filter tagged entries under the
        ;; committed worldview. O(1), structural. No fold, no explicit commit.
        result]
       [else
        ;; Retract = restore elab-net snapshot (SCAFFOLDING for off-network
        ;; stores — meta-info CHAMP, constraint store, id-map) + clear the
        ;; hypothesis bit from worldview-cache (makes tagged entries
        ;; structurally invisible). Record nogood for ATMS.
        ;; Post-Phase-4 + post-PM-12, the snapshot-restore block retires;
        ;; retract becomes just `record-nogood + clear-bit` (pure on-network).
        (when (and elab-net-box saved-enet)
          (set-box! elab-net-box saved-enet))
        ;; Clear the assumption's bit from the restored network's worldview cache
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
