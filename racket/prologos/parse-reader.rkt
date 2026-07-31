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
         ;; D4.P1b-iii: THE reader-form-head registry. A leaf module with no
         ;; project-local requires — that is what lets grouping (here) and
         ;; preparse (macros.rkt) share ONE list with no cycle.
         "reader-forms.rkt"
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

(define (recognize-exp-literal rrb pos)
  ;; Exponent literal (Numerics N1): [-]?digit+(.digit+)?[eE][+-]?digit+
  ;; ONLY matches when an exponent is actually present — otherwise returns #f so
  ;; plain numbers/decimals/arrows fall through to recognize-number /
  ;; recognize-decimal-literal / recognize-negative-number / session-arrow.
  ;; Classified as 'number → value via #e → EXACT (Int if integral, Rat if not),
  ;; bypassing the decimal-literal → Posit32 path (bare 3.14 stays Posit32 = N4).
  (define c0 (rrb-char-at rrb pos))
  (define neg?
    (and c0 (char=? c0 #\-)
         (let ([c1 (rrb-char-at rrb (+ pos 1))])
           (and c1 (char-numeric? c1)))
         ;; same delimiter gate as recognize-negative-number (so x-1e3 stays ident)
         (or (= pos 0)
             (let ([prev (rrb-char-at rrb (- pos 1))])
               (and prev (or (char=? prev #\space) (char=? prev #\newline)
                             (char=? prev #\tab) (char=? prev #\()
                             (char=? prev #\[) (char=? prev #\{)
                             (char=? prev #\<)))))))
  (define start (if neg? (+ pos 1) pos))
  (define s0 (rrb-char-at rrb start))
  (and s0 (char-numeric? s0)
       (let* ([i (let loop ([i (+ start 1)])  ;; integer-part digits
                   (define nc (rrb-char-at rrb i))
                   (if (and nc (char-numeric? nc)) (loop (+ i 1)) i))]
              [i (let ([dot (rrb-char-at rrb i)]      ;; optional .digit+
                       [d1 (rrb-char-at rrb (+ i 1))])
                   (if (and dot (char=? dot #\.) d1 (char-numeric? d1))
                       (let loop ([j (+ i 2)])
                         (define nc (rrb-char-at rrb j))
                         (if (and nc (char-numeric? nc)) (loop (+ j 1)) j))
                       i))]
              [ec (rrb-char-at rrb i)])             ;; REQUIRE [eE][+-]?digit+
         (and ec (or (char=? ec #\e) (char=? ec #\E))
              (let* ([j (+ i 1)]
                     [sgn (rrb-char-at rrb j)]
                     [k (if (and sgn (or (char=? sgn #\+) (char=? sgn #\-))) (+ j 1) j)]
                     [d (rrb-char-at rrb k)])
                (and d (char-numeric? d)
                     (let loop ([m (+ k 1)])
                       (define nc (rrb-char-at rrb m))
                       (if (and nc (char-numeric? nc)) (loop (+ m 1)) (- m pos)))))))))

(define (recognize-float-literal rrb pos)
  ;; Float literal (Numerics N3c): [-]?digit+(.digit+)?([eE][+-]?digit+)? f (32|64)?
  ;; REQUIRES the trailing `f` (optionally `f32`/`f64`); only fires when present so
  ;; bare numbers/decimals/exponents fall through (bare 3.14 stays Posit32 = N4).
  ;; Classified 'float-literal → ($float-literal <exact-rational> <width>) → Float.
  (define c0 (rrb-char-at rrb pos))
  (define neg?
    (and c0 (char=? c0 #\-)
         (let ([c1 (rrb-char-at rrb (+ pos 1))])
           (and c1 (char-numeric? c1)))
         ;; same delimiter gate as recognize-negative-number (so x-3.0f stays ident)
         (or (= pos 0)
             (let ([prev (rrb-char-at rrb (- pos 1))])
               (and prev (or (char=? prev #\space) (char=? prev #\newline)
                             (char=? prev #\tab) (char=? prev #\()
                             (char=? prev #\[) (char=? prev #\{)
                             (char=? prev #\<)))))))
  (define start (if neg? (+ pos 1) pos))
  (define s0 (rrb-char-at rrb start))
  (and s0 (char-numeric? s0)
       (let* ([i (let loop ([i (+ start 1)])         ;; integer-part digits
                   (define nc (rrb-char-at rrb i))
                   (if (and nc (char-numeric? nc)) (loop (+ i 1)) i))]
              [i (let ([dot (rrb-char-at rrb i)]      ;; optional .digit+
                       [d1 (rrb-char-at rrb (+ i 1))])
                   (if (and dot (char=? dot #\.) d1 (char-numeric? d1))
                       (let loop ([j (+ i 2)])
                         (define nc (rrb-char-at rrb j))
                         (if (and nc (char-numeric? nc)) (loop (+ j 1)) j))
                       i))]
              [i (let ([ec (rrb-char-at rrb i)])      ;; optional [eE][+-]?digit+
                   (if (and ec (or (char=? ec #\e) (char=? ec #\E)))
                       (let* ([j (+ i 1)]
                              [sgn (rrb-char-at rrb j)]
                              [k (if (and sgn (or (char=? sgn #\+) (char=? sgn #\-))) (+ j 1) j)]
                              [d (rrb-char-at rrb k)])
                         (if (and d (char-numeric? d))
                             (let loop ([m (+ k 1)])
                               (define nc (rrb-char-at rrb m))
                               (if (and nc (char-numeric? nc)) (loop (+ m 1)) m))
                             i))   ;; 'e' without exponent digits → no exp consumed
                       i))]
              [fc (rrb-char-at rrb i)])               ;; REQUIRE the `f` suffix
         (and fc (char=? fc #\f)
              (let* ([j (+ i 1)]
                     [cj (rrb-char-at rrb j)]
                     [cj1 (rrb-char-at rrb (+ j 1))]
                     [j2 (cond
                           [(and cj cj1 (char=? cj #\3) (char=? cj1 #\2)) (+ j 2)]
                           [(and cj cj1 (char=? cj #\6) (char=? cj1 #\4)) (+ j 2)]
                           [else j])]
                     [after (rrb-char-at rrb j2)])
                ;; trailing guard: the suffix must end the token (no alnum after)
                (and (or (not after)
                         (not (or (char-numeric? after) (char-alphabetic? after))))
                     (- j2 pos)))))))

(define (recognize-posit-literal rrb pos)
  ;; Posit literal (Numerics N6b; bare `p` = Posit64 added for Float symmetry):
  ;;   [-]?digit+(.digit+)?([eE][+-]?digit+)? p (8|16|32|64)?
  ;; Bare `p` → Posit64 (mirrors bare `f` = Float64); explicit p8/p16/p32/p64; no
  ;; suffix at all = Posit32 (D-N6.1 compute default). Mirrors recognize-float-literal.
  ;; Classified 'posit-literal → ($posit-literal <exact-rational> <width>) → Posit.
  (define c0 (rrb-char-at rrb pos))
  (define neg?
    (and c0 (char=? c0 #\-)
         (let ([c1 (rrb-char-at rrb (+ pos 1))])
           (and c1 (char-numeric? c1)))
         ;; same delimiter gate as recognize-negative-number (so x-3.0p8 stays ident)
         (or (= pos 0)
             (let ([prev (rrb-char-at rrb (- pos 1))])
               (and prev (or (char=? prev #\space) (char=? prev #\newline)
                             (char=? prev #\tab) (char=? prev #\()
                             (char=? prev #\[) (char=? prev #\{)
                             (char=? prev #\<)))))))
  (define start (if neg? (+ pos 1) pos))
  (define s0 (rrb-char-at rrb start))
  (and s0 (char-numeric? s0)
       (let* ([i (let loop ([i (+ start 1)])         ;; integer-part digits
                   (define nc (rrb-char-at rrb i))
                   (if (and nc (char-numeric? nc)) (loop (+ i 1)) i))]
              [i (let ([dot (rrb-char-at rrb i)]      ;; optional .digit+
                       [d1 (rrb-char-at rrb (+ i 1))])
                   (if (and dot (char=? dot #\.) d1 (char-numeric? d1))
                       (let loop ([j (+ i 2)])
                         (define nc (rrb-char-at rrb j))
                         (if (and nc (char-numeric? nc)) (loop (+ j 1)) j))
                       i))]
              [i (let ([ec (rrb-char-at rrb i)])      ;; optional [eE][+-]?digit+
                   (if (and ec (or (char=? ec #\e) (char=? ec #\E)))
                       (let* ([j (+ i 1)]
                              [sgn (rrb-char-at rrb j)]
                              [k (if (and sgn (or (char=? sgn #\+) (char=? sgn #\-))) (+ j 1) j)]
                              [d (rrb-char-at rrb k)])
                         (if (and d (char-numeric? d))
                             (let loop ([m (+ k 1)])
                               (define nc (rrb-char-at rrb m))
                               (if (and nc (char-numeric? nc)) (loop (+ m 1)) m))
                             i))   ;; 'e' without exponent digits → no exp consumed
                       i))]
              [pc (rrb-char-at rrb i)])               ;; REQUIRE the `p` suffix
         (and pc (char=? pc #\p)
              (let* ([j (+ i 1)]
                     [cj (rrb-char-at rrb j)]
                     [cj1 (rrb-char-at rrb (+ j 1))]
                     [j2 (cond
                           [(and cj cj1 (char=? cj #\1) (char=? cj1 #\6)) (+ j 2)]
                           [(and cj cj1 (char=? cj #\3) (char=? cj1 #\2)) (+ j 2)]
                           [(and cj cj1 (char=? cj #\6) (char=? cj1 #\4)) (+ j 2)]
                           [(and cj (char=? cj #\8)) (+ j 1)]
                           [else j])]                  ;; bare `p` → Posit64 (like bare `f`)
                     [after (and j2 (rrb-char-at rrb j2))])
                (and j2
                     ;; trailing guard: the suffix must end the token (no alnum after)
                     (or (not after)
                         (not (or (char-numeric? after) (char-alphabetic? after))))
                     (- j2 pos)))))))

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
        ;; Keyword-continue delegates to ident-continue? — the SINGLE source of
        ;; truth, matching the sibling keyword recognizers (#:kw / .:kw, which
        ;; already loop on ident-continue?). This admits ?/! (the predicate /
        ;; mutation suffix conventions: :active?, :reset!) and ^ (path-selection
        ;; rename :key^alias, kept whole then split by validate-selection-paths).
        ;; The LEADING char (above) stays char-alphabetic? — deliberately narrower
        ;; than ident-start? so :=/:-foo do not collide with colon-assign. (CIU T6
        ;; F1b.7g: was an inline charset that had drifted from ident-continue? for
        ;; 8 chars; CIU T6 F3 added ^ inline without noticing the base divergence.)
        (if (and nc (ident-continue? nc))
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

;; (N6c) `~N` approximate literals are REMOVED — bare decimals are Posit32
;; (N6b), other widths use pNN literals (2.5p8). `~[` (LSeq) survives via
;; recognize-tilde-lbracket above. The recognizer is KEPT solely so stale
;; tilde-numeric input gets a migration hint instead of silent mis-tokenizing.
(define (recognize-removed-tilde-number rrb pos)
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 c2 (char=? c1 #\~)
           (or (char-numeric? c2)
               (and (char=? c2 #\-)
                    (let ([c3 (rrb-char-at rrb (+ pos 2))])
                      (and c3 (char-numeric? c3))))))
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

(define (recognize-dot-lparen rrb pos)
  ;; .(  — mixfix entry with `( )` grouping. Content closes on `)`.
  ;; (The 2026-07-26 note here — "`.{ }` is RETIRED entirely … selection is the
  ;;  postfix-bracket surface" — described a surface the 2026-07-28 REDESIGN
  ;;  replaced. `.{` is live again below, for a DIFFERENT construct.)
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 c2 (char=? c1 #\.) (char=? c2 #\())
      2
      #f))

;; CIU T6 D4.P1b-ii (ruling 3a + Q_M5) — the mid-path sub-block opener.
;; `.{` is descend-then-select: `server^.{ssl port}`. `.` uniformly DESCENDS
;; and the brace SELECTS, so this is a compound token, not a mixfix entry.
;;
;; ⚠ Its closer is a PLAIN `'rbrace`, deliberately NOT dot-lparen's
;; `'mixfix-rparen` sentinel (Q_M5): the extent scanner stores REAL token types
;; as frame closers and `langle-matched?` terminates on a bare `eq?` with no
;; translation arm (its twin `has-matching-rangle?` DOES translate) — a sentinel
;; closer would reproduce the `31d27c83` cross-line swallow AND would add six
;; closer-side sites. With `'rbrace`, every closer enumeration already lists it
;; and ZERO closer-side edits are needed.
;;
;; Prefix-disjoint from all five dot-band members by second character
;; (`.`/`:`/`(`/`*`/ident-start); `recognize-dot-access` additionally excludes
;; `{` explicitly. Per Q8.5 invariant 1, DISJOINTNESS — not the priority
;; number — is what makes this safe.
(define (recognize-dot-lbrace rrb pos)
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (if (and c1 c2 (char=? c1 #\.) (char=? c2 #\{))
      2
      #f))

;; CIU T6 D4.P2 — ORDINAL ACCESS `.N` (owner rulings Q_M8 · Q_R1 · Q_R2 · Q_R3).
;;
;; `.` DESCENDS uniformly under the 2026-07-28 surface, so `.0` / `.10` is
;; ordinal descent — the positional twin of `.name`. MULTI-digit per Q_M8.
;;
;; WHY THIS KILLS THE RATIONAL MIS-LEX STRUCTURALLY, not heuristically: the
;; tokenizer scans by POSITION and advances by the matched length, so once `.1`
;; is consumed AT THE DOT, `recognize-decimal-literal` — which anchors at a
;; DIGIT — never gets the interior dot of `x.1.2` as a candidate position. The
;; dot simply stops being available as an anchor. (Before this, `x.1.2` read as
;; `($decimal-literal 6/5)` and `x.10.20` as `51/5`. ⚠ Those were READER-layer
;; readings: end-to-end the stranded bare `|.|` was UNBOUND, so the forms were
;; LOUD, not silently wrong. See D4 §Q8.1's layer-error correction.)
;;
;; DISJOINTNESS, NOT PRIORITY, IS THE SAFETY PROPERTY (Q8.5 invariant 1 —
;; priorities tie three ways at 87 and the registry is a plain hash, so ties
;; break by unspecified order). The six-member dot band discriminates entirely
;; on the SECOND character: `.` rest-param · `:` dot-key · `(` dot-lparen ·
;; `{` dot-lbrace · `*` broadcast-access · ident-start dot-access (which
;; excludes digits EXPLICITLY). A digit is disjoint from all six.
;;
;; Q_R2 — THE TRAILING GUARD, copied from the `:N` twin
;; (`recognize-colon-annotation`): consume the whole digit run, THEN decline if
;; an `ident-continue?` char follows. So `x.0N` `x.1e3` `x.1/2` `x.1f` `x.1p8`
;; all DECLINE and keep lexing exactly as they do today — the guard mints no new
;; error surface. `xs.0N` is a NAMED NON-GOAL (`0N` is the project's Nat
;; spelling and `expr-get` accepts Nat-or-Int, so it reads as sensible
;; Prologos; supporting it needs `digit+` plus an optional `N`, which is not
;; this phase). Note `#\.` is NOT in `ident-continue?`, which is what lets
;; `x.1.2` chain rather than decline.
;;
;; ⚠ ASCII DIGITS, DELIBERATELY DIFFERENT FROM THE `:N` TWIN — and this is NOT
;; the F1b.7g drift class, because the two classifiers have different
;; obligations. The twin's classifier keeps its lexeme symbolic and never calls
;; `string->number`; THIS one must produce a NUMERIC payload (Q_R1). Measured:
;; `char-numeric?` ACCEPTS U+0663 ARABIC-INDIC DIGIT THREE (and U+06F3, U+0966,
;; U+FF11, U+17E0) while `(string->number "٣")` returns `#f`, so a
;; `char-numeric?` gate here would mint a payload of `#f`. The narrow test is
;; the one that matches what the classifier can actually convert.
;;
;; ⚠ AN EARLIER VERSION OF THIS COMMENT MADE A LAYER ERROR — corrected after
;; adversarial verify measured the counterfactual end-to-end, and recorded here
;; because it is the THIRD instance of this class in this phase (see `0e5a56a3`
;; and `f6f30eaa`). It claimed the `char-numeric?` gate would be a "SILENT WRONG
;; DATUM … worse than" the audit's predicted `exact?: contract violation`. Both
;; halves were layer-confused: (1) the `#f` payload is silent only at the DATUM
;; layer — end-to-end it is a LOUD per-command `ERROR: Unexpected datum: #f`
;; with the file continuing, i.e. LESS severe, not worse; (2) the audit's
;; `exact?: contract violation` prediction describes the SHIPPED path correctly
;; (a non-ASCII digit is declined by this recognizer AND by `recognize-dot-access`,
;; whose :738 exclusion is the wider `char-numeric?`, so it falls to pre-existing
;; machinery and raises there — byte-identical to baseline). The audit was right;
;; it was not superseded. State the layer with the measurement — the same
;; discipline this file's own comment 30 lines above already applies.
(define (ascii-digit? c)
  (and (char? c) (char<=? #\0 c) (char<=? c #\9)))

(define (recognize-dot-ordinal rrb pos)
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (cond
    [(not (and c1 c2 (char=? c1 #\.) (ascii-digit? c2))) #f]
    [else
     (let loop ([i (+ pos 2)])
       (define c (rrb-char-at rrb i))
       (cond
         [(ascii-digit? c) (loop (+ i 1))]
         ;; Q_R2: a suffixed numeric shape is NOT an ordinal — decline whole.
         [(and c (ident-continue? c)) #f]
         [else (- i pos)]))]))

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
  ;; `:N` (N = one or MORE digits) · `:w` · `:m` — ONLY when not followed by
  ;; ident-continue (else it is a keyword like :where, :write, :wm).
  ;;
  ;; CIU T6 D4.P1b-iii / Q_M8 [owner]: the digit run is `digit+`, not one digit.
  ;; It was hard-capped at 2 chars, so `:10` shattered into `:` + `10` while
  ;; `:0`…`:9` were single tokens — arbitrary, and it also made `{:10 v}` an
  ;; illegal map key while `{:0 v}`/`{:9 v}` were fine.
  ;;
  ;; Widening is not widening a COLLISION: this recognizer already accepted
  ;; TWELVE lexemes (`:0`–`:9`, `:w`, `:m`) while `mult-annot?` (parser.rkt)
  ;; accepts THREE (`:0 :1 :w`), so nine of the twelve already lexed as one
  ;; token and already were not multiplicities. Ordinal ∩ multiplicity is
  ;; `:0`/`:1` only, and those are discriminated by POSITION (of 289 live
  ;; multiplicity tokens, 287 spaced + 2 opener-preceded, ZERO focus-adjacent).
  ;;
  ;; ⚠ The trailing guard must be tested after the LAST digit — see
  ;; `fused-type-annot?` in parser.rkt for the co-migration this REQUIRES.
  (define c1 (rrb-char-at rrb pos))
  (define c2 (rrb-char-at rrb (+ pos 1)))
  (cond
    [(not (and c1 c2 (char=? c1 #\:))) #f]
    ;; letter arm — unchanged, always exactly 2 chars
    [(or (char=? c2 #\w) (char=? c2 #\m))
     (let ([c3 (rrb-char-at rrb (+ pos 2))])
       (if (not (and c3 (ident-continue? c3))) 2 #f))]
    ;; digit arm — consume the whole run, THEN apply the guard
    [(char-numeric? c2)
     (let loop ([i (+ pos 2)])
       (define c (rrb-char-at rrb i))
       (cond
         [(and c (char-numeric? c)) (loop (+ i 1))]
         [(and c (ident-continue? c)) #f]   ;; e.g. `:10abc` — not an annotation
         [else (- i pos)]))]
    [else #f]))

;; CIU T6 D4.P1b-i (owner ruling Q_L1's scoped-in repair) — the WS narrowing
;; typed logic variable `?x:Nat` (chains: `?foo:Nat:Even`), lexed as ONE token.
;;
;; The sexp reader glues `?x:Nat` into a single symbol; the WS tokenizer split
;; it, so `narrow-var-constraints`' string-split never saw a colon: WS
;; narrowing silently returned `nil` — ZERO solutions, ZERO errors — where
;; sexp returns six. Its only regression pin passed on the substring "nil",
;; i.e. it passed BECAUSE of the bug.
;;
;; ⚠ The FIRST fix attempt joined the two datums back together in the PARSER,
;; and was UNSOUND: at the datum layer adjacency is already destroyed (the
;; very fact this phase's audit established for braces), so it absorbed ANY
;; following colon-symbol — `[add ?x :foo ?y] = 5N` silently became a
;; different 2-argument goal returning six solutions, and `{:name ?n :age 30}`
;; swallowed a map key. Caught by two independent skeptics. Doing it HERE, in
;; the tokenizer, makes adjacency inherent: a token is contiguous by
;; construction, so a SPACE-separated `?m :name` cannot match and keyword
;; arguments after a logic variable are untouched.
(define (recognize-narrow-var-annot rrb pos)
  (define (ident-run i)   ;; length of an ident-start ident-continue* run at i
    (define c (rrb-char-at rrb i))
    (and c (ident-start? c)
         (let loop ([j (+ i 1)])
           (define cj (rrb-char-at rrb j))
           (if (and cj (ident-continue? cj)) (loop (+ j 1)) (- j i)))))
  (define c0 (rrb-char-at rrb pos))
  (and c0 (char=? c0 #\?)
       (let ([vlen (ident-run (+ pos 1))])
         (and vlen
              ;; at least one `:Segment` must follow, contiguously
              (let seg ([i (+ pos 1 vlen)] [n 0])
                (define ci (rrb-char-at rrb i))
                (cond
                  [(and ci (char=? ci #\:))
                   (let ([slen (ident-run (+ i 1))])
                     (if slen (seg (+ i 1 slen) (+ n 1)) (and (> n 0) (- i pos))))]
                  [(> n 0) (- i pos)]
                  [else #f]))))))

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
  ;; D4.P1b-i: `?x:Nat` as ONE token — before `symbol` (50), which would stop
  ;; at the colon. Contiguity is the discriminator: `?m :name` (spaced) is
  ;; untouched, so keyword arguments after a logic variable still work.
  (register-token-pattern!
   (token-pattern 'narrow-var-annot (lambda (rrb pos) (recognize-narrow-var-annot rrb pos))
                  (lambda (s p l) 'symbol) 96))
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
  ;; Exponent literals (Numerics N1): 1e10, 1.5e-3, -1.5e-3 → exact (Int/Rat).
  ;; Priority 97 so it wins over negative-number (96), decimal-literal (75) and
  ;; number (70) for exponent-bearing lexemes; only fires when an exponent is
  ;; present, so plain numbers/decimals/arrows are unaffected.
  (register-token-pattern!
   (token-pattern 'exp-literal (lambda (rrb pos) (recognize-exp-literal rrb pos))
                  (lambda (s p l) 'number) 97))
  ;; Float literals (Numerics N3c): 3.14f, 3.14f32, 1.5e-3f64 → Float.
  ;; Priority 98 so it wins over exp-literal (97) and below, consuming the
  ;; trailing `f`/`f32`/`f64` in one token; only fires when the `f` suffix is present.
  (register-token-pattern!
   (token-pattern 'float-literal (lambda (rrb pos) (recognize-float-literal rrb pos))
                  (lambda (s p l) 'float-literal) 98))
  ;; Posit literals (Numerics N6b): 2p8, 3.14p16, 1.5e-3p64 → Posit{8,16,32,64}.
  ;; p32 accepted on input for explicitness though display emits bare (Posit32
  ;; is the bare-decimal default width). Suffix space disjoint from `f`.
  (register-token-pattern!
   (token-pattern 'posit-literal (lambda (rrb pos) (recognize-posit-literal rrb pos))
                  (lambda (s p l) 'posit-literal) 99))
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
   (token-pattern 'dot-lparen (lambda (rrb pos) (recognize-dot-lparen rrb pos))
                  (lambda (s p l) 'dot-lparen) 87))
  ;; D4.P1b-ii: `.{` mid-path sub-block. Shares 87 with its dot-compound
  ;; siblings; safe because the three are PREFIX-DISJOINT (`(` / `*` / `{`),
  ;; not because of the number — priorities tie here and the registry is a
  ;; plain hash, so ties break by unspecified order (Q8.5 invariant 1).
  (register-token-pattern!
   (token-pattern 'dot-lbrace (lambda (rrb pos) (recognize-dot-lbrace rrb pos))
                  (lambda (s p l) 'dot-lbrace) 87))
  (register-token-pattern!
   (token-pattern 'broadcast-access (lambda (rrb pos) (recognize-broadcast-access rrb pos))
                  (lambda (s p l) 'broadcast-access) 87))
  ;; D4.P2: `.N` ordinal access. Joins the 87 dot-compound cluster, making it
  ;; FOUR-way — safe for the same reason the three-way was: all four are
  ;; PREFIX-DISJOINT (`(` / `*` / `{` / digit), not because of the number
  ;; (Q8.5 invariant 1). It is also disjoint from `decimal-literal` (75), which
  ;; anchors at a DIGIT and can therefore never contend for a dot position.
  (register-token-pattern!
   (token-pattern 'dot-ordinal (lambda (rrb pos) (recognize-dot-ordinal rrb pos))
                  (lambda (s p l) 'dot-ordinal) 87))
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
  ;; (N6c) ~N approximate literals removed — the pattern now raises a
  ;; migration hint (fires on the production tokenizer, any entry path)
  (register-token-pattern!
   (token-pattern 'tilde-number (lambda (rrb pos) (recognize-removed-tilde-number rrb pos))
                  (lambda (s p l)
                    (error 'prologos-reader
                           "`~~` approximate literals were removed — bare decimals are Posit32 (3.14); use pNN literals for other widths (3.14p16, or 3.14p for Posit64)"))
                  86))
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
;;
;; `<`/`>` are NOT unconditional openers/closers — they double as operators.
;; The grouping layer (group-items) decides: inside mixfix `.( )` they are
;; operators by fiat; elsewhere `<` opens an angle group only when a matching
;; `>` exists in scope (has-matching-rangle?). The extent scan here MUST make
;; the same call, else an operator-`<` leaves the running depth >0 at end of
;; line and every following top-level line is silently swallowed as a
;; bracket continuation (the `.( 3N < 5N )` / `[< 3N 5N]` defect, 2026-07-26).
;; A frame stack tracks the innermost group kind + its closer to mirror the
;; grouping layer's context.
;; ============================================================
;; CIU T6 D4.P1b-i (owner ruling Q_M4) — the TOP-LEVEL `<` bound.
;;
;; `langle-matched?` / `has-matching-rangle?` decide whether a `<` OPENS an
;; angle group by scanning ahead for a matching `>`. Their terminating arm
;; needs a close-type — but at TOP LEVEL close-type is #f, so it can never
;; fire and the scan ran to the END OF THE TOKEN STREAM. A `<` therefore
;; matched a `>` belonging to a LATER top-level form: `def p := 1 < 2` /
;; `def q := 3 > 4` collapsed into ONE form at ZERO errors — a silent
;; wrong answer in ordinary code, and the reason `:<` (disclose) looked
;; hazardous when the hazard was the bare `<`.
;;
;; The bound: a TOP-LEVEL `<` may not scan past the start of the NEXT
;; top-level form. Continuation lines are INDENTED by layout, so multi-line
;; angle groups (`<(x : A)\n -> B>`) are unaffected — pinned in
;; test-parse-reader.rkt. Applied ONLY when close-type is #f: nested scopes
;; are already bounded by their own closer, so this cannot regress them.
;;
;; Both twins take the bound. Their disagreement IS the `31d27c83` defect
;; class, and the bracket-depth pin passing while the datum layer collapsed
;; is exactly what proved both are load-bearing here.
;; ============================================================

;; A token BEGINS A TOP-LEVEL FORM iff it is the first thing on its line and
;; that line has indent 0. Both halves DELEGATE to the reader's own notions
;; rather than re-deriving them:
;;   * indent = leading SPACE count — exactly `measure-indent` (:121-126);
;;   * everything between the line start and the token must be whitespace,
;;     which makes `\r` (CRLF) and `\t` invisible here just as the tokenizer
;;     already treats them.
;;
;; ⚠ The first draft of this bound hand-rolled a THIRD definition of
;; "indent-0 content line" and drifted from BOTH existing ones — it counted
;; `\r` as content (so a CRLF blank line destroyed a working angle group) and
;; counted `\t` as indent (so tab-indented files got no bound at all and the
;; swallow survived). That is the F1b.7g drift class in `prologos-syntax.md`
;; § Reader, caught by the P1b-i adversarial verify. Working per TOKEN also
;; removes two hazards the string scan had for free: a multi-line STRING is
;; ONE token, so column-0 text inside it can no longer register a phantom
;; form start, and comments are not tokens at all.
(define (line-start-of src pos)
  (let back ([i (- pos 1)])
    (cond [(< i 0) 0]
          [(char=? (string-ref src i) #\newline) (+ i 1)]
          [else (back (- i 1))])))

;; Indent of the line containing `pos`, delegating to `measure-indent`'s
;; semantics: LEADING SPACES only (a tab-indented line therefore has indent 0
;; and is a sibling, exactly as the layout engine already reads it).
(define (line-indent-at src pos)
  (define ls (line-start-of src pos))
  (let count ([i ls] [k 0])
    (if (and (< i (string-length src)) (char=? (string-ref src i) #\space))
        (count (+ i 1) (+ k 1))
        k)))

;; Is `pos` the FIRST token position on its line? (Only whitespace behind it.)
;; Working per TOKEN is what makes a multi-line STRING safe: the string is ONE
;; token, so column-0 text inside it can never register as a form start.
(define (token-first-on-line? src pos)
  (let scan ([i (line-start-of src pos)])
    (cond [(>= i pos) #t]
          [(memv (string-ref src i) '(#\space #\tab #\return)) (scan (+ i 1))]
          [else #f])))

;; Does the token at `tok-pos` START A NEW FORM relative to a `<` at
;; `langle-pos`? Layout rule: a line at the SAME-or-LESSER indent is a sibling
;; or an outdent — a new form; a MORE-indented line is a continuation.
;;
;; ⚠ Two earlier drafts of this bound were wrong in instructive ways, both
;; caught by the P1b-i adversarial verify. The first hand-rolled a THIRD
;; definition of "indent-0 content line" that drifted from BOTH `content-line?`
;; and `measure-indent` (it counted `\r` as content, so a CRLF blank line
;; destroyed a working angle group, and counted `\t` as indent, so
;; tab-indented files got no bound at all) — the F1b.7g drift class. The
;; second fixed those but tested "indent 0" absolutely, which misses every
;; file whose forms start indented (`"  def a\n  def b"` is TWO forms).
;; Delegate, and compare RELATIVE indent.
(define (token-starts-new-form? src langle-pos tok-pos)
  (and (token-first-on-line? src tok-pos)
       (<= (line-indent-at src tok-pos) (line-indent-at src langle-pos))))

(define (make-bracket-depth-rrb token-rrb [src #f])
  (define n (rrb-size token-rrb))
  ;; Lookahead twin of has-matching-rangle? over the token RRB: is there a
  ;; matching rangle for a langle at `start`, before the enclosing group's
  ;; closer? Skips balanced nested groups; nested angles via angle-depth.
  (define (langle-matched? start close-type)
    ;; Q_M4: at TOP LEVEL (no enclosing closer) bound the scan at the next
    ;; top-level form start, else it runs to EOF and matches another form's `>`.
    (define langle-pos
      (and src (not close-type) (> start 0)
           (token-entry-start-pos (rrb-get token-rrb (- start 1)))))
    (let loop ([i start] [angle-depth 0] [other-depth 0])
      (cond
        [(>= i n) #f]
        [(and langle-pos
              (token-starts-new-form?
               src langle-pos (token-entry-start-pos (rrb-get token-rrb i))))
         #f]
        [else
         (define type (set-first (token-entry-types (rrb-get token-rrb i))))
         (cond
           [(and (eq? type 'rangle) (= angle-depth 0) (= other-depth 0)) #t]
           [(eq? type 'langle) (loop (+ i 1) (+ angle-depth 1) other-depth)]
           [(and (eq? type 'rangle) (> angle-depth 0))
            (loop (+ i 1) (- angle-depth 1) other-depth)]
           ;; OPENER DEPTH-BALANCING set (NOT angle suppression — that is keyed
           ;; on frame kind 'mixfix below). MUST stay identical to its twin in
           ;; has-matching-rangle?; their disagreement IS the 31d27c83 defect.
           [(memq type '(lbracket lparen lbrace quote-lbracket at-lbracket
                         tilde-lbracket hash-lbrace dot-lparen dot-lbrace))
            (loop (+ i 1) angle-depth (+ other-depth 1))]
           [(and (memq type '(rbracket rparen rbrace)) (> other-depth 0))
            (loop (+ i 1) angle-depth (- other-depth 1))]
           ;; Hit the enclosing group's closer at depth 0 → no match
           [(and close-type (eq? type close-type) (= other-depth 0)) #f]
           [else (loop (+ i 1) angle-depth other-depth)])])))
  ;; Frames: (cons kind closer). kind ∈ {mixfix paren bracket brace angle};
  ;; a `(` directly inside mixfix opens a NESTED mixfix group (group-items'
  ;; lparen-in-mixfix leg), so operator suppression continues through it.
  (let loop ([i 0] [bd 0] [qd 0] [frames '()] [result rrb-empty])
    (if (>= i n)
        result
        (let* ([entry (rrb-get token-rrb i)]
               [type (set-first (token-entry-types entry))]
               [in-mixfix? (and (pair? frames) (eq? (car (car frames)) 'mixfix))])
          (define-values (new-bd new-frames)
            (cond
              [(eq? type 'dot-lparen)
               (values (+ bd 1) (cons (cons 'mixfix 'rparen) frames))]
              [(eq? type 'lparen)
               (values (+ bd 1)
                       (cons (cons (if in-mixfix? 'mixfix 'paren) 'rparen) frames))]
              [(memq type '(lbracket quote-lbracket at-lbracket tilde-lbracket))
               (values (+ bd 1) (cons (cons 'bracket 'rbracket) frames))]
              ;; D4.P1b-ii: dot-lbrace joins the BRACE family — kind 'brace,
              ;; closer 'rbrace (Q_M5). Kind 'brace (not 'mixfix) is what keeps
              ;; angle grouping ALIVE inside a `.{ }` block, which type-level
              ;; angle groups need. Omitting it here would leave bd
              ;; un-incremented while the matching `}` still pops — the
              ;; wrong-frame-pop half of the 31d27c83 class.
              [(memq type '(lbrace hash-lbrace dot-lbrace))
               (values (+ bd 1) (cons (cons 'brace 'rbrace) frames))]
              [(eq? type 'langle)
               ;; Operator inside mixfix; opener only when a matching `>`
               ;; exists in the enclosing scope (agrees with group-items).
               (if (or in-mixfix?
                       (not (langle-matched?
                             (+ i 1)
                             (and (pair? frames) (cdr (car frames))))))
                   (values bd frames)
                   (values (+ bd 1) (cons (cons 'angle 'rangle) frames)))]
              [(eq? type 'rangle)
               (if in-mixfix?
                   (values bd frames)  ;; operator inside mixfix
                   (if (> bd 0)
                       (values (- bd 1) (cdr frames))
                       (values 0 '())))]
              [(memq type '(rbracket rparen rbrace))
               (if (> bd 0)
                   (values (- bd 1) (cdr frames))
                   (values 0 '()))]
              [else (values bd frames)]))
          ;; qq-depth: backtick increments, comma in qq context decrements
          ;; (simplified — full qq handling in Phase 2/reader macros)
          (define new-qd qd)
          (loop (+ i 1) new-bd new-qd new-frames
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
  ;; Q_M4 (D4.P1b-i): the source bounds the top-level angle lookahead.
  (define bd-rrb (make-bracket-depth-rrb tok-rrb str))

  ;; Disambiguation cycle (≤2 rounds)
  (define-values (tok-rrb-final bd-rrb-final)
    (let round ([tok tok-rrb] [bd bd-rrb] [rounds 0])
      (if (>= rounds 2)
          (values tok bd)  ;; Max rounds reached
          (let-values ([(narrowed changed?) (disambiguate-tokens tok bd)])
            (if changed?
                ;; Recompute bracket-depth from narrowed tokens
                (let ([new-bd (make-bracket-depth-rrb narrowed str)])
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
      ;; #e prefix → exact (Numerics N1: exponent literals; idempotent for plain int/rat)
      [(number) (or (string->number (string-append "#e" lexeme)) (string->number lexeme) (string->symbol lexeme))]
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
      [(pipe) '$pipe]
      [(pipe-right) '$pipe-gt]
      [(facts-sep) '$facts-sep]
      [(clause-sep) '$clause-sep]
      ;; D4.P2: `dot-ordinal` is NOT in this list — it needs a NUMERIC payload,
      ;; not a prefix-stripped symbol, so it gets its own arm below. Reported
      ;; independently by FOUR adversarial lenses when it was missing: the token
      ;; fell to `[else (string->symbol lexeme)]` and yielded `|.10|` (dot
      ;; retained, payload symbolic), contradicting both the sibling contract
      ;; here and the numeric payload Q_R1 establishes. Not production-reachable
      ;; (this converter's only non-test consumer, tools/golden-capture.rkt,
      ;; reads token TYPES only) — fixed anyway, because a sibling-inconsistent
      ;; value in an exported API is how the next reader gets misled.
      [(dot-ordinal)
       (string->number (substring lexeme 1))]
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
    ;; Reject negative Nats (-3N)
    (when (and (eq? type 'nat-literal)
               (string-contains? lexeme "-"))
      (error 'tokenize-string "Negative Nat literal not allowed: ~a" lexeme))
    ;; (N6c) Reject stray ~ with a migration hint: `~N` approximate literals
    ;; were removed (`~[` LSeq is tokenized earlier and never reaches here).
    (when (and (eq? type 'symbol)
               (or (equal? lexeme "~")
                   (and (string-prefix? lexeme "~")
                        (> (string-length lexeme) 1)
                        (let ([c (string-ref lexeme 1)])
                          (or (char-numeric? c) (char=? c #\-))))))
      (error 'prologos-reader
             "`~~` approximate literals were removed — bare decimals are Posit32 (3.14); use pNN literals for other widths (3.14p16, or 3.14p for Posit64)"))
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
      ;; #e prefix → exact (Numerics N1: exponent literals; idempotent for plain int/rat)
      [(number) (or (string->number (string-append "#e" lexeme)) (string->number lexeme) (string->symbol lexeme))]
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
    ;; D4.P2 — `.N` ordinal access. THIS SITE IS THE ONE NO ENUMERATION HAD
    ;; NAMED, and a miss here is SILENT: a token type with no arm falls through
    ;; both `[else]`s (the inner `value` case yields `(string->symbol lexeme)`,
    ;; the outer wraps that symbol) — no raise, no diagnostic, just the bare
    ;; symbol `|.1|`. §Q8.5 invariant 3 now carries it as token-layer site (f).
    ;;
    ;; ⚠ `string->number`, NOT the siblings' `string->symbol`. A NUMERIC payload
    ;; is what makes `v.0` byte-identical to `v[0]`'s datum, and that identity is
    ;; the whole content of owner ruling Q_R1 ("two SURFACES over ONE
    ;; mechanism") — with a symbolic payload the reuse would silently mint
    ;; `(map-get x :10)`: the wrong node (map-get has no PVec leg) with the
    ;; wrong key domain. The recognizer's ASCII-digit gate is what guarantees
    ;; this conversion cannot return `#f`.
    [(dot-ordinal)
     (define n (string->number (substring lexeme 1)))
     (make-stx (list (make-stx '$postfix-index source line col pos1 0)
                     (make-stx n source line (+ col 1) (+ pos1 1) (- span 1)))
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
    ;; Slash-containing number lexeme (e.g. 0/1, 1/2, -3/7) → ($rat-literal n).
    ;; A user-written `0/1` IS a Rat literal even when string->number simplifies
    ;; the value to the integer 0; the `/` is a load-bearing source token. The
    ;; sentinel preserves Rat-ness through the parse pipeline so downstream
    ;; typing sees `0/1` as Rat, not as Int.
    [(number)
     (cond
       [(string-contains? lexeme "/")
        (make-stx (list (make-stx '$rat-literal source line col pos1 0)
                        (make-stx value source line col pos1 span))
                  source line col pos1 span)]
       ;; N6b: NON-INTEGRAL exponent lexeme (1.5e-3) → ($exp-literal n). The
       ;; exp-literal token identity is erased at tokenize (its classifier
       ;; returns 'number), so like the `/` case above the LEXEME is the only
       ;; carrier of notation origin. Integral exponents (1e10) stay bare —
       ;; they parse as exact integers → Int (structural; D8-consistent).
       [(and (exact? value) (not (integer? value))
             (or (string-contains? lexeme "e") (string-contains? lexeme "E")))
        (make-stx (list (make-stx '$exp-literal source line col pos1 0)
                        (make-stx value source line col pos1 span))
                  source line col pos1 span)]
       [else (make-stx value source line col pos1 span)])]
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

;; The mixfix entry form `.( )` (mixfix-rparen) suppresses angle-bracket
;; grouping so `<`/`>` read as operators inside mixfix. (`.{ }`/mixfix-rbrace
;; retired — CIU T6 Path Selection P1.) The form-extent scanner
;; (make-bracket-depth-rrb) applies the same suppression via its frame stack —
;; the two layers must agree or operator-`<` inside `.( )` mis-extends the
;; form across lines (fixed 2026-07-26; legacy flatten-tokens/group-tokens
;; pair deleted then — dead since group-items superseded them).
(define (mixfix-close? ct)
  (eq? ct 'mixfix-rparen))

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
;;
;; Some forms need their indent-grouped continuation lines to be SPLICED
;; into the parent token stream rather than wrapped as sub-lists, so that
;; binding/arrow markers placed on continuation lines remain at the top
;; level where the elaborator and preparser can find them. See:
;;   - `flatten-with-boundaries/spec`: splices type-signature continuations
;;     so `->` on its own line is visible to `decompose-spec-type`.
;;   - `flatten-with-boundaries/def`: splices ONLY continuations whose first
;;     token is `:=`, so `def name : T\n  := body` is read identically to
;;     `def name : T := body`.
(define (tree-node->stx-elements node source source-str)
  (define items
    (cond
      [(spec-form-node? node) (flatten-with-boundaries/spec node)]
      [(def-form-node? node)  (flatten-with-boundaries/def  node)]
      [else (flatten-with-boundaries node)]))
  (define vec (list->vector items))
  (define-values (elems _end)
    (group-items vec 0 (vector-length vec) #f source source-str))
  (transform-let-blocks-elems elems))

;; ============================================================
;; LET P3 (2026-07-31): aligned let blocks — the column discipline.
;; ============================================================
;;
;;     let x 4              The continuation BINDING lines share one column;
;;         y 5              the BODY sits strictly between the `let` column
;;         z [+ x y]        and the binding column. STRICT (owner ruling 1):
;;       [+ a z]            anything else is a guided per-command error
;;                          naming the columns.
;;
;; This is the ONE layer that can implement the discipline: every element here
;; — bare token or wrapped line-group — still carries line/column, while
;; preparse strips srclocs (`syntax->datum`) before `expand-let` dispatches,
;; and binding groups vs a body application are SHAPE-IDENTICAL without
;; columns (`(z (+ x y))` vs `(+ a z)`). The `&>` clause-group machinery is
;; the precedent (Rel T1 POL.8).
;;
;; ACTIVATION is deliberately narrow — the transform is IDENTITY unless:
;;   - the group heads with the identifier `let` followed by BARE binding
;;     tokens (bracket-binding heads excluded), and
;;   - there are ≥2 continuation LINES, and
;;   - none is `$pipe`-headed (STRUCTURAL, not heuristic: `|` is reserved arm
;;     syntax and never a binding, so the working `let x := v` + `match x` +
;;     `| arm` body shape can never be captured), and
;;   - the elements carry real line/col (synthesized stx deactivates), and
;;   - EITHER the aligned body signature is present (last continuation
;;     strictly between the let and binding columns) OR every continuation
;;     shares the binding column (the forgot-the-body shape, which today
;;     value-swallows into junk — it gets the guided no-body error instead).
;;
;; On success the group is rewritten to
;;     (let ($let-block (head-binding) (b1 …) (b2 …)) body)
;; — head `let` retained so preparse's existing dispatch reaches expand-let,
;; which normalizes the groups onto the single parse-assign-bindings funnel.
;; On violation the group becomes P1's ($let-error "…") marker: a per-command
;; guided error with the columns named, and the file continues.

(define (let-block-pipe-headed? e)
  (define d (syntax-e e))
  (or (and (symbol? d) (eq? d '$pipe))
      (and (pair? d)
           (let ([h (syntax-e (car d))])
             (and (symbol? h) (eq? h '$pipe))))))

(define (let-block-error stx msg)
  (datum->syntax #f (list (datum->syntax #f '$let-error stx)
                          (datum->syntax #f msg stx))
                 stx))

;; The recursive walk: bottom-up (a nested let inside a binding value is
;; transformed before its parent is classified). `classify` runs on
;; already-recursed element lists; the two entry points share it.
(define (let-headed? elems)
  (and (pair? elems)
       (let ([h (syntax-e (car elems))]) (and (symbol? h) (eq? h 'let)))))

;; ⚠ EQ?-PRESERVING BY CONSTRUCTION (caught by the P3 gate, acceptance
;; [27]/[28]): the first draft rebuilt EVERY stx-list via
;; `(datum->syntax #f kids stx)`, which copies the srcloc but DROPS SYNTAX
;; PROPERTIES — including POL.9's 'prologos-paren-origin mark, so an
;; implicit-solve paren goal `(quest t "Alice" r)` silently degraded to an
;; APPLICATION. A form the walk does not change now keeps its ORIGINAL stx
;; (identity, properties, everything); a rebuilt form passes the original as
;; BOTH the srcloc and the property template (datum->syntax's 4th argument).
(define (transform-let-blocks-stx stx)
  (define lst (syntax->list stx))
  (if (not lst)
      stx
      (let* ([kids (map transform-let-blocks-stx lst)]
             [kids* (if (let-headed? kids) (classify-let-block kids) kids)])
        (if (and (eq? kids* kids) (andmap eq? kids lst))
            stx
            (datum->syntax #f kids* stx stx)))))

;; Entry point for a top-level form's element list (tree-node->stx-elements).
(define (transform-let-blocks-elems elems)
  (define elems* (map transform-let-blocks-stx elems))
  (if (let-headed? elems*) (classify-let-block elems*) elems*))

;; Classify a let-headed element list; return the (possibly rewritten) list.
(define (classify-let-block elems)
  (define let-tok (car elems))
  (define let-line (syntax-line let-tok))
  (define let-col (syntax-column let-tok))
  (define rest (cdr elems))
  (define (loc-ok? e) (and (syntax-line e) (syntax-column e)))
  (cond
    [(or (not let-line) (not let-col) (not (andmap loc-ok? rest))) elems]
    [else
     (define head-elems (filter (lambda (e) (= (syntax-line e) let-line)) rest))
     (define cont-elems (filter (lambda (e) (> (syntax-line e) let-line)) rest))
     (cond
       ;; 0/1 continuation lines: every working form (single-line lets, the
       ;; nested shorthand, bracket lets with one body line, sibling := chains)
       ;; — untouched, byte-transparent.
       [(< (length cont-elems) 2) elems]
       ;; pipe-headed continuation: a match/arm body — never bindings.
       [(ormap let-block-pipe-headed? cont-elems) elems]
       ;; bracket-binding head (car of head-elems is a group) or empty head:
       ;; not the aligned surface.
       [(or (null? head-elems) (pair? (syntax-e (car head-elems)))) elems]
       [else
        (define bcol (syntax-column (car cont-elems)))
        (define body-cands
          (filter (lambda (e) (and (> (syntax-column e) let-col)
                                   (< (syntax-column e) bcol)))
                  cont-elems))
        (define binding-lines
          (filter (lambda (e) (= (syntax-column e) bcol)) cont-elems))
        (define stray
          (filter (lambda (e) (and (not (memq e body-cands))
                                   (not (memq e binding-lines))))
                  cont-elems))
        (define (fail msg) (let-block-error let-tok msg))
        (cond
          ;; No body signature AND no strays: the forgot-the-body shape.
          [(and (null? body-cands) (null? stray))
           (fail (format
                  "let block has no body — expected a line indented between column ~a (the `let`) and column ~a (the bindings)"
                  let-col bcol))]
          [(pair? stray)
           (fail (format
                  "let block mis-indent at column ~a — bindings align at column ~a; the body sits strictly between column ~a (the `let`) and column ~a"
                  (syntax-column (car stray)) bcol let-col bcol))]
          [(> (length body-cands) 1)
           (fail (format
                  "let block has ~a body lines at columns between ~a and ~a — exactly one body line is allowed"
                  (length body-cands) let-col bcol))]
          [(not (eq? (car body-cands) (last cont-elems)))
           (fail (format
                  "let block bindings appear AFTER the body line — the body (column between ~a and ~a) must be last"
                  let-col bcol))]
          [(ormap (lambda (e) (not (pair? (syntax-e e)))) binding-lines)
           (fail (format
                  "let block binding line at column ~a needs a name and a value (e.g. `y 5` or `y := 5`)"
                  bcol))]
          [else
           (define body (car body-cands))
           (define groups
             (cons (datum->syntax #f head-elems let-tok)  ;; the head-line binding
                   binding-lines))
           (list let-tok
                 (datum->syntax #f (cons (datum->syntax #f '$let-block let-tok)
                                         groups)
                                let-tok)
                 body)])])]))

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

;; Recognize a parse-tree-node whose first token is `def` or `def-`.
;; Used by `tree-node->stx-elements` to apply the def-specific splice
;; rule. Mirrors `spec-form-node?`: the node's tag may not yet be
;; refined to `'def` (the private `def-` variant is registered as a
;; preparser keyword but has no tag rule), so we look at the first
;; child token directly.
(define (def-form-node? node)
  (and (parse-tree-node? node)
       (let ([children (parse-tree-node-children node)])
         (and (> (rrb-size children) 0)
              (let ([first (rrb-get children 0)])
                (and (token-entry? first)
                     (let ([lex (token-entry-lexeme first)])
                       (or (equal? lex "def")
                           (equal? lex "def-")))))))))

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

;; Flatten variant for `def`/`def-` forms: top-level child lines are
;; SPLICED into the parent token stream ONLY when the line begins with
;; the binding marker `:=`. This makes
;;     def name : T
;;       := body
;; read identically to
;;     def name : T := body
;; so `expand-def-assign` (which only scans the top level for `:=`)
;; picks up the assignment.
;;
;; All other continuation lines (a bare body expression, a continued
;; bracketed application, etc.) remain wrapped as sub-lists, preserving
;; the existing semantics where
;;     def name
;;       + 1 2
;; reads as `(def name (+ 1 2))` with the body grouped as one
;; application. This is intentionally narrower than the spec splice
;; rule: spec needs to expose `->` from anywhere in a multi-line type
;; signature, while def only needs to expose `:=` (which is always the
;; head of its continuation when line-broken in the natural way).
(define (flatten-with-boundaries/def node)
  (define children (parse-tree-node-children node))
  (define n (rrb-size children))
  (apply append
    (for/list ([i (in-range n)])
      (define child (rrb-get children i))
      (cond
        [(token-entry? child) (list child)]
        [(parse-tree-node? child)
         (define inner (flatten-with-boundaries child))
         (if (continuation-starts-with-assign? inner)
             ;; `:= body` continuation — splice tokens directly so `:=`
             ;; appears at the top level of the def form.
             inner
             ;; Other continuation (bare body, application chain,
             ;; etc.): keep wrapped as a sub-list.
             (append (list 'indent-open) inner (list 'indent-close)))]
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

;; Does this flattened token list start with the assignment token `:=`?
;; Used by `flatten-with-boundaries/def` to identify continuations that
;; should be spliced into the def's top-level token stream.
(define (continuation-starts-with-assign? items)
  (let loop ([items items])
    (cond
      [(null? items) #f]
      [(eq? (car items) 'indent-open) (loop (cdr items))]
      [(token-entry? (car items))
       (equal? (token-entry-lexeme (car items)) ":=")]
      [else #f])))

;; Lookahead: check if there's a matching rangle before the current scope closes.
;; Scans forward tracking nesting depth for <> pairs.
(define (has-matching-rangle? vec start end close-type [src #f])
  ;; Scan forward for matching rangle, tracking ALL bracket depths.
  ;; Skip over nested [...], (...), {...} groups entirely.
  ;; Q_M4 (D4.P1b-i): the langle-matched? twin — same top-level bound, or a
  ;; `<` matches a `>` in a later top-level form. The bracket-depth pin
  ;; passing while the DATUM layer still collapsed is what proved this twin
  ;; also needs it (the 31d27c83 "layers must agree" lesson).
  (define langle-pos
    (and src (not close-type) (> start 0)
         (let ([prev (vector-ref vec (- start 1))])
           (and (token-entry? prev) (token-entry-start-pos prev)))))
  (let loop ([i start] [angle-depth 0] [other-depth 0])
    (cond
      [(>= i end) #f]
      [else
       (define item (vector-ref vec i))
       (cond
         [(and langle-pos (token-entry? item)
               (token-starts-new-form? src langle-pos (token-entry-start-pos item)))
          #f]
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
            ;; Twin of langle-matched?'s opener set — keep IDENTICAL (31d27c83).
            [(memq type '(lbracket lparen lbrace quote-lbracket at-lbracket
                          tilde-lbracket hash-lbrace dot-lparen dot-lbrace))
             (loop (+ i 1) angle-depth (+ other-depth 1))]
            [(and (memq type '(rbracket rparen rbrace)) (> other-depth 0))
             (loop (+ i 1) angle-depth (- other-depth 1))]
            ;; Hit the current scope's closer at depth 0 → no match
            [(and close-type (not (eq? close-type 'indent-close))
                  (or (eq? type close-type)
                      (and (eq? close-type 'mixfix-rparen) (eq? type 'rparen)))
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
;; ── D4.P1b-iii: THE adjacency test, hoisted ──────────────────────────────────
;; Was inlined in the bracket arm as `is-postfix?`. Hoisted so the bracket arm
;; and the brace arm consume ONE definition rather than two copies that drift.
;;
;; ⚠ It is NOT enough to add `lbrace` to the bracket arm's `memq`: that arm's
;; closer is a two-way `(if (eq? type 'lbracket) 'rbracket 'rparen)`, so a brace
;; joining it would be handed `'rparen`. That is the identical "a two-way if
;; cannot express three token types" shape D4.P1b-ii hit in surface-rewrite.rkt.
;;
;; `(pair? result)` means THE CURRENT GROUP HAS ALREADY EMITTED A BASE. `result`
;; is the per-group accumulator, seeded '() at every recursive entry, so it is
;; false exactly when the opener is the FIRST item inside its group. That is the
;; only thing distinguishing `xs{…}` (select off xs) from `'[{…}` / `@[{…}`
;; (a map literal that merely happens to be byte-adjacent to its opener) — ~28
;; live sites. Drop it and every list-of-maps literal mis-reads its FIRST
;; element only, at zero errors.
;;
;; `(> i 0)` is redundant while `(pair? result)` holds (a non-empty accumulator
;; implies the loop advanced), and becomes load-bearing only if that conjunct is
;; ever removed — it also guards the `(- i 1)` index below.
(define (adjacent-to-base? vec i result item)
  (and (pair? result)
       (> i 0)
       (let ([prev-item (vector-ref vec (- i 1))])
         (and (token-entry? prev-item)
              (= (token-entry-end-pos prev-item)
                 (token-entry-start-pos item))))))

;; Is the physically preceding token a READER-FORM HEAD (`racket{…}`)? Consults
;; the ONE registry (reader-forms.rkt) — never an inline literal.
(define (prev-token-reader-form-head? vec i)
  (and (> i 0)
       (let ([prev (vector-ref vec (- i 1))])
         (and (token-entry? prev)
              (reader-form-head? (string->symbol (token-entry-lexeme prev)))))))

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
                      (and (eq? close-type 'mixfix-rparen) (eq? type 'rparen))))
             (values (reverse result) (+ i 1))]
            ;; Mixfix `.( )` grouping: inside .( ), a bare ( E ) is an infix
            ;; grouping → nested $mixfix (reuses nested-mixfix re-expansion, like
            ;; the old nested .{ }). `[ ]` stays a plain function-application list.
            [(and (eq? type 'lparen) (eq? close-type 'mixfix-rparen))
             (let-values ([(inner next-i) (group-items vec (+ i 1) end 'mixfix-rparen source source-str qq-depth)])
               (let-values ([(ml mc) (pos->line-col source-str (token-entry-start-pos item))])
                 (loop next-i
                       (cons (make-stx (cons (make-stx '$mixfix source ml mc (+ (token-entry-start-pos item) 1) 1) inner)
                                       source ml mc (+ (token-entry-start-pos item) 1) 1) result))))]
            ;; Square/round brackets — check for postfix index (xs[0] with no space)
            [(memq type '(lbracket lparen))
             (define is-postfix?
               (and (eq? type 'lbracket)
                    (adjacent-to-base? vec i result item)))
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
                   ;; Normal bracket group.
                   ;; Rel T1 POL.9: PAREN groups carry a syntax property so the
                   ;; parser can give command-position paren groups goal-ness
                   ;; (design §8 POL.9: parens make a relational goal; brackets
                   ;; stay application). Property-only — datum shape unchanged,
                   ;; invisible to every existing match arm; the sexp reader
                   ;; (native (…) reading) never attaches it, so sexp
                   ;; application is untouched by construction.
                   (let ([grp (wrap-stx-list inner source)])
                     (loop next-i
                           (cons (if (eq? type 'lparen)
                                     (syntax-property grp 'prologos-paren-origin #t)
                                     grp)
                                 result)))))]
            ;; Angle brackets → $angle-type sentinel IF matching rangle exists
            ;; AND we're not inside a mixfix group (where < > are operators)
            [(eq? type 'langle)
             (if (and (not (mixfix-close? close-type))
                      (has-matching-rangle? vec (+ i 1) end close-type source-str))
                 (let-values ([(inner next-i) (group-items vec (+ i 1) end 'rangle source source-str qq-depth)])
                   (let-values ([(al ac) (pos->line-col source-str (token-entry-start-pos item))])
                     (loop next-i
                           (cons (make-stx (cons (make-stx '$angle-type source al ac (+ (token-entry-start-pos item) 1) 1) inner)
                                           source al ac (+ (token-entry-start-pos item) 1) 1) result))))
                 ;; No matching > → treat < as operator
                 (loop (+ i 1) (cons (token-entry->stx item source source-str) result)))]
            ;; Braces → $brace-params (spaced / reader-form head) or $select-brace
            ;; (adjacent). D4.P1b-iii: THE adjacency fork.
            ;;
            ;; Order is load-bearing (Q8.2's grouping table): HEAD PRECEDENCE is
            ;; checked FIRST, so `racket{…}` stays a foreign block rather than
            ;; becoming a selection off a variable named `racket`. Spaced braces
            ;; are never select blocks — 419 of 622 live spaced braces are
            ;; implicit type binders, and `combine-foreign-blocks` accepts the
            ;; spaced `racket {…}` too, so both head spellings keep the old
            ;; sentinel UNCHANGED.
            ;;
            ;; `adjacent-to-base?` carries the `(pair? result)` conjunct, which
            ;; is the ONLY thing keeping opener-adjacent braces (`'[{…}`,
            ;; `@[{…}` — ~28 live sites) out of the select reading.
            [(eq? type 'lbrace)
             (define adjacent? (adjacent-to-base? vec i result item))
             (define head-form? (and adjacent? (prev-token-reader-form-head? vec i)))
             (define sentinel (if (and adjacent? (not head-form?)) '$select-brace '$brace-params))
             (let-values ([(inner next-i) (group-items vec (+ i 1) end 'rbrace source source-str qq-depth)])
               (let-values ([(bl bc) (pos->line-col source-str (token-entry-start-pos item))])
                 (loop next-i
                       (cons (make-stx (cons (make-stx sentinel source bl bc (+ (token-entry-start-pos item) 1) 1) inner)
                                       source bl bc (+ (token-entry-start-pos item) 1) 1) result))))]
            ;; D4.P1b-ii — Dot-brace → $dot-brace sentinel, PLAIN 'rbrace closer.
            ;; The mid-path sub-block `server^.{ssl port}`. Ruling Q_N1 mints a
            ;; DISTINCT sentinel rather than reusing $brace-params: that head
            ;; means IMPLICIT TYPE BINDER to a large consumer surface (driver
            ;; capability extraction, form-cells, ~30 library sites), and the
            ;; only signal that distinguishes `x.{a}` from `x{a}` today is the
            ;; loose `.` token — which THIS token fold destroys. Reuse would be
            ;; a one-way loss, and srcloc cannot recover it (every group in a
            ;; form shares the enclosing node's srcloc).
            ;; Span is 2 (a two-char token), matching hash-lbrace.
            [(eq? type 'dot-lbrace)
             (let-values ([(inner next-i) (group-items vec (+ i 1) end 'rbrace source source-str qq-depth)])
               (let-values ([(dl dc) (pos->line-col source-str (token-entry-start-pos item))])
                 (loop next-i
                       (cons (make-stx (cons (make-stx '$dot-brace source dl dc (+ (token-entry-start-pos item) 1) 2) inner)
                                       source dl dc (+ (token-entry-start-pos item) 1) 2) result))))]
            ;; Dot-paren → $mixfix sentinel with 'mixfix-rparen (closes on `)`,
            ;; enables `( )` grouping inside — the mixfix ergonomics form).
            [(eq? type 'dot-lparen)
             (let-values ([(inner next-i) (group-items vec (+ i 1) end 'mixfix-rparen source source-str qq-depth)])
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
            ;; (N6c) approx-literal compound-token arm removed (~N deprecated)
            ;; Posit-literal compound token (Numerics N6b): 3.14p16 → ($posit-literal 157/50 16)
            [(eq? type 'posit-literal)
             (define lex (token-entry-lexeme item))
             (define len (string-length lex))
             (define lc (string-ref lex (- len 1)))
             (define-values (num-str width)
               (cond
                 [(and (>= len 3) (char=? lc #\6)
                       (char=? (string-ref lex (- len 2)) #\1)
                       (char=? (string-ref lex (- len 3)) #\p))
                  (values (substring lex 0 (- len 3)) 16)]
                 [(and (>= len 3) (char=? lc #\2)
                       (char=? (string-ref lex (- len 2)) #\3)
                       (char=? (string-ref lex (- len 3)) #\p))
                  (values (substring lex 0 (- len 3)) 32)]
                 [(and (>= len 3) (char=? lc #\4)
                       (char=? (string-ref lex (- len 2)) #\6)
                       (char=? (string-ref lex (- len 3)) #\p))
                  (values (substring lex 0 (- len 3)) 64)]
                 [(and (>= len 2) (char=? lc #\8)
                       (char=? (string-ref lex (- len 2)) #\p))
                  (values (substring lex 0 (- len 2)) 8)]
                 [(char=? lc #\p)  ;; bare `p` → Posit64 (mirrors bare `f` = Float64)
                  (values (substring lex 0 (- len 1)) 64)]
                 [else (values lex 32)]))  ;; unreachable: recognizer emits p8/16/32/64/bare-p
             ;; exact rational like decimal/approx; posit encoding at elaborate
             (define num-val (or (string->number (string-append "#e" num-str))
                                 (string->number num-str)
                                 (string->symbol num-str)))
             (define spos (token-entry-start-pos item))
             (define epos (token-entry-end-pos item))
             (define-values (vl vc) (pos->line-col source-str spos))
             (loop (+ i 1)
                   (cons (make-stx (list (make-stx '$posit-literal source vl vc (+ spos 1) 1)
                                         (make-stx num-val source vl vc spos (- epos spos))
                                         (make-stx width source vl vc spos (- epos spos)))
                                   source vl vc spos (- epos spos))
                         result))]
            ;; Float-literal compound token (Numerics N3c): 3.14f → ($float-literal 157/50 64)
            [(eq? type 'float-literal)
             (define lex (token-entry-lexeme item))
             (define len (string-length lex))
             (define lc (string-ref lex (- len 1)))
             (define-values (num-str width)
               (cond
                 [(and (>= len 3) (char=? lc #\2)
                       (char=? (string-ref lex (- len 2)) #\3)
                       (char=? (string-ref lex (- len 3)) #\f))
                  (values (substring lex 0 (- len 3)) 32)]
                 [(and (>= len 3) (char=? lc #\4)
                       (char=? (string-ref lex (- len 2)) #\6)
                       (char=? (string-ref lex (- len 3)) #\f))
                  (values (substring lex 0 (- len 3)) 64)]
                 [(char=? lc #\f) (values (substring lex 0 (- len 1)) 64)]
                 [else (values lex 64)]))
             ;; exact rational (157/50) like decimal/approx; Float conversion at elaborate
             (define num-val (or (string->number (string-append "#e" num-str))
                                 (string->number num-str)
                                 (string->symbol num-str)))
             (define spos (token-entry-start-pos item))
             (define epos (token-entry-end-pos item))
             (define-values (vl vc) (pos->line-col source-str spos))
             (loop (+ i 1)
                   (cons (make-stx (list (make-stx '$float-literal source vl vc (+ spos 1) 1)
                                         (make-stx num-val source vl vc spos (- epos spos))
                                         (make-stx width source vl vc spos (- epos spos)))
                                   source vl vc spos (- epos spos))
                         result))]
            ;; (N6c) adjacent-tilde $approx-literal arm removed (~N deprecated;
            ;; a stray ~ symbol is rejected at tokenize-time with a migration hint)
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
