#lang racket/base

;;;
;;; PROLOGOS REPL
;;; Interactive read-eval-type-check loop.
;;; Supports two modes:
;;;   - sexp: S-expression syntax (default)
;;;   - ws:   Whitespace syntax (blank line to submit)
;;;

(require racket/string
         "source-location.rkt"
         "errors.rkt"
         "parser.rkt"
         "driver.rkt"
         "pretty-print.rkt"
         "global-env.rkt"
         "reader.rkt"
         "macros.rkt"
         "sexp-readtable.rkt")

(provide run-repl
         current-repl-mode)

;; ========================================
;; Mode parameter
;; ========================================
(define current-repl-mode (make-parameter 'sexp))

;; ========================================
;; REPL Main Loop
;; ========================================
(define (run-repl)
  (displayln "Prologos v0.3.0")
  (displayln (format "Mode: ~a | :mode sexp/ws to switch | :quit to exit | :env | :load"
                     (current-repl-mode)))
  (newline)
  ;; Start with empty global env
  (parameterize ([current-global-env (hasheq)])
    (repl-loop)))

(define (repl-loop)
  (display "> ")
  (flush-output)
  (define input
    (case (current-repl-mode)
      [(sexp) (read-repl-input-sexp)]
      [(ws)   (read-repl-input-ws)]))
  (cond
    [(eof-object? input)
     (displayln "")
     (displayln "Goodbye.")]
    [(not input)
     ;; blank line in ws mode, skip
     (repl-loop)]
    [(string=? (string-trim input) "")
     (repl-loop)]
    [(repl-command? input)
     (handle-repl-command input)
     (repl-loop)]
    [else
     (case (current-repl-mode)
       [(sexp) (process-sexp-input input)]
       [(ws)   (process-ws-input input)])
     (repl-loop)]))

;; ========================================
;; Process input in S-expression mode
;; ========================================
(define (process-sexp-input input)
  (with-handlers
    ([exn:fail? (lambda (e)
                  (displayln (format "Error: ~a" (exn-message e))))])
    (define port (open-input-string input))
    (port-count-lines! port)
    (define stx (prologos-sexp-read-syntax "<repl>" port))
    (unless (eof-object? stx)
      ;; Pre-parse macro expansion
      (define datum (syntax->datum stx))
      (cond
        ;; defmacro — register and consume
        [(and (pair? datum) (eq? (car datum) 'defmacro))
         (process-defmacro datum)
         (displayln "Macro defined.")]
        ;; deftype — register and consume
        [(and (pair? datum) (eq? (car datum) 'deftype))
         (process-deftype datum)
         (displayln "Type alias defined.")]
        [else
         ;; Expand pre-parse macros
         (define expanded-datum (preparse-expand-form datum))
         ;; Preserve original syntax if no change (keeps paren-shape etc.)
         (define expanded-stx
           (if (equal? expanded-datum datum) stx (datum->syntax #f expanded-datum stx)))
         (define surf (parse-datum expanded-stx))
         (if (prologos-error? surf)
             (displayln (format-error surf))
             (let ([result (process-command surf)])
               (if (prologos-error? result)
                   (displayln (format-error result))
                   (displayln result))))]))))

;; ========================================
;; Process input in whitespace mode
;; ========================================
(define (process-ws-input input)
  (with-handlers
    ([exn:fail? (lambda (e)
                  (displayln (format "Error: ~a" (exn-message e))))])
    (define port (open-input-string input))
    (port-count-lines! port)
    ;; Read all forms produced by the whitespace reader
    (define stx (prologos-read-syntax "<repl>" port))
    (let loop ()
      (unless (eof-object? stx)
        ;; Pre-parse macro expansion
        (define datum (syntax->datum stx))
        (cond
          [(and (pair? datum) (eq? (car datum) 'defmacro))
           (process-defmacro datum)
           (displayln "Macro defined.")]
          [(and (pair? datum) (eq? (car datum) 'deftype))
           (process-deftype datum)
           (displayln "Type alias defined.")]
          [else
           (define expanded-datum (preparse-expand-form datum))
           (define expanded-stx
             (if (equal? expanded-datum datum) stx (datum->syntax #f expanded-datum stx)))
           (define surf (parse-datum expanded-stx))
           (if (prologos-error? surf)
               (displayln (format-error surf))
               (let ([result (process-command surf)])
                 (if (prologos-error? result)
                     (displayln (format-error result))
                     (displayln result))))])
        (set! stx (prologos-read-syntax "<repl>" port))
        (loop)))))

;; ========================================
;; Read input in S-expression mode (paren-balanced)
;; ========================================
(define (read-repl-input-sexp)
  (define first-line (read-line))
  (cond
    [(eof-object? first-line) first-line]
    [else
     ;; Check if brackets are balanced
     (let loop ([acc first-line])
       (if (brackets-balanced? acc)
           acc
           (begin
             (display "  ")
             (flush-output)
             (let ([next (read-line)])
               (if (eof-object? next)
                   acc
                   (loop (string-append acc "\n" next)))))))]))

;; ========================================
;; Read input in whitespace mode (blank-line terminated)
;; ========================================
(define (read-repl-input-ws)
  (define first-line (read-line))
  (cond
    [(eof-object? first-line) eof]
    [(string=? (string-trim first-line) "") #f]
    [else
     (let loop ([lines (list first-line)])
       (display "  ")
       (flush-output)
       (define next (read-line))
       (cond
         [(eof-object? next)
          (string-join (reverse lines) "\n")]
         [(string=? (string-trim next) "")
          ;; Blank line terminates the form
          (string-join (reverse lines) "\n")]
         [else
          (loop (cons next lines))]))]))

;; ========================================
;; Bracket balance checker (handles (), [], {})
;; ========================================
(define (brackets-balanced? s)
  (let loop ([chars (string->list s)] [count 0])
    (cond
      [(null? chars) (= count 0)]
      [(memq (car chars) '(#\( #\[ #\{ #\<)) (loop (cdr chars) (+ count 1))]
      [(memq (car chars) '(#\) #\] #\} #\>)) (loop (cdr chars) (- count 1))]
      [else (loop (cdr chars) count)])))

;; ========================================
;; REPL meta-commands
;; ========================================
(define (repl-command? input)
  (string-prefix? (string-trim input) ":"))

(define (handle-repl-command input)
  (define cmd (string-trim input))
  (cond
    [(or (string=? cmd ":quit") (string=? cmd ":q"))
     (displayln "Goodbye.")
     (exit 0)]
    [(string=? cmd ":env")
     (display-env)]
    [(string-prefix? cmd ":mode")
     (let ([mode-str (string-trim (substring cmd 5))])
       (cond
         [(string=? mode-str "sexp")
          (current-repl-mode 'sexp)
          (displayln "Switched to S-expression mode.")]
         [(string=? mode-str "ws")
          (current-repl-mode 'ws)
          (displayln "Switched to whitespace mode. Blank line to submit.")]
         [else
          (displayln "Usage: :mode sexp | :mode ws")]))]
    [(string-prefix? cmd ":load")
     (let ([path (string-trim (substring cmd 5))])
       ;; Strip quotes if present
       (define clean-path
         (if (and (> (string-length path) 1)
                  (char=? (string-ref path 0) #\")
                  (char=? (string-ref path (- (string-length path) 1)) #\"))
             (substring path 1 (- (string-length path) 1))
             path))
       (with-handlers
         ([exn:fail? (lambda (e)
                       (displayln (format "Error loading file: ~a" (exn-message e))))])
         (define results (process-file clean-path))
         (for ([r (in-list results)])
           (if (prologos-error? r)
               (displayln (format-error r))
               (displayln r)))))]
    [(string-prefix? cmd ":type")
     (let ([expr-str (string-trim (substring cmd 5))])
       (define port (open-input-string (format "(infer ~a)" expr-str)))
       (port-count-lines! port)
       (define stx (prologos-sexp-read-syntax "<repl>" port))
       (unless (eof-object? stx)
         (define surf (parse-datum stx))
         (if (prologos-error? surf)
             (displayln (format-error surf))
             (let ([result (process-command surf)])
               (if (prologos-error? result)
                   (displayln (format-error result))
                   (displayln result))))))]
    [else
     (displayln (format "Unknown command: ~a" cmd))]))

;; Display current environment
(define (display-env)
  (define names (global-env-names))
  (if (null? names)
      (displayln "  (no definitions)")
      (for ([name (in-list names)])
        (let ([ty (global-env-lookup-type name)])
          (displayln (format "  ~a : ~a" name (if ty (pp-expr ty) "?")))))))

;; ========================================
;; Entry point
;; ========================================
(module+ main
  (require racket/cmdline)
  (define ws-mode? (make-parameter #f))
  (command-line
   #:once-each
   ["--ws" "Start in whitespace syntax mode"
    (ws-mode? #t)]
   #:args ()
   (when (ws-mode?)
     (current-repl-mode 'ws))
   (run-repl)))
