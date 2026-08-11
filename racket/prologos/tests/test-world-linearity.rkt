#lang racket/base

;;; test-world-linearity.rkt — the World token's guarantees, at the type level.
;;;
;;; `prologos::core::world` exists because reduction is lazy in argument
;;; position, so effect ordering is not something the language gives you for
;;; free. The pre-existing answer is to force an effect by MATCHING on its
;;; result, and `emit-after-stash` (interop-driver.prologos) documents that
;;; idiom's fragility at the site: its two arms are deliberately different
;;; because identical arms could be folded away by "any arm-collapsing rewrite
;;; — and folding it away DELETES the stash".
;;;
;;; A World token replaces the idiom with a data dependency. This file asserts
;;; that the dependency is real and that QTT enforces it, and — just as
;;; importantly — pins the ONE case it does not.
;;;
;;; No sockets here. This is about what the type checker accepts and rejects;
;;; test-prologos-echo-server.rkt is what runs the primitives for real.

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
         "../namespace.rkt"
         "../multi-dispatch.rkt")

(define shared-preamble
  "(ns test-world-linearity)
(imports (prologos::core::world :refer-all))
(imports (prologos::io::net :refer-all))
")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-ctor-reg
                shared-type-meta)
  (parameterize ([current-file-module-network-ref (make-module-network)]
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
    (values (global-env-snapshot)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-ctor-registry)
            (current-type-meta))))

(define (run s)
  (parameterize ([current-file-module-network-ref
                  (module-network-add-import (make-module-network)
                                             (module-network-from-snapshot shared-global-env))]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-ctor-registry shared-ctor-reg]
                 [current-type-meta shared-type-meta])
    (process-string s)))

(define (run-last s)
  (define r (run s))
  (if (null? r) "" (last r)))

;; A multiplicity violation, as a string, or #f if the form was accepted.
(define (mult-error s)
  (define r (run-last s))
  (and (not (string? r))
       (let ([m (format "~s" r)])
         (and (regexp-match? #rx"multiplicity-error" m) m))))

;; ------------------------------------------------------------------
;; The token itself
;; ------------------------------------------------------------------

(test-case "the initial world starts the clock at zero"
  ;; Zero rather than a live reading: this names the BEGINNING. A live value
  ;; would make the first World depend on whatever ran before the program.
  (check-equal? (string-trim (run-last "(eval (world-tick initial-world))")) "0N : Nat"))

;; ------------------------------------------------------------------
;; What QTT enforces
;; ------------------------------------------------------------------

(test-case "a World may not be used twice"
  ;; Two futures branching off one past — two effects both claiming to follow
  ;; the same predecessor, which is the ambiguity the token exists to remove.
  ;; Consumes `w` by matching it AND reads it again through `world-tick`.
  ;; Deliberately avoids list literals: those pull in Seqable and the failure
  ;; arrives as an inference error, which would pass a naive "did it error?"
  ;; check while proving nothing about multiplicity.
  (define e (mult-error
             "(def two := (fn [w :1 World] (match w (| world n -> (world (world-tick w))))))"))
  (check-true (and e #t) "using a linear World twice was ACCEPTED")
  (check-true (regexp-match? #rx"more than once" e)))

(test-case "a World may not be dropped"
  ;; A dropped World is an effect nothing depends on — exactly the one a lazy
  ;; reducer is entitled to skip.
  (define e (mult-error "(def dropw := (fn [w :1 World] 0N))"))
  (check-true (and e #t) "dropping a linear World was ACCEPTED")
  (check-true (regexp-match? #rx"not used|must be consumed" e)))

(test-case "matching a World counts as exactly one use"
  ;; Load-bearing: every action in io::net consumes its World by matching it.
  ;; If `match` counted as zero or two uses, none of them would type.
  (check-true (regexp-match? #rx"defined"
                             (run-last "(def m := (fn [w :1 World] (match w (| world n -> n))))"))))

(test-case "a World may be consumed and a new one rebuilt"
  ;; The shape every action uses: match the old, produce the next.
  (check-true (regexp-match? #rx"defined"
                             (run-last "(def step := (fn [w :1 World] (match w (| world n -> (world (suc n))))))"))))

;; ------------------------------------------------------------------
;; The specs are load-bearing, not documentation
;; ------------------------------------------------------------------
;;
;; These assert the multiplicity actually reached the type rather than trusting
;; that a declaration was honoured.
;;
;; What they catch, measured rather than assumed: `:1` survives if EITHER the
;; spec's Pi binder or the body's `fn` binder declares it, and a disagreement
;; between the two is accepted SILENTLY. So widening one site alone does not
;; fail here — verified by perturbing each in turn. Widening both does. Read
;; these as a guard against the multiplicity disappearing from the type, not as
;; a guard on any single declaration site.

(define (linear-world-param? expr)
  (define t (run-last (format "(infer ~a)" expr)))
  (and (string? t) (regexp-match? #rx":1 <prologos::core::world::World>" t)))

(test-case "every net action takes its World linearly"
  (for ([op (list "net-listen" "net-accept" "net-send" "net-recv"
                  "net-close-conn" "net-close-server")])
    (check-true (linear-world-param? op)
                (format "~a does not take its World at :1 — the spec was widened" op))))

(test-case "an action is a function of a World, not an effect already run"
  ;; `net-send c payload` must be a VALUE. If applying the ordinary arguments
  ;; performed the send, ordering would be back to evaluation order.
  (define t (run-last "(infer net-send)"))
  (check-true (regexp-match? #rx"ConnH String -> \\[Pi" t)
              (format "net-send is not curried to a World transformer: ~a" t)))

;; ------------------------------------------------------------------
;; The gap, pinned
;; ------------------------------------------------------------------

(test-case "KNOWN GAP: a World can be extracted from a Recv twice"
  ;; `Recv` holds a World in an ordinary field, and data fields carry no
  ;; multiplicity — so the branching-timeline case linearity exists to stop is
  ;; reachable through the bundle rather than through the parameter. Closing it
  ;; needs linear fields, which Phase 0 does not have.
  ;;
  ;; Asserted as ACCEPTED on purpose. This is the honest state of the
  ;; guarantee, and if a future change starts rejecting it, this test failing
  ;; is the notification that the gap closed.
  ;; A `spec` so the nested matches have a return type to check against —
  ;; without one this fails on INFERENCE, which would look like the gap being
  ;; closed while proving nothing.
  (run "(spec twice-out Recv -> Nat)")
  (define r (run-last
             (string-append
              "(defn twice-out [r] "
              "  (match (recv-world r) (| world a -> "
              "    (match (recv-world r) (| world b -> a)))))")))
  (check-true (and (string? r) (regexp-match? #rx"defined" r))
              "the Recv gap has CLOSED — update the docs in io::net and world"))
