#lang racket/base

;;;
;;; Tests for Phase B: QTT Pipeline Integration
;;;
;;; Verifies that the QTT multiplicity checker is actually called from driver.rkt
;;; and that multiplicity violations produce structured errors.
;;;
;;; Positive tests: definitions with correct multiplicities pass.
;;; Negative tests: definitions violating `:0` or `:1` produce multiplicity-error.
;;; Regression guards: stdlib loads, mult-inference, and defn paths still work.
;;;

(require rackunit
         racket/path
         racket/list
         racket/string
         "../errors.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../macros.rkt"
         "../metavar-store.rkt")

;; Compute the lib directory path
(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

;; Helper: run prologos code in a fresh environment
(define (run s)
  (parameterize ([current-global-env (hasheq)]
                 [current-meta-store (make-hasheq)]
                 [current-level-meta-store (make-hasheq)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-constraint-store '()]
                 [current-wakeup-registry (make-hasheq)])
    (process-string s)))

;; Helper: run prologos code and return the first result
(define (run-first s)
  (first (run s)))

;; Helper: run prologos code and return the last result
(define (run-last s)
  (last (run s)))

;; Helper: run code with namespace system active (for module loading)
(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)])
    (install-module-loader!)
    (process-string s)))

;; Helper: run code with namespace and return last result
(define (run-ns-last s)
  (last (run-ns s)))

;; ========================================
;; Positive tests: correct multiplicities pass QTT
;; ========================================

(test-case "qtt-pipeline/unrestricted-identity"
  ;; Default multiplicity (mw) — any usage is fine
  (check-equal?
   (run-last "(def id <(-> Nat Nat)> (fn [x <Nat>] x))\n(eval (id zero))")
   "0N : Nat"))

(test-case "qtt-pipeline/linear-identity"
  ;; Linear (:1) used exactly once — correct
  (check-equal?
   (run-last "(def lin-id <(Pi [x :1 <Nat>] Nat)> (fn [x :1 <Nat>] x))\n(eval (lin-id zero))")
   "0N : Nat"))

(test-case "qtt-pipeline/erased-const"
  ;; Erased (:0) not used in body — correct
  (check-equal?
   (run-last "(def erased-c <(Pi [x :0 <Nat>] Nat)> (fn [x :0 <Nat>] zero))\n(eval (erased-c zero))")
   "0N : Nat"))

(test-case "qtt-pipeline/unrestricted-used-twice"
  ;; Unrestricted (mw) can be used any number of times — use natrec to reference x twice
  (check-equal?
   (run-first "(def use-twice <(-> Nat Nat)> (fn [x <Nat>] (natrec (fn [_ <Nat>] Nat) x (fn [_ <Nat>] (fn [r <Nat>] (suc r))) x)))")
   "use-twice : Nat -> Nat defined."))

(test-case "qtt-pipeline/unrestricted-used-zero"
  ;; Unrestricted (mw) — not using is fine too
  (check-equal?
   (run-first "(def drop <(-> Nat Nat)> (fn [x <Nat>] zero))")
   "drop : Nat -> Nat defined."))

(test-case "qtt-pipeline/inferred-path-simple"
  ;; Type-inferred def (no annotation) — should pass QTT
  (check-equal?
   (run-last "(def one (suc zero))\n(eval one)")
   "1N : Nat"))

(test-case "qtt-pipeline/defn-natrec-based"
  ;; defn with natrec — uses bare match on Nat
  ;; spec+defn goes through process-def-group → process-def
  (check-equal?
   (run-last "(def double <(-> Nat Nat)> (fn [n <Nat>] (natrec (fn [_ <Nat>] Nat) zero (fn [_ <Nat>] (fn [r <Nat>] (suc (suc r)))) n)))\n(eval (double (suc (suc zero))))")
   "4N : Nat"))

(test-case "qtt-pipeline/let-in-def"
  ;; Let expressions elaborate to app(lam, arg) — QTT beta-typed app handles this
  (check-equal?
   (run-last "(def r <Nat> (let a : Nat := (suc zero) a))\n(eval r)")
   "1N : Nat"))

;; ========================================
;; Negative tests: multiplicity violations produce errors
;; ========================================

(test-case "qtt-pipeline/linear-used-twice-is-error"
  ;; Linear (:1) used twice → multiplicity violation
  ;; natrec uses the target twice (base=x, step uses x again implicitly via the recursion)
  ;; But simpler: add x x uses x twice
  (define result
    (run-first "(def dup <(Pi [x :1 <Nat>] Nat)> (fn [x :1 <Nat>] (natrec (fn [_ <Nat>] Nat) x (fn [_ <Nat>] (fn [r <Nat>] (suc r))) x)))"))
  (check-true (multiplicity-error? result)
              "Expected multiplicity-error for linear variable used twice"))

(test-case "qtt-pipeline/linear-not-used-is-error"
  ;; Linear (:1) not used → multiplicity violation
  (define result
    (run-first "(def drop <(Pi [x :1 <Nat>] Nat)> (fn [x :1 <Nat>] zero))"))
  (check-true (multiplicity-error? result)
              "Expected multiplicity-error for linear variable not used"))

(test-case "qtt-pipeline/erased-used-is-error"
  ;; Erased (:0) used at runtime → multiplicity violation
  (define result
    (run-first "(def use-erased <(Pi [x :0 <Nat>] Nat)> (fn [x :0 <Nat>] x))"))
  (check-true (multiplicity-error? result)
              "Expected multiplicity-error for erased variable used at runtime"))

(test-case "qtt-pipeline/erased-used-in-suc-is-error"
  ;; Erased (:0) used in suc — multiplicity violation
  (define result
    (run-first "(def suc-erased <(Pi [x :0 <Nat>] Nat)> (fn [x :0 <Nat>] (suc x)))"))
  (check-true (multiplicity-error? result)
              "Expected multiplicity-error for erased variable used in suc"))

(test-case "qtt-pipeline/error-message-contains-multiplicity"
  ;; The error message should mention "Multiplicity violation"
  (define result
    (run-first "(def use-erased <(Pi [x :0 <Nat>] Nat)> (fn [x :0 <Nat>] x))"))
  (check-true (multiplicity-error? result))
  (check-true (string-contains? (prologos-error-message result) "Multiplicity")
              "Error message should mention 'Multiplicity'"))

(test-case "qtt-pipeline/linear-violation-removes-def"
  ;; After a QTT failure, the definition should be removed from global env
  ;; (not left as a half-registered entry)
  (define results
    (run "(def bad <(Pi [x :1 <Nat>] Nat)> (fn [x :1 <Nat>] zero))\n(eval bad)"))
  (check-true (multiplicity-error? (first results))
              "First result should be multiplicity-error")
  ;; Second result should be an unbound variable error (def was removed)
  (check-true (prologos-error? (second results))
              "Second result should be an error (bad is not defined)"))

;; ========================================
;; Regression guards: existing functionality still works
;; ========================================

(test-case "qtt-pipeline/stdlib-nat-loads"
  ;; The nat stdlib loads and add works
  (check-equal?
   (run-ns-last "(ns qtt-r1)\n(require [prologos.data.nat :refer [add]])\n(eval (add (suc (suc zero)) (suc (suc (suc zero)))))")
   "5N : Nat"))

(test-case "qtt-pipeline/stdlib-bool-loads"
  ;; The bool stdlib loads
  (check-equal?
   (run-ns-last "(ns qtt-r2)\n(require [prologos.data.bool :refer [not]])\n(eval (not true))")
   "false : Bool"))

(test-case "qtt-pipeline/mult-inference-still-works"
  ;; Omitted multiplicities still default to mw and work
  (check-equal?
   (run-last "(def id <(-> Nat Nat)> (fn [x <Nat>] x))\n(eval (id (suc zero)))")
   "1N : Nat"))

(test-case "qtt-pipeline/posit8-basic"
  ;; Posit8 operations pass QTT
  (check-equal?
   (run-first "(def one <Posit8> (p8-from-nat (suc zero)))")
   "one : Posit8 defined."))

(test-case "qtt-pipeline/eval-command-not-qtt-checked"
  ;; eval commands don't go through QTT — they're ephemeral
  ;; This verifies that eval path is unaffected
  (check-equal?
   (run-first "(eval (suc (suc zero)))")
   "2N : Nat"))
