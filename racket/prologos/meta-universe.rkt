#lang racket/base

;;;
;;; meta-universe.rkt — PPN 4C Addendum 1A-iii-a-wide Step 2 (2026-04-23)
;;;
;;; Per-domain compound PU cells for meta state. Collapses the N-separate-
;;; cells pattern (per-meta cells from pre-Step-2) into 4 compound cells
;;; — one per domain — each holding `(hasheq meta-id → tagged-cell-value)`.
;;;
;;; Four universes:
;;;   type-meta-universe    : (hasheq meta-id → tagged-cell-value-of-type)
;;;   mult-meta-universe    : (hasheq meta-id → tagged-cell-value-of-mult)
;;;   level-meta-universe   : (hasheq meta-id → tagged-cell-value-of-level)
;;;   session-meta-universe : (hasheq meta-id → tagged-cell-value-of-session)
;;;
;;; Merge: `compound-tagged-merge(domain-merge)` from decision-cell.rkt.
;;; Per-domain domain-merge:
;;;   type     : type-unify-or-top (equality-enforce, PPN 4C T-3 Commit A)
;;;   mult     : mult-lattice-merge
;;;   level    : merge-meta-solve-identity (identity-or-error)
;;;   session  : merge-meta-solve-identity
;;;
;;; Classification: `'structural` — per-meta component-path dependency
;;; indexing via `:component-paths (cons universe-cell-id meta-id)`.
;;;
;;; Shared hasse-registry-handle: one `hasse-registry-handle` used by
;;; all 4 universes for worldview-bitmask Q_n subsumption lookups.
;;;
;;; API (this module):
;;;   init-meta-universes! enet → enet*
;;;     Allocates the 4 compound cells + shared handle on enet's prop-net.
;;;     Sets the four cell-id parameters + the handle parameter. Returns
;;;     updated enet. Idempotent if already initialized.
;;;
;;;   compound-cell-component-ref enet cell-id component-key [default]
;;;     Read a component's value from a compound cell. Encapsulates:
;;;       (hash-ref (elab-cell-read enet cid) component-key default)
;;;
;;; Parameters (read by consumers at call sites; set by init-meta-universes!):
;;;   current-type-meta-universe-cell-id
;;;   current-mult-meta-universe-cell-id
;;;   current-level-meta-universe-cell-id
;;;   current-session-meta-universe-cell-id
;;;   current-worldview-hasse-registry-handle
;;;
;;; NOTE: In S2.a (this commit), the infrastructure is created but NOT
;;; YET WIRED UP — `elab-fresh-meta` and friends still allocate per-meta
;;; cells. Migration happens in S2.b (type) → S2.c (mult) → S2.d (level+
;;; session). After all domains migrate, S2.e retires the old factories.
;;;
;;; Reference:
;;;   D.3 §7.5.4 Step 2 deliverables (revised 2026-04-23 to Option B)
;;;   2026-04-23_STEP2_BASELINE.md §5 hypotheses
;;;

(require racket/match
         "propagator.rkt"
         "decision-cell.rkt"         ;; compound-tagged-merge, tagged-cell-value
         "elab-network-types.rkt"    ;; elab-network, elab-cell-read, elab-cell-write
         "hasse-registry.rkt"        ;; hasse-registry-handle, net-new-hasse-registry
         "type-lattice.rkt"          ;; type-unify-or-top, type-bot
         "mult-lattice.rkt")         ;; mult-lattice-merge, mult-bot

;; Identity-or-error merge for level/session metas (inlined from
;; elaborator-network.rkt:1012-1023 to avoid a circular import — later
;; sub-phases will have elaborator-network.rkt depend on this module).
;; Semantics:
;;   'unsolved (bot) ⊔ value = value (monotone solve)
;;   value ⊔ value (equal?) = value (identity)
;;   value1 ⊔ value2 (not equal?) = 'meta-solve-contradiction (top)
;;
;; KEEP IN SYNC with elaborator-network.rkt's merge-meta-solve-identity.
;; S2.e (cleanup) may consolidate to a single definition in
;; elab-network-types.rkt once the circularity is easier to resolve.
(define (merge-meta-solve-identity old new)
  (cond
    [(eq? old 'unsolved) new]
    [(eq? new 'unsolved) old]
    [(eq? old 'meta-solve-contradiction) old]
    [(eq? new 'meta-solve-contradiction) new]
    [(equal? old new) old]
    [else 'meta-solve-contradiction]))

(provide
 ;; Cell-id parameters — set by init-meta-universes!; read by call sites
 current-type-meta-universe-cell-id
 current-mult-meta-universe-cell-id
 current-level-meta-universe-cell-id
 current-session-meta-universe-cell-id
 current-worldview-hasse-registry-handle
 ;; Initialization
 init-meta-universes!
 ;; Per-component access helper
 compound-cell-component-ref
 ;; Per-domain merge functions (for external consumers needing direct access)
 type-universe-merge
 mult-universe-merge
 level-universe-merge
 session-universe-merge)

;; ============================================================
;; Cell-id parameters
;; ============================================================
;; These hold the allocated universe cell-ids after init-meta-universes!.
;; Initial #f means "not yet initialized" — consumer should check or
;; init-meta-universes! should have been called earlier in the pipeline.
;;
;; NOTE on parameter vs struct-field placement: using parameters follows
;; the existing convention (`current-attribute-map-cell-id`). DEFERRED.md
;; captures this as PM Track 12 retirement scope (parameters → cells
;; for module loading). Step 2 follows existing convention; migration
;; happens holistically at PM Track 12.
(define current-type-meta-universe-cell-id (make-parameter #f))
(define current-mult-meta-universe-cell-id (make-parameter #f))
(define current-level-meta-universe-cell-id (make-parameter #f))
(define current-session-meta-universe-cell-id (make-parameter #f))

;; Shared hasse-registry-handle for worldview-bitmask Q_n subsumption.
;; One instance, reused by all 4 universes at read time for filtering
;; tagged entries by worldview.
(define current-worldview-hasse-registry-handle (make-parameter #f))

;; ============================================================
;; Per-domain merge functions
;; ============================================================
;; These wrap the domain-specific merge via compound-tagged-merge
;; to produce the compound cell merge function.

(define type-universe-merge (compound-tagged-merge type-unify-or-top))
(define mult-universe-merge (compound-tagged-merge mult-lattice-merge))
(define level-universe-merge (compound-tagged-merge merge-meta-solve-identity))
(define session-universe-merge (compound-tagged-merge merge-meta-solve-identity))

;; ============================================================
;; Contradiction predicates
;; ============================================================
;; Each universe contradicts if ANY component has a contradicting
;; tagged-cell-value at its base. Conservative: scan the hasheq.
;; In practice, contradiction signals are rare and this scan is cheap.

(define (type-universe-contradicts? v)
  (and (hash? v)
       (for/or ([(_k tcv) (in-hash v)])
         (and (tagged-cell-value? tcv)
              (eq? (tagged-cell-value-base tcv) 'type-top)))))

(define (mult-universe-contradicts? v)
  (and (hash? v)
       (for/or ([(_k tcv) (in-hash v)])
         (and (tagged-cell-value? tcv)
              ;; mult-lattice contradicts when base reaches mult-top
              (eq? (tagged-cell-value-base tcv) 'mult-top)))))

(define (meta-solve-universe-contradicts? v)
  ;; For level/session (identity-or-error semantics):
  ;; merge-meta-solve-identity returns 'meta-solve-contradiction on disagreement.
  (and (hash? v)
       (for/or ([(_k tcv) (in-hash v)])
         (and (tagged-cell-value? tcv)
              (eq? (tagged-cell-value-base tcv) 'meta-solve-contradiction)))))

;; ============================================================
;; Initialization
;; ============================================================

;; init-meta-universes! enet → enet*
;;
;; Allocates the 4 compound universe cells + shared hasse-registry-handle
;; on enet's prop-network. Sets the 5 parameters. Returns updated enet.
;;
;; Idempotent in the sense that re-calling with the same enet+parameters
;; already set is a no-op (parameters already hold cell-ids).
;;
;; S2.a: infrastructure only; not yet called from any production pipeline.
;; S2.b+: driver.rkt (or equivalent) calls this during elab-network setup.
(define (init-meta-universes! enet)
  ;; Check if already initialized for this enet
  (cond
    [(and (current-type-meta-universe-cell-id)
          (current-mult-meta-universe-cell-id)
          (current-level-meta-universe-cell-id)
          (current-session-meta-universe-cell-id)
          (current-worldview-hasse-registry-handle))
     enet]
    [else
     (define pnet (elab-network-prop-net enet))
     ;; Allocate 4 universe cells + 1 hasse-registry
     (define-values (pnet1 type-cid)
       (net-new-cell pnet (hasheq) type-universe-merge type-universe-contradicts?))
     (define-values (pnet2 mult-cid)
       (net-new-cell pnet1 (hasheq) mult-universe-merge mult-universe-contradicts?))
     (define-values (pnet3 level-cid)
       (net-new-cell pnet2 (hasheq) level-universe-merge meta-solve-universe-contradicts?))
     (define-values (pnet4 session-cid)
       (net-new-cell pnet3 (hasheq) session-universe-merge meta-solve-universe-contradicts?))
     ;; Shared hasse-registry-handle for worldview Q_n subsumption.
     ;; Uses the existing 'hasheq-replace domain for the registry cell merge
     ;; (registry entries are stored as position→entry hasheq).
     ;; The SUBSUME-FN is the Q_n bitmask override per hasse-registry.rkt.
     (define-values (pnet5 handle)
       (net-new-hasse-registry
        pnet4
        #:l-domain 'worldview
        #:position-fn (lambda (entry) (car entry))
        #:subsume-fn (lambda (pos query)
                       ;; Q_n subset check: bitmask intersection == query
                       (and (number? pos) (number? query)
                            (= (bitwise-and pos query) query)))))
     ;; Commit all to elab-network
     (define enet* (elab-network-rewrap enet pnet5))
     ;; Set parameters
     (current-type-meta-universe-cell-id type-cid)
     (current-mult-meta-universe-cell-id mult-cid)
     (current-level-meta-universe-cell-id level-cid)
     (current-session-meta-universe-cell-id session-cid)
     (current-worldview-hasse-registry-handle handle)
     enet*]))

;; ============================================================
;; Per-component access helper
;; ============================================================

;; compound-cell-component-ref enet cell-id component-key [default]
;;   Read a component's value from a compound cell (hasheq-valued).
;;   Returns `default` (or `#f` if not provided) if the component-key
;;   is not present.
;;
;; Encapsulates the pattern:
;;   (hash-ref (elab-cell-read enet cid) component-key default)
;;
;; Used at meta-access sites in S2.b-d to read per-meta values from
;; universe cells without call-site hasheq-ref boilerplate.
;;
;; Complexity: O(1) for the elab-cell-read (direct cell lookup) +
;; O(log N) for hasheq-ref (CHAMP lookup). N = number of live metas
;; per domain per elab-network, typically < 100.
(define compound-cell-component-ref
  (case-lambda
    [(enet cell-id component-key)
     (compound-cell-component-ref enet cell-id component-key #f)]
    [(enet cell-id component-key default)
     (define compound-val (elab-cell-read enet cell-id))
     (if (hash? compound-val)
         (hash-ref compound-val component-key default)
         default)]))
