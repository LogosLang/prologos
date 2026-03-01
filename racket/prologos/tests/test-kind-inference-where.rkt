#lang racket/base

;;;
;;; Tests for Kind Inference Direction 2:
;;; Auto-detect free type variables in :where clauses and infer their kind
;;; from the trait declaration.
;;;
;;; Key scenario: spec foo (C A) -> (LSeq A) where (Seqable C)
;;; WITHOUT explicit {C} — C auto-detected, kind inferred as Type -> Type
;;; from Seqable's trait declaration.
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt")

;; ========================================
;; Helper: run with spec-store inspection
;; ========================================

(define (run-ns-with-spec-store s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (define results (process-string s))
    (values results (current-spec-store))))

;; ========================================
;; 1. Spec-level auto-detection + kind refinement
;; ========================================
;; Verify that spec entries store correct implicit-binders with refined kinds
;; when no explicit {C} is given.

(test-case "D2: Seqable C in where — C auto-detected, kind refined to Type -> Type"
  (define-values (_results spec-store)
    (run-ns-with-spec-store
      (string-append
        "(ns test-d2-1 :no-prelude)\n"
        "(require [prologos::core::collection-traits :refer [Seqable]])\n"
        "(require [prologos::data::lseq :refer [LSeq]])\n"
        "(spec my-to-seq (C A) -> (LSeq A) where (Seqable C))\n")))
  (define se (hash-ref spec-store 'my-to-seq #f))
  (check-true (spec-entry? se) "spec entry should exist")
  (define binders (spec-entry-implicit-binders se))
  ;; C should be auto-detected and refined to (-> (Type 0) (Type 0))
  (define c-binder (assq 'C binders))
  (check-true (pair? c-binder) "C binder should exist")
  (check-equal? (cdr c-binder) '(-> (Type 0) (Type 0))
                "C should have kind Type -> Type from Seqable")
  ;; A should remain at default kind (Type 0)
  (define a-binder (assq 'A binders))
  (check-true (pair? a-binder) "A binder should exist")
  (check-equal? (cdr a-binder) '(Type 0)
                "A should remain at default kind Type"))

(test-case "D2: Buildable C in where — C auto-detected, kind refined"
  (define-values (_results spec-store)
    (run-ns-with-spec-store
      (string-append
        "(ns test-d2-2 :no-prelude)\n"
        "(require [prologos::core::collection-traits :refer [Buildable]])\n"
        "(require [prologos::data::lseq :refer [LSeq]])\n"
        "(spec my-build (LSeq A) -> (C A) where (Buildable C))\n")))
  (define se (hash-ref spec-store 'my-build #f))
  (check-true (spec-entry? se))
  (define binders (spec-entry-implicit-binders se))
  (define c-binder (assq 'C binders))
  (check-true (pair? c-binder))
  (check-equal? (cdr c-binder) '(-> (Type 0) (Type 0))))

(test-case "D2: multiple HKT constraints — Seqable C + Buildable C agree"
  (define-values (_results spec-store)
    (run-ns-with-spec-store
      (string-append
        "(ns test-d2-3 :no-prelude)\n"
        "(require [prologos::core::collection-traits :refer [Seqable]])\n"
        "(require [prologos::core::collection-traits :refer [Buildable]])\n"
        "(require [prologos::data::lseq :refer [LSeq]])\n"
        "(spec gmap (-> A B) -> (C A) -> (C B) where (Seqable C) (Buildable C))\n")))
  (define se (hash-ref spec-store 'gmap #f))
  (check-true (spec-entry? se))
  (define binders (spec-entry-implicit-binders se))
  ;; C refined to Type -> Type by both Seqable and Buildable (agree)
  (check-equal? (cdr (assq 'C binders)) '(-> (Type 0) (Type 0)))
  ;; A and B stay at default Type
  (check-equal? (cdr (assq 'A binders)) '(Type 0))
  (check-equal? (cdr (assq 'B binders)) '(Type 0)))

(test-case "D2: mixed HKT + Type constraints — C: Type->Type, A: Type"
  (define-values (_results spec-store)
    (run-ns-with-spec-store
      (string-append
        "(ns test-d2-4 :no-prelude)\n"
        "(require [prologos::core::collection-traits :refer [Seqable]])\n"
        "(require [prologos::core::eq-trait :refer [Eq]])\n"
        "(spec gfilter (-> A Bool) -> (C A) -> (C A) where (Seqable C) (Eq A))\n")))
  (define se (hash-ref spec-store 'gfilter #f))
  (check-true (spec-entry? se))
  (define binders (spec-entry-implicit-binders se))
  ;; C refined by Seqable
  (check-equal? (cdr (assq 'C binders)) '(-> (Type 0) (Type 0)))
  ;; A stays at Type (Eq has {A : Type})
  (check-equal? (cdr (assq 'A binders)) '(Type 0)))

(test-case "D2: variable only in where clause — still auto-detected"
  (define-values (_results spec-store)
    (run-ns-with-spec-store
      (string-append
        "(ns test-d2-5 :no-prelude)\n"
        "(require [prologos::core::collection-traits :refer [Seqable]])\n"
        ;; C only appears in where, not in type signature
        "(spec my-phantom Nat where (Seqable C))\n")))
  (define se (hash-ref spec-store 'my-phantom #f))
  (check-true (spec-entry? se))
  (define binders (spec-entry-implicit-binders se))
  ;; C auto-detected from constraint args, kind refined from Seqable
  (define c-binder (assq 'C binders))
  (check-true (pair? c-binder))
  (check-equal? (cdr c-binder) '(-> (Type 0) (Type 0))))

;; ========================================
;; 2. E2E sexp-mode — type-checkable definitions
;; ========================================

(test-case "D2 e2e: spec with where (Eq A) — no explicit {A}, type-checks"
  ;; Simple case: Eq has {A : Type}, auto-detected A stays at Type
  ;; Uses explicit dict passing pattern (proven in test-where-parsing.rkt)
  ;; Note: nat-eq is the Eq dict for Nat, so use Nat literals (zero, suc zero)
  (define result
    (run-ns-last
      (string-append
        "(ns test-d2-e2e1)\n"
        ";; No explicit {A} binder on spec — A is auto-detected\n"
        "(spec my-eq-check A A -> Bool where (Eq A))\n"
        "(defn my-eq-check [d x y] (d x y))\n"
        "(eval (my-eq-check nat-eq zero zero))\n")))
  (check-true (string-contains? result "true")))

(test-case "D2 e2e: spec with where (Eq A) — call with different values"
  (define result
    (run-ns-last
      (string-append
        "(ns test-d2-e2e2)\n"
        "(spec my-neq A A -> Bool where (Eq A))\n"
        "(defn my-neq [d x y] (not (d x y)))\n"
        "(eval (my-neq nat-eq zero (suc zero)))\n")))
  (check-true (string-contains? result "true")))

(test-case "D2 e2e: spec with where (Ord A) — auto-detected, uses ord-lt"
  ;; Use explicit dict passing pattern (proven in test-where-parsing.rkt)
  (define result
    (run-ns-last
      (string-append
        "(ns test-d2-e2e3)\n"
        "(spec my-lt A A -> Bool where (Ord A))\n"
        "(defn my-lt [d x y] (ord-lt d x y))\n"
        "(eval (my-lt nat-ord zero (suc zero)))\n")))
  (check-true (string-contains? result "true")))

;; ========================================
;; 3. E2E — additional callable function tests
;; ========================================
;; Note: process-string always uses sexp reader. WS mode requires .prologos files.
;; These tests use sexp mode throughout.

(test-case "D2 e2e: spec with where (Eq A) (Ord A) — multiple constraints"
  ;; Two constraints, both Type-kinded — both A's auto-detected
  (define result
    (run-ns-last
      (string-append
        "(ns test-d2-e2e4)\n"
        "(spec my-cmp A A -> Bool where (Eq A) (Ord A))\n"
        "(defn my-cmp [d1 d2 x y] (ord-lt d2 x y))\n"
        "(eval (my-cmp nat-eq nat-ord zero (suc zero)))\n")))
  (check-true (string-contains? result "true")))

(test-case "D2 e2e: spec with where (Eq A) — different result (inequality)"
  ;; Verify auto-detected where works for false case too
  (define result
    (run-ns-last
      (string-append
        "(ns test-d2-e2e5)\n"
        "(spec my-eq2 A A -> Bool where (Eq A))\n"
        "(defn my-eq2 [d x y] (d x y))\n"
        "(eval (my-eq2 nat-eq zero (suc zero)))\n")))
  (check-true (string-contains? result "false")))

;; ========================================
;; 4. Edge cases — backward compatibility and conflicts
;; ========================================

(test-case "D2 compat: explicit {C} still works (backward compat)"
  (define-values (_results spec-store)
    (run-ns-with-spec-store
      (string-append
        "(ns test-d2-compat1 :no-prelude)\n"
        "(require [prologos::core::collection-traits :refer [Seqable]])\n"
        "(require [prologos::data::lseq :refer [LSeq]])\n"
        ;; Explicit {C} binder — existing pattern should still work
        "(spec my-explicit ($brace-params C) ($brace-params A)"
        "  (C A) -> (LSeq A) where (Seqable C))\n")))
  (define se (hash-ref spec-store 'my-explicit #f))
  (check-true (spec-entry? se))
  (define binders (spec-entry-implicit-binders se))
  ;; C should still be refined to Type -> Type
  (check-equal? (cdr (assq 'C binders)) '(-> (Type 0) (Type 0)))
  (check-equal? (cdr (assq 'A binders)) '(Type 0)))

(test-case "D2 compat: explicit {C : Type -> Type} + where (Seqable C) — no conflict"
  (define-values (_results spec-store)
    (run-ns-with-spec-store
      (string-append
        "(ns test-d2-compat2 :no-prelude)\n"
        "(require [prologos::core::collection-traits :refer [Seqable]])\n"
        "(require [prologos::data::lseq :refer [LSeq]])\n"
        ;; Explicit kind annotation matching trait kind — should agree
        ;; parse-brace-param-list expects: ($brace-params C : Type -> Type)
        "(spec my-explicit2 ($brace-params C : Type -> Type) ($brace-params A)"
        "  (C A) -> (LSeq A) where (Seqable C))\n")))
  (define se (hash-ref spec-store 'my-explicit2 #f))
  (check-true (spec-entry? se))
  (define binders (spec-entry-implicit-binders se))
  (check-equal? (cdr (assq 'C binders)) '(-> (Type 0) (Type 0))))

(test-case "D2 conflict: explicit wrong kind + where constraint — error"
  ;; If user explicitly writes {C : Type -> Type -> Type} but where (Seqable C)
  ;; expects Type -> Type, should error
  (check-exn exn:fail?
    (lambda ()
      (run-ns-with-spec-store
        (string-append
          "(ns test-d2-conflict :no-prelude)\n"
          "(require [prologos::core::collection-traits :refer [Seqable]])\n"
          "(require [prologos::data::lseq :refer [LSeq]])\n"
          "(spec my-conflict ($brace-params C : Type -> Type -> Type)"
          "  ($brace-params A)"
          "  (C A) -> (LSeq A) where (Seqable C))\n")))))

;; ========================================
;; 5. Metadata :where syntax
;; ========================================

(test-case "D2 metadata: {:where (Seqable C)} — C auto-detected"
  (define-values (_results spec-store)
    (run-ns-with-spec-store
      (string-append
        "(ns test-d2-meta :no-prelude)\n"
        "(require [prologos::core::collection-traits :refer [Seqable]])\n"
        "(require [prologos::data::lseq :refer [LSeq]])\n"
        ;; Use metadata :where instead of inline where
        "(spec my-meta-fn (C A) -> (LSeq A) {:where (Seqable C)})\n")))
  (define se (hash-ref spec-store 'my-meta-fn #f))
  (check-true (spec-entry? se))
  (define binders (spec-entry-implicit-binders se))
  (define c-binder (assq 'C binders))
  (check-true (pair? c-binder))
  (check-equal? (cdr c-binder) '(-> (Type 0) (Type 0))))

(test-case "D2 metadata: {:where (Eq A)} — simple Type-kinded"
  (define-values (_results spec-store)
    (run-ns-with-spec-store
      (string-append
        "(ns test-d2-meta2 :no-prelude)\n"
        "(require [prologos::core::eq-trait :refer [Eq]])\n"
        ;; Metadata :where with Type-kinded constraint
        "(spec my-meta-eq A A -> Bool {:where (Eq A)})\n")))
  (define se (hash-ref spec-store 'my-meta-eq #f))
  (check-true (spec-entry? se))
  (define binders (spec-entry-implicit-binders se))
  (define a-binder (assq 'A binders))
  (check-true (pair? a-binder))
  (check-equal? (cdr a-binder) '(Type 0)))
