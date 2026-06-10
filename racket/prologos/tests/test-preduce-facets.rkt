#lang racket/base
;; PReduce Track 1 SM1.1 — facet substrate tests (D.1 §4.1; autonomy ledger iter 2).
;; Unit-level: the four reduction facets' lattice laws, the closed-dispatch
;; hardening, the two-site bot-filter, and the arity-2 internal-facet filter.
(require rackunit racket/set
         "../typing-propagators.rkt")

;; ---- new facet lattice laws ----

;; :eclass-link — flat ⊥(#f) < KEY < ⊤('eclass-link-top); idempotent/commutative.
(check-equal? (facet-merge ':eclass-link 'k1 'k1) 'k1)
(check-equal? (facet-merge ':eclass-link 'k1 'k2) 'eclass-link-top)
(check-equal? (facet-merge ':eclass-link 'eclass-link-top 'k1) 'eclass-link-top)
(check-true (facet-bot? ':eclass-link (facet-bot ':eclass-link)))
(check-false (facet-bot? ':eclass-link 'k1))

;; :reduction-status — chain ⊥ ⊑ (reduced . K) ⊑ exhausted; rank-equal conflict → ⊤.
(check-equal? (facet-merge ':reduction-status '(reduced . k1) 'exhausted) 'exhausted)
(check-equal? (facet-merge ':reduction-status 'exhausted '(reduced . k1)) 'exhausted)
(check-equal? (facet-merge ':reduction-status '(reduced . k1) '(reduced . k1)) '(reduced . k1))
(check-equal? (facet-merge ':reduction-status '(reduced . k1) '(reduced . k2)) 'reduction-status-top)
(check-equal? (facet-merge ':reduction-status 'reduction-status-top 'exhausted) 'reduction-status-top)
(check-true (facet-bot? ':reduction-status (facet-bot ':reduction-status)))

;; :cost-in-context — min-join (declared monotone-min at landing, D.1 §4.1).
(check-equal? (facet-merge ':cost-in-context 5 3) 3)
(check-equal? (facet-merge ':cost-in-context 3 5) 3)
(check-equal? (facet-merge ':cost-in-context 3 3) 3)
(check-true (facet-bot? ':cost-in-context (facet-bot ':cost-in-context)))

;; :reduction-provenance — set-union; empty SET is bot ((not v) would misclassify).
(check-equal? (facet-merge ':reduction-provenance (seteq 'a) (seteq 'b)) (seteq 'a 'b))
(check-equal? (facet-merge ':reduction-provenance (seteq 'a 'b) (seteq 'b)) (seteq 'a 'b))
(check-true (facet-bot? ':reduction-provenance (seteq)))
(check-false (facet-bot? ':reduction-provenance (seteq 'a)))
(check-true (set-empty? (facet-bot ':reduction-provenance)))

;; ---- closed-dispatch hardening: unknown facets ERROR in all three ----
(check-exn exn:fail? (lambda () (facet-merge ':mult 'a 'b)))
(check-exn exn:fail? (lambda () (facet-bot ':mult)))
(check-exn exn:fail? (lambda () (facet-bot? ':mult 'a)))

;; ---- bot-filter, site 1: wholesale insert never materializes bots ----
(let* ([delta (hasheq 'pos1 (hasheq ':eclass-link 'k1
                                    ':reduction-provenance (seteq)   ;; bot
                                    ':cost-in-context #f))]          ;; bot
       [merged (attribute-map-merge-fn (hasheq) delta)]
       [rec (hash-ref merged 'pos1)])
  (check-equal? (hash-ref rec ':eclass-link #f) 'k1)
  (check-false (hash-has-key? rec ':reduction-provenance))
  (check-false (hash-has-key? rec ':cost-in-context)))

;; site 1: an ALL-bot record inserts nothing (position absent).
(let ([merged (attribute-map-merge-fn
               (hasheq)
               (hasheq 'pos1 (hasheq ':cost-in-context #f
                                     ':reduction-provenance (seteq))))])
  (check-false (hash-has-key? merged 'pos1)))

;; ---- bot-filter, site 2: bot DELTA is skipped (incl. bot-onto-bot) ----
(let* ([base (attribute-map-merge-fn (hasheq) (hasheq 'p (hasheq ':eclass-link 'k1)))]
       [merged (attribute-map-merge-fn base (hasheq 'p (hasheq ':eclass-link #f)))])
  (check-equal? (hash-ref (hash-ref merged 'p) ':eclass-link) 'k1))
(let* ([base (attribute-map-merge-fn (hasheq) (hasheq 'p (hasheq ':eclass-link 'k1)))]
       ;; bot-onto-bot via a facet the record doesn't hold: must not appear
       [merged (attribute-map-merge-fn base (hasheq 'p (hasheq ':cost-in-context #f)))])
  (check-false (hash-has-key? (hash-ref merged 'p) ':cost-in-context)))

;; ---- pointwise law spot-check (shape-P precondition, D.1 §8.1) ----
;; positions absent from the delta are untouched (eq?-preserved records).
(let* ([base (attribute-map-merge-fn
              (hasheq)
              (hasheq 'p (hasheq ':eclass-link 'k1)
                      'q (hasheq ':eclass-link 'k2)))]
       [merged (attribute-map-merge-fn base (hasheq 'p (hasheq ':cost-in-context 7)))])
  (check-eq? (hash-ref merged 'q) (hash-ref base 'q))
  (check-equal? (hash-ref (hash-ref merged 'p) ':cost-in-context) 7))

;; ---- arity-2 filter: internal reduction facets hidden from the record view ----
(let* ([am (attribute-map-merge-fn
            (hasheq)
            (hasheq 'p (hasheq ':eclass-link 'k1
                               ':cost-in-context 3
                               ':warnings '(w1))))]
       [view (that-read am 'p)])
  (check-false (hash-has-key? view ':eclass-link))
  (check-false (hash-has-key? view ':cost-in-context))
  (check-equal? (hash-ref view ':warnings) '(w1))
  ;; arity-3 by-name reads stay RAW for internal callers:
  (check-equal? (that-read am 'p ':eclass-link) 'k1)
  (check-equal? (that-read am 'p ':cost-in-context) 3)
  ;; absent internal facet reads as its bot:
  (check-true (facet-bot? ':reduction-provenance
                          (that-read am 'p ':reduction-provenance))))
