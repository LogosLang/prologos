#lang racket/base

;;;
;;; test-merge-fn-registry.rkt — PPN Track 4C Phase 1b tests
;;;
;;; Covers the Tier 2 merge-fn → domain reverse-lookup registry.
;;; Uses dummy `test-merge-*` functions + dummy domain-name symbols
;;; so tests do not couple to real SRE domain registrations (those
;;; arrive in Phase 2).
;;;

(require rackunit
         "../merge-fn-registry.rkt")

;; ========================================
;; Fixture helpers
;; ========================================

;; Fresh dummy merge functions per test case — each is a distinct
;; function object. We don't care what they compute; only their
;; identity as registry keys matters.
(define (make-test-merge-fn)
  (lambda (old new) new))

;; ========================================
;; Tests
;; ========================================

(test-case "register + lookup roundtrip"
  (reset-merge-fn-registry!)
  (define fn (make-test-merge-fn))
  (register-merge-fn!/lattice fn #:for-domain 'TestDomainA)
  (check-equal? (lookup-merge-fn-domain fn) 'TestDomainA))

(test-case "unregistered lookup returns #f"
  (reset-merge-fn-registry!)
  (define fn (make-test-merge-fn))
  (check-false (lookup-merge-fn-domain fn)))

(test-case "same-fn same-domain is idempotent"
  (reset-merge-fn-registry!)
  (define fn (make-test-merge-fn))
  (register-merge-fn!/lattice fn #:for-domain 'TestDomainA)
  (check-not-exn
   (lambda ()
     (register-merge-fn!/lattice fn #:for-domain 'TestDomainA)))
  (check-equal? (lookup-merge-fn-domain fn) 'TestDomainA)
  (check-equal? (merge-fn-registry-size) 1))

(test-case "same-fn different-domain raises error"
  (reset-merge-fn-registry!)
  (define fn (make-test-merge-fn))
  (register-merge-fn!/lattice fn #:for-domain 'TestDomainA)
  (check-exn exn:fail?
             (lambda ()
               (register-merge-fn!/lattice fn #:for-domain 'TestDomainB))))

(test-case "different fns same domain both registered"
  (reset-merge-fn-registry!)
  (define fn1 (make-test-merge-fn))
  (define fn2 (make-test-merge-fn))
  (register-merge-fn!/lattice fn1 #:for-domain 'TestDomainA)
  (register-merge-fn!/lattice fn2 #:for-domain 'TestDomainA)
  (check-equal? (lookup-merge-fn-domain fn1) 'TestDomainA)
  (check-equal? (lookup-merge-fn-domain fn2) 'TestDomainA)
  (check-equal? (merge-fn-registry-size) 2))

(test-case "registry-size reflects registrations"
  (reset-merge-fn-registry!)
  (check-equal? (merge-fn-registry-size) 0)
  (define fn1 (make-test-merge-fn))
  (define fn2 (make-test-merge-fn))
  (define fn3 (make-test-merge-fn))
  (register-merge-fn!/lattice fn1 #:for-domain 'DomA)
  (check-equal? (merge-fn-registry-size) 1)
  (register-merge-fn!/lattice fn2 #:for-domain 'DomB)
  (check-equal? (merge-fn-registry-size) 2)
  (register-merge-fn!/lattice fn3 #:for-domain 'DomA)
  (check-equal? (merge-fn-registry-size) 3))

(test-case "non-procedure merge-fn raises error"
  (reset-merge-fn-registry!)
  (check-exn exn:fail?
             (lambda ()
               (register-merge-fn!/lattice 'not-a-fn #:for-domain 'TestDomainA))))

(test-case "non-symbol domain raises error"
  (reset-merge-fn-registry!)
  (define fn (make-test-merge-fn))
  (check-exn exn:fail?
             (lambda ()
               (register-merge-fn!/lattice fn #:for-domain "not-a-symbol"))))
