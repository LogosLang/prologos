#lang racket/base

;; low-pnet-to-prop-network.rkt — kernel-pocket-universes Phase 4 Day 10.
;;
;; Walks a Low-PNet IR structure and materializes a runnable prop-network
;; via propagator.rkt primitives. This closes the round-trip:
;;
;;   typed AST → ast-to-low-pnet → Low-PNet IR → THIS PASS → prop-network
;;                                                  → run-to-quiescence → result
;;
;; The motivation (per design doc § 15.6 + § 14 Phase 4 deliverable):
;;
;;   No LLVM in the loop. The IR can be exercised against the canonical
;;   Racket interpreter (propagator.rkt) directly, decoupling IR / lowering
;;   correctness from native-kernel correctness. Round-trip gate: for every
;;   tail-rec / NAF / topology acceptance example,
;;
;;     (run-prop-network (low-pnet-to-prop-network (ast-to-low-pnet ast)))
;;     ≡
;;     (run-prop-network (build-network-direct ast))
;;
;;   produces the same final cell values. If they diverge, the bug is in
;;   the lowering, not the kernel.
;;
;; Scope (Phase 4 Day 10):
;;   - cell-decl       → net-new-cell with domain-appropriate merge fn
;;   - propagator-decl → net-add-propagator with kernel-* fire-fn
;;   - dep-decl        → no-op (subscription is implicit on net-add-propagator,
;;                       same as low-pnet-to-llvm.rkt's treatment)
;;   - write-decl      → net-cell-write (mode='merge) or net-cell-reset
;;                       (mode='reset). Mode tag landed in V1.1 (Day 8).
;;   - entry-decl      → translated to the prop-network cell-id; returned to
;;                       the caller for net-cell-read after run-to-quiescence
;;   - domain-decl     → consulted to pick the merge fn at cell-alloc time
;;                       (currently: int → LWW, bool → LWW; future: per-domain
;;                       merge dispatch via merge-fn-registry)
;;   - meta-decl       → ignored at materialization time (informational only)
;;   - stratum-decl    → unsupported (multi-stratum scheduling deferred;
;;                       same as low-pnet-to-llvm.rkt)
;;   - iter-block-decl → IR node retired 2026-05-02 (kernel-PU Phase 6
;;                       Day 13). lower-tail-rec emits the substrate
;;                       iteration pattern (Variant B; § 5.5) instead;
;;                       any leftover IR will fail to parse.
;;
;; Out of scope:
;;   - The reverse direction (prop-network → Low-PNet) — that's
;;     network-to-low-pnet.rkt (Phase 2.B).
;;   - LLVM emission (low-pnet-to-llvm.rkt).
;;   - Native-kernel feature-parity for cell_reset semantics — the Racket
;;     net-cell-reset is REPLACE without enqueue (matches the kernel's
;;     prologos_cell_reset; see propagator.rkt:1145).

(require racket/match
         racket/list
         "low-pnet-ir.rkt"
         "propagator.rkt")

(provide low-pnet-to-prop-network
         run-low-pnet
         (struct-out low-pnet-materialize-error))

(struct low-pnet-materialize-error exn:fail (decl reason) #:transparent)

(define (materialize-error! d reason)
  (raise (low-pnet-materialize-error
          (format "low-pnet-to-prop-network cannot materialize ~v: ~a" d reason)
          (current-continuation-marks)
          d
          reason)))

;; ============================================================
;; Domain → merge function
;; ============================================================
;;
;; The int and bool domains both use LWW (last-write-wins) i64 / bool
;; semantics in the Zig kernel (see runtime/prologos-runtime.zig
;; DOMAIN_LWW_I64 / DOMAIN_MIN_I64). For Racket-side execution the
;; merge function is `(lambda (old new) new)` — same observable behavior
;; for ascending sequences and the LWW substitution case. A future track
;; can wire merge-fn-registry to handle structural-domain cells.

(define (lww-merge-fn _old new) new)

;; min-merge i64 domain (Phase 1 Day 1 added DOMAIN_MIN_I64 in the kernel
;; for non-vacuous merge-vs-reset distinguishability tests). Surfaces here
;; as a separate merge fn so cells declared with this domain commute under
;; net-cell-write.
(define (min-merge-fn old new) (if (< new old) new old))

;; domain-merge-fn : domain-decl → (Any Any → Any)
(define (domain-merge-fn dom)
  (case (domain-decl-merge-fn-tag dom)
    [(kernel-merge-int)        lww-merge-fn]   ; LWW i64
    [(kernel-merge-int-monotone) lww-merge-fn] ; alias used by ast-to-low-pnet
    [(kernel-merge-bool)       lww-merge-fn]   ; LWW bool (no separate bool domain in kernel)
    [(kernel-min-merge-int)    min-merge-fn]   ; DOMAIN_MIN_I64
    [else
     ;; Default to LWW so unknown domains are still runnable; surfaces as a
     ;; soft warning at materialize time rather than a hard error.
     lww-merge-fn]))

;; ============================================================
;; Fire-fn registry: kernel-* tag → Racket fire-fn factory
;; ============================================================
;;
;; Each entry is keyed by (cons tag arity) and returns a function
;; (in-cids out-cids → fire-fn). The fire-fn is `(network → network)`,
;; following the convention of propagator.rkt's net-add-propagator.
;;
;; Mirrors runtime/prologos-runtime.zig's fire_against_snapshot switch.
;; The Zig switch is the source of truth; this table must stay in sync.
;; Cross-reference: low-pnet-to-llvm.rkt's FIRE-FN-TAG-REGISTRY-{1-1,2-1,3-1}.

(define (fire-1-1 op)
  ;; op : (i64 → i64). Returns a fire-fn factory.
  (lambda (in-cids out-cids)
    (define a (car in-cids))
    (define r (car out-cids))
    (lambda (net)
      (net-cell-write net r (op (net-cell-read net a))))))

(define (fire-2-1 op)
  (lambda (in-cids out-cids)
    (define a (car in-cids))
    (define b (cadr in-cids))
    (define r (car out-cids))
    (lambda (net)
      (net-cell-write net r (op (net-cell-read net a) (net-cell-read net b))))))

(define (fire-3-1 op)
  (lambda (in-cids out-cids)
    (define a (car in-cids))
    (define b (cadr in-cids))
    (define c (caddr in-cids))
    (define r (car out-cids))
    (lambda (net)
      (net-cell-write net r (op (net-cell-read net a)
                                (net-cell-read net b)
                                (net-cell-read net c))))))

;; Bool → 0/1 normalization for kernel-int-{eq,lt,le}.
(define (bool->i64 b) (if b 1 0))
(define (i64->bool i) (not (zero? i)))

;; Truncated division — matches Zig's @divTrunc (truncate towards zero).
(define (int-div-trunc a b)
  (cond
    [(zero? b) (error 'int-div-trunc "division by zero")]
    [(or (and (>= a 0) (>= b 0))
         (and (<= a 0) (<= b 0)))
     (quotient a b)]
    [else
     ;; Mixed-sign: Racket's `quotient` truncates towards zero too, so
     ;; this is identity. Kept explicit for clarity.
     (quotient a b)]))

(define FIRE-FN-FACTORY-TABLE
  (hasheq
   ;; (1,1) shape — input arity 1, output arity 1
   'kernel-identity (cons 1 (fire-1-1 (lambda (a) a)))
   'kernel-int-neg  (cons 1 (fire-1-1 -))
   'kernel-int-abs  (cons 1 (fire-1-1 abs))
   ;; (2,1) shape
   'kernel-int-add  (cons 2 (fire-2-1 +))
   'kernel-int-sub  (cons 2 (fire-2-1 -))
   'kernel-int-mul  (cons 2 (fire-2-1 *))
   'kernel-int-div  (cons 2 (fire-2-1 int-div-trunc))
   'kernel-int-eq   (cons 2 (fire-2-1 (lambda (a b) (bool->i64 (= a b)))))
   'kernel-int-lt   (cons 2 (fire-2-1 (lambda (a b) (bool->i64 (< a b)))))
   'kernel-int-le   (cons 2 (fire-2-1 (lambda (a b) (bool->i64 (<= a b)))))
   ;; (3,1) shape
   'kernel-select   (cons 3 (fire-3-1 (lambda (c t e) (if (i64->bool c) t e))))))

;; ============================================================
;; Materialization
;; ============================================================

(define (low-pnet-to-prop-network lp [initial-fuel 1000000])
  (unless (low-pnet? lp)
    (error 'low-pnet-to-prop-network "expected low-pnet, got ~v" lp))
  (validate-low-pnet lp)  ; raises if malformed
  (define nodes (low-pnet-nodes lp))

  ;; Phase 4 Day 10: refuse stratum-decl (multi-stratum deferred).
  ;; iter-block-decl handler RETIRED 2026-05-02 (Phase 6 Day 13) — the
  ;; IR node itself is gone; any program containing it now fails at
  ;; parse-low-pnet (unknown decl head).
  (for ([n (in-list nodes)])
    (cond
      [(stratum-decl? n)
       (materialize-error! n "stratum-decl materialization deferred")]))

  ;; Index domain-decls by id so cell-decl can resolve its merge fn.
  (define domains-by-id
    (for/hash ([d (in-list (filter domain-decl? nodes))])
      (values (domain-decl-id d) d)))

  (define cell-decls       (filter cell-decl? nodes))
  (define prop-decls       (filter propagator-decl? nodes))
  (define write-decls      (filter write-decl? nodes))
  (define entry            (findf entry-decl? nodes))
  (unless entry
    (error 'low-pnet-to-prop-network "no entry-decl in Low-PNet"))

  ;; Step 1: allocate cells. Build a map low-pnet cell-decl id → real
  ;; prop-network cell-id (the cell-id struct from propagator.rkt). Cells
  ;; are allocated in declaration order — validate-low-pnet (V10) ensures
  ;; this is well-defined.
  ;;
  ;; Init-value normalization: matches the LLVM lowering pass
  ;; (low-pnet-to-llvm.rkt:145-154) — bool init-values flow as 0 or 1
  ;; rather than #f/#t, so kernel-select / kernel-int-{eq,lt,le} all see
  ;; consistent i64 cells. Without this, cells initialized via
  ;; (expr-true)/(expr-false) hold Racket booleans and downstream fires
  ;; like (zero? #t) raise contract-violation. The Zig kernel stores bool
  ;; cells as i64; this normalization keeps the Racket interpreter
  ;; observationally identical for the round-trip gate.
  (define (init-value-normalize v)
    (cond [(exact-integer? v) v]
          [(eq? v #t) 1]
          [(eq? v #f) 0]
          [else v]))  ; pass through anything else (untouched for unsupported types)
  (define-values (net-after-cells low-id->prop-cid)
    (for/fold ([net (make-prop-network initial-fuel)]
               [m (hash)])
              ([c (in-list cell-decls)])
      (define dom (hash-ref domains-by-id (cell-decl-domain-id c) #f))
      (define merge-fn (if dom (domain-merge-fn dom) lww-merge-fn))
      (define init (init-value-normalize (cell-decl-init-value c)))
      (define-values (net+ cid)
        (net-new-cell net init merge-fn))
      (values net+ (hash-set m (cell-decl-id c) cid))))

  ;; Step 2: install propagators. dep-decls are no-ops here (the
  ;; subscription happens implicitly inside net-add-propagator on the
  ;; declared input cells).
  (define net-after-props
    (for/fold ([net net-after-cells])
              ([p (in-list prop-decls)])
      (define tag (propagator-decl-fire-fn-tag p))
      (define entry-fac (hash-ref FIRE-FN-FACTORY-TABLE tag #f))
      (unless entry-fac
        (materialize-error!
         p
         (format "fire-fn-tag '~a' has no Racket fire-fn implementation. Supported (1,1): kernel-{identity,int-neg,int-abs}. Supported (2,1): kernel-int-{add,sub,mul,div,eq,lt,le}. Supported (3,1): kernel-select."
                 tag)))
      (define expected-arity (car entry-fac))
      (define factory (cdr entry-fac))
      (define low-ins (propagator-decl-input-cells p))
      (define low-outs (propagator-decl-output-cells p))
      (unless (= (length low-ins) expected-arity)
        (materialize-error!
         p
         (format "fire-fn-tag '~a' expects ~a inputs but propagator-decl has ~a"
                 tag expected-arity (length low-ins))))
      (unless (= (length low-outs) 1)
        (materialize-error!
         p
         (format "fire-fn-tag '~a' is single-output; propagator-decl has ~a outputs"
                 tag (length low-outs))))
      (define real-ins (map (lambda (x) (hash-ref low-id->prop-cid x)) low-ins))
      (define real-outs (map (lambda (x) (hash-ref low-id->prop-cid x)) low-outs))
      (define fire-fn (factory real-ins real-outs))
      (define-values (net+ _pid)
        (net-add-propagator net real-ins real-outs fire-fn
                            #:fire-fn-tag tag))
      net+))

  ;; Step 3: apply write-decls. Mode tag (V1.1, Day 8) dispatches between
  ;; net-cell-write (merge) and net-cell-reset (reset). Write values are
  ;; normalized the same way as cell-decl init-values (bool → 0/1) for
  ;; LLVM-pipeline parity.
  (define net-after-writes
    (for/fold ([net net-after-props])
              ([w (in-list write-decls)])
      (define cid (hash-ref low-id->prop-cid (write-decl-cell-id w)))
      (define v (init-value-normalize (write-decl-value w)))
      (case (write-decl-mode w)
        [(merge) (net-cell-write net cid v)]
        [(reset) (net-cell-reset net cid v)]
        [else (materialize-error!
               w
               (format "unknown write-decl mode ~v" (write-decl-mode w)))])))

  ;; Return the network + the prop-network cell-id for the entry-decl's
  ;; main cell. Caller drives run-to-quiescence and reads.
  (values net-after-writes
          (hash-ref low-id->prop-cid (entry-decl-main-cell-id entry))))

;; ============================================================
;; run-low-pnet : low-pnet → Any
;; ============================================================
;;
;; One-shot helper for the round-trip gate: materialize, run-to-quiescence,
;; read the entry cell. Returns the entry cell's final value (raw).

(define (run-low-pnet lp [initial-fuel 1000000])
  (define-values (net entry-cid) (low-pnet-to-prop-network lp initial-fuel))
  (define quiesced (run-to-quiescence net))
  (net-cell-read quiesced entry-cid))
