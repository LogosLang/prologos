#lang racket/base

;;;
;;; test-facet-tag-dispatch.rkt — PPN 4C Phase 3c-i
;;;
;;; Tests the :type / :term tag-layer dispatch at the that-read / that-write
;;; boundary per D.3 §6.15.8.
;;;
;;; - :type reads/writes route to the CLASSIFIER layer of the :type facet
;;; - :term reads/writes route to the INHABITANT layer of the SAME facet
;;; - 5 facets preserved per §4.2 (no 6th facet in AttributeRecord)
;;; - Raw type-value backward-compat: legacy direct-construction sites
;;;   continue to work (base lattice embeds as classifier-only at the boundary)
;;;

(require rackunit
         prologos/propagator
         prologos/typing-propagators
         prologos/syntax
         prologos/type-lattice
         prologos/classify-inhabit)

;; ============================================================
;; Reader semantics
;; ============================================================

(test-case "that-read :type on empty cell returns type-bot"
  (define am (hasheq))
  (check-equal? (that-read am 'p ':type) type-bot))

(test-case "that-read :term on empty cell returns 'bot"
  (define am (hasheq))
  (check-equal? (that-read am 'p ':term) 'bot))

(test-case "that-read :type extracts classifier layer from classify-inhabit-value"
  (define am (hasheq 'p (hasheq ':type (classifier-only (expr-Int)))))
  (check-equal? (that-read am 'p ':type) (expr-Int)))

(test-case "that-read :term extracts inhabitant layer from classify-inhabit-value"
  (define am (hasheq 'p (hasheq ':type (inhabitant-only (expr-nat-val 5)))))
  (check-equal? (that-read am 'p ':term) (expr-nat-val 5))
  ;; And :type returns bot because classifier layer is empty
  (check-equal? (that-read am 'p ':type) type-bot))

(test-case "that-read both layers of a fully-populated classify-inhabit-value"
  (define v (classify-inhabit-value (expr-Int) (expr-nat-val 42)))
  (define am (hasheq 'p (hasheq ':type v)))
  (check-equal? (that-read am 'p ':type) (expr-Int))
  (check-equal? (that-read am 'p ':term) (expr-nat-val 42)))

(test-case "that-read :type on contradiction sentinel returns type-top"
  (define am (hasheq 'p (hasheq ':type 'classify-inhabit-contradiction)))
  (check-true (type-top? (that-read am 'p ':type))))

(test-case "that-read :term on contradiction sentinel returns the sentinel"
  (define am (hasheq 'p (hasheq ':type 'classify-inhabit-contradiction)))
  (check-true (classify-inhabit-contradiction? (that-read am 'p ':term))))

;; ============================================================
;; Backward-compat: raw type-value in :type facet
;; ============================================================

(test-case "raw type-value in :type facet: reader returns it as classifier"
  ;; Sites constructing (hasheq ':type raw-type) without going through that-write.
  (define am (hasheq 'p (hasheq ':type (expr-Int))))
  (check-equal? (that-read am 'p ':type) (expr-Int))
  ;; :term is empty since raw values have no inhabitant layer
  (check-equal? (that-read am 'p ':term) 'bot))

(test-case "raw type-bot in :type facet: reader returns type-bot"
  (define am (hasheq 'p (hasheq ':type type-bot)))
  (check-equal? (that-read am 'p ':type) type-bot))

;; ============================================================
;; Writer semantics
;; ============================================================

(define (make-empty-net)
  (define net0 (make-prop-network))
  (define-values (net1 cid) (net-new-cell net0 (hasheq) attribute-map-merge-fn))
  (values net1 cid))

(test-case "that-write :type populates classifier layer"
  (define-values (net cid) (make-empty-net))
  (define net* (that-write net cid 'p ':type (expr-Int)))
  (check-equal? (that-read (net-cell-read net* cid) 'p ':type) (expr-Int))
  ;; Inhabitant layer stays empty
  (check-equal? (that-read (net-cell-read net* cid) 'p ':term) 'bot))

(test-case "that-write :term populates inhabitant layer"
  (define-values (net cid) (make-empty-net))
  (define net* (that-write net cid 'p ':term (expr-nat-val 5)))
  (check-equal? (that-read (net-cell-read net* cid) 'p ':term) (expr-nat-val 5))
  ;; Classifier layer stays empty
  (check-equal? (that-read (net-cell-read net* cid) 'p ':type) type-bot))

(test-case "writing :type then :term populates both layers"
  (define-values (net cid) (make-empty-net))
  (define n1 (that-write net cid 'p ':type (expr-Int)))
  (define n2 (that-write n1 cid 'p ':term (expr-nat-val 5)))
  (check-equal? (that-read (net-cell-read n2 cid) 'p ':type) (expr-Int))
  (check-equal? (that-read (net-cell-read n2 cid) 'p ':term) (expr-nat-val 5)))

(test-case "writing :term then :type populates both layers (order-independent)"
  (define-values (net cid) (make-empty-net))
  (define n1 (that-write net cid 'p ':term (expr-nat-val 5)))
  (define n2 (that-write n1 cid 'p ':type (expr-Int)))
  (check-equal? (that-read (net-cell-read n2 cid) 'p ':type) (expr-Int))
  (check-equal? (that-read (net-cell-read n2 cid) 'p ':term) (expr-nat-val 5)))

;; ============================================================
;; Idempotence + contradictions
;; ============================================================

(test-case "idempotent :type write"
  (define-values (net cid) (make-empty-net))
  (define n1 (that-write net cid 'p ':type (expr-Int)))
  (define n2 (that-write n1 cid 'p ':type (expr-Int)))
  (check-equal? (that-read (net-cell-read n2 cid) 'p ':type) (expr-Int)))

(test-case "idempotent :term write"
  (define-values (net cid) (make-empty-net))
  (define n1 (that-write net cid 'p ':term (expr-nat-val 5)))
  (define n2 (that-write n1 cid 'p ':term (expr-nat-val 5)))
  (check-equal? (that-read (net-cell-read n2 cid) 'p ':term) (expr-nat-val 5)))

(test-case "classifier contradiction (conflicting types) surfaces type-top via :type"
  (define-values (net cid) (make-empty-net))
  (define n1 (that-write net cid 'p ':type (expr-Int)))
  (define n2 (that-write n1 cid 'p ':type (expr-Bool)))
  (check-true (type-top? (that-read (net-cell-read n2 cid) 'p ':type))))

(test-case "inhabitant contradiction (conflicting values) surfaces via :term"
  (define-values (net cid) (make-empty-net))
  (define n1 (that-write net cid 'p ':term (expr-nat-val 5)))
  (define n2 (that-write n1 cid 'p ':term (expr-nat-val 7)))
  (check-true (classify-inhabit-contradiction?
               (that-read (net-cell-read n2 cid) 'p ':term))))

;; ============================================================
;; Positions are independent
;; ============================================================

(test-case "writes to different positions do not interfere"
  (define-values (net cid) (make-empty-net))
  (define n1 (that-write net cid 'p1 ':type (expr-Int)))
  (define n2 (that-write n1 cid 'p2 ':term (expr-nat-val 5)))
  (define am (net-cell-read n2 cid))
  (check-equal? (that-read am 'p1 ':type) (expr-Int))
  (check-equal? (that-read am 'p1 ':term) 'bot)
  (check-equal? (that-read am 'p2 ':type) type-bot)
  (check-equal? (that-read am 'p2 ':term) (expr-nat-val 5)))

;; ============================================================
;; Other facets unchanged
;; ============================================================

(test-case "that-write :usage still works (non-:type facet)"
  (define-values (net cid) (make-empty-net))
  (define n1 (that-write net cid 'p ':usage '(m1)))
  (check-equal? (that-read (net-cell-read n1 cid) 'p ':usage) '(m1)))

(test-case "5 facets preserved: :constraints, :usage, :warnings untouched"
  ;; Writing to :type or :term does not pollute other facets.
  (define-values (net cid) (make-empty-net))
  (define n1 (that-write net cid 'p ':type (expr-Int)))
  (define n2 (that-write n1 cid 'p ':term (expr-nat-val 5)))
  (define am (net-cell-read n2 cid))
  ;; Other facets still report bot
  (check-equal? (that-read am 'p ':usage) '())
  (check-equal? (that-read am 'p ':warnings) '()))

;; ============================================================
;; PPN 4C Phase 3c-ii: term-map-read / term-map-write helpers
;; ============================================================
;;
;; Symmetric to type-map-read / type-map-write for the INHABITANT layer.
;; Used by per-rule writers at sites where the semantic intent is
;; "this position IS SOLVED to V" (meta-feedback, trait-resolution dict).

(test-case "term-map-write populates inhabitant layer"
  (define-values (net cid) (make-empty-net))
  (define net* (term-map-write net cid 'p (expr-nat-val 5)))
  (check-equal? (term-map-read net* cid 'p) (expr-nat-val 5))
  ;; Classifier layer stays empty (parallel to type-map-write's
  ;; effect on inhabitant)
  (check-equal? (type-map-read net* cid 'p) type-bot))

(test-case "term-map-read returns 'bot on empty cell"
  (define-values (net cid) (make-empty-net))
  (check-equal? (term-map-read net cid 'p) 'bot))

(test-case "type-map-write and term-map-write compose"
  (define-values (net cid) (make-empty-net))
  (define n1 (type-map-write net cid 'p (expr-Int)))
  (define n2 (term-map-write n1 cid 'p (expr-nat-val 5)))
  (check-equal? (type-map-read n2 cid 'p) (expr-Int))
  (check-equal? (term-map-read n2 cid 'p) (expr-nat-val 5)))

;; ============================================================
;; PPN 4C Phase 3e addendum: that-read arity-2 (whole-record view)
;; ============================================================
;;
;; `(that-read am x)` returns a user-facing hash of all facets stored at
;; position x. The :type facet's internal classify-inhabit-value is
;; decomposed into user-facing :type (classifier) + :term (inhabitant).

(test-case "that-read arity-2: empty position returns empty hash"
  (define am (hasheq))
  (check-equal? (that-read am 'p) (hasheq)))

(test-case "that-read arity-2: non-hash attribute-map returns empty hash"
  (check-equal? (that-read #f 'p) (hasheq))
  (check-equal? (that-read '() 'p) (hasheq)))

(test-case "that-read arity-2: :type only → returns :type + :term (term 'bot)"
  (define am (hasheq 'p (hasheq ':type (classifier-only (expr-Int)))))
  (define record (that-read am 'p))
  (check-equal? (hash-ref record ':type) (expr-Int))
  (check-equal? (hash-ref record ':term) 'bot))

(test-case "that-read arity-2: :term only → returns :type (type-bot) + :term"
  (define am (hasheq 'p (hasheq ':type (inhabitant-only (expr-nat-val 5)))))
  (define record (that-read am 'p))
  (check-equal? (hash-ref record ':type) type-bot)
  (check-equal? (hash-ref record ':term) (expr-nat-val 5)))

(test-case "that-read arity-2: both layers populated → both in record"
  (define v (classify-inhabit-value (expr-Int) (expr-int 42)))
  (define am (hasheq 'p (hasheq ':type v)))
  (define record (that-read am 'p))
  (check-equal? (hash-ref record ':type) (expr-Int))
  (check-equal? (hash-ref record ':term) (expr-int 42)))

(test-case "that-read arity-2: non-:type facets pass through as-is"
  (define am (hasheq 'p (hasheq ':usage '(m1)
                                ':warnings '((coercion-warning ...)))))
  (define record (that-read am 'p))
  (check-equal? (hash-ref record ':usage) '(m1))
  (check-equal? (hash-ref record ':warnings) '((coercion-warning ...)))
  ;; :type / :term NOT synthesized when :type facet absent — honest shape
  (check-false (hash-has-key? record ':type))
  (check-false (hash-has-key? record ':term)))

(test-case "that-read arity-2: :type + other facets → all present"
  (define am (hasheq 'p (hasheq ':type (classifier-only (expr-Int))
                                ':usage '(m1)
                                ':warnings '())))
  (define record (that-read am 'p))
  (check-equal? (hash-ref record ':type) (expr-Int))
  (check-equal? (hash-ref record ':term) 'bot)
  (check-equal? (hash-ref record ':usage) '(m1))
  (check-equal? (hash-ref record ':warnings) '()))

(test-case "that-read arity-2: contradiction sentinel at :type decomposes"
  (define am (hasheq 'p (hasheq ':type 'classify-inhabit-contradiction)))
  (define record (that-read am 'p))
  (check-true (type-top? (hash-ref record ':type)))
  (check-true (classify-inhabit-contradiction? (hash-ref record ':term))))

(test-case "that-read arity-2: after that-write round-trip"
  (define-values (net cid) (make-empty-net))
  (define n1 (that-write net cid 'p ':type (expr-Int)))
  (define n2 (that-write n1 cid 'p ':term (expr-int 42)))
  (define n3 (that-write n2 cid 'p ':usage '(m1)))
  (define record (that-read (net-cell-read n3 cid) 'p))
  (check-equal? (hash-ref record ':type) (expr-Int))
  (check-equal? (hash-ref record ':term) (expr-int 42))
  (check-equal? (hash-ref record ':usage) '(m1)))

(test-case "that-read arity-2: independent positions"
  (define-values (net cid) (make-empty-net))
  (define n1 (that-write net cid 'p1 ':type (expr-Int)))
  (define n2 (that-write n1 cid 'p2 ':usage '(m1)))
  (define am (net-cell-read n2 cid))
  (check-equal? (hash-ref (that-read am 'p1) ':type) (expr-Int))
  (check-false (hash-has-key? (that-read am 'p1) ':usage))
  (check-equal? (hash-ref (that-read am 'p2) ':usage) '(m1))
  (check-false (hash-has-key? (that-read am 'p2) ':type))
  ;; Unknown position → empty record
  (check-equal? (that-read am 'p3) (hasheq)))
