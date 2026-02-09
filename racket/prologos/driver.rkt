#lang racket/base

;;;
;;; PROLOGOS DRIVER
;;; Processes top-level commands (def, check, eval, infer).
;;; Manages the global definition environment.
;;; Provides module loading for the namespace system.
;;;

(require racket/match
         racket/port
         racket/set
         racket/path
         "prelude.rkt"
         "syntax.rkt"
         "reduction.rkt"
         "typing-core.rkt"
         "source-location.rkt"
         "surface-syntax.rkt"
         "errors.rkt"
         "parser.rkt"
         "elaborator.rkt"
         "pretty-print.rkt"
         "typing-errors.rkt"
         "global-env.rkt"
         "macros.rkt"
         "sexp-readtable.rkt"
         "reader.rkt"
         "namespace.rkt")

(provide process-command
         process-file
         process-string
         load-module
         install-module-loader!)

;; ========================================
;; Process a single top-level command
;; ========================================
;; Returns a result string, or a prologos-error.
;; Side effect: may update current-global-env for 'def'.
;;
;; When a namespace context is active, def stores names both as
;; bare symbols (for local use) and as fully-qualified names (for export).
(define (process-command surf)
  (define expanded (expand-top-level surf))
  (if (prologos-error? expanded)
      expanded
      (let ([elab-result (elaborate-top-level expanded)])
        (if (prologos-error? elab-result)
            elab-result
            (match elab-result
              ;; (def name type body)
              [(list 'def name type body)
               (let ([ty-ok (is-type/err ctx-empty type)])
                 (if (prologos-error? ty-ok) ty-ok
                     (let ([chk (check/err ctx-empty body type)])
                       (if (prologos-error? chk) chk
                           (begin
                             ;; Store under bare name (for local use within the module)
                             (current-global-env
                              (global-env-add (current-global-env) name type body))
                             ;; Also store under fully-qualified name if namespace is active
                             (when (current-ns-context)
                               (define fqn (qualify-name name
                                             (ns-context-current-ns (current-ns-context))))
                               (current-global-env
                                (global-env-add (current-global-env) fqn type body)))
                             (format "~a : ~a defined." name (pp-expr type)))))))]

              ;; (check expr type)
              [(list 'check expr type)
               (let ([chk (check/err ctx-empty expr type)])
                 (if (prologos-error? chk) chk
                     "OK"))]

              ;; (eval expr)
              [(list 'eval expr)
               (let ([ty (infer/err ctx-empty expr)])
                 (if (prologos-error? ty) ty
                     (let ([val (nf expr)]
                           [ty-nf (nf ty)])
                       (format "~a : ~a" (pp-expr val) (pp-expr ty-nf)))))]

              ;; (infer expr)
              [(list 'infer expr)
               (let ([ty (infer/err ctx-empty expr)])
                 (if (prologos-error? ty) ty
                     (pp-expr ty)))]

              [_ (prologos-error srcloc-unknown (format "Unknown command: ~a" elab-result))])))))

;; ========================================
;; Read all syntax objects from a port
;; ========================================
(define (read-all-syntax port [source "<port>"])
  (port-count-lines! port)
  (let loop ([acc '()])
    (define stx (prologos-sexp-read-syntax source port))
    (if (eof-object? stx)
        (reverse acc)
        (loop (cons stx acc)))))

;; Read all syntax objects using the whitespace-significant reader
(define (read-all-syntax-ws port [source "<port>"])
  (port-count-lines! port)
  (prologos-read-syntax-all source port))

;; ========================================
;; Process all commands from a string
;; ========================================
(define (process-string s)
  (define port (open-input-string s))
  ;; Read raw syntax, apply pre-parse expansion, then parse
  (define raw-stxs (read-all-syntax port "<string>"))
  (define expanded-stxs (preparse-expand-all raw-stxs))
  (define surfs (map parse-datum expanded-stxs))
  (for/list ([surf (in-list surfs)])
    (if (prologos-error? surf)
        surf
        (process-command surf))))

;; ========================================
;; Process all commands from a file
;; ========================================
(define (process-file path)
  (define port (open-input-file path))
  ;; Read raw syntax, apply pre-parse expansion, then parse
  (define raw-stxs (read-all-syntax port path))
  (close-input-port port)
  (define expanded-stxs (preparse-expand-all raw-stxs))
  (define surfs (map parse-datum expanded-stxs))
  (for/list ([surf (in-list surfs)])
    (if (prologos-error? surf)
        surf
        (process-command surf))))

;; ========================================
;; Module Loading
;; ========================================

;; Load a module from a namespace symbol.
;; Returns a module-info, or raises an error.
;;
;; Steps:
;;   1. Check module registry cache
;;   2. Check for circular dependencies
;;   3. Resolve namespace to file path
;;   4. Process the file in a fresh environment
;;   5. Build module-info from resulting definitions
;;   6. Register in module registry
(define (load-module ns-sym base-dir)
  ;; 1. Check cache
  (define cached (lookup-module ns-sym))
  (when cached (begin cached))
  (when cached cached)

  ;; Actually return early if cached
  (cond
    [cached cached]
    [else
     ;; 2. Check for circular dependencies
     (when (set-member? (current-loading-set) ns-sym)
       (error 'require "Circular dependency detected: ~a" ns-sym))

     ;; 3. Resolve to file path
     (define file-path
       (resolve-ns-path ns-sym base-dir))
     (unless file-path
       (error 'require "Cannot find module: ~a (searched lib paths: ~a)"
              ns-sym (current-lib-paths)))

     ;; 4. Process the file in a fresh environment
     (define mod-env #f)
     (define mod-ns-ctx #f)

     (parameterize ([current-global-env (hasheq)]
                    [current-ns-context #f]
                    [current-preparse-registry (current-preparse-registry)]
                    [current-loading-set (set-add (current-loading-set) ns-sym)])
       ;; Read and process the file
       ;; Use WS reader for .prologos files, sexp reader otherwise
       (define port (open-input-file file-path))
       (define file-str (path->string file-path))
       (define raw-stxs
         (if (regexp-match? #rx"\\.prologos$" file-str)
             (read-all-syntax-ws port file-str)
             (read-all-syntax port file-str)))
       (close-input-port port)
       (define expanded-stxs (preparse-expand-all raw-stxs))
       (define surfs (map parse-datum expanded-stxs))
       (for ([surf (in-list surfs)])
         (unless (prologos-error? surf)
           (define result (process-command surf))
           (when (prologos-error? result)
             (error 'require "Error loading module ~a: ~a"
                    ns-sym (prologos-error-message result)))))

       ;; Capture the resulting environment and namespace context
       (set! mod-env (current-global-env))
       (set! mod-ns-ctx (current-ns-context)))

     ;; 5. Build module-info
     (define exports
       (if (and mod-ns-ctx (ns-context-exports mod-ns-ctx))
           (let ([exp (ns-context-exports mod-ns-ctx)])
             (cond
               ;; :all — export everything defined in the namespace
               [(and (pair? exp) (eq? (car exp) ':all))
                (for/list ([(k _) (in-hash mod-env)]
                           #:when (let-values ([(prefix name) (split-qualified-name k)])
                                    (and prefix (eq? prefix ns-sym))))
                  (let-values ([(_ name) (split-qualified-name k)])
                    name))]
               [else exp]))
           ;; No provide — export nothing (or we could default to all?)
           '()))

     (define mi (module-info ns-sym
                             exports
                             mod-env
                             file-path
                             (hasheq)
                             (hasheq)))

     ;; 6. Register
     (register-module! ns-sym mi)

     ;; 7. Import module's fqn definitions into the CALLER's global env
     (for ([short-name (in-list exports)])
       (define fqn (qualify-name short-name ns-sym))
       (define entry (hash-ref mod-env fqn #f))
       ;; Also try bare name if fqn not found
       (define entry* (or entry (hash-ref mod-env short-name #f)))
       (when entry*
         (current-global-env
          (hash-set (current-global-env) fqn entry*))))

     mi]))

;; ========================================
;; Install the module loader callback
;; ========================================
;; Call this at startup to wire up the namespace system.
(define (install-module-loader!)
  (current-module-loader load-module))

;; Auto-install on module load
(install-module-loader!)
