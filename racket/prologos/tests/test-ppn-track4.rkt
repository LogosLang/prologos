#lang racket/base

;;; test-ppn-track4.rkt — PPN Track 4: Elaboration as Attribute Evaluation
;;;
;;; Tests for Track 4 infrastructure: component-indexed firing, PU cell-trees,
;;; context lattice, DPO typing rules, etc. Phases add tests as they complete.

(require rackunit
         rackunit/text-ui
         prologos/propagator
         prologos/champ
         prologos/typing-propagators
         prologos/syntax
         prologos/prelude
         prologos/type-lattice
         (only-in prologos/typing-core infer))

;; ============================================================
;; Phase 1a: Component-indexed propagator firing
;; ============================================================

(define phase-1a-tests
  (test-suite
   "Phase 1a: component-indexed propagator firing"

   ;; --- pu-value-diff ---

   (test-case "pu-value-diff: identical hasheqs → empty diff"
     (define m (hasheq 'a 1 'b 2))
     (check-equal? (pu-value-diff m m) '()))

   (test-case "pu-value-diff: one key changed"
     (define old (hasheq 'a 1 'b 2 'c 3))
     (define new (hasheq 'a 1 'b 99 'c 3))
     (define diff (pu-value-diff old new))
     (check-equal? (sort diff symbol<?) '(b)))

   (test-case "pu-value-diff: key added"
     (define old (hasheq 'a 1))
     (define new (hasheq 'a 1 'b 2))
     (define diff (pu-value-diff old new))
     (check-equal? (sort diff symbol<?) '(b)))

   (test-case "pu-value-diff: key removed"
     (define old (hasheq 'a 1 'b 2))
     (define new (hasheq 'a 1))
     (define diff (pu-value-diff old new))
     (check-equal? (sort diff symbol<?) '(b)))

   (test-case "pu-value-diff: multiple keys changed"
     (define old (hasheq 'a 1 'b 2 'c 3))
     (define new (hasheq 'a 99 'b 2 'c 88))
     (define diff (pu-value-diff old new))
     (check-equal? (sort diff symbol<?) '(a c)))

   (test-case "pu-value-diff: non-hash values → #f (all changed)"
     (check-false (pu-value-diff 42 43))
     (check-false (pu-value-diff "hello" "world"))
     (check-false (pu-value-diff (hasheq 'a 1) 42)))

   ;; --- filter-dependents-by-paths ---

   (test-case "filter-dependents: all paths #f → all fire"
     (define deps (champ-insert
                   (champ-insert champ-empty 1 (prop-id 1) #f)
                   2 (prop-id 2) #f))
     (define result (filter-dependents-by-paths deps '(a)))
     (check-equal? (length result) 2))

   (test-case "filter-dependents: component match → fires"
     (define deps (champ-insert champ-empty 1 (prop-id 1) 'b))
     (define result (filter-dependents-by-paths deps '(b)))
     (check-equal? (length result) 1))

   (test-case "filter-dependents: component no match → skipped"
     (define deps (champ-insert champ-empty 1 (prop-id 1) 'b))
     (define result (filter-dependents-by-paths deps '(a)))
     (check-equal? (length result) 0))

   (test-case "filter-dependents: mixed paths, only matching fire"
     (define deps (champ-insert
                   (champ-insert
                    (champ-insert champ-empty 1 (prop-id 1) #f)     ;; watch all
                    2 (prop-id 2) 'a)                                ;; watch 'a
                   3 (prop-id 3) 'b))                                ;; watch 'b
     (define result (filter-dependents-by-paths deps '(a)))
     ;; prop-id 1 (watch all) + prop-id 2 (watch 'a) = 2
     (check-equal? (length result) 2))

   (test-case "filter-dependents: #f changed-paths → all fire"
     (define deps (champ-insert
                   (champ-insert champ-empty 1 (prop-id 1) 'a)
                   2 (prop-id 2) 'b))
     (define result (filter-dependents-by-paths deps #f))
     (check-equal? (length result) 2))

   ;; --- Integration: component-indexed propagator on network ---

   (test-case "component-indexed propagator: only fires on watched component"
     ;; Create a network with one cell holding a hasheq PU value
     (define fire-count (box 0))
     (define net0 (make-prop-network))
     (define-values (net1 cid)
       (net-new-cell net0 (hasheq 'a 0 'b 0)
                     (lambda (old new)
                       ;; Merge: pointwise max
                       (for/hasheq ([(k v) (in-hash new)])
                         (values k (max v (hash-ref old k 0)))))))
     ;; Add a propagator that watches only component 'a
     (define-values (net2 pid)
       (net-add-propagator net1
                           (list cid) '()
                           (lambda (net)
                             (set-box! fire-count (add1 (unbox fire-count)))
                             net)
                           #:component-paths (list (cons cid 'a))))
     ;; Drain initial firing (net-add-propagator schedules initial fire)
     (define net2q (run-to-quiescence net2))
     (set-box! fire-count 0)
     ;; Write to component 'b — propagator should NOT fire
     (define net3 (run-to-quiescence
                   (net-cell-write net2q cid (hasheq 'a 0 'b 99))))
     (check-equal? (unbox fire-count) 0
                   "propagator watching 'a should not fire when only 'b changed")
     ;; Write to component 'a — propagator SHOULD fire
     (set-box! fire-count 0)
     (define net4 (run-to-quiescence
                   (net-cell-write net3 cid (hasheq 'a 42 'b 99))))
     (check-equal? (unbox fire-count) 1
                   "propagator watching 'a should fire when 'a changed"))

   (test-case "backward compat: propagator without component-paths fires on any change"
     (define fire-count (box 0))
     (define net0 (make-prop-network))
     (define-values (net1 cid)
       (net-new-cell net0 (hasheq 'a 0 'b 0)
                     (lambda (old new)
                       (for/hasheq ([(k v) (in-hash new)])
                         (values k (max v (hash-ref old k 0)))))))
     ;; Add propagator WITHOUT component-paths (default = watch all)
     (define-values (net2 pid)
       (net-add-propagator net1 (list cid) '()
                           (lambda (net)
                             (set-box! fire-count (add1 (unbox fire-count)))
                             net)))
     ;; Drain initial firing
     (define net2q (run-to-quiescence net2))
     (set-box! fire-count 0)
     ;; Write to component 'b — propagator SHOULD fire (no filtering)
     (define net3 (run-to-quiescence
                   (net-cell-write net2q cid (hasheq 'a 0 'b 99))))
     (check-equal? (unbox fire-count) 1
                   "propagator without component-paths should fire on any change"))
   ))


;; ============================================================
;; Phase 1c: Context lattice
;; ============================================================

(define phase-1c-tests
  (test-suite
   "Phase 1c: context lattice"

   (test-case "context-empty-value is empty"
     (check-equal? (context-cell-value-bindings context-empty-value) '())
     (check-equal? (context-cell-value-depth context-empty-value) 0))

   (test-case "context-extend-value adds binding at head"
     (define ctx1 (context-extend-value context-empty-value (expr-Nat) 'mw))
     (check-equal? (context-cell-value-depth ctx1) 1)
     (check-equal? (length (context-cell-value-bindings ctx1)) 1)
     (define ctx2 (context-extend-value ctx1 (expr-Int) 'm1))
     (check-equal? (context-cell-value-depth ctx2) 2)
     (check-equal? (length (context-cell-value-bindings ctx2)) 2))

   (test-case "context-lookup-type: de Bruijn indexing"
     (define ctx (context-extend-value
                  (context-extend-value context-empty-value (expr-Nat) 'mw)
                  (expr-Int) 'm1))
     ;; Position 0 = most recent = Int
     (check-equal? (context-lookup-type ctx 0) (expr-Int))
     ;; Position 1 = earlier = Nat
     (check-equal? (context-lookup-type ctx 1) (expr-Nat))
     ;; Position 2 = out of bounds = error
     (check-pred expr-error? (context-lookup-type ctx 2)))

   (test-case "context-lookup-mult: de Bruijn indexing"
     (define ctx (context-extend-value
                  (context-extend-value context-empty-value (expr-Nat) 'mw)
                  (expr-Int) 'm1))
     (check-equal? (context-lookup-mult ctx 0) 'm1)
     (check-equal? (context-lookup-mult ctx 1) 'mw)
     (check-false (context-lookup-mult ctx 2)))

   (test-case "context-cell-merge: bot with non-bot → non-bot"
     (define ctx (context-extend-value context-empty-value (expr-Nat) 'mw))
     (check-equal? (context-cell-value-depth (context-cell-merge context-empty-value ctx)) 1)
     (check-equal? (context-cell-value-depth (context-cell-merge ctx context-empty-value)) 1))

   (test-case "context-cell-merge: same depth → pointwise"
     (define ctx1 (context-extend-value context-empty-value (expr-Nat) 'mw))
     (define ctx2 (context-extend-value context-empty-value (expr-Int) 'mw))
     (define merged (context-cell-merge ctx1 ctx2))
     ;; Both depth 1, pointwise merge takes newer (ctx2's Int)
     (check-equal? (context-cell-value-depth merged) 1)
     (check-equal? (context-lookup-type merged 0) (expr-Int)))

   (test-case "context-cell-merge: different depth → deeper wins"
     (define ctx1 (context-extend-value context-empty-value (expr-Nat) 'mw))
     (define ctx2 (context-extend-value ctx1 (expr-Int) 'm1))
     ;; ctx1 is depth 1, ctx2 is depth 2
     (define merged (context-cell-merge ctx1 ctx2))
     (check-equal? (context-cell-value-depth merged) 2))

   (test-case "context-cell-contradicts? always #f"
     (check-false (context-cell-contradicts? context-empty-value))
     (check-false (context-cell-contradicts?
                   (context-extend-value context-empty-value (expr-Nat) 'mw))))
   ))


;; ============================================================
;; Phase 2a: Typing rule infrastructure
;; ============================================================

(define phase-2a-tests
  (test-suite
   "Phase 2a: typing rule infrastructure"

   (test-case "registry: create empty"
     (define reg (make-typing-rule-registry))
     (check-equal? (length (typing-rule-registry-rules reg)) 0))

   (test-case "registry: add and lookup"
     (define reg (make-typing-rule-registry))
     (define rule (typing-rule
                   'expr-int 'int-literal 0
                   (lambda (ctx e reader) (expr-Int))
                   #f  ;; no check-fn
                   0))
     (typing-rule-registry-add! reg rule)
     (check-equal? (length (typing-rule-registry-rules reg)) 1)
     (check-eq? (typing-rule-registry-lookup reg 'expr-int) rule)
     (check-false (typing-rule-registry-lookup reg 'expr-nat)))

   (test-case "dispatch: infer with matching rule"
     (define reg (make-typing-rule-registry))
     (typing-rule-registry-add! reg
       (typing-rule
        'test-lit 'test-literal 0
        (lambda (ctx e reader) (expr-Int))
        #f 0))
     (define result
       (dispatch-typing-rule reg (lambda (e) 'test-lit)
                             context-empty-value 'dummy-expr
                             (lambda (pos) #f)))
     (check-equal? result (cons 'ok (expr-Int))))

   (test-case "dispatch: no matching rule → #f (imperative fallback)"
     (define reg (make-typing-rule-registry))
     (define result
       (dispatch-typing-rule reg (lambda (e) 'unknown-tag)
                             context-empty-value 'dummy-expr
                             (lambda (pos) #f)))
     (check-false result))

   (test-case "dispatch: check mode with matching rule"
     (define reg (make-typing-rule-registry))
     (typing-rule-registry-add! reg
       (typing-rule
        'test-lit 'test-literal 0
        (lambda (ctx e reader) (expr-Int))
        (lambda (ctx e expected reader) (equal? expected (expr-Int)))
        0))
     ;; Check against Int → #t
     (define result-ok
       (dispatch-typing-rule reg (lambda (e) 'test-lit)
                             context-empty-value 'dummy-expr
                             (lambda (pos) #f)
                             #:expected-type (expr-Int)))
     (check-equal? result-ok (cons 'check #t))
     ;; Check against Nat → #f
     (define result-fail
       (dispatch-typing-rule reg (lambda (e) 'test-lit)
                             context-empty-value 'dummy-expr
                             (lambda (pos) #f)
                             #:expected-type (expr-Nat)))
     (check-equal? result-fail (cons 'check #f)))

   (test-case "typing-rule struct is inspectable"
     (define rule (typing-rule 'expr-app 'app-tensor 2
                               (lambda (ctx e reader) #f)
                               #f 0))
     (check-eq? (typing-rule-tag rule) 'expr-app)
     (check-eq? (typing-rule-name rule) 'app-tensor)
     (check-equal? (typing-rule-arity rule) 2)
     (check-equal? (typing-rule-stratum rule) 0))
   ))


;; ============================================================
;; Phase 2b: Literal + universe typing rules
;; ============================================================

(define phase-2b-tests
  (let ()
    (define reg (make-typing-rule-registry))
    (register-literal-typing-rules! reg)
    (register-universe-typing-rules! reg)

    (define (infer-via-rule e)
      (dispatch-typing-rule reg expr-typing-tag context-empty-value e
                            (lambda (pos) #f)))

    (define (check-via-rule e expected)
      (dispatch-typing-rule reg expr-typing-tag context-empty-value e
                            (lambda (pos) #f)
                            #:expected-type expected))

    (test-suite
     "Phase 2b: literal + universe typing rules"

     (test-case "int literal: 42 → Int"
       (check-equal? (infer-via-rule (expr-int 42)) (cons 'ok (expr-Int))))

     (test-case "nat literal: (nat-val 3) → Nat"
       (check-equal? (infer-via-rule (expr-nat-val 3)) (cons 'ok (expr-Nat))))

     (test-case "true → Bool"
       (check-equal? (infer-via-rule (expr-true)) (cons 'ok (expr-Bool))))

     (test-case "false → Bool"
       (check-equal? (infer-via-rule (expr-false)) (cons 'ok (expr-Bool))))

     (test-case "Int : Type 0"
       (check-equal? (infer-via-rule (expr-Int)) (cons 'ok (expr-Type (lzero)))))

     (test-case "Nat : Type 0"
       (check-equal? (infer-via-rule (expr-Nat)) (cons 'ok (expr-Type (lzero)))))

     (test-case "Bool : Type 0"
       (check-equal? (infer-via-rule (expr-Bool)) (cons 'ok (expr-Type (lzero)))))

     (test-case "String : Type 0"
       (check-equal? (infer-via-rule (expr-String)) (cons 'ok (expr-Type (lzero)))))

     (test-case "Type 0 : Type 1"
       (define result (infer-via-rule (expr-Type (lzero))))
       (check-equal? result (cons 'ok (expr-Type (lsuc (lzero))))))

     (test-case "Type 1 : Type 2"
       (define result (infer-via-rule (expr-Type (lsuc (lzero)))))
       (check-equal? result (cons 'ok (expr-Type (lsuc (lsuc (lzero)))))))

     (test-case "check: 42 : Int → #t"
       (check-equal? (check-via-rule (expr-int 42) (expr-Int))
                     (cons 'check #t)))

     (test-case "check: 42 : Nat → #f"
       (check-equal? (check-via-rule (expr-int 42) (expr-Nat))
                     (cons 'check #f)))

     (test-case "check: true : Bool → #t"
       (check-equal? (check-via-rule (expr-true) (expr-Bool))
                     (cons 'check #t)))

     (test-case "unknown expr tag → #f (imperative fallback)"
       (check-false (infer-via-rule (expr-app (expr-int 1) (expr-int 2)))))

     (test-case "tag extraction works for all registered types"
       (check-eq? (expr-typing-tag (expr-int 42)) 'expr-int)
       (check-eq? (expr-typing-tag (expr-true)) 'expr-true)
       (check-eq? (expr-typing-tag (expr-Int)) 'expr-Int)
       (check-eq? (expr-typing-tag (expr-Type (lzero))) 'expr-Type)
       (check-eq? (expr-typing-tag (expr-app (expr-int 1) (expr-int 2))) 'expr-app))
     )))


;; ============================================================
;; Run
;; ============================================================

;; ============================================================
;; Phase 2c: Variable lookup typing rules
;; ============================================================

(define phase-2c-tests
  (let ()
    (define reg (make-typing-rule-registry))
    (register-variable-typing-rules! reg)

    (define (infer-with-ctx ctx-val e)
      (dispatch-typing-rule reg expr-typing-tag ctx-val e
                            (lambda (pos) #f)))

    (test-suite
     "Phase 2c: variable lookup typing rules"

     (test-case "bvar 0: most recent binding"
       (define ctx (context-extend-value context-empty-value (expr-Int) 'mw))
       ;; bvar(0) in ctx with [Int] → Int (shifted by 1, but Int has no bvars → stays Int)
       (define result (infer-with-ctx ctx (expr-bvar 0)))
       (check-equal? result (cons 'ok (expr-Int))))

     (test-case "bvar 1: earlier binding"
       (define ctx (context-extend-value
                    (context-extend-value context-empty-value (expr-Nat) 'mw)
                    (expr-Int) 'm1))
       ;; bvar(1) → Nat (shifted by 2, but Nat has no bvars → stays Nat)
       (define result (infer-with-ctx ctx (expr-bvar 1)))
       (check-equal? result (cons 'ok (expr-Nat))))

     (test-case "bvar out of bounds: returns #f"
       (define result (infer-with-ctx context-empty-value (expr-bvar 0)))
       (check-false result))

     ;; fvar tests require global-env state — skip for unit tests.
     ;; fvar is tested via the acceptance file (process-file) at Level 3.
     (test-case "fvar rule registered"
       (check-true (typing-rule? (typing-rule-registry-lookup reg 'expr-fvar))))
     )))


;; ============================================================
;; Phase 2d: Lambda + Pi + Sigma formation typing rules
;; ============================================================

(define phase-2d-tests
  (let ()
    (define reg (make-typing-rule-registry))
    (register-binder-typing-rules! reg)

    (test-suite
     "Phase 2d: lambda + Pi + Sigma formation typing rules"

     (test-case "lambda: (lam mw Int body) where body:Bool → Pi(mw, Int, Bool)"
       (define lam-expr (expr-lam 'mw (expr-Int) (expr-bvar 0)))
       ;; Simulate type-map: dom=(expr-Int) has type Type(0), body has type Bool
       (define reader
         (lambda (sub-e)
           (cond
             [(equal? sub-e (expr-Int)) (expr-Type (lzero))]   ;; Int : Type 0
             [(equal? sub-e (expr-bvar 0)) (expr-Bool)]         ;; body : Bool
             [else #f])))
       (define result
         (dispatch-typing-rule reg expr-typing-tag context-empty-value
                               lam-expr reader))
       (check-equal? result (cons 'ok (expr-Pi 'mw (expr-Int) (expr-Bool)))))

     (test-case "lambda: hole domain → #f in infer mode"
       (define lam-expr (expr-lam 'mw (expr-hole) (expr-bvar 0)))
       (define result
         (dispatch-typing-rule reg expr-typing-tag context-empty-value
                               lam-expr (lambda (_) #f)))
       (check-false result))

     (test-case "lambda check: hole domain accepts expected Pi domain"
       (define lam-expr (expr-lam 'mw (expr-hole) (expr-bvar 0)))
       (define expected (expr-Pi 'mw (expr-Int) (expr-Bool)))
       (define reader
         (lambda (sub-e)
           (cond
             [(equal? sub-e (expr-bvar 0)) (expr-Bool)]
             [else #f])))
       (define result
         (dispatch-typing-rule reg expr-typing-tag context-empty-value
                               lam-expr reader
                               #:expected-type expected))
       (check-equal? result (cons 'check #t)))

     (test-case "lambda: sub-expression not ready → not-ready"
       (define lam-expr (expr-lam 'mw (expr-Int) (expr-bvar 0)))
       (define reader
         (lambda (sub-e)
           (cond
             [(equal? sub-e (expr-Int)) (expr-Type (lzero))]
             [else #f])))  ;; body not typed yet
       (define result
         (dispatch-typing-rule reg expr-typing-tag context-empty-value
                               lam-expr reader))
       (check-false result))  ;; not-ready → #f

     (test-case "Pi formation: Pi(mw, Int, Bool) → Type(max(0,0)) = Type(0)"
       (define pi-expr (expr-Pi 'mw (expr-Int) (expr-Bool)))
       (define reader
         (lambda (sub-e)
           (cond
             [(equal? sub-e (expr-Int)) (expr-Type (lzero))]
             [(equal? sub-e (expr-Bool)) (expr-Type (lzero))]
             [else #f])))
       (define result
         (dispatch-typing-rule reg expr-typing-tag context-empty-value
                               pi-expr reader))
       (check-equal? result (cons 'ok (expr-Type (lmax (lzero) (lzero))))))

     (test-case "Sigma formation: Sigma(Int, Bool) → Type(0)"
       (define sig-expr (expr-Sigma (expr-Int) (expr-Bool)))
       (define reader
         (lambda (sub-e)
           (cond
             [(equal? sub-e (expr-Int)) (expr-Type (lzero))]
             [(equal? sub-e (expr-Bool)) (expr-Type (lzero))]
             [else #f])))
       (define result
         (dispatch-typing-rule reg expr-typing-tag context-empty-value
                               sig-expr reader))
       (check-equal? result (cons 'ok (expr-Type (lmax (lzero) (lzero))))))

     (test-case "Pi formation: sub-expression not a type → #f"
       (define pi-expr (expr-Pi 'mw (expr-int 42) (expr-Bool)))
       (define reader
         (lambda (sub-e)
           (cond
             [(equal? sub-e (expr-int 42)) (expr-Int)]   ;; 42 : Int, not Type
             [(equal? sub-e (expr-Bool)) (expr-Type (lzero))]
             [else #f])))
       (define result
         (dispatch-typing-rule reg expr-typing-tag context-empty-value
                               pi-expr reader))
       (check-false result))
     )))

;; ============================================================
;; Phase 2e: Application (tensor) + projection typing rules
;; ============================================================

(define phase-2e-tests
  (let ()
    (define reg (make-typing-rule-registry))
    (register-application-typing-rules! reg)

    (test-suite
     "Phase 2e: application (tensor) + projection typing rules"

     (test-case "app: [Int→Bool applied to Int] → Bool"
       (define app-expr (expr-app (expr-fvar 'f) (expr-int 42)))
       (define reader
         (lambda (sub-e)
           (cond
             [(equal? sub-e (expr-fvar 'f)) (expr-Pi 'mw (expr-Int) (expr-Bool))]
             [(equal? sub-e (expr-int 42)) (expr-Int)]
             [else #f])))
       (define result
         (dispatch-typing-rule reg expr-typing-tag context-empty-value
                               app-expr reader))
       ;; type-tensor-core(Pi(mw, Int, Bool), Int) → Bool (via subst)
       (check-equal? (cdr result) (expr-Bool)))

     (test-case "app: func type not ready → not-ready"
       (define app-expr (expr-app (expr-fvar 'f) (expr-int 42)))
       (define reader (lambda (sub-e) #f))
       (define result
         (dispatch-typing-rule reg expr-typing-tag context-empty-value
                               app-expr reader))
       (check-false result))

     (test-case "app: non-Pi func → #f (error)"
       (define app-expr (expr-app (expr-int 1) (expr-int 2)))
       (define reader
         (lambda (sub-e)
           (cond
             [(equal? sub-e (expr-int 1)) (expr-Int)]  ;; Int is not a Pi
             [(equal? sub-e (expr-int 2)) (expr-Int)]
             [else #f])))
       (define result
         (dispatch-typing-rule reg expr-typing-tag context-empty-value
                               app-expr reader))
       (check-false result))

     (test-case "fst: fst(Sigma(Int, Bool)) → Int"
       (define fst-expr (expr-fst (expr-fvar 'p)))
       (define reader
         (lambda (sub-e)
           (if (equal? sub-e (expr-fvar 'p))
               (expr-Sigma (expr-Int) (expr-Bool))
               #f)))
       (define result
         (dispatch-typing-rule reg expr-typing-tag context-empty-value
                               fst-expr reader))
       (check-equal? result (cons 'ok (expr-Int))))

     (test-case "snd: snd(Sigma(Int, Bool)) → Bool"
       (define snd-expr (expr-snd (expr-fvar 'p)))
       (define reader
         (lambda (sub-e)
           (if (equal? sub-e (expr-fvar 'p))
               (expr-Sigma (expr-Int) (expr-Bool))
               #f)))
       (define result
         (dispatch-typing-rule reg expr-typing-tag context-empty-value
                               snd-expr reader))
       (check-equal? result (cons 'ok (expr-Bool))))

     (test-case "fst on non-Sigma → #f"
       (define fst-expr (expr-fst (expr-fvar 'x)))
       (define reader
         (lambda (sub-e)
           (if (equal? sub-e (expr-fvar 'x)) (expr-Int) #f)))
       (define result
         (dispatch-typing-rule reg expr-typing-tag context-empty-value
                               fst-expr reader))
       (check-false result))
     )))

;; ============================================================
;; Phase 3: Integration — typing-rule-aware infer parity
;; ============================================================

(define phase-3-tests
  (let ()
    ;; Create rule-infer that falls back to imperative infer
    (define rule-infer (make-typing-rule-infer infer))
    (define ctx ctx-empty)

    (test-suite
     "Phase 3: typing-rule-aware infer parity with imperative"

     ;; Literals: rule-infer should match imperative infer
     (test-case "parity: int literal"
       (define e (expr-int 42))
       (check-equal? (rule-infer ctx e) (infer ctx e)))

     (test-case "parity: nat literal"
       (define e (expr-nat-val 3))
       (check-equal? (rule-infer ctx e) (infer ctx e)))

     (test-case "parity: true"
       (check-equal? (rule-infer ctx (expr-true)) (infer ctx (expr-true))))

     (test-case "parity: false"
       (check-equal? (rule-infer ctx (expr-false)) (infer ctx (expr-false))))

     ;; Type constructors
     (test-case "parity: Int type"
       (check-equal? (rule-infer ctx (expr-Int)) (infer ctx (expr-Int))))

     (test-case "parity: Nat type"
       (check-equal? (rule-infer ctx (expr-Nat)) (infer ctx (expr-Nat))))

     (test-case "parity: Bool type"
       (check-equal? (rule-infer ctx (expr-Bool)) (infer ctx (expr-Bool))))

     ;; Universe
     (test-case "parity: Type 0"
       (define e (expr-Type (lzero)))
       (check-equal? (rule-infer ctx e) (infer ctx e)))

     ;; Application (tensor): [int+ applied to args]
     ;; This requires global env for int+ — test with a simple Pi
     (test-case "parity: application of lambda to arg"
       ;; (\x:Int. x) 42  — should infer Int
       (define lam (expr-lam 'mw (expr-Int) (expr-bvar 0)))
       (define app (expr-app lam (expr-int 42)))
       (define imperative-result (infer ctx app))
       (define rule-result (rule-infer ctx app))
       ;; Both should produce Int (or at least be equal)
       (check-equal? rule-result imperative-result))

     ;; Fallback: expressions without rules still work
     (test-case "fallback: error expression"
       (define e (expr-error))
       ;; expr-error has no typing rule → falls back to imperative
       (check-equal? (rule-infer ctx e) (infer ctx e)))
     )))

(run-tests phase-1a-tests)
(run-tests phase-1c-tests)
(run-tests phase-2a-tests)
(run-tests phase-2b-tests)
(run-tests phase-2c-tests)
(run-tests phase-2d-tests)
(run-tests phase-2e-tests)
(run-tests phase-3-tests)
