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
         "sexp-readtable.rkt"
         "trait-resolution.rkt")

(provide run-repl
         current-repl-mode)

;; ========================================
;; Mode parameter
;; ========================================
(define current-repl-mode (make-parameter 'ws))

;; ========================================
;; REPL Main Loop
;; ========================================
(define (run-repl)
  (displayln "Prologos v0.3.0")
  (displayln ":quit to exit | :env | :load | :type | :expand | :macros | :specs | :instances | :methods | :satisfies")
  (newline)
  ;; Start with empty global env
  (parameterize ([current-global-env (hasheq)])
    (repl-loop)))

(define (repl-loop)
  (display "> ")
  (flush-output)
  (define input (read-repl-input-ws))
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
     (process-ws-input input)
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
;; Note: <> are NOT counted — the > in -> would cause false imbalance.
;; ========================================
(define (brackets-balanced? s)
  (let loop ([chars (string->list s)] [count 0])
    (cond
      [(null? chars) (= count 0)]
      [(memq (car chars) '(#\( #\[ #\{)) (loop (cdr chars) (+ count 1))]
      [(memq (car chars) '(#\) #\] #\})) (loop (cdr chars) (- count 1))]
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
       (define stx (prologos-sexp-read-syntax "<repl>" port))
       (unless (eof-object? stx)
         (define surf (parse-datum stx))
         (if (prologos-error? surf)
             (displayln (format-error surf))
             (let ([result (process-command surf)])
               (if (prologos-error? result)
                   (displayln (format-error result))
                   (displayln result))))))]
    ;; :expand-full must come before :expand (string-prefix? overlap)
    [(string-prefix? cmd ":expand-full")
     (let ([expr-str (string-trim (substring cmd 12))])
       (with-handlers ([exn:fail? (lambda (e)
                                    (displayln (format "Error: ~a" (exn-message e))))])
         (define port (open-input-string (format "(expand-full ~a)" expr-str)))
         (port-count-lines! port)
         (define stx (prologos-sexp-read-syntax "<repl>" port))
         (unless (eof-object? stx)
           (define surf (parse-datum stx))
           (if (prologos-error? surf)
               (displayln (format-error surf))
               (let ([result (process-command surf)])
                 (if (prologos-error? result)
                     (displayln (format-error result))
                     (displayln result)))))))]
    ;; :expand-1 must come before :expand (string-prefix? overlap)
    [(string-prefix? cmd ":expand-1")
     (let ([expr-str (string-trim (substring cmd 9))])
       (with-handlers ([exn:fail? (lambda (e)
                                    (displayln (format "Error: ~a" (exn-message e))))])
         (define port (open-input-string (format "(expand-1 ~a)" expr-str)))
         (port-count-lines! port)
         (define stx (prologos-sexp-read-syntax "<repl>" port))
         (unless (eof-object? stx)
           (define surf (parse-datum stx))
           (if (prologos-error? surf)
               (displayln (format-error surf))
               (let ([result (process-command surf)])
                 (if (prologos-error? result)
                     (displayln (format-error result))
                     (displayln result)))))))]
    [(string-prefix? cmd ":expand")
     (let ([expr-str (string-trim (substring cmd 7))])
       (with-handlers ([exn:fail? (lambda (e)
                                    (displayln (format "Error: ~a" (exn-message e))))])
         (define port (open-input-string (format "(expand ~a)" expr-str)))
         (port-count-lines! port)
         (define stx (prologos-sexp-read-syntax "<repl>" port))
         (unless (eof-object? stx)
           (define surf (parse-datum stx))
           (if (prologos-error? surf)
               (displayln (format-error surf))
               (let ([result (process-command surf)])
                 (if (prologos-error? result)
                     (displayln (format-error result))
                     (displayln result)))))))]
    [(string=? cmd ":macros")
     (define reg (current-preparse-registry))
     (if (hash-empty? reg)
         (displayln "  (no macros registered)")
         (for ([(name entry) (in-hash reg)])
           (cond
             [(preparse-macro? entry)
              (displayln (format "  ~a  (pattern -> template)" name))]
             [(procedure? entry)
              (displayln (format "  ~a  (procedural)" name))]
             [else
              (displayln (format "  ~a" name))])))]
    [(string=? cmd ":specs")
     (define store (current-spec-store))
     (if (hash-empty? store)
         (displayln "  (no specs registered)")
         (for ([(name entry) (in-hash store)])
           (define types (spec-entry-type-datums entry))
           (displayln
            (format "  spec ~a ~a"
                    name
                    (string-join
                     (map (lambda (clause)
                            (string-join (map (lambda (t) (format "~s" t)) clause) " "))
                          types)
                     " | ")))))]
    ;; Phase 3b: Trait introspection commands
    [(string-prefix? cmd ":instances")
     (let ([trait-str (string-trim (substring cmd 10))])
       (if (string=? trait-str "")
           ;; List all registered traits
           (let ([reg (current-trait-registry)])
             (if (hash-empty? reg)
                 (displayln "  (no traits registered)")
                 (for ([(name _) (in-hash reg)])
                   (displayln (format "  ~a" name)))))
           ;; List instances of specific trait
           (let ([trait-name (string->symbol trait-str)])
             (define impl-reg (read-impl-registry))
             (define param-reg (current-param-impl-registry))
             (define mono-instances
               (for/list ([(key entry) (in-hash impl-reg)]
                          #:when (eq? (impl-entry-trait-name entry) trait-name))
                 (impl-entry-type-args entry)))
             (define param-instances (hash-ref param-reg trait-name '()))
             (if (and (null? mono-instances) (null? param-instances))
                 (displayln (format "  No instances found for trait ~a" trait-name))
                 (begin
                   (for ([ta (in-list mono-instances)])
                     (displayln (format "  ~a"
                       (string-join (map (lambda (t) (format "~a" t)) ta) " "))))
                   (for ([pe (in-list param-instances)])
                     (displayln (format "  ~a (parametric)"
                       (string-join
                        (map (lambda (t) (format "~a" t))
                             (param-impl-entry-type-pattern pe))
                        " ")))))))))]

    [(string-prefix? cmd ":methods")
     (let ([trait-str (string-trim (substring cmd 8))])
       (if (string=? trait-str "")
           (displayln "Usage: :methods TraitName")
           (let ([trait-name (string->symbol trait-str)])
             (define tm (lookup-trait trait-name))
             (if (not tm)
                 (displayln (format "  No trait found: ~a" trait-name))
                 (let ([methods (trait-meta-methods tm)])
                   (if (null? methods)
                       (displayln (format "  Trait ~a has no methods." trait-name))
                       (for ([m (in-list methods)])
                         (displayln (format "  ~a : ~a"
                           (trait-method-name m)
                           (pp-datum (trait-method-type-datum m)))))))))))]

    [(string-prefix? cmd ":satisfies")
     (let ([args-str (string-trim (substring cmd 10))])
       (define parts (string-split args-str))
       (cond
         [(< (length parts) 2)
          (displayln "Usage: :satisfies TypeName TraitName")]
         [else
          (define type-name (string->symbol (car parts)))
          (define trait-name (string->symbol (cadr parts)))
          (define impl-reg (read-impl-registry))
          (define param-reg (current-param-impl-registry))
          (define mono-key
            (string->symbol (format "~a--~a" type-name trait-name)))
          (define mono? (hash-has-key? impl-reg mono-key))
          (define param?
            (let ([entries (hash-ref param-reg trait-name '())])
              (ormap (lambda (pe)
                       (let ([pattern (param-impl-entry-type-pattern pe)])
                         (and (pair? pattern)
                              (eq? (car pattern) type-name))))
                     entries)))
          (displayln (format "  ~a satisfies ~a: ~a"
                             type-name trait-name (if (or mono? param?) "true" "false")))]))]

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
