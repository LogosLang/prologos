#lang racket/base

;;;
;;; Tests for PVec (persistent vector, RRB-Tree-backed) integration
;;;

(require racket/string
         racket/list
         racket/path
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
         "../namespace.rkt"
         "../macros.rkt"
         "../rrb.rkt"
         "../reader.rkt"
         "../sexp-readtable.rkt")

;; Compute the lib directory path for namespace loading
;; Helper to run with clean global env
(define (run s)
  (parameterize ([current-global-env (hasheq)])
    (process-string s)))

;; Helper to run with namespace system (prelude) active
(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry])
    (install-module-loader!)
    (process-string s)))

;; ========================================
;; Core AST: PVec type formation
;; ========================================

(test-case "PVec type formation"
  (check-equal? (tc:infer ctx-empty (expr-PVec (expr-Nat)))
                (expr-Type (lzero))))

(test-case "PVec type level"
  (check-equal? (tc:infer-level ctx-empty (expr-PVec (expr-Nat)))
                (tc:just-level (lzero))))

;; ========================================
;; Core AST: pvec-empty typing
;; ========================================

(test-case "pvec-empty typing"
  (check-equal? (tc:infer ctx-empty (expr-pvec-empty (expr-Nat)))
                (expr-PVec (expr-Nat))))

;; ========================================
;; Core AST: pvec-push typing
;; ========================================

(test-case "pvec-push typing"
  ;; push(pvec-empty(Nat), zero) : PVec Nat
  (check-equal? (tc:infer ctx-empty
                  (expr-pvec-push (expr-pvec-empty (expr-Nat)) (expr-zero)))
                (expr-PVec (expr-Nat))))

;; ========================================
;; Core AST: pvec-nth typing
;; ========================================

(test-case "pvec-nth returns element type"
  ;; nth returns Nat (element type), NOT PVec Nat
  (check-equal? (tc:infer ctx-empty
                  (expr-pvec-nth
                    (expr-pvec-push (expr-pvec-empty (expr-Nat)) (expr-zero))
                    (expr-zero)))
                (expr-Nat)))

;; ========================================
;; Core AST: pvec-update typing
;; ========================================

(test-case "pvec-update typing"
  (check-equal? (tc:infer ctx-empty
                  (expr-pvec-update
                    (expr-pvec-push (expr-pvec-empty (expr-Nat)) (expr-zero))
                    (expr-zero)
                    (expr-suc (expr-zero))))
                (expr-PVec (expr-Nat))))

;; ========================================
;; Core AST: pvec-length typing
;; ========================================

(test-case "pvec-length typing"
  (check-equal? (tc:infer ctx-empty
                  (expr-pvec-length
                    (expr-pvec-push (expr-pvec-empty (expr-Nat)) (expr-zero))))
                (expr-Nat)))

;; ========================================
;; Core AST: pvec-pop typing
;; ========================================

(test-case "pvec-pop typing"
  (check-equal? (tc:infer ctx-empty
                  (expr-pvec-pop
                    (expr-pvec-push (expr-pvec-empty (expr-Nat)) (expr-zero))))
                (expr-PVec (expr-Nat))))

;; ========================================
;; Core AST: pvec-concat typing
;; ========================================

(test-case "pvec-concat typing"
  (check-equal? (tc:infer ctx-empty
                  (expr-pvec-concat
                    (expr-pvec-push (expr-pvec-empty (expr-Nat)) (expr-zero))
                    (expr-pvec-empty (expr-Nat))))
                (expr-PVec (expr-Nat))))

;; ========================================
;; Core AST: pvec-slice typing
;; ========================================

(test-case "pvec-slice typing"
  (check-equal? (tc:infer ctx-empty
                  (expr-pvec-slice
                    (expr-pvec-push (expr-pvec-empty (expr-Nat)) (expr-zero))
                    (expr-zero)
                    (expr-suc (expr-zero))))
                (expr-PVec (expr-Nat))))

;; ========================================
;; Core AST: Reduction (iota rules)
;; ========================================

(test-case "pvec-empty reduces to rrb"
  (let ([result (whnf (expr-pvec-empty (expr-Nat)))])
    (check-true (expr-rrb? result))))

(test-case "pvec-push + pvec-nth round-trip"
  ;; push zero, then nth at index 0 → zero
  (let ([result (whnf (expr-pvec-nth
                        (expr-pvec-push (expr-pvec-empty (expr-Nat)) (expr-zero))
                        (expr-zero)))])
    (check-equal? result (expr-zero))))

(test-case "pvec-length reduction"
  (let ([result (whnf (expr-pvec-length
                        (expr-pvec-push
                          (expr-pvec-push (expr-pvec-empty (expr-Nat)) (expr-zero))
                          (expr-suc (expr-zero)))))])
    (check-equal? result (expr-nat-val 2))))

(test-case "pvec-update reduction"
  ;; push zero, update index 0 to 1, nth at 0 → 1
  (let ([result (whnf (expr-pvec-nth
                        (expr-pvec-update
                          (expr-pvec-push (expr-pvec-empty (expr-Nat)) (expr-zero))
                          (expr-zero)
                          (expr-suc (expr-zero)))
                        (expr-zero)))])
    (check-equal? result (expr-nat-val 1))))

(test-case "pvec-pop reduction"
  ;; push two elements, pop, length = 1
  (let ([result (whnf (expr-pvec-length
                        (expr-pvec-pop
                          (expr-pvec-push
                            (expr-pvec-push (expr-pvec-empty (expr-Nat)) (expr-zero))
                            (expr-suc (expr-zero))))))])
    (check-equal? result (expr-nat-val 1))))

;; ========================================
;; Core AST: Substitution
;; ========================================

(test-case "substitution: shift through PVec type"
  (let ([e (expr-PVec (expr-bvar 0))])
    (check-equal? (shift 1 0 e) (expr-PVec (expr-bvar 1)))))

(test-case "substitution: shift through pvec operations"
  (let ([e (expr-pvec-push (expr-bvar 0) (expr-bvar 1))])
    (check-equal? (shift 1 0 e) (expr-pvec-push (expr-bvar 1) (expr-bvar 2)))))

;; ========================================
;; Core AST: Pretty-printing
;; ========================================

(test-case "pretty-print: PVec type"
  (check-equal? (pp-expr (expr-PVec (expr-Nat)) '()) "(PVec Nat)"))

(test-case "pretty-print: rrb value"
  (check-equal? (pp-expr (expr-rrb rrb-empty) '()) "@[]"))

;; ========================================
;; Core AST: Check cases
;; ========================================

(test-case "check: rrb against PVec"
  (check-true (tc:check ctx-empty (expr-rrb rrb-empty) (expr-PVec (expr-Nat)))))

(test-case "check: pvec-push against PVec propagates type"
  ;; This tests the critical check-propagation for @[...] literal desugaring
  (check-true (tc:check ctx-empty
                (expr-pvec-push (expr-pvec-empty (expr-Nat)) (expr-zero))
                (expr-PVec (expr-Nat)))))

;; ========================================
;; Surface syntax: PVec type
;; ========================================

(test-case "surface: PVec type check"
  (check-equal? (run "(check (PVec Nat) <(Type 0)>)")
                '("OK")))

;; ========================================
;; Surface syntax: pvec-empty
;; ========================================

(test-case "surface: pvec-empty eval"
  (let ([result (run "(eval (pvec-empty Nat))")])
    (check-equal? (length result) 1)
    (check-true (string-contains? (car result) "PVec Nat"))))

;; ========================================
;; Surface syntax: pvec-push + pvec-nth
;; ========================================

(test-case "surface: pvec-push + pvec-nth"
  (let ([result (run "(eval (pvec-nth (pvec-push (pvec-empty Nat) (suc zero)) zero))")])
    (check-equal? (length result) 1)
    (check-equal? (car result) "1N : Nat")))

;; ========================================
;; Surface syntax: pvec-update
;; ========================================

(test-case "surface: pvec-update"
  (let ([result (run "(eval (pvec-nth (pvec-update (pvec-push (pvec-empty Nat) zero) zero (suc zero)) zero))")])
    (check-equal? (car result) "1N : Nat")))

;; ========================================
;; Surface syntax: pvec-length
;; ========================================

(test-case "surface: pvec-length"
  (let ([result (run "(eval (pvec-length (pvec-push (pvec-push (pvec-empty Nat) zero) (suc zero))))")])
    (check-equal? (car result) "2N : Nat")))

;; ========================================
;; Surface syntax: pvec-pop
;; ========================================

(test-case "surface: pvec-pop"
  (let ([result (run "(eval (pvec-length (pvec-pop (pvec-push (pvec-push (pvec-empty Nat) zero) (suc zero)))))")])
    (check-equal? (car result) "1N : Nat")))

;; ========================================
;; Surface syntax: pvec-concat
;; ========================================

(test-case "surface: pvec-concat"
  (let ([result (run "(eval (pvec-length (pvec-concat (pvec-push (pvec-empty Nat) zero) (pvec-push (pvec-empty Nat) (suc zero)))))")])
    (check-equal? (car result) "2N : Nat")))

;; ========================================
;; Surface syntax: pvec-slice
;; ========================================

(test-case "surface: pvec-slice"
  (let ([result (run "(eval (pvec-length (pvec-slice (pvec-push (pvec-push (pvec-push (pvec-empty Nat) zero) (suc zero)) (suc (suc zero))) (suc zero) (suc (suc (suc zero))))))")])
    (check-equal? (car result) "2N : Nat")))

;; ========================================
;; Surface syntax: def + eval with PVec
;; ========================================

(test-case "surface: def + eval with PVec"
  (parameterize ([current-global-env (hasheq)])
    (let ([result (process-string "(def v <(PVec Nat)> (pvec-push (pvec-empty Nat) (suc (suc zero))))\n(eval (pvec-nth v zero))")])
      (check-equal? (length result) 2)
      (check-true (string-contains? (car result) "v : (PVec Nat) defined"))
      (check-equal? (cadr result) "2N : Nat"))))

;; ========================================
;; Surface syntax: defn with PVec parameter
;; ========================================

(test-case "surface: defn with PVec parameter"
  (parameterize ([current-global-env (hasheq)])
    (let ([result (process-string "(defn first-elem [v <(PVec Nat)>] <Nat> (pvec-nth v zero))\n(eval (first-elem (pvec-push (pvec-empty Nat) (suc (suc (suc zero))))))")])
      (check-equal? (length result) 2)
      (check-equal? (cadr result) "3N : Nat"))))

;; ========================================
;; @[...] literal syntax: empty
;; ========================================

(test-case "surface: empty @[] literal"
  ;; Empty vec literal needs checking context
  (let ([result (run "(eval @[])")])
    (check-equal? (length result) 1)))

;; ========================================
;; @[...] literal syntax: with check
;; ========================================

(test-case "surface: @[...] literal with check"
  (check-equal? (run "(check @[zero (suc zero)] <(PVec Nat)>)")
                '("OK")))

;; ========================================
;; @[...] literal syntax: via def
;; ========================================

(test-case "surface: @[...] literal via def"
  (parameterize ([current-global-env (hasheq)])
    (let ([result (process-string "(def v <(PVec Nat)> @[zero (suc zero) (suc (suc zero))])\n(eval (pvec-nth v (suc zero)))")])
      (check-equal? (length result) 2)
      (check-equal? (cadr result) "1N : Nat"))))

;; ========================================
;; @[...] literal syntax: pvec-nth on literal
;; ========================================

(test-case "surface: pvec-nth on @[...] literal via def"
  ;; @[...] literals need checking context to resolve element type metas
  (parameterize ([current-global-env (hasheq)])
    (let ([result (process-string "(def v <(PVec Nat)> @[zero (suc zero) (suc (suc zero))])\n(eval (pvec-nth v (suc (suc zero))))")])
      (check-equal? (length result) 2)
      (check-equal? (cadr result) "2N : Nat"))))

;; ========================================
;; Reader tests: WS reader @[] tokenization
;; ========================================

(test-case "reader: WS @[1 2 3] produces $vec-literal"
  (define forms (read-all-forms-string "eval @[1 2 3]"))
  (check-equal? forms '((eval ($vec-literal 1 2 3)))))

(test-case "reader: WS @[] produces empty $vec-literal"
  (define forms (read-all-forms-string "@[]"))
  (check-equal? forms '(($vec-literal))))

(test-case "reader: WS @[...] with commas stripped"
  (define forms (read-all-forms-string "@[1, 2, 3]"))
  (check-equal? forms '(($vec-literal 1 2 3))))

;; ========================================
;; Reader tests: sexp reader @[] support
;; ========================================

(test-case "sexp: @[1 2 3] produces $vec-literal"
  (define in (open-input-string "@[1 2 3]"))
  (define result (prologos-sexp-read in))
  (check-equal? result '($vec-literal 1 2 3)))

(test-case "sexp: @[] produces empty $vec-literal"
  (define in (open-input-string "@[]"))
  (define result (prologos-sexp-read in))
  (check-equal? result '($vec-literal)))

;; ========================================
;; pvec-to-list: PVec A → List A
;; ========================================

(test-case "pvec-to-list: empty vector"
  (let ([result (run "(eval (pvec-to-list (pvec-empty Nat)))")])
    (check-equal? (length result) 1)
    (check-true (string-contains? (car result) "nil"))))

(test-case "pvec-to-list: singleton vector"
  (let ([result (run "(eval (pvec-to-list (pvec-push (pvec-empty Nat) zero)))")])
    (check-equal? (length result) 1)
    (check-true (string-contains? (car result) "0N"))))

(test-case "pvec-to-list: multi-element vector"
  (parameterize ([current-global-env (hasheq)])
    (let ([result (process-string
                   (string-append
                    "(def v <(PVec Nat)> (pvec-push (pvec-push (pvec-empty Nat) zero) (suc zero)))\n"
                    "(eval (pvec-to-list v))"))])
      (check-equal? (length result) 2)
      ;; Second result is the list with 0N and 1N
      (check-true (string-contains? (cadr result) "0N"))
      (check-true (string-contains? (cadr result) "1N")))))

(test-case "pvec-to-list: type inferred as List A"
  (let ([result (run "(infer (pvec-to-list (pvec-empty Nat)))")])
    (check-equal? (length result) 1)
    (check-true (string-contains? (car result) "List"))
    (check-true (string-contains? (car result) "Nat"))))

;; ========================================
;; pvec-from-list: List A → PVec A
;; ========================================

(test-case "pvec-from-list: empty list"
  (let ([result (run-ns
                 (string-append
                  "(ns pvec-from-list-test-1)\n"
                  "(eval (pvec-length (pvec-from-list (nil Nat))))"))])
    (check-true (string-contains? (last result) "0N"))))

(test-case "pvec-from-list: singleton list"
  (let ([result (run-ns
                 (string-append
                  "(ns pvec-from-list-test-2)\n"
                  "(eval (pvec-length (pvec-from-list (cons zero (nil Nat)))))"))])
    (check-true (string-contains? (last result) "1N"))))

(test-case "pvec-from-list: roundtrip pvec→list→pvec"
  (let ([result (run-ns
                 (string-append
                  "(ns pvec-from-list-test-3)\n"
                  "(def v <(PVec Nat)> (pvec-push (pvec-push (pvec-empty Nat) zero) (suc zero)))\n"
                  "(eval (pvec-length (pvec-from-list (pvec-to-list v))))"))])
    (check-true (string-contains? (last result) "2N"))))

(test-case "pvec-from-list: type inferred as PVec A"
  (let ([result (run-ns
                 (string-append
                  "(ns pvec-from-list-test-4)\n"
                  "(infer (pvec-from-list (nil Nat)))"))])
    (check-true (string-contains? (last result) "PVec"))
    (check-true (string-contains? (last result) "Nat"))))
