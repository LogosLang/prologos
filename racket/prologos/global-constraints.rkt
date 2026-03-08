#lang racket/base

;;;
;;; global-constraints.rkt — Global Constraint Propagators for Narrowing
;;;
;;; Forward-checking constraints for the narrowing DFS search.
;;; After each variable binding, active constraints are checked:
;;;   - Violated → backtrack (return #f)
;;;   - Fully satisfied → remove from active set
;;;   - Partially checkable → narrow peer domains, keep in set
;;;
;;; Constraint types:
;;;   - all-different: all variables must have distinct values
;;;   - element: v = xs[i] (array element constraint)
;;;   - cumulative: task scheduling with capacity bound
;;;
;;; Phase 3c of FL Narrowing implementation.
;;;

(require racket/match
         racket/list
         "interval-domain.rkt"
         "syntax.rkt")

(provide
 ;; Constraint struct
 (struct-out narrow-constraint)
 ;; Constraint store parameter
 current-narrow-constraints
 ;; Forward-checking API
 forward-check
 ;; Helpers for testing
 expr->nat-val
 resolve-var
 var-ground?)

;; ========================================
;; Constraint representation
;; ========================================

;; narrow-constraint:
;;   kind: 'all-different | 'element | 'cumulative
;;   vars: (listof symbol) — variable names involved
;;   data: kind-specific data
;;     all-different: #f (no extra data)
;;     element: (list index-var-name value-var-name ground-list)
;;     cumulative: (list durations resources capacity)
(struct narrow-constraint (kind vars data) #:transparent)

;; Active constraint store, threaded via parameterize for backtracking.
(define current-narrow-constraints (make-parameter '()))

;; ========================================
;; Variable resolution helpers
;; ========================================

;; resolve-var : hasheq × symbol → expr | #f
;; Follow logic-var chains in the substitution.
;; Returns the resolved expression, or #f if the variable is unbound.
(define (resolve-var subst name)
  (define val (hash-ref subst name #f))
  (cond
    [(not val) #f]
    [(expr-logic-var? val)
     (resolve-var subst (expr-logic-var-name val))]
    [else val]))

;; var-ground? : hasheq × symbol → boolean
;; Is the variable bound to a fully ground (no logic vars) expression?
(define (var-ground? subst name)
  (define val (resolve-var subst name))
  (and val (ground-expr? val)))

;; ground-expr? : expr → boolean
;; Does the expression contain no logic variables?
(define (ground-expr? expr)
  (match expr
    [(expr-logic-var _ _) #f]
    [(expr-zero) #t]
    [(expr-true) #t]
    [(expr-false) #t]
    [(expr-unit) #t]
    [(expr-nil) #t]
    [(expr-nat-val _) #t]
    [(expr-int _) #t]
    [(expr-string _) #t]
    [(expr-keyword _) #t]
    [(expr-suc sub) (ground-expr? sub)]
    [(expr-app f a) (and (ground-expr? f) (ground-expr? a))]
    [(expr-pair a b) (and (ground-expr? a) (ground-expr? b))]
    [(expr-fvar _) #t]
    [_ #t]))

;; expr->nat-val : expr → exact-nonneg-integer | #f
;; Extract a natural number from a Peano expression (zero/suc chain).
;; Returns #f if the expression is not a complete Peano nat.
(define (expr->nat-val expr)
  (match expr
    [(expr-zero) 0]
    [(expr-nat-val n) n]
    [(expr-int n) (and (>= n 0) n)]
    [(expr-suc sub)
     (define sub-val (expr->nat-val sub))
     (and sub-val (+ sub-val 1))]
    [_ #f]))

;; ========================================
;; Forward-checking: main entry point
;; ========================================

;; forward-check : hasheq × (listof narrow-constraint) × hasheq
;;                 → (or/c #f (list hasheq (listof narrow-constraint) hasheq))
;;
;; Check all constraints against the current substitution.
;; Returns #f on contradiction, or (list subst remaining-constraints intervals).
;; Satisfied constraints are removed; partially checked constraints are kept.
(define (forward-check subst constraints intervals)
  (let loop ([cs constraints]
             [remaining '()]
             [ivs intervals])
    (cond
      [(null? cs)
       (list subst (reverse remaining) ivs)]
      [else
       (define c (car cs))
       (define result (check-one-constraint c subst ivs))
       (cond
         [(not result) #f]  ;; contradiction
         [else
          (define-values (status new-ivs) (apply values result))
          (case status
            [(satisfied)
             (loop (cdr cs) remaining new-ivs)]
            [(active)
             (loop (cdr cs) (cons c remaining) new-ivs)])])])))

;; check-one-constraint : narrow-constraint × hasheq × hasheq
;;                         → (or/c #f (list symbol hasheq))
;;
;; Check a single constraint. Returns:
;;   #f — contradiction
;;   (list 'satisfied intervals) — fully satisfied, can be removed
;;   (list 'active intervals) — still has unbound vars, keep checking
(define (check-one-constraint constraint subst intervals)
  (case (narrow-constraint-kind constraint)
    [(all-different)
     (check-all-different constraint subst intervals)]
    [(element)
     (check-element constraint subst intervals)]
    [(cumulative)
     (check-cumulative constraint subst intervals)]
    [else (list 'active intervals)]))

;; ========================================
;; all-different constraint
;; ========================================

;; check-all-different : constraint × subst × intervals → result
;;
;; For each pair of bound variables: if same ground value → contradiction.
;; For each bound variable with nat value v: remove v from unbound peers' intervals.
;; If all vars bound with distinct values → satisfied.
(define (check-all-different constraint subst intervals)
  (define var-names (narrow-constraint-vars constraint))
  ;; Partition into bound (ground) and unbound variables
  (define-values (bound-pairs unbound-names)
    (for/fold ([bp '()] [un '()])
              ([vn (in-list var-names)])
      (define val (resolve-var subst vn))
      (cond
        [(and val (ground-expr? val))
         (values (cons (cons vn val) bp) un)]
        [else
         (values bp (cons vn un))])))
  ;; Check bound pairs for duplicates
  (define bound-vals (map cdr bound-pairs))
  (define (vals-conflict? v1 v2)
    (equal? v1 v2))
  ;; Check all pairs of bound values for conflicts
  (define conflict?
    (let check ([vs bound-vals])
      (cond
        [(null? vs) #f]
        [else
         (or (for/or ([other (in-list (cdr vs))])
               (vals-conflict? (car vs) other))
             (check (cdr vs)))])))
  (cond
    [conflict? #f]  ;; contradiction
    ;; All bound, no conflicts → satisfied
    [(null? unbound-names)
     (list 'satisfied intervals)]
    [else
     ;; Narrow unbound peers' intervals by removing bound nat values
     (define bound-nat-vals
       (filter-map (lambda (bp) (expr->nat-val (cdr bp))) bound-pairs))
     (define new-intervals
       (for/fold ([ivs intervals])
                 ([un (in-list unbound-names)])
         (define iv (hash-ref ivs un #f))
         (cond
           [(not iv) ivs]
           [else
            (define narrowed
              (for/fold ([iv iv])
                        ([bv (in-list bound-nat-vals)])
                (interval-remove iv bv)))
            (if (interval-contradiction? narrowed)
                ;; Will be caught as contradiction below
                (hash-set ivs un narrowed)
                (hash-set ivs un narrowed))])))
     ;; Check if any interval became contradictory
     (define interval-contradiction
       (for/or ([un (in-list unbound-names)])
         (define iv (hash-ref new-intervals un #f))
         (and iv (interval-contradiction? iv))))
     (cond
       [interval-contradiction #f]
       [else (list 'active new-intervals)])]))

;; ========================================
;; element constraint
;; ========================================

;; check-element : constraint × subst × intervals → result
;;
;; element constraint: v = xs[i]
;; data = (list ground-list) where ground-list is a (listof expr)
;;
;; After binding i: v must equal xs[i].
;; After binding v: i must be one of the matching indices.
(define (check-element constraint subst intervals)
  (define var-names (narrow-constraint-vars constraint))
  (define i-var (car var-names))
  (define v-var (cadr var-names))
  (define xs (car (narrow-constraint-data constraint)))
  (define i-val (resolve-var subst i-var))
  (define v-val (resolve-var subst v-var))
  (define i-ground (and i-val (ground-expr? i-val)))
  (define v-ground (and v-val (ground-expr? v-val)))
  (cond
    ;; Both bound → check consistency
    [(and i-ground v-ground)
     (define idx (expr->nat-val i-val))
     (cond
       [(not idx) #f]  ;; index not a nat
       [(or (< idx 0) (>= idx (length xs))) #f]  ;; out of bounds
       [(equal? (list-ref xs idx) v-val)
        (list 'satisfied intervals)]
       [else #f])]  ;; mismatch
    ;; Index bound → constrain value
    [i-ground
     (define idx (expr->nat-val i-val))
     (cond
       [(not idx) #f]
       [(or (< idx 0) (>= idx (length xs))) #f]
       [else
        ;; v must equal xs[idx]; narrow v's interval to singleton
        (define target-val (list-ref xs idx))
        (define target-nat (expr->nat-val target-val))
        (define new-intervals
          (if target-nat
              (let ([iv (hash-ref intervals v-var #f)])
                (if iv
                    (let ([narrowed (interval-merge iv (interval target-nat target-nat))])
                      (if (interval-contradiction? narrowed)
                          (hash-set intervals v-var narrowed)
                          (hash-set intervals v-var narrowed)))
                    intervals))
              intervals))
        ;; Check contradiction
        (define v-iv (hash-ref new-intervals v-var #f))
        (cond
          [(and v-iv (interval-contradiction? v-iv)) #f]
          [else (list 'active new-intervals)])])]
    ;; Value bound → constrain index
    [v-ground
     (define matching-indices
       (for/list ([x (in-list xs)]
                  [j (in-naturals)]
                  #:when (equal? x v-val))
         j))
     (cond
       [(null? matching-indices) #f]  ;; no match → contradiction
       [else
        ;; Narrow i's interval to contain only matching indices
        (define lo (apply min matching-indices))
        (define hi (apply max matching-indices))
        (define new-iv (interval lo hi))
        (define i-iv (hash-ref intervals i-var #f))
        (define narrowed
          (if i-iv (interval-merge i-iv new-iv) new-iv))
        (cond
          [(interval-contradiction? narrowed) #f]
          [else
           (list 'active (hash-set intervals i-var narrowed))])])]
    ;; Neither bound → defer
    [else (list 'active intervals)]))

;; ========================================
;; cumulative constraint
;; ========================================

;; check-cumulative : constraint × subst × intervals → result
;;
;; cumulative: task scheduling with capacity bound.
;; vars = (listof symbol) — start-time variable names for each task
;; data = (list durations resources capacity)
;;   durations: (listof nat) — duration of each task
;;   resources: (listof nat) — resource usage of each task
;;   capacity: nat — maximum total resource at any time point
;;
;; Timetable filtering: after binding start times, check that at each
;; time point t, sum of resource[i] for all tasks i covering t does not
;; exceed capacity.
(define (check-cumulative constraint subst intervals)
  (define var-names (narrow-constraint-vars constraint))
  (define data (narrow-constraint-data constraint))
  (define durations (car data))
  (define resources (cadr data))
  (define capacity (caddr data))
  ;; Collect bound tasks: (start duration resource) triples
  (define-values (bound-tasks all-bound?)
    (for/fold ([tasks '()] [all? #t])
              ([vn (in-list var-names)]
               [dur (in-list durations)]
               [res (in-list resources)])
      (define val (resolve-var subst vn))
      (cond
        [(and val (ground-expr? val))
         (define start (expr->nat-val val))
         (cond
           [start (values (cons (list start dur res) tasks) all?)]
           [else (values tasks #f)])]
        [else (values tasks #f)])))
  (cond
    ;; No bound tasks → defer
    [(null? bound-tasks) (list 'active intervals)]
    [else
     ;; Check capacity at each time point covered by bound tasks
     (define all-time-points
       (remove-duplicates
        (append-map
         (lambda (task)
           (define start (car task))
           (define dur (cadr task))
           (for/list ([t (in-range start (+ start dur))]) t))
         bound-tasks)))
     (define capacity-ok?
       (for/and ([t (in-list all-time-points)])
         (define load
           (for/sum ([task (in-list bound-tasks)])
             (define start (car task))
             (define dur (cadr task))
             (define res (caddr task))
             (if (and (>= t start) (< t (+ start dur)))
                 res 0)))
         (<= load capacity)))
     (cond
       [(not capacity-ok?) #f]  ;; overloaded → contradiction
       [all-bound? (list 'satisfied intervals)]
       [else (list 'active intervals)])]))
