#lang racket/base

;;;
;;; Tests for Underscore Placeholder Partial Application
;;;
;;; Verifies that _ in function application argument positions desugars
;;; to anonymous lambdas: (add 1 _) → (fn [$_0] (add 1 $_0))
;;;

(require rackunit
         racket/string
         racket/list
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../macros.rkt"
         "../multi-dispatch.rkt")

;; ========================================
;; Helpers
;; ========================================

(define (run s)
  (parameterize ([current-global-env (hasheq)]
                 [current-multi-defn-registry (hasheq)])
    (process-string s)))

(define (run-first s) (car (run s)))
(define (run-last s) (last (run s)))

;; ========================================
;; Unit tests: expand-expression desugaring
;; ========================================

(test-case "placeholder/unit: single hole produces surf-lam"
  (define loc srcloc-unknown)
  (define input (surf-app (surf-var 'f loc)
                          (list (surf-zero loc) (surf-hole loc))
                          loc))
  (define result (expand-expression input))
  ;; Result should be a surf-lam wrapping a surf-app
  (check-true (surf-lam? result))
  (check-equal? (binder-info-name (surf-lam-binder result)) '$_0)
  ;; Body should be an application
  (check-true (surf-app? (surf-lam-body result))))

(test-case "placeholder/unit: multiple holes produce nested surf-lam"
  (define loc srcloc-unknown)
  (define input (surf-app (surf-var 'f loc)
                          (list (surf-hole loc)
                                (surf-zero loc)
                                (surf-hole loc))
                          loc))
  (define result (expand-expression input))
  ;; Outermost: surf-lam with $_0
  (check-true (surf-lam? result))
  (check-equal? (binder-info-name (surf-lam-binder result)) '$_0)
  ;; Inner: surf-lam with $_1
  (define inner (surf-lam-body result))
  (check-true (surf-lam? inner))
  (check-equal? (binder-info-name (surf-lam-binder inner)) '$_1)
  ;; Innermost: surf-app with no holes
  (define body (surf-lam-body inner))
  (check-true (surf-app? body))
  (check-false (ormap surf-hole? (surf-app-args body))))

(test-case "placeholder/unit: no holes passes through"
  (define loc srcloc-unknown)
  (define input (surf-app (surf-var 'f loc)
                          (list (surf-zero loc) (surf-zero loc))
                          loc))
  (define result (expand-expression input))
  ;; Result should still be a surf-app (not wrapped in surf-lam)
  (check-true (surf-app? result)))

;; ========================================
;; Integration tests: end-to-end
;; ========================================

(test-case "placeholder/single-arg-applied"
  ;; Define a 2-arg function, use _ for partial application, then apply
  ;; (myadd x y) = natrec x y (fn [_ r] (inc r))
  (check-equal?
   (run-last
    (string-join
     (list "(def myadd <(-> Nat (-> Nat Nat))>"
           "  (fn [x <Nat>] (fn [y <Nat>] (natrec (fn [_ <Nat>] Nat) x (fn [_ <Nat>] (fn [r <Nat>] (inc r))) y))))"
           "(eval ((the (-> Nat Nat) (myadd (inc zero) _)) (inc (inc zero))))")
     "\n"))
   "3 : Nat"))

(test-case "placeholder/in-check-context"
  ;; Placeholder in a checking context — type drives inference
  (check-equal?
   (run-last
    (string-join
     (list "(def myadd <(-> Nat (-> Nat Nat))>"
           "  (fn [x <Nat>] (fn [y <Nat>] (natrec (fn [_ <Nat>] Nat) x (fn [_ <Nat>] (fn [r <Nat>] (inc r))) y))))"
           "(check (myadd (inc zero) _) <(-> Nat Nat)>)")
     "\n"))
   "OK"))

(test-case "placeholder/multiple-holes"
  ;; Two placeholders create a 2-arg lambda
  ;; (f _ zero _) where f takes 3 args
  (check-equal?
   (run-last
    (string-join
     (list "(def choose <(-> Nat (-> Nat (-> Nat Nat)))>"
           "  (fn [a <Nat>] (fn [b <Nat>] (fn [c <Nat>] b))))"
           "(eval ((the (-> Nat (-> Nat Nat)) (choose _ zero _)) (inc zero) (inc (inc zero))))")
     "\n"))
   "zero : Nat"))

(test-case "placeholder/no-holes-unchanged"
  ;; No holes — no desugaring, works as normal application
  (check-equal?
   (run-first "(eval (inc (inc zero)))")
   "2 : Nat"))

(test-case "placeholder/type-hole-not-affected"
  ;; _ in type position is a type hole, not a placeholder
  (check-equal?
   (run-first "(check (fn [x <_>] x) <(-> Nat Nat)>)")
   "OK"))

(test-case "placeholder/match-wildcard-not-affected"
  ;; _ in match pattern is a binding wildcard, not a placeholder
  (check-equal?
   (run-first
    "(eval (the Bool (match (inc zero) (zero -> false) (inc _ -> true))))")
   "true : Bool"))

(test-case "placeholder/nested-in-arg"
  ;; Placeholder in a nested application argument
  ;; The inner (myadd _ (inc zero)) desugars to (fn [$_0] (myadd $_0 (inc zero)))
  ;; The outer application applies it
  (check-equal?
   (run-last
    (string-join
     (list "(def myadd <(-> Nat (-> Nat Nat))>"
           "  (fn [x <Nat>] (fn [y <Nat>] (natrec (fn [_ <Nat>] Nat) x (fn [_ <Nat>] (fn [r <Nat>] (inc r))) y))))"
           "(def apply-fn <(-> (-> Nat Nat) (-> Nat Nat))>"
           "  (fn [f <(-> Nat Nat)>] (fn [x <Nat>] (f x))))"
           "(eval (apply-fn (the (-> Nat Nat) (myadd _ (inc zero))) (inc (inc zero))))")
     "\n"))
   "3 : Nat"))
