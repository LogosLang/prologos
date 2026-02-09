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
         "namespace.rkt")

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
(define (preparse-expand-subforms datum reg depth)
  (define expanded
    (map (lambda (sub) (preparse-expand-form sub reg depth))
         datum))
  (if (equal? expanded datum) datum expanded))

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
        ;; data — generate Church-encoded defs, inject into stream
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
;; process-defmacro: register a user macro
;; ========================================
;; (defmacro (name $param ...) template)
(define (process-defmacro datum)
  (unless (and (list? datum) (= (length datum) 3))
    (error 'defmacro "defmacro requires: (defmacro (name $params...) template)"))
  (define pattern (cadr datum))
  (define template (caddr datum))
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
  (define pattern (cadr datum))
  (define body (caddr datum))
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
(define (parse-let-flat-triples elems)
  (cond
    [(null? elems) '()]
    [(< (length elems) 3)
     (error 'let "let: incomplete binding triple, got ~a" elems)]
    [else
     (define name (car elems))
     (define angle-form (cadr elems))
     (define value (caddr elems))
     (unless (symbol? name)
       (error 'let "let: expected variable name, got ~a" name))
     (unless (and (pair? angle-form) (eq? (car angle-form) '$angle-type))
       (error 'let "let: expected <type>, got ~a" angle-form))
     ;; Extract the type from ($angle-type content)
     (define type
       (if (= (length (cdr angle-form)) 1)
           (cadr angle-form)  ; single element: ($angle-type Nat) → Nat
           (cdr angle-form))) ; multiple: ($angle-type -> Nat Nat) → (-> Nat Nat) -- shouldn't happen with reader
     (cons (list name type value)
           (parse-let-flat-triples (cdddr elems)))]))

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
  (unless (and (list? datum) (= (length datum) 5))
    (error 'if "if requires: (if ResultType cond then else)"))
  (define result-type (list-ref datum 1))
  (define cond-expr (list-ref datum 2))
  (define then-expr (list-ref datum 3))
  (define else-expr (list-ref datum 4))
  ;; Use constant motive shorthand — the parser wraps bare types automatically.
  `(boolrec ,result-type ,then-expr ,else-expr ,cond-expr))

;; match: pattern matching on Church-encoded ADTs
;; WS format (from reader):
;;   (match scrutinee ($angle-type ResultType)
;;          (ctor1 body1)                               — nullary ctor
;;          (ctor2 (x ($angle-type T)) body2) ...)      — ctor with field bindings
;;
;; Sexp format:
;;   (match scrutinee ResultType
;;          (ctor1 body1)
;;          (ctor2 (x : T) body2) ...)
;;
;; Desugars to Church-encoded application:
;;   (scrutinee ResultType branch1 branch2 ...)
;; where branch_i is:
;;   body                        for nullary constructors
;;   (fn (x : T) body)           for constructors with one field
;;   (fn (x : T) (fn (y : U) body))  for constructors with multiple fields
;;
;; Approach 1 from the plan: require type annotations in patterns.
;; [x <T>] in WS becomes (x ($angle-type T)), parsed as a binding.
;; (x : T) in sexp also works directly.

(define (expand-match datum)
  (unless (and (list? datum) (>= (length datum) 4))
    (error 'match "match requires: (match scrutinee <ResultType> branch1 branch2 ...)"))

  (define scrutinee (cadr datum))
  (define result-type-raw (caddr datum))
  ;; Unwrap $angle-type if present (WS: ($angle-type T) → T)
  (define result-type
    (if (and (pair? result-type-raw)
             (eq? (car result-type-raw) '$angle-type))
        (cadr result-type-raw)
        result-type-raw))

  (define raw-branches (cdddr datum))
  (when (null? raw-branches)
    (error 'match "match requires at least one branch"))

  ;; Parse each branch: (ctor-name [bindings...] body)
  ;; Bindings are optional; body is the last element
  ;; Returns the branch expression (either body or nested fn wrapping body)
  (define branch-exprs
    (for/list ([branch (in-list raw-branches)])
      (unless (and (pair? branch) (symbol? (car branch)) (>= (length branch) 2))
        (error 'match "match: each branch must be (CtorName [bindings...] body), got ~a" branch))
      (define ctor-name (car branch))
      (define rest (cdr branch))
      ;; rest is either: (body) for nullary, or ((x ($angle-type T)) ... body) for fields
      ;; The body is always the last element
      (define body (last rest))
      (define raw-bindings (drop-right rest 1))

      (if (null? raw-bindings)
          ;; Nullary constructor: branch = body
          body
          ;; Constructor with fields: wrap body in nested fn
          (foldr
           (lambda (binding inner)
             (cond
               ;; WS format: (x ($angle-type T))
               [(and (list? binding) (= (length binding) 2)
                     (symbol? (car binding))
                     (pair? (cadr binding))
                     (eq? (car (cadr binding)) '$angle-type))
                (define name (car binding))
                (define type (cadr (cadr binding)))
                `(fn (,name : ,type) ,inner)]
               ;; Sexp format: (x : T)
               [(and (list? binding) (>= (length binding) 3)
                     (symbol? (car binding))
                     (eq? (cadr binding) ':))
                (define name (car binding))
                (define type (caddr binding))
                `(fn (,name : ,type) ,inner)]
               [else
                (error 'match "match: invalid binding in branch ~a, expected [x <T>] or (x : T), got ~a"
                       ctor-name binding)]))
           body
           raw-bindings))))

  ;; Generate: (scrutinee ResultType branch1 branch2 ...)
  `(,scrutinee ,result-type ,@branch-exprs))

;; Register built-in pre-parse macros at module load time
(register-preparse-macro! 'let expand-let)
(register-preparse-macro! 'do expand-do)
(register-preparse-macro! 'if expand-if)
(register-preparse-macro! 'match expand-match)


;; ========================================
;; process-data: Church-encoded algebraic data types
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
;; Generates Church-encoded definitions:
;;   - Type definition: TypeName as a function returning a Pi type
;;   - Constructor definitions: each constructor as a lambda
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
;; WS: (A ($angle-type (Type 0)) B ($angle-type (Type 0)) ...)
;; Sexp: ((A : (Type 0)) (B : (Type 0)) ...)
(define (parse-data-param-list raw)
  (cond
    [(null? raw) '()]
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
     (define raw-fields (cdr raw))
     (define fields
       (map (lambda (f)
              (if (and (pair? f) (eq? (car f) '$angle-type))
                  (cadr f)   ;; WS: ($angle-type T) → T
                  f))        ;; Sexp: bare T
            raw-fields))
     (cons name fields)]
    [else
     (error 'data "data: constructor must be (Name fields...) or a bare symbol, got ~a" raw)]))

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

;; Main data processing function
;; Returns a list of s-expression datums: ((def ...) (def ...) ...)
(define (process-data datum)
  (unless (and (list? datum) (>= (length datum) 2))
    (error 'data "data requires: (data TypeName-or-(TypeName params...) ctor1 ctor2 ...)"))

  (define-values (type-name params)
    (parse-data-params (cadr datum)))
  (define raw-ctors (cddr datum))

  (when (null? raw-ctors)
    (error 'data "data ~a: must have at least one constructor" type-name))

  (define ctors (map parse-data-ctor raw-ctors))
  ;; ctors = ((name . (field-types ...)) ...)

  ;; Number of constructors
  (define n-ctors (length ctors))

  ;; Generate fresh names for constructor branch parameters
  ;; Each branch parameter corresponds to a constructor's elimination branch
  (define branch-names
    (for/list ([ctor (in-list ctors)]
               [i (in-naturals)])
      (string->symbol (format "~a~a" "branch" i))))

  ;; ---- Generate the type definition ----
  ;; Church encoding: TypeName A B ... = Pi(R : (Type 0)). branch1-type -> branch2-type -> ... -> R
  ;; where branch_i-type = field1 -> field2 -> ... -> R

  ;; Type params as Pi bindings (all :0)
  (define param-pi-bindings
    (for/list ([p (in-list params)])
      (list (car p) ':0 (cdr p))))

  ;; The R parameter — use a name unlikely to clash with user names
  (define r-name '__R)

  ;; Build branch types: for each constructor, the type of its branch
  ;; (field1 -> field2 -> ... -> R)
  (define branch-types
    (for/list ([ctor (in-list ctors)])
      (define field-types (cdr ctor))
      (build-arrow-type field-types r-name)))

  ;; Full Church-encoded type body (inside the param lambdas):
  ;; Pi(R : (Type 0)). branch1-type -> branch2-type -> ... -> R
  ;; R ranges over (Type 0) for small elimination.
  ;; Combinators returning Church-encoded types use delegation instead.
  (define church-body
    `(Pi (,r-name :0 (Type 0))
         ,(build-arrow-type branch-types r-name)))

  ;; Type body with param lambdas
  (define type-body
    (build-nested-fn
     (for/list ([p (in-list params)])
       (list (car p) ':0 (cdr p)))
     church-body))

  ;; Type type: param-types -> (Type 1)
  ;; Church encoding lives in (Type 1) because it quantifies over R : (Type 0)
  (define type-type
    (if (null? params)
        '(Type 1)
        (build-nested-pi
         param-pi-bindings
         '(Type 1))))

  ;; The type def
  (define type-def
    `(def ,type-name : ,type-type ,type-body))

  ;; ---- Generate constructor definitions ----
  ;; For constructor i with fields f1:T1 f2:T2 ...:
  ;; Type: Pi(A :0 T_A) ... -> T1 -> T2 -> ... -> (TypeName A B ...)
  ;; Body: fn A ... . fn f1 f2 ... . fn R . fn branch0 branch1 ... . branch_i f1 f2 ...

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

      ;; Generate fresh field parameter names
      (define field-names
        (for/list ([_ (in-list field-types)]
                   [j (in-naturals)])
          (string->symbol (format "x~a" j))))

      ;; Constructor body: fn R . fn branch0 ... branch_{n-1} . branch_i x0 x1 ...
      ;; The branch_i is applied to the field arguments
      (define branch-application
        (if (null? field-names)
            (list-ref branch-names i)
            `(,(list-ref branch-names i) ,@field-names)))

      ;; Build the body from inside out:
      ;; 1. Innermost: branch_i applied to fields
      ;; 2. Wrap with branch parameter lambdas
      ;; 3. Wrap with R parameter lambda
      ;; 4. Wrap with field parameter lambdas
      ;; 5. Wrap with type parameter lambdas

      ;; Branch parameter bindings
      (define branch-bindings
        (for/list ([bn (in-list branch-names)]
                   [bt (in-list branch-types)])
          (list bn ': bt)))

      ;; R binding — must match the type definition's Pi(R : (Type 0))
      (define r-binding `(,r-name :0 (Type 0)))

      ;; Field bindings
      (define field-bindings
        (for/list ([fn field-names]
                   [ft (in-list field-types)])
          (list fn ': ft)))

      ;; Type parameter bindings (same as params but as fn bindings)
      (define param-fn-bindings
        (for/list ([p (in-list params)])
          (list (car p) ':0 (cdr p))))

      ;; Build nested fn from inside out
      (define body-with-branches
        (build-nested-fn branch-bindings branch-application))
      (define body-with-r
        `(fn (,@r-binding) ,body-with-branches))
      (define body-with-fields
        (build-nested-fn field-bindings body-with-r))
      (define full-body
        (build-nested-fn param-fn-bindings body-with-fields))

      ;; Constructor type:
      ;; Pi(A :0 T_A) ... -> T1 -> T2 -> ... -> (TypeName A B ...)
      (define ctor-result-type applied-type-name)
      (define ctor-type
        (build-nested-pi
         param-pi-bindings
         (build-arrow-type field-types ctor-result-type)))

      `(def ,ctor-name : ,ctor-type ,full-body)))

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
     (define binders (extract-pi-binders type-ast))
     (cond
       [(not (= (length param-names) (length binders)))
        (prologos-error
         loc
         (format "defn ~a: parameter list has ~a names but type has ~a binders"
                 name (length param-names) (length binders)))]
       [else
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
     (define binders (extract-pi-binders type-ast))
     (cond
       [(not (= (length param-names) (length binders)))
        (prologos-error
         loc
         (format "the-fn: parameter list has ~a names but type has ~a binders"
                 (length param-names) (length binders)))]
       [else
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
    ;; Built-in: defn desugaring
    [(surf-defn? surf)
     (define result (desugar-defn surf))
     (if (prologos-error? result)
         result
         (expand-top-level result (+ depth 1)))]
    ;; Already a top-level command — expand sub-expressions, then pass through
    [(surf-def? surf)
     (surf-def (surf-def-name surf)
               (expand-expression (surf-def-type surf))
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
