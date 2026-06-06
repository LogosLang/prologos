#lang racket/base

;;;
;;; PROLOGOS GLOBAL ENVIRONMENT
;;;
;;; Single resolution source: the per-file `module-network-ref` (mnr) cascade
;;; (current-file-module-network-ref). Per-file definitions live in the local
;;; mnr's per-name cells; prelude + imported definitions are reached by walking
;;; the mnr's imports cascade (PPN 4C Addendum Phase 4A.b read-flip + 4A.c
;;; share-by-reference). The legacy two-layer hasheq param stores
;;; (current-prelude-env / current-module-definitions-content /
;;; current-definition-cells-content) were RETIRED at 4A.c-iii-e-2 — the mnr
;;; cascade is now the sole source; there is no Layer-1/Layer-2 fallback.
;;;
;;; Reads:     global-env-lookup-type/value → local mnr cascade (module-network-cascading-lookup)
;;; Names:     global-env-names             → cascade names
;;; Snapshot:  global-env-snapshot          → cascade-materialize (local ∪ imports)
;;; External:  external-definitions-snapshot / external-definition-names
;;;              → prelude + imports only (EXCLUDES the file's own per-file defs)
;;; Writes:    global-env-add / -add-type-only / -remove! → the in-flight mnr (mnr-add-or-update!)
;;;

(provide global-env-lookup-type
         global-env-lookup-value
         global-env-add
         global-env-add-type-only
         prealloc-def-cell!  ;; PPN 4C Addendum Phase 4B.2-b: def-bot pre-allocation (preparse sweep)
         global-env-remove!
         global-env-names
         global-env-snapshot
         ;; PPN 4C Addendum Phase 4A.c-ii-a (D2 Path Y): external-only read source
         ;; (prelude + imported, EXCLUDING the file's own per-file defs) for the
         ;; narrowing/CFA consumers. external-definitions-snapshot = values;
         ;; external-definition-names = keys-only (hot find-fqn path).
         external-definitions-snapshot
         external-definition-names
         ;; Defn param-name registry (user-facing names for bound-arg display)
         current-defn-param-names
         register-defn-param-names!
         lookup-defn-param-names
         ;; LSP Tier 2.3: Definition location registry
         current-definition-locations
         register-definition-location!
         lookup-definition-location
         all-definition-locations)

(require "infra-cell.rkt"   ;; merge-replace, merge-hasheq-identity (Phase 1e-α split)
         "namespace.rkt"    ;; PPN 4C Addendum Phase 4A.a (2026-05-28) Q-4A.6 cycle-break: module-network-ref + APIs consumed at 4A.b read-flip
         "definition-entry.rkt")  ;; PPN 4C Addendum Phase 4B.2-b: def-bot (prealloc-def-cell!). Pure leaf → no cycle.
         ;; PPN 4C Addendum Phase 4B.1: racket/list (remove-duplicates) + racket/set
         ;; (seteq/set-add) requires retired — sole consumers were global-env-names
         ;; (cascade-only since 4A.c-iii-b) + dep-recording (retired 4B.1).


;; PPN 4C Addendum Phase 4A.c-iii-a2/a3: the box-gated per-definition
;; cell-write path RETIRED. definition-cell-write! / -remove! / -write-named!
;; (a2) were the only readers of the 3 network-access callback params
;; (current-prelude-env-prop-net-box / -prop-cell-write / -prop-new-cell);
;; a3 removed those params entirely. a1's dispatch collapse (global-env-add →
;; always-mnr) made the box path unreachable; the mnr is the sole per-name
;; authority since 4A.b.

;; PPN 4C Addendum Phase 4B.1 (2026-06-04): the Phase-3b / Track-5-Phase-4
;; definition-dependency recording machinery RETIRED OUTRIGHT (zero production
;; consumers — nothing read the dep data to drive behavior). Retired:
;; current-elaborating-name / current-definition-dependencies /
;; current-cross-module-deps params + record-definition-dependency! /
;; definition-dependencies-snapshot / record-cross-module-dep! fns + the
;; per-lookup side-effect below. The module-network-ref dep-edges field +
;; the driver dep-edge-hash builder die with it. Captures the ~170-230 ns/lookup
;; dep-recording overhead (part of the 4A+4B 2.5×). Per §18.21.17 row 4B.1.

;; ========================================
;; Lookups (per-file mnr cascade — sole resolution source)
;; ========================================

;; Lookup the type of a global definition.
;; PPN 4C Addendum Phase 4A.b (Path A read-flip): Layer 1 reads the per-file mnr
;; (authoritative) via module-network-cascading-lookup. Layer-2 fallback retired
;; at 4A.c-ii-b cut-flip; dep-recording side-effect retired at 4B.1. The mnr
;; cascade is the SOLE resolution source. #f-on-miss (NOT (void) — ~20 callers
;; test truthiness via (and entry ...)).
(define (global-env-lookup-type name)
  (define mnr (current-file-module-network-ref))
  (define cell-entry (and mnr (module-network-cascading-lookup mnr name)))
  (and cell-entry (car cell-entry)))

;; Lookup the value of a global definition (PPN 4C Addendum Phase 4A.b: mnr Layer 1).
(define (global-env-lookup-value name)
  (define mnr (current-file-module-network-ref))
  (define cell-entry (and mnr (module-network-cascading-lookup mnr name)))
  (and cell-entry (cdr cell-entry)))

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

;; PPN 4C Addendum Phase 4B.2-b (§18.21.19): pre-allocate a def-bot cell for
;; `name` in the in-flight mnr IF the name is absent. IDEMPOTENT / ORDER-
;; INSENSITIVE — it reads only cell-id-map KEY presence (never a cell VALUE)
;; to decide, so the FREE_ORDERING guard holds (pre-allocating a name set in
;; any order yields the same cells). A def-bot cell reads #f via the lookup
;; adapter (def-entry->cons: def-bot → #f) = the SAME "Unbound variable" as an
;; absent name, so pre-alloc is BEHAVIOR-PRESERVING at 4B.2 (a forward-ref
;; still errors); 4B.3's δ residuation propagator turns the def-bot read into
;; a wait. Never clobbers a real value — def-bot is the def-entry-merge
;; identity, so even a present cell is left untouched (we no-op on present
;; rather than write, avoiding a redundant struct-copy). Called by
;; preparse-expand-all's def-bot pre-alloc pass for every user def/defn name.
(define (prealloc-def-cell! name)
  (define mnr (or (current-file-module-network-ref) (make-module-network)))
  (unless (hash-ref (module-network-ref-cell-id-map mnr) name #f)
    (let-values ([(mnr* _cid) (module-network-add-definition mnr name def-bot)])
      (current-file-module-network-ref mnr*))))

;; Add a definition to the global environment.
;; PPN 4C Addendum Phase 4A.c-iii-a: dispatch COLLAPSED to always-mnr — the
;; box-gated legacy Layer-2 path is RETIRED (the 4A.c-ii-b cut-flip made the mnr
;; cascade the sole resolution source). mnr-add-or-update! lazy-inits the in-flight
;; mnr if unbound; in every real context (process-file/-command, fixtures) it is
;; bound. Degenerate bare process-string-without-(ns ...) is the LSP/REPL class
;; (PPN Track 11). Returns void (no caller uses the return).
;; The 4A.c-ii-b foreign-write-(b) helper (global-env-add-to-mnr!) folded in here:
;; the box-free global-env-add now carries the mnr write for foreign defs too.
(define (global-env-add name type value)
  (mnr-add-or-update! name (cons type value)))

;; Pre-register only the type (value = #f) for recursive definitions.
;; whnf treats #f as stuck (no unfolding), so self-references are opaque during
;; type checking. After checking, call global-env-add with the real value.
;; PPN 4C Addendum Phase 4A.c-iii-a: always-mnr (see global-env-add).
(define (global-env-add-type-only name type)
  (mnr-add-or-update! name (cons type #f)))

;; Remove a definition from all layers on failure.
;; Track 5 Phase 2: consolidates 12 inline removal sites in driver.rkt.
;; PPN 4C Addendum Phase 4A.b: Layer-1 removal drops the name from the per-file
;; mnr's cell-id-map (cell persists in the prop-net — cells are never deleted —
;; but the name→cid mapping is removed, so cascading-lookup misses). Matches the
;; pre-4A.b "remove from cells-content hash + #f sentinel" visibility semantics.
(define (global-env-remove! name)
  ;; PPN 4C Addendum Phase 4A.c-iii-b: mnr-only. The Layer-2a/2b hash-removes
  ;; retired — the mnr cascade is the sole resolution source; current-prelude-env
  ;; / -module-definitions-content are unwritten (empty) in production.
  (define mnr (current-file-module-network-ref))
  (when mnr
    (current-file-module-network-ref
     (struct-copy module-network-ref mnr
       [cell-id-map (hash-remove (module-network-ref-cell-id-map mnr) name)]))))

;; ========================================
;; Utilities (cascade views — local ∪ imports)
;; ========================================

;; List all definition names visible to the current file.
;; PPN 4C Addendum Phase 4A.c-iii-b: cascade-only (own cells + imports, prelude
;; included as an import). Layer-2 prelude/module-def keys retired (unwritten/
;; empty in production); module-network-cascade-names already de-duplicates.
(define (global-env-names)
  (define mnr (current-file-module-network-ref))
  (if mnr (module-network-cascade-names mnr) '()))

;; (global-env-import-module RETIRED at 4A-VAG, 2026-06-01: the legacy raw-hasheq
;; module-import for/fold was superseded by 4A.c's share-by-reference imports
;; (module-network-add-import); zero production callers remained.)

;; Snapshot the FULL current global env: the mnr CASCADE (own cells + imports,
;; prelude included as an import). PPN 4C Addendum Phase 4A.c-iii-b: cascade-only
;; — the Layer-2 base (current-prelude-env ∪ current-module-definitions-content)
;; retired; it has been unwritten/empty in production since the cut-flip + a1.
;; Distinct from external-definitions-snapshot, which EXCLUDES local cells (Path Y):
;; global-env-snapshot is the FULL env (own + external); external-* is external-only.
(define (global-env-snapshot)
  (define mnr (current-file-module-network-ref))
  (if mnr (module-network-cascade-materialize mnr) (hasheq)))

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
;; PPN 4C Addendum Phase 4A.c-iii-b: imports-cascade only (prelude-as-import +
;;   imported modules), excluding local cells. The Layer-2 base retired — it was
;;   unwritten/empty in production since the cut-flip + a1; the cascade is now the
;;   sole source (the consumers switched transparently at the ii-b cut-flip).

;; VALUES view. Returns: hasheq name → (cons type value).
(define (external-definitions-snapshot)
  (define mnr (current-file-module-network-ref))
  (if mnr
      (for*/fold ([acc (hasheq)])
                 ([imp (in-list (module-network-ref-imports mnr))]
                  [(k v) (in-hash (module-network-cascade-materialize imp))])
        (hash-set acc k v))
      (hasheq)))

;; KEYS-only counterpart, for the hot find-fqn-for-local-name path (needs FQN
;; keys, not values — avoids materializing cascade values). Returns: (listof
;; symbol), de-duplicated via a hasheq-as-set accumulator.
(define (external-definition-names)
  (define mnr (current-file-module-network-ref))
  (if mnr
      (hash-keys
       (for*/fold ([a (hasheq)])
                  ([imp (in-list (module-network-ref-imports mnr))]
                   [nm (in-list (module-network-cascade-names imp))])
         (hash-set a nm #t)))
      '()))

;; ========================================
;; Defn param-name registry
;; ========================================
;; Maps function name (symbol) to user-facing parameter names (listof symbol).
;; Populated during defn processing in macros.rkt.
;; Used by compute-bound-args in reduction.rkt to produce readable
;; bound-variable output (e.g., :y_ 3N) instead of internal lambda names.

(define current-defn-param-names (make-parameter (hasheq)))

(define (register-defn-param-names! name param-names)
  ;; PPN 4C Addendum Phase 4A.c-iii-a2: the Phase-3c cell dual-write retired
  ;; (the cell was write-only — RISK 4). The param hash registry stays; it is
  ;; the live source read by lookup-defn-param-names + pnet-serialize.
  (current-defn-param-names
   (hash-set (current-defn-param-names) name param-names)))

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
