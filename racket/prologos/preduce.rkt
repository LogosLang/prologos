#lang racket/base

;;;
;;; preduce.rkt — PReduce-lite, the propagator-network-based reducer
;;;
;;; PM Track 9 first concrete realization. Translates an elaborated
;;; Prologos AST into a propagator network whose run-to-quiescence
;;; produces the WHNF of the input expression.
;;;
;;; Design priority order (load-bearing, see design doc § 1):
;;;   1. Correctness  — produce results equal? to nf for every supported node
;;;   2. Simplicity   — eager optimization explicitly out of scope
;;;   3. Performance  — not a goal of PReduce-lite; full Track 9 closes the gap
;;;
;;; "Lite" means: no incrementality, no e-graph merges, no equality
;;; saturation, no speculative reduction, no tropical-quantale fuel.
;;; The cell-value lattice is the simplest possible (discrete with bot);
;;; each cell is written once.
;;;
;;; Phased rollout: 16 phases covering the full reducer surface.
;;;   Phase 1 (THIS): skeleton — lattice, domain registration, parameters,
;;;                   error type, compile-expr dispatcher, opaque-value
;;;                   rule for type-formers, top-level entry points.
;;;                   No reduction-active AST cases yet.
;;;   Phase 2+:       reduction cases land per the design doc's tracker.
;;;
;;; Out-of-scope nodes raise exn:fail:preduce-unsupported (hard error,
;;; per the correctness-favoring policy in design doc § 3 + § 8.5).
;;; The diagnostic `(preduce-or-nf e)` helper catches and dispatches
;;; to nf for exploratory REPL use only — never wired into typing-core.
;;;
;;; Cross-references:
;;;   - docs/tracking/2026-05-02_PREDUCE_LITE_DESIGN.md (this design)
;;;   - docs/tracking/2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md (origin)
;;;   - racket/prologos/reduction.rkt (the existing tree-walker we eventually replace)
;;;

(require racket/match
         "syntax.rkt"
         (only-in "propagator.rkt"
                  make-prop-network
                  net-new-cell
                  net-cell-read
                  net-cell-write
                  net-add-propagator
                  net-add-fire-once-propagator
                  run-to-quiescence)
         (only-in "sre-core.rkt" make-sre-domain register-domain!)
         (only-in "merge-fn-registry.rkt" register-merge-fn!/lattice)
         (only-in "reduction.rkt" nf))  ;; for preduce-or-nf diagnostic helper

(provide
 ;; Entry points
 preduce
 preduce-or-nf

 ;; Parameters
 current-use-preduce?
 current-preduce-fuel

 ;; Errors
 (struct-out exn:fail:preduce-unsupported)
 preduce-unsupported-node-error?

 ;; Lattice
 preduce-bot
 preduce-top
 preduce-bot?
 preduce-top?
 preduce-merge

 ;; Domain (for cross-module references in tests)
 preduce-value-domain)

;; ============================================================
;; Discrete value lattice
;; ============================================================
;;
;; Lattice: ⊥  →  any value (incomparable)  →  ⊤
;; Merge:   first write sets the value; subsequent equal writes are
;;          idempotent; subsequent unequal writes produce ⊤
;;          (contradiction — indicates a bug or non-deterministic input).
;; Bot:     'preduce-bot — sentinel for "cell not yet computed."
;; Top:     'preduce-top — sentinel for "contradiction."
;;
;; This is the simplest valid join-semilattice for the use case:
;; deterministic reduction means every cell is written at most once,
;; so the lattice is essentially "uninitialized memory that, once set,
;; stays." The e-graph generalization (full Track 9) replaces this
;; with a richer lattice supporting equivalence merges.

(define preduce-bot 'preduce-bot)
(define preduce-top 'preduce-top)

(define (preduce-bot? v) (eq? v preduce-bot))
(define (preduce-top? v) (eq? v preduce-top))

(define (preduce-merge a b)
  (cond
    [(eq? a preduce-bot) b]
    [(eq? b preduce-bot) a]
    [(eq? a preduce-top) preduce-top]
    [(eq? b preduce-top) preduce-top]
    [(equal? a b) a]
    [else preduce-top]))

;; ============================================================
;; SRE domain registration
;; ============================================================

(define preduce-value-domain
  (make-sre-domain
   #:name 'preduce-value
   #:merge-registry (lambda (r)
                      (case r
                        [(equality) preduce-merge]
                        [else (error 'preduce-value-merge
                                     "no merge for relation: ~a" r)]))
   #:contradicts? preduce-top?
   #:bot? preduce-bot?
   #:bot-value preduce-bot
   #:classification 'value))

(register-domain! preduce-value-domain)
(register-merge-fn!/lattice preduce-merge #:for-domain 'preduce-value)

;; ============================================================
;; Parameters
;; ============================================================

;; Default #f: the existing nf path is unchanged. Phase 16 flips this
;; to #t after the full-coverage differential gate (Phase 15) passes.
(define current-use-preduce? (make-parameter #f))

;; Imperative fuel counter (named scaffolding; tropical-lattice fuel
;; per PPN 4C M2 is the v2 retirement target). Bounds the number of
;; topology operations / propagator firings before bailing out.
(define current-preduce-fuel (make-parameter 1000000))

;; ============================================================
;; Error type
;; ============================================================

(struct exn:fail:preduce-unsupported exn:fail (node-kind phase)
  #:extra-constructor-name make-preduce-unsupported
  #:transparent)

(define (preduce-unsupported-node-error? v)
  (exn:fail:preduce-unsupported? v))

(define (raise-unsupported! node-kind phase msg)
  (raise (make-preduce-unsupported
          msg
          (current-continuation-marks)
          node-kind phase)))

(define (expr-kind e)
  ;; struct->vector on (expr-int 5) returns #(struct:expr-int 5),
  ;; so the first element is the symbol 'struct:expr-int. Strip the
  ;; "struct:" prefix for a clean error-message identifier.
  (cond
    [(struct? e)
     (define v (struct->vector e))
     (define tag (vector-ref v 0))
     (define s (symbol->string tag))
     (if (regexp-match? #rx"^struct:" s)
         (string->symbol (substring s 7))
         tag)]
    [else 'non-struct]))

;; ============================================================
;; compile-expr — translation
;; ============================================================
;;
;; compile-expr : expr × env × net → (values cell-id net)
;;
;; env : (Listof cell-id), innermost-first per de Bruijn convention.
;;       (expr-bvar 0) reads (list-ref env 0); the outermost binder
;;       has the highest bvar index.
;;
;; net : the prop-network being built (immutable; threaded through).
;;
;; Returns: (values result-cid net') — result-cid's value (after
;;          run-to-quiescence) is the WHNF of expr.
;;
;; Phase 1: handles only the opaque-value rule (type formers and
;; nullary type atoms held as values). All other nodes raise
;; exn:fail:preduce-unsupported.

(define (compile-expr e env net)
  (match e
    ;; ----- Phase 1 opaque-value rule -----
    ;;
    ;; Type formers and nullary type atoms reduce to themselves. We
    ;; allocate a cell whose initial value IS the AST node, no
    ;; propagator needed. Subsequent reads find the value already in
    ;; place at WHNF.
    [(or (? expr-Pi?) (? expr-Sigma?) (? expr-Type?)
         (? expr-Vec?) (? expr-Eq?) (? expr-Fin?)
         (? expr-Nat?) (? expr-Int?) (? expr-Rat?)
         (? expr-Bool?) (? expr-String?) (? expr-Char?)
         (? expr-Keyword?) (? expr-Symbol?) (? expr-Path?)
         (? expr-Unit?) (? expr-Nil?))
     (alloc-value-cell net e)]

    ;; ----- All other nodes: deferred to later phases -----
    [_
     (raise-unsupported!
      (expr-kind e)
      'phase-2-or-later
      (format "PReduce-lite Phase 1: AST node ~a is not yet supported. \
Programs using this node should run via the existing nf reducer until \
the relevant phase lands."
              (expr-kind e)))]))

;; Allocate a fresh cell with the given value as its initial state.
;; Returns (values cid net'). Used by Phase 1's opaque-value rule and
;; by Phase 2's literal cases.
(define (alloc-value-cell net value)
  (define-values (net* cid)
    (net-new-cell net value preduce-merge #:domain 'preduce-value))
  (values cid net*))

;; ============================================================
;; Top-level entry points
;; ============================================================

;; preduce : expr → expr
;;   Reduce expr to WHNF via the propagator network.
;;   Raises exn:fail:preduce-unsupported if expr contains nodes not
;;   yet covered by the current phase.
(define (preduce expr)
  (define net0 (make-prop-network (current-preduce-fuel)))
  (define-values (result-cid net1) (compile-expr expr '() net0))
  (define net-final (run-to-quiescence net1))
  (define result-value (net-cell-read net-final result-cid))
  (cond
    [(preduce-bot? result-value)
     (error 'preduce
            "result cell unfilled — fire functions did not produce a value")]
    [(preduce-top? result-value)
     (error 'preduce
            "contradiction in result cell — non-deterministic input or bug")]
    [else result-value]))

;; preduce-or-nf : expr → expr
;;   Diagnostic helper for exploratory REPL use ONLY. Catches the
;;   unsupported-node error and dispatches to the existing nf reducer.
;;   NEVER wire this into typing-core or the test suite — that re-
;;   introduces the graceful-degradation correctness traps the design
;;   doc § 12 VAG explicitly rejects.
(define (preduce-or-nf expr)
  (with-handlers ([preduce-unsupported-node-error?
                   (lambda (_) (nf expr))])
    (preduce expr)))
