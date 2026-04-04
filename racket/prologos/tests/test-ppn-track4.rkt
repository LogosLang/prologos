#lang racket/base

;;; test-ppn-track4.rkt — PPN Track 4: Elaboration as Attribute Evaluation
;;;
;;; Tests for Track 4 infrastructure: component-indexed firing, PU cell-trees,
;;; context lattice, DPO typing rules, etc. Phases add tests as they complete.

(require rackunit
         rackunit/text-ui
         prologos/propagator
         prologos/champ)

;; ============================================================
;; Phase 1a: Component-indexed propagator firing
;; ============================================================

(define phase-1a-tests
  (test-suite
   "Phase 1a: component-indexed propagator firing"

   ;; --- pu-value-diff ---

   (test-case "pu-value-diff: identical hasheqs → empty diff"
     (define m (hasheq 'a 1 'b 2))
     (check-equal? (pu-value-diff m m) '()))

   (test-case "pu-value-diff: one key changed"
     (define old (hasheq 'a 1 'b 2 'c 3))
     (define new (hasheq 'a 1 'b 99 'c 3))
     (define diff (pu-value-diff old new))
     (check-equal? (sort diff symbol<?) '(b)))

   (test-case "pu-value-diff: key added"
     (define old (hasheq 'a 1))
     (define new (hasheq 'a 1 'b 2))
     (define diff (pu-value-diff old new))
     (check-equal? (sort diff symbol<?) '(b)))

   (test-case "pu-value-diff: key removed"
     (define old (hasheq 'a 1 'b 2))
     (define new (hasheq 'a 1))
     (define diff (pu-value-diff old new))
     (check-equal? (sort diff symbol<?) '(b)))

   (test-case "pu-value-diff: multiple keys changed"
     (define old (hasheq 'a 1 'b 2 'c 3))
     (define new (hasheq 'a 99 'b 2 'c 88))
     (define diff (pu-value-diff old new))
     (check-equal? (sort diff symbol<?) '(a c)))

   (test-case "pu-value-diff: non-hash values → #f (all changed)"
     (check-false (pu-value-diff 42 43))
     (check-false (pu-value-diff "hello" "world"))
     (check-false (pu-value-diff (hasheq 'a 1) 42)))

   ;; --- filter-dependents-by-paths ---

   (test-case "filter-dependents: all paths #f → all fire"
     (define deps (champ-insert
                   (champ-insert champ-empty 1 (prop-id 1) #f)
                   2 (prop-id 2) #f))
     (define result (filter-dependents-by-paths deps '(a)))
     (check-equal? (length result) 2))

   (test-case "filter-dependents: component match → fires"
     (define deps (champ-insert champ-empty 1 (prop-id 1) 'b))
     (define result (filter-dependents-by-paths deps '(b)))
     (check-equal? (length result) 1))

   (test-case "filter-dependents: component no match → skipped"
     (define deps (champ-insert champ-empty 1 (prop-id 1) 'b))
     (define result (filter-dependents-by-paths deps '(a)))
     (check-equal? (length result) 0))

   (test-case "filter-dependents: mixed paths, only matching fire"
     (define deps (champ-insert
                   (champ-insert
                    (champ-insert champ-empty 1 (prop-id 1) #f)     ;; watch all
                    2 (prop-id 2) 'a)                                ;; watch 'a
                   3 (prop-id 3) 'b))                                ;; watch 'b
     (define result (filter-dependents-by-paths deps '(a)))
     ;; prop-id 1 (watch all) + prop-id 2 (watch 'a) = 2
     (check-equal? (length result) 2))

   (test-case "filter-dependents: #f changed-paths → all fire"
     (define deps (champ-insert
                   (champ-insert champ-empty 1 (prop-id 1) 'a)
                   2 (prop-id 2) 'b))
     (define result (filter-dependents-by-paths deps #f))
     (check-equal? (length result) 2))

   ;; --- Integration: component-indexed propagator on network ---

   (test-case "component-indexed propagator: only fires on watched component"
     ;; Create a network with one cell holding a hasheq PU value
     (define fire-count (box 0))
     (define net0 (make-prop-network))
     (define-values (net1 cid)
       (net-new-cell net0 (hasheq 'a 0 'b 0)
                     (lambda (old new)
                       ;; Merge: pointwise max
                       (for/hasheq ([(k v) (in-hash new)])
                         (values k (max v (hash-ref old k 0)))))))
     ;; Add a propagator that watches only component 'a
     (define-values (net2 pid)
       (net-add-propagator net1
                           (list cid) '()
                           (lambda (net)
                             (set-box! fire-count (add1 (unbox fire-count)))
                             net)
                           #:component-paths (list (cons cid 'a))))
     ;; Drain initial firing (net-add-propagator schedules initial fire)
     (define net2q (run-to-quiescence net2))
     (set-box! fire-count 0)
     ;; Write to component 'b — propagator should NOT fire
     (define net3 (run-to-quiescence
                   (net-cell-write net2q cid (hasheq 'a 0 'b 99))))
     (check-equal? (unbox fire-count) 0
                   "propagator watching 'a should not fire when only 'b changed")
     ;; Write to component 'a — propagator SHOULD fire
     (set-box! fire-count 0)
     (define net4 (run-to-quiescence
                   (net-cell-write net3 cid (hasheq 'a 42 'b 99))))
     (check-equal? (unbox fire-count) 1
                   "propagator watching 'a should fire when 'a changed"))

   (test-case "backward compat: propagator without component-paths fires on any change"
     (define fire-count (box 0))
     (define net0 (make-prop-network))
     (define-values (net1 cid)
       (net-new-cell net0 (hasheq 'a 0 'b 0)
                     (lambda (old new)
                       (for/hasheq ([(k v) (in-hash new)])
                         (values k (max v (hash-ref old k 0)))))))
     ;; Add propagator WITHOUT component-paths (default = watch all)
     (define-values (net2 pid)
       (net-add-propagator net1 (list cid) '()
                           (lambda (net)
                             (set-box! fire-count (add1 (unbox fire-count)))
                             net)))
     ;; Drain initial firing
     (define net2q (run-to-quiescence net2))
     (set-box! fire-count 0)
     ;; Write to component 'b — propagator SHOULD fire (no filtering)
     (define net3 (run-to-quiescence
                   (net-cell-write net2q cid (hasheq 'a 0 'b 99))))
     (check-equal? (unbox fire-count) 1
                   "propagator without component-paths should fire on any change"))
   ))


;; ============================================================
;; Run
;; ============================================================

(run-tests phase-1a-tests)
