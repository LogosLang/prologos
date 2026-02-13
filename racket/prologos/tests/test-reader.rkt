#lang racket/base

;;;
;;; PROLOGOS READER TESTS
;;; Unit tests for the significant-whitespace reader (reader.rkt).
;;; Tests both the tokenizer and the indentation parser.
;;;

(require rackunit
         racket/string
         "../reader.rkt")

;; ================================================================
;; Helper: extract token types from a token stream
;; ================================================================
(define (token-types s)
  (map (lambda (t) (vector-ref (struct->vector t) 1))
       (tokenize-string s)))

(define (token-values s)
  (map (lambda (t) (vector-ref (struct->vector t) 2))
       (tokenize-string s)))

;; Helper: token type at index
(define (tok-type tokens i)
  (vector-ref (struct->vector (list-ref tokens i)) 1))

(define (tok-val tokens i)
  (vector-ref (struct->vector (list-ref tokens i)) 2))

;; ================================================================
;; TOKENIZER TESTS
;; ================================================================

(test-case "tokenize: bare symbol"
  (define toks (tokenize-string "foo"))
  ;; newline + symbol + eof
  (check-equal? (tok-type toks 1) 'symbol)
  (check-equal? (tok-val toks 1) 'foo))

(test-case "tokenize: number literal"
  (define toks (tokenize-string "42"))
  (check-equal? (tok-type toks 1) 'number)
  (check-equal? (tok-val toks 1) 42))

(test-case "tokenize: zero"
  (define toks (tokenize-string "0"))
  (check-equal? (tok-type toks 1) 'number)
  (check-equal? (tok-val toks 1) 0))

(test-case "tokenize: arrow symbol"
  (define toks (tokenize-string "->"))
  (check-equal? (tok-type toks 1) 'symbol)
  (check-equal? (tok-val toks 1) '->))

(test-case "tokenize: qualified name"
  (define toks (tokenize-string "std/list/append"))
  (check-equal? (tok-val toks 1) 'std/list/append))

(test-case "tokenize: freestanding colon"
  (define toks (tokenize-string "x : Nat"))
  (check-equal? (tok-type toks 2) 'colon))

(test-case "tokenize: multiplicity :0"
  (define toks (tokenize-string ":0"))
  (check-equal? (tok-type toks 1) 'symbol)
  (check-equal? (tok-val toks 1) ':0))

(test-case "tokenize: multiplicity :1"
  (define toks (tokenize-string ":1"))
  (check-equal? (tok-type toks 1) 'symbol)
  (check-equal? (tok-val toks 1) ':1))

(test-case "tokenize: multiplicity :w"
  (define toks (tokenize-string ":w"))
  (check-equal? (tok-type toks 1) 'symbol)
  (check-equal? (tok-val toks 1) ':w))

(test-case "tokenize: EDN keyword :name"
  (define toks (tokenize-string ":name"))
  (check-equal? (tok-type toks 1) 'keyword)
  (check-equal? (tok-val toks 1) 'name))

(test-case "tokenize: :widget is keyword, not :w + ident"
  (define toks (tokenize-string ":widget"))
  (check-equal? (tok-type toks 1) 'keyword)
  (check-equal? (tok-val toks 1) 'widget))

(test-case "tokenize: parentheses error in WS mode"
  ;; () is reserved for future tuple syntax — errors in WS mode
  (check-exn exn:fail?
    (lambda () (tokenize-string "(x)"))))

(test-case "tokenize: dollar sign"
  (define toks (tokenize-string "$x"))
  (check-equal? (tok-type toks 1) 'dollar))

(test-case "tokenize: string literal"
  (define toks (tokenize-string "\"hello world\""))
  (check-equal? (tok-type toks 1) 'string)
  (check-equal? (tok-val toks 1) "hello world"))

(test-case "tokenize: string with escape"
  (define toks (tokenize-string "\"hello\\nworld\""))
  (check-equal? (tok-val toks 1) "hello\nworld"))

(test-case "tokenize: comment skipped"
  (define result (read-all-forms-string "eval zero ; this is a comment"))
  (check-equal? result '((eval zero))))

(test-case "tokenize: comment-only line skipped"
  (define result (read-all-forms-string "; just a comment\neval zero"))
  (check-equal? result '((eval zero))))

(test-case "tokenize: indent token"
  (define toks (tokenize-string "x\n  y"))
  (define types (map (lambda (t) (vector-ref (struct->vector t) 1)) toks))
  (check-not-false (member 'indent types)))

(test-case "tokenize: dedent token at EOF"
  (define toks (tokenize-string "x\n  y"))
  (define types (map (lambda (t) (vector-ref (struct->vector t) 1)) toks))
  (check-not-false (member 'dedent types)))

(test-case "tokenize: brackets inside disable indentation"
  ;; Inside brackets, newlines should not produce indent/dedent
  (define toks (tokenize-string "[x\n  y]"))
  (define types (map (lambda (t) (vector-ref (struct->vector t) 1)) toks))
  (check-false (member 'indent types))
  (check-false (member 'dedent types)))

(test-case "tokenize: tab produces error"
  (check-exn exn:fail?
    (lambda () (tokenize-string "\tx"))))

(test-case "tokenize: square brackets"
  (define toks (tokenize-string "[x]"))
  (check-equal? (tok-type toks 1) 'lbracket)
  (check-equal? (tok-type toks 3) 'rbracket))

(test-case "tokenize: braces"
  (define toks (tokenize-string "{x}"))
  (check-equal? (tok-type toks 1) 'lbrace)
  (check-equal? (tok-type toks 3) 'rbrace))

;; ================================================================
;; PARSER TESTS — Indentation to S-expression
;; ================================================================

(test-case "parse: single-line form"
  (check-equal? (read-all-forms-string "eval zero")
                '((eval zero))))

(test-case "parse: single-line with grouping"
  (check-equal? (read-all-forms-string "eval [inc zero]")
                '((eval (inc zero)))))

(test-case "parse: multi-token indented child"
  (check-equal? (read-all-forms-string "eval\n  id Nat zero")
                '((eval (id Nat zero)))))

(test-case "parse: single-atom indented child (unwrapped)"
  (check-equal? (read-all-forms-string "fn [x : Nat]\n  x")
                '((fn (x : Nat) x))))

(test-case "parse: nested indentation"
  (check-equal?
   (read-all-forms-string "def id : T\n  fn a\n    fn b")
   '((def id : T (fn a (fn b))))))

(test-case "parse: nested with grouping"
  (check-equal?
   (read-all-forms-string
    "def id : [Pi [A :0 [Type 0]] [-> A A]]\n  fn [A :0 [Type 0]]\n    fn [x : A] x")
   '((def id : (Pi (A :0 (Type 0)) (-> A A)) (fn (A :0 (Type 0)) (fn (x : A) x))))))

(test-case "parse: check form with colon"
  (check-equal?
   (read-all-forms-string "check [pair zero true] : [Sigma [x : Nat] Bool]")
   '((check (pair zero true) : (Sigma (x : Nat) Bool)))))

(test-case "parse: def form with body"
  (check-equal?
   (read-all-forms-string "def one : Nat [inc zero]")
   '((def one : Nat (inc zero)))))

(test-case "parse: multiple top-level forms"
  (check-equal?
   (read-all-forms-string "eval zero\neval [inc zero]")
   '((eval zero) (eval (inc zero)))))

(test-case "parse: blank lines between top-level forms"
  (check-equal?
   (read-all-forms-string "eval zero\n\n\neval [inc zero]")
   '((eval zero) (eval (inc zero)))))

(test-case "parse: nested indentation back to column 0"
  (check-equal?
   (read-all-forms-string "def x : y\n  fn a\n    fn b\neval z")
   '((def x : y (fn a (fn b))) (eval z))))

(test-case "parse: multiple indented children"
  ;; Two children at the same indent level under a parent
  (check-equal?
   (read-all-forms-string "f\n  a b\n  c d")
   '((f (a b) (c d)))))

(test-case "parse: grouping inside grouping"
  (check-equal?
   (read-all-forms-string "eval [id [inc zero]]")
   '((eval (id (inc zero))))))

(test-case "parse: indentation inside brackets ignored"
  ;; Newlines inside [] don't create indent/dedent
  (check-equal?
   (read-all-forms-string "eval [id\n  Nat\n  zero]")
   '((eval (id Nat zero)))))

(test-case "parse: blank line inside indented block"
  ;; Blank lines in an indented block don't close the block
  (check-equal?
   (read-all-forms-string "f\n  a\n\n  b")
   '((f a b))))

(test-case "parse: deeply nested back to top"
  (check-equal?
   (read-all-forms-string "a\n  b\n    c\n      d\ne")
   '((a (b (c d))) (e))))

(test-case "parse: empty input"
  (check-equal? (read-all-forms-string "") '()))

(test-case "parse: only comments"
  (check-equal? (read-all-forms-string "; comment\n; another") '()))

(test-case "parse: [] bracket form"
  (check-equal?
   (read-all-forms-string "eval [1 2 3]")
   '((eval (1 2 3)))))

(test-case "parse: {} brace params"
  ;; Braces now produce ($brace-params ...) sentinel
  (define forms (read-all-forms-string "defn foo {A B} [x <A>] <A>\n  x"))
  (check-not-false forms)
  ;; Verify {A B} produces ($brace-params A B) in the datum
  (define first-form (car forms))
  ;; first-form should be (defn foo ($brace-params A B) (x ($angle-type A)) ($angle-type A) x)
  (define brace-part (caddr first-form))
  (check-equal? (car brace-part) '$brace-params)
  (check-equal? (cadr brace-part) 'A)
  (check-equal? (caddr brace-part) 'B))

;; ================================================================
;; COMMA SEPARATOR TESTS
;; ================================================================

(test-case "tokenize: comma token"
  (define toks (tokenize-string "a, b"))
  (define types (map (lambda (t) (vector-ref (struct->vector t) 1)) toks))
  (check-not-false (member 'comma types)))

(test-case "parse: commas in brackets stripped"
  ;; Commas in [...] should be silently removed by the bracket parser
  (define forms (read-all-forms-string "defn foo [x : Nat, y : Nat] <Nat>\n  x"))
  (check-not-false forms)
  (define first-form (car forms))
  ;; first-form: (defn foo (x : Nat y : Nat) ($angle-type Nat) x)
  ;; The bracket content should have commas stripped
  (define bracket-part (caddr first-form))
  (check-true (list? bracket-part))
  ;; Should be (x : Nat y : Nat) — no commas
  (check-equal? bracket-part '(x : Nat y : Nat)))

;; ================================================================
;; ROUND-TRIP TESTS — ws syntax produces same S-exprs as sexp
;; ================================================================

(test-case "round-trip: hello"
  (define ws-forms (read-all-forms-string
   "def one : Nat [inc zero]\ndef two : Nat [inc one]\ncheck two : Nat\neval two"))
  (check-equal? ws-forms
   '((def one : Nat (inc zero))
     (def two : Nat (inc one))
     (check two : Nat)
     (eval two))))

(test-case "round-trip: identity def"
  (define ws-forms (read-all-forms-string
   "def id : [Pi [A :0 [Type 0]] [-> A A]]\n  fn [A :0 [Type 0]]\n    fn [x : A] x"))
  (check-equal? ws-forms
   '((def id : (Pi (A :0 (Type 0)) (-> A A))
       (fn (A :0 (Type 0)) (fn (x : A) x))))))

(test-case "round-trip: check with sigma"
  (define ws-forms (read-all-forms-string
   "check [pair zero true] : [Sigma [x : Nat] Bool]"))
  (check-equal? ws-forms
   '((check (pair zero true) : (Sigma (x : Nat) Bool)))))

;; ================================================================
;; SOURCE LOCATION TESTS
;; ================================================================

(test-case "source locations: line and column preserved"
  (define port (open-input-string "eval zero"))
  (port-count-lines! port)
  (define stx (prologos-read-syntax "<test>" port))
  (check-equal? (syntax-line stx) 1)
  (check-equal? (syntax-column stx) 0))

;; ================================================================
;; := tokenization
;; ================================================================

(test-case "tokenize: := as symbol"
  ;; tokenize-string prepends a newline token, so indices are offset by 1
  (define tokens (tokenize-string "x := 42"))
  (check-equal? (tok-type tokens 1) 'symbol)
  (check-equal? (tok-val tokens 1) 'x)
  (check-equal? (tok-type tokens 2) 'symbol)
  (check-equal? (tok-val tokens 2) ':=)
  (check-equal? (tok-type tokens 3) 'number)
  (check-equal? (tok-val tokens 3) 42))

(test-case "tokenize: := after name"
  ;; Ensure := is a single token, not : then =
  (define tokens (tokenize-string "let x := 42"))
  (check-equal? (tok-val tokens 2) 'x)
  (check-equal? (tok-val tokens 3) ':=)
  (check-equal? (tok-type tokens 3) 'symbol))

(test-case "tokenize: := does not consume :0"
  ;; Ensure := doesn't break :0 — :0 is still token type 'symbol with value ':0
  (define tokens (tokenize-string "x :0"))
  (check-equal? (tok-type tokens 2) 'symbol)
  (check-equal? (tok-val tokens 2) ':0))

(test-case "WS parse: let x := 42 with body"
  ;; read-all-forms-string returns datums (already syntax->datum'd)
  (define forms (read-all-forms-string "let x := 42\n  body"))
  (check-equal? (length forms) 1)
  (check-equal? (car forms) '(let x := 42 body)))

(test-case "WS parse: let x : Nat := 42 with body"
  (define forms (read-all-forms-string "let x : Nat := 42\n  body"))
  (check-equal? (length forms) 1)
  (check-equal? (car forms) '(let x : Nat := 42 body)))

(test-case "source locations: second form has correct line"
  (define port (open-input-string "eval zero\neval one"))
  (port-count-lines! port)
  (define stx1 (prologos-read-syntax "<test>" port))
  (define stx2 (prologos-read-syntax "<test>" port))
  (check-equal? (syntax-line stx1) 1)
  (check-equal? (syntax-line stx2) 2))

(test-case "source locations: prologos-read returns eof"
  (define port (open-input-string ""))
  (port-count-lines! port)
  (check-true (eof-object? (prologos-read-syntax "<test>" port))))
