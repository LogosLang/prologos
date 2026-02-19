#lang racket/base

;;;
;;; Tests for Sprint 7: Multiplicity Inference for QTT
;;;
;;; Tests the mult-meta struct, mult-meta store, unify-mult,
;;; zonk-mult, and integration with parser/elaborator for omitted multiplicities.
;;;

(require rackunit
         racket/path
         racket/list
         "../prelude.rkt"
         "../syntax.rkt"
         "../metavar-store.rkt"
         "../unify.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../macros.rkt"
         "../zonk.rkt")

;; ========================================
;; Unit tests: mult-meta infrastructure
;; ========================================

(test-case "mult-meta/fresh-creates-unsolved"
  (parameterize ([current-mult-meta-store (make-hasheq)])
    (define mm (fresh-mult-meta "test"))
    (check-true (mult-meta? mm))
    (check-false (mult-meta-solved? (mult-meta-id mm)))))

(test-case "mult-meta/solve-and-retrieve"
  (parameterize ([current-mult-meta-store (make-hasheq)])
    (define mm (fresh-mult-meta "test"))
    (define id (mult-meta-id mm))
    (solve-mult-meta! id 'mw)
    (check-true (mult-meta-solved? id))
    (check-equal? (mult-meta-solution id) 'mw)))

(test-case "mult-meta/solve-with-m1"
  (parameterize ([current-mult-meta-store (make-hasheq)])
    (define mm (fresh-mult-meta "test"))
    (define id (mult-meta-id mm))
    (solve-mult-meta! id 'm1)
    (check-equal? (mult-meta-solution id) 'm1)))

(test-case "mult-meta/solve-with-m0"
  (parameterize ([current-mult-meta-store (make-hasheq)])
    (define mm (fresh-mult-meta "test"))
    (define id (mult-meta-id mm))
    (solve-mult-meta! id 'm0)
    (check-equal? (mult-meta-solution id) 'm0)))

(test-case "mult?/accepts-mult-meta"
  (parameterize ([current-mult-meta-store (make-hasheq)])
    (define mm (fresh-mult-meta "test"))
    (check-not-false (mult? mm))))

(test-case "mult?/still-accepts-concrete"
  (check-not-false (mult? 'm0))
  (check-not-false (mult? 'm1))
  (check-not-false (mult? 'mw)))

;; ========================================
;; Unit tests: zonk-mult
;; ========================================

(test-case "zonk-mult/follows-solved"
  (parameterize ([current-mult-meta-store (make-hasheq)])
    (define mm (fresh-mult-meta "test"))
    (solve-mult-meta! (mult-meta-id mm) 'm1)
    (check-equal? (zonk-mult mm) 'm1)))

(test-case "zonk-mult/preserves-unsolved"
  (parameterize ([current-mult-meta-store (make-hasheq)])
    (define mm (fresh-mult-meta "test"))
    ;; zonk-mult preserves unsolved mult-metas (for intermediate use)
    (check-true (mult-meta? (zonk-mult mm)))))

(test-case "zonk-mult-default/defaults-unsolved-to-mw"
  (parameterize ([current-mult-meta-store (make-hasheq)])
    (define mm (fresh-mult-meta "test"))
    ;; zonk-mult-default defaults unsolved to 'mw (for final output)
    (check-equal? (zonk-mult-default mm) 'mw)))

(test-case "zonk-mult/transitive"
  (parameterize ([current-mult-meta-store (make-hasheq)])
    (define mm1 (fresh-mult-meta "a"))
    (define mm2 (fresh-mult-meta "b"))
    (solve-mult-meta! (mult-meta-id mm1) mm2)
    (solve-mult-meta! (mult-meta-id mm2) 'm1)
    (check-equal? (zonk-mult mm1) 'm1)))

(test-case "zonk-mult/concrete-passthrough"
  (check-equal? (zonk-mult 'mw) 'mw)
  (check-equal? (zonk-mult 'm1) 'm1)
  (check-equal? (zonk-mult 'm0) 'm0))

;; ========================================
;; Unit tests: unify-mult
;; ========================================

(test-case "unify-mult/meta-vs-concrete"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-level-meta-store (make-hasheq)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-constraint-store '()]
                 [current-wakeup-registry (make-hasheq)]
                 [current-global-env (hasheq)])
    (define mm (fresh-mult-meta "test"))
    ;; Unify Pi(?m, Nat, Nat) vs Pi(mw, Nat, Nat)
    (define t1 (expr-Pi mm (expr-Nat) (expr-Nat)))
    (define t2 (expr-Pi 'mw (expr-Nat) (expr-Nat)))
    (check-equal? (unify ctx-empty t1 t2) #t)
    (check-true (mult-meta-solved? (mult-meta-id mm)))
    (check-equal? (mult-meta-solution (mult-meta-id mm)) 'mw)))

(test-case "unify-mult/two-metas"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-level-meta-store (make-hasheq)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-constraint-store '()]
                 [current-wakeup-registry (make-hasheq)]
                 [current-global-env (hasheq)])
    (define mm1 (fresh-mult-meta "a"))
    (define mm2 (fresh-mult-meta "b"))
    (define t1 (expr-Pi mm1 (expr-Nat) (expr-Nat)))
    (define t2 (expr-Pi mm2 (expr-Nat) (expr-Nat)))
    (check-equal? (unify ctx-empty t1 t2) #t)
    ;; One should be solved to the other
    (check-true (mult-meta-solved? (mult-meta-id mm1)))))

(test-case "unify-mult/ground-match"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-level-meta-store (make-hasheq)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-constraint-store '()]
                 [current-wakeup-registry (make-hasheq)]
                 [current-global-env (hasheq)])
    (define t1 (expr-Pi 'm1 (expr-Nat) (expr-Nat)))
    (define t2 (expr-Pi 'm1 (expr-Nat) (expr-Nat)))
    (check-equal? (unify ctx-empty t1 t2) #t)))

(test-case "unify-mult/ground-mismatch-rejects"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-level-meta-store (make-hasheq)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-constraint-store '()]
                 [current-wakeup-registry (make-hasheq)]
                 [current-global-env (hasheq)])
    (define t1 (expr-Pi 'm0 (expr-Nat) (expr-Nat)))
    (define t2 (expr-Pi 'm1 (expr-Nat) (expr-Nat)))
    (check-equal? (unify ctx-empty t1 t2) #f)))

;; ========================================
;; Integration tests: multiplicity inference in user code
;; ========================================

;; Compute the lib directory path
(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

;; Helper: run prologos code with namespace system active
(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)])
    (install-module-loader!)
    (process-string s)))

;; Helper: run code and return the last result line
(define (run-last s)
  (last (run-ns s)))

(test-case "mult-inference/arrow-fn-omitted-mult"
  ;; (fn [x] x) against (-> Nat Nat): arrow has 'mw, lambda mult-meta solved to 'mw
  (check-equal?
   (run-last "(ns mi1)\n(def id <(-> Nat Nat)> (fn [x <Nat>] x))\n(eval (id zero))")
   "0N : Nat"))

(test-case "mult-inference/linear-pi-fn-omitted-mult"
  ;; Lambda with omitted mult checked against Pi :1 — mult-meta solved to m1
  (check-equal?
   (run-last "(ns mi2)\n(def linear-id <(Pi [x :1 <Nat>] Nat)> (fn [x <Nat>] x))\n(eval (linear-id zero))")
   "0N : Nat"))

(test-case "mult-inference/explicit-m1-still-works"
  ;; Explicit :1 on lambda should still work
  (check-equal?
   (run-last "(ns mi3)\n(def linear-id <(Pi [x :1 <Nat>] Nat)> (fn [x :1 <Nat>] x))\n(eval (linear-id zero))")
   "0N : Nat"))

(test-case "mult-inference/explicit-m0-still-works"
  ;; Explicit :0 on Pi/lambda should still work
  (check-equal?
   (run-last "(ns mi4)\n(def const-zero <(Pi [x :0 <Nat>] Nat)> (fn [x :0 <Nat>] zero))\n(eval (const-zero (suc zero)))")
   "0N : Nat"))

(test-case "mult-inference/stdlib-id-still-works"
  ;; id from stdlib uses implicit params — should still work
  (check-equal?
   (run-last "(ns mi5)\n(require [prologos.core :refer [id]])\n(eval (id zero))")
   "0N : Nat"))

(test-case "mult-inference/stdlib-add-still-works"
  ;; add from stdlib — should still work with level + mult inference
  (check-equal?
   (run-last "(ns mi6)\n(require [prologos.data.nat :refer [add]])\n(eval (add 2N 3N))")
   "5N : Nat"))

(test-case "mult-inference/defn-type-display"
  ;; defn: omitted mult in defn params should display with (-> ...) or (Pi ...)
  (check-equal?
   (run-last "(ns mi7)\n(defn myid [x <Nat>] <Nat> x)")
   "myid : Nat -> Nat defined."))

(test-case "mult-inference/bare-lambda-checked-against-arrow"
  ;; A lambda checked against an arrow: mult-meta solved from the arrow's 'mw
  (check-equal?
   (run-last "(ns mi8)\n(eval (the (-> Nat Nat) (fn [x <Nat>] x)))")
   "[fn [x <Nat>] x] : Nat -> Nat"))
