# Generic `Num` — Constraint-as-Type Numeric Functions (Implementation Note / Track Seed)

**Status**: Implementation note — **seed for a proposed Num Series track (Track 2)**. NOT yet Stage-1. Read-only grounding done; no code touched.
**Date**: 2026-07-02
**Series**: `Num` ([`2026-07-02_NUM_MASTER.md`](2026-07-02_NUM_MASTER.md))
**Grounding basis**: `grounding-audit` workflow (run `wf_c7a0bfa2-123`, 5 HEAD-pinned read-only facets + adversarial completeness critic, HEAD `b3369312`), plus main-session probes and surgical R-lens verification. All coordinates cited at HEAD `b3369312` (they drift — re-verify before implementing).

---

## §1 Purpose

Capture the design discussion and grounded findings for making a **bundle/constraint name usable directly in TYPE position** so numeric functions can be written generically:

```prologos
spec square Num -> Num
defn square [x]
  * x x
```

…and applied to any numeric type. This note is the seed for a dedicated Num Series track; it is deliberately **out of focus for the current DEMO needs** (owner, 2026-07-02) and does not belong in Track 1's N6f capstone.

**Owner intent (load-bearing)**: `Num` denotes *any* numeric type, and in a multi-argument signature the occurrences may be **different** numeric types — `spec addy Num -> Num -> Num` should accept `addy 3 3.14` (Int + Posit) and return the numeric-join (widened). This **heterogeneous** reading is the hard part. Approach is the *constraint* (conjunctive-sequent) reading, NOT a union/subtype supertype — consistent with the tower's D-N2 (refinement-via-trait, not subtyping).

## §2 What already exists (so we don't reinvent)

Verified at HEAD `b3369312` (live probes):

- `bundle Num := (Add Sub Mul Neg Eq Ord Abs FromInt)` and `bundle Fractional := (Num Div FromRat)` — `core/algebra.prologos:22,32`.
- **`where (Num A)` already works**: it expands (via `expand-bundle-constraints`, `macros.rkt:3437-3440`) to all 8 dictionaries and resolves at the call site. `spec square {A} A -> A where (Num A)` / `defn square [x] [mul x x]` compiles and dispatches (`[square 3]`→`9 : Int`, `[square 3.14p]`→`9.8596p : Posit64`).
- Trait-method dispatch over a constrained abstract type var works (`[mul x x]`); the head-keyword `[* x x]` does not.

## §3 The three grounded findings (the reframe)

- **F1 — `Num`-in-type-position is *silently mis-elaborated* today, not cleanly erroring.** `known-type-name?` (`macros.rkt:6590`, incl. `(lookup-bundle sym)` at `:6605`) treats a bundle name as a known type → it is **suppressed** from auto-binding, kept as a bare atom, and decays into an unconstrained inference meta with **no constraint attached**. So `spec square Num -> Num` fails **even with a trait-method body** (`No instance of Mul for B`). The desugar must *actively redirect* this suppressed-atom path — it is not filling an empty slot.
- **F2 — the runtime is already fully heterogeneous.** `reduce-generic-binary` (`reduction.rkt:1197-1242`) dispatches on operand runtime value-tags, computes the join, and coerces — so `[+ 3 3.14]` on concrete values *already reduces correctly*. **Every realization shares the SAME single blocker (the static type checker); NONE need runtime changes.** The whole job is "teach the checker what the evaluator already does."
- **F3 — homogeneous is tractable; heterogeneous is categorically larger.** The single-parameter `square : Num -> Num` (one shared type var) is small. The heterogeneous multi-arg case needs **two independent net-new layers** with no existing code path.

## §3a Correction to earlier framing

- The head-keyword operators (`+ - * /`, comparisons) are captured at **parse time** as dedicated `surf-generic-*` nodes (`tree-parser.rkt:311`, `parser.rkt:1958`) → `expr-generic-*` → the **concrete-only `numeric-join`** (`typing-core.rkt:266-291`, `[else #f]` on any abstract operand). `mul` etc. stay `surf-app` resolved via `resolve-method-from-where` (`elaborator.rkt:165-204`) into a dict-accessor application. THIS is the keyword-vs-method divergence.
- For a **`defn` body** (the goal surface), checking runs through the **imperative `inferQ`/`infer`** path (`checkQ-top/err` `driver.rkt:1594` + `check/err`), NOT the on-network path (that's only top-level `eval`/display, `driver.rkt:585`). `inferQ` is *stricter* (extra `concrete-numeric-type?` guards, `qtt.rkt:533…625`). So a fix touching only the on-network ret-fn under-counts.

## §4 The three layers (scope)

| Layer | Delivers | Depth | Primary sites |
|---|---|---|---|
| **L1 — constraint-as-type desugar** | `Num` in type position → `{A} … where (Num A)`; `square` works with `[mul x x]` bodies | **small** — one pass | process-spec `macros.rkt:3432-3496`; scan `type-tokens` for `lookup-bundle`/`lookup-trait` atoms → mint fresh binder + inject `(Bundle A)` into `combined-raw-where` **before** `expand-bundle-constraints`; must redirect the `known-type-name?` suppression (F1) |
| **L2 — keyword routing** | `[* x x]` works (not just `[mul x x]`) on constrained abstract operands | **medium** — cross-cutting | imperative `infer` (`typing-core.rkt:1001-1066`) **+** `inferQ` (`qtt.rkt:527-653`), ~12 arith/cmp ops; the single-site elaboration shortcut (`elaborator.rkt:1549-1621`) is **BLOCKED** — the elaborator has no operand types (types are post-elaboration) — forcing the 3-stage typing edit (the recurring drift trap) |
| **L3 — heterogeneous** | `addy Num -> Num -> Num` mixes types; result = numeric-join | **deep — the track's core** | (1) **fresh-per-occurrence binders** — none exists (`collect-free-type-vars-from-datums` `seen`-dedup `macros.rkt:6648-6664` mints ONE shared binder per name); (2) a **heterogeneous value-level op** — the traits are homogeneous `A A -> A` (`arithmetic-traits.prologos:39-40,140`), there is NO two-type `Add A B` and NO functional-dependency / output-type inference (grep-confirmed absent) |

Homogeneous-vs-heterogeneous is exactly the L1 choice: whether the minted fresh var is **shared-per-name** (reuse `seen` = homogeneous) or **per-occurrence** (net-new logic).

## §5 The heterogeneous realization choice (what L3 must decide)

All four realizations share F2's single static-typing blocker; none need runtime work.

| Realization | Fit with the constraint (not-subtyping) approach | Cost |
|---|---|---|
| **Relational `NumJoin A B C`** (output `C` inferred) | **Best** — a trait/relation, conjunctive; idiomatic for a functional-*logic* language with a relation substrate | net-new functional-dependency / output-mode inference (does not exist) |
| Union-`Num` (`<all numeric types>`) | union/subset — the reading the approach steps away from | combinatorial: result is a union of pairwise joins over the branch cross-product (N→N²), growing through a body; intra-family-only subtyping (`subtype-predicate.rkt:131-141`) means it can't collapse; also `union-sort-key` (`union-types.rkt:43-95`) lacks Float entries (latent bug to fix first) |
| coerce-to-join + homogeneous op | pragmatic | loses per-argument-type identity (both coerced to the join first) |
| type-level-join alone (`NumJoin(A,B)` return) | partial | **necessary-but-not-sufficient** — even a computed return type has no dict to dispatch the homogeneous value op on `a:A, b:B`. NOTE: an on-network "computed return type from arg *types*" already exists for the concrete case (`make-arith-ret`, `typing-propagators.rkt:2066-2090`) — extend, not greenfield |

**Recommendation for the eventual track**: design L3 around the **relational `NumJoin`** direction (it is the theory-aligned + language-idiomatic option), accepting that it needs net-new output-mode/functional-dependency inference — which is itself a meaningful language-feature investment.

## §6 Scope verdict

- **L1 + L2 (homogeneous `Num` in type position, with `* x x` working)** = a tractable phase (~3–4 sub-phases): the L1 desugar (one site) + the L2 3-stage keyword routing + literal coercion (`FromInt` insertion in the N4 CHECK case, `typing-core.rkt:2371`; currently `[else #f]` on an abstract Num target) + tests. This is what would deliver the owner's `square` example.
- **L3 (heterogeneous multi-arg)** = the track's deep core; the relational-`NumJoin` design + fundep/output inference.
- **The `add`/`sub` shadow is bigger than a sub-phase**: the clean fix needs an **FQN-keyed / module-scoped spec store** (currently bare-symbol last-write-wins, `macros.rkt:479-482` + `driver.rkt:2823-2842`), which is **PM-series (module-system) territory** and BLOCKS lifting the `derive-skip-methods '(add sub join reduce)` (`macros.rkt:7573`). Issue mapping: `#66` (spec-store clobber) + `#67` (registry overwrite) — **`#72` was not found in-repo** (earlier "#66/#72" pairing was stale).
- **Biggest risk/unknown**: L2's single-site elaboration shortcut is blocked → the routing lands in the 3-stage typing layer (`infer` + `inferQ` primary; on-network for eval), the recurring drift trap — mirror across all three per `pipeline.md`.

## §7 Open design questions for the track's Stage-1→3

1. **Homogeneous v1 vs heterogeneous-first**: ship L1+L2 (delivers `square`) and defer L3, or design L3 (relational `NumJoin`) up front because homogeneous-only is a partial answer to the intent?
2. **L1 desugar semantics**: same-name-shared binder (homogeneous, reuse `seen`) vs fresh-per-occurrence (heterogeneous prerequisite) — and how a mixed signature (`Num -> Float` — constraint name + concrete type) composes.
3. **L2 routing mechanism**: 3-stage per-op edit vs relaxing `numeric-join` at its single shared choke point (but the per-site `qtt` `concrete-numeric-type?` guards are stricter and won't inherit a relaxation) vs a new elaboration-time route (blocked without operand types — could a two-pass elaborate/infer/re-elaborate unblock it?).
4. **Literal coercion**: insert `from-integer`/`from-rational` (bundle `FromInt`/`FromRat`) for bare literals in a constrained-numeric body — where and under what constraint-resolution trigger (relates to DEFERRED.md N6d-i item 3, output-position-only methods as context-resolved values, UNPROVEN).
5. **L3 realization**: relational `NumJoin A B C` (needs fundep/output inference) vs union vs coerce-to-join — and whether output-mode trait inference is a Num-track deliverable or its own trait-system feature.
6. **`add`/`sub` module-scoped spec store**: keep in this track or hand to a PM-series module fix?

## §8 Key coordinates (for the track's grounding; re-verify — they drift)

- Desugar insertion: `macros.rkt:3432-3496` (`combined-raw-where` → `expand-bundle-constraints`); suppression gate `known-type-name?` `macros.rkt:6590` (`lookup-bundle` `:6605`); homogeneity dedup `collect-free-type-vars-from-datums` `macros.rkt:6648-6664`.
- Keyword nodes: parse `tree-parser.rkt:311` / `parser.rkt:1958`; elaborate `elaborator.rkt:1549-1621` (14 `surf-generic-*`); `infer` `typing-core.rkt:1001-1066`; `inferQ` `qtt.rkt:527-653`; on-network `make-arith-ret` `typing-propagators.rkt:2394-2429`.
- `numeric-join` (single shared choke) `typing-core.rkt:266-291`; `base-numeric-type` `:204-214`; `resolve-solved-meta` `:259-264`. Method dispatch `resolve-method-from-where` `elaborator.rkt:165-204`.
- defn check path `driver.rkt:1594` (`checkQ-top/err`) + `:1715`; eval/on-network `driver.rkt:585-588`.
- N4 literal CHECK `typing-core.rkt:2371-2378`; `FromInt` `conversions.prologos:728`; derive-skip `macros.rkt:7573`; spec-store clobber `macros.rkt:479-482` + `driver.rkt:2823-2842`.
- Runtime (already heterogeneous, no change needed) `reduce-generic-binary` `reduction.rkt:1197-1242`.
- Union realization: `union-types.rkt:43-95` (missing Float sort keys); `type-tensor-distribute` `subtype-predicate.rkt:266-292` (union-operand distribution, disjoint path); on-network `process-fork-on-union` `typing-propagators.rkt:1159`.

## §9 References

- Grounding audit: `grounding-audit` run `wf_c7a0bfa2-123` (2026-07-02, HEAD `b3369312`).
- Series: [`2026-07-02_NUM_MASTER.md`](2026-07-02_NUM_MASTER.md); Track 1: [`2026-06-30_NUMERICS_TRACK_STAGE3_DESIGN.md`](2026-06-30_NUMERICS_TRACK_STAGE3_DESIGN.md).
- Cross-refs: [`2026-06-30_TRAITS_AS_REFINEMENT_TYPING_NOTE.md`](2026-06-30_TRAITS_AS_REFINEMENT_TYPING_NOTE.md) (UCS; general refinement/type-producer surface — the fundep/output-inference machinery L3 wants may share design), `pipeline.md` (three-stage typing exhaustiveness).

---
*Seed note, 2026-07-02. Feeds a future Num Series Track 2 Stage-1→3 cycle. Out of focus for current DEMO needs; opens after Numerics Track 1 completes.*
