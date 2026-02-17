#lang racket/base

;;;
;;; PROLOGOS ELABORATOR
;;; Transforms surface AST (named variables) to core AST (de Bruijn indices).
;;; Performs name resolution, scope checking, and desugaring.
;;;

(require racket/match
         racket/list
         racket/string
         "prelude.rkt"
         "syntax.rkt"
         "source-location.rkt"
         "surface-syntax.rkt"
         "errors.rkt"
         "global-env.rkt"
         "namespace.rkt"
         "metavar-store.rkt"
         "pretty-print.rkt"
         "multi-dispatch.rkt"
         "foreign.rkt"
         "posit-impl.rkt"
         "champ.rkt")

(provide elaborate
         elaborate-top-level)

;; ========================================
;; Elaboration environment
;; ========================================
;; An environment is a list of (cons name depth) pairs, most recent first.
;; When we look up a name at current depth D, we find its binding depth BD,
;; and the de Bruijn index is D - BD - 1.

;; Lookup a name in the environment, returning de Bruijn index or #f
(define (env-lookup env name depth)
  (cond
    [(null? env) #f]
    [(eq? (caar env) name)
     (- depth (cdar env) 1)]
    [else (env-lookup (cdr env) name depth)]))

;; Extend environment with a new binding
(define (env-extend env name depth)
  (cons (cons name depth) env))

;; Sprint 9: Convert elaborator env to a de Bruijn name stack for error messages.
;; The env stores (name . depth), most recent first — same order as pp-expr's names.
(define (env->name-stack env)
  (map (lambda (pair) (symbol->string (car pair))) env))

;; ========================================
;; Implicit argument helpers
;; ========================================

;; Walk a core Pi chain and collect the multiplicity of each binder.
;; Returns a list of multiplicities ('m0 or 'mw).
(define (collect-pi-mults type)
  (match type
    [(expr-Pi m _ cod) (cons m (collect-pi-mults cod))]
    [_ '()]))

;; Count leading m0 (implicit/erased) parameters.
(define (leading-m0-count mults)
  (length (takef mults (lambda (m) (eq? m 'm0)))))

;; Auto-apply holes for a bare variable whose type has ALL m0 parameters.
;; e.g., nil : Pi(A :0 Type 0, List A) → (app (fvar nil) hole)
;; Only applies when ALL Pi binders are m0 (fully implicit).
;; For mixed types (like cons : Pi(A :0 Type 0, A -> List A -> List A)),
;; we don't auto-apply — the user must use application syntax.
(define (maybe-auto-apply-implicits fvar-expr resolved-name loc env)
  (define ftype (global-env-lookup-type resolved-name))
  (if ftype
      (let ([mults (collect-pi-mults ftype)])
        (if (and (not (null? mults))
                 (andmap (lambda (m) (eq? m 'm0)) mults))
            ;; All params are implicit → auto-apply with fresh metavariables
            (for/fold ([acc fvar-expr])
                      ([_ (in-range (length mults))])
              (expr-app acc (fresh-meta ctx-empty (expr-hole)
                              (meta-source-info loc 'implicit
                                (format "implicit type argument for ~a" resolved-name)
                                #f (env->name-stack env)))))
            fvar-expr))
      fvar-expr))

;; Given a function's global type and the number of user-supplied args,
;; return the number of implicit holes to prepend (or 0 if no insertion needed).
;; Rules:
;;   - total-arity = length of Pi chain
;;   - n-implicit = count of leading m0 binders
;;   - n-explicit = total-arity - n-implicit
;;   - If user provides n-explicit args → prepend n-implicit holes
;;   - If user provides total-arity args → no insertion (backward compat)
;;   - Otherwise → no insertion (let type checker report arity error)
(define (implicit-holes-needed func-type n-user-args)
  (define mults (collect-pi-mults func-type))
  (define total (length mults))
  (define n-imp (leading-m0-count mults))
  (define n-exp (- total n-imp))
  (cond
    [(= n-user-args total) 0]         ; user gave all args → backward compat, no insertion
    [(and (> n-imp 0)                 ; has implicit params
          (= n-user-args n-exp))      ; user gave explicit-only count
     n-imp]                           ; → insert implicits
    [else 0]))                        ; mismatch → don't insert, let checker error

;; ========================================
;; Arity checking helpers
;; ========================================

;; Count explicit (non-m0) parameters in a Pi chain.
(define (count-explicit-params type)
  (match type
    [(expr-Pi m _ cod)
     (if (eq? m 'm0)
         (count-explicit-params cod)
         (add1 (count-explicit-params cod)))]
    [_ 0]))

;; Count total parameters (implicit + explicit) in a Pi chain.
(define (total-params type)
  (match type
    [(expr-Pi _ _ cod) (add1 (total-params cod))]
    [_ 0]))

;; ========================================
;; Main elaboration: surface -> core
;; ========================================

;; Resolve a surf-var to a core expression.
;; When auto-apply? is #t and the global has ALL m0 params, auto-apply with holes.
;; When auto-apply? is #f (function position), just return the fvar.
(define (elaborate-var name loc env depth auto-apply?)
  (let ([idx (env-lookup env name depth)])
    (cond
      [idx (expr-bvar idx)]
      ;; When namespace context is active, try FQN resolution FIRST.
      [(and (current-ns-context)
            (let ([resolved (resolve-name name (current-ns-context))])
              (and resolved
                   (not (eq? resolved name))
                   (global-env-lookup-type resolved)
                   resolved)))
       => (lambda (resolved)
            (if auto-apply?
                (maybe-auto-apply-implicits (expr-fvar resolved) resolved loc env)
                (expr-fvar resolved)))]
      ;; Fall back to bare name
      [(global-env-lookup-type name)
       (if auto-apply?
           (maybe-auto-apply-implicits (expr-fvar name) name loc env)
           (expr-fvar name))]
      ;; Multi-body function: base name exists in dispatch registry but not in global env.
      ;; Must be applied (bare reference is ambiguous — which arity?).
      [(lookup-multi-defn name)
       => (lambda (info)
            (prologos-error loc
              (format "Multi-body function '~a' must be applied; available arities: ~a"
                      name (string-join (map number->string (multi-defn-info-arities info)) ", "))))]
      [else (unbound-variable-error loc "Unbound variable" name)])))

;; elaborate: surface-expr, env, depth -> (or/c expr? prologos-error?)
(define (elaborate surf [env '()] [depth 0])
  (match surf
    ;; Variable: look up name, compute de Bruijn index
    ;; For globals with ALL-implicit type params (e.g., nil : Pi(A :0 Type). List A),
    ;; auto-apply with holes so bare `nil` becomes `(nil _)`.
    ;; This auto-apply is suppressed when the var is in function position of surf-app.
    [(surf-var name loc)
     (elaborate-var name loc env depth #t)]

    ;; Nat literal: desugar to suc chain
    [(surf-nat-lit n loc)
     (nat->expr n)]

    ;; Constants
    [(surf-zero _) (expr-zero)]
    [(surf-suc pred loc)
     (let ([e (elaborate pred env depth)])
       (if (prologos-error? e) e (expr-suc e)))]
    [(surf-true _) (expr-true)]
    [(surf-false _) (expr-false)]
    [(surf-unit _) (expr-unit)]
    [(surf-refl _) (expr-refl)]
    [(surf-nat-type _) (expr-Nat)]
    [(surf-bool-type _) (expr-Bool)]
    [(surf-unit-type _) (expr-Unit)]

    ;; Type hole (inferred during checking)
    [(surf-hole loc)
     (expr-hole)]

    ;; Type universe — Sprint 6: #f means infer level
    [(surf-type n loc)
     (if n
         (expr-Type (nat->level n))
         (expr-Type (fresh-level-meta (meta-source-info loc 'bare-Type "universe level" #f #f))))]

    ;; Arrow (non-dependent): (-> A B) -> Pi(mw, elab-A, elab-B-shifted)
    ;; Pi introduces a binder, so codomain is under a binder even for arrows.
    ;; We elaborate B at depth+1 (under a dummy binding) so that references
    ;; to outer variables get the correct de Bruijn indices.
    [(surf-arrow raw-mult dom cod loc)
     (let* ([m (or raw-mult 'mw)]  ;; #f defaults to unrestricted
            [a (elaborate dom env depth)]
            [b (elaborate cod env (+ depth 1))])
       (cond
         [(prologos-error? a) a]
         [(prologos-error? b) b]
         [else (expr-Pi m a b)]))]

    ;; Pi type: (Pi (x :m A) B) -> Pi(m, elab-A, elab-B) with x bound in B
    ;; Sprint 7: #f mult → fresh-mult-meta
    [(surf-pi binder body loc)
     (let* ([name (binder-info-name binder)]
            [raw-mult (binder-info-mult binder)]
            [mult (if raw-mult raw-mult
                     (fresh-mult-meta (meta-source-info loc 'pi-param "multiplicity of Pi parameter" #f #f)))]
            [ty-surf (binder-info-type binder)]
            [ty (elaborate ty-surf env depth)])
       (if (prologos-error? ty) ty
           (let* ([new-env (env-extend env name depth)]
                  [new-depth (+ depth 1)]
                  [bod (elaborate body new-env new-depth)])
             (if (prologos-error? bod) bod
                 (expr-Pi mult ty bod)))))]

    ;; Lambda: (lam (x :m A) body) -> lam(m, elab-A, elab-body) with x bound
    ;; Sprint 7: #f mult → fresh-mult-meta
    [(surf-lam binder body loc)
     (let* ([name (binder-info-name binder)]
            [raw-mult (binder-info-mult binder)]
            [mult (if raw-mult raw-mult
                     (fresh-mult-meta (meta-source-info loc 'lambda-param "multiplicity of lambda parameter" #f #f)))]
            [ty-surf (binder-info-type binder)]
            [ty (elaborate ty-surf env depth)])
       (if (prologos-error? ty) ty
           (let* ([new-env (env-extend env name depth)]
                  [new-depth (+ depth 1)]
                  [bod (elaborate body new-env new-depth)])
             (if (prologos-error? bod) bod
                 (expr-lam mult ty bod)))))]

    ;; Sigma: (Sigma (x : A) B) -> Sigma(elab-A, elab-B) with x bound in B
    [(surf-sigma binder body loc)
     (let* ([name (binder-info-name binder)]
            [ty-surf (binder-info-type binder)]
            [ty (elaborate ty-surf env depth)])
       (if (prologos-error? ty) ty
           (let* ([new-env (env-extend env name depth)]
                  [new-depth (+ depth 1)]
                  [bod (elaborate body new-env new-depth)])
             (if (prologos-error? bod) bod
                 (expr-Sigma ty bod)))))]

    ;; Application: (f a b c) -> app(app(app(elab-f, elab-a), elab-b), elab-c)
    ;; When the function resolves to an expr-fvar, check its type for leading
    ;; implicit (m0) parameters and auto-insert holes if the user provided
    ;; only the explicit arguments.
    ;; The function is elaborated WITHOUT auto-apply (auto-apply? = #f) to avoid
    ;; double-application — the implicit insertion here handles ALL cases.
    [(surf-app func args loc)
     ;; Multi-defn dispatch: resolve base name to internal clause by arity
     (cond
       [(and (surf-var? func)
             (lookup-multi-defn (surf-var-name func)))
        => (lambda (multi-info)
             (define n-user-args (length args))
             (define resolved-name (resolve-multi-defn (surf-var-name func) n-user-args))
             (cond
               [resolved-name
                ;; Elaborate as if the user wrote the internal name
                (elaborate (surf-app (surf-var resolved-name (surf-var-srcloc func))
                                     args loc)
                           env depth)]
               [else
                (multi-arity-error loc
                  (format "No matching clause for '~a' with ~a argument~a"
                          (surf-var-name func) n-user-args
                          (if (= n-user-args 1) "" "s"))
                  (surf-var-name func) n-user-args
                  (multi-defn-info-arities multi-info))]))]
       [else
        ;; Normal application path
        (let ([ef (if (surf-var? func)
                      (elaborate-var (surf-var-name func) (surf-var-srcloc func)
                                     env depth #f)
                      (elaborate func env depth))])
          (if (prologos-error? ef) ef
              ;; Check for implicit parameters, arity, and insert fresh metavariables
              (if (expr-fvar? ef)
                  (let ([ftype (global-env-lookup-type (expr-fvar-name ef))])
                    (if ftype
                        (let* ([fname (expr-fvar-name ef)]
                               [n-user-args (length args)]
                               [mults (collect-pi-mults ftype)]
                               [n-total (length mults)]
                               [n-imp (leading-m0-count mults)]
                               [n-exp (- n-total n-imp)]
                               [n-holes (implicit-holes-needed ftype n-user-args)])
                          ;; Arity check: reject over-application for known globals
                          (cond
                            ;; Too many args (more than explicit count, and not total count)
                            [(and (> n-user-args n-exp)
                                  (not (= n-user-args n-total))
                                  (> n-total 0))
                             (arity-error loc
                               (format "Too many arguments to '~a'" fname)
                               fname n-exp n-user-args
                               (pp-function-signature ftype))]
                            ;; Insert implicits if needed
                            [(> n-holes 0)
                             (let ([with-metas
                                    (for/fold ([acc ef])
                                              ([_ (in-range n-holes)])
                                      (expr-app acc (fresh-meta ctx-empty (expr-hole)
                                                      (meta-source-info loc 'implicit-app
                                                        (format "implicit argument for ~a" fname)
                                                        #f (env->name-stack env)))))])
                               (elaborate-args with-metas args env depth loc))]
                            ;; Normal case: no insertion needed, proceed
                            [else
                             (elaborate-args ef args env depth loc)]))
                        (elaborate-args ef args env depth loc)))
                  (elaborate-args ef args env depth loc))))])]

    ;; Pair
    [(surf-pair e1 e2 loc)
     (let ([a (elaborate e1 env depth)]
           [b (elaborate e2 env depth)])
       (cond [(prologos-error? a) a]
             [(prologos-error? b) b]
             [else (expr-pair a b)]))]

    ;; Projections
    [(surf-fst e loc)
     (let ([e1 (elaborate e env depth)])
       (if (prologos-error? e1) e1 (expr-fst e1)))]
    [(surf-snd e loc)
     (let ([e1 (elaborate e env depth)])
       (if (prologos-error? e1) e1 (expr-snd e1)))]

    ;; Annotation: (the T e) -> ann(elab-e, elab-T)
    [(surf-ann type term loc)
     (let ([t (elaborate type env depth)]
           [e (elaborate term env depth)])
       (cond [(prologos-error? t) t]
             [(prologos-error? e) e]
             [else (expr-ann e t)]))]

    ;; Equality type
    [(surf-eq type lhs rhs loc)
     (let ([t (elaborate type env depth)]
           [l (elaborate lhs env depth)]
           [r (elaborate rhs env depth)])
       (cond [(prologos-error? t) t]
             [(prologos-error? l) l]
             [(prologos-error? r) r]
             [else (expr-Eq t l r)]))]

    ;; Union type
    [(surf-union left right loc)
     (let ([l (elaborate left env depth)]
           [r (elaborate right env depth)])
       (cond [(prologos-error? l) l]
             [(prologos-error? r) r]
             [else (expr-union l r)]))]

    ;; boolrec
    [(surf-boolrec mot tc fc target loc)
     (let ([m (elaborate mot env depth)]
           [t (elaborate tc env depth)]
           [f (elaborate fc env depth)]
           [tgt (elaborate target env depth)])
       (cond [(prologos-error? m) m]
             [(prologos-error? t) t]
             [(prologos-error? f) f]
             [(prologos-error? tgt) tgt]
             [else (expr-boolrec m t f tgt)]))]

    ;; natrec
    [(surf-natrec mot base step target loc)
     (let ([m (elaborate mot env depth)]
           [b (elaborate base env depth)]
           [s (elaborate step env depth)]
           [tgt (elaborate target env depth)])
       (cond [(prologos-error? m) m]
             [(prologos-error? b) b]
             [(prologos-error? s) s]
             [(prologos-error? tgt) tgt]
             [else (expr-natrec m b s tgt)]))]

    ;; J
    [(surf-J mot base left right proof loc)
     (let ([m (elaborate mot env depth)]
           [b (elaborate base env depth)]
           [l (elaborate left env depth)]
           [r (elaborate right env depth)]
           [p (elaborate proof env depth)])
       (cond [(prologos-error? m) m]
             [(prologos-error? b) b]
             [(prologos-error? l) l]
             [(prologos-error? r) r]
             [(prologos-error? p) p]
             [else (expr-J m b l r p)]))]

    ;; Vec/Fin
    [(surf-vec-type t n loc)
     (let ([a (elaborate t env depth)]
           [len (elaborate n env depth)])
       (cond [(prologos-error? a) a]
             [(prologos-error? len) len]
             [else (expr-Vec a len)]))]
    [(surf-vnil t loc)
     (let ([a (elaborate t env depth)])
       (if (prologos-error? a) a (expr-vnil a)))]
    [(surf-vcons t n hd tl loc)
     (let ([a (elaborate t env depth)]
           [len (elaborate n env depth)]
           [h (elaborate hd env depth)]
           [tail (elaborate tl env depth)])
       (cond [(prologos-error? a) a]
             [(prologos-error? len) len]
             [(prologos-error? h) h]
             [(prologos-error? tail) tail]
             [else (expr-vcons a len h tail)]))]
    [(surf-fin-type n loc)
     (let ([bound (elaborate n env depth)])
       (if (prologos-error? bound) bound (expr-Fin bound)))]
    [(surf-fzero n loc)
     (let ([bound (elaborate n env depth)])
       (if (prologos-error? bound) bound (expr-fzero bound)))]
    [(surf-fsuc n inner loc)
     (let ([bound (elaborate n env depth)]
           [i (elaborate inner env depth)])
       (cond [(prologos-error? bound) bound]
             [(prologos-error? i) i]
             [else (expr-fsuc bound i)]))]
    [(surf-vhead t n v loc)
     (let ([a (elaborate t env depth)]
           [len (elaborate n env depth)]
           [vec (elaborate v env depth)])
       (cond [(prologos-error? a) a]
             [(prologos-error? len) len]
             [(prologos-error? vec) vec]
             [else (expr-vhead a len vec)]))]
    [(surf-vtail t n v loc)
     (let ([a (elaborate t env depth)]
           [len (elaborate n env depth)]
           [vec (elaborate v env depth)])
       (cond [(prologos-error? a) a]
             [(prologos-error? len) len]
             [(prologos-error? vec) vec]
             [else (expr-vtail a len vec)]))]
    [(surf-vindex t n i v loc)
     (let ([a (elaborate t env depth)]
           [len (elaborate n env depth)]
           [idx (elaborate i env depth)]
           [vec (elaborate v env depth)])
       (cond [(prologos-error? a) a]
             [(prologos-error? len) len]
             [(prologos-error? idx) idx]
             [(prologos-error? vec) vec]
             [else (expr-vindex a len idx vec)]))]

    ;; ---- Int ----
    [(surf-int-type loc) (expr-Int)]
    [(surf-int-lit v loc) (expr-int v)]
    [(surf-int-add a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-int-add ea eb)]))]
    [(surf-int-sub a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-int-sub ea eb)]))]
    [(surf-int-mul a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-int-mul ea eb)]))]
    [(surf-int-div a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-int-div ea eb)]))]
    [(surf-int-mod a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-int-mod ea eb)]))]
    [(surf-int-neg a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-int-neg ea)))]
    [(surf-int-abs a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-int-abs ea)))]
    [(surf-int-lt a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-int-lt ea eb)]))]
    [(surf-int-le a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-int-le ea eb)]))]
    [(surf-int-eq a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-int-eq ea eb)]))]
    [(surf-from-nat n loc)
     (let ([en (elaborate n env depth)])
       (if (prologos-error? en) en (expr-from-nat en)))]

    ;; ---- Rat ----
    [(surf-rat-type loc) (expr-Rat)]
    [(surf-rat-lit v loc) (expr-rat v)]
    [(surf-rat-add a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-rat-add ea eb)]))]
    [(surf-rat-sub a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-rat-sub ea eb)]))]
    [(surf-rat-mul a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-rat-mul ea eb)]))]
    [(surf-rat-div a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-rat-div ea eb)]))]
    [(surf-rat-neg a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-rat-neg ea)))]
    [(surf-rat-abs a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-rat-abs ea)))]
    [(surf-rat-lt a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-rat-lt ea eb)]))]
    [(surf-rat-le a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-rat-le ea eb)]))]
    [(surf-rat-eq a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-rat-eq ea eb)]))]
    [(surf-from-int n loc)
     (let ([en (elaborate n env depth)])
       (if (prologos-error? en) en (expr-from-int en)))]
    [(surf-rat-numer a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-rat-numer ea)))]
    [(surf-rat-denom a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-rat-denom ea)))]

    ;; ---- Posit8 ----
    [(surf-posit8-type loc) (expr-Posit8)]
    [(surf-posit8 v loc) (expr-posit8 v)]
    [(surf-p8-add a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p8-add ea eb)]))]
    [(surf-p8-sub a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p8-sub ea eb)]))]
    [(surf-p8-mul a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p8-mul ea eb)]))]
    [(surf-p8-div a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p8-div ea eb)]))]
    [(surf-p8-neg a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p8-neg ea)))]
    [(surf-p8-abs a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p8-abs ea)))]
    [(surf-p8-sqrt a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p8-sqrt ea)))]
    [(surf-p8-lt a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p8-lt ea eb)]))]
    [(surf-p8-le a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p8-le ea eb)]))]
    [(surf-p8-from-nat n loc)
     (let ([en (elaborate n env depth)])
       (if (prologos-error? en) en (expr-p8-from-nat en)))]
    [(surf-p8-if-nar tp nc vc v loc)
     (let ([etp (elaborate tp env depth)]
           [enc (elaborate nc env depth)]
           [evc (elaborate vc env depth)]
           [ev (elaborate v env depth)])
       (cond [(prologos-error? etp) etp]
             [(prologos-error? enc) enc]
             [(prologos-error? evc) evc]
             [(prologos-error? ev) ev]
             [else (expr-p8-if-nar etp enc evc ev)]))]

    ;; ---- Posit16 ----
    [(surf-posit16-type loc) (expr-Posit16)]
    [(surf-posit16 v loc) (expr-posit16 v)]
    [(surf-p16-add a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p16-add ea eb)]))]
    [(surf-p16-sub a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p16-sub ea eb)]))]
    [(surf-p16-mul a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p16-mul ea eb)]))]
    [(surf-p16-div a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p16-div ea eb)]))]
    [(surf-p16-neg a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p16-neg ea)))]
    [(surf-p16-abs a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p16-abs ea)))]
    [(surf-p16-sqrt a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p16-sqrt ea)))]
    [(surf-p16-lt a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p16-lt ea eb)]))]
    [(surf-p16-le a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p16-le ea eb)]))]
    [(surf-p16-from-nat n loc)
     (let ([en (elaborate n env depth)])
       (if (prologos-error? en) en (expr-p16-from-nat en)))]
    [(surf-p16-if-nar tp nc vc v loc)
     (let ([etp (elaborate tp env depth)]
           [enc (elaborate nc env depth)]
           [evc (elaborate vc env depth)]
           [ev (elaborate v env depth)])
       (cond [(prologos-error? etp) etp]
             [(prologos-error? enc) enc]
             [(prologos-error? evc) evc]
             [(prologos-error? ev) ev]
             [else (expr-p16-if-nar etp enc evc ev)]))]

    ;; ---- Posit32 ----
    [(surf-posit32-type loc) (expr-Posit32)]
    [(surf-posit32 v loc) (expr-posit32 v)]
    [(surf-p32-add a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p32-add ea eb)]))]
    [(surf-p32-sub a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p32-sub ea eb)]))]
    [(surf-p32-mul a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p32-mul ea eb)]))]
    [(surf-p32-div a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p32-div ea eb)]))]
    [(surf-p32-neg a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p32-neg ea)))]
    [(surf-p32-abs a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p32-abs ea)))]
    [(surf-p32-sqrt a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p32-sqrt ea)))]
    [(surf-p32-lt a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p32-lt ea eb)]))]
    [(surf-p32-le a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p32-le ea eb)]))]
    [(surf-p32-from-nat n loc)
     (let ([en (elaborate n env depth)])
       (if (prologos-error? en) en (expr-p32-from-nat en)))]
    [(surf-p32-if-nar tp nc vc v loc)
     (let ([etp (elaborate tp env depth)]
           [enc (elaborate nc env depth)]
           [evc (elaborate vc env depth)]
           [ev (elaborate v env depth)])
       (cond [(prologos-error? etp) etp]
             [(prologos-error? enc) enc]
             [(prologos-error? evc) evc]
             [(prologos-error? ev) ev]
             [else (expr-p32-if-nar etp enc evc ev)]))]

    ;; ---- Posit64 ----
    [(surf-posit64-type loc) (expr-Posit64)]
    [(surf-posit64 v loc) (expr-posit64 v)]
    [(surf-p64-add a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p64-add ea eb)]))]
    [(surf-p64-sub a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p64-sub ea eb)]))]
    [(surf-p64-mul a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p64-mul ea eb)]))]
    [(surf-p64-div a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p64-div ea eb)]))]
    [(surf-p64-neg a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p64-neg ea)))]
    [(surf-p64-abs a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p64-abs ea)))]
    [(surf-p64-sqrt a loc)
     (let ([ea (elaborate a env depth)])
       (if (prologos-error? ea) ea (expr-p64-sqrt ea)))]
    [(surf-p64-lt a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p64-lt ea eb)]))]
    [(surf-p64-le a b loc)
     (let ([ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-p64-le ea eb)]))]
    [(surf-p64-from-nat n loc)
     (let ([en (elaborate n env depth)])
       (if (prologos-error? en) en (expr-p64-from-nat en)))]
    [(surf-p64-if-nar tp nc vc v loc)
     (let ([etp (elaborate tp env depth)]
           [enc (elaborate nc env depth)]
           [evc (elaborate vc env depth)]
           [ev (elaborate v env depth)])
       (cond [(prologos-error? etp) etp]
             [(prologos-error? enc) enc]
             [(prologos-error? evc) evc]
             [(prologos-error? ev) ev]
             [else (expr-p64-if-nar etp enc evc ev)]))]

    ;; ---- Quire operations ----
    ;; Types
    [(surf-quire8-type loc) (expr-Quire8)]
    [(surf-quire16-type loc) (expr-Quire16)]
    [(surf-quire32-type loc) (expr-Quire32)]
    [(surf-quire64-type loc) (expr-Quire64)]
    ;; Zero constructors → quireW-val with 0
    [(surf-quire8-zero loc) (expr-quire8-val 0)]
    [(surf-quire16-zero loc) (expr-quire16-val 0)]
    [(surf-quire32-zero loc) (expr-quire32-val 0)]
    [(surf-quire64-zero loc) (expr-quire64-val 0)]
    ;; FMA: (qW-fma q a b)
    [(surf-quire8-fma q a b loc)
     (let ([eq (elaborate q env depth)]
           [ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? eq) eq]
             [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-quire8-fma eq ea eb)]))]
    [(surf-quire16-fma q a b loc)
     (let ([eq (elaborate q env depth)]
           [ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? eq) eq]
             [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-quire16-fma eq ea eb)]))]
    [(surf-quire32-fma q a b loc)
     (let ([eq (elaborate q env depth)]
           [ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? eq) eq]
             [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-quire32-fma eq ea eb)]))]
    [(surf-quire64-fma q a b loc)
     (let ([eq (elaborate q env depth)]
           [ea (elaborate a env depth)]
           [eb (elaborate b env depth)])
       (cond [(prologos-error? eq) eq]
             [(prologos-error? ea) ea]
             [(prologos-error? eb) eb]
             [else (expr-quire64-fma eq ea eb)]))]
    ;; TO: (qW-to q)
    [(surf-quire8-to q loc)
     (let ([eq (elaborate q env depth)])
       (if (prologos-error? eq) eq (expr-quire8-to eq)))]
    [(surf-quire16-to q loc)
     (let ([eq (elaborate q env depth)])
       (if (prologos-error? eq) eq (expr-quire16-to eq)))]
    [(surf-quire32-to q loc)
     (let ([eq (elaborate q env depth)])
       (if (prologos-error? eq) eq (expr-quire32-to eq)))]
    [(surf-quire64-to q loc)
     (let ([eq (elaborate q env depth)])
       (if (prologos-error? eq) eq (expr-quire64-to eq)))]

    ;; Approximate literal: ~N → default Posit32
    ;; Context-aware width selection happens in the type checker (check mode).
    ;; At elaboration time, we default to Posit32.
    [(surf-approx-literal v loc)
     (expr-posit32 (posit32-encode (if (exact? v) v (inexact->exact v))))]

    ;; ---- Keyword type and literal ----
    [(surf-keyword-type loc)
     (expr-Keyword)]
    [(surf-keyword name loc)
     (expr-keyword name)]

    ;; ---- Map type and operations ----
    [(surf-map-type k v loc)
     (let ([ek (elaborate k env depth)]
           [ev (elaborate v env depth)])
       (cond [(prologos-error? ek) ek]
             [(prologos-error? ev) ev]
             [else (expr-Map ek ev)]))]

    [(surf-map-literal entries loc)
     ;; Elaborate to nested map-assoc on map-empty.
     ;; entries is a list of (parsed-key . parsed-val) pairs.
     ;; Key and value types use fresh metas — unification will resolve them.
     (if (null? entries)
         ;; Empty map: fresh metas for key/value types
         (let ([km (fresh-meta ctx-empty (expr-hole)
                     (meta-source-info loc 'map-key-type "key type of empty map literal" #f (env->name-stack env)))]
               [vm (fresh-meta ctx-empty (expr-hole)
                     (meta-source-info loc 'map-val-type "value type of empty map literal" #f (env->name-stack env)))])
           (expr-map-empty km vm))
         ;; Non-empty: elaborate all entries, then fold into map-assoc
         (let ([km (fresh-meta ctx-empty (expr-hole)
                     (meta-source-info loc 'map-key-type "key type of map literal" #f (env->name-stack env)))]
               [vm (fresh-meta ctx-empty (expr-hole)
                     (meta-source-info loc 'map-val-type "value type of map literal" #f (env->name-stack env)))])
           (let loop ([remaining entries]
                      [result (expr-map-empty km vm)])
             (cond
               [(null? remaining)
                result]
               [else
                (define entry (car remaining))
                (define ek (elaborate (car entry) env depth))
                (define ev (elaborate (cdr entry) env depth))
                (cond
                  [(prologos-error? ek) ek]
                  [(prologos-error? ev) ev]
                  [else
                   (loop (cdr remaining)
                         (expr-map-assoc result ek ev))])]))))]

    [(surf-map-empty k v loc)
     (let ([ek (elaborate k env depth)]
           [ev (elaborate v env depth)])
       (cond [(prologos-error? ek) ek]
             [(prologos-error? ev) ev]
             [else (expr-map-empty ek ev)]))]

    [(surf-map-assoc m k v loc)
     (let ([em (elaborate m env depth)]
           [ek (elaborate k env depth)]
           [ev (elaborate v env depth)])
       (cond [(prologos-error? em) em]
             [(prologos-error? ek) ek]
             [(prologos-error? ev) ev]
             [else (expr-map-assoc em ek ev)]))]

    [(surf-map-get m k loc)
     (let ([em (elaborate m env depth)]
           [ek (elaborate k env depth)])
       (cond [(prologos-error? em) em]
             [(prologos-error? ek) ek]
             [else (expr-map-get em ek)]))]

    [(surf-map-dissoc m k loc)
     (let ([em (elaborate m env depth)]
           [ek (elaborate k env depth)])
       (cond [(prologos-error? em) em]
             [(prologos-error? ek) ek]
             [else (expr-map-dissoc em ek)]))]

    [(surf-map-size m loc)
     (let ([em (elaborate m env depth)])
       (if (prologos-error? em) em
           (expr-map-size em)))]

    [(surf-map-has-key m k loc)
     (let ([em (elaborate m env depth)]
           [ek (elaborate k env depth)])
       (cond [(prologos-error? em) em]
             [(prologos-error? ek) ek]
             [else (expr-map-has-key em ek)]))]

    [(surf-map-keys m loc)
     (let ([em (elaborate m env depth)])
       (if (prologos-error? em) em
           (expr-map-keys em)))]

    [(surf-map-vals m loc)
     (let ([em (elaborate m env depth)])
       (if (prologos-error? em) em
           (expr-map-vals em)))]

    ;; Reduce: ML-style pattern matching
    ;; Each arm's body must be elaborated with binding names in scope.
    ;; We add dummy binders (the actual types come from the type checker).
    [(surf-reduce scrutinee arms loc)
     (let ([elab-scrutinee (elaborate scrutinee env depth)])
       (if (prologos-error? elab-scrutinee) elab-scrutinee
           (let ([elab-arms
                  (for/list ([arm (in-list arms)])
                    (elaborate-reduce-arm arm env depth))])
             (define first-err (findf prologos-error? elab-arms))
             (if first-err first-err
                 ;; All match/reduce uses structural PM with native constructors.
                 ;; No Church fold desugaring path needed.
                 (expr-reduce elab-scrutinee elab-arms #t)))))]

    ;; Foreign escape block: racket{ code } [captures] -> [exports]
    ;; Desugar to expr-foreign-fn application:
    ;; 1. Build a Racket lambda from code + capture names
    ;; 2. Eval it in a Racket namespace
    ;; 3. Wrap as expr-foreign-fn
    ;; 4. Apply to elaborated capture expressions
    [(surf-foreign-block lang code-datums captures return-type loc)
     (elaborate-foreign-block lang code-datums captures return-type loc env depth)]

    ;; Fallback
    [_ (prologos-error srcloc-unknown (format "Cannot elaborate: ~a" surf))]))

;; ========================================
;; Elaborate a list of arguments into nested application
;; ========================================
(define (elaborate-args func-expr arg-surfs env depth loc)
  (if (null? arg-surfs)
      func-expr
      (let ([arg (elaborate (car arg-surfs) env depth)])
        (if (prologos-error? arg) arg
            (elaborate-args (expr-app func-expr arg)
                           (cdr arg-surfs) env depth loc)))))

;; ========================================
;; Elaborate a reduce arm
;; ========================================
;; Bindings are added to the environment (with dummy types) so
;; the body's variable references get correct de Bruijn indices.
;; The actual types are resolved by the type checker.
(define (elaborate-reduce-arm arm env depth)
  (match arm
    [(reduce-arm ctor-name bindings body-surf loc)
     ;; Add each binding name to the environment
     ;; Sprint 10: Wildcard `_` — skip env-extend but still increment depth
     ;; so de Bruijn indices for subsequent bindings remain correct.
     (define-values (new-env new-depth)
       (for/fold ([e env] [d depth])
                 ([name (in-list bindings)])
         (if (eq? name '_)
             (values e (+ d 1))               ;; wildcard: skip binding, bump depth
             (values (env-extend e name d) (+ d 1)))))
     (define elab-body (elaborate body-surf new-env new-depth))
     (if (prologos-error? elab-body) elab-body
         (expr-reduce-arm ctor-name (length bindings) elab-body))]))

;; ========================================
;; Elaborate a foreign escape block
;; ========================================
;; Transforms: racket{ code } [captures] -> [exports]
;; into: (expr-app ... (expr-foreign-fn gensym proc arity () marshal-in marshal-out) cap1 cap2 ...)
;;
;; The strategy:
;; 1. Elaborate capture types to core types
;; 2. Build a Racket lambda: (lambda (cap-names...) code-datums...)
;; 3. Eval the lambda in a Racket namespace
;; 4. Determine return type (from annotation or hole for checking context)
;; 5. Build type: Cap1Type -> Cap2Type -> ... -> ReturnType
;; 6. Create expr-foreign-fn with marshallers
;; 7. Apply to elaborated capture expressions
(define (elaborate-foreign-block lang code-datums captures return-type loc env depth)
  ;; Step 1: Elaborate capture types
  (define elab-captures
    (for/list ([cap (in-list captures)])
      (define name (car cap))
      (define type-surf (cadr cap))
      (define type-core (elaborate type-surf env depth))
      (list name type-surf type-core)))

  ;; Check for errors in capture type elaboration
  (define cap-type-error
    (for/or ([cap (in-list elab-captures)])
      (and (prologos-error? (caddr cap)) (caddr cap))))

  (cond
    [cap-type-error cap-type-error]
    [else
     ;; Step 2: Elaborate return type (if provided)
     (define ret-type-core
       (if return-type
           (elaborate return-type env depth)
           #f))  ;; #f = no explicit return type

     (cond
       [(and ret-type-core (prologos-error? ret-type-core)) ret-type-core]
       [else
        (define capture-names (map car captures))
        (define capture-types-core (map caddr elab-captures))

        ;; Step 3: Build a Racket lambda from the code datums
        (define rkt-lambda-expr
          (if (null? capture-names)
              `(lambda () ,@code-datums)
              `(lambda ,capture-names ,@code-datums)))

        ;; Step 4: Eval in a Racket namespace
        (define rkt-ns (make-base-namespace))
        (define rkt-proc
          (with-handlers ([exn:fail? (lambda (e)
                                       (prologos-error loc
                                         (format "foreign block eval error: ~a" (exn-message e))))])
            (eval rkt-lambda-expr rkt-ns)))

        (cond
          [(prologos-error? rkt-proc) rkt-proc]
          [else
           ;; Step 5: Determine return type
           ;; If no explicit return type AND no captures, eval immediately
           ;; and auto-detect the Prologos type from the Racket result
           (define-values (actual-ret-type-core result-val)
             (cond
               ;; Explicit return type provided
               [ret-type-core (values ret-type-core #f)]
               ;; No return type, no captures: eval thunk immediately and detect type
               [(null? capture-names)
                (define rkt-result
                  (with-handlers ([exn:fail? (lambda (e)
                                               (prologos-error loc
                                                 (format "foreign block runtime error: ~a" (exn-message e))))])
                    (rkt-proc)))
                (cond
                  [(prologos-error? rkt-result) (values #f rkt-result)]
                  [(and (exact-integer? rkt-result) (>= rkt-result 0))
                   (values (expr-Nat) (integer->nat rkt-result))]
                  [(boolean? rkt-result)
                   (values (expr-Bool) (if rkt-result (expr-true) (expr-false)))]
                  [(void? rkt-result)
                   (values (expr-Unit) (expr-unit))]
                  [else
                   (values #f
                     (prologos-error loc
                       (format "foreign block: cannot auto-detect type of Racket result: ~a" rkt-result)))])]
               ;; No return type, with captures: error — need explicit type
               [else
                (values #f
                  (prologos-error loc
                    "foreign block with captures requires explicit return type"))]))

           (cond
             ;; If result-val is an error, propagate it
             [(and result-val (prologos-error? result-val)) result-val]
             ;; If we eagerly evaluated (zero captures, auto-detect), return the result directly
             [result-val result-val]
             ;; Normal path: build expr-foreign-fn with marshallers
             [else
              ;; Build the full type: Cap1Type -> Cap2Type -> ... -> ReturnType
              (define full-type
                (foldr (lambda (cap-type rest-type)
                         (expr-Pi 'mw cap-type rest-type))
                       actual-ret-type-core
                       capture-types-core))

              ;; Build marshaller pair from the type
              (define parsed-type (parse-foreign-type full-type))
              (define-values (marshal-in marshal-out) (make-marshaller-pair parsed-type))
              (define arity (length capture-names))

              ;; Create the foreign-fn with a gensym name
              (define fn-name (gensym 'foreign-block))
              (define foreign-fn-val
                (expr-foreign-fn fn-name rkt-proc arity '() marshal-in marshal-out))

              ;; Register the type in global-env so the infer case can find it
              (current-global-env
               (global-env-add (current-global-env) fn-name full-type foreign-fn-val))

              ;; Elaborate capture expressions (they reference variables in scope)
              (define elab-cap-exprs
                (for/list ([cap (in-list captures)])
                  (define name (car cap))
                  (elaborate (surf-var name loc) env depth)))

              ;; Check for errors in capture elaboration
              (define cap-expr-error
                (for/or ([e (in-list elab-cap-exprs)])
                  (and (prologos-error? e) e)))

              (cond
                [cap-expr-error cap-expr-error]
                [else
                 ;; Apply the foreign-fn to all capture expressions
                 (foldl (lambda (cap-expr acc)
                          (expr-app acc cap-expr))
                        foreign-fn-val
                        elab-cap-exprs)])])])])]))

;; ========================================
;; Helper: natural -> level
;; ========================================
(define (nat->level n)
  (if (= n 0) (lzero) (lsuc (nat->level (- n 1)))))

;; ========================================
;; Elaborate top-level commands
;; Returns the surface command + elaborated expressions,
;; or a prologos-error
;; ========================================
(define (elaborate-top-level surf)
  (match surf
    [(surf-def name type-surf body-surf loc)
     (cond
       ;; Sprint 10: No type annotation — elaborate body only
       [(not type-surf)
        (let ([bd (elaborate body-surf)])
          (if (prologos-error? bd) bd
              (list 'def name #f bd)))]
       [else
        (let ([ty (elaborate type-surf)]
              [bd (elaborate body-surf)])
          (cond
            [(prologos-error? ty) ty]
            [(prologos-error? bd) bd]
            [else (list 'def name ty bd)]))])]

    [(surf-check expr-surf type-surf loc)
     (let ([e (elaborate expr-surf)]
           [t (elaborate type-surf)])
       (cond
         [(prologos-error? e) e]
         [(prologos-error? t) t]
         [else (list 'check e t)]))]

    [(surf-eval expr-surf loc)
     (let ([e (elaborate expr-surf)])
       (if (prologos-error? e) e
           (list 'eval e)))]

    [(surf-infer expr-surf loc)
     (let ([e (elaborate expr-surf)])
       (if (prologos-error? e) e
           (list 'infer e)))]

    ;; Inspection: expand — datum passes through, handled in driver
    [(surf-expand datum loc)
     (list 'expand datum)]

    ;; Inspection: parse — surface AST passes through, shown directly
    [(surf-parse expr-surf loc)
     (list 'parse expr-surf)]

    ;; Inspection: elaborate — elaborate the sub-expression
    [(surf-elaborate expr-surf loc)
     (let ([e (elaborate expr-surf)])
       (if (prologos-error? e) e
           (list 'elaborate e)))]

    [(surf-defn name _ _ _ loc)
     (prologos-error loc "defn should have been expanded by the macro system before elaboration")]

    [(surf-the-fn _ _ _ loc)
     (prologos-error loc "the-fn should have been expanded by the macro system before elaboration")]

    [_ (prologos-error srcloc-unknown (format "Unknown top-level form: ~a" surf))]))
