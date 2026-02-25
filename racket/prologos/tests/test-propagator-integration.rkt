#lang racket/base

;;;
;;; Tests for PropNetwork surface syntax integration
;;; Phase 3d: parser → elaborator → type-check → reduce → pretty-print
;;;

(require racket/string
         racket/list
         rackunit
         "test-support.rkt"
         "../syntax.rkt"
         "../prelude.rkt"
         "../substitution.rkt"
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../pretty-print.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../errors.rkt")

;; Helper to run with clean global env (sexp mode)
(define (run s)
  (parameterize ([current-global-env (hasheq)])
    (process-string s)))

;; ========================================
;; Type checking: type constructors (sexp mode)
;; ========================================

(test-case "surface: PropNetwork type check"
  (check-equal? (run "(check PropNetwork : (Type 0))")
                '("OK")))

(test-case "surface: CellId type check"
  (check-equal? (run "(check CellId : (Type 0))")
                '("OK")))

(test-case "surface: PropId type check"
  (check-equal? (run "(check PropId : (Type 0))")
                '("OK")))

;; ========================================
;; Type inference: operations (sexp mode)
;; ========================================

(test-case "surface: net-new type infer"
  (check-equal? (run "(infer (net-new 1000))")
                '("PropNetwork")))

(test-case "surface: net-new check"
  (check-equal? (run "(check (net-new 1000) : PropNetwork)")
                '("OK")))

(test-case "surface: net-run type infer"
  (check-equal? (run "(infer (net-run (net-new 1000)))")
                '("PropNetwork")))

(test-case "surface: net-snapshot check"
  (check-equal? (run "(check (net-snapshot (net-new 1000)) : PropNetwork)")
                '("OK")))

(test-case "surface: net-contradict? type infer"
  (check-equal? (run "(infer (net-contradict? (net-new 1000)))")
                '("Bool")))

(test-case "surface: net-new-cell type infer"
  (let ([result (run "(infer (net-new-cell (net-new 1000) zero (fn (x : Nat) (fn (y : Nat) y))))")])
    (check-equal? result '("[Sigma PropNetwork CellId]"))))

;; ========================================
;; Evaluation: basic operations (sexp mode)
;; ========================================

(test-case "surface: eval net-new produces PropNetwork"
  (let ([result (run "(eval (net-new 1000))")])
    (check-true (and (list? result) (= 1 (length result))))
    (check-true (string-contains? (car result) "PropNetwork"))))

(test-case "surface: eval net-contradict? on fresh network"
  (check-equal? (run "(eval (net-contradict? (net-new 1000)))")
                '("false : Bool")))

(test-case "surface: eval net-run on fresh network"
  (let ([result (run "(eval (net-run (net-new 1000)))")])
    (check-true (and (list? result) (= 1 (length result))))
    (check-true (string-contains? (car result) "PropNetwork"))))

;; ========================================
;; Prelude-enabled: full cell operations (sexp mode)
;; ========================================

(test-case "surface+prelude: def net-new + eval"
  (check-equal?
   (run-ns-last
    "(ns prop-t1)\n(def mynet : PropNetwork (net-new 1000))\n(eval (net-contradict? mynet))")
   "false : Bool"))

(test-case "surface+prelude: persistence — old network retains zero"
  (check-equal?
   (run-ns-last
    (string-append
     "(ns prop-t2)\n"
     "(def merge : (-> Nat (-> Nat Nat)) (fn (x : Nat) (fn (y : Nat) y)))\n"
     "(def pair1 : (Sigma (_ : PropNetwork) CellId) (net-new-cell (net-new 1000) zero merge))\n"
     "(def mynet : PropNetwork (first pair1))\n"
     "(def mycid : CellId (second pair1))\n"
     "(def net2 : PropNetwork (net-cell-write mynet mycid (suc zero)))\n"
     "(eval (the Nat (net-cell-read mynet mycid)))"))
   "0N : Nat"))

(test-case "surface+prelude: persistence — new network has suc(zero)"
  (check-equal?
   (run-ns-last
    (string-append
     "(ns prop-t3)\n"
     "(def merge : (-> Nat (-> Nat Nat)) (fn (x : Nat) (fn (y : Nat) y)))\n"
     "(def pair1 : (Sigma (_ : PropNetwork) CellId) (net-new-cell (net-new 1000) zero merge))\n"
     "(def mynet : PropNetwork (first pair1))\n"
     "(def mycid : CellId (second pair1))\n"
     "(def net2 : PropNetwork (net-cell-write mynet mycid (suc zero)))\n"
     "(eval (the Nat (net-cell-read net2 mycid)))"))
   "1N : Nat"))

(test-case "surface+prelude: net-new-cell read initial value"
  (check-equal?
   (run-ns-last
    (string-append
     "(ns prop-t4)\n"
     "(def merge : (-> Nat (-> Nat Nat)) (fn (x : Nat) (fn (y : Nat) y)))\n"
     "(def pair1 : (Sigma (_ : PropNetwork) CellId) (net-new-cell (net-new 1000) zero merge))\n"
     "(def mynet : PropNetwork (first pair1))\n"
     "(def mycid : CellId (second pair1))\n"
     "(eval (the Nat (net-cell-read mynet mycid)))"))
   "0N : Nat"))
