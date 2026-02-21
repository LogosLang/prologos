#lang racket/base

;;;
;;; PROLOGOS SEXP READTABLE
;;; Custom readtable for #lang prologos/sexp that makes < > work as
;;; type annotation delimiters. <content> reads as ($angle-type content).
;;;
;;; Shared between sexp.rkt, driver.rkt, repl.rkt, and test files.
;;;

(provide prologos-readtable
         prologos-sexp-read
         prologos-sexp-read-syntax)

;; ========================================
;; Inner readtable for inside <...>
;; ========================================
;; Inside angle brackets, > is a terminating macro character (close delimiter).
;; We also handle - specially so -> still works as a symbol.

(define (make-inner-readtable outer-rt)
  (make-readtable outer-rt
    #\> 'terminating-macro
    (lambda (ch port src line col pos)
      ;; Return a sentinel to signal closing
      '$angle-close$)
    #\| 'terminating-macro
    (lambda (ch port src line col pos)
      ;; Pipe in type position → $pipe sentinel for union types
      '$pipe)
    #\- 'terminating-macro
    (lambda (ch port src line col pos)
      ;; Check if this is ->, -0>, -1>, or -w> (arrow operators)
      (define next (peek-char port))
      (cond
        ;; Multiplied arrows: -0>, -1>, -w>
        [(and (char? next) (memq next '(#\0 #\1 #\w)))
         (define mc (read-char port))
         (define after-mult (peek-char port))
         (cond
           [(and (char? after-mult) (char=? after-mult #\>))
            (read-char port) ; consume >
            (string->symbol (string #\- mc #\>))]
           [else
            ;; Not a multiplied arrow; reconstruct identifier
            (let loop ([chars (list mc #\-)])
              (define c (peek-char port))
              (cond
                [(and (char? c)
                      (not (char-whitespace? c))
                      (not (memq c '(#\( #\) #\[ #\] #\< #\> #\; #\"))))
                 (read-char port)
                 (loop (cons c chars))]
                [else
                 (string->symbol (list->string (reverse chars)))]))])]
        [(and (char? next) (char=? next #\>))
         ;; -> arrow: consume >, check what follows
         (read-char port)
         (define after (peek-char port))
         (cond
           ;; If more identifier chars follow (e.g. ->foo), keep reading
           [(and (char? after)
                 (or (char-alphabetic? after) (char=? after #\_)
                     (char=? after #\-) (char-numeric? after)))
            (let loop ([chars (list #\> #\-)])
              (define c (peek-char port))
              (cond
                [(and (char? c)
                      (not (char-whitespace? c))
                      (not (memq c '(#\( #\) #\[ #\] #\< #\> #\; #\"))))
                 (read-char port)
                 (loop (cons c chars))]
                [else
                 (string->symbol (list->string (reverse chars)))]))]
           [else '->])]
        [else
         ;; Just a bare -, read rest of identifier
         (let loop ([chars (list #\-)])
           (define c (peek-char port))
           (cond
             [(and (char? c)
                   (not (char-whitespace? c))
                   (not (memq c '(#\( #\) #\[ #\] #\< #\> #\; #\"))))
              (read-char port)
              (loop (cons c chars))]
             [else
              (string->symbol (list->string (reverse chars)))]))]))))

;; ========================================
;; Angle bracket reader procedure
;; ========================================
;; Called when < is encountered. Reads content until matching >.
;; Returns ($angle-type content...) as a syntax object or datum.

(define (read-angle-bracket-syntax ch port src line col pos)
  (define inner-rt (make-inner-readtable prologos-readtable))
  (define elements
    (let loop ([elems '()])
      ;; Skip whitespace inside angle brackets
      (let skip-ws ()
        (define c (peek-char port))
        (when (and (char? c) (char-whitespace? c))
          (read-char port)
          (skip-ws)))
      (define next (peek-char port))
      (cond
        [(eof-object? next)
         (error 'prologos-reader "Unclosed < at ~a:~a:~a" src line col)]
        [(char=? next #\>)
         (read-char port) ; consume >
         (reverse elems)]
        [else
         (define val
           (parameterize ([current-readtable inner-rt])
             (read-syntax src port)))
         ;; Check if we got the close sentinel
         (cond
           [(and (syntax? val) (eq? (syntax-e val) '$angle-close$))
            (reverse elems)]
           [(eq? val '$angle-close$)
            (reverse elems)]
           [else
            (loop (cons val elems))])])))
  ;; Build ($angle-type content...) syntax
  (define end-pos (file-position port))
  (define span (- end-pos pos))
  (define sentinel (datum->syntax #f '$angle-type (list src line col pos 0)))
  (datum->syntax #f (cons sentinel elements)
                 (list src line col pos span)))

(define (read-angle-bracket-datum ch port)
  (define stx (read-angle-bracket-syntax ch port "<unknown>" #f #f (file-position port)))
  (syntax->datum stx))

;; ========================================
;; Brace reader procedure
;; ========================================
;; Called when { is encountered. Reads content until matching }.
;; Returns ($brace-params content...) as a syntax object or datum.
;; Used for implicit type parameters: {A B C} → ($brace-params A B C).

(define (read-brace-params-syntax ch port src line col pos)
  (define elements
    (let loop ([elems '()])
      ;; Skip whitespace inside braces
      (let skip-ws ()
        (define c (peek-char port))
        (when (and (char? c) (char-whitespace? c))
          (read-char port)
          (skip-ws)))
      (define next (peek-char port))
      (cond
        [(eof-object? next)
         (error 'prologos-reader "Unclosed { at ~a:~a:~a" src line col)]
        [(char=? next #\})
         (read-char port) ; consume }
         (reverse elems)]
        [else
         (define val
           (parameterize ([current-readtable prologos-readtable])
             (read-syntax src port)))
         (loop (cons val elems))])))
  ;; Build ($brace-params content...) syntax
  (define end-pos (file-position port))
  (define span (- end-pos pos))
  (define sentinel (datum->syntax #f '$brace-params (list src line col pos 0)))
  (datum->syntax #f (cons sentinel elements)
                 (list src line col pos span)))

(define (read-brace-params-datum ch port)
  (define stx (read-brace-params-syntax ch port "<unknown>" #f #f (file-position port)))
  (syntax->datum stx))

;; ========================================
;; Comma reader: skip commas as separators in [param : Type, param : Type]
;; ========================================
;; When a comma is encountered, just read and return the next datum.
;; This effectively makes commas whitespace-like separators.
(define (read-comma-syntax ch port src line col pos)
  (parameterize ([current-readtable prologos-readtable])
    (read-syntax src port)))

(define (read-comma-datum ch port)
  (parameterize ([current-readtable prologos-readtable])
    (read port)))

;; ========================================
;; Single-quote reader: intercept '[ for list literals
;; ========================================
;; When ' is followed by [, read list literal as ($list-literal ...).
;; Otherwise, fall back to standard Racket quote behavior.

(define (read-quote-syntax ch port src line col pos)
  (define next (peek-char port))
  (cond
    ;; '[ — list literal
    [(and (char? next) (char=? next #\[))
     (read-char port) ; consume [
     ;; Read elements until ]
     (define elements
       (let loop ([elems '()])
         ;; Skip whitespace
         (let skip-ws ()
           (define c (peek-char port))
           (when (and (char? c) (char-whitespace? c))
             (read-char port)
             (skip-ws)))
         (define nc (peek-char port))
         (cond
           [(eof-object? nc)
            (error 'prologos-reader "Unclosed list literal '[ at ~a:~a:~a" src line col)]
           [(char=? nc #\])
            (read-char port) ; consume ]
            (reverse elems)]
           ;; Pipe for cons-tail syntax: '[1 2 | ys]
           [(char=? nc #\|)
            (read-char port) ; consume |
            (define tail-val
              (parameterize ([current-readtable prologos-readtable])
                (read-syntax src port)))
            (define tail-datum
              (if (syntax? tail-val) (syntax->datum tail-val) tail-val))
            ;; Expect closing ]
            (let skip-ws ()
              (define c (peek-char port))
              (when (and (char? c) (char-whitespace? c))
                (read-char port)
                (skip-ws)))
            (define close (peek-char port))
            (unless (and (char? close) (char=? close #\]))
              (error 'prologos-reader "Expected ] after tail in list literal at ~a:~a:~a"
                     src line col))
            (read-char port) ; consume ]
            (reverse (cons `($list-tail ,tail-datum) elems))]
           ;; Skip commas
           [(char=? nc #\,)
            (read-char port) ; consume comma
            (loop elems)]
           [else
            (define val
              (parameterize ([current-readtable prologos-readtable])
                (read-syntax src port)))
            (define datum-val
              (if (syntax? val) (syntax->datum val) val))
            (loop (cons datum-val elems))])))
     ;; Build ($list-literal ...) as syntax
     (define end-pos (file-position port))
     (define span (- end-pos pos))
     (datum->syntax #f (cons '$list-literal elements)
                    (list src line col pos span))]
    ;; Not '[ — quote operator: 'expr → ($quote expr)
    [else
     (define inner
       (parameterize ([current-readtable prologos-readtable])
         (read-syntax src port)))
     (datum->syntax #f (list '$quote inner)
                    (list src line col pos (max 1 (- (file-position port) pos))))]))

(define (read-quote-datum ch port)
  (define stx (read-quote-syntax ch port "<unknown>" #f #f (file-position port)))
  (if (syntax? stx) (syntax->datum stx) stx))

;; ========================================
;; Tilde reader: ~[ for LSeq literals, ~N for approximate literals
;; ========================================
;; When ~ is followed by [, read LSeq literal as ($lseq-literal ...).
;; ~[1 2 3] → ($lseq-literal 1 2 3)
;; ~[] → ($lseq-literal)
;; When ~ is followed by a number, reads as ($approx-literal <value>).
;; ~42 → ($approx-literal 42)
;; ~3/7 → ($approx-literal 3/7)
;; Bare ~ (not followed by [ or digit) is an error.

(define (read-tilde-syntax ch port src line col pos)
  (define next (peek-char port))
  (cond
    ;; ~[ — LSeq literal
    [(and (char? next) (char=? next #\[))
     (read-char port) ; consume [
     (define elements
       (let loop ([elems '()])
         ;; Skip whitespace
         (let skip-ws ()
           (define c (peek-char port))
           (when (and (char? c) (char-whitespace? c))
             (read-char port)
             (skip-ws)))
         (define nc (peek-char port))
         (cond
           [(eof-object? nc)
            (error 'prologos-reader "Unclosed LSeq literal ~[ at ~a:~a:~a" src line col)]
           [(char=? nc #\])
            (read-char port) ; consume ]
            (reverse elems)]
           ;; Skip commas
           [(char=? nc #\,)
            (read-char port)
            (loop elems)]
           [else
            (define val
              (parameterize ([current-readtable prologos-readtable])
                (read-syntax src port)))
            (define datum-val
              (if (syntax? val) (syntax->datum val) val))
            (loop (cons datum-val elems))])))
     ;; Build ($lseq-literal ...) as syntax
     (define end-pos (file-position port))
     (define span (- end-pos pos))
     (datum->syntax #f (cons '$lseq-literal elements)
                    (list src line col pos span))]
    ;; ~N — approximate literal
    [(and (char? next) (char-numeric? next))
     ;; Read the number using the standard Racket reader
     (define num-val
       (parameterize ([current-readtable prologos-readtable])
         (read-syntax src port)))
     (define v (if (syntax? num-val) (syntax-e num-val) num-val))
     (define end-pos (file-position port))
     (define span (- end-pos pos))
     (datum->syntax #f (list '$approx-literal v)
                    (list src line col pos span))]
    [else
     (error 'prologos-reader "~a:~a:~a: ~ must be followed by [ (LSeq literal) or a number (approximate literal)"
            src (or line 0) (or col 0))]))

(define (read-tilde-datum ch port)
  (define stx (read-tilde-syntax ch port "<unknown>" #f #f (file-position port)))
  (if (syntax? stx) (syntax->datum stx) stx))

;; ========================================
;; At-bracket reader: @[ for PVec literals
;; ========================================
;; When @ is followed by [, read PVec literal as ($vec-literal ...).
;; @[1 2 3] → ($vec-literal 1 2 3)
;; @[] → ($vec-literal)
;; Bare @ (not followed by [) is an error.

(define (read-at-bracket-syntax ch port src line col pos)
  (define next (peek-char port))
  (cond
    ;; @[ — PVec literal
    [(and (char? next) (char=? next #\[))
     (read-char port) ; consume [
     (define elements
       (let loop ([elems '()])
         ;; Skip whitespace
         (let skip-ws ()
           (define c (peek-char port))
           (when (and (char? c) (char-whitespace? c))
             (read-char port)
             (skip-ws)))
         (define nc (peek-char port))
         (cond
           [(eof-object? nc)
            (error 'prologos-reader "Unclosed PVec literal @[ at ~a:~a:~a" src line col)]
           [(char=? nc #\])
            (read-char port) ; consume ]
            (reverse elems)]
           ;; Skip commas
           [(char=? nc #\,)
            (read-char port)
            (loop elems)]
           [else
            (define val
              (parameterize ([current-readtable prologos-readtable])
                (read-syntax src port)))
            (define datum-val
              (if (syntax? val) (syntax->datum val) val))
            (loop (cons datum-val elems))])))
     ;; Build ($vec-literal ...) as syntax
     (define end-pos (file-position port))
     (define span (- end-pos pos))
     (datum->syntax #f (cons '$vec-literal elements)
                    (list src line col pos span))]
    ;; Not @[ — error
    [else
     (error 'prologos-reader "~a:~a:~a: @ must be followed by [ for PVec literal (@[...])"
            src (or line 0) (or col 0))]))

(define (read-at-bracket-datum ch port)
  (define stx (read-at-bracket-syntax ch port "<unknown>" #f #f (file-position port)))
  (if (syntax? stx) (syntax->datum stx) stx))

;; ========================================
;; Pipe reader: |> → $pipe-gt, bare | → $pipe
;; ========================================
;; When | is followed by >, read as $pipe-gt sentinel (pipe operator).
;; Otherwise, read as $pipe sentinel (union type separator / match arm).
;; This mirrors the WS reader's handling of |> and |.

(define (read-pipe-syntax ch port src line col pos)
  (define next (peek-char port))
  (cond
    ;; |> — pipe operator
    [(and (char? next) (char=? next #\>))
     (read-char port) ; consume >
     (define end-pos (file-position port))
     (datum->syntax #f '$pipe-gt (list src line col pos (- end-pos pos)))]
    ;; | — pipe sentinel (union type separator / match arm)
    [else
     (datum->syntax #f '$pipe (list src line col pos 1))]))

(define (read-pipe-datum ch port)
  (define stx (read-pipe-syntax ch port "<unknown>" #f #f (file-position port)))
  (if (syntax? stx) (syntax->datum stx) stx))

;; ========================================
;; Backtick reader: `expr → ($quasiquote expr)
;; ========================================
;; Quasiquote. Reads one form under a readtable where , produces ($unquote expr).
;; `(add ,x 2) → ($quasiquote (add ($unquote x) 2))
;; `,@x (splice) is NOT supported yet — just ,x for unquote.

;; Forward declaration: prologos-readtable is needed by the qq readtable,
;; and the qq readtable is needed by the backtick handler registered in
;; prologos-readtable. We break the cycle by making the qq readtable lazily.
(define prologos-qq-readtable #f)

(define (ensure-qq-readtable!)
  (unless prologos-qq-readtable
    (set! prologos-qq-readtable
      (make-readtable prologos-readtable
        #\, 'terminating-macro read-unquote-syntax))))

;; Comma inside quasiquote context → ($unquote expr)
(define (read-unquote-syntax ch port src line col pos)
  ;; Read one form using the quasiquote readtable (so nested , still works)
  (define inner
    (parameterize ([current-readtable prologos-qq-readtable])
      (read-syntax src port)))
  (datum->syntax #f (list '$unquote inner)
                 (list src line col pos (max 1 (- (file-position port) pos)))))

(define (read-backtick-syntax ch port src line col pos)
  (ensure-qq-readtable!)
  (define next (peek-char port))
  (cond
    ;; `, — direct unquote after backtick (edge case: `,(foo))
    ;; Read one form under qq readtable
    [else
     (define inner
       (parameterize ([current-readtable prologos-qq-readtable])
         (read-syntax src port)))
     (datum->syntax #f (list '$quasiquote inner)
                    (list src line col pos (max 1 (- (file-position port) pos))))]))

(define (read-backtick-datum ch port)
  (define stx (read-backtick-syntax ch port "<unknown>" #f #f (file-position port)))
  (if (syntax? stx) (syntax->datum stx) stx))

;; ========================================
;; The custom readtable
;; ========================================
;; ========================================
;; Hash dispatch: #{ → Set literal
;; ========================================
(define (read-hash-dispatch-syntax ch port src line col pos)
  (define next (peek-char port))
  (cond
    ;; #{ — Set literal
    [(and (char? next) (char=? next #\{))
     (read-char port) ; consume {
     (define elements
       (let loop ([elems '()])
         ;; Skip whitespace
         (let skip-ws ()
           (define c (peek-char port))
           (when (and (char? c) (char-whitespace? c))
             (read-char port)
             (skip-ws)))
         (define nc (peek-char port))
         (cond
           [(eof-object? nc)
            (error 'prologos-reader "Unclosed Set literal #{ at ~a:~a:~a" src line col)]
           [(char=? nc #\})
            (read-char port) ; consume }
            (reverse elems)]
           ;; Skip commas
           [(char=? nc #\,)
            (read-char port)
            (loop elems)]
           [else
            (define val
              (parameterize ([current-readtable prologos-readtable])
                (read-syntax src port)))
            (define datum-val
              (if (syntax? val) (syntax->datum val) val))
            (loop (cons datum-val elems))])))
     ;; Build ($set-literal ...) as syntax
     (define end-pos (file-position port))
     (define span (- end-pos pos))
     (datum->syntax #f (cons '$set-literal elements)
                    (list src line col pos span))]
    ;; #\ — Character literal (Racket-style, for sexp mode compatibility)
    [(and (char? next) (char=? next #\\))
     (read-char port) ; consume backslash
     (define c2 (peek-char port))
     (cond
       ;; Named character or single alpha char
       [(and (char? c2) (char-alphabetic? c2))
        ;; Read all identifier-like chars
        (define name
          (let loop ([chars '()])
            (define c (peek-char port))
            (cond
              [(and (char? c) (or (char-alphabetic? c) (char-numeric? c)))
               (read-char port)
               (loop (cons c chars))]
              [else (list->string (reverse chars))])))
        (define char-val
          (cond
            [(= (string-length name) 1) (string-ref name 0)]
            [(string=? name "newline")   #\newline]
            [(string=? name "space")     #\space]
            [(string=? name "tab")       #\tab]
            [(string=? name "return")    #\return]
            [(string=? name "backspace") #\backspace]
            [(string=? name "formfeed")  (integer->char 12)]
            ;; Unicode escape: uXXXX (consumed as part of name)
            [(and (> (string-length name) 1)
                  (char=? (string-ref name 0) #\u)
                  (= (string-length name) 5)
                  (for/and ([i (in-range 1 5)])
                    (let ([c (string-ref name i)])
                      (or (char-numeric? c)
                          (memv (char-downcase c) '(#\a #\b #\c #\d #\e #\f))))))
             (integer->char (string->number (substring name 1) 16))]
            [else
             (error 'prologos-reader "~a:~a:~a: Unknown named character: #\\~a"
                    src (or line 0) (or col 0) name)]))
        (define end-pos (file-position port))
        (define span (- end-pos pos))
        (datum->syntax #f char-val (list src line col pos span))]
       ;; Single non-alpha character: #\!, #\0, etc.
       [(char? c2)
        (read-char port)
        (define end-pos (file-position port))
        (define span (- end-pos pos))
        (datum->syntax #f c2 (list src line col pos span))]
       [else
        (error 'prologos-reader "~a:~a:~a: Expected character after #\\"
               src (or line 0) (or col 0))])]
    [else
     (error 'prologos-reader "~a:~a:~a: # must be followed by { for Set literal (#{...}) or \\ for char literal (#\\a)"
            src (or line 0) (or col 0))]))

;; Datum-level reader for #{ (used by prologos-sexp-read)
(define (read-hash-dispatch-datum ch port)
  (define stx (read-hash-dispatch-syntax ch port "<unknown>" #f #f (file-position port)))
  (if (syntax? stx) (syntax->datum stx) stx))

(define prologos-readtable
  (make-readtable (current-readtable)
    #\< 'terminating-macro read-angle-bracket-syntax
    #\{ 'terminating-macro read-brace-params-syntax
    #\, 'terminating-macro read-comma-syntax
    #\' 'terminating-macro read-quote-syntax
    #\~ 'terminating-macro read-tilde-syntax
    #\@ 'terminating-macro read-at-bracket-syntax
    #\| 'terminating-macro read-pipe-syntax
    #\# 'terminating-macro read-hash-dispatch-syntax
    #\` 'terminating-macro read-backtick-syntax))

;; ========================================
;; Convenience read functions
;; ========================================
(define (prologos-sexp-read in)
  (parameterize ([current-readtable prologos-readtable])
    (read in)))

(define (prologos-sexp-read-syntax src in)
  (parameterize ([current-readtable prologos-readtable])
    (read-syntax src in)))
