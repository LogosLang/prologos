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
         "global-env.rkt")

(provide ast-to-low-pnet
         (struct-out ast-translation-error))

(struct ast-translation-error exn:fail (node hint) #:transparent)

(define (translate-error! node hint)
  (raise (ast-translation-error
          (format "ast-to-low-pnet cannot translate ~v: ~a" node hint)
          (current-continuation-marks)
          node
          hint)))

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
                 ;; Sprint G note: bridge-cache is unused by the current
                 ;; lower-tail-rec design (which emits iter-block-decls
                 ;; instead of feedback bridges). Kept for any future
                 ;; lowering pass that needs depth alignment within S0.
                 [bridge-cache #:auto #:mutable]
                 ;; Sprint G: pending iter-block declarations. lower-tail-rec
                 ;; appends an iter-block-decl here; ast-to-low-pnet emits
                 ;; them in the final low-pnet structure.
                 [iter-blocks #:auto #:mutable])
  #:auto-value '()
  #:transparent)

(define (make-builder)
  (define b (builder))
  (set-builder-next-cid! b 0)
  (set-builder-next-pid! b 0)
  (set-builder-depths! b (hasheq))
  (set-builder-bridge-cache! b (hasheq))
  (set-builder-iter-blocks! b '())
  b)

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
(define (assert-depth-balance-invariant! b)
  (for ([p (in-list (builder-props b))]
        #:when (propagator-decl? p))
    (define ins (propagator-decl-input-cells p))
    (when (>= (length ins) 2)
      (define depths (map (lambda (c) (cell-depth b c)) ins))
      (unless (apply = depths)
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

(define (assert-scalar! vt expr context)
  (unless (vtree-scalar? vt)
    (translate-error!
     expr
     (format "~a expected a scalar (Int or Bool) but got a pair-typed value. \
fst/snd projection or destructuring is required first."
             context)))
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

;; Sprint F.3: vtree-walking helpers for pair-typed tail-rec state.

;; vtree-leaves : vtree → (Listof scalar-leaf)
;; Flatten the vtree's leaves in left-to-right order. Used to build a
;; set of state cell-ids for the bridge check.
(define (vtree-leaves vt)
  (cond [(or (exact-integer? vt) (boolean? vt)) (list vt)]
        [(list? vt) (apply append (map vtree-leaves vt))]
        [else '()]))

;; vtree-shapes-match? : vtree × vtree → Bool
;; True iff the two vtrees have identical structure (same nesting).
(define (vtree-shapes-match? a b)
  (cond [(and (vtree-scalar? a) (vtree-scalar? b)) #t]
        [(and (list? a) (list? b) (= (length a) (length b)))
         (andmap vtree-shapes-match? a b)]
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
  (define k (length init-args))

  ;; 1. Each init-arg → init-vt. Sprint F.3: pair-typed init-args (e.g.
  ;; `[pair 0 1]`) supported as nested literal vtrees. Each leaf must
  ;; be an Int.
  (define init-vts
    (for/list ([arg (in-list init-args)])
      (define v (literal-init-value arg))
      (unless v
        (translate-error! arg
                          "tail-rec init-arg must be a literal Int (or pair of literal Ints). \
For non-literal initializers, lift the value to a separate def or pre-compute it."))
      ;; Bool init-leaves not yet supported in tail-rec state.
      (let walk ([leaf v])
        (cond [(exact-integer? leaf) (void)]
              [(list? leaf) (for-each walk leaf)]
              [else
               (translate-error! arg
                                 "tail-rec init-leaves must be Int (Bool/scalar Bool state slots not yet supported).")]))
      v))

  ;; 2. Allocate state cells matching each init-vt's shape (recursive).
  (define (alloc-state-vt init-vt)
    (cond [(exact-integer? init-vt)
           (emit-cell! b INT-DOMAIN-ID init-vt)]
          [else
           (map alloc-state-vt init-vt)]))
  (define state-vts (map alloc-state-vt init-vts))

  ;; State env: outermost lambda's binder has highest bvar index. The
  ;; init-args/state-vts are in outermost-first order; env is innermost-
  ;; first, so reverse.
  (define state-env (reverse state-vts))

  ;; 3. cond-expr → bool cell. With base-on-true? we mutate cond's
  ;; cell-decl init from #f to #t to force round-1 freeze.
  (define base-on-true? (eq? (tail-rec-shape-base-arm-tag shape) 'true))
  (define cond-vt (build (tail-rec-shape-cond-expr shape) b BOOL-DOMAIN-ID state-env))
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
      (define raw-vt (build step-arg b INT-DOMAIN-ID state-env))
      (unless (vtree-shapes-match? state-vt raw-vt)
        (translate-error! step-arg
                          (format "tail-rec step-arg shape ~v doesn't match state shape ~v"
                                  raw-vt state-vt)))
      raw-vt))

  ;; F.5: lag-matching has TWO layers:
  ;;
  ;; (a) Per-propagator alignment via emit-aligned-propagator! —
  ;;     fixes mismatched depths of inputs to each arithmetic /
  ;;     comparison propagator (e.g., Pell's `int-add(int-mul(2,b), a)`
  ;;     inputs are aligned before int-add fires).
  ;;
  ;; (b) Pre-select uniform lift — each per-state-slot select reads
  ;;     (cond, state, step). If step depths vary across slots, the
  ;;     selects produce next-state cells at different depths, which
  ;;     means state cells update at different rounds (creating an
  ;;     inconsistent snapshot mid-iteration). Lifting cond AND each
  ;;     step-leaf to a common max-depth before the selects ensures
  ;;     all selects fire at the same depth, all next-state cells
  ;;     are at the same depth, all feedbacks fire uniformly, and
  ;;     state updates atomically per iteration.
  (define max-step-depth
    (apply max (cell-depth b cond-cid)
           (map (lambda (vt) (max-vtree-depth b vt)) raw-step-vts)))

  (define cond-cid-lifted (lift-cell-to-depth b cond-cid max-step-depth))

  (define step-vts
    (for/list ([raw-vt (in-list raw-step-vts)])
      (lift-vtree-to-depth b raw-vt max-step-depth)))

  ;; 5. Per-leaf: alloc next-cell + select + feedback. Walk the vtrees
  ;; in lockstep across (state, step, init). Uses the lifted cond cell
  ;; (F.5) so all selects fire on a cond at the same depth as their
  ;; step inputs.
  (define (emit-feedback state-vt step-vt init-vt)
    (cond
      [(exact-integer? state-vt)
       (define next-cid (emit-cell! b INT-DOMAIN-ID init-vt))
       ;; F.5: aligned-emit so cond + state + step are read at the
       ;; same depth in the select. cond may be at depth 1 (from
       ;; int-lt) while step may be at depth 2+ (nested arithmetic);
       ;; the alignment inserts bridges as needed.
       (cond
         [base-on-true?
          (emit-aligned-propagator! b (list cond-cid-lifted state-vt step-vt) next-cid 'kernel-select)]
         [else
          (emit-aligned-propagator! b (list cond-cid-lifted step-vt state-vt) next-cid 'kernel-select)])
       ;; Feedback identity is intentionally NOT aligned — it's a
       ;; lag-1 bridge by design (the canonical "next-state → state"
       ;; edge of the iteration loop). Also skip depth update: state
       ;; cells stay at logical depth 0 for future references.
       (emit-propagator! b (list next-cid) state-vt 'kernel-identity
                         #:skip-depth-update? #t)]
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

    ;; Binary arithmetic: recursively translate each operand to a cell,
    ;; then allocate a result cell + install the corresponding propagator.
    [(expr-int-add a b-expr) (build-binary b a b-expr 'kernel-int-add env)]
    [(expr-int-sub a b-expr) (build-binary b a b-expr 'kernel-int-sub env)]
    [(expr-int-mul a b-expr) (build-binary b a b-expr 'kernel-int-mul env)]
    [(expr-int-div a b-expr) (build-binary b a b-expr 'kernel-int-div env)]

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
        (translate-error!
         expr
         (format "expr-reduce two-arm match supports {true,false} (Bool) or \
{zero,suc} (Nat); got ~a (count ~a), ~a (count ~a). Other sum types are not \
yet lowered."
                 tag-a count-a tag-b count-b))])]

    ;; Multi-arm match with N != 2 not yet lowered.
    [(expr-reduce _ arms _)
     (translate-error!
      expr
      (format "expr-reduce with ~a arms not supported yet (only 2-arm Bool/Nat \
match is lowered). Other sum types (Maybe, Either, List, user-defined) require \
tagged-union runtime representation, not yet built."
              (length arms)))]

    ;; expr-app of an expr-fvar to k arguments — three-way dispatch:
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
(inlined at lowering time) ARE supported.")]))]))]

    ;; Bare expr-fvar (no application) — currently unsupported.
    [(expr-fvar name)
     (translate-error! expr
                       (format "bare reference to top-level definition '~a' not supported. \
Only saturated calls to tail-recursive functions and non-recursive \
helpers are lowered."
                               name))]

    [_
     (translate-error!
      expr
      "Phase 2.D supports Int/Bool literals, int+/-/*//, int-eq/lt/le, \
boolrec, expr-bvar, let-binding, and saturated tail-recursive function calls. \
Other forms (non-tail recursion, named-function references, complex match) \
are not yet supported.")]))

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

(define (ast-to-low-pnet main-type main-body source-file)
  (define b (make-builder))
  ;; Pick an outermost domain based on main's type (for the meta only;
  ;; the result cell's domain is set during build). main has no enclosing
  ;; lambdas, so the initial env is empty.
  (define result-vt
    (cond
      [(expr-Int? main-type)  (build main-body b INT-DOMAIN-ID '())]
      [(expr-Nat? main-type)  (build main-body b INT-DOMAIN-ID '())]
      [(expr-Bool? main-type) (build main-body b BOOL-DOMAIN-ID '())]
      [else
       (translate-error! main-type
                         "main must currently have type Int, Nat, or Bool")]))
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

  ;; Validation order requires domains before cells, cells before props,
  ;; props before deps, all before entry.
  (low-pnet
   '(1 0)
   (append (list meta)
           domain-decls
           cells-emitted
           props-emitted
           deps-emitted
           (list (entry-decl result-cid)))))
