#lang racket/base

;;;
;;; error-explanation.rkt — PPN 4C Addendum Phase 3C.a foundation
;;;
;;; On-network static-walk over the propagator-firing dependency graph,
;;; producing structured derivation chains for diagnostic error reporting.
;;;
;;; CONTEXT (per §9.5.1 mini-design + §9.5.2 3C.a mini-design):
;;;   First user-facing instance of Propagator-First Diagnostics (vision-
;;;   forward framing; watching-list codification candidate, graduates at
;;;   Phase 11b second consumer). Phase 3C.a delivers the FOUNDATION
;;;   primitive + structs; sub-phases 3C.b/c/d consume this foundation
;;;   for union-contradict + union-check + format integration.
;;;
;;; ARCHITECTURE:
;;;   `static-reverse-walk` is a READ-TIME function over on-network state
;;;   (NOT a propagator). It reads:
;;;     - `propagator.outputs` / `propagator.inputs` (struct accessors)
;;;     - `propagator.srcloc` (Phase 1.5 srcloc infrastructure)
;;;     - `tagged-cell-value.entries` (BSP-LE Track 2B substrate)
;;;   No `current-bsp-observer` activation — preserves
;;;   Cell/Propagator/Scheduler Orthogonality (DESIGN_PRINCIPLES.org).
;;;
;;; DECOMPLECTION:
;;;   This module performs GRAPH WALK + STEP DECORATION only. The
;;;   `assumption-names` (string decoding via solver-state-assumptions)
;;;   and `residual-cost` (tropical-quantale annotation) are CONSUMER
;;;   responsibilities (Phase 3C.b/c wrappers). Primitive returns steps
;;;   with `assumption-names = '()` and `residual-cost = #f`.
;;;
;;; FORWARD CONSUMERS (per §9.5.1.7 cross-track captures):
;;;   - Phase 11b general derivation-chain-for(position, tag)
;;;   - PPN Track 8 LSP integration (transparent struct serialization)
;;;   - SH Series Track 1 (.pnet IR includes chain shape)
;;;   - SH Series Track 4 (LHC runtime diagnostic primitive)
;;;   - PReduce Track 6 speculative-reduction errors
;;;
;;; LOCKED design decisions (per §9.5.2.2):
;;;   Q-A.1 Signature with #:max-depth + #:filter-fn kwargs
;;;   Q-A.2 5-field derivation-step (no input/output cell-ids stored)
;;;   Q-A.3 Single-layer decorated walk (no two-layer raw/decorate split)
;;;   Q-A.4 Cycle detection + #:max-depth 32 (Phase 3A 30-bit budget + 2)
;;;   Q-A.5 DFS pre-order cons-onto-head; natural order = causal reading
;;;   Q-A.6 Aids from cell's tagged-entries UNION at walk time
;;;   Q-A.7 Single atomic 3C.a commit

(require racket/list
         "atms.rkt"           ;; assumption-id struct
         "champ.rkt"          ;; champ-fold + champ-lookup
         "decision-cell.rkt"  ;; tagged-cell-value accessors
         "propagator.rkt")    ;; prop-network + propagator + net-cell-read-raw + prop-id-hash

(provide
 ;; Core data types (transparent; LSP-ready; forward-compat with field
 ;; additions per Q-A.8 — field-semantics changes treated as breaking)
 (struct-out derivation-chain)
 (struct-out derivation-step)
 ;; Static graph-walk primitive (load-bearing for Phase 11b + LSP + LHC
 ;; per §9.5.1.7 Propagator-First Diagnostics framing; pre-export with
 ;; codification-graduation discipline — codifies as Cross-Track Template
 ;; at Phase 11b second consumer per Specialized Cell Type Framework precedent)
 static-reverse-walk)

;; ============================================================
;; Core data types (§9.5.2.2 Q-A.2)
;; ============================================================

;; A derivation chain is a sequence of steps describing how a cell's
;; contradicting state arose through propagator firings. Steps are in
;; CAUSAL READING ORDER: deepest cause first (head of list) → symptom
;; last (tail). Consumers wrap this struct in error structures
;; (e.g., union-exhaustion-error.derivation-chain field) per §9.5.1.4.
(struct derivation-chain (steps) #:transparent)

;; A single step in the derivation chain represents one propagator's
;; participation in producing the contradicting cell's state.
;;
;; Field semantics:
;;   propagator-id   — prop-id of the participating propagator (always non-#f)
;;   srcloc          — install-time srcloc, or #f for propagators installed
;;                     without explicit #:srcloc kwarg (graceful degradation
;;                     per D-3C-7); see Phase 1.5 srcloc infrastructure
;;   assumption-ids  — (listof assumption-id) — aids the OUTPUT cell was
;;                     tagged with at walk time (per Q-A.6 documented
;;                     attribution); '() if cell is untagged
;;   assumption-names — (listof string) — primitive sets '(); CONSUMER
;;                     enriches via solver-state-assumptions lookup
;;   residual-cost   — exact-nonnegative-integer | #f — primitive sets #f;
;;                     CONSUMER may populate via tropical-left-residual
(struct derivation-step
  (propagator-id
   srcloc
   assumption-ids
   assumption-names
   residual-cost)
  #:transparent)

;; ============================================================
;; Internal helpers
;; ============================================================

;; Build reverse-index: cell-id → (listof prop-id) for propagators that
;; output to each cell. O(N) where N = total propagator count in net.
;; Returns mutable hasheq for fast lookup during recursion.
(define (build-reverse-index net)
  (define ht (make-hasheq))
  (define props (prop-network-propagators net))
  (champ-fold
   props
   (lambda (pid prop _)
     (for ([out-cid (in-list (propagator-outputs prop))])
       (hash-update! ht out-cid
                     (lambda (pids) (cons pid pids))
                     '()))
     #f)
   #f)
  ht)

;; Decode assumption-ids from tagged-cell-value entries. Returns '() for
;; non-tagged values. Iterates bit positions 0-29 (Phase 3A's 30-bit
;; budget envelope; D-3C-8). Per Q-A.6: aids are UNION across all entries
;; at the cell — not per-propagator-write attribution.
(define (decode-aids-from-cell-value cell-val)
  (cond
    [(tagged-cell-value? cell-val)
     (define entries (tagged-cell-value-entries cell-val))
     (define combined-bm
       (for/fold ([acc 0])
                 ([entry (in-list entries)])
         (bitwise-ior acc (car entry))))
     (for/list ([i (in-range 30)]
                #:when (bitwise-bit-set? combined-bm i))
       (assumption-id i))]
    [else '()]))

;; Decode a single step from (net, prop-id, propagator, cell-id).
;; Primitive sets assumption-names='() and residual-cost=#f per Q-A.2;
;; consumer enriches at higher layer.
(define (decode-step net pid prop output-cid)
  (define srcloc (propagator-srcloc prop))
  (define cell-val (net-cell-read-raw net output-cid))
  (define aids (decode-aids-from-cell-value cell-val))
  (derivation-step pid srcloc aids '() #f))

;; ============================================================
;; static-reverse-walk — public API (§9.5.2.2 Q-A.1)
;; ============================================================

;; Walk backward through the propagator-firing dependency graph from a
;; contradicting cell, producing a derivation chain in causal reading order
;; (deepest cause first; symptom last).
;;
;; Inputs:
;;   net       — prop-network (current network state)
;;   cell-id   — cell-id where the contradicting state landed (start of walk)
;;
;; Keyword arguments:
;;   #:max-depth N        — depth bound (default 32; matches Phase 3A's
;;                          30-bit assumption budget + 2 headroom per Q-A.4)
;;   #:filter-fn (step → bool)
;;                        — predicate applied to each decoded step;
;;                          step is included in chain only if predicate
;;                          returns #t (default: include all)
;;
;; Returns: derivation-chain with steps in causal reading order.
;;
;; Walk semantics:
;;   - DFS pre-order traversal from cell-id via cell→writers index
;;   - Each propagator visited AT MOST ONCE (cycle detection via prop-id
;;     visited set; D-3C.a-2 + Q-A.4)
;;   - When max-depth reached, that branch terminates; siblings continue
;;   - Steps cons'd onto accumulator: causal-reading-order falls out from
;;     cons-onto-head DFS (Q-A.5)
;;
;; Mantra alignment (per §9.5.2 mini-audit):
;;   - all-at-once: ONE walk per call ✓
;;   - all-in-parallel: read-time function (sequential by design; N/A) ✓
;;   - structurally emergent: chain emerges from on-network graph structure ✓
;;   - information flow: through cells (reads net-cell-read-raw +
;;     propagator-outputs/-inputs/-srcloc) ✓
;;   - on-network: derived view over on-network primary state (that-read analog) ✓
;;
;; Preserves Cell/Propagator/Scheduler Orthogonality (DESIGN_PRINCIPLES.org):
;;   NO `current-bsp-observer` activation; NO scheduler coupling; purely
;;   read-time over static on-network state.
(define (static-reverse-walk net cell-id
                              #:max-depth [max-depth 32]
                              #:filter-fn [filter-fn (lambda (step) #t)])
  (define cell→writers (build-reverse-index net))
  (define props (prop-network-propagators net))
  (define visited (make-hasheq))  ;; prop-id → #t
  (define collected (box '()))    ;; cons-onto-head; natural order = causal-reading
  (define (visit cid depth)
    (cond
      [(>= depth max-depth) (void)]
      [else
       (define writers (hash-ref cell→writers cid '()))
       (for ([pid (in-list writers)]
             #:when (not (hash-ref visited pid #f)))
         (hash-set! visited pid #t)
         (define prop (champ-lookup props (prop-id-hash pid) pid))
         (define step (decode-step net pid prop cid))
         (when (filter-fn step)
           (set-box! collected (cons step (unbox collected)))
           (for ([input-cid (in-list (propagator-inputs prop))])
             (visit input-cid (+ depth 1)))))]))
  (visit cell-id 0)
  ;; Natural order from cons-onto-head DFS pre-order = causal reading
  ;; order (deepest cause first, symptom last) per Q-A.5
  (derivation-chain (unbox collected)))
