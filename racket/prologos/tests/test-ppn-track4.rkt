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
         prologos/prelude)

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

(run-tests phase-1a-tests)
(run-tests phase-1c-tests)
(run-tests phase-2a-tests)
(run-tests phase-2b-tests)
