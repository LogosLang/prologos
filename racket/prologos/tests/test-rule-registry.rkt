#lang racket/base
;; PReduce SM3 — rule-registry universe cell tests (15a; ledger iter 15).
(require rackunit racket/set
         "../rule-registry.rkt"
         "../propagator.rkt")

(define r-add (make-preduce-rule #:name 'int-add-fold
                                 #:rule-id 'kernel::int-add-fold
                                 #:interface-keys '(int+)
                                 #:tier 'declarative
                                 #:lhs-pattern '(int+ (lit a) (lit b))
                                 #:rhs-template '(lit (+ a b))
                                 #:cost 1
                                 #:confluence-class 'literal-fold))
(define r-mul (make-preduce-rule #:name 'int-mul-fold
                                 #:rule-id 'kernel::int-mul-fold
                                 #:interface-keys '(int*)
                                 #:tier 'declarative))
(define r-closure (make-preduce-rule #:name 'sre-classify
                                     #:rule-id 'kernel::sre-classify
                                     #:interface-keys '(int+ classify)
                                     #:tier 'closure-resident
                                     #:apply-fn values))  ;; named Racket reference

;; ---- registration + lookup + module-keyed isolation ----
(let*-values ([(net0 cid) (make-rule-registry-cell (make-prop-network))])
  (define net1 (register-rule net0 cid 'kernel r-add))
  (define net2 (register-rule net1 cid 'kernel r-mul))
  (define net3 (register-rule net2 cid 'user-mod r-closure))
  (check-equal? (rule-lookup net3 cid 'kernel 'kernel::int-add-fold) r-add)
  (check-equal? (rule-lookup net3 cid 'user-mod 'kernel::sre-classify) r-closure)
  (check-false (rule-lookup net3 cid 'kernel 'kernel::sre-classify)
               "module components are isolated namespaces")

  ;; ---- dedup-or-error (D5): idempotent re-register OK; conflict ERRORS ----
  (check-not-exn (lambda () (register-rule net3 cid 'kernel r-add))
                 "equal? re-registration is idempotent")
  (define r-add-conflict
    (make-preduce-rule #:name 'int-add-fold
                       #:rule-id 'kernel::int-add-fold
                       #:interface-keys '(int+)
                       #:tier 'declarative
                       #:cost 99))  ;; differs
  (check-exn exn:fail?
    (lambda () (register-rule net3 cid 'kernel r-add-conflict))
    "conflicting rule under the same id must ERROR (append-only per namespace)")

  ;; ---- the propagator-maintained tag index, at quiescence ----
  (define net4 (run-to-quiescence net3))
  (check-equal? (rules-for-tag net4 cid 'int+)
                (set 'kernel::int-add-fold 'kernel::sre-classify)
                "tag index derives across modules (information flow)")
  (check-equal? (rules-for-tag net4 cid 'int*) (set 'kernel::int-mul-fold))
  (check-equal? (rules-for-tag net4 cid 'classify) (set 'kernel::sre-classify))
  (check-equal? (rules-for-tag net4 cid 'no-such-tag) (set))

  ;; index is MONOTONE under later registration: register after quiescence,
  ;; re-quiesce, the index catches up (the watcher refires)
  (define r-late (make-preduce-rule #:name 'late
                                    #:rule-id 'user-mod::late
                                    #:interface-keys '(int+)
                                    #:tier 'declarative))
  (define net5 (run-to-quiescence (register-rule net4 cid 'user-mod r-late)))
  (check-true (set-member? (rules-for-tag net5 cid 'int+) 'user-mod::late)
              "late registration flows into the derived index"))

;; ---- schema: the reserved worldview slot + tier fields round-trip ----
(check-false (preduce-rule-worldview-bitmask r-add) "reserved slot present, #f today")
(check-equal? (preduce-rule-tier r-closure) 'closure-resident)
(check-equal? (preduce-rule-stratum r-add) 's0)
(check-equal? (preduce-rule-write-target r-add) 'best+alts)
