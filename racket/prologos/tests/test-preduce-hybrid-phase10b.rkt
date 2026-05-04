#lang racket/base

;;; test-preduce-hybrid-phase10b.rkt
;;;
;;; Validates that compile-expr (shared via preduce-core.rkt) runs
;;; Phase-10b user-defined-ctor programs end-to-end on the Zig kernel
;;; via backend-hybrid.
;;;
;;; This is the headline acceptance test for the swappable-backend
;;; refactor: a Phase-10b workload (the AST shape OCapN-syrup tests
;;; produce after elaboration) runs through the same compile-expr
;;; that powers preduce.rkt under backend-racket — only the backend
;;; instance differs.
;;;
;;; Skips when the kernel .so isn't available, mirroring the existing
;;; test-preduce-hybrid-* fail-soft pattern.

(require rackunit
         "../preduce.rkt"
         "../preduce-core.rkt"
         "../preduce-backend-hybrid.rkt"
         "../runtime-bridge.rkt"
         "../syntax.rkt"
         "../macros.rkt"
         (only-in "../reduction.rkt" nf))

(cond
  [(not (hybrid-runtime-available?))
   (printf "test-preduce-hybrid-phase10b: kernel .so not available, skipping~n")]
  [else
   ;; Register synthetic data types mirroring syrup's nullary + unary cases.
   ;; Same shape as test-preduce-phase10b.rkt's fixtures, namespaced to avoid
   ;; collision when both test files run in the same suite worker.
   (register-ctor! 'probehy-null (ctor-meta 'ProbeHy '() '()         '()  0))
   (register-ctor! 'probehy-tag  (ctor-meta 'ProbeHy '() (list 'Nat) '(#f) 1))

   (define (run-via-hybrid e)
     (with-backend backend-hybrid
       (define net0 (b-fresh-net))
       (define-values (cid net1) (compile-expr e '() net0))
       (define netf (b-run-to-quiescence net1))
       (b-read netf cid)))

   ;; Match against `nf` (the production reducer) for value-level equality
   ;; on Int / Bool / Nat results. preduce-user-ctor stuck values use
   ;; backend-specific cell-id representations (Racket cell-id struct vs
   ;; uint32) so we don't compare those directly — extract via match.

   (test-case "phase10b/hybrid: bare nullary user ctor produces preduce-user-ctor"
     (define e (expr-fvar 'probehy-null))
     (define r (run-via-hybrid e))
     (check-pred preduce-user-ctor? r)
     (check-equal? (preduce-user-ctor-short-name r) 'probehy-null)
     (check-equal? (preduce-user-ctor-field-cids r) '()))

   (test-case "phase10b/hybrid: unary ctor application produces preduce-user-ctor with one field"
     (define e (expr-app (expr-fvar 'probehy-tag) (expr-suc (expr-suc (expr-zero)))))
     (define r (run-via-hybrid e))
     (check-pred preduce-user-ctor? r)
     (check-equal? (preduce-user-ctor-short-name r) 'probehy-tag)
     (check-equal? (length (preduce-user-ctor-field-cids r)) 1))

   (test-case "phase10b/hybrid: match on nullary ctor selects right arm"
     (define e
       (expr-reduce (expr-fvar 'probehy-null)
                    (list (expr-reduce-arm 'probehy-null 0 (expr-int 42))
                          (expr-reduce-arm 'probehy-tag 1 (expr-int 99)))
                    #t))
     (check-equal? (run-via-hybrid e) (expr-int 42))
     (check-equal? (run-via-hybrid e) (nf e)))

   (test-case "phase10b/hybrid: match on unary ctor extracts field (THE headline case)"
     ;; This is the AST shape OCapN-syrup tests produce after elaboration.
     ;; Equivalent to: (match (syrup-tagged tag payload) | ... | syrup-tagged t _ -> t)
     (define e
       (expr-reduce (expr-app (expr-fvar 'probehy-tag) (expr-suc (expr-suc (expr-suc (expr-zero)))))
                    (list (expr-reduce-arm 'probehy-null 0 (expr-int 0))
                          (expr-reduce-arm 'probehy-tag 1 (expr-bvar 0)))
                    #t))
     (check-equal? (run-via-hybrid e) (expr-nat-val 3))
     (check-equal? (run-via-hybrid e) (nf e)))

   ;; Print kernel profile for the headline case (Phase 6 — observation).
   (printf "~n=== Kernel profile for the headline match-on-unary-ctor case ===~n")
   (prologos_set_profile_per_tag 1)
   (prologos_reset_stats)
   (run-via-hybrid
    (expr-reduce (expr-app (expr-fvar 'probehy-tag) (expr-suc (expr-suc (expr-suc (expr-zero)))))
                 (list (expr-reduce-arm 'probehy-null 0 (expr-int 0))
                       (expr-reduce-arm 'probehy-tag 1 (expr-bvar 0)))
                 #t))
   (prologos_print_stats)
   (prologos_print_callback_summary)])
