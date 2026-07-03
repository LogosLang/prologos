#lang racket/base

;;;
;;; PROLOGOS REPL
;;; Interactive read-eval-type-check loop.
;;; Supports two modes:
;;;   - sexp: S-expression syntax (default)
;;;   - ws:   Whitespace syntax (blank line to submit)
;;;

(require racket/string
         racket/port          ;; open-output-nowhere, port->string (gh #73 session)
         racket/path          ;; path-only (gh #73 lib-dir resolution)
         "source-location.rkt"
         "errors.rkt"
         "parser.rkt"
         "driver.rkt"
         "pretty-print.rkt"
         "global-env.rkt"
         "parse-reader.rkt"  ;; prologos-read-syntax (sexp mode)
         "macros.rkt"
         "sexp-readtable.rkt"
         "namespace.rkt"      ;; current-module-registry / current-ns-context / current-lib-paths (gh #73)
         "trait-resolution.rkt")

(provide run-repl
         current-repl-mode
         make-repl-session    ;; gh #73: testable session entry points
         repl-eval!)

;; ========================================
;; Mode parameter
;; ========================================
(define current-repl-mode (make-parameter 'ws))

;; ========================================
;; Persistent REPL session (gh #73)
;; ----------------------------------------
;; Mirrors lsp/server.rkt `eval-in-session-raw!`: the ns/module/def context
;; lives in a session that survives across evals. Each input `parameterize`s
;; the 9 context params FROM the session, runs the full WS pipeline via
;; `process-string-ws` (which consumes `ns` AND runs preparse Pass -1 — fixing
;; BOTH the persistence loss and the bare-`ns` error), then snapshots the
;; mutated params BACK. stdout/stderr → nowhere suppresses PERF/PHASE telemetry.
;; (Path B per gh #73: replicated here rather than extracting a shared module,
;;  to leave the working LSP untouched; a shared `repl-session.rkt` is filed
;;  as a follow-up.)
;; ========================================

(struct repl-session
  (ns-context module-registry trait-registry impl-registry param-impl-registry
   preparse-registry capability-registry spec-store mnr) #:mutable)

;; Prelude loaded once, cached (registries + lib-dir).
(struct prelude-snap
  (module-registry trait-registry impl-registry param-impl-registry
   preparse-registry capability-registry lib-dir) #:transparent)

(define cached-prelude (box #f))

;; Load the prelude once and capture its registries (mirrors
;; lsp/server.rkt `load-prelude-cache!`, minus the LSP observatory cache).
(define (load-prelude!)
  (or (unbox cached-prelude)
      (let ()
        (define here-dir (path->string (path-only (syntax-source #'here))))
        (define lib-dir (simplify-path (build-path here-dir "lib")))
        (define-values (mr tr ir pir prr cr)
          (parameterize ([current-file-module-network-ref (make-module-network)]
                         [current-ns-context #f]
                         [current-module-registry (hasheq)]
                         [current-lib-paths (list lib-dir)]
                         [current-preparse-registry (current-preparse-registry)]
                         [current-trait-registry (current-trait-registry)]
                         [current-impl-registry (current-impl-registry)]
                         [current-param-impl-registry (current-param-impl-registry)]
                         [current-capability-registry (current-capability-registry)]
                         [current-output-port (open-output-nowhere)]
                         [current-error-port (open-output-nowhere)])
            (install-module-loader!)
            (process-string "(ns prelude-cache)\n")
            (values (current-module-registry)
                    (current-trait-registry)
                    (current-impl-registry)
                    (current-param-impl-registry)
                    (current-preparse-registry)
                    (current-capability-registry))))
        (define snap (prelude-snap mr tr ir pir prr cr lib-dir))
        (set-box! cached-prelude snap)
        snap)))

;; Create a fresh REPL session seeded from the cached prelude, with the working
;; namespace established (`ns repl`), mirroring the LSP's get-or-create-session!.
(define (make-repl-session)
  (define pc (load-prelude!))
  (define session
    (repl-session #f
                  (prelude-snap-module-registry pc)
                  (prelude-snap-trait-registry pc)
                  (prelude-snap-impl-registry pc)
                  (prelude-snap-param-impl-registry pc)
                  (prelude-snap-preparse-registry pc)
                  (prelude-snap-capability-registry pc)
                  (hasheq)
                  (make-module-network)))
  (repl-eval! session "(ns repl)\n")
  session)

;; Evaluate `code` in `session`: parameterize the 9 params from the session,
;; run `process-string-ws`, snapshot the mutated params back. Returns the raw
;; result list (formatted strings and/or prologos-error structs).
(define (repl-eval! session code)
  (define results '())
  (with-handlers
    ([exn:fail? (lambda (e) (set! results (list (prologos-error #f (exn-message e)))))])
    (parameterize ([current-file-module-network-ref
                    (or (repl-session-mnr session) (make-module-network))]
                   [current-ns-context           (repl-session-ns-context session)]
                   [current-module-registry      (repl-session-module-registry session)]
                   [current-lib-paths            (list (prelude-snap-lib-dir (load-prelude!)))]
                   [current-preparse-registry    (repl-session-preparse-registry session)]
                   [current-trait-registry       (repl-session-trait-registry session)]
                   [current-impl-registry        (repl-session-impl-registry session)]
                   [current-param-impl-registry  (repl-session-param-impl-registry session)]
                   [current-capability-registry  (repl-session-capability-registry session)]
                   [current-spec-store           (repl-session-spec-store session)]
                   [current-error-port           (open-output-nowhere)]
                   [current-output-port          (open-output-nowhere)]
                   [current-definition-locations (hasheq)])
      (install-module-loader!)
      (set! results (process-string-ws code))
      (set-repl-session-mnr!                 session (current-file-module-network-ref))
      (set-repl-session-ns-context!          session (current-ns-context))
      (set-repl-session-module-registry!     session (current-module-registry))
      (set-repl-session-trait-registry!      session (current-trait-registry))
      (set-repl-session-impl-registry!       session (current-impl-registry))
      (set-repl-session-param-impl-registry! session (current-param-impl-registry))
      (set-repl-session-preparse-registry!   session (current-preparse-registry))
      (set-repl-session-capability-registry! session (current-capability-registry))
      (set-repl-session-spec-store!          session (current-spec-store))))
  results)

;; The interactive loop's single session (lazily initialized on first use).
(define interactive-session (box #f))
(define (get-interactive-session!)
  (or (unbox interactive-session)
      (let ([s (make-repl-session)]) (set-box! interactive-session s) s)))

;; Display a result list from repl-eval!.
(define (display-repl-results results)
  (for ([r (in-list results)])
    (cond
      [(prologos-error? r) (displayln (format-error r))]
      [(string? r)         (displayln r)]
      [else                (displayln (format "~a" r))])))

;; ========================================
;; REPL Main Loop
;; ========================================
(define (run-repl)
  (displayln "Prologos v0.3.0")
  (displayln ":quit to exit | :env | :load | :type | :expand | :macros | :specs | :instances | :methods | :satisfies")
  (newline)
  ;; The mnr is lazy-init'd on the first def (global-env-add); resolution reads its cascade.
  (repl-loop))

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
  ;; gh #73: route through the persistent session. `process-string-ws` consumes
  ;; `ns` (Bug B) and runs the full pipeline; the session persists ns/def
  ;; context across inputs (Bug A). Replaces the old per-form process-command loop.
  (display-repl-results (repl-eval! (get-interactive-session!) input)))

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
         ;; gh #73: load through the session (read → process-string-ws in
         ;; session), like the LSP's loadFile, so loaded defs persist into
         ;; subsequent evals (was `process-file`, whose parameterize unwound).
         (define contents (call-with-input-file clean-path port->string))
         (display-repl-results (repl-eval! (get-interactive-session!) contents))))]
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
             ;; Track 6 Phase 8b: read from parameter (REPL runs outside elaboration)
             (define impl-reg (current-impl-registry))
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
          ;; Track 6 Phase 8b: read from parameter (REPL runs outside elaboration)
          (define impl-reg (current-impl-registry))
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
