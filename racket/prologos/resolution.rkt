#lang racket/base

;;;
;;; resolution.rkt — Constraint Resolution Logic (Track 7 Phase 7a)
;;;
;;; Extracted from driver.rkt (trait/hasmethod callbacks) and unify.rkt
;;; (constraint retry callback). These are the S2 resolution functions
;;; called by execute-resolution-actions! in metavar-store.rkt.
;;;
;;; Breaking circular deps: metavar-store.rkt cannot import unify.rkt
;;; or driver.rkt directly. This module bridges the gap — it imports
;;; both and provides direct resolution functions that metavar-store.rkt
;;; can call without callback parameters.
;;;

(require racket/match
         "syntax.rkt"
         "metavar-store.rkt"
         "unify.rkt"
         "zonk.rkt"
         "trait-resolution.rkt"
         "macros.rkt"
         "infra-cell.rkt"
         "performance-counters.rkt")

(provide retry-unify-constraint!
         resolve-trait-constraint!
         resolve-hasmethod-constraint!
         ;; Track 7 Phase 7a: single dispatcher replacing 3 callbacks
         resolution-execute-action!)

;; ========================================
;; Constraint Retry (extracted from unify.rkt module-level callback)
;; ========================================
;; When a postponed constraint's dependency metas are solved, retry
;; unification. Uses unify-core (not unify) to avoid double propagator
;; checking — the retry is triggered by the stratified resolution loop.

(define (retry-unify-constraint! c)
  (let ([lhs (zonk-at-depth 0 (constraint-lhs c))]
        [rhs (zonk-at-depth 0 (constraint-rhs c))])
    (define result (unify-core (constraint-ctx c) lhs rhs))
    (cond
      [(eq? result #t)
       (write-constraint-to-store! (struct-copy constraint c [status 'solved]))
       (write-constraint-status-cell! (constraint-cid c) 'resolved)]
      [(eq? result #f)
       (write-constraint-to-store! (struct-copy constraint c [status 'failed]))
       (write-constraint-status-cell! (constraint-cid c) 'resolved)]
      ;; 'postponed: leave status as-is (will be set back to 'postponed
      ;; by the caller if still 'retrying)
      )))

;; ========================================
;; Trait Resolution (extracted from driver.rkt callback)
;; ========================================
;; When a trait constraint's type-arg metas are all ground, attempt
;; monomorphic then parametric resolution. On success, solve the dict meta.
;; On failure, record an error descriptor for the post-fixpoint error sweep.

(define (resolve-trait-constraint! dict-meta-id tc-info)
  (define trait-name (trait-constraint-info-trait-name tc-info))
  (define type-args
    (map (lambda (e) (normalize-for-resolution (zonk e)))
         (trait-constraint-info-type-arg-exprs tc-info)))
  (when (andmap ground-expr? type-args)
    (define dict-expr
      (or (try-monomorphic-resolve trait-name type-args)
          (try-parametric-resolve trait-name type-args)))
    (if dict-expr
        (solve-meta! dict-meta-id dict-expr)
        ;; Track 2 Phase 7: Write error descriptor on resolution failure.
        (write-error-descriptor! dict-meta-id
          (build-trait-error dict-meta-id trait-name type-args)))))

;; ========================================
;; HasMethod Resolution (extracted from driver.rkt callback)
;; ========================================
;; When a hasmethod constraint's dependency metas (trait-var + type-args)
;; are all ground, resolve by finding the trait with the method,
;; resolving the dict, and projecting the method.

(define (resolve-hasmethod-constraint! meta-id hm-info)
  (unless (meta-solved? meta-id)
    (define method-name (hasmethod-constraint-info-method-name hm-info))
    (define type-args
      (map (lambda (e) (normalize-for-resolution (zonk e)))
           (hasmethod-constraint-info-type-arg-exprs hm-info)))
    (when (andmap ground-expr? type-args)
      ;; Strategy 1: P (trait var) is already ground
      (define trait-expr (zonk (hasmethod-constraint-info-trait-var-expr hm-info)))
      (define known-trait-name (and (ground-expr? trait-expr) (trait-expr->name trait-expr)))
      ;; Strategy 2: P is not ground — search all traits for the method name
      (define resolved-trait-name
        (or known-trait-name
            (find-trait-with-method method-name type-args)))
      (when resolved-trait-name
        (define tm (lookup-trait resolved-trait-name))
        (when tm
          (define methods (trait-meta-methods tm))
          (define method-idx
            (for/or ([m (in-list methods)] [i (in-naturals)])
              (and (eq? (trait-method-name m) method-name) i)))
          (when method-idx
            ;; Resolve the dict via standard impl resolution
            (define dict-expr
              (or (try-monomorphic-resolve resolved-trait-name type-args)
                  (try-parametric-resolve resolved-trait-name type-args)))
            (when dict-expr
              ;; Solve the trait variable P if it's still a meta
              (define trait-var-expr (hasmethod-constraint-info-trait-var-expr hm-info))
              (when (and (expr-meta? trait-var-expr)
                         (not (meta-solved? (expr-meta-id trait-var-expr))))
                (solve-meta! (expr-meta-id trait-var-expr) (expr-fvar resolved-trait-name)))
              ;; Optionally solve the dict meta if present
              (define dict-meta-id (hasmethod-constraint-info-dict-meta-id hm-info))
              (when (and dict-meta-id (not (meta-solved? dict-meta-id)))
                (solve-meta! dict-meta-id dict-expr))
              ;; Project the method and solve the evidence meta.
              (unless (meta-solved? meta-id)
                (define projected (project-method dict-expr tm method-idx))
                (solve-meta! meta-id projected)))))))))

;; ========================================
;; Track 7 Phase 7a: Unified Resolution Dispatcher
;; ========================================
;; Single function replacing 3 callback parameters.
;; Called from execute-resolution-actions! in metavar-store.rkt.

(define (resolution-execute-action! action)
  (match action
    [(action-retry-constraint c)
     ;; Re-check: constraint may have been resolved by a prior action.
     (define c-cid (constraint-cid c))
     (define current-c (read-constraint-by-cid c-cid))
     (when (and current-c (eq? (constraint-status current-c) 'postponed))
       (perf-inc-constraint-retry!)
       (write-constraint-to-store! (struct-copy constraint current-c [status 'retrying]))
       (retry-unify-constraint! current-c)
       (define post-c (read-constraint-by-cid c-cid))
       (when (and post-c (eq? (constraint-status post-c) 'retrying))
         (write-constraint-to-store! (struct-copy constraint post-c [status 'postponed]))))]
    [(action-resolve-trait dict-id tc-info)
     (unless (meta-solved? dict-id)
       (resolve-trait-constraint! dict-id tc-info))]
    [(action-resolve-hasmethod hm-id hm-info)
     (unless (meta-solved? hm-id)
       (resolve-hasmethod-constraint! hm-id hm-info))]))
