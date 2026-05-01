#lang racket/base

;; llvm-lower.rkt — SH Series Track 1, Tier 0–2.
;;
;; Lowers typed AST (expr-* structs from syntax.rkt, post-elaboration and
;; post-zonking) to LLVM IR text.
;;
;; SCAFFOLDING STATEMENT (per docs/tracking/2026-04-30_LLVM_LOWERING_TIER_0_2.md
;; § 5): this is a Racket function, NOT a propagator stratum. Promotion to a
;; lowering stratum is a deferred SH-series track gated on PPN Track 4D +
;; incremental compilation requirement. The function form's API is shaped
;; (lower-program : Listof TopForm -> String) so it can be replaced by the
;; stratum form without touching callers.
;;
;; CLOSED PASS: any AST node not in the supported set raises
;; (unsupported-llvm-node node tier hint). No silent fallthroughs.

(require racket/match
         racket/list
         "syntax.rkt"
         "global-env.rkt")

(provide lower-program
         lower-program/from-global-env
         lower-program/from-global-env-multi
         (struct-out unsupported-llvm-node)
         current-llvm-tier)

;; The tier currently in scope. Lowering rules dispatch on this so a Tier 1
;; node attempted under (current-llvm-tier 0) raises a clear error pointing
;; the caller at the next tier.
(define current-llvm-tier (make-parameter 0))

;; A top-form triple as it lives in the global-env after process-file:
;;   (list 'def name type body)
;; Lowering operates on a list of these, with main as the entry point.
;;
;; unsupported-llvm-node is a real exn:fail so it interoperates with
;; rackunit's check-exn and Racket's standard error formatting.
(struct unsupported-llvm-node exn:fail (node tier hint) #:transparent)

;; Fail loud: raise with the struct kind, the tier we are in, and a hint.
(define (unsupported! node hint)
  (raise
   (unsupported-llvm-node
    (format "unsupported LLVM lowering node at tier ~a: ~a (node: ~v)"
            (current-llvm-tier) hint node)
    (current-continuation-marks)
    node
    (current-llvm-tier)
    hint)))

;; ============================================================
;; Public entry points
;; ============================================================

;; lower-program : (Listof TopForm) -> String
;; Lowers a list of (list 'def name type body) into a single .ll text.
;; Tier 0: the list MUST contain exactly one form, named 'main, whose body
;; lowers to a single i64 literal returned from @main.
(define (lower-program forms)
  (case (current-llvm-tier)
    [(0 1) (lower-program/main-only forms)]
    [(2)   (lower-program/tier2 forms)]
    [else
     (error 'lower-program
            "tier ~a not yet implemented (Tier 0–2 at this commit)"
            (current-llvm-tier))]))

;; Guard: raise unsupported-llvm-node unless current tier is at least min-tier.
(define (require-tier! min-tier node feature-name)
  (when (< (current-llvm-tier) min-tier)
    (unsupported! node
                  (format "~a requires Tier ~a (current Tier ~a)"
                          feature-name min-tier (current-llvm-tier)))))

;; lower-program/from-global-env : -> String
;; Convenience: pulls main's type+body out of (current-prelude-env)
;; and lowers. Caller is expected to have just run process-file.
;; Tier 0–1 only — for Tier 2+ use lower-program/from-global-env-multi.
(define (lower-program/from-global-env)
  (define type (global-env-lookup-type 'main))
  (define body (global-env-lookup-value 'main))
  (unless type
    (error 'lower-program/from-global-env
           "no top-level definition named 'main' in global env"))
  (lower-program (list (list 'def 'main type body))))

;; lower-program/from-global-env-multi : -> String
;; Tier 2 entry: pulls main + transitively-reachable user-defined functions
;; out of the global env (via expr-fvar references in the body) and lowers
;; the whole bundle into one .ll text.
(define (lower-program/from-global-env-multi)
  (define main-type (global-env-lookup-type 'main))
  (define main-body (global-env-lookup-value 'main))
  (unless main-type
    (error 'lower-program/from-global-env-multi
           "no top-level definition named 'main' in global env"))
  (define names (collect-reachable-names 'main main-body))
  (define forms
    (for/list ([n (in-list names)])
      (define t (global-env-lookup-type n))
      (define v (global-env-lookup-value n))
      (unless v
        (error 'lower-program/from-global-env-multi
               "definition ~a has no body in global env (forward decl?)" n))
      (list 'def n t v)))
  (lower-program forms))

;; collect-reachable-names : Symbol × Expr -> Listof Symbol
;; BFS through expr-fvar references. main is first in the result; the rest
;; are in discovery order. Names not present in the global env are skipped
;; (they are either primitives or unresolved references caught later).
(define (collect-reachable-names main-name main-body)
  (define seen (make-hasheq))
  (hash-set! seen main-name #t)
  (define result (list main-name))
  (let loop ([queue (list main-body)])
    (cond
      [(null? queue) (reverse result)]
      [else
       (define refs (collect-fvars (car queue)))
       (define new-bodies
         (for/list ([r (in-list refs)]
                    #:when (and (not (hash-ref seen r #f))
                                (global-env-lookup-value r)))
           (hash-set! seen r #t)
           (set! result (cons r result))
           (global-env-lookup-value r)))
       (loop (append (cdr queue) new-bodies))])))

;; collect-fvars : Expr -> Listof Symbol
;; Walk the expression tree, gathering all expr-fvar names.
(define (collect-fvars e)
  (define out '())
  (define (walk x)
    (cond
      [(expr-fvar? x) (set! out (cons (expr-fvar-name x) out))]
      [(expr-app? x) (walk (expr-app-func x)) (walk (expr-app-arg x))]
      [(expr-lam? x) (walk (expr-lam-type x)) (walk (expr-lam-body x))]
      [(expr-Pi? x) (walk (expr-Pi-domain x)) (walk (expr-Pi-codomain x))]
      [(expr-ann? x) (walk (expr-ann-term x)) (walk (expr-ann-type x))]
      [(expr-int-add? x) (walk (expr-int-add-a x)) (walk (expr-int-add-b x))]
      [(expr-int-sub? x) (walk (expr-int-sub-a x)) (walk (expr-int-sub-b x))]
      [(expr-int-mul? x) (walk (expr-int-mul-a x)) (walk (expr-int-mul-b x))]
      [(expr-int-div? x) (walk (expr-int-div-a x)) (walk (expr-int-div-b x))]
      [(expr-int-mod? x) (walk (expr-int-mod-a x)) (walk (expr-int-mod-b x))]
      [(expr-int-neg? x) (walk (expr-int-neg-a x))]
      [(expr-int-abs? x) (walk (expr-int-abs-a x))]
      [else (void)]))
  (walk e)
  (reverse out))


;; ============================================================
;; bb-builder: a mutable basic-block builder for a single function body
;; ============================================================
;;
;; State:
;;   instrs       : Hash[Symbol → ListOf String]  (reverse-instr-list per block)
;;   cur-block    : Box Symbol | Box #f           (current block; #f after branch)
;;   ssa-counter  : Box Integer                   (for fresh!)
;;   block-counter: Box Integer                   (for fresh-label!)
;;   block-order  : Box ListOf Symbol             (reverse declaration order)
;;   abs-needed?  : Box Boolean                   (declare @llvm.abs.i64 if any abs)

(struct bb-builder (instrs cur-block ssa-counter block-counter block-order abs-needed?))

(define (make-bb-builder)
  (define b (bb-builder (make-hasheq) (box #f) (box 0) (box 0) (box '()) (box #f)))
  (bb-start-block! b "entry")
  b)

(define (bb-emit! bb str)
  (define cur (unbox (bb-builder-cur-block bb)))
  (unless cur
    (error 'bb-emit! "no current block (a branch terminated the previous block)"))
  (hash-update! (bb-builder-instrs bb) cur (lambda (xs) (cons str xs)) '()))

(define (bb-fresh! bb)
  (define b (bb-builder-ssa-counter bb))
  (set-box! b (+ 1 (unbox b)))
  (format "%t~a" (unbox b)))

(define (bb-fresh-label! bb prefix)
  (define b (bb-builder-block-counter bb))
  (set-box! b (+ 1 (unbox b)))
  (format "~a_~a" prefix (unbox b)))

(define (bb-start-block! bb name)
  (define sym (string->symbol name))
  (set-box! (bb-builder-cur-block bb) sym)
  (define instrs (bb-builder-instrs bb))
  (unless (hash-has-key? instrs sym)
    (hash-set! instrs sym '())
    (define ord (bb-builder-block-order bb))
    (set-box! ord (cons sym (unbox ord)))))

(define (bb-cur-block-name bb)
  (define c (unbox (bb-builder-cur-block bb)))
  (and c (symbol->string c)))

(define (bb-branch! bb label)
  (bb-emit! bb (format "  br label %~a" label))
  (set-box! (bb-builder-cur-block bb) #f))

(define (bb-branch-cond! bb cond-i1 lt lf)
  (bb-emit! bb (format "  br i1 ~a, label %~a, label %~a" cond-i1 lt lf))
  (set-box! (bb-builder-cur-block bb) #f))

(define (bb-ret! bb val)
  (bb-emit! bb (format "  ret i64 ~a" val))
  (set-box! (bb-builder-cur-block bb) #f))

(define (bb-render bb)
  (define ordered (reverse (unbox (bb-builder-block-order bb))))
  (apply string-append
         (for/list ([k (in-list ordered)])
           (define lines (reverse (hash-ref (bb-builder-instrs bb) k)))
           (string-append
            (symbol->string k) ":\n"
            (apply string-append
                   (map (lambda (s) (string-append s "\n")) lines))))))

;; ============================================================
;; Tier 0–1 — single `def main : Int` lowered to @main
;; ============================================================

(define (lower-program/main-only forms)
  (match forms
    [(list (list 'def 'main type body))
     (lower-main type body)]
    [_
     (error 'lower-program/main-only
            "Tiers 0–1 expect a single 'main' top-form; got ~v" forms)]))

(define (lower-main type body)
  (unless (or (expr-Int? type) (expr-Bool? type))
    (unsupported! type "main must currently have type Int or Bool"))
  (define bb (make-bb-builder))
  (define final-val
    (parameterize ([current-bvar-env '()])
      (lower-int-expr body bb)))
  (bb-ret! bb final-val)
  (define decls
    (cond
      [(unbox (bb-builder-abs-needed? bb))
       "declare i64 @llvm.abs.i64(i64, i1)\n\n"]
      [else ""]))
  (string-append
   (format "; ModuleID = 'prologos-tier~a'\n" (current-llvm-tier))
   "target triple = \"" (default-target-triple) "\"\n"
   "\n"
   decls
   "define i64 @main() {\n"
   (bb-render bb)
   "}\n"))

;; lower-int-expr : Expr × bb-builder -> String
;; Returns the LLVM value reference (literal or %tN) for the i64 result of e.
;; bb is the builder for the current function; emits side-effect into bb.
(define (lower-int-expr e bb)
  (define (recur x) (lower-int-expr x bb))
  (define (binop op a b)
    (define av (recur a))
    (define bv (recur b))
    (define t (bb-fresh! bb))
    (bb-emit! bb (format "  ~a = ~a i64 ~a, ~a" t op av bv))
    t)
  ;; Comparisons emit `icmp <op> i64 %a, %b` (i1) then `zext i1 to i64`.
  (define (cmpop op a b)
    (define av (recur a))
    (define bv (recur b))
    (define t1 (bb-fresh! bb))
    (define t2 (bb-fresh! bb))
    (bb-emit! bb (format "  ~a = icmp ~a i64 ~a, ~a" t1 op av bv))
    (bb-emit! bb (format "  ~a = zext i1 ~a to i64" t2 t1))
    t2)
  (match e
    ;; -- Tier 0 --
    [(expr-int n)
     (unless (exact-integer? n)
       (unsupported! e "expr-int with non-integer payload"))
     (number->string n)]
    [(expr-ann inner _)
     (recur inner)]

    ;; -- Tier 1: Int arithmetic --
    [(expr-int-add a b)
     (require-tier! 1 e "expr-int-add")
     (binop "add" a b)]
    [(expr-int-sub a b)
     (require-tier! 1 e "expr-int-sub")
     (binop "sub" a b)]
    [(expr-int-mul a b)
     (require-tier! 1 e "expr-int-mul")
     (binop "mul" a b)]
    [(expr-int-div a b)
     ;; LLVM sdiv: signed integer division (truncating toward zero).
     ;; Division by zero is LLVM-undefined; matches Tier 1 unsafety budget.
     (require-tier! 1 e "expr-int-div")
     (binop "sdiv" a b)]
    [(expr-int-mod a b)
     ;; LLVM srem: signed remainder. Sign matches dividend.
     (require-tier! 1 e "expr-int-mod")
     (binop "srem" a b)]
    [(expr-int-neg a)
     (require-tier! 1 e "expr-int-neg")
     (define av (recur a))
     (define t (bb-fresh! bb))
     (bb-emit! bb (format "  ~a = sub i64 0, ~a" t av))
     t]
    [(expr-int-abs a)
     (require-tier! 1 e "expr-int-abs")
     (set-box! (bb-builder-abs-needed? bb) #t)
     (define av (recur a))
     (define t (bb-fresh! bb))
     ;; @llvm.abs.i64 with poison-on-INT_MIN = false: returns INT_MIN as-is.
     (bb-emit! bb (format "  ~a = call i64 @llvm.abs.i64(i64 ~a, i1 false)" t av))
     t]

    ;; -- Tier 2: variable references and calls --
    [(expr-bvar i)
     (require-tier! 2 e "expr-bvar")
     (lookup-bvar i)]
    [(expr-fvar name)
     ;; A bare expr-fvar at value position is a Tier 3+ feature
     ;; (function-as-value requires closure conversion).
     (require-tier! 2 e "expr-fvar")
     (unsupported! e
                   (format "expr-fvar '~a' as a bare value (not in app position) requires closure conversion"
                           name))]
    [(expr-app fn arg)
     (require-tier! 2 e "expr-app")
     ;; Tier 3 special case: (expr-app (expr-lam mult type body) arg) is a let-binding
     ;; emitted by the pattern compiler. Lower arg, push onto bvar-env, lower body.
     (cond
       [(expr-lam? fn)
        (lower-let bb fn arg)]
       [else
        (lower-app/tier2 e bb)])]

    ;; -- Tier 3: Bool + comparisons + conditionals --
    [(expr-Bool)
     (require-tier! 3 e "expr-Bool")
     ;; Bool as a *type* should not appear at a value position; this is reached
     ;; if a body is just the literal `Bool`. Emit the canonical 0 (vacuous).
     "0"]
    [(expr-true)
     (require-tier! 3 e "expr-true")
     "1"]
    [(expr-false)
     (require-tier! 3 e "expr-false")
     "0"]
    [(expr-int-lt a b)
     (require-tier! 3 e "expr-int-lt")
     (cmpop "slt" a b)]
    [(expr-int-le a b)
     (require-tier! 3 e "expr-int-le")
     (cmpop "sle" a b)]
    [(expr-int-eq a b)
     (require-tier! 3 e "expr-int-eq")
     (cmpop "eq" a b)]
    [(expr-boolrec _motive true-case false-case target)
     (require-tier! 3 e "expr-boolrec")
     (lower-conditional bb target true-case false-case)]
    [(expr-reduce scrutinee arms _structural?)
     (require-tier! 3 e "expr-reduce")
     (lower-reduce-bool bb scrutinee arms)]

    [_
     (unsupported! e
                   (format "no Tier ~a lowering for this node"
                           (current-llvm-tier)))]))

;; lower-let : bb-builder × expr-lam × Expr -> String
;; Lowers (expr-app (expr-lam mult type body) arg) as a let-binding:
;;   m0 binder: don't evaluate arg, push 'erased
;;   mw/m1   : evaluate arg, push its SSA value
(define (lower-let bb lam arg)
  (match lam
    [(expr-lam mult _type body)
     (case mult
       [(m0)
        (parameterize ([current-bvar-env (cons 'erased (current-bvar-env))])
          (lower-int-expr body bb))]
       [(m1 mw)
        (define av (lower-int-expr arg bb))
        (parameterize ([current-bvar-env (cons av (current-bvar-env))])
          (lower-int-expr body bb))]
       [else
        (unsupported! lam (format "unknown multiplicity ~v in let-binding" mult))])]))

;; lower-conditional : bb-builder × Expr × Expr × Expr -> String
;; Emits an if-then-else with phi merging at the join block. Returns the phi's
;; SSA name. Used by both expr-boolrec and expr-reduce-on-Bool.
(define (lower-conditional bb target true-case false-case)
  (define tv (lower-int-expr target bb))
  (define cb (bb-fresh! bb))
  (bb-emit! bb (format "  ~a = icmp ne i64 ~a, 0" cb tv))
  (define tlab (bb-fresh-label! bb "true"))
  (define flab (bb-fresh-label! bb "false"))
  (define jlab (bb-fresh-label! bb "join"))
  (bb-branch-cond! bb cb tlab flab)
  ;; True arm
  (bb-start-block! bb tlab)
  (define tv-result (lower-int-expr true-case bb))
  (define t-end-block (bb-cur-block-name bb))
  (bb-branch! bb jlab)
  ;; False arm
  (bb-start-block! bb flab)
  (define fv-result (lower-int-expr false-case bb))
  (define f-end-block (bb-cur-block-name bb))
  (bb-branch! bb jlab)
  ;; Join
  (bb-start-block! bb jlab)
  (define r (bb-fresh! bb))
  (bb-emit! bb (format "  ~a = phi i64 [~a, %~a], [~a, %~a]"
                       r tv-result t-end-block fv-result f-end-block))
  r)

;; lower-reduce-bool : bb-builder × Expr × Listof expr-reduce-arm -> String
;; Tier 3 supports expr-reduce ONLY for Bool: arms must be one each of
;; 'true / 'false with binding-count 0. Anything else → Tier 4.
(define (lower-reduce-bool bb scrutinee arms)
  (define (find-arm tag)
    (or (findf (lambda (a) (eq? (expr-reduce-arm-ctor-name a) tag)) arms)
        (unsupported! arms
                      (format "expr-reduce missing the '~a arm (Tier 3 requires both true and false on Bool)" tag))))
  (define t-arm (find-arm 'true))
  (define f-arm (find-arm 'false))
  (for ([a (in-list arms)])
    (unless (= 0 (expr-reduce-arm-binding-count a))
      (unsupported! a
                    (format "expr-reduce-arm '~a has binding-count ~a; Tier 3 supports only 0-binding (Bool) constructors"
                            (expr-reduce-arm-ctor-name a) (expr-reduce-arm-binding-count a)))))
  (lower-conditional bb scrutinee
                     (expr-reduce-arm-body t-arm)
                     (expr-reduce-arm-body f-arm)))

;; lookup-bvar : Integer -> String
;; Resolved against the current-bvar-env parameter set by lower-function.
;; Each entry is either a string (the SSA name like "%p2") or 'erased.
(define current-bvar-env (make-parameter '()))

(define (lookup-bvar i)
  (define env (current-bvar-env))
  (when (or (< i 0) (>= i (length env)))
    (raise
     (unsupported-llvm-node
      (format "expr-bvar ~a escapes the enclosing function (only top-level functions, no closures)"
              i)
      (current-continuation-marks)
      (expr-bvar i)
      (current-llvm-tier)
      "Tier 2 rejects free variables / closure captures")))
  (define entry (list-ref env i))
  (when (eq? entry 'erased)
    (raise
     (unsupported-llvm-node
      (format "expr-bvar ~a refers to an erased (m0) binder; cannot use at runtime" i)
      (current-continuation-marks)
      (expr-bvar i)
      (current-llvm-tier)
      "m0 binders are dropped from the function signature")))
  entry)

;; ============================================================
;; Tier 2 — multi-form programs with top-level functions
;; ============================================================

;; Per-program function-name → type map. Populated at the start of
;; lower-program/tier2 and consulted by lower-app/tier2 so unit tests
;; do not need to populate the global env.
(define current-fn-types (make-parameter (hasheq)))

(define (lower-program/tier2 forms)
  ;; Validate main exists and has type Int.
  (define main-form
    (or (findf (lambda (f) (eq? (cadr f) 'main)) forms)
        (error 'lower-program/tier2 "no top-form named 'main")))
  (define main-type (caddr main-form))
  (unless (expr-Int? main-type)
    (unsupported! main-type "main must currently have type Int"))
  ;; Build the name-to-type map from the form list itself.
  (define fn-types
    (for/fold ([h (hasheq)]) ([f (in-list forms)])
      (hash-set h (cadr f) (caddr f))))
  ;; Build LLVM module: each function gets its own bb-builder. We also
  ;; thread a top-level abs-needed? through to collect declarations.
  (define abs-needed? (box #f))
  (define non-main (filter (lambda (f) (not (eq? (cadr f) 'main))) forms))
  (define fn-irs
    (parameterize ([current-fn-types fn-types])
      (for/list ([f (in-list non-main)])
        (lower-function/tier2 f abs-needed?))))
  (define main-ir
    (parameterize ([current-fn-types fn-types])
      (lower-main-tier2 main-form abs-needed?)))
  (define decls
    (cond
      [(unbox abs-needed?)
       "declare i64 @llvm.abs.i64(i64, i1)\n\n"]
      [else ""]))
  (string-append
   "; ModuleID = 'prologos-tier2'\n"
   "target triple = \"" (default-target-triple) "\"\n"
   "\n"
   decls
   (apply string-append (map (lambda (s) (string-append s "\n")) fn-irs))
   main-ir))

(define (lower-main-tier2 form mod-abs-needed?)
  (match form
    [(list 'def 'main type body)
     (define bb (make-bb-builder))
     (define final-val
       (parameterize ([current-bvar-env '()])
         (lower-int-expr body bb)))
     (bb-ret! bb final-val)
     (when (unbox (bb-builder-abs-needed? bb))
       (set-box! mod-abs-needed? #t))
     (string-append
      "define i64 @main() {\n"
      (bb-render bb)
      "}\n")]))

;; lower-function/tier2 : TopForm × Box[Bool] -> String
;; Walks the curried lambda chain, drops m0 binders, lowers the body.
(define (lower-function/tier2 form mod-abs-needed?)
  (match form
    [(list 'def name type body)
     (define-values (params inner-body) (collect-lambdas body))
     ;; Validate type is a Pi-chain matching the lambdas.
     (define-values (pi-params return-type) (collect-pi-binders type))
     (unless (= (length params) (length pi-params))
       (unsupported! body
                     (format "def ~a: lambda chain length ~a does not match Pi chain length ~a"
                             name (length params) (length pi-params))))
     ;; Return type: must be Int/Bool *or* a bvar referring to an m0 (erased) binder.
     ;; The latter is the common case for polymorphic identity-like functions
     ;; (forall A, A -> A) after m0 erasure: the runtime type is i64.
     (unless (or (expr-Int? return-type)
                 (expr-Bool? return-type)
                 (and (expr-bvar? return-type)
                      (let ([idx (expr-bvar-index return-type)])
                        (and (< idx (length pi-params))
                             (eq? (car (list-ref pi-params (- (length pi-params) 1 idx)))
                                  'm0)))))
       (unsupported! return-type
                     (format "def ~a: only Int- or Bool-returning functions are supported (return type: ~v)"
                             name return-type)))
     ;; Build SSA params (skipping m0 binders) and the de Bruijn env.
     ;; params is outer-to-inner; env must be innermost-first to match
     ;; expr-bvar 0 = innermost.
     (define-values (sig-params env-rev)
       (for/fold ([sigs '()] [env '()])
                 ([p (in-list params)]
                  [i (in-naturals)])
         (define mult (car p))
         (case mult
           [(m0)
            (values sigs (cons 'erased env))]
           [(m1 mw)
            (define ssa (format "%p~a" i))
            (values (cons (format "i64 ~a" ssa) sigs)
                    (cons ssa env))]
           [else
            (unsupported! body
                          (format "def ~a: unknown multiplicity ~v"
                                  name mult))])))
     (define sig-str (string-join* (reverse sig-params) ", "))
     (define bb (make-bb-builder))
     (define final-val
       (parameterize ([current-bvar-env env-rev])
         (lower-int-expr inner-body bb)))
     (bb-ret! bb final-val)
     (when (unbox (bb-builder-abs-needed? bb))
       (set-box! mod-abs-needed? #t))
     (string-append
      (format "define i64 @~a(~a) {\n" (mangle-name name) sig-str)
      (bb-render bb)
      "}\n")]))

;; lower-app/tier2 : Expr × bb-builder -> String  (the SSA value reference)
;; Walks the curried application chain, skips m0 args, emits a single call.
(define (lower-app/tier2 e bb)
  (define-values (head args) (uncurry-app e))
  (unless (expr-fvar? head)
    (unsupported! head
                  "Tier 2 only supports calls where the head is a named top-level function (expr-fvar) or a let-binding (expr-lam). Got something else."))
  (define name (expr-fvar-name head))
  (define ftype
    (or (hash-ref (current-fn-types) name #f)
        (global-env-lookup-type name)))
  (unless ftype
    (unsupported! head
                  (format "no top-level definition named '~a' in scope" name)))
  (define-values (pi-params _ret) (collect-pi-binders ftype))
  (unless (= (length args) (length pi-params))
    (unsupported! e
                  (format "call to ~a: ~a args given, ~a expected"
                          name (length args) (length pi-params))))
  ;; Lower each non-m0 arg; m0 args are dropped.
  (define arg-strs
    (for/list ([a (in-list args)]
               [p (in-list pi-params)]
               #:when (not (eq? (car p) 'm0)))
      (define av (lower-int-expr a bb))
      (format "i64 ~a" av)))
  (define t (bb-fresh! bb))
  (bb-emit! bb (format "  ~a = call i64 @~a(~a)"
                       t (mangle-name name) (string-join* arg-strs ", ")))
  t)

;; collect-lambdas : Expr -> (values Listof(cons Mult Type) Expr)
;; Walks a chain of expr-lam, returning binders (outer-first) and the inner body.
(define (collect-lambdas e)
  (let loop ([e e] [acc '()])
    (match e
      [(expr-lam mult type body)
       (loop body (cons (cons mult type) acc))]
      [_
       (values (reverse acc) e)])))

;; collect-pi-binders : Expr -> (values Listof(cons Mult Type) Expr)
;; Walks a chain of expr-Pi, returning binders (outer-first) and return type.
(define (collect-pi-binders t)
  (let loop ([t t] [acc '()])
    (match t
      [(expr-Pi mult dom cod)
       (loop cod (cons (cons mult dom) acc))]
      [_
       (values (reverse acc) t)])))

;; uncurry-app : Expr -> (values head Listof(args))
;; Flatten nested (expr-app (expr-app ... f a1) a2) ... into (f, [a1, a2, ...]).
(define (uncurry-app e)
  (let loop ([e e] [acc '()])
    (match e
      [(expr-app f a) (loop f (cons a acc))]
      [_ (values e acc)])))

;; mangle-name : Symbol -> String
;; Translate Prologos identifiers into LLVM-safe names. We allow [a-zA-Z0-9_]
;; through and replace anything else with '_'. main is kept as-is.
(define (mangle-name name)
  (define s (symbol->string name))
  (cond
    [(equal? s "main") "main"]
    [else
     (define cs
       (for/list ([c (in-string s)])
         (cond
           [(or (char-alphabetic? c) (char-numeric? c) (eq? c #\_)) c]
           [else #\_])))
     (string-append "p_" (list->string cs))]))

;; string-join* : Listof String × String -> String
;; Like string-join from racket/string but kept local to avoid the require.
(define (string-join* ss sep)
  (cond
    [(null? ss) ""]
    [(null? (cdr ss)) (car ss)]
    [else
     (apply string-append
            (cons (car ss)
                  (for/list ([s (in-list (cdr ss))])
                    (string-append sep s))))]))

;; ============================================================
;; Helpers
;; ============================================================

;; Default target triple. Linux x86_64 covers our CI runner. Override via
;; PROLOGOS_LLVM_TRIPLE env var when cross-compiling.
(define (default-target-triple)
  (or (getenv "PROLOGOS_LLVM_TRIPLE")
      "x86_64-unknown-linux-gnu"))
