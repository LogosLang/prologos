#lang racket/base

;; performance-counters.rkt — Deterministic heartbeat counters for benchmarking
;;
;; Inspired by Lean4's heartbeat system. Hardware-independent, deterministic,
;; reproducible. Zero-cost when disabled (parameter check = ~5ns, same as
;; existing current-reduction-fuel pattern in reduction.rkt).
;;
;; IMPORTANT: This module must remain a PURE LEAF — requires only racket/base
;; and json. 8+ source modules require it; any project dependency creates cycles.

(require json
         (for-syntax racket/base))

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
 print-perf-report!

 ;; Phase B: Phase-level timing
 (struct-out phase-timings)
 current-phase-timings
 time-phase!
 phase-timings->hasheq
 print-phase-report!

 ;; Phase D: Memory + GC reporting
 measure-memory-before
 measure-memory-after
 print-memory-report!

 ;; Cell metrics reporting (Track 1 Phase 0b)
 print-cell-metrics-report!

 ;; E3d: Provenance stats
 (struct-out provenance-counters)
 current-provenance-counters
 perf-inc-speculation!
 perf-inc-atms-hypothesis!
 perf-inc-atms-nogood!
 perf-inc-provenance-chain!
 perf-inc-constraint-shadow-mismatch!
 ;; GDE-4: Diagnosis counter
 perf-inc-gde-diagnosis!
 ;; P-U2b: Cell-write consistency counter
 perf-inc-cell-write-mismatch!
 ;; Track 4 Phase 5: Speculation pruning counter
 perf-inc-speculation-pruned!
 provenance-counters->hasheq
 print-provenance-report!)

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

;; ============================================================
;; Phase B: Phase-level timing
;;
;; Accumulates wall-clock milliseconds per pipeline phase.
;; Uses addition (not assignment) because phases are called
;; multiple times per file (e.g., zonk-final for body + type).
;; ============================================================

(struct phase-timings
  (parse-ms
   elaborate-ms
   type-check-ms
   trait-resolve-ms
   qtt-ms
   zonk-ms
   reduce-ms)
  #:mutable #:transparent)

;; Parameter: #f = disabled (default), phase-timings struct = enabled
(define current-phase-timings (make-parameter #f))

;; time-phase! — wrap body in wall-clock timing, accumulate into the named field.
;; Zero-cost when current-phase-timings is #f.
;; Usage: (time-phase! elaborate (elaborate surf))
;;        (time-phase! type-check (infer/err ctx-empty expr))
;;
;; Uses syntax-case + datum matching because the phase names (elaborate, etc.)
;; may be bound identifiers at use sites (e.g., driver.rkt imports elaborate).
(define-syntax (time-phase! stx)
  (syntax-case stx ()
    [(_ phase-name body ...)
     (case (syntax->datum #'phase-name)
       [(parse)         #'(time-phase-impl phase-timings-parse-ms set-phase-timings-parse-ms! body ...)]
       [(elaborate)     #'(time-phase-impl phase-timings-elaborate-ms set-phase-timings-elaborate-ms! body ...)]
       [(type-check)    #'(time-phase-impl phase-timings-type-check-ms set-phase-timings-type-check-ms! body ...)]
       [(trait-resolve) #'(time-phase-impl phase-timings-trait-resolve-ms set-phase-timings-trait-resolve-ms! body ...)]
       [(qtt)           #'(time-phase-impl phase-timings-qtt-ms set-phase-timings-qtt-ms! body ...)]
       [(zonk)          #'(time-phase-impl phase-timings-zonk-ms set-phase-timings-zonk-ms! body ...)]
       [(reduce)        #'(time-phase-impl phase-timings-reduce-ms set-phase-timings-reduce-ms! body ...)]
       [else (raise-syntax-error 'time-phase! "unknown phase name" #'phase-name)])]))

;; Internal helper macro — not exported. Handles the conditional timing + accumulation.
(define-syntax-rule (time-phase-impl getter setter body ...)
  (let ([pt (current-phase-timings)])
    (if pt
        (let* ([t0 (current-inexact-monotonic-milliseconds)]
               [result (begin body ...)]
               [elapsed (- (current-inexact-monotonic-milliseconds) t0)])
          (setter pt (+ (getter pt) elapsed))
          result)
        (begin body ...))))

;; Snapshot to immutable hasheq (for JSON serialization)
(define (phase-timings->hasheq pt)
  (hasheq 'parse_ms       (inexact->exact (round (phase-timings-parse-ms pt)))
          'elaborate_ms   (inexact->exact (round (phase-timings-elaborate-ms pt)))
          'type_check_ms  (inexact->exact (round (phase-timings-type-check-ms pt)))
          'trait_resolve_ms (inexact->exact (round (phase-timings-trait-resolve-ms pt)))
          'qtt_ms         (inexact->exact (round (phase-timings-qtt-ms pt)))
          'zonk_ms        (inexact->exact (round (phase-timings-zonk-ms pt)))
          'reduce_ms      (inexact->exact (round (phase-timings-reduce-ms pt)))))

;; Print structured JSON to stderr for subprocess extraction.
(define (print-phase-report! pt)
  (define h (phase-timings->hasheq pt))
  (eprintf "PHASE-TIMINGS:~a\n" (jsexpr->string h)))

;; ============================================================
;; Phase D: Memory + GC reporting
;;
;; Records memory usage and GC time before/after processing.
;; Forces a major GC before measurement for consistency.
;; ============================================================

;; Snapshot memory state before processing.
;; Returns an opaque hasheq to be passed to measure-memory-after.
(define (measure-memory-before)
  (collect-garbage 'major)
  (hasheq 'mem_bytes (current-memory-use)
          'gc_ms (current-gc-milliseconds)))

;; Compute deltas after processing.
;; Returns a hasheq suitable for JSON serialization.
(define (measure-memory-after before)
  (collect-garbage 'major)
  (define mem-after (current-memory-use))
  (define gc-after (current-gc-milliseconds))
  (hasheq 'mem_before_bytes (hash-ref before 'mem_bytes)
          'mem_after_bytes mem-after
          'mem_retained_bytes (max 0 (- mem-after (hash-ref before 'mem_bytes)))
          'gc_ms (- gc-after (hash-ref before 'gc_ms))))

;; Print MEMORY-STATS:{json} to stderr for subprocess extraction.
(define (print-memory-report! mem-stats)
  (eprintf "MEMORY-STATS:~a\n" (jsexpr->string mem-stats)))

;; ============================================================
;; Track 1 Phase 0b: Cell metrics reporting
;;
;; Emits CELL-METRICS:{json} to stderr for subprocess extraction.
;; The caller (driver.rkt) builds the hasheq from network state;
;; this function just serializes and emits it. Keeps this module
;; as a pure leaf (no propagator.rkt dependency).
;; ============================================================

(define (print-cell-metrics-report! metrics)
  (when metrics
    (eprintf "CELL-METRICS:~a\n" (jsexpr->string metrics))))

;; ============================================================
;; E3d: Provenance stats
;;
;; Counts speculation branches, ATMS hypotheses/nogoods created,
;; and provenance chains emitted. Zero-cost when disabled.
;; ============================================================

(struct provenance-counters
  (speculation-count
   atms-hypothesis-count
   atms-nogood-count
   provenance-chain-count
   constraint-shadow-mismatches   ;; P1-E3b: cell-path vs legacy divergences
   gde-diagnosis-count            ;; GDE-4: diagnoses computed
   cell-write-mismatches          ;; P-U2b: cell value ≠ solution after write
   speculation-pruned-count)      ;; Track 4 Phase 5: branches pruned by learned nogoods
  #:mutable #:transparent)

(define current-provenance-counters (make-parameter #f))

(define-syntax-rule (perf-inc-speculation!)
  (let ([pv (current-provenance-counters)])
    (when pv (set-provenance-counters-speculation-count!
              pv (add1 (provenance-counters-speculation-count pv))))))

(define-syntax-rule (perf-inc-atms-hypothesis!)
  (let ([pv (current-provenance-counters)])
    (when pv (set-provenance-counters-atms-hypothesis-count!
              pv (add1 (provenance-counters-atms-hypothesis-count pv))))))

(define-syntax-rule (perf-inc-atms-nogood!)
  (let ([pv (current-provenance-counters)])
    (when pv (set-provenance-counters-atms-nogood-count!
              pv (add1 (provenance-counters-atms-nogood-count pv))))))

(define-syntax-rule (perf-inc-provenance-chain!)
  (let ([pv (current-provenance-counters)])
    (when pv (set-provenance-counters-provenance-chain-count!
              pv (add1 (provenance-counters-provenance-chain-count pv))))))

(define-syntax-rule (perf-inc-constraint-shadow-mismatch!)
  (let ([pv (current-provenance-counters)])
    (when pv (set-provenance-counters-constraint-shadow-mismatches!
              pv (add1 (provenance-counters-constraint-shadow-mismatches pv))))))

(define-syntax-rule (perf-inc-gde-diagnosis!)
  (let ([pv (current-provenance-counters)])
    (when pv (set-provenance-counters-gde-diagnosis-count!
              pv (add1 (provenance-counters-gde-diagnosis-count pv))))))

(define-syntax-rule (perf-inc-cell-write-mismatch!)
  (let ([pv (current-provenance-counters)])
    (when pv (set-provenance-counters-cell-write-mismatches!
              pv (add1 (provenance-counters-cell-write-mismatches pv))))))

(define-syntax-rule (perf-inc-speculation-pruned!)
  (let ([pv (current-provenance-counters)])
    (when pv (set-provenance-counters-speculation-pruned-count!
              pv (add1 (provenance-counters-speculation-pruned-count pv))))))

(define (provenance-counters->hasheq pv)
  (hasheq 'speculation_count       (provenance-counters-speculation-count pv)
          'atms_hypothesis_count   (provenance-counters-atms-hypothesis-count pv)
          'atms_nogood_count       (provenance-counters-atms-nogood-count pv)
          'provenance_chain_count  (provenance-counters-provenance-chain-count pv)
          'constraint_shadow_mismatches (provenance-counters-constraint-shadow-mismatches pv)
          'gde_diagnosis_count     (provenance-counters-gde-diagnosis-count pv)
          'cell_write_mismatches   (provenance-counters-cell-write-mismatches pv)
          'speculation_pruned_count (provenance-counters-speculation-pruned-count pv)))

(define (print-provenance-report! pv)
  (define h (provenance-counters->hasheq pv))
  (eprintf "PROVENANCE-STATS:~a\n" (jsexpr->string h)))
