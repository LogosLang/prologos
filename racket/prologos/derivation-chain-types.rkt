#lang racket/base

;;;
;;; derivation-chain-types.rkt — PPN 4C Addendum Phase 3C.c.3 (2026-05-24)
;;;
;;; Base struct definitions for derivation chains. Extracted from
;;; error-explanation.rkt at 3C.c.3 to break a require cycle:
;;;   errors.rkt → error-explanation.rkt → propagator.rkt → reduction.rkt → errors.rkt
;;;
;;; The structs themselves are pure data with no behavioral dependencies, so
;;; they live in this leaf module that both `errors.rkt` (for format-error's
;;; union-exhaustion-error case) and `error-explanation.rkt` (for the
;;; `static-reverse-walk` primitive + `derivation-chain-for/union-*`
;;; wrappers) can require without cycle risk.
;;;
;;; PROVENANCE: structs originally defined in error-explanation.rkt at 3C.a
;;; (commit `1d803ed2`); relocated here at 3C.c.3 atomic landing per
;;; §9.5.4.5 cycle resolution. Backward compatibility preserved via
;;; (struct-out ...) re-export from error-explanation.rkt.
;;;
;;; LOCKED design decisions (per §9.5.2.2):
;;;   Q-A.2 Step field shape — 5 fields: propagator-id + srcloc +
;;;         assumption-ids + assumption-names + residual-cost (all transparent;
;;;         LSP-ready; forward-compat with field additions per Q-A.8 —
;;;         field-semantics changes treated as breaking)
;;;   Q-A.5 Step ordering — DFS pre-order (deepest cause first → symptom last)
;;;

(provide
 (struct-out derivation-chain)
 (struct-out derivation-step))

;; A derivation chain is a sequence of steps describing how a cell's
;; contradicting state arose through propagator firings (on-network walk via
;; static-reverse-walk) OR speculation-failure trees (sexp translation via
;; derivation-chain-for/union-check). Steps are in CAUSAL READING ORDER:
;; deepest cause first (head of list) → symptom last (tail). Consumers wrap
;; this struct in error structures (e.g., union-exhaustion-error.derivation-
;; chain field; (listof derivation-chain) per Q-B.2 + Q-C.6).
(struct derivation-chain (steps) #:transparent)

;; A single step in the derivation chain represents one propagator's
;; participation in producing the contradicting cell's state (on-network) or
;; one speculation-failure's contribution to the per-branch tree (sexp).
;;
;; Field semantics:
;;   propagator-id   — prop-id of the participating propagator (on-network);
;;                     #f for sexp-fed steps (no propagator); Phase 11b /
;;                     Track 4D may populate for unified post-retirement state
;;   srcloc          — install-time srcloc or #f for propagators installed
;;                     without explicit #:srcloc kwarg (graceful degradation
;;                     per D-3C-7); #f for sexp-fed steps (speculation-failure
;;                     doesn't track srcloc per D-3C.c-1 — Phase 11b enriches)
;;   assumption-ids  — (listof assumption-id) — aids the step represents (for
;;                     on-network: aids the OUTPUT cell was tagged with at
;;                     walk time per Q-A.6; for sexp: (list hypothesis-id)
;;                     from speculation-failure)
;;   assumption-names — (listof string) — decoded via solver-state-assumptions
;;                     lookup (string-datum preferred; symbol name fallback);
;;                     for sexp-fed steps falls back to speculation-failure-
;;                     label when no aid available
;;   residual-cost   — exact-nonnegative-integer | #f — primitive sets #f;
;;                     wrappers may populate via tropical-quantale annotation
;;                     (3C.d / future cost-bounded ATMS work)
(struct derivation-step
  (propagator-id
   srcloc
   assumption-ids
   assumption-names
   residual-cost)
  #:transparent)
