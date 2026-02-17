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
         racket/string
         "surface-syntax.rkt"
         "source-location.rkt"
         "errors.rkt"
         "namespace.rkt"
         "global-env.rkt")

(provide ;; Post-parse (layer 2)
         expand-top-level
         expand-expression
         current-macro-registry
         register-macro!
         ;; Pre-parse (layer 1)
         current-preparse-registry
         register-preparse-macro!
         preparse-expand-form
         preparse-expand-all
         preparse-expand-single
         preparse-macro
         preparse-macro?
         expand-lseq-literal
         pattern-var?
         datum-match
         datum-subst
         process-defmacro
         process-deftype
         process-data
         process-trait
         process-impl
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
         ;; Trait metadata registry
         current-trait-registry
         trait-meta
         trait-meta?
         trait-meta-name
         trait-meta-params
         trait-meta-methods
         trait-method
         trait-method?
         trait-method-name
         trait-method-type-datum
         register-trait!
         lookup-trait
         parse-trait-method
         ;; Impl metadata registry
         current-impl-registry
         impl-entry
         impl-entry?
         impl-entry-trait-name
         impl-entry-type-args
         impl-entry-dict-name
         register-impl!
         lookup-impl
         ;; Shared
         extract-pi-binders
         ;; Sibling let merging (for testing)
         merge-sibling-lets
         ;; Foreign escape block combining (for testing)
         combine-foreign-blocks
         ;; HKT brace-param parsing
         parse-brace-param-list
         group-brace-params
         ;; Spec store
         current-spec-store
         spec-entry
         spec-entry?
         spec-entry-type-datums
         spec-entry-docstring
         spec-entry-multi?
         spec-entry-srcloc
         register-spec!
         lookup-spec
         process-spec)

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
;; Spec store: type signatures for named definitions
;; ========================================

;; A spec entry: stores a type specification for a named definition.
;; type-datums: list of type-token-lists. Single-arity: ((Nat Nat -> Nat)).
;;              Multi-arity: ((Nat Nat -> Nat) (Nat -> Nat)).
;; docstring: (or/c string? #f)
;; multi?: #t if declared with | branches
;; srcloc: source location of the spec form
(struct spec-entry (type-datums docstring multi? srcloc) #:transparent)

;; Spec store: symbol → spec-entry
(define current-spec-store (make-parameter (hasheq)))

(define (register-spec! name entry)
  (current-spec-store (hash-set (current-spec-store) name entry)))

(define (lookup-spec name)
  (hash-ref (current-spec-store) name #f))

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
    ;; $foreign-block — opaque, do NOT recurse into code datums
    ;; The code inside is raw Racket, not Prologos surface syntax
    [(and (pair? datum) (eq? (car datum) '$foreign-block))
     datum]
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

;; Expand a single top-level datum through all preparse stages.
;; Applies: def := expansion, spec injection, then preparse-expand-form.
;; Used by the `expand` inspection command.
(define (preparse-expand-single datum)
  (cond
    [(and (pair? datum) (symbol? (car datum)))
     (define head (car datum))
     (cond
       ;; def with := — expand assignment syntax, then spec injection
       [(and (eq? head 'def) (memq ':= datum))
        (define pre (expand-def-assign datum))
        (define injected (maybe-inject-spec-def pre))
        (preparse-expand-form injected)]
       ;; def without := — try spec injection
       [(eq? head 'def)
        (define injected (maybe-inject-spec-def datum))
        (preparse-expand-form injected)]
       ;; defn — spec injection
       [(eq? head 'defn)
        (define injected (maybe-inject-spec datum))
        (preparse-expand-form injected)]
       ;; Everything else — standard preparse
       [else (preparse-expand-form datum)])]
    [else (preparse-expand-form datum)]))

;; Merge consecutive bodyless let forms into a single let with bracket bindings.
;; Input: list of elements (siblings in a form).
;; A "bodyless let" is (let name [: T] := value) with no body — detected because
;; the last element is NOT a list (it's the value, not a body expression like (add a b)).
;; The last let in a consecutive run has a body.
;;
;; Example: (defn ... (let a := 1) (let b := 2 (add a b)))
;; → (defn ... (let (a := 1 b := 2) (add a b)))
(define (merge-sibling-lets elems)
  (cond
    [(or (not (list? elems)) (null? elems)) elems]
    [else
     (let loop ([rest elems] [acc '()])
       (cond
         [(null? rest) (reverse acc)]
         ;; Check if current element is a bodyless let
         [(let-form? (car rest))
          ;; Collect consecutive let forms
          (define-values (lets remaining) (collect-consecutive-lets rest))
          (cond
            ;; Single let — no merging needed
            [(<= (length lets) 1)
             (loop remaining (cons (car lets) acc))]
            ;; Multiple lets followed by a non-let body expression —
            ;; treat ALL lets as bodyless bindings, trailing expr is the body.
            ;; This handles WS-mode where body is at the same indent level:
            ;;   let x := 10
            ;;   let y := add x x
            ;;   y              ← not a let, so it's the body
            [(and (pair? remaining)
                  (not (let-form? (car remaining))))
             (define body (car remaining))
             (define all-bindings
               (append-map extract-let-binding-tokens lets))
             (define merged `(let ,all-bindings ,body))
             (loop (cdr remaining) (cons merged acc))]
            ;; Multiple consecutive lets (last has body embedded) — merge
            [else
             (define merged (merge-let-sequence lets))
             (loop remaining (cons merged acc))])]
         [else
          (loop (cdr rest) (cons (car rest) acc))]))]))

;; Is this element a let form?
(define (let-form? elem)
  (and (list? elem) (pair? elem) (eq? (car elem) 'let)))

;; Is this let form bodyless? A bodyless let has no body expression.
;; For := format: (let name := value) — no further elements after value.
;; We detect this by: the form has no nested list as last element
;; that could be a body, OR the form only has binding tokens.
;; Simple heuristic: a let with only binding tokens (no body) will have
;; := as the second-to-last element, or will lack a final body form.
(define (let-bodyless? elem)
  (and (let-form? elem)
       (let ([rest (cdr elem)])
         (cond
           ;; (let name := value) — 3 elements in rest, := is second
           [(and (>= (length rest) 3) (eq? (cadr rest) ':=)
                 (= (length rest) 3))
            #t]
           ;; (let name : T1 T2 ... := value) — has := but last is the value, no body
           ;; Count: name : T1 ... := value = even number of "sections"
           ;; Detect by: rest ends right after the value following :=
           [(memq ':= rest)
            ;; Find := position, check if there's exactly one element after it
            (let ([assign-pos (index-of-symbol ':= rest)])
              (and assign-pos (= (length rest) (+ assign-pos 2))))]
           ;; (let [bindings] body) — has body, not bodyless
           ;; (let name value body) — has body, not bodyless
           [else #f]))))

;; Find the index of a symbol in a list
(define (index-of-symbol sym lst)
  (let loop ([i 0] [rest lst])
    (cond
      [(null? rest) #f]
      [(eq? (car rest) sym) i]
      [else (loop (+ i 1) (cdr rest))])))

;; Collect consecutive let forms from the start of a list.
;; Returns (values lets remaining).
(define (collect-consecutive-lets elems)
  (let loop ([rest elems] [lets '()])
    (cond
      [(and (pair? rest) (let-form? (car rest)))
       (loop (cdr rest) (cons (car rest) lets))]
      [else
       (values (reverse lets) rest)])))

;; Merge a sequence of let forms into one let with bracket bindings.
;; All but the last must be bodyless. The last has the body.
;; Returns a single (let (bindings...) body) form.
(define (merge-let-sequence lets)
  (define last-let (last lets))
  (define bodyless-lets (drop-right lets 1))
  ;; Extract bindings from bodyless lets
  (define bindings
    (append-map extract-let-binding-tokens bodyless-lets))
  ;; Extract bindings and body from the last let
  (define-values (last-bindings last-body) (split-last-let last-let))
  ;; Combine all bindings into bracket format
  (define all-bindings (append bindings last-bindings))
  `(let ,all-bindings ,last-body))

;; Extract binding tokens from a bodyless let form.
;; (let name := value) → (name := value)
;; (let name : T := value) → (name : T := value)
(define (extract-let-binding-tokens let-form)
  (cdr let-form))  ; everything after 'let

;; Split the last let in a sequence into (values binding-tokens body).
;; The last let has a body.
(define (split-last-let let-form)
  (define rest (cdr let-form))
  (cond
    ;; := format: find the body (last element after the value)
    [(memq ':= rest)
     ;; For (let name := value body) or (let name : T := value body)
     ;; Body is the last element, bindings are everything else
     (define body (last rest))
     (define binding-tokens (drop-right rest 1))
     (values binding-tokens body)]
    ;; Bracket format: (let [bindings] body) — already has bracket
    [(and (>= (length rest) 2) (list? (car rest)))
     (values (car rest) (cadr rest))]
    ;; Legacy format: (let name value body) — 3 elements
    [(= (length rest) 3)
     (define body (caddr rest))
     (define binding-tokens (list (car rest) ':= (cadr rest)))
     (values binding-tokens body)]
    [else
     ;; Fallback: treat last element as body
     (define body (last rest))
     (define binding-tokens (drop-right rest 1))
     (values binding-tokens body)]))

;; ========================================
;; Foreign escape block combining pass
;; ========================================
;; Merges sibling elements: racket ($brace-params code...) [captures...] -> [exports...]
;; into a single ($foreign-block ...) sentinel form.
;;
;; Input:  (...before... racket ($brace-params c1 c2) (x : Nat) -> (y : Nat) ...after...)
;; Output: (...before... ($foreign-block racket (c1 c2) ((x : Nat)) ((y : Nat))) ...after...)
;;
;; The parser then handles the detailed parsing of captures/exports.

;; Is this element a ($brace-params ...) form?
(define (brace-params? elem)
  (and (pair? elem)
       (let ([h (car elem)])
         (cond
           [(symbol? h) (eq? h '$brace-params)]
           [(syntax? h) (eq? (syntax-e h) '$brace-params)]
           [else #f]))))

;; Is this element a list that looks like a capture/export spec?
;; A capture list is [...] containing (name : Type) patterns.
;; At the datum level, it's a list whose first element is a symbol (not a keyword)
;; and contains the symbol ':'.
(define (capture-or-export-list? elem)
  (and (pair? elem)
       (not (null? elem))
       ;; Must not be a sentinel form ($brace-params, $angle-type, etc.)
       (let ([h (if (syntax? (car elem)) (syntax-e (car elem)) (car elem))])
         (and (symbol? h)
              (not (eq? h '$brace-params))
              (not (eq? h '$angle-type))
              (not (eq? h '$foreign-block))
              (not (eq? h '$quote))
              (not (eq? h '$pipe))
              ;; Must contain ':' somewhere (type annotation)
              (ormap (lambda (e)
                       (let ([v (if (syntax? e) (syntax-e e) e)])
                         (eq? v ':)))
                     elem)))))

;; Is this element the arrow '->' symbol?
(define (arrow-sym? elem)
  (let ([v (if (syntax? elem) (syntax-e elem) elem)])
    (eq? v '->)))

;; Combine foreign escape blocks in a flat element list.
;; Scans for: racket ($brace-params ...) [captures...] -> [exports...]
;; and merges into ($foreign-block racket (code...) (captures...) (exports...))
(define (combine-foreign-blocks elems)
  (if (or (not (list? elems)) (null? elems))
      elems
      (let loop ([rest elems] [acc '()])
        (cond
          [(null? rest) (reverse acc)]
          ;; Detect: racket followed by ($brace-params ...)
          [(and (pair? (cdr rest))
                (let ([v (if (syntax? (car rest)) (syntax-e (car rest)) (car rest))])
                  (eq? v 'racket))
                (let ([next (cadr rest)])
                  (let ([d (if (syntax? next) (syntax-e next) next)])
                    (brace-params? d))))
           (define lang 'racket)
           (define brace-elem (cadr rest))
           (define brace-datum (if (syntax? brace-elem) (syntax-e brace-elem) brace-elem))
           ;; Extract code datums (skip $brace-params sentinel)
           (define code-datums (cdr brace-datum))
           ;; Look ahead for captures and exports
           (define remaining (cddr rest))
           (define-values (captures remaining2)
             (if (and (pair? remaining)
                      (let ([e (car remaining)])
                        (let ([d (if (syntax? e) (syntax-e e) e)])
                          (capture-or-export-list? d))))
                 ;; Next element is a capture list
                 (let ([cap (car remaining)]
                       [cap-datum (let ([e (car remaining)])
                                    (if (syntax? e) (syntax-e e) e))])
                   (values (list cap-datum) (cdr remaining)))
                 (values '() remaining)))
           (define-values (exports remaining3)
             (if (and (pair? remaining2)
                      (arrow-sym? (car remaining2))
                      (pair? (cdr remaining2))
                      (let ([e (cadr remaining2)])
                        (let ([d (if (syntax? e) (syntax-e e) e)])
                          (capture-or-export-list? d))))
                 ;; -> followed by export list
                 (let ([exp (cadr remaining2)]
                       [exp-datum (let ([e (cadr remaining2)])
                                    (if (syntax? e) (syntax-e e) e))])
                   (values (list exp-datum) (cddr remaining2)))
                 (values '() remaining2)))
           ;; Build ($foreign-block racket (code...) (captures...) (exports...))
           (define block `($foreign-block ,lang ,code-datums ,captures ,exports))
           (loop remaining3 (cons block acc))]
          ;; Not a foreign block — pass through
          [else
           (loop (cdr rest) (cons (car rest) acc))]))))

;; Recursively expand subexpressions of a list datum
;; Special handling for $pipe forms: group elements after -> into a single
;; sub-form so pre-parse macros (like let) see the correct structure.
;; Also merges consecutive bodyless let forms (sibling lets) before expansion.
;; Also combines foreign escape blocks (racket { ... } [captures] -> [exports]).
(define (preparse-expand-subforms datum reg depth)
  (define grouped (maybe-group-pipe-body datum))
  (define foreign-combined (combine-foreign-blocks grouped))
  (define merged (merge-sibling-lets foreign-combined))
  (define expanded
    (map (lambda (sub) (preparse-expand-form sub reg depth))
         merged))
  ;; Return expanded if any transformation changed the datum.
  ;; Compare against original datum (not intermediate) to preserve
  ;; changes from combining passes (foreign blocks, pipe grouping, let merging).
  (if (equal? expanded datum) datum expanded))

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
;; Helper: auto-export a name if a namespace context is active.
;; Does nothing if no ns-context (legacy mode).
(define (auto-export-name! name)
  (when (current-ns-context)
    (current-ns-context
     (ns-context-add-auto-export (current-ns-context) name))))

;; Helper: auto-export multiple names.
(define (auto-export-names! names)
  (for ([name (in-list names)])
    (auto-export-name! name)))

;; Helper: detect private suffix forms (defn-, def-, data-, deftype-, defmacro-).
;; Returns the base keyword symbol (e.g., 'defn for 'defn-) or #f.
(define (private-form-base head)
  (case head
    [(defn-)    'defn]
    [(def-)     'def]
    [(data-)    'data]
    [(deftype-) 'deftype]
    [(defmacro-) 'defmacro]
    [(spec-)    'spec]
    [(trait-)   'trait]
    [(impl-)    'impl]
    [else #f]))

;; Helper: extract the defined name(s) from a top-level form datum.
;; Returns a list of symbols for auto-export.
;;  - defn, def: (cadr datum) is the name
;;  - deftype: (caadr datum) if parameterized, (cadr datum) if bare alias
;;  - defmacro: (cadr datum) (the name symbol)
;;  - data: handled separately (type + constructor names from process-data result)
(define (extract-defined-name datum head)
  (case head
    [(defn def)
     (if (and (>= (length datum) 2) (symbol? (cadr datum)))
         (list (cadr datum))
         '())]
    [(deftype)
     (if (>= (length datum) 2)
         (let ([pattern (cadr datum)])
           (cond
             [(symbol? pattern) (list pattern)]
             [(and (pair? pattern) (symbol? (car pattern))) (list (car pattern))]
             [else '()]))
         '())]
    [(defmacro)
     (if (and (>= (length datum) 2) (symbol? (cadr datum)))
         (list (cadr datum))
         '())]
    [else '()]))

(define (preparse-expand-all stxs)
  (define result
    (for/fold ([acc '()])
              ([stx (in-list stxs)])
      (define datum (syntax->datum stx))
      (define head (and (pair? datum) (car datum)))
      (cond
        ;; ns — set namespace context and consume
        [(and (pair? datum) (eq? head 'ns))
         (process-ns-declaration datum)
         acc]
        ;; require — import module and consume
        [(and (pair? datum) (eq? head 'require))
         (process-require datum)
         acc]
        ;; provide — record exports and consume
        [(and (pair? datum) (eq? head 'provide))
         (process-provide datum)
         acc]
        ;; foreign — import foreign function binding and consume
        [(and (pair? datum) (eq? head 'foreign))
         (process-foreign datum)
         acc]

        ;; ---- Private suffix forms: defn-, def-, data-, deftype-, defmacro- ----
        ;; Rewrite to the base form but do NOT auto-export.
        [(and (pair? datum) (private-form-base head))
         => (lambda (base)
              (define rewritten (cons base (cdr datum)))
              (cond
                [(eq? base 'defmacro)
                 (process-defmacro rewritten)
                 acc]
                [(eq? base 'deftype)
                 (process-deftype rewritten)
                 acc]
                [(eq? base 'spec)
                 (process-spec rewritten)
                 acc]
                [(eq? base 'data)
                 (define defs (process-data rewritten))
                 (define new-stxs
                   (for/list ([d (in-list defs)])
                     (datum->syntax #f d stx)))
                 (append (reverse new-stxs) acc)]
                [(eq? base 'trait)
                 (define defs (process-trait rewritten))
                 (define new-stxs
                   (for/list ([d (in-list defs)])
                     (datum->syntax #f (preparse-expand-form d) stx)))
                 (append (reverse new-stxs) acc)]
                [(eq? base 'impl)
                 (define defs (process-impl rewritten))
                 (define new-stxs
                   (for/list ([d (in-list defs)])
                     (datum->syntax #f (preparse-expand-form d) stx)))
                 (append (reverse new-stxs) acc)]
                ;; def- or defn- — rewrite head, preserving child syntax properties
                [else
                 ;; Replace just the head symbol in the syntax list to preserve
                 ;; properties like paren-shape on child nodes (e.g., [params]).
                 (define children (if (syntax? stx) (syntax->list stx) #f))
                 (define new-stx
                   (if children
                       ;; Replace head syntax object, keep remaining children
                       (datum->syntax stx (cons (datum->syntax (car children) base (car children))
                                                (cdr children))
                                      stx)
                       ;; Fallback: pure datum
                       (datum->syntax #f rewritten stx)))
                 ;; Inject spec type into bare-param defn- if matching spec exists
                 (define maybe-injected
                   (let ([d (syntax->datum new-stx)])
                     (if (eq? base 'defn) (maybe-inject-spec d) d)))
                 (define expanded (preparse-expand-form maybe-injected))
                 (if (equal? expanded maybe-injected)
                     (cons (datum->syntax #f maybe-injected stx) acc)
                     (cons (datum->syntax #f expanded stx) acc))]))]

        ;; ---- Public defmacro — register, consume, AND auto-export ----
        [(and (pair? datum) (eq? head 'defmacro))
         (process-defmacro datum)
         (auto-export-names! (extract-defined-name datum 'defmacro))
         acc]
        ;; ---- Public deftype — register, consume, AND auto-export ----
        [(and (pair? datum) (eq? head 'deftype))
         (process-deftype datum)
         (auto-export-names! (extract-defined-name datum 'deftype))
         acc]
        ;; ---- Public spec — register type spec, consume, AND auto-export ----
        [(and (pair? datum) (eq? head 'spec))
         (process-spec datum)
         (when (and (list? datum) (>= (length datum) 2) (symbol? (cadr datum)))
           (auto-export-name! (cadr datum)))
         acc]
        ;; ---- Public data — generate defs, auto-export type + constructors ----
        [(and (pair? datum) (eq? head 'data))
         (define defs (process-data datum))
         ;; Auto-export: type name + all constructor names from generated defs
         (for ([d (in-list defs)])
           (when (and (list? d) (>= (length d) 2) (symbol? (cadr d)))
             (auto-export-name! (cadr d))))
         ;; Convert each def to a syntax object and add to accumulator
         (define new-stxs
           (for/list ([d (in-list defs)])
             (datum->syntax #f d stx)))
         (append (reverse new-stxs) acc)]
        ;; ---- Public trait — generate deftype + accessor defs, auto-export ----
        [(and (pair? datum) (eq? head 'trait))
         (define defs (process-trait datum))
         ;; Auto-export: trait name + accessor names
         (define tname (let ([h (cadr datum)])
                         (if (symbol? h) h (and (pair? h) (car h)))))
         (when tname (auto-export-name! tname))
         (for ([d (in-list defs)])
           (when (and (list? d) (>= (length d) 2) (symbol? (cadr d)))
             (auto-export-name! (cadr d))))
         ;; Convert accessor defs to syntax objects (expand sub-forms for deftype macros)
         (define new-stxs
           (for/list ([d (in-list defs)])
             (datum->syntax #f (preparse-expand-form d) stx)))
         (append (reverse new-stxs) acc)]
        ;; ---- Public impl — generate dict + method defs, auto-export ----
        [(and (pair? datum) (eq? head 'impl))
         (define defs (process-impl datum))
         ;; Auto-export: dict name + method helper names
         (for ([d (in-list defs)])
           (when (and (list? d) (>= (length d) 2) (symbol? (cadr d)))
             (auto-export-name! (cadr d))))
         ;; Convert defs to syntax objects (expand sub-forms for deftype macros)
         (define new-stxs
           (for/list ([d (in-list defs)])
             (datum->syntax #f (preparse-expand-form d) stx)))
         (append (reverse new-stxs) acc)]
        ;; ---- Public defn/def — auto-export the name ----
        [(and (pair? datum) (memq head '(defn def)))
         (auto-export-names! (extract-defined-name datum head))
         ;; Step 1: expand := syntax for def (before spec injection)
         (define pre-datum
           (if (and (eq? head 'def) (memq ':= datum))
               (expand-def-assign datum)
               datum))
         ;; Step 2: inject spec type (defn or def)
         (define maybe-injected
           (cond
             [(eq? (car pre-datum) 'defn) (maybe-inject-spec pre-datum)]
             [(eq? (car pre-datum) 'def)  (maybe-inject-spec-def pre-datum)]
             [else pre-datum]))
         (define expanded (preparse-expand-form maybe-injected))
         (if (equal? expanded maybe-injected)
             (if (equal? maybe-injected datum)
                 (cons stx acc)
                 (cons (datum->syntax #f maybe-injected stx) acc))
             (cons (datum->syntax #f expanded stx) acc))]
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
;; (defmacro name ($param ...) template)
(define (process-defmacro datum)
  (unless (and (list? datum) (= (length datum) 4))
    (error 'defmacro "defmacro requires: (defmacro name ($params...) template)"))
  (define macro-name (cadr datum))
  (unless (symbol? macro-name)
    (error 'defmacro "defmacro: name must be a symbol, got ~a" macro-name))
  (define params (normalize-quote-vars (caddr datum)))
  (define template (normalize-quote-vars (cadddr datum)))
  (define pattern (if (list? params) (cons macro-name params) (list macro-name params)))
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
;; process-spec: register a type specification
;; ========================================
;; Syntax variants:
;;   (spec name type-atoms...)                     — single arity
;;   (spec name "docstring" type-atoms...)          — with docstring
;;   (spec name ($pipe type-atoms...) ($pipe ...))  — multi-arity
;;   (spec name "docstring" ($pipe ...) ($pipe ...)) — multi with docstring
(define (process-spec datum)
  (unless (and (list? datum) (>= (length datum) 3))
    (error 'spec "spec requires: (spec name type-signature)"))
  (define name (cadr datum))
  (unless (symbol? name)
    (error 'spec "spec: name must be a symbol, got ~a" name))
  (define rest (cddr datum))
  ;; Check for optional docstring (first element after name is a string)
  (define-values (docstring body-tokens)
    (if (and (not (null? rest)) (string? (car rest)))
        (values (car rest) (cdr rest))
        (values #f rest)))
  (when (null? body-tokens)
    (error 'spec "spec ~a: missing type signature" name))
  ;; Check for multi-arity: body-tokens contain $pipe forms
  (define has-pipes?
    (ormap (lambda (t) (or (eq? t '$pipe)
                           (and (pair? t) (eq? (car t) '$pipe))))
           body-tokens))
  (cond
    [has-pipes?
     ;; Split on $pipe to get branches
     (define branches (split-on-pipe body-tokens))
     (register-spec! name (spec-entry branches docstring #t srcloc-unknown))]
    [else
     ;; Single-arity: the entire body-tokens is the type datum
     (register-spec! name (spec-entry (list body-tokens) docstring #f srcloc-unknown))]))

;; Split a token list on '$pipe boundaries.
;; Handles two forms:
;;   Flat: ($pipe A B -> C $pipe D E -> F) → ((A B -> C) (D E -> F))
;;   Grouped: (($pipe A B -> C) ($pipe D E -> F)) → ((A B -> C) (D E -> F))
;; Leading $pipe is consumed.
(define (split-on-pipe tokens)
  (cond
    ;; Grouped form: each element is ($pipe content...)
    [(and (pair? tokens)
          (pair? (car tokens))
          (eq? (car (car tokens)) '$pipe))
     (map cdr tokens)]
    ;; Flat form: $pipe separates items
    [else
     (define stripped
       (if (and (pair? tokens) (eq? (car tokens) '$pipe))
           (cdr tokens)
           tokens))
     (let loop ([remaining stripped] [current '()] [result '()])
       (cond
         [(null? remaining)
          (reverse (if (null? current) result (cons (reverse current) result)))]
         [(eq? (car remaining) '$pipe)
          (loop (cdr remaining) '() (cons (reverse current) result))]
         [else
          (loop (cdr remaining) (cons (car remaining) current) result)]))]))

;; ========================================
;; Spec injection into defn
;; ========================================
;; When a defn has bare params (no type annotations) and a matching spec
;; exists, inject the spec type into the defn datum so the existing parser
;; handles it as a typed defn.

;; Check if a parameter list contains only bare symbols (no type annotations).
(define (spec-bare-param-list? lst)
  (and (list? lst) (not (null? lst))
       (andmap (lambda (x)
                 (and (symbol? x)
                      (not (memq x '(: :0 :1 :w)))))
               lst)
       (not (ormap (lambda (x) (and (pair? x) (eq? (car x) '$angle-type))) lst))))

;; Check if defn rest (after name) has any type annotation indicators.
;; rest = (param-bracket possibly-more...)
(define (defn-has-type-annotation? rest)
  (and (pair? rest)
       (let ([params (car rest)])
         (or
          ;; Params contain type markers
          (and (list? params)
               (ormap (lambda (x)
                        (or (and (pair? x) (eq? (car x) '$angle-type))
                            (eq? x ':)
                            (memq x '(:0 :1 :w))))
                      params))
          ;; Has angle-type or colon after params (return type)
          (and (pair? (cdr rest))
               (let ([after (cadr rest)])
                 (or (and (pair? after) (eq? (car after) '$angle-type))
                     (eq? after ':))))))))

;; Check if rest contains $pipe clauses (multi-body defn at datum level)
(define (defn-has-pipes? rest)
  (ormap (lambda (x)
           (and (pair? x) (eq? (car x) '$pipe)))
         rest))

;; Decompose spec type tokens into parameter types and return type.
;; Uses the Prologos uncurried arrow convention:
;;   A B -> C  means  A -> B -> C  (each atom in non-last segment = separate param type)
;;   [A -> B] C -> D  means  (A->B) -> C -> D  (sub-lists are grouped param types)
;;   (n : Nat) A -> Vec n A  means  Pi(n:Nat) -> A -> Vec n A  (sub-list binder)
;;
;; Returns (values param-types return-type-tokens)
;; param-types: a list of param type atoms/lists (one per expected param)
;; return-type-tokens: the tokens for the return type
(define (decompose-spec-type tokens n-params name)
  (define segments (split-on-arrow-datum tokens))
  (cond
    ;; No arrows: relation type (or zero-param function)
    [(= (length segments) 1)
     (if (= n-params 0)
         (values '() tokens)
         (error 'spec "spec type for ~a has no arrow but defn has ~a params"
                name n-params))]
    [else
     ;; Has arrows: non-last segments = param types, last = return type
     (define non-last (drop-right segments 1))
     (define last-seg (last segments))
     ;; Flatten non-last segments: each element is a param type
     ;; Elements that are sub-lists (from [...]) stay as single param types
     (define flat-params (append-map (lambda (x) x) non-last))
     (cond
       [(= (length flat-params) n-params)
        (values flat-params last-seg)]
       [(> (length flat-params) n-params)
        ;; More type params than defn params — extra become part of return type
        ;; This happens for curried returns: spec f Nat -> Nat -> Nat, defn f [x] ...
        (define actual (take flat-params n-params))
        (define extra (drop flat-params n-params))
        (values actual (append extra (list '->) last-seg))]
       [else
        (error 'spec "spec ~a: type has ~a type parameters but defn has ~a params"
               name (length flat-params) n-params)])]))

;; Convert a spec param-type element to an $angle-type annotation.
;; - plain atom Nat → ($angle-type Nat)
;; - grouped list [List A] → ($angle-type List A)
;; - dependent binder (n : Nat) → just Nat (the type part, binder name ignored)
(define (param-type->angle-type ptype)
  (cond
    ;; Dependent binder: (name : type-atoms...)
    [(and (list? ptype) (>= (length ptype) 3) (eq? (cadr ptype) ':))
     `($angle-type ,@(cddr ptype))]
    ;; Grouped type containing infix -> : flatten so parse-infix-type handles arrow
    ;; e.g. (B -> C) → ($angle-type B -> C), (A -> B -> C) → ($angle-type A -> B -> C)
    ;; But NOT prefix -> like (-> Nat Nat) which would break parse-infix-type
    [(and (list? ptype) (pair? ptype) (not (eq? (car ptype) '->))
          (memq '-> ptype))
     `($angle-type ,@ptype)]
    ;; All other grouped types: wrap as single element for parse-datum
    ;; Handles: (-> Nat Nat), (List A), (Sigma (_ ...) B), (Option A), etc.
    [(list? ptype)
     `($angle-type ,ptype)]
    ;; Plain atom
    [else
     `($angle-type ,ptype)]))

;; Inject a spec type into a single-arity defn datum.
;; datum: (defn name [x y] body)  OR  (defn name [x y] body1 body2 ...)
;; spec-tokens: (Nat Nat -> Nat)
;; Returns: (defn name [x ($angle-type Nat) y ($angle-type Nat)] ($angle-type Nat) body)
(define (inject-spec-into-defn datum spec-tokens)
  (define name (cadr datum))
  (define rest (cddr datum))  ;; ([x y] body ...)
  (define param-bracket (car rest))
  (define body-forms (cdr rest))  ;; could be multiple body forms
  (define param-names
    (if (list? param-bracket) param-bracket
        (error 'spec "Expected parameter list, got ~a" param-bracket)))
  ;; Decompose spec type into param types + return type
  (define-values (param-types return-type-tokens)
    (decompose-spec-type spec-tokens (length param-names) name))
  ;; Build typed bracket: [x ($angle-type T1) y ($angle-type T2)]
  (define typed-bracket
    (apply append
           (for/list ([pname (in-list param-names)]
                      [ptype (in-list param-types)])
             (list pname (param-type->angle-type ptype)))))
  ;; Build return type angle form
  (define ret-angle `($angle-type ,@return-type-tokens))
  ;; Assemble: (defn name [typed-bracket...] ($angle-type ret) body-forms...)
  `(defn ,name ,typed-bracket ,ret-angle ,@body-forms))

;; Inject spec types into a multi-arity defn datum.
;; Each $pipe clause gets its corresponding spec branch type.
(define (inject-spec-into-defn-multi datum name spec-branches)
  (define rest (cddr datum))  ;; everything after name
  ;; Extract pipe clauses and any docstring
  (define docstring
    (and (pair? rest) (string? (car rest)) (car rest)))
  (define clauses
    (filter (lambda (x) (and (pair? x) (eq? (car x) '$pipe)))
            rest))
  (unless (= (length clauses) (length spec-branches))
    (error 'spec "spec ~a has ~a branches but defn has ~a clauses"
           name (length spec-branches) (length clauses)))
  ;; Rewrite each clause
  (define rewritten-clauses
    (for/list ([clause (in-list clauses)]
               [branch-tokens (in-list spec-branches)])
      ;; clause = ($pipe [params...] body ...)
      (define clause-body (cdr clause))  ;; everything after $pipe
      ;; Build a temporary defn datum for injection
      (define temp-datum `(defn ,name ,@clause-body))
      (define injected (inject-spec-into-defn temp-datum branch-tokens))
      ;; Re-wrap as $pipe clause: ($pipe typed-bracket ret body...)
      `($pipe ,@(cddr injected))))
  ;; Reconstruct the defn with rewritten clauses
  (if docstring
      `(defn ,name ,docstring ,@rewritten-clauses)
      `(defn ,name ,@rewritten-clauses)))

;; Top-level dispatcher: check if a defn should have spec type injected.
;; Returns the original datum unchanged if no spec applies.
(define (maybe-inject-spec datum)
  (define name (and (list? datum) (>= (length datum) 3) (cadr datum)))
  (cond
    [(not (symbol? name)) datum]
    [else
     (define rest (cddr datum))
     (define spec (lookup-spec name))
     (cond
       [(not spec) datum]
       ;; Multi-body defn with pipes
       [(defn-has-pipes? rest)
        (cond
          [(defn-has-type-annotation? rest)
           ;; Error: defn has inline types AND spec
           ;; But multi-body pipes may have types per-clause; check first clause
           ;; For now, attempt injection — if clauses have bare params, inject
           ;; If not, error.
           ;; Actually, for multi-body, check each clause individually
           ;; For simplicity: if any clause has type annotations, error
           (error 'spec "defn ~a has both a spec and inline type annotations" name)]
          [(not (spec-entry-multi? spec))
           (error 'spec "spec for ~a is single-arity but defn ~a has multiple clauses"
                  name name)]
          [else
           (inject-spec-into-defn-multi datum name (spec-entry-type-datums spec))])]
       ;; Single-body defn
       [(and (pair? rest) (list? (car rest)) (spec-bare-param-list? (car rest))
             (not (defn-has-type-annotation? rest)))
        ;; Bare params with no type → inject spec
        (cond
          [(spec-entry-multi? spec)
           (error 'spec "spec for ~a is multi-arity but defn ~a is single-body"
                  name name)]
          [else
           (inject-spec-into-defn datum (car (spec-entry-type-datums spec)))])]
       ;; Defn has inline types — conflict with spec
       [(defn-has-type-annotation? rest)
        (error 'spec "defn ~a has both a spec and inline type annotations" name)]
       ;; No injection needed (e.g., no params bracket)
       [else datum])]))

;; Inject a spec type into a def datum.
;; datum: (def name body)
;; spec-tokens: (Nat) or (Nat -> Nat)
;; Returns: (def name ($angle-type spec-tokens...) body)
(define (inject-spec-into-def datum spec-tokens)
  (define name (cadr datum))
  (define rest (cddr datum))
  `(def ,name ($angle-type ,@spec-tokens) ,@rest))

;; Top-level dispatcher: check if a def should have spec type injected.
;; Returns the original datum unchanged if no spec applies.
(define (maybe-inject-spec-def datum)
  (define name (and (list? datum) (>= (length datum) 2) (cadr datum)))
  (cond
    [(not (symbol? name)) datum]
    [else
     (define spec (lookup-spec name))
     (cond
       [(not spec) datum]
       [(spec-entry-multi? spec)
        (error 'spec "spec for ~a is multi-arity but used with def" name)]
       ;; Check if def already has a type annotation (angle-type or colon)
       [(and (>= (length datum) 4)
             (let ([third (caddr datum)])
               (or (and (pair? third) (eq? (car third) '$angle-type))
                   (eq? third ':))))
        (error 'spec "def ~a has both a spec and inline type annotation" name)]
       [else
        (inject-spec-into-def datum (car (spec-entry-type-datums spec)))])]))

;; Expand def := assignment syntax into standard def form.
;; (def name := value) → (def name value)
;; (def name : T1 T2 ... := value) → (def name ($angle-type T1 T2 ...) value)
(define (expand-def-assign datum)
  (define name (cadr datum))
  (define rest (cddr datum))  ; tokens after name
  (define assign-pos (index-of-symbol ':= rest))
  (cond
    [(not assign-pos) datum]
    [else
     (define before (take rest assign-pos))
     (define after (drop rest (+ assign-pos 1)))
     (unless (= (length after) 1)
       (error 'def "def: expected exactly one value after :=, got ~a" after))
     (define value (car after))
     (cond
       ;; No type annotation: (def name := value) → (def name value)
       [(null? before)
        `(def ,name ,value)]
       ;; Type annotation with colon: (def name : T1 T2 ... := value)
       [(and (>= (length before) 2) (eq? (car before) ':))
        (define type-tokens (cdr before))
        `(def ,name ($angle-type ,@type-tokens) ,value)]
       [else
        (error 'def "def: unexpected tokens before :=: ~a" before)])]))

;; ========================================
;; Built-in pre-parse macros
;; ========================================

;; let: sequential local bindings
;; Formats (all expand to nested ((fn (name : type) ...) value) applications):
;;
;; 1. Inline :=  — (let name := value body)
;;                  (let name : T1 T2 := value body)
;; 2. Bracket := — (let [name := value  name2 : T := value2] body)
;; 3. Bracket <> — (let [name ($angle-type T) value ...] body) — flat triples
;; 4. Bracket () — (let ([name : T value] ...) body) — nested 4-element sub-lists
;; 5. Shorthand  — (let name value body) — no type, 4 elements
;;
(define (expand-let datum)
  (unless (and (list? datum) (>= (length datum) 3))
    (error 'let "let requires at least: (let name value body)"))
  (define rest (cdr datum))  ; everything after 'let

  (cond
    ;; --- Branch 1: Bracket format — second element is a list ---
    [(list? (car rest))
     (unless (= (length rest) 2)
       (error 'let "let with bracket bindings requires: (let [bindings...] body)"))
     (define bindings-datum (car rest))
     (define body (cadr rest))
     (expand-let-bracket-bindings bindings-datum body)]

    ;; --- Branch 2: Inline := format — find := in rest ---
    [(memq ':= rest)
     (expand-let-inline-assign rest)]

    ;; --- Branch 3: Legacy shorthand — (let name value body) ---
    [(and (= (length rest) 3) (symbol? (car rest)))
     (define name (car rest))
     (define value (cadr rest))
     (define body (caddr rest))
     `((fn (,name : _) ,body) ,value)]

    ;; --- Branch 4: Legacy angle-type format — (let name ($angle-type T) value body) ---
    [(and (>= (length rest) 4)
          (symbol? (car rest))
          (let ([second (cadr rest)])
            (and (pair? second) (eq? (car second) '$angle-type))))
     ;; Re-wrap as bracket format for uniform handling
     (define body (last rest))
     (define bindings-tokens (drop-right rest 1))
     (expand-let-bracket-bindings bindings-tokens body)]

    [else
     (error 'let "let: unrecognized format: ~a" datum)]))

;; Expand bracket-style let bindings.
;; Handles three sub-formats within the bracket:
;;   := format: [name := value  name2 : T := value2 ...]
;;   angle-type format: [name ($angle-type T) value ...]
;;   nested format: ([name : T value] ...)
(define (expand-let-bracket-bindings bindings-datum body)
  (cond
    ;; Empty bindings — just return body
    [(null? bindings-datum) body]
    ;; := format: contains := symbol somewhere in the flat list
    [(memq ':= bindings-datum)
     (define parsed (parse-assign-bindings bindings-datum))
     (let-bindings->nested-fn parsed body)]
    ;; Angle-type format: first element is symbol, second is ($angle-type ...)
    [(and (symbol? (car bindings-datum))
          (>= (length bindings-datum) 3)
          (let ([second (cadr bindings-datum)])
            (and (pair? second) (eq? (car second) '$angle-type))))
     (define parsed (parse-let-flat-triples bindings-datum))
     (let-bindings->nested-fn parsed body)]
    ;; Nested format: ([name : T value] ...) or ([name value] ...) with inferred type
    [else
     (define parsed
       (for/list ([binding (in-list bindings-datum)])
         (cond
           [(and (list? binding) (= (length binding) 4))
            ;; (name : type value)
            (list (car binding) (caddr binding) (cadddr binding))]
           [(and (list? binding) (= (length binding) 2) (symbol? (car binding)))
            ;; (name value) — type inferred via hole
            (list (car binding) '_ (cadr binding))]
           [else
            (error 'let "let: each binding must be (name value) or (name : type value), got ~a" binding)])))
     (let-bindings->nested-fn parsed body)]))

;; Expand inline := let: rest = (name [: type-atoms...] := value body)
;; The last element is the body. Everything before is: name [: T1 T2 ...] := value
(define (expand-let-inline-assign rest)
  (define body (last rest))
  (define tokens (drop-right rest 1))  ; name [: T1 T2 ...] := value
  (define parsed (parse-assign-bindings tokens))
  (let-bindings->nested-fn parsed body))

;; Convert parsed bindings ((name type value) ...) to nested fn application.
;; Type '_ means inferred (hole).
(define (let-bindings->nested-fn parsed-bindings body)
  (foldr (lambda (binding inner)
           (define name (car binding))
           (define type (cadr binding))
           (define value (caddr binding))
           `((fn (,name : ,type) ,inner) ,value))
         body
         parsed-bindings))

;; Parse := bindings from a flat token list.
;; Format: name [: T1 T2 ...] := value [name2 [: T3 ...] := value2 ...]
;; Returns list of (name type value) triples. Type = '_ when omitted.
(define (parse-assign-bindings tokens)
  (cond
    [(null? tokens) '()]
    [else
     (unless (symbol? (car tokens))
       (error 'let "let :=: expected variable name, got ~a" (car tokens)))
     (define name (car tokens))
     (define after-name (cdr tokens))
     ;; Check for optional type annotation: : T1 T2 ... :=
     (cond
       ;; name := value ... — no type annotation
       [(and (pair? after-name) (eq? (car after-name) ':=))
        (define after-assign (cdr after-name))
        (when (null? after-assign)
          (error 'let "let :=: missing value after := for ~a" name))
        ;; Value = everything until next binding start or end
        (define-values (value-tokens rest) (split-at-next-assign-binding after-assign))
        (define value (if (= (length value-tokens) 1)
                          (car value-tokens)
                          value-tokens))
        (cons (list name '_ value) (parse-assign-bindings rest))]
       ;; name : T1 T2 ... := value ... — with type annotation
       [(and (pair? after-name) (eq? (car after-name) ':))
        (define after-colon (cdr after-name))
        ;; Collect type atoms until :=
        (define-values (type-atoms after-assign)
          (split-before-symbol ':= after-colon))
        (when (null? type-atoms)
          (error 'let "let :=: empty type annotation for ~a" name))
        (when (null? after-assign)
          (error 'let "let :=: missing := after type for ~a" name))
        ;; after-assign starts with :=, skip it
        (define past-assign (cdr after-assign))
        (when (null? past-assign)
          (error 'let "let :=: missing value after := for ~a" name))
        (define-values (value-tokens rest) (split-at-next-assign-binding past-assign))
        (define type (if (= (length type-atoms) 1)
                         (car type-atoms)
                         type-atoms))
        (define value (if (= (length value-tokens) 1)
                          (car value-tokens)
                          value-tokens))
        (cons (list name type value) (parse-assign-bindings rest))]
       [else
        (error 'let "let :=: expected := or : after name ~a, got ~a" name after-name)])]))

;; Split a list at the first occurrence of a given symbol.
;; Returns (values before-symbol from-symbol-onwards).
;; If symbol not found, returns (values list '()).
(define (split-before-symbol sym lst)
  (let loop ([acc '()] [rest lst])
    (cond
      [(null? rest) (values (reverse acc) '())]
      [(eq? (car rest) sym) (values (reverse acc) rest)]
      [else (loop (cons (car rest) acc) (cdr rest))])))

;; Split at the start of the next := binding in a value token list.
;; A binding starts at position i if tokens[i] is a symbol and
;; tokens[i+1] is := or tokens[i+1] is : (followed eventually by :=).
;; Returns (values value-tokens remaining-tokens).
(define (split-at-next-assign-binding tokens)
  (let loop ([i 0] [rest tokens])
    (cond
      [(null? rest)
       (values tokens '())]
      [(and (> i 0)
            (symbol? (car rest))
            (not (eq? (car rest) ':))
            (not (eq? (car rest) ':=))
            (pair? (cdr rest))
            (or (eq? (cadr rest) ':=)
                (eq? (cadr rest) ':)))
       (values (take tokens i) rest)]
      [else
       (loop (+ i 1) (cdr rest))])))

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

;; list literal: '[1 2 3] → (cons 1 (cons 2 (cons 3 nil)))
;; The WS reader produces ($list-literal e1 e2 ...) and ($list-tail tail)
;; for the pipe syntax '[1 2 | ys].
;; Expansion:
;;   ($list-literal)             → nil
;;   ($list-literal 1 2 3)      → (cons 1 (cons 2 (cons 3 nil)))
;;   ($list-literal 1 ($list-tail ys)) → (cons 1 ys)
;;   ($list-literal 1 2 ($list-tail ys)) → (cons 1 (cons 2 ys))
(define (expand-list-literal datum)
  (unless (and (list? datum) (>= (length datum) 1)
               (eq? (car datum) '$list-literal))
    (error '$list-literal "expected ($list-literal ...), got ~a" datum))
  (define elems (cdr datum))
  (cond
    [(null? elems) 'nil]
    [else
     ;; Build nested cons from right to left
     ;; Check if the last element is a ($list-tail ...) sentinel
     (define last-elem (last elems))
     (define-values (proper-elems tail)
       (if (and (list? last-elem)
                (not (null? last-elem))
                (eq? (car last-elem) '$list-tail))
           ;; Tail syntax: the last element is ($list-tail expr)
           (values (drop-right elems 1) (cadr last-elem))
           ;; No tail: terminate with nil
           (values elems 'nil)))
     (foldr (lambda (elem rest) `(cons ,elem ,rest))
            tail
            proper-elems)]))

;; lseq literal: ~[1 2 3] → nested lseq-cell with thunks
;; The WS reader produces ($lseq-literal e1 e2 ...).
;; Expansion:
;;   ($lseq-literal)         → lseq-nil
;;   ($lseq-literal 1 2 3)  → (lseq-cell 1 (fn (_ : Unit) (lseq-cell 2 (fn (_ : Unit) (lseq-cell 3 (fn (_ : Unit) lseq-nil))))))
;; The implicit type parameter {A} of lseq-cell/lseq-nil is inferred
;; by the type checker (same pattern as '[...] list literal using cons/nil).
(define (expand-lseq-literal datum)
  (unless (and (list? datum) (>= (length datum) 1)
               (eq? (car datum) '$lseq-literal))
    (error '$lseq-literal "expected ($lseq-literal ...), got ~a" datum))
  (define elems (cdr datum))
  (foldr (lambda (elem rest)
           `(lseq-cell ,elem (fn (_ : Unit) ,rest)))
         'lseq-nil
         elems))

;; Register built-in pre-parse macros at module load time
(register-preparse-macro! 'let expand-let)
(register-preparse-macro! 'do expand-do)
(register-preparse-macro! 'if expand-if)
(register-preparse-macro! '$list-literal expand-list-literal)
(register-preparse-macro! '$lseq-literal expand-lseq-literal)


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

;; Unit: unit (nullary)
(register-ctor! 'unit (ctor-meta 'Unit '() '() '() 0))
(current-type-meta (hash-set (current-type-meta) 'Unit '(unit)))

;; ========================================
;; Trait metadata registry
;; ========================================
;; Stores metadata about each trait for impl validation and dictionary resolution.

;; trait-method: name (symbol), type-datum (s-expression for the method type)
(struct trait-method (name type-datum) #:transparent)

;; trait-meta: name (symbol), params ((name . type) ...), methods (list of trait-method)
(struct trait-meta (name params methods) #:transparent)

;; Registry: trait-name (symbol) → trait-meta
(define current-trait-registry (make-parameter (hasheq)))

(define (register-trait! name meta)
  (current-trait-registry (hash-set (current-trait-registry) name meta)))

(define (lookup-trait name)
  (hash-ref (current-trait-registry) name #f))

;; ========================================
;; Impl metadata registry
;; ========================================
;; Stores metadata about each impl for dictionary resolution.

;; impl-entry: trait-name (symbol), type-args (list of type datums), dict-name (symbol)
(struct impl-entry (trait-name type-args dict-name) #:transparent)

;; Registry: key (symbol, e.g. "Nat--Eq") → impl-entry
(define current-impl-registry (make-parameter (hasheq)))

(define (register-impl! key entry)
  (current-impl-registry (hash-set (current-impl-registry) key entry)))

(define (lookup-impl key)
  (hash-ref (current-impl-registry) key #f))

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

;; ========================================
;; parse-brace-param-list: parse {A B} or {F : Type -> Type} brace params
;; ========================================
;; Input: list of symbols/tokens after $brace-params sentinel
;;   e.g., (A B)                    for {A B}
;;   e.g., (F : Type -> Type)       for {F : Type -> Type}
;;   e.g., (F : Type -> Type A)     for {F : Type -> Type, A}
;;   e.g., (A B : Type -> Type -> Type) for {A, B : Type -> Type -> Type}
;; Output: alist of ((name . kind) ...) where kind is a type datum
;;   e.g., ((A . (Type 0)) (B . (Type 0)))
;;   e.g., ((F . (-> (Type 0) (Type 0))))
;;
;; Algorithm: find all "symbol :" boundaries to identify param groups.
;; Each "symbol :" starts a kinded param whose kind extends until the next
;; "symbol :" boundary or end of tokens. Any symbols before the first kinded
;; param (or if no colons exist) are bare params with default kind (Type 0).

(define (parse-brace-param-list symbols context-name)
  (define groups (group-brace-params symbols))
  (for/list ([g (in-list groups)])
    (cond
      ;; Kinded: (name : kind-tokens...)
      [(and (>= (length g) 3) (eq? (cadr g) ':))
       (define name (car g))
       (unless (symbol? name)
         (error context-name "~a: parameter name must be a symbol, got ~a" context-name name))
       (define kind-tokens (cddr g))
       ;; Normalize bare 'Type' to '(Type 0)' in kind tokens
       (define normalized-tokens
         (map (lambda (t) (if (eq? t 'Type) '(Type 0) t)) kind-tokens))
       ;; Parse using arrow splitting (reuse existing utilities)
       (define segments (split-on-arrow-datum normalized-tokens))
       (define kind
         (if (= (length segments) 1)
             ;; No arrows — bare kind
             (let ([seg (car segments)])
               (if (= (length seg) 1) (car seg) seg))
             ;; Has arrows — build nested arrow type
             (let* ([domains (drop-right segments 1)]
                    [codomain-seg (last segments)]
                    [codomain (if (= (length codomain-seg) 1)
                                  (car codomain-seg)
                                  codomain-seg)]
                    [domain-types (map (lambda (seg)
                                         (if (= (length seg) 1) (car seg) seg))
                                       domains)])
               (build-arrow-type domain-types codomain))))
       (cons name kind)]
      ;; Bare: (name)
      [(and (= (length g) 1) (symbol? (car g)))
       (cons (car g) '(Type 0))]
      [else
       (error context-name "~a: malformed brace parameter: ~a" context-name g)])))

;; Group a flat list of brace-param tokens into parameter groups.
;; Strategy: find positions of ':' preceded by a symbol. These are kinded param
;; boundaries. Split the token list so each kinded param gets its name + : + kind,
;; and each bare symbol becomes its own group.
(define (group-brace-params tokens)
  (if (null? tokens)
      '()
      (let ()
        (define tvec (list->vector tokens))
        (define n (vector-length tvec))
        ;; Find indices of ':' preceded by a symbol — these are "name :" boundaries
        ;; The param name is at index (colon-idx - 1)
        (define param-start-indices
          (for/list ([i (in-range 1 n)]
                     #:when (and (eq? (vector-ref tvec i) ':)
                                 (symbol? (vector-ref tvec (- i 1)))))
            (- i 1)))  ;; position of the name symbol
        (cond
          ;; No colons — all bare symbols
          [(null? param-start-indices)
           (for/list ([t (in-list tokens)])
             (list t))]
          [else
           ;; Build groups by splitting at param-start boundaries
           ;; Tokens before the first kinded param are bare params
           ;; Tokens between kinded param starts belong to the preceding kind
           (define result '())
           ;; Process bare params before the first kinded param
           (define first-start (car param-start-indices))
           (for ([i (in-range 0 first-start)])
             (set! result (cons (list (vector-ref tvec i)) result)))
           ;; Process each kinded param
           (for ([start-idx (in-list param-start-indices)]
                 [next-idx (in-list (append (cdr param-start-indices) (list n)))])
             (define group
               (for/list ([k (in-range start-idx next-idx)])
                 (vector-ref tvec k)))
             (set! result (cons group result)))
           (reverse result)]))))

;; Parse parameter list in WS or sexp format
;; ($brace-params ...) — implicit type params, optionally with kind annotations
;; WS: (A ($angle-type (Type 0)) B ($angle-type (Type 0)) ...)
;; Sexp: ((A : (Type 0)) (B : (Type 0)) ...)
(define (parse-data-param-list raw)
  (cond
    [(null? raw) '()]
    ;; ($brace-params ...) — implicit type params with optional kind annotations
    [(and (= (length raw) 1)
          (pair? (car raw))
          (list? (car raw))
          (>= (length (car raw)) 2)
          (eq? (car (car raw)) '$brace-params))
     (define symbols (cdr (car raw)))
     (parse-brace-param-list symbols 'data)]
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
                 (define field-type
                   (if (= (length seg) 1)
                       (car seg)  ;; single atom: e.g., A
                       seg))      ;; multi-atom: e.g., (List A)
                 ;; Normalize any infix -> inside grouped types
                 ;; e.g., (Unit -> LSeq A) → (-> Unit (LSeq A))
                 (normalize-infix-arrow-type field-type))
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

;; Normalize a type datum that may contain infix ->
;; Converts (Unit -> LSeq A) → (-> Unit (LSeq A))
;; Leaves (List A) and bare symbols unchanged.
;; Recursively normalizes nested grouped types.
(define (normalize-infix-arrow-type ty)
  (cond
    ;; Not a list — bare atom, leave as-is
    [(not (list? ty)) ty]
    ;; Empty list — leave as-is
    [(null? ty) ty]
    ;; Already prefix -> — normalize children
    [(eq? (car ty) '->)
     (cons '-> (map normalize-infix-arrow-type (cdr ty)))]
    ;; Contains infix -> (e.g., (Unit -> LSeq A))
    ;; Convert to prefix form
    [(memq '-> ty)
     (define segments (split-on-arrow-datum ty))
     (if (= (length segments) 1)
         ;; No actual -> found (shouldn't happen since memq found one)
         (map normalize-infix-arrow-type ty)
         ;; Build prefix arrow from segments
         (let* ([normalized-segs
                 (map (lambda (seg)
                        (define normalized (map normalize-infix-arrow-type seg))
                        (if (= (length normalized) 1)
                            (car normalized)
                            normalized))
                      segments)]
                [domains (drop-right normalized-segs 1)]
                [codomain (last normalized-segs)])
           (build-arrow-type domains codomain)))]
    ;; No infix -> — normalize children
    [else
     (map normalize-infix-arrow-type ty)]))

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
         (define brace-params (parse-brace-param-list symbols 'data))
         (values head brace-params (cdr rest))]
        ;; EXISTING: parse head normally
        [else
         (define-values (tn ps) (parse-data-params head))
         (values tn ps rest)])))

  ;; Zero-constructor types are allowed (uninhabited types like Never/Void)
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

;; ========================================
;; process-trait: trait declarations
;; ========================================
;; Syntax (WS, after reader):
;;   (trait TraitName ($brace-params A) (method1 : T1 -> T2) (method2 : T3))
;;
;; Syntax (sexp):
;;   (trait (TraitName (A : (Type 0))) (method1 : T1 -> T2) (method2 : T3))
;;
;; Generates:
;;   - deftype for the dictionary type
;;     Single-method: (deftype (TraitName A) <method-type>)
;;     Multi-method: (deftype (TraitName A) (Sigma (_ <method1-type>) method2-type...))
;;   - Accessor defs for each method
;;     Single-method: (def trait-method1 : Pi(A :0 Type) -> (TraitName A) -> method1-type
;;                       (fn (dict) dict))
;;     Multi-method: first/second projections
;;   - Trait metadata registered for impl validation
;;
;; Returns: list of s-expression datums

;; Parse a trait method declaration.
;; Input: (method-name : type-atoms...) or (method-name ($angle-type ...) ...)
;; Returns: trait-method struct
(define (parse-trait-method raw trait-name)
  (unless (and (pair? raw) (symbol? (car raw)))
    (error 'trait "trait ~a: method must be (name : type ...), got ~a" trait-name raw))
  (define name (car raw))
  (define rest (cdr raw))
  (cond
    ;; Colon-based: (method : T1 -> T2 -> Result)
    [(and (not (null? rest)) (eq? (car rest) ':))
     (define type-atoms (cdr rest))
     (when (null? type-atoms)
       (error 'trait "trait ~a: method ~a: missing type after ':'" trait-name name))
     ;; Build the method's function type from atoms
     ;; Unlike data ctor, we keep the FULL type (including return type)
     (define segments (split-on-arrow-datum type-atoms))
     (define method-type
       (if (= (length segments) 1)
           ;; Single segment, no arrows — bare type
           (let ([seg (car segments)])
             (if (= (length seg) 1) (car seg) seg))
           ;; Multiple segments — build arrow type
           (let ([domains (drop-right segments 1)]
                 [codomain-seg (last segments)])
             (define codomain
               (if (= (length codomain-seg) 1) (car codomain-seg) codomain-seg))
             (define domain-types
               (map (lambda (seg)
                      (if (= (length seg) 1) (car seg) seg))
                    domains))
             (build-arrow-type domain-types codomain))))
     (trait-method name method-type)]
    ;; Angle-bracket (WS reader): (method ($angle-type T1) ...)
    [(and (not (null? rest))
          (pair? (car rest))
          (eq? (car (car rest)) '$angle-type))
     ;; Extract the type from the angle bracket
     (define type-datum (cadr (car rest)))
     (trait-method name type-datum)]
    [else
     (error 'trait "trait ~a: method ~a must have type annotation (name : type)" trait-name name)]))

;; Build a nested Sigma type from a list of types.
;; (build-sigma-type '(T1 T2 T3)) → (Sigma (_ : T1) (Sigma (_ : T2) T3))
;; Uses (_ : T) binder syntax for proper sexp parsing.
(define (build-sigma-type types)
  (cond
    [(= (length types) 1) (car types)]
    [(= (length types) 2)
     `(Sigma (_ : ,(car types)) ,(cadr types))]
    [else
     `(Sigma (_ : ,(car types)) ,(build-sigma-type (cdr types)))]))

;; Build accessor expression for the i-th element of a nested Sigma.
;; n = total number of methods
;; i = 0-based index
;; dict-expr = the expression to project from
(define (build-sigma-accessor n i dict-expr)
  (cond
    ;; Last element: apply (n-1) `second` projections
    [(= i (- n 1))
     (for/fold ([expr dict-expr])
               ([_ (in-range (- n 1))])
       `(second ,expr))]
    ;; Not last: apply i `second` projections, then `first`
    [else
     (define inner
       (for/fold ([expr dict-expr])
                 ([_ (in-range i)])
         `(second ,expr)))
     `(first ,inner)]))

(define (process-trait datum)
  (unless (and (list? datum) (>= (length datum) 3))
    (error 'trait "trait requires: (trait TraitName {params} method1 method2 ...)"))

  ;; Parse trait name and params (same patterns as data)
  (define-values (trait-name params raw-methods)
    (let ([head (cadr datum)]
          [rest (cddr datum)])
      (cond
        ;; Brace-params: (trait Eq ($brace-params A) ...)
        [(and (symbol? head)
              (not (null? rest))
              (let ([maybe-braces (car rest)])
                (and (pair? maybe-braces)
                     (eq? (car maybe-braces) '$brace-params))))
         (define brace-element (car rest))
         (define symbols (cdr brace-element))
         (define brace-params (parse-brace-param-list symbols 'trait))
         (values head brace-params (cdr rest))]
        ;; Sexp params: (trait (Eq (A : (Type 0))) ...)
        [else
         (define-values (tn ps) (parse-data-params head))
         (values tn ps rest)])))

  (when (null? raw-methods)
    (error 'trait "trait ~a: must have at least one method" trait-name))

  ;; Parse methods
  (define methods
    (map (lambda (m) (parse-trait-method m trait-name)) raw-methods))

  ;; Register trait metadata
  (register-trait! trait-name (trait-meta trait-name params methods))

  ;; ---- Generate the dictionary type ----
  ;; Type params as Pi bindings (all :0)
  (define param-pi-bindings
    (for/list ([p (in-list params)])
      (list (car p) ':0 (cdr p))))

  ;; For parameterized deftype, we need $-prefixed param names
  ;; so process-deftype's pattern-template macro expansion works.
  ;; Map: A → $A in both the deftype pattern and body.
  (define param-name->pvar
    (for/hasheq ([p (in-list params)])
      (values (car p)
              (string->symbol (string-append "$" (symbol->string (car p)))))))

  ;; Substitute param names with $-prefixed versions in a type datum
  (define (pvarify datum)
    (cond
      [(symbol? datum)
       (hash-ref param-name->pvar datum datum)]
      [(pair? datum)
       (map pvarify datum)]
      [else datum]))

  (define method-types (map trait-method-type-datum methods))

  ;; Pvarified method types for the deftype body
  (define pvar-method-types (map pvarify method-types))

  ;; Dictionary type body: single method → bare type, multi → nested Sigma
  (define dict-body
    (if (= (length methods) 1)
        (car pvar-method-types)
        (build-sigma-type pvar-method-types)))

  ;; deftype pattern: (TraitName $A $B ...) or bare TraitName
  (define deftype-pattern
    (if (null? params)
        trait-name
        `(,trait-name ,@(map (lambda (p) (hash-ref param-name->pvar (car p))) params))))

  ;; deftype datum with $-prefixed params for pattern-template expansion
  (define deftype-datum `(deftype ,deftype-pattern ,dict-body))

  ;; Process deftype to register it as a pre-parse macro
  (process-deftype deftype-datum)

  ;; ---- Generate accessor definitions ----
  ;; Each accessor takes type params + a dict, and projects the right field.
  ;; Single method: accessor is identity (dict IS the function)
  ;; Multi method: accessor projects from nested Sigma

  (define n-methods (length methods))

  ;; Applied trait type: (TraitName A B ...) or bare TraitName
  (define applied-trait-type
    (if (null? params)
        trait-name
        `(,trait-name ,@(map car params))))

  (define accessor-defs
    (for/list ([method (in-list methods)]
               [i (in-naturals)])
      (define method-name (trait-method-name method))
      (define method-type (trait-method-type-datum method))
      ;; Accessor name: TraitName-methodname
      (define accessor-name
        (string->symbol
         (string-append (symbol->string trait-name)
                        "-"
                        (symbol->string method-name))))

      ;; Accessor type: Pi(A :0 Type 0) ... -> TraitName A -> method-type
      (define accessor-type
        (build-nested-pi
         param-pi-bindings
         (build-arrow-type (list applied-trait-type) method-type)))

      ;; Accessor body: fn that projects from dict
      ;; For single-method: (fn (dict <TraitType>) dict)
      ;; For multi-method: (fn (dict <TraitType>) (first/second... dict))
      (define dict-var 'dict)
      (define projection
        (if (= n-methods 1)
            dict-var
            (build-sigma-accessor n-methods i dict-var)))

      (define inner-fn
        `(fn (,dict-var : ,applied-trait-type) ,projection))
      (define accessor-body
        (if (null? params)
            inner-fn
            (build-nested-fn param-pi-bindings inner-fn)))

      `(def ,accessor-name : ,accessor-type ,accessor-body)))

  ;; Return the accessor defs (deftype was already processed via process-deftype)
  accessor-defs)

;; ========================================
;; process-impl: trait implementation
;; ========================================
;; Syntax (WS, after reader):
;;   (impl TraitName TypeArg1 TypeArg2 ...
;;     (defn method1 [params] <ReturnType> body1)
;;     (defn method2 [params] <ReturnType> body2))
;;
;; Sexp:
;;   (impl TraitName TypeArg1 ...
;;     (defn method1 (x : T1) ... : Ret body)
;;     ...)
;;
;; Generates:
;;   (def TypeArg--TraitName--dict : (TraitName TypeArg) dict-value)
;;
;; For single-method traits: dict value is the bare fn
;; For multi-method traits: dict value is (pair fn1 (pair fn2 ...)) nested
;;
;; Returns: list of s-expression datums (just the dict def)

;; Build a nested pair expression from a list of expressions.
;; (build-nested-pair '(e1 e2 e3)) → (pair e1 (pair e2 e3))
(define (build-nested-pair exprs)
  (cond
    [(= (length exprs) 1) (car exprs)]
    [(= (length exprs) 2)
     `(pair ,(car exprs) ,(cadr exprs))]
    [else
     `(pair ,(car exprs) ,(build-nested-pair (cdr exprs)))]))

;; Extract method body from a defn datum.
;; Input: (defn name [params] <RetType> body) or (defn name (p : T) ... : Ret body)
;; Returns: the full defn datum as-is (will be processed by preparse later)
;; We extract just the defn body parts and build an fn expression.
(define (impl-method-to-fn defn-datum)
  ;; The defn datum is a full defn form. We want to return it as a defn
  ;; that gets processed normally. But for impl, we need to convert
  ;; the defn body into a lambda for the dictionary.
  ;;
  ;; Strategy: return the defn as-is. The impl will emit individual defn forms
  ;; for each method, plus a dictionary def that references them.
  defn-datum)

(define (process-impl datum)
  (unless (and (list? datum) (>= (length datum) 4))
    (error 'impl "impl requires: (impl TraitName TypeArgs... method-defn1 method-defn2 ...)"))

  (define trait-name (cadr datum))
  (unless (symbol? trait-name)
    (error 'impl "impl: trait name must be a symbol, got ~a" trait-name))

  ;; Look up trait metadata
  (define tm (lookup-trait trait-name))
  (unless tm
    (error 'impl "impl: unknown trait ~a (must be declared with 'trait' first)" trait-name))

  (define expected-methods (trait-meta-methods tm))
  (define n-expected (length expected-methods))

  ;; Parse type args and method defns from the rest of the datum
  ;; The structure is: (impl TraitName type-arg1 ... method-defn1 method-defn2 ...)
  ;; Type args are symbols/lists that are NOT defn forms.
  ;; Method defns are lists starting with 'defn.
  (define rest-after-trait (cddr datum))

  ;; Split into type-args and method-defns
  (define-values (type-args method-defns)
    (let loop ([remaining rest-after-trait]
               [targs '()])
      (cond
        [(null? remaining)
         (values (reverse targs) '())]
        [(and (pair? (car remaining))
              (eq? (caar remaining) 'defn))
         (values (reverse targs) remaining)]
        [else
         (loop (cdr remaining) (cons (car remaining) targs))])))

  (when (null? type-args)
    (error 'impl "impl ~a: must specify at least one type argument" trait-name))

  ;; Validate method count
  (unless (= (length method-defns) n-expected)
    (error 'impl "impl ~a: expected ~a method(s), got ~a"
           trait-name n-expected (length method-defns)))

  ;; Validate method names match trait declaration (in order)
  (for ([defn-d (in-list method-defns)]
        [expected-m (in-list expected-methods)]
        [i (in-naturals)])
    (define defn-name (and (list? defn-d) (>= (length defn-d) 2) (cadr defn-d)))
    (define expected-name (trait-method-name expected-m))
    (unless (eq? defn-name expected-name)
      (error 'impl "impl ~a: method ~a at position ~a should be '~a', got '~a'"
             trait-name trait-name i expected-name defn-name)))

  ;; Generate dictionary name: TypeArg1--TraitName--dict
  ;; For single type arg: "Nat--Eq--dict"
  ;; For multiple: "Nat-Bool--Convert--dict"
  (define type-arg-str
    (string-join
     (map (lambda (ta)
            (if (symbol? ta)
                (symbol->string ta)
                (format "~a" ta)))
          type-args)
     "-"))
  (define dict-name
    (string->symbol
     (string-append type-arg-str "--" (symbol->string trait-name) "--dict")))

  ;; Generate the applied trait type: (TraitName TypeArg1 TypeArg2 ...)
  (define applied-trait-type
    (if (= (length type-args) 1)
        (let ([ta (car type-args)])
          (if (null? (trait-meta-params tm))
              trait-name
              `(,trait-name ,ta)))
        `(,trait-name ,@type-args)))

  ;; Generate method helper defns (each method gets its own top-level defn)
  ;; Method defn names are scoped: TypeArg--TraitName--method-name
  (define method-helper-names
    (for/list ([defn-d (in-list method-defns)])
      (define method-name (cadr defn-d))
      (string->symbol
       (string-append type-arg-str "--" (symbol->string trait-name)
                      "--" (symbol->string method-name)))))

  ;; Rewrite each defn with scoped name
  (define method-helper-defns
    (for/list ([defn-d (in-list method-defns)]
               [helper-name (in-list method-helper-names)])
      (cons 'defn (cons helper-name (cddr defn-d)))))

  ;; Build dictionary value: for single-method, just the helper name.
  ;; For multi-method, (pair helper1 (pair helper2 helper3))
  (define dict-value
    (if (= n-expected 1)
        (car method-helper-names)
        (build-nested-pair method-helper-names)))

  ;; Dictionary def: (def dict-name : applied-trait-type dict-value)
  (define dict-def
    `(def ,dict-name : ,applied-trait-type ,dict-value))

  ;; Register impl in the registry
  (define impl-key
    (string->symbol (string-append type-arg-str "--" (symbol->string trait-name))))
  (register-impl! impl-key (impl-entry trait-name type-args dict-name))

  ;; Return all definitions: helper defns + dict def
  ;; For single-method, still emit the helper defn too (for direct use by name)
  (append method-helper-defns (list dict-def)))


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
      (surf-infer? surf)
      (surf-expand? surf)
      (surf-parse? surf)
      (surf-elaborate? surf)))

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
      [(surf-arrow _ domain codomain _loc)
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
      [(surf-posit16-type _) (void)]
      [(surf-posit32-type _) (void)]
      [(surf-posit64-type _) (void)]
      [(surf-quire8-type _) (void)]
      [(surf-quire16-type _) (void)]
      [(surf-quire32-type _) (void)]
      [(surf-quire64-type _) (void)]
      [(surf-keyword-type _) (void)]
      [(surf-keyword _ _) (void)]
      ;; Map type: walk key and value type sub-expressions
      [(surf-map-type k v _loc)
       (walk k) (walk v)]
      ;; Set type: walk element type
      [(surf-set-type a _loc)
       (walk a)]
      ;; PVec type: walk element type
      [(surf-pvec-type a _loc)
       (walk a)]
      [(surf-pvec-literal elems _loc)
       (for-each walk elems)]
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
    posit8 p8+ p8- p8* p8/ p8-neg p8-abs p8-sqrt p8< p8<= p8-from-nat p8-if-nar
    Posit16 posit16 p16+ p16- p16* p16/ p16-neg p16-abs p16-sqrt p16-lt p16-le p16-from-nat p16-if-nar
    Posit32 posit32 p32+ p32- p32* p32/ p32-neg p32-abs p32-sqrt p32-lt p32-le p32-from-nat p32-if-nar
    Posit64 posit64 p64+ p64- p64* p64/ p64-neg p64-abs p64-sqrt p64-lt p64-le p64-from-nat p64-if-nar
    Quire8 q8-zero q8-fma q8-to
    Quire16 q16-zero q16-fma q16-to
    Quire32 q32-zero q32-fma q32-to
    Quire64 q64-zero q64-fma q64-to
    Int int int+ int- int* int/ int-mod int-neg int-abs int-lt int-le int-eq from-nat
    Rat rat rat+ rat- rat* rat/ rat-neg rat-abs rat-lt rat-le rat-eq from-int rat-numer rat-denom
    Keyword Map map-empty map-assoc map-get map-dissoc map-size map-has-key? map-keys map-vals
    Set set-empty set-insert set-member? set-delete set-size set-union set-intersect set-diff set-to-list
    PVec pvec-empty pvec-push pvec-nth pvec-update pvec-length pvec-pop pvec-concat pvec-slice))

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
    [(surf-arrow _ domain codomain _loc)
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
    ;; Placeholder desugaring: _ in app args → anonymous lambda
    ;; (add 1 _) → (fn [$_0] (add 1 $_0))
    ;; (clamp _ 100 _) → (fn [$_0] (fn [$_1] (clamp $_0 100 $_1)))
    ;; Positional placeholders: _N (1-based) control lambda ordering
    ;; (f _2 zero _1) → (fn [$_1] (fn [$_2] (f $_2 zero $_1)))
    [(surf-app fn args loc)
     (define has-plain (ormap surf-hole? args))
     (define has-numbered (ormap surf-numbered-hole? args))
     (cond
       ;; Error: cannot mix plain _ and numbered _N
       [(and has-plain has-numbered)
        (error 'expand-expression
               "cannot mix plain _ and numbered _N placeholders in the same application")]
       ;; Plain holes: existing sequential behavior
       [has-plain
        (let* ([hole-count (count surf-hole? args)]
               [names (for/list ([i (in-range hole-count)])
                        (string->symbol (format "$_~a" i)))]
               [new-args (let loop ([as args] [ns names])
                           (cond
                             [(null? as) '()]
                             [(surf-hole? (car as))
                              (cons (surf-var (car ns) loc) (loop (cdr as) (cdr ns)))]
                             [else (cons (car as) (loop (cdr as) ns))]))]
               [new-app (surf-app fn new-args loc)]
               [result (foldr (lambda (name inner)
                                (surf-lam (binder-info name #f (surf-hole loc)) inner loc))
                              new-app names)])
          (expand-expression result))]
       ;; Numbered holes: positional placeholders with explicit ordering
       [has-numbered
        (let* (;; Collect all indices
               [indices (for/list ([a (in-list args)]
                                   #:when (surf-numbered-hole? a))
                          (surf-numbered-hole-index a))]
               ;; Check for duplicates
               [_ (unless (= (length indices) (length (remove-duplicates indices)))
                    (error 'expand-expression
                           "duplicate numbered placeholder indices: ~a" indices))]
               ;; Sort indices ascending — smallest index = outermost lambda
               [sorted-indices (sort indices <)]
               ;; Create name map: index → $_N symbol
               [name-map (for/hasheq ([idx (in-list sorted-indices)])
                           (values idx (string->symbol (format "$_~a" idx))))]
               ;; Replace each numbered hole with its corresponding surf-var
               [new-args (for/list ([a (in-list args)])
                           (if (surf-numbered-hole? a)
                               (surf-var (hash-ref name-map (surf-numbered-hole-index a)) loc)
                               a))]
               [new-app (surf-app fn new-args loc)]
               ;; Wrap in nested lambdas ordered by sorted indices
               ;; sorted ascending: _1 outermost, _2 next, etc.
               [result (foldr (lambda (idx inner)
                                (surf-lam (binder-info (hash-ref name-map idx)
                                                       #f (surf-hole loc))
                                          inner loc))
                              new-app sorted-indices)])
          (expand-expression result))]
       ;; No holes: just recurse on sub-expressions
       [else
        (surf-app (expand-expression fn) (map expand-expression args) loc)])]
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
    [(surf-arrow m dom cod loc)
     (surf-arrow m (expand-expression dom) (expand-expression cod) loc)]
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
;; Expand multi-body defn → surf-def-group
;; ========================================
;; Each clause becomes a separate surf-def with an internal name (name/N).
;; The surf-def-group carries the dispatch metadata.
(define (expand-defn-multi form)
  (match form
    [(surf-defn-multi name docstring clauses loc)
     ;; Compute arities (explicit param count per clause)
     (define arities
       (for/list ([clause (in-list clauses)])
         (length (defn-clause-param-names clause))))
     ;; Check for duplicate arities
     (if (not (= (length arities) (length (remove-duplicates arities))))
       (prologos-error loc
         (format "defn ~a: multiple clauses with the same arity" name))
       ;; Expand each clause through the normal defn pipeline
       (let ()
         (define expanded-defs
           (for/list ([clause (in-list clauses)]
                      [arity (in-list arities)])
             (define internal-name
               (string->symbol (format "~a::~a" name arity)))
             ;; Wrap as surf-defn for existing pipeline
             (define as-defn
               (surf-defn internal-name
                          (defn-clause-type clause)
                          (defn-clause-param-names clause)
                          (defn-clause-body clause)
                          (defn-clause-srcloc clause)))
             ;; Apply auto-implicits then desugar to surf-def
             (define with-implicits (infer-auto-implicits as-defn))
             (define desugared (desugar-defn with-implicits))
             (if (prologos-error? desugared)
                 desugared
                 (expand-top-level desugared))))
         ;; Check for errors in expansion
         (define first-err (findf prologos-error? expanded-defs))
         (cond
           [first-err first-err]
           [else
            ;; Build arity-map for dispatch
            (define arity-map
              (for/fold ([m (hasheq)])
                        ([clause (in-list clauses)]
                         [arity (in-list arities)])
                (hash-set m arity
                          (string->symbol (format "~a::~a" name arity)))))
            (surf-def-group name expanded-defs arities docstring loc)])))]))

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
    ;; Multi-body defn: expand each clause, produce surf-def-group
    [(surf-defn-multi? surf)
     (expand-defn-multi surf)]
    ;; surf-def-group: already expanded, pass through
    [(surf-def-group? surf) surf]
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
    ;; Inspection commands — expand/parse pass through as-is,
    ;; elaborate expands its sub-expression (consistent with eval/infer)
    [(surf-expand? surf) surf]
    [(surf-parse? surf) surf]
    [(surf-elaborate? surf)
     (surf-elaborate (expand-expression (surf-elaborate-expr surf))
                     (surf-elaborate-srcloc surf))]
    ;; Bare expression — implicit eval
    [else
     (define loc (cond
                   [(surf-var? surf) (surf-var-srcloc surf)]
                   [(surf-app? surf) (surf-app-srcloc surf)]
                   [(surf-ann? surf) (surf-ann-srcloc surf)]
                   [else srcloc-unknown]))
     (surf-eval (expand-expression surf) loc)]))
