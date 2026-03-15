# D4: Explain Provenance — Stage 3 Design

**Date**: 2026-03-14
**Status**: DESIGN (Stage 3)
**Depends on**: WFLE (complete), Logic Engine Phase 7 surface syntax (complete)
**Blocked by**: Nothing — all prerequisites are in place
**Source design**: `2026-02-24_LOGIC_ENGINE_DESIGN.md` §7.4.4, §7.6.3, §7.6.4

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 1 | Answer type + derivation tree structures | ⬜ | Racket-side structs |
| 2 | explain-goals parallel DFS solver | ⬜ | Option B: decoupled from solve path |
| 3 | Provenance level dispatch | ⬜ | :none / :summary / :full / :atms |
| 4 | WF integration (certainty + cycle) | ⬜ | Orthogonal to provenance |
| 5 | Output serialization to Prologos maps | ⬜ | Answer → user-facing map |
| 6 | Tests (L1/L2/L3) | ⬜ | Three-level WS validation |
| 7 | Acceptance file updates | ⬜ | D4 section uncommented |

---

## 1. Problem Statement

`explain` / `explain-with` currently returns flat maps with query variable bindings.
The WFLE added `__certainty` and `__cycle` as flat keys merged directly into the
bindings CHAMP map. This was expedient but violates two design decisions from the
Logic Engine Design (§7.6.3):

1. **`explain` should return `Seq (Answer Value)`**, not `Seq (Map Keyword Value)`.
   The `Answer` type bundles bindings with provenance as structured data — a record,
   not a flat map with magic-prefixed keys.

2. **Provenance is gated by level** (`:none`, `:summary`, `:full`, `:atms`), read
   from the solver config's `:provenance` key. Currently hardcoded to `'full` in
   the dispatch, and the provenance data itself is always empty (`#f` derivation,
   `#f` support).

Additionally, WF-specific semantics (certainty, cycle info) are conflated with
provenance. These are orthogonal concerns:
- **Certainty** is a semantic property of the answer under WF evaluation — it tells
  you *what the answer means* (definite vs unknown). It should always be present
  when using WF semantics.
- **Provenance** is an observability property — it tells you *how the answer was
  derived* (which clauses, what tree structure, what assumptions). It's opt-in
  via the `:provenance` solver key.

---

## 2. Design Principles Applied

| Principle | Application |
|-----------|-------------|
| **Decoupled** | Solve path and explain path are separate code paths (Option B). WF certainty is orthogonal to provenance level. |
| **First-class** | Derivation trees are values — `derivation-tree` structs returned alongside bindings. Data all the way down. |
| **Data-oriented** | The proof structure is a plain struct tree, serializable to Prologos maps. Not callbacks or closures. |
| **Composable / Layered** | Provenance is a layer on top of solving. Each level composes with WF certainty orthogonally. |
| **Pay-for-what-you-use** | `solve` never touches derivation code. `explain` with `:none` doesn't build trees. Only `:summary`+ runs the heavier path. |
| **Completeness over deferral** | Full context is available now — DFS structure is clear, structs exist, plumbing is understood. |

### Why Option B (Parallel Explain Solver)

Three options were evaluated:

- **Option A (Thread through solve-goals)**: Add derivation accumulator to
  `solve-goals`/`solve-single-goal`/`solve-app-goal`. Touches the hot path for
  `solve` (which doesn't need derivations). Coupling violation.

- **Option B (Separate explain solver)**: Write `explain-goals`/`explain-app-goal`
  that mirror the solve variants but return `(subst . derivation-tree)` pairs.
  Zero impact on `solve` hot path. Unification core is shared.

- **Option C (Post-hoc replay)**: Run `solve-goal`, then replay each answer to
  reconstruct the derivation tree. Unsound under nondeterminism — replay may find
  a different proof path than the one that originally succeeded.

**Decision**: Option B. Decoupled, first-class, data-oriented, complete.

---

## 3. Architecture

### 3.1 Data Flow

```
explain-with solver (goal args...)
  │
  ├─ read solver config → provenance level, semantics
  │
  ├─ semantics = 'stratified ?
  │   ├─ provenance = 'none → solve-goal + wrap as Answer (no tree)
  │   └─ provenance ≥ 'summary → explain-goals (parallel DFS with tree)
  │
  └─ semantics = 'well-founded ?
      ├─ wf-explain-goal (bilattice fixpoint)
      │   ├─ definite answers:
      │   │   ├─ provenance = 'none → Answer with certainty only
      │   │   └─ provenance ≥ 'summary → Answer with certainty + derivation
      │   └─ unknown answers:
      │       └─ Answer with certainty='unknown + cycle info (always)
      └─ serialize Answer → Prologos map
```

### 3.2 The Answer Record

From the Logic Engine Design (§7.6.3), refined:

```prologos
deftype Answer {V : Type}
  :bindings    (Map Keyword V)           ;; the substitution — the what
  :certainty   (Option Keyword)          ;; WF semantics: :definite | :unknown | nil
  :cycle       (Option (List String))    ;; WF undeterminacy: predicates in neg cycle
  :provenance  (Option ProvenanceData)   ;; the why — gated by provenance level

deftype ProvenanceData
  :clause-id   (Option Keyword)          ;; which clause/fact produced this
  :depth       Nat                       ;; derivation depth
  :derivation  (Option DerivationTree)   ;; present at :full and :atms
  :support     (Option (Set Keyword))    ;; ATMS support set — at :atms only

deftype DerivationTree
  :goal      Keyword                     ;; relation name
  :args      (List Value)                ;; instantiated arguments
  :rule      Keyword                     ;; clause identifier ("fact-0", "clause-1")
  :children  (List DerivationTree)       ;; sub-derivations
```

**Key refinement from §7.6.3**: The original design put `clause-id`, `depth`,
`derivation`, and `support` directly on `Answer`. This design nests them under
`:provenance` as a `ProvenanceData` record, so that:
1. You can key out `:provenance` to get all observability data in one value
2. The presence/absence of `:provenance` signals whether provenance was requested
3. WF semantics fields (`:certainty`, `:cycle`) live at the top level — they're
   always present when using WF, independent of provenance level

### 3.3 Separation of Concerns

```
Answer
├── :bindings     — WHAT was found (always present)
├── :certainty    — WHAT IT MEANS under WF (semantic, always on for WF)
├── :cycle        — WHY it's uncertain (semantic, always on for unknown)
└── :provenance   — HOW it was derived (observability, opt-in via config)
    ├── :clause-id
    ├── :depth
    ├── :derivation
    └── :support
```

This separation means:
- **Stratified semantics**: `:certainty` is absent (or nil). Anything that would
  be uncertain has already errored out under stratified evaluation. The absence of
  `:certainty` cues you that you're looking at a stratified response, not WF.
- **WF semantics**: `:certainty` is always `definite` or `unknown`. Its presence
  cues you that you're in WF-semantic land.
- **Provenance `:none`**: `:provenance` is absent. You get bindings + certainty.
- **Provenance `:summary`**: `:provenance` present with `:clause-id` and `:depth`.
- **Provenance `:full`**: `:provenance` present with full `:derivation` tree.
- **Provenance `:atms`**: `:provenance` present with `:derivation` + `:support`.

---

## 4. Output Format

### 4.1 Serialized as Prologos Maps

Each `Answer` serializes to a Prologos map. The structure mirrors the record:

**Stratified, `:none` provenance (default):**
```prologos
explain (ancestor "alice" who)
;; => [{:who "bob"} {:who "carol"}]
```
No certainty (stratified), no provenance. Identical to `solve` output.

**WF, `:none` provenance:**
```prologos
explain-with wf-solver (pacifist "nixon")
;; => [{:x_ "nixon", :certainty :unknown, :cycle '["pacifist" "hawk"]}]

explain-with wf-solver (reachable "a" to)
;; => [{:to_ "b", :certainty :definite} {:to_ "c", :certainty :definite}]
```
Certainty always present (WF). Cycle only when unknown. No provenance data.

**WF, `:summary` provenance:**
```prologos
solver wf-debug
  :semantics well-founded
  :provenance summary

explain-with wf-debug (reachable "a" to)
;; => [{:to_ "b", :certainty :definite,
;;      :provenance {:clause-id :reachable/2-1, :depth 1N}}
;;     {:to_ "c", :certainty :definite,
;;      :provenance {:clause-id :reachable/2-1, :depth 2N}}]
```

**WF, `:full` provenance:**
```prologos
solver wf-full
  :semantics well-founded
  :provenance full

explain-with wf-full (ancestor "tom" desc)
;; => [{:desc "bob", :certainty :definite,
;;      :provenance {:clause-id :ancestor/2-0, :depth 1N,
;;                   :derivation {:goal :ancestor, :args '["tom" "bob"],
;;                                :rule :ancestor/2-0,
;;                                :children '[{:goal :parent,
;;                                             :args '["tom" "bob"],
;;                                             :rule :parent/2,
;;                                             :children '[]}]}}}]
```

**Stratified, `:full` provenance:**
```prologos
solver debug-solver
  :provenance full

explain-with debug-solver (ancestor "tom" desc)
;; => [{:desc "bob",
;;      :provenance {:clause-id :ancestor/2-0, :depth 1N,
;;                   :derivation {:goal :ancestor, :args '["tom" "bob"],
;;                                :rule :ancestor/2-0,
;;                                :children '[...]}}}]
```
No certainty (stratified). Full provenance tree.

### 4.2 Key Naming Convention

| Key | Presence | Type | Meaning |
|-----|----------|------|---------|
| `:certainty` | WF only | `:definite` \| `:unknown` | Three-valued WF result |
| `:cycle` | Unknown WF only | `(List String)` | Predicates in negative cycle |
| `:provenance` | ≥ `:summary` | `Map` | Nested provenance data |
| `:clause-id` | In provenance | `Keyword` | Which clause/fact matched |
| `:depth` | In provenance | `Nat` | Max recursion depth |
| `:derivation` | `:full`+ | `Map` (nested) | Complete proof tree |
| `:support` | `:atms` only | `(Set Keyword)` | ATMS assumption set |

Note: We drop the `__` prefix from the WFLE quick-ship implementation. The nesting
under `:provenance` already disambiguates provenance keys from user bindings. The
top-level `:certainty` and `:cycle` are semantic, not provenance — they don't need
a disambiguating prefix because no user-defined relation parameter would be named
`certainty` or `cycle` (they'd be `certainty_` or `?certainty` in relational context).

---

## 5. Implementation Plan

### Phase 1: Racket-Side Structs (provenance.rkt)

The `answer-record` struct already exists but fields are unused. Refine to match:

```racket
;; In provenance.rkt — already exists, refine

;; The top-level answer: bindings + optional semantics + optional provenance
(struct answer-result (bindings certainty cycle provenance) #:transparent)

;; Provenance data (nested under :provenance key)
(struct provenance-data (clause-id depth derivation support) #:transparent)

;; Derivation tree node (already exists as derivation-tree, keep as-is)
(struct derivation-tree (goal args rule children) #:transparent)
```

### Phase 2: Parallel Explain DFS Solver (relations.rkt)

New functions mirroring the solve path:

```racket
;; explain-goals : config store goals subst depth → (listof (cons subst derivation-tree))
(define (explain-goals config store goals subst depth) ...)

;; explain-single-goal : config store goal subst depth → (listof (cons subst derivation-tree))
(define (explain-single-goal config store goal subst depth) ...)

;; explain-app-goal : config store goal-name goal-args subst depth → (listof (cons subst derivation-tree))
(define (explain-app-goal config store goal-name goal-args subst depth) ...)
```

These share the unification core (`unify-terms`, `walk`, freshening) with the
solve path. The difference: every recursive call also builds and returns a
`derivation-tree` node alongside the substitution.

For `:summary` level, the tree structure is not built — only `clause-id` and
`depth` are recorded. This is a flag check at the `explain-app-goal` level:

```racket
(define (explain-app-goal config store goal-name goal-args subst depth)
  (define prov-level (solver-config-provenance config))
  ;; ... match facts/clauses as in solve-app-goal ...
  ;; For each successful fact:
  (define arity (length goal-args))
  (define clause-id
    (string->symbol (format "~a/~a-~a" goal-name arity fact-idx)))
  (define node
    (if (eq? prov-level 'summary)
        #f  ;; no tree node at summary level
        (make-derivation goal-name resolved-args clause-id '())))
  (define prov
    (provenance-data clause-id depth node #f))
  (cons result-subst prov)
  ;; ... similar for clauses, with children from recursive explain-goals ...
  )
```

### Phase 3: Provenance Level Dispatch (stratified-eval.rkt, reduction.rkt)

In `stratified-explain-goal`:

```racket
(define (stratified-explain-goal config store goal-name goal-args query-vars)
  (define semantics (solver-config-semantics config))
  (define prov-level (solver-config-provenance config))

  ;; Force provenance on for explain (default to :full if :none)
  (define effective-prov
    (if (eq? prov-level 'none) 'full prov-level))

  (case semantics
    [(well-founded)
     (wf-explain-goal config store goal-name goal-args query-vars effective-prov)]
    [else
     (case effective-prov
       [(none)
        ;; Fast path: delegate to solve-goal, wrap as answer-result
        (define bindings (solve-goal config store goal-name goal-args query-vars))
        (for/list ([bm (in-list bindings)])
          (answer-result bm #f #f #f))]  ;; no certainty (stratified), no provenance
       [else
        ;; Provenance path: use explain-goals parallel solver
        (define results
          (explain-goal-with-provenance config store goal-name goal-args query-vars effective-prov))
        results])]))
```

In `reduction.rkt` (`run-explain-goal`):
- Read provenance from solver config instead of hardcoded `'full`
- Serialize `answer-result` structs to Prologos maps using the nested structure

### Phase 4: WF Integration (wf-engine.rkt)

`wf-explain-goal` already produces `wf-explained-answer` structs. Refine to produce
`answer-result` structs instead:

- **Definite answers**: `certainty = 'definite`, `cycle = #f`. If provenance ≥
  `:summary`, delegate to `explain-goals` for the derivation data.
- **Unknown answers**: `certainty = 'unknown`, `cycle = (list-of-predicate-symbols)`.
  Provenance is typically `#f` for unknown answers (no derivation to show —
  the cycle IS the explanation).

### Phase 5: Output Serialization (reduction.rkt)

Build the Prologos map from `answer-result`:

```racket
(define (answer-result->prologos-map ar query-vars bound-args)
  (define base-champ
    ;; ... build from bindings as today ...
    )

  ;; Add :certainty if present (WF only)
  (define with-certainty
    (if (answer-result-certainty ar)
        (champ-insert base :certainty (expr-keyword (answer-result-certainty ar)))
        base))

  ;; Add :cycle if present (unknown WF only)
  (define with-cycle
    (if (answer-result-cycle ar)
        (champ-insert with-certainty :cycle (list->prologos-list ...))
        with-certainty))

  ;; Add :provenance if present
  (define with-prov
    (if (answer-result-provenance ar)
        (let ([prov (answer-result-provenance ar)])
          (champ-insert with-cycle :provenance
                        (provenance-data->prologos-map prov)))
        with-cycle))

  (expr-champ with-prov))
```

### Phase 6: Tests

**Level 1 (sexp):**
- `test-explain-provenance.rkt` — test provenance levels via `process-string`
- Stratified: `:none` → no provenance; `:summary` → clause-id + depth; `:full` → tree
- WF: certainty always present; provenance gated independently

**Level 2 (WS string):**
- `process-string-ws` tests for explain-with solver surface syntax

**Level 3 (WS file):**
- Update acceptance file `2026-03-14-wfle-acceptance.prologos` D4 section

### Phase 7: Acceptance File

Uncomment D4 section with working examples showing provenance at each level.

---

## 6. ATMS Provenance (`:atms` Level)

At `:atms` level, each answer's provenance includes the ATMS support set — the
minimal set of assumptions under which this answer holds. This is the most
expensive provenance level: it requires the ATMS layer to be active.

```prologos
solver atms-debug
  :strategy    :atms
  :provenance  :atms

explain-with atms-debug (coloring node color)
;; => [{:node "a", :color "red",
;;      :provenance {:clause-id :coloring/2-0, :depth 2N,
;;                   :derivation {...},
;;                   :support #{:h1 :h3}}}    ;; assumption set
;;     {:node "a", :color "blue",
;;      :provenance {:clause-id :coloring/2-0, :depth 2N,
;;                   :derivation {...},
;;                   :support #{:h2 :h4}}}]   ;; different worldview
```

The support set answers: "Under which assumptions does this answer hold?" This
is essential for:
- **Debugging nondeterministic search**: Which choices led to this answer?
- **Dependency-directed backtracking**: If this answer is wrong, which assumptions
  should be retracted?
- **Minimal explanation**: The support set is the minimal justification — removing
  any assumption invalidates the answer.

### ATMS + WF Composition

Per the WFLE design (§4.3, Option 3: Orthogonal composition): ATMS manages
worldview alternatives; bilattice manages negation-as-failure. Within each
worldview, the bilattice converges independently.

At `:atms` provenance under WF semantics:
```
Answer
├── :bindings      — what was found
├── :certainty     — definite | unknown (WF bilattice result)
├── :cycle         — neg cycle predicates (if unknown)
└── :provenance
    ├── :clause-id
    ├── :depth
    ├── :derivation — proof tree
    └── :support   — ATMS assumption set (which worldview)
```

Both certainty and support are present. They answer different questions:
- **Certainty**: "Is this answer definitely true, or could it go either way?"
  (negation-as-failure question)
- **Support**: "Under which set of choices does this answer hold?"
  (nondeterminism question)

---

## 7. Migration from Current Implementation

The WFLE quick-ship used flat `__certainty`/`__cycle` keys in the CHAMP map.
This needs to migrate to the structured `answer-result` approach:

1. Replace `wf-explained-answer` usage in `wf-engine.rkt` → produce `answer-result`
2. Replace flat-map building in `reduction.rkt` `run-explain-goal` → use serializer
3. Drop `__` prefix: `:certainty` not `:__certainty`, `:cycle` not `:__cycle`
4. Update all existing WFLE tests to expect new key names
5. Update acceptance file expected outputs

This is a breaking change for any code relying on `__certainty`/`__cycle` keys.
Since WFLE shipped same-day and has no external consumers, the migration cost is
purely our test suite.

---

## 8. Test Matrix

| Scenario | Semantics | Provenance | Expected Keys |
|----------|-----------|------------|---------------|
| Basic explain | stratified | none (→ full) | bindings + provenance |
| WF explain | well-founded | none | bindings + certainty [+ cycle] |
| WF + summary | well-founded | summary | bindings + certainty + provenance{clause,depth} |
| WF + full | well-founded | full | bindings + certainty + provenance{clause,depth,derivation} |
| Stratified + summary | stratified | summary | bindings + provenance{clause,depth} |
| Stratified + full | stratified | full | bindings + provenance{clause,depth,derivation} |
| Unknown atom | well-founded | any | bindings + certainty:unknown + cycle |
| ATMS + full | stratified | atms | bindings + provenance{..., support} |
| ATMS + WF | well-founded | atms | bindings + certainty + provenance{..., support} |

---

## 9. Design Decisions (Resolved)

1. **`explain` default provenance**: `explain` forces provenance to `:full` when
   the solver says `:none`. Follows the LE Design spec — calling `explain` implies
   you want the why. If `:full` proves too heavy in practice, we can default to
   `:summary` later. **Decision: `:full`.**

2. **Clause identification scheme**: `relation-name/arity-index` format.

   **Convention**:
   ```
   ancestor/2-0    — relation "ancestor", arity 2, first clause (or fact)
   ancestor/2-1    — relation "ancestor", arity 2, second clause
   ancestor/2      — elided index when only one clause at this arity
   parent/2        — single-clause relation, arity 2
   rel-g1234/3-0   — anonymous rel, gensym-based name, arity 3, first clause
   ```

   **Rationale**: Arity is structurally meaningful — multi-arity `defr` defines
   genuinely different variants. `ancestor/2-1` tells you *which variant shape*
   matched, not just which clause. Adding a clause to the 3-arity variant doesn't
   shift IDs for the 2-arity clauses. Arity partitions provide natural stability
   boundaries.

   For named `defr`: uses the relation name directly.
   For anonymous `rel`: uses `rel-<gensym>` prefix — reads more honestly than
   `anon-<gensym>`, since `rel` is the syntactic form that produced it.

   Whether a clause-id points to a fact or clause is visible from the derivation
   tree structure: facts have empty `:children`, clauses don't. The ID is a
   *locator*, not a complete description.

   **Future**: Named clauses on `defr` (e.g., `:base &> ...`, `:recurse &> ...`)
   would allow user-chosen stable IDs. This is a separate syntax design concern
   — touches parser, surface syntax, `clause-info` struct. Not entangled with
   provenance implementation.

   Content-hashing was considered but rejected: stable but opaque — you can't
   look at the ID and know which clause it refers to.

   **Decision: `name/arity-index`, `rel-<gensym>/arity-index` for anonymous.**

3. **Derivation tree depth limit**: Configurable via `:max-derivation-depth` on
   the solver config, with a default of 50. Most real relational programs are
   shallow (ancestor chains, graph reachability). Depth 50 means 50 levels of
   recursive clause application — already very deep. If hit, the tree is truncated
   at that depth with a sentinel node (e.g., `{:goal :truncated, :depth 50N}`).
   Users can override higher on their solver config if needed.

   **Decision: default 50, configurable via `:max-derivation-depth`.**

---

## 10. Files Modified

| File | Change |
|------|--------|
| `racket/prologos/provenance.rkt` | Refine structs: `answer-result`, `provenance-data` |
| `racket/prologos/relations.rkt` | Add `explain-goals`, `explain-app-goal` (parallel solver) |
| `racket/prologos/stratified-eval.rkt` | Dispatch by provenance level |
| `racket/prologos/wf-engine.rkt` | Produce `answer-result` instead of `wf-explained-answer` |
| `racket/prologos/reduction.rkt` | Serialize `answer-result` → Prologos map (nested) |
| `racket/prologos/solver.rkt` | Add `:max-derivation-depth` key (default 50) |
| `tests/test-explain-provenance.rkt` | NEW: provenance level tests |
| `tests/test-wfle-*.rkt` | Update expected keys: `__certainty` → `certainty` |
| `examples/2026-03-14-wfle-acceptance.prologos` | D4 section with working examples |
