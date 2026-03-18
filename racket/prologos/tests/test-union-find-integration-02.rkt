#lang racket/base

;;;
;;; Tests for UnionFind surface syntax integration (Part 2)
;;; Sections D-F: Union+find, persistence, three sets
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

;; Helper to run with clean global env (sexp mode, no prelude)
(define (run s)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
    (process-string s)))

;; Helper to run with prelude (needed for nat-eq?, etc.)
(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
    (process-string (string-append "(ns test) " s))))

;; ========================================
;; Eval: union + find (requires prelude for nat-eq?)
;; ========================================

(test-case "surface: union two sets, find returns same root"
  (let ([result (run-ns (string-append
                          "(def s0 : UnionFind (uf-empty))"
                          "(def s1 : UnionFind (uf-make-set s0 0N true))"
                          "(def s2 : UnionFind (uf-make-set s1 1N false))"
                          "(def s3 : UnionFind (uf-union s2 0N 1N))"
                          "(def r0 : Nat (fst (uf-find s3 0N)))"
                          "(def r1 : Nat (fst (uf-find s3 1N)))"
                          "(eval (nat-eq? r0 r1))"))])
    (check-not-false (member "true : Bool" result)
                "after union, both ids have same root")))

;; ========================================
;; Persistence: old store unchanged
;; ========================================

(test-case "surface: persistence — old store unaffected by union"
  (let ([result (run-ns (string-append
                          "(def s0 : UnionFind (uf-empty))"
                          "(def s1 : UnionFind (uf-make-set s0 0N true))"
                          "(def s2 : UnionFind (uf-make-set s1 1N false))"
                          "(def s3 : UnionFind (uf-union s2 0N 1N))"
                          ;; Query old store s2: 0 and 1 should have different roots
                          "(def r0-old : Nat (fst (uf-find s2 0N)))"
                          "(def r1-old : Nat (fst (uf-find s2 1N)))"
                          "(eval (nat-eq? r0-old r1-old))"))])
    (check-not-false (member "false : Bool" result)
                "old store: 0 and 1 are separate (different roots)")))

;; ========================================
;; Make 3 sets, union chain
;; ========================================

(test-case "surface: three sets, union chain"
  (let ([result (run-ns (string-append
                          "(def s0 : UnionFind (uf-empty))"
                          "(def s1 : UnionFind (uf-make-set s0 0N true))"
                          "(def s2 : UnionFind (uf-make-set s1 1N false))"
                          "(def s3 : UnionFind (uf-make-set s2 2N true))"
                          "(def s4 : UnionFind (uf-union s3 0N 1N))"
                          "(def s5 : UnionFind (uf-union s4 1N 2N))"
                          ;; All three should have same root
                          "(def r0 : Nat (fst (uf-find s5 0N)))"
                          "(def r2 : Nat (fst (uf-find s5 2N)))"
                          "(eval (nat-eq? r0 r2))"))])
    (check-not-false (member "true : Bool" result)
                "after chained unions, 0 and 2 have same root")))
