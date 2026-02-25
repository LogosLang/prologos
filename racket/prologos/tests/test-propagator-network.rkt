#lang racket/base

;;;
;;; Tests for Phase 2c: Propagator Network — Topology and Wiring
;;; Tests: propagator creation, dependency registration, network topologies.
;;;

(require rackunit
         racket/list
         "../propagator.rkt"
         "../champ.rkt")

;; ========================================
;; Test Merge Functions
;; ========================================

(define (flat-merge old new)
  (cond [(eq? old 'bot) new]
        [(eq? new 'bot) old]
        [(equal? old new) old]
        [else 'top]))

(define (max-merge old new) (max old new))

;; ========================================
;; Helper: make a simple "copy" propagator (reads A, writes to B)
;; ========================================

(define (make-copy-fire-fn src-id dst-id)
  (lambda (net)
    (define val (net-cell-read net src-id))
    (if (eq? val 'bot)
        net
        (net-cell-write net dst-id val))))

;; ========================================
;; Helper: make an adder propagator (reads A+B, writes to C)
;; ========================================

(define (make-adder-fire-fn a-id b-id c-id)
  (lambda (net)
    (define a-val (net-cell-read net a-id))
    (define b-val (net-cell-read net b-id))
    (if (and (number? a-val) (number? b-val))
        (net-cell-write net c-id (+ a-val b-val))
        net)))

;; ========================================
;; 1. Add Propagator Basics
;; ========================================

(test-case "net-add-propagator: returns new network and prop-id"
  (define net0 (make-prop-network))
  (define-values (net1 cell-a) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cell-b) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 pid)
    (net-add-propagator net2 (list cell-a) (list cell-b)
                        (make-copy-fire-fn cell-a cell-b)))
  (check-true (prop-network? net3))
  (check-true (prop-id? pid))
  (check-equal? (prop-id-n pid) 0))

(test-case "net-add-propagator: sequential prop ids"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cb) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 pid1)
    (net-add-propagator net2 (list ca) (list cb)
                        (make-copy-fire-fn ca cb)))
  (define-values (net4 pid2)
    (net-add-propagator net3 (list ca) (list cb)
                        (make-copy-fire-fn ca cb)))
  (check-equal? (prop-id-n pid1) 0)
  (check-equal? (prop-id-n pid2) 1))

;; ========================================
;; 2. Dependency Registration
;; ========================================

(test-case "add-propagator: input cell has pid in dependents"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cb) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 pid)
    (net-add-propagator net2 (list ca) (list cb)
                        (make-copy-fire-fn ca cb)))
  (define cell-a (champ-lookup (prop-network-cells net3) (cell-id-hash ca) ca))
  (define deps (champ-keys (prop-cell-dependents cell-a)))
  (check-not-false (member pid deps) "propagator should be in input cell's dependents"))

(test-case "add-propagator: output cell does NOT have pid in dependents"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cb) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 pid)
    (net-add-propagator net2 (list ca) (list cb)
                        (make-copy-fire-fn ca cb)))
  (define cell-b (champ-lookup (prop-network-cells net3) (cell-id-hash cb) cb))
  (define deps (champ-keys (prop-cell-dependents cell-b)))
  (check-true (null? deps) "output cell should have no dependents"))

(test-case "add-propagator: multiple inputs register in all"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 0 max-merge))
  (define-values (net2 cb) (net-new-cell net1 0 max-merge))
  (define-values (net3 cc) (net-new-cell net2 0 max-merge))
  (define-values (net4 pid)
    (net-add-propagator net3 (list ca cb) (list cc)
                        (make-adder-fire-fn ca cb cc)))
  ;; Both input cells should have pid as dependent
  (define cell-a (champ-lookup (prop-network-cells net4) (cell-id-hash ca) ca))
  (define cell-b (champ-lookup (prop-network-cells net4) (cell-id-hash cb) cb))
  (check-not-false (member pid (champ-keys (prop-cell-dependents cell-a))))
  (check-not-false (member pid (champ-keys (prop-cell-dependents cell-b)))))

(test-case "add-propagator: two propagators on same input"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cb) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 cc) (net-new-cell net2 'bot flat-merge))
  (define-values (net4 pid1)
    (net-add-propagator net3 (list ca) (list cb)
                        (make-copy-fire-fn ca cb)))
  (define-values (net5 pid2)
    (net-add-propagator net4 (list ca) (list cc)
                        (make-copy-fire-fn ca cc)))
  ;; Cell A should have both propagators in its dependents
  (define cell-a (champ-lookup (prop-network-cells net5) (cell-id-hash ca) ca))
  (define deps (champ-keys (prop-cell-dependents cell-a)))
  (check-equal? (length deps) 2)
  (check-not-false (member pid1 deps))
  (check-not-false (member pid2 deps)))

;; ========================================
;; 3. Worklist Scheduling
;; ========================================

(test-case "add-propagator: propagator scheduled on worklist"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cb) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 pid)
    (net-add-propagator net2 (list ca) (list cb)
                        (make-copy-fire-fn ca cb)))
  (check-false (net-quiescent? net3) "worklist should be non-empty after add"))

(test-case "cell-write: enqueues dependents on value change"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cb) (net-new-cell net1 'bot flat-merge))
  ;; Run initial propagator firing first
  (define-values (net3 pid)
    (net-add-propagator net2 (list ca) (list cb)
                        (make-copy-fire-fn ca cb)))
  (define net4 (run-to-quiescence net3))
  ;; Now write to cell A — should enqueue pid
  (define net5 (net-cell-write net4 ca 42))
  (check-false (net-quiescent? net5)
               "worklist should be non-empty after write to input cell"))

;; ========================================
;; 4. Two-Cell Chain
;; ========================================

(test-case "chain: A → B propagation"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cb) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 _pid)
    (net-add-propagator net2 (list ca) (list cb)
                        (make-copy-fire-fn ca cb)))
  ;; Write to A and run
  (define net4 (net-cell-write net3 ca 42))
  (define net5 (run-to-quiescence net4))
  (check-equal? (net-cell-read net5 cb) 42))

(test-case "chain: A → B, write twice to A"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 0 max-merge))
  (define-values (net2 cb) (net-new-cell net1 0 max-merge))
  (define-values (net3 _pid)
    (net-add-propagator net2 (list ca) (list cb)
                        (make-copy-fire-fn ca cb)))
  (define net4 (run-to-quiescence (net-cell-write net3 ca 5)))
  (check-equal? (net-cell-read net4 cb) 5)
  (define net5 (run-to-quiescence (net-cell-write net4 ca 10)))
  (check-equal? (net-cell-read net5 cb) 10))

;; ========================================
;; 5. Diamond Network
;; ========================================

(test-case "diamond: A → B, A → C, B+C → D"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 0 max-merge))
  (define-values (net2 cb) (net-new-cell net1 0 max-merge))
  (define-values (net3 cc) (net-new-cell net2 0 max-merge))
  (define-values (net4 cd) (net-new-cell net3 0 max-merge))
  ;; A → B (doubles)
  (define-values (net5 _p1)
    (net-add-propagator net4 (list ca) (list cb)
      (lambda (net)
        (let ([v (net-cell-read net ca)])
          (if (= v 0) net (net-cell-write net cb (* v 2)))))))
  ;; A → C (triples)
  (define-values (net6 _p2)
    (net-add-propagator net5 (list ca) (list cc)
      (lambda (net)
        (let ([v (net-cell-read net ca)])
          (if (= v 0) net (net-cell-write net cc (* v 3)))))))
  ;; B+C → D (adds)
  (define-values (net7 _p3)
    (net-add-propagator net6 (list cb cc) (list cd)
                        (make-adder-fire-fn cb cc cd)))
  ;; Write 10 to A, run
  (define net8 (run-to-quiescence (net-cell-write net7 ca 10)))
  (check-equal? (net-cell-read net8 cb) 20)
  (check-equal? (net-cell-read net8 cc) 30)
  (check-equal? (net-cell-read net8 cd) 50))

;; ========================================
;; 6. Fan-Out and Fan-In
;; ========================================

(test-case "fan-out: one input drives multiple propagators"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cb) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 cc) (net-new-cell net2 'bot flat-merge))
  (define-values (net4 _p1)
    (net-add-propagator net3 (list ca) (list cb)
                        (make-copy-fire-fn ca cb)))
  (define-values (net5 _p2)
    (net-add-propagator net4 (list ca) (list cc)
                        (make-copy-fire-fn ca cc)))
  (define net6 (run-to-quiescence (net-cell-write net5 ca 42)))
  (check-equal? (net-cell-read net6 cb) 42)
  (check-equal? (net-cell-read net6 cc) 42))

(test-case "fan-in: multiple inputs to one propagator"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 0 max-merge))
  (define-values (net2 cb) (net-new-cell net1 0 max-merge))
  (define-values (net3 cc) (net-new-cell net2 0 max-merge))
  (define-values (net4 _pid)
    (net-add-propagator net3 (list ca cb) (list cc)
                        (make-adder-fire-fn ca cb cc)))
  (define net5 (run-to-quiescence (net-cell-write net4 ca 3)))
  (define net6 (run-to-quiescence (net-cell-write net5 cb 4)))
  (check-equal? (net-cell-read net6 cc) 7))

;; ========================================
;; 7. Adder Propagator (Design Doc Section 2.5)
;; ========================================

(test-case "adder: design doc example — 3 + 4 = 7"
  (define net0 (make-prop-network))
  (define-values (net1 cell-a) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cell-b) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 cell-c) (net-new-cell net2 'bot flat-merge))
  (define-values (net4 _pid)
    (net-add-propagator net3
      (list cell-a cell-b) (list cell-c)
      (make-adder-fire-fn cell-a cell-b cell-c)))
  (define net5 (net-cell-write net4 cell-a 3))
  (define net6 (net-cell-write net5 cell-b 4))
  (define net7 (run-to-quiescence net6))
  (check-equal? (net-cell-read net7 cell-c) 7))

(test-case "adder: partial input does not propagate"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cb) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 cc) (net-new-cell net2 'bot flat-merge))
  (define-values (net4 _pid)
    (net-add-propagator net3 (list ca cb) (list cc)
                        (make-adder-fire-fn ca cb cc)))
  ;; Only write to A, not B
  (define net5 (run-to-quiescence (net-cell-write net4 ca 3)))
  (check-equal? (net-cell-read net5 cc) 'bot
                "output should stay bot when not all inputs are ready"))

;; ========================================
;; 8. Chain of 3+
;; ========================================

(test-case "chain of 3: A → B → C"
  (define net0 (make-prop-network))
  (define-values (net1 ca) (net-new-cell net0 'bot flat-merge))
  (define-values (net2 cb) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 cc) (net-new-cell net2 'bot flat-merge))
  (define-values (net4 _p1)
    (net-add-propagator net3 (list ca) (list cb)
                        (make-copy-fire-fn ca cb)))
  (define-values (net5 _p2)
    (net-add-propagator net4 (list cb) (list cc)
                        (make-copy-fire-fn cb cc)))
  (define net6 (run-to-quiescence (net-cell-write net5 ca 99)))
  (check-equal? (net-cell-read net6 cb) 99)
  (check-equal? (net-cell-read net6 cc) 99))
