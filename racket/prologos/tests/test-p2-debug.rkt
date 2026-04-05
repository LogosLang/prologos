#lang racket/base
;;; Debug: test Pattern 2 on the auto-implicit case
(require "../driver.rkt"
         "../typing-propagators.rkt"
         "../propagator.rkt"
         "../syntax.rkt"
         "../type-lattice.rkt"
         "../substitution.rkt"
         "../elab-network-types.rkt"
         "../metavar-store.rkt")

;; Temporarily patch make-app-fire-fn to use Pattern 2 (subst with expr keys)
;; by monkey-patching infer-on-network to use a custom fire fn.
;; Actually, just test the full pipeline and time it.

(define result
  (with-handlers ([exn:fail? (lambda (e) (format "ERROR: ~a" (exn-message e)))])
    (process-string "(ns ai1)\n(defn id [x <A>] <A> x)\n(eval (id zero))")))
(printf "result: ~a\n" result)
