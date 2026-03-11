#lang racket/base

;;;
;;; test-infra-cell-01.rkt — Unit tests for infra-cell.rkt
;;;
;;; Tests merge functions, cell factories, and named cell registry.
;;; Phase 0a of the Propagator-First Migration Sprint.
;;;

(require rackunit
         racket/set
         racket/string
         "../propagator.rkt"
         "../infra-cell.rkt")

;; ========================================
;; Merge Function Tests
;; ========================================

;; --- merge-hasheq-union ---

(test-case "merge-hasheq-union: bot + value = value"
  (define result (merge-hasheq-union 'infra-bot (hasheq 'a 1)))
  (check-equal? result (hasheq 'a 1)))

(test-case "merge-hasheq-union: value + bot = value"
  (define result (merge-hasheq-union (hasheq 'a 1) 'infra-bot))
  (check-equal? result (hasheq 'a 1)))

(test-case "merge-hasheq-union: disjoint keys merge"
  (define result (merge-hasheq-union (hasheq 'a 1 'b 2) (hasheq 'c 3)))
  (check-equal? (hash-ref result 'a) 1)
  (check-equal? (hash-ref result 'b) 2)
  (check-equal? (hash-ref result 'c) 3)
  (check-equal? (hash-count result) 3))

(test-case "merge-hasheq-union: overlapping keys — right wins"
  (define result (merge-hasheq-union (hasheq 'a 1 'b 2) (hasheq 'a 99)))
  (check-equal? (hash-ref result 'a) 99)
  (check-equal? (hash-ref result 'b) 2))

(test-case "merge-hasheq-union: empty + empty = empty"
  (define result (merge-hasheq-union (hasheq) (hasheq)))
  (check-equal? (hash-count result) 0))

;; --- merge-list-append ---

(test-case "merge-list-append: bot + value = value"
  (check-equal? (merge-list-append 'infra-bot '(1 2)) '(1 2)))

(test-case "merge-list-append: value + bot = value"
  (check-equal? (merge-list-append '(1 2) 'infra-bot) '(1 2)))

(test-case "merge-list-append: two lists concatenate"
  (check-equal? (merge-list-append '(a b) '(c d)) '(a b c d)))

(test-case "merge-list-append: empty + list = list"
  (check-equal? (merge-list-append '() '(x y)) '(x y)))

;; --- merge-set-union ---

(test-case "merge-set-union: bot + value = value"
  (define s (seteq 'a 'b))
  (check-equal? (merge-set-union 'infra-bot s) s))

(test-case "merge-set-union: value + bot = value"
  (define s (seteq 'a 'b))
  (check-equal? (merge-set-union s 'infra-bot) s))

(test-case "merge-set-union: disjoint sets merge"
  (define result (merge-set-union (seteq 'a 'b) (seteq 'c 'd)))
  (check-true (set-member? result 'a))
  (check-true (set-member? result 'b))
  (check-true (set-member? result 'c))
  (check-true (set-member? result 'd))
  (check-equal? (set-count result) 4))

(test-case "merge-set-union: overlapping sets — idempotent"
  (define result (merge-set-union (seteq 'a 'b) (seteq 'b 'c)))
  (check-equal? (set-count result) 3))

;; --- merge-replace ---

(test-case "merge-replace: bot + value = value"
  (check-equal? (merge-replace 'infra-bot 42) 42))

(test-case "merge-replace: value + bot = old value"
  (check-equal? (merge-replace 42 'infra-bot) 42))

(test-case "merge-replace: value + value = new value"
  (check-equal? (merge-replace 42 99) 99))

;; ========================================
;; Cell Factory Tests (on prop-network)
;; ========================================

(test-case "net-new-cell-with-merge: general factory creates cell"
  (define net0 (make-prop-network))
  (define-values (net1 cid) (net-new-cell-with-merge net0 merge-hasheq-union (hasheq)))
  (check-equal? (net-cell-read net1 cid) (hasheq)))

(test-case "net-new-registry-cell: creates hasheq cell with union merge"
  (define net0 (make-prop-network))
  (define-values (net1 cid) (net-new-registry-cell net0))
  ;; Initial content is empty hasheq
  (check-equal? (net-cell-read net1 cid) (hasheq))
  ;; Write a key
  (define net2 (net-cell-write net1 cid (hasheq 'foo 42)))
  (check-equal? (hash-ref (net-cell-read net2 cid) 'foo) 42)
  ;; Write another key — union merge
  (define net3 (net-cell-write net2 cid (hasheq 'bar 99)))
  (define content (net-cell-read net3 cid))
  (check-equal? (hash-ref content 'foo) 42)
  (check-equal? (hash-ref content 'bar) 99))

(test-case "net-new-list-cell: creates list cell with append merge"
  (define net0 (make-prop-network))
  (define-values (net1 cid) (net-new-list-cell net0))
  (check-equal? (net-cell-read net1 cid) '())
  (define net2 (net-cell-write net1 cid '(a b)))
  (check-equal? (net-cell-read net2 cid) '(a b))
  (define net3 (net-cell-write net2 cid '(c d)))
  (check-equal? (net-cell-read net3 cid) '(a b c d)))

(test-case "net-new-set-cell: creates set cell with union merge"
  (define net0 (make-prop-network))
  (define-values (net1 cid) (net-new-set-cell net0))
  (check-true (set-empty? (net-cell-read net1 cid)))
  (define net2 (net-cell-write net1 cid (seteq 'x 'y)))
  (check-equal? (set-count (net-cell-read net2 cid)) 2)
  (define net3 (net-cell-write net2 cid (seteq 'y 'z)))
  (check-equal? (set-count (net-cell-read net3 cid)) 3))

(test-case "net-new-replace-cell: creates latest-value-wins cell"
  (define net0 (make-prop-network))
  (define-values (net1 cid) (net-new-replace-cell net0))
  (check-equal? (net-cell-read net1 cid) 'infra-bot)
  (define net2 (net-cell-write net1 cid 'first))
  (check-equal? (net-cell-read net2 cid) 'first)
  (define net3 (net-cell-write net2 cid 'second))
  (check-equal? (net-cell-read net3 cid) 'second))

(test-case "net-new-replace-cell: custom initial content"
  (define net0 (make-prop-network))
  (define-values (net1 cid) (net-new-replace-cell net0 (hasheq 'type 'Nat)))
  (check-equal? (hash-ref (net-cell-read net1 cid) 'type) 'Nat))

;; ========================================
;; Multiple Cells in One Network
;; ========================================

(test-case "multiple cell types coexist in one network"
  (define net0 (make-prop-network))
  (define-values (net1 reg-cid) (net-new-registry-cell net0))
  (define-values (net2 list-cid) (net-new-list-cell net1))
  (define-values (net3 set-cid) (net-new-set-cell net2))
  (define-values (net4 def-cid) (net-new-replace-cell net3))
  ;; Write to each
  (define net5 (net-cell-write net4 reg-cid (hasheq 'a 1)))
  (define net6 (net-cell-write net5 list-cid '(warning-1)))
  (define net7 (net-cell-write net6 set-cid (seteq 'spec-a)))
  (define net8 (net-cell-write net7 def-cid 'my-value))
  ;; Read back — each cell has its own merge semantics
  (check-equal? (hash-ref (net-cell-read net8 reg-cid) 'a) 1)
  (check-equal? (net-cell-read net8 list-cid) '(warning-1))
  (check-true (set-member? (net-cell-read net8 set-cid) 'spec-a))
  (check-equal? (net-cell-read net8 def-cid) 'my-value))

;; ========================================
;; Propagator Interaction Tests
;; ========================================

(test-case "propagator fires on registry cell write"
  (define net0 (make-prop-network))
  (define-values (net1 source-cid) (net-new-registry-cell net0))
  (define-values (net2 target-cid) (net-new-list-cell net1))
  ;; Add propagator: when source changes, append a notification to target
  (define-values (net3 pid)
    (net-add-propagator net2 (list source-cid) (list target-cid)
      (lambda (net)
        (define content (net-cell-read net source-cid))
        (define keys (hash-keys content))
        (if (null? keys)
            net
            (net-cell-write net target-cid
                            (list (format "registered: ~a" keys)))))))
  ;; Write to source
  (define net4 (net-cell-write net3 source-cid (hasheq 'my-impl 'the-fn)))
  ;; Run to quiescence
  (define net5 (run-to-quiescence net4))
  ;; Target should have a notification
  (define notifications (net-cell-read net5 target-cid))
  (check-true (pair? notifications))
  (check-true (string-contains? (car notifications) "my-impl")))

(test-case "independent propagators on separate cells don't interfere"
  (define net0 (make-prop-network))
  (define-values (net1 cid-a) (net-new-registry-cell net0))
  (define-values (net2 cid-b) (net-new-registry-cell net1))
  ;; Use replace cells so repeated writes are idempotent (no double-append)
  (define-values (net3 result-a) (net-new-replace-cell net2))
  (define-values (net4 result-b) (net-new-replace-cell net3))
  ;; Two independent propagators
  (define-values (net5 _pa)
    (net-add-propagator net4 (list cid-a) (list result-a)
      (lambda (net)
        (define content (net-cell-read net cid-a))
        (if (hash-empty? content) net
            (net-cell-write net result-a 'a-fired)))))
  (define-values (net6 _pb)
    (net-add-propagator net5 (list cid-b) (list result-b)
      (lambda (net)
        (define content (net-cell-read net cid-b))
        (if (hash-empty? content) net
            (net-cell-write net result-b 'b-fired)))))
  ;; Write to A only
  (define net7 (net-cell-write net6 cid-a (hasheq 'x 1)))
  (define net8 (run-to-quiescence net7))
  (check-equal? (net-cell-read net8 result-a) 'a-fired)
  (check-equal? (net-cell-read net8 result-b) 'infra-bot))

;; ========================================
;; Named Cell Registry Tests
;; ========================================

(test-case "net-register-named-cell + net-named-cell-ref roundtrip"
  (define net0 (make-prop-network))
  (define-values (net1 cid) (net-new-registry-cell net0))
  (define names0 (hasheq))
  (define-values (net2 names1) (net-register-named-cell net1 names0 'impl-registry cid))
  (define looked-up (net-named-cell-ref names1 'impl-registry))
  (check-equal? looked-up cid))

(test-case "net-named-cell-ref errors on unknown name"
  (check-exn exn:fail?
    (lambda () (net-named-cell-ref (hasheq) 'nonexistent))))

(test-case "net-named-cell-ref/opt returns #f on unknown name"
  (check-false (net-named-cell-ref/opt (hasheq) 'nonexistent)))

(test-case "net-has-named-cell? returns #t/#f correctly"
  (define names (hasheq 'foo (cell-id 0)))
  (check-true (net-has-named-cell? names 'foo))
  (check-false (net-has-named-cell? names 'bar)))

(test-case "net-register-named-cell errors on duplicate name"
  (define net0 (make-prop-network))
  (define-values (net1 cid1) (net-new-registry-cell net0))
  (define-values (net2 cid2) (net-new-registry-cell net1))
  (define names0 (hasheq))
  (define-values (_net names1) (net-register-named-cell net2 names0 'my-cell cid1))
  (check-exn exn:fail?
    (lambda ()
      (net-register-named-cell _net names1 'my-cell cid2))))

(test-case "multiple named cells registered and retrieved"
  (define net0 (make-prop-network))
  (define-values (net1 cid-a) (net-new-registry-cell net0))
  (define-values (net2 cid-b) (net-new-list-cell net1))
  (define-values (net3 cid-c) (net-new-set-cell net2))
  (define names0 (hasheq))
  (define-values (net4 names1) (net-register-named-cell net3 names0 'registry-a cid-a))
  (define-values (net5 names2) (net-register-named-cell net4 names1 'warnings cid-b))
  (define-values (net6 names3) (net-register-named-cell net5 names2 'spec-set cid-c))
  ;; All retrievable
  (check-equal? (net-named-cell-ref names3 'registry-a) cid-a)
  (check-equal? (net-named-cell-ref names3 'warnings) cid-b)
  (check-equal? (net-named-cell-ref names3 'spec-set) cid-c)
  ;; Write through named cells and verify
  (define net7 (net-cell-write net6 (net-named-cell-ref names3 'registry-a) (hasheq 'k 42)))
  (check-equal? (hash-ref (net-cell-read net7 cid-a) 'k) 42))

;; ========================================
;; Merge Function Properties
;; ========================================

(test-case "merge-hasheq-union: idempotent (same data merged twice)"
  (define h (hasheq 'a 1 'b 2))
  (check-equal? (merge-hasheq-union h h) h))

(test-case "merge-list-append: identity element is empty list"
  (check-equal? (merge-list-append '(x) '()) '(x))
  (check-equal? (merge-list-append '() '(y)) '(y)))

(test-case "merge-set-union: idempotent"
  (define s (seteq 'a 'b 'c))
  (check-equal? (merge-set-union s s) s))

(test-case "merge-set-union: commutative"
  (define s1 (seteq 'a 'b))
  (define s2 (seteq 'c 'd))
  (check-equal? (merge-set-union s1 s2) (merge-set-union s2 s1)))

(test-case "merge-hasheq-union: associative"
  (define h1 (hasheq 'a 1))
  (define h2 (hasheq 'b 2))
  (define h3 (hasheq 'c 3))
  ;; (h1 ∪ h2) ∪ h3 = h1 ∪ (h2 ∪ h3)
  (define lhs (merge-hasheq-union (merge-hasheq-union h1 h2) h3))
  (define rhs (merge-hasheq-union h1 (merge-hasheq-union h2 h3)))
  (check-equal? lhs rhs))

;; ========================================
;; End-to-End: Registration + Write + Propagate + Read
;; ========================================

(test-case "end-to-end: register cells, write, propagate, read via names"
  (define net0 (make-prop-network))
  ;; Create and register cells
  (define-values (net1 impl-cid) (net-new-registry-cell net0))
  (define-values (net2 warn-cid) (net-new-list-cell net1))
  (define names0 (hasheq))
  (define-values (net3 names1) (net-register-named-cell net2 names0 'impl-registry impl-cid))
  (define-values (net4 names2) (net-register-named-cell net3 names1 'warnings warn-cid))
  ;; Add propagator: when impl-registry gets a new entry, emit a warning
  (define-values (net5 _pid)
    (net-add-propagator net4 (list impl-cid) (list warn-cid)
      (lambda (net)
        (define impls (net-cell-read net impl-cid))
        (if (hash-empty? impls)
            net
            (net-cell-write net warn-cid
                            (list (format "~a impl(s) registered" (hash-count impls))))))))
  ;; Write via named cell
  (define target-cid (net-named-cell-ref names2 'impl-registry))
  (define net6 (net-cell-write net5 target-cid (hasheq 'Nat-Add 'add-fn)))
  ;; Propagate
  (define net7 (run-to-quiescence net6))
  ;; Read warnings via named cell
  (define warnings (net-cell-read net7 (net-named-cell-ref names2 'warnings)))
  (check-true (pair? warnings))
  (check-true (string-contains? (car warnings) "1 impl(s) registered")))
