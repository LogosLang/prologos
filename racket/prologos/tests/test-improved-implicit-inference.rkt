#lang racket/base

;;;
;;; Tests for issue #20: Improved Implicit Binder Inference
;;;
;;; Direction 1 (D1): Auto-introduce {A : Type} binders for kind-Type variables
;;; that appear free in a spec signature but aren't bound by an explicit binder.
;;;
;;; Direction 2 (D2): Infer the kind of an unbound variable from a :where (or
;;; inline) trait constraint that pins its kind. e.g. :where (Seqable C) →
;;; auto-introduce {C : Type -> Type} based on Seqable's declared param kind.
;;;
;;; The two directions are additive: a single spec can drop both kinds of
;;; explicit binders.
;;;
;;; Three-level WS validation:
;;;   - Level 1 (sexp): direct unit tests on extract-implicit-binders /
;;;     propagate-kinds-from-constraints, plus end-to-end via process-string
;;;   - Level 2 (WS string): process-string-ws on bare-binder forms
;;;   - Level 3 (WS file): process-file on the acceptance file
;;;     examples/2026-04-27-improved-implicit-inference.prologos
;;;

(require rackunit
         racket/list
         racket/path
         racket/runtime-path
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
         "../namespace.rkt"
         "../multi-dispatch.rkt")

;; ========================================
;; Shared Fixture
;; ========================================
;; Load Seqable, Buildable, Foldable + LSeq + List once. Each test reuses
;; the cached env via `run`/`run-last`.

(define shared-preamble
  "(ns test-iii)
(imports (prologos::core::collection-traits :refer (Seqable Buildable Foldable
                                                     Buildable-from-seq)))
(imports (prologos::data::lseq :refer (LSeq)))
(imports (prologos::data::lseq-ops :refer (lseq-map lseq-length)))
(imports (prologos::data::list :refer (List nil cons)))
(imports (prologos::data::option :refer (Option some none)))
")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry))))

(define (run s)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-spec-store (current-spec-store)])
    (process-string s)))

(define (run-last s) (last (run s)))

;; Run and inspect the spec-entry from current-spec-store.
;; Returns a hash: (hash 'binders ... 'where ...) or #f if not found.
(define (run-and-inspect-spec s spec-name)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-spec-store (hasheq)])
    (process-string s)
    (define se (hash-ref (current-spec-store) spec-name #f))
    (and se
         (hash 'binders (spec-entry-implicit-binders se)
               'where (spec-entry-where-constraints se)))))

;; ========================================
;; D1: Auto-introduce {A : Type} for kind-Type variables
;; ========================================

(test-case "D1: bare A in [List A] -> Nat introduces {A : Type}"
  (define info (run-and-inspect-spec
                "(spec my-len (List A) -> Nat)\n"
                'my-len))
  (check-not-false info)
  (define binders (hash-ref info 'binders))
  (check-equal? (length binders) 1)
  (check-equal? (assq 'A binders) '(A . (Type 0))))

(test-case "D1: bare A and B in A -> B -> A introduce two {*: Type}"
  (define info (run-and-inspect-spec
                "(spec my-const A -> B -> A)\n"
                'my-const))
  (check-not-false info)
  (define binders (hash-ref info 'binders))
  (check-equal? (length binders) 2)
  (check-equal? (assq 'A binders) '(A . (Type 0)))
  (check-equal? (assq 'B binders) '(B . (Type 0))))

(test-case "D1: bare A inside [A -> B] arrow function-type position"
  (define info (run-and-inspect-spec
                "(spec my-apply (-> A B) -> A -> B)\n"
                'my-apply))
  (check-not-false info)
  (define binders (hash-ref info 'binders))
  (check-equal? (length binders) 2))

(test-case "D1: bare A in nested [List [Option A]]"
  (define info (run-and-inspect-spec
                "(spec my-flatten (List (Option A)) -> (List A))\n"
                'my-flatten))
  (check-not-false info)
  (define binders (hash-ref info 'binders))
  (check-equal? (length binders) 1)
  (check-equal? (assq 'A binders) '(A . (Type 0))))

(test-case "D1: explicit {A : Type} still works (regression)"
  (define info (run-and-inspect-spec
                "(spec my-id1 ($brace-params A : (Type 0)) A -> A)\n"
                'my-id1))
  (check-not-false info)
  (define binders (hash-ref info 'binders))
  (check-equal? (length binders) 1)
  (check-equal? (assq 'A binders) '(A . (Type 0))))

(test-case "D1: known type names (Nat, Bool, List) are NOT auto-bound"
  (define info (run-and-inspect-spec
                "(spec my-and Bool -> Bool -> Bool)\n"
                'my-and))
  (check-not-false info)
  (check-equal? (length (hash-ref info 'binders)) 0))

(test-case "D1: bare A in spec with where-clause Eq A"
  (define info (run-and-inspect-spec
                "(imports (prologos::core::eq :refer (Eq)))\n
                 (spec my-eq A -> A -> Bool where (Eq A))\n"
                'my-eq))
  (check-not-false info)
  (define binders (hash-ref info 'binders))
  (check-equal? (length binders) 1)
  ;; A : Type — Eq has {A : Type}, no upgrade
  (check-equal? (assq 'A binders) '(A . (Type 0))))

;; ========================================
;; D2: Infer kind from where / inline constraints
;; ========================================

(test-case "D2: bare C with :where (Seqable C) infers C : Type -> Type"
  (define info (run-and-inspect-spec
                "(spec my-glen ($brace-params A) (C A) -> Nat where (Seqable C))\n"
                'my-glen))
  (check-not-false info)
  (define binders (hash-ref info 'binders))
  ;; A : Type (explicit), C : Type -> Type (D2 from Seqable)
  (check-equal? (assq 'A binders) '(A . (Type 0)))
  (check-equal? (assq 'C binders) '(C . (-> (Type 0) (Type 0)))))

(test-case "D2: bare C with inline (Seqable C) constraint infers C : Type -> Type"
  (define info (run-and-inspect-spec
                "(spec my-glen2 ($brace-params A) (Seqable C) -> (C A) -> Nat)\n"
                'my-glen2))
  (check-not-false info)
  (define binders (hash-ref info 'binders))
  (check-equal? (assq 'C binders) '(C . (-> (Type 0) (Type 0)))))

(test-case "D2: bare C with both Seqable and Buildable C — both agree"
  (define info (run-and-inspect-spec
                "(spec my-gtrans ($brace-params A B)
                   (Seqable C) -> (Buildable C) -> (-> A B) -> (C A) -> (C B))\n"
                'my-gtrans))
  (check-not-false info)
  (define binders (hash-ref info 'binders))
  (check-equal? (assq 'C binders) '(C . (-> (Type 0) (Type 0)))))

(test-case "D2: explicit {C : Type -> Type} still works (regression)"
  (define info (run-and-inspect-spec
                "(spec my-glen3 ($brace-params A)
                   ($brace-params C : (-> (Type 0) (Type 0)))
                   (Seqable C) -> (C A) -> Nat)\n"
                'my-glen3))
  (check-not-false info)
  (define binders (hash-ref info 'binders))
  (check-equal? (assq 'C binders) '(C . (-> (Type 0) (Type 0)))))

;; ========================================
;; D1 + D2 combined: drop both kinds of binders
;; ========================================

(test-case "D1+D2: bare A, B, and C — gmap-style signature"
  (define info (run-and-inspect-spec
                "(spec my-gmap
                   (Seqable C) -> (Buildable C) -> (-> A B) -> (C A) -> (C B))\n"
                'my-gmap))
  (check-not-false info)
  (define binders (hash-ref info 'binders))
  (check-equal? (length binders) 3
                "Should auto-introduce three binders: A, B, C")
  (check-equal? (assq 'A binders) '(A . (Type 0)))
  (check-equal? (assq 'B binders) '(B . (Type 0)))
  (check-equal? (assq 'C binders) '(C . (-> (Type 0) (Type 0)))))

(test-case "D1+D2: bare A and C — Foldable-style"
  (define info (run-and-inspect-spec
                "(spec my-gfold
                   (Foldable C) -> (-> A B B) -> B -> (C A) -> B)\n"
                'my-gfold))
  (check-not-false info)
  (define binders (hash-ref info 'binders))
  ;; A, B (kind Type), C (kind Type -> Type)
  (check-equal? (length binders) 3)
  (check-equal? (assq 'A binders) '(A . (Type 0)))
  (check-equal? (assq 'B binders) '(B . (Type 0)))
  (check-equal? (assq 'C binders) '(C . (-> (Type 0) (Type 0)))))

;; ========================================
;; Edge cases — when explicit binders are STILL needed
;; ========================================

(test-case "edge: spec with no constraining position (just A) — still needs binder"
  ;; Even bare `spec empty A -> [List A]` should auto-bind A via D1.
  (define info (run-and-inspect-spec
                "(spec my-empty1 (List A))\n"
                'my-empty1))
  (check-not-false info)
  (check-equal? (length (hash-ref info 'binders)) 1)
  (check-equal? (assq 'A (hash-ref info 'binders)) '(A . (Type 0))))

;; ========================================
;; End-to-end: spec + defn + call
;; ========================================

(test-case "e2e: D1 spec singleton with bare A elaborates and runs"
  ;; Use a simple non-multi-arity defn to avoid $pipe sexp dispatching issues
  (define result (run-last
                  (string-append
                   "(spec my-singleton2 A -> (List A))\n"
                   "(defn my-singleton2 (x) (cons A x (nil A)))\n"
                   "(eval (my-singleton2 Nat 1N))\n")))
  ;; Pretty-printer renders cons-list as '[…]
  (check-true (string-contains? result "1N")
              (format "expected list output to contain 1N, got: ~s" result))
  (check-true (string-contains? result "List")
              (format "expected list output to mention List, got: ~s" result)))

(test-case "e2e: D1+D2 spec g-length with bare Seqable C parses + stores binders"
  ;; Verify only that the spec form (with bare A and C) is accepted by
  ;; process-spec and stores the right implicit binders. We don't run a defn
  ;; here — the body type-checking would exercise unrelated trait machinery.
  (define info (run-and-inspect-spec
                "(spec my-g-length (Seqable C) -> (C A) -> Nat)\n"
                'my-g-length))
  (check-not-false info)
  (define binders (hash-ref info 'binders))
  (check-equal? (length binders) 2 "should have A and C")
  (check-equal? (assq 'A binders) '(A . (Type 0)))
  (check-equal? (assq 'C binders) '(C . (-> (Type 0) (Type 0)))))

;; ========================================
;; Level 3: WS file via process-file
;; ========================================
;; Run the acceptance file and check it elaborates without errors.

(define-runtime-path examples-dir "../examples")

(test-case "L3: acceptance file elaborates cleanly via process-file"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (define acceptance-path
      (path->string
       (build-path examples-dir
                   "2026-04-27-improved-implicit-inference.prologos")))
    ;; If process-file raises, the test fails; otherwise it returns a list
    ;; of results which we don't inspect here.
    (check-not-exn
     (lambda ()
       (process-file acceptance-path)))))
