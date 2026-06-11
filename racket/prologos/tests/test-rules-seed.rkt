#lang racket/base
;; PReduce Track 2 Phase 1 — the arithmetic seed fires on the e-graph
;; (design §3/§4; ledger iter 20). THE FIRST REAL REDUCTION RULES.
(require rackunit racket/set
         "../kernel-rules-seed.rkt"
         "../rule-registry.rkt"
         "../rule-dispatch.rkt"
         "../eclass-graph.rkt"
         "../eclass-cell.rkt"
         "../propagator.rkt")

;; shared fixture: registry with the seed + a hashcons graph, quiesced
(define-values (net0 hashcons) (make-eclass-graph (make-prop-network)))
(define-values (net1 registry) (make-rule-registry-cell net0))
(define net2 (run-to-quiescence (register-arithmetic-seed! net1 registry)))

(check-equal? (set-count (rules-for-tag net2 registry 'int+)) 1
              "seed registered + index derived")

;; helper: intern a form, dispatch, return (values net best fired)
(define (run-fold net form)
  (define-values (n1 cid _d) (eclass-intern net hashcons form #:cost 5))
  (define-values (n2 fired) (dispatch-rules n1 hashcons registry cid))
  (values n2 (hash-ref (eclass-read n2 cid) ':best) fired))

;; --- THE FIRST FOLDS ---
(let-values ([(n best fired) (run-fold net2 '(int+ (lit 1) (lit 2)))])
  (check-equal? fired 1 "int+ fold fires")
  (check-equal? best (cons 1 '(lit 3)) "1 + 2 → 3, cheaper form wins the class"))
(let-values ([(n best fired) (run-fold net2 '(int* (lit 6) (lit 7)))])
  (check-equal? best (cons 1 '(lit 42))))
(let-values ([(n best fired) (run-fold net2 '(int- (lit 10) (lit 3)))])
  (check-equal? best (cons 1 '(lit 7))))
(let-values ([(n best fired) (run-fold net2 '(int/ (lit 12) (lit 4)))])
  (check-equal? best (cons 1 '(lit 3))))
(let-values ([(n best fired) (run-fold net2 '(int-mod (lit 10) (lit 3)))])
  (check-equal? best (cons 1 '(lit 1))))

;; division by zero: compute aborts — the rule does NOT fire, the class unchanged
(let-values ([(n best fired) (run-fold net2 '(int/ (lit 1) (lit 0)))])
  (check-equal? fired 0 "div-by-zero never fires")
  (check-equal? best (cons 5 '(int/ (lit 1) (lit 0))) "class untouched"))

;; comparisons fold to booleans
(let-values ([(n best fired) (run-fold net2 '(int-lt (lit 1) (lit 2)))])
  (check-equal? best (cons 1 '(lit #t))))
(let-values ([(n best fired) (run-fold net2 '(int-ge (lit 1) (lit 2)))])
  (check-equal? best (cons 1 '(lit #f))))

;; booleans
(let-values ([(n best fired) (run-fold net2 '(bool-and (lit #t) (lit #f)))])
  (check-equal? best (cons 1 '(lit #f))))
(let-values ([(n best fired) (run-fold net2 '(bool-not (lit #f)))])
  (check-equal? best (cons 1 '(lit #t))))

;; nat folds on numeric literal form (design §6 Q2)
(let-values ([(n best fired) (run-fold net2 '(suc (lit 4)))])
  (check-equal? best (cons 1 '(lit 5))))
(let-values ([(n best fired) (run-fold net2 '(nat-pred (lit 5)))])
  (check-equal? best (cons 1 '(lit 4))))

;; non-literal operands: no match, no fire (lazy — folds need ground children)
(let-values ([(n best fired) (run-fold net2 '(int+ (lit 1) (var x)))])
  (check-equal? fired 0)
  (check-equal? best (cons 5 '(int+ (lit 1) (var x)))))

;; alts retained: the original form stays in the class (write-target best+alts)
(let*-values ([(n1 cid d) (eclass-intern net2 hashcons '(int+ (lit 2) (lit 3)) #:cost 5)]
              [(n2 _f) (dispatch-rules n1 hashcons registry cid)])
  (define v (eclass-read n2 cid))
  (check-true (set-member? (hash-ref v ':alts) d) "original alt retained")
  (check-equal? (hash-ref v ':best) (cons 1 '(lit 5))))

;; idempotent re-dispatch: same fixpoint, no growth
(let*-values ([(n1 cid _d) (eclass-intern net2 hashcons '(int+ (lit 1) (lit 1)) #:cost 5)]
              [(n2 _f1) (dispatch-rules n1 hashcons registry cid)]
              [(n3 _f2) (dispatch-rules n2 hashcons registry cid)])
  (check-equal? (eclass-read n3 cid) (eclass-read n2 cid) "re-dispatch is a fixpoint"))
