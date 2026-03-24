#lang racket/base

;;;
;;; test-ctor-registry.rkt — Unit tests for the constructor descriptor registry
;;;
;;; Covers: lookup, ctor-tag-for-value, decompose/reconstruct roundtrips,
;;; generic-merge, domain isolation, edge cases.
;;;
;;; Motivated by PUnify Parts 1-2 PIR §3 coverage gap: ctor-registry.rkt
;;; (571 lines) had zero dedicated unit tests.
;;;

(require rackunit
         racket/list
         "../ctor-registry.rkt"
         "../syntax.rkt"
         "../term-lattice.rkt"
         "../mult-lattice.rkt")

;; ========================================
;; Suite 1: Lookup by Tag
;; ========================================

(test-case "lookup-ctor-desc: known type tags found"
  (for ([tag '(Pi Sigma app Eq Vec Fin pair lam PVec Set Map suc)])
    (check-not-false (lookup-ctor-desc tag #:domain 'type)
                     (format "missing type descriptor for ~a" tag))))

(test-case "lookup-ctor-desc: known data tags found"
  (for ([tag '(cons nil some none suc zero pair ok err)])
    (check-not-false (lookup-ctor-desc tag #:domain 'data)
                     (format "missing data descriptor for ~a" tag))))

(test-case "lookup-ctor-desc: unknown tag returns #f"
  (check-false (lookup-ctor-desc 'nonexistent #:domain 'type))
  (check-false (lookup-ctor-desc 'nonexistent #:domain 'data)))

(test-case "lookup-ctor-desc: domain isolation — type suc ≠ data suc"
  (define type-suc (lookup-ctor-desc 'suc #:domain 'type))
  (define data-suc (lookup-ctor-desc 'suc #:domain 'data))
  (check-not-false type-suc)
  (check-not-false data-suc)
  ;; Different recognizers: type-suc recognizes expr-suc, data-suc recognizes list-encoded
  (check-true ((ctor-desc-recognizer-fn type-suc) (expr-suc (expr-zero))))
  (check-false ((ctor-desc-recognizer-fn type-suc) '(suc n)))
  (check-true ((ctor-desc-recognizer-fn data-suc) '(suc n)))
  (check-false ((ctor-desc-recognizer-fn data-suc) (expr-suc (expr-zero)))))

(test-case "lookup-ctor-desc: domain isolation — type pair ≠ data pair"
  (define type-pair (lookup-ctor-desc 'pair #:domain 'type))
  (define data-pair (lookup-ctor-desc 'pair #:domain 'data))
  (check-not-false type-pair)
  (check-not-false data-pair)
  (check-true ((ctor-desc-recognizer-fn type-pair) (expr-pair (expr-zero) (expr-zero))))
  (check-false ((ctor-desc-recognizer-fn type-pair) '(pair a b)))
  (check-true ((ctor-desc-recognizer-fn data-pair) '(pair a b)))
  (check-false ((ctor-desc-recognizer-fn data-pair) (expr-pair (expr-zero) (expr-zero)))))

;; ========================================
;; Suite 2: ctor-tag-for-value
;; ========================================

(test-case "ctor-tag-for-value: recognizes expr-Pi"
  (define v (expr-Pi 'mw (expr-tycon 'Nat) (expr-bvar 0)))
  (define desc (ctor-tag-for-value v))
  (check-not-false desc)
  (check-eq? (ctor-desc-tag desc) 'Pi))

(test-case "ctor-tag-for-value: recognizes expr-Sigma"
  (define v (expr-Sigma (expr-tycon 'Nat) (expr-bvar 0)))
  (define desc (ctor-tag-for-value v))
  (check-not-false desc)
  (check-eq? (ctor-desc-tag desc) 'Sigma))

(test-case "ctor-tag-for-value: recognizes expr-app"
  (define v (expr-app (expr-tycon 'List) (expr-tycon 'Nat)))
  (define desc (ctor-tag-for-value v))
  (check-not-false desc)
  (check-eq? (ctor-desc-tag desc) 'app))

(test-case "ctor-tag-for-value: recognizes data cons"
  (define desc (ctor-tag-for-value '(cons 1 nil)))
  (check-not-false desc)
  (check-eq? (ctor-desc-tag desc) 'cons)
  (check-eq? (ctor-desc-domain desc) 'data))

(test-case "ctor-tag-for-value: recognizes data nil"
  (define desc (ctor-tag-for-value 'nil))
  (check-not-false desc)
  (check-eq? (ctor-desc-tag desc) 'nil))

(test-case "ctor-tag-for-value: recognizes data some/none"
  (check-eq? (ctor-desc-tag (ctor-tag-for-value '(some 42))) 'some)
  (check-eq? (ctor-desc-tag (ctor-tag-for-value 'none)) 'none))

(test-case "ctor-tag-for-value: non-constructor returns #f"
  (check-false (ctor-tag-for-value 42))
  (check-false (ctor-tag-for-value "hello"))
  (check-false (ctor-tag-for-value #t))
  (check-false (ctor-tag-for-value (expr-tycon 'Nat))))

(test-case "ctor-tag-for-value: expr-suc recognized as type, not data"
  ;; Type domain is checked first
  (define desc (ctor-tag-for-value (expr-suc (expr-zero))))
  (check-not-false desc)
  (check-eq? (ctor-desc-domain desc) 'type))

;; ========================================
;; Suite 3: Decompose / Reconstruct Roundtrips
;; ========================================

;; Type constructors

(test-case "roundtrip: Pi"
  (define v (expr-Pi 'mw (expr-tycon 'Int) (expr-tycon 'Bool)))
  (define comps (generic-decompose-components v))
  (check-not-false comps)
  (check-equal? (length comps) 3)
  (define desc (lookup-ctor-desc 'Pi))
  (check-equal? (generic-reconstruct-value desc comps) v))

(test-case "roundtrip: Sigma"
  (define v (expr-Sigma (expr-tycon 'Nat) (expr-bvar 0)))
  (define comps (generic-decompose-components v))
  (check-equal? (length comps) 2)
  (define desc (lookup-ctor-desc 'Sigma))
  (check-equal? (generic-reconstruct-value desc comps) v))

(test-case "roundtrip: app"
  (define v (expr-app (expr-tycon 'List) (expr-tycon 'Int)))
  (define comps (generic-decompose-components v))
  (check-equal? (length comps) 2)
  (define desc (lookup-ctor-desc 'app))
  (check-equal? (generic-reconstruct-value desc comps) v))

(test-case "roundtrip: Eq"
  (define v (expr-Eq (expr-tycon 'Nat) (expr-zero) (expr-suc (expr-zero))))
  (define comps (generic-decompose-components v))
  (check-equal? (length comps) 3)
  (define desc (lookup-ctor-desc 'Eq))
  (check-equal? (generic-reconstruct-value desc comps) v))

(test-case "roundtrip: suc (type)"
  (define v (expr-suc (expr-suc (expr-zero))))
  (define comps (generic-decompose-components v))
  (check-equal? (length comps) 1)
  (define desc (lookup-ctor-desc 'suc))
  (check-equal? (generic-reconstruct-value desc comps) v))

(test-case "roundtrip: pair (type)"
  (define v (expr-pair (expr-tycon 'Nat) (expr-tycon 'Bool)))
  (define comps (generic-decompose-components v))
  (check-equal? (length comps) 2)
  (define desc (lookup-ctor-desc 'pair))
  (check-equal? (generic-reconstruct-value desc comps) v))

(test-case "roundtrip: Vec"
  (define v (expr-Vec (expr-tycon 'Nat) (expr-suc (expr-zero))))
  (define comps (generic-decompose-components v))
  (check-equal? (length comps) 2)
  (define desc (lookup-ctor-desc 'Vec))
  (check-equal? (generic-reconstruct-value desc comps) v))

(test-case "roundtrip: lam"
  (define v (expr-lam 'mw (expr-tycon 'Int) (expr-bvar 0)))
  (define comps (generic-decompose-components v))
  (check-equal? (length comps) 3)
  (define desc (lookup-ctor-desc 'lam))
  (check-equal? (generic-reconstruct-value desc comps) v))

;; Data constructors

(test-case "roundtrip: cons (data)"
  (define v '(cons 1 (cons 2 nil)))
  (define comps (generic-decompose-components v))
  (check-not-false comps)
  (check-equal? (length comps) 2)
  (define desc (lookup-ctor-desc 'cons #:domain 'data))
  (check-equal? (generic-reconstruct-value desc comps) v))

(test-case "roundtrip: some (data)"
  (define v '(some 42))
  (define comps (generic-decompose-components v))
  (check-equal? (length comps) 1)
  (define desc (lookup-ctor-desc 'some #:domain 'data))
  (check-equal? (generic-reconstruct-value desc comps) v))

(test-case "roundtrip: pair (data)"
  (define v '(pair a b))
  (define comps (generic-decompose-components v))
  (check-equal? (length comps) 2)
  (define desc (lookup-ctor-desc 'pair #:domain 'data))
  (check-equal? (generic-reconstruct-value desc comps) v))

(test-case "roundtrip: ok/err (data)"
  (define ok-v '(ok 1))
  (define err-v '(err "bad"))
  (define ok-desc (lookup-ctor-desc 'ok #:domain 'data))
  (define err-desc (lookup-ctor-desc 'err #:domain 'data))
  (check-equal? (generic-reconstruct-value ok-desc (generic-decompose-components ok-v)) ok-v)
  (check-equal? (generic-reconstruct-value err-desc (generic-decompose-components err-v)) err-v))

;; Arity-0

(test-case "roundtrip: arity-0 constructors"
  (for ([v '(nil none zero)])
    (define comps (generic-decompose-components v))
    (check-not-false comps (format "decompose failed for ~a" v))
    (check-equal? (length comps) 0 (format "wrong arity for ~a" v))))

(test-case "decompose: non-constructor returns #f"
  (check-false (generic-decompose-components 42))
  (check-false (generic-decompose-components "hello"))
  (check-false (generic-decompose-components (expr-tycon 'Nat))))

;; ========================================
;; Suite 4: generic-merge
;; ========================================
;;
;; NOTE: Data constructors use term-lattice-spec for component merge.
;; term-merge operates on term-lattice values (term-bot, term-top, term-var,
;; term-ctor), NOT raw Racket values. Raw atoms that aren't term-lattice
;; values fall through to term-top (absorbing element).
;;
;; For type constructors, generic-merge requires #:type-merge.
;; We test data domain (term-lattice) and type domain (with mock merge) separately.

(test-case "generic-merge: different data constructors → #f"
  (check-false (generic-merge '(some 1) 'none #:domain 'data))
  (check-false (generic-merge '(ok 1) '(err "x") #:domain 'data)))

(test-case "generic-merge: arity-0 same tag → original value"
  (check-equal? (generic-merge 'nil 'nil #:domain 'data) 'nil)
  (check-equal? (generic-merge 'none 'none #:domain 'data) 'none)
  (check-equal? (generic-merge 'zero 'zero #:domain 'data) 'zero))

(test-case "generic-merge: unrecognized values → #f"
  (check-false (generic-merge 42 42 #:domain 'data))
  (check-false (generic-merge "hello" "hello" #:domain 'data)))

(test-case "generic-merge: type domain with mock type-merge"
  ;; Use a trivial merge that returns first arg if equal, #f otherwise
  (define (mock-type-merge a b) (if (equal? a b) a #f))
  (define pi1 (expr-Pi 'mw (expr-tycon 'Nat) (expr-tycon 'Bool)))
  (define pi2 (expr-Pi 'mw (expr-tycon 'Nat) (expr-tycon 'Bool)))
  ;; Same Pi → merge succeeds (mult same, domain same, codomain same)
  (define result (generic-merge pi1 pi2 #:type-merge mock-type-merge #:domain 'type))
  (check-not-false result)
  ;; Mult merged via mult-lattice-merge (mw ⊔ mw = mw), components via mock
  (check-true (expr-Pi? result)))

(test-case "generic-merge: type domain — different domains → #f"
  (define (mock-type-merge a b) (if (equal? a b) a #f))
  (define pi1 (expr-Pi 'mw (expr-tycon 'Nat) (expr-tycon 'Bool)))
  (define pi2 (expr-Pi 'mw (expr-tycon 'Int) (expr-tycon 'Bool)))
  ;; domain mismatch: Nat ≠ Int → mock returns #f → merge fails
  (check-false (generic-merge pi1 pi2 #:type-merge mock-type-merge #:domain 'type)))

(test-case "generic-merge: different type constructors → #f"
  (define (mock-type-merge a b) (if (equal? a b) a #f))
  (define pi (expr-Pi 'mw (expr-tycon 'Nat) (expr-tycon 'Bool)))
  (define sigma (expr-Sigma (expr-tycon 'Nat) (expr-tycon 'Bool)))
  (check-false (generic-merge pi sigma #:type-merge mock-type-merge #:domain 'type)))

(test-case "generic-merge: app type with same components"
  (define (mock-type-merge a b) (if (equal? a b) a #f))
  (define v (expr-app (expr-tycon 'List) (expr-tycon 'Nat)))
  (define result (generic-merge v v #:type-merge mock-type-merge #:domain 'type))
  (check-not-false result)
  (check-equal? result v))

;; ========================================
;; Suite 5: all-ctor-descs
;; ========================================

(test-case "all-ctor-descs: type domain has 12 descriptors"
  (define descs (all-ctor-descs #:domain 'type))
  (check-equal? (length descs) 12))

(test-case "all-ctor-descs: data domain has 9 descriptors"
  (define descs (all-ctor-descs #:domain 'data))
  (check-equal? (length descs) 9))

(test-case "all-ctor-descs: total = 26"  ;; 12 type + 9 data + 5 session (SRE Track 1 Phase 3)
  (define descs (all-ctor-descs))
  (check-equal? (length descs) 26))

;; ========================================
;; Suite 6: Descriptor struct field access
;; ========================================

(test-case "ctor-desc fields: Pi"
  (define desc (lookup-ctor-desc 'Pi))
  (check-eq? (ctor-desc-tag desc) 'Pi)
  (check-equal? (ctor-desc-arity desc) 3)
  (check-equal? (ctor-desc-binder-depth desc) 1)
  (check-eq? (ctor-desc-domain desc) 'type)
  (check-equal? (length (ctor-desc-component-lattices desc)) 3))

(test-case "ctor-desc fields: cons (data)"
  (define desc (lookup-ctor-desc 'cons #:domain 'data))
  (check-eq? (ctor-desc-tag desc) 'cons)
  (check-equal? (ctor-desc-arity desc) 2)
  (check-equal? (ctor-desc-binder-depth desc) 0)
  (check-eq? (ctor-desc-domain desc) 'data))

(test-case "ctor-desc fields: nil (arity-0)"
  (define desc (lookup-ctor-desc 'nil #:domain 'data))
  (check-equal? (ctor-desc-arity desc) 0)
  (check-equal? (ctor-desc-binder-depth desc) 0))
