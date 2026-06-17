#lang racket/base
;;; eclass-graph.rkt — PReduce Track 1 GREEN SLICE (D.1 §2.4 / §3.2; ledger iter 9).
;;;
;;; The hashcons registry + intern + union-emitter over e-class cells:
;;;
;;;   - REGISTRY: an on-network cell mapping PCE ground digest → (alloc . cell-id),
;;;     equal?-keyed (digests are bytes), hash-union merge with per-key MIN-BY-ALLOC
;;;     (racing interns of the same term resolve deterministically to the
;;;     first-allocated cell — ACI, CALM-safe; the loser cell is unreachable
;;;     garbage, not an error).
;;;   - INTERN: content-address the term via pce.rkt (the single hasher — D.3 §2),
;;;     reuse the registered class or allocate a fresh product cell. The
;;;     ':canonical component = the cell-id's allocation number (network cell-ids
;;;     are allocated monotonically — the min-join over them IS first-allocation
;;;     order; no separate counter, no off-network state).
;;;   - UNION: e-graph union = installing an 'eclass-refine relate propagator
;;;     between two class cells (SM2 D2: relations are propagator KINDS). The
;;;     coarsening join happens at BSP quiescence — racing unions converge to one
;;;     fixpoint by CALM, exercised by the racing test.
;;;
;;; Three keys, never conflated (D.1 §2.1 three-key separation): canonical NAME
;;; (min alloc) ≠ cost-best FORM (':best argmin) ≠ content-address KEY (PCE digest).
(require racket/set
         "pce.rkt"
         "eclass-cell.rkt"
         "sre-core.rkt"
         "propagator.rkt")

(provide current-eclass-hashcons-cell-id
         current-eclass-containment-box  ;; PTF Track V: reduction-DAG capture
         init-eclass-hashcons-cell!
         current-intern-origin
         current-parent-index-cell-id
         init-parent-index-cell!
         parent-index-merge
         make-eclass-graph
         eclass-registry-merge
         eclass-intern
         eclass-union
         eclass-lookup
         eclass-read
         ;; congruence engine (PReduce Track 1, iter 11a — D.1 §2.1)
         eclass-canonical
         eclass-node-signature
         eclass-intern-node
         eclass-congruence-collisions
         eclass-union-all
         ;; 11b reactive wiring (ledger iter 12)
         process-congruence-requests
         ;; effect-safety floor (ledger iter 13 — D.1 §6.2 F-A lock)
         register-effectful-head!
         register-capability-polymorphic-head!
         effectful-head?
         pessimism-bite-count
         eclass-intern-effectful)

;; --- the hashcons registry cell ---

;; per-key min-by-alloc hash-union: deterministic winner for racing interns
(define (eclass-registry-merge old new)
  (cond
    [(not (hash? old)) new]
    [(not (hash? new)) old]
    [else
     (for/fold ([acc old]) ([(k v) (in-hash new)])
       (define e (hash-ref acc k #f))
       (cond
         [(not e) (hash-set acc k v)]
         [(<= (car e) (car v)) acc]
         [else (hash-set acc k v)]))]))

;; → (values net' registry-cid)
(define (make-eclass-graph net)
  (net-new-cell net (hash) eclass-registry-merge))

;; --- intern ---

;; PTF Track V (viz): optional containment recording. When set to a (box hash),
;; eclass-intern records parent-alloc → (listof child-alloc) for each interned
;; term's IMMEDIATE sub-terms, resolving children against the registry at intern
;; time (children are interned bottom-up, so they're present). This captures the
;; reduction DAG structure (e.g. int+((lit 377),(lit 233)) → its operands) which
;; is otherwise consumed: an e-class's :best becomes the reduced VALUE, losing
;; the redex shape. Off-network viz side-channel; default #f = zero cost.
(define current-eclass-containment-box (make-parameter #f))

;; Immediate child sub-terms of a sexp-encoded term (op c1 c2 ...): the operands.
;; (lit N) is a leaf. Non-list / symbol-headed-lit terms have no children.
(define (term-immediate-children t)
  (if (and (pair? t) (symbol? (car t)) (not (eq? (car t) 'lit)))
      (filter pair? (cdr t))
      '()))

(define (record-term-containment! box reg parent-alloc term)
  (define h (unbox box))
  (for ([ch (in-list (term-immediate-children term))])
    (define cd (pce-persistable-digest PCE-KIND-GROUND-TERM ch))
    (define entry (and (hash? reg) (hash-ref reg cd #f)))
    (when entry  ;; child already interned → record parent → child-alloc
      (hash-update! h parent-alloc (lambda (l) (cons (car entry) l)) '()))))

;; → (values net' class-cid digest)
(define (eclass-intern net reg-cid term
                       #:cost [cost 1]
                       #:regime [regime 'ground]
                       #:provenance [provenance (seteq 'intern)])
  (define provenance* (set-add provenance (origin-marker)))
  ;; effect-safety guard (iter 13): application terms with effectful heads may
  ;; not enter the ground path (head = the operator position of an expr-app
  ;; spine whose head is a known symbol is checked at the NODE path; raw-term
  ;; interning guards symbolic heads when the term IS a bare operator symbol)
  (when (symbol? term) (guard-ground-path! 'eclass-intern term))
  (define digest (pce-persistable-digest PCE-KIND-GROUND-TERM term))
  (define reg (net-cell-read net reg-cid))
  (define existing (and (hash? reg) (hash-ref reg digest #f)))
  (cond
    [existing (values net (cdr existing) digest)]
    [else
     (define-values (net1 cid) (net-new-cell net eclass-bot eclass-merge))
     (define alloc (cell-id-n cid))
     (define v0 (make-eclass-value #:best (cons cost term)
                                   #:alts (set digest)
                                   #:canonical alloc
                                   #:provenance provenance*
                                   #:regime regime))
     (define net2 (net-cell-write net1 cid v0))
     (define net3 (net-cell-write net2 reg-cid (hash digest (cons alloc cid))))
     (when (current-eclass-containment-box)
       (record-term-containment! (current-eclass-containment-box) reg alloc term))
     (values net3 cid digest)]))

;; --- union-emitter ---

;; e-graph union = an 'eclass-refine relate install; the join lands at quiescence.
;; → net' (propagator installed; caller drives run-to-quiescence)
(define (eclass-union net cid-a cid-b)
  (define fire (sre-make-structural-relate-propagator term-carrier-sre-domain
                                                      cid-a cid-b
                                                      #:relation sre-eclass-refine))
  (define-values (net1 _pid)
    (net-add-propagator net (list cid-a cid-b) (list cid-a cid-b) fire))
  net1)

;; --- reads ---

(define (eclass-lookup net reg-cid digest)
  (define reg (net-cell-read net reg-cid))
  (define e (and (hash? reg) (hash-ref reg digest #f)))
  (and e (cdr e)))

(define (eclass-read net cid)
  (net-cell-read net cid))

;; ========================================================================
;; Congruence engine (PReduce Track 1, iter 11a — D.1 §2.1)
;;
;; E-NODES are decomposed applications: (op, child-class...). A node's
;; SIGNATURE is the PCE digest of (vector 'enode op canonical(child)...) —
;; canonicals are the min-alloc NAMES, PCE-encodable integers.
;;
;; SOUND-IF-STALE (the load-bearing argument, ledger iter 11): classes only
;; COARSEN (unions never split), so two nodes whose signatures were equal at
;; ANY point are congruent FOREVER — stale signature-index entries can never
;; cause a wrong union. An intern keyed by a STALE canonical merely allocates
;; a duplicate class for the same node; the congruence scan detects the
;; signature collision and unions the duplicate away. Wasteful-but-sound is
;; the CALM-compatible failure mode; precision returns at quiescence.
;;
;; 11a = the ENGINE (signatures, decomposed intern, collision scan, batch
;; union) — pure + cell-level, fully testable. 11b = the reactive wiring
;; (parent watchers + topology-tier collision handler).
;; ========================================================================

;; the canonical NAME of a class (min-alloc component of the product)
(define (eclass-canonical net cid)
  (define v (net-cell-read net cid))
  (and (hash? v) (hash-ref v ':canonical #f)))

;; signature = content address of (op, canonical children...)
(define (eclass-node-signature net op child-cids)
  (define canon (for/list ([c (in-list child-cids)]) (eclass-canonical net c)))
  (pce-persistable-digest PCE-KIND-GROUND-TERM
                          (list->vector (cons 'enode (cons op canon)))))

;; Decomposed intern: a node keyed by its CURRENT signature. Returns the node
;; DESCRIPTOR (list op child-cids class-cid) alongside — 11b's watchers and the
;; collision scan consume descriptors.
;; → (values net' class-cid descriptor)

;; ========================================================================
;; Effect-safety floor (ledger iter 13 — D.1 §6.2 F-A lock, Track 1 Option 1)
;;
;; F-A: two occurrences of [read ch] hash equal → same e-class → extraction
;; DEDUPS THE EFFECT. The floor: effectful-headed occurrences NEVER enter the
;; ground hashcons path — they get a deterministic (epoch × occurrence-path)
;; identity key (kind-2: session-local, structurally excluded from persistence
;; by pce-persistable-digest), are NEVER written to the hashcons registry or
;; the congruence signature index, and carry the positive :opaque facet at
;; their positions (the facet is LOAD-BEARING — absence-from-index alone does
;; not carry congruence safety; typing-propagators.rkt :opaque).
;;
;; HEAD CLASSIFICATION (v1 = the floor's shape; type-derived α consuming the
;; capability lattice is the NAMED Track 7 upgrade): an explicit effectful-head
;; registry + a capability-polymorphic registry with PESSIMISTIC default
;; (treated effectful; a bite counter measures how often pessimism fires —
;; the D5-style counter the lock requires). Unregistered heads are PURE
;; (the SM3 rule registry will own authoritative classification).
;; ========================================================================

(define effectful-head-registry (box (seteq 'read 'write 'print 'send 'recv 'perform)))
(define capability-polymorphic-registry (box (seteq)))
(define pessimism-bites (box 0))

(define (register-effectful-head! op)
  (set-box! effectful-head-registry (set-add (unbox effectful-head-registry) op)))
(define (register-capability-polymorphic-head! op)
  (set-box! capability-polymorphic-registry
            (set-add (unbox capability-polymorphic-registry) op)))
(define (pessimism-bite-count) (unbox pessimism-bites))

(define (effectful-head? op)
  (cond
    [(set-member? (unbox effectful-head-registry) op) #t]
    [(set-member? (unbox capability-polymorphic-registry) op)
     ;; pessimistic: pure head, possibly-effectful instantiation → treat
     ;; effectful + count the bite (D.1 §6.2; upgrade = type-derived α)
     (set-box! pessimism-bites (add1 (unbox pessimism-bites)))
     #t]
    [else #f]))

(define (guard-ground-path! who op)
  (when (effectful-head? op)
    (error who
           "ADMISSION GUARD (F-A, D.1 §6.2): effectful head ~a may not enter the ground hashcons path — use eclass-intern-effectful (per-occurrence epoch×path identity)"
           op)))

;; Per-occurrence intern for effectful heads: the key is the DETERMINISTIC
;; (epoch × occurrence-path) identity — idempotent under re-fire (same epoch +
;; path → the SAME class), serializability-shaped for Track 5, but kind-2:
;; structurally excluded from anything that persists. The class is allocated
;; CELL-ONLY: no hashcons registry entry, no signature-index entry, no parent
;; watcher — congruence machinery never sees it as a dedup source.
;; → (values net' class-cid occurrence-key)
(define (eclass-intern-effectful net occurrence-index-box op epoch occurrence-path
                                 #:cost [cost 1])
  (define key (pce-digest PCE-KIND-EFFECTFUL-SESSION
                          (list->vector (list 'effect-occurrence op epoch occurrence-path))))
  (define idx (unbox occurrence-index-box))
  (define existing (hash-ref idx key #f))
  (cond
    [existing (values net existing key)]
    [else
     (define-values (net1 cid) (net-new-cell net eclass-bot eclass-merge))
     (define v0 (make-eclass-value
                 #:best (cons cost (list->vector (list 'effect-occurrence op epoch occurrence-path)))
                 #:alts (set key)
                 #:canonical (cell-id-n cid)
                 #:provenance (seteq 'effect-occurrence)
                 #:regime 'retraction-eligible))
     (define net2 (net-cell-write net1 cid v0))
     (set-box! occurrence-index-box (hash-set idx key cid))
     (values net2 cid key)]))

(define (eclass-intern-node net reg-cid op child-cids
                            #:cost [cost 1]
                            #:regime [regime 'ground])
  (guard-ground-path! 'eclass-intern-node op)
  (define sig (eclass-node-signature net op child-cids))
  (define reg (net-cell-read net reg-cid))
  (define existing (and (hash? reg) (hash-ref reg sig #f)))
  (cond
    [existing (values net (cdr existing) (list op child-cids (cdr existing) cost))]
    [else
     (define-values (net1 cid) (net-new-cell net eclass-bot eclass-merge))
     (define alloc (cell-id-n cid))
     ;; the node's FORM for cost purposes: the signature vector itself at v1
     ;; (real terms attach when reduction rules intern concrete exprs)
     (define form (list->vector (cons 'enode (cons op (map cell-id-n child-cids)))))
     (define v0 (make-eclass-value #:best (cons cost form)
                                   #:alts (set sig)
                                   #:canonical alloc
                                   #:provenance (set-add (seteq 'intern-node) (origin-marker))
                                   #:regime regime))
     (define net2 (net-cell-write net1 cid v0))
     (define net3 (net-cell-write net2 reg-cid (hash sig (cons alloc cid))))
     ;; 11b: seed the signature index + install the PARENT WATCHER — a plain
     ;; REFIREABLE propagator (congruence cascades refire it; fire-once would
     ;; consume its shot — the iter-4 lesson applied at design time) watching
     ;; ONLY the children's ':canonical components (asymmetric staleness: only
     ;; union-CHANGED canonicals matter; component-paths give the precision).
     (define net3a (net-cell-write net3 congruence-sig-index-cell-id
                                   (hash sig (set cid))))
     (define (watch net)
       (define sig* (eclass-node-signature net op child-cids))
       (define n1 (net-cell-write net congruence-sig-index-cell-id
                                  (hash sig* (set cid))))
       (net-cell-write n1 congruence-request-cell-id (hash sig* #t)))
     (define-values (net4 _wpid)
       (net-add-propagator net3a child-cids
                           (list congruence-sig-index-cell-id
                                 congruence-request-cell-id)
                           watch
                           #:component-paths
                           (for/list ([c (in-list child-cids)])
                             (cons c ':canonical))))
     ;; Track 4 Phase 1 (iter 29): the parent-descriptor index — child-keyed
     ;; (the cost-recompute fan-in projection); written here (cheap monotone),
     ;; consumed lazily by extraction. Descriptor gains node-cost as a 4th
     ;; element (older consumers access only the first three — compatible).
     (define descriptor (list op child-cids cid cost))
     (define pidx (current-parent-index-cell-id))
     (define net5
       (if pidx
           (for/fold ([n net4]) ([c (in-list child-cids)])
             (net-cell-write n pidx (hash (cell-id-n c) (set descriptor))))
           net4))
     (values net5 cid descriptor)]))

;; Collision scan: recompute every descriptor's signature against CURRENT
;; canonicals; group classes whose nodes now share a signature. Returns a list
;; of class-cid groups (each ≥2 distinct classes) needing union.
(define (eclass-congruence-collisions net descriptors)
  (define by-sig
    (for/fold ([acc (hash)]) ([d (in-list descriptors)])
      (define sig (eclass-node-signature net (car d) (cadr d)))
      (hash-update acc sig (lambda (s) (set-add s (caddr d))) (set))))
  (for/list ([(sig cids) (in-hash by-sig)]
             #:when (> (set-count cids) 1))
    (set->list cids)))

;; Batch union: chain 'eclass-refine relates across each group.
(define (eclass-union-all net groups)
  (for/fold ([n net]) ([group (in-list groups)])
    (for/fold ([n2 n]) ([a (in-list group)] [b (in-list (cdr group))])
      (eclass-union n2 a b))))

;; --- 11b: the congruence collision handler (topology tier) ---
;; Reads the round's CHANGED sigs (the request delta), consults the monotone
;; signature index, and installs 'eclass-refine relates for every collided
;; group. STATELESS: re-installing a relate for an already-unioned group is an
;; idempotent no-op at quiescence (the joins are equal) — bounded by the number
;; of sig-changes, which is bounded by unions. Topology tier: installing
;; propagators is a structural change (stratification.md request-accumulator
;; pattern; the cell is preallocated as cell-21).
(define (process-congruence-requests net pending)
  (define index (net-cell-read net congruence-sig-index-cell-id))
  (for/fold ([n net]) ([(sig _v) (in-hash pending)])
    (define group (and (hash? index) (hash-ref index sig #f)))
    (if (and group (> (set-count group) 1))
        (eclass-union-all n (list (set->list group)))
        n)))

(register-stratum-handler! congruence-request-cell-id
                           process-congruence-requests
                           #:tier 'topology
                           #:reset-value (hash))

;; --- driver-init plumbing (iter 22; same shape as the rule-registry cell) ---
;; iter 36 (Track 5 Phase 1): the intern ORIGIN — folded into every class's
;; provenance as (cons 'origin id); the serialize-time projection filters on it
;; (unknown ⇒ not projected — the pessimistic admission posture). The driver
;; sets it per file; bare contexts stay 'unknown.
(define current-intern-origin (make-parameter 'unknown))
;; the provenance MARKER is an INTERNED SYMBOL ("origin:<id>"), not a cons —
;; eq-sets with fresh cons members break VALUE equality (equal? fixpoints
;; compared unequal; the racing-union test caught it at iter 36 — data point:
;; eq-set members must be eq-stable across constructions)
(define (origin-marker)
  (string->symbol (format "origin:~a" (current-intern-origin))))
(define current-eclass-hashcons-cell-id (make-parameter #f))
(define (init-eclass-hashcons-cell! prn-box)
  (when prn-box
    (define-values (pnet* cid) (make-eclass-graph (unbox prn-box)))
    (current-eclass-hashcons-cell-id cid)
    (set-box! prn-box pnet*)))

;; --- Track 4 Phase 1 (iter 29): the parent-descriptor index cell ---
;; child-alloc → (set descriptor); hash-union-of-set-union (the iter-12 merge
;; shape). Child-keyed = the cost-recompute FAN-IN projection; extraction's
;; per-parent grouping derives by scan at request time (v1; a parent-keyed
;; second projection is the named refinement if scans show in profiles).
(define (parent-index-merge old new)
  (cond
    [(not (hash? old)) new]
    [(not (hash? new)) old]
    [else (for/fold ([acc old]) ([(k v) (in-hash new)])
            (hash-update acc k (lambda (s) (set-union s v)) (set)))]))

(define current-parent-index-cell-id (make-parameter #f))
(define (init-parent-index-cell! prn-box)
  (when prn-box
    (define-values (pnet* cid)
      (net-new-cell (unbox prn-box) (hash) parent-index-merge))
    (current-parent-index-cell-id cid)
    (set-box! prn-box pnet*)))
