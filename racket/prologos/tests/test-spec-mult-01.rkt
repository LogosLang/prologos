#lang racket/base

;;;
;;; test-spec-mult-01.rkt -- Spec/defn multiplicity arrow tests
;;;
;;; Tests that -1>, -0>, -w> in spec declarations correctly propagate
;;; multiplicity into defn parameters via inject-spec-into-defn.
;;;
;;; Group 1: Spec with multiplicity arrows — basic parsing
;;; Group 2: QTT enforcement via spec -1> arrows
;;; Group 3: Mixed multiplicities and edge cases
;;; Group 4: fio.prologos rewrite verification
;;;
;;; Pattern: Shared fixture with process-string + prelude.
;;;

(require rackunit
         racket/list
         racket/string
         racket/file
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
         "../namespace.rkt"
         "../multi-dispatch.rkt")

;; ========================================
;; Shared Fixture (prelude + Handle type)
;; ========================================

(define shared-preamble
  "(ns test-spec-mult)
(data Handle (mk-handle : Nat))")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-ctor-reg
                shared-type-meta)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
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
    (values (current-global-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-ctor-registry)
            (current-type-meta))))

(define (run s)
  (parameterize ([current-global-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-ctor-registry shared-ctor-reg]
                 [current-type-meta shared-type-meta])
    (process-string s)))

(define (run-last s) (last (run s)))
(define (run-first s) (first (run s)))

;; ========================================
;; Group 1: Spec with multiplicity arrows — basic parsing
;; ========================================

(test-case "spec-mult: -1> arrow creates linear parameter"
  ;; spec with -1> should make the parameter linear;
  ;; a defn that uses the parameter exactly once should type-check.
  (define result
    (run-first
     "(spec consume Handle -1> Unit)
      (defn consume [h] (match h (mk-handle idx -> unit)))"))
  (check-true (string-contains? result "defined")
              "spec with -1> + linear usage should type-check"))

(test-case "spec-mult: -0> arrow creates erased parameter"
  ;; spec with -0> should make the parameter erased;
  ;; a defn that doesn't use the erased param should type-check.
  (define result
    (run-first
     "(spec type-tag Type -0> Nat)
      (defn type-tag [t] zero)"))
  (check-true (string-contains? result "defined")
              "spec with -0> + unused erased param should type-check"))

(test-case "spec-mult: plain -> works unchanged"
  ;; Regression: plain -> should still work (unrestricted by default).
  (define result
    (run-first
     "(spec identity Handle -> Handle)
      (defn identity [h] h)"))
  (check-true (string-contains? result "defined")
              "spec with plain -> should type-check"))

(test-case "spec-mult: -1> with eval produces correct result"
  ;; Verify that a -1> spec function actually runs correctly.
  (define result
    (run-last
     "(spec extract Handle -1> Nat)
      (defn extract [h] (match h (mk-handle idx -> idx)))
      (eval (extract (mk-handle (suc (suc zero)))))"))
  (check-equal? result "2N : Nat"))

;; ========================================
;; Group 2: QTT enforcement via spec -1>
;; ========================================

(test-case "spec-mult: -1> unused param produces multiplicity error"
  ;; Negative: function declared with -1> but doesn't use the linear handle.
  (define result
    (run-first
     "(spec leak Handle -1> Unit)
      (defn leak [h] unit)"))
  (check-true (multiplicity-error? result)
              "unused linear handle via -1> spec should produce multiplicity error"))

(test-case "spec-mult: -1> double-use produces multiplicity error"
  ;; Negative: function declared with -1> duplicates the handle via pair.
  (define result
    (run-first
     "(spec double-use Handle -1> <Handle * Handle>)
      (defn double-use [h] (pair h h))"))
  (check-true (multiplicity-error? result)
              "double-use of linear handle via -1> spec should produce multiplicity error"))

(test-case "spec-mult: -1> used exactly once type-checks"
  ;; Positive: function declared with -1> uses the handle exactly once.
  (define result
    (run-first
     "(spec close-it Handle -1> Unit)
      (defn close-it [h] (match h (mk-handle idx -> unit)))"))
  (check-true (string-contains? result "defined")
              "linear handle via -1> used once should type-check"))

;; ========================================
;; Group 3: Mixed multiplicities and edge cases
;; ========================================

(test-case "spec-mult: mixed -1> and -> in multi-param spec"
  ;; First param linear, second unrestricted.
  (define result
    (run-first
     "(spec use-both Handle -1> String -> Nat)
      (defn use-both [h s] (match h (mk-handle idx -> idx)))"))
  (check-true (string-contains? result "defined")
              "mixed -1> and -> should type-check"))

(test-case "spec-mult: mixed -1> and -> enforces linearity on first param"
  ;; First param is linear but unused → error.
  (define result
    (run-first
     "(spec bad-mix Handle -1> String -> Nat)
      (defn bad-mix [h s] zero)"))
  (check-true (multiplicity-error? result)
              "unused linear first param in mixed spec should produce multiplicity error"))

(test-case "spec-mult: -0> param cannot be used at runtime"
  ;; Erased param used at runtime → multiplicity error.
  (define result
    (run-first
     "(spec bad-erase Nat -0> Nat)
      (defn bad-erase [n] n)"))
  (check-true (multiplicity-error? result)
              "erased param used at runtime should produce multiplicity error"))

(test-case "spec-mult: -1> with implicit type params"
  ;; {A} implicit type param + linear arrow on concrete type.
  ;; A is used for the second (unrestricted) param; Handle is linear.
  (define result
    (run-first
     "(spec wrap-linear {A : Type} Handle -1> A -> Nat)
      (defn wrap-linear [h a] (match h (mk-handle idx -> idx)))"))
  (check-true (string-contains? result "defined")
              "-1> with implicit type params should type-check"))

;; ========================================
;; Group 4: fio.prologos rewrite verification
;; ========================================

(test-case "spec-mult: fio module loads with spec/defn forms"
  ;; Verify the fio module (rewritten with spec/defn) loads without error.
  (define results
    (run "(imports (prologos::core::fio :refer (Handle mk-handle fio-open fio-read-all fio-write fio-close fio-with-file)))"))
  (check-true (andmap (lambda (r) (not (prologos-error? r))) results)
              "fio module should load without errors"))

(test-case "spec-mult: fio bracket lifecycle after spec/defn rewrite"
  ;; Full bracket lifecycle: open → read → close via fio-with-file.
  ;; Note: import fio's Handle (not fixture's) via :refer; use
  ;; prologos::core::fio::Handle in the fn annotation to avoid
  ;; namespace conflict with the fixture's Handle type.
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "spec-mult read test" out))
    #:exists 'truncate/replace)
  (define result
    (run-last
     (format "(imports (prologos::core::fio :refer (Handle fio-with-file fio-read-all)))
              (eval (fio-with-file ~s \"read\" (fn [h <prologos::core::fio::Handle>] (fio-read-all h))))"
             (path->string tmp))))
  (check-equal? result "\"spec-mult read test\" : String")
  (delete-file tmp))
