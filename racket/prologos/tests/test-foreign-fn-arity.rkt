#lang racket/base

;;; test-foreign-fn-arity.rkt — a partially-applied foreign's type is the
;;; REMAINDER, not the full registered Pi.
;;;
;;; QTT P5 residual 5. `global-env-lookup-type` returns the type the foreign
;;; was declared with, which is the node's type only while `args` is empty.
;;; `reduction.rkt`'s partial-application arm appends whnf'd arguments into
;;; `args` and returns the updated node when arity has not been reached — and
;;; both `infer` and `inferQ` went on reporting the FULL Pi, so the type was
;;; arity-wrong by exactly `(length args)`.
;;;
;;; The residual noted the two arms agreed with each other, so this was
;;; twin-parity rather than drift, and that fixing it meant fixing both. It
;;; turned out to mean fixing ONE: `inferQ` already delegates the type to
;;; `infer` (the no-drift twin pattern), so the peel lands in one place and
;;; both arms inherit it. Both are asserted below anyway — "they agree" is the
;;; property that made this safe to leave, so it is the property to pin.
;;;
;;; Tested at the arm directly. The accumulating node is built only inside
;;; `whnf`, on the hole-section path, so no source program reaches this today —
;;; the same reason the sibling walker defect (`2df675d5`) needed direct tests.

(require rackunit
         racket/list
         "test-support.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../macros.rkt"
         (only-in "../metavar-store.rkt" current-persistent-registry-net-box)
         "../errors.rkt"
         (prefix-in tc: "../typing-core.rkt")
         (prefix-in q: "../qtt.rkt"))

;; A 2-ary foreign from the standard library: `fio-open-raw : String -> String
;; -> Nat`. Using a REAL registered foreign rather than a hand-planted env
;; entry keeps the test honest about what `global-env-lookup-type` returns.
(define-values (env-ready?)
  (parameterize ([current-file-module-network-ref (make-module-network)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-persistent-registry-net-box prelude-persistent-registry-net-box])
    (install-module-loader!)
    (process-string "(ns foreign-arity-pre)")
    (process-string "(imports prologos::core::fio)")
    (and (global-env-lookup-type 'prologos::core::fio::fio-open-raw) #t)))

;; Everything below runs inside the same env the fixture built.
(define-syntax-rule (with-env body ...)
  (parameterize ([current-file-module-network-ref (make-module-network)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-persistent-registry-net-box prelude-persistent-registry-net-box])
    (install-module-loader!)
    (process-string "(ns foreign-arity-t)")
    (process-string "(imports prologos::core::fio)")
    body ...))

(define fname 'prologos::core::fio::fio-open-raw)

(define (mk args)
  (expr-foreign-fn fname void 2 args (list values values) values #f 'fio-open-port))

(define (pi-depth t)
  (let loop ([t t] [n 0]) (if (expr-Pi? t) (loop (expr-Pi-codomain t) (add1 n)) n)))

(test-case "foreign-arity/the fixture found a real 2-ary foreign"
  ;; If this fails everything below is vacuous — the arms return expr-error for
  ;; an unknown name, and `expr-error` is not a Pi, so the depth assertions
  ;; would "pass" for the wrong reason.
  (check-true env-ready? "prologos.core.fio did not load")
  (with-env
    (define full (global-env-lookup-type fname))
    (check-true (and full (not (expr-error? full))) (format "~v" full))
    (check-equal? (pi-depth full) 2
                  (format "expected String -> String -> Nat, got: ~v" full))))

(test-case "foreign-arity/infer peels one Pi per accumulated argument"
  (with-env
    (define full (global-env-lookup-type fname))
    (check-equal? (tc:infer ctx-empty (mk '())) full
                  "an empty node still reports the full registered type")
    (check-equal? (pi-depth (tc:infer ctx-empty (mk (list (expr-string "f")))))
                  1
                  "one accumulated argument must leave ONE Pi")
    (check-equal? (tc:infer ctx-empty (mk (list (expr-string "f") (expr-string "r"))))
                  (expr-Nat)
                  "both arguments accumulated: the type is the result type")))

(test-case "foreign-arity/inferQ agrees with infer at every arity"
  ;; The residual's own framing: the two arms agreed while both were wrong, so
  ;; agreement is what has to keep holding after the fix.
  (with-env
    (for ([args (in-list (list '()
                               (list (expr-string "f"))
                               (list (expr-string "f") (expr-string "r"))))])
      (define e (mk args))
      (define t-infer (tc:infer ctx-empty e))
      (define r (q:inferQ ctx-empty e))
      (check-true (q:tu? r) (format "inferQ failed at ~a args: ~v" (length args) r))
      (check-equal? (q:tu-type r) t-infer
                    (format "twins disagree at ~a accumulated args" (length args))))))

(test-case "foreign-arity/over-application is an error, not a wrong type"
  ;; More accumulated args than the registered type has Pis means the node is
  ;; malformed. Reporting expr-error beats handing back a type that is wrong by
  ;; a different amount — which is what the peel would do if it stopped early.
  (with-env
    (define e (mk (list (expr-string "a") (expr-string "b") (expr-string "c"))))
    (check-true (expr-error? (tc:infer ctx-empty e))
                (format "~v" (tc:infer ctx-empty e)))))
