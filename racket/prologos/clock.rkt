#lang racket/base

;;;
;;; clock.rkt — PPN 4C Phase 1e-β-iii: on-network Lamport clock primitive
;;;
;;; Provides a timestamped-cell primitive with E1 Lamport semantics:
;;; timestamps are (counter, process-id) pairs, totally ordered by
;;; lexicographic compare. Under today's single-BSP scheduler, all
;;; writes use process-id = 0; the pid tag future-proofs the shape for
;;; parallel workers without cell-by-cell migration when that lands.
;;;
;;; Prior art reuse: counter-merge from decision-cell.rkt (max join-
;;; semilattice) is the clock cell's merge function. The clock cell
;;; itself is allocated on the main persistent-registry network at
;;; initialization time; its cell-id is held in `current-clock-cell-id`
;;; (scaffolding parameter, like `current-attribute-map-cell-id`).
;;;
;;; Consumers use `net-new-timestamped-cell` / `net-write-timestamped` /
;;; `net-read-timestamped-payload` — the primitive handles the read-
;;; then-increment-then-write of the clock cell internally.
;;;
;;; Concurrency discipline (inherited from ATMS counter at
;;; decision-cell.rkt:609-610): clock writes happen at the topology
;;; stratum (or in clearly-sequential elaboration context). Same-BSP-
;;; round concurrent writes to the same timestamped cell would race on
;;; the counter-read-then-increment; topology-stratum discipline makes
;;; this structurally impossible. Documented as a load-bearing
;;; invariant for timestamped-cell users.
;;;
;;; Phase 11b upgrade path (per §6.14.6 / §6.1.1): identity-or-error
;;; behavior on equal-timestamp different-payload writes currently
;;; returns the 'timestamp-contradiction sentinel (path A). Phase 11b
;;; upgrades to path (C) provenance-rich contradict-record with
;;; conflicting values + srclocs + producer propagator IDs.
;;;

(require (only-in "decision-cell.rkt" counter-merge)
         "propagator.rkt"
         (only-in "sre-core.rkt" make-sre-domain register-domain!)
         (only-in "merge-fn-registry.rkt" register-merge-fn!/lattice))

(provide
 ;; Parameters
 current-process-id
 current-clock-cell-id
 ;; Structs
 (struct-out timestamp)
 (struct-out timestamped-value)
 ;; Timestamp ops
 timestamp<?
 timestamp=?
 fresh-timestamp
 ;; Contradiction sentinel
 timestamp-contradiction?
 ;; Merge
 merge-by-timestamp-max
 ;; Cell API
 net-allocate-clock-cell
 net-new-timestamped-cell
 net-write-timestamped
 net-read-timestamped
 net-read-timestamped-payload)

;; ========================================
;; Scaffolding parameters (PM Track 12)
;; ========================================

;; current-process-id: under single-BSP (today), always 0. Parameterized
;; per-worker in future parallel-execution contexts. See DEFERRED.md
;; § "PM Track 12 design input from PPN 4C Phase 1e-α" — the pid tag
;; is the shape-preserving dimension that makes today's scalar Lamport
;; extensible to multi-process without cell-by-cell migration.
(define current-process-id (make-parameter 0))

;; current-clock-cell-id: scaffolding parameter holding the cell-id of
;; the global clock cell. Set at network initialization via
;; `net-allocate-clock-cell`. PM Track 12 evaluates whether this remains
;; a parameter (dynamic-scope shape) or migrates to a well-known cell-id.
(define current-clock-cell-id (make-parameter #f))

;; ========================================
;; Timestamp structure + ops
;; ========================================

;; Timestamp = (counter, pid) pair
;; Total order via lexicographic compare on (counter, pid).
(struct timestamp (counter pid) #:transparent)

;; Strict-less compare: t1 < t2 iff (counter1 < counter2)
;; or (counter1 = counter2 AND pid1 < pid2).
(define (timestamp<? t1 t2)
  (or (< (timestamp-counter t1) (timestamp-counter t2))
      (and (= (timestamp-counter t1) (timestamp-counter t2))
           (< (timestamp-pid t1) (timestamp-pid t2)))))

(define (timestamp=? t1 t2)
  (and (= (timestamp-counter t1) (timestamp-counter t2))
       (= (timestamp-pid t1) (timestamp-pid t2))))

;; Read clock cell, increment, return new timestamp tagged with
;; (current-process-id). Also returns the new network (clock-written).
;; Topology-stratum discipline assumed — see module docstring.
(define (fresh-timestamp net clock-cid)
  (define n (net-cell-read net clock-cid))
  (define new-n (+ n 1))
  (define net* (net-cell-write net clock-cid new-n))
  (values net* (timestamp new-n (current-process-id))))

;; ========================================
;; Timestamped-value structure + merge
;; ========================================

;; Cell value shape for timestamped cells: payload tagged with its
;; write timestamp. Merge compares timestamps; newer wins.
(struct timestamped-value (ts payload) #:transparent)

;; Sentinel for concurrent-write contradiction (equal timestamps with
;; different payloads). SRE domain's `#:contradicts?` recognizes.
(define (timestamp-contradiction? v)
  (eq? v 'timestamp-contradiction))

;; Max-by-timestamp merge:
;;   bot handling: 'infra-bot defers
;;   top absorbs: existing contradiction persists
;;   newer wins by timestamp<?
;;   equal timestamps: identity check — equal payloads keep old;
;;     different payloads return 'timestamp-contradiction sentinel.
(define (merge-by-timestamp-max old new)
  (cond
    [(eq? old 'infra-bot) new]
    [(eq? new 'infra-bot) old]
    [(timestamp-contradiction? old) old]
    [(timestamp-contradiction? new) new]
    [(timestamp<? (timestamped-value-ts old) (timestamped-value-ts new)) new]
    [(timestamp<? (timestamped-value-ts new) (timestamped-value-ts old)) old]
    ;; Equal timestamps: identity-or-error on payload
    [(equal? (timestamped-value-payload old) (timestamped-value-payload new)) old]
    [else 'timestamp-contradiction]))

;; ========================================
;; Cell API
;; ========================================

;; Allocate the global clock cell on `net`. Returns (values new-net
;; clock-cid). Call ONCE at network initialization; sets
;; `current-clock-cell-id` so consumers can reference it.
(define (net-allocate-clock-cell net)
  (define-values (net* cid) (net-new-cell net 0 counter-merge))
  (current-clock-cell-id cid)
  (values net* cid))

;; Allocate a new timestamped cell on `net`. Initial payload gets a
;; fresh timestamp. `clock-cid` is the counter cell (normally
;; `(current-clock-cell-id)`). Returns (values new-net cell-id).
(define (net-new-timestamped-cell net clock-cid init-payload)
  (define-values (net1 ts) (fresh-timestamp net clock-cid))
  (define initial-wrapped (timestamped-value ts init-payload))
  (net-new-cell net1 initial-wrapped merge-by-timestamp-max))

;; Write a new timestamped value to an existing timestamped cell.
;; Reads clock, increments, tags payload with fresh timestamp.
;; Returns new network.
(define (net-write-timestamped net clock-cid cid payload)
  (define-values (net1 ts) (fresh-timestamp net clock-cid))
  (net-cell-write net1 cid (timestamped-value ts payload)))

;; Read the full timestamped-value from a cell. Returns the struct
;; (or 'timestamp-contradiction if the cell is in contradiction state).
(define (net-read-timestamped net cid)
  (net-cell-read net cid))

;; Read just the payload from a timestamped cell. Errors if the cell
;; is in contradiction state (caller should check via
;; `timestamp-contradiction?` first if that's a possibility).
(define (net-read-timestamped-payload net cid)
  (define v (net-cell-read net cid))
  (cond
    [(timestamp-contradiction? v)
     (error 'net-read-timestamped-payload
            "cell in contradiction state; check timestamp-contradiction? first")]
    [(timestamped-value? v) (timestamped-value-payload v)]
    [else (error 'net-read-timestamped-payload
                 "cell value is not timestamped: ~e" v)]))

;; ========================================
;; SRE domain registration
;; ========================================

(define timestamped-cell-sre-domain
  (make-sre-domain
   #:name 'timestamped-cell
   #:merge-registry (lambda (r)
                      (case r
                        [(equality) merge-by-timestamp-max]
                        [else (error 'timestamped-cell-merge
                                     "no merge for relation: ~a" r)]))
   #:contradicts? timestamp-contradiction?
   #:bot? (lambda (v) (eq? v 'infra-bot))
   #:bot-value 'infra-bot
   #:classification 'value))  ;; PPN 4C Phase 1f: wraps a single payload value
(register-domain! timestamped-cell-sre-domain)
(register-merge-fn!/lattice merge-by-timestamp-max #:for-domain 'timestamped-cell)
