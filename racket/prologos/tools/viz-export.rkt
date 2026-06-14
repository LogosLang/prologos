#lang racket/base

;;;
;;; viz-export.rkt — PTF Track 2 Phase 2c: headless trace exporter
;;;
;;; Runs a .prologos file with the trace observer + observatory armed and
;;; writes ONE self-contained JSON envelope (vizTrace 1) for the standalone
;;; browser viewer: per-command captures with topology, epoch-bucketed BSP
;;; rounds (timestamped by the observer wrapper), per-epoch last-snapshot
;;; topologies (the solver free-path — design doc §7.7 A4), an identity
;;; section per topology (D4: best-available with measured coverage), and
;;; bounded semantic value detail (D7).
;;;
;;; Design: docs/tracking/2026-06-12_PTF_TRACK2_BROWSER_VIZ_DESIGN.md §7.
;;; Schema posture (D2 PATH B): trace-serialize.rkt is reused VERBATIM;
;;; everything viz-specific lives in this envelope, not the core schema.
;;; Identity is PER-TOPOLOGY (not global): cell-id spaces are per-network
;;; (each prop-network counts from 0), so a global map would conflate the
;;; elab net with solver nets (implementation note for D1).
;;;
;;; Usage:
;;;   racket tools/viz-export.rkt FILE.prologos -o out.json
;;;          [--max-diffs N] [--max-rounds N] [--validate]
;;;

(require json
         racket/list
         racket/string
         racket/file
         "../champ.rkt"
         "../driver.rkt"
         "../errors.rkt"
         "../propagator.rkt"
         "../prop-observatory.rkt"
         "../elaborator-network.rkt"
         (only-in "../eclass-graph.rkt" current-eclass-containment-box
                  current-eclass-hashcons-cell-id init-eclass-hashcons-cell!)
         (only-in "../reduction.rkt" whnf-via-egraph-network)
         (only-in "../rule-registry.rkt"
                  current-rule-registry-cell-id init-rule-registry-cell!)
         (only-in "../kernel-rules-seed.rkt" register-arithmetic-seed!)
         (only-in "../metavar-store.rkt" current-persistent-registry-net-box)
         "../trace-serialize.rkt")

(provide viz-export-file viz-export-expr-network)

;; Well-known infrastructure cells (propagator.rkt:500-800, 2323). Identity is
;; exporter-local per D2 PATH B; this table mirrors the named constants — when
;; a new well-known cell is added there, extend here (cheap; viz-only).
(define well-known-cells
  (hasheq 0 "decomp-request" 1 "worldview-cache" 2 "relation-store"
          3 "config" 4 "naf-pending" 5 "pool-config"
          6 "constraint-propagators-topology" 7 "elaborator-topology"
          8 "narrowing-topology" 9 "sre-topology" 10 "classify-inhabit-request"
          11 "fuel" 12 "fuel-budget" 13 "retraction-stratum-request"
          14 "resolution-stratum-request" 15 "fork-on-union-request"
          16 "fork-contradiction-request" 17 "decomposed-positions"
          18 "contradicted-branch-aids" 19 "union-derivation-chains"
          20 "congruence-sig-index" 21 "congruence-request"
          22 "dispatch-request" 23 "reduce-request"))

(define (num-key n) (string->symbol (number->string n)))

;; D4 identity stack for one network: domains champ + well-known + srclocs,
;; with measured coverage stats (the lock's "best-available with MEASURED
;; coverage" — never claim more than the data shows).
(define (identity-for-network pnet)
  (define cells-champ (prop-network-cells pnet))
  (define cell-ids (champ-keys cells-champ))
  (define domains-champ (prop-network-cell-domains pnet))
  (define domain-cids (champ-keys domains-champ))
  (define cell-domains
    (for/hasheq ([cid (in-list domain-cids)])
      (values (num-key (cell-id-n cid))
              (format "~a" (champ-lookup domains-champ (cell-id-n cid) cid)))))
  (define wkc
    (for/hasheq ([cid (in-list cell-ids)]
                 #:when (hash-has-key? well-known-cells (cell-id-n cid)))
      (values (num-key (cell-id-n cid))
              (hash-ref well-known-cells (cell-id-n cid)))))
  (define props-champ (prop-network-propagators pnet))
  (define prop-srclocs
    (for/hasheq ([pid (in-list (champ-keys props-champ))]
                 #:when (let ([p (champ-lookup props-champ (prop-id-hash pid) pid)])
                          (and (not (eq? p 'none)) (propagator-srcloc p))))
      (values (num-key (prop-id-n pid))
              (format "~a" (propagator-srcloc
                            (champ-lookup props-champ (prop-id-hash pid) pid))))))
  (define total (length cell-ids))
  (hasheq 'cellDomains cell-domains
          'wellKnownCells wkc
          'propagatorSrclocs prop-srclocs
          'coverage (hasheq 'cellsWithDomain (length domain-cids)
                            'cellsWellKnown (hash-count wkc)
                            'totalCells total)))

;; Cheap topology signature (incremental observer, Phase 4a perf): cell-ids +
;; propagator connections ONLY — skips the per-cell `serialize-lattice-value`
;; that DOMINATES `serialize-network-topology` (e-class values carry
;; :best/:alts/:canonical/:provenance sets). Produces the SAME dedup key the full
;; serialize would, so the full serialize runs ONLY on a NEW topology — not once
;; per round. Under monotone network growth most rounds share a topology, so this
;; turns the per-round cost from O(net + every cell's value) into O(cells+props
;; ids). Matches the legacy sig format exactly (cell `id`s sorted | `pid:in>out`
;; sorted).
(define (topology-signature pnet)
  (define cells-champ (prop-network-cells pnet))
  (define props-champ (prop-network-propagators pnet))
  (string-append
   (string-join (sort (map (lambda (cid) (number->string (cell-id-n cid)))
                           (champ-keys cells-champ)) string<?) ",")
   "|"
   (string-join
    (sort (map (lambda (pid)
                 (define prop (champ-lookup props-champ (prop-id-hash pid) pid))
                 (format "~a:~a>~a" (prop-id-n pid)
                         (map cell-id-n (propagator-inputs prop))
                         (map cell-id-n (propagator-outputs prop))))
               (champ-keys props-champ))
          string<?)
    ";")))

;; D7: bounded one-level semantic detail for hash-valued cells (the "hash(N
;; entries)" opacity fix — keys only, capped; depth growth is a Phase 4 rider).
(define VALUE-DETAIL-MAX-KEYS 8)
(define (value-detail-for-network pnet)
  (define cells-champ (prop-network-cells pnet))
  (for/hasheq ([cid (in-list (champ-keys cells-champ))]
               #:when (hash? (prop-cell-value
                              (champ-lookup cells-champ (cell-id-n cid) cid))))
    (define v (prop-cell-value (champ-lookup cells-champ (cell-id-n cid) cid)))
    (define ks (hash-keys v))
    (values (num-key (cell-id-n cid))
            (hasheq 'entryCount (hash-count v)
                    'keys (for/list ([k (in-list (take ks (min (length ks)
                                                               VALUE-DETAIL-MAX-KEYS)))])
                            (format "~a" k))
                    'truncated (> (hash-count v) VALUE-DETAIL-MAX-KEYS)))))

(define (topology-section pnet [cell-info #f])
  (hasheq 'topology (serialize-network-topology pnet cell-info)
          'identity (identity-for-network pnet)
          'valueDetail (value-detail-for-network pnet)))

;; Epoch bucketing: capture timestamps partition the round timeline. Round r
;; belongs to the first capture whose timestamp >= r's; trailing rounds (file
;; close: residuation fixpoint etc.) get a final "file-close" epoch.
(define (epoch-index-for ts capture-ts-list)
  (let loop ([k 0] [cs capture-ts-list])
    (cond [(null? cs) k]
          [(<= ts (car cs)) k]
          [else (loop (add1 k) (cdr cs))])))

;; Source lines keyed by line-number string → trimmed text. Lets the viewer
;; label propagators by the SOURCE CONSTRUCT that installed them (fire-fns are
;; anonymous closures; srcloc is the meaningful identity). Best-effort: a
;; missing/unreadable file yields an empty map.
(define (read-source-lines path)
  (with-handlers ([exn:fail? (lambda (_) (hasheq))])
    (define lines (file->lines path))
    (for/hasheq ([ln (in-list lines)] [i (in-naturals 1)]
                 #:when (positive? (string-length (string-trim ln))))
      (define t (string-trim ln))
      (values (string->symbol (number->string i))
              (if (> (string-length t) 120) (substring t 0 120) t)))))

;; --- the trace harness, factored so both the file driver (process-file) and the
;; --- Phase 5b network driver (whnf-via-egraph-network) share the SAME envelope.
;; run-thunk : (-> (listof result)) — runs under the armed observer + e-graph
;; capture; its run-to-quiescence rounds are what the envelope renders.
(define (run-with-viz-trace run-thunk src-label source-lines max-diffs max-rounds)
  (define-values (bsp-observe bsp-get-rounds) (make-trace-accumulator))
  (define round-times (box '()))   ;; reversed; one ts per observed round
  (define (timed-observer r)
    (set-box! round-times (cons (current-inexact-milliseconds)
                                (unbox round-times)))
    (bsp-observe r))
  (define obs (make-observatory (hasheq 'file (format "~a" src-label))))
  (define cap-box (box #f))
  ;; containment capture (reduction DAG): parent-alloc → (listof child-alloc).
  (define containment-box (box (make-hash)))
  (define t0 (current-inexact-milliseconds))
  (define results
    (parameterize ([current-bsp-observer timed-observer]
                   [current-observatory obs]
                   [current-network-capture-box cap-box]
                   [current-eclass-containment-box containment-box])
      (run-thunk)))
  (define t1 (current-inexact-milliseconds))
  (build-viz-envelope src-label source-lines results
                      bsp-get-rounds round-times obs cap-box containment-box
                      t0 t1 max-diffs max-rounds))

;; viz-export-file : path → envelope jsexpr. Reduction is ON-NETWORK (β/δ/ι/int-folds
;; route through the e-graph: redex⇒result rewrites become union propagators).
(define (viz-export-file src-path
                         #:max-diffs [max-diffs 50000]
                         #:max-rounds [max-rounds 5000])
  (run-with-viz-trace (lambda () (process-file src-path))
                      (format "~a" src-path) (read-source-lines src-path)
                      max-diffs max-rounds))

;; viz-export-expr-network : expr → envelope jsexpr. Phase 5b — drive reduction of a
;; (constructed, ground) expr through whnf-via-egraph-network: the SCHEDULER-DRIVEN
;; reduce-stratum cascade. The trace then SHOWS the network DRIVING reduction (the
;; reduce-request cell, the emitter, the per-step union cascade), not just recording
;; it. Sets up the e-graph plumbing (registry + arithmetic seed + hashcons) here.
(define (viz-export-expr-network e
                                 #:label [label "whnf-via-egraph-network"]
                                 #:source-lines [source-lines (hash)]
                                 #:max-diffs [max-diffs 50000]
                                 #:max-rounds [max-rounds 5000])
  (run-with-viz-trace
   (lambda ()
     (parameterize ([current-rule-registry-cell-id #f]
                    [current-eclass-hashcons-cell-id #f]
                    [current-persistent-registry-net-box (box (make-prop-network))])
       (define pb (current-persistent-registry-net-box))
       (init-rule-registry-cell! pb)
       (set-box! pb (run-to-quiescence
                     (register-arithmetic-seed! (unbox pb) (current-rule-registry-cell-id))))
       (init-eclass-hashcons-cell! pb)
       (list (whnf-via-egraph-network e))))
   label source-lines max-diffs max-rounds))

;; the shared envelope builder (vizTrace 2): per-round deduped topology + identity +
;; containment, from the observer's captured rounds.
(define (build-viz-envelope src-label source-lines results
                            bsp-get-rounds round-times obs cap-box containment-box
                            t0 t1 max-diffs max-rounds)
  (define containment   ;; cid → (listof child-cid), deduped
    (for/hash ([(k v) (in-hash (unbox containment-box))])
      (values k (remove-duplicates v))))
  (define rounds (bsp-get-rounds))
  (define times (reverse (unbox round-times)))
  (define captures (sort (observatory-captures obs) <
                         #:key net-capture-sequence-number))
  (define capture-ts (map net-capture-timestamp-ms captures))

  ;; Validation block (the locked 2c criteria) — always computed, never silent.
  (define monotone?
    (or (null? times)
        (for/and ([a (in-list times)] [b (in-list (cdr times))]) (<= a b))))
  (define n-cmds (length results))
  (define n-caps (length captures))
  (define round-epochs (for/list ([ts (in-list times)])
                         (epoch-index-for ts capture-ts)))
  (define validation
    (hasheq 'roundTimestampsMonotone monotone?
            'commandCount n-cmds
            'captureCount n-caps
            'capturesMatchCommands (= n-cmds n-caps)
            'roundsTotal (length rounds)
            'roundsBucketed (length round-epochs)))

  ;; --- vizTrace 2: per-ROUND topology. Each round is rendered against its
  ;; OWN network snapshot, fixing the per-epoch id-space mismatch (a round's
  ;; fired props / cell diffs reference cells in the id-space of the network
  ;; THAT ROUND ran on — elaboration vs a solve-fork — which an epoch's
  ;; last-round snapshot need not match). Topologies are globally deduped by
  ;; signature; each round carries an index into the table.
  (define (friendly s) (regexp-replace #rx"^elab:" s ""))
  (define capped-rounds (if (> (length rounds) max-rounds) (take rounds max-rounds) rounds))
  (define capped-times  (if (> (length times)  max-rounds) (take times  max-rounds) times))
  (define capped-epochs (if (> (length round-epochs) max-rounds) (take round-epochs max-rounds) round-epochs))
  (define topo-table (make-hash))   ;; signature → index
  (define topo-rev '())             ;; reversed topology sections
  (define topo-count 0)
  (define (intern-topology! pnet)
    ;; Cheap sig per round (no value serialization); full serialize ONLY on a NEW
    ;; topology (the incremental-observer win — most rounds reuse a topology).
    (define sig (topology-signature pnet))
    (or (hash-ref topo-table sig #f)
        (let ([idx topo-count]
              [topo (serialize-network-topology pnet)])
          (hash-set! topo-table sig idx)
          (set! topo-count (add1 topo-count))
          ;; containment edges present in THIS topology (both ends are cells here)
          (define present
            (for/hasheq ([c (in-list (hash-ref topo 'cells))]) (values (hash-ref c 'id) #t)))
          (define cont-edges
            (for*/list ([(parent kids) (in-hash containment)]
                        #:when (hash-ref present parent #f)
                        [kid (in-list kids)]
                        #:when (hash-ref present kid #f))
              (hasheq 'from parent 'to kid)))
          (set! topo-rev (cons (hasheq 'topology topo
                                       'identity (identity-for-network pnet)
                                       'containment cont-edges) topo-rev))
          idx)))
  (define total-diffs (for/sum ([r (in-list rounds)]) (length (bsp-round-cell-diffs r))))
  (define diffs-capped? (> total-diffs max-diffs))
  (define (round-label e)
    (friendly (cond [(< e n-caps) (format "~a" (net-capture-label (list-ref captures e)))]
                    [else "file-close"])))
  (define rounds-json
    (for/list ([r (in-list capped-rounds)] [ts (in-list capped-times)] [e (in-list capped-epochs)])
      (hasheq 'roundNumber (bsp-round-round-number r)
              'timestampMs ts
              'command (round-label e)
              'topo (intern-topology! (bsp-round-network-snapshot r))
              'propagatorsFired (map prop-id-n (bsp-round-propagators-fired r))
              'cellDiffs (if diffs-capped? '()
                             (map serialize-cell-diff (bsp-round-cell-diffs r))))))
  (define topologies-json (reverse topo-rev))
  ;; Ordered distinct commands (label + first round) for the timeline readout.
  (define commands-json
    (let loop ([rs rounds-json] [seen (hash)] [acc '()] [seq 0])
      (cond [(null? rs) (reverse acc)]
            [(hash-has-key? seen (hash-ref (car rs) 'command)) (loop (cdr rs) seen acc seq)]
            [else (loop (cdr rs) (hash-set seen (hash-ref (car rs) 'command) #t)
                        (cons (hasheq 'seq seq 'label (hash-ref (car rs) 'command)
                                      'firstRound (hash-ref (car rs) 'roundNumber)) acc)
                        (add1 seq))])))

  (define enet (unbox cap-box))
  (hasheq 'vizTrace 2
          'file src-label
          'source (hasheq 'path src-label
                          'lines source-lines)
          'wallMs (- t1 t0)
          'commandCount n-cmds
          'errors (length (filter prologos-error? results))
          'errorMessages (for/list ([r (in-list results)]
                                    #:when (prologos-error? r))
                           (prologos-error-message r))
          'commands commands-json
          'topologies topologies-json
          'rounds rounds-json
          'finalTopology
          (if enet
              (hash-set (topology-section (elab-network-prop-net enet)
                                          (elab-network-cell-info enet))
                        'present #t)
              (hasheq 'present #f))
          'roundsTruncated (or (> (length rounds) max-rounds) diffs-capped?)
          'validation (hash-set validation 'topologyCount topo-count)))

(module+ main
  (define args (vector->list (current-command-line-arguments)))
  (define (flag-val flag lst) (let loop ([l lst])
                                (cond [(or (null? l) (null? (cdr l))) #f]
                                      [(equal? (car l) flag) (cadr l)]
                                      [else (loop (cdr l))])))
  (define src (findf (lambda (a) (not (string-prefix? a "-"))) args))
  (define out (flag-val "-o" args))
  (define validate? (member "--validate" args))
  (unless src
    (eprintf "usage: racket tools/viz-export.rkt FILE.prologos -o out.json [--max-diffs N] [--max-rounds N] [--validate]\n")
    (eprintf "  reduction is on-network (propagator-native) on this branch — always.\n")
    (exit 1))
  (define envelope
    (viz-export-file src
                     #:max-diffs (cond [(flag-val "--max-diffs" args) => string->number]
                                       [else 50000])
                     #:max-rounds (cond [(flag-val "--max-rounds" args) => string->number]
                                        [else 5000])))
  (when out
    (call-with-output-file out
      (lambda (port) (write-json envelope port))
      #:exists 'replace)
    (printf "wrote ~a (~a bytes)\n" out (file-size out)))
  (define v (hash-ref envelope 'validation))
  (define rs (hash-ref envelope 'rounds))
  (define fired (map (lambda (r) (length (hash-ref r 'propagatorsFired))) rs))
  (define max-fired (if (null? fired) 0 (apply max fired)))
  (printf "vizTrace2  errors ~a  rounds ~a  topologies ~a  monotone ~a  captures==commands ~a\n"
          (hash-ref envelope 'errors) (length rs)
          (hash-ref v 'topologyCount)
          (hash-ref v 'roundTimestampsMonotone)
          (hash-ref v 'capturesMatchCommands))
  (printf "concurrency: max propagators fired in one round = ~a (rounds with >1: ~a)\n"
          max-fired (length (filter (lambda (n) (> n 1)) fired)))
  (when (and validate?
             (not (and (hash-ref v 'roundTimestampsMonotone)
                       (hash-ref v 'capturesMatchCommands)
                       (zero? (hash-ref envelope 'errors)))))
    (eprintf "VALIDATION FAILED: ~a\n" v)
    (exit 2)))
