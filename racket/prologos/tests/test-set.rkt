#lang racket/base

;;;
;;; Tests for Set (persistent hash set, CHAMP-backed) integration
;;;

(require racket/string
         rackunit
         "../syntax.rkt"
         "../prelude.rkt"
         "../substitution.rkt"
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../pretty-print.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../champ.rkt"
         "../parse-reader.rkt"
         "../sexp-readtable.rkt")

;; Helper to run with clean global env
(define (run s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
    (process-string s)))

;; ========================================
;; Core AST: Set type formation
;; ========================================

(test-case "Set type formation"
  (check-equal? (tc:infer ctx-empty (expr-Set (expr-Nat)))
                (expr-Type (lzero))
                "(Set Nat) : Type 0")
  (check-true (tc:is-type ctx-empty (expr-Set (expr-Nat)))
              "(Set Nat) is a type"))

(test-case "Set type level"
  (check-equal? (tc:infer-level ctx-empty (expr-Set (expr-Nat)))
                (tc:just-level (lzero))
                "(Set Nat) at level 0"))

;; ========================================
;; Core AST: set-empty typing
;; ========================================

(test-case "set-empty typing"
  (check-equal? (tc:infer ctx-empty (expr-set-empty (expr-Nat)))
                (expr-Set (expr-Nat))
                "set-empty(Nat) : Set Nat"))

;; ========================================
;; Core AST: set-insert typing
;; ========================================

(test-case "set-insert typing"
  (let ([s (expr-set-empty (expr-Nat))])
    (check-equal? (tc:infer ctx-empty (expr-set-insert s (expr-zero)))
                  (expr-Set (expr-Nat))
                  "set-insert infers Set Nat")))

;; ========================================
;; Core AST: set-member? typing
;; ========================================

(test-case "set-member? typing"
  (let ([s (expr-set-empty (expr-Nat))])
    (check-equal? (tc:infer ctx-empty (expr-set-member s (expr-zero)))
                  (expr-Bool)
                  "set-member? infers Bool")))

;; ========================================
;; Core AST: set-delete typing
;; ========================================

(test-case "set-delete typing"
  (let ([s (expr-set-empty (expr-Nat))])
    (check-equal? (tc:infer ctx-empty (expr-set-delete s (expr-zero)))
                  (expr-Set (expr-Nat))
                  "set-delete infers Set Nat")))

;; ========================================
;; Core AST: set-size typing
;; ========================================

(test-case "set-size typing"
  (let ([s (expr-set-empty (expr-Nat))])
    (check-equal? (tc:infer ctx-empty (expr-set-size s))
                  (expr-Nat)
                  "set-size infers Nat")))

;; ========================================
;; Core AST: set-union / set-intersect / set-diff typing
;; ========================================

(test-case "set-union typing"
  (let ([s (expr-set-empty (expr-Nat))])
    (check-equal? (tc:infer ctx-empty (expr-set-union s s))
                  (expr-Set (expr-Nat))
                  "set-union infers Set Nat")))

(test-case "set-intersect typing"
  (let ([s (expr-set-empty (expr-Nat))])
    (check-equal? (tc:infer ctx-empty (expr-set-intersect s s))
                  (expr-Set (expr-Nat))
                  "set-intersect infers Set Nat")))

(test-case "set-diff typing"
  (let ([s (expr-set-empty (expr-Nat))])
    (check-equal? (tc:infer ctx-empty (expr-set-diff s s))
                  (expr-Set (expr-Nat))
                  "set-diff infers Set Nat")))

;; ========================================
;; Core AST: Check cases
;; ========================================

(test-case "check: hset against Set"
  (check-true (tc:check ctx-empty (expr-hset champ-empty) (expr-Set (expr-Nat)))
              "hset checks against (Set Nat)"))

(test-case "check: set-empty against Set"
  (check-true (tc:check ctx-empty (expr-set-empty (expr-Nat)) (expr-Set (expr-Nat)))
              "set-empty checks against (Set Nat)"))

(test-case "check: set-insert propagates type"
  ;; This tests check-propagation: set-insert checked against (Set Nat)
  ;; propagates Nat to both the set and the element
  (check-true (tc:check ctx-empty
                (expr-set-insert (expr-set-empty (expr-Nat)) (expr-zero))
                (expr-Set (expr-Nat)))
              "set-insert check-propagation works"))

;; ========================================
;; Core AST: Reduction (iota rules)
;; ========================================

(test-case "set-empty reduces to hset"
  (let ([result (whnf (expr-set-empty (expr-Nat)))])
    (check-true (expr-hset? result) "set-empty produces hset")))

(test-case "set-insert + set-member? round-trip"
  ;; Insert zero, then check membership
  (let* ([empty (expr-hset champ-empty)]
         [s1 (whnf (expr-set-insert empty (expr-zero)))])
    (check-true (expr-hset? s1) "insert produces hset")
    (check-equal? (whnf (expr-set-member s1 (expr-zero)))
                  (expr-true)
                  "member after insert → true")
    (check-equal? (whnf (expr-set-member s1 (expr-suc (expr-zero))))
                  (expr-false)
                  "member of non-inserted → false")))

(test-case "set-delete reduction"
  (let* ([empty (expr-hset champ-empty)]
         [s1 (whnf (expr-set-insert empty (expr-zero)))]
         [s2 (whnf (expr-set-delete s1 (expr-zero)))])
    (check-equal? (whnf (expr-set-member s2 (expr-zero)))
                  (expr-false)
                  "after delete, member → false")))

(test-case "set-size reduction"
  (let* ([empty (expr-hset champ-empty)]
         [s1 (whnf (expr-set-insert empty (expr-zero)))]
         [s2 (whnf (expr-set-insert s1 (expr-suc (expr-zero))))])
    (check-equal? (whnf (expr-set-size empty)) (expr-nat-val 0)
                  "empty set has size 0")
    (check-equal? (whnf (expr-set-size s2)) (expr-nat-val 2)
                  "two-element set has size 2")))

(test-case "set-insert duplicate does not increase size"
  (let* ([empty (expr-hset champ-empty)]
         [s1 (whnf (expr-set-insert empty (expr-zero)))]
         [s2 (whnf (expr-set-insert s1 (expr-zero)))])
    (check-equal? (whnf (expr-set-size s2)) (expr-nat-val 1)
                  "duplicate insert → size still 1")))

(test-case "set-union reduction"
  ;; {0} ∪ {1} → has both 0 and 1
  (let* ([empty (expr-hset champ-empty)]
         [s1 (whnf (expr-set-insert empty (expr-zero)))]
         [s2 (whnf (expr-set-insert empty (expr-suc (expr-zero))))]
         [u (whnf (expr-set-union s1 s2))])
    (check-equal? (whnf (expr-set-member u (expr-zero)))
                  (expr-true)
                  "union contains 0")
    (check-equal? (whnf (expr-set-member u (expr-suc (expr-zero))))
                  (expr-true)
                  "union contains 1")
    (check-equal? (whnf (expr-set-size u)) (expr-nat-val 2)
                  "union size = 2")))

(test-case "set-intersect reduction"
  ;; {0,1} ∩ {1,2} → {1}
  (let* ([empty (expr-hset champ-empty)]
         [s1 (whnf (expr-set-insert (whnf (expr-set-insert empty (expr-zero))) (expr-suc (expr-zero))))]
         [s2 (whnf (expr-set-insert (whnf (expr-set-insert empty (expr-suc (expr-zero)))) (expr-suc (expr-suc (expr-zero)))))]
         [i (whnf (expr-set-intersect s1 s2))])
    (check-equal? (whnf (expr-set-member i (expr-suc (expr-zero))))
                  (expr-true)
                  "intersect contains 1")
    (check-equal? (whnf (expr-set-member i (expr-zero)))
                  (expr-false)
                  "intersect does not contain 0")
    (check-equal? (whnf (expr-set-member i (expr-suc (expr-suc (expr-zero)))))
                  (expr-false)
                  "intersect does not contain 2")))

(test-case "set-diff reduction"
  ;; {0,1} \ {1} → {0}
  (let* ([empty (expr-hset champ-empty)]
         [s1 (whnf (expr-set-insert (whnf (expr-set-insert empty (expr-zero))) (expr-suc (expr-zero))))]
         [s2 (whnf (expr-set-insert empty (expr-suc (expr-zero))))]
         [d (whnf (expr-set-diff s1 s2))])
    (check-equal? (whnf (expr-set-member d (expr-zero)))
                  (expr-true)
                  "diff contains 0")
    (check-equal? (whnf (expr-set-member d (expr-suc (expr-zero))))
                  (expr-false)
                  "diff does not contain 1")))

;; ========================================
;; Core AST: Substitution
;; ========================================

(test-case "set substitution: shift through Set type"
  (check-equal? (shift 1 0 (expr-Set (expr-bvar 0)))
                (expr-Set (expr-bvar 1))
                "shift increases bvar in Set type"))

(test-case "set substitution: shift through set operations"
  (check-equal? (shift 1 0 (expr-set-insert (expr-bvar 0) (expr-bvar 1)))
                (expr-set-insert (expr-bvar 1) (expr-bvar 2))
                "shift increases bvars in set-insert")
  (check-equal? (shift 1 0 (expr-hset champ-empty))
                (expr-hset champ-empty)
                "hset is opaque, stable under shift"))

;; ========================================
;; Core AST: Pretty-printing
;; ========================================

(test-case "pretty-print: Set type"
  (check-equal? (pp-expr (expr-Set (expr-Nat)) '()) "(Set Nat)"))

(test-case "pretty-print: hset value"
  (check-equal? (pp-expr (expr-hset champ-empty) '()) "#{}"))

(test-case "pretty-print: set-empty"
  (check-true (string-contains? (pp-expr (expr-set-empty (expr-Nat)) '()) "set-empty")))

;; ========================================
;; Surface syntax: Set type formation
;; ========================================

(test-case "surface: Set type check"
  (check-equal? (run "(check (Set Nat) <(Type 0)>)")
                '("OK")))

;; ========================================
;; Surface syntax: set-empty
;; ========================================

(test-case "surface: set-empty eval"
  (let ([result (run "(eval (set-empty Nat))")])
    (check-equal? (length result) 1)
    (check-true (string-contains? (car result) "Set Nat"))))

;; ========================================
;; Surface syntax: set-insert + set-member?
;; ========================================

(test-case "surface: set-insert + set-member?"
  (check-equal? (run "(eval (set-member? (set-insert (set-empty Nat) (suc zero)) (suc zero)))")
                '("true : Bool"))
  (check-equal? (run "(eval (set-member? (set-empty Nat) zero))")
                '("false : Bool")))

;; ========================================
;; Surface syntax: set-delete
;; ========================================

(test-case "surface: set-delete"
  (check-equal? (run "(eval (set-member? (set-delete (set-insert (set-empty Nat) zero) zero) zero))")
                '("false : Bool")))

;; ========================================
;; Surface syntax: set-size
;; ========================================

(test-case "surface: set-size"
  (check-equal? (run "(eval (set-size (set-empty Nat)))")
                '("0N : Nat"))
  (check-equal? (run "(eval (set-size (set-insert (set-empty Nat) zero)))")
                '("1N : Nat")))

;; ========================================
;; Surface syntax: set-union
;; ========================================

(test-case "surface: set-union"
  (check-equal?
    (run "(eval (set-size (set-union (set-insert (set-empty Nat) zero) (set-insert (set-empty Nat) (suc zero)))))")
    '("2N : Nat")))

;; ========================================
;; Surface syntax: set-intersect
;; ========================================

(test-case "surface: set-intersect"
  ;; {0,1} ∩ {1,2} → size 1
  (check-equal?
    (run "(eval (set-size (set-intersect (set-insert (set-insert (set-empty Nat) zero) (suc zero)) (set-insert (set-insert (set-empty Nat) (suc zero)) (suc (suc zero))))))")
    '("1N : Nat")))

;; ========================================
;; Surface syntax: set-diff
;; ========================================

(test-case "surface: set-diff"
  ;; {0,1} \ {1} → size 1
  (check-equal?
    (run "(eval (set-size (set-diff (set-insert (set-insert (set-empty Nat) zero) (suc zero)) (set-insert (set-empty Nat) (suc zero)))))")
    '("1N : Nat")))

;; ========================================
;; Surface syntax: def + eval with Set
;; ========================================

(test-case "surface: def + eval with Set"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
    (let ([result (process-string "(def s <(Set Nat)> (set-insert (set-empty Nat) (suc (suc zero))))\n(eval (set-member? s (suc (suc zero))))")])
      (check-equal? (length result) 2)
      (check-true (string-contains? (car result) "s : (Set Nat) defined"))
      (check-equal? (cadr result) "true : Bool"))))

;; ========================================
;; Surface syntax: defn with Set parameter
;; ========================================

(test-case "surface: defn with Set parameter"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
    (let ([result (process-string "(defn has-zero [s <(Set Nat)>] <Bool> (set-member? s zero))\n(eval (has-zero (set-insert (set-empty Nat) zero)))")])
      (check-equal? (length result) 2)
      (check-equal? (cadr result) "true : Bool"))))

;; ========================================
;; #{...} literal syntax: empty (sexp)
;; ========================================

(test-case "surface: empty #{} literal"
  ;; #{} should parse as an empty set literal
  (let ([result (run "(eval #{})")])
    ;; Empty set needs type annotation context; without it, metas may not resolve
    ;; Just check it doesn't crash
    (check-equal? (length result) 1)))

;; ========================================
;; #{...} literal syntax: with check
;; ========================================

(test-case "surface: #{...} literal with check"
  (check-equal? (run "(check #{zero (suc zero)} <(Set Nat)>)")
                '("OK")))

;; ========================================
;; #{...} literal syntax: via def
;; ========================================

(test-case "surface: #{...} literal via def"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
    (let ([result (process-string "(def s <(Set Nat)> #{zero (suc zero) (suc (suc zero))})\n(eval (set-size s))")])
      (check-equal? (length result) 2)
      (check-equal? (cadr result) "3N : Nat"))))

;; ========================================
;; #{...} literal syntax: member? on literal
;; ========================================

(test-case "surface: set-member? on #{...} literal via def"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
    (let ([result (process-string "(def s <(Set Nat)> #{zero (suc zero) (suc (suc zero))})\n(eval (set-member? s (suc zero)))")])
      (check-equal? (length result) 2)
      (check-equal? (cadr result) "true : Bool"))))

;; ========================================
;; Reader tests: WS reader #{} tokenization
;; ========================================

(test-case "reader: WS #{1 2 3} produces $set-literal"
  (define forms (read-all-forms-string "eval #{1 2 3}"))
  (check-equal? forms '((eval ($set-literal 1 2 3)))))

(test-case "reader: WS #{} produces empty $set-literal"
  (define forms (read-all-forms-string "#{}"))
  (check-equal? forms '(($set-literal))))

(test-case "reader: WS #{...} with commas stripped"
  (define forms (read-all-forms-string "#{1, 2, 3}"))
  (check-equal? forms '(($set-literal 1 2 3))))

;; ========================================
;; Reader tests: sexp reader #{} support
;; ========================================

(test-case "sexp: #{1 2 3} produces $set-literal"
  (define in (open-input-string "#{1 2 3}"))
  (define result (prologos-sexp-read in))
  (check-equal? result '($set-literal 1 2 3)))

(test-case "sexp: #{} produces empty $set-literal"
  (define in (open-input-string "#{}"))
  (define result (prologos-sexp-read in))
  (check-equal? result '($set-literal)))

;; ========================================
;; set-to-list reduction (Phase 3a)
;; ========================================

(test-case "set-to-list: empty set"
  (let ([result (run "(eval (set-to-list (set-empty Nat)))")])
    (check-equal? (length result) 1)
    (check-true (string-contains? (car result) "nil"))))

(test-case "set-to-list: singleton set"
  (let ([result (run "(eval (set-to-list (set-insert (set-empty Nat) (suc zero))))")])
    (check-equal? (length result) 1)
    (check-true (string-contains? (car result) "1N"))))

(test-case "set-to-list: multi-element set has correct count"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
    (let ([result (process-string
                   (string-append
                    "(def s <(Set Nat)> (set-insert (set-insert (set-empty Nat) zero) (suc zero)))\n"
                    "(eval (set-to-list s))"))])
      (check-equal? (length result) 2)
      ;; Second result is the list — should mention both 0N and 1N
      (check-true (string-contains? (cadr result) "0N"))
      (check-true (string-contains? (cadr result) "1N")))))
