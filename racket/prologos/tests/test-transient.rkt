#lang racket/base

;;;
;;; Tests for Transient Builders (mutable batch construction for PVec, Map, Set)
;;;

(require racket/string
         racket/path
         rackunit
         "test-support.rkt"
         "../syntax.rkt"
         "../prelude.rkt"
         "../substitution.rkt"
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../pretty-print.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../rrb.rkt"
         "../champ.rkt"
         "../namespace.rkt"
         "../macros.rkt"
         "../errors.rkt")

;; Helper to run with clean global env
(define (run s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
    (process-string s)))

;; Helper: run with namespace system (for prelude access)
(define (run-ns s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    (process-string s)))

;; Helper: check that results contain an error
(define (result-has-error? results)
  (and (list? results)
       (ormap prologos-error? results)))

;; ========================================
;; Core AST: TVec type formation
;; ========================================

(test-case "TVec type formation"
  (check-equal? (tc:infer ctx-empty (expr-TVec (expr-Nat)))
                (expr-Type (lzero))))

(test-case "TMap type formation"
  (check-equal? (tc:infer ctx-empty (expr-TMap (expr-Nat) (expr-Bool)))
                (expr-Type (lzero))))

(test-case "TSet type formation"
  (check-equal? (tc:infer ctx-empty (expr-TSet (expr-Nat)))
                (expr-Type (lzero))))

;; ========================================
;; Core AST: transient/persist typing (generic)
;; ========================================

(test-case "transient PVec → TVec"
  (check-equal? (tc:infer ctx-empty
                  (expr-transient (expr-pvec-empty (expr-Nat))))
                (expr-TVec (expr-Nat))))

(test-case "persist TVec → PVec"
  ;; Build a transient of a PVec, then persist it
  ;; The type checker handles the generic expr-persist
  (let ([transient-expr (expr-transient (expr-pvec-empty (expr-Nat)))])
    (check-equal? (tc:infer ctx-empty (expr-persist transient-expr))
                  (expr-PVec (expr-Nat)))))

;; ========================================
;; Core AST: specific transient-vec/persist-vec typing
;; ========================================

(test-case "transient-vec typing"
  (check-equal? (tc:infer ctx-empty
                  (expr-transient-vec (expr-pvec-empty (expr-Nat))))
                (expr-TVec (expr-Nat))))

(test-case "persist-vec typing"
  (check-equal? (tc:infer ctx-empty
                  (expr-persist-vec (expr-transient-vec (expr-pvec-empty (expr-Nat)))))
                (expr-PVec (expr-Nat))))

;; ========================================
;; Core AST: tvec-push! typing
;; ========================================

(test-case "tvec-push! typing"
  (check-equal? (tc:infer ctx-empty
                  (expr-tvec-push!
                    (expr-transient-vec (expr-pvec-empty (expr-Nat)))
                    (expr-zero)))
                (expr-TVec (expr-Nat))))

;; ========================================
;; Core AST: tvec-update! typing
;; ========================================

(test-case "tvec-update! typing"
  (check-equal? (tc:infer ctx-empty
                  (expr-tvec-update!
                    (expr-tvec-push!
                      (expr-transient-vec (expr-pvec-empty (expr-Nat)))
                      (expr-zero))
                    (expr-zero)
                    (expr-suc (expr-zero))))
                (expr-TVec (expr-Nat))))

;; ========================================
;; Core AST: Map transient typing
;; ========================================

(test-case "transient-map typing"
  (check-equal? (tc:infer ctx-empty
                  (expr-transient-map (expr-map-empty (expr-Nat) (expr-Bool))))
                (expr-TMap (expr-Nat) (expr-Bool))))

(test-case "tmap-assoc! typing"
  (check-equal? (tc:infer ctx-empty
                  (expr-tmap-assoc!
                    (expr-transient-map (expr-map-empty (expr-Nat) (expr-Bool)))
                    (expr-zero) (expr-true)))
                (expr-TMap (expr-Nat) (expr-Bool))))

(test-case "persist-map typing"
  (check-equal? (tc:infer ctx-empty
                  (expr-persist-map
                    (expr-transient-map (expr-map-empty (expr-Nat) (expr-Bool)))))
                (expr-Map (expr-Nat) (expr-Bool))))

;; ========================================
;; Core AST: Set transient typing
;; ========================================

(test-case "transient-set typing"
  (check-equal? (tc:infer ctx-empty
                  (expr-transient-set (expr-set-empty (expr-Nat))))
                (expr-TSet (expr-Nat))))

(test-case "tset-insert! typing"
  (check-equal? (tc:infer ctx-empty
                  (expr-tset-insert!
                    (expr-transient-set (expr-set-empty (expr-Nat)))
                    (expr-zero)))
                (expr-TSet (expr-Nat))))

(test-case "persist-set typing"
  (check-equal? (tc:infer ctx-empty
                  (expr-persist-set
                    (expr-transient-set (expr-set-empty (expr-Nat)))))
                (expr-Set (expr-Nat))))

;; ========================================
;; Reduction: PVec transient roundtrip
;; ========================================

(test-case "PVec empty transient roundtrip"
  ;; persist!(transient(pvec-empty(Nat))) ≡ pvec-empty value
  (let* ([empty-pvec (expr-pvec-empty (expr-Nat))]
         [result (nf (expr-persist-vec (expr-transient-vec empty-pvec)))])
    (check-pred expr-rrb? result)
    (check-equal? (rrb-size (expr-rrb-racket-rrb result)) 0)))

(test-case "PVec transient push and freeze"
  ;; Build: transient(empty), push 0, push 1, push 2, persist
  (let* ([t (expr-transient-vec (expr-pvec-empty (expr-Nat)))]
         [t1 (expr-tvec-push! t (expr-zero))]
         [t2 (expr-tvec-push! t1 (expr-suc (expr-zero)))]
         [t3 (expr-tvec-push! t2 (expr-suc (expr-suc (expr-zero))))]
         [result (nf (expr-persist-vec t3))])
    (check-pred expr-rrb? result)
    (let ([r (expr-rrb-racket-rrb result)])
      (check-equal? (rrb-size r) 3)
      (check-equal? (whnf (rrb-get r 0)) (expr-nat-val 0))
      (check-equal? (whnf (rrb-get r 1)) (expr-nat-val 1))
      (check-equal? (whnf (rrb-get r 2)) (expr-nat-val 2)))))

(test-case "PVec transient update"
  ;; Build 3 elements, update index 1, persist
  (let* ([t (expr-transient-vec (expr-pvec-empty (expr-Nat)))]
         [t1 (expr-tvec-push! t (expr-zero))]
         [t2 (expr-tvec-push! t1 (expr-suc (expr-zero)))]
         [t3 (expr-tvec-push! t2 (expr-suc (expr-suc (expr-zero))))]
         [t4 (expr-tvec-update! t3 (expr-suc (expr-zero)) (nat->expr 42))]
         [result (nf (expr-persist-vec t4))])
    (check-pred expr-rrb? result)
    (let ([r (expr-rrb-racket-rrb result)])
      (check-equal? (rrb-size r) 3)
      (check-equal? (whnf (rrb-get r 1)) (nat->expr 42)))))

;; ========================================
;; Reduction: Map transient roundtrip
;; ========================================

(test-case "Map empty transient roundtrip"
  (let* ([empty-map (expr-map-empty (expr-Nat) (expr-Bool))]
         [result (nf (expr-persist-map (expr-transient-map empty-map)))])
    (check-pred expr-champ? result)
    (check-equal? (champ-size (expr-champ-racket-champ result)) 0)))

(test-case "Map transient assoc and freeze"
  ;; Build: transient(empty), assoc 0->true, assoc 1->false, persist
  (let* ([t (expr-transient-map (expr-map-empty (expr-Nat) (expr-Bool)))]
         [t1 (expr-tmap-assoc! t (expr-zero) (expr-true))]
         [t2 (expr-tmap-assoc! t1 (expr-suc (expr-zero)) (expr-false))]
         [result (nf (expr-persist-map t2))])
    (check-pred expr-champ? result)
    (check-equal? (champ-size (expr-champ-racket-champ result)) 2)))

(test-case "Map transient dissoc"
  ;; Build 2 entries, remove first, persist
  (let* ([t (expr-transient-map (expr-map-empty (expr-Nat) (expr-Bool)))]
         [t1 (expr-tmap-assoc! t (expr-zero) (expr-true))]
         [t2 (expr-tmap-assoc! t1 (expr-suc (expr-zero)) (expr-false))]
         [t3 (expr-tmap-dissoc! t2 (expr-zero))]
         [result (nf (expr-persist-map t3))])
    (check-pred expr-champ? result)
    (check-equal? (champ-size (expr-champ-racket-champ result)) 1)))

;; ========================================
;; Reduction: Set transient roundtrip
;; ========================================

(test-case "Set empty transient roundtrip"
  (let* ([empty-set (expr-set-empty (expr-Nat))]
         [result (nf (expr-persist-set (expr-transient-set empty-set)))])
    (check-pred expr-hset? result)
    (check-equal? (champ-size (expr-hset-racket-champ result)) 0)))

(test-case "Set transient insert and freeze"
  (let* ([t (expr-transient-set (expr-set-empty (expr-Nat)))]
         [t1 (expr-tset-insert! t (expr-zero))]
         [t2 (expr-tset-insert! t1 (expr-suc (expr-zero)))]
         [result (nf (expr-persist-set t2))])
    (check-pred expr-hset? result)
    (check-equal? (champ-size (expr-hset-racket-champ result)) 2)))

(test-case "Set transient delete"
  (let* ([t (expr-transient-set (expr-set-empty (expr-Nat)))]
         [t1 (expr-tset-insert! t (expr-zero))]
         [t2 (expr-tset-insert! t1 (expr-suc (expr-zero)))]
         [t3 (expr-tset-delete! t2 (expr-zero))]
         [result (nf (expr-persist-set t3))])
    (check-pred expr-hset? result)
    (check-equal? (champ-size (expr-hset-racket-champ result)) 1)))

;; ========================================
;; Reduction: Generic transient/persist
;; ========================================

(test-case "generic transient on PVec reduces"
  (let* ([empty-pvec (expr-pvec-empty (expr-Nat))]
         [result (whnf (expr-transient empty-pvec))])
    (check-pred expr-trrb? result)))

(test-case "generic persist on TVec reduces"
  (let* ([t (expr-transient (expr-pvec-empty (expr-Nat)))]
         [result (nf (expr-persist t))])
    (check-pred expr-rrb? result)))

(test-case "generic transient on Map reduces"
  (let* ([empty-map (expr-map-empty (expr-Nat) (expr-Bool))]
         [result (whnf (expr-transient empty-map))])
    (check-pred expr-tchamp? result)))

(test-case "generic transient on Set reduces"
  (let* ([empty-set (expr-set-empty (expr-Nat))]
         [result (whnf (expr-transient empty-set))])
    (check-pred expr-thset? result)))

;; ========================================
;; Surface syntax: sexp forms
;; ========================================

(test-case "surface: transient + persist PVec"
  (check-equal?
   (run "(eval (pvec-length (persist! (tvec-push! (transient (pvec-empty Nat)) zero))))")
   '("1N : Nat")))

(test-case "surface: transient + persist PVec multi-push"
  (check-equal?
   (run "(eval (pvec-length (persist! (tvec-push! (tvec-push! (transient (pvec-empty Nat)) zero) (suc zero)))))")
   '("2N : Nat")))

(test-case "surface: transient + persist Map"
  (check-equal?
   (run "(eval (map-size (persist! (tmap-assoc! (transient (map-empty Nat Bool)) zero true))))")
   '("1N : Nat")))

(test-case "surface: transient + persist Set"
  (check-equal?
   (run "(eval (set-size (persist! (tset-insert! (transient (set-empty Nat)) zero))))")
   '("1N : Nat")))

(test-case "surface: tvec-update!"
  (check-equal?
   (run "(eval (pvec-nth (persist! (tvec-update! (tvec-push! (transient (pvec-empty Nat)) zero) zero (suc zero))) zero))")
   '("1N : Nat")))

(test-case "surface: tmap-dissoc!"
  (check-equal?
   (run "(eval (map-size (persist! (tmap-dissoc! (tmap-assoc! (transient (map-empty Nat Bool)) zero true) zero))))")
   '("0N : Nat")))

(test-case "surface: tset-delete!"
  (check-equal?
   (run "(eval (set-size (persist! (tset-delete! (tset-insert! (transient (set-empty Nat)) zero) zero))))")
   '("0N : Nat")))

;; ========================================
;; Type checking: TVec/TMap/TSet in check position
;; ========================================

(test-case "check: transient result against TVec"
  (check-equal?
   (run "(check (transient (pvec-empty Nat)) : (TVec Nat))")
   '("OK")))

(test-case "check: persist result against PVec"
  (check-equal?
   (run "(check (persist! (transient (pvec-empty Nat))) : (PVec Nat))")
   '("OK")))

;; ========================================
;; with-transient macro
;; ========================================

(test-case "with-transient PVec"
  (check-equal?
   (run "(eval (pvec-length (with-transient (pvec-empty Nat) (fn (t : (TVec Nat)) (tvec-push! (tvec-push! t zero) (suc zero))))))")
   '("2N : Nat")))
