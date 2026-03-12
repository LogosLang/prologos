#lang racket/base

;;; json-rpc.rkt — JSON-RPC 2.0 over stdio with Content-Length framing
;;;
;;; Implements the LSP transport layer:
;;; - read-message: parse Content-Length header, read JSON body
;;; - write-message: format JSON with Content-Length header
;;; - make-response / make-notification / make-error: JSON-RPC message constructors
;;;
;;; No external dependencies — uses racket/json (built-in).

(require json)

(provide read-message
         write-message
         make-response
         make-notification
         make-error-response
         make-request
         jsexpr->bytes
         ;; Error codes (LSP-defined)
         parse-error-code
         invalid-request-code
         method-not-found-code
         invalid-params-code
         internal-error-code
         server-not-initialized-code
         request-cancelled-code)

;; ============================================================
;; LSP JSON-RPC error codes
;; ============================================================

(define parse-error-code          -32700)
(define invalid-request-code      -32600)
(define method-not-found-code     -32601)
(define invalid-params-code       -32602)
(define internal-error-code       -32603)
(define server-not-initialized-code -32002)
(define request-cancelled-code    -32800)

;; ============================================================
;; Reading messages
;; ============================================================

;; Read a single LSP message from `in`.
;; Returns a jsexpr (hasheq) or #f on EOF.
;;
;; Protocol: "Content-Length: N\r\n\r\n" followed by N bytes of UTF-8 JSON.
;; Additional headers (Content-Type) are read and ignored.
(define (read-message in)
  (define content-length (read-headers in))
  (cond
    [(not content-length) #f]  ; EOF
    [else
     (define body-bytes (read-bytes content-length in))
     (cond
       [(eof-object? body-bytes) #f]
       [(< (bytes-length body-bytes) content-length) #f]  ; truncated
       [else
        (define body-str (bytes->string/utf-8 body-bytes))
        (with-handlers ([exn:fail? (lambda (e) #f)])
          (string->jsexpr body-str))])]))

;; Read headers until blank line (\r\n\r\n).
;; Returns Content-Length as integer, or #f on EOF/error.
(define (read-headers in)
  (let loop ([content-length #f])
    (define line (read-line in 'return-linefeed))
    (cond
      [(eof-object? line) #f]
      [(equal? line "") content-length]   ; blank line = end of headers
      [(equal? line "\r") content-length] ; handle bare \r
      [else
       (define cl (parse-content-length line))
       (loop (or cl content-length))])))

;; Parse "Content-Length: 123" from a header line.
;; Returns integer or #f.
(define (parse-content-length line)
  (define m (regexp-match #px"^[Cc]ontent-[Ll]ength:\\s*([0-9]+)" line))
  (and m (string->number (cadr m))))

;; ============================================================
;; Writing messages
;; ============================================================

;; Write a JSON-RPC message to `out` with Content-Length framing.
(define (write-message out msg)
  (define body (jsexpr->bytes msg))
  (define header
    (string->bytes/utf-8
     (string-append "Content-Length: "
                    (number->string (bytes-length body))
                    "\r\n\r\n")))
  (write-bytes header out)
  (write-bytes body out)
  (flush-output out))

;; Convert jsexpr to UTF-8 bytes.
(define (jsexpr->bytes js)
  (string->bytes/utf-8 (jsexpr->string js)))

;; ============================================================
;; Message constructors
;; ============================================================

;; Build a JSON-RPC response (success).
(define (make-response id result)
  (hasheq 'jsonrpc "2.0"
          'id id
          'result result))

;; Build a JSON-RPC error response.
(define (make-error-response id code message [data #f])
  (define err (hasheq 'code code 'message message))
  (hasheq 'jsonrpc "2.0"
          'id id
          'error (if data (hash-set err 'data data) err)))

;; Build a JSON-RPC notification (no id, no response expected).
(define (make-notification method params)
  (hasheq 'jsonrpc "2.0"
          'method method
          'params params))

;; Build a JSON-RPC request (with id).
(define (make-request id method params)
  (hasheq 'jsonrpc "2.0"
          'id id
          'method method
          'params params))
