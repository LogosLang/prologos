#lang racket/base

;;;
;;; PROLOGOS/SEXP MODULE LANGUAGE
;;; Backward-compatible S-expression syntax for #lang prologos/sexp.
;;; Uses Racket's standard reader (parenthesized S-expressions).
;;;

;; Re-export everything from the main prologos module
(require "main.rkt")
(provide (all-from-out "main.rkt"))

;; Reader submodule: uses custom readtable with < > angle bracket support
(module reader syntax/module-reader
  prologos/sexp
  #:read prologos-sexp-read
  #:read-syntax prologos-sexp-read-syntax
  (require prologos/sexp-readtable))
