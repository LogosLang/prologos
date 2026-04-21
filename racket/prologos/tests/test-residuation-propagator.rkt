#lang racket/base

;;;
;;; test-residuation-propagator.rkt — PPN 4C Phase 3c-iii
;;;
;;; Cross-tag residuation propagator per D.3 §6.15.8 Q2:
;;; "does inhabitant inhabit classifier?" via subtype-lattice-merge.
;;; Contradictions are written inline; narrowings emit stratum requests.
;;;

(require rackunit
         "../prelude.rkt"  ;; for lzero, lsuc
         "../propagator.rkt"
         "../typing-propagators.rkt"
         "../syntax.rkt"
         "../type-lattice.rkt"
         "../classify-inhabit.rkt")

;; ============================================================
;; type-of-expr helper
;; ============================================================

(test-case "type-of-expr: literals classify correctly"
  (check-equal? (type-of-expr (expr-int 42)) (expr-Int))
  (check-equal? (type-of-expr (expr-nat-val 5)) (expr-Nat))
  (check-equal? (type-of-expr (expr-true)) (expr-Bool))
  (check-equal? (type-of-expr (expr-false)) (expr-Bool))
  (check-equal? (type-of-expr (expr-string "hi")) (expr-String)))

(test-case "type-of-expr: type constructors sit at Type(0)"
  (check-equal? (type-of-expr (expr-Int)) (expr-Type (lzero)))
  (check-equal? (type-of-expr (expr-Nat)) (expr-Type (lzero)))
  (check-equal? (type-of-expr (expr-Bool)) (expr-Type (lzero)))
  (check-equal? (type-of-expr (expr-String)) (expr-Type (lzero))))

(test-case "type-of-expr: Type(l) has type Type(l+1)"
  (check-equal? (type-of-expr (expr-Type (lzero))) (expr-Type (lsuc (lzero))))
  (check-equal? (type-of-expr (expr-Type (lsuc (lzero)))) (expr-Type (lsuc (lsuc (lzero))))))

(test-case "type-of-expr: metas return type-bot (defer)"
  (define m (expr-meta 'anon (cell-id 99)))
  (check-true (type-bot? (type-of-expr m))))

(test-case "type-of-expr: compound/complex expressions return type-bot (3c-iv refinement candidate)"
  (define app (expr-app (expr-fvar 'f) (expr-int 1)))
  (check-true (type-bot? (type-of-expr app))))

;; ============================================================
;; Residuation propagator (installed at meta positions)
;; ============================================================
;;
;; Direct-write test setup: bypass install-typing-network to isolate the
;; residuation propagator's behavior. Install it manually on a test cell.

(define (make-test-net-with-residuation)
  (define net0 (make-prop-network))
  (define-values (net1 tm-cid) (net-new-cell net0 (hasheq) attribute-map-merge-fn))
  (values net1 tm-cid))

(define (install-residuation net tm-cid meta-pos)
  (define-values (net* _pid)
    (net-add-propagator net (list tm-cid) (list tm-cid classify-inhabit-request-cell-id)
                        (make-classify-inhabit-residuation-fire-fn tm-cid meta-pos)
                        #:component-paths
                        (list (cons tm-cid (cons meta-pos ':type)))))
  net*)

;; --------------------------------------------------
;; Threshold: propagator does not fire until both layers populated
;; --------------------------------------------------

(test-case "residuation: threshold not met (classifier only) → no contradiction"
  (define-values (net tm-cid) (make-test-net-with-residuation))
  (define meta-pos 'test-meta)
  (define net1 (install-residuation net tm-cid meta-pos))
  (define net2 (that-write net1 tm-cid meta-pos ':type (expr-Int)))
  (define net3 (run-to-quiescence net2))
  ;; Classifier present, inhabitant absent — propagator fires but threshold not met
  (check-equal? (that-read (net-cell-read net3 tm-cid) meta-pos ':type) (expr-Int))
  ;; No contradiction
  (check-false (classify-inhabit-contradiction?
                (hash-ref (hash-ref (net-cell-read net3 tm-cid) meta-pos (hasheq))
                          ':type 'none))))

(test-case "residuation: threshold not met (inhabitant only) → no contradiction"
  (define-values (net tm-cid) (make-test-net-with-residuation))
  (define meta-pos 'test-meta-2)
  (define net1 (install-residuation net tm-cid meta-pos))
  (define net2 (that-write net1 tm-cid meta-pos ':term (expr-nat-val 5)))
  (define net3 (run-to-quiescence net2))
  ;; Inhabitant present, classifier absent — threshold not met
  (check-equal? (that-read (net-cell-read net3 tm-cid) meta-pos ':term) (expr-nat-val 5))
  (check-equal? (that-read (net-cell-read net3 tm-cid) meta-pos ':type) type-bot))

;; --------------------------------------------------
;; Compatibility: inhabitant inhabits classifier (no-op)
;; --------------------------------------------------

(test-case "residuation: compatible (Int classifier, int-42 inhabitant) → no-op"
  (define-values (net tm-cid) (make-test-net-with-residuation))
  (define meta-pos 'test-meta-compat)
  (define net1 (install-residuation net tm-cid meta-pos))
  (define net2 (that-write net1 tm-cid meta-pos ':type (expr-Int)))
  (define net3 (that-write net2 tm-cid meta-pos ':term (expr-int 42)))
  (define net4 (run-to-quiescence net3))
  ;; Both layers populated; compatible; no contradiction
  (check-equal? (that-read (net-cell-read net4 tm-cid) meta-pos ':type) (expr-Int))
  (check-equal? (that-read (net-cell-read net4 tm-cid) meta-pos ':term) (expr-int 42)))

(test-case "residuation: Option C skip dissolution — Type(0) classifier + Nat inhabitant"
  ;; §6.15.9 risk #8: the tag distinction makes Option C skip unreachable.
  ;; Under 3c framing: classifier = Type(0) (meta has type Type(0));
  ;; inhabitant = (expr-Nat) (meta is SOLVED to Nat).
  ;; type-of-expr((expr-Nat)) = Type(0). subtype-lattice-merge(Type(0), Type(0))
  ;; = Type(0). Compatible. No contradiction. Pre-3c's Option C skip was needed
  ;; because :type conflated CLASSIFIER and INHABITANT; post-3c they're
  ;; orthogonal and the residuation check resolves cleanly.
  (define-values (net tm-cid) (make-test-net-with-residuation))
  (define meta-pos 'type-meta)
  (define net1 (install-residuation net tm-cid meta-pos))
  (define net2 (that-write net1 tm-cid meta-pos ':type (expr-Type (lzero))))
  (define net3 (that-write net2 tm-cid meta-pos ':term (expr-Nat)))
  (define net4 (run-to-quiescence net3))
  ;; Both layers populated; Nat inhabits Type(0); no contradiction
  (check-equal? (that-read (net-cell-read net4 tm-cid) meta-pos ':type) (expr-Type (lzero)))
  (check-equal? (that-read (net-cell-read net4 tm-cid) meta-pos ':term) (expr-Nat)))

;; --------------------------------------------------
;; Contradiction: inhabitant does NOT inhabit classifier
;; --------------------------------------------------

(test-case "residuation: contradiction (Bool classifier, int-5 inhabitant)"
  (define-values (net tm-cid) (make-test-net-with-residuation))
  (define meta-pos 'test-meta-contra)
  (define net1 (install-residuation net tm-cid meta-pos))
  (define net2 (that-write net1 tm-cid meta-pos ':type (expr-Bool)))
  (define net3 (that-write net2 tm-cid meta-pos ':term (expr-int 5)))
  (define net4 (run-to-quiescence net3))
  ;; Contradiction: reader surfaces type-top via :type (classifier translation)
  (check-true (type-top? (that-read (net-cell-read net4 tm-cid) meta-pos ':type)))
  ;; :term read surfaces the contradiction sentinel explicitly
  (check-true (classify-inhabit-contradiction?
               (that-read (net-cell-read net4 tm-cid) meta-pos ':term))))

(test-case "residuation: contradiction (String classifier, nat-val inhabitant)"
  (define-values (net tm-cid) (make-test-net-with-residuation))
  (define meta-pos 'test-meta-contra-2)
  (define net1 (install-residuation net tm-cid meta-pos))
  (define net2 (that-write net1 tm-cid meta-pos ':type (expr-String)))
  (define net3 (that-write net2 tm-cid meta-pos ':term (expr-nat-val 3)))
  (define net4 (run-to-quiescence net3))
  (check-true (type-top? (that-read (net-cell-read net4 tm-cid) meta-pos ':type))))

;; --------------------------------------------------
;; Compound/complex inhabitants: defer (type-bot returned)
;; --------------------------------------------------

(test-case "residuation: compound inhabitant (app) → defer, no contradiction"
  (define-values (net tm-cid) (make-test-net-with-residuation))
  (define meta-pos 'test-meta-compound)
  (define net1 (install-residuation net tm-cid meta-pos))
  (define net2 (that-write net1 tm-cid meta-pos ':type (expr-Int)))
  (define compound (expr-app (expr-fvar 'f) (expr-int 1)))
  (define net3 (that-write net2 tm-cid meta-pos ':term compound))
  (define net4 (run-to-quiescence net3))
  ;; type-of-expr compound = type-bot → propagator defers, no contradiction
  (check-equal? (that-read (net-cell-read net4 tm-cid) meta-pos ':type) (expr-Int))
  (check-equal? (that-read (net-cell-read net4 tm-cid) meta-pos ':term) compound))

;; --------------------------------------------------
;; Independence: multiple positions don't interfere
;; --------------------------------------------------

(test-case "residuation: independent positions processed independently"
  (define-values (net tm-cid) (make-test-net-with-residuation))
  (define p1 'pos-1)
  (define p2 'pos-2)
  (define net1 (install-residuation net tm-cid p1))
  (define net2 (install-residuation net1 tm-cid p2))
  ;; p1: compatible (Int + int-1)
  (define net3 (that-write net2 tm-cid p1 ':type (expr-Int)))
  (define net4 (that-write net3 tm-cid p1 ':term (expr-int 1)))
  ;; p2: contradiction (Bool + nat-val)
  (define net5 (that-write net4 tm-cid p2 ':type (expr-Bool)))
  (define net6 (that-write net5 tm-cid p2 ':term (expr-nat-val 7)))
  (define net7 (run-to-quiescence net6))
  (define tm (net-cell-read net7 tm-cid))
  ;; p1 clean
  (check-equal? (that-read tm p1 ':type) (expr-Int))
  (check-equal? (that-read tm p1 ':term) (expr-int 1))
  ;; p2 contradicted
  (check-true (type-top? (that-read tm p2 ':type))))

;; --------------------------------------------------
;; Stratum handler infrastructure
;; --------------------------------------------------

(test-case "stratum handler: classify-inhabit-request cell pre-allocated in make-prop-network"
  (define net (make-prop-network))
  (define req-val (net-cell-read net classify-inhabit-request-cell-id))
  (check-true (hash? req-val))
  (check-equal? (hash-count req-val) 0))

(test-case "classify-inhabit-request-merge is hash-union"
  (define h1 (hasheq 'a 1))
  (define h2 (hasheq 'b 2))
  (define merged (classify-inhabit-request-merge h1 h2))
  (check-equal? (hash-ref merged 'a) 1)
  (check-equal? (hash-ref merged 'b) 2))
