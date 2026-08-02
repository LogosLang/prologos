#lang racket/base

;;;
;;; Tests for PPN Track 1: Propagator-Based Reader
;;;

(require rackunit
         racket/set
         racket/list
         racket/string
         racket/file
         racket/path
         "../rrb.rkt"
         "../propagator.rkt"
         "../parse-lattice.rkt"
         "../parse-reader.rkt"
         (only-in "../parse-reader.rkt" read-all-forms-string)
         ;; D4.P1b-ii Q_N3: the two-grouper agreement guard needs the OTHER
         ;; grouping implementation (surface-rewrite's tree layer).
         (only-in "../surface-rewrite.rkt" group-tree-node))

;; Helper: register patterns once
(register-default-token-patterns!)

;; Path resolution (CWD-independent)
(define here-dir (path-only (syntax-source #'here)))
(define project-root (simplify-path (build-path here-dir "..")))

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
  (check-equal? (car (list-ref toks 0)) 'nat-literal)
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
;; Phase 2: Reader macro token patterns
;; ============================================================

(test-case "tokenizer: quote '["
  (define tok-rrb (tokenize-char-rrb (make-char-rrb-from-string "'[1 2]")))
  (define toks (token-types-from-rrb tok-rrb))
  (check-equal? (car (list-ref toks 0)) 'quote-lbracket)
  (check-equal? (cdr (list-ref toks 0)) "'["))

(test-case "tokenizer: bare quote"
  (define tok-rrb (tokenize-char-rrb (make-char-rrb-from-string "'x")))
  (define toks (token-types-from-rrb tok-rrb))
  (check-equal? (car (list-ref toks 0)) 'quote)
  (check-equal? (cdr (list-ref toks 0)) "'"))

(test-case "tokenizer: @[ PVec literal"
  (define tok-rrb (tokenize-char-rrb (make-char-rrb-from-string "@[1 2]")))
  (define toks (token-types-from-rrb tok-rrb))
  (check-equal? (car (list-ref toks 0)) 'at-lbracket)
  (check-equal? (cdr (list-ref toks 0)) "@["))

(test-case "tokenizer: ~[ LSeq literal"
  (define tok-rrb (tokenize-char-rrb (make-char-rrb-from-string "~[1 2]")))
  (define toks (token-types-from-rrb tok-rrb))
  (check-equal? (car (list-ref toks 0)) 'tilde-lbracket)
  (check-equal? (cdr (list-ref toks 0)) "~["))

(test-case "tokenizer: #{ Set literal"
  (define tok-rrb (tokenize-char-rrb (make-char-rrb-from-string "#{1 2}")))
  (define toks (token-types-from-rrb tok-rrb))
  (check-equal? (car (list-ref toks 0)) 'hash-lbrace)
  (check-equal? (cdr (list-ref toks 0)) "#{"))

(test-case "tokenizer: #= narrowing"
  (define tok-rrb (tokenize-char-rrb (make-char-rrb-from-string "#= x")))
  (define toks (token-types-from-rrb tok-rrb))
  (check-equal? (car (list-ref toks 0)) 'symbol)
  (check-equal? (cdr (list-ref toks 0)) "#="))

(test-case "tokenizer: #p( path literal"
  (define tok-rrb (tokenize-char-rrb (make-char-rrb-from-string "#p(foo.bar)")))
  (define toks (token-types-from-rrb tok-rrb))
  (check-equal? (car (list-ref toks 0)) 'path-literal)
  (check-equal? (cdr (list-ref toks 0)) "#p(foo.bar)"))

(test-case "tokenizer: .field dot-access"
  (define tok-rrb (tokenize-char-rrb (make-char-rrb-from-string "x.name")))
  (define toks (token-types-from-rrb tok-rrb))
  (check-equal? (length toks) 2)
  (check-equal? (car (list-ref toks 0)) 'symbol)
  (check-equal? (car (list-ref toks 1)) 'dot-access)
  (check-equal? (cdr (list-ref toks 1)) ".name"))

(test-case "tokenizer: .:keyword dot-key"
  (define tok-rrb (tokenize-char-rrb (make-char-rrb-from-string "m.:key")))
  (define toks (token-types-from-rrb tok-rrb))
  (check-equal? (car (list-ref toks 1)) 'dot-key)
  (check-equal? (cdr (list-ref toks 1)) ".:key"))

;; ============================================================
;; CIU T6 D4.P1b-ii — the `.{` opener (dot-lbrace re-mint)
;;
;; FLIPPED from "`.{` is RETIRED — no dot-lbrace token exists (CIU T6 P1)".
;; P1 retired `.{`-as-MIXFIX; the redesign (2026-07-28) re-mints the GLYPH for
;; a different construct — the mid-path sub-block `server^.{ssl port}`, where
;; `.` DESCENDS and the brace SELECTS. Q_M5: plain 'rbrace closer (the
;; hash-lbrace precedent), NOT dot-lparen's 'mixfix-rparen sentinel.
;; ============================================================

(test-case "tokenizer: .{ produces a dot-lbrace compound token (D4.P1b-ii)"
  (define tok-rrb (tokenize-char-rrb (make-char-rrb-from-string "x.{a b}")))
  (define toks (token-types-from-rrb tok-rrb))
  (check-true (and (assq 'dot-lbrace toks) #t)
              "`.{` must fold into ONE token, not a bare `.` + lbrace")
  ;; and the loose `.` it replaces must be GONE — that token was the only
  ;; signal distinguishing `x.{a}` from `x{a}`, which is why Q_N1 mints a
  ;; distinct sentinel rather than reusing $brace-params.
  (check-false (member '(symbol . ".") toks)))

(test-case "datum: .{ mints the $dot-brace sentinel, distinct from $brace-params"
  (define forms (read-all-forms-string "x.{a b}"))
  (check-equal? forms '((x ($dot-brace a b)))))


;; ============================================================
;; CIU T6 D4.P1b-iii — BRACE ADJACENCY
;;
;; Adjacent `x{…}` is a SELECT BLOCK (forced new sentinel, Q_M6 — adjacency is
;; destroyed at the datum layer and $brace-params is ELEVEN-purposed). Spaced
;; `f {…}` must NOT change: 419 of 622 live spaced braces are implicit type
;; binders. Known reader-form heads (`racket{…}`) win FIRST and keep
;; $brace-params, because `combine-foreign-blocks` has no adjacency test and
;; the spaced form is accepted today.
;; ============================================================

(test-case "P1b-iii: ADJACENT x{…} mints $select-brace"
  (check-equal? (read-all-forms-string "x{a b}") '((x ($select-brace a b)))))

(test-case "P1b-iii: SPACED f {…} is UNCHANGED — the 419-binder population"
  (check-equal? (read-all-forms-string "x {a b}") '((x ($brace-params a b))))
  (check-equal? (read-all-forms-string "spec identity {A : Type} A -> A")
                '((spec identity ($brace-params A : Type) A -> A))))

(test-case "P1b-iii: HEAD PRECEDENCE — racket{…} keeps $brace-params"
  ;; Checked BEFORE the select-block rule. No-space is the documented canonical
  ;; form for foreign blocks (10 live WS sites), and the spaced form is
  ;; accepted too, so BOTH must stay $brace-params.
  (check-equal? (read-all-forms-string "racket{(+ 1 2)}") '((racket ($brace-params (+ 1 2)))))
  (check-equal? (read-all-forms-string "racket {(+ 1 2)}") '((racket ($brace-params (+ 1 2))))))

(test-case "P1b-iii Q_N5: BUCKET 4 — closing-delimiter-adjacent is SELECT, by decision"
  ;; ⚠ Inaction is NOT the status quo here: for `f[x]{a}` BOTH is-postfix?
  ;; conjuncts already pass, so a naive generalization would rule this by
  ;; ACCIDENT. Owner-ruled SELECT, matching the bracket band's own precedent
  ;; (`xs[0][1]` chains through is-postfix? off an rbracket). Zero live sites.
  (check-equal? (read-all-forms-string "f[x]{a}")
                '((f ($postfix-index x) ($select-brace a))))
  (check-equal? (read-all-forms-string "xs[0][1]")
                '((xs ($postfix-index 0) ($postfix-index 1)))))

(test-case "P1b-iii Q_N6: the ACCEPTED binder hazard, both spellings pinned"
  ;; `defn f{x} x` was a BINDER and becomes a select block. Owner-accepted:
  ;; zero live adjacent-brace binder sites. The SPACED spelling — which is what
  ;; 419 live sites use — must not move.
  (check-equal? (read-all-forms-string "defn f{x} x") '((defn f ($select-brace x) x)))
  (check-equal? (read-all-forms-string "defn f {x} x") '((defn f ($brace-params x) x))))

(test-case "P1b-iii: OPENER-ADJACENT braces are NOT select blocks — the (pair? result) guard"
  ;; `'[{` and `@[{` are byte-adjacent, so ONLY `(pair? result)` declines them.
  ;; ~28 live sites. If the guard is dropped, every list-of-maps literal
  ;; mis-reads its FIRST element only, at zero errors.
  (check-equal? (read-all-forms-string "'[{:a 1} {:b 2}]")
                '(($list-literal ($brace-params :a 1) ($brace-params :b 2))))
  (check-equal? (read-all-forms-string "@[{:a 1} {:b 2}]")
                '(($vec-literal ($brace-params :a 1) ($brace-params :b 2))))
  (check-equal? (read-all-forms-string "[{:a 1}]") '((($brace-params :a 1))))
  (check-equal? (read-all-forms-string "({:a 1})") '((($brace-params :a 1)))))

;; ============================================================
;; CIU T6 D4.P1b-iii / Q_M8 — ORDINALS ARE MULTI-DIGIT
;;
;; `recognize-colon-annotation` was hard-capped at 2 chars, so `:10` shattered
;; into `:` + `10` while `:0`…`:9` were single tokens. Owner-ruled Q_M8: widen
;; the DIGIT run to digit+. The overlap with the QTT multiplicity vocabulary is
;; only `:0`/`:1` (mult-annot? accepts exactly {:0 :1 :w}), and those are
;; discriminated by position, not by lexeme.
;; ============================================================

;; ⚠ D4.P4c-2 — THE EIGHT DELIBERATE FLIPS. The datums below changed because
;; the `:` gate now mints `$bcast-step` for a keyword/colon-annotation token
;; byte-adjacent to a non-empty local result (Q_U8 mint, Q_U16 unwrap). They are
;; listed as flips in §5.P4c-2's test delta, NOT silenced: this is the third
;; consecutive phase in which the PRIOR rung's flagship pin flips, and an
;; unannounced flip reads as a regression at suite time.
;; ⚠ Two neighbours must NOT move and are load-bearing: `x:0abc`/`x:10abc`
;; (the annotation arm declines, the colon shatters to a bare `colon`, which is
;; OUTSIDE the trigger) and `{:10 v}`/`{:0 v}` (branch-initial ⇒ EMPTY local
;; result). Admitting bare `colon` to the trigger would break both.
(test-case "Q_M8: :10 is ONE token, like :0…:9 (was: `:` + `10`)"
  (check-equal? (read-all-forms-string "users:10") '((users ($bcast-step :10))))
  (check-equal? (read-all-forms-string "users:127") '((users ($bcast-step :127)))))

(test-case "Q_M8: single-digit and w/m forms are UNCHANGED (must-not-break)"
  (check-equal? (read-all-forms-string "users:0") '((users ($bcast-step :0))))
  (check-equal? (read-all-forms-string "users:9") '((users ($bcast-step :9))))
  (check-equal? (read-all-forms-string "users:w") '((users ($bcast-step :w))))
  (check-equal? (read-all-forms-string "users:m") '((users ($bcast-step :m)))))

(test-case "Q_M8: the trailing ident-continue GUARD still declines after the LAST digit"
  ;; The widened digit run must test `not ident-continue?` AFTER the last digit,
  ;; or `:10abc` would wrongly lex as an annotation.
  ;;
  ;; ⚠ These pin ACTUAL behaviour, not intuition — my first draft asserted
  ;; `:0abc` was a KEYWORD and the test refuted it. A digit-headed colon symbol
  ;; that the annotation arm declines does NOT fall through to the keyword arm
  ;; (no keyword starts with a digit), so it SHATTERS. That is the status quo
  ;; for `:0abc` and must stay the status quo for `:10abc`.
  (check-equal? (read-all-forms-string "x:0abc") '((x : 0 abc)))
  (check-equal? (read-all-forms-string "x:10abc") '((x : 10 abc)))
  ;; …while the LETTER arm still yields keywords, which is why the guard exists:
  (check-equal? (read-all-forms-string "x:where") '((x ($bcast-step :where))))
  (check-equal? (read-all-forms-string "x:wm") '((x ($bcast-step :wm)))))

(test-case "Q_M8: {:10 v} is a legal map key — the LATENT DEFECT this repairs"
  ;; `{:0 v}`, `{:1 v}`, `{:9 v}` were legal today while `{:10 v}` SHATTERED
  ;; into `: 10 v` and failed the even-count check. Arbitrary and
  ;; user-surprising, and unrelated to Path Selection.
  (check-equal? (read-all-forms-string "{:10 v}") '(($brace-params :10 v)))
  (check-equal? (read-all-forms-string "{:0 v}") '(($brace-params :0 v))))

(test-case "datum: plain {…} still mints $brace-params (must-not-break)"
  (check-equal? (read-all-forms-string "x {a b}") '((x ($brace-params a b)))))

(test-case "⭐ D4.P1b-ii FLAGSHIP: a nested .{ } does not expel its outer tail"
  ;; The INVERTED hazard. This groups CORRECTLY today (because `.{` lexes as
  ;; two tokens and the general lbrace arm handles the inner `{`); minting
  ;; dot-lbrace WITHOUT teaching every grouper about it REGRESSES it —
  ;; silently: the inner `}` closes the OUTER group and `version` is expelled.
  ;; The corpus A/B cannot catch this (exactly ONE live `.{` exists in all 160
  ;; corpus files, and it is not this shape), so it is pinned explicitly.
  (define forms (read-all-forms-string "app-config{server^.{ssl port} version}"))
  (check-equal? (length forms) 1)
  (define g (car forms))
  ;; `version` must be INSIDE the outer brace group, not a sibling of it.
  ;; ⚠ FLIPPED at D4.P1b-iii: `app-config{` is ADJACENT and `app-config` is not
  ;; a reader-form head, so under Q_M6 this brace is now a SELECT BLOCK. The
  ;; P1b-iii audit caught that §5.P1b-iii's test-delta never named this flip —
  ;; discovered at suite time it would have read as a regression.
  (check-equal? g '(app-config ($select-brace server^ ($dot-brace ssl port) version))))

(test-case "D4.P1b-ii: .{ nests inside itself"
  (check-equal? (read-all-forms-string "x.{a.{b c} d}")
                '((x ($dot-brace a ($dot-brace b c) d)))))

(test-case "D4.P1b-ii: angle groups still work INSIDE a .{ } block"
  ;; Q_M5 consequence, and the refutation of an audit question's premise: the
  ;; opener lists in langle-matched?/has-matching-rangle? are DEPTH-BALANCING
  ;; sets, not angle-SUPPRESSION sets. Suppression is keyed on frame kind
  ;; 'mixfix, which a 'brace/'rbrace frame never sets — so type-level angle
  ;; groups must keep grouping inside a select block.
  (check-equal? (length (read-all-forms-string "def f : <Int -> Int> := g.{a b}")) 1)
  (check-equal? (length (read-all-forms-string "x.{a b}\ndef p := 1 < 2\ndef q := 3 > 4")) 3))

(test-case "tokenizer: .*field broadcast"
  (define tok-rrb (tokenize-char-rrb (make-char-rrb-from-string "xs.*name")))
  (define toks (token-types-from-rrb tok-rrb))
  (check-equal? (car (list-ref toks 1)) 'broadcast-access)
  (check-equal? (cdr (list-ref toks 1)) ".*name"))

(test-case "tokenizer: |> pipe-right"
  (define tok-rrb (tokenize-char-rrb (make-char-rrb-from-string "|> x f")))
  (define toks (token-types-from-rrb tok-rrb))
  (check-equal? (car (list-ref toks 0)) 'symbol)
  (check-equal? (cdr (list-ref toks 0)) "|>"))

(test-case "tokenizer: | pipe separator"
  (define tok-rrb (tokenize-char-rrb (make-char-rrb-from-string "| x -> y")))
  (define toks (token-types-from-rrb tok-rrb))
  (check-equal? (car (list-ref toks 0)) 'pipe)
  (check-equal? (cdr (list-ref toks 0)) "|"))

(test-case "tokenizer: -> arrow"
  (define tok-rrb (tokenize-char-rrb (make-char-rrb-from-string "A -> B")))
  (define toks (token-types-from-rrb tok-rrb))
  (check-equal? (car (list-ref toks 1)) 'symbol)
  (check-equal? (cdr (list-ref toks 1)) "->"))

(test-case "tokenizer: #.field nil-dot-access"
  (define tok-rrb (tokenize-char-rrb (make-char-rrb-from-string "#.name")))
  (define toks (token-types-from-rrb tok-rrb))
  (check-equal? (car (list-ref toks 0)) 'nil-dot-access)
  (check-equal? (cdr (list-ref toks 0)) "#.name"))

(test-case "tokenizer: #:keyword nil-dot-key"
  (define tok-rrb (tokenize-char-rrb (make-char-rrb-from-string "#:key")))
  (define toks (token-types-from-rrb tok-rrb))
  (check-equal? (car (list-ref toks 0)) 'nil-dot-key)
  (check-equal? (cdr (list-ref toks 0)) "#:key"))

(test-case "tokenizer: bracket-depth includes compound openers"
  (define tok-rrb (tokenize-char-rrb (make-char-rrb-from-string "'[x]")))
  (define bd-rrb (make-bracket-depth-rrb tok-rrb))
  ;; '[ → depth 1, x → 1, ] → 0
  (check-equal? (car (rrb-get bd-rrb 0)) 1)
  (check-equal? (car (rrb-get bd-rrb 1)) 1)
  (check-equal? (car (rrb-get bd-rrb 2)) 0))

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

;; Helper: bracket depth after the LAST token of a string. If > 0, the
;; form-extent layer treats every following top-level line as a
;; continuation — the silent-swallow defect class (2026-07-26).
(define (final-bracket-depth s)
  (define tok-rrb (tokenize-char-rrb (make-char-rrb-from-string s)))
  (define bd-rrb (make-bracket-depth-rrb tok-rrb))
  (car (rrb-get bd-rrb (- (rrb-size bd-rrb) 1))))

(test-case "bracket-depth: < inside mixfix .( ) is an operator, not an opener"
  ;; The `.( 3N < 5N )` swallow: `<` counted +1 with no matching `>` left
  ;; depth 1 after `)`, so all following lines were eaten as continuation.
  (check-equal? (final-bracket-depth ".( 3N < 5N )") 0))

(test-case "bracket-depth: > inside mixfix .( ) is an operator"
  (check-equal? (final-bracket-depth ".( 5N > 3N )") 0))

(test-case "bracket-depth: < and > as operators inside mixfix stay balanced mid-form"
  ;; a < b > c inside .( ): neither angle counts; depth 1 throughout, 0 after )
  (define tok-rrb (tokenize-char-rrb (make-char-rrb-from-string ".( a < b > c )")))
  (define bd-rrb (make-bracket-depth-rrb tok-rrb))
  ;; tokens: .( a < b > c )  — indices 0..6
  (check-equal? (car (rrb-get bd-rrb 0)) 1)   ;; .(
  (check-equal? (car (rrb-get bd-rrb 2)) 1)   ;; < (operator, no bump)
  (check-equal? (car (rrb-get bd-rrb 4)) 1)   ;; > (operator, no drop)
  (check-equal? (car (rrb-get bd-rrb 6)) 0))  ;; )

(test-case "bracket-depth: unmatched < inside plain brackets is an operator"
  ;; [< 3N 5N] — group-items reads `<` as operator (no matching rangle);
  ;; the extent scan must agree or the same swallow occurs.
  (check-equal? (final-bracket-depth "[< 3N 5N]") 0))

(test-case "bracket-depth: matched angle group still counts as opener"
  (define tok-rrb (tokenize-char-rrb (make-char-rrb-from-string "<Int | String>")))
  (define bd-rrb (make-bracket-depth-rrb tok-rrb))
  (check-equal? (car (rrb-get bd-rrb 0)) 1)  ;; < opens
  (check-equal? (car (rrb-get bd-rrb (- (rrb-size bd-rrb) 1))) 0))  ;; > closes

(test-case "bracket-depth: multi-line angle group keeps continuation depth"
  ;; A matched `<` spanning a newline must still hold depth > 0 at the
  ;; line boundary so the continuation line joins the form.
  (define tok-rrb (tokenize-char-rrb (make-char-rrb-from-string "<(x : A)\n -> B>")))
  (define bd-rrb (make-bracket-depth-rrb tok-rrb))
  ;; token 0 = `<`; depth after the `)` closing (x : A) must still be 1
  (check-equal? (car (rrb-get bd-rrb 0)) 1)
  (define n (rrb-size bd-rrb))
  (check-equal? (car (rrb-get bd-rrb (- n 1))) 0)   ;; final > closes all
  (check-equal? (car (rrb-get bd-rrb (- n 2))) 1))  ;; B still inside <>

;; ---- D4.P1b-i (owner ruling Q_M4): the TOP-LEVEL `<` swallow ----
;; `langle-matched?`'s terminating arm needs a close-type, but at TOP LEVEL
;; close-type is #f — so the scan ran to the end of the whole token stream and
;; a `<` matched a `>` belonging to a LATER top-level form. Ordinary code
;; (`def p := 1 < 2` / `def q := 3 > 4`) silently collapsed into ONE form at
;; ZERO errors. The bound: a top-level `<` may not scan past the start of the
;; next top-level (indent-0) form. Continuation lines are INDENTED, so
;; multi-line angle groups are unaffected (pinned directly below).

(test-case "P1b-i: a top-level `<` does not match a `>` in a LATER top-level form"
  ;; The comparison pair that silently collapsed. Depth must return to 0.
  (check-equal? (final-bracket-depth "def p := 1 < 2\ndef q := 3 > 4") 0))

(test-case "P1b-i: the collapse is gone at the DATUM layer — two forms, not one"
  (check-equal? (length (read-all-forms-string "def p := 1 < 2\ndef q := 3 > 4")) 2))

(test-case "P1b-i: `:<` disclose shape is safe even with a later depth-0 `>`"
  ;; The audit showed the swallower is the bare `<`, NOT `:<` — this pins the
  ;; disclose spelling against the same hazard (grammar row owed by Q8; the
  ;; SEMANTICS land at P4).
  (check-equal? (length (read-all-forms-string "users:<{a}\ndef z := 1\na > b")) 3))

(test-case "P1b-i: the bare-`<` control is fixed too (no colon, no brace)"
  (check-equal? (length (read-all-forms-string "users<{a}\ndef z := 1\na > b")) 3))

(test-case "P1b-i MUST-STAY-GREEN: a multi-line angle group still spans its continuation"
  ;; Continuations are MORE-indented, so the relative-indent bound must not cut them.
  (check-equal? (length (read-all-forms-string "def f : <(x : Int)\n -> Int> := g")) 1)
  (check-equal? (length (read-all-forms-string "def u : <Int\n | String> := 42")) 1))

;; ---- The P1b-i adversarial verify's findings, pinned. Two earlier drafts of
;; this bound were wrong: the first hand-rolled a THIRD definition of
;; "indent-0 content line" (drifting from both `content-line?` and
;; `measure-indent` — the F1b.7g class); the second tested indent 0
;; ABSOLUTELY, which misses every file whose forms start indented. The bound
;; now compares RELATIVE indent and works per TOKEN. ----

(test-case "P1b-i: the bound works when the whole file is INDENTED (relative, not absolute)"
  ;; `  def a := 1` / `  def b := 2` is TWO forms with no angles — so a bound
  ;; keyed on "indent 0" would never fire here and the swallow would survive.
  (check-equal? (length (read-all-forms-string "  def a := 1\n  def b := 2")) 2)
  (check-equal? (length (read-all-forms-string "  def p := 1 < 2\n  def q := 3 > 4")) 2))

(test-case "P1b-i: TAB-indented siblings are bounded (measure-indent counts spaces only)"
  (check-equal? (length (read-all-forms-string "def p := 1 < 2\n\tdef q := 3 > 4")) 2))

(test-case "P1b-i: a CRLF blank line inside an angle group does NOT destroy it"
  ;; The first draft counted a bare `\r` as indent-0 CONTENT, registering a
  ;; phantom form start; `content-line?` string-trims, so it is not one.
  (check-equal? (length (read-all-forms-string "def u : <Int\r\n\r\n | String> := 42")) 1)
  (check-equal? (length (read-all-forms-string "def u : <Int\r\n | String> := 42")) 1))

(test-case "P1b-i: column-0 text inside a multi-line STRING is not a form start"
  ;; Free consequence of working per TOKEN: a multi-line string is ONE token,
  ;; so nothing inside it can begin a line as far as the bound is concerned.
  (check-equal? (length (read-all-forms-string "def f : <(x : Int)\n -> Foo \"ab\ncd\"> := g")) 1))

(test-case "bracket-depth: bracket group inside mixfix restores mixfix context"
  ;; .( [id 3N] < 5N ) — `<` after the nested [ ] pops back to the mixfix
  ;; frame, so it is still an operator.
  (check-equal? (final-bracket-depth ".( [id 3N] < 5N )") 0))

(test-case "bracket-depth: nested paren inside mixfix is nested mixfix"
  ;; .( (1N < 2N) ) — `(` directly inside .( ) opens a nested mixfix group
  ;; (group-items' lparen-in-mixfix leg), so `<` inside it stays an operator.
  (check-equal? (final-bracket-depth ".( (1N < 2N) )") 0))


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

;; ============================================================
;; Phase 3a: Read API
;; ============================================================

(test-case "read-to-tree: returns parse-tree struct"
  (define pt (read-to-tree "def x := 42"))
  (check-pred parse-tree? pt)
  (check-pred parse-tree-node? (parse-tree-root pt)))

(test-case "tree-top-level-forms: single def"
  (define pt (read-to-tree "def x := 42"))
  (define forms (tree-top-level-forms pt))
  (check-equal? (length forms) 1)
  (check-pred parse-tree-node? (car forms)))

(test-case "tree-top-level-forms: multiple defs"
  (define pt (read-to-tree "def x := 1\n\ndef y := 2\n\ndef z := 3"))
  (define forms (tree-top-level-forms pt))
  (check-equal? (length forms) 3))

(test-case "tree-children: line node has tokens"
  (define pt (read-to-tree "def x := 42"))
  (define forms (tree-top-level-forms pt))
  (define children (tree-children (car forms)))
  ;; Should have token-entry children (def, x, :=, 42)
  (check-true (> (length children) 0))
  (check-pred token-entry? (car children)))

(test-case "tree-children: nested node has sub-nodes"
  (define pt (read-to-tree "def f [x]\n  [int+ x 1]"))
  (define forms (tree-top-level-forms pt))
  (define children (tree-children (car forms)))
  ;; Top-level form has tokens AND a child line node
  (check-true (ormap parse-tree-node? children)))

(test-case "tree-parent: finds parent of child"
  (define pt (read-to-tree "def f [x]\n  body"))
  (define forms (tree-top-level-forms pt))
  (define top (car forms))
  ;; Find a child line node
  (define children (tree-children top))
  (define sub-node (findf parse-tree-node? children))
  (when sub-node
    (define parent (tree-parent pt sub-node))
    (check-eq? parent top)))

(test-case "tree-parent: root children have root as parent"
  (define pt (read-to-tree "def x := 42"))
  (define forms (tree-top-level-forms pt))
  (define parent (tree-parent pt (car forms)))
  (check-pred parse-tree-node? parent)
  (check-equal? (parse-tree-node-tag parent) 'root))

(test-case "read-file-to-tree: reads real file"
  (define nat-path
    (build-path project-root "lib" "prologos" "data" "nat.prologos"))
  (when (file-exists? nat-path)
    (define pt (read-file-to-tree nat-path))
    (check-pred parse-tree? pt)
    (define forms (tree-top-level-forms pt))
    (check-true (> (length forms) 5))))

;; ============================================================
;; Phase 3b: Write API
;; ============================================================

(test-case "tree-replace-children: replaces all children"
  (define pt (read-to-tree "def x := 42"))
  (define form (car (tree-top-level-forms pt)))
  (define new-node (tree-replace-children form '()))
  (check-equal? (length (tree-children new-node)) 0))

(test-case "tree-insert-child: inserts at position"
  (define pt (read-to-tree "def x := 42"))
  (define form (car (tree-top-level-forms pt)))
  (define children-before (tree-children form))
  (define dummy (token-entry (seteq 'symbol) "inserted" 0 8))
  (define new-node (tree-insert-child form dummy 1))
  (define children-after (tree-children new-node))
  (check-equal? (length children-after) (+ 1 (length children-before)))
  (check-eq? (list-ref children-after 1) dummy))

(test-case "tree-remove-child: removes by identity"
  (define pt (read-to-tree "def x := 42"))
  (define form (car (tree-top-level-forms pt)))
  (define children (tree-children form))
  (define target (car children))
  (define new-node (tree-remove-child form target))
  (check-equal? (length (tree-children new-node))
                (- (length children) 1)))

(test-case "tree-splice: replaces one child with multiple"
  (define pt (read-to-tree "def x := 42"))
  (define form (car (tree-top-level-forms pt)))
  (define children (tree-children form))
  (define target (car children))
  (define r1 (token-entry (seteq 'symbol) "a" 0 1))
  (define r2 (token-entry (seteq 'symbol) "b" 0 1))
  (define new-node (tree-splice form target (list r1 r2)))
  (define new-children (tree-children new-node))
  ;; One child replaced by two → length + 1
  (check-equal? (length new-children) (+ 1 (length children)))
  (check-eq? (car new-children) r1)
  (check-eq? (cadr new-children) r2))

;; ============================================================
;; Phase 3c: Compatibility wrappers
;; ============================================================

(test-case "compat-tokenize-string: produces compat-tokens with newline/eof padding"
  (define tokens (compat-tokenize-string "def x := 42"))
  (check-true (> (length tokens) 2))
  ;; First token is synthetic newline
  (check-equal? (compat-token-type (car tokens)) 'newline)
  ;; Content tokens start at index 1
  (check-pred compat-token? (cadr tokens))
  (check-equal? (compat-token-type (cadr tokens)) 'symbol)
  (check-equal? (compat-token-value (cadr tokens)) 'def)
  ;; Last token is synthetic eof
  (check-equal? (compat-token-type (last tokens)) 'eof))

(test-case "compat-tokenize-string: token positions"
  (define tokens (compat-tokenize-string "x y"))
  ;; Skip newline at index 0; content starts at index 1
  (define t0 (cadr tokens))     ;; x
  (define t1 (caddr tokens))    ;; y
  (check-equal? (compat-token-pos t0) 0)
  (check-equal? (compat-token-span t0) 1)
  (check-equal? (compat-token-pos t1) 2)
  (check-equal? (compat-token-span t1) 1))

(test-case "compat-tokenize-string: line/col computation"
  (define tokens (compat-tokenize-string "a\nb"))
  ;; Skip newline at index 0; content starts at index 1
  (define t0 (cadr tokens))     ;; a
  (define t1 (caddr tokens))    ;; b
  (check-equal? (compat-token-line t0) 1)
  (check-equal? (compat-token-col t0) 0)
  (check-equal? (compat-token-line t1) 2)
  (check-equal? (compat-token-col t1) 0))

(test-case "compat-tokenize-string: number value"
  (define tokens (compat-tokenize-string "42"))
  (check-equal? (compat-token-type (cadr tokens)) 'number)
  (check-equal? (compat-token-value (cadr tokens)) 42))

(test-case "compat-tokenize-string: string value"
  (define tokens (compat-tokenize-string "\"hello\""))
  (check-equal? (compat-token-type (cadr tokens)) 'string))

(test-case "compat-tokenize-string: keyword value"
  (define tokens (compat-tokenize-string ":name"))
  (check-equal? (compat-token-type (cadr tokens)) 'keyword)
  (check-equal? (compat-token-value (cadr tokens)) ':name))

(test-case "compat-tokenize-string: dot-access value"
  (define tokens (compat-tokenize-string "x.name"))
  ;; Skip newline, first content is x at index 1, dot-access at index 2
  (define dot-tok (caddr tokens))
  (check-equal? (compat-token-type dot-tok) 'dot-access)
  (check-equal? (compat-token-value dot-tok) 'name))

;; ============================================================
;; Phase 5a: Datum extraction
;; ============================================================

(test-case "datum: simple def"
  (define old (read-all-forms-string "def x := 42"))
  (define new (compat-read-all-forms-string "def x := 42"))
  (check-equal? new old))

(test-case "datum: bracket form"
  (define old (read-all-forms-string "[f x y]"))
  (define new (compat-read-all-forms-string "[f x y]"))
  (check-equal? new old))

(test-case "datum: nested brackets"
  (define old (read-all-forms-string "[[x] [y]]"))
  (define new (compat-read-all-forms-string "[[x] [y]]"))
  (check-equal? new old))

(test-case "datum: indented body"
  (define old (read-all-forms-string "def f [x]\n  [int+ x 1]"))
  (define new (compat-read-all-forms-string "def f [x]\n  [int+ x 1]"))
  (check-equal? new old))

(test-case "datum: dot-access"
  (define old (read-all-forms-string "user.name"))
  (define new (compat-read-all-forms-string "user.name"))
  (check-equal? new old))

(test-case "datum: pipe operator"
  (define old (read-all-forms-string "|> 5 inc dbl"))
  (define new (compat-read-all-forms-string "|> 5 inc dbl"))
  (check-equal? new old))

(test-case "datum: angle bracket type"
  (define src "spec f Int -> <Bool>")
  (define old (read-all-forms-string src))
  (define new (compat-read-all-forms-string src))
  (check-equal? new old))

(test-case "datum: brace params"
  (define src (string-append "{" ":name \"alice\"}"))
  (define old (read-all-forms-string src))
  (define new (compat-read-all-forms-string src))
  (check-equal? new old))

(test-case "datum: module path"
  (define old (read-all-forms-string "ns prologos::data::nat"))
  (define new (compat-read-all-forms-string "ns prologos::data::nat"))
  (check-equal? new old))

(test-case "datum: pattern match with pipe"
  (define old (read-all-forms-string "defn f\n  | zero -> true\n  | suc _ -> false"))
  (define new (compat-read-all-forms-string "defn f\n  | zero -> true\n  | suc _ -> false"))
  (check-equal? new old))

(test-case "datum: nat.prologos matches old reader"
  (define nat-path (build-path project-root "lib" "prologos" "data" "nat.prologos"))
  (when (file-exists? nat-path)
    (define src (file->string nat-path))
    (define old (read-all-forms-string src))
    (define new (compat-read-all-forms-string src))
    (check-equal? new old)))

;; ============================================================
;; Phase 4: Bracket matching validation
;; ============================================================
;;
;; Verifies that the new tokenizer produces properly balanced
;; brackets across real .prologos files.

(define (bracket-balance tok-rrb)
  ;; Returns 0 if balanced, positive if unclosed, negative if over-closed
  ;; Excludes langle/rangle — these are context-dependent (operator vs delimiter)
  ;; and handled by the disambiguator, not by simple bracket counting.
  (define n (rrb-size tok-rrb))
  (let loop ([i 0] [depth 0])
    (if (>= i n)
        depth
        (let* ([entry (rrb-get tok-rrb i)]
               [type (set-first (token-entry-types entry))]
               [d (cond
                    ;; ⚠ THIRD COPY of the production opener list (the other two
                    ;; are langle-matched? / has-matching-rangle? in
                    ;; parse-reader.rkt). It is a hand-maintained duplicate of a
                    ;; production invariant and it DRIFTS: D4.P1b-ii's
                    ;; `dot-lbrace` made this oracle report a real example file
                    ;; as unbalanced until it was added here. If you add an
                    ;; opener token type, it goes in all three — and the Q_N3
                    ;; agreement guard above only covers the two PRODUCTION
                    ;; groupers, not this oracle.
                    [(memq type '(lbracket lparen lbrace
                                  quote-lbracket at-lbracket tilde-lbracket
                                  hash-lbrace dot-lparen dot-lbrace))
                     (+ depth 1)]
                    [(memq type '(rbracket rparen rbrace))
                     (- depth 1)]
                    [else depth])])
          (loop (+ i 1) d)))))

;; ============================================================
;; CIU T6 D4.P1b-ii Q_N3 — THE TWO-GROUPER AGREEMENT GUARD (structural)
;;
;; The tree carries TWO independent grouping implementations: parse-reader's
;; `group-items` (datum layer) and surface-rewrite's `group-items-to-tree`
;; (tree layer). Each dispatches on token type through a hand-written arm
;; list ending in a bare `[else]` catch-all — the exact shape
;; `.claude/rules/pipeline.md` § "Exhaustive Walkers" names as a red flag.
;; When an opener is known to one and not the other they SILENTLY DISAGREE:
;; that is the live `.( )` defect (DEFERRED, filed 2026-07-28), where the
;; datum layer keeps the trailing token and the tree layer expels it, at
;; ZERO errors.
;;
;; This guard makes the class impossible by CONSTRUCTION rather than by
;; checklist: for `a OPEN b CLOSE c`, both layers must agree that the form
;; has THREE top-level items (a, the group, c). A grouper that does not know
;; an opener produces a different count.
;; ============================================================

(define (grouped-line-item-count s)
  ;; tree layer: direct children of the line node after grouping
  (define grouped (group-tree-node (parse-tree-root (read-to-tree s))))
  (define line (rrb-get (parse-tree-node-children grouped) 0))
  (rrb-size (parse-tree-node-children line)))

(define (datum-form-item-count s)
  ;; datum layer: top-level items of the single form
  (define forms (read-all-forms-string s))
  (and (= (length forms) 1) (length (car forms))))

(test-case "Q_N3 GUARD: every opener groups IDENTICALLY at both layers"
  ;; (opener-literal closer-literal label)
  (define openers
    (list (list "["   "]" 'lbracket)
          (list "("   ")" 'lparen)
          (list "{"   "}" 'lbrace)
          (list "'["  "]" 'quote-lbracket)
          (list "@["  "]" 'at-lbracket)
          (list "~["  "]" 'tilde-lbracket)
          (list "#{"  "}" 'hash-lbrace)
          (list ".{"  "}" 'dot-lbrace)))   ;; D4.P1b-ii — the new one
  ;; ⚠ NAMED EXCLUSION: `dot-lparen` FAILS this guard today — tree layer
  ;; reports 4 where the datum layer reports 3, because surface-rewrite.rkt
  ;; has no dot-lparen arm at all. Owner-ruled Q_N2: FILED, not fixed here
  ;; (the repair needs a 'mixfix frame concept group-items-to-tree lacks,
  ;; and the 'mixfix-group tag its arm would emit was deleted at D4.P1a).
  ;; See DEFERRED.md § "CIU T6 D4.P1b-ii spin-offs" item 1. When that lands,
  ;; delete this comment and add (list ".(" ")" 'dot-lparen) above.
  (for ([o (in-list openers)])
    (define src (string-append "a " (car o) " b " (cadr o) " c"))
    (define tree-n (grouped-line-item-count src))
    (define datum-n (datum-form-item-count src))
    (check-equal? datum-n 3
                  (format "datum layer lost/gained an item for ~a: ~s"
                          (caddr o) (read-all-forms-string src)))
    (check-equal? tree-n datum-n
                  (format "LAYER DISAGREEMENT for ~a — tree=~a datum=~a (this is the .( ) defect class)"
                          (caddr o) tree-n datum-n))))

(test-case "Q_N3 GUARD v2 (D4.P1b-iii): the two layers agree on the brace SENTINEL, not just counts"
  ;; ⚠ The original guard was STRUCTURALLY BLIND to P1b-iii, twice over: every
  ;; row was built SPACED (exactly the population adjacency must NOT change),
  ;; and it compared ITEM COUNTS while this phase's defect class is a SHAPE
  ;; divergence at EQUAL count. This row set closes both holes by asserting the
  ;; tree TAG corresponds to the datum SENTINEL for each brace spelling.
  ;;
  ;; It is the guard that would catch "adjacency implemented in parse-reader
  ;; only" — the failure mode that would otherwise SILENTLY hand back a map
  ;; literal, because brace-group has a non-error tree handler and driver lets a
  ;; non-error tree surf replace preparse's error surf.
  (define cases
    (list (list "x{a}"        '$select-brace  'select-brace-group "adjacent → select")
          (list "x {a}"       '$brace-params  'brace-group        "spaced → literal")
          (list "racket{a}"   '$brace-params  'brace-group        "head-adjacent → literal")
          (list "racket {a}"  '$brace-params  'brace-group        "head-spaced → literal")
          (list "x.{a}"       '$dot-brace     'dot-brace-group    "dot-brace")
          (list "x#{a}"       '$set-literal   'set-group          "set literal")))
  (for ([c (in-list cases)])
    (define src (car c))
    ;; datum layer: find the sentinel head of the last item in the form
    (define form (car (read-all-forms-string src)))
    (define datum-head (let ([lst (car (reverse form))]) (and (pair? lst) (car lst))))
    (check-equal? datum-head (cadr c)
                  (format "DATUM layer wrong for ~a (~a)" src (cadddr c)))
    ;; tree layer: the tag of the last child of the line
    (define grouped (group-tree-node (parse-tree-root (read-to-tree src))))
    (define line (rrb-get (parse-tree-node-children grouped) 0))
    (define kids (parse-tree-node-children line))
    (define lastk (rrb-get kids (- (rrb-size kids) 1)))
    (check-true (parse-tree-node? lastk)
                (format "TREE layer produced no group for ~a — the grouper does not know this shape" src))
    (check-equal? (parse-tree-node-tag lastk) (caddr c)
                  (format "LAYER DISAGREEMENT for ~a (~a): datum ~a vs tree ~a"
                          src (cadddr c) datum-head (parse-tree-node-tag lastk)))))

(test-case "Q_N3 GUARD: the guard actually detects a known divergence (dot-lparen)"
  ;; The guard is only worth having if it fails on the real bug. Pin the
  ;; KNOWN-BAD case so that if `.( )` is ever repaired this test goes red and
  ;; whoever fixed it promotes dot-lparen into the guard list above.
  (define src "a .( b ) c")
  (check-equal? (datum-form-item-count src) 3)
  (check-equal? (grouped-line-item-count src) 4
                "dot-lparen tree/datum divergence is FIXED — promote it into the Q_N3 guard list and delete this test"))

(test-case "bracket-balance: simple expressions"
  (define test-strings
    (list "[f x]" "[[x]]" "(match x)" "{:a 1}" "'[1 2]" "@[1]"))
  (for ([s (in-list test-strings)])
    (define tok-rrb (tokenize-char-rrb (make-char-rrb-from-string s)))
    (check-equal? (bracket-balance tok-rrb) 0
                  (format "Unbalanced brackets in: ~a" s))))

(test-case "bracket-balance: all library .prologos files balanced"
  (define lib-dir (build-path project-root "lib" "prologos"))
  (define files
    (for/list ([f (in-directory lib-dir)]
               #:when (regexp-match? #rx"\\.prologos$" (path->string f))
               ;; Skip editor lock/autosave files (Emacs: .#name, name.~undo-tree~, etc.)
               ;; A leading `.` or `~` in the basename is conventionally non-source.
               #:unless (let ([name (path->string (file-name-from-path f))])
                          (or (regexp-match? #rx"^\\." name)
                              (regexp-match? #rx"^~" name))))
      f))
  (define unbalanced 0)
  (for ([f (in-list files)])
    (with-handlers ([exn? (lambda (e) (set! unbalanced (+ unbalanced 1)))])
      (define src (file->string f))
      (define tok-rrb (tokenize-char-rrb (make-char-rrb-from-string src)))
      (define bal (bracket-balance tok-rrb))
      (unless (= bal 0)
        (set! unbalanced (+ unbalanced 1)))))
  (check-equal? unbalanced 0
                (format "~a library files have unbalanced brackets" unbalanced)))

(test-case "bracket-balance: all example files balanced"
  (define examples-dir (build-path project-root "examples"))
  (define files
    (if (directory-exists? examples-dir)
        (for/list ([f (in-directory examples-dir)]
                   #:when (regexp-match? #rx"\\.prologos$" (path->string f))
                   ;; Skip editor lock/autosave files (Emacs: .#name, name.~undo-tree~, etc.)
                   ;; A leading `.` or `~` in the basename is conventionally non-source.
                   #:unless (let ([name (path->string (file-name-from-path f))])
                              (or (regexp-match? #rx"^\\." name)
                                  (regexp-match? #rx"^~" name))))
          f)
        '()))
  (define unbalanced 0)
  (for ([f (in-list files)])
    (with-handlers ([exn? (lambda (e) (set! unbalanced (+ unbalanced 1)))])
      (define src (file->string f))
      (define tok-rrb (tokenize-char-rrb (make-char-rrb-from-string src)))
      (define bal (bracket-balance tok-rrb))
      (unless (= bal 0)
        (set! unbalanced (+ unbalanced 1)))))
  (check-equal? unbalanced 0
                (format "~a example files have unbalanced brackets" unbalanced)))

;; ============================================================
;; Phase 1f: Integration gate — topology comparison
;; ============================================================
;;
;; Extracts topology from the new reader's tree and compares
;; against the golden capture's reference-topology.
;; Both compute parent/indent from the same source string;
;; they must agree.

;; Reference topology from raw string (same algorithm as golden-capture.rkt):
;; Returns list of (content-idx source-line indent parent-idx)
(define (reference-topology src)
  (define lines (string-split src "\n"))
  (define content-lines '())
  (define stack '())
  (for ([line (in-list lines)]
        [i (in-naturals)])
    (define trimmed (string-trim line))
    (when (and (> (string-length trimmed) 0)
               (not (string-prefix? trimmed ";")))
      (define indent
        (let loop ([j 0])
          (if (and (< j (string-length line))
                   (char=? (string-ref line j) #\space))
              (loop (+ j 1))
              j)))
      (set! stack
        (let loop ([s stack])
          (if (and (pair? s) (>= (car (car s)) indent))
              (loop (cdr s))
              s)))
      (define parent (if (null? stack) -1 (cdr (car stack))))
      (set! stack (cons (cons indent (length content-lines)) stack))
      (set! content-lines
        (cons (list (length content-lines) i indent parent) content-lines))))
  (reverse content-lines))

;; Extract topology from new reader's cells:
;; Read the indent RRB and content-line-indices, recompute parents
;; using the same stack algorithm as reference-topology.
;; Returns list of (content-idx source-line indent parent-idx)
(define (extract-new-topology src)
  (define-values (net cells) (parse-string-to-cells src))
  (define indent-rrb (net-cell-read net (parse-cells-indent-cell-id cells)))
  ;; Also need content-line-indices — get from the char-rrb
  (define char-rrb (net-cell-read net (parse-cells-char-cell-id cells)))
  (define-values (_indent-rrb2 content-line-indices)
    (make-indent-rrb-from-char-rrb char-rrb))
  ;; Recompute parents from indent RRB using stack algorithm
  (define n (rrb-size indent-rrb))
  (define result '())
  (define stack '())
  (for ([i (in-range n)])
    (define indent (rrb-get indent-rrb i))
    (define src-line (rrb-get content-line-indices i))
    (set! stack
      (let loop ([s stack])
        (if (and (pair? s) (>= (car (car s)) indent))
            (loop (cdr s))
            s)))
    (define parent (if (null? stack) -1 (cdr (car stack))))
    (set! stack (cons (cons indent i) stack))
    (set! result (cons (list i src-line indent parent) result)))
  (reverse result))

(test-case "integration: topology matches golden for simple def"
  (define src "def x := 42")
  (define golden-topo (reference-topology src))
  (define new-topo (extract-new-topology src))
  ;; Both should have 1 content line at indent 0, parent -1
  (check-equal? (length new-topo) (length golden-topo))
  (for ([g (in-list golden-topo)]
        [n (in-list new-topo)])
    ;; Compare indent levels (field 2) and parent indices (field 3)
    (check-equal? (third n) (third g)
                  (format "indent mismatch at line ~a: new=~a golden=~a"
                          (first n) (third n) (third g)))
    (check-equal? (fourth n) (fourth g)
                  (format "parent mismatch at line ~a: new=~a golden=~a"
                          (first n) (fourth n) (fourth g)))))

(test-case "integration: topology matches golden for indented body"
  (define src "def f [x]\n  [int+ x 1]")
  (define golden-topo (reference-topology src))
  (define new-topo (extract-new-topology src))
  (check-equal? (length new-topo) (length golden-topo))
  (for ([g (in-list golden-topo)]
        [n (in-list new-topo)])
    (check-equal? (third n) (third g))
    (check-equal? (fourth n) (fourth g))))

(test-case "integration: topology matches golden for multi-form"
  (define src "def x := 1\n\ndef y := 2\n\ndef z := 3")
  (define golden-topo (reference-topology src))
  (define new-topo (extract-new-topology src))
  (check-equal? (length new-topo) (length golden-topo))
  (for ([g (in-list golden-topo)]
        [n (in-list new-topo)])
    (check-equal? (third n) (third g))
    (check-equal? (fourth n) (fourth g))))

(test-case "integration: topology matches golden for nested indent"
  (define src "trait Foo\n  method bar\n    body\n  method baz\n    other")
  (define golden-topo (reference-topology src))
  (define new-topo (extract-new-topology src))
  (check-equal? (length new-topo) (length golden-topo))
  (for ([g (in-list golden-topo)]
        [n (in-list new-topo)])
    (check-equal? (third n) (third g))
    (check-equal? (fourth n) (fourth g))))

(test-case "integration: topology matches on real .prologos file"
  ;; Use nat.prologos as a real-world test
  (define nat-path (build-path project-root "lib" "prologos" "data" "nat.prologos"))
  (when (file-exists? nat-path)
    (define src (file->string nat-path))
    (define golden-topo (reference-topology src))
    (define new-topo (extract-new-topology src))
    (check-equal? (length new-topo) (length golden-topo)
                  (format "line count mismatch: new=~a golden=~a"
                          (length new-topo) (length golden-topo)))
    (for ([g (in-list golden-topo)]
          [n (in-list new-topo)]
          [i (in-naturals)])
      (check-equal? (third n) (third g)
                    (format "indent mismatch at content line ~a" i))
      (check-equal? (fourth n) (fourth g)
                    (format "parent mismatch at content line ~a" i)))))

(test-case "integration: topology matches on multiple library files"
  (define lib-dir (build-path project-root "lib" "prologos"))
  (define files
    (for/list ([f (in-directory lib-dir)]
               #:when (regexp-match? #rx"\\.prologos$" (path->string f))
               ;; Skip editor lock/autosave files (Emacs: .#name, name.~undo-tree~, etc.)
               ;; A leading `.` or `~` in the basename is conventionally non-source.
               #:unless (let ([name (path->string (file-name-from-path f))])
                          (or (regexp-match? #rx"^\\." name)
                              (regexp-match? #rx"^~" name))))
      f))
  (check-true (> (length files) 10)
              "Expected at least 10 .prologos library files")
  (define passed 0)
  (define failed 0)
  (for ([f (in-list files)])
    (with-handlers ([exn? (lambda (e)
                            (set! failed (+ failed 1))
                            (printf "  ERROR ~a: ~a\n"
                                    (find-relative-path project-root f)
                                    (substring (exn-message e)
                                               0 (min 80 (string-length (exn-message e))))))])
      (define src (file->string f))
      (define ref-topo (reference-topology src))
      (define new-topo (extract-new-topology src))
      (cond
        [(not (= (length new-topo) (length ref-topo)))
         (set! failed (+ failed 1))
         (printf "  LINES ~a: new=~a ref=~a\n"
                 (find-relative-path project-root f)
                 (length new-topo) (length ref-topo))]
        [(for/and ([g (in-list ref-topo)]
                   [n (in-list new-topo)])
           (and (= (third n) (third g))
                (= (fourth n) (fourth g))))
         (set! passed (+ passed 1))]
        [else
         (set! failed (+ failed 1))
         ;; Find first mismatch
         (for ([g (in-list ref-topo)]
               [n (in-list new-topo)]
               [i (in-naturals)])
           (unless (and (= (third n) (third g))
                        (= (fourth n) (fourth g)))
             (printf "  DIFF ~a line ~a: new=(~a ~a) ref=(~a ~a)\n"
                     (find-relative-path project-root f)
                     i (third n) (fourth n) (third g) (fourth g))
             ;; Only print first diff
             (void)))])))
  (check-equal? failed 0
                (format "~a/~a library files failed topology comparison"
                        failed (+ passed failed))))

(test-case "integration: topology matches on example files"
  (define examples-dir (build-path project-root "examples"))
  (define files
    (if (directory-exists? examples-dir)
        (for/list ([f (in-directory examples-dir)]
                   #:when (regexp-match? #rx"\\.prologos$" (path->string f))
                   ;; Skip editor lock/autosave files (Emacs: .#name, name.~undo-tree~, etc.)
                   ;; A leading `.` or `~` in the basename is conventionally non-source.
                   #:unless (let ([name (path->string (file-name-from-path f))])
                              (or (regexp-match? #rx"^\\." name)
                                  (regexp-match? #rx"^~" name))))
          f)
        '()))
  (define passed 0)
  (define failed 0)
  (for ([f (in-list files)])
    (with-handlers ([exn? (lambda (e)
                            (set! failed (+ failed 1)))])
      (define src (file->string f))
      (define ref-topo (reference-topology src))
      (define new-topo (extract-new-topology src))
      (if (and (= (length new-topo) (length ref-topo))
               (for/and ([g (in-list ref-topo)]
                         [n (in-list new-topo)])
                 (and (= (third n) (third g))
                      (= (fourth n) (fourth g)))))
          (set! passed (+ passed 1))
          (set! failed (+ failed 1)))))
  (check-equal? failed 0
                (format "~a/~a example files failed topology comparison"
                        failed (+ passed failed))))

;; ============================================================
;; CIU T6 D4.P2 — the `.N` ordinal-access token (Q_M8's dot half)
;;
;; Dot-anchored `digit+` (owner ruling Q_M8: MULTI-digit), with the Q_R2
;; trailing guard copied from the `:N` twin, minting `$postfix-index` per
;; owner ruling Q_R1 (NOT a new sentinel — reuse is near-free and the
;; existing fold arm is already a fixpoint).
;;
;; ⚠ TWO-LAYER PIN. These are the DATUM-layer half. The design originally
;; claimed the rational mis-lex sat "at 0 errors"; that was a LAYER ERROR —
;; end-to-end the stranded bare `|.|` is unbound, so every rational-class form
;; is LOUD today. The end-to-end half lives in test-path-selection.rkt and is
;; framed "was a misleading error, now computes the right value".
;; ============================================================

(test-case "P2: .N produces a dot-ordinal token, MULTI-digit (Q_M8)"
  (define toks (token-types-from-rrb (tokenize-char-rrb (make-char-rrb-from-string "x.10"))))
  (check-equal? (length toks) 2)
  (check-equal? (car (list-ref toks 0)) 'symbol)
  (check-equal? (car (list-ref toks 1)) 'dot-ordinal)
  (check-equal? (cdr (list-ref toks 1)) ".10"))

(test-case "P2: .N mints $postfix-index with a NUMERIC payload (Q_R1)"
  ;; The payload must be a NUMBER, not a symbol: that is what makes it
  ;; byte-identical to `v[0]`'s bare fixnum, which is what makes Q_R1's
  ;; "two surfaces, ONE mechanism" hold at the datum layer rather than
  ;; merely architecturally. `string->number`, not `string->symbol`.
  (check-equal? (read-all-forms-string "x.10") '((x ($postfix-index 10))))
  (check-equal? (read-all-forms-string "x.0")  '((x ($postfix-index 0)))))

(test-case "P2 ⭐ Q_R1's checkable pin: `v[0]` and `v.0` are the SAME DATUM"
  ;; Owner ruling: two SURFACES over ONE mechanism. If this ever diverges,
  ;; the ruling has silently stopped being true.
  (check-equal? (read-all-forms-string "v.0") (read-all-forms-string "v[0]"))
  (check-equal? (read-all-forms-string "v.10") (read-all-forms-string "v[10]")))

(test-case "P2 ⭐ the RATIONAL mis-lex is dead, structurally (datum layer)"
  ;; Today `x.1.2` reads as ($decimal-literal 6/5) and `x.10.20` as 51/5,
  ;; because `decimal-literal` anchors at the DIGIT. A dot-anchored
  ;; recognizer consumes `.1` first, so decimal-literal never gets to anchor.
  (check-equal? (read-all-forms-string "x.1.2")
                '((x ($postfix-index 1) ($postfix-index 2))))
  (check-equal? (read-all-forms-string "x.10.20")
                '((x ($postfix-index 10) ($postfix-index 20))))
  ;; and no rational survives anywhere in the datum
  (check-false (regexp-match? #rx"decimal-literal"
                             (format "~s" (read-all-forms-string "x.1.2")))))

(test-case "P2: mixed chains lex in BOTH directions now (field→nat was broken)"
  (check-equal? (read-all-forms-string "x.0.name")
                '((x ($postfix-index 0) ($dot-access name))))
  (check-equal? (read-all-forms-string "x.name.0")
                '((x ($dot-access name) ($postfix-index 0)))))

(test-case "P2 Q_R2: the TRAILING GUARD declines every suffixed numeric shape"
  ;; Copied from the `:N` twin (parse-reader.rkt: `[(and c (ident-continue? c)) #f]`).
  ;; Each of these lexes as ONE numeric token today and KEEPS doing so — the
  ;; guard mints no new error surface. `xs.0N` is a NAMED NON-GOAL (`0N` is the
  ;; project's Nat spelling and expr-get accepts Nat or Int, so it reads as
  ;; sensible Prologos — but supporting it needs `digit+` plus optional `N`).
  ;; ⚠ HONEST NOTE: before the recognizer exists this passes TRIVIALLY (no
  ;; `dot-ordinal` token exists at all). It is a MUST-STAY-GREEN guard, not a
  ;; failing-first pin — its value is entirely post-implementation.
  (for ([s (in-list '("x.0N" "x.1e3" "x.1/2" "x.1f" "x.1p8"))])
    (define toks (token-types-from-rrb (tokenize-char-rrb (make-char-rrb-from-string s))))
    (check-false (and (assq 'dot-ordinal toks) #t)
                 (format "~a must DECLINE the guard, not split into .N + stray" s))))

(test-case "P2 Q_R3: the dot band is ADJACENCY-FREE — ruled, not inherited"
  ;; `adjacent-to-base?` is called only from the bracket and brace arms, so the
  ;; dot band has no gate at all — and `.k` never had one either. Requiring
  ;; adjacency for `.N` alone would be a NEW inconsistency inside the band.
  (check-equal? (read-all-forms-string "x .0") '((x ($postfix-index 0))))
  ;; ⚠ SHARPENED BY MEASUREMENT — the P2 audit conflated two different spaces.
  ;; A space BEFORE the dot is irrelevant (no base-adjacency gate, above), but a
  ;; space AFTER the dot means there is no `.N` LEXEME at all: contiguity is
  ;; inherent to being one token, exactly as it is for the `?x:Nat` twin. So
  ;; `x. 0` is NOT ordinal access and must stay the single-char fallback.
  (check-equal? (read-all-forms-string "x. 0") '((x |.| 0)))
  ;; consequence, pinned so it is deliberate: a form-leading `.N` is a
  ;; base-less sentinel (the fold's null-acc leg keeps it raw).
  (check-equal? (read-all-forms-string ".5") '(($postfix-index 5))))

(test-case "P2: leading zeros COLLAPSE — pinned rather than discovered"
  ;; `string->number` on "007" is 7. Inherited from the number classifier's
  ;; own conversion; the `:N` twin does the same since P1b-iii.
  (check-equal? (read-all-forms-string "x.007") '((x ($postfix-index 7)))))

(test-case "P2 MUST-NOT-BREAK: the rest of the dot band and every numeric literal"
  ;; the other five band members
  (check-equal? (read-all-forms-string "x.name")  '((x ($dot-access name))))
  (check-equal? (read-all-forms-string "x...")    '((x $rest)))
  (check-equal? (read-all-forms-string "x.{a}")   '((x ($dot-brace a))))
  ;; `.-1` / `.+1` lex CLEANLY as dot-access with a SIGNED field (`ident-start?`
  ;; admits both `-` and `+`), so a digit-required `.N` correctly declines them.
  (check-equal? (read-all-forms-string "x.-1")    '((x ($dot-access |-1|))))
  (check-equal? (read-all-forms-string "x.+1")    '((x ($dot-access |+1|))))
  ;; interior dots are structurally unreachable as anchors: the scan advances by
  ;; the matched length, so `3.14` is consumed whole at the `3`.
  (check-equal? (read-all-forms-string "1.5")     '(($decimal-literal 3/2)))
  (check-equal? (read-all-forms-string "3.14")    '(($decimal-literal 157/50)))
  (check-equal? (read-all-forms-string "[+ 1 2.5]") '((+ 1 ($decimal-literal 5/2)))))

;; ============================================================
;; D4.P4c-1 (Q_U16b) — `colon-annotation` becomes a REAL token type
;; ============================================================
;;
;; Q_U16b rules `users:0` a legal ω step, so P4c-2's `:` gate must dispatch on
;; the ordinal band at GROUPING. It cannot today: `recognize-colon-annotation`'s
;; registered classifier is `(lambda (s p l) 'symbol)`, so `:0`/`:w`/`:m` are
;; type-indistinguishable from any ordinary identifier.
;;
;; The rival mechanism (carry a pattern-provenance field on `token-entry`) was
;; measured at 25 constructor sites across 7 files — and sre-rewrite.rkt holds 4
;; of them, borrowing `token-entry` as a general-purpose term carrier
;; ('binding/'sample/'constant), which makes it a struct-OWNERSHIP question.
;; Classifier promotion wins on cost by an order of magnitude. It is filed
;; separately on its OWN merits ($exp-literal + $rat-literal, both
;; self-documented as identity-erased), NOT as a scheduled revert of this.
;;
;; These pins live HERE, beside their siblings and the eight datum pins that
;; flip at P4c-2, because this file calls `register-default-token-patterns!` at
;; :23 — a direct `tokenize-char-rrb` without it matches NOTHING and returns a
;; FALSE ZERO (the footgun `tools/reader-corpus-ab.rkt:74` carries a tripwire
;; for; it bit the author of these pins once before they were written).

(test-case "P4c-1: `:0` carries the colon-annotation TOKEN TYPE, not 'symbol"
  (define toks (token-types-from-rrb (tokenize-char-rrb (make-char-rrb-from-string "users:0"))))
  (check-equal? (cdr (list-ref toks 1)) ":0" "fixture sanity: the lexeme is the one we mean")
  (check-equal? (car (list-ref toks 1)) 'colon-annotation
                "the ordinal band must be type-dispatchable at grouping (Q_U16b)"))

(test-case "P4c-1: the `:w`/`:m` letter arm carries it too"
  (for ([s '("users:w" "users:m")] [lex '(":w" ":m")])
    (define toks (token-types-from-rrb (tokenize-char-rrb (make-char-rrb-from-string s))))
    (check-equal? (cdr (list-ref toks 1)) lex)
    (check-equal? (car (list-ref toks 1)) 'colon-annotation s)))

(test-case "P4c-1: the promotion does NOT disturb the `keyword` band"
  ;; `:name` already carries its own type. Note `x:Int` and `users:userName` are
  ;; BOTH 'keyword — type-identical — which is precisely why Q_U16's position
  ;; dispatch is needed and why no token-type test can separate binder from
  ;; expression in this band.
  (for ([s '("users:userName" "x:Int")] [lex '(":userName" ":Int")])
    (define toks (token-types-from-rrb (tokenize-char-rrb (make-char-rrb-from-string s))))
    (check-equal? (car (list-ref toks 1)) 'keyword s)
    (check-equal? (cdr (list-ref toks 1)) lex)))
