#lang racket/base

;;;
;;; PROLOGOS MACROS
;;; Two-layer macro expansion system:
;;;
;;; Layer 1 (pre-parse): S-expression datum → datum rewrites.
;;;   - defmacro: user-defined pattern-template macros
;;;   - Built-in: let, do, if, deftype
;;;   Runs BEFORE the parser, on raw S-expression datums.
;;;
;;; Layer 2 (post-parse): surface AST → surface AST transforms.
;;;   - defn: sugared function definition with parameter name list
;;;   - the-fn: annotated lambda shorthand
;;;   - Implicit eval: bare top-level expressions wrapped in surf-eval
;;;   Runs AFTER parsing, on surf-* structs.
;;;

(require racket/match
         racket/list
         "surface-syntax.rkt"
         "source-location.rkt"
         "errors.rkt"
         "namespace.rkt"
         "global-env.rkt")

(provide ;; Post-parse (layer 2)
         expand-top-level
         current-macro-registry
         register-macro!
         ;; Pre-parse (layer 1)
         current-preparse-registry
         register-preparse-macro!
         preparse-expand-form
         preparse-expand-all
         preparse-macro
         preparse-macro?
         pattern-var?
         datum-match
         datum-subst
         process-defmacro
         process-deftype
         process-data
         ;; Constructor metadata registry (for reduce)
         current-ctor-registry
         current-type-meta
         ctor-meta
         ctor-meta?
         ctor-meta-type-name
         ctor-meta-params
         ctor-meta-field-types
         ctor-meta-is-recursive
         ctor-meta-branch-index
         register-ctor!
         lookup-ctor
         lookup-type-ctors
         ;; Shared
         extract-pi-binders)

;; ================================================================
;; LAYER 1: PRE-PARSE MACRO SYSTEM
;; ================================================================

;; ========================================
;; Pre-parse macro struct and registry
;; ========================================

;; A pre-parse macro: pattern-template rewrite on S-expression datums
(struct preparse-macro (name pattern template) #:transparent)

;; Registry: symbol → (or/c preparse-macro? procedure?)
;;   preparse-macro = user-defined pattern-template (from defmacro)
;;   procedure = built-in procedural macro (e.g., let, do, if)
(define current-preparse-registry (make-parameter (hasheq)))

(define (register-preparse-macro! name entry)
  (current-preparse-registry
   (hash-set (current-preparse-registry) name entry)))

;; ========================================
;; Pattern variables: symbols starting with $
;; ========================================
(define (pattern-var? x)
  (and (symbol? x)
       (not (eq? x '$angle-type))  ; reader sentinel, not a pattern variable
       (let ([s (symbol->string x)])
         (and (> (string-length s) 1)
              (char=? (string-ref s 0) #\$)))))

;; ========================================
;; datum-match: match a datum against a pattern
;; ========================================
;; Returns a hash of bindings ($name → value) on success, #f on failure.
;;
;; Pattern language:
;;   $name         — matches any single datum, binds it
;;   literal       — matches exactly (symbol, number, boolean)
;;   (pat ...)     — matches a list of the same length
;;   (pat ... $x ...) — $x captures remaining elements as a list
;;     (the ... after $x is literal ellipsis symbol)
(define (datum-match pattern datum)
  (cond
    ;; Pattern variable: matches anything
    [(pattern-var? pattern)
     (hasheq pattern datum)]
    ;; Literal match
    [(and (symbol? pattern) (symbol? datum) (eq? pattern datum))
     (hasheq)]
    [(and (number? pattern) (number? datum) (= pattern datum))
     (hasheq)]
    [(and (boolean? pattern) (boolean? datum) (eq? pattern datum))
     (hasheq)]
    ;; List match
    [(and (list? pattern) (list? datum))
     (datum-match-list pattern datum)]
    ;; No match
    [else #f]))

;; Match list patterns, handling ellipsis rest patterns
(define (datum-match-list pats dats)
  (cond
    ;; Both empty — success
    [(and (null? pats) (null? dats)) (hasheq)]
    ;; Pattern empty but data remains — fail
    [(null? pats) #f]
    ;; Check for ellipsis rest pattern: ($var ...)
    [(and (>= (length pats) 2)
          (pattern-var? (car pats))
          (eq? (cadr pats) '...))
     ;; $var captures remaining data minus any trailing fixed patterns
     (let ([remaining-pats (cddr pats)])
       (if (null? remaining-pats)
           ;; $var ... at end — captures all remaining data as a list
           (hasheq (car pats) dats)
           ;; $var ... followed by more patterns — not supported in v1
           #f))]
    ;; Data empty but pattern remains — fail
    [(null? dats) #f]
    ;; Match first element, then rest
    [else
     (let ([first-match (datum-match (car pats) (car dats))])
       (and first-match
            (let ([rest-match (datum-match-list (cdr pats) (cdr dats))])
              (and rest-match
                   (merge-bindings first-match rest-match)))))]))

;; Merge two binding hashes; fail if same variable bound to different values
(define (merge-bindings a b)
  (for/fold ([result a])
            ([(k v) (in-hash b)])
    (if (not result) #f
        (let ([existing (hash-ref result k 'not-found)])
          (cond
            [(eq? existing 'not-found) (hash-set result k v)]
            [(equal? existing v) result]
            [else #f])))))

;; ========================================
;; datum-subst: substitute bindings into a template
;; ========================================
;; Replaces pattern variables with their bound values.
;; Handles $name ... for splicing lists.
(define (datum-subst template bindings)
  (cond
    ;; Pattern variable: substitute
    [(pattern-var? template)
     (hash-ref bindings template
               (lambda ()
                 (error 'defmacro "Unbound pattern variable in template: ~a" template)))]
    ;; List template: handle splicing
    [(list? template)
     (datum-subst-list template bindings)]
    ;; Literal: pass through
    [else template]))

;; Substitute in a list template, handling $var ... splicing
(define (datum-subst-list elems bindings)
  (cond
    [(null? elems) '()]
    ;; Check for splice: $var ...
    [(and (>= (length elems) 2)
          (pattern-var? (car elems))
          (eq? (cadr elems) '...))
     (let ([val (hash-ref bindings (car elems)
                          (lambda ()
                            (error 'defmacro "Unbound pattern variable: ~a" (car elems))))])
       (unless (list? val)
         (error 'defmacro "Splice variable ~a must be bound to a list, got: ~a"
                (car elems) val))
       (append val (datum-subst-list (cddr elems) bindings)))]
    ;; Regular element
    [else
     (cons (datum-subst (car elems) bindings)
           (datum-subst-list (cdr elems) bindings))]))

;; ========================================
;; preparse-expand-form: expand a single datum
;; ========================================
;; Tries to match the head symbol against registered macros.
;; Loops until fixpoint or depth limit.
;; After expanding the head form, recursively expands subexpressions.
(define (preparse-expand-form datum [registry #f] [depth 0])
  (define reg (or registry (current-preparse-registry)))
  (cond
    [(> depth 100)
     (error 'preparse "Macro expansion depth limit exceeded (possible infinite loop)")]
    ;; Bare symbol — check if it's a registered macro (e.g., simple deftype alias)
    [(symbol? datum)
     (define entry (hash-ref reg datum #f))
     (cond
       [(procedure? entry)
        (define result (entry datum))
        (if (equal? result datum) datum
            (preparse-expand-form result reg (+ depth 1)))]
       [else datum])]
    ;; List form — check head symbol for macros
    [(and (pair? datum) (symbol? (car datum)))
     (define entry (hash-ref reg (car datum) #f))
     (cond
       [(preparse-macro? entry)
        ;; Pattern-template rewrite
        (define bindings (datum-match (preparse-macro-pattern entry) datum))
        (if bindings
            (preparse-expand-form
             (datum-subst (preparse-macro-template entry) bindings)
             reg (+ depth 1))
            ;; Pattern didn't match — still recurse into subexpressions
            (preparse-expand-subforms datum reg depth))]
       [(procedure? entry)
        ;; Built-in procedural macro
        (define result (entry datum))
        (if (equal? result datum)
            datum  ; no change, avoid infinite loop
            (preparse-expand-form result reg (+ depth 1)))]
       [else
        ;; Not a macro — recurse into subexpressions
        (preparse-expand-subforms datum reg depth)])]
    ;; Non-symbol list — recurse into subexpressions
    [(pair? datum)
     (preparse-expand-subforms datum reg depth)]
    [else datum]))

;; Recursively expand subexpressions of a list datum
;; Special handling for $pipe forms: group elements after -> into a single
;; sub-form so pre-parse macros (like let) see the correct structure.
(define (preparse-expand-subforms datum reg depth)
  (define grouped (maybe-group-pipe-body datum))
  (define expanded
    (map (lambda (sub) (preparse-expand-form sub reg depth))
         grouped))
  (if (equal? expanded grouped) datum expanded))

;; For $pipe forms (WS match arms), group body elements after -> into a single list.
;; ($pipe ctor args... -> e1 e2 e3) → ($pipe ctor args... -> (e1 e2 e3))
;; This ensures pre-parse macros like `let` see (let bindings body) correctly.
(define (maybe-group-pipe-body datum)
  (if (and (pair? datum) (eq? (car datum) '$pipe))
      (let ([arrow-idx (for/or ([x (in-list datum)] [i (in-naturals)])
                         (and (eq? x '->) i))])
        (if (and arrow-idx (> (length datum) (+ arrow-idx 2)))
            ;; Multiple body elements after -> : group them
            (let ([before-body (take datum (+ arrow-idx 1))]
                  [body-elems (drop datum (+ arrow-idx 1))])
              (append before-body (list body-elems)))
            ;; Single body element or no -> : leave as-is
            datum))
      datum))

;; ========================================
;; preparse-expand-all: process a list of syntax objects
;; ========================================
;; Handles defmacro and deftype forms (consumes them).
;; Expands all other forms.
;; Returns filtered list of syntax objects.
(define (preparse-expand-all stxs)
  (define result
    (for/fold ([acc '()])
              ([stx (in-list stxs)])
      (define datum (syntax->datum stx))
      (cond
        ;; ns — set namespace context and consume
        [(and (pair? datum) (eq? (car datum) 'ns))
         (process-ns-declaration datum)
         acc]
        ;; require — import module and consume
        [(and (pair? datum) (eq? (car datum) 'require))
         (process-require datum)
         acc]
        ;; provide — record exports and consume
        [(and (pair? datum) (eq? (car datum) 'provide))
         (process-provide datum)
         acc]
        ;; defmacro — register and consume
        [(and (pair? datum) (eq? (car datum) 'defmacro))
         (process-defmacro datum)
         acc]
        ;; deftype — register and consume
        [(and (pair? datum) (eq? (car datum) 'deftype))
         (process-deftype datum)
         acc]
        ;; data — generate type/constructor defs, inject into stream
        [(and (pair? datum) (eq? (car datum) 'data))
         (define defs (process-data datum))
         ;; Convert each def to a syntax object and add to accumulator
         (define new-stxs
           (for/list ([d (in-list defs)])
             (datum->syntax #f d stx)))
         (append (reverse new-stxs) acc)]
        ;; Regular form — expand
        [else
         (define expanded (preparse-expand-form datum))
         ;; If datum didn't change, preserve original syntax (keeps properties like paren-shape)
         (if (equal? expanded datum)
             (cons stx acc)
             (cons (datum->syntax #f expanded stx) acc))])))
  (reverse result))

;; ========================================
;; WS reader normalization for pattern variables
;; ========================================
;; The WS reader converts $X to ($quote X). For defmacro/deftype patterns
;; and templates, we need to convert these back to the $X symbol form.
(define (normalize-quote-vars datum)
  (cond
    ;; ($quote X) → $X
    [(and (list? datum) (= (length datum) 2)
          (eq? (car datum) '$quote) (symbol? (cadr datum)))
     (string->symbol (string-append "$" (symbol->string (cadr datum))))]
    ;; Recurse into lists
    [(list? datum)
     (map normalize-quote-vars datum)]
    ;; Pass through atoms
    [else datum]))

;; ========================================
;; process-defmacro: register a user macro
;; ========================================
;; (defmacro (name $param ...) template)
(define (process-defmacro datum)
  (unless (and (list? datum) (= (length datum) 3))
    (error 'defmacro "defmacro requires: (defmacro (name $params...) template)"))
  (define pattern (normalize-quote-vars (cadr datum)))
  (define template (normalize-quote-vars (caddr datum)))
  (unless (and (pair? pattern) (symbol? (car pattern)))
    (error 'defmacro "defmacro: first argument must be (name ...)"))
  (define macro-name (car pattern))
  (register-preparse-macro! macro-name (preparse-macro macro-name pattern template)))

;; ========================================
;; process-deftype: register a type alias
;; ========================================
;; (deftype Name body) — simple alias
;; (deftype (Name $A $B ...) body) — parameterized alias
(define (process-deftype datum)
  (unless (and (list? datum) (= (length datum) 3))
    (error 'deftype "deftype requires: (deftype name-or-pattern body)"))
  (define pattern (normalize-quote-vars (cadr datum)))
  (define body (normalize-quote-vars (caddr datum)))
  (cond
    [(symbol? pattern)
     ;; Simple alias: bare symbol expands to body
     ;; Register as procedural macro that ignores the input datum
     (register-preparse-macro! pattern (lambda (_) body))]
    [(pair? pattern)
     ;; Parameterized: (Name $A $B) body → pattern-template macro
     (define macro-name (car pattern))
     (register-preparse-macro! macro-name (preparse-macro macro-name pattern body))]
    [else
     (error 'deftype "deftype: expected name or (name params...) pattern")]))

;; ========================================
;; Built-in pre-parse macros
;; ========================================

;; let: sequential local bindings
;; NEW: (let [x <T> e1 y <T2> e2] body) → flat triples in bracket
;; OLD: (let ([x : T e] ...) body) → nested 4-element sub-lists
;; Both expand to: nested ((fn (x : T) ...) e) applications
(define (expand-let datum)
  (unless (and (list? datum) (= (length datum) 3))
    (error 'let "let requires: (let (bindings...) body)"))
  (define bindings-datum (cadr datum))
  (define body (caddr datum))
  (unless (list? bindings-datum)
    (error 'let "let: bindings must be a list"))
  (cond
    ;; Detect new flat format: first element is a symbol, second is ($angle-type ...)
    [(and (not (null? bindings-datum))
          (symbol? (car bindings-datum))
          (>= (length bindings-datum) 3)
          (let ([second (cadr bindings-datum)])
            (and (pair? second) (eq? (car second) '$angle-type))))
     ;; New flat triple format: [name ($angle-type T) expr ...]
     (define parsed-bindings (parse-let-flat-triples bindings-datum))
     (foldr (lambda (binding inner)
              (define name (car binding))
              (define type (cadr binding))
              (define value (caddr binding))
              `((fn (,name : ,type) ,inner) ,value))
            body
            parsed-bindings)]
    ;; Old nested format: ([x : T e] ...)
    [else
     (foldr (lambda (binding inner)
              (unless (and (list? binding) (= (length binding) 4))
                (error 'let "let: each binding must be (name : type value), got ~a" binding))
              (define name (car binding))
              ;; binding is (name : type value)
              (define type (caddr binding))
              (define value (cadddr binding))
              `((fn (,name : ,type) ,inner) ,value))
            body
            bindings-datum)]))

;; Parse flat triples from let binding list: name ($angle-type T) expr ...
;; Value tokens: everything after the type until the next binding (symbol ($angle-type ...))
;; or end of list. Multi-token values are wrapped as an application list.
(define (parse-let-flat-triples elems)
  (cond
    [(null? elems) '()]
    [(< (length elems) 3)
     (error 'let "let: incomplete binding triple, got ~a" elems)]
    [else
     (let* ([name (car elems)]
            [angle-form (cadr elems)]
            [_ (unless (symbol? name)
                 (error 'let "let: expected variable name, got ~a" name))]
            [_ (unless (and (pair? angle-form) (eq? (car angle-form) '$angle-type))
                 (error 'let "let: expected <type>, got ~a" angle-form))]
            [type (if (= (length (cdr angle-form)) 1)
                      (cadr angle-form)
                      (cdr angle-form))]
            [after-type (cddr elems)])
       (define-values (value-tokens rest)
         (split-at-next-binding after-type))
       (let ([value (if (= (length value-tokens) 1)
                        (car value-tokens)
                        value-tokens)])
         (cons (list name type value)
               (parse-let-flat-triples rest))))]))

;; Split a list at the start of the next binding (symbol followed by ($angle-type ...)).
;; Returns (values consumed-tokens remaining-tokens).
(define (split-at-next-binding elems)
  (let loop ([i 0] [rest elems])
    (cond
      [(null? rest)
       (values elems '())]
      [(and (> i 0)
            (>= (length rest) 2)
            (symbol? (car rest))
            (let ([next (cadr rest)])
              (and (pair? next) (eq? (car next) '$angle-type))))
       (values (take elems i) rest)]
      [else
       (loop (+ i 1) (cdr rest))])))

;; do: sequenced bindings
;; NEW: (do [x ($angle-type T) e1] [y ($angle-type T2) e2] body) → 3-element bindings
;; OLD: (do [x : T = e1] [y : T2 = e2] body) → 5-element bindings with =
;; Both expand to nested let
(define (expand-do datum)
  (unless (and (list? datum) (>= (length datum) 2))
    (error 'do "do requires at least a body"))
  (define parts (cdr datum))  ; everything after 'do
  (define body (last parts))
  (define bindings (drop-right parts 1))
  (if (null? bindings)
      body  ; no bindings, just the body
      (let ([let-bindings
             (for/list ([b (in-list bindings)])
               (cond
                 ;; NEW: (name ($angle-type T) value) — 3 elements
                 [(and (list? b) (= (length b) 3)
                       (pair? (cadr b)) (eq? (car (cadr b)) '$angle-type))
                  (define name (car b))
                  (define angle-form (cadr b))
                  (define type
                    (if (= (length (cdr angle-form)) 1)
                        (cadr angle-form)
                        (cdr angle-form)))
                  (list name ': type (caddr b))]
                 ;; OLD: (name : type = value) — 5 elements
                 [(and (list? b) (= (length b) 5))
                  (list (car b) (cadr b) (caddr b) (list-ref b 4))]
                 [else
                  (error 'do "do: each binding must be [name <type> value] or [name : type = value], got ~a" b)]))])
        `(let ,let-bindings ,body))))

;; if: boolean branching (requires boolrec in core)
;; (if ResultType cond then else) → (boolrec (the (-> Bool (Type 0)) (fn (_ : Bool) ResultType)) then else cond)
;; The motive must be annotated with `the` so boolrec can synthesize its type.
;; Note: The expansion uses old colon syntax internally since macros generate
;; internal forms that the parser's backward compatibility handles.
(define (expand-if datum)
  (unless (and (list? datum) (or (= (length datum) 4) (= (length datum) 5)))
    (error 'if "if requires: (if cond then else) or (if ResultType cond then else)"))
  (cond
    ;; Sprint 10: 3-arg form — (if cond then else), motive inferred via hole
    [(= (length datum) 4)
     (define cond-expr (list-ref datum 1))
     (define then-expr (list-ref datum 2))
     (define else-expr (list-ref datum 3))
     ;; Use `_` as motive — parser converts to surf-hole, boolrec wraps it,
     ;; type checker infers result type from checking context.
     `(boolrec _ ,then-expr ,else-expr ,cond-expr)]
    ;; 4-arg form — (if ResultType cond then else), backward compat
    [else
     (define result-type (list-ref datum 1))
     (define cond-expr (list-ref datum 2))
     (define then-expr (list-ref datum 3))
     (define else-expr (list-ref datum 4))
     ;; Use constant motive shorthand — the parser wraps bare types automatically.
     `(boolrec ,result-type ,then-expr ,else-expr ,cond-expr)]))

;; Register built-in pre-parse macros at module load time
(register-preparse-macro! 'let expand-let)
(register-preparse-macro! 'do expand-do)
(register-preparse-macro! 'if expand-if)


;; ========================================
;; Constructor metadata registry (for reduce)
;; ========================================
;; Stores metadata about each constructor so the type checker can
;; perform structural pattern matching from reduce arms.

;; ctor-meta: type-name, params, field-types, is-recursive flags, branch-index
(struct ctor-meta (type-name params field-types is-recursive branch-index) #:transparent)

;; Registry: ctor-name (symbol) → ctor-meta
(define current-ctor-registry (make-parameter (hasheq)))

;; Type metadata: type-name (symbol) → (list ctor-names-in-order)
(define current-type-meta (make-parameter (hasheq)))

(define (register-ctor! name meta)
  (current-ctor-registry (hash-set (current-ctor-registry) name meta)))

(define (lookup-ctor name)
  (hash-ref (current-ctor-registry) name #f))

(define (lookup-type-ctors type-name)
  (hash-ref (current-type-meta) type-name #f))

;; ========================================
;; Built-in constructor metadata (Nat, Bool)
;; ========================================
;; Register Nat and Bool constructors so match/reduce works on them.
;; These are built-in types with no type parameters.

;; Nat: zero (nullary), inc (one recursive Nat field)
(register-ctor! 'zero (ctor-meta 'Nat '() '() '() 0))
(register-ctor! 'inc  (ctor-meta 'Nat '() (list 'Nat) (list #t) 1))
(current-type-meta (hash-set (current-type-meta) 'Nat '(zero inc)))

;; Bool: true (nullary), false (nullary)
(register-ctor! 'true  (ctor-meta 'Bool '() '() '() 0))
(register-ctor! 'false (ctor-meta 'Bool '() '() '() 1))
(current-type-meta (hash-set (current-type-meta) 'Bool '(true false)))

;; ========================================
;; process-data: algebraic data types with native constructors
;; ========================================
;; Syntax:
;;   (data TypeName ctor1 (Ctor2 field2 ...) ...)                     — no params
;;   (data (TypeName (A : T1) ...) ctor1 (Ctor2 field2 ...) ...)     — with params
;;
;; WS syntax (after reader):
;;   (data TypeName ctor1 (Ctor2 ($angle-type f1) ...) ...)           — no params
;;   (data (TypeName A ($angle-type T1) ...) ctor1 (Ctor2 ...))      — with params
;;
;; Constructors can be bare symbols (nullary) or (Name fields...).
;;
;; Generates opaque definitions (bodies are placeholders, never evaluated):
;;   - Type definition: TypeName with type annotation (Type 0)
;;   - Constructor definitions: each with type annotation only
;;   - Constructor metadata: registered for structural pattern matching
;;
;; Returns: list of s-expression datums (def type-name ...) (def ctor1 ...) ...

;; Parse data parameter list from WS or sexp syntax
;; WS: (TypeName A ($angle-type (Type 0)) B ($angle-type (Type 0)) ...)
;; Sexp: (TypeName (A : (Type 0)) (B : (Type 0)) ...)
;; Returns: (values type-name params) where params is ((name . type) ...)
(define (parse-data-params head-datum)
  (cond
    ;; Bare symbol: no params
    [(symbol? head-datum)
     (values head-datum '())]
    ;; List: (TypeName params...)
    [(pair? head-datum)
     (define type-name (car head-datum))
     (unless (symbol? type-name)
       (error 'data "data: type name must be a symbol, got ~a" type-name))
     (define raw-params (cdr head-datum))
     ;; Parse params — try WS format first, then sexp format
     (define params (parse-data-param-list raw-params))
     (values type-name params)]
    [else
     (error 'data "data: expected type name or (type-name params...), got ~a" head-datum)]))

;; Parse parameter list in WS or sexp format
;; NEW: ($brace-params A B C) — implicit type params, all get type (Type 0)
;; WS: (A ($angle-type (Type 0)) B ($angle-type (Type 0)) ...)
;; Sexp: ((A : (Type 0)) (B : (Type 0)) ...)
(define (parse-data-param-list raw)
  (cond
    [(null? raw) '()]
    ;; NEW: ($brace-params A B C) — single element containing all params
    [(and (= (length raw) 1)
          (pair? (car raw))
          (list? (car raw))
          (>= (length (car raw)) 2)
          (eq? (car (car raw)) '$brace-params))
     (define symbols (cdr (car raw)))
     (for/list ([s (in-list symbols)])
       (unless (symbol? s)
         (error 'data "data: implicit type parameter must be a symbol, got ~a" s))
       (cons s '(Type 0)))]
    ;; WS format: name ($angle-type Type) name ($angle-type Type) ...
    [(and (symbol? (car raw))
          (>= (length raw) 2)
          (let ([second (cadr raw)])
            (and (pair? second) (eq? (car second) '$angle-type))))
     (define name (car raw))
     (define type (cadr (cadr raw)))  ;; extract from ($angle-type T)
     (cons (cons name type)
           (parse-data-param-list (cddr raw)))]
    ;; WS format with multiplicity: name :0 ($angle-type Type) ...
    [(and (symbol? (car raw))
          (>= (length raw) 3)
          (memq (cadr raw) '(:0 :1 :w))
          (let ([third (caddr raw)])
            (and (pair? third) (eq? (car third) '$angle-type))))
     (define name (car raw))
     ;; multiplicity ignored for params (always :0 for type params)
     (define type (cadr (caddr raw)))
     (cons (cons name type)
           (parse-data-param-list (cdddr raw)))]
    ;; Sexp format: (A : (Type 0)) ...
    [(and (pair? (car raw))
          (list? (car raw))
          (>= (length (car raw)) 3)
          (eq? (cadr (car raw)) ':))
     (define binding (car raw))
     (define name (car binding))
     (define type (caddr binding))
     (cons (cons name type)
           (parse-data-param-list (cdr raw)))]
    ;; WS bracket format: (A ($angle-type (Type 0))) as a sub-list
    ;; This happens when [A <(Type 0)>] is used inside parens
    [(and (pair? (car raw))
          (list? (car raw))
          (>= (length (car raw)) 2)
          (symbol? (car (car raw)))
          (let ([second (cadr (car raw))])
            (and (pair? second) (eq? (car second) '$angle-type))))
     (define binding (car raw))
     (define name (car binding))
     (define type (cadr (cadr binding)))
     (cons (cons name type)
           (parse-data-param-list (cdr raw)))]
    ;; WS bracket format with multiplicity: (A :0 ($angle-type (Type 0))) as sub-list
    [(and (pair? (car raw))
          (list? (car raw))
          (>= (length (car raw)) 3)
          (symbol? (car (car raw)))
          (memq (cadr (car raw)) '(:0 :1 :w))
          (let ([third (caddr (car raw))])
            (and (pair? third) (eq? (car third) '$angle-type))))
     (define binding (car raw))
     (define name (car binding))
     (define type (cadr (caddr binding)))
     (cons (cons name type)
           (parse-data-param-list (cdr raw)))]
    [else
     (error 'data "data: unexpected parameter format: ~a" raw)]))

;; Parse a constructor declaration
;; NEW: (CtorName : T1 -> T2 -> ... -> ResultType) — colon-based (field types only)
;; WS: bare symbol (nullary), (CtorName ($angle-type T1) ...) (with fields)
;; Sexp: (CtorName field1 field2 ...) or (CtorName) for nullary
;; Returns: (cons name (list field-types...))
(define (parse-data-ctor raw)
  (cond
    ;; Bare symbol: nullary constructor (e.g., none, lt-ord)
    [(symbol? raw)
     (cons raw '())]
    ;; List: (CtorName fields...)
    [(and (pair? raw) (symbol? (car raw)))
     (define name (car raw))
     (define rest (cdr raw))
     (cond
       ;; NEW: colon-based syntax: (CtorName : T1 -> T2 -> ...)
       ;; The return type (last segment) is implicit (always the data type itself)
       ;; so we treat all-but-last segments as field types
       [(and (not (null? rest))
             (eq? (car rest) ':))
        (define type-atoms (cdr rest)) ;; everything after ':'
        (when (null? type-atoms)
          (error 'data "data constructor ~a: missing type after ':'" name))
        ;; Split on -> to get segments
        ;; ALL segments are field types (return type is implicit — always the data type)
        (define segments (split-on-arrow-datum type-atoms))
        (define fields
          (map (lambda (seg)
                 (if (= (length seg) 1)
                     (car seg)  ;; single atom: e.g., A
                     seg))      ;; multi-atom: e.g., (List A) — left as-is for now
               segments))
        (cons name fields)]
       ;; EXISTING: angle-bracket or bare fields
       [else
        (define fields
          (map (lambda (f)
                 (if (and (pair? f) (eq? (car f) '$angle-type))
                     (cadr f)   ;; WS: ($angle-type T) → T
                     f))        ;; Sexp: bare T
               rest))
        (cons name fields)])]
    [else
     (error 'data "data: constructor must be (Name fields...) or a bare symbol, got ~a" raw)]))

;; Split a flat list of atoms on the '-> symbol (datum-level, not syntax).
;; Returns a list of lists (segments between arrows).
(define (split-on-arrow-datum atoms)
  (let loop ([remaining atoms] [current '()] [result '()])
    (cond
      [(null? remaining)
       (reverse (cons (reverse current) result))]
      [(eq? (car remaining) '->)
       (loop (cdr remaining) '() (cons (reverse current) result))]
      [else
       (loop (cdr remaining) (cons (car remaining) current) result)])))

;; Build a nested -> type from a list of domains and a codomain
;; (build-arrow-type '(A B C) 'R) → (-> A (-> B (-> C R)))
(define (build-arrow-type domains codomain)
  (foldr (lambda (dom rest) `(-> ,dom ,rest)) codomain domains))

;; Build nested (fn ...) from bindings: ((name mult type) ...) and a body
;; Each binding is (name multiplicity type-expr)
(define (build-nested-fn bindings body)
  (foldr (lambda (bnd rest)
           (define name (car bnd))
           (define mult (cadr bnd))
           (define type (caddr bnd))
           `(fn (,name ,mult ,type) ,rest))
         body bindings))

;; Build nested (Pi ...) from bindings
(define (build-nested-pi bindings body)
  (foldr (lambda (bnd rest)
           (define name (car bnd))
           (define mult (cadr bnd))
           (define type (caddr bnd))
           `(Pi (,name ,mult ,type) ,rest))
         body bindings))

;; Check if a field type is a self-reference to the type being defined
;; Matches bare TypeName (no params) or (TypeName A B ...) with exact param names
(define (self-reference? field-type type-name params)
  (cond
    ;; Bare name with no params: e.g., MyType when defining (data MyType ...)
    [(and (symbol? field-type) (eq? field-type type-name) (null? params)) #t]
    ;; Applied name: e.g., (List A) when defining (data (List (A : (Type 0))) ...)
    [(and (pair? field-type)
          (eq? (car field-type) type-name)
          (= (length (cdr field-type)) (length params))
          (andmap (lambda (arg param)
                    (and (symbol? arg) (eq? arg (car param))))
                  (cdr field-type) params))
     #t]
    [else #f]))

;; Main data processing function
;; Returns a list of s-expression datums: ((def ...) (def ...) ...)
(define (process-data datum)
  (unless (and (list? datum) (>= (length datum) 2))
    (error 'data "data requires: (data TypeName-or-(TypeName params...) ctor1 ctor2 ...)"))

  ;; NEW: detect (data TypeName {A B} ctor1 ctor2 ...) — brace-params after bare type name
  ;; In WS mode: (data Maybe ($brace-params A) nothing ...)
  ;; In sexp mode: (data Maybe ($brace-params A) (nothing) (just A))
  (define-values (type-name params raw-ctors)
    (let ([head (cadr datum)]
          [rest (cddr datum)])
      (cond
        ;; NEW: bare symbol followed by ($brace-params ...)
        [(and (symbol? head)
              (not (null? rest))
              (let ([maybe-braces (car rest)])
                (and (pair? maybe-braces)
                     (eq? (car maybe-braces) '$brace-params))))
         (define brace-element (car rest))
         (define symbols (cdr brace-element))
         (define brace-params
           (for/list ([s (in-list symbols)])
             (unless (symbol? s)
               (error 'data "data: implicit type parameter must be a symbol, got ~a" s))
             (cons s '(Type 0))))
         (values head brace-params (cdr rest))]
        ;; EXISTING: parse head normally
        [else
         (define-values (tn ps) (parse-data-params head))
         (values tn ps rest)])))

  (when (null? raw-ctors)
    (error 'data "data ~a: must have at least one constructor" type-name))

  (define ctors (map parse-data-ctor raw-ctors))
  ;; ctors = ((name . (field-types ...)) ...)

  ;; ---- Generate the type definition ----

  ;; Type params as Pi bindings (all :0)
  (define param-pi-bindings
    (for/list ([p (in-list params)])
      (list (car p) ':0 (cdr p))))

  ;; Type type: param-types -> (Type 0)
  ;; User-defined types are opaque (non-unfolding fvars) and live at Type 0,
  ;; matching built-in types (Nat, Bool). The body is a placeholder —
  ;; driver.rkt stores these with value=#f (never evaluated at runtime).
  (define type-type
    (if (null? params)
        '(Type 0)
        (build-nested-pi
         param-pi-bindings
         '(Type 0))))

  ;; Body placeholder — never elaborated or evaluated (driver.rkt skips
  ;; body processing for data type definitions and stores value=#f).
  (define type-body '(Type 0))

  ;; The type def
  (define type-def
    `(def ,type-name : ,type-type ,type-body))

  ;; ---- Generate constructor definitions ----
  ;; Type: Pi(A :0 T_A) ... -> T1 -> T2 -> ... -> (TypeName A B ...)
  ;; Body: placeholder (never evaluated — constructors are opaque fvars)

  ;; Applied type: (TypeName A B ...) or just TypeName if no params
  (define applied-type-name
    (if (null? params)
        type-name
        `(,type-name ,@(map car params))))

  (define ctor-defs
    (for/list ([ctor (in-list ctors)]
               [i (in-naturals)])
      (define ctor-name (car ctor))
      (define field-types (cdr ctor))

      ;; Constructor type:
      ;; Pi(A :0 T_A) ... -> T1 -> T2 -> ... -> (TypeName A B ...)
      (define ctor-result-type applied-type-name)
      (define ctor-type
        (build-nested-pi
         param-pi-bindings
         (build-arrow-type field-types ctor-result-type)))

      ;; Body placeholder — never elaborated or evaluated
      (define full-body '(Type 0))

      `(def ,ctor-name : ,ctor-type ,full-body)))

  ;; Register constructor metadata for reduce
  (current-type-meta
   (hash-set (current-type-meta) type-name
             (map car ctors)))

  (for ([ctor (in-list ctors)]
        [i (in-naturals)])
    (define ctor-name (car ctor))
    (define field-types (cdr ctor))
    (define rec-flags
      (map (lambda (ft) (self-reference? ft type-name params)) field-types))
    (register-ctor! ctor-name
                    (ctor-meta type-name params field-types rec-flags i)))

  ;; Return all definitions
  (cons type-def ctor-defs))


;; ================================================================
;; LAYER 2: POST-PARSE MACRO SYSTEM
;; ================================================================

;; ========================================
;; Post-parse macro registry (for surf-* transforms)
;; ========================================
;; Maps symbol → (surf-form → surf-form) procedure
(define current-macro-registry (make-parameter (hasheq)))

(define (register-macro! name proc)
  (current-macro-registry
   (hash-set (current-macro-registry) name proc)))

(define (lookup-macro name)
  (hash-ref (current-macro-registry) name #f))

;; ========================================
;; Top-level command predicate
;; ========================================
(define (top-level-command? surf)
  (or (surf-def? surf)
      (surf-defn? surf)
      (surf-check? surf)
      (surf-eval? surf)
      (surf-infer? surf)))

;; ========================================
;; Collect all surf-var names from a surface type AST
;; ========================================
;; Walks a type-level surface AST and returns a list of symbol names
;; in left-to-right first-appearance order (deduplicated).
;; Used by infer-auto-implicits to find free type variables.
(define (collect-surf-vars type-ast)
  (define seen (make-hasheq))
  (define result '())
  (define (add! name)
    (unless (hash-ref seen name #f)
      (hash-set! seen name #t)
      (set! result (cons name result))))
  (define (walk ast)
    (match ast
      [(surf-var name _loc) (add! name)]
      [(surf-pi binder body _loc)
       (let ([btype (binder-info-type binder)])
         (when btype (walk btype)))
       (walk body)]
      [(surf-arrow domain codomain _loc)
       (walk domain)
       (walk codomain)]
      [(surf-sigma binder body _loc)
       (let ([btype (binder-info-type binder)])
         (when btype (walk btype)))
       (walk body)]
      [(surf-app func args _loc)
       (walk func)
       (for-each walk args)]
      [(surf-eq type lhs rhs _loc)
       (walk type) (walk lhs) (walk rhs)]
      [(surf-vec-type elem-type length _loc)
       (walk elem-type) (walk length)]
      [(surf-fin-type bound _loc)
       (walk bound)]
      [(surf-ann type term _loc)
       (walk type) (walk term)]
      [(surf-suc pred _loc)
       (walk pred)]
      ;; Terminal nodes that are not variable references — skip
      [(surf-hole _) (void)]
      [(surf-type _ _) (void)]
      [(surf-nat-type _) (void)]
      [(surf-bool-type _) (void)]
      [(surf-posit8-type _) (void)]
      [(surf-zero _) (void)]
      [(surf-true _) (void)]
      [(surf-false _) (void)]
      [(surf-refl _) (void)]
      [(surf-nat-lit _ _) (void)]
      ;; Catch-all for any unhandled nodes
      [_ (void)]))
  (walk type-ast)
  (reverse result))

;; ========================================
;; Auto-implicit type parameter inference
;; ========================================

;; Built-in type/constructor names that should never become auto-implicits.
;; These are symbols recognized by parse-symbol in parser.rkt.
(define builtin-names
  '(Nat Bool Type Posit8 zero true false refl inc
    Pi Sigma Eq Vec Fin natrec boolrec J pair fst snd
    vnil vcons vhead vtail vindex fzero fsuc
    posit8 p8+ p8- p8* p8/ p8-neg p8-abs p8-sqrt p8< p8<= p8-from-nat p8-if-nar))

;; Check if a symbol is a "known name" — should NOT be treated as a free type variable.
(define (known-name? name)
  (or (memq name builtin-names)
      (global-env-lookup-type name)                      ;; previously defined def/defn
      (hash-ref (current-ctor-registry) name #f)         ;; data constructor
      (hash-ref (current-type-meta) name #f)             ;; data type name
      (hash-ref (current-preparse-registry) name #f)))   ;; deftype alias / macro

;; Detect if a surf-defn already has explicit implicit params (from {A B} syntax).
;; If the first Pi binder has mult='m0 and type=(surf-type ...) and its name
;; matches the first param-name, then the parser already inserted implicits.
(define (has-leading-implicits? type-ast param-names)
  (and (not (null? param-names))
       (match type-ast
         [(surf-pi (binder-info bname 'm0 (surf-type _ _)) _body _loc)
          (eq? bname (car param-names))]
         [_ #f])))

;; Infer auto-implicit type parameters for a surf-defn.
;; If the defn already has explicit implicits, returns unchanged.
;; Otherwise, finds free type variables in the type signature and
;; prepends them as implicit (m0) parameters of type Type (level inferred).
(define (infer-auto-implicits form)
  (match form
    [(surf-defn name type-ast param-names body-ast loc)
     (cond
       ;; Already has explicit {A B} — skip
       [(has-leading-implicits? type-ast param-names) form]
       [else
        (define all-vars (collect-surf-vars type-ast))
        ;; Filter out: param names, known names
        (define free-vars
          (filter (lambda (v)
                    (and (not (memq v param-names))
                         (not (known-name? v))))
                  all-vars))
        (cond
          [(null? free-vars) form]
          [else
           ;; Build implicit binders
           (define implicit-binders
             (map (lambda (v) (binder-info v 'm0 (surf-type #f loc)))
                  free-vars))
           ;; Prepend Pi binders to type-ast
           (define new-type-ast
             (foldr (lambda (bnd rest) (surf-pi bnd rest loc))
                    type-ast
                    implicit-binders))
           ;; Prepend names to param-names
           (define new-param-names (append free-vars param-names))
           (surf-defn name new-type-ast new-param-names body-ast loc)])])]
    [_ form]))

;; ========================================
;; Extract Pi binders from a surface type AST
;; ========================================
;; Walks the type to collect the chain of Pi/arrow binders.
;; Returns a list of binder-info structs.
(define (extract-pi-binders type-ast)
  (match type-ast
    [(surf-pi binder body _loc)
     (cons binder (extract-pi-binders body))]
    [(surf-arrow domain codomain _loc)
     ;; Non-dependent arrow: generate anonymous binder
     (cons (binder-info '_ 'mw domain)
           (extract-pi-binders codomain))]
    [_ '()]))

;; ========================================
;; Desugar defn → def + nested fn
;; ========================================
(define (desugar-defn form)
  (match form
    [(surf-defn name type-ast param-names body-ast loc)
     (define all-binders (extract-pi-binders type-ast))
     (define n-params (length param-names))
     (define n-binders (length all-binders))
     (cond
       [(> n-params n-binders)
        (prologos-error
         loc
         (format "defn ~a: parameter list has ~a names but type has only ~a binders"
                 name n-params n-binders))]
       [else
        ;; Take only as many binders as there are parameter names.
        ;; The remaining Pi binders are part of the return type
        ;; (e.g. defn f [x : Nat] <Nat -> Nat> ... has return type Nat -> Nat).
        (define binders (take all-binders n-params))
        (define named-binders
          (for/list ([pname (in-list param-names)]
                     [bnd (in-list binders)])
            (binder-info pname (binder-info-mult bnd) (binder-info-type bnd))))
        (define nested-lam
          (foldr (lambda (bnd inner)
                   (surf-lam bnd inner loc))
                 body-ast
                 named-binders))
        (surf-def name type-ast nested-lam loc)])]))

;; ========================================
;; Desugar the-fn → the + nested fn
;; ========================================
;; (the-fn type [params...] body) → (the type (fn (p1:T1) (fn (p2:T2) ... body)))
(define (desugar-the-fn form)
  (match form
    [(surf-the-fn type-ast param-names body-ast loc)
     (define all-binders (extract-pi-binders type-ast))
     (define n-params (length param-names))
     (define n-binders (length all-binders))
     (cond
       [(> n-params n-binders)
        (prologos-error
         loc
         (format "the-fn: parameter list has ~a names but type has only ~a binders"
                 n-params n-binders))]
       [else
        ;; Take only as many binders as there are parameter names
        (define binders (take all-binders n-params))
        (define named-binders
          (for/list ([pname (in-list param-names)]
                     [bnd (in-list binders)])
            (binder-info pname (binder-info-mult bnd) (binder-info-type bnd))))
        (define nested-lam
          (foldr (lambda (bnd inner)
                   (surf-lam bnd inner loc))
                 body-ast
                 named-binders))
        (surf-ann type-ast nested-lam loc)])]))

;; ========================================
;; Expand expressions (walk sub-expressions for the-fn)
;; ========================================
(define (expand-expression surf)
  (match surf
    ;; the-fn — desugar
    [(surf-the-fn _ _ _ _)
     (define result (desugar-the-fn surf))
     (if (prologos-error? result) result (expand-expression result))]
    ;; Walk sub-expressions
    [(surf-app fn args loc)
     (surf-app (expand-expression fn) (map expand-expression args) loc)]
    [(surf-lam binder body loc)
     (surf-lam binder (expand-expression body) loc)]
    [(surf-ann type term loc)
     (surf-ann (expand-expression type) (expand-expression term) loc)]
    [(surf-pair e1 e2 loc)
     (surf-pair (expand-expression e1) (expand-expression e2) loc)]
    [(surf-fst e loc)
     (surf-fst (expand-expression e) loc)]
    [(surf-snd e loc)
     (surf-snd (expand-expression e) loc)]
    [(surf-suc e loc)
     (surf-suc (expand-expression e) loc)]
    [(surf-pi binder body loc)
     (surf-pi binder (expand-expression body) loc)]
    [(surf-arrow dom cod loc)
     (surf-arrow (expand-expression dom) (expand-expression cod) loc)]
    [(surf-sigma binder body loc)
     (surf-sigma binder (expand-expression body) loc)]
    [(surf-eq type lhs rhs loc)
     (surf-eq (expand-expression type) (expand-expression lhs) (expand-expression rhs) loc)]
    [(surf-natrec mot base step target loc)
     (surf-natrec (expand-expression mot) (expand-expression base)
                  (expand-expression step) (expand-expression target) loc)]
    [(surf-boolrec mot tc fc target loc)
     (surf-boolrec (expand-expression mot) (expand-expression tc)
                   (expand-expression fc) (expand-expression target) loc)]
    [(surf-J mot base left right proof loc)
     (surf-J (expand-expression mot) (expand-expression base)
             (expand-expression left) (expand-expression right)
             (expand-expression proof) loc)]
    ;; Reduce — walk scrutinee and arm bodies
    [(surf-reduce scrutinee arms loc)
     (surf-reduce (expand-expression scrutinee)
                  (map (lambda (arm)
                         (reduce-arm (reduce-arm-ctor-name arm)
                                     (reduce-arm-bindings arm)
                                     (expand-expression (reduce-arm-body arm))
                                     (reduce-arm-srcloc arm)))
                       arms)
                  loc)]
    ;; Leaf forms — pass through
    [_ surf]))

;; ========================================
;; Expand a top-level form (post-parse)
;; ========================================
;; Applies macro expansion, expression-level expansion, and implicit eval.
;; Returns a surf-def, surf-check, surf-eval, or surf-infer.
(define (expand-top-level surf [depth 0])
  (cond
    [(> depth 100)
     (prologos-error
      srcloc-unknown
      "Macro expansion depth limit exceeded (possible infinite loop)")]
    ;; Built-in: defn desugaring (with auto-implicit inference)
    [(surf-defn? surf)
     (define with-implicits (infer-auto-implicits surf))
     (define result (desugar-defn with-implicits))
     (if (prologos-error? result)
         result
         (expand-top-level result (+ depth 1)))]
    ;; Already a top-level command — expand sub-expressions, then pass through
    [(surf-def? surf)
     (surf-def (surf-def-name surf)
               ;; Sprint 10: type may be #f for type-inferred defs
               (let ([ty (surf-def-type surf)])
                 (if ty (expand-expression ty) #f))
               (expand-expression (surf-def-body surf))
               (surf-def-srcloc surf))]
    [(surf-check? surf)
     (surf-check (expand-expression (surf-check-expr surf))
                 (expand-expression (surf-check-type surf))
                 (surf-check-srcloc surf))]
    [(surf-eval? surf)
     (surf-eval (expand-expression (surf-eval-expr surf))
                (surf-eval-srcloc surf))]
    [(surf-infer? surf)
     (surf-infer (expand-expression (surf-infer-expr surf))
                 (surf-infer-srcloc surf))]
    ;; Bare expression — implicit eval
    [else
     (define loc (cond
                   [(surf-var? surf) (surf-var-srcloc surf)]
                   [(surf-app? surf) (surf-app-srcloc surf)]
                   [(surf-ann? surf) (surf-ann-srcloc surf)]
                   [else srcloc-unknown]))
     (surf-eval (expand-expression surf) loc)]))
