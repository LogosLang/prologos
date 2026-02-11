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
;;;   - A list of constraints (for Sprint 5)
;;;   - Source info for error reporting
;;;
;;; The store is a mutable hash wrapped in a Racket parameter,
;;; enabling per-definition isolation via parameterize.
;;;

(require racket/list
         "syntax.rkt")

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
 all-unsolved-metas
 ;; Sprint 5: Constraint postponement
 (struct-out constraint)
 current-constraint-store
 current-wakeup-registry
 current-retry-unify
 add-constraint!
 collect-meta-ids
 get-wakeup-constraints
 reset-constraint-store!
 all-postponed-constraints
 all-failed-constraints)

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
;; Sprint 5: Constraint postponement
;; ========================================
;; A constraint is a deferred unification obligation that can't be solved
;; immediately (e.g., when pattern-check fails for an applied metavariable).
;; Constraints are retried when the metavariables they mention get solved.

(struct constraint
  (lhs       ;; Expr — left side of unification
   rhs       ;; Expr — right side of unification
   ctx       ;; Context — typing context at creation
   source    ;; any — debug info (description string)
   status)   ;; 'postponed | 'retrying | 'solved | 'failed
  #:transparent
  #:mutable)

;; Global constraint store: list of all constraints
(define current-constraint-store (make-parameter '()))

;; Per-meta wakeup registry: maps meta-id -> (listof constraint)
(define current-wakeup-registry (make-parameter (make-hasheq)))

;; Callback for constraint retry (set by unify.rkt at initialization).
;; This avoids a circular dependency: metavar-store.rkt -> unify.rkt.
(define current-retry-unify (make-parameter #f))

;; Walk an expression and collect all unsolved meta IDs referenced in it.
;; Uses struct->vector generic traversal (same pattern as occurs? in unify.rkt).
(define (collect-meta-ids expr)
  (let walk ([e expr] [acc '()])
    (cond
      [(expr-meta? e)
       (let ([id (expr-meta-id e)])
         (if (meta-solved? id)
             ;; Follow solved meta's solution to find transitive metas
             (let ([sol (meta-solution id)])
               (if sol (walk sol acc) acc))
             (if (memq id acc) acc (cons id acc))))]
      [(struct? e)
       (let ([v (struct->vector e)])
         (for/fold ([a acc])
                   ([i (in-range 1 (vector-length v))])
           (let ([field (vector-ref v i)])
             (if (or (struct? field) (expr-meta? field))
                 (walk field a)
                 a))))]
      [else acc])))

;; Create a postponed constraint, add to global store, register for wakeup.
(define (add-constraint! lhs rhs ctx source)
  (define c (constraint lhs rhs ctx source 'postponed))
  ;; Add to global store
  (current-constraint-store (cons c (current-constraint-store)))
  ;; Register for wakeup on all mentioned metas
  (define meta-ids (append (collect-meta-ids lhs) (collect-meta-ids rhs)))
  (define registry (current-wakeup-registry))
  (for ([id (in-list meta-ids)])
    (define existing (hash-ref registry id '()))
    (hash-set! registry id (cons c existing)))
  c)

;; Get constraints associated with a metavariable for wakeup.
(define (get-wakeup-constraints meta-id)
  (hash-ref (current-wakeup-registry) meta-id '()))

;; Retry postponed constraints that mention the given meta.
;; Uses 'retrying guard to prevent infinite re-entrant loops.
(define (retry-constraints-for-meta! meta-id)
  (define retry-fn (current-retry-unify))
  (when retry-fn
    (define constraints (get-wakeup-constraints meta-id))
    (for ([c (in-list constraints)])
      (when (eq? (constraint-status c) 'postponed)
        ;; Guard against re-entrant retry
        (set-constraint-status! c 'retrying)
        (retry-fn c)
        ;; If still 'retrying after the call, set back to 'postponed
        (when (eq? (constraint-status c) 'retrying)
          (set-constraint-status! c 'postponed))))))

;; Reset the constraint store (called by reset-meta-store!).
(define (reset-constraint-store!)
  (current-constraint-store '())
  (hash-clear! (current-wakeup-registry)))

;; Query: all postponed constraints.
(define (all-postponed-constraints)
  (filter (lambda (c) (eq? (constraint-status c) 'postponed))
          (current-constraint-store)))

;; Query: all failed constraints.
(define (all-failed-constraints)
  (filter (lambda (c) (eq? (constraint-status c) 'failed))
          (current-constraint-store)))

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
;; After solving, retries any postponed constraints that mention this meta.
(define (solve-meta! id solution)
  (define info (hash-ref (current-meta-store) id #f))
  (unless info
    (error 'solve-meta! "unknown metavariable: ~a" id))
  (when (eq? (meta-info-status info) 'solved)
    (error 'solve-meta! "metavariable ~a already solved" id))
  (set-meta-info-status! info 'solved)
  (set-meta-info-solution! info solution)
  ;; Sprint 5: retry postponed constraints that mention this meta
  (retry-constraints-for-meta! id))

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

;; Clear all metavariables and constraints from the store.
(define (reset-meta-store!)
  (hash-clear! (current-meta-store))
  (reset-constraint-store!))

;; List all unsolved metavariable infos.
(define (all-unsolved-metas)
  (for/list ([(id info) (in-hash (current-meta-store))]
             #:when (eq? (meta-info-status info) 'unsolved))
    info))
