#lang racket/base

;;;
;;; Tests for Phase 2a-2b: Propagator Network — Core Operations
;;; Tests: struct construction, cell CRUD, merge behavior, contradiction.
;;;

(require rackunit
         racket/list
         "../propagator.rkt"
         "../champ.rkt")

;; ========================================
;; Test Merge Functions
;; ========================================

;; Flat lattice: 'bot → value → 'top
(define (flat-merge old new)
  (cond [(eq? old 'bot) new]
        [(eq? new 'bot) old]
        [(equal? old new) old]
        [else 'top]))

(define (flat-contradicts? v) (eq? v 'top))

;; Max merge (numeric cells)
(define (max-merge old new) (max old new))

;; Set merge (list-based)
(define (set-merge old new)
  (remove-duplicates (append old new)))

;; ========================================
;; 1. Network Creation
;; ========================================

(test-case "make-prop-network: creates empty network"
  (define net (make-prop-network))
  (check-true (prop-network? net))
  (check-true (net-quiescent? net))
  (check-false (net-contradiction? net))
  (check-equal? (prop-network-next-cell-id net) 1)  ;; PAR Track 1: cell-id 0 is decomp-request cell
  (check-equal? (prop-network-next-prop-id net) 0))

(test-case "make-prop-network: custom fuel"
  (define net (make-prop-network 500))
  (check-equal? (net-fuel-remaining net) 500))

(test-case "make-prop-network: default fuel is 1000000"
  (define net (make-prop-network))
  (check-equal? (net-fuel-remaining net) 1000000))

;; ========================================
;; 2. Hash Helpers
;; ========================================

(test-case "cell-id-hash: returns the integer"
  (check-equal? (cell-id-hash (cell-id 42)) 42))

(test-case "prop-id-hash: returns the integer"
  (check-equal? (prop-id-hash (prop-id 7)) 7))

;; ========================================
;; 3. Cell Creation
;; ========================================

(test-case "net-new-cell: returns new network and cell-id"
  (define net (make-prop-network))
  (define-values (net1 cid) (net-new-cell net 'bot flat-merge))
  (check-true (prop-network? net1))
  (check-true (cell-id? cid))
  (check-equal? (cell-id-n cid) 1))  ;; PAR Track 1: first user cell is 1 (0 = request cell)

(test-case "net-new-cell: sequential cell ids"
  (define net (make-prop-network))
  (define-values (net1 cid1) (net-new-cell net 'bot flat-merge))
  (define-values (net2 cid2) (net-new-cell net1 'bot flat-merge))
  (define-values (net3 cid3) (net-new-cell net2 'bot flat-merge))
  (check-equal? (cell-id-n cid1) 1)  ;; PAR Track 1: offset by 1
  (check-equal? (cell-id-n cid2) 2)
  (check-equal? (cell-id-n cid3) 3))

(test-case "net-new-cell: initial value accessible"
  (define-values (net cid) (net-new-cell (make-prop-network) 42 max-merge))
  (check-equal? (net-cell-read net cid) 42))

(test-case "net-new-cell: with contradiction predicate"
  (define-values (net cid)
    (net-new-cell (make-prop-network) 'bot flat-merge flat-contradicts?))
  (check-equal? (net-cell-read net cid) 'bot)
  (check-false (net-contradiction? net)))

;; ========================================
;; 4. Cell Read
;; ========================================

(test-case "net-cell-read: returns initial value"
  (define-values (net cid) (net-new-cell (make-prop-network) 'hello max-merge))
  (check-equal? (net-cell-read net cid) 'hello))

(test-case "net-cell-read: error on unknown cell"
  (define net (make-prop-network))
  (check-exn exn:fail? (lambda () (net-cell-read net (cell-id 999)))))

;; ========================================
;; 5. Cell Write — Merge Behavior
;; ========================================

(test-case "cell-write: flat-merge bot + value = value"
  (define-values (net cid) (net-new-cell (make-prop-network) 'bot flat-merge))
  (define net1 (net-cell-write net cid 42))
  (check-equal? (net-cell-read net1 cid) 42))

(test-case "cell-write: flat-merge same value = no change"
  (define-values (net cid) (net-new-cell (make-prop-network) 42 flat-merge))
  (define net1 (net-cell-write net cid 42))
  ;; Should return the exact same network object (eq?)
  (check-eq? net1 net))

(test-case "cell-write: flat-merge different values = top"
  (define-values (net cid) (net-new-cell (make-prop-network) 'bot flat-merge))
  (define net1 (net-cell-write net cid 1))
  (define net2 (net-cell-write net1 cid 2))
  (check-equal? (net-cell-read net2 cid) 'top))

(test-case "cell-write: max-merge increases monotonically"
  (define-values (net cid) (net-new-cell (make-prop-network) 0 max-merge))
  (define net1 (net-cell-write net cid 5))
  (define net2 (net-cell-write net1 cid 3))
  (define net3 (net-cell-write net2 cid 7))
  (check-equal? (net-cell-read net1 cid) 5)
  (check-equal? (net-cell-read net2 cid) 5)  ;; 3 < 5, no change
  (check-equal? (net-cell-read net3 cid) 7))

(test-case "cell-write: max-merge no change returns same net"
  (define-values (net cid) (net-new-cell (make-prop-network) 10 max-merge))
  (define net1 (net-cell-write net cid 5))
  (check-eq? net1 net))  ;; max(10,5)=10, no change

(test-case "cell-write: set-merge accumulates elements"
  (define-values (net cid) (net-new-cell (make-prop-network) '() set-merge))
  (define net1 (net-cell-write net cid '(a)))
  (define net2 (net-cell-write net1 cid '(b)))
  (define net3 (net-cell-write net2 cid '(a c)))
  (define result (sort (net-cell-read net3 cid) symbol<?))
  (check-equal? result '(a b c)))

(test-case "cell-write: error on unknown cell"
  (define net (make-prop-network))
  (check-exn exn:fail? (lambda () (net-cell-write net (cell-id 999) 42))))

;; ========================================
;; 6. Contradiction Detection
;; ========================================

(test-case "contradiction: flat-top triggers contradiction"
  (define-values (net cid)
    (net-new-cell (make-prop-network) 'bot flat-merge flat-contradicts?))
  (define net1 (net-cell-write net cid 1))
  (check-false (net-contradiction? net1))
  (define net2 (net-cell-write net1 cid 2))  ;; 1 ≠ 2 → top
  (check-true (net-contradiction? net2))
  (check-equal? (prop-network-contradiction net2) cid))

(test-case "contradiction: cell without predicate never contradicts"
  (define-values (net cid) (net-new-cell (make-prop-network) 'bot flat-merge))
  (define net1 (net-cell-write net cid 1))
  (define net2 (net-cell-write net1 cid 2))  ;; top, but no predicate
  (check-false (net-contradiction? net2))
  (check-equal? (net-cell-read net2 cid) 'top))

;; ========================================
;; 7. Convenience Queries
;; ========================================

(test-case "net-quiescent?: true for fresh network"
  (check-true (net-quiescent? (make-prop-network))))

(test-case "net-contradiction?: false for fresh network"
  (check-false (net-contradiction? (make-prop-network))))

;; ========================================
;; Phase 4: Batch Cell Registration
;; ========================================

(test-case "net-new-cells-batch: empty specs returns unchanged network"
  (define net (make-prop-network))
  (define-values (net* ids) (net-new-cells-batch net '()))
  (check-eq? net* net)
  (check-equal? ids '()))

(test-case "net-new-cells-batch: creates N cells with contiguous IDs"
  (define net (make-prop-network))
  (define specs (list (list 'bot flat-merge)
                      (list 'bot flat-merge)
                      (list 'bot flat-merge)))
  (define-values (net* ids) (net-new-cells-batch net specs))
  (check-equal? (length ids) 3)
  (check-equal? (map cell-id-n ids) '(1 2 3))  ;; PAR Track 1: offset by 1
  ;; All cells readable with initial values
  (for ([cid (in-list ids)])
    (check-equal? (net-cell-read net* cid) 'bot))
  ;; next-cell-id advanced by 3 from 1
  (check-equal? (prop-network-next-cell-id net*) 4))

(test-case "net-new-cells-batch: cells are writable and merge correctly"
  (define net (make-prop-network))
  (define specs (list (list 0 max-merge)
                      (list 0 max-merge)))
  (define-values (net* ids) (net-new-cells-batch net specs))
  (define c0 (car ids))
  (define c1 (cadr ids))
  (define net2 (net-cell-write net* c0 42))
  (define net3 (net-cell-write net2 c1 99))
  (check-equal? (net-cell-read net3 c0) 42)
  (check-equal? (net-cell-read net3 c1) 99))

(test-case "net-new-cells-batch: contradiction function works"
  (define net (make-prop-network))
  (define specs (list (list 'bot flat-merge (lambda (v) (eq? v 'top)))))
  (define-values (net* ids) (net-new-cells-batch net specs))
  (define cid (car ids))
  ;; Write non-contradictory
  (define net2 (net-cell-write net* cid 42))
  (check-false (prop-network-contradiction net2))
  ;; Write contradictory
  (define net3 (net-cell-write net2 cid 'top))
  (check-equal? (prop-network-contradiction net3) cid))

(test-case "net-new-cells-batch: IDs continue from existing cells"
  (define net (make-prop-network))
  (define-values (net1 existing-id) (net-new-cell net 'bot flat-merge))
  (define specs (list (list 'bot flat-merge)
                      (list 'bot flat-merge)))
  (define-values (net2 ids) (net-new-cells-batch net1 specs))
  ;; PAR Track 1: existing cell is ID 1 (0 = request cell), batch starts at 2
  (check-equal? (cell-id-n existing-id) 1)
  (check-equal? (map cell-id-n ids) '(2 3))
  (check-equal? (prop-network-next-cell-id net2) 4))
