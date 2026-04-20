#lang racket/base

;;;
;;; test-component-paths-enforcement.rkt — PPN 4C Phase 1f
;;;
;;; Tests the structural-domain :component-paths enforcement at
;;; net-add-propagator. Creates minimal test cases for each classification
;;; branch: 'structural (enforces), 'value (skips), 'unclassified (skips).
;;;

(require rackunit
         "../propagator.rkt"
         "../sre-core.rkt"
         "../merge-fn-registry.rkt"
         "../infra-cell-sre-registrations.rkt")  ;; wires current-domain-classification-lookup

;; ============================================================
;; Setup: test-structural and test-value domains
;; ============================================================

(define (test-structural-merge old new)
  (cond
    [(eq? old 'infra-bot) new]
    [(eq? new 'infra-bot) old]
    [else (for/fold ([acc old]) ([(k v) (in-hash new)]) (hash-set acc k v))]))

(define test-structural-domain
  (make-sre-domain
   #:name 'test-structural-enforcement
   #:merge-registry (lambda (r) (case r [(equality) test-structural-merge]))
   #:contradicts? (lambda (v) #f)
   #:bot? (lambda (v) (and (hash? v) (zero? (hash-count v))))
   #:bot-value (hasheq)
   #:classification 'structural))
(register-domain! test-structural-domain)
(register-merge-fn!/lattice test-structural-merge #:for-domain 'test-structural-enforcement)

(define (test-value-merge old new)
  (cond
    [(eq? old 'infra-bot) new]
    [else new]))  ;; simple replace for value lattice

(define test-value-domain
  (make-sre-domain
   #:name 'test-value-enforcement
   #:merge-registry (lambda (r) (case r [(equality) test-value-merge]))
   #:contradicts? (lambda (v) #f)
   #:bot? (lambda (v) (eq? v 'infra-bot))
   #:bot-value 'infra-bot
   #:classification 'value))
(register-domain! test-value-domain)
(register-merge-fn!/lattice test-value-merge #:for-domain 'test-value-enforcement)

;; An unclassified domain (legacy — no #:classification kwarg).
(define (test-unclassified-merge old new)
  (cond [(eq? old 'infra-bot) new] [else new]))

(define test-unclassified-domain
  (make-sre-domain
   #:name 'test-unclassified-enforcement
   #:merge-registry (lambda (r) (case r [(equality) test-unclassified-merge]))
   #:contradicts? (lambda (v) #f)
   #:bot? (lambda (v) (eq? v 'infra-bot))
   #:bot-value 'infra-bot))  ;; no #:classification → defaults to 'unclassified
(register-domain! test-unclassified-domain)
(register-merge-fn!/lattice test-unclassified-merge #:for-domain 'test-unclassified-enforcement)

;; ============================================================
;; Classification lookup
;; ============================================================

(test-case "lookup-domain-classification: structural"
  (check-equal? (lookup-domain-classification 'test-structural-enforcement) 'structural))

(test-case "lookup-domain-classification: value"
  (check-equal? (lookup-domain-classification 'test-value-enforcement) 'value))

(test-case "lookup-domain-classification: unclassified default"
  (check-equal? (lookup-domain-classification 'test-unclassified-enforcement) 'unclassified))

(test-case "lookup-domain-classification: unregistered returns #f"
  (check-equal? (lookup-domain-classification 'no-such-domain) #f))

;; ============================================================
;; Enforcement at net-add-propagator
;; ============================================================

(test-case "structural domain + :component-paths declared → OK"
  (define net0 (make-prop-network))
  (define-values (net1 cid)
    (net-new-cell net0 (hasheq) test-structural-merge))
  (define-values (net2 out-cid)
    (net-new-cell net1 'nothing test-value-merge))
  ;; Add propagator WITH component-paths for the structural cell
  (define-values (net3 _pid)
    (net-add-propagator net2 (list cid) (list out-cid)
                        (lambda (n) n)
                        #:component-paths (list (cons cid 'some-path))))
  (check-true (prop-network? net3)))

(test-case "structural domain + MISSING :component-paths → error"
  (define net0 (make-prop-network))
  (define-values (net1 cid)
    (net-new-cell net0 (hasheq) test-structural-merge))
  (define-values (net2 out-cid)
    (net-new-cell net1 'nothing test-value-merge))
  ;; Add propagator WITHOUT component-paths for the structural cell
  (check-exn
   (lambda (e) (regexp-match? #rx"must declare :component-paths" (exn-message e)))
   (lambda ()
     (net-add-propagator net2 (list cid) (list out-cid)
                         (lambda (n) n)))))

(test-case "value domain + no :component-paths → OK (no enforcement)"
  (define net0 (make-prop-network))
  (define-values (net1 cid)
    (net-new-cell net0 'infra-bot test-value-merge))
  (define-values (net2 out-cid)
    (net-new-cell net1 'nothing test-value-merge))
  ;; Add propagator WITHOUT component-paths; value domain skips enforcement
  (define-values (net3 _pid)
    (net-add-propagator net2 (list cid) (list out-cid)
                        (lambda (n) n)))
  (check-true (prop-network? net3)))

(test-case "unclassified domain + no :component-paths → OK (progressive rollout)"
  (define net0 (make-prop-network))
  (define-values (net1 cid)
    (net-new-cell net0 'infra-bot test-unclassified-merge))
  (define-values (net2 out-cid)
    (net-new-cell net1 'nothing test-value-merge))
  ;; Unclassified: enforcement skips (legacy compatibility)
  (define-values (net3 _pid)
    (net-add-propagator net2 (list cid) (list out-cid)
                        (lambda (n) n)))
  (check-true (prop-network? net3)))

(test-case "multiple input cells: structural enforced, value skipped"
  (define net0 (make-prop-network))
  (define-values (net1 struct-cid)
    (net-new-cell net0 (hasheq) test-structural-merge))
  (define-values (net2 value-cid)
    (net-new-cell net1 'infra-bot test-value-merge))
  (define-values (net3 out-cid)
    (net-new-cell net2 'nothing test-value-merge))
  ;; Declare paths for structural input; value input skips
  (define-values (net4 _pid)
    (net-add-propagator net3 (list struct-cid value-cid) (list out-cid)
                        (lambda (n) n)
                        #:component-paths (list (cons struct-cid 'path1))))
  (check-true (prop-network? net4)))

(test-case "multiple structural inputs: each needs its own path declaration"
  (define net0 (make-prop-network))
  (define-values (net1 cid-a)
    (net-new-cell net0 (hasheq) test-structural-merge))
  (define-values (net2 cid-b)
    (net-new-cell net1 (hasheq) test-structural-merge))
  (define-values (net3 out-cid)
    (net-new-cell net2 'nothing test-value-merge))
  ;; Missing path for cid-b → error
  (check-exn
   (lambda (e) (regexp-match? #rx"must declare :component-paths" (exn-message e)))
   (lambda ()
     (net-add-propagator net3 (list cid-a cid-b) (list out-cid)
                         (lambda (n) n)
                         #:component-paths (list (cons cid-a 'path-a))))))
