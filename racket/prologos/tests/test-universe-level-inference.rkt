#lang racket/base

;;;
;;; Tests for Sprint 6: Universe Level Inference
;;;
;;; Tests the level-meta struct, level-meta store, unify-level,
;;; zonk-level, and integration with parser/elaborator for bare Type.
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
;; Unit tests: level-meta infrastructure
;; ========================================

(test-case "level-meta/fresh-creates-unsolved"
  (parameterize ([current-level-meta-store (make-hasheq)])
    (define lm (fresh-level-meta "test"))
    (check-true (level-meta? lm))
    (check-false (level-meta-solved? (level-meta-id lm)))))

(test-case "level-meta/solve-and-retrieve"
  (parameterize ([current-level-meta-store (make-hasheq)])
    (define lm (fresh-level-meta "test"))
    (define id (level-meta-id lm))
    (solve-level-meta! id (lzero))
    (check-true (level-meta-solved? id))
    (check-equal? (level-meta-solution id) (lzero))))

(test-case "level-meta/solve-with-lsuc"
  (parameterize ([current-level-meta-store (make-hasheq)])
    (define lm (fresh-level-meta "test"))
    (define id (level-meta-id lm))
    (solve-level-meta! id (lsuc (lzero)))
    (check-equal? (level-meta-solution id) (lsuc (lzero)))))

;; ========================================
;; Unit tests: zonk-level
;; ========================================

(test-case "zonk-level/follows-solved"
  (parameterize ([current-level-meta-store (make-hasheq)])
    (define lm (fresh-level-meta "test"))
    (solve-level-meta! (level-meta-id lm) (lsuc (lzero)))
    (check-equal? (zonk-level lm) (lsuc (lzero)))))

(test-case "zonk-level/preserves-unsolved"
  (parameterize ([current-level-meta-store (make-hasheq)])
    (define lm (fresh-level-meta "test"))
    ;; zonk-level preserves unsolved level-metas (for intermediate use)
    (check-true (level-meta? (zonk-level lm)))))

(test-case "zonk-level-default/defaults-unsolved-to-lzero"
  (parameterize ([current-level-meta-store (make-hasheq)])
    (define lm (fresh-level-meta "test"))
    ;; zonk-level-default defaults unsolved to lzero (for final output)
    (check-equal? (zonk-level-default lm) (lzero))))

(test-case "zonk-level/handles-lsuc-of-level-meta"
  (parameterize ([current-level-meta-store (make-hasheq)])
    (define lm (fresh-level-meta "test"))
    (solve-level-meta! (level-meta-id lm) (lzero))
    (check-equal? (zonk-level (lsuc lm)) (lsuc (lzero)))))

(test-case "zonk-level/transitive"
  (parameterize ([current-level-meta-store (make-hasheq)])
    (define lm1 (fresh-level-meta "a"))
    (define lm2 (fresh-level-meta "b"))
    (solve-level-meta! (level-meta-id lm1) lm2)
    (solve-level-meta! (level-meta-id lm2) (lsuc (lzero)))
    (check-equal? (zonk-level lm1) (lsuc (lzero)))))

;; ========================================
;; Unit tests: unify-level
;; ========================================

(test-case "unify-level/meta-vs-concrete"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-level-meta-store (make-hasheq)]
                 [current-constraint-store '()]
                 [current-wakeup-registry (make-hasheq)]
                 [current-global-env (hasheq)])
    (define lm (fresh-level-meta "test"))
    ;; Unify Type(?l) vs Type(0)
    (define t1 (expr-Type lm))
    (define t2 (expr-Type (lzero)))
    (check-equal? (unify ctx-empty t1 t2) #t)
    (check-true (level-meta-solved? (level-meta-id lm)))
    (check-equal? (level-meta-solution (level-meta-id lm)) (lzero))))

(test-case "unify-level/two-metas"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-level-meta-store (make-hasheq)]
                 [current-constraint-store '()]
                 [current-wakeup-registry (make-hasheq)]
                 [current-global-env (hasheq)])
    (define lm1 (fresh-level-meta "a"))
    (define lm2 (fresh-level-meta "b"))
    (define t1 (expr-Type lm1))
    (define t2 (expr-Type lm2))
    (check-equal? (unify ctx-empty t1 t2) #t)
    ;; One should be solved to the other
    (check-true (level-meta-solved? (level-meta-id lm1)))))

(test-case "unify-level/lsuc-vs-lsuc"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-level-meta-store (make-hasheq)]
                 [current-constraint-store '()]
                 [current-wakeup-registry (make-hasheq)]
                 [current-global-env (hasheq)])
    (define t1 (expr-Type (lsuc (lzero))))
    (define t2 (expr-Type (lsuc (lzero))))
    (check-equal? (unify ctx-empty t1 t2) #t)))

(test-case "unify-level/mismatch-rejects"
  (parameterize ([current-meta-store (make-hasheq)]
                 [current-level-meta-store (make-hasheq)]
                 [current-constraint-store '()]
                 [current-wakeup-registry (make-hasheq)]
                 [current-global-env (hasheq)])
    (define t1 (expr-Type (lzero)))
    (define t2 (expr-Type (lsuc (lzero))))
    (check-equal? (unify ctx-empty t1 t2) #f)))

;; ========================================
;; Unit tests: lmax / level<=? with level-metas
;; ========================================

(test-case "lmax/zero-and-level-meta"
  (parameterize ([current-level-meta-store (make-hasheq)])
    (define lm (fresh-level-meta "test"))
    ;; lmax(lzero, ?l) = ?l
    (check-equal? (lmax (lzero) lm) lm)
    ;; lmax(?l, lzero) = ?l
    (check-equal? (lmax lm (lzero)) lm)))

(test-case "lmax/concrete-and-level-meta"
  (parameterize ([current-level-meta-store (make-hasheq)])
    (define lm (fresh-level-meta "test"))
    ;; lmax(?l, lsuc(lzero)) = lsuc(lzero)  — concrete wins
    (check-equal? (lmax lm (lsuc (lzero))) (lsuc (lzero)))
    (check-equal? (lmax (lsuc (lzero)) lm) (lsuc (lzero)))))

(test-case "level<=?/meta-is-optimistic"
  (parameterize ([current-level-meta-store (make-hasheq)])
    (define lm (fresh-level-meta "test"))
    (check-true (level<=? lm (lsuc (lzero))))
    (check-true (level<=? lm (lzero)))
    (check-true (level<=? (lsuc (lzero)) lm))))

;; ========================================
;; Unit tests: level? predicate
;; ========================================

(test-case "level?/accepts-level-meta"
  (parameterize ([current-level-meta-store (make-hasheq)])
    (define lm (fresh-level-meta "test"))
    (check-true (level? lm))))

;; ========================================
;; Integration tests: level inference in user code
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
                 [current-preparse-registry (current-preparse-registry)])
    (install-module-loader!)
    (process-string s)))

;; Helper: run code and return the last result line
(define (run-last s)
  (last (run-ns s)))

(test-case "implicit/id-with-inferred-level"
  ;; id uses {A} which now gets level-meta instead of Type 0
  (check-equal?
   (run-last "(ns lvl1)\n(require [prologos::core :refer [id]])\n(eval (id zero))")
   "0N : Nat"))

(test-case "implicit/const-with-inferred-level"
  (check-equal?
   (run-last "(ns lvl2)\n(require [prologos::core :refer [const]])\n(eval (const zero true))")
   "0N : Nat"))

(test-case "implicit/compose-with-inferred-level"
  (check-equal?
   (run-last "(ns lvl3)\n(require [prologos::core :refer [compose]])\n(require [prologos::data::nat :refer [double pred]])\n(eval (compose double pred 3N))")
   "4N : Nat"))

(test-case "explicit-type-0-still-works"
  (check-equal?
   (run-last "(ns lvl4)\n(def id <(Pi [A :0 <(Type 0)>] (-> A A))>\n  (fn [A :0 <(Type 0)>] (fn [x <A>] x)))\n(eval (id Nat zero))")
   "0N : Nat"))

(test-case "infer-bare-Type"
  ;; Bare Type should infer as Type, and (infer Type) should give (Type 1)
  ;; Note: infer returns just the type, not "expr : type"
  (check-equal?
   (run-last "(ns lvl5)\n(infer Type)")
   "[Type 1]"))

(test-case "implicit/stdlib-nat-with-inferred-level"
  ;; add 2 3 = 5 — stdlib still works with level inference
  (check-equal?
   (run-last "(ns lvl6)\n(require [prologos::data::nat :refer [add]])\n(eval (add 2N 3N))")
   "5N : Nat"))

(test-case "implicit/stdlib-bool-with-inferred-level"
  ;; not true = false
  (check-equal?
   (run-last "(ns lvl7)\n(require [prologos::data::bool :refer [not]])\n(eval (not true))")
   "false : Bool"))
