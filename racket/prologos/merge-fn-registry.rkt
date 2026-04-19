#lang racket/base

;;;
;;; merge-fn-registry.rkt — PPN Track 4C Phase 1b Tier 2 API
;;;
;;; SCAFFOLDING. Retires when PM Track 12 (Module Loading on Network)
;;; migrates off-network registries to cells. Tracked in DEFERRED.md
;;; § "Off-Network Registry Scaffolding (PM Track 12 consolidation)".
;;;
;;; Purpose: link merge functions (Tier 2) to their SRE domain (Tier 1)
;;; so cells (Tier 3) can inherit domain classification from their
;;; merge-fn argument. This is the reverse-lookup the SRE domain struct
;;; does not provide directly — SRE's `sre-domain.merge-registry` is
;;; the forward map (relation → merge-fn); this module is the reverse
;;; (merge-fn → domain-name) per D.3 §6.8 option (a) (independent
;;; reverse-lookup registry, chosen 2026-04-18 for smaller blast
;;; radius over option (b) which would extend SRE's semantics).
;;;
;;; Architectural direction: PM Track 12 consolidates all off-network
;;; registries to cells with unified API. Until then:
;;;   - keep API minimal and consistent with existing `register-X!`
;;;     patterns (SRE `register-domain!`, propagator
;;;     `register-stratum-handler!`, etc.)
;;;   - keep identifier names that make scaffolding status visible
;;;     (`scaffolding-merge-fn-registry`)
;;;   - keep retirement plan in comment at point of use
;;;
;;; Phase 1b scope: API + reverse-lookup registry ONLY. No actual
;;; merge-fn registrations happen here (Phase 1d/1e do that). No
;;; `#:domain` plumbing to cell-creation variants here (Phase 1c does
;;; that). No structural enforcement at `net-add-propagator` here
;;; (Phase 1f does that).
;;;

(require racket/format)

(provide register-merge-fn!/lattice
         lookup-merge-fn-domain
         merge-fn-registry-size
         ;; Testing support: reset the registry between tests
         reset-merge-fn-registry!)

;; ========================================
;; Registry storage (SCAFFOLDING — PM Track 12)
;; ========================================
;; Function-object identity via `make-hasheq`. Two same-shape functions
;; defined separately are different identities (Racket `eq?` semantics);
;; this is correct — the registry keys on the specific function object
;; passed to `net-new-cell`.
(define scaffolding-merge-fn-registry (make-hasheq))

;; ========================================
;; Public API
;; ========================================

;; Register a merge function as implementing a Tier 1 SRE domain.
;; MERGE-FN: the function object (as passed positionally to net-new-cell).
;; DOMAIN-NAME: symbol identifying a Tier 1 SRE-registered domain
;;   (the name registered via sre-core's `register-domain!`).
;;
;; Collision semantics:
;;   - Re-register same fn → same domain : idempotent (silent no-op)
;;   - Re-register same fn → different domain : hard error
;;     (indicates either a bug in the registration site or a design
;;      problem where one merge fn implements two lattices)
;;
;; Module reload is treated as re-registration — same-fn-same-domain
;; idempotence makes Racket's dev cycle (reload + re-require) safe.
(define (register-merge-fn!/lattice merge-fn #:for-domain domain-name)
  (unless (procedure? merge-fn)
    (error 'register-merge-fn!/lattice
           "expected procedure for merge-fn, got: ~e" merge-fn))
  (unless (symbol? domain-name)
    (error 'register-merge-fn!/lattice
           "expected symbol for #:for-domain, got: ~e" domain-name))
  (define existing (hash-ref scaffolding-merge-fn-registry merge-fn #f))
  (cond
    [(not existing)
     (hash-set! scaffolding-merge-fn-registry merge-fn domain-name)]
    [(eq? existing domain-name)
     ;; idempotent — module reload, repeated registration
     (void)]
    [else
     (error 'register-merge-fn!/lattice
            (string-append
             "merge function ~e is already registered for domain ~a; "
             "cannot re-register for different domain ~a "
             "(each merge function implements exactly one lattice)")
            merge-fn existing domain-name)]))

;; Look up the domain name a merge function is registered for.
;; Returns the domain name symbol, or #f if unregistered.
;; Callers decide what #f means in their context:
;;   - Phase 1c (net-new-cell inheritance): #f = no domain inherited;
;;     cell stays unclassified unless `#:domain` override is present
;;   - Phase 1f (net-add-propagator enforcement): #f on a structural
;;     cell's merge-fn = structural enforcement error
(define (lookup-merge-fn-domain merge-fn)
  (hash-ref scaffolding-merge-fn-registry merge-fn #f))

;; Count of currently-registered merge functions. Primarily for:
;;   - Phase 1a/1e lint baseline progress tracking
;;   - Test assertions (fixture verification)
(define (merge-fn-registry-size)
  (hash-count scaffolding-merge-fn-registry))

;; Reset to empty state. SCAFFOLDING — only for test isolation.
;; Not exported for production use; production registrations are
;; at module load time and should not be unregistered.
(define (reset-merge-fn-registry!)
  (hash-clear! scaffolding-merge-fn-registry))
