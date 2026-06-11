#lang racket/base
;; PReduce Track 2 Phase 0 — the RHS effect-safety dispatch guard (D.1 §6.2
;; Option 2; Track 2 design §2; ledger iter 19). Tests PRECEDE the seed.
(require rackunit racket/set
         "../rule-dispatch.rkt"
         "../rule-registry.rkt"
         "../eclass-graph.rkt"
         "../eclass-cell.rkt"
         "../propagator.rkt")

;; --- capture-profile derivation units ---
(define del-rule (make-preduce-rule #:name 'del #:rule-id 't::del #:tier 'declarative
                                    #:interface-keys '(seq)
                                    #:lhs-pattern '(seq (capture a) (capture b))
                                    #:rhs-template '(only (ref b))))
(define dup-rule (make-preduce-rule #:name 'dup #:rule-id 't::dup #:tier 'declarative
                                    #:interface-keys '(dup)
                                    #:lhs-pattern '(dup (capture a))
                                    #:rhs-template '(pair (ref a) (ref a))))
(define swap-rule (make-preduce-rule #:name 'swap #:rule-id 't::swap #:tier 'declarative
                                     #:interface-keys '(seq2)
                                     #:lhs-pattern '(seq2 (capture a) (capture b))
                                     #:rhs-template '(seq2 (ref b) (ref a))))
(define keep-rule (make-preduce-rule #:name 'keep #:rule-id 't::keep #:tier 'declarative
                                     #:interface-keys '(seq2)
                                     #:lhs-pattern '(seq2 (capture a) (capture b))
                                     #:rhs-template '(seq2 (ref a) (ref b))))
(define tier2-rule (make-preduce-rule #:name 't2 #:rule-id 't::t2 #:tier 'closure-resident
                                      #:interface-keys '(seq) #:apply-fn values))

(let ([p (derive-capture-profile del-rule)])
  (check-equal? (hash-ref p 'lhs-order) '(a b))
  (check-equal? (hash-ref (hash-ref p 'counts) 'a) (cons 1 0))   ;; DELETE shape
  (check-equal? (hash-ref (hash-ref p 'counts) 'b) (cons 1 1)))
(check-equal? (hash-ref (hash-ref (derive-capture-profile dup-rule) 'counts) 'a)
              (cons 1 2))                                         ;; DUPLICATE shape
(check-equal? (derive-capture-profile tier2-rule) 'underivable)

;; --- guard behavior on a live graph ---
(define-values (net0 reg) (make-eclass-graph (make-prop-network)))
(define occ (box (hash)))
(define-values (net1 eff-cid _k) (eclass-intern-effectful net0 occ 'read 0 '(p 1)))
(define-values (net2 pure-cid _d) (eclass-intern net1 reg '(lit 42) #:cost 1))

(check-true (effect-bearing-class? net2 eff-cid))
(check-false (effect-bearing-class? net2 pure-cid))

(define (allows? rule bindings) (guard-allows? net2 (derive-capture-profile rule) bindings))

(reset-guard-skip-count!)
;; effect-bearing capture: all three violation kinds SKIP
(check-false (allows? del-rule (hash 'a eff-cid 'b pure-cid)) "DELETE of effectful skips")
(check-false (allows? dup-rule (hash 'a eff-cid)) "DUPLICATE of effectful skips")
(check-false (allows? swap-rule (hash 'a eff-cid 'b eff-cid)) "REORDER of effectful skips")
(check-equal? (guard-skip-count) 3 "each skip counted")
;; order-PRESERVING rule on effectful captures fires (not a violation)
(check-true (allows? keep-rule (hash 'a eff-cid 'b eff-cid)))
;; pure captures: all rules fire freely
(check-true (allows? del-rule (hash 'a pure-cid 'b pure-cid)))
(check-true (allows? dup-rule (hash 'a pure-cid)))
(check-true (allows? swap-rule (hash 'a pure-cid 'b pure-cid)))
;; tier-2 pessimism: effectful capture skips + counts; pure fires
(reset-guard-skip-count!)
(check-false (allows? tier2-rule (hash 'a eff-cid)) "tier-2 pessimistic skip")
(check-equal? (guard-skip-count) 1)
(check-true (allows? tier2-rule (hash 'a pure-cid)))

;; --- apply-rule end-to-end: a literal fold FIRES and the union lands ---
(define fold-rule (make-preduce-rule #:name 'int-add-fold #:rule-id 't::fold
                                     #:tier 'declarative
                                     #:interface-keys '(int+)
                                     #:lhs-pattern '(int+ (lit (capture a)) (lit (capture b)))
                                     #:rhs-template '(folded (ref a) (ref b))))
(define-values (net3 sum-cid _d3) (eclass-intern net2 reg '(int+ (lit 1) (lit 2)) #:cost 5))
(define-values (net4 fired?) (apply-rule net3 reg fold-rule sum-cid #:cost 1))
(check-true fired? "pure literal fold fires through the choke point")
(define joined (eclass-read net4 sum-cid))
(check-equal? (hash-ref joined ':best) (cons 1 '(folded 1 2))
              "the folded form wins the class (cost argmin)")
(check-true (set-member? (hash-ref joined ':alts) _d3) "original alt retained")

;; non-matching form: no fire, no error
(define-values (net5 fired2?) (apply-rule net4 reg fold-rule pure-cid))
(check-false fired2?)

;; apply-rule integrates the guard: a deleting rule over an effectful
;; sub-binding SKIPS at the choke point (class-of maps the subform)
(define del-fire-rule (make-preduce-rule #:name 'delf #:rule-id 't::delf
                                         #:tier 'declarative
                                         #:interface-keys '(seq)
                                         #:lhs-pattern '(seq (capture a) (capture b))
                                         #:rhs-template '(only (ref b))))
(define-values (net6 seq-cid _d6) (eclass-intern net5 reg '(seq EFF (lit 9)) #:cost 4))
(reset-guard-skip-count!)
(define-values (net7 fired3?)
  (apply-rule net6 reg del-fire-rule seq-cid
              #:class-of (lambda (sub) (if (eq? sub 'EFF) eff-cid #f))))
(check-false fired3? "guard blocks the deleting fire at the choke point")
(check-equal? (guard-skip-count) 1)
(check-equal? (hash-ref (eclass-read net7 seq-cid) ':best) (cons 4 '(seq EFF (lit 9)))
              "the class is untouched by the skipped rule")
