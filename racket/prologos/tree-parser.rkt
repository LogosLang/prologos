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
;; Stub implementations for form parsing
;; ========================================
;; These will be fleshed out as we translate each parse-* function.
;; For now, they provide the structure for the dispatch.

(define (parse-error-result loc msg)
  (prologos-error loc msg #f))

(define (parse-def-tree args loc)
  ;; TODO: translate from parser.rkt parse-def
  (parse-error-result loc "parse-def-tree: not yet implemented"))

(define (parse-defn-tree args loc)
  (parse-error-result loc "parse-defn-tree: not yet implemented"))

(define (parse-spec-tree args loc)
  (parse-error-result loc "parse-spec-tree: not yet implemented"))

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
  ;; Generic expression: first child is head, rest are args
  (cond
    [(null? children) (parse-error-result loc "empty expression")]
    [(= (length children) 1) (parse-form-tree (car children))]
    [else (parse-application-tree children loc)]))

(define (parse-bracket-group-tree children loc)
  ;; [f x y] → application
  (if (null? children)
      (surf-nil loc)  ;; empty brackets = nil
      (parse-application-tree children loc)))

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
)
