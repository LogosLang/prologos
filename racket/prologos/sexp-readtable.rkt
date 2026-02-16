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
    ;; Not '[ — fall back to standard quote
    [else
     (define inner
       (parameterize ([current-readtable prologos-readtable])
         (read-syntax src port)))
     (datum->syntax #f (list 'quote inner)
                    (list src line col pos (max 1 (- (file-position port) pos))))]))

(define (read-quote-datum ch port)
  (define stx (read-quote-syntax ch port "<unknown>" #f #f (file-position port)))
  (if (syntax? stx) (syntax->datum stx) stx))

;; ========================================
;; The custom readtable
;; ========================================
(define prologos-readtable
  (make-readtable (current-readtable)
    #\< 'terminating-macro read-angle-bracket-syntax
    #\{ 'terminating-macro read-brace-params-syntax
    #\, 'terminating-macro read-comma-syntax
    #\' 'terminating-macro read-quote-syntax))

;; ========================================
;; Convenience read functions
;; ========================================
(define (prologos-sexp-read in)
  (parameterize ([current-readtable prologos-readtable])
    (read in)))

(define (prologos-sexp-read-syntax src in)
  (parameterize ([current-readtable prologos-readtable])
    (read-syntax src in)))
