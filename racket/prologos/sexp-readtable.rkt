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
    #\- 'terminating-macro
    (lambda (ch port src line col pos)
      ;; Check if this is -> (arrow operator)
      (define next (peek-char port))
      (cond
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
;; The custom readtable
;; ========================================
(define prologos-readtable
  (make-readtable (current-readtable)
    #\< 'terminating-macro read-angle-bracket-syntax))

;; ========================================
;; Convenience read functions
;; ========================================
(define (prologos-sexp-read in)
  (parameterize ([current-readtable prologos-readtable])
    (read in)))

(define (prologos-sexp-read-syntax src in)
  (parameterize ([current-readtable prologos-readtable])
    (read-syntax src in)))
