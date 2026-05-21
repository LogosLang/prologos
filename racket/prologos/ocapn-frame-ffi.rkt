#lang racket/base

;;;
;;; ocapn-frame-ffi.rkt — byte-marshalling FFI for the OCapN interop
;;; test server.
;;;
;;; The test server hands an inbound wire frame to the Prologos core
;;; (`prologos::ocapn::handshake`) as an ASCII hex string: embedding
;;; arbitrary Latin-1 bytes directly in a Prologos source literal is
;;; fragile, and a hex-decode loop written in Prologos is far too slow
;;; in the tree-walking reducer (~100s for a 300-byte frame). This
;;; module does the hex->bytes conversion in a single Racket call.
;;;
;;; Prologos `String` carries arbitrary bytes via Latin-1 (any 0-255
;;; byte is a 1-char Latin-1 string) — the same convention used by
;;; crypto-ffi.rkt and the `syrup-bytes` wire codec.

(require (only-in file/sha1 hex-string->bytes))

(provide ocapn-hex-decode)

(define (ocapn-hex-decode hex-str)
  "Decode an ASCII hex string into a Latin-1 byte-string."
  (bytes->string/latin-1 (hex-string->bytes hex-str)))
