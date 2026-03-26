#lang racket/base

;;;
;;; Tests for PPN Track 1: Propagator-Based Reader
;;;

(require rackunit
         racket/set
         racket/list
         "../rrb.rkt"
         "../propagator.rkt"
         "../parse-lattice.rkt"
         "../parse-reader.rkt")

;; Helper: register patterns once
(register-default-token-patterns!)

;; ============================================================
;; Phase 1a: Character RRB
;; ============================================================

(test-case "char-rrb: build from simple string"
  (define rrb (make-char-rrb-from-string "hello"))
  (check-equal? (rrb-size rrb) 5)
  (check-equal? (rrb-get rrb 0) #\h)
  (check-equal? (rrb-get rrb 4) #\o))

(test-case "char-rrb: handles newlines"
  (define rrb (make-char-rrb-from-string "a\nb\nc"))
  (check-equal? (rrb-size rrb) 5)
  (check-equal? (rrb-get rrb 0) #\a)
  (check-equal? (rrb-get rrb 1) #\newline)
  (check-equal? (rrb-get rrb 2) #\b))

(test-case "char-rrb: empty string"
  (define rrb (make-char-rrb-from-string ""))
  (check-equal? (rrb-size rrb) 0))

(test-case "char-rrb: unicode characters"
  (define rrb (make-char-rrb-from-string "café"))
  (check-equal? (rrb-size rrb) 4)
  (check-equal? (rrb-get rrb 3) #\é))


;; ============================================================
;; Phase 1a: Content line classification
;; ============================================================

(test-case "content-line?: regular code"
  (check-true (content-line? "def x := 42"))
  (check-true (content-line? "  [f x y]"))
  (check-true (content-line? "spec foo Int -> Int")))

(test-case "content-line?: blank line"
  (check-false (content-line? ""))
  (check-false (content-line? "   "))
  (check-false (content-line? "\t  ")))

(test-case "content-line?: comment-only"
  (check-false (content-line? ";; this is a comment"))
  (check-false (content-line? "  ;; indented comment")))

(test-case "content-line?: code with trailing comment"
  ;; Line has content before the comment — it IS a content line
  (check-true (content-line? "def x := 42 ;; inline comment")))


;; ============================================================
;; Phase 1a: Indent measurement
;; ============================================================

(test-case "measure-indent: no indent"
  (check-equal? (measure-indent "def x := 42") 0))

(test-case "measure-indent: 2 spaces"
  (check-equal? (measure-indent "  where") 2))

(test-case "measure-indent: 4 spaces"
  (check-equal? (measure-indent "    [Eq x]") 4))

(test-case "measure-indent: empty string"
  (check-equal? (measure-indent "") 0))


;; ============================================================
;; Phase 1a: Indent RRB from character RRB
;; ============================================================

(test-case "indent-rrb: simple multi-line"
  (define char-rrb (make-char-rrb-from-string
    "def x := 42\n  where\n    [Eq x]\n"))
  (define-values (indent-rrb line-indices) (make-indent-rrb-from-char-rrb char-rrb))
  ;; 3 content lines: "def x := 42" (indent 0), "  where" (indent 2), "    [Eq x]" (indent 4)
  (check-equal? (rrb-size indent-rrb) 3)
  (check-equal? (rrb-get indent-rrb 0) 0)
  (check-equal? (rrb-get indent-rrb 1) 2)
  (check-equal? (rrb-get indent-rrb 2) 4)
  ;; Source line indices: 0, 1, 2
  (check-equal? (rrb-size line-indices) 3)
  (check-equal? (rrb-get line-indices 0) 0)
  (check-equal? (rrb-get line-indices 1) 1)
  (check-equal? (rrb-get line-indices 2) 2))

(test-case "indent-rrb: skips blank lines"
  (define char-rrb (make-char-rrb-from-string
    "def x := 42\n\n  where\n\n    [Eq x]\n"))
  (define-values (indent-rrb line-indices) (make-indent-rrb-from-char-rrb char-rrb))
  ;; Same 3 content lines, blank lines skipped
  (check-equal? (rrb-size indent-rrb) 3)
  (check-equal? (rrb-get indent-rrb 0) 0)
  (check-equal? (rrb-get indent-rrb 1) 2)
  (check-equal? (rrb-get indent-rrb 2) 4)
  ;; Source line indices: 0, 2, 4 (blanks at 1 and 3 skipped)
  (check-equal? (rrb-get line-indices 0) 0)
  (check-equal? (rrb-get line-indices 1) 2)
  (check-equal? (rrb-get line-indices 2) 4))

(test-case "indent-rrb: skips comment-only lines"
  (define char-rrb (make-char-rrb-from-string
    ";; header comment\ndef x := 42\n;; mid comment\n  where\n"))
  (define-values (indent-rrb line-indices) (make-indent-rrb-from-char-rrb char-rrb))
  ;; 2 content lines: "def x := 42" (indent 0), "  where" (indent 2)
  (check-equal? (rrb-size indent-rrb) 2)
  (check-equal? (rrb-get indent-rrb 0) 0)
  (check-equal? (rrb-get indent-rrb 1) 2))

(test-case "indent-rrb: no trailing newline"
  (define char-rrb (make-char-rrb-from-string "def x := 42"))
  (define-values (indent-rrb line-indices) (make-indent-rrb-from-char-rrb char-rrb))
  (check-equal? (rrb-size indent-rrb) 1)
  (check-equal? (rrb-get indent-rrb 0) 0))


;; ============================================================
;; Phase 1a: Parse cells on propagator network
;; ============================================================

(test-case "create-parse-cells: 5 cells on network"
  (define net0 (make-prop-network))
  (define-values (net1 cells) (create-parse-cells net0))
  ;; All 5 cell IDs are distinct
  (define ids (list (parse-cells-char-cell-id cells)
                    (parse-cells-indent-cell-id cells)
                    (parse-cells-token-cell-id cells)
                    (parse-cells-bracket-cell-id cells)
                    (parse-cells-tree-cell-id cells)))
  (check-equal? (set-count (list->seteq ids)) 5))

(test-case "parse-cells: write char RRB to char cell"
  (define net0 (make-prop-network))
  (define-values (net1 cells) (create-parse-cells net0))
  (define char-rrb (make-char-rrb-from-string "hello"))
  (define net2 (net-cell-write net1 (parse-cells-char-cell-id cells) char-rrb))
  (define val (net-cell-read net2 (parse-cells-char-cell-id cells)))
  (check-equal? (rrb-size val) 5)
  (check-equal? (rrb-get val 0) #\h))

(test-case "parse-cells: write indent RRB to indent cell"
  (define net0 (make-prop-network))
  (define-values (net1 cells) (create-parse-cells net0))
  (define char-rrb (make-char-rrb-from-string "def x\n  where\n"))
  (define-values (indent-rrb _) (make-indent-rrb-from-char-rrb char-rrb))
  (define net2 (net-cell-write net1 (parse-cells-indent-cell-id cells) indent-rrb))
  (define val (net-cell-read net2 (parse-cells-indent-cell-id cells)))
  (check-equal? (rrb-size val) 2)
  (check-equal? (rrb-get val 0) 0)
  (check-equal? (rrb-get val 1) 2))

(test-case "parse-cells: RRB merge — bot + value = value"
  (define net0 (make-prop-network))
  (define-values (net1 cells) (create-parse-cells net0))
  ;; Cell starts at bot (rrb-empty)
  (define val0 (net-cell-read net1 (parse-cells-char-cell-id cells)))
  (check-true (rrb-empty? val0))
  ;; Write value
  (define char-rrb (make-char-rrb-from-string "x"))
  (define net2 (net-cell-write net1 (parse-cells-char-cell-id cells) char-rrb))
  (define val1 (net-cell-read net2 (parse-cells-char-cell-id cells)))
  (check-equal? (rrb-size val1) 1))

(test-case "parse-cells: tree cell starts at parse-bot"
  (define net0 (make-prop-network))
  (define-values (net1 cells) (create-parse-cells net0))
  (define val (net-cell-read net1 (parse-cells-tree-cell-id cells)))
  (check-true (parse-bot? val)))


;; ============================================================
;; Phase 1b: Tokenizer
;; ============================================================

;; Helper: get token types from token RRB
(define (token-types-from-rrb tok-rrb)
  (for/list ([i (in-range (rrb-size tok-rrb))])
    (define entry (rrb-get tok-rrb i))
    (cons (set-first (token-entry-types entry))
          (token-entry-lexeme entry))))

(test-case "tokenizer: simple definition"
  (define char-rrb (make-char-rrb-from-string "def x := 42"))
  (define tok-rrb (tokenize-char-rrb char-rrb))
  (define toks (token-types-from-rrb tok-rrb))
  ;; def(sym) x(sym) :=(sym) 42(num)
  (check-equal? (length toks) 4)
  (check-equal? (car (list-ref toks 0)) 'symbol)
  (check-equal? (cdr (list-ref toks 0)) "def")
  (check-equal? (car (list-ref toks 1)) 'symbol)
  (check-equal? (cdr (list-ref toks 1)) "x")
  (check-equal? (car (list-ref toks 2)) 'symbol)  ;; := is a symbol
  (check-equal? (cdr (list-ref toks 2)) ":=")
  (check-equal? (car (list-ref toks 3)) 'number)
  (check-equal? (cdr (list-ref toks 3)) "42"))

(test-case "tokenizer: brackets"
  (define char-rrb (make-char-rrb-from-string "[f x y]"))
  (define tok-rrb (tokenize-char-rrb char-rrb))
  (define toks (token-types-from-rrb tok-rrb))
  (check-equal? (length toks) 5)
  (check-equal? (car (list-ref toks 0)) 'lbracket)
  (check-equal? (car (list-ref toks 1)) 'symbol)
  (check-equal? (car (list-ref toks 4)) 'rbracket))

(test-case "tokenizer: string literal"
  (define char-rrb (make-char-rrb-from-string "\"hello world\""))
  (define tok-rrb (tokenize-char-rrb char-rrb))
  (define toks (token-types-from-rrb tok-rrb))
  (check-equal? (length toks) 1)
  (check-equal? (car (list-ref toks 0)) 'string)
  (check-equal? (cdr (list-ref toks 0)) "\"hello world\""))

(test-case "tokenizer: string with escape"
  (define char-rrb (make-char-rrb-from-string "\"hello\\nworld\""))
  (define tok-rrb (tokenize-char-rrb char-rrb))
  (define toks (token-types-from-rrb tok-rrb))
  (check-equal? (length toks) 1)
  (check-equal? (car (list-ref toks 0)) 'string))

(test-case "tokenizer: nat literal"
  (define char-rrb (make-char-rrb-from-string "42N"))
  (define tok-rrb (tokenize-char-rrb char-rrb))
  (define toks (token-types-from-rrb tok-rrb))
  (check-equal? (length toks) 1)
  (check-equal? (car (list-ref toks 0)) 'number)
  (check-equal? (cdr (list-ref toks 0)) "42N"))

(test-case "tokenizer: rational literal"
  (define char-rrb (make-char-rrb-from-string "3/4"))
  (define tok-rrb (tokenize-char-rrb char-rrb))
  (define toks (token-types-from-rrb tok-rrb))
  (check-equal? (length toks) 1)
  (check-equal? (car (list-ref toks 0)) 'number)
  (check-equal? (cdr (list-ref toks 0)) "3/4"))

(test-case "tokenizer: keyword"
  (define char-rrb (make-char-rrb-from-string ":name"))
  (define tok-rrb (tokenize-char-rrb char-rrb))
  (define toks (token-types-from-rrb tok-rrb))
  (check-equal? (length toks) 1)
  (check-equal? (car (list-ref toks 0)) 'keyword)
  (check-equal? (cdr (list-ref toks 0)) ":name"))

(test-case "tokenizer: colon vs keyword vs colon-assign"
  (define char-rrb (make-char-rrb-from-string "x : Int := 42 :name"))
  (define tok-rrb (tokenize-char-rrb char-rrb))
  (define toks (token-types-from-rrb tok-rrb))
  ;; x(sym) :(colon) Int(sym) :=(sym) 42(num) :name(keyword)
  (check-equal? (length toks) 6)
  (check-equal? (car (list-ref toks 1)) 'colon)
  (check-equal? (car (list-ref toks 3)) 'symbol)  ;; := classified as symbol
  (check-equal? (cdr (list-ref toks 3)) ":=")
  (check-equal? (car (list-ref toks 5)) 'keyword))

(test-case "tokenizer: quote-lbracket"
  (define char-rrb (make-char-rrb-from-string "'[1 2 3]"))
  (define tok-rrb (tokenize-char-rrb char-rrb))
  (define toks (token-types-from-rrb tok-rrb))
  (check-equal? (car (list-ref toks 0)) 'quote-lbracket)
  (check-equal? (cdr (list-ref toks 0)) "'["))

(test-case "tokenizer: skips comments"
  (define char-rrb (make-char-rrb-from-string "x ;; comment\ny"))
  (define tok-rrb (tokenize-char-rrb char-rrb))
  (define toks (token-types-from-rrb tok-rrb))
  (check-equal? (length toks) 2)
  (check-equal? (cdr (list-ref toks 0)) "x")
  (check-equal? (cdr (list-ref toks 1)) "y"))

(test-case "tokenizer: skips whitespace and newlines"
  (define char-rrb (make-char-rrb-from-string "  a  \n  b  "))
  (define tok-rrb (tokenize-char-rrb char-rrb))
  (define toks (token-types-from-rrb tok-rrb))
  (check-equal? (length toks) 2)
  (check-equal? (cdr (list-ref toks 0)) "a")
  (check-equal? (cdr (list-ref toks 1)) "b"))

(test-case "tokenizer: multi-line definition"
  (define char-rrb (make-char-rrb-from-string "def x : Int := 42\n  where\n    [Eq x]"))
  (define tok-rrb (tokenize-char-rrb char-rrb))
  (define toks (token-types-from-rrb tok-rrb))
  ;; def x : Int := 42 where [ Eq x ]
  ;; No indent/dedent/newline tokens in the new reader
  (check-true (> (length toks) 8))
  ;; First token is "def"
  (check-equal? (cdr (list-ref toks 0)) "def"))

(test-case "tokenizer: char literal"
  (define char-rrb (make-char-rrb-from-string "'A'"))
  (define tok-rrb (tokenize-char-rrb char-rrb))
  (define toks (token-types-from-rrb tok-rrb))
  (check-equal? (length toks) 1)
  (check-equal? (car (list-ref toks 0)) 'char)
  (check-equal? (cdr (list-ref toks 0)) "'A'"))

(test-case "tokenizer: token-entry has set of types"
  (define char-rrb (make-char-rrb-from-string "x"))
  (define tok-rrb (tokenize-char-rrb char-rrb))
  (define entry (rrb-get tok-rrb 0))
  ;; Types is a seteq with one element
  (check-equal? (set-count (token-entry-types entry)) 1)
  (check-true (set-member? (token-entry-types entry) 'symbol)))

(test-case "tokenizer: positions tracked"
  (define char-rrb (make-char-rrb-from-string "ab cd"))
  (define tok-rrb (tokenize-char-rrb char-rrb))
  (define e0 (rrb-get tok-rrb 0))
  (define e1 (rrb-get tok-rrb 1))
  (check-equal? (token-entry-start-pos e0) 0)
  (check-equal? (token-entry-end-pos e0) 2)
  (check-equal? (token-entry-start-pos e1) 3)
  (check-equal? (token-entry-end-pos e1) 5))


;; ============================================================
;; Phase 1d: Bracket-depth RRB
;; ============================================================

(test-case "bracket-depth: simple brackets"
  (define char-rrb (make-char-rrb-from-string "[f x]"))
  (define tok-rrb (tokenize-char-rrb char-rrb))
  (define bd-rrb (make-bracket-depth-rrb tok-rrb))
  ;; [ → depth 1, f → 1, x → 1, ] → 0
  (check-equal? (rrb-size bd-rrb) (rrb-size tok-rrb))
  (check-equal? (car (rrb-get bd-rrb 0)) 1)  ;; after [
  (check-equal? (car (rrb-get bd-rrb 1)) 1)  ;; f inside brackets
  (check-equal? (car (rrb-get bd-rrb 3)) 0))  ;; after ]

(test-case "bracket-depth: nested brackets"
  (define char-rrb (make-char-rrb-from-string "[[x]]"))
  (define tok-rrb (tokenize-char-rrb char-rrb))
  (define bd-rrb (make-bracket-depth-rrb tok-rrb))
  ;; [[ → 1,2  x → 2  ]] → 1,0
  (check-equal? (car (rrb-get bd-rrb 0)) 1)   ;; first [
  (check-equal? (car (rrb-get bd-rrb 1)) 2)   ;; second [
  (check-equal? (car (rrb-get bd-rrb 2)) 2)   ;; x at depth 2
  (check-equal? (car (rrb-get bd-rrb 3)) 1)   ;; first ]
  (check-equal? (car (rrb-get bd-rrb 4)) 0))  ;; second ]

(test-case "bracket-depth: no brackets"
  (define char-rrb (make-char-rrb-from-string "x y z"))
  (define tok-rrb (tokenize-char-rrb char-rrb))
  (define bd-rrb (make-bracket-depth-rrb tok-rrb))
  (for ([i (in-range (rrb-size bd-rrb))])
    (check-equal? (car (rrb-get bd-rrb i)) 0)))

(test-case "bracket-depth-at: lookup"
  (define char-rrb (make-char-rrb-from-string "[x]"))
  (define tok-rrb (tokenize-char-rrb char-rrb))
  (define bd-rrb (make-bracket-depth-rrb tok-rrb))
  (check-equal? (bracket-depth-at bd-rrb 0) 1)
  (check-equal? (bracket-depth-at bd-rrb 2) 0))


;; ============================================================
;; Phase 1c: Tree-builder
;; ============================================================

(test-case "tree-builder: single line"
  (define src "def x := 42")
  (define char-rrb (make-char-rrb-from-string src))
  (define-values (indent-rrb line-indices) (make-indent-rrb-from-char-rrb char-rrb))
  (define tok-rrb (tokenize-char-rrb char-rrb))
  (define bd-rrb (make-bracket-depth-rrb tok-rrb))
  (define result (build-tree-from-domains char-rrb indent-rrb tok-rrb bd-rrb line-indices))
  (check-pred parse-cell-value? result)
  (check-false (parse-bot? result))
  ;; One derivation
  (check-equal? (set-count (parse-cell-value-derivations result)) 1))

(test-case "tree-builder: multi-line with indentation"
  (define src "def x := 42\n  where\n    [Eq x]")
  (define char-rrb (make-char-rrb-from-string src))
  (define-values (indent-rrb line-indices) (make-indent-rrb-from-char-rrb char-rrb))
  (define tok-rrb (tokenize-char-rrb char-rrb))
  (define bd-rrb (make-bracket-depth-rrb tok-rrb))
  (define result (build-tree-from-domains char-rrb indent-rrb tok-rrb bd-rrb line-indices))
  (check-pred parse-cell-value? result)
  ;; Root should have 1 child (the def-form at indent 0)
  (define deriv (set-first (parse-cell-value-derivations result)))
  (define root (car (derivation-node-children deriv)))
  (check-pred parse-tree-node? root)
  (check-equal? (parse-tree-node-tag root) 'root)
  ;; Root has 1 top-level form (def x at indent 0)
  (check-equal? (rrb-size (parse-tree-node-children root)) 1))

(test-case "tree-builder: blank lines skipped"
  (define src "def x := 42\n\ndef y := 10")
  (define char-rrb (make-char-rrb-from-string src))
  (define-values (indent-rrb line-indices) (make-indent-rrb-from-char-rrb char-rrb))
  (define tok-rrb (tokenize-char-rrb char-rrb))
  (define bd-rrb (make-bracket-depth-rrb tok-rrb))
  (define result (build-tree-from-domains char-rrb indent-rrb tok-rrb bd-rrb line-indices))
  (define deriv (set-first (parse-cell-value-derivations result)))
  (define root (car (derivation-node-children deriv)))
  ;; 2 top-level forms (both at indent 0)
  (check-equal? (rrb-size (parse-tree-node-children root)) 2))

(test-case "tree-builder: tree cell on network"
  (define net0 (make-prop-network))
  (define-values (net1 cells) (create-parse-cells net0))
  (define src "def x := 42")
  (define char-rrb (make-char-rrb-from-string src))
  (define-values (indent-rrb line-indices) (make-indent-rrb-from-char-rrb char-rrb))
  (define tok-rrb (tokenize-char-rrb char-rrb))
  (define bd-rrb (make-bracket-depth-rrb tok-rrb))
  (define tree-val (build-tree-from-domains char-rrb indent-rrb tok-rrb bd-rrb line-indices))
  ;; Write all 5 cells
  (define net2
    (net-cell-write
     (net-cell-write
      (net-cell-write
       (net-cell-write
        (net-cell-write net1
         (parse-cells-char-cell-id cells) char-rrb)
        (parse-cells-indent-cell-id cells) indent-rrb)
       (parse-cells-token-cell-id cells) tok-rrb)
      (parse-cells-bracket-cell-id cells) bd-rrb)
     (parse-cells-tree-cell-id cells) tree-val))
  ;; All 5 cells populated
  (check-false (rrb-empty? (net-cell-read net2 (parse-cells-char-cell-id cells))))
  (check-false (rrb-empty? (net-cell-read net2 (parse-cells-indent-cell-id cells))))
  (check-false (rrb-empty? (net-cell-read net2 (parse-cells-token-cell-id cells))))
  (check-false (rrb-empty? (net-cell-read net2 (parse-cells-bracket-cell-id cells))))
  (check-false (parse-bot? (net-cell-read net2 (parse-cells-tree-cell-id cells)))))

;; ============================================================
;; Phase 1e: Context disambiguator
;; ============================================================

(test-case "disambiguate: no change when no ambiguity"
  (define src "def x := 42")
  (define char-rrb (make-char-rrb-from-string src))
  (define tok-rrb (tokenize-char-rrb char-rrb))
  (define bd-rrb (make-bracket-depth-rrb tok-rrb))
  (define-values (narrowed changed?) (disambiguate-tokens tok-rrb bd-rrb))
  (check-false changed?)
  (check-equal? (rrb-size narrowed) (rrb-size tok-rrb)))

(test-case "disambiguate: > narrows to rangle when ambiguous at depth > 0"
  ;; Manually build an ambiguous token RRB: [< symbol {operator,rangle}]
  ;; with bracket-depth > 0 for the > token
  (define lt (token-entry (seteq 'langle) "<" 0 1))
  (define sym (token-entry (seteq 'symbol) "Int" 1 4))
  (define gt-ambig (token-entry (seteq 'operator 'rangle) ">" 5 6))
  (define tok-rrb (rrb-push (rrb-push (rrb-push rrb-empty lt) sym) gt-ambig))
  ;; Bracket depth: (cons bd qd) pairs — post-processing:
  ;; < → depth 0→1 stores (1 . 0), Int → stays 1 stores (1 . 0), > → depth 1→0 stores (0 . 0)
  ;; disambiguator checks bd-before (index i-1) for closing delimiters
  (define bd-rrb (rrb-push (rrb-push (rrb-push rrb-empty (cons 1 0)) (cons 1 0)) (cons 0 0)))
  (define-values (narrowed changed?) (disambiguate-tokens tok-rrb bd-rrb))
  (check-true changed?)
  (define gt-result (rrb-get narrowed 2))
  (check-equal? (token-entry-types gt-result) (seteq 'rangle)))

(test-case "disambiguate: > stays ambiguous at depth 0"
  ;; Manually build ambiguous > at bracket-depth 0
  (define sym1 (token-entry (seteq 'symbol) "x" 0 1))
  (define gt-ambig (token-entry (seteq 'operator 'rangle) ">" 2 3))
  (define sym2 (token-entry (seteq 'symbol) "y" 4 5))
  (define tok-rrb (rrb-push (rrb-push (rrb-push rrb-empty sym1) gt-ambig) sym2))
  (define bd-rrb (rrb-push (rrb-push (rrb-push rrb-empty (cons 0 0)) (cons 0 0)) (cons 0 0)))
  (define-values (narrowed changed?) (disambiguate-tokens tok-rrb bd-rrb))
  ;; > at depth 0 — should NOT be narrowed
  (check-false changed?)
  (define gt-result (rrb-get narrowed 1))
  (check-equal? (set-count (token-entry-types gt-result)) 2))

;; ============================================================
;; Phase 1e: Full parse pipeline
;; ============================================================

(test-case "parse-string-to-cells: simple def"
  (define-values (net cells) (parse-string-to-cells "def x := 42"))
  ;; All 5 cells should be populated
  (check-false (rrb-empty? (net-cell-read net (parse-cells-char-cell-id cells))))
  (check-false (rrb-empty? (net-cell-read net (parse-cells-indent-cell-id cells))))
  (check-false (rrb-empty? (net-cell-read net (parse-cells-token-cell-id cells))))
  (check-false (rrb-empty? (net-cell-read net (parse-cells-bracket-cell-id cells))))
  (check-false (parse-bot? (net-cell-read net (parse-cells-tree-cell-id cells)))))

(test-case "parse-string-to-cells: multiline with indent"
  (define src "def f [x]\n  [int+ x 1]")
  (define-values (net cells) (parse-string-to-cells src))
  ;; Token cell should have tokens
  (define tok (net-cell-read net (parse-cells-token-cell-id cells)))
  (check-true (> (rrb-size tok) 0))
  ;; Tree cell should have parse tree
  (define tree-val (net-cell-read net (parse-cells-tree-cell-id cells)))
  (check-false (parse-bot? tree-val))
  (define deriv (set-first (parse-cell-value-derivations tree-val)))
  (define root (car (derivation-node-children deriv)))
  ;; Root should have 1 top-level form
  (check-equal? (rrb-size (parse-tree-node-children root)) 1))

(test-case "parse-string-to-cells: angle brackets parse correctly"
  (define src "<Int | String>")
  (define-values (net cells) (parse-string-to-cells src))
  ;; All cells populated
  (define tok (net-cell-read net (parse-cells-token-cell-id cells)))
  (check-true (> (rrb-size tok) 0))
  ;; Tree cell has parse tree
  (check-false (parse-bot? (net-cell-read net (parse-cells-tree-cell-id cells))))
  ;; Verify > is classified as rangle
  (define n (rrb-size tok))
  (define gt-entry
    (for/first ([i (in-range n)]
                #:when (string=? (token-entry-lexeme (rrb-get tok i)) ">"))
      (rrb-get tok i)))
  (check-pred (lambda (e) e) gt-entry)
  (check-true (set-member? (token-entry-types gt-entry) 'rangle)))

(test-case "parse-string-to-cells: empty string"
  (define-values (net cells) (parse-string-to-cells ""))
  ;; Char cell populated (empty RRB)
  (define char-val (net-cell-read net (parse-cells-char-cell-id cells)))
  (check-equal? (rrb-size char-val) 0))
