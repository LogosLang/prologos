#lang racket/base

;;;
;;; test-merge-fn-registry.rkt — PPN Track 4C Phase 1b tests
;;;
;;; Covers the Tier 2 merge-fn → domain reverse-lookup registry.
;;; Uses dummy `test-merge-*` functions + dummy domain-name symbols
;;; so tests do not couple to real SRE domain registrations (those
;;; arrive in Phase 2).
;;;
;;; Size assertions are DELTA-style against a captured base, never
;;; absolute. The registry is process-shared and load-time-populated
;;; (~30 production registrations arrive when this module loads
;;; alongside driver.rkt), and batch workers cache module instances
;;; across test files — so a destructive reset here would empty the
;;; shared registry for every LATER test file in the same worker
;;; (module bodies do not re-execute on re-require). That was the
;;; confirmed mechanism behind the test-facet-sre-registration and
;;; test-module-network-01 batch-only flakes (2026-06-11);
;;; reset-merge-fn-registry! is retired.
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
  (define fn (make-test-merge-fn))
  (register-merge-fn!/lattice fn #:for-domain 'TestDomainA)
  (check-equal? (lookup-merge-fn-domain fn) 'TestDomainA))

(test-case "unregistered lookup returns #f"
  (define fn (make-test-merge-fn))
  (check-false (lookup-merge-fn-domain fn)))

(test-case "same-fn same-domain is idempotent"
  (define base (merge-fn-registry-size))
  (define fn (make-test-merge-fn))
  (register-merge-fn!/lattice fn #:for-domain 'TestDomainA)
  (check-not-exn
   (lambda ()
     (register-merge-fn!/lattice fn #:for-domain 'TestDomainA)))
  (check-equal? (lookup-merge-fn-domain fn) 'TestDomainA)
  (check-equal? (merge-fn-registry-size) (+ base 1)))

(test-case "same-fn different-domain raises error"
  (define fn (make-test-merge-fn))
  (register-merge-fn!/lattice fn #:for-domain 'TestDomainA)
  (check-exn exn:fail?
             (lambda ()
               (register-merge-fn!/lattice fn #:for-domain 'TestDomainB))))

(test-case "different fns same domain both registered"
  (define base (merge-fn-registry-size))
  (define fn1 (make-test-merge-fn))
  (define fn2 (make-test-merge-fn))
  (register-merge-fn!/lattice fn1 #:for-domain 'TestDomainA)
  (register-merge-fn!/lattice fn2 #:for-domain 'TestDomainA)
  (check-equal? (lookup-merge-fn-domain fn1) 'TestDomainA)
  (check-equal? (lookup-merge-fn-domain fn2) 'TestDomainA)
  (check-equal? (merge-fn-registry-size) (+ base 2)))

(test-case "registry-size reflects registrations"
  (define base (merge-fn-registry-size))
  (define fn1 (make-test-merge-fn))
  (define fn2 (make-test-merge-fn))
  (define fn3 (make-test-merge-fn))
  (register-merge-fn!/lattice fn1 #:for-domain 'DomA)
  (check-equal? (merge-fn-registry-size) (+ base 1))
  (register-merge-fn!/lattice fn2 #:for-domain 'DomB)
  (check-equal? (merge-fn-registry-size) (+ base 2))
  (register-merge-fn!/lattice fn3 #:for-domain 'DomA)
  (check-equal? (merge-fn-registry-size) (+ base 3)))

(test-case "non-procedure merge-fn raises error"
  (check-exn exn:fail?
             (lambda ()
               (register-merge-fn!/lattice 'not-a-fn #:for-domain 'TestDomainA))))

(test-case "non-symbol domain raises error"
  (define fn (make-test-merge-fn))
  (check-exn exn:fail?
             (lambda ()
               (register-merge-fn!/lattice fn #:for-domain "not-a-symbol"))))
