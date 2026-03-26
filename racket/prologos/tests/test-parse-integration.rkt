#lang racket/base

;;;
;;; PPN Track 0 Phase 6: Integration Test
;;;
;;; Hand-constructed propagator network exercising the parse lattice
;;; infrastructure. No real lexer or parser — we manually create cells
;;; and install propagators to validate that the lattices compose
;;; correctly on the propagator network.
;;;
;;; Test 1 (happy path): Parse "def x : Int := 42"
;;; Test 2 (ambiguity): Two parse alternatives, type resolves one
;;;

(require rackunit
         racket/set
         "../parse-lattice.rkt"
         "../parse-bridges.rkt"
         "../propagator.rkt"
         "../champ.rkt"
         "../infra-cell.rkt")

;; ============================================================
;; Helper: create a prop-network with parse lattice cells
;; ============================================================

;; Register parse lattice merge functions with the propagator network
(define (make-parse-network)
  (make-prop-network))

(define (add-token-cell net)
  (net-new-cell net token-bot token-lattice-merge token-contradicts?))

(define (add-parse-cell net)
  (net-new-cell net parse-bot parse-lattice-merge parse-contradicts?))

(define (add-core-cell net)
  (net-new-cell net core-bot core-lattice-merge core-contradicts?))


;; ============================================================
;; Test 1: Happy path — "def x : Int := 42"
;; ============================================================
;; Tokens: def(kw) x(id) :(delim) Int(id) :=(delim) 42(num)
;; Parse: def-form production, single unambiguous derivation
;; Core: (def x Int 42) AST node
;; Type: Int (from the annotation)

(test-case "integration: happy path — def x : Int := 42"
  ;; Create network
  (define net0 (make-parse-network))

  ;; Create 6 token cells
  (define-values (net1 tok-def-id) (add-token-cell net0))
  (define-values (net2 tok-x-id) (add-token-cell net1))
  (define-values (net3 tok-colon-id) (add-token-cell net2))
  (define-values (net4 tok-Int-id) (add-token-cell net3))
  (define-values (net5 tok-assign-id) (add-token-cell net4))
  (define-values (net6 tok-42-id) (add-token-cell net5))

  ;; Create 1 parse cell (for the completed def-form item)
  (define-values (net7 parse-def-id) (add-parse-cell net6))

  ;; Create 1 core cell
  (define-values (net8 core-def-id) (add-core-cell net7))

  ;; Write tokens (set-once: each written exactly once)
  (define net9
    (net-cell-write
     (net-cell-write
      (net-cell-write
       (net-cell-write
        (net-cell-write
         (net-cell-write net8
          tok-def-id (make-token 'keyword "def" 0 3 0))
         tok-x-id (make-token 'identifier "x" 4 5 0))
        tok-colon-id (make-token 'delimiter ":" 6 7 0))
       tok-Int-id (make-token 'identifier "Int" 8 11 0))
      tok-assign-id (make-token 'delimiter ":=" 12 14 0))
     tok-42-id (make-token 'number "42" 15 17 0)))

  ;; Verify tokens are set
  (check-pred token-cell-value? (net-cell-read net9 tok-def-id))
  (check-equal? (token-cell-value-type (net-cell-read net9 tok-def-id)) 'keyword)
  (check-equal? (token-cell-value-lexeme (net-cell-read net9 tok-42-id)) "42")

  ;; Simulate scanning: token-to-surface-alpha creates a derivation
  (define def-item (make-parse-item 'def-form 6 0 17))  ;; completed item
  (define def-deriv (make-derivation-node def-item '()))
  (define net10
    (net-cell-write net9 parse-def-id
                    (parse-cell-value (seteq def-deriv))))

  ;; Verify parse cell has 1 derivation
  (define parse-val (net-cell-read net10 parse-def-id))
  (check-pred parse-cell-value? parse-val)
  (check-equal? (set-count (parse-cell-value-derivations parse-val)) 1)

  ;; Simulate surface-to-core-alpha: build AST from completed parse
  (define ast-node (surface-to-core-alpha def-deriv
    (lambda (d) (list 'def 'x 'Int 42))))
  (define net11 (net-cell-write net10 core-def-id ast-node))

  ;; Verify core cell has AST
  (check-equal? (net-cell-read net11 core-def-id) '(def x Int 42))

  ;; Verify no contradictions anywhere
  (check-false (net-contradiction? net11)))


;; ============================================================
;; Test 2: Ambiguity — two parse alternatives
;; ============================================================
;; Scenario: "f x y" could be:
;;   Parse A: (app (app f x) y) — left-associative application
;;   Parse B: (app f (app x y)) — right-associative application
;;
;; Type information resolves: if f : Int -> Int -> Int, then A is correct.
;; If f : (Int -> Int) -> Int, then B is correct.
;;
;; We simulate with ATMS assumptions: one per parse alternative.

(test-case "integration: ambiguity — two parses, ATMS resolves"
  (define net0 (make-parse-network))

  ;; Create parse cell for the ambiguous expression
  (define-values (net1 parse-expr-id) (add-parse-cell net0))

  ;; Create two derivation alternatives with different ATMS assumptions
  (define item-A (make-parse-item 'app-left 2 0 5))
  (define item-B (make-parse-item 'app-right 2 0 5))
  (define deriv-A (make-derivation-node item-A '() 'assume-A 0))
  (define deriv-B (make-derivation-node item-B '() 'assume-B 0))

  ;; Write BOTH alternatives to the parse cell (set union — ambiguity!)
  (define net2
    (net-cell-write
     (net-cell-write net1
      parse-expr-id (parse-cell-value (seteq deriv-A)))
     parse-expr-id (parse-cell-value (seteq deriv-B))))

  ;; Parse cell should have 2 derivations
  (define parse-val (net-cell-read net2 parse-expr-id))
  (check-equal? (set-count (parse-cell-value-derivations parse-val)) 2)

  ;; Simulate type-directed disambiguation:
  ;; Type checker says deriv-B leads to type error.
  ;; ATMS retraction: assumption-id from deriv-B
  (define retract-id (core-to-surface-gamma deriv-B))
  (check-equal? retract-id 'assume-B)

  ;; After retraction, the remaining derivation should be deriv-A.
  ;; (In the full system, ATMS worldview filtering makes deriv-B invisible.
  ;; Here we simulate by manually filtering.)
  (define surviving
    (for/seteq ([d (in-set (parse-cell-value-derivations parse-val))]
                #:when (not (equal? (derivation-node-assumption-id d) retract-id)))
      d))
  (check-equal? (set-count surviving) 1)
  (check-equal? (parse-item-production
                 (derivation-node-item (set-first surviving)))
                'app-left))


;; ============================================================
;; Test 3: Demand satisfaction
;; ============================================================

(test-case "integration: demand satisfaction protocol"
  (define net0 (make-parse-network))

  ;; Create a token cell and a demand
  (define-values (net1 tok-id) (add-token-cell net0))
  (define d (make-demand-from-elaboration 'token 0 'any))

  ;; Token cell is bot — demand NOT satisfied
  (check-false (demand-satisfied? d (net-cell-read net1 tok-id)))

  ;; Write a token value
  (define net2 (net-cell-write net1 tok-id
    (make-token 'identifier "x" 0 1 0)))

  ;; Now demand IS satisfied
  (check-true (demand-satisfied? d (net-cell-read net2 tok-id))))


;; ============================================================
;; Test 4: Token set-once contradiction
;; ============================================================

(test-case "integration: token set-once — different value = contradiction"
  (define net0 (make-parse-network))
  (define-values (net1 tok-id) (add-token-cell net0))

  ;; Write first token
  (define net2 (net-cell-write net1 tok-id
    (make-token 'identifier "def" 0 3 0)))

  ;; Write DIFFERENT token at same cell — should trigger contradiction
  (define net3 (net-cell-write net2 tok-id
    (make-token 'keyword "def" 0 3 0)))

  ;; Cell should now be token-top (contradiction)
  (check-true (token-contradicts? (net-cell-read net3 tok-id)))
  (check-true (net-contradiction? net3)))


;; ============================================================
;; Test 5: Parse derivation merge (set union)
;; ============================================================

(test-case "integration: parse merge accumulates derivations"
  (define net0 (make-parse-network))
  (define-values (net1 parse-id) (add-parse-cell net0))

  ;; Write first derivation
  (define d1 (make-derivation-node (make-parse-item 'S 2 0 5) '()))
  (define net2 (net-cell-write net1 parse-id (parse-cell-value (seteq d1))))

  ;; Write second derivation (different item)
  (define d2 (make-derivation-node (make-parse-item 'S 2 0 5)
               (list (make-derivation-node (make-parse-item 'NP 1 0 3) '()))))
  (define net3 (net-cell-write net2 parse-id (parse-cell-value (seteq d2))))

  ;; Both derivations should be in the cell (set union)
  (define val (net-cell-read net3 parse-id))
  (check-pred parse-cell-value? val)
  (check-equal? (set-count (parse-cell-value-derivations val)) 2))


;; ============================================================
;; Test 6: Context-sensitive token disambiguation via bridge
;; ============================================================

(test-case "integration: bridge γ reclassifies token based on parse context"
  (define tok (make-token 'operator ">" 10 11 0))

  ;; Parse context: inside angle brackets
  (define ctx (parse-cell-value
    (seteq (make-derivation-node
            (make-parse-item 'type-annotation 1 5 10) '()))))

  ;; Context function: reclassify > as delimiter inside type annotations
  (define (type-context ps tt)
    (if (eq? tt 'operator) 'delimiter #f))

  (define refined (surface-to-token-gamma ctx tok type-context))
  (check-equal? (token-cell-value-type refined) 'delimiter)
  (check-equal? (token-cell-value-lexeme refined) ">"))


;; ============================================================
;; Test 7: Provenance via derivation children
;; ============================================================

(test-case "integration: derivation children carry provenance trace"
  ;; Build a derivation tree: S → NP VP
  (define np-item (make-parse-item 'NP 2 0 3))
  (define vp-item (make-parse-item 'VP 2 3 7))
  (define s-item  (make-parse-item 'S 2 0 7))

  (define np-deriv (make-derivation-node np-item '()))
  (define vp-deriv (make-derivation-node vp-item '()))
  (define s-deriv  (make-derivation-node s-item (list np-deriv vp-deriv)))

  ;; Provenance: S's children are NP and VP
  (check-equal? (length (derivation-node-children s-deriv)) 2)
  (check-equal? (parse-item-production
                 (derivation-node-item (car (derivation-node-children s-deriv))))
                'NP)
  (check-equal? (parse-item-production
                 (derivation-node-item (cadr (derivation-node-children s-deriv))))
                'VP))
