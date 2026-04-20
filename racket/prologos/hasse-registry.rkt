#lang racket/base

;;;
;;; hasse-registry.rkt — PPN Track 4C Phase 2b primitive
;;;
;;; Foundational infrastructure for Hasse-structured registration + lookup
;;; on SRE-registered lattices. Used by:
;;;   Phase 7  — parametric impl registry (L_impl: impl specificity lattice)
;;;   Phase 9b — γ hole-fill inhabitant catalog (L_inhabitant: constructor
;;;              subsumption lattice)
;;;   Future   — PPN Track 5 (type-directed disambiguation), FL-Narrowing,
;;;              PM trait coherence, SRE Track 6 reduction, general
;;;              residual solver (future BSP-LE Track 6)
;;;
;;; Design approach (D.3 §6.12, refined 2026-04-19):
;;;
;;; This primitive is a THIN WRAPPER on existing infrastructure:
;;;   - Cell: `net-new-registry-cell` from infra-cell.rkt (hasheq-union merge)
;;;   - Hasse structure: IMPLICIT in the L domain's :subtype relation,
;;;     navigated via consumer-provided subsume-fn (canonical impl uses
;;;     PUnify + SRE ctor-desc)
;;;   - Storage shape: Module Theory Realization B — position-keyed
;;;     hasheq, Hasse-position-tagged layers on shared carrier
;;;
;;; NO materialized Hasse edges. NO transitive reduction at registration.
;;; The Hasse ORDER lives in the L domain's subsumption relation.
;;;
;;; This matches prior art across 10+ files: tagged-cell-value pattern
;;; (position-keyed hasheq, filter-based reads) + ATMS bitmask subcube
;;; membership (hypercube research) + filter-dependents-by-paths. Phase
;;; 2b GENERALIZES this practice as reusable infrastructure.
;;;
;;; Complexity (honest framing):
;;;   - Register: O(1) — single cell write
;;;   - Lookup:   O(N × subsume-cost) generic; specialized lattices can
;;;               achieve O(1) (Q_n bitmask, prior art) or O(log N)
;;;               (indexing) via their subsume-fn implementation
;;;
;;; Handle shape (hasse-registry-handle):
;;;   Lightweight Racket-level wrapper around the on-network cell +
;;;   parameterization (position-fn, subsume-fn). Handle is held by
;;;   consumers; cell (state) is on-network. PM Track 12 evaluates
;;;   handle shape during its scoping; noted in DEFERRED.md.
;;;

(require "propagator.rkt"
         (only-in "sre-core.rkt" make-sre-domain register-domain!)
         (only-in "merge-fn-registry.rkt" register-merge-fn!/lattice))

;; equal?-based hash union (hasse-registry uses `hash`, not `hasheq`,
;; because positions are typically structured values — types, patterns,
;; pairs — that require equal? semantics, not eq?). The existing
;; merge-hasheq-identity / merge-hasheq-replace in infra-cell.rkt are
;; eq?-keyed, which drops collisions between structurally-equal-but-
;; not-eq pairs.
(define (hasse-merge-hash-union old new)
  (cond
    [(zero? (hash-count new)) old]
    [else (for/fold ([acc old]) ([(k v) (in-hash new)])
            (hash-set acc k v))]))

(provide
 ;; Handle — the user-facing registry reference
 (struct-out hasse-registry-handle)
 ;; Factory
 net-new-hasse-registry
 ;; Core operations
 hasse-registry-register
 hasse-registry-lookup
 ;; Inspection
 hasse-registry-size
 hasse-registry-entries-at-position
 hasse-registry-all-positions)

;; ============================================================
;; Handle
;; ============================================================
;;
;; cell-id       — on-network registry cell (CHAMP-backed hasheq-union)
;; l-domain-name — symbol naming the SRE-registered lattice providing
;;                 the Hasse structure (documentation + potential
;;                 property-inference target at the L level)
;; position-fn   — (Entry → L-value) : where each entry sits in L
;; subsume-fn    — (L-value × L-value → Bool) : does pos subsume query?
;;                 Canonical impl uses PUnify with L's :subtype relation
;;                 via unify-core + SRE ctor-desc. Specialized lattices
;;                 (e.g., Q_n hypercube bitmask, interval trees) override
;;                 for O(1) or O(log N) queries.
(struct hasse-registry-handle (cell-id l-domain-name position-fn subsume-fn)
  #:transparent)

;; ============================================================
;; Factory
;; ============================================================

;; Create a new Hasse-registry instance on the propagator network.
;; Returns (values new-network handle).
;;
;; #:l-domain      : symbol — SRE-registered lattice providing L
;; #:position-fn   : (Entry → L-value)
;; #:subsume-fn    : (L-value × L-value → Bool)
(define (net-new-hasse-registry net
                                #:l-domain l-domain
                                #:position-fn position-fn
                                #:subsume-fn subsume-fn)
  (unless (symbol? l-domain)
    (error 'net-new-hasse-registry
           "#:l-domain must be a symbol (SRE-registered lattice name); got: ~e"
           l-domain))
  (unless (procedure? position-fn)
    (error 'net-new-hasse-registry "#:position-fn must be a procedure; got: ~e" position-fn))
  (unless (procedure? subsume-fn)
    (error 'net-new-hasse-registry "#:subsume-fn must be a procedure; got: ~e" subsume-fn))
  ;; Cell uses equal?-based hash (hasse-merge-hash-union) — positions
  ;; are typically structured values requiring equal? semantics.
  (define-values (net* cid) (net-new-cell net (hash) hasse-merge-hash-union))
  (values net* (hasse-registry-handle cid l-domain position-fn subsume-fn)))

;; ============================================================
;; Registration
;; ============================================================

;; Register an entry. Computes position via position-fn; stores
;; entry in the cell's hasheq at that position (hasheq-union merge
;; handles aggregation when multiple entries share the same position).
;; Returns new network.
(define (hasse-registry-register net handle entry)
  (define cid (hasse-registry-handle-cell-id handle))
  (define position ((hasse-registry-handle-position-fn handle) entry))
  ;; Read existing entries at this position (if any) so we preserve them.
  (define current (net-cell-read net cid))
  (define existing-at-pos (hash-ref current position '()))
  ;; equal?-based hash single-key write; merge preserves other positions.
  (net-cell-write net cid
                  (hash position (cons entry existing-at-pos))))

;; ============================================================
;; Lookup
;; ============================================================

;; Return the antichain of Hasse-minimal entries whose position subsumes
;; the query. "Antichain" = no position in the result is strictly below
;; any other (no position p where q < p for another q in the result).
;;
;; Emergent semantics:
;;   1. Filter positions by subsume-fn (all subsumers of query).
;;   2. Extract Hasse-minimal antichain (no subsumer strictly below another).
;;   3. Return entry lists at antichain positions.
;;
;; Complexity: O(N × subsume-cost) for step 1; O(|subsumers|² × subsume-cost)
;; for step 2. Typical case: |subsumers| small (sparse subsumption); practical
;; cost low. Specialized lattices override subsume-fn for O(1) / O(log N).
(define (hasse-registry-lookup net handle query)
  (define cid (hasse-registry-handle-cell-id handle))
  (define subsume? (hasse-registry-handle-subsume-fn handle))
  (define entries-by-position (net-cell-read net cid))
  ;; Step 1: positions subsuming query
  (define subsumers
    (for/list ([position (in-hash-keys entries-by-position)]
               #:when (subsume? position query))
      position))
  ;; Step 2: Hasse-minimal antichain — retain positions p with no STRICTLY
  ;; MORE-SPECIFIC q in the subsumer set. "q more specific than p" means
  ;; "p subsumes q" (p is broader). REMOVE p if there's such a q:
  ;;   subsume?(p, q)  — p contains q (p is broader)
  ;;   AND NOT subsume?(q, p) — q doesn't contain p (strict, not equal)
  ;; When this holds, q is strictly narrower than p AND also subsumes the
  ;; original query, so p is redundant in the antichain.
  (define antichain
    (for/list ([p (in-list subsumers)]
               #:unless (for/or ([q (in-list subsumers)])
                          (and (not (equal? p q))
                               (subsume? p q)
                               (not (subsume? q p)))))
      p))
  ;; Step 3: entries at antichain positions (flatten — a caller iterates
  ;; all candidate entries without caring which position they came from)
  (for/fold ([result '()])
            ([p (in-list antichain)])
    (append (hash-ref entries-by-position p '()) result)))

;; ============================================================
;; Inspection
;; ============================================================

;; Total number of entries across all positions.
(define (hasse-registry-size net handle)
  (define cid (hasse-registry-handle-cell-id handle))
  (define entries-by-position (net-cell-read net cid))
  (for/sum ([(_ entries) (in-hash entries-by-position)])
    (length entries)))

;; Entries at a specific position (or '() if none).
(define (hasse-registry-entries-at-position net handle position)
  (define cid (hasse-registry-handle-cell-id handle))
  (define entries-by-position (net-cell-read net cid))
  (hash-ref entries-by-position position '()))

;; All positions with registered entries.
(define (hasse-registry-all-positions net handle)
  (define cid (hasse-registry-handle-cell-id handle))
  (define entries-by-position (net-cell-read net cid))
  (hash-keys entries-by-position))

;; ============================================================
;; SRE domain registration for the primitive itself
;; ============================================================
;;
;; 'hasse-registry registers the merge pattern of the primitive —
;; entries accumulate per-position via hasheq-union. The Hasse ORDER
;; lives in L's domain (separately SRE-registered); this domain
;; captures the primitive's OWN algebraic behavior.
;;
;; D2 framework per §6.9.2:
;;   Aspirational: commutative, associative, idempotent (set-like
;;     accumulation of entries per position)
;;   Declared: none initially (γ)
;;   Expected inference: confirm all three
;;   Delta: none expected — hasseq-union over hash-keys has these properties
;;
;; Merge function is hasse-merge-hash-union (equal?-based, defined above).
;; Tier 2 linkage for hasse-merge-hash-union registered at module load.

(define (hasse-registry-merge-registry rel-name)
  (case rel-name
    [(equality) hasse-merge-hash-union]
    [else (error 'hasse-registry-merge-registry
                 "no merge for relation: ~a" rel-name)]))

(define (hasse-registry-bot? v)
  (and (hash? v) (zero? (hash-count v))))

(define (hasse-registry-contradicts? v) #f)

(define hasse-registry-sre-domain
  (make-sre-domain
   #:name 'hasse-registry
   #:merge-registry hasse-registry-merge-registry
   #:contradicts? hasse-registry-contradicts?
   #:bot? hasse-registry-bot?
   #:bot-value (hasheq)
   #:classification 'structural))  ;; PPN 4C Phase 1f: position-keyed compound

(register-domain! hasse-registry-sre-domain)
(register-merge-fn!/lattice hasse-merge-hash-union #:for-domain 'hasse-registry)
