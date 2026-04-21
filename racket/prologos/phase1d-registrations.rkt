#lang racket/base

;;;
;;; phase1d-registrations.rkt — PPN 4C Phase 1d bulk Tier 1+2 registrations
;;;
;;; Registers the remaining per-subsystem merge functions as SRE domains +
;;; Tier 2 merge-fn-registry entries. Separate module to:
;;;   (a) avoid inline-registration cycles (each module would pull
;;;       sre-core → ctor-registry → sessions → ... → back to itself)
;;;   (b) consolidate the Phase 1d registration campaign paper trail
;;;
;;; Loaded by driver.rkt for side-effect registration at module load.
;;;
;;; D2 framework (§6.9.2) per registration: aspirational / declared /
;;; inference / delta. Detailed tables in the Phase 1d commit message.
;;;
;;; NOT registered here:
;;;   - Facet merges (context-facet-merge, add-usage, constraint-merge,
;;;     warnings-facet-merge, hasse-merge-hash-union) — registered
;;;     in Phase 2 + 2b inline at their owning modules.
;;;   - Generic infra-cell merges — registered in
;;;     infra-cell-sre-registrations.rkt (Phase 1d-A).
;;;   - Replace-semantics merges (merge-replace, merge-last-write-wins) —
;;;     scoped to Phase 1e per-site audit.
;;;

(require (only-in "sre-core.rkt" make-sre-domain register-domain!)
         (only-in "merge-fn-registry.rkt" register-merge-fn!/lattice)
         ;; ATMS + decision-cell
         (only-in "decision-cell.rkt"
                  assumptions-merge
                  counter-merge
                  nogood-merge
                  scope-cell-merge
                  decisions-state-merge        ;; Phase 1d-D: compound decisions cell merge
                  commitments-state-merge)     ;; Phase 1d-D: compound commitments cell merge
         (only-in "atms.rkt"
                  table-registry-merge         ;; Phase 1e-β-ii: hoisted hasheq new-wins
                  table-answer-merge)          ;; Phase 1e-β-ii: hoisted dedup-append
         ;; Tabling
         (only-in "tabling.rkt"
                  wf-all-mode-merge)           ;; Phase 1d-D: well-founded tabling all-answers mode
         ;; Relations
         (only-in "relations.rkt"
                  discrimination-data-merge)
         ;; Note: logic-var-merge is NOT exported from relations.rkt;
         ;; registration deferred until it's exposed (relations.rkt
         ;; exports sweep — flag in DEFERRED if needed).
         ;; Session runtime + related
         (only-in "session-runtime.rkt"
                  choice-lattice-merge
                  msg-lattice-merge)
         (only-in "session-lattice.rkt" session-lattice-merge)
         (only-in "io-bridge.rkt" io-state-merge)
         (only-in "effect-position.rkt" eff-pos-merge)
         ;; Capability
         (only-in "capability-inference.rkt" cap-set-join)
         ;; Term / parse lattices
         (only-in "term-lattice.rkt" term-merge)
         (only-in "parse-lattice.rkt" parse-lattice-merge)
         (only-in "parse-reader.rkt" rrb-embedded-merge)
         ;; Typing propagators
         (only-in "typing-propagators.rkt"
                  attribute-map-merge-fn
                  meta-solution-merge)
         ;; Type lattice (already Tier 1-registered as type-sre-domain;
         ;; Phase 1d adds the Tier 2 merge-fn linkage)
         (only-in "type-lattice.rkt" type-lattice-merge))

;; ============================================================
;; Helper: minimal-declaration SRE domain + Tier 2 link
;; ============================================================

;; Most merge functions here have #:contradicts? = (lambda (v) #f)
;; (they don't detect contradiction explicitly — the lattice's top-value
;; is checked elsewhere). Keeping minimal declarations; D2 inference
;; later (Phase 1e audit) can refine.

;; PPN 4C Phase 3e (2026-04-20): #:classification kwarg added. Default
;; 'unclassified preserves the progressive-rollout pattern from Phase 1f.
;; Pass #:classification 'structural to enable Phase 1f :component-paths
;; enforcement on cells of this domain.
(define (register/minimal domain-name merge-fn bot-predicate bot-value
                          #:classification [classification 'unclassified])
  (define d (make-sre-domain
             #:name domain-name
             #:merge-registry (lambda (r)
                                (case r
                                  [(equality) merge-fn]
                                  [else (error 'phase1d-registration
                                               "no merge for relation: ~a" r)]))
             #:contradicts? (lambda (v) #f)
             #:bot? bot-predicate
             #:bot-value bot-value
             #:classification classification))
  (register-domain! d)
  (register-merge-fn!/lattice merge-fn #:for-domain domain-name))

;; ============================================================
;; ATMS + decision-cell
;; ============================================================

(register/minimal 'atms-assumptions assumptions-merge
                  (lambda (v) #f) #f)  ;; assumptions-empty sentinel opaque
(register/minimal 'counter counter-merge
                  (lambda (v) (and (number? v) (zero? v))) 0)  ;; max-join, PROPER lattice
(register/minimal 'nogood-set nogood-merge
                  (lambda (v) (and (list? v) (null? v))) '())
(register/minimal 'scope-cell scope-cell-merge
                  (lambda (v) (eq? v 'infra-bot)) 'infra-bot)

;; Phase 1d-D: compound state cells from decision-cell.rkt
;; Both are STRUCTURAL lattices — per-component monotone merge.
;; bot values are (decisions-state-empty N) / (commitments-state-empty)
;; — opaque to this registration (N varies by assumption-id-n at site).
(register/minimal 'decisions-state decisions-state-merge
                  (lambda (v) #f) #f)  ;; bot is per-site-N; opaque
(register/minimal 'commitments-state commitments-state-merge
                  (lambda (v) #f) #f)  ;; bot is struct; opaque

;; Phase 1e-β-ii: ATMS table-* cells (hoisted from local defines).
;; table-registry-merge has replace-hasheq semantics — register under
;; existing 'hasheq-replace domain (same as infra-cell's merge-hasheq-
;; replace). atms.rkt can't import infra-cell (cycle), so the function
;; is a separate instance with equivalent semantics.
(register-merge-fn!/lattice table-registry-merge #:for-domain 'hasheq-replace)
;; table-answer-merge has dedup-append semantics — register under
;; existing 'dedup-list-append domain (same as infra-cell's merge-
;; list-dedup-append). Ditto cycle-avoidance rationale.
(register-merge-fn!/lattice table-answer-merge #:for-domain 'dedup-list-append)

;; ============================================================
;; Relations
;; ============================================================

;; logic-var-merge — deferred (not exported from relations.rkt)
;; solver-term-merge — deferred (not exported from relations.rkt;
;;   Phase 1d-D follow-up alongside logic-var-merge — both are
;;   relations.rkt internal merge fns not currently surfaced).
(register/minimal 'discrimination-data discrimination-data-merge
                  (lambda (v) #f) #f)

;; Phase 1d-D: well-founded tabling all-answers mode
(register/minimal 'wf-all-mode wf-all-mode-merge
                  (lambda (v) (and (list? v) (null? v))) '())

;; ============================================================
;; Session runtime + session lattice + IO + effects
;; ============================================================

(register/minimal 'session-choice choice-lattice-merge
                  (lambda (v) #f) #f)
(register/minimal 'session-message msg-lattice-merge
                  (lambda (v) #f) #f)
(register/minimal 'session session-lattice-merge
                  (lambda (v) #f) #f)
(register/minimal 'io-state io-state-merge
                  (lambda (v) #f) #f)
(register/minimal 'effect-position eff-pos-merge
                  (lambda (v) #f) #f)

;; ============================================================
;; Capability — PROPER join-semilattice (set-union is comm+assoc+idem)
;; ============================================================

(register/minimal 'capability-set cap-set-join
                  (lambda (v) #f) #f)  ;; cap-set empty check opaque

;; ============================================================
;; Term / parse lattices
;; ============================================================

(register/minimal 'narrowing-term term-merge
                  (lambda (v) #f) #f)  ;; term-bot opaque
(register/minimal 'parse parse-lattice-merge
                  (lambda (v) #f) #f)  ;; parse-bot/parse-top opaque
(register/minimal 'rrb-embedded rrb-embedded-merge
                  (lambda (v) #f) #f)  ;; rrb-empty? opaque

;; ============================================================
;; Typing propagators — attribute-map + meta-solution
;; ============================================================

;; 'attribute-map — the compound facet-map carrier. Cell value is
;; (hasheq position → (hasheq facet → value)). Merge is pointwise
;; per-facet via facet-merge dispatch. Commutative iff each inner
;; facet merge is commutative (D2 delta per facet documents).
;;
;; PPN 4C Phase 3e (2026-04-20): classified 'structural. Per §6.15.5,
;; this enables Phase 1f :component-paths enforcement for propagators
;; reading attribute-map cells. Each propagator must declare which
;; (position, facet) pairs it watches, or justify a whole-cell read
;; (§6.15.5: "rare for structural cells; if it exists, it's a design
;; question"). Phase 3e audits the typing-propagators.rkt installations
;; and tightens declarations or defers restructuring.
(register/minimal 'attribute-map attribute-map-merge-fn
                  (lambda (v) (and (hash? v) (zero? (hash-count v))))
                  (hasheq)
                  #:classification 'structural)

;; 'meta-solution — list-append semantics for accumulating meta
;; solutions. D2 delta: non-commutative list concatenation;
;; accepted as accumulator pattern.
(register/minimal 'meta-solution meta-solution-merge
                  (lambda (v) (and (list? v) (null? v)))
                  '())

;; ============================================================
;; Type lattice — Tier 2 link for existing type-sre-domain (Tier 1)
;; ============================================================
;;
;; type-sre-domain is registered at unify.rkt:109. Phase 1d adds the
;; Tier 2 merge-fn linkage so cells using type-lattice-merge inherit
;; the 'type domain automatically.

(register-merge-fn!/lattice type-lattice-merge #:for-domain 'type)
