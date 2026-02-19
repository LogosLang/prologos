#lang racket/base

;;;
;;; Tests for surface-level defmacro: WS-mode macros, cross-module import,
;;; pattern language features, private macros, error cases.
;;;

(require rackunit
         racket/path
         racket/string
         racket/list
         "../driver.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../macros.rkt"
         "../metavar-store.rkt")

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

;; ========================================
;; 2a. Core macro smoke tests
;; ========================================

(test-case "core-macro/twice-suc"
  ;; twice suc zero → suc(suc(zero)) = 2
  (check-equal?
   (run-last "(ns dm1)\n(eval (the Nat (twice suc zero)))")
   "2N : Nat"))

(test-case "core-macro/pipe2"
  ;; pipe2 zero suc suc → suc(suc(zero)) = 2
  (check-equal?
   (run-last "(ns dm2)\n(eval (the Nat (pipe2 zero suc suc)))")
   "2N : Nat"))

(test-case "core-macro/pipe3"
  ;; pipe3 zero suc suc suc → suc(suc(suc(zero))) = 3
  (check-equal?
   (run-last "(ns dm3)\n(eval (the Nat (pipe3 zero suc suc suc)))")
   "3N : Nat"))

(test-case "core-macro/when-true"
  ;; when true unit → if true unit unit → unit
  (check-equal?
   (run-last "(ns dm4)\n(eval (the Unit (when true unit)))")
   "unit : Unit"))

(test-case "core-macro/unless-false"
  ;; unless false unit → if false unit unit → unit
  (check-equal?
   (run-last "(ns dm5)\n(eval (the Unit (unless false unit)))")
   "unit : Unit"))

;; ========================================
;; 2b. Inline defmacro in WS mode
;; ========================================

(test-case "inline-macro/inc2"
  ;; defmacro inc2 — increment twice
  (check-equal?
   (run-last "(ns dm6)\n(defmacro inc2 ($x) (suc (suc $x)))\n(eval (the Nat (inc2 zero)))")
   "2N : Nat"))

(test-case "inline-macro/constant"
  ;; defmacro with no pattern vars — constant replacement
  (check-equal?
   (run-last "(ns dm7)\n(defmacro my-zero () zero)\n(eval (the Nat (my-zero)))")
   "0N : Nat"))

(test-case "inline-macro/chain"
  ;; macro calling macro: inc2 then inc4
  (check-equal?
   (run-last (string-append "(ns dm8)\n"
                            "(defmacro inc2 ($x) (suc (suc $x)))\n"
                            "(defmacro inc4 ($x) (inc2 (inc2 $x)))\n"
                            "(eval (the Nat (inc4 zero)))"))
   "4N : Nat"))

(test-case "inline-macro/multi-arg"
  ;; defmacro with multiple arguments
  (check-equal?
   (run-last (string-append "(ns dm9)\n"
                            "(require (prologos.data.nat :refer (add)))\n"
                            "(defmacro add3 ($a $b $c) (add $a (add $b $c)))\n"
                            "(eval (add3 (the Nat (suc zero)) (the Nat (suc zero)) (the Nat (suc zero))))"))
   "3N : Nat"))

(test-case "inline-macro/apply2"
  ;; macro that applies a function to two arguments
  (check-equal?
   (run-last (string-append "(ns dm10)\n"
                            "(require (prologos.data.nat :refer (add)))\n"
                            "(defmacro apply2 ($f $x $y) ($f $x $y))\n"
                            "(eval (apply2 add (the Nat (suc zero)) (the Nat (suc zero))))"))
   "2N : Nat"))

(test-case "inline-macro/nested-body"
  ;; macro with nested expression in body
  (check-equal?
   (run-last (string-append "(ns dm11)\n"
                            "(defmacro suc3 ($x) (suc (suc (suc $x))))\n"
                            "(eval (the Nat (suc3 zero)))"))
   "3N : Nat"))

;; ========================================
;; 2c. Cross-module macro import
;; ========================================

(test-case "cross-module/twice-auto-import"
  ;; core macros are auto-imported via prologos.core
  ;; twice should be available without explicit require
  (check-equal?
   (run-last "(ns dm12)\n(eval (the Nat (twice suc zero)))")
   "2N : Nat"))

(test-case "cross-module/pipe2-auto-import"
  ;; pipe2 should be available via auto-imported core
  (check-equal?
   (run-last "(ns dm13)\n(eval (the Nat (pipe2 zero suc suc)))")
   "2N : Nat"))

(test-case "cross-module/when-auto-import"
  ;; when should be available via auto-imported core
  (check-equal?
   (run-last "(ns dm14)\n(eval (the Unit (when true unit)))")
   "unit : Unit"))

;; ========================================
;; 2d. Private macros
;; ========================================

(test-case "private-macro/defmacro-minus"
  ;; defmacro- defines a macro that works locally
  (check-equal?
   (run-last (string-append "(ns dm15)\n"
                            "(defmacro- my-suc ($x) (suc $x))\n"
                            "(eval (the Nat (my-suc zero)))"))
   "1N : Nat"))

(test-case "private-macro/not-exported"
  ;; defmacro- should NOT add to auto-exports
  ;; We verify by checking that the macro works locally (test above)
  ;; but isn't in auto-exports. This is a structural test.
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)])
    (install-module-loader!)
    ;; Process a namespace with a private macro
    (process-string (string-append "(ns dm16)\n"
                                   "(defmacro- secret-suc ($x) (suc $x))\n"
                                   "(def pub : Nat (secret-suc zero))"))
    ;; Check auto-exports: 'pub should be there but 'secret-suc should not
    (define ctx (current-ns-context))
    (when ctx
      (define autos (ns-context-auto-exports ctx))
      (check-not-false (memq 'pub autos))
      (check-false (memq 'secret-suc autos)))))

;; ========================================
;; 2e. Pattern language features
;; ========================================

(test-case "pattern/recursive-macro-use"
  ;; Macro applied recursively (calling a macro-defined form multiple times)
  (check-equal?
   (run-last (string-append "(ns dm17)\n"
                            "(defmacro wrap-suc ($x) (suc $x))\n"
                            "(eval (the Nat (wrap-suc (wrap-suc zero))))"))
   "2N : Nat"))

(test-case "pattern/multi-use-same-var"
  ;; Pattern variable used multiple times in template
  (check-equal?
   (run-last (string-append "(ns dm18)\n"
                            "(require (prologos.data.nat :refer (add)))\n"
                            "(defmacro double-add ($x) (add $x $x))\n"
                            "(eval (double-add (the Nat (suc zero))))"))
   "2N : Nat"))

(test-case "pattern/ellipsis-rest"
  ;; Rest capture with ... — works at the datum level
  ;; (defmacro first-of ($x $rest ...) $x)
  (check-equal?
   (run-last (string-append "(ns dm19)\n"
                            "(defmacro first-of ($x $rest ...) $x)\n"
                            "(eval (the Nat (first-of zero (suc zero) (suc (suc zero)))))"))
   "0N : Nat"))

(test-case "pattern/ellipsis-splice"
  ;; Splice rest args into template
  ;; (defmacro call-with ($f $args ...) ($f $args ...))
  (check-equal?
   (run-last (string-append "(ns dm20)\n"
                            "(require (prologos.data.nat :refer (add)))\n"
                            "(defmacro call-with ($f $args ...) ($f $args ...))\n"
                            "(eval (call-with add (the Nat (suc zero)) (the Nat (suc zero))))"))
   "2N : Nat"))

;; ========================================
;; 2f. when/unless with Unit type
;; ========================================

(test-case "when/true-unit"
  (check-equal?
   (run-last "(ns dm21)\n(eval (the Unit (when true unit)))")
   "unit : Unit"))

(test-case "when/false-unit"
  ;; when false → unit (the else branch)
  (check-equal?
   (run-last "(ns dm22)\n(eval (the Unit (when false unit)))")
   "unit : Unit"))

(test-case "unless/true-unit"
  ;; unless true → unit (the then branch is unit)
  (check-equal?
   (run-last "(ns dm23)\n(eval (the Unit (unless true unit)))")
   "unit : Unit"))

(test-case "unless/false-unit"
  (check-equal?
   (run-last "(ns dm24)\n(eval (the Unit (unless false unit)))")
   "unit : Unit"))

;; ========================================
;; 2g. Error cases
;; ========================================

(test-case "defmacro/malformed-error"
  ;; Missing template
  (check-exn exn:fail?
    (lambda ()
      (run-ns "(ns dm25)\n(defmacro (bad))"))))

(test-case "defmacro/infinite-loop-error"
  ;; Macro that expands to itself → depth limit error
  (check-exn exn:fail?
    (lambda ()
      (run-ns "(ns dm26)\n(defmacro loop ($x) (loop $x))\n(eval (loop zero))"))))

;; ========================================
;; 2h. Macro + type checking
;; ========================================

(test-case "macro/type-check-twice"
  ;; twice suc zero type-checks as Nat (check returns "OK")
  (check-equal?
   (run-last "(ns dm27)\n(check (twice suc zero) : Nat)")
   "OK"))

(test-case "macro/type-check-pipe2"
  ;; pipe2 with typed functions type-checks
  (check-equal?
   (run-last "(ns dm28)\n(check (pipe2 zero suc suc) : Nat)")
   "OK"))

(test-case "macro/type-check-when"
  ;; when in checking context type-checks
  (check-equal?
   (run-last "(ns dm29)\n(check (when true unit) : Unit)")
   "OK"))

(test-case "macro/expansion-visible"
  ;; Use expand command to see the macro expansion
  (define results
    (run-ns "(ns dm30)\n(defmacro my-double ($x) (suc (suc $x)))\n(expand (my-double zero))"))
  ;; expand should show the expanded form
  (check-true (> (length results) 0)))
