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


(test-case "generic-ops/compat: existing list ops"
  (define result
    (run-ns-last
      (string-append
        "(ns go-compat-2)\n"
        "(eval (length '[1N 2N 3N]))\n")))
  (check-equal? result "3N : Nat"))


(test-case "generic-ops/compat: explicit trait accessor"
  (define result
    (run-ns-last
      (string-append
        "(ns go-compat-3)\n"
        "(eval (Eq-eq? Nat Nat--Eq--dict zero zero))\n")))
  (check-equal? result "true : Bool"))


;; ========================================
;; 9. Prelude integration (HKT-6d)
;; ========================================

(test-case "generic-ops/prelude: gmap from prelude"
  (define result
    (run-ns-last
      (string-append
        "(ns go-prelude-1)\n"
        "(spec inc Nat -> Nat)\n"
        "(defn inc [x] (suc x))\n"
        "(eval (gmap inc '[0N 1N]))\n")))
  (check-true (string-contains? result "'[1N 2N]")))


(test-case "generic-ops/prelude: glength from prelude"
  (define result
    (run-ns-last
      (string-append
        "(ns go-prelude-2)\n"
        "(eval (glength '[0N 1N 2N]))\n")))
  (check-equal? result "3N : Nat"))


(test-case "generic-ops/prelude: gfold sum from prelude"
  (define result
    (run-ns-last
      (string-append
        "(ns go-prelude-3)\n"
        "(eval (gfold (fn [x] [acc] (add acc x)) zero '[1N 2N 3N]))\n")))
  (check-equal? result "6N : Nat"))


(test-case "generic-ops/prelude: gto-list from prelude"
  (define result
    (run-ns-last
      (string-append
        "(ns go-prelude-4)\n"
        "(eval (gto-list '[0N]))\n")))
  (check-true (string-contains? result "'[0N]")))


(test-case "generic-ops/prelude: gfilter from prelude"
  (define result
    (run-ns-last
      (string-append
        "(ns go-prelude-5)\n"
        "(eval (gfilter zero? '[0N 1N 0N]))\n")))
  (check-true (string-contains? result "'[0N 0N]")))


(test-case "generic-ops/prelude: gconcat from prelude"
  (define result
    (run-ns-last
      (string-append
        "(ns go-prelude-6)\n"
        "(eval (gconcat '[1N] '[2N]))\n")))
  (check-true (string-contains? result "'[1N 2N]")))


(test-case "generic-ops/prelude: gany? from prelude"
  (define result
    (run-ns-last
      (string-append
        "(ns go-prelude-7)\n"
        "(eval (gany? zero? '[0N 1N]))\n")))
  (check-true (string-contains? result "true")))


(test-case "generic-ops/prelude: gall? from prelude"
  (define result
    (run-ns-last
      (string-append
        "(ns go-prelude-8)\n"
        "(eval (gall? zero? '[0N 1N]))\n")))
  (check-true (string-contains? result "false")))
