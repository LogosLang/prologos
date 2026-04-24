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

;; NOTE on imports: this module is LIGHTWEIGHT — imports only from
;; leaf modules (propagator.rkt, decision-cell.rkt, elab-network-types.rkt,
;; hasse-registry.rkt). Does NOT import type-lattice.rkt / mult-lattice.rkt
;; which would create a cycle via reduction.rkt → metavar-store.rkt.
;;
;; Per-domain merge-fn and contradiction predicate definitions live in
;; elaborator-network.rkt (which is downstream of type-lattice.rkt and
;; provides them to init-meta-universes! via parameter injection).
(require racket/match
         "propagator.rkt"
         "decision-cell.rkt"         ;; compound-tagged-merge, tagged-cell-value, tagged-cell-read
         "elab-network-types.rkt"    ;; elab-network, elab-cell-read, elab-cell-write
         "hasse-registry.rkt")       ;; hasse-registry-handle, net-new-hasse-registry

(provide
 ;; Cell-id parameters — set by init-meta-universes!; read by call sites
 current-type-meta-universe-cell-id
 current-mult-meta-universe-cell-id
 current-level-meta-universe-cell-id
 current-session-meta-universe-cell-id
 current-worldview-hasse-registry-handle
 ;; Parameters for domain merge-fns + contradiction predicates (injected
 ;; by elaborator-network.rkt at module load time — breaks type-lattice
 ;; dependency cycle). Defaults to fallback functions.
 current-type-universe-merge
 current-mult-universe-merge
 current-level-universe-merge
 current-session-universe-merge
 current-type-universe-contradicts?
 current-mult-universe-contradicts?
 current-meta-solve-universe-contradicts?
 ;; Initialization
 init-meta-universes!
 reset-meta-universe-parameters!
 ;; Per-component access helpers (enet-level)
 compound-cell-component-ref
 compound-cell-component-write
 ;; Per-component access helpers (pnet-level — for use inside propagator
 ;; fire functions where only pnet is available; PPN 4C S2.b-iv)
 compound-cell-component-ref/pnet
 compound-cell-component-write/pnet
 resolve-worldview-bitmask/pnet
 ;; Universe-cell predicate — distinguishes universe cells from per-meta cells
 meta-universe-cell-id?)

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
;; Domain merge-fn and contradiction-predicate parameters (injected)
;; ============================================================
;; These are set by elaborator-network.rkt at module load time with
;; the real domain-specific merge-fns. Default to conservative fallbacks
;; that don't require type-lattice.rkt / mult-lattice.rkt imports.
;;
;; This breaks the import cycle:
;;   meta-universe.rkt → type-lattice.rkt → reduction.rkt → metavar-store.rkt
;;   → (would need) meta-universe.rkt
;; By deferring merge-fn construction to post-load injection, meta-universe.rkt
;; stays lightweight.

(define (default-pointwise-hasheq-merge old new)
  ;; Conservative fallback — pointwise hasheq merge without per-value lattice join.
  ;; Used only if domain-specific merges aren't injected before init.
  (cond
    [(eq? old 'infra-bot) new]
    [(eq? new 'infra-bot) old]
    [(and (hash? old) (hash? new))
     (for/fold ([acc old]) ([(k v) (in-hash new)]) (hash-set acc k v))]
    [else new]))

(define (default-no-contradicts? v) #f)

(define current-type-universe-merge (make-parameter default-pointwise-hasheq-merge))
(define current-mult-universe-merge (make-parameter default-pointwise-hasheq-merge))
(define current-level-universe-merge (make-parameter default-pointwise-hasheq-merge))
(define current-session-universe-merge (make-parameter default-pointwise-hasheq-merge))
(define current-type-universe-contradicts? (make-parameter default-no-contradicts?))
(define current-mult-universe-contradicts? (make-parameter default-no-contradicts?))
(define current-meta-solve-universe-contradicts? (make-parameter default-no-contradicts?))

;; ============================================================
;; Initialization
;; ============================================================

;; init-meta-universes! enet → enet*
;;
;; Allocates the 4 compound universe cells + shared hasse-registry-handle
;; on enet's prop-network. Sets the 5 parameters. Returns updated enet.
;;
;; ALWAYS allocates fresh cells. Does NOT short-circuit based on parameter
;; state — parameters may hold stale cell-ids from a prior elab-network
;; (parameters persist across parameterize blocks when not in the scope).
;; Callers should call `reset-meta-universe-parameters!` inside their
;; `parameterize` block if they want parameters scoped to the block; OR
;; just call `init-meta-universes!` once per fresh enet and allow the
;; per-enet cell allocation cost (4 cells + 1 hasse-registry) — cheap.
;;
;; S2.a: infrastructure; not called from production pipeline.
;; S2.b: called lazily from `fresh-meta` in metavar-store.rkt.
(define (init-meta-universes! enet)
  (define pnet (elab-network-prop-net enet))
  ;; Read injected per-domain merge-fns + contradiction predicates from parameters.
  (define type-merge (current-type-universe-merge))
  (define mult-merge (current-mult-universe-merge))
  (define level-merge (current-level-universe-merge))
  (define session-merge (current-session-universe-merge))
  (define type-cx? (current-type-universe-contradicts?))
  (define mult-cx? (current-mult-universe-contradicts?))
  (define ms-cx? (current-meta-solve-universe-contradicts?))
  ;; Allocate 4 universe cells + 1 hasse-registry
  (define-values (pnet1 type-cid)
    (net-new-cell pnet (hasheq) type-merge type-cx?))
  (define-values (pnet2 mult-cid)
    (net-new-cell pnet1 (hasheq) mult-merge mult-cx?))
  (define-values (pnet3 level-cid)
    (net-new-cell pnet2 (hasheq) level-merge ms-cx?))
  (define-values (pnet4 session-cid)
    (net-new-cell pnet3 (hasheq) session-merge ms-cx?))
  ;; Shared hasse-registry-handle for worldview Q_n subsumption.
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
  ;; Set parameters (may overwrite stale values from prior enet)
  (current-type-meta-universe-cell-id type-cid)
  (current-mult-meta-universe-cell-id mult-cid)
  (current-level-meta-universe-cell-id level-cid)
  (current-session-meta-universe-cell-id session-cid)
  (current-worldview-hasse-registry-handle handle)
  enet*)

;; Reset all 5 parameters to #f. Useful at the top of a fresh
;; `parameterize` block to ensure subsequent `init-meta-universes!`
;; calls allocate on the fresh enet rather than reusing stale cids.
;;
;; Alternative to including all 5 parameters in the driver's parameterize
;; block (which would be noisier at call sites).
(define (reset-meta-universe-parameters!)
  (current-type-meta-universe-cell-id #f)
  (current-mult-meta-universe-cell-id #f)
  (current-level-meta-universe-cell-id #f)
  (current-session-meta-universe-cell-id #f)
  (current-worldview-hasse-registry-handle #f))

;; Predicate: is this cell-id one of the 4 meta-universe cells?
;; Used by dispatching call sites (e.g., meta-solution/cell-id) to
;; decide between compound access and direct cell access paths.
(define (meta-universe-cell-id? cid)
  (or (and (current-type-meta-universe-cell-id)
           (equal? cid (current-type-meta-universe-cell-id)))
      (and (current-mult-meta-universe-cell-id)
           (equal? cid (current-mult-meta-universe-cell-id)))
      (and (current-level-meta-universe-cell-id)
           (equal? cid (current-level-meta-universe-cell-id)))
      (and (current-session-meta-universe-cell-id)
           (equal? cid (current-session-meta-universe-cell-id)))))

;; ============================================================
;; Per-component access helper
;; ============================================================

;; compound-cell-component-ref enet cell-id component-key [default]
;;   Read a component's UNWRAPPED value from a compound cell (hasheq-valued).
;;   Returns `default` (or `#f` if not provided) if the component-key
;;   is not present.
;;
;; Performs 2-level unwrap:
;;   1. Read compound hasheq from cell
;;   2. hash-ref for component-key → tagged-cell-value
;;   3. tagged-cell-read to filter by resolved worldview bitmask → unwrapped value
;;
;; This mirrors what `net-cell-read` does for per-cell tagged-cell-value
;; cells (the Step-1 substrate), but lifted to the compound-cell case.
;;
;; S2.b-iii fix (2026-04-24): bitmask resolution matches net-cell-read —
;; per-prop `current-worldview-bitmask` takes priority when non-zero;
;; otherwise fall back to the worldview-cache-cell. Without the fallback,
;; committed speculation entries (tagged with a hyp-bit in the cache) were
;; invisible to reads after `with-speculative-rollback` returned (parameter
;; reset to 0 but cache retained hyp-bit). Broke test-speculation-bridge.rkt
;; "Speculative rollback > success — keeps meta-state" until this fix.
;;
;; Complexity: O(1) cell lookup + O(log N) hasheq-ref + O(K) tagged-cell-read
;; where K = number of tagged entries (typically small, often zero).
(define compound-cell-component-ref
  (case-lambda
    [(enet cell-id component-key)
     (compound-cell-component-ref enet cell-id component-key #f)]
    [(enet cell-id component-key default)
     (define compound-val (elab-cell-read enet cell-id))
     (cond
       [(not (hash? compound-val)) default]
       [else
        (define tcv (hash-ref compound-val component-key #f))
        (cond
          [(not tcv) default]
          [(tagged-cell-value? tcv)
           (tagged-cell-read tcv (resolve-worldview-bitmask enet))]
          [else tcv])])]))

;; Resolve the effective worldview bitmask for a read, matching net-cell-read.
;; Per-prop bitmask (non-zero) takes priority; otherwise read the worldview-
;; cache-cell (committed network-wide worldview). Without this fallback,
;; committed speculation entries are invisible after with-speculative-rollback
;; returns (parameter reset to 0; cache retains hyp-bit).
(define (resolve-worldview-bitmask enet)
  (define per-prop-wv (current-worldview-bitmask))
  (cond
    [(and per-prop-wv (not (zero? per-prop-wv))) per-prop-wv]
    [else
     ;; Fallback: read worldview-cache cell for network-wide committed bitmask.
     ;; Use a defensive read — if the cache cell is missing (early init),
     ;; default to 0. elab-cell-read raises on unknown cell-ids; catch with
     ;; a handler.
     (with-handlers ([exn:fail? (lambda (_) 0)])
       (define v (elab-cell-read enet worldview-cache-cell-id))
       (if (number? v) v 0))]))

;; compound-cell-component-write enet cell-id component-key value → enet*
;;   Write a value for `component-key` into the compound cell. Wraps the
;;   value as a tagged-cell-value entry respecting the current worldview
;;   bitmask (tagged-cell-write semantics), then writes a delta hasheq to
;;   the compound cell. The cell's compound-tagged-merge handles pointwise
;;   merging with the existing hasheq contents.
;;
;; If `value` is already a tagged-cell-value, it's used as-is (no re-wrap).
;;
;; Returns updated enet (with eq?-preservation if no change occurred).
(define (compound-cell-component-write enet cell-id component-key value)
  (define wv (or (current-worldview-bitmask) 0))
  (define tcv
    (cond
      [(tagged-cell-value? value) value]
      [(zero? wv) (tagged-cell-value value '())]
      [else (tagged-cell-value 'infra-bot (list (cons wv value)))]))
  (elab-cell-write enet cell-id (hasheq component-key tcv)))

;; ============================================================
;; Per-component access helpers — pnet-level variants (PPN 4C S2.b-iv)
;; ============================================================
;;
;; The enet-level helpers above suffice when we have an elab-network in
;; hand (e.g., during elaboration top-level dispatch). But propagator
;; fire functions receive only the pnet (prop-network), not the enet.
;; Set-latch fire-once propagators and broadcast item-fns need pnet-level
;; access to compound cells.
;;
;; These are functional mirrors of the enet variants, using net-cell-read
;; / net-cell-write directly. Worldview bitmask resolution mirrors the
;; b-iii follow-up logic — per-prop bitmask priority, fallback to
;; worldview-cache-cell.
;;
;; Used by:
;;   - `add-readiness-set-latch!` helper's broadcast item-fn + fire-once
;;     fire-fns (metavar-store.rkt)
;;   - Bridge fire-fn factories (resolution.rkt) for component-keyed
;;     read/write of universe metas

;; Resolve effective worldview bitmask for a pnet-level read.
;; Mirrors `resolve-worldview-bitmask` (enet variant) but reads via
;; net-cell-read instead of elab-cell-read. Defensive against missing
;; worldview-cache cell (early init or test contexts without the cell).
(define (resolve-worldview-bitmask/pnet pnet)
  (define per-prop-wv (current-worldview-bitmask))
  (cond
    [(and per-prop-wv (not (zero? per-prop-wv))) per-prop-wv]
    [else
     (with-handlers ([exn:fail? (lambda (_) 0)])
       (define v (net-cell-read pnet worldview-cache-cell-id))
       (if (number? v) v 0))]))

;; compound-cell-component-ref/pnet pnet cell-id component-key [default]
;;   Read a component's UNWRAPPED value from a compound cell (hasheq-valued).
;;   Returns `default` (or `#f` if not provided) if the component-key is
;;   not present, the cell value isn't a hasheq, or the tagged-cell-value
;;   has no entry visible under the resolved worldview bitmask.
;;
;; Mirrors compound-cell-component-ref (enet variant) using net-cell-read.
;; Used inside propagator fire functions where only pnet is in scope.
(define compound-cell-component-ref/pnet
  (case-lambda
    [(pnet cell-id component-key)
     (compound-cell-component-ref/pnet pnet cell-id component-key #f)]
    [(pnet cell-id component-key default)
     (define compound-val (net-cell-read pnet cell-id))
     (cond
       [(not (hash? compound-val)) default]
       [else
        (define tcv (hash-ref compound-val component-key #f))
        (cond
          [(not tcv) default]
          [(tagged-cell-value? tcv)
           (tagged-cell-read tcv (resolve-worldview-bitmask/pnet pnet))]
          [else tcv])])]))

;; compound-cell-component-write/pnet pnet cell-id component-key value → pnet*
;;   Pnet-level mirror of compound-cell-component-write. Wraps `value` as
;;   tagged-cell-value entry under the current worldview, writes a delta
;;   hasheq to the compound cell. The cell's compound-tagged-merge handles
;;   pointwise merging with existing contents.
;;
;; If `value` is already a tagged-cell-value, used as-is (no re-wrap).
;; Returns updated pnet (with eq?-preservation if no change occurred).
(define (compound-cell-component-write/pnet pnet cell-id component-key value)
  (define wv (or (current-worldview-bitmask) 0))
  (define tcv
    (cond
      [(tagged-cell-value? value) value]
      [(zero? wv) (tagged-cell-value value '())]
      [else (tagged-cell-value 'infra-bot (list (cons wv value)))]))
  (net-cell-write pnet cell-id (hasheq component-key tcv)))
