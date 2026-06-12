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
         "../champ.rkt"
         "../driver.rkt"
         "../errors.rkt"
         "../propagator.rkt"
         "../prop-observatory.rkt"
         "../elaborator-network.rkt"
         "../trace-serialize.rkt")

(provide viz-export-file)

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
          20 "congruence-sig-index" 21 "congruence-request"))

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

;; viz-export-file : path (-> hasheq) — runs FILE, returns the envelope jsexpr.
(define (viz-export-file src-path
                         #:max-diffs [max-diffs 50000]
                         #:max-rounds [max-rounds 5000])
  (define-values (bsp-observe bsp-get-rounds) (make-trace-accumulator))
  (define round-times (box '()))   ;; reversed; one ts per observed round
  (define (timed-observer r)
    (set-box! round-times (cons (current-inexact-milliseconds)
                                (unbox round-times)))
    (bsp-observe r))
  (define obs (make-observatory (hasheq 'file (format "~a" src-path))))
  (define cap-box (box #f))
  (define t0 (current-inexact-milliseconds))
  (define results
    (parameterize ([current-bsp-observer timed-observer]
                   [current-observatory obs]
                   [current-network-capture-box cap-box])
      (process-file src-path)))
  (define t1 (current-inexact-milliseconds))

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

  ;; Per-epoch last-snapshot topology — the A4 solver free path: whichever
  ;; network ran that epoch's last observed round is what gets serialized.
  (define last-round-per-epoch
    (for/fold ([h (hash)]) ([r (in-list rounds)] [e (in-list round-epochs)])
      (hash-set h e r)))   ;; later rounds overwrite: keeps the LAST per epoch
  (define epochs-json
    (for/list ([(e r) (in-hash last-round-per-epoch)])
      (define label
        (cond [(< e n-caps) (net-capture-label (list-ref captures e))]
              [else "file-close"]))
      (hash-set* (topology-section (bsp-round-network-snapshot r))
                 'epoch e
                 'label (format "~a" label)
                 'roundsInEpoch (for/sum ([e2 (in-list round-epochs)])
                                  (if (= e e2) 1 0)))))

  ;; Rounds (truncate honestly past the caps; diffs cap measured globally).
  (define total-diffs (for/sum ([r (in-list rounds)])
                        (length (bsp-round-cell-diffs r))))
  (define rounds-truncated? (or (> (length rounds) max-rounds)
                                (> total-diffs max-diffs)))
  (define rounds-json
    (for/list ([r (in-list (if (> (length rounds) max-rounds)
                               (take rounds max-rounds)
                               rounds))]
               [ts (in-list times)]
               [e (in-list round-epochs)])
      (define base (if (> total-diffs max-diffs)
                       (hasheq 'roundNumber (bsp-round-round-number r)
                               'diffCount (length (bsp-round-cell-diffs r))
                               'propagatorsFired
                               (map prop-id-n (bsp-round-propagators-fired r)))
                       (serialize-bsp-round r)))
      (hash-set* base 'timestampMs ts 'epoch e)))

  (define captures-json
    (for/list ([c (in-list captures)])
      (hash-set* (topology-section (net-capture-network c))
                 'label (format "~a" (net-capture-label c))
                 'subsystem (format "~a" (net-capture-subsystem c))
                 'status (format "~a" (net-capture-status c))
                 'timestampMs (net-capture-timestamp-ms c)
                 'sequence (net-capture-sequence-number c))))

  (define enet (unbox cap-box))
  (hasheq 'vizTrace 1
          'file (format "~a" src-path)
          'wallMs (- t1 t0)
          'commands n-cmds
          'errors (length (filter prologos-error? results))
          'errorMessages (for/list ([r (in-list results)]
                                    #:when (prologos-error? r))
                           (prologos-error-message r))
          'captures captures-json
          'finalTopology
          (if enet
              (hash-set (topology-section (elab-network-prop-net enet)
                                          (elab-network-cell-info enet))
                        'present #t)
              (hasheq 'present #f))
          'epochs epochs-json
          'rounds rounds-json
          'roundsTruncated rounds-truncated?
          'validation validation))

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
  (printf "commands ~a  errors ~a  captures ~a  rounds ~a  monotone ~a  captures==commands ~a\n"
          (hash-ref envelope 'commands) (hash-ref envelope 'errors)
          (hash-ref v 'captureCount) (hash-ref v 'roundsTotal)
          (hash-ref v 'roundTimestampsMonotone)
          (hash-ref v 'capturesMatchCommands))
  (printf "epochs: ~a\n"
          (for/list ([e (in-list (hash-ref envelope 'epochs))])
            (list (hash-ref e 'epoch)
                  (hash-ref e 'label)
                  (hash-ref (hash-ref (hash-ref e 'topology) 'stats) 'totalCells)
                  (hash-ref (hash-ref (hash-ref e 'topology) 'stats) 'totalPropagators))))
  (when (and validate?
             (not (and (hash-ref v 'roundTimestampsMonotone)
                       (hash-ref v 'capturesMatchCommands)
                       (zero? (hash-ref envelope 'errors)))))
    (eprintf "VALIDATION FAILED: ~a\n" v)
    (exit 2)))
