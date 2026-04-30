#lang racket/base

;;; sre-sample-generator.rkt — Programmatic sample generator from ctor-desc registry
;;;
;;; SRE Track 2I Phase 2 (2026-04-30).
;;;
;;; Walks a domain's ctor-desc table to synthesize representative inhabitants
;;; for empirical algebraic-property checking (test-distributive, test-sd-vee,
;;; test-sd-wedge, etc.). Produces values bottom-up from depth 0 (atoms) to
;;; configurable max-depth.
;;;
;;; DESIGN NOTES:
;;; - Decomplection: generator is orthogonal to property-check infrastructure.
;;;   Any future algebraic-property test consumes generator output uniformly.
;;; - Determinism: no randomness. ctor-desc iteration order + Cartesian product
;;;   gives reproducible samples. Phase 3 findings tied to a specific generator
;;;   call will be reproducible across runs.
;;; - Defensive scaffolding: `with-handlers` around (reconstruct-fn ...)
;;;   silently skips failed reconstructions. Labeled scaffolding — this is
;;;   tolerable because the generator is naive about component-type
;;;   compatibility; ctors that demand specific component shapes will reject
;;;   incompatible combinations at reconstruction time. If Phase 3 reveals
;;;   systematic sample loss obscuring property findings, revisit with
;;;   per-ctor compatibility filtering.
;;;
;;; LIMITATIONS:
;;; - Binder ctors (binder-depth > 0) — Pi, Sigma, lam — are SKIPPED in this
;;;   phase. Including them properly requires gensym + binder-open-fn
;;;   machinery beyond the empirical-SD-check scope. Documented Phase-3
;;;   revisit if findings reveal gaps from missing function-type coverage.
;;; - Cartesian product grows as per-ctor-count^arity. Default per-ctor-count=2
;;;   keeps arity-2 ctors at 4 inhabitants, arity-3 at 8. No automatic budget;
;;;   caller controls parameters.

(require racket/list)
(require "ctor-registry.rkt")
(require "sre-core.rkt")

(provide generate-domain-samples)

;; ========================================================================
;; Sample Generation
;; ========================================================================

;; Generate a list of representative values for a domain's ctor-desc registry.
;; Walks the registry bottom-up: depth 0 (atoms + bot/top) → depth max-depth
;; (compound values whose components are drawn from depth (d-1)).
;;
;; #:max-depth      — max constructor nesting depth (default 2)
;; #:per-ctor-count — number of components per arg slot in Cartesian product
;;                    (default 2). For arity N, this gives per-ctor-count^N
;;                    inhabitants per ctor per depth.
;; #:include-bot-top — include bot-value and top-value at depth 0 (default #t)
;; #:base-values    — optional list of pre-built atomic samples (e.g.,
;;                    (list (expr-Int) (expr-Bool))). Concatenated with
;;                    auto-generated atomics.
;;
;; Returns: (listof value), deduplicated via equal?.
(define (generate-domain-samples domain
                                 #:max-depth [max-depth 2]
                                 #:per-ctor-count [per-ctor-count 2]
                                 #:include-bot-top [include-bot-top #t]
                                 #:base-values [base-values #f])
  (define domain-name (sre-domain-name domain))
  (define ctor-descs (all-ctor-descs #:domain domain-name))

  ;; ----------------------------------------------------------------------
  ;; Depth 0: bot/top + base-values + nullary ctor inhabitants
  ;; ----------------------------------------------------------------------
  (define depth-0-atoms
    (let* ([acc '()]
           [acc (if include-bot-top
                    (list* (sre-domain-bot-value domain)
                           (sre-domain-top-value domain)
                           acc)
                    acc)]
           [acc (if base-values (append base-values acc) acc)]
           [acc (append acc (nullary-ctor-inhabitants ctor-descs))])
      (remove-duplicates acc)))

  ;; ----------------------------------------------------------------------
  ;; Depth d > 0: compound values
  ;; ----------------------------------------------------------------------
  ;; samples-by-depth: list of lists, indexed by depth.
  ;; Iteratively fold from 1 to max-depth, drawing components from depth (d-1).
  (define samples-by-depth
    (for/fold ([acc (list depth-0-atoms)])
              ([d (in-range 1 (+ max-depth 1))])
      (define prev-samples (last acc))
      (define component-pool (take-up-to prev-samples per-ctor-count))
      (define new-samples
        (compound-ctor-inhabitants ctor-descs component-pool domain-name))
      (append acc (list (remove-duplicates new-samples)))))

  ;; ----------------------------------------------------------------------
  ;; Flatten across depths, dedupe globally
  ;; ----------------------------------------------------------------------
  (remove-duplicates (apply append samples-by-depth)))

;; ========================================================================
;; Helpers
;; ========================================================================

;; Take up to n elements from xs (without erroring if (length xs) < n).
(define (take-up-to xs n)
  (cond
    [(<= n 0) '()]
    [(null? xs) '()]
    [else (cons (car xs) (take-up-to (cdr xs) (- n 1)))]))

;; Reconstruct nullary ctor inhabitants from a domain's ctor-descs.
;; Skips binder ctors (binder-depth > 0).
(define (nullary-ctor-inhabitants ctor-descs)
  (for/fold ([acc '()])
            ([desc (in-list ctor-descs)]
             #:when (and (zero? (ctor-desc-arity desc))
                         (zero? (ctor-desc-binder-depth desc))))
    (define v (try-reconstruct desc '()))
    (if v (cons v acc) acc)))

;; Reconstruct compound ctor inhabitants by Cartesian-producting components.
;; Skips:
;;   - arity-0 ctors (handled at depth 0)
;;   - binder ctors (binder-depth > 0; documented Phase-2 limitation)
;;   - reconstructions that fail (try-reconstruct returns #f)
;;
;; Validation: we rely on the ctor's reconstruct-fn to reject malformed
;; component combinations (it raises on type mismatch). The with-handlers
;; in try-reconstruct catches these as silent-skip. A future per-value
;; classification check could be added if Phase 3 reveals the silent skip
;; misses real malformedness; today's coverage is the reconstruct contract.
(define (compound-ctor-inhabitants ctor-descs component-pool _domain-name)
  (for/fold ([acc '()])
            ([desc (in-list ctor-descs)]
             #:when (and (positive? (ctor-desc-arity desc))
                         (zero? (ctor-desc-binder-depth desc))))
    (for/fold ([acc2 acc])
              ([combo (in-list (cartesian-of-arity component-pool
                                                   (ctor-desc-arity desc)))])
      (define v (try-reconstruct desc combo))
      (if v (cons v acc2) acc2))))

;; Cartesian product of `pool` repeated `arity` times.
;; arity=0 → '(()) (single empty combo); arity=1 → '((x) (y) ...);
;; arity=2 → '((x x) (x y) ... (y y)); etc.
(define (cartesian-of-arity pool arity)
  (cond
    [(zero? arity) '(())]
    [else
     (define rest-combos (cartesian-of-arity pool (- arity 1)))
     (for*/list ([x (in-list pool)]
                 [r (in-list rest-combos)])
       (cons x r))]))

;; Attempt to reconstruct via the ctor-desc's reconstruct-fn.
;; Returns the reconstructed value on success, #f on failure.
;; Defensive scaffolding: silently swallows reconstruction errors caused by
;; naive component-type combinations. See file header LIMITATIONS for context.
(define (try-reconstruct desc components)
  (with-handlers ([exn:fail? (lambda (_e) #f)])
    ((ctor-desc-reconstruct-fn desc) components)))
