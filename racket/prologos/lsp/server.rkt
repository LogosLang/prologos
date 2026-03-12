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
         "../global-env.rkt")

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
   ) #:mutable)

(define (make-initial-state)
  (lsp-state #f       ; not initialized
             #f       ; no root URI
             (make-hash)
             (make-hash)
             #f       ; module registry loaded on initialize
             (current-error-port)
             (make-hash)))

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
    (hasheq 'triggerCharacters '("[" " ")))

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
                   [current-error-port (open-output-nowhere)])
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
      ;; Capture definition locations before parameterize exits
      (set! captured-def-locs (current-definition-locations))))

  ;; Convert to LSP diagnostics and publish
  (define diags (errors->diagnostics (reverse errors)))
  (hash-set! (lsp-state-document-diagnostics state) uri diags)
  (notify! "textDocument/publishDiagnostics"
           (hasheq 'uri uri
                   'diagnostics diags))

  ;; LSP Tier 2.3: Store captured definition locations for go-to-definition
  (hash-set! (lsp-state-definition-locations state) uri captured-def-locs)

  (lsp-log state "Published ~a diagnostics, ~a definitions for ~a"
           (length diags) (hash-count captured-def-locs) uri))

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
