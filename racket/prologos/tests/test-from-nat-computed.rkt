#lang racket/base

;;;
;;; `from-nat` over a COMPUTED Nat.
;;;
;;; `nf`'s from-nat case used to rebuild the node after normalizing its
;;; argument instead of re-firing the reduction rule. `whnf` cannot see through
;;; `(suc <unreduced>)` -- it does not go under constructors -- so a from-nat
;;; over an arithmetic result arrived at `nf` still stuck, and `nf` left it that
;;; way. It then survived all the way to the FFI boundary and died there as
;;;
;;;   foreign: Cannot marshal to integer -- not an Int literal:
;;;     #(struct:expr-from-nat #(struct:expr-nat-val 4))
;;;
;;; which names a fully-reduced argument and blames the marshaller.
;;;
;;; It stayed hidden because every hand-written case works: a literal `4N` is
;;; already `expr-nat-val`, and a short `(suc (suc zero))` reduces under whnf.
;;; Only a Nat built by recursion -- an accumulator, a refcount, a tally --
;;; reaches `nf` in the broken shape. Found via an op:gc-exports wire-delta
;;; that came out as 1 when four references had been counted.
;;;

(require rackunit
         "../syntax.rkt"
         "../reduction.rkt")

(test-case "from-nat/literal nat-val reduces under whnf and nf"
  (check-equal? (whnf (expr-from-nat (expr-nat-val 2))) (expr-int 2))
  (check-equal? (nf   (expr-from-nat (expr-nat-val 2))) (expr-int 2)))

(test-case "from-nat/a fully-evaluated suc chain reduces"
  (check-equal? (whnf (expr-from-nat (expr-suc (expr-suc (expr-zero))))) (expr-int 2))
  (check-equal? (nf   (expr-from-nat (expr-suc (expr-suc (expr-zero))))) (expr-int 2)))

(test-case "from-nat/nf reduces a suc whose body needs reduction — the regression"
  ;; `(suc BODY)` where BODY only becomes a numeral after reduction. whnf is
  ;; entitled to leave this alone; nf is not. Built with an identity redex so
  ;; the body is genuinely unreduced rather than merely deep.
  (define id-app
    (expr-app (expr-lam 'x (expr-Nat) (expr-bvar 0)) (expr-suc (expr-suc (expr-zero)))))
  (define computed (expr-suc (expr-suc id-app)))
  (check-equal? (nf (expr-from-nat computed)) (expr-int 4))
  ;; And nested one more level, to be sure it is not a one-deep special case.
  (check-equal? (nf (expr-from-nat (expr-suc computed))) (expr-int 5)))

(test-case "from-nat/a genuinely stuck argument stays stuck, and does not loop"
  ;; An open term has no numeral. The rule must return the node with its
  ;; argument normalized -- not diverge, and not claim a value.
  (define stuck (expr-from-nat (expr-bvar 0)))
  (check-equal? (nf stuck) stuck)
  (check-equal? (nf (expr-from-nat (expr-suc (expr-bvar 0))))
                (expr-from-nat (expr-suc (expr-bvar 0)))))
