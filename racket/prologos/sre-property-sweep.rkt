#lang racket/base

;;; SRE Track 2I Phase 3: Property sweep (empirical algebraic-property check)
;;;
;;; Walks (domain, relation) pairs running {distributive, sd-vee, sd-wedge}
;;; against samples generated from the per-domain ctor registry plus
;;; caller-supplied base atoms. Produces sd-finding records and a markdown
;;; findings table for design-doc reporting.
;;;
;;; Design references:
;;;   - docs/tracking/2026-04-30_SRE_TRACK2I_SD_CHECKS_DESIGN.md § Phase 3
;;;     ("Locked decisions" subsection — Q1 separate file, Q2 caller-supplied
;;;     atoms, Q3 distributive+SD together, sd-finding shape, table columns)
;;;   - docs/research/2026-04-30_LATTICE_HIERARCHY_AND_DISTRIBUTIVITY_FOR_PROPAGATORS.md
;;;     §5.1+§5.2 (what each algebraic level unlocks)
;;;
;;; Architecture per Phase 3 mini-design:
;;;   - Sweep is GENERIC over (domain, relations, atoms, depth-config)
;;;   - Atoms are caller-supplied per-domain config (no hardcoded defaults)
;;;   - Properties run TOGETHER per (domain, relation), reifying the
;;;     implication chain `distributive ⇒ sd-vee ∧ sd-wedge`
;;;   - Per-relation meet via sre-domain-meet (Phase 3c registry; principled
;;;     dispatch, NOT off-network callback)
;;;   - /detailed SD variants surface vacuous-vs-non-vacuous counts
;;;
;;; Mantra check: this is off-network sample-check infrastructure (existing
;;; Track 2G scaffolding lineage). Labeled scaffolding, NOT new debt.
;;; Retirement direction: would migrate to property-cells with monotone-merge
;;; if/when broader property-check infrastructure migrates on-network
;;; (sister concern of PM Track 12's callback retirement scope).

(require racket/list)
(require racket/format)
(require racket/string)
(require "sre-core.rkt")
(require "sre-sample-generator.rkt")

(provide (struct-out sd-finding)
         run-sd-sweep
         format-sd-findings
         format-variety-placement-summary
         all-sweep-properties)

;; ========================================================================
;; sd-finding record
;; ========================================================================
;; Records the outcome of one (domain, relation, property) sweep check.
;;
;;   domain-name      — symbol (sre-domain-name, e.g. 'type)
;;   relation         — symbol ('equality | 'subtype | ...)
;;   property         — symbol (10 algebraic properties — see all-sweep-properties)
;;   sample-count     — int (atoms count after generation; same per (domain, depth))
;;   evidence         — one of: sd-evidence, pc-rel-evidence, modular-evidence,
;;                      whitman-evidence, axiom-confirmed, axiom-refuted, axiom-untested
;;   untested-reason  — symbol or #f. Phase 9 (Q7): when status is untested,
;;                      records cause: 'no-relation (relation absent from
;;                      sre-domain meet-registry), 'no-meet-fn (meet-registry
;;                      returns #f), 'no-join-fn (merge-registry returns #f),
;;                      or #f when result is tested (confirmed/refuted).
(struct sd-finding
  (domain-name
   relation
   property
   sample-count
   evidence
   untested-reason)
  #:transparent)

;; The 10 algebraic properties Phase 9 sweeps across.
;; Ordered to surface variety-relevant grouping (per PTF Lattice Hierarchy §3):
;;   - free-lattice membership: whitmans-condition (Nation 1982)
;;   - SD: sd-vee, sd-wedge (Jónsson-Kiefer 1962)
;;   - modular layer (between SD and distributive)
;;   - distributive
;;   - Heyting layer: pseudo-complement family + Stone identity
;;   - complement family: relatively-complemented, sectionally-complemented,
;;     breadth-bound (Hasse-structural)
(define all-sweep-properties
  '(distributive
    sd-vee sd-wedge
    modular
    has-pseudo-complement-rel has-pseudo-complement-abs
    stone-identity
    whitmans-condition
    relatively-complemented sectionally-complemented
    breadth-bound
    has-complement))  ;; Phase 11: Boolean placement

;; ========================================================================
;; run-sd-sweep
;; ========================================================================
;; Runs {distributive, sd-vee, sd-wedge} per (domain, relation) and returns
;; a flat list of sd-finding records.
;;
;; domain          — sre-domain struct
;; relations       — list of relation symbols (e.g. '(equality subtype))
;; base-atoms      — per-domain caller-supplied list of representative
;;                   atomic values (e.g. realistic-type-atoms for type domain)
;;
;; #:max-depth     — sample-generator depth (default 1; see Phase 2a)
;; #:per-ctor-count — sample-generator Cartesian width (default 2)
;; #:cross-domain-atoms — Phase 7: hash spec → atom-list for ctor slots
;;                   from other domains. E.g., sweeping session domain
;;                   requires `(hasheq 'type type-atoms)` because session
;;                   ctors (sess-send/recv/...) have type-payload slots.
;;                   Default empty hasheq (no cross-domain ctors).
;;
;; Returns: (listof sd-finding) — len(properties) findings per relation; flattened.
;;
;; Phase 9 (2026-05-07): swept-properties is configurable; defaults to
;; `all-sweep-properties` (10 algebraic properties). Each finding carries
;; an `untested-reason` indicating WHY a result is untested when applicable
;; ('no-relation if rel absent from registry; 'no-meet-fn / 'no-join-fn for
;; specific lookups returning #f). Honest coverage map.
(define (run-sd-sweep domain
                      relations
                      base-atoms
                      #:max-depth [max-depth 1]
                      #:per-ctor-count [per-ctor-count 2]
                      #:cross-domain-atoms [cross-domain-atoms (hasheq)]
                      ;; Phase 8: domains may have non-trivial bot/top that
                      ;; aren't safe to feed through merge/meet (e.g.,
                      ;; form-cell top-value defaults to #f, breaks
                      ;; form-pipeline-merge contract). Caller controls.
                      #:include-bot-top [include-bot-top #t]
                      ;; Phase 9: which properties to sweep (default = all 10)
                      #:properties [properties all-sweep-properties])
  (define samples
    (generate-domain-samples domain
                             #:max-depth max-depth
                             #:per-ctor-count per-ctor-count
                             #:base-values base-atoms
                             #:include-bot-top include-bot-top
                             #:cross-domain-atoms cross-domain-atoms))
  (define sample-count (length samples))
  (define domain-name (sre-domain-name domain))
  ;; Phase 4: derive both meet-fn and join-fn from the SAME relation
  ;; (avoids lattice-mixing — see sre-core.rkt test-distributive comment).
  (define merge-registry (sre-domain-merge-registry domain))
  (define meet-registry (sre-domain-meet-registry domain))
  (apply append
         (for/list ([rel (in-list relations)])
           ;; Phase 9 (Q7): determine untested-reason if any prerequisite missing
           (define rel-in-meet-registry?
             (and meet-registry
                  (with-handlers ([exn:fail? (λ (_) #f)])
                    (meet-registry rel))))
           (define rel-in-merge-registry?
             (and merge-registry
                  (with-handlers ([exn:fail? (λ (_) #f)])
                    (merge-registry rel))))
           (define meet-fn (and rel-in-meet-registry? (sre-domain-meet domain rel)))
           (define join-fn (and rel-in-merge-registry? (merge-registry rel)))
           (define base-untested-reason
             (cond
               [(not rel-in-meet-registry?) 'no-relation]
               [(not meet-fn) 'no-meet-fn]
               [(not join-fn) 'no-join-fn]
               [else #f]))
           (for/list ([prop (in-list properties)])
             (sweep-one-property domain domain-name rel prop sample-count
                                 samples meet-fn join-fn base-untested-reason)))))

;; Run a single property check and produce an sd-finding.
;; If prerequisites missing (base-untested-reason is non-#f), short-circuit
;; with axiom-untested + the given reason. Otherwise dispatch on property symbol.
(define (sweep-one-property domain domain-name rel prop sample-count
                            samples meet-fn join-fn base-untested-reason)
  (cond
    [base-untested-reason
     (sd-finding domain-name rel prop sample-count
                 axiom-untested base-untested-reason)]
    [else
     (define ev
       (case prop
         [(distributive)
          (test-distributive domain samples meet-fn join-fn)]
         [(sd-vee)
          (test-sd-vee/detailed domain samples meet-fn join-fn)]
         [(sd-wedge)
          (test-sd-wedge/detailed domain samples meet-fn join-fn)]
         [(modular)
          (test-modular/detailed domain samples meet-fn join-fn)]
         [(has-pseudo-complement-rel)
          (test-pseudo-complement-rel/detailed domain samples meet-fn join-fn)]
         [(has-pseudo-complement-abs)
          (test-pseudo-complement-abs domain samples meet-fn join-fn)]
         [(stone-identity)
          (test-stone-identity domain samples meet-fn join-fn)]
         [(whitmans-condition)
          (test-whitmans-condition/detailed domain samples meet-fn join-fn)]
         [(relatively-complemented)
          (test-relatively-complemented domain samples meet-fn join-fn)]
         [(sectionally-complemented)
          (test-sectionally-complemented domain samples meet-fn join-fn)]
         [(breadth-bound)
          ;; test-breadth-bound takes (domain samples meet-fn #:max-width k)
          ;; — no join-fn (Hasse-structural). Default #:max-width 4 per Phase 6.
          (test-breadth-bound domain samples meet-fn)]
         [(has-complement)
          ;; Phase 11: per-element search for complement (a∧x=⊥, a∨x=⊤)
          (test-has-complement/detailed domain samples meet-fn join-fn)]
         [else axiom-untested]))
     (sd-finding domain-name rel prop sample-count ev #f)]))

;; ========================================================================
;; format-sd-findings
;; ========================================================================
;; Produces a markdown table from a list of sd-findings.
;;
;; Columns: Domain | Relation | Property | Samples | Status |
;;          Triples | Hypothesis fired | Conclusion held | Non-vacuity % | Witness
;;
;; Distributive findings have no hypothesis-firing semantics; their
;; "hypothesis fired" and "conclusion held" columns mirror the triples count
;; (every triple is a real check) and non-vacuity is 100%.
;;
;; SD findings (sd-evidence) report vacuous-vs-fired distinction: non-vacuity
;; below ~30% means the SD-confirmed result is informationally weak (most
;; triples didn't fire the hypothesis).
(define (format-sd-findings findings)
  (define header
    "| Domain | Relation | Property | Samples | Status | Triples | Hypothesis fired | Conclusion held | Non-vacuity % | Witness |")
  (define separator
    "|---|---|---|---|---|---|---|---|---|---|")
  (define rows
    (for/list ([f (in-list findings)])
      (format-sd-finding-row f)))
  (string-join (cons header (cons separator rows)) "\n"))

;; Phase 9: extract (status total fired held witness) uniformly from any
;; detailed-evidence struct — sd-evidence, pc-rel-evidence, modular-evidence,
;; whitman-evidence all share the same field shape. Returns #f if not detailed.
(define (extract-detailed-fields ev)
  (cond
    [(sd-evidence? ev)
     (list (sd-evidence-status ev)
           (sd-evidence-total-checked ev)
           (sd-evidence-hypothesis-fired ev)
           (sd-evidence-conclusion-held ev)
           (sd-evidence-witness ev))]
    [(pc-rel-evidence? ev)
     (list (pc-rel-evidence-status ev)
           (pc-rel-evidence-total-checked ev)
           (pc-rel-evidence-hypothesis-fired ev)
           (pc-rel-evidence-conclusion-held ev)
           (pc-rel-evidence-witness ev))]
    [(modular-evidence? ev)
     (list (modular-evidence-status ev)
           (modular-evidence-total-checked ev)
           (modular-evidence-hypothesis-fired ev)
           (modular-evidence-conclusion-held ev)
           (modular-evidence-witness ev))]
    [(complement-evidence? ev)  ;; Phase 11
     (list (complement-evidence-status ev)
           (complement-evidence-total-checked ev)
           (complement-evidence-hypothesis-fired ev)
           (complement-evidence-conclusion-held ev)
           (complement-evidence-witness ev))]
    [(whitman-evidence? ev)
     (list (whitman-evidence-status ev)
           (whitman-evidence-total-checked ev)
           (whitman-evidence-hypothesis-fired ev)
           (whitman-evidence-conclusion-held ev)
           (whitman-evidence-witness ev))]
    [else #f]))

(define (format-sd-finding-row f)
  (define domain  (~a (sd-finding-domain-name f)))
  (define rel     (~a (sd-finding-relation f)))
  (define prop    (~a (sd-finding-property f)))
  (define samples (~a (sd-finding-sample-count f)))
  (define ev      (sd-finding-evidence f))
  (define ur      (sd-finding-untested-reason f))
  (define detailed (extract-detailed-fields ev))
  (define-values (status triples hyp-fired conc-held non-vac witness)
    (cond
      [detailed
       (define st (first detailed))
       (define total (second detailed))
       (define fired (third detailed))
       (define held  (fourth detailed))
       (define wit   (fifth detailed))
       (values (~a st)
               (~a total)
               (~a fired)
               (~a held)
               (non-vacuity-pct fired total)
               (witness->string wit))]
      [(axiom-confirmed? ev)
       (define total (axiom-confirmed-count ev))
       (values "confirmed"
               (~a total)
               (~a total)
               (~a total)
               "100.0%"
               "—")]
      [(axiom-refuted? ev)
       (values "refuted"
               "—"
               "—"
               "—"
               "—"
               (witness->string (axiom-refuted-witness ev)))]
      [(eq? ev axiom-untested)
       ;; Phase 9 Q7: include untested-reason if present
       (values (if ur (format "untested (~a)" ur) "untested")
               "—" "—" "—" "—" "—")]
      [else
       (values "unknown" "—" "—" "—" "—" "—")]))
  (format "| ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a |"
          domain rel prop samples status triples hyp-fired conc-held non-vac witness))

;; ========================================================================
;; format-variety-placement-summary
;; ========================================================================
;; Phase 9 Q2 (c) — Two-table approach. This is the FIRST table: at-a-glance
;; variety placement per (domain, relation, depth). Each row shows boolean
;; variety membership across the PTF Lattice Hierarchy levels.
;;
;; Columns: Domain | Relation | SD | Modular | Distributive | Heyting | Stone | Boolean | Notes
;;
;; Variety-placement is derived from raw findings via implication rules:
;;   - SD: sd-vee ∧ sd-wedge confirmed
;;   - Modular: modular confirmed
;;   - Distributive: distributive confirmed
;;   - Heyting: distributive ∧ has-pseudo-complement-rel confirmed
;;   - Stone: distributive ∧ has-pseudo-complement-rel ∧ stone-identity confirmed
;;   - Boolean: heyting ∧ has-complement (Phase 11 added empirical
;;     has-complement check; was reported as "—" pre-Phase-11)
;;
;; "Notes" column flags Whitman's W (FL membership) status, breadth bound,
;; and any honest gaps (untested due to no-relation etc.).
(define (format-variety-placement-summary findings)
  (define grouped
    (group-findings-by-domain-rel findings))
  (define header
    "| Domain | Relation | SD | Modular | Distributive | Heyting | Stone | Boolean | (W) | Notes |")
  (define separator
    "|---|---|---|---|---|---|---|---|---|---|")
  (define rows
    (for/list ([key+findings (in-list grouped)])
      (define key (car key+findings))
      (define group-findings (cdr key+findings))
      (format-variety-row key group-findings)))
  (string-join (cons header (cons separator rows)) "\n"))

;; Group findings list by (domain-name, relation) — returns list of pairs:
;;   ((domain . relation) . (listof sd-finding))
(define (group-findings-by-domain-rel findings)
  (define groups (make-hash))
  (for ([f (in-list findings)])
    (define key (cons (sd-finding-domain-name f) (sd-finding-relation f)))
    (hash-update! groups key (λ (acc) (cons f acc)) '()))
  (for/list ([(k v) (in-hash groups)])
    (cons k (reverse v))))

(define (format-variety-row key findings)
  (define domain (car key))
  (define rel    (cdr key))
  (define (status-of prop)
    (define f (findf (λ (f) (eq? (sd-finding-property f) prop)) findings))
    (cond
      [(not f) 'absent]
      [(sd-finding-untested-reason f) 'untested]
      [else (evidence-status (sd-finding-evidence f))]))
  (define (cell-for status)
    (case status
      [(confirmed) "✓"]
      [(refuted)   "✗"]
      [(untested)  "—"]
      [(absent)    "—"]
      [else        "?"]))
  ;; Variety membership derivations
  (define sd-status
    (cond
      [(and (eq? (status-of 'sd-vee) 'confirmed)
            (eq? (status-of 'sd-wedge) 'confirmed))
       'confirmed]
      [(or (eq? (status-of 'sd-vee) 'refuted)
           (eq? (status-of 'sd-wedge) 'refuted))
       'refuted]
      [else 'untested]))
  (define mod-status (status-of 'modular))
  (define dist-status (status-of 'distributive))
  (define pc-rel-status (status-of 'has-pseudo-complement-rel))
  (define stone-id-status (status-of 'stone-identity))
  (define heyting-status
    (cond
      [(and (eq? dist-status 'confirmed) (eq? pc-rel-status 'confirmed)) 'confirmed]
      [(or (eq? dist-status 'refuted) (eq? pc-rel-status 'refuted)) 'refuted]
      [else 'untested]))
  (define stone-status
    (cond
      [(and (eq? heyting-status 'confirmed) (eq? stone-id-status 'confirmed)) 'confirmed]
      [(or (eq? heyting-status 'refuted) (eq? stone-id-status 'refuted)) 'refuted]
      [else 'untested]))
  ;; Boolean = Heyting + has-complement (Phase 11: now empirically swept)
  (define has-complement-status (status-of 'has-complement))
  (define boolean-status
    (cond
      [(and (eq? heyting-status 'confirmed) (eq? has-complement-status 'confirmed)) 'confirmed]
      [(or (eq? heyting-status 'refuted) (eq? has-complement-status 'refuted)) 'refuted]
      [else 'untested]))
  (define w-status (status-of 'whitmans-condition))
  ;; Notes: untested reasons + breadth/sectional-complemented summaries
  (define untested-reasons
    (remove-duplicates
     (filter values
             (for/list ([f (in-list findings)])
               (and (eq? (status-of (sd-finding-property f)) 'untested)
                    (sd-finding-untested-reason f))))))
  (define notes
    (cond
      [(null? untested-reasons) "—"]
      [else (string-join (map ~a untested-reasons) ", ")]))
  (format "| ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a |"
          domain rel
          (cell-for sd-status)
          (cell-for mod-status)
          (cell-for dist-status)
          (cell-for heyting-status)
          (cell-for stone-status)
          (cell-for boolean-status)
          (cell-for w-status)
          notes))

;; Get the empirical status of evidence (confirmed/refuted/untested), uniform
;; over detailed-evidence and axiom-* shapes.
(define (evidence-status ev)
  (cond
    [(extract-detailed-fields ev)
     => (λ (fields) (first fields))]
    [(axiom-confirmed? ev) 'confirmed]
    [(axiom-refuted? ev)   'refuted]
    [(eq? ev axiom-untested) 'untested]
    [else 'unknown]))

(define (non-vacuity-pct fired total)
  (cond
    [(zero? total) "n/a"]
    [else (format "~a%"
                  (~r (* 100.0 (/ fired total))
                      #:precision '(= 1)))]))

(define (witness->string w)
  (cond
    [(not w) "—"]
    [else (format "`~v`" w)]))

;; ========================================================================
;; main — one-off invocation for design-doc findings table
;; ========================================================================
;; Run via: racket sre-property-sweep.rkt
;; Produces the wider-sample findings markdown table, suitable for capturing
;; into design doc § Phase 3 Findings as a versioned artifact.
;;
;; Wider-sample params: max-depth 1 + per-ctor-count 2 + 4 realistic atoms
;; → ~50 samples, ~750k merge/meet calls across 6 checks. Takes 30-60s.
;; This invocation is for capturing the findings table; the test suite uses
;; depth-0 for fast regression of the sweep mechanism (see
;; tests/test-sre-sd-properties.rkt).

(module+ main
  (require "driver.rkt"
           "syntax.rkt"
           "sessions.rkt")
  (define type-domain (lookup-domain 'type))
  (define session-domain (lookup-domain 'session))
  (define realistic-type-atoms
    (list (expr-Int) (expr-Bool) (expr-Nat) (expr-String)))
  (define realistic-session-atoms
    (list (sess-end) (sess-svar 0)))
  ;; Type domain sweep
  (displayln ";; SRE Track 2I Phase 3 — wider-sample sweep findings (TYPE domain)")
  (displayln ";; Generated via: racket sre-property-sweep.rkt")
  (displayln ";; Sample params: max-depth 1, per-ctor-count 2, 4 realistic atoms")
  (newline)
  (define type-findings
    (time
     (run-sd-sweep type-domain
                   '(equality subtype)
                   realistic-type-atoms
                   #:max-depth 1
                   #:per-ctor-count 2)))
  (newline)
  (displayln (format-sd-findings type-findings))
  ;; Session domain sweep (Phase 7)
  (newline)
  (displayln ";; SRE Track 2I Phase 7 — wider-sample sweep findings (SESSION domain)")
  (displayln ";; Cross-domain atoms: realistic-type-atoms for type-payload slots")
  (newline)
  (define session-findings
    (time
     (run-sd-sweep session-domain
                   '(equality)
                   realistic-session-atoms
                   #:max-depth 1
                   #:per-ctor-count 2
                   #:cross-domain-atoms (hasheq 'type realistic-type-atoms))))
  (newline)
  (displayln (format-sd-findings session-findings)))
