#lang racket/base

;;;
;;; wf-propagators.rkt — Well-Founded Propagator Patterns
;;;
;;; Translates logic program clauses into bilattice cell updates that
;;; compute the well-founded semantics via simultaneous mu/nu fixpoints.
;;;
;;; For each clause, two propagator directions are wired:
;;;   Lower (ascending): "if all body atoms are certainly true, head is certainly true"
;;;   Upper (descending): "head is possibly true only if some clause could prove it"
;;;
;;; Negation flips cross the bilattice: not-q's lower reads q's upper,
;;; not-q's upper reads q's lower. This makes negation monotone in the
;;; precision ordering.
;;;
;;; Design reference: docs/tracking/2026-03-14_WFLE_IMPLEMENTATION.md Phase 3
;;;

(require racket/list
         racket/set
         "propagator.rkt"
         "bilattice.rkt")

(provide
 ;; Individual propagator patterns
 wf-wire-fact
 wf-wire-negation
 wf-wire-positive-clause
 wf-wire-aggregate-upper
 ;; Clause & program compilation
 wf-compile-clause
 wf-compile-program)

;; ========================================
;; Fact Propagator
;; ========================================

;; Wire a ground fact: p. (no body)
;; lower-p := true (immediately), upper-p stays true.
;; Returns: new-network
(define (wf-wire-fact net p-bvar)
  (net-cell-write net (bilattice-var-lower-cid p-bvar) #t))

;; ========================================
;; Negation Propagator
;; ========================================

;; Wire a negative literal: create a derived bilattice-var for "not q"
;; whose lower/upper are the negation-flipped values of q.
;;
;; neg-lower = not(upper-q) : "not-q is certainly true iff q is certainly false"
;; neg-upper = not(lower-q) : "not-q is certainly false iff q is certainly true"
;;
;; These are monotone in precision ordering:
;;   upper-q descends -> not(upper-q) ascends (lower for not-q rises)
;;   lower-q ascends  -> not(lower-q) descends (upper for not-q falls)
;;
;; Returns: (values new-network neg-bvar)
(define (wf-wire-negation net q-bvar)
  (define lat (bilattice-var-lattice q-bvar))
  (define-values (net1 neg-bvar) (bilattice-new-var net lat))
  (define neg-lower-cid (bilattice-var-lower-cid neg-bvar))
  (define neg-upper-cid (bilattice-var-upper-cid neg-bvar))
  (define q-lower-cid (bilattice-var-lower-cid q-bvar))
  (define q-upper-cid (bilattice-var-upper-cid q-bvar))
  ;; Propagator: neg-lower := not(upper-q)
  (define-values (net2 _pid1)
    (net-add-propagator net1
      (list q-upper-cid)
      (list neg-lower-cid)
      (lambda (n)
        (define upper-q (net-cell-read n q-upper-cid))
        (net-cell-write n neg-lower-cid (not upper-q)))))
  ;; Propagator: neg-upper := not(lower-q)
  (define-values (net3 _pid2)
    (net-add-propagator net2
      (list q-lower-cid)
      (list neg-upper-cid)
      (lambda (n)
        (define lower-q (net-cell-read n q-lower-cid))
        (net-cell-write n neg-upper-cid (not lower-q)))))
  (values net3 neg-bvar))

;; ========================================
;; Positive Clause Propagator
;; ========================================

;; Wire the lower bound propagator for a positive clause: p :- q1, ..., qn
;; lower-p := lower-p or (lower-q1 and ... and lower-qn)
;; Upper bound is handled by the aggregate pattern.
;; Returns: new-network
(define (wf-wire-positive-clause net p-bvar q-bvars)
  (define lower-inputs (map bilattice-var-lower-cid q-bvars))
  (define lower-p-cid (bilattice-var-lower-cid p-bvar))
  (define-values (net1 _pid)
    (net-add-propagator net
      lower-inputs
      (list lower-p-cid)
      (lambda (n)
        (define body-lower
          (for/and ([bv (in-list q-bvars)])
            (net-cell-read n (bilattice-var-lower-cid bv))))
        (if body-lower
            (net-cell-write n lower-p-cid #t)
            n))))
  net1)

;; ========================================
;; Aggregate Upper Bound
;; ========================================

;; Wire the aggregate upper bound for atom p.
;; upper-p = OR over all clauses c of (body-upper(c))
;; "p is possibly true iff at least one clause could possibly prove it"
;;
;; all-body-upper-cids: (listof cell-id) — all cells any clause reads for upper bounds
;; clause-body-upper-fns: (listof (prop-network -> Bool))
;; Returns: new-network
(define (wf-wire-aggregate-upper net p-bvar all-body-upper-cids clause-body-upper-fns)
  (define upper-p-cid (bilattice-var-upper-cid p-bvar))
  (define-values (net1 _pid)
    (net-add-propagator net
      all-body-upper-cids
      (list upper-p-cid)
      (lambda (n)
        (define any-feasible?
          (for/or ([clause-fn (in-list clause-body-upper-fns)])
            (clause-fn n)))
        (if any-feasible?
            n  ;; at least one clause could work — upper stays #t
            (net-cell-write n upper-p-cid #f)))))
  net1)

;; ========================================
;; Clause Compilation
;; ========================================

;; Compile a single clause into bilattice propagators.
;;
;; head-bvar: bilattice-var for the head atom
;; body-specs: (listof (cons 'pos|'neg bilattice-var))
;;
;; Returns: (values new-network body-upper-fn body-bvars)
;;   body-upper-fn: (prop-network -> Bool) — this clause's body feasibility
;;   body-bvars: (listof bilattice-var) — effective body bvars after negation wiring
(define (wf-compile-clause net head-bvar body-specs)
  ;; Phase 1: wire negation for negative literals -> get effective bvars
  (define-values (net1 effective-bvars)
    (for/fold ([n net] [bvars '()])
              ([spec (in-list body-specs)])
      (case (car spec)
        [(pos) (values n (cons (cdr spec) bvars))]
        [(neg)
         (define-values (n2 neg-bvar) (wf-wire-negation n (cdr spec)))
         (values n2 (cons neg-bvar bvars))])))
  (define eff-bvars (reverse effective-bvars))
  ;; Phase 2: wire lower bound propagator
  (define lower-inputs (map bilattice-var-lower-cid eff-bvars))
  (define lower-head-cid (bilattice-var-lower-cid head-bvar))
  (define-values (net2 _pid)
    (net-add-propagator net1
      lower-inputs
      (list lower-head-cid)
      (lambda (n)
        (define body-lower
          (for/and ([bv (in-list eff-bvars)])
            (net-cell-read n (bilattice-var-lower-cid bv))))
        (if body-lower
            (net-cell-write n lower-head-cid #t)
            n))))
  ;; Phase 3: construct body-upper-fn
  (define body-upper-fn
    (lambda (n)
      (for/and ([bv (in-list eff-bvars)])
        (net-cell-read n (bilattice-var-upper-cid bv)))))
  (values net2 body-upper-fn eff-bvars))

;; ========================================
;; Program Compilation
;; ========================================

;; Compile a complete logic program into a bilattice propagator network.
;;
;; program: (listof (cons head-name body-specs))
;;   where head-name is a symbol and body-specs is
;;   (listof (cons 'pos|'neg atom-name))
;;
;; Example: '((p (neg . q)) (q (neg . p)))
;;   = p :- not q. q :- not p.
;;
;; A clause with empty body represents a fact:
;;   '((c)) = c.
;;
;; Returns: (values new-network atom-bvar-map)
;;   atom-bvar-map: hasheq : symbol -> bilattice-var
(define (wf-compile-program net program)
  ;; Phase 1: collect all atom names
  (define all-atoms
    (remove-duplicates
     (append (map car program)
             (apply append
                    (for/list ([clause (in-list program)])
                      (map cdr (cdr clause)))))))
  ;; Phase 2: create bilattice-vars for all atoms
  (define-values (net1 atom-map)
    (for/fold ([n net] [m (hasheq)])
              ([atom (in-list all-atoms)])
      (if (hash-has-key? m atom)
          (values n m)
          (let-values ([(n2 bvar) (bilattice-new-var n bool-lattice)])
            (values n2 (hash-set m atom bvar))))))
  ;; Phase 3: compile each clause
  (define-values (net2 head-clause-info)
    (for/fold ([n net1] [hci (hasheq)])
              ([clause (in-list program)])
      (define head-name (car clause))
      (define body-specs (cdr clause))
      (define head-bvar (hash-ref atom-map head-name))
      (cond
        ;; Fact: empty body
        [(null? body-specs)
         (define n2 (wf-wire-fact n head-bvar))
         (values n2 hci)]
        ;; Clause with body
        [else
         (define resolved-body
           (for/list ([spec (in-list body-specs)])
             (cons (car spec) (hash-ref atom-map (cdr spec)))))
         (define-values (n2 body-upper-fn body-bvars)
           (wf-compile-clause n head-bvar resolved-body))
         (values n2
                 (hash-update hci head-name
                              (lambda (entries)
                                (cons (list body-upper-fn body-bvars) entries))
                              '()))])))
  ;; Phase 4: wire aggregate upper bounds for atoms that have clauses
  (define net3
    (for/fold ([n net2])
              ([(head-name entries) (in-hash head-clause-info)])
      (define head-bvar (hash-ref atom-map head-name))
      (define fns (map car entries))
      (define clause-upper-cids
        (remove-duplicates
         (apply append
                (for/list ([entry (in-list entries)])
                  (map bilattice-var-upper-cid (cadr entry))))))
      (wf-wire-aggregate-upper n head-bvar clause-upper-cids fns)))
  ;; Phase 5: wire aggregate upper bounds for atoms with NO clauses
  ;; (atoms that appear only in bodies, never as heads)
  ;; These atoms are unfounded — their upper bound should be false.
  (define head-atoms (list->set (map car program)))
  (define net4
    (for/fold ([n net3])
              ([atom (in-list all-atoms)])
      (if (set-member? head-atoms atom)
          n
          ;; No clauses for this atom — upper := false
          (let ([bvar (hash-ref atom-map atom)])
            (wf-wire-aggregate-upper n bvar '() '())))))
  (values net4 atom-map))
