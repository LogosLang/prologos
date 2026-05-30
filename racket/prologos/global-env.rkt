#lang racket/base

;;;
;;; PROLOGOS GLOBAL ENVIRONMENT
;;;
;;; Two-layer architecture (Propagator-First Migration Phase 3):
;;;
;;;   Layer 1: current-definition-cells-content (hasheq: name → (cons type value))
;;;     - Per-file definitions created during elaboration
;;;     - Persistent across commands within a file; reset per-file/per-test
;;;     - Authoritative for per-file defs — lookups check here FIRST
;;;     - Each definition backed by a cell in the propagator network
;;;     - Phase 3b: lookups record dependency edges in current-definition-dependencies
;;;
;;;   Layer 2: current-prelude-env (hasheq: name → (cons type value))
;;;     - Prelude and module definitions (populated during module loading)
;;;     - Structurally frozen after prelude loading: global-env-add doesn't
;;;       write here when cell infrastructure is available
;;;     - Serves as fallback when definition not found in Layer 1
;;;     - Track 6 Phase 9: renamed from current-global-env to current-prelude-env
;;;
;;; The "freeze" is structural: during module loading, parameterize sets
;;; current-prelude-env-prop-net-box to #f, so global-env-add falls back to
;;; legacy behavior (writes to Layer 2). After module loading returns, the
;;; prop-net is set up by process-command's parameterize, so global-env-add
;;; writes to Layer 1 + cell. The legacy hasheq stops growing automatically.
;;;
;;; Read path: global-env-lookup-type/value check Layer 1 first, then Layer 2.
;;; Merge: global-env-snapshot merges both layers (per-file shadows prelude).
;;; Names: global-env-names returns union of both layers.
;;;

(provide current-prelude-env
         ;; Track 6 Phase 9: canonical name. Holds prelude/module definitions (Layer 2).
         ;; Per-file definitions are in current-definition-cells-content (Layer 1).
         ;; Use global-env-lookup-* for reads (checks both layers).
         ;; Track 6 Phase 7d: Module definitions sourced from module-network-ref
         current-module-definitions-content
         global-env-lookup-type
         global-env-lookup-value
         global-env-add
         global-env-add-type-only
         global-env-remove!
         global-env-names
         global-env-import-module
         global-env-snapshot
         ;; PPN 4C Addendum Phase 4A.c-ii-a (D2 Path Y): external-only read source
         ;; (prelude + imported, EXCLUDING the file's own per-file defs) for the
         ;; narrowing/CFA consumers. external-definitions-snapshot = values;
         ;; external-definition-names = keys-only (hot find-fqn path).
         external-definitions-snapshot
         external-definition-names
         ;; Phase 3a: Per-definition cell infrastructure
         current-definition-cells-content
         current-definition-cell-ids
         current-prelude-env-prop-net-box
         current-prelude-env-prop-cell-write
         current-prelude-env-prop-new-cell
         register-global-env-cells!
         ;; Phase 3b: Definition dependency recording
         current-elaborating-name
         current-definition-dependencies
         definition-dependencies-snapshot
         ;; Defn param-name registry (user-facing names for bound-arg display)
         current-defn-param-names
         current-defn-param-names-cell-id
         register-defn-param-names!
         lookup-defn-param-names
         ;; Track 5 Phase 4: Cross-module dependency edges
         current-cross-module-deps
         record-cross-module-dep!
         ;; LSP Tier 2.3: Definition location registry
         current-definition-locations
         register-definition-location!
         lookup-definition-location
         all-definition-locations)

(require racket/list        ;; remove-duplicates
         racket/set         ;; seteq, set-add (Phase 3b dependency recording)
         "infra-cell.rkt"   ;; merge-replace, merge-hasheq-identity (Phase 1e-α split)
         "namespace.rkt")   ;; PPN 4C Addendum Phase 4A.a (2026-05-28) Q-4A.6 cycle-break: module-network-ref + APIs consumed at 4A.b read-flip

;; ========================================
;; Layer 2: Prelude/module definitions (legacy)
;; ========================================
;; Populated during module loading. Structurally frozen after prelude load.
(define current-prelude-env (make-parameter (hasheq)))

;; ========================================
;; Module definitions (Track 6 Phase 7d)
;; ========================================
;; Persistent hasheq: name → (cons type value) populated from module-network-ref
;; during module import. Analogous to current-definition-cells-content but for
;; module/prelude defs. Sourced from Track 5's module network cells — the module
;; network is the authoritative source; this is the materialized lookup cache.
;; Persists across commands within a file; reset per-file/per-test.
(define current-module-definitions-content (make-parameter (hasheq)))

;; ========================================
;; Layer 1: Per-file definitions (Phase 3a)
;; ========================================
;; Persistent across commands within a file. Reset per-file (and per-test).
(define current-definition-cells-content (make-parameter (hasheq)))

;; Per-command cell-ids in the prop-net (recreated each command).
;; Cells exist for future propagator wiring (LSP dependency propagation).
(define current-definition-cell-ids (make-parameter (hasheq)))

;; Callback parameters for network access (set by driver.rkt).
(define current-prelude-env-prop-net-box (make-parameter #f))
(define current-prelude-env-prop-cell-write (make-parameter #f))
(define current-prelude-env-prop-new-cell (make-parameter #f))

;; Helper: write to per-definition cell in the prop-net.
;; Creates a new cell if one doesn't exist for this name.
(define (definition-cell-write! name entry)
  (define net-box (current-prelude-env-prop-net-box))
  (define write-fn (current-prelude-env-prop-cell-write))
  (define new-cell-fn (current-prelude-env-prop-new-cell))
  (when (and net-box write-fn)
    (define cid (hash-ref (current-definition-cell-ids) name #f))
    (cond
      [cid
       ;; Update existing cell (e.g., type-only → type+value)
       (set-box! net-box (write-fn (unbox net-box) cid entry))]
      [new-cell-fn
       ;; Create new cell for new definition
       (define-values (enet* new-cid) (new-cell-fn (unbox net-box) entry merge-replace))
       (current-definition-cell-ids
        (hash-set (current-definition-cell-ids) name new-cid))
       (set-box! net-box enet*)])))

;; Helper: write sentinel (#f) to a definition cell in the prop-net.
;; The cell itself persists (cells are never deleted); the #f sentinel
;; tells global-env-lookup-type/value to return #f (definition invisible).
;; Track 5 Phase 2: extracted for failure cleanup consolidation.
(define (definition-cell-remove! name)
  (define net-box (current-prelude-env-prop-net-box))
  (define write-fn (current-prelude-env-prop-cell-write))
  (when (and net-box write-fn)
    (define cid (hash-ref (current-definition-cell-ids) name #f))
    (when cid
      (set-box! net-box (write-fn (unbox net-box) cid #f)))))

;; Helper: write to a known cell-id in the prop-net.
;; Used for param-names and other singleton cells.
(define (definition-cell-write-named! cell-id entry)
  (define net-box (current-prelude-env-prop-net-box))
  (define write-fn (current-prelude-env-prop-cell-write))
  (when (and net-box write-fn cell-id)
    (set-box! net-box (write-fn (unbox net-box) cell-id entry))))

;; ========================================
;; Phase 3b: Definition dependency recording
;; ========================================
;; When elaboration references a prior definition via lookup, record a
;; dependency edge. Informational in batch mode; enables selective
;; re-elaboration in LSP.

;; Set to the name of the definition currently being elaborated.
;; When set, lookups record dependency edges.
(define current-elaborating-name (make-parameter #f))

;; Persistent across commands within a file (same lifecycle as
;; current-definition-cells-content). Maps name → (seteq dep-name).
(define current-definition-dependencies (make-parameter (hasheq)))

;; Record that `elaborating-name` depends on `dep-name`.
(define (record-definition-dependency! elaborating-name dep-name)
  (when (not (eq? elaborating-name dep-name))  ;; skip self-references
    (define deps (current-definition-dependencies))
    (define existing (hash-ref deps elaborating-name (seteq)))
    (current-definition-dependencies
     (hash-set deps elaborating-name (set-add existing dep-name)))))

;; Snapshot for inspection/testing.
(define (definition-dependencies-snapshot)
  (current-definition-dependencies))

;; Track 5 Phase 4: Cross-module dependency edge recording.
;; Accumulates (list dep-name src-origin) pairs where src-origin is 'same-file
;; or a module namespace symbol. Persistent across commands within a file.
;; Used by driver.rkt to populate module-network-ref dep-edges at file end.
(define current-cross-module-deps (make-parameter '()))

;; Record a cross-module dependency: current definition depends on `dep-name`
;; which was resolved from `source` ('same-file or a module namespace symbol).
(define (record-cross-module-dep! elab-name dep-name source)
  (when (and elab-name (not (eq? elab-name dep-name)))
    (current-cross-module-deps
     (cons (list elab-name dep-name source)
           (current-cross-module-deps)))))

;; ========================================
;; Lookups (two-layer: per-file first, prelude fallback)
;; ========================================

;; Lookup the type of a global definition.
;; PPN 4C Addendum Phase 4A.b (Path A read-flip): Layer 1 reads the per-file mnr
;; (authoritative) via module-network-cascading-lookup, replacing the off-network
;; current-definition-cells-content hasheq. Dep-recording side-effect PRESERVED
;; (Q-4A.2: retires at 4B, not 4A). Layer 2 (module-defs + prelude) unchanged
;; (retires at 4A.c imports migration). cascading-lookup imports are empty until
;; 4A.c, so a Layer-1 hit is same-file (matches pre-4A.b semantics).
(define (global-env-lookup-type name)
  ;; Phase 3b: record dependency
  (define elab-name (current-elaborating-name))
  (when elab-name
    (record-definition-dependency! elab-name name))
  ;; Layer 1: per-file mnr cells (authoritative read source)
  (define mnr (current-file-module-network-ref))
  (define cell-entry (and mnr (module-network-cascading-lookup mnr name)))
  (cond
    [cell-entry
     ;; Track 5 Phase 4: same-file edge
     (when elab-name
       (record-cross-module-dep! elab-name name 'same-file))
     (car cell-entry)]
    [else
     ;; Layer 2: module definitions + prelude (unchanged; retires at 4A.c)
     (define entry (or (hash-ref (current-module-definitions-content) name #f)
                       (hash-ref (current-prelude-env) name #f)))
     ;; Track 5 Phase 4: cross-module edge (source is a module, not same-file)
     (when (and entry elab-name)
       (record-cross-module-dep! elab-name name 'module))
     (and entry (car entry))]))

;; Lookup the value of a global definition (PPN 4C Addendum Phase 4A.b: mnr Layer 1).
(define (global-env-lookup-value name)
  ;; Phase 3b: record dependency
  (define elab-name (current-elaborating-name))
  (when elab-name
    (record-definition-dependency! elab-name name))
  ;; Layer 1: per-file mnr cells
  (define mnr (current-file-module-network-ref))
  (define cell-entry (and mnr (module-network-cascading-lookup mnr name)))
  (cond
    [cell-entry
     ;; Track 5 Phase 4: same-file edge (already recorded in lookup-type)
     (cdr cell-entry)]
    [else
     ;; Layer 2: module definitions + prelude (unchanged; retires at 4A.c)
     (define entry (or (hash-ref (current-module-definitions-content) name #f)
                       (hash-ref (current-prelude-env) name #f)))
     (and entry (cdr entry))]))

;; ========================================
;; Writes (per-file → cells, module loading → legacy)
;; ========================================

;; PPN 4C Addendum Phase 4A.b (Path A): add-or-update a definition in the
;; per-file mnr. Create cell if name absent; else update existing cell via
;; module-network-write (merge-replace = last-write-wins, EXACTLY matching the
;; pre-4A.b current-definition-cells-content hash-set semantics → probe-diff=0).
;; Values stay (cons type value) at 4A.b (def-entry shape migration is 4A.b-ii).
(define (mnr-add-or-update! entry-name entry)
  (define mnr (or (current-file-module-network-ref) (make-module-network)))
  (current-file-module-network-ref
   (if (hash-ref (module-network-ref-cell-id-map mnr) entry-name #f)
       (module-network-write mnr entry-name entry)
       (let-values ([(mnr* _cid) (module-network-add-definition mnr entry-name entry)])
         mnr*))))

;; Add a definition to the global environment.
;; PPN 4C Addendum Phase 4A.b: cell path writes to the per-file mnr (authoritative
;; Layer-1 source), NOT current-definition-cells-content (dead at 4A.b, removed
;; at 4A.c) and NOT the ephemeral box cell (definition-cell-write! retires at 4A.c).
;; Returns env UNCHANGED (cell-path callers discard return). Dispatch on the box
;; (current-prelude-env-prop-net-box) is UNCHANGED — same contexts activate the
;; cell path as pre-4A.b; only the write TARGET flips (mnr vs cells-content+box-cell).
;; Legacy path (no cell infra — bootstrap/some tests): update prelude-env hash.
(define (global-env-add env name type value)
  (define entry (cons type value))
  (cond
    [(current-prelude-env-prop-net-box)
     (mnr-add-or-update! name entry)
     env]
    [else
     ;; Legacy path: update parameter AND return new hash (some callers
     ;; compose functionally: (global-env-add (global-env-add ...) ...))
     (define new-env (hash-set env name entry))
     (current-prelude-env new-env)
     new-env]))

;; Pre-register only the type (value = #f) for recursive definitions.
;; whnf treats #f as stuck (no unfolding), so self-references are opaque
;; during type checking. After checking, call global-env-add with real value.
;; PPN 4C Addendum Phase 4A.b: writes (cons type #f) to the mnr (set-once
;; commit of the real value happens via a later global-env-add → merge-replace).
;; STAYS as a separate API at 4A.b; retires (subsumed by STRUCTURAL) at 4A.b-ii.
(define (global-env-add-type-only env name type)
  (define entry (cons type #f))
  (cond
    [(current-prelude-env-prop-net-box)
     (mnr-add-or-update! name entry)
     env]
    [else
     ;; Legacy path: update parameter AND return new hash
     (define new-env (hash-set env name entry))
     (current-prelude-env new-env)
     new-env]))

;; Remove a definition from all layers on failure.
;; Track 5 Phase 2: consolidates 12 inline removal sites in driver.rkt.
;; PPN 4C Addendum Phase 4A.b: Layer-1 removal drops the name from the per-file
;; mnr's cell-id-map (cell persists in the prop-net — cells are never deleted —
;; but the name→cid mapping is removed, so cascading-lookup misses). Matches the
;; pre-4A.b "remove from cells-content hash + #f sentinel" visibility semantics.
(define (global-env-remove! name)
  ;; Layer 1: per-file mnr — remove the name→cid mapping
  (define mnr (current-file-module-network-ref))
  (when mnr
    (current-file-module-network-ref
     (struct-copy module-network-ref mnr
       [cell-id-map (hash-remove (module-network-ref-cell-id-map mnr) name)])))
  ;; Track 6 Phase 7d: remove from module-definitions-content (Layer 2a)
  (current-module-definitions-content
   (hash-remove (current-module-definitions-content) name))
  ;; Layer 2b: prelude env parameter
  (current-prelude-env
   (hash-remove (current-prelude-env) name)))

;; ========================================
;; Utilities (merge both layers)
;; ========================================

;; List all definition names (from all layers)
;; PPN 4C Addendum Phase 4A.b: Layer-1 file-keys come from the per-file mnr's
;; cell-id-map (names with cells), replacing current-definition-cells-content keys.
(define (global-env-names)
  (define prelude-keys (hash-keys (current-prelude-env)))
  (define module-keys (hash-keys (current-module-definitions-content)))
  (define mnr (current-file-module-network-ref))
  (define file-keys (if mnr (hash-keys (module-network-ref-cell-id-map mnr)) '()))
  ;; Priority: file-keys > module-keys > prelude-keys
  (remove-duplicates (append file-keys module-keys prelude-keys) eq?))

;; Import a module's exported definitions into a global env.
;; Takes a qualify-fn that maps (short-name, namespace-sym) → fqn-symbol.
;; The module-exports is a list of short-name symbols.
;; The module-env is a hasheq of fqn → (cons type value).
;; Note: This operates on raw hasheqs and is used during module loading
;; (legacy path). Per-file definitions don't go through this path.
(define (global-env-import-module env module-exports module-env qualify-fn module-ns)
  (for/fold ([e env])
            ([short-name (in-list module-exports)])
    (define fqn (qualify-fn short-name module-ns))
    (define entry (hash-ref module-env fqn #f))
    (if entry (hash-set e fqn entry) e)))

;; Snapshot the current global env (merges all layers).
;; Priority: per-file defs > module defs > legacy prelude defs.
;; PPN 4C Addendum Phase 4A.b: per-file defs materialize from the mnr cells,
;; replacing current-definition-cells-content.
;; PPN 4C Addendum Phase 4A.c-ii-b RF-1 (§18.18.6.8): materialize the mnr CASCADE
;; (own cells + imports), NOT own-cells-only — so the snapshot stays fat (prelude +
;; transitive imports) after the 4A.c-ii-b copy loops retire empties Layer-2.
;; Behavior-preserving pre-cutover (imports empty → cascade = own-cells-only).
;; Distinct from external-definitions-snapshot, which EXCLUDES local cells (Path Y):
;; global-env-snapshot is the FULL env (own + external); external-* is external-only.
(define (global-env-snapshot)
  (define base (current-prelude-env))
  ;; Track 6 Phase 7d: merge module-definitions-content
  (define mod-defs (current-module-definitions-content))
  (define with-mods
    (if (hash-empty? mod-defs)
        base
        (for/fold ([env base])
                  ([(k v) (in-hash mod-defs)])
          (hash-set env k v))))
  (define mnr (current-file-module-network-ref))
  (define file-defs (if mnr (module-network-cascade-materialize mnr) (hasheq)))
  (if (hash-empty? file-defs)
      with-mods
      (for/fold ([env with-mods])
                ([(k v) (in-hash file-defs)])
        (hash-set env k v))))

;; ========================================
;; External definitions view (PPN 4C Addendum Phase 4A.c-ii-a, D2 Path Y)
;; ========================================
;; The definitions visible to the current file FROM OUTSIDE it: prelude +
;; imported modules, EXCLUDING the file's own per-file defs (which live in the
;; local mnr's own cell-id-map, Layer 1). This is the read source for the
;; narrowing/CFA consumers that today iterate (current-prelude-env) and must
;; NOT see the file's own (mid-elaboration) definitions:
;;   constraint-propagators.rkt find-fqn-for-local-name → external-definition-names (keys)
;;   cfa-analysis.rkt cfa-collect-constraints + cfa-get-candidates-for-arity → external-definitions-snapshot (values)
;;
;; Pre-4A.c-ii-b: current-file-mnr.imports is EMPTY → these return the Layer-2
;;   base (current-prelude-env ∪ current-module-definitions-content), which =
;;   today's (current-prelude-env) view (module-defs keys ⊆ prelude keys; values
;;   identical for shared keys). Behavior-preserving (the ii-a gate).
;; Post-4A.c-ii-b: imports populated + Layer-2 retired → these return the
;;   imports cascade (prelude-as-import + imported), still excluding local cells.
;;   Transparent switch — no consumer edit at ii-b.

;; VALUES view. Returns: hasheq name → (cons type value).
(define (external-definitions-snapshot)
  (define mnr (current-file-module-network-ref))
  ;; Layer-2 base (retires at 4A.c-ii-b): prelude, then module-defs overlaid
  (define base
    (for/fold ([acc (current-prelude-env)])
              ([(k v) (in-hash (current-module-definitions-content))])
      (hash-set acc k v)))
  ;; imports cascade (empty pre-flip; authoritative post-flip) overlays base
  (if mnr
      (for*/fold ([acc base])
                 ([imp (in-list (module-network-ref-imports mnr))]
                  [(k v) (in-hash (module-network-cascade-materialize imp))])
        (hash-set acc k v))
      base))

;; KEYS-only counterpart, for the hot find-fqn-for-local-name path (needs FQN
;; keys, not values — avoids materializing cascade values). Returns: (listof
;; symbol), de-duplicated via a hasheq-as-set accumulator.
(define (external-definition-names)
  (define mnr (current-file-module-network-ref))
  ;; Layer-2 keys (retires at 4A.c-ii-b)
  (define acc1
    (for/fold ([a (hasheq)]) ([k (in-hash-keys (current-prelude-env))]) (hash-set a k #t)))
  (define acc2
    (for/fold ([a acc1]) ([k (in-hash-keys (current-module-definitions-content))]) (hash-set a k #t)))
  ;; imports cascade names (empty pre-flip; authoritative post-flip)
  (define acc3
    (if mnr
        (for*/fold ([a acc2])
                   ([imp (in-list (module-network-ref-imports mnr))]
                    [nm (in-list (module-network-cascade-names imp))])
          (hash-set a nm #t))
        acc2))
  (hash-keys acc3))

;; ========================================
;; Cell registration (per-command)
;; ========================================

;; Create per-definition cells in the propagator network.
;; Called per-command after reset-meta-store!, since the network is fresh.
;; Recreates cells from current-definition-cells-content (which persists).
(define (register-global-env-cells! net-box new-cell-fn)
  (when (and net-box new-cell-fn)
    ;; Note: does NOT set current-prelude-env-prop-net-box here.
    ;; driver.rkt sets it in process-command's parameterize block so
    ;; it auto-reverts when the command finishes (preventing test leakage).
    (define cells-content (current-definition-cells-content))
    (define-values (final-enet final-ids)
      (for/fold ([enet (unbox net-box)] [ids (hasheq)])
                ([(name entry) (in-hash cells-content)])
        (define-values (enet* cid) (new-cell-fn enet entry merge-replace))
        (values enet* (hash-set ids name cid))))
    (current-definition-cell-ids final-ids)
    ;; Phase 3c: Create defn-param-names cell
    (define-values (enet-pn pn-cid) (new-cell-fn final-enet (current-defn-param-names) merge-replace))
    (current-defn-param-names-cell-id pn-cid)
    (set-box! net-box enet-pn)))

;; ========================================
;; Defn param-name registry
;; ========================================
;; Maps function name (symbol) to user-facing parameter names (listof symbol).
;; Populated during defn processing in macros.rkt.
;; Used by compute-bound-args in reduction.rkt to produce readable
;; bound-variable output (e.g., :y_ 3N) instead of internal lambda names.

(define current-defn-param-names (make-parameter (hasheq)))
(define current-defn-param-names-cell-id (make-parameter #f))

(define (register-defn-param-names! name param-names)
  (current-defn-param-names
   (hash-set (current-defn-param-names) name param-names))
  ;; Phase 3c: dual-write to cell
  (definition-cell-write-named! (current-defn-param-names-cell-id)
                                (current-defn-param-names)))

(define (lookup-defn-param-names name)
  (hash-ref (current-defn-param-names) name #f))

;; ========================================
;; Definition location registry (LSP Tier 2.3)
;; ========================================
;; Maps definition name (symbol) to source location.
;; Populated during process-def in driver.rkt.
;; Used by the LSP server for textDocument/definition (go-to-definition).

(define current-definition-locations (make-parameter (hasheq)))

(define (register-definition-location! name srcloc)
  (current-definition-locations
   (hash-set (current-definition-locations) name srcloc)))

(define (lookup-definition-location name)
  (hash-ref (current-definition-locations) name #f))

(define (all-definition-locations)
  (current-definition-locations))
