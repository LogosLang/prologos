#lang racket/base

;;;
;;; 2026-05-24-3C-d-3-w1-empirical-probe.rkt — PPN 4C Addendum Phase 3C.d.3
;;;
;;; Empirical W1 srcloc probe — provides the empirical premise for the
;;; (β.3.*) decision tree at addendum §9.5.5.5 deliverable 3.
;;;
;;; Three scenarios probe the propagator-srcloc field population through
;;; the chain construction path:
;;;
;;;   A — Synthetic E2E baseline (no current-source-loc parameterize)
;;;       Mirrors union-all-contradict-chain/int-bool-both-fail from
;;;       tests/test-union-types-atms.rkt:730+. Predicted: srcloc=#f for
;;;       every chain step (test fixture doesn't bind current-source-loc;
;;;       W1 default returns #f).
;;;
;;;   B — Synthetic E2E WITH (parameterize ([current-source-loc test-loc]) ...)
;;;       Same setup as A but inside a current-source-loc parameterize.
;;;       Probes (β.3.i) parameterize-wrap MECHANICAL FEASIBILITY: does
;;;       W1 wiring through process-fork-on-union dispatch actually thread
;;;       the parameterized srcloc through to propagator structs + chain
;;;       steps? Predicted: srcloc=test-loc for steps whose propagators
;;;       were installed during process-fork-on-union. Falsification would
;;;       surface a W1 wiring gap (3C.d.1 would have a hidden defect).
;;;
;;;   C — Production sexp paths via process-string/return-net
;;;       C1: (def x <Nat | Bool> "hello") — union all-branch-contradict
;;;           Predicted: chains are EMPTY (derivation-chain '()) per sexp
;;;           translator design (3C.c.1 lean α + 3C.b atomic case) — no
;;;           sub-failures to translate for atomic check. Even if chains
;;;           had steps, srcloc would be #f by design (D-3C.c-1; sexp
;;;           translator at error-explanation.rkt:409 hardcodes #f).
;;;       C2: (def x <Nat | Bool> 42) — union partial-success (Nat<:Int)
;;;           Predicted: cell-19 unwritten for this position (no all-contradict).
;;;       C3: (def x : Nat true) — non-union type-mismatch-error
;;;           Predicted: type-mismatch-error?, no derivation-chain field
;;;           (provenance is (listof string)). KR-3 boundary verification.
;;;
;;; Run via: racket data/probes/2026-05-24-3C-d-3-w1-empirical-probe.rkt
;;;          > data/probes/2026-05-24-3C-d-3-w1-empirical-output.txt 2>&1
;;;
;;; Output is committed alongside the probe as design-doc empirical artifact.
;;; Referenced from addendum §9.5.5.5 deliverable 3 + §9.5.5.10 cross-track
;;; captures + dailies 2026-05-24 session.
;;;

(require racket/list
         "../../syntax.rkt"
         "../../propagator.rkt"
         "../../atms.rkt"
         "../../classify-inhabit.rkt"
         "../../elab-speculation-bridge.rkt"
         "../../error-explanation.rkt"
         "../../source-location.rkt"
         "../../driver.rkt"
         "../../elab-network-types.rkt"
         "../../errors.rkt")

;; ============================================================
;; Inline fixture — replicates tests/test-union-types-atms.rkt:61+78
;; (make-test-fixture + write-classify-inhabit are not exported)
;; ============================================================

(define (make-test-fixture)
  (define net (make-prop-network))
  (define (attr-map-merge old new)
    (cond
      [(not (hash? old)) new]
      [(not (hash? new)) old]
      [else
       (for/fold ([acc old]) ([(k v) (in-hash new)])
         (hash-set acc k v))]))
  (define-values (net1 tm-cid) (net-new-cell net (hasheq) attr-map-merge))
  (values net1 tm-cid 'test-position))

(define (write-classify-inhabit net tm-cid position classifier inhabitant)
  (define cinhab-val (classify-inhabit-value classifier inhabitant))
  (net-cell-write net tm-cid (hasheq position (hasheq ':type cinhab-val))))

;; ============================================================
;; Diagnostic formatters
;; ============================================================

(define (format-step step idx)
  (format "      step[~a]: pid=~v srcloc=~v aids=~v names=~v residual-cost=~v"
          idx
          (derivation-step-propagator-id step)
          (derivation-step-srcloc step)
          (derivation-step-assumption-ids step)
          (derivation-step-assumption-names step)
          (derivation-step-residual-cost step)))

(define (print-chain-info label chain)
  (define steps (derivation-chain-steps chain))
  (printf "    ~a steps=~a\n" label (length steps))
  (for ([step (in-list steps)]
        [i (in-naturals)])
    (printf "~a\n" (format-step step i))))

;; Read cell-19 from a synthetic prop-network (Scenarios A/B).
;; Uses net-cell-read (prop-network primitive).
(define (print-cell-19-prop-net net label)
  (define cell-19-val (net-cell-read net union-derivation-chains-cell-id))
  (cond
    [(not (hash? cell-19-val))
     (printf "    cell-19 value (non-hash): ~v\n" cell-19-val)]
    [(zero? (hash-count cell-19-val))
     (printf "    cell-19: empty hash (no chain written for any position)\n")]
    [else
     (for ([(pos chains) (in-hash cell-19-val)]
           [pi (in-naturals)])
       (printf "    position[~a]=~v\n" pi pos)
       (cond
         [(list? chains)
          (printf "    per-branch chain count: ~a\n" (length chains))
          (for ([c (in-list chains)]
                [ci (in-naturals)])
            (print-chain-info (format "chain[~a]:" ci) c))]
         [else
          (printf "    chains (non-list): ~v\n" chains)]))]))

;; Read cell-19 from a process-string/return-net result (Scenario C).
;; Uses elab-cell-read per test-provenance-errors.rkt:270.
(define (print-cell-19-elab-net net label)
  (define cell-19-val
    (with-handlers ([exn:fail? (lambda (_) #f)])
      (elab-cell-read net union-derivation-chains-cell-id)))
  (cond
    [(not cell-19-val)
     (printf "    [cell-19 not readable: elab-cell-read raised]\n")]
    [(not (hash? cell-19-val))
     (printf "    cell-19 value (non-hash): ~v\n" cell-19-val)]
    [(zero? (hash-count cell-19-val))
     (printf "    cell-19: empty hash (no chain written for any position)\n")]
    [else
     (for ([(pos chains) (in-hash cell-19-val)]
           [pi (in-naturals)])
       (printf "    position[~a]=~v\n" pi pos)
       (cond
         [(list? chains)
          (printf "    per-branch chain count: ~a\n" (length chains))
          (for ([c (in-list chains)]
                [ci (in-naturals)])
            (print-chain-info (format "chain[~a]:" ci) c))]
         [else
          (printf "    chains (non-list): ~v\n" chains)]))]))

(define (summarize-error r)
  (cond
    [(type-mismatch-error? r) 'type-mismatch-error]
    [(union-exhaustion-error? r) 'union-exhaustion-error]
    [(prologos-error? r) 'other-prologos-error]
    [else 'non-error]))

;; ============================================================
;; Scenario A — Synthetic E2E baseline (no current-source-loc parameterize)
;; ============================================================

(define (scenario-A)
  (printf "===========================================================\n")
  (printf "Scenario A — Synthetic E2E baseline (no current-source-loc parameterize)\n")
  (printf "===========================================================\n")
  (printf "Setup: mirrors union-all-contradict-chain/int-bool-both-fail\n")
  (printf "  components: (Int | Bool); inhabitant: (expr-string \"hello\")\n")
  (printf "  current-source-loc at probe entry = ~v\n" (current-source-loc))

  (define-values (net tm-cid position) (make-test-fixture))
  (parameterize ([current-command-atms (box (make-solver-state (make-prop-network)))])
    (printf "  current-source-loc INSIDE current-command-atms parameterize = ~v\n"
            (current-source-loc))
    (define net1 (write-classify-inhabit net tm-cid position 'bot (expr-string "hello")))
    (define components (list (expr-Int) (expr-Bool)))
    (define request (hasheq 'components components 'tm-cid tm-cid))
    (define net2 (net-cell-write net1 fork-on-union-request-cell-id
                                  (hasheq position request)))
    (define net3 (run-to-quiescence net2))
    (print-cell-19-prop-net net3 "after run-to-quiescence")))

;; ============================================================
;; Scenario B — Synthetic E2E WITH current-source-loc parameterize
;; ============================================================

(define (scenario-B)
  (printf "\n===========================================================\n")
  (printf "Scenario B — Synthetic E2E WITH (parameterize ([current-source-loc test-loc]) ...)\n")
  (printf "===========================================================\n")
  (printf "Setup: same as A, but with current-source-loc bound to a test srcloc\n")

  (define test-loc (srcloc "probe-test.rkt" 42 5 10))
  (printf "  test-loc = ~v\n" test-loc)
  (define-values (net tm-cid position) (make-test-fixture))
  (parameterize ([current-command-atms (box (make-solver-state (make-prop-network)))]
                 [current-source-loc test-loc])
    (printf "  current-source-loc INSIDE parameterize = ~v\n" (current-source-loc))
    (define net1 (write-classify-inhabit net tm-cid position 'bot (expr-string "hello")))
    (define components (list (expr-Int) (expr-Bool)))
    (define request (hasheq 'components components 'tm-cid tm-cid))
    (define net2 (net-cell-write net1 fork-on-union-request-cell-id
                                  (hasheq position request)))
    (define net3 (run-to-quiescence net2))
    (print-cell-19-prop-net net3 "after run-to-quiescence")))

;; ============================================================
;; Scenario C — Production sexp paths via process-string/return-net
;; ============================================================

(define (scenario-C)
  (printf "\n===========================================================\n")
  (printf "Scenario C — Production sexp paths via process-string/return-net\n")
  (printf "===========================================================\n")

  ;; C1 — union all-branch-contradict
  (printf "\n  --- C1: (def x <Nat | Bool> \"hello\") — union all-branch-contradict ---\n")
  (define-values (r1 net1) (process-string/return-net "(def x <Nat | Bool> \"hello\")"))
  (printf "    results=~v\n" (and (list? r1) (map summarize-error r1)))
  (print-cell-19-elab-net net1 "cell-19 state")

  ;; C2 — union partial-success (Nat<:Int matches via SRE Track 2H subtype lattice)
  (printf "\n  --- C2: (def x <Nat | Bool> 42) — union partial-success ---\n")
  (define-values (r2 net2) (process-string/return-net "(def x <Nat | Bool> 42)"))
  (printf "    results=~v\n" (and (list? r2) (map summarize-error r2)))
  (print-cell-19-elab-net net2 "cell-19 state")

  ;; C3 — non-union type-mismatch
  (printf "\n  --- C3: (def x : Nat true) — non-union type-mismatch ---\n")
  (define-values (r3 net3) (process-string/return-net "(def x : Nat true)"))
  (printf "    results=~v\n" (and (list? r3) (map summarize-error r3)))
  (when (and (list? r3) (positive? (length r3)))
    (define last-r (last r3))
    (cond
      [(type-mismatch-error? last-r)
       (printf "    type-mismatch-error fields (KR-3 boundary):\n")
       (printf "      message: ~v\n" (prologos-error-message last-r))
       (printf "      expected: ~v\n" (type-mismatch-error-expected last-r))
       (printf "      actual: ~v\n" (type-mismatch-error-actual last-r))
       (printf "      provenance: ~v\n" (type-mismatch-error-provenance last-r))
       (printf "      provenance is list? ~v\n" (list? (type-mismatch-error-provenance last-r)))
       (printf "      type-mismatch-error struct has NO derivation-chain field per errors.rkt:65 (4 fields total)\n")]
      [else
       (printf "    UNEXPECTED: last result is not a type-mismatch-error: ~v\n" last-r)]))
  (print-cell-19-elab-net net3 "cell-19 state (should be unrelated to non-union mismatch)"))

;; ============================================================
;; Main — confined to (module+ main) so the check-stdout-clean
;; pre-commit hook (which uses dynamic-require) doesn't see this
;; intentional stdout output. The main submodule runs only when
;; the file is invoked directly via `racket file.rkt`.
;; ============================================================

(module+ main
  (printf "PPN 4C Phase 3C.d.3 — W1 srcloc empirical probe\n")
  (printf "================================================\n")
  (printf "Date: 2026-05-24\n")
  (printf "Purpose: empirical premise for (β.3.*) decision tree at addendum §9.5.5.5\n")
  (printf "Source: this file (probe.rkt); Output: probe-output.txt (paired artifact)\n\n")

  (scenario-A)
  (scenario-B)
  (scenario-C)

  (printf "\n===========================================================\n")
  (printf "Probe complete.\n"))
