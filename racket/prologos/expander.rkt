#lang racket/base

;;;
;;; PROLOGOS EXPANDER
;;; Compile-time helpers for the #lang prologos module language.
;;; This module is required for-syntax by main.rkt, so all functions
;;; here run at phase 1 (compile time) of the user's module.
;;;
;;; Provides:
;;;   expand-prologos-module : syntax? -> syntax?
;;;     Takes the full #%module-begin syntax and returns expanded module.
;;;
;;; The logic is a direct adaptation of driver.rkt process-command,
;;; except errors raise exn:fail:prologos instead of being returned.
;;;

(require racket/match
         racket/list
         racket/string
         syntax/parse
         "source-location.rkt"
         "surface-syntax.rkt"
         "errors.rkt"
         "parser.rkt"
         "elaborator.rkt"
         "prelude.rkt"
         "syntax.rkt"
         "typing-core.rkt"
         "typing-errors.rkt"
         "reduction.rkt"
         "pretty-print.rkt"
         "global-env.rkt"
         "lang-error.rkt"
         "macros.rkt"
         "metavar-store.rkt"
         "zonk.rkt"
         "multi-dispatch.rkt"
         "trait-resolution.rkt"
         (for-template racket/base
                      "repl-support.rkt"))

(provide expand-prologos-module)

;; ========================================
;; Extract source location from surface AST
;; ========================================
(define (surf-loc surf)
  (cond
    [(surf-def? surf)       (surf-def-srcloc surf)]
    [(surf-defn? surf)      (surf-defn-srcloc surf)]
    [(surf-check? surf)     (surf-check-srcloc surf)]
    [(surf-eval? surf)      (surf-eval-srcloc surf)]
    [(surf-infer? surf)     (surf-infer-srcloc surf)]
    [(surf-expand? surf)    (surf-expand-srcloc surf)]
    [(surf-parse? surf)     (surf-parse-srcloc surf)]
    [(surf-elaborate? surf) (surf-elaborate-srcloc surf)]
    [else                   srcloc-unknown]))

;; ========================================
;; Process a single parsed surface form
;; ========================================
;; Sprint 10: Check if an elaborated type contains expr-hole
(define (type-contains-hole? e)
  (match e
    [(expr-hole) #t]
    [(expr-typed-hole _) #t]
    [(expr-Pi _ a b) (or (type-contains-hole? a) (type-contains-hole? b))]
    [(expr-Sigma a b) (or (type-contains-hole? a) (type-contains-hole? b))]
    [(expr-app f x) (or (type-contains-hole? f) (type-contains-hole? x))]
    [(expr-lam _ a b) (or (type-contains-hole? a) (type-contains-hole? b))]
    [_ #f]))

;; Replace expr-hole with fresh metavariables in a type expression.
;; This allows holes in type annotations (e.g., return type of pattern-compiled
;; functions) to be solved via unification during type checking.
(define (holes-to-metas e)
  (match e
    [(expr-hole) (fresh-meta ctx-empty (expr-Type 0) "type-hole")]
    [(expr-typed-hole _) e]
    [(expr-Pi m a b) (expr-Pi m (holes-to-metas a) (holes-to-metas b))]
    [(expr-Sigma a b) (expr-Sigma (holes-to-metas a) (holes-to-metas b))]
    [(expr-app f x) (expr-app (holes-to-metas f) (holes-to-metas x))]
    [(expr-lam m a b) (expr-lam m (holes-to-metas a) (holes-to-metas b))]
    [_ e]))

;; After zonk-final, replace any remaining unsolved metas with holes.
;; Prevents dangling meta references in stored types (metas are cleared
;; between commands by reset-meta-store!).
(define (unsolved-metas-to-holes e)
  (match e
    [(expr-meta _) (expr-hole)]
    [(expr-Pi m a b) (expr-Pi m (unsolved-metas-to-holes a) (unsolved-metas-to-holes b))]
    [(expr-Sigma a b) (expr-Sigma (unsolved-metas-to-holes a) (unsolved-metas-to-holes b))]
    [(expr-app f x) (expr-app (unsolved-metas-to-holes f) (unsolved-metas-to-holes x))]
    [(expr-lam m a b) (expr-lam m (unsolved-metas-to-holes a) (unsolved-metas-to-holes b))]
    [_ e]))


;; Returns: (list 'def name type-string)
;;        | (list 'output string)
;; Raises: exn:fail:prologos on any error
(define (process-form surf)
  (reset-meta-store!)  ;; Sprint 7: clear metas between forms (matches driver.rkt)
  (define loc (surf-loc surf))
  (define elab-result (elaborate-top-level surf))
  (when (prologos-error? elab-result)
    (raise-prologos-error elab-result))

  (match elab-result
    ;; Sprint 10: (def name #f body) — type inferred from body
    [(list 'def name #f body)
     (let ([inferred-type (infer/err ctx-empty body loc)])
       (when (prologos-error? inferred-type)
         (raise-prologos-error inferred-type))
       (let ([ty-ok (is-type/err ctx-empty inferred-type loc)])
         (when (prologos-error? ty-ok)
           (raise-prologos-error ty-ok))
         ;; Track 2: trait + hasmethod resolution handled reactively by propagator callbacks
         (let ([te (check-unresolved-trait-constraints)])
           (when (not (null? te))
             (raise-prologos-error (car te))))
         (let ([z-type (zonk-final inferred-type)]
               [z-body (zonk-final body)])
           (current-prelude-env
            (global-env-add (current-prelude-env) name z-type z-body))
           (list 'def name (pp-expr z-type)))))]

    ;; (def name type body) — annotated path
    [(list 'def name type body)
     ;; Sprint 10: skip is-type check when type has holes (bare-param defn)
     (define has-holes? (type-contains-hole? type))
     (let ([ty-ok (if has-holes? #t (is-type/err ctx-empty type loc))])
       (when (prologos-error? ty-ok)
         (raise-prologos-error ty-ok))
       ;; Replace holes with metas so they can be solved via unification
       (define type* (if has-holes? (holes-to-metas type) type))
       (let ([chk (check/err ctx-empty body type* loc)])
         (when (prologos-error? chk)
           (raise-prologos-error chk))
         ;; Track 2: trait + hasmethod resolution handled reactively by propagator callbacks
         (let ([te (check-unresolved-trait-constraints)])
           (when (not (null? te))
             (raise-prologos-error (car te))))
         ;; Zonk for storage and display (defaults unsolved level/mult-metas)
         ;; Convert any unsolved metas back to holes (prevents dangling refs)
         (let ([z-type-raw (zonk-final type*)]
               [z-body (zonk-final body)])
           (define z-type (if has-holes? (unsolved-metas-to-holes z-type-raw) z-type-raw))
           ;; Update the global environment for subsequent forms
           (current-prelude-env
            (global-env-add (current-prelude-env) name z-type z-body))
           (list 'def name (pp-expr z-type)))))]

    ;; (check expr type)
    [(list 'check expr type)
     (let ([chk (check/err ctx-empty expr type loc)])
       (when (prologos-error? chk)
         (raise-prologos-error chk))
       (list 'output "OK"))]

    ;; (eval expr)
    [(list 'eval expr)
     (let ([ty (infer/err ctx-empty expr loc)])
       (when (prologos-error? ty)
         (raise-prologos-error ty))
       ;; Track 2: trait + hasmethod resolution handled reactively by propagator callbacks
       (let ([te (check-unresolved-trait-constraints)])
         (when (not (null? te))
           (raise-prologos-error (car te))))
       (let ([val (nf (zonk-final expr))]
             [ty-nf (nf (zonk-final ty))])
         (list 'output (format "~a : ~a" (pp-expr val) (pp-expr ty-nf)))))]

    ;; (infer expr)
    [(list 'infer expr)
     (let ([ty (infer/err ctx-empty expr loc)])
       (when (prologos-error? ty)
         (raise-prologos-error ty))
       ;; Track 2: trait + hasmethod resolution handled reactively by propagator callbacks
       (let ([te (check-unresolved-trait-constraints)])
         (when (not (null? te))
           (raise-prologos-error (car te))))
       (list 'output (pp-expr (zonk-final ty))))]

    ;; (expand datum) — show preparse expansion
    [(list 'expand datum)
     (list 'output (format "~s" (preparse-expand-single datum)))]

    ;; (parse surf) — show parsed surface AST
    [(list 'parse surf-ast)
     (list 'output (format "~s" surf-ast))]

    ;; (elaborate expr) — show elaborated core AST
    [(list 'elaborate expr)
     (list 'output (pp-expr (zonk-final expr)))]

    [_ (raise-prologos-error
        (prologos-error srcloc-unknown
                        (format "Unknown top-level form: ~a" elab-result)))]))

;; ========================================
;; Expand an entire #lang prologos module
;; ========================================
;; Called from the define-syntax form in main.rkt.
;; Receives the full (#%module-begin form ...) syntax.
;; Returns expanded (#%module-begin out-expr ...) syntax.
(define (expand-prologos-module stx)
  (syntax-parse stx
    [(_ form ...)
     (parameterize ([current-prelude-env (hasheq)]
                    [current-preparse-registry (current-preparse-registry)]
                    [current-spec-store (current-spec-store)])
       ;; Pre-parse macro expansion: expand defmacro/let/do/if/deftype
       (define expanded-stxs (preparse-expand-all (syntax->list #'(form ...))))
       (define output-exprs
         (for/list ([form-stx (in-list expanded-stxs)])
           ;; Parse the syntax object into surface AST
           (define parsed (parse-datum form-stx))
           (when (prologos-error? parsed)
             (raise-prologos-error parsed))
           ;; Expand macros (defn → def, the-fn, implicit eval, etc.)
           (define expanded (expand-top-level parsed))
           (when (prologos-error? expanded)
             (raise-prologos-error expanded))
           ;; Process the form (type check, elaborate, etc.)
           ;; Multi-body defn: surf-def-group contains multiple surf-defs
           (cond
             [(surf-def-group? expanded)
              (define grp-name (surf-def-group-name expanded))
              (define grp-arities (surf-def-group-arities expanded))
              (define grp-docstring (surf-def-group-docstring expanded))
              ;; Register dispatch table
              (define arity-map
                (for/fold ([m (hasheq)])
                          ([arity (in-list grp-arities)])
                  (hash-set m arity (string->symbol (format "~a::~a" grp-name arity)))))
              (register-multi-defn! grp-name grp-arities arity-map grp-docstring)
              ;; Process each clause def
              (for ([def (in-list (surf-def-group-defs expanded))])
                (reset-meta-store!)
                (process-form def))
              #`(displayln #,(format "~a defined (arities: ~a)."
                                     grp-name
                                     (string-join (map number->string (sort grp-arities <)) ", ")))]
             [else
              (define result (process-form expanded))
              ;; Generate runtime code
              (match result
                [(list 'def name type-str)
                 #`(displayln #,(format "~a : ~a defined." name type-str))]
                [(list 'output str)
                 #`(displayln #,str)])])))
       ;; Wrap in the real #%module-begin
       ;; Include prologos-init-repl-env to populate runtime env for REPL
       ;; Pass expanded syntax (after pre-parse) for REPL replay
       (with-syntax ([(out-expr ...) output-exprs]
                     [(form-stx ...) expanded-stxs])
         #'(#%module-begin
            out-expr ...
            (prologos-init-repl-env
             (list (quote-syntax form-stx) ...)))))]))
