#lang racket/base

;;;
;;; PROLOGOS REPL
;;; Interactive read-eval-type-check loop.
;;;

(require racket/string
         "source-location.rkt"
         "errors.rkt"
         "parser.rkt"
         "driver.rkt"
         "pretty-print.rkt"
         "global-env.rkt")

(provide run-repl)

;; ========================================
;; REPL Main Loop
;; ========================================
(define (run-repl)
  (displayln "Prologos v0.2.0")
  (displayln "Type :quit to exit, :env to see definitions, :load \"file\" to load a file.")
  (newline)
  ;; Start with empty global env
  (parameterize ([current-global-env (hasheq)])
    (repl-loop)))

(define (repl-loop)
  (display "> ")
  (flush-output)
  (define input (read-repl-input))
  (cond
    [(eof-object? input)
     (displayln "")
     (displayln "Goodbye.")]
    [(string=? (string-trim input) "")
     (repl-loop)]
    [(repl-command? input)
     (handle-repl-command input)
     (repl-loop)]
    [else
     (with-handlers
       ([exn:fail? (lambda (e)
                     (displayln (format "Error: ~a" (exn-message e))))])
       (define port (open-input-string input))
       (port-count-lines! port)
       (define stx (read-syntax "<repl>" port))
       (unless (eof-object? stx)
         (define surf (parse-datum stx))
         (if (prologos-error? surf)
             (displayln (format-error surf))
             (let ([result (process-command surf)])
               (if (prologos-error? result)
                   (displayln (format-error result))
                   (displayln result))))))
     (repl-loop)]))

;; ========================================
;; Read input with multi-line support
;; ========================================
(define (read-repl-input)
  (define first-line (read-line))
  (cond
    [(eof-object? first-line) first-line]
    [else
     ;; Check if parens are balanced
     (let loop ([acc first-line])
       (if (parens-balanced? acc)
           acc
           (begin
             (display "  ")
             (flush-output)
             (let ([next (read-line)])
               (if (eof-object? next)
                   acc  ; return what we have
                   (loop (string-append acc "\n" next)))))))]))

;; Simple paren balance checker
(define (parens-balanced? s)
  (let loop ([chars (string->list s)] [count 0])
    (cond
      [(null? chars) (= count 0)]
      [(char=? (car chars) #\() (loop (cdr chars) (+ count 1))]
      [(char=? (car chars) #\)) (loop (cdr chars) (- count 1))]
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
       (define stx (read-syntax "<repl>" port))
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
  (run-repl))
