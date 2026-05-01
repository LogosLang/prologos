#lang racket/base

;; test-fire-fn-tag.rkt — SH Track 1 seed test.
;;
;; The propagator struct has a new fire-fn-tag field (added 2026-05-02)
;; that's the foundation for round-tripping propagator structure to
;; .pnet. fire-fns themselves are Racket closures and can't be serialized;
;; the tag is the symbol the runtime kernel will use to look up the
;; corresponding native function.
;;
;; This file validates:
;;   - the field exists on the propagator struct
;;   - the default value is DEFAULT-FIRE-FN-TAG ('untagged)
;;   - net-add-propagator accepts and threads :fire-fn-tag
;;   - net-add-fire-once-propagator threads :fire-fn-tag
;;   - net-add-broadcast-propagator threads :fire-fn-tag
;;   - the tag is reachable via propagator-fire-fn-tag accessor

(require rackunit
         racket/set
         "../propagator.rkt"
         "../champ.rkt")

(define (lookup-prop net pid)
  (champ-lookup (prop-network-propagators net) (prop-id-hash pid) pid))

;; A trivial merge: "take the new value". Used only to make cell allocation
;; happy; the test does not exercise any real merging behavior.
(define (last-write-wins _old new) new)

(define (fresh-net+cell)
  (define net (make-prop-network))
  (net-new-cell net #f last-write-wins))

(test-case "default fire-fn-tag is 'untagged"
  (check-equal? DEFAULT-FIRE-FN-TAG 'untagged))

(test-case "net-add-propagator: default tag is 'untagged"
  (define-values (net1 cid) (fresh-net+cell))
  (define-values (net2 pid)
    (net-add-propagator net1 (list cid) '() (lambda (n) n)))
  (define prop (lookup-prop net2 pid))
  (check-equal? (propagator-fire-fn-tag prop) 'untagged))

(test-case "net-add-propagator: explicit tag is preserved"
  (define-values (net1 cid) (fresh-net+cell))
  (define-values (net2 pid)
    (net-add-propagator net1 (list cid) '() (lambda (n) n)
                        #:fire-fn-tag 'merge-set-union))
  (define prop (lookup-prop net2 pid))
  (check-equal? (propagator-fire-fn-tag prop) 'merge-set-union))

(test-case "net-add-fire-once-propagator: explicit tag is preserved"
  (define-values (net1 cid) (fresh-net+cell))
  (define-values (net2 pid)
    (net-add-fire-once-propagator net1 (list cid) '() (lambda (n) n)
                                  #:fire-fn-tag 'fire-once-test))
  (define prop (lookup-prop net2 pid))
  (check-equal? (propagator-fire-fn-tag prop) 'fire-once-test))

(test-case "net-add-broadcast-propagator: explicit tag is preserved"
  (define-values (net1 in-cid) (fresh-net+cell))
  (define-values (net2 out-cid) (net-new-cell net1 #f last-write-wins))
  (define-values (net3 pid)
    (net-add-broadcast-propagator net2 (list in-cid) out-cid
                                  '(a b c)            ;; items
                                  (lambda (item _) (seteq item))  ;; item-fn
                                  set-union           ;; result-merge-fn
                                  #:fire-fn-tag 'broadcast-test))
  (define prop (lookup-prop net3 pid))
  (check-equal? (propagator-fire-fn-tag prop) 'broadcast-test))
