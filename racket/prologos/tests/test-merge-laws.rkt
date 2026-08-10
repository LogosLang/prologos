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
;;; hand-written. It covered the decision-cell and infra-cell families at first;
;;; a static scan of `register-merge-fn!/lattice` call sites on 2026-08-05 raised
;;; it to 21 of the 29 registered merges, adding propagator.rkt's four
;;; stratum-request accumulators, three more infra-cell facet merges, and
;;; constraint-cell's. The residual 8 are enumerated in a test-case at the
;;; bottom, with the reason each is not here.
;;;
;;; The guard against the table going stale is COVERAGE-FLOOR below: it fails if
;;; the registry grows past the number of merges recorded here. That is a floor,
;;; not proof of coverage — it cannot tell that a NEW registration is the one
;;; missing. It is the same device `lint-parameters.rkt` and
;;; `lint-discarded-errors.rkt` use, and it has the same limits.
;;;

(require rackunit
         racket/file
         racket/runtime-path
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
                  merge-list-dedup-append merge-set-union
                  merge-constraint-status-map merge-error-descriptor-map
                  merge-mod-status)
         (only-in "../propagator.rkt"
                  retraction-stratum-merge fork-contradiction-request-merge
                  decomposed-positions-merge contradicted-branch-aids-merge)
         (only-in "../infra-cell-sre-registrations.rkt" worldview-merge)
         (only-in "../hasse-registry.rkt" hasse-merge-hash-union)
         (only-in "../elaborator-network.rkt" merge-meta-solve-identity)
         (only-in "../qtt.rkt" add-usage)
         (only-in "../warnings.rkt" warnings-facet-merge)
         (only-in "../atms.rkt" table-answer-merge table-registry-merge)
         (only-in "../typing-propagators.rkt" context-facet-merge)
         (only-in "../session-lattice.rkt" session-lattice-merge)
         (only-in "../tropical-fuel-primitives.rkt" tropical-fuel-merge)
         (only-in "../type-lattice.rkt" type-lattice-merge)
         (only-in "../propagator.rkt" union-derivation-chains-merge)
         (only-in "../classify-inhabit.rkt"
                  merge-classify-inhabit classifier-only inhabitant-only
                  classify-and-inhabit)
         (only-in "../clock.rkt"
                  merge-by-timestamp-max timestamp timestamped-value)
         (only-in "../constraint-cell.rkt"
                  constraint-merge constraint-bot constraint-top
                  constraint-one constraint-set constraint-set? constraint-set-candidates))

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
;; The compiler source directory, resolved from this file's own location so the
;; drift-guard scan does not depend on the working directory of whoever runs it.
(define-runtime-path compiler-src-dir "..")

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

;; classify-inhabit's carrier is a two-layer tag struct, built through its own
;; constructors rather than by hand so the samples cannot drift from the shape.
(define CLASSIFY-SAMPLES
  (list 'infra-bot
        (classifier-only 'bot)
        (classifier-only 'Int)
        (inhabitant-only 'x)
        (classify-and-inhabit 'Int 'x)))

;; timestamped-value over (timestamp counter pid). Deliberately includes two
;; values at the SAME counter with different pids — that is the tie the merge's
;; pid comparison exists to break, and the case where an unlucky merge could
;; oscillate between two writers.
(define (tv c p v) (timestamped-value (timestamp c p) v))
(define TIMESTAMP-SAMPLES
  (list 'infra-bot
        (tv 0 0 'a)
        (tv 1 0 'b)
        (tv 1 1 'c)))

(define HASH-OF-SETS-SAMPLES
  (list (hasheq)
        (hasheq 'p (seteq 1))
        (hasheq 'p (seteq 1 2) 'q (seteq 3))))

;; A one-element `constraint-set` is included ON PURPOSE: it is the shape that
;; makes the merge's normalization visible. It is unconstructible through
;; `constraint-from-candidates`, so this sample is reaching past the public API
;; to pin behaviour the API currently prevents.
(define CONSTRAINT-SAMPLES
  (list constraint-bot constraint-top
        (constraint-one 'a) (constraint-one 'b)
        (constraint-set (seteq 'a 'b))
        (constraint-set (seteq 'a))))

;; Normalize a singleton `constraint-set` to the `constraint-one` the merge and
;; the constructor both produce, then compare.
(define (constraint-norm v)
  (if (and (constraint-set? v) (= 1 (set-count (constraint-set-candidates v))))
      (constraint-one (set-first (constraint-set-candidates v)))
      v))
(define (constraint-equiv a b) (equal? (constraint-norm a) (constraint-norm b)))

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
      #:laws '(commutative associative))
   ;; --- added 2026-08-05, from the static scan of registration sites ---
   ;; The table covered 13 of 29 registered merges. These are the ones that were
   ;; both EXPORTED and probeable; see the test-case below for the ones that are
   ;; not, which is a provide-surface problem rather than a coverage decision.
   ;; --- propagator.rkt: four 'monotone-set stratum-request accumulators ---
   (E "retraction-stratum-merge" retraction-stratum-merge SET-SAMPLES
      #:laws '(commutative associative))
   (E "fork-contradiction-request-merge" fork-contradiction-request-merge SET-SAMPLES
      #:laws '(commutative associative))
   (E "decomposed-positions-merge" decomposed-positions-merge SET-SAMPLES
      #:laws '(commutative associative))
   ;; NOT a plain set, despite registering under 'monotone-set alongside its
   ;; three neighbours: the carrier is a HASH of position → aid-set, hash-union
   ;; with per-position set-union. Caught by this table — SET-SAMPLES made it
   ;; fail commutativity, because the non-hash guard arms (`[(not (hash? old))
   ;; new]`) return whichever argument is a hash, which is asymmetric for inputs
   ;; that are neither. The domain name describes the ALGEBRA, not the carrier.
   (E "contradicted-branch-aids-merge" contradicted-branch-aids-merge
      HASH-OF-SETS-SAMPLES
      #:laws '(commutative associative))
   ;; --- infra-cell.rkt: three more hasheq facet merges ---
   (E "merge-constraint-status-map" merge-constraint-status-map HASHEQ-SAMPLES)
   (E "merge-error-descriptor-map" merge-error-descriptor-map HASHEQ-SAMPLES)
   (E "merge-mod-status" merge-mod-status HASHEQ-SAMPLES)
   ;; --- constraint-cell.rkt ---
   ;; Idempotent only UP TO NORMALIZATION, and the distinction is the point.
   ;; `(constraint-set (seteq 'a))` merged with itself intersects to a
   ;; one-element set, which the merge's own `[(= n 1) (constraint-one …)]` arm
   ;; then normalizes — so `merge(x,x)` is `equal?`-different from `x` while
   ;; being the SAME lattice point. Not a defect: `constraint-from-candidates`
   ;; normalizes a singleton at construction too (`constraint-cell.rkt:109`), so
   ;; a one-element `constraint-set` cannot arise through the public
   ;; constructor. Compared up to normalization rather than dropped, so that if
   ;; either normalization is ever removed this says so.
   (E "constraint-merge" constraint-merge CONSTRAINT-SAMPLES
      #:laws '(commutative associative) #:equiv constraint-equiv)
   ;; --- added 2026-08-05 (second pass), after exporting six module-private
   ;; --- merges for exactly this purpose. Three are joins and live here; the
   ;; --- other three are ACCUMULATORS and are pinned below instead.
   (E "worldview-merge" worldview-merge NAT-SAMPLES
      #:laws '(commutative associative))
   (E "hasse-merge-hash-union" hasse-merge-hash-union HASHEQ-SAMPLES)
   (E "merge-meta-solve-identity" merge-meta-solve-identity HASHEQ-SAMPLES)
   ;; --- the last two, 2026-08-05: both were "uncovered" only for want of
   ;; --- domain-typed samples. Neither needed a design decision.
   (E "merge-classify-inhabit" merge-classify-inhabit CLASSIFY-SAMPLES
      #:laws '(commutative associative))
   (E "merge-by-timestamp-max" merge-by-timestamp-max TIMESTAMP-SAMPLES
      #:laws '(commutative associative))
   ;; --- the seven the coverage arithmetic had been hiding (2026-08-05).
   ;; --- All seven idempotent on first probe; none needed a decision.
   ;; --- Samples are bot-and-simple: these carriers are quantale/lattice
   ;; --- elements whose rich cases belong to their own test files, and the
   ;; --- law here is the ALGEBRA, which bot plus one point already exercises.
   (E "union-derivation-chains-merge" union-derivation-chains-merge HASHEQ-SAMPLES)
   (E "table-answer-merge" table-answer-merge LIST-SAMPLES)
   (E "table-registry-merge" table-registry-merge HASHEQ-SAMPLES)
   (E "context-facet-merge" context-facet-merge HASHEQ-SAMPLES)
   (E "session-lattice-merge" session-lattice-merge (list 'infra-bot))
   (E "tropical-fuel-merge" tropical-fuel-merge NAT-SAMPLES)
   (E "type-lattice-merge" type-lattice-merge (list 'infra-bot))))

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
  ;; NOT fixed, and measurement says it should not be: the three cells using this
  ;; merge are WRITE-ONLY. Instrumented across the 51-file examples corpus —
  ;; 6-11 writes per file, ZERO reads, every file — and the three
  ;; collect-ready-*-for-meta readers have no callers in the tree at all (a
  ;; comment at metavar-store.rkt:1108 already suspected as much). So the
  ;; non-idempotence is dead weight rather than a live hazard, and deduping the
  ;; merge would only make dead machinery tidier. The retirement is filed.
  ;;
  ;; Pinned as a KNOWN violation rather than omitted, so the table cannot quietly
  ;; stop covering it.
  (check-not-equal? (merge-hasheq-list-append (hasheq 'a '(1)) (hasheq 'a '(1)))
                    (hasheq 'a '(1))
                    "if this becomes idempotent, move it into MERGES above"))

(test-case "merge-list-append is an ACCUMULATOR, not a join — deliberately, in one consumer"
  ;; ⚠ CORRECTED 2026-08-05. This case previously called merge-list-append "a
  ;; helper" and warned "if a cell ever adopts this merge ... expect the
  ;; union-hang shape". The antecedent was ALREADY TRUE when that was written:
  ;; it is a live cell merge at EIGHT `net-new-cell` sites. Censused —
  ;;
  ;;   warnings.rkt:108/110/112/114/116  5 warning cells
  ;;   global-constraints.rkt:102        narrow-constraints
  ;;   relations.rkt:3136                the query ANSWER accumulator
  ;;   infra-cell.rkt:309                net-new-list-cell (generic constructor)
  ;;
  ;; The comment is the exact failure mode this file exists to catch: a claim
  ;; about a merge, asserted rather than checked, which stops the next reader
  ;; from checking. Left in the history; corrected here.
  ;;
  ;; Why it is nonetheless NOT the tagged-cell-merge hazard, per consumer:
  ;;
  ;;  - The 5 warning cells are written IMPERATIVELY (`warnings-cell-write!`
  ;;    set-box!es the network from `emit-*-warning`), not by a propagator fire,
  ;;    and `reset-warning-cells!` clears them per command. Nothing re-merges a
  ;;    cell with its own value, so there is no fixpoint to fail to reach.
  ;;
  ;;  - relations.rkt's answer accumulator IS written by a propagator
  ;;    (relations.rkt:3013, the gating-success writers) — and there its
  ;;    non-idempotence is REQUIRED, not tolerated. Rel T1 POL.1 is an owner
  ;;    ruling that solution sets are BAGS: one row per derivation path, the
  ;;    multiplicity IS the derivation count (ℕ-semiring provenance). Deduping
  ;;    this merge would silently violate that ruling.
  ;;
  ;; So: do NOT "fix" this merge. A global dedup would break `solve`'s
  ;; semantics. If a NEW cell adopts it and its writers are propagator re-fires
  ;; whose duplicates are not meaningful, that cell needs a different merge —
  ;; the fix belongs at the cell, not here.
  (check-not-equal? (merge-list-append '(1) '(1)) '(1)
                    "merge-list-append must stay an accumulator — solve's bag semantics depend on it"))

;; ============================================================================
;; Coverage floor
;; ============================================================================

;; The registered merges that are deliberately NOT joins. Declared as DATA
;; because the drift guard below needs to know they are covered-by-exception
;; rather than missing. Adding a name here is a claim that needs its reason
;; written in the test-case that follows.
(define ACCUMULATOR-MERGES
  '(add-usage merge-list-append warnings-facet-merge merge-hasheq-list-append))

(test-case "ACCUMULATORS: four registered cell merges are NOT joins, and three are correct"
  ;; The finding this file was not looking for. `on-network.md` says "every cell
  ;; value must be a lattice element with a monotone merge" — and FOUR registered
  ;; cell merges are not joins at all. They are accumulators: `merge(x,x) ≠ x` by
  ;; construction. Three of them are RIGHT to be, which is why "add dedup" is the
  ;; wrong instinct every time:
  ;;
  ;;   add-usage (qtt.rkt, domain 'usage)
  ;;     (m1) + (m1) = (mw). Semiring ADDITION, not a join — using a linear
  ;;     resource twice makes it unrestricted. Idempotence would BREAK QTT.
  ;;
  ;;   merge-list-append (relations.rkt's answer cell)
  ;;     Rel T1 POL.1: solution sets are BAGS, multiplicity IS the derivation
  ;;     count. Idempotence would break `solve`. See its own case below.
  ;;
  ;;   warnings-facet-merge (warnings.rkt)
  ;;     `append`. Two identical warnings from two sites are two warnings.
  ;;
  ;;   merge-hasheq-list-append — the one with no defence; its cells were
  ;;     write-only and are retired. See its case below.
  ;;
  ;; So the ambient rule is too strong as written, and the honest statement is
  ;; that cells come in TWO kinds. JOIN cells are idempotent, hence CALM-safe and
  ;; order-independent. ACCUMULATOR cells are not, and their correctness
  ;; therefore depends on a property nothing checks: that their writers never
  ;; re-fire with a value already merged. `tagged-cell-merge` was an accumulator
  ;; that believed it was a join, and that is exactly the fourteen-month hang.
  ;;
  ;; `merge-fn-registry.rkt` does not record the difference — a domain name says
  ;; which lattice, never whether it IS one. Filed.
  (check-not-equal? (add-usage '(m1) '(m1)) '(m1)
                    "add-usage is semiring ADD; if this becomes idempotent QTT is broken")
  (check-not-equal? (warnings-facet-merge '(w) '(w)) '(w)
                    "warnings-facet-merge is an accumulator; two identical warnings are two warnings"))

(test-case "DRIFT GUARD: every registered merge is covered, checked against the SOURCE"
  ;; The guard the DEFERRED entry asked for, and the third attempt at it.
  ;;
  ;; Attempt 1 asserted `(<= (merge-fn-registry-size) 40)`. It passed standalone
  ;; and failed in the batch runner at 46, because `merge-fn-registry.rkt` is a
  ;; process-global hash populated by MODULE SIDE-EFFECTS: its size is a property
  ;; of whatever the enclosing process happened to load, not of the tree.
  ;;
  ;; Attempt 2 was me running `comm -23` by hand and writing the answer into a
  ;; comment. That found seven uncovered merges the previous count had hidden —
  ;; and would have gone stale the moment someone registered the next one.
  ;;
  ;; This is attempt 3: do the set difference IN THE TEST, against the source
  ;; text. Registration sites are a property of the TREE, so this is
  ;; deterministic under any loading order — which is exactly what attempt 1
  ;; lacked. No enumeration API on the registry required, so it does not wait on
  ;; PM Track 12.
  ;;
  ;; Deliberately a TEXT scan rather than a runtime enumeration: the registry
  ;; keys on function OBJECTS, so a runtime view can only see merges whose
  ;; modules this process loaded. The source is the whole tree, always.
  ;; Relative to THIS FILE, never to `current-directory` — the first version
  ;; used the latter and the scan found zero merges under the batch worker,
  ;; which is the whole reason the sanity check below exists.
  (define src-dir compiler-src-dir)
  ;; The module that DEFINES the API is not a call site: its own `(define
  ;; (register-merge-fn!/lattice merge-fn ...))` and its provide list both match
  ;; the pattern. Excluded by name rather than by a cleverer regex, because a
  ;; regex that tries to tell a definition from a call is the thing that breaks
  ;; silently later.
  (define (read-all pat dir)
    (for*/list ([f (in-list (directory-list dir))]
                #:when (and (regexp-match? #rx"[.]rkt$" (path->string f))
                            (not (equal? (path->string f) "merge-fn-registry.rkt")))
                [m (in-list (regexp-match* pat (file->string (build-path dir f))
                                           #:match-select cadr))])
      (string->symbol m)))
  (define registered
    (remove-duplicates
     (remq* '(merge-fn)   ;; the generic parameter in phase1d-registrations.rkt's
                          ;; pass-through helper — a variable, not a merge
           (read-all #px"register-merge-fn!/lattice\\s+([a-zA-Z][a-zA-Z0-9!?*/<>+=:-]*)"
                     src-dir))))
  (define covered
    (append (map (lambda (e) (string->symbol
                              (regexp-replace #rx"/identity$" (merge-entry-name e) "")))
                 MERGES)
            ACCUMULATOR-MERGES))
  (define missing (for/list ([r (in-list registered)]
                             #:unless (memq r covered))
                    r))
  (check-equal? missing '()
                (string-append
                 "these merges are registered via register-merge-fn!/lattice but are "
                 "neither in MERGES nor declared in ACCUMULATOR-MERGES. Add a row to "
                 "MERGES (with domain-typed samples), or — if the merge is deliberately "
                 "not a join — add it to ACCUMULATOR-MERGES and write the reason into "
                 "the ACCUMULATORS test-case above. Do not simply widen this list."))
  ;; Sanity: the scan must actually find something, or a regex typo would make
  ;; this guard vacuously green — the failure mode of every scan-based check.
  (check-true (>= (length registered) 25)
              (format "the registration scan found only ~a merges — the regex or the path is wrong"
                      (length registered))))

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
  ;; Raised 13 → 21 on 2026-08-05 by a STATIC scan of `register-merge-fn!/lattice`
  ;; call sites — a property of the TREE, unlike registry size. That scan is the
  ;; shape the real drift guard wants; see the residual test-case below for why
  ;; it is not yet automated here.
  (check-true (>= (length MERGES) 33)
              (format "the table shrank to ~a entries — merges were removed from coverage"
                      (length MERGES)))
  ;; Reported, never asserted.
  (printf "merge-fn-registry-size in this process: ~a (informational — load-order dependent)\n"
          (merge-fn-registry-size)))
