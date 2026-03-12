#lang racket/base

;;; server.rkt — Prologos LSP server main loop
;;;
;;; Thin event pump over JSON-RPC:
;;; 1. Read message from stdin
;;; 2. Dispatch to handler
;;; 3. Write response (if request, not notification)
;;; 4. Publish any changed diagnostics
;;;
;;; Tier 2 scope: diagnostics on save, go-to-definition, document symbols.
;;; No propagator network yet — uses process-file directly.

(require racket/match
         racket/path
         racket/list
         racket/string
         racket/file
         racket/port
         (only-in json json-null)
         "json-rpc.rkt"
         "diagnostics.rkt"
         "../driver.rkt"
         "../errors.rkt"
         "../namespace.rkt"
         "../source-location.rkt"
         "../global-env.rkt"
         "../pretty-print.rkt"
         "../macros.rkt"
         "../metavar-store.rkt"
         "../propagator.rkt"
         "../elaborator-network.rkt"
         "../trace-serialize.rkt")

(provide run-lsp-server)

;; ============================================================
;; Server state
;; ============================================================

;; Mutable server state. Tier 2: simple model — re-elaborate on each save.
;; Tier 3+ will replace this with propagator network cells.
(struct lsp-state
  (initialized?           ; boolean
   root-uri               ; string or #f
   document-contents      ; hash: uri → string (open document contents)
   document-diagnostics   ; hash: uri → (listof diagnostic)
   module-registry        ; cached module registry from prelude
   log-port               ; output port for logging (stderr)
   definition-locations   ; hash: uri → (hasheq: symbol → srcloc)
   type-envs              ; hash: uri → hasheq (global-env snapshot for hover)
   repl-sessions          ; hash: uri → repl-session
   prelude-cache          ; prelude-cache struct or #f (loaded lazily)
   spec-stores            ; hash: uri → hasheq (spec-store snapshot for hover/InfoView)
   prop-traces            ; hash: uri → jsexpr (serialized prop-trace for visualization)
   ) #:mutable)

(define (make-initial-state)
  (lsp-state #f       ; not initialized
             #f       ; no root URI
             (make-hash)
             (make-hash)
             #f       ; module registry loaded on initialize
             (current-error-port)
             (make-hash)
             (make-hash)
             (make-hash)
             #f       ; prelude cache loaded on first eval
             (make-hash)
             (make-hash)  ; prop-traces
             ))

;; ============================================================
;; Tier 4: REPL sessions
;; ============================================================

;; Cached prelude registries (loaded once, shared across sessions).
(struct prelude-cache
  (module-registry
   trait-registry
   impl-registry
   param-impl-registry
   preparse-registry
   capability-registry
   lib-dir) #:transparent)

;; Per-URI REPL session state. Definitions accumulate across evals.
(struct repl-session
  (global-env              ; hasheq: name → (cons type value)
   ns-context              ; ns-context or #f
   module-registry         ; hasheq: ns-sym → module-info
   trait-registry          ; hasheq
   impl-registry           ; hasheq
   param-impl-registry     ; hasheq
   preparse-registry       ; hasheq
   capability-registry     ; hasheq
   spec-store              ; hasheq
   definition-cells        ; hasheq (Phase 3a)
   definition-deps         ; hasheq (Phase 3b)
   ) #:mutable)

;; Load prelude once and cache registries (mirrors test-support.rkt pattern).
(define (load-prelude-cache! state)
  (define cache (lsp-state-prelude-cache state))
  (when (not cache)
    (lsp-log state "Loading prelude for REPL sessions...")
    ;; Compute lib-dir relative to server.rkt location
    (define here-dir
      (path->string (path-only (syntax-source #'here))))
    (define lib-dir
      (simplify-path (build-path here-dir ".." "lib")))
    (define-values (mod-reg trait-reg impl-reg param-impl-reg preparse-reg cap-reg)
      (parameterize ([current-global-env (hasheq)]
                     [current-definition-cells-content (hasheq)]
                     [current-definition-dependencies (hasheq)]
                     [current-ns-context #f]
                     [current-module-registry (hasheq)]
                     [current-lib-paths (list lib-dir)]
                     [current-mult-meta-store (make-hasheq)]
                     [current-preparse-registry (current-preparse-registry)]
                     [current-trait-registry (current-trait-registry)]
                     [current-impl-registry (current-impl-registry)]
                     [current-param-impl-registry (current-param-impl-registry)]
                     [current-capability-registry (current-capability-registry)]
                     [current-error-port (open-output-nowhere)])
        (install-module-loader!)
        (process-string "(ns prelude-cache)\n")
        (values (current-module-registry)
                (current-trait-registry)
                (current-impl-registry)
                (current-param-impl-registry)
                (current-preparse-registry)
                (current-capability-registry))))
    (set-lsp-state-prelude-cache!
     state
     (prelude-cache mod-reg trait-reg impl-reg param-impl-reg preparse-reg cap-reg lib-dir))
    (lsp-log state "Prelude loaded (~a modules cached)" (hash-count mod-reg))))

;; Get or create a REPL session for a URI.
(define (get-or-create-session! state uri)
  (define sessions (lsp-state-repl-sessions state))
  (define existing (hash-ref sessions uri #f))
  (cond
    [existing existing]
    [else
     (load-prelude-cache! state)
     (define pc (lsp-state-prelude-cache state))
     (define session
       (repl-session
        (hasheq)                                    ; global-env (fresh)
        #f                                          ; ns-context
        (prelude-cache-module-registry pc)           ; module-registry
        (prelude-cache-trait-registry pc)             ; trait-registry
        (prelude-cache-impl-registry pc)              ; impl-registry
        (prelude-cache-param-impl-registry pc)        ; param-impl-registry
        (prelude-cache-preparse-registry pc)           ; preparse-registry
        (prelude-cache-capability-registry pc)         ; capability-registry
        (hasheq)                                    ; spec-store
        (hasheq)                                    ; definition-cells (Phase 3a)
        (hasheq)))                                  ; definition-deps (Phase 3b)
     ;; Initialize the session with a namespace declaration to load prelude
     (eval-in-session-raw! state session "(ns repl)\n")
     (hash-set! sessions uri session)
     (lsp-log state "Created REPL session for ~a" uri)
     session]))

;; Evaluate code in a REPL session. Returns a list of result hasheqs.
(define (eval-in-session! state session code)
  (define raw-results (eval-in-session-raw! state session code))
  ;; Format results for LSP response
  (for/list ([r (in-list raw-results)])
    (cond
      [(prologos-error? r)
       (hasheq 'text (prologos-error-message r)
               'isError #t)]
      [(string? r)
       (hasheq 'text r
               'isError #f)]
      [else
       (hasheq 'text (format "~a" r)
               'isError #f)])))

;; Low-level eval: parameterize with session state, call process-string-ws,
;; snapshot state back. Returns raw results (strings and prologos-errors).
(define (eval-in-session-raw! state session code)
  (define pc (lsp-state-prelude-cache state))
  (define results '())
  (with-handlers
    ([exn:fail?
      (lambda (e)
        (set! results (list (prologos-error #f (exn-message e)))))])
    (parameterize ([current-global-env           (repl-session-global-env session)]
                   [current-definition-cells-content (repl-session-definition-cells session)]
                   [current-definition-dependencies  (repl-session-definition-deps session)]
                   [current-ns-context           (repl-session-ns-context session)]
                   [current-module-registry       (repl-session-module-registry session)]
                   [current-lib-paths             (list (prelude-cache-lib-dir pc))]
                   [current-mult-meta-store       (make-hasheq)]
                   [current-preparse-registry     (repl-session-preparse-registry session)]
                   [current-trait-registry         (repl-session-trait-registry session)]
                   [current-impl-registry          (repl-session-impl-registry session)]
                   [current-param-impl-registry    (repl-session-param-impl-registry session)]
                   [current-capability-registry    (repl-session-capability-registry session)]
                   [current-spec-store             (repl-session-spec-store session)]
                   [current-error-port             (open-output-nowhere)]
                   [current-definition-locations   (hasheq)])
      (install-module-loader!)
      (set! results (process-string-ws code))
      ;; Snapshot state back into session (definitions accumulate)
      (set-repl-session-global-env!           session (current-global-env))
      (set-repl-session-ns-context!           session (current-ns-context))
      (set-repl-session-module-registry!      session (current-module-registry))
      (set-repl-session-trait-registry!        session (current-trait-registry))
      (set-repl-session-impl-registry!         session (current-impl-registry))
      (set-repl-session-param-impl-registry!   session (current-param-impl-registry))
      (set-repl-session-preparse-registry!      session (current-preparse-registry))
      (set-repl-session-capability-registry!    session (current-capability-registry))
      (set-repl-session-spec-store!             session (current-spec-store))
      (set-repl-session-definition-cells!       session (current-definition-cells-content))
      (set-repl-session-definition-deps!        session (current-definition-dependencies))))
  results)

;; Log a message to stderr (not stdout — stdout is the LSP channel).
(define (lsp-log state fmt . args)
  (fprintf (lsp-state-log-port state)
           "[prologos-lsp] ~a\n"
           (apply format fmt args))
  (flush-output (lsp-state-log-port state)))

;; ============================================================
;; Main loop
;; ============================================================

(define (run-lsp-server)
  (define state (make-initial-state))
  (lsp-log state "Prologos LSP server starting")
  (let loop ()
    (define msg (read-message (current-input-port)))
    (cond
      [(not msg)
       (lsp-log state "EOF received, shutting down")]
      [else
       (handle-message! state msg)
       (loop)])))

;; ============================================================
;; Message dispatch
;; ============================================================

(define (handle-message! state msg)
  (define method (hash-ref msg 'method #f))
  (define id     (hash-ref msg 'id #f))
  (define params (hash-ref msg 'params (hasheq)))

  (define (respond! result)
    (when id
      (write-message (current-output-port) (make-response id result))))

  (define (respond-error! code message)
    (when id
      (write-message (current-output-port) (make-error-response id code message))))

  (define (notify! method params)
    (write-message (current-output-port) (make-notification method params)))

  (match method
    ;; ---- Lifecycle ----
    ["initialize"
     (lsp-log state "Initialize request received")
     (set-lsp-state-root-uri! state (hash-ref params 'rootUri #f))
     (set-lsp-state-initialized?! state #t)
     (respond! (initialize-result))]

    ["initialized"
     (lsp-log state "Client initialized")]

    ["shutdown"
     (lsp-log state "Shutdown request")
     (respond! (json-null))]

    ["exit"
     (lsp-log state "Exit notification")
     (exit 0)]

    ;; ---- Document sync ----
    ["textDocument/didOpen"
     (define uri  (hash-ref (hash-ref params 'textDocument) 'uri))
     (define text (hash-ref (hash-ref params 'textDocument) 'text))
     (lsp-log state "didOpen: ~a" uri)
     (hash-set! (lsp-state-document-contents state) uri text)
     (elaborate-and-publish-diagnostics! state uri text notify!)]

    ["textDocument/didChange"
     (define uri  (hash-ref (hash-ref params 'textDocument) 'uri))
     ;; Full sync: take the last content change
     (define changes (hash-ref params 'contentChanges))
     (when (and (list? changes) (not (null? changes)))
       (define text (hash-ref (last changes) 'text))
       (hash-set! (lsp-state-document-contents state) uri text))]

    ["textDocument/didSave"
     (define uri (hash-ref (hash-ref params 'textDocument) 'uri))
     (lsp-log state "didSave: ~a" uri)
     (define text (or (hash-ref params 'text #f)
                      (hash-ref (lsp-state-document-contents state) uri #f)))
     (when text
       (elaborate-and-publish-diagnostics! state uri text notify!))]

    ["textDocument/didClose"
     (define uri (hash-ref (hash-ref params 'textDocument) 'uri))
     (lsp-log state "didClose: ~a" uri)
     (hash-remove! (lsp-state-document-contents state) uri)
     ;; Clear diagnostics for closed document
     (notify! "textDocument/publishDiagnostics"
              (hasheq 'uri uri 'diagnostics '()))]

    ;; ---- Document symbols ----
    ["textDocument/documentSymbol"
     (define uri (hash-ref (hash-ref params 'textDocument) 'uri))
     (respond! (get-document-symbols state uri))]

    ;; ---- Go-to-definition ----
    ["textDocument/definition"
     (define uri (hash-ref (hash-ref params 'textDocument) 'uri))
     (define pos (hash-ref params 'position))
     (define line (hash-ref pos 'line))
     (define char (hash-ref pos 'character))
     (respond! (get-definition-location state uri line char))]

    ;; ---- Signature help ----
    ["textDocument/signatureHelp"
     (define uri (hash-ref (hash-ref params 'textDocument) 'uri))
     (define pos (hash-ref params 'position))
     (define line (hash-ref pos 'line))
     (define char (hash-ref pos 'character))
     (respond! (get-signature-help state uri line char))]

    ;; ---- Hover ----
    ["textDocument/hover"
     (define uri (hash-ref (hash-ref params 'textDocument) 'uri))
     (define pos (hash-ref params 'position))
     (define line (hash-ref pos 'line))
     (define char (hash-ref pos 'character))
     (respond! (get-hover-info state uri line char))]

    ;; ---- Completion ----
    ["textDocument/completion"
     (define uri (hash-ref (hash-ref params 'textDocument) 'uri))
     (define pos (hash-ref params 'position))
     (define line (hash-ref pos 'line))
     (define char (hash-ref pos 'character))
     (respond! (get-completions state uri line char))]

    ;; ---- REPL: Evaluate (Tier 4) ----
    ["$/prologos/eval"
     (define uri  (hash-ref params 'uri ""))
     (define code (hash-ref params 'code ""))
     (lsp-log state "REPL eval (~a bytes) for ~a" (string-length code) uri)
     (define session (get-or-create-session! state uri))
     (define results (eval-in-session! state session code))
     (respond! (hasheq 'results results))]

    ;; ---- REPL: Load file (Tier 4) ----
    ["$/prologos/loadFile"
     (define uri  (hash-ref params 'uri ""))
     (define code (hash-ref params 'code ""))
     (lsp-log state "REPL loadFile for ~a" uri)
     (define session (get-or-create-session! state uri))
     (define results (eval-in-session! state session code))
     (respond! (hasheq 'results results))]

    ;; ---- REPL: Type of expression (Tier 4) ----
    ["$/prologos/typeOf"
     (define uri  (hash-ref params 'uri ""))
     (define code (hash-ref params 'code ""))
     (lsp-log state "REPL typeOf: ~a" code)
     (define session (get-or-create-session! state uri))
     ;; Try global-env lookup first, then wrap in infer
     (define sym (string->symbol code))
     (define entry (hash-ref (repl-session-global-env session) sym #f))
     (cond
       [(and entry (pair? entry))
        (respond! (hasheq 'type (pp-expr (car entry))))]
       [else
        ;; Wrap in infer command
        (define results (eval-in-session! state session (format "infer ~a" code)))
        (respond! (hasheq 'type (if (null? results)
                                    "unknown"
                                    (hash-ref (car results) 'text "unknown"))))])]

    ;; ---- REPL: Reset session (Tier 4) ----
    ["$/prologos/resetSession"
     (define uri (hash-ref params 'uri ""))
     (lsp-log state "REPL resetSession for ~a" uri)
     (hash-remove! (lsp-state-repl-sessions state) uri)
     (respond! (hasheq 'ok #t))]

    ;; ---- Propagator Visualization (Phase 3) ----
    ["$/prologos/propagatorSnapshot"
     (define uri (hash-ref params 'uri ""))
     (define trace (hash-ref (lsp-state-prop-traces state) uri #f))
     (respond! (or trace (hasheq 'error "No propagator trace available for this file")))]

    ;; ---- InfoView: Cursor context (Tier 5) ----
    ["$/prologos/cursorContext"
     (define uri  (hash-ref params 'uri ""))
     (define line (hash-ref params 'line 0))
     (define char (hash-ref params 'character 0))
     (respond! (get-cursor-context state uri line char))]

    ;; ---- Client notifications (silently ignored) ----
    ["$/setTrace" (void)]           ; trace level change — no-op
    ["$/cancelRequest" (void)]      ; request cancellation — no-op for sync server

    ;; ---- Unknown ----
    [_
     (lsp-log state "Unhandled method: ~a" method)
     (when id
       (respond-error! method-not-found-code
                       (format "Method not found: ~a" method)))]))

;; ============================================================
;; Initialize result
;; ============================================================

(define (initialize-result)
  (hasheq
   'capabilities
   (hasheq
    ;; Full document sync (send entire content on change)
    'textDocumentSync
    (hasheq 'openClose #t
            'change 1       ; TextDocumentSyncKind.Full = 1
            'save (hasheq 'includeText #t))

    ;; Document symbols (outline)
    'documentSymbolProvider #t

    ;; Go-to-definition
    'definitionProvider #t

    ;; Signature help
    'signatureHelpProvider
    (hasheq 'triggerCharacters '("[" " "))

    ;; Hover
    'hoverProvider #t

    ;; Completion
    'completionProvider
    (hasheq 'triggerCharacters '("." ":")
            'resolveProvider #f))

   'serverInfo
   (hasheq 'name "prologos-lsp"
           'version "0.1.0")))

;; ============================================================
;; Diagnostics: elaborate file and publish errors
;; ============================================================

;; Run process-file on the document content and publish diagnostics.
;; This is the Tier 2 approach: full re-elaboration on each save.
;; Tier 3+ will use propagator cells for incremental updates.
(define (elaborate-and-publish-diagnostics! state uri text notify!)
  (define file-path (uri->path uri))
  (lsp-log state "Elaborating ~a (~a bytes)" file-path (string-length text))

  ;; Capture errors from process-file
  (define errors '())
  (define warnings '())
  (define captured-def-locs (hasheq))
  (define captured-type-env (hasheq))
  (define captured-spec-store (hasheq))
  (define captured-prop-trace #f)

  ;; Set up BSP observer for propagator trace capture
  (define-values (bsp-observe bsp-get-rounds) (make-trace-accumulator))

  (with-handlers
    ([exn:fail?
      (lambda (e)
        (lsp-log state "Elaboration exception: ~a" (exn-message e))
        (set! errors
              (list (prologos-error #f (exn-message e)))))])

    ;; Run elaboration. process-file returns a list of results where
    ;; prologos-error? items are errors. Also redirect current-error-port
    ;; to suppress perf/phase/memory noise (those reports are for the test
    ;; runner, not LSP). Our lsp-log uses lsp-state-log-port, not
    ;; current-error-port, so it's unaffected.
    (parameterize ([current-emit-error-diagnostics #t]
                   ;; LSP Tier 2.3: fresh definition locations per elaboration
                   [current-definition-locations (hasheq)]
                   ;; Suppress process-file perf/phase/memory/diagnostic noise
                   [current-error-port (open-output-nowhere)]
                   ;; Visualization Phase 1: capture BSP rounds
                   [current-bsp-observer bsp-observe])
      ;; Write content to temp file and process
      (define tmp-path (make-temporary-file "prologos-lsp-~a.prologos"))
      (call-with-output-file tmp-path
        (lambda (out) (display text out))
        #:exists 'replace)
      (with-handlers ([exn:fail? (lambda (e)
                                   (set! errors (cons (prologos-error #f (exn-message e)) errors)))])
        (define results (process-file tmp-path))
        ;; Extract errors from the result list
        (for ([r (in-list (or results '()))])
          (when (prologos-error? r)
            (set! errors (cons r errors)))))
      (delete-file tmp-path)
      ;; Capture definition locations, type env, and spec store before parameterize exits
      (set! captured-def-locs (current-definition-locations))
      (set! captured-type-env (current-global-env))
      (set! captured-spec-store (current-spec-store))
      ;; Visualization Phase 3: capture propagator network trace
      (define net-box (current-prop-net-box))
      (when net-box
        (define final-enet (unbox net-box))
        (define final-net (elab-network-prop-net final-enet))
        (define rounds (bsp-get-rounds))
        (when (> (length rounds) 0)
          (set! captured-prop-trace
                (serialize-prop-trace
                 (prop-trace final-net  ;; initial = final for now (no pre-elab snapshot)
                             rounds
                             final-net
                             (hasheq 'file uri))))))))

  ;; Filter out errors with unknown/zero srclocs — these come from internal
  ;; elaboration issues (e.g., reduce type inference) and can't be displayed
  ;; meaningfully since they'd always pin to line 0 (the ns declaration).
  (define (has-real-srcloc? err)
    (define loc (and (prologos-error? err) (prologos-error-srcloc err)))
    (or (not loc)
        (not (srcloc? loc))
        (and (srcloc? loc)
             (not (equal? (srcloc-file loc) "<unknown>"))
             (> (srcloc-line loc) 0))))
  ;; Convert to LSP diagnostics and publish
  (define real-errors (filter has-real-srcloc? (reverse errors)))
  (define diags (errors->diagnostics real-errors))
  (hash-set! (lsp-state-document-diagnostics state) uri diags)
  (notify! "textDocument/publishDiagnostics"
           (hasheq 'uri uri
                   'diagnostics diags))

  ;; LSP Tier 2.3: Store captured definition locations for go-to-definition
  (hash-set! (lsp-state-definition-locations state) uri captured-def-locs)

  ;; LSP Tier 3: Store type env and spec store for hover/InfoView
  (hash-set! (lsp-state-type-envs state) uri captured-type-env)
  (hash-set! (lsp-state-spec-stores state) uri captured-spec-store)

  ;; Visualization Phase 3: Store propagator trace
  (when captured-prop-trace
    (hash-set! (lsp-state-prop-traces state) uri captured-prop-trace))

  (lsp-log state "Published ~a diagnostics, ~a definitions, ~a specs for ~a"
           (length diags) (hash-count captured-def-locs)
           (hash-count captured-spec-store) uri))

;; ============================================================
;; Document symbols
;; ============================================================

;; Extract top-level symbols from the document for the outline view.
;; Uses a simple regex scan of the document content.
;; Tier 3+ will use the parsed AST from the propagator network.
(define (get-document-symbols state uri)
  (define text (hash-ref (lsp-state-document-contents state) uri #f))
  (cond
    [(not text) '()]
    [else
     (define lines (string-split text "\n"))
     (define symbols '())
     (for ([line (in-list lines)]
           [line-num (in-naturals)])
       (define m-defn (regexp-match #rx"^\\s*defn\\s+([a-zA-Z_][a-zA-Z0-9_?!'-]*)" line))
       (define m-def  (regexp-match #rx"^\\s*def\\s+([a-zA-Z_][a-zA-Z0-9_?!'-]*)" line))
       (define m-spec (regexp-match #rx"^\\s*spec\\s+([a-zA-Z_][a-zA-Z0-9_?!'-]*)" line))
       (define m-data (regexp-match #rx"^\\s*data\\s+([a-zA-Z_][a-zA-Z0-9_?!'-]*)" line))
       (define m-trait (regexp-match #rx"^\\s*trait\\s+([a-zA-Z_][a-zA-Z0-9_?!'-]*)" line))
       (define m-impl (regexp-match #rx"^\\s*impl\\s+([a-zA-Z_][a-zA-Z0-9_?!'-]*)" line))
       (define m-ns   (regexp-match #rx"^\\s*ns\\s+([a-zA-Z_][a-zA-Z0-9_.:-]*)" line))
       (define m-bundle (regexp-match #rx"^\\s*bundle\\s+([a-zA-Z_][a-zA-Z0-9_?!'-]*)" line))

       (define (add-symbol! name kind)
         (set! symbols
               (cons (hasheq 'name name
                             'kind kind
                             'range (make-range line-num 0 line-num (string-length line))
                             'selectionRange (make-range line-num 0 line-num (string-length name)))
                     symbols)))

       (when m-ns     (add-symbol! (cadr m-ns)     2))    ; Module
       (when m-spec   (add-symbol! (cadr m-spec)   11))   ; Interface
       (when m-defn   (add-symbol! (cadr m-defn)   12))   ; Function
       (when m-def    (add-symbol! (cadr m-def)    13))   ; Variable
       (when m-data   (add-symbol! (cadr m-data)   5))    ; Class
       (when m-trait  (add-symbol! (cadr m-trait)   11))   ; Interface
       (when m-impl   (add-symbol! (cadr m-impl)   11))   ; Interface
       (when m-bundle (add-symbol! (cadr m-bundle) 11)))  ; Interface

     (reverse symbols)]))

;; Helper: make an LSP Range (imported from diagnostics but inlined for simplicity)
(define (make-range start-line start-char end-line end-char)
  (hasheq 'start (hasheq 'line start-line 'character start-char)
          'end   (hasheq 'line end-line   'character end-char)))

;; ============================================================
;; Go-to-definition (Tier 2.4)
;; ============================================================

;; Find the definition location for the symbol at the given position.
;; Returns an LSP Location or null if not found.
(define (get-definition-location state uri line char)
  (define text (hash-ref (lsp-state-document-contents state) uri #f))
  (cond
    [(not text) (json-null)]
    [else
     (define word (word-at-position text line char))
     (cond
       [(not word) (json-null)]
       [else
        (lsp-log state "Go-to-definition: ~a at ~a:~a" word line char)
        (define sym (string->symbol word))
        ;; Check definition locations captured during elaboration
        (define def-locs (hash-ref (lsp-state-definition-locations state) uri #f))
        (define loc (and def-locs (hash-ref def-locs sym #f)))
        (cond
          [loc
           ;; Found in same file — return Location with srcloc
           (define range (srcloc->range loc))
           (hasheq 'uri uri 'range range)]
          [else
           ;; Try qualified name lookup — search def-locs for FQN matching short name
           (define found-loc
             (and def-locs
                  (for/first ([(k v) (in-hash def-locs)]
                              #:when (let ([s (symbol->string k)])
                                       (string-suffix? s (string-append "::" word))))
                    v)))
           (cond
             [found-loc
              (hasheq 'uri uri 'range (srcloc->range found-loc))]
             [else
              ;; Fallback: regex scan for definition in current document
              (define def-line (find-definition-line text word))
              (cond
                [def-line
                 (hasheq 'uri uri
                         'range (make-range def-line 0 def-line (string-length word)))]
                [else (json-null)])])])])]))

;; Extract the word (identifier) at the given line and character position.
(define (word-at-position text line char)
  (define lines (string-split text "\n"))
  (cond
    [(>= line (length lines)) #f]
    [else
     (define l (list-ref lines line))
     (cond
       [(>= char (string-length l)) #f]
       [else
        ;; Expand left and right from cursor to find word boundaries
        (define id-char?
          (lambda (c) (or (char-alphabetic? c) (char-numeric? c)
                          (char=? c #\_) (char=? c #\?) (char=? c #\!)
                          (char=? c #\') (char=? c #\-) (char=? c #\:))))
        (define start
          (let loop ([i char])
            (if (and (> i 0) (id-char? (string-ref l (sub1 i))))
                (loop (sub1 i))
                i)))
        (define end
          (let loop ([i char])
            (if (and (< i (string-length l)) (id-char? (string-ref l i)))
                (loop (add1 i))
                i)))
        (if (= start end) #f
            (substring l start end))])]))

;; Return a list of candidate words to look up for InfoView, ordered by priority:
;; 1. Exact word at cursor position
;; 2. Word immediately left of cursor (for "factorial|" case)
;; 3. First word on the line (form head — for "factorial 5|" case)
;; Used for InfoView where we want sticky type display across the whole form line.
(define (words-near-position text line char)
  (define candidates '())
  ;; 1. Exact position
  (define exact (word-at-position text line char))
  (when exact (set! candidates (cons exact candidates)))
  ;; 2. One char left
  (when (> char 0)
    (define left (word-at-position text line (sub1 char)))
    (when (and left (not (equal? left exact)))
      (set! candidates (cons left candidates))))
  ;; 3. First word on line (form head)
  (define lines (string-split text "\n"))
  (when (< line (length lines))
    (define l (list-ref lines line))
    (define m (regexp-match #rx"^\\s*([A-Za-z_][A-Za-z0-9_?!':=-]*)" l))
    (when (and m (cadr m))
      (define head (cadr m))
      (unless (member head candidates)
        (set! candidates (cons head candidates)))))
  (reverse candidates))

;; Regex-scan fallback: find the line number where a name is defined.
;; Returns 0-based line number or #f.
(define (find-definition-line text name)
  (define escaped (regexp-quote name))
  (define rx (regexp (string-append "^\\s*(?:def|defn|spec|data|trait|impl|bundle)\\s+" escaped "\\b")))
  (define lines (string-split text "\n"))
  (for/first ([l (in-list lines)]
              [n (in-naturals)]
              #:when (regexp-match? rx l))
    n))

;; ============================================================
;; Spec type formatting
;; ============================================================

;; Format spec-entry type-datums as a display string.
;; type-datums is a list of clauses; each clause is a list of tokens (symbols/datums).
;; Single clause: "Int -> Int"; multi-clause: "0 -> 1 | Nat -> Nat"
;; Note: WS-parsed specs include a leading `:` token (the type separator) — strip it.
(define (format-spec-type spec)
  (define types (spec-entry-type-datums spec))
  (string-join
   (map (lambda (clause)
          (define tokens
            (if (and (pair? clause) (eq? (car clause) ':))
                (cdr clause)  ; strip leading `:` from WS-parsed specs
                clause))
          (string-join (map (lambda (t) (format "~a" t)) tokens) " "))
        types)
   " | "))

;; ============================================================
;; Hover (Tier 3.2)
;; ============================================================

;; Provide hover information (type signature) for the symbol under cursor.
;; Returns an LSP Hover object or null.
(define (get-hover-info state uri line char)
  (define text (hash-ref (lsp-state-document-contents state) uri #f))
  (cond
    [(not text) (json-null)]
    [else
     (define word (word-at-position text line char))
     (cond
       [(not word) (json-null)]
       [else
        (lsp-log state "Hover: ~a at ~a:~a" word line char)
        (define sym (string->symbol word))
        (define type-env (hash-ref (lsp-state-type-envs state) uri #f))
        (cond
          [(not type-env) (json-null)]
          [else
           ;; Look up type in the global env snapshot
           (define entry (hash-ref type-env sym #f))
           ;; Also try FQN variants
           (define entry*
             (or entry
                 (and (hash-ref (lsp-state-definition-locations state) uri #f)
                      (for/first ([(k v) (in-hash type-env)]
                                  #:when (let ([s (symbol->string k)])
                                           (string-suffix? s (string-append "::" word))))
                        v))))
           (cond
             [entry*
              ;; entry is (cons type value) or just type depending on env format
              (define type-expr
                (cond
                  [(pair? entry*) (car entry*)]  ; (type . value)
                  [else entry*]))
              (define type-str (pp-expr type-expr))
              (define markdown
                (format "```prologos\n~a : ~a\n```" word type-str))
              (hasheq 'contents
                      (hasheq 'kind "markdown"
                              'value markdown))]
             [else
              ;; Fall back to spec-store for type signature
              (define spec-store (hash-ref (lsp-state-spec-stores state) uri #f))
              (define spec (and spec-store (hash-ref spec-store sym #f)))
              (cond
                [spec
                 (define type-str (format-spec-type spec))
                 (define markdown
                   (format "```prologos\n~a : ~a\n```" word type-str))
                 (hasheq 'contents
                         (hasheq 'kind "markdown"
                                 'value markdown))]
                [else (json-null)])])])])]))

;; ============================================================
;; Completion (Tier 3.3)
;; ============================================================

;; Provide completion items based on the global env.
;; Returns a CompletionList with isIncomplete=true (client-side filtering).
(define (get-completions state uri line char)
  (define text (hash-ref (lsp-state-document-contents state) uri #f))
  (define type-env (hash-ref (lsp-state-type-envs state) uri #f))
  (cond
    [(not type-env) (hasheq 'isIncomplete #t 'items '())]
    [else
     ;; Get the prefix being typed
     (define prefix (word-prefix-at-position text line char))
     ;; Build completion items from the global env
     ;; Filter: only short names (no :: qualified names) to avoid duplicates,
     ;; and names matching the prefix
     (define items
       (for/list ([(name entry) (in-hash type-env)]
                  #:when (pair? entry)  ; must have type
                  #:when (let ([s (symbol->string name)])
                           (and (not (string-contains? s "::"))
                                (or (not prefix)
                                    (string=? prefix "")
                                    (string-prefix? s prefix)))))
         (define name-str (symbol->string name))
         (define type-str (pp-expr (car entry)))
         (hasheq 'label name-str
                 'kind 3           ; CompletionItemKind.Function = 3
                 'detail type-str
                 'sortText name-str)))
     ;; Also add keywords
     (define kw-items
       (for/list ([kw (in-list '("defn" "def" "spec" "data" "trait" "impl"
                                 "bundle" "match" "fn" "let" "if" "require"
                                 "ns" "reduce" "eval" "infer" "type"
                                 "where" "forall" "property"))]
                  #:when (or (not prefix)
                             (string=? prefix "")
                             (string-prefix? kw prefix)))
         (hasheq 'label kw
                 'kind 14          ; CompletionItemKind.Keyword = 14
                 'sortText (string-append "~" kw))))  ; sort keywords after names
     (hasheq 'isIncomplete #t
             'items (append items kw-items))]))

;; Extract the word prefix being typed at the cursor position.
;; Returns the partial word before the cursor, or "" if at word start.
(define (word-prefix-at-position text line char)
  (cond
    [(not text) ""]
    [else
     (define lines (string-split text "\n"))
     (cond
       [(>= line (length lines)) ""]
       [else
        (define l (list-ref lines line))
        (define id-char?
          (lambda (c) (or (char-alphabetic? c) (char-numeric? c)
                          (char=? c #\_) (char=? c #\?) (char=? c #\!)
                          (char=? c #\') (char=? c #\-) (char=? c #\:))))
        (define start
          (let loop ([i char])
            (if (and (> i 0) (id-char? (string-ref l (sub1 i))))
                (loop (sub1 i))
                i)))
        (if (>= start char) ""
            (substring l start char))])]))

;; ============================================================
;; Cursor context (Tier 5: InfoView)
;; ============================================================

;; Return cursor context for the InfoView panel: type at cursor,
;; file outline with types, diagnostics, REPL state.
(define (get-cursor-context state uri line char)
  (define text (hash-ref (lsp-state-document-contents state) uri #f))
  (define type-env (hash-ref (lsp-state-type-envs state) uri #f))

  ;; 1. Type at cursor — try candidate words in priority order for sticky display.
  ;;    Handles: exact position, cursor just past word, and form head on the line.
  (define candidates (if text (words-near-position text line char) '()))
  (define spec-store (hash-ref (lsp-state-spec-stores state) uri #f))
  (define type-at-cursor
    (for/or ([word (in-list candidates)])
      (define sym (string->symbol word))
      (define entry (and type-env
                         (or (hash-ref type-env sym #f)
                             (for/first ([(k v) (in-hash type-env)]
                                         #:when (let ([s (symbol->string k)])
                                                  (string-suffix? s (string-append "::" word))))
                               v))))
      (cond
        [entry
         (let ([type-expr (if (pair? entry) (car entry) entry)])
           (format "~a : ~a" word (pp-expr type-expr)))]
        [(and spec-store (hash-ref spec-store sym #f))
         => (lambda (spec)
              (format "~a : ~a" word (format-spec-type spec)))]
        [else #f])))

  ;; 2. File context: definitions with types + namespace
  (define symbols (if text (get-document-symbols state uri) '()))
  (define definitions
    (for/list ([s (in-list symbols)])
      (define name (hash-ref s 'name ""))
      (define sym (string->symbol name))
      (define kind-num (hash-ref s 'kind 0))
      (define kind-str (symbol-kind->string kind-num))
      (define def-line (hash-ref (hash-ref (hash-ref s 'range (hasheq)) 'start (hasheq)) 'line 0))
      ;; Look up type from type-env, fall back to spec-store
      (define type-str
        (cond
          [(and type-env
                (let ([entry (or (hash-ref type-env sym #f)
                                 (for/first ([(k v) (in-hash type-env)]
                                             #:when (let ([sk (symbol->string k)])
                                                      (string-suffix? sk (string-append "::" name))))
                                   v))])
                  (and entry (pair? entry) (pp-expr (car entry)))))
           => values]
          [(and spec-store (hash-ref spec-store sym #f))
           => (lambda (spec) (format-spec-type spec))]
          [else ""]))
      (hasheq 'name name 'type type-str 'line def-line 'kind kind-str)))

  ;; Extract namespace from symbols
  (define ns-name
    (for/first ([s (in-list symbols)]
                #:when (= (hash-ref s 'kind 0) 2))  ; Module kind
      (hash-ref s 'name "")))

  ;; 3. Diagnostics for this document
  (define raw-diags (hash-ref (lsp-state-document-diagnostics state) uri '()))
  (define diags
    (for/list ([d (in-list raw-diags)])
      (define range (hash-ref d 'range (hasheq)))
      (define start (hash-ref range 'start (hasheq)))
      (define d-line (hash-ref start 'line 0))
      (define severity-num (hash-ref d 'severity 1))
      (hasheq 'message (hash-ref d 'message "")
              'line d-line
              'severity (if (= severity-num 1) "error" "warning"))))

  ;; 4. REPL state
  (define session (hash-ref (lsp-state-repl-sessions state) uri #f))
  (define repl-state
    (cond
      [session
       (define env (repl-session-global-env session))
       (hasheq 'active #t
               'evalCount (hash-count env)
               'lastResult (json-null))]
      [else
       (hasheq 'active #f
               'evalCount 0
               'lastResult (json-null))]))

  ;; Build response
  (hasheq 'typeAtCursor (or type-at-cursor (json-null))
          'symbolKind (json-null)
          'fileContext (hasheq 'namespace (or ns-name (json-null))
                              'definitions definitions
                              'imports '())
          'diagnostics diags
          'replState repl-state))

;; Convert LSP SymbolKind number to a readable string.
(define (symbol-kind->string kind)
  (case kind
    [(2)  "module"]
    [(5)  "data"]
    [(11) "spec"]
    [(12) "function"]
    [(13) "variable"]
    [else "other"]))

;; ============================================================
;; Signature help (Tier 2.6)
;; ============================================================

;; Provide signature help for the function being called.
;; Returns a SignatureHelp object or null.
(define (get-signature-help state uri line char)
  (define text (hash-ref (lsp-state-document-contents state) uri #f))
  (cond
    [(not text) (json-null)]
    [else
     ;; Simple heuristic: look for the function name before the cursor
     ;; In Prologos, function calls are [f x y z], so look for [ followed by name
     (define lines (string-split text "\n"))
     (cond
       [(>= line (length lines)) (json-null)]
       [else
        (define l (list-ref lines line))
        ;; Search backwards from cursor for opening bracket
        (define fn-name (find-function-name l char))
        (cond
          [(not fn-name) (json-null)]
          [else
           (lsp-log state "Signature help: ~a" fn-name)
           ;; Look up param names from the elaboration
           (define param-names (lookup-defn-param-names (string->symbol fn-name)))
           ;; Look up type from definition locations
           (define def-locs (hash-ref (lsp-state-definition-locations state) uri #f))
           (define type-str
             (and def-locs
                  (let ([sym (string->symbol fn-name)])
                    ;; Try to get type from global env snapshot
                    ;; For now, use param names as the signature
                    #f)))
           (cond
             [(and param-names (not (null? param-names)))
              (define params-str
                (string-join (map symbol->string param-names) ", "))
              (define sig-label
                (format "~a [~a]" fn-name params-str))
              (hasheq 'signatures
                      (list (hasheq 'label sig-label
                                    'parameters
                                    (for/list ([p (in-list param-names)])
                                      (hasheq 'label (symbol->string p)))))
                      'activeSignature 0
                      'activeParameter (count-args-before-cursor l char))]
             [else (json-null)])])])]))

;; Find the function name being called at cursor position.
;; Searches backwards for pattern like "[name " or "[name\n".
(define (find-function-name line char)
  (define id-char?
    (lambda (c) (or (char-alphabetic? c) (char-numeric? c)
                    (char=? c #\_) (char=? c #\?) (char=? c #\!)
                    (char=? c #\') (char=? c #\-))))
  ;; Search backwards from cursor for [
  (let loop ([i (min (sub1 char) (sub1 (string-length line)))])
    (cond
      [(< i 0) #f]
      [(char=? (string-ref line i) #\[)
       ;; Found opening bracket — extract the name after it
       (define start (add1 i))
       (define end
         (let lp ([j start])
           (if (and (< j (string-length line)) (id-char? (string-ref line j)))
               (lp (add1 j))
               j)))
       (if (> end start) (substring line start end) #f)]
      [else (loop (sub1 i))])))

;; Count how many arguments appear before the cursor (for activeParameter).
(define (count-args-before-cursor line char)
  ;; Simple heuristic: count space-separated tokens between [ and cursor
  (let loop ([i 0] [depth 0] [args 0] [in-word? #f])
    (cond
      [(>= i (min char (string-length line))) (max 0 (sub1 args))]
      [else
       (define c (string-ref line i))
       (cond
         [(char=? c #\[) (loop (add1 i) (add1 depth) (if (= depth 0) 0 args) #f)]
         [(char=? c #\]) (loop (add1 i) (sub1 depth) args #f)]
         [(and (> depth 0) (char-whitespace? c))
          (loop (add1 i) depth args #f)]
         [(and (> depth 0) (not in-word?))
          (loop (add1 i) depth (add1 args) #t)]
         [else (loop (add1 i) depth args in-word?)])])))

;; ============================================================
;; URI <-> path conversion
;; ============================================================

;; Convert file:///path/to/file.prologos → /path/to/file.prologos
(define (uri->path uri)
  (cond
    [(string-prefix? uri "file://")
     (define raw (substring uri 7))
     ;; Handle percent-encoded characters
     (regexp-replace* #rx"%20" raw " ")]
    [else uri]))

;; Convert /path/to/file.prologos → file:///path/to/file.prologos
(define (path->uri path)
  (string-append "file://" (path->string (simplify-path path))))

;; ============================================================
;; Entry point
;; ============================================================

(module+ main
  (run-lsp-server))
