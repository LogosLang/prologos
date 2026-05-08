#lang racket/base

;;; SRE Track 2I Phase 9b: Comprehensive lattice variety sweep.
;;;
;;; Runs `run-sd-sweep` across all 4 SRE-registered domains × all relations ×
;;; all 11 algebraic properties (per `all-sweep-properties`) at depth-0
;;; (ground sublattice) AND depth-1 (binder/compound-included). Captures
;;; the structured findings into:
;;;
;;;   1. **Variety-placement summary table** (Q2(c) FIRST table) — at-a-glance
;;;      hierarchy placement per (domain, relation, depth) row
;;;   2. **Per-finding detail table** (Q2(c) SECOND table) — full evidence
;;;      with non-vacuity ratios + footnoted witnesses
;;;   3. **Witness footnotes** — refutation witnesses (W1, W2, ...)
;;;
;;; Output is markdown to stdout. Capture with redirection for design doc:
;;;   racket tools/run-phase9-sweep.rkt > /tmp/phase9-findings.md
;;;
;;; Usage from project root:
;;;   cd /Users/avanti/dev/projects/prologos/racket/prologos
;;;   racket tools/run-phase9-sweep.rkt
;;;
;;; Estimated wall time: ~45-60 min (one-time; Type domain depth-1 sweep
;;; dominates ~40 min for Whitman's W + breadth-bound + rel-complemented at
;;; N=58). Other 3 domains complete in <5 min total.

(require racket/cmdline
         racket/list
         racket/set
         racket/string
         racket/format
         "../driver.rkt"
         "../sre-core.rkt"
         "../sre-property-sweep.rkt"
         "../syntax.rkt"
         "../sessions.rkt"
         "../surface-rewrite.rkt"
         (only-in "../form-cells.rkt"
                  form-cell-bot
                  spec-cell-bot
                  spec-cell-value))

;; ============================================================================
;; Per-domain atom fixtures
;; ============================================================================
;; Mirror the test-sre-sd-properties.rkt definitions.

(define realistic-type-atoms
  (list (expr-Int) (expr-Bool) (expr-Nat) (expr-String)))

(define realistic-session-atoms
  (list (sess-end) (sess-svar 0)))

;; Form-cell atoms — mix constant-metadata + vary-metadata atoms (Phase 8).
(define form-cell-atom-bot form-cell-bot)
(define form-cell-atom-tagged
  (form-pipeline-value (seteq 'tagged) #f '() #f (hasheq)))
(define form-cell-atom-grouped
  (form-pipeline-value (seteq 'grouped) #f '() #f (hasheq)))
(define form-cell-atom-tagged+grouped
  (form-pipeline-value (seteq 'tagged 'grouped) #f '() #f (hasheq)))
(define form-cell-atom-done
  (form-pipeline-value (seteq 'done) #f '() #f (hasheq)))
(define form-cell-atom-tagged-with-node
  (form-pipeline-value (seteq 'tagged) 'mock-tree-node-A '((reg-1 . val-1)) 'pos-A (hasheq)))
(define form-cell-atom-tagged-with-other-node
  (form-pipeline-value (seteq 'tagged) 'mock-tree-node-B '((reg-2 . val-2)) 'pos-B (hasheq)))

(define realistic-form-cell-atoms
  (list form-cell-atom-bot
        form-cell-atom-tagged
        form-cell-atom-grouped
        form-cell-atom-tagged+grouped
        form-cell-atom-done
        form-cell-atom-tagged-with-node
        form-cell-atom-tagged-with-other-node))

;; Spec-cell atoms (Phase 8d).
(define realistic-spec-cell-atoms
  (list spec-cell-bot
        (spec-cell-value 'foo 'mock-Int-surf #f #f)
        (spec-cell-value 'foo 'mock-Bool-surf #f #f)
        (spec-cell-value 'bar 'mock-Int-surf #f #f)
        (spec-cell-value #f #f #f #t)))  ;; collision-top

;; ============================================================================
;; Domain configuration table
;; ============================================================================
;; Each entry is: (domain-name relations atoms cross-domain-atoms include-bot-top?)

(define sweep-config
  (list
    (list 'type
          '(equality subtype)
          realistic-type-atoms
          (hasheq)
          #t)
    (list 'session
          '(equality)
          realistic-session-atoms
          (hasheq 'type realistic-type-atoms)
          #t)
    (list 'form-cell
          '(equality)
          realistic-form-cell-atoms
          (hasheq)
          ;; form-cell top-value defaults to #f (no real top); skip bot-top
          ;; inclusion to avoid #f reaching merge/meet (Phase 8 lesson).
          #f)
    (list 'spec-cell
          '(equality)
          realistic-spec-cell-atoms
          (hasheq)
          ;; spec-cell atoms already include explicit bot + top.
          #f)))

;; ============================================================================
;; Sweep runner
;; ============================================================================

(define (run-domain-sweep cfg max-depth [properties-filter #f])
  (define domain-name (first cfg))
  (define relations   (second cfg))
  (define atoms       (third cfg))
  (define cross-doms  (fourth cfg))
  (define include-bt? (fifth cfg))
  (define domain (lookup-domain domain-name))
  (cond
    [(not domain)
     (eprintf "WARN: domain '~a not registered; skipping.\n" domain-name)
     '()]
    [else
     (eprintf ";; sweeping ~a × ~a at depth ~a~a... "
              domain-name relations max-depth
              (if properties-filter (format " [~a]" properties-filter) ""))
     (define start-ms (current-inexact-milliseconds))
     (define findings
       (cond
         [properties-filter
          (run-sd-sweep domain relations atoms
                        #:max-depth max-depth
                        #:per-ctor-count 2
                        #:cross-domain-atoms cross-doms
                        #:include-bot-top include-bt?
                        #:properties properties-filter)]
         [else
          (run-sd-sweep domain relations atoms
                        #:max-depth max-depth
                        #:per-ctor-count 2
                        #:cross-domain-atoms cross-doms
                        #:include-bot-top include-bt?)]))
     (define elapsed (- (current-inexact-milliseconds) start-ms))
     (eprintf "(~as, ~a findings)\n"
              (~r (/ elapsed 1000.0) #:precision '(= 1))
              (length findings))
     ;; Tag each finding with its depth (for grouping in the report).
     (map (λ (f) (list f max-depth)) findings)]))

(define (run-comprehensive-sweep [domain-filter #f]
                                 [depths '(0 1)]
                                 [relation-filter #f]
                                 [properties-filter #f])
  (define cfgs
    (cond
      [(not domain-filter) sweep-config]
      [else (filter (λ (cfg) (eq? (first cfg) domain-filter)) sweep-config)]))
  ;; Apply relation-filter by overriding the relations field of each config
  (define filtered-cfgs
    (cond
      [(not relation-filter) cfgs]
      [else
       (for/list ([cfg (in-list cfgs)])
         (define orig-rels (second cfg))
         (cond
           [(memq relation-filter orig-rels)
            (list (first cfg) (list relation-filter)
                  (third cfg) (fourth cfg) (fifth cfg))]
           [else
            (eprintf ";; WARN: relation '~a not in domain '~a (has ~a); skipping.\n"
                     relation-filter (first cfg) orig-rels)
            #f]))]))
  (define non-empty-cfgs (filter values filtered-cfgs))
  (apply append
         (for/list ([cfg (in-list non-empty-cfgs)])
           (apply append
                  (for/list ([d (in-list depths)])
                    (run-domain-sweep cfg d properties-filter))))))

;; ============================================================================
;; Markdown output
;; ============================================================================

(define (depth-tag d)
  (case d
    [(0) "ground"]
    [(1) "wider"]
    [else (~a "depth-" d)]))

;; Variety-placement summary table — extends the per-(domain, relation) summary
;; with a "Depth" column for Phase 9 multi-depth runs.
(define (format-multi-depth-variety-summary tagged-findings)
  ;; tagged-findings: (listof (list sd-finding depth-int))
  (define groups (make-hash))
  (for ([tf (in-list tagged-findings)])
    (define f (first tf))
    (define d (second tf))
    (define key (list (sd-finding-domain-name f) (sd-finding-relation f) d))
    (hash-update! groups key (λ (acc) (cons f acc)) '()))
  (define header
    "| Domain | Relation | Depth | SD | Modular | Distributive | Heyting | Stone | Boolean | (W) | Notes |")
  (define separator
    "|---|---|---|---|---|---|---|---|---|---|---|")
  (define keys (sort (hash-keys groups) key-sort-key))
  (define rows
    (for/list ([k (in-list keys)])
      (format-multi-depth-variety-row k (reverse (hash-ref groups k)))))
  (string-join (cons header (cons separator rows)) "\n"))

(define (key-sort-key a b)
  ;; Sort by (domain-name-string, relation-string, depth-int)
  (define a-d (~a (first a)))
  (define b-d (~a (first b)))
  (cond
    [(string<? a-d b-d) #t]
    [(string>? a-d b-d) #f]
    [else
     (define a-r (~a (second a)))
     (define b-r (~a (second b)))
     (cond
       [(string<? a-r b-r) #t]
       [(string>? a-r b-r) #f]
       [else (< (third a) (third b))])]))

(define (format-multi-depth-variety-row key findings)
  (define domain (first key))
  (define rel    (second key))
  (define d      (third key))
  (define (status-of prop)
    (define f (findf (λ (f) (eq? (sd-finding-property f) prop)) findings))
    (cond
      [(not f) 'absent]
      [(sd-finding-untested-reason f) 'untested]
      [else (evidence-status-public (sd-finding-evidence f))]))
  (define (cell-for status)
    (case status
      [(confirmed) "✓"]
      [(refuted)   "✗"]
      [(untested)  "—"]
      [(absent)    "—"]
      [else        "?"]))
  (define sd-status
    (cond
      [(and (eq? (status-of 'sd-vee) 'confirmed)
            (eq? (status-of 'sd-wedge) 'confirmed)) 'confirmed]
      [(or (eq? (status-of 'sd-vee) 'refuted)
           (eq? (status-of 'sd-wedge) 'refuted)) 'refuted]
      [else 'untested]))
  (define mod-status     (status-of 'modular))
  (define dist-status    (status-of 'distributive))
  (define pc-rel-status  (status-of 'has-pseudo-complement-rel))
  (define stone-status   (status-of 'stone-identity))
  (define heyting-status
    (cond
      [(and (eq? dist-status 'confirmed) (eq? pc-rel-status 'confirmed)) 'confirmed]
      [(or (eq? dist-status 'refuted) (eq? pc-rel-status 'refuted)) 'refuted]
      [else 'untested]))
  (define stone-algebra-status
    (cond
      [(and (eq? heyting-status 'confirmed) (eq? stone-status 'confirmed)) 'confirmed]
      [(or (eq? heyting-status 'refuted) (eq? stone-status 'refuted)) 'refuted]
      [else 'untested]))
  ;; Phase 11: has-complement now empirically swept; Boolean derives
  (define has-complement-status (status-of 'has-complement))
  (define boolean-status
    (cond
      [(and (eq? heyting-status 'confirmed) (eq? has-complement-status 'confirmed)) 'confirmed]
      [(or (eq? heyting-status 'refuted) (eq? has-complement-status 'refuted)) 'refuted]
      [else 'untested]))
  (define w-status (status-of 'whitmans-condition))
  (define untested-reasons
    (remove-duplicates
     (filter values
             (for/list ([f (in-list findings)])
               (sd-finding-untested-reason f)))))
  (define notes
    (cond
      [(null? untested-reasons) "—"]
      [else (string-join (map ~a untested-reasons) ", ")]))
  (format "| ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a |"
          domain rel (depth-tag d)
          (cell-for sd-status)
          (cell-for mod-status)
          (cell-for dist-status)
          (cell-for heyting-status)
          (cell-for stone-algebra-status)
          (cell-for boolean-status)
          (cell-for w-status)
          notes))

;; Public re-export of evidence-status logic (needed because the local one in
;; sre-property-sweep.rkt isn't exported). Mirror the same dispatch.
(define (evidence-status-public ev)
  (cond
    [(sd-evidence? ev) (sd-evidence-status ev)]
    [(pc-rel-evidence? ev) (pc-rel-evidence-status ev)]
    [(modular-evidence? ev) (modular-evidence-status ev)]
    [(whitman-evidence? ev) (whitman-evidence-status ev)]
    [(axiom-confirmed? ev) 'confirmed]
    [(axiom-refuted? ev)   'refuted]
    [(eq? ev axiom-untested) 'untested]
    [else 'unknown]))

;; ============================================================================
;; Per-finding detail table with footnoted witnesses
;; ============================================================================

(define (format-multi-depth-detail-table tagged-findings)
  ;; Collect witnesses; assign W1, W2, ... footnotes
  (define witnesses '())
  (define (witness-key wit) (~v wit))
  (define witness-table (make-hash))
  (define (register-witness! wit)
    (cond
      [(not wit) #f]
      [(hash-ref witness-table (witness-key wit) #f)
       => values]
      [else
       (set! witnesses (cons wit witnesses))
       (define n (length witnesses))
       (define label (format "W~a" n))
       (hash-set! witness-table (witness-key wit) label)
       label]))
  (define header
    "| Domain | Relation | Depth | Property | Samples | Status | Triples | Hypothesis fired | Conclusion held | Non-vacuity % | Witness |")
  (define separator
    "|---|---|---|---|---|---|---|---|---|---|---|")
  (define rows
    (for/list ([tf (in-list tagged-findings)])
      (define f (first tf))
      (define d (second tf))
      (format-multi-depth-detail-row f d register-witness!)))
  (define table (string-join (cons header (cons separator rows)) "\n"))
  ;; Append footnotes at end
  (define footnotes
    (for/list ([w (in-list (reverse witnesses))]
               [i (in-naturals 1)])
      (format "**W~a**: `~v`" i w)))
  (cond
    [(null? footnotes) table]
    [else (string-append table "\n\n### Witness footnotes\n\n"
                         (string-join footnotes "\n\n"))]))

(define (format-multi-depth-detail-row f d register-witness!)
  (define domain  (~a (sd-finding-domain-name f)))
  (define rel     (~a (sd-finding-relation f)))
  (define prop    (~a (sd-finding-property f)))
  (define samples (~a (sd-finding-sample-count f)))
  (define ev      (sd-finding-evidence f))
  (define ur      (sd-finding-untested-reason f))
  (define-values (status triples hyp-fired conc-held non-vac witness)
    (cond
      [(detailed-evidence-fields ev)
       => (λ (fields)
            (define st    (first fields))
            (define total (second fields))
            (define fired (third fields))
            (define held  (fourth fields))
            (define wit   (fifth fields))
            (values (~a st)
                    (~a total)
                    (~a fired)
                    (~a held)
                    (non-vacuity-pct fired total)
                    (witness->footref wit register-witness!)))]
      [(axiom-confirmed? ev)
       (define total (axiom-confirmed-count ev))
       (values "confirmed" (~a total) (~a total) (~a total) "100.0%" "—")]
      [(axiom-refuted? ev)
       (values "refuted" "—" "—" "—" "—"
               (witness->footref (axiom-refuted-witness ev) register-witness!))]
      [(eq? ev axiom-untested)
       (values (if ur (format "untested (~a)" ur) "untested")
               "—" "—" "—" "—" "—")]
      [else
       (values "unknown" "—" "—" "—" "—" "—")]))
  (format "| ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a | ~a |"
          domain rel (depth-tag d) prop samples
          status triples hyp-fired conc-held non-vac witness))

;; Mirror the extract-detailed-fields logic from sre-property-sweep.rkt.
(define (detailed-evidence-fields ev)
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

(define (non-vacuity-pct fired total)
  (cond
    [(zero? total) "n/a"]
    [else (format "~a%"
                  (~r (* 100.0 (/ fired total))
                      #:precision '(= 1)))]))

(define (witness->footref wit register-witness!)
  (cond
    [(not wit) "—"]
    [else
     (define label (register-witness! wit))
     (format "(~a)" label)]))

;; ============================================================================
;; Main
;; ============================================================================

(define (main)
  (define cli-domain-filter   (make-parameter #f))
  (define cli-depths          (make-parameter '(0 1)))
  (define cli-relation-filter (make-parameter #f))
  (define cli-properties      (make-parameter #f))
  (command-line
   #:program "run-phase9-sweep"
   #:once-each
   [("--domain") d "Restrict sweep to one domain (type | session | form-cell | spec-cell)"
                 (cli-domain-filter (string->symbol d))]
   [("--depth") n "Restrict to a single depth (0 or 1)"
                (cli-depths (list (string->number n)))]
   [("--relation") r "Restrict sweep to one relation within the domain (equality | subtype | ...)"
                   (cli-relation-filter (string->symbol r))]
   [("--properties") p "Comma-separated list of property symbols to sweep (default: all)"
                     (cli-properties
                      (map string->symbol (string-split p ",")))]
   #:args ()
   (void))
  (eprintf ";; SRE Track 2I Phase 9b — Comprehensive lattice variety sweep\n")
  (eprintf ";; Generated via: racket tools/run-phase9-sweep.rkt~a~a\n"
           (if (cli-domain-filter) (format " --domain ~a" (cli-domain-filter)) "")
           (cond
             [(equal? (cli-depths) '(0)) " --depth 0"]
             [(equal? (cli-depths) '(1)) " --depth 1"]
             [else ""]))
  (eprintf ";; Sweeps ~a × ~a depths × 11 properties\n"
           (cond
             [(cli-domain-filter) (cli-domain-filter)]
             [else "4 domains"])
           (length (cli-depths)))
  (eprintf ";;\n")
  (define start-ms (current-inexact-milliseconds))
  (define tagged-findings
    (time (run-comprehensive-sweep (cli-domain-filter)
                                   (cli-depths)
                                   (cli-relation-filter)
                                   (cli-properties))))
  (define total-elapsed (- (current-inexact-milliseconds) start-ms))
  (eprintf ";; Sweep total: ~as wall time. ~a tagged findings.\n"
           (~r (/ total-elapsed 1000.0) #:precision '(= 1))
           (length tagged-findings))
  (eprintf "\n")

  ;; Markdown output to stdout
  (displayln "## Phase 9 Findings — Comprehensive Lattice Variety Sweep")
  (newline)
  (displayln "**Generated**: by `tools/run-phase9-sweep.rkt`")
  (displayln "**Sweep params**: per-ctor-count 2, depth ∈ {0 (ground), 1 (wider)}")
  (displayln "**Domains × relations swept**:")
  (for ([cfg (in-list sweep-config)])
    (displayln (format "- `~a × ~a`" (first cfg) (second cfg))))
  (newline)

  (displayln "### Variety-placement summary")
  (newline)
  (displayln "Each row places a `(domain × relation × depth)` lattice into the PTF lattice hierarchy. ✓ = property holds empirically; ✗ = refuted with witness; — = untested (no relation in registry, or property not testable on these samples). `(W)` = Whitman's W (free-lattice membership criterion, Nation 1982 Theorem 5.55/6.9).")
  (newline)
  (displayln (format-multi-depth-variety-summary tagged-findings))
  (newline)

  (displayln "### Per-finding detail")
  (newline)
  (displayln "Witnesses are footnoted (W1, W2, ...) below the table. Non-vacuity % surfaces evidence-strength asymmetries (e.g., SD-vee 3.5% vs SD-wedge 91.4% on type×equality wider — most SD-vee triples don't fire the hypothesis non-trivially).")
  (newline)
  (displayln (format-multi-depth-detail-table tagged-findings))
  (newline))

(main)
