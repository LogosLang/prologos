#lang racket/base

;;;
;;; infra-cell-sre-registrations.rkt — PPN 4C Phase 1d Tier 1+2 registrations
;;;
;;; Registers the generic merge functions from `infra-cell.rkt` as SRE
;;; domains + Tier 2 merge-fn-registry entries.
;;;
;;; Separate module to break the import cycle that would result if
;;; infra-cell.rkt imported sre-core.rkt directly:
;;;   infra-cell.rkt → sre-core.rkt → ctor-registry.rkt → sessions.rkt
;;;   → substitution.rkt → namespace.rkt → infra-cell.rkt [CYCLE]
;;;
;;; This module is loaded by `driver.rkt` (or any module downstream of
;;; both infra-cell and sre-core) for the registration side effects.
;;;
;;; D2 framework (§6.9.2) per registration: aspirational / declared /
;;; inference / delta. Detailed tables in the Phase 1d commit message.
;;;
;;; NOT registered here (scoped to Phase 1e correctness refactors):
;;;   - merge-replace + merge-last-write-wins — replace-semantics
;;;     call-site audit; refactor paths (timestamp-ordered / identity-
;;;     or-error / accept-as-non-lattice) decided per site.
;;;
;;; PPN 4C Phase 1e-α (2026-04-20): η split of merge-hasheq-union.
;;; Retired 'monotone-registry domain; replaced with two domains:
;;;   'hasheq-identity — merge-hasheq-identity, identity-or-error
;;;     (commutative, associative, idempotent by construction;
;;;      `#:contradicts?` recognizes the hasheq-identity-contradiction sentinel)
;;;   'hasheq-replace  — merge-hasheq-replace, explicit last-write-wins
;;;     (non-commutative by intent; named so ambiguity is gone)
;;;

(require racket/set
         "infra-cell.rkt"
         "sre-core.rkt"
         "merge-fn-registry.rkt")

;; 'hasheq-identity — merge-hasheq-identity (identity-or-error)
;; Contradiction sentinel: 'hasheq-identity-contradiction — returned
;; when same-key writes carry different values. SRE domain's
;; `#:contradicts?` predicate recognizes the sentinel so downstream
;; propagators see contradiction and halt (path A per §6.14.6;
;; Phase 11b upgrades to path C provenance-rich contradict-record).
(define hasheq-identity-sre-domain
  (make-sre-domain
   #:name 'hasheq-identity
   #:merge-registry (lambda (r)
                      (case r
                        [(equality) merge-hasheq-identity]
                        [else (error 'hasheq-identity-merge "no merge: ~a" r)]))
   #:contradicts? hasheq-identity-contradiction?
   #:bot? (lambda (v) (and (hash? v) (zero? (hash-count v))))
   #:bot-value (hasheq)))
(register-domain! hasheq-identity-sre-domain)
(register-merge-fn!/lattice merge-hasheq-identity #:for-domain 'hasheq-identity)

;; 'hasheq-replace — merge-hasheq-replace (explicit last-write-wins)
;; D2 delta: non-commutative by intent at sites where same-key-different-
;; value is legitimate (per-elab evolving stores). Named so that the
;; intent is explicit; not registered as identity domain because
;; collision is not an error here.
(define hasheq-replace-sre-domain
  (make-sre-domain
   #:name 'hasheq-replace
   #:merge-registry (lambda (r)
                      (case r
                        [(equality) merge-hasheq-replace]
                        [else (error 'hasheq-replace-merge "no merge: ~a" r)]))
   #:contradicts? (lambda (v) #f)
   #:bot? (lambda (v) (and (hash? v) (zero? (hash-count v))))
   #:bot-value (hasheq)))
(register-domain! hasheq-replace-sre-domain)
(register-merge-fn!/lattice merge-hasheq-replace #:for-domain 'hasheq-replace)

;; 'hash-of-lists-accumulator — merge-hasheq-list-append
(define hash-of-lists-accumulator-sre-domain
  (make-sre-domain
   #:name 'hash-of-lists-accumulator
   #:merge-registry (lambda (r)
                      (case r
                        [(equality) merge-hasheq-list-append]
                        [else (error 'hash-of-lists-accumulator-merge "no merge: ~a" r)]))
   #:contradicts? (lambda (v) #f)
   #:bot? (lambda (v) (and (hash? v) (zero? (hash-count v))))
   #:bot-value (hasheq)))
(register-domain! hash-of-lists-accumulator-sre-domain)
(register-merge-fn!/lattice merge-hasheq-list-append #:for-domain 'hash-of-lists-accumulator)

;; 'accumulator-list — merge-list-append (non-comm monoidal)
(define accumulator-list-sre-domain
  (make-sre-domain
   #:name 'accumulator-list
   #:merge-registry (lambda (r)
                      (case r
                        [(equality) merge-list-append]
                        [else (error 'accumulator-list-merge "no merge: ~a" r)]))
   #:contradicts? (lambda (v) #f)
   #:bot? (lambda (v) (and (list? v) (null? v)))
   #:bot-value '()))
(register-domain! accumulator-list-sre-domain)
(register-merge-fn!/lattice merge-list-append #:for-domain 'accumulator-list)

;; 'monotone-set — merge-set-union (proper join-semilattice)
(define monotone-set-sre-domain
  (make-sre-domain
   #:name 'monotone-set
   #:merge-registry (lambda (r)
                      (case r
                        [(equality) merge-set-union]
                        [else (error 'monotone-set-merge "no merge: ~a" r)]))
   #:contradicts? (lambda (v) #f)
   #:bot? (lambda (v) (and (set? v) (set-empty? v)))
   #:bot-value (seteq)))
(register-domain! monotone-set-sre-domain)
(register-merge-fn!/lattice merge-set-union #:for-domain 'monotone-set)

;; 'constraint-status-map — merge-constraint-status-map
;; (pending→resolved monotone per key)
(define constraint-status-map-sre-domain
  (make-sre-domain
   #:name 'constraint-status-map
   #:merge-registry (lambda (r)
                      (case r
                        [(equality) merge-constraint-status-map]
                        [else (error 'constraint-status-map-merge "no merge: ~a" r)]))
   #:contradicts? (lambda (v) #f)
   #:bot? (lambda (v) (and (hash? v) (zero? (hash-count v))))
   #:bot-value (hasheq)))
(register-domain! constraint-status-map-sre-domain)
(register-merge-fn!/lattice merge-constraint-status-map #:for-domain 'constraint-status-map)

;; 'error-descriptor-map — merge-error-descriptor-map
;; (last-wins per key; Phase 1e audit may refactor)
(define error-descriptor-map-sre-domain
  (make-sre-domain
   #:name 'error-descriptor-map
   #:merge-registry (lambda (r)
                      (case r
                        [(equality) merge-error-descriptor-map]
                        [else (error 'error-descriptor-map-merge "no merge: ~a" r)]))
   #:contradicts? (lambda (v) #f)
   #:bot? (lambda (v) (and (hash? v) (zero? (hash-count v))))
   #:bot-value (hasheq)))
(register-domain! error-descriptor-map-sre-domain)
(register-merge-fn!/lattice merge-error-descriptor-map #:for-domain 'error-descriptor-map)

;; 'module-lifecycle — merge-mod-status
;; (mod-loading < mod-loaded < mod-stale; proper join-semilattice)
(define module-lifecycle-sre-domain
  (make-sre-domain
   #:name 'module-lifecycle
   #:merge-registry (lambda (r)
                      (case r
                        [(equality) merge-mod-status]
                        [else (error 'module-lifecycle-merge "no merge: ~a" r)]))
   #:contradicts? (lambda (v) #f)
   #:bot? (lambda (v) (eq? v 'mod-loading))
   #:bot-value 'mod-loading))
(register-domain! module-lifecycle-sre-domain)
(register-merge-fn!/lattice merge-mod-status #:for-domain 'module-lifecycle)
