#lang racket/base

;;;
;;; preduce-hybrid.rkt — thin wrapper around the shared compile-expr
;;; from preduce-core/preduce.rkt, parameterized by backend-hybrid
;;; (the Zig-kernel backend).
;;;
;;; **Refactor history**: the original preduce-hybrid.rkt (~407 LOC,
;;; commit 06ce222) was a parallel re-implementation of compile-expr
;;; targeting the kernel — Phase 8b scope only (literals, int arith,
;;; ann, suc, lam, app, fvar, boolrec, pair, fst/snd). It duplicated
;;; preduce.rkt's compile-expr structure but used the FFI primitives
;;; (prologos_cell_alloc / prologos_propagator_install_*) instead of
;;; Racket-side propagator.rkt.
;;;
;;; The 2026-05-04 swappable-backend refactor unified both reducers
;;; under preduce.rkt's compile-expr + a backend interface:
;;;   - backend-racket   threads the actual prop-network struct
;;;   - backend-hybrid   threads a 'hybrid sentinel; cell-IO via FFI
;;; This file is now ~30 LOC of entry-point glue.
;;;
;;; Net effect: all of preduce.rkt's ~120 AST cases (Phases 1–10b)
;;; run on the Zig kernel via the shared compile-expr — the hybrid
;;; backend wraps each fire-fn as a Racket callback at a fresh kernel
;;; tag. Profile-driven migration (Phase 7+) replaces the heaviest
;;; callbacks with native Zig fire-fns over time.
;;;
;;; Cross-references:
;;;   docs/tracking/2026-05-04_PREDUCE_BACKEND_REFACTOR_DESIGN.md
;;;   racket/prologos/preduce-core.rkt (the backend interface)
;;;   racket/prologos/preduce-backend-hybrid.rkt (kernel-bridging backend)
;;;   racket/prologos/preduce.rkt (compile-expr + lattice + helpers)

(require "preduce.rkt"
         "preduce-core.rkt"
         "preduce-backend-hybrid.rkt"
         "runtime-bridge.rkt")

(provide preduce-hybrid
         preduce-hybrid-supported?)

;; preduce-hybrid : expr → expr
;;   Reduce expr to WHNF via the Zig kernel's propagator network.
;;   Uses preduce.rkt's compile-expr with backend-hybrid.
(define (preduce-hybrid e)
  (with-backend backend-hybrid
    (define net0 (b-fresh-net))
    (define-values (result-cid net1) (compile-expr e '() net0))
    (define net-final (b-run-to-quiescence net1))
    (b-read net-final result-cid)))

;; preduce-hybrid-supported? : expr → boolean
;;   Returns #t iff this expression is in scope for the hybrid backend.
;;   Post-refactor: the hybrid backend covers everything compile-expr
;;   covers (Phases 1–10b), since fire-fns become Racket callbacks for
;;   any case not yet migrated to a kernel-native fire-fn.
;;
;;   Pre-refactor preduce-hybrid had a Phase-8b-only filter; that's
;;   obsolete now. We keep the predicate (returning #t for everything
;;   compile-expr handles) so the export surface is preserved for any
;;   external consumer; the predicate is conservative (errors-on-call
;;   for genuinely unsupported nodes — same as preduce.rkt).
(define (preduce-hybrid-supported? e)
  ;; Trust compile-expr's coverage: anything preduce.rkt supports,
  ;; preduce-hybrid supports too (via callback dispatch).
  #t)
