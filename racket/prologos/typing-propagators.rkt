#lang racket/base

;;;
;;; typing-propagators.rkt — PPN Track 4: Elaboration as Attribute Evaluation
;;;
;;; Infrastructure for propagator-based type inference. Typing rules are
;;; DPO rewrite rules (Engelfriet-Heyker: HR grammars = attribute grammars).
;;; Types live in form cells' type-maps (PU values). Context is a cell.
;;;
;;; Phase 1c: Context lattice — typing context as cells.
;;; Phase 2+: DPO typing rules, tensor propagator, etc.
;;;

(require racket/match
         "syntax.rkt")

(provide
 ;; Phase 1c: Context lattice
 (struct-out context-cell-value)
 context-empty-value
 context-extend-value
 context-lookup-type
 context-lookup-mult
 context-cell-merge
 context-cell-contradicts?)

;; ============================================================
;; Phase 1c: Context Lattice
;; ============================================================
;;
;; The typing context IS a cell. Its PU value is a binding stack
;; (list of (type . mult) pairs using de Bruijn indices).
;;
;; Lattice structure:
;;   bot = empty context (no bindings)
;;   merge = pointwise on bindings at each position
;;   tensor (extension) = prepend new binding (creates child cell)
;;
;; This parallels Module Theory (SRE Track 7): a typing context
;; is a "local module" with positional exports.

;; A context cell's value. Wraps the binding stack with metadata
;; for lattice operations (parent tracking for scope nesting).
(struct context-cell-value
  (bindings    ;; (listof (cons type mult)): de Bruijn binding stack
   depth)      ;; Nat: nesting depth (0 = top-level)
  #:transparent)

;; Bot: empty context (top-level scope)
(define context-empty-value
  (context-cell-value '() 0))

;; Tensor: extend context with a new binding (enter a binder scope).
;; Returns a new context-cell-value (for writing to a child context cell).
;; The child is at depth+1.
(define (context-extend-value ctx-val type mult)
  (context-cell-value
   (cons (cons type mult)
         (context-cell-value-bindings ctx-val))
   (add1 (context-cell-value-depth ctx-val))))

;; Lookup type at de Bruijn position k.
;; Returns the type, or expr-error if k is out of bounds.
(define (context-lookup-type ctx-val k)
  (define bindings (context-cell-value-bindings ctx-val))
  (if (< k (length bindings))
      (car (list-ref bindings k))
      (expr-error)))

;; Lookup multiplicity at de Bruijn position k.
;; Returns the mult, or #f if k is out of bounds.
(define (context-lookup-mult ctx-val k)
  (define bindings (context-cell-value-bindings ctx-val))
  (if (< k (length bindings))
      (cdr (list-ref bindings k))
      #f))

;; Merge function for context cells. Pointwise merge on bindings:
;; - Same length: merge each (type . mult) pair
;; - Different length: take the LONGER (more information = deeper scope)
;; - Type merge: equal? check (Phase 2 will wire in type-lattice-merge)
;; - Mult merge: keep the more informative (max in QTT ordering)
;;
;; Context cells form TREES (parent→child via extension), and under ATMS
;; branching, each branch has its own worldview (TMS layer handles this).
;; There is no cross-branch context merging — the merge below handles
;; the case where two propagators write to the same context cell within
;; a single worldview.
(define (context-cell-merge old new)
  (cond
    ;; If either is the empty/bot value, take the other
    [(null? (context-cell-value-bindings old)) new]
    [(null? (context-cell-value-bindings new)) old]
    ;; Same depth: pointwise merge
    [(= (context-cell-value-depth old) (context-cell-value-depth new))
     (context-cell-value
      (map (lambda (ob nb)
             (cons
              ;; Type: if equal keep, otherwise keep newer (Phase 2: lattice merge)
              (if (equal? (car ob) (car nb)) (car ob) (car nb))
              ;; Mult: if equal keep, otherwise keep newer
              (if (equal? (cdr ob) (cdr nb)) (cdr ob) (cdr nb))))
           (context-cell-value-bindings old)
           (context-cell-value-bindings new))
      (context-cell-value-depth old))]
    ;; Different depth: take the deeper (more information)
    [(> (context-cell-value-depth new) (context-cell-value-depth old)) new]
    [else old]))

;; Context cells don't have a contradiction state (no type-top equivalent).
;; A contradicted binding will show up as type-top IN the type lattice,
;; not in the context lattice.
(define (context-cell-contradicts? v) #f)
