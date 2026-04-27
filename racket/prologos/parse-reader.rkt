#lang racket/base

;;;
;;; PPN Track 1: Propagator-Based Reader
;;;
;;; The parse tree is the fixpoint of 5 lattice domains:
;;; 1. Character RRB (embedded cell) — raw input
;;; 2. Token RRB (embedded cell) — token classifications (set-narrowing)
;;; 3. Indent RRB (embedded cell) — per-content-line indent levels
;;; 4. Bracket-depth RRB (embedded cell) — bracket + qq nesting
;;; 5. Tree cell (parse-cell-value) — parse tree M-type
;;;
;;; Each domain is an embedded lattice (Pocket Universe principle):
;;; a single propagator-network cell holding an RRB persistent vector.
;;;
;;; See: docs/tracking/2026-03-26_PPN_TRACK1_DESIGN.md (D.9)
;;;

(require racket/string
         racket/list
         racket/set
         racket/file
         racket/port
         "rrb.rkt"
         "propagator.rkt"
         "parse-lattice.rkt"
)

(provide
 ;; Phase 1a: Character + indent domains
 make-char-rrb-from-string
 make-indent-rrb-from-char-rrb
 content-line?
 measure-indent

 ;; Phase 1b: Tokenizer
 (struct-out token-entry)
 tokenize-char-rrb
 register-token-pattern!
 register-default-token-patterns!

 ;; Cell constructors for propagator network
 create-parse-cells
 parse-cells-char-cell-id
 parse-cells-indent-cell-id
 parse-cells-token-cell-id
 parse-cells-bracket-cell-id
 parse-cells-tree-cell-id

 ;; Embedded lattice merge functions
 rrb-embedded-merge

 ;; Phase 3a: Read API
 (struct-out parse-tree)
 read-to-tree
 read-file-to-tree
 tree-top-level-forms
 tree-children
 tree-parent

 ;; Phase 3b: Write API
 tree-replace-children
 tree-insert-child
 tree-remove-child
 tree-splice

 ;; Phase 3c: Compatibility wrappers
 (struct-out compat-token)
 compat-tokenize-string
 token-entry->compat
 pos->line-col

 ;; Phase 5a: Datum extraction
 flatten-with-boundaries
 read-all-forms-from-tree
 compat-read-all-forms-string
 compat-read-syntax-all
 token-entry->stx
 tree-node->stx-form
 tree-node->stx-elements

 ;; PPN Track 2 Phase 8a: backward-compatible aliases for reader.rkt migration
 ;; These allow test files to import from parse-reader.rkt using the same
 ;; function names they used from reader.rkt.
 (rename-out [compat-tokenize-string tokenize-string]
             [compat-read-all-forms-string read-all-forms-string]
             [compat-read-syntax-all prologos-read-syntax-all])
 ;; Token accessor compatibility (old reader used token struct with type/value fields)
 (rename-out [compat-token-type token-type]
             [compat-token-value token-value])
 ;; Sexp reader re-export (from reader.rkt — until sexp reader extracted)
 prologos-read
 prologos-read-syntax
 )


;; ============================================================
;; Phase 1a: Character Domain (RRB embedded cell)
;; ============================================================

;; Build an RRB persistent vector from a source string.
;; Each entry: one character at its position.
;; This IS the character lattice — set-once per position.
(define (make-char-rrb-from-string str)
  (define chars (string->list str))
  (rrb-from-list chars))


;; ============================================================
;; Phase 1a: Indent Domain (RRB embedded cell)
;; ============================================================

;; Determine if a source line is a CONTENT line (not blank, not comment-only).
;; Blank and comment-only lines are invisible to the tree topology.
(define (content-line? line-str)
  (define trimmed (string-trim line-str))
  (and (> (string-length trimmed) 0)
       (not (string-prefix? trimmed ";"))))

;; Measure the indent level of a line (count leading spaces).
(define (measure-indent line-str)
  (let loop ([i 0])
    (if (and (< i (string-length line-str))
             (char=? (string-ref line-str i) #\space))
        (loop (+ i 1))
        i)))

;; Build the indent RRB from the character RRB.
;; One entry per CONTENT LINE: its indent level.
;; Returns: (values indent-rrb content-line-source-indices)
;;   indent-rrb: RRB of indent levels (one per content line)
;;   content-line-source-indices: RRB mapping content-line-idx → source-line-number
(define (make-indent-rrb-from-char-rrb char-rrb)
  ;; Reconstruct lines from character RRB
  (define n (rrb-size char-rrb))
  (define lines '())
  (define current-line '())
  (define line-starts '())  ;; list of source-line-number for each content line
  (define source-line 0)
  (define line-start-pos 0)

  (for ([i (in-range n)])
    (define c (rrb-get char-rrb i))
    (cond
      [(char=? c #\newline)
       (define line-str (list->string (reverse current-line)))
       (when (content-line? line-str)
         (set! lines (cons (measure-indent line-str) lines))
         (set! line-starts (cons source-line line-starts)))
       (set! current-line '())
       (set! source-line (+ source-line 1))
       (set! line-start-pos (+ i 1))]
      [else
       (set! current-line (cons c current-line))]))

  ;; Handle last line (may not end with newline)
  (when (pair? current-line)
    (define line-str (list->string (reverse current-line)))
    (when (content-line? line-str)
      (set! lines (cons (measure-indent line-str) lines))
      (set! line-starts (cons source-line line-starts))))

  (values (rrb-from-list (reverse lines))
          (rrb-from-list (reverse line-starts))))


;; ============================================================
;; Phase 1b: Token Domain (RRB embedded cell)
;; ============================================================
;;
;; One tokenizer propagator reads the character RRB and writes
;; the token RRB. Registered token patterns with priority.
;;
;; Token cells hold a SET of possible types (D.9 set-narrowing):
;; ambiguous tokens start with multiple types, disambiguation
;; narrows by intersection. For 99% of tokens: set has 1 element.

;; A token entry in the token RRB
(struct token-entry
  (types       ;; seteq of symbol: possible classifications
   lexeme      ;; string: the raw character sequence
   start-pos   ;; exact-nonneg-integer: start position in source
   end-pos     ;; exact-nonneg-integer: end position in source
   )
  #:transparent)

;; A registered token pattern
(struct token-pattern
  (name        ;; symbol: pattern identifier
   recognizer  ;; (string pos) → match-length | #f
   classifier  ;; (string pos len) → symbol (token type)
   priority    ;; int: higher priority wins
   )
  #:transparent)

;; Pattern registry
(define token-pattern-registry (make-hash))

(define (register-token-pattern! pattern)
  (hash-set! token-pattern-registry
             (token-pattern-name pattern)
             pattern))

;; ---- Character classification helpers ----

(define (ident-start? c)
  (and (char? c)
       (or (char-alphabetic? c)
           (char=? c #\_)
           (char=? c #\-)
           (char=? c #\+)
           (char=? c #\*)
           (char=? c #\/)
           (char=? c #\=)
           (char=? c #\$)
           (char=? c #\?)
           (char=? c #\!))))

(define (ident-continue? c)
  (and (char? c)
       (or (char-alphabetic? c)
           (char-numeric? c)
           (char=? c #\_)
           (char=? c #\-)
           (char=? c #\?)
           (char=? c #\!)
           (char=? c #\*)
           (char=? c #\+)
           (char=? c #\')
           (char=? c #\/)
           (char=? c #\=)
           (char=? c #\$)
           (char=? c #\^))))

;; ---- Pattern recognizers ----

;; Read characters from RRB starting at pos
(define (rrb-char-at rrb pos)
  (if (< pos (rrb-size rrb)) (rrb-get rrb pos) #f))

(define (recognize-symbol rrb pos)
  ;; Symbol: ident-start followed by ident-continue* and optional ::ident segments
  (define c (rrb-char-at rrb pos))
  (if (and c (ident-start? c))
      (let loop ([i (+ pos 1)])
        (define nc (rrb-char-at rrb i))
        (cond
          [(and nc (ident-continue? nc))
           (loop (+ i 1))]
          ;; :: followed by ident-start → module path continuation
          [(and nc (char=? nc #\:)
                (let ([nc2 (rrb-char-at rrb (+ i 1))])
                  (and nc2 (char=? nc2 #\:)
                       (let ([nc3 (rrb-char-at rrb (+ i 2))])
                         (and nc3 (ident-start? nc3))))))
           (loop (+ i 3))]  ;; skip :: and first char of next segment
          [else (- i pos)]))
      #f))

(define (recognize-number rrb pos)
  ;; Number: digit+, optionally followed by N (nat) or /digit+ (rat)
  ;; Does NOT match digit+.digit+ — that's decimal-literal (higher priority)
  (define c (rrb-char-at rrb pos))
  (if (and c (char-numeric? c))
      (let loop ([i (+ pos 1)])
        (define nc (rrb-char-at rrb i))
        (cond
          [(and nc (char-numeric? nc)) (loop (+ i 1))]
          [(and nc (char=? nc #\N)) (+ (- i pos) 1)]  ;; Nat literal
          [(and nc (char=? nc #\/)
                (let ([nc2 (rrb-char-at rrb (+ i 1))])
                  (and nc2 (char-numeric? nc2))))
           ;; Rational: digit+/digit+
           (let loop2 ([j (+ i 2)])
             (define nc2 (rrb-char-at rrb j))
             (if (and nc2 (char-numeric? nc2))
                 (loop2 (+ j 1))
                 (- j pos)))]
          [else (- i pos)]))
      #f))

(define (recognize-decimal-literal rrb pos)
  ;; Decimal literal: digit+.digit+ (bare, no tilde prefix)
  ;; Must have digits on BOTH sides of the dot
  (define c (rrb-char-at rrb pos))
  (if (and c (char-numeric? c))
      (let loop ([i (+ pos 1)])
        (define nc (rrb-char-at rrb i))
        (cond
          [(and nc (char-numeric? nc)) (loop (+ i 1))]
          [(and nc (char=? nc #\.))
           ;; Check for digit after dot
           (let ([after-dot (rrb-char-at rrb (+ i 1))])
             (if (and after-dot (char-numeric? after-dot))
                 ;; Consume remaining digits after dot
                 (let loop2 ([j (+ i 2)])
                   (define nc2 (rrb-char-at rrb j))
                   (if (and nc2 (char-numeric? nc2))
                       (loop2 (+ j 1))
                       (- j pos)))
                 #f))]  ;; dot not followed by digit — not a decimal
          [else #f]))  ;; no dot found — not a decimal
      #f))

(define (recognize-string rrb pos)
  ;; String: " ... " with escape handling
  (define c (rrb-char-at rrb pos))
  (if (and c (char=? c #\"))
      (let loop ([i (+ pos 1)] [escaped? #f])
        (define nc (rrb-char-at rrb i))
        (cond
          [(not nc) #f]  ;; unterminated string
          [escaped? (loop (+ i 1) #f)]
          [(char=? nc #\\) (loop (+ i 1) #t)]
          [(char=? nc #\") (+ (- i pos) 1)]
          [else (loop (+ i 1) #f)]))
      #f))

(define (recognize-char-literal rrb pos)
  ;; Char: 'X' (single character between single quotes)
  (define c (rrb-char-at rrb pos))
  (if (and c (char=? c #\')
           (rrb-char-at rrb (+ pos 1))
           (let ([c3 (rrb-char-at rrb (+ pos 2))])
             (and c3 (char=? c3 #\'))))
      3
      #f))

(define (recognize-colon-assign rrb pos)
  ;; := (2 chars, higher priority than bare :)
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 c2 (char=? c1 #\:) (char=? c2 #\=))
      2
      #f))

(define (recognize-double-colon rrb pos)
  ;; :: (module path separator, higher priority than bare :)
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 c2 (char=? c1 #\:) (char=? c2 #\:))
      2
      #f))

(define (recognize-colon rrb pos)
  ;; : (single colon)
  (define c (rrb-char-at rrb pos))
  (if (and c (char=? c #\:)) 1 #f))

(define (recognize-keyword rrb pos)
  ;; :identifier (colon followed by identifier chars)
  (define c (rrb-char-at rrb pos))
  (if (and c (char=? c #\:)
           (let ([c2 (rrb-char-at rrb (+ pos 1))])
             (and c2 (char-alphabetic? c2))))
      (let loop ([i (+ pos 2)])
        (define nc (rrb-char-at rrb i))
        (if (and nc (or (char-alphabetic? nc) (char-numeric? nc)
                        (char=? nc #\-) (char=? nc #\_)))
            (loop (+ i 1))
            (- i pos)))
      #f))

(define (recognize-single-char rrb pos expected type)
  (define c (rrb-char-at rrb pos))
  (if (and c (char=? c expected)) 1 #f))

(define (recognize-quote-lbracket rrb pos)
  ;; '[ (quote list literal)
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 c2 (char=? c1 #\') (char=? c2 #\[))
      2
      #f))

(define (recognize-quote rrb pos)
  ;; 'expr (quote, but NOT '[)
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 (char=? c1 #\')
           (not (and c2 (char=? c2 #\[))))
      1
      #f))

(define (recognize-at-lbracket rrb pos)
  ;; @[ (PVec literal)
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 c2 (char=? c1 #\@) (char=? c2 #\[))
      2
      #f))

(define (recognize-tilde-lbracket rrb pos)
  ;; ~[ (LSeq literal)
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 c2 (char=? c1 #\~) (char=? c2 #\[))
      2
      #f))

(define (recognize-tilde-number rrb pos)
  ;; ~42 or ~3/7 or ~3.14 (approx-literal)
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 c2 (char=? c1 #\~)
           (or (char-numeric? c2)
               (and (char=? c2 #\-) ;; negative: ~-5
                    (let ([c3 (rrb-char-at rrb (+ pos 2))])
                      (and c3 (char-numeric? c3))))))
      ;; Scan forward for the full number (including trailing N for Nat)
      (let loop ([i (+ pos 1)])
        (define c (rrb-char-at rrb i))
        (if (and c (or (char-numeric? c) (char=? c #\.) (char=? c #\/)
                       (char=? c #\-) (char=? c #\e) (char=? c #\E)
                       (char=? c #\N)))
            (loop (+ i 1))
            (- i pos)))
      #f))

(define (recognize-hash-lbrace rrb pos)
  ;; #{ (Set literal)
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 c2 (char=? c1 #\#) (char=? c2 #\{))
      2
      #f))

(define (recognize-hash-eq rrb pos)
  ;; #= (narrowing operator)
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 c2 (char=? c1 #\#) (char=? c2 #\=))
      2
      #f))

(define (recognize-hash-path rrb pos)
  ;; #p( (path literal) — recognize the prefix only, content is opaque to tokenizer
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (define c3 (rrb-char-at rrb (+ pos 2)))
  (if (and c1 c2 c3 (char=? c1 #\#) (char=? c2 #\p) (char=? c3 #\())
      ;; Read until matching )
      (let loop ([i (+ pos 3)] [depth 1])
        (define c (rrb-char-at rrb i))
        (cond
          [(not c) #f]  ;; unterminated
          [(char=? c #\() (loop (+ i 1) (+ depth 1))]
          [(char=? c #\))
           (if (= depth 1) (- (+ i 1) pos) (loop (+ i 1) (- depth 1)))]
          [else (loop (+ i 1) depth)]))
      #f))

(define (recognize-nil-dot-key rrb pos)
  ;; #.:keyword OR #:keyword
  (define c1 (rrb-char-at rrb pos))
  (if (and c1 (char=? c1 #\#))
      (let ([c2 (rrb-char-at rrb (+ pos 1))])
        (cond
          ;; #.:keyword
          [(and c2 (char=? c2 #\.))
           (let ([c3 (rrb-char-at rrb (+ pos 2))])
             (and c3 (char=? c3 #\:)
                  (let ([c4 (rrb-char-at rrb (+ pos 3))])
                    (and c4 (ident-start? c4)
                         (let loop ([i (+ pos 4)])
                           (define cn (rrb-char-at rrb i))
                           (if (and cn (ident-continue? cn))
                               (loop (+ i 1))
                               (- i pos)))))))]
          ;; #:keyword
          [(and c2 (char=? c2 #\:))
           (let ([c3 (rrb-char-at rrb (+ pos 2))])
             (and c3 (ident-start? c3)
                  (let loop ([i (+ pos 3)])
                    (define cn (rrb-char-at rrb i))
                    (if (and cn (ident-continue? cn))
                        (loop (+ i 1))
                        (- i pos)))))]
          [else #f]))
      #f))

(define (recognize-nil-dot-access rrb pos)
  ;; #.ident (NOT #.:keyword — that's nil-dot-key)
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (define c3 (rrb-char-at rrb (+ pos 2)))
  (if (and c1 c2 c3
           (char=? c1 #\#) (char=? c2 #\.)
           (not (char=? c3 #\:))  ;; not #.:
           (ident-start? c3))
      (let loop ([i (+ pos 3)])
        (define cn (rrb-char-at rrb i))
        (if (and cn (ident-continue? cn))
            (loop (+ i 1))
            (- i pos)))
      #f))

(define (recognize-backslash-char rrb pos)
  ;; \a, \newline, \space, \tab, \uNNNN — WS-mode char literals
  (define c1 (rrb-char-at rrb pos))
  (if (and c1 (char=? c1 #\\))
      (let ([c2 (rrb-char-at rrb (+ pos 1))])
        (cond
          [(not c2) #f]
          ;; \uNNNN — unicode
          [(char=? c2 #\u)
           (let loop ([i (+ pos 2)] [count 0])
             (define cn (rrb-char-at rrb i))
             (if (and cn (or (char-numeric? cn)
                             (memq cn '(#\a #\b #\c #\d #\e #\f
                                        #\A #\B #\C #\D #\E #\F)))
                       (< count 4))
                 (loop (+ i 1) (+ count 1))
                 (if (> count 0) (- i pos) #f)))]
          ;; \charname — multi-char name like \newline, \space, \tab
          [(char-alphabetic? c2)
           (let loop ([i (+ pos 2)])
             (define cn (rrb-char-at rrb i))
             (if (and cn (char-alphabetic? cn))
                 (loop (+ i 1))
                 (- i pos)))]
          [else #f]))
      #f))

(define (recognize-backtick rrb pos)
  ;; ` (quasiquote)
  (define c (rrb-char-at rrb pos))
  (if (and c (char=? c #\`)) 1 #f))

(define (recognize-comma rrb pos)
  ;; , (unquote)
  (define c (rrb-char-at rrb pos))
  (if (and c (char=? c #\,)) 1 #f))

(define (recognize-rest-param rrb pos)
  ;; ...ident — rest parameter (three dots + identifier)
  ;; ... — standalone rest marker ($rest)
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (define c3 (rrb-char-at rrb (+ pos 2)))
  (if (and c1 c2 c3
           (char=? c1 #\.) (char=? c2 #\.) (char=? c3 #\.))
      (let ([c4 (rrb-char-at rrb (+ pos 3))])
        (if (and c4 (ident-start? c4))
            ;; ...name — rest parameter
            (let loop ([i (+ pos 4)])
              (define cn (rrb-char-at rrb i))
              (if (and cn (ident-continue? cn))
                  (loop (+ i 1))
                  (- i pos)))
            ;; standalone ... — 3 chars
            3))
      #f))

(define (recognize-dot-access rrb pos)
  ;; .ident (NOT .:keyword, NOT .{, NOT .*, NOT number continuation)
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 c2 (char=? c1 #\.)
           (not (char=? c2 #\:))  ;; not .:
           (not (char=? c2 #\{))  ;; not .{
           (not (char=? c2 #\*))  ;; not .*
           (not (char-numeric? c2))  ;; not decimal continuation
           (ident-start? c2))
      (let loop ([i (+ pos 2)])
        (define cn (rrb-char-at rrb i))
        (if (and cn (ident-continue? cn))
            (loop (+ i 1))
            (- i pos)))
      #f))

(define (recognize-dot-key rrb pos)
  ;; .:keyword
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (define c3 (rrb-char-at rrb (+ pos 2)))
  (if (and c1 c2 c3 (char=? c1 #\.) (char=? c2 #\:) (ident-start? c3))
      (let loop ([i (+ pos 3)])
        (define cn (rrb-char-at rrb i))
        (if (and cn (ident-continue? cn))
            (loop (+ i 1))
            (- i pos)))
      #f))

(define (recognize-dot-lbrace rrb pos)
  ;; .{
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 c2 (char=? c1 #\.) (char=? c2 #\{))
      2
      #f))

(define (recognize-broadcast-access rrb pos)
  ;; .*ident
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (define c3 (rrb-char-at rrb (+ pos 2)))
  (if (and c1 c2 c3 (char=? c1 #\.) (char=? c2 #\*) (ident-continue? c3))
      (let loop ([i (+ pos 3)])
        (define cn (rrb-char-at rrb i))
        (if (and cn (ident-continue? cn))
            (loop (+ i 1))
            (- i pos)))
      #f))

(define (recognize-pipe-right rrb pos)
  ;; |>
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 c2 (char=? c1 #\|) (char=? c2 #\>))
      2
      #f))

(define (recognize-facts-sep rrb pos)
  ;; || (double pipe — fact separator in defr)
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 c2 (char=? c1 #\|) (char=? c2 #\|))
      2
      #f))

(define (recognize-pipe rrb pos)
  ;; | (standalone, NOT |> or ||)
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 (char=? c1 #\|)
           (not (and c2 (or (char=? c2 #\>) (char=? c2 #\|)))))
      1
      #f))

(define (recognize-double-arrow rrb pos)
  ;; ->> (session double arrow)
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (define c3 (rrb-char-at rrb (+ pos 2)))
  (if (and c1 c2 c3 (char=? c1 #\-) (char=? c2 #\>) (char=? c3 #\>))
      3
      #f))

(define (recognize-arrow rrb pos)
  ;; ->
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 c2 (char=? c1 #\-) (char=? c2 #\>))
      2
      #f))

(define (recognize-lte rrb pos)
  ;; <= (less-than-or-equal)
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 c2 (char=? c1 #\<) (char=? c2 #\=))
      2
      #f))

(define (recognize-gte rrb pos)
  ;; >= (greater-than-or-equal)
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 c2 (char=? c1 #\>) (char=? c2 #\=))
      2
      #f))

(define (recognize-compose rrb pos)
  ;; >> (compose operator)
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 c2 (char=? c1 #\>) (char=? c2 #\>))
      2
      #f))

;; ---- Phase 5b tokenizer gaps ----

(define (recognize-colon-annotation rrb pos)
  ;; :0, :1, :w, :m — colon immediately followed by digit or w/m
  ;; ONLY when NOT followed by ident-continue (else it's a keyword like :where, :write)
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (define c3 (rrb-char-at rrb (+ pos 2)))
  (if (and c1 c2 (char=? c1 #\:)
           (or (char-numeric? c2)
               (char=? c2 #\w)
               (char=? c2 #\m))
           ;; Must NOT be followed by ident-continue
           (not (and c3 (ident-continue? c3))))
      2
      #f))

(define (recognize-session-arrow rrb pos)
  ;; -0>, -1>, -w> — session type linear arrows
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (define c3 (rrb-char-at rrb (+ pos 2)))
  (if (and c1 c2 c3 (char=? c1 #\-)
           (or (char-numeric? c2) (char=? c2 #\w))
           (char=? c3 #\>))
      3
      #f))

(define (recognize-choice-arrow rrb pos)
  ;; +> — session type choice
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 c2 (char=? c1 #\+) (char=? c2 #\>))
      2
      #f))

(define (recognize-typed-hole rrb pos)
  ;; ?? — unnamed typed hole; ??name — named typed hole
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (define c3 (rrb-char-at rrb (+ pos 2)))
  (if (and c1 c2 (char=? c1 #\?) (char=? c2 #\?))
      (cond
        ;; ??? — not a typed hole (triple question mark)
        [(and c3 (char=? c3 #\?)) #f]
        ;; ??name — named typed hole
        [(and c3 (ident-start? c3))
         (let loop ([i (+ pos 3)])
           (define cn (rrb-char-at rrb i))
           (if (and cn (ident-continue? cn))
               (loop (+ i 1))
               (- i pos)))]
        ;; ?? alone — unnamed typed hole
        [else 2])
      #f))

(define (recognize-async-send rrb pos)
  ;; !! — async send
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (define c3 (rrb-char-at rrb (+ pos 2)))
  (if (and c1 c2 (char=? c1 #\!) (char=? c2 #\!)
           (not (and c3 (or (char=? c3 #\!) (ident-continue? c3)))))
      2
      #f))

(define (recognize-dep-send rrb pos)
  ;; !: — dependent session send
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 c2 (char=? c1 #\!) (char=? c2 #\:))
      2
      #f))

(define (recognize-dep-recv rrb pos)
  ;; ?: — dependent session receive
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 c2 (char=? c1 #\?) (char=? c2 #\:))
      2
      #f))

(define (recognize-clause-sep rrb pos)
  ;; &> — session offer/clause separator
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 c2 (char=? c1 #\&) (char=? c2 #\>))
      2
      #f))

(define (recognize-session-op rrb pos)
  ;; ? or ! — session send/receive (standalone, not !:/?:/??/!!)
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 (or (char=? c1 #\?) (char=? c1 #\!))
           (not (and c2 (char=? c2 #\:)))  ;; not !: or ?:
           (not (and c2 (char=? c2 c1)))   ;; not ?? or !!
           (not (and c2 (ident-continue? c2))))  ;; not part of identifier
      1
      #f))

(define (recognize-negative-number rrb pos)
  ;; -digit+ — negative number literal (only at start or after space/bracket)
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 c2 (char=? c1 #\-) (char-numeric? c2)
           ;; Check not preceded by ident-continue (would be part of identifier like x-1)
           (or (= pos 0)
               (let ([prev (rrb-char-at rrb (- pos 1))])
                 (and prev (or (char=? prev #\space) (char=? prev #\newline)
                               (char=? prev #\tab) (char=? prev #\()
                               (char=? prev #\[) (char=? prev #\{)
                               (char=? prev #\<))))))
      ;; Read the number part
      (let loop ([i (+ pos 2)])
        (define nc (rrb-char-at rrb i))
        (cond
          [(and nc (char-numeric? nc)) (loop (+ i 1))]
          [(and nc (char=? nc #\N)) (+ (- i pos) 1)]  ;; -42N
          [(and nc (char=? nc #\/)  ;; rational -3/7
                (let ([nc2 (rrb-char-at rrb (+ i 1))])
                  (and nc2 (char-numeric? nc2))))
           (let loop2 ([j (+ i 2)])
             (define nc2 (rrb-char-at rrb j))
             (if (and nc2 (char-numeric? nc2))
                 (loop2 (+ j 1))
                 (- j pos)))]
          [(and nc (char=? nc #\.)  ;; decimal -3.14
                (let ([nc2 (rrb-char-at rrb (+ i 1))])
                  (and nc2 (char-numeric? nc2))))
           (let loop2 ([j (+ i 2)])
             (define nc2 (rrb-char-at rrb j))
             (if (and nc2 (char-numeric? nc2))
                 (loop2 (+ j 1))
                 (- j pos)))]
          [else (- i pos)]))
      #f))

;; ---- Register default patterns ----

(define (register-default-token-patterns!)
  ;; Highest priority first (tried in priority order, highest wins)
  ;; Compound patterns need higher priority than prefix patterns.
  (register-token-pattern!
   (token-pattern 'colon-assign (lambda (rrb pos) (recognize-colon-assign rrb pos))
                  (lambda (s p l) 'symbol) 100))
  (register-token-pattern!
   (token-pattern 'double-colon (lambda (rrb pos) (recognize-double-colon rrb pos))
                  (lambda (s p l) 'symbol) 99))
  (register-token-pattern!
   (token-pattern 'session-arrow (lambda (rrb pos) (recognize-session-arrow rrb pos))
                  (lambda (s p l) 'symbol) 99))  ;; -0>, -1> before arrow ->
  (register-token-pattern!
   (token-pattern 'choice-arrow (lambda (rrb pos) (recognize-choice-arrow rrb pos))
                  (lambda (s p l) 'symbol) 99))  ;; +> before symbol +
  (register-token-pattern!
   (token-pattern 'double-arrow (lambda (rrb pos) (recognize-double-arrow rrb pos))
                  (lambda (s p l) 'symbol) 99))  ;; ->> before ->
  (register-token-pattern!
   (token-pattern 'arrow (lambda (rrb pos) (recognize-arrow rrb pos))
                  (lambda (s p l) 'symbol) 98))
  (register-token-pattern!
   (token-pattern 'colon-annotation (lambda (rrb pos) (recognize-colon-annotation rrb pos))
                  (lambda (s p l) 'symbol) 97))  ;; :0, :w before bare colon
  (register-token-pattern!
   (token-pattern 'typed-hole (lambda (rrb pos) (recognize-typed-hole rrb pos))
                  (lambda (s p l) 'typed-hole) 98))  ;; ?? before ?:/?
  (register-token-pattern!
   (token-pattern 'async-send (lambda (rrb pos) (recognize-async-send rrb pos))
                  (lambda (s p l) 'symbol) 98))  ;; !! before !:
  (register-token-pattern!
   (token-pattern 'dep-send (lambda (rrb pos) (recognize-dep-send rrb pos))
                  (lambda (s p l) 'symbol) 97))  ;; !: before standalone !
  (register-token-pattern!
   (token-pattern 'dep-recv (lambda (rrb pos) (recognize-dep-recv rrb pos))
                  (lambda (s p l) 'symbol) 97))  ;; ?: before standalone ?
  (register-token-pattern!
   (token-pattern 'clause-sep (lambda (rrb pos) (recognize-clause-sep rrb pos))
                  (lambda (s p l) 'symbol) 97))  ;; &>
  (register-token-pattern!
   (token-pattern 'session-op (lambda (rrb pos) (recognize-session-op rrb pos))
                  (lambda (s p l) 'symbol) 96))  ;; ?, ! standalone
  (register-token-pattern!
   (token-pattern 'negative-number (lambda (rrb pos) (recognize-negative-number rrb pos))
                  (lambda (rrb pos len)
                    (define last-c (rrb-char-at rrb (+ pos len -1)))
                    (define lexeme-str
                      (list->string
                       (for/list ([i (in-range pos (+ pos len))])
                         (rrb-char-at rrb i))))
                    (cond
                      [(and last-c (char=? last-c #\N)) 'nat-literal]
                      [(string-contains? lexeme-str ".") 'decimal-literal]
                      [else 'number]))
                  96))  ;; -42 before symbol -
  (register-token-pattern!
   (token-pattern 'keyword (lambda (rrb pos) (recognize-keyword rrb pos))
                  (lambda (s p l) 'keyword) 95))
  ;; Hash-prefix compound tokens (must precede simpler # patterns)
  (register-token-pattern!
   (token-pattern 'hash-path (lambda (rrb pos) (recognize-hash-path rrb pos))
                  (lambda (s p l) 'path-literal) 93))
  (register-token-pattern!
   (token-pattern 'nil-dot-key (lambda (rrb pos) (recognize-nil-dot-key rrb pos))
                  (lambda (s p l) 'nil-dot-key) 92))
  (register-token-pattern!
   (token-pattern 'nil-dot-access (lambda (rrb pos) (recognize-nil-dot-access rrb pos))
                  (lambda (s p l) 'nil-dot-access) 92))
  (register-token-pattern!
   (token-pattern 'hash-lbrace (lambda (rrb pos) (recognize-hash-lbrace rrb pos))
                  (lambda (s p l) 'hash-lbrace) 91))
  (register-token-pattern!
   (token-pattern 'hash-eq (lambda (rrb pos) (recognize-hash-eq rrb pos))
                  (lambda (s p l) 'symbol) 91))
  ;; Quote patterns: quote-lbracket > char-lit > bare quote
  (register-token-pattern!
   (token-pattern 'quote-lbracket (lambda (rrb pos) (recognize-quote-lbracket rrb pos))
                  (lambda (s p l) 'quote-lbracket) 91))
  ;; Rest parameter ...ident (must precede dot-access)
  (register-token-pattern!
   (token-pattern 'rest-param (lambda (rrb pos) (recognize-rest-param rrb pos))
                  (lambda (s p l) 'rest-param) 89))
  ;; Dot-prefix compound tokens (must precede symbol/single-char)
  (register-token-pattern!
   (token-pattern 'dot-key (lambda (rrb pos) (recognize-dot-key rrb pos))
                  (lambda (s p l) 'dot-key) 88))
  (register-token-pattern!
   (token-pattern 'dot-lbrace (lambda (rrb pos) (recognize-dot-lbrace rrb pos))
                  (lambda (s p l) 'dot-lbrace) 87))
  (register-token-pattern!
   (token-pattern 'broadcast-access (lambda (rrb pos) (recognize-broadcast-access rrb pos))
                  (lambda (s p l) 'broadcast-access) 87))
  (register-token-pattern!
   (token-pattern 'dot-access (lambda (rrb pos) (recognize-dot-access rrb pos))
                  (lambda (s p l) 'dot-access) 86))
  ;; Collection literal prefixes
  (register-token-pattern!
   (token-pattern 'at-lbracket (lambda (rrb pos) (recognize-at-lbracket rrb pos))
                  (lambda (s p l) 'at-lbracket) 85))
  (register-token-pattern!
   (token-pattern 'tilde-lbracket (lambda (rrb pos) (recognize-tilde-lbracket rrb pos))
                  (lambda (s p l) 'tilde-lbracket) 85))
  (register-token-pattern!
   (token-pattern 'tilde-number (lambda (rrb pos) (recognize-tilde-number rrb pos))
                  (lambda (s p l) 'approx-literal) 86))  ;; higher priority than tilde-lbracket
  ;; Backtick and comma (quasiquote/unquote)
  (register-token-pattern!
   (token-pattern 'backtick (lambda (rrb pos) (recognize-backtick rrb pos))
                  (lambda (s p l) 'backtick) 85))
  (register-token-pattern!
   (token-pattern 'comma (lambda (rrb pos) (recognize-comma rrb pos))
                  (lambda (s p l) 'comma) 85))
  ;; Pipe operators (|> and || must precede |)
  (register-token-pattern!
   (token-pattern 'pipe-right (lambda (rrb pos) (recognize-pipe-right rrb pos))
                  (lambda (s p l) 'symbol) 84))
  (register-token-pattern!
   (token-pattern 'facts-sep (lambda (rrb pos) (recognize-facts-sep rrb pos))
                  (lambda (s p l) 'symbol) 84))
  (register-token-pattern!
   (token-pattern 'pipe (lambda (rrb pos) (recognize-pipe rrb pos))
                  (lambda (s p l) 'pipe) 83))
  ;; Backslash char literal (\a, \newline, \space, \tab, \uNNNN)
  (register-token-pattern!
   (token-pattern 'backslash-char (lambda (rrb pos) (recognize-backslash-char rrb pos))
                  (lambda (s p l) 'char) 91))
  ;; Char literal 'X' (must precede bare quote — both start with ')
  (register-token-pattern!
   (token-pattern 'char-lit (lambda (rrb pos) (recognize-char-literal rrb pos))
                  (lambda (s p l) 'char) 90))
  ;; Bare quote (lowest of the '-prefix patterns)
  (register-token-pattern!
   (token-pattern 'quote (lambda (rrb pos) (recognize-quote rrb pos))
                  (lambda (s p l) 'quote) 89))
  ;; Strings
  (register-token-pattern!
   (token-pattern 'string (lambda (rrb pos) (recognize-string rrb pos))
                  (lambda (s p l) 'string) 80))
  ;; Decimal literals (3.14, 0.5) — higher priority than plain number
  (register-token-pattern!
   (token-pattern 'decimal-literal (lambda (rrb pos) (recognize-decimal-literal rrb pos))
                  (lambda (s p l) 'decimal-literal) 75))
  ;; Numbers
  (register-token-pattern!
   (token-pattern 'number (lambda (rrb pos) (recognize-number rrb pos))
                  (lambda (rrb pos len)
                    (define last-c (rrb-char-at rrb (+ pos len -1)))
                    (if (and last-c (char=? last-c #\N))
                        'nat-literal
                        'number))
                  70))
  ;; Identifiers
  (register-token-pattern!
   (token-pattern 'symbol (lambda (rrb pos) (recognize-symbol rrb pos))
                  (lambda (s p l) 'symbol) 50))
  ;; Colon
  (register-token-pattern!
   (token-pattern 'colon (lambda (rrb pos) (recognize-colon rrb pos))
                  (lambda (s p l) 'colon) 40))
  ;; Brackets
  (register-token-pattern!
   (token-pattern 'lbracket (lambda (rrb pos) (recognize-single-char rrb pos #\[ 'lbracket))
                  (lambda (s p l) 'lbracket) 30))
  (register-token-pattern!
   (token-pattern 'rbracket (lambda (rrb pos) (recognize-single-char rrb pos #\] 'rbracket))
                  (lambda (s p l) 'rbracket) 30))
  (register-token-pattern!
   (token-pattern 'lparen (lambda (rrb pos) (recognize-single-char rrb pos #\( 'lparen))
                  (lambda (s p l) 'lparen) 30))
  (register-token-pattern!
   (token-pattern 'rparen (lambda (rrb pos) (recognize-single-char rrb pos #\) 'rparen))
                  (lambda (s p l) 'rparen) 30))
  (register-token-pattern!
   (token-pattern 'lbrace (lambda (rrb pos) (recognize-single-char rrb pos #\{ 'lbrace))
                  (lambda (s p l) 'lbrace) 30))
  (register-token-pattern!
   (token-pattern 'rbrace (lambda (rrb pos) (recognize-single-char rrb pos #\} 'rbrace))
                  (lambda (s p l) 'rbrace) 30))
  ;; Comparison operators (must precede langle/rangle)
  (register-token-pattern!
   (token-pattern 'lte (lambda (rrb pos) (recognize-lte rrb pos))
                  (lambda (s p l) 'symbol) 26))
  (register-token-pattern!
   (token-pattern 'gte (lambda (rrb pos) (recognize-gte rrb pos))
                  (lambda (s p l) 'symbol) 26))
  ;; NOTE: >> (compose) is NOT a token pattern — it's ambiguous with >>
  ;; (two rangle closers). Handled in disambiguator: two consecutive
  ;; rangle at bracket-depth 0 → merge into $compose symbol.
  (register-token-pattern!
   (token-pattern 'langle (lambda (rrb pos) (recognize-single-char rrb pos #\< 'langle))
                  (lambda (s p l) 'langle) 25))
  (register-token-pattern!
   (token-pattern 'rangle (lambda (rrb pos) (recognize-single-char rrb pos #\> 'rangle))
                  (lambda (s p l) 'rangle) 25)))

;; ---- Tokenizer: char RRB → token RRB ----

;; Tokenize a character RRB. Returns a token RRB.
;; This is the fire function for the tokenizer propagator.
(define (tokenize-char-rrb char-rrb)
  (define n (rrb-size char-rrb))
  (define patterns
    (sort (hash-values token-pattern-registry)
          > #:key token-pattern-priority))

  (let loop ([pos 0] [token-rrb rrb-empty])
    (if (>= pos n)
        token-rrb
        (let ([c (rrb-get char-rrb pos)])
          (cond
            ;; Skip whitespace (space, tab) and newlines — not tokens
            [(and (char? c) (or (char=? c #\space) (char=? c #\tab)
                                (char=? c #\newline) (char=? c #\return)))
             (loop (+ pos 1) token-rrb)]
            ;; Skip comments (;; to end of line)
            [(and (char? c) (char=? c #\;))
             (let skip ([j (+ pos 1)])
               (define nc (rrb-char-at char-rrb j))
               (if (or (not nc) (char=? nc #\newline))
                   (loop (if nc (+ j 1) j) token-rrb)
                   (skip (+ j 1))))]
            ;; Try patterns in priority order
            [else
             (define match
               (for/or ([pat (in-list patterns)])
                 (define len ((token-pattern-recognizer pat) char-rrb pos))
                 (and len (list pat len))))
             (if match
                 (let* ([pat (car match)]
                        [len (cadr match)]
                        [type ((token-pattern-classifier pat)
                               char-rrb pos len)]
                        [lexeme (list->string
                                 (for/list ([i (in-range pos (+ pos len))])
                                   (rrb-get char-rrb i)))]
                        [entry (token-entry (seteq type) lexeme pos (+ pos len))])
                   (loop (+ pos len) (rrb-push token-rrb entry)))
                 ;; No pattern matched — emit as single-character symbol token.
                 ;; The reader preserves ALL input; the parser decides what's valid.
                 ;; Silent skipping causes datum mismatches (characters lost).
                 (let* ([lexeme (string c)]
                        [entry (token-entry (seteq 'symbol) lexeme pos (+ pos 1))])
                   (loop (+ pos 1) (rrb-push token-rrb entry))))])))))


;; ============================================================
;; Phase 1d: Bracket-depth Domain (RRB embedded cell)
;; ============================================================
;;
;; Running sum of bracket opens/closes from the token RRB.
;; Each entry: (bracket-depth . qq-depth) at that token position.
;; The tree-builder reads bracket-depth-at-line-start to determine
;; whether indent processing applies (depth 0 = yes, >0 = continuation).

;; Build bracket-depth RRB from token RRB.
;; Returns: RRB of (cons bracket-depth qq-depth) per token.
(define (make-bracket-depth-rrb token-rrb)
  (define n (rrb-size token-rrb))
  (let loop ([i 0] [bd 0] [qd 0] [result rrb-empty])
    (if (>= i n)
        result
        (let* ([entry (rrb-get token-rrb i)]
               [type (set-first (token-entry-types entry))]
               [new-bd (cond
                         [(memq type '(lbracket lparen lbrace langle
                                       quote-lbracket at-lbracket tilde-lbracket
                                       hash-lbrace dot-lbrace))
                          (+ bd 1)]
                         [(memq type '(rbracket rparen rbrace rangle))
                          (max 0 (- bd 1))]
                         [else bd])]
               ;; qq-depth: backtick increments, comma in qq context decrements
               ;; (simplified — full qq handling in Phase 2/reader macros)
               [new-qd qd])
          (loop (+ i 1) new-bd new-qd
                (rrb-push result (cons new-bd new-qd)))))))

;; Get bracket-depth at a given token index
(define (bracket-depth-at bracket-rrb token-idx)
  (if (and (> (rrb-size bracket-rrb) 0) (< token-idx (rrb-size bracket-rrb)))
      (car (rrb-get bracket-rrb token-idx))
      0))


;; ============================================================
;; Phase 1c: Tree-builder (indent + bracket → tree M-type)
;; ============================================================
;;
;; One propagator that reads indent RRB + bracket-depth RRB + token RRB
;; and produces the parse tree as an annotated S-expression wrapped
;; in a parse-cell-value.
;;
;; The tree is the M-type (initial algebra of parse tree polynomial
;; functor). Same representation as SRE type trees.

;; A parse tree node (RRB children for structural sharing)
(struct parse-tree-node
  (tag         ;; symbol: form tag (e.g., 'def-form, 'line, 'bracket-group)
   children    ;; rrb of (parse-tree-node | token-entry): ordered children
   srcloc      ;; (list source-line source-col start-pos end-pos) | #f
   indent      ;; exact-nonneg-integer: indent level of this node
   )
  #:transparent)

(provide (struct-out parse-tree-node)
         make-bracket-depth-rrb
         bracket-depth-at
         build-tree-from-domains

         ;; Phase 1e: Disambiguator
         disambiguate-tokens

         ;; Phase 1e+: Full parse pipeline (all 5 domains)
         parse-string-to-cells)

;; Build the parse tree from indent RRB + token RRB + bracket-depth RRB.
;; This is the fire function for the tree-builder propagator.
;;
;; Algorithm (expressed as fixpoint, implemented sequentially):
;; 1. Map each token to its source line (from start-pos)
;; 2. Group tokens by content line
;; 3. For each content line, determine parent from indent RRB
;;    (skip if bracket-depth-at-line-start > 0 — continuation)
;; 4. Assemble tree: each content line becomes a node, children
;;    are its tokens + any child lines
;;
;; Returns: parse-cell-value with one derivation-node holding the tree.

(define (build-tree-from-domains char-rrb indent-rrb token-rrb bracket-rrb
                                  content-line-indices)
  (define n-lines (rrb-size indent-rrb))
  (define n-tokens (rrb-size token-rrb))

  (when (= n-lines 0)
    (return-parse-bot))

  ;; Step 1: Map each token to its content-line index
  ;; (by comparing token start-pos to line boundaries in char-rrb)
  (define line-boundaries
    ;; For each content line, find its start position in the source
    (for/list ([li (in-range (rrb-size content-line-indices))])
      (define source-line (rrb-get content-line-indices li))
      ;; Find the position of this source line in the char-rrb
      ;; (count newlines to find line start)
      (find-line-start-pos char-rrb source-line)))

  ;; Step 2: Assign tokens to content lines
  (define line-tokens (make-vector n-lines '()))
  (for ([ti (in-range n-tokens)])
    (define entry (rrb-get token-rrb ti))
    (define pos (token-entry-start-pos entry))
    ;; Find which content line this token belongs to
    (define line-idx (find-content-line-for-pos pos line-boundaries n-lines))
    (when (and line-idx (< line-idx n-lines))
      (vector-set! line-tokens line-idx
                   (cons (cons ti entry) (vector-ref line-tokens line-idx)))))

  ;; Reverse token lists (they were consed in reverse order)
  (for ([i (in-range n-lines)])
    (vector-set! line-tokens i (reverse (vector-ref line-tokens i))))

  ;; Step 3: Compute parent assignments from indent RRB
  ;; (same as golden-capture's topology computation)
  (define parents (make-vector n-lines -1))
  (define stack '())
  (for ([i (in-range n-lines)])
    (define indent (rrb-get indent-rrb i))

    ;; Check bracket-depth at this line's first token
    ;; If > 0, this line is a continuation (parent = bracket opener's line)
    (define first-tok-idx
      (and (pair? (vector-ref line-tokens i))
           (car (car (vector-ref line-tokens i)))))
    (define bd-at-start
      (if (and first-tok-idx (> first-tok-idx 0))
          (bracket-depth-at bracket-rrb (- first-tok-idx 1))
          0))

    (cond
      [(> bd-at-start 0)
       ;; Inside brackets — parent is the line containing the open bracket
       ;; (for now: use the stack top as parent, same as normal indent)
       (vector-set! parents i (if (null? stack) -1 (cdr (car stack))))]
      [else
       ;; Normal indent resolution
       (set! stack
         (let loop ([s stack])
           (if (and (pair? s) (>= (car (car s)) indent))
               (loop (cdr s))
               s)))
       (vector-set! parents i (if (null? stack) -1 (cdr (car stack))))
       (set! stack (cons (cons indent i) stack))]))

  ;; Step 4: Build tree nodes (bottom-up)
  ;; Each line becomes a parse-tree-node. Children = its tokens + child lines.
  (define nodes (make-vector n-lines #f))

  ;; Build in reverse order (children before parents)
  (for ([i (in-range (- n-lines 1) -1 -1)])
    (define tok-entries
      (for/fold ([rrb rrb-empty]) ([te (in-list (vector-ref line-tokens i))])
        (rrb-push rrb (cdr te))))  ;; push token-entry values

    ;; Collect child nodes (lines whose parent is i)
    (define child-nodes
      (for/fold ([rrb rrb-empty]) ([j (in-range n-lines)])
        (if (= (vector-ref parents j) i)
            (rrb-push rrb (vector-ref nodes j))
            rrb)))

    ;; Merge: tokens first, then child nodes
    (define all-children (rrb-concat tok-entries child-nodes))

    (define indent-level (rrb-get indent-rrb i))
    (define source-line-num
      (if (< i (rrb-size content-line-indices))
          (rrb-get content-line-indices i)
          i))

    (vector-set! nodes i
                 (parse-tree-node
                  'line
                  all-children
                  (list source-line-num 0 0 0)  ;; simplified srcloc
                  indent-level)))

  ;; Step 5: Collect root nodes (parent = -1)
  (define root-children
    (for/fold ([rrb rrb-empty]) ([i (in-range n-lines)])
      (if (= (vector-ref parents i) -1)
          (rrb-push rrb (vector-ref nodes i))
          rrb)))

  (define root (parse-tree-node 'root root-children #f 0))

  ;; Wrap in parse-cell-value with one derivation
  (define item (make-parse-item 'program 1 0 n-tokens))
  (define deriv (make-derivation-node item (list root)))
  (parse-cell-value (seteq deriv)))

;; Helper: return parse-bot
(define (return-parse-bot)
  parse-bot)

;; Helper: find the character position where source line N starts
(define (find-line-start-pos char-rrb source-line)
  (if (= source-line 0)
      0
      (let loop ([pos 0] [line 0])
        (cond
          [(>= pos (rrb-size char-rrb)) pos]
          [(= line source-line) pos]
          [(char=? (rrb-get char-rrb pos) #\newline)
           (loop (+ pos 1) (+ line 1))]
          [else (loop (+ pos 1) line)]))))

;; Helper: find which content line a character position belongs to
(define (find-content-line-for-pos pos line-boundaries n-lines)
  (let loop ([i (- n-lines 1)])
    (cond
      [(< i 0) 0]
      [(<= (list-ref line-boundaries i) pos) i]
      [else (loop (- i 1))])))


;; ============================================================
;; Phase 1e: Context Disambiguator
;; ============================================================
;;
;; Reads the bracket-depth RRB and narrows ambiguous token types.
;; The ≤2-round cycle: tokenize → bracket-depth → disambiguate →
;; (if changed) re-tokenize affected spans.
;;
;; For Track 1: disambiguation is applied as a post-pass on the
;; token RRB (not a separate propagator yet — the propagator wiring
;; comes when we install these on the network in Phase 1f).

;; Disambiguate tokens based on bracket context.
;; Returns a new token RRB with narrowed type sets.
(define (disambiguate-tokens token-rrb bracket-rrb)
  (define n (rrb-size token-rrb))
  (let loop ([i 0] [result rrb-empty] [changed? #f])
    (if (>= i n)
        (values result changed?)
        (let* ([entry (rrb-get token-rrb i)]
               [types (token-entry-types entry)]
               [lexeme (token-entry-lexeme entry)]
               ;; For closing delimiters, check depth BEFORE this token
               ;; (bracket-depth RRB stores post-processing depth)
               [bd-before (if (> i 0) (bracket-depth-at bracket-rrb (- i 1)) 0)]
               ;; Decision 1: > inside brackets with angle context → delimiter
               ;; (simplified: any > at bracket-depth > 0 could be a delimiter)
               ;; PPN Track 2B: merge consecutive >> at bracket-depth 0 → $compose
               [compose-merge?
                (and (string=? lexeme ">")
                     (set-member? types 'rangle)
                     (= bd-before 0)
                     (< (+ i 1) n)
                     (let ([next (rrb-get token-rrb (+ i 1))])
                       (and (string=? (token-entry-lexeme next) ">")
                            (set-member? (token-entry-types next) 'rangle))))]
               [new-types
                (cond
                  ;; >> at bracket-depth 0 → compose operator (first > consumed, second skipped below)
                  [compose-merge? (seteq 'symbol)]
                  ;; > that could be operator or rangle
                  [(and (string=? lexeme ">")
                        (set-member? types 'rangle)
                        (> bd-before 0))
                   ;; Inside brackets → narrow to delimiter/rangle
                   (seteq 'rangle)]
                  ;; - that could be operator or negative prefix
                  ;; (if previous token is operator, delimiter, or start of line → prefix)
                  [(and (string=? lexeme "-")
                        (> i 0)
                        (let ([prev (rrb-get token-rrb (- i 1))])
                          (define pt (set-first (token-entry-types prev)))
                          (memq pt '(lbracket lparen lbrace langle
                                     colon quote-lbracket))))
                   ;; After open bracket/colon → could be negative prefix
                   ;; For now: keep as symbol (full disambiguation in Track 2)
                   types]
                  [else types])]
               [entry-changed? (or compose-merge? (not (equal? new-types types)))]
               [new-entry
                (cond
                  [compose-merge?
                   ;; Merge two > into >> compose token
                   (token-entry (seteq 'symbol) ">>"
                                (token-entry-start-pos entry)
                                (token-entry-end-pos (rrb-get token-rrb (+ i 1))))]
                  [entry-changed?
                   (struct-copy token-entry entry [types new-types])]
                  [else entry])])
          (loop (if compose-merge? (+ i 2) (+ i 1))  ;; skip second > when merging
                (rrb-push result new-entry)
                (or changed? entry-changed?))))))


;; ============================================================
;; Full parse pipeline: string → 5 cells on network
;; ============================================================
;;
;; The complete fixpoint computation: character → token → indent →
;; bracket-depth → tree. Disambiguation cycle if needed.

(define (parse-string-to-cells str)
  ;; Create network + cells
  (define net0 (make-prop-network))
  (define-values (net1 cells) (create-parse-cells net0))

  ;; Domain 1: Character RRB
  (define char-rrb (make-char-rrb-from-string str))
  (define net2 (net-cell-write net1 (parse-cells-char-cell-id cells) char-rrb))

  ;; Domain 2: Indent RRB
  (define-values (indent-rrb content-line-indices)
    (make-indent-rrb-from-char-rrb char-rrb))
  (define net3 (net-cell-write net2 (parse-cells-indent-cell-id cells) indent-rrb))

  ;; Domain 3: Token RRB
  (define tok-rrb (tokenize-char-rrb char-rrb))

  ;; Domain 4: Bracket-depth RRB
  (define bd-rrb (make-bracket-depth-rrb tok-rrb))

  ;; Disambiguation cycle (≤2 rounds)
  (define-values (tok-rrb-final bd-rrb-final)
    (let round ([tok tok-rrb] [bd bd-rrb] [rounds 0])
      (if (>= rounds 2)
          (values tok bd)  ;; Max rounds reached
          (let-values ([(narrowed changed?) (disambiguate-tokens tok bd)])
            (if changed?
                ;; Recompute bracket-depth from narrowed tokens
                (let ([new-bd (make-bracket-depth-rrb narrowed)])
                  (round narrowed new-bd (+ rounds 1)))
                (values tok bd))))))

  (define net4 (net-cell-write net3 (parse-cells-token-cell-id cells) tok-rrb-final))
  (define net5 (net-cell-write net4 (parse-cells-bracket-cell-id cells) bd-rrb-final))

  ;; Domain 5: Tree M-type
  (define tree-val
    (build-tree-from-domains char-rrb indent-rrb tok-rrb-final bd-rrb-final
                             content-line-indices))
  (define net6 (net-cell-write net5 (parse-cells-tree-cell-id cells) tree-val))

  (values net6 cells))


;; ============================================================
;; Embedded lattice merge for RRB cells
;; ============================================================

;; Merge function for RRB embedded cells.
;; bot = rrb-empty. Any non-empty RRB replaces bot.
;; Two non-empty RRBs: this shouldn't happen in normal operation
;; (each RRB cell is written once). If it does, keep the larger.
(define rrb-bot rrb-empty)

(define (rrb-embedded-merge a b)
  (cond
    [(rrb-empty? a) b]
    [(rrb-empty? b) a]
    [(eq? a b) a]  ;; identity
    ;; Both non-empty: keep larger (more complete)
    [(>= (rrb-size a) (rrb-size b)) a]
    [else b]))

(define (rrb-embedded-contradicts? v)
  #f)  ;; RRB cells don't contradict


;; ============================================================
;; Parse cell creation (all 5 cells on one network)
;; ============================================================

;; A parse-cells struct holds the 5 cell IDs for one parse operation.
(struct parse-cells
  (char-cell-id      ;; cell-id: character RRB
   indent-cell-id    ;; cell-id: indent RRB
   token-cell-id     ;; cell-id: token RRB (Phase 1b)
   bracket-cell-id   ;; cell-id: bracket-depth RRB (Phase 1d)
   tree-cell-id      ;; cell-id: parse tree M-type (Phase 1c)
   )
  #:transparent)

;; Create all 5 parse cells on a propagator network.
;; Returns: (values updated-net parse-cells)
(define (create-parse-cells net)
  (define-values (net1 char-id)
    (net-new-cell net rrb-bot rrb-embedded-merge rrb-embedded-contradicts?))
  (define-values (net2 indent-id)
    (net-new-cell net1 rrb-bot rrb-embedded-merge rrb-embedded-contradicts?))
  (define-values (net3 token-id)
    (net-new-cell net2 rrb-bot rrb-embedded-merge rrb-embedded-contradicts?))
  (define-values (net4 bracket-id)
    (net-new-cell net3 rrb-bot rrb-embedded-merge rrb-embedded-contradicts?))
  (define-values (net5 tree-id)
    (net-new-cell net4 parse-bot parse-lattice-merge parse-contradicts?))
  (values net5
          (parse-cells char-id indent-id token-id bracket-id tree-id)))


;; ============================================================
;; Phase 3a: Read API (primary tree-walking functions)
;; ============================================================

;; A parse-tree wraps the network + cells + extracted root node.
;; This is the PRIMARY API type for the propagator reader.
(struct parse-tree
  (net       ;; prop-network with all 5 cells populated
   cells     ;; parse-cells struct (cell ids)
   root      ;; parse-tree-node: the root node
   )
  #:transparent)

;; Read a string → parse-tree
(define (read-to-tree str)
  (define-values (net cells) (parse-string-to-cells str))
  (define tree-val (net-cell-read net (parse-cells-tree-cell-id cells)))
  (define deriv (set-first (parse-cell-value-derivations tree-val)))
  (define root (car (derivation-node-children deriv)))
  (parse-tree net cells root))

;; Read a file → parse-tree
(define (read-file-to-tree path)
  (read-to-tree (file->string path)))

;; Get top-level form nodes from a parse-tree
(define (tree-top-level-forms pt)
  (define root (parse-tree-root pt))
  (define children (parse-tree-node-children root))
  (for/list ([i (in-range (rrb-size children))])
    (rrb-get children i)))

;; Get children of a parse-tree-node
;; Returns a list of (parse-tree-node | token-entry)
(define (tree-children node)
  (define children (parse-tree-node-children node))
  (for/list ([i (in-range (rrb-size children))])
    (rrb-get children i)))

;; Find the parent of a node by walking the tree.
;; Returns: parse-tree-node | 'root | #f (not found)
;; Note: O(n) walk — for frequent use, build a parent index.
(define (tree-parent pt target-node)
  (define root (parse-tree-root pt))
  (let search ([node root] [parent 'root])
    (cond
      [(eq? node target-node) parent]
      [(parse-tree-node? node)
       (define children (parse-tree-node-children node))
       (for/or ([i (in-range (rrb-size children))])
         (define child (rrb-get children i))
         (search child node))]
      [else #f])))


;; ============================================================
;; Phase 3b: Write API (tree mutation functions)
;; ============================================================

;; Replace a node's children with a new list.
;; Returns a new parse-tree-node (functional update).
(define (tree-replace-children node new-children-list)
  (struct-copy parse-tree-node node
    [children (rrb-from-list new-children-list)]))

;; Insert a child at a specific position.
;; Returns a new parse-tree-node.
(define (tree-insert-child node child position)
  (define old-children (tree-children node))
  (define new-list
    (append (take old-children (min position (length old-children)))
            (list child)
            (drop old-children (min position (length old-children)))))
  (tree-replace-children node new-list))

;; Remove a child from a node (by eq? identity).
;; Returns a new parse-tree-node.
(define (tree-remove-child node target-child)
  (define new-list
    (filter (lambda (c) (not (eq? c target-child)))
            (tree-children node)))
  (tree-replace-children node new-list))

;; Splice: replace one child with multiple children.
;; Returns a new parse-tree-node.
(define (tree-splice node old-child new-children-list)
  (define result '())
  (for ([c (in-list (tree-children node))])
    (if (eq? c old-child)
        (set! result (append (reverse new-children-list) result))
        (set! result (cons c result))))
  (tree-replace-children node (reverse result)))


;; ============================================================
;; Phase 3c: Compatibility wrappers
;; ============================================================
;;
;; These convert the new reader's output to match the old reader.rkt
;; API, allowing existing consumers to work unchanged.

;; Old-style token: (type value line col pos span)
;; Wraps token-entry for compatibility.
(struct compat-token (type value line col pos span) #:transparent)

;; Convert token-entry → compat-token
(define (token-entry->compat entry source-str)
  (define raw-type (set-first (token-entry-types entry)))
  ;; Remap internal token types to match old reader's type scheme
  ;; The old reader used 'symbol for most operator-like tokens
  (define lexeme (token-entry-lexeme entry))
  (define type
    (case raw-type
      [(pipe pipe-right facts-sep clause-sep) 'symbol]
      ;; rest-param: bare ... → symbol, ...name → rest-param
      [(rest-param)
       (if (equal? lexeme "...") 'symbol 'rest-param)]
      [else raw-type]))
  (define start (token-entry-start-pos entry))
  (define end (token-entry-end-pos entry))
  ;; Compute line/col from start position
  (define-values (line col)
    (pos->line-col source-str start))
  ;; Value conversion uses raw-type (before remapping) for correct dispatch
  (define value
    (case raw-type
      [(symbol)
       ;; Map specific operator symbols to their $-prefixed forms
       (define sym (string->symbol lexeme))
       (cond
         [(equal? lexeme "|>") '$pipe-gt]
         [(equal? lexeme ">>") '$compose]
         [(equal? lexeme "||") '$facts-sep]
         [(equal? lexeme "&>") '$clause-sep]
         [else sym])]
      [(number) (or (string->number lexeme) (string->symbol lexeme))]
      [(string)
       ;; Strip surrounding quotes if present (old reader returned raw content)
       (if (and (>= (string-length lexeme) 2)
                (char=? (string-ref lexeme 0) #\")
                (char=? (string-ref lexeme (- (string-length lexeme) 1)) #\"))
           (substring lexeme 1 (- (string-length lexeme) 1))
           lexeme)]
      [(keyword) (string->symbol lexeme)]
      [(char) (if (= (string-length lexeme) 3)
                  (string-ref lexeme 1)  ;; 'X' → X
                  lexeme)]
      [(path-literal) lexeme]
      [(decimal-literal)
       ;; Parse as exact rational: "3.14" → 157/50, "-3.14" → -157/50
       (define exact-str (string-append "#e" lexeme))
       (or (string->number exact-str) (string->number lexeme) lexeme)]
      [(approx-literal)
       (define num-str (substring lexeme 1))
       ;; Parse as exact: prepend #e to get exact rational (3.14 → 157/50)
       (define exact-str (string-append "#e" num-str))
       (or (string->number exact-str) (string->number num-str) lexeme)]
      [(pipe) '$pipe]
      [(pipe-right) '$pipe-gt]
      [(facts-sep) '$facts-sep]
      [(clause-sep) '$clause-sep]
      [(dot-access nil-dot-access broadcast-access)
       (string->symbol (substring lexeme (if (string-prefix? lexeme "#") 2 1)))]
      [(dot-key)
       ;; .:name → :name (strip leading dot)
       (string->symbol (substring lexeme 1))]
      [(nil-dot-key)
       ;; #:name → :name, #.:name → :name (extract keyword part)
       (cond
         [(string-prefix? lexeme "#.:") (string->symbol (substring lexeme 2))]  ;; #.:name → :name
         [(string-prefix? lexeme "#:")  (string->symbol (substring lexeme 1))]  ;; #:name → :name
         [else (string->symbol lexeme)])]
      [(typed-hole)
       ;; ?? → #f (unnamed), ??name → name (named)
       (if (> (string-length lexeme) 2)
           (string->symbol (substring lexeme 2))
           #f)]
      [(rest-param)
       ;; ... → $rest, ...name → name
       (if (> (string-length lexeme) 3)
           (string->symbol (substring lexeme 3))
           '$rest)]
      [else (if (> (string-length lexeme) 0) (string->symbol lexeme) #f)]))
  (compat-token type value line col start (- end start)))

;; Compute line and column from string position
(define (pos->line-col str pos)
  (let loop ([i 0] [line 1] [col 0])
    (cond
      [(>= i pos) (values line col)]
      [(char=? (string-ref str i) #\newline)
       (loop (+ i 1) (+ line 1) 0)]
      [else (loop (+ i 1) line (+ col 1))])))

;; tokenize-string compatibility: string → (listof compat-token)
;; Prepends a newline token and appends an eof token to match old reader format.
;; Also runs disambiguation and merges >> into $compose.
(define (compat-tokenize-string str)
  (register-default-token-patterns!)  ;; ensure patterns registered
  (define char-rrb (make-char-rrb-from-string str))
  (define tok-rrb (tokenize-char-rrb char-rrb))
  ;; Run disambiguation
  (define bd-rrb (make-bracket-depth-rrb tok-rrb))
  (define-values (disamb-rrb _) (disambiguate-tokens tok-rrb bd-rrb))
  ;; Validate: reject invalid tokens
  (for ([i (in-range (rrb-size disamb-rrb))])
    (define entry (rrb-get disamb-rrb i))
    (define type (set-first (token-entry-types entry)))
    (define lexeme (token-entry-lexeme entry))
    ;; Reject negative Nats (-3N, ~-3N)
    (when (and (eq? type 'nat-literal)
               (string-contains? lexeme "-"))
      (error 'tokenize-string "Negative Nat literal not allowed: ~a" lexeme))
    (when (and (eq? type 'approx-literal)
               (let ([num-str (substring lexeme 1)])
                 (and (string-contains? num-str "-")
                      (string-suffix? num-str "N"))))
      (error 'tokenize-string "Negative Nat literal not allowed: ~a" lexeme))
    ;; Reject standalone & (must use &> for rule clauses)
    (when (and (eq? type 'symbol) (equal? lexeme "&"))
      (error 'prologos-reader "Unexpected & — use &> for rule clauses"))
    ;; Reject standalone . (must use .name for dot-access)
    (when (and (eq? type 'symbol) (equal? lexeme "."))
      (error 'prologos-reader "Unexpected character: .")))
  ;; Convert to compat-tokens
  (define raw-tokens
    (for/list ([i (in-range (rrb-size disamb-rrb))])
      (token-entry->compat (rrb-get disamb-rrb i) str)))
  ;; Post-pass: merge consecutive rangle rangle at bracket-depth 0 → $compose
  (define tokens (compat-merge-compose raw-tokens))
  (append
   (list (compat-token 'newline #f 1 0 0 0))
   tokens
   (list (compat-token 'eof #f 1 (string-length str) (string-length str) 0))))

;; Merge consecutive rangle tokens into $compose symbol
(define (compat-merge-compose tokens)
  (let loop ([rest tokens] [acc '()])
    (cond
      [(null? rest) (reverse acc)]
      [(and (not (null? (cdr rest)))
            (eq? (compat-token-type (car rest)) 'rangle)
            (eq? (compat-token-type (cadr rest)) 'rangle))
       ;; Merge two > into $compose
       (define t1 (car rest))
       (loop (cddr rest)
             (cons (compat-token 'symbol '$compose
                                 (compat-token-line t1) (compat-token-col t1)
                                 (compat-token-pos t1)
                                 (+ (compat-token-span t1) (compat-token-span (cadr rest))))
                   acc))]
      [else (loop (cdr rest) (cons (car rest) acc))])))

;; Accessors matching old reader API names
;; (compat-token-type and compat-token-value are auto-generated by struct)


;; ============================================================
;; Phase 5a: Datum extraction — tree → syntax objects
;; ============================================================
;;
;; Walks parse-tree-nodes and produces Racket syntax objects
;; matching the old reader.rkt output. This is the bridge
;; between the propagator reader's tree and the parser pipeline.

;; Process escape sequences in a string: \n → newline, \t → tab, \\ → \, \" → "
(define (process-string-escapes s)
  (define n (string-length s))
  (let loop ([i 0] [chars '()])
    (cond
      [(>= i n) (list->string (reverse chars))]
      [(and (char=? (string-ref s i) #\\) (< (+ i 1) n))
       (define next (string-ref s (+ i 1)))
       (define esc-char
         (case next
           [(#\n) #\newline]
           [(#\t) #\tab]
           [(#\r) #\return]
           [(#\\) #\\]
           [(#\") #\"]
           [(#\0) #\nul]
           [else next]))
       (loop (+ i 2) (cons esc-char chars))]
      [else (loop (+ i 1) (cons (string-ref s i) chars))])))

(define (make-stx datum source line col pos span)
  ;; datum->syntax expects: line ≥ 1 or #f, col ≥ 0 or #f, pos ≥ 1 or #f, span ≥ 0 or #f
  ;; pos must be ≥ 1 (1-based). Callers pass either 0-based token positions
  ;; (converted via make-stx-from-token) or already-1-based positions from syntax objects.
  (datum->syntax #f datum (list source
                                (if (> line 0) line #f)
                                (if (>= col 0) col #f)
                                (if (> pos 0) pos 1)
                                (if (>= span 0) span #f))))

;; Convert a token-entry → syntax object
(define (token-entry->stx entry source source-str)
  (define type (set-first (token-entry-types entry)))
  (define lexeme (token-entry-lexeme entry))
  (define start (token-entry-start-pos entry))
  (define end (token-entry-end-pos entry))
  (define span (- end start))
  (define pos1 (+ start 1))  ;; 0-based → 1-based for syntax positions
  (define-values (line col) (pos->line-col source-str start))

  (define value
    (case type
      [(symbol) (cond
                  [(string=? lexeme "|>") '$pipe-gt]
                  [(string=? lexeme ">>") '$compose]
                  [(string=? lexeme "&>") '$clause-sep]
                  [(string=? lexeme "||") '$facts-sep]
                  [(string=? lexeme ":=") ':=]
                  [(string=? lexeme "->") '->]
                  [(string=? lexeme "->>") '->>]
                  [else (string->symbol lexeme)])]
      [(number) (or (string->number lexeme) (string->symbol lexeme))]
      [(nat-literal) (string->number (substring lexeme 0 (- (string-length lexeme) 1)))]
      [(string) (if (and (>= (string-length lexeme) 2)
                         (char=? (string-ref lexeme 0) #\")
                         (char=? (string-ref lexeme (- (string-length lexeme) 1)) #\"))
                    (process-string-escapes
                     (substring lexeme 1 (- (string-length lexeme) 1)))
                    lexeme)]
      [(keyword) (string->symbol lexeme)]
      [(char) (cond
                ;; 'X' char literal → the char
                [(and (= (string-length lexeme) 3)
                      (char=? (string-ref lexeme 0) #\'))
                 (string-ref lexeme 1)]
                ;; \a → #\a, \newline → #\newline, etc.
                [(char=? (string-ref lexeme 0) #\\)
                 (define name (substring lexeme 1))
                 (cond
                   [(= (string-length name) 1) (string-ref name 0)]
                   [(string=? name "newline") #\newline]
                   [(string=? name "space") #\space]
                   [(string=? name "tab") #\tab]
                   [(string=? name "return") #\return]
                   [(string=? name "nul") #\nul]
                   [(and (> (string-length name) 1) (char=? (string-ref name 0) #\u))
                    (integer->char (string->number (substring name 1) 16))]
                   [else (string->symbol lexeme)])]
                [else lexeme])]
      [(colon) ':]
      [(pipe) '$pipe]
      [else (string->symbol lexeme)]))

  (case type
    ;; Compound tokens that produce sentinel syntax lists
    [(dot-access)
     (define field-sym (string->symbol (substring lexeme 1)))
     (make-stx (list (make-stx '$dot-access source line col pos1 0)
                     (make-stx field-sym source line (+ col 1) (+ pos1 1) (- span 1)))
               source line col pos1 span)]
    [(dot-key)
     (define kw-sym (string->symbol (substring lexeme 1)))  ;; .:name → :name
     (make-stx (list (make-stx '$dot-key source line col pos1 0)
                     (make-stx kw-sym source line (+ col 1) (+ pos1 1) (- span 1)))
               source line col pos1 span)]
    [(broadcast-access)
     (define field-sym (string->symbol (substring lexeme 2)))
     (make-stx (list (make-stx '$broadcast-access source line col pos1 0)
                     (make-stx field-sym source line (+ col 2) (+ pos1 2) (- span 2)))
               source line col pos1 span)]
    [(nil-dot-access)
     (define field-sym (string->symbol (substring lexeme 2)))
     (make-stx (list (make-stx '$nil-dot-access source line col pos1 0)
                     (make-stx field-sym source line (+ col 2) (+ pos1 2) (- span 2)))
               source line col pos1 span)]
    [(nil-dot-key)
     (define kw-sym (string->symbol lexeme))
     (make-stx (list (make-stx '$nil-dot-key source line col pos1 0)
                     (make-stx kw-sym source line (+ col 2) (+ pos1 2) (- span 2)))
               source line col pos1 span)]
    [(path-literal)
     ;; #p(foo.bar) → (path :foo.bar)
     (define raw (substring lexeme 3 (- (string-length lexeme) 1)))
     (define cleaned (if (and (> (string-length raw) 0)
                              (char=? (string-ref raw 0) #\:))
                         (substring raw 1) raw))
     (define kw-sym (string->symbol (string-append ":" cleaned)))
     (make-stx (list (make-stx 'path source line col pos1 4)
                     (make-stx kw-sym source line col pos1 span))
               source line col pos1 span)]
    ;; Simple tokens → direct syntax wrapping
    [(nat-literal)
     ;; 42N → ($nat-literal 42)
     (make-stx (list (make-stx '$nat-literal source line col pos1 0)
                     (make-stx value source line col pos1 span))
               source line col pos1 span)]
    [(rest-param)
     (if (string=? lexeme "...")
         ;; standalone ... → $rest symbol
         (make-stx '$rest source line col pos1 span)
         ;; ...args → ($rest-param args)
         (let ([name-sym (string->symbol (substring lexeme 3))])
           (make-stx (list (make-stx '$rest-param source line col pos1 0)
                           (make-stx name-sym source line (+ col 3) (+ pos1 3) (- span 3)))
                     source line col pos1 span)))]
    [(typed-hole)
     ;; ?? → ($typed-hole) — wrapped in sentinel list like the old reader
     (make-stx (list (make-stx '$typed-hole source line col pos1 2))
               source line col pos1 span)]
    [else (make-stx value source line col pos1 span)]))

;; ---- Flatten-then-group approach for datum extraction ----
;;
;; The tree represents indent structure (line nodes with children).
;; Bracket grouping crosses line boundaries. We flatten all tokens
;; depth-first within a form's subtree, then apply sequential bracket
;; matching. The tree structure is preserved in cells for Track 2+.

;; Flatten a parse-tree-node depth-first into ordered token-entries
(define (flatten-tokens node)
  (define children (parse-tree-node-children node))
  (define n (rrb-size children))
  (let loop ([i 0] [result '()])
    (if (>= i n)
        (reverse result)
        (let ([child (rrb-get children i)])
          (cond
            [(token-entry? child) (loop (+ i 1) (cons child result))]
            [(parse-tree-node? child)
             (loop (+ i 1) (append (reverse (flatten-tokens child)) result))]
            [else (loop (+ i 1) result)])))))

;; Group tokens from vec[start..end) with bracket matching.
;; Returns (values stx-elements next-index)
(define (group-tokens vec start end close-type source source-str)
  (let loop ([i start] [result '()])
    (cond
      [(>= i end) (values (reverse result) end)]
      [else
       (define entry (vector-ref vec i))
       (define type (set-first (token-entry-types entry)))
       (cond
         ;; Close on matching bracket type (mixfix-rbrace closes on rbrace)
         [(and close-type
               (or (eq? type close-type)
                   (and (eq? close-type 'mixfix-rbrace) (eq? type 'rbrace))))
          (values (reverse result) (+ i 1))]
         [(memq type '(lbracket lparen))
          (define ct (if (eq? type 'lbracket) 'rbracket 'rparen))
          (define-values (inner next-i) (group-tokens vec (+ i 1) end ct source source-str))
          (loop next-i (cons (wrap-stx-list inner source) result))]
         ;; Angle brackets: NOT treated as brackets inside mixfix (.{...})
         ;; In mixfix context (close-type = mixfix-rbrace), < and > are operators
         [(and (eq? type 'langle) (not (eq? close-type 'mixfix-rbrace)))
          (define-values (inner next-i) (group-tokens vec (+ i 1) end 'rangle source source-str))
          (define-values (al ac) (pos->line-col source-str (token-entry-start-pos entry)))
          (loop next-i (cons (make-stx (cons (make-stx '$angle-type source al ac (+ (token-entry-start-pos entry) 1) 1) inner)
                                       source al ac (+ (token-entry-start-pos entry) 1) 1) result))]
         [(eq? type 'lbrace)
          (define-values (inner next-i) (group-tokens vec (+ i 1) end 'rbrace source source-str))
          (define-values (bl bc) (pos->line-col source-str (token-entry-start-pos entry)))
          (loop next-i (cons (make-stx (cons (make-stx '$brace-params source bl bc (+ (token-entry-start-pos entry) 1) 1) inner)
                                       source bl bc (+ (token-entry-start-pos entry) 1) 1) result))]
         [(eq? type 'dot-lbrace)
          ;; .{a b} → ($mixfix a b)
          ;; Use 'mixfix-rbrace so group-tokens knows < > are operators, not brackets
          (define-values (inner next-i) (group-tokens vec (+ i 1) end 'mixfix-rbrace source source-str))
          (define-values (ml mc) (pos->line-col source-str (token-entry-start-pos entry)))
          (loop next-i (cons (make-stx (cons (make-stx '$mixfix source ml mc (+ (token-entry-start-pos entry) 1) 2) inner)
                                       source ml mc (+ (token-entry-start-pos entry) 1) 2) result))]
         [(eq? type 'quote-lbracket)
          (define-values (inner next-i) (group-tokens vec (+ i 1) end 'rbracket source source-str))
          (define-values (ql qc) (pos->line-col source-str (token-entry-start-pos entry)))
          (loop next-i (cons (make-stx (cons (make-stx '$list-literal source ql qc (+ (token-entry-start-pos entry) 1) 2) inner)
                                       source ql qc (+ (token-entry-start-pos entry) 1) 2) result))]
         [(eq? type 'at-lbracket)
          (define-values (inner next-i) (group-tokens vec (+ i 1) end 'rbracket source source-str))
          (define-values (al ac) (pos->line-col source-str (token-entry-start-pos entry)))
          (loop next-i (cons (make-stx (cons (make-stx '$vec-literal source al ac (+ (token-entry-start-pos entry) 1) 2) inner)
                                       source al ac (+ (token-entry-start-pos entry) 1) 2) result))]
         [(eq? type 'tilde-lbracket)
          (define-values (inner next-i) (group-tokens vec (+ i 1) end 'rbracket source source-str))
          (define-values (tl tc) (pos->line-col source-str (token-entry-start-pos entry)))
          (loop next-i (cons (make-stx (cons (make-stx '$lseq-literal source tl tc (+ (token-entry-start-pos entry) 1) 2) inner)
                                       source tl tc (+ (token-entry-start-pos entry) 1) 2) result))]
         [(eq? type 'hash-lbrace)
          (define-values (inner next-i) (group-tokens vec (+ i 1) end 'rbrace source source-str))
          (define-values (hl hc) (pos->line-col source-str (token-entry-start-pos entry)))
          (loop next-i (cons (make-stx (cons (make-stx '$set-literal source hl hc (+ (token-entry-start-pos entry) 1) 2) inner)
                                       source hl hc (+ (token-entry-start-pos entry) 1) 2) result))]
         ;; Stray closing brackets: skip. But in mixfix context, rangle is an operator.
         [(and (memq type '(rangle langle)) (eq? close-type 'mixfix-rbrace))
          ;; Inside .{...}: < and > are operators, emit as symbols
          (loop (+ i 1) (cons (token-entry->stx entry source source-str) result))]
         [(memq type '(rbracket rparen rbrace rangle))
          (loop (+ i 1) result)]
         [else
          (loop (+ i 1) (cons (token-entry->stx entry source source-str) result))])])))

(define (wrap-stx-list elems source)
  (if (null? elems)
      (make-stx '() source 0 0 0 0)
      (let ([first (car elems)] [last (last-stx elems)])
        (make-stx elems source (syntax-line first) (syntax-column first)
                  (syntax-position first)
                  (max 1 (- (+ (syntax-position last) (syntax-span last))
                            (syntax-position first)))))))

;; Convert a parse-tree-node to syntax elements.
;; Uses flatten-then-group on the FULL token sequence (depth-first)
;; to correctly handle both indent grouping and cross-line brackets.
;; Indent grouping is recovered by treating child-node boundaries as
;; implicit wrapping points when not inside an open bracket.
(define (tree-node->stx-elements node source source-str)
  ;; Collect tokens with indent-boundary markers. For a `spec` form, the
  ;; type-signature continuation lines are inlined directly (rather than
  ;; wrapped as sub-lists) so that arrows like `-> Result` placed on their
  ;; own continuation line remain at the top level of the spec body — where
  ;; `decompose-spec-type` looks for them. Metadata-style continuation lines
  ;; (whose first token is a keyword-like symbol such as `:doc`) are still
  ;; wrapped so the `process-spec` metadata loop recognizes them.
  (define items
    (if (spec-form-node? node)
        (flatten-with-boundaries/spec node)
        (flatten-with-boundaries node)))
  (define vec (list->vector items))
  (define-values (elems _end)
    (group-items vec 0 (vector-length vec) #f source source-str))
  elems)

;; Flatten a node into a list of items: token-entries and 'indent-open/'indent-close markers.
;; Child line nodes are wrapped in indent-open/indent-close pairs.
(define (flatten-with-boundaries node)
  (define children (parse-tree-node-children node))
  (define n (rrb-size children))
  ;; Build result as list of lists, then flatten
  (apply append
    (for/list ([i (in-range n)])
      (define child (rrb-get children i))
      (cond
        [(token-entry? child) (list child)]
        [(parse-tree-node? child)
         (append (list 'indent-open)
                 (flatten-with-boundaries child)
                 (list 'indent-close))]
        [else '()]))))

;; Recognize a parse-tree-node whose first token is `spec` or `spec-`. The
;; node's tag may not yet be refined to `'spec` (e.g., the private `spec-`
;; variant is registered as a preparser keyword but has no tag rule), so we
;; look at the first child token directly.
(define (spec-form-node? node)
  (and (parse-tree-node? node)
       (let ([children (parse-tree-node-children node)])
         (and (> (rrb-size children) 0)
              (let ([first (rrb-get children 0)])
                (and (token-entry? first)
                     (let ([lex (token-entry-lexeme first)])
                       (or (equal? lex "spec")
                           (equal? lex "spec-")))))))))

;; Flatten variant for `spec` forms: top-level child lines are SPLICED into
;; the parent token stream (no `indent-open`/`indent-close` wrapping), so a
;; multi-line type signature like
;;     spec foo
;;          [List Rat]
;;          -> Result
;; flattens to `spec foo [List Rat] -> Result` — keeping `->` at the top
;; level where `split-on-arrow-datum` can find it. Continuation lines whose
;; first token is a keyword-like symbol (e.g. `:doc`) are still wrapped so
;; that the `process-spec` metadata loop, which expects `(:key val ...)`
;; sub-lists, continues to recognize them.
(define (flatten-with-boundaries/spec node)
  (define children (parse-tree-node-children node))
  (define n (rrb-size children))
  (apply append
    (for/list ([i (in-range n)])
      (define child (rrb-get children i))
      (cond
        [(token-entry? child) (list child)]
        [(parse-tree-node? child)
         (define inner (flatten-with-boundaries child))
         (if (continuation-starts-with-keyword? inner)
             ;; Metadata-style continuation: keep wrapped as a sub-list
             (append (list 'indent-open) inner (list 'indent-close))
             ;; Type-signature continuation: splice tokens directly
             inner)]
        [else '()]))))

;; Does this flattened token list start with a keyword-like token (lexeme
;; beginning with `:`)? Used to distinguish metadata continuations from
;; type-signature continuations in spec forms.
(define (continuation-starts-with-keyword? items)
  (let loop ([items items])
    (cond
      [(null? items) #f]
      [(eq? (car items) 'indent-open) (loop (cdr items))]
      [(token-entry? (car items))
       (let ([lex (token-entry-lexeme (car items))])
         (and (string? lex)
              (positive? (string-length lex))
              (char=? (string-ref lex 0) #\:)))]
      [else #f])))

;; Lookahead: check if there's a matching rangle before the current scope closes.
;; Scans forward tracking nesting depth for <> pairs.
(define (has-matching-rangle? vec start end close-type)
  ;; Scan forward for matching rangle, tracking ALL bracket depths.
  ;; Skip over nested [...], (...), {...} groups entirely.
  (let loop ([i start] [angle-depth 0] [other-depth 0])
    (cond
      [(>= i end) #f]
      [else
       (define item (vector-ref vec i))
       (cond
         [(not (token-entry? item)) (loop (+ i 1) angle-depth other-depth)]
         [else
          (define type (set-first (token-entry-types item)))
          (cond
            ;; Found matching rangle at angle-depth 0 and not inside other brackets
            [(and (eq? type 'rangle) (= angle-depth 0) (= other-depth 0)) #t]
            ;; Nested angle brackets
            [(eq? type 'langle) (loop (+ i 1) (+ angle-depth 1) other-depth)]
            [(and (eq? type 'rangle) (> angle-depth 0)) (loop (+ i 1) (- angle-depth 1) other-depth)]
            ;; Other brackets — track depth to skip over them
            [(memq type '(lbracket lparen lbrace quote-lbracket at-lbracket
                          tilde-lbracket hash-lbrace dot-lbrace))
             (loop (+ i 1) angle-depth (+ other-depth 1))]
            [(and (memq type '(rbracket rparen rbrace)) (> other-depth 0))
             (loop (+ i 1) angle-depth (- other-depth 1))]
            ;; Hit the current scope's closer at depth 0 → no match
            [(and close-type (not (eq? close-type 'indent-close))
                  (or (eq? type close-type)
                      (and (eq? close-type 'mixfix-rbrace) (eq? type 'rbrace)))
                  (= other-depth 0))
             #f]
            [else (loop (+ i 1) angle-depth other-depth)])])])))

;; Convert | inside list literals to ($list-tail ...) form
;; '[1 2 | ys] → '($list-literal 1 2 ($list-tail ys))
(define (convert-list-tail-pipe items source)
  (let loop ([rest items] [acc '()])
    (cond
      [(null? rest) (reverse acc)]
      ;; Check if current item is $pipe
      [(and (syntax? (car rest))
            (let ([d (syntax-e (car rest))])
              (eq? d '$pipe)))
       ;; Everything after $pipe becomes ($list-tail tail-items...)
       (define tail-items (cdr rest))
       (cond
         [(= (length tail-items) 1)
          ;; Single tail element: ($list-tail elem)
          (define elem (car tail-items))
          (define tail-stx
            (datum->syntax #f (list (datum->syntax #f '$list-tail) elem)))
          (reverse (cons tail-stx acc))]
         [else
          ;; Multiple tail elements: ($list-tail (items...))
          (define tail-stx
            (datum->syntax #f (cons (datum->syntax #f '$list-tail) tail-items)))
          (reverse (cons tail-stx acc))])]
      [else (loop (cdr rest) (cons (car rest) acc))])))

;; Group items (tokens + indent markers) with bracket matching.
;; indent-open/indent-close create implicit sub-lists ONLY when
;; not inside an explicit bracket group (bracket groups take priority).
(define (group-items vec start end close-type source source-str [qq-depth 0])
  (let loop ([i start] [result '()])
    (cond
      [(>= i end)
       (values (reverse result) end)]
      [else
       (define item (vector-ref vec i))
       (cond
         ;; Indent boundary markers
         [(eq? item 'indent-open)
          (if (and close-type (not (eq? close-type 'indent-close)))
              ;; Inside EXPLICIT brackets: ignore indent boundaries (brackets win)
              (loop (+ i 1) result)
              ;; Not inside brackets: collect until indent-close, wrap as sub-form
              (let-values ([(inner-elems next-i)
                            (group-items vec (+ i 1) end 'indent-close source source-str qq-depth)])
                (cond
                  [(null? inner-elems) (loop next-i result)]
                  [(= (length inner-elems) 1) (loop next-i (cons (car inner-elems) result))]
                  [else (loop next-i (cons (wrap-stx-list inner-elems source) result))])))]
         [(eq? item 'indent-close)
          (if (eq? close-type 'indent-close)
              (values (reverse result) (+ i 1))
              (loop (+ i 1) result))]
         ;; Token processing
         [(token-entry? item)
          (define type (set-first (token-entry-types item)))
          (cond
            ;; Matching close bracket
            [(and close-type (not (eq? close-type 'indent-close))
                  (or (eq? type close-type)
                      (and (eq? close-type 'mixfix-rbrace) (eq? type 'rbrace))))
             (values (reverse result) (+ i 1))]
            ;; Square/round brackets — check for postfix index (xs[0] with no space)
            [(memq type '(lbracket lparen))
             (define is-postfix?
               (and (eq? type 'lbracket)
                    (pair? result)
                    ;; Previous item must be adjacent (no whitespace gap)
                    (> i 0)
                    (let ([prev-item (vector-ref vec (- i 1))])
                      (and (token-entry? prev-item)
                           (= (token-entry-end-pos prev-item)
                              (token-entry-start-pos item))))))
             (let-values ([(inner next-i)
                           (group-items vec (+ i 1) end
                                        (if (eq? type 'lbracket) 'rbracket 'rparen)
                                        source source-str qq-depth)])
               (if is-postfix?
                   ;; Postfix: xs[f x] → ($postfix-index (f x)) — wrap inner as sub-form
                   (let-values ([(pl pc) (pos->line-col source-str (token-entry-start-pos item))])
                     (define wrapped-inner
                       (if (= (length inner) 1)
                           inner  ;; single element: ($postfix-index elem)
                           (list (wrap-stx-list inner source))))  ;; multi: ($postfix-index (f x))
                     (loop next-i
                           (cons (make-stx (cons (make-stx '$postfix-index source pl pc (+ (token-entry-start-pos item) 1) 1) wrapped-inner)
                                           source pl pc (+ (token-entry-start-pos item) 1) 1) result)))
                   ;; Normal bracket group
                   (loop next-i (cons (wrap-stx-list inner source) result))))]
            ;; Angle brackets → $angle-type sentinel IF matching rangle exists
            ;; AND we're not inside a dot-lbrace/mixfix group (where < > are operators)
            [(eq? type 'langle)
             (if (and (not (eq? close-type 'mixfix-rbrace))
                      (has-matching-rangle? vec (+ i 1) end close-type))
                 (let-values ([(inner next-i) (group-items vec (+ i 1) end 'rangle source source-str qq-depth)])
                   (let-values ([(al ac) (pos->line-col source-str (token-entry-start-pos item))])
                     (loop next-i
                           (cons (make-stx (cons (make-stx '$angle-type source al ac (+ (token-entry-start-pos item) 1) 1) inner)
                                           source al ac (+ (token-entry-start-pos item) 1) 1) result))))
                 ;; No matching > → treat < as operator
                 (loop (+ i 1) (cons (token-entry->stx item source source-str) result)))]
            ;; Braces → $brace-params sentinel
            [(eq? type 'lbrace)
             (let-values ([(inner next-i) (group-items vec (+ i 1) end 'rbrace source source-str qq-depth)])
               (let-values ([(bl bc) (pos->line-col source-str (token-entry-start-pos item))])
                 (loop next-i
                       (cons (make-stx (cons (make-stx '$brace-params source bl bc (+ (token-entry-start-pos item) 1) 1) inner)
                                       source bl bc (+ (token-entry-start-pos item) 1) 1) result))))]
            ;; Dot-brace → $mixfix sentinel (uses 'mixfix-rbrace to suppress angle brackets)
            [(eq? type 'dot-lbrace)
             (let-values ([(inner next-i) (group-items vec (+ i 1) end 'mixfix-rbrace source source-str qq-depth)])
               (let-values ([(ml mc) (pos->line-col source-str (token-entry-start-pos item))])
                 (loop next-i
                       (cons (make-stx (cons (make-stx '$mixfix source ml mc (+ (token-entry-start-pos item) 1) 2) inner)
                                       source ml mc (+ (token-entry-start-pos item) 1) 2) result))))]
            ;; Quote bracket → $list-literal sentinel
            ;; Also converts `| elem` inside list to ($list-tail elem)
            [(eq? type 'quote-lbracket)
             (let-values ([(inner next-i) (group-items vec (+ i 1) end 'rbracket source source-str qq-depth)])
               (define processed-inner (convert-list-tail-pipe inner source))
               (let-values ([(ql qc) (pos->line-col source-str (token-entry-start-pos item))])
                 (loop next-i
                       (cons (make-stx (cons (make-stx '$list-literal source ql qc (+ (token-entry-start-pos item) 1) 2) processed-inner)
                                       source ql qc (+ (token-entry-start-pos item) 1) 2) result))))]
            ;; At bracket → $pvec-literal sentinel
            [(eq? type 'at-lbracket)
             (let-values ([(inner next-i) (group-items vec (+ i 1) end 'rbracket source source-str qq-depth)])
               (let-values ([(al ac) (pos->line-col source-str (token-entry-start-pos item))])
                 (loop next-i
                       (cons (make-stx (cons (make-stx '$vec-literal source al ac (+ (token-entry-start-pos item) 1) 2) inner)
                                       source al ac (+ (token-entry-start-pos item) 1) 2) result))))]
            ;; Tilde bracket → $lseq-literal sentinel
            [(eq? type 'tilde-lbracket)
             (let-values ([(inner next-i) (group-items vec (+ i 1) end 'rbracket source source-str qq-depth)])
               (let-values ([(tl tc) (pos->line-col source-str (token-entry-start-pos item))])
                 (loop next-i
                       (cons (make-stx (cons (make-stx '$lseq-literal source tl tc (+ (token-entry-start-pos item) 1) 2) inner)
                                       source tl tc (+ (token-entry-start-pos item) 1) 2) result))))]
            ;; Hash brace → $set-literal sentinel
            [(eq? type 'hash-lbrace)
             (let-values ([(inner next-i) (group-items vec (+ i 1) end 'rbrace source source-str qq-depth)])
               (let-values ([(hl hc) (pos->line-col source-str (token-entry-start-pos item))])
                 (loop next-i
                       (cons (make-stx (cons (make-stx '$set-literal source hl hc (+ (token-entry-start-pos item) 1) 2) inner)
                                       source hl hc (+ (token-entry-start-pos item) 1) 2) result))))]
            ;; Stray rangle: check for >> (compose)
            ;; Two consecutive rangle at bracket-depth 0 = >> compose operator
            [(eq? type 'rangle)
             (if (and (< (+ i 1) end)
                      (let ([next (vector-ref vec (+ i 1))])
                        (and (token-entry? next)
                             (eq? (set-first (token-entry-types next)) 'rangle)
                             ;; Adjacent positions (no space between)
                             (= (token-entry-end-pos item)
                                (token-entry-start-pos next)))))
                 ;; Merge two > into $compose
                 (let-values ([(al ac) (pos->line-col source-str (token-entry-start-pos item))])
                   (loop (+ i 2)
                         (cons (make-stx '$compose source al ac (+ (token-entry-start-pos item) 1) 2)
                               result)))
                 ;; Single stray rangle → emit as > operator symbol
                 (loop (+ i 1) (cons (token-entry->stx item source source-str) result)))]
            ;; Comma → skip (cosmetic separator in brace-params, etc.)
            [(eq? type 'comma)
             (if (> qq-depth 0)
                 ;; Inside quasiquote: comma is unquote
                 (if (< (+ i 1) end)
                     (let ([next-item (vector-ref vec (+ i 1))])
                       (cond
                         ;; ,( or ,[ → unquote of bracket group
                         [(and (token-entry? next-item)
                               (memq (set-first (token-entry-types next-item)) '(lparen lbracket)))
                          (let-values ([(inner next-i)
                                        (group-items vec (+ i 2) end  ;; skip , + (
                                                     (if (eq? (set-first (token-entry-types next-item)) 'lparen)
                                                         'rparen 'rbracket)
                                                     source source-str 0)])  ;; qq-depth 0: commas inside unquote are separators
                            (let-values ([(ul uc) (pos->line-col source-str (token-entry-start-pos item))])
                              (loop next-i
                                    (cons (make-stx (list (make-stx '$unquote source ul uc (+ (token-entry-start-pos item) 1) 1)
                                                          (wrap-stx-list inner source))
                                                    source ul uc (+ (token-entry-start-pos item) 1) 1) result))))]
                         ;; ,x → unquote of single token
                         [(token-entry? next-item)
                          (let ([next-stx (token-entry->stx next-item source source-str)])
                            (let-values ([(ul uc) (pos->line-col source-str (token-entry-start-pos item))])
                              (loop (+ i 2)
                                    (cons (make-stx (list (make-stx '$unquote source ul uc (+ (token-entry-start-pos item) 1) 1)
                                                          next-stx)
                                                    source ul uc (+ (token-entry-start-pos item) 1) 1) result))))]
                         [else (loop (+ i 1) result)]))
                     (loop (+ i 1) result))
                 ;; Outside quasiquote: cosmetic separator, skip
                 (loop (+ i 1) result))]
            ;; Other stray closing brackets → skip
            [(memq type '(rbracket rparen rbrace))
             (loop (+ i 1) result)]
            ;; Decimal-literal compound token: 3.14 → ($decimal-literal 157/50)
            [(eq? type 'decimal-literal)
             (define lex (token-entry-lexeme item))
             ;; Parse as exact rational: 3.14 → 157/50 (matching old reader)
             (define num-val (or (string->number (string-append "#e" lex))
                                 (string->number lex)
                                 (string->symbol lex)))
             (define spos (token-entry-start-pos item))
             (define epos (token-entry-end-pos item))
             (define-values (vl vc) (pos->line-col source-str spos))
             (loop (+ i 1)
                   (cons (make-stx (list (make-stx '$decimal-literal source vl vc (+ spos 1) 1)
                                         (make-stx num-val source vl vc spos (- epos spos)))
                                   source vl vc spos (- epos spos))
                         result))]
            ;; Approx-literal compound token: ~42 → ($approx-literal 42)
            [(eq? type 'approx-literal)
             (define lex (token-entry-lexeme item))
             (define num-str (substring lex 1))
             ;; Parse as exact rational: 3.14 → 157/50 (matching old reader)
             (define num-val (or (string->number (string-append "#e" num-str))
                                 (string->number num-str)
                                 (string->symbol num-str)))
             (define spos (token-entry-start-pos item))
             (define epos (token-entry-end-pos item))
             (define-values (vl vc) (pos->line-col source-str spos))
             (loop (+ i 1)
                   (cons (make-stx (list (make-stx '$approx-literal source vl vc (+ spos 1) 1)
                                         (make-stx num-val source vl (+ vc 1) (+ spos 2) (- epos spos 1)))
                                   source vl vc (+ spos 1) (- epos spos))
                         result))]
            ;; Tilde prefix: ~ followed by token → $approx-literal sentinel
            ;; ~42 → ($approx-literal 42), ~[1 2] handled by tilde-lbracket
            [(and (eq? type 'symbol)
                  (equal? (token-entry-lexeme item) "~")
                  (< (+ i 1) end)
                  (let ([next (vector-ref vec (+ i 1))])
                    (and (token-entry? next)
                         ;; Adjacent: no whitespace gap
                         (= (token-entry-end-pos item)
                            (token-entry-start-pos next)))))
             (let* ([next-item (vector-ref vec (+ i 1))]
                    [next-stx (token-entry->stx next-item source source-str)])
               (define-values (vl vc) (pos->line-col source-str (token-entry-start-pos item)))
               (loop (+ i 2)
                     (cons (make-stx (list (make-stx '$approx-literal source vl vc (+ (token-entry-start-pos item) 1) 1)
                                           next-stx)
                                     source vl vc (+ (token-entry-start-pos item) 1) 1)
                           result)))]
            ;; Backtick prefix: ` followed by element → $quasiquote sentinel
            [(eq? type 'backtick)
             (if (< (+ i 1) end)
                 (let* ([next-item (vector-ref vec (+ i 1))])
                   (cond
                     ;; Next is a bracket group → consume CONTENTS as quasiquoted form
                     ;; Skip backtick + open bracket, collect until close, qq-depth+1
                     [(and (token-entry? next-item)
                           (memq (set-first (token-entry-types next-item)) '(lparen lbracket)))
                      (let-values ([(inner next-i)
                                    (group-items vec (+ i 2) end  ;; skip ` + (
                                                 (if (eq? (set-first (token-entry-types next-item)) 'lparen)
                                                     'rparen 'rbracket)
                                                 source source-str (+ qq-depth 1))])
                        (let-values ([(bl bc) (pos->line-col source-str (token-entry-start-pos item))])
                          (loop next-i
                                (cons (make-stx (list (make-stx '$quasiquote source bl bc (+ (token-entry-start-pos item) 1) 1)
                                                      (wrap-stx-list inner source))
                                                source bl bc (+ (token-entry-start-pos item) 1) 1) result))))]
                     ;; Next is comma → `,x → ($quasiquote ($unquote x))
                     [(and (token-entry? next-item)
                           (eq? (set-first (token-entry-types next-item)) 'comma)
                           (< (+ i 2) end))
                      (let* ([unquoted-item (vector-ref vec (+ i 2))]
                             [unquoted-stx (if (token-entry? unquoted-item)
                                               (token-entry->stx unquoted-item source source-str)
                                               (make-stx '_ source 0 0 0 0))])
                        (let-values ([(bl bc) (pos->line-col source-str (token-entry-start-pos item))]
                                     [(ul uc) (pos->line-col source-str (token-entry-start-pos next-item))])
                          (define unquote-form
                            (make-stx (list (make-stx '$unquote source ul uc (+ (token-entry-start-pos next-item) 1) 1)
                                            unquoted-stx)
                                      source ul uc (+ (token-entry-start-pos next-item) 1) 1))
                          (loop (+ i 3)
                                (cons (make-stx (list (make-stx '$quasiquote source bl bc (+ (token-entry-start-pos item) 1) 1)
                                                      unquote-form)
                                                source bl bc (+ (token-entry-start-pos item) 1) 1) result))))]
                     ;; Next is a regular token → consume as single quasiquoted atom
                     [(token-entry? next-item)
                      (let ([next-stx (token-entry->stx next-item source source-str)])
                        (let-values ([(bl bc) (pos->line-col source-str (token-entry-start-pos item))])
                          (loop (+ i 2)
                                (cons (make-stx (list (make-stx '$quasiquote source bl bc (+ (token-entry-start-pos item) 1) 1)
                                                      next-stx)
                                                source bl bc (+ (token-entry-start-pos item) 1) 1) result))))]
                     [else (loop (+ i 1) result)]))
                 (loop (+ i 1) result))]
            ;; Comma inside quasiquote context → $unquote sentinel
            ;; Note: comma is normally skipped (cosmetic separator).
            ;; But inside quasiquote (`` ` ``), commas become unquote.
            ;; This requires quasiquote depth tracking — for now, this is
            ;; handled by the tokenizer's qq-depth channel. The datum
            ;; extraction (group-items) sees comma tokens that the tokenizer
            ;; decided NOT to skip.
            ;; Regular token
            [else
             (loop (+ i 1) (cons (token-entry->stx item source source-str) result))])]
         ;; Unknown item → skip
         [else (loop (+ i 1) result)])])))


;; Convert a parse-tree-node → a single syntax object (wrapping its elements)
(define (tree-node->stx-form node source source-str)
  (define elems (tree-node->stx-elements node source source-str))
  (cond
    [(null? elems) (make-stx '() source 0 0 0 0)]
    [(= (length elems) 1) (car elems)]
    [else
     (define first (car elems))
     (define last (last-stx elems))
     (make-stx elems source
               (syntax-line first)
               (syntax-column first)
               (syntax-position first)
               (max 1 (- (+ (syntax-position last) (syntax-span last))
                         (syntax-position first))))]))

(define (last-stx lst)
  (if (null? (cdr lst)) (car lst) (last-stx (cdr lst))))


;; ---- Infix = rewriting ----
;; If a form's elements contain a bare `=` or `#=` (not `:=`),
;; rewrite from infix to prefix: A ... = B ... → (= A... B...)
(define (maybe-rewrite-infix-eq-stx elems source)
  ;; Find := position (if present and before =, don't rewrite)
  (define assign-pos
    (for/first ([e (in-list elems)] [i (in-naturals)]
                #:when (and (syntax? e) (symbol? (syntax-e e))
                            (eq? (syntax-e e) ':=)))
      i))
  (define eq-pos
    (for/first ([e (in-list elems)] [i (in-naturals)]
                #:when (and (syntax? e) (symbol? (syntax-e e))
                            (or (eq? (syntax-e e) '=)
                                (eq? (syntax-e e) '$narrow-eq))
                            (> i 0)))
      i))
  (if (and eq-pos (not (and assign-pos (> eq-pos assign-pos))))
      (let* ([lhs (take elems eq-pos)]
             [eq-stx (list-ref elems eq-pos)]
             [rhs (drop elems (+ eq-pos 1))]
             [lhs-stx (if (= (length lhs) 1) (car lhs)
                          (wrap-stx-list lhs source))]
             [rhs-stx (if (= (length rhs) 1) (car rhs)
                          (wrap-stx-list rhs source))])
        (list (wrap-stx-list (list eq-stx lhs-stx rhs-stx) source)))
      elems))

;; ---- Main API: read-all-forms-from-tree ----

;; Convert a parse-tree → list of syntax objects (matching old reader output)
(define (read-all-forms-from-tree pt source-str [source "<string>"])
  (define root (parse-tree-root pt))
  (define forms (tree-top-level-forms pt))
  (for/list ([form (in-list forms)])
    (define raw-elems (tree-node->stx-elements form source source-str))
    (define elems (maybe-rewrite-infix-eq-stx raw-elems source))
    (cond
      [(null? elems) (make-stx '() source 0 0 0 0)]
      ;; Single paren-form — don't double-wrap
      [(and (= (length elems) 1) (pair? (syntax-e (car elems))))
       (car elems)]
      [else
       (define first (car elems))
       (define last (last-stx elems))
       (make-stx elems source
                 (syntax-line first)
                 (syntax-column first)
                 (syntax-position first)
                 (max 1 (- (+ (syntax-position last) (syntax-span last))
                           (syntax-position first))))])))

;; Compatibility: read-all-forms-string replacement
(define (compat-read-all-forms-string str)
  (register-default-token-patterns!)
  (define pt (read-to-tree str))
  (define stxs (read-all-forms-from-tree pt str))
  (map syntax->datum stxs))

;; Compatibility: prologos-read-syntax-all replacement
(define (compat-read-syntax-all source port)
  (register-default-token-patterns!)
  (define str (port->string port))
  (define pt (read-to-tree str))
  (read-all-forms-from-tree pt str (or source "<unknown>")))

;; ============================================================
;; Phase 10: Native prologos-read / prologos-read-syntax
;; ============================================================
;; These replace reader.rkt's WS reader functions.
;; Pattern: parse all on first call, cache remaining forms.

(define prologos-stx-cache (make-weak-hasheq))
(define prologos-form-cache (make-weak-hasheq))

;; Read one WS-mode syntax object (with source locations).
;; On first call: reads all forms and caches the rest.
;; Subsequent calls on same port return from cache.
(define (prologos-read-syntax source in)
  (define cached (hash-ref prologos-stx-cache in #f))
  (cond
    [(and cached (pair? cached))
     (hash-set! prologos-stx-cache in (cdr cached))
     (car cached)]
    [(and cached (null? cached))
     eof]
    [else
     ;; First call: parse everything using new reader
     (register-default-token-patterns!)
     (define str (port->string in))
     (define pt (read-to-tree str))
     (define all-forms (read-all-forms-from-tree pt str (or source "<unknown>")))
     (cond
       [(null? all-forms) eof]
       [else
        (hash-set! prologos-stx-cache in (cdr all-forms))
        (car all-forms)])]))

;; Read one WS-mode datum (no source locations).
(define (prologos-read in)
  (define cached (hash-ref prologos-form-cache in #f))
  (cond
    [(and cached (pair? cached))
     (hash-set! prologos-form-cache in (cdr cached))
     (syntax->datum (car cached))]
    [(and cached (null? cached))
     eof]
    [else
     ;; First call: parse everything using new reader
     (register-default-token-patterns!)
     (define str (port->string in))
     (define pt (read-to-tree str))
     (define all-forms (read-all-forms-from-tree pt str "<unknown>"))
     (cond
       [(null? all-forms) eof]
       [else
        (hash-set! prologos-form-cache in (cdr all-forms))
        (syntax->datum (car all-forms))])]))
