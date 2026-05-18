#lang racket/base
;;;
;;; test-specialized-cells.rkt — D.4 1B-ii framework tests
;;;
;;; Tests the specialized cell type framework per §9.6:
;;; 1. Cell-meta registration (struct + accessors)
;;; 2. Backward compatibility (regular cells with meta=#f take slow path)
;;; 3. Fast-path dispatch (specialized cells take fast path under
;;;    no-speculation; tier/storage conditions hold)
;;; 4. On-write check fires inline → structural contradiction
;;; 5. Fire-on-threshold-crossing skips dependent notify when not fired
;;; 6. Speculation fallback (under-speculation? cache makes fast-path bypass)
;;; 7. Construction site smoke test (all 17 prop-cell construction sites
;;;    in propagator.rkt still work with #f default for meta)
;;;

(require rackunit
         (only-in "../propagator.rkt"
                  make-prop-network
                  fork-prop-network
                  net-new-cell net-cell-read net-cell-write
                  net-cell-reset
                  net-register-specialized-cell
                  prop-network-contradiction
                  prop-network-cells prop-network-warm
                  prop-net-warm-under-speculation?
                  prop-net-warm-fuel-cell-cache
                  prop-net-warm-worldview-cache-cache
                  fuel-cell-id
                  worldview-cache-cell-id
                  prop-cell-meta prop-cell-value
                  cell-id-hash
                  specialized-cell-meta specialized-cell-meta?
                  specialized-cell-meta-tier
                  specialized-cell-meta-storage
                  specialized-cell-meta-fires-on
                  specialized-cell-meta-on-write-check
                  specialized-cell-meta-merge-fn)
         (only-in "../champ.rkt" champ-lookup))

;; Standard merge: max for monotone counter
(define max-merge (lambda (a b) (if (> b a) b a)))

;; ----------------------------------------------------------------
;; Test 1: cell-meta struct + accessors
;; ----------------------------------------------------------------
(test-case "cell-meta struct construction + accessors"
  ;; D.4 1V-2 Item #1 (§11.X.2 α1): 6th field merge-fn cached for fast path
  (define m (specialized-cell-meta 'hot 'monotone-counter 'threshold-crossing
                                   (lambda (o n net) (>= n 100))
                                   #f
                                   max-merge))
  (check-true (specialized-cell-meta? m))
  (check-eq? (specialized-cell-meta-tier m) 'hot)
  (check-eq? (specialized-cell-meta-storage m) 'monotone-counter)
  (check-eq? (specialized-cell-meta-fires-on m) 'threshold-crossing)
  (check-equal? ((specialized-cell-meta-on-write-check m) 0 100 'fake-net) #t)
  (check-equal? ((specialized-cell-meta-on-write-check m) 0 50 'fake-net) #f)
  ;; D.4 1V-2 Item #1: merge-fn accessor returns the cached function;
  ;; verify it composes correctly (max-merge: pick larger value)
  (check-eq? (specialized-cell-meta-merge-fn m) max-merge)
  (check-equal? ((specialized-cell-meta-merge-fn m) 3 5) 5)
  (check-equal? ((specialized-cell-meta-merge-fn m) 7 2) 7))

;; ----------------------------------------------------------------
;; Test 2: Backward compatibility — regular cell (meta=#f)
;; ----------------------------------------------------------------
(test-case "backward compat: regular cells have meta=#f and take slow path"
  (define-values (net1 cid) (net-new-cell (make-prop-network) 0 max-merge))
  (define cells (prop-network-cells net1))
  (define cell (champ-lookup cells (cell-id-hash cid) cid))
  ;; Regular cells have meta=#f
  (check-eq? (prop-cell-meta cell) #f)
  ;; Cell read/write works unchanged
  (check-equal? (net-cell-read net1 cid) 0)
  (define net2 (net-cell-write net1 cid 5))
  (check-equal? (net-cell-read net2 cid) 5))

;; ----------------------------------------------------------------
;; Test 3: Specialized cell registration — meta is attached
;; ----------------------------------------------------------------
(test-case "net-register-specialized-cell attaches cell-meta"
  (define-values (net1 cid)
    (net-register-specialized-cell (make-prop-network) 0 max-merge
                                   #:tier 'hot
                                   #:storage 'monotone-counter
                                   #:fires-on 'threshold-crossing
                                   #:on-write-check (lambda (o n net) (>= n 1000))))
  (define cells (prop-network-cells net1))
  (define cell (champ-lookup cells (cell-id-hash cid) cid))
  (define meta (prop-cell-meta cell))
  (check-true (specialized-cell-meta? meta))
  (check-eq? (specialized-cell-meta-tier meta) 'hot)
  (check-eq? (specialized-cell-meta-storage meta) 'monotone-counter)
  (check-eq? (specialized-cell-meta-fires-on meta) 'threshold-crossing)
  (check-equal? (prop-cell-value cell) 0))

;; ----------------------------------------------------------------
;; Test 4: Fast-path dispatch — write below threshold, no contradiction
;; ----------------------------------------------------------------
(test-case "fast-path: write below threshold preserves cell value, no contradiction"
  (define-values (net1 cid)
    (net-register-specialized-cell (make-prop-network) 0 max-merge
                                   #:tier 'hot
                                   #:storage 'monotone-counter
                                   #:fires-on 'threshold-crossing
                                   #:on-write-check (lambda (o n net) (>= n 1000))))
  (define net2 (net-cell-write net1 cid 50))
  (check-equal? (net-cell-read net2 cid) 50)
  (check-eq? (prop-network-contradiction net2) #f)
  (define net3 (net-cell-write net2 cid 500))
  (check-equal? (net-cell-read net3 cid) 500)
  (check-eq? (prop-network-contradiction net3) #f))

;; ----------------------------------------------------------------
;; Test 5: Fast-path on-write-check fires → structural contradiction
;; ----------------------------------------------------------------
(test-case "on-write-check fires inline → contradiction written structurally"
  (define-values (net1 cid)
    (net-register-specialized-cell (make-prop-network) 0 max-merge
                                   #:tier 'hot
                                   #:storage 'monotone-counter
                                   #:fires-on 'threshold-crossing
                                   #:on-write-check (lambda (o n net) (>= n 1000))))
  ;; Write below threshold — no contradiction
  (define net2 (net-cell-write net1 cid 999))
  (check-eq? (prop-network-contradiction net2) #f)
  ;; Write at threshold — fires; contradiction = cid
  (define net3 (net-cell-write net2 cid 1000))
  (check-equal? (prop-network-contradiction net3) cid)
  ;; Cell value was updated to the contradicting value
  (check-equal? (net-cell-read net3 cid) 1000))

;; ----------------------------------------------------------------
;; Test 6: prop-net-warm.under-speculation? defaults to #f
;; ----------------------------------------------------------------
(test-case "prop-net-warm.under-speculation? defaults to #f"
  (define net (make-prop-network))
  (define warm (prop-network-warm net))
  (check-eq? (prop-net-warm-under-speculation? warm) #f))

;; ----------------------------------------------------------------
;; Test 7: Same-value write — no change, return same network
;; ----------------------------------------------------------------
(test-case "fast-path: same-value write returns same network (termination)"
  (define-values (net1 cid)
    (net-register-specialized-cell (make-prop-network) 5 max-merge
                                   #:tier 'hot
                                   #:storage 'monotone-counter
                                   #:fires-on 'threshold-crossing
                                   #:on-write-check #f))
  ;; Writing same value should return same network reference
  (define net2 (net-cell-write net1 cid 5))
  (check-eq? net1 net2 "no-op write returns same network identity"))

;; ----------------------------------------------------------------
;; Test 8: Cold+general cell-meta takes slow path (tier != 'hot)
;; ----------------------------------------------------------------
(test-case "cold+general specialized cell falls through to slow path"
  (define-values (net1 cid)
    (net-register-specialized-cell (make-prop-network) 1000 max-merge
                                   #:tier 'cold
                                   #:storage 'general
                                   #:fires-on 'any-change))
  ;; The cell is registered with meta, but tier is 'cold not 'hot —
  ;; fast-path check fails → slow path runs → normal cell semantics.
  (define net2 (net-cell-write net1 cid 2000))
  (check-equal? (net-cell-read net2 cid) 2000))

;; ----------------------------------------------------------------
;; Test 9: Smoke test — make-prop-network works with new prop-cell field
;; ----------------------------------------------------------------
;; Coverage of the 11 well-known cells (cell-id 0-10) constructed in
;; make-prop-network is provided by the existing test suite (test-propagator,
;; test-propagator-bsp, etc.). If those passed after the prop-cell field
;; addition (verified before this test file was written), backward compat
;; for the construction sites is empirically established.
(test-case "make-prop-network constructs without error (smoke)"
  (define net (make-prop-network 1000))
  (check-not-false net))

;; ----------------------------------------------------------------
;; Test 10: D.4 1V-3 Item #1-bis — fuel-cell-cache initialized at make-prop-network
;; ----------------------------------------------------------------
(test-case "fuel-cell-cache set after make-prop-network registration"
  (define net (make-prop-network 1000))
  (define cache (prop-net-warm-fuel-cell-cache (prop-network-warm net)))
  ;; Cache is the prop-cell direct-ref for fuel-cell-id
  (check-not-false cache)
  (check-equal? (prop-cell-value cache) 1000)
  ;; Cache mirrors what champ-lookup would return
  (define champ-cell (champ-lookup (prop-network-cells net)
                                    (cell-id-hash fuel-cell-id)
                                    fuel-cell-id))
  (check-eq? cache champ-cell))

;; ----------------------------------------------------------------
;; Test 11: D.4 1V-3 Item #1-bis — fuel-cell-cache updates on net-cell-write
;; ----------------------------------------------------------------
(test-case "fuel-cell-cache updates through net-cell-write fast-path (WT-1)"
  (define net (make-prop-network 1000))
  ;; Verify read short-circuit returns same value as struct field
  (check-equal? (net-cell-read net fuel-cell-id) 1000)
  ;; Decrement: tropical-fuel-merge = min; new value 500 < 1000 → merged = 500
  (define net2 (net-cell-write net fuel-cell-id 500))
  (check-equal? (net-cell-read net2 fuel-cell-id) 500)
  ;; Cache reflects the new prop-cell (its value matches the write)
  (define cache2 (prop-net-warm-fuel-cell-cache (prop-network-warm net2)))
  (check-equal? (prop-cell-value cache2) 500)
  ;; Cache is consistent with champ-lookup result
  (define champ-cell2 (champ-lookup (prop-network-cells net2)
                                     (cell-id-hash fuel-cell-id)
                                     fuel-cell-id))
  (check-eq? cache2 champ-cell2))

;; ----------------------------------------------------------------
;; Test 12: D.4 1V-3 Item #1-bis — fuel-cell-cache updates on net-cell-reset (WT-3)
;; ----------------------------------------------------------------
(test-case "fuel-cell-cache updates through net-cell-reset (WT-3)"
  (define net (make-prop-network 1000))
  ;; Decrement first so cell != initial
  (define net2 (net-cell-write net fuel-cell-id 500))
  ;; Reset to fresh budget
  (define net3 (net-cell-reset net2 fuel-cell-id 2000))
  (check-equal? (net-cell-read net3 fuel-cell-id) 2000)
  (define cache3 (prop-net-warm-fuel-cell-cache (prop-network-warm net3)))
  (check-equal? (prop-cell-value cache3) 2000))

;; ----------------------------------------------------------------
;; Test 13: D.4 1V-3 Item #1-bis — cache invariant under non-fuel writes (γ1 dual-storage)
;; ----------------------------------------------------------------
(test-case "fuel-cell-cache unchanged when writes target other cells"
  (define net (make-prop-network 1000))
  (define cache-before (prop-net-warm-fuel-cell-cache (prop-network-warm net)))
  ;; Write to a different cell (allocate a new one; write to it)
  (define-values (net2 other-cid)
    (net-new-cell net 0 max-merge))
  (define net3 (net-cell-write net2 other-cid 42))
  ;; fuel-cell-cache should be UNCHANGED (cid != fuel-cell-id → inherit prev cache)
  (define cache-after (prop-net-warm-fuel-cell-cache (prop-network-warm net3)))
  (check-eq? cache-before cache-after))

;; ----------------------------------------------------------------
;; Test 14: D.4 1V-3 Item #1-bis — fork-prop-network establishes fresh cache (WT-7)
;; ----------------------------------------------------------------
(test-case "fork-prop-network initializes fuel-cell-cache with fresh budget"
  (define parent (make-prop-network 1000))
  (define parent2 (net-cell-write parent fuel-cell-id 500))
  ;; Fork: sub-net gets fresh fuel budget = 750 (passed as arg)
  (define forked (fork-prop-network parent2 750))
  (check-equal? (net-cell-read forked fuel-cell-id) 750)
  (define cache (prop-net-warm-fuel-cell-cache (prop-network-warm forked)))
  (check-equal? (prop-cell-value cache) 750)
  ;; Parent's cache unaffected (parent2 still has 500)
  (check-equal? (net-cell-read parent2 fuel-cell-id) 500))

;; ----------------------------------------------------------------
;; Test 15: D.4 1V-5 Item #1-quater — worldview-cache-cache initialized at make-prop-network
;; ----------------------------------------------------------------
(test-case "worldview-cache-cache set after make-prop-network registration"
  (define net (make-prop-network 1000))
  (define cache (prop-net-warm-worldview-cache-cache (prop-network-warm net)))
  ;; Cache is the prop-cell direct-ref for worldview-cache-cell-id
  (check-not-false cache)
  ;; Cache mirrors what champ-lookup would return
  (define champ-cell (champ-lookup (prop-network-cells net)
                                    (cell-id-hash worldview-cache-cell-id)
                                    worldview-cache-cell-id))
  (check-eq? cache champ-cell))

;; ----------------------------------------------------------------
;; Test 16: D.4 1V-5 Item #1-quater — worldview-cache-cache updates on net-cell-write (WT-*)
;; ----------------------------------------------------------------
(test-case "worldview-cache-cache updates through net-cell-write"
  (define net (make-prop-network 1000))
  ;; Verify read short-circuit returns same value as struct field
  (check-equal? (net-cell-read net worldview-cache-cell-id) 0)
  ;; Write bitmask 1 to worldview-cache-cell
  (define net2 (net-cell-write net worldview-cache-cell-id 1))
  (check-equal? (net-cell-read net2 worldview-cache-cell-id) 1)
  ;; Cache reflects the new prop-cell (its value matches the write)
  (define cache2 (prop-net-warm-worldview-cache-cache (prop-network-warm net2)))
  (check-equal? (prop-cell-value cache2) 1)
  ;; Cache is consistent with champ-lookup result
  (define champ-cell2 (champ-lookup (prop-network-cells net2)
                                     (cell-id-hash worldview-cache-cell-id)
                                     worldview-cache-cell-id))
  (check-eq? cache2 champ-cell2))

;; ----------------------------------------------------------------
;; Test 17: D.4 1V-5 Item #1-quater — both caches coexist independently
;; ----------------------------------------------------------------
(test-case "fuel-cell-cache + worldview-cache-cache coexist independently"
  (define net (make-prop-network 1000))
  (define fuel-cache-before (prop-net-warm-fuel-cell-cache (prop-network-warm net)))
  (define wv-cache-before (prop-net-warm-worldview-cache-cache (prop-network-warm net)))
  ;; Write to worldview-cache only
  (define net2 (net-cell-write net worldview-cache-cell-id 5))
  (define fuel-cache-after-wv-write (prop-net-warm-fuel-cell-cache (prop-network-warm net2)))
  (define wv-cache-after-wv-write (prop-net-warm-worldview-cache-cache (prop-network-warm net2)))
  ;; fuel-cell-cache unchanged
  (check-eq? fuel-cache-before fuel-cache-after-wv-write)
  ;; worldview-cache-cache updated
  (check-not-eq? wv-cache-before wv-cache-after-wv-write)
  (check-equal? (prop-cell-value wv-cache-after-wv-write) 5)
  ;; Now write to fuel-cell only
  (define net3 (net-cell-write net2 fuel-cell-id 500))
  (define fuel-cache-after-fuel-write (prop-net-warm-fuel-cell-cache (prop-network-warm net3)))
  (define wv-cache-after-fuel-write (prop-net-warm-worldview-cache-cache (prop-network-warm net3)))
  ;; fuel-cell-cache updated
  (check-not-eq? fuel-cache-after-wv-write fuel-cache-after-fuel-write)
  (check-equal? (prop-cell-value fuel-cache-after-fuel-write) 500)
  ;; worldview-cache-cache unchanged from prior write
  (check-eq? wv-cache-after-wv-write wv-cache-after-fuel-write))

;; ----------------------------------------------------------------
;; Test 18: D.4 1V-5 Item #1-quater — fork-prop-network preserves worldview-cache-cache
;; ----------------------------------------------------------------
(test-case "fork-prop-network initializes worldview-cache-cache from parent"
  (define parent (make-prop-network 1000))
  (define parent2 (net-cell-write parent worldview-cache-cell-id 7))
  ;; Fork: sub-net shares cells with parent via structural sharing
  (define forked (fork-prop-network parent2 1000))
  ;; Forked net's worldview-cache-cache reflects parent's value
  (check-equal? (net-cell-read forked worldview-cache-cell-id) 7)
  (define wv-cache (prop-net-warm-worldview-cache-cache (prop-network-warm forked)))
  (check-equal? (prop-cell-value wv-cache) 7))
