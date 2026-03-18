#lang racket/base

;;; test-properties.rkt — Property-based tests for Prologos core
;;; Phase E: Subject reduction, unification soundness, heartbeat bounds.

(require rackunit
         rackcheck
         racket/match
         "../prelude.rkt"
         "../syntax.rkt"
         "../metavar-store.rkt"
         "../reduction.rkt"
         "../unify.rkt"
         "../zonk.rkt"
         "../global-env.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../performance-counters.rkt"
         "test-generators.rkt"
         "../driver.rkt")

;; ============================================================
;; Property 1: Subject reduction
;; If e : T and e ⇝ e', then e' : T
;; (Type is preserved under reduction)
;; ============================================================

(test-case "property: subject reduction for Nat terms"
  (check-property
   (make-config #:tests 50)
   (property ([n (gen:integer-in 0 10)])
     (with-fresh-tc-env
       ;; Construct S^n(Z)
       (define term
         (let loop ([n n])
           (if (zero? n) (expr-zero) (expr-suc (loop (sub1 n))))))
       ;; Infer type
       (define ty (tc:infer ctx-empty term))
       (check-true (expr-Nat? ty))
       ;; Reduce to normal form
       (define nf-term (nf term))
       ;; Re-infer type of reduced term
       (define ty2 (tc:infer ctx-empty nf-term))
       (check-true (expr-Nat? ty2)
                   (format "Subject reduction failed: ~a reduced to ~a, type ~a"
                           term nf-term ty2))))))

(test-case "property: subject reduction for Bool terms"
  (check-property
   (make-config #:tests 20)
   (property ([b gen:boolean])
     (with-fresh-tc-env
       (define term (if b (expr-true) (expr-false)))
       (define ty (tc:infer ctx-empty term))
       (check-true (expr-Bool? ty))
       (define nf-term (nf term))
       (define ty2 (tc:infer ctx-empty nf-term))
       (check-true (expr-Bool? ty2))))))

(test-case "property: subject reduction for well-typed programs"
  (check-property
   (make-config #:tests 30)
   (property ([prog gen:well-typed-program])
     (with-fresh-tc-env
       (define term (car prog))
       (define type (cdr prog))
       ;; Should type-check before reduction
       (check-true (tc:check ctx-empty term type))
       ;; Reduce
       (define nf-term (nf term))
       ;; Should still type-check after reduction
       (check-true (tc:check ctx-empty nf-term type)
                   (format "Subject reduction: ~a : ~a but nf(~a) fails check"
                           term type nf-term))))))

;; ============================================================
;; Property 2: Unification soundness
;; If unify(a, b) succeeds, then zonk(a) = zonk(b)
;; ============================================================

(test-case "property: unification soundness — same types"
  (check-property
   (make-config #:tests 50)
   (property ([ty gen:prologos-type])
     (with-fresh-meta-env
       (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                      [current-reduction-fuel (box 50000)])
         (define result (unify '() ty ty))
         (check-true (not (eq? result #f))
                     (format "Same type should unify: ~a" ty))
         ;; After unification, zonk(ty) = zonk(ty) trivially
         (define z1 (zonk ty))
         (define z2 (zonk ty))
         (check-equal? z1 z2))))))

(test-case "property: unification soundness — meta vs concrete"
  (check-property
   (make-config #:tests 30)
   (property ([ty (gen:prologos-type-depth 0)])
     (with-fresh-meta-env
       (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                      [current-reduction-fuel (box 50000)])
         ;; Create a meta, unify with concrete type
         (define m (fresh-meta '() (expr-Type 0) 'test))
         (define result (unify '() m ty))
         (check-true (not (eq? result #f))
                     (format "Meta should unify with ~a" ty))
         ;; zonk(meta) should equal zonk(ty) after successful unification
         (define zm (zonk m))
         (define zt (zonk ty))
         (check-equal? zm zt
                       (format "After unify(?m, ~a): zonk(?m)=~a but zonk(~a)=~a"
                               ty zm ty zt)))))))

;; ============================================================
;; Property 3: Heartbeat bounds
;; Type-checking should complete within bounded heartbeats.
;; For simple terms of size n, expect O(n²) or less.
;; ============================================================

(test-case "property: heartbeat bounds for Nat terms"
  (check-property
   (make-config #:tests 30)
   (property ([n (gen:integer-in 0 15)])
     (with-fresh-tc-env
       (define term
         (let loop ([n n])
           (if (zero? n) (expr-zero) (expr-suc (loop (sub1 n))))))
       (define pc (perf-counters 0 0 0 0 0 0 0 0 0 0 0 0))
       (parameterize ([current-perf-counters pc])
         (tc:infer ctx-empty term))
       ;; Total heartbeats should be bounded by O(n²)
       ;; Use a generous bound: 100 * (n+1)²
       (define total
         (+ (perf-counters-infer-steps pc)
            (perf-counters-unify-steps pc)
            (perf-counters-reduce-steps pc)))
       (define bound (* 100 (expt (+ n 1) 2)))
       (check-true (<= total bound)
                   (format "n=~a: ~a heartbeats exceeds bound ~a"
                           n total bound))))))

;; ============================================================
;; Property 4: Idempotent zonking
;; zonk(zonk(e)) = zonk(e)
;; ============================================================

(test-case "property: zonk is idempotent"
  (check-property
   (make-config #:tests 30)
   (property ([prog gen:well-typed-program])
     (with-fresh-meta-env
       (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                      [current-reduction-fuel (box 50000)])
         (define term (car prog))
         (define z1 (zonk term))
         (define z2 (zonk z1))
         (check-equal? z1 z2
                       (format "zonk not idempotent: zonk(~a)=~a but zonk(zonk)=~a"
                               term z1 z2)))))))

;; ============================================================
;; Property 5: NF is a fixed point
;; nf(nf(e)) = nf(e)
;; ============================================================

(test-case "property: nf is a fixed point"
  (check-property
   (make-config #:tests 30)
   (property ([prog gen:well-typed-program])
     (with-fresh-tc-env
       (define term (car prog))
       (define n1 (nf term))
       (define n2 (nf n1))
       (check-equal? n1 n2
                     (format "nf not idempotent: nf(~a)=~a but nf(nf)=~a"
                             term n1 n2))))))
