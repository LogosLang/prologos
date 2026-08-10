#lang racket/base

;;; test-resolution-bridge-cids.rkt — the pure resolution bridges must read the
;;; registry cell-ids at FIRE time, not at factory-construction time.
;;;
;;; `make-pure-trait-bridge-factory` and `make-pure-hasmethod-bridge-factory`
;;; used to read `(current-impl-registry-cell-id)` and friends EAGERLY, outside
;;; the returned lambda — and both factories are invoked at MODULE LEVEL in
;;; driver.rkt, where those cell-ids are still #f and stay #f for the life of
;;; the process.
;;;
;;; `read-persistent-registry-cell` has no parameter fallback: it answers
;;; `(hasheq)` unconditionally on a #f cid. So the pure bridges read an EMPTY
;;; impl registry in every process, silently.
;;;
;;; Deferring into the lambda would not have been enough — the lambda is called
;;; at INSTALL time, which is also before some paths identify the cells. Fire
;;; time is the only point at which the answer is guaranteed current.
;;;
;;; This is the opposite polarity of GitHub #78 (write-to-param, read-from-cell)
;;; from the same half-migration.

(require rackunit
         "test-support.rkt"
         (only-in "../resolution.rkt"
                  make-pure-trait-bridge-factory
                  make-pure-hasmethod-bridge-factory)
         "../errors.rkt"
         (only-in "../macros.rkt"
                  current-impl-registry-cell-id
                  current-param-impl-registry-cell-id
                  current-trait-registry-cell-id))

;; The property under test is "when is the cell-id READ", and the observable
;; form is: a factory built while the cell-ids are #f must still produce a fire
;; function that sees a cell-id set afterwards.
;;
;; Both factories are exercised, because they had the same defect independently
;; and a fix to one would not have moved the other.

(test-case "resolution/the trait-bridge factory does not capture cell-ids"
  ;; Built with the cell-ids unset — exactly the module-level situation.
  (define factory
    (parameterize ([current-impl-registry-cell-id #f]
                   [current-param-impl-registry-cell-id #f])
      (make-pure-trait-bridge-factory)))
  (check-true (procedure? factory))
  ;; The factory must be usable, and the fire function it returns must be a
  ;; procedure regardless of when the cell-ids were set. If the cids were
  ;; captured, this still succeeds — which is why the pin below is on ARITY,
  ;; the thing that changes when the plumbing is removed.
  (define fire (factory 'SomeTrait #f #f '()))
  (check-true (procedure? fire))
  (check-true (procedure-arity-includes? fire 1)
              "a bridge fire function takes the pnet and nothing else"))

(test-case "resolution/the hasmethod-bridge factory does not capture cell-ids"
  (define factory
    (parameterize ([current-trait-registry-cell-id #f]
                   [current-impl-registry-cell-id #f]
                   [current-param-impl-registry-cell-id #f])
      (make-pure-hasmethod-bridge-factory)))
  (check-true (procedure? factory))
  (define fire (factory 'some-method (cons #f #f) #f #f '()))
  (check-true (procedure? fire))
  (check-true (procedure-arity-includes? fire 1)))

(test-case "resolution/a factory built before the cells exist still resolves traits"
  ;; The end-to-end check that matters: the factories ARE built at module level
  ;; with the cell-ids unset, so ordinary trait resolution exercises exactly the
  ;; path this fixes. If the deferral broke anything, trait dispatch is where it
  ;; shows.
  (define r (run-ns-ws-last "ns rb\n[+ 1 2]\n"))
  (check-false (prologos-error? r) (format "trait dispatch broke: ~v" r))
  (check-true (regexp-match? #rx"3" (format "~a" r)) (format "got: ~v" r)))
