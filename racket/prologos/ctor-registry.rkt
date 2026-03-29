#lang racket/base

;;;
;;; ctor-registry.rkt — Domain-Agnostic Constructor Descriptor Registry
;;;
;;; A single registration site for all compound structure — both type constructors
;;; (System 1) and data constructors (System 2). Each constructor is described by
;;; a `ctor-desc` struct that captures its arity, recognition, decomposition,
;;; reconstruction, and per-component lattice merge functions.
;;;
;;; The registry is the single source of structural truth. All structural
;;; decomposition, reconstruction, and merge operations are derived from
;;; descriptors rather than hardcoded per-tag match clauses.
;;;
;;; Design reference: docs/tracking/2026-03-19_PUNIFY_PART2_CELL_TREE_ARCHITECTURE.md
;;;   §5.6.2 Constructor Descriptor Registry
;;;   §5.6.3 Generic Operations Derived From Descriptors
;;;
;;; Dependencies: syntax.rkt (struct predicates/accessors),
;;;   mult-lattice.rkt (pure leaf), term-lattice.rkt (pure leaf).
;;; Does NOT depend on type-lattice.rkt (avoids circular dependency).
;;; The type-lattice merge is passed as #:type-merge to generic-merge.
;;;

(require racket/match
         racket/list
         "syntax.rkt"
         "mult-lattice.rkt"
         "term-lattice.rkt"
         "sessions.rkt")          ;; SRE Track 1 Phase 3: session struct predicates/accessors
;; NOTE: session-lattice.rkt NOT imported here (circular dep through type-lattice → reduction chain).
;; Session lattice uses 'session sentinel (like 'type for type-lattice), resolved at call time.

(provide
 ;; Struct
 (struct-out ctor-desc)
 ;; Registration
 register-ctor!
 ;; Lookup
 lookup-ctor-desc
 ctor-tag-for-value
 all-ctor-descs
 ;; Lattice spec helpers
 type-lattice-spec
 mult-lattice-spec
 term-lattice-spec
 session-lattice-spec
 lattice-spec?
 lattice-spec-merge
 lattice-spec-contradicts?
 ;; Generic operations
 generic-decompose-components
 generic-reconstruct-value
 generic-merge
 ;; Toggle
 current-punify-enabled?
 ;; Debugging
 cell-tree->sexp)

;; ========================================
;; Constructor Descriptor Struct
;; ========================================

;; A descriptor for a compound constructor (type or data).
;;
;; tag:                symbol — 'Pi, 'Sigma, 'app, 'cons, 'some, 'suc, ...
;; arity:              natural — number of sub-components
;; recognizer-fn:      (value → boolean) — is this value of this constructor?
;; extract-fn:         (value → (listof component)) — extract sub-components
;; reconstruct-fn:     ((listof value) → value) — rebuild from components
;; component-lattices: (listof lattice-spec) — per-component merge/contradicts
;; binder-depth:       natural — how many trailing components are under a binder
;; domain:             symbol — 'type or 'data
;;
;; SRE Track 1 additions:
;; component-variances: (listof variance) or #f — per-component variance for subtyping
;;   Variance values: '+ (covariant), '- (contravariant), '= (invariant), 'ø (phantom)
;;   When #f, all components default to invariant (= equality, no subtyping).
;;   For built-in types: hardcoded textbook values (Pi = '(- +), List = '(+), etc.)
;;   For user-defined types: derived via polarity inference from type definition.
;; binder-open-fn:     (value gensym → (values opened-body fresh-var)) or #f
;;   How to open a binder for structural decomposition. Needed for Pi, Sigma,
;;   lam, DSend, DRecv — any constructor with binder-depth > 0.
;;   When #f, binder decomposition falls through to caller (PUnify dispatch).
(struct ctor-desc
  (tag
   arity
   recognizer-fn
   extract-fn
   reconstruct-fn
   component-lattices
   binder-depth
   domain
   component-variances   ; SRE Track 1: '(+ - = ø ...) or #f
   binder-open-fn)       ; SRE Track 1: (value gensym → values) or #f
  #:transparent)

;; ========================================
;; Lattice Specifications
;; ========================================
;;
;; Each component-lattice entry is either:
;; - A concrete lattice-spec with merge and contradicts? functions
;; - The special 'type sentinel, resolved at call time via #:type-merge
;;   to avoid circular dependency with type-lattice.rkt

(struct lattice-spec (merge contradicts?) #:transparent)

;; Pre-built specs for the four lattice families
(define mult-lattice-spec
  (lattice-spec mult-lattice-merge mult-lattice-contradicts?))

(define term-lattice-spec
  (lattice-spec term-merge term-contradiction?))

;; Sentinel for type-lattice components (resolved at call time)
(define type-lattice-spec 'type)

;; SRE Track 1 Phase 3: Session lattice spec — sentinel symbol, like type-lattice-spec.
;; Cannot use concrete lattice-spec here because session-lattice.rkt creates a
;; circular dependency (session-lattice → type-lattice → reduction → ... → ctor-registry).
;; Resolved at call time via #:session-merge parameter on generic operations.
(define session-lattice-spec 'session)

;; Resolve a component's lattice spec to its merge function.
;; For 'type specs, uses the provided type-merge-fn.
(define (resolve-merge-fn spec type-merge-fn)
  (cond
    [(eq? spec 'type) type-merge-fn]
    [(lattice-spec? spec) (lattice-spec-merge spec)]
    [else (error 'resolve-merge-fn "unknown lattice spec: ~a" spec)]))

;; ========================================
;; Registry Storage
;; ========================================
;;
;; Two-level lookup: domain → tag → descriptor.
;; Separate tables per domain so 'pair in type domain doesn't collide
;; with 'pair in data domain.

(define type-ctor-table (make-hasheq))  ; tag → ctor-desc
(define data-ctor-table (make-hasheq))  ; tag → ctor-desc

;; SRE Track 0: Extensible domain table registry.
;; New domains auto-create their table on first registration.
(define extra-domain-tables (make-hasheq))  ; domain-symbol → (hasheq tag → ctor-desc)

(define (domain-table domain)
  (case domain
    [(type) type-ctor-table]
    [(data) data-ctor-table]
    [else
     ;; Auto-create table for new domains
     (or (hash-ref extra-domain-tables domain #f)
         (let ([tbl (make-hasheq)])
           (hash-set! extra-domain-tables domain tbl)
           tbl))]))

;; ========================================
;; Validation
;; ========================================

;; Validate a descriptor at registration time.
;; Checks:
;; 1. extract-fn returns exactly `arity` components
;; 2. roundtrip: reconstruct(extract(sample)) = sample
;; 3. component-lattices length = arity
;; 4. binder-depth ≤ arity
(define (validate-ctor-desc! desc sample)
  (define tag (ctor-desc-tag desc))
  (define arity (ctor-desc-arity desc))
  (define extract (ctor-desc-extract-fn desc))
  (define reconstruct (ctor-desc-reconstruct-fn desc))
  (define lats (ctor-desc-component-lattices desc))
  (define bd (ctor-desc-binder-depth desc))
  (define recog (ctor-desc-recognizer-fn desc))

  ;; Check recognizer matches sample
  (unless (recog sample)
    (error 'validate-ctor-desc!
           "~a: recognizer-fn rejects sample value: ~a" tag sample))

  ;; Check extract arity
  (define components (extract sample))
  (unless (= (length components) arity)
    (error 'validate-ctor-desc!
           "~a: extract-fn returned ~a components, expected ~a"
           tag (length components) arity))

  ;; Check roundtrip (only for arity > 0; atoms trivially roundtrip)
  (when (> arity 0)
    (define rebuilt (reconstruct components))
    (unless (equal? rebuilt sample)
      (error 'validate-ctor-desc!
             "~a: roundtrip failed: reconstruct(extract(~a)) = ~a"
             tag sample rebuilt)))

  ;; Check component-lattices length
  (unless (= (length lats) arity)
    (error 'validate-ctor-desc!
           "~a: component-lattices has ~a entries, expected ~a"
           tag (length lats) arity))

  ;; Check binder-depth ≤ arity
  (unless (<= bd arity)
    (error 'validate-ctor-desc!
           "~a: binder-depth ~a exceeds arity ~a"
           tag bd arity))

  ;; SRE Track 1: Check component-variances length if provided
  (define cv (ctor-desc-component-variances desc))
  (when (and cv (not (= (length cv) arity)))
    (error 'validate-ctor-desc!
           "~a: component-variances has ~a entries, expected ~a"
           tag (length cv) arity))

  ;; SRE Track 1 + Track 2F: Validate variance values
  ;; Track 2F adds 'same-domain and 'cross-domain for antitone (duality) kinds.
  (when cv
    (for ([v (in-list cv)])
      (unless (memq v '(+ - = ø same-domain cross-domain))
        (error 'validate-ctor-desc!
               "~a: invalid variance ~a (expected +, -, =, ø, same-domain, or cross-domain)"
               tag v))))

  ;; SRE Track 1: binder-open-fn should be present iff binder-depth > 0
  ;; (Soft check — warn, don't error, since Track 0 descriptors may not have it yet)
  )

;; ========================================
;; Registration
;; ========================================

;; Register a constructor descriptor. Validates against sample at registration time.
;; Keywords provide a readable registration syntax.
(define (register-ctor! tag
                        #:arity arity
                        #:recognizer recognizer-fn
                        #:extract extract-fn
                        #:reconstruct reconstruct-fn
                        #:component-lattices component-lattices
                        #:binder-depth [binder-depth 0]
                        #:domain domain
                        #:sample sample
                        #:component-variances [component-variances #f]
                        #:binder-open-fn [binder-open-fn #f])
  (define desc
    (ctor-desc tag arity recognizer-fn extract-fn reconstruct-fn
               component-lattices binder-depth domain
               component-variances binder-open-fn))
  ;; Validate at registration time
  (validate-ctor-desc! desc sample)
  ;; Store in appropriate domain table
  (define tbl (domain-table domain))
  (when (hash-has-key? tbl tag)
    (error 'register-ctor!
           "duplicate registration for tag ~a in domain ~a" tag domain))
  (hash-set! tbl tag desc)
  (void))

;; ========================================
;; Lookup
;; ========================================

;; Look up a descriptor by tag and domain.
;; Returns #f if not found.
(define (lookup-ctor-desc tag #:domain [domain 'type])
  (hash-ref (domain-table domain) tag #f))

;; Determine the constructor descriptor for a value by testing all registered
;; recognizers. Returns ctor-desc or #f for atoms/unrecognized values.
;;
;; SRE Track 2 Phase 0: O(1) fast path via prop:ctor-desc-tag struct property.
;; If the value carries the property, extract (domain . tag) and look up the
;; descriptor directly. Falls back to linear scan for non-struct values
;; (data domain: plain lists/symbols) or values without the property.
(define (ctor-tag-for-value v)
  ;; Fast path: O(1) via struct-type property (~4ns + ~15ns)
  ;; Covers all type-domain and session-domain structs from syntax.rkt/sessions.rkt.
  (cond
    [(ctor-desc-tag? v)
     (define dt (ctor-desc-tag-ref v))
     (define domain (car dt))
     (define tag (cdr dt))
     (hash-ref (domain-table domain) tag #f)]
    ;; Slow path: linear scan for values without property.
    ;; Data domain (lists/symbols like '(cons h t), 'nil) and extra domains
    ;; (test structs, narrowing vars) don't carry the property.
    [else
     (or (ctor-tag-for-value-in-domain v data-ctor-table)
         ;; SRE Track 0: search extra domain tables
         (for/first ([tbl (in-hash-values extra-domain-tables)]
                     #:when (ctor-tag-for-value-in-domain v tbl))
           (ctor-tag-for-value-in-domain v tbl)))]))

(define (ctor-tag-for-value-in-domain v tbl)
  (for/first ([desc (in-hash-values tbl)]
              #:when ((ctor-desc-recognizer-fn desc) v))
    desc))

;; Return all registered descriptors as a list.
(define (all-ctor-descs #:domain [domain #f])
  (cond
    [(not domain)
     (append (hash-values type-ctor-table)
             (hash-values data-ctor-table)
             ;; SRE Track 0: include extra domain tables
             (apply append (map hash-values (hash-values extra-domain-tables))))]
    [else
     (hash-values (domain-table domain))]))

;; ========================================
;; Generic Operations (§5.6.3)
;; ========================================

;; Generic decomposition: extract components from a value using its descriptor.
;; Returns (listof component) or #f if value has no registered descriptor.
(define (generic-decompose-components value)
  (define desc (ctor-tag-for-value value))
  (and desc ((ctor-desc-extract-fn desc) value)))

;; Generic reconstruction: rebuild a value from components using a descriptor.
;; Returns the reconstructed value.
(define (generic-reconstruct-value desc components)
  ((ctor-desc-reconstruct-fn desc) components))

;; Generic merge: merge two values of the same constructor tag.
;; Uses the descriptor's component-lattices for per-component merge.
;;
;; #:type-merge is REQUIRED when the descriptor has type-lattice components.
;; This avoids the circular dependency with type-lattice.rkt: the caller
;; (type-lattice.rkt) passes try-unify-pure as self-reference.
;;
;; Returns merged value, or #f for contradiction (matching try-unify-pure convention).
(define (generic-merge v1 v2
                       #:type-merge [type-merge-fn #f]
                       #:domain [domain 'type])
  ;; Find descriptors for both values
  (define tbl (domain-table domain))
  (define desc1 (find-desc-in-table v1 tbl))
  (define desc2 (find-desc-in-table v2 tbl))
  (cond
    ;; Both must be recognized and have the same tag
    [(not desc1) #f]  ;; v1 not a registered constructor → can't merge structurally
    [(not desc2) #f]  ;; v2 not a registered constructor
    [(not (eq? (ctor-desc-tag desc1) (ctor-desc-tag desc2)))
     #f]  ;; different summands → contradiction
    [else
     (define desc desc1)
     (define arity (ctor-desc-arity desc))
     (cond
       ;; Arity 0: both are the same atom → return v1
       [(= arity 0) v1]
       [else
        (define cs1 ((ctor-desc-extract-fn desc) v1))
        (define cs2 ((ctor-desc-extract-fn desc) v2))
        (define lats (ctor-desc-component-lattices desc))
        ;; Merge each component pair using the appropriate lattice merge
        (define merged
          (for/list ([c1 (in-list cs1)]
                     [c2 (in-list cs2)]
                     [lat (in-list lats)])
            (define merge-fn (resolve-merge-fn lat type-merge-fn))
            (unless merge-fn
              (error 'generic-merge
                     "type-lattice component requires #:type-merge parameter for tag ~a"
                     (ctor-desc-tag desc)))
            (merge-fn c1 c2)))
        ;; Check for contradictions: any component returned #f means failure
        ;; (following try-unify-pure convention where #f = contradiction)
        (if (memq #f merged)
            #f
            ((ctor-desc-reconstruct-fn desc) merged))])]))

(define (find-desc-in-table v tbl)
  (for/first ([(tag desc) (in-hash tbl)]
              #:when ((ctor-desc-recognizer-fn desc) v))
    desc))

;; ========================================
;; Toggle: current-punify-enabled?
;; ========================================

;; A/B toggle for PUnify. When #f (default), existing unification runs unchanged.
;; When #t, unify-core delegates to unify-via-propagator (cell-tree decomposition).
;; Track 10B Phase A5: Toggle flip ATTEMPTED. Result: systemic regression —
;; multiple failures + timeouts (test-map-bridge, test-stdlib-01-data-04).
;; The 5 known parity bugs are NOT simple fixes. PUnify needs dedicated track.
;; Reverted to #f. See Track 10B PIR for details.
(define current-punify-enabled? (make-parameter #f))

;; ========================================
;; Debugging: cell-tree->sexp
;; ========================================

;; Convert a cell-tree structure to a readable S-expression for debugging.
;; Takes a cell-id and a read-fn (net → cell-id → value) to traverse.
;; Returns a nested S-expression representing the tree structure.
(define (cell-tree->sexp cell-id read-fn decomp-fn)
  (define val (read-fn cell-id))
  (define desc (ctor-tag-for-value val))
  (define tag (and desc (ctor-desc-tag desc)))
  (cond
    [(not desc) val]  ;; atom or unrecognized — return as-is
    [else
     ;; Try to get sub-cells from decomposition registry
     (define sub-cells (decomp-fn cell-id))
     (cond
       [(not sub-cells) val]  ;; not decomposed yet — return value
       [else
        ;; Recursively convert sub-cells
        (cons tag
              (for/list ([sc (in-list sub-cells)])
                (cell-tree->sexp sc read-fn decomp-fn)))])]))

;; ========================================
;; Type Constructor Registrations (System 1)
;; ========================================
;;
;; All 11 compound type tags from elaborator-network.rkt:type-constructor-tag.
;; Component lattices use type-lattice-spec (deferred) for type components
;; and mult-lattice-spec (concrete) for multiplicity components.

;; Pi: mult, domain, codomain (codomain under binder)
;; Variance: mult=invariant, domain=contravariant, codomain=covariant
(register-ctor! 'Pi
  #:arity 3
  #:recognizer expr-Pi?
  #:extract (λ (v) (list (expr-Pi-mult v) (expr-Pi-domain v) (expr-Pi-codomain v)))
  #:reconstruct (λ (cs) (expr-Pi (first cs) (second cs) (third cs)))
  #:component-lattices (list mult-lattice-spec type-lattice-spec type-lattice-spec)
  #:binder-depth 1
  #:domain 'type
  #:sample (expr-Pi 'mw (expr-tycon 'Nat) (expr-bvar 0))
  #:component-variances '(= - +))

;; Sigma: fst-type, snd-type (snd-type under binder)
;; Variance: fst=covariant, snd=covariant
(register-ctor! 'Sigma
  #:arity 2
  #:recognizer expr-Sigma?
  #:extract (λ (v) (list (expr-Sigma-fst-type v) (expr-Sigma-snd-type v)))
  #:reconstruct (λ (cs) (expr-Sigma (first cs) (second cs)))
  #:component-lattices (list type-lattice-spec type-lattice-spec)
  #:binder-depth 1
  #:domain 'type
  #:sample (expr-Sigma (expr-tycon 'Nat) (expr-bvar 0))
  #:component-variances '(+ +))

;; App: func, arg
;; Variance: func=invariant (HKT variance unknown), arg=covariant
(register-ctor! 'app
  #:arity 2
  #:recognizer expr-app?
  #:extract (λ (v) (list (expr-app-func v) (expr-app-arg v)))
  #:reconstruct (λ (cs) (expr-app (first cs) (second cs)))
  #:component-lattices (list type-lattice-spec type-lattice-spec)
  #:binder-depth 0
  #:domain 'type
  #:sample (expr-app (expr-tycon 'List) (expr-tycon 'Nat))
  #:component-variances '(= +))

;; Eq: type, lhs, rhs
;; Variance: all invariant (equality type is fixed, lhs/rhs must match exactly)
(register-ctor! 'Eq
  #:arity 3
  #:recognizer expr-Eq?
  #:extract (λ (v) (list (expr-Eq-type v) (expr-Eq-lhs v) (expr-Eq-rhs v)))
  #:reconstruct (λ (cs) (expr-Eq (first cs) (second cs) (third cs)))
  #:component-lattices (list type-lattice-spec type-lattice-spec type-lattice-spec)
  #:binder-depth 0
  #:domain 'type
  #:sample (expr-Eq (expr-tycon 'Nat) (expr-zero) (expr-zero))
  #:component-variances '(= = =))

;; Vec: elem-type, length
;; Variance: elem=covariant, length=invariant (length is a value, not a type)
(register-ctor! 'Vec
  #:arity 2
  #:recognizer expr-Vec?
  #:extract (λ (v) (list (expr-Vec-elem-type v) (expr-Vec-length v)))
  #:reconstruct (λ (cs) (expr-Vec (first cs) (second cs)))
  #:component-lattices (list type-lattice-spec type-lattice-spec)
  #:binder-depth 0
  #:domain 'type
  #:sample (expr-Vec (expr-tycon 'Nat) (expr-zero))
  #:component-variances '(+ =))

;; Fin: bound
;; Variance: bound=invariant (Fin is indexed by a specific value)
(register-ctor! 'Fin
  #:arity 1
  #:recognizer expr-Fin?
  #:extract (λ (v) (list (expr-Fin-bound v)))
  #:reconstruct (λ (cs) (expr-Fin (first cs)))
  #:component-lattices (list type-lattice-spec)
  #:binder-depth 0
  #:domain 'type
  #:sample (expr-Fin (expr-suc (expr-zero)))
  #:component-variances '(=))

;; pair (type-level): fst, snd
;; Variance: both covariant
(register-ctor! 'pair
  #:arity 2
  #:recognizer expr-pair?
  #:extract (λ (v) (list (expr-pair-fst v) (expr-pair-snd v)))
  #:reconstruct (λ (cs) (expr-pair (first cs) (second cs)))
  #:component-lattices (list type-lattice-spec type-lattice-spec)
  #:binder-depth 0
  #:domain 'type
  #:sample (expr-pair (expr-zero) (expr-zero))
  #:component-variances '(+ +))

;; lam: mult, type, body (body under binder)
;; Variance: mult=invariant, type=contravariant (input), body=covariant (output)
(register-ctor! 'lam
  #:arity 3
  #:recognizer expr-lam?
  #:extract (λ (v) (list (expr-lam-mult v) (expr-lam-type v) (expr-lam-body v)))
  #:reconstruct (λ (cs) (expr-lam (first cs) (second cs) (third cs)))
  #:component-lattices (list mult-lattice-spec type-lattice-spec type-lattice-spec)
  #:binder-depth 1
  #:domain 'type
  #:sample (expr-lam 'mw (expr-tycon 'Nat) (expr-bvar 0))
  #:component-variances '(= - +))

;; PVec: elem-type
;; Variance: elem=covariant
(register-ctor! 'PVec
  #:arity 1
  #:recognizer expr-PVec?
  #:extract (λ (v) (list (expr-PVec-elem-type v)))
  #:reconstruct (λ (cs) (expr-PVec (first cs)))
  #:component-lattices (list type-lattice-spec)
  #:binder-depth 0
  #:domain 'type
  #:sample (expr-PVec (expr-tycon 'Nat))
  #:component-variances '(+))

;; Set: elem-type
;; Variance: elem=covariant
(register-ctor! 'Set
  #:arity 1
  #:recognizer expr-Set?
  #:extract (λ (v) (list (expr-Set-elem-type v)))
  #:reconstruct (λ (cs) (expr-Set (first cs)))
  #:component-lattices (list type-lattice-spec)
  #:binder-depth 0
  #:domain 'type
  #:sample (expr-Set (expr-tycon 'Nat))
  #:component-variances '(+))

;; Map: k-type, v-type
;; Variance: key=invariant (keys must match exactly for lookup), value=covariant
(register-ctor! 'Map
  #:arity 2
  #:recognizer expr-Map?
  #:extract (λ (v) (list (expr-Map-k-type v) (expr-Map-v-type v)))
  #:reconstruct (λ (cs) (expr-Map (first cs) (second cs)))
  #:component-lattices (list type-lattice-spec type-lattice-spec)
  #:binder-depth 0
  #:domain 'type
  #:sample (expr-Map (expr-tycon 'String) (expr-tycon 'Nat))
  #:component-variances '(= +))

;; suc (type-level): predecessor
;; Variance: invariant (suc is a value constructor, not a type constructor)
(register-ctor! 'suc
  #:arity 1
  #:recognizer expr-suc?
  #:extract (λ (v) (list (expr-suc-pred v)))
  #:reconstruct (λ (cs) (expr-suc (first cs)))
  #:component-lattices (list type-lattice-spec)
  #:binder-depth 0
  #:domain 'type
  #:sample (expr-suc (expr-zero))
  #:component-variances '(=))

;; ========================================
;; Data Constructor Registrations (System 2)
;; ========================================
;;
;; Data values are list-encoded: '(cons h t), '(some x), '(suc n), etc.
;; Atoms: 'nil, 'none, 'zero.

;; cons: head, tail
(register-ctor! 'cons
  #:arity 2
  #:recognizer (λ (v) (and (list? v) (= (length v) 3) (eq? (first v) 'cons)))
  #:extract (λ (v) (list (second v) (third v)))
  #:reconstruct (λ (cs) (list 'cons (first cs) (second cs)))
  #:component-lattices (list term-lattice-spec term-lattice-spec)
  #:domain 'data
  #:sample '(cons a b))

;; nil: arity 0
(register-ctor! 'nil
  #:arity 0
  #:recognizer (λ (v) (eq? v 'nil))
  #:extract (λ (v) '())
  #:reconstruct (λ (cs) 'nil)
  #:component-lattices '()
  #:domain 'data
  #:sample 'nil)

;; some: inner
(register-ctor! 'some
  #:arity 1
  #:recognizer (λ (v) (and (list? v) (= (length v) 2) (eq? (first v) 'some)))
  #:extract (λ (v) (list (second v)))
  #:reconstruct (λ (cs) (list 'some (first cs)))
  #:component-lattices (list term-lattice-spec)
  #:domain 'data
  #:sample '(some x))

;; none: arity 0
(register-ctor! 'none
  #:arity 0
  #:recognizer (λ (v) (eq? v 'none))
  #:extract (λ (v) '())
  #:reconstruct (λ (cs) 'none)
  #:component-lattices '()
  #:domain 'data
  #:sample 'none)

;; suc (data-level): predecessor
(register-ctor! 'suc
  #:arity 1
  #:recognizer (λ (v) (and (list? v) (= (length v) 2) (eq? (first v) 'suc)))
  #:extract (λ (v) (list (second v)))
  #:reconstruct (λ (cs) (list 'suc (first cs)))
  #:component-lattices (list term-lattice-spec)
  #:domain 'data
  #:sample '(suc n))

;; zero: arity 0
(register-ctor! 'zero
  #:arity 0
  #:recognizer (λ (v) (eq? v 'zero))
  #:extract (λ (v) '())
  #:reconstruct (λ (cs) 'zero)
  #:component-lattices '()
  #:domain 'data
  #:sample 'zero)

;; pair (data-level): fst, snd
(register-ctor! 'pair
  #:arity 2
  #:recognizer (λ (v) (and (list? v) (= (length v) 3) (eq? (first v) 'pair)))
  #:extract (λ (v) (list (second v) (third v)))
  #:reconstruct (λ (cs) (list 'pair (first cs) (second cs)))
  #:component-lattices (list term-lattice-spec term-lattice-spec)
  #:domain 'data
  #:sample '(pair a b))

;; ok: value
(register-ctor! 'ok
  #:arity 1
  #:recognizer (λ (v) (and (list? v) (= (length v) 2) (eq? (first v) 'ok)))
  #:extract (λ (v) (list (second v)))
  #:reconstruct (λ (cs) (list 'ok (first cs)))
  #:component-lattices (list term-lattice-spec)
  #:domain 'data
  #:sample '(ok v))

;; err: error
(register-ctor! 'err
  #:arity 1
  #:recognizer (λ (v) (and (list? v) (= (length v) 2) (eq? (first v) 'err)))
  #:extract (λ (v) (list (second v)))
  #:reconstruct (λ (cs) (list 'err (first cs)))
  #:component-lattices (list term-lattice-spec)
  #:domain 'data
  #:sample '(err e))

;; ========================================
;; Session Constructor Registrations (System 3) — SRE Track 1 Phase 3
;; ========================================
;;
;; Session types use Racket structs (sess-send, sess-recv, etc.) from sessions.rkt.
;; Component lattices: type-lattice-spec for payload types, session-lattice-spec for continuations.
;; The duality relation uses dual-pairs on the domain to know that Send↔Recv, etc.
;; Sub-relation derivation: same-domain (session) → duality, cross-domain (type) → equality.
;;
;; Note: Choice/Offer have branch lists (variable arity) — not registered as ctor-desc.
;; They're handled specially by the duality propagator.

;; Send: type (payload), cont (continuation)
(register-ctor! 'sess-send
  #:arity 2
  #:recognizer sess-send?
  #:extract (λ (v) (list (sess-send-type v) (sess-send-cont v)))
  #:reconstruct (λ (cs) (sess-send (first cs) (second cs)))
  #:component-lattices (list type-lattice-spec session-lattice-spec)
  #:component-variances '(cross-domain same-domain)  ;; Track 2F: payload crosses domains, continuation stays
  #:domain 'session
  #:sample (sess-send (expr-tycon 'Int) (sess-end)))

;; Recv: type (payload), cont (continuation)
(register-ctor! 'sess-recv
  #:arity 2
  #:recognizer sess-recv?
  #:extract (λ (v) (list (sess-recv-type v) (sess-recv-cont v)))
  #:reconstruct (λ (cs) (sess-recv (first cs) (second cs)))
  #:component-lattices (list type-lattice-spec session-lattice-spec)
  #:component-variances '(cross-domain same-domain)
  #:domain 'session
  #:sample (sess-recv (expr-tycon 'Int) (sess-end)))

;; DSend: type (payload), cont (continuation under binder — de Bruijn)
;; SRE Track 1B Phase 4: binder-open-fn opens the binder by substituting
;; a fresh fvar for bvar(0) in the continuation.
(register-ctor! 'sess-dsend
  #:arity 2
  #:recognizer sess-dsend?
  #:extract (λ (v) (list (sess-dsend-type v) (sess-dsend-cont v)))
  #:reconstruct (λ (cs) (sess-dsend (first cs) (second cs)))
  #:component-lattices (list type-lattice-spec session-lattice-spec)
  #:component-variances '(cross-domain same-domain)
  #:binder-depth 1
  #:domain 'session
  #:sample (sess-dsend (expr-tycon 'Int) (sess-end))
  #:binder-open-fn
  (λ (val sym)
    ;; Open: substitute fresh fvar for bvar(0) in continuation
    (define payload (sess-dsend-type val))
    (define cont (sess-dsend-cont val))
    (define fv (expr-fvar sym))
    (define opened-cont (substS cont 0 fv))
    (values (list payload opened-cont) sym)))

;; DRecv: type (payload), cont (continuation under binder — de Bruijn)
(register-ctor! 'sess-drecv
  #:arity 2
  #:recognizer sess-drecv?
  #:extract (λ (v) (list (sess-drecv-type v) (sess-drecv-cont v)))
  #:reconstruct (λ (cs) (sess-drecv (first cs) (second cs)))
  #:component-lattices (list type-lattice-spec session-lattice-spec)
  #:component-variances '(cross-domain same-domain)
  #:binder-depth 1
  #:domain 'session
  #:sample (sess-drecv (expr-tycon 'Int) (sess-end))
  #:binder-open-fn
  (λ (val sym)
    (define payload (sess-drecv-type val))
    (define cont (sess-drecv-cont val))
    (define fv (expr-fvar sym))
    (define opened-cont (substS cont 0 fv))
    (values (list payload opened-cont) sym)))

;; AsyncSend: type, cont
(register-ctor! 'sess-async-send
  #:arity 2
  #:recognizer sess-async-send?
  #:extract (λ (v) (list (sess-async-send-type v) (sess-async-send-cont v)))
  #:reconstruct (λ (cs) (sess-async-send (first cs) (second cs)))
  #:component-lattices (list type-lattice-spec session-lattice-spec)
  #:component-variances '(cross-domain same-domain)
  #:domain 'session
  #:sample (sess-async-send (expr-tycon 'Int) (sess-end)))

;; AsyncRecv: type, cont
(register-ctor! 'sess-async-recv
  #:arity 2
  #:recognizer sess-async-recv?
  #:extract (λ (v) (list (sess-async-recv-type v) (sess-async-recv-cont v)))
  #:reconstruct (λ (cs) (sess-async-recv (first cs) (second cs)))
  #:component-lattices (list type-lattice-spec session-lattice-spec)
  #:component-variances '(cross-domain same-domain)
  #:domain 'session
  #:sample (sess-async-recv (expr-tycon 'Int) (sess-end)))

;; Mu: body (recursive, body under binder — but session binders use de Bruijn indices,
;; not the type domain's open-expr pattern, so binder-depth=0 for SRE purposes.
;; The "opening" of mu is via unfold-session, not via binder-open-fn.)
(register-ctor! 'sess-mu
  #:arity 1
  #:recognizer sess-mu?
  #:extract (λ (v) (list (sess-mu-body v)))
  #:reconstruct (λ (cs) (sess-mu (first cs)))
  #:component-lattices (list session-lattice-spec)
  #:component-variances '(same-domain)  ;; Track 2F: recursive body stays in session domain
  #:domain 'session
  #:sample (sess-mu (sess-svar 0)))
