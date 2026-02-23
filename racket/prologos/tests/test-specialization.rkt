#lang racket/base

;;;
;;; Tests for HKT Phase 8: Specialization Framework
;;; Verifies the `specialize` macro, specialization registry, and
;;; correctness of specialized function definitions.
;;;

(require rackunit
         racket/list
         racket/path
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
;; Helpers
;; ========================================

(define (run-ns-last s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-specialization-registry (current-specialization-registry)])
    (install-module-loader!)
    (last (process-string s))))

;; ========================================
;; 1. Unit tests — process-specialize parsing
;; ========================================

(test-case "specialize/parse: basic specialize form"
  (parameterize ([current-specialization-registry (hash)])
    (define defs
      (process-specialize
        '(specialize gmap for List
           (defn gmap [f xs] (list-map f xs)))))
    ;; Should produce one defn form with specialized name
    (check-equal? (length defs) 1)
    (define d (car defs))
    (check-equal? (car d) 'defn)
    (check-equal? (cadr d) 'gmap--List--specialized)
    ;; Registry should have the entry
    (define entry (lookup-specialization 'gmap 'List))
    (check-not-false entry)
    (check-equal? (specialization-entry-generic-name entry) 'gmap)
    (check-equal? (specialization-entry-type-con entry) 'List)
    (check-equal? (specialization-entry-specialized-name entry)
                  'gmap--List--specialized)))

(test-case "specialize/parse: PVec specialization"
  (parameterize ([current-specialization-registry (hash)])
    (define defs
      (process-specialize
        '(specialize gmap for PVec
           (defn gmap [f v] (pvec-map f v)))))
    (check-equal? (length defs) 1)
    (check-equal? (cadr (car defs)) 'gmap--PVec--specialized)
    (define entry (lookup-specialization 'gmap 'PVec))
    (check-not-false entry)
    (check-equal? (specialization-entry-specialized-name entry)
                  'gmap--PVec--specialized)))

(test-case "specialize/parse: error on missing 'for' keyword"
  (parameterize ([current-specialization-registry (hash)])
    (check-exn exn:fail?
      (lambda ()
        (process-specialize
          '(specialize gmap List (defn gmap [f xs] body)))))))

(test-case "specialize/parse: error on missing body"
  (parameterize ([current-specialization-registry (hash)])
    (check-exn exn:fail?
      (lambda ()
        (process-specialize
          '(specialize gmap for List))))))

;; ========================================
;; 2. Registry lookup tests
;; ========================================

(test-case "specialize/registry: multiple registrations"
  (parameterize ([current-specialization-registry (hash)])
    (process-specialize
      '(specialize gmap for List
         (defn gmap [f xs] (list-map f xs))))
    (process-specialize
      '(specialize gmap for PVec
         (defn gmap [f v] (pvec-map f v))))
    (process-specialize
      '(specialize gfilter for List
         (defn gfilter [p xs] (list-filter p xs))))
    ;; All three lookups should succeed
    (check-not-false (lookup-specialization 'gmap 'List))
    (check-not-false (lookup-specialization 'gmap 'PVec))
    (check-not-false (lookup-specialization 'gfilter 'List))
    ;; Non-existent lookup returns #f
    (check-false (lookup-specialization 'gmap 'Set))
    (check-false (lookup-specialization 'gfold 'List))))

(test-case "specialize/registry: entries are distinct"
  (parameterize ([current-specialization-registry (hash)])
    (process-specialize
      '(specialize gmap for List
         (defn gmap [f xs] (list-map f xs))))
    (process-specialize
      '(specialize gmap for PVec
         (defn gmap [f v] (pvec-map f v))))
    (define e1 (lookup-specialization 'gmap 'List))
    (define e2 (lookup-specialization 'gmap 'PVec))
    (check-not-equal? (specialization-entry-specialized-name e1)
                      (specialization-entry-specialized-name e2))))

;; ========================================
;; 3. End-to-end: specialized function compiles
;; ========================================

(test-case "specialize/e2e: sexp-mode specialize compiles"
  ;; In sexp mode (no WS reader), the specialize form works end-to-end.
  ;; The specialized defn gets its type via spec injection.
  (define result
    (run-ns-last
      (string-append
        "(ns spec-e2e-1 :no-prelude)\n"
        "(data Nat | zero | (suc Nat))\n"
        "(spec my-inc Nat -> Nat)\n"
        "(defn my-inc [x] (suc x))\n"
        "(spec my-inc--Nat--specialized Nat -> Nat)\n"
        "(specialize my-inc for Nat\n"
        "  (defn my-inc [x] (suc x)))\n"
        "(eval (my-inc--Nat--specialized zero))\n")))
  ;; Should get "1N : Nat" back (pretty-printed Nat literal)
  (check-true (string? result))
  (check-true (string-contains? result "Nat")))

(test-case "specialize/e2e: WS-mode specialize form"
  ;; In WS mode (ns triggers prelude), the specialize form should
  ;; at minimum not crash. The generated defn needs a spec to compile.
  (define result
    (run-ns-last
      (string-append
        "(ns spec-e2e-2)\n"
        "(spec my-double Nat -> Nat)\n"
        "(defn my-double [x] (add x x))\n"
        "(spec my-double--Nat--specialized Nat -> Nat)\n"
        "(specialize my-double for Nat\n"
        "  (defn my-double [x] (add x x)))\n"
        "(eval (my-double--Nat--specialized (suc zero)))\n")))
  (check-true (string? result)))

(test-case "specialize/e2e: registry persists across module processing"
  ;; Verify that after processing a module with specialize forms,
  ;; the registry has the correct entries
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-specialization-registry (current-specialization-registry)])
    (install-module-loader!)
    (process-string
      (string-append
        "(ns spec-e2e-3)\n"
        "(spec my-fn Nat -> Nat)\n"
        "(defn my-fn [x] x)\n"
        "(specialize my-fn for Nat\n"
        "  (defn my-fn [x] x))\n"))
    ;; Check that the registry entry persists
    (check-not-false (lookup-specialization 'my-fn 'Nat))))
