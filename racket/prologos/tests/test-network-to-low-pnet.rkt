#lang racket/base

;; test-network-to-low-pnet.rkt — SH Track 2 Phase 2.B unit tests.
;;
;; Validates that prop-network-to-low-pnet produces a Low-PNet IR
;; structure that:
;;   - passes validate-low-pnet (well-formed)
;;   - reflects the actual cells, propagators, and dep edges in the network
;;   - preserves fire-fn-tag from the propagator struct

(require rackunit
         "../propagator.rkt"
         "../low-pnet-ir.rkt"
         "../network-to-low-pnet.rkt")

(define (last-write-wins _old new) new)

(define (find-decl-by lp pred)
  (for/first ([n (in-list (low-pnet-nodes lp))] #:when (pred n)) n))

(define (filter-decls lp pred)
  (for/list ([n (in-list (low-pnet-nodes lp))] #:when (pred n)) n))

;; ============================================================
;; Single-cell network
;; ============================================================

(test-case "single-cell network: produces valid Low-PNet with our cell + entry"
  (define net (make-prop-network))
  (define-values (net1 cid) (net-new-cell net 0 last-write-wins))
  (define lp (prop-network-to-low-pnet net1 (cell-id-n cid)))
  (check-true (low-pnet? lp))
  (check-true (validate-low-pnet lp))
  ;; Networks contain book-keeping cells too; verify ours is present.
  (check-true (for/or ([c (in-list (filter-decls lp cell-decl?))])
                (= (cell-decl-id c) (cell-id-n cid)))
              "our cell appears among the cell-decls")
  (check-equal? (length (filter-decls lp entry-decl?)) 1)
  (check-true (>= (length (filter-decls lp domain-decl?)) 1))
  (define entry (find-decl-by lp entry-decl?))
  (check-equal? (entry-decl-main-cell-id entry) (cell-id-n cid)))

;; ============================================================
;; Multi-cell network with one propagator
;; ============================================================

(test-case "1-propagator network: propagator and dep-decls correct"
  (define net (make-prop-network))
  (define-values (net1 a-cid) (net-new-cell net 0 last-write-wins))
  (define-values (net2 b-cid) (net-new-cell net1 0 last-write-wins))
  (define-values (net3 c-cid) (net-new-cell net2 0 last-write-wins))
  (define-values (net4 _pid)
    (net-add-propagator net3 (list a-cid b-cid) (list c-cid)
                        (lambda (n) n)
                        #:fire-fn-tag 'rt-test-add))
  (define lp (prop-network-to-low-pnet net4 (cell-id-n c-cid)))
  (check-true (validate-low-pnet lp))
  ;; Find our specific propagator (the one with our tag) — there are no
  ;; other user-installed propagators in this network.
  (define p
    (for/first ([d (in-list (filter-decls lp propagator-decl?))]
                #:when (eq? (propagator-decl-fire-fn-tag d) 'rt-test-add))
      d))
  (check-true (propagator-decl? p) "our tagged propagator appears")
  (check-equal? (sort (propagator-decl-input-cells p) <)
                (sort (list (cell-id-n a-cid) (cell-id-n b-cid)) <))
  (check-equal? (propagator-decl-output-cells p) (list (cell-id-n c-cid)))
  ;; Our propagator's deps: 2 input cells → 2 dep-decls for that prop-id
  (define our-deps
    (for/list ([d (in-list (filter-decls lp dep-decl?))]
               #:when (= (dep-decl-prop-id d) (propagator-decl-id p)))
      d))
  (check-equal? (length our-deps) 2))

;; ============================================================
;; Tag default: untagged propagators come through as 'untagged
;; ============================================================

(test-case "untagged propagator: tag is 'untagged"
  (define net (make-prop-network))
  (define-values (net1 cid) (net-new-cell net 0 last-write-wins))
  (define-values (net2 _pid)
    (net-add-propagator net1 (list cid) '() (lambda (n) n)))
  (define lp (prop-network-to-low-pnet net2 (cell-id-n cid)))
  (define p (find-decl-by lp propagator-decl?))
  (check-equal? (propagator-decl-fire-fn-tag p) 'untagged))

;; ============================================================
;; Empty-ish network: at least one cell required for entry-decl
;; ============================================================

(test-case "empty network with 1 cell still produces valid Low-PNet"
  (define net (make-prop-network))
  (define-values (net1 cid) (net-new-cell net 0 last-write-wins))
  (define lp (prop-network-to-low-pnet net1 (cell-id-n cid)))
  (check-true (validate-low-pnet lp)))

;; ============================================================
;; pp + reparse roundtrip on a real network's output
;; ============================================================

;; ============================================================
;; Cell-value marshaling (Phase 2.B+)
;; ============================================================

(test-case "value-marshalable?: simple values"
  (check-true (value-marshalable? 42))
  (check-true (value-marshalable? -7))
  (check-true (value-marshalable? #t))
  (check-true (value-marshalable? #f))
  (check-true (value-marshalable? 'foo))
  (check-true (value-marshalable? "hello"))
  (check-true (value-marshalable? '()))
  (check-true (value-marshalable? '(1 2 3)))
  (check-true (value-marshalable? '(a b (c d))))
  (check-true (value-marshalable? (vector 1 'x "s"))))

(test-case "value-marshalable?: rejects non-serializable values"
  (check-false (value-marshalable? (lambda (x) x)))
  (check-false (value-marshalable? (box 5)))
  (check-false (value-marshalable? (make-hash)))
  (check-false (value-marshalable? (list 1 (lambda (x) x))) "lists with closures rejected"))

(test-case "marshal-value: passes marshalable, sentinels otherwise"
  (check-equal? (marshal-value 42) 42)
  (check-equal? (marshal-value 'foo) 'foo)
  (check-equal? (marshal-value '(1 2)) '(1 2))
  (check-equal? (marshal-value (lambda () 0)) 'phase-2b-placeholder))

(test-case "cell init-value reflects marshalable cell value"
  (define net (make-prop-network))
  (define-values (net1 cid) (net-new-cell net 99 last-write-wins))
  (define lp (prop-network-to-low-pnet net1 (cell-id-n cid)))
  (define our-cell
    (for/first ([n (in-list (low-pnet-nodes lp))]
                #:when (and (cell-decl? n) (= (cell-decl-id n) (cell-id-n cid))))
      n))
  (check-equal? (cell-decl-init-value our-cell) 99))

(test-case "cell init-value falls back to placeholder for non-marshalable"
  (define net (make-prop-network))
  (define-values (net1 cid) (net-new-cell net (lambda (n) n) last-write-wins))
  (define lp (prop-network-to-low-pnet net1 (cell-id-n cid)))
  (define our-cell
    (for/first ([n (in-list (low-pnet-nodes lp))]
                #:when (and (cell-decl? n) (= (cell-decl-id n) (cell-id-n cid))))
      n))
  (check-equal? (cell-decl-init-value our-cell) 'phase-2b-placeholder))

(test-case "pp ∘ parse on prop-network-to-low-pnet output"
  (define net (make-prop-network))
  (define-values (net1 a-cid) (net-new-cell net 0 last-write-wins))
  (define-values (net2 b-cid) (net-new-cell net1 0 last-write-wins))
  (define-values (net3 _pid)
    (net-add-propagator net2 (list a-cid) (list b-cid)
                        (lambda (n) n)
                        #:fire-fn-tag 'rt-test-fwd))
  (define lp (prop-network-to-low-pnet net3 (cell-id-n b-cid)))
  ;; Round-trip through sexp
  (define sexp (pp-low-pnet lp))
  (define lp2 (parse-low-pnet sexp))
  (check-equal? (length (low-pnet-nodes lp))
                (length (low-pnet-nodes lp2))
                "node count preserves through pp/parse")
  (check-true (validate-low-pnet lp2)
              "roundtripped Low-PNet validates"))
