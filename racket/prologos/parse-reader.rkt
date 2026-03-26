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
         "rrb.rkt"
         "propagator.rkt"
         "parse-lattice.rkt")

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
           (char=? c #\$))))

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
  ;; Symbol: ident-start followed by ident-continue*
  (define c (rrb-char-at rrb pos))
  (if (and c (ident-start? c))
      (let loop ([i (+ pos 1)])
        (define nc (rrb-char-at rrb i))
        (if (and nc (ident-continue? nc))
            (loop (+ i 1))
            (- i pos)))
      #f))

(define (recognize-number rrb pos)
  ;; Number: digit+, optionally followed by N (nat) or /digit+ (rat)
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

;; ---- Register default patterns ----

(define (register-default-token-patterns!)
  ;; Highest priority first (tried in priority order, highest wins)
  (register-token-pattern!
   (token-pattern 'colon-assign (lambda (rrb pos) (recognize-colon-assign rrb pos))
                  (lambda (s p l) 'symbol) 100))
  (register-token-pattern!
   (token-pattern 'double-colon (lambda (rrb pos) (recognize-double-colon rrb pos))
                  (lambda (s p l) 'symbol) 99))
  (register-token-pattern!
   (token-pattern 'keyword (lambda (rrb pos) (recognize-keyword rrb pos))
                  (lambda (s p l) 'keyword) 95))
  (register-token-pattern!
   (token-pattern 'quote-lbracket (lambda (rrb pos) (recognize-quote-lbracket rrb pos))
                  (lambda (s p l) 'quote-lbracket) 90))
  (register-token-pattern!
   (token-pattern 'string (lambda (rrb pos) (recognize-string rrb pos))
                  (lambda (s p l) 'string) 80))
  (register-token-pattern!
   (token-pattern 'char-lit (lambda (rrb pos) (recognize-char-literal rrb pos))
                  (lambda (s p l) 'char) 79))
  (register-token-pattern!
   (token-pattern 'number (lambda (rrb pos) (recognize-number rrb pos))
                  (lambda (s p l) 'number) 70))
  (register-token-pattern!
   (token-pattern 'symbol (lambda (rrb pos) (recognize-symbol rrb pos))
                  (lambda (s p l) 'symbol) 50))
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
                 ;; No pattern matched — skip character (error recovery)
                 (loop (+ pos 1) token-rrb))])))))


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
