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
         format-sd-findings)

;; ========================================================================
;; sd-finding record
;; ========================================================================
;; Records the outcome of one (domain, relation, property) sweep check.
;;
;;   domain-name   — symbol (sre-domain-name, e.g. 'type)
;;   relation      — symbol ('equality | 'subtype | ...)
;;   property      — symbol ('distributive | 'sd-vee | 'sd-wedge)
;;   sample-count  — int (atoms count after generation; same per (domain, depth))
;;   evidence      — sd-evidence struct (for SD properties)
;;                 OR axiom-confirmed / axiom-refuted / axiom-untested
;;                    (for distributive — has no hypothesis-firing semantics)
(struct sd-finding
  (domain-name
   relation
   property
   sample-count
   evidence)
  #:transparent)

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
;;
;; Returns: (listof sd-finding) — 3 findings per relation; flattened.
(define (run-sd-sweep domain
                      relations
                      base-atoms
                      #:max-depth [max-depth 1]
                      #:per-ctor-count [per-ctor-count 2])
  (define samples
    (generate-domain-samples domain
                             #:max-depth max-depth
                             #:per-ctor-count per-ctor-count
                             #:base-values base-atoms))
  (define sample-count (length samples))
  (define domain-name (sre-domain-name domain))
  (apply append
         (for/list ([rel (in-list relations)])
           (define meet-fn (sre-domain-meet domain rel))
           (list
             (sd-finding domain-name rel 'distributive sample-count
                         (test-distributive domain samples meet-fn))
             (sd-finding domain-name rel 'sd-vee sample-count
                         (test-sd-vee/detailed domain samples meet-fn))
             (sd-finding domain-name rel 'sd-wedge sample-count
                         (test-sd-wedge/detailed domain samples meet-fn))))))

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

(define (format-sd-finding-row f)
  (define domain  (~a (sd-finding-domain-name f)))
  (define rel     (~a (sd-finding-relation f)))
  (define prop    (~a (sd-finding-property f)))
  (define samples (~a (sd-finding-sample-count f)))
  (define ev      (sd-finding-evidence f))
  (define-values (status triples hyp-fired conc-held non-vac witness)
    (cond
      [(sd-evidence? ev)
       (define total (sd-evidence-total-checked ev))
       (define fired (sd-evidence-hypothesis-fired ev))
       (define held  (sd-evidence-conclusion-held ev))
       (values (~a (sd-evidence-status ev))
               (~a total)
               (~a fired)
               (~a held)
               (non-vacuity-pct fired total)
               (witness->string (sd-evidence-witness ev)))]
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
       (values "untested" "—" "—" "—" "—" "—")]
      [else
       (values "unknown" "—" "—" "—" "—" "—")]))
  (format "| ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a |"
          domain rel prop samples status triples hyp-fired conc-held non-vac witness))

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
           "syntax.rkt")
  (define type-domain (lookup-domain 'type))
  (define realistic-type-atoms
    (list (expr-Int) (expr-Bool) (expr-Nat) (expr-String)))
  (displayln ";; SRE Track 2I Phase 3 — wider-sample sweep findings")
  (displayln ";; Generated via: racket sre-property-sweep.rkt")
  (displayln ";; Sample params: max-depth 1, per-ctor-count 2, 4 realistic atoms")
  (newline)
  (define findings
    (time
     (run-sd-sweep type-domain
                   '(equality subtype)
                   realistic-type-atoms
                   #:max-depth 1
                   #:per-ctor-count 2)))
  (newline)
  (displayln (format-sd-findings findings)))
