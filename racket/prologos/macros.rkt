#lang racket/base

;;;
;;; PROLOGOS MACROS
;;; Two-layer macro expansion system:
;;;
;;; Layer 1 (pre-parse): S-expression datum → datum rewrites.
;;;   - defmacro: user-defined pattern-template macros
;;;   - Built-in: let, do, if, deftype
;;;   Runs BEFORE the parser, on raw S-expression datums.
;;;
;;; Layer 2 (post-parse): surface AST → surface AST transforms.
;;;   - defn: sugared function definition with parameter name list
;;;   - the-fn: annotated lambda shorthand
;;;   - Implicit eval: bare top-level expressions wrapped in surf-eval
;;;   Runs AFTER parsing, on surf-* structs.
;;;

(require racket/match
         racket/list
         racket/string
         racket/set
         "syntax.rkt"           ;; Phase 7: expr-fvar?, expr-app? for capability-type-expr?
         "surface-syntax.rkt"
         "source-location.rkt"
         "errors.rkt"
         "namespace.rkt"
         "global-env.rkt"
         "infra-cell.rkt"        ;; Phase 2a: merge functions for registry cells
         "propagator.rkt"        ;; Track 7 Phase 2: net-new-cell, net-cell-read, net-cell-write for persistent registry
         "metavar-store.rkt")    ;; Track 7 Phase 2: current-persistent-registry-net-box

(provide ;; Post-parse (layer 2)
         expand-top-level
         expand-expression
         current-macro-registry
         read-macro-registry
         register-macro!
         ;; Pre-parse (layer 1)
         current-preparse-registry
         read-preparse-registry
         register-preparse-macro!
         preparse-expand-form
         preparse-expand-all
         preparse-expand-single
         preparse-expand-1
         preparse-expand-full
         preparse-macro
         preparse-macro?
         expand-lseq-literal
         pattern-var?
         datum-match
         datum-subst
         process-defmacro
         process-deftype
         process-data
         process-trait
         process-impl
         ;; Constructor metadata registry (for reduce)
         current-ctor-registry
         read-ctor-registry
         current-type-meta
         read-type-meta
         ctor-meta
         ctor-meta?
         ctor-meta-type-name
         ctor-meta-params
         ctor-meta-field-types
         ctor-meta-is-recursive
         ctor-meta-branch-index
         register-ctor!
         lookup-ctor
         lookup-type-ctors
         ;; Trait metadata registry
         current-trait-registry
         read-trait-registry
         trait-meta
         trait-meta?
         trait-meta-name
         trait-meta-params
         trait-meta-methods
         trait-meta-metadata
         trait-method
         trait-method?
         trait-method-name
         trait-method-type-datum
         register-trait!
         lookup-trait
         parse-trait-method
         ;; Impl metadata registry
         current-impl-registry
         impl-entry
         impl-entry?
         impl-entry-trait-name
         impl-entry-type-args
         impl-entry-dict-name
         register-impl!
         lookup-impl
         read-impl-registry
         ;; Parametric impl metadata registry
         current-param-impl-registry
         read-param-impl-registry
         param-impl-entry
         param-impl-entry?
         param-impl-entry-trait-name
         param-impl-entry-type-pattern
         param-impl-entry-pattern-vars
         param-impl-entry-dict-name
         param-impl-entry-where-constraints
         register-param-impl!
         lookup-param-impls
         ;; Bundle registry
         current-bundle-registry
         read-bundle-registry
         bundle-entry
         bundle-entry?
         bundle-entry-name
         bundle-entry-params
         bundle-entry-constraints
         bundle-entry-metadata
         register-bundle!
         lookup-bundle
         process-bundle
         expand-bundle-constraints
         ;; Subtype registry (Phase E)
         current-subtype-registry
         read-subtype-registry
         register-subtype-pair!
         subtype-pair?
         all-supertypes
         all-subtypes
         ;; Coercion registry (Phase E)
         current-coercion-registry
         read-coercion-registry
         register-coercion!
         lookup-coercion
         ;; Capability registry (Capabilities as Types)
         current-capability-registry
         read-capability-registry
         (struct-out capability-meta)
         register-capability!
         lookup-capability
         capability-type?
         capability-type-expr?
         ;; Capability scope for lexical resolution (Phase 4)
         current-capability-scope
         find-capability-in-scope
         ;; HKT-8: Specialization registry
         current-specialization-registry
         read-specialization-registry
         specialization-entry
         specialization-entry?
         specialization-entry-generic-name
         specialization-entry-type-con
         specialization-entry-specialized-name
         register-specialization!
         lookup-specialization
         process-specialize
         ;; Shared
         extract-pi-binders
         ;; Sibling let merging (for testing)
         merge-sibling-lets
         ;; Foreign escape block combining (for testing)
         combine-foreign-blocks
         ;; HKT brace-param parsing + kind propagation
         parse-brace-param-list
         group-brace-params
         propagate-kinds-from-constraints
         extract-inline-constraints
         datum->kind-string
         ;; HKT-3: Auto-registration of trait dict defs
         maybe-register-trait-dict-def
         ;; HKT-4: Overlap detection helpers (for testing)
         parametric-impls-could-overlap?
         format-param-impl-entry
         ;; Schema registry
         read-schema-registry
         current-schema-registry
         schema-field
         schema-field?
         schema-field-keyword
         schema-field-type-datum
         schema-field-default-val
         schema-field-check-pred
         schema-entry
         schema-entry?
         schema-entry-name
         schema-entry-fields
         schema-entry-closed?
         schema-entry-srcloc
         register-schema!
         lookup-schema
         parse-schema-fields
         ;; Selection registry
         current-selection-registry
         read-selection-registry
         selection-entry
         selection-entry?
         selection-entry-name
         selection-entry-schema-name
         selection-entry-requires-paths
         selection-entry-provides-paths
         selection-entry-includes-names
         selection-entry-srcloc
         register-selection!
         lookup-selection
         ;; Session WS desugaring (exported for testing)
         desugar-session-ws
         ;; Process WS desugaring (S2c, exported for testing)
         desugar-defproc-ws
         desugar-proc-ws
         ;; Session registry
         current-session-registry
         read-session-registry
         session-entry
         session-entry?
         session-entry-name
         session-entry-session-type
         session-entry-srcloc
         register-session!
         lookup-session
         ;; Strategy registry (Phase S6)
         current-strategy-registry
         read-strategy-registry
         strategy-entry
         strategy-entry?
         strategy-entry-name
         strategy-entry-properties
         strategy-entry-srcloc
         register-strategy!
         lookup-strategy
         strategy-defaults
         valid-strategy-keys
         parse-strategy-properties
         ;; Process registry (Phase S7c)
         current-process-registry
         read-process-registry
         process-entry
         process-entry?
         process-entry-name
         process-entry-session-type
         process-entry-proc-body
         process-entry-caps
         process-entry-srcloc
         register-process!
         lookup-process
         ;; Spec store
         current-spec-store
         read-spec-store
         current-propagated-specs
         read-propagated-specs
         spec-propagated?
         spec-entry
         spec-entry?
         spec-entry-type-datums
         spec-entry-docstring
         spec-entry-multi?
         spec-entry-srcloc
         spec-entry-where-constraints
         spec-entry-implicit-binders
         spec-entry-rest-type
         spec-entry-metadata
         register-spec!
         lookup-spec
         process-spec
         extract-where-clause
         ;; Phase 1b: Auto-implicit detection
         capitalized-symbol?
         collect-free-type-vars-from-datums
         known-type-name?
         maybe-inject-where
         param-type->angle-type
         ;; Property registry
         current-property-store
         read-property-store
         property-entry
         property-entry?
         property-entry-name
         property-entry-params
         property-entry-where-clauses
         property-entry-includes
         property-entry-clauses
         property-entry-metadata
         property-clause
         property-clause?
         property-clause-name
         property-clause-forall-binders
         property-clause-holds-expr
         register-property!
         lookup-property
         flatten-property
         spec-properties
         spec-examples
         spec-doc
         spec-deprecated
         trait-doc
         trait-deprecated
         bundle-doc
         trait-laws-flattened
         deduplicate-binders
         parse-spec-metadata
         process-property
         ;; Functor registry
         current-functor-store
         read-functor-store
         functor-entry
         functor-entry?
         functor-entry-name
         functor-entry-params
         functor-entry-unfolds
         functor-entry-metadata
         register-functor!
         lookup-functor
         process-functor
         ;; Trait laws
         current-trait-laws
         read-trait-laws
         register-trait-laws!
         lookup-trait-laws
         ;; Implicit map, dot-access, and introspection helpers
         rewrite-implicit-map
         rewrite-dot-access
         rewrite-nil-dot-access
         rewrite-infix-operators
         maybe-inject-spec
         maybe-inject-spec-def
         expand-def-assign
         datum->datum-expr
         qq->datum-expr
         keyword-like-symbol?
         ;; Phase 2a/2b: Propagator-first migration — registry cell infrastructure
         current-macros-prop-net-box
         current-macros-prop-cell-write
         current-macros-prop-cell-read
         current-schema-registry-cell-id
         current-ctor-registry-cell-id
         current-type-meta-cell-id
         current-subtype-registry-cell-id
         current-coercion-registry-cell-id
         current-capability-registry-cell-id
         current-property-store-cell-id
         current-functor-store-cell-id
         ;; Phase 2b: Trait + instance registry cell IDs
         current-trait-registry-cell-id
         current-trait-laws-cell-id
         current-impl-registry-cell-id
         current-param-impl-registry-cell-id
         current-bundle-registry-cell-id
         current-specialization-registry-cell-id
         current-selection-registry-cell-id
         current-session-registry-cell-id
         ;; Phase 2c: Remaining registry cell IDs
         current-preparse-registry-cell-id
         current-spec-store-cell-id
         current-propagated-specs-cell-id
         current-strategy-registry-cell-id
         current-process-registry-cell-id
         current-user-precedence-groups-cell-id
         current-user-operators-cell-id
         current-macro-registry-cell-id
         macros-cell-write!
         register-macros-cells!
         init-macros-cells!
         ;; Track 6 Phase 6: Snapshot/restore for batch-worker
         save-macros-cell-ids
         restore-macros-cell-ids!
         save-macros-registry-snapshot
         restore-macros-registry-snapshot!
         ;; Mixfix / precedence groups (Phase 2)
         current-user-precedence-groups
         read-user-precedence-groups
         current-user-operators
         read-user-operators
         register-precedence-group!
         lookup-precedence-group
         register-user-operator!
         process-precedence-group
         prec-group
         prec-group?
         prec-group-name
         prec-group-assoc
         prec-group-tighter-than
         op-info
         op-info?
         op-info-symbol
         op-info-fn-name
         op-info-group
         op-info-assoc
         op-info-left-bp
         op-info-right-bp
         op-info-swap?
         builtin-operators
         builtin-precedence-groups
         effective-operator-table
         effective-precedence-groups
         pratt-parse)

;; ================================================================
;; LAYER 1: PRE-PARSE MACRO SYSTEM
;; ================================================================

;; ========================================
;; Pre-parse macro struct and registry
;; ========================================

;; A pre-parse macro: pattern-template rewrite on S-expression datums
(struct preparse-macro (name pattern template) #:transparent)

;; Registry: symbol → (or/c preparse-macro? procedure?)
;;   preparse-macro = user-defined pattern-template (from defmacro)
;;   procedure = built-in procedural macro (e.g., let, do, if)
(define current-preparse-registry (make-parameter (hasheq)))

(define (register-preparse-macro! name entry)
  (current-preparse-registry
   (hash-set (current-preparse-registry) name entry))
  ;; Phase 2c: dual-write to cell
  (macros-cell-write! (current-preparse-registry-cell-id) (hasheq name entry)))

;; Track 3 Phase 3: cell-primary reader for preparse registry
(define (read-preparse-registry)
  (or (macros-cell-read-safe (current-preparse-registry-cell-id)) (current-preparse-registry)))

;; ========================================
;; Spec store: type signatures for named definitions
;; ========================================

;; A spec entry: stores a type specification for a named definition.
;; type-datums: list of type-token-lists. Single-arity: ((Nat Nat -> Nat)).
;;              Multi-arity: ((Nat Nat -> Nat) (Nat -> Nat)).
;; docstring: (or/c string? #f)
;; multi?: #t if declared with | branches
;; srcloc: source location of the spec form
;; where-constraints: (listof (listof symbol)) — trait constraints from `where` clause.
;;   e.g., ((Eq A) (Ord A)) for `where (Eq A) (Ord A)`.
;;   '() if no where clause. Constraints are prepended to type-datums as leading params.
;; - rest-type: #f for normal functions, or the element type datum for variadic functions.
;;   e.g., 'Nat for `spec add Nat ... -> Nat`, meaning the last param is List Nat.
(struct spec-entry (type-datums docstring multi? srcloc where-constraints implicit-binders rest-type metadata) #:transparent)

;; Spec store: symbol → spec-entry
(define current-spec-store (make-parameter (hasheq)))

;; Set of spec names that were propagated from required modules
;; (not defined in the current module). Used to allow inline type
;; annotations to silently override propagated specs.
(define current-propagated-specs (make-parameter (seteq)))

(define (register-spec! name entry)
  (current-spec-store (hash-set (current-spec-store) name entry))
  ;; Phase 2c: dual-write to cell
  (macros-cell-write! (current-spec-store-cell-id) (hasheq name entry)))

;; Track 3 Phase 3: cell-primary reader for spec store
(define (read-spec-store)
  (or (macros-cell-read-safe (current-spec-store-cell-id)) (current-spec-store)))

(define (lookup-spec name)
  (hash-ref (read-spec-store) name #f))

;; Track 3 Phase 3: cell-primary reader for propagated specs
(define (read-propagated-specs)
  (or (macros-cell-read-safe (current-propagated-specs-cell-id)) (current-propagated-specs)))

(define (spec-propagated? name)
  (set-member? (read-propagated-specs) name))

;; ========================================
;; Phase 2a: Propagator-First Migration — Registry Cell Infrastructure
;; ========================================
;;
;; Callback parameters for network access. Set by driver.rkt to the same
;; elab-network box and write function used by metavar-store.rkt. This breaks
;; the circular dependency: macros.rkt cannot import metavar-store.rkt or
;; elaborator-network.rkt, so network operations are injected via callbacks.
;;
;; Design: dual-write pattern — each register-X! writes to both the legacy
;; Racket parameter AND the propagator cell. Reads still go through the legacy
;; parameter for compatibility. The cell shadow enables LSP incremental
;; re-elaboration and reactive propagation in future phases.

;; Box of elab-network | #f — same box as current-prop-net-box in metavar-store
(define current-macros-prop-net-box (make-parameter #f))
;; (enet cell-id value → enet*) — same as elab-cell-write
(define current-macros-prop-cell-write (make-parameter #f))
(define current-macros-prop-cell-read (make-parameter #f))   ;; (enet cell-id → value)

;; Track 6 Phase 8d: current-macros-in-elaboration? removed. Guard was eliminated
;; in Phase 8b — cell reads are unconditional (net-box scoped to command parameterize).

;; Track 3: Safe cell-primary read helper.
;; Track 7 Phase 2: reads from persistent registry network directly.
;; Track 7 Phase 6e: returns cell content or #f (no parameter fallback).
;; Callers provide their own default when #f is returned.
(define (macros-cell-read-safe cid)
  (define prn-box (current-persistent-registry-net-box))
  (if (and cid prn-box)
      (with-handlers ([exn:fail? (λ (_) #f)])
        (net-cell-read (unbox prn-box) cid))
      #f))

;; Cell-id parameters for each registry (set by register-macros-cells!).
;; When #f, dual-write is skipped (legacy-only mode).
(define current-schema-registry-cell-id (make-parameter #f))
(define current-ctor-registry-cell-id (make-parameter #f))
(define current-type-meta-cell-id (make-parameter #f))
(define current-subtype-registry-cell-id (make-parameter #f))
(define current-coercion-registry-cell-id (make-parameter #f))
(define current-capability-registry-cell-id (make-parameter #f))
(define current-property-store-cell-id (make-parameter #f))
(define current-functor-store-cell-id (make-parameter #f))
;; Phase 2b: Trait + instance registry cell IDs
(define current-trait-registry-cell-id (make-parameter #f))
(define current-trait-laws-cell-id (make-parameter #f))
(define current-impl-registry-cell-id (make-parameter #f))
(define current-param-impl-registry-cell-id (make-parameter #f))
(define current-bundle-registry-cell-id (make-parameter #f))
(define current-specialization-registry-cell-id (make-parameter #f))
(define current-selection-registry-cell-id (make-parameter #f))
(define current-session-registry-cell-id (make-parameter #f))
;; Phase 2c: Remaining registry cell IDs
(define current-preparse-registry-cell-id (make-parameter #f))
(define current-spec-store-cell-id (make-parameter #f))
(define current-propagated-specs-cell-id (make-parameter #f))
(define current-strategy-registry-cell-id (make-parameter #f))
(define current-process-registry-cell-id (make-parameter #f))
(define current-user-precedence-groups-cell-id (make-parameter #f))
(define current-user-operators-cell-id (make-parameter #f))
(define current-macro-registry-cell-id (make-parameter #f))

;; Helper: write a single entry to a registry cell in the persistent network.
;; value should be a hasheq/hash with just the new entry — the cell's merge
;; function (merge-hasheq-union) will union it with existing content.
;; Track 7 Phase 2: targets the persistent registry network directly.
(define (macros-cell-write! cid value)
  (define prn-box (current-persistent-registry-net-box))
  (when (and prn-box cid)
    (set-box! prn-box (net-cell-write (unbox prn-box) cid value))))

;; Track 7 Phase 2: Initialize registry cells in the persistent registry network.
;; Called ONCE at file/prelude start from init-persistent-registry-network!.
;; Creates 24 cells initialized from current parameter content. Cell IDs are
;; STABLE — set once and never reset per command.
;; prn-box: (box prop-network) — the persistent registry network box
(define (init-macros-cells! prn-box)
  (when prn-box
    (define net0 (unbox prn-box))
    ;; Create cells initialized from current registry content
    (define-values (net1 sr-cid) (net-new-cell net0 (current-schema-registry) merge-hasheq-union))
    (current-schema-registry-cell-id sr-cid)
    (define-values (net2 cr-cid) (net-new-cell net1 (current-ctor-registry) merge-hasheq-union))
    (current-ctor-registry-cell-id cr-cid)
    (define-values (net3 tm-cid) (net-new-cell net2 (current-type-meta) merge-hasheq-union))
    (current-type-meta-cell-id tm-cid)
    ;; subtype/coercion use hash (equal?-based keys), but merge-hasheq-union
    ;; works correctly — hash-set preserves the hash type of the accumulator.
    (define-values (net4 st-cid) (net-new-cell net3 (current-subtype-registry) merge-hasheq-union))
    (current-subtype-registry-cell-id st-cid)
    (define-values (net5 co-cid) (net-new-cell net4 (current-coercion-registry) merge-hasheq-union))
    (current-coercion-registry-cell-id co-cid)
    (define-values (net6 cap-cid) (net-new-cell net5 (current-capability-registry) merge-hasheq-union))
    (current-capability-registry-cell-id cap-cid)
    (define-values (net7 ps-cid) (net-new-cell net6 (current-property-store) merge-hasheq-union))
    (current-property-store-cell-id ps-cid)
    (define-values (net8 fs-cid) (net-new-cell net7 (current-functor-store) merge-hasheq-union))
    (current-functor-store-cell-id fs-cid)
    ;; Trait + instance registry cells
    (define-values (net9 tr-cid) (net-new-cell net8 (current-trait-registry) merge-hasheq-union))
    (current-trait-registry-cell-id tr-cid)
    (define-values (net10 tl-cid) (net-new-cell net9 (current-trait-laws) merge-hasheq-union))
    (current-trait-laws-cell-id tl-cid)
    (define-values (net11 ir-cid) (net-new-cell net10 (current-impl-registry) merge-hasheq-union))
    (current-impl-registry-cell-id ir-cid)
    (define-values (net12 pir-cid) (net-new-cell net11 (current-param-impl-registry) merge-hasheq-union))
    (current-param-impl-registry-cell-id pir-cid)
    (define-values (net13 br-cid) (net-new-cell net12 (current-bundle-registry) merge-hasheq-union))
    (current-bundle-registry-cell-id br-cid)
    ;; specialization-registry uses hash (equal?-based keys: cons pairs)
    (define-values (net14 spr-cid) (net-new-cell net13 (current-specialization-registry) merge-hasheq-union))
    (current-specialization-registry-cell-id spr-cid)
    (define-values (net15 sel-cid) (net-new-cell net14 (current-selection-registry) merge-hasheq-union))
    (current-selection-registry-cell-id sel-cid)
    (define-values (net16 sess-cid) (net-new-cell net15 (current-session-registry) merge-hasheq-union))
    (current-session-registry-cell-id sess-cid)
    ;; Remaining registries
    (define-values (net17 pp-cid) (net-new-cell net16 (current-preparse-registry) merge-hasheq-union))
    (current-preparse-registry-cell-id pp-cid)
    (define-values (net18 ss-cid) (net-new-cell net17 (current-spec-store) merge-hasheq-union))
    (current-spec-store-cell-id ss-cid)
    ;; propagated-specs is a set (seteq), uses merge-set-union
    (define-values (net19 ps-set-cid) (net-new-cell net18 (current-propagated-specs) merge-set-union))
    (current-propagated-specs-cell-id ps-set-cid)
    (define-values (net20 strat-cid) (net-new-cell net19 (current-strategy-registry) merge-hasheq-union))
    (current-strategy-registry-cell-id strat-cid)
    (define-values (net21 proc-cid) (net-new-cell net20 (current-process-registry) merge-hasheq-union))
    (current-process-registry-cell-id proc-cid)
    (define-values (net22 pg-cid) (net-new-cell net21 (current-user-precedence-groups) merge-hasheq-union))
    (current-user-precedence-groups-cell-id pg-cid)
    (define-values (net23 op-cid) (net-new-cell net22 (current-user-operators) merge-hasheq-union))
    (current-user-operators-cell-id op-cid)
    (define-values (net24 mr-cid) (net-new-cell net23 (current-macro-registry) merge-hasheq-union))
    (current-macro-registry-cell-id mr-cid)
    (set-box! prn-box net24)))

;; Legacy: per-command registry cell creation in the elab-network.
;; Track 7 Phase 2: RETAINED for belt-and-suspenders — creates cells in the
;; elab-network alongside the persistent cells. Will be removed in Phase 3
;; once persistent reads are validated.
;; net-box: (box elab-network) — the shared network box
;; new-cell-fn: (enet initial-value merge-fn → (values enet* cell-id))
(define (register-macros-cells! net-box new-cell-fn)
  (void)  ;; Track 7 Phase 2: cells now created in persistent network by init-macros-cells!
  )

;; Track 6 Phase 6: Save/restore cell IDs for batch-worker network snapshot.
;; Returns a vector of 24 cell IDs in a fixed order.
(define (save-macros-cell-ids)
  (vector (current-schema-registry-cell-id)
          (current-ctor-registry-cell-id)
          (current-type-meta-cell-id)
          (current-subtype-registry-cell-id)
          (current-coercion-registry-cell-id)
          (current-capability-registry-cell-id)
          (current-property-store-cell-id)
          (current-functor-store-cell-id)
          (current-trait-registry-cell-id)
          (current-trait-laws-cell-id)
          (current-impl-registry-cell-id)
          (current-param-impl-registry-cell-id)
          (current-bundle-registry-cell-id)
          (current-specialization-registry-cell-id)
          (current-selection-registry-cell-id)
          (current-session-registry-cell-id)
          (current-preparse-registry-cell-id)
          (current-spec-store-cell-id)
          (current-propagated-specs-cell-id)
          (current-strategy-registry-cell-id)
          (current-process-registry-cell-id)
          (current-user-precedence-groups-cell-id)
          (current-user-operators-cell-id)
          (current-macro-registry-cell-id)))

;; Restore cell IDs from a saved vector (must match save-macros-cell-ids order).
(define (restore-macros-cell-ids! v)
  (current-schema-registry-cell-id       (vector-ref v 0))
  (current-ctor-registry-cell-id         (vector-ref v 1))
  (current-type-meta-cell-id             (vector-ref v 2))
  (current-subtype-registry-cell-id      (vector-ref v 3))
  (current-coercion-registry-cell-id     (vector-ref v 4))
  (current-capability-registry-cell-id   (vector-ref v 5))
  (current-property-store-cell-id        (vector-ref v 6))
  (current-functor-store-cell-id         (vector-ref v 7))
  (current-trait-registry-cell-id        (vector-ref v 8))
  (current-trait-laws-cell-id            (vector-ref v 9))
  (current-impl-registry-cell-id        (vector-ref v 10))
  (current-param-impl-registry-cell-id   (vector-ref v 11))
  (current-bundle-registry-cell-id       (vector-ref v 12))
  (current-specialization-registry-cell-id (vector-ref v 13))
  (current-selection-registry-cell-id    (vector-ref v 14))
  (current-session-registry-cell-id      (vector-ref v 15))
  (current-preparse-registry-cell-id     (vector-ref v 16))
  (current-spec-store-cell-id            (vector-ref v 17))
  (current-propagated-specs-cell-id      (vector-ref v 18))
  (current-strategy-registry-cell-id     (vector-ref v 19))
  (current-process-registry-cell-id      (vector-ref v 20))
  (current-user-precedence-groups-cell-id (vector-ref v 21))
  (current-user-operators-cell-id        (vector-ref v 22))
  (current-macro-registry-cell-id        (vector-ref v 23)))

;; Track 6 Phase 6: Save/restore all 19 macros registry PARAM VALUES for batch-worker.
;; Consolidates 19 individual define/parameterize bindings into a single vector.
;; Used by batch-worker.rkt to save post-prelude state and restore per-file.
(define (save-macros-registry-snapshot)
  (vector (current-preparse-registry)
          (current-spec-store)
          (current-propagated-specs)
          (current-ctor-registry)
          (current-type-meta)
          (current-subtype-registry)
          (current-coercion-registry)
          (current-trait-registry)
          (current-trait-laws)
          (current-impl-registry)
          (current-param-impl-registry)
          (current-bundle-registry)
          (current-specialization-registry)
          (current-capability-registry)
          (current-property-store)
          (current-functor-store)
          (current-user-precedence-groups)
          (current-user-operators)
          (current-macro-registry)))

;; Restore macros registry params from a saved vector.
;; Direct mutation (not parameterize) — caller is responsible for calling
;; this at the start of each isolation scope (e.g., per-file in batch-worker).
(define (restore-macros-registry-snapshot! v)
  (current-preparse-registry       (vector-ref v 0))
  (current-spec-store              (vector-ref v 1))
  (current-propagated-specs        (vector-ref v 2))
  (current-ctor-registry           (vector-ref v 3))
  (current-type-meta               (vector-ref v 4))
  (current-subtype-registry        (vector-ref v 5))
  (current-coercion-registry       (vector-ref v 6))
  (current-trait-registry          (vector-ref v 7))
  (current-trait-laws              (vector-ref v 8))
  (current-impl-registry           (vector-ref v 9))
  (current-param-impl-registry     (vector-ref v 10))
  (current-bundle-registry         (vector-ref v 11))
  (current-specialization-registry (vector-ref v 12))
  (current-capability-registry     (vector-ref v 13))
  (current-property-store          (vector-ref v 14))
  (current-functor-store           (vector-ref v 15))
  (current-user-precedence-groups  (vector-ref v 16))
  (current-user-operators          (vector-ref v 17))
  (current-macro-registry          (vector-ref v 18)))

;; ========================================
;; Schema registry: field information for schema types
;; ========================================

;; A schema field: stores a keyword name and its declared type datum.
;; keyword: symbol — the keyword name (e.g., 'name, 'age)
;; type-datum: symbol or list — the type datum (e.g., 'String, 'Nat, '(List Nat))
;; A schema field: keyword name, declared type, optional default value, optional check predicate.
;; default-val: #f if no :default, otherwise the datum value
;; check-pred: #f if no :check, otherwise the predicate datum (e.g., (> _ 0))
(struct schema-field (keyword type-datum default-val check-pred) #:transparent)

;; A schema entry: stores the full schema definition.
;; name: symbol — the schema name (e.g., 'User)
;; fields: (listof schema-field) — the declared fields in order
;; closed?: boolean — #t if :closed was specified (default #f, Phase 5)
;; srcloc: source location of the schema form
(struct schema-entry (name fields closed? srcloc) #:transparent)

;; Schema store: symbol → schema-entry
(define current-schema-registry (make-parameter (hasheq)))

(define (register-schema! name entry)
  (current-schema-registry (hash-set (current-schema-registry) name entry))
  ;; Phase 2a: dual-write to cell
  (macros-cell-write! (current-schema-registry-cell-id) (hasheq name entry)))

;; Track 3 Phase 1: cell-primary reader
(define (read-schema-registry)
  (or (macros-cell-read-safe (current-schema-registry-cell-id)) (current-schema-registry)))

(define (lookup-schema name)
  (hash-ref (read-schema-registry) name #f))

;; Parse schema field pairs from a datum list.
;; Input: (:name String :age Nat) → list of schema-field
;; Handles both simple types (Nat, String) and compound types ((List Nat)).
;; Parse schema fields. Returns (values fields auto-sub-schema-names).
;; auto-sub-schema-names is a list of symbols for inline nested schemas that
;; were auto-generated (and registered) during parsing. The caller should
;; emit type definitions for these in Pass 2.
(define (parse-schema-fields field-pairs srcloc [parent-name #f])
  (define auto-subs '())
  (define fields
    (let loop ([pairs field-pairs] [fields '()])
      (cond
        [(null? pairs) (reverse fields)]
        [(null? (cdr pairs))
         (error 'schema
                (format "schema field ~a is missing a type" (car pairs)))]
        [else
         (define kw-datum (car pairs))
         ;; Validate keyword: must be a keyword-like symbol (starts with ':')
         (unless (keyword-like-symbol? kw-datum)
           (error 'schema
                  (format "expected a keyword field name (e.g., :name), got ~a" kw-datum)))
         ;; Strip the leading ':' for storage
         (define kw-name
           (let ([s (symbol->string kw-datum)])
             (string->symbol (substring s 1))))
         (define type-datum (cadr pairs))
         ;; Check if this is an inline nested schema: the "type" is a list starting
         ;; with a keyword (e.g., (:name String)) — collect all consecutive sub-field
         ;; lists as the nested schema's fields.
         (cond
           [(and (pair? type-datum)
                 (keyword-like-symbol? (car type-datum)))
            ;; Inline nested schema: collect consecutive sub-field lists
            ;; Each sub-field is a list like (:name String) from the flattened form
            (define-values (sub-field-lists rest)
              (let collect ([remaining (cdr pairs)] [subs '()])
                (if (and (pair? remaining)
                         (pair? (car remaining))
                         (keyword-like-symbol? (caar remaining)))
                    (collect (cdr remaining) (cons (car remaining) subs))
                    (values (reverse subs) remaining))))
            ;; Flatten the sub-field lists into kv pairs
            (define sub-flat (apply append sub-field-lists))
            ;; Generate a name for the auto-schema
            (define sub-name
              (string->symbol
               (format "~a__~a"
                       (or parent-name (and srcloc (if (symbol? srcloc) srcloc "anon")) "anon")
                       kw-name)))
            ;; Recursively parse sub-fields (may generate further nested subs)
            (define-values (sub-fields sub-auto-subs) (parse-schema-fields sub-flat srcloc sub-name))
            (set! auto-subs (append auto-subs sub-auto-subs (list sub-name)))
            ;; Register the auto-generated sub-schema
            (register-schema! sub-name (schema-entry sub-name sub-fields #f #f))
            (loop rest
                  (cons (schema-field kw-name sub-name #f #f) fields))]
           [else
            ;; Normal field: keyword followed by type datum
            ;; Consume optional :default val and :check pred after the type
            (define-values (default-val check-pred rest)
              (parse-field-properties (cddr pairs)))
            (loop rest
                  (cons (schema-field kw-name type-datum default-val check-pred) fields))])])))
  (values fields auto-subs))


;; Parse optional field-level properties after a field's type datum.
;; Returns (values default-val check-pred remaining-pairs).
;; Handles: :default val, :check (pred), in any order, at most once each.
(define (parse-field-properties pairs)
  (let loop ([remaining pairs] [default-val #f] [check-pred #f])
    (cond
      [(null? remaining) (values default-val check-pred remaining)]
      ;; :default val — consume two items
      [(eq? (car remaining) ':default)
       (when (null? (cdr remaining))
         (error 'schema ":default requires a value"))
       (loop (cddr remaining) (cadr remaining) check-pred)]
      ;; :check pred — consume two items (pred is a form like (> _ 0))
      [(eq? (car remaining) ':check)
       (when (null? (cdr remaining))
         (error 'schema ":check requires a predicate"))
       (loop (cddr remaining) default-val (cadr remaining))]
      ;; Not a field property — stop
      [else (values default-val check-pred remaining)])))

;; Qualify a type-datum symbol using namespace context.
;; Built-in types (Nat, String, etc.) are left as-is.
;; User-defined types (Address, Point, etc.) are qualified with the current namespace.
;; Compound type datums like (List Nat) are recursively qualified.
(define builtin-type-names
  '(Nat Int Rat Bool String Char Keyword Unit Nil Symbol Type
    Posit8 Posit16 Posit32 Posit64 Quire8 Quire16 Quire32 Quire64
    List PVec Map Set Option Result Pair LSeq Value))
(define (qualify-type-datum datum ns-ctx)
  (cond
    [(symbol? datum)
     (if (memq datum builtin-type-names)
         datum
         (qualify-name datum (ns-context-current-ns ns-ctx)))]
    [(list? datum)
     (map (lambda (d) (qualify-type-datum d ns-ctx)) datum)]
    [else datum]))

;; ========================================
;; Selection registry
;; ========================================
;; name: symbol (the selection name, e.g., 'MovieTimesReq)
;; schema-name: symbol (the parent schema, e.g., 'User)
;; requires-paths: list of Racket keywords (#:id, #:name, etc.)
;; provides-paths: list of Racket keywords
;; includes-names: list of symbols (other selection names)
;; srcloc: source location of the selection form
(struct selection-entry (name schema-name requires-paths provides-paths includes-names srcloc) #:transparent)

;; Selection store: symbol → selection-entry
(define current-selection-registry (make-parameter (hasheq)))

(define (register-selection! name entry)
  (current-selection-registry (hash-set (current-selection-registry) name entry))
  ;; Phase 2b: dual-write to cell
  (macros-cell-write! (current-selection-registry-cell-id) (hasheq name entry)))

;; Track 3 Phase 2: cell-primary reader for selection registry
(define (read-selection-registry)
  (or (macros-cell-read-safe (current-selection-registry-cell-id)) (current-selection-registry)))

(define (lookup-selection name)
  (hash-ref (read-selection-registry) name #f))

;; ========================================
;; Session registry
;; ========================================
;; Stores session type declarations for lookup during elaboration.
;; name: symbol — the session name (e.g., 'Greeting)
;; session-type: sess-* tree — the elaborated session type (filled after elaboration)
;; srcloc: source location of the session declaration
(struct session-entry (name session-type srcloc) #:transparent)

;; Session store: symbol → session-entry
(define current-session-registry (make-parameter (hasheq)))

(define (register-session! name entry)
  (current-session-registry (hash-set (current-session-registry) name entry))
  ;; Phase 2b: dual-write to cell
  (macros-cell-write! (current-session-registry-cell-id) (hasheq name entry)))

;; Track 3 Phase 2: cell-primary reader for session registry
(define (read-session-registry)
  (or (macros-cell-read-safe (current-session-registry-cell-id)) (current-session-registry)))

(define (lookup-session name)
  (hash-ref (read-session-registry) name #f))

;; ========================================
;; Strategy registry (Phase S6): scheduling/execution configuration
;; ========================================

;; A strategy entry: stores scheduling/execution configuration properties.
;; name: symbol — the strategy name (e.g., 'realtime, 'batch)
;; properties: hasheq of keyword → value
;;   :fairness   → :round-robin | :priority | :none
;;   :fuel       → positive integer (propagator firing limit per step)
;;   :scheduler-io → :nonblocking | :blocking-ok (renamed from :io to avoid
;;                   confusion with protocol-level async !! / ??)
;;   :parallelism   → :single-thread | :work-stealing
;; srcloc: source location of the strategy declaration
(struct strategy-entry (name properties srcloc) #:transparent)

;; Default strategy properties
(define strategy-defaults
  (hasheq ':fairness ':round-robin
          ':fuel 50000
          ':scheduler-io ':nonblocking
          ':parallelism ':single-thread))

;; Valid property keys and their valid values
(define valid-strategy-keys
  (hasheq ':fairness '(:round-robin :priority :none)
          ':fuel 'positive-integer
          ':scheduler-io '(:nonblocking :blocking-ok)
          ':parallelism '(:single-thread :work-stealing)))

;; Strategy store: symbol → strategy-entry
(define current-strategy-registry (make-parameter (hasheq)))

(define (register-strategy! name entry)
  (current-strategy-registry (hash-set (current-strategy-registry) name entry))
  ;; Phase 2c: dual-write to cell
  (macros-cell-write! (current-strategy-registry-cell-id) (hasheq name entry)))

;; Track 3 Phase 3: cell-primary reader for strategy registry
(define (read-strategy-registry)
  (or (macros-cell-read-safe (current-strategy-registry-cell-id)) (current-strategy-registry)))

(define (lookup-strategy name)
  (hash-ref (read-strategy-registry) name #f))

;; ========================================
;; Process registry (Phase S7c): stores defproc definitions for spawn
;; ========================================

;; A process entry: stores a defined process for later execution.
;; name: symbol — the process name
;; session-type: sess-* tree — the session type
;; proc-body: proc-* tree — the process body
;; caps: list of (list name mult type-expr) — capability binders
;; srcloc: source location
(struct process-entry (name session-type proc-body caps srcloc) #:transparent)

;; Process store: symbol → process-entry
(define current-process-registry (make-parameter (hasheq)))

(define (register-process! name entry)
  (current-process-registry (hash-set (current-process-registry) name entry))
  ;; Phase 2c: dual-write to cell
  (macros-cell-write! (current-process-registry-cell-id) (hasheq name entry)))

;; Track 3 Phase 3: cell-primary reader for process registry
(define (read-process-registry)
  (or (macros-cell-read-safe (current-process-registry-cell-id)) (current-process-registry)))

(define (lookup-process name)
  (hash-ref (read-process-registry) name #f))

;; Parse strategy properties from a flat keyword-value list.
;; Input: (:fairness :priority :fuel 10000) → hasheq
;; Validates keys and values against valid-strategy-keys.
;; Returns: (values hasheq-of-props error-or-#f)
(define (parse-strategy-properties prop-list)
  (let loop ([remaining prop-list] [props strategy-defaults])
    (cond
      [(null? remaining) (values props #f)]
      [else
       (define key (car remaining))
       (cond
         ;; Must be a keyword symbol
         [(not (and (symbol? key)
                    (let ([s (symbol->string key)])
                      (and (> (string-length s) 1)
                           (char=? (string-ref s 0) #\:)))))
          (values props (format "strategy: expected keyword property, got ~a" key))]
         ;; Must be a valid strategy key
         [(not (hash-has-key? valid-strategy-keys key))
          (values props (format "strategy: unknown property ~a (valid: ~a)"
                                key (hash-keys valid-strategy-keys)))]
         ;; Must have a value after the key
         [(null? (cdr remaining))
          (values props (format "strategy: property ~a requires a value" key))]
         [else
          (define val (cadr remaining))
          (define valid-vals (hash-ref valid-strategy-keys key))
          ;; Validate value
          (define val-error
            (cond
              [(eq? valid-vals 'positive-integer)
               (if (and (integer? val) (positive? val)) #f
                   (format "strategy: ~a requires a positive integer, got ~a" key val))]
              [(list? valid-vals)
               (if (memq val valid-vals) #f
                   (format "strategy: ~a must be one of ~a, got ~a" key valid-vals val))]
              [else #f]))
          (if val-error
              (values props val-error)
              (loop (cddr remaining) (hash-set props key val)))])])))

;; ========================================
;; Pattern variables: symbols starting with $
;; ========================================
(define (pattern-var? x)
  (and (symbol? x)
       (not (eq? x '$angle-type))  ; reader sentinel, not a pattern variable
       (let ([s (symbol->string x)])
         (and (> (string-length s) 1)
              (char=? (string-ref s 0) #\$)))))

;; ========================================
;; datum-match: match a datum against a pattern
;; ========================================
;; Returns a hash of bindings ($name → value) on success, #f on failure.
;;
;; Pattern language:
;;   $name         — matches any single datum, binds it
;;   literal       — matches exactly (symbol, number, boolean)
;;   (pat ...)     — matches a list of the same length
;;   (pat ... $x ...) — $x captures remaining elements as a list
;;     (the ... after $x is literal ellipsis symbol)
(define (datum-match pattern datum)
  (cond
    ;; Pattern variable: matches anything
    [(pattern-var? pattern)
     (hasheq pattern datum)]
    ;; Literal match
    [(and (symbol? pattern) (symbol? datum) (eq? pattern datum))
     (hasheq)]
    [(and (number? pattern) (number? datum) (= pattern datum))
     (hasheq)]
    [(and (boolean? pattern) (boolean? datum) (eq? pattern datum))
     (hasheq)]
    ;; List match
    [(and (list? pattern) (list? datum))
     (datum-match-list pattern datum)]
    ;; No match
    [else #f]))

;; Match list patterns, handling ellipsis rest patterns
(define (datum-match-list pats dats)
  (cond
    ;; Both empty — success
    [(and (null? pats) (null? dats)) (hasheq)]
    ;; Pattern empty but data remains — fail
    [(null? pats) #f]
    ;; Check for ellipsis rest pattern: ($var ...)
    [(and (>= (length pats) 2)
          (pattern-var? (car pats))
          (eq? (cadr pats) '...))
     ;; $var captures remaining data minus any trailing fixed patterns
     (let ([remaining-pats (cddr pats)])
       (if (null? remaining-pats)
           ;; $var ... at end — captures all remaining data as a list
           (hasheq (car pats) dats)
           ;; $var ... followed by more patterns — not supported in v1
           #f))]
    ;; Data empty but pattern remains — fail
    [(null? dats) #f]
    ;; Match first element, then rest
    [else
     (let ([first-match (datum-match (car pats) (car dats))])
       (and first-match
            (let ([rest-match (datum-match-list (cdr pats) (cdr dats))])
              (and rest-match
                   (merge-bindings first-match rest-match)))))]))

;; Merge two binding hashes; fail if same variable bound to different values
(define (merge-bindings a b)
  (for/fold ([result a])
            ([(k v) (in-hash b)])
    (if (not result) #f
        (let ([existing (hash-ref result k 'not-found)])
          (cond
            [(eq? existing 'not-found) (hash-set result k v)]
            [(equal? existing v) result]
            [else #f])))))

;; ========================================
;; datum-subst: substitute bindings into a template
;; ========================================
;; Replaces pattern variables with their bound values.
;; Handles $name ... for splicing lists.
(define (datum-subst template bindings)
  (cond
    ;; Pattern variable: substitute
    [(pattern-var? template)
     (hash-ref bindings template
               (lambda ()
                 (error 'defmacro "Unbound pattern variable in template: ~a" template)))]
    ;; List template: handle splicing
    [(list? template)
     (datum-subst-list template bindings)]
    ;; Literal: pass through
    [else template]))

;; Substitute in a list template, handling $var ... splicing
(define (datum-subst-list elems bindings)
  (cond
    [(null? elems) '()]
    ;; Check for splice: $var ...
    [(and (>= (length elems) 2)
          (pattern-var? (car elems))
          (eq? (cadr elems) '...))
     (let ([val (hash-ref bindings (car elems)
                          (lambda ()
                            (error 'defmacro "Unbound pattern variable: ~a" (car elems))))])
       (unless (list? val)
         (error 'defmacro "Splice variable ~a must be bound to a list, got: ~a"
                (car elems) val))
       (append val (datum-subst-list (cddr elems) bindings)))]
    ;; Regular element
    [else
     (cons (datum-subst (car elems) bindings)
           (datum-subst-list (cdr elems) bindings))]))

;; ========================================
;; ========================================
;; Schema default injection helpers
;; ========================================

;; Extract provided keyword symbols from a $brace-params datum.
;; ($brace-params :x 1 :y 2) → '(x y)
(define (brace-params-provided-keywords brace-datum)
  (let loop ([items (cdr brace-datum)] [keys '()])
    (cond
      [(null? items) (reverse keys)]
      [(and (symbol? (car items)) (keyword-like-symbol? (car items)))
       (loop (if (null? (cdr items)) items (cddr items))
             (cons (let ([s (symbol->string (car items))])
                     (string->symbol (substring s 1)))
                   keys))]
      [else (loop (if (null? (cdr items)) items (cddr items)) keys)])))

;; Inject default values for missing fields into a $brace-params datum.
;; Returns augmented $brace-params or original if nothing to inject.
(define (inject-schema-defaults schema-entry brace-datum)
  (define provided (brace-params-provided-keywords brace-datum))
  (define fields (schema-entry-fields schema-entry))
  (define missing-defaults
    (filter-map (lambda (f)
                  (and (schema-field-default-val f)
                       (not (memq (schema-field-keyword f) provided))
                       (cons (schema-field-keyword f) (schema-field-default-val f))))
                fields))
  (if (null? missing-defaults)
      brace-datum
      ;; Append :field val pairs to the brace-params
      (append brace-datum
              (append-map (lambda (pair)
                            (list (string->symbol (format ":~a" (car pair)))
                                  (cdr pair)))
                          missing-defaults))))

;; ========================================
;; Schema check-pred wrapping helpers
;; ========================================

;; Substitute all occurrences of the symbol _ in a datum tree.
(define (subst-underscore datum replacement)
  (cond
    [(eq? datum '_) replacement]
    [(pair? datum) (map (lambda (d) (subst-underscore d replacement)) datum)]
    [else datum]))

;; Normalize operator symbols in a check-pred datum to parser keywords.
;; > → lt (swapped), >= → le (swapped), < → lt, <= → le, == → eq, /= → neq.
;; Passes through $mixfix datums (WS reader already wrapped them).
;; Passes through function applications (valid? _) unchanged.
(define (normalize-check-pred datum)
  (cond
    [(not (pair? datum)) datum]
    [(eq? (car datum) '$mixfix) datum]  ;; WS reader already handled
    [(memq (car datum) '(> >=))
     (define norm-args (map normalize-check-pred (cdr datum)))
     `(,(if (eq? (car datum) '>) 'lt 'le) ,@(reverse norm-args))]
    [(memq (car datum) '(< <=))
     (define norm-args (map normalize-check-pred (cdr datum)))
     `(,(if (eq? (car datum) '<) 'lt 'le) ,@norm-args)]
    [(memq (car datum) '(== /=))
     (define norm-args (map normalize-check-pred (cdr datum)))
     `(,(if (eq? (car datum) '==) 'eq 'neq) ,@norm-args)]
    [else (map normalize-check-pred datum)]))

;; Wrap a base-form datum with nested if/panic checks for all checked fields.
;; Returns the wrapped datum, or base-form if no checks needed.
(define (wrap-schema-checks schema-entry base-form)
  (define fields (schema-entry-fields schema-entry))
  (define checked-fields
    (filter (lambda (f) (schema-field-check-pred f)) fields))
  (if (null? checked-fields)
      base-form
      (let ([tmp '__schema-check-tmp])
        (define body
          (foldr (lambda (f inner)
                   (define kw-sym (schema-field-keyword f))
                   (define access `(map-get ,tmp ,(string->symbol (format ":~a" kw-sym))))
                   (define pred-raw (schema-field-check-pred f))
                   (define pred-subst (subst-underscore pred-raw access))
                   (define pred-norm (normalize-check-pred pred-subst))
                   (define schema-name (schema-entry-name schema-entry))
                   (define msg (format "~a: field :~a failed check ~a" schema-name kw-sym pred-raw))
                   `(if ,pred-norm ,inner (panic ,msg)))
                 tmp
                 checked-fields))
        `(let ,tmp ,base-form ,body))))

;; ========================================
;; Session type WS-mode desugaring (Phase S1d)
;; ========================================
;; Converts WS-mode session body items from flat list to nested sexp form.
;; Input: (session Name items...) where items are flat body elements
;;   (! Type) → Send, (? Type) → Recv, (!: (n : T)) → DSend, (?: (n : T)) → DRecv,
;;   (+> ($pipe :l1 items...) ...) → Choice, (&> ($pipe :l1 items...) ...) → Offer,
;;   rec → anonymous Mu, (rec Label) → named Mu, end → End,
;;   (shared items...) → Shared
;; Output: (session Name NestedBody) where NestedBody is right-nested sexp

(define (desugar-session-ws datum)
  (define parts (cdr datum))  ;; skip 'session
  (cond
    [(< (length parts) 2)
     datum]  ;; malformed — let parser report error
    [else
     (define name (car parts))
     (define rest (cdr parts))
     ;; Separate metadata from body items
     (define-values (meta body-items) (split-session-metadata rest))
     (define nested-body (session-items->nested body-items))
     `(session ,name ,@meta ,nested-body)]))

;; Split leading metadata keywords from body items.
;; Returns (values metadata-items body-items).
(define (split-session-metadata items)
  (let loop ([remaining items] [meta '()])
    (cond
      [(null? remaining) (values (reverse meta) '())]
      [else
       (define item (car remaining))
       (cond
         ;; Keyword symbol followed by value = metadata
         [(and (symbol? item)
               (let ([s (symbol->string item)])
                 (and (> (string-length s) 1)
                      (char=? (string-ref s 0) #\:)))
               (pair? (cdr remaining)))
          (loop (cddr remaining) (cons (cadr remaining) (cons item meta)))]
         ;; Not a keyword — rest is body
         [else (values (reverse meta) remaining)])])))

;; Right-fold a flat list of WS session items into nested sexp form.
;; (! String) (? Nat) end  →  (Send String (Recv Nat End))
;;
;; Special handling for `rec` in continuation position:
;; - As the FIRST item (head): creates a Mu (recursion binder)
;; - As a TAIL item (continuation after send/recv): recursion variable reference
;;   In WS mode: `rec` at tail means "go back to the enclosing Mu"
;;   The parser treats bare symbols in session position as session variables.
(define (session-items->nested items)
  (cond
    [(null? items) 'End]  ;; implicit End
    [(= (length items) 1)
     (define item (car items))
     ;; Bare `rec` as the only/last item = recursion variable reference
     ;; Parser's parse-session-body handles bare symbols as surf-sess-var
     (cond
       [(and (symbol? item) (eq? item 'rec))
        ;; Recursion back to enclosing Mu — pass as bare symbol.
        ;; The elaborator resolves unnamed recursion variables.
        'rec]
       [else (session-item->sexp item 'End)])]
    [else
     (session-item->sexp (car items) (session-items->nested (cdr items)))]))

;; Convert a single WS session item to sexp, with given continuation.
(define (session-item->sexp item cont)
  (cond
    ;; Bare symbol
    [(symbol? item)
     (case item
       [(end End) 'End]
       [(rec) `(Mu ,cont)]
       [else
        ;; Session variable reference — use as-is, cont is ignored
        ;; (the item IS the body, not a step that chains)
        item])]
    ;; List form
    [(pair? item)
     (define head (car item))
     ;; Handle reader's ($typed-hole) form for ?? in session context.
     ;; The WS reader tokenizes ?? as ($typed-hole), which appears as the head
     ;; of the line-grouped item. The inner element may be a syntax object.
     (define (typed-hole-head? h)
       (and (pair? h)
            (let ([inner (car h)])
              (and (or (and (symbol? inner) (eq? inner '$typed-hole))
                       (and (syntax? inner) (eq? (syntax-e inner) '$typed-hole)))
                   (null? (cdr h))))))
     (cond
      [(typed-hole-head? head)
       (if (>= (length item) 2)
           `(AsyncRecv ,(cadr item) ,cont)
           item)]
      [else
       (case head
       ;; (! Type) → (Send Type Cont)
       [(!)
        (if (>= (length item) 2)
            `(Send ,(cadr item) ,cont)
            item)]  ;; malformed
       ;; (?? Type) → (AsyncRecv Type Cont) — non-blocking recv
       [(??)
        (if (>= (length item) 2)
            `(AsyncRecv ,(cadr item) ,cont)
            item)]
       ;; (? Type) → (Recv Type Cont)
       [(?)
        (if (>= (length item) 2)
            `(Recv ,(cadr item) ,cont)
            item)]
       ;; (!! Type) → (AsyncSend Type Cont) — non-blocking send
       [(!!)
        (if (>= (length item) 2)
            `(AsyncSend ,(cadr item) ,cont)
            item)]
       ;; (!: n T) → (DSend (n : T) Cont)
       ;; WS reader produces (!: n Nat) as a 3-element list
       [(!:)
        (cond
          [(= (length item) 3)
           ;; (!: name Type) → (DSend (name : Type) Cont)
           `(DSend (,(cadr item) : ,(caddr item)) ,cont)]
          [(= (length item) 2)
           ;; (!: (n : T)) from sexp form — pass through
           `(DSend ,(cadr item) ,cont)]
          [else item])]
       ;; (?: x T) → (DRecv (x : T) Cont)
       ;; WS reader produces (?: x Bool) as a 3-element list
       [(?:)
        (cond
          [(= (length item) 3)
           ;; (?: name Type) → (DRecv (name : Type) Cont)
           `(DRecv (,(cadr item) : ,(caddr item)) ,cont)]
          [(= (length item) 2)
           ;; (?: (x : T)) from sexp form — pass through
           `(DRecv ,(cadr item) ,cont)]
          [else item])]
       ;; (+> ($pipe :l1 items...) ...) → (Choice ((:l1 nested1) (:l2 nested2) ...))
       [(+>)
        (define branches (desugar-session-branches (cdr item)))
        `(Choice ,branches)]
       ;; (&> ($pipe :l1 items...) ...) → (Offer ...)
       ;; Note: &> tokenizes as $clause-sep in the reader, so match both.
       [(&> $clause-sep)
        (define branches (desugar-session-branches (cdr item)))
        `(Offer ,branches)]
       ;; rec forms:
       ;; (rec) alone → (Mu cont)
       ;; (rec Label Body...) where Label is a symbol → (Mu Label desugared-body)
       ;; (rec Body...) where Body is a list → (Mu desugared-body)
       [(rec)
        (cond
          [(= (length item) 1)
           ;; Bare (rec) — unnamed recursion, body is the continuation
           `(Mu ,cont)]
          [(and (>= (length item) 2) (symbol? (cadr item)))
           ;; Named recursion: (rec Label Body...)
           (define label (cadr item))
           (define body-items (cddr item))
           (cond
             [(null? body-items)
              ;; Just a label, body is the continuation
              `(Mu ,label ,cont)]
             [else
              ;; Named with body items — desugar recursively
              `(Mu ,label ,(session-items->nested body-items))])]
          [else
           ;; Unnamed recursion with body items: (rec Body...)
           `(Mu ,(session-items->nested (cdr item)))])]
       ;; (shared items...) → (Shared nested)
       [(shared)
        `(Shared ,(session-items->nested (cdr item)))]
       ;; (SVar Name) → pass through
       [(SVar) item]
       ;; Otherwise — pass through unchanged (could be a type reference)
       [else item])])]
    [else item]))

;; Desugar WS-mode branch list from $pipe children.
;; ($pipe :label items...) → (:label nested)
(define (desugar-session-branches pipe-children)
  (for/list ([child (in-list pipe-children)])
    (cond
      [(and (pair? child) (eq? (car child) '$pipe) (>= (length child) 2))
       (define label (cadr child))
       (define branch-items (cddr child))
       ;; Handle -> chains in branch items:
       ;; 1. Strip bare -> symbols
       ;; 2. Re-group flat tokens into operator+arg lists
       (define flat-items (flatten-arrow-chain branch-items))
       (define clean-items (regroup-session-tokens flat-items))
       (define nested (session-items->nested clean-items))
       `(,label ,nested)]
      ;; Non-pipe child — pass through (shouldn't happen in well-formed input)
      [else child])))

;; Flatten arrow chains: strip bare -> symbols from item lists.
;; The WS reader produces inline arrow chains for branch bodies:
;;   (-> ! Nat -> rec) → (! Nat rec)     [strip bare -> symbols]
;;   ((-> X Y)) → (X Y)                  [unwrap single -> wrapper list]
(define (flatten-arrow-chain items)
  (cond
    [(null? items) '()]
    ;; Single -> wrapper list: (-> X Y) as a nested list
    [(and (= (length items) 1) (pair? (car items)) (eq? (caar items) '->))
     (flatten-arrow-chain (cdar items))]
    ;; Bare -> symbol — skip it (WS reader separator)
    [(and (symbol? (car items)) (eq? (car items) '->))
     (flatten-arrow-chain (cdr items))]
    [else
     (cons (car items) (flatten-arrow-chain (cdr items)))]))

;; Re-group flat session tokens into operator+argument lists.
;; After arrow-stripping, branch bodies may be flat token sequences:
;;   (! Nat rec end) → ((! Nat) rec end)
;;   (? String end) → ((? String) end)
;;   (!: n Nat end) → ((!: n Nat) end)
;; Bare symbols (end, rec, SVar names) remain ungrouped.
(define (regroup-session-tokens items)
  (cond
    [(null? items) '()]
    ;; ($typed-hole) followed by something → async recv (?? Type)
    ;; The reader tokenizes ?? as ($typed-hole), not a symbol.
    ;; In session body context, bare ($typed-hole) means async recv.
    ;; The inner element may be a symbol or a syntax object.
    [(and (pair? (car items))
          (let ([inner (caar items)])
            (and (or (and (symbol? inner) (eq? inner '$typed-hole))
                     (and (syntax? inner) (eq? (syntax-e inner) '$typed-hole)))
                 (null? (cdar items))))
          (pair? (cdr items)))
     (cons (list '?? (cadr items))
           (regroup-session-tokens (cddr items)))]
    ;; ! or ? or !! followed by something → group as (Op Type)
    [(and (symbol? (car items))
          (memq (car items) '(! ? !!))
          (pair? (cdr items)))
     (cons (list (car items) (cadr items))
           (regroup-session-tokens (cddr items)))]
    ;; !: or ?: followed by two things → group as (Op Name Type)
    [(and (symbol? (car items))
          (memq (car items) '(!: ?:))
          (>= (length (cdr items)) 2))
     (cons (list (car items) (cadr items) (caddr items))
           (regroup-session-tokens (cdddr items)))]
    [else
     (cons (car items)
           (regroup-session-tokens (cdr items)))]))

;; ========================================
;; Process WS-mode desugaring (Phase S2c)
;; ========================================
;; Converts WS-mode process body items from flat list to nested sexp form.
;; Input (from WS reader):
;;   (defproc Name : SessionType (self ! "hello") (name := self ?) stop)
;; Output (for sexp-mode parser):
;;   (defproc Name : SessionType (proc-send self "hello" (proc-recv self name (proc-stop))))
;;
;; Parallels desugar-session-ws for session type declarations.

;; Check if a datum is a ($brace-params ...) form (capability binders).
(define (brace-params-datum? x)
  (and (pair? x) (eq? (car x) '$brace-params)))

;; Split defproc header from body items.
;; Header forms: `: SessionType`, `($brace-params ...)`
;; Returns (values header-prefix body-items).
(define (split-defproc-header items)
  (cond
    [(null? items) (values '() '())]
    [(eq? (car items) ':)
     ;; : SessionType [Caps] Body...
     (cond
       [(< (length items) 2) (values items '())]  ;; malformed
       [else
        (define sess-type (cadr items))
        (define after (cddr items))
        (cond
          [(and (pair? after) (brace-params-datum? (car after)))
           (values (list ': sess-type (car after)) (cdr after))]
          [else
           (values (list ': sess-type) after)])])]
    [(brace-params-datum? (car items))
     ;; {Caps} Body...
     (values (list (car items)) (cdr items))]
    [else
     ;; No header — everything is body
     (values '() items)]))

;; Right-fold a flat list of WS process body items into nested sexp form.
;; (self ! "x") (name := self ?) stop  →  (proc-send self "x" (proc-recv self name (proc-stop)))
(define (proc-items->nested items)
  (cond
    [(null? items) '(proc-stop)]  ;; implicit stop
    [(= (length items) 1)
     (proc-item->sexp (car items) '(proc-stop))]
    [else
     (proc-item->sexp (car items) (proc-items->nested (cdr items)))]))

;; Desugar WS-mode branch list from $pipe children for offer/case.
;; ($pipe :label items...) → (:label nested-body)
(define (desugar-proc-branches pipe-children)
  (for/list ([child (in-list pipe-children)])
    (cond
      [(and (pair? child) (eq? (car child) '$pipe) (>= (length child) 2))
       (define label (cadr child))
       (define branch-items (cddr child))
       (define clean-items (flatten-arrow-chain branch-items))
       (define nested (proc-items->nested clean-items))
       `(,label ,nested)]
      [else child])))

;; Convert a single WS process body item to sexp, with given continuation.
(define (proc-item->sexp item cont)
  (cond
    ;; Bare symbol
    [(symbol? item)
     (case item
       [(stop proc-stop) '(proc-stop)]
       [(rec) '(proc-rec)]
       [else item])]  ;; unknown — pass through for parser error
    ;; List form
    [(pair? item)
     (define len (length item))
     (cond
       ;; (Chan ! Expr) or (Chan !: Expr) or (Chan !! Expr) — send
       [(and (= len 3) (memq (cadr item) '(! !: !!)))
        `(proc-send ,(car item) ,(caddr item) ,cont)]
       ;; (Var := Chan ?) or (Var := Chan ?:) or (Var := Chan ??) — receive
       ;; Note: ?? from the reader arrives as ($typed-hole), not a symbol.
       [(and (= len 4) (eq? (cadr item) ':=)
             (or (memq (cadddr item) '(? ?:))
                 (and (pair? (cadddr item))
                      (let ([inner (car (cadddr item))])
                        (or (eq? inner '$typed-hole)
                            (and (syntax? inner) (eq? (syntax-e inner) '$typed-hole)))))))
        `(proc-recv ,(caddr item) ,(car item) ,cont)]
       ;; (select Chan :Label) — select
       [(and (>= len 3) (eq? (car item) 'select))
        `(proc-sel ,(cadr item) ,(caddr item) ,cont)]
       ;; (offer Chan $pipe...) — case/offer
       [(and (>= len 2) (eq? (car item) 'offer))
        (define chan (cadr item))
        (define branches (desugar-proc-branches (cddr item)))
        `(proc-case ,chan ,branches)]
       ;; (new (c1 c2) : Session Body1 Body2) — new channel pair
       [(and (>= len 5) (eq? (car item) 'new) (eq? (caddr item) ':))
        (define session-type (cadddr item))
        (define par-bodies (cddddr item))
        (cond
          [(= (length par-bodies) 2)
           `(proc-new ,session-type
              (proc-par ,(proc-items->nested (list (car par-bodies)))
                        ,(proc-items->nested (list (cadr par-bodies)))))]
          [else
           `(proc-new ,session-type ,(proc-items->nested par-bodies))])]
       ;; (par P1 P2) — parallel
       [(and (= len 3) (eq? (car item) 'par))
        `(proc-par ,(proc-items->nested (list (cadr item)))
                   ,(proc-items->nested (list (caddr item))))]
       ;; (link c1 c2) — channel forwarding
       [(and (= len 3) (eq? (car item) 'link))
        `(proc-link ,(cadr item) ,(caddr item))]
       ;; (with-open path : Session body...) — auto-closing open
       ;; Expands to: (proc-open path : Session (body... (proc-sel ch :close cont)))
       ;; The user writes:
       ;;   with-open "file.txt" : FileRead
       ;;     select ch :read-all
       ;;     data := ch ?
       ;; And it auto-adds select ch :close before the outer continuation.
       ;; Minimum: (with-open path : Session) = 4 elements (no body, just open+close)
       [(and (>= len 4) (eq? (car item) 'with-open))
        (define path-expr (cadr item))
        (define after-open (cddr item))  ; (: FileRead body1 body2 ...)
        (cond
          [(and (>= (length after-open) 2) (eq? (car after-open) ':))
           (define sess-type (cadr after-open))
           (define body-items (cddr after-open))
           ;; Build: body items folded right, with (proc-sel ch :close cont) as base
           (define close-then-cont `(proc-sel ch |:close| ,cont))
           (define body-nested
             (foldr (lambda (item* acc) (proc-item->sexp item* acc))
                    close-then-cont
                    body-items))
           `(proc-open ,path-expr : ,sess-type ,body-nested)]
          [else item])]  ;; malformed — let parser report error
       ;; (open/connect/listen path : Session [Cap] body...) — boundary ops
       [(and (>= len 4) (memq (car item) '(open connect listen)))
        (define proc-op (case (car item)
                          [(open) 'proc-open]
                          [(connect) 'proc-connect]
                          [(listen) 'proc-listen]))
        `(,proc-op ,@(cdr item) ,cont)]
       ;; Other list forms (match, function calls, etc.) — pass through
       [else item])]
    [else item]))

(define (desugar-defproc-ws datum)
  (define parts (cdr datum))  ;; skip 'defproc
  (cond
    [(< (length parts) 2) datum]  ;; malformed — let parser report error
    [else
     (define name (car parts))
     (define rest (cdr parts))
     (define-values (header-items body-items) (split-defproc-header rest))
     (cond
       [(null? body-items) datum]  ;; no body to desugar
       ;; If body is already a single sexp proc form, pass through
       [(and (= (length body-items) 1) (pair? (car body-items))
             (let ([h (caar body-items)])
               (memq h '(proc-send proc-recv proc-sel proc-case proc-stop
                         proc-new proc-par proc-link proc-rec
                         proc-open proc-connect proc-listen))))
        datum]
       [else
        (define nested-body (proc-items->nested body-items))
        `(defproc ,name ,@header-items ,nested-body)])]))

(define (desugar-proc-ws datum)
  (define parts (cdr datum))  ;; skip 'proc
  (cond
    [(null? parts) datum]
    [else
     (define-values (header-items body-items) (split-defproc-header parts))
     (cond
       [(null? body-items) datum]
       ;; If body is already a single sexp proc form, pass through
       [(and (= (length body-items) 1) (pair? (car body-items))
             (let ([h (caar body-items)])
               (memq h '(proc-send proc-recv proc-sel proc-case proc-stop
                         proc-new proc-par proc-link proc-rec
                         proc-open proc-connect proc-listen))))
        datum]
       [else
        (define nested-body (proc-items->nested body-items))
        `(proc ,@header-items ,nested-body)])]))

;; ========================================
;; Strategy WS-mode desugaring (Phase WS-4)
;; ========================================
;; The WS reader groups each indented property line as a sub-list:
;;   (strategy realtime (:fairness :priority) (:fuel 10000))
;; The parser expects a flat form:
;;   (strategy realtime :fairness :priority :fuel 10000)
;; This function flattens nested property pairs.
(define (desugar-strategy-ws datum)
  (define parts (cdr datum))  ;; skip 'strategy
  (cond
    [(< (length parts) 1) datum]  ;; malformed
    [else
     (define name (car parts))
     (define rest (cdr parts))
     ;; Flatten: each element that is a list of keywords/values gets spliced
     (define flat-props
       (apply append
              (for/list ([item (in-list rest)])
                (cond
                  [(pair? item) item]    ;; (:key value) → splice
                  [else (list item)]))))  ;; bare symbol → keep
     `(strategy ,name ,@flat-props)]))

;; preparse-expand-form: expand a single datum
;; ========================================
;; Tries to match the head symbol against registered macros.
;; Loops until fixpoint or depth limit.
;; After expanding the head form, recursively expands subexpressions.
(define (preparse-expand-form datum [registry #f] [depth 0])
  (define reg (or registry (read-preparse-registry)))
  (cond
    [(> depth 100)
     (error 'preparse "Macro expansion depth limit exceeded (possible infinite loop)")]
    ;; Bare symbol — check if it's a registered macro (e.g., simple deftype alias)
    [(symbol? datum)
     (define entry (hash-ref reg datum #f))
     (cond
       [(procedure? entry)
        (define result (entry datum))
        (if (equal? result datum) datum
            (preparse-expand-form result reg (+ depth 1)))]
       [else datum])]
    ;; $foreign-block — opaque, do NOT recurse into code datums
    ;; The code inside is raw Racket, not Prologos surface syntax
    [(and (pair? datum) (eq? (car datum) '$foreign-block))
     datum]
    ;; Track 8 B3: $brace-params — opaque during preparse.
    ;; Contents are parsed later by parse-brace-param-list when consumed
    ;; by trait/data/spec processing. Do NOT recursively expand — the ->
    ;; inside brace params is a kind annotation, not a function arrow.
    [(and (pair? datum) (eq? (car datum) '$brace-params))
     datum]
    ;; List form — check head symbol for macros
    [(and (pair? datum) (symbol? (car datum)))
     (define entry (hash-ref reg (car datum) #f))
     (cond
       [(preparse-macro? entry)
        ;; Pattern-template rewrite
        (define bindings (datum-match (preparse-macro-pattern entry) datum))
        (if bindings
            (preparse-expand-form
             (datum-subst (preparse-macro-template entry) bindings)
             reg (+ depth 1))
            ;; Pattern didn't match — still recurse into subexpressions
            (preparse-expand-subforms datum reg depth))]
       [(procedure? entry)
        ;; Built-in procedural macro
        (define result (entry datum))
        (if (equal? result datum)
            datum  ; no change, avoid infinite loop
            (preparse-expand-form result reg (+ depth 1)))]
       [else
        ;; Schema construction rewrite: (SchemaName ($brace-params ...)) → (the SchemaName ($brace-params ...))
        ;; When the head is a known schema name and the rest is a brace-params map literal,
        ;; wrap in a `the` annotation so the map is type-checked against the schema.
        (define maybe-schema (lookup-schema (car datum)))
        (if (and maybe-schema
                 (pair? (cdr datum))
                 (let ([arg (cadr datum)])
                   (and (pair? arg) (eq? (car arg) '$brace-params)))
                 (null? (cddr datum)))  ;; exactly one arg: the brace-params
            ;; Phase 5b: inject default values for missing fields
            ;; Phase 5c: wrap with :check assertions
            (let* ([augmented (inject-schema-defaults maybe-schema (cadr datum))]
                   [the-form `(the ,(car datum) ,augmented)]
                   [wrapped (wrap-schema-checks maybe-schema the-form)])
              (preparse-expand-form wrapped reg (+ depth 1)))
            ;; Not a schema construction — recurse into subexpressions
            (preparse-expand-subforms datum reg depth))])]
    ;; Non-symbol list — recurse into subexpressions
    [(pair? datum)
     (preparse-expand-subforms datum reg depth)]
    [else datum]))

;; Single-step macro expansion. Returns the result of exactly one expansion.
;; If no expansion applies, returns the datum unchanged.
;; Does NOT recurse into subforms — shows only the outermost rewrite.
;; Used by the `expand-1` inspection command.
(define (preparse-expand-1 datum [registry #f])
  (define reg (or registry (read-preparse-registry)))
  (cond
    [(symbol? datum)
     (define entry (hash-ref reg datum #f))
     (cond
       [(procedure? entry) (entry datum)]
       [else datum])]
    [(and (pair? datum) (eq? (car datum) '$foreign-block))
     datum]
    [(and (pair? datum) (symbol? (car datum)))
     (define entry (hash-ref reg (car datum) #f))
     (cond
       [(preparse-macro? entry)
        (define bindings (datum-match (preparse-macro-pattern entry) datum))
        (if bindings
            (datum-subst (preparse-macro-template entry) bindings)
            datum)]
       [(procedure? entry) (entry datum)]
       [else datum])]
    [else datum]))

;; Expand a single top-level datum through all preparse stages.
;; Applies: def := expansion, spec injection, then preparse-expand-form.
;; Used by the `expand` inspection command.
(define (preparse-expand-single datum)
  (cond
    [(and (pair? datum) (symbol? (car datum)))
     (define head (car datum))
     (cond
       ;; def with := — expand assignment syntax, then spec injection
       [(and (eq? head 'def) (memq ':= datum))
        (define pre (expand-def-assign datum))
        (define injected (maybe-inject-spec-def pre))
        (preparse-expand-form injected)]
       ;; def without := — try spec injection
       [(eq? head 'def)
        (define injected (maybe-inject-spec-def datum))
        (preparse-expand-form injected)]
       ;; defn — spec injection
       [(eq? head 'defn)
        (define injected (maybe-inject-spec datum))
        (preparse-expand-form injected)]
       ;; Everything else — standard preparse
       [else (preparse-expand-form datum)])]
    [else (preparse-expand-form datum)]))

;; Full preparse expansion with all intermediate steps visible.
;; Returns a list of (label . datum) pairs showing each transformation.
;; Shows: def-assign expansion, spec injection, where-clause injection,
;; infix rewriting, and macro expansion — making all "invisible" rewrites visible.
;; Used by the `expand-full` inspection command.
(define (preparse-expand-full datum)
  (define steps '())
  (define (record! label d)
    (set! steps (cons (cons label d) steps)))

  (record! "input" datum)

  ;; Step 1: def := expansion
  (define after-assign
    (if (and (pair? datum) (symbol? (car datum))
             (eq? (car datum) 'def) (memq ':= datum))
        (let ([r (expand-def-assign datum)])
          (unless (equal? r datum) (record! "def-assign" r)) r)
        datum))

  ;; Step 2: spec injection (for def/defn)
  (define after-spec
    (cond
      [(and (pair? after-assign) (eq? (car after-assign) 'defn))
       (let ([r (maybe-inject-spec after-assign)])
         (unless (equal? r after-assign) (record! "spec-inject" r)) r)]
      [(and (pair? after-assign) (eq? (car after-assign) 'def))
       (let ([r (maybe-inject-spec-def after-assign)])
         (unless (equal? r after-assign) (record! "spec-inject" r)) r)]
      [else after-assign]))

  ;; Step 3: where-clause injection (only for def/defn forms)
  (define after-where
    (if (and (pair? after-spec) (symbol? (car after-spec))
             (memq (car after-spec) '(def defn)))
        (let ([r (maybe-inject-where after-spec)])
          (unless (equal? r after-spec) (record! "where-inject" r)) r)
        after-spec))

  ;; Step 4: infix rewriting
  (define after-infix
    (if (pair? after-where)
        (let ([r (rewrite-infix-operators after-where)])
          (unless (equal? r after-where) (record! "infix-rewrite" r)) r)
        after-where))

  ;; Step 5: macro expansion (to fixpoint)
  (define after-macros (preparse-expand-form after-infix))
  (unless (equal? after-macros after-infix)
    (record! "macro-expand" after-macros))

  (reverse steps))

;; Merge consecutive bodyless let forms into a single let with bracket bindings.
;; Input: list of elements (siblings in a form).
;; A "bodyless let" is (let name [: T] := value) with no body — detected because
;; the last element is NOT a list (it's the value, not a body expression like (add a b)).
;; The last let in a consecutive run has a body.
;;
;; Example: (defn ... (let a := 1) (let b := 2 (add a b)))
;; → (defn ... (let (a := 1 b := 2) (add a b)))
(define (merge-sibling-lets elems)
  (cond
    [(or (not (list? elems)) (null? elems)) elems]
    [else
     (let loop ([rest elems] [acc '()])
       (cond
         [(null? rest) (reverse acc)]
         ;; Check if current element is a bodyless let
         [(let-form? (car rest))
          ;; Collect consecutive let forms
          (define-values (lets remaining) (collect-consecutive-lets rest))
          (cond
            ;; Single let — merge with following body only if bodyless
            [(<= (length lets) 1)
             ;; Pre-process: restructure infix = in value tokens so that
             ;; let-bodyless? works correctly for values like (r := 1N = 1N).
             ;; Without this, (let r := ($nat-literal 1) = ($nat-literal 1))
             ;; appears to have 3 elements after :=, fooling let-bodyless?.
             (define preprocessed (preprocess-let-infix-eq (car lets)))
             (if (and (pair? remaining)
                      (not (let-form? (car remaining)))
                      (let-bodyless? preprocessed))
                 ;; Single bodyless let followed by body expression — merge
                 ;; (WS reader produces bodyless lets as siblings, with body
                 ;; at same indent level.)
                 (let* ([body (car remaining)]
                        [all-bindings (extract-let-binding-tokens preprocessed)]
                        [merged `(let ,all-bindings ,body)])
                   (loop (cdr remaining) (cons merged acc)))
                 ;; Has body already or no following expr — pass through as-is
                 (loop remaining (cons (car lets) acc)))]
            ;; Multiple lets followed by a non-let body expression —
            ;; treat ALL lets as bodyless bindings, trailing expr is the body.
            ;; This handles WS-mode where body is at the same indent level:
            ;;   let x := 10
            ;;   let y := add x x
            ;;   y              ← not a let, so it's the body
            [(and (pair? remaining)
                  (not (let-form? (car remaining))))
             (define body (car remaining))
             (define all-bindings
               (append-map extract-let-binding-tokens lets))
             (define merged `(let ,all-bindings ,body))
             (loop (cdr remaining) (cons merged acc))]
            ;; Multiple consecutive lets (last has body embedded) — merge
            [else
             (define merged (merge-let-sequence lets))
             (loop remaining (cons merged acc))])]
         [else
          (loop (cdr rest) (cons (car rest) acc))]))]))

;; Pre-process a let form to restructure infix = in value tokens.
;; (let r := a = b) → (let r := (= a b))
;; This makes let-bodyless? work correctly for values containing =.
(define (preprocess-let-infix-eq form)
  (if (not (and (list? form) (pair? form) (eq? (car form) 'let)))
      form
      (let* ([rest (cdr form)]
             [assign-pos (index-of-symbol ':= rest)])
        (if (not assign-pos)
            form
            (let* ([before-and-assign (take rest (+ assign-pos 1))]  ; name ... :=
                   [after-assign (drop rest (+ assign-pos 1))])
              (if (<= (length after-assign) 1)
                  form  ; already single-element value or empty — no restructuring needed
                  (let ([restructured (maybe-restructure-infix-eq after-assign)])
                    (if (equal? restructured after-assign)
                        form  ; no = found in value — leave unchanged
                        `(let ,@before-and-assign ,restructured)))))))))

;; Is this element a let form?
(define (let-form? elem)
  (and (list? elem) (pair? elem) (eq? (car elem) 'let)))

;; Is this let form bodyless? A bodyless let has no body expression.
;; For := format: (let name := value) — no further elements after value.
;; We detect this by: the form has no nested list as last element
;; that could be a body, OR the form only has binding tokens.
;; Simple heuristic: a let with only binding tokens (no body) will have
;; := as the second-to-last element, or will lack a final body form.
(define (let-bodyless? elem)
  (and (let-form? elem)
       (let ([rest (cdr elem)])
         (cond
           ;; (let name := value) — 3 elements in rest, := is second
           [(and (>= (length rest) 3) (eq? (cadr rest) ':=)
                 (= (length rest) 3))
            #t]
           ;; (let name : T1 T2 ... := value) — has := but last is the value, no body
           ;; Count: name : T1 ... := value = even number of "sections"
           ;; Detect by: rest ends right after the value following :=
           [(memq ':= rest)
            ;; Find := position, check if there's exactly one element after it
            (let ([assign-pos (index-of-symbol ':= rest)])
              (and assign-pos (= (length rest) (+ assign-pos 2))))]
           ;; (let [bindings] body) — has body, not bodyless
           ;; (let name value body) — has body, not bodyless
           [else #f]))))

;; Find the index of a symbol in a list
(define (index-of-symbol sym lst)
  (let loop ([i 0] [rest lst])
    (cond
      [(null? rest) #f]
      [(eq? (car rest) sym) i]
      [else (loop (+ i 1) (cdr rest))])))

;; Collect consecutive let forms from the start of a list.
;; Returns (values lets remaining).
(define (collect-consecutive-lets elems)
  (let loop ([rest elems] [lets '()])
    (cond
      [(and (pair? rest) (let-form? (car rest)))
       (loop (cdr rest) (cons (car rest) lets))]
      [else
       (values (reverse lets) rest)])))

;; Merge a sequence of let forms into one let with bracket bindings.
;; All but the last must be bodyless. The last has the body.
;; Returns a single (let (bindings...) body) form.
(define (merge-let-sequence lets)
  (define last-let (last lets))
  (define bodyless-lets (drop-right lets 1))
  ;; Extract bindings from bodyless lets
  (define bindings
    (append-map extract-let-binding-tokens bodyless-lets))
  ;; Extract bindings and body from the last let
  (define-values (last-bindings last-body) (split-last-let last-let))
  ;; Combine all bindings into bracket format
  (define all-bindings (append bindings last-bindings))
  `(let ,all-bindings ,last-body))

;; Extract binding tokens from a bodyless let form.
;; (let name := value) → (name := value)
;; (let name : T := value) → (name : T := value)
(define (extract-let-binding-tokens let-form)
  (cdr let-form))  ; everything after 'let

;; Split the last let in a sequence into (values binding-tokens body).
;; The last let has a body.
(define (split-last-let let-form)
  (define rest (cdr let-form))
  (cond
    ;; := format: find the body (last element after the value)
    [(memq ':= rest)
     ;; For (let name := value body) or (let name : T := value body)
     ;; Body is the last element, bindings are everything else
     (define body (last rest))
     (define binding-tokens (drop-right rest 1))
     (values binding-tokens body)]
    ;; Bracket format: (let [bindings] body) — already has bracket
    [(and (>= (length rest) 2) (list? (car rest)))
     (values (car rest) (cadr rest))]
    ;; Legacy format: (let name value body) — 3 elements
    [(= (length rest) 3)
     (define body (caddr rest))
     (define binding-tokens (list (car rest) ':= (cadr rest)))
     (values binding-tokens body)]
    [else
     ;; Fallback: treat last element as body
     (define body (last rest))
     (define binding-tokens (drop-right rest 1))
     (values binding-tokens body)]))

;; ========================================
;; Foreign escape block combining pass
;; ========================================
;; Merges sibling elements: racket ($brace-params code...) [captures...] -> [exports...]
;; into a single ($foreign-block ...) sentinel form.
;;
;; Input:  (...before... racket ($brace-params c1 c2) (x : Nat) -> (y : Nat) ...after...)
;; Output: (...before... ($foreign-block racket (c1 c2) ((x : Nat)) ((y : Nat))) ...after...)
;;
;; The parser then handles the detailed parsing of captures/exports.

;; Is this element a ($brace-params ...) form?
(define (brace-params? elem)
  (and (pair? elem)
       (let ([h (car elem)])
         (cond
           [(symbol? h) (eq? h '$brace-params)]
           [(syntax? h) (eq? (syntax-e h) '$brace-params)]
           [else #f]))))

;; Is this element a list that looks like a capture/export spec?
;; A capture list is [...] containing (name : Type) patterns.
;; At the datum level, it's a list whose first element is a symbol (not a keyword)
;; and contains the symbol ':'.
(define (capture-or-export-list? elem)
  (and (pair? elem)
       (not (null? elem))
       ;; Must not be a sentinel form ($brace-params, $angle-type, etc.)
       (let ([h (if (syntax? (car elem)) (syntax-e (car elem)) (car elem))])
         (and (symbol? h)
              (not (eq? h '$brace-params))
              (not (eq? h '$angle-type))
              (not (eq? h '$foreign-block))
              (not (eq? h '$quote))
              (not (eq? h '$pipe))
              ;; Must contain ':' somewhere (type annotation)
              (ormap (lambda (e)
                       (let ([v (if (syntax? e) (syntax-e e) e)])
                         (eq? v ':)))
                     elem)))))

;; Is this element the arrow '->' symbol?
(define (arrow-sym? elem)
  (let ([v (if (syntax? elem) (syntax-e elem) elem)])
    (eq? v '->)))

;; Combine foreign escape blocks in a flat element list.
;; Scans for: racket ($brace-params ...) [captures...] -> [exports...]
;; and merges into ($foreign-block racket (code...) (captures...) (exports...))
(define (combine-foreign-blocks elems)
  (if (or (not (list? elems)) (null? elems))
      elems
      (let loop ([rest elems] [acc '()])
        (cond
          [(null? rest) (reverse acc)]
          ;; Detect: racket followed by ($brace-params ...)
          [(and (pair? (cdr rest))
                (let ([v (if (syntax? (car rest)) (syntax-e (car rest)) (car rest))])
                  (eq? v 'racket))
                (let ([next (cadr rest)])
                  (let ([d (if (syntax? next) (syntax-e next) next)])
                    (brace-params? d))))
           (define lang 'racket)
           (define brace-elem (cadr rest))
           (define brace-datum (if (syntax? brace-elem) (syntax-e brace-elem) brace-elem))
           ;; Extract code datums (skip $brace-params sentinel)
           (define code-datums (cdr brace-datum))
           ;; Look ahead for captures and exports
           (define remaining (cddr rest))
           (define-values (captures remaining2)
             (if (and (pair? remaining)
                      (let ([e (car remaining)])
                        (let ([d (if (syntax? e) (syntax-e e) e)])
                          (capture-or-export-list? d))))
                 ;; Next element is a capture list
                 (let ([cap (car remaining)]
                       [cap-datum (let ([e (car remaining)])
                                    (if (syntax? e) (syntax-e e) e))])
                   (values (list cap-datum) (cdr remaining)))
                 (values '() remaining)))
           (define-values (exports remaining3)
             (if (and (pair? remaining2)
                      (arrow-sym? (car remaining2))
                      (pair? (cdr remaining2))
                      (let ([e (cadr remaining2)])
                        (let ([d (if (syntax? e) (syntax-e e) e)])
                          (capture-or-export-list? d))))
                 ;; -> followed by export list
                 (let ([exp (cadr remaining2)]
                       [exp-datum (let ([e (cadr remaining2)])
                                    (if (syntax? e) (syntax-e e) e))])
                   (values (list exp-datum) (cddr remaining2)))
                 (values '() remaining2)))
           ;; Build ($foreign-block racket (code...) (captures...) (exports...))
           (define block `($foreign-block ,lang ,code-datums ,captures ,exports))
           (loop remaining3 (cons block acc))]
          ;; Not a foreign block — pass through
          [else
           (loop (cdr rest) (cons (car rest) acc))]))))

;; Recursively expand subexpressions of a list datum
;; Special handling for $pipe forms: group elements after -> into a single
;; sub-form so pre-parse macros (like let) see the correct structure.
;; Also merges consecutive bodyless let forms (sibling lets) before expansion.
;; Also combines foreign escape blocks (racket { ... } [captures] -> [exports]).
(define (preparse-expand-subforms datum reg depth)
  ;; Zero: rewrite implicit map blocks (:key value children → $brace-params)
  ;; before dot-access/infix, since it reshapes the overall form structure.
  (define map-rewritten (rewrite-implicit-map datum))
  (cond
    [(not (equal? map-rewritten datum))
     (preparse-expand-form map-rewritten reg depth)]
    [else
  ;; First: rewrite all access sentinels (.field, .:kw, #.field, #:kw, [index])
  ;; before infix operators, so that `user.name |> f` desugars correctly.
  ;; Unified handler processes $dot-access, $nil-dot-access, $postfix-index in one pass.
  (define dot-rewritten (rewrite-dot-access datum))
  (cond
    [(not (equal? dot-rewritten datum))
     ;; Access sentinel rewrite happened — re-expand the result through preparse
     ;; (this will re-enter preparse-expand-subforms for further rewrites)
     (if (list? dot-rewritten)
         (preparse-expand-form dot-rewritten reg depth)
         dot-rewritten)]
    [else
  ;; Second: rewrite infix operators (|>, >>) before other expansions
  (define infix-rewritten (rewrite-infix-operators datum))
  (when (not (equal? infix-rewritten datum))
    ;; Infix operator was rewritten — re-expand the result through preparse
    ;; (return early to avoid double-processing)
    (void))
  (cond
    [(not (equal? infix-rewritten datum))
     ;; Infix rewrite happened — re-expand the result
     (preparse-expand-form infix-rewritten reg depth)]
    [else
     ;; No infix rewrite — proceed with normal subform expansion
     (define grouped (maybe-group-pipe-body datum))
     (define foreign-combined (combine-foreign-blocks grouped))
     (define merged (merge-sibling-lets foreign-combined))
     (define expanded
       (map (lambda (sub) (preparse-expand-form sub reg depth))
            merged))
     ;; Return expanded if any transformation changed the datum.
     ;; Compare against original datum (not intermediate) to preserve
     ;; changes from combining passes (foreign blocks, pipe grouping, let merging).
     (if (equal? expanded datum) datum expanded)])])]))

;; For $pipe forms (WS match arms), group body elements after -> into a single list.
;; ($pipe ctor args... -> e1 e2 e3) → ($pipe ctor args... -> (e1 e2 e3))
;; This ensures pre-parse macros like `let` see (let bindings body) correctly.
(define (maybe-group-pipe-body datum)
  (if (and (pair? datum) (eq? (car datum) '$pipe))
      (let ([arrow-idx (for/or ([x (in-list datum)] [i (in-naturals)])
                         (and (eq? x '->) i))])
        (if (and arrow-idx (> (length datum) (+ arrow-idx 2)))
            ;; Multiple body elements after -> : group them
            (let ([before-body (take datum (+ arrow-idx 1))]
                  [body-elems (drop datum (+ arrow-idx 1))])
              (append before-body (list body-elems)))
            ;; Single body element or no -> : leave as-is
            datum))
      datum))

;; ========================================
;; preparse-expand-all: process a list of syntax objects
;; ========================================
;; Handles defmacro and deftype forms (consumes them).
;; Expands all other forms.
;; Returns filtered list of syntax objects.
;; Helper: auto-export a name if a namespace context is active.
;; Does nothing if no ns-context (legacy mode).
(define (auto-export-name! name)
  (when (current-ns-context)
    (current-ns-context
     (ns-context-add-auto-export (current-ns-context) name))))

;; Helper: auto-export multiple names.
(define (auto-export-names! names)
  (for ([name (in-list names)])
    (auto-export-name! name)))

;; Helper: detect private suffix forms (defn-, def-, data-, deftype-, defmacro-).
;; Returns the base keyword symbol (e.g., 'defn for 'defn-) or #f.
(define (private-form-base head)
  (case head
    [(defn-)    'defn]
    [(def-)     'def]
    [(data-)    'data]
    [(deftype-) 'deftype]
    [(defmacro-) 'defmacro]
    [(spec-)    'spec]
    [(trait-)   'trait]
    [(impl-)    'impl]
    [(bundle-)  'bundle]
    [(property-) 'property]
    [(functor-)  'functor]
    [else #f]))

;; Helper: extract the defined name(s) from a top-level form datum.
;; Returns a list of symbols for auto-export.
;;  - defn, def: (cadr datum) is the name
;;  - deftype: (caadr datum) if parameterized, (cadr datum) if bare alias
;;  - defmacro: (cadr datum) (the name symbol)
;;  - data: handled separately (type + constructor names from process-data result)
(define (extract-defined-name datum head)
  (case head
    [(defn def)
     (if (and (>= (length datum) 2) (symbol? (cadr datum)))
         (list (cadr datum))
         '())]
    [(deftype)
     (if (>= (length datum) 2)
         (let ([pattern (cadr datum)])
           (cond
             [(symbol? pattern) (list pattern)]
             [(and (pair? pattern) (symbol? (car pattern))) (list (car pattern))]
             [else '()]))
         '())]
    [(defmacro)
     (if (and (>= (length datum) 2) (symbol? (cadr datum)))
         (list (cadr datum))
         '())]
    [else '()]))

;; Flatten WS-reader sub-lists for keyword-value forms.
;; WS reader wraps each indented line as a sub-list:
;;   ((:tabling by-default) (:timeout 5000))
;; This flattens to: (:tabling by-default :timeout 5000)
;; Only flattens sub-lists whose first element is a keyword-like symbol (:foo).
;; Compound types like (List Nat) are NOT flattened.
(define (flatten-ws-kv-pairs items)
  (apply append
         (for/list ([item (in-list items)])
           (if (and (pair? item) (not (null? item))
                    (let ([head (car item)])
                      (and (symbol? head) (keyword-like-symbol? head))))
               item
               (list item)))))

;; Reconstitute $dot-access chains inside selection vector args into dot-path symbols.
;; The WS reader splits :address.zip into (:address ($dot-access zip)), but the
;; selection parser expects :address.zip as a single keyword-like symbol.
;; This walks the flattened arg list, finds vector args (lists following :requires etc.),
;; and reconstitutes each element that contains $dot-access back into a dot-path keyword.
(define (reconstitute-selection-paths items)
  (let loop ([remaining items] [acc '()])
    (cond
      [(null? remaining) (reverse acc)]
      ;; Any list that isn't a $dot-access sentinel is a vector arg — reconstitute its elements.
      ;; The vector may start with a keyword like (:address ($dot-access zip)),
      ;; so we can't exclude keyword-starting lists.
      [(and (pair? (car remaining))
            (list? (car remaining))
            (not (and (symbol? (caar remaining))
                      (let ([s (symbol->string (caar remaining))])
                        (and (> (string-length s) 1)
                             (char=? (string-ref s 0) #\$))))))
       (loop (cdr remaining)
             (cons (reconstitute-path-list (car remaining)) acc))]
      [else
       (loop (cdr remaining) (cons (car remaining) acc))])))

;; Reconstitute a single vector arg list: each element may be
;; a keyword :name, or a sequence (:address ($dot-access zip)) → :address.zip
(define (reconstitute-path-list items)
  (let loop ([remaining items] [acc '()])
    (cond
      [(null? remaining) (reverse acc)]
      ;; A keyword followed by ($dot-access field) chains — reconstitute
      [(and (keyword-like-symbol? (car remaining))
            (pair? (cdr remaining))
            (let ([next (cadr remaining)])
              (and (pair? next) (eq? (car next) '$dot-access))))
       ;; Collect all consecutive $dot-access segments
       (define base-str (symbol->string (car remaining)))
       (define-values (path-str rest)
         (let collect ([r (cdr remaining)] [segs (list base-str)])
           (if (and (pair? r) (pair? (car r)) (eq? (caar r) '$dot-access))
               (collect (cdr r) (append segs (list (symbol->string (cadar r)))))
               (values (string-join segs ".") r))))
       (loop rest (cons (string->symbol path-str) acc))]
      [else
       (loop (cdr remaining) (cons (car remaining) acc))])))

(define (preparse-expand-all stxs)
  ;; ============================================================
  ;; Pass -1: Process ns/imports declarations FIRST
  ;; ============================================================
  ;; The ns declaration triggers prelude loading, which registers
  ;; all prelude traits (Eq, Ord, Add, etc.) into the trait registry.
  ;; This MUST happen before Pass 0/1, because:
  ;;   - Pass 1 processes `spec` which calls `extract-inline-constraints`
  ;;   - `extract-inline-constraints` uses `lookup-trait` to recognize
  ;;     constraint forms like `(Eq A)`
  ;;   - If prelude traits aren't registered yet, constraints aren't
  ;;     recognized → arity mismatch and missing dict parameters
  ;; Also process imports here so user-specified imports are available.
  (for ([stx (in-list stxs)])
    (define datum (syntax->datum stx))
    (define head (and (pair? datum) (car datum)))
    (when (and (pair? datum) (eq? head 'ns))
      (with-handlers ([exn:fail? void])
        (process-ns-declaration datum)))
    (when (and (pair? datum) (or (eq? head 'imports) (eq? head 'require)))
      (with-handlers ([exn:fail? void])
        (process-imports datum))))

  ;; ============================================================
  ;; Pass 0: Pre-register no-dependency declarations
  ;; ============================================================
  ;; Register all declarations that have NO external reads: data, trait,
  ;; deftype, defmacro, bundle, property, functor. These only WRITE to
  ;; registries (via hash-set → idempotent). Return values (generated
  ;; defs) are discarded — Pass 2 regenerates them into the accumulator.
  ;; This enables later declarations (spec, impl, defn) to find these
  ;; registrations regardless of source ordering.
  (for ([stx (in-list stxs)])
    (define datum (syntax->datum stx))
    (define head (and (pair? datum) (car datum)))
    (define base (and head (private-form-base head)))
    (define eff-head (or base head))
    (define eff-datum (if base (cons base (cdr datum)) datum))
    (with-handlers ([exn:fail? void])
      (case eff-head
        [(data)     (process-data eff-datum)]
        [(trait)    (process-trait eff-datum)]
        [(deftype)  (process-deftype eff-datum)]
        [(defmacro) (process-defmacro eff-datum)]
        [(bundle)   (process-bundle (rewrite-implicit-map eff-datum))]
        [(property) (process-property (rewrite-implicit-map eff-datum))]
        [(functor)  (process-functor (rewrite-implicit-map eff-datum))]
        [(schema)
         ;; Pre-register schema fields so forward references work
         (when (and (list? eff-datum) (>= (length eff-datum) 2) (symbol? (cadr eff-datum)))
           (define sname (cadr eff-datum))
           (define after-name (flatten-ws-kv-pairs (cddr eff-datum)))
           ;; Detect :closed property after schema name
           (define-values (closed? fpairs)
             (if (and (pair? after-name) (eq? (car after-name) ':closed))
                 (values #t (cdr after-name))
                 (values #f after-name)))
           (define-values (flds _auto-subs) (parse-schema-fields fpairs #f sname))
           (register-schema! sname (schema-entry sname flds closed? #f)))]
        [(selection)
         ;; Pre-register selection name so known-type-name? recognizes it during spec processing
         (when (and (list? eff-datum) (>= (length eff-datum) 4)
                    (symbol? (cadr eff-datum))     ;; selection name
                    (eq? (caddr eff-datum) 'from)  ;; 'from' keyword
                    (symbol? (cadddr eff-datum)))  ;; schema name
           (define sel-name (cadr eff-datum))
           (define schema-name (cadddr eff-datum))
           ;; Minimal pre-registration — full validation happens during elaboration
           (register-selection! sel-name (selection-entry sel-name schema-name '() '() '() #f)))]
        [else (void)])))

  ;; ============================================================
  ;; Pass 1: Pre-register declarations that depend on Pass 0
  ;; ============================================================
  ;; spec reads from bundle-registry (where-clause expansion) and
  ;; trait-registry (HKT-2 kind propagation). impl reads from
  ;; trait-registry (lookup-trait). Both are now populated from Pass 0.
  ;; Also safe to re-process in Pass 2 (idempotent hash-set).
  (for ([stx (in-list stxs)])
    (define datum (syntax->datum stx))
    (define head (and (pair? datum) (car datum)))
    (define base (and head (private-form-base head)))
    (define eff-head (or base head))
    (define eff-datum (if base (cons base (cdr datum)) datum))
    (with-handlers ([exn:fail? void])
      (case eff-head
        [(spec) (process-spec eff-datum)
                (maybe-register-trait-dict-def eff-datum)
                ;; Auto-export for public specs only (not spec-)
                (when (and (eq? head 'spec)
                           (list? eff-datum) (>= (length eff-datum) 2)
                           (symbol? (cadr eff-datum)))
                  (auto-export-name! (cadr eff-datum)))]
        [(impl) (process-impl eff-datum)]
        [else (void)])))

  ;; Track names generated by data/trait for Phase 5b reordering.
  ;; After the main loop, data type defs + ctor defs and trait accessor
  ;; defs are hoisted before user forms, so that constructor/accessor
  ;; types are in global-env before any user defn/def is type-checked.
  ;; NOTE: impl-generated defs are NOT hoisted because impl method
  ;; helpers can reference user-defined functions from the same module.
  (define generated-decl-names (make-hasheq))

  (define (mark-generated-names! defs)
    (for ([d (in-list defs)])
      (when (and (list? d) (>= (length d) 2) (symbol? (cadr d)))
        (hash-set! generated-decl-names (cadr d) #t))))

  (define result
    (for/fold ([acc '()])
              ([stx (in-list stxs)])
      (define datum (syntax->datum stx))
      (define head (and (pair? datum) (car datum)))
      (cond
        ;; ns — set namespace context and consume
        [(and (pair? datum) (eq? head 'ns))
         (process-ns-declaration datum)
         acc]
        ;; imports (formerly require) — import module and consume
        [(and (pair? datum) (or (eq? head 'imports) (eq? head 'require)))
         (process-imports datum)
         acc]
        ;; exports (formerly provide) — record exports and consume
        [(and (pair? datum) (or (eq? head 'exports) (eq? head 'provide)))
         (process-exports datum)
         acc]
        ;; foreign — import foreign function binding and consume
        [(and (pair? datum) (eq? head 'foreign))
         (process-foreign datum)
         acc]

        ;; ---- Private suffix forms: defn-, def-, data-, deftype-, defmacro- ----
        ;; Rewrite to the base form but do NOT auto-export.
        [(and (pair? datum) (private-form-base head))
         => (lambda (base)
              (define rewritten (cons base (cdr datum)))
              (cond
                [(eq? base 'defmacro)
                 (process-defmacro rewritten)
                 acc]
                [(eq? base 'deftype)
                 (process-deftype rewritten)
                 acc]
                [(eq? base 'spec)
                 (process-spec rewritten)
                 ;; HKT-3: Auto-register trait dict specs
                 (maybe-register-trait-dict-def rewritten)
                 acc]
                [(eq? base 'data)
                 (define defs (process-data rewritten))
                 (mark-generated-names! defs)
                 (define new-stxs
                   (for/list ([d (in-list defs)])
                     (datum->syntax #f d stx)))
                 (append (reverse new-stxs) acc)]
                [(eq? base 'trait)
                 (define defs (process-trait rewritten))
                 (mark-generated-names! defs)
                 (define new-stxs
                   (for/list ([d (in-list defs)])
                     (datum->syntax #f (preparse-expand-form d) stx)))
                 (append (reverse new-stxs) acc)]
                [(eq? base 'impl)
                 (define defs (process-impl rewritten))
                 (define new-stxs
                   (for/list ([d (in-list defs)])
                     (datum->syntax #f (preparse-expand-form d) stx)))
                 (append (reverse new-stxs) acc)]
                [(eq? base 'bundle)
                 (process-bundle rewritten)
                 acc]
                [(eq? base 'property)
                 (process-property (rewrite-implicit-map rewritten))
                 acc]
                [(eq? base 'functor)
                 (process-functor (rewrite-implicit-map rewritten))
                 acc]
                [(eq? base 'specialize)
                 (define defs (process-specialize rewritten))
                 ;; Process each output defn through spec injection + preparse
                 (define new-stxs
                   (for/list ([d (in-list defs)])
                     (define injected (if (and (pair? d) (eq? (car d) 'defn))
                                          (maybe-inject-spec d)
                                          d))
                     (datum->syntax #f (preparse-expand-form injected) stx)))
                 (append (reverse new-stxs) acc)]
                ;; def- or defn- — rewrite head, preserving child syntax properties
                [else
                 ;; HKT-3: Auto-register trait dict defs
                 (maybe-register-trait-dict-def rewritten)
                 ;; Replace just the head symbol in the syntax list to preserve
                 ;; properties like paren-shape on child nodes (e.g., [params]).
                 (define children (if (syntax? stx) (syntax->list stx) #f))
                 (define new-stx
                   (if children
                       ;; Replace head syntax object, keep remaining children
                       (datum->syntax stx (cons (datum->syntax (car children) base (car children))
                                                (cdr children))
                                      stx)
                       ;; Fallback: pure datum
                       (datum->syntax #f rewritten stx)))
                 ;; Step 0: group flat $pipe tokens in defn- (WS reader produces flat form)
                 (define grouped-d
                   (let ([d (syntax->datum new-stx)])
                     (if (eq? base 'defn) (group-defn-pipes d) d)))
                 ;; Expand := syntax for def- (before spec injection)
                 (define pre-datum
                   (if (and (eq? base 'def) (memq ':= grouped-d))
                       (expand-def-assign grouped-d)
                       grouped-d))
                 ;; Inject spec type into bare-param defn- if matching spec exists
                 (define maybe-injected
                   (if (eq? base 'defn) (maybe-inject-spec pre-datum) pre-datum))
                 ;; Inject spec type into def- if matching spec exists
                 (define maybe-spec-injected
                   (if (eq? base 'def) (maybe-inject-spec-def maybe-injected) maybe-injected))
                 ;; Inject where-clause constraints (defn only)
                 (define maybe-where-injected
                   (if (and (pair? maybe-spec-injected)
                            (eq? (car maybe-spec-injected) 'defn)
                            (memq 'where maybe-spec-injected))
                       (maybe-inject-where maybe-spec-injected)
                       maybe-spec-injected))
                 (define expanded (preparse-expand-form maybe-where-injected))
                 (if (equal? expanded maybe-where-injected)
                     (cons (datum->syntax #f maybe-where-injected stx) acc)
                     (cons (datum->syntax #f expanded stx) acc))]))]

        ;; ---- Public defmacro — register, consume, AND auto-export ----
        [(and (pair? datum) (eq? head 'defmacro))
         (process-defmacro datum)
         (auto-export-names! (extract-defined-name datum 'defmacro))
         acc]
        ;; ---- Public deftype — register, consume, AND auto-export ----
        [(and (pair? datum) (eq? head 'deftype))
         (process-deftype datum)
         (auto-export-names! (extract-defined-name datum 'deftype))
         acc]
        ;; ---- Public spec — register type spec, consume, AND auto-export ----
        [(and (pair? datum) (eq? head 'spec))
         (process-spec datum)
         ;; HKT-3: Auto-register trait dict specs in impl registry
         (maybe-register-trait-dict-def datum)
         (when (and (list? datum) (>= (length datum) 2) (symbol? (cadr datum)))
           (auto-export-name! (cadr datum)))
         acc]
        ;; ---- Public data — generate defs, auto-export type + constructors ----
        [(and (pair? datum) (eq? head 'data))
         (define defs (process-data datum))
         (mark-generated-names! defs)
         ;; Auto-export: type name + all constructor names from generated defs
         (for ([d (in-list defs)])
           (when (and (list? d) (>= (length d) 2) (symbol? (cadr d)))
             (auto-export-name! (cadr d))))
         ;; Convert each def to a syntax object and add to accumulator
         (define new-stxs
           (for/list ([d (in-list defs)])
             (datum->syntax #f d stx)))
         (append (reverse new-stxs) acc)]
        ;; ---- Public trait — generate deftype + accessor defs, auto-export ----
        [(and (pair? datum) (eq? head 'trait))
         (define defs (process-trait datum))
         (mark-generated-names! defs)
         ;; Auto-export: trait name + accessor names
         (define tname (let ([h (cadr datum)])
                         (if (symbol? h) h (and (pair? h) (car h)))))
         (when tname (auto-export-name! tname))
         (for ([d (in-list defs)])
           (when (and (list? d) (>= (length d) 2) (symbol? (cadr d)))
             (auto-export-name! (cadr d))))
         ;; Convert accessor defs to syntax objects (expand sub-forms for deftype macros)
         (define new-stxs
           (for/list ([d (in-list defs)])
             (datum->syntax #f (preparse-expand-form d) stx)))
         (append (reverse new-stxs) acc)]
        ;; ---- Public impl — generate dict + method defs, auto-export ----
        [(and (pair? datum) (eq? head 'impl))
         (define defs (process-impl datum))
         ;; Auto-export: dict name + method helper names
         (for ([d (in-list defs)])
           (when (and (list? d) (>= (length d) 2) (symbol? (cadr d)))
             (auto-export-name! (cadr d))))
         ;; Convert defs to syntax objects (expand sub-forms for deftype macros)
         (define new-stxs
           (for/list ([d (in-list defs)])
             (datum->syntax #f (preparse-expand-form d) stx)))
         (append (reverse new-stxs) acc)]
        ;; ---- Public bundle — register, consume, AND auto-export name ----
        [(and (pair? datum) (eq? head 'bundle))
         (process-bundle datum)
         (when (and (list? datum) (>= (length datum) 2) (symbol? (cadr datum)))
           (auto-export-name! (cadr datum)))
         acc]
        ;; ---- Public property — register, consume, AND auto-export name ----
        [(and (pair? datum) (eq? head 'property))
         (process-property (rewrite-implicit-map datum))
         (when (and (list? datum) (>= (length datum) 2) (symbol? (cadr datum)))
           (auto-export-name! (cadr datum)))
         acc]
        ;; ---- Public functor — register, consume, AND auto-export name ----
        [(and (pair? datum) (eq? head 'functor))
         (process-functor (rewrite-implicit-map datum))
         (when (and (list? datum) (>= (length datum) 2) (symbol? (cadr datum)))
           (auto-export-name! (cadr datum)))
         acc]
        ;; ---- precedence-group — register, consume ----
        [(and (pair? datum) (eq? head 'precedence-group))
         (process-precedence-group datum)
         acc]
        ;; ---- Public specialize — register specialization, emit specialized defn ----
        [(and (pair? datum) (eq? head 'specialize))
         (define defs (process-specialize datum))
         ;; Auto-export the specialized function name
         (for ([d (in-list defs)])
           (when (and (list? d) (>= (length d) 2) (symbol? (cadr d)))
             (auto-export-name! (cadr d))))
         ;; Process each output defn through spec injection + preparse
         (define new-stxs
           (for/list ([d (in-list defs)])
             (define injected (if (and (pair? d) (eq? (car d) 'defn))
                                  (maybe-inject-spec d)
                                  d))
             (datum->syntax #f (preparse-expand-form injected) stx)))
         (append (reverse new-stxs) acc)]
        ;; ---- Public defr — auto-export the relation name, pass through ----
        [(and (pair? datum) (eq? head 'defr))
         (when (and (list? datum) (>= (length datum) 2) (symbol? (cadr datum)))
           (auto-export-name! (cadr datum)))
         (define expanded (preparse-expand-form datum))
         (if (equal? expanded datum)
             (cons stx acc)
             (cons (datum->syntax #f expanded stx) acc))]
        ;; ---- Public solver — expand to (def name ($solver-config ...)), auto-export ----
        [(and (pair? datum) (eq? head 'solver))
         ;; (solver name :key val ...) → (def name ($solver-config :key val ...))
         ;; $solver-config sentinel makes the parser produce a surf-solver,
         ;; which the elaborator converts to expr-solver-config with a proper
         ;; solver-config struct. Values are treated as symbol literals.
         (unless (and (list? datum) (>= (length datum) 2) (symbol? (cadr datum)))
           (error 'solver "solver requires: (solver name :key val ...)"))
         (define sname (cadr datum))
         (auto-export-name! sname)
         (define opts (flatten-ws-kv-pairs (cddr datum)))
         ;; Wrap as: (def name ($solver-config :key val ...))
         (define expanded `(def ,sname ($solver-config ,@opts)))
         (define new-stx (datum->syntax #f (preparse-expand-form expanded) stx))
         (cons new-stx acc)]
        ;; ---- Public schema — parse fields, register, emit as named type, auto-export ----
        [(and (pair? datum) (eq? head 'schema))
         ;; (schema Name [:closed] :field1 Type1 :field2 Type2 ...) → register + (def Name : (Type 0) (Type 0))
         (unless (and (list? datum) (>= (length datum) 2) (symbol? (cadr datum)))
           (error 'schema "schema requires: (schema Name :field1 Type1 ...)"))
         (define schema-name (cadr datum))
         (auto-export-name! schema-name)
         (define after-name (flatten-ws-kv-pairs (cddr datum)))
         ;; Detect :closed property after schema name
         (define-values (closed? field-pairs)
           (if (and (pair? after-name) (eq? (car after-name) ':closed))
               (values #t (cdr after-name))
               (values #f after-name)))
         ;; Parse and register schema fields — qualify user-defined type names
         (define-values (fields-raw auto-sub-schemas)
           (parse-schema-fields field-pairs (syntax->datum stx) schema-name))
         (define ns-ctx (current-ns-context))
         (define fields
           (if ns-ctx
               (map (lambda (f)
                      (schema-field (schema-field-keyword f)
                                    (qualify-type-datum (schema-field-type-datum f) ns-ctx)
                                    (schema-field-default-val f)
                                    (schema-field-check-pred f)))
                    fields-raw)
               fields-raw))
         (register-schema! schema-name
                           (schema-entry schema-name fields closed? (syntax->datum stx)))
         ;; Emit schema name as an opaque type in global-env (same pattern as data types).
         ;; The def form (def Name : (Type 0) (Type 0)) creates an fvar with Type 0 type.
         ;; Actual field checking is done in typing-core.rkt via schema registry lookups.
         ;; First emit type defs for any auto-generated sub-schemas
         (define sub-defs
           (for/list ([sub-name (in-list auto-sub-schemas)])
             (datum->syntax #f `(def ,sub-name : (Type 0) (Type 0)) stx)))
         (define type-def `(def ,schema-name : (Type 0) (Type 0)))
         (define all-defs (append sub-defs (list (datum->syntax #f type-def stx))))
         (append (reverse all-defs) acc)]
        ;; ---- Selection declaration — flatten WS-grouped kv-pairs, then pass through ----
        [(and (pair? datum) (eq? head 'selection))
         ;; WS reader produces: (selection Name from Schema (:requires (:name :age)) ...)
         ;; Parser expects:      (selection Name from Schema :requires (:name :age) ...)
         ;; Sexp input is already flat: (selection Name from Schema :requires (:name :age) ...)
         ;; Only flatten+reconstitute when WS grouping is detected.
         (if (and (list? datum) (>= (length datum) 4))
             (let* ([prefix (list 'selection (second datum) (third datum) (fourth datum))]
                    [rest-ws (list-tail datum 4)]
                    ;; Detect WS grouping: if first rest element is a list starting with
                    ;; a keyword, it's WS-wrapped; if it's a bare keyword, already flat.
                    [ws-grouped? (and (pair? rest-ws)
                                      (pair? (car rest-ws))
                                      (symbol? (caar rest-ws))
                                      (keyword-like-symbol? (caar rest-ws)))]
                    [flattened (if ws-grouped?
                                   (flatten-ws-kv-pairs rest-ws)
                                   rest-ws)]
                    ;; Reconstitute $dot-access chains inside vector args into dot-paths
                    [reconstituted (reconstitute-selection-paths flattened)]
                    [new-datum (append prefix reconstituted)])
               (cons (datum->syntax #f new-datum stx) acc))
             (cons stx acc))]
        ;; ---- Session type declaration — desugar WS-mode body to sexp form (Phase S1d) ----
        [(and (pair? datum) (eq? head 'session))
         (when (and (list? datum) (>= (length datum) 2) (symbol? (cadr datum)))
           (auto-export-name! (cadr datum)))
         (define desugared (desugar-session-ws datum))
         (cons (datum->syntax #f desugared stx) acc)]
        ;; ---- Process declaration — desugar WS-mode body to sexp form (Phase S2c) ----
        [(and (pair? datum) (eq? head 'defproc))
         (when (and (list? datum) (>= (length datum) 2) (symbol? (cadr datum)))
           (auto-export-name! (cadr datum)))
         (define desugared (desugar-defproc-ws datum))
         (cons (datum->syntax #f desugared stx) acc)]
        ;; ---- Anonymous process — desugar WS-mode body (Phase S2c) ----
        [(and (pair? datum) (eq? head 'proc))
         (define desugared (desugar-proc-ws datum))
         (cons (datum->syntax #f desugared stx) acc)]
        ;; ---- Spawn command — pass through (Phase S7c) ----
        ;; (spawn name) or (spawn (proc ...)) — no WS desugaring needed
        [(and (pair? datum) (eq? head 'spawn))
         (cons stx acc)]
        ;; ---- Spawn-with command — pass through (Phase S7d) ----
        ;; (spawn-with strat {overrides} target) — no WS desugaring needed
        [(and (pair? datum) (eq? head 'spawn-with))
         (cons stx acc)]
        ;; ---- Strategy declaration — desugar WS-mode props, pass to parser (Phase S6) ----
        [(and (pair? datum) (eq? head 'strategy))
         (when (and (list? datum) (>= (length datum) 2) (symbol? (cadr datum)))
           (auto-export-name! (cadr datum)))
         (define desugared (desugar-strategy-ws datum))
         (cons (datum->syntax #f desugared stx) acc)]
        ;; ---- Public defn/def — auto-export the name ----
        [(and (pair? datum) (memq head '(defn def)))
         (auto-export-names! (extract-defined-name datum head))
         ;; HKT-3: Auto-register trait dict defs in impl registry
         (maybe-register-trait-dict-def datum)
         ;; Step 0: group flat $pipe tokens in defn (WS reader produces flat form)
         (define grouped-datum
           (if (eq? head 'defn) (group-defn-pipes datum) datum))
         ;; Step 1: expand := syntax for def (before spec injection)
         (define pre-datum
           (if (and (eq? (car grouped-datum) 'def) (memq ':= grouped-datum))
               (expand-def-assign grouped-datum)
               grouped-datum))
         ;; Step 2: inject spec type (defn or def)
         (define maybe-injected
           (cond
             [(eq? (car pre-datum) 'defn) (maybe-inject-spec pre-datum)]
             [(eq? (car pre-datum) 'def)  (maybe-inject-spec-def pre-datum)]
             [else pre-datum]))
         ;; Step 3: inject where-clause constraints (defn only)
         (define maybe-where-injected
           (if (and (pair? maybe-injected)
                    (eq? (car maybe-injected) 'defn)
                    (memq 'where maybe-injected))
               (maybe-inject-where maybe-injected)
               maybe-injected))
         (define expanded (preparse-expand-form maybe-where-injected))
         (if (equal? expanded maybe-where-injected)
             (if (equal? maybe-where-injected datum)
                 (cons stx acc)
                 (cons (datum->syntax #f maybe-where-injected stx) acc))
             (cons (datum->syntax #f expanded stx) acc))]
        ;; ---- Public capability — auto-export the capability type name (IO-D5) ----
        [(and (pair? datum) (eq? head 'capability))
         (when (and (list? datum) (>= (length datum) 2) (symbol? (cadr datum)))
           (auto-export-name! (cadr datum)))
         (cons stx acc)]
        ;; Regular form — expand
        [else
         (define expanded (preparse-expand-form datum))
         ;; If datum didn't change, preserve original syntax (keeps properties like paren-shape)
         (if (equal? expanded datum)
             (cons stx acc)
             (cons (datum->syntax #f expanded stx) acc))])))
  ;; ============================================================
  ;; Phase 5b: Hoist data/trait-generated defs before user forms
  ;; ============================================================
  ;; Stable partition: forms whose name was generated by data/trait are
  ;; hoisted to the front (preserving relative order within each group).
  ;; This ensures constructor types and trait accessor types enter
  ;; global-env (via process-command) BEFORE any user defn/def is
  ;; type-checked — enabling forward references to later data/trait.
  ;; NOTE: impl-generated defs are NOT hoisted because impl method
  ;; helpers can reference user-defined functions from the same module.
  (define all-forms (reverse result))
  (if (hash-empty? generated-decl-names)
      all-forms  ;; fast path: no data/trait/impl declarations
      (let-values ([(decl-forms user-forms)
                    (partition
                     (lambda (stx)
                       (define datum (syntax->datum stx))
                       ;; Only hoist DEFINITION forms (def/defn/spec) whose name
                       ;; was generated by data/trait. Without the head check,
                       ;; function calls like [direction-name North] would be
                       ;; hoisted because North is a generated constructor name.
                       (and (pair? datum)
                            (>= (length datum) 2)
                            (memq (car datum) '(def defn spec deftype))
                            (symbol? (cadr datum))
                            (hash-has-key? generated-decl-names (cadr datum))))
                     all-forms)])
        (append decl-forms user-forms))))

;; ========================================
;; process-defmacro: register a user macro
;; ========================================
;; (defmacro name ($param ...) template)
;; Pattern variables use $-prefixed symbols: $x, $body, $args
;; These are read as plain symbols by the reader (no normalization needed).
(define (process-defmacro datum)
  (unless (and (list? datum) (= (length datum) 4))
    (error 'defmacro "defmacro requires: (defmacro name ($params...) template)"))
  (define macro-name (cadr datum))
  (unless (symbol? macro-name)
    (error 'defmacro "defmacro: name must be a symbol, got ~a" macro-name))
  (define params (caddr datum))
  (define template (cadddr datum))
  (define pattern (if (list? params) (cons macro-name params) (list macro-name params)))
  (register-preparse-macro! macro-name (preparse-macro macro-name pattern template)))

;; ========================================
;; process-deftype: register a type alias
;; ========================================
;; (deftype Name body) — simple alias
;; (deftype (Name $A $B ...) body) — parameterized alias
;; Pattern variables use $-prefixed symbols: $A, $B
(define (process-deftype datum)
  (unless (and (list? datum) (= (length datum) 3))
    (error 'deftype "deftype requires: (deftype name-or-pattern body)"))
  (define pattern (cadr datum))
  (define body (caddr datum))
  (cond
    [(symbol? pattern)
     ;; Simple alias: bare symbol expands to body
     ;; Register as procedural macro that ignores the input datum
     (register-preparse-macro! pattern (lambda (_) body))]
    [(pair? pattern)
     ;; Parameterized: (Name $A $B) body → pattern-template macro
     (define macro-name (car pattern))
     (register-preparse-macro! macro-name (preparse-macro macro-name pattern body))]
    [else
     (error 'deftype "deftype: expected name or (name params...) pattern")]))

;; ========================================
;; extract-where-clause: split tokens on 'where keyword
;; ========================================
;; Returns (values type-tokens where-constraints)
;; where-constraints: list of parenthesized constraint forms, e.g., ((Eq A) (Ord A))
;; type-tokens: everything before 'where
;; If no 'where found, returns the original tokens and '().
;;
;; Handles:
;;   spec eq-neq A A -> Bool where (Eq A)
;;   spec sort List A -> List A where (Ord A) (Eq A)
;;   spec foo Nat -> Nat                                  ← no where
(define (extract-where-clause tokens)
  (define idx (index-where tokens (lambda (t) (eq? t 'where))))
  (if idx
      (let ([type-part (take tokens idx)]
            [where-part (drop tokens (add1 idx))])
        ;; where-part should be a sequence of parenthesized constraint forms
        ;; Each constraint is a list like (Eq A) or (Ord A B)
        (define constraints
          (filter list? where-part))
        (when (null? constraints)
          (error 'where "where clause has no constraints"))
        ;; Check for non-list tokens after where (error)
        (define non-list-tokens (filter (lambda (t) (not (list? t))) where-part))
        (when (not (null? non-list-tokens))
          (error 'where "unexpected tokens after where: ~a (constraints must be parenthesized)"
                 non-list-tokens))
        (values type-part constraints))
      (values tokens '())))

;; ========================================
;; HKT-2: Kind propagation from where-constraints to implicit binders
;; ========================================
;; When a spec has {C} and [Seqable C] in its where clause, and Seqable is
;; registered as a trait with {C : Type -> Type}, we refine C's kind from
;; the default (Type 0) to (-> (Type 0) (Type 0)).
;;
;; Algorithm:
;; 1. For each where-constraint (TraitName Var1 Var2 ...):
;;    a. Look up TraitName in the trait registry
;;    b. Get the trait's declared params: ((C . kind) ...)
;;    c. For each (Var_i, TraitParam_i), if Var_i is in brace-params
;;       and its current kind is the default (Type 0), upgrade to trait's kind
;; 2. If the same variable gets different kinds from different constraints, error.

(define (propagate-kinds-from-constraints brace-params where-constraints spec-name)
  ;; Build a mutable table from brace-params
  (define param-table (make-hasheq))
  (for ([bp (in-list brace-params)])
    (hash-set! param-table (car bp) (cdr bp)))

  (for ([wc (in-list where-constraints)])
    (when (and (pair? wc) (>= (length wc) 2))
      (define trait-name (car wc))
      (define constraint-vars (cdr wc))
      (define tm (lookup-trait trait-name))
      (when tm
        (define trait-params (trait-meta-params tm))
        ;; Match constraint vars to trait params positionally
        (for ([cv (in-list constraint-vars)]
              [tp (in-list trait-params)]
              #:when (and (symbol? cv) (hash-has-key? param-table cv)))
          (define current-kind (hash-ref param-table cv))
          ;; trait-params may be (name . kind) pairs or bare symbols
          (define trait-kind (if (pair? tp) (cdr tp) '(Type 0)))
          (cond
            ;; Current kind is default (Type 0) — upgrade to trait's kind
            [(equal? current-kind '(Type 0))
             (hash-set! param-table cv trait-kind)]
            ;; Current kind already set and matches — no action
            [(equal? current-kind trait-kind)
             (void)]
            ;; Current kind conflicts — error
            [else
             (error 'spec
               "~a: kind mismatch for ~a: constraint ~a requires kind ~a, but ~a"
               spec-name cv trait-name
               (datum->kind-string trait-kind)
               (if (equal? current-kind '(Type 0))
                   "default is Type"
                   (format "already inferred ~a" (datum->kind-string current-kind))))])))))

  ;; Rebuild brace-params list with updated kinds (preserving order)
  (for/list ([bp (in-list brace-params)])
    (cons (car bp) (hash-ref param-table (car bp)))))

;; Extract inline constraint forms from type tokens.
;; Scans leading list forms before the first -> that look like trait constraints.
;; A constraint has the form (TraitName Var ...) where TraitName is a registered trait.
;; Returns a list of constraint forms suitable for propagate-kinds-from-constraints.
;;
;; Example: ((Seqable C) -> (C A) -> (LSeq A)) → ((Seqable C))
;; Example: ((Seqable C) (Buildable C) -> ...) → ((Seqable C) (Buildable C))
;; Example: (Nat -> Nat) → ()
(define (extract-inline-constraints tokens)
  ;; Scan leading tokens, collecting trait-constraint forms.
  ;; Constraint forms like (Eq A) may be separated by -> arrows:
  ;;   (Eq A) -> (Add A) -> A -> A -> Bool
  ;; We skip over -> arrows and keep collecting constraints until we
  ;; see a non-constraint form after an arrow.
  (let loop ([remaining tokens] [constraints '()])
    (cond
      [(null? remaining) (reverse constraints)]
      ;; Skip arrow tokens — constraints may be separated by ->
      [(eq? (car remaining) '->) (loop (cdr remaining) constraints)]
      ;; Check if this token is a list form (TraitName Var ...)
      [(and (pair? (car remaining))
            (let ([head (car (car remaining))])
              (and (symbol? head)
                   ;; Check if head is a registered trait
                   (lookup-trait head))))
       (loop (cdr remaining) (cons (car remaining) constraints))]
      ;; Non-constraint form — stop scanning
      ;; (don't look past non-constraint forms)
      [else (reverse constraints)])))

;; Format a kind datum as a readable string for error messages
(define (datum->kind-string d)
  (cond
    [(equal? d '(Type 0)) "Type"]
    [(and (list? d) (eq? (car d) '->) (= (length d) 3))
     (format "~a -> ~a" (datum->kind-string (cadr d)) (datum->kind-string (caddr d)))]
    [else (format "~a" d)]))

;; ========================================
;; extract-implicit-binders: extract leading {A B : Type} from spec tokens
;; ========================================
;; Scans for leading ($brace-params ...) groups in spec body tokens.
;; Returns (values implicit-binders remaining-tokens)
;; implicit-binders: alist of ((name . kind) ...) — same format as parse-brace-param-list
;; remaining-tokens: the type tokens with brace groups removed
;;
;; Example: (($brace-params A B) ($brace-params R : Type) Nat -> Nat)
;;        → (values ((A . (Type 0)) (B . (Type 0)) (R . (Type 0))) (Nat -> Nat))
(define (extract-implicit-binders tokens spec-name)
  (let loop ([remaining tokens] [binders '()])
    (cond
      [(null? remaining)
       (values (reverse binders) remaining)]
      [(and (pair? (car remaining))
            (let ([h (car (car remaining))])
              (cond
                [(symbol? h) (eq? h '$brace-params)]
                [(syntax? h) (eq? (syntax-e h) '$brace-params)]
                [else #f])))
       ;; Found a ($brace-params ...) group — check if it's a metadata block
       (define brace-datum (car remaining))
       (define symbols (cdr brace-datum))
       (if (and (pair? symbols) (keyword-like-symbol? (car symbols)))
           ;; This is a metadata block, not implicit binders — stop here
           (values (reverse binders) remaining)
           ;; Normal brace-params group — parse as implicit binders
           (let ([parsed (parse-brace-param-list symbols spec-name)])
             (loop (cdr remaining) (append (reverse parsed) binders))))]
      [else
       (values (reverse binders) remaining)])))

;; ========================================
;; parse-spec-metadata: parse trailing {kw val ...} block into hasheq
;; ========================================
;; Parses a ($brace-params ...) form containing keyword-value pairs into a hash.
;; Recognized keys:
;;   :where   → collect parenthesized constraint forms via collect-constraint-values
;;   :implicits → collect $brace-params groups via collect-brace-groups
;;   :properties → collect parenthesized constraint forms via collect-constraint-values
;;   :see-also → stored as-is
;;   default  → stored as-is
;;   key with no value → #t (boolean flag)

;; collect-constraint-values: collect parenthesized forms from a kv tail until next keyword.
;; Example: (:where (Eq A) (Ord A) :doc "foo") → (values ((Eq A) (Ord A)) (:doc "foo"))
(define (collect-constraint-values tail)
  (let loop ([rest tail] [acc '()])
    (cond
      [(null? rest)
       (values (reverse acc) '())]
      [(and (pair? (car rest)) (not (keyword-like-symbol? (car rest))))
       (loop (cdr rest) (cons (car rest) acc))]
      [else
       (values (reverse acc) rest)])))

;; collect-brace-groups: collect ($brace-params ...) groups from a kv tail until next keyword.
;; Example: (:implicits ($brace-params A B) ($brace-params C : Type) :doc "foo")
;;        → (values (($brace-params A B) ($brace-params C : Type)) (:doc "foo"))
(define (collect-brace-groups tail)
  (let loop ([rest tail] [acc '()])
    (cond
      [(null? rest)
       (values (reverse acc) '())]
      [(and (pair? (car rest))
            ;; Check for $brace-params sentinel at head of the form
            (let ([h (car (car rest))])
              (cond
                [(symbol? h) (eq? h '$brace-params)]
                [(syntax? h) (eq? (syntax-e h) '$brace-params)]
                [else #f])))
       (loop (cdr rest) (cons (car rest) acc))]
      [else
       (values (reverse acc) rest)])))

(define (parse-spec-metadata brace-datum)
  ;; brace-datum is ($brace-params :key1 val1 :key2 val2 ...)
  (define kv-list (cdr brace-datum))
  (let loop ([remaining kv-list] [result (hasheq)])
    (cond
      [(null? remaining) result]
      [(keyword-like-symbol? (car remaining))
       (define key (car remaining))
       (define tail (cdr remaining))
       (cond
         ;; :where → collect constraint values
         [(eq? key ':where)
          (define-values (constraints rest) (collect-constraint-values tail))
          (loop rest (hash-set result key constraints))]
         ;; :implicits → collect brace groups
         [(eq? key ':implicits)
          (define-values (groups rest) (collect-brace-groups tail))
          (loop rest (hash-set result key groups))]
         ;; :properties → collect constraint values
         [(eq? key ':properties)
          (define-values (constraints rest) (collect-constraint-values tail))
          (loop rest (hash-set result key constraints))]
         ;; :laws → collect constraint values (law references are parenthesized forms)
         [(eq? key ':laws)
          (define-values (constraints rest) (collect-constraint-values tail))
          (loop rest (hash-set result key constraints))]
         ;; :includes → collect constraint values (included property references)
         [(eq? key ':includes)
          (define-values (constraints rest) (collect-constraint-values tail))
          (loop rest (hash-set result key constraints))]
         ;; :examples → collect parenthesized example forms (datum => datum)
         [(eq? key ':examples)
          (define-values (examples rest) (collect-constraint-values tail))
          (loop rest (hash-set result key examples))]
         ;; :see-also → collect parenthesized symbol references
         [(eq? key ':see-also)
          (define-values (refs rest) (collect-constraint-values tail))
          (loop rest (hash-set result key refs))]
         ;; :over → single symbol (trait variable name for HasMethod abstraction)
         [(eq? key ':over)
          (if (and (pair? tail) (symbol? (car tail)))
              (loop (cdr tail) (hash-set result key (car tail)))
              (error 'spec ":over requires a trait variable name"))]
         ;; :method → TraitVar method-name : Type...
         ;; Collects tokens until next :keyword or end, parses into (trait-var method-name type-tokens)
         [(eq? key ':method)
          (unless (and (pair? tail) (symbol? (car tail))
                       (pair? (cdr tail)) (symbol? (cadr tail)))
            (error 'spec ":method requires: :method TraitVar method-name : Type..."))
          (define trait-var (car tail))
          (define method-name (cadr tail))
          (define after-name (cddr tail))
          ;; Skip optional colon
          (define type-start
            (if (and (pair? after-name) (eq? (car after-name) ':))
                (cdr after-name)
                after-name))
          ;; Collect type tokens until next keyword or end
          (define-values (type-tokens rest)
            (let collect ([remaining type-start] [acc '()])
              (cond
                [(null? remaining) (values (reverse acc) '())]
                [(keyword-like-symbol? (car remaining))
                 (values (reverse acc) remaining)]
                [else (collect (cdr remaining) (cons (car remaining) acc))])))
          (when (null? type-tokens)
            (error 'spec ":method ~a ~a requires a type signature" trait-var method-name))
          (define entry (list trait-var method-name type-tokens))
          (define existing (hash-ref result key '()))
          (loop rest (hash-set result key (append existing (list entry))))]
         ;; :pre → predicate expression on function args (Phase 2: runtime contract)
         [(eq? key ':pre)
          (if (null? tail)
              (error 'spec ":pre requires a predicate expression")
              (loop (cdr tail) (hash-set result key (car tail))))]
         ;; :post → predicate expression on args + return (Phase 2: runtime contract)
         [(eq? key ':post)
          (if (null? tail)
              (error 'spec ":post requires a predicate expression")
              (loop (cdr tail) (hash-set result key (car tail))))]
         ;; :invariant → relational predicate on args + return (Phase 2: runtime contract)
         [(eq? key ':invariant)
          (if (null? tail)
              (error 'spec ":invariant requires a predicate expression")
              (loop (cdr tail) (hash-set result key (car tail))))]
         ;; :variance → functor variance annotation (:covariant, :contravariant, :invariant, :phantom)
         [(eq? key ':variance)
          (if (and (pair? tail) (memq (car tail) '(:covariant :contravariant :invariant :phantom)))
              (loop (cdr tail) (hash-set result key (car tail)))
              (error 'functor ":variance must be :covariant, :contravariant, :invariant, or :phantom"))]
         ;; :fold → identifier for catamorphism (recursion scheme)
         [(eq? key ':fold)
          (if (and (pair? tail) (symbol? (car tail)))
              (loop (cdr tail) (hash-set result key (car tail)))
              (error 'functor ":fold requires an identifier"))]
         ;; :unfold → identifier for anamorphism (recursion scheme, distinct from :unfolds)
         [(eq? key ':unfold)
          (if (and (pair? tail) (symbol? (car tail)))
              (loop (cdr tail) (hash-set result key (car tail)))
              (error 'functor ":unfold requires an identifier"))]
         ;; :mixfix → next value should be a $brace-params map {:symbol op :group grp}
         [(eq? key ':mixfix)
          (if (and (pair? tail) (pair? (car tail))
                   (eq? (caar tail) '$brace-params))
              ;; Parse the mixfix metadata map
              (let ([mixfix-map (parse-spec-metadata (car tail))])
                (loop (cdr tail) (hash-set result key mixfix-map)))
              ;; Take next value as-is (fallback)
              (loop (cdr tail) (hash-set result key (car tail))))]
         ;; Key with no following value (or next is also a keyword) → boolean flag
         [(or (null? tail) (keyword-like-symbol? (car tail)))
          (loop tail (hash-set result key #t))]
         ;; Default: take next value as-is
         [else
          (loop (cdr tail) (hash-set result key (car tail)))])]
      ;; Skip non-keyword elements (shouldn't happen in well-formed metadata)
      [else (loop (cdr remaining) result)])))

;; ========================================
;; extract-implicits-from-metadata: parse :implicits into binder alist
;; ========================================
;; Takes the :implicits value (list of $brace-params groups) from metadata
;; and converts to the same binder alist format as extract-implicit-binders.
(define (extract-implicits-from-metadata groups name)
  (apply append
         (for/list ([g (in-list groups)])
           (define symbols
             (if (and (pair? g) (let ([h (car g)])
                                  (cond
                                    [(symbol? h) (eq? h '$brace-params)]
                                    [(syntax? h) (eq? (syntax-e h) '$brace-params)]
                                    [else #f])))
                 (cdr g)
                 ;; Bare group without sentinel — treat as raw symbols
                 (list g)))
           (parse-brace-param-list symbols name))))

;; ========================================
;; deduplicate-binders: merge inline + metadata binders with dedup
;; ========================================
;; If a binder appears in both inline and metadata, keep the inline one
;; and warn to stderr about the duplicate.
(define (deduplicate-binders inline-binders meta-binders)
  (define inline-names (map car inline-binders))
  (define inline-lookup
    (for/hasheq ([b (in-list inline-binders)])
      (values (car b) (cdr b))))
  (define unique-meta
    (filter (lambda (b)
              (define name (car b))
              (if (memq name inline-names)
                  (let ([inline-kind (hash-ref inline-lookup name)]
                        [meta-kind (cdr b)])
                    ;; G2: Error on kind disagreement between inline and metadata
                    (unless (equal? inline-kind meta-kind)
                      (error 'spec
                        "implicit binder `~a` declared as `~a` inline but `~a` in :implicits"
                        name inline-kind meta-kind))
                    (eprintf "warning: duplicate implicit binder ~a in metadata (using inline version)~n"
                             name)
                    #f)
                  #t))
            meta-binders))
  (append inline-binders unique-meta))

;; ========================================
;; desugar-rest-type: detect $rest in spec tokens and desugar to List
;; ========================================
;; Scans type tokens for the `$rest` sentinel (from `...` in the spec).
;; When found, the token BEFORE $rest is the variadic element type.
;; Replaces `<elem-type> $rest` with `(List <elem-type>)` in the tokens.
;; Returns (values desugared-tokens rest-element-type-or-#f).
;;
;; Sexp reader parity: also recognizes bare `...` (Racket symbol) as alias for $rest.
;;
;; Examples:
;;   (Nat $rest -> Nat) → (values ((List Nat) -> Nat) Nat)
;;   (Nat ... -> Nat)   → (values ((List Nat) -> Nat) Nat)  [sexp mode]
;;   (Nat Nat $rest -> Nat) → (values (Nat (List Nat) -> Nat) Nat)
;;   ({A} A $rest -> Nat) → (values ((List A) -> Nat) A)
;;   (Nat -> Nat) → (values (Nat -> Nat) #f)
(define (desugar-rest-type tokens name)
  (define (rest-sentinel? x) (or (eq? x '$rest) (eq? x '...)))
  (define rest-idx
    (let loop ([i 0] [remaining tokens])
      (cond
        [(null? remaining) #f]
        [(rest-sentinel? (car remaining)) i]
        [else (loop (add1 i) (cdr remaining))])))
  (cond
    [(not rest-idx) (values tokens #f)]
    [(= rest-idx 0)
     (error 'spec "spec ~a: `...` must follow an element type (e.g., `Nat ...`)" name)]
    [else
     (define before-rest (take tokens (sub1 rest-idx)))
     (define elem-type (list-ref tokens (sub1 rest-idx)))
     (define after-rest (drop tokens (add1 rest-idx)))
     ;; Build (List <elem-type>) as the replacement
     (define list-type
       (if (and (list? elem-type) (pair? elem-type))
           ;; Grouped type like [A] or (Pair A B) → (List A) or (List (Pair A B))
           `(List ,@elem-type)
           ;; Bare symbol like Nat or A → (List Nat) or (List A)
           `(List ,elem-type)))
     (values (append before-rest (list list-type) after-rest) elem-type)]))

;; ========================================
;; process-spec: register a type specification
;; ========================================
;; Syntax variants:
;;   (spec name type-atoms...)                     — single arity
;;   (spec name "docstring" type-atoms...)          — with docstring
;;   (spec name ($pipe type-atoms...) ($pipe ...))  — multi-arity
;;   (spec name "docstring" ($pipe ...) ($pipe ...)) — multi with docstring
;;   (spec name type-atoms... where (Constraint1) (Constraint2))  — with where clause
(define (process-spec datum)
  (unless (and (list? datum) (>= (length datum) 3))
    (error 'spec "spec requires: (spec name type-signature)"))
  (define name (cadr datum))
  (unless (symbol? name)
    (error 'spec "spec: name must be a symbol, got ~a" name))
  (define rest (cddr datum))
  ;; Check for optional docstring (first element after name is a string)
  (define-values (docstring body-tokens)
    (if (and (not (null? rest)) (string? (car rest)))
        (values (car rest) (cdr rest))
        (values #f rest)))
  (when (null? body-tokens)
    (error 'spec "spec ~a: missing type signature" name))
  ;; Extract trailing metadata block: check if last token is ($brace-params :key ...)
  (define-values (pre-meta-tokens-0 metadata-0)
    (let* ([last-tok (last body-tokens)]
           [is-meta? (and (pair? last-tok)
                          (let ([h (car last-tok)])
                            (cond
                              [(symbol? h) (eq? h '$brace-params)]
                              [(syntax? h) (eq? (syntax-e h) '$brace-params)]
                              [else #f]))
                          (pair? (cdr last-tok))
                          (keyword-like-symbol? (cadr last-tok)))])
      (if is-meta?
          (values (drop-right body-tokens 1) (parse-spec-metadata last-tok))
          (values body-tokens #f))))
  ;; Also handle inline keyword-headed children from WS mode
  ;; e.g. (:doc "...") as a direct child of the spec form
  (define-values (pre-meta-tokens metadata)
    (let loop ([remaining pre-meta-tokens-0]
               [kept '()]
               [meta (or metadata-0 (hasheq))])
      (cond
        [(null? remaining)
         (values (reverse kept)
                 (if (hash-empty? meta) (and metadata-0 meta) meta))]
        [(and (pair? (car remaining)) (keyword-like-symbol? (caar remaining)))
         (define entry (car remaining))
         (define key (car entry))
         (define val (cdr entry))
         (define merged-val
           (cond
             [(and (= (length val) 1) (string? (car val))) (car val)]
             [(= (length val) 1) (car val)]
             [else val]))
         (loop (cdr remaining) kept (hash-set meta key merged-val))]
        [else
         (loop (cdr remaining) (cons (car remaining) kept) meta)])))
  ;; Merge :doc from metadata with positional docstring (metadata wins)
  (define merged-docstring
    (or (and metadata (hash-ref metadata ':doc #f)) docstring))
  ;; Extract leading {A B : Type} implicit binders (zero or more $brace-params groups)
  (define-values (implicit-binders after-implicits)
    (extract-implicit-binders pre-meta-tokens name))
  ;; Extract :implicits from metadata and merge with inline binders
  (define meta-implicits-raw (and metadata (hash-ref metadata ':implicits #f)))
  (define meta-implicits
    (if meta-implicits-raw
        (extract-implicits-from-metadata meta-implicits-raw name)
        '()))
  (define merged-implicit-binders
    (if (null? meta-implicits)
        implicit-binders
        (deduplicate-binders implicit-binders meta-implicits)))
  ;; Extract where clause (if present) — both positional and from metadata
  (define-values (type-tokens raw-where-constraints) (extract-where-clause after-implicits))
  (define meta-where (and metadata (hash-ref metadata ':where #f)))
  (define combined-raw-where
    (if meta-where
        (append raw-where-constraints meta-where)
        raw-where-constraints))
  ;; Expand bundle references in where constraints (e.g., (Comparable A) → (Eq A) (Ord A))
  (define where-constraints
    (if (null? combined-raw-where)
        '()
        (expand-bundle-constraints combined-raw-where)))
  ;; HKT-2: Propagate kinds from where-constraints AND inline constraints to implicit binders.
  ;; If {C} appears with [Seqable C] in where or as a leading inline param, and Seqable
  ;; expects {C : Type -> Type}, then C's kind is refined from (Type 0) to (-> (Type 0) (Type 0)).
  ;;
  ;; Two sources of constraints:
  ;; 1. Explicit where-clause: spec foo {C} ... where (Seqable C)
  ;; 2. Inline leading params: spec foo {C} (Seqable C) -> (C A) -> ...
  ;;    These are parenthesized forms before the first -> whose head is a known trait.
  (define inline-constraints
    (extract-inline-constraints type-tokens))
  (define all-constraints (append where-constraints inline-constraints))
  ;; Phase 1b: Auto-introduce free type variables from type signature and constraints.
  ;; Collect capitalized symbols that aren't already in implicit binders or known type names.
  ;; These become {X : Type} binders, which propagate-kinds-from-constraints may refine.
  (define auto-detected-binders
    (let* ([constraint-arg-datums (apply append (map cdr all-constraints))]
           [all-datums (append type-tokens constraint-arg-datums)]
           [candidates (collect-free-type-vars-from-datums all-datums)]
           [existing-names (map car merged-implicit-binders)]
           ;; Exclude names locally bound in higher-rank Pi binders (e.g. S in <(S :0 Type) -> ...>)
           [local-pi-names (collect-local-pi-binder-names type-tokens)]
           [new-vars (filter (lambda (v)
                               (and (not (memq v existing-names))
                                    (not (memq v local-pi-names))
                                    (not (known-type-name? v))))
                             candidates)])
      (map (lambda (v) (cons v '(Type 0))) new-vars)))
  ;; Phase 3a: :over P → add {P : Type → Type} to implicit binders
  (define over-var (and metadata (hash? metadata) (hash-ref metadata ':over #f)))
  (define over-binder
    (if over-var
        (list (cons over-var '(-> (Type 0) (Type 0))))
        '()))
  ;; Phase 3a: filter auto-detected-binders to exclude :over variable (already added with HKT kind)
  (define filtered-auto-detected-binders
    (if over-var
        (filter (lambda (b) (not (eq? (car b) over-var))) auto-detected-binders)
        auto-detected-binders))
  (define all-implicit-binders
    (append over-binder merged-implicit-binders filtered-auto-detected-binders))
  (define refined-implicit-binders
    (if (or (null? all-implicit-binders) (null? all-constraints))
        all-implicit-binders
        (propagate-kinds-from-constraints all-implicit-binders all-constraints name)))
  ;; Detect and desugar variadic rest type: `A $rest` → `(List A)`
  ;; The $rest sentinel marks the preceding type as variadic.
  (define-values (desugared-type-tokens rest-type)
    (desugar-rest-type type-tokens name))
  ;; Prepend where-constraints as leading parameter types
  ;; (Eq A) becomes a leading param type [Eq A], just like existing explicit dict style
  ;; Note: inline-constraints are ALREADY in desugared-type-tokens, only explicit
  ;; where-constraints need prepending.
  (define effective-tokens
    (if (null? where-constraints)
        desugared-type-tokens
        (append where-constraints (list '->) desugared-type-tokens)))
  ;; Phase 3a: :method entries → prepend evidence types to effective-tokens
  ;; Each :method entry adds a leading param type (the method's type signature).
  ;; These are prepended AFTER where-constraints but before user params.
  (define method-entries
    (if (and metadata (hash? metadata))
        (hash-ref metadata ':method '())
        '()))
  (define effective-tokens-with-methods
    (if (null? method-entries)
        effective-tokens
        ;; Build evidence type tokens: (type1) -> (type2) -> ... existing-tokens
        ;; Each method type is wrapped in parens so it's a single compound token
        ;; that survives arrow-splitting (method types often contain arrows themselves).
        (let ([evidence-prefix
               (apply append
                 (for/list ([me (in-list method-entries)])
                   (define method-type-tokens (caddr me))  ;; type tokens from :method
                   (list method-type-tokens '->)))])
          (append evidence-prefix effective-tokens))))
  ;; Store all-constraints (explicit where + inline) in spec entry so that
  ;; inject-spec-into-defn knows about inline constraints for dict param generation.
  ;; Phase 3a: also include HasMethod marker entries for constraint counting
  (define method-constraint-markers
    (for/list ([me (in-list method-entries)])
      (list 'HasMethod (car me) (cadr me))))  ;; (HasMethod P eq?)
  (define stored-constraints (append all-constraints method-constraint-markers))
  ;; G1: :invariant and :pre/:post have different proof obligation semantics — error if combined
  (when (and metadata (hash? metadata)
             (hash-ref metadata ':invariant #f)
             (or (hash-ref metadata ':pre #f)
                 (hash-ref metadata ':post #f)))
    (error 'spec
      (string-append
       "spec ~a: `:invariant` and `:pre`/`:post` have different proof obligation semantics "
       "and cannot be combined. Use `:pre` + `:post` for split obligations, "
       "or `:invariant` for a single relational assertion.")
      name))
  ;; G3: Warn if property :where constraints aren't covered by spec :where
  (let ([spec-properties (and metadata (hash? metadata) (hash-ref metadata ':properties #f))])
    (when (and spec-properties (pair? spec-properties))
      (for ([prop-ref (in-list spec-properties)])
        (define prop-name (if (pair? prop-ref) (car prop-ref) prop-ref))
        (define pe (lookup-property prop-name))
        (when pe
          (define prop-wheres (property-entry-where-clauses pe))
          (define spec-trait-names (map car stored-constraints))
          (for ([pw (in-list prop-wheres)])
            (unless (memq (car pw) spec-trait-names)
              (eprintf "warning: property `~a` requires `~a` but spec `~a` only provides ~a~n"
                       prop-name pw name stored-constraints)))))))
  ;; Check for multi-arity: effective-tokens contain $pipe forms
  (define final-effective-tokens effective-tokens-with-methods)
  (define has-pipes?
    (ormap (lambda (t) (or (eq? t '$pipe)
                           (and (pair? t) (eq? (car t) '$pipe))))
           final-effective-tokens))
  (cond
    [has-pipes?
     ;; Split on $pipe to get branches
     (define branches (split-on-pipe final-effective-tokens))
     (register-spec! name (spec-entry branches merged-docstring #t srcloc-unknown stored-constraints refined-implicit-binders rest-type metadata))]
    [else
     ;; Single-arity: the entire effective-tokens is the type datum
     (register-spec! name (spec-entry (list final-effective-tokens) merged-docstring #f srcloc-unknown stored-constraints refined-implicit-binders rest-type metadata))])
  ;; Phase 2: If spec has :mixfix metadata, auto-register as user operator
  (when (and metadata (hash? metadata) (hash-ref metadata ':mixfix #f))
    (maybe-register-mixfix-operator name metadata)))

;; Split a token list on '$pipe boundaries.
;; Handles two forms:
;;   Flat: ($pipe A B -> C $pipe D E -> F) → ((A B -> C) (D E -> F))
;;   Grouped: (($pipe A B -> C) ($pipe D E -> F)) → ((A B -> C) (D E -> F))
;; Leading $pipe is consumed.
(define (split-on-pipe tokens)
  (cond
    ;; Grouped form: each element is ($pipe content...)
    [(and (pair? tokens)
          (pair? (car tokens))
          (eq? (car (car tokens)) '$pipe))
     (map cdr tokens)]
    ;; Flat form: $pipe separates items
    [else
     (define stripped
       (if (and (pair? tokens) (eq? (car tokens) '$pipe))
           (cdr tokens)
           tokens))
     (let loop ([remaining stripped] [current '()] [result '()])
       (cond
         [(null? remaining)
          (reverse (if (null? current) result (cons (reverse current) result)))]
         [(eq? (car remaining) '$pipe)
          (loop (cdr remaining) '() (cons (reverse current) result))]
         [else
          (loop (cdr remaining) (cons (car remaining) current) result)]))]))

;; Restructure a defn datum with flat $pipe tokens into grouped form.
;; (defn name $pipe a -> b $pipe c -> d) → (defn name ($pipe a -> b) ($pipe c -> d))
;; Also handles: (defn name [params] $pipe a -> b $pipe c -> d)
;;            → (defn name [params] ($pipe a -> b) ($pipe c -> d))
;; If no flat $pipe tokens found, returns datum unchanged.
(define (group-defn-pipes datum)
  (cond
    [(and (pair? datum) (memq (car datum) '(defn defn-)))
     (define head (car datum))
     (define name (cadr datum))
     (define rest (cddr datum))
     ;; Check if rest has flat $pipe symbols (not already grouped)
     (define has-flat-pipes?
       (ormap (lambda (x) (eq? x '$pipe)) rest))
     (cond
       [has-flat-pipes?
        ;; Collect non-pipe prefix (e.g., [params], docstring)
        ;; and group pipe segments
        (define-values (prefix pipe-tokens)
          (let loop ([remaining rest] [pre '()])
            (cond
              [(null? remaining) (values (reverse pre) '())]
              [(eq? (car remaining) '$pipe)
               (values (reverse pre) remaining)]
              [else (loop (cdr remaining) (cons (car remaining) pre))])))
        ;; Group pipe-tokens into ($pipe ...) sub-lists
        (define branches (split-on-pipe pipe-tokens))
        (define grouped-branches
          (for/list ([branch (in-list branches)])
            (cons '$pipe branch)))
        `(,head ,name ,@prefix ,@grouped-branches)]
       [else datum])]
    [else datum]))

;; ========================================
;; Spec injection into defn
;; ========================================
;; When a defn has bare params (no type annotations) and a matching spec
;; exists, inject the spec type into the defn datum so the existing parser
;; handles it as a typed defn.

;; Check if a symbol represents a sexp-mode rest parameter: ...name (e.g., ...xs)
;; Returns the name part (e.g., xs) or #f.
(define (sexp-rest-param-sym? x)
  (and (symbol? x)
       (let ([s (symbol->string x)])
         (and (> (string-length s) 3)
              (string-prefix? s "...")
              (string->symbol (substring s 3))))))

;; Check if a parameter list contains only bare symbols (no type annotations).
;; Also accepts ($rest-param name) and ...name for varargs rest parameters.
(define (spec-bare-param-list? lst)
  (and (list? lst)
       (andmap (lambda (x)
                 (or (and (symbol? x)
                          (not (memq x '(: :0 :1 :w)))
                          ;; Bare ... is not a param name
                          (not (eq? x '...)))
                     ;; ($rest-param name) — varargs rest parameter (WS reader)
                     (and (list? x) (= (length x) 2) (eq? (car x) '$rest-param))
                     ;; ...name — varargs rest parameter (sexp reader)
                     (sexp-rest-param-sym? x)))
               lst)
       (not (ormap (lambda (x) (and (pair? x) (eq? (car x) '$angle-type))) lst))))

;; Check if defn rest (after name) has any type annotation indicators.
;; rest = (param-bracket possibly-more...) or
;;         (($brace-params ...) param-bracket possibly-more...)
;; Must skip leading $brace-params groups to find the real param bracket.
(define (defn-has-type-annotation? rest)
  ;; Skip leading $brace-params groups
  (define effective-rest
    (let loop ([r rest])
      (cond
        [(null? r) r]
        [(and (pair? (car r)) (eq? (caar r) '$brace-params))
         (loop (cdr r))]
        [else r])))
  (and (pair? effective-rest)
       (let ([params (car effective-rest)])
         (or
          ;; Params contain type markers
          (and (list? params)
               (ormap (lambda (x)
                        (or (and (pair? x) (eq? (car x) '$angle-type))
                            (eq? x ':)
                            (memq x '(:0 :1 :w))))
                      params))
          ;; Has angle-type or colon after params (return type)
          (and (pair? (cdr effective-rest))
               (let ([after (cadr effective-rest)])
                 (or (and (pair? after) (eq? (car after) '$angle-type))
                     (eq? after ':))))))))

;; Check if rest contains $pipe clauses (multi-body defn at datum level)
(define (defn-has-pipes? rest)
  (ormap (lambda (x)
           (and (pair? x) (eq? (car x) '$pipe)))
         rest))

;; Check if a $pipe clause is a pattern clause (has -> in clause body)
;; Pattern clause datums:
;;   ($pipe (params...) -> body ...)   — bracketed params
;;   ($pipe pattern -> body ...)       — bare pattern (e.g., zero -> true)
;;   ($pipe pattern1 pattern2 -> body ...)  — multi-arg patterns
(define (pipe-clause-datum-is-pattern? clause)
  (and (pair? clause) (eq? (car clause) '$pipe)
       (let ([rest (cdr clause)])
         (and (>= (length rest) 3)
              (memq '-> rest)          ;; contains -> somewhere
              #t))))

;; Check if ALL pipe clauses in rest are pattern clauses
(define (defn-has-all-pattern-clauses? rest)
  (define pipe-clauses
    (filter (lambda (x) (and (pair? x) (eq? (car x) '$pipe))) rest))
  (and (not (null? pipe-clauses))
       (for/and ([clause (in-list pipe-clauses)])
         (pipe-clause-datum-is-pattern? clause))))

;; Check if ANY pipe clause in rest is a pattern clause.
;; Also detects defn f [params] | arms syntax where the first element
;; is a bracket form (param list) and subsequent elements are $pipe arms.
(define (defn-has-any-pattern-clauses? rest)
  (define pipe-clauses
    (filter (lambda (x) (and (pair? x) (eq? (car x) '$pipe))) rest))
  (or
   ;; Existing: any pipe clause has [patterns] -> body format
   (for/or ([clause (in-list pipe-clauses)])
     (pipe-clause-datum-is-pattern? clause))
   ;; New: first element is a bracket form (not $pipe), rest are $pipe arms
   ;; This is the defn f [params] | pat... -> body syntax
   (and (not (null? rest))
        (pair? (car rest))
        (not (eq? (let ([h (car (car rest))]) h) '$pipe))
        (not (null? (cdr rest)))
        (andmap (lambda (x) (and (pair? x) (eq? (car x) '$pipe)))
                (cdr rest)))))

;; Decompose spec type tokens into parameter types and return type.
;; Uses the Prologos uncurried arrow convention:
;;   A B -> C  means  A -> B -> C  (each atom in non-last segment = separate param type)
;;   [A -> B] C -> D  means  (A->B) -> C -> D  (sub-lists are grouped param types)
;;   (n : Nat) A -> Vec n A  means  Pi(n:Nat) -> A -> Vec n A  (sub-list binder)
;;
;; Returns (values param-types return-type-tokens)
;; param-types: a list of param type atoms/lists (one per expected param)
;; return-type-tokens: the tokens for the return type
(define (decompose-spec-type tokens n-params name)
  (define segments (split-on-arrow-datum tokens))
  (cond
    ;; No arrows: relation type (or zero-param function)
    [(= (length segments) 1)
     (if (= n-params 0)
         (values '() tokens)
         (error 'spec "spec type for ~a has no arrow but defn has ~a params"
                name n-params))]
    [else
     ;; Has arrows: non-last segments = param types, last = return type
     (define non-last (drop-right segments 1))
     (define last-seg (last segments))
     ;; Flatten non-last segments: each element is a param type
     ;; Elements that are sub-lists (from [...]) stay as single param types
     (define flat-params (append-map (lambda (x) x) non-last))
     (cond
       [(= (length flat-params) n-params)
        (values flat-params last-seg)]
       [(> (length flat-params) n-params)
        ;; More type params than defn params — extra become part of return type
        ;; This happens for curried returns: spec f Nat -> Nat -> Nat, defn f [x] ...
        (define actual (take flat-params n-params))
        (define extra (drop flat-params n-params))
        (values actual (append extra (list '->) last-seg))]
       [else
        (error 'spec "spec ~a: type has ~a type parameters but defn has ~a params"
               name (length flat-params) n-params)])]))

;; Like decompose-spec-type but recognizes multiplicity arrows (-0>, -1>, -w>)
;; and returns a parallel multiplicities list alongside param types.
;; Returns (values param-types param-mults return-type-tokens)
;;   param-mults: list parallel to param-types, each #f, 'm0, 'm1, or 'mw
(define (decompose-spec-type/mult tokens n-params name)
  (define-values (segments arrow-mults) (split-on-arrow-datum/mult tokens))
  (cond
    ;; No arrows: relation type (or zero-param function)
    [(= (length segments) 1)
     (if (= n-params 0)
         (values '() '() tokens)
         (error 'spec "spec type for ~a has no arrow but defn has ~a params"
                name n-params))]
    [else
     (define non-last (drop-right segments 1))
     (define last-seg (last segments))
     ;; Flatten non-last segments: each element is a param type
     (define flat-params (append-map (lambda (x) x) non-last))
     ;; Build parallel multiplicity list: each param in a segment gets
     ;; the multiplicity of the arrow that follows that segment.
     ;; arrow-mults[i] = mult of arrow between segments[i] and segments[i+1]
     (define flat-mults
       (apply append
              (for/list ([seg (in-list non-last)]
                         [mult (in-list arrow-mults)])
                (make-list (length seg) mult))))
     (cond
       [(= (length flat-params) n-params)
        (values flat-params flat-mults last-seg)]
       [(> (length flat-params) n-params)
        ;; More type params than defn params — extra become part of return type
        (define actual (take flat-params n-params))
        (define actual-mults (take flat-mults n-params))
        (define extra (drop flat-params n-params))
        ;; Reconstruct arrows for extra params → return type
        (define extra-mults (drop flat-mults n-params))
        (define return-with-extras
          (let loop ([ps extra] [ms extra-mults])
            (cond
              [(null? ps) last-seg]
              [else
               (define arrow (case (car ms) [(m0) '-0>] [(m1) '-1>] [(mw) '-w>] [else '->]))
               (append (list (car ps) arrow) (loop (cdr ps) (cdr ms)))])))
        (values actual actual-mults return-with-extras)]
       [else
        (error 'spec "spec ~a: type has ~a type parameters but defn has ~a params"
               name (length flat-params) n-params)])]))

;; Convert a spec param-type element to an $angle-type annotation.
;; - plain atom Nat → ($angle-type Nat)
;; - grouped list [List A] → ($angle-type List A)
;; - dependent binder (n : Nat) → just Nat (the type part, binder name ignored)
;; - already $angle-type → pass through (higher-rank Pi parameter)
(define (param-type->angle-type ptype)
  (cond
    ;; Already an $angle-type form (e.g. from <(S :0 Type) -> ...> in spec) — pass through
    [(and (list? ptype) (pair? ptype) (eq? (car ptype) '$angle-type))
     ptype]
    ;; Dependent binder: (name : type-atoms...)
    [(and (list? ptype) (>= (length ptype) 3) (eq? (cadr ptype) ':))
     `($angle-type ,@(cddr ptype))]
    ;; Grouped type containing infix -> : flatten so parse-infix-type handles arrow
    ;; e.g. (B -> C) → ($angle-type B -> C), (A -> B -> C) → ($angle-type A -> B -> C)
    ;; But NOT prefix -> like (-> Nat Nat) which would break parse-infix-type
    [(and (list? ptype) (pair? ptype) (not (eq? (car ptype) '->))
          (memq '-> ptype))
     `($angle-type ,@ptype)]
    ;; Grouped type containing infix * : flatten so parse-infix-type handles product
    ;; e.g. (A * B) → ($angle-type A * B) → parsed as Sigma(_, A, B)
    ;; Without this, (A * B) as a single sub-list inside $angle-type gets
    ;; delegated to parse-datum which treats * as a variable name.
    [(and (list? ptype) (pair? ptype) (memq '* ptype))
     `($angle-type ,@ptype)]
    ;; All other grouped types: wrap as single element for parse-datum
    ;; Handles: (-> Nat Nat), (List A), (Sigma (_ ...) B), (Option A), etc.
    [(list? ptype)
     `($angle-type ,ptype)]
    ;; Plain atom
    [else
     `($angle-type ,ptype)]))

;; Inject a spec type into a single-arity defn datum.
;; datum: (defn name [x y] body)  OR  (defn name [x y] body1 body2 ...)
;; spec-tokens: (Nat Nat -> Nat)
;; Returns: (defn name [x ($angle-type Nat) y ($angle-type Nat)] ($angle-type Nat) body)
;; When implicit-binders is non-empty, prepends ($brace-params ...) so the parser
;; handles implicit type parameters: (defn name ($brace-params A B) [typed-bracket] ret body)
(define (inject-spec-into-defn datum spec-tokens [where-constraints '()] [implicit-binders '()])
  (define name (cadr datum))
  (define rest (cddr datum))  ;; ([x y] body ...)
  (define param-bracket (car rest))
  ;; Strip any existing `where` clause from body-forms — inject-spec-into-defn
  ;; re-adds constraints from the spec, so a user-supplied `where` in the defn
  ;; would cause duplication if not removed here.
  (define raw-body-forms (cdr rest))
  (define body-forms
    (let ([widx (index-where raw-body-forms (lambda (t) (eq? t 'where)))])
      (if (not widx)
          raw-body-forms
          ;; Skip 'where + any parenthesized constraint forms that follow it
          (let ([before (take raw-body-forms widx)]
                [after (drop raw-body-forms (add1 widx))])
            ;; Skip leading parenthesized forms that are trait constraints
            (define remaining
              (let loop ([items after])
                (cond
                  [(null? items) '()]
                  [(and (list? (car items))
                        (not (null? (car items)))
                        (symbol? (caar items))
                        (or (lookup-trait (caar items))
                            (lookup-bundle (caar items))))
                   (loop (cdr items))]
                  [else items])))
            (append before remaining)))))
  ;; Extract param names, stripping $rest-param wrappers and ...name symbols:
  ;; (x y ($rest-param xs)) → (x y xs)  [WS reader]
  ;; (x y ...xs)            → (x y xs)  [sexp reader]
  (define param-names
    (if (list? param-bracket)
        (map (lambda (x)
               (cond
                 [(and (list? x) (= (length x) 2) (eq? (car x) '$rest-param))
                  (cadr x)]
                 [(sexp-rest-param-sym? x) => values]
                 [else x]))
             param-bracket)
        (error 'spec "Expected parameter list, got ~a" param-bracket)))
  ;; When spec has where-constraints, check if the user provides:
  ;; a) ALL params (including constraint dicts) → use full spec-tokens, no where rewrite
  ;; b) Only regular params (without dicts) → strip constraints, re-add `where`
  (define n-constraints (length where-constraints))
  ;; Count total param types in full spec (use mult-aware splitting to handle -1> etc.)
  (define-values (full-segments full-arrow-mults) (split-on-arrow-datum/mult spec-tokens))
  (define full-non-last (if (> (length full-segments) 1) (drop-right full-segments 1) '()))
  (define full-flat-params (append-map (lambda (x) x) full-non-last))
  (define n-full-params (length full-flat-params))
  (define n-regular-params (- n-full-params n-constraints))
  ;; Detect: does the user's param count match the full spec or the regular-only count?
  (define user-provides-dicts?
    (and (> n-constraints 0)
         (= (length param-names) n-full-params)))
  (define effective-spec-tokens
    (cond
      [(= n-constraints 0) spec-tokens]  ;; no constraints
      [user-provides-dicts? spec-tokens]  ;; user provides all params including dicts
      [else
       ;; Strip leading constraint types from spec-tokens.
       ;; Constraints may be prepended via `where` clause (with -> arrow separator)
       ;; or inline (without -> separator between constraint and value params).
       ;; Walk the list, removing n-constraints constraint forms + interleaved arrows.
       (let loop ([remaining spec-tokens] [n n-constraints])
         (cond
           [(= n 0)
            ;; Skip any leading -> arrow after last constraint
            (if (and (pair? remaining) (memq (car remaining) '(-> -0> -1> -w>)))
                (cdr remaining)
                remaining)]
           [(null? remaining)
            (error 'spec "spec ~a: could not strip ~a constraint(s) from type" name n-constraints)]
           ;; Skip arrow tokens between constraints
           [(memq (car remaining) '(-> -0> -1> -w>))
            (loop (cdr remaining) n)]
           ;; Skip constraint form
           [else
            (loop (cdr remaining) (- n 1))]))]))
  ;; Decompose the effective spec type into param types + return type + multiplicities
  (define-values (param-types param-mults return-type-tokens)
    (decompose-spec-type/mult effective-spec-tokens (length param-names) name))
  ;; Build typed bracket for user params: [x ($angle-type T1) y :1 ($angle-type T2)]
  ;; When a param has non-default multiplicity (m0 or m1), emit the annotation.
  (define typed-bracket
    (apply append
           (for/list ([pname (in-list param-names)]
                      [ptype (in-list param-types)]
                      [pmult (in-list param-mults)])
             (define annot (mult->annot-symbol pmult))
             (if annot
                 (list pname annot (param-type->angle-type ptype))
                 (list pname (param-type->angle-type ptype))))))
  ;; Build return type angle form.
  ;; When return-type-tokens is a single sub-list (e.g. from [A * B] in the spec),
  ;; use param-type->angle-type to properly flatten infix operators like * and ->.
  ;; Without this, ($angle-type (A * B)) gets parsed as a single element by parse-datum
  ;; which treats * as a variable rather than the Sigma product operator.
  (define ret-angle
    (if (and (= (length return-type-tokens) 1)
             (list? (car return-type-tokens)))
        (param-type->angle-type (car return-type-tokens))
        `($angle-type ,@return-type-tokens)))
  ;; Build implicit binder forms if needed
  ;; implicit-binders: alist of ((name . kind) ...) from spec's {A B : Type}
  ;; Group consecutive binders with the same kind into separate $brace-params forms.
  ;; This is critical because the parser's parse-brace-typed-binders only supports
  ;; ONE colon per $brace-params group — all names share the same type.
  ;; So {A} {C : Type -> Type} must become two separate groups, not one flat list.
  (define brace-forms
    (if (null? implicit-binders)
        '()
        ;; Group consecutive binders with the same kind
        (let loop ([remaining implicit-binders] [groups '()])
          (cond
            [(null? remaining) (reverse groups)]
            [else
             (define current-kind (cdr (car remaining)))
             ;; Collect consecutive binders with the same kind
             (define-values (same-kind rest)
               (splitf-at remaining (lambda (bnd) (equal? (cdr bnd) current-kind))))
             (define names (map car same-kind))
             (define form
               (if (equal? current-kind '(Type 0))
                   `($brace-params ,@names)
                   `($brace-params ,@names : ,current-kind)))
             (loop rest (cons form groups))]))))
  ;; Phase 3a: Split where-constraints into standard trait constraints and HasMethod entries.
  ;; Standard constraints go through maybe-inject-where; HasMethod evidence params are
  ;; generated directly here (since 'HasMethod is not a real trait in the registry).
  (define-values (standard-where-constraints hasmethod-where-entries)
    (partition (lambda (c) (not (and (pair? c) (eq? (car c) 'HasMethod))))
              where-constraints))
  ;; Generate HasMethod evidence params: [$hm-eq? ($angle-type method-type)]
  ;; These use the method evidence types from the full spec tokens.
  ;; The evidence types are at positions after standard where-constraints.
  (define hasmethod-params
    (for/list ([hm (in-list hasmethod-where-entries)])
      ;; hm = (HasMethod trait-var method-name)
      (define method-name (caddr hm))
      (define param-name (string->symbol (string-append "$hm-" (symbol->string method-name))))
      ;; Find the corresponding evidence type from the spec tokens.
      ;; It's the n-standard-where + offset param in the full spec.
      ;; For now, use a placeholder angle-type from the spec metadata.
      ;; The actual type comes from the spec-tokens decomposition.
      param-name))
  ;; Reconstruct typed-bracket with HasMethod evidence params prepended
  ;; Each evidence param gets its type from the full spec decomposition.
  ;; When the user didn't provide dict params, we need to decompose the full spec
  ;; to extract evidence types. The evidence types are the params between
  ;; standard where-constraints and user params in the full spec.
  (define extended-typed-bracket
    (if (or (null? hasmethod-where-entries) user-provides-dicts?)
        typed-bracket
        ;; Decompose the full spec to get evidence param types
        (let ()
          ;; Full spec has: std-constraints... -> evidence-types... -> user-types... -> ret
          (define n-std (length standard-where-constraints))
          (define n-hm (length hasmethod-where-entries))
          ;; Skip standard constraints + arrows, extract evidence types
          (define after-std (drop spec-tokens (if (> n-std 0) (add1 n-std) 0)))
          (define-values (ev-segments _ev-mults) (split-on-arrow-datum/mult after-std))
          ;; Unwrap single-element segments: ((A A -> Bool)) → (A A -> Bool)
          ;; Evidence types are compound tokens (paren-wrapped function types),
          ;; so each segment contains exactly one list element.
          (define evidence-types
            (map (lambda (seg)
                   (if (and (= (length seg) 1) (list? (car seg)))
                       (car seg)  ;; unwrap compound token
                       seg))
                 (take (drop-right ev-segments 1) n-hm)))
          ;; Build typed bracket with evidence params prepended
          (define hm-bracket-entries
            (apply append
              (for/list ([pname (in-list hasmethod-params)]
                         [ptype (in-list evidence-types)])
                (list pname (param-type->angle-type ptype)))))
          (append hm-bracket-entries typed-bracket))))
  ;; Assemble: (defn name [typed-bracket...] ($angle-type ret) body-forms...)
  ;; With implicits: (defn name ($brace-params ...) ... [typed-bracket...] ($angle-type ret) body-forms...)
  ;; If constraints were stripped, append `where` so maybe-inject-where adds them back.
  ;; Phase 3a: Only standard constraints go in the where clause; HasMethod params are already
  ;; in the typed bracket.
  (define base-defn
    (cond
      [(or (null? where-constraints) user-provides-dicts?)
       `(defn ,name ,extended-typed-bracket ,ret-angle ,@body-forms)]
      [(null? standard-where-constraints)
       ;; Only HasMethod constraints, no standard where clause needed
       `(defn ,name ,extended-typed-bracket ,ret-angle ,@body-forms)]
      [else
       `(defn ,name ,extended-typed-bracket ,ret-angle where ,@standard-where-constraints ,@body-forms)]))
  ;; Prepend brace-forms after name if present
  (if (null? brace-forms)
      base-defn
      (let ([after-name (cddr base-defn)])
        `(defn ,name ,@brace-forms ,@after-name))))

;; Inject spec types into a multi-arity defn datum.
;; Each $pipe clause gets its corresponding spec branch type.
(define (inject-spec-into-defn-multi datum name spec-branches)
  (define rest (cddr datum))  ;; everything after name
  ;; Extract pipe clauses and any docstring
  (define docstring
    (and (pair? rest) (string? (car rest)) (car rest)))
  (define clauses
    (filter (lambda (x) (and (pair? x) (eq? (car x) '$pipe)))
            rest))
  (unless (= (length clauses) (length spec-branches))
    (error 'spec "spec ~a has ~a branches but defn has ~a clauses"
           name (length spec-branches) (length clauses)))
  ;; Rewrite each clause
  (define rewritten-clauses
    (for/list ([clause (in-list clauses)]
               [branch-tokens (in-list spec-branches)])
      ;; clause = ($pipe [params...] body ...)
      (define clause-body (cdr clause))  ;; everything after $pipe
      ;; Build a temporary defn datum for injection
      (define temp-datum `(defn ,name ,@clause-body))
      (define injected (inject-spec-into-defn temp-datum branch-tokens))
      ;; Re-wrap as $pipe clause: ($pipe typed-bracket ret body...)
      `($pipe ,@(cddr injected))))
  ;; Reconstruct the defn with rewritten clauses
  (if docstring
      `(defn ,name ,docstring ,@rewritten-clauses)
      `(defn ,name ,@rewritten-clauses)))

;; Top-level dispatcher: check if a defn should have spec type injected.
;; Returns the original datum unchanged if no spec applies.
(define (maybe-inject-spec datum)
  (define name (and (list? datum) (>= (length datum) 3) (cadr datum)))
  (cond
    [(not (symbol? name)) datum]
    [else
     (define rest (cddr datum))
     (define spec (lookup-spec name))
     (cond
       [(not spec) datum]
       ;; Multi-body defn with pipes
       [(defn-has-pipes? rest)
        (cond
          ;; Pattern clauses (have -> after params bracket):
          ;; Skip spec injection — pattern clause compilation handles type inference.
          ;; The spec type is NOT injected per-clause; the compiled defn infers its type.
          [(defn-has-any-pattern-clauses? rest)
           datum]
          [(defn-has-type-annotation? rest)
           ;; Defn has inline types AND a spec. If propagated, override silently.
           (if (spec-propagated? name)
               datum
               (error 'spec "defn ~a has both a spec and inline type annotations" name))]
          [(not (spec-entry-multi? spec))
           (error 'spec "spec for ~a is single-arity but defn ~a has multiple clauses"
                  name name)]
          [else
           (inject-spec-into-defn-multi datum name (spec-entry-type-datums spec))])]
       ;; Single-body defn
       [(and (pair? rest) (list? (car rest)) (spec-bare-param-list? (car rest))
             (not (defn-has-type-annotation? rest)))
        ;; Bare params with no type → inject spec
        (cond
          [(spec-entry-multi? spec)
           (error 'spec "spec for ~a is multi-arity but defn ~a is single-body"
                  name name)]
          [else
           (inject-spec-into-defn datum (car (spec-entry-type-datums spec))
                                  (spec-entry-where-constraints spec)
                                  (spec-entry-implicit-binders spec))])]
       ;; Defn has inline types — if propagated spec, override silently;
       ;; if own-module spec, error (user mistake).
       [(defn-has-type-annotation? rest)
        (if (spec-propagated? name)
            datum
            (error 'spec "defn ~a has both a spec and inline type annotations" name))]
       ;; No injection needed (e.g., no params bracket)
       [else datum])]))

;; Inject a spec type into a def datum.
;; datum: (def name body)
;; spec-tokens: (Nat) or (Nat -> Nat)
;; Returns: (def name ($angle-type spec-tokens...) body)
(define (inject-spec-into-def datum spec-tokens)
  (define name (cadr datum))
  (define rest (cddr datum))
  `(def ,name ($angle-type ,@spec-tokens) ,@rest))

;; Top-level dispatcher: check if a def should have spec type injected.
;; Returns the original datum unchanged if no spec applies.
(define (maybe-inject-spec-def datum)
  (define name (and (list? datum) (>= (length datum) 2) (cadr datum)))
  (cond
    [(not (symbol? name)) datum]
    [else
     (define spec (lookup-spec name))
     (cond
       [(not spec) datum]
       [(spec-entry-multi? spec)
        (error 'spec "spec for ~a is multi-arity but used with def" name)]
       ;; Check if def already has a type annotation (angle-type or colon).
       ;; If the spec was propagated from a required module, the inline
       ;; annotation silently takes precedence. If own-module, error.
       [(and (>= (length datum) 4)
             (let ([third (caddr datum)])
               (or (and (pair? third) (eq? (car third) '$angle-type))
                   (eq? third ':))))
        (if (spec-propagated? name)
            datum
            (error 'spec "def ~a has both a spec and inline type annotation" name))]
       [else
        (inject-spec-into-def datum (car (spec-entry-type-datums spec)))])]))

;; ========================================
;; maybe-inject-where: extract where-clause from defn and desugar
;; ========================================
;; Detects `where` keyword in a defn datum and rewrites by prepending
;; trait constraint parameters to the parameter list.
;;
;; Input:  (defn sum [xs ($angle-type List A)] ($angle-type A) where (Add A) body)
;; Output: (defn sum [$Add-A ($angle-type (Add A))] [xs ($angle-type List A)] ($angle-type A) body)
;;
;; The prepended parameters become m0 (implicit) Pi binders after auto-implicit
;; inference adds the type variable binders. This means the existing
;; implicit-holes-needed machinery will insert fresh metas for them at call sites.
(define (maybe-inject-where datum)
  (unless (and (list? datum) (>= (length datum) 3) (eq? (car datum) 'defn))
    (error 'where "maybe-inject-where called on non-defn: ~a" datum))
  (define name (cadr datum))
  (define rest (cddr datum))  ;; everything after name
  ;; Scan for 'where in the flat datum list
  (define where-idx (index-where rest (lambda (t) (eq? t 'where))))
  (cond
    [(not where-idx) datum]  ;; no where clause — return unchanged
    [else
     (define before-where (take rest where-idx))
     (define after-where (drop rest (add1 where-idx)))
     ;; Extract parenthesized constraint forms from after-where
     ;; Constraints are leading parenthesized lists; the rest is body
     (define-values (raw-constraints body-forms)
       (let loop ([remaining after-where] [cs '()])
         (cond
           [(null? remaining) (values (reverse cs) '())]
           [(and (list? (car remaining))
                 ;; A constraint is a list like (Eq A) or (Add A) or (Comparable A)
                 ;; NOT a $angle-type, NOT a defn, NOT a match arm
                 (not (null? (car remaining)))
                 (symbol? (caar remaining))
                 ;; Must be a known trait or bundle (validate)
                 (or (lookup-trait (caar remaining))
                     (lookup-bundle (caar remaining))))
            (loop (cdr remaining) (cons (car remaining) cs))]
           [else (values (reverse cs) remaining)])))
     (when (null? raw-constraints)
       (error 'where "defn ~a: where clause has no valid trait constraints" name))
     ;; Expand bundle references to flat trait constraints
     (define constraints (expand-bundle-constraints raw-constraints))
     ;; Generate synthetic dict parameter names and type annotations.
     ;; Dict params are runtime-relevant (carry actual functions), so they use mw (not m0).
     ;; The implicit insertion mechanism is extended to also count these params
     ;; via the spec's where-constraints, even though they are mw.
     (define dict-params
       (for/list ([c (in-list constraints)])
         (define param-name
           (string->symbol
            (string-append "$"
                           (string-join (map symbol->string c) "-"))))
         ;; No explicit mult annotation → defaults to mult-meta → solved to mw based on usage.
         ;; The implicit-holes-needed function is extended to count leading m0 binders
         ;; PLUS immediately-following where-constraint params (even if they're mw).
         (list param-name `($angle-type ,c))))
     ;; Reconstruct: (defn name dict-param1 dict-param2 ... before-where... body-forms...)
     ;; The dict params are interleaved as [name ($angle-type type)] pairs in the param list
     ;; We need to splice them before the existing params
     ;;
     ;; before-where might be: [xs ($angle-type List A)] ($angle-type A)
     ;; or: [xs <List A>] <A>
     ;; The existing param list is the first bracket in before-where
     ;; We prepend our dict params to that bracket
     (define (find-param-bracket items)
       ;; Find the first element that is a list with square-bracket paren-shape,
       ;; or just the first list that looks like a parameter list
       (let loop ([items items] [idx 0])
         (cond
           [(null? items) #f]
           [(and (list? (car items))
                 (not (null? (car items)))
                 ;; A param bracket contains symbol names (possibly with type annotations)
                 (symbol? (caar items))
                 ;; Skip $brace-params and $angle-type — not parameter brackets
                 (not (eq? (caar items) '$brace-params))
                 (not (eq? (caar items) '$angle-type)))
            idx]
           [else (loop (cdr items) (add1 idx))])))
     (define bracket-idx (find-param-bracket before-where))
     (cond
       [bracket-idx
        ;; Splice dict params into the parameter bracket
        (define old-bracket (list-ref before-where bracket-idx))
        (define dict-param-items
          (apply append dict-params))  ;; flatten: ($Add-A ($angle-type (Add A)) $Ord-B ...)
        (define new-bracket (append dict-param-items old-bracket))
        (define new-before (list-set before-where bracket-idx new-bracket))
        `(defn ,name ,@new-before ,@body-forms)]
       [else
        ;; No existing param bracket found — create one with just the dict params
        (define dict-param-items (apply append dict-params))
        `(defn ,name ,dict-param-items ,@before-where ,@body-forms)])]))

;; Expand def := assignment syntax into standard def form.
;; (def name := value) → (def name value)
;; (def name : T1 T2 ... := value) → (def name ($angle-type T1 T2 ...) value)
(define (expand-def-assign datum)
  (define name (cadr datum))
  (define rest (cddr datum))  ; tokens after name
  (define assign-pos (index-of-symbol ':= rest))
  (cond
    [(not assign-pos) datum]
    [else
     (define before (take rest assign-pos))
     (define after (drop rest (+ assign-pos 1)))
     (when (null? after)
       (error 'def "def: expected at least one value after :="))
     ;; Auto-wrap multi-token RHS as application: `some 42N` → `(some 42N)`
     ;; In WS mode, juxtaposed tokens after := form an application.
     (define value (if (= (length after) 1) (car after) after))
     (cond
       ;; No type annotation: (def name := value) → (def name value)
       [(null? before)
        `(def ,name ,value)]
       ;; Type annotation with colon: (def name : T1 T2 ... := value)
       [(and (>= (length before) 2) (eq? (car before) ':))
        (define type-tokens (cdr before))
        `(def ,name ($angle-type ,@type-tokens) ,value)]
       [else
        (error 'def "def: unexpected tokens before :=: ~a" before)])]))

;; ========================================
;; Built-in pre-parse macros
;; ========================================

;; let: sequential local bindings
;; Formats (all expand to nested ((fn (name : type) ...) value) applications):
;;
;; 1. Inline :=  — (let name := value body)
;;                  (let name : T1 T2 := value body)
;; 2. Bracket := — (let [name := value  name2 : T := value2] body)
;; 3. Bracket <> — (let [name ($angle-type T) value ...] body) — flat triples
;; 4. Bracket () — (let ([name : T value] ...) body) — nested 4-element sub-lists
;; 5. Shorthand  — (let name value body) — no type, 4 elements
;;
(define (expand-let datum)
  (unless (and (list? datum) (>= (length datum) 3))
    (error 'let "let requires at least: (let name value body)"))
  (define rest (cdr datum))  ; everything after 'let

  ;; Detect top-level let without body: (let name := value) with no continuation.
  ;; In WS mode, top-level let has no body because there's no enclosing scope.
  ;; Emit a clear error directing users to use `def` instead.
  (when (and (memq ':= rest)
             (symbol? (car rest))
             ;; A single-binding let without body: (name := value) or (name : T := value)
             ;; has no remaining tokens after the first value.
             ;; Detect by checking: after removing the binding, nothing is left for a body.
             (let ()
               (define assign-pos (index-of rest ':=))
               (and assign-pos
                    ;; Everything after := is the value; if there's exactly 1 token after :=,
                    ;; then the "body" would be that same token (stolen by expand-let-inline-assign).
                    ;; Count total bindings: each binding consumes name [: type...] := value.
                    ;; Simple heuristic: exactly one := and value is the last token.
                    (let ([after-assign (drop rest (+ assign-pos 1))])
                      (= (length after-assign) 1)))))
    (define name (car rest))
    (error 'let
           "`let` is not allowed at top level. Use `def` instead.\n  let ~a := ...\n      ^^^\n  Use: def ~a := ..."
           name name))

  (cond
    ;; --- Branch 1: Bracket format — second element is a list ---
    [(list? (car rest))
     (unless (= (length rest) 2)
       (error 'let "let with bracket bindings requires: (let [bindings...] body)"))
     (define bindings-datum (car rest))
     (define body (cadr rest))
     (expand-let-bracket-bindings bindings-datum body)]

    ;; --- Branch 2: Inline := format — find := in rest ---
    [(memq ':= rest)
     (expand-let-inline-assign rest)]

    ;; --- Branch 3: Legacy shorthand — (let name value body) ---
    [(and (= (length rest) 3) (symbol? (car rest)))
     (define name (car rest))
     (define value (cadr rest))
     (define body (caddr rest))
     `((fn (,name : _) ,body) ,value)]

    ;; --- Branch 4: Legacy angle-type format — (let name ($angle-type T) value body) ---
    [(and (>= (length rest) 4)
          (symbol? (car rest))
          (let ([second (cadr rest)])
            (and (pair? second) (eq? (car second) '$angle-type))))
     ;; Re-wrap as bracket format for uniform handling
     (define body (last rest))
     (define bindings-tokens (drop-right rest 1))
     (expand-let-bracket-bindings bindings-tokens body)]

    [else
     (error 'let "let: unrecognized format: ~a" datum)]))

;; Expand bracket-style let bindings.
;; Handles three sub-formats within the bracket:
;;   := format: [name := value  name2 : T := value2 ...]
;;   angle-type format: [name ($angle-type T) value ...]
;;   nested format: ([name : T value] ...)
(define (expand-let-bracket-bindings bindings-datum body)
  (cond
    ;; Empty bindings — just return body
    [(null? bindings-datum) body]
    ;; := format: contains := symbol somewhere in the flat list
    [(memq ':= bindings-datum)
     (define parsed (parse-assign-bindings bindings-datum))
     (let-bindings->nested-fn parsed body)]
    ;; Angle-type format: first element is symbol, second is ($angle-type ...)
    [(and (symbol? (car bindings-datum))
          (>= (length bindings-datum) 3)
          (let ([second (cadr bindings-datum)])
            (and (pair? second) (eq? (car second) '$angle-type))))
     (define parsed (parse-let-flat-triples bindings-datum))
     (let-bindings->nested-fn parsed body)]
    ;; Flat-pair format: (x v1 y v2 ...) — alternating name/value pairs.
    ;; Values CAN be lists (applications like (suc zero)).
    ;; Distinguished from nested format because nested has ALL elements as
    ;; sub-lists, while flat-pair has symbols at even positions (names).
    ;; The := and $angle-type cases are already handled by earlier branches.
    [(and (>= (length bindings-datum) 2)
          (even? (length bindings-datum))
          (symbol? (car bindings-datum)))
     (define parsed
       (let loop ([rest bindings-datum] [acc '()])
         (cond
           [(null? rest) (reverse acc)]
           [else
            (define name (car rest))
            (define value (cadr rest))
            (loop (cddr rest) (cons (list name '_ value) acc))])))
     (let-bindings->nested-fn parsed body)]
    ;; Nested format: ([name : T value] ...) or ([name value] ...) with inferred type
    [else
     (define parsed
       (for/list ([binding (in-list bindings-datum)])
         (cond
           [(and (list? binding) (= (length binding) 4))
            ;; (name : type value)
            (list (car binding) (caddr binding) (cadddr binding))]
           [(and (list? binding) (= (length binding) 2) (symbol? (car binding)))
            ;; (name value) — type inferred via hole
            (list (car binding) '_ (cadr binding))]
           [else
            (error 'let "let: each binding must be (name value) or (name : type value), got ~a" binding)])))
     (let-bindings->nested-fn parsed body)]))

;; Expand inline := let: rest = (name [: type-atoms...] := value body)
;; The last element is the body. Everything before is: name [: T1 T2 ...] := value
(define (expand-let-inline-assign rest)
  (define body (last rest))
  (define tokens (drop-right rest 1))  ; name [: T1 T2 ...] := value
  (define parsed (parse-assign-bindings tokens))
  (let-bindings->nested-fn parsed body))

;; Convert parsed bindings ((name type value) ...) to nested fn application.
;; Type '_ means inferred (hole).
(define (let-bindings->nested-fn parsed-bindings body)
  (foldr (lambda (binding inner)
           (define name (car binding))
           (define type (cadr binding))
           (define value (caddr binding))
           `((fn (,name : ,type) ,inner) ,value))
         body
         parsed-bindings))

;; Parse := bindings from a flat token list.
;; Format: name [: T1 T2 ...] := value [name2 [: T3 ...] := value2 ...]
;; Returns list of (name type value) triples. Type = '_ when omitted.
(define (parse-assign-bindings tokens)
  (cond
    [(null? tokens) '()]
    [else
     (unless (symbol? (car tokens))
       (error 'let "let :=: expected variable name, got ~a" (car tokens)))
     (define name (car tokens))
     (define after-name (cdr tokens))
     ;; Check for optional type annotation: : T1 T2 ... :=
     (cond
       ;; name := value ... — no type annotation
       [(and (pair? after-name) (eq? (car after-name) ':=))
        (define after-assign (cdr after-name))
        (when (null? after-assign)
          (error 'let "let :=: missing value after := for ~a" name))
        ;; Value = everything until next binding start or end
        (define-values (value-tokens rest) (split-at-next-assign-binding after-assign))
        (define value (if (= (length value-tokens) 1)
                          (car value-tokens)
                          (maybe-restructure-infix-eq value-tokens)))
        (cons (list name '_ value) (parse-assign-bindings rest))]
       ;; name : T1 T2 ... := value ... — with type annotation
       [(and (pair? after-name) (eq? (car after-name) ':))
        (define after-colon (cdr after-name))
        ;; Collect type atoms until :=
        (define-values (type-atoms after-assign)
          (split-before-symbol ':= after-colon))
        (when (null? type-atoms)
          (error 'let "let :=: empty type annotation for ~a" name))
        (when (null? after-assign)
          (error 'let "let :=: missing := after type for ~a" name))
        ;; after-assign starts with :=, skip it
        (define past-assign (cdr after-assign))
        (when (null? past-assign)
          (error 'let "let :=: missing value after := for ~a" name))
        (define-values (value-tokens rest) (split-at-next-assign-binding past-assign))
        (define type (if (= (length type-atoms) 1)
                         (car type-atoms)
                         type-atoms))
        (define value (if (= (length value-tokens) 1)
                          (car value-tokens)
                          (maybe-restructure-infix-eq value-tokens)))
        (cons (list name type value) (parse-assign-bindings rest))]
       [else
        (error 'let "let :=: expected := or : after name ~a, got ~a" name after-name)])]))

;; Restructure infix = in a multi-token value list to prefix form.
;; (add ?x 3N = 5N) → (= (add ?x 3N) 5N)
;; This is needed because the WS reader's infix = rewriting is suppressed
;; after := (Phase 1b), so = in let values remains in infix position.
;; Only fires on multi-token lists; single-token values pass through.
(define (maybe-restructure-infix-eq tokens)
  (define eq-idx
    (let loop ([ts tokens] [i 0])
      (cond
        [(null? ts) #f]
        [(and (symbol? (car ts)) (eq? (car ts) '=) (> i 0)) i]
        [else (loop (cdr ts) (+ i 1))])))
  (if eq-idx
      (let* ([lhs-ts (take tokens eq-idx)]
             [rhs-ts (drop tokens (+ eq-idx 1))]
             [lhs (if (= (length lhs-ts) 1) (car lhs-ts) lhs-ts)]
             [rhs (if (= (length rhs-ts) 1) (car rhs-ts) rhs-ts)])
        (list '= lhs rhs))
      tokens))

;; Split a list at the first occurrence of a given symbol.
;; Returns (values before-symbol from-symbol-onwards).
;; If symbol not found, returns (values list '()).
(define (split-before-symbol sym lst)
  (let loop ([acc '()] [rest lst])
    (cond
      [(null? rest) (values (reverse acc) '())]
      [(eq? (car rest) sym) (values (reverse acc) rest)]
      [else (loop (cons (car rest) acc) (cdr rest))])))

;; Split at the start of the next := binding in a value token list.
;; A binding starts at position i if tokens[i] is a symbol and
;; tokens[i+1] is := or tokens[i+1] is : (followed eventually by :=).
;; Returns (values value-tokens remaining-tokens).
(define (split-at-next-assign-binding tokens)
  (let loop ([i 0] [rest tokens])
    (cond
      [(null? rest)
       (values tokens '())]
      [(and (> i 0)
            (symbol? (car rest))
            (not (eq? (car rest) ':))
            (not (eq? (car rest) ':=))
            (pair? (cdr rest))
            (or (eq? (cadr rest) ':=)
                (eq? (cadr rest) ':)))
       (values (take tokens i) rest)]
      [else
       (loop (+ i 1) (cdr rest))])))

;; Parse flat triples from let binding list: name ($angle-type T) expr ...
;; Value tokens: everything after the type until the next binding (symbol ($angle-type ...))
;; or end of list. Multi-token values are wrapped as an application list.
(define (parse-let-flat-triples elems)
  (cond
    [(null? elems) '()]
    [(< (length elems) 3)
     (error 'let "let: incomplete binding triple, got ~a" elems)]
    [else
     (let* ([name (car elems)]
            [angle-form (cadr elems)]
            [_ (unless (symbol? name)
                 (error 'let "let: expected variable name, got ~a" name))]
            [_ (unless (and (pair? angle-form) (eq? (car angle-form) '$angle-type))
                 (error 'let "let: expected <type>, got ~a" angle-form))]
            [type (if (= (length (cdr angle-form)) 1)
                      (cadr angle-form)
                      (cdr angle-form))]
            [after-type (cddr elems)])
       (define-values (value-tokens rest)
         (split-at-next-binding after-type))
       (let ([value (if (= (length value-tokens) 1)
                        (car value-tokens)
                        value-tokens)])
         (cons (list name type value)
               (parse-let-flat-triples rest))))]))

;; Split a list at the start of the next binding (symbol followed by ($angle-type ...)).
;; Returns (values consumed-tokens remaining-tokens).
(define (split-at-next-binding elems)
  (let loop ([i 0] [rest elems])
    (cond
      [(null? rest)
       (values elems '())]
      [(and (> i 0)
            (>= (length rest) 2)
            (symbol? (car rest))
            (let ([next (cadr rest)])
              (and (pair? next) (eq? (car next) '$angle-type))))
       (values (take elems i) rest)]
      [else
       (loop (+ i 1) (cdr rest))])))

;; do: sequenced bindings
;; NEW: (do [x ($angle-type T) e1] [y ($angle-type T2) e2] body) → 3-element bindings
;; OLD: (do [x : T = e1] [y : T2 = e2] body) → 5-element bindings with =
;; Both expand to nested let
(define (expand-do datum)
  (unless (and (list? datum) (>= (length datum) 2))
    (error 'do "do requires at least a body"))
  (define parts (cdr datum))  ; everything after 'do
  (define body (last parts))
  (define bindings (drop-right parts 1))
  (if (null? bindings)
      body  ; no bindings, just the body
      (let ([let-bindings
             (for/list ([b (in-list bindings)])
               (cond
                 ;; NEW: (name ($angle-type T) value) — 3 elements
                 [(and (list? b) (= (length b) 3)
                       (pair? (cadr b)) (eq? (car (cadr b)) '$angle-type))
                  (define name (car b))
                  (define angle-form (cadr b))
                  (define type
                    (if (= (length (cdr angle-form)) 1)
                        (cadr angle-form)
                        (cdr angle-form)))
                  (list name ': type (caddr b))]
                 ;; OLD: (name : type = value) — 5 elements
                 [(and (list? b) (= (length b) 5))
                  (list (car b) (cadr b) (caddr b) (list-ref b 4))]
                 [else
                  (error 'do "do: each binding must be [name <type> value] or [name : type = value], got ~a" b)]))])
        `(let ,let-bindings ,body))))

;; cond: multi-way conditional dispatch
;; (cond ($pipe guard1 -> body1) ($pipe guard2 -> body2) ...)
;;   → (if guard1 body1 (if guard2 body2 ...))
;; The last arm should typically be `| true -> default`.
;; If no arm matches, evaluates to a typed hole (__cond-fail).
(define (expand-cond datum)
  (unless (and (list? datum) (>= (length datum) 2))
    (error 'cond "cond requires at least one arm: (cond | guard -> body ...)"))
  (define arms (cdr datum))
  (define parsed
    (for/list ([arm arms])
      ;; Strip $pipe prefix if present (WS mode); otherwise use as-is (sexp mode)
      (define parts
        (cond
          [(and (list? arm) (pair? arm)
                (eq? (car arm) '$pipe))
           (cdr arm)]
          [(list? arm) arm]
          [else (error 'cond "cond: each arm must be (guard -> body), got ~a" arm)]))
      ;; Find -> separator
      (define arrow-pos (index-of-symbol '-> parts))
      (unless arrow-pos
        (error 'cond "cond arm missing ->: ~a" arm))
      (define guard-parts (take parts arrow-pos))
      (define body-parts (drop parts (+ arrow-pos 1)))
      (when (null? guard-parts)
        (error 'cond "cond arm has empty guard: ~a" arm))
      (when (null? body-parts)
        (error 'cond "cond arm has empty body: ~a" arm))
      ;; Single form → use directly; multiple forms → implicit application
      (define guard (if (= (length guard-parts) 1)
                        (car guard-parts)
                        guard-parts))
      (define body (if (= (length body-parts) 1)
                       (car body-parts)
                       body-parts))
      (list guard body)))
  ;; Build nested if chain (right fold)
  ;; Last arm wraps in: (if guard body __cond-fail)
  (foldr (lambda (arm rest)
           `(if ,(car arm) ,(cadr arm) ,rest))
         '($typed-hole __cond-fail)
         parsed))

;; if: boolean branching (requires boolrec in core)
;; (if ResultType cond then else) → (boolrec (the (-> Bool (Type 0)) (fn (_ : Bool) ResultType)) then else cond)
;; The motive must be annotated with `the` so boolrec can synthesize its type.
;; Note: The expansion uses old colon syntax internally since macros generate
;; internal forms that the parser's backward compatibility handles.
(define (expand-if datum)
  (unless (and (list? datum) (or (= (length datum) 4) (= (length datum) 5)))
    (error 'if "if requires: (if cond then else) or (if ResultType cond then else)"))
  (cond
    ;; Sprint 10: 3-arg form — (if cond then else), motive inferred via hole
    [(= (length datum) 4)
     (define cond-expr (list-ref datum 1))
     (define then-expr (list-ref datum 2))
     (define else-expr (list-ref datum 3))
     ;; Use `_` as motive — parser converts to surf-hole, boolrec wraps it,
     ;; type checker infers result type from checking context.
     `(boolrec _ ,then-expr ,else-expr ,cond-expr)]
    ;; 4-arg form — (if ResultType cond then else), backward compat
    [else
     (define result-type (list-ref datum 1))
     (define cond-expr (list-ref datum 2))
     (define then-expr (list-ref datum 3))
     (define else-expr (list-ref datum 4))
     ;; Use constant motive shorthand — the parser wraps bare types automatically.
     `(boolrec ,result-type ,then-expr ,else-expr ,cond-expr)]))

;; list literal: '[1 2 3] → (cons 1 (cons 2 (cons 3 nil)))
;; The WS reader produces ($list-literal e1 e2 ...) and ($list-tail tail)
;; for the pipe syntax '[1 2 | ys].
;; Expansion:
;;   ($list-literal)             → nil
;;   ($list-literal 1 2 3)      → (cons 1 (cons 2 (cons 3 nil)))
;;   ($list-literal 1 ($list-tail ys)) → (cons 1 ys)
;;   ($list-literal 1 2 ($list-tail ys)) → (cons 1 (cons 2 ys))
(define (expand-list-literal datum)
  (unless (and (list? datum) (>= (length datum) 1)
               (eq? (car datum) '$list-literal))
    (error '$list-literal "expected ($list-literal ...), got ~a" datum))
  (define elems (cdr datum))
  (cond
    [(null? elems) 'nil]
    [else
     ;; Build nested cons from right to left
     ;; Check if the last element is a ($list-tail ...) sentinel
     (define last-elem (last elems))
     (define-values (proper-elems tail)
       (if (and (list? last-elem)
                (not (null? last-elem))
                (eq? (car last-elem) '$list-tail))
           ;; Tail syntax: the last element is ($list-tail expr)
           (values (drop-right elems 1) (cadr last-elem))
           ;; No tail: terminate with nil
           (values elems 'nil)))
     (foldr (lambda (elem rest) `(cons ,elem ,rest))
            tail
            proper-elems)]))

;; lseq literal: ~[1 2 3] → nested lseq-cell with thunks
;; The WS reader produces ($lseq-literal e1 e2 ...).
;; Expansion:
;;   ($lseq-literal)         → lseq-nil
;;   ($lseq-literal 1 2 3)  → (lseq-cell 1 (fn (_ : Unit) (lseq-cell 2 (fn (_ : Unit) (lseq-cell 3 (fn (_ : Unit) lseq-nil))))))
;; The implicit type parameter {A} of lseq-cell/lseq-nil is inferred
;; by the type checker (same pattern as '[...] list literal using cons/nil).
(define (expand-lseq-literal datum)
  (unless (and (list? datum) (>= (length datum) 1)
               (eq? (car datum) '$lseq-literal))
    (error '$lseq-literal "expected ($lseq-literal ...), got ~a" datum))
  (define elems (cdr datum))
  (foldr (lambda (elem rest)
           `(lseq-cell ,elem (fn (_ : Unit) ,rest)))
         'lseq-nil
         elems))

;; ========================================
;; Pipe (|>) and Compose (>>) Operators
;; ========================================
;; |> threads a value through a pipeline of function applications (left-fold).
;; >> composes functions/transducers left-to-right.
;;
;; WS reader produces: (data $pipe-gt map f $pipe-gt filter p)
;; Sexp mode uses head-symbol: (|> data (map f) (filter p))
;;
;; Desugaring rules for |>:
;;   (data $pipe-gt f)             → (f data)
;;   (data $pipe-gt f a b)         → (f a b data)          ;; multi-arg: last position
;;   (data $pipe-gt insert _ table) → (insert data table)   ;; _ placeholder
;;   (data $pipe-gt f $pipe-gt g)  → (g (f data))          ;; chaining
;;
;; Desugaring rules for >>:
;;   (f $compose g)               → (fn ($>>0 : _) (g (f $>>0)))
;;   (f $compose g $compose h)    → (fn ($>>0 : _) (h (g (f $>>0))))

;; Split a flat list on occurrences of a symbol.
;; Returns list of segments (each a list of the elements between the symbol).
(define (split-on-infix-symbol sym lst)
  (let loop ([remaining lst] [current '()] [result '()])
    (cond
      [(null? remaining)
       (reverse (cons (reverse current) result))]
      [(eq? (car remaining) sym)
       (loop (cdr remaining) '() (cons (reverse current) result))]
      [else
       (loop (cdr remaining) (cons (car remaining) current) result)])))

;; Count bare _ at the top level of a list (not inside sub-lists).
(define (count-top-level-underscores atoms)
  (for/sum ([x (in-list atoms)])
    (if (eq? x '_) 1 0)))

;; Apply a pipe step to an accumulated value.
;; step is a list of atoms (the segment between |> markers).
;; acc is the accumulated expression from the left.
(define (apply-pipe-step acc step)
  (cond
    ;; Empty step — error
    [(null? step)
     (error 'pipe "|> pipe step cannot be empty")]
    ;; Single element — bare function name: (f acc)
    [(and (= (length step) 1) (not (list? (car step))))
     `(,(car step) ,acc)]
    [else
     (define n-holes (count-top-level-underscores step))
     (cond
       [(= n-holes 0)
        ;; No _: append accumulated value to end → (f args... acc)
        (append step (list acc))]
       [(= n-holes 1)
        ;; One _: substitute _ with accumulated value
        (map (lambda (x) (if (eq? x '_) acc x)) step)]
       [else
        (error 'pipe "Multiple _ placeholders in pipe step — use explicit lambda instead")])]))

;; Rewrite |> pipe operator in a flat datum.
;; (data $pipe-gt step1 $pipe-gt step2 ...) → nested application
(define (rewrite-pipe datum)
  (define segments (split-on-infix-symbol '$pipe-gt datum))
  (when (< (length segments) 2)
    (error 'pipe "|> requires at least a value and one step"))
  ;; First segment is the initial value (may be multi-atom → application)
  (define init
    (let ([seg (car segments)])
      (if (= (length seg) 1)
          (car seg)
          seg)))  ; multi-atom first segment stays as-is (an application)
  ;; Left-fold subsequent segments
  (foldl (lambda (step acc) (apply-pipe-step acc step))
         init
         (cdr segments)))

;; Apply a compose step: wrap fn around the accumulated expression.
(define (make-compose-step step acc)
  (cond
    [(null? step)
     (error '>> ">> compose step cannot be empty")]
    [(and (= (length step) 1) (not (list? (car step))))
     `(,(car step) ,acc)]
    [else
     (define n-holes (count-top-level-underscores step))
     (cond
       [(= n-holes 0)
        (append step (list acc))]
       [(= n-holes 1)
        (map (lambda (x) (if (eq? x '_) acc x)) step)]
       [else
        (error '>> "Multiple _ placeholders in compose step — use explicit lambda")])]))

;; Rewrite >> compose operator in a flat datum.
;; (f $compose g $compose h) → (fn ($>>0 : _) (h (g (f $>>0))))
(define (rewrite-compose datum)
  (define segments (split-on-infix-symbol '$compose datum))
  (when (< (length segments) 2)
    (error '>> ">> requires at least two functions"))
  (define var '$>>0)
  ;; Build the innermost application from the first segment
  (define inner
    (let ([seg (car segments)])
      (if (and (= (length seg) 1) (not (list? (car seg))))
          `(,(car seg) ,var)
          (append seg (list var)))))
  ;; Left-fold outward: each step wraps around the accumulated expression
  (define body
    (foldl (lambda (step acc) (make-compose-step step acc))
           inner
           (cdr segments)))
  ;; Wrap in lambda
  `(fn (,var : _) ,body))

;; Canonicalize infix |> in a flat datum to block form ($pipe-gt init step1 step2 ...).
;; (x $pipe-gt f a $pipe-gt g b) → ($pipe-gt x (f a) (g b))
;; This routes through the registered $pipe-gt macro for unified expansion.
(define (canonicalize-infix-pipe datum)
  (define segments (split-on-infix-symbol '$pipe-gt datum))
  (when (< (length segments) 2)
    (error 'pipe "|> requires at least a value and one step"))
  ;; First segment is the initial value
  (define init-seg (car segments))
  (define init (if (= (length init-seg) 1) (car init-seg) init-seg))
  ;; Subsequent segments stay as-is — each segment is already a list of
  ;; the atoms/forms between |> markers. This preserves the semantics that
  ;; apply-pipe-step expects: (f a b) is a multi-element step.
  ;; A single-element segment like ((fn ...)) stays as ((fn ...)) so that
  ;; apply-pipe-step sees a one-element list whose car is a list → application.
  `($pipe-gt ,init ,@(cdr segments)))

;; ============================================================
;; Implicit map rewriting
;; ============================================================
;; Rewrites keyword-headed tails in def/defn forms into $brace-params map literals.
;; (def m (:name "Alice") (:age 25N)) → (def m ($brace-params :name "Alice" :age 25N))
;; Nested: (:server (:host "h") (:port 8080)) → :server ($brace-params :host "h" :port 8080)
;; Dash children: (:items (- (:k1 v1)) (- (:k2 v2))) → :items ($vec-literal ...)

;; Is x a list whose car is a keyword-like symbol (starts with :)?
(define (keyword-headed? x)
  (and (pair? x) (keyword-like-symbol? (car x))))

;; Is x a list whose car is the symbol '-'?
(define (dash-headed? x)
  (and (pair? x) (eq? (car x) '-)))

;; Are all elements in lst keyword-headed or dash-headed?
(define (all-keyword-or-dash-headed? lst)
  (and (pair? lst)
       (andmap (lambda (x) (or (keyword-headed? x) (dash-headed? x))) lst)))

;; Does datum have a non-empty keyword-headed tail?
(define (has-keyword-tail? datum)
  (and (pair? datum)
       (>= (length datum) 2)
       (let loop ([elems (cdr datum)])
         (cond
           [(null? elems) #f]
           [(and (pair? elems) (or (keyword-headed? (car elems)) (dash-headed? (car elems)))
                 (all-keyword-or-dash-headed? elems))
            #t]
           [else (loop (cdr elems))]))))

;; Split datum into prefix + keyword tail.
;; Returns (values prefix keyword-tail) where keyword-tail is the longest
;; suffix of keyword-headed/dash-headed elements.
(define (split-keyword-tail datum)
  (define len (length datum))
  ;; Find the first index from which all remaining are keyword/dash-headed
  (define start-idx
    (let loop ([i (- len 1)])
      (cond
        [(< i 0) 0]
        [(or (keyword-headed? (list-ref datum i))
             (dash-headed? (list-ref datum i)))
         (loop (- i 1))]
        [else (+ i 1)])))
  (values (take datum start-idx) (drop datum start-idx)))

;; Process one keyword-headed child (:key val1 val2 ...) into key + processed value.
;; Returns a list of elements to splice into $brace-params.
(define (process-implicit-map-child child)
  (define key (car child))
  (define vals (cdr child))
  (cond
    ;; (:key) — keyword with no value (error, but pass through)
    [(null? vals) (list key)]
    ;; (:key val) — single value
    [(and (= (length vals) 1) (not (keyword-headed? (car vals))) (not (dash-headed? (car vals))))
     (list key (car vals))]
    ;; (:key (- ...) (- ...) ...) — all dash-headed → PVec of processed elements
    [(andmap dash-headed? vals)
     (list key `($vec-literal ,@(map process-dash-child vals)))]
    ;; (:key (:k2 v2) (:k3 v3) ...) — nested keyword children → recursive map
    [(all-keyword-or-dash-headed? vals)
     (list key (implicit-map-children->brace-params vals))]
    ;; Fallback: multiple values that aren't all keyword-headed — leave as-is
    [else (list key (if (= (length vals) 1) (car vals) vals))]))

;; Process one dash-headed child (- child1 child2 ...) into a PVec element.
(define (process-dash-child child)
  (define vals (cdr child))
  (cond
    ;; (- (:k1 v1) (:k2 v2)) — keyword children → nested map
    [(and (pair? vals) (all-keyword-or-dash-headed? vals))
     (implicit-map-children->brace-params vals)]
    ;; (- val) — single value
    [(and (pair? vals) (null? (cdr vals)))
     (car vals)]
    ;; (- v1 v2 ...) — multiple non-keyword values, wrap in list
    [else `(,@vals)]))

;; Convert a list of keyword-headed children to ($brace-params k1 v1 k2 v2 ...).
(define (implicit-map-children->brace-params children)
  `($brace-params ,@(apply append (map process-implicit-map-child
                                       (filter keyword-headed? children)))))

;; Top-level: detect def/defn forms with keyword-headed tails, rewrite.
(define (rewrite-implicit-map datum)
  (cond
    [(not (list? datum)) datum]
    [(null? datum) datum]
    ;; Property forms: dash-headed children are clauses (not map entries).
    ;; Separate dash clauses from keyword metadata, flatten dash internals.
    [(and (pair? datum)
          (eq? (car datum) 'property)
          (has-keyword-tail? datum))
     (define-values (prefix keyword-tail) (split-keyword-tail datum))
     ;; Partition tail into keyword-headed (metadata) and dash-headed (clauses)
     (define kw-children (filter keyword-headed? keyword-tail))
     (define dash-children (filter dash-headed? keyword-tail))
     ;; Flatten each dash clause's internal keyword-headed children:
     ;; (- :name "refl" (:holds expr)) → (- :name "refl" :holds expr)
     (define flat-dash-children
       (map (lambda (dc)
              (cons (car dc) ;; -
                    (apply append
                      (map (lambda (elem)
                             (cond
                               [(and (pair? elem) (keyword-headed? elem))
                                ;; (:holds expr) → :holds expr
                                elem]
                               [else (list elem)]))
                           (cdr dc)))))
            dash-children))
     ;; Build metadata $brace-params from keyword children only
     (define meta
       (if (pair? kw-children)
           (list (implicit-map-children->brace-params kw-children))
           '()))
     (append prefix flat-dash-children meta)]
    ;; Scope: only def/defn/spec/trait/property/functor head forms that have a keyword tail
    [(and (pair? datum)
          (memq (car datum) '(def defn spec trait property functor))
          (has-keyword-tail? datum))
     (define-values (prefix keyword-tail) (split-keyword-tail datum))
     (define brace-contents (implicit-map-children->brace-params keyword-tail))
     (append prefix (list brace-contents))]
    [else datum]))

;; ============================================================
;; Dot-access rewriting
;; ============================================================
;; Rewrites ($dot-access field) and ($dot-key :kw) sentinels into map-get calls.
;; Called from preparse-expand-subforms BEFORE infix operator rewriting, so that
;; `user.name |> string-length` first becomes `(map-get user :name)` then pipes.

;; Check if a datum element is a ($dot-access field) sentinel
(define (dot-access? x)
  (and (list? x) (= (length x) 2) (eq? (car x) '$dot-access)))

;; Check if a datum element is a ($dot-key :kw) sentinel
(define (dot-key? x)
  (and (list? x) (= (length x) 2) (eq? (car x) '$dot-key)))

;; Check if a datum element is a ($nil-dot-access field) sentinel
(define (nil-dot-access? x)
  (and (list? x) (= (length x) 2) (eq? (car x) '$nil-dot-access)))

;; Check if a datum element is a ($nil-dot-key :kw) sentinel
(define (nil-dot-key? x)
  (and (list? x) (= (length x) 2) (eq? (car x) '$nil-dot-key)))

;; Check if a datum element is a ($postfix-index key) sentinel
(define (postfix-index? x)
  (and (list? x) (= (length x) 2) (eq? (car x) '$postfix-index)))

;; Check if a datum element is a ($broadcast-access field) sentinel
(define (broadcast-access? x)
  (and (list? x) (= (length x) 2) (eq? (car x) '$broadcast-access)))

;; Is this element any kind of access sentinel?
(define (access-sentinel? x)
  (or (dot-access? x) (dot-key? x)
      (nil-dot-access? x) (nil-dot-key? x)
      (postfix-index? x) (broadcast-access? x)))

;; Unified rewrite for ALL access sentinels in a flat datum list.
;; Handles: $dot-access, $dot-key, $nil-dot-access, $nil-dot-key, $postfix-index
;; All are "consume preceding element" operations, processed left-to-right.
;;
;; Pattern 1: (expr ($dot-access f1) ($postfix-index k) ($dot-access f2) ...)
;;   → fold left: (map-get (get (map-get expr :f1) k) :f2)
;; Pattern 2: (($dot-key :kw) expr) or (($nil-dot-key :kw) expr) at head
;;   → (map-get expr :kw) or (nil-safe-get expr :kw)
;; Pattern 3: standalone ($dot-key :kw) or ($nil-dot-key :kw)
;;   → partial fn
(define (rewrite-dot-access datum)
  (cond
    [(not (list? datum)) datum]
    [(null? datum) datum]
    ;; Check for any access sentinels in the list
    [(not (ormap access-sentinel? datum))
     datum]
    ;; Pattern 2a: ($dot-key :kw) at head, with at least one more element
    [(and (dot-key? (car datum)) (>= (length datum) 2))
     (define kw (cadr (car datum)))
     (define expr (cadr datum))
     (define rest-elems (cddr datum))
     (define rewritten `(map-get ,expr ,kw))
     (if (null? rest-elems)
         rewritten
         (rewrite-dot-access (cons rewritten rest-elems)))]
    ;; Pattern 3a: standalone ($dot-key :kw) — single element list
    [(and (= (length datum) 1) (dot-key? (car datum)))
     (define kw (cadr (car datum)))
     `(fn ($x : _) (map-get $x ,kw))]
    ;; Pattern 2b: ($nil-dot-key :kw) at head, with at least one more element
    [(and (nil-dot-key? (car datum)) (>= (length datum) 2))
     (define kw (cadr (car datum)))
     (define expr (cadr datum))
     (define rest-elems (cddr datum))
     (define rewritten `(nil-safe-get ,expr ,kw))
     (if (null? rest-elems)
         rewritten
         (rewrite-dot-access (cons rewritten rest-elems)))]
    ;; Pattern 3b: standalone ($nil-dot-key :kw) — single element list
    [(and (= (length datum) 1) (nil-dot-key? (car datum)))
     (define kw (cadr (car datum)))
     `(fn ($x : _) (nil-safe-get $x ,kw))]
    ;; Unified fold-left for all access sentinels
    [else
     (define result
       (let loop ([elems datum] [acc '()])
         (cond
           [(null? elems) (reverse acc)]
           [(dot-access? (car elems))
            (if (null? acc)
                (loop (cdr elems) (cons (car elems) acc))
                (let* ([field (cadr (car elems))]
                       [target (car acc)]
                       [wrapped `(map-get ,target ,(string->symbol
                                                     (string-append ":" (symbol->string field))))])
                  (loop (cdr elems) (cons wrapped (cdr acc)))))]
           [(nil-dot-access? (car elems))
            (if (null? acc)
                (loop (cdr elems) (cons (car elems) acc))
                (let* ([field (cadr (car elems))]
                       [target (car acc)]
                       [wrapped `(nil-safe-get ,target ,(string->symbol
                                                          (string-append ":" (symbol->string field))))])
                  (loop (cdr elems) (cons wrapped (cdr acc)))))]
           [(postfix-index? (car elems))
            (if (null? acc)
                (loop (cdr elems) (cons (car elems) acc))
                (let* ([key (cadr (car elems))]
                       [target (car acc)]
                       [wrapped `(get ,target ,key)])
                  (loop (cdr elems) (cons wrapped (cdr acc)))))]
           [(dot-key? (car elems))
            (if (null? acc)
                (loop (cdr elems) (cons (car elems) acc))
                (let* ([kw (cadr (car elems))]
                       [target (car acc)]
                       [wrapped `(map-get ,target ,kw)])
                  (loop (cdr elems) (cons wrapped (cdr acc)))))]
           [(nil-dot-key? (car elems))
            (if (null? acc)
                (loop (cdr elems) (cons (car elems) acc))
                (let* ([kw (cadr (car elems))]
                       [target (car acc)]
                       [wrapped `(nil-safe-get ,target ,kw)])
                  (loop (cdr elems) (cons wrapped (cdr acc)))))]
           [(broadcast-access? (car elems))
            (if (null? acc)
                ;; No target yet — standalone broadcast, keep as-is
                (loop (cdr elems) (cons (car elems) acc))
                ;; Broadcast: consume target + collect subsequent dot-access for deep path
                (let* ([field (cadr (car elems))]
                       [target (car acc)])
                  ;; Collect subsequent $dot-access sentinels for deep broadcast
                  (define-values (deep-fields remaining)
                    (let collect ([r (cdr elems)] [fields '()])
                      (if (and (pair? r) (dot-access? (car r)))
                          (collect (cdr r) (cons (cadr (car r)) fields))
                          (values (reverse fields) r))))
                  ;; Build the chained map-get body: x.field.sub1.sub2...
                  (define all-fields (cons field deep-fields))
                  (define body
                    (foldl (lambda (f acc)
                             `(map-get ,acc ,(string->symbol
                                              (string-append ":" (symbol->string f)))))
                           '$broadcast-var
                           all-fields))
                  ;; Desugar to (broadcast-get target :field1 :field2 ...) — a form
                  ;; the parser handles, avoiding the map+lambda inference gap.
                  (define kw-fields
                    (map (lambda (f) (string->symbol (string-append ":" (symbol->string f))))
                         all-fields))
                  (define wrapped `(broadcast-get ,target ,@kw-fields))
                  (loop remaining (cons wrapped (cdr acc)))))]
           [else
            (loop (cdr elems) (cons (car elems) acc))])))
     ;; If result is a single-element list, unwrap it
     (if (and (pair? result) (null? (cdr result)))
         (car result)
         result)]))

;; Backward-compatible alias — rewrite-nil-dot-access now handled by rewrite-dot-access
(define (rewrite-nil-dot-access datum)
  (rewrite-dot-access datum))

;; Rewrite infix operators ($pipe-gt, $compose) in a datum.
;; Called from preparse-expand-subforms before recursing into subexpressions.
;; For |>: canonicalizes to block form ($pipe-gt init step1 ...) so the registered
;; macro handles fusion uniformly for both infix and block syntax.
;; Sexp reader parity: also recognizes >> (bare Racket symbol) as alias for $compose.
(define (rewrite-infix-operators datum)
  (cond
    [(not (list? datum)) datum]
    ;; Normalize >> → $compose for reader parity (sexp mode reads >> as symbol >>)
    [(memq '>> datum)
     (rewrite-infix-operators
      (map (lambda (x) (if (eq? x '>>) '$compose x)) datum))]
    ;; Check for $pipe-gt (|>) as infix in the flat list (not at head position)
    [(and (memq '$pipe-gt datum)
          (not (eq? (car datum) '$pipe-gt)))
     (canonicalize-infix-pipe datum)]
    ;; Check for $compose (>>) anywhere in the flat list
    [(memq '$compose datum) (rewrite-compose datum)]
    [else datum]))

;; ========================================
;; Block-form pipe macro with loop fusion
;; ========================================
;; ($pipe-gt init step1 step2 ...) — block-form pipe with automatic fusion.
;; Consecutive fusible operations (map, filter, remove) are composed into a
;; single transducer pass via xf-compose + transduce/xf-into-list.
;; Non-fusible operations act as barriers that materialize intermediate results.

;; --- Step classification tables ---
(define pipe-fusible-ops '(map filter remove))
(define pipe-terminal-ops '(reduce sum length count))
(define pipe-barrier-ops '(sort reverse partition zip zip-with dedup scanl foldr
                           foldr1 concat concat-map take drop take-while drop-while
                           append intersperse span break))

;; Classify a pipe step: 'fusible, 'terminal, 'barrier, or 'plain.
(define (classify-pipe-step step)
  (cond
    [(not (list? step)) 'plain]
    [(null? step) (error 'pipe "|> pipe step cannot be empty")]
    [else
     (define head (car step))
     (define has-underscore (> (count-top-level-underscores step) 0))
     (cond
       ;; _ in the step → positional application, not fusible
       [has-underscore 'plain]
       ;; Fusible: exactly (op arg) with no extra args
       [(and (memq head pipe-fusible-ops) (= (length step) 2)) 'fusible]
       ;; Terminal: consumes the pipeline
       [(memq head pipe-terminal-ops) 'terminal]
       ;; Barrier: materializes intermediate list
       [(memq head pipe-barrier-ops) 'barrier]
       [else 'plain])]))

;; ---- Inline reducer composition for loop fusion ----
;; Instead of emitting transducer API calls (which need explicit type args),
;; we build composed reducers inline. This achieves O(n) single-pass
;; using only `reduce` (which works with implicit type inference).
;;
;; A fusible chain [map f, filter p, map g] with reducer rf and init z produces:
;;   (reduce (fn ($a : _) (fn ($x0 : _)
;;     (let $x1 := (f $x0)
;;       (if (p $x1)
;;           (let $x2 := (g $x1)
;;             (rf $a $x2))
;;           $a))))
;;     z xs)
;;
;; Each fusible step wraps the body:
;;   map f    → let $xN := (f $xPrev) ... continue with $xN
;;   filter p → if (p $xPrev) ... continue ... else $acc
;;   remove p → if (p $xPrev) $acc else ... continue ...

;; Generate a unique symbol for the Nth element variable in the fused reducer.
(define (pipe-var n) (string->symbol (format "$x~a" n)))

;; Build a fused inline reducer from a chain of fusible steps.
;; Returns a lambda: (fn ($a : _) (fn ($x0 : _) body))
;; where body composes all the fusible transforms in a single pass.
;;
;; The function tracks the "current element" variable. Map steps introduce
;; a new let-binding (transforming the element), while filter/remove steps
;; conditionally pass through the current element unchanged.
;;
;; make-inner: procedure (current-var -> expr) that produces the innermost
;;   expression using the final element variable.
;;   For reduce terminal: (lambda (v) `(rf $a ,v))
;;   For materialization: (lambda (v) `(cons _ ,v $a))
;; acc-sym: the accumulator variable name (e.g., '$a)
(define (build-fused-reducer fusible-steps make-inner acc-sym)
  (define x0 (pipe-var 0))
  ;; Walk steps left-to-right, building the body by nesting.
  ;; Each step either wraps a let (map) or wraps an if (filter/remove).
  ;; The "current variable" tracks what name holds the current element.
  (define body
    (let loop ([steps fusible-steps]
               [cur-var x0]       ;; current element variable
               [var-counter 1])   ;; next variable index for map bindings
      (if (null? steps)
          ;; All steps consumed → emit the inner rf call with current element
          (make-inner cur-var)
          (let* ([step (car steps)]
                 [head (car step)]
                 [arg (cadr step)])
            (case head
              [(map)
               ;; Bind new variable: let $xN := (f cur-var) ... continue with $xN
               (define new-var (pipe-var var-counter))
               `(let ,new-var := (,arg ,cur-var)
                  ,(loop (cdr steps) new-var (+ var-counter 1)))]
              [(filter)
               ;; Guard: if (p cur-var) continue else $acc
               `(if (,arg ,cur-var)
                    ,(loop (cdr steps) cur-var var-counter)
                    ,acc-sym)]
              [(remove)
               ;; Guard: if (p cur-var) $acc else continue
               `(if (,arg ,cur-var)
                    ,acc-sym
                    ,(loop (cdr steps) cur-var var-counter))])))))
  ;; Wrap in lambda: (fn ($a : _) (fn ($x0 : _) body))
  `(fn (,acc-sym : _) (fn (,x0 : _) ,body)))

;; Flush a pending fusible chain by materializing into a list.
;; Emits sequential applications: (filter p (map f xs)).
;; Terminal steps use inline fusion (single-pass O(n)) via build-fused-reducer.
;; Materialization uses sequential function calls, which is multi-pass but correct
;; and avoids needing explicit type args on cons/nil/reverse.
;; If chain is empty, return acc unchanged.
(define (flush-xf-chain xf-chain acc)
  (if (null? xf-chain)
      acc
      ;; Build sequential: (filter p (map f acc))
      (foldl (lambda (step result)
               (apply-pipe-step result step))
             acc
             xf-chain)))

;; Expand a terminal step, optionally fusing with pending fusible chain.
(define (expand-terminal step xf-chain acc)
  (define head (car step))
  (case head
    [(reduce)
     (unless (= (length step) 3)
       (error 'pipe "|> reduce requires exactly 2 arguments: reduce <rf> <init>"))
     (define rf (cadr step))
     (define init-val (caddr step))
     (if (null? xf-chain)
         `(reduce ,rf ,init-val ,acc)
         ;; Fuse: build inline reducer that composes fusible ops with rf
         (let* ([acc-sym '$a]
                [make-inner (lambda (v) `(,rf ,acc-sym ,v))]
                [fused-rf (build-fused-reducer xf-chain make-inner acc-sym)])
           `(reduce ,fused-rf ,init-val ,acc)))]
    [(sum)
     (unless (= (length step) 1)
       (error 'pipe "|> sum takes no arguments"))
     (if (null? xf-chain)
         `(sum ,acc)
         ;; Fuse: sum = reduce add zero
         (let* ([acc-sym '$a]
                [make-inner (lambda (v) `(add ,acc-sym ,v))]
                [fused-rf (build-fused-reducer xf-chain make-inner acc-sym)])
           `(reduce ,fused-rf zero ,acc)))]
    [(length)
     (unless (= (length step) 1)
       (error 'pipe "|> length takes no arguments"))
     (if (null? xf-chain)
         `(length _ ,acc)
         ;; Fuse: length = reduce (fn [n _] suc n) zero (ignore element)
         (let* ([acc-sym '$a]
                [make-inner (lambda (_v) `(suc ,acc-sym))]
                [fused-rf (build-fused-reducer xf-chain make-inner acc-sym)])
           `(reduce ,fused-rf zero ,acc)))]
    [(count)
     (unless (= (length step) 2)
       (error 'pipe "|> count requires exactly 1 argument: count <pred>"))
     (define pred (cadr step))
     ;; Fuse count p = filter p then count = length
     ;; Add filter to the chain, then use length reducer
     (define all-steps (append xf-chain (list `(filter ,pred))))
     (let* ([acc-sym '$a]
            [make-inner (lambda (_v) `(suc ,acc-sym))]
            [fused-rf (build-fused-reducer all-steps make-inner acc-sym)])
       `(reduce ,fused-rf zero ,acc))]
    [else
     ;; Unknown terminal — flush and apply as plain step
     (define flushed-acc (flush-xf-chain xf-chain acc))
     (apply-pipe-step flushed-acc step)]))

;; Main block-form pipe expander with loop fusion.
;; ($pipe-gt init step1 step2 ...) → fused pipeline
(define (expand-pipe-block datum)
  (define parts (cdr datum))  ; everything after $pipe-gt
  (when (null? parts)
    (error 'pipe "|> requires at least a value"))
  (define init (car parts))
  (define steps (cdr parts))

  ;; Normalize: bare symbols become 1-element lists
  (define normalized-steps
    (map (lambda (s) (if (list? s) s (list s))) steps))

  ;; No steps → return init unchanged
  (if (null? normalized-steps)
      init
      ;; Process steps with fusion
      (let loop ([remaining normalized-steps]
                 [acc init]
                 [xf-chain '()])
        (if (null? remaining)
            ;; End of pipeline: flush any pending transducers
            (flush-xf-chain xf-chain acc)
            (let* ([step (car remaining)]
                   [rest (cdr remaining)]
                   [class (classify-pipe-step step)])
              (case class
                [(fusible)
                 ;; Accumulate raw step datum — build-fused-reducer handles it
                 (loop rest acc (append xf-chain (list step)))]
                [(terminal)
                 ;; Error if more steps follow a terminal
                 (unless (null? rest)
                   (error 'pipe "|> terminal step (~a) must be the last step" (car step)))
                 (expand-terminal step xf-chain acc)]
                [(barrier plain)
                 ;; Flush pending transducers, apply this step
                 (define flushed-acc (flush-xf-chain xf-chain acc))
                 (define new-acc (apply-pipe-step flushed-acc step))
                 (loop rest new-acc '())]))))))

;; Sexp-mode handler: (>> f g h ...)
(define (expand-compose-sexp datum)
  (define fns (cdr datum))
  (when (< (length fns) 2)
    (error '>> ">> requires at least two functions"))
  (define var '$>>0)
  (define inner
    (let ([f (car fns)])
      (if (list? f) (append f (list var)) `(,f ,var))))
  (define body
    (foldl (lambda (step acc)
             (if (list? step) (append step (list acc)) `(,step ,acc)))
           inner
           (cdr fns)))
  `(fn (,var : _) ,body))

;; ========================================
;; Mixfix syntax: .{...} → Pratt parser
;; ========================================
;; ($mixfix token1 token2 ...) is produced by the WS reader for .{...} forms.
;; The Pratt parser converts infix notation to prefix application.
;; .{a + b * c} → ($mixfix a + b * c) → (add a (mul b c))

;; --- Precedence group definition ---
(struct prec-group (name assoc tighter-than) #:transparent)
;; name: symbol (e.g., 'additive)
;; assoc: 'left | 'right | 'none
;; tighter-than: (listof symbol) — names of groups this is tighter than

;; --- Operator info ---
(struct op-info (symbol fn-name group assoc left-bp right-bp swap?) #:transparent)
;; symbol: the operator symbol as it appears in .{...} (e.g., '+)
;; fn-name: the prefix function name to desugar to (e.g., 'add)
;; group: symbol name of the precedence group
;; assoc: 'left | 'right | 'none
;; left-bp / right-bp: integer binding powers (computed from DAG)

;; --- Fixed precedence DAG (Phase 1) ---
;; Groups from loosest to tightest:
;;   pipe < logical-or < logical-and < comparison < additive < multiplicative < exponential < composition
;;                                                < cons (right)
;; Note: additive and cons are UNRELATED (forces explicit grouping)

(define builtin-precedence-groups
  (hasheq
   'pipe           (prec-group 'pipe           'left  '())
   'logical-or     (prec-group 'logical-or     'right '(pipe))
   'logical-and    (prec-group 'logical-and    'right '(logical-or))
   'comparison     (prec-group 'comparison     'none  '(logical-and))
   'additive       (prec-group 'additive       'left  '(comparison))
   'cons           (prec-group 'cons           'right '(comparison))
   'multiplicative (prec-group 'multiplicative 'left  '(additive cons))
   'exponential    (prec-group 'exponential    'right '(multiplicative))
   'composition    (prec-group 'composition    'right '(exponential))))

;; Compute binding powers from DAG via topological sort.
;; Returns hash: group-name → (cons left-bp right-bp)
(define (compute-binding-powers groups)
  ;; Build reverse mapping: for each group, what groups are tighter?
  ;; (i.e., which groups list it in their tighter-than)
  ;; We assign levels by depth in the DAG. Loosest = lowest level.

  ;; First, compute depth of each group (longest path from a root)
  (define (group-depth name visited)
    (when (set-member? visited name)
      (error 'mixfix "Cycle in precedence DAG involving group: ~a" name))
    (define g (hash-ref groups name #f))
    (if (or (not g) (null? (prec-group-tighter-than g)))
        0
        (+ 1 (apply max
                (map (lambda (parent)
                       (group-depth parent (set-add visited name)))
                     (prec-group-tighter-than g))))))

  (define depths
    (for/hasheq ([(name _) (in-hash groups)])
      (values name (group-depth name (seteq)))))

  ;; Assign binding powers: depth * 10 gives spacing for future groups
  ;; left-assoc: right-bp = left-bp + 1 (left binds tighter)
  ;; right-assoc: right-bp = left-bp (right binds tighter — same bp means right wins)
  ;; none: right-bp = left-bp (but we'll error on consecutive use)
  (for/hasheq ([(name depth) (in-hash depths)])
    (define g (hash-ref groups name))
    (define base-bp (* depth 10))
    (define left-bp base-bp)
    (define right-bp
      (case (prec-group-assoc g)
        [(left) (+ base-bp 1)]
        [(right) base-bp]
        [(none) (+ base-bp 1)]  ; same as left for single use; chaining checked separately
        [else base-bp]))
    (values name (cons left-bp right-bp))))

(define builtin-binding-powers
  (compute-binding-powers builtin-precedence-groups))

;; --- Built-in operator table ---
(define builtin-operators
  (let ([bps builtin-binding-powers])
    (define (make-op sym fn grp [swap? #f])
      (define bp-pair (hash-ref bps grp))
      (define g (hash-ref builtin-precedence-groups grp))
      (cons sym (op-info sym fn grp (prec-group-assoc g) (car bp-pair) (cdr bp-pair) swap?)))
    (make-hasheq
     (list
      ;; Arithmetic — fn-names are parser keywords that produce surf-generic-* AST nodes
      (make-op '+  '+       'additive)
      (make-op '-  '-       'additive)
      (make-op '*  '*       'multiplicative)
      (make-op '/  '/       'multiplicative)
      (make-op '%  'mod     'multiplicative)
      (make-op '** 'pow     'exponential)
      ;; Comparison — parser keywords lt/le/eq produce surf-generic-* AST nodes
      ;; > and >= rewrite to (lt b a) and (le b a) via swap? flag
      (make-op '== 'eq      'comparison)
      (make-op '=  'eq      'comparison)  ; = is alias for == in mixfix context
      (make-op '/= 'neq     'comparison)
      (make-op '<  'lt      'comparison)
      (make-op '<= 'le      'comparison)
      (make-op '>  'lt      'comparison #t)   ; > a b → (lt b a)
      (make-op '>= 'le      'comparison #t)   ; >= a b → (le b a)
      ;; Logical — use the identifier names (& and | aren't valid token chars)
      (make-op 'and 'and    'logical-and)
      (make-op 'or  'or     'logical-or)
      ;; Cons
      (make-op ':: 'cons    'cons)
      ;; Append (same group as additive)
      (make-op '++ 'append  'additive)
      ;; Pipe / Compose
      (make-op '$pipe-gt '$pipe-gt 'pipe)
      (make-op '$compose '$compose 'composition)))))

;; Check if two groups are comparable in the DAG
;; Returns: 'less | 'greater | 'equal | 'incomparable
(define (compare-groups g1-name g2-name groups)
  (cond
    [(eq? g1-name g2-name) 'equal]
    [else
     ;; Check if g1 is tighter than g2 (g1 is reachable from g2 via tighter-than chains)
     (define (reachable? from to visited)
       (cond
         [(eq? from to) #t]
         [(set-member? visited from) #f]
         [else
          (define g (hash-ref groups from #f))
          (and g
               (for/or ([parent (in-list (prec-group-tighter-than g))])
                 (reachable? parent to (set-add visited from))))]))
     (cond
       [(reachable? g1-name g2-name (seteq)) 'greater]  ; g1 tighter than g2
       [(reachable? g2-name g1-name (seteq)) 'less]     ; g2 tighter than g1
       [else 'incomparable])]))

;; --- Pratt parser ---
;; Takes a list of tokens (datum values from $mixfix) and returns prefix form.
;; Tokens are symbols, numbers, lists (bracket forms), etc.
;; Operators are looked up in the operator table.

(define (pratt-parse tokens [op-table builtin-operators] [groups builtin-precedence-groups])
  (define pos (box 0))
  (define toks (list->vector tokens))
  (define len (vector-length toks))

  (define (peek)
    (if (< (unbox pos) len)
        (vector-ref toks (unbox pos))
        #f))

  (define (advance!)
    (define v (vector-ref toks (unbox pos)))
    (set-box! pos (+ 1 (unbox pos)))
    v)

  (define (at-end?)
    (>= (unbox pos) len))

  (define (lookup-op sym)
    (and (symbol? sym) (hash-ref op-table sym #f)))

  ;; Parse a primary expression (atom, parenthesized group, unary prefix)
  (define (parse-primary)
    (define tok (peek))
    (cond
      [(not tok)
       (error 'mixfix "Unexpected end of expression in .{...}")]
      ;; Unary minus: - followed by non-operator
      [(and (symbol? tok) (eq? tok '-)
            (let ([next-pos (+ 1 (unbox pos))])
              (and (< next-pos len)
                   (let ([next (vector-ref toks next-pos)])
                     (not (lookup-op next))))))
       (advance!) ; consume -
       (define operand (parse-primary))
       (list 'negate operand)]  ; negate is a parser keyword → surf-generic-negate
      ;; Parenthesized group via [] brackets (in .{...}, [...] is explicit grouping)
      [(and (list? tok) (pair? tok))
       (advance!)
       tok]  ; already a parsed form — pass through
      ;; Atom: number, symbol (non-operator), etc.
      [(not (lookup-op tok))
       (advance!)
       tok]
      [else
       (error 'mixfix "Expected expression, got operator: ~a" tok)]))

  ;; Build operator result, respecting swap? flag for > and >=
  (define (make-op-result op lhs rhs)
    (if (op-info-swap? op)
        (list (op-info-fn-name op) rhs lhs)
        (list (op-info-fn-name op) lhs rhs)))

  ;; Check if an operator is in the comparison group
  (define (comparison-op? op)
    (and op (eq? (op-info-group op) 'comparison)))

  ;; Check if a fn-name corresponds to a comparison operator
  (define comparison-fn-names
    (for/seteq ([(sym info) (in-hash op-table)]
                #:when (comparison-op? info))
      (op-info-fn-name info)))

  (define (comparison-form? form)
    (and (pair? form) (= (length form) 3)
         (set-member? comparison-fn-names (car form))))

  ;; Extract the shared operand (rightmost RHS) from a comparison chain.
  ;; Returns #f if the form is not a valid comparison chain.
  ;; - (lt a b) → b
  ;; - (and (lt a b) (le b c)) → c
  ;; - (and (and ...) (gt c d)) → d
  (define (extract-chain-shared form)
    (cond
      [(comparison-form? form) (caddr form)]
      [(and (pair? form) (eq? (car form) 'and) (= (length form) 3))
       ;; (and left right) — extract from the rightmost comparison
       (define right (caddr form))
       (and (comparison-form? right) (caddr right))]
      [else #f]))

  ;; Parse expression with minimum binding power.
  ;; context-group: the group of the operator that set this binding power context (or #f at top-level).
  ;; Used for incomparable-group detection.
  (define (parse-expr min-bp [context-group #f])
    (define lhs (parse-primary))
    ;; last-chain-rhs tracks the actual RHS operand of the last comparison in a chain.
    ;; This is needed because swap? operators reorder args, so we can't extract
    ;; the shared operand from the output form alone.
    (let loop ([lhs lhs] [last-chain-rhs #f])
      (define op-tok (peek))
      (cond
        [(or (not op-tok) (at-end?))
         lhs]
        [else
         (define op (lookup-op op-tok))
         (cond
           [(not op)
            ;; Not an operator — could be juxtaposition or end of expression
            lhs]
           [else
            (define op-left-bp (op-info-left-bp op))
            (define op-grp (op-info-group op))
            ;; Incomparable-group check: if there's a context group and the current
            ;; operator's group is incomparable, error with guidance.
            (when (and context-group (not (eq? context-group op-grp)))
              (define cmp (compare-groups op-grp context-group groups))
              (when (eq? cmp 'incomparable)
                (error 'mixfix
                       (format "Operators from groups '~a' and '~a' have no defined precedence relationship — use [] for explicit grouping"
                               op-grp context-group))))
            ;; Chained comparison detection: if we have a last-chain-rhs (from a previous
            ;; comparison) and the current op is also comparison, chain.
            (cond
              [(and last-chain-rhs (comparison-op? op) (>= op-left-bp min-bp))
               ;; Chained comparison: shared operand = last-chain-rhs
               ;; Desugar: (and lhs (new-cmp shared rhs))
               (advance!) ; consume operator
               (define rhs (parse-expr (op-info-right-bp op) op-grp))
               (define new-cmp (make-op-result op last-chain-rhs rhs))
               (loop (list 'and lhs new-cmp) rhs)]
              [(< op-left-bp min-bp)
               ;; Operator binds less tightly — return lhs
               lhs]
              [(= op-left-bp min-bp)
               ;; Same binding power — check associativity
               (case (op-info-assoc op)
                 [(right) ;; Right-assoc: allow (continue with same min-bp)
                  (advance!) ; consume operator
                  (define rhs (parse-expr (op-info-right-bp op) op-grp))
                  (define result (make-op-result op lhs rhs))
                  (loop result #f)]
                 [(left) ;; Left-assoc: we already collected lhs, don't recurse further
                  lhs]
                 [(none) ;; Non-associative: error on chaining
                  (error 'mixfix
                         "Non-associative operator '~a' cannot be used consecutively — use explicit grouping []"
                         (op-info-symbol op))]
                 [else lhs])]
              [else
               ;; Operator binds tighter — consume and recurse
               (advance!) ; consume operator
               (define rhs (parse-expr (op-info-right-bp op) op-grp))
               (define result (make-op-result op lhs rhs))
               ;; Track chain-rhs for comparison operators
               (define new-chain-rhs (and (comparison-op? op) rhs))
               (loop result new-chain-rhs)])])])))

  (if (= len 0)
      (error 'mixfix "Empty .{} expression")
      (let ([result (parse-expr 0)])
        (unless (at-end?)
          (error 'mixfix "Unexpected token after expression: ~a" (peek)))
        result)))

;; --- Effective operator table (merges builtin + user-defined) ---
;; builtin-operators is a mutable hash; user-operators is immutable.
;; We copy user entries into the mutable table (or return builtin as-is).
(define (effective-operator-table)
  (define user-ops (read-user-operators))
  (if (hash-empty? user-ops)
      builtin-operators
      ;; Create merged mutable hash
      (let ([merged (hash-copy builtin-operators)])
        (for ([(k v) (in-hash user-ops)])
          (hash-set! merged k v))
        merged)))

;; --- Effective precedence groups (merges builtin + user-defined) ---
(define (effective-precedence-groups)
  (define user-groups (read-user-precedence-groups))
  (if (hash-empty? user-groups)
      builtin-precedence-groups
      (for/fold ([h builtin-precedence-groups])
                ([(k v) (in-hash user-groups)])
        (hash-set h k v))))

;; --- Preparse macro for $mixfix ---
(define (expand-mixfix-form datum)
  ;; datum is ($mixfix token1 token2 ...)
  (define tokens (cdr datum))
  (if (null? tokens)
      (error 'mixfix "Empty .{} expression")
      (pratt-parse tokens (effective-operator-table) (effective-precedence-groups))))

;; Register built-in pre-parse macros at module load time
(register-preparse-macro! 'let expand-let)
(register-preparse-macro! 'do expand-do)
(register-preparse-macro! 'if expand-if)
(register-preparse-macro! 'cond expand-cond)
(register-preparse-macro! '$list-literal expand-list-literal)
(register-preparse-macro! '$lseq-literal expand-lseq-literal)
(register-preparse-macro! '$pipe-gt expand-pipe-block)
(register-preparse-macro! '$compose expand-compose-sexp)
(register-preparse-macro! '$mixfix expand-mixfix-form)
;; $quote: code-as-data — 'expr → ($quote expr) → Datum constructor chain
;; Walks the quoted datum and emits Datum constructor calls.
;; Requires prologos::data::datum to be loaded for the constructors to resolve.

;; Helper: check if a symbol is a keyword literal (starts with :)
(define (keyword-like-symbol? s)
  (and (symbol? s)
       (let ([str (symbol->string s)])
         (and (> (string-length str) 1)
              (char=? (string-ref str 0) #\:)))))

;; Convert a raw datum to Datum constructor calls
(define (datum->datum-expr d)
  (cond
    ;; Keyword-like symbols (:foo) → (datum-kw :foo)
    [(keyword-like-symbol? d) `(datum-kw ,d)]
    ;; Regular symbols → (datum-sym (symbol-lit name))
    [(symbol? d) `(datum-sym (symbol-lit ,d))]
    ;; Natural numbers (non-negative integers) → (datum-nat n)
    ;; Use ($nat-literal n) so bare n parses as Nat, not Int
    [(and (exact-integer? d) (>= d 0)) `(datum-nat ($nat-literal ,d))]
    ;; Negative integers → (datum-int n)
    [(exact-integer? d) `(datum-int (int ,d))]
    ;; Rationals → (datum-rat n)
    [(rational? d) `(datum-rat ,d)]
    ;; Booleans → (datum-bool true/false)
    [(boolean? d) (if d '(datum-bool true) '(datum-bool false))]
    ;; Empty list → datum-nil
    [(null? d) 'datum-nil]
    ;; Pairs/lists → (datum-cons car cdr)
    [(pair? d) `(datum-cons ,(datum->datum-expr (car d))
                            ,(datum->datum-expr (cdr d)))]
    ;; Fallback: treat as symbol
    [else `(datum-sym (symbol-lit ,d))]))

(define (expand-quote datum)
  (datum->datum-expr (cadr datum)))

(register-preparse-macro! '$quote expand-quote)

;; ========================================
;; Quasiquote macro: $quasiquote
;; ========================================
;; ($quasiquote datum) walks the datum like datum->datum-expr, but
;; ($unquote expr) nodes are passed through raw (expr must be of type Datum).
;; This allows splicing live expressions into quoted data templates.
;;
;; Example: `(add ,x 2) → ($quasiquote (add ($unquote x) 2))
;; Expands to: (datum-cons (datum-sym (symbol-lit add))
;;               (datum-cons x
;;                 (datum-cons (datum-nat 2) datum-nil)))
;;
;; Where x is passed through as-is (must be Datum at runtime).

(define (qq->datum-expr d)
  (cond
    ;; ($unquote expr) — pass expr through raw
    [(and (pair? d) (eq? (car d) '$unquote) (pair? (cdr d)) (null? (cddr d)))
     (cadr d)]
    ;; Keyword-like symbols (:foo) → (datum-kw :foo)
    [(keyword-like-symbol? d) `(datum-kw ,d)]
    ;; Regular symbols → (datum-sym (symbol-lit name))
    [(symbol? d) `(datum-sym (symbol-lit ,d))]
    ;; Natural numbers → (datum-nat n)
    ;; Use ($nat-literal n) so bare n parses as Nat, not Int
    [(and (exact-integer? d) (>= d 0)) `(datum-nat ($nat-literal ,d))]
    ;; Negative integers → (datum-int n)
    [(exact-integer? d) `(datum-int (int ,d))]
    ;; Rationals → (datum-rat n)
    [(rational? d) `(datum-rat ,d)]
    ;; Booleans → (datum-bool true/false)
    [(boolean? d) (if d '(datum-bool true) '(datum-bool false))]
    ;; Empty list → datum-nil
    [(null? d) 'datum-nil]
    ;; Pairs/lists → (datum-cons car cdr), recursing into elements
    [(pair? d) `(datum-cons ,(qq->datum-expr (car d))
                            ,(qq->datum-expr (cdr d)))]
    ;; Fallback: treat as symbol
    [else `(datum-sym (symbol-lit ,d))]))

(define (expand-quasiquote datum)
  (qq->datum-expr (cadr datum)))

(register-preparse-macro! '$quasiquote expand-quasiquote)

;; ========================================
;; with-transient macro
;; ========================================
;; (with-transient coll (fn [t] body))
;; → (persist! ((fn [t] body) (transient coll)))
;;
;; Enables idiomatic batch construction:
;;   with-transient @[]
;;     fn [t]
;;       let t = [tvec-push! t 1N]
;;       let t = [tvec-push! t 2N]
;;       t
;;   ;; => @[1N 2N]
(define (expand-with-transient datum)
  (cond
    ;; 2-arg form: (with-transient coll fn-expr)
    [(and (list? datum) (= (length datum) 3))
     (let ([coll (cadr datum)]
           [fn-expr (caddr datum)])
       ;; (persist! ((fn-expr) (transient coll)))
       `(|persist!| (,fn-expr (transient ,coll))))]
    ;; Multi-step WS form: (with-transient coll [type-args...] step1 step2 ...)
    ;; In WS mode, collection may span multiple tokens: @[] Nat → ($vec-literal) Nat.
    ;; Steps are application forms (lists starting with a !-suffixed symbol).
    ;; Collection = first arg + any following bare type symbols before steps.
    [(and (list? datum) (>= (length datum) 4))
     (define args (cdr datum))  ;; everything after with-transient
     ;; First arg is always the collection base (may be symbol or list)
     (define coll-base (car args))
     ;; Remaining args: bare symbols = type args for collection, lists = steps
     (define-values (type-args steps)
       (let loop ([remaining (cdr args)] [types '()])
         (cond
           [(null? remaining) (values (reverse types) '())]
           ;; Bare symbol = type argument for collection
           [(symbol? (car remaining))
            (loop (cdr remaining) (cons (car remaining) types))]
           ;; List form = step (stop collecting type args)
           [else (values (reverse types) remaining)])))
     ;; Build collection expression: base + type args wrapped as application
     (define coll
       (if (null? type-args)
           coll-base
           (cons coll-base type-args)))
     (when (null? steps)
       (error 'with-transient "missing steps after collection"))
     ;; Build chained let body: let __t := [step1 __t args...] in let __t := [step2 __t args...] in ...
     ;; Each step (f arg1 arg2 ...) becomes (f __t arg1 arg2 ...)
     (define (inject-transient-arg step)
       (if (pair? step)
           (cons (car step) (cons '__t (cdr step)))
           `(,step __t)))
     (define body
       (let loop ([remaining steps])
         (cond
           [(null? (cdr remaining))
            ;; Last step — just apply it
            (inject-transient-arg (car remaining))]
           [else
            ;; Chain: let __t := [step __t args] in rest
            `(let __t := ,(inject-transient-arg (car remaining))
               ,(loop (cdr remaining)))])))
     (define fn-expr `(fn (__t) ,body))
     `(|persist!| (,fn-expr (transient ,coll)))]
    [else
     (error 'with-transient
            "expected (with-transient coll fn-expr) or (with-transient coll step1 step2 ...), got ~v" datum)]))

(register-preparse-macro! 'with-transient expand-with-transient)

;; ========================================
;; Constructor metadata registry (for reduce)
;; ========================================
;; Stores metadata about each constructor so the type checker can
;; perform structural pattern matching from reduce arms.

;; ctor-meta: type-name, params, field-types, is-recursive flags, branch-index
(struct ctor-meta (type-name params field-types is-recursive branch-index) #:transparent)

;; Registry: ctor-name (symbol) → ctor-meta
(define current-ctor-registry (make-parameter (hasheq)))

;; Type metadata: type-name (symbol) → (list ctor-names-in-order)
(define current-type-meta (make-parameter (hasheq)))

(define (register-ctor! name meta)
  (current-ctor-registry (hash-set (current-ctor-registry) name meta))
  ;; Phase 2a: dual-write to cell
  (macros-cell-write! (current-ctor-registry-cell-id) (hasheq name meta)))

;; Track 3 Phase 1: cell-primary readers
(define (read-ctor-registry)
  (or (macros-cell-read-safe (current-ctor-registry-cell-id)) (current-ctor-registry)))

(define (read-type-meta)
  (or (macros-cell-read-safe (current-type-meta-cell-id)) (current-type-meta)))

(define (lookup-ctor name)
  (hash-ref (read-ctor-registry) name #f))

(define (lookup-type-ctors type-name)
  (hash-ref (read-type-meta) type-name #f))

;; ========================================
;; Built-in constructor metadata (Nat, Bool)
;; ========================================
;; Register Nat and Bool constructors so match/reduce works on them.
;; These are built-in types with no type parameters.

;; Nat: zero (nullary), suc (one recursive Nat field)
(register-ctor! 'zero (ctor-meta 'Nat '() '() '() 0))
(register-ctor! 'suc  (ctor-meta 'Nat '() (list 'Nat) (list #t) 1))
(current-type-meta (hash-set (current-type-meta) 'Nat '(zero suc)))

;; Bool: true (nullary), false (nullary)
(register-ctor! 'true  (ctor-meta 'Bool '() '() '() 0))
(register-ctor! 'false (ctor-meta 'Bool '() '() '() 1))
(current-type-meta (hash-set (current-type-meta) 'Bool '(true false)))

;; Unit: unit (nullary)
(register-ctor! 'unit (ctor-meta 'Unit '() '() '() 0))
(current-type-meta (hash-set (current-type-meta) 'Unit '(unit)))

;; ========================================
;; Subtype registry (Phase E: refined numeric subtyping)
;; ========================================
;; Maps (cons sub-key super-key) → #t for registered subtype relationships.
;; Keys are symbols: 'Int, 'Rat, 'Nat for built-ins; qualified names for user types.
;; Used by typing-core.rkt subtype? as a fallback after hardcoded pairs.
(define current-subtype-registry (make-parameter (hash)))

(define (register-subtype-pair! sub-key super-key)
  (current-subtype-registry
   (hash-set (current-subtype-registry) (cons sub-key super-key) #t))
  ;; Phase 2a: dual-write to cell
  (macros-cell-write! (current-subtype-registry-cell-id) (hash (cons sub-key super-key) #t)))

;; Track 3 Phase 1: cell-primary reader
(define (read-subtype-registry)
  (or (macros-cell-read-safe (current-subtype-registry-cell-id)) (current-subtype-registry)))

(define (subtype-pair? sub-key super-key)
  (hash-ref (read-subtype-registry) (cons sub-key super-key) #f))

;; Return all registered supertypes of a given sub-key.
(define (all-supertypes sub-key)
  (for/list ([(k _v) (in-hash (read-subtype-registry))]
             #:when (equal? (car k) sub-key))
    (cdr k)))

;; Return all registered subtypes of a given super-key.
(define (all-subtypes super-key)
  (for/list ([(k _v) (in-hash (read-subtype-registry))]
             #:when (equal? (cdr k) super-key))
    (car k)))

;; ========================================
;; Coercion registry (Phase E: refined numeric subtyping)
;; ========================================
;; Maps (cons sub-key super-key) → (expr → expr) coercion function.
;; Used by reduction.rkt to coerce refined type values at runtime.
(define current-coercion-registry (make-parameter (hash)))

(define (register-coercion! sub-key super-key coerce-fn)
  (current-coercion-registry
   (hash-set (current-coercion-registry) (cons sub-key super-key) coerce-fn))
  ;; Phase 2a: dual-write to cell
  (macros-cell-write! (current-coercion-registry-cell-id) (hash (cons sub-key super-key) coerce-fn)))

;; Track 3 Phase 1: cell-primary reader
(define (read-coercion-registry)
  (or (macros-cell-read-safe (current-coercion-registry-cell-id)) (current-coercion-registry)))

(define (lookup-coercion sub-key super-key)
  (hash-ref (read-coercion-registry) (cons sub-key super-key) #f))

;; ========================================
;; Built-in subtype registrations
;; ========================================
;; Register existing built-in subtype pairs so transitive closure can find them
;; when user-defined subtypes chain through (e.g., PosInt <: Int <: Rat).
;; These duplicate the hardcoded match* in typing-core.rkt subtype?,
;; but the registry is needed for transitive closure computation.
(register-subtype-pair! 'Nat 'Int)
(register-subtype-pair! 'Nat 'Rat)
(register-subtype-pair! 'Int 'Rat)
(register-subtype-pair! 'Posit8 'Posit16)
(register-subtype-pair! 'Posit8 'Posit32)
(register-subtype-pair! 'Posit8 'Posit64)
(register-subtype-pair! 'Posit16 'Posit32)
(register-subtype-pair! 'Posit16 'Posit64)
(register-subtype-pair! 'Posit32 'Posit64)

;; ========================================
;; Capability registry (Capabilities as Types)
;; ========================================
;; Stores metadata about each capability type for kind-marker checking,
;; multiplicity defaulting, and capability resolution.

;; capability-meta: name (symbol, FQN), params (list, reserved for dependent caps),
;;                  metadata (hasheq of :doc, etc.)
(struct capability-meta (name params metadata) #:transparent)

;; Registry: capability-name (symbol) → capability-meta
(define current-capability-registry (make-parameter (hasheq)))

(define (register-capability! name meta)
  (current-capability-registry
   (hash-set (current-capability-registry) name meta))
  ;; Phase 2a: dual-write to cell
  (macros-cell-write! (current-capability-registry-cell-id) (hasheq name meta)))

;; Track 3 Phase 1: cell-primary reader
(define (read-capability-registry)
  (or (macros-cell-read-safe (current-capability-registry-cell-id)) (current-capability-registry)))

(define (lookup-capability name)
  (hash-ref (read-capability-registry) name #f))

;; Kind marker check: is this name a registered capability type?
;; Checks both the exact name and short name (for namespace-qualified lookups).
(define (capability-type? name)
  (and (hash-ref (read-capability-registry) name #f) #t))

;; Extract capability functor name from a type expression.
;; Handles both simple fvar (ReadCap) and applied forms (FileCap "/data").
;; Returns the functor name (symbol) if the type is a capability, or #f otherwise.
(define (capability-type-expr? ty)
  (define (expr-head e)
    (cond [(expr-fvar? e) e]
          [(expr-app? e)  (expr-head (expr-app-func e))]
          [else #f]))
  (define head (expr-head ty))
  (and head (expr-fvar? head)
       (capability-type? (expr-fvar-name head))
       (expr-fvar-name head)))

;; ========================================
;; Capability scope for lexical resolution (Phase 4)
;; ========================================
;; Tracks capability-typed bindings currently in scope during elaboration.
;; Each entry is (cons intro-depth type-expr), where intro-depth is the
;; de Bruijn depth at which the capability binding was introduced,
;; and type-expr is the full elaborated type (fvar for simple caps,
;; expr-app chain for dependent caps like (FileCap "/data")).
;; Most-recent bindings are at the front (cons prepends).
(define current-capability-scope (make-parameter '()))

;; Search the capability scope for a binding that satisfies the required capability.
;; Phase 7: scope entries are now (cons depth type-expr), not (cons depth symbol).
;; A binding satisfies the requirement if:
;;   - Its functor name equals the required functor name, OR
;;   - The required functor is a subtype of the binding's functor (attenuation)
;;     e.g., need ReadCap, have FsCap: ReadCap <: FsCap → FsCap subsumes ReadCap
;; Returns the intro-depth of the matching binding, or #f if none found.
(define (find-capability-in-scope required-cap-expr scope)
  (define req-name (capability-type-expr? required-cap-expr))
  (for/or ([entry (in-list scope)])
    (define entry-depth (car entry))
    (define entry-ty (cdr entry))
    (define entry-name (capability-type-expr? entry-ty))
    (cond
      [(and req-name entry-name (eq? req-name entry-name)) entry-depth]
      [(and req-name entry-name (subtype-pair? req-name entry-name)) entry-depth]
      [else #f])))

;; ========================================
;; Trait metadata registry
;; ========================================
;; Stores metadata about each trait for impl validation and dictionary resolution.

;; trait-method: name (symbol), type-datum (s-expression for the method type)
(struct trait-method (name type-datum) #:transparent)

;; trait-meta: name (symbol), params ((name . type) ...), methods (list of trait-method),
;;            metadata (hasheq of :doc, :deprecated, :see-also, etc.)
(struct trait-meta (name params methods metadata) #:transparent)

;; Registry: trait-name (symbol) → trait-meta
(define current-trait-registry (make-parameter (hasheq)))

(define (register-trait! name meta)
  (current-trait-registry (hash-set (current-trait-registry) name meta))
  ;; Phase 2b: dual-write to cell
  (macros-cell-write! (current-trait-registry-cell-id) (hasheq name meta)))

;; Track 3 Phase 2: cell-primary reader for trait registry
(define (read-trait-registry)
  (or (macros-cell-read-safe (current-trait-registry-cell-id)) (current-trait-registry)))

(define (lookup-trait name)
  (hash-ref (read-trait-registry) name #f))

;; ========================================
;; Trait laws store
;; ========================================
;; Stores property laws associated with traits (declared via :laws in trait metadata).
;; Separate from trait-meta to keep the core registry lightweight.
;; Registry: trait-name (symbol) → list of law datums (s-expression property references)

(define current-trait-laws (make-parameter (hasheq)))

(define (register-trait-laws! name laws)
  (current-trait-laws (hash-set (current-trait-laws) name laws))
  ;; Phase 2b: dual-write to cell
  (macros-cell-write! (current-trait-laws-cell-id) (hasheq name laws)))

;; Track 3 Phase 2: cell-primary reader for trait laws
(define (read-trait-laws)
  (or (macros-cell-read-safe (current-trait-laws-cell-id)) (current-trait-laws)))

(define (lookup-trait-laws name)
  (hash-ref (read-trait-laws) name '()))

;; ========================================
;; Impl metadata registry
;; ========================================
;; Stores metadata about each impl for dictionary resolution.

;; impl-entry: trait-name (symbol), type-args (list of type datums), dict-name (symbol)
(struct impl-entry (trait-name type-args dict-name) #:transparent)

;; Registry: key (symbol, e.g. "Nat--Eq") → impl-entry
(define current-impl-registry (make-parameter (hasheq)))

;; HKT-4: Duplicate detection — error if same key with different dict name.
;; Benign re-registration (same key, same dict name) is allowed because the
;; prelude may load the same instance module multiple times.
;; Track 2 Phase 1: read the instance registry from the propagator cell.
;; Falls back to the parameter when no network exists (during module loading,
;; where instances are registered to the parameter before the network is initialized).
(define (read-impl-registry)
  (or (macros-cell-read-safe (current-impl-registry-cell-id)) (current-impl-registry)))

(define (register-impl! key entry)
  ;; Duplicate check uses the parameter — it's the persistent cross-command
  ;; accumulator, always accurate at registration time.
  (define existing (hash-ref (current-impl-registry) key #f))
  (when (and existing
             (not (eq? (impl-entry-dict-name existing) (impl-entry-dict-name entry))))
    (error 'impl
      "Duplicate instance: ~a already registered (dict ~a), cannot re-register (dict ~a)"
      key (impl-entry-dict-name existing) (impl-entry-dict-name entry)))
  ;; Parameter write kept for cross-command accumulation (prelude loading).
  ;; The parameter seeds the cell at network init via register-macros-cells!.
  (current-impl-registry (hash-set (current-impl-registry) key entry))
  ;; Cell write for intra-command visibility (Track 2: sole authority during elaboration).
  (macros-cell-write! (current-impl-registry-cell-id) (hasheq key entry)))

;; lookup-impl uses the parameter — it's called during registration paths
;; (register-impl!, maybe-register-trait-dict-def) where the parameter is the
;; authoritative source. For mid-elaboration reads that need cell-authoritative
;; data, use read-impl-registry instead.
(define (lookup-impl key)
  (hash-ref (current-impl-registry) key #f))

;; ========================================
;; HKT-3: Auto-register trait dict defs in impl registry
;; ========================================
;; When a def has a type annotation matching (TraitName TypeArg1 ...),
;; and TraitName is a registered trait, automatically register the impl entry.
;; This lets manual `def Type--Trait--dict : [Trait Type] body` forms get
;; registered for trait resolution without requiring `impl` syntax.
;;
;; Examples detected:
;;   (def List--Seqable--dict : (Seqable List) body) → register "List--Seqable" → impl-entry
;;   (spec List--Seqable--dict (Seqable List)) → register from spec annotation
;;   (def pvec-foldable : (Foldable PVec) body) → register "PVec--Foldable"
(define (maybe-register-trait-dict-def datum)
  ;; Extract name and type from def: (def name : type body) or (spec name type)
  (define-values (def-name type-datum)
    (cond
      ;; (def name : type body) or (def name : type := body)
      [(and (pair? datum) (memq (car datum) '(def spec))
            (>= (length datum) 3))
       (define name (cadr datum))
       (define rest (cddr datum))
       (cond
         ;; (spec name type) — just name + type
         [(and (eq? (car datum) 'spec) (= (length rest) 1) (list? (car rest)))
          (values name (car rest))]
         ;; (def name : type ...) — look for colon
         [(and (pair? rest) (eq? (car rest) ':) (pair? (cdr rest)) (list? (cadr rest)))
          (values name (cadr rest))]
         [else (values #f #f)])]
      [else (values #f #f)]))
  (when (and def-name type-datum (symbol? def-name)
             (pair? type-datum) (symbol? (car type-datum))
             (>= (length type-datum) 2))
    (define trait-name (car type-datum))
    (define type-args (cdr type-datum))
    (define tm (lookup-trait trait-name))
    (when (and tm
               ;; Check that the number of type args matches trait params
               (= (length type-args) (length (trait-meta-params tm)))
               ;; All type args are symbols (ground types or type constructors)
               (andmap symbol? type-args)
               ;; Not already registered via impl
               (let* ([type-arg-str
                       (string-join (map symbol->string type-args) "-")]
                      [impl-key
                       (string->symbol
                        (string-append type-arg-str "--" (symbol->string trait-name)))])
                 (not (lookup-impl impl-key))))
      ;; Register the impl entry
      (define type-arg-str
        (string-join (map symbol->string type-args) "-"))
      (define impl-key
        (string->symbol
         (string-append type-arg-str "--" (symbol->string trait-name))))
      (register-impl! impl-key (impl-entry trait-name type-args def-name)))))

;; ========================================
;; Parametric impl registry (for impls with `where` constraints)
;; ========================================
;; Parametric impl: impl Eq (List A) where (Eq A) ...
;; dict is a FUNCTION: Pi(A :0 Type) -> Eq A -> Eq (List A)

;; param-impl-entry: stores metadata for parametric impls
(struct param-impl-entry
  (trait-name        ;; symbol — e.g., 'Eq
   type-pattern      ;; (listof datum) — e.g., '((List A))
   pattern-vars      ;; (listof symbol) — e.g., '(A)
   dict-name         ;; symbol — e.g., 'List--Eq--dict
   where-constraints ;; (listof (listof symbol)) — e.g., '((Eq A))
  ) #:transparent)

;; Registry: trait-name (symbol) → (listof param-impl-entry)
;; Keyed by trait name (not impl key) because lookup requires pattern matching.
(define current-param-impl-registry (make-parameter (hasheq)))

;; Track 3 Phase 2: cell-primary reader for parametric impl registry
(define (read-param-impl-registry)
  (or (macros-cell-read-safe (current-param-impl-registry-cell-id)) (current-param-impl-registry)))

;; HKT-4: Overlap detection — warn if a new parametric impl could overlap with existing ones.
(define (register-param-impl! trait-name entry)
  (define existing (hash-ref (read-param-impl-registry) trait-name '()))
  ;; Idempotency guard: skip if an entry with the same dict-name already exists.
  ;; This happens when impl is pre-registered in Pass 1 and re-processed in Pass 2.
  (define dict-name (param-impl-entry-dict-name entry))
  (unless (for/or ([ex (in-list existing)])
            (eq? (param-impl-entry-dict-name ex) dict-name))
    ;; Check for potential overlap with existing entries
    (for ([ex (in-list existing)])
      (when (parametric-impls-could-overlap? entry ex)
        (eprintf "Warning: Potentially overlapping instances for ~a:\n  ~a\n  ~a\n"
                 trait-name
                 (format-param-impl-entry entry)
                 (format-param-impl-entry ex))))
    (define new-list (cons entry existing))
    (current-param-impl-registry
      (hash-set (current-param-impl-registry) trait-name new-list))
    ;; Phase 2b: dual-write to cell
    (macros-cell-write! (current-param-impl-registry-cell-id) (hasheq trait-name new-list))))

;; Check if two parametric impls could overlap.
;; Two impls overlap if their type patterns could unify (i.e., there exists a type
;; that matches both patterns). Conservative: if any position has a variable on at least
;; one side or the patterns are structurally equal, they could unify.
(define (parametric-impls-could-overlap? e1 e2)
  (define vars1 (param-impl-entry-pattern-vars e1))
  (define vars2 (param-impl-entry-pattern-vars e2))
  (define (could-unify? a b)
    (cond
      ;; A pattern variable on either side → could match anything
      [(and (symbol? a) (memq a vars1)) #t]
      [(and (symbol? b) (memq b vars2)) #t]
      ;; Both are lists → must have same length and all elements could unify
      [(and (list? a) (list? b))
       (and (= (length a) (length b))
            (andmap could-unify? a b))]
      ;; Otherwise must be structurally equal
      [else (equal? a b)]))
  (define p1 (param-impl-entry-type-pattern e1))
  (define p2 (param-impl-entry-type-pattern e2))
  (and (= (length p1) (length p2))
       (andmap could-unify? p1 p2)))

;; Format a param-impl-entry for warning messages
(define (format-param-impl-entry entry)
  (format "impl ~a ~a~a"
    (param-impl-entry-trait-name entry)
    (string-join (map (lambda (p) (format "~a" p)) (param-impl-entry-type-pattern entry)) " ")
    (if (null? (param-impl-entry-where-constraints entry))
        ""
        (format " where ~a"
          (string-join
            (map (lambda (wc) (format "(~a)" (string-join (map symbol->string wc) " ")))
                 (param-impl-entry-where-constraints entry))
            " ")))))

(define (lookup-param-impls trait-name)
  (hash-ref (read-param-impl-registry) trait-name '()))

;; ========================================
;; Bundle registry (named constraint conjunctions)
;; ========================================
;; A bundle is a named conjunction of trait constraints, expanded at desugar time.
;; `bundle Comparable := (Eq, Ord)` → `where (Comparable A)` expands to `where (Eq A) (Ord A)`.
;; Zero runtime overhead — purely syntactic sugar.

(struct bundle-entry (name params constraints metadata) #:transparent)
;; name: symbol — e.g., 'Comparable
;; params: (listof symbol) — type var params, e.g., '(A)
;; constraints: (listof (listof symbol)) — e.g., '((Eq A) (Ord A))

(define current-bundle-registry (make-parameter (hasheq)))

(define (register-bundle! name entry)
  (current-bundle-registry (hash-set (current-bundle-registry) name entry))
  ;; Phase 2b: dual-write to cell
  (macros-cell-write! (current-bundle-registry-cell-id) (hasheq name entry)))

;; Track 3 Phase 2: cell-primary reader for bundle registry
(define (read-bundle-registry)
  (or (macros-cell-read-safe (current-bundle-registry-cell-id)) (current-bundle-registry)))

(define (lookup-bundle name)
  (hash-ref (read-bundle-registry) name #f))

;; ========================================
;; HKT-8: Specialization registry
;; ========================================
;; Maps (cons generic-fn-name type-con-name) → specialized-fn-name.
;; E.g., (cons 'gmap 'List) → 'gmap--List--specialized
;; The specialization registry is populated by `process-specialize` and
;; can be queried during a future call-site rewriting optimization pass.
;; Phase HKT-8 implements the registry and macro only; call-site rewriting
;; is deferred to a performance optimization sprint.

(struct specialization-entry (generic-name type-con specialized-name) #:transparent)

;; Uses `hash` (equal?-based) because keys are cons pairs (not symbols)
(define current-specialization-registry (make-parameter (hash)))

(define (register-specialization! generic-name type-con specialized-name)
  (define key (cons generic-name type-con))
  (define entry (specialization-entry generic-name type-con specialized-name))
  (current-specialization-registry
    (hash-set (current-specialization-registry) key entry))
  ;; Phase 2b: dual-write to cell (hash with equal?-based cons keys)
  (macros-cell-write! (current-specialization-registry-cell-id) (hash key entry)))

;; Track 3 Phase 2: cell-primary reader for specialization registry
(define (read-specialization-registry)
  (or (macros-cell-read-safe (current-specialization-registry-cell-id)) (current-specialization-registry)))

(define (lookup-specialization generic-name type-con)
  (hash-ref (read-specialization-registry) (cons generic-name type-con) #f))

;; ========================================
;; process-bundle: parse and register a bundle definition
;; ========================================
;; Syntax (after WS reader):
;;   (bundle Name := (Eq Ord))                   — flat shorthand, 1-param traits
;;   (bundle Name := ((Eq A) (Ord A)))           — bracketed sub-lists (from [Eq A] [Ord A])
;;   (bundle Name (Eq A) (Ord A))                — positional form (no :=)
;;
;; WS reader: commas are whitespace, brackets [...] → parens (...).
;; So `bundle Comparable := (Eq, Ord)` → datum `(bundle Comparable := (Eq Ord))`
;;    `bundle Conv := ([From A B] [Into B A])` → datum `(bundle Conv := ((From A B) (Into B A)))`
(define (process-bundle datum)
  (unless (and (list? datum) (>= (length datum) 3) (eq? (car datum) 'bundle))
    (error 'bundle "bundle requires: (bundle Name body)"))
  (define name (cadr datum))
  (unless (symbol? name)
    (error 'bundle "bundle name must be a symbol, got ~a" name))
  (define rest (cddr datum))
  ;; Skip optional ':=' token
  (define body-tokens
    (if (and (pair? rest) (eq? (car rest) ':=))
        (cdr rest)
        rest))
  (when (null? body-tokens)
    (error 'bundle "bundle ~a: missing body" name))
  ;; Parse the bundle body into constraints
  (define-values (params constraints) (parse-bundle-body name body-tokens))
  (register-bundle! name (bundle-entry name params constraints (hasheq))))

;; parse-bundle-body: extract type params and constraint list from bundle body
;; Returns (values params constraints) where
;;   params: (listof symbol) — inferred type var params
;;   constraints: (listof (listof symbol)) — e.g., '((Eq A) (Ord A))
;;
;; Two body forms after WS reader:
;; 1. Single parenthesized list — the bundle body:
;;    (Eq Ord)         → all bare symbols → flat shorthand, each is 1-param trait
;;    ((Eq A) (Ord A)) → has sub-lists → explicit constraints
;; 2. Multiple top-level parenthesized forms — positional (no :=):
;;    (Eq A) (Ord A)   → each is a constraint
(define (parse-bundle-body name body-tokens)
  (cond
    ;; Case 1: Single parenthesized list — the bundle body
    [(and (= (length body-tokens) 1) (list? (car body-tokens)))
     (define body (car body-tokens))
     (when (null? body)
       (error 'bundle "bundle ~a: empty body" name))
     (cond
       ;; All bare symbols → flat shorthand (1-param traits with implicit param A)
       [(andmap symbol? body)
        (define constraints (map (lambda (s) (list s 'A)) body))
        (values '(A) constraints)]
       ;; Mix or all sub-lists → explicit constraints
       [else
        (define constraints
          (for/list ([item (in-list body)])
            (cond
              [(and (list? item) (>= (length item) 2) (symbol? (car item)))
               item]
              [(symbol? item)
               ;; Bare symbol in a mixed body → 1-param trait with implicit A
               (list item 'A)]
              [else
               (error 'bundle "bundle ~a: invalid constraint ~a" name item)])))
        ;; Infer params: all symbols that appear in constraints but are not known
        ;; type names or trait/bundle names
        (define all-syms (remove-duplicates (append-map cdr constraints)))
        (define params (filter (lambda (s) (not (known-type-name? s))) all-syms))
        (values params constraints)])]
    ;; Case 2: Multiple top-level parenthesized forms (positional)
    [(andmap list? body-tokens)
     (define constraints
       (for/list ([item (in-list body-tokens)])
         (unless (and (>= (length item) 2) (symbol? (car item)))
           (error 'bundle "bundle ~a: invalid constraint ~a" name item))
         item))
     (define all-syms (remove-duplicates (append-map cdr constraints)))
     (define params (filter (lambda (s) (not (known-type-name? s))) all-syms))
     (values params constraints)]
    [else
     (error 'bundle "bundle ~a: invalid body syntax" name)]))

;; Helper: check if a symbol is a known concrete type name (not a type variable)
(define (known-type-name? sym)
  (or (memq sym '(Nat Bool Type Int Rat Unit Nil Symbol Keyword Char String
                  Posit8 Posit16 Posit32 Posit64
                  Quire8 Quire16 Quire32 Quire64
                  List Option Result Either Pair
                  Pi Sigma Eq J
                  Map Set PVec LSeq Vec Fin Datum Ordering
                  ;; Propagator / ATMS / Relational ground types
                  PropNetwork CellId PropId UnionFind
                  ATMS AssumptionId TableStore
                  Solver Goal Derivation))
      (lookup-ctor sym)       ;; user-defined constructor → known
      (lookup-type-ctors sym) ;; user-defined type → known
      (lookup-trait sym)      ;; trait → known (not a variable)
      (lookup-bundle sym)     ;; bundle → known (not a variable)
      (lookup-schema sym)     ;; schema → known type (not a variable)
      (lookup-selection sym)))  ;; selection → known type (not a variable)

;; Phase 1b: Check if a symbol starts with an uppercase letter (type variable candidate)
(define (capitalized-symbol? sym)
  (let ([s (symbol->string sym)])
    (and (> (string-length s) 0)
         (char-upper-case? (string-ref s 0)))))

;; Phase 1b: Collect free type variable candidates from datum tokens.
;; Collect locally-bound Pi binder names from within $angle-type forms.
;; These are names like S in <(S :0 Type) -> ...> that are quantified inside
;; a higher-rank Pi type and should NOT become auto-implicit type parameters.
(define (collect-local-pi-binder-names datums)
  (define result '())
  (define (walk d)
    (cond
      [(and (pair? d) (or (eq? (car d) '$angle-type)
                          (and (syntax? (car d))
                               (eq? (syntax-e (car d)) '$angle-type))))
       ;; Inside an angle-type: look for (name :0 type...) Pi binder patterns
       (extract-pi-binder-names (cdr d))]
      [(pair? d)
       (walk (car d))
       (walk (cdr d))]
      [(syntax? d) (walk (syntax-e d))]
      [else (void)]))
  (define (extract-pi-binder-names tokens)
    (for ([tok (in-list (if (list? tokens) tokens '()))])
      (cond
        ;; (name :0 type...) or (name : type...) — Pi binder within angle-type
        [(and (list? tok) (>= (length tok) 3)
              (symbol? (car tok))
              (memq (cadr tok) '(: :0 :1 :w)))
         (set! result (cons (car tok) result))]
        [(pair? tok) (walk tok)]
        [else (void)])))
  (for-each walk datums)
  result)

;; Walks the token tree and collects symbols that start with an uppercase letter,
;; excluding special syntax sentinels. Returns a deduplicated list in first-occurrence order.
(define (collect-free-type-vars-from-datums datums)
  (define seen (make-hasheq))
  (define result '())
  (define (walk d)
    (cond
      [(symbol? d)
       (when (and (capitalized-symbol? d)
                  (not (hash-has-key? seen d)))
         (hash-set! seen d #t)
         (set! result (cons d result)))]
      [(pair? d)
       (walk (car d))
       (walk (cdr d))]
      [(syntax? d) (walk (syntax-e d))]
      [else (void)]))
  (for-each walk datums)
  (reverse result))

;; ========================================
;; expand-bundle-constraints: recursive expansion with cycle detection
;; ========================================
;; Given a list of constraints (which may reference bundles), expand all bundle
;; references to their constituent trait constraints. Returns a flat, deduplicated
;; list of trait constraints.
;;
;; Example:
;;   (expand-bundle-constraints '((Comparable A)))
;;   where Comparable = (Eq Ord)
;;   → '((Eq A) (Ord A))
(define (expand-bundle-constraints raw-constraints [seen '()])
  (define expanded
    (append-map (lambda (c) (expand-one-constraint c seen)) raw-constraints))
  (dedup-constraints expanded))

;; Expand a single constraint: if it's a bundle reference, substitute and recurse.
;; If it's a trait, return as-is (leaf).
(define (expand-one-constraint constraint seen)
  (define head (car constraint))
  (define args (cdr constraint))
  (cond
    ;; Known trait → leaf case, return as-is
    [(lookup-trait head) (list constraint)]
    ;; Known bundle → expand
    [(lookup-bundle head)
     => (lambda (bentry)
          ;; Cycle detection
          (when (memq head seen)
            (error 'bundle "circular bundle reference: ~a (path: ~a)"
                   head (reverse (cons head seen))))
          ;; Arity check
          (define expected-params (bundle-entry-params bentry))
          (unless (= (length args) (length expected-params))
            (error 'bundle "bundle ~a expects ~a type params (~a), got ~a (~a)"
                   head (length expected-params) expected-params
                   (length args) args))
          ;; Build substitution map: param → arg
          (define subst-map
            (for/hasheq ([p (in-list expected-params)]
                         [a (in-list args)])
              (values p a)))
          ;; Substitute and recursively expand
          (define substituted
            (for/list ([c (in-list (bundle-entry-constraints bentry))])
              (subst-constraint c subst-map)))
          (expand-bundle-constraints substituted (cons head seen)))]
    [else
     ;; Unknown head — pass through as-is. It may be a trait that isn't registered yet
     ;; (e.g., defined in another module or later in the file). Validation happens
     ;; downstream when the constraint is actually used (e.g., in maybe-inject-where).
     (list constraint)]))

;; Apply symbol→symbol substitution to a constraint list.
(define (subst-constraint constraint subst-map)
  (for/list ([sym (in-list constraint)])
    (hash-ref subst-map sym sym)))

;; Remove duplicate constraints, preserving first-appearance order.
(define (dedup-constraints constraints)
  (let loop ([remaining constraints] [seen '()] [acc '()])
    (cond
      [(null? remaining) (reverse acc)]
      [(member (car remaining) seen)
       (loop (cdr remaining) seen acc)]
      [else
       (loop (cdr remaining) (cons (car remaining) seen)
             (cons (car remaining) acc))])))

;; ========================================
;; process-data: algebraic data types with native constructors
;; ========================================
;; Syntax:
;;   (data TypeName ctor1 (Ctor2 field2 ...) ...)                     — no params
;;   (data (TypeName (A : T1) ...) ctor1 (Ctor2 field2 ...) ...)     — with params
;;
;; WS syntax (after reader):
;;   (data TypeName ctor1 (Ctor2 ($angle-type f1) ...) ...)           — no params
;;   (data (TypeName A ($angle-type T1) ...) ctor1 (Ctor2 ...))      — with params
;;
;; Constructors can be bare symbols (nullary) or (Name fields...).
;;
;; Generates opaque definitions (bodies are placeholders, never evaluated):
;;   - Type definition: TypeName with type annotation (Type 0)
;;   - Constructor definitions: each with type annotation only
;;   - Constructor metadata: registered for structural pattern matching
;;
;; Returns: list of s-expression datums (def type-name ...) (def ctor1 ...) ...

;; Parse data parameter list from WS or sexp syntax
;; WS: (TypeName A ($angle-type (Type 0)) B ($angle-type (Type 0)) ...)
;; Sexp: (TypeName (A : (Type 0)) (B : (Type 0)) ...)
;; Returns: (values type-name params) where params is ((name . type) ...)
(define (parse-data-params head-datum)
  (cond
    ;; Bare symbol: no params
    [(symbol? head-datum)
     (values head-datum '())]
    ;; List: (TypeName params...)
    [(pair? head-datum)
     (define type-name (car head-datum))
     (unless (symbol? type-name)
       (error 'data "data: type name must be a symbol, got ~a" type-name))
     (define raw-params (cdr head-datum))
     ;; Parse params — try WS format first, then sexp format
     (define params (parse-data-param-list raw-params))
     (values type-name params)]
    [else
     (error 'data "data: expected type name or (type-name params...), got ~a" head-datum)]))

;; ========================================
;; parse-brace-param-list: parse {A B} or {F : Type -> Type} brace params
;; ========================================
;; Input: list of symbols/tokens after $brace-params sentinel
;;   e.g., (A B)                    for {A B}
;;   e.g., (F : Type -> Type)       for {F : Type -> Type}
;;   e.g., (F : Type -> Type A)     for {F : Type -> Type, A}
;;   e.g., (A B : Type -> Type -> Type) for {A, B : Type -> Type -> Type}
;; Output: alist of ((name . kind) ...) where kind is a type datum
;;   e.g., ((A . (Type 0)) (B . (Type 0)))
;;   e.g., ((F . (-> (Type 0) (Type 0))))
;;
;; Algorithm: find all "symbol :" boundaries to identify param groups.
;; Each "symbol :" starts a kinded param whose kind extends until the next
;; "symbol :" boundary or end of tokens. Any symbols before the first kinded
;; param (or if no colons exist) are bare params with default kind (Type 0).

(define (parse-brace-param-list symbols context-name)
  (define groups (group-brace-params symbols))
  (for/list ([g (in-list groups)])
    (cond
      ;; Kinded: (name : kind-tokens...)
      [(and (>= (length g) 3) (eq? (cadr g) ':))
       (define name (car g))
       (unless (symbol? name)
         (error context-name "~a: parameter name must be a symbol, got ~a" context-name name))
       (define kind-tokens (cddr g))
       ;; Normalize bare 'Type' to '(Type 0)' in kind tokens
       (define normalized-tokens
         (map (lambda (t) (if (eq? t 'Type) '(Type 0) t)) kind-tokens))
       ;; Parse using arrow splitting (reuse existing utilities)
       (define segments (split-on-arrow-datum normalized-tokens))
       (define kind
         (if (= (length segments) 1)
             ;; No arrows — bare kind
             (let ([seg (car segments)])
               (if (= (length seg) 1) (car seg) seg))
             ;; Has arrows — build nested arrow type
             (let* ([domains (drop-right segments 1)]
                    [codomain-seg (last segments)]
                    [codomain (if (= (length codomain-seg) 1)
                                  (car codomain-seg)
                                  codomain-seg)]
                    [domain-types (map (lambda (seg)
                                         (if (= (length seg) 1) (car seg) seg))
                                       domains)])
               (build-arrow-type domain-types codomain))))
       (cons name kind)]
      ;; Bare: (name)
      [(and (= (length g) 1) (symbol? (car g)))
       (cons (car g) '(Type 0))]
      [else
       (error context-name "~a: malformed brace parameter: ~a" context-name g)])))

;; Group a flat list of brace-param tokens into parameter groups.
;; Strategy: find positions of ':' preceded by a symbol. These are kinded param
;; boundaries. Split the token list so each kinded param gets its name + : + kind,
;; and each bare symbol becomes its own group.
(define (group-brace-params tokens)
  (if (null? tokens)
      '()
      (let ()
        (define tvec (list->vector tokens))
        (define n (vector-length tvec))
        ;; Find indices of ':' preceded by a symbol — these are "name :" boundaries
        ;; The param name is at index (colon-idx - 1)
        (define param-start-indices
          (for/list ([i (in-range 1 n)]
                     #:when (and (eq? (vector-ref tvec i) ':)
                                 (symbol? (vector-ref tvec (- i 1)))))
            (- i 1)))  ;; position of the name symbol
        (cond
          ;; No colons — all bare symbols
          [(null? param-start-indices)
           (for/list ([t (in-list tokens)])
             (list t))]
          [else
           ;; Build groups by splitting at param-start boundaries
           ;; Tokens before the first kinded param are bare params
           ;; Tokens between kinded param starts belong to the preceding kind
           (define result '())
           ;; Process bare params before the first kinded param
           (define first-start (car param-start-indices))
           (for ([i (in-range 0 first-start)])
             (set! result (cons (list (vector-ref tvec i)) result)))
           ;; Process each kinded param
           (for ([start-idx (in-list param-start-indices)]
                 [next-idx (in-list (append (cdr param-start-indices) (list n)))])
             (define group
               (for/list ([k (in-range start-idx next-idx)])
                 (vector-ref tvec k)))
             (set! result (cons group result)))
           (reverse result)]))))

;; Parse parameter list in WS or sexp format
;; ($brace-params ...) — implicit type params, optionally with kind annotations
;; WS: (A ($angle-type (Type 0)) B ($angle-type (Type 0)) ...)
;; Sexp: ((A : (Type 0)) (B : (Type 0)) ...)
(define (parse-data-param-list raw)
  (cond
    [(null? raw) '()]
    ;; ($brace-params ...) — implicit type params with optional kind annotations
    [(and (= (length raw) 1)
          (pair? (car raw))
          (list? (car raw))
          (>= (length (car raw)) 2)
          (eq? (car (car raw)) '$brace-params))
     (define symbols (cdr (car raw)))
     (parse-brace-param-list symbols 'data)]
    ;; WS format: name ($angle-type Type) name ($angle-type Type) ...
    [(and (symbol? (car raw))
          (>= (length raw) 2)
          (let ([second (cadr raw)])
            (and (pair? second) (eq? (car second) '$angle-type))))
     (define name (car raw))
     (define type (cadr (cadr raw)))  ;; extract from ($angle-type T)
     (cons (cons name type)
           (parse-data-param-list (cddr raw)))]
    ;; WS format with multiplicity: name :0 ($angle-type Type) ...
    [(and (symbol? (car raw))
          (>= (length raw) 3)
          (memq (cadr raw) '(:0 :1 :w))
          (let ([third (caddr raw)])
            (and (pair? third) (eq? (car third) '$angle-type))))
     (define name (car raw))
     ;; multiplicity ignored for params (always :0 for type params)
     (define type (cadr (caddr raw)))
     (cons (cons name type)
           (parse-data-param-list (cdddr raw)))]
    ;; Sexp format: (A : (Type 0)) ...
    [(and (pair? (car raw))
          (list? (car raw))
          (>= (length (car raw)) 3)
          (eq? (cadr (car raw)) ':))
     (define binding (car raw))
     (define name (car binding))
     (define type (caddr binding))
     (cons (cons name type)
           (parse-data-param-list (cdr raw)))]
    ;; WS bracket format: (A ($angle-type (Type 0))) as a sub-list
    ;; This happens when [A <(Type 0)>] is used inside parens
    [(and (pair? (car raw))
          (list? (car raw))
          (>= (length (car raw)) 2)
          (symbol? (car (car raw)))
          (let ([second (cadr (car raw))])
            (and (pair? second) (eq? (car second) '$angle-type))))
     (define binding (car raw))
     (define name (car binding))
     (define type (cadr (cadr binding)))
     (cons (cons name type)
           (parse-data-param-list (cdr raw)))]
    ;; WS bracket format with multiplicity: (A :0 ($angle-type (Type 0))) as sub-list
    [(and (pair? (car raw))
          (list? (car raw))
          (>= (length (car raw)) 3)
          (symbol? (car (car raw)))
          (memq (cadr (car raw)) '(:0 :1 :w))
          (let ([third (caddr (car raw))])
            (and (pair? third) (eq? (car third) '$angle-type))))
     (define binding (car raw))
     (define name (car binding))
     (define type (cadr (caddr binding)))
     (cons (cons name type)
           (parse-data-param-list (cdr raw)))]
    [else
     (error 'data "data: unexpected parameter format: ~a" raw)]))

;; Parse a constructor declaration
;; NEW: (CtorName : T1 -> T2 -> ... -> ResultType) — colon-based (field types only)
;; WS: bare symbol (nullary), (CtorName ($angle-type T1) ...) (with fields)
;; Sexp: (CtorName field1 field2 ...) or (CtorName) for nullary
;; Returns: (cons name (list field-types...))
(define (parse-data-ctor raw)
  (cond
    ;; Bare symbol: nullary constructor (e.g., none, lt-ord)
    [(symbol? raw)
     (cons raw '())]
    ;; List: (CtorName fields...)
    [(and (pair? raw) (symbol? (car raw)))
     (define name (car raw))
     (define rest (cdr raw))
     (cond
       ;; NEW: colon-based syntax: (CtorName : T1 -> T2 -> ...)
       ;; The return type (last segment) is implicit (always the data type itself)
       ;; so we treat all-but-last segments as field types
       [(and (not (null? rest))
             (eq? (car rest) ':))
        (define type-atoms (cdr rest)) ;; everything after ':'
        (when (null? type-atoms)
          (error 'data "data constructor ~a: missing type after ':'" name))
        ;; Split on -> to get segments
        ;; ALL segments are field types (return type is implicit — always the data type)
        (define segments (split-on-arrow-datum type-atoms))
        (define fields
          (map (lambda (seg)
                 (define field-type
                   (if (= (length seg) 1)
                       (car seg)  ;; single atom: e.g., A
                       seg))      ;; multi-atom: e.g., (List A)
                 ;; Normalize any infix -> inside grouped types
                 ;; e.g., (Unit -> LSeq A) → (-> Unit (LSeq A))
                 (normalize-infix-arrow-type field-type))
               segments))
        (cons name fields)]
       ;; EXISTING: angle-bracket or bare fields
       [else
        (define fields
          (map (lambda (f)
                 (if (and (pair? f) (eq? (car f) '$angle-type))
                     (cadr f)   ;; WS: ($angle-type T) → T
                     f))        ;; Sexp: bare T
               rest))
        (cons name fields)])]
    [else
     (error 'data "data: constructor must be (Name fields...) or a bare symbol, got ~a" raw)]))

;; Normalize a type datum that may contain infix ->
;; Converts (Unit -> LSeq A) → (-> Unit (LSeq A))
;; Leaves (List A) and bare symbols unchanged.
;; Recursively normalizes nested grouped types.
(define (normalize-infix-arrow-type ty)
  (cond
    ;; Not a list — bare atom, leave as-is
    [(not (list? ty)) ty]
    ;; Empty list — leave as-is
    [(null? ty) ty]
    ;; Already prefix -> — normalize children
    [(eq? (car ty) '->)
     (cons '-> (map normalize-infix-arrow-type (cdr ty)))]
    ;; Contains infix -> (e.g., (Unit -> LSeq A))
    ;; Convert to prefix form
    [(memq '-> ty)
     (define segments (split-on-arrow-datum ty))
     (if (= (length segments) 1)
         ;; No actual -> found (shouldn't happen since memq found one)
         (map normalize-infix-arrow-type ty)
         ;; Build prefix arrow from segments
         (let* ([normalized-segs
                 (map (lambda (seg)
                        (define normalized (map normalize-infix-arrow-type seg))
                        (if (= (length normalized) 1)
                            (car normalized)
                            normalized))
                      segments)]
                [domains (drop-right normalized-segs 1)]
                [codomain (last normalized-segs)])
           (build-arrow-type domains codomain)))]
    ;; No infix -> — normalize children
    [else
     (map normalize-infix-arrow-type ty)]))

;; Split a flat list of atoms on the '-> symbol (datum-level, not syntax).
;; Returns a list of lists (segments between arrows).
(define (split-on-arrow-datum atoms)
  (let loop ([remaining atoms] [current '()] [result '()])
    (cond
      [(null? remaining)
       (reverse (cons (reverse current) result))]
      [(eq? (car remaining) '->)
       (loop (cdr remaining) '() (cons (reverse current) result))]
      [else
       (loop (cdr remaining) (cons (car remaining) current) result)])))

;; Like split-on-arrow-datum but recognizes ALL arrow variants (->, -0>, -1>, -w>)
;; and returns multiplicity information alongside segments.
;; Returns (values segments arrow-mults)
;;   segments: list of token-lists (param types + return type)
;;   arrow-mults: list of mult symbols (#f, 'm0, 'm1, 'mw), one per arrow
;;   (length arrow-mults) = (- (length segments) 1)
;; Example: (Handle -1> String -> Unit)
;;   → segments: ((Handle) (String) (Unit))
;;   → arrow-mults: (m1 #f)
(define (arrow-symbol-datum? s) (memq s '(-> -0> -1> -w>)))
(define (arrow-mult-datum sym)
  (case sym [(-0>) 'm0] [(-1>) 'm1] [(-w>) 'mw] [(->)  #f] [else #f]))

;; Convert internal mult symbol to annotation symbol for typed brackets.
;; Returns :0, :1, or #f (omit annotation for :w/unrestricted and #f/default).
(define (mult->annot-symbol m)
  (case m [(m0) ':0] [(m1) ':1] [else #f]))

(define (split-on-arrow-datum/mult atoms)
  (let loop ([remaining atoms] [current '()] [segments '()] [mults '()])
    (cond
      [(null? remaining)
       (values (reverse (cons (reverse current) segments))
               (reverse mults))]
      [(arrow-symbol-datum? (car remaining))
       (loop (cdr remaining) '()
             (cons (reverse current) segments)
             (cons (arrow-mult-datum (car remaining)) mults))]
      [else
       (loop (cdr remaining) (cons (car remaining) current) segments mults)])))

;; Build a nested -> type from a list of domains and a codomain
;; (build-arrow-type '(A B C) 'R) → (-> A (-> B (-> C R)))
(define (build-arrow-type domains codomain)
  (foldr (lambda (dom rest) `(-> ,dom ,rest)) codomain domains))

;; Build nested (fn ...) from bindings: ((name mult type) ...) and a body
;; Each binding is (name multiplicity type-expr)
(define (build-nested-fn bindings body)
  (foldr (lambda (bnd rest)
           (define name (car bnd))
           (define mult (cadr bnd))
           (define type (caddr bnd))
           `(fn (,name ,mult ,type) ,rest))
         body bindings))

;; Build nested (Pi ...) from bindings
(define (build-nested-pi bindings body)
  (foldr (lambda (bnd rest)
           (define name (car bnd))
           (define mult (cadr bnd))
           (define type (caddr bnd))
           `(Pi (,name ,mult ,type) ,rest))
         body bindings))

;; Check if a field type is a self-reference to the type being defined
;; Matches bare TypeName (no params) or (TypeName A B ...) with exact param names
(define (self-reference? field-type type-name params)
  (cond
    ;; Bare name with no params: e.g., MyType when defining (data MyType ...)
    [(and (symbol? field-type) (eq? field-type type-name) (null? params)) #t]
    ;; Applied name: e.g., (List A) when defining (data (List (A : (Type 0))) ...)
    [(and (pair? field-type)
          (eq? (car field-type) type-name)
          (= (length (cdr field-type)) (length params))
          (andmap (lambda (arg param)
                    (and (symbol? arg) (eq? arg (car param))))
                  (cdr field-type) params))
     #t]
    [else #f]))

;; Main data processing function
;; Returns a list of s-expression datums: ((def ...) (def ...) ...)
(define (process-data datum)
  (unless (and (list? datum) (>= (length datum) 2))
    (error 'data "data requires: (data TypeName-or-(TypeName params...) ctor1 ctor2 ...)"))

  ;; NEW: detect (data TypeName {A B} ctor1 ctor2 ...) — brace-params after bare type name
  ;; In WS mode: (data Maybe ($brace-params A) nothing ...)
  ;; In sexp mode: (data Maybe ($brace-params A) (nothing) (just A))
  (define-values (type-name params raw-ctors)
    (let ([head (cadr datum)]
          [rest (cddr datum)])
      (cond
        ;; NEW: bare symbol followed by ($brace-params ...)
        [(and (symbol? head)
              (not (null? rest))
              (let ([maybe-braces (car rest)])
                (and (pair? maybe-braces)
                     (eq? (car maybe-braces) '$brace-params))))
         (define brace-element (car rest))
         (define symbols (cdr brace-element))
         (define brace-params (parse-brace-param-list symbols 'data))
         (values head brace-params (cdr rest))]
        ;; EXISTING: parse head normally
        [else
         (define-values (tn ps) (parse-data-params head))
         (values tn ps rest)])))

  ;; Zero-constructor types are allowed (uninhabited types like Never/Void)
  (define ctors (map parse-data-ctor raw-ctors))
  ;; ctors = ((name . (field-types ...)) ...)

  ;; ---- Generate the type definition ----

  ;; Type params as Pi bindings (all :0)
  (define param-pi-bindings
    (for/list ([p (in-list params)])
      (list (car p) ':0 (cdr p))))

  ;; Type type: param-types -> (Type 0)
  ;; User-defined types are opaque (non-unfolding fvars) and live at Type 0,
  ;; matching built-in types (Nat, Bool). The body is a placeholder —
  ;; driver.rkt stores these with value=#f (never evaluated at runtime).
  (define type-type
    (if (null? params)
        '(Type 0)
        (build-nested-pi
         param-pi-bindings
         '(Type 0))))

  ;; Body placeholder — never elaborated or evaluated (driver.rkt skips
  ;; body processing for data type definitions and stores value=#f).
  (define type-body '(Type 0))

  ;; The type def
  (define type-def
    `(def ,type-name : ,type-type ,type-body))

  ;; ---- Generate constructor definitions ----
  ;; Type: Pi(A :0 T_A) ... -> T1 -> T2 -> ... -> (TypeName A B ...)
  ;; Body: placeholder (never evaluated — constructors are opaque fvars)

  ;; Applied type: (TypeName A B ...) or just TypeName if no params
  (define applied-type-name
    (if (null? params)
        type-name
        `(,type-name ,@(map car params))))

  (define ctor-defs
    (for/list ([ctor (in-list ctors)]
               [i (in-naturals)])
      (define ctor-name (car ctor))
      (define field-types (cdr ctor))

      ;; Constructor type:
      ;; Pi(A :0 T_A) ... -> T1 -> T2 -> ... -> (TypeName A B ...)
      (define ctor-result-type applied-type-name)
      (define ctor-type
        (build-nested-pi
         param-pi-bindings
         (build-arrow-type field-types ctor-result-type)))

      ;; Body placeholder — never elaborated or evaluated
      (define full-body '(Type 0))

      `(def ,ctor-name : ,ctor-type ,full-body)))

  ;; Register constructor metadata for reduce
  (define ctor-names (map car ctors))
  (current-type-meta
   (hash-set (current-type-meta) type-name ctor-names))
  ;; Phase 2a: dual-write to cell
  (macros-cell-write! (current-type-meta-cell-id) (hasheq type-name ctor-names))

  (for ([ctor (in-list ctors)]
        [i (in-naturals)])
    (define ctor-name (car ctor))
    (define field-types (cdr ctor))
    (define rec-flags
      (map (lambda (ft) (self-reference? ft type-name params)) field-types))
    (register-ctor! ctor-name
                    (ctor-meta type-name params field-types rec-flags i)))

  ;; Return all definitions
  (cons type-def ctor-defs))

;; ========================================
;; process-trait: trait declarations
;; ========================================
;; Syntax (WS, after reader):
;;   (trait TraitName ($brace-params A) (method1 : T1 -> T2) (method2 : T3))
;;
;; Syntax (sexp):
;;   (trait (TraitName (A : (Type 0))) (method1 : T1 -> T2) (method2 : T3))
;;
;; Generates:
;;   - deftype for the dictionary type
;;     Single-method: (deftype (TraitName A) <method-type>)
;;     Multi-method: (deftype (TraitName A) (Sigma (_ <method1-type>) method2-type...))
;;   - Accessor defs for each method
;;     Single-method: (def trait-method1 : Pi(A :0 Type) -> (TraitName A) -> method1-type
;;                       (fn (dict) dict))
;;     Multi-method: first/second projections
;;   - Trait metadata registered for impl validation
;;
;; Returns: list of s-expression datums

;; Parse a trait method declaration.
;; Input: (method-name : type-atoms...) or (method-name ($angle-type ...) ...)
;; Returns: trait-method struct
(define (parse-trait-method raw trait-name)
  (unless (and (pair? raw) (symbol? (car raw)))
    (error 'trait "trait ~a: method must be (name : type ...), got ~a" trait-name raw))
  (define name (car raw))
  (define rest (cdr raw))
  (cond
    ;; Colon-based: (method : T1 -> T2 -> Result)
    [(and (not (null? rest)) (eq? (car rest) ':))
     (define type-atoms (cdr rest))
     (when (null? type-atoms)
       (error 'trait "trait ~a: method ~a: missing type after ':'" trait-name name))
     ;; Build the method's function type from atoms
     ;; Unlike data ctor, we keep the FULL type (including return type)
     (define segments (split-on-arrow-datum type-atoms))
     (define method-type
       (if (= (length segments) 1)
           ;; Single segment, no arrows — bare type
           (let ([seg (car segments)])
             (if (= (length seg) 1) (car seg) seg))
           ;; Multiple segments — build arrow type
           (let ([domains (drop-right segments 1)]
                 [codomain-seg (last segments)])
             (define codomain
               (if (= (length codomain-seg) 1) (car codomain-seg) codomain-seg))
             ;; Flatten: each atom in each segment is a separate param type.
             ;; Bracket-grouped types like [Option A] arrive as single list
             ;; elements, so they stay grouped.  Matches decompose-spec-type.
             (define domain-types
               (append-map (lambda (seg) seg) domains))
             (build-arrow-type domain-types codomain))))
     (trait-method name method-type)]
    ;; Angle-bracket (WS reader): (method ($angle-type T1) ...)
    [(and (not (null? rest))
          (pair? (car rest))
          (eq? (car (car rest)) '$angle-type))
     ;; Extract the type from the angle bracket
     (define type-datum (cadr (car rest)))
     (trait-method name type-datum)]
    [else
     (error 'trait "trait ~a: method ~a must have type annotation (name : type)" trait-name name)]))

;; Build a nested Sigma type from a list of types.
;; (build-sigma-type '(T1 T2 T3)) → (Sigma (_ : T1) (Sigma (_ : T2) T3))
;; Uses (_ : T) binder syntax for proper sexp parsing.
(define (build-sigma-type types)
  (cond
    [(= (length types) 1) (car types)]
    [(= (length types) 2)
     `(Sigma (_ : ,(car types)) ,(cadr types))]
    [else
     `(Sigma (_ : ,(car types)) ,(build-sigma-type (cdr types)))]))

;; Build accessor expression for the i-th element of a nested Sigma.
;; n = total number of methods
;; i = 0-based index
;; dict-expr = the expression to project from
(define (build-sigma-accessor n i dict-expr)
  (cond
    ;; Last element: apply (n-1) `snd` projections
    [(= i (- n 1))
     (for/fold ([expr dict-expr])
               ([_ (in-range (- n 1))])
       `(snd ,expr))]
    ;; Not last: apply i `snd` projections, then `fst`
    [else
     (define inner
       (for/fold ([expr dict-expr])
                 ([_ (in-range i)])
         `(snd ,expr)))
     `(fst ,inner)]))

(define (process-trait datum)
  (unless (and (list? datum) (>= (length datum) 3))
    (error 'trait "trait requires: (trait TraitName {params} method1 method2 ...)"))

  ;; Parse trait name and params (same patterns as data)
  (define-values (trait-name params raw-methods)
    (let ([head (cadr datum)]
          [rest (cddr datum)])
      (cond
        ;; Brace-params: (trait Eq ($brace-params A) ...)
        [(and (symbol? head)
              (not (null? rest))
              (let ([maybe-braces (car rest)])
                (and (pair? maybe-braces)
                     (eq? (car maybe-braces) '$brace-params))))
         (define brace-element (car rest))
         (define symbols (cdr brace-element))
         (define brace-params (parse-brace-param-list symbols 'trait))
         (values head brace-params (cdr rest))]
        ;; Sexp params: (trait (Eq (A : (Type 0))) ...)
        [else
         (define-values (tn ps) (parse-data-params head))
         (values tn ps rest)])))

  ;; Separate trailing metadata block from method specs
  ;; A trailing ($brace-params :key ...) is trait metadata, not a method
  (define-values (method-specs-0 trait-metadata-0)
    (if (and (not (null? raw-methods))
             (let ([last-elem (last raw-methods)])
               (and (pair? last-elem)
                    (let ([h (car last-elem)])
                      (cond
                        [(symbol? h) (eq? h '$brace-params)]
                        [(syntax? h) (eq? (syntax-e h) '$brace-params)]
                        [else #f]))
                    (pair? (cdr last-elem))
                    (keyword-like-symbol? (cadr last-elem)))))
        (values (drop-right raw-methods 1) (parse-spec-metadata (last raw-methods)))
        (values raw-methods (hasheq))))

  ;; Also handle inline keyword-headed children from WS mode
  ;; e.g. (:doc "...") and (:laws ...) as direct children of the trait body
  (define-values (method-specs trait-metadata)
    (let loop ([remaining method-specs-0]
               [methods '()]
               [meta trait-metadata-0])
      (cond
        [(null? remaining) (values (reverse methods) meta)]
        [(and (pair? (car remaining)) (keyword-like-symbol? (caar remaining)))
         ;; This is a keyword-headed entry like (:doc "...") or (:laws ...)
         (define entry (car remaining))
         (define key (car entry))
         (define val (cdr entry))
         (define merged-val
           (cond
             ;; (:doc "string") → just the string
             [(and (= (length val) 1) (string? (car val))) (car val)]
             ;; (:laws (- ...) (- ...) ...) → list of law entries
             [(and (pair? val) (pair? (car val))) val]
             ;; Single value
             [(= (length val) 1) (car val)]
             ;; Multiple values → keep as list
             [else val]))
         (loop (cdr remaining) methods (hash-set meta key merged-val))]
        [else
         (loop (cdr remaining) (cons (car remaining) methods) meta)])))

  (when (null? method-specs)
    (error 'trait "trait ~a: must have at least one method" trait-name))

  ;; Extract :laws from metadata and register
  (define raw-laws (hash-ref trait-metadata ':laws #f))
  (when (and raw-laws (pair? raw-laws))
    (register-trait-laws! trait-name raw-laws))

  ;; Parse methods
  (define methods
    (map (lambda (m) (parse-trait-method m trait-name)) method-specs))

  ;; Register trait metadata (G5: include metadata hash for :doc, :deprecated, :see-also, etc.)
  (register-trait! trait-name (trait-meta trait-name params methods trait-metadata))

  ;; ---- Generate the dictionary type ----
  ;; Type params as Pi bindings (all :0)
  (define param-pi-bindings
    (for/list ([p (in-list params)])
      (list (car p) ':0 (cdr p))))

  ;; For parameterized deftype, we need $-prefixed param names
  ;; so process-deftype's pattern-template macro expansion works.
  ;; Map: A → $A in both the deftype pattern and body.
  (define param-name->pvar
    (for/hasheq ([p (in-list params)])
      (values (car p)
              (string->symbol (string-append "$" (symbol->string (car p)))))))

  ;; Substitute param names with $-prefixed versions in a type datum
  (define (pvarify datum)
    (cond
      [(symbol? datum)
       (hash-ref param-name->pvar datum datum)]
      [(pair? datum)
       (map pvarify datum)]
      [else datum]))

  (define method-types (map trait-method-type-datum methods))

  ;; Pvarified method types for the deftype body
  (define pvar-method-types (map pvarify method-types))

  ;; Dictionary type body: single method → bare type, multi → nested Sigma
  (define dict-body
    (if (= (length methods) 1)
        (car pvar-method-types)
        (build-sigma-type pvar-method-types)))

  ;; deftype pattern: (TraitName $A $B ...) or bare TraitName
  (define deftype-pattern
    (if (null? params)
        trait-name
        `(,trait-name ,@(map (lambda (p) (hash-ref param-name->pvar (car p))) params))))

  ;; deftype datum with $-prefixed params for pattern-template expansion
  (define deftype-datum `(deftype ,deftype-pattern ,dict-body))

  ;; Process deftype to register it as a pre-parse macro
  (process-deftype deftype-datum)

  ;; Register trait as type constructor with correct arity for kind inference
  (current-tycon-arity-extension
    (hash-set (current-tycon-arity-extension)
              trait-name
              (length params)))

  ;; ---- Generate accessor definitions ----
  ;; Each accessor takes type params + a dict, and projects the right field.
  ;; Single method: accessor is identity (dict IS the function)
  ;; Multi method: accessor projects from nested Sigma

  (define n-methods (length methods))

  ;; Applied trait type: (TraitName A B ...) or bare TraitName
  (define applied-trait-type
    (if (null? params)
        trait-name
        `(,trait-name ,@(map car params))))

  (define accessor-defs
    (for/list ([method (in-list methods)]
               [i (in-naturals)])
      (define method-name (trait-method-name method))
      (define method-type (trait-method-type-datum method))
      ;; Accessor name: TraitName-methodname
      (define accessor-name
        (string->symbol
         (string-append (symbol->string trait-name)
                        "-"
                        (symbol->string method-name))))

      ;; Accessor type: Pi(A :0 Type 0) ... -> TraitName A -> method-type
      (define accessor-type
        (build-nested-pi
         param-pi-bindings
         (build-arrow-type (list applied-trait-type) method-type)))

      ;; Accessor body: fn that projects from dict
      ;; For single-method: (fn (dict <TraitType>) dict)
      ;; For multi-method: (fn (dict <TraitType>) (fst/snd... dict))
      (define dict-var 'dict)
      (define projection
        (if (= n-methods 1)
            dict-var
            (build-sigma-accessor n-methods i dict-var)))

      (define inner-fn
        `(fn (,dict-var : ,applied-trait-type) ,projection))
      (define accessor-body
        (if (null? params)
            inner-fn
            (build-nested-fn param-pi-bindings inner-fn)))

      `(def ,accessor-name : ,accessor-type ,accessor-body)))

  ;; Return the accessor defs (deftype was already processed via process-deftype)
  accessor-defs)

;; ========================================
;; Property declarations
;; ========================================
;; Syntax:
;;   (property PropertyName ($brace-params A)
;;     :where (Eq A)
;;     :includes (SomeOtherProp A)
;;     (reflexivity :holds (forall (x : A) [eq? x x]))
;;     (symmetry :holds (forall (x : A) (y : A) [eq? x y] -> [eq? y x])))
;;
;; A property groups reusable propositions. Like bundle for traits,
;; property is for proposition groups.

;; property-clause: a single proposition within a property
;; name: symbol (e.g., reflexivity)
;; forall-binders: the forall expression if present, or #f
;; holds-expr: the proposition expression
(struct property-clause (name forall-binders holds-expr) #:transparent)

;; property-entry: stores a property declaration
;; name: symbol
;; params: alist of ((name . kind) ...) from $brace-params
;; where-clauses: list of constraint datums
;; includes: list of property references (for composition)
;; clauses: list of property-clause structs
;; metadata: hasheq of extra metadata
(struct property-entry (name params where-clauses includes clauses metadata) #:transparent)

;; Registry: property-name → property-entry
(define current-property-store (make-parameter (hasheq)))

(define (register-property! name entry)
  (current-property-store (hash-set (current-property-store) name entry))
  ;; Phase 2a: dual-write to cell
  (macros-cell-write! (current-property-store-cell-id) (hasheq name entry)))

;; Track 3 Phase 1: cell-primary reader
(define (read-property-store)
  (or (macros-cell-read-safe (current-property-store-cell-id)) (current-property-store)))

(define (lookup-property name)
  (hash-ref (read-property-store) name #f))

;; Parse a single property clause datum.
;; Input: (- :name "law-name" :forall ($brace-params x : A) :holds expr)
;; The head symbol is - (dash), followed by keyword-value pairs.
;; Returns: property-clause struct
(define (parse-property-clause clause-datum prop-name)
  (unless (and (pair? clause-datum) (eq? (car clause-datum) '-))
    (error 'property "property ~a: clause must start with -, got ~a" prop-name clause-datum))
  (define kv-list (cdr clause-datum))
  ;; Parse keyword-value pairs
  (let loop ([remaining kv-list] [cname #f] [forall-binders #f] [holds-expr #f])
    (cond
      [(null? remaining)
       (unless cname
         (error 'property "property ~a: clause missing :name" prop-name))
       (unless holds-expr
         (error 'property "property ~a: clause ~a missing :holds" prop-name cname))
       (property-clause cname forall-binders holds-expr)]
      [(eq? (car remaining) ':name)
       (when (null? (cdr remaining))
         (error 'property "property ~a: :name missing value" prop-name))
       (loop (cddr remaining) (cadr remaining) forall-binders holds-expr)]
      [(eq? (car remaining) ':forall)
       ;; Collect binder groups (could be $brace-params or plain forms) until next keyword
       (define-values (binder-forms rest)
         (let bloop ([r (cdr remaining)] [acc '()])
           (cond
             [(null? r) (values (reverse acc) '())]
             [(keyword-like-symbol? (car r)) (values (reverse acc) r)]
             [else (bloop (cdr r) (cons (car r) acc))])))
       (loop rest cname binder-forms holds-expr)]
      [(eq? (car remaining) ':exists)
       ;; O7: Existential quantification — collect binder groups, tag with :exists
       (define-values (binder-forms rest)
         (let bloop ([r (cdr remaining)] [acc '()])
           (cond
             [(null? r) (values (reverse acc) '())]
             [(keyword-like-symbol? (car r)) (values (reverse acc) r)]
             [else (bloop (cdr r) (cons (car r) acc))])))
       (loop rest cname (list ':exists binder-forms) holds-expr)]
      [(eq? (car remaining) ':holds)
       ;; Collect expression(s) until next keyword
       (define-values (expr-forms rest)
         (let bloop ([r (cdr remaining)] [acc '()])
           (cond
             [(null? r) (values (reverse acc) '())]
             [(keyword-like-symbol? (car r)) (values (reverse acc) r)]
             [else (bloop (cdr r) (cons (car r) acc))])))
       (define expr
         (if (= (length expr-forms) 1)
             (car expr-forms)
             expr-forms))
       (loop rest cname forall-binders expr)]
      [else
       ;; Skip unknown keywords
       (if (and (pair? (cdr remaining)) (not (keyword-like-symbol? (cadr remaining))))
           (loop (cddr remaining) cname forall-binders holds-expr)
           (loop (cdr remaining) cname forall-binders holds-expr))])))

;; process-property: parse and register a property declaration
;; Returns '() (property is metadata-only, no code generation)
(define (process-property datum)
  (unless (and (list? datum) (>= (length datum) 3))
    (error 'property "property requires: (property PropName {params} clause1 ...)"))
  (define head (cadr datum))
  (define rest (cddr datum))
  ;; Parse name and params (similar to trait)
  (define-values (prop-name params remaining)
    (cond
      ;; Brace-params: (property PropName ($brace-params A) ...)
      [(and (symbol? head)
            (not (null? rest))
            (let ([maybe-braces (car rest)])
              (and (pair? maybe-braces)
                   (eq? (car maybe-braces) '$brace-params)
                   ;; Must NOT be a metadata block
                   (or (null? (cdr maybe-braces))
                       (not (keyword-like-symbol? (cadr maybe-braces)))))))
       (define brace-element (car rest))
       (define symbols (cdr brace-element))
       (define brace-params (parse-brace-param-list symbols 'property))
       (values head brace-params (cdr rest))]
      ;; No params
      [(symbol? head)
       (values head '() rest)]
      [else
       (error 'property "property: invalid name/params: ~a" head)]))
  ;; Separate trailing metadata from clauses
  (define-values (body-forms metadata)
    (if (and (not (null? remaining))
             (let ([last-elem (last remaining)])
               (and (pair? last-elem)
                    (let ([h (car last-elem)])
                      (cond
                        [(symbol? h) (eq? h '$brace-params)]
                        [(syntax? h) (eq? (syntax-e h) '$brace-params)]
                        [else #f]))
                    (pair? (cdr last-elem))
                    (keyword-like-symbol? (cadr last-elem)))))
        (values (drop-right remaining 1) (parse-spec-metadata (last remaining)))
        (values remaining (hasheq))))
  ;; Extract :where constraints (from keyword position or metadata)
  (define-values (non-where-forms positional-where)
    (let loop ([rest body-forms] [before '()] [after-where '()] [in-where? #f])
      (cond
        [(null? rest) (values (reverse before) (reverse after-where))]
        [(and (not in-where?) (eq? (car rest) ':where))
         (loop (cdr rest) before after-where #t)]
        [in-where?
         (if (and (pair? (car rest)) (not (keyword-like-symbol? (car rest))))
             (loop (cdr rest) before (cons (car rest) after-where) #t)
             (loop rest before after-where #f))]
        [else (loop (cdr rest) (cons (car rest) before) after-where in-where?)])))
  (define meta-where (hash-ref metadata ':where #f))
  (define where-clauses
    (append positional-where (or meta-where '())))
  ;; Extract :includes (from keyword position or metadata)
  (define-values (clause-forms positional-includes)
    (let loop ([rest non-where-forms] [before '()] [after-inc '()] [in-inc? #f])
      (cond
        [(null? rest) (values (reverse before) (reverse after-inc))]
        [(and (not in-inc?) (eq? (car rest) ':includes))
         (loop (cdr rest) before after-inc #t)]
        [in-inc?
         (if (and (pair? (car rest)) (not (keyword-like-symbol? (car rest))))
             (loop (cdr rest) before (cons (car rest) after-inc) #t)
             (loop rest before after-inc #f))]
        [else (loop (cdr rest) (cons (car rest) before) after-inc in-inc?)])))
  (define meta-includes (hash-ref metadata ':includes #f))
  (define includes
    (append positional-includes (or meta-includes '())))
  ;; Parse property clauses (forms starting with -)
  (define clauses
    (map (lambda (c) (parse-property-clause c prop-name))
         (filter (lambda (x) (and (pair? x) (eq? (car x) '-))) clause-forms)))
  ;; Register
  (register-property! prop-name
                      (property-entry prop-name params where-clauses includes clauses metadata))
  ;; Properties are metadata-only — no code generation in Phase 1
  '())

;; flatten-property : symbol → (listof property-clause)
;; Resolves :includes recursively, producing a flat list of clauses.
;; Each clause name is /-qualified: "parent-prop/clause-name".
;; Detects cycles via visited set.
(define (flatten-property prop-name)
  (define entry (lookup-property prop-name))
  (unless entry
    (error 'property "unknown property: ~a" prop-name))
  (flatten-property-entry prop-name entry (seteq)))

(define (flatten-property-entry prop-name entry visited)
  (when (set-member? visited prop-name)
    (error 'property "circular :includes detected: ~a" prop-name))
  (define visited+ (set-add visited prop-name))
  ;; Flatten includes first
  (define included-clauses
    (append-map
      (lambda (inc-ref)
        ;; inc-ref is like (semigroup-laws A) — head is property name
        (define inc-name (if (pair? inc-ref) (car inc-ref) inc-ref))
        (define inc-entry (lookup-property inc-name))
        (unless inc-entry
          (error 'property "property ~a: :includes unknown property ~a"
                 prop-name inc-name))
        (flatten-property-entry inc-name inc-entry visited+))
      (property-entry-includes entry)))
  ;; Own clauses, /-qualified
  (define own-clauses
    (map (lambda (c)
           (property-clause
             (string->symbol
               (format "~a/~a" prop-name (property-clause-name c)))
             (property-clause-forall-binders c)
             (property-clause-holds-expr c)))
         (property-entry-clauses entry)))
  (append included-clauses own-clauses))

;; spec-properties : symbol → (or/c (listof datum) #f)
;; Returns the :properties metadata from a spec entry, or #f if none.
(define (spec-properties name)
  (define se (lookup-spec name))
  (and se
       (let ([md (spec-entry-metadata se)])
         (and md (hash-ref md ':properties #f)))))

;; spec-examples : symbol → (or/c (listof datum) #f)
;; Returns the :examples metadata from a spec entry, or #f if none.
(define (spec-examples name)
  (define se (lookup-spec name))
  (and se
       (let ([md (spec-entry-metadata se)])
         (and md (hash-ref md ':examples #f)))))

;; spec-doc : symbol → (or/c string #f)
;; Returns the :doc metadata from a spec entry, or #f if none.
(define (spec-doc name)
  (define se (lookup-spec name))
  (and se
       (let ([md (spec-entry-metadata se)])
         (and md (hash-ref md ':doc #f)))))

;; spec-deprecated : symbol → (or/c string #t #f)
;; Returns the :deprecated metadata from a spec entry, or #f if none.
(define (spec-deprecated name)
  (define se (lookup-spec name))
  (and se
       (let ([md (spec-entry-metadata se)])
         (and md (hash-ref md ':deprecated #f)))))

;; trait-laws-flattened : symbol → (listof property-clause)
;; Returns a flat list of all property clauses from a trait's :laws references.
(define (trait-laws-flattened trait-name)
  (define laws (lookup-trait-laws trait-name))
  (append-map
    (lambda (law-ref)
      (define p-name (if (pair? law-ref) (car law-ref) law-ref))
      (if (lookup-property p-name)
          (flatten-property p-name)
          '()))
    laws))

;; trait-doc : symbol → (or/c string #f)
;; Returns the :doc metadata from a trait, or #f if none.
(define (trait-doc name)
  (define tm (lookup-trait name))
  (and tm (hash-ref (trait-meta-metadata tm) ':doc #f)))

;; trait-deprecated : symbol → (or/c string #t #f)
;; Returns the :deprecated metadata from a trait, or #f if none.
(define (trait-deprecated name)
  (define tm (lookup-trait name))
  (and tm (hash-ref (trait-meta-metadata tm) ':deprecated #f)))

;; bundle-doc : symbol → (or/c string #f)
;; Returns the :doc metadata from a bundle, or #f if none.
(define (bundle-doc name)
  (define be (lookup-bundle name))
  (and be (hash-ref (bundle-entry-metadata be) ':doc #f)))

;; ========================================
;; Functor declarations
;; ========================================
;; Syntax:
;;   (functor Maybe ($brace-params A)
;;     :unfolds <(A : Type) -> Type>
;;     {$brace-params metadata...})
;;
;; A functor names a type abstraction with optional category-theoretic metadata.
;; In Phase 1, it registers as a deftype for transparent expansion.

;; functor-entry: stores a functor declaration
;; name: symbol
;; params: alist of ((name . kind) ...) from $brace-params
;; unfolds: the type expression it expands to (from :unfolds), or #f
;; metadata: hasheq of extra metadata
(struct functor-entry (name params unfolds metadata) #:transparent)

;; Registry: functor-name → functor-entry
(define current-functor-store (make-parameter (hasheq)))

(define (register-functor! name entry)
  (current-functor-store (hash-set (current-functor-store) name entry))
  ;; Phase 2a: dual-write to cell
  (macros-cell-write! (current-functor-store-cell-id) (hasheq name entry)))

;; Track 3 Phase 1: cell-primary reader
(define (read-functor-store)
  (or (macros-cell-read-safe (current-functor-store-cell-id)) (current-functor-store)))

(define (lookup-functor name)
  (hash-ref (read-functor-store) name #f))

;; process-functor: parse and register a functor declaration
;; Also registers as a deftype for transparent expansion.
;; Returns '() (functor is metadata-only in Phase 1)
(define (process-functor datum)
  (unless (and (list? datum) (>= (length datum) 3))
    (error 'functor "functor requires: (functor Name {params} ...)"))
  (define head (cadr datum))
  (define rest (cddr datum))
  ;; Parse name and params (similar to trait)
  (define-values (func-name params remaining)
    (cond
      ;; Brace-params: (functor Maybe ($brace-params A) ...)
      [(and (symbol? head)
            (not (null? rest))
            (let ([maybe-braces (car rest)])
              (and (pair? maybe-braces)
                   (eq? (car maybe-braces) '$brace-params)
                   ;; Must NOT be a metadata block
                   (or (null? (cdr maybe-braces))
                       (not (keyword-like-symbol? (cadr maybe-braces)))))))
       (define brace-element (car rest))
       (define symbols (cdr brace-element))
       (define brace-params (parse-brace-param-list symbols 'functor))
       (values head brace-params (cdr rest))]
      ;; No params
      [(symbol? head)
       (values head '() rest)]
      [else
       (error 'functor "functor: invalid name/params: ~a" head)]))
  ;; Separate trailing metadata from body
  (define-values (body-forms metadata)
    (if (and (not (null? remaining))
             (let ([last-elem (last remaining)])
               (and (pair? last-elem)
                    (let ([h (car last-elem)])
                      (cond
                        [(symbol? h) (eq? h '$brace-params)]
                        [(syntax? h) (eq? (syntax-e h) '$brace-params)]
                        [else #f]))
                    (pair? (cdr last-elem))
                    (keyword-like-symbol? (cadr last-elem)))))
        (values (drop-right remaining 1) (parse-spec-metadata (last remaining)))
        (values remaining (hasheq))))
  ;; Extract :unfolds from positional body or metadata
  (define unfolds-expr
    (or (hash-ref metadata ':unfolds #f)
        ;; Check positional: (:unfolds expr ...) in body-forms
        (let loop ([rest body-forms])
          (cond
            [(null? rest) #f]
            [(eq? (car rest) ':unfolds)
             (if (null? (cdr rest)) #f
                 (cadr rest))]
            [else (loop (cdr rest))]))))
  ;; :unfolds is required for functors
  (unless unfolds-expr
    (error 'functor "functor ~a: requires :unfolds type expression" func-name))
  ;; G4: Collision detection — functor must not shadow existing data type
  (when (or (lookup-ctor func-name) (lookup-type-ctors func-name))
    (error 'functor
      "functor `~a` conflicts with existing data type `~a` — use a different name"
      func-name func-name))
  ;; Register functor entry
  (register-functor! func-name
                     (functor-entry func-name params unfolds-expr metadata))
  ;; Also register as deftype for transparent expansion (if unfolds is provided and params exist)
  (when (and unfolds-expr (not (null? params)))
    ;; Build a deftype: (deftype (Name $A $B ...) unfolds-body)
    (define param-name->pvar
      (for/hasheq ([p (in-list params)])
        (values (car p)
                (string->symbol (string-append "$" (symbol->string (car p)))))))
    (define (pvarify d)
      (cond
        [(symbol? d) (hash-ref param-name->pvar d d)]
        [(pair? d) (map pvarify d)]
        [else d]))
    (define deftype-pattern
      `(,func-name ,@(map (lambda (p) (hash-ref param-name->pvar (car p))) params)))
    (define deftype-body (pvarify unfolds-expr))
    (process-deftype `(deftype ,deftype-pattern ,deftype-body)))
  ;; Functors are metadata-only in Phase 1 — no additional code generation
  '())

;; ========================================
;; User-defined precedence groups (Phase 2)
;; ========================================
;; precedence-group name :assoc left :tighter-than additive
;; Stores user-defined groups in current-user-precedence-groups.
;; The Pratt parser merges these with builtin-precedence-groups at lookup time.

(define current-user-precedence-groups (make-parameter (hasheq)))

(define (register-precedence-group! name entry)
  (current-user-precedence-groups
   (hash-set (current-user-precedence-groups) name entry))
  ;; Phase 2c: dual-write to cell
  (macros-cell-write! (current-user-precedence-groups-cell-id) (hasheq name entry)))

;; Track 3 Phase 3: cell-primary reader for user precedence groups
(define (read-user-precedence-groups)
  (or (macros-cell-read-safe (current-user-precedence-groups-cell-id)) (current-user-precedence-groups)))

(define (lookup-precedence-group name)
  (or (hash-ref (read-user-precedence-groups) name #f)
      (hash-ref builtin-precedence-groups name #f)))

;; User-defined mixfix operators: symbol → op-info
;; Populated from :mixfix metadata on spec entries
(define current-user-operators (make-parameter (hasheq)))

;; Track 3 Phase 3: cell-primary reader for user operators
(define (read-user-operators)
  (or (macros-cell-read-safe (current-user-operators-cell-id)) (current-user-operators)))

(define (register-user-operator! sym info)
  (current-user-operators
   (hash-set (current-user-operators) sym info))
  ;; Phase 2c: dual-write to cell
  (macros-cell-write! (current-user-operators-cell-id) (hasheq sym info)))

;; process-precedence-group: parse and register a precedence-group declaration
;; Syntax (WS mode): precedence-group mygroup :assoc left :tighter-than additive
;; After reader: (precedence-group mygroup ($brace-params :assoc left :tighter-than additive))
;;   or positional: (precedence-group mygroup :assoc left :tighter-than additive)
(define (process-precedence-group datum)
  (unless (and (list? datum) (>= (length datum) 2))
    (error 'precedence-group "precedence-group requires at least a name"))
  (define name (cadr datum))
  (unless (symbol? name)
    (error 'precedence-group "precedence-group name must be a symbol, got: ~a" name))
  (define rest (cddr datum))
  ;; Parse metadata: either a $brace-params map or inline keyword args
  (define metadata
    (cond
      [(and (pair? rest) (pair? (car rest))
            (eq? (caar rest) '$brace-params))
       ;; Brace-params map
       (parse-spec-metadata (car rest))]
      [(pair? rest)
       ;; Inline keyword args: :assoc left :tighter-than additive ...
       (parse-spec-metadata (cons '$brace-params rest))]
      [else (hasheq)]))
  ;; Extract fields
  (define assoc-val (hash-ref metadata ':assoc 'left))
  (define assoc-sym
    (cond
      [(memq assoc-val '(left right none)) assoc-val]
      [else (error 'precedence-group
                   "~a: :assoc must be left, right, or none; got: ~a" name assoc-val)]))
  ;; :tighter-than can be a single symbol or a list of symbols
  (define tighter-raw (hash-ref metadata ':tighter-than '()))
  (define tighter-than
    (cond
      [(null? tighter-raw) '()]
      [(symbol? tighter-raw) (list tighter-raw)]
      [(list? tighter-raw) tighter-raw]
      [else (list tighter-raw)]))
  ;; Validate that all referenced groups exist
  (for ([g (in-list tighter-than)])
    (unless (or (hash-ref builtin-precedence-groups g #f)
                (hash-ref (read-user-precedence-groups) g #f))
      (error 'precedence-group
             "~a: :tighter-than references unknown group '~a'" name g)))
  ;; Register
  (register-precedence-group! name (prec-group name assoc-sym tighter-than)))

;; maybe-register-mixfix-operator: extract :mixfix metadata from spec and register operator
;; :mixfix metadata is a hash with :symbol and :group keys
;; e.g. spec plus ... :mixfix {:symbol + :group additive}
(define (maybe-register-mixfix-operator fn-name metadata)
  (define mixfix-meta (hash-ref metadata ':mixfix #f))
  (when (and mixfix-meta (hash? mixfix-meta))
    (define op-sym (hash-ref mixfix-meta ':symbol #f))
    (define grp-name (hash-ref mixfix-meta ':group #f))
    (when (and op-sym grp-name (symbol? op-sym) (symbol? grp-name))
      ;; Resolve group from builtin or user-defined groups
      (define grp (or (hash-ref builtin-precedence-groups grp-name #f)
                      (hash-ref (read-user-precedence-groups) grp-name #f)))
      (unless grp
        (error 'spec ":mixfix on '~a': unknown precedence group '~a'" fn-name grp-name))
      ;; Compute binding powers — merge all groups for the computation
      (define all-groups
        (for/fold ([h builtin-precedence-groups])
                  ([(k v) (in-hash (read-user-precedence-groups))])
          (hash-set h k v)))
      (define bps (compute-binding-powers all-groups))
      (define bp-pair (hash-ref bps grp-name))
      ;; Determine the function name to emit — if fn-name is a parser keyword, use it directly;
      ;; otherwise use fn-name as a regular function application
      (define assoc-val (prec-group-assoc grp))
      (register-user-operator! op-sym
        (op-info op-sym fn-name grp-name assoc-val (car bp-pair) (cdr bp-pair) #f)))))

;; ========================================
;; process-impl: trait implementation
;; ========================================
;; Syntax (WS, after reader):
;;   (impl TraitName TypeArg1 TypeArg2 ...
;;     (defn method1 [params] <ReturnType> body1)
;;     (defn method2 [params] <ReturnType> body2))
;;
;; Sexp:
;;   (impl TraitName TypeArg1 ...
;;     (defn method1 (x : T1) ... : Ret body)
;;     ...)
;;
;; Generates:
;;   (def TypeArg--TraitName--dict : (TraitName TypeArg) dict-value)
;;
;; For single-method traits: dict value is the bare fn
;; For multi-method traits: dict value is (pair fn1 (pair fn2 ...)) nested
;;
;; Returns: list of s-expression datums (just the dict def)

;; Build a nested pair expression from a list of expressions.
;; (build-nested-pair '(e1 e2 e3)) → (pair e1 (pair e2 e3))
(define (build-nested-pair exprs)
  (cond
    [(= (length exprs) 1) (car exprs)]
    [(= (length exprs) 2)
     `(pair ,(car exprs) ,(cadr exprs))]
    [else
     `(pair ,(car exprs) ,(build-nested-pair (cdr exprs)))]))

;; Extract method body from a defn datum.
;; Input: (defn name [params] <RetType> body) or (defn name (p : T) ... : Ret body)
;; Returns: the full defn datum as-is (will be processed by preparse later)
;; We extract just the defn body parts and build an fn expression.
(define (impl-method-to-fn defn-datum)
  ;; The defn datum is a full defn form. We want to return it as a defn
  ;; that gets processed normally. But for impl, we need to convert
  ;; the defn body into a lambda for the dictionary.
  ;;
  ;; Strategy: return the defn as-is. The impl will emit individual defn forms
  ;; for each method, plus a dictionary def that references them.
  defn-datum)

(define (process-impl datum)
  (unless (and (list? datum) (>= (length datum) 4))
    (error 'impl "impl requires: (impl TraitName TypeArgs... method-defn1 method-defn2 ...)"))

  (define trait-name (cadr datum))
  (unless (symbol? trait-name)
    (error 'impl "impl: trait name must be a symbol, got ~a" trait-name))

  ;; Look up trait metadata
  (define tm (lookup-trait trait-name))
  (unless tm
    (error 'impl "impl: unknown trait ~a (must be declared with 'trait' first)" trait-name))

  (define expected-methods (trait-meta-methods tm))
  (define n-expected (length expected-methods))

  ;; Parse type args and method defns from the rest of the datum
  ;; The structure is: (impl TraitName type-arg1 ... method-defn1 method-defn2 ...)
  ;; Type args are symbols/lists that are NOT defn forms.
  ;; Method defns are lists starting with 'defn.
  (define rest-after-trait (cddr datum))

  ;; Split into type-args, where-constraints, and method-defns.
  ;; Type args are symbols/lists that are NOT defn forms and NOT 'where.
  ;; 'where marks the start of constraints.
  ;; Method defns are lists starting with 'defn.
  (define-values (type-args where-constraints method-defns)
    (let loop ([remaining rest-after-trait]
               [targs '()])
      (cond
        [(null? remaining)
         (values (reverse targs) '() '())]
        ;; Hit 'where — extract constraints then method defns
        [(eq? (car remaining) 'where)
         (define after-where (cdr remaining))
         ;; Constraints are parenthesized lists; method defns start with 'defn
         (define-values (constraints methods)
           (let cloop ([rem after-where] [cs '()])
             (cond
               [(null? rem) (values (reverse cs) '())]
               [(and (pair? (car rem))
                     (not (null? (car rem)))
                     (eq? (caar rem) 'defn))
                (values (reverse cs) rem)]
               [(list? (car rem))
                (cloop (cdr rem) (cons (car rem) cs))]
               [else
                (error 'impl "impl ~a: unexpected token after where: ~a" trait-name (car rem))])))
         (values (reverse targs) constraints methods)]
        ;; Hit a defn — no where clause
        [(and (pair? (car remaining))
              (eq? (caar remaining) 'defn))
         (values (reverse targs) '() remaining)]
        [else
         (loop (cdr remaining) (cons (car remaining) targs))])))

  (when (null? type-args)
    (error 'impl "impl ~a: must specify at least one type argument" trait-name))

  ;; Dispatch: parametric impl vs monomorphic impl
  ;; Parametric if has where-constraints OR has compound type args (e.g. (FlatVal A))
  (define has-compound-type-args?
    (ormap (lambda (ta) (and (list? ta) (>= (length ta) 2))) type-args))
  (if (or (not (null? where-constraints)) has-compound-type-args?)
      (process-parametric-impl trait-name tm type-args where-constraints method-defns)
      (process-monomorphic-impl trait-name tm type-args method-defns)))

;; Monomorphic impl: impl Eq Nat (defn eq? ...)
;; This is the existing behavior, extracted into a helper.
(define (process-monomorphic-impl trait-name tm type-args method-defns)
  (define expected-methods (trait-meta-methods tm))
  (define n-expected (length expected-methods))

  ;; Validate method count
  (unless (= (length method-defns) n-expected)
    (error 'impl "impl ~a: expected ~a method(s), got ~a"
           trait-name n-expected (length method-defns)))

  ;; Validate method names match trait declaration (in order)
  (for ([defn-d (in-list method-defns)]
        [expected-m (in-list expected-methods)]
        [i (in-naturals)])
    (define defn-name (and (list? defn-d) (>= (length defn-d) 2) (cadr defn-d)))
    (define expected-name (trait-method-name expected-m))
    (unless (eq? defn-name expected-name)
      (error 'impl "impl ~a: method ~a at position ~a should be '~a', got '~a'"
             trait-name trait-name i expected-name defn-name)))

  ;; Generate dictionary name: TypeArg1--TraitName--dict
  ;; For single type arg: "Nat--Eq--dict"
  ;; For multiple: "Nat-Bool--Convert--dict"
  (define type-arg-str
    (string-join
     (map (lambda (ta)
            (if (symbol? ta)
                (symbol->string ta)
                (format "~a" ta)))
          type-args)
     "-"))
  (define dict-name
    (string->symbol
     (string-append type-arg-str "--" (symbol->string trait-name) "--dict")))

  ;; Generate the applied trait type: (TraitName TypeArg1 TypeArg2 ...)
  (define applied-trait-type
    (if (= (length type-args) 1)
        (let ([ta (car type-args)])
          (if (null? (trait-meta-params tm))
              trait-name
              `(,trait-name ,ta)))
        `(,trait-name ,@type-args)))

  ;; Generate method helper defns (each method gets its own top-level defn)
  ;; Method defn names are scoped: TypeArg--TraitName--method-name
  (define method-helper-names
    (for/list ([defn-d (in-list method-defns)])
      (define method-name (cadr defn-d))
      (string->symbol
       (string-append type-arg-str "--" (symbol->string trait-name)
                      "--" (symbol->string method-name)))))

  ;; Rewrite each defn with scoped name
  ;; Rewrite each defn with scoped name.
  ;; If the defn lacks a return type annotation (only params + body), inject
  ;; the return type from the trait method's type-datum so the parser can build
  ;; the full Pi type. Without this, bare-param defns like `defn describe [n] n`
  ;; produce inferred holes that don't resolve correctly.
  (define method-helper-defns
    (for/list ([defn-d (in-list method-defns)]
               [helper-name (in-list method-helper-names)]
               [expected-m (in-list expected-methods)])
      (define after-name (cddr defn-d))  ;; everything after method name: params body [rettype]
      ;; Check if defn has a return type annotation:
      ;; With rettype: (params rettype body) — 3+ elements, second is $angle-type or ':'
      ;; Without rettype: (params body) — exactly 2 elements, second is the body
      (define needs-rettype?
        (and (= (length after-name) 2)
             (let ([second-datum (if (syntax? (cadr after-name))
                                     (syntax->datum (cadr after-name))
                                     (cadr after-name))])
               (not (and (pair? second-datum)
                         (eq? (car second-datum) '$angle-type))))))
      (if needs-rettype?
          ;; Extract return type from trait method's type-datum.
          ;; Type is curried: (-> A (-> B Ret)). Walk to get the final result type.
          ;; Substitute trait params → type-args.
          (let* ([method-type (trait-method-type-datum expected-m)]
                 [trait-params (map car (trait-meta-params tm))]
                 [subst-type (let subst-loop ([t method-type])
                               (cond
                                 [(symbol? t)
                                  (let ([idx (index-of trait-params t)])
                                    (if idx (list-ref type-args idx) t))]
                                 [(and (pair? t) (eq? (car t) '->))
                                  `(-> ,(subst-loop (cadr t)) ,(subst-loop (caddr t)))]
                                 [(pair? t) (map subst-loop t)]
                                 [else t]))]
                 ;; Extract the final return type from curried arrows
                 [ret-type (let ret-loop ([t subst-type])
                             (if (and (pair? t) (eq? (car t) '->) (= (length t) 3))
                                 (ret-loop (caddr t))
                                 t))]
                 [params (car after-name)]
                 [body (cadr after-name)])
            `(defn ,helper-name ,params ($angle-type ,ret-type) ,body))
          ;; Already has return type — just rename
          (cons 'defn (cons helper-name after-name)))))

  ;; Build dictionary value: for single-method, just the helper name.
  ;; For multi-method, (pair helper1 (pair helper2 helper3))
  (define dict-value
    (if (= n-expected 1)
        (car method-helper-names)
        (build-nested-pair method-helper-names)))

  ;; Dictionary def: (def dict-name : applied-trait-type dict-value)
  (define dict-def
    `(def ,dict-name : ,applied-trait-type ,dict-value))

  ;; Register impl in the registry
  (define impl-key
    (string->symbol (string-append type-arg-str "--" (symbol->string trait-name))))
  (register-impl! impl-key (impl-entry trait-name type-args dict-name))

  ;; Return all definitions: helper defns + dict def
  ;; For single-method, still emit the helper defn too (for direct use by name)
  (append method-helper-defns (list dict-def)))

;; Parametric impl: impl Eq (List A) where (Eq A) (defn eq? ...)
;; Dict is a function that takes type params + constraint dicts → trait dict.
;; For single-method: dict IS the method helper (which takes constraint dicts).
;; For multi-method: dict wraps method helpers in a pair.
(define (process-parametric-impl trait-name tm type-args where-constraints method-defns)
  (define expected-methods (trait-meta-methods tm))
  (define n-expected (length expected-methods))

  ;; Validate method count
  (unless (= (length method-defns) n-expected)
    (error 'impl "impl ~a: expected ~a method(s), got ~a"
           trait-name n-expected (length method-defns)))

  ;; Validate method names match trait declaration
  (for ([defn-d (in-list method-defns)]
        [expected-m (in-list expected-methods)]
        [i (in-naturals)])
    (define defn-name (and (list? defn-d) (>= (length defn-d) 2) (cadr defn-d)))
    (define expected-name (trait-method-name expected-m))
    (unless (eq? defn-name expected-name)
      (error 'impl "impl ~a: method ~a at position ~a should be '~a', got '~a'"
             trait-name trait-name i expected-name defn-name)))

  ;; Identify pattern variables: symbols in type-args that are NOT type constructors.
  ;; In a compound type like (List A), the head (List) is a type constructor,
  ;; and the arguments (A) are potential pattern variables.
  ;; A bare symbol like Nat is a concrete type (not a pattern variable).
  ;; A bare uppercase-starting symbol like A that isn't a known type is a pattern variable.
  (define (collect-pattern-var-candidates ta)
    (cond
      [(symbol? ta) (list ta)]         ;; bare type arg — candidate
      [(and (list? ta) (>= (length ta) 2))
       ;; Compound: (Constructor Arg1 Arg2 ...) — head is constructor, args are candidates
       (apply append (map collect-pattern-var-candidates (cdr ta)))]
      [(list? ta) '()]                 ;; empty or single-element list
      [else '()]))
  (define all-pvar-candidates
    (apply append (map collect-pattern-var-candidates type-args)))
  (define pattern-vars
    (remove-duplicates
     (filter (lambda (s) (not (known-name? s))) all-pvar-candidates)))
  ;; Compute pattern-vars in the order matching implicit quantification.
  ;; Implicit quantification scans constraint param types first (since
  ;; they appear first in the param bracket), then method/return types.
  ;; Without this ordering, dict body helper calls pass type args in the
  ;; wrong order (e.g. K,V instead of V,K for `impl Lattice (Map K V) where (Lattice V)`).
  (define constraint-pvar-candidates
    (apply append
      (map (lambda (c)
             (apply append (map collect-pattern-var-candidates (cdr c))))
           where-constraints)))
  (define ordered-pattern-vars
    (remove-duplicates
     (filter (lambda (s) (not (known-name? s)))
             (append constraint-pvar-candidates all-pvar-candidates))))

  ;; Generate type-arg-str for naming (flattens compound type args)
  (define type-arg-str
    (string-join
     (map (lambda (ta)
            (cond
              [(symbol? ta) (symbol->string ta)]
              [(list? ta) (string-join (map (lambda (x) (format "~a" x)) ta) "-")]
              [else (format "~a" ta)]))
          type-args)
     "-"))
  (define dict-name
    (string->symbol
     (string-append type-arg-str "--" (symbol->string trait-name) "--dict")))

  ;; Generate method helper names
  (define method-helper-names
    (for/list ([defn-d (in-list method-defns)])
      (define method-name (cadr defn-d))
      (string->symbol
       (string-append type-arg-str "--" (symbol->string trait-name)
                      "--" (symbol->string method-name)))))

  ;; Detect the param format used by the method defns:
  ;; - colon-style: [name : Type, ...] — params have ':' symbol
  ;; - angle-style: [name <Type> ...] — params have ($angle-type ...)
  ;; Generate constraint params in the same style.
  ;; Scan ALL methods (not just the first) since zero-arg methods like `bot`
  ;; have empty param brackets that don't indicate style.
  (define uses-colon-style?
    (for/or ([defn-d (in-list method-defns)])
      (let ([params-flat (cddr defn-d)]) ;; everything after (defn name ...)
        ;; Find the parameter bracket
        (let loop ([items params-flat])
          (cond
            [(null? items) #f]
            [(and (list? (car items)) (not (null? (car items)))
                  (symbol? (caar items)))
             ;; This is the bracket — check for ':'
             (memq ': (car items))]
            [else (loop (cdr items))])))))

  ;; Generate synthetic constraint dict param names and type annotations
  ;; Each (Eq A) → parameter formatted to match existing style.
  ;; Colon-style: $Eq-A : (Eq A) → items: ($Eq-A : (Eq A))
  ;; Angle-style: $Eq-A <(Eq A)> → items: ($Eq-A ($angle-type (Eq A)))
  (define constraint-param-pairs
    (for/list ([c (in-list where-constraints)])
      (define param-name
        (string->symbol
         (string-append "$"
                        (string-join (map symbol->string c) "-"))))
      (if uses-colon-style?
          (list param-name ': c)
          (list param-name `($angle-type ,c)))))

  ;; Flatten constraint params for injection
  (define constraint-param-items
    (apply append constraint-param-pairs))

  ;; Rewrite each method defn with scoped name AND constraint dict params prepended
  ;; The constraint params are injected at the front of the parameter bracket.
  (define method-helper-defns
    (for/list ([defn-d (in-list method-defns)]
               [helper-name (in-list method-helper-names)])
      (define original-params (cddr defn-d))  ;; everything after (defn name ...)
      ;; Find the parameter bracket (first list with symbol as first element)
      (define (find-param-bracket items)
        (let loop ([items items] [idx 0])
          (cond
            [(null? items) #f]
            ;; Empty list = empty param bracket [] → ()
            [(and (list? (car items)) (null? (car items)))
             idx]
            [(and (list? (car items))
                  (not (null? (car items)))
                  (symbol? (caar items)))
             idx]
            [else (loop (cdr items) (add1 idx))])))
      (define bracket-idx (find-param-bracket original-params))
      (define new-params
        (cond
          [bracket-idx
           ;; Splice constraint params into existing bracket
           (define old-bracket (list-ref original-params bracket-idx))
           (define new-bracket (append constraint-param-items old-bracket))
           (list-set original-params bracket-idx new-bracket)]
          [else
           ;; No bracket found — create one with just constraint params
           (cons constraint-param-items original-params)]))
      `(defn ,helper-name ,@new-params)))

  ;; Extract method-specific params (name . type) from each ORIGINAL method defn
  ;; (before constraint injection).  These are needed for eta-expansion in the
  ;; dict body to avoid implicit insertion issues with partial application.
  (define method-original-params-list
    (for/list ([defn-d (in-list method-defns)])
      (define after-name (cddr defn-d))  ;; everything after (defn name ...)
      ;; Find the bracket (first list in after-name)
      (define bracket
        (let loop ([items after-name])
          (cond
            [(null? items) '()]
            [(list? (car items)) (car items)]
            [else (loop (cdr items))])))
      ;; Extract name/type pairs from bracket.
      ;; angle-style: ($angle-type X Y ...) is FLAT — type = X if single, (X Y ...) if compound
      (define (angle-type-expr at-form)
        ;; at-form = ($angle-type elem ...) → type = (cdr at-form), unwrap if single
        (let ([elems (cdr at-form)])
          (if (and (pair? elems) (null? (cdr elems)))
              (car elems)     ;; single element: just the symbol
              elems)))        ;; multiple elements: (TypeCon Arg ...)
      (let extract ([items bracket] [pairs '()])
        (cond
          [(null? items) (reverse pairs)]
          ;; angle-style: name ($angle-type ...)
          [(and (>= (length items) 2)
                (symbol? (car items))
                (list? (cadr items))
                (not (null? (cadr items)))
                (eq? '$angle-type (caadr items)))
           (extract (cddr items)
                    (cons (cons (car items) (angle-type-expr (cadr items))) pairs))]
          ;; colon-style: name : TYPE
          [(and (>= (length items) 3)
                (symbol? (car items))
                (eq? ': (cadr items)))
           (extract (cdddr items)
                    (cons (cons (car items) (caddr items)) pairs))]
          [else (extract (cdr items) pairs)]))))

  ;; For single-method traits, dict = method helper (alias via def).
  ;; For multi-method, dict wraps helpers in a nested pair with explicit Pi/fn
  ;; binders.  Methods with extra params (beyond constraint dict) are
  ;; eta-expanded so the helper call is fully saturated — this avoids the
  ;; elaborator's implicit-hole insertion (which fires on partial application
  ;; when n-user-args == n-explicit, inserting metas for leading m0 binders).
  (define dict-def
    (if (= n-expected 1)
        ;; Single-method: dict IS the method helper.
        ;; Just alias: (def dict-name helper-name)
        `(def ,dict-name ,(car method-helper-names))
        ;; Multi-method: generate (def name : type body) with explicit
        ;; Pi/fn binders for pattern-vars and constraint params.
        (let* ([constraint-param-names (map car constraint-param-pairs)]
               [helper-calls
                (for/list ([hn (in-list method-helper-names)]
                           [method-params (in-list method-original-params-list)])
                  (if (null? method-params)
                      ;; Zero extra params (e.g. bot) — direct call is fully saturated
                      `(,hn ,@ordered-pattern-vars ,@constraint-param-names)
                      ;; Has method-specific params — eta-expand so the call provides
                      ;; ALL args (pattern-vars + constraints + method params = total),
                      ;; preventing the elaborator from inserting implicit holes.
                      ;; Use fresh $eta-N names to avoid shadowing pattern-vars or
                      ;; constraint params that are in scope.
                      (let* ([param-types (map cdr method-params)]
                             [eta-names (for/list ([i (in-range (length method-params))])
                                          (string->symbol
                                           (format "$eta-~a" i)))]
                             [full-call `(,hn ,@ordered-pattern-vars
                                              ,@constraint-param-names
                                              ,@eta-names)]
                             [wrapped
                              (for/fold ([body full-call])
                                        ([en (in-list (reverse eta-names))]
                                         [pt (in-list (reverse param-types))])
                                `(fn (,en :w ,pt) ,body))])
                        wrapped)))]
               [dict-body (build-nested-pair helper-calls)]
               ;; Return type expression
               [return-type-expr `(,trait-name ,@type-args)]
               ;; Constraint types (from where-constraints directly)
               [constraint-types where-constraints]
               ;; Build type: Pi pvars:0:Type... -> constraints... -> (Trait TypeArgs)
               [type-with-constraints
                (for/fold ([type return-type-expr])
                          ([ct (in-list (reverse constraint-types))])
                  `(-> ,ct ,type))]
               [full-type
                (for/fold ([type type-with-constraints])
                          ([pv (in-list (reverse ordered-pattern-vars))])
                  `(Pi (,pv :0 (Type 0)) ,type))]
               ;; Build body: fn pvars:0:Type... fn constraints:w... dict-body
               [body-with-constraints
                (for/fold ([body dict-body])
                          ([cn (in-list (reverse constraint-param-names))]
                           [ct (in-list (reverse constraint-types))])
                  `(fn (,cn :w ,ct) ,body))]
               [full-body
                (for/fold ([body body-with-constraints])
                          ([pv (in-list (reverse ordered-pattern-vars))])
                  `(fn (,pv :0 (Type 0)) ,body))])
          `(def ,dict-name : ,full-type ,full-body))))

  ;; Register in parametric impl registry
  (register-param-impl! trait-name
    (param-impl-entry trait-name type-args pattern-vars dict-name where-constraints))

  ;; Return all definitions: method helper defns + dict def(s)
  ;; dict-def may be a single form or a list of forms (spec + def)
  (define dict-forms
    (if (and (list? dict-def) (not (null? dict-def))
             (list? (car dict-def)) (memq (caar dict-def) '(spec def)))
        dict-def           ;; list of forms
        (list dict-def)))  ;; single form → wrap in list
  (append method-helper-defns dict-forms))

;; ========================================
;; HKT-8: process-specialize — register a specialization
;; ========================================
;; Surface syntax (after WS reader):
;;   (specialize gmap for List
;;     (defn gmap [f xs] (list-map f xs)))
;;
;; Generates:
;;   1. A specialized defn with a unique name (gmap--List--specialized)
;;   2. A registry entry: (gmap, List) → gmap--List--specialized
;;
;; The specialized function definition is returned as output; the registry
;; entry is stored for future call-site rewriting optimization.
(define (process-specialize datum)
  (unless (and (list? datum) (>= (length datum) 4))
    (error 'specialize
      "specialize requires: (specialize fn-name for TypeCon defn-body...)"))

  (define fn-name (cadr datum))
  (unless (symbol? fn-name)
    (error 'specialize "specialize: function name must be a symbol, got ~a" fn-name))

  ;; Skip 'for' keyword
  (define rest-after-name (cddr datum))
  (unless (and (pair? rest-after-name) (eq? (car rest-after-name) 'for))
    (error 'specialize "specialize: expected 'for' keyword after function name"))

  (define rest-after-for (cdr rest-after-name))
  (unless (and (pair? rest-after-for) (symbol? (car rest-after-for)))
    (error 'specialize "specialize: expected type constructor name after 'for'"))

  (define type-con (car rest-after-for))
  (define body-forms (cdr rest-after-for))

  ;; Generate specialized function name
  (define spec-name
    (string->symbol
      (string-append (symbol->string fn-name) "--"
                     (symbol->string type-con) "--specialized")))

  ;; Parse the body — expect exactly one defn form
  (unless (and (pair? body-forms)
               (pair? (car body-forms))
               (eq? (caar body-forms) 'defn))
    (error 'specialize
      "specialize ~a for ~a: body must contain a defn form" fn-name type-con))

  (define defn-form (car body-forms))
  ;; Rewrite the defn to use the specialized name
  ;; Original: (defn gmap [f xs] body)
  ;; Rewritten: (defn gmap--List--specialized [f xs] body)
  (define spec-defn
    (cons 'defn (cons spec-name (cddr defn-form))))

  ;; Register in the specialization registry
  (register-specialization! fn-name type-con spec-name)

  ;; Return the specialized defn as output
  (list spec-defn))


;; ================================================================
;; LAYER 2: POST-PARSE MACRO SYSTEM
;; ================================================================

;; ========================================
;; Post-parse macro registry (for surf-* transforms)
;; ========================================
;; Maps symbol → (surf-form → surf-form) procedure
(define current-macro-registry (make-parameter (hasheq)))

(define (register-macro! name proc)
  (current-macro-registry
   (hash-set (current-macro-registry) name proc))
  ;; Phase 2c: dual-write to cell
  (macros-cell-write! (current-macro-registry-cell-id) (hasheq name proc)))

;; Track 3 Phase 3: cell-primary reader for macro registry
(define (read-macro-registry)
  (or (macros-cell-read-safe (current-macro-registry-cell-id)) (current-macro-registry)))

(define (lookup-macro name)
  (hash-ref (read-macro-registry) name #f))

;; ========================================
;; Top-level command predicate
;; ========================================
(define (top-level-command? surf)
  (or (surf-def? surf)
      (surf-defn? surf)
      (surf-check? surf)
      (surf-eval? surf)
      (surf-infer? surf)
      (surf-expand? surf)
      (surf-parse? surf)
      (surf-elaborate? surf)))

;; ========================================
;; Collect all surf-var names from a surface type AST
;; ========================================
;; Walks a type-level surface AST and returns a list of symbol names
;; in left-to-right first-appearance order (deduplicated).
;; Used by infer-auto-implicits to find free type variables.
(define (collect-surf-vars type-ast)
  (define seen (make-hasheq))
  (define result '())
  (define (add! name)
    (unless (hash-ref seen name #f)
      (hash-set! seen name #t)
      (set! result (cons name result))))
  (define (walk ast)
    (match ast
      [(surf-var name _loc) (add! name)]
      [(surf-pi binder body _loc)
       (let ([btype (binder-info-type binder)])
         (when btype (walk btype)))
       (walk body)]
      [(surf-arrow _ domain codomain _loc)
       (walk domain)
       (walk codomain)]
      [(surf-sigma binder body _loc)
       (let ([btype (binder-info-type binder)])
         (when btype (walk btype)))
       (walk body)]
      [(surf-app func args _loc)
       (walk func)
       (for-each walk args)]
      [(surf-eq type lhs rhs _loc)
       (walk type) (walk lhs) (walk rhs)]
      [(surf-vec-type elem-type length _loc)
       (walk elem-type) (walk length)]
      [(surf-fin-type bound _loc)
       (walk bound)]
      [(surf-ann type term _loc)
       (walk type) (walk term)]
      [(surf-suc pred _loc)
       (walk pred)]
      ;; Terminal nodes that are not variable references — skip
      [(surf-hole _) (void)]
      [(surf-type _ _) (void)]
      [(surf-nat-type _) (void)]
      [(surf-bool-type _) (void)]
      [(surf-posit8-type _) (void)]
      [(surf-posit16-type _) (void)]
      [(surf-posit32-type _) (void)]
      [(surf-posit64-type _) (void)]
      [(surf-quire8-type _) (void)]
      [(surf-quire16-type _) (void)]
      [(surf-quire32-type _) (void)]
      [(surf-quire64-type _) (void)]
      [(surf-symbol-type _) (void)]
      [(surf-symbol _ _) (void)]
      [(surf-keyword-type _) (void)]
      [(surf-keyword _ _) (void)]
      ;; Map type: walk key and value type sub-expressions
      [(surf-map-type k v _loc)
       (walk k) (walk v)]
      ;; Set type: walk element type
      [(surf-set-type a _loc)
       (walk a)]
      ;; PVec type: walk element type
      [(surf-pvec-type a _loc)
       (walk a)]
      [(surf-pvec-literal elems _loc)
       (for-each walk elems)]
      [(surf-zero _) (void)]
      [(surf-true _) (void)]
      [(surf-false _) (void)]
      [(surf-refl _) (void)]
      [(surf-nat-lit _ _) (void)]
      ;; Catch-all for any unhandled nodes
      [_ (void)]))
  (walk type-ast)
  (reverse result))

;; ========================================
;; Auto-implicit type parameter inference
;; ========================================

;; Built-in type/constructor names that should never become auto-implicits.
;; These are symbols recognized by parse-symbol in parser.rkt.
(define builtin-names
  '(Nat Bool Type Posit8 zero true false refl suc
    Pi Sigma Eq Vec Fin natrec boolrec J pair fst snd
    vnil vcons vhead vtail vindex fzero fsuc
    posit8 p8+ p8- p8* p8/ p8-neg p8-abs p8-sqrt p8< p8<= p8-from-nat p8-if-nar
    Posit16 posit16 p16+ p16- p16* p16/ p16-neg p16-abs p16-sqrt p16-lt p16-le p16-from-nat p16-if-nar
    Posit32 posit32 p32+ p32- p32* p32/ p32-neg p32-abs p32-sqrt p32-lt p32-le p32-from-nat p32-if-nar
    Posit64 posit64 p64+ p64- p64* p64/ p64-neg p64-abs p64-sqrt p64-lt p64-le p64-from-nat p64-if-nar
    Quire8 q8-zero q8-fma q8-to
    Quire16 q16-zero q16-fma q16-to
    Quire32 q32-zero q32-fma q32-to
    Quire64 q64-zero q64-fma q64-to
    Int int int+ int- int* int/ int-mod int-neg int-abs int-lt int-le int-eq from-nat
    Rat rat rat+ rat- rat* rat/ rat-neg rat-abs rat-lt rat-le rat-eq from-int rat-numer rat-denom
    Keyword Map map-empty map-assoc map-get map-dissoc map-size map-has-key? map-keys map-vals
    Set set-empty set-insert set-member? set-delete set-size set-union set-intersect set-diff set-to-list
    PVec pvec-empty pvec-push pvec-nth pvec-update pvec-length pvec-pop pvec-concat pvec-slice pvec-to-list pvec-from-list pvec-fold pvec-map pvec-filter
    set-fold set-filter
    map-fold-entries map-filter-entries map-map-vals))

;; Check if a symbol is a "known name" — should NOT be treated as a free type variable.
(define (known-name? name)
  (or (memq name builtin-names)
      (global-env-lookup-type name)                      ;; previously defined def/defn
      (hash-ref (read-ctor-registry) name #f)         ;; data constructor (cell-primary)
      (hash-ref (read-type-meta) name #f)             ;; data type name (cell-primary)
      (hash-ref (read-preparse-registry) name #f)))   ;; deftype alias / macro (cell-primary)

;; Detect if a surf-defn already has explicit implicit params (from {A B} syntax).
;; If the first Pi binder has mult='m0 and type=(surf-type ...) and its name
;; matches the first param-name, then the parser already inserted implicits.
(define (has-leading-implicits? type-ast param-names)
  (and (not (null? param-names))
       (match type-ast
         [(surf-pi (binder-info bname 'm0 (surf-type _ _)) _body _loc)
          (eq? bname (car param-names))]
         [_ #f])))

;; Infer auto-implicit type parameters for a surf-defn.
;; If the defn already has explicit implicits, returns unchanged.
;; Otherwise, finds free type variables in the type signature and
;; prepends them as implicit (m0) parameters of type Type (level inferred).
(define (infer-auto-implicits form)
  (match form
    [(surf-defn name type-ast param-names body-ast loc)
     (cond
       ;; Already has explicit {A B} — skip
       [(has-leading-implicits? type-ast param-names) form]
       [else
        (define all-vars (collect-surf-vars type-ast))
        ;; Filter out: param names, known names
        (define free-vars
          (filter (lambda (v)
                    (and (not (memq v param-names))
                         (not (known-name? v))))
                  all-vars))
        (cond
          [(null? free-vars) form]
          [else
           ;; Build implicit binders
           (define implicit-binders
             (map (lambda (v) (binder-info v 'm0 (surf-type #f loc)))
                  free-vars))
           ;; Prepend Pi binders to type-ast
           (define new-type-ast
             (foldr (lambda (bnd rest) (surf-pi bnd rest loc))
                    type-ast
                    implicit-binders))
           ;; Prepend names to param-names
           (define new-param-names (append free-vars param-names))
           (surf-defn name new-type-ast new-param-names body-ast loc)])])]
    [_ form]))

;; ========================================
;; Extract Pi binders from a surface type AST
;; ========================================
;; Walks the type to collect the chain of Pi/arrow binders.
;; Returns a list of binder-info structs.
(define (extract-pi-binders type-ast)
  (match type-ast
    [(surf-pi binder body _loc)
     (cons binder (extract-pi-binders body))]
    [(surf-arrow _ domain codomain _loc)
     ;; Non-dependent arrow: generate anonymous binder
     (cons (binder-info '_ 'mw domain)
           (extract-pi-binders codomain))]
    [_ '()]))

;; ========================================
;; Desugar defn → def + nested fn
;; ========================================
(define (desugar-defn form)
  (match form
    [(surf-defn name type-ast param-names body-ast loc)
     (define all-binders (extract-pi-binders type-ast))
     (define n-params (length param-names))
     (define n-binders (length all-binders))
     (cond
       [(> n-params n-binders)
        (prologos-error
         loc
         (format "defn ~a: parameter list has ~a names but type has only ~a binders"
                 name n-params n-binders))]
       [else
        ;; Take only as many binders as there are parameter names.
        ;; The remaining Pi binders are part of the return type
        ;; (e.g. defn f [x : Nat] <Nat -> Nat> ... has return type Nat -> Nat).
        (define binders (take all-binders n-params))
        (define named-binders
          (for/list ([pname (in-list param-names)]
                     [bnd (in-list binders)])
            (binder-info pname (binder-info-mult bnd) (binder-info-type bnd))))
        (define nested-lam
          (foldr (lambda (bnd inner)
                   (surf-lam bnd inner loc))
                 body-ast
                 named-binders))
        ;; Register user-facing param names for bound-arg display in narrowing/solve
        (register-defn-param-names! name param-names)
        (surf-def name type-ast nested-lam loc)])]))

;; ========================================
;; Desugar the-fn → the + nested fn
;; ========================================
;; (the-fn type [params...] body) → (the type (fn (p1:T1) (fn (p2:T2) ... body)))
(define (desugar-the-fn form)
  (match form
    [(surf-the-fn type-ast param-names body-ast loc)
     (define all-binders (extract-pi-binders type-ast))
     (define n-params (length param-names))
     (define n-binders (length all-binders))
     (cond
       [(> n-params n-binders)
        (prologos-error
         loc
         (format "the-fn: parameter list has ~a names but type has only ~a binders"
                 n-params n-binders))]
       [else
        ;; Take only as many binders as there are parameter names
        (define binders (take all-binders n-params))
        (define named-binders
          (for/list ([pname (in-list param-names)]
                     [bnd (in-list binders)])
            (binder-info pname (binder-info-mult bnd) (binder-info-type bnd))))
        (define nested-lam
          (foldr (lambda (bnd inner)
                   (surf-lam bnd inner loc))
                 body-ast
                 named-binders))
        (surf-ann type-ast nested-lam loc)])]))

;; ========================================
;; Expand expressions (walk sub-expressions for the-fn)
;; ========================================
(define (expand-expression surf)
  (match surf
    ;; the-fn — desugar
    [(surf-the-fn _ _ _ _)
     (define result (desugar-the-fn surf))
     (if (prologos-error? result) result (expand-expression result))]
    ;; Walk sub-expressions
    ;; Placeholder desugaring: _ in app args → anonymous lambda
    ;; (add 1 _) → (fn [$_0] (add 1 $_0))
    ;; (clamp _ 100 _) → (fn [$_0] (fn [$_1] (clamp $_0 100 $_1)))
    ;; Positional placeholders: _N (1-based) control lambda ordering
    ;; (f _2 zero _1) → (fn [$_1] (fn [$_2] (f $_2 zero $_1)))
    [(surf-app fn args loc)
     (define has-plain (ormap surf-hole? args))
     (define has-numbered (ormap surf-numbered-hole? args))
     (cond
       ;; Error: cannot mix plain _ and numbered _N
       [(and has-plain has-numbered)
        (error 'expand-expression
               "cannot mix plain _ and numbered _N placeholders in the same application")]
       ;; Plain holes: existing sequential behavior
       [has-plain
        (let* ([hole-count (count surf-hole? args)]
               [names (for/list ([i (in-range hole-count)])
                        (string->symbol (format "$_~a" i)))]
               [new-args (let loop ([as args] [ns names])
                           (cond
                             [(null? as) '()]
                             [(surf-hole? (car as))
                              (cons (surf-var (car ns) loc) (loop (cdr as) (cdr ns)))]
                             [else (cons (car as) (loop (cdr as) ns))]))]
               [new-app (surf-app fn new-args loc)]
               [result (foldr (lambda (name inner)
                                (surf-lam (binder-info name #f (surf-hole loc)) inner loc))
                              new-app names)])
          (expand-expression result))]
       ;; Numbered holes: positional placeholders with explicit ordering
       [has-numbered
        (let* (;; Collect all indices
               [indices (for/list ([a (in-list args)]
                                   #:when (surf-numbered-hole? a))
                          (surf-numbered-hole-index a))]
               ;; Check for duplicates
               [_ (unless (= (length indices) (length (remove-duplicates indices)))
                    (error 'expand-expression
                           "duplicate numbered placeholder indices: ~a" indices))]
               ;; Sort indices ascending — smallest index = outermost lambda
               [sorted-indices (sort indices <)]
               ;; Create name map: index → $_N symbol
               [name-map (for/hasheq ([idx (in-list sorted-indices)])
                           (values idx (string->symbol (format "$_~a" idx))))]
               ;; Replace each numbered hole with its corresponding surf-var
               [new-args (for/list ([a (in-list args)])
                           (if (surf-numbered-hole? a)
                               (surf-var (hash-ref name-map (surf-numbered-hole-index a)) loc)
                               a))]
               [new-app (surf-app fn new-args loc)]
               ;; Wrap in nested lambdas ordered by sorted indices
               ;; sorted ascending: _1 outermost, _2 next, etc.
               [result (foldr (lambda (idx inner)
                                (surf-lam (binder-info (hash-ref name-map idx)
                                                       #f (surf-hole loc))
                                          inner loc))
                              new-app sorted-indices)])
          (expand-expression result))]
       ;; No holes: just recurse on sub-expressions
       [else
        (surf-app (expand-expression fn) (map expand-expression args) loc)])]
    [(surf-lam binder body loc)
     (surf-lam binder (expand-expression body) loc)]
    [(surf-ann type term loc)
     (surf-ann (expand-expression type) (expand-expression term) loc)]
    [(surf-pair e1 e2 loc)
     (surf-pair (expand-expression e1) (expand-expression e2) loc)]
    [(surf-fst e loc)
     (surf-fst (expand-expression e) loc)]
    [(surf-snd e loc)
     (surf-snd (expand-expression e) loc)]
    [(surf-suc e loc)
     (surf-suc (expand-expression e) loc)]
    [(surf-pi binder body loc)
     (surf-pi binder (expand-expression body) loc)]
    [(surf-arrow m dom cod loc)
     (surf-arrow m (expand-expression dom) (expand-expression cod) loc)]
    [(surf-sigma binder body loc)
     (surf-sigma binder (expand-expression body) loc)]
    [(surf-eq type lhs rhs loc)
     (surf-eq (expand-expression type) (expand-expression lhs) (expand-expression rhs) loc)]
    [(surf-natrec mot base step target loc)
     (surf-natrec (expand-expression mot) (expand-expression base)
                  (expand-expression step) (expand-expression target) loc)]
    [(surf-boolrec mot tc fc target loc)
     (surf-boolrec (expand-expression mot) (expand-expression tc)
                   (expand-expression fc) (expand-expression target) loc)]
    [(surf-J mot base left right proof loc)
     (surf-J (expand-expression mot) (expand-expression base)
             (expand-expression left) (expand-expression right)
             (expand-expression proof) loc)]
    ;; Rich pattern match — compile via compile-match-tree, then re-expand
    [(surf-match-patterns scrutinee arms loc)
     (define compiled (compile-match-expression scrutinee arms loc))
     (expand-expression compiled)]
    ;; Reduce — walk scrutinee and arm bodies
    [(surf-reduce scrutinee arms loc)
     (surf-reduce (expand-expression scrutinee)
                  (map (lambda (arm)
                         (reduce-arm (reduce-arm-ctor-name arm)
                                     (reduce-arm-bindings arm)
                                     (expand-expression (reduce-arm-body arm))
                                     (reduce-arm-srcloc arm)))
                       arms)
                  loc)]
    ;; Narrowing expression — expand sub-expressions (Phase 1e)
    [(surf-narrow lhs rhs vars loc constraint-map)
     (surf-narrow (expand-expression lhs) (expand-expression rhs) vars loc constraint-map)]
    ;; Constraint forms — expand sub-expressions (Phase 3c)
    [(surf-all-different vars loc)
     (surf-all-different (map expand-expression vars) loc)]
    [(surf-element index list-expr var loc)
     (surf-element (expand-expression index) (expand-expression list-expr)
                   (expand-expression var) loc)]
    [(surf-cumulative tasks capacity loc)
     (surf-cumulative (expand-expression tasks) (expand-expression capacity) loc)]
    [(surf-minimize cost-var loc)
     (surf-minimize (expand-expression cost-var) loc)]
    ;; Leaf forms — pass through
    [_ surf]))

;; ========================================
;; Pattern-based defn clause compilation
;; ========================================
;; Compiles pattern-based defn clauses into a single surf-def
;; with a match-based body. Used by expand-defn-multi when
;; multiple clauses share the same arity with pattern syntax.

;; Check if a pattern is a variable or wildcard (non-dispatching)
(define (pattern-is-variable? pat)
  (and (pat-atom? pat)
       (memq (pat-atom-kind pat) '(var wildcard))))

;; Normalize a numeric pattern to nested constructor pattern
;; 0 → (pat-compound 'zero () loc)
;; 1 → (pat-compound 'suc [(pat-compound 'zero () loc)] loc)
;; n → suc^n(zero)
(define (normalize-numeric-pattern pat)
  (define val (pat-atom-value pat))
  (define loc (pat-atom-srcloc pat))
  (let loop ([n val])
    (if (= n 0)
        (pat-compound 'zero '() loc)
        (pat-compound 'suc (list (loop (- n 1))) loc))))

;; Normalize a pattern recursively:
;; - var that's a known constructor → compound (ctor disambiguation)
;; - numeric → nested zero/suc compound
;; - head-tail → nested cons compound
;; - compound sub-patterns normalized recursively
(define (normalize-pattern pat)
  (cond
    ;; Variable that might actually be a constructor
    [(and (pat-atom? pat) (eq? (pat-atom-kind pat) 'var))
     (define name (pat-atom-name pat))
     (define meta (lookup-ctor name))
     (cond
       ;; Known nullary constructor → convert to compound
       [(and meta (null? (ctor-meta-field-types meta)))
        (pat-compound name '() (pat-atom-srcloc pat))]
       ;; Known constructor with fields used without brackets — treat as
       ;; nullary match (type checker will catch arity mismatch if wrong)
       [meta
        (pat-compound name '() (pat-atom-srcloc pat))]
       ;; Not a constructor → stays as variable
       [else pat])]
    ;; Int literal → leave as-is (compiled to equality dispatch, not constructor dispatch)
    [(and (pat-atom? pat) (eq? (pat-atom-kind pat) 'int-lit))
     pat]
    ;; Numeric (Nat literal) → nested zero/suc
    [(and (pat-atom? pat) (eq? (pat-atom-kind pat) 'numeric))
     (normalize-numeric-pattern pat)]
    ;; Compound → normalize sub-patterns
    [(pat-compound? pat)
     (pat-compound (pat-compound-ctor-name pat)
                   (map normalize-pattern (pat-compound-args pat))
                   (pat-compound-srcloc pat))]
    ;; Head-tail → nested cons
    [(pat-head-tail? pat)
     (define heads (pat-head-tail-heads pat))
     (define tail (pat-head-tail-tail pat))
     (define loc (pat-head-tail-srcloc pat))
     (let loop ([hs heads])
       (cond
         [(null? hs) (normalize-pattern tail)]
         [else
          (pat-compound 'cons
                        (list (normalize-pattern (car hs))
                              (if (null? (cdr hs))
                                  (normalize-pattern tail)
                                  (loop (cdr hs))))
                        loc)]))]
    [else pat]))

;; Find the first column index with a non-variable pattern.
;; Returns column index or #f if all patterns are variables.
(define (find-dispatch-column rows)
  (define n-cols (length (caar rows)))
  (for/or ([col (in-range n-cols)])
    (and (for/or ([row (in-list rows)])
           (not (pattern-is-variable? (list-ref (car row) col))))
         col)))

;; Find the type being matched from constructor patterns in a column.
;; Returns type-name symbol or #f.
(define (find-type-from-column rows col)
  (for/or ([row (in-list rows)])
    (define pat (list-ref (car row) col))
    (and (pat-compound? pat)
         (let ([meta (lookup-ctor (pat-compound-ctor-name pat))])
           (and meta (ctor-meta-type-name meta))))))

;; Create a let-binding expression: let name := value in body
;; Implemented as ((fn (name : _) body) value)
(define (make-let-binding name value body loc)
  (surf-app
   (surf-lam (binder-info name 'mw (surf-hole loc)) body loc)
   (list value)
   loc))

;; Wrap body with let bindings for variable patterns.
;; For each variable pattern at position i, bind pattern-name to param-name.
;; Wildcards are skipped (no binding needed).
(define (wrap-variable-bindings patterns param-names body loc)
  ;; Process in reverse order so outermost let is first param
  (for/fold ([b body])
            ([pat (in-list (reverse patterns))]
             [pname (in-list (reverse param-names))])
    (cond
      [(and (pat-atom? pat) (eq? (pat-atom-kind pat) 'var))
       (define vname (pat-atom-name pat))
       (if (eq? vname pname) b
           (make-let-binding vname (surf-var pname loc) b loc))]
      [else b])))

;; Specialize rows for a constructor at a given column.
;; For each row:
;;   - compound matching ctor → replace column with sub-patterns
;;   - variable → replace column with fresh wildcards + bind variable
;;   - different ctor → skip
;; Returns list of (list new-patterns new-body), preserving order.
(define (specialize-rows rows col ctor n-fields param-names loc)
  (define param-at-col (list-ref param-names col))
  (for/fold ([result '()])
            ([row (in-list (reverse rows))])
    (define pats (car row))
    (define guard (cadr row))
    (define body (caddr row))
    (define pat-at-col (list-ref pats col))
    (cond
      ;; Compound pattern matching this ctor
      [(and (pat-compound? pat-at-col)
            (eq? (pat-compound-ctor-name pat-at-col) ctor))
       (define sub-pats (pat-compound-args pat-at-col))
       (define new-pats
         (append (take pats col) sub-pats (drop pats (+ col 1))))
       (cons (list new-pats guard body) result)]
      ;; Variable — matches any ctor, bind to original param
      [(and (pat-atom? pat-at-col) (eq? (pat-atom-kind pat-at-col) 'var))
       (define vname (pat-atom-name pat-at-col))
       (define fresh-vars
         (for/list ([_ (in-range n-fields)])
           (pat-atom 'wildcard '_ #f loc)))
       (define new-pats
         (append (take pats col) fresh-vars (drop pats (+ col 1))))
       (define new-body
         (make-let-binding vname (surf-var param-at-col loc) body loc))
       (cons (list new-pats guard new-body) result)]
      ;; Wildcard — matches any ctor, no binding
      [(and (pat-atom? pat-at-col) (eq? (pat-atom-kind pat-at-col) 'wildcard))
       (define fresh-vars
         (for/list ([_ (in-range n-fields)])
           (pat-atom 'wildcard '_ #f loc)))
       (define new-pats
         (append (take pats col) fresh-vars (drop pats (+ col 1))))
       (cons (list new-pats guard body) result)]
      ;; Different ctor — skip this row
      [else result])))

;; Check if a column contains any Int literal patterns.
(define (has-int-literal-column? rows col)
  (for/or ([row (in-list rows)])
    (define pat (list-ref (car row) col))
    (and (pat-atom? pat) (eq? (pat-atom-kind pat) 'int-lit))))

;; Compile Int literal dispatch via equality checks.
;; Produces nested surf-boolrec: (if (int-eq scrutinee lit) body (if ...))
;; Variable/wildcard rows become the default fallback.
(define (compile-int-dispatch rows col param-names loc)
  (define scrutinee-name (list-ref param-names col))
  (define scrutinee-ref (surf-var scrutinee-name loc))
  ;; Separate into int-lit rows and default (var/wildcard) rows.
  ;; Process in order: each int-lit row becomes an equality check,
  ;; variable/wildcard rows become the default branch.
  (define-values (int-rows default-rows)
    (partition (lambda (row)
                 (define pat (list-ref (car row) col))
                 (and (pat-atom? pat) (eq? (pat-atom-kind pat) 'int-lit)))
               rows))
  ;; Build the default branch from variable/wildcard rows
  (define default-branch
    (if (null? default-rows)
        (surf-typed-hole '__match-fail loc)
        ;; Remove the dispatch column from default rows (it matched as var/wildcard)
        ;; and compile the remaining columns
        (let* ([adjusted-rows
                (for/list ([row (in-list default-rows)])
                  (define pats (car row))
                  (define guard (cadr row))
                  (define body (caddr row))
                  (define pat-at-col (list-ref pats col))
                  (define new-pats
                    (append (take pats col) (drop pats (+ col 1))))
                  ;; Keep the original pattern at dispatch col for variable binding
                  ;; (handled by compile-match-tree base case or here for single-col)
                  (define new-body
                    (cond
                      [(and (pat-atom? pat-at-col) (eq? (pat-atom-kind pat-at-col) 'var))
                       (make-let-binding (pat-atom-name pat-at-col) scrutinee-ref body loc)]
                      [else body]))
                  ;; Guard may reference pattern variables — wrap guard too
                  (define new-guard
                    (cond
                      [(not guard) #f]
                      [(and (pat-atom? pat-at-col) (eq? (pat-atom-kind pat-at-col) 'var))
                       (make-let-binding (pat-atom-name pat-at-col) scrutinee-ref guard loc)]
                      [else guard]))
                  (list new-pats new-guard new-body))]
               [new-params
                (append (take param-names col) (drop param-names (+ col 1)))])
          (if (null? (caar adjusted-rows))
              ;; Dispatch column was the only one — return first default body/guard
              (let ([guard (cadr (car adjusted-rows))]
                    [body (caddr (car adjusted-rows))])
                (if guard
                    (let ([motive (surf-ann
                                  (surf-arrow #f (surf-bool-type loc) (surf-type 0 loc) loc)
                                  (surf-lam (binder-info '_ 'mw (surf-bool-type loc))
                                            (surf-hole loc) loc)
                                  loc)])
                      ;; Guard and body already have variable bindings applied above
                      (surf-boolrec motive body
                                    (compile-match-tree (cdr adjusted-rows) '() loc)
                                    guard loc))
                    body))
              ;; More columns to dispatch — recurse
              (compile-match-tree adjusted-rows new-params loc)))))
  ;; Build nested if chain from int-lit rows (right fold, order preserved)
  (define boolrec-motive
    (surf-ann (surf-arrow #f (surf-bool-type loc) (surf-type 0 loc) loc)
              (surf-lam (binder-info '_ 'mw (surf-bool-type loc))
                        (surf-hole loc) loc)
              loc))
  (foldr (lambda (row rest)
           (define pat (list-ref (car row) col))
           (define lit-value (pat-atom-value pat))
           (define guard (cadr row))
           (define body (caddr row))
           ;; Remove the int-lit column from remaining patterns
           (define remaining-pats
             (append (take (car row) col) (drop (car row) (+ col 1))))
           (define new-params
             (append (take param-names col) (drop param-names (+ col 1))))
           ;; If there are remaining columns with non-trivial patterns, recurse
           (define resolved-body
             (if (and (pair? remaining-pats)
                      (for/or ([p (in-list remaining-pats)])
                        (not (pattern-is-variable? p))))
                 (compile-match-tree (list (list remaining-pats guard body)) new-params loc)
                 ;; All remaining are variables — just bind and return body
                 (if (null? remaining-pats)
                     body
                     (wrap-variable-bindings remaining-pats new-params body loc))))
           ;; Apply guard if present: wrap body with (if guard body rest)
           (define guarded-body
             (if guard
                 (surf-boolrec boolrec-motive resolved-body rest guard loc)
                 resolved-body))
           ;; Equality check: if (int-eq scrutinee lit) then guarded-body else rest
           (surf-boolrec boolrec-motive
                         guarded-body
                         rest
                         (surf-int-eq scrutinee-ref (surf-int-lit lit-value loc) loc)
                         loc))
         default-branch
         int-rows))

;; Compile a match tree from pattern rows.
;; rows: list of (list patterns guard body) where patterns is a list of normalized patterns.
;; param-names: symbols for the scrutinee at each position.
;; Returns a surface expression (surf-reduce, surf-var, surf-app, etc.)
(define (compile-match-tree rows param-names loc)
  (cond
    ;; No rows — unreachable branch (incomplete pattern match)
    [(null? rows)
     (surf-typed-hole '__match-fail loc)]
    ;; First row is all variables → base case: bind and return body
    [(for/and ([pat (in-list (caar rows))])
       (pattern-is-variable? pat))
     (define row-guard (cadr (car rows)))
     (define row-body (caddr (car rows)))
     (if row-guard
         ;; Guard: bind variables, then check guard; if guard fails, try remaining rows.
         ;; The guard expression may reference pattern-bound variables, so both
         ;; guard and body must be inside the variable binding scope.
         ;; Use the same annotated constant motive shorthand as the parser's
         ;; boolrec handler: (the (-> Bool (Type 0)) (fn [_ <Bool>] _))
         (let* ([guard-motive
                 (surf-ann (surf-arrow #f (surf-bool-type loc) (surf-type 0 loc) loc)
                           (surf-lam (binder-info '_ 'mw (surf-bool-type loc))
                                     (surf-hole loc) loc)
                           loc)]
                [guard-check
                 (surf-boolrec guard-motive
                               row-body
                               (compile-match-tree (cdr rows) param-names loc)
                               row-guard
                               loc)])
           (wrap-variable-bindings (caar rows) param-names guard-check loc))
         ;; No guard: just bind and return body
         (wrap-variable-bindings (caar rows) param-names row-body loc))]
    ;; Dispatch: check if column has Int literal patterns
    [else
     (define col (find-dispatch-column rows))
     (define scrutinee-name (list-ref param-names col))
     (cond
       ;; Int literal dispatch — equality-based (not constructor-based)
       [(has-int-literal-column? rows col)
        (compile-int-dispatch rows col param-names loc)]
       ;; Constructor dispatch — standard algebraic type matching
       [else
        ;; Determine type from ctor patterns in this column
        (define type-name (find-type-from-column rows col))
        ;; Get all constructors (in declaration order if type known)
        (define all-ctors
          (if type-name
              (or (lookup-type-ctors type-name) '())
              ;; Fallback: collect constructors from rows (order of first appearance)
              (remove-duplicates
               (filter-map
                (lambda (row)
                  (define pat (list-ref (car row) col))
                  (and (pat-compound? pat) (pat-compound-ctor-name pat)))
                rows))))
        ;; Build reduce-arms for each constructor
        (define arms
          (for/list ([ctor (in-list all-ctors)])
            (define meta (lookup-ctor ctor))
            (define n-fields
              (if meta (length (ctor-meta-field-types meta)) 0))
            ;; Generate fresh field binding names
            (define field-names
              (for/list ([i (in-range n-fields)])
                (string->symbol (format "__~a_~a" ctor i))))
            ;; Specialize rows for this constructor
            (define specialized
              (specialize-rows rows col ctor n-fields param-names loc))
            ;; New param names: replace dispatch column with field names
            (define new-params
              (append (take param-names col)
                      field-names
                      (drop param-names (+ col 1))))
            ;; Recurse
            (define arm-body
              (compile-match-tree specialized new-params loc))
            (reduce-arm ctor field-names arm-body loc)))
        (surf-reduce (surf-var scrutinee-name loc) arms loc)])]))

;; Check if a normalized pattern is "simple flat": a constructor with all
;; variable or wildcard sub-patterns. These can be compiled directly to
;; reduce-arm without the full compile-match-tree pipeline. Top-level
;; variable/wildcard patterns are NOT simple-flat because they need
;; let-bindings from compile-match-tree to bind the scrutinee.
(define (pattern-is-simple-flat? pat)
  (and (pat-compound? pat)
       (for/and ([sub (in-list (pat-compound-args pat))])
         (and (pat-atom? sub) (memq (pat-atom-kind sub) '(var wildcard))))))

;; Compile a rich pattern match expression into nested surf-reduce.
;; Used by expand-expression to handle surf-match-patterns nodes.
;; scrutinee: already-parsed surface expression (NOT yet expanded)
;; arms: list of match-pattern-arm (each has a single-element patterns list)
;; Returns un-expanded surface AST (caller should re-expand).
;; Row format: (list patterns guard body) where guard is #f or surf expr.
(define (compile-match-expression scrutinee arms loc)
  ;; Fast path: if all arms are simple flat constructor patterns with no guards,
  ;; directly produce surf-reduce (like the old parse-reduce-arm did).
  ;; This avoids the compile-match-tree overhead of extra let-bindings and
  ;; re-expansion, which matters because prelude loading processes hundreds of
  ;; match expressions.
  (define normalized-arms
    (for/list ([arm (in-list arms)])
      (list (map normalize-pattern (match-pattern-arm-patterns arm))
            (match-pattern-arm-guard arm)
            (match-pattern-arm-body arm))))
  (define simple?
    (for/and ([row (in-list normalized-arms)])
      (and (not (cadr row))                     ;; no guard
           (= (length (car row)) 1)             ;; single pattern
           (pattern-is-simple-flat? (caar row))  ;; flat ctor or variable
           )))
  (if simple?
      ;; Fast path: directly produce surf-reduce (all arms are flat constructors)
      (let ([reduce-arms
             (for/list ([row (in-list normalized-arms)])
               (define pat (caar row))
               (define body (caddr row))
               (reduce-arm (pat-compound-ctor-name pat)
                           (map pat-atom-name (pat-compound-args pat))
                           body loc))])
        (surf-reduce scrutinee reduce-arms loc))
      ;; Full path: compile via compile-match-tree for complex patterns
      (let* ([scrutinee-name (gensym '__scrutinee)]
             [match-body (compile-match-tree normalized-arms (list scrutinee-name) loc)])
        (make-let-binding scrutinee-name scrutinee match-body loc))))

;; Convert a type name symbol to its surface syntax representation.
;; Built-in types (Nat, Bool, Unit) have dedicated surface syntax structs;
;; user-defined types use surf-var (looked up in global env at elaboration).
(define (type-name->surf-type type-name loc)
  (case type-name
    [(Nat)  (surf-nat-type loc)]
    [(Bool) (surf-bool-type loc)]
    [(Unit) (surf-unit-type loc)]
    [else   (surf-var type-name loc)]))

;; Build a type annotation for the pattern group from constructor metadata.
;; For each argument position, if constructor patterns are present, infer the
;; argument type from the constructor registry. Otherwise, use a hole.
;; Returns a surf-pi chain: T1 -> T2 -> ... -> _ (return type is always a hole).
(define (build-pattern-group-type param-names rows loc)
  (define arg-types
    (for/list ([i (in-range (length param-names))])
      ;; Look for a constructor pattern in this column to determine the type
      (define type-info
        (for/or ([row (in-list rows)])
          (define pat (list-ref (car row) i))
          (and (pat-compound? pat)
               (let ([meta (lookup-ctor (pat-compound-ctor-name pat))])
                 (and meta (list (ctor-meta-type-name meta)
                                (ctor-meta-params meta)))))))
      (cond
        [type-info
         (define type-name (car type-info))
         (define params (cadr type-info))
         (if (null? params)
             ;; Nullary type (Nat, Bool, Unit)
             (type-name->surf-type type-name loc)
             ;; Parameterized type (List A, Option A) → apply to hole params
             (surf-app (type-name->surf-type type-name loc)
                       (for/list ([_ (in-list params)])
                         (surf-hole loc))
                       loc))]
        ;; No constructor info → hole (type will be inferred)
        [else (surf-hole loc)])))
  ;; Build Pi chain
  (foldr (lambda (pname arg-type inner)
           (surf-pi (binder-info pname 'mw arg-type) inner loc))
         (surf-hole loc)  ;; Return type is a hole
         param-names
         arg-types))

;; Convert a raw datum (symbol or application list) to a surface type AST.
;; Handles built-in type names and type constructor applications.
;; Returns a surface type node, or #f if the datum is unsupported.
(define (datum->surf-type datum loc)
  (cond
    [(symbol? datum)
     (case datum
       [(Nat)    (surf-nat-type loc)]
       [(Bool)   (surf-bool-type loc)]
       [(Unit)   (surf-unit-type loc)]
       [(Int)    (surf-int-type loc)]
       [(Rat)    (surf-rat-type loc)]
       [(Char)   (surf-char-type loc)]
       [(String) (surf-string-type loc)]
       [(Type)   (surf-var 'Type loc)]
       [(Posit8)  (surf-posit8-type loc)]
       [(Posit16) (surf-posit16-type loc)]
       [(Posit32) (surf-posit32-type loc)]
       [(Posit64) (surf-posit64-type loc)]
       [(Symbol) (surf-symbol-type loc)]
       [(Keyword) (surf-keyword-type loc)]
       [else (surf-var datum loc)])]
    [(pair? datum)
     ;; Application: (Constructor Arg1 Arg2 ...)
     (define head (datum->surf-type (car datum) loc))
     (define args (map (lambda (a) (datum->surf-type a loc)) (cdr datum)))
     (cond
       [(not head) #f]
       [(ormap not args) #f]
       [(null? args) head]  ;; single-element list → just the head
       [else (surf-app head args loc)])]
    [else #f]))

;; Convert spec type tokens (e.g., (Nat -> Nat -> Bool)) to a surface type AST.
;; Only handles "simple" specs — no nested arrow types in param positions.
;; Returns a surface type (surf-arrow chain), or #f on failure.
(define (spec-tokens->surf-type tokens loc)
  ;; Guard: reject tokens with nested arrows in sublists (higher-order param types).
  ;; These require infix type parsing which isn't available at this stage.
  (define (simple-tokens? ts)
    (for/and ([t (in-list ts)])
      (cond
        [(symbol? t) #t]
        [(pair? t) (not (ormap arrow-symbol-datum? t))]
        [else #t])))
  (cond
    [(not (simple-tokens? tokens)) #f]
    [else
     (define-values (segments mults) (split-on-arrow-datum/mult tokens))
     (cond
       [(= (length segments) 1)
        ;; No arrows — just a return type (unusual for functions)
        (define seg (car segments))
        (define datum (if (= (length seg) 1) (car seg) seg))
        (datum->surf-type datum loc)]
       [else
        ;; Has arrows: flatten params, build arrow chain
        (define non-last (drop-right segments 1))
        (define last-seg (last segments))
        ;; Flatten: each atom in a segment is a separate param type.
        ;; Each param gets the multiplicity of the arrow following its segment.
        (define flat-params+mults
          (apply append
                 (for/list ([seg (in-list non-last)]
                            [mult (in-list mults)])
                   (map (lambda (p) (cons p mult)) seg))))
        ;; Build codomain
        (define codomain-datum
          (if (= (length last-seg) 1) (car last-seg) last-seg))
        (define codomain (datum->surf-type codomain-datum loc))
        (cond
          [(not codomain) #f]
          [else
           ;; Build right-associated arrow chain: T1 -> T2 -> ... -> Ret
           (define result
             (foldr (lambda (pm inner)
                      (cond
                        [(not inner) #f]
                        [else
                         (define p (car pm))
                         (define m (cdr pm))
                         (define dom (datum->surf-type p loc))
                         (cond
                           [(not dom) #f]
                           [else (surf-arrow m dom inner loc)])]))
                    codomain
                    flat-params+mults))
           result])])]))

;; Look up the spec for a pattern group and convert to surface type.
;; Only uses simple specs (no implicit binders, no where-constraints, single-arity).
;; arity: expected number of parameters (for validation).
;; Returns a surface type or #f (caller falls back to build-pattern-group-type).
(define (lookup-spec-type-for-patterns spec-name arity loc)
  (define spec (and spec-name (lookup-spec spec-name)))
  (cond
    [(not spec) #f]
    ;; Skip complex specs: implicits, constraints, multi-arity
    [(spec-entry-multi? spec) #f]
    [(and (spec-entry-implicit-binders spec)
          (not (null? (spec-entry-implicit-binders spec)))) #f]
    [(and (spec-entry-where-constraints spec)
          (not (null? (spec-entry-where-constraints spec)))) #f]
    [else
     ;; spec-entry-type-datums is (list type-tokens) for single-arity
     ;; Strip leading colon if present (WS reader includes ':' from 'spec foo : T')
     (define raw-tokens (car (spec-entry-type-datums spec)))
     (define type-tokens
       (if (and (pair? raw-tokens) (eq? (car raw-tokens) ':))
           (cdr raw-tokens)
           raw-tokens))
     ;; Validate arity: count domain segments
     (define-values (segments _mults) (split-on-arrow-datum/mult type-tokens))
     (define non-last (if (> (length segments) 1) (drop-right segments 1) '()))
     (define n-params (apply + (map length non-last)))
     (cond
       [(not (= n-params arity)) #f]  ;; arity mismatch — skip
       [else (spec-tokens->surf-type type-tokens loc)])]))

;; Compile a group of pattern clauses (all same arity) into a single surf-def.
;; name: the function name (symbol), possibly internal name like name::arity.
;; clauses: list of defn-pattern-clause, all same arity.
;; loc: source location.
;; spec-name: original function name (for spec lookup), or #f.
;; Returns a surf-def with inferred type (built from constructor metadata or spec).
(define (compile-pattern-group name clauses loc [spec-name #f])
  (define arity
    (length (defn-pattern-clause-patterns (car clauses))))
  ;; Generate param names. If all clauses have all-variable first patterns,
  ;; use variable names from the first clause to avoid redundant let-bindings.
  ;; This is critical for guards: fn __arg0 . (let n = __arg0 in ...) creates
  ;; an extra indirection that triggers QTT false positives.
  (define param-names
    (let* ([all-var? (for/and ([clause (in-list clauses)])
                       (for/and ([pat (in-list (defn-pattern-clause-patterns clause))])
                         (pattern-is-variable? pat)))]
           [first-pats (defn-pattern-clause-patterns (car clauses))])
      (if all-var?
          (for/list ([pat (in-list first-pats)])
            (if (and (pat-atom? pat) (eq? (pat-atom-kind pat) 'var))
                (pat-atom-name pat)
                (gensym '__wild)))
          (for/list ([i (in-range arity)])
            (string->symbol (format "__arg~a" i))))))
  ;; Normalize all patterns and build rows
  ;; Row format: (list patterns guard body)
  (define rows
    (for/list ([clause (in-list clauses)])
      (list (map normalize-pattern (defn-pattern-clause-patterns clause))
            (defn-pattern-clause-guard clause)
            (defn-pattern-clause-body clause))))
  ;; Try spec type first, fall back to inferred type from constructor metadata
  (define spec-type
    (and (> arity 0) (lookup-spec-type-for-patterns spec-name arity loc)))
  (cond
    ;; Zero-arity: just use first body
    [(= arity 0)
     (surf-def name #f (caddr (car rows)) loc)]
    ;; Single clause, all variables, no guard → optimize: use variable names as params
    [(and (= (length rows) 1)
          (not (cadr (car rows)))  ;; no guard
          (for/and ([pat (in-list (caar rows))])
            (pattern-is-variable? pat)))
     (define var-names
       (for/list ([pat (in-list (caar rows))])
         (if (eq? (pat-atom-kind pat) 'wildcard)
             (gensym '__wild)
             (pat-atom-name pat))))
     (define body (caddr (car rows)))
     (define type (or spec-type (build-pattern-group-type var-names rows loc)))
     (define nested-lam
       (foldr (lambda (vn inner)
                (surf-lam (binder-info vn 'mw (surf-hole loc)) inner loc))
              body var-names))
     ;; Register user-facing param names for bound-arg display (don't overwrite parser-provided names)
     (unless (lookup-defn-param-names name)
       (register-defn-param-names! name var-names))
     (surf-def name type nested-lam loc)]
    ;; General case: compile match tree
    [else
     (define type (or spec-type (build-pattern-group-type param-names rows loc)))
     (define body (compile-match-tree rows param-names loc))
     (define nested-lam
       (foldr (lambda (pn inner)
                (surf-lam (binder-info pn 'mw (surf-hole loc)) inner loc))
              body param-names))
     ;; Register param names for bound-arg display (don't overwrite parser-provided names)
     (unless (lookup-defn-param-names name)
       (register-defn-param-names! name param-names))
     (surf-def name type nested-lam loc)]))

;; ========================================
;; Expand multi-body defn → surf-def-group
;; ========================================
;; Clauses may be arity-based (defn-clause) or pattern-based
;; (defn-pattern-clause). They are grouped by arity. Within each
;; arity group, all clauses must be the same kind:
;;   - arity clauses → existing pipeline (one surf-def per clause)
;;   - pattern clauses → compiled to single surf-def with match body
(define (expand-defn-multi form)
  (match form
    [(surf-defn-multi name docstring clauses loc)
     ;; Compute arity for each clause (works for both kinds)
     (define (clause-arity c)
       (cond
         [(defn-clause? c) (length (defn-clause-param-names c))]
         [(defn-pattern-clause? c)
          (length (defn-pattern-clause-patterns c))]
         [else (error 'expand-defn-multi "unknown clause type: ~a" c)]))
     (define arities (map clause-arity clauses))

     ;; Group clauses by arity (preserving order within groups)
     (define arity-group-hash (make-hasheq))
     (for ([clause (in-list clauses)]
           [arity (in-list arities)])
       (hash-update! arity-group-hash arity
                     (lambda (lst) (append lst (list clause)))
                     '()))
     (define sorted-arities
       (sort (remove-duplicates arities) <))
     (define sorted-groups
       (for/list ([a (in-list sorted-arities)])
         (cons a (hash-ref arity-group-hash a))))

     ;; Validate: within each group, all same kind
     (define validation-error
       (for/or ([group (in-list sorted-groups)])
         (define arity (car group))
         (define group-clauses (cdr group))
         (define kinds
           (map (lambda (c)
                  (cond [(defn-clause? c) 'arity]
                        [(defn-pattern-clause? c) 'pattern]
                        [else 'unknown]))
                group-clauses))
         (define unique-kinds (remove-duplicates kinds))
         (if (> (length unique-kinds) 1)
             (prologos-error loc
               (format "defn ~a: arity ~a mixes arity and pattern clauses"
                       name arity))
             #f)))

     (cond
       [validation-error validation-error]

       ;; Optimization: single arity group, all pattern clauses →
       ;; return compiled surf-def directly (no arity dispatch needed)
       [(and (= (length sorted-groups) 1)
             (defn-pattern-clause? (cadr (car sorted-groups))))
        (define group-clauses (cdr (car sorted-groups)))
        (define compiled (compile-pattern-group name group-clauses loc name))
        (if (prologos-error? compiled) compiled
            (expand-top-level compiled))]

       ;; General case: multiple arity groups or arity-based clauses
       [else
        (let ()
          (define expanded-defs '())
          (define all-arities '())
          (define first-err #f)

          (for ([group (in-list sorted-groups)])
            #:break first-err
            (define arity (car group))
            (define group-clauses (cdr group))
            (define kind
              (if (defn-clause? (car group-clauses)) 'arity 'pattern))

            (cond
              ;; Pattern group → compile to single surf-def
              [(eq? kind 'pattern)
               (define internal-name
                 (string->symbol (format "~a::~a" name arity)))
               (define compiled
                 (compile-pattern-group internal-name group-clauses loc name))
               (cond
                 [(prologos-error? compiled)
                  (set! first-err compiled)]
                 [else
                  (define expanded (expand-top-level compiled))
                  (cond
                    [(prologos-error? expanded)
                     (set! first-err expanded)]
                    [else
                     (set! expanded-defs
                           (append expanded-defs (list expanded)))
                     (set! all-arities
                           (append all-arities (list arity)))])])]

              ;; Arity group → existing pipeline
              [else
               (when (> (length group-clauses) 1)
                 (set! first-err
                   (prologos-error loc
                     (format "defn ~a: multiple arity clauses with same arity ~a"
                             name arity))))
               (unless first-err
                 (define clause (car group-clauses))
                 (define internal-name
                   (string->symbol (format "~a::~a" name arity)))
                 (define as-defn
                   (surf-defn internal-name
                              (defn-clause-type clause)
                              (defn-clause-param-names clause)
                              (defn-clause-body clause)
                              (defn-clause-srcloc clause)))
                 (define with-implicits (infer-auto-implicits as-defn))
                 (define desugared (desugar-defn with-implicits))
                 (define expanded
                   (if (prologos-error? desugared)
                       desugared
                       (expand-top-level desugared)))
                 (cond
                   [(prologos-error? expanded)
                    (set! first-err expanded)]
                   [else
                    (set! expanded-defs
                          (append expanded-defs (list expanded)))
                    (set! all-arities
                          (append all-arities (list arity)))]))]))

          (cond
            [first-err first-err]
            [else
             (surf-def-group name expanded-defs all-arities
                             docstring loc)]))])]))

;; ========================================
;; Expand a top-level form (post-parse)
;; ========================================
;; Applies macro expansion, expression-level expansion, and implicit eval.
;; Returns a surf-def, surf-check, surf-eval, or surf-infer.
(define (expand-top-level surf [depth 0])
  (cond
    [(> depth 100)
     (prologos-error
      srcloc-unknown
      "Macro expansion depth limit exceeded (possible infinite loop)")]
    ;; Multi-body defn: expand each clause, produce surf-def-group
    [(surf-defn-multi? surf)
     (expand-defn-multi surf)]
    ;; surf-def-group: already expanded, pass through
    [(surf-def-group? surf) surf]
    ;; Built-in: defn desugaring (with auto-implicit inference)
    [(surf-defn? surf)
     (define with-implicits (infer-auto-implicits surf))
     (define result (desugar-defn with-implicits))
     (if (prologos-error? result)
         result
         (expand-top-level result (+ depth 1)))]
    ;; Already a top-level command — expand sub-expressions, then pass through
    [(surf-def? surf)
     (surf-def (surf-def-name surf)
               ;; Sprint 10: type may be #f for type-inferred defs
               (let ([ty (surf-def-type surf)])
                 (if ty (expand-expression ty) #f))
               (expand-expression (surf-def-body surf))
               (surf-def-srcloc surf))]
    [(surf-check? surf)
     (surf-check (expand-expression (surf-check-expr surf))
                 (expand-expression (surf-check-type surf))
                 (surf-check-srcloc surf))]
    [(surf-eval? surf)
     (surf-eval (expand-expression (surf-eval-expr surf))
                (surf-eval-srcloc surf))]
    [(surf-infer? surf)
     (surf-infer (expand-expression (surf-infer-expr surf))
                 (surf-infer-srcloc surf))]
    ;; Inspection commands — expand/parse pass through as-is,
    ;; elaborate expands its sub-expression (consistent with eval/infer)
    [(surf-expand? surf) surf]
    [(surf-expand-1? surf) surf]
    [(surf-expand-full? surf) surf]
    [(surf-parse? surf) surf]
    [(surf-elaborate? surf)
     (surf-elaborate (expand-expression (surf-elaborate-expr surf))
                     (surf-elaborate-srcloc surf))]
    ;; Phase 3b: Trait introspection — pass through to elaboration
    [(surf-instances-of? surf) surf]
    [(surf-methods-of? surf) surf]
    [(surf-satisfies?? surf) surf]
    ;; defr — named relation definition (Phase 7)
    ;; Pass through to elaboration, which produces (list 'defr name expr)
    [(surf-defr? surf) surf]
    ;; Phase E: subtype declaration — pass through to elaboration
    [(surf-subtype? surf) surf]
    ;; Selection declaration — pass through to elaboration
    [(surf-selection? surf) surf]
    ;; Capability declaration — pass through to elaboration
    [(surf-capability? surf) surf]
    ;; Capability inference REPL commands — pass through
    [(surf-cap-closure? surf) surf]
    [(surf-cap-audit? surf) surf]
    [(surf-cap-verify? surf) surf]
    [(surf-cap-bridge? surf) surf]
    ;; Session/process declarations — pass through to elaboration (Phase S1/S2)
    [(surf-session? surf) surf]
    [(surf-defproc? surf) surf]
    [(surf-proc? surf) surf]
    [(surf-dual? surf) surf]
    ;; Strategy declaration — pass through to elaboration (Phase S6)
    [(surf-strategy? surf) surf]
    ;; Spawn command — pass through to elaboration (Phase S7c)
    [(surf-spawn? surf) surf]
    ;; Spawn-with command — pass through to elaboration (Phase S7d)
    [(surf-spawn-with? surf) surf]
    ;; Narrowing expression — treat as implicit eval (Phase 1e)
    [(surf-narrow? surf)
     (surf-eval (expand-expression surf) (surf-narrow-srcloc surf))]
    ;; Bare expression — implicit eval
    [else
     (define loc (cond
                   [(surf-var? surf) (surf-var-srcloc surf)]
                   [(surf-app? surf) (surf-app-srcloc surf)]
                   [(surf-ann? surf) (surf-ann-srcloc surf)]
                   [else srcloc-unknown]))
     (surf-eval (expand-expression surf) loc)]))
