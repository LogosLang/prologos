#lang racket/base

;;;
;;; Tests for Underscore Placeholder Partial Application
;;;
;;; Verifies that _ in function application argument positions desugars
;;; to anonymous lambdas: (add 1N _) → (fn [$_0] (add 1N $_0))
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
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
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
  ;; (myadd x y) = natrec x y (fn [_ r] (suc r))
  (check-equal?
   (run-last
    (string-join
     (list "(def myadd <(-> Nat (-> Nat Nat))>"
           "  (fn [x <Nat>] (fn [y <Nat>] (natrec (fn [_ <Nat>] Nat) x (fn [_ <Nat>] (fn [r <Nat>] (suc r))) y))))"
           "(eval ((the (-> Nat Nat) (myadd (suc zero) _)) (suc (suc zero))))")
     "\n"))
   "3N : Nat"))

(test-case "placeholder/in-check-context"
  ;; Placeholder in a checking context — type drives inference
  (check-equal?
   (run-last
    (string-join
     (list "(def myadd <(-> Nat (-> Nat Nat))>"
           "  (fn [x <Nat>] (fn [y <Nat>] (natrec (fn [_ <Nat>] Nat) x (fn [_ <Nat>] (fn [r <Nat>] (suc r))) y))))"
           "(check (myadd (suc zero) _) <(-> Nat Nat)>)")
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
           "(eval ((the (-> Nat (-> Nat Nat)) (choose _ zero _)) (suc zero) (suc (suc zero))))")
     "\n"))
   "0N : Nat"))

(test-case "placeholder/no-holes-unchanged"
  ;; No holes — no desugaring, works as normal application
  (check-equal?
   (run-first "(eval (suc (suc zero)))")
   "2N : Nat"))

(test-case "placeholder/type-hole-not-affected"
  ;; _ in type position is a type hole, not a placeholder
  (check-equal?
   (run-first "(check (fn [x <_>] x) <(-> Nat Nat)>)")
   "OK"))

(test-case "placeholder/match-wildcard-not-affected"
  ;; _ in match pattern is a binding wildcard, not a placeholder
  (check-equal?
   (run-first
    "(eval (the Bool (match (suc zero) (zero -> false) (suc _ -> true))))")
   "true : Bool"))

(test-case "placeholder/nested-in-arg"
  ;; Placeholder in a nested application argument
  ;; The inner (myadd _ (suc zero)) desugars to (fn [$_0] (myadd $_0 (suc zero)))
  ;; The outer application applies it
  (check-equal?
   (run-last
    (string-join
     (list "(def myadd <(-> Nat (-> Nat Nat))>"
           "  (fn [x <Nat>] (fn [y <Nat>] (natrec (fn [_ <Nat>] Nat) x (fn [_ <Nat>] (fn [r <Nat>] (suc r))) y))))"
           "(def apply-fn <(-> (-> Nat Nat) (-> Nat Nat))>"
           "  (fn [f <(-> Nat Nat)>] (fn [x <Nat>] (f x))))"
           "(eval (apply-fn (the (-> Nat Nat) (myadd _ (suc zero))) (suc (suc zero))))")
     "\n"))
   "3N : Nat"))

;; ========================================
;; Unit tests: numbered placeholder (_N) desugaring
;; ========================================

(test-case "numbered-placeholder/unit: single _1 produces surf-lam"
  (define loc srcloc-unknown)
  (define input (surf-app (surf-var 'f loc)
                          (list (surf-zero loc) (surf-numbered-hole 1 loc))
                          loc))
  (define result (expand-expression input))
  ;; Result should be a surf-lam wrapping a surf-app
  (check-true (surf-lam? result))
  (check-equal? (binder-info-name (surf-lam-binder result)) '$_1)
  ;; Body should be an application
  (check-true (surf-app? (surf-lam-body result))))

(test-case "numbered-placeholder/unit: _2 _1 produces ordered lambdas (_1 outermost)"
  (define loc srcloc-unknown)
  (define input (surf-app (surf-var 'f loc)
                          (list (surf-numbered-hole 2 loc)
                                (surf-zero loc)
                                (surf-numbered-hole 1 loc))
                          loc))
  (define result (expand-expression input))
  ;; Outermost: surf-lam with $_1 (smallest index = outermost)
  (check-true (surf-lam? result))
  (check-equal? (binder-info-name (surf-lam-binder result)) '$_1)
  ;; Inner: surf-lam with $_2
  (define inner (surf-lam-body result))
  (check-true (surf-lam? inner))
  (check-equal? (binder-info-name (surf-lam-binder inner)) '$_2)
  ;; Innermost: surf-app with no numbered holes
  (define body (surf-lam-body inner))
  (check-true (surf-app? body))
  (check-false (ormap surf-numbered-hole? (surf-app-args body))))

(test-case "numbered-placeholder/unit: non-contiguous indices (_1 _3)"
  (define loc srcloc-unknown)
  (define input (surf-app (surf-var 'f loc)
                          (list (surf-numbered-hole 1 loc)
                                (surf-numbered-hole 3 loc))
                          loc))
  (define result (expand-expression input))
  ;; Outermost: $_1
  (check-true (surf-lam? result))
  (check-equal? (binder-info-name (surf-lam-binder result)) '$_1)
  ;; Inner: $_3
  (define inner (surf-lam-body result))
  (check-true (surf-lam? inner))
  (check-equal? (binder-info-name (surf-lam-binder inner)) '$_3))

(test-case "numbered-placeholder/unit: mixed plain and numbered errors"
  (define loc srcloc-unknown)
  (define input (surf-app (surf-var 'f loc)
                          (list (surf-hole loc) (surf-numbered-hole 1 loc))
                          loc))
  (check-exn exn:fail?
    (lambda () (expand-expression input))))

(test-case "numbered-placeholder/unit: duplicate index errors"
  (define loc srcloc-unknown)
  (define input (surf-app (surf-var 'f loc)
                          (list (surf-numbered-hole 1 loc) (surf-numbered-hole 1 loc))
                          loc))
  (check-exn exn:fail?
    (lambda () (expand-expression input))))

;; ========================================
;; Integration tests: numbered placeholders end-to-end
;; ========================================

(test-case "numbered-placeholder/single-_1-applied"
  ;; (myadd (suc zero) _1) applied to (suc (suc zero)) → 3
  (check-equal?
   (run-last
    (string-join
     (list "(def myadd <(-> Nat (-> Nat Nat))>"
           "  (fn [x <Nat>] (fn [y <Nat>] (natrec (fn [_ <Nat>] Nat) x (fn [_ <Nat>] (fn [r <Nat>] (suc r))) y))))"
           "(eval ((the (-> Nat Nat) (myadd (suc zero) _1)) (suc (suc zero))))")
     "\n"))
   "3N : Nat"))

(test-case "numbered-placeholder/reorder-args"
  ;; Use _2 and _1 to swap argument order
  ;; choose : Nat → Nat → Nat → Nat, returns second arg
  ;; (choose _2 _1 zero) called with (suc zero) (suc (suc zero))
  ;; = (choose (suc (suc zero)) (suc zero) zero) = suc zero = 1
  (check-equal?
   (run-last
    (string-join
     (list "(def choose <(-> Nat (-> Nat (-> Nat Nat)))>"
           "  (fn [a <Nat>] (fn [b <Nat>] (fn [c <Nat>] b))))"
           "(eval ((the (-> Nat (-> Nat Nat)) (choose _2 _1 zero)) (suc zero) (suc (suc zero))))")
     "\n"))
   "1N : Nat"))

(test-case "numbered-placeholder/type-check-reordered"
  ;; Type-checking: (choose _2 _1 zero) should have type (-> Nat (-> Nat Nat))
  (check-equal?
   (run-last
    (string-join
     (list "(def choose <(-> Nat (-> Nat (-> Nat Nat)))>"
           "  (fn [a <Nat>] (fn [b <Nat>] (fn [c <Nat>] b))))"
           "(check (choose _2 _1 zero) <(-> Nat (-> Nat Nat))>)")
     "\n"))
   "OK"))

(test-case "numbered-placeholder/plain-holes-still-work"
  ;; Existing plain _ behavior still works after adding numbered support
  (check-equal?
   (run-last
    (string-join
     (list "(def myadd <(-> Nat (-> Nat Nat))>"
           "  (fn [x <Nat>] (fn [y <Nat>] (natrec (fn [_ <Nat>] Nat) x (fn [_ <Nat>] (fn [r <Nat>] (suc r))) y))))"
           "(eval ((the (-> Nat Nat) (myadd _ (suc zero))) (suc (suc zero))))")
     "\n"))
   "3N : Nat"))

(test-case "numbered-placeholder/same-order-as-plain"
  ;; _1 _2 in order should behave same as _ _ for argument passing
  ;; (choose _1 _2 zero) called with (suc zero) (suc (suc zero))
  ;; = choose (suc zero) (suc (suc zero)) zero = (suc (suc zero)) = 2
  (check-equal?
   (run-last
    (string-join
     (list "(def choose <(-> Nat (-> Nat (-> Nat Nat)))>"
           "  (fn [a <Nat>] (fn [b <Nat>] (fn [c <Nat>] b))))"
           "(eval ((the (-> Nat (-> Nat Nat)) (choose _1 _2 zero)) (suc zero) (suc (suc zero))))")
     "\n"))
   "2N : Nat"))
