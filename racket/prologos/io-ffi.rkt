#lang racket/base

;;;
;;; io-ffi.rkt — FFI bridge: Racket IO primitives wrapped for Prologos
;;;
;;; Registry mapping function names to (cons racket-procedure type-descriptor).
;;; These are NOT registered in the Prologos namespace yet — that happens in
;;; IO-D when io.prologos does (foreign racket "io-ffi.rkt" ...).
;;; For IO-B, this is just the registry + wrapper functions.
;;;
;;; Design reference: docs/tracking/2026-03-05_IO_IMPLEMENTATION_DESIGN.md §10
;;;

(require racket/file)

(provide
 io-ffi-registry
 ;; Wrapper functions (exported for direct testing in IO-B3)
 port-read-string
 port-read-line
 port-write-string
 io-close-port
 display-wrapper
 displayln-wrapper
 read-line-wrapper)

;; ========================================
;; Wrapper Functions
;; ========================================
;;
;; Handle Racket IO quirks: EOF objects → empty strings,
;; void returns for write operations, etc.

(define (port-read-string port)
  (define s (read-string 1048576 port))  ;; 1MB max
  (if (eof-object? s) "" s))

(define (port-read-line port)
  (define s (read-line port))
  (if (eof-object? s) "" s))

(define (port-write-string port str)
  (write-string str port)
  (void))

;; Racket has close-input-port and close-output-port but no generic close-port.
;; This wrapper handles both.
(define (io-close-port port)
  (if (input-port? port)
      (close-input-port port)
      (close-output-port port))
  (void))

(define (display-wrapper str) (display str) (void))
(define (displayln-wrapper str) (displayln str) (void))
(define (read-line-wrapper) (read-line))

;; ========================================
;; FFI Registry
;; ========================================
;;
;; Maps Prologos function names to (cons racket-procedure type-descriptor).
;; Type descriptors use the same format as foreign.rkt:
;;   (cons '(arg-types ...) 'return-type)
;; The Opaque:file-port tag wraps Racket ports as expr-opaque values.

(define io-ffi-registry
  (hasheq
   ;; File operations
   'io-open-input    (cons open-input-file    '((String) . Opaque:file-port))
   'io-open-output   (cons open-output-file   '((String) . Opaque:file-port))
   'io-read-string   (cons port-read-string   '((Opaque:file-port) . String))
   'io-read-line     (cons port-read-line     '((Opaque:file-port) . String))
   'io-write-string  (cons port-write-string  '((Opaque:file-port String) . Unit))
   'io-close         (cons io-close-port      '((Opaque:file-port) . Unit))
   'io-port-closed?  (cons port-closed?       '((Opaque:file-port) . Bool))
   ;; Console
   'io-display       (cons display-wrapper    '((String) . Unit))
   'io-displayln     (cons displayln-wrapper  '((String) . Unit))
   'io-read-ln       (cons read-line-wrapper  '(() . String))
   ;; Filesystem queries
   'io-file-exists?  (cons file-exists?       '((String) . Bool))
   'io-directory?    (cons directory-exists?   '((String) . Bool))))
