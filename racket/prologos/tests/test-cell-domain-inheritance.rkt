#lang racket/base

;;;
;;; test-cell-domain-inheritance.rkt — PPN Track 4C Phase 1c tests
;;;
;;; Covers Tier 3 inheritance: cells inherit domain from their
;;; merge function at allocation time, unless #:domain overrides.
;;; Tests both net-new-cell and net-new-cell-desc variants.
;;; net-new-cell-widen is tested indirectly via net-new-cell since
;;; it's a thin wrapper.
;;;

(require rackunit
         "../merge-fn-registry.rkt"
         "../propagator.rkt")

;; Fresh dummy merge functions — distinct identities per test.
(define (make-test-merge-fn)
  (lambda (old new) new))

(define (make-test-meet-fn)
  (lambda (old new) (if (eq? new 'bot) 'bot old)))

;; Helper: build a fresh minimal prop-network for tests.
;; NOTE: make-prop-network allocates topology cells (0-9). We get
;; a clean slate for our cells starting at id 10.
(define (fresh-net)
  (make-prop-network))

(test-case "cell inherits domain from registered merge-fn"
  (reset-merge-fn-registry!)
  (define fn (make-test-merge-fn))
  (register-merge-fn!/lattice fn #:for-domain 'TestDomain)
  (define-values (net cid) (net-new-cell (fresh-net) 'initial fn))
  (check-equal? (lookup-cell-domain net cid) 'TestDomain))

(test-case "unregistered merge-fn leaves cell unclassified (#f)"
  (reset-merge-fn-registry!)
  (define fn (make-test-merge-fn))
  ;; fn NOT registered
  (define-values (net cid) (net-new-cell (fresh-net) 'initial fn))
  (check-false (lookup-cell-domain net cid)))

(test-case "#:domain override wins over registered merge-fn"
  (reset-merge-fn-registry!)
  (define fn (make-test-merge-fn))
  (register-merge-fn!/lattice fn #:for-domain 'InheritedDomain)
  (define-values (net cid)
    (net-new-cell (fresh-net) 'initial fn #f #:domain 'OverrideDomain))
  (check-equal? (lookup-cell-domain net cid) 'OverrideDomain))

(test-case "#:domain override works when merge-fn unregistered"
  (reset-merge-fn-registry!)
  (define fn (make-test-merge-fn))
  ;; fn NOT registered
  (define-values (net cid)
    (net-new-cell (fresh-net) 'initial fn #f #:domain 'ExplicitDomain))
  (check-equal? (lookup-cell-domain net cid) 'ExplicitDomain))

(test-case "multiple cells on same merge-fn all inherit"
  (reset-merge-fn-registry!)
  (define fn (make-test-merge-fn))
  (register-merge-fn!/lattice fn #:for-domain 'SharedDomain)
  (define-values (net1 cid1) (net-new-cell (fresh-net) 'a fn))
  (define-values (net2 cid2) (net-new-cell net1 'b fn))
  (check-equal? (lookup-cell-domain net2 cid1) 'SharedDomain)
  (check-equal? (lookup-cell-domain net2 cid2) 'SharedDomain))

(test-case "cells with different merge-fns get different domains"
  (reset-merge-fn-registry!)
  (define fn-a (make-test-merge-fn))
  (define fn-b (make-test-merge-fn))
  (register-merge-fn!/lattice fn-a #:for-domain 'DomainA)
  (register-merge-fn!/lattice fn-b #:for-domain 'DomainB)
  (define-values (net1 cid-a) (net-new-cell (fresh-net) 'a fn-a))
  (define-values (net2 cid-b) (net-new-cell net1 'b fn-b))
  (check-equal? (lookup-cell-domain net2 cid-a) 'DomainA)
  (check-equal? (lookup-cell-domain net2 cid-b) 'DomainB))

(test-case "net-new-cell-desc also inherits"
  (reset-merge-fn-registry!)
  (define meet (make-test-meet-fn))
  (register-merge-fn!/lattice meet #:for-domain 'DescDomain)
  (define-values (net cid) (net-new-cell-desc (fresh-net) 'top meet))
  (check-equal? (lookup-cell-domain net cid) 'DescDomain))

(test-case "net-new-cell-desc honors #:domain override"
  (reset-merge-fn-registry!)
  (define meet (make-test-meet-fn))
  (register-merge-fn!/lattice meet #:for-domain 'InheritedMeet)
  (define-values (net cid)
    (net-new-cell-desc (fresh-net) 'top meet #f #:domain 'OverrideMeet))
  (check-equal? (lookup-cell-domain net cid) 'OverrideMeet))

(test-case "backward compat: existing call sites without #:domain work"
  (reset-merge-fn-registry!)
  (define fn (make-test-merge-fn))
  ;; Simulate the 101 existing call sites: no domain kwarg, no registration.
  ;; Cell should allocate successfully and be unclassified.
  (define-values (net cid) (net-new-cell (fresh-net) 'initial fn))
  (check-false (lookup-cell-domain net cid))
  ;; Cell is still fully functional for reads/writes.
  (check-equal? (net-cell-read net cid) 'initial))

(test-case "lookup-cell-domain on unknown cell-id returns #f"
  (reset-merge-fn-registry!)
  ;; Not an allocated cell-id
  (check-false (lookup-cell-domain (fresh-net) (cell-id 999999))))
