#lang racket/base

;;;
;;; test-hasse-registry.rkt — PPN Track 4C Phase 2b tests
;;;
;;; Tests the Hasse-registry primitive with a mock lattice to isolate
;;; primitive behavior from real 4C lattices. Uses integer-interval
;;; containment as the test lattice:
;;;
;;;   Position = (cons lo hi) representing interval [lo, hi]
;;;   Subsume? = "interval p contains interval q"
;;;   Entry   = any value (arbitrary payload)
;;;
;;; This lattice is rich enough to exercise Hasse semantics:
;;;   - Multiple positions can subsume the same query (chain)
;;;   - Antichain extraction: most-specific (smallest containing interval)
;;;   - Incomparable positions (siblings): neither subsumes the other
;;;

(require rackunit
         "../propagator.rkt"
         "../sre-core.rkt"
         "../hasse-registry.rkt")

;; ============================================================
;; Mock lattice: integer intervals
;; ============================================================

;; Position: (cons lo hi)
;; p subsumes q iff p.lo <= q.lo AND q.hi <= p.hi (p contains q)
(define (interval-subsume? p q)
  (and (<= (car p) (car q))
       (<= (cdr q) (cdr p))))

;; position-fn: entry is a (cons 'tag (cons lo hi)) pair; position is (cons lo hi)
(define (entry->position entry) (cdr entry))

(define (fresh-net) (make-prop-network))

;; ============================================================
;; Handle construction
;; ============================================================

(test-case "net-new-hasse-registry returns handle"
  (define-values (net handle)
    (net-new-hasse-registry (fresh-net)
                            #:l-domain 'test-interval
                            #:position-fn entry->position
                            #:subsume-fn interval-subsume?))
  (check-true (hasse-registry-handle? handle))
  (check-equal? (hasse-registry-handle-l-domain-name handle) 'test-interval))

(test-case "factory rejects non-symbol l-domain"
  (check-exn exn:fail?
             (lambda ()
               (net-new-hasse-registry (fresh-net)
                                       #:l-domain "not-a-symbol"
                                       #:position-fn entry->position
                                       #:subsume-fn interval-subsume?))))

(test-case "factory rejects non-procedure position-fn"
  (check-exn exn:fail?
             (lambda ()
               (net-new-hasse-registry (fresh-net)
                                       #:l-domain 'test-interval
                                       #:position-fn 'not-a-fn
                                       #:subsume-fn interval-subsume?))))

;; ============================================================
;; Registration
;; ============================================================

(test-case "register single entry, size = 1"
  (define-values (net handle)
    (net-new-hasse-registry (fresh-net)
                            #:l-domain 'test-interval
                            #:position-fn entry->position
                            #:subsume-fn interval-subsume?))
  (define net2 (hasse-registry-register net handle '(e1 . (1 . 10))))
  (check-equal? (hasse-registry-size net2 handle) 1)
  (check-equal? (hasse-registry-all-positions net2 handle) '((1 . 10))))

(test-case "register multiple entries at same position"
  (define-values (net handle)
    (net-new-hasse-registry (fresh-net)
                            #:l-domain 'test-interval
                            #:position-fn entry->position
                            #:subsume-fn interval-subsume?))
  (define net2 (hasse-registry-register net handle '(e1 . (1 . 10))))
  (define net3 (hasse-registry-register net2 handle '(e2 . (1 . 10))))
  (check-equal? (hasse-registry-size net3 handle) 2)
  (check-equal? (length (hasse-registry-entries-at-position net3 handle '(1 . 10))) 2))

(test-case "register entries at different positions"
  (define-values (net handle)
    (net-new-hasse-registry (fresh-net)
                            #:l-domain 'test-interval
                            #:position-fn entry->position
                            #:subsume-fn interval-subsume?))
  (define net2
    (for/fold ([n net])
              ([e (in-list '((e1 . (1 . 10))
                             (e2 . (2 . 5))
                             (e3 . (6 . 9))))])
      (hasse-registry-register n handle e)))
  (check-equal? (hasse-registry-size net2 handle) 3)
  (check-equal? (length (hasse-registry-all-positions net2 handle)) 3))

;; ============================================================
;; Lookup — the Hasse semantics
;; ============================================================

(test-case "lookup returns empty on no entries"
  (define-values (net handle)
    (net-new-hasse-registry (fresh-net)
                            #:l-domain 'test-interval
                            #:position-fn entry->position
                            #:subsume-fn interval-subsume?))
  (check-equal? (hasse-registry-lookup net handle '(3 . 7)) '()))

(test-case "lookup returns entry when its position subsumes query"
  (define-values (net handle)
    (net-new-hasse-registry (fresh-net)
                            #:l-domain 'test-interval
                            #:position-fn entry->position
                            #:subsume-fn interval-subsume?))
  (define net2 (hasse-registry-register net handle '(broad . (1 . 100))))
  ;; Query (3, 7) is contained in [1, 100] → the entry subsumes it
  (define results (hasse-registry-lookup net2 handle '(3 . 7)))
  (check-equal? (length results) 1)
  (check-equal? (car results) '(broad . (1 . 100))))

(test-case "lookup filters out non-subsumers"
  (define-values (net handle)
    (net-new-hasse-registry (fresh-net)
                            #:l-domain 'test-interval
                            #:position-fn entry->position
                            #:subsume-fn interval-subsume?))
  (define net2
    (for/fold ([n net])
              ([e (in-list '((subsumer . (1 . 100))
                             (disjoint . (200 . 300))
                             (overlap . (50 . 150))))])
      (hasse-registry-register n handle e)))
  ;; Query (3, 7) — only (1, 100) fully contains it
  ;; (50, 150) does not contain (3, 7), (200, 300) disjoint
  (define results (hasse-registry-lookup net2 handle '(3 . 7)))
  (check-equal? (length results) 1)
  (check-equal? (cdar results) '(1 . 100)))

(test-case "lookup returns antichain — most-specific subsumers only"
  ;; Register a chain: (1,100), (2,50), (3,10)  — each contained in the previous
  ;; Plus an incomparable: (80, 90)
  ;; Query: (4, 8)
  ;;   - (1,100) subsumes (4,8) but (2,50) is MORE specific and also subsumes
  ;;   - (2,50) subsumes (4,8) but (3,10) is MORE specific and also subsumes
  ;;   - (3,10) subsumes (4,8) and has no more-specific subsumer in the registry
  ;;   - (80,90) does NOT subsume (4,8) (disjoint at this query)
  ;; Expected antichain: only (3,10)
  (define-values (net handle)
    (net-new-hasse-registry (fresh-net)
                            #:l-domain 'test-interval
                            #:position-fn entry->position
                            #:subsume-fn interval-subsume?))
  (define net2
    (for/fold ([n net])
              ([e (in-list '((broadest . (1 . 100))
                             (medium   . (2 . 50))
                             (narrowest . (3 . 10))
                             (sibling  . (80 . 90))))])
      (hasse-registry-register n handle e)))
  (define results (hasse-registry-lookup net2 handle '(4 . 8)))
  (check-equal? (length results) 1)
  (check-equal? (car results) '(narrowest . (3 . 10))))

(test-case "lookup with incomparable subsumers returns both (antichain)"
  ;; Register two incomparable positions that both subsume the query
  ;; (1, 50) and (1, 100) — wait those aren't incomparable, (1,50) ⊆ (1,100)
  ;; Need proper incomparable: e.g., (1, 20) and (10, 30)
  ;;   - Both contain query (12, 15)
  ;;   - Neither subsumes the other (neither contains the other)
  ;; Expected: antichain is BOTH
  (define-values (net handle)
    (net-new-hasse-registry (fresh-net)
                            #:l-domain 'test-interval
                            #:position-fn entry->position
                            #:subsume-fn interval-subsume?))
  (define net2
    (for/fold ([n net])
              ([e (in-list '((left  . (1 . 20))
                             (right . (10 . 30))))])
      (hasse-registry-register n handle e)))
  (define results (hasse-registry-lookup net2 handle '(12 . 15)))
  (check-equal? (length results) 2))

(test-case "lookup with chain + incomparable branches — returns antichain per branch"
  ;; Tree structure:
  ;;   Root: (1, 100)
  ;;   Left branch: (2, 20)   — within root
  ;;   Right branch: (50, 90) — within root, disjoint from left
  ;;   Under right: (60, 80)  — within right
  ;; Query: (65, 70)
  ;;   - (1, 100) subsumes, but (50, 90) more specific
  ;;   - (50, 90) subsumes, but (60, 80) more specific
  ;;   - (60, 80) subsumes, nothing more specific
  ;;   - (2, 20) does not subsume
  ;; Expected antichain: (60, 80) only
  (define-values (net handle)
    (net-new-hasse-registry (fresh-net)
                            #:l-domain 'test-interval
                            #:position-fn entry->position
                            #:subsume-fn interval-subsume?))
  (define net2
    (for/fold ([n net])
              ([e (in-list '((root . (1 . 100))
                             (left . (2 . 20))
                             (right-outer . (50 . 90))
                             (right-inner . (60 . 80))))])
      (hasse-registry-register n handle e)))
  (define results (hasse-registry-lookup net2 handle '(65 . 70)))
  (check-equal? (length results) 1)
  (check-equal? (car results) '(right-inner . (60 . 80))))

;; ============================================================
;; SRE domain integration
;; ============================================================

(test-case "'hasse-registry SRE domain registered"
  ;; Module load side effect — domain should be registered
  (define d (lookup-domain 'hasse-registry))
  (check-not-false d)
  (check-equal? (sre-domain-name d) 'hasse-registry))

;; ============================================================
;; Subsume-fn override demonstration (the Q_n bitmask pattern)
;; ============================================================

(test-case "override subsume-fn — bitmask subcube membership (Q_n pattern)"
  ;; Demonstrates the hypercube-research pattern from BSP-LE Track 2 addendum:
  ;; Q_n worldview space; positions are bitmasks; subsume = (p & q) == q
  ;;   position p subsumes query q iff q's bits are a SUBSET of p's bits
  (define (bitmask-subsume? p q)
    (= (bitwise-and p q) q))
  (define (id-position-fn entry) entry)  ;; entry IS the bitmask
  (define-values (net handle)
    (net-new-hasse-registry (fresh-net)
                            #:l-domain 'test-worldview
                            #:position-fn id-position-fn
                            #:subsume-fn bitmask-subsume?))
  (define net2
    (for/fold ([n net])
              ([bm (in-list '(#b111    ; 7 — all three bits
                              #b110    ; 6 — first two bits
                              #b011    ; 3 — last two bits
                              #b001))]) ; 1 — just bit 0
      (hasse-registry-register n handle bm)))
  ;; Query = #b010 (bit 1 only)
  ;; - #b111 subsumes (all bits) but #b110 more specific (also subsumes b010? b010 has bit 1; b110 has bits 1,2 — yes b110 ⊇ b010)
  ;; - #b110 subsumes; nothing more specific also subsumes
  ;; - #b011 subsumes (b011 has bits 0,1 ⊇ bit 1)
  ;; - #b001 does NOT subsume b010 (b001 has bit 0, b010 has bit 1; different bits)
  ;; Expected antichain: {#b110, #b011} (both incomparable, both contain b010)
  (define results (hasse-registry-lookup net2 handle #b010))
  (check-equal? (length results) 2))
