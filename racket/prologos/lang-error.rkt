#lang racket/base

;;;
;;; PROLOGOS LANG-ERROR
;;; Bridge between kernel prologos-error structs and Racket's exn:fail
;;; exception hierarchy. When a type error or parse error occurs during
;;; #%module-begin expansion, this module converts it into a proper
;;; Racket exception that DrRacket can highlight.
;;;
;;; Follows the Pie language pattern: store raw location lists in the
;;; exception, construct Racket srcloc values inside prop:exn:srclocs.
;;;

(require racket/match
         (prefix-in prologos: "source-location.rkt")
         "errors.rkt")

(provide (struct-out exn:fail:prologos)
         raise-prologos-error)

;; ========================================
;; Exception struct with source location support
;; ========================================

;; The `where` field stores a raw list (list source line col pos span)
;; or #f if location is unknown. The prop:exn:srclocs property tells
;; DrRacket where to highlight the error.
(struct exn:fail:prologos exn:fail (where)
  #:property prop:exn:srclocs
  (lambda (e)
    (match (exn:fail:prologos-where e)
      [(list src line col pos span)
       (define real-src
         (if (and (string? src) (file-exists? src))
             (string->path src)
             src))
       (list (srcloc real-src line col pos span))]
      [_ '()]))
  #:transparent)

;; ========================================
;; Convert and raise a prologos-error
;; ========================================

;; Convert our prologos srcloc to the raw list format.
(define (prologos-loc->where loc)
  (if (equal? loc prologos:srcloc-unknown)
      #f
      (list (prologos:srcloc-file loc)
            (prologos:srcloc-line loc)
            (prologos:srcloc-col loc)
            #f    ;; position (we don't track byte offset)
            (prologos:srcloc-span loc))))

;; Raise a prologos-error as a Racket exception.
;; Used inside the #%module-begin macro when type checking fails.
(define (raise-prologos-error err)
  (define msg (format-error err))
  (define where (prologos-loc->where (prologos-error-srcloc err)))
  (raise (exn:fail:prologos msg (current-continuation-marks) where)))
