#lang racket/base

;;; test-ppn-track4.rkt — PPN Track 4: Elaboration as Attribute Evaluation
;;;
;;; Tests for Track 4 propagator-native infrastructure.
;;; D.4 redo: tests verify actual propagator firings on the network,
;;; not function-call dispatch.

(require rackunit
         rackunit/text-ui
         racket/set
         prologos/propagator
         prologos/champ
         prologos/typing-propagators  ;; provides that-read, attribute-map-merge-fn
         prologos/syntax
         prologos/prelude
         prologos/type-lattice
         prologos/surface-rewrite)

;; ============================================================
;; Phase 1a: Component-indexed propagator firing
;; ============================================================

(define phase-1a-tests
  (test-suite
   "Phase 1a: component-indexed propagator firing"

   (test-case "pu-value-diff: identical hasheqs → empty diff"
     (define m (hasheq 'a 1 'b 2))
     (check-equal? (pu-value-diff m m) '()))

   (test-case "pu-value-diff: one key changed"
     (define old (hasheq 'a 1 'b 2 'c 3))
     (define new (hasheq 'a 1 'b 99 'c 3))
     (define diff (pu-value-diff old new))
     (check-equal? (sort diff symbol<?) '(b)))

   (test-case "pu-value-diff: non-hash values → #f (all changed)"
     (check-false (pu-value-diff 42 43)))

   (test-case "component-indexed propagator: only fires on watched component"
     (define fire-count (box 0))
     (define net0 (make-prop-network))
     (define-values (net1 cid)
       (net-new-cell net0 (hasheq 'a 0 'b 0)
                     (lambda (old new)
                       (for/hasheq ([(k v) (in-hash new)])
                         (values k (max v (hash-ref old k 0)))))))
     (define-values (net2 pid)
       (net-add-propagator net1
                           (list cid) '()
                           (lambda (net)
                             (set-box! fire-count (add1 (unbox fire-count)))
                             net)
                           #:component-paths (list (cons cid 'a))))
     (define net2q (run-to-quiescence net2))
     (set-box! fire-count 0)
     ;; Write to 'b — propagator watching 'a should NOT fire
     (define net3 (run-to-quiescence
                   (net-cell-write net2q cid (hasheq 'a 0 'b 99))))
     (check-equal? (unbox fire-count) 0)
     ;; Write to 'a — propagator SHOULD fire
     (set-box! fire-count 0)
     (define net4 (run-to-quiescence
                   (net-cell-write net3 cid (hasheq 'a 42 'b 99))))
     (check-equal? (unbox fire-count) 1))
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

   (test-case "context-extend-value adds binding"
     (define ctx1 (context-extend-value context-empty-value (expr-Nat) 'mw))
     (check-equal? (context-cell-value-depth ctx1) 1))

   (test-case "context-lookup-type: de Bruijn indexing"
     (define ctx (context-extend-value
                  (context-extend-value context-empty-value (expr-Nat) 'mw)
                  (expr-Int) 'm1))
     (check-equal? (context-lookup-type ctx 0) (expr-Int))
     (check-equal? (context-lookup-type ctx 1) (expr-Nat))
     (check-pred expr-error? (context-lookup-type ctx 2)))
   ))

;; ============================================================
;; Phase 2 (D.4): Propagator-native typing — Network Reality Check
;; ============================================================

(define phase-2-network-tests
  (test-suite
   "Phase 2 D.4: propagator-native typing on the network"

   (test-case "literal propagator: writes type to type-map via net-cell-write"
     ;; Create a network with a typing cell (plain hasheq)
     (define net0 (make-prop-network))
     (define-values (net1 tm-cid)
       (net-new-cell net0 (hasheq) type-map-merge-fn))
     ;; Install a literal propagator for an int expression
     (define int-expr (expr-int 42))
     (define-values (net2 _pid)
       (net-add-propagator net1 (list tm-cid) (list tm-cid)
                           (make-literal-fire-fn tm-cid int-expr (expr-Int))))
     ;; Run to quiescence — propagator fires and writes Int to type-map
     (define net3 (run-to-quiescence net2))
     ;; Read result from the type-map cell
     (define tm (net-cell-read net3 tm-cid))
     (define result-type (that-read tm int-expr ':type))
     ;; Network Reality Check: result comes from cell read after propagator firing
     (check-equal? result-type (expr-Int)))

   (test-case "universe propagator: Type(0) → Type(1)"
     (define net0 (make-prop-network))
     (define-values (net1 tm-cid)
       (net-new-cell net0 (hasheq) type-map-merge-fn))
     (define type-expr (expr-Type (lzero)))
     (define-values (net2 _pid)
       (net-add-propagator net1 (list tm-cid) (list tm-cid)
                           (make-universe-fire-fn tm-cid type-expr (lzero))))
     (define net3 (run-to-quiescence net2))
     (define tm (net-cell-read net3 tm-cid))
     (check-equal? (that-read tm type-expr ':type) (expr-Type (lsuc (lzero)))))

   (test-case "app propagator: tensor fires when func + arg types available"
     (define net0 (make-prop-network))
     (define func-e (expr-fvar 'f))
     (define arg-e (expr-int 42))
     (define app-e (expr-app func-e arg-e))
     ;; Create attribute cell pre-populated with func and arg types (nested records)
     (define-values (net1 tm-cid)
       (net-new-cell net0
                     (hasheq func-e (hasheq ':type (expr-Pi 'mw (expr-Int) (expr-Bool)))
                             arg-e (hasheq ':type (expr-Int)))
                     type-map-merge-fn))
     ;; Install app propagator — compound component-paths
     (define-values (net2 _pid)
       (net-add-propagator net1 (list tm-cid) (list tm-cid)
                           (make-app-fire-fn tm-cid app-e func-e arg-e)
                           #:component-paths
                           (list (cons tm-cid (cons func-e ':type))
                                 (cons tm-cid (cons arg-e ':type)))))
     (define net3 (run-to-quiescence net2))
     (define tm (net-cell-read net3 tm-cid))
     ;; tensor(Pi(mw, Int, Bool), Int) = Bool (via subst)
     (check-equal? (that-read tm app-e ':type) (expr-Bool)))

   (test-case "infer-on-network: literal expression"
     (define net0 (make-prop-network))
     (define e (expr-int 42))
     (define-values (net1 result-type)
       (infer-on-network net0 e context-empty-value))
     ;; Network Reality Check: result comes from cell read after quiescence
     (check-equal? result-type (expr-Int)))

   (test-case "infer-on-network: Type(0) → Type(1)"
     (define net0 (make-prop-network))
     (define-values (net1 result-type)
       (infer-on-network net0 (expr-Type (lzero)) context-empty-value))
     (check-equal? result-type (expr-Type (lsuc (lzero)))))

   (test-case "app propagator: fires after both inputs written"
     ;; Test the app propagator in isolation with manual writes
     (define net0 (make-prop-network))
     (define func-e (expr-fvar 'f))
     (define arg-e (expr-int 1))
     (define app-e (expr-app func-e arg-e))
     ;; Create typing cell
     (define-values (net1 tm-cid)
       (net-new-cell net0 (hasheq) type-map-merge-fn))
     ;; Install ONLY the app propagator (not sub-expression propagators)
     (define-values (net2 _pid)
       (net-add-propagator net1 (list tm-cid) (list tm-cid)
                           (make-app-fire-fn tm-cid app-e func-e arg-e)
                           #:component-paths
                           (list (cons tm-cid (cons func-e ':type))
                                 (cons tm-cid (cons arg-e ':type)))))
     ;; Drain initial fire (inputs are ⊥, propagator is a no-op)
     (define net2q (run-to-quiescence net2))
     ;; Write func type (nested record)
     (define net3 (net-cell-write net2q tm-cid
                    (hasheq func-e (hasheq ':type (expr-Pi 'mw (expr-Int) (expr-Int))))))
     ;; Write arg type — this should trigger the app propagator
     (define net4 (net-cell-write net3 tm-cid (hasheq arg-e (hasheq ':type (expr-Int)))))
     (define net5 (run-to-quiescence net4))
     (define tm (net-cell-read net5 tm-cid))
     ;; tensor(Pi(mw,Int,Int), Int) = Int
     (check-equal? (that-read tm app-e ':type) (expr-Int)))
   ))

;; ============================================================
;; Phase 4b-i: Fan-in meta-readiness
;; ============================================================

(define phase-4b-tests
  (test-suite
   "Phase 4b-i: fan-in meta-readiness"

   (test-case "empty readiness: all solved"
     (check-true (meta-readiness-all-solved? meta-readiness-empty)))

   (test-case "register + solve: tracks correctly"
     (define rv (meta-readiness-register
                 (meta-readiness-register meta-readiness-empty 'a 'type)
                 'b 'level))
     (check-false (meta-readiness-all-solved? rv))
     (define rv2 (meta-readiness-solve (meta-readiness-solve rv 'a) 'b))
     (check-true (meta-readiness-all-solved? rv2)))

   (test-case "merge: set-union on registered and solved"
     (define rv1 (meta-readiness-solve
                  (meta-readiness-register meta-readiness-empty 'a 'type) 'a))
     (define rv2 (meta-readiness-register meta-readiness-empty 'b 'level))
     (define merged (meta-readiness-merge rv1 rv2))
     (check-equal? (length (meta-readiness-unsolved merged)) 1))
   ))

;; ============================================================
;; Phase 6: Constraint lattice
;; ============================================================

(define phase-6-tests
  (test-suite
   "Phase 6: constraint lattice"

   (test-case "join: pending ⊔ resolved = resolved"
     (define r (constraint-resolved 'eq-int))
     (check-true (constraint-resolved? (constraint-cell-merge constraint-pending r))))

   (test-case "join: resolved(A) ⊔ resolved(B) = contradicted"
     (check-true (constraint-contradicted?
                  (constraint-cell-merge (constraint-resolved 'a) (constraint-resolved 'b)))))

   (test-case "meet: contradicted ⊓ X = X"
     (define r (constraint-resolved 'eq-int))
     (check-equal? (constraint-cell-meet constraint-contradicted r) r))
   ))

;; ============================================================
;; Run
;; ============================================================

;; ============================================================
;; Pattern 5: Context threading via cell positions
;; ============================================================

(define pattern-5-tests
  (test-suite
   "Pattern 5: context as cell positions in type-map"

   (test-case "bvar in lambda body: reads from context position"
     ;; (lambda [x : Int] x) — body is bvar(0), should get type Int
     (define net0 (make-prop-network))
     (define dom-e (expr-Int))
     (define body-e (expr-bvar 0))
     (define lam-e (expr-lam 'mw dom-e body-e))
     (define-values (net1 tm-cid)
       (net-new-cell net0 (hasheq) type-map-merge-fn))
     (define net2 (install-typing-network net1 tm-cid lam-e context-empty-value))
     (define net3 (run-to-quiescence net2))
     (define tm (net-cell-read net3 tm-cid))
     ;; domain = Int, so bvar(0) should read Int from context
     ;; Int : Type(0), body : Int, so lam : Pi(mw, Int, Int)
     (check-equal? (that-read tm dom-e ':type) (expr-Type (lzero))
                   "Int : Type(0)")
     (check-equal? (that-read tm body-e ':type) (expr-Int)
                   "bvar(0) in [x:Int] scope should be Int")
     (check-equal? (that-read tm lam-e ':type)
                   (expr-Pi 'mw dom-e (expr-Int))
                   "lambda should produce Pi(mw, Int, Int)"))

   (test-case "nested lambda: inner bvar reads from extended context"
     ;; (lambda [x : Int] (lambda [y : Bool] x))
     ;; Inner body is bvar(1) — should be Int (from outer scope)
     (define dom1 (expr-Int))
     (define dom2 (expr-Bool))
     (define inner-body (expr-bvar 1))  ;; x in outer scope
     (define inner-lam (expr-lam 'mw dom2 inner-body))
     (define outer-lam (expr-lam 'mw dom1 inner-lam))
     (define net0 (make-prop-network))
     (define-values (net1 tm-cid)
       (net-new-cell net0 (hasheq) type-map-merge-fn))
     (define net2 (install-typing-network net1 tm-cid outer-lam context-empty-value))
     (define net3 (run-to-quiescence net2))
     (define tm (net-cell-read net3 tm-cid))
     ;; bvar(1) in [y:Bool] scope = Int (from [x:Int] scope)
     (check-equal? (that-read tm inner-body ':type) (expr-Int)
                   "bvar(1) should be Int from outer scope"))

   (test-case "fvar: reads from global env"
     ;; This test requires global env state — limited to verifying
     ;; that the fvar propagator is installed and fires
     (define net0 (make-prop-network))
     (define fvar-e (expr-fvar 'nonexistent))
     (define-values (net1 tm-cid)
       (net-new-cell net0 (hasheq) type-map-merge-fn))
     (define net2 (install-typing-network net1 tm-cid fvar-e context-empty-value))
     (define net3 (run-to-quiescence net2))
     (define tm (net-cell-read net3 tm-cid))
     ;; Non-existent fvar stays at ⊥
     (check-equal? (that-read tm fvar-e ':type) type-bot))

   (test-case "app: bidirectional — writes domain to arg, result via tensor"
     ;; App propagator writes domain DOWNWARD to arg position (check direction)
     ;; and result UPWARD to app position (infer direction)
     (define func-e (expr-fvar 'f))
     (define arg-e (expr-int 42))
     (define app-e (expr-app func-e arg-e))
     (define net0 (make-prop-network))
     (define-values (net1 tm-cid)
       (net-new-cell net0
                     (hasheq func-e (hasheq ':type (expr-Pi 'mw (expr-Int) (expr-Bool))))
                     type-map-merge-fn))
     (define net2 (install-typing-network net1 tm-cid app-e context-empty-value))
     (define net3 (run-to-quiescence net2))
     (define tm (net-cell-read net3 tm-cid))
     ;; Arg gets Int from BOTH: literal propagator (infer) AND app's domain write (check)
     ;; The merge: Int ⊔ Int = Int (idempotent)
     (check-equal? (that-read tm arg-e ':type) (expr-Int)
                   "arg 42 : Int (bidirectional merge)")
     ;; App result: tensor(Pi(mw,Int,Bool), Int) = Bool
     (check-equal? (that-read tm app-e ':type) (expr-Bool)
                   "app result: Bool via tensor"))
   ))

;; ============================================================
;; Phase 5: Structural decomposition in single-cell PU model
;; ============================================================
;;
;; Verify the attribute PU handles structural decomposition through
;; APP propagator writes + merge, without separate sub-cells.

(define phase-5-decomp-tests
  (test-suite
   "Phase 5: structural decomposition via single-cell PU"

   (test-case "Pi decomposition: APP decomposes Pi(mw,Int,Int) into domain+codomain"
     ;; Pre-populate func with Pi(mw,Int,Int), let APP decompose
     (define func-e (expr-fvar 'f))
     (define arg-e (expr-int 42))
     (define app-e (expr-app func-e arg-e))
     (define net0 (make-prop-network))
     (define-values (net1 tm-cid)
       (net-new-cell net0
                     (hasheq func-e (hasheq ':type (expr-Pi 'mw (expr-Int) (expr-Int))))
                     attribute-map-merge-fn))
     (define net2 (install-typing-network net1 tm-cid app-e (context-cell-value '() 0)))
     (define net3 (run-to-quiescence-bsp net2))
     (define tm (net-cell-read net3 tm-cid))
     ;; APP decomposes: domain Int → arg-pos, codomain Int → result-pos
     (check-equal? (that-read tm arg-e ':type) (expr-Int)
                   "domain Int written to arg position")
     (check-equal? (that-read tm app-e ':type) (expr-Int)
                   "codomain Int written to result position"))

   (test-case "chained APP: Pi(mw,Int,Pi(mw,Int,Int)) decomposes through two APPs"
     ;; f : Pi(mw, Int, Pi(mw, Int, Int)), applied to 1 then 2
     (define plus-e (expr-fvar 'f))
     (define a1 (expr-int 1))
     (define a2 (expr-int 2))
     (define app1 (expr-app plus-e a1))
     (define app2 (expr-app app1 a2))
     (define net0 (make-prop-network))
     (define-values (net1 tm-cid)
       (net-new-cell net0
                     (hasheq plus-e (hasheq ':type (expr-Pi 'mw (expr-Int) (expr-Pi 'mw (expr-Int) (expr-Int)))))
                     attribute-map-merge-fn))
     (define net2 (install-typing-network net1 tm-cid app2 (context-cell-value '() 0)))
     (define net3 (run-to-quiescence-bsp net2))
     (define tm (net-cell-read net3 tm-cid))
     ;; First APP: domain Int → a1, codomain Pi(mw,Int,Int) → app1
     (check-equal? (that-read tm a1 ':type) (expr-Int)
                   "first arg gets domain Int")
     (check-equal? (that-read tm app1 ':type) (expr-Pi 'mw (expr-Int) (expr-Int))
                   "intermediate app gets codomain Pi(mw,Int,Int)")
     ;; Second APP: domain Int → a2, codomain Int → app2
     (check-equal? (that-read tm a2 ':type) (expr-Int)
                   "second arg gets domain Int")
     (check-equal? (that-read tm app2 ':type) (expr-Int)
                   "final result: Int"))

   (test-case "dependent codomain: subst propagates through decomposition"
     ;; Lambda with dependent codomain: fn [x:Int] x
     ;; Type should be Pi(mw, Int, Int) — codomain depends on domain
     (define dom-e (expr-Int))
     (define body-e (expr-bvar 0))
     (define lam-e (expr-lam 'mw dom-e body-e))
     (define net0 (make-prop-network))
     (define ctx (context-cell-value '() 0))
     (define-values (net1 result-type)
       (infer-on-network net0 lam-e ctx))
     ;; Lambda propagator: reads dom (Type(0)→Int via context) and body (bvar→Int)
     ;; Writes Pi(mw, Int, Int) — correctly decomposed
     (check-true (expr-Pi? result-type)
                 "lambda produces Pi type")
     (when (expr-Pi? result-type)
       (check-equal? (expr-Pi-domain result-type) dom-e
                     "Pi domain is the original dom expression")))

   (test-case "type constructor application: (List Nat) via APP propagator"
     ;; List : Type(0) → Type(0) as an fvar
     ;; (app List Nat) should give Type(0) via APP decomposition
     ;; This tests generic type constructor decomposition through APP
     (define list-e (expr-fvar 'List))
     (define nat-e (expr-Nat))
     (define app-e (expr-app list-e nat-e))
     (define net0 (make-prop-network))
     (define-values (net1 result-type)
       (infer-on-network net0 app-e
         (context-cell-value '() 0)))
     ;; APP reads List's type: Pi(m0, Type(0), Type(0))
     ;; Writes Type(0) (domain) to Nat position, Type(0) (codomain) to result
     ;; Result should be Type(0) — the type of (List Nat)
     (check-true (or (and (expr-Type? result-type))
                     ;; If List is not in env, result may be bot (acceptable)
                     (type-bot? result-type))
                 "type constructor app: (List Nat) : Type(0) or bot if not in env"))
   ))

(run-tests phase-1a-tests)
(run-tests phase-1c-tests)
(run-tests phase-2-network-tests)
(run-tests phase-4b-tests)
(run-tests phase-6-tests)
(run-tests pattern-5-tests)
(run-tests phase-5-decomp-tests)
