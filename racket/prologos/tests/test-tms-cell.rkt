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

   (test-case "tms-read: nested fallback to outer hypothesis (Phase 4 fix)"
     ;; Cell has branch for H1 (outer) but NOT for H2 (inner).
     ;; Stack (H2 H1) — H2 missing, should fall back to try H1.
     ;; Before Phase 4 fix, this fell to base instead.
     (define tv (tms-cell-value 'base (hasheq 1 'outer-val)))
     (check-equal? (tms-read tv '(2 1)) 'outer-val)
     ;; Also check: no branch for either → falls to base
     (check-equal? (tms-read tv '(3 4)) 'base))

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

   (test-case "tms-commit: flattens sub-tree into outer cell"
     (define inner (tms-cell-value 'inner-committed (hasheq 2 'still-here)))
     (define tv (tms-cell-value 'bot (hasheq 1 inner)))
     (define tv* (tms-commit tv 1))
     ;; Base promoted from inner's base (non-bot)
     (check-equal? (tms-cell-value-base tv*) 'inner-committed)
     ;; Inner's branches merged into outer; committed branch removed
     (check-false (hash-ref (tms-cell-value-branches tv*) 1 #f))
     (check-equal? (hash-ref (tms-cell-value-branches tv*) 2) 'still-here))

   (test-case "tms-commit: sub-tree with tms-bot base preserves outer base"
     (define inner (tms-cell-value 'tms-bot (hasheq 2 'nested-val)))
     (define tv (tms-cell-value 'outer-base (hasheq 1 inner)))
     (define tv* (tms-commit tv 1))
     ;; tms-bot base means keep outer base
     (check-equal? (tms-cell-value-base tv*) 'outer-base)
     ;; Inner's branches merged into outer
     (check-false (hash-ref (tms-cell-value-branches tv*) 1 #f))
     (check-equal? (hash-ref (tms-cell-value-branches tv*) 2) 'nested-val))

   (test-case "tms-commit: no-op for missing assumption"
     (define tv (tms-cell-value 'bot (hasheq 1 'val)))
     (define tv* (tms-commit tv 99))
     (check-equal? tv tv*))

   (test-case "tms-commit: non-tms-cell-value passes through"
     (check-equal? (tms-commit 42 1) 42))

   ;; --- tms-retract ---

   (test-case "tms-retract: removes branch for assumption"
     (define tv (tms-cell-value 'base (hasheq 1 'val1 2 'val2)))
     (define tv* (tms-retract tv 1))
     (check-equal? (tms-cell-value-base tv*) 'base)
     (check-false (hash-ref (tms-cell-value-branches tv*) 1 #f))
     (check-equal? (hash-ref (tms-cell-value-branches tv*) 2) 'val2))

   (test-case "tms-retract: no-op for missing assumption"
     (define tv (tms-cell-value 'base (hasheq 1 'val)))
     (define tv* (tms-retract tv 99))
     (check-eq? tv tv*))

   (test-case "tms-retract: non-tms-cell-value passes through"
     (check-equal? (tms-retract 42 1) 42))

   (test-case "tms-retract: removes sub-tree branch"
     (define inner (tms-cell-value 'inner-base (hasheq 2 'nested)))
     (define tv (tms-cell-value 'base (hasheq 1 inner)))
     (define tv* (tms-retract tv 1))
     (check-equal? (tms-cell-value-base tv*) 'base)
     (check-false (hash-ref (tms-cell-value-branches tv*) 1 #f)))

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
     ;; net-cell-read returns TMS-unwrapped value (the base at depth 0)
     (check-equal? (net-cell-read net* cid) 'type-bot)
     ;; net-cell-read-raw returns the full tms-cell-value
     (define raw (net-cell-read-raw net* cid))
     (check-true (tms-cell-value? raw))
     (check-equal? (tms-cell-value-base raw) 'type-bot)
     (check-equal? (tms-cell-value-branches raw) (hasheq)))

   (test-case "net-new-tms-cell: TMS-transparent write and read via network"
     (define net (make-prop-network))
     (define-values (net* cid) (net-new-tms-cell net 'bot))
     ;; Write a plain value 'solved — TMS-transparent write wraps it at depth 0
     (define net** (net-cell-write net* cid 'solved))
     ;; Read at depth 0 — should see 'solved (base was updated)
     (check-equal? (net-cell-read net** cid) 'solved)
     ;; Raw value shows TMS structure
     (define raw (net-cell-read-raw net** cid))
     (check-true (tms-cell-value? raw))
     (check-equal? (tms-cell-value-base raw) 'solved))

   (test-case "net-new-tms-cell: speculative write via parameterize"
     (define net (make-prop-network))
     (define-values (net* cid) (net-new-tms-cell net 'bot))
     ;; Write under speculation H=1 using TMS-transparent net-cell-write
     (define net**
       (parameterize ([current-speculation-stack '(1)])
         (net-cell-write net* cid 'solved)))
     ;; At depth 0 — should see base 'bot (speculation hasn't committed)
     (check-equal? (net-cell-read net** cid) 'bot)
     ;; At depth 1 under H1 — should see 'solved
     (check-equal?
      (parameterize ([current-speculation-stack '(1)])
        (net-cell-read net** cid))
      'solved))

   ;; --- Speculation workflow simulation ---

   (test-case "speculation workflow: TMS-transparent write under H1, fail, write under H2, succeed"
     (define net0 (make-prop-network))
     (define-values (net1 cid) (net-new-tms-cell net0 'bot))
     ;; Snapshot for belt-and-suspenders
     (define snapshot net1)
     ;; Speculation H1: write 'int via TMS-transparent API
     (define net2
       (parameterize ([current-speculation-stack '(1)])
         (net-cell-write net1 cid 'int)))
     ;; Verify: at depth 1 under H1, reads 'int
     (check-equal?
      (parameterize ([current-speculation-stack '(1)])
        (net-cell-read net2 cid))
      'int)
     ;; At depth 0, still 'bot
     (check-equal? (net-cell-read net2 cid) 'bot)
     ;; H1 fails — restore snapshot (belt-and-suspenders)
     (define net3 snapshot)
     ;; Speculation H2: write 'string
     (define net4
       (parameterize ([current-speculation-stack '(2)])
         (net-cell-write net3 cid 'string)))
     ;; H2 succeeds — commit
     (define raw-final (net-cell-read-raw net4 cid))
     (define committed (tms-commit raw-final 2))
     ;; After commit, base should be 'string
     (check-equal? (tms-cell-value-base committed) 'string)
     ;; Branch 2 preserved for provenance
     (check-equal? (hash-ref (tms-cell-value-branches committed) 2) 'string))

   (test-case "nested speculation: union-of-unions pattern with TMS-transparent API"
     (define net0 (make-prop-network))
     (define-values (net1 cid) (net-new-tms-cell net0 'bot))
     ;; Outer H1, inner H2 (fails), inner H3 (succeeds)
     ;; Write at depth (1 2) — H1 outer, H2 inner
     (define net2
       (parameterize ([current-speculation-stack '(1 2)])
         (net-cell-write net1 cid 'nat)))
     ;; At depth (1) — should see 'bot (base of H1's sub-tree = tms-bot)
     (define raw2 (net-cell-read-raw net2 cid))
     (check-equal? (tms-read raw2 '(1)) 'tms-bot)
     ;; H2 fails — belt-and-suspenders restore
     ;; H3 succeeds — write at (1 3)
     (define net3
       (parameterize ([current-speculation-stack '(1 3)])
         (net-cell-write net1 cid 'int)))
     ;; Read at (1 3) via TMS-transparent API
     (check-equal?
      (parameterize ([current-speculation-stack '(1 3)])
        (net-cell-read net3 cid))
      'int)
     ;; Verify raw structure
     (define raw3 (net-cell-read-raw net3 cid))
     (define h1-subtree (hash-ref (tms-cell-value-branches raw3) 1))
     (check-true (tms-cell-value? h1-subtree))
     ;; Commit H3 under H1's sub-tree
     (define h1-committed (tms-commit h1-subtree 3))
     (check-equal? (tms-cell-value-base h1-committed) 'int))

   ))

(run-tests tms-cell-tests 'verbose)
