#lang racket/base

;;; test-relation-store-isolation.rkt — a `defr` must not outlive its call.
;;;
;;; `current-relation-store` is a Racket parameter, and `pipeline.md`
;;; § "New Racket Parameter" names test-support.rkt and batch-worker.rkt as
;;; items 2 and 3 of the checklist for exactly this reason. It was in NEITHER:
;;; `grep -c current-relation-store` was 0 in both.
;;;
;;; Two consequences, both silent. A `defr` registered by one call stayed
;;; visible to the next — and, in a batch worker, to the next FILE. And `solve`
;;; in those contexts read a store that was not the ambient one, so it typed as
;;; untyped where production types.
;;;
;;; The design that introduced it recommended threading and accepted the gap,
;;; making this instance #7 of the two-context boundary class. The class recurs
;;; because the parameter set is discovered by grep rather than declared in one
;;; place — which is why this test exists rather than another grep.

(require rackunit
         racket/string
         "test-support.rkt"
         "../errors.rkt"
         (only-in "../relations.rkt" current-relation-store relation-store-names))

(test-case "relation-store/a defr registered by one call is gone by the next"
  ;; Call 1 registers `zz-iso-rel` and queries it.
  (define r1 (run-ns-ws-all "ns rs\ndefr zz-iso-rel [?d]\n  || 1 | 2 | 3\n"))
  (check-true (list? r1))
  ;; Call 2 must not see it. If the store leaked, the goal resolves and this
  ;; returns rows instead of failing.
  (define r2 (run-ns-ws-last "ns rs\n(zz-iso-rel ?d)\n"))
  (check-true (prologos-error? r2)
              (format "the relation leaked into the next call: ~v" r2)))

(test-case "relation-store/the ambient store is restored after a call"
  ;; The parameter itself, not just the observable behaviour: whatever a call
  ;; does to the store, the caller's binding is what remains afterwards.
  (define before (relation-store-names (current-relation-store)))
  (run-ns-ws-all "ns rs2\ndefr zz-iso-rel2 [?d]\n  || 7 | 8\n")
  (define after (relation-store-names (current-relation-store)))
  (check-equal? (sort (map symbol->string after) string<?)
                (sort (map symbol->string before) string<?)
                "a call mutated the caller's relation store"))

(test-case "relation-store/a defr and its query in ONE call still work"
  ;; The isolation must not have broken the ordinary case — register and query
  ;; within a single call is the whole point of the store.
  (define rs (run-ns-ws-all "ns rs3\ndefr zz-iso-rel3 [?d]\n  || 4 | 5\n(zz-iso-rel3 ?d)\n"))
  (check-true (list? rs))
  (check-false (ormap prologos-error? rs)
               (format "register-then-query in one call broke: ~v" rs)))
