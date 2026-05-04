#lang racket/base

;;;
;;; preduce-hybrid.rkt — PReduce-lite compile-expr targeting the hybrid
;;; Racket-Zig runtime instead of the Racket-side propagator.rkt.
;;;
;;; Phase 8 (load-bearing) deliverable: demonstrate end-to-end that an
;;; elaborated Prologos AST compiles to a propagator network in the
;;; Zig kernel, runs to quiescence, and produces a result identical
;;; to what (preduce e) and (nf e) produce on the Racket-side runtime.
;;;
;;; This module currently supports a narrow subset (literals + Int
;;; arithmetic + ann); full coverage matching preduce.rkt's ~120 AST
;;; cases is a fast-follow expansion. The minimum-viable scope proves
;;; the architecture and unlocks the differential-gate methodology.
;;;
;;; Architecture:
;;;   1. compile-expr-hybrid : expr × env × () → cell-id (kernel-side)
;;;      Recurses on AST, calls kernel APIs to alloc cells / install
;;;      propagators. For each unique fire-fn pattern, we register a
;;;      Racket callback at a fresh tag the first time it's needed.
;;;   2. preduce-hybrid : expr → expr
;;;      Resets kernel state, compiles, runs to quiescence, reads
;;;      the result cell, unboxes back to a Prologos AST value.
;;;
;;; Cross-references:
;;;   docs/tracking/2026-05-03_HYBRID_RUNTIME_DESIGN.md (the design)
;;;   racket/prologos/preduce.rkt (the Racket-side reducer; reference)
;;;   racket/prologos/runtime-bridge.rkt (FFI layer)

(require racket/match
         "syntax.rkt"
         "runtime-bridge.rkt")

(provide preduce-hybrid
         preduce-hybrid-supported?)

;; ====================================================================
;; Tag registry — assign a fresh kernel tag per fire-fn pattern
;; ====================================================================
;;
;; We reserve tag 0 for kernel-native int-add (already built in to
;; the Zig kernel; no callback overhead). Tags 1..7 are kernel-native
;; for sub/mul/div/eq/lt/le/select. Tags 8..15 are Racket callbacks
;; we register on first use. (N_TAGS=16 in the kernel; if we exceed
;; this we'd need to bump the kernel limit.)

;; Built-in tags (must match prologos-runtime-hybrid.zig:register_built_ins).
;; Shape 1-1 tag 0 is kernel-native identity — used as a zero-overhead
;; bridge for app/boolrec/projection result-forwarding (Phase 10).
(define KERNEL-IDENTITY-TAG 0)
(define KERNEL-INT-ADD-TAG  0)
(define KERNEL-INT-SUB-TAG  1)
(define KERNEL-INT-MUL-TAG  2)
(define KERNEL-INT-DIV-TAG  3)
(define KERNEL-INT-EQ-TAG   4)
(define KERNEL-INT-LT-TAG   5)
(define KERNEL-INT-LE-TAG   6)

;; Tags 8+ allocated dynamically for Racket callbacks.
;; Two allocation strategies:
;;
;; (a) Cached/idempotent: `intern-callback-tag!` for fire-fns with NO
;;     captured state — like 'identity or 'bridge. Same tag returned
;;     for the same (name . shape) key.
;;
;; (b) Fresh per call site: `allocate-fresh-callback!` for closure-
;;     capturing fire-fns (app-dispatch, boolrec, projection — each
;;     captures cid-arg / body / env). Each call gets a brand new tag.
;;
;; The kernel's N_TAGS=256 supports up to 256-7 = ~249 fresh callback
;; allocations per program. Plenty for typical preduce-hybrid networks
;; (factorial-iter 1 5 needs ~30; full PReduce-lite test suite ~few hundred).
(define KERNEL-NATIVE-TAG-COUNT 8)  ;; Tags 0-7 are kernel-native (built-in)
(define MAX-N-TAGS 256)
(define next-callback-tag (box KERNEL-NATIVE-TAG-COUNT))
(define interned-callbacks (make-hash))  ;; (cons name shape) -> (cons tag closure-keeper)

(define (next-tag!)
  (define tag (unbox next-callback-tag))
  (when (>= tag MAX-N-TAGS)
    (error 'preduce-hybrid
           "kernel callback tag space exhausted (~a allocated, max ~a). \
Either reset between programs (via reset-handle-table!) or raise N_TAGS \
in runtime/core/profile.zig + rebuild the kernel."
           tag MAX-N-TAGS))
  (set-box! next-callback-tag (+ tag 1))
  tag)

;; Idempotent: same (name . shape) returns the same tag.
;; Use for stateless fire-fns (e.g., bridge identity).
(define (intern-callback-tag! name shape rkt-fire-fn)
  (define key (cons name shape))
  (cond
    [(hash-ref interned-callbacks key #f) => (lambda (entry) (car entry))]
    [else
     (define tag (next-tag!))
     (register-fire-fn! tag shape rkt-fire-fn)
     (hash-set! interned-callbacks key (cons tag rkt-fire-fn))
     tag]))

;; Fresh per call: every invocation registers a new fn-ptr at a new tag.
;; Use for closure-capturing fire-fns (app-dispatch, boolrec arms,
;; projection, ...).
(define (allocate-fresh-callback! shape rkt-fire-fn)
  (define tag (next-tag!))
  (register-fire-fn! tag shape rkt-fire-fn)
  tag)

;; Reset the per-program tag counter. Called from preduce-hybrid at
;; the start of each (preduce-hybrid e) so successive programs don't
;; exhaust tag space. Note: we DON'T un-register old tags from the
;; kernel (the dispatch table entries persist), but the tag indices
;; restart from 8 — the kernel just overwrites the dispatch entry with
;; the new fn-ptr. Old fn-ptrs remain in `registered-fire-fns` keepalive
;; (in runtime-bridge.rkt) until that hash is cleared. We DO clear that
;; here too (via reset-fire-fn-keepalive!) to avoid unbounded growth
;; across many (preduce-hybrid e) calls.
(define (reset-callback-tags!)
  (set-box! next-callback-tag KERNEL-NATIVE-TAG-COUNT)
  (hash-clear! interned-callbacks))

;; ====================================================================
;; Per-program cell-allocator (always via kernel)
;; ====================================================================

(define (alloc-cell-with-value boxed-value)
  (define cid (prologos_cell_alloc))
  (prologos_cell_write cid boxed-value)
  cid)

;; ====================================================================
;; compile-expr-hybrid
;; ====================================================================
;;
;; Returns a kernel cell-id whose value (after run_to_quiescence) is
;; the WHNF of expr. env is a list of cell-ids indexed by de Bruijn
;; (innermost-first), same convention as preduce.rkt.

(define (compile-expr-hybrid e env)
  (match e
    ;; Literals: alloc cell with boxed value.
    [(? expr-int?) (alloc-cell-with-value (box-prologos-value e))]
    [(? expr-true?)
     (alloc-cell-with-value (prologos_cell_box_bool 1))]
    [(? expr-false?)
     (alloc-cell-with-value (prologos_cell_box_bool 0))]
    [(? expr-nat-val?) (alloc-cell-with-value (box-prologos-value e))]
    [(? expr-zero?) (alloc-cell-with-value (prologos_cell_box_nat 0))]

    ;; Annotation erasure
    [(expr-ann inner _) (compile-expr-hybrid inner env)]

    ;; Bound variable
    [(expr-bvar i)
     (when (or (< i 0) (>= i (length env)))
       (error 'preduce-hybrid "bvar ~a out of range (env depth ~a)" i (length env)))
     (list-ref env i)]

    ;; Int arithmetic — use kernel-native built-ins (zero callback overhead)
    [(expr-int-add a b) (compile-int-binary a b env KERNEL-INT-ADD-TAG)]
    [(expr-int-sub a b) (compile-int-binary a b env KERNEL-INT-SUB-TAG)]
    [(expr-int-mul a b) (compile-int-binary a b env KERNEL-INT-MUL-TAG)]
    [(expr-int-div a b) (compile-int-binary a b env KERNEL-INT-DIV-TAG)]
    [(expr-int-eq  a b) (compile-int-binary a b env KERNEL-INT-EQ-TAG)]
    [(expr-int-lt  a b) (compile-int-binary a b env KERNEL-INT-LT-TAG)]
    [(expr-int-le  a b) (compile-int-binary a b env KERNEL-INT-LE-TAG)]

    ;; expr-suc — simple pattern: same kernel as int-add of (inner, 1).
    ;; We register a small Racket callback for the nat-val/zero collapse logic.
    [(expr-suc inner)
     (define cid-in (compile-expr-hybrid inner env))
     (define cid-out (prologos_cell_alloc))
     (prologos_cell_write cid-out (prologos_cell_box_bot))
     (define tag
       (allocate-fresh-callback! 1
         (lambda (boxed-in)
           (cond
             [(= (prologos_cell_value_kind boxed-in) TAG-BOT) boxed-in]
             [else
              (define v (unbox-prologos-value boxed-in))
              (define result
                (cond
                  [(expr-nat-val? v) (expr-nat-val (+ (expr-nat-val-n v) 1))]
                  [(expr-zero? v) (expr-nat-val 1)]
                  [else (expr-suc v)]))
              (box-prologos-value result)]))))
     (prologos_propagator_install_1_1 tag cid-in cid-out)
     cid-out]

    ;; ====================================================================
    ;; Phase 8b expansion: lambdas, application, eliminators, pairs
    ;; ====================================================================
    ;;
    ;; Each compiles to a propagator network using kernel cells; the
    ;; non-trivial logic lives in Racket-callback fire-fns. The kernel
    ;; sees them as opaque function pointers; profiling distinguishes
    ;; built-in (kernel-native) tags 0-7 from registered callback tags 8+.

    ;; expr-lam — alloc a cell with a HANDLE pointing to the closure.
    ;; The closure is a Racket struct (preduce-hybrid-lam) so handle-
    ;; table marshaling routes through TAG-HANDLE.
    [(expr-lam mw type body)
     (alloc-cell-with-value
      (box-racket-value (preduce-hybrid-lam mw type body env)))]

    ;; expr-fvar — inline the global definition (same approach as PReduce-lite).
    ;; Static recursion guard via current-fvar-stack.
    [(expr-fvar name)
     (when (memq name (current-fvar-stack))
       (error 'preduce-hybrid "recursive fvar ~a (Phase 8b doesn't support self-recursive defs)" name))
     (define value-ast ((dynamic-require 'prologos/global-env 'global-env-lookup-value) name))
     (unless value-ast (error 'preduce-hybrid "expr-fvar ~a not in global env" name))
     (parameterize ([current-fvar-stack (cons name (current-fvar-stack))])
       (compile-expr-hybrid value-ast '()))]

    ;; expr-app — dynamic β. Compile f and arg; install a fire-once
    ;; callback on f's cell. When f resolves to a HANDLE pointing to a
    ;; preduce-hybrid-lam, the fire-fn compiles the body in (cons cid-arg
    ;; captured-env) and forwards the result cell via an identity bridge.
    [(expr-app f arg)
     ;; Static β fast-path: if f is statically a lambda, compile body inline.
     (define f-static (statically-reducible-lam f))
     (cond
       [f-static
        (define cid-arg (compile-expr-hybrid arg env))
        (compile-expr-hybrid (expr-lam-body f-static) (cons cid-arg env))]
       [else
        (define cid-f (compile-expr-hybrid f env))
        (define cid-arg (compile-expr-hybrid arg env))
        (define cid-out (prologos_cell_alloc))
        (prologos_cell_write cid-out (prologos_cell_box_bot))
        ;; Track whether the dispatch has fired — propagator fires per
        ;; BSP round on input changes; we must only do the topology
        ;; mutation once (else we'd install duplicate body subnetworks
        ;; on every round). Racket-side flag closes that fire-once gap
        ;; without needing a kernel-level fire-once flag.
        (define fired? (box #f))
        (define tag
          (allocate-fresh-callback! 1
            (lambda (boxed-f)
              (cond
                [(unbox fired?) boxed-f]
                [(= (prologos_cell_value_kind boxed-f) TAG-BOT) boxed-f]
                [else
                 (define f-val (unbox-prologos-value boxed-f))
                 (cond
                   [(preduce-hybrid-lam? f-val)
                    (set-box! fired? #t)
                    (define body (preduce-hybrid-lam-body f-val))
                    (define captured-env (preduce-hybrid-lam-env f-val))
                    (define new-env (cons cid-arg captured-env))
                    (define cid-body (compile-expr-hybrid body new-env))
                    ;; Phase 10 migration: was 'app-bridge Racket cb (~242 ns/fire); now native (~3 ns).
                    (define id-tag KERNEL-IDENTITY-TAG)
                    (prologos_propagator_install_1_1 id-tag cid-body cid-out)
                    boxed-f]
                   [else (error 'preduce-hybrid "app function position not a lambda: ~v" f-val)])]))))
        (prologos_propagator_install_1_1 tag cid-f cid-out)
        cid-out])]

    ;; expr-boolrec — Bool eliminator. Install fire-once-style on target;
    ;; when target resolves to true/false, compile the matching arm and
    ;; forward via identity bridge. Racket-side fired? flag avoids
    ;; double-installing the arm subnetwork on subsequent fires.
    [(expr-boolrec _motive tc fc target)
     (define cid-target (compile-expr-hybrid target env))
     (define cid-out (prologos_cell_alloc))
     (prologos_cell_write cid-out (prologos_cell_box_bot))
     (define fired? (box #f))
     (define tag
       (allocate-fresh-callback! 1
         (lambda (boxed-target)
           (cond
             [(unbox fired?) boxed-target]
             [(= (prologos_cell_value_kind boxed-target) TAG-BOT) boxed-target]
             [else
              (define v (unbox-prologos-value boxed-target))
              (define arm (cond [(expr-true? v) tc] [(expr-false? v) fc] [else #f]))
              (unless arm (error 'preduce-hybrid "boolrec target not Bool: ~v" v))
              (set-box! fired? #t)
              (define cid-arm (compile-expr-hybrid arm env))
              ;; Phase 10 migration: native identity (no callback).
              (define id-tag KERNEL-IDENTITY-TAG)
              (prologos_propagator_install_1_1 id-tag cid-arm cid-out)
              boxed-target]))))
     (prologos_propagator_install_1_1 tag cid-target cid-out)
     cid-out]

    ;; expr-pair — pack fst-cid + snd-cid into a Racket struct, store via handle.
    [(expr-pair a b)
     (define cid-a (compile-expr-hybrid a env))
     (define cid-b (compile-expr-hybrid b env))
     (alloc-cell-with-value
      (box-racket-value (preduce-hybrid-pair cid-a cid-b)))]

    ;; expr-fst / expr-snd — static fast-path when inner is literal pair.
    [(expr-fst inner)
     (cond
       [(expr-pair? inner) (compile-expr-hybrid (expr-pair-fst inner) env)]
       [(expr-ann? inner) (compile-expr-hybrid (expr-fst (expr-ann-term inner)) env)]
       [else (compile-projection inner env 'fst)])]
    [(expr-snd inner)
     (cond
       [(expr-pair? inner) (compile-expr-hybrid (expr-pair-snd inner) env)]
       [(expr-ann? inner) (compile-expr-hybrid (expr-snd (expr-ann-term inner)) env)]
       [else (compile-projection inner env 'snd)])]

    [_ (error 'preduce-hybrid
              "unsupported AST node ~v (Phase 8b scope: literals, int arith, ann, suc, lam, app, fvar, boolrec, pair, fst/snd)"
              e)]))

(define (compile-int-binary a b env tag)
  (define cid-a (compile-expr-hybrid a env))
  (define cid-b (compile-expr-hybrid b env))
  (define cid-out (prologos_cell_alloc))
  (prologos_cell_write cid-out (prologos_cell_box_bot))
  (prologos_propagator_install_2_1 tag cid-a cid-b cid-out)
  cid-out)

;; Phase 8b — closure value carried in cells via handle table.
(struct preduce-hybrid-lam (mw type body env) #:transparent)
(struct preduce-hybrid-pair (fst-cid snd-cid) #:transparent)

;; Recursion guard for fvar inlining (mirrors preduce.rkt's pattern).
(define current-fvar-stack (make-parameter '()))

;; Static fast-path for app: returns the underlying expr-lam if f is
;; statically known to be a lambda (literal, ann-wrapped, or fvar→lam).
(define (statically-reducible-lam f)
  (cond
    [(expr-lam? f) f]
    [(expr-ann? f) (statically-reducible-lam (expr-ann-term f))]
    [(expr-fvar? f)
     (define name (expr-fvar-name f))
     (cond
       [(memq name (current-fvar-stack)) #f]
       [else
        (define v ((dynamic-require 'prologos/global-env 'global-env-lookup-value) name))
        (and v
             (parameterize ([current-fvar-stack (cons name (current-fvar-stack))])
               (statically-reducible-lam v)))])]
    [else #f]))

;; expr-fst/snd projection on a non-static pair value.
(define (compile-projection inner env which)
  (define cid-in (compile-expr-hybrid inner env))
  (define cid-out (prologos_cell_alloc))
  (prologos_cell_write cid-out (prologos_cell_box_bot))
  (define fired? (box #f))
  (define tag
    (allocate-fresh-callback! 1
      (lambda (boxed-pair)
        (cond
          [(unbox fired?) boxed-pair]
          [(= (prologos_cell_value_kind boxed-pair) TAG-BOT) boxed-pair]
          [else
           (define v (unbox-prologos-value boxed-pair))
           (cond
             [(preduce-hybrid-pair? v)
              (set-box! fired? #t)
              (define component-cid
                (case which
                  [(fst) (preduce-hybrid-pair-fst-cid v)]
                  [(snd) (preduce-hybrid-pair-snd-cid v)]))
              ;; Phase 10 migration: native identity.
              (define id-tag KERNEL-IDENTITY-TAG)
              (prologos_propagator_install_1_1 id-tag component-cid cid-out)
              boxed-pair]
             [else (error 'preduce-hybrid "expected pair for ~a projection, got ~v" which v)])]))))
  (prologos_propagator_install_1_1 tag cid-in cid-out)
  cid-out)

;; ====================================================================
;; Top-level entry point
;; ====================================================================

(define (preduce-hybrid e)
  (reset-handle-table!)
  (reset-callback-tags!)
  (define result-cid (compile-expr-hybrid e '()))
  (prologos_run_to_quiescence)
  (define result-boxed (prologos_cell_read result-cid))
  (unbox-prologos-value result-boxed))

;; preduce-hybrid-supported? — quick check for whether this expression
;; is in the Phase 8 minimum-viable subset (no nodes that would error).
;; Used by tests that may run on the hybrid runtime when supported,
;; or fall back to the Racket-side preduce otherwise.
(define (preduce-hybrid-supported? e)
  (match e
    [(? expr-int?) #t]
    [(? expr-true?) #t]
    [(? expr-false?) #t]
    [(? expr-nat-val?) #t]
    [(? expr-zero?) #t]
    [(expr-ann inner _) (preduce-hybrid-supported? inner)]
    [(expr-bvar _) #t]
    [(expr-int-add a b) (and (preduce-hybrid-supported? a) (preduce-hybrid-supported? b))]
    [(expr-int-sub a b) (and (preduce-hybrid-supported? a) (preduce-hybrid-supported? b))]
    [(expr-int-mul a b) (and (preduce-hybrid-supported? a) (preduce-hybrid-supported? b))]
    [(expr-int-div a b) (and (preduce-hybrid-supported? a) (preduce-hybrid-supported? b))]
    [(expr-int-eq  a b) (and (preduce-hybrid-supported? a) (preduce-hybrid-supported? b))]
    [(expr-int-lt  a b) (and (preduce-hybrid-supported? a) (preduce-hybrid-supported? b))]
    [(expr-int-le  a b) (and (preduce-hybrid-supported? a) (preduce-hybrid-supported? b))]
    [(expr-suc inner) (preduce-hybrid-supported? inner)]
    [_ #f]))
