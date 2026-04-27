#lang racket/base

;;;
;;; tcp-ffi.rkt — minimal TCP primitives bridge for the OCapN
;;; tcp-testing-only netlayer.
;;;
;;; Mirrors `io-ffi.rkt`'s handle-table approach: Prologos sees only
;;; integer handles; Racket maintains a port-id → port table.
;;;
;;; This is the testing-only netlayer. There is NO crypto and NO
;;; auth here — anyone who can connect to the listen socket is
;;; granted a session. NEVER use over public networks. The transport
;;; name in OCapN locators is "tcp-testing-only" by convention.
;;;
;;; Primitives (handle ID semantics):
;;;
;;;   tcp-listen          : (port -> Nat)
;;;     start a listener; returns a server-handle.
;;;
;;;   tcp-accept          : (Nat -> Nat)
;;;     accept ONE incoming connection on a server-handle; returns
;;;     a connection-handle. Blocks. Use only inside tests.
;;;
;;;   tcp-accept-ready?   : (Nat -> Bool)
;;;     true iff an accept would not block.
;;;
;;;   tcp-connect         : (String -> Nat -> Nat)
;;;     dial host:port; returns a connection-handle.
;;;
;;;   tcp-send-line       : (Nat -> String -> Nat)
;;;     write a string + newline to the connection; returns the
;;;     same handle (for data-flow forcing in lazy reduction).
;;;
;;;   tcp-recv-line-ret   : (Nat -> Nat)
;;;     read one line; cache it under the handle; return the handle.
;;;     (Mirrors io-ffi.rkt's read-then-cache trick.)
;;;
;;;   tcp-recv-cached     : (Nat -> String)
;;;     return the previously-cached line for this handle.
;;;
;;;   tcp-close           : (Nat -> Unit)
;;;     close a connection or server handle and remove it from the
;;;     table.
;;;
;;; Wire format: ONE message = ONE line. Each line is a Syrup-encoded
;;; SyrupValue (we use a textual subset; Endo uses byte-level Syrup
;;; but we approximate by serialising via the pretty-printer's repr
;;; in the netlayer Prologos layer). Lines are terminated by `\n`.
;;; Length-prefix framing is intentionally NOT used — keeping testing-
;;; only simple. See goblin-pitfalls #19.

(require racket/tcp
         racket/string)

(provide
 tcp-listen
 tcp-accept
 tcp-accept-ready?
 tcp-connect
 tcp-send-line
 tcp-recv-line-ret
 tcp-recv-cached
 tcp-close
 tcp-ffi-registry
 ;; Test-only helpers
 tcp-table-size
 tcp-table-clear!)

;; ========================================
;; Handle table
;; ========================================

(define tcp-table       (make-hasheq))   ;; id -> (cons port-or-listener kind)
(define tcp-recv-cache  (make-hasheq))   ;; id -> last-recv'd string
(define tcp-next-id     0)

(define (tcp-fresh-id!)
  (define id tcp-next-id)
  (set! tcp-next-id (add1 id))
  id)

(define (tcp-store! kind v)
  (define id (tcp-fresh-id!))
  (hash-set! tcp-table id (cons v kind))
  id)

(define (tcp-lookup id)
  (define entry (hash-ref tcp-table id
    (lambda () (error 'tcp-ffi "invalid handle: ~a" id))))
  (car entry))

(define (tcp-kind id)
  (define entry (hash-ref tcp-table id
    (lambda () (error 'tcp-ffi "invalid handle: ~a" id))))
  (cdr entry))

;; ========================================
;; Primitives
;; ========================================

(define (tcp-listen port)
  ;; Bind to localhost-only — testing only.
  (define ll (tcp-listen-impl port))
  (tcp-store! 'listener ll))

(define (tcp-listen-impl port)
  (tcp-listen-port port 4 #t "127.0.0.1"))

;; tcp-listen-port: Racket's `tcp-listen` (qualified name to avoid clash
;; with our exported `tcp-listen`).
(define tcp-listen-port
  (dynamic-require 'racket/tcp 'tcp-listen))

(define (tcp-accept server-id)
  (define listener (tcp-lookup server-id))
  (define-values (in out) (tcp-accept-impl listener))
  (tcp-store! 'connection (cons in out)))

(define tcp-accept-impl
  (dynamic-require 'racket/tcp 'tcp-accept))

(define (tcp-accept-ready? server-id)
  (define listener (tcp-lookup server-id))
  ((dynamic-require 'racket/tcp 'tcp-accept-ready?) listener))

(define (tcp-connect host port)
  (define-values (in out) (tcp-connect-impl host port))
  (tcp-store! 'connection (cons in out)))

(define tcp-connect-impl
  (dynamic-require 'racket/tcp 'tcp-connect))

(define (tcp-send-line conn-id line)
  (define entry (tcp-lookup conn-id))
  (define out (cdr entry))   ;; (cons in out)
  ;; If line already ends with \n, don't double-append.
  (define payload
    (if (regexp-match? #rx"\n$" line) line (string-append line "\n")))
  (write-string payload out)
  (flush-output out)
  conn-id)

;; Read ONE line from the connection's input port. Cache it under
;; conn-id and return conn-id (data-flow trick — see io-ffi.rkt).
(define (tcp-recv-line-ret conn-id)
  (define entry (tcp-lookup conn-id))
  (define in (car entry))    ;; (cons in out)
  (define line (read-line in 'linefeed))
  (hash-set! tcp-recv-cache conn-id (if (eof-object? line) "" line))
  conn-id)

(define (tcp-recv-cached conn-id)
  (hash-ref tcp-recv-cache conn-id ""))

(define (tcp-close handle-id)
  (define kind (tcp-kind handle-id))
  (case kind
    [(listener)
     (define ll (tcp-lookup handle-id))
     (tcp-close-listener ll)]
    [(connection)
     (define entry (tcp-lookup handle-id))
     (define in  (car entry))
     (define out (cdr entry))
     (close-input-port in)
     (close-output-port out)])
  (hash-remove! tcp-table handle-id)
  (hash-remove! tcp-recv-cache handle-id)
  (void))

(define tcp-close-listener
  (dynamic-require 'racket/tcp 'tcp-close))

;; ========================================
;; Test-only helpers
;; ========================================

(define (tcp-table-size) (hash-count tcp-table))

(define (tcp-table-clear!)
  ;; Best-effort cleanup for tests.
  (for ([(id _) (in-hash tcp-table)])
    (with-handlers ([exn:fail? (lambda _ (void))])
      (tcp-close id)))
  (hash-clear! tcp-table)
  (hash-clear! tcp-recv-cache)
  (set! tcp-next-id 0))

;; ========================================
;; FFI registry (mirrors io-ffi-registry)
;; ========================================

(define tcp-ffi-registry
  (hasheq
   'tcp-listen         (cons tcp-listen         '(Nat -> Nat))
   'tcp-accept         (cons tcp-accept         '(Nat -> Nat))
   'tcp-accept-ready?  (cons tcp-accept-ready?  '(Nat -> Bool))
   'tcp-connect        (cons tcp-connect        '(String -> Nat -> Nat))
   'tcp-send-line      (cons tcp-send-line      '(Nat -> String -> Nat))
   'tcp-recv-line-ret  (cons tcp-recv-line-ret  '(Nat -> Nat))
   'tcp-recv-cached    (cons tcp-recv-cached    '(Nat -> String))
   'tcp-close          (cons tcp-close          '(Nat -> Unit))))
