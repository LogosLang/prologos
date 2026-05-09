#lang racket/base

;;; test-preduce-phase10b.rkt
;;;
;;; Phase 10b — expr-reduce dispatch over USER-DEFINED constructors.
;;;
;;; Phase 10 covered built-in constructors only (true/false/zero/suc/
;;; refl/nil/vnil/vcons/fzero/fsuc/pair). Phase 10b extends expr-reduce
;;; to dispatch over user-declared `data` constructors via the ctor
;;; registry. The compile-expr path now recognizes:
;;;   - bare nullary ctor references (expr-fvar)
;;;   - fully-applied curried ctor applications (expr-app chain)
;;;     (with optional explicit type-arg prefix)
;;; and produces a `preduce-user-ctor` value that classify-ctor in
;;; make-reduce-fire dispatches on by short ctor name.
;;;
;;; This unblocks the OCapN compatibility-target Tier B port (syrup,
;;; promise, message) under PReduce-lite. Validation of those ports
;;; under PReduce-lite waits on Phase 10b (this) + the rest of the
;;; lite reducer's coverage.

(require rackunit
         "../syntax.rkt"
         "../preduce.rkt"
         "../macros.rkt"
         (only-in "../reduction.rkt" nf))

;; ====================================================================
;; Test fixtures: register synthetic data types in the ctor registry.
;; Mirrors what the elaborator does for `data Color = red | rgb Nat`.
;; ====================================================================

;; data Color := red | rgb Nat
(register-ctor! 'phase10b-red (ctor-meta 'Color '() '()      '()  0))
(register-ctor! 'phase10b-rgb (ctor-meta 'Color '() (list 'Nat) '(#f) 1))

;; data Tree := leaf | node Tree Tree   (binary, recursive)
(register-ctor! 'phase10b-leaf (ctor-meta 'Tree '() '()                  '()         0))
(register-ctor! 'phase10b-node (ctor-meta 'Tree '() (list 'Tree 'Tree)   '(#t #t)    1))

;; data Box := wrap Nat Nat Nat   (ternary; checks arity-3 dispatch)
(register-ctor! 'phase10b-wrap (ctor-meta 'Box '() (list 'Nat 'Nat 'Nat) '(#f #f #f) 0))

;; ====================================================================
;; Bare nullary user ctor → preduce-user-ctor value
;; ====================================================================

(test-case "phase10b/bare nullary ctor (red) becomes a stuck user-ctor value"
  (define e (expr-fvar 'phase10b-red))
  (define got (preduce e))
  (check-pred preduce-user-ctor? got)
  (check-equal? (preduce-user-ctor-short-name got) 'phase10b-red)
  (check-equal? (preduce-user-ctor-field-cids got) '()))

(test-case "phase10b/bare nullary ctor (leaf) becomes a stuck user-ctor value"
  (define e (expr-fvar 'phase10b-leaf))
  (define got (preduce e))
  (check-pred preduce-user-ctor? got)
  (check-equal? (preduce-user-ctor-short-name got) 'phase10b-leaf))

;; ====================================================================
;; Fully-applied user ctor (unary, binary, ternary)
;; ====================================================================

(test-case "phase10b/unary ctor application (rgb 7) becomes a stuck user-ctor value"
  (define e (expr-app (expr-fvar 'phase10b-rgb) (expr-nat-val 7)))
  (define got (preduce e))
  (check-pred preduce-user-ctor? got)
  (check-equal? (preduce-user-ctor-short-name got) 'phase10b-rgb)
  (check-equal? (length (preduce-user-ctor-field-cids got)) 1))

(test-case "phase10b/binary ctor application (node leaf leaf)"
  (define e (expr-app (expr-app (expr-fvar 'phase10b-node)
                                (expr-fvar 'phase10b-leaf))
                      (expr-fvar 'phase10b-leaf)))
  (define got (preduce e))
  (check-pred preduce-user-ctor? got)
  (check-equal? (preduce-user-ctor-short-name got) 'phase10b-node)
  (check-equal? (length (preduce-user-ctor-field-cids got)) 2))

(test-case "phase10b/ternary ctor application (wrap 1 2 3)"
  (define e (expr-app (expr-app (expr-app (expr-fvar 'phase10b-wrap)
                                          (expr-nat-val 1))
                                (expr-nat-val 2))
                      (expr-nat-val 3)))
  (define got (preduce e))
  (check-pred preduce-user-ctor? got)
  (check-equal? (preduce-user-ctor-short-name got) 'phase10b-wrap)
  (check-equal? (length (preduce-user-ctor-field-cids got)) 3))

;; ====================================================================
;; expr-reduce dispatch on user ctor (the headline feature)
;; ====================================================================

(test-case "phase10b/match red selects the red arm"
  (define e
    (expr-reduce (expr-fvar 'phase10b-red)
                 (list (expr-reduce-arm 'phase10b-red 0 (expr-int 100))
                       (expr-reduce-arm 'phase10b-rgb 1 (expr-int 200)))
                 #t))
  (check-equal? (preduce e) (expr-int 100)))

(test-case "phase10b/match (rgb 7) selects the rgb arm"
  (define e
    (expr-reduce (expr-app (expr-fvar 'phase10b-rgb) (expr-nat-val 7))
                 (list (expr-reduce-arm 'phase10b-red 0 (expr-int 100))
                       (expr-reduce-arm 'phase10b-rgb 1 (expr-int 200)))
                 #t))
  (check-equal? (preduce e) (expr-int 200)))

(test-case "phase10b/match extracts the field of a unary ctor"
  ;; (match (rgb 42) | red → 0 | rgb n → n)  =  42
  (define e
    (expr-reduce (expr-app (expr-fvar 'phase10b-rgb) (expr-nat-val 42))
                 (list (expr-reduce-arm 'phase10b-red 0 (expr-int 0))
                       (expr-reduce-arm 'phase10b-rgb 1 (expr-bvar 0)))
                 #t))
  (check-equal? (preduce e) (expr-nat-val 42)))

(test-case "phase10b/match extracts both fields of a binary ctor"
  ;; (match (node leaf (node leaf leaf))
  ;;   | leaf       → red
  ;;   | node l r   → r)        ;; returns the right child
  (define inner-node
    (expr-app (expr-app (expr-fvar 'phase10b-node)
                        (expr-fvar 'phase10b-leaf))
              (expr-fvar 'phase10b-leaf)))
  (define e
    (expr-reduce (expr-app (expr-app (expr-fvar 'phase10b-node)
                                     (expr-fvar 'phase10b-leaf))
                           inner-node)
                 (list (expr-reduce-arm 'phase10b-leaf 0 (expr-fvar 'phase10b-red))
                       ;; Two binders: bvar 0 = right (innermost), bvar 1 = left.
                       ;; Return the right child (bvar 0).
                       (expr-reduce-arm 'phase10b-node 2 (expr-bvar 0)))
                 #t))
  (define got (preduce e))
  (check-pred preduce-user-ctor? got)
  (check-equal? (preduce-user-ctor-short-name got) 'phase10b-node))

(test-case "phase10b/match on ternary ctor extracts middle field"
  ;; (match (wrap 10 20 30) | wrap a b c → b) = 20
  ;; Binders bound innermost-first: bvar 0 = c, bvar 1 = b, bvar 2 = a.
  (define e
    (expr-reduce (expr-app (expr-app (expr-app (expr-fvar 'phase10b-wrap)
                                               (expr-nat-val 10))
                                     (expr-nat-val 20))
                           (expr-nat-val 30))
                 (list (expr-reduce-arm 'phase10b-wrap 3 (expr-bvar 1)))
                 #t))
  (check-equal? (preduce e) (expr-nat-val 20)))

;; ====================================================================
;; Differential against nf — the production reducer's user-ctor path
;; should produce equal results.
;; ====================================================================

(test-case "phase10b/differential vs nf: nullary ctor reduces to ground"
  ;; nf returns the curried-app form; preduce returns a preduce-user-ctor
  ;; value (an internal reduction-time tag). Differential here is on the
  ;; OBSERVABLE outcome of expr-reduce dispatch, not on the wrapped
  ;; representation. We compare under expr-reduce + an int-returning arm.
  (define e
    (expr-reduce (expr-fvar 'phase10b-red)
                 (list (expr-reduce-arm 'phase10b-red 0 (expr-int 7))
                       (expr-reduce-arm 'phase10b-rgb 1 (expr-int 8)))
                 #t))
  (check-equal? (preduce e) (nf e)))

(test-case "phase10b/differential vs nf: unary ctor field extraction"
  (define e
    (expr-reduce (expr-app (expr-fvar 'phase10b-rgb) (expr-nat-val 5))
                 (list (expr-reduce-arm 'phase10b-red 0 (expr-int 0))
                       (expr-reduce-arm 'phase10b-rgb 1 (expr-bvar 0)))
                 #t))
  (check-equal? (preduce e) (nf e)))
