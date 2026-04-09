#lang racket/base

;;;
;;; test-trace-serialize.rkt — Tests for Phase 2: Network Serialization
;;;
;;; Validates: lattice value display, cell-diff/bsp-round/prop-trace JSON
;;; serialization, network topology extraction, round-trip via jsexpr->string.
;;;

(require rackunit
         json
         "../propagator.rkt"
         "../trace-serialize.rkt"
         "../type-lattice.rkt")

;; ========================================
;; Lattice Value Serialization
;; ========================================

(test-case "serialize-lattice-value: type-bot → ⊥"
  (check-equal? (serialize-lattice-value type-bot) "⊥"))

(test-case "serialize-lattice-value: type-top → ⊤"
  (check-equal? (serialize-lattice-value type-top) "⊤"))

(test-case "serialize-lattice-value: raw bot symbol"
  (check-equal? (serialize-lattice-value 'bot) "⊥"))

(test-case "serialize-lattice-value: number"
  (check-equal? (serialize-lattice-value 42) "42"))

(test-case "serialize-lattice-value: string passthrough"
  (check-equal? (serialize-lattice-value "hello") "hello"))

(test-case "serialize-lattice-value: symbol"
  (check-equal? (serialize-lattice-value 'omega) "omega"))

(test-case "serialize-lattice-value: hash summary"
  (define h (hasheq 'a 1 'b 2 'c 3))
  (check-equal? (serialize-lattice-value h) "hash(3 entries)"))

(test-case "serialize-lattice-value: boolean"
  (check-equal? (serialize-lattice-value #t) "true")
  (check-equal? (serialize-lattice-value #f) "false"))

;; ========================================
;; Cell Diff Serialization
;; ========================================

(test-case "serialize-cell-diff: basic"
  (define cd (cell-diff (cell-id 5) 'bot 42 (prop-id 3)))
  (define js (serialize-cell-diff cd))
  (check-equal? (hash-ref js 'cellId) 5)
  (check-equal? (hash-ref js 'oldValue) "⊥")
  (check-equal? (hash-ref js 'newValue) "42")
  (check-equal? (hash-ref js 'sourcePropagator) 3))

;; ========================================
;; ATMS Event Serialization
;; ========================================

(test-case "serialize-atms-event: assume"
  (define e (atms-event:assume (cell-id 1) 'alpha))
  (define js (serialize-atms-event e))
  (check-equal? (hash-ref js 'type) "assume")
  (check-equal? (hash-ref js 'cellId) 1)
  (check-equal? (hash-ref js 'label) "alpha"))

(test-case "serialize-atms-event: retract"
  (define e (atms-event:retract (cell-id 2) 'beta 'contradiction))
  (define js (serialize-atms-event e))
  (check-equal? (hash-ref js 'type) "retract")
  (check-equal? (hash-ref js 'reason) "contradiction"))

(test-case "serialize-atms-event: nogood"
  (define e (atms-event:nogood '(a1 a2) '(c1)))
  (define js (serialize-atms-event e))
  (check-equal? (hash-ref js 'type) "nogood")
  (check-equal? (hash-ref js 'nogoodSet) '("a1" "a2"))
  (check-equal? (hash-ref js 'explanation) '("c1")))

;; ========================================
;; BSP Round Serialization
;; ========================================

(test-case "serialize-bsp-round: empty round"
  (define r (bsp-round 0 (make-prop-network) '() '() #f '()))
  (define js (serialize-bsp-round r))
  (check-equal? (hash-ref js 'roundNumber) 0)
  (check-equal? (hash-ref js 'cellDiffs) '())
  (check-equal? (hash-ref js 'propagatorsFired) '())
  (check-equal? (hash-ref js 'contradiction) (json-null))
  (check-equal? (hash-ref js 'atmsEvents) '()))

(test-case "serialize-bsp-round: with diffs and contradiction"
  (define diffs (list (cell-diff (cell-id 0) 'bot 10 (prop-id 1))))
  (define r (bsp-round 2 (make-prop-network) diffs (list (prop-id 1)) (cell-id 0) '()))
  (define js (serialize-bsp-round r))
  (check-equal? (hash-ref js 'roundNumber) 2)
  (check-equal? (length (hash-ref js 'cellDiffs)) 1)
  (check-equal? (hash-ref js 'propagatorsFired) '(1))
  (check-equal? (hash-ref js 'contradiction) 0))

;; ========================================
;; Network Topology Serialization
;; ========================================

(test-case "serialize-network-topology: empty network"
  (define js (serialize-network-topology (make-prop-network)))
  (check-equal? (hash-ref (hash-ref js 'stats) 'totalCells) 2)  ;; PAR Track 1: request cell at id 0, BSP-LE Track 2: worldview cache at id 1
  (check-equal? (hash-ref (hash-ref js 'stats) 'totalPropagators) 0)
  (check-equal? (hash-ref (hash-ref js 'stats) 'contradiction) (json-null)))

(test-case "serialize-network-topology: network with cells and propagator"
  (define net0 (make-prop-network))
  (define merge (lambda (old new) new))
  (define-values (net1 cid-a) (net-new-cell net0 'bot merge))
  (define-values (net2 cid-b) (net-new-cell net1 'bot merge))
  (define (copy-fn net)
    (define v (net-cell-read net cid-a))
    (if (eq? v 'bot) net (net-cell-write net cid-b v)))
  (define-values (net3 pid) (net-add-propagator net2 (list cid-a) (list cid-b) copy-fn))
  (define js (serialize-network-topology net3))
  (check-equal? (hash-ref (hash-ref js 'stats) 'totalCells) 4)  ;; PAR Track 1: +1 request cell, BSP-LE Track 2: +1 worldview cache
  (check-equal? (hash-ref (hash-ref js 'stats) 'totalPropagators) 1)
  ;; Check propagator has correct inputs/outputs
  (define prop-json (car (hash-ref js 'propagators)))
  (check-equal? (hash-ref prop-json 'inputs) (list (cell-id-n cid-a)))
  (check-equal? (hash-ref prop-json 'outputs) (list (cell-id-n cid-b))))

;; ========================================
;; Full Prop Trace Serialization
;; ========================================

(test-case "serialize-prop-trace: minimal trace"
  (define net (make-prop-network))
  (define tr (prop-trace net '() net (hasheq 'file "test.prologos")))
  (define js (serialize-prop-trace tr))
  (check-true (hash? js))
  (check-true (hash-has-key? js 'initialNetwork))
  (check-true (hash-has-key? js 'rounds))
  (check-true (hash-has-key? js 'finalNetwork))
  (check-true (hash-has-key? js 'metadata))
  (check-equal? (hash-ref (hash-ref js 'metadata) 'file) "test.prologos"))

;; ========================================
;; Round-trip: trace → JSON string
;; ========================================

(test-case "trace->json-string: produces valid JSON"
  (define net (make-prop-network))
  (define diffs (list (cell-diff (cell-id 0) 'bot 42 (prop-id 0))))
  (define rounds (list (bsp-round 0 net diffs (list (prop-id 0)) #f '())))
  (define tr (prop-trace net rounds net (hasheq 'fuel-used 100)))
  (define json-str (trace->json-string tr))
  ;; Should be a valid JSON string
  (check-true (string? json-str))
  ;; Should parse back successfully
  (define parsed (string->jsexpr json-str))
  (check-true (hash? parsed))
  (check-equal? (hash-ref (hash-ref parsed 'metadata) 'fuel-used) 100)
  (check-equal? (length (hash-ref parsed 'rounds)) 1))

;; ========================================
;; Integration: BSP observer → serialize
;; ========================================

(test-case "end-to-end: BSP observer capture → serialization"
  (define-values (observe get-rounds) (make-trace-accumulator))
  (define net0 (make-prop-network))
  (define merge (lambda (old new) new))
  (define-values (net1 cid-a) (net-new-cell net0 'bot merge))
  (define-values (net2 cid-b) (net-new-cell net1 'bot merge))
  (define (copy-fn net)
    (define v (net-cell-read net cid-a))
    (if (eq? v 'bot) net (net-cell-write net cid-b v)))
  (define-values (net3 pid) (net-add-propagator net2 (list cid-a) (list cid-b) copy-fn))
  (define net4 (net-cell-write net3 cid-a 99))
  (define final
    (parameterize ([current-bsp-observer observe])
      (run-to-quiescence-bsp net4)))
  (define tr (prop-trace net4 (get-rounds) final (hasheq 'test #t)))
  ;; Serialize to JSON and back
  (define json-str (trace->json-string tr))
  (define parsed (string->jsexpr json-str))
  (check-true (>= (length (hash-ref parsed 'rounds)) 1))
  ;; Check the diff in round 0
  (define round0 (car (hash-ref parsed 'rounds)))
  (define diffs (hash-ref round0 'cellDiffs))
  (check-true (>= (length diffs) 1)))
