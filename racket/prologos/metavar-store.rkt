#lang racket/base

;;;
;;; PROLOGOS METAVARIABLE STORE
;;; Infrastructure for type inference metavariables.
;;;
;;; A metavariable represents an unknown term (type, implicit argument,
;;; universe level, etc.) that will be solved during elaboration and
;;; unification. Each metavariable has:
;;;   - A unique gensym ID
;;;   - The typing context in which it was created
;;;   - The expected type of its solution
;;;   - A status ('unsolved or 'solved)
;;;   - An optional solution (expr or #f)
;;;   - A list of constraints (for Sprint 2)
;;;   - Source info for error reporting
;;;
;;; The store is a mutable hash wrapped in a Racket parameter,
;;; enabling per-definition isolation via parameterize.
;;;

(require "syntax.rkt")

(provide
 ;; Meta-info struct
 (struct-out meta-info)
 ;; Store parameter
 current-meta-store
 ;; API
 fresh-meta
 solve-meta!
 meta-solved?
 meta-solution
 meta-lookup
 reset-meta-store!
 all-unsolved-metas)

;; ========================================
;; Meta-info: everything about a single metavariable
;; ========================================
(struct meta-info
  (id          ;; symbol (gensym), e.g. 'meta42
   ctx         ;; typing context at creation (list of (cons type mult))
   type        ;; expected type of the solution (Expr)
   status      ;; 'unsolved or 'solved
   solution    ;; Expr or #f if unsolved
   constraints ;; (listof any) — empty in Sprint 1, used by Sprint 2
   source)     ;; any — debug info (source location, description string)
  #:transparent
  #:mutable)

;; ========================================
;; Global metavariable store
;; ========================================
;; Mutable hash (symbol -> meta-info) inside a parameter.
;; Use parameterize with (make-hasheq) for isolation in tests/modules.
(define current-meta-store (make-parameter (make-hasheq)))

;; ========================================
;; API
;; ========================================

;; Create a fresh metavariable, register it in the store, return expr-meta.
(define (fresh-meta ctx type source)
  (define id (gensym 'meta))
  (define info (meta-info id ctx type 'unsolved #f '() source))
  (hash-set! (current-meta-store) id info)
  (expr-meta id))

;; Assign a solution to a metavariable. Errors if already solved.
(define (solve-meta! id solution)
  (define info (hash-ref (current-meta-store) id #f))
  (unless info
    (error 'solve-meta! "unknown metavariable: ~a" id))
  (when (eq? (meta-info-status info) 'solved)
    (error 'solve-meta! "metavariable ~a already solved" id))
  (set-meta-info-status! info 'solved)
  (set-meta-info-solution! info solution))

;; Check if a metavariable has been solved.
(define (meta-solved? id)
  (define info (hash-ref (current-meta-store) id #f))
  (and info (eq? (meta-info-status info) 'solved)))

;; Retrieve the solution of a metavariable, or #f if unsolved/unknown.
(define (meta-solution id)
  (define info (hash-ref (current-meta-store) id #f))
  (and info (meta-info-solution info)))

;; Retrieve the full meta-info struct, or #f if unknown.
(define (meta-lookup id)
  (hash-ref (current-meta-store) id #f))

;; Clear all metavariables from the store.
(define (reset-meta-store!)
  (hash-clear! (current-meta-store)))

;; List all unsolved metavariable infos.
(define (all-unsolved-metas)
  (for/list ([(id info) (in-hash (current-meta-store))]
             #:when (eq? (meta-info-status info) 'unsolved))
    info))
