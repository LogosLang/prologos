#lang racket/base

;;;
;;; Tests for HKT Phase 6c: Generic Collection Operations
;;; Verifies that gmap, gfilter, gfold, glength, gconcat, gany?, gall?, gto-list
;;; dispatch correctly across collection types via HKT trait resolution.
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         racket/port
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
;; Helpers
;; ========================================

(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry])
    (install-module-loader!)
    (process-string s)))

(define (run-ns-last s)
  (last (run-ns s)))

;; Generic ops preamble — defines all generic functions inline.
;; NOTE: generic-ops.prologos IS now in the prelude (namespace.rkt Tier 3d).
;; These inline definitions are kept for test isolation and explicit dict passing.
;; Uses sexp-mode parens for inline constraint syntax.
(define gen-ops-preamble
  (string-append
    "(spec gmap {A B : Type} {C : Type -> Type} (Seqable C) -> (Buildable C) -> (-> A B) -> (C A) -> (C B))\n"
    "(defn gmap [$seq $build f xs] (Buildable-from-seq $build B (lseq-map A B f ($seq A xs))))\n"
    "(spec gfilter {A : Type} {C : Type -> Type} (Seqable C) -> (Buildable C) -> (-> A Bool) -> (C A) -> (C A))\n"
    "(defn gfilter [$seq $build pred xs] (Buildable-from-seq $build A (lseq-filter A pred ($seq A xs))))\n"
    "(spec gfold {A B : Type} {C : Type -> Type} (Foldable C) -> (-> A (-> B B)) -> B -> (C A) -> B)\n"
    "(defn gfold [$foldable f z xs] ($foldable A B f z xs))\n"
    "(spec glength {A : Type} {C : Type -> Type} (Seqable C) -> (C A) -> Nat)\n"
    "(defn glength [$seq xs] (lseq-length ($seq A xs)))\n"
    "(spec gconcat {A : Type} {C : Type -> Type} (Seqable C) -> (Buildable C) -> (C A) -> (C A) -> (C A))\n"
    "(defn gconcat [$seq $build xs ys] (Buildable-from-seq $build A (lseq-append A ($seq A xs) ($seq A ys))))\n"
    "(spec gany? {A : Type} {C : Type -> Type} (Foldable C) -> (-> A Bool) -> (C A) -> Bool)\n"
    "(defn gany? [$foldable pred xs] ($foldable A Bool (fn [a] [acc] (if (pred a) true acc)) false xs))\n"
    "(spec gall? {A : Type} {C : Type -> Type} (Foldable C) -> (-> A Bool) -> (C A) -> Bool)\n"
    "(defn gall? [$foldable pred xs] ($foldable A Bool (fn [a] [acc] (if (pred a) acc false)) true xs))\n"
    "(spec gto-list {A : Type} {C : Type -> Type} (Seqable C) -> (C A) -> (List A))\n"
    "(defn gto-list [$seq xs] (lseq-to-list ($seq A xs)))\n"))


;; ========================================
;; 1. Generic ops define successfully
;; ========================================

(test-case "generic-ops/define: all ops type-check"
  (define results
    (run-ns
      (string-append "(ns go-def-1)\n" gen-ops-preamble)))
  ;; All definitions should succeed (no error structs)
  (for ([r (in-list results)])
    (check-true (string? r)
                (format "Expected string result, got ~a" r))))


;; ========================================
;; 2. gmap on List
;; ========================================

(test-case "generic-ops/gmap: List singleton"
  (define result
    (run-ns-last
      (string-append
        "(ns go-gmap-1)\n"
        gen-ops-preamble
        "(spec inc Nat -> Nat)\n"
        "(defn inc [x] (suc x))\n"
        "(eval (gmap inc '[0N]))\n")))
  (check-true (string-contains? result "'[1N]")))


(test-case "generic-ops/gmap: List multiple"
  (define result
    (run-ns-last
      (string-append
        "(ns go-gmap-2)\n"
        gen-ops-preamble
        "(spec inc Nat -> Nat)\n"
        "(defn inc [x] (suc x))\n"
        "(eval (gmap inc '[0N 1N 2N]))\n")))
  (check-true (string-contains? result "'[1N 2N 3N]")))


(test-case "generic-ops/gmap: List empty"
  (define result
    (run-ns-last
      (string-append
        "(ns go-gmap-3)\n"
        gen-ops-preamble
        "(spec inc Nat -> Nat)\n"
        "(defn inc [x] (suc x))\n"
        "(eval (gmap inc (nil Nat)))\n")))
  (check-true (string-contains? result "nil")))


;; ========================================
;; 3. glength on List
;; ========================================

