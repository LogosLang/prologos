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
                 [next-pid #:auto #:mutable])
  #:auto-value '()
  #:transparent)

(define (make-builder)
  (define b (builder))
  (set-builder-next-cid! b 0)
  (set-builder-next-pid! b 0)
  b)

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
  id)

(define (emit-propagator! b in-cids out-cid tag)
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
    ;; Lambda binder annotations are expr-Int when a spec is given,
    ;; expr-hole when not (the elaborator leaves bare defn args
    ;; untyped at the lambda level — type info lives on the function's
    ;; Pi type instead). Both shapes are fine for our Int-only
    ;; iteration lowering; we just need k binders.
    [(not (andmap (lambda (t) (or (expr-Int? t) (expr-hole? t))) arg-types)) #f]
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

(define (literal-init-value e)
  ;; Returns the i64 (or #t/#f) value for an init-arg expression that
  ;; we can evaluate at compile time, or #f if non-literal.
  (match e
    [(expr-int n) n]
    [(expr-ann inner _) (literal-init-value inner)]
    [(expr-true)  #t]
    [(expr-false) #f]
    [_ #f]))

(define (lower-tail-rec b dom-id env shape init-args)
  (define k (length init-args))

  ;; init-args MUST be literals (Sprint E.3 v1 limitation). Each state
  ;; cell is allocated with its init-arg's literal value as cell-decl
  ;; init-value. Both state cells AND next-state cells take the same
  ;; init value — feedback propagators reading next-state in round 1
  ;; (against the snapshot) need it to match state, otherwise their
  ;; "no-op" write of the snapshot's stale next-state value would
  ;; incorrectly stomp the initial state.
  (define init-vals
    (for/list ([arg (in-list init-args)])
      (define v (literal-init-value arg))
      (unless v
        (translate-error! arg
                          "tail-rec init-arg must be a literal Int (Sprint E.3 v1 limitation). \
For non-literal initializers, lift the value to a separate def or pre-compute it."))
      ;; literal-init-value returns #t/#f for booleans; tail-rec state
      ;; is currently Int-only, so reject Bool init-args here.
      (unless (exact-integer? v)
        (translate-error! arg
                          "tail-rec init-arg must be Int (Sprint E.3 v1 supports Int state only)."))
      v))

  ;; 1. Allocate state cells with literal init-values.
  (define state-cids
    (for/list ([v (in-list init-vals)])
      (emit-cell! b INT-DOMAIN-ID v)))

  ;; State env: in the elaborated body, the OUTERMOST lambda's binder
  ;; has the largest bvar index. init-args/state-cids are in outermost-
  ;; first order, so env (innermost-first for bvar lookup) is the
  ;; reverse.
  (define state-env (reverse state-cids))

  ;; 2. cond-expr → bool cell. For base-on-true case (the user's cond is
  ;; "is_base_case", e.g., `n<1`), we OVERRIDE the cond cell's init from
  ;; the default #f to #t. Reason: in cold-start round 1, computed step
  ;; cells haven't fired yet (init = 0). Selects must pick "freeze"
  ;; (state) in round 1 to avoid stomping good init values with stale
  ;; step values. With base-on-true polarity (select(cond, state, step)),
  ;; cond=1 → freeze; cond=0 → step. Setting cond's init to 1 fakes
  ;; "halt" for round 1, so selects pick state. The cond propagator
  ;; fires in round 1 and writes the actual cond value (e.g., 0 if not-
  ;; yet-base-case), which takes effect in round 2.
  ;;
  ;; This avoids the should_step intermediate's extra hop, matching the
  ;; structural shape of the working test-bsp-feedback.c iterative-fib
  ;; (which uses `cont = (i < N)` directly — its natural cold-start
  ;; init=0 already means "halt").
  (define base-on-true? (eq? (tail-rec-shape-base-arm-tag shape) 'true))
  (define cond-cid (build (tail-rec-shape-cond-expr shape) b BOOL-DOMAIN-ID state-env))
  (when base-on-true?
    ;; Mutate the cond cell-decl's init-value from #f to #t.
    (set-builder-cells! b
                        (for/list ([c (in-list (builder-cells b))])
                          (if (and (cell-decl? c) (= (cell-decl-id c) cond-cid))
                              (cell-decl (cell-decl-id c)
                                         (cell-decl-domain-id c)
                                         #t)
                              c))))

  ;; 3. step-args → step result cells (parallel, one per state slot).
  ;;
  ;; Lag alignment: all step cells must have the same BSP lag relative
  ;; to state cells, otherwise the select fan-in reads "current" vs
  ;; "previous-round" values for different state slots and the
  ;; iteration produces inconsistent step-results across slots.
  ;;
  ;; Step-args that compute via a propagator (e.g. (a+b), (n-1)) get
  ;; lag = 1 automatically. Step-args that lower to a bare state cell
  ;; (e.g. step-arg = (expr-bvar 1) referring to b) get lag = 0
  ;; without intervention. Patch them via a 1-round identity bridge,
  ;; matching the C-level iterative-fib reference (test-bsp-feedback.c
  ;; uses `identity(b → a_step)` for exactly this reason).
  ;;
  ;; Bridge cell init = same as the source state cell's init, so the
  ;; cold-start round's bridged value matches expected lag-1 behavior.
  (define step-cids
    (for/list ([step-arg (in-list (tail-rec-shape-step-args shape))])
      (define cid (build step-arg b INT-DOMAIN-ID state-env))
      (cond
        [(member cid state-cids)
         (define state-idx (index-of state-cids cid))
         (define init-val (list-ref init-vals state-idx))
         (define bridge-cid (emit-cell! b INT-DOMAIN-ID init-val))
         (emit-propagator! b (list cid) bridge-cid 'kernel-identity)
         bridge-cid]
        [else cid])))

  ;; 4. Build next-state cell + select + feedback per state slot.
  ;;
  ;; Select polarity depends on what cond=1 semantically means:
  ;; - base-on-true?  cond=1 → terminal (freeze): select(cond, state, step).
  ;; - else (cond=1 → continue/step):              select(cond, step, state).
  ;;
  ;; The cold-start problem (selects firing in round 1 with stale step
  ;; cells = 0) is handled by the cond cell init override above
  ;; (base-on-true? ⇒ cond init = #t = "halt", forcing round-1 select
  ;; to pick state).
  ;;
  ;; This polarity matches the C-level test-bsp-feedback.c iterative-fib
  ;; structure but in Prologos's "is_base_case" cond convention.
  (for ([state-cid (in-list state-cids)]
        [step-cid (in-list step-cids)]
        [v (in-list init-vals)])
    (define next-cid (emit-cell! b INT-DOMAIN-ID v))
    (cond
      [base-on-true?
       (emit-propagator! b (list cond-cid state-cid step-cid) next-cid 'kernel-select)]
      [else
       (emit-propagator! b (list cond-cid step-cid state-cid) next-cid 'kernel-select)])
    ;; Feedback edge — write back into state.
    (emit-propagator! b (list next-cid) state-cid 'kernel-identity))

  ;; 6. base-result expression evaluated in state env (re-fires every
  ;;    round; settles when state stops changing). Returns the result
  ;;    cell-id.
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

    ;; Beta-redex == let-binding. (expr-app (expr-lam mult type body) arg)
    ;; Translate arg to a cell; push the cell-id onto env; translate body.
    ;; m0 binders are not evaluated; their env entry is 'erased.
    [(expr-app (expr-lam mult _type body) arg)
     (case mult
       [(m0)
        (build body b dom-id (cons 'erased env))]
       [(m1 mw)
        (define arg-cid (build arg b INT-DOMAIN-ID env))
        (build body b dom-id (cons arg-cid env))]
       [else
        (translate-error! expr (format "unknown multiplicity ~v in let-binding" mult))])]

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
                  (list (expr-reduce-arm tag-a 0 body-a)
                        (expr-reduce-arm tag-b 0 body-b))
                  _structural?)
     (cond
       [(and (eq? tag-a 'true) (eq? tag-b 'false))
        (build-select b scrutinee body-a body-b env dom-id)]
       [(and (eq? tag-a 'false) (eq? tag-b 'true))
        (build-select b scrutinee body-b body-a env dom-id)]
       [else
        (translate-error! expr
                          (format "expr-reduce arm tags must be 'true and 'false; got ~a, ~a"
                                  tag-a tag-b))])]

    ;; expr-app of an expr-fvar to k arguments — dispatch to the
    ;; tail-recursion recognizer. If the fvar's body matches the
    ;; tail-rec shape, lower as a feedback network. Otherwise fall
    ;; through to the unsupported error below.
    [(expr-app f-expr _arg-expr)
     (let ([result (try-lower-tail-rec-call expr b dom-id env)])
       (cond
         [result result]
         [else
          (translate-error!
           expr
           "function call not supported. Only tail-recursive functions matching \
the (expr-lam* (expr-reduce cond [base | (self-call args...)])) shape are \
recognized. For non-recursive helpers, inline the definition manually.")]))]

    ;; Bare expr-fvar (no application) — currently unsupported.
    [(expr-fvar name)
     (translate-error! expr
                       (format "bare reference to top-level definition '~a' not supported. \
Only saturated calls to tail-recursive functions are lowered."
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
  (define a-cid (build a-expr b INT-DOMAIN-ID env))
  (define b-cid (build b-expr b INT-DOMAIN-ID env))
  (define r-cid (emit-cell! b out-dom out-init))
  (emit-propagator! b (list a-cid b-cid) r-cid tag)
  r-cid)

(define (build-select b cond-expr then-expr else-expr env out-dom)
  (define c-cid (build cond-expr b BOOL-DOMAIN-ID env))
  (define t-cid (build then-expr b out-dom env))
  (define e-cid (build else-expr b out-dom env))
  (define init-val (case out-dom [(0) 0] [(1) #f]))
  (define r-cid (emit-cell! b out-dom init-val))
  (emit-propagator! b (list c-cid t-cid e-cid) r-cid 'kernel-select)
  r-cid)

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
  (define result-cid
    (cond
      [(expr-Int? main-type) (build main-body b INT-DOMAIN-ID '())]
      [(expr-Bool? main-type) (build main-body b BOOL-DOMAIN-ID '())]
      [else
       (translate-error! main-type
                         "main must currently have type Int or Bool")]))

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
