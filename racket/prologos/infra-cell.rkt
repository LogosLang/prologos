#lang racket/base

;;;
;;; infra-cell.rkt — Infrastructure Cell Abstraction
;;;
;;; Thin convenience layer on top of propagator.rkt for domain-specific
;;; infrastructure cells: registries, constraint stores, warnings, etc.
;;; All cells live in the same prop-network as elaboration cells.
;;;
;;; Provides:
;;;   - Domain-specific merge functions (hasheq union, list append, set union)
;;;   - General cell factory (net-new-cell-with-merge) — The Most Generalizable Interface
;;;   - Convenience cell factories (registry, list, set, definition)
;;;   - Named cell registry for registration protocol (Phase 0c)
;;;
;;; Design principles:
;;;   - Depends ONLY on propagator.rkt and champ.rkt — no circular dependency risk
;;;   - All merge functions are pure (content × content → content)
;;;   - Self-hosting compatible: no Racket parameters, continuations, or
;;;     inspector-dependent behavior in the cell abstraction itself
;;;
;;; Design reference: docs/tracking/2026-03-11_1800_PROPAGATOR_FIRST_MIGRATION.md §Phase 0a
;;;

(require racket/set
         "propagator.rkt"
         "champ.rkt"
         "atms.rkt")

(provide
 ;; Merge functions — pure (content × content → content)
 merge-hasheq-union
 merge-hasheq-list-append
 merge-list-append
 merge-set-union
 merge-replace
 merge-last-write-wins
 merge-constraint-status-map
 merge-error-descriptor-map
 ;; Module lifecycle lattice — Track 5
 mod-loading
 mod-loaded
 mod-stale
 merge-mod-status
 ;; General cell factory — The Most Generalizable Interface
 net-new-cell-with-merge
 ;; Convenience cell factories (delegate to net-new-cell-with-merge)
 net-new-registry-cell
 net-new-list-cell
 net-new-set-cell
 net-new-replace-cell
 net-new-mod-status-cell
 ;; Named cell registry — registration protocol (Phase 0c)
 net-register-named-cell
 net-named-cell-ref
 net-named-cell-ref/opt
 net-has-named-cell?
 ;; Track 7 Phase 4: Assumption-tagged entries for scoped cells
 (struct-out tagged-entry)
 unwrap-tagged-hasheq
 unwrap-tagged-list
 unwrap-tagged-hasheq-list
 hasheq?
 ;; ATMS assumption bridge — Phase 0b
 ;; Struct
 (struct-out infra-state)
 ;; Construction
 make-infra-state
 ;; Assumption lifecycle
 infra-assume
 infra-retract
 infra-commit
 ;; Assumed cell operations
 infra-write-assumed
 infra-read-believed
 infra-read-all-supported
 ;; Current assumption tracking
 current-infra-assumption)

;; ========================================
;; Merge Functions
;; ========================================

;; Monotonic hash union: for registries where each key is registered once.
;; Conflicts use right-hand-side (latest registration wins).
;; Both arguments must be hasheq (immutable eq-based hash).
(define (merge-hasheq-union old new)
  (cond
    [(eq? old 'infra-bot) new]
    [(eq? new 'infra-bot) old]
    [else
     (for/fold ([acc old])
               ([(k v) (in-hash new)])
       (hash-set acc k v))]))

;; Monotonic hash with per-key list append: for wakeup registries.
;; Each key maps to a list; on collision, lists are appended.
;; Both arguments must be hasheq.
(define (merge-hasheq-list-append old new)
  (cond
    [(eq? old 'infra-bot) new]
    [(eq? new 'infra-bot) old]
    [else
     (for/fold ([acc old])
               ([(k v) (in-hash new)])
       (hash-set acc k (append (hash-ref acc k '()) v)))]))

;; Monotonic list accumulation: for warnings, constraints.
;; Appends new items to existing list. Both must be lists.
(define (merge-list-append old new)
  (cond
    [(eq? old 'infra-bot) new]
    [(eq? new 'infra-bot) old]
    [else (append old new)]))

;; Monotonic set union: for propagated-specs, visited sets.
;; Both must be sets (seteq or similar).
(define (merge-set-union old new)
  (cond
    [(eq? old 'infra-bot) new]
    [(eq? new 'infra-bot) old]
    [else (set-union old new)]))

;; Non-monotonic replacement: latest value wins.
;; For cells where the content is replaced on each write (e.g., definition cells
;; whose value changes across LSP edits). In batch mode, definitions are written
;; once, so this is equivalent to a monotonic write. In LSP mode (future), this
;; composes with ATMS assumptions for retraction-based rollback.
(define (merge-replace old new)
  (cond
    [(eq? new 'infra-bot) old]
    [else new]))

;; Track 3 Phase 5b: Alias for merge-replace with clearer semantics for
;; non-monotonic per-clause narrowing var-constraints. Each write replaces
;; the entire map (one var-constraint map per narrowing clause).
(define merge-last-write-wins merge-replace)

;; Track 2 Phase 2: Monotonic hash with per-key status max.
;; Maps constraint-id → status symbol (or tagged-entry of status) with
;; lattice: 'pending < 'resolved.
;; Once a key reaches 'resolved, it stays 'resolved regardless of new writes.
;; Track 7 Phase 4: handles tagged-entry values (unwraps for comparison).
(define (merge-constraint-status-map old new)
  (cond
    [(eq? old 'infra-bot) new]
    [(eq? new 'infra-bot) old]
    [else
     (for/fold ([acc old])
               ([(k v) (in-hash new)])
       (define existing (hash-ref acc k #f))
       ;; Track 7 Phase 4: unwrap tagged entries for status comparison
       (define existing-status
         (if (tagged-entry? existing) (tagged-entry-value existing) existing))
       ;; Monotone: 'resolved wins over 'pending (or absent)
       (if (eq? existing-status 'resolved)
           acc
           (hash-set acc k v)))]))

;; Track 2 Phase 7: Error descriptor map — last-write-wins per meta-id.
;; Maps meta-id → no-instance-error. Later resolution attempts produce
;; better errors as more type info becomes available, so last write wins.
(define (merge-error-descriptor-map old new)
  (cond
    [(eq? old 'infra-bot) new]
    [(eq? new 'infra-bot) old]
    [else
     (for/fold ([acc old])
               ([(k v) (in-hash new)])
       (hash-set acc k v))]))

;; ========================================
;; Module Lifecycle Lattice — Track 5
;; ========================================
;;
;; Module lifecycle states form a monotone lattice:
;;   mod-loading < mod-loaded < mod-stale
;; Stale dominates: once a module is marked stale, it stays stale
;; until explicitly reloaded (which resets to mod-loading).

(define mod-loading 'mod-loading)
(define mod-loaded  'mod-loaded)
(define mod-stale   'mod-stale)

;; Monotone merge: stale dominates loaded dominates loading.
(define (merge-mod-status old new)
  (cond
    [(eq? old 'infra-bot) new]
    [(eq? new 'infra-bot) old]
    [(eq? old mod-stale) mod-stale]    ;; once stale, stays stale
    [(eq? new mod-stale) mod-stale]    ;; stale always wins
    [(eq? new mod-loaded) mod-loaded]  ;; loaded beats loading
    [(eq? old mod-loaded) mod-loaded]  ;; loaded beats loading
    [else old]))                       ;; loading = loading

;; ========================================
;; General Cell Factory
;; ========================================

;; Create a cell with any merge function and initial content.
;; This is the primary API — convenience factories delegate to this.
;; Returns: (values new-network cell-id)
(define (net-new-cell-with-merge net merge-fn initial-content [contradicts? #f])
  (net-new-cell net initial-content merge-fn contradicts?))

;; ========================================
;; Convenience Cell Factories
;; ========================================

;; Registry cell: hasheq with union merge, starts empty.
;; For: schema-registry, ctor-registry, impl-registry, etc.
;; Returns: (values new-network cell-id)
(define (net-new-registry-cell net)
  (net-new-cell-with-merge net merge-hasheq-union (hasheq)))

;; List cell: list with append merge, starts empty.
;; For: constraint-store, coercion-warnings, deprecation-warnings, etc.
;; Returns: (values new-network cell-id)
(define (net-new-list-cell net)
  (net-new-cell-with-merge net merge-list-append '()))

;; Set cell: set with union merge, starts empty.
;; For: propagated-specs, visited-modules, etc.
;; Returns: (values new-network cell-id)
(define (net-new-set-cell net)
  (net-new-cell-with-merge net merge-set-union (seteq)))

;; Replace cell: latest-value-wins semantics, starts at bot.
;; For: definition cells (type, value), namespace context, etc.
;; Returns: (values new-network cell-id)
(define (net-new-replace-cell net [initial-content 'infra-bot])
  (net-new-cell-with-merge net merge-replace initial-content))

;; Module status cell: lifecycle lattice (loading < loaded < stale).
;; For: module-network-ref mod-status tracking.
;; Returns: (values new-network cell-id)
(define (net-new-mod-status-cell net [initial-status mod-loading])
  (net-new-cell-with-merge net merge-mod-status initial-status))

;; ========================================
;; Named Cell Registry — Registration Protocol
;; ========================================
;;
;; Each module registers its own cells by symbolic name at startup.
;; The driver calls registration functions in dependency order.
;; Cells are looked up by name at runtime via net-named-cell-ref.
;;
;; The named registry is stored as a separate hasheq alongside the network,
;; NOT inside the prop-network struct (which is Racket-level infrastructure
;; that should not know about Prologos-specific naming conventions).
;;
;; Usage pattern:
;;   (define-values (net* cid) (net-new-registry-cell net))
;;   (define-values (net** names*) (net-register-named-cell net* names 'impl-registry cid))
;;   ;; later:
;;   (define cid (net-named-cell-ref names 'impl-registry))
;;   (net-cell-read net cid)

;; Register a cell under a symbolic name.
;; names: hasheq (symbol → cell-id) — the name registry
;; Returns: (values network updated-names)
(define (net-register-named-cell net names name cell-id)
  (when (hash-has-key? names name)
    (error 'net-register-named-cell
           "cell already registered: ~a" name))
  (values net (hash-set names name cell-id)))

;; Look up a named cell. Errors if not found.
(define (net-named-cell-ref names name)
  (hash-ref names name
            (lambda ()
              (error 'net-named-cell-ref
                     "unknown infrastructure cell: ~a" name))))

;; Look up a named cell. Returns #f if not found.
(define (net-named-cell-ref/opt names name)
  (hash-ref names name #f))

;; Check if a named cell exists.
(define (net-has-named-cell? names name)
  (hash-has-key? names name))

;; ========================================
;; Track 7 Phase 4: Assumption-Tagged Entries
;; ========================================
;;
;; Scoped cells (constraints, wakeups, warnings) tag each entry with the
;; assumption-id under which it was created. At depth 0 (no speculation),
;; assumption-id is #f (unconditional — always believed).
;;
;; Merge functions work unchanged — they accumulate tagged entries.
;; Read helpers unwrap tags for consumers; S(-1) reads raw tags for retraction.

;; A cell entry tagged with the assumption under which it was created.
(struct tagged-entry (value assumption-id) #:transparent)

;; Unwrap tagged entries in a hasheq: return hasheq with raw values.
;; Handles mixed tagged/untagged entries (backward compatibility during migration).
(define (unwrap-tagged-hasheq h)
  (if (or (eq? h 'infra-bot) (not (hash? h)) (zero? (hash-count h)))
      h
      (for/fold ([acc (if (hasheq? h) (hasheq) (hash))])
                ([(k v) (in-hash h)])
        (hash-set acc k (if (tagged-entry? v) (tagged-entry-value v) v)))))

;; Unwrap tagged entries in a list: return list with raw values.
(define (unwrap-tagged-list lst)
  (if (or (eq? lst 'infra-bot) (null? lst))
      lst
      (map (λ (e) (if (tagged-entry? e) (tagged-entry-value e) e)) lst)))

;; Unwrap tagged entries in a hasheq where values are lists (wakeup cells).
;; Each list element may be tagged; unwrap them.
(define (unwrap-tagged-hasheq-list h)
  (if (or (eq? h 'infra-bot) (not (hash? h)) (zero? (hash-count h)))
      h
      (for/fold ([acc (hasheq)])
                ([(k v) (in-hash h)])
        (hash-set acc k (if (list? v) (unwrap-tagged-list v) v)))))

;; Helper: check if a hasheq is eq?-based (not equal?-based)
(define (hasheq? h)
  (and (hash? h) (immutable? h) (hash-eq? h)))

;; ========================================
;; ATMS Assumption Bridge — Phase 0b
;; ========================================
;;
;; Pairs the prop-network (monotonic infra-cells) with an ATMS
;; (assumption-tagged cells for non-monotonic operations).
;;
;; Two kinds of infrastructure cells coexist:
;;   1. Monotonic cells (registries, warnings, constraint stores) — live in
;;      prop-network, use merge functions, never need retraction.
;;   2. Assumed cells (definitions, speculative state) — live in ATMS TMS cells,
;;      tagged with assumptions, support retraction and commit.
;;
;; The infra-state struct holds both, plus the named registry.
;; This is the "one network" from the design document — the prop-network
;; inside the ATMS is the same one that holds the monotonic cells.

;; Combined state: prop-network (via ATMS) + names + current assumption scope.
;; Pure value — all operations return new infra-state values.
(struct infra-state
  (atms       ;; atms (wraps prop-network; holds both monotonic + TMS cells)
   names)     ;; hasheq: symbol → cell-id (named cell registry)
  #:transparent)

;; Dynamic parameter: the currently active assumption-id (or #f for unconditional).
;; Used by `infra-write-assumed` to auto-tag writes.
;; This is the ONE Racket parameter in the cell abstraction — justified because
;; assumption scoping is inherently dynamic (it follows the call stack, not the
;; data flow). The cell values themselves remain pure.
(define current-infra-assumption (make-parameter #f))

;; Create an infra-state with a fresh ATMS wrapping the given prop-network.
;; If no network is given, starts from a fresh prop-network.
(define (make-infra-state [net #f] [names (hasheq)])
  (infra-state (atms-empty (or net (make-prop-network))) names))

;; --- Assumption Lifecycle ---

;; Create a new assumption. Returns (values new-infra-state assumption-id).
;; name: symbol (for debugging, e.g., 'per-command, 'speculation-church-fold)
;; datum: any value (e.g., the form being elaborated)
(define (infra-assume is name [datum #f])
  (define-values (atms* aid) (atms-assume (infra-state-atms is) name datum))
  (values (struct-copy infra-state is [atms atms*]) aid))

;; Retract an assumption: all TMS cell values tagged with this assumption
;; become non-believed. They still exist in the TMS (for history/nogoods),
;; but `infra-read-believed` will no longer return them.
(define (infra-retract is aid)
  (struct-copy infra-state is
    [atms (atms-retract (infra-state-atms is) aid)]))

;; Commit an assumption: makes it permanent. In practice, this is a no-op
;; for the current ATMS (assumptions start believed). The semantic intent
;; is: "this assumption is now unconditional; future retractions won't
;; affect its content." For batch mode, all per-command assumptions are
;; committed immediately after successful elaboration.
;;
;; Implementation: commitment is implicit — believed assumptions are
;; already "active." The commit operation is the decision to NOT retract.
;; We provide this as an explicit API for clarity and future extensibility
;; (e.g., removing the assumption from the believed set entirely to reduce
;; membership checks).
(define (infra-commit is aid)
  ;; Currently a no-op — the assumption stays in believed.
  ;; Future: could compact TMS cells by removing the assumption tag
  ;; from all supported-values, converting them to unconditional.
  is)

;; --- Assumed Cell Operations ---

;; Write a value to a TMS cell under the given assumption (or the
;; current-infra-assumption if not specified).
;; cell-key: any hashable key (typically a symbol like 'global-env:foo)
;; value: the content to write
;; Returns: new infra-state
(define (infra-write-assumed is cell-key value [aid (current-infra-assumption)])
  (unless aid
    (error 'infra-write-assumed
           "no active assumption — use infra-assume or parameterize current-infra-assumption"))
  (define support (hasheq aid #t))
  (struct-copy infra-state is
    [atms (atms-write-cell (infra-state-atms is) cell-key value support)]))

;; Read the believed value from a TMS cell under the current worldview.
;; Returns 'infra-bot if no compatible value exists (mirrors bot convention).
(define (infra-read-believed is cell-key)
  (define val (atms-read-cell (infra-state-atms is) cell-key))
  (if (eq? val 'bot) 'infra-bot val))

;; Read all supported values for a TMS cell (regardless of worldview).
;; Returns a list of supported-value structs.
;; Useful for debugging, inspection, and understanding what's been written.
(define (infra-read-all-supported is cell-key)
  (define tc (hash-ref (atms-tms-cells (infra-state-atms is)) cell-key #f))
  (if tc (tms-cell-values tc) '()))
