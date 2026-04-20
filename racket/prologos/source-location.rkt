#lang racket/base

;;;
;;; PROLOGOS SOURCE LOCATION
;;; Source location tracking for error reporting.
;;;

(provide
 (struct-out srcloc)
 srcloc-unknown
 format-srcloc
 ;; PPN 4C Phase 1.5: unified current-source-location infrastructure.
 ;; SCAFFOLDING. Racket parameter carries dynamic-scope context for
 ;; emit sites (warnings, errors, diagnostics). Value is DERIVED from
 ;; on-network state (surf-node srcloc fields during elaboration;
 ;; propagator struct srcloc field during fire). PM Track 12 evaluates
 ;; during its scoping phase whether this remains a parameter or
 ;; migrates to a cell; tracking row in DEFERRED.md.
 ;;
 ;; Readers: emit sites call (current-source-loc) to tag warnings/errors.
 ;; Writers (via parameterize): elaborate recursion entries, driver
 ;; command entries, scheduler fire wrapping (via fire-propagator helper
 ;; in propagator.rkt).
 current-source-loc)

;; Source location: file, line, column, span
(struct srcloc (file line col span) #:transparent)

;; Sentinel for unknown locations
(define srcloc-unknown (srcloc "<unknown>" 0 0 0))

;; PPN 4C Phase 1.5: current source location parameter.
;; #f = unknown (top-level, no surf-node context).
;; Set via parameterize at: elaborate entry, driver command entry,
;; scheduler fire wrapping (via fire-propagator in propagator.rkt).
(define current-source-loc (make-parameter #f))

;; Format a source location for display
(define (format-srcloc loc)
  (cond
    [(not loc) "<unknown>"]
    [(equal? loc srcloc-unknown) "<unknown>"]
    [else (format "~a:~a:~a"
                  (srcloc-file loc)
                  (srcloc-line loc)
                  (srcloc-col loc))]))
