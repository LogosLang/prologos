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
         racket/set                       ;; set-member? (Phase 3C.b.3)
         "atms.rkt"                       ;; assumption-id + assumption + solver-state-assumptions
         "champ.rkt"                      ;; champ-fold + champ-lookup
         "decision-cell.rkt"              ;; tagged-cell-value accessors
         "derivation-chain-types.rkt"     ;; derivation-chain + derivation-step structs (3C.c.3 cycle break)
         "elab-speculation-bridge.rkt"    ;; current-command-atms (Phase 3C.b.3)
         "propagator.rkt")                ;; prop-network + propagator + net-cell-read-raw + prop-id-hash

(provide
 ;; Core data types (transparent; LSP-ready; forward-compat with field
 ;; additions per Q-A.8 — field-semantics changes treated as breaking)
 (struct-out derivation-chain)
 (struct-out derivation-step)
 ;; Static graph-walk primitive (load-bearing for Phase 11b + LSP + LHC
 ;; per §9.5.1.7 Propagator-First Diagnostics framing; pre-export with
 ;; codification-graduation discipline — codifies as Cross-Track Template
 ;; at Phase 11b second consumer per Specialized Cell Type Framework precedent)
 static-reverse-walk
 ;; PPN 4C Phase 3C.b.3 (2026-05-23): union-contradict consumer wrapper.
 ;; First downstream consumer of static-reverse-walk per Propagator-First
 ;; Diagnostics framing. Phase 3C.c bridges from check/err to populate
 ;; union-exhaustion-error.derivation-chain; Phase 11b extends the wrapper
 ;; pattern to general derivation diagnostics.
 derivation-chain-for/union-contradict
 ;; PPN 4C Phase 3C.c.1 (2026-05-24): sexp-mode translator wrapper.
 ;; Direct parallel to retired build-derivation-chain (typing-errors.rkt:127);
 ;; takes sub-failures list, returns derivation-chain struct. SEXP-MODE
 ;; SCAFFOLDING — retires at Track 4D when sexp typing unifies on-network.
 ;; Per §9.5.4.5.1 audit lock (α): sub-failures input matches retired function
 ;; shape; atomic Q6.x UX unchanged (chain empty); richness inherits structurally
 ;; for nested scenarios.
 derivation-chain-for/union-check)

;; ============================================================
;; Core data types (§9.5.2.2 Q-A.2)
;; ============================================================
;;
;; PPN 4C 3C.c.3 (2026-05-24): structs RELOCATED to derivation-chain-types.rkt
;; (leaf module) to break a require cycle with errors.rkt (which needs the
;; struct accessors for format-error's union-exhaustion-error case). Backward
;; compatibility preserved: structs still EXPORTED from this module via
;; (struct-out ...) in the provide block above. Existing consumers don't need
;; to change their require shape.

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

;; ============================================================
;; PPN 4C Phase 3C.b.3 (2026-05-23): derivation-chain-for/union-contradict
;; ============================================================
;;
;; Per addendum design §9.5.3.4. Wraps `static-reverse-walk` to produce a
;; derivation chain for the union all-branch-contradict event, enriched with
;; assumption-names decoded via solver-state-assumptions lookup.
;;
;; First downstream CONSUMER of `static-reverse-walk` per Propagator-First
;; Diagnostics framing (§9.5.1.3). Phase 3C.c bridges this chain from
;; check/err to populate `union-exhaustion-error.derivation-chain`; Phase
;; 11b extends the wrapper pattern to general derivation diagnostics.
;;
;; Signature:
;;   net              — current prop-network state
;;   branch-aid-set   — seteq of branch assumption-ids that contradicted
;;                      (output of per-fork threshold predicate at 3C.b.4)
;;   request-info     — fork-on-union request hash from cell-15 (per
;;                      typing-propagators.rkt:615 R7 emit shape:
;;                      (hasheq 'components ... 'tm-cid CellId))
;;
;; Returns: derivation-chain with steps enriched via assumption-names
;;
;; Filter-fn semantic: include step if any of step.assumption-ids intersect
;; branch-aid-set. Per static-reverse-walk implementation (line 204), filter
;; applies BEFORE recursion — so the walk PRUNES through propagators whose
;; aids don't intersect the contradicted aid-set. This is DESIRABLE: keeps
;; chain focused on contradicted-branch lineage; unrelated propagators
;; (elaboration scaffolding firing under outer worldview before fork) don't
;; appear in chain. D-3C.b-5 verified.
;;
;; Assumption-name decoding (D-3C.b-1 mitigation per audit at atms.rkt:397+403):
;; `solver-amb` stores synthetic symbols (`'h0`, `'h1`, ...) in the
;; `assumption-name` field via `(string->symbol (format "h~a" i))`, and the
;; original label STRING (Phase 3A's `"branch-N-at-position-X"` per
;; typing-propagators.rkt:1137) in the `assumption-datum` field. Wrapper
;; prefers `datum` when it's a string (Phase 3A pattern); else formats
;; `name` symbol. Handles both Phase 3A amb pattern AND future consumers
;; (e.g., context assumptions per elab-speculation-bridge.rkt:164) with
;; non-string datums uniformly.
;;
;; Residual-cost: NOT populated by 3C.b.3 — primitive default `#f` preserved
;; through enrichment per Q-B.4 lock (defer to 3C.d).
;;
;; ATMS access: via `current-command-atms` parameter (elab-speculation-
;; bridge.rkt:104). Defensive on `#f` — returns empty chain (consumer should
;; ensure ATMS is active before invoking, but graceful degradation preserved).
(define (derivation-chain-for/union-contradict net branch-aid-set request-info)
  (define tm-cid (hash-ref request-info 'tm-cid #f))
  (cond
    [(not tm-cid)
     ;; Defensive: malformed request-info — return empty chain
     (derivation-chain '())]
    [else
     (define atms-box (current-command-atms))
     (define assumptions
       (cond
         [atms-box (solver-state-assumptions (unbox atms-box))]
         [else (hasheq)]))
     ;; D-3C.b-7 (NEW, found at impl 2026-05-23): aid IDENTITY is the integer
     ;; `assumption-id-n` field; aid STRUCT is just a typed wrapper. Two aid
     ;; structs with the same `n` are logically the same assumption. But
     ;; `decode-aids-from-cell-value` (line 124+) constructs FRESH
     ;; `(assumption-id i)` from bit positions — these are equal? but NOT eq?
     ;; to the canonical aids passed in `branch-aid-set` (which originate from
     ;; `solver-state-amb` and flow through cell-16/cell-18 preserving eq?
     ;; identity within Phase 3A). `seteq` membership check fails on the eq?
     ;; mismatch even though aids are logically the same. Fix: normalize to
     ;; integer-keyed seteqv at the wrapper boundary; filter + decode both use
     ;; `assumption-id-n` as canonical identity. Documented at wrapper docstring.
     (define branch-aid-ns
       (for/seteqv ([aid (in-set branch-aid-set)]) (assumption-id-n aid)))
     ;; Filter-fn: include step if any of its aid-n integers intersect
     ;; branch-aid-ns. Applied BEFORE recursion (3C.a:204 + T6 test) → prunes
     ;; walk through propagators whose aids don't intersect contradicted set
     ;; (D-3C.b-5).
     (define (filter-fn step)
       (define step-aids (derivation-step-assumption-ids step))
       (for/or ([aid (in-list step-aids)])
         (set-member? branch-aid-ns (assumption-id-n aid))))
     ;; Raw walk over the union cell's dep graph (3C.a primitive)
     (define raw-chain (static-reverse-walk net tm-cid #:filter-fn filter-fn))
     ;; Enrich each step's assumption-names via solver-state-assumptions
     (define enriched-steps
       (for/list ([step (in-list (derivation-chain-steps raw-chain))])
         (define names
           (for/list ([aid (in-list (derivation-step-assumption-ids step))])
             (decode-aid-name assumptions aid)))
         (derivation-step
          (derivation-step-propagator-id step)
          (derivation-step-srcloc step)
          (derivation-step-assumption-ids step)
          names                                       ;; ENRICHED (Q-B.4: residual-cost stays #f, defer to 3C.d)
          (derivation-step-residual-cost step))))
     (derivation-chain enriched-steps)]))

;; PPN 4C Phase 3C.b.3 (2026-05-23): D-3C.b-1 mitigation — assumption-name
;; decoding handles SYMBOL-vs-STRING shape across consumers.
;;
;; Per atms.rkt:397+403 audit, `solver-amb` (the Phase 3A consumer) stores:
;;   - `assumption-name`  = synthetic symbol (`'h0`, `'h1`, ...) via string->symbol
;;   - `assumption-datum` = the original label (Phase 3A passes STRING per
;;                          typing-propagators.rkt:1137 `(format "branch-~a-at-~v" ...)`)
;;
;; Other consumers (e.g., `add-context-assumption!` at elab-speculation-
;; bridge.rkt:164) may store NON-STRING datums (descriptive Racket values).
;;
;; Sexp consumers (Phase 3C.c.1 — `with-speculative-rollback` at
;; elab-speculation-bridge.rkt:213-217) store:
;;   - `assumption-name`  = `(string->symbol label)` (e.g., `'union-branch-Nat`)
;;   - `assumption-datum` = the label STRING (e.g., `"union-branch-Nat"`)
;; This matches Phase 3A's shape; string-datum preference path produces the
;; semantic label naturally for sexp speculation translation.
;;
;; Decoding strategy: prefer `datum` when string (Phase 3A + sexp speculation
;; pattern; carries meaningful semantic info); else format `name` symbol
;; (handles non-string datums + general fallback). Returns synthetic "aid-N"
;; if assumption is missing (defensive; shouldn't happen if ATMS state is
;; consistent).
(define (decode-aid-name assumptions aid)
  ;; D-3C.b-7 mitigation: `assumptions` is a HASHEQ (eq?-keyed) populated by
  ;; canonical aid instances from solver-state-assume; `aid` here may be a
  ;; FRESH struct from decode-aids-from-cell-value (constructed from bit
  ;; position). Direct `hash-ref` would fail on eq? mismatch even though
  ;; aids are equal?. Look up by `assumption-id-n` (canonical integer
  ;; identity) by iterating hash entries — O(N) per lookup; N is bounded by
  ;; active assumption count per command (typically <30 per Phase 3A's bit
  ;; budget; D-3C-8). Acceptable for diagnostic paths (error reporting is
  ;; not on the hot path).
  (define target-n (assumption-id-n aid))
  (define asn
    (for/or ([(k v) (in-hash assumptions)])
      (and (= (assumption-id-n k) target-n) v)))
  (cond
    [(not asn) (format "aid-~a" target-n)]
    [else
     (define datum (assumption-datum asn))
     (cond
       [(string? datum) datum]
       [else (format "~a" (assumption-name asn))])]))

;; ============================================================
;; PPN 4C Phase 3C.c.1 (2026-05-24): derivation-chain-for/union-check
;; ============================================================
;;
;; Per addendum design §9.5.4.5 + §9.5.4.5.1 lean (α). SEXP-MODE TRANSLATOR.
;; Direct parallel to current build-derivation-chain (typing-errors.rkt:127)
;; signature shape: takes sub-failures (LIST of speculation-failure children
;; of the latest speculation-failure at this branch's check). Returns
;; derivation-chain struct.
;;
;; SEXP-MODE TRANSLATOR — scaffolding; retires at Track 4D when sexp typing
;; unifies into on-network typing per Attribute Grammar Substrate vision.
;;
;; Lean (α) sub-failures rationale (§9.5.4.5.1): preserves UX parity with
;; retired build-derivation-chain for atomic checks (no spammy "because:"
;; redundancy with "tried X" line). Richness lands automatically for nested
;; speculation scenarios (where sub-failures populates). For atomic Q6.x
;; case, chain is empty (matches today's UX byte-for-byte); for nested case,
;; chain captures the speculation tree as structured data.
;;
;; Field mapping per speculation-failure → derivation-step:
;;   propagator-id    — #f (sexp speculation has no propagator)
;;   srcloc           — #f (speculation-failure doesn't track srcloc;
;;                          D-3C.c-1 capture for Phase 11b / Track 4D)
;;   assumption-ids   — (list hypothesis-id) from speculation-failure (or '()
;;                      when hypothesis-id is #f, which would only arise for
;;                      direct record-speculation-failure! callers without
;;                      with-speculative-rollback)
;;   assumption-names — decoded via decode-aid-name (3C.b.3 helper); per
;;                      elab-speculation-bridge.rkt:213-217 with-speculative-
;;                      rollback uses label STRING as assumption-datum →
;;                      decode-aid-name returns it via string-datum preference;
;;                      fallback to (list speculation-failure-label) when no aid
;;   residual-cost    — #f (3C.d may populate via tropical-quantale annotation)
;;
;; ATMS access via current-command-atms (same as 3C.b.3); defensive on #f
;; (returns synthetic "aid-N" names via decode-aid-name's no-asn branch).
;;
;; DFS pre-order traversal of the speculation-failure forest:
;;   For each sf in sub-failures, emit (failure-to-step sf), then recursively
;;   collect sf's own sub-failures. Result list is in causal reading order
;;   (parent-failure-first, then nested-failures); parallel to
;;   static-reverse-walk's deepest-first cons-onto-head pattern.
(define (derivation-chain-for/union-check sub-failures)
  (cond
    [(or (not sub-failures) (null? sub-failures))
     (derivation-chain '())]
    [else
     (define atms-box (current-command-atms))
     (define assumptions
       (cond [atms-box (solver-state-assumptions (unbox atms-box))]
             [else (hasheq)]))
     (define (failure-to-step sf)
       (define hyp-id (speculation-failure-hypothesis-id sf))
       (define aids (if hyp-id (list hyp-id) '()))
       (define names
         (cond
           [(pair? aids)
            (for/list ([aid (in-list aids)])
              (decode-aid-name assumptions aid))]
           [else (list (speculation-failure-label sf))]))
       (derivation-step #f #f aids names #f))
     ;; DFS pre-order flatten across the speculation-failure forest:
     ;; for each sf in sub-failures, emit (failure-to-step sf) followed
     ;; by recursive collection of its own sub-failures.
     (define (collect sf)
       (cons (failure-to-step sf)
             (apply append
                    (map collect (speculation-failure-sub-failures sf)))))
     (derivation-chain
       (apply append (map collect sub-failures)))]))
