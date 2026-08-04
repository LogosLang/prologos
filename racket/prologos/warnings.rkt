#lang racket/base

;;;
;;; PROLOGOS WARNINGS
;;; Informational warnings (non-fatal) emitted during type checking.
;;; Accumulated via a parameterized list and displayed after command processing.
;;;

(provide current-coercion-warnings
         emit-coercion-warning!
         format-coercion-warning
         ;; Deprecation warnings
         current-deprecation-warnings
         deprecation-warning
         deprecation-warning?
         deprecation-warning-name
         deprecation-warning-message
         emit-deprecation-warning!
         format-deprecation-warning
         ;; Capability warnings (W2001)
         current-capability-warnings
         capability-warning
         capability-warning?
         capability-warning-name
         capability-warning-multiplicity
         emit-capability-warning!
         format-capability-warning
         ;; Process capability warnings (W2002, W2003)
         process-cap-warning
         process-cap-warning?
         process-cap-warning-code
         process-cap-warning-name
         process-cap-warning-message
         emit-process-cap-warning!
         format-process-cap-warning
         ;; Duplicate-binding warnings (W3001) — issue #67
         current-duplicate-binding-warnings
         duplicate-binding-warning
         duplicate-binding-warning?
         duplicate-binding-warning-name
         emit-duplicate-binding-warning!
         format-duplicate-binding-warning
         read-duplicate-binding-warnings
         reset-duplicate-binding-warnings!
         ;; Non-exhaustive match warnings (W3002)
         current-inexhaustive-match-warnings
         inexhaustive-match-warning
         inexhaustive-match-warning?
         inexhaustive-match-warning-loc-str
         emit-inexhaustive-match-warning!
         format-inexhaustive-match-warning
         read-inexhaustive-match-warnings
         current-inexhaustive-match-warnings-cell-id
         current-duplicate-binding-warnings-cell-id
         ;; Phase 2c: Warning cell infrastructure
         current-warnings-prop-net-box
         current-warnings-prop-cell-write
         current-warnings-prop-cell-read
         current-coercion-warnings-cell-id
         current-deprecation-warnings-cell-id
         current-capability-warnings-cell-id
         register-warning-cells!
         init-warning-cells!
         reset-warning-cells!
         ;; Track 3 Phase 4: cell-primary readers
         read-coercion-warnings
         read-deprecation-warnings
         read-capability-warnings
         ;; PPN 4C Phase 2: facet SRE registration
         warnings-facet-merge)

(require racket/string
         "infra-cell.rkt"        ;; merge-list-append
         "propagator.rkt"        ;; Track 7 Phase 2: net-new-cell, net-cell-read, net-cell-write
         "metavar-store.rkt"     ;; Track 7 Phase 2: current-persistent-registry-net-box
         (only-in "sre-core.rkt" make-sre-domain register-domain!)  ;; PPN 4C Phase 2
         (only-in "merge-fn-registry.rkt" register-merge-fn!/lattice))  ;; PPN 4C Phase 2

;; ========================================
;; Phase 2c: Propagator-First Migration — Warning Cell Infrastructure
;; ========================================
;; Callback parameters for network access (set by driver.rkt).
(define current-warnings-prop-net-box (make-parameter #f))
(define current-warnings-prop-cell-write (make-parameter #f))
(define current-warnings-prop-cell-read (make-parameter #f))  ;; Track 3 Phase 4: (enet cell-id → value)
;; Cell-id parameters for each warning accumulator.
(define current-coercion-warnings-cell-id (make-parameter #f))
(define current-deprecation-warnings-cell-id (make-parameter #f))
(define current-capability-warnings-cell-id (make-parameter #f))
(define current-duplicate-binding-warnings-cell-id (make-parameter #f))
(define current-inexhaustive-match-warnings-cell-id (make-parameter #f))

;; Helper: write a warning to a list cell in the persistent network.
;; Track 7 Phase 2: targets persistent registry network directly.
;; Track 7 Phase 4: tags each list element with current assumption.
(define (warnings-cell-write! cid value)
  (define prn-box (current-persistent-registry-net-box))
  (when (and prn-box cid)
    (define aid (current-speculation-assumption))
    (define tagged-value (map (λ (w) (tagged-entry w aid)) value))
    (set-box! prn-box (net-cell-write (unbox prn-box) cid tagged-value))))

;; Track 7 Phase 2: Initialize warning cells in the persistent registry network.
;; Called ONCE from init-persistent-registry-network!.
(define (init-warning-cells! prn-box)
  (when prn-box
    (define net0 (unbox prn-box))
    (define-values (net1 cw-cid) (net-new-cell net0 (current-coercion-warnings) merge-list-append))
    (current-coercion-warnings-cell-id cw-cid)
    (define-values (net2 dw-cid) (net-new-cell net1 (current-deprecation-warnings) merge-list-append))
    (current-deprecation-warnings-cell-id dw-cid)
    (define-values (net3 capw-cid) (net-new-cell net2 (current-capability-warnings) merge-list-append))
    (current-capability-warnings-cell-id capw-cid)
    (define-values (net4 dbw-cid) (net-new-cell net3 (current-duplicate-binding-warnings) merge-list-append))
    (current-duplicate-binding-warnings-cell-id dbw-cid)
    (define-values (net5 imw-cid) (net-new-cell net4 (current-inexhaustive-match-warnings) merge-list-append))
    (current-inexhaustive-match-warnings-cell-id imw-cid)
    (set-box! prn-box net5)))

;; Per-command reset: clear the (grows-only) warning cells on the persistent
;; registry network back to '(). These cells are per-command EPHEMERAL but live
;; on the persistent-registry net (init-warning-cells!), which reset-meta-store!
;; does NOT rebuild — so without this they accumulate across commands / tests
;; (the passes-alone-fails-in-batch hazard, and a locked rule losing L2 coverage).
;; net-cell-reset bypasses the list-append merge (which only grows) to clear to
;; '(). Called from process-command after reset-meta-store!. FOLLOW-UP: re-home
;; these onto the per-command elab-network so this explicit reset can be deleted
;; (correct-by-construction) — deferred because it crosses the elaboration-vs-
;; module-load two-context boundary.
(define (reset-warning-cells!)
  (define prn-box (current-persistent-registry-net-box))
  (when prn-box
    (define net0 (unbox prn-box))
    (define (clr net cid) (if cid (net-cell-reset net cid '()) net))
    (define net1 (clr net0 (current-coercion-warnings-cell-id)))
    (define net2 (clr net1 (current-deprecation-warnings-cell-id)))
    (define net3a (clr net2 (current-capability-warnings-cell-id)))
    ;; W3002 IS cleared per command — unlike W3001, a non-exhaustive match
    ;; belongs to the definition being processed, so the per-command channel is
    ;; the right lifetime and a stale one must not follow the next command.
    (define net3 (clr net3a (current-inexhaustive-match-warnings-cell-id)))
    ;; issue #67: the duplicate-binding cell is NOT cleared here. It accumulates
    ;; a FILE-level fact — raised while the import set is resolved during
    ;; preparse, before any command runs — so a per-command clear would wipe it
    ;; before anything could report it. `process-file-inner` reads it once at the
    ;; end; the per-command channel is the wrong lifetime for this category.
    (set-box! prn-box net3)))

;; Legacy: per-command warning cell creation.
;; Track 7 Phase 2: no-op — cells now in persistent network.
(define (register-warning-cells! net-box new-cell-fn)
  (void))

;; Track 7 Phase 2: cell-primary read from persistent registry network.
;; Track 7 Phase 6e: returns cell content or #f (no parameter fallback).
(define (warnings-cell-read-safe cid)
  (define prn-box (current-persistent-registry-net-box))
  (if (and cid prn-box)
      (with-handlers ([exn:fail? (λ (_) #f)])
        (net-cell-read (unbox prn-box) cid))
      #f))

;; Track 7 Phase 6e: cell-primary reads with parameter fallback for no-network case.
(define (read-coercion-warnings)
  (define v (warnings-cell-read-safe (current-coercion-warnings-cell-id)))
  (if v (unwrap-tagged-list v) (current-coercion-warnings)))

(define (read-deprecation-warnings)
  (define v (warnings-cell-read-safe (current-deprecation-warnings-cell-id)))
  (if v (unwrap-tagged-list v) (current-deprecation-warnings)))

(define (read-capability-warnings)
  (define v (warnings-cell-read-safe (current-capability-warnings-cell-id)))
  (if v (unwrap-tagged-list v) (current-capability-warnings)))

(define (read-inexhaustive-match-warnings)
  (define v (warnings-cell-read-safe (current-inexhaustive-match-warnings-cell-id)))
  (if v (unwrap-tagged-list v) (current-inexhaustive-match-warnings)))

(define (read-duplicate-binding-warnings)
  (define v (warnings-cell-read-safe (current-duplicate-binding-warnings-cell-id)))
  (if v (unwrap-tagged-list v) (current-duplicate-binding-warnings)))

;; ========================================
;; Coercion warnings
;; ========================================

;; Accumulator for coercion warnings (list of warning structs).
;; Reset per-command in driver.rkt.
(define current-coercion-warnings (make-parameter '()))

;; A coercion warning: from-type-str and to-type-str are human-readable names.
(struct coercion-warning (from-type-str to-type-str) #:transparent)

;; Emit a coercion warning (exact → approximate).
;; from-str, to-str: strings like "Int", "Posit32"
(define (emit-coercion-warning! from-str to-str)
  (define w (coercion-warning from-str to-str))
  (current-coercion-warnings (cons w (current-coercion-warnings)))
  ;; Phase 2c: dual-write to cell
  (warnings-cell-write! (current-coercion-warnings-cell-id) (list w)))

;; Format a coercion warning for display.
(define (format-coercion-warning w)
  (format "warning: implicit coercion from ~a to ~a (loss of exactness)"
          (coercion-warning-from-type-str w)
          (coercion-warning-to-type-str w)))

;; ========================================
;; Deprecation warnings
;; ========================================

;; Accumulator for deprecation warnings (list of warning structs).
;; Reset per-command in driver.rkt.
(define current-deprecation-warnings (make-parameter '()))

;; A deprecation warning: name is the deprecated function/spec name (symbol),
;; message is an optional string (e.g., "use foo-v2 instead") or #f.
(struct deprecation-warning (name message) #:transparent)

;; Emit a deprecation warning.
(define (emit-deprecation-warning! name msg)
  (define w (deprecation-warning name msg))
  (current-deprecation-warnings (cons w (current-deprecation-warnings)))
  ;; Phase 2c: dual-write to cell
  (warnings-cell-write! (current-deprecation-warnings-cell-id) (list w)))

;; Format a deprecation warning for display.
(define (format-deprecation-warning w)
  (format "warning: ~a is deprecated~a"
          (deprecation-warning-name w)
          (if (deprecation-warning-message w)
              (format " — ~a" (deprecation-warning-message w))
              "")))

;; ========================================
;; Capability warnings (W2001)
;; ========================================

;; Accumulator for capability warnings (list of warning structs).
;; Reset per-command in driver.rkt.
(define current-capability-warnings (make-parameter '()))

;; A capability warning: name is the capability type name (symbol),
;; multiplicity is the declared multiplicity ('mw typically).
;; W2001: Unrestricted (:w) on a capability — consider :0 (authority proof) or :1 (authority transfer).
(struct capability-warning (name multiplicity) #:transparent)

;; Emit a capability warning.
(define (emit-capability-warning! name mult)
  (define w (capability-warning name mult))
  (current-capability-warnings (cons w (current-capability-warnings)))
  ;; Phase 2c: dual-write to cell
  (warnings-cell-write! (current-capability-warnings-cell-id) (list w)))

;; Format a capability warning for display.
(define (format-capability-warning w)
  (format "W2001: Unrestricted :w on capability ~a — consider :0 (authority proof) or :1 (authority transfer)."
          (capability-warning-name w)))

;; ========================================
;; Process capability warnings (W2002, W2003)
;; ========================================

;; W2002: Dead authority — process declares a capability binder but never uses it.
;; W2003: Ambient authority — process header uses :w multiplicity on a cap.
;; These are accumulated in the same current-capability-warnings list (shared accumulator).
(struct process-cap-warning (code name message) #:transparent)

;; Emit a process capability warning.
(define (emit-process-cap-warning! code name msg)
  (define w (process-cap-warning code name msg))
  (current-capability-warnings (cons w (current-capability-warnings)))
  ;; Phase 2c: dual-write to cell (shared with capability warnings)
  (warnings-cell-write! (current-capability-warnings-cell-id) (list w)))

;; Format a process capability warning for display.
(define (format-process-cap-warning w)
  (format "~a: ~a — ~a"
          (process-cap-warning-code w)
          (process-cap-warning-name w)
          (process-cap-warning-message w)))

;; ========================================
;; Non-exhaustive match warnings (W3002) — 2026-08-03
;; ========================================
;;
;; A pattern match with no matching row compiles to a typed hole named
;; `__match-fail` (macros.rkt), and a typed hole is a legal term that types at
;; anything. So a partial function SILENTLY returned a hole at its declared
;; return type:
;;
;;   spec p1 Nat -> Nat
;;   defn p1
;;     | zero -> 1N
;;   [p1 5N]   ⇒  ??__match-fail : Nat        (0 errors, before this)
;;
;; A WARNING rather than an error, and the severity is the whole design
;; question. Prologos has typed holes as a FIRST-CLASS feature — a user-written
;; `??foo` is accepted at 0 errors on purpose — so a partial function is not
;; obviously illegal here the way it is in Agda or Idris. What is not defensible
;; is silence about a hole the COMPILER inserted because a case was missed.
;;
;; DEFAULT-ON, decided by measurement rather than taste, the same way W3001 was:
;;   - a full prelude load plants ZERO `__match-fail` holes;
;;   - the F1-records and F1b5-validate acceptance files: zero;
;;   - the OCapN acceptance file: exactly ONE.
;; So the ordinary path is silent and the signal is precise — it fires where a
;; match is genuinely incomplete, not on every constructor split.
(define current-inexhaustive-match-warnings (make-parameter '()))

(struct inexhaustive-match-warning (loc-str) #:transparent)

(define (emit-inexhaustive-match-warning! loc-str)
  (define w (inexhaustive-match-warning loc-str))
  (current-inexhaustive-match-warnings (cons w (current-inexhaustive-match-warnings)))
  (warnings-cell-write! (current-inexhaustive-match-warnings-cell-id) (list w)))

(define (format-inexhaustive-match-warning w)
  (format (string-append
           "W3002: this pattern match does not cover every case~a. An uncovered "
           "input yields `??__match-fail` — a typed hole at the declared return "
           "type — rather than an error, so the gap is silent at runtime. Add "
           "the missing patterns, or a `_` catch-all if partiality is intended.")
          (let ([l (inexhaustive-match-warning-loc-str w)])
            (if (and l (not (equal? l ""))) (format " (~a)" l) ""))))

;; ========================================
;; Duplicate-binding warnings (W3001) — issue #67
;; ========================================
;;
;; The spec store keys by BARE symbol with silent last-write-wins, so importing
;; two modules that both export a spec for `map` leaves ONE of them, chosen by
;; import order, with no signal at all. The loser's call sites then get the
;; WRONG implicit-argument count.
;;
;; DEFAULT-ON, and that was the open question in the filing ("the
;; DEFAULT-ON-vs-opt-in question is a UX call"). It was settled by measuring
;; rather than by taste. Two numbers decided it:
;;
;;   - Importing `prologos::data::list` + `prologos::core::collections` — the
;;     realistic pair — collides on 14 spec names, and ALL FOURTEEN differ in
;;     where-constraints AND implicit-binders. There is no benign-clobber class
;;     to filter out: every collision in the censused set is behaviourally live.
;;     So default-on has no false positives to apologise for.
;;   - A plain prelude load collides ZERO times. The ordinary path is silent,
;;     which is why this stayed invisible and why turning it on is not noisy for
;;     programs that do not create the ambiguity.
;;
;; An opt-in nobody enables is decoration — this project's own "Validated Is Not
;; Deployed" lesson — and a warning that fires only on genuine, order-dependent
;; ambiguity does not need an opt-out.
(define current-duplicate-binding-warnings (make-parameter '()))

;; name: the bare symbol more than one import bound.
;;
;; ⚠ THE WINNER IS DELIBERATELY NOT RECORDED, and that is a correction rather
;; than a simplification. The first cut named it ("X wins here") and the probe
;; falsified the claim immediately: preparse walks the import list TWICE, so
;; each name warned once per direction with OPPOSITE winners. Even without the
;; double pass the claim would have been wrong — the census
;; (`test-spec-store-clobber.rkt`) established that "last import wins" is FALSE
;; as a general rule; `sum` is the counterexample. What is TRUE, and what the
;; census does lock, is that the outcome is order-DEPENDENT. So that is what
;; the message says.
(struct duplicate-binding-warning (name) #:transparent)

;; Per-FILE reset. This category is deliberately absent from
;; `reset-warning-cells!` (which runs per COMMAND and would wipe it before
;; anything could report it), so it needs its own clearing point — otherwise a
;; long-lived process running many files accumulates every file's warnings and
;; reports them all under the second one. Found exactly that way: the four
;; W3001 tests passed one at a time and three failed in file order.
(define (reset-duplicate-binding-warnings!)
  (current-duplicate-binding-warnings '())
  (define prn-box (current-persistent-registry-net-box))
  (define cid (current-duplicate-binding-warnings-cell-id))
  ;; The cell-id parameter outlives any particular network: a test that swaps
  ;; the persistent-registry net box (test-pnet-registry-restore does) leaves a
  ;; live id naming a cell the current net has never heard of. Nothing to clear
  ;; is not an error — the parameter reset above already covers the no-network
  ;; path — so this mirrors `warnings-cell-read-safe`'s existing handler rather
  ;; than raising into an unrelated caller.
  (when (and prn-box cid)
    (with-handlers ([exn:fail? (lambda (_) (void))])
      (set-box! prn-box (net-cell-reset (unbox prn-box) cid '())))))

(define (emit-duplicate-binding-warning! name)
  (define w (duplicate-binding-warning name))
  (current-duplicate-binding-warnings (cons w (current-duplicate-binding-warnings)))
  (warnings-cell-write! (current-duplicate-binding-warnings-cell-id) (list w)))

;; Takes the whole NAME LIST and renders ONE line. The realistic pair collides
;; on 14 names at once, and 14 near-identical paragraphs would bury the file's
;; actual results — the list of names IS the information here, and the
;; explanation is the same sentence for every one of them.
;;
;; The message names the remedy, because the remedy is what the reader needs:
;; the ambiguity is resolvable by qualifying the call or importing selectively.
;;
;; ⚠ IT DELIBERATELY DOES NOT CLAIM A CONSEQUENCE IT CANNOT DEMONSTRATE. The
;; first version said "call sites of the other get the wrong argument count",
;; borrowed from the DEFERRED entry. Probed afterwards, and it did not hold for
;; a BARE call: value resolution and spec propagation both follow import order
;; over the same import list, so they AGREE, and an unqualified `[length xs]`
;; with both modules imported gives the right answer — verified identical with
;; the qualified-lookup probe removed, i.e. it was never broken. The case that
;; WAS broken is a QUALIFIED call to the race's loser, and that one is fixed.
;;
;; So what remains true, and all the message now says, is that the NAME is
;; ambiguous and which module answers to it depends on import order. That is
;; worth telling someone — they may get a different function than they meant —
;; but it is a question of MEANING, not of a corrupted argument count.
(define (format-duplicate-binding-warning names)
  (format (string-append
           "W3001: ~a name~a bound by more than one import with different "
           "implicit-argument counts (~a). Which one you get depends on import "
           "ORDER — qualify the call (`Module::name`) or import selectively.")
          (length names)
          (if (= 1 (length names)) " is" "s are")
          (string-join (map symbol->string names) " ")))

;; ============================================================
;; PPN 4C Phase 2: :warnings facet SRE domain registration (A9)
;; ============================================================
;;
;; D2 framework per §6.9.2:
;;   Aspirational: commutative + idempotent (SET LATTICE with srcloc-
;;     in-value per D1 resolution); associative
;;   Declared (γ, pre-Phase-5): associative only — warning structs
;;     don't yet carry srcloc field; current merge is list-append
;;     which is non-commutative and non-idempotent
;;   Expected inference (pre-Phase-5): confirm associative; refute
;;     commutative + idempotent
;;   Delta: RESOLVED IN PHASE 5 — add srcloc field to warning
;;     structs, thread srcloc at emit sites (uses Phase 1.5
;;     current-source-loc API), switch merge to merge-set-union,
;;     re-run inference → should then confirm comm + assoc + idem.
;;
;; warnings-facet-merge wraps raw `append` as a named function so
;; Phase 1d Tier 2 registration has a concrete name to link to a
;; domain (unnamed `append` isn't registerable).

(define (warnings-facet-merge old new)
  (cond
    [(null? old) new]  ;; '() is bot
    [(null? new) old]
    [else (append old new)]))

(define warnings-merge-registry
  (lambda (rel-name)
    (case rel-name
      [(equality) warnings-facet-merge]
      [else (error 'warnings-merge-registry "no merge for relation: ~a" rel-name)])))

(define (warnings-bot? v) (and (list? v) (null? v)))
(define (warnings-contradicts? v) #f)  ;; warnings accumulate; no contradiction state

(define warnings-sre-domain
  (make-sre-domain
   #:name 'warnings
   #:merge-registry warnings-merge-registry
   #:contradicts? warnings-contradicts?
   #:bot? warnings-bot?
   #:bot-value '()))

(register-domain! warnings-sre-domain)
(register-merge-fn!/lattice warnings-facet-merge #:for-domain 'warnings)
