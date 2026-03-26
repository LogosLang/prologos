#lang racket/base

;;;
;;; Tests for PPN Track 0: Parse Domain Bridges + Exchanges
;;;

(require rackunit
         racket/set
         "../parse-lattice.rkt"
         "../parse-bridges.rkt")

;; ============================================================
;; Test Grammar (hardcoded for Track 0 integration)
;; ============================================================
;; A tiny grammar: S → def IDENT COLON TYPE ASSIGN EXPR

(define (test-expected-tokens position token-type)
  ;; At position 0, expect 'keyword (for "def")
  ;; At position 1, expect 'identifier (for variable name)
  ;; At position 3, expect 'identifier (for type name)
  ;; Others: empty
  (cond
    [(and (= position 0) (eq? token-type 'keyword))
     (seteq (make-parse-item 'def-form 0 0 0))]
    [(and (= position 1) (eq? token-type 'identifier))
     (seteq (make-parse-item 'def-form 1 0 1))]
    [(and (= position 3) (eq? token-type 'identifier))
     (seteq (make-parse-item 'def-form 3 0 3))]
    [else (seteq)]))


;; ============================================================
;; Bridge 1: TokenToSurface
;; ============================================================

(test-case "token-to-surface-alpha: matching token creates derivations"
  (define tok (make-token 'keyword "def" 0 3 0))
  (define result (token-to-surface-alpha tok test-expected-tokens))
  (check-pred parse-cell-value? result)
  (check-equal? (set-count (parse-cell-value-derivations result)) 1))

(test-case "token-to-surface-alpha: non-matching token returns bot"
  (define tok (make-token 'number "42" 0 2 0))
  (define result (token-to-surface-alpha tok test-expected-tokens))
  (check-true (parse-bot? result)))

(test-case "token-to-surface-alpha: bot token returns parse-bot"
  (define result (token-to-surface-alpha token-bot test-expected-tokens))
  (check-true (parse-bot? result)))

(test-case "surface-to-token-gamma: no parse context = no change"
  (define tok (make-token 'operator ">" 10 11 0))
  (define result (surface-to-token-gamma parse-bot tok
    (lambda (ps tt) #f)))
  (check-equal? result tok))

(test-case "surface-to-token-gamma: context reclassifies token"
  (define tok (make-token 'operator ">" 10 11 0))
  (define parse-ctx (parse-cell-value
    (seteq (make-derivation-node
            (make-parse-item 'angle-bracket 0 5 10) '()))))
  ;; Context function: if we're inside an angle-bracket production,
  ;; reclassify ">" from operator to delimiter
  (define (angle-context ps token-type)
    (if (eq? token-type 'operator) 'delimiter #f))
  (define result (surface-to-token-gamma parse-ctx tok angle-context))
  (check-equal? (token-cell-value-type result) 'delimiter))

(test-case "surface-to-token-gamma: context preserves non-matching tokens"
  (define tok (make-token 'identifier "foo" 10 13 0))
  (define parse-ctx (parse-cell-value
    (seteq (make-derivation-node
            (make-parse-item 'angle-bracket 0 5 10) '()))))
  (define result (surface-to-token-gamma parse-ctx tok
    (lambda (ps tt) #f)))
  (check-eq? result tok))


;; ============================================================
;; Bridge 2: SurfaceToCore
;; ============================================================

(test-case "surface-to-core-alpha: builds AST from derivation"
  (define deriv (make-derivation-node
                 (make-parse-item 'def-form 5 0 6) '()))
  (define result (surface-to-core-alpha deriv
    (lambda (d) (list 'def-ast (parse-item-production (derivation-node-item d))))))
  (check-equal? result '(def-ast def-form)))

(test-case "surface-to-core-alpha: non-derivation returns core-bot"
  (check-equal? (surface-to-core-alpha "not a derivation" (lambda (d) d))
                core-bot))

(test-case "core-to-surface-gamma: extracts assumption for retraction"
  (define deriv (make-derivation-node
                 (make-parse-item 'S 2 0 5) '() 'assume-7))
  (check-equal? (core-to-surface-gamma deriv) 'assume-7))

(test-case "core-to-surface-gamma: no assumption = #f"
  (define deriv (make-derivation-node
                 (make-parse-item 'S 2 0 5) '()))
  (check-false (core-to-surface-gamma deriv)))


;; ============================================================
;; Bridge 3: SurfaceToType
;; ============================================================

(test-case "surface-to-type-alpha: generates constraints"
  (define deriv (make-derivation-node
                 (make-parse-item 'def-form 5 0 6) '()))
  (define constraints
    (surface-to-type-alpha deriv
      (lambda (d) (list '(type-eq x Int) '(type-eq body Int)))))
  (check-equal? constraints '((type-eq x Int) (type-eq body Int))))

(test-case "surface-to-type-alpha: non-derivation returns empty"
  (check-equal? (surface-to-type-alpha "nope" (lambda (d) '(bad)))
                '()))


;; ============================================================
;; Exchange: Right Kan (demand from elaboration)
;; ============================================================

(test-case "demand-from-elaboration: creates demand with source stratum"
  (define d (make-demand-from-elaboration 'token 42 'any))
  (check-equal? (demand-target-domain d) 'token)
  (check-equal? (demand-position d) 42)
  (check-equal? (demand-specificity d) 'any)
  (check-equal? (demand-source-stratum d) 'S-elaborate))

(test-case "demand-from-elaboration: priority defaults to 0"
  (define d (make-demand-from-elaboration 'type 'cell-100 'ground))
  (check-equal? (demand-priority d) 0))

(test-case "demand-from-elaboration: explicit priority"
  (define d (make-demand-from-elaboration 'surface '(0 . 10) 'complete-item 5))
  (check-equal? (demand-priority d) 5))


;; ============================================================
;; Exchange: Left Kan (partial parse result)
;; ============================================================

(test-case "partial-parse-result: wraps parse value with confidence"
  (define pcv (parse-cell-value
    (seteq (make-derivation-node (make-parse-item 'S 1 0 3) '()))))
  (define ppr (make-partial-parse-result pcv 0.8))
  (check-equal? (partial-parse-result-confidence ppr) 0.8)
  (check-equal? (partial-parse-result-parse-value ppr) pcv))

(test-case "partial-parse-result: default confidence 0.5"
  (define ppr (make-partial-parse-result parse-bot))
  (check-equal? (partial-parse-result-confidence ppr) 0.5))


;; ============================================================
;; Projection: SurfaceToNarrowing
;; ============================================================

(test-case "surface-to-narrowing-alpha: triggers narrowing request"
  (define deriv (make-derivation-node
                 (make-parse-item 'match-arm 2 0 5) '()))
  (define result (surface-to-narrowing-alpha deriv
    (lambda (d) (list 'narrow (parse-item-production (derivation-node-item d))))))
  (check-equal? result '(narrow match-arm)))

(test-case "surface-to-narrowing-alpha: non-derivation returns #f"
  (check-false (surface-to-narrowing-alpha "nope" (lambda (d) 'bad))))


;; ============================================================
;; Demand Satisfaction Protocol
;; ============================================================

(test-case "demand-satisfied?: any specificity — non-bot satisfies"
  (define d (make-demand 'token 5 'any 'S-elaborate))
  (check-true (demand-satisfied? d (make-token 'identifier "x" 5 6 0)))
  (check-false (demand-satisfied? d token-bot)))

(test-case "demand-satisfied?: ground specificity — delegates to checker"
  (define d (make-demand 'type 'cell-1 'ground 'S-elaborate))
  ;; Ground check passes
  (check-true (demand-satisfied? d 'some-value (lambda (v) #t)))
  ;; Ground check fails (has unsolved metas)
  (check-false (demand-satisfied? d 'some-value (lambda (v) #f))))

(test-case "demand-satisfied?: complete-item — needs non-empty derivations"
  (define d (make-demand 'surface '(0 . 5) 'complete-item 'S-elaborate))
  (define pcv (parse-cell-value
    (seteq (make-derivation-node (make-parse-item 'S 3 0 5) '()))))
  (check-true (demand-satisfied? d pcv))
  (check-false (demand-satisfied? d parse-bot)))

(test-case "demand-satisfied?: bot values never satisfy"
  (define d (make-demand 'token 0 'any 'S-elaborate))
  (check-false (demand-satisfied? d token-bot))
  (check-false (demand-satisfied? d core-bot))
  (check-false (demand-satisfied? d parse-bot))
  (check-false (demand-satisfied? d demand-bot)))
