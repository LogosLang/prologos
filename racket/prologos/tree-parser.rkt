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
         "errors.rkt")

(provide parse-form-tree
         parse-top-level-forms-from-tree)

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
       [(def) (parse-def-tree args loc)]
       [(defn) (parse-defn-tree args loc)]
       [(spec) (parse-spec-tree args loc)]
       [(eval) (parse-eval-tree args loc)]
       [(data) (parse-data-tree args loc)]
       [(trait) (parse-trait-tree args loc)]
       [(impl) (parse-impl-tree args loc)]
       [(check) (parse-check-tree args loc)]
       [(infer) (parse-infer-tree args loc)]

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
       [(list-literal) (parse-list-literal-tree args loc)]
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

;; ========================================
;; Built-in operation dispatch tables
;; ========================================

(define builtin-binary-ops
  (hash
   "int+" surf-int-add  "int-" surf-int-sub  "int*" surf-int-mul
   "int/" surf-int-div  "int%" surf-int-mod
   "int=" surf-int-eq   "int<" surf-int-lt   "int<=" surf-int-le
   "+" surf-generic-add  "-" surf-generic-sub  "*" surf-generic-mul
   "/" surf-generic-div  "%" surf-generic-mod
   "=" surf-generic-eq   "<" surf-generic-lt   "<=" surf-generic-le
   ">" surf-generic-gt   ">=" surf-generic-ge
   "eq?" surf-generic-eq
   "map-get" surf-map-get
   ))

(define builtin-unary-ops
  (hash
   "int-neg" surf-int-neg  "int-abs" surf-int-abs
   "negate" surf-generic-negate  "abs" surf-generic-abs
   "fst" surf-fst  "snd" surf-snd
   "not" surf-not
   ))

;; ========================================
;; Stub implementations for form parsing
;; ========================================
;; These will be fleshed out as we translate each parse-* function.
;; For now, they provide the structure for the dispatch.

(define (parse-error-result loc msg)
  (prologos-error loc msg #f))

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
    ;; 4 args with := and type: (def name <type> := body) or (def name := <type> body)
    [(and (>= (length args) 4)
          (token-is? (cadr args) ":="))
     ;; (def name := ... body) — skip :=, rest is body
     (define name (token-symbol (car args)))
     (if (not name)
         (parse-error-result loc "def: expected name")
         (let ([bd (parse-form-tree (caddr args))])
           (if (prologos-error? bd) bd
               (surf-def name #f bd loc))))]
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
    ;; 4+ args: (def name : type body) or (def name <type> body...)
    [(>= (length args) 4)
     (define name (token-symbol (car args)))
     (if (not name)
         (parse-error-result loc "def: expected name")
         (let ([second (cadr args)])
           (cond
             ;; Colon annotation
             [(token-is? second ":")
              (let ([ty (parse-form-tree (caddr args))]
                    [bd (parse-form-tree (cadddr args))])
                (cond
                  [(prologos-error? ty) ty]
                  [(prologos-error? bd) bd]
                  [else (surf-def name ty bd loc)]))]
             ;; Angle annotation + body
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
  ;; args (after defn token): [name, params-bracket, maybe-return-type, body...]
  ;; Variants:
  ;;   [name, [params], body] — bare params, type inferred
  ;;   [name, [params], <RetType>, body] — typed params + return type
  ;;   [name, [params], :, type, body] — colon return type
  ;; Multi-clause: handled by expand-top-level (defn-multi) at Layer 2
  (cond
    [(< (length args) 2)
     (parse-error-result loc "defn: need name + params + body")]
    [else
     (define name (token-symbol (car args)))
     (when (not name)
       (parse-error-result loc (format "defn: expected name, got ~a" (car args))))
     (cond
       [(not name)
        (parse-error-result loc "defn: expected name")]
       ;; Check if second arg is a bracket-group (param list)
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
                 ;; Build: (def name (the (Pi binders RetType) (fn binders body)))
                 (define full-type
                   (foldr (lambda (bnd rest-ty) (surf-pi bnd rest-ty loc))
                          ret-type binders))
                 (define nested-lam
                   (foldr (lambda (bnd inner) (surf-lam bnd inner loc))
                          body binders))
                 (surf-def name full-type nested-lam loc)])]
             ;; [name, [params], :, type, body]
             [(and (>= (length rest) 3)
                   (token-is? (car rest) ":"))
              (define type-parsed (parse-form-tree (cadr rest)))
              (define body (parse-form-tree (caddr rest)))
              (cond
                [(prologos-error? type-parsed) type-parsed]
                [(prologos-error? body) body]
                [else
                 (define full-type
                   (foldr (lambda (bnd rest-ty) (surf-pi bnd rest-ty loc))
                          type-parsed binders))
                 (define nested-lam
                   (foldr (lambda (bnd inner) (surf-lam bnd inner loc))
                          body binders))
                 (surf-def name full-type nested-lam loc)])]
             ;; [name, [params], body] — type inferred
             [(= (length rest) 1)
              (define body (parse-form-tree (car rest)))
              (if (prologos-error? body) body
                  (let ([nested-lam
                         (foldr (lambda (bnd inner) (surf-lam bnd inner loc))
                                body binders)])
                    (surf-def name #f nested-lam loc)))]
             ;; [name, [params], body1, body2, ...] — multi-expr body
             [(>= (length rest) 1)
              (define body (parse-form-tree (car rest)))
              (if (prologos-error? body) body
                  (let ([nested-lam
                         (foldr (lambda (bnd inner) (surf-lam bnd inner loc))
                                body binders)])
                    (surf-def name #f nested-lam loc)))]
             [else
              (parse-error-result loc "defn: need body after params")])])]
       ;; Bare symbols as params (no bracket group)
       [else
        ;; Try: all-but-last are symbols (bare params), last is body
        (define param-tokens (drop-right (cdr args) 1))
        (define body-item (last (cdr args)))
        (define param-names
          (for/list ([p (in-list param-tokens)])
            (token-symbol p)))
        (if (ormap not param-names)
            (parse-error-result loc "defn: expected param names")
            (let* ([binders (map (lambda (n) (binder-info n #f (surf-hole loc)))
                                 param-names)]
                   [body (parse-form-tree body-item)]
                   [nested-lam
                    (foldr (lambda (bnd inner) (surf-lam bnd inner loc))
                           body binders)])
              (if (prologos-error? body) body
                  (surf-def name #f nested-lam loc))))])]))

(define (parse-spec-tree args loc)
  ;; spec is consumed by preparse-expand-all (registers type info).
  ;; At this level, it's already been processed. If it reaches the
  ;; tree parser, treat as a pass-through (the elaborator handles it
  ;; via the spec registry cell).
  ;; For now: return a placeholder that the elaborator can recognize.
  ;; The spec form is: (spec name type-tokens...)
  ;; After preparse injection, specs are consumed — they don't appear
  ;; in the parsed output. If they DO appear here, they weren't consumed.
  (parse-error-result loc "spec: should have been consumed by preparse"))

(define (parse-eval-tree args loc)
  ;; Simple: (eval expr) → surf-eval
  (if (= (length args) 1)
      (surf-eval (parse-form-tree (car args)) loc)
      ;; Multiple args → implicit application
      (surf-eval (parse-application-tree args loc) loc)))

(define (parse-data-tree args loc)
  (parse-error-result loc "parse-data-tree: not yet implemented"))

(define (parse-trait-tree args loc)
  (parse-error-result loc "parse-trait-tree: not yet implemented"))

(define (parse-impl-tree args loc)
  (parse-error-result loc "parse-impl-tree: not yet implemented"))

(define (parse-check-tree args loc)
  (if (>= (length args) 2)
      (surf-check (parse-form-tree (car args))
                  (parse-form-tree (cadr args)) loc)
      (parse-error-result loc "check: need expr type")))

(define (parse-infer-tree args loc)
  (if (= (length args) 1)
      (surf-infer (parse-form-tree (car args)) loc)
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

;; Helper: cddddr
(define (cddddr lst) (cdr (cdddr lst)))

(define (parse-if-tree args loc)
  ;; After rewriting: should be boolrec form. But if not rewritten:
  ;; (if cond then else) → surf-boolrec
  (cond
    [(= (length args) 3)
     (surf-boolrec (surf-hole loc)
                   (parse-form-tree (list-ref args 1))
                   (parse-form-tree (list-ref args 2))
                   (parse-form-tree (car args))
                   loc)]
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
       ;; Default: application
       [else (parse-application-tree children loc)])]))

(define (parse-bracket-group-tree children loc)
  ;; [f x y] → application (with keyword dispatch)
  (if (null? children)
      (surf-nil loc)  ;; empty brackets = nil
      (parse-expr-tree children loc)))  ;; dispatch through keyword check

(define (parse-angle-group-tree children loc)
  ;; <Type> → type annotation
  ;; For now, parse as expression
  (if (= (length children) 1)
      (parse-form-tree (car children))
      (parse-application-tree children loc)))

(define (parse-brace-group-tree children loc)
  ;; {k1 v1 k2 v2} → map literal
  (parse-error-result loc "brace-group: not yet implemented"))

(define (parse-paren-group-tree children loc)
  ;; (expr) → parse contents
  (if (null? children)
      (parse-error-result loc "empty paren group")
      (if (= (length children) 1)
          (parse-form-tree (car children))
          (parse-application-tree children loc))))

(define (parse-group-tree children loc)
  ;; Indent-nested group → parse as expression
  (parse-expr-tree children loc))

(define (parse-application-tree items loc)
  ;; (f x y) → surf-app chain
  (define parsed (map parse-form-tree items))
  (if (null? parsed)
      (parse-error-result loc "empty application")
      (foldl (lambda (arg func) (surf-app func arg loc))
             (car parsed)
             (cdr parsed))))

(define (parse-list-literal-tree args loc)
  ;; Already rewritten by expand-list-literal to cons chain
  ;; If not rewritten, handle here
  (parse-error-result loc "list-literal: should have been rewritten"))

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
  ;; (ns name) → just the name symbol for module system
  ;; This is handled by preparse, not parser. Pass through.
  (parse-error-result loc "ns: handled by preparse"))

(define (parse-imports-tree args loc)
  (parse-error-result loc "imports: handled by preparse"))

(define (parse-exports-tree args loc)
  (parse-error-result loc "exports: handled by preparse"))

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
    (check-true (surf-def? result))
    (check-eq? (surf-def-name result) 'add))

  (test-case "parse-defn: typed params + return type"
    (define params (tnode 'bracket-group (tok "x") (tok ":") (tok "Int")))
    (define ret-type (tnode 'angle-group (tok "Int")))
    (define body (tok "x"))
    (define node (tnode 'defn (tok "defn") (tok "id") params ret-type body))
    (define result (parse-form-tree node))
    (check-true (surf-def? result) (format "expected surf-def, got ~a" result))
    (check-eq? (surf-def-name result) 'id)
    (check-not-false (surf-def-type result)))  ;; has type annotation

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

  (test-case "parse-def: name + colon + type + body (4 args)"
    (define node (tnode 'def (tok "def") (tok "x") (tok ":") (tok "Int") (tok "42")))
    (define result (parse-form-tree node))
    (check-true (surf-def? result))
    (check-eq? (surf-def-name result) 'x)
    (check-true (surf-int-type? (surf-def-type result)))
    (check-true (surf-int-lit? (surf-def-body result))))
)
