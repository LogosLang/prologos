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
 make-sre-domain                ;; SRE Track 2H: keyword constructor (retires positional debt L4)
 sre-domain-merge
 sre-domain-meet                ;; SRE Track 2I Phase 3c: per-relation meet lookup

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
 lookup-domain-classification  ;; PPN 4C Phase 1f
 all-registered-domains
 ;; Track 2G: property inference
 axiom-confirmed axiom-confirmed? axiom-confirmed-count
 axiom-refuted axiom-refuted? axiom-refuted-witness
 axiom-untested
 test-commutative-join test-associative-join test-idempotent-join test-distributive
 test-sd-vee test-sd-wedge  ;; Track 2I: semidistributivity (Jónsson-Kiefer 1962)
 ;; Track 2I Phase 2: detailed SD evidence for vacuous-vs-non-vacuous reporting
 (struct-out sd-evidence)
 test-sd-vee/detailed test-sd-wedge/detailed
 ;; Track 2I Phase 5: pseudo-complement family
 lattice-leq?
 (struct-out pc-rel-evidence)
 test-pseudo-complement-rel test-pseudo-complement-rel/detailed
 test-pseudo-complement-abs
 test-relatively-complemented
 test-stone-identity
 ;; Track 2I Phase 6: free-lattice membership + modularity
 (struct-out modular-evidence)
 test-modular test-modular/detailed
 (struct-out whitman-evidence)
 test-whitmans-condition test-whitmans-condition/detailed
 test-breadth-bound
 test-sectionally-complemented
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
   declared-properties ; SRE Track 2H: (hasheq relation-name → (hasheq property-name → property-value))
                       ; Was flat hash in Track 2G; now nested by relation (F7, P4, L3).
                       ; Relation-level: endomorphism properties on sre-relation.properties.
                       ; Domain×relation: lattice structure properties here.
   operations          ; SRE Track 2H: (hasheq op-name → (hasheq 'name sym 'fn proc 'arity nat 'properties list))
                       ; Discoverable operations: tensor, pseudo-complement, residual (future).
                       ; Track 4 looks up operations generically via this field.
   classification      ; PPN 4C Phase 1f (2026-04-20): 'structural | 'value | 'unclassified
                       ; Drives net-add-propagator :component-paths enforcement.
                       ;   'structural — cell holds compound value with independent components;
                       ;     propagators reading it MUST declare :component-paths (or get error).
                       ;   'value — cell holds single evolving value; no :component-paths needed.
                       ;   'unclassified (default) — legacy domains, no enforcement (progressive rollout).
                       ; Adding classification to existing domain sites is a per-session activity
                       ; as architectural understanding solidifies.
   meet-registry       ; SRE Track 2I Phase 3c (2026-04-30): (relation-name → meet-fn) | #f
                       ; Parallel to merge-registry. Per-relation meet (greatest lower
                       ; bound) lookup. Default #f for backward-compat with domains that
                       ; don't have meet implementations.
                       ; Replaces the off-network `current-lattice-subtype-fn` Racket-
                       ; parameter callback pattern from Track 2H — relation-determined
                       ; meet behavior is now explicit per-relation registration,
                       ; correct-by-construction. Same case-dispatch idiom as
                       ; merge-registry (zero overhead, jump table).
   )
  #:transparent)

;; SRE Track 2H: Keyword constructor for sre-domain (retires L4 positional debt).
;; Required fields: name, merge-registry, contradicts?, bot?, bot-value.
;; Optional fields default to #f / (hasheq) as appropriate.
;; All 13 construction sites can migrate incrementally.
(define (make-sre-domain #:name name
                          #:merge-registry merge-registry
                          #:contradicts? contradicts?
                          #:bot? bot?
                          #:bot-value bot-value
                          #:top-value [top-value #f]
                          #:meta-recognizer [meta-recognizer #f]
                          #:meta-resolver [meta-resolver #f]
                          #:dual-pairs [dual-pairs #f]
                          #:property-cell-ids [property-cell-ids (hasheq)]
                          #:declared-properties [declared-properties (hasheq)]
                          #:operations [operations (hasheq)]
                          ;; PPN 4C Phase 1f: classification drives enforcement.
                          #:classification [classification 'unclassified]
                          ;; SRE Track 2I Phase 3c: per-relation meet registry.
                          #:meet-registry [meet-registry #f])
  (sre-domain name merge-registry contradicts? bot? bot-value top-value
              meta-recognizer meta-resolver dual-pairs
              property-cell-ids declared-properties operations
              classification meet-registry))

;; Merge lookup: gets the merge function for a given relation from the domain registry.
(define (sre-domain-merge domain relation)
  ((sre-domain-merge-registry domain) (sre-relation-name relation)))

;; SRE Track 2I Phase 3c: Meet lookup. Gets the meet function for a given relation,
;; or #f if no meet-registry is registered (backward-compat for domains without meet).
;; Accepts either an sre-relation struct or a bare relation-name symbol.
(define (sre-domain-meet domain relation)
  (define registry (sre-domain-meet-registry domain))
  (and registry (registry (if (sre-relation? relation)
                              (sre-relation-name relation)
                              relation))))

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
;; SRE Track 2H: #:relation keyword selects which ordering's properties to check.
;; Default: 'equality (backward compat — all pre-2H callers query equality ordering).
;; The keyword API is SCAFFOLDING (F5) — permanent is cell reads from property-cell-ids.
;;
;; Two sources (Phase 4: declaration hash, Phase 6: cells on network):
;; 1. Check property-cell-ids for a cell → read from network
;; 2. Fall back to declared-properties nested hash
(define (sre-domain-has-property? domain property-name
                                  #:net [net #f]
                                  #:relation [relation-name 'equality])
  ;; First: check cell (if exists and network provided)
  (define cell-ids (sre-domain-property-cell-ids domain))
  (define cell-id (and net (hash-ref cell-ids property-name #f)))
  (cond
    [(and cell-id net)
     (define val (net-cell-read net cell-id))
     (eq? val prop-confirmed)]
    ;; Fallback: check declared-properties nested hash
    [else
     (define declared (sre-domain-declared-properties domain))
     (define rel-props (hash-ref declared relation-name (hasheq)))
     (eq? (hash-ref rel-props property-name prop-unknown) prop-confirmed)]))

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

;; PPN 4C Phase 1f (2026-04-20): classification lookup for enforcement.
;; Returns 'structural | 'value | 'unclassified. #f if domain unregistered.
;; A loader module wires this into propagator.rkt's
;; `current-domain-classification-lookup` parameter at initialization.
(define (lookup-domain-classification name)
  (define d (lookup-domain name))
  (if d (sre-domain-classification d) #f))

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
;;
;; SRE Track 2I Phase 4 (Scaffolding-Hides-Truth corrective, 2026-04-30):
;; join-fn is now an explicit parameter (was hardcoded `'equality` lookup
;; from sre-domain-merge-registry, which mixed lattices when meet-fn came
;; from a non-equality relation). Callers must derive both meet-fn and
;; join-fn from the SAME relation to avoid lattice-mixing.
(define (test-distributive domain samples meet-fn join-fn)
  (cond
    [(not meet-fn) axiom-untested]
    [(not join-fn) axiom-untested]
    [else
     (for/fold ([status (axiom-confirmed 0)])
               ([a (in-list samples)]
                #:break (axiom-refuted? status))
       (for/fold ([st status])
                 ([b (in-list samples)]
                  #:break (axiom-refuted? st))
         (for/fold ([st2 st])
                   ([c (in-list samples)]
                    #:break (axiom-refuted? st2))
           (define lhs (join-fn a (meet-fn b c)))
           (define rhs (meet-fn (join-fn a b) (join-fn a c)))
           (if (equal? lhs rhs)
               (axiom-confirmed (+ (axiom-confirmed-count st2) 1))
               (axiom-refuted (list a b c))))))]))

;; ========================================================================
;; SRE Track 2I: Semidistributivity (Jónsson-Kiefer 1962)
;; ========================================================================
;; SD∨ (semidistributive-on-join):
;;   (a ⊔ b = a ⊔ c)  ⇒  (a ⊔ b = a ⊔ (b ⊓ c))
;; SD∧ (semidistributive-on-meet, dual):
;;   (a ⊓ b = a ⊓ c)  ⇒  (a ⊓ b = a ⊓ (b ⊔ c))
;;
;; Distributive lattices satisfy both (free corollary).
;; Free lattices satisfy both (Freese-Nation Theorem 1.21).
;; The interesting empirical question: do our non-distributive-yet domains
;; (type×equality, session×equality) satisfy SD even though not distributive?
;;
;; Both checks require meet-fn. Return axiom-untested if no meet available.

;; ------------------------------------------------------------------------
;; Phase 2: detailed SD evidence (vacuous-triple counting)
;; ------------------------------------------------------------------------
;;
;; sd-evidence reports four counts plus optional witness:
;;   status            — 'confirmed | 'refuted | 'untested
;;   total-checked     — total triples (a,b,c) iterated over
;;   hypothesis-fired  — triples where the SD hypothesis non-trivially held
;;                       (SD∨: a ⊔ b = a ⊔ c; SD∧: a ⊓ b = a ⊓ c)
;;   conclusion-held   — triples where hypothesis fired AND conclusion also held
;;                       (this is the genuinely-informative count)
;;   witness           — (list a b c) on refute; #f on confirmed/untested
;;
;; The vacuous count is (total-checked - hypothesis-fired). Phase 3 reports
;; (hypothesis-fired / total-checked) as the "non-vacuity ratio" so SD-confirmed
;; results are interpretable: SD-confirmed with 0 hypothesis-fired means
;; "vacuously true on this sample set" — informationally weak. SD-confirmed
;; with hypothesis-fired = total-checked is the strongest evidence shape.
;;
;; Status and witness semantics match axiom-confirmed/refuted/untested for
;; backward compat: existing test-sd-vee and test-sd-wedge wrappers translate.
(struct sd-evidence
  (status
   total-checked
   hypothesis-fired
   conclusion-held
   witness)
  #:transparent)

;; Detailed SD∨: a ⊔ b = a ⊔ c ⇒ a ⊔ b = a ⊔ (b ⊓ c)
;;
;; SRE Track 2I Phase 4 (Scaffolding-Hides-Truth corrective, 2026-04-30):
;; join-fn is now an explicit parameter; callers must pair it with a meet-fn
;; from the SAME relation to avoid lattice-mixing (see test-distributive).
(define (test-sd-vee/detailed domain samples meet-fn join-fn)
  (cond
    [(or (not meet-fn) (not join-fn))
     (sd-evidence 'untested 0 0 0 #f)]
    [else
     (let/ec return
       (define-values (total fired held)
         (for*/fold ([t 0] [f 0] [h 0])
                    ([a (in-list samples)]
                     [b (in-list samples)]
                     [c (in-list samples)])
           (define t* (+ t 1))
           (define ab (join-fn a b))
           (define ac (join-fn a c))
           (cond
             [(not (equal? ab ac))
              ;; Hypothesis fails — vacuously satisfied
              (values t* f h)]
             [else
              ;; Hypothesis holds — check conclusion
              (define conclusion (join-fn a (meet-fn b c)))
              (cond
                [(equal? ab conclusion)
                 (values t* (+ f 1) (+ h 1))]
                [else
                 ;; Refute and short-circuit
                 (return (sd-evidence 'refuted t* (+ f 1) h (list a b c)))])])))
       (sd-evidence 'confirmed total fired held #f))]))

;; Detailed SD∧ (dual): a ⊓ b = a ⊓ c ⇒ a ⊓ b = a ⊓ (b ⊔ c)
(define (test-sd-wedge/detailed domain samples meet-fn join-fn)
  (cond
    [(or (not meet-fn) (not join-fn))
     (sd-evidence 'untested 0 0 0 #f)]
    [else
     (let/ec return
       (define-values (total fired held)
         (for*/fold ([t 0] [f 0] [h 0])
                    ([a (in-list samples)]
                     [b (in-list samples)]
                     [c (in-list samples)])
           (define t* (+ t 1))
           (define ab (meet-fn a b))
           (define ac (meet-fn a c))
           (cond
             [(not (equal? ab ac))
              (values t* f h)]
             [else
              (define conclusion (meet-fn a (join-fn b c)))
              (cond
                [(equal? ab conclusion)
                 (values t* (+ f 1) (+ h 1))]
                [else
                 (return (sd-evidence 'refuted t* (+ f 1) h (list a b c)))])])))
       (sd-evidence 'confirmed total fired held #f))]))

;; ------------------------------------------------------------------------
;; Backward-compat wrappers — preserve axiom-confirmed | axiom-refuted | axiom-untested
;; shape consumed by infer-domain-properties + resolve-and-report-properties.
;; Phase 3 reporting uses /detailed variants directly for vacuous-counting.
;; ------------------------------------------------------------------------

;; Test SD∨: a ⊔ b = a ⊔ c ⇒ a ⊔ b = a ⊔ (b ⊓ c)
;; Phase 4: thread join-fn through to /detailed variant.
(define (test-sd-vee domain samples meet-fn join-fn)
  (define ev (test-sd-vee/detailed domain samples meet-fn join-fn))
  (case (sd-evidence-status ev)
    [(confirmed) (axiom-confirmed (sd-evidence-total-checked ev))]
    [(refuted)   (axiom-refuted (sd-evidence-witness ev))]
    [(untested)  axiom-untested]))

;; Test SD∧ (dual of SD∨): a ⊓ b = a ⊓ c ⇒ a ⊓ b = a ⊓ (b ⊔ c)
(define (test-sd-wedge domain samples meet-fn join-fn)
  (define ev (test-sd-wedge/detailed domain samples meet-fn join-fn))
  (case (sd-evidence-status ev)
    [(confirmed) (axiom-confirmed (sd-evidence-total-checked ev))]
    [(refuted)   (axiom-refuted (sd-evidence-witness ev))]
    [(untested)  axiom-untested]))

;; ========================================================================
;; SRE Track 2I Phase 5: Pseudo-complement family checks
;; ========================================================================
;;
;; Adds empirical checks for pseudo-complement variants relevant to
;; Heyting / Stone algebra structure on our lattices. Per Phase 5
;; mini-design (2026-04-30):
;;
;;   - test-pseudo-complement-rel : relative pseudo-complement (Heyting →);
;;     a → b = ⋁{x : x ∧ a ≤ b}. Combined with distributivity ⇒ Heyting.
;;   - test-pseudo-complement-abs : absolute pseudo-complement (= a → ⊥);
;;     ¬a = ⋁{x : x ∧ a = ⊥}. The meet-zero sense.
;;
;; Calling discipline (Phase 4 Scaffolding-Hides-Truth #3): explicit
;; meet-fn AND join-fn from the SAME relation. Caller derives both via
;; sre-domain-meet + sre-domain-merge-registry.
;;
;; Q1 disambiguation (Phase 5 mini-design 2026-04-30): the existing
;; 'has-pseudo-complement registry symbol is RENAMED to
;; 'has-pseudo-complement-rel (Track 2H meant the relative form when
;; combining with distributive → Heyting). 'has-pseudo-complement-abs
;; is added as a sibling.

;; Lattice partial-order helper: x ≤ y iff x ∧ y = x.
(define (lattice-leq? x y meet-fn)
  (equal? (meet-fn x y) x))

;; ------------------------------------------------------------------------
;; pc-rel-evidence: detailed evidence for relative pseudo-complement check
;; (parallels sd-evidence; non-vacuity is informationally rich here)
;; ------------------------------------------------------------------------
;;
;;   status            — 'confirmed | 'refuted | 'untested
;;   total-checked     — total (a, b) pairs iterated
;;   hypothesis-fired  — pairs where {x : x ∧ a ≤ b} non-empty (non-vacuous)
;;   conclusion-held   — pairs where the candidate join satisfies the axiom
;;                       (i.e., relative pseudo-complement EXISTS for (a, b)
;;                       on this sample set)
;;   witness           — (list a b) on refute; #f on confirmed/untested
(struct pc-rel-evidence
  (status
   total-checked
   hypothesis-fired
   conclusion-held
   witness)
  #:transparent)

;; Test relative pseudo-complement: a → b exists for all (a, b)?
;;
;; Implementation:
;;   1. For each (a, b), collect samples {x : x ∧ a ≤ b}.
;;   2. If empty (vacuous), continue with non-fired count.
;;   3. Else, candidate := join of all such x.
;;   4. Verify: candidate ∧ a ≤ b. If yes, candidate IS the supremum
;;      (and is in the set ⇒ is the maximum ⇒ relative pseudo-complement
;;      exists empirically). If no, the supremum of the set isn't in the
;;      set ⇒ no maximum ⇒ relative pseudo-complement does not exist on
;;      this sample.
;;
;; Sample-set sensitivity: ground sublattice (6 atoms) is exhaustive for
;; atomic types; wider samples may falsely refute when true PC exists
;; outside sample. Flag in interpretation.
(define (test-pseudo-complement-rel/detailed domain samples meet-fn join-fn)
  (cond
    [(or (not meet-fn) (not join-fn))
     (pc-rel-evidence 'untested 0 0 0 #f)]
    [else
     (let/ec return
       (define-values (total fired held)
         (for*/fold ([t 0] [f 0] [h 0])
                    ([a (in-list samples)]
                     [b (in-list samples)])
           (define t* (+ t 1))
           ;; Step 1: collect candidates {x : x ∧ a ≤ b}
           (define candidates
             (for/list ([x (in-list samples)]
                        #:when (lattice-leq? (meet-fn x a) b meet-fn))
               x))
           (cond
             [(null? candidates)
              ;; Vacuous: no x satisfies x ∧ a ≤ b. Hypothesis didn't fire.
              (values t* f h)]
             [else
              ;; Step 2: candidate := join of all such x
              (define candidate
                (foldl join-fn (first candidates) (rest candidates)))
              ;; Step 3: verify candidate ∧ a ≤ b (axiom)
              (cond
                [(lattice-leq? (meet-fn candidate a) b meet-fn)
                 (values t* (+ f 1) (+ h 1))]
                [else
                 (return (pc-rel-evidence 'refuted t* (+ f 1) h (list a b)))])])))
       (pc-rel-evidence 'confirmed total fired held #f))]))

;; Backward-compat wrapper: simple axiom shape for registry consumption.
(define (test-pseudo-complement-rel domain samples meet-fn join-fn)
  (define ev (test-pseudo-complement-rel/detailed domain samples meet-fn join-fn))
  (case (pc-rel-evidence-status ev)
    [(confirmed) (axiom-confirmed (pc-rel-evidence-total-checked ev))]
    [(refuted)   (axiom-refuted (pc-rel-evidence-witness ev))]
    [(untested)  axiom-untested]))

;; ========================================================================
;; SRE Track 2I Phase 6: Free-lattice membership + modularity checks
;; ========================================================================
;;
;; Three+ algebraic-property checks anchored on Nation's central work:
;;
;;   - test-modular         : a ≤ c ⇒ a ∨ (b ∧ c) = (a ∨ b) ∧ c
;;     Modular law (Dedekind 1900). Level between SD and distributive in
;;     the PTF hierarchy (§3.3). Forbidden sublattice: pentagon N₅.
;;
;;   - test-whitmans-condition (W) : a ∧ b ≤ c ∨ d ⇒ one of {a ≤ c∨d,
;;     b ≤ c∨d, a∧b ≤ c, a∧b ≤ d}. Whitman 1941. FL membership criterion
;;     when combined with SD (Theorem 5.55/6.9, Nation 1982). High
;;     theoretic alignment with Nation's central work in *Free Lattices*.
;;
;;   - test-breadth-bound k : maximum antichain width ≤ k. Theorem 1.21
;;     corollary (Jónsson-Kiefer-Nation 1962): SD lattices have breadth ≤ 4
;;     on finite sublattices. Parameterized via #:max-width (default 4).
;;     FIRST Hasse-structural property check in Track 2I — exploits
;;     antichain enumeration via incomparability adjacency.
;;
;;   - test-sectionally-complemented : every c ∈ [⊥, b] has d ∈ [⊥, b]
;;     with c ∧ d = ⊥, c ∨ d = b. Grätzer's *General Lattice Theory*
;;     definition. Distinct from (and weaker than) Phase 5b's
;;     test-relatively-complemented (which uses interval bottom a, not ⊥).
;;     Forward: rel-complemented ⇒ sect-complemented. Reverse fails.

;; ------------------------------------------------------------------------
;; Phase 6: modular-evidence (parallel to sd-evidence; non-vacuity rich)
;; ------------------------------------------------------------------------
;;
;; status            — 'confirmed | 'refuted | 'untested
;; total-checked     — total (a, b, c) triples iterated
;; hypothesis-fired  — triples where a ≤ c (non-vacuous)
;; conclusion-held   — triples where hypothesis fired AND conclusion held
;; witness           — (list a b c) on refute; #f on confirmed/untested
(struct modular-evidence
  (status total-checked hypothesis-fired conclusion-held witness)
  #:transparent)

;; Test modular law: a ≤ c ⇒ a ∨ (b ∧ c) = (a ∨ b) ∧ c
;; Hypothesis a ≤ c provides non-vacuity gating.
(define (test-modular/detailed domain samples meet-fn join-fn)
  (cond
    [(or (not meet-fn) (not join-fn))
     (modular-evidence 'untested 0 0 0 #f)]
    [else
     (let/ec return
       (define-values (total fired held)
         (for*/fold ([t 0] [f 0] [h 0])
                    ([a (in-list samples)]
                     [b (in-list samples)]
                     [c (in-list samples)])
           (define t* (+ t 1))
           (cond
             [(not (lattice-leq? a c meet-fn))
              ;; Hypothesis fails — vacuously satisfied
              (values t* f h)]
             [else
              (define lhs (join-fn a (meet-fn b c)))
              (define rhs (meet-fn (join-fn a b) (join-fn a c)))
              (cond
                [(equal? lhs rhs)
                 (values t* (+ f 1) (+ h 1))]
                [else
                 (return (modular-evidence 'refuted t* (+ f 1) h (list a b c)))])])))
       (modular-evidence 'confirmed total fired held #f))]))

(define (test-modular domain samples meet-fn join-fn)
  (define ev (test-modular/detailed domain samples meet-fn join-fn))
  (case (modular-evidence-status ev)
    [(confirmed) (axiom-confirmed (modular-evidence-total-checked ev))]
    [(refuted)   (axiom-refuted (modular-evidence-witness ev))]
    [(untested)  axiom-untested]))

;; ------------------------------------------------------------------------
;; Phase 6: whitman-evidence + Whitman's condition (W)
;; ------------------------------------------------------------------------
;;
;; (W): a ∧ b ≤ c ∨ d ⇒ one of {a ≤ c∨d, b ≤ c∨d, a∧b ≤ c, a∧b ≤ d}
;; Whitman 1941. FL membership criterion (with SD: Theorem 5.55, Nation 1982).
;;
;; O(N⁴) sweep — heavy at wider sample but tractable (depth-1 N=58 → 11.3M).
;; Hypothesis non-vacuity matters; /detailed surfaces it.
(struct whitman-evidence
  (status total-checked hypothesis-fired conclusion-held witness)
  #:transparent)

(define (test-whitmans-condition/detailed domain samples meet-fn join-fn)
  (cond
    [(or (not meet-fn) (not join-fn))
     (whitman-evidence 'untested 0 0 0 #f)]
    [else
     (let/ec return
       (define-values (total fired held)
         (for*/fold ([t 0] [f 0] [h 0])
                    ([a (in-list samples)]
                     [b (in-list samples)]
                     [c (in-list samples)]
                     [d (in-list samples)])
           (define t* (+ t 1))
           (define ab (meet-fn a b))
           (define cd (join-fn c d))
           (cond
             [(not (lattice-leq? ab cd meet-fn))
              ;; Hypothesis a∧b ≤ c∨d fails — vacuously satisfied
              (values t* f h)]
             [else
              ;; Hypothesis holds — check disjunctive conclusion
              (define conc-1 (lattice-leq? a cd meet-fn))
              (define conc-2 (lattice-leq? b cd meet-fn))
              (define conc-3 (lattice-leq? ab c meet-fn))
              (define conc-4 (lattice-leq? ab d meet-fn))
              (cond
                [(or conc-1 conc-2 conc-3 conc-4)
                 (values t* (+ f 1) (+ h 1))]
                [else
                 (return (whitman-evidence 'refuted t* (+ f 1) h (list a b c d)))])])))
       (whitman-evidence 'confirmed total fired held #f))]))

(define (test-whitmans-condition domain samples meet-fn join-fn)
  (define ev (test-whitmans-condition/detailed domain samples meet-fn join-fn))
  (case (whitman-evidence-status ev)
    [(confirmed) (axiom-confirmed (whitman-evidence-total-checked ev))]
    [(refuted)   (axiom-refuted (whitman-evidence-witness ev))]
    [(untested)  axiom-untested]))

;; ------------------------------------------------------------------------
;; Phase 6: Breadth bound (Jónsson-Kiefer-Nation 1962, Theorem 1.21 corollary)
;; ------------------------------------------------------------------------
;;
;; Breadth ≤ k iff no (k+1)-element antichain exists. SD lattices satisfy
;; breadth ≤ 4 on finite sublattices. Implementation: search for any
;; (k+1)-element antichain by enumerating size-(k+1) subsets and checking
;; pairwise incomparability. If found → breadth > k → refuted with witness.
;;
;; FIRST Hasse-structural property check in Track 2I — uses incomparability
;; adjacency directly (no Hasse edge between two elements ⟺ incomparable).
;;
;; Cost: O(N^(k+1)) for the search. At k=4, N=6: 7776 (cheap). N=58: 656M
;; (heavy but feasible).
(define (test-breadth-bound domain samples meet-fn #:max-width [k 4])
  (cond
    [(not meet-fn) axiom-untested]
    [else
     ;; Helper: are all elements in the list pairwise incomparable?
     (define (antichain? elts)
       (for*/and ([x (in-list elts)]
                  [y (in-list elts)]
                  #:when (not (eq? x y)))
         (and (not (lattice-leq? x y meet-fn))
              (not (lattice-leq? y x meet-fn)))))
     ;; Search for any (k+1)-element antichain among samples
     (define antichain-found
       (let loop ([picks '()] [pool samples] [remaining (+ k 1)])
         (cond
           [(zero? remaining) (and (antichain? picks) picks)]
           [(null? pool) #f]
           [else
            (or (loop (cons (car pool) picks) (cdr pool) (- remaining 1))
                (loop picks (cdr pool) remaining))])))
     (cond
       [antichain-found
        (axiom-refuted antichain-found)]  ;; breadth > k
       [else
        (axiom-confirmed (length samples))])]))  ;; breadth ≤ k

;; ------------------------------------------------------------------------
;; Phase 6: Sectionally complemented (Grätzer's General Lattice Theory)
;; ------------------------------------------------------------------------
;;
;; A bounded lattice is sectionally complemented iff for every b and every
;; c ∈ [⊥, b], ∃ d ∈ [⊥, b] with c ∧ d = ⊥ AND c ∨ d = b.
;;
;; DISTINCT FROM Phase 5b's test-relatively-complemented (which uses
;; interval bottom a as meet target; sectional uses ⊥). Forward implication:
;; relatively-complemented ⇒ sectionally-complemented.
(define (test-sectionally-complemented domain samples meet-fn join-fn)
  (cond
    [(or (not meet-fn) (not join-fn)) axiom-untested]
    [else
     (define bot (sre-domain-bot-value domain))
     (let/ec return
       (define count
         (for/fold ([k 0])
                   ([b (in-list samples)])
           (for/fold ([k2 k])
                     ([c (in-list samples)]
                      #:when (lattice-leq? c b meet-fn))
             ;; c ∈ [⊥, b]; search for d ∈ [⊥, b] with c ∧ d = ⊥, c ∨ d = b
             (define d-found?
               (for/or ([d (in-list samples)])
                 (and (lattice-leq? d b meet-fn)
                      (equal? (meet-fn c d) bot)
                      (equal? (join-fn c d) b))))
             (cond
               [d-found? (+ k2 1)]
               [else
                (return (axiom-refuted (list b c)))]))))
       (axiom-confirmed count))]))

;; Compute absolute pseudo-complement candidate ¬a on a sample set.
;; Returns the candidate (the join of all x with x ∧ a = ⊥), or #f if
;; no such x exists in samples. Used by test-stone-identity below.
;; Sample-set sensitive — returns sample-witness PC, may differ from
;; lattice-theoretic PC if true PC is outside sample.
(define (compute-abs-pc-candidate a samples meet-fn join-fn bot)
  (define candidates
    (for/list ([x (in-list samples)]
               #:when (equal? (meet-fn x a) bot))
      x))
  (cond
    [(null? candidates) #f]
    [else (foldl join-fn (first candidates) (rest candidates))]))

;; Test Stone identity: ¬a ∨ ¬¬a = ⊤ for all a (where ¬ is absolute pc).
;;
;; Stone algebras = distributive pseudo-complemented + Stone identity.
;; Connects to intermediate logic (Gödel-Dummett, between intuitionistic
;; and classical). The identity says: for every element a, the lattice
;; is "covered" by a's pseudo-complement and its double-complement —
;; the closure-under-double-negation is the whole lattice.
;;
;; Conditional check: only meaningful if has-pseudo-complement-rel
;; confirms. The check itself just runs; callers gate via property
;; registry inspection. Untested only when meet-fn or join-fn is #f.
;;
;; Sample-set sensitivity: per-atom; if pc-abs(a) doesn't exist on
;; sample for some a, that atom is skipped (not refuted). Refutation
;; only on a witness where ¬a ∨ ¬¬a ≠ ⊤ explicitly.
(define (test-stone-identity domain samples meet-fn join-fn)
  (cond
    [(or (not meet-fn) (not join-fn)) axiom-untested]
    [else
     (define bot (sre-domain-bot-value domain))
     (define top (sre-domain-top-value domain))
     (let/ec return
       (define checked
         (for/fold ([k 0])
                   ([a (in-list samples)])
           (define neg-a (compute-abs-pc-candidate a samples meet-fn join-fn bot))
           (cond
             [(not neg-a) k]   ; pc-abs of a not in sample; skip
             [else
              (define neg-neg-a
                (compute-abs-pc-candidate neg-a samples meet-fn join-fn bot))
              (cond
                [(not neg-neg-a) k]
                [else
                 (define stone-result (join-fn neg-a neg-neg-a))
                 (cond
                   [(equal? stone-result top) (+ k 1)]
                   [else
                    (return (axiom-refuted (list a neg-a neg-neg-a stone-result)))])])])))
       (axiom-confirmed checked))]))

;; Test relatively complemented: every interval [a, b] is complemented?
;;
;; A lattice L is relatively complemented if for every interval [a, b] in L
;; and every c ∈ [a, b], there exists d ∈ [a, b] (the relative complement
;; of c) such that c ∧ d = a and c ∨ d = b.
;;
;; This is **Nation's primary terminology** (Notes on Lattice Theory ch4
;; partition lattice Eq X, ch10 Theorem 10.10 Dilworth 1950 PCF lattices,
;; ch11 Theorem 11.3 geometric lattices). Distinct from Heyting's relative
;; pseudo-complement (a → b operator). This is the INTERVAL-WISE version
;; of complementation.
;;
;; Implementation:
;;   For each (a, b) with a ≤ b in samples (the interval [a, b]):
;;     For each c with a ≤ c ≤ b in samples:
;;       Search samples for d satisfying:
;;         a ≤ d ≤ b (d in interval)
;;         c ∧ d = a (meet)
;;         c ∨ d = b (join)
;;       If no such d found in samples, refuted with witness (a, b, c).
;;
;; Cost: O(N^4) worst case (intervals × c × d-search). At N=6 (ground), 1296
;; iterations — cheap. At N=58 (depth-1), 11.3M — heavy but tractable.
;;
;; Sample-set sensitivity: similar to pseudo-complement-rel — may falsely
;; refute when true relative complement exists outside sample but candidate
;; d isn't drawn. Ground sublattice (6 atoms) is exhaustive for atomic
;; types; flag in interpretation for wider sweeps.
(define (test-relatively-complemented domain samples meet-fn join-fn)
  (cond
    [(or (not meet-fn) (not join-fn)) axiom-untested]
    [else
     (let/ec return
       (define count
         (for*/fold ([k 0])
                    ([a (in-list samples)]
                     [b (in-list samples)]
                     #:when (lattice-leq? a b meet-fn))  ; only valid intervals
           (for/fold ([k2 k])
                     ([c (in-list samples)]
                      #:when (and (lattice-leq? a c meet-fn)
                                  (lattice-leq? c b meet-fn)))
             (define d-found?
               (for/or ([d (in-list samples)])
                 (and (lattice-leq? a d meet-fn)
                      (lattice-leq? d b meet-fn)
                      (equal? (meet-fn c d) a)
                      (equal? (join-fn c d) b))))
             (cond
               [d-found? (+ k2 1)]
               [else
                (return (axiom-refuted (list a b c)))]))))
       (axiom-confirmed count))]))

;; Test absolute pseudo-complement: ¬a exists for all a?
;; ¬a = ⋁{x : x ∧ a = ⊥} = max element disjoint from a in meet.
;;
;; Implementation parallels test-pseudo-complement-rel but with the
;; bottom element of the lattice as the "b" target (semantically
;; equivalent to test-pseudo-complement-rel with b=⊥; we provide a
;; direct check for clarity + cases where rel-form check isn't run).
(define (test-pseudo-complement-abs domain samples meet-fn join-fn)
  (cond
    [(or (not meet-fn) (not join-fn)) axiom-untested]
    [else
     (define bot (sre-domain-bot-value domain))
     (let/ec return
       (define count
         (for/fold ([k 0])
                   ([a (in-list samples)])
           (define candidates
             (for/list ([x (in-list samples)]
                        #:when (equal? (meet-fn x a) bot))
               x))
           (cond
             [(null? candidates) (+ k 1)] ;; vacuous (no disjoint x in sample)
             [else
              (define candidate
                (foldl join-fn (first candidates) (rest candidates)))
              (cond
                [(equal? (meet-fn candidate a) bot)
                 (+ k 1)]
                [else
                 (return (axiom-refuted (list a)))])])))
       (axiom-confirmed count))]))

;; Infer properties for a domain from sample values.
;; SRE Track 2H: #:relation selects which sub-hash to work with.
;; Returns updated properties sub-hash for that relation.
;; Declarations take priority — inference validates but doesn't override #t declarations.
;; If inference finds counterexample for a declared #t property → prop-contradicted.
(define (infer-domain-properties domain samples
                                 #:meet-fn [meet-fn #f]
                                 #:relation [relation-name 'equality])
  (define all-declared (sre-domain-declared-properties domain))
  (define declared (hash-ref all-declared relation-name (hasheq)))
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
  ;; Phase 4: look up join-fn per relation (mirrors meet-fn discipline);
  ;; both must come from the same relation to avoid lattice-mixing.
  (define merge-registry (sre-domain-merge-registry domain))
  (define join-fn (and merge-registry (merge-registry relation-name)))
  (define props-3
    (if (and meet-fn join-fn)
        (update-property props-2 'distributive
                         (test-distributive domain samples meet-fn join-fn))
        props-2))
  ;; Track 2I: SD∨ and SD∧ (require meet-fn AND join-fn; otherwise untested)
  (define props-4
    (if (and meet-fn join-fn)
        (update-property props-3 'sd-vee
                         (test-sd-vee domain samples meet-fn join-fn))
        props-3))
  (define props-5
    (if (and meet-fn join-fn)
        (update-property props-4 'sd-wedge
                         (test-sd-wedge domain samples meet-fn join-fn))
        props-4))
  ;; Phase 5: pseudo-complement family (require meet-fn AND join-fn)
  (define props-6
    (if (and meet-fn join-fn)
        (update-property props-5 'has-pseudo-complement-rel
                         (test-pseudo-complement-rel domain samples meet-fn join-fn))
        props-5))
  (define props-7
    (if (and meet-fn join-fn)
        (update-property props-6 'has-pseudo-complement-abs
                         (test-pseudo-complement-abs domain samples meet-fn join-fn))
        props-6))
  ;; Phase 5b: relatively-complemented (Nation's primary terminology)
  (define props-8
    (if (and meet-fn join-fn)
        (update-property props-7 'relatively-complemented
                         (test-relatively-complemented domain samples meet-fn join-fn))
        props-7))
  ;; Phase 5c: Stone identity (gated semantically on has-pseudo-complement-rel
  ;; confirming — but we run unconditionally; the result is informative only
  ;; if rel-pc also confirms. The implication rule below ensures stone-algebra
  ;; only derives when both confirm.)
  (define props-9
    (if (and meet-fn join-fn)
        (update-property props-8 'stone-identity
                         (test-stone-identity domain samples meet-fn join-fn))
        props-8))
  ;; Phase 6: modular law (Dedekind 1900)
  (define props-10
    (if (and meet-fn join-fn)
        (update-property props-9 'modular
                         (test-modular domain samples meet-fn join-fn))
        props-9))
  ;; Phase 6: Whitman's condition (W) — FL membership criterion (Nation 1982)
  (define props-11
    (if (and meet-fn join-fn)
        (update-property props-10 'whitmans-condition
                         (test-whitmans-condition domain samples meet-fn join-fn))
        props-10))
  ;; Phase 6: breadth bound (Jónsson-Kiefer-Nation 1962, default k=4)
  (define props-12
    (if meet-fn
        (update-property props-11 'breadth-bound
                         (test-breadth-bound domain samples meet-fn))
        props-11))
  ;; Phase 6: sectionally complemented (Grätzer; weaker than relatively-complemented)
  (define props-13
    (if (and meet-fn join-fn)
        (update-property props-12 'sectionally-complemented
                         (test-sectionally-complemented domain samples meet-fn join-fn))
        props-12))
  props-13)

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
                     '(distributive has-pseudo-complement-rel)  ;; renamed Phase 5 (Q1 disambiguation)
                     'heyting)
   (implication-rule 'boolean
                     '(heyting has-complement)
                     'boolean)
   ;; Track 2I: distributive ⇒ semidistributive (forward implication only;
   ;; SD ⇒ distributive does NOT hold — there exist non-distributive SD lattices,
   ;; e.g., free lattices satisfy SD but not distributivity).
   (implication-rule 'distributive→sd-vee
                     '(distributive)
                     'sd-vee)
   (implication-rule 'distributive→sd-wedge
                     '(distributive)
                     'sd-wedge)
   ;; SRE Track 2I Phase 5c: Stone algebra = distributive + has-pseudo-complement-rel + stone-identity
   (implication-rule 'stone-algebra
                     '(distributive has-pseudo-complement-rel stone-identity)
                     'stone-algebra)
   ;; SRE Track 2I Phase 6: codify hierarchy SD ⊃ modular ⊃ distributive
   (implication-rule 'distributive→modular
                     '(distributive)
                     'modular)
   ;; SRE Track 2I Phase 6: relative ⇒ sectional (principal ideals are intervals)
   (implication-rule 'rel-comp→sect-comp
                     '(relatively-complemented)
                     'sectionally-complemented)))

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
;; Phase 4: thread #:relation through to infer-domain-properties so
;; join-fn lookup uses the right per-relation merge.
(define (resolve-domain-properties domain samples
                                   #:meet-fn [meet-fn #f]
                                   #:relation [relation-name 'equality])
  (define after-inference
    (infer-domain-properties domain samples
                             #:meet-fn meet-fn
                             #:relation relation-name))
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
;; Phase 4: thread #:relation through; look up join-fn per relation for
;; the test-{distributive,sd-vee,sd-wedge} dispatch (avoids lattice-mixing).
(define (resolve-and-report-properties domain samples
                                       #:meet-fn [meet-fn #f]
                                       #:relation [relation-name 'equality])
  ;; Step 1: Infer (produces inference evidence)
  (define after-inference
    (infer-domain-properties domain samples
                             #:meet-fn meet-fn
                             #:relation relation-name))
  ;; Step 2: Build evidence map for reporting (Phase 4: per-relation join-fn)
  (define merge-registry (sre-domain-merge-registry domain))
  (define join-fn (and merge-registry (merge-registry relation-name)))
  (define evidence
    (for/hasheq ([prop (in-list '(commutative-join associative-join idempotent-join
                                  distributive sd-vee sd-wedge
                                  has-pseudo-complement-rel has-pseudo-complement-abs
                                  relatively-complemented stone-identity
                                  ;; Phase 6 additions
                                  modular whitmans-condition breadth-bound
                                  sectionally-complemented))])
      (define test-fn
        (case prop
          [(commutative-join) test-commutative-join]
          [(associative-join) test-associative-join]
          [(idempotent-join) test-idempotent-join]
          [(distributive) (lambda (d s) (test-distributive d s meet-fn join-fn))]
          [(sd-vee)       (lambda (d s) (test-sd-vee d s meet-fn join-fn))]
          [(sd-wedge)     (lambda (d s) (test-sd-wedge d s meet-fn join-fn))]
          ;; Phase 5: pseudo-complement family
          [(has-pseudo-complement-rel)
           (lambda (d s) (test-pseudo-complement-rel d s meet-fn join-fn))]
          [(has-pseudo-complement-abs)
           (lambda (d s) (test-pseudo-complement-abs d s meet-fn join-fn))]
          ;; Phase 5b: relatively-complemented (Nation's term)
          [(relatively-complemented)
           (lambda (d s) (test-relatively-complemented d s meet-fn join-fn))]
          ;; Phase 5c: Stone identity
          [(stone-identity)
           (lambda (d s) (test-stone-identity d s meet-fn join-fn))]
          ;; Phase 6: free-lattice membership + modularity family
          [(modular)
           (lambda (d s) (test-modular d s meet-fn join-fn))]
          [(whitmans-condition)
           (lambda (d s) (test-whitmans-condition d s meet-fn join-fn))]
          [(breadth-bound)
           (lambda (d s) (test-breadth-bound d s meet-fn))]
          [(sectionally-complemented)
           (lambda (d s) (test-sectionally-complemented d s meet-fn join-fn))]
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
;; #:relation defaults to 'equality (backward compat).
(define (with-domain-property domain property-name then-fn else-fn
                              #:relation [relation-name 'equality])
  (if (sre-domain-has-property? domain property-name #:relation relation-name)
      (then-fn)
      (else-fn)))

;; Select from a list of (property-name . behavior-fn) pairs.
;; Returns the first behavior whose property is confirmed, or default-fn.
;; #:relation defaults to 'equality (backward compat).
(define (select-by-property domain property-behaviors default-fn
                            #:relation [relation-name 'equality])
  (let loop ([rest property-behaviors])
    (cond
      [(null? rest) (default-fn)]
      [(sre-domain-has-property? domain (caar rest) #:relation relation-name)
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
            (net-cell-write net sre-topology-cell-id
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
            (net-cell-write net sre-topology-cell-id
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
               (net-cell-write net sre-topology-cell-id
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
            (net-cell-write net sre-topology-cell-id
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
            (net-cell-write net sre-topology-cell-id
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
;; A1 (BSP-LE 2B addendum, 2026-04-16): migrated to per-subsystem stratum
;; handler on sre-topology-cell-id (was shared decomp-request-cell).
(register-stratum-handler!
 sre-topology-cell-id
 (lambda (net req-set)
   (for/fold ([n net]) ([req (in-set req-set)])
     (define pair-key (sre-decomp-request-pair-key req))
     (cond
       [(net-pair-decomp? n pair-key) n]
       [else
        (define domain (sre-decomp-request-domain req))
        (define cell-a (sre-decomp-request-cell-a req))
        (define cell-b (sre-decomp-request-cell-b req))
        (define relation (sre-decomp-request-relation req))
        (define va (net-cell-read n cell-a))
        (define vb (net-cell-read n cell-b))
        (define bot? (sre-domain-bot? domain))
        (define is-antitone? (sre-relation-has-property? relation 'antitone))
        (define has-dual-pairs? (and (sre-domain-dual-pairs domain) #t))
        (define both-needed? (not (and is-antitone? has-dual-pairs?)))
        (cond
          [(and both-needed? (or (bot? va) (bot? vb))) n]
          [else
           (define reversed? (eq? (sre-relation-name relation) 'subtype-reverse))
           (define lhs (if reversed? vb va))
           (define tag (sre-constructor-tag domain lhs))
           (define desc (and tag (lookup-ctor-desc tag #:domain (sre-domain-name domain))))
           (cond
             [(and is-antitone? has-dual-pairs?)
              (define pairs (sre-domain-dual-pairs domain))
              (define dual-map
                (let ([h (make-hasheq)])
                  (when pairs
                    (for ([p (in-list pairs)])
                      (hash-set! h (car p) (cdr p))
                      (hash-set! h (cdr p) (car p))))
                  h))
              (define tag-a (sre-constructor-tag domain va))
              (define tag-b (sre-constructor-tag domain vb))
              (define tag-a* (or tag-a (and tag-b (hash-ref dual-map tag-b #f)) tag-b))
              (define tag-b* (or tag-b (and tag-a (hash-ref dual-map tag-a #f)) tag-a))
              (define desc-a (and tag-a* (lookup-ctor-desc tag-a* #:domain (sre-domain-name domain))))
              (define desc-b (and tag-b* (lookup-ctor-desc tag-b* #:domain (sre-domain-name domain))))
              (if (and desc-a desc-b)
                  (sre-duality-decompose-dual-pair n domain cell-a cell-b va vb
                                                    desc-a desc-b pair-key relation)
                  n)]
             [(not desc) n]
             [else
              (sre-decompose-generic n domain cell-a cell-b va vb lhs
                                     pair-key desc #:relation relation)])])])))
 #:tier 'topology
 #:reset-value (set))
