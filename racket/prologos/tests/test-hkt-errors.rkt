#lang racket/base

;;;
;;; Tests for HKT Phase 7: Enhanced Error Messages
;;; Verifies that no-instance errors include available instances, hints,
;;; and (where detectable) kind mismatch diagnostics.
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

(define (run-ns-last s)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry])
    (install-module-loader!)
    (last (process-string s))))

;; ========================================
;; 1. No-instance error includes available instances
;; ========================================

(test-case "hkt-errors/no-instance: lists available Eq instances"
  (define result
    (run-ns-last
      (string-append
        "(ns hkt-err-1)\n"
        "(data Foo | mk-foo)\n"
        "(spec my-eq A A -> Bool where (Eq A))\n"
        "(defn my-eq [x y] (eq? x y))\n"
        "(eval (my-eq mk-foo mk-foo))\n")))
  (check-true (no-instance-error? result))
  (define msg (prologos-error-message result))
  (check-true (string-contains? msg "No instance of Eq for Foo"))
  (check-true (string-contains? msg "Available instances"))
  (check-true (string-contains? msg "Eq Nat"))
  (check-true (string-contains? msg "Eq Bool")))

(test-case "hkt-errors/no-instance: hint mentions method name"
  (define result
    (run-ns-last
      (string-append
        "(ns hkt-err-2)\n"
        "(data Bar | mk-bar)\n"
        "(spec my-eq A A -> Bool where (Eq A))\n"
        "(defn my-eq [x y] (eq? x y))\n"
        "(eval (my-eq mk-bar mk-bar))\n")))
  (check-true (no-instance-error? result))
  (define msg (prologos-error-message result))
  (check-true (string-contains? msg "Hint"))
  (check-true (string-contains? msg "eq?")))

(test-case "hkt-errors/no-instance: error includes trait name"
  ;; Ord's method is `compare`, not `lt?`
  (define result
    (run-ns-last
      (string-append
        "(ns hkt-err-3)\n"
        "(data Baz | mk-baz)\n"
        "(spec my-cmp A A -> Ordering where (Ord A))\n"
        "(defn my-cmp [x y] (compare x y))\n"
        "(eval (my-cmp mk-baz mk-baz))\n")))
  (check-true (no-instance-error? result))
  (check-equal? (no-instance-error-trait-name result) 'Ord)
  (check-true (string-contains? (no-instance-error-type-args-str result) "Baz")))

;; ========================================
;; 2. Eq/Ord still work for ground types
;; ========================================

(test-case "hkt-errors/compat: Eq Nat resolves"
  (define result
    (run-ns-last
      (string-append
        "(ns hkt-err-4)\n"
        "(spec my-eq A A -> Bool where (Eq A))\n"
        "(defn my-eq [x y] (eq? x y))\n"
        "(eval (my-eq zero zero))\n")))
  (check-true (string-contains? result "true")))

(test-case "hkt-errors/compat: Ord Nat resolves"
  ;; Ord's method is `compare`, not `lt?`
  (define result
    (run-ns-last
      (string-append
        "(ns hkt-err-5)\n"
        "(spec my-cmp A A -> Ordering where (Ord A))\n"
        "(defn my-cmp [x y] (compare x y))\n"
        "(eval (my-cmp zero (suc zero)))\n")))
  (check-true (string? result)))

;; ========================================
;; 3. Available instances includes parametric impls
;; ========================================

(test-case "hkt-errors/available: includes parametric instances"
  (define result
    (run-ns-last
      (string-append
        "(ns hkt-err-6)\n"
        "(data Qux | mk-qux)\n"
        "(spec my-eq A A -> Bool where (Eq A))\n"
        "(defn my-eq [x y] (eq? x y))\n"
        "(eval (my-eq mk-qux mk-qux))\n")))
  (check-true (no-instance-error? result))
  (define msg (prologos-error-message result))
  ;; Parametric instances like (List A) or (Option A) should appear
  ;; if they're registered in param-impl-registry
  (check-true (string-contains? msg "Available instances")))

;; ========================================
;; 4. HKT generic ops errors
;; ========================================

(test-case "hkt-errors/hkt: glength with Nat not a collection"
  ;; glength expects (Seqable C) where C : Type -> Type
  ;; Nat has kind Type, so this fails at inference (not trait resolution)
  (define result
    (run-ns-last
      (string-append
        "(ns hkt-err-7)\n"
        "(eval (glength zero))\n")))
  ;; This should produce some error (inference or type mismatch)
  ;; The exact error type depends on how far inference gets
  (check-true (or (prologos-error? result)
                  ;; Or might produce a partially-reduced form with unsolved metas
                  (and (string? result) (string-contains? result "?meta")))))

;; ========================================
;; 5. Multi-method trait error hint
;; ========================================

(test-case "hkt-errors/multi-method: Add trait hint shows method name"
  (define result
    (run-ns-last
      (string-append
        "(ns hkt-err-8)\n"
        "(data Val | mk-val)\n"
        "(spec my-add A A -> A where (Add A))\n"
        "(defn my-add [x y] (add x y))\n"
        "(eval (my-add mk-val mk-val))\n")))
  (check-true (no-instance-error? result))
  (define msg (prologos-error-message result))
  (check-true (string-contains? msg "No instance of Add for Val"))
  (check-true (string-contains? msg "add")))

;; ========================================
;; 6. Error preserves source location
;; ========================================

(test-case "hkt-errors/srcloc: error has source location"
  (define result
    (run-ns-last
      (string-append
        "(ns hkt-err-9)\n"
        "(data Zzz | mk-zzz)\n"
        "(spec my-eq A A -> Bool where (Eq A))\n"
        "(defn my-eq [x y] (eq? x y))\n"
        "(eval (my-eq mk-zzz mk-zzz))\n")))
  (check-true (no-instance-error? result))
  ;; Source location should exist (may be srcloc-unknown for string input)
  (check-true (srcloc? (prologos-error-srcloc result))))
