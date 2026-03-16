#lang racket/base

;;;
;;; test-tms-cell.rkt — Tests for TMS cell infrastructure (Track 4 Phase 1)
;;;
;;; Pure infrastructure tests: tms-cell-value struct, tms-read, tms-write,
;;; tms-commit, merge-tms-cell, and net-new-tms-cell.
;;;
;;; No dependency on the Prologos type system or metavar store.
;;;

(require rackunit
         rackunit/text-ui
         "../propagator.rkt")

;; ========================================
;; tms-cell-value struct
;; ========================================

(define tms-cell-tests
  (test-suite
   "TMS cell infrastructure"

   ;; --- Struct basics ---

   (test-case "tms-cell-value construction and access"
     (define tv (tms-cell-value 'bot (hasheq)))
     (check-true (tms-cell-value? tv))
     (check-equal? (tms-cell-value-base tv) 'bot)
     (check-equal? (tms-cell-value-branches tv) (hasheq)))

   (test-case "tms-cell-value with branches"
     (define tv (tms-cell-value 'bot (hasheq 1 'int 2 'string)))
     (check-equal? (tms-cell-value-base tv) 'bot)
     (check-equal? (hash-ref (tms-cell-value-branches tv) 1) 'int)
     (check-equal? (hash-ref (tms-cell-value-branches tv) 2) 'string))

   ;; --- tms-read ---

   (test-case "tms-read: depth 0 returns base"
     (define tv (tms-cell-value 42 (hasheq 1 99)))
     (check-equal? (tms-read tv '()) 42))

   (test-case "tms-read: depth 1 with matching branch"
     (define tv (tms-cell-value 'bot (hasheq 1 'int 2 'string)))
     (check-equal? (tms-read tv '(1)) 'int)
     (check-equal? (tms-read tv '(2)) 'string))

   (test-case "tms-read: depth 1 with no matching branch falls back to base"
     (define tv (tms-cell-value 'fallback (hasheq 1 'int)))
     (check-equal? (tms-read tv '(99)) 'fallback))

   (test-case "tms-read: depth 2 nested"
     ;; Outer H1, inner H2 → leaf value
     (define inner (tms-cell-value 'h1-base (hasheq 2 'nested-val)))
     (define tv (tms-cell-value 'bot (hasheq 1 inner)))
     (check-equal? (tms-read tv '(1 2)) 'nested-val)
     ;; Stack (1) reads inner's base
     (check-equal? (tms-read tv '(1)) 'h1-base)
     ;; Stack (1 99) — no H99 branch in inner, falls back to inner's base
     (check-equal? (tms-read tv '(1 99)) 'h1-base))

   (test-case "tms-read: depth 3 deeply nested"
     (define l3 (tms-cell-value 'l2-base (hasheq 3 'deep)))
     (define l2 (tms-cell-value 'l1-base (hasheq 2 l3)))
     (define tv (tms-cell-value 'bot (hasheq 1 l2)))
     (check-equal? (tms-read tv '(1 2 3)) 'deep)
     (check-equal? (tms-read tv '(1 2)) 'l2-base)
     (check-equal? (tms-read tv '(1)) 'l1-base)
     (check-equal? (tms-read tv '()) 'bot))

   (test-case "tms-read: non-tms-cell-value passes through"
     (check-equal? (tms-read 42 '()) 42)
     (check-equal? (tms-read 42 '(1 2)) 42))

   (test-case "tms-read: leaf value with deeper stack returns leaf"
     ;; H1 → leaf 'int (not a tms-cell-value)
     ;; Stack (1 2) — H1 maps to leaf, deeper stack entries ignored
     (define tv (tms-cell-value 'bot (hasheq 1 'int)))
     (check-equal? (tms-read tv '(1 2)) 'int))

   ;; --- tms-write ---

   (test-case "tms-write: depth 0 updates base"
     (define tv (tms-cell-value 'bot (hasheq)))
     (define tv* (tms-write tv '() 'new-base))
     (check-equal? (tms-cell-value-base tv*) 'new-base)
     ;; Branches unchanged
     (check-equal? (tms-cell-value-branches tv*) (hasheq)))

   (test-case "tms-write: depth 1 creates branch"
     (define tv (tms-cell-value 'bot (hasheq)))
     (define tv* (tms-write tv '(1) 'int))
     (check-equal? (tms-cell-value-base tv*) 'bot)
     (check-equal? (hash-ref (tms-cell-value-branches tv*) 1) 'int))

   (test-case "tms-write: depth 1 overwrites existing branch"
     (define tv (tms-cell-value 'bot (hasheq 1 'old)))
     (define tv* (tms-write tv '(1) 'new))
     (check-equal? (hash-ref (tms-cell-value-branches tv*) 1) 'new))

   (test-case "tms-write: depth 2 creates nested sub-tree"
     (define tv (tms-cell-value 'bot (hasheq)))
     (define tv* (tms-write tv '(1 2) 'nested))
     ;; Branch 1 should be a tms-cell-value with H2 → 'nested
     (define branch1 (hash-ref (tms-cell-value-branches tv*) 1))
     (check-true (tms-cell-value? branch1))
     (check-equal? (hash-ref (tms-cell-value-branches branch1) 2) 'nested))

   (test-case "tms-write: depth 2 into existing leaf promotes to sub-tree"
     ;; Start with H1 → 'leaf (plain value)
     (define tv (tms-cell-value 'bot (hasheq 1 'leaf)))
     ;; Write at (1 2) — should promote 'leaf to a sub-tree base
     (define tv* (tms-write tv '(1 2) 'nested))
     (define branch1 (hash-ref (tms-cell-value-branches tv*) 1))
     (check-true (tms-cell-value? branch1))
     ;; Old leaf value becomes the sub-tree's base
     (check-equal? (tms-cell-value-base branch1) 'leaf)
     ;; New nested value is at H2
     (check-equal? (hash-ref (tms-cell-value-branches branch1) 2) 'nested))

   (test-case "tms-write + tms-read roundtrip"
     (define tv0 (tms-cell-value 'bot (hasheq)))
     (define tv1 (tms-write tv0 '(1) 'val-h1))
     (define tv2 (tms-write tv1 '(2) 'val-h2))
     (define tv3 (tms-write tv2 '(1 3) 'val-h1-h3))
     ;; Read at various depths
     (check-equal? (tms-read tv3 '()) 'bot)
     (check-equal? (tms-read tv3 '(2)) 'val-h2)
     ;; Stack (1) — H1 is now a sub-tree (promoted from leaf), base = 'val-h1
     (check-equal? (tms-read tv3 '(1)) 'val-h1)
     ;; Stack (1 3) — nested under H1
     (check-equal? (tms-read tv3 '(1 3)) 'val-h1-h3))

   ;; --- tms-commit ---

   (test-case "tms-commit: promotes branch leaf to base"
     (define tv (tms-cell-value 'bot (hasheq 1 'committed-val)))
     (define tv* (tms-commit tv 1))
     (check-equal? (tms-cell-value-base tv*) 'committed-val)
     ;; Branch preserved for provenance
     (check-equal? (hash-ref (tms-cell-value-branches tv*) 1) 'committed-val))

   (test-case "tms-commit: promotes sub-tree base to base"
     (define inner (tms-cell-value 'inner-committed (hasheq 2 'still-here)))
     (define tv (tms-cell-value 'bot (hasheq 1 inner)))
     (define tv* (tms-commit tv 1))
     ;; Base promoted from inner's base
     (check-equal? (tms-cell-value-base tv*) 'inner-committed)
     ;; Branch preserved
     (check-true (tms-cell-value? (hash-ref (tms-cell-value-branches tv*) 1))))

   (test-case "tms-commit: no-op for missing assumption"
     (define tv (tms-cell-value 'bot (hasheq 1 'val)))
     (define tv* (tms-commit tv 99))
     (check-equal? tv tv*))

   (test-case "tms-commit: non-tms-cell-value passes through"
     (check-equal? (tms-commit 42 1) 42))

   ;; --- merge-tms-cell ---

   (test-case "merge-tms-cell: infra-bot handling"
     (define tv (tms-cell-value 'x (hasheq)))
     (check-equal? (merge-tms-cell 'infra-bot tv) tv)
     (check-equal? (merge-tms-cell tv 'infra-bot) tv))

   (test-case "merge-tms-cell: disjoint branches merged"
     (define tv1 (tms-cell-value 'b1 (hasheq 1 'a)))
     (define tv2 (tms-cell-value 'b2 (hasheq 2 'b)))
     (define merged (merge-tms-cell tv1 tv2))
     ;; Base takes new's base
     (check-equal? (tms-cell-value-base merged) 'b2)
     ;; Both branches present
     (check-equal? (hash-ref (tms-cell-value-branches merged) 1) 'a)
     (check-equal? (hash-ref (tms-cell-value-branches merged) 2) 'b))

   (test-case "merge-tms-cell: overlapping leaf branches — new wins"
     (define tv1 (tms-cell-value 'old (hasheq 1 'old-val)))
     (define tv2 (tms-cell-value 'new (hasheq 1 'new-val)))
     (define merged (merge-tms-cell tv1 tv2))
     (check-equal? (hash-ref (tms-cell-value-branches merged) 1) 'new-val))

   (test-case "merge-tms-cell: recursive merge on shared sub-trees"
     (define inner1 (tms-cell-value 'i1 (hasheq 2 'from-old)))
     (define inner2 (tms-cell-value 'i2 (hasheq 3 'from-new)))
     (define tv1 (tms-cell-value 'b1 (hasheq 1 inner1)))
     (define tv2 (tms-cell-value 'b2 (hasheq 1 inner2)))
     (define merged (merge-tms-cell tv1 tv2))
     (define merged-inner (hash-ref (tms-cell-value-branches merged) 1))
     (check-true (tms-cell-value? merged-inner))
     ;; Inner base takes new's
     (check-equal? (tms-cell-value-base merged-inner) 'i2)
     ;; Both inner branches present
     (check-equal? (hash-ref (tms-cell-value-branches merged-inner) 2) 'from-old)
     (check-equal? (hash-ref (tms-cell-value-branches merged-inner) 3) 'from-new))

   ;; --- net-new-tms-cell ---

   (test-case "net-new-tms-cell: creates cell in network"
     (define net (make-prop-network))
     (define-values (net* cid) (net-new-tms-cell net 'type-bot))
     (check-true (cell-id? cid))
     (define val (net-cell-read net* cid))
     (check-true (tms-cell-value? val))
     (check-equal? (tms-cell-value-base val) 'type-bot)
     (check-equal? (tms-cell-value-branches val) (hasheq)))

   (test-case "net-new-tms-cell: write and read via network"
     (define net (make-prop-network))
     (define-values (net* cid) (net-new-tms-cell net 'bot))
     ;; Write a speculative value at depth 1 (assumption H=1)
     (define old-val (net-cell-read net* cid))
     (define new-val (tms-write old-val '(1) 'solved))
     (define net** (net-cell-write net* cid new-val))
     ;; Read at depth 0 — should see base (because merge-tms-cell base = new's base = 'bot)
     (define read-val (net-cell-read net** cid))
     ;; At depth 1 under H1
     (check-equal? (tms-read read-val '(1)) 'solved)
     ;; At depth 0 — base
     (check-equal? (tms-read read-val '()) 'bot))

   ;; --- Speculation workflow simulation ---

   (test-case "speculation workflow: write under H1, fail, write under H2, succeed"
     (define net0 (make-prop-network))
     (define-values (net1 cid) (net-new-tms-cell net0 'bot))
     ;; Snapshot for belt-and-suspenders
     (define snapshot net1)
     ;; Speculation H1: write 'int
     (define val1 (net-cell-read net1 cid))
     (define val1* (tms-write val1 '(1) 'int))
     (define net2 (net-cell-write net1 cid val1*))
     ;; H1 fails — restore snapshot (belt-and-suspenders)
     ;; In TMS terms: retract H1 (reads at '() won't follow H1)
     ;; With belt-and-suspenders, we also restore:
     (define net3 snapshot)
     ;; Speculation H2: write 'string
     (define val2 (net-cell-read net3 cid))
     (define val2* (tms-write val2 '(2) 'string))
     (define net4 (net-cell-write net3 cid val2*))
     ;; H2 succeeds — commit
     (define val-final (net-cell-read net4 cid))
     (define val-committed (tms-commit val-final 2))
     ;; After commit, base should be 'string
     (check-equal? (tms-cell-value-base val-committed) 'string)
     ;; Branch 2 preserved for provenance
     (check-equal? (hash-ref (tms-cell-value-branches val-committed) 2) 'string))

   (test-case "nested speculation: union-of-unions pattern"
     (define net0 (make-prop-network))
     (define-values (net1 cid) (net-new-tms-cell net0 'bot))
     ;; Outer H1, inner H2 (fails), inner H3 (succeeds)
     ;; Write at depth (1 2) — H1 outer, H2 inner
     (define v0 (net-cell-read net1 cid))
     (define v1 (tms-write v0 '(1 2) 'nat))   ;; inner speculation: try Nat
     ;; H2 fails — read at (1) should see base of H1's sub-tree (= tms-bot)
     ;; because we haven't written at (1) alone
     (check-equal? (tms-read v1 '(1)) 'tms-bot)
     ;; H3 succeeds — write at (1 3)
     (define v2 (tms-write v1 '(1 3) 'int))
     ;; Read at (1 3) — committed inner
     (check-equal? (tms-read v2 '(1 3)) 'int)
     ;; Commit H3 under H1's sub-tree
     (define h1-subtree (hash-ref (tms-cell-value-branches v2) 1))
     (check-true (tms-cell-value? h1-subtree))
     (define h1-committed (tms-commit h1-subtree 3))
     (check-equal? (tms-cell-value-base h1-committed) 'int)
     ;; H2's branch preserved as negative knowledge
     (check-equal? (hash-ref (tms-cell-value-branches h1-committed) 2) 'nat))

   ))

(run-tests tms-cell-tests 'verbose)
