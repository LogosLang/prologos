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
         (only-in json json-null)
         "json-rpc.rkt"
         "diagnostics.rkt"
         "../driver.rkt"
         "../errors.rkt"
         "../namespace.rkt"
         "../source-location.rkt")

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
   ) #:mutable)

(define (make-initial-state)
  (lsp-state #f       ; not initialized
             #f       ; no root URI
             (make-hash)
             (make-hash)
             #f       ; module registry loaded on initialize
             (current-error-port)))

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
    'documentSymbolProvider #t)

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

  (with-handlers
    ([exn:fail?
      (lambda (e)
        (lsp-log state "Elaboration exception: ~a" (exn-message e))
        (set! errors
              (list (prologos-error #f (exn-message e)))))])

    ;; Run elaboration, capture errors via the error emission parameter
    (parameterize ([current-emit-error-diagnostics
                    (lambda (err)
                      (set! errors (cons err errors)))])
      ;; Write content to temp file and process
      (define tmp-path (make-temporary-file "prologos-lsp-~a.prologos"))
      (call-with-output-file tmp-path
        (lambda (out) (display text out))
        #:exists 'replace)
      (with-handlers ([exn:fail? (lambda (e)
                                   (set! errors (cons (prologos-error #f (exn-message e)) errors)))])
        (process-file tmp-path))
      (delete-file tmp-path)))

  ;; Convert to LSP diagnostics and publish
  (define diags (errors->diagnostics (reverse errors)))
  (hash-set! (lsp-state-document-diagnostics state) uri diags)
  (notify! "textDocument/publishDiagnostics"
           (hasheq 'uri uri
                   'diagnostics diags))
  (lsp-log state "Published ~a diagnostics for ~a" (length diags) uri))

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
       (define m-defn (regexp-match #rx"^defn\\s+([a-zA-Z_][a-zA-Z0-9_?!'-]*)" line))
       (define m-def  (regexp-match #rx"^def\\s+([a-zA-Z_][a-zA-Z0-9_?!'-]*)" line))
       (define m-spec (regexp-match #rx"^spec\\s+([a-zA-Z_][a-zA-Z0-9_?!'-]*)" line))
       (define m-data (regexp-match #rx"^data\\s+([a-zA-Z_][a-zA-Z0-9_?!'-]*)" line))
       (define m-trait (regexp-match #rx"^trait\\s+([a-zA-Z_][a-zA-Z0-9_?!'-]*)" line))
       (define m-impl (regexp-match #rx"^impl\\s+([a-zA-Z_][a-zA-Z0-9_?!'-]*)" line))
       (define m-ns   (regexp-match #rx"^ns\\s+([a-zA-Z_][a-zA-Z0-9_.:-]*)" line))
       (define m-bundle (regexp-match #rx"^bundle\\s+([a-zA-Z_][a-zA-Z0-9_?!'-]*)" line))

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
