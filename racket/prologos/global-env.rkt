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
;;;   Layer 2: current-global-env / current-prelude-env (hasheq: name → (cons type value))
;;;     - Prelude and module definitions (populated during module loading)
;;;     - Structurally frozen after prelude loading: global-env-add doesn't
;;;       write here when cell infrastructure is available
;;;     - Serves as fallback when definition not found in Layer 1
;;;     - Phase 3d: aliased as current-prelude-env for clarity; full rename
;;;       deferred (266 files, 1002 references, purely mechanical)
;;;
;;; The "freeze" is structural: during module loading, parameterize sets
;;; current-global-env-prop-net-box to #f, so global-env-add falls back to
;;; legacy behavior (writes to Layer 2). After module loading returns, the
;;; prop-net is set up by process-command's parameterize, so global-env-add
;;; writes to Layer 1 + cell. The legacy hasheq stops growing automatically.
;;;
;;; Read path: global-env-lookup-type/value check Layer 1 first, then Layer 2.
;;; Merge: global-env-snapshot merges both layers (per-file shadows prelude).
;;; Names: global-env-names returns union of both layers.
;;;

(provide current-global-env
         ;; Phase 3d: Alias — current-global-env holds prelude/module definitions
         ;; (Layer 2). Per-file definitions are in current-definition-cells-content
         ;; (Layer 1). Use global-env-lookup-* for reads (checks both layers).
         ;; The alias is provided for documentation clarity; the rename is deferred
         ;; to avoid touching 266 files with a purely mechanical change.
         (rename-out [current-global-env current-prelude-env])
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
         ;; Phase 3a: Per-definition cell infrastructure
         current-definition-cells-content
         current-definition-cell-ids
         current-global-env-prop-net-box
         current-global-env-prop-cell-write
         current-global-env-prop-new-cell
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
         "infra-cell.rkt")  ;; merge-replace, merge-hasheq-union

;; ========================================
;; Layer 2: Prelude/module definitions (legacy)
;; ========================================
;; Populated during module loading. Structurally frozen after prelude load.
(define current-global-env (make-parameter (hasheq)))

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
(define current-global-env-prop-net-box (make-parameter #f))
(define current-global-env-prop-cell-write (make-parameter #f))
(define current-global-env-prop-new-cell (make-parameter #f))

;; Helper: write to per-definition cell in the prop-net.
;; Creates a new cell if one doesn't exist for this name.
(define (definition-cell-write! name entry)
  (define net-box (current-global-env-prop-net-box))
  (define write-fn (current-global-env-prop-cell-write))
  (define new-cell-fn (current-global-env-prop-new-cell))
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
  (define net-box (current-global-env-prop-net-box))
  (define write-fn (current-global-env-prop-cell-write))
  (when (and net-box write-fn)
    (define cid (hash-ref (current-definition-cell-ids) name #f))
    (when cid
      (set-box! net-box (write-fn (unbox net-box) cid #f)))))

;; Helper: write to a known cell-id in the prop-net.
;; Used for param-names and other singleton cells.
(define (definition-cell-write-named! cell-id entry)
  (define net-box (current-global-env-prop-net-box))
  (define write-fn (current-global-env-prop-cell-write))
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

;; Lookup the type of a global definition
(define (global-env-lookup-type name)
  ;; Phase 3b: record dependency
  (define elab-name (current-elaborating-name))
  (when elab-name
    (record-definition-dependency! elab-name name))
  ;; Layer 1: per-file definitions
  (define cell-entry (hash-ref (current-definition-cells-content) name #f))
  (cond
    [cell-entry
     ;; Track 5 Phase 4: same-file edge
     (when elab-name
       (record-cross-module-dep! elab-name name 'same-file))
     (car cell-entry)]
    [else
     ;; Layer 2: prelude/module definitions
     ;; Track 6 Phase 7d: belt-and-suspenders — Layer 2 still primary for lookups;
     ;; current-module-definitions-content populated in parallel for validation.
     (let ([entry (hash-ref (current-global-env) name #f)])
       ;; Track 5 Phase 4: cross-module edge (source is a module, not same-file)
       (when (and entry elab-name)
         (record-cross-module-dep! elab-name name 'module))
       (and entry (car entry)))]))

;; Lookup the value of a global definition
(define (global-env-lookup-value name)
  ;; Phase 3b: record dependency
  (define elab-name (current-elaborating-name))
  (when elab-name
    (record-definition-dependency! elab-name name))
  ;; Layer 1: per-file definitions
  (define cell-entry (hash-ref (current-definition-cells-content) name #f))
  (cond
    [cell-entry
     ;; Track 5 Phase 4: same-file edge (already recorded in lookup-type)
     (cdr cell-entry)]
    [else
     ;; Layer 2: prelude/module definitions
     (let ([entry (hash-ref (current-global-env) name #f)])
       (and entry (cdr entry)))]))

;; ========================================
;; Writes (per-file → cells, module loading → legacy)
;; ========================================

;; Add a definition to the global environment.
;; When cell infrastructure is available (per-file processing):
;;   writes to current-definition-cells-content + prop-net cell.
;;   Returns env UNCHANGED (per-file def is NOT in the legacy hasheq).
;; When cell infrastructure is unavailable (module loading, tests):
;;   legacy behavior — returns updated hasheq.
(define (global-env-add env name type value)
  (define entry (cons type value))
  (cond
    [(current-global-env-prop-net-box)
     ;; Cell path: write to Layer 1 cells (callers discard return)
     (current-definition-cells-content
      (hash-set (current-definition-cells-content) name entry))
     (definition-cell-write! name entry)
     env]
    [else
     ;; Legacy path: update parameter AND return new hash (some callers
     ;; compose functionally: (global-env-add (global-env-add ...) ...))
     (define new-env (hash-set env name entry))
     (current-global-env new-env)
     new-env]))

;; Pre-register only the type (value = #f) for recursive definitions.
;; whnf treats #f as stuck (no unfolding), so self-references are opaque
;; during type checking. After checking, call global-env-add with real value.
(define (global-env-add-type-only env name type)
  (define entry (cons type #f))
  (cond
    [(current-global-env-prop-net-box)
     ;; Cell path: write to Layer 1 cells (callers discard return)
     (current-definition-cells-content
      (hash-set (current-definition-cells-content) name entry))
     (definition-cell-write! name entry)
     env]
    [else
     ;; Legacy path: update parameter AND return new hash
     (define new-env (hash-set env name entry))
     (current-global-env new-env)
     new-env]))

;; Remove a definition from both layers on failure.
;; Layer 1: remove from per-file content hash + write sentinel to cell.
;; Layer 2: remove from prelude/module env parameter.
;; Track 5 Phase 2: consolidates 12 inline removal sites in driver.rkt.
(define (global-env-remove! name)
  ;; Layer 1: per-file definitions content
  (current-definition-cells-content
   (hash-remove (current-definition-cells-content) name))
  ;; Layer 1: cell sentinel (cell stays, value = #f)
  (definition-cell-remove! name)
  ;; Layer 2: prelude/module env parameter
  (current-global-env
   (hash-remove (current-global-env) name)))

;; ========================================
;; Utilities (merge both layers)
;; ========================================

;; List all definition names (from both layers)
(define (global-env-names)
  (define prelude-keys (hash-keys (current-global-env)))
  (define file-keys (hash-keys (current-definition-cells-content)))
  (remove-duplicates (append file-keys prelude-keys) eq?))

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

;; Snapshot the current global env (merges both layers).
;; Per-file defs shadow prelude defs.
(define (global-env-snapshot)
  (define base (current-global-env))
  (define file-defs (current-definition-cells-content))
  (if (hash-empty? file-defs)
      base
      (for/fold ([env base])
                ([(k v) (in-hash file-defs)])
        (hash-set env k v))))

;; ========================================
;; Cell registration (per-command)
;; ========================================

;; Create per-definition cells in the propagator network.
;; Called per-command after reset-meta-store!, since the network is fresh.
;; Recreates cells from current-definition-cells-content (which persists).
(define (register-global-env-cells! net-box new-cell-fn)
  (when (and net-box new-cell-fn)
    ;; Note: does NOT set current-global-env-prop-net-box here.
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
