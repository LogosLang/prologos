#lang racket/base

;;; sre-sample-generator.rkt — Per-component-spec sample generator
;;;
;;; SRE Track 2I.
;;;   Phase 2  (commit f241e14e): initial generator + sd-evidence struct.
;;;   Phase 2a (this version):    Option C — per-component-spec generation,
;;;     drop with-handlers / silent-skip patterns (correct-by-construction),
;;;     include binder ctors with closed-body limitation.
;;;
;;; ARCHITECTURE — DATA-DRIVEN BY ctor-desc-component-lattices
;;;
;;; Each ctor-desc declares per-component lattice-specs:
;;;   - 'type sentinel    → component must be a type-shaped value
;;;   - 'session sentinel → component must be a session-shaped value
;;;   - mult-lattice-spec → component must be a multiplicity (m0, m1, mw)
;;;   - term-lattice-spec → component must be a term-shaped value
;;;
;;; The generator builds an `atoms-by-spec` hash mapping each spec to a pool
;;; of valid inhabitants. For each ctor at depth d, it draws each component
;;; slot from the pool for that slot's spec, Cartesian-products the slots,
;;; and reconstructs. Reconstruction is GUARANTEED to succeed because each
;;; component is valid for its slot's lattice-spec by construction. No
;;; with-handlers needed; no silent skip.
;;;
;;; This is the principled response to the codified red-flag pattern from
;;; PPN 4C S2.c-iii drift (workflow.md:56, DEVELOPMENT_LESSONS.org §1102):
;;; defensive `with-handlers` masks a structural issue rather than fixing it,
;;; ships shape without benefit. The Move B+ corrective pattern (S2.c-iii
;;; commit c86596e0) is the precedent for separate corrective sub-phases
;;; that drop defensive scaffolding and capture the principled benefit.
;;;
;;; LIMITATIONS:
;;; - Binder ctors (Pi, Sigma, lam) are generated with CLOSED BODIES — the
;;;   under-binder slot is filled with a closed type (no expr-bvar
;;;   references). These are valid non-dependent function/pair/lambda types,
;;;   not the full set of dependent variants. Dependent-type generation
;;;   would require populating the type pool with bvar-bearing values
;;;   conditionally on slot context — deferred to a future phase.
;;; - Domains beyond type get only their own pool initialized; cross-domain
;;;   ctors (none currently in type domain post-binder-inclusion) are not
;;;   reachable. Per-domain generator extension is straightforward by
;;;   adding entries to atoms-by-spec.

(require racket/list)
(require "ctor-registry.rkt")
(require "sre-core.rkt")

(provide generate-domain-samples)

;; ========================================================================
;; Multiplicity Pool
;; ========================================================================
;; The three QTT multiplicities (per CLAUDE.md glossary). Atomic symbols;
;; no struct construction needed.

(define mult-pool '(mw m1 m0))

;; ========================================================================
;; Sample Generation
;; ========================================================================

;; Generate a list of representative values for a domain's ctor-desc registry.
;;
;; Per-component-spec architecture (Option C, Phase 2a):
;;   - Build depth-0 atom pool from bot/top + base-values + nullary ctors.
;;   - For each depth d > 0: build atoms-by-spec hash, then for each ctor
;;     draw each component slot from the pool for that slot's lattice-spec
;;     and Cartesian-product the slots.
;;   - Reconstruction is correct-by-construction; no with-handlers.
;;
;; #:max-depth      — max constructor nesting depth (default 2)
;; #:per-ctor-count — components per slot in Cartesian product (default 2).
;;                    For arity N, gives per-ctor-count^N inhabitants per ctor
;;                    per depth.
;; #:include-bot-top — include bot-value and top-value at depth 0 (default #t)
;; #:base-values    — optional list of pre-built atomic samples.
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
  ;; Depth d > 0: per-component-spec compound generation
  ;; ----------------------------------------------------------------------
  (define samples-by-depth
    (for/fold ([acc (list depth-0-atoms)])
              ([d (in-range 1 (+ max-depth 1))])
      (define prev-samples (last acc))
      (define atoms-by-spec
        (build-atoms-by-spec prev-samples per-ctor-count domain))
      (define new-samples
        (compound-ctor-inhabitants ctor-descs atoms-by-spec))
      (append acc (list (remove-duplicates new-samples)))))

  (remove-duplicates (apply append samples-by-depth)))

;; ========================================================================
;; Per-Component-Spec Pool Construction
;; ========================================================================

;; Build the atoms-by-spec hash: lattice-spec → pool of valid component values.
;;
;; Keys are heterogeneous (sentinel symbols + concrete lattice-spec structs).
;; We use a hash with equal? semantics to handle both uniformly.
;;
;; TWO-POOL DISTINCTION (Phase 2a finding, surfaced after dropping with-handlers):
;;   - The full-pool (depth-d-1 samples) includes lattice SENTINELS (bot/top).
;;     These are valid lattice ELEMENTS — they participate in merge / SD checks.
;;   - But sentinels are NOT valid STRUCTURAL COMPONENTS — feeding them into
;;     `(expr-Pi mw type-top type-top)` etc. produces malformed values that
;;     the merge functions' match-dispatch doesn't handle.
;;
;; Phase 2 masked this with `with-handlers` (silently skipping the resulting
;; reconstruct/merge failures). Phase 2a surfaces it: filter sentinels out of
;; component pools before feeding to ctor reconstruction. Compound types
;; produced this way are well-formed structurally and well-behaved under
;; merge.
;;
;; For Phase 2a's type-domain scope:
;;   - 'type sentinel    → component pool excluding lattice sentinels
;;   - mult-lattice-spec → the multiplicity pool (capped)
;;
;; To extend for other domains:
;;   - Add an entry mapping 'session, term-lattice-spec, etc. to its
;;     domain-appropriate non-sentinel pool. The compound-ctor-inhabitants
;;     function uses the hash uniformly.
(define (build-atoms-by-spec full-pool per-ctor-count domain)
  (define bot (sre-domain-bot-value domain))
  (define top (sre-domain-top-value domain))
  (define non-sentinel-pool
    (filter (lambda (v) (and (not (equal? v bot))
                             (not (equal? v top))))
            full-pool))
  (hash 'type            (take-up-to non-sentinel-pool per-ctor-count)
        'session         (take-up-to non-sentinel-pool per-ctor-count)
        mult-lattice-spec (take-up-to mult-pool per-ctor-count)))

;; ========================================================================
;; Compound Inhabitant Reconstruction
;; ========================================================================

;; Reconstruct compound inhabitants per ctor by drawing each slot from the
;; pool for that slot's component-lattice-spec.
;;
;; Includes binder ctors (binder-depth > 0) — for non-dependent variants
;; (closed bodies that don't reference the bound parameter via expr-bvar).
;; This is a documented limitation; dependent-type generation requires
;; bvar-bearing components conditionally on slot context.
(define (compound-ctor-inhabitants ctor-descs atoms-by-spec)
  (for/fold ([acc '()])
            ([desc (in-list ctor-descs)]
             #:when (positive? (ctor-desc-arity desc)))
    (define slot-pools
      (for/list ([spec (in-list (ctor-desc-component-lattices desc))])
        (hash-ref atoms-by-spec spec '())))
    ;; If any slot-pool is empty, cartesian-of-slots returns '() — no
    ;; inhabitants generated for this ctor. This is structurally correct:
    ;; we have no way to fill that slot.
    (for/fold ([acc2 acc])
              ([combo (in-list (cartesian-of-slots slot-pools))])
      (cons ((ctor-desc-reconstruct-fn desc) combo) acc2))))

;; Reconstruct nullary ctor inhabitants. Nullary ctors take no components,
;; so reconstruction always succeeds.
(define (nullary-ctor-inhabitants ctor-descs)
  (for/list ([desc (in-list ctor-descs)]
             #:when (zero? (ctor-desc-arity desc)))
    ((ctor-desc-reconstruct-fn desc) '())))

;; ========================================================================
;; Helpers
;; ========================================================================

;; Take up to n elements from xs.
(define (take-up-to xs n)
  (cond
    [(<= n 0) '()]
    [(null? xs) '()]
    [else (cons (car xs) (take-up-to (cdr xs) (- n 1)))]))

;; Cartesian product across a list of per-slot pools (heterogeneous lengths).
;;   '() slot-pools         → '(())  — single empty combination
;;   '(x) slot-pools        → '((x1) (x2) ...) — each x in pool[0]
;;   '(x y) slot-pools      → '((x1 y1) (x1 y2) ... (x2 y1) ...) — Cartesian
;;
;; If ANY slot-pool is empty, the result is '() — no inhabitants reachable
;; with at least one un-fillable slot. Structurally correct.
(define (cartesian-of-slots slot-pools)
  (cond
    [(null? slot-pools) '(())]
    [(null? (car slot-pools)) '()]
    [else
     (define rest-combos (cartesian-of-slots (cdr slot-pools)))
     (for*/list ([x (in-list (car slot-pools))]
                 [r (in-list rest-combos)])
       (cons x r))]))
