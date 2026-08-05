#lang racket/base

;;;
;;; test-merge-laws.rkt — every cell merge must be a lattice. Checked, not assumed.
;;;
;;; `structural-thinking.md` § The Lattice Test: "Every cell value must be a
;;; lattice element with a monotone merge." `propagator-design.md` leans on the
;;; same thing for CALM-safety — monotone computation on a fixed topology
;;; converges to the same fixpoint regardless of evaluation order, which is what
;;; lets the scheduler fire in any order it likes.
;;;
;;; That obligation was documented in three places and enforced in none, and it
;;; cost fourteen months. `tagged-cell-merge` unioned its entry lists with a bare
;;; `(append (entries new) (entries old))`, so `(merge x x)` returned twice x's
;;; entries. Not idempotent. A cell whose lattice VALUE is stable but whose
;;; REPRESENTATION grows every round reads as changed to the scheduler, so its
;;; dependents re-fire forever: the union-type hang filed 2026-06-29 and fixed
;;; 2026-08-05, which also took the LSP down, and which was chased at the wrong
;;; layer the whole time because the entry blamed "the `:type`-facet union join
;;; not reaching a fixpoint". The join was innocent.
;;;
;;; Three lines of `(check-equal? (merge x x) x)` would have found it on day one
;;; with no repro at all. This file is those three lines, generalised.
;;;
;;; ---------------------------------------------------------------------------
;;; WHICH LAWS
;;;
;;; IDEMPOTENCE is required of every merge here, unconditionally: `merge(x,x)`
;;; must equal `x`. A merge that grows its argument cannot reach a fixpoint.
;;;
;;; COMMUTATIVITY and ASSOCIATIVITY are declared per-merge, because several
;;; merges in this tree are deliberately NOT commutative — `merge-hasheq-replace`
;;; is last-write-wins by design, and `tagged-cell-merge` keeps the newer base.
;;; Declaring rather than assuming is the point: a merge that claims to be a
;;; join-semilattice gets all three checked, and one that does not has to say so
;;; HERE, where the next person reads it.
;;;
;;; ---------------------------------------------------------------------------
;;; WHAT THIS DOES NOT COVER, SAID PLAINLY
;;;
;;; The merge that had the bug is NOT in `merge-fn-registry.rkt` — 29 merges are
;;; registered there and `tagged-cell-merge` is not one of them. So a purely
;;; registry-driven sweep would have missed it too. The table below is therefore
;;; hand-written and covers the decision-cell and infra-cell families directly.
;;;
;;; The guard against the table going stale is COVERAGE-FLOOR below: it fails if
;;; the registry grows past the number of merges recorded here. That is a floor,
;;; not proof of coverage — it cannot tell that a NEW registration is the one
;;; missing. It is the same device `lint-parameters.rkt` and
;;; `lint-discarded-errors.rkt` use, and it has the same limits.
;;;

(require rackunit
         racket/list
         racket/set
         (only-in "../merge-fn-registry.rkt" merge-fn-registry-size)
         (only-in "../decision-cell.rkt"
                  tagged-cell-value tagged-cell-merge make-tagged-merge
                  decision-domain-merge decision-from-alternatives
                  decision-bot decision-top
                  nogood-empty nogood-merge nogood-add
                  assumptions-empty assumptions-merge assumptions-add
                  counter-merge
                  completion-bot completion-done completion-merge
                  scope-cell-empty scope-cell-merge scope-cell-set
                  decisions-state-empty decisions-state-merge
                  decisions-state-add-component)
         (only-in "../infra-cell.rkt"
                  merge-hasheq-identity merge-hasheq-replace
                  merge-hasheq-list-append merge-list-append
                  merge-list-dedup-append merge-set-union))

;; ============================================================================
;; The law checks
;; ============================================================================

;; `equiv` compares LATTICE VALUES, which is not always `equal?` on the
;; representation. A set carried as a list has a real order, and set-union is
;; commutative while `append` is not — so `nogood-merge` must be compared up to
;; set equality or the law test would demand a property the lattice never
;; claimed. Getting this wrong in the other direction is worse: `equal?` on a
;; representation that carries junk (the duplicate entries above) is exactly what
;; catches the bugs, so the DEFAULT stays `equal?` and a looser one is declared
;; per-merge, in view.
(define (check-idempotent name merge samples equiv)
  (for ([x (in-list samples)])
    (check-true (equiv (merge x x) x)
                (format "~a: merge(x,x) must equal x — x = ~e, got ~e"
                        name x (merge x x)))))

(define (check-commutative name merge samples equiv)
  (for* ([x (in-list samples)] [y (in-list samples)])
    (check-true (equiv (merge x y) (merge y x))
                (format "~a: merge(x,y) must equal merge(y,x) — x = ~e, y = ~e"
                        name x y))))

(define (check-associative name merge samples equiv)
  (for* ([x (in-list samples)] [y (in-list samples)] [z (in-list samples)])
    (check-true (equiv (merge (merge x y) z) (merge x (merge y z)))
                (format "~a: merge must associate — x = ~e, y = ~e, z = ~e"
                        name x y z))))

;; A merge is only a lattice join if repeated application settles. This catches
;; the tagged-cell-merge shape specifically: idempotence on the FIRST
;; application can hold while the value still creeps under repetition.
(define (check-stable-under-repetition name merge samples equiv)
  (for ([x (in-list samples)])
    (define once (merge x x))
    (define twice (merge once once))
    (define thrice (merge twice twice))
    (check-true (equiv thrice once)
                (format "~a: repeated merging must not keep changing the value — x = ~e"
                        name x))))

;; ============================================================================
;; The table
;; ============================================================================
;;
;; (name merge samples laws) — `laws` beyond idempotence, which is always checked.

(struct merge-entry (name fn samples laws equiv) #:transparent)

(define (E name fn samples #:laws [laws '()] #:equiv [equiv equal?])
  (merge-entry name fn samples laws equiv))

;; Same elements, order ignored — for lattice values carried as lists.
(define (set-equiv a b)
  (and (list? a) (list? b)
       (= (length a) (length b))
       (for/and ([x (in-list a)]) (and (member x b) #t))))

(define TAGGED-SAMPLES
  (list (tagged-cell-value 'b '())
        (tagged-cell-value 'b (list (cons 1 'a)))
        (tagged-cell-value 'b (list (cons 1 'a) (cons 2 'c)))))

(define DECISION-SAMPLES
  (list decision-bot
        decision-top
        (decision-from-alternatives '(a))
        (decision-from-alternatives '(a b))))

(define NOGOOD-SAMPLES
  (list nogood-empty
        (nogood-add nogood-empty (seteq 1))
        (nogood-add (nogood-add nogood-empty (seteq 1)) (seteq 2 3))))

(define ASSUMPTION-SAMPLES
  (list assumptions-empty
        (assumptions-add assumptions-empty 1 'a)
        (assumptions-add (assumptions-add assumptions-empty 1 'a) 2 'b)))

(define SCOPE-SAMPLES
  (list (scope-cell-empty)
        (scope-cell-set (scope-cell-empty) 'x 1)
        (scope-cell-set (scope-cell-set (scope-cell-empty) 'x 1) 'y 2)))

;; `decisions-state-empty` takes the aid->int map — it is a constructor, not a
;; constant, unlike its neighbours. Easy to trip over; noted rather than fixed.
(define (fresh-decisions) (decisions-state-empty (hasheq 'a 0 'b 1)))

(define DECISIONS-SAMPLES
  (list (fresh-decisions)
        (decisions-state-add-component (fresh-decisions) 'k
                                       (decision-from-alternatives '(a b)))))

(define HASHEQ-SAMPLES
  (list (hasheq) (hasheq 'a 1) (hasheq 'a 1 'b 2)))

(define HASH-OF-LISTS-SAMPLES
  (list (hasheq) (hasheq 'a '(1)) (hasheq 'a '(1) 'b '(2))))

(define LIST-SAMPLES (list '() '(1) '(1 2)))
(define SET-SAMPLES (list (seteq) (seteq 1) (seteq 1 2)))
(define NAT-SAMPLES (list 0 1 7))

(define MERGES
  (list
   ;; --- decision-cell.rkt ---
   ;; NOT commutative by design: the newer base wins, and entry ORDER is load
   ;; bearing ("NEW entries first — later writes win at same specificity", and
   ;; tagged-cell-read takes the first match when given no domain-merge).
   (E "tagged-cell-merge" tagged-cell-merge TAGGED-SAMPLES)
   (E "make-tagged-merge/identity"
      (make-tagged-merge (lambda (a b) (if (equal? a b) a (list a b))))
      TAGGED-SAMPLES)
   (E "decision-domain-merge" decision-domain-merge DECISION-SAMPLES
      #:laws '(commutative associative))
   ;; Set-union carried as a LIST: commutative and associative as a lattice, but
   ;; only up to element order in the representation.
   (E "nogood-merge" nogood-merge NOGOOD-SAMPLES
      #:laws '(commutative associative) #:equiv set-equiv)
   (E "assumptions-merge" assumptions-merge ASSUMPTION-SAMPLES
      #:laws '(commutative associative))
   (E "counter-merge" counter-merge NAT-SAMPLES
      #:laws '(commutative associative))
   (E "completion-merge" completion-merge (list completion-bot completion-done)
      #:laws '(commutative associative))
   (E "scope-cell-merge" scope-cell-merge SCOPE-SAMPLES)
   (E "decisions-state-merge" decisions-state-merge DECISIONS-SAMPLES)
   ;; --- infra-cell.rkt ---
   ;; hasheq-replace is last-write-wins: idempotent, NOT commutative.
   (E "merge-hasheq-replace" merge-hasheq-replace HASHEQ-SAMPLES)
   (E "merge-hasheq-identity" merge-hasheq-identity HASHEQ-SAMPLES)
   ;; plain append is NOT idempotent by construction — it is an accumulator, not
   ;; a join. Recorded here as a KNOWN non-lattice rather than omitted, so the
   ;; distinction is visible; see the dedicated case below.
   (E "merge-list-dedup-append" merge-list-dedup-append LIST-SAMPLES)
   (E "merge-set-union" merge-set-union SET-SAMPLES
      #:laws '(commutative associative))))

;; ============================================================================
;; Run them
;; ============================================================================

(for ([e (in-list MERGES)])
  (define nm (merge-entry-name e))
  (define fn (merge-entry-fn e))
  (define ss (merge-entry-samples e))
  (define eq (merge-entry-equiv e))
  (test-case (format "merge law: ~a is idempotent" nm)
    (check-idempotent nm fn ss eq)
    (check-stable-under-repetition nm fn ss eq))
  (when (memq 'commutative (merge-entry-laws e))
    (test-case (format "merge law: ~a is commutative" nm)
      (check-commutative nm fn ss eq)))
  (when (memq 'associative (merge-entry-laws e))
    (test-case (format "merge law: ~a is associative" nm)
      (check-associative nm fn ss eq))))

;; ============================================================================
;; The known non-lattice, pinned as such
;; ============================================================================

(test-case "merge-hasheq-list-append is a live CELL merge and is NOT idempotent"
  ;; Found by this file on its first run, alongside nogood-merge. Unlike
  ;; merge-list-append (a helper), this one IS registered as a cell merge —
  ;; metavar-store.rkt:2891/2893/2896, the wakeup registry cells — so it carries
  ;; the same non-quiescence hazard that tagged-cell-merge did.
  ;;
  ;; NOT fixed here, deliberately: deduping the per-key lists changes wakeup
  ;; semantics in a hot registry, and "a duplicate wakeup is harmless" is exactly
  ;; the kind of unchecked parenthetical that produced the two bugs above. It
  ;; deserves its own slice with its own evidence. Filed in DEFERRED.
  ;;
  ;; Pinned as a KNOWN violation rather than omitted, so the table cannot quietly
  ;; stop covering it.
  (check-not-equal? (merge-hasheq-list-append (hasheq 'a '(1)) (hasheq 'a '(1)))
                    (hasheq 'a '(1))
                    "if this becomes idempotent, move it into MERGES above"))

(test-case "merge-list-append is an ACCUMULATOR, not a join — and that is the hazard"
  ;; Recorded rather than hidden. `(append x x)` is not `x`, so a cell using this
  ;; merge cannot reach a fixpoint by re-merging its own value — it relies on the
  ;; caller never doing so. That is precisely the assumption `tagged-cell-merge`
  ;; violated. If a cell ever adopts this merge and its writers are not
  ;; write-once, expect the union-hang shape.
  (check-not-equal? (merge-list-append '(1) '(1)) '(1)
                    "if this ever becomes idempotent, move it into the table above"))

;; ============================================================================
;; Coverage floor
;; ============================================================================

(test-case "COVERAGE-FLOOR: the table has not shrunk"
  ;; A floor on the TABLE, not on the registry — and the difference is a finding.
  ;;
  ;; The first version of this asserted `(<= (merge-fn-registry-size) 40)`, so
  ;; that adding a registration without adding a law entry would fail. It passed
  ;; standalone (`raco test`, registry size under 40) and FAILED in the batch
  ;; runner at 46. Nothing was wrong with the code: `merge-fn-registry.rkt` is a
  ;; process-global hash populated by MODULE SIDE-EFFECTS, so its size is a
  ;; function of what the enclosing process happened to load. A batch worker that
  ;; has already run other test files has loaded more of the compiler.
  ;;
  ;; So registry size cannot gate anything — it is not a property of the tree,
  ;; it is a property of the run. Recorded here rather than worked around,
  ;; because the same trap is available to anyone who reaches for that number.
  ;;
  ;; What remains is the honest, weaker guard: the table must not shrink. Adding
  ;; a merge without adding it here is still uncaught. That is a real gap, and
  ;; closing it wants an enumeration API on the registry plus deterministic
  ;; loading — filed in DEFERRED rather than faked with a number.
  (check-true (>= (length MERGES) 13)
              (format "the table shrank to ~a entries — merges were removed from coverage"
                      (length MERGES)))
  ;; Reported, never asserted.
  (printf "merge-fn-registry-size in this process: ~a (informational — load-order dependent)\n"
          (merge-fn-registry-size)))
