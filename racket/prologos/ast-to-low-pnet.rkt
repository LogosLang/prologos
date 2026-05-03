#lang racket/base

;; ast-to-low-pnet.rkt — Typed AST → Low-PNet IR translator.
;;
;; Bridges Prologos's typed AST (post-elaboration `expr-*` structs) into
;; a propagator-network shape suitable for Low-PNet → LLVM IR lowering.
;; This is the missing piece that lets `def main : Int := [int+ 1 2]`
;; compile to a binary via the .pnet pipeline (rather than via the
;; sequential AST-to-LLVM Tier 0–3 path).
;;
;; Translation strategy: ANF-style flattening. Each `expr-int-*` arithmetic
;; node becomes (per subexpression) one cell + one propagator:
;;
;;   [int+ a b]       →  cells [a, b, r]; propagator (kernel-int-add, [a,b]→r)
;;   [int+ [int* 2 3] 4]
;;                    →  cells [2, 3, m, 4, r]
;;                        propagator (kernel-int-mul, [c2,c3]→cm)
;;                        propagator (kernel-int-add, [cm,c4]→cr)
;;
;; The result-cell of the outermost expression becomes the program's
;; entry-decl.
;;
;; Supported AST nodes (this commit + 2026-05-02 let-binding extension):
;;   expr-int n              — Int literal
;;   expr-int-add a b        — binary arithmetic
;;   expr-int-sub a b
;;   expr-int-mul a b
;;   expr-int-div a b
;;   expr-true / expr-false  — Bool literals
;;   expr-ann inner type     — strip the annotation
;;   expr-bvar i             — looked up in current env
;;   (expr-app (expr-lam mult type body) arg)
;;                           — beta-redex, treated as let-binding:
;;                             arg is translated to a cell, that cell-id is
;;                             pushed onto env, body translates in extended
;;                             env. m0 args are not evaluated; their env
;;                             slot is 'erased and any bvar referencing it
;;                             raises ast-translation-error.
;;
;; Unsupported nodes raise; the caller should treat the program as
;; outside the supported subset and report so.

(require racket/match
         racket/list
         "syntax.rkt"
         "low-pnet-ir.rkt"
         "global-env.rkt"
         (only-in "macros.rkt"
                  lookup-ctor
                  lookup-type-ctors
                  ctor-meta
                  ctor-meta-type-name
                  ctor-meta-field-types
                  ctor-meta-is-recursive
                  ctor-meta-branch-index))

(provide ast-to-low-pnet
         (struct-out ast-translation-error))

(struct ast-translation-error exn:fail (node hint) #:transparent)

(define (translate-error! node hint)
  (raise (ast-translation-error
          (format "ast-to-low-pnet cannot translate ~v: ~a" node hint)
          (current-continuation-marks)
          node
          hint)))

(define (peel-expr-ann e)
  (match e
    [(expr-ann inner _) (peel-expr-ann inner)]
    [_ e]))

(define (expr-proof-refl? p)
  (expr-refl? (peel-expr-ann p)))

(define (lowering-type-only! expr what)
  (translate-error!
   expr
   (format "lowering: ~a — type-level only (cannot compile as runtime value)" what)))

(define (lowering-deferred-substrate! expr what)
  (translate-error!
   expr
   (format "lowering deferred (~a): requires substrate beyond current kernel \
(heap/GC, trait monomorphization, or extra Zig primitives)" what)))

;; ============================================================
;; Builder state
;; ============================================================
;;
;; A small mutable accumulator holds the cell-decls, propagator-decls,
;; and dep-decls being emitted as we walk the AST. After the walk we
;; assemble these into the final low-pnet structure.

(struct builder ([cells #:auto #:mutable]
                 [props #:auto #:mutable]
                 [deps #:auto #:mutable]
                 [next-cid #:auto #:mutable]
                 [next-pid #:auto #:mutable]
                 ;; Sprint F.5: per-cell-id depth (longest propagator path
                 ;; from initial cells to this cell). emit-cell sets to 0;
                 ;; emit-propagator updates output cell's depth = max(input
                 ;; depths) + 1. Used by lower-tail-rec's lag-matching
                 ;; bridge insertion.
                 [depths #:auto #:mutable]
                 ;; Sprint F.6: bridge cache for lift-cell-to-depth coalescing.
                 ;; Maps source-cell-id → (Listof (cons depth bridge-cid)),
                 ;; representing all identity-bridge cells reachable from
                 ;; that source. When multiple consumers lift the same
                 ;; source to (possibly different) target depths, they
                 ;; share the bridge chain instead of duplicating it.
                 ;;
                 ;; bridge-cache is the live coalescing structure used by
                 ;; lift-cell-to-depth (Sprint F.6). Read by find-cached-below
                 ;; / lookup-bridge / cache-bridge!. Currently exercised by
                 ;; lower-tail-rec's depth-alignment within the iteration body.
                 [bridge-cache #:auto #:mutable]
                 ;; tail-rec-count: tracks how many tail-recursive call sites
                 ;; were lowered to the substrate iteration pattern. Used by
                 ;; ast-to-low-pnet to emit a meta-decl signature
                 ;; (tail-rec-pattern: lww-feedback-v1) iff > 0. The signature
                 ;; is the verifiable test artifact for kernel-PU Phase 4
                 ;; Day 9 — confirms lower-tail-rec emitted the dissolved
                 ;; substrate pattern (cells + identity-feedback propagators)
                 ;; rather than the never-shipped Sprint G iter-block-decl
                 ;; pattern. See docs/tracking/2026-05-02_KERNEL_POCKET_UNIVERSES.md
                 ;; § 5.5 and § 14.1 Day 9.
                 [tail-rec-count #:auto #:mutable]
                 ;; lowering-yolo M3 (2026-05-02): cell-ids allocated for
                 ;; main's parameters, in OUTERMOST-FIRST declaration
                 ;; order. Empty list for closed main (the historical
                 ;; case). Read by ast-to-low-pnet to emit the
                 ;; (meta-decl input-cells (cid0 cid1 ...)) +
                 ;; (meta-decl main-prints-result #t) signature consumed
                 ;; by low-pnet-to-llvm. See
                 ;; docs/tracking/2026-05-02_LOWERING_INPUT_OUTPUT.md.
                 [input-cells #:auto #:mutable]
                 ;; lowering-yolo M6 (2026-05-02): list of
                 ;; (input-cell-id . target-cell-id) pairs. When tail-rec
                 ;; lowering needs to seed a state cell with the runtime
                 ;; argv value, it allocates a FRESH state cell (rather
                 ;; than reusing the input cell directly — that breaks
                 ;; if the same input is consumed by multiple iteration
                 ;; sites, which all race to write back to it via their
                 ;; feedback identities). The mirror entry says "after
                 ;; argv-write to src-input, also write the same value
                 ;; to dst". Emitted as
                 ;;   (meta-decl input-cell-mirrors ((src . dst) ...))
                 ;; and consumed by low-pnet-to-llvm to inject one extra
                 ;; cell_write(dst, argv_value) per pair, immediately
                 ;; after the canonical cell_write(src, argv_value). One
                 ;; src can map to many dsts (state-cell + lagged prev-cell
                 ;; at minimum, and across multiple iteration sites).
                 [input-cell-mirrors #:auto #:mutable]
                 ;; lowering-yolo M6 (2026-05-02): map from state-cell-id
                 ;; to the input-cell-id that seeded it. Lower-tail-rec
                 ;; mirrors the same argv write onto each lagged prev cell
                 ;; when the state slot came from a parameter, so BSP
                 ;; round 1 reads the runtime counter (not placeholder 0).
                 [state-cell-input-source #:auto #:mutable])
  #:auto-value '()
  #:transparent)

(define (make-builder)
  (define b (builder))
  (set-builder-next-cid! b 0)
  (set-builder-next-pid! b 0)
  (set-builder-depths! b (hasheq))
  (set-builder-bridge-cache! b (hasheq))
  ;; Phase 6 Day 13 (kernel-PU rev 2.1, § 9.1 Category B): vestigial
  ;; `iter-blocks` builder field deleted alongside iter-block-decl.
  ;; lower-tail-rec emits the substrate iteration pattern (cells +
  ;; identity-feedback propagators) directly into builder-cells /
  ;; builder-props; no separate iter-block accumulator is needed.
  (set-builder-tail-rec-count! b 0)
  (set-builder-input-cells! b '())
  (set-builder-input-cell-mirrors! b '())
  (set-builder-state-cell-input-source! b (hasheqv))
  b)

;; lowering-yolo M6 helper: record a (src . dst) mirror pair on the
;; builder. src is an input cell id (must be in builder-input-cells);
;; dst is any cell id whose runtime initial value should match src's
;; runtime argv value. See builder-input-cell-mirrors docstring.
(define (record-input-mirror! b src-cid dst-cid)
  (set-builder-input-cell-mirrors!
   b (cons (cons src-cid dst-cid)
           (builder-input-cell-mirrors b))))

;; lowering-yolo M6 helper: record that state-cid was seeded from
;; input-cid. Used by emit-feedback to also mirror the corresponding
;; next-cell from the same input, preventing a round-1 feedback from
;; overwriting state-cid's argv value with the next-cell's placeholder.
(define (record-state-input-source! b state-cid input-cid)
  (set-builder-state-cell-input-source!
   b (hash-set (builder-state-cell-input-source b) state-cid input-cid)))

(define (state-input-source b state-cid)
  (hash-ref (builder-state-cell-input-source b) state-cid #f))

;; True iff `cid` is one of main's input cells (i.e., its runtime
;; value comes from argv at @main entry).
(define (input-cell? b cid)
  (and (memv cid (builder-input-cells b)) #t))

(define (cell-depth b cid)
  (hash-ref (builder-depths b) cid 0))

(define (set-cell-depth! b cid d)
  (set-builder-depths! b (hash-set (builder-depths b) cid d)))

;; Sprint F.6 bridge cache helpers.

;; Return the cached bridge from `src-cid` at exactly `target-depth`,
;; or #f if no such bridge exists.
(define (lookup-bridge b src-cid target-depth)
  (define entries (hash-ref (builder-bridge-cache b) src-cid '()))
  (for/first ([entry (in-list entries)] #:when (= (car entry) target-depth))
    (cdr entry)))

;; Return the cached bridge from `src-cid` at the highest depth strictly
;; less than `target-depth`, or `src-cid` itself if no such bridge.
;; This is the starting point for extending a chain.
(define (find-cached-below b src-cid target-depth)
  (define entries (hash-ref (builder-bridge-cache b) src-cid '()))
  (define candidates
    (filter (lambda (e) (< (car e) target-depth)) entries))
  (cond
    [(null? candidates) src-cid]
    [else
     ;; argmax of car (depth)
     (define-values (best _)
       (for/fold ([best (car candidates)] [best-d (caar candidates)])
                 ([c (in-list (cdr candidates))])
         (if (> (car c) best-d) (values c (car c)) (values best best-d))))
     (cdr best)]))

;; Record bridge-cid as reachable from src-cid at its current depth.
(define (cache-bridge! b src-cid bridge-cid)
  (define d (cell-depth b bridge-cid))
  (set-builder-bridge-cache!
   b (hash-update (builder-bridge-cache b) src-cid
                  (lambda (entries) (cons (cons d bridge-cid) entries))
                  '())))

;; Sprint F.6: post-build invariant. Every multi-input propagator's
;; input cells should have equal depth — F.5's emit-aligned-propagator!
;; should have lifted them via identity bridges so that's the case.
;;
;; Exemptions:
;;   - kernel-identity (1-input): no fan-in to align.
;;   - kernel-int-{neg,abs} (1-input): same.
;;   - Any 1-input propagator: no peer inputs.
;;
;; If this assertion fires, F.5's lifting missed a case — the program
;; would silently produce wrong values via stale-snapshot reads. The
;; assertion catches the bug at compile time rather than at run time.
;;
;; Exemption: tail-rec self-loop selects (`kernel-select` writing back
;; into one of its input cells). The freeze operand stays at logical
;; depth 0 while cond/step are lifted — intentional; see lower-tail-rec.
(define (kernel-select-self-loop? p)
  (and (propagator-decl? p)
       (eq? (propagator-decl-fire-fn-tag p) 'kernel-select)
       (let ([ins (propagator-decl-input-cells p)]
             [outs (propagator-decl-output-cells p)])
         (and (= (length ins) 3)
              (= (length outs) 1)
              (memv (car outs) ins)))))

(define (assert-depth-balance-invariant! b)
  (for ([p (in-list (builder-props b))]
        #:when (propagator-decl? p))
    (define ins (propagator-decl-input-cells p))
    (when (>= (length ins) 2)
      (define depths (map (lambda (c) (cell-depth b c)) ins))
      (unless (or (apply = depths) (kernel-select-self-loop? p))
        (translate-error!
         p
         (format "F.6 depth-balance invariant violated: propagator ~a (~a) \
has inputs at differing depths ~v. F.5's emit-aligned-propagator! should \
have inserted identity bridges to lift shorter inputs. This is a bug in \
the lowering; please file an issue with the source program."
                 (propagator-decl-id p)
                 (propagator-decl-fire-fn-tag p)
                 (map cons ins depths)))))))

;; Find the cell-decl for a given cell-id. Linear scan; only used by
;; lift-cell-to-depth which runs O(N) times in lower-tail-rec.
(define (find-cell-decl b cid)
  (for/first ([c (in-list (builder-cells b))]
              #:when (and (cell-decl? c) (= (cell-decl-id c) cid)))
    c))

(define (fresh-cid! b)
  (define id (builder-next-cid b))
  (set-builder-next-cid! b (+ 1 id))
  id)

(define (fresh-pid! b)
  (define id (builder-next-pid b))
  (set-builder-next-pid! b (+ 1 id))
  id)

(define (emit-cell! b dom-id init-value)
  (define id (fresh-cid! b))
  (set-builder-cells! b (cons (cell-decl id dom-id init-value)
                              (builder-cells b)))
  ;; F.5: new cells start at depth 0 (no propagator chain leading to
  ;; them). emit-propagator updates the output cell's depth.
  (set-cell-depth! b id 0)
  id)

(define (emit-propagator! b in-cids out-cid tag
                          #:skip-depth-update? [skip-depth-update? #f])
  (define pid (fresh-pid! b))
  (set-builder-props! b
                      (cons (propagator-decl pid in-cids
                                             (list out-cid) tag 0)
                            (builder-props b)))
  ;; dep-decls: one per input cell, in input order.
  (set-builder-deps! b
                     (append (reverse (for/list ([cid (in-list in-cids)])
                                        (dep-decl pid cid 'all)))
                             (builder-deps b)))
  ;; F.5: out-cid's depth = max(input depths) + 1. The longest
  ;; propagator chain from initial cells to out-cid.
  ;;
  ;; #:skip-depth-update? — pass #t for feedback edges (identity
  ;; propagators that close the iteration loop by writing back to a
  ;; state cell). Without this, the feedback would overwrite the
  ;; state cell's depth with a high value, breaking depth-aware lift
  ;; logic for any future build that references that state cell.
  ;; State cells are conceptually depth 0 perpetually.
  (unless skip-depth-update?
    (define max-in-depth
      (for/fold ([m 0]) ([c (in-list in-cids)])
        (max m (cell-depth b c))))
    (set-cell-depth! b out-cid (+ max-in-depth 1)))
  pid)

;; ============================================================
;; Translation
;; ============================================================
;;
;; build : AST × builder × dom-id × env → cell-id
;;   Recursively translates an expression. Returns the cell-id whose
;;   value (after run-to-quiescence) holds the expression's result.
;;
;; env is a list of cell-ids, indexed by de Bruijn index. expr-bvar i
;; reads (list-ref env i). The 'erased entry stands in for m0-bound
;; values that don't exist at runtime; any bvar that resolves to it
;; raises ast-translation-error.
;;
;; The dom-id is the int-domain id (we use 0 for Int, 1 for Bool — see
;; the Low-PNet assembly below). Phase 2.D supports only these two.

(define INT-DOMAIN-ID 0)
(define BOOL-DOMAIN-ID 1)

;; ============================================================
;; Value-tree representation (Sprint F.2, 2026-05-01)
;; ============================================================
;;
;; build returns a "value-tree" (vtree): either a single cell-id
;; (representing a scalar value like an Int or Bool) or a list of
;; vtrees (representing a non-dependent pair / nested pair).
;;
;;   vtree ::= cell-id (exact-nonnegative-integer)
;;           | (Listof vtree)        ; pair with components
;;
;; Examples:
;;   42                  scalar Int → cell-id (e.g. 5)
;;   <a; b>              pair → (list ca cb)
;;   <<a; b>; c>         nested pair → (list (list ca cb) cc)
;;
;; Per-component decomposition: an N-component pair becomes N flat
;; cells. fst/snd index into the list. Operations on pairs (e.g.
;; select on a pair-typed branch) decompose into per-component
;; operations.
;;
;; Scope: NON-DEPENDENT pairs only. Dependent Sigma `<n:Nat * Vec(n)>`
;; (where snd-type depends on fst's value) is intentionally NOT
;; supported — see docs/tracking/2026-05-01_SH_LOWERING_FEATURE_MAP.md.
;; In practice the elaborator has discharged dependent typing into
;; proofs that get erased before lowering; what arrives here is a
;; tree of concrete cells.

(define (vtree-scalar? vt) (exact-integer? vt))

;; ============================================================
;; Gate 1 (rev 1.0): tagged-union vtree — defunctionalized ADT
;; ============================================================
;;
;; A `ctor-vt` represents a value of an algebraic data type (ADT).
;; Layout: one tag cell + a flat list of slot cells (the type's
;; total slot count = sum of all ctor arities). Every value of a
;; given ADT type shares the same shape, regardless of which ctor
;; it was constructed with — slots a ctor doesn't use stay at the
;; default value (0).
;;
;; This shape uniformity is what lets `select` combine two vtrees
;; of the same type from then/else branches without runtime tag
;; reshape.
;;
;; type-name : symbol — the ADT type (e.g. 'Maybe, 'Either)
;; tag-cid   : i64 cell holding the runtime branch index (0..n-1)
;; slot-cids : list of i64 cells, length = type-flat-slot-count(type)
(struct ctor-vt (type-name tag-cid slot-cids) #:transparent)

(define (assert-scalar! vt expr context)
  (unless (vtree-scalar? vt)
    (translate-error!
     expr
     (format "~a expected a scalar (Int or Bool) but got a ~a value. \
fst/snd projection or destructuring is required first."
             context
             (cond
               [(ctor-vt? vt) (format "tagged-union (~a)" (ctor-vt-type-name vt))]
               [(list? vt)    "pair-typed"]
               [else          "unknown"]))))
  vt)

(define (assert-pair! vt expr context)
  (when (vtree-scalar? vt)
    (translate-error!
     expr
     (format "~a expected a pair-typed value but got a scalar." context)))
  (unless (= (length vt) 2)
    (translate-error!
     expr
     (format "~a expected a 2-component pair but got ~a components."
             context (length vt))))
  vt)

;; ============================================================
;; Tail-recursion recognition (Sprint E.3)
;; ============================================================
;;
;; Recognizes the elaborated AST shape for a tail-recursive function:
;;
;;   (expr-lam mw T1
;;    (expr-lam mw T2
;;     ...
;;     (expr-lam mw Tk
;;      (expr-reduce COND-EXPR
;;       (list (expr-reduce-arm BASE-TAG 0 BASE-RESULT)
;;             (expr-reduce-arm STEP-TAG 0
;;                              (expr-app^k (expr-fvar SELF-NAME)
;;                                          STEP-ARG-1 ... STEP-ARG-k)))
;;       _structural?))))
;;
;; The two arms can appear in either order. SELF-NAME must equal the
;; name of the function being recognized. All k Tᵢ must be expr-Int.
;; The BASE arm's body must NOT contain a recursive call to SELF-NAME
;; (it's the terminal case). The STEP arm's body must be exactly a
;; saturated call to SELF-NAME with k arguments.

(struct tail-rec-shape (arg-types
                        cond-expr
                        base-arm-tag       ; 'true or 'false
                        base-result
                        step-args)
  #:transparent)

;; Peel any number of expr-lam binders. Returns (values arg-types body)
;; where arg-types is in OUTERMOST-FIRST order.
(define (peel-lambdas e)
  (let loop ([e e] [acc '()])
    (match e
      [(expr-lam 'mw type body) (loop body (cons type acc))]
      [_ (values (reverse acc) e)])))

;; If `e` is (expr-app^k (expr-fvar self-name) ARG1 ... ARGk), return
;; the args as a list (outermost-first), else #f.
(define (extract-self-call e self-name k)
  (let loop ([e e] [args '()])
    (cond
      [(expr-app? e)
       (loop (expr-app-func e) (cons (expr-app-arg e) args))]
      [(and (expr-fvar? e) (eq? (expr-fvar-name e) self-name)
            (= (length args) k))
       args]
      [else #f])))

;; Returns #t iff `e` mentions (expr-fvar self-name) anywhere.
(define (mentions-fvar? e self-name)
  (define (yes? x) (mentions-fvar? x self-name))
  (match e
    [(expr-fvar n) (eq? n self-name)]
    [(expr-app f a) (or (yes? f) (yes? a))]
    [(expr-int-add a b) (or (yes? a) (yes? b))]
    [(expr-int-sub a b) (or (yes? a) (yes? b))]
    [(expr-int-mul a b) (or (yes? a) (yes? b))]
    [(expr-int-div a b) (or (yes? a) (yes? b))]
    [(expr-int-eq a b)  (or (yes? a) (yes? b))]
    [(expr-int-lt a b)  (or (yes? a) (yes? b))]
    [(expr-int-le a b)  (or (yes? a) (yes? b))]
    [(expr-ann e _) (yes? e)]
    [(expr-lam _ _ body) (yes? body)]
    [(expr-reduce s arms _) (or (yes? s)
                                (for/or ([a (in-list arms)])
                                  (yes? (expr-reduce-arm-body a))))]
    [_ #f]))

(define (match-tail-rec value self-name)
  (define-values (arg-types body) (peel-lambdas value))
  (define k (length arg-types))
  (cond
    [(zero? k) #f]
    ;; Lambda binder annotations: expr-Int when spec given, expr-hole
    ;; when not, expr-Sigma for pair-typed binders (Sprint F.3). All
    ;; three are fine for our lowering — we just need k binders; the
    ;; literal-init-value check handles the actual init-leaf shape.
    [(not (andmap (lambda (t) (or (expr-Int? t) (expr-hole? t)
                                  (expr-Sigma? t))) arg-types)) #f]
    [else
     (match body
       [(expr-reduce cond-expr (list arm0 arm1) _structural?)
        ;; Each arm must have 0 binding count (no captured fields)
        (cond
          [(not (and (zero? (expr-reduce-arm-binding-count arm0))
                     (zero? (expr-reduce-arm-binding-count arm1))))
           #f]
          [else
           ;; Find the step arm (contains recursive call) vs base.
           (define call-args-0 (extract-self-call (expr-reduce-arm-body arm0) self-name k))
           (define call-args-1 (extract-self-call (expr-reduce-arm-body arm1) self-name k))
           (cond
             [(and call-args-0 (not (mentions-fvar? (expr-reduce-arm-body arm1) self-name)))
              (tail-rec-shape arg-types cond-expr
                              (expr-reduce-arm-ctor-name arm1)
                              (expr-reduce-arm-body arm1)
                              call-args-0)]
             [(and call-args-1 (not (mentions-fvar? (expr-reduce-arm-body arm0) self-name)))
              (tail-rec-shape arg-types cond-expr
                              (expr-reduce-arm-ctor-name arm0)
                              (expr-reduce-arm-body arm0)
                              call-args-1)]
             [else #f])])]
       [_ #f])]))

;; Try to lower (expr-app^k (expr-fvar f) init-args) as a tail-rec
;; feedback network. Returns the result cell-id, or #f if the pattern
;; doesn't apply (caller raises an unsupported error).
(define (try-lower-tail-rec-call expr b dom-id env)
  ;; Peel the application chain.
  (let peel ([e expr] [init-args '()])
    (match e
      [(expr-app f a) (peel f (cons a init-args))]
      [(expr-fvar self-name)
       (define value (global-env-lookup-value self-name))
       (cond
         [(not value) #f]
         [else
          (define shape (match-tail-rec value self-name))
          (cond
            [(not shape) #f]
            [(not (= (length init-args) (length (tail-rec-shape-arg-types shape))))
             #f]  ; partial application: not handled
            [else
             (lower-tail-rec b dom-id env shape init-args)])])]
      [_ #f])))

;; ============================================================
;; Non-recursive function inlining (Sprint F.1, 2026-05-01)
;; ============================================================
;;
;; When `(expr-app^k (expr-fvar f) arg1...argk)` doesn't match the
;; tail-rec pattern, try compile-time inlining: look up f's value V;
;; if V is a non-recursive lambda chain, build the substituted form
;; `(expr-app^k V arg1...argk)` and translate it as a beta-redex. The
;; existing let-binding case in `build` handles the resulting shape.
;;
;; Cycle detection has two layers:
;;   1. Immediate self-recursion: if V mentions (expr-fvar f) directly
;;      anywhere in its body, inlining would not terminate — error
;;      with a clear message.
;;   2. Mutual recursion (f calls g calls f, where neither is tail-
;;      recursive): caught by a depth limit on inline expansion.
;;      Reasonable programs nest helpers shallowly (depth 5-10);
;;      exceeding MAX-INLINING-DEPTH=64 indicates either pathological
;;      nesting or a mutual-recursion cycle. Either way, the user
;;      should rewrite the program (typically: tail-recursive form,
;;      or fewer layers of helpers).

(define MAX-INLINING-DEPTH 64)
(define current-inlining-depth (make-parameter 0))

;; ============================================================
;; Gate 2 rev 1.0: compile-time static evaluation
;; ============================================================
;;
;; Many programs use general (non-tail) recursion, e.g. `[fact 5]`,
;; `[fib 10]`, `[sum-to 15]`. These call sites have STATICALLY KNOWN
;; integer arguments — there's no need for a runtime call stack;
;; we can fold the entire call tree to its result at compile time.
;;
;; try-static-eval walks an expression. If it can reduce to a
;; literal value (Int, #t, #f), it returns that value. If any
;; sub-expression depends on a runtime cell (an `expr-bvar`
;; marked 'unknown in the static env), it returns #f and the
;; caller falls through to runtime lowering.
;;
;; The static env is a list of values parallel to `env` (the cell-id
;; list). For each binder pushed onto `env`, the static env gets the
;; binder's literal value (if known at compile time) or `'unknown`.
;; Lookups via expr-bvar return the literal or fail.
;;
;; Recursion bound: MAX-STATIC-EVAL-STEPS (200000). For fib(15) ≈
;; 1973 calls; fib(20) ≈ 21891; fib(25) ≈ 242785. Up to fib(20)-ish
;; folds in well under a second. Beyond that we abort cleanly and
;; fall through.

(define MAX-STATIC-EVAL-STEPS 200000)

;; truncated division — must match the runtime semantics (Zig
;; @divTrunc / Racket quotient on same-sign args). For mixed-sign
;; args, Racket's `quotient` truncates towards zero too.
(define (static-int-div a b)
  (cond [(zero? b) #f]   ; runtime would trap; refuse to fold
        [else (quotient a b)]))

(define (static-int-mod a b)
  (cond [(zero? b) #f]
        [else (modulo a b)]))

;; A small mutable counter keeps us inside a step budget across the
;; entire evaluation tree (depth alone is not a tight enough bound
;; for fib-shaped expansion).
(define current-static-steps (make-parameter #f))
(define (bump-static-step!)
  (define box (current-static-steps))
  (cond [(not box) #t]
        [(>= (unbox box) MAX-STATIC-EVAL-STEPS) #f]
        [else (set-box! box (+ 1 (unbox box))) #t]))

;; try-static-eval-impl : expr × literal-env → value | 'unfoldable
;;   value is an Int (exact integer), Racket #t / #f, or sctor.
;;   'unfoldable means we couldn't (or chose not to) fold this expr.
;;   The literal-env is a list of (literal-value | 'unknown), one
;;   slot per outer bvar binder.
(define UNFOLDABLE 'unfoldable)
(define (foldable? v) (not (eq? v UNFOLDABLE)))

;; sctor: a static-eval ctor value. `name` is the ctor symbol (the
;; namespaced fvar name), `branch` is its branch index in the type's
;; ctor list, `fields` is a list of statically-evaluated field values
;; (Int / Bool / sctor — recursively static).
;;
;; Distinct from `ctor-vt` (which is the runtime-cell representation
;; allocated by build-ctor-application). sctor never reaches the
;; low-pnet — it lives only inside try-static-eval and gets pattern-
;; matched away by surrounding expr-reduce. If a program's main
;; result folds to an sctor (rather than a scalar), we conservatively
;; fall through to the normal build pipeline (which will then emit
;; the runtime ctor-vt or hard-error on recursive ctors).
(struct sctor (name branch fields) #:transparent)

(define (try-static-eval-impl e lit-env)
  (cond
    [(not (bump-static-step!)) UNFOLDABLE]
    [else
     (match e
       [(expr-ann inner _) (try-static-eval-impl inner lit-env)]
       [(expr-int n)       n]
       [(expr-true)        #t]
       [(expr-false)       #f]
       [(expr-zero)        0]
       [(expr-nat-val n)   n]
       [(expr-suc inner)
        (define v (try-static-eval-impl inner lit-env))
        (cond [(exact-integer? v) (+ v 1)] [else UNFOLDABLE])]

       [(expr-bvar i)
        (cond [(>= i (length lit-env)) UNFOLDABLE]
              [else (let ([v (list-ref lit-env i)])
                      (cond [(eq? v 'unknown) UNFOLDABLE] [else v]))])]

       ;; Bare expr-fvar: nullary ctor. Examples: `nil`, `none`,
       ;; standalone `zero` (although latter is usually expr-zero).
       [(expr-fvar n)
        (cond [(is-ctor-name? n)
               (define meta (lookup-ctor* n))
               (cond [(zero? (length (ctor-meta-field-types meta)))
                      (sctor n (ctor-meta-branch-index meta) '())]
                     [else UNFOLDABLE])]
              [else UNFOLDABLE])]

       [(expr-int-add a b) (static-bin + a b lit-env)]
       [(expr-int-sub a b) (static-bin - a b lit-env)]
       [(expr-int-mul a b) (static-bin * a b lit-env)]
       [(expr-int-div a b) (static-bin static-int-div a b lit-env)]
       [(expr-int-mod a b) (static-bin static-int-mod a b lit-env)]
       [(expr-int-eq a b)  (static-bin = a b lit-env)]
       [(expr-int-lt a b)  (static-bin < a b lit-env)]
       [(expr-int-le a b)  (static-bin <= a b lit-env)]
       [(expr-int-neg a)
        (define av (try-static-eval-impl a lit-env))
        (cond [(exact-integer? av) (- av)] [else UNFOLDABLE])]
       [(expr-int-abs a)
        (define av (try-static-eval-impl a lit-env))
        (cond [(exact-integer? av) (abs av)] [else UNFOLDABLE])]

       [(expr-boolrec _motive tc fc cnd)
        (define cv (try-static-eval-impl cnd lit-env))
        (cond [(eq? cv #t) (try-static-eval-impl tc lit-env)]
              [(eq? cv #f) (try-static-eval-impl fc lit-env)]
              [else UNFOLDABLE])]

       ;; 2-arm reduce: Bool / Nat fast-paths, then general sctor
       ;; dispatch (covers Maybe, Either, and other 2-ctor ADTs).
       [(expr-reduce s
                     (list (expr-reduce-arm tag-a count-a body-a)
                           (expr-reduce-arm tag-b count-b body-b))
                     _)
        (define sv (try-static-eval-impl s lit-env))
        (cond
          ;; Bool match
          [(and (boolean? sv) (eq? tag-a 'true) (eq? tag-b 'false)
                (= count-a 0) (= count-b 0))
           (try-static-eval-impl (if sv body-a body-b) lit-env)]
          [(and (boolean? sv) (eq? tag-a 'false) (eq? tag-b 'true)
                (= count-a 0) (= count-b 0))
           (try-static-eval-impl (if sv body-b body-a) lit-env)]
          ;; Nat match: zero arm has count 0; suc arm has count 1
          ;; (binder for predecessor).
          [(and (exact-integer? sv) (>= sv 0)
                (eq? tag-a 'zero) (eq? tag-b 'suc)
                (= count-a 0) (= count-b 1))
           (cond [(zero? sv) (try-static-eval-impl body-a lit-env)]
                 [else (try-static-eval-impl body-b
                                             (cons (- sv 1) lit-env))])]
          [(and (exact-integer? sv) (>= sv 0)
                (eq? tag-a 'suc) (eq? tag-b 'zero)
                (= count-a 1) (= count-b 0))
           (cond [(zero? sv) (try-static-eval-impl body-b lit-env)]
                 [else (try-static-eval-impl body-a
                                             (cons (- sv 1) lit-env))])]
          ;; Gate 1 rev 1.5: sctor scrutinee — match by branch index.
          [(sctor? sv)
           (try-eval-sctor-arm sv (list (expr-reduce-arm tag-a count-a body-a)
                                        (expr-reduce-arm tag-b count-b body-b))
                               lit-env)]
          [else UNFOLDABLE])]

       ;; N-arm reduce (N >= 1): only fires when scrutinee is an sctor
       ;; (Bool/Nat fast-paths only handle 2-arm above).
       [(expr-reduce s arms _)
        (define sv (try-static-eval-impl s lit-env))
        (cond [(sctor? sv) (try-eval-sctor-arm sv arms lit-env)]
              [else UNFOLDABLE])]

       ;; Beta-redex: (expr-app (expr-lam …) arg)
       [(expr-app (expr-lam _ _ body) arg)
        (define av (try-static-eval-impl arg lit-env))
        (cond [(foldable? av) (try-static-eval-impl body (cons av lit-env))]
              [else UNFOLDABLE])]

       [(expr-app _ _)
        (let-values ([(head args) (peel-fvar-app-chain e)])
          (cond
            ;; Gate 1 rev 1.5: ctor application — build sctor.
            [(and head (is-ctor-name? head))
             (try-eval-ctor-app head args lit-env)]
            [head
             (define v (global-env-lookup-value head))
             (cond
               [(not (expr-lam? v)) UNFOLDABLE]
               [else (apply-static-lam v args lit-env)])]
            [else UNFOLDABLE]))]

       [_ UNFOLDABLE])]))

;; try-eval-ctor-app : ctor-name × (Listof expr) × lit-env → sctor | 'unfoldable
;; Build an sctor from a ctor application. Filters out leading type
;; args (Int / Bool / Nat / Type / Pi / type-var fvar).
(define (try-eval-ctor-app head args lit-env)
  (define meta (lookup-ctor* head))
  (cond
    [(not meta) UNFOLDABLE]
    [else
     (define-values (_type-args value-args) (split-type-and-value-args args))
     (define expected-arity (length (ctor-meta-field-types meta)))
     (cond
       [(not (= (length value-args) expected-arity)) UNFOLDABLE]
       [else
        (let loop ([args value-args] [acc '()])
          (cond
            [(null? args)
             (sctor head (ctor-meta-branch-index meta) (reverse acc))]
            [else
             (define v (try-static-eval-impl (car args) lit-env))
             (cond [(foldable? v) (loop (cdr args) (cons v acc))]
                   [else UNFOLDABLE])]))])]))

;; try-eval-sctor-arm : sctor × (Listof expr-reduce-arm) × lit-env → value | 'unfoldable
;; Find the arm whose ctor-name matches the sctor, then push field
;; values onto lit-env (mirroring build-ctor-match's reverse-cons so
;; bvar 0 is the first-declared field), then evaluate the body.
;; Tolerate namespace-qualified arm tags by delegating to lookup-ctor*.
(define (try-eval-sctor-arm sv arms lit-env)
  (define sv-branch (sctor-branch sv))
  (define sv-fields (sctor-fields sv))
  (define matched
    (for/or ([arm (in-list arms)])
      (define arm-name (expr-reduce-arm-ctor-name arm))
      (define meta (lookup-ctor* arm-name))
      (cond [(and meta (= (ctor-meta-branch-index meta) sv-branch)
                  (= (expr-reduce-arm-binding-count arm) (length sv-fields)))
             arm]
            [else #f])))
  (cond
    [(not matched) UNFOLDABLE]
    [else
     ;; Elaborator binds fields LAST-LISTED-FIRST: e.g., for `cons a r`,
     ;; the body's `(expr-bvar 0)` refers to `r` (the last binder),
     ;; `(expr-bvar 1)` to `a`. Cons fields onto lit-env in declaration
     ;; order so the last field ends up at the head (de Bruijn 0).
     (define new-env
       (for/fold ([env lit-env])
                 ([f (in-list sv-fields)])
         (cons f env)))
     (try-static-eval-impl (expr-reduce-arm-body matched) new-env)]))

;; static-bin : binop × expr × expr × lit-env → result | 'unfoldable
(define (static-bin op a b lit-env)
  (define av (try-static-eval-impl a lit-env))
  (cond
    [(not (or (exact-integer? av) (boolean? av))) UNFOLDABLE]
    [else
     (define bv (try-static-eval-impl b lit-env))
     (cond
       [(not (or (exact-integer? bv) (boolean? bv))) UNFOLDABLE]
       [else
        (with-handlers ([exn:fail? (lambda _ UNFOLDABLE)])
          (op av bv))])]))

;; apply-static-lam : expr-lam × (Listof expr) × lit-env → value | 'unfoldable
(define (apply-static-lam lam args lit-env)
  (let loop ([body lam] [args args] [acc-env lit-env])
    (cond
      [(null? args) (try-static-eval-impl body acc-env)]
      [(expr-lam? body)
       (define av (try-static-eval-impl (car args) lit-env))
       (cond [(foldable? av)
              (loop (expr-lam-body body) (cdr args) (cons av acc-env))]
             [else UNFOLDABLE])]
      [(expr-ann? body) (loop (expr-ann-term body) args acc-env)]
      [else UNFOLDABLE])))

;; try-static-eval : expr × lit-env → value | 'unfoldable
;; Sets up a fresh step-budget box per top-level call.
(define (try-static-eval e lit-env)
  (parameterize ([current-static-steps (box 0)])
    (with-handlers ([exn:fail? (lambda _ UNFOLDABLE)])
      (try-static-eval-impl e lit-env))))

;; ============================================================
;; Static env tracking (parallel to cell-id env)
;; ============================================================
;;
;; The build pipeline passes `env` (a list of cell-ids) through
;; recursive build calls. We mirror it with a `static-env`
;; (a list of literal-values-or-'unknown) using a parameter, so
;; every push to `env` also pushes to `static-env`.
(define current-static-env (make-parameter '()))
(define-syntax-rule (with-static-extension new-env body ...)
  (parameterize ([current-static-env new-env]) body ...))

;; Construct (expr-app^k (expr-lam-chain) arg1 ... argk) from a value V
;; and the original application expression. Replaces the (expr-fvar f)
;; head with V; the rest of the application chain is preserved.
(define (substitute-head new-head expr)
  (match expr
    [(expr-app f a) (expr-app (substitute-head new-head f) a)]
    [(? expr-fvar?) new-head]
    [_ expr]))  ; should not happen

(define (try-inline-fvar-call expr b dom-id env)
  (let peel ([e expr] [arg-count 0])
    (match e
      [(expr-app f _) (peel f (+ arg-count 1))]
      [(expr-fvar name)
       (cond
         [(>= (current-inlining-depth) MAX-INLINING-DEPTH)
          (translate-error!
           expr
           (format "inlining depth limit ~a exceeded while expanding '~a'. \
Likely cause: deeply nested helper functions (rewrite to fewer levels) \
or mutual recursion between non-tail-recursive functions (rewrite as \
tail-recursive). Programmatic limit; raise MAX-INLINING-DEPTH if \
genuinely needed."
                   MAX-INLINING-DEPTH name))]
         [else
          (define value (global-env-lookup-value name))
          (cond
            [(not value) #f]            ; unknown fvar; caller raises generic error
            [(not (expr-lam? value)) #f] ; non-lambda binding
            [(mentions-fvar? value name)
             (translate-error!
              expr
              (format "function '~a' is non-tail-self-recursive; inlining \
would not terminate. Use tail-recursive form (recognized by `match-tail-rec`) \
instead — pattern: `match cond | true → base | false → [self ...]`."
                      name))]
            [else
             (parameterize ([current-inlining-depth
                             (+ 1 (current-inlining-depth))])
               (build (substitute-head value expr) b dom-id env))])])]
      [_ #f])))

(define (literal-init-value e)
  ;; Returns a value-tree of literal Int (or #t/#f) leaves for an
  ;; init-arg expression that we can evaluate at compile time, or #f
  ;; if non-literal. Pair literals like `[pair 0 1]` produce a list
  ;; of leaves matching the pair structure; arbitrary nesting OK.
  (match e
    [(expr-int n) n]
    [(expr-true)  #t]
    [(expr-false) #f]
    [(expr-ann inner _) (literal-init-value inner)]
    [(expr-pair fst-e snd-e)
     (define a (literal-init-value fst-e))
     (define b (literal-init-value snd-e))
     (and (not (eq? a #f)) (not (eq? b #f)) (list a b))]
    ;; Expr-ann with #f init becomes problematic; bail early.
    [_ #f]))

;; alloc-state-vt-from-literal : builder × literal-vtree → state-vtree
;; Allocate fresh state cells matching the shape of a literal init-vt
;; and seed each leaf cell with its literal init-value. Used in
;; lower-tail-rec's literal-init path. Lifted out of the original
;; `alloc-state-vt` so the M6 non-literal path can share the helper.
(define (alloc-state-vt-from-literal b init-vt)
  (cond
    [(exact-integer? init-vt) (emit-cell! b INT-DOMAIN-ID init-vt)]
    [else (map (lambda (sub) (alloc-state-vt-from-literal b sub)) init-vt)]))

;; vtree-zeros-like : vtree → vtree
;; Return a vtree mirroring the SHAPE of `vt` with every leaf replaced
;; by zero. Used by lower-tail-rec to derive a placeholder init-vt for
;; a non-literal init-arg (where the underlying state cells are
;; runtime-bound and the literal init is meaningless). The next-cell
;; downstream uses these zeros as their cell-decl init-value; the
;; first select fire overwrites before any reader observes the value.
(define (vtree-zeros-like vt)
  (cond
    [(exact-integer? vt) 0]
    [else (map vtree-zeros-like vt)]))

;; Sprint F.3: vtree-walking helpers for pair-typed tail-rec state.

;; vtree-leaves : vtree → (Listof scalar-leaf)
;; Flatten the vtree's leaves in left-to-right order. Used to build a
;; set of state cell-ids for the bridge check.
(define (vtree-leaves vt)
  (cond [(or (exact-integer? vt) (boolean? vt)) (list vt)]
        [(list? vt) (apply append (map vtree-leaves vt))]
        [(ctor-vt? vt)
         (cons (ctor-vt-tag-cid vt)
               (apply append (map vtree-leaves (ctor-vt-slot-cids vt))))]
        [else '()]))

;; vtree-shapes-match? : vtree × vtree → Bool
;; True iff the two vtrees have identical structure (same nesting).
(define (vtree-shapes-match? a b)
  (cond [(and (vtree-scalar? a) (vtree-scalar? b)) #t]
        [(and (list? a) (list? b) (= (length a) (length b)))
         (andmap vtree-shapes-match? a b)]
        [(and (ctor-vt? a) (ctor-vt? b))
         (and (eq? (ctor-vt-type-name a) (ctor-vt-type-name b))
              (= (length (ctor-vt-slot-cids a))
                 (length (ctor-vt-slot-cids b)))
              (andmap vtree-shapes-match?
                      (ctor-vt-slot-cids a) (ctor-vt-slot-cids b)))]
        [else #f]))

;; init-of-state-leaf : leaf-cid × state-vts × init-vts → init-leaf | #f
;; Find the init-leaf corresponding to a given state cell-id, by walking
;; both vtrees in lockstep. Returns #f if cell-id isn't a state cell.
(define (init-of-state-leaf cid state-vts init-vts)
  (let walk ([s state-vts] [i init-vts])
    (cond
      [(and (exact-integer? s) (= s cid)) i]
      [(exact-integer? s) #f]
      [(and (list? s) (list? i) (= (length s) (length i)))
       (for/or ([sub-s (in-list s)] [sub-i (in-list i)])
         (walk sub-s sub-i))]
      [else #f])))

;; F.5+F.6: lift-cell-to-depth — chain identity propagators until
;; cell-id's depth equals target-depth. Returns the cell-id at the new
;; depth. F.6 adds bridge-cache coalescing: when multiple consumers
;; want the same source lifted, they share the same bridge chain
;; instead of allocating fresh duplicate cells.
;;
;; Algorithm:
;;   1. If `cid` is already at depth ≥ target, return it as-is.
;;   2. Look up an existing bridge from `cid` at exactly target depth;
;;      if found, return it (full coalesce).
;;   3. Find the highest existing bridge from `cid` at depth < target;
;;      use it as the starting point for chain extension. (If none,
;;      start from `cid` itself.) This is partial coalescing: we reuse
;;      whatever lower-depth chain already exists, and only build the
;;      remaining bridges to reach target.
;;   4. Extend the chain, caching each new bridge against the original
;;      `cid` for future consumers.
(define (lift-cell-to-depth b cid target-depth)
  (cond
    [(>= (cell-depth b cid) target-depth) cid]
    [else
     (define cached (lookup-bridge b cid target-depth))
     (cond
       [cached cached]
       [else
        (define start-cid (find-cached-below b cid target-depth))
        (let loop ([current start-cid])
          (cond
            [(>= (cell-depth b current) target-depth) current]
            [else
             (define src-decl (find-cell-decl b current))
             (define src-domain (cell-decl-domain-id src-decl))
             (define src-init   (cell-decl-init-value src-decl))
             (define bridge-cid (emit-cell! b src-domain src-init))
             (emit-propagator! b (list current) bridge-cid 'kernel-identity)
             ;; Cache bridge against the ORIGINAL source cid, not the
             ;; intermediate `current`, so future consumers of `cid`
             ;; can find this bridge at its target depth.
             (cache-bridge! b cid bridge-cid)
             (loop bridge-cid)]))])]))

;; F.5: emit-aligned-propagator! — like emit-propagator!, but first
;; lifts every input cell to the maximum depth across all inputs via
;; identity bridges. This guarantees the propagator's inputs are read
;; at the same iteration boundary, fixing the lag-mismatch bug that
;; produces wrong values in nested-arithmetic step expressions.
;;
;; When inputs are already at the same depth (the common case for
;; non-nested expressions), no bridges are added — emit-aligned reduces
;; to plain emit-propagator!.
(define (emit-aligned-propagator! b in-cids out-cid tag)
  (define max-d (apply max 0 (map (lambda (c) (cell-depth b c)) in-cids)))
  (define lifted-in-cids
    (map (lambda (c) (lift-cell-to-depth b c max-d)) in-cids))
  (emit-propagator! b lifted-in-cids out-cid tag))

;; F.5: lift each leaf of a value-tree to target-depth.
(define (lift-vtree-to-depth b vt target-depth)
  (cond
    [(exact-integer? vt) (lift-cell-to-depth b vt target-depth)]
    [else (map (lambda (sub) (lift-vtree-to-depth b sub target-depth)) vt)]))

;; F.5: max depth of leaves in a value-tree.
(define (max-vtree-depth b vt)
  (cond
    [(exact-integer? vt) (cell-depth b vt)]
    [else (apply max 0 (map (lambda (sub) (max-vtree-depth b sub)) vt))]))

(define (lower-tail-rec b dom-id env shape init-args)
  ;; kernel-PU Phase 4 Day 9: track that we lowered a tail-rec via the
  ;; substrate iteration pattern (cells + kernel-identity feedback +
  ;; per-leaf kernel-select arithmetic — § 5.5 of the design doc). The
  ;; meta-decl emitted at assemble-time documents this for testing and
  ;; confirms we did NOT take the never-shipped Sprint G iter-block-decl
  ;; path (which is scheduled for Phase 6 deletion).
  (set-builder-tail-rec-count! b (+ 1 (builder-tail-rec-count b)))
  (define k (length init-args))

  ;; 1. Each init-arg → init-vt + state-vt. Two cases per arg:
  ;;
  ;;    (a) Literal init (the historical case, e.g. `[pair 0 1]`):
  ;;        init-vt is a vtree of Int literals; allocate fresh state
  ;;        cells with those as cell-decl init-values. Next-cell init
  ;;        is the same literal so the per-leaf next-cell is born with
  ;;        a sensible value before the first select fires.
  ;;
  ;;    (b) Non-literal init (lowering-yolo M6, 2026-05-02), e.g.
  ;;        `[fib-pair [pair 0 1] n]` where `n` is a parameter:
  ;;        `build` the expression to get a vtree of cell-ids and
  ;;        REUSE those cells as the state cells. No copy propagator
  ;;        needed — the cells whose values are set at runtime (via
  ;;        argv-write before quiescence, for input cells) ARE the
  ;;        iteration state. The feedback identity then writes the
  ;;        new state into them each round, naturally consuming the
  ;;        input value over the iteration. For the next-cell init we
  ;;        substitute 0 (the eventual select write will overwrite
  ;;        before any reader sees it). Sprint F.3's vtree shape
  ;;        invariant is preserved: the nested structure of init-vts
  ;;        and state-vts matches; only the leaf values differ.
  (define-values (init-vts state-vts)
    (let loop ([args init-args] [iv-acc '()] [sv-acc '()])
      (cond
        [(null? args) (values (reverse iv-acc) (reverse sv-acc))]
        [else
         (define arg (car args))
         (define lit (literal-init-value arg))
         (cond
           [lit
            (let walk ([leaf lit])
              (cond [(exact-integer? leaf) (void)]
                    [(list? leaf) (for-each walk leaf)]
                    [else
                     (translate-error!
                      arg
                      "tail-rec init-leaves must be Int (Bool/scalar \
Bool state slots not yet supported).")]))
            (define sv (alloc-state-vt-from-literal b lit))
            (loop (cdr args) (cons lit iv-acc) (cons sv sv-acc))]
           [else
            ;; Build the non-literal init-arg in the OUTER env (not
            ;; state-env, which doesn't exist yet). Returns a vtree
            ;; of cell-ids (typically a single cell-id for an
            ;; (expr-bvar i) — the corresponding env slot).
            (define vt (build arg b INT-DOMAIN-ID env))
            ;; Today we only support the case where vt is a single
            ;; input cell — i.e., the init-arg is a main parameter
            ;; like `n`. More general non-literal initializers
            ;; (intermediate computations) are deferred — they would
            ;; need careful BSP race analysis since the iteration's
            ;; feedback would compete with the upstream propagator's
            ;; output for the state cell value.
            (unless (and (exact-integer? vt) (input-cell? b vt))
              (translate-error!
               arg
               "tail-rec: non-literal init-args must currently \
resolve to a single main parameter (an opaque bvar from \
parameterised main). Other non-literal initializers are deferred."))
            (define input-cid vt)
            ;; Allocate a FRESH state cell (not the input cell — see
            ;; builder-input-cell-mirrors docstring for why sharing
            ;; breaks under multi-site iteration). Mirror argv to the
            ;; state cell so it starts at the runtime input value.
            (define state-cid (emit-cell! b INT-DOMAIN-ID 0))
            (record-input-mirror! b input-cid state-cid)
            (record-state-input-source! b state-cid input-cid)
            (define iv (vtree-zeros-like vt))
            (loop (cdr args) (cons iv iv-acc) (cons state-cid sv-acc))])])))

  (define (alloc-state-vt init-vt) (alloc-state-vt-from-literal b init-vt))

  ;; State env: outermost lambda's binder has highest bvar index. The
  ;; init-args/state-vts are in outermost-first order; env is innermost-
  ;; first, so reverse.
  (define state-env (reverse state-vts))

  ;; --- Tail-rec convergence (Solution 2,
  ;; docs/tracking/2026-05-02_TAILREC_OSCILLATION_FINDING.md) ---
  ;;
  ;; Cond/step read a lagged copy of state (`prev`) via kernel-identity.
  ;; Each select writes **directly** into the state cell (the freeze
  ;; operand reads raw state at logical depth 0). This replaces the
  ;; historical next-cell feedback loop, which failed to reach a BSP
  ;; fixed point under opaque iteration counters (limit-cycle oscillation
  ;; after the base case became true).
  ;;
  ;; Prev cells reuse state's decl init and argv mirrors (when present)
  ;; so round 1 does not see counter=0 in prev while state holds argv(n).
  (define (emit-prev-vtree state-vt)
    (cond
      [(exact-integer? state-vt)
       (define decl (find-cell-decl b state-vt))
       (define prev
         (emit-cell! b (cell-decl-domain-id decl) (cell-decl-init-value decl)))
       (emit-propagator! b (list state-vt) prev 'kernel-identity)
       (define src (state-input-source b state-vt))
       (when src (record-input-mirror! b src prev))
       prev]
      [(list? state-vt)
       (map emit-prev-vtree state-vt)]
      [(ctor-vt? state-vt)
       (ctor-vt (ctor-vt-type-name state-vt)
                (emit-prev-vtree (ctor-vt-tag-cid state-vt))
                (map emit-prev-vtree (ctor-vt-slot-cids state-vt)))]
      [else
       (translate-error!
        #f
        (format "tail-rec: unsupported state vtree shape ~v for prev-chain"
                state-vt))]))

  (define prev-vts (map emit-prev-vtree state-vts))
  ;; Innermost-first env for cond + step binders (lagged cells).
  (define state-env-prev (reverse prev-vts))

  ;; 3. cond-expr → bool cell. With base-on-true? we mutate cond's
  ;; cell-decl init from #f to #t to force round-1 freeze.
  (define base-on-true? (eq? (tail-rec-shape-base-arm-tag shape) 'true))
  (define cond-vt (build (tail-rec-shape-cond-expr shape) b BOOL-DOMAIN-ID state-env-prev))
  (define cond-cid (assert-scalar! cond-vt (tail-rec-shape-cond-expr shape)
                                   "tail-rec cond-expr"))
  (when base-on-true?
    (set-builder-cells! b
                        (for/list ([c (in-list (builder-cells b))])
                          (if (and (cell-decl? c) (= (cell-decl-id c) cond-cid))
                              (cell-decl (cell-decl-id c)
                                         (cell-decl-domain-id c)
                                         #t)
                              c))))

  ;; 4. step-args → step-vts. Each step-vt's shape MUST match the
  ;; corresponding state-vt's shape (this is enforced by the elaborator
  ;; via type checking; we assert defensively).
  (define raw-step-vts
    (for/list ([step-arg (in-list (tail-rec-shape-step-args shape))]
               [state-vt  (in-list state-vts)])
      (define raw-vt (build step-arg b INT-DOMAIN-ID state-env-prev))
      (unless (vtree-shapes-match? state-vt raw-vt)
        (translate-error! step-arg
                          (format "tail-rec step-arg shape ~v doesn't match state shape ~v"
                                  raw-vt state-vt)))
      raw-vt))

  ;; F.5 (tail-rec slice): lift cond + step leaves to a common depth so
  ;; every slot's select observes the same cond timing across pair slots.
  ;; Arithmetic/compare subgraphs still use emit-aligned-propagator!
  ;; internally during `build`.
  ;;
  ;; The select's freeze operand is raw `state-vt` (not lifted): bridging
  ;; it to max-step-depth would phase-shift the freeze snapshot and break
  ;; quiescence (oscillation finding doc § Solution 2).
  (define max-step-depth
    (apply max (cell-depth b cond-cid)
           (map (lambda (vt) (max-vtree-depth b vt)) raw-step-vts)))

  (define cond-cid-lifted (lift-cell-to-depth b cond-cid max-step-depth))

  (define step-vts
    (for/list ([raw-vt (in-list raw-step-vts)])
      (lift-vtree-to-depth b raw-vt max-step-depth)))

  ;; 5. Per-leaf: kernel-select writes directly into the state cell
  ;; (self-loop). Assert-depth-balance exempts this kernel-select shape.
  (define (emit-feedback state-vt step-vt init-vt)
    (cond
      [(exact-integer? state-vt)
       (cond
         [base-on-true?
          (emit-propagator! b
                            (list cond-cid-lifted state-vt step-vt)
                            state-vt
                            'kernel-select
                            #:skip-depth-update? #t)]
         [else
          (emit-propagator! b
                            (list cond-cid-lifted step-vt state-vt)
                            state-vt
                            'kernel-select
                            #:skip-depth-update? #t)])]
      [else
       (for ([s (in-list state-vt)]
             [t (in-list step-vt)]
             [i (in-list init-vt)])
         (emit-feedback s t i))]))
  (for ([s (in-list state-vts)] [t (in-list step-vts)] [i (in-list init-vts)])
    (emit-feedback s t i))

  ;; 6. base-result expression evaluated in state env. Returns a vtree
  ;; (could be scalar or pair) — caller (try-lower-tail-rec-call's
  ;; build chain) handles whatever shape comes back.
  (build (tail-rec-shape-base-result shape) b dom-id state-env))

(define (build expr b dom-id env)
  ;; Gate 2 rev 1.0: try compile-time static evaluation as a fallback
  ;; for expressions that contain a function call (`expr-fvar` head in
  ;; an `expr-app`). This handles the concrete-argument case for
  ;; general (non-tail) recursion (`fact 5`, `fib 10`, `sum-to 15`,
  ;; etc.) without needing a runtime call stack.
  ;;
  ;; The heuristic "only fold when expression contains a function
  ;; call" preserves the existing low-pnet shape for pure arithmetic
  ;; expressions (`[int+ 1 2]` still emits 3 cells + 1 propagator),
  ;; which the unit tests assert. Recursive call sites get folded.
  (cond
    [(expr-mentions-fvar-app? expr)
     (define sv (try-static-eval expr (current-static-env)))
     (cond
       [(exact-integer? sv) (emit-cell! b INT-DOMAIN-ID sv)]
       [(eq? sv #t) (emit-cell! b BOOL-DOMAIN-ID #t)]
       [(eq? sv #f) (emit-cell! b BOOL-DOMAIN-ID #f)]
       ;; Gate 1 rev 1.5: sctor result — caller expects a runtime cell,
       ;; so we don't emit the sctor directly. Fall through to the
       ;; existing build pipeline. (If the program's main result is a
       ;; ctor, build-ctor-application will hard-error on recursive
       ;; ctors as before; the static-eval value is consumed only when
       ;; surrounded by an expr-reduce that resolves it to a scalar.)
       [else (build-uncached expr b dom-id env)])]
    [else (build-uncached expr b dom-id env)]))

;; expr-mentions-fvar-app? : expr → Bool
;; True iff any sub-expression has the shape `(expr-app head ...)`
;; where head peels to an `expr-fvar`. This is the syntactic
;; precondition for static-eval to be useful (function inlining +
;; partial evaluation). Pure literal arithmetic without any function
;; call short-circuits to the existing build path.
(define (expr-mentions-fvar-app? e)
  (define (yes? x) (expr-mentions-fvar-app? x))
  (match e
    [(? expr-app?)
     (let-values ([(head _) (peel-fvar-app-chain e)])
       (cond [head #t]
             [else (or (yes? (expr-app-func e)) (yes? (expr-app-arg e)))]))]
    [(expr-ann inner _) (yes? inner)]
    [(expr-int-add a b) (or (yes? a) (yes? b))]
    [(expr-int-sub a b) (or (yes? a) (yes? b))]
    [(expr-int-mul a b) (or (yes? a) (yes? b))]
    [(expr-int-div a b) (or (yes? a) (yes? b))]
    [(expr-int-mod a b) (or (yes? a) (yes? b))]
    [(expr-int-eq a b) (or (yes? a) (yes? b))]
    [(expr-int-lt a b) (or (yes? a) (yes? b))]
    [(expr-int-le a b) (or (yes? a) (yes? b))]
    [(expr-int-neg a) (yes? a)]
    [(expr-int-abs a) (yes? a)]
    [(expr-suc a) (yes? a)]
    [(expr-boolrec _ tc fc cnd) (or (yes? tc) (yes? fc) (yes? cnd))]
    [(expr-reduce s arms _)
     (or (yes? s) (for/or ([a (in-list arms)])
                    (yes? (expr-reduce-arm-body a))))]
    [(expr-lam _ _ body) (yes? body)]
    [(expr-natrec _ b s t) (or (yes? b) (yes? s) (yes? t))]
    [_ #f]))

;; lower-natrec — dependent Nat eliminator for executable lowering.
;;
;; Restrictions (narrow slice sufficient for stdlib-style folds):
;;   - `target` must be `nat-val`, `zero`, or a single Nat **parameter**
;;     cell (`expr-bvar` resolving to an `input-cell?`).
;;   - `base` must fold to a compile-time Int (`literal-init-value` or
;;     `try-static-eval` under `current-static-env`).
;;   - `step` must be `(λ (_ : Nat). (λ (_ : T). body))` with runtime mult m1/mw;
;;     body uses `bvar 0` = accumulator, `bvar 1` = predecessor index k.
;;   - Accumulator must translate to a scalar Int cell (assert-scalar!).
;;
;; Iterator invariant: state `(k, acc)` holds partial computation after `k`
;; outer reductions (`acc = elim(_,base)` at partial depth `k`). Loop continues
;; while `k < n` using lagged prev copies like tail-rec (BSP convergence).
(define (lower-natrec b dom-id outer-env mot base step target err-expr)
  (void mot)
  (define base-lit
    (let ([lit (literal-init-value base)])
      (cond [(exact-integer? lit) lit]
            [else
             (define sv (try-static-eval base (current-static-env)))
             (cond [(exact-integer? sv) sv]
                   [else #f])])))
  (unless (exact-integer? base-lit)
    (translate-error!
     err-expr
     "natrec: base must fold to a compile-time Int for lowering"))

  (define tgt* (peel-expr-ann target))
  (define-values (orig-init mirror-src)
    (match tgt*
      [(expr-nat-val n)
       (unless (and (exact-integer? n) (>= n 0))
         (translate-error! err-expr "natrec: invalid expr-nat-val"))
       (values n #f)]
      [(expr-zero) (values 0 #f)]
      [(expr-bvar i)
       (when (or (< i 0) (>= i (length outer-env)))
         (translate-error! err-expr "natrec: target bvar out of scope"))
       (define cid (list-ref outer-env i))
       (unless (input-cell? b cid)
         (translate-error!
          err-expr
          "natrec: opaque Nat target must be a parameter cell"))
       (values 0 cid)]
      [_ (translate-error!
          err-expr
          "natrec: target must be nat-val, zero, or Nat main parameter")]))

  (define step* (peel-expr-ann step))
  (define inner-body
    (match step*
      [(expr-lam mult1 ty1 (expr-lam mult2 _ty2 ib))
       (unless (memq mult1 '(m1 mw))
         (translate-error! err-expr "natrec step outer λ multiplicity unsupported"))
       (unless (memq mult2 '(m1 mw))
         (translate-error! err-expr "natrec step inner λ multiplicity unsupported"))
       (unless (expr-Nat? (peel-expr-ann ty1))
         (translate-error! err-expr "natrec step first binder must be Nat"))
       ib]
      [_ (translate-error!
          err-expr
          "natrec step must be (λ (_ : Nat). (λ (_ : _). body))")]))

  ;; Constant bound n (mirrored from argv when needed).
  (define orig-cid (emit-cell! b INT-DOMAIN-ID orig-init))
  (when mirror-src (record-input-mirror! b mirror-src orig-cid))

  ;; Iterator cells.
  (define k-cid (emit-cell! b INT-DOMAIN-ID 0))
  (define acc-cid (emit-cell! b INT-DOMAIN-ID base-lit))

  ;; Lagged copies for cond + step (same pattern as lower-tail-rec).
  (define prev-k-cid (emit-cell! b INT-DOMAIN-ID 0))
  (emit-propagator! b (list k-cid) prev-k-cid 'kernel-identity)
  (define prev-acc-cid (emit-cell! b INT-DOMAIN-ID base-lit))
  (emit-propagator! b (list acc-cid) prev-acc-cid 'kernel-identity)

  ;; cond := (prev_k < n)
  (define cond-cid (emit-cell! b BOOL-DOMAIN-ID #f))
  (emit-aligned-propagator! b (list prev-k-cid orig-cid) cond-cid 'kernel-int-lt)

  (define one-cid (emit-cell! b INT-DOMAIN-ID 1))
  ;; Step index uses predecessor counter value `prev_k`.
  (define step-env (cons prev-acc-cid (cons prev-k-cid outer-env)))
  (define new-acc-vt (build inner-body b dom-id step-env))
  (define new-acc-cid (assert-scalar! new-acc-vt inner-body "natrec step body"))
  (define new-k-cid (emit-cell! b INT-DOMAIN-ID 0))
  (emit-aligned-propagator! b (list prev-k-cid one-cid) new-k-cid 'kernel-int-add)

  ;; Lift cond + step operands to a common depth (freeze operands stay raw).
  (define max-d (max (cell-depth b cond-cid)
                     (cell-depth b new-k-cid)
                     (cell-depth b new-acc-cid)))
  (define cond-lifted (lift-cell-to-depth b cond-cid max-d))
  (define new-k-lifted (lift-cell-to-depth b new-k-cid max-d))
  (define new-acc-lifted (lift-cell-to-depth b new-acc-cid max-d))

  ;; base-on-false kernel-select: cond≠0 → then-branch (step); cond=0 → freeze.
  (emit-propagator! b (list cond-lifted new-k-lifted k-cid) k-cid 'kernel-select
                    #:skip-depth-update? #t)
  (emit-propagator! b (list cond-lifted new-acc-lifted acc-cid) acc-cid 'kernel-select
                    #:skip-depth-update? #t)

  acc-cid)

(define (build-uncached expr b dom-id env)
  (match expr
    ;; Strip annotations
    [(expr-ann inner _) (build inner b dom-id env)]

    ;; Literals: a single cell whose init-value is the literal.
    [(expr-int n)
     (unless (exact-integer? n)
       (translate-error! expr "expr-int with non-integer payload"))
     (emit-cell! b INT-DOMAIN-ID n)]
    [(expr-true)  (emit-cell! b BOOL-DOMAIN-ID #t)]
    [(expr-false) (emit-cell! b BOOL-DOMAIN-ID #f)]

    ;; Unit / Nil singletons — represented as i64 0 at runtime (witness only).
    [(expr-unit) (emit-cell! b INT-DOMAIN-ID 0)]
    [(expr-nil) (emit-cell! b INT-DOMAIN-ID 0)]

    ;; Eq introduction — proof irrelevant for executable lowering.
    [(expr-refl) (emit-cell! b INT-DOMAIN-ID 0)]

    ;; J elimination — only the definitional refl case (β rule).
    [(expr-J _mot base left _right proof)
     (cond
       [(expr-proof-refl? proof)
        (build (expr-app base left) b dom-id env)]
       [else
        (translate-error!
         expr
         "J elimination requires a refl proof at lowering time")])]

    ;; Nil predicate — sound when scrutinee is lowered Nil (sentinel 0).
    ;; Typed surface guarantees disjointness from arbitrary Int programs.
    [(expr-nil-check arg-expr)
     (build-binary b arg-expr (expr-int 0) 'kernel-int-eq env BOOL-DOMAIN-ID #f)]

    ;; Fin indices as plain i64 (bound type argument ignored at runtime).
    [(expr-fzero _bound)
     (emit-cell! b INT-DOMAIN-ID 0)]
    [(expr-fsuc _bound inner)
     (define inner-vt (build inner b INT-DOMAIN-ID env))
     (define inner-cid (assert-scalar! inner-vt inner "expr-fsuc inner"))
     (define one-cid (emit-cell! b INT-DOMAIN-ID 1))
     (define r-cid (emit-cell! b INT-DOMAIN-ID 0))
     (emit-aligned-propagator! b (list inner-cid one-cid) r-cid 'kernel-int-add)
     r-cid]

    ;; Nat elimination — narrow executable slice (see `lower-natrec` docstring).
    [(expr-natrec mot base step target)
     (lower-natrec b dom-id env mot base step target expr)]

    ;; Nat literals (Sprint F.4). expr-nat-val holds an O(1) i64 nat;
    ;; same runtime representation as Int. expr-zero is just literal 0.
    [(expr-nat-val n)
     (unless (and (exact-integer? n) (>= n 0))
       (translate-error! expr "expr-nat-val with non-nonnegative-integer payload"))
     (emit-cell! b INT-DOMAIN-ID n)]
    [(expr-zero) (emit-cell! b INT-DOMAIN-ID 0)]

    ;; expr-suc inner — successor. Lowered as int-add(inner, 1).
    [(expr-suc inner)
     (define inner-vt (build inner b INT-DOMAIN-ID env))
     (define inner-cid (assert-scalar! inner-vt inner "expr-suc operand"))
     (define one-cid (emit-cell! b INT-DOMAIN-ID 1))
     (define r-cid (emit-cell! b INT-DOMAIN-ID 0))
     ;; F.5: align inner + one to consistent depth.
     (emit-aligned-propagator! b (list inner-cid one-cid) r-cid 'kernel-int-add)
     r-cid]

    ;; Non-dependent pair construction (Sprint F.2). Translates each
    ;; component to a vtree; the result is the 2-element list. No
    ;; new cells allocated — the components ARE the pair (no boxing).
    [(expr-pair fst-expr snd-expr)
     (define fst-vt (build fst-expr b dom-id env))
     (define snd-vt (build snd-expr b dom-id env))
     (list fst-vt snd-vt)]

    ;; Pair projection — fst returns the first component vtree.
    [(expr-fst inner)
     (define inner-vt (build inner b dom-id env))
     (assert-pair! inner-vt expr "expr-fst")
     (car inner-vt)]

    ;; Pair projection — snd returns the second component vtree.
    [(expr-snd inner)
     (define inner-vt (build inner b dom-id env))
     (assert-pair! inner-vt expr "expr-snd")
     (cadr inner-vt)]

    ;; Bound variable: look up in env. Each occurrence yields the SAME
    ;; cell-id, which means downstream propagators reading from it share
    ;; the result — this is the let-binding semantics we want.
    [(expr-bvar i)
     (when (or (< i 0) (>= i (length env)))
       (translate-error!
        expr
        (format "expr-bvar ~a escapes the let-binding scope (env depth ~a)"
                i (length env))))
     (define v (list-ref env i))
     (when (eq? v 'erased)
       (translate-error!
        expr
        (format "expr-bvar ~a refers to an erased (m0) binder; cannot use at runtime"
                i)))
     v]

    ;; Beta-redex == let-binding (single-arg). The general k-arg case
    ;; below (expr-app on an app-chain whose head is a lambda chain)
    ;; subsumes this; we keep the single case as a fast-path for the
    ;; common single let-binding shape.
    [(expr-app (expr-lam mult _type body) arg)
     (case mult
       [(m0)
        (build body b dom-id (cons 'erased env))]
       [(m1 mw)
        (define arg-cid (build arg b INT-DOMAIN-ID env))
        (build body b dom-id (cons arg-cid env))]
       [else
        (translate-error! expr (format "unknown multiplicity ~v in let-binding" mult))])]

    ;; Multi-arg beta-redex chain: (expr-app^k (expr-lam^k body) arg1 ... argk).
    ;; Produced by either source-level multi-arg let-binding or by F.1
    ;; non-recursive fvar inlining (substitute-head replaces an fvar
    ;; with a multi-binder lambda). Peel all apps + lambdas in lockstep,
    ;; evaluate each arg in caller env (innermost-arg first per de
    ;; Bruijn convention), push to env, build body.
    [(expr-app f-app arg-N)
     #:when (let peel ([e f-app])
              (match e
                [(expr-app f _) (peel f)]
                [(expr-lam _ _ _) #t]
                [_ #f]))
     ;; Collect args (outermost-first, since outer apps wrap inner) and
     ;; the lambda chain.
     (let collect ([e expr] [args '()])
       (match e
         [(expr-app f a) (collect f (cons a args))]
         [_
          ;; e is now the lambda chain head. Args is in outermost-first
          ;; order. We must apply args left-to-right, peeling one
          ;; binder at a time. The OUTERMOST lambda's binder is the
          ;; first arg in the chain (highest bvar index in body).
          (let beta ([lam e] [remaining-args args] [bound-env env])
            (cond
              [(null? remaining-args)
               (build lam b dom-id bound-env)]
              [(expr-lam? lam)
               (define mult (expr-lam-mult lam))
               (define inner-body (expr-lam-body lam))
               (case mult
                 [(m0)
                  (beta inner-body (cdr remaining-args)
                        (cons 'erased bound-env))]
                 [(m1 mw)
                  (define arg-cid
                    (build (car remaining-args) b INT-DOMAIN-ID env))
                  (beta inner-body (cdr remaining-args)
                        (cons arg-cid bound-env))]
                 [else
                  (translate-error! expr
                                    (format "unknown multiplicity ~v in beta-redex chain" mult))])]
              [else
               ;; Not enough lambdas for the args — partial overflow.
               ;; Recombine remaining args into the result expr and
               ;; recurse.
               (translate-error! expr
                                 "beta-redex chain has more args than lambda binders; \
arity mismatch in lowering")]))]))]

    ;; Unary arithmetic: (1,1) propagators.
    [(expr-int-neg a) (build-unary b a 'kernel-int-neg env)]
    [(expr-int-abs a) (build-unary b a 'kernel-int-abs env)]

    ;; Binary arithmetic: recursively translate each operand to a cell,
    ;; then allocate a result cell + install the corresponding propagator.
    [(expr-int-add a b-expr) (build-binary b a b-expr 'kernel-int-add env)]
    [(expr-int-sub a b-expr) (build-binary b a b-expr 'kernel-int-sub env)]
    [(expr-int-mul a b-expr) (build-binary b a b-expr 'kernel-int-mul env)]
    [(expr-int-div a b-expr) (build-binary b a b-expr 'kernel-int-div env)]
    [(expr-int-mod a b-expr) (build-binary b a b-expr 'kernel-int-mod env)]

    ;; Integer comparisons → Bool result cell. Kernel encodes Bool as i64
    ;; 0/1; we model the cell domain as Bool with init #f. cell-decl-init
    ;; initialization writes #f (lowered to 0); the kernel writes 0 or 1.
    [(expr-int-eq a b-expr)
     (build-binary b a b-expr 'kernel-int-eq env BOOL-DOMAIN-ID #f)]
    [(expr-int-lt a b-expr)
     (build-binary b a b-expr 'kernel-int-lt env BOOL-DOMAIN-ID #f)]
    [(expr-int-le a b-expr)
     (build-binary b a b-expr 'kernel-int-le env BOOL-DOMAIN-ID #f)]

    ;; expr-boolrec(motive, true-case, false-case, target):
    ;; eager-evaluation conditional. Both branches are translated to cells;
    ;; a select propagator picks one based on the Bool target. This is sound
    ;; for the pure-arithmetic subset (no side effects, no nontermination
    ;; in either branch). Recursive bodies will need lazy or feedback
    ;; semantics handled by Sprint B's BSP scheduler.
    [(expr-boolrec _motive true-case false-case target)
     (build-select b target true-case false-case env dom-id)]

    ;; expr-reduce: general two-arm Bool case (fib-iter's match form
    ;; elaborates to this). Same shape as boolrec — pick the arm by
    ;; cond polarity. Both arms must have 0 binding-count (no fields).
    ;; Recursive cases here are normally handled by the tail-rec
    ;; lowering at the call site (expr-app dispatch below); standalone
    ;; non-recursive expr-reduce just becomes a select.
    [(expr-reduce scrutinee
                  (list (expr-reduce-arm tag-a count-a body-a)
                        (expr-reduce-arm tag-b count-b body-b))
                  _structural?)
     (cond
       ;; Bool match — both arms have count=0; scrutinee is the cond.
       [(and (eq? tag-a 'true) (eq? tag-b 'false)
             (= count-a 0) (= count-b 0))
        (build-select b scrutinee body-a body-b env dom-id)]
       [(and (eq? tag-a 'false) (eq? tag-b 'true)
             (= count-a 0) (= count-b 0))
        (build-select b scrutinee body-b body-a env dom-id)]

       ;; Nat match (Sprint F.4) — zero arm has count=0; suc arm has
       ;; count=1 (binder for predecessor). Lower as int-eq dispatch
       ;; with predecessor-cell pushed onto env for suc body.
       [(and (eq? tag-a 'zero) (eq? tag-b 'suc)
             (= count-a 0) (= count-b 1))
        (build-nat-match b dom-id env scrutinee body-a body-b expr)]
       [(and (eq? tag-a 'suc) (eq? tag-b 'zero)
             (= count-a 1) (= count-b 0))
        (build-nat-match b dom-id env scrutinee body-b body-a expr)]

       [else
        ;; Gate 1: fall through to the general N-arm ctor match for any
        ;; other 2-arm shape (Maybe, Either, user 2-ctor ADTs).
        (build-ctor-match b dom-id env scrutinee
                          (list (expr-reduce-arm tag-a count-a body-a)
                                (expr-reduce-arm tag-b count-b body-b))
                          expr)])]

    ;; Multi-arm match (N ≥ 1, including N != 2) — Gate 1.
    [(expr-reduce scrutinee arms _)
     (build-ctor-match b dom-id env scrutinee arms expr)]

    ;; expr-app of an expr-fvar to k arguments — four-way dispatch:
    ;;   0. (Gate 1) If the head fvar is a registered ctor, lower as a
    ;;      tagged-union construction.
    ;;   1. If the fvar's body matches the tail-rec shape, lower as a
    ;;      feedback network.
    ;;   2. Else if the fvar's body is a non-recursive lambda chain,
    ;;      INLINE by substituting the lambda for the fvar reference
    ;;      and recursing. Falls through to the existing let-binding
    ;;      lowering since the result is (expr-app (expr-lam ...) arg).
    ;;   3. Else, error (non-tail recursion or undefined fvar).
    ;;
    ;; Cycle detection: `currently-inlining` parameter holds the set of
    ;; fvar names being expanded along this path. If we hit a name
    ;; already in the set, that's mutual recursion (or single-fn self-
    ;; recursion that's not tail-recursive) — error.
    [(expr-app f-expr _arg-expr)
     (let-values ([(head-name args) (peel-fvar-app-chain expr)])
       (cond
         ;; (0) Ctor application — Gate 1 rev 1.0
         [(and head-name (is-ctor-name? head-name))
          (build-ctor-application b expr head-name args env)]
         ;; (0.5) Foreign-call constant fold — Gate 3 rev 1.0
         [(let ([folded (try-fold-foreign-call b expr env)]) folded)
          => values]
         [else
          (let ([result (try-lower-tail-rec-call expr b dom-id env)])
            (cond
              [result result]
              [else
               (let ([inlined (try-inline-fvar-call expr b dom-id env)])
                 (cond
                   [inlined inlined]
                   [else
                    (translate-error!
                     expr
                     "function call not supported. The function is either \
non-tail-recursive (would need runtime call stack), self-referential in \
a non-tail position, mutually recursive, or undefined. Tail-recursive \
functions (recognized by `match-tail-rec`) and non-recursive helpers \
(inlined at lowering time) ARE supported.")]))]))]))]

    ;; Bare expr-fvar (no application) — supported only for nullary ctors;
    ;; everything else is unsupported.
    [(expr-fvar name)
     (cond
       [(is-ctor-name? name)
        (build-ctor-application b expr name '() env)]
       [else
        (translate-error! expr
                          (format "bare reference to top-level definition '~a' not supported. \
Only saturated calls to tail-recursive functions and non-recursive \
helpers are lowered."
                                  name))])]

    ;; ---- Explicit buckets (clear errors vs generic fall-through) ----

    [(expr-Type _)            (lowering-type-only! expr "Type(n)")]
    [(expr-Pi _ _ _)          (lowering-type-only! expr "Pi")]
    [(expr-Sigma _ _)         (lowering-type-only! expr "Sigma")]
    [(expr-Eq _ _ _)          (lowering-type-only! expr "Eq")]
    [(expr-union _ _)         (lowering-type-only! expr "union")]
    [(expr-Vec _ _)           (lowering-deferred-substrate! expr "Vec")]
    [(expr-Fin _)             (lowering-type-only! expr "Fin type")]
    [(expr-Nat)               (lowering-type-only! expr "Nat type")]
    [(expr-Bool)              (lowering-type-only! expr "Bool type")]
    [(expr-Unit)              (lowering-type-only! expr "Unit type")]
    [(expr-Nil)               (lowering-type-only! expr "Nil type")]

    [(expr-vnil _)            (lowering-deferred-substrate! expr "vnil")]
    [(expr-vcons _ _ _ _)     (lowering-deferred-substrate! expr "vcons")]
    [(expr-vhead _ _ _)       (lowering-deferred-substrate! expr "vhead")]
    [(expr-vtail _ _ _)       (lowering-deferred-substrate! expr "vtail")]
    [(expr-vindex _ _ _ _)    (lowering-deferred-substrate! expr "vindex")]

    [(expr-char _)            (lowering-deferred-substrate! expr "Char")]
    [(expr-string _)         (lowering-deferred-substrate! expr "String")]
    [(expr-hole)             (translate-error! expr "lowering: unsolved metavar (hole)")]
    [(expr-meta _ _)         (translate-error! expr "lowering: expr-meta should not reach codegen")]
    [(expr-tycon _)          (lowering-type-only! expr "type constructor")]

    [(expr-generic-add _ _)  (lowering-deferred-substrate! expr "generic arithmetic (+)")]
    [(expr-generic-sub _ _)  (lowering-deferred-substrate! expr "generic arithmetic (-)")]
    [(expr-generic-mul _ _)  (lowering-deferred-substrate! expr "generic arithmetic (*)")]
    [(expr-generic-div _ _)  (lowering-deferred-substrate! expr "generic arithmetic (/)")]
    [(expr-generic-mod _ _)  (lowering-deferred-substrate! expr "generic arithmetic (mod)")]
    [(expr-generic-lt _ _)   (lowering-deferred-substrate! expr "generic comparison (<)")]
    [(expr-generic-le _ _)   (lowering-deferred-substrate! expr "generic comparison (<=)")]
    [(expr-generic-gt _ _)   (lowering-deferred-substrate! expr "generic comparison (>)")]
    [(expr-generic-ge _ _)   (lowering-deferred-substrate! expr "generic comparison (>=)")]
    [(expr-generic-eq _ _)   (lowering-deferred-substrate! expr "generic comparison (=)")]
    [(expr-generic-negate _) (lowering-deferred-substrate! expr "generic negate")]
    [(expr-generic-abs _)    (lowering-deferred-substrate! expr "generic abs")]
    [(expr-generic-from-int _ _)
     (lowering-deferred-substrate! expr "generic-from-int")]
    [(expr-generic-from-rat _ _)
     (lowering-deferred-substrate! expr "generic-from-rat")]

    [_
     (translate-error!
      expr
      "Lowering does not implement this expression yet — likely Posit/Rational/collections/FFI/FIRST CLASS FUNCTIONS/session-logic (see docs/tracking/2026-05-01_SH_LOWERING_FEATURE_MAP.md).")]))

(define (build-unary b a-expr tag env [out-dom INT-DOMAIN-ID] [out-init 0])
  (define a-vt (build a-expr b INT-DOMAIN-ID env))
  (define a-cid (assert-scalar! a-vt a-expr (format "unary op '~a' operand" tag)))
  (define r-cid (emit-cell! b out-dom out-init))
  ;; F.5: single-input alignment is identity, but emit-aligned-propagator!
  ;; tracks depth bookkeeping consistently regardless of arity.
  (emit-aligned-propagator! b (list a-cid) r-cid tag)
  r-cid)

;; ============================================================
;; Gate 1 (rev 1.0) — tagged-union ctor application & match
;; ============================================================
;;
;; Strategy: defunctionalize per type. Every ADT value uses a flat
;; cell layout: 1 tag cell + sum-of-ctor-arities slot cells. All
;; values of the type share the same layout (some slots may be
;; unused for a given ctor; their default value is 0).
;;
;; This rev (1.0) supports:
;;   - Non-recursive ADTs only (no field whose type is the ADT itself).
;;   - Field types must lower to scalar (Int / Bool / Nat) cells.
;;   - Type args are erased and skipped during arg peeling.
;;
;; Recursive ADTs (List, Tree) and ADT-typed fields (Maybe (Maybe Int))
;; require nested vtree slot-types and are deferred to rev 1.1+ /
;; rev 2 (heap).

;; lookup-ctor handles bare ctor names (e.g. 'some). When the
;; elaborator qualifies them (e.g. 'examples::n9-sums::maybe-some::some)
;; we strip the namespace prefix and retry. The name format uses '::'
;; separators per `qualify-name` in macros.rkt.
(define (lookup-ctor* name)
  (cond
    [(lookup-ctor name)]
    [else
     (define s (symbol->string name))
     (define m (regexp-match #px"::([^:]+)$" s))
     (cond
       [m (lookup-ctor (string->symbol (cadr m)))]
       [else #f])]))

(define (lookup-type-ctors* name)
  (cond
    [(lookup-type-ctors name)]
    [else
     (define s (symbol->string name))
     (define m (regexp-match #px"::([^:]+)$" s))
     (cond
       [m (lookup-type-ctors (string->symbol (cadr m)))]
       [else #f])]))

(define (is-ctor-name? sym) (and sym (lookup-ctor* sym) #t))

;; ============================================================
;; Gate 3 (rev 1.0) — foreign-call constant folding
;; ============================================================
;;
;; Prologos's string ops are foreign Racket procedures (see
;; lib/prologos/data/string.prologos). At native runtime there is no
;; Racket VM, so we cannot lower foreign calls to native code. We CAN
;; constant-fold a foreign call when all its value args are literals,
;; emitting just the result as a literal cell.
;;
;; This makes simple compile-time string programs lower (e.g.
;; `length "hello"` → 5), but does NOT add any runtime string support.
;; See docs/tracking/2026-05-02_GATE3_STRINGS_DESIGN.md § 8 for rev 2.

;; lookup-foreign-fn : symbol → expr-foreign-fn-or-#f
(define (lookup-foreign-fn name)
  (define v
    (with-handlers ([exn:fail? (lambda _ #f)])
      (global-env-lookup-value name)))
  (and (expr-foreign-fn? v) v))

;; expr-to-literal-value : expr → (or scalar #f)
;; If `e` is a literal, return its Racket value; else #f.
;; Strings are returned as Racket strings; chars as Racket chars.
(define (expr-to-literal-value e)
  (match e
    [(expr-int n) n]
    [(expr-true) #t]
    [(expr-false) #f]
    [(expr-string s) s]
    [(expr-char c) c]
    [_ #f]))

;; literal-value-to-vtree : builder × any × expr → vtree
;; Embed a Racket value as a fresh i64/Bool cell. Strings cannot be
;; embedded in rev 1.0 (no runtime string representation).
(define (literal-value-to-vtree b val err-expr)
  (cond
    [(exact-integer? val) (emit-cell! b INT-DOMAIN-ID val)]
    [(boolean? val) (emit-cell! b BOOL-DOMAIN-ID val)]
    [(char? val) (emit-cell! b INT-DOMAIN-ID (char->integer val))]
    [(string? val)
     (translate-error!
      err-expr
      (format "constant-folded foreign call returned a string ~v; \
strings have no runtime representation in rev 1.0. Wrap with a foreign \
op that reduces to Int/Bool (e.g. length, eq) instead."
              val))]
    [else
     (translate-error!
      err-expr
      (format "constant-folded foreign call returned ~v of unsupported type \
(only Int/Bool/Char results lower in rev 1.0)" val))]))

;; expr-is-literal? : expr → bool
(define (expr-is-literal? e)
  (or (expr-int? e) (expr-true? e) (expr-false? e)
      (expr-string? e) (expr-char? e)))

;; value-to-literal-expr : Racket value → expr-or-#f
;; Re-wrap a Racket value into a Prologos literal expr (so the
;; marshal-in functions, which expect literal exprs, can run
;; recursively on constant-folded subresults).
(define (value-to-literal-expr v)
  (cond
    [(exact-integer? v) (expr-int v)]
    [(eq? v #t) (expr-true)]
    [(eq? v #f) (expr-false)]
    [(string? v) (expr-string v)]
    [(char? v) (expr-char v)]
    [else #f]))

;; try-fold-foreign-call : expr × env → vtree-or-#f
;; If the head fvar of `expr` is an `expr-foreign-fn` and ALL value
;; args are (after recursive folding) literal exprs, evaluate the
;; foreign procedure at compile time and return its result as a vtree.
;; Else return #f and the caller falls through.
;;
;; Recursively folds nested foreign calls: `(length (append "ab" "cd"))`
;; first folds the inner `append` call to `(expr-string "abcd")`, then
;; folds the outer `length` call to `4`.
(define (try-fold-foreign-call b expr env)
  (let-values ([(head-name args) (peel-fvar-app-chain expr)])
    (define ff (and head-name (lookup-foreign-fn head-name)))
    (cond
      [(not ff) #f]
      [else
       (define-values (_t-args v-args) (split-type-and-value-args args))
       (cond
         [(not (= (length v-args) (expr-foreign-fn-arity ff))) #f]
         [else
          ;; Recursively try to fold each arg to a literal expr.
          (define lit-arg-exprs
            (for/list ([va (in-list v-args)])
              (cond
                [(expr-is-literal? va) va]
                [else (try-recursive-fold va env)])))
          (cond
            [(memq #f lit-arg-exprs) #f]                  ; some arg not foldable → bail
            [else
             (define marshalled
               (for/list ([m (in-list (expr-foreign-fn-marshal-in ff))]
                          [v (in-list lit-arg-exprs)])
                 (m v)))
             (define proc (expr-foreign-fn-proc ff))
             (define raw-result
               (with-handlers
                 ([exn:fail?
                   (lambda (e)
                     (translate-error!
                      expr
                      (format "constant-folding foreign call '~a' raised: ~a"
                              head-name (exn-message e))))])
                 (apply proc marshalled)))
             ;; The marshal-out expects the raw Racket result and returns a
             ;; Prologos expr (e.g. expr-int for an i64 result).
             (define unmarshal (expr-foreign-fn-marshal-out ff))
             (define unmarshalled (unmarshal raw-result))
             (cond
               [(and unmarshalled
                     (or (exact-integer? (expr-to-literal-value unmarshalled))
                         (boolean? (expr-to-literal-value unmarshalled))
                         (char? (expr-to-literal-value unmarshalled))))
                (literal-value-to-vtree
                 b (expr-to-literal-value unmarshalled) expr)]
               [(expr-string? unmarshalled)
                ;; Result is a string — no scalar lowering, but the value
                ;; may be useful as a sub-fold for an enclosing foreign call.
                ;; In that case the enclosing call's try-recursive-fold
                ;; consumes the string-literal expr; here as a top-level
                ;; result we error.
                (translate-error!
                 expr
                 (format "foreign call '~a' constant-folded to a string \
~v; strings have no runtime cell representation in rev 1.0. Wrap with \
length / eq / etc. to produce an Int / Bool result."
                         head-name (expr-string-val unmarshalled)))]
               [else #f])])])])))

;; try-recursive-fold : expr × env → expr-or-#f
;; Fold a nested expr to a literal expr (string / int / bool / char) if
;; possible. Used by try-fold-foreign-call to handle nested foreign
;; calls like (length (append "ab" "cd")) — the inner `append` is folded
;; to expr-string "abcd", then the outer length is foldable.
(define (try-recursive-fold expr env)
  (let-values ([(head-name args) (peel-fvar-app-chain expr)])
    (define ff (and head-name (lookup-foreign-fn head-name)))
    (cond
      [(not ff) #f]
      [else
       (define-values (_t-args v-args) (split-type-and-value-args args))
       (cond
         [(not (= (length v-args) (expr-foreign-fn-arity ff))) #f]
         [else
          (define lit-arg-exprs
            (for/list ([va (in-list v-args)])
              (cond
                [(expr-is-literal? va) va]
                [else (try-recursive-fold va env)])))
          (cond
            [(memq #f lit-arg-exprs) #f]
            [else
             (define marshalled
               (for/list ([m (in-list (expr-foreign-fn-marshal-in ff))]
                          [v (in-list lit-arg-exprs)])
                 (m v)))
             (define proc (expr-foreign-fn-proc ff))
             (define raw-result
               (with-handlers ([exn:fail? (lambda _ #f)])
                 (apply proc marshalled)))
             (cond
               [(not raw-result) #f]
               [else
                (define unmarshal (expr-foreign-fn-marshal-out ff))
                (define unmarshalled (unmarshal raw-result))
                (cond
                  [(and unmarshalled (expr-is-literal? unmarshalled))
                   unmarshalled]
                  [(value-to-literal-expr raw-result)
                   ;; Fallback: marshal-out couldn't unmarshal but the
                   ;; raw result IS a Racket primitive we can wrap.
                   => values]
                  [else #f])])])])])))

;; type-flat-slot-count : symbol → nat
;; Sum the field arities of all ctors of the named ADT type. Errors
;; if the type isn't registered.
(define (type-flat-slot-count type-name)
  (define ctors (lookup-type-ctors* type-name))
  (unless ctors
    (error 'type-flat-slot-count "unknown ADT type: ~a" type-name))
  (for/sum ([c (in-list ctors)])
    (define meta (lookup-ctor* c))
    (length (ctor-meta-field-types meta))))

;; ctor-flat-field-offset : symbol → nat
;; Offset of this ctor's first field within the type's flat slot list.
;; (Sum of arities of ctors with smaller branch indices.)
(define (ctor-flat-field-offset ctor-name)
  (define meta (lookup-ctor* ctor-name))
  (define type-name (ctor-meta-type-name meta))
  (define this-branch (ctor-meta-branch-index meta))
  (define ctors (lookup-type-ctors* type-name))
  (for/sum ([c (in-list ctors)] [i (in-naturals)] #:when (< i this-branch))
    (length (ctor-meta-field-types (lookup-ctor* c)))))

;; type-arg? : expr → bool
;; Heuristic for distinguishing erased type args from value args in
;; an elaborated expr-app chain. Type args appear leftmost (curried
;; first) thanks to the Pi (A : Type) binders.
(define (type-arg? e)
  (match e
    [(expr-Int) #t]
    [(expr-Bool) #t]
    [(expr-Nat) #t]
    [(expr-Type _) #t]
    [(expr-Pi _ _ _) #t]
    [(expr-app (expr-fvar T) _) (and (lookup-type-ctors* T) #t)]
    [(expr-fvar T) (and (lookup-type-ctors* T) #t)]
    [_ #f]))

;; peel-fvar-app-chain : expr → (values fvar-name|#f arg-list)
;; Walk a left-associated app chain. Returns the head fvar's name (or
;; #f if the head isn't an fvar) and the args in left-to-right order.
(define (peel-fvar-app-chain e)
  (let loop ([e e] [args '()])
    (match e
      [(expr-app f a) (loop f (cons a args))]
      [(expr-fvar name) (values name args)]
      [_ (values #f args)])))

;; split-type-and-value-args : (Listof expr) → (values type-args value-args)
;; The leading prefix of args matching `type-arg?` are type args; the
;; rest are value args.
(define (split-type-and-value-args args)
  (define-values (types vals) (splitf-at args type-arg?))
  (values types vals))

;; build-ctor-application : builder × expr × symbol × (Listof expr) × env → ctor-vt
;; Lower (C type-args… value-args…) to a ctor-vt.
(define (build-ctor-application b expr ctor-name args env)
  (define meta (lookup-ctor* ctor-name))
  (unless meta
    (translate-error! expr
                      (format "internal: '~a' not in ctor registry" ctor-name)))
  ;; Rev 1.0: refuse recursive ctors (any field whose is-recursive flag is #t).
  (when (ormap values (ctor-meta-is-recursive meta))
    (translate-error!
     expr
     (format "ctor '~a' of type ~a has recursive field(s); recursive ADTs \
need a heap-backed runtime (Gate 1 rev 2 — not yet implemented). Maybe / \
Either / non-recursive user ADTs work in rev 1."
             ctor-name (ctor-meta-type-name meta))))
  (define type-name (ctor-meta-type-name meta))
  (define-values (_type-args value-args) (split-type-and-value-args args))
  (define expected-arity (length (ctor-meta-field-types meta)))
  (unless (= (length value-args) expected-arity)
    (translate-error!
     expr
     (format "ctor '~a' expects ~a value field(s), got ~a"
             ctor-name expected-arity (length value-args))))
  ;; Build each value arg first (in caller env). Rev 1.0: each value
  ;; arg must lower to a SCALAR (Int/Bool cell).
  (define value-cids
    (for/list ([va (in-list value-args)] [i (in-naturals)])
      (define vt (build va b INT-DOMAIN-ID env))
      (assert-scalar! vt va
                      (format "ctor '~a' field ~a (rev 1.0 supports scalar fields only; \
nested ADT fields are rev 1.1+)" ctor-name i))))
  ;; Tag cell: i64 holding the branch index. Static literal value.
  (define branch-idx (ctor-meta-branch-index meta))
  (define tag-cid (emit-cell! b INT-DOMAIN-ID branch-idx))
  ;; Slot cells: allocate the type's full flat slot count, default 0.
  ;; For each value field of this ctor, plug in the value-arg cell at
  ;; the correct offset. Other ctors' slots stay at default 0 — the
  ;; match never reads them when the tag selects another arm.
  ;;
  ;; Subtlety: we want the slot cell to hold the value-arg's value,
  ;; not just be a separate cell. Use a kernel-identity propagator to
  ;; copy. (Allocating the slot cell with the value-arg's cell-id
  ;; directly would break shape uniformity — different constructions
  ;; would land in different cells.)
  (define n-slots (type-flat-slot-count type-name))
  (define this-offset (ctor-flat-field-offset ctor-name))
  (define slot-cids
    (for/list ([slot-i (in-range n-slots)])
      (emit-cell! b INT-DOMAIN-ID 0)))
  (for ([value-cid (in-list value-cids)] [i (in-naturals)])
    (define slot-cid (list-ref slot-cids (+ this-offset i)))
    (emit-aligned-propagator! b (list value-cid) slot-cid 'kernel-identity))
  (ctor-vt type-name tag-cid slot-cids))

;; build-ctor-match : builder × dom-id × env × expr × (Listof expr-reduce-arm) × expr → vtree
;; Lower an N-arm match against an ADT scrutinee.
;;
;; Strategy: build the scrutinee as a ctor-vt; for each arm compute
;; the body's vtree (with field cells pushed onto env per the arm's
;; binding-count and the ctor's flat offset); then build a left-
;; leaning select cascade dispatching on the tag cell.
(define (build-ctor-match b dom-id env scrut-expr arms err-expr)
  (when (null? arms)
    (translate-error! err-expr "match has no arms"))
  ;; Look up type info from any arm's ctor. All arms must be ctors of
  ;; the same type.
  (define first-ctor (expr-reduce-arm-ctor-name (car arms)))
  (define first-meta (lookup-ctor* first-ctor))
  (unless first-meta
    (translate-error! err-expr
                      (format "match arm ctor '~a' is not a registered ctor; \
this match shape is not (yet) lowered." first-ctor)))
  (define type-name (ctor-meta-type-name first-meta))
  (define type-ctors (lookup-type-ctors* type-name))
  (unless type-ctors
    (translate-error! err-expr
                      (format "ctor '~a' references unknown type ~a"
                              first-ctor type-name)))
  ;; Verify all arms are ctors of this type and arities match.
  (for ([arm (in-list arms)])
    (define c (expr-reduce-arm-ctor-name arm))
    (define m (lookup-ctor* c))
    (unless m
      (translate-error! err-expr
                        (format "match arm ctor '~a' is not a registered ctor"
                                c)))
    (unless (eq? (ctor-meta-type-name m) type-name)
      (translate-error! err-expr
                        (format "match arms span multiple types (~a vs ~a); \
all arms of a single match must belong to the same ADT."
                                type-name (ctor-meta-type-name m))))
    (unless (= (expr-reduce-arm-binding-count arm)
               (length (ctor-meta-field-types m)))
      (translate-error! err-expr
                        (format "ctor '~a' expects ~a field-binders, arm has ~a"
                                c (length (ctor-meta-field-types m))
                                (expr-reduce-arm-binding-count arm)))))
  ;; Build scrutinee. Must be a ctor-vt of `type-name`.
  (define scrut-vt (build scrut-expr b INT-DOMAIN-ID env))
  (unless (ctor-vt? scrut-vt)
    (translate-error! scrut-expr
                      (format "match scrutinee was expected to be a ~a value, \
but lowered to a non-ctor vtree (~v)." type-name scrut-vt)))
  (unless (eq? (ctor-vt-type-name scrut-vt) type-name)
    (translate-error! scrut-expr
                      (format "match scrutinee type ~a doesn't match arm ctor type ~a"
                              (ctor-vt-type-name scrut-vt) type-name)))
  (define tag-cid (ctor-vt-tag-cid scrut-vt))
  (define slot-cids (ctor-vt-slot-cids scrut-vt))
  ;; Build each arm's body in env extended with the arm's field cells.
  ;; Arms can appear in any order; index by the arm's ctor branch-idx.
  ;; Build up a list (sorted by arm appearance order) of (branch-idx . body-vtree).
  (define arm-results
    (for/list ([arm (in-list arms)])
      (define c (expr-reduce-arm-ctor-name arm))
      (define m (lookup-ctor* c))
      (define b-idx (ctor-meta-branch-index m))
      (define offset (ctor-flat-field-offset c))
      (define n-fields (length (ctor-meta-field-types m)))
      (define field-cids
        (for/list ([i (in-range n-fields)]) (list-ref slot-cids (+ offset i))))
      ;; Field binders are pushed onto env in declaration order so
      ;; that the LAST-listed binder ends up at the head of env (de
      ;; Bruijn 0). The elaborator uses this convention: for `cons a
      ;; r → match r ...`, the body's `(expr-bvar 0)` refers to `r`,
      ;; `(expr-bvar 1)` refers to `a`. (Single-field arms are
      ;; insensitive to this order, which is why Maybe / Either
      ;; worked before this fix.) Cross-checked against build-nat-
      ;; match, where suc's single predecessor binder is consed
      ;; directly onto env (bvar 0 = predecessor).
      (define new-env
        (for/fold ([e env]) ([f (in-list field-cids)])
          (cons f e)))
      (define body-vt (build (expr-reduce-arm-body arm) b dom-id new-env))
      (cons b-idx body-vt)))
  ;; Build a left-leaning select cascade keyed on tag-cid.
  ;;   For arms with branch indices i₀, i₁, …, i_{n-1} (in arm order):
  ;;     dispatch = if (tag == i₀) then body₀
  ;;                else if (tag == i₁) then body₁
  ;;                ...
  ;;                else body_{n-1}
  ;;
  ;; The last arm becomes the fallthrough (its tag-eq isn't tested). For
  ;; total coverage of all ctors of the type, callers should provide an
  ;; arm per ctor; if not, the fallthrough arm "absorbs" the missing
  ;; ones (which is the standard match-fallthrough semantics).
  (define rev-arms (reverse arm-results))
  (define final-vt (cdr (car rev-arms)))
  (define remaining (cdr rev-arms))
  (for/fold ([acc-vt final-vt]) ([entry (in-list remaining)])
    (define b-idx (car entry))
    (define body-vt (cdr entry))
    ;; cond = (tag == b-idx)
    (define const-cid (emit-cell! b INT-DOMAIN-ID b-idx))
    (define cond-cid (emit-cell! b BOOL-DOMAIN-ID #f))
    (emit-aligned-propagator! b (list tag-cid const-cid) cond-cid 'kernel-int-eq)
    (build-select-vtree b cond-cid body-vt acc-vt err-expr dom-id)))

(define (build-binary b a-expr b-expr tag env [out-dom INT-DOMAIN-ID]
                      [out-init 0])
  (define a-vt (build a-expr b INT-DOMAIN-ID env))
  (define b-vt (build b-expr b INT-DOMAIN-ID env))
  (define a-cid (assert-scalar! a-vt a-expr (format "binary op '~a' lhs" tag)))
  (define b-cid (assert-scalar! b-vt b-expr (format "binary op '~a' rhs" tag)))
  (define r-cid (emit-cell! b out-dom out-init))
  ;; F.5: align input depths so the binary op reads consistent values.
  (emit-aligned-propagator! b (list a-cid b-cid) r-cid tag)
  r-cid)

;; build-nat-match (Sprint F.4): lower `match scrut | zero -> z-body
;; | suc m -> s-body` to a select gated on `(int-eq scrut 0)`. The
;; suc body executes in env extended with a "predecessor" cell
;; holding `(int-sub scrut 1)` — bvar 0 in s-body refers to it.
;;
;; Polarity: select(cond, z-body, s-body). cond=1 (scrut==0) → z-body;
;; cond=0 → s-body.
(define (build-nat-match b dom-id env scrut-expr z-body s-body err-expr)
  (define scrut-vt (build scrut-expr b INT-DOMAIN-ID env))
  (define scrut-cid (assert-scalar! scrut-vt scrut-expr "Nat match scrutinee"))
  ;; cond = (scrut == 0). F.5: aligned-emit so scrut + zero-lit are
  ;; read at consistent depth.
  (define zero-lit-cid (emit-cell! b INT-DOMAIN-ID 0))
  (define cond-cid (emit-cell! b BOOL-DOMAIN-ID #f))
  (emit-aligned-propagator! b (list scrut-cid zero-lit-cid) cond-cid 'kernel-int-eq)
  ;; predecessor = scrut - 1 (only used in s-body's env). Aligned.
  (define one-lit-cid (emit-cell! b INT-DOMAIN-ID 1))
  (define pred-cid (emit-cell! b INT-DOMAIN-ID 0))
  (emit-aligned-propagator! b (list scrut-cid one-lit-cid) pred-cid 'kernel-int-sub)
  ;; Build both bodies (eagerly, like boolrec). Suc body's env has
  ;; the predecessor as a new innermost binder.
  (define z-vt (build z-body b dom-id env))
  (define s-vt (build s-body b dom-id (cons pred-cid env)))
  (build-select-vtree b cond-cid z-vt s-vt err-expr dom-id))

;; build-select: cond-expr must be scalar (Bool); then/else can be
;; arbitrary vtrees as long as their shapes match. For pair-typed
;; branches, lower as a per-component select cascade (one (3,1)
;; propagator per scalar leaf in the result tree).
(define (build-select b cond-expr then-expr else-expr env out-dom)
  (define c-vt (build cond-expr b BOOL-DOMAIN-ID env))
  (define c-cid (assert-scalar! c-vt cond-expr "select condition"))
  (define t-vt (build then-expr b out-dom env))
  (define e-vt (build else-expr b out-dom env))
  (build-select-vtree b c-cid t-vt e-vt then-expr out-dom))

;; Recursively build select propagators per leaf. t-vt and e-vt must
;; have matching shapes; we error if not. Returns a vtree of result
;; cell-ids matching the shape.
(define (build-select-vtree b c-cid t-vt e-vt err-expr out-dom)
  (cond
    [(and (vtree-scalar? t-vt) (vtree-scalar? e-vt))
     (define init-val (case out-dom [(0) 0] [(1) #f] [else 0]))
     (define r-cid (emit-cell! b out-dom init-val))
     ;; F.5: align cond + then + else to same depth.
     (emit-aligned-propagator! b (list c-cid t-vt e-vt) r-cid 'kernel-select)
     r-cid]
    [(and (list? t-vt) (list? e-vt) (= (length t-vt) (length e-vt)))
     (for/list ([t (in-list t-vt)] [e (in-list e-vt)])
       (build-select-vtree b c-cid t e err-expr out-dom))]
    [(and (ctor-vt? t-vt) (ctor-vt? e-vt)
          (eq? (ctor-vt-type-name t-vt) (ctor-vt-type-name e-vt))
          (= (length (ctor-vt-slot-cids t-vt))
             (length (ctor-vt-slot-cids e-vt))))
     ;; Gate 1: per-cell select on tag + each slot. Result is a fresh
     ;; ctor-vt with the same type-name. All slot domains are INT.
     (define new-tag-cid
       (build-select-vtree b c-cid
                           (ctor-vt-tag-cid t-vt)
                           (ctor-vt-tag-cid e-vt)
                           err-expr INT-DOMAIN-ID))
     (define new-slot-cids
       (for/list ([t-slot (in-list (ctor-vt-slot-cids t-vt))]
                  [e-slot (in-list (ctor-vt-slot-cids e-vt))])
         (build-select-vtree b c-cid t-slot e-slot err-expr INT-DOMAIN-ID)))
     (ctor-vt (ctor-vt-type-name t-vt) new-tag-cid new-slot-cids)]
    [else
     (translate-error!
      err-expr
      (format "select branches have mismatched shapes: then=~v else=~v"
              t-vt e-vt))]))

;; ============================================================
;; ast-to-low-pnet : Expr × Expr × String → low-pnet
;; ============================================================
;;
;; Public entry point. main-type and main-body come from
;; (global-env-lookup-type 'main) / (global-env-lookup-value 'main)
;; after process-file. source-file is the .prologos path, used for the
;; meta-decl.

;; build-parameterised-main : (Listof type) × main-body × builder × dom-id → vtree
;;
;; Entry-point variant for `def main : T1 -> T2 -> ... -> R := \x.\y...body`.
;;
;;   1. Peel matching lambda binders from main-body. Reject mismatched arity.
;;   2. Validate each parameter type is Int (extending later).
;;   3. Allocate one INT-DOMAIN cell per parameter (init=0; will be
;;      overwritten at runtime by the LLVM lowering pass via
;;      prologos_argv_i64 + prologos_cell_write before quiescence).
;;   4. Build the env in DE BRUIJN order: innermost binder at the
;;      head, outermost at the tail. For `\x.\y.body`:
;;        - x is bvar 1 → at index 1 → tail of env
;;        - y is bvar 0 → at index 0 → head of env
;;      So we cons input cells onto env outermost-first (left-fold),
;;      which puts the LAST-LISTED parameter (innermost) at the head.
;;   5. Mirror the same shape into current-static-env with 'unknown
;;      values, so try-static-eval treats every reference to these
;;      bvars as UNFOLDABLE — the body's expression cannot collapse
;;      to a literal at compile time.
;;   6. Build the body in the seeded env. Subsequent (expr-bvar i)
;;      lookups resolve to the input cell ids; subsequent static-eval
;;      attempts return UNFOLDABLE.
;;   7. Stash the input cell ids on the builder for the final meta-decl
;;      emission in ast-to-low-pnet.
(define (build-parameterised-main param-types main-body b result-domain)
  (define n (length param-types))
  (define-values (lam-arg-types body-after-lams) (peel-lambdas main-body))
  (unless (= n (length lam-arg-types))
    (translate-error!
     main-body
     (format
      "main has type with ~a parameter(s) but body has ~a lambda binder(s); \
explicit lambdas are required for parameterised main (eta-expansion / \
fvar-only bodies are not yet supported)"
      n (length lam-arg-types))))
  (for ([t (in-list param-types)] [i (in-naturals)])
    (unless (or (expr-Int? t) (expr-Nat? t))
      (translate-error!
       t
       (format
        "parameter ~a of main has type ~v; only Int / Nat parameters \
are supported (Bool / String / ADT input deferred to a later milestone)"
        i t))))

  ;; Allocate input cells (one per parameter), in declaration order.
  ;; emit-cell! returns cell-ids in increasing order; for a 2-arg main
  ;; this gives input-cells = (0 1) where 0 is the OUTER param.
  (define input-cells
    (for/list ([_t (in-list param-types)])
      (emit-cell! b INT-DOMAIN-ID 0)))

  ;; Build env in de Bruijn order: innermost (last-listed) at head.
  ;; Cons in declaration order so the last parameter ends up at the
  ;; head and is reached by (expr-bvar 0).
  (define env
    (for/fold ([env '()])
              ([cid (in-list input-cells)])
      (cons cid env)))
  (define lit-env
    (for/fold ([le '()])
              ([_t (in-list param-types)])
      (cons 'unknown le)))

  ;; Stash the input-cell ids on the builder so ast-to-low-pnet can
  ;; emit the meta-decl signature after the build pass completes.
  (set-builder-input-cells! b input-cells)

  (with-static-extension lit-env
    (build body-after-lams b result-domain env)))

;; Peel an arrow chain from a type expression. Returns (values
;; param-types codomain). param-types is OUTERMOST-FIRST; codomain
;; is the final non-Pi type. For a non-Pi type, returns ('() T).
;;
;; Examples:
;;   Int                      → '()              , Int
;;   Int -> Int               → '(Int)           , Int
;;   Int -> Bool -> Int       → '(Int Bool)      , Int
;;
;; lowering-yolo M3 (2026-05-02): used by ast-to-low-pnet's
;; parameterised-main entry path. Today we only support `Int -> Int`
;; (one Int parameter); the function returns the full chain so the
;; caller can give targeted error messages.
(define (peel-pi t)
  (let loop ([t t] [acc '()])
    (match t
      [(expr-Pi 'mw dom cod) (loop cod (cons dom acc))]
      [_ (values (reverse acc) t)])))

(define (ast-to-low-pnet main-type main-body source-file)
  (define b (make-builder))
  (define-values (param-types codomain-type) (peel-pi main-type))
  (define n-params (length param-types))

  ;; Choose the result-domain (from codomain) and walk the body. The
  ;; closed-main path matches the historical behavior; the
  ;; parameterised-main path (n-params > 0) allocates one input cell
  ;; per parameter, seeds the body's env / static-env, and emits
  ;; meta-decls describing the input plumbing for the LLVM lowering
  ;; pass to consume.
  (define result-domain
    (cond
      [(expr-Int? codomain-type) INT-DOMAIN-ID]
      [(expr-Nat? codomain-type) INT-DOMAIN-ID]
      [(expr-Bool? codomain-type) BOOL-DOMAIN-ID]
      [else
       (translate-error! codomain-type
                         "main must ultimately return Int, Nat, or Bool")]))

  (define result-vt
    (cond
      [(zero? n-params)
       ;; Closed main — original entry path. main-body is the value
       ;; expression directly; no lambda peeling, empty env.
       (build main-body b result-domain '())]
      [else
       ;; Parameterised main (lowering-yolo M3, 2026-05-02). Today we
       ;; only support Int / Nat parameters and a Pi-typed main with
       ;; an explicit lambda for each binder. Multi-parameter is
       ;; allowed but the actual argv plumbing in low-pnet-to-llvm
       ;; only wires up the first one for now (the meta-decls list
       ;; them all so the gating is honest).
       (build-parameterised-main param-types main-body b result-domain)]))
  ;; The top-level entry-decl points at ONE cell. main must produce a
  ;; scalar; pair-typed `def main` is rejected (the binary's exit code
  ;; is single-valued). Helpers and intermediate expressions can be
  ;; pair-typed; only `main` is constrained.
  (define result-cid (assert-scalar! result-vt main-body
                                     "main result"))

  ;; Sprint F.6: depth-balance invariant check. Every multi-input
  ;; propagator should have all its inputs at the same depth (after
  ;; F.5's emit-aligned-propagator! lifting + F.6's coalescing).
  ;; Identity propagators (kernel-identity) are EXEMPT — they're
  ;; designed to bridge depths, so by definition their input is at
  ;; depth N-1 while output is at N.
  (assert-depth-balance-invariant! b)

  ;; Determine which domains we actually emitted (any cell with that
  ;; domain-id). Emit domain-decls for those.
  (define cells-emitted (reverse (builder-cells b)))
  (define props-emitted (reverse (builder-props b)))
  (define deps-emitted (reverse (builder-deps b)))

  (define used-int?
    (for/or ([c (in-list cells-emitted)])
      (= (cell-decl-domain-id c) INT-DOMAIN-ID)))
  (define used-bool?
    (for/or ([c (in-list cells-emitted)])
      (= (cell-decl-domain-id c) BOOL-DOMAIN-ID)))

  (define domain-decls
    (filter values
            (list
             (and used-int?
                  (domain-decl INT-DOMAIN-ID 'int 'kernel-merge-int 0 'never))
             (and used-bool?
                  (domain-decl BOOL-DOMAIN-ID 'bool 'kernel-merge-bool #f 'never)))))

  (define meta (meta-decl 'source-file source-file))

  ;; kernel-PU Phase 4 Day 9: emit a signature meta-decl iff lower-tail-rec
  ;; ran. Verifies the substrate iteration pattern (§ 5.5 of
  ;; docs/tracking/2026-05-02_KERNEL_POCKET_UNIVERSES.md) was emitted —
  ;; namely, cells + kernel-identity feedback + per-leaf arithmetic +
  ;; kernel-select halt-guard. The pattern variant is `lww-feedback-v1`
  ;; (LWW state cells + propagator-firing-driven re-enqueue, observationally
  ;; equivalent to the design doc's cell_reset+tick variant which is a
  ;; future optimization; see § 5.5 "Iteration's advance state pattern").
  ;; Day 9 test gate: tail-rec acceptance examples (n2-tailrec/*) produce
  ;; this meta-decl; non-tail-rec programs do not.
  (define tail-rec-meta
    (if (> (builder-tail-rec-count b) 0)
        (list (meta-decl 'tail-rec-pattern 'lww-feedback-v1)
              (meta-decl 'tail-rec-count (builder-tail-rec-count b)))
        '()))

  ;; lowering-yolo M3 (2026-05-02): parameterised-main meta-decls.
  ;; Two signatures:
  ;;   (meta-decl input-cells (cid0 cid1 ...))   ; outermost-first
  ;;   (meta-decl main-prints-result #t)         ; signal stdout printing
  ;;
  ;; Both are emitted iff main has at least one parameter. The
  ;; low-pnet-to-llvm pass scans for these and:
  ;;   - reshapes @main from `i64 @main()` to `i32 @main(i32, i8**)`
  ;;   - emits one prologos_argv_i64 + prologos_cell_write per input
  ;;     cell, before prologos_run_to_quiescence
  ;;   - emits one prologos_print_i64 of the entry-cell value before ret 0
  ;;
  ;; Both meta-decls are absent for closed main; the LLVM emitter
  ;; preserves the historical exit-code-only @main signature in that
  ;; case for backward compatibility with all existing benchmarks
  ;; and golden fixtures.
  (define input-cells (builder-input-cells b))
  (define input-cell-mirrors (reverse (builder-input-cell-mirrors b)))
  (define input-meta
    (cond
      [(null? input-cells) '()]
      [else
       (append
        (list (meta-decl 'input-cells input-cells)
              (meta-decl 'main-prints-result #t))
        ;; lowering-yolo M6: emit the mirror map only when non-empty.
        ;; Each entry says "after writing argv to src, also write the
        ;; same value to dst". See builder-input-cell-mirrors docstring.
        (cond
          [(null? input-cell-mirrors) '()]
          [else (list (meta-decl 'input-cell-mirrors input-cell-mirrors))]))]))

  ;; Validation order requires domains before cells, cells before props,
  ;; props before deps, all before entry.
  (low-pnet
   '(1 1)
   (append (list meta)
           tail-rec-meta
           input-meta
           domain-decls
           cells-emitted
           props-emitted
           deps-emitted
           (list (entry-decl result-cid)))))
