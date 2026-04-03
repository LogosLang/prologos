#lang racket/base

;;;
;;; tree-parser.rkt — Parse form-tree nodes directly to surf-* ASTs
;;;
;;; PPN Track 2 Phase 6c: Eliminates the datum layer entirely.
;;; Replaces: read-all-forms-from-tree (tree → datums) + parse-datum (datums → surf-*)
;;; With: parse-form-tree (tree → surf-* directly)
;;;
;;; The form tree (after G(0) grouping) has nodes with:
;;;   - tag: form identity (:defn, :def, :if, etc.)
;;;   - children: bracket-grouped sub-nodes + token entries
;;;   - srcloc: source location
;;;   - indent: indent level
;;;
;;; This is a mechanical translation of parser.rkt's parse-datum/parse-list,
;;; reading from tree node children instead of datum lists.
;;;

(require racket/list
         racket/string
         racket/set
         "parse-reader.rkt"
         "surface-syntax.rkt"
         "surface-rewrite.rkt"
         "rrb.rkt"
         "errors.rkt"
         ;; Phase 1a: process-data/trait/impl reuse
         "macros.rkt"
         "parser.rkt")

(provide parse-form-tree
         parse-top-level-forms-from-tree
         parse-subtree-via-datum
         current-source-str
         current-raw-node
         ;; §11 WS normalizations (used by form-cells.rkt datum path too)
         flatten-ws-datum
         restructure-infix-eq
         normalize-ws-tokens)

;; ========================================
;; Helpers: reading from tree nodes
;; ========================================

;; Get a tree node's children as a list
(define (node-children node)
  (if (parse-tree-node? node)
      (rrb-to-list (parse-tree-node-children node))
      '()))

;; Get source location from a node or token
(define (item-srcloc item)
  (cond
    [(parse-tree-node? item) (parse-tree-node-srcloc item)]
    [(token-entry? item) (list 0 0 (token-entry-start-pos item)
                                (token-entry-end-pos item))]
    [else #f]))

;; Get the lexeme string from a token entry
(define (token-lexeme item)
  (and (token-entry? item) (token-entry-lexeme item)))

;; Get the lexeme as a symbol
(define (token-symbol item)
  (and (token-entry? item) (string->symbol (token-entry-lexeme item))))

;; Check if item is a token with given lexeme
(define (token-is? item lex)
  (and (token-entry? item) (equal? (token-entry-lexeme item) lex)))

;; Get children after the head token (the "args")
(define (node-args node)
  (if (parse-tree-node? node)
      (let ([children (node-children node)])
        (if (and (pair? children) (token-entry? (car children)))
            (cdr children)  ;; skip head token
            children))
      '()))

;; ========================================
;; Main dispatch: parse a form-tree node → surf-*
;; ========================================

(define (parse-form-tree node)
  (cond
    ;; Token entry (leaf) → parse as atom
    [(token-entry? node)
     (parse-token-atom node)]

    ;; Parse-tree-node → dispatch by tag
    [(parse-tree-node? node)
     (define tag (parse-tree-node-tag node))
     (define loc (item-srcloc node))
     (define children (node-children node))
     (define args (node-args node))

     (case tag
       ;; --- Top-level forms ---
       ;; §11: when source-str is set (cell pipeline), use datum conversion
       ;; on the WHOLE node for correct keyword handling + postfix/dot-access.
       ;; This makes parse-form-tree the ON-NETWORK dispatch point while
       ;; parse-datum remains the canonical expression parser.
       ;; §11: ALL top-level forms use datum conversion when source-str set
       [(def defn defn-multi spec eval check infer
         strategy session defproc defr solver subtype selection capability foreign)
        (if (not (equal? (current-source-str) ""))
            (parse-eval-tree-for-cell node loc)  ;; datum conversion on whole node
            ;; Legacy path (merge/non-cell context)
            (case tag
              [(def) (parse-def-tree args loc)]
              [(defn) (parse-defn-tree args loc)]
              [(spec) (parse-spec-tree args loc)]
              [(eval) (parse-eval-tree args loc)]
              [(check) (parse-check-tree args loc)]
              [(infer) (parse-infer-tree args loc)]
              [(subtype) (parse-subtype-tree args loc)]
              [(selection) (parse-selection-tree args loc)]
              [else (parse-error-result loc (format "Unhandled form: ~a" tag))]))]
       [(data) (parse-data-tree args loc)]
       [(trait) (parse-trait-tree args loc)]
       [(impl) (parse-impl-tree args loc)]

       ;; --- Expression forms ---
       [(if) (parse-if-tree args loc)]
       [(when) (parse-when-tree args loc)]
       [(expr) (parse-expr-tree children loc)]
       [(bracket-group) (parse-bracket-group-tree children loc)]
       [(angle-group) (parse-angle-group-tree children loc)]
       [(brace-group) (parse-brace-group-tree children loc)]
       [(paren-group) (parse-paren-group-tree children loc)]
       [(group) (parse-group-tree children loc)]

       ;; --- Sentinel forms ---
       [(list-literal list-literal-group) (parse-list-literal-tree children loc)]
       [(quote) (parse-quote-tree args loc)]

       ;; --- Session forms ---
       [(session) (parse-session-tree args loc)]
       [(defproc) (parse-defproc-tree args loc)]

       ;; --- Relational ---
       [(defr) (parse-defr-tree args loc)]
       [(solver) (parse-solver-tree args loc)]

       ;; --- Module ---
       [(ns) (parse-ns-tree args loc)]
       [(imports) (parse-imports-tree args loc)]
       [(exports) (parse-exports-tree args loc)]

       ;; --- Expression-level sentinels (deferred to preparse) ---
       ;; These are rewritten by preparse-expand-form (mixfix Pratt parser,
       ;; pipe/compose expansion) but NOT by surface-rewrite.rkt. The tree
       ;; parser returns errors so the merge uses preparse's version.
       [(mixfix mixfix-group) (parse-error-result loc "mixfix: handled by preparse expansion")]
       [(pipe-gt) (parse-error-result loc "pipe-gt: handled by preparse expansion")]
       [(compose) (parse-error-result loc "compose: handled by preparse expansion")]
       [(dot-access) (parse-error-result loc "dot-access: handled by preparse expansion")]
       [(dot-key) (parse-error-result loc "dot-key: handled by preparse expansion")]
       [(infix-pipe) (parse-error-result loc "infix-pipe: handled by preparse expansion")]
       [(implicit-map) (parse-error-result loc "implicit-map: handled by preparse expansion")]

       ;; --- Phase 1b: parseable preparse-consumed forms ---
       [(subtype) (parse-subtype-tree args loc)]

       ;; --- Preparse-consumed forms (remaining stubs) ---
       ;; These are handled by preparse: registration, generation, or specialized
       ;; desugaring. The tree parser returns explicit errors so the merge's
       ;; error filter catches them. Without these stubs, the `else` fallthrough
       ;; would call parse-expr-tree and produce garbage surf-app nodes.
       [(bundle) (parse-error-result loc "bundle: consumed by preparse")]
       [(capability) (parse-error-result loc "capability: consumed by preparse")]
       [(defmacro) (parse-error-result loc "defmacro: consumed by preparse")]
       [(deftype) (parse-error-result loc "deftype: consumed by preparse")]
       [(foreign) (parse-error-result loc "foreign: consumed by preparse")]
       [(functor) (parse-error-result loc "functor: consumed by preparse")]
       [(precedence-group) (parse-error-result loc "precedence-group: consumed by preparse")]
       [(proc) (parse-error-result loc "proc: consumed by preparse")]
       [(property) (parse-error-result loc "property: consumed by preparse")]
       [(schema) (parse-error-result loc "schema: consumed by preparse")]
       [(selection) (parse-selection-tree args loc)]
       [(spawn) (parse-error-result loc "spawn: consumed by preparse")]
       [(spawn-with) (parse-error-result loc "spawn-with: consumed by preparse")]
       [(specialize) (parse-error-result loc "specialize: consumed by preparse")]
       [(strategy) (parse-error-result loc "strategy: consumed by preparse")]

       ;; --- Fall through ---
       [else
        ;; Unknown tag — try as expression
        (if (pair? children)
            (parse-expr-tree children loc)
            (parse-error-result loc (format "Unknown form tag: ~a" tag)))])]

    [else (parse-error-result #f "Cannot parse: not a node or token")]))

;; ========================================
;; Atom parsing (token entries)
;; ========================================

(define (parse-token-atom token)
  (define lex (token-entry-lexeme token))
  (define loc (item-srcloc token))
  (define s (string->symbol lex))

  (cond
    ;; Boolean literals
    [(equal? lex "true") (surf-true loc)]
    [(equal? lex "false") (surf-false loc)]

    ;; Unit
    [(equal? lex "unit") (surf-unit loc)]

    ;; Hole
    [(equal? lex "_") (surf-hole loc)]

    ;; Type keywords
    [(equal? lex "Type") (surf-type 0 loc)]
    [(equal? lex "Nat") (surf-nat-type loc)]
    [(equal? lex "Int") (surf-int-type loc)]
    [(equal? lex "String") (surf-string-type loc)]
    [(equal? lex "Bool") (surf-bool-type loc)]
    [(equal? lex "Char") (surf-char-type loc)]
    [(equal? lex "Nil") (surf-nil-type loc)]

    ;; Keyword literal :name
    [(and (> (string-length lex) 1) (char=? (string-ref lex 0) #\:))
     (surf-keyword (string->symbol (substring lex 1)) loc)]

    ;; Number — integer
    [(string->number lex)
     => (lambda (n)
          (cond
            [(and (exact-integer? n) (>= n 0)) (surf-int-lit n loc)]
            [(exact-integer? n) (surf-int-lit n loc)]
            [(rational? n) (surf-rat-lit n loc)]
            [else (surf-var s loc)]))]

    ;; Nat literal: 42N
    [(and (> (string-length lex) 1)
          (char=? (string-ref lex (- (string-length lex) 1)) #\N))
     (let ([num-str (substring lex 0 (- (string-length lex) 1))])
       (define v (string->number num-str))
       (if (and v (exact-nonnegative-integer? v))
           (if (= v 0) (surf-zero loc) (surf-nat-lit v loc))
           (surf-var s loc)))]

    ;; String literal
    [(and (> (string-length lex) 1)
          (char=? (string-ref lex 0) #\")
          (char=? (string-ref lex (- (string-length lex) 1)) #\"))
     (surf-string (substring lex 1 (- (string-length lex) 1)) loc)]

    ;; Char literal
    [(char? (string-ref lex 0))
     ;; Check for #\char format
     (if (and (> (string-length lex) 2)
              (char=? (string-ref lex 0) #\#)
              (char=? (string-ref lex 1) #\\))
         (let ([char-name (substring lex 2)])
           (surf-char (cond
                        [(= (string-length char-name) 1) (string-ref char-name 0)]
                        [(equal? char-name "newline") #\newline]
                        [(equal? char-name "space") #\space]
                        [(equal? char-name "tab") #\tab]
                        [else (string-ref char-name 0)])
                      loc))
         ;; Regular symbol
         (surf-var s loc))]

    ;; Default: variable reference
    [else (surf-var s loc)]))

;; §11: Sub-expression parsing via datum conversion.
;; Converts a tree-node to datum via tree-node->stx-form, then
;; preparse-expand-single + parse-datum. Produces surfs IDENTICAL
;; to the datum path (correct keyword handling, motive annotations, etc.)
(define current-source-str (make-parameter ""))
(define current-raw-node (make-parameter #f))  ;; §11: raw node for datum conversion

(define (parse-subtree-via-datum node)
  (define stx (tree-node->stx-form node "<tree>" (current-source-str)))
  (if (not stx)
      (parse-form-tree node)
      (let ([datum (syntax->datum stx)])
        (with-handlers ([exn:fail? (lambda (e) (parse-form-tree node))])
          (define expanded (preparse-expand-single datum))
          (parse-datum (datum->syntax #f expanded))))))

;; ========================================
;; Built-in operation dispatch tables
;; ========================================

(define builtin-binary-ops
  (hash
   ;; Integer arithmetic
   "int+" surf-int-add  "int-" surf-int-sub  "int*" surf-int-mul
   "int/" surf-int-div  "int%" surf-int-mod
   "int=" surf-int-eq   "int<" surf-int-lt   "int<=" surf-int-le
   ;; Generic arithmetic (trait-dispatched)
   "+" surf-generic-add  "-" surf-generic-sub  "*" surf-generic-mul
   "/" surf-generic-div  "%" surf-generic-mod
   "=" surf-generic-eq   "<" surf-generic-lt   "<=" surf-generic-le
   ">" surf-generic-gt   ">=" surf-generic-ge
   "eq?" surf-generic-eq
   ;; Map operations
   "map-get" surf-map-get  "map-assoc" surf-map-assoc
   ;; Pair
   "pair" surf-pair
   ;; From-int / from-nat
   "from-int" surf-from-int  "from-nat" surf-from-nat
   ))

(define builtin-unary-ops
  (hash
   ;; Integer
   "int-neg" surf-int-neg  "int-abs" surf-int-abs
   ;; Generic
   "negate" surf-generic-negate  "abs" surf-generic-abs
   ;; Pair projections
   "fst" surf-fst  "snd" surf-snd
   ;; Boolean
   "not" surf-not
   ;; Nat
   "suc" surf-suc
   ))

;; ========================================
;; Stub implementations for form parsing
;; ========================================
;; These will be fleshed out as we translate each parse-* function.
;; For now, they provide the structure for the dispatch.

(define (parse-error-result loc msg)
  (prologos-error loc msg))

(define (parse-def-tree args loc)
  ;; Tree args (after def token): [name, maybe-type-annotation, body]
  ;; Variants:
  ;;   [name, body] — 2 args, type inferred
  ;;   [name, <angle-group>, body] — 3 args, angle-type annotation
  ;;   [name, :, type, body] — 4+ args, colon annotation
  (cond
    ;; 2 args: (def name body)
    [(= (length args) 2)
     (define name (token-symbol (car args)))
     (if (not name)
         (parse-error-result loc (format "def: expected name, got ~a" (car args)))
         (let ([bd (parse-form-tree (cadr args))])
           (if (prologos-error? bd) bd
               (surf-def name #f bd loc))))]
    ;; 3 args with := : (def name := body)
    [(and (= (length args) 3)
          (token-is? (cadr args) ":="))
     (define name (token-symbol (car args)))
     (if (not name)
         (parse-error-result loc "def: expected name")
         (let ([bd (parse-form-tree (caddr args))])
           (if (prologos-error? bd) bd
               (surf-def name #f bd loc))))]
    ;; 5+ args: (def name : Type := body...) — colon type annotation with :=
    [(and (>= (length args) 5)
          (token-is? (cadr args) ":")
          ;; Find := position
          (for/or ([item (in-list args)] [i (in-naturals)])
            (and (token-is? item ":=") i)))
     (define name (token-symbol (car args)))
     (define assign-idx (for/or ([item (in-list args)] [i (in-naturals)])
                          (and (token-is? item ":=") i)))
     (if (not name)
         (parse-error-result loc "def: expected name")
         (let* ([type-items (drop (take args assign-idx) 2)]  ;; between : and :=
                [body-items (drop args (+ assign-idx 1))]     ;; after :=
                [type-surf (if (= (length type-items) 1)
                               (parse-form-tree (car type-items))
                               (parse-expr-tree type-items loc))]
                [bd (cond
                      [(null? body-items) (parse-error-result loc "def: need body")]
                      [(= (length body-items) 1) (parse-form-tree (car body-items))]
                      [else (parse-expr-items body-items loc)])])
           (cond
             [(prologos-error? type-surf) type-surf]
             [(prologos-error? bd) bd]
             [else (surf-def name type-surf bd loc)])))]
    ;; 4+ args with := at position 1: (def name := body-items...)
    ;; body-items may be: single expression, type + body, or let-chain
    [(and (>= (length args) 4)
          (token-is? (cadr args) ":="))
     (define name (token-symbol (car args)))
     (if (not name)
         (parse-error-result loc "def: expected name")
         (let* ([body-items (cddr args)]  ;; everything after :=
                ;; Check if first item after := is an angle-group (type annotation)
                [has-type? (and (pair? body-items)
                                (parse-tree-node? (car body-items))
                                (eq? (parse-tree-node-tag (car body-items)) 'angle-group))]
                [type-surf (if has-type? (parse-form-tree (car body-items)) #f)]
                [rest-items (if has-type? (cdr body-items) body-items)]
                ;; Parse body: single item → parse directly; multiple → expr sequence
                [bd (cond
                      [(null? rest-items) (parse-error-result loc "def: need body")]
                      [(= (length rest-items) 1) (parse-form-tree (car rest-items))]
                      [else (parse-expr-items rest-items loc)])])
           (cond
             [(prologos-error? bd) bd]
             [(and has-type? (prologos-error? type-surf)) type-surf]
             [else (surf-def name (and has-type? type-surf) bd loc)])))]
    ;; 3 args: (def name <type> body) or (def name body-expr)
    [(= (length args) 3)
     (define name (token-symbol (car args)))
     (if (not name)
         (parse-error-result loc "def: expected name")
         (let ([second (cadr args)])
           (if (and (parse-tree-node? second)
                    (eq? (parse-tree-node-tag second) 'angle-group))
               ;; Angle-type annotation
               (let ([ty (parse-form-tree second)]
                     [bd (parse-form-tree (caddr args))])
                 (cond
                   [(prologos-error? ty) ty]
                   [(prologos-error? bd) bd]
                   [else (surf-def name ty bd loc)]))
               ;; Not angle — might be colon annotation or body
               (if (token-is? second ":")
                   (parse-error-result loc "def with : needs type AND body (4 args)")
                   ;; Treat as (def name expr1 expr2) — application?
                   (let ([bd (parse-application-tree (cdr args) loc)])
                     (if (prologos-error? bd) bd
                         (surf-def name #f bd loc)))))))]
    ;; 4+ args: various forms with type annotations and/or :=
    [(>= (length args) 4)
     (define name (token-symbol (car args)))
     (if (not name)
         (parse-error-result loc "def: expected name")
         (let ([second (cadr args)])
           (cond
             ;; (def name : type := body) — 5+ args, colon + assign
             [(and (token-is? second ":")
                   (>= (length args) 5)
                   (token-is? (list-ref args 3) ":="))
              (let ([ty (parse-form-tree (caddr args))]
                    [bd (parse-form-tree (list-ref args 4))])
                (cond
                  [(prologos-error? ty) ty]
                  [(prologos-error? bd) bd]
                  [else (surf-def name ty bd loc)]))]
             ;; (def name : type body) — 4 args, colon without :=
             [(token-is? second ":")
              (let ([ty (parse-form-tree (caddr args))]
                    [bd (parse-form-tree (cadddr args))])
                (cond
                  [(prologos-error? ty) ty]
                  [(prologos-error? bd) bd]
                  [else (surf-def name ty bd loc)]))]
             ;; (def name <type> := body) — angle + assign
             [(and (parse-tree-node? second)
                   (eq? (parse-tree-node-tag second) 'angle-group)
                   (>= (length args) 4)
                   (token-is? (caddr args) ":="))
              (let ([ty (parse-form-tree second)]
                    [bd (parse-form-tree (cadddr args))])
                (cond
                  [(prologos-error? ty) ty]
                  [(prologos-error? bd) bd]
                  [else (surf-def name ty bd loc)]))]
             ;; (def name <type> body) — angle without :=
             [(and (parse-tree-node? second)
                   (eq? (parse-tree-node-tag second) 'angle-group))
              (let ([ty (parse-form-tree second)]
                    [bd (if (= (length args) 4)
                            (parse-form-tree (caddr args))
                            (parse-application-tree (cddr args) loc))])
                (cond
                  [(prologos-error? ty) ty]
                  [(prologos-error? bd) bd]
                  [else (surf-def name ty bd loc)]))]
             [else
              (parse-error-result loc "def: unexpected format")])))]
    [else
     (parse-error-result loc "def: need at least name + body")]))

(define (parse-defn-tree args loc)
  ;; Produce surf-defn (NOT surf-def). Let expand-top-level handle:
  ;;   infer-auto-implicits → desugar-defn → nested lambdas.
  ;; The tree parser's job is PARSING, not DESUGARING.
  ;; surf-defn: (name type param-names body srcloc)
  (cond
    [(< (length args) 2)
     (parse-error-result loc "defn: need name + params + body")]
    [else
     (define name (token-symbol (car args)))
     (cond
       [(not name)
        (parse-error-result loc "defn: expected name")]
       ;; Bracket-group param list
       [(and (>= (length args) 3)
             (parse-tree-node? (cadr args))
             (eq? (parse-tree-node-tag (cadr args)) 'bracket-group))
        (define param-node (cadr args))
        (define binders (parse-binder-bracket param-node loc))
        (cond
          [(prologos-error? binders) binders]
          [else
           (define rest (cddr args))
           (cond
             ;; [name, [params], <RetType>, body]
             ;; Build full Pi chain: Pi(x:T1, Pi(y:T2, RetType))
             [(and (>= (length rest) 2)
                   (parse-tree-node? (car rest))
                   (eq? (parse-tree-node-tag (car rest)) 'angle-group))
              (define ret-type (parse-form-tree (car rest)))
              (define body (if (= (length rest) 2)
                              (parse-form-tree (cadr rest))
                              (parse-application-tree (cdr rest) loc)))
              (cond
                [(prologos-error? ret-type) ret-type]
                [(prologos-error? body) body]
                [else
                 (define param-names (map binder-info-name binders))
                 ;; Build Pi chain with binder types + return type
                 (define full-type
                   (foldr (lambda (bnd rest-ty) (surf-pi bnd rest-ty loc))
                          ret-type
                          binders))
                 (surf-defn name full-type param-names body loc)])]
             ;; [name, [params], :, type, body]
             ;; Build full Pi chain: Pi(x:T1, Pi(y:T2, RetType))
             ;; Same as inferred case but with return type instead of hole
             [(and (>= (length rest) 3)
                   (token-is? (car rest) ":"))
              (define ret-type-parsed (parse-form-tree (cadr rest)))
              (define body (parse-form-tree (caddr rest)))
              (cond
                [(prologos-error? ret-type-parsed) ret-type-parsed]
                [(prologos-error? body) body]
                [else
                 (define param-names (map binder-info-name binders))
                 ;; Build Pi chain: (Pi (x : T) (Pi (y : U) RetType))
                 (define full-type
                   (foldr (lambda (bnd rest-ty) (surf-pi bnd rest-ty loc))
                          ret-type-parsed
                          binders))
                 (surf-defn name full-type param-names body loc)])]
             ;; [name, [params], body] — type inferred (build Pi chain with holes)
             [(>= (length rest) 1)
              (define body (parse-form-tree (car rest)))
              (if (prologos-error? body) body
                  (let* ([param-names (map binder-info-name binders)]
                         ;; Build full type: (Pi (x : _) (Pi (y : _) _))
                         ;; This is what the old parser does — desugar-defn
                         ;; needs Pi binders to create named lambdas.
                         [full-type
                          (foldr (lambda (bnd rest-ty) (surf-pi bnd rest-ty loc))
                                 (surf-hole loc)
                                 binders)])
                    (surf-defn name full-type param-names body loc)))]
             [else
              (parse-error-result loc "defn: need body after params")])])]
       ;; Bare symbols as params (no bracket group)
       [else
        (define param-tokens (drop-right (cdr args) 1))
        (define body-item (last (cdr args)))
        (define param-names
          (for/list ([p (in-list param-tokens)])
            (token-symbol p)))
        (if (ormap not param-names)
            (parse-error-result loc "defn: expected param names")
            (let ([body (parse-form-tree body-item)])
              (if (prologos-error? body) body
                  (let* ([binders (map (lambda (n) (binder-info n #f (surf-hole loc)))
                                      param-names)]
                         [full-type
                          (foldr (lambda (bnd rest-ty) (surf-pi bnd rest-ty loc))
                                 (surf-hole loc)
                                 binders)])
                    (surf-defn name full-type param-names body loc)))))])]))

(define (parse-spec-tree args loc)
  ;; spec is consumed by preparse-expand-all (registers type info).
  ;; At this level, it's already been processed. If it reaches the
  ;; tree parser, treat as a pass-through (the elaborator handles it
  ;; via the spec registry cell).
  ;; For now: return a placeholder that the elaborator can recognize.
  ;; The spec form is: (spec name type-tokens...)
  ;; After preparse injection, specs are consumed — they don't appear
  ;; in the parsed output. If they DO appear here, they weren't consumed.
  (parse-error-result loc "spec: consumed by preparse"))

;; §11 WS normalizations for datum path
(define (restructure-infix-eq datum)
  (if (not (and (pair? datum) (list? datum))) datum
      (let ([eq-idx (let loop ([ts datum] [i 0])
                      (cond [(null? ts) #f]
                            [(and (symbol? (car ts)) (eq? (car ts) '=) (> i 0)) i]
                            [else (loop (cdr ts) (+ i 1))]))])
        (if eq-idx
            (let* ([lhs-ts (take datum eq-idx)]
                   [rhs-ts (drop datum (+ eq-idx 1))]
                   [lhs (if (= (length lhs-ts) 1) (car lhs-ts) lhs-ts)]
                   [rhs (if (= (length rhs-ts) 1) (car rhs-ts) rhs-ts)])
              (list '= lhs rhs))
            datum))))

(define (flatten-ws-datum datum)
  (if (not (pair? datum)) datum
      (cons (car datum)
            (apply append
              (for/list ([item (in-list (cdr datum))])
                (cond
                  [(and (pair? item) (symbol? (car item))
                        (let ([s (symbol->string (car item))])
                          (and (> (string-length s) 1)
                               (char=? (string-ref s 0) #\:))))
                   item]
                  [(and (pair? item)
                        (not (memq (car item) '($brace-params $angle-type $list-literal
                                                $nat-literal $approx-literal $decimal-literal
                                                $set-literal $vec-literal $foreign-block
                                                $typed-hole $solver-config quote $quote)))
                        (>= (length item) 2)
                        (symbol? (car item))
                        (let ([s (symbol->string (car item))])
                          (and (> (string-length s) 1)
                               (char=? (string-ref s 0) #\:))))
                   item]
                  [else (list item)]))))))

(define (normalize-ws-tokens datum)
  (cond
    [(not (pair? datum)) datum]
    [(symbol? datum)
     (case datum [(!!) 'AsyncSend] [(??) 'AsyncRecv] [else datum])]
    [else
     (map (lambda (item)
            (cond
              [(symbol? item)
               (case item [(!!) 'AsyncSend] [(??) 'AsyncRecv] [else item])]
              [(pair? item) (normalize-ws-tokens item)]
              [else item]))
          datum)]))

;; §11: parse ANY top-level form via datum conversion on the WHOLE node.
;; Applies all WS normalizations: flatten, session desugar, infix =, tokens.
;; This is the ON-NETWORK dispatch point — form-level dispatch via parse-form-tree,
;; expression parsing via parse-datum (canonical, correct).
(define (parse-eval-tree-for-cell node loc)
  ;; Use raw node if available (preserves pre-pipeline structure for multi-line forms)
  (define use-node (or (current-raw-node) node))
  (define stx (tree-node->stx-form use-node "<tree>" (current-source-str)))
  (if (not stx)
      (parse-error-result loc "eval: cannot convert to datum")
      (let ([datum (syntax->datum stx)])
        (with-handlers ([exn:fail? (lambda (e)
                                     (parse-error-result loc (format "eval: ~a" (exn-message e))))])
          ;; Apply ALL WS normalizations (same as extract-surfs datum path)
          (define flat (flatten-ws-datum datum))
          (define session-desugared
            (cond
              [(and (pair? flat) (eq? (car flat) 'session))
               (desugar-session-ws flat)]
              [(and (pair? flat) (eq? (car flat) 'defproc))
               (desugar-defproc-ws flat)]
              [else flat]))
          (define eq-fixed (restructure-infix-eq session-desugared))
          (define norm (normalize-ws-tokens eq-fixed))
          (define expanded (preparse-expand-single norm))
          (parse-datum (datum->syntax #f expanded))))))

(define (parse-eval-tree args loc)
  ;; Simple: (eval expr) → surf-eval
  (define inner
    (if (= (length args) 1)
        (parse-form-tree (car args))
        (parse-application-tree args loc)))
  (if (prologos-error? inner)
      inner
      (surf-eval inner loc)))

;; ========================================
;; Phase 4: Expression-level desugaring (cond, let, do)
;; ========================================
;; These replace preparse's expand-cond, expand-let, expand-do.
;; Each produces the same surf-* output that parse-datum would
;; produce after preparse expansion.

;; cond | guard1 -> body1 | guard2 -> body2 | ...
;; After G(0) grouping + T(0) tagging, cond node has children:
;;   [cond-token, expr-node1, expr-node2, ...]
;; Each expr-node contains: ["|" guard-tokens... "->" body-tokens...]
;; Desugars to: nested boolrec (same as preparse's expand-cond)
(define (parse-cond-expr args loc)
  ;; args = children of cond node after keyword = [expr-node1, expr-node2, ...]
  ;; Each arg is a parse-tree-node with clause children
  (define clause-nodes
    (filter (lambda (a) (parse-tree-node? a)) args))
  (if (null? clause-nodes)
      (parse-error-result loc "cond: need at least one clause")
      ;; Build nested boolrec from last clause to first
      (let loop ([remaining (reverse clause-nodes)])
        (if (null? remaining)
            (surf-hole loc)  ;; cond fallthrough: use plain hole (no typed-hole diagnostic)
            (let* ([clause-node (car remaining)]
                   [rest (cdr remaining)]
                   ;; Get clause children (flat tokens inside the expr node)
                   [items (rrb-to-list (parse-tree-node-children clause-node))]
                   ;; Strip leading | if present
                   [items (if (and (pair? items) (token-entry? (car items))
                                   (or (equal? (token-entry-lexeme (car items)) "|")
                                       (equal? (token-entry-lexeme (car items)) "$pipe")))
                              (cdr items) items)]
                   ;; Find -> to split guard from body
                   [arrow-idx (for/or ([item (in-list items)] [i (in-naturals)])
                                (and (token-is? item "->") i))]
                   [guard-items (if arrow-idx (take items arrow-idx) items)]
                   [body-items (if arrow-idx (drop items (+ arrow-idx 1)) '())])
              (if (or (null? guard-items) (null? body-items))
                  (parse-error-result loc "cond clause: need guard -> body")
                  (let ([guard (parse-expr-items guard-items loc)]
                        [body (parse-expr-items body-items loc)]
                        [else-branch (loop rest)])
                    (cond
                      [(prologos-error? guard) guard]
                      [(prologos-error? body) body]
                      [(prologos-error? else-branch) else-branch]
                      [else
                       (surf-boolrec (surf-lam (binder-info '_ #f (surf-bool-type loc))
                                               (surf-hole loc) loc)
                                     body else-branch guard loc)]))))))))

;; let x := val body  OR  let x : T := val body
;; Desugars to: ((fn [x] body) val) — application of lambda
(define (parse-let-expr args loc)
  (cond
    [(< (length args) 3)
     (parse-error-result loc "let: need name := value body")]
    [else
     ;; Find := in args
     (define assign-idx
       (for/or ([item (in-list args)] [i (in-naturals)])
         (and (token-is? item ":=") i)))
     (if (not assign-idx)
         ;; No := — try as (let [bindings] body) bracket form
         (parse-let-bracket-expr args loc)
         ;; let name [:type] := value body...
         (let* ([name-token (car args)]
                [name (token-symbol name-token)]
                [value-and-body (drop args (+ assign-idx 1))]
                ;; First item after := is the value; rest is body
                ;; But for multi-line let, body is on next indent level
                ;; In tree form, body is the remaining children
                [val-item (if (pair? value-and-body) (car value-and-body) #f)]
                [body-items (if (pair? value-and-body) (cdr value-and-body) '())])
           (if (or (not name) (not val-item))
               (parse-error-result loc "let: need name := value body")
               (let ([val-surf (parse-form-tree val-item)]
                     [body-surf (if (null? body-items)
                                    (parse-error-result loc "let: need body after value")
                                    (parse-expr-items body-items loc))])
                 (cond
                   [(prologos-error? val-surf) val-surf]
                   [(prologos-error? body-surf) body-surf]
                   [else
                    ;; ((fn [name] body) val)
                    (surf-app
                     (surf-lam (binder-info name #f (surf-hole loc))
                               body-surf loc)
                     (list val-surf) loc)])))))]))

;; let [x1 := v1, x2 := v2, ...] body — bracket binding form
(define (parse-let-bracket-expr args loc)
  ;; First arg should be a bracket group with bindings, rest is body
  (if (null? args)
      (parse-error-result loc "let: need bindings + body")
      (let ([bindings-node (car args)]
            [body-items (cdr args)])
        (if (null? body-items)
            (parse-error-result loc "let: need body after bindings")
            (let ([body (parse-expr-items body-items loc)])
              (if (prologos-error? body) body
                  ;; For now, pass through as-is — complex let desugaring
                  ;; falls back to preparse via datum conversion
                  (parse-error-result loc "let bracket form: complex desugaring needed")))))))

;; do e1 e2 e3 ...
;; Desugars to: ((fn [_] ((fn [_] e3) e2)) e1) — nested sequencing
(define (parse-do-expr args loc)
  (cond
    [(null? args) (parse-error-result loc "do: need at least one expression")]
    [(= (length args) 1) (parse-form-tree (car args))]
    [else
     ;; Build from last to first: ((fn [_] last) second-to-last)
     (let loop ([remaining (reverse args)])
       (if (= (length remaining) 1)
           (parse-form-tree (car remaining))
           (let ([current (parse-form-tree (car remaining))]
                 [rest (loop (cdr remaining))])
             (cond
               [(prologos-error? current) current]
               [(prologos-error? rest) rest]
               [else
                (surf-app
                 (surf-lam (binder-info '_ #f (surf-unit-type loc))
                           current loc)
                 (list rest) loc)]))))]))

;; Helper: parse items as either a binder (x : T) or a type expression
;; Returns binder-info if it's a binder, surf-* if it's a type
(define (parse-binder-or-type items loc)
  (cond
    [(null? items) (surf-hole loc)]
    [(= (length items) 1)
     (define item (car items))
     (cond
       ;; Paren group: (x : T) → binder
       [(and (parse-tree-node? item)
             (eq? (parse-tree-node-tag item) 'paren-group))
        (define pchildren (rrb-to-list (parse-tree-node-children item)))
        ;; Check for (name : type) pattern
        (if (and (>= (length pchildren) 3)
                 (token-entry? (car pchildren))
                 (token-entry? (cadr pchildren))
                 (equal? (token-entry-lexeme (cadr pchildren)) ":"))
            (let ([name (string->symbol (token-entry-lexeme (car pchildren)))]
                  [type-items (cddr pchildren)])
              (define type-surf (if (= (length type-items) 1)
                                    (parse-form-tree (car type-items))
                                    (parse-application-tree type-items loc)))
              (if (prologos-error? type-surf) type-surf
                  (binder-info name #f type-surf)))
            ;; Not a binder pattern — parse as expression
            (parse-form-tree item))]
       [else (parse-form-tree item)])]
    [else (parse-application-tree items loc)]))

;; Helper: check if any item (recursively) has ?-prefixed variable names
(define (has-narrow-vars? items)
  (for/or ([item (in-list items)])
    (cond
      [(token-entry? item)
       (let ([lex (token-entry-lexeme item)])
         (and (> (string-length lex) 1)
              (char=? (string-ref lex 0) #\?)))]
      [(parse-tree-node? item)
       (has-narrow-vars? (rrb-to-list (parse-tree-node-children item)))]
      [else #f])))

;; Helper: collect all ?-vars and constraint map recursively from items
(define (collect-narrow-vars-from-items items)
  (define qvars '())
  (define cmap (hasheq))
  (define (walk items)
    (for ([item (in-list items)])
      (cond
        [(token-entry? item)
         (define lex (token-entry-lexeme item))
         (when (and (> (string-length lex) 1)
                    (char=? (string-ref lex 0) #\?))
           (define base (if (string-contains? lex ":")
                            (car (string-split lex ":"))
                            lex))
           (set! qvars (cons (string->symbol base) qvars))
           (when (string-contains? lex ":")
             (define parts (string-split lex ":"))
             (when (>= (length parts) 2)
               (set! cmap (hash-set cmap (string->symbol (car parts))
                                    (list (string->symbol (cadr parts))))))))]
        [(parse-tree-node? item)
         (walk (rrb-to-list (parse-tree-node-children item)))])))
  (walk items)
  (values (reverse qvars) cmap))

;; Helper: split a list of items by $pipe tokens
(define (split-by-pipe items)
  (let loop ([remaining items] [current '()] [groups '()])
    (cond
      [(null? remaining)
       (if (null? current)
           (reverse groups)
           (reverse (cons (reverse current) groups)))]
      [(and (token-entry? (car remaining))
            (equal? (token-entry-lexeme (car remaining)) "$pipe"))
       (loop (cdr remaining)
             '()
             (if (null? current) groups (cons (reverse current) groups)))]
      ;; Also split on bare | token
      [(and (token-entry? (car remaining))
            (equal? (token-entry-lexeme (car remaining)) "|"))
       (loop (cdr remaining)
             '()
             (if (null? current) groups (cons (reverse current) groups)))]
      [else
       (loop (cdr remaining) (cons (car remaining) current) groups)])))

;; Helper: parse a list of items as an expression sequence
;; Handles: single item, let-chains, do-chains, application
(define (parse-expr-items items loc)
  (cond
    [(null? items) (parse-error-result loc "empty expression")]
    [(= (length items) 1) (parse-form-tree (car items))]
    ;; Check if first item is a let-assign node → let-chain
    [(and (parse-tree-node? (car items))
          (memq (parse-tree-node-tag (car items)) '(let-assign let-bracket)))
     ;; Let-chain: parse first let, body is rest of items
     (define let-node (car items))
     (define rest (cdr items))
     (define let-children (rrb-to-list (parse-tree-node-children let-node)))
     ;; let-assign: [let, name, :=, value]
     (define let-items (if (and (pair? let-children) (token-entry? (car let-children))
                                (equal? (token-entry-lexeme (car let-children)) "let"))
                           (cdr let-children) let-children))
     (define assign-idx (for/or ([item (in-list let-items)] [i (in-naturals)])
                           (and (token-is? item ":=") i)))
     (if (not assign-idx)
         (parse-expr-tree items loc)  ;; not a proper let — fallback
         (let* ([name (token-symbol (car let-items))]
                [val-items (drop let-items (+ assign-idx 1))]
                [val (if (= (length val-items) 1) (parse-form-tree (car val-items))
                         (parse-expr-items val-items loc))]
                [body (parse-expr-items rest loc)])
           (cond
             [(not name) (parse-error-result loc "let: expected name")]
             [(prologos-error? val) val]
             [(prologos-error? body) body]
             [else (surf-app (surf-lam (binder-info name #f (surf-hole loc)) body loc)
                             (list val) loc)])))]
    [else
     ;; Multiple items — parse as expression tree
     (parse-expr-tree items loc)]))

;; ========================================
;; Phase 1a: Consumed forms (data/trait/impl)
;; ========================================
;;
;; Strategy: convert tree-node args to datum, call process-data/trait/impl
;; (macros.rkt), then parse each generated def through parse-datum.
;; Returns the first generated surf (the type def). Additional surfs
;; (constructors, accessors, etc.) are handled by the merge fallback
;; to preparse — preparse also calls process-data/trait/impl, and the
;; registration is idempotent (hash-set). Once Phase 4 eliminates preparse,
;; the form-cell path will handle ALL generated surfs.
;;
;; process-data/trait/impl also perform registration (register-ctor!,
;; register-trait!, etc.). This is intentional — registration at
;; tree-parser time replaces preparse registration for these forms.

;; Helper: convert tree-node args (token-entries + parse-tree-nodes) to flat datum list
(define (tree-args-to-datums args)
  (for/list ([a (in-list args)])
    (cond
      [(token-entry? a)
       (define lex (token-entry-lexeme a))
       ;; Try as number first, then symbol
       (or (string->number lex) (string->symbol lex))]
      [(parse-tree-node? a)
       ;; Bracket/indent group: convert children to a list datum
       (define children
         (for/list ([c (in-list (rrb-to-list (parse-tree-node-children a)))]
                    #:when (token-entry? c))
           (define cl (token-entry-lexeme c))
           (or (string->number cl) (string->symbol cl))))
       (cond
         [(null? children) '()]
         [(= (length children) 1) (car children)]
         ;; Check if this is a $brace-params group
         [(eq? (car children) '$brace-params) children]
         [else children])]
      [else a])))

(define (parse-data-tree args loc)
  ;; Revert to error stub — the merge falls back to preparse.
  ;; Direct process-data call from tree-parser causes double-registration
  ;; and produces surfs without proper namespace scoping.
  ;; Phase 1a+3b-3e needs a different approach: either (a) produce the
  ;; generated defs as additional form cells (Phase 3e pattern), or
  ;; (b) skip process-data and only produce the tree-node for cell storage.
  ;; For now, the merge fallback is correct.
  (parse-error-result loc "parse-data-tree: deferred to Phase 3e (generated defs)"))

(define (parse-trait-tree args loc)
  (parse-error-result loc "parse-trait-tree: deferred to Phase 3e (generated defs)"))

(define (parse-impl-tree args loc)
  (parse-error-result loc "parse-impl-tree: deferred to Phase 3e (generated defs)"))

(define (parse-check-tree args loc)
  (if (>= (length args) 2)
      (let ([e (parse-form-tree (car args))]
            [t (parse-form-tree (cadr args))])
        (cond [(prologos-error? e) e]
              [(prologos-error? t) t]
              [else (surf-check e t loc)]))
      (parse-error-result loc "check: need expr type")))

(define (parse-infer-tree args loc)
  (if (= (length args) 1)
      (let ([e (parse-form-tree (car args))])
        (if (prologos-error? e) e (surf-infer e loc)))
      (parse-error-result loc "infer: need exactly 1 arg")))

(define (parse-when-tree args loc)
  ;; (when cond body) → boolrec with unit else
  (if (>= (length args) 2)
      (let ([cond-e (parse-form-tree (car args))]
            [body-e (parse-form-tree (cadr args))])
        (cond
          [(prologos-error? cond-e) cond-e]
          [(prologos-error? body-e) body-e]
          [else (surf-boolrec (surf-hole loc) body-e (surf-unit loc) cond-e loc)]))
      (parse-error-result loc "when: need cond body")))

;; --- fn: lambda expressions ---
;; Tree children after fn token:
;;   [bracket-group, body] — single binder group
;;   [bracket-group, angle-group, body] — binder + return type
;;   [bracket-group, bracket-group, ..., body] — multi-binder groups
;;   [bare-symbol, bare-symbol, ..., body] — bare params (uncurried)
(define (parse-fn-tree args loc)
  (cond
    [(< (length args) 2)
     (parse-error-result loc "fn: need at least binder + body")]
    ;; Single binder bracket + body (most common)
    [(and (= (length args) 2)
          (parse-tree-node? (car args))
          (eq? (parse-tree-node-tag (car args)) 'bracket-group))
     (define binders (parse-binder-bracket (car args) loc))
     (define body (parse-form-tree (cadr args)))
     (cond
       [(prologos-error? binders) binders]
       [(prologos-error? body) body]
       [else
        (foldr (lambda (bnd inner) (surf-lam bnd inner loc))
               body binders)])]
    ;; Binder bracket + angle-group (return type) + body
    [(and (= (length args) 3)
          (parse-tree-node? (car args))
          (eq? (parse-tree-node-tag (car args)) 'bracket-group)
          (parse-tree-node? (cadr args))
          (eq? (parse-tree-node-tag (cadr args)) 'angle-group))
     (define binders (parse-binder-bracket (car args) loc))
     (define ret-type (parse-form-tree (cadr args)))
     (define body (parse-form-tree (caddr args)))
     (cond
       [(prologos-error? binders) binders]
       [(prologos-error? ret-type) ret-type]
       [(prologos-error? body) body]
       [else
        (define full-type
          (foldr (lambda (bnd rest-ty) (surf-pi bnd rest-ty loc))
                 ret-type binders))
        (define nested-lam
          (foldr (lambda (bnd inner) (surf-lam bnd inner loc))
                 body binders))
        (surf-ann full-type nested-lam loc)])]
    ;; Multi-binder groups: all-but-last are bracket-groups, last is body
    [(let ([params (drop-right args 1)])
       (andmap (lambda (a)
                 (and (parse-tree-node? a)
                      (eq? (parse-tree-node-tag a) 'bracket-group)))
               params))
     (define param-groups (drop-right args 1))
     (define body (parse-form-tree (last args)))
     (if (prologos-error? body) body
         (let loop ([groups param-groups] [inner body])
           (if (null? groups) inner
               (let ([binders (parse-binder-bracket (car groups) loc)])
                 (if (prologos-error? binders) binders
                     (loop (cdr groups)
                           (foldr (lambda (bnd i) (surf-lam bnd i loc))
                                  inner binders)))))))]
    ;; Bare symbols: (fn x y body) — uncurried
    [else
     (define params (drop-right args 1))
     (define body (parse-form-tree (last args)))
     (if (prologos-error? body) body
         (let ([binders
                (for/list ([p (in-list params)])
                  (define name (token-symbol p))
                  (if name
                      (binder-info name #f (surf-hole loc))
                      (parse-error-result loc (format "fn: expected param name, got ~a" p))))])
           (if (ormap prologos-error? binders)
               (findf prologos-error? binders)
               (foldr (lambda (bnd inner) (surf-lam bnd inner loc))
                      body binders))))]))

;; Parse a bracket-group as binder list: [x : T, y : T] → (list binder-info ...)
(define (parse-binder-bracket bracket-node loc)
  (define children (node-children bracket-node))
  (if (null? children)
      '()
      ;; Simple case: [name] or [name : type]
      ;; For now, handle bare names and name:type pairs
      (let loop ([remaining children] [binders '()])
        (cond
          [(null? remaining) (reverse binders)]
          ;; name : type
          [(and (>= (length remaining) 3)
                (token-entry? (car remaining))
                (token-is? (cadr remaining) ":"))
           ;; Collect type tokens until next name or end
           (define name (token-symbol (car remaining)))
           (define type-item (caddr remaining))
           (define type-parsed (parse-form-tree type-item))
           (if (or (not name) (prologos-error? type-parsed))
               (list (or (and (not name)
                              (parse-error-result loc "binder: expected name"))
                         type-parsed))
               (loop (cdddr remaining)
                     (cons (binder-info name #f type-parsed) binders)))]
          ;; Multiplicity annotation: name :0 or name :w
          [(and (>= (length remaining) 2)
                (token-entry? (car remaining))
                (token-entry? (cadr remaining))
                (let ([lex (token-entry-lexeme (cadr remaining))])
                  (member lex '(":0" ":1" ":w"))))
           (define name (token-symbol (car remaining)))
           (define mult-lex (token-entry-lexeme (cadr remaining)))
           (define mult (case (string->symbol mult-lex)
                          [(:0) 'm0] [(:1) 'm1] [(:w) 'mw] [else #f]))
           ;; Check for : type after mult
           (if (and (>= (length remaining) 4)
                    (token-is? (caddr remaining) ":"))
               (let ([type-parsed (parse-form-tree (cadddr remaining))])
                 (loop (cddddr remaining)
                       (cons (binder-info name mult type-parsed) binders)))
               (loop (cddr remaining)
                     (cons (binder-info name mult (surf-hole loc)) binders)))]
          ;; Bare name
          [(token-entry? (car remaining))
           (define name (token-symbol (car remaining)))
           (if name
               (loop (cdr remaining)
                     (cons (binder-info name #f (surf-hole loc)) binders))
               (loop (cdr remaining) binders))]
          ;; Sub-node (nested bracket, angle, etc.)
          [(parse-tree-node? (car remaining))
           ;; Could be a type annotation in angle brackets
           (loop (cdr remaining) binders)]
          [else (loop (cdr remaining) binders)]))))

;; Parse a single binder: (x : T) or bare x
;; Used by Pi, Sigma — expects a bracket-group or bare token
(define (parse-binder-single item loc)
  (cond
    [(token-entry? item)
     ;; Bare name — type is hole
     (define name (token-symbol item))
     (if name
         (binder-info name #f (surf-hole loc))
         (parse-error-result loc "binder: expected name"))]
    [(and (parse-tree-node? item)
          (eq? (parse-tree-node-tag item) 'bracket-group))
     ;; Bracket group: [x : T] or [x :0 T] etc.
     (define binders (parse-binder-bracket item loc))
     (if (and (list? binders) (= (length binders) 1))
         (car binders)
         (if (prologos-error? binders) binders
             (parse-error-result loc "Pi/Sigma binder: expected single binder")))]
    [(and (parse-tree-node? item)
          (eq? (parse-tree-node-tag item) 'paren-group))
     ;; Paren group: (x : T) — sexp-style binder
     (define children (node-children item))
     (if (and (>= (length children) 3)
              (token-is? (cadr children) ":"))
         (let ([name (token-symbol (car children))]
               [ty (parse-form-tree (caddr children))])
           (if (and name (not (prologos-error? ty)))
               (binder-info name #f ty)
               (parse-error-result loc "paren binder: expected (name : type)")))
         (parse-error-result loc "paren binder: expected (name : type)"))]
    [else (parse-error-result loc "binder: expected [name : type] or bare name")]))

;; Parse match/reduce clauses
;; Each clause is a ($pipe pattern -> body) or (pattern -> body)
(define (parse-match-clauses items loc)
  (if (null? items)
      '()
      ;; For now, treat remaining items as the body (simplified)
      ;; Full clause parsing requires pattern compilation
      ;; which is handled by expand-top-level / defn-multi
      (for/list ([item (in-list items)])
        (parse-form-tree item))))

;; Helper: cddddr
(define (cddddr lst) (cdr (cdddr lst)))

(define (parse-if-tree args loc)
  ;; (if cond then else) → (boolrec (fn [_] _) then else cond)
  ;; Motive = (fn [_ : Bool] _) — same as preparse's expand-if
  (cond
    [(= (length args) 3)
     (define cond-e (parse-form-tree (car args)))
     (define then-e (parse-form-tree (list-ref args 1)))
     (define else-e (parse-form-tree (list-ref args 2)))
     (cond
       [(prologos-error? cond-e) cond-e]
       [(prologos-error? then-e) then-e]
       [(prologos-error? else-e) else-e]
       [else
        (surf-boolrec
         (surf-lam (binder-info '_ #f (surf-hole loc)) (surf-hole loc) loc)
         then-e else-e cond-e loc)])]
    [(>= (length args) 3)
     ;; (if cond then else) where cond/then/else may be multi-token
     (parse-if-tree (list (car args) (cadr args) (caddr args)) loc)]
    [else (parse-error-result loc "if: need cond then else")]))

(define (parse-expr-tree children loc)
  ;; Generic expression: check first child for keyword dispatch
  (cond
    [(null? children) (parse-error-result loc "empty expression")]
    [(= (length children) 1) (parse-form-tree (car children))]
    [else
     ;; Check if first child is a keyword token
     (define head (car children))
     (define head-lex (token-lexeme head))
     (define args (cdr children))
     (cond
       ;; Keyword dispatch (mirrors parser.rkt parse-list case dispatch)
       [(and head-lex (equal? head-lex "fn")) (parse-fn-tree args loc)]
       [(and head-lex (equal? head-lex "the"))
        (if (>= (length args) 2)
            (let ([ty (parse-form-tree (car args))]
                  [bd (parse-form-tree (cadr args))])
              (cond [(prologos-error? ty) ty]
                    [(prologos-error? bd) bd]
                    [else (surf-ann ty bd loc)]))
            (parse-error-result loc "the: need type expr"))]
       [(and head-lex (equal? head-lex "suc"))
        (if (= (length args) 1)
            (let ([e (parse-form-tree (car args))])
              (if (prologos-error? e) e (surf-suc e loc)))
            (parse-error-result loc "suc: need exactly 1 arg"))]
       [(and head-lex (equal? head-lex "boolrec"))
        ;; (boolrec motive then else cond) — 4 args
        (if (>= (length args) 4)
            (let ([motive (parse-form-tree (car args))]
                  [then-e (parse-form-tree (cadr args))]
                  [else-e (parse-form-tree (caddr args))]
                  [cond-e (parse-form-tree (cadddr args))])
              (cond [(prologos-error? motive) motive]
                    [(prologos-error? then-e) then-e]
                    [(prologos-error? else-e) else-e]
                    [(prologos-error? cond-e) cond-e]
                    [else (surf-boolrec motive then-e else-e cond-e loc)]))
            (parse-error-result loc "boolrec: need 4 args"))]
       [(and head-lex (equal? head-lex "cons"))
        (if (= (length args) 2)
            (let ([a (parse-form-tree (car args))]
                  [b (parse-form-tree (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-pair a b loc)]))
            ;; 3-arg cons: (cons Type head tail) — typed
            (if (= (length args) 3)
                (let ([ty (parse-form-tree (car args))]
                      [hd (parse-form-tree (cadr args))]
                      [tl (parse-form-tree (caddr args))])
                  (cond [(prologos-error? ty) ty]
                        [(prologos-error? hd) hd]
                        [(prologos-error? tl) tl]
                        [else (surf-pair hd tl loc)]))  ;; type implicit
                (parse-application-tree children loc)))]
       ;; Pi type: (Pi binder body)
       [(and head-lex (equal? head-lex "Pi"))
        (if (= (length args) 2)
            (let ([bnd (parse-binder-single (car args) loc)]
                  [body (parse-form-tree (cadr args))])
              (cond [(prologos-error? bnd) bnd]
                    [(prologos-error? body) body]
                    [else (surf-pi bnd body loc)]))
            (parse-error-result loc "Pi: need binder + body"))]
       ;; Sigma type: (Sigma binder body)
       [(and head-lex (equal? head-lex "Sigma"))
        (if (= (length args) 2)
            (let ([bnd (parse-binder-single (car args) loc)]
                  [body (parse-form-tree (cadr args))])
              (cond [(prologos-error? bnd) bnd]
                    [(prologos-error? body) body]
                    [else (surf-sigma bnd body loc)]))
            (parse-error-result loc "Sigma: need binder + body"))]
       ;; Arrow types: (-> A B), (-0> A B), (-1> A B)
       [(and head-lex (equal? head-lex "->"))
        (if (= (length args) 2)
            (let ([a (parse-form-tree (car args))]
                  [b (parse-form-tree (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-arrow #f a b loc)]))
            (parse-error-result loc "->: need 2 args"))]
       [(and head-lex (equal? head-lex "-0>"))
        (if (= (length args) 2)
            (let ([a (parse-form-tree (car args))]
                  [b (parse-form-tree (cadr args))])
              (cond [(prologos-error? a) a] [(prologos-error? b) b]
                    [else (surf-arrow 'm0 a b loc)]))
            (parse-error-result loc "-0>: need 2 args"))]
       ;; match/reduce: (match scrutinee clauses...)
       [(and head-lex (or (equal? head-lex "match") (equal? head-lex "reduce")))
        (if (>= (length args) 1)
            (let ([scrutinee (parse-form-tree (car args))])
              (if (prologos-error? scrutinee) scrutinee
                  (let ([clauses (parse-match-clauses (cdr args) loc)])
                    (if (prologos-error? clauses) clauses
                        (surf-reduce scrutinee clauses loc)))))
            (parse-error-result loc "match/reduce: need scrutinee + clauses"))]
       ;; Pair constructor: (pair a b)
       [(and head-lex (equal? head-lex "pair"))
        (if (= (length args) 2)
            (let ([a (parse-form-tree (car args))]
                  [b (parse-form-tree (cadr args))])
              (cond [(prologos-error? a) a] [(prologos-error? b) b]
                    [else (surf-pair a b loc)]))
            (parse-application-tree children loc))]
       ;; fst / snd already in unary ops
       ;; nil
       [(and head-lex (equal? head-lex "nil"))
        (surf-nil loc)]
       ;; natrec: (natrec motive base step n)
       [(and head-lex (equal? head-lex "natrec"))
        (if (= (length args) 4)
            (let ([m (parse-form-tree (car args))]
                  [b (parse-form-tree (cadr args))]
                  [s (parse-form-tree (caddr args))]
                  [n (parse-form-tree (cadddr args))])
              (cond [(prologos-error? m) m]
                    [(prologos-error? b) b]
                    [(prologos-error? s) s]
                    [(prologos-error? n) n]
                    [else (surf-natrec m b s n loc)]))
            (parse-application-tree children loc))]
       ;; map-literal: {k1 v1 k2 v2 ...}
       ;; This comes from brace-group tag, handled separately
       ;; eq: (eq A a b)
       [(and head-lex (equal? head-lex "Eq"))
        (if (= (length args) 3)
            (let ([ty (parse-form-tree (car args))]
                  [a (parse-form-tree (cadr args))]
                  [b (parse-form-tree (caddr args))])
              (cond [(prologos-error? ty) ty]
                    [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else (surf-eq ty a b loc)]))
            (parse-application-tree children loc))]
       ;; J eliminator: (J motive base a b proof)
       [(and head-lex (equal? head-lex "J"))
        (if (= (length args) 5)
            (parse-application-tree children loc)  ;; J is complex — use generic app for now
            (parse-application-tree children loc))]
       ;; Expression-level desugaring forms (Phase 4: inline handling replaces preparse)
       [(and head-lex (equal? head-lex "cond"))
        (parse-cond-expr args loc)]
       [(and head-lex (equal? head-lex "let"))
        (parse-let-expr args loc)]
       [(and head-lex (equal? head-lex "do"))
        (parse-do-expr args loc)]
       ;; if/when already handled by tag dispatch (lines 101-102)
       ;; but can appear as lexemes in expression context
       [(and head-lex (equal? head-lex "if"))
        (parse-if-tree args loc)]
       [(and head-lex (equal? head-lex "when"))
        (parse-when-tree args loc)]
       ;; defmacro/deftype in expression context — error
       [(and head-lex (member head-lex '("defmacro" "deftype")))
        (parse-error-result loc (format "~a cannot appear in expression position" head-lex))]
       ;; dual: (dual SessionRef) → surf-dual
       [(and head-lex (equal? head-lex "dual"))
        (if (= (length args) 1)
            (let ([ref (parse-form-tree (car args))])
              (if (prologos-error? ref) ref (surf-dual ref loc)))
            (parse-application-tree children loc))]
       ;; Expression keywords handled by parser.rkt but not tree-parser
       ;; (relational, session, capability). Return error so merge uses preparse.
       [(and head-lex (member head-lex '("solve" "solve-one" "defr" "rel" "facts"
                                         "session" "defproc" "proc" "spawn" "spawn-with"
                                         "capability" "with-cap" "with-transient"
                                         "assert" "retract" "explain")))
        (parse-error-result loc (format "~a: expression keyword handled by preparse" head-lex))]
       ;; Built-in binary operations: int+, int-, etc.
       [(and head-lex (hash-has-key? builtin-binary-ops head-lex))
        (if (= (length args) 2)
            (let ([a (parse-form-tree (car args))]
                  [b (parse-form-tree (cadr args))])
              (cond [(prologos-error? a) a]
                    [(prologos-error? b) b]
                    [else ((hash-ref builtin-binary-ops head-lex) a b loc)]))
            (parse-application-tree children loc))]
       ;; Built-in unary operations
       [(and head-lex (hash-has-key? builtin-unary-ops head-lex))
        (if (= (length args) 1)
            (let ([a (parse-form-tree (car args))])
              (if (prologos-error? a) a
                  ((hash-ref builtin-unary-ops head-lex) a loc)))
            (parse-application-tree children loc))]
       ;; Default: check for pipe/compose operators in children (mid-expression)
       ;; These are handled by preparse's expand-pipe-block/expand-compose-sexp,
       ;; not by the tree parser. Return error so merge falls back to preparse.
       ;; Also detect consecutive > > (rangle) which is >> compose inside brackets
       ;; (disambiguator only merges >> at bracket-depth 0).
       [(and (> (length children) 1)
             (let check ([rest children])
               (cond
                 [(null? rest) #f]
                 [(and (token-entry? (car rest))
                       (let ([lex (token-entry-lexeme (car rest))])
                         (or (equal? lex "|>") (equal? lex ">>")
                             (equal? lex "$pipe-gt") (equal? lex "$compose"))))
                  #t]
                 ;; Consecutive > > = >> compose
                 [(and (pair? (cdr rest))
                       (token-entry? (car rest))
                       (token-entry? (cadr rest))
                       (equal? (token-entry-lexeme (car rest)) ">")
                       (equal? (token-entry-lexeme (cadr rest)) ">"))
                  #t]
                 [else (check (cdr rest))])))
        (parse-error-result loc "pipe/compose in expression: handled by preparse")]
       ;; §11 G1: Narrowing infix = detection
       ;; (expr1 expr2 ... = exprN) with ?-prefixed variables → surf-narrow
       ;; (expr1 = expr2) without ?-vars → eq-check via parse-datum
       [(let ([eq-pos (for/or ([c (in-list children)] [i (in-naturals)])
                        (and (token-entry? c) (equal? (token-entry-lexeme c) "=")
                             (> i 0) i))])
          (and eq-pos
               ;; Check for ?-prefixed variables in children (recursively into sub-nodes)
               (has-narrow-vars? children)))
        ;; Narrowing: split at = into LHS and RHS
        (define eq-pos (for/or ([c (in-list children)] [i (in-naturals)])
                         (and (token-entry? c) (equal? (token-entry-lexeme c) "=")
                              (> i 0) i)))
        (define lhs-items (take children eq-pos))
        (define rhs-items (drop children (+ eq-pos 1)))
        (define lhs (if (= (length lhs-items) 1) (parse-form-tree (car lhs-items))
                        (parse-application-tree lhs-items loc)))
        (define rhs (if (= (length rhs-items) 1) (parse-form-tree (car rhs-items))
                        (parse-application-tree rhs-items loc)))
        ;; Collect ?-variables and constraint maps (recursively into sub-nodes)
        (define-values (qvars cmap) (collect-narrow-vars-from-items children))
        (cond
          [(prologos-error? lhs) lhs]
          [(prologos-error? rhs) rhs]
          [else (surf-narrow lhs rhs qvars loc cmap)])]
       ;; No = with ?-vars → application
       [else (parse-application-tree children loc)])]))

(define (parse-bracket-group-tree children loc)
  ;; [f x y] → application (with keyword dispatch)
  (if (null? children)
      (surf-nil loc)  ;; empty brackets = nil
      (parse-expr-tree children loc)))  ;; dispatch through keyword check

(define (parse-angle-group-tree children loc)
  ;; <Type> → type annotation
  ;; Detect: -> (Pi), * (Sigma), | (Union) operators
  (cond
    [(null? children) (surf-hole loc)]
    [(= (length children) 1) (parse-form-tree (car children))]
    ;; Check for -> (Pi type) or * (Sigma type) or | (Union)
    [else
     ;; Find arrow or star operator
     (define arrow-pos (for/or ([c (in-list children)] [i (in-naturals)])
                         (and (token-entry? c)
                              (member (token-entry-lexeme c) '("->" "-0>" "->>" "-1>"))
                              i)))
     (define star-pos (for/or ([c (in-list children)] [i (in-naturals)])
                        (and (token-entry? c) (equal? (token-entry-lexeme c) "*")
                             (> i 0) i)))
     (define union-pos (for/or ([c (in-list children)] [i (in-naturals)])
                         (and (token-entry? c) (equal? (token-entry-lexeme c) "|")
                              (> i 0) i)))
     (cond
       ;; Arrow type: <A -> B>
       [arrow-pos
        (define arrow-lex (token-entry-lexeme (list-ref children arrow-pos)))
        (define mult (cond [(equal? arrow-lex "-0>") 'm0]
                           [(equal? arrow-lex "-1>") 'm1]
                           [else 'm0]))  ;; default mult
        (define lhs-items (take children arrow-pos))
        (define rhs-items (drop children (+ arrow-pos 1)))
        (define lhs (parse-binder-or-type lhs-items loc))
        (define rhs (if (= (length rhs-items) 1) (parse-form-tree (car rhs-items))
                        (parse-angle-group-tree rhs-items loc)))
        (cond [(prologos-error? lhs) lhs]
              [(prologos-error? rhs) rhs]
              [(binder-info? lhs) (surf-pi lhs rhs loc)]
              [else (surf-arrow mult lhs rhs loc)])]
       ;; Sigma type: <(x : A) * B>
       [star-pos
        (define lhs-items (take children star-pos))
        (define rhs-items (drop children (+ star-pos 1)))
        (define lhs (parse-binder-or-type lhs-items loc))
        (define rhs (if (= (length rhs-items) 1) (parse-form-tree (car rhs-items))
                        (parse-angle-group-tree rhs-items loc)))
        (cond [(prologos-error? lhs) lhs]
              [(prologos-error? rhs) rhs]
              [(binder-info? lhs) (surf-sigma lhs rhs loc)]
              [else (surf-pair lhs rhs loc)])]
       ;; Union type: <A | B>
       [union-pos
        (define lhs-items (take children union-pos))
        (define rhs-items (drop children (+ union-pos 1)))
        (define lhs (if (= (length lhs-items) 1) (parse-form-tree (car lhs-items))
                        (parse-application-tree lhs-items loc)))
        (define rhs (if (= (length rhs-items) 1) (parse-form-tree (car rhs-items))
                        (parse-angle-group-tree rhs-items loc)))
        (cond [(prologos-error? lhs) lhs]
              [(prologos-error? rhs) rhs]
              [else (surf-union lhs rhs loc)])]
       ;; No operator — application
       [else (parse-application-tree children loc)])]))

(define (parse-brace-group-tree children loc)
  ;; {k1 v1 k2 v2} → map literal
  ;; Keys are keyword tokens (:name), values are expressions
  (if (null? children)
      (surf-map-empty (surf-hole loc) (surf-hole loc) loc)
      (let loop ([remaining children] [pairs '()])
        (cond
          [(null? remaining)
           ;; Build map from pairs
           (if (null? pairs)
               (surf-map-empty (surf-hole loc) (surf-hole loc) loc)
               (foldr (lambda (pair rest)
                        (surf-map-assoc (car pair) (cdr pair) rest loc))
                      (surf-map-empty (surf-hole loc) (surf-hole loc) loc)
                      (reverse pairs)))]
          [(and (>= (length remaining) 2)
                (token-entry? (car remaining)))
           (define key (parse-form-tree (car remaining)))
           (define val (parse-form-tree (cadr remaining)))
           (loop (cddr remaining)
                 (cons (cons key val) pairs))]
          [else
           ;; Odd number of elements or non-token key
           (parse-application-tree children loc)]))))

(define (parse-paren-group-tree children loc)
  ;; (keyword arg ...) → dispatch via parse-expr-tree (keyword recognition)
  ;; (expr) → single expression
  (if (null? children)
      (parse-error-result loc "empty paren group")
      (if (= (length children) 1)
          (parse-form-tree (car children))
          (parse-expr-tree children loc))))

(define (parse-group-tree children loc)
  ;; Indent-nested group → parse as expression
  (parse-expr-tree children loc))

(define (parse-application-tree items loc)
  ;; (f x y) → (surf-app f (list x y) loc)
  ;; surf-app takes func + args-LIST + loc
  (define parsed (map parse-form-tree items))
  (cond
    [(null? parsed) (parse-error-result loc "empty application")]
    [(ormap prologos-error? parsed) (findf prologos-error? parsed)]
    [(= (length parsed) 1) (car parsed)]  ;; single item, no application
    [else (surf-app (car parsed) (cdr parsed) loc)]))

(define (parse-list-literal-tree args loc)
  ;; '[1 2 3] → (cons 1 (cons 2 (cons 3 nil)))
  (let loop ([remaining args])
    (if (null? remaining)
        (surf-nil loc)
        (let ([elem (parse-form-tree (car remaining))])
          (if (prologos-error? elem) elem
              (let ([rest-list (loop (cdr remaining))])
                (if (prologos-error? rest-list) rest-list
                    (surf-app (surf-var 'cons loc)
                              (list elem rest-list) loc))))))))

(define (parse-quote-tree args loc)
  (parse-error-result loc "quote: not yet implemented"))

(define (parse-session-tree args loc)
  (parse-error-result loc "session: not yet implemented"))

(define (parse-defproc-tree args loc)
  (parse-error-result loc "defproc: not yet implemented"))

(define (parse-defr-tree args loc)
  (parse-error-result loc "defr: not yet implemented"))

(define (parse-solver-tree args loc)
  (parse-error-result loc "solver: not yet implemented"))

(define (parse-ns-tree args loc)
  (parse-error-result loc "ns: consumed by preparse"))

(define (parse-imports-tree args loc)
  (parse-error-result loc "imports: consumed by preparse"))

(define (parse-exports-tree args loc)
  (parse-error-result loc "exports: consumed by preparse"))

;; ========================================
;; Phase 1b: Parseable preparse-consumed forms
;; ========================================

;; subtype Sub Super [via fn]
;; Tree args: [Sub, Super] or [Sub, Super, via, fn]
(define (parse-subtype-tree args loc)
  (cond
    [(< (length args) 2)
     (parse-error-result loc "subtype requires at least 2 arguments: subtype Sub Super")]
    [else
     (define sub-sym (token-symbol (first args)))
     (define super-sym (token-symbol (second args)))
     (cond
       [(not sub-sym)
        (parse-error-result loc (format "subtype: expected type name, got ~a" (first args)))]
       [(not super-sym)
        (parse-error-result loc (format "subtype: expected type name, got ~a" (second args)))]
       [else
        (define rest (cddr args))
        (define via-fn
          (cond
            [(null? rest) #f]
            [(and (>= (length rest) 2)
                  (token-is? (first rest) "via"))
             (token-symbol (second rest))]
            [else #f]))
        (surf-subtype sub-sym super-sym via-fn loc)])]))

;; selection Name from Schema :requires [...] :provides [...] :includes [...]
;; Tree args: [Name, from, Schema, ...keyword-clauses...]
(define (parse-selection-tree args loc)
  (cond
    [(< (length args) 3)
     (parse-error-result loc "selection requires: selection Name from Schema")]
    [else
     (define name-sym (token-symbol (first args)))
     (define from-kw (token-lexeme (second args)))
     (define schema-sym (token-symbol (third args)))
     (cond
       [(not name-sym)
        (parse-error-result loc (format "selection: expected name, got ~a" (first args)))]
       [(not (equal? from-kw "from"))
        (parse-error-result loc (format "selection: expected 'from' after name, got ~a" from-kw))]
       [(not schema-sym)
        (parse-error-result loc (format "selection: expected schema name, got ~a" (third args)))]
       [else
        ;; Parse keyword clauses from remaining args
        (define rest (cdddr args))
        (define-values (req prov incl)
          (parse-selection-kw-clauses rest loc))
        (surf-selection name-sym schema-sym req prov incl loc)])]))

;; Helper: parse selection keyword clauses from tree args
;; Recognizes :requires, :provides, :includes followed by bracket groups
(define (parse-selection-kw-clauses args loc)
  (let loop ([remaining args] [req '()] [prov '()] [incl '()])
    (cond
      [(null? remaining) (values req prov incl)]
      [else
       (define kw (token-lexeme (car remaining)))
       (cond
         [(and kw (string=? kw ":requires") (pair? (cdr remaining)))
          (define val-node (cadr remaining))
          (define items (extract-bracket-symbols val-node))
          (loop (cddr remaining) items prov incl)]
         [(and kw (string=? kw ":provides") (pair? (cdr remaining)))
          (define val-node (cadr remaining))
          (define items (extract-bracket-symbols val-node))
          (loop (cddr remaining) req items incl)]
         [(and kw (string=? kw ":includes") (pair? (cdr remaining)))
          (define val-node (cadr remaining))
          (define items (extract-bracket-symbols val-node))
          (loop (cddr remaining) req prov items)]
         [else
          ;; Unknown keyword — skip
          (loop (cdr remaining) req prov incl)])])))

;; Helper: extract symbol names from a bracket-group node
(define (extract-bracket-symbols node)
  (if (parse-tree-node? node)
      (for/list ([child (in-list (node-children node))]
                 #:when (token-entry? child))
        (string->symbol (token-entry-lexeme child)))
      '()))

;; ========================================
;; Top-level: parse all forms from a tree
;; ========================================

(define (parse-top-level-forms-from-tree root)
  ;; root is a 'root node. Its children are top-level form nodes.
  (define children (node-children root))
  (for/list ([child (in-list children)])
    (parse-form-tree child)))

;; ========================================
;; Tests
;; ========================================

(module+ test
  (require rackunit
           "rrb.rkt")

  ;; Helper: make a token
  (define (tok lex)
    (token-entry (seteq 'symbol) lex 0 (string-length lex)))

  ;; Helper: make a tagged node
  (define (tnode tag . children)
    (parse-tree-node tag (list->rrb children) #f 0))

  (define (list->rrb lst)
    (for/fold ([r rrb-empty]) ([x (in-list lst)]) (rrb-push r x)))

  (test-case "parse-token: integer"
    (define result (parse-form-tree (tok "42")))
    (check-true (surf-int-lit? result)))

  (test-case "parse-token: variable"
    (define result (parse-form-tree (tok "foo")))
    (check-true (surf-var? result)))

  (test-case "parse-token: true"
    (define result (parse-form-tree (tok "true")))
    (check-true (surf-true? result)))

  (test-case "parse-token: keyword"
    (define result (parse-form-tree (tok ":name")))
    (check-true (surf-keyword? result)))

  (test-case "parse-token: string"
    (define result (parse-form-tree (tok "\"hello\"")))
    (check-true (surf-string? result)))

  (test-case "parse-token: Type"
    (define result (parse-form-tree (tok "Type")))
    (check-true (surf-type? result)))

  (test-case "parse-eval: simple"
    (define node (tnode 'eval (tok "eval") (tok "42")))
    (define result (parse-form-tree node))
    (check-true (surf-eval? result)))

  (test-case "parse-bracket-group: application"
    (define node (tnode 'bracket-group (tok "f") (tok "x") (tok "y")))
    (define result (parse-form-tree node))
    (check-true (surf-app? result)))

  (test-case "parse-bracket-group: empty → nil"
    (define node (tnode 'bracket-group))
    (define result (parse-form-tree node))
    (check-true (surf-nil? result)))

  (test-case "parse-expr: single token"
    (define node (tnode 'expr (tok "x")))
    (define result (parse-form-tree node))
    (check-true (surf-var? result)))

  (test-case "parse-expr: application"
    (define node (tnode 'expr (tok "f") (tok "x")))
    (define result (parse-form-tree node))
    (check-true (surf-app? result)))

  ;; --- Form-specific tests ---

  (test-case "parse-def: name + body (2 args)"
    (define node (tnode 'def (tok "def") (tok "x") (tok "42")))
    (define result (parse-form-tree node))
    (check-true (surf-def? result))
    (check-eq? (surf-def-name result) 'x)
    (check-false (surf-def-type result))  ;; type inferred
    (check-true (surf-int-lit? (surf-def-body result))))

  (test-case "parse-def: name + angle-type + body (3 args)"
    (define angle (tnode 'angle-group (tok "Int")))
    (define node (tnode 'def (tok "def") (tok "x") angle (tok "42")))
    (define result (parse-form-tree node))
    (check-true (surf-def? result))
    (check-eq? (surf-def-name result) 'x)
    (check-true (surf-int-type? (surf-def-type result)))
    (check-true (surf-int-lit? (surf-def-body result))))

  (test-case "parse-defn: bare params + body"
    (define params (tnode 'bracket-group (tok "x") (tok "y")))
    (define body (tnode 'bracket-group (tok "int+") (tok "x") (tok "y")))
    (define node (tnode 'defn (tok "defn") (tok "add") params body))
    (define result (parse-form-tree node))
    (check-true (surf-defn? result) (format "expected surf-defn, got ~a" result))
    (check-eq? (surf-defn-name result) 'add))

  (test-case "parse-defn: typed params + return type"
    (define params (tnode 'bracket-group (tok "x") (tok ":") (tok "Int")))
    (define ret-type (tnode 'angle-group (tok "Int")))
    (define body (tok "x"))
    (define node (tnode 'defn (tok "defn") (tok "id") params ret-type body))
    (define result (parse-form-tree node))
    (check-true (surf-defn? result) (format "expected surf-defn, got ~a" result))
    (check-eq? (surf-defn-name result) 'id)
    (check-not-false (surf-defn-type result)))  ;; has type annotation

  (test-case "parse-fn: bracket-binder + body"
    (define binder (tnode 'bracket-group (tok "x") (tok ":") (tok "Int")))
    (define node (tnode 'expr (tok "fn") binder (tok "x")))
    (define result (parse-form-tree node))
    (check-true (surf-lam? result)))

  (test-case "parse-fn: bare params + body"
    (define node (tnode 'expr (tok "fn") (tok "x") (tok "x")))
    (define result (parse-form-tree node))
    (check-true (surf-lam? result)))

  (test-case "parse-suc: suc x"
    (define node (tnode 'expr (tok "suc") (tok "x")))
    (define result (parse-form-tree node))
    (check-true (surf-suc? result)))

  (test-case "parse-the: type annotation"
    (define node (tnode 'expr (tok "the") (tok "Int") (tok "42")))
    (define result (parse-form-tree node))
    (check-true (surf-ann? result)))

  (test-case "parse-boolrec: from rewritten if"
    (define node (tnode 'expr (tok "boolrec") (tok "_") (tok "1") (tok "0") (tok "true")))
    (define result (parse-form-tree node))
    (check-true (surf-boolrec? result)))

  (test-case "parse-int+: builtin binary"
    (define node (tnode 'bracket-group (tok "int+") (tok "1") (tok "2")))
    (define result (parse-form-tree node))
    (check-true (surf-int-add? result)))

  (test-case "parse-Pi: binder + body"
    (define binder (tnode 'bracket-group (tok "x") (tok ":") (tok "Nat")))
    (define node (tnode 'expr (tok "Pi") binder (tok "Nat")))
    (define result (parse-form-tree node))
    (check-true (surf-pi? result)))

  (test-case "parse-Sigma: binder + body"
    (define binder (tnode 'bracket-group (tok "x") (tok ":") (tok "Nat")))
    (define node (tnode 'expr (tok "Sigma") binder (tok "Nat")))
    (define result (parse-form-tree node))
    (check-true (surf-sigma? result)))

  (test-case "parse-arrow: A -> B"
    (define node (tnode 'expr (tok "->") (tok "Nat") (tok "Int")))
    (define result (parse-form-tree node))
    (check-true (surf-arrow? result)))

  (test-case "parse-map-literal: empty braces"
    (define node (tnode 'brace-group))
    (define result (parse-form-tree node))
    (check-true (surf-map-empty? result)))

  (test-case "parse-def: name + colon + type + body (4 args)"
    (define node (tnode 'def (tok "def") (tok "x") (tok ":") (tok "Int") (tok "42")))
    (define result (parse-form-tree node))
    (check-true (surf-def? result))
    (check-eq? (surf-def-name result) 'x)
    (check-true (surf-int-type? (surf-def-type result)))
    (check-true (surf-int-lit? (surf-def-body result))))
)
