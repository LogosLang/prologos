#lang racket/base

;;;
;;; PROLOGOS SUBSTITUTION
;;; Locally-nameless substitution operations for Prologos.
;;; Direct translation of prologos-substitution.maude + prologos-inductive.maude extensions.
;;;
;;; shift(delta, cutoff, expr) : increase all bound indices >= cutoff by delta in expr
;;; subst(k, s, expr)         : replace bvar(k) with s in expr (shifting s under binders)
;;; open-expr(body, arg)      : replace bvar(0) with arg and decrement other indices
;;;                             (used when entering a binder)
;;;

(require racket/match
         "prelude.rkt"
         "syntax.rkt")

(provide shift subst open-expr)

;; ========================================
;; Shift: increase bound indices >= cutoff by delta
;; ========================================
(define (shift delta cutoff e)
  (match e
    ;; Variables
    [(expr-bvar k)
     (if (>= k cutoff)
         (expr-bvar (+ k delta))
         (expr-bvar k))]
    [(expr-fvar _) e]

    ;; Constants (no bound variables inside)
    [(expr-zero) e]
    [(expr-nat-val _) e]
    [(expr-suc e1) (expr-suc (shift delta cutoff e1))]
    [(expr-refl) e]
    [(expr-Nat) e]
    [(expr-Bool) e]
    [(expr-true) e]
    [(expr-false) e]
    [(expr-Unit) e]
    [(expr-unit) e]
    [(expr-Nil) e]
    [(expr-nil) e]
    [(expr-Type _) e]
    [(expr-hole) e]
    [(expr-typed-hole _) e]
    [(expr-meta _) e]
    [(expr-error) e]

    ;; Binding forms: cutoff increases under binders
    [(expr-lam m t body)
     (expr-lam m (shift delta cutoff t) (shift delta (add1 cutoff) body))]
    [(expr-Pi m dom cod)
     (expr-Pi m (shift delta cutoff dom) (shift delta (add1 cutoff) cod))]
    [(expr-Sigma t1 t2)
     (expr-Sigma (shift delta cutoff t1) (shift delta (add1 cutoff) t2))]

    ;; Non-binding forms
    [(expr-app e1 e2)
     (expr-app (shift delta cutoff e1) (shift delta cutoff e2))]
    [(expr-pair e1 e2)
     (expr-pair (shift delta cutoff e1) (shift delta cutoff e2))]
    [(expr-fst e1) (expr-fst (shift delta cutoff e1))]
    [(expr-snd e1) (expr-snd (shift delta cutoff e1))]
    [(expr-ann e1 e2)
     (expr-ann (shift delta cutoff e1) (shift delta cutoff e2))]
    [(expr-Eq t e1 e2)
     (expr-Eq (shift delta cutoff t) (shift delta cutoff e1) (shift delta cutoff e2))]

    ;; Eliminators (all arguments are non-binding — motives are lambda terms)
    [(expr-natrec mot base step target)
     (expr-natrec (shift delta cutoff mot)
                  (shift delta cutoff base)
                  (shift delta cutoff step)
                  (shift delta cutoff target))]
    [(expr-J mot base left right proof)
     (expr-J (shift delta cutoff mot)
             (shift delta cutoff base)
             (shift delta cutoff left)
             (shift delta cutoff right)
             (shift delta cutoff proof))]
    [(expr-boolrec mot tc fc target)
     (expr-boolrec (shift delta cutoff mot)
                   (shift delta cutoff tc)
                   (shift delta cutoff fc)
                   (shift delta cutoff target))]

    ;; Vec/Fin (all non-binding)
    [(expr-Vec t n)
     (expr-Vec (shift delta cutoff t) (shift delta cutoff n))]
    [(expr-vnil t) (expr-vnil (shift delta cutoff t))]
    [(expr-vcons t n hd tl)
     (expr-vcons (shift delta cutoff t) (shift delta cutoff n)
                 (shift delta cutoff hd) (shift delta cutoff tl))]
    [(expr-Fin n) (expr-Fin (shift delta cutoff n))]
    [(expr-fzero n) (expr-fzero (shift delta cutoff n))]
    [(expr-fsuc n i) (expr-fsuc (shift delta cutoff n) (shift delta cutoff i))]
    [(expr-vhead t n v)
     (expr-vhead (shift delta cutoff t) (shift delta cutoff n) (shift delta cutoff v))]
    [(expr-vtail t n v)
     (expr-vtail (shift delta cutoff t) (shift delta cutoff n) (shift delta cutoff v))]
    [(expr-vindex t n i v)
     (expr-vindex (shift delta cutoff t) (shift delta cutoff n)
                  (shift delta cutoff i) (shift delta cutoff v))]

    ;; Posit8 (all non-binding)
    [(expr-Posit8) e]
    [(expr-posit8 _) e]
    [(expr-p8-add a b) (expr-p8-add (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p8-sub a b) (expr-p8-sub (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p8-mul a b) (expr-p8-mul (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p8-div a b) (expr-p8-div (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p8-neg a) (expr-p8-neg (shift delta cutoff a))]
    [(expr-p8-abs a) (expr-p8-abs (shift delta cutoff a))]
    [(expr-p8-sqrt a) (expr-p8-sqrt (shift delta cutoff a))]
    [(expr-p8-lt a b) (expr-p8-lt (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p8-le a b) (expr-p8-le (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p8-eq a b) (expr-p8-eq (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p8-from-nat n) (expr-p8-from-nat (shift delta cutoff n))]
    [(expr-p8-to-rat a) (expr-p8-to-rat (shift delta cutoff a))]
    [(expr-p8-from-rat a) (expr-p8-from-rat (shift delta cutoff a))]
    [(expr-p8-from-int a) (expr-p8-from-int (shift delta cutoff a))]
    [(expr-p8-if-nar t nc vc v)
     (expr-p8-if-nar (shift delta cutoff t) (shift delta cutoff nc)
                     (shift delta cutoff vc) (shift delta cutoff v))]

    ;; Posit16 (all non-binding)
    [(expr-Posit16) e]
    [(expr-posit16 _) e]
    [(expr-p16-add a b) (expr-p16-add (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p16-sub a b) (expr-p16-sub (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p16-mul a b) (expr-p16-mul (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p16-div a b) (expr-p16-div (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p16-neg a) (expr-p16-neg (shift delta cutoff a))]
    [(expr-p16-abs a) (expr-p16-abs (shift delta cutoff a))]
    [(expr-p16-sqrt a) (expr-p16-sqrt (shift delta cutoff a))]
    [(expr-p16-lt a b) (expr-p16-lt (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p16-le a b) (expr-p16-le (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p16-eq a b) (expr-p16-eq (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p16-from-nat n) (expr-p16-from-nat (shift delta cutoff n))]
    [(expr-p16-to-rat a) (expr-p16-to-rat (shift delta cutoff a))]
    [(expr-p16-from-rat a) (expr-p16-from-rat (shift delta cutoff a))]
    [(expr-p16-from-int a) (expr-p16-from-int (shift delta cutoff a))]
    [(expr-p16-if-nar t nc vc v)
     (expr-p16-if-nar (shift delta cutoff t) (shift delta cutoff nc)
                      (shift delta cutoff vc) (shift delta cutoff v))]

    ;; Posit32 (all non-binding)
    [(expr-Posit32) e]
    [(expr-posit32 _) e]
    [(expr-p32-add a b) (expr-p32-add (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p32-sub a b) (expr-p32-sub (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p32-mul a b) (expr-p32-mul (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p32-div a b) (expr-p32-div (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p32-neg a) (expr-p32-neg (shift delta cutoff a))]
    [(expr-p32-abs a) (expr-p32-abs (shift delta cutoff a))]
    [(expr-p32-sqrt a) (expr-p32-sqrt (shift delta cutoff a))]
    [(expr-p32-lt a b) (expr-p32-lt (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p32-le a b) (expr-p32-le (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p32-eq a b) (expr-p32-eq (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p32-from-nat n) (expr-p32-from-nat (shift delta cutoff n))]
    [(expr-p32-to-rat a) (expr-p32-to-rat (shift delta cutoff a))]
    [(expr-p32-from-rat a) (expr-p32-from-rat (shift delta cutoff a))]
    [(expr-p32-from-int a) (expr-p32-from-int (shift delta cutoff a))]
    [(expr-p32-if-nar t nc vc v)
     (expr-p32-if-nar (shift delta cutoff t) (shift delta cutoff nc)
                      (shift delta cutoff vc) (shift delta cutoff v))]

    ;; Posit64 (all non-binding)
    [(expr-Posit64) e]
    [(expr-posit64 _) e]
    [(expr-p64-add a b) (expr-p64-add (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p64-sub a b) (expr-p64-sub (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p64-mul a b) (expr-p64-mul (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p64-div a b) (expr-p64-div (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p64-neg a) (expr-p64-neg (shift delta cutoff a))]
    [(expr-p64-abs a) (expr-p64-abs (shift delta cutoff a))]
    [(expr-p64-sqrt a) (expr-p64-sqrt (shift delta cutoff a))]
    [(expr-p64-lt a b) (expr-p64-lt (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p64-le a b) (expr-p64-le (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p64-eq a b) (expr-p64-eq (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-p64-from-nat n) (expr-p64-from-nat (shift delta cutoff n))]
    [(expr-p64-to-rat a) (expr-p64-to-rat (shift delta cutoff a))]
    [(expr-p64-from-rat a) (expr-p64-from-rat (shift delta cutoff a))]
    [(expr-p64-from-int a) (expr-p64-from-int (shift delta cutoff a))]
    [(expr-p64-if-nar t nc vc v)
     (expr-p64-if-nar (shift delta cutoff t) (shift delta cutoff nc)
                      (shift delta cutoff vc) (shift delta cutoff v))]

    ;; Quire accumulators (all non-binding)
    [(expr-Quire8) e]
    [(expr-quire8-val _) e]
    [(expr-quire8-fma q a b) (expr-quire8-fma (shift delta cutoff q) (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-quire8-to q) (expr-quire8-to (shift delta cutoff q))]
    [(expr-Quire16) e]
    [(expr-quire16-val _) e]
    [(expr-quire16-fma q a b) (expr-quire16-fma (shift delta cutoff q) (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-quire16-to q) (expr-quire16-to (shift delta cutoff q))]
    [(expr-Quire32) e]
    [(expr-quire32-val _) e]
    [(expr-quire32-fma q a b) (expr-quire32-fma (shift delta cutoff q) (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-quire32-to q) (expr-quire32-to (shift delta cutoff q))]
    [(expr-Quire64) e]
    [(expr-quire64-val _) e]
    [(expr-quire64-fma q a b) (expr-quire64-fma (shift delta cutoff q) (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-quire64-to q) (expr-quire64-to (shift delta cutoff q))]

    ;; Symbol (no subexpressions)
    [(expr-Symbol) e]
    [(expr-symbol _) e]

    ;; Keyword (all non-binding, no subexpressions with de Bruijn vars)
    [(expr-Keyword) e]
    [(expr-keyword _) e]

    ;; Char (atom, no subexpressions)
    [(expr-Char) e]
    [(expr-char _) e]

    ;; String (atom, no subexpressions)
    [(expr-String) e]
    [(expr-string _) e]

    ;; Map (all non-binding)
    [(expr-Map k v) (expr-Map (shift delta cutoff k) (shift delta cutoff v))]
    [(expr-champ _) e]  ; Racket value, no de Bruijn vars
    [(expr-map-empty k v) (expr-map-empty (shift delta cutoff k) (shift delta cutoff v))]
    [(expr-map-assoc m k v) (expr-map-assoc (shift delta cutoff m) (shift delta cutoff k) (shift delta cutoff v))]
    [(expr-map-get m k) (expr-map-get (shift delta cutoff m) (shift delta cutoff k))]
    [(expr-get c k) (expr-get (shift delta cutoff c) (shift delta cutoff k))]
    [(expr-nil-safe-get m k) (expr-nil-safe-get (shift delta cutoff m) (shift delta cutoff k))]
    [(expr-nil-check a) (expr-nil-check (shift delta cutoff a))]
    [(expr-map-dissoc m k) (expr-map-dissoc (shift delta cutoff m) (shift delta cutoff k))]
    [(expr-map-size m) (expr-map-size (shift delta cutoff m))]
    [(expr-map-has-key m k) (expr-map-has-key (shift delta cutoff m) (shift delta cutoff k))]
    [(expr-map-keys m) (expr-map-keys (shift delta cutoff m))]
    [(expr-map-vals m) (expr-map-vals (shift delta cutoff m))]

    ;; Set (all non-binding)
    [(expr-Set a) (expr-Set (shift delta cutoff a))]
    [(expr-hset _) e]  ; Racket value, no de Bruijn vars
    [(expr-set-empty a) (expr-set-empty (shift delta cutoff a))]
    [(expr-set-insert s a) (expr-set-insert (shift delta cutoff s) (shift delta cutoff a))]
    [(expr-set-member s a) (expr-set-member (shift delta cutoff s) (shift delta cutoff a))]
    [(expr-set-delete s a) (expr-set-delete (shift delta cutoff s) (shift delta cutoff a))]
    [(expr-set-size s) (expr-set-size (shift delta cutoff s))]
    [(expr-set-union s1 s2) (expr-set-union (shift delta cutoff s1) (shift delta cutoff s2))]
    [(expr-set-intersect s1 s2) (expr-set-intersect (shift delta cutoff s1) (shift delta cutoff s2))]
    [(expr-set-diff s1 s2) (expr-set-diff (shift delta cutoff s1) (shift delta cutoff s2))]
    [(expr-set-to-list s) (expr-set-to-list (shift delta cutoff s))]

    ;; PVec (all non-binding)
    [(expr-PVec a) (expr-PVec (shift delta cutoff a))]
    [(expr-rrb _) e]
    [(expr-pvec-empty a) (expr-pvec-empty (shift delta cutoff a))]
    [(expr-pvec-push v x) (expr-pvec-push (shift delta cutoff v) (shift delta cutoff x))]
    [(expr-pvec-nth v i) (expr-pvec-nth (shift delta cutoff v) (shift delta cutoff i))]
    [(expr-pvec-update v i x) (expr-pvec-update (shift delta cutoff v) (shift delta cutoff i) (shift delta cutoff x))]
    [(expr-pvec-length v) (expr-pvec-length (shift delta cutoff v))]
    [(expr-pvec-to-list v) (expr-pvec-to-list (shift delta cutoff v))]
    [(expr-pvec-from-list v) (expr-pvec-from-list (shift delta cutoff v))]
    [(expr-pvec-pop v) (expr-pvec-pop (shift delta cutoff v))]
    [(expr-pvec-concat v1 v2) (expr-pvec-concat (shift delta cutoff v1) (shift delta cutoff v2))]
    [(expr-pvec-slice v lo hi) (expr-pvec-slice (shift delta cutoff v) (shift delta cutoff lo) (shift delta cutoff hi))]
    [(expr-pvec-fold f init vec) (expr-pvec-fold (shift delta cutoff f) (shift delta cutoff init) (shift delta cutoff vec))]
    [(expr-pvec-map f vec) (expr-pvec-map (shift delta cutoff f) (shift delta cutoff vec))]
    [(expr-pvec-filter pred vec) (expr-pvec-filter (shift delta cutoff pred) (shift delta cutoff vec))]
    [(expr-set-fold f init set) (expr-set-fold (shift delta cutoff f) (shift delta cutoff init) (shift delta cutoff set))]
    [(expr-set-filter pred set) (expr-set-filter (shift delta cutoff pred) (shift delta cutoff set))]
    [(expr-map-fold-entries f init map) (expr-map-fold-entries (shift delta cutoff f) (shift delta cutoff init) (shift delta cutoff map))]
    [(expr-map-filter-entries pred map) (expr-map-filter-entries (shift delta cutoff pred) (shift delta cutoff map))]
    [(expr-map-map-vals f map) (expr-map-map-vals (shift delta cutoff f) (shift delta cutoff map))]

    ;; Path values (no free variables — branches are keywords/symbols)
    [(expr-path _) e]
    [(expr-Path) e]
    ;; Dynamic path operations (sub-expressions may have free vars)
    [(expr-get-in target paths)
     (expr-get-in (shift delta cutoff target) (shift delta cutoff paths))]
    [(expr-update-in target paths fn)
     (expr-update-in (shift delta cutoff target) (shift delta cutoff paths) (shift delta cutoff fn))]

    ;; Transient Builders (all non-binding)
    [(expr-transient c) (expr-transient (shift delta cutoff c))]
    [(expr-persist c) (expr-persist (shift delta cutoff c))]
    [(expr-TVec a) (expr-TVec (shift delta cutoff a))]
    [(expr-TMap k v) (expr-TMap (shift delta cutoff k) (shift delta cutoff v))]
    [(expr-TSet a) (expr-TSet (shift delta cutoff a))]
    [(expr-trrb _) e]
    [(expr-tchamp _) e]
    [(expr-thset _) e]
    [(expr-transient-vec v) (expr-transient-vec (shift delta cutoff v))]
    [(expr-persist-vec t) (expr-persist-vec (shift delta cutoff t))]
    [(expr-transient-map m) (expr-transient-map (shift delta cutoff m))]
    [(expr-persist-map t) (expr-persist-map (shift delta cutoff t))]
    [(expr-transient-set s) (expr-transient-set (shift delta cutoff s))]
    [(expr-persist-set t) (expr-persist-set (shift delta cutoff t))]
    [(expr-tvec-push! t x) (expr-tvec-push! (shift delta cutoff t) (shift delta cutoff x))]
    [(expr-tvec-update! t i x) (expr-tvec-update! (shift delta cutoff t) (shift delta cutoff i) (shift delta cutoff x))]
    [(expr-tmap-assoc! t k v) (expr-tmap-assoc! (shift delta cutoff t) (shift delta cutoff k) (shift delta cutoff v))]
    [(expr-tmap-dissoc! t k) (expr-tmap-dissoc! (shift delta cutoff t) (shift delta cutoff k))]
    [(expr-tset-insert! t a) (expr-tset-insert! (shift delta cutoff t) (shift delta cutoff a))]
    [(expr-tset-delete! t a) (expr-tset-delete! (shift delta cutoff t) (shift delta cutoff a))]
    ;; Panic
    [(expr-panic msg) (expr-panic (shift delta cutoff msg))]

    ;; PropNetwork (all non-binding)
    [(expr-net-type) e]
    [(expr-cell-id-type) e]
    [(expr-prop-id-type) e]
    [(expr-prop-network _) e]
    [(expr-cell-id _) e]
    [(expr-prop-id _) e]
    [(expr-net-new fuel) (expr-net-new (shift delta cutoff fuel))]
    [(expr-net-new-cell n init merge)
     (expr-net-new-cell (shift delta cutoff n) (shift delta cutoff init) (shift delta cutoff merge))]
    [(expr-net-new-cell-widen n init merge wf nf)
     (expr-net-new-cell-widen (shift delta cutoff n) (shift delta cutoff init) (shift delta cutoff merge)
                              (shift delta cutoff wf) (shift delta cutoff nf))]
    [(expr-net-cell-read n c) (expr-net-cell-read (shift delta cutoff n) (shift delta cutoff c))]
    [(expr-net-cell-write n c v)
     (expr-net-cell-write (shift delta cutoff n) (shift delta cutoff c) (shift delta cutoff v))]
    [(expr-net-add-prop n ins outs fn)
     (expr-net-add-prop (shift delta cutoff n) (shift delta cutoff ins) (shift delta cutoff outs) (shift delta cutoff fn))]
    [(expr-net-run n) (expr-net-run (shift delta cutoff n))]
    [(expr-net-snapshot n) (expr-net-snapshot (shift delta cutoff n))]
    [(expr-net-contradiction n) (expr-net-contradiction (shift delta cutoff n))]

    ;; UnionFind (all non-binding)
    [(expr-uf-type) e]
    [(expr-uf-store _) e]
    [(expr-uf-empty) e]
    [(expr-uf-make-set st id val)
     (expr-uf-make-set (shift delta cutoff st) (shift delta cutoff id) (shift delta cutoff val))]
    [(expr-uf-find st id) (expr-uf-find (shift delta cutoff st) (shift delta cutoff id))]
    [(expr-uf-union st id1 id2)
     (expr-uf-union (shift delta cutoff st) (shift delta cutoff id1) (shift delta cutoff id2))]
    [(expr-uf-value st id) (expr-uf-value (shift delta cutoff st) (shift delta cutoff id))]

    ;; ATMS (all non-binding)
    [(expr-atms-type) e]
    [(expr-assumption-id-type) e]
    [(expr-atms-store _) e]
    [(expr-assumption-id-val _) e]
    [(expr-atms-new net) (expr-atms-new (shift delta cutoff net))]
    [(expr-atms-assume a nm d)
     (expr-atms-assume (shift delta cutoff a) (shift delta cutoff nm) (shift delta cutoff d))]
    [(expr-atms-retract a aid) (expr-atms-retract (shift delta cutoff a) (shift delta cutoff aid))]
    [(expr-atms-nogood a aids) (expr-atms-nogood (shift delta cutoff a) (shift delta cutoff aids))]
    [(expr-atms-amb a alts) (expr-atms-amb (shift delta cutoff a) (shift delta cutoff alts))]
    [(expr-atms-solve-all a g) (expr-atms-solve-all (shift delta cutoff a) (shift delta cutoff g))]
    [(expr-atms-read a c) (expr-atms-read (shift delta cutoff a) (shift delta cutoff c))]
    [(expr-atms-write a c v s)
     (expr-atms-write (shift delta cutoff a) (shift delta cutoff c) (shift delta cutoff v) (shift delta cutoff s))]
    [(expr-atms-consistent a aids) (expr-atms-consistent (shift delta cutoff a) (shift delta cutoff aids))]
    [(expr-atms-worldview a aids) (expr-atms-worldview (shift delta cutoff a) (shift delta cutoff aids))]

    ;; Tabling (all non-binding)
    [(expr-table-store-type) e]
    [(expr-table-store-val _) e]
    [(expr-table-new net) (expr-table-new (shift delta cutoff net))]
    [(expr-table-register s n m) (expr-table-register (shift delta cutoff s) (shift delta cutoff n) (shift delta cutoff m))]
    [(expr-table-add s n a) (expr-table-add (shift delta cutoff s) (shift delta cutoff n) (shift delta cutoff a))]
    [(expr-table-answers s n) (expr-table-answers (shift delta cutoff s) (shift delta cutoff n))]
    [(expr-table-freeze s n) (expr-table-freeze (shift delta cutoff s) (shift delta cutoff n))]
    [(expr-table-complete s n) (expr-table-complete (shift delta cutoff s) (shift delta cutoff n))]
    [(expr-table-run s) (expr-table-run (shift delta cutoff s))]
    [(expr-table-lookup s n a) (expr-table-lookup (shift delta cutoff s) (shift delta cutoff n) (shift delta cutoff a))]

    ;; Opaque FFI values (no binding structure)
    [(expr-opaque _ _) e]

    ;; Relational language (Phase 7 — all non-binding)
    [(expr-solver-type) e]
    [(expr-goal-type) e]
    [(expr-derivation-type) e]
    [(expr-cut) e]
    [(expr-schema-type _) e]
    [(expr-answer-type t) (expr-answer-type (shift delta cutoff t))]
    [(expr-relation-type pts) (expr-relation-type (map (lambda (p) (shift delta cutoff p)) pts))]
    [(expr-solver-config m) (expr-solver-config (shift delta cutoff m))]
    [(expr-logic-var _ _) e]
    [(expr-defr nm sc vs) (expr-defr nm (and sc (shift delta cutoff sc)) (map (lambda (v) (shift delta cutoff v)) vs))]
    [(expr-defr-variant ps bd) (expr-defr-variant ps (map (lambda (b) (shift delta cutoff b)) bd))]
    [(expr-rel ps cls) (expr-rel ps (map (lambda (c) (shift delta cutoff c)) cls))]
    [(expr-clause gs) (expr-clause (map (lambda (g) (shift delta cutoff g)) gs))]
    [(expr-fact-block rs) (expr-fact-block (map (lambda (r) (shift delta cutoff r)) rs))]
    [(expr-fact-row ts) (expr-fact-row (map (lambda (t) (shift delta cutoff t)) ts))]
    [(expr-goal-app nm as) (expr-goal-app nm (map (lambda (a) (shift delta cutoff a)) as))]
    [(expr-unify-goal l r) (expr-unify-goal (shift delta cutoff l) (shift delta cutoff r))]
    [(expr-is-goal v ex) (expr-is-goal (shift delta cutoff v) (shift delta cutoff ex))]
    [(expr-not-goal g) (expr-not-goal (shift delta cutoff g))]
    [(expr-schema nm fs) (expr-schema nm (map (lambda (f) (shift delta cutoff f)) fs))]
    [(expr-solve g) (expr-solve (shift delta cutoff g))]
    [(expr-solve-with sv ov g) (expr-solve-with (and sv (shift delta cutoff sv)) (and ov (shift delta cutoff ov)) (shift delta cutoff g))]
    [(expr-solve-one g) (expr-solve-one (shift delta cutoff g))]
    [(expr-explain g) (expr-explain (shift delta cutoff g))]
    [(expr-explain-with sv ov g) (expr-explain-with (and sv (shift delta cutoff sv)) (and ov (shift delta cutoff ov)) (shift delta cutoff g))]
    [(expr-narrow func args target vars)
     (expr-narrow (shift delta cutoff func) (map (lambda (a) (shift delta cutoff a)) args) (shift delta cutoff target) vars)]
    [(expr-guard cond goal) (expr-guard (shift delta cutoff cond) (and goal (shift delta cutoff goal)))]

    ;; Int (all non-binding)
    [(expr-Int) e]
    [(expr-int _) e]
    [(expr-int-add a b) (expr-int-add (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-int-sub a b) (expr-int-sub (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-int-mul a b) (expr-int-mul (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-int-div a b) (expr-int-div (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-int-mod a b) (expr-int-mod (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-int-neg a) (expr-int-neg (shift delta cutoff a))]
    [(expr-int-abs a) (expr-int-abs (shift delta cutoff a))]
    [(expr-int-lt a b) (expr-int-lt (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-int-le a b) (expr-int-le (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-int-eq a b) (expr-int-eq (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-from-nat n) (expr-from-nat (shift delta cutoff n))]

    ;; Rat (all non-binding)
    [(expr-Rat) e]
    [(expr-rat _) e]
    [(expr-rat-add a b) (expr-rat-add (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-rat-sub a b) (expr-rat-sub (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-rat-mul a b) (expr-rat-mul (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-rat-div a b) (expr-rat-div (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-rat-neg a) (expr-rat-neg (shift delta cutoff a))]
    [(expr-rat-abs a) (expr-rat-abs (shift delta cutoff a))]
    [(expr-rat-lt a b) (expr-rat-lt (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-rat-le a b) (expr-rat-le (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-rat-eq a b) (expr-rat-eq (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-from-int n) (expr-from-int (shift delta cutoff n))]
    [(expr-rat-numer a) (expr-rat-numer (shift delta cutoff a))]
    [(expr-rat-denom a) (expr-rat-denom (shift delta cutoff a))]

    ;; Generic arithmetic (all non-binding)
    [(expr-generic-add a b) (expr-generic-add (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-generic-sub a b) (expr-generic-sub (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-generic-mul a b) (expr-generic-mul (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-generic-div a b) (expr-generic-div (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-generic-lt a b) (expr-generic-lt (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-generic-le a b) (expr-generic-le (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-generic-gt a b) (expr-generic-gt (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-generic-ge a b) (expr-generic-ge (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-generic-eq a b) (expr-generic-eq (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-generic-mod a b) (expr-generic-mod (shift delta cutoff a) (shift delta cutoff b))]
    [(expr-generic-negate a) (expr-generic-negate (shift delta cutoff a))]
    [(expr-generic-abs a) (expr-generic-abs (shift delta cutoff a))]
    [(expr-generic-from-int t a) (expr-generic-from-int (shift delta cutoff t) (shift delta cutoff a))]
    [(expr-generic-from-rat t a) (expr-generic-from-rat (shift delta cutoff t) (shift delta cutoff a))]

    ;; Union types (non-binding)
    [(expr-union l r)
     (expr-union (shift delta cutoff l) (shift delta cutoff r))]

    ;; Unapplied type constructor (HKT) — no bound variables inside
    [(expr-tycon _) e]

    ;; Foreign function (opaque leaf — no Prologos sub-expressions)
    [(expr-foreign-fn _ _ _ _ _ _) e]

    ;; Reduce: scrutinee is non-binding, arm bodies have binding-count binders
    [(expr-reduce scrut arms structural?)
     (expr-reduce (shift delta cutoff scrut)
                  (map (lambda (arm)
                         (expr-reduce-arm
                          (expr-reduce-arm-ctor-name arm)
                          (expr-reduce-arm-binding-count arm)
                          (shift delta (+ cutoff (expr-reduce-arm-binding-count arm))
                                (expr-reduce-arm-body arm))))
                       arms)
                  structural?)]))

;; ========================================
;; Substitution: replace bvar(k) with s in e
;; When going under a binder, k increases and s is shifted up
;; ========================================
(define (subst k s e)
  (match e
    ;; Variables
    [(expr-bvar n)
     (cond
       [(= n k) s]           ; target variable: replace with s
       [(> n k) (expr-bvar (- n 1))]  ; above target: decrement (binder removed)
       [else (expr-bvar n)])]         ; below target: unchanged
    [(expr-fvar _) e]

    ;; Constants
    [(expr-zero) e]
    [(expr-nat-val _) e]
    [(expr-suc e1) (expr-suc (subst k s e1))]
    [(expr-refl) e]
    [(expr-Nat) e]
    [(expr-Bool) e]
    [(expr-true) e]
    [(expr-false) e]
    [(expr-Unit) e]
    [(expr-unit) e]
    [(expr-Nil) e]
    [(expr-nil) e]
    [(expr-Type _) e]
    [(expr-hole) e]
    [(expr-typed-hole _) e]
    [(expr-meta _) e]
    [(expr-error) e]

    ;; Binding forms: increase k, shift s up by 1
    [(expr-lam m t body)
     (expr-lam m (subst k s t) (subst (add1 k) (shift 1 0 s) body))]
    [(expr-Pi m dom cod)
     (expr-Pi m (subst k s dom) (subst (add1 k) (shift 1 0 s) cod))]
    [(expr-Sigma t1 t2)
     (expr-Sigma (subst k s t1) (subst (add1 k) (shift 1 0 s) t2))]

    ;; Non-binding forms
    [(expr-app e1 e2)
     (expr-app (subst k s e1) (subst k s e2))]
    [(expr-pair e1 e2)
     (expr-pair (subst k s e1) (subst k s e2))]
    [(expr-fst e1) (expr-fst (subst k s e1))]
    [(expr-snd e1) (expr-snd (subst k s e1))]
    [(expr-ann e1 e2)
     (expr-ann (subst k s e1) (subst k s e2))]
    [(expr-Eq t e1 e2)
     (expr-Eq (subst k s t) (subst k s e1) (subst k s e2))]

    ;; Eliminators (non-binding)
    [(expr-natrec mot base step target)
     (expr-natrec (subst k s mot)
                  (subst k s base)
                  (subst k s step)
                  (subst k s target))]
    [(expr-J mot base left right proof)
     (expr-J (subst k s mot)
             (subst k s base)
             (subst k s left)
             (subst k s right)
             (subst k s proof))]
    [(expr-boolrec mot tc fc target)
     (expr-boolrec (subst k s mot)
                   (subst k s tc)
                   (subst k s fc)
                   (subst k s target))]

    ;; Vec/Fin (all non-binding)
    [(expr-Vec t n)
     (expr-Vec (subst k s t) (subst k s n))]
    [(expr-vnil t) (expr-vnil (subst k s t))]
    [(expr-vcons t n hd tl)
     (expr-vcons (subst k s t) (subst k s n)
                 (subst k s hd) (subst k s tl))]
    [(expr-Fin n) (expr-Fin (subst k s n))]
    [(expr-fzero n) (expr-fzero (subst k s n))]
    [(expr-fsuc n i) (expr-fsuc (subst k s n) (subst k s i))]
    [(expr-vhead t n v)
     (expr-vhead (subst k s t) (subst k s n) (subst k s v))]
    [(expr-vtail t n v)
     (expr-vtail (subst k s t) (subst k s n) (subst k s v))]
    [(expr-vindex t n i v)
     (expr-vindex (subst k s t) (subst k s n)
                  (subst k s i) (subst k s v))]

    ;; Posit8 (all non-binding)
    [(expr-Posit8) e]
    [(expr-posit8 _) e]
    [(expr-p8-add a b) (expr-p8-add (subst k s a) (subst k s b))]
    [(expr-p8-sub a b) (expr-p8-sub (subst k s a) (subst k s b))]
    [(expr-p8-mul a b) (expr-p8-mul (subst k s a) (subst k s b))]
    [(expr-p8-div a b) (expr-p8-div (subst k s a) (subst k s b))]
    [(expr-p8-neg a) (expr-p8-neg (subst k s a))]
    [(expr-p8-abs a) (expr-p8-abs (subst k s a))]
    [(expr-p8-sqrt a) (expr-p8-sqrt (subst k s a))]
    [(expr-p8-lt a b) (expr-p8-lt (subst k s a) (subst k s b))]
    [(expr-p8-le a b) (expr-p8-le (subst k s a) (subst k s b))]
    [(expr-p8-eq a b) (expr-p8-eq (subst k s a) (subst k s b))]
    [(expr-p8-from-nat n) (expr-p8-from-nat (subst k s n))]
    [(expr-p8-to-rat a) (expr-p8-to-rat (subst k s a))]
    [(expr-p8-from-rat a) (expr-p8-from-rat (subst k s a))]
    [(expr-p8-from-int a) (expr-p8-from-int (subst k s a))]
    [(expr-p8-if-nar t nc vc v)
     (expr-p8-if-nar (subst k s t) (subst k s nc)
                     (subst k s vc) (subst k s v))]

    ;; Posit16 (all non-binding)
    [(expr-Posit16) e]
    [(expr-posit16 _) e]
    [(expr-p16-add a b) (expr-p16-add (subst k s a) (subst k s b))]
    [(expr-p16-sub a b) (expr-p16-sub (subst k s a) (subst k s b))]
    [(expr-p16-mul a b) (expr-p16-mul (subst k s a) (subst k s b))]
    [(expr-p16-div a b) (expr-p16-div (subst k s a) (subst k s b))]
    [(expr-p16-neg a) (expr-p16-neg (subst k s a))]
    [(expr-p16-abs a) (expr-p16-abs (subst k s a))]
    [(expr-p16-sqrt a) (expr-p16-sqrt (subst k s a))]
    [(expr-p16-lt a b) (expr-p16-lt (subst k s a) (subst k s b))]
    [(expr-p16-le a b) (expr-p16-le (subst k s a) (subst k s b))]
    [(expr-p16-eq a b) (expr-p16-eq (subst k s a) (subst k s b))]
    [(expr-p16-from-nat n) (expr-p16-from-nat (subst k s n))]
    [(expr-p16-to-rat a) (expr-p16-to-rat (subst k s a))]
    [(expr-p16-from-rat a) (expr-p16-from-rat (subst k s a))]
    [(expr-p16-from-int a) (expr-p16-from-int (subst k s a))]
    [(expr-p16-if-nar t nc vc v)
     (expr-p16-if-nar (subst k s t) (subst k s nc)
                      (subst k s vc) (subst k s v))]

    ;; Posit32 (all non-binding)
    [(expr-Posit32) e]
    [(expr-posit32 _) e]
    [(expr-p32-add a b) (expr-p32-add (subst k s a) (subst k s b))]
    [(expr-p32-sub a b) (expr-p32-sub (subst k s a) (subst k s b))]
    [(expr-p32-mul a b) (expr-p32-mul (subst k s a) (subst k s b))]
    [(expr-p32-div a b) (expr-p32-div (subst k s a) (subst k s b))]
    [(expr-p32-neg a) (expr-p32-neg (subst k s a))]
    [(expr-p32-abs a) (expr-p32-abs (subst k s a))]
    [(expr-p32-sqrt a) (expr-p32-sqrt (subst k s a))]
    [(expr-p32-lt a b) (expr-p32-lt (subst k s a) (subst k s b))]
    [(expr-p32-le a b) (expr-p32-le (subst k s a) (subst k s b))]
    [(expr-p32-eq a b) (expr-p32-eq (subst k s a) (subst k s b))]
    [(expr-p32-from-nat n) (expr-p32-from-nat (subst k s n))]
    [(expr-p32-to-rat a) (expr-p32-to-rat (subst k s a))]
    [(expr-p32-from-rat a) (expr-p32-from-rat (subst k s a))]
    [(expr-p32-from-int a) (expr-p32-from-int (subst k s a))]
    [(expr-p32-if-nar t nc vc v)
     (expr-p32-if-nar (subst k s t) (subst k s nc)
                      (subst k s vc) (subst k s v))]

    ;; Posit64 (all non-binding)
    [(expr-Posit64) e]
    [(expr-posit64 _) e]
    [(expr-p64-add a b) (expr-p64-add (subst k s a) (subst k s b))]
    [(expr-p64-sub a b) (expr-p64-sub (subst k s a) (subst k s b))]
    [(expr-p64-mul a b) (expr-p64-mul (subst k s a) (subst k s b))]
    [(expr-p64-div a b) (expr-p64-div (subst k s a) (subst k s b))]
    [(expr-p64-neg a) (expr-p64-neg (subst k s a))]
    [(expr-p64-abs a) (expr-p64-abs (subst k s a))]
    [(expr-p64-sqrt a) (expr-p64-sqrt (subst k s a))]
    [(expr-p64-lt a b) (expr-p64-lt (subst k s a) (subst k s b))]
    [(expr-p64-le a b) (expr-p64-le (subst k s a) (subst k s b))]
    [(expr-p64-eq a b) (expr-p64-eq (subst k s a) (subst k s b))]
    [(expr-p64-from-nat n) (expr-p64-from-nat (subst k s n))]
    [(expr-p64-to-rat a) (expr-p64-to-rat (subst k s a))]
    [(expr-p64-from-rat a) (expr-p64-from-rat (subst k s a))]
    [(expr-p64-from-int a) (expr-p64-from-int (subst k s a))]
    [(expr-p64-if-nar t nc vc v)
     (expr-p64-if-nar (subst k s t) (subst k s nc)
                      (subst k s vc) (subst k s v))]

    ;; Quire accumulators (all non-binding)
    [(expr-Quire8) e]
    [(expr-quire8-val _) e]
    [(expr-quire8-fma q a b) (expr-quire8-fma (subst k s q) (subst k s a) (subst k s b))]
    [(expr-quire8-to q) (expr-quire8-to (subst k s q))]
    [(expr-Quire16) e]
    [(expr-quire16-val _) e]
    [(expr-quire16-fma q a b) (expr-quire16-fma (subst k s q) (subst k s a) (subst k s b))]
    [(expr-quire16-to q) (expr-quire16-to (subst k s q))]
    [(expr-Quire32) e]
    [(expr-quire32-val _) e]
    [(expr-quire32-fma q a b) (expr-quire32-fma (subst k s q) (subst k s a) (subst k s b))]
    [(expr-quire32-to q) (expr-quire32-to (subst k s q))]
    [(expr-Quire64) e]
    [(expr-quire64-val _) e]
    [(expr-quire64-fma q a b) (expr-quire64-fma (subst k s q) (subst k s a) (subst k s b))]
    [(expr-quire64-to q) (expr-quire64-to (subst k s q))]

    ;; Symbol (no subexpressions)
    [(expr-Symbol) e]
    [(expr-symbol _) e]

    ;; Keyword (no subexpressions)
    [(expr-Keyword) e]
    [(expr-keyword _) e]

    ;; Char (no subexpressions)
    [(expr-Char) e]
    [(expr-char _) e]

    ;; String (no subexpressions)
    [(expr-String) e]
    [(expr-string _) e]

    ;; Map (all non-binding)
    [(expr-Map kt vt) (expr-Map (subst k s kt) (subst k s vt))]
    [(expr-champ _) e]
    [(expr-map-empty kt vt) (expr-map-empty (subst k s kt) (subst k s vt))]
    [(expr-map-assoc m key v) (expr-map-assoc (subst k s m) (subst k s key) (subst k s v))]
    [(expr-map-get m key) (expr-map-get (subst k s m) (subst k s key))]
    [(expr-get c key) (expr-get (subst k s c) (subst k s key))]
    [(expr-nil-safe-get m key) (expr-nil-safe-get (subst k s m) (subst k s key))]
    [(expr-nil-check a) (expr-nil-check (subst k s a))]
    [(expr-map-dissoc m key) (expr-map-dissoc (subst k s m) (subst k s key))]
    [(expr-map-size m) (expr-map-size (subst k s m))]
    [(expr-map-has-key m key) (expr-map-has-key (subst k s m) (subst k s key))]
    [(expr-map-keys m) (expr-map-keys (subst k s m))]
    [(expr-map-vals m) (expr-map-vals (subst k s m))]

    ;; Set (all non-binding)
    [(expr-Set a) (expr-Set (subst k s a))]
    [(expr-hset _) e]
    [(expr-set-empty a) (expr-set-empty (subst k s a))]
    [(expr-set-insert m x) (expr-set-insert (subst k s m) (subst k s x))]
    [(expr-set-member m x) (expr-set-member (subst k s m) (subst k s x))]
    [(expr-set-delete m x) (expr-set-delete (subst k s m) (subst k s x))]
    [(expr-set-size m) (expr-set-size (subst k s m))]
    [(expr-set-union s1 s2) (expr-set-union (subst k s s1) (subst k s s2))]
    [(expr-set-intersect s1 s2) (expr-set-intersect (subst k s s1) (subst k s s2))]
    [(expr-set-diff s1 s2) (expr-set-diff (subst k s s1) (subst k s s2))]
    [(expr-set-to-list m) (expr-set-to-list (subst k s m))]

    ;; PVec (all non-binding)
    [(expr-PVec a) (expr-PVec (subst k s a))]
    [(expr-rrb _) e]
    [(expr-pvec-empty a) (expr-pvec-empty (subst k s a))]
    [(expr-pvec-push v x) (expr-pvec-push (subst k s v) (subst k s x))]
    [(expr-pvec-nth v i) (expr-pvec-nth (subst k s v) (subst k s i))]
    [(expr-pvec-update v i x) (expr-pvec-update (subst k s v) (subst k s i) (subst k s x))]
    [(expr-pvec-length v) (expr-pvec-length (subst k s v))]
    [(expr-pvec-to-list v) (expr-pvec-to-list (subst k s v))]
    [(expr-pvec-from-list v) (expr-pvec-from-list (subst k s v))]
    [(expr-pvec-pop v) (expr-pvec-pop (subst k s v))]
    [(expr-pvec-concat v1 v2) (expr-pvec-concat (subst k s v1) (subst k s v2))]
    [(expr-pvec-slice v lo hi) (expr-pvec-slice (subst k s v) (subst k s lo) (subst k s hi))]
    [(expr-pvec-fold f init vec) (expr-pvec-fold (subst k s f) (subst k s init) (subst k s vec))]
    [(expr-pvec-map f vec) (expr-pvec-map (subst k s f) (subst k s vec))]
    [(expr-pvec-filter pred vec) (expr-pvec-filter (subst k s pred) (subst k s vec))]
    [(expr-set-fold f init set) (expr-set-fold (subst k s f) (subst k s init) (subst k s set))]
    [(expr-set-filter pred set) (expr-set-filter (subst k s pred) (subst k s set))]
    [(expr-map-fold-entries f init map) (expr-map-fold-entries (subst k s f) (subst k s init) (subst k s map))]
    [(expr-map-filter-entries pred map) (expr-map-filter-entries (subst k s pred) (subst k s map))]
    [(expr-map-map-vals f map) (expr-map-map-vals (subst k s f) (subst k s map))]

    ;; Path values (no free variables)
    [(expr-path _) e]
    [(expr-Path) e]
    ;; Dynamic path operations
    [(expr-get-in target paths)
     (expr-get-in (subst k s target) (subst k s paths))]
    [(expr-update-in target paths fn)
     (expr-update-in (subst k s target) (subst k s paths) (subst k s fn))]

    ;; Transient Builders (all non-binding)
    [(expr-transient c) (expr-transient (subst k s c))]
    [(expr-persist c) (expr-persist (subst k s c))]
    [(expr-TVec a) (expr-TVec (subst k s a))]
    [(expr-TMap kt vt) (expr-TMap (subst k s kt) (subst k s vt))]
    [(expr-TSet a) (expr-TSet (subst k s a))]
    [(expr-trrb _) e]
    [(expr-tchamp _) e]
    [(expr-thset _) e]
    [(expr-transient-vec v) (expr-transient-vec (subst k s v))]
    [(expr-persist-vec t) (expr-persist-vec (subst k s t))]
    [(expr-transient-map m) (expr-transient-map (subst k s m))]
    [(expr-persist-map t) (expr-persist-map (subst k s t))]
    [(expr-transient-set sv) (expr-transient-set (subst k s sv))]
    [(expr-persist-set t) (expr-persist-set (subst k s t))]
    [(expr-tvec-push! t x) (expr-tvec-push! (subst k s t) (subst k s x))]
    [(expr-tvec-update! t i x) (expr-tvec-update! (subst k s t) (subst k s i) (subst k s x))]
    [(expr-tmap-assoc! t kt v) (expr-tmap-assoc! (subst k s t) (subst k s kt) (subst k s v))]
    [(expr-tmap-dissoc! t kt) (expr-tmap-dissoc! (subst k s t) (subst k s kt))]
    [(expr-tset-insert! t a) (expr-tset-insert! (subst k s t) (subst k s a))]
    [(expr-tset-delete! t a) (expr-tset-delete! (subst k s t) (subst k s a))]
    ;; Panic
    [(expr-panic msg) (expr-panic (subst k s msg))]

    ;; PropNetwork (all non-binding)
    [(expr-net-type) e]
    [(expr-cell-id-type) e]
    [(expr-prop-id-type) e]
    [(expr-prop-network _) e]
    [(expr-cell-id _) e]
    [(expr-prop-id _) e]
    [(expr-net-new fuel) (expr-net-new (subst k s fuel))]
    [(expr-net-new-cell n init merge)
     (expr-net-new-cell (subst k s n) (subst k s init) (subst k s merge))]
    [(expr-net-new-cell-widen n init merge wf nf)
     (expr-net-new-cell-widen (subst k s n) (subst k s init) (subst k s merge)
                              (subst k s wf) (subst k s nf))]
    [(expr-net-cell-read n c) (expr-net-cell-read (subst k s n) (subst k s c))]
    [(expr-net-cell-write n c v)
     (expr-net-cell-write (subst k s n) (subst k s c) (subst k s v))]
    [(expr-net-add-prop n ins outs fn)
     (expr-net-add-prop (subst k s n) (subst k s ins) (subst k s outs) (subst k s fn))]
    [(expr-net-run n) (expr-net-run (subst k s n))]
    [(expr-net-snapshot n) (expr-net-snapshot (subst k s n))]
    [(expr-net-contradiction n) (expr-net-contradiction (subst k s n))]

    ;; UnionFind (all non-binding)
    [(expr-uf-type) e]
    [(expr-uf-store _) e]
    [(expr-uf-empty) e]
    [(expr-uf-make-set st id val)
     (expr-uf-make-set (subst k s st) (subst k s id) (subst k s val))]
    [(expr-uf-find st id) (expr-uf-find (subst k s st) (subst k s id))]
    [(expr-uf-union st id1 id2)
     (expr-uf-union (subst k s st) (subst k s id1) (subst k s id2))]
    [(expr-uf-value st id) (expr-uf-value (subst k s st) (subst k s id))]

    ;; ATMS (all non-binding)
    [(expr-atms-type) e]
    [(expr-assumption-id-type) e]
    [(expr-atms-store _) e]
    [(expr-assumption-id-val _) e]
    [(expr-atms-new net) (expr-atms-new (subst k s net))]
    [(expr-atms-assume a nm d)
     (expr-atms-assume (subst k s a) (subst k s nm) (subst k s d))]
    [(expr-atms-retract a aid) (expr-atms-retract (subst k s a) (subst k s aid))]
    [(expr-atms-nogood a aids) (expr-atms-nogood (subst k s a) (subst k s aids))]
    [(expr-atms-amb a alts) (expr-atms-amb (subst k s a) (subst k s alts))]
    [(expr-atms-solve-all a g) (expr-atms-solve-all (subst k s a) (subst k s g))]
    [(expr-atms-read a c) (expr-atms-read (subst k s a) (subst k s c))]
    [(expr-atms-write a c v sup)
     (expr-atms-write (subst k s a) (subst k s c) (subst k s v) (subst k s sup))]
    [(expr-atms-consistent a aids) (expr-atms-consistent (subst k s a) (subst k s aids))]
    [(expr-atms-worldview a aids) (expr-atms-worldview (subst k s a) (subst k s aids))]

    ;; Tabling (all non-binding)
    [(expr-table-store-type) e]
    [(expr-table-store-val _) e]
    [(expr-table-new net) (expr-table-new (subst k s net))]
    [(expr-table-register st n m) (expr-table-register (subst k s st) (subst k s n) (subst k s m))]
    [(expr-table-add st n a) (expr-table-add (subst k s st) (subst k s n) (subst k s a))]
    [(expr-table-answers st n) (expr-table-answers (subst k s st) (subst k s n))]
    [(expr-table-freeze st n) (expr-table-freeze (subst k s st) (subst k s n))]
    [(expr-table-complete st n) (expr-table-complete (subst k s st) (subst k s n))]
    [(expr-table-run st) (expr-table-run (subst k s st))]
    [(expr-table-lookup st n a) (expr-table-lookup (subst k s st) (subst k s n) (subst k s a))]

    ;; Opaque FFI values (no binding structure)
    [(expr-opaque _ _) e]

    ;; Relational language (Phase 7 — all non-binding)
    [(expr-solver-type) e]
    [(expr-goal-type) e]
    [(expr-derivation-type) e]
    [(expr-cut) e]
    [(expr-schema-type _) e]
    [(expr-answer-type t) (expr-answer-type (subst k s t))]
    [(expr-relation-type pts) (expr-relation-type (map (lambda (p) (subst k s p)) pts))]
    [(expr-solver-config m) (expr-solver-config (subst k s m))]
    [(expr-logic-var _ _) e]
    [(expr-defr nm sc vs) (expr-defr nm (and sc (subst k s sc)) (map (lambda (v) (subst k s v)) vs))]
    [(expr-defr-variant ps bd) (expr-defr-variant ps (map (lambda (b) (subst k s b)) bd))]
    [(expr-rel ps cls) (expr-rel ps (map (lambda (c) (subst k s c)) cls))]
    [(expr-clause gs) (expr-clause (map (lambda (g) (subst k s g)) gs))]
    [(expr-fact-block rs) (expr-fact-block (map (lambda (r) (subst k s r)) rs))]
    [(expr-fact-row ts) (expr-fact-row (map (lambda (t) (subst k s t)) ts))]
    [(expr-goal-app nm as) (expr-goal-app nm (map (lambda (a) (subst k s a)) as))]
    [(expr-unify-goal l r) (expr-unify-goal (subst k s l) (subst k s r))]
    [(expr-is-goal v ex) (expr-is-goal (subst k s v) (subst k s ex))]
    [(expr-not-goal g) (expr-not-goal (subst k s g))]
    [(expr-schema nm fs) (expr-schema nm (map (lambda (f) (subst k s f)) fs))]
    [(expr-solve g) (expr-solve (subst k s g))]
    [(expr-solve-with sv ov g) (expr-solve-with (and sv (subst k s sv)) (and ov (subst k s ov)) (subst k s g))]
    [(expr-solve-one g) (expr-solve-one (subst k s g))]
    [(expr-explain g) (expr-explain (subst k s g))]
    [(expr-explain-with sv ov g) (expr-explain-with (and sv (subst k s sv)) (and ov (subst k s ov)) (subst k s g))]
    [(expr-narrow func args target vars)
     (expr-narrow (subst k s func) (map (lambda (a) (subst k s a)) args) (subst k s target) vars)]
    [(expr-guard cond goal) (expr-guard (subst k s cond) (and goal (subst k s goal)))]

    ;; Int (all non-binding)
    [(expr-Int) e]
    [(expr-int _) e]
    [(expr-int-add a b) (expr-int-add (subst k s a) (subst k s b))]
    [(expr-int-sub a b) (expr-int-sub (subst k s a) (subst k s b))]
    [(expr-int-mul a b) (expr-int-mul (subst k s a) (subst k s b))]
    [(expr-int-div a b) (expr-int-div (subst k s a) (subst k s b))]
    [(expr-int-mod a b) (expr-int-mod (subst k s a) (subst k s b))]
    [(expr-int-neg a) (expr-int-neg (subst k s a))]
    [(expr-int-abs a) (expr-int-abs (subst k s a))]
    [(expr-int-lt a b) (expr-int-lt (subst k s a) (subst k s b))]
    [(expr-int-le a b) (expr-int-le (subst k s a) (subst k s b))]
    [(expr-int-eq a b) (expr-int-eq (subst k s a) (subst k s b))]
    [(expr-from-nat n) (expr-from-nat (subst k s n))]

    ;; Rat (all non-binding)
    [(expr-Rat) e]
    [(expr-rat _) e]
    [(expr-rat-add a b) (expr-rat-add (subst k s a) (subst k s b))]
    [(expr-rat-sub a b) (expr-rat-sub (subst k s a) (subst k s b))]
    [(expr-rat-mul a b) (expr-rat-mul (subst k s a) (subst k s b))]
    [(expr-rat-div a b) (expr-rat-div (subst k s a) (subst k s b))]
    [(expr-rat-neg a) (expr-rat-neg (subst k s a))]
    [(expr-rat-abs a) (expr-rat-abs (subst k s a))]
    [(expr-rat-lt a b) (expr-rat-lt (subst k s a) (subst k s b))]
    [(expr-rat-le a b) (expr-rat-le (subst k s a) (subst k s b))]
    [(expr-rat-eq a b) (expr-rat-eq (subst k s a) (subst k s b))]
    [(expr-from-int n) (expr-from-int (subst k s n))]
    [(expr-rat-numer a) (expr-rat-numer (subst k s a))]
    [(expr-rat-denom a) (expr-rat-denom (subst k s a))]

    ;; Generic arithmetic (all non-binding)
    [(expr-generic-add a b) (expr-generic-add (subst k s a) (subst k s b))]
    [(expr-generic-sub a b) (expr-generic-sub (subst k s a) (subst k s b))]
    [(expr-generic-mul a b) (expr-generic-mul (subst k s a) (subst k s b))]
    [(expr-generic-div a b) (expr-generic-div (subst k s a) (subst k s b))]
    [(expr-generic-lt a b) (expr-generic-lt (subst k s a) (subst k s b))]
    [(expr-generic-le a b) (expr-generic-le (subst k s a) (subst k s b))]
    [(expr-generic-gt a b) (expr-generic-gt (subst k s a) (subst k s b))]
    [(expr-generic-ge a b) (expr-generic-ge (subst k s a) (subst k s b))]
    [(expr-generic-eq a b) (expr-generic-eq (subst k s a) (subst k s b))]
    [(expr-generic-mod a b) (expr-generic-mod (subst k s a) (subst k s b))]
    [(expr-generic-negate a) (expr-generic-negate (subst k s a))]
    [(expr-generic-abs a) (expr-generic-abs (subst k s a))]
    [(expr-generic-from-int t a) (expr-generic-from-int (subst k s t) (subst k s a))]
    [(expr-generic-from-rat t a) (expr-generic-from-rat (subst k s t) (subst k s a))]

    ;; Union types (non-binding)
    [(expr-union l r)
     (expr-union (subst k s l) (subst k s r))]

    ;; Unapplied type constructor (HKT) — no bound variables inside
    [(expr-tycon _) e]

    ;; Foreign function (opaque leaf — no Prologos sub-expressions)
    [(expr-foreign-fn _ _ _ _ _ _) e]

    ;; Reduce: arm bodies have binding-count binders
    [(expr-reduce scrut arms structural?)
     (expr-reduce (subst k s scrut)
                  (map (lambda (arm)
                         (define bc (expr-reduce-arm-binding-count arm))
                         (expr-reduce-arm
                          (expr-reduce-arm-ctor-name arm)
                          bc
                          (subst (+ k bc) (shift bc 0 s)
                                 (expr-reduce-arm-body arm))))
                       arms)
                  structural?)]))

;; ========================================
;; Open: substitute s for bvar(0)
;; open(e, s) = subst(0, s, e)
;; ========================================
(define (open-expr body arg)
  (subst 0 arg body))
