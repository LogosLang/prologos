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
         "champ.rkt")

(provide
 ;; Merge functions — pure (content × content → content)
 merge-hasheq-union
 merge-list-append
 merge-set-union
 merge-replace
 ;; General cell factory — The Most Generalizable Interface
 net-new-cell-with-merge
 ;; Convenience cell factories (delegate to net-new-cell-with-merge)
 net-new-registry-cell
 net-new-list-cell
 net-new-set-cell
 net-new-replace-cell
 ;; Named cell registry — registration protocol (Phase 0c)
 net-register-named-cell
 net-named-cell-ref
 net-named-cell-ref/opt
 net-has-named-cell?)

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
