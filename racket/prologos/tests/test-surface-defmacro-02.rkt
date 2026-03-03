#lang racket/base

;;;
;;; Tests for surface-level defmacro: WS-mode macros, cross-module import,
;;; pattern language features, private macros, error cases.
;;;

(require rackunit
         racket/path
         racket/string
         racket/list
         "test-support.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../macros.rkt"
         "../metavar-store.rkt")

;; Helper: run prologos code with namespace system active
(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry])
    (install-module-loader!)
    (process-string s)))

;; Helper: run code and return the last result line
(define (run-last s)
  (last (run-ns s)))


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
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry])
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
                            "(imports (prologos::data::nat :refer (add)))\n"
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
                            "(imports (prologos::data::nat :refer (add)))\n"
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
