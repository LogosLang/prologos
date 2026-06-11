#lang racket/base
;;; rule-registry.rkt — PReduce SM3: the unified rule registry universe cell (15a).
;;;
;;; D.1 §3 lock (owner D1/D2/D4-D7), realized as the BRIDGE substrate before
;;; Track 2 (autonomy ledger iter 15):
;;;
;;;   - CELL-FIRST: one compound universe cell — components keyed by MODULE-ID,
;;;     each holding that module's rules (hash rule-id → preduce-rule). The
;;;     parameter+cell-mirror shape is OFF the table (D4).
;;;   - MERGE = per-namespace DEDUP-OR-ERROR join (D5): re-registering an
;;;     equal? rule is idempotent; a CONFLICTING rule under the same rule-id
;;;     ERRORS (today's sre-rewrite list-append is verifiably not ACI — this is
;;;     the fix-by-construction). Append-only per namespace.
;;;   - TAG-INDEX: a ':tag-index component MAINTAINED BY A PROPAGATOR that
;;;     watches the module components and derives tag → (set rule-id) from the
;;;     rules' interface-keys (information flow, not registrar dual-write).
;;;   - SCHEMA (SP1): the sre-rewrite-rule spine EXTENDED — enrichment-tag,
;;;     write-target, nac-spec (semantic NACs = extraction-time presence; the
;;;     termination-guard kind DISSOLVED into ACI absorption), tier
;;;     (declarative | closure-resident), module-qualified rule-id, RESERVED
;;;     worldview-bitmask slot, stratum as a separate pipeline-stage field.
;;;   - Two-tier (D2): tier-2 closure-resident rules register as property-tagged
;;;     metadata + named Racket references; NEVER serialized.
;;;
;;; NOT in 15a (named, queued): the prn-init seed pour (kernel/prelude
;;; pseudo-module projection of ctor-registry + sre-rewrite-registry — 15b);
;;; driver init wiring (15b); the typing-domain/consumer-read migration (its own
;;; named track — consumers keep reading legacy hasheqs until then); the
;;; broadcast dispatch realization (Track 2, where rules first FIRE).
(require racket/set
         "sre-core.rkt"
         "merge-fn-registry.rkt"
         "propagator.rkt")

(provide (struct-out preduce-rule)
         make-preduce-rule
         rule-registry-merge
         make-rule-registry-cell
         register-rule
         rule-lookup
         rules-for-tag
         rule-registry-sre-domain)

;; --- SP1 schema ---
(struct preduce-rule
  (name              ; symbol — human name
   lhs-pattern       ; pattern datum (tier-1) or #f (tier-2)
   interface-keys    ; list of tag symbols — the dispatch tags (head ops etc.)
   rhs-template      ; template datum (tier-1) or #f (tier-2 closure-resident)
   apply-fn          ; procedure or #f — tier-2 named Racket reference
   directionality    ; 'forward | 'bidirectional
   cost              ; cost annotation (Q-shaped; #f = unknown)
   confluence-class  ; symbol — D.2 taxonomy kind
   enrichment-tag    ; 'enrichment-preserving | 'not-enrichment-preserving
   write-target      ; 'best-only | 'best+alts (SM2 datum)
   nac-spec          ; #f | semantic-NAC datum (extraction-time presence — D1)
   tier              ; 'declarative | 'closure-resident
   rule-id           ; symbol — MODULE-QUALIFIED unique id
   worldview-bitmask ; RESERVED (schema frozen WITH the slot — D.1 §3.1); #f today
   stratum)          ; pipeline-stage field (kept separate from enrichment-tag)
  #:transparent)

(define (make-preduce-rule #:name name
                           #:rule-id rule-id
                           #:interface-keys interface-keys
                           #:tier tier
                           #:lhs-pattern [lhs-pattern #f]
                           #:rhs-template [rhs-template #f]
                           #:apply-fn [apply-fn #f]
                           #:directionality [directionality 'forward]
                           #:cost [cost #f]
                           #:confluence-class [confluence-class 'unclassified]
                           #:enrichment-tag [enrichment-tag 'enrichment-preserving]
                           #:write-target [write-target 'best+alts]
                           #:nac-spec [nac-spec #f]
                           #:stratum [stratum 's0]
                           #:worldview-bitmask [worldview-bitmask #f])
  (preduce-rule name lhs-pattern interface-keys rhs-template apply-fn
                directionality cost confluence-class enrichment-tag
                write-target nac-spec tier rule-id worldview-bitmask stratum))

;; --- the universe-cell merge: per-namespace dedup-or-error (D5) ---
;; value shape: (hasheq module-id (hash rule-id → preduce-rule)
;;              ':tag-index (hash tag → (set rule-id)))
(define (rule-registry-merge old new)
  (cond
    [(not (hash? old)) new]
    [(not (hash? new)) old]
    [else
     (for/fold ([acc old]) ([(mod-id rules) (in-hash new)])
       (cond
         [(eq? mod-id ':tag-index)
          ;; the derived index component: hash-union-of-set-union (monotone)
          (hash-set acc ':tag-index
                    (for/fold ([idx (hash-ref acc ':tag-index (hash))])
                              ([(tag ids) (in-hash rules)])
                      (hash-update idx tag (lambda (s) (set-union s ids)) (set))))]
         [else
          (define old-rules (hash-ref acc mod-id (hash)))
          (define merged
            (for/fold ([m old-rules]) ([(rid rule) (in-hash rules)])
              (define existing (hash-ref m rid #f))
              (cond
                [(not existing) (hash-set m rid rule)]
                [(equal? existing rule) m]  ;; idempotent re-registration
                [else (error 'rule-registry-merge
                             "DEDUP-OR-ERROR (D.1 §3, D5): conflicting rule under ~a::~a — re-registration must be equal? (append-only per namespace)"
                             mod-id rid)])))
          (hash-set acc mod-id merged)]))]))

(define (registry-bot? v) (and (hash? v) (zero? (hash-count v))))

(define rule-registry-sre-domain
  (make-sre-domain
   #:name 'rule-registry
   #:merge-registry (lambda (r)
                      (case r
                        [(equality) rule-registry-merge]
                        [else (error 'rule-registry-merge
                                     "no merge for relation ~a on 'rule-registry" r)]))
   #:contradicts? (lambda (v) #f)
   #:bot? registry-bot?
   #:bot-value (hasheq)))
(register-domain! rule-registry-sre-domain)
(register-merge-fn!/lattice rule-registry-merge #:for-domain 'rule-registry)

;; --- the cell + the propagator-maintained tag index ---

;; → (values net' registry-cid). Installs the INDEX PROPAGATOR: plain refireable,
;; watches the cell, derives ':tag-index from every module component's rules'
;; interface-keys, writes it back into the SAME cell (monotone self-watch —
;; converges at quiescence; information flow, not registrar dual-write).
(define (make-rule-registry-cell net)
  (define-values (net1 cid) (net-new-cell net (hasheq) rule-registry-merge))
  (define (derive-index net*)
    (define reg (net-cell-read net* cid))
    (define idx
      (for*/fold ([idx (hash)])
                 ([(mod-id rules) (in-hash reg)]
                  #:unless (eq? mod-id ':tag-index)
                  [(rid rule) (in-hash rules)]
                  [tag (in-list (preduce-rule-interface-keys rule))])
        (hash-update idx tag (lambda (s) (set-add s rid)) (set))))
    (if (zero? (hash-count idx))
        net*
        (net-cell-write net* cid (hasheq ':tag-index idx))))
  (define-values (net2 _pid)
    (net-add-propagator net1 (list cid) (list cid) derive-index))
  (values net2 cid))

;; component write: one module's rule, keyed by module-qualified rule-id
(define (register-rule net cid module-id rule)
  (net-cell-write net cid
                  (hasheq module-id (hash (preduce-rule-rule-id rule) rule))))

(define (rule-lookup net cid module-id rule-id)
  (define reg (net-cell-read net cid))
  (and (hash? reg)
       (let ([rules (hash-ref reg module-id #f)])
         (and rules (hash-ref rules rule-id #f)))))

;; the dispatch read: tag → set of rule-ids (from the DERIVED index)
(define (rules-for-tag net cid tag)
  (define reg (net-cell-read net cid))
  (define idx (and (hash? reg) (hash-ref reg ':tag-index #f)))
  (if (and idx (hash-ref idx tag #f))
      (hash-ref idx tag)
      (set)))
