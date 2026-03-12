#lang racket/base

;;; diagnostics.rkt — Convert Prologos errors to LSP Diagnostic objects
;;;
;;; Maps prologos-error structs from the elaboration pipeline to
;;; LSP Diagnostic JSON, including error codes (E1001-E3001),
;;; severity levels, and source location conversion.

(require json
         "../errors.rkt")

(provide error->diagnostic
         errors->diagnostics
         srcloc->range
         warning->diagnostic)

;; ============================================================
;; Error code mapping
;; ============================================================

;; Map error tag symbols to LSP diagnostic codes.
;; Tags are set by the elaboration pipeline (typing-errors.rkt).
(define (error->code err)
  (define msg (if (prologos-error? err)
                  (prologos-error-message err)
                  (format "~a" err)))
  (cond
    [(regexp-match? #rx"(?i:type.?mismatch)" msg)      "E1001"]
    [(regexp-match? #rx"(?i:unbound)"        msg)      "E1002"]
    [(regexp-match? #rx"(?i:multiplicity)"   msg)      "E1003"]
    [(regexp-match? #rx"(?i:cannot infer)"   msg)      "E1004"]
    [(regexp-match? #rx"(?i:inference)"      msg)      "E1004"]
    [(regexp-match? #rx"(?i:param).*(type|infer)" msg) "E1005"]
    [(regexp-match? #rx"(?i:conflict)"       msg)      "E1006"]
    [(regexp-match? #rx"(?i:no instance)"    msg)      "E1007"]
    [(regexp-match? #rx"(?i:no).+impl"       msg)      "E1007"]
    [(regexp-match? #rx"(?i:parse)"          msg)      "E2001"]
    [(regexp-match? #rx"(?i:syntax)"         msg)      "E2001"]
    [(regexp-match? #rx"(?i:arity)"          msg)      "E2002"]
    [(regexp-match? #rx"(?i:session)"        msg)      "E3001"]
    [else                                             "E0000"]))

;; ============================================================
;; Diagnostic constructors
;; ============================================================

;; Convert a prologos-error to an LSP Diagnostic hasheq.
;; LSP Diagnostic: { range, severity, source, message, code }
(define (error->diagnostic err)
  (define loc (and (prologos-error? err)
                   (prologos-error-srcloc err)))
  (hasheq 'range    (srcloc->range loc)
          'severity 1  ; DiagnosticSeverity.Error = 1
          'source   "prologos"
          'message  (if (prologos-error? err)
                        (prologos-error-message err)
                        (format "~a" err))
          'code     (error->code err)))

;; Convert a warning string to a Warning diagnostic.
(define (warning->diagnostic msg [loc #f])
  (hasheq 'range    (srcloc->range loc)
          'severity 2  ; DiagnosticSeverity.Warning = 2
          'source   "prologos"
          'message  msg
          'code     "W1001"))

;; Convert a list of errors to a list of diagnostics.
(define (errors->diagnostics errs)
  (map error->diagnostic errs))

;; ============================================================
;; Source location conversion
;; ============================================================

;; Convert a Prologos srcloc to an LSP Range.
;; LSP uses 0-based lines, 0-based characters.
;; Prologos uses 1-based lines, 0-based columns.
(define (srcloc->range loc)
  (cond
    [(and loc
          (list? loc)
          (>= (length loc) 4)
          (number? (list-ref loc 0))
          (number? (list-ref loc 1)))
     ;; loc = (source line col pos span) or (line col pos span)
     ;; Try to extract line and col
     (define line (list-ref loc 0))
     (define col  (list-ref loc 1))
     (define span (if (>= (length loc) 5)
                      (or (list-ref loc 4) 1)
                      (if (>= (length loc) 4)
                          (or (list-ref loc 3) 1)
                          1)))
     (make-range (sub1 (max 1 line)) col
                 (sub1 (max 1 line)) (+ col span))]
    [(and loc (vector? loc) (>= (vector-length loc) 4))
     ;; vector form: #(source line col pos span)
     (define line (vector-ref loc 1))
     (define col  (vector-ref loc 2))
     (define span (if (>= (vector-length loc) 5)
                      (or (vector-ref loc 4) 1)
                      1))
     (make-range (sub1 (max 1 line)) col
                 (sub1 (max 1 line)) (+ col span))]
    [else
     ;; Unknown or missing location — position 0:0
     (make-range 0 0 0 0)]))

;; Helper: construct an LSP Range.
(define (make-range start-line start-char end-line end-char)
  (hasheq 'start (hasheq 'line start-line 'character start-char)
          'end   (hasheq 'line end-line   'character end-char)))
