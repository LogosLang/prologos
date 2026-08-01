#lang racket/base

;;;
;;; .pnet CONTAINER SENTINELS — every runtime container wrapper round-trips.
;;;
;;; Rel T1 POL.10 made `def` bind WHNF-REDUCED values, so runtime container
;;; VALUES reach module env-snapshots and therefore the .pnet cache. Each such
;;; value is an `expr-*` struct wrapping a RAW persistent/transient structure,
;;; and each needs a reconstructive sentinel for two independent reasons:
;;;
;;;   (1) HASH PERSISTENCE. champ-backed containers store `equal-hash-code`
;;;       values in their nodes, and `champ-lookup` navigates BY the stored
;;;       hash. `equal-hash-code` is process-stable ONLY, so a cache written by
;;;       one process and read by another has stale hashes baked in and lookups
;;;       SILENTLY MISS. The sentinel serializes ENTRIES and recomputes hashes
;;;       at read.
;;;
;;;   (2) RECONSTRUCTION. Without a sentinel (and absent a reg0!/reg1!/regN!
;;;       entry) the reader's unknown-tag fallback returns a RAW VECTOR that
;;;       PRINTS like the struct — the pipeline.md failure verbatim, detonating
;;;       at the first struct match to touch it, arbitrarily far away.
;;;
;;; History: `expr-champ` got its sentinel at POL.10 (v2→v3); `expr-rrb` at the
;;; SolveCarrier flip (v8→v9), which is when the class was recognized; an audit
;;; of every wrapper then found the remaining FOUR unprotected (v9→v10).
;;;
;;; THIS FILE IS THE ANTI-DRIFT GATE: it enumerates the wrappers and asserts the
;;; property for each, so a NEW container struct that forgets its sentinel fails
;;; here rather than in a cached module months later.
;;;

(require rackunit
         racket/list
         (only-in "../pnet-serialize.rkt"
                  deep-struct->serializable deep-serializable->struct)
         (only-in "../syntax.rkt"
                  expr-champ expr-champ? expr-champ-racket-champ
                  expr-hset expr-hset? expr-hset-racket-champ
                  expr-rrb expr-rrb? expr-rrb-racket-rrb
                  expr-trrb expr-trrb? expr-trrb-racket-trrb
                  expr-tchamp expr-tchamp? expr-tchamp-racket-tchamp
                  expr-thset expr-thset? expr-thset-racket-tchamp
                  expr-string expr-int expr-true)
         (only-in "../champ.rkt"
                  champ-empty champ-insert champ-entries champ-size champ-lookup
                  champ-transient tchamp-freeze)
         (only-in "../rrb.rkt"
                  rrb-from-list rrb-to-list rrb-transient trrb-freeze))

;; Two elements whose `equal-hash-code`s are large, so a persisted hash is
;; actually VISIBLE to the digit scan below. (A short-hashed element would let
;; the leak through undetected — that is why this fixture is strings, not the
;; small keywords a casual probe reaches for.)
(define e1 (expr-string "alpha"))
(define e2 (expr-string "beta"))

(define base-champ
  (champ-insert (champ-insert champ-empty (equal-hash-code e1) e1 (expr-int 1))
                (equal-hash-code e2) e2 (expr-int 2)))

(define set-champ
  (champ-insert (champ-insert champ-empty (equal-hash-code e1) e1 (expr-true))
                (equal-hash-code e2) e2 (expr-true)))

(define base-rrb (rrb-from-list (list e1 e2)))

;; ── the shared property ──────────────────────────────────────────────────────

(define (check-sentinel name val expected-head pred)
  (define ser (deep-struct->serializable val))
  (check-true (and (list? ser) (pair? ser) (eq? (car ser) expected-head))
              (format "~a must serialize RECONSTRUCTIVELY as ~a, got: ~v"
                      name expected-head (if (pair? ser) (car ser) ser)))
  ;; No `equal-hash-code` may reach the wire. The fixture's elements hash to
  ;; long integers, so any leak shows up as a long digit run.
  (check-false (regexp-match? #rx"[0-9]{12,}" (format "~s" ser))
               (format "~a must not persist an equal-hash-code: ~v" name ser))
  (define back (deep-serializable->struct ser))
  (check-true (pred back)
              (format "~a must reconstruct as its own struct, not a raw vector impostor; got: ~v"
                      name back))
  back)

;; ── persistent containers ────────────────────────────────────────────────────

(test-case "sentinel/expr-champ (Map) — the original, POL.10"
  (define back (check-sentinel "expr-champ" (expr-champ base-champ) 'champ-sentinel expr-champ?))
  (check-equal? (champ-size (expr-champ-racket-champ back)) 2)
  ;; the load-bearing one: lookup by a FRESHLY computed hash must find the entry
  (check-equal? (champ-lookup (expr-champ-racket-champ back) (equal-hash-code e1) e1)
                (expr-int 1)
                "lookup by a fresh hash must succeed — this is what a persisted hash breaks"))

(test-case "sentinel/expr-hset (Set) — wraps a champ but is NOT expr-champ"
  ;; The `expr-champ?` arm does not see through the wrapper, so before v10 an
  ;; hset fell to the generic struct walk and hit BOTH defects at once.
  (define back (check-sentinel "expr-hset" (expr-hset set-champ) 'hset-sentinel expr-hset?))
  (check-equal? (champ-size (expr-hset-racket-champ back)) 2)
  (check-equal? (champ-lookup (expr-hset-racket-champ back) (equal-hash-code e2) e2)
                (expr-true)
                "membership by a fresh hash must succeed"))

(test-case "sentinel/expr-rrb (PVec) — the SolveCarrier flip's carrier"
  ;; rrb-root's `tail` is a RAW RACKET VECTOR and deep-s->v has no `vector?` arm,
  ;; so its contents leaked through `[else v]` VERBATIM before v9.
  (define back (check-sentinel "expr-rrb" (expr-rrb base-rrb) 'rrb-sentinel expr-rrb?))
  (check-equal? (rrb-to-list (expr-rrb-racket-rrb back)) (list e1 e2)
                "order and contents preserved"))

;; ── transient builders ──────────────────────────────────────────────────────
;; Reachable: `def ts := (transient s)` binds a TSet, and POL.10 puts the reduced
;; value in the env-snapshot (probe: `ts : [TSet Int] defined.`).

(test-case "sentinel/expr-thset (TSet)"
  (define back (check-sentinel "expr-thset" (expr-thset (champ-transient set-champ))
                               'thset-sentinel expr-thset?))
  (check-equal? (champ-size (tchamp-freeze (expr-thset-racket-tchamp back))) 2))

(test-case "sentinel/expr-tchamp (TMap)"
  (define back (check-sentinel "expr-tchamp" (expr-tchamp (champ-transient base-champ))
                               'tchamp-sentinel expr-tchamp?))
  (check-equal? (champ-size (tchamp-freeze (expr-tchamp-racket-tchamp back))) 2))

(test-case "sentinel/expr-trrb (TVec)"
  (define back (check-sentinel "expr-trrb" (expr-trrb (rrb-transient base-rrb))
                               'trrb-sentinel expr-trrb?))
  (check-equal? (rrb-to-list (trrb-freeze (expr-trrb-racket-trrb back))) (list e1 e2)))

;; ── the properties that make the transient arms SAFE ────────────────────────

(test-case "sentinel/serializing a transient does NOT consume it"
  ;; The arms serialize through `trrb-freeze` / `tchamp-freeze`. Both build a
  ;; fresh persistent structure and leave the transient untouched — if either
  ;; were destructive, merely WRITING a cache would corrupt the live value.
  (define t (expr-tchamp (champ-transient base-champ)))
  (void (deep-struct->serializable t))
  (check-equal? (champ-size (tchamp-freeze (expr-tchamp-racket-tchamp t))) 2
                "the transient survives its own serialization intact")
  (define t2 (expr-trrb (rrb-transient base-rrb)))
  (void (deep-struct->serializable t2))
  (check-equal? (length (rrb-to-list (trrb-freeze (expr-trrb-racket-trrb t2)))) 2))

(test-case "sentinel/each read yields a DISTINCT transient builder"
  ;; A mutable builder must never be shared across module loads. Re-reading the
  ;; same serialized form twice must produce two independent values.
  (define ser (deep-struct->serializable (expr-tchamp (champ-transient base-champ))))
  (define a (deep-serializable->struct ser))
  (define b (deep-serializable->struct ser))
  (check-false (eq? (expr-tchamp-racket-tchamp a) (expr-tchamp-racket-tchamp b))
               "two reads must not alias one builder"))

;; ── the empty case, for every wrapper ───────────────────────────────────────

(test-case "sentinel/empty containers round-trip"
  (define (rt v) (deep-serializable->struct (deep-struct->serializable v)))
  (check-equal? (champ-size (expr-champ-racket-champ (rt (expr-champ champ-empty)))) 0)
  (check-equal? (champ-size (expr-hset-racket-champ (rt (expr-hset champ-empty)))) 0)
  (check-equal? (rrb-to-list (expr-rrb-racket-rrb (rt (expr-rrb (rrb-from-list '()))))) '())
  (check-true (expr-thset? (rt (expr-thset (champ-transient champ-empty)))))
  (check-true (expr-tchamp? (rt (expr-tchamp (champ-transient champ-empty)))))
  (check-true (expr-trrb? (rt (expr-trrb (rrb-transient (rrb-from-list '())))))))
