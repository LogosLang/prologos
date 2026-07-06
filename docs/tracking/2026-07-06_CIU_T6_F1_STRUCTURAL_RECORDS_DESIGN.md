# CIU Track 6, F1 — Structural Record Typing for Anonymous Maps (Stage-3 Design)

**Status**: **Stage-3 D.1 (draft)** — awaiting Pre-0 benchmark input (→ D.2) and independent adversarial critique rounds (→ D.3+), per `DESIGN_METHODOLOGY.org` § Stage 3.
**Date**: 2026-07-06 · **Owner**: Zee Larson · **Series/Track**: CIU Track 6, phase F1
**Co-design home**: [`2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md`](2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md) (§2a locked decisions D1–D12; §3b research synthesis; §4a grounding). Research note: [`ROWS_COALGEBRA_PROPAGATOR_NOTE`](../research/2026-07-06_ROWS_COALGEBRA_PROPAGATOR_NOTE.md).
**Verified-at**: HEAD `ead785c0` (all file:line coordinates in this doc re-verified there by main-session R-lens; re-grep before trusting after drift).

## §1 Goal and one-sentence job

`{:a 1}.a : Int` — anonymous map literals type **structurally/observationally** (the type of `{:a 1}` is the record `{:a Int}`), so `+ {:a 1}.a 1 ⇒ 2 : Int` (owner V5). The entire job: **replace the elaborator's hardcoded `Open` value-type for unannotated literals with a ground row**, and teach the map-op typing arms to consume it. The projection machinery already works when the type is concrete (verified live: `def am : (Map Keyword Int) := {:a 1}` → `am.a : Int` today).

Non-goals of F1a (explicitly deferred): dyn-tail semantics (F1a.2), width subsumption + Map↔schema seal (F1b), row variables ρ / `Concat` constraints (F-row), extensible variants (F-variant), any surface syntax change (record types are inferred + displayed, not user-writable, in F1a).

## §2 Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| Pre-0 | Serializer probe + field-rep micro + display-churn census + baseline timing + acceptance file + `--check` expectation runner | ✅ | 2026-07-06; results §7. `record-field` struct SAFE; sorted-assoc confirmed; churn small; acceptance 26/26 green at baseline |
| F1a-s1 | `expr-Record` node through core pipeline (files 1–8 + sets) + display | ⬜ | |
| F1a-s2 | Literal inference (keyword-keyed seed; map-empty/assoc arms) + projection arms + qtt delegation | ⬜ | The `{:a 1}.a : Int` slice |
| F1a-s3 | Remaining map-op arms + Record-vs-Map subsumption (union-join for metas) + union arm | ⬜ | |
| F1a-s4 | Flip acceptance `;;N=>` expectations to F1a targets (+ add `het.z` closed-row miss) + `test-first-class-paths` flips + census fixes (~10 assertions / 4 files) + suite wrapper for `--check` | ⬜ | Acceptance file EXISTS (Pre-0), baseline-green |
| F1a-s5 | Full-suite gate + `bench-ab` + PIR-lite checkpoint | ⬜ | |
| F1a.2 | dyn tail live; `Open` relocation + node deletion (D1-b/D7) | ⬜ | Own mini-design |
| F1b | Erasure-mode width + label-keyed depth; schema→Map free; Map→schema seal | ⬜ | Own Stage-3 |
| F-row / F-variant | ρ (spike: row-kinded meta), `Concat`/`DeepConcat`, open sums | ⬜ | UCS-5 / SRE-5 junctions |

## §3 Grounded code facts this design consumes (all VERIFIED at `ead785c0`)

| Fact | Where |
|---|---|
| `Open` minted at exactly 2 sites, both the unannotated-literal seed | `elaborator.rkt:2127` (empty), `:2132` (non-empty), comment `:2117` |
| Literal entries (`ek`/`ev` exprs) in-hand at the mint site | `elaborator.rkt:2138-2139` |
| `{:a 1}` infers `(expr-Map ?km (expr-Open))` — hits the **Map arm**, not the schema arm | `typing-core.rkt:1465-1473` (assoc fold), `:1512-1513` (map-get returns `vt`) |
| `expr-Map` = 2 slots, no field table; 102 production `(expr-Map ` sites | `syntax.rkt:648`; 34 typing-core / 20 qtt / 3 zonk / 2 unify / 2 trait-resolution |
| `m.a` lowers to `(map-get m :a)`; `m[i]` to `(get m i)` | `macros.rkt:5064/5096/5119` vs `:5112` |
| qtt `map-get` Map arm is INLINE (no delegation; no Open arm; `tu-error` fallback); schema arm delegates to `infer` | `qtt.rkt:1213` vs `:1215-1218`; assoc arm propagates `t1` unchanged (`:1196-1205`) |
| Open α-wildcard: 3 sites; **also load-bearing for ordinary annotation checks** (`{} : (Map K T)` succeeds only via `unify:574`) | `unify.rkt:574-575`, `typing-core:2608-2609`, `qtt:2140-2141`; `typing-core:2424-2426`, `:2429-2431` |
| Annotated-literal checking is TERM-directed (never consults the inferred type) | `typing-core:2429-2431` (vs Map), `:2433-2448` (vs schema, `closed?` at `:2444`) |
| Schema projection template + datum→expr converter | `typing-core:1536-1548`, `:390-393`, `:351-386`; `schema-field` = `(keyword type-datum default-val check-pred)` `macros.rkt:758` |
| `compound-type?` whitelist excludes any new node (F1b concern, NOT F1a — see §6.4) | `subtype-predicate.rkt:106-111`, `subtype?` `:113-126` |
| Union map-get arm filters `expr-Map?` components; **uses `with-speculative-rollback` + `build-union-type`** (retired-mechanism inconsistency, flagged) | `typing-core:1549-1568`, comment `:1459` |
| No map `merge` exists (only list merge-sort) — map combination = `assoc` chains | `lib/prologos/{book,data}/list*.prologos:359/334`; no `expr-map-merge`/keyword |
| Current behavior baseline (live probe) | `{:a 1 :b "hello"}` : `[Map Keyword Open]`; `.a`/`.b` : `Open`; `+ q.a 1` = "Could not infer type"; annotated + schema paths already project concretely |

## §4 The design

### §4.1 The carrier — `expr-Record` (D6)

```racket
;; syntax.rkt — the anonymous structural record TYPE node (internal-only in F1a: inferred + displayed, not parsed)
(struct expr-Record (fields tail) #:transparent)
;;   fields : canonical assoc list ((label . field-info) ...) — label = bare keyword symbol,
;;            sorted by symbol<? (constructor-enforced canonical form)
;;   tail   : 'closed | 'dyn        (F1a mints 'closed ONLY; 'dyn semantics land F1a.2;
;;                                   ρ = an expr (row-kinded meta) at F-row — the slot is expr-ready)

;; field-info, primary proposal: a small struct
(struct record-field (type presence) #:transparent)
;;   type     : a type expr (per-field types are ORDINARY type exprs/metas — NO new meta domain)
;;   presence : 'present            (F1a writes ONLY 'present; 'optional | 'absent | 'unknown reserved per D6)
;; FALLBACK (if Pre-0 shows pnet-serialize cannot handle a nested non-expr struct): plain pairs
;;   (label . (cons type presence-symbol)) — serializer-native; same information, less shape.
```

Why sorted assoc (not hasheq): deterministic serialization + pretty-print + structural `equal?`; cheap recursion in `shift`/`subst`/`zonk`; n is small (records are human-written). The unordered unique-label row *theory* is unchanged — sorting is a canonical form, not semantics. Pre-0 measures assoc-vs-hasheq lookup at n∈{1,4,16} to confirm.

**Well-formedness**: `is-type` — `(expr-Record fields tail)` is a type at `Type 0` iff every field's `type` is a type (mirrors `expr-Map` at `typing-core:1445-1448`); `infer-level` → `lzero`. Duplicate labels are impossible by construction (map-literal keys are unique; assoc extension overwrites).

**Type-lattice merge (spec, not F1a code)**: record-meet — field-set union + per-field unify; failure ⇒ contradiction. In *information* order this is the JOIN (accumulating observations); the OSF orientation flip is documented once, here: OSF's generality-meet = our information-join.

**Records vs dictionaries (a load-bearing distinction this design introduces)**: a *record* is a keyword-literal-keyed literal — finite, syntactically-known field set. A *dictionary* is a map with computed/non-keyword keys — uniform `(Map K V)`. F1a gives records `expr-Record` types and leaves dictionaries EXACTLY as today. The moment a non-literal key enters a record flow, typing degrades to dictionary view (§4.3). `expr-Map` is NOT retired — it remains the dictionary type and the annotation surface.

### §4.2 Elaboration (the only elaborator change)

`surf-map-literal` (`elaborator.rkt:2113-2145`): if **non-empty and every key elaborates to `expr-keyword`** → seed the chain with a **record seed** instead of `(expr-map-empty km (expr-Open))`. Mechanism: seed `(expr-map-empty (expr-Keyword) (expr-Record '() 'closed))` — zero new *term* nodes; the record type rides the existing v-type slot and `infer` returns it (§4.3). Otherwise (empty literal `{}`, or any non-keyword key) → **unchanged**, today's Open seed. (`{}` stays on the legacy path in F1a deliberately: it is the dictionary-accumulator idiom's seed; its record reading arrives with dyn tails in F1a.2.)

Annotated literals are untouched — checking is term-directed (`typing-core:2429/2433`) and never consults the seed.

### §4.3 Typing arms — the per-site disposition table (F1a-s2/s3)

All in `typing-core.rkt` `infer` unless noted. `R` = the map's whnf-inferred type is `(expr-Record fields tail)`; F1a tails are always `'closed`.

| Site (current line) | Disposition on `R` |
|---|---|
| `expr-map-empty` (`:1450`) | If v-type is `expr-Record` → return it (the empty ground record). Else unchanged. |
| `expr-map-assoc` (`:1465`) | Key = `expr-keyword` lit → `infer` v; **extend** fields right-priority (assoc = single-field merge; this IS D10's exact extension typing). Key non-literal → **degrade to dictionary**: return `(expr-Map (infer-type-of k) (expr-Open))` — byte-identical to today's behavior for dynamic keys (Open survives F1a per D7). |
| `expr-map-get` (`:1512`) / `expr-get` (`:1491`) | Key = keyword lit: present → the field's type (**the goal**); absent → `(expr-error)` with the closed-row-miss diagnostic (§4.6). Key non-literal → `build-union-type` of all field types (sound: some field is selected; strictly better than Open). |
| `expr-nil-safe-get` (`:1585` region) | Present → `(field-type \| Nil)`; absent + closed → `Nil` (definitionally nil — *more* precise than today); non-literal key → union-of-fields ∪ Nil. |
| `expr-map-dissoc` (`:1619`) | Keyword lit → `R` minus the field (exact closed-row removal); non-literal → degrade to dictionary as in assoc. |
| `expr-map-size` (`:1626`) / `expr-map-has-key` (`:1634`) | `Nat` / `Bool` (unchanged types; add the `R` match arm). |
| `expr-map-keys` (`:1643`) / `expr-map-vals` (`:1651`) | `(List Keyword)` / `(List ⋃fields)` — both strictly better than today's `(List Open)`. |
| Union arm of map-get (`:1549-1568`) | Accept `expr-Record?` components alongside `expr-Map?`: project each per the rules above; union the results. (Do NOT copy the `with-speculative-rollback` shape into new code; see §8 risks.) |
| **check-subsumption** (`:2700-2706`) — NEW arm | `R <: (expr-Map K V)`: labels check against `K` (keywords); if `V` is an **unsolved meta** → solve `V := ⋃fields` (the uniform-bound view of a record is the JOIN of its fields — this keeps `def m := {:a 1}` usable where `(Map Keyword T)` is expected, replacing what seeded-Open absorption did, with a *more precise* answer); if `V` concrete → per-field check. **This is the annotation-satisfaction regression canary's mechanism.** |
| `qtt.rkt` co-edits | `map-get` (`:1213`) + `map-assoc` (`:1196-1205`): add `expr-Record`/record-seed handling by **delegating the type to `(infer ctx e)`** (the `:1215-1218` schema-arm pattern), keeping usage computation local. `expr-get` (`:1221-1227`) already delegates — free. |

What F1a does **not** touch: `unify.rkt:574-575` (Open wildcard — D7 relocation is F1a.2); `subtype-predicate.rkt` anything (no record-subtype judgment ever, D11; width is F1b erasure-mode); the two term-directed check arms (`:2429`, `:2433`); reduction/runtime (values stay CHAMP; types only).

### §4.4 `merge` / `deep-merge` (D10; F1a.2-era slice, designed now)

New **node-backed** operations (no legacy to fight — grounded: none exist): `expr-map-merge (m1 m2 deep?)` (exact node split TBD at its mini-design), value semantics right-priority overwrite, deep recursing iff both sides are maps. M1 typing: both sides `R`-ground → compute the result row exactly (right's fields + left's fields whose labels are absent on the right; deep: recurse where both field types are records — finite trees, terminating). Any side non-ground → dyn-tail result (F1a.2's representation). M3 (F-row): the node is where `Concat`/`DeepConcat` residuated constraints attach — 3-cell fundep-directional propagator in the ONE solver. WS surface (`merge`, `deep-merge` as parser keywords like `assoc`) specced at that slice's mini-design.

### §4.5 Open relocation plan (D7 — F1a.2, summarized here for phasing integrity)

F1a leaves every non-literal `Open` path byte-identical. F1a.2: (i) `'dyn` tail semantics go live — `(Map K V)`-annotation flows and dynamic-key degradations produce dyn-tailed records instead of `(Map _ Open)`; (ii) transcribe Sekiyama–Igarashi `C_ConsL`/`C_ConsR` absorption into the unify rules for dyn tails (reproducing `unify:574`'s annotation-satisfaction duty in its principled home); (iii) unknown-field projection on a dyn tail mints a fresh type meta + records the observation (monotone, existing constraint store); (iv) delete `expr-Open` (~38 sites across 11 files, enumerated in the grounding) and the F4 perf comment's "Open by Design" docstring, with the two-role history recorded. D1-b closes there.

### §4.6 WS impact (required section)

**No reader/parser/preparse changes in F1a.** `{:a 1}.a` already parses; only types change. The WS-visible surface is:

1. **Type display** (pretty-print): ground record → map-literal-shaped type, `{:a Int :b String}` (fields in canonical order); nested records nest (`{:a {:a1 Int}}`). Dyn tail (F1a.2) → `{:a Int | _}` (proposal — bikeshed at critique). `expr-Map` display unchanged (`[Map Keyword Int]`). *Consequence*: existing tests asserting `: Open` / `[Map Keyword Open]` displays change — Pre-0 censuses the churn (grep count), F1a-s4 fixes them.
2. **Diagnostics**: closed-row miss reads like a user error, e.g. `field :b is not present in {:a Int} — the literal's fields are :a` (exact wording at s2; must name the *available* fields).
3. **Not user-writable**: `{:a Int}` in type position stays a parse-time map literal (annotation surface deferred; `(Map K V)` and `schema` remain the annotation forms). Documented in the acceptance file.

### §4.7 Acceptance file (Phase 0 artifact — EXISTS as of Pre-0, baseline-green 26/26)

`racket/prologos/examples/2026-07-06-ciu-t6-f1-records.prologos`, `:no-prelude` (F4 perf lesson), self-verifying via `tools/run-file.rkt --check` (`;;N=>` markers; §7 item 6). Current expectations = pre-F1a baseline; each slice flips its `;;   F1a:` targets. Canaries:

```
def q := {:a 1}            ;; q : {:a Int}
q.a                        ;; 1 : Int          ← THE goal
+ q.a 1                    ;; 2 : Int          ← V5 (errors today)
def m := {:a {:a1 1} :b {:b1 11}}
m.a.a1                     ;; 1 : Int          ← nested (flips F4's "1 : Open")
def het := {:n 1 :s "x"}
het.n                      ;; 1 : Int          ← per-field beats uniform-join
het.s                      ;; "x" : String
;; het.z                   ;; closed-row miss — type error (assert message)
def am : (Map Keyword Int) := {:a 1}
am.a                       ;; 1 : Int          ← annotated path unchanged
def p : Point := {:x 1 :y 2}
p.x                        ;; 1 : Int          ← schema path unchanged
spec sum-vals (Map Keyword Int) -> Int         ;; + a body using map-vals
[sum-vals {:a 1 :b 2}]     ;; annotation-satisfaction canary: literal → (Map Keyword Int) via check;
def r := {:a 1 :b 2}
[sum-vals r]               ;; ← THE regression canary: inferred-Record-vs-Map-annotation (check-subsumption arm)
assoc q :b "hi"            ;; : {:a Int :b String} — exact extension
dissoc q :a                ;; : {} — exact removal
map-keys het               ;; : (List Keyword); map-vals het : (List <Int | String>)
```

Plus `tests/test-first-class-paths.rkt` assertion flips (`"1 : Open"` → `"1 : Int"` at lines 113/127 — the file's own NOTE anticipates this) and a WS test file for the new behaviors (shared fixture pattern, `:no-prelude`).

## §5 SRE lattice lens (6 questions) — the record description lattice

1. **Classification**: STRUCTURAL — a labeled product of per-field VALUE lattices (the flat type lattice), indexed by a support set (labels) plus a tail state. Components evolve independently.
2. **Algebraic properties**: per-field = the existing flat type lattice (join-semilattice + ⊤/⊥). Support = powerset lattice (Boolean) over labels. Tail = 3-point info order (`dyn ⊑ closed`, `dyn ⊑ ρ-bound`). Whole = a feature lattice (OSF-family): join = record-meet-under-orientation-flip (field union + per-field unify; clash ⇒ ⊤/contradiction). Commutative, associative, idempotent — CALM-safe when it becomes a cell merge (F-row). **Unverified precondition (flagged, §8)**: per-field meets distributing over our binary normalized unions — check before claiming distributivity anywhere.
3. **Bridges**: (a) per-field ↔ flat type lattice — componentwise, trivially Galois. (b) record ↔ `(Map K V)` — the uniform-bound abstraction α(R) = `(Map Keyword ⋃fields)`; γ = "any record whose fields all fit V". The §4.3 check-subsumption arm IS this α — stated as a Galois connection, not ad-hoc. (c) record ↔ schema — up-shift (schema entries embed into the description lattice) is an embedding; seal is a *checked* partial inverse with residual (F1b), NOT a lattice morphism — polarity boundary, per D11/MLstruct nominality discipline.
4. **Composition**: fields compose with unions (field types may be unions — build-union-type already normalized); records nest (field type may itself be a record) — the lattice is the least fixpoint of the labeled-product functor over the flat lattice; no cycles in F1a (ground literals are finite trees).
5. **Primary vs derived**: a literal's ground row = PRIMARY (from syntax). The `(Map Keyword ⋃fields)` view = DERIVED (α). Schema registry = PRIMARY for nominal types. A sealed value's type (F1b) = schema name + possibly residual observed refinements (derived from both).
6. **Hasse diagram**: nodes = (support, per-field assignments, tail); edges = single-fact refinements (add a label / refine one field / close the tail). The per-field independence means the diagram factors as a product — which IS the parallel decomposition: per-field components map directly onto compound-cell components when rows become cells (F-row), and the set-latch/broadcast patterns apply per-label. F1a consumes this only as documentation; F-row consumes it operationally.

## §6 Principles gate (challenge column included) + subtyping/NTT notes

| Decision | Serves | Challenge (could it be MORE aligned?) |
|---|---|---|
| Row-shaped carrier w/ tail (D6) | Data Orientation; Correct-by-Construction (fields only from syntax) | More aligned would be rows-as-cells NOW — rejected: new-meta-domain co-migration cost is documented and F1a needs zero inference beyond existing metas. Forward-compat obligations (§4.1, ordinary type metas; sorted canonical form) are the honest bridge. |
| Records vs dictionaries split (§4.1) | Decomplection (two concepts, two types) | Risk: is the keyword-literal test too syntactic? Challenged: it mirrors TS's fresh-literal treatment and Typed Clojure's complete-HMap literals — the *literal* is the one place the field set is a fact, not an inference. |
| Degrade-to-dictionary on dynamic keys (§4.3) | Honest scoping; behavior preservation | Red-flag check: is `(expr-Map k (expr-Open))` here "keeping the old path"? It IS the old path — F1a's scope boundary, with D7's relocation scheduled (F1a.2). Named, dated, planned — passes the scaffolding gate. |
| Union-join for meta `V` in Record<:Map (§4.3) | Most Generalizable Interface (α as Galois) | More aligned than Open-absorption (today) AND than per-field-unify (would reject heterogeneous records). It's the principled abstraction — and strictly more precise than the status quo. |
| No record-subtype judgment (D11) | Decomplection; compositional safety | The fragile global relation is never built; the two subsumption uses (Record<:Map now, width at F1b) are local check arms / erasure-mode discharge. Challenged against "just extend subtype?": rejected — `compound-type?`/positional-ctor-desc would demand a label-keyed engine variant F1a doesn't need. |
| qtt via delegation (§4.3) | Single source of truth for types | More aligned than replicating logic inline (the current `:1213` shape is the divergence bug class). |

**NTT-relevance (mandatory note)**: F1a adds **zero propagators and zero cells** — it is value-type-lattice representation work inside the existing imperative `infer`/`check` (same on/off-network status as all of typing-core; bringing typing on-network is PPN's turf). The Network Reality Check therefore honestly returns "function-call chain" — *and that is the correct answer for this layer*. The NTT-model obligation attaches at **F-row** (rows-as-cells, `Concat` as 3-cell propagator, set-latch per-label obligations, non-monotone residue at strata) — that design doc MUST carry the full NTT model; this one carries the forward-compat obligations (§4.1, §4.3) that keep F-row's path clear.

## §7 Pre-0 — RESULTS (2026-07-06, executed at HEAD `ead54e27`; feeds D.2)

1. **Serializer probe ✅ RESOLVED — `record-field` struct is SAFE.** `deep-s->v` (pnet-serialize.rkt:91-118) is a *generic recursive walk*: any `struct?` → `struct->vector` with recursive elements; pairs/lists/hashes recursive. Deserialization needs only the tag registered (`regN!`). Empirical round-trip of `(list (cons 'a (expr-Int)) …)` → `equal? #t`. Production precedent for list fields: `expr-path (branches)` (syntax.rkt:673). **Decision: primary proposal stands** — `record-field` struct + `expr-Record` each get a `reg2!`; the pairs fallback is unnecessary. (The F2 vector-impostor mode = forgetting EITHER registration.)
2. **Field-rep micro ✅ — representation is NOT perf-driven.** Lookups <0.05µs both reps at n≤16; extension: assoc cons+sort 0.2µs (n=4) / 0.9µs (n=16) vs hasheq ~0.1µs — all 3+ orders below per-form typing cost (~ms). **Sorted-assoc stands on determinism grounds** (serialization, display, `equal?`); implementation note: canonicalize ONCE at literal completion, not per-extension.
3. **Display-churn census ✅ — SMALL.** `: Open` assertions: 5 hits in 3 test files (`test-schema-properties`, `test-first-class-paths`, `test-mixed-map`); `Map Keyword Open`: 5 hits (`test-path-expressions`, `test-mixed-map`). s4 budget: ~10 assertion flips across 4 files.
4. **Baseline timing ✅.** Instrument = the acceptance file itself (26 forms, map-literal-heavy): elaborate 16ms / type_check 36-37ms / qtt 6ms / zonk 21-22ms / reduce 44-45ms (3 runs, tight). Post-F1a re-run compares like-for-like. Suite baseline: GREEN 8530/448/0 at `35b3bc90` (docs-only commits since).
5. **Acceptance file ✅ LIVE + WS wiring verified through-and-through** (`examples/2026-07-06-ciu-t6-f1-records.prologos`): all §4.7 surfaces run at Level 3 (`process-file`, `:no-prelude`) — literals, projection, annotated, schema, spec/defn annotation-satisfaction (canary 16 = today's Open-absorption, confirmed live), `map-assoc`/`map-dissoc`/`map-keys`/`map-vals`/`map-size`/`map-has-key?`/`nil-safe-get`/`get-in`+`#p`. **Wiring finding**: the WS surfaces are the `map-`-prefixed parser keywords; bare `assoc`/`dissoc` ergonomic aliases do NOT exist (out of F1a scope; noted for the track's ergonomics backlog).
6. **NEW: `.prologos`-level regression testing (owner-flagged gap) — minimal closer shipped.** `tools/run-file.rkt --check` verifies `;;N=>` (exact) / `;;N=>~` (contains) expectation markers keyed to run-file's own result indices (authoring loop: run → copy numbered outputs → `--check`). The acceptance file carries **26 expectations, 26 passing** at the pre-F1a baseline — each F1a slice flips its marked lines (F1a targets sit on adjacent `;;   F1a:` comments). Exit code 1 on mismatch → suite-integrable via a thin `tests/` wrapper (s4).

## §8 Risks and open items (for the critique rounds)

- ~~pnet-serialize nested-struct support~~ — **RESOLVED (Pre-0 #1)**: generic walk verified + empirical round-trip; struct shape confirmed.
- **Distributivity precondition unverified**: per-field meet over binary normalized unions (SRE Q2) — check before any doc claims it.
- **Union-arm inconsistency inherited**: `typing-core:1549-1568` still uses `with-speculative-rollback`+`build-union-type` — the mechanisms the `:1459` comment says were retired. F1a extends this arm minimally (accept Record components) but must NOT copy the shape into new arms; excise-or-defer decision belongs to the critique round.
- **Heterogeneous projections become precise**: code that today silently flows `Open` into arithmetic may now surface real type errors (strictly more sound; suite + acceptance will quantify).
- **Display churn** could be larger than expected (Pre-0 #3); s4 budgets it.
- **`{}` stays legacy in F1a** — the empty-literal record reading waits for dyn tails; assert the `{}`-annotation canary (`typing-core:2424`) stays green.
- **Perf**: per-literal record construction + canonical sorting (n small; Pre-0 #4 guards).
- Open for critique: exact `record-field` vs pairs; dynamic-key projection = union-of-fields vs error; dyn-tail display; whether F1a-s3's `map-keys`/`map-vals` precision upgrades belong in s2 instead.

## §9 Deferred (explicit)

dyn tails + Open deletion (F1a.2); width subsumption, rank≤2/weak-preservation documentation, seal + residual + `closed?` scan (F1b); `merge`/`deep-merge` nodes + M1 (F1a.2-era slice, §4.4); ρ/`Concat`/`DeepConcat`/ambiguity check (F-row; UCS-5 + SRE-5 junctions); variants (F-variant); presence marks beyond `'present` (with the schema optional-keys design); user-writable record-type annotations; V2–V4 selection syntax (track doc).
