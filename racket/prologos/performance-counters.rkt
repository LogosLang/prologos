#lang racket/base

;; performance-counters.rkt — Deterministic heartbeat counters for benchmarking
;;
;; Inspired by Lean4's heartbeat system. Hardware-independent, deterministic,
;; reproducible. Zero-cost when disabled (parameter check = ~5ns, same as
;; existing current-reduction-fuel pattern in reduction.rkt).
;;
;; IMPORTANT: This module must remain a PURE LEAF — requires only racket/base
;; and json. 8+ source modules require it; any project dependency creates cycles.

(require json)

(provide
 ;; Counter struct + parameter
 (struct-out perf-counters)
 current-perf-counters

 ;; 12 concrete increment macros (zero-cost when current-perf-counters = #f)
 perf-inc-unify!
 perf-inc-reduce!
 perf-inc-elaborate!
 perf-inc-infer!
 perf-inc-trait-resolve!
 perf-inc-meta-created!
 perf-inc-meta-solved!
 perf-inc-constraint!
 perf-inc-constraint-retry!
 perf-inc-solver-backtrack!
 perf-inc-solver-unify!
 perf-inc-zonk!

 ;; Lifecycle
 with-perf-counters
 perf-counters-reset!
 perf-counters->hasheq

 ;; Subprocess reporting
 print-perf-report!)

;; ============================================================
;; Counter struct: 12 mutable fields
;; ============================================================

(struct perf-counters
  (unify-steps
   reduce-steps
   elaborate-steps
   infer-steps
   trait-resolve-steps
   meta-created
   meta-solved
   constraint-count
   constraint-retries
   solver-backtracks
   solver-unifies
   zonk-steps)
  #:mutable #:transparent)

;; Parameter: #f = disabled (default), perf-counters struct = enabled
(define current-perf-counters (make-parameter #f))

;; ============================================================
;; Concrete increment macros
;;
;; Each expands to: check parameter → when non-#f → mutate specific field.
;; Using concrete macros avoids the need for runtime struct reflection.
;; The (when pc ...) pattern matches the existing fuel check in reduction.rkt.
;; ============================================================

(define-syntax-rule (perf-inc-unify!)
  (let ([pc (current-perf-counters)])
    (when pc (set-perf-counters-unify-steps! pc (add1 (perf-counters-unify-steps pc))))))

(define-syntax-rule (perf-inc-reduce!)
  (let ([pc (current-perf-counters)])
    (when pc (set-perf-counters-reduce-steps! pc (add1 (perf-counters-reduce-steps pc))))))

(define-syntax-rule (perf-inc-elaborate!)
  (let ([pc (current-perf-counters)])
    (when pc (set-perf-counters-elaborate-steps! pc (add1 (perf-counters-elaborate-steps pc))))))

(define-syntax-rule (perf-inc-infer!)
  (let ([pc (current-perf-counters)])
    (when pc (set-perf-counters-infer-steps! pc (add1 (perf-counters-infer-steps pc))))))

(define-syntax-rule (perf-inc-trait-resolve!)
  (let ([pc (current-perf-counters)])
    (when pc (set-perf-counters-trait-resolve-steps! pc (add1 (perf-counters-trait-resolve-steps pc))))))

(define-syntax-rule (perf-inc-meta-created!)
  (let ([pc (current-perf-counters)])
    (when pc (set-perf-counters-meta-created! pc (add1 (perf-counters-meta-created pc))))))

(define-syntax-rule (perf-inc-meta-solved!)
  (let ([pc (current-perf-counters)])
    (when pc (set-perf-counters-meta-solved! pc (add1 (perf-counters-meta-solved pc))))))

(define-syntax-rule (perf-inc-constraint!)
  (let ([pc (current-perf-counters)])
    (when pc (set-perf-counters-constraint-count! pc (add1 (perf-counters-constraint-count pc))))))

(define-syntax-rule (perf-inc-constraint-retry!)
  (let ([pc (current-perf-counters)])
    (when pc (set-perf-counters-constraint-retries! pc (add1 (perf-counters-constraint-retries pc))))))

(define-syntax-rule (perf-inc-solver-backtrack!)
  (let ([pc (current-perf-counters)])
    (when pc (set-perf-counters-solver-backtracks! pc (add1 (perf-counters-solver-backtracks pc))))))

(define-syntax-rule (perf-inc-solver-unify!)
  (let ([pc (current-perf-counters)])
    (when pc (set-perf-counters-solver-unifies! pc (add1 (perf-counters-solver-unifies pc))))))

(define-syntax-rule (perf-inc-zonk!)
  (let ([pc (current-perf-counters)])
    (when pc (set-perf-counters-zonk-steps! pc (add1 (perf-counters-zonk-steps pc))))))

;; ============================================================
;; Lifecycle
;; ============================================================

;; with-perf-counters: set up fresh counters, run body, return (values result pc)
(define-syntax-rule (with-perf-counters body ...)
  (let ([pc (perf-counters 0 0 0 0 0 0 0 0 0 0 0 0)])
    (parameterize ([current-perf-counters pc])
      (let ([result (begin body ...)])
        (values result pc)))))

;; Reset all counters to zero
(define (perf-counters-reset! pc)
  (set-perf-counters-unify-steps! pc 0)
  (set-perf-counters-reduce-steps! pc 0)
  (set-perf-counters-elaborate-steps! pc 0)
  (set-perf-counters-infer-steps! pc 0)
  (set-perf-counters-trait-resolve-steps! pc 0)
  (set-perf-counters-meta-created! pc 0)
  (set-perf-counters-meta-solved! pc 0)
  (set-perf-counters-constraint-count! pc 0)
  (set-perf-counters-constraint-retries! pc 0)
  (set-perf-counters-solver-backtracks! pc 0)
  (set-perf-counters-solver-unifies! pc 0)
  (set-perf-counters-zonk-steps! pc 0))

;; Snapshot to immutable hasheq (for JSON serialization)
(define (perf-counters->hasheq pc)
  (hasheq 'unify_steps       (perf-counters-unify-steps pc)
          'reduce_steps      (perf-counters-reduce-steps pc)
          'elaborate_steps   (perf-counters-elaborate-steps pc)
          'infer_steps       (perf-counters-infer-steps pc)
          'trait_resolve_steps (perf-counters-trait-resolve-steps pc)
          'meta_created      (perf-counters-meta-created pc)
          'meta_solved       (perf-counters-meta-solved pc)
          'constraint_count  (perf-counters-constraint-count pc)
          'constraint_retries (perf-counters-constraint-retries pc)
          'solver_backtracks (perf-counters-solver-backtracks pc)
          'solver_unifies    (perf-counters-solver-unifies pc)
          'zonk_steps        (perf-counters-zonk-steps pc)))

;; ============================================================
;; Subprocess reporting
;; ============================================================

;; Print structured JSON to stderr with prefix for extraction by bench-lib.rkt.
;; The benchmark runner scans stderr for "PERF-COUNTERS:" and parses the JSON.
(define (print-perf-report! pc)
  (define h (perf-counters->hasheq pc))
  (eprintf "PERF-COUNTERS:~a\n" (jsexpr->string h)))
