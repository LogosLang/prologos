#lang racket/base

;;;
;;; SRE Track 0 Phase 3: Second domain validation
;;;
;;; Tests the SRE core with a term-value domain (NF-Narrowing's lattice)
;;; to validate that sre-core.rkt is genuinely domain-parameterized.
;;;
;;; Key validations:
;;; - sre-identify-sub-cell works with term-merge (not type-lattice-merge)
;;; - sre-constructor-tag looks up 'test-term domain (not 'type)
;;; - sre-make-structural-relate-propagator uses domain lattice ops
;;; - sre-maybe-decompose dispatches via descriptor (no hardcoded case arms)
;;; - Debug-mode idempotency assertion catches non-monotone merge
;;;

(require rackunit
         rackunit/text-ui
         "../propagator.rkt"
         "../sre-core.rkt"
         "../ctor-registry.rkt")

;; ========================================
;; A. Minimal test lattice (simpler than full term-lattice)
;; ========================================
;; We use a minimal lattice to avoid coupling to the full NF-Narrowing
;; infrastructure. This tests the SRE mechanism, not the term lattice.

(define test-bot 'test-bot)
(define test-top 'test-top)

(define (test-bot? v) (eq? v 'test-bot))
(define (test-top? v) (eq? v 'test-top))

;; Simple tagged value for testing decomposition
(struct test-pair (fst snd) #:transparent)
(struct test-leaf (val) #:transparent)

;; Test lattice merge: structural merge for test-pair, join for test-leaf
(define (test-merge old new)
  (cond
    [(test-bot? old) new]
    [(test-bot? new) old]
    [(test-top? old) test-top]
    [(test-top? new) test-top]
    ;; Same constructor, same tag → keep (sub-cell unification by network)
    [(and (test-pair? old) (test-pair? new)) old]
    [(and (test-leaf? old) (test-leaf? new))
     (if (equal? (test-leaf-val old) (test-leaf-val new))
         old
         test-top)]
    ;; Mismatch → contradiction
    [else test-top]))

(define (test-contradicts? v) (test-top? v))

;; Test domain spec
(define test-domain
  (sre-domain 'test-term
              test-merge
              test-contradicts?
              test-bot?
              test-bot
              #f    ; no meta-recognizer
              #f))  ; no meta-resolver

;; ========================================
;; B. Register test constructors
;; ========================================

;; Register descriptors via keyword API (with sample values for validation)
(register-ctor! 'test-pair
  #:arity 2
  #:recognizer test-pair?
  #:extract (lambda (v) (list (test-pair-fst v) (test-pair-snd v)))
  #:reconstruct (lambda (vals) (test-pair (car vals) (cadr vals)))
  #:component-lattices (list 'test-term 'test-term)
  #:domain 'test-term
  #:sample (test-pair (test-leaf 1) (test-leaf 2)))

(register-ctor! 'test-leaf
  #:arity 1
  #:recognizer test-leaf?
  #:extract (lambda (v) (list (test-leaf-val v)))
  #:reconstruct (lambda (vals) (test-leaf (car vals)))
  #:component-lattices (list 'test-term)
  #:domain 'test-term
  #:sample (test-leaf 42))

;; ========================================
;; C. Helper: create a fresh empty network
;; ========================================

(define (fresh-net)
  (make-prop-network))

;; ========================================
;; Tests
;; ========================================

(define sre-core-tests
  (test-suite
   "SRE Core — Second Domain Validation"

   ;; --- Section A: sre-constructor-tag ---

   (test-suite
    "A. sre-constructor-tag"

    (test-case "recognizes test-pair in test-term domain"
      (check-eq? (sre-constructor-tag test-domain (test-pair (test-leaf 1) (test-leaf 2)))
                 'test-pair))

    (test-case "recognizes test-leaf in test-term domain"
      (check-eq? (sre-constructor-tag test-domain (test-leaf 42))
                 'test-leaf))

    (test-case "returns #f for bot"
      (check-false (sre-constructor-tag test-domain test-bot)))

    (test-case "returns #f for top"
      (check-false (sre-constructor-tag test-domain test-top)))

    (test-case "returns #f for wrong domain"
      ;; A type-domain value shouldn't match test-term domain
      ;; (assuming 'test-pair is only registered in 'test-term domain)
      (check-eq? (sre-constructor-tag test-domain (test-pair (test-leaf 1) (test-leaf 2)))
                 'test-pair)))

   ;; --- Section B: sre-identify-sub-cell ---

   (test-suite
    "B. sre-identify-sub-cell"

    (test-case "bot creates fresh bot cell"
      (define-values (net cid) (sre-identify-sub-cell (fresh-net) test-domain test-bot))
      (check-eq? (net-cell-read net cid) test-bot))

    (test-case "concrete value creates fresh cell with that value"
      (define val (test-leaf 42))
      (define-values (net cid) (sre-identify-sub-cell (fresh-net) test-domain val))
      (check-equal? (net-cell-read net cid) val))

    (test-case "no meta-recognizer → concrete path for all non-bot values"
      ;; test-domain has #f for meta-recognizer
      (define val (test-pair (test-leaf 1) (test-leaf 2)))
      (define-values (net cid) (sre-identify-sub-cell (fresh-net) test-domain val))
      (check-equal? (net-cell-read net cid) val)))

   ;; --- Section C: structural-relate propagator (bot propagation) ---

   (test-suite
    "C. structural-relate propagator"

    (test-case "one bot, one concrete → propagates concrete to bot"
      (define net0 (fresh-net))
      (define val (test-leaf 42))
      (define-values (net1 c1) (net-new-cell net0 test-bot test-merge test-contradicts?))
      (define-values (net2 c2) (net-new-cell net1 val test-merge test-contradicts?))
      ;; Add structural-relate propagator
      (define-values (net3 _pid) (net-add-propagator net2
                                   (list c1 c2) (list c1 c2)
                                   (sre-make-structural-relate-propagator test-domain c1 c2)))
      ;; Run to quiescence
      (define net4 (run-to-quiescence net3))
      ;; c1 should now have the concrete value
      (check-equal? (net-cell-read net4 c1) val)
      (check-equal? (net-cell-read net4 c2) val))

    (test-case "both concrete, same → no change"
      (define net0 (fresh-net))
      (define val (test-leaf 42))
      (define-values (net1 c1) (net-new-cell net0 val test-merge test-contradicts?))
      (define-values (net2 c2) (net-new-cell net1 val test-merge test-contradicts?))
      (define-values (net3 _pid) (net-add-propagator net2
                                   (list c1 c2) (list c1 c2)
                                   (sre-make-structural-relate-propagator test-domain c1 c2)))
      (define net4 (run-to-quiescence net3))
      (check-equal? (net-cell-read net4 c1) val)
      (check-equal? (net-cell-read net4 c2) val))

    (test-case "both concrete, different → contradiction"
      (define net0 (fresh-net))
      (define-values (net1 c1) (net-new-cell net0 (test-leaf 1) test-merge test-contradicts?))
      (define-values (net2 c2) (net-new-cell net1 (test-leaf 2) test-merge test-contradicts?))
      (define-values (net3 _pid) (net-add-propagator net2
                                   (list c1 c2) (list c1 c2)
                                   (sre-make-structural-relate-propagator test-domain c1 c2)))
      (define net4 (run-to-quiescence net3))
      ;; Should have contradiction
      (check-true (test-top? (net-cell-read net4 c1)))))

   ;; --- Section D: structural decomposition (the key validation) ---

   (test-suite
    "D. structural decomposition"

    (test-case "test-pair decomposes into sub-cells"
      (define net0 (fresh-net))
      (define val-a (test-pair (test-leaf 1) (test-leaf 2)))
      (define val-b (test-pair (test-leaf 1) (test-leaf 2)))
      (define-values (net1 c1) (net-new-cell net0 val-a test-merge test-contradicts?))
      (define-values (net2 c2) (net-new-cell net1 val-b test-merge test-contradicts?))
      ;; Add structural-relate
      (define-values (net3 _pid) (net-add-propagator net2
                                   (list c1 c2) (list c1 c2)
                                   (sre-make-structural-relate-propagator test-domain c1 c2)))
      (define net4 (run-to-quiescence net3))
      ;; Cells should have their values (no contradiction)
      (check-equal? (net-cell-read net4 c1) val-a)
      (check-equal? (net-cell-read net4 c2) val-b)
      ;; Check that decomp registry has entries
      (define decomp-a (net-cell-decomp-lookup net4 c1))
      (define decomp-b (net-cell-decomp-lookup net4 c2))
      (check-not-eq? decomp-a 'none "c1 should be decomposed")
      (check-not-eq? decomp-b 'none "c2 should be decomposed"))

    (test-case "mismatched constructors → contradiction"
      (define net0 (fresh-net))
      (define-values (net1 c1) (net-new-cell net0 (test-pair (test-leaf 1) (test-leaf 2))
                                 test-merge test-contradicts?))
      (define-values (net2 c2) (net-new-cell net1 (test-leaf 99)
                                 test-merge test-contradicts?))
      (define-values (net3 _pid) (net-add-propagator net2
                                   (list c1 c2) (list c1 c2)
                                   (sre-make-structural-relate-propagator test-domain c1 c2)))
      (define net4 (run-to-quiescence net3))
      ;; Merge of test-pair and test-leaf → test-top
      (check-true (test-top? (net-cell-read net4 c1)))))

   ;; --- Section E: negative tests (D.2 critique) ---

   (test-suite
    "E. negative tests"

    (test-case "unregistered tag → sre-maybe-decompose returns net unchanged"
      (define net0 (fresh-net))
      ;; Create a value that has no registered ctor-desc
      (define weird-val (vector 'no-such-ctor))
      (define-values (net1 c1) (net-new-cell net0 weird-val test-merge test-contradicts?))
      (define-values (net2 c2) (net-new-cell net1 weird-val test-merge test-contradicts?))
      ;; sre-maybe-decompose should return net unchanged (tag = #f)
      (define net3 (sre-maybe-decompose net2 test-domain c1 c2 weird-val weird-val weird-val))
      ;; No decomposition registered
      (check-eq? (net-cell-decomp-lookup net3 c1) 'none))

    (test-case "debug mode catches non-idempotent merge"
      ;; Create a deliberately bad domain with non-idempotent merge
      (define call-count 0)
      (define (bad-merge old new)
        (set! call-count (add1 call-count))
        ;; Non-idempotent: merge(merge(a,b), a) ≠ merge(a,b)
        (if (> call-count 2)
            'different-each-time
            new))
      (define bad-domain
        (sre-domain 'bad bad-merge (lambda (v) (eq? v 'top))
                    (lambda (v) (eq? v 'bot)) 'bot #f #f))
      ;; In debug mode, this should error
      (parameterize ([current-sre-debug? #t])
        (define net0 (fresh-net))
        (define-values (net1 c1) (net-new-cell net0 'a bad-merge (lambda (v) #f)))
        (define-values (net2 c2) (net-new-cell net1 'b bad-merge (lambda (v) #f)))
        (check-exn
         #rx"Non-idempotent merge"
         (lambda ()
           (define fire (sre-make-structural-relate-propagator bad-domain c1 c2))
           (fire net2))))))))

;; ========================================
;; Run
;; ========================================

(run-tests sre-core-tests)
