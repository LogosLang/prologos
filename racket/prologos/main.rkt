#lang racket/base

;;;
;;; PROLOGOS MODULE LANGUAGE
;;; Entry point for #lang prologos.
;;;
;;; When a file begins with `#lang prologos`, Racket:
;;;   1. Finds the reader submodule below, which uses the custom
;;;      indentation-sensitive reader.
;;;   2. Wraps all read forms in (module <name> prologos <forms>...).
;;;   3. Resolves `prologos` to this module (prologos/main.rkt).
;;;   4. Uses the exports below (#%module-begin, etc.) as the
;;;      initial bindings.
;;;   5. The #%module-begin macro runs the full Prologos type checker
;;;      at compile time, raising exn:fail:prologos on errors.
;;;   6. At runtime, the env is populated for REPL use.
;;;

(require (for-syntax racket/base
                     "expander.rkt")
         ;; Runtime REPL support (separate module to avoid circular deps)
         "repl-support.rkt")

;; ========================================
;; Module-level macros
;; ========================================

;; #%module-begin: wraps the entire module body.
;; All type checking happens at compile time inside expand-prologos-module.
(define-syntax (prologos-module-begin stx)
  (expand-prologos-module stx))

;; #%top: handles unbound identifiers (bare symbols).
;; Returns them as quoted values so the parser can handle them.
(define-syntax (prologos-top stx)
  (syntax-case stx ()
    [(_ . x) #''x]))

;; #%datum: handles literal datums (numbers, booleans, etc.)
(define-syntax (prologos-datum stx)
  (syntax-case stx ()
    [(_ . x) #''x]))

;; #%top-interaction: handles REPL interactions in DrRacket.
;; Forwards the form to the runtime prologos-repl-eval function.
(define-syntax (prologos-top-interaction stx)
  (syntax-case stx ()
    [(_ . form)
     #'(prologos-repl-eval (quote-syntax form))]))

;; ========================================
;; Provide the module-level macros + REPL support
;; ========================================
(provide (rename-out [prologos-module-begin #%module-begin]
                     [prologos-top-interaction #%top-interaction]
                     [prologos-top #%top]
                     [prologos-datum #%datum])
         ;; Re-export REPL support for use in generated code
         (all-from-out "repl-support.rkt"))

;; ========================================
;; Reader submodule
;; ========================================
;; Uses the custom Prologos reader with significant whitespace.
;; #:whole-body-readers? #t means the reader returns a list of all forms at once,
;; which is necessary for indentation-sensitive parsing.
;; For S-expression syntax, use #lang prologos/sexp instead.
(module reader syntax/module-reader
  prologos
  #:whole-body-readers? #t
  #:read-syntax (lambda (src in) (prologos-read-syntax-all src in))
  #:read (lambda (in) (list (prologos-read in)))
  (require prologos/reader))
