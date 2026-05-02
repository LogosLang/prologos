#lang racket/base

;; network-emit.rkt — SH Series Track 3 (N-series), Phase N0.
;;
;; Translates a typed AST (post-elaboration, post-zonk) into a *fresh*
;; propagator-network skeleton. The skeleton is the runtime-relevant
;; subset of the program — cells the program needs at run time, plus
;; the propagators that compute between them.
;;
;; SCAFFOLDING (per docs/tracking/2026-05-02_NETWORK_LOWERING_N0.md § 12):
;; the emission pass is a Racket function. It will eventually be subsumed
;; by P-reductions (issue #44), where each reduction rule is itself a
;; registered propagator and the runtime sub-graph emerges naturally as
;; a slice of the elaborator's reduction stratum.
;;
;; CLOSED PASS for the N-tier in scope: any AST node not handled raises
;; (unsupported-network-node node tier hint).

(require racket/match
         "syntax.rkt"
         "global-env.rkt")

(provide emit-program/from-global-env
         (struct-out network-skeleton)
         (struct-out cell-decl)
         (struct-out write-decl)
         (struct-out unsupported-network-node)
         current-network-tier)

(define current-network-tier (make-parameter 0))

;; ============================================================
;; Skeleton data model (N0)
;; ============================================================
;;
;; cells       : Listof cell-decl
;;   each cell-decl carries a stable index (the cell's id at runtime)
;;   plus its source-level info (currently just a hint name).
;; writes      : Listof write-decl
;;   initial constant writes that the lowered binary emits at startup.
;;   N0 only handles writes of constants; N1 introduces propagators.
;; result-cell : Integer
;;   index of the cell whose value is the program's result (main's exit).

(struct network-skeleton (cells writes result-cell) #:transparent)
(struct cell-decl (idx name) #:transparent)
(struct write-decl (idx value) #:transparent)

(struct unsupported-network-node exn:fail (node tier hint) #:transparent)

(define (unsupported! node hint)
  (raise
   (unsupported-network-node
    (format "unsupported network-emission node at tier ~a: ~a (node: ~v)"
            (current-network-tier) hint node)
    (current-continuation-marks)
    node
    (current-network-tier)
    hint)))

;; ============================================================
;; N0 emission
;; ============================================================
;;
;; The only program shape supported in N0 is:
;;   def main : Int := <int-literal>
;; emitted as:
;;   1 cell + 1 constant write
;;   result-cell = 0

(define (emit-program/from-global-env)
  (define type (global-env-lookup-type 'main))
  (define body (global-env-lookup-value 'main))
  (unless type
    (error 'emit-program/from-global-env
           "no top-level definition named 'main' in global env"))
  (case (current-network-tier)
    [(0) (emit-program/n0 type body)]
    [else
     (error 'emit-program/from-global-env
            "tier ~a not yet implemented (N0 only at this commit)"
            (current-network-tier))]))

(define (emit-program/n0 type body)
  (unless (expr-Int? type)
    (unsupported! type "N0 requires `def main : Int`"))
  (define n (extract-int-literal/n0 body))
  (network-skeleton
   (list (cell-decl 0 'main))
   (list (write-decl 0 n))
   0))

(define (extract-int-literal/n0 e)
  (match e
    [(expr-int n)
     (unless (exact-integer? n)
       (unsupported! e "expr-int with non-integer payload"))
     n]
    [(expr-ann inner _) (extract-int-literal/n0 inner)]
    [_
     (unsupported! e
                   "N0 body must reduce to an Int literal (use Tier 1+ AST→LLVM lowering for arithmetic; N1 of network-emit will introduce propagators)")]))
