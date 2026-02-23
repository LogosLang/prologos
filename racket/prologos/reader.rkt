#lang racket/base

;;;
;;; PROLOGOS READER
;;; Custom reader with significant whitespace for #lang prologos.
;;;
;;; Converts indentation-sensitive syntax into S-expression syntax objects
;;; that feed directly into the existing parse-datum pipeline.
;;;
;;; Design rules:
;;;   1. No opening brackets — top-level forms don't start with [
;;;   2. New line, same level — tokens are siblings (arguments)
;;;   3. New line, deeper level — each child line becomes a sub-list
;;;   4. Same line with [] groupings — explicit grouping inline
;;;   5. [] for all grouping (code); () reserved for future tuples
;;;   6. {} for implicit type params; <> for type annotations
;;;   7. '[] for list literals (linked list)
;;;

(require racket/match
         racket/string)

(provide prologos-read
         prologos-read-syntax
         ;; For #:whole-body-readers? #t in syntax/module-reader:
         prologos-read-syntax-all
         ;; For testing:
         tokenize-string
         read-all-forms-string
         token-type
         token-value)

;; ========================================
;; Token structure
;; ========================================

(struct token (type value line col pos span) #:transparent)

;; ========================================
;; Tokenizer
;; ========================================

(struct tokenizer
  (port           ; input port
   source         ; source name (string or path)
   indent-stack   ; (mutable) list of column numbers
   bracket-depth  ; (mutable) nesting depth of () [] {}
   angle-depth    ; (mutable) nesting depth of <> (separate for >> disambiguation)
   pending        ; (mutable) list of pending tokens (for INDENT/DEDENT)
   line           ; (mutable) current line
   col            ; (mutable) current column
   pos            ; (mutable) current position
   at-line-start? ; (mutable) are we at the start of a line?
   )
  #:mutable
  #:transparent)

(define (make-tokenizer port source)
  (port-count-lines! port)
  (tokenizer port source
             (list 0)   ; indent-stack starts at column 0
             0           ; bracket-depth
             0           ; angle-depth
             '()         ; pending tokens
             1           ; line
             0           ; col
             1           ; pos
             #t))        ; at-line-start

;; --- Character reading with position tracking ---

(define (tok-peek tok)
  (peek-char (tokenizer-port tok)))

(define (tok-read! tok)
  (define c (read-char (tokenizer-port tok)))
  (unless (eof-object? c)
    (cond
      [(char=? c #\newline)
       (set-tokenizer-line! tok (+ 1 (tokenizer-line tok)))
       (set-tokenizer-col! tok 0)
       (set-tokenizer-pos! tok (+ 1 (tokenizer-pos tok)))]
      [else
       (set-tokenizer-col! tok (+ 1 (tokenizer-col tok)))
       (set-tokenizer-pos! tok (+ 1 (tokenizer-pos tok)))]))
  c)

;; --- Helper predicates ---

(define (ident-start? c)
  (and (char? c)
       (or (char-alphabetic? c)
           (char=? c #\_)
           (char=? c #\-)    ; for ->
           (char=? c #\+)    ; operator symbols (foreign interop)
           (char=? c #\*)    ; product type and operator
           (char=? c #\/)    ; division operator
           (char=? c #\=)    ; equality operator
           (char=? c #\$)))) ; pattern variable prefix ($x in defmacro)

(define (ident-continue? c)
  (and (char? c)
       (or (char-alphabetic? c)
           (char-numeric? c)
           (char=? c #\_)
           (char=? c #\-)
           (char=? c #\?)
           (char=? c #\!)
           (char=? c #\*)
           (char=? c #\+)    ; for p8+ etc.
           (char=? c #\')
           (char=? c #\/)    ; qualified names
           (char=? c #\=)    ; for => and similar
           (char=? c #\$)))) ; for $-prefixed identifiers

(define (delimiter? c)
  (and (char? c)
       (or (char-whitespace? c)
           (char=? c #\()
           (char=? c #\))
           (char=? c #\[)
           (char=? c #\])
           (char=? c #\{)
           (char=? c #\})
           (char=? c #\<)
           (char=? c #\>)
           (char=? c #\;))))

;; --- Skip whitespace (not newlines) on the current line ---

(define (skip-inline-whitespace! tok)
  (let loop ()
    (define c (tok-peek tok))
    (when (and (char? c)
               (char-whitespace? c)
               (not (char=? c #\newline)))
      (tok-read! tok)
      (loop))))

;; --- Skip comment (from ; to end of line) ---

(define (skip-comment! tok)
  (let loop ()
    (define c (tok-peek tok))
    (when (and (char? c) (not (char=? c #\newline)))
      (tok-read! tok)
      (loop))))

;; --- Process line-start indentation ---
;; Returns: number of leading spaces, or #f if blank/comment-only line

(define (count-leading-spaces! tok)
  (let loop ([spaces 0])
    (define c (tok-peek tok))
    (cond
      [(eof-object? c)
       spaces]
      [(char=? c #\space)
       (tok-read! tok)
       (loop (+ spaces 1))]
      [(char=? c #\tab)
       (error 'prologos-reader
              "~a:~a: Use spaces for indentation, not tabs"
              (tokenizer-source tok) (tokenizer-line tok))]
      [(char=? c #\newline)
       ;; Blank line — skip it and try next line
       (tok-read! tok)
       #f]
      [(char=? c #\;)
       ;; Comment-only line — skip comment and newline, try next
       (skip-comment! tok)
       (define next (tok-peek tok))
       (when (and (char? next) (char=? next #\newline))
         (tok-read! tok))
       #f]
      [else
       spaces])))

;; Generate INDENT/DEDENT/NEWLINE tokens based on indentation level

(define (process-indentation! tok col)
  (define stack (tokenizer-indent-stack tok))
  (define top (car stack))
  (define ln (tokenizer-line tok))
  (cond
    [(> col top)
     ;; INDENT
     (set-tokenizer-indent-stack! tok (cons col stack))
     (list (token 'indent #f ln col (tokenizer-pos tok) 0))]
    [(= col top)
     ;; Same level — NEWLINE (used to separate top-level forms)
     (list (token 'newline #f ln col (tokenizer-pos tok) 0))]
    [else
     ;; DEDENT — pop stack until we find a match
     (let loop ([stk stack] [dedents '()])
       (cond
         [(null? stk)
          (error 'prologos-reader
                 "~a:~a: Indentation level ~a does not match any outer block"
                 (tokenizer-source tok) ln col)]
         [(= col (car stk))
          (set-tokenizer-indent-stack! tok stk)
          (append dedents
                  (list (token 'newline #f ln col (tokenizer-pos tok) 0)))]
         [(< col (car stk))
          (loop (cdr stk)
                (append dedents
                        (list (token 'dedent #f ln col (tokenizer-pos tok) 0))))]
         [else
          (error 'prologos-reader
                 "~a:~a: Indentation level ~a does not match any outer block"
                 (tokenizer-source tok) ln col)]))]))

(define (tokenizer-next! tok)
  (let/ec return
    (define (return-token t) (return t))

    ;; Check pending tokens first
    (when (pair? (tokenizer-pending tok))
      (define t (car (tokenizer-pending tok)))
      (set-tokenizer-pending! tok (cdr (tokenizer-pending tok)))
      (return-token t))

    ;; At line start? Process indentation (only when not inside brackets)
    (when (tokenizer-at-line-start? tok)
      (set-tokenizer-at-line-start?! tok #f)
      (when (= 0 (tokenizer-bracket-depth tok))
        ;; Count leading spaces, skipping blank/comment-only lines
        (let loop ()
          (define spaces (count-leading-spaces! tok))
          (cond
            [(not spaces) ; blank or comment-only line
             (loop)]
            [else
             (when (eof-object? (tok-peek tok))
               ;; EOF after blank lines — just fall through to EOF handling below
               (void))
             (unless (eof-object? (tok-peek tok))
               (define indent-tokens (process-indentation! tok spaces))
               (when (pair? (cdr indent-tokens))
                 (set-tokenizer-pending! tok
                                        (append (cdr indent-tokens) (tokenizer-pending tok))))
               (return-token (car indent-tokens)))]))))

    ;; Skip inline whitespace
    (skip-inline-whitespace! tok)

    (define c (tok-peek tok))
    (define ln (tokenizer-line tok))
    (define cl (tokenizer-col tok))
    (define ps (tokenizer-pos tok))

    (cond
      ;; EOF
      [(eof-object? c)
       (define stack (tokenizer-indent-stack tok))
       (if (and (pair? stack) (pair? (cdr stack)))
           (begin
             (set-tokenizer-indent-stack! tok (cdr stack))
             (token 'dedent #f ln cl ps 0))
           (token 'eof #f ln cl ps 0))]

      ;; Newline
      [(char=? c #\newline)
       (tok-read! tok)
       (if (> (tokenizer-bracket-depth tok) 0)
           (tokenizer-next! tok)
           (begin
             (set-tokenizer-at-line-start?! tok #t)
             (tokenizer-next! tok)))]

      ;; Comment
      [(char=? c #\;)
       (skip-comment! tok)
       (tokenizer-next! tok)]

      ;; Parentheses — type grouping
      [(char=? c #\()
       (tok-read! tok)
       (set-tokenizer-bracket-depth! tok (+ 1 (tokenizer-bracket-depth tok)))
       (token 'lparen #f ln cl ps 1)]

      [(char=? c #\))
       (tok-read! tok)
       (define depth (tokenizer-bracket-depth tok))
       (when (= depth 0)
         (error 'prologos-reader "~a:~a:~a: Unexpected closing paren"
                (tokenizer-source tok) ln (+ cl 1)))
       (set-tokenizer-bracket-depth! tok (- depth 1))
       (token 'rparen #f ln cl ps 1)]

      ;; Square brackets — primary grouping delimiter
      [(char=? c #\[)
       (tok-read! tok)
       (set-tokenizer-bracket-depth! tok (+ 1 (tokenizer-bracket-depth tok)))
       (token 'lbracket #f ln cl ps 1)]

      [(char=? c #\])
       (tok-read! tok)
       (define depth (tokenizer-bracket-depth tok))
       (when (= depth 0)
         (error 'prologos-reader "~a:~a:~a: Unexpected closing bracket"
                (tokenizer-source tok) ln (+ cl 1)))
       (set-tokenizer-bracket-depth! tok (- depth 1))
       (token 'rbracket #f ln cl ps 1)]

      ;; Braces — reserved for EDN
      [(char=? c #\{)
       (tok-read! tok)
       (set-tokenizer-bracket-depth! tok (+ 1 (tokenizer-bracket-depth tok)))
       (token 'lbrace #f ln cl ps 1)]

      [(char=? c #\})
       (tok-read! tok)
       (define depth (tokenizer-bracket-depth tok))
       (when (= depth 0)
         (error 'prologos-reader "~a:~a:~a: Unexpected closing brace"
                (tokenizer-source tok) ln (+ cl 1)))
       (set-tokenizer-bracket-depth! tok (- depth 1))
       (token 'rbrace #f ln cl ps 1)]

      ;; Comma — parameter separator (stripped by bracket parsing)
      [(char=? c #\,)
       (tok-read! tok)
       (token 'comma #f ln cl ps 1)]

      ;; Angle brackets — type annotations
      [(char=? c #\<)
       (tok-read! tok)
       (set-tokenizer-bracket-depth! tok (+ 1 (tokenizer-bracket-depth tok)))
       (set-tokenizer-angle-depth! tok (+ 1 (tokenizer-angle-depth tok)))
       (token 'langle #f ln cl ps 1)]

      [(char=? c #\>)
       (tok-read! tok)
       (define adepth (tokenizer-angle-depth tok))
       (cond
         ;; Inside angle brackets: close the angle bracket
         [(> adepth 0)
          (set-tokenizer-bracket-depth! tok (- (tokenizer-bracket-depth tok) 1))
          (set-tokenizer-angle-depth! tok (- adepth 1))
          (token 'rangle #f ln cl ps 1)]
         ;; Outside angle brackets: check for >> compose operator
         [(and (char? (tok-peek tok)) (char=? (tok-peek tok) #\>))
          (tok-read! tok)  ; consume second >
          (token 'symbol '$compose ln cl ps 2)]
         [else
          (error 'prologos-reader "~a:~a:~a: Unexpected >"
                 (tokenizer-source tok) ln (+ cl 1))])]

      ;; NOTE: Dollar ($) is now handled as an identifier prefix via ident-start?
      ;; $foo reads as the symbol $foo (used for defmacro pattern variables).

      ;; Single quote — list literal '[ ... ] or quote operator 'expr
      [(char=? c #\')
       (tok-read! tok)
       (define next (tok-peek tok))
       (cond
         [(and (char? next) (char=? next #\[))
          ;; '[ — list literal opener; [ will be consumed by parse-list-literal-form
          (token 'quote-lbracket #f ln cl ps 1)]
         [else
          ;; 'expr — quote operator; expr will be parsed by parse-inline-element
          (token 'quote #f ln cl ps 1)])]

      ;; At-sign — PVec literal @[ ... ]
      [(char=? c #\@)
       (tok-read! tok)
       (define next (tok-peek tok))
       (cond
         [(and (char? next) (char=? next #\[))
          ;; @[ — PVec literal opener; [ will be consumed by parse-vec-literal-form
          (token 'at-lbracket #f ln cl ps 1)]
         [else
          (error 'prologos-reader
                 "~a:~a:~a: Unexpected @ — use @[...] for PVec literals"
                 (tokenizer-source tok) ln (+ cl 1))])]

      ;; Pipe — reduce arm separator, or |> pipe operator
      [(char=? c #\|)
       (tok-read! tok)
       (define next (tok-peek tok))
       (cond
         [(and (char? next) (char=? next #\>))
          (tok-read! tok)  ; consume >
          (token 'symbol '$pipe-gt ln cl ps 2)]
         [else
          (token 'symbol '$pipe ln cl ps 1)])]

      ;; Backtick — quasiquote operator `expr
      [(char=? c #\`)
       (tok-read! tok)
       (token 'backtick #f ln cl ps 1)]

      ;; Comma — unquote inside quasiquote, or ignored separator
      [(char=? c #\,)
       (tok-read! tok)
       (token 'comma #f ln cl ps 1)]

      ;; Colon
      [(char=? c #\:)
       (tok-read! tok)
       (define next (tok-peek tok))
       (cond
         ;; := assignment operator
         [(and (char? next) (char=? next #\=))
          (tok-read! tok)
          (token 'symbol ':= ln cl ps 2)]
         ;; :0, :1, :w — multiplicity annotations
         [(and (char? next) (or (char=? next #\0) (char=? next #\1) (char=? next #\w)))
          (define nc (tok-read! tok))
          (define after (tok-peek tok))
          (if (and (char? after) (ident-continue? after)
                   (not (char=? nc #\0)) (not (char=? nc #\1)))
              ;; :w followed by more chars → keyword like :widget
              (let ()
                (define rest (read-ident-rest! tok))
                (token 'keyword
                       (string->symbol (string-append ":" (string nc) rest))
                       ln cl ps (+ 2 (string-length rest))))
              ;; :0, :1, or :w standalone
              (token 'symbol
                     (string->symbol (string #\: nc))
                     ln cl ps 2))]
         ;; :keyword
         [(and (char? next) (char-alphabetic? next))
          (define rest (read-ident-chars! tok))
          (token 'keyword
                 (string->symbol (string-append ":" rest))
                 ln cl ps (+ 1 (string-length rest)))]
         ;; Freestanding colon
         [else
          (token 'colon #f ln cl ps 1)])]

      ;; String literal
      [(char=? c #\")
       (read-string-token! tok ln cl ps)]

      ;; Number
      [(char-numeric? c)
       (read-number-token! tok ln cl ps)]

      ;; Multiplied arrows: -0>, -1>, -w> (must check BEFORE -> since - triggers both)
      [(and (char=? c #\-)
            (let ([c2 (peek-char (tokenizer-port tok) 1)])
              (and (char? c2)
                   (or (char=? c2 #\0) (char=? c2 #\1) (char=? c2 #\w))
                   (let ([c3 (peek-char (tokenizer-port tok) 2)])
                     (and (char? c3) (char=? c3 #\>))))))
       (tok-read! tok)  ; consume -
       (define mc (tok-read! tok))  ; consume 0/1/w
       (tok-read! tok)  ; consume >
       (token 'symbol (string->symbol (string #\- mc #\>)) ln cl ps 3)]

      ;; -> arrow operator (must come before ident-start? since - is ident-start)
      [(and (char=? c #\-)
            (let ([c2 (peek-char (tokenizer-port tok) 1)])
              (and (char? c2) (char=? c2 #\>))))
       (tok-read! tok)  ; consume -
       (tok-read! tok)  ; consume >
       (token 'symbol '-> ln cl ps 2)]

      ;; Hash — Set literal #{...}
      [(char=? c #\#)
       (tok-read! tok)
       (define next (tok-peek tok))
       (cond
         [(and (char? next) (char=? next #\{))
          ;; #{ — Set literal opener; { will be consumed by parse-set-literal-form
          (token 'hash-lbrace #f ln cl ps 1)]
         [else
          (error 'prologos-reader
                 "~a:~a:~a: # must be followed by { for Set literal (#{...})"
                 (tokenizer-source tok) ln (+ cl 1))])]

      ;; Tilde — LSeq literal ~[ or approximate literal prefix ~42, ~3/7
      [(char=? c #\~)
       (tok-read! tok)
       (define next (tok-peek tok))
       (cond
         [(and (char? next) (char=? next #\[))
          ;; ~[ — LSeq literal opener; [ will be consumed by parse-lseq-literal-form
          (token 'tilde-lbracket #f ln cl ps 1)]
         [(and (char? next) (char-numeric? next))
          ;; ~N — read the number, produce ($approx-literal N) as a list
          (let ([num-tok (read-number-token! tok (tokenizer-line tok)
                                                 (tokenizer-col tok)
                                                 (tokenizer-pos tok))])
            (token 'approx-literal (token-value num-tok) ln cl ps
                   (+ 1 (token-span num-tok))))]
         [else
          (error 'prologos-reader
                 "~a:~a:~a: ~ must be followed by [ (LSeq literal) or a number (approximate literal)"
                 (tokenizer-source tok) ln (+ cl 1))])]

      ;; Dot handling:
      ;;   ...      → $rest sentinel symbol
      ;;   ...name  → rest-param token
      ;;   .:kw     → dot-key token (for .:name prefix syntax)
      ;;   .ident   → dot-access token (for user.name postfix syntax)
      ;;   .        → error
      [(char=? c #\.)
       (let ([c2 (peek-char (tokenizer-port tok) 1)]
             [c3 (peek-char (tokenizer-port tok) 2)])
         (cond
           [(and (char? c2) (char=? c2 #\.) (char? c3) (char=? c3 #\.))
            ;; Consume three dots
            (tok-read! tok) (tok-read! tok) (tok-read! tok)
            ;; Check if followed by identifier chars → ...name (rest param)
            (define next (tok-peek tok))
            (if (and (char? next) (ident-start? next))
                (let ([rest-name (read-ident-chars! tok)])
                  (token 'rest-param (string->symbol rest-name) ln cl ps
                         (+ 3 (string-length rest-name))))
                ;; Bare ... → $rest sentinel symbol
                (token 'symbol '$rest ln cl ps 3))]
           ;; .:keyword → dot-key token
           [(and (char? c2) (char=? c2 #\:)
                 (char? c3) (ident-start? c3))
            (tok-read! tok) (tok-read! tok) ; consume . and :
            (define field-name (read-ident-chars! tok))
            (token 'dot-key (string->symbol (string-append ":" field-name))
                   ln cl ps (+ 2 (string-length field-name)))]
           ;; .ident → dot-access token
           [(and (char? c2) (ident-start? c2))
            (tok-read! tok) ; consume .
            (define field-name (read-ident-chars! tok))
            (token 'dot-access (string->symbol field-name)
                   ln cl ps (+ 1 (string-length field-name)))]
           [else
            (tok-read! tok)
            (error 'prologos-reader "~a:~a:~a: Unexpected character: ."
                   (tokenizer-source tok) ln (+ cl 1))]))]

      ;; Identifier
      [(ident-start? c)
       (read-ident-token! tok ln cl ps)]

      ;; NOTE: Star (*) is now handled by ident-start? above, producing the
      ;; symbol '* instead of '$star. The parser's star-symbol? accepts both.

      ;; Character literal: \a, \newline, \space, \tab, \return, \uXXXX
      [(char=? c #\\)
       (tok-read! tok)  ; consume the backslash
       (define next (tok-peek tok))
       (cond
         ;; Unicode escape: \uXXXX — check BEFORE alphabetic branch
         ;; because 'u' is alphabetic and read-ident-chars! would consume 'u0041' as a name
         [(and (char? next) (char=? next #\u))
          ;; Peek ahead to see if next 4 chars after 'u' are hex digits
          (define port (tokenizer-port tok))
          (define h1 (peek-char port 1))
          (cond
            [(and (char? h1)
                  (or (char-numeric? h1)
                      (memv (char-downcase h1) '(#\a #\b #\c #\d #\e #\f))))
             ;; Looks like \uXXXX — consume 'u' and read 4 hex digits
             (tok-read! tok)  ; consume 'u'
             (define hex-chars
               (let loop ([i 0] [acc '()])
                 (if (= i 4) (list->string (reverse acc))
                     (let ([h (tok-peek tok)])
                       (if (and (char? h)
                                (or (char-numeric? h)
                                    (memv (char-downcase h) '(#\a #\b #\c #\d #\e #\f))))
                           (begin (tok-read! tok) (loop (+ i 1) (cons h acc)))
                           (error 'prologos-reader
                                  "~a:~a:~a: Expected 4 hex digits after \\u, got ~a"
                                  (tokenizer-source tok) ln (+ cl 1) i))))))
             (define code-point (string->number hex-chars 16))
             (token 'char (integer->char code-point) ln cl ps (+ 2 (string-length hex-chars)))]
            [else
             ;; \u followed by non-hex → single char literal 'u'
             (tok-read! tok)
             (token 'char #\u ln cl ps 2)])]
         ;; Named characters or single alpha char
         [(and (char? next) (char-alphabetic? next))
          (define start-pos (+ ps 1))
          ;; Read all identifier-like chars
          (define name (read-ident-chars! tok))
          (define total-len (+ 1 (string-length name)))
          (cond
            ;; Single character: \a, \A, \z etc.
            [(= (string-length name) 1)
             (token 'char (string-ref name 0) ln cl ps total-len)]
            ;; Named characters
            [(string=? name "newline")   (token 'char #\newline ln cl ps total-len)]
            [(string=? name "space")     (token 'char #\space ln cl ps total-len)]
            [(string=? name "tab")       (token 'char #\tab ln cl ps total-len)]
            [(string=? name "return")    (token 'char #\return ln cl ps total-len)]
            [(string=? name "backspace") (token 'char #\backspace ln cl ps total-len)]
            [(string=? name "formfeed")  (token 'char (integer->char 12) ln cl ps total-len)]
            [else
             (error 'prologos-reader "~a:~a:~a: Unknown named character: \\~a"
                    (tokenizer-source tok) ln (+ cl 1) name)])]
         ;; Single non-alpha character: \!, \?, \0 etc.
         [(char? next)
          (tok-read! tok)
          (token 'char next ln cl ps 2)]
         [else
          (error 'prologos-reader "~a:~a:~a: Expected character after \\"
                 (tokenizer-source tok) ln (+ cl 1))])]

      [else
       (tok-read! tok)
       (error 'prologos-reader "~a:~a:~a: Unexpected character: ~a"
              (tokenizer-source tok) ln (+ cl 1) c)])))

;; --- Token reading helpers ---

(define (read-ident-chars! tok)
  (let loop ([chars '()])
    (define c (tok-peek tok))
    (cond
      [(and (char? c) (ident-continue? c))
       (tok-read! tok) (loop (cons c chars))]
      ;; :: namespace separator: consume both colons if followed by ident char
      ;; e.g., nat::add tokenizes as a single symbol
      [(and (char? c) (char=? c #\:)
            (let ([c2 (peek-char (tokenizer-port tok) 1)])
              (and (char? c2) (char=? c2 #\:)))
            (let ([c3 (peek-char (tokenizer-port tok) 2)])
              (and (char? c3) (ident-start? c3)))
            (pair? chars))  ; must have identifier chars before ::
       (tok-read! tok) (tok-read! tok)  ; consume both colons
       (loop (cons #\: (cons #\: chars)))]
      [else
       (list->string (reverse chars))])))

(define (read-ident-rest! tok)
  ;; Like read-ident-chars! but for the remaining part after first char(s) consumed
  (read-ident-chars! tok))

(define (read-ident-token! tok ln cl ps)
  (define s (read-ident-chars! tok))
  (token 'symbol (string->symbol s) ln cl ps (string-length s)))

(define (read-number-token! tok ln cl ps)
  ;; Read integer digits, then check for / followed by digits (fraction literal)
  (let loop ([chars '()])
    (define c (tok-peek tok))
    (if (and (char? c) (char-numeric? c))
        (begin (tok-read! tok) (loop (cons c chars)))
        ;; Integer digits consumed. Check for fraction: N/D
        ;; Use peek-char with skip to look 1 ahead without consuming /
        (let ([int-chars (reverse chars)]
              [port (tokenizer-port tok)])
          (if (and (char? c) (char=? c #\/)
                   (let ([d (peek-char port 1)])
                     (and (char? d) (char-numeric? d))))
              ;; Fraction: consume / then read denominator digits
              (begin
                (tok-read! tok) ; consume /
                (let dloop ([dchars '()])
                  (define dc (tok-peek tok))
                  (if (and (char? dc) (char-numeric? dc))
                      (begin (tok-read! tok) (dloop (cons dc dchars)))
                      (let* ([s (string-append (list->string int-chars) "/"
                                               (list->string (reverse dchars)))]
                             [v (string->number s)])
                        (token 'number v ln cl ps (string-length s))))))
              ;; No fraction — check for decimal point: N.D
              (if (and (char? c) (char=? c #\.)
                       (let ([d (peek-char port 1)])
                         (and (char? d) (char-numeric? d))))
                  ;; Decimal: consume . then read fractional digits → exact rational
                  (begin
                    (tok-read! tok) ; consume .
                    (let dloop ([dchars '()])
                      (define dc (tok-peek tok))
                      (if (and (char? dc) (char-numeric? dc))
                          (begin (tok-read! tok) (dloop (cons dc dchars)))
                          (let* ([frac-str (list->string (reverse dchars))]
                                 [int-val (string->number (list->string int-chars))]
                                 [frac-val (string->number frac-str)]
                                 [denom (expt 10 (string-length frac-str))]
                                 [v (+ int-val (/ frac-val denom))]  ;; exact rational
                                 [total-len (+ (length int-chars) 1 (string-length frac-str))])
                            (token 'decimal-literal v ln cl ps total-len)))))
                  ;; No decimal — check for N suffix (Nat literal: 42N)
                  (let ([next-c (tok-peek tok)])
                    (if (and (char? next-c) (char=? next-c #\N))
                        ;; N suffix → Nat literal
                        (begin
                          (tok-read! tok) ; consume N
                          (let ([s (list->string int-chars)])
                            (token 'nat-literal (string->number s) ln cl ps (+ (string-length s) 1))))
                        ;; No N → plain integer (will become Int)
                        (let ([s (list->string int-chars)])
                          (token 'number (string->number s) ln cl ps (string-length s)))))))))))

(define (read-string-token! tok ln cl ps)
  (tok-read! tok) ; consume opening "
  (let loop ([chars '()])
    (define c (tok-peek tok))
    (cond
      [(eof-object? c)
       (error 'prologos-reader "~a:~a:~a: Unterminated string literal"
              (tokenizer-source tok) ln cl)]
      [(char=? c #\\)
       (tok-read! tok)
       (define esc (tok-read! tok))
       (when (eof-object? esc)
         (error 'prologos-reader "~a:~a:~a: Unterminated string escape"
                (tokenizer-source tok) ln cl))
       (define actual
         (case esc
           [(#\n) #\newline]
           [(#\t) #\tab]
           [(#\\) #\\]
           [(#\") #\"]
           [else esc]))
       (loop (cons actual chars))]
      [(char=? c #\")
       (tok-read! tok) ; consume closing "
       (let ([s (list->string (reverse chars))])
         (token 'string s ln cl ps (+ 2 (string-length s))))]
      [else
       (tok-read! tok)
       (loop (cons c chars))])))

;; --- Public tokenizer interface ---

(define (tokenize-string s)
  (define port (open-input-string s))
  (define tok (make-tokenizer port "<string>"))
  (let loop ([tokens '()])
    (define t (tokenizer-next! tok))
    (if (eq? (token-type t) 'eof)
        (reverse (cons t tokens))
        (loop (cons t tokens)))))

;; ========================================
;; Indentation Parser
;; ========================================
;; Converts token stream into Racket syntax objects (S-expressions).

;; Parser state
(struct parser (tok source) #:transparent)

(define (make-parser port source)
  (parser (make-tokenizer port source) source))

;; Peek at the next token without consuming
(define (parser-peek p)
  (define tok (parser-tok p))
  (when (null? (tokenizer-pending tok))
    ;; Read next token and push it back as pending.
    ;; tokenizer-next! may have added extra tokens to pending already
    ;; (e.g. multiple DEDENTs), so we prepend the returned token
    ;; rather than overwriting.
    (define t (tokenizer-next! tok))
    (set-tokenizer-pending! tok (cons t (tokenizer-pending tok))))
  (car (tokenizer-pending tok)))

(define (parser-next! p)
  (tokenizer-next! (parser-tok p)))

(define (parser-peek-type p)
  (token-type (parser-peek p)))

;; Make a syntax object from a datum with source location
(define (make-stx datum source line col pos span)
  (datum->syntax #f datum (list source line col pos span)))

(define (token->stx t source)
  (make-stx (token-value t) source
            (token-line t) (token-col t) (token-pos t) (token-span t)))

;; --- Parse a grouped form: ( ... ) ---
;; Inside parens, indentation is disabled. Content is a flat sequence.

(define (parse-grouped-form p)
  (define open-tok (parser-next! p))  ; consume lparen
  (define ln (token-line open-tok))
  (define cl (token-col open-tok))
  (define ps (token-pos open-tok))
  (define src (parser-source p))

  (define elements
    (let loop ([elems '()])
      (define tt (parser-peek-type p))
      (cond
        [(eq? tt 'rparen)
         (parser-next! p) ; consume rparen
         (reverse elems)]
        [(eq? tt 'eof)
         (error 'prologos-reader "~a:~a:~a: Unclosed parenthesis"
                src ln cl)]
        [else
         (define elem (parse-inline-element p))
         (loop (cons elem elems))])))

  ;; Produce a syntax list
  (make-stx elements src ln cl ps
            (- (+ (token-pos (parser-peek p)) 1) ps)))

;; --- Parse a bracket form: [ ... ] ---
;; Primary grouping delimiter. Produces plain S-expression lists.
;; Commas inside brackets are stripped (parameter separator).

(define (parse-bracket-form p)
  (define open-tok (parser-next! p))  ; consume lbracket
  (define ln (token-line open-tok))
  (define cl (token-col open-tok))
  (define ps (token-pos open-tok))
  (define src (parser-source p))

  (define elements
    (let loop ([elems '()])
      (define tt (parser-peek-type p))
      (cond
        [(eq? tt 'rbracket)
         (parser-next! p) ; consume rbracket
         (reverse elems)]
        [(eq? tt 'eof)
         (error 'prologos-reader "~a:~a:~a: Unclosed bracket"
                src ln cl)]
        ;; Skip comma tokens inside brackets (parameter separator)
        [(eq? tt 'comma)
         (parser-next! p) ; consume comma
         (loop elems)]
        [else
         (define elem (parse-inline-element p))
         (loop (cons elem elems))])))

  (make-stx elements src ln cl ps
            (- (+ (token-pos (parser-peek p)) 1) ps)))

;; --- Parse a paren form: ( ... ) ---
;; Produces the same datum tree as brackets (a plain list).
;; Used for type grouping: (Nat -> Nat), (A * B), (A | B), etc.
(define (parse-paren-form p)
  (define open-tok (parser-next! p))  ; consume lparen
  (define ln (token-line open-tok))
  (define cl (token-col open-tok))
  (define ps (token-pos open-tok))
  (define src (parser-source p))

  (define elements
    (let loop ([elems '()])
      (define tt (parser-peek-type p))
      (cond
        [(eq? tt 'rparen)
         (parser-next! p) ; consume rparen
         (reverse elems)]
        [(eq? tt 'eof)
         (error 'prologos-reader "~a:~a:~a: Unclosed paren"
                src ln cl)]
        ;; Skip comma tokens inside parens (parameter separator)
        [(eq? tt 'comma)
         (parser-next! p) ; consume comma
         (loop elems)]
        [else
         (define elem (parse-inline-element p))
         (loop (cons elem elems))])))

  (make-stx elements src ln cl ps
            (- (+ (token-pos (parser-peek p)) 1) ps)))

;; --- Parse a list literal form: '[ ... ] ---
;; Wraps contents with $list-literal sentinel.
;; '[] → ($list-literal)
;; '[1 2 3] → ($list-literal 1 2 3)
;; '[1 2 | ys] → ($list-literal 1 2 ($list-tail ys))

(define (parse-list-literal-form p)
  (define quote-tok (parser-next! p))  ; consume quote-lbracket (the ')
  (define open-tok (parser-next! p))   ; consume lbracket (the [)
  (define ln (token-line quote-tok))
  (define cl (token-col quote-tok))
  (define ps (token-pos quote-tok))
  (define src (parser-source p))

  (define elements
    (let loop ([elems '()])
      (define tt (parser-peek-type p))
      (cond
        [(eq? tt 'rbracket)
         (parser-next! p) ; consume rbracket
         (reverse elems)]
        [(eq? tt 'eof)
         (error 'prologos-reader "~a:~a:~a: Unclosed list literal '[..."
                src ln cl)]
        ;; Skip commas inside list literals
        [(eq? tt 'comma)
         (parser-next! p)
         (loop elems)]
        ;; Pipe for cons-tail syntax: '[ 1 2 | ys ]
        [(and (eq? tt 'symbol)
              (eq? (token-value (parser-peek p)) '$pipe))
         (parser-next! p) ; consume |
         (define tail-elem (parse-inline-element p))
         ;; Wrap the tail with $list-tail sentinel
         (define tail-stx
           (make-stx (list (make-stx '$list-tail src ln cl ps 0)
                           tail-elem)
                     src (token-line (parser-peek p)) (token-col (parser-peek p))
                     (token-pos (parser-peek p)) 1))
         ;; Expect closing bracket
         (define close-tt (parser-peek-type p))
         (unless (eq? close-tt 'rbracket)
           (error 'prologos-reader "~a:~a:~a: Expected ] after tail in list literal"
                  src ln cl))
         (parser-next! p) ; consume rbracket
         (reverse (cons tail-stx elems))]
        [else
         (define elem (parse-inline-element p))
         (loop (cons elem elems))])))

  ;; Wrap with $list-literal sentinel
  (define sentinel (make-stx '$list-literal src ln cl ps 0))
  (define all (cons sentinel elements))
  (make-stx all src ln cl ps
            (max 1 (- (+ (token-pos (parser-peek p)) 1) ps))))

;; --- Parse a PVec literal form: @[ ... ] ---
;; Wraps contents with $vec-literal sentinel.
;; @[] → ($vec-literal)
;; @[1 2 3] → ($vec-literal 1 2 3)

(define (parse-vec-literal-form p)
  (define at-tok (parser-next! p))    ; consume at-lbracket (the @)
  (define open-tok (parser-next! p))  ; consume lbracket (the [)
  (define ln (token-line at-tok))
  (define cl (token-col at-tok))
  (define ps (token-pos at-tok))
  (define src (parser-source p))

  (define elements
    (let loop ([elems '()])
      (define tt (parser-peek-type p))
      (cond
        [(eq? tt 'rbracket)
         (parser-next! p) ; consume rbracket
         (reverse elems)]
        [(eq? tt 'eof)
         (error 'prologos-reader "~a:~a:~a: Unclosed PVec literal @[..."
                src ln cl)]
        ;; Skip commas
        [(eq? tt 'comma)
         (parser-next! p)
         (loop elems)]
        [else
         (define elem (parse-inline-element p))
         (loop (cons elem elems))])))

  ;; Wrap with $vec-literal sentinel
  (define sentinel (make-stx '$vec-literal src ln cl ps 0))
  (define all (cons sentinel elements))
  (make-stx all src ln cl ps
            (max 1 (- (+ (token-pos (parser-peek p)) 1) ps))))

;; --- Parse an LSeq literal form: ~[ ... ] ---
;; Wraps contents with $lseq-literal sentinel.
;; ~[] → ($lseq-literal)
;; ~[1 2 3] → ($lseq-literal 1 2 3)

(define (parse-lseq-literal-form p)
  (define tilde-tok (parser-next! p))   ; consume tilde-lbracket (the ~)
  (define open-tok (parser-next! p))    ; consume lbracket (the [)
  (define ln (token-line tilde-tok))
  (define cl (token-col tilde-tok))
  (define ps (token-pos tilde-tok))
  (define src (parser-source p))

  (define elements
    (let loop ([elems '()])
      (define tt (parser-peek-type p))
      (cond
        [(eq? tt 'rbracket)
         (parser-next! p) ; consume rbracket
         (reverse elems)]
        [(eq? tt 'eof)
         (error 'prologos-reader "~a:~a:~a: Unclosed LSeq literal ~[..."
                src ln cl)]
        ;; Skip commas
        [(eq? tt 'comma)
         (parser-next! p)
         (loop elems)]
        [else
         (define elem (parse-inline-element p))
         (loop (cons elem elems))])))

  ;; Wrap with $lseq-literal sentinel
  (define sentinel (make-stx '$lseq-literal src ln cl ps 0))
  (define all (cons sentinel elements))
  (make-stx all src ln cl ps
            (max 1 (- (+ (token-pos (parser-peek p)) 1) ps))))

;; --- Parse an angle-bracket form: < ... > ---
;; Wraps contents with $angle-type sentinel for type annotations.

(define (parse-angle-form p)
  (define open-tok (parser-next! p))  ; consume langle
  (define ln (token-line open-tok))
  (define cl (token-col open-tok))
  (define ps (token-pos open-tok))
  (define src (parser-source p))

  (define elements
    (let loop ([elems '()])
      (define tt (parser-peek-type p))
      (cond
        [(eq? tt 'rangle)
         (parser-next! p) ; consume rangle
         (reverse elems)]
        [(eq? tt 'eof)
         (error 'prologos-reader "~a:~a:~a: Unclosed <"
                src ln cl)]
        [else
         (define elem (parse-inline-element p))
         (loop (cons elem elems))])))

  ;; Wrap with $angle-type sentinel
  (define sentinel (make-stx '$angle-type src ln cl ps 0))
  (define all (cons sentinel elements))
  (make-stx all src ln cl ps
            (max 1 (- (+ (token-pos (parser-peek p)) 1) ps))))

;; --- Parse a brace form: { ... } ---
;; Wraps contents with $brace-params sentinel for implicit type parameters.
;; {A B C} → ($brace-params A B C)

(define (parse-brace-form p)
  (define open-tok (parser-next! p))  ; consume lbrace
  (define ln (token-line open-tok))
  (define cl (token-col open-tok))
  (define ps (token-pos open-tok))
  (define src (parser-source p))

  (define elements
    (let loop ([elems '()])
      (define tt (parser-peek-type p))
      (cond
        [(eq? tt 'rbrace)
         (parser-next! p) ; consume rbrace
         (reverse elems)]
        [(eq? tt 'eof)
         (error 'prologos-reader "~a:~a:~a: Unclosed {"
                src ln cl)]
        [else
         (define elem (parse-inline-element p))
         (loop (cons elem elems))])))

  ;; Wrap with $brace-params sentinel
  (define sentinel (make-stx '$brace-params src ln cl ps 0))
  (define all (cons sentinel elements))
  (make-stx all src ln cl ps
            (max 1 (- (+ (token-pos (parser-peek p)) 1) ps))))

;; --- Parse a Set literal form: #{ ... } ---
;; Wraps contents with $set-literal sentinel.
;; #{} → ($set-literal)
;; #{1 2 3} → ($set-literal 1 2 3)

(define (parse-set-literal-form p)
  (define hash-tok (parser-next! p))   ; consume hash-lbrace (the #)
  (define open-tok (parser-next! p))   ; consume lbrace (the {)
  (define ln (token-line hash-tok))
  (define cl (token-col hash-tok))
  (define ps (token-pos hash-tok))
  (define src (parser-source p))

  (define elements
    (let loop ([elems '()])
      (define tt (parser-peek-type p))
      (cond
        [(eq? tt 'rbrace)
         (parser-next! p) ; consume rbrace
         (reverse elems)]
        [(eq? tt 'eof)
         (error 'prologos-reader "~a:~a:~a: Unclosed Set literal #{"
                src ln cl)]
        ;; Skip commas
        [(eq? tt 'comma)
         (parser-next! p)
         (loop elems)]
        [else
         (define elem (parse-inline-element p))
         (loop (cons elem elems))])))

  ;; Wrap with $set-literal sentinel
  (define sentinel (make-stx '$set-literal src ln cl ps 0))
  (define all (cons sentinel elements))
  (make-stx all src ln cl ps
            (max 1 (- (+ (token-pos (parser-peek p)) 1) ps))))

;; --- Parse a single inline element (atom, grouped form, $-quote, <angle>, {brace}) ---

(define (parse-inline-element p)
  (define tt (parser-peek-type p))
  (define src (parser-source p))
  (cond
    [(eq? tt 'lbracket)
     (parse-bracket-form p)]
    [(eq? tt 'lparen)
     (parse-paren-form p)]
    [(eq? tt 'langle)
     (parse-angle-form p)]
    [(eq? tt 'lbrace)
     (parse-brace-form p)]
    [(eq? tt 'quote-lbracket)
     ;; '[ ... ] — list literal
     (parse-list-literal-form p)]
    [(eq? tt 'at-lbracket)
     ;; @[ ... ] — PVec literal
     (parse-vec-literal-form p)]
    [(eq? tt 'tilde-lbracket)
     ;; ~[ ... ] — LSeq literal
     (parse-lseq-literal-form p)]
    [(eq? tt 'hash-lbrace)
     ;; #{ ... } — Set literal
     (parse-set-literal-form p)]
    [(eq? tt 'quote)
     ;; 'expr — quote operator
     (define d (parser-next! p)) ; consume '
     (define inner (parse-inline-element p))
     (define src (parser-source p))
     (make-stx (list (make-stx '$quote src
                               (token-line d) (token-col d) (token-pos d) 1)
                     inner)
               src (token-line d) (token-col d) (token-pos d)
               (token-span d))]
    [(eq? tt 'backtick)
     ;; `expr — quasiquote operator
     (define d (parser-next! p)) ; consume `
     (define inner (parse-inline-element p))
     (define src (parser-source p))
     (make-stx (list (make-stx '$quasiquote src
                               (token-line d) (token-col d) (token-pos d) 1)
                     inner)
               src (token-line d) (token-col d) (token-pos d)
               (token-span d))]
    [(eq? tt 'comma)
     ;; ,expr — unquote operator
     (define d (parser-next! p)) ; consume ,
     (define inner (parse-inline-element p))
     (define src (parser-source p))
     (make-stx (list (make-stx '$unquote src
                               (token-line d) (token-col d) (token-pos d) 1)
                     inner)
               src (token-line d) (token-col d) (token-pos d)
               (token-span d))]
    [(eq? tt 'symbol)
     (define t (parser-next! p))
     (token->stx t src)]
    [(eq? tt 'number)
     (define t (parser-next! p))
     (token->stx t src)]
    [(eq? tt 'nat-literal)
     ;; 42N → ($nat-literal 42) sentinel for parser
     (define t (parser-next! p))
     (make-stx (list (make-stx '$nat-literal src
                                (token-line t) (token-col t) (token-pos t) 1)
                      (make-stx (token-value t) src
                                (token-line t) (token-col t) (token-pos t) (token-span t)))
               src (token-line t) (token-col t) (token-pos t) (token-span t))]
    [(eq? tt 'colon)
     ;; Freestanding : becomes the symbol ':
     (define t (parser-next! p))
     (make-stx ': src (token-line t) (token-col t) (token-pos t) 1)]
    [(eq? tt 'string)
     (define t (parser-next! p))
     (token->stx t src)]
    [(eq? tt 'keyword)
     (define t (parser-next! p))
     (token->stx t src)]
    [(eq? tt 'char)
     (define t (parser-next! p))
     (token->stx t src)]
    [(eq? tt 'approx-literal)
     ;; ~N — produce ($approx-literal N) as syntax list
     (define t (parser-next! p))
     (define ln (token-line t))
     (define cl (token-col t))
     (define ps (token-pos t))
     (define sp (token-span t))
     (make-stx (list (make-stx '$approx-literal src ln cl ps 0)
                     (make-stx (token-value t) src ln (+ cl 1) (+ ps 1) (- sp 1)))
               src ln cl ps sp)]
    [(eq? tt 'decimal-literal)
     ;; 3.14 — bare decimal → Posit32 (produce ($decimal-literal 157/50) sentinel)
     (define t (parser-next! p))
     (define ln (token-line t))
     (define cl (token-col t))
     (define ps (token-pos t))
     (define sp (token-span t))
     (make-stx (list (make-stx '$decimal-literal src ln cl ps 0)
                     (make-stx (token-value t) src ln cl ps sp))
               src ln cl ps sp)]
    [(eq? tt 'rest-param)
     ;; ...name — produce ($rest-param name) as syntax list
     (define t (parser-next! p))
     (define ln (token-line t))
     (define cl (token-col t))
     (define ps (token-pos t))
     (define sp (token-span t))
     (make-stx (list (make-stx '$rest-param src ln cl ps 0)
                     (make-stx (token-value t) src ln (+ cl 3) (+ ps 3) (- sp 3)))
               src ln cl ps sp)]
    [(eq? tt 'dot-access)
     ;; .field — produce ($dot-access field) sentinel for preparse macro
     (define t (parser-next! p))
     (define ln (token-line t))
     (define cl (token-col t))
     (define ps (token-pos t))
     (define sp (token-span t))
     (make-stx (list (make-stx '$dot-access src ln cl ps 0)
                     (make-stx (token-value t) src ln (+ cl 1) (+ ps 1) (- sp 1)))
               src ln cl ps sp)]
    [(eq? tt 'dot-key)
     ;; .:keyword — produce ($dot-key :keyword) sentinel for preparse macro
     (define t (parser-next! p))
     (define ln (token-line t))
     (define cl (token-col t))
     (define ps (token-pos t))
     (define sp (token-span t))
     (make-stx (list (make-stx '$dot-key src ln cl ps 0)
                     (make-stx (token-value t) src ln (+ cl 1) (+ ps 1) (- sp 1)))
               src ln cl ps sp)]
    [else
     (define t (parser-peek p))
     (error 'prologos-reader
            "~a:~a:~a: Unexpected token: ~a"
            src (token-line t) (token-col t) (token-type t))]))

;; --- Read all tokens on the current line (up to NEWLINE, INDENT, DEDENT, or EOF) ---

(define (read-line-elements p)
  (let loop ([elems '()])
    (define tt (parser-peek-type p))
    (cond
      [(or (eq? tt 'newline) (eq? tt 'indent)
           (eq? tt 'dedent) (eq? tt 'eof))
       (reverse elems)]
      [else
       (define elem (parse-inline-element p))
       (loop (cons elem elems))])))

;; --- Parse a child form (inside an indented block) ---

(define (parse-child-form p)
  (define elems (read-line-elements p))
  (define tt (parser-peek-type p))

  (cond
    ;; Child has an indented block below it
    [(eq? tt 'indent)
     (define children (parse-indented-block p))
     (define all-elems (append elems children))
     ;; Always wrap when there are indented children
     (wrap-as-list all-elems (parser-source p))]

    ;; Single-element child — unwrap
    [(and (= (length elems) 1))
     (car elems)]

    ;; Multi-element child — wrap as list
    [else
     (wrap-as-list elems (parser-source p))]))

;; --- Parse an indented block ---

(define (parse-indented-block p)
  (parser-next! p) ; consume INDENT
  (let loop ([forms '()])
    (define tt (parser-peek-type p))
    (cond
      [(eq? tt 'dedent)
       (parser-next! p) ; consume DEDENT
       (reverse forms)]
      [(eq? tt 'eof)
       (reverse forms)]
      [(eq? tt 'newline)
       (parser-next! p) ; consume NEWLINE between children
       (loop forms)]
      [else
       (define form (parse-child-form p))
       (loop (cons form forms))])))

;; --- Parse a top-level form ---

(define (parse-top-level-form p)
  (define elems (read-line-elements p))
  (define tt (parser-peek-type p))

  (cond
    ;; Top-level form has an indented block
    [(eq? tt 'indent)
     (define children (parse-indented-block p))
     (define all-elems (append elems children))
     (wrap-as-list all-elems (parser-source p))]

    ;; Single paren-form at top level — already a list, don't double-wrap.
    ;; e.g. (def foo : Nat body) should stay as (def foo : Nat body),
    ;; not become ((def foo : Nat body)).
    [(and (= (length elems) 1)
          (pair? (syntax-e (car elems))))
     (car elems)]

    ;; Single element at top level — still wrap (top-level forms are always commands)
    [else
     (wrap-as-list elems (parser-source p))]))

;; --- Wrap a list of syntax elements as a syntax list ---

(define (wrap-as-list elems source)
  (if (null? elems)
      (make-stx '() source 0 0 0 0)
      (let ([first (car elems)])
        (make-stx elems source
                  (syntax-line first)
                  (syntax-column first)
                  (syntax-position first)
                  (max 1 (- (+ (syntax-position (last-elem elems))
                               (syntax-span (last-elem elems)))
                            (syntax-position first)))))))

(define (last-elem lst)
  (if (null? (cdr lst)) (car lst) (last-elem (cdr lst))))

;; --- Read all top-level forms ---

(define (read-all-forms p)
  (let loop ([forms '()])
    (define tt (parser-peek-type p))
    (cond
      [(eq? tt 'eof)
       (reverse forms)]
      [(eq? tt 'newline)
       (parser-next! p) ; skip newlines between top-level forms
       (loop forms)]
      [else
       (define form (parse-top-level-form p))
       (loop (cons form forms))])))

;; ========================================
;; Public API
;; ========================================

;; Read one datum (no source locations)
;; NOTE: Because indentation-sensitive parsing requires reading the entire
;; input to determine block structure, this reads ALL forms on first call
;; and caches remaining forms for subsequent calls via a port property.
(define prologos-form-cache (make-weak-hasheq))

(define (prologos-read in)
  (define cached (hash-ref prologos-form-cache in #f))
  (cond
    [(and cached (pair? cached))
     (hash-set! prologos-form-cache in (cdr cached))
     (syntax->datum (car cached))]
    [(and cached (null? cached))
     eof]
    [else
     ;; First call: parse everything
     (define p (make-parser in "<unknown>"))
     (define all-forms (read-all-forms p))
     (cond
       [(null? all-forms) eof]
       [else
        (hash-set! prologos-form-cache in (cdr all-forms))
        (syntax->datum (car all-forms))])]))

;; Read one datum with source locations
(define prologos-stx-cache (make-weak-hasheq))

(define (prologos-read-syntax source in)
  (define cached (hash-ref prologos-stx-cache in #f))
  (cond
    [(and cached (pair? cached))
     (hash-set! prologos-stx-cache in (cdr cached))
     (car cached)]
    [(and cached (null? cached))
     eof]
    [else
     ;; First call: parse everything
     (define p (make-parser in (or source "<unknown>")))
     (define all-forms (read-all-forms p))
     (cond
       [(null? all-forms) eof]
       [else
        (hash-set! prologos-stx-cache in (cdr all-forms))
        (car all-forms)])]))

;; Read ALL forms at once (for #:whole-body-readers? #t in syntax/module-reader)
(define (prologos-read-syntax-all source in)
  (define p (make-parser in (or source "<unknown>")))
  (read-all-forms p))

;; Read all forms from a string (for testing)
(define (read-all-forms-string s)
  (define port (open-input-string s))
  (define p (make-parser port "<string>"))
  (map syntax->datum (read-all-forms p)))

