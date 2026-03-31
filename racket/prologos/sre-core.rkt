#lang racket/base

;; ========================================================================
;; SRE Core — Domain-Parameterized Structural Reasoning Engine
;; ========================================================================
;;
;; Extracted from elaborator-network.rkt (PUnify structural decomposition).
;; Parameterized by sre-domain (lattice ops bundled as first-class data).
;;
;; This module is the operational semantics of NTT's `:lattice :structural`.
;; Every function here is domain-neutral: the domain-specific behavior comes
;; from the sre-domain struct and the ctor-desc registry.
;;
;; SRE Track 0: Form Registry — Domain-Parameterized Structural Decomposition
;; Design: docs/tracking/2026-03-22_SRE_TRACK0_FORM_REGISTRY_DESIGN.md
;;
;; Layer 1 (within-domain) only. Cross-domain bridging (Layer 2: Galois
;; connections) is the caller's responsibility. See design §4.3.

(require racket/list
         racket/set
         racket/string
         "propagator.rkt"
         "ctor-registry.rkt")

(provide
 ;; Domain spec
 (struct-out sre-domain)
 sre-domain-merge

 ;; Relation spec (SRE Track 1 + Track 2F)
 (struct-out sre-relation)
 sre-equality
 sre-subtype
 sre-subtype-reverse
 sre-duality
 sre-phantom
 ;; Track 2F: algebraic foundation
 derive-sub-relation
 sre-relation-has-property?
 ;; Track 2G: algebraic domain properties
 prop-unknown prop-confirmed prop-refuted prop-contradicted
 property-value-join
 sre-domain-has-property?
 ;; Track 2G: domain registry
 register-domain!
 lookup-domain
 all-registered-domains
 ;; Track 2G: property inference
 axiom-confirmed axiom-confirmed? axiom-confirmed-count
 axiom-refuted axiom-refuted? axiom-refuted-witness
 axiom-untested
 infer-domain-properties
 ;; Track 2G: implication rules + resolution
 (struct-out implication-rule)
 standard-implication-rules
 derive-composite-properties
 resolve-domain-properties
 ;; Track 2G: diagnostic reporting + property-gated behavior
 format-property-profile
 resolve-and-report-properties
 with-domain-property
 select-by-property

 ;; Core SRE functions
 sre-identify-sub-cell
 sre-get-or-create-sub-cells
 sre-constructor-tag
 sre-make-structural-relate-propagator
 sre-maybe-decompose
 sre-decompose-generic  ;; PAR Track 1: called by topology stratum
 sre-decompose-generic
 sre-make-generic-reconstructor

 ;; Polarity inference (SRE Track 1)
 variance-join
 variance-flip

 ;; Debug parameter
 current-sre-debug?)

;; ========================================================================
;; Domain Spec
;; ========================================================================
;;
;; A domain spec bundles the lattice operations needed for structural
;; reasoning in a particular domain. It's a first-class data value —
;; not a set of callbacks scattered across Racket parameters.
;;
;; Design note (D.2 critique): meta-recognizer is PURE — safe to cache,
;; no ambient state. meta-resolver is CONTEXT-DEPENDENT — it reads from
;; the current elab-network (type domain) or narrowing context (term domain).
;; The domain spec is created per-command, so the resolver closure always
;; reads from the correct context.
;;
;; Design note: The lattice ordering is NOT a separate field because
;; merge IS the ordering for join-semilattices (a ≤ b iff merge(a,b) = b).
;; Subtyping variance (SRE Track 1) uses per-component annotations on
;; ctor-desc, not a domain-level ordering function.
;;
;; Design note: Domain identity is by name symbol. Two domains that
;; share a lattice are treated as separate — their cells don't interact
;; without a bridge. This is a deliberate isolation choice.

(struct sre-domain
  (name              ; symbol: 'type, 'term, 'session, ...
   merge-registry    ; SRE Track 1B: (relation-name → merge-fn)
                     ; Replaces fixed lattice-merge + subtype-merge fields.
                     ; Each relation has its own lattice ordering on the same carrier:
                     ;   equality → flat merge (Nat ≠ Int → top)
                     ;   subtype → subtype-ordering merge (Nat ≤ Int → Int)
                     ;   duality → same as equality (structural swap, not ordering)
                     ; Implemented as `case` dispatch (zero overhead, compiles to jump table).
                     ; Error on unregistered relation (fail-fast).
   contradicts?      ; (val → bool) — is this value top/contradiction?
   bot?              ; (val → bool) — is this value bottom?
   bot-value         ; the bottom element itself
   top-value         ; SRE Track 1: the contradiction/top element.
   meta-recognizer   ; (expr → bool) | #f — pure structural check: is this a meta/var ref?
   meta-resolver     ; (expr → cell-id | #f) | #f — context-dependent: what cell?
   dual-pairs        ; SRE Track 1: '((Send . Recv) ...) or #f
   property-cell-ids ; SRE Track 2G: (hasheq property-name → cell-id) — on-network cells (Phase 6)
   declared-properties ; SRE Track 2G: (hasheq property-name → property-value) — declarations (Phase 4)
   )
  #:transparent)

;; Merge lookup: gets the merge function for a given relation from the domain registry.
(define (sre-domain-merge domain relation)
  ((sre-domain-merge-registry domain) (sre-relation-name relation)))

;; ========================================================================
;; SRE Track 2G: Algebraic Domain Property Infrastructure
;; ========================================================================
;; 4-valued property lattice: ⊥ (unknown), #t (confirmed), #f (refuted), ⊤ (contradicted)
;; Properties are cells on the network. has-property? is a pure cell read.

;; Property value constants
(define prop-unknown 'prop-unknown)   ;; ⊥
(define prop-confirmed 'prop-confirmed)  ;; #t
(define prop-refuted 'prop-refuted)    ;; #f
(define prop-contradicted 'prop-contradicted)  ;; ⊤

;; Property lattice join (4-valued)
(define (property-value-join a b)
  (cond
    [(eq? a prop-unknown) b]
    [(eq? b prop-unknown) a]
    [(eq? a b) a]  ;; confirmed⊔confirmed, refuted⊔refuted
    [(eq? a prop-contradicted) prop-contradicted]
    [(eq? b prop-contradicted) prop-contradicted]
    ;; confirmed ⊔ refuted = contradicted (declaration vs inference disagree)
    [else prop-contradicted]))

;; Query: does domain have this algebraic property?
;; Returns #t only for prop-confirmed. Everything else → #f (capability gating).
;;
;; Two sources (Phase 4: declaration hash, Phase 6: cells on network):
;; 1. Check property-cell-ids for a cell → read from network
;; 2. Fall back to declared-properties hash
;; After Phase 6 wiring, all properties are on cells. Before: hash only.
(define (sre-domain-has-property? domain property-name #:net [net #f])
  ;; First: check cell (if exists and network provided)
  (define cell-ids (sre-domain-property-cell-ids domain))
  (define cell-id (and net (hash-ref cell-ids property-name #f)))
  (cond
    [(and cell-id net)
     (define val (net-cell-read net cell-id))
     (eq? val prop-confirmed)]
    ;; Fallback: check declared-properties hash (Phase 4)
    [else
     (define declared (sre-domain-declared-properties domain))
     (eq? (hash-ref declared property-name prop-unknown) prop-confirmed)]))

;; ========================================================================
;; SRE Track 2G Phase 1.5: Domain Registry
;; ========================================================================
;; Central registry of all SRE domains. Monotone: domains only added.
;; Scaffolding: module-level hash (same pattern as ctor-registry.rkt).
;; Track 3-4 refinement: cell on persistent registry network (pnet-cacheable).
;; The register-domain! / lookup-domain API is the permanent interface.

(define domain-registry (make-hasheq))  ;; mutable: domain-name → sre-domain

(define (register-domain! domain)
  (define name (sre-domain-name domain))
  (when (hash-has-key? domain-registry name)
    (eprintf "WARNING: domain ~a already registered, overwriting\n" name))
  (hash-set! domain-registry name domain))

(define (lookup-domain name)
  (hash-ref domain-registry name #f))

(define (all-registered-domains)
  (hash-values domain-registry))

;; ========================================================================
;; SRE Track 2G Phase 5: Property Inference (Pocket Universe Evidence)
;; ========================================================================
;; Axiom testing: sample domain values, test algebraic axioms.
;; Evidence accumulation: per-axiom status (untested/confirmed/refuted).
;; Eager at domain registration. Validates declarations + discovers undeclared.

;; Per-axiom evidence (D.3 F2)
(struct axiom-confirmed (count) #:transparent)
(struct axiom-refuted (witness) #:transparent)
(define axiom-untested 'axiom-untested)

;; Test commutativity of join: a ⊔ b = b ⊔ a
(define (test-commutative-join domain samples)
  (define merge-fn (sre-domain-merge-registry domain))
  (define join (merge-fn 'equality))  ;; equality merge = lattice join
  (for/fold ([status (axiom-confirmed 0)])
            ([i (in-range (length samples))]
             [a (in-list samples)]
             #:break (axiom-refuted? status))
    (for/fold ([st status])
              ([b (in-list samples)]
               #:break (axiom-refuted? st))
      (if (equal? (join a b) (join b a))
          (axiom-confirmed (+ (axiom-confirmed-count st) 1))
          (axiom-refuted (list a b))))))

;; Test associativity of join: (a ⊔ b) ⊔ c = a ⊔ (b ⊔ c)
(define (test-associative-join domain samples)
  (define join ((sre-domain-merge-registry domain) 'equality))
  (for/fold ([status (axiom-confirmed 0)])
            ([a (in-list samples)]
             #:break (axiom-refuted? status))
    (for/fold ([st status])
              ([b (in-list samples)]
               #:break (axiom-refuted? st))
      (for/fold ([st2 st])
                ([c (in-list samples)]
                 #:break (axiom-refuted? st2))
        (if (equal? (join (join a b) c) (join a (join b c)))
            (axiom-confirmed (+ (axiom-confirmed-count st2) 1))
            (axiom-refuted (list a b c)))))))

;; Test idempotence of join: a ⊔ a = a
(define (test-idempotent-join domain samples)
  (define join ((sre-domain-merge-registry domain) 'equality))
  (for/fold ([status (axiom-confirmed 0)])
            ([a (in-list samples)]
             #:break (axiom-refuted? status))
    (if (equal? (join a a) a)
        (axiom-confirmed (+ (axiom-confirmed-count status) 1))
        (axiom-refuted (list a)))))

;; Test distributivity: a ⊔ (b ⊓ c) = (a ⊔ b) ⊓ (a ⊔ c)
;; Requires meet-fn. Returns axiom-untested if no meet available.
(define (test-distributive domain samples meet-fn)
  (if (not meet-fn)
      axiom-untested
      (let ([join ((sre-domain-merge-registry domain) 'equality)])
        (for/fold ([status (axiom-confirmed 0)])
                  ([a (in-list samples)]
                   #:break (axiom-refuted? status))
          (for/fold ([st status])
                    ([b (in-list samples)]
                     #:break (axiom-refuted? st))
            (for/fold ([st2 st])
                      ([c (in-list samples)]
                       #:break (axiom-refuted? st2))
              (define lhs (join a (meet-fn b c)))
              (define rhs (meet-fn (join a b) (join a c)))
              (if (equal? lhs rhs)
                  (axiom-confirmed (+ (axiom-confirmed-count st2) 1))
                  (axiom-refuted (list a b c)))))))))

;; Infer properties for a domain from sample values.
;; Returns updated declared-properties hash with inference results.
;; Declarations take priority — inference validates but doesn't override #t declarations.
;; If inference finds counterexample for a declared #t property → prop-contradicted.
(define (infer-domain-properties domain samples #:meet-fn [meet-fn #f])
  (define declared (sre-domain-declared-properties domain))
  (define (update-property props name test-result)
    (define current (hash-ref props name prop-unknown))
    (define inferred
      (cond
        [(eq? test-result axiom-untested) prop-unknown]
        [(axiom-confirmed? test-result) prop-confirmed]
        [(axiom-refuted? test-result) prop-refuted]))
    ;; Join declared value with inferred value
    (hash-set props name (property-value-join current inferred)))

  (define props-0
    (update-property declared 'commutative-join
                     (test-commutative-join domain samples)))
  (define props-1
    (update-property props-0 'associative-join
                     (test-associative-join domain samples)))
  (define props-2
    (update-property props-1 'idempotent-join
                     (test-idempotent-join domain samples)))
  (define props-3
    (if meet-fn
        (update-property props-2 'distributive
                         (test-distributive domain samples meet-fn))
        props-2))
  props-3)

;; ========================================================================
;; SRE Track 2G Phase 6: Implication Rules (Derive Composite Properties)
;; ========================================================================
;; Composite properties are conjunctions of atomic properties.
;; No hierarchy. Flat composition via implication rules.
;;
;; Scaffolding: eager function call after inference.
;; Permanent: implication rules are data. Track 3-4 refinement:
;; Pocket Universe internal stratification with actual propagators.

;; Implication rule: if all source properties are confirmed → write target confirmed.
(struct implication-rule (name sources target) #:transparent)

;; Built-in implication rules
(define standard-implication-rules
  (list
   (implication-rule 'heyting
                     '(distributive has-pseudo-complement)
                     'heyting)
   (implication-rule 'boolean
                     '(heyting has-complement)
                     'boolean)))

;; Derive composite properties from atomic ones.
;; Reads source properties, writes derived property using property-value-join.
;; Returns updated properties hash.
(define (derive-composite-properties props [rules standard-implication-rules])
  (for/fold ([p props])
            ([rule (in-list rules)])
    (define sources-satisfied?
      (for/and ([src (in-list (implication-rule-sources rule))])
        (eq? (hash-ref p src prop-unknown) prop-confirmed)))
    (define any-source-refuted?
      (for/or ([src (in-list (implication-rule-sources rule))])
        (let ([v (hash-ref p src prop-unknown)])
          (or (eq? v prop-refuted) (eq? v prop-contradicted)))))
    (define derived-value
      (cond
        [sources-satisfied? prop-confirmed]
        [any-source-refuted? prop-refuted]  ;; if any source is refuted, derived is refuted
        [else prop-unknown]))  ;; sources still unknown → derived unknown
    (hash-set p (implication-rule-target rule)
              (property-value-join (hash-ref p (implication-rule-target rule) prop-unknown)
                                  derived-value))))

;; Full property resolution: declare → infer → derive implications.
;; Called at domain registration time. Returns final properties hash.
(define (resolve-domain-properties domain samples #:meet-fn [meet-fn #f])
  (define after-inference
    (infer-domain-properties domain samples #:meet-fn meet-fn))
  (derive-composite-properties after-inference))

;; ========================================================================
;; SRE Track 2G Phase 7a: Diagnostic Property Reporting
;; ========================================================================
;; Formats the algebraic property profile of a domain with evidence details.
;; Output: string (cell-compatible for network in Track 3-4).

(define (format-property-profile domain-name properties inference-evidence)
  (define lines
    (for/list ([(prop val) (in-hash properties)])
      (define evidence-detail
        (let ([ev (hash-ref inference-evidence prop #f)])
          (cond
            [(not ev) ""]
            [(axiom-confirmed? ev)
             (format " (~a tests)" (axiom-confirmed-count ev))]
            [(axiom-refuted? ev)
             (format " (counterexample: ~a)"
                     (string-join (map (lambda (v) (format "~a" v))
                                       (axiom-refuted-witness ev))
                                 ", "))]
            [else ""])))
      (format "  ~a: ~a~a" prop val evidence-detail)))
  (string-append
   (format "Domain '~a algebraic profile:\n" domain-name)
   (string-join (sort lines string<?) "\n")))

;; Run full property resolution and report diagnostic.
;; Returns: (values final-properties report-string)
(define (resolve-and-report-properties domain samples #:meet-fn [meet-fn #f])
  ;; Step 1: Infer (produces inference evidence)
  (define after-inference
    (infer-domain-properties domain samples #:meet-fn meet-fn))
  ;; Step 2: Build evidence map for reporting
  (define evidence
    (for/hasheq ([prop (in-list '(commutative-join associative-join idempotent-join distributive))])
      (define test-fn
        (case prop
          [(commutative-join) test-commutative-join]
          [(associative-join) test-associative-join]
          [(idempotent-join) test-idempotent-join]
          [(distributive) (lambda (d s) (test-distributive d s meet-fn))]
          [else (lambda (d s) axiom-untested)]))
      (values prop (test-fn domain samples))))
  ;; Step 3: Derive composite properties
  (define final-props (derive-composite-properties after-inference))
  ;; Step 4: Format report
  (define report (format-property-profile (sre-domain-name domain) final-props evidence))
  (values final-props report))

;; ========================================================================
;; SRE Track 2G Phase 7b: Property-Gated Behavior
;; ========================================================================
;; Pattern for code that branches on domain algebraic properties.
;; Future consumers (Heyting error reporting, CDCL, backward propagation)
;; plug into this pattern. When properties change (e.g., type lattice
;; redesign makes type domain Heyting), behavior activates automatically.

;; Execute then-fn if domain has property, else-fn otherwise.
(define (with-domain-property domain property-name then-fn else-fn)
  (if (sre-domain-has-property? domain property-name)
      (then-fn)
      (else-fn)))

;; Select from a list of (property-name . behavior-fn) pairs.
;; Returns the first behavior whose property is confirmed, or default-fn.
(define (select-by-property domain property-behaviors default-fn)
  (let loop ([rest property-behaviors])
    (cond
      [(null? rest) (default-fn)]
      [(sre-domain-has-property? domain (caar rest))
       ((cdar rest))]
      [else (loop (cdr rest))])))

;; Debug mode: enables idempotency assertions (D.2 critique)
(define current-sre-debug? (make-parameter #f))

;; ========================================================================
;; Polarity Inference (SRE Track 1)
;; ========================================================================
;;
;; Infer variance annotations for type parameters from constructor field
;; positions. Uses iterative fixpoint on the 4-element lattice {ø, +, -, =}.
;;
;; Polarity rules:
;; - Direct occurrence of param → covariant (+)
;; - Occurrence in contravariant position (e.g., Pi domain) → contravariant (-)
;; - Occurrence in both positions → invariant (=)
;; - No occurrence → phantom (ø)
;;
;; Fixpoint handles recursive types: `data List A := nil | cons A (List A)`
;; - Start with ø for all params
;; - Propagate polarity through fields (including recursive occurrences)
;; - Converge in 2-3 iterations on the finite lattice
;;
;; Known limitations:
;; - HKT parameters treated as invariant (safe default)
;; - GADTs: out of scope (would need equational constraint analysis)
;; - Mutual recursion: needs simultaneous iteration over all types in group

;; Join two variance values: polarity lattice join
(define (variance-join a b)
  (cond
    [(eq? a b) a]
    [(eq? a 'ø) b]
    [(eq? b 'ø) a]
    [else '=]))  ;; + and - join to = (invariant)

;; Flip polarity (for contravariant positions)
(define (variance-flip v)
  (case v
    [(+) '-]
    [(-) '+]
    [(=) '=]
    [(ø) 'ø]))

;; ========================================================================
;; SRE Relation (Track 1)
;; ========================================================================
;;
;; A first-class structural relation. Parameterizes how the SRE propagates
;; between cell pairs.
;;
;; Semantic distinction (D.4 clarification):
;; - Equality and duality are INFORMATION PROPAGATORS: they write new values
;;   into cells, moving them up the lattice.
;; - Subtyping is a STRUCTURAL CHECKER via propagation infrastructure: it
;;   fires when cells are ground, verifies the relationship, and signals
;;   contradiction on failure. Does NOT write new information.
;;
;; name:            symbol — 'equality, 'subtype, 'subtype-reverse, 'duality, 'phantom
;; sub-relation-fn: (relation ctor-desc component-index domain → relation)
;;   Given the parent relation, the constructor descriptor, the component
;;   index, and the domain, returns the sub-cell relation for that component.
;;   For equality: always equality.
;;   For subtyping: uses component-variances from ctor-desc.
;;   For duality: uses component-lattices (same-domain → duality, cross → equality).

(struct sre-relation
  (name
   ;; --- Track 2F: Algebraic Foundation ---
   properties                 ;; (seteq symbol): algebraic properties of this endomorphism.
                              ;; Relation-level ONLY (not domain-level — see Track 2G).
                              ;; Valid: 'identity, 'order-preserving, 'antitone, 'involutive,
                              ;;   'idempotent, 'trivial, 'requires-binder-opening
   propagator-ctor            ;; (domain cell-a cell-b relation → (net → net)) or #f
                              ;; Fire function factory for this relation kind.
   merge-key)                 ;; symbol: key for domain merge-registry lookup.
                              ;; Allows subtype/subtype-reverse to share a merge entry.
  #:transparent)

;; --- Built-in relations ---
;;
;; Track 2F: Each relation carries algebraic properties and a merge-key.
;; The sub-relation-fn closures are LEGACY — callers migrating to
;; derive-sub-relation (Phase 2). Closures removed in Phase 7.
;;
;; Endomorphism ring decomposition (the variance-map table):
;;
;; | Variance      | equality | subtype | sub-reverse | duality  | phantom |
;; |---------------|----------|---------|-------------|----------|---------|
;; | + (covariant) | equality | subtype | sub-reverse | —        | phantom |
;; | - (contra)    | equality | sub-rev | subtype     | —        | phantom |
;; | = (invariant) | equality | equality| equality    | equality | phantom |
;; | ø (phantom)   | phantom  | phantom | phantom     | phantom  | phantom |
;; | same-domain   | —        | —       | —           | duality  | —       |
;; | cross-domain  | —        | —       | —           | equality | —       |
;; | #f (unspec)   | equality | equality| equality    | equality | phantom |

;; Equality: identity endomorphism. Sub-relation always equality.
(define sre-equality
  (sre-relation
   'equality
   (seteq 'identity 'requires-binder-opening)
   #f  ;; propagator-ctor: wired in Phase 4 (defined later in file)
   'equality))

;; Subtype: monotone endomorphism (order-preserving). Sub-relation from variance.
(define sre-subtype
  (sre-relation
   'subtype
   (seteq 'order-preserving)
   #f  ;; propagator-ctor: wired in Phase 4
   'subtype))

;; Subtype-reverse: flipped monotone (contravariant positions).
(define sre-subtype-reverse
  (sre-relation
   'subtype-reverse
   (seteq 'order-preserving)
   #f  ;; propagator-ctor: wired in Phase 4
   'subtype))  ;; same merge-key as subtype

;; Duality: antitone involution. Constructor pairing (Send ↔ Recv).
;; Sub-relation: same-domain → duality, cross-domain → equality.
(define sre-duality
  (sre-relation
   'duality
   (seteq 'antitone 'involutive)
   #f  ;; propagator-ctor: wired in Phase 4
   'duality))

;; Phantom: zero endomorphism. No constraint.
(define sre-phantom
  (sre-relation
   'phantom
   (seteq 'trivial)
   #f  ;; propagator-ctor: wired in Phase 4
   'phantom))

;; --- Track 2F: Variance-map registry ---
;; Defined AFTER all 5 relations (D.3 E1: avoids circular reference).
;; Maps (relation, variance) → sub-relation struct value.
;; The endomorphism ring decomposition as data.

(define variance-maps
  (hasheq
   'equality       (hasheq '+ sre-equality  '- sre-equality  '= sre-equality  'ø sre-phantom
                           'same-domain sre-equality  'cross-domain sre-equality  #f sre-equality)
   'subtype        (hasheq '+ sre-subtype  '- sre-subtype-reverse  '= sre-equality  'ø sre-phantom
                           'same-domain sre-subtype  'cross-domain sre-equality  #f sre-equality)
   'subtype-reverse (hasheq '+ sre-subtype-reverse  '- sre-subtype  '= sre-equality  'ø sre-phantom
                            'same-domain sre-subtype-reverse  'cross-domain sre-equality  #f sre-equality)
   'duality        (hasheq 'same-domain sre-duality  'cross-domain sre-equality  '= sre-equality
                           'ø sre-phantom  #f sre-equality)
   'phantom        (hasheq '+ sre-phantom  '- sre-phantom  '= sre-phantom  'ø sre-phantom
                           'same-domain sre-phantom  'cross-domain sre-phantom  #f sre-phantom)))

;; derive-sub-relation: table-driven sub-relation derivation.
;; Replaces the 3 hand-written sub-relation-fn closures.
;; Returns an sre-relation struct value, not a symbol.
(define (derive-sub-relation relation variance)
  (define rel-name (sre-relation-name relation))
  (define vmap (hash-ref variance-maps rel-name #f))
  (if vmap
      (hash-ref vmap variance
                (λ () (error 'derive-sub-relation
                             "no sub-relation for variance ~a under ~a"
                             variance rel-name)))
      (error 'derive-sub-relation
             "no variance-map registered for relation: ~a" rel-name)))

;; Property check helper
(define (sre-relation-has-property? relation prop)
  (set-member? (sre-relation-properties relation) prop))

;; ========================================================================
;; sre-identify-sub-cell
;; ========================================================================
;;
;; Domain-parameterized version of identify-sub-cell.
;; Was: elaborator-network.rkt:317, hardcoded to type domain.
;;
;; Creates or reuses a sub-cell for a decomposed component expression.
;; - Meta/var ref (recognized by domain's meta-recognizer): reuse existing cell
;; - Bot value: fresh bot cell
;; - Concrete value: fresh cell initialized to the expression value

(define (sre-identify-sub-cell net domain expr)
  (define recognizer (sre-domain-meta-recognizer domain))
  (define resolver (sre-domain-meta-resolver domain))
  (define merge (sre-domain-merge domain sre-equality))
  (define contradicts? (sre-domain-contradicts? domain))
  (define bot? (sre-domain-bot? domain))
  (define bot-val (sre-domain-bot-value domain))
  (cond
    ;; Meta/var ref → reuse existing cell
    [(and recognizer (recognizer expr))
     (define cid (and resolver (resolver expr)))
     (if cid
         (values net cid)
         ;; Recognized as meta but no cell mapping → fresh bot cell
         (net-new-cell net bot-val merge contradicts?))]
    ;; Bot → fresh bot cell
    [(bot? expr)
     (net-new-cell net bot-val merge contradicts?)]
    ;; Concrete value → fresh cell initialized to value
    [else
     (net-new-cell net expr merge contradicts?)]))

;; ========================================================================
;; sre-get-or-create-sub-cells
;; ========================================================================
;;
;; Domain-parameterized version of get-or-create-sub-cells.
;; Was: elaborator-network.rkt:338, called identify-sub-cell (type-only).
;;
;; Checks decomp registry first — if cell already decomposed, reuse sub-cells.
;; Otherwise, create sub-cells for each component and register.
;; Returns (values net* sub-cell-ids).

(define (sre-get-or-create-sub-cells net domain cell-id tag components)
  (define existing (net-cell-decomp-lookup net cell-id))
  (cond
    [(not (eq? existing 'none))
     ;; Already decomposed — reuse existing sub-cells
     (values net (cdr existing))]
    [else
     ;; Create sub-cells for each component
     (define-values (net* sub-ids-rev)
       (for/fold ([n net] [ids '()])
                 ([comp (in-list components)])
         (define-values (n* cid) (sre-identify-sub-cell n domain comp))
         (values n* (cons cid ids))))
     (define sub-ids (reverse sub-ids-rev))
     ;; Register in decomp registry
     (define net** (net-cell-decomp-insert net* cell-id tag sub-ids))
     (values net** sub-ids)]))

;; ========================================================================
;; sre-constructor-tag
;; ========================================================================
;;
;; Domain-parameterized version of type-constructor-tag.
;; Was: elaborator-network.rkt:302, hardcoded domain='type.
;;
;; Returns the constructor tag for a compound value, or #f for atoms/bot/top.

(define (sre-constructor-tag domain expr)
  (define bot? (sre-domain-bot? domain))
  (define contradicts? (sre-domain-contradicts? domain))
  (cond
    [(bot? expr) #f]
    [(contradicts? expr) #f]
    [else
     (define desc (ctor-tag-for-value expr))
     (and desc
          (eq? (ctor-desc-domain desc) (sre-domain-name domain))
          (ctor-desc-tag desc))]))

;; ========================================================================
;; sre-make-generic-reconstructor
;; ========================================================================
;;
;; Domain-parameterized version of make-generic-reconstructor.
;; Was: elaborator-network.rkt:788, hardcoded type-bot?/type-top?.
;;
;; Reads sub-cells, reconstructs parent. If any sub-cell is bot, waits.
;; If any sub-cell is contradiction, propagates to parent.

(define (sre-make-generic-reconstructor domain parent-cell sub-cells desc)
  (define bot? (sre-domain-bot? domain))
  (define contradicts? (sre-domain-contradicts? domain))
  (lambda (net)
    (define vals (map (λ (sc) (net-cell-read net sc)) sub-cells))
    (cond
      [(ormap bot? vals) net]  ;; wait for more info
      [(ormap contradicts? vals)
       ;; Propagate contradiction to parent
       ;; Use the first contradicted value as the contradiction signal
       (define top-val (findf contradicts? vals))
       (net-cell-write net parent-cell top-val)]
      [else
       (net-cell-write net parent-cell
                       ((ctor-desc-reconstruct-fn desc) vals))])))

;; ========================================================================
;; sre-decompose-generic
;; ========================================================================
;;
;; Domain-parameterized version of decompose-generic.
;; Was: elaborator-network.rkt:803, already mostly generic.
;;
;; Descriptor-driven structural decomposition for binder-depth=0 constructors.
;; Extracts components from both sides, creates sub-cells, adds
;; structural-relate propagators between corresponding sub-cells,
;; adds reconstructors for each side.

(define (sre-decompose-generic net domain cell-a cell-b va vb unified pair-key desc
                                #:relation [relation sre-equality])
  (define tag (ctor-desc-tag desc))
  (define recog (ctor-desc-recognizer-fn desc))
  (define extract (ctor-desc-extract-fn desc))
  (define domain-name (sre-domain-name domain))
  ;; Per-side sources: use original value if it matches.
  ;; Track 1B: for non-equality relations (duality, subtype), when one side
  ;; is bot or doesn't match, use BOT sub-components instead of copying from
  ;; unified. Copying would put un-dualized/un-subtyped values in sub-cells.
  (define src-a (if (recog va) va unified))
  (define use-bot-for-b?
    (and (not (recog vb))
         (not (sre-relation-has-property? relation 'requires-binder-opening))))
  (define src-b (if (recog vb) vb unified))
  ;; Extract components
  (define comps-a (extract src-a))
  (define bot-val (sre-domain-bot-value domain))
  (define comps-b (if use-bot-for-b?
                      (make-list (ctor-desc-arity desc) bot-val)
                      (extract src-b)))
  ;; Get or create sub-cells for each side
  (define-values (net1 subs-a) (sre-get-or-create-sub-cells net domain cell-a tag comps-a))
  (define-values (net2 subs-b) (sre-get-or-create-sub-cells net1 domain cell-b tag comps-b))
  ;; Add structural-relate propagators for each component pair
    ;; Track 2F: sub-cell relation from variance-map table via derive-sub-relation.
  ;; If no component-variances, passes #f → defaults to equality.
  (define variances (ctor-desc-component-variances desc))
  (define net3
    (for/fold ([n net2])
              ([sa (in-list subs-a)]
               [sb (in-list subs-b)]
               [idx (in-naturals)])
      (if (equal? sa sb)
          n
          (let* ([sub-rel (derive-sub-relation relation (if variances (list-ref variances idx) #f))])
            (if (eq? (sre-relation-name sub-rel) 'phantom)
                n  ;; no constraint for phantom components
                (let-values ([(n* _pid)
                              (net-add-propagator n
                                (list sa sb) (list sa sb)
                                (sre-make-structural-relate-propagator
                                 domain sa sb #:relation sub-rel))])
                  n*))))))
  ;; Add generic reconstructors for each side
  ;; (reconstructors are relation-independent — they always rebuild from sub-cells)
  (define-values (net4 _p1)
    (net-add-propagator net3 subs-a (list cell-a)
      (sre-make-generic-reconstructor domain cell-a subs-a desc)))
  (define-values (net5 _p2)
    (net-add-propagator net4 subs-b (list cell-b)
      (sre-make-generic-reconstructor domain cell-b subs-b desc)))
  ;; Register pair as decomposed
  (net-pair-decomp-insert net5 pair-key))

;; ========================================================================
;; sre-maybe-decompose
;; ========================================================================
;;
;; Domain-parameterized version of maybe-decompose.
;; Was: elaborator-network.rkt:842, hardcoded Pi/Sigma/lam case arms.
;;
;; Dispatches structural decomposition based on constructor tag.
;; All constructors go through the descriptor — no hardcoded case arms.
;; Binder-depth>0 constructors require binder-open-fn on their descriptor.
;;
;; NOTE: For Phase 2 migration, Pi/Sigma/lam retain their existing
;; decomposers temporarily (called from the PUnify dispatch layer,
;; not from the SRE). Once binder-open-fn is fully wired, they can
;; be migrated to sre-decompose-binder. See design §4.3.

(define (sre-maybe-decompose net domain cell-a cell-b va vb unified
                             #:relation [relation sre-equality])
  (define tag (sre-constructor-tag domain unified))
  (cond
    [(not tag) net]  ;; Not compound — nothing to decompose
    [else
     (define rel-name (sre-relation-name relation))
     (define pair-key (decomp-key cell-a cell-b rel-name))
     ;; PAR Track 1 D.4: Check if BSP fire round is active.
     ;; If yes → emit request to decomp-request cell (topology stratum processes).
     ;; If no (DFS) → decompose inline (existing behavior, unchanged).
     (if (current-bsp-fire-round?)
         ;; BSP path: emit decomposition request
         (cond
           ;; Binder-depth>0 + requires binder opening → fall through to PUnify
           [(let ([desc (lookup-ctor-desc tag #:domain (sre-domain-name domain))])
              (and desc (> (ctor-desc-binder-depth desc) 0)
                   (sre-relation-has-property? relation 'requires-binder-opening)))
            net]
           [else
            (net-cell-write net decomp-request-cell-id
                            (set (sre-decomp-request pair-key domain cell-a cell-b
                                                     relation '())))])
         ;; DFS path: decompose inline (unchanged from pre-PAR)
         (cond
           [(net-pair-decomp? net pair-key) net]  ;; Already decomposed
           [else
            (define desc (lookup-ctor-desc tag #:domain (sre-domain-name domain)))
            (cond
              [(not desc) net]
              [(zero? (ctor-desc-binder-depth desc))
               (sre-decompose-generic net domain cell-a cell-b va vb unified pair-key desc
                                      #:relation relation)]
              [(sre-relation-has-property? relation 'requires-binder-opening)
               net]
              [else
               (sre-decompose-generic net domain cell-a cell-b va vb unified pair-key desc
                                      #:relation relation)])]))]))

;; ========================================================================
;; sre-make-structural-relate-propagator
;; ========================================================================
;;
;; Domain-parameterized, relation-parameterized structural relate propagator.
;; Was: elaborator-network.rkt:871, hardcoded to type lattice + equality.
;;
;; SRE Track 1: dispatches on relation type:
;; - Equality: reads two cells, merges to join, writes both, decomposes.
;;   This is INFORMATION PROPAGATION — cells move up the lattice.
;; - Subtype: reads two cells, checks a ≤ b, decomposes with variance.
;;   This is STRUCTURAL CHECKING — no writes except contradiction.
;; - Duality: reads two cells, applies dual constructor pairing.
;;   This is INFORMATION PROPAGATION with constructor swapping.
;; - Phantom: no-op (for phantom type parameters).
;;
;; Termination argument:
;; - Equality: decomp registries + lattice-merge monotonicity + no-change guard.
;; - Subtype: no cell writes on success; only contradiction signals (monotone).
;;   Decomposition creates sub-checkers that are strictly smaller.
;; - Duality: involution preserves lattice ordering; no-change guard.
;; Guarantee level: 2 (finite lattice height with fuel guard)

(define (sre-make-structural-relate-propagator domain cell-a cell-b
                                                #:relation [relation sre-equality])
  ;; Track 2F Phase 4: table-driven dispatch (table defined after propagator constructors).
  (define ctor (hash-ref propagator-ctor-table (sre-relation-name relation) #f))
  (if ctor
      (ctor domain cell-a cell-b relation)
      (error 'sre-make-structural-relate-propagator
             "unknown relation: ~a" (sre-relation-name relation))))

;; --- Equality propagator (Track 0 behavior, unchanged) ---
(define (sre-make-equality-propagator domain cell-a cell-b relation)
  (define merge (sre-domain-merge domain sre-equality))
  (define contradicts? (sre-domain-contradicts? domain))
  (define bot? (sre-domain-bot? domain))
  (lambda (net)
    (define va (net-cell-read net cell-a))
    (define vb (net-cell-read net cell-b))
    (cond
      [(and (bot? va) (bot? vb)) net]
      [(bot? va)
       (let ([net* (net-cell-write net cell-a vb)])
         (sre-maybe-decompose net* domain cell-a cell-b va vb vb
                              #:relation relation))]
      [(bot? vb)
       (let ([net* (net-cell-write net cell-b va)])
         (sre-maybe-decompose net* domain cell-a cell-b va vb va
                              #:relation relation))]
      [else
       (define unified (merge va vb))
       (when (current-sre-debug?)
         (unless (equal? (merge unified va) unified)
           (error 'sre-structural-relate
                  "Non-idempotent merge detected for domain ~a: merge(~a, ~a) = ~a but merge(~a, ~a) = ~a"
                  (sre-domain-name domain) va vb unified unified va (merge unified va))))
       (if (contradicts? unified)
           (net-cell-write net cell-a unified)
           (let* ([net*  (net-cell-write net cell-a unified)]
                  [net** (net-cell-write net* cell-b unified)])
             (sre-maybe-decompose net** domain cell-a cell-b va vb unified
                                  #:relation relation)))])))

;; --- Subtype propagator (Track 1: structural checker) ---
;; Checks a ≤ b directionally. Does NOT merge/write cell values.
;; Fires when both cells are non-bot. Decomposes structurally with variance.
;; For subtype-reverse: checks b ≤ a (used for contravariant positions).
;;
;; KEY INSIGHT: The type lattice merge is equality-based (different compound
;; types → top/contradiction). For subtyping, we must decompose structurally
;; BEFORE using the flat lattice check. Strategy:
;; 1. Both compound with same tag? → decompose with variance (structural path)
;; 2. Both atomic? → check flat subtype relationship (flat path)
;; 3. Different tags? → subtype violation
(define (sre-make-subtype-propagator domain cell-a cell-b relation)
  (define contradicts? (sre-domain-contradicts? domain))
  (define bot? (sre-domain-bot? domain))
  (define sub-merge (sre-domain-merge domain relation))
  (define reversed? (eq? (sre-relation-name relation) 'subtype-reverse))
  (lambda (net)
    (define va (net-cell-read net cell-a))
    (define vb (net-cell-read net cell-b))
    (cond
      ;; Wait for both cells to have values
      [(or (bot? va) (bot? vb)) net]
      [else
       ;; Direction: check lhs ≤ rhs
       (let* ([lhs (if reversed? vb va)]
              [rhs (if reversed? va vb)]
              [tag-lhs (sre-constructor-tag domain lhs)]
              [tag-rhs (sre-constructor-tag domain rhs)])
         (cond
           ;; Both compound with same tag → structural decomposition with variance
           [(and tag-lhs tag-rhs (eq? tag-lhs tag-rhs))
            (sre-maybe-decompose net domain cell-a cell-b va vb lhs
                                 #:relation relation)]
           ;; At least one atomic, or different compound tags →
           ;; use subtype-merge lattice (proper subtype ordering).
           ;; subtype-merge(a, b) = b if a <: b, = a if b <: a,
           ;; = top if incomparable. This is fully on-network.
           [else
            (if (not sub-merge)
                ;; No subtype-merge → domain doesn't support subtyping.
                ;; No merge for this relation → fall back to equality merge.
                (let ([eq-merged ((sre-domain-merge domain sre-equality) lhs rhs)])
                  (if (contradicts? eq-merged)
                      (net-cell-write net cell-a eq-merged)
                      net))
                ;; Use the subtype-ordering merge
                (let ([merged (sub-merge lhs rhs)])
                  (cond
                    [(contradicts? merged)
                     ;; Incomparable → subtype violation
                     (net-cell-write net cell-a merged)]
                    [(equal? merged rhs)
                     ;; merged = rhs → lhs ≤ rhs holds (lhs joins up to rhs)
                     net]
                    [(equal? merged lhs)
                     ;; merged = lhs → rhs ≤ lhs (wrong direction) → violation
                     ;; Unless lhs = rhs (handled by equal? in sub-merge)
                     (net-cell-write net cell-a
                       ((sre-domain-merge domain sre-equality) lhs rhs))]
                    [else
                     ;; merged ≠ either → shouldn't happen for well-formed subtype merge
                     net])))]))])))

;; --- Duality propagator (SRE Track 1 Phase 3) ---
;; Duality is an involution: dual(dual(x)) = x.
;; For session types: Send↔Recv, AsyncSend↔AsyncRecv, Choice↔Offer.
;;
;; Strategy: when one cell has a concrete session value, look up the dual
;; constructor via dual-pairs, reconstruct with swapped tag, write to other cell.
;; Then structurally decompose: payload sub-cells get equality, continuation
;; sub-cells get duality (derived from component lattice types per D.3 design).
;;
;; This is INFORMATION PROPAGATION (like equality), not checking (like subtyping).
;; Both cells move toward compatible values via the dual mapping.
(define (sre-make-duality-propagator domain cell-a cell-b relation)
  (define merge (sre-domain-merge domain sre-equality))
  (define contradicts? (sre-domain-contradicts? domain))
  (define bot? (sre-domain-bot? domain))
  (define pairs (sre-domain-dual-pairs domain))
  (unless pairs
    (error 'sre-make-duality-propagator
           "domain ~a has no dual-pairs — cannot create duality propagator"
           (sre-domain-name domain)))
  ;; Build lookup tables from dual-pairs: tag → dual-tag
  (define dual-tag-map
    (let ([h (make-hasheq)])
      (for ([p (in-list pairs)])
        (hash-set! h (car p) (cdr p))
        (hash-set! h (cdr p) (car p)))
      h))
  (define (lookup-dual-tag tag)
    (hash-ref dual-tag-map tag #f))
  (lambda (net)
    (define va (net-cell-read net cell-a))
    (define vb (net-cell-read net cell-b))
    (cond
      ;; Both bot: wait
      [(and (bot? va) (bot? vb)) net]
      ;; One has value: compute dual, write to other, then decompose
      [(bot? vb)
       (sre-duality-propagate-one net domain cell-a cell-b va
                                   lookup-dual-tag relation)]
      [(bot? va)
       (sre-duality-propagate-one net domain cell-b cell-a vb
                                   lookup-dual-tag relation)]
      ;; Both have values: verify duality holds and decompose
      [else
       (sre-duality-propagate-both net domain cell-a cell-b va vb
                                    lookup-dual-tag relation)])))

;; Helper: one cell has value, propagate dual to other cell
(define (sre-duality-propagate-one net domain from-cell to-cell from-val
                                    lookup-dual-tag relation)
  (define from-tag (sre-constructor-tag domain from-val))
  (cond
    ;; Non-compound (atoms like sess-end, sess-svar): self-dual, write as-is
    [(not from-tag)
     (net-cell-write net to-cell from-val)]
    ;; Compound: look up dual constructor, reconstruct with swapped tag
    [else
     (define dual-tag (lookup-dual-tag from-tag))
     (define from-desc (lookup-ctor-desc from-tag #:domain (sre-domain-name domain)))
     (cond
       [(not from-desc) net]
       [(not dual-tag)
        ;; No dual mapping — self-dual constructor (e.g., mu)
        (define pair-key (decomp-key from-cell to-cell (sre-relation-name relation)))
        ;; PAR Track 1 D.4: dual-path BSP/DFS
        (if (current-bsp-fire-round?)
            (net-cell-write net decomp-request-cell-id
                            (set (sre-decomp-request pair-key domain from-cell to-cell
                                                     relation '())))
            (if (net-pair-decomp? net pair-key)
                net
                (sre-decompose-generic net domain from-cell to-cell
                                       from-val (net-cell-read net to-cell) from-val pair-key from-desc
                                       #:relation relation)))]
       [else
        ;; Dual constructor found.
        ;; DON'T write any value to to-cell yet — the components need to be
        ;; dualized by sub-cell propagators first. The reconstructor propagator
        ;; on to-cell will build the correct dual value from the sub-cells.
        ;; We decompose directly: from-cell gets real sub-cells, to-cell gets
        ;; bot sub-cells. Sub-cell duality/equality propagators push values.
        ;; Then the reconstructor fires and writes the correct compound to to-cell.
        (define dual-desc (lookup-ctor-desc dual-tag #:domain (sre-domain-name domain)))
        (cond
          [(not dual-desc) net]
          [else
           (define pair-key (decomp-key from-cell to-cell (sre-relation-name relation)))
           ;; PAR Track 1 D.4: dual-path BSP/DFS
           (if (current-bsp-fire-round?)
               ;; BSP: emit request
               (net-cell-write net decomp-request-cell-id
                               (set (sre-decomp-request pair-key domain from-cell to-cell
                                                        relation '())))
               ;; DFS: decompose inline
               (if (net-pair-decomp? net pair-key)
                   net
                   (sre-duality-decompose-dual-pair
                    net domain from-cell to-cell from-val (net-cell-read net to-cell)
                    from-desc dual-desc pair-key relation)))])])]))

;; Duality-specific decomposition for dual constructor pairs.
;; Each side uses its OWN descriptor for extraction/reconstruction.
;; Sub-cells are paired by position (Send.type ↔ Recv.type, Send.cont ↔ Recv.cont).
;; Sub-relations derived from component lattice types.
(define (sre-duality-decompose-dual-pair net domain cell-a cell-b va vb
                                          desc-a desc-b pair-key relation)
  (define domain-name (sre-domain-name domain))
  (define bot? (sre-domain-bot? domain))
  (define bot-val (sre-domain-bot-value domain))
  (define extract-a (ctor-desc-extract-fn desc-a))
  (define extract-b (ctor-desc-extract-fn desc-b))
  (define recog-a (ctor-desc-recognizer-fn desc-a))
  (define recog-b (ctor-desc-recognizer-fn desc-b))
  ;; Extract components — handle bot cells by creating bot sub-components
  (define comps-a (if (or (bot? va) (not (recog-a va)))
                      (make-list (ctor-desc-arity desc-a) bot-val)
                      (extract-a va)))
  (define comps-b (if (or (bot? vb) (not (recog-b vb)))
                      (make-list (ctor-desc-arity desc-b) bot-val)
                      (extract-b vb)))
  ;; Get or create sub-cells for each side
  (define tag-a (ctor-desc-tag desc-a))
  (define tag-b (ctor-desc-tag desc-b))
  (define-values (net1 subs-a)
    (sre-get-or-create-sub-cells net domain cell-a tag-a comps-a))
  (define-values (net2 subs-b)
    (sre-get-or-create-sub-cells net1 domain cell-b tag-b comps-b))
  ;; Track 2F Phase 2: sub-relation from variance-map table.
  ;; Duality path falls back to legacy until Phase 3 adds variances.
  (define variances-a (ctor-desc-component-variances desc-a))
  (define net3
    (for/fold ([n net2])
              ([sa (in-list subs-a)]
               [sb (in-list subs-b)]
               [idx (in-naturals)])
      (if (equal? sa sb)
          n
          (let* ([sub-rel (derive-sub-relation relation (if variances-a (list-ref variances-a idx) #f))])
            (if (eq? (sre-relation-name sub-rel) 'phantom)
                n
                (let-values ([(n* _pid)
                              (net-add-propagator n
                                (list sa sb) (list sa sb)
                                (sre-make-structural-relate-propagator
                                 domain sa sb #:relation sub-rel))])
                  n*))))))
  ;; Add reconstructors for each side (using each side's own descriptor)
  (define-values (net4 _p1)
    (net-add-propagator net3 subs-a (list cell-a)
      (sre-make-generic-reconstructor domain cell-a subs-a desc-a)))
  (define-values (net5 _p2)
    (net-add-propagator net4 subs-b (list cell-b)
      (sre-make-generic-reconstructor domain cell-b subs-b desc-b)))
  ;; Register pair as decomposed
  (net-pair-decomp-insert net5 pair-key))

;; Helper: both cells have values, verify duality and decompose
(define (sre-duality-propagate-both net domain cell-a cell-b va vb
                                     lookup-dual-tag relation)
  (define contradicts? (sre-domain-contradicts? domain))
  (define tag-a (sre-constructor-tag domain va))
  (define tag-b (sre-constructor-tag domain vb))
  (cond
    ;; Both non-compound: check they're equal (self-dual atoms)
    [(and (not tag-a) (not tag-b))
     (if (equal? va vb) net
         (net-cell-write net cell-a (sre-domain-top-value domain)))]
    ;; One compound, one not → contradiction
    [(or (not tag-a) (not tag-b))
     (net-cell-write net cell-a (sre-domain-top-value domain))]
    ;; Both compound: check dual pairing
    [else
     (define expected-dual-a (lookup-dual-tag tag-a))
     (define pair-key (decomp-key cell-a cell-b (sre-relation-name relation)))
     ;; PAR Track 1 D.4: BSP does case analysis, emits requests ONLY for decomposition.
     ;; Contradictions are value writes — BSP captures them directly.
     (cond
       [(net-pair-decomp? net pair-key) net]
       ;; Tags are duals → decomposition needed (emit request under BSP)
       [(and expected-dual-a (eq? expected-dual-a tag-b))
        (if (current-bsp-fire-round?)
            (net-cell-write net decomp-request-cell-id
                            (set (sre-decomp-request pair-key domain cell-a cell-b
                                                     relation '())))
            ;; DFS: decompose inline
            (let ([desc-a (lookup-ctor-desc tag-a #:domain (sre-domain-name domain))]
                  [desc-b (lookup-ctor-desc tag-b #:domain (sre-domain-name domain))])
              (if (and desc-a desc-b)
                  (sre-duality-decompose-dual-pair
                   net domain cell-a cell-b va vb desc-a desc-b pair-key relation)
                  net)))]
       ;; Same tag, self-dual → decomposition needed
       [(and (eq? tag-a tag-b) (not expected-dual-a))
        (if (current-bsp-fire-round?)
            (net-cell-write net decomp-request-cell-id
                            (set (sre-decomp-request pair-key domain cell-a cell-b
                                                     relation '())))
            ;; DFS: decompose inline
            (let ([desc (lookup-ctor-desc tag-a #:domain (sre-domain-name domain))])
              (if (and desc (zero? (ctor-desc-binder-depth desc)))
                  (sre-decompose-generic net domain cell-a cell-b va vb va pair-key desc
                                         #:relation relation)
                  net)))]
       ;; Wrong pairing → contradiction (value write, BSP captures directly)
       [else
        (net-cell-write net cell-a (sre-domain-top-value domain))])]))

;; ========================================================================
;; Track 2F Phase 4: Propagator constructor table
;; ========================================================================
;; Defined AFTER all propagator constructors (forward-reference safe).
;; Maps relation name → fire function factory.
;; Adding a new relation kind: add one entry here.
(define propagator-ctor-table
  (hasheq
   'equality        sre-make-equality-propagator
   'subtype         sre-make-subtype-propagator
   'subtype-reverse sre-make-subtype-propagator
   'duality         sre-make-duality-propagator
   'phantom         (λ (domain cell-a cell-b relation) (λ (net) net))))

;; ========================================================================
;; PAR Track 1: SRE topology handler (self-registering at module load time)
;; ========================================================================
;; Processes sre-decomp-request in the BSP topology stratum.
;; Calls sre-decompose-generic (defined above) to create sub-cells,
;; sub-propagators, and reconstructors.
(register-topology-handler!
 (lambda (net req)
   (and (sre-decomp-request? req)
        (sre-decomp-request-domain req)  ;; Only handle SRE-domain requests (non-#f)
        (let ([pair-key (sre-decomp-request-pair-key req)])
          (if (net-pair-decomp? net pair-key)
              net  ;; Already processed — dedup
              (let* ([domain (sre-decomp-request-domain req)]
                     [cell-a (sre-decomp-request-cell-a req)]
                     [cell-b (sre-decomp-request-cell-b req)]
                     [relation (sre-decomp-request-relation req)]
                     [va (net-cell-read net cell-a)]
                     [vb (net-cell-read net cell-b)]
                     [bot? (sre-domain-bot? domain)])
                ;; Track 2F Phase 5: property-driven dispatch, not name-driven.
                (let* ([is-antitone? (sre-relation-has-property? relation 'antitone)]
                       [has-dual-pairs? (and (sre-domain-dual-pairs domain) #t)]
                       ;; Antitone kinds with dual-pairs: one cell may be bot (propagate-one).
                       ;; Non-antitone: both must be non-bot.
                       [both-needed? (not (and is-antitone? has-dual-pairs?))])
                (if (and both-needed? (or (bot? va) (bot? vb)))
                    net
                    (let* (
                           [reversed? (eq? (sre-relation-name relation) 'subtype-reverse)]
                           [lhs (if reversed? vb va)]
                           [tag (sre-constructor-tag domain lhs)]
                           [desc (and tag (lookup-ctor-desc tag
                                           #:domain (sre-domain-name domain)))])
                      (cond
                        ;; Track 2F Phase 5: antitone + dual-pairs → dual-pair decomposition
                        ;; (was: eq? rel-name 'duality)
                        ;; Domain-driven: if domain has dual-pairs AND relation is antitone,
                        ;; use the dual-pair-specific decomposition path.
                        [(and is-antitone? has-dual-pairs?)
                         (let* ([pairs (sre-domain-dual-pairs domain)]
                                [dual-map (let ([h (make-hasheq)])
                                            (when pairs
                                              (for ([p (in-list pairs)])
                                                (hash-set! h (car p) (cdr p))
                                                (hash-set! h (cdr p) (car p))))
                                            h)]
                                [tag-a (sre-constructor-tag domain va)]
                                [tag-b (sre-constructor-tag domain vb)]
                                ;; One cell may be bot — derive missing tag from dual map.
                                ;; Self-dual constructors (no dual mapping): same tag both sides.
                                [tag-a* (or tag-a
                                            (and tag-b (hash-ref dual-map tag-b #f))
                                            tag-b)]  ;; self-dual fallback
                                [tag-b* (or tag-b
                                            (and tag-a (hash-ref dual-map tag-a #f))
                                            tag-a)]  ;; self-dual fallback
                                [desc-a (and tag-a* (lookup-ctor-desc tag-a* #:domain (sre-domain-name domain)))]
                                [desc-b (and tag-b* (lookup-ctor-desc tag-b* #:domain (sre-domain-name domain)))])
                           (if (and desc-a desc-b)
                               (sre-duality-decompose-dual-pair net domain cell-a cell-b va vb
                                                                 desc-a desc-b pair-key relation)
                               net))]
                        ;; Equality/subtype: standard decomposition
                        [(not desc) net]
                        ;; Equality/subtype: standard decomposition
                        [else
                         (sre-decompose-generic net domain cell-a cell-b va vb lhs
                                                pair-key desc
                                                #:relation relation)]))))))))))
