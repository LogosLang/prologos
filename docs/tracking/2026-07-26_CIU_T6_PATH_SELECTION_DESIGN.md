# CIU Track 6 — Path Selection (Stage-3 Design, **D.2**)

**Status**: **Stage-3 D.2 — the SURFACE IS SETTLED** (five co-design rounds, owner-ruled
2026-07-26; consolidated spec = **§5.9 PS1–PS15**; §5.1–§5.8 remain as the conversation
record). Implementation opens at P0 (acceptance file) per §2.
**Series / Track**: CIU Series → **Track 6** (Anonymous Records & Collections & Path Selection).
**Date opened**: 2026-07-26 · **Owner**: Zee Larson
**Predecessor**: [`2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md`](2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md)
(Stage 0/1 track doc — owner vision §2, locked decisions §2a D1–D29). That doc remains the
home of the RECORD-typing decisions; this doc is the SELECTION design.
**Substrate**: F1a ✅ · F1a-col ✅ · F1a.2 ✅ · F1b ✅ ([PIR](2026-07-19_CIU_T6_F1B_PIR.md)) ·
Rel T1 ✅ ([PIR](2026-07-25_REL_T1_PIR.md), typed solution rows).
**Grounded at HEAD** `fe03b493` (audit `wf_a62d4b88-47b`, 6 facets + completeness critic;
prior-art survey `wf_c1acb1c7-ce1`, 33 systems). Every §3 claim marked ✔ was
R-lens-verified in the main session; ⊙ = audit-reported, not yet main-session-verified.

---

## §1 Intent (owner, 2026-07-26)

> The main insight and intent: **records and arrays/vectors are the same associative
> data structure at a higher level of abstraction; nested collections of such are
> TREES; and there is a desire, often, in programming, to select out subtrees of such
> a structure.** Current practice has us rebuild that structure one sub-piece at a
> time, line-by-line. The goal with Path Selection is **an ergonomic, single-line
> syntax that can select out any arbitrary subtree or leaves of the structure.**

Two consequences that shape everything below:

1. **The unit of selection is a SUBTREE, not a field.** A field is the degenerate
   subtree, exactly as an index is the degenerate path. This is the same
   generalization twice, and it has a formal precedent: Morris & McKinna (POPL'19)
   *define* single-field access as subset-projection composed with singleton
   destruction (`sel = λ r l. prj r/l`) — **set-projection is primitive, one-field
   access is derived**, with principal types. Our `v[0]`-as-degenerate-case is not an
   intuition; it is a published factoring.
2. **The output is a REBUILD.** Selection does not merely read — it constructs a new
   tree whose shape the user is choosing. That is why result shape (V4) is the crux
   and not an afterthought, and it is why the prior art's unanimous verdict is
   *"ship the construction/rename form in the same design round"* (§4).

**Non-goal (v1)**: this is a READ surface. The write direction (`update-in`'s
successor) is designed-for but phased — see §9.

---

## §2 Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| G | Grounding audit + prior-art survey | ✅ | audit `wf_a62d4b88-47b`; prior art `wf_c1acb1c7-ce1`; §3/§4 |
| S | **Surface co-design (OWNER CONVERSATION)** | ✅ | **SETTLED 2026-07-26** — five rounds (§5.4–§5.8), consolidated as **§5.9 PS1–PS15** |
| P0 | **Acceptance file** (`examples/2026-07-26-ciu-t6-path-selection.prologos`) — IDEAL Prologos syntax throughout [owner]; not-yet-working forms COMMENTED until their phase lands; `--check` gated from day one (the Rel T1 Batch-A lesson). Charter [owner, round 6b]: the `app-config` nested record · **broadcast over PVecs of same-shaped records** · **solve result sets** · **typing pins throughout** (markers carry types) · **function-typed forms** (D3-S11: named-schema + keyword-projection consumers) · **the standalone-def seam family pinned** (`def add5 := [+ 5 _]` et al., commented + the working argument/annotated forms as markers). **At X.close the file PROMOTES to a suite-gated regression test** (the F1 `test-*-acceptance.rkt` clone pattern) | ✅ | `--check` 21/21, 0 errors @ P0 landing; §A–§G: guild-hall config · party PVec · quest-board solve rows · the add5 family · typing pins | workflow.md § "Acceptance file as Phase 0". Spans predicate FAMILIES of forms, not one idiom (the 7a lesson) |
| P1 | **`.{` retirement, WS leg (D3-S5 split)**: repair the 4 audit files' mixfix `.{X}`→`.(X)` · **DELETE the recognizer + the `$mixfix-retired` error entirely** (owner: retire from code AND diagnostics) | ✅ | `d18648f0` — recognizer + both grouping arms + error path + dead mixfix-rbrace closer legs all deleted; audit-06/-08/-09 → 0 errors, audit-12 runs (3 pre-existing quote-section errors unmasked); `<`-in-`.( )` mis-extension found + spawned as its own task (capability loss on 2 audit lines NAMED, converted to `lt`/`le`); suite 9150/471/0 | **Owner-RULED (Q_P5 + round 6)**. The SEXP brace-select leg is NOT here — it sequences WITH P4 (tests re-pointed, never deleted) |
| P2 | Prerequisite defect repairs, SPLIT at the mini-audit (`wf_2c99bc25-940`): **P2.a ✅ `ad75e57a`** — record-project Int gate (+ the pvec-nth discipline guard the audit found: widening alone would have silently flipped the Nat-only discipline, suite-invisible) · ground-expr? twins → generic transparent-struct fallback (`expr-substructs-all?` in syntax.rkt; union-of-metas defect closed; mult/level-meta posture ruled+pinned) · normalize-for-resolution union descent (the upstream capture gap) · broadcast-get whnf arm + definitely-not-map? exemption (minimal scope; bare-meta typing = P5). 14 tests failing-first; suite 9164/472/0. **P2.b 🔄 RULED (c) — the TWO-TIER PRINCIPLE (owner, round 7), REALIZATION CORRECTED at the mini-audit (`wf_c89b3532-8a7`, round 8 — 3 premises refuted, all main-session re-probed)**. The principle stands; the mechanism is now the **CARRIED-ALPHA slot** (elaboration mints a fresh meta → type-check solves it from the subject's row → zonk materializes it), NOT an "elaboration-time mark" (elaborate has no typing env). Scope, as ruled round 8: Map-miss (dyn residue only — closed rows are ALREADY loud, with a better diagnostic than a panic can give) · `pvec-nth` OOB · `expr-get` PVec **:2706** + List **:2717** OOB · **the DEF SEAM** (Q_N5 — `driver.rkt:1907` has NO panic check; P2.b is unobservable without it) · **SITE 7** (Q_N6 — `[map-get tup <nat>]` on a PRESENT position fabricates `none`; `definitely-not-map?` has no `expr-rrb?` arm; prefer the STRUCTURAL default over a sixth exemption). SPLIT OUT (Q_N7, each named): `pvec-update`/`tvec-update!` (write-shaped + an incoherent `Indexed` instance) · `pvec-pop`-on-empty (partial-on-empty) · `pvec-slice` (silent clamp → §3.7's class). **SLICES: (1) site 7 ✅ `88d1f746`** — `definitely-not-map?` polarity INVERTED to a positive list (default now conservative-stuck, so the list cannot silently rot) + an `expr-map-get`-on-`expr-rrb` arm DELEGATING to `expr-get` (closes the divergence by construction); +8 tests, suite 9226/474/0 · **(2) ✅ `b8f7cc27` (round 8b: NO slot needed)** — both rrb arms → one panic shape (index+length in the message; the divergent stuck leg unified; with-handlers REMOVED, not doubled) + BOTH def seams count a top-node panic (`def-panic-error`, the seal-forcing template; annotated path un-registers) + the A9 deliberate dynamic-tuple flip pinned + B8 pins the nested-panic bound; +8 tests (30 total), suite 9229/474/ALL PASS, 3-skeptic adversarial verify refuted=false · **(3) ✅ `d4f4b80f` the List-leg SPLIT** — non-literal index stays STUCK (fixes the live nf-display bug: a stored lambda body over `[get xs i]` was displayed as `<error>` while the whnf-stored value was intact — the slice-2 audit's "body destroyed" claim refined to display-only); true OOB → the same panic shape ("index 5 out of bounds for List of length 3"); +4 tests incl. a PRELUDE-BACKED second fixture (under `:no-prelude` the `List` TYPE doesn't exist → three first-draft tests FALSE-GREENED on error-struct noise, one on digits in the TEMP PATH — 3rd/4th wrong-reason instances; a fixture-sanity guard is now structural); suite 9233/474/ALL PASS · **(4) ✅ `ac89341f` the Map-miss fork — CARRIED-ALPHA LANDED; P2.b's behavioral surface COMPLETE.** Mint (2 user sites, kind `'strictness-slot`) → solve (`solve-strict-assert!`, the `(expr-Map)` legs ONLY, both nodes) → zonk materializes → the champ-miss arm panics naming key + available keys. Slot rides both cross-delegations; qtt Map leg delegates (R8); pnet: both nodes on loud `regN!` (map-get OUT of auto-cache!'s swallow), `PNET_VERSION` 6; `expr-get?` added to `expr?` (C25); oracle battery +1 poison position. +5 tests (39 total; B9 pins the TIER BOUNDARY: get-in miss permissive); break set ZERO (the 2 test-map pins now PIN the permissive default). Suite 9238/474/ALL PASS · 4-skeptic verify, ~25 probes, no live defect — incl. kv-get round-tripping `.pnet` with a SOLVED slot while its guard still yields `(none)` (guard-awareness proven in serialized stdlib). NAMED residuals: conv-equality (unsolved-slot meta ids differ across elaborations; unconstructible today, the num-lit-alpha precedent) · the tier boundary sits at the INFERRED TYPE (a `[map-empty K V]` chain is Map ⇒ loud even unannotated; `{}` chains are the dyn-row permissive class) | ✅ **P2 COMPLETE** (P2.a `ad75e57a` · site 7 `88d1f746` · slice 2 `b8f7cc27` · slice 3 `d4f4b80f` · slice 4 `ac89341f`) | Failing-test-first is MANDATORY, not optional: **5 of the 6 sites have ZERO coverage in either direction** (every in-tree OOB pin is a closed tuple erroring at ELABORATION), so the flip is suite-invisible both ways. Break set is literally 2 pins (`test-map.rkt:126`, `:141`). Doc-truth rider: the map-tutorial TEACHES error-on-miss **4×** (:103 :143 :246 :498) — (c) makes it true; a FIFTH site (`syntax.rkt:812`) points the opposite way and is corrected in this phase |
| P3 | Reader/lexer (WS-Impact MANDATORY; both-modes census; **ground on the TOKEN-REGISTRY inventory, priorities 92/88/87/86 — D3-S6**): `.N` segments (anchor at the DOT; numerics anchor at a DIGIT — CH-4 ruled) · `.:.`/`.:[` iteration · `*` splat/`[*]` · dot-key retirement (`.:name`→`.name`, **+ the `$nil-dot-key` twin `#.:name`**) · `.*name`→`.:.name` migration · **`m[:a]` RETIRES (error + hint; no flip — D3-S4)** · `x[]`/`_[sel]`/**`.-1`** rejections with real diagnostics · selector **round-trip printing pins** (D3-M6) · the sexp special form (PS14) | ⬜ | Censuses per D3-M7: dot-key 8+11 sites, `.*name` 7+4, `m[:kw]` 17+8, `v[literal]` 49+45 / 48 test-cases. **Sections tokens are GONE from this phase** (B2 → keyword-projection needs none) |
| P4 | The selection NODE + elaboration + static typing (PS3–PS8 as amended §5.10): core-elaborator form (NOT preparse, §4.10) · contributions keying/assembly/collision/miss · rows out (§3.2 narrowed: keyword result type) · **P4.a the nat-keyed assembly path + PS4 renumbering** · **P4.b the closed-vs-dyn seed pin (PS15=CLOSED, test-pinned)** · **P4.c the sexp special form + re-pointing the 20 brace-select tests (D3-S5)** · **P4.d `v.i` neutral-segment + soft resolution (D3-S1; cuttable)** · full pipeline incl. **item 13: deliberate `#f` registration in typing-propagators (D3-M2)** | ⬜ | The heart. Tests per-phase; probe-first; Exhaustive-Walker discipline, generic fallback |
| PX | **The binder-seam phase (owner-ruled in-track; WIDENED round 6b)**: (a) the D3-S10 concrete-codomain lambda-adoption hole — `[the [List String] [map [fn [x] x] ints]]` accepts silently; fix = decomplect evidence/obligation at binder positions (`:expected` facet; lam `:type` written only from the body; disagreement → top → existing refusal). (b) **the standalone-def seam** — `def f := [fn …]` / `def add5 := [int+ 5 _]` fail even when the body DETERMINES the types; body-directed inference for the monomorphic + row-lambda cases; the trait-op case (`[+ 5 _]`) honest residue (may need defaulting/residuation → Num T2/F-row; annotated-only fallback) | ⬜ | Position flexible; failing-test-first. §3.7's `map-size` class stays filed separately |
| P5 | Iteration `:` + first-class selectors (PS1/PS11 as amended): `.:.`/`.:[` both key domains, **result carrier = source collection kind preserved (D3-S4)** · **keyword-projection coercion `map :name users` + qtt twin (+ the `[:kw m]` head arm)** · explicit lambdas as multi-select selector values · empty-prefix column extraction | ⬜ | v1 adds ZERO propagators (Network Reality Check stated in advance); the broadcast-propagator node is a FUTURE upgrade with its own NTT model |
| P6 | Migration + supersession (§9 + PS12/PS13 as amended): `#p(…)`/`get-in`/`update-in` = the dynamic tier (kept; **Path applicability → DEFERRED entry, D3-M3**) · `selection`'s three gaps revisited · **CIU master: T2 items 2+4 superseded, 1+3 re-homed; T3 RE-CHARTERED (D3-S9)** · DEFERRED triage | ⬜ | §9's write-phase note: source-overlap disjointness is the WRITE headline (D3-S7) |
| X.close | **MANDATORY** — bench matrix (feature microbench + E2E per testing.md) · DEFERRED triage · doc-truth sweep · memory fold · **Stage-5 PIR** | ⬜ | The track does not flip ✅ until the PIR lands |

*Per `workflow.md`: tests are PER-PHASE, never a dedicated end-of-track test phase.
A behavioural phase shipping +0 tests is INCOMPLETE.*

---

## §3 Grounded code facts (HEAD `fe03b493`)

### §3.1 The source side is DONE — and it is excellent ✔

The owner's own example record elaborates today with a fully precise nested row type,
three levels deep, including YAML-style list-of-records:

```
def app-config
  :name "MyApp"
  :server
    :host "localhost"
    :ssl
      :enabled true
  :features @[:auth :logging :caching]
  :admins
    - :name "Alice"
      :role :super
```
→ `{:admins [PVec {:name String :role Keyword}] :features [PVec Keyword] :name String
    :server {:host String :ssl {:enabled Bool}} …}` — and `app-config.server.ssl.enabled`
→ `true : Bool`. **0 errors.** The tree is fully typed and closed at every level. What is
missing is exactly and only the selection surface.

### §3.2 ⭐ V4 IS NOT A BLANK SLATE — the feature exists and is test-pinned to the WRONG type ✔

Brace multi-select `(get-in nested :a.{x y})` **works today in sexp mode**
(⊙ `sexp-readtable.rkt:564` registers `{` as a terminating macro emitting `$brace-params`;
dead only in WS). 20/20 tests pass in `tests/test-path-expressions.rkt`. But:

- The result types as **`[Map Keyword Nat]` — WIDTH-ERASED, not a row.**
- `tests/test-path-expressions.rkt:193-198` asserts `(string-contains? … "Map")` —
  **the degraded type is pinned by the suite.**
- `tests/test-path-expressions.rkt:101` concedes the limit in a comment:
  `;; Shared preamble: homogeneous maps (avoid Peano union type issues)`.
- Heterogeneous selections **fail outright** ("Could not infer type").

**Root cause is one local seed choice.** `elaborator.rkt:2301-2316` builds the multi-path
result by seeding `(expr-map-empty km vm)` with two `fresh-meta`s, so it lands on
`typing-core.rkt:1807`'s `(expr-Map k v)` arm instead of `:1806`'s row arm
`[(expr-map-empty _ (? expr-Record? rec)) rec]` — whose own comment reads *"The ONLY source
of a map-empty with an expr-Record v-type is the all-keyword literal seed."*

**⇒ V4 is a RETYPE of a shipped feature, one seed away from structural rows.** The design
supersedes an existing semantics rather than filling a void.

### §3.3 The predecessor's own V4 lever is REFUTED by shipped code ✔

The Stage-0 doc §3 proposed *"`{a.b}` flattens, `{a.{b}}` preserves one level — the
selector's shape IS the result's shape."* Probed: `(get-in n :v.{id loc.{nm}})` →
`{:nm 2N, :id 1N}` — **flat, `:loc` erased**. `expand-brace-branches` flattens nested braces
into sibling paths before `elaborator.rkt:2312`'s `(last path)` keys the result by the
LAST segment. The mirror principle's most concrete mechanism has already been tried here
and did not survive contact.

### §3.4 The READER already does most of the §5.3 work ✔

Verified reader output at HEAD (raw datum, WS mode):

| Source | Reads as | Status |
|---|---|---|
| `x[a b c]` | `(x ($postfix-index (a b c)))` | ✅ multi-select free |
| `x[a^b]` / `x[a^]` | `($postfix-index a^b)` / `($postfix-index a^)` | ✅ **`^` glues into ONE symbol** — split at the parser |
| `x[a[b c]]` | `($postfix-index (a ($postfix-index (b c))))` | ✅ nested-bracket free |
| `x[1.b]` | `($postfix-index (1 ($dot-access b)))` | ✅ **nat→field works** |
| `x[a.b]` | `($postfix-index (a ($dot-access b)))` | ✅ field→field works |
| `x.[a]` | `(x \|.\| ($postfix-index a))` | ~ available; bare-`.` + bracket, **needs a token** |
| **`x.1` / `x[a.1]`** | **`(x \|.\| 1)` — a BARE `.` SYMBOL** | ❌ **field→nat MIS-LEXES** |
| **`x.1.2`** | **`(x \|.\| ($decimal-literal 6/5))`** | ❌ **nat→nat becomes a RATIONAL** |

**The asymmetry is load-bearing for §5**: `recognize-dot-access` requires `ident-start?`
after the dot and explicitly excludes numeric continuation, while
`recognize-decimal-literal` needs digits on *both* sides. So the reader today supports
**exactly one direction** of mixed keyword/positional paths. Every `.N` form in the owner's
draft (`features.1`, `admins.0.name`, `admins.0[…]`) is currently mis-lexed.

**And `v[1.b]` failing is NOT a reader problem.** ⊙ `macros.rkt:2488-2495` re-entrantly
preparses the `$postfix-index` payload, so `rewrite-dot-access` folds `(1 ($dot-access b))`
into `(map-get 1 :b)`, yielding `(get v (map-get 1 :b))`. **The lift is one fold arm plus
stopping that re-entrancy.** ⊙ The adjacency test (`parse-reader.rkt:2471-2479`) is purely
POSITIONAL (`end-pos == start-pos`), not token-kind-based — it already fires after every
literal form and **in binder position** (`defn f[x] x` → `(defn f ($postfix-index x) x)`).

⚠ **`^` reuse note**: `^` gluing into the identifier is the same shape POL.6 already solved
for `x:Int` — `split-fused-symbol` / `fused-type-annot?` / `fused-annot->type-surf`
(Rel T1). **The pattern exists; do not write a second splitter** (the `recognize-keyword`
drift class, `prologos-syntax.md` § Reader).

### §3.5 Prerequisite defects — the degenerate case is non-uniform ✔

| Subject | Form | Behaviour |
|---|---|---|
| PVec | `pv[i]` (Int var) | ✅ works |
| PVec | `pv[5]` out-of-bounds | ⚠ **`<error> : Int`, SILENTLY — 0 errors reported** |
| Tuple | `tup[1]` literal | ✅ exact per-position type |
| Tuple | `tup[5]` literal OOB | ✅ static error |
| Tuple | `tup[n]` (Nat var) | ~ degrades to ⋃positions |
| Tuple | `tup[i]` (**Int** var) | ❌ **ERROR — a defect** |

The last is a real divergence: `typing-core.rkt:558-562` (literal leg) accepts Nat-or-Int
with the comment *"mirroring expr-get's PVec Nat-or-Int gate"*, while `:563-566` (dynamic
leg) sets `key-ty = (expr-Nat)` only. **`def i := 1` is Int by our own convention**
(`prologos-syntax.md` § Nat vs Int), so the most natural dynamic tuple index fails.

**Miss semantics are already FOUR-way inconsistent**, and any selection surface inherits
all four unless §5 rules: PVec OOB → silent `<error>` value · tuple OOB → static error ·
closed-row keyword miss → rich diagnostic naming available fields
(`typing-errors.rkt:132-140`) · dyn-row miss → fresh meta (D19). Meanwhile the traits a
unified surface would dispatch through return `Option`.

### §3.6 Walker gaps we would build on ✔

Per `pipeline.md` § "Exhaustive Walkers" (7+ silent in-tree instances):

- **`expr-broadcast-get` occurs exactly twice in all of `reduction.rkt`** (`:4133`, `:4178`),
  both in the `nf` family — **no whnf arm** — and it is **absent from
  `definitely-not-map?`**, where its two path siblings `expr-get-in?` / `expr-update-in?`
  sit with explicit comments added by the 2026-07-16 value-loss fix. A broadcast surface
  built on this node inherits a live silent-class gap.
- **`ground-expr?` at `global-constraints.rkt:154-170`** is 14 arms then `[_ #t]`, with **no
  `expr-meta` arm at all** — so every path node, `expr-Record`, and union reports GROUND.
  Its same-named twin at `trait-resolution.rkt:54` IS meta-aware. Two functions, one name,
  divergent completeness. *(Call sites not yet audited — flagged, not yet called a live bug.)*

### §3.7 Adjacent soundness defect (separable, file it) ✔

`[map-size 5] : Nat` and `[map-size "hello"] : Nat`, **both with 0 errors**.
`typing-propagators.rkt:2372` registers `map-size` with a *constant* return `(expr-Nat)` —
the subject is never checked — and `driver.rkt:1786-1791` runs on-network first, so the
constant rule wins before typing-core's arm. `map-has-key` (`:2371`, `(expr-Bool)`) is the
same shape.

This **empirically settles** DEFERRED's open selection question: `[map-size v]` on a
`selection … :requires [:name]` over a two-field value returns `2N` — full parent width —
while `v.age` errors statically. Current behaviour is **INCONSISTENT, not "strict"**.

### §3.8 `.{` is a live regression, not a clean retirement ✔

`.{` has **live, uncommented users as LEADING mixfix** in four shipped audit examples
(audit-06: 7 lines · audit-09: 5 · audit-12: 5 · audit-08: 4), plus owner-WIP
`examples/today.prologos:19`. ⊙ `macros.rkt:6145-6147` raises a raw Racket `error`, so
**`audit-09-numerics.prologos` aborts fatally — zero output, not even commands before the
offending line.** Verified by running it. The audit examples are a diagnostic instrument
and are currently unrunnable.

### §3.9 Stale predecessor items to strike ✔

- Track-doc `:178` item 3 (*"`^` rename broken in WS-file mode"*) is **FIXED** —
  `ident-continue?` includes `#\^` and F1b.7g's rewrite preserved it. Strike, don't re-litigate.
- F2's 5-node `pnet-serialize` registration **survives** at HEAD.
- The predecessor's §4a coordinates are stale by ~8–400 lines throughout; §3 above supersedes them.

---

## §4 Prior art — the rulings it actually supports

Survey: 33 systems across 5 families (`wf_c1acb1c7-ce1`), tool-verified where possible
(jq 1.8.1 and the Python JMESPath reference were **run**, not recalled).

1. **Result shape must be dispatched by the selector's KIND, never its ARITY.** λ⟨⟩
   (TyDe'23) is the only worked-out typed answer: `r.foo : τ` (label → leaf) vs
   `r • ⟨foo⟩ : {foo:τ}` (singleton ROW → one-field record), with `⟨foo⟩` syntactically
   distinct from `foo`. R and JSONPath let arity/punctuation decide and are the canonical
   disasters — whether JSONPath's single match returns `42` or `[42]` is the
   **most-diverged decision in 40+ implementations**, with one author's own two
   implementations disagreeing.
2. **The mirror principle ships (GraphQL, Datomic Pull) but has NEVER been sufficient
   alone.** Both had to bolt on: rename (Datomic shipped Pull 2014, `:as` **Dec 2017**), a
   static key-collision rule (GraphQL `FieldsInSetCanMerge`), a key-order rule, and
   (Pathom 3) **synthetic nesting for shapes the source lacks**. Adopt it *with* those four
   or not at all. It also cannot say *"give me this whole subtree"* — GraphQL's leaf rule
   forces spelling every leaf, which is where the verbosity and fragments come from.
3. **EQL's spec concedes the mirror's hole in one sentence** — *"with just EQL you can't
   know if a key value is expected to be a single item or a sequence"* — **and that is
   exactly the hole our row types close.** Strongest single argument for us in the survey.
4. **Broadcast must be EXPLICIT, and the reason is structural.** Type-directed implicit
   broadcast works only where the type system distinguishes collection from record;
   unifying Array and Map as rows **deletes that discriminator**. Array⇄Map unification and
   implicit auto-broadcast are in direct tension — forced, not stylistic.
5. **⚠ `coll.[…]` is contested, unclaimed territory.** `A.[i]` is a **syntax error in Julia
   today**; issue #19169 has been open since **Oct 2016** (verified open 2026-07-26) on
   exactly which position the dot distributes over — and the syntactic-analogy argument
   yields the reading we probably don't want. We are not adopting a resolved design.
6. **Make the marker BUY something.** Julia's dot buys a *syntactic* loop-fusion guarantee.
   Our honest analogue: **a dotted selection is ONE broadcast propagator, one fire, one
   merge — guaranteed, not optimized-into** (`net-add-broadcast-propagator`, measured
   2.3× at N=3 / 75.6× at N=100). Where a marker buys only disambiguation, users file it
   as a papercut.
7. **Unify the KEY DOMAIN; do NOT unify the RESULT-SHAPE decision into the same bracket.**
   R's `[` vs `[[` is *not* a caution against one bracket for two key types — it is one
   bracket with two-to-four *result shapes*. Ur/Web has run nat-keyed-tuples-as-rows for
   two decades. Consequence to state deliberately: **`v[0]` means "the field LABELLED 0",
   not "the FIRST field"** — slices/ranges/negative indices do not come free, and λ⟨⟩
   states that integer selectors over unordered rows are *inexpressible*. We escape only
   because our nat keys are labels IN the row.
8. **Closed-row miss = TYPE ERROR, and the trend runs our way.** Every omit/silent-null
   behaviour comes from an untyped language and they are all walking it back: Pathom 3
   throws by default; **Clojure 1.13 (2026-07-02) added `:keys!` after 18 years of silent
   nil**; Dhall — the one typed total member — errors unconditionally.
9. **Two candidates we had not listed.** *(a)* **Selector-is-a-type** (Dhall
   `r.({x : Double})`) — result type is not inferred, it *is* the selector. ⚠ Dhall #771
   proposed exactly our nested version and **dropped it** ("couldn't be implemented via
   desugaring"), verified open. *(b)* **Clojure 1.13 `:select`** — ONE selector yielding
   BOTH flat leaf bindings AND a shape-preserved subset row, chosen by an **orthogonal
   request**; documented rationale *open input, closed output row*.
10. **⚠ WHERE THE RISK ACTUALLY IS: typed deep multi-select with a result shape DOES NOT
    EXIST.** Every row system is flat (ROSE, Rω, λ⟨⟩, PureScript, Ur/Web); every mirror
    system is deep but untyped with no path syntax and no flatten (GraphQL, Pull, EQL);
    every deep-path system is untyped (jq, JMESPath, Specter, q, Clojure). **Five typed /
    config design teams declined to build it.** ⇒ the selection form belongs in the **core
    elaborator, not a preparse rewrite**, and there is **no principal-typing result to lean
    on** — say so rather than assuming the row literature covers it.
11. **Our un-precedented asset.** λ⟨⟩: *"there is no direct way to say 'a record r lacks a
    label l'."* TypeScript's `Omit` is unsound in its key parameter for the same reason.
    **Our 3-state tail + per-field presence marks buy exactly that negative information**,
    which is what makes omit-selectors, "these and only these", and **static disjointness
    checking** typable. Multi-select overlap is the field's worst wart — Haskell quarantines
    it in `Control.Lens.Unsound`, Racket documents it unenforced, Monocle's request closed
    with nothing shipped. **Nobody checks it. We can.**
12. **REFUSE list (evidence-backed)**: arity-dispatched shape · result type encoded in the
    operator's spelling (`->`/`->>`, `[`/`[[`) · implicit broadcast · sticky broadcast
    without a stop operator · silent omission on a closed-row miss · length-changing
    broadcast · unchecked overlap · **wildcard over an open/`dyn` tail** (permit only where
    the tail is CLOSED — our tail state is the gate) · **deferring the construction/rename
    form** (XQuery is the 20-year cautionary tale; EQL LOST rename entirely) · `.` on
    triple duty without a WS-reader grammar audit (Julia: `sin (1)` is rejected but
    **`sin. (1)` parses**; GHC disambiguates `.` from composition *by whitespace*).
13. **`^` direction is genuinely contested** — OLD-first in SQL `AS` / Datomic `:as` /
    `rename-keys`; NEW-first in GraphQL aliases / Clojure destructuring. **Pick once, never vary.**
14. **An architectural argument nobody has made, available to us.** A mirrored nested result
    is ONE joined value converging as a unit; a flat leaf collection or path-keyed map is N
    **independently-converging cells**. GraphQL's nested result proved hostile to
    incremental delivery (`@defer`/`@stream` retrofitted, still unstandardized) and *every*
    serious consumer (Apollo, Relay) immediately normalizes it flat. In a propagator
    language that is a dataflow argument — not an ergonomic one — for flat/path-keyed modes
    existing *alongside* the nested one. **No prior art; ours to make or ignore.**

---

## §5 THE OPEN SURFACE — owner conversation (NOT decided here)

Deliberately left open per owner direction 2026-07-26: *"I'd like to go through
surface-language designs conversationally more deeply before we get back to iterating on
the implementation design document itself."*

### §5.1 The owner's draft (`foray.prologos:626-653`, verbatim intent)

```
app-config[database]                  ;; {:database {…}}          — keep the key
app-config[database^]                 ;; {:url …, :pool-size 10}  — ^ ELIDES the key
app-config[database^db features]      ;; {:db {…} :features @[…]} — ^name RENAMES
app-config[database^ features.1]      ;; ⟨{…} Keyword⟩            — key-less ⇒ POSITIONAL
app-config[admins.[name^]]            ;; @["Alice" "Bob"] : [PVec String]
app-config[admins.[name]]             ;; @[{:name "Alice"} …] : [PVec {:name String}]
app-config[admins.0.name]             ;; "Alice" : String
app-config[admins.0[name^ role^]]     ;; @["Alice" :super] : ⟨String Keyword⟩
app-config[admins.[name^ role^]]      ;; @[@["Alice" :super] …] : [PVec ⟨String Keyword⟩]
```

**The algebra this implies** (read out, for the owner to confirm or correct):
1. `.` = leaf access; `[…]` = selection that **keeps keys**.
2. **`^` is ONE operator at two arities**: `a^b` renames; **`a^` elides the key** (take the
   value). This is an elegant unification and, as far as the survey found, **novel**.
3. Result shape **falls out of key-presence** rather than a mode flag — the S7
   "algebraic collapse rule" position that the survey called the cleanest realization of
   the mirror principle in a shipping system (q/k).
4. Key-less entries ⇒ **positional (tuple) result**; keyed ⇒ record.
5. `.[…]` = **explicit broadcast**, per-element; result is a collection of the inner shape.
6. Nested `[…]` inside a path = sub-multi-select at that node.

### §5.2 Challenges to bring to the conversation

**CH-1 — One character on ONE selector reshapes the WHOLE result.** `[database^ features.1]`
→ tuple, but `[database features.1]` → record. That is arity/punctuation-dispatched shape,
the exact pattern §4.1/§4.12 identify as the canonical disaster. Options: (a) accept it as
an algebraic collapse rule and document it loudly; (b) **make mixing keyed and key-less a
static error** — uniformity required, which also honours the locked homogeneous-key-domain
invariant (Q_B) more honestly than a silent collapse.

**CH-2 — The draft is internally inconsistent on single-selector shape.** `[database]` →
`{:database …}` (keeps key) but `[admins.0.name]` → `"Alice"` (bare leaf). Path *length*
appears to decide shape. ⚠ This is very likely inherited from the shipped implementation
(`elaborator.rkt:2301`: `[(= (length paths) 1) (path->chain et (car paths))]`) — i.e. an
**implementation artifact absorbed as a design rule**. λ⟨⟩'s discipline says: never let
arity or length decide leaf-vs-row.

**CH-3 — "Preserve the path/nesting" has NO spelling in the draft** — yet it is V4's
explicit (b)/(c). Everything flattens to the leaf key. **Candidate**: `x[a.b]` = flatten
(dot descends), `x[a[b]]` = preserve (bracket nests) — which makes **dot and bracket the
two shape operators**, and the reader **already lexes both** (§3.4). But it collides with
the draft's `admins.0[name^ role^]`, whose result is a bare tuple, not `{:admins …}`.
Resolving that collision is the single richest question in the conversation.

**CH-4 — Every `.N` in the draft currently mis-lexes** (§3.4): `features.1` → bare `.`;
`x.1.2` → the rational 6/5. Fixable in the tokenizer, but it must be designed deliberately
and censused in BOTH reader modes, and it interacts with decimal literals.

**CH-5 — Collision is unhandled and currently silent.** `app-config[server.host db.host]`
→ both key `:host`; the shipped fold is `map-assoc` last-wins ⇒ **silent data loss**. This
is the one wart the whole field has (§4.11) **and the one we can statically check.** Make
it a named design goal.

**CH-6 — Missing feature-needs to rule on**: wildcard / "everything at a level" (owner's V4
listed it; §4.12 says permit only on a CLOSED tail) · miss semantics (§3.5, four-way) ·
whether a selector is a **first-class value** (§4 STEAL — the one feature nobody complains
about; `ERGONOMICS.org:74` already documents `map .:name` aspirationally, and it is
currently **unbound**) · nested/stacked broadcast (`.[…].[…]` — J's lesson: stacked rank
markers WRAP, they don't ADD) · the opt-OUT ("this row-valued thing is a VALUE here, not a
collection to iterate") · the write direction.

### §5.3 Rulings so far

- **Q_P5 — RULED (owner, 2026-07-26)**: **repair `.{` and retire it FULLY. Clean
  switchover; NO diagnostic, warning, or deprecation messaging to prior behaviour.**
  → Phase P1.
- Q_P1 (result shape) · Q_P2 (miss semantics) · Q_P3 (broadcast) — **folded into §5's
  conversation**; they are surface-shaped and will be ruled there.
- Q_P4 (scope) · Q_P6 (series reconciliation) — proposals in §9, owner to ratify.

### §5.4 Surface round 1 — rulings (owner, 2026-07-26)

- **Q_S1 — bare names ARE the selector keys** (`x[database]`, matching dot-access).
  Dynamic key indexing is the rarer case in a functional language; its selection
  spelling is **DEFERRED, not ruled** — the functional forms (`get`, `get-in`) remain
  the escape hatch. ⚠ Open consequence for shipped `v[i]` / `m[:a]` → **Q_S7**.
- **Q_S2 — the nat-key-display concern, and its resolution path**: the owner flagged
  that a record result keyed `0` would surprise (PVec/tuples don't display keys) and
  proposed `admins.0^[…]` — **`^`-elision mid-path** — to get the bare inner result;
  also proposed conditioning the keep-key rule on collection type, and pointed back at
  the historical `*` / `**` vocabulary. Grounded: `*`/`**` are from
  [`2026-03-02_2200_SCHEMA_SELECTION_DESIGN.md`](2026-03-02_2200_SCHEMA_SELECTION_DESIGN.md)
  §4.4 (`*` = all fields at a level; `**` = recursive; `:address` ≡ `:address.*`),
  carried into `#p(address.*)` / `#p(address.**)`. **Design observation (Claude)**: the
  carrier may already answer the display concern — a selection whose kept keys are nats
  IS a nat-keyed row, which IS the tuple (D13/Q_A: one carrier, surface presentation
  dispatched by key domain); no per-collection conditioning needed. Working through
  this is live (→ Q_S7's uniformity question).
- **Q_S3 — `x[a]` is ALWAYS `{:a …}`** — no arity/length dispatch. The redundant
  spelling `x[a^]` ≡ `x.a` is "acceptable and expected"; the motivating non-redundant
  case is same-level value-tuples `x[a^ b^]`.
- **Q_S4 — selectors ARE first-class values.** Both `my-selector m` and
  `map my-selector m` must work; `[…]` / `.[…]` are the ANONYMOUS selector, "akin to
  `rel` or `fn`". Prior efforts get a hardening re-look. Grounded at HEAD:
  `#p(a.x) : Path` constructs (wildcard `#p(a.*)` and globstar `#p(**)` too), and
  `[get-in m p]` evaluates — but a Path is **NOT applicable** (`[p m]` and
  `map p rows` both fail "Could not infer type"), get-in's result types as a **leaked
  meta** (`1 : ?meta…`), and wildcard get-in returns a silent `<error>` value.
- **Q_S5 — key COLLISION = static error**, with a diagnostic pointing at rename.
  (Owner wrote "pointing to `^_` as dynamic key rename" — exact `^_` semantics to
  clarify → **Q_S8**.)
- **Q_S6 — miss = type error / loud error with rich diagnostics** — extends the
  closed-row-miss standard over the §3.5 four-way inconsistency.

**Open after round 1**: **Q_S7** — does the uniform bracket law re-target shipped
`v[0]`/`v[1].b` (F1a-col degenerate case) to `⟨elem⟩`, with `v.0` (new `.N` lexing)
as element access? **Q_S8** — `^_` semantics. **Q_S9** — the anonymous selector's
standalone spelling + typing (selector-as-lambda v1 vs a dedicated node); interaction
with the standalone-`def`-lambda inference gap. Plus: wildcard `*`/`**` gating on
closed tails · stacked broadcast · empty selection · the write direction.

### §5.5 Surface round 2 — rulings (owner, 2026-07-26)

- **Q_S7 — RULED (a): the uniform law WINS.** `v[…]` always returns a selection
  (nat-keyed row); element extraction moves to **`v.0`** (new `.N` lexing, both reader
  modes, census required). Re-targets the shipped F1a-col degenerate case (`v[0]`,
  `v[1].b` → `v.1.b`) — clean switchover, Q_P5 posture. The law in one sentence:
  **"dot extracts the value; bracket selects a sub-structure."** Owner follow-up
  folded in: **`v.i` (dynamic index) as the recovery for dynamic PVec indexing** —
  see the round-2 proposal below.
- **Q_S8 — RESOLVED.** The owner's `^_` was placeholder notation (meaning `^new-name`,
  e.g. `host^new-host`). **But the misread is ADOPTED as a feature**: `^_` =
  **rename-to-DERIVED-key**, the mechanical remedy the collision diagnostic points at.
  Derivation rule = round-3 proposal below.
- **Q_S9 — RULED: selector-as-lambda is the v1 first-classness mechanism.**
  `.[sel]` ≡ `[fn [r] r[sel]]`; `map .[sel] coll` works via bidirectional checking
  (probe-verified); `coll.[sel]` ≡ `map .[sel] coll`. Named residual: standalone
  `def sel := .[…]` inherits the standalone-lambda def gap until annotated or until
  the dedicated selector node lands (where the broadcast-propagator guarantee attaches).

### §5.6 Round-2/3 proposals (Claude — pending owner ruling)

Motivated by the owner's standing unease: *"it's almost always my intuition that `v.N`
is the value at that index; `v[1 5]` would return a two-tuple of those indices;
requiring the `^` on `[admins.0^[…]]` seems unsatisfying."*

- **PR-1 — POSITIONS RENUMBER; keyword keys are IDENTITIES, nat keys are POSITIONS.**
  A nat-keyed selection result cannot keep source indices anyway — the carrier's
  **dense-prefix invariant** (F1 design §4.1) forbids the sparse row `{1↦B, 5↦F}`,
  and pvec `slice`/`concat` already renumber (F1a-col col-3: "renumbered append",
  "clamped sub-row"). So `v[1 5]` → **`⟨v.1 v.5⟩` dense, automatically — no `^`
  needed**: elision is STRUCTURAL in the nat domain. The owner's two-tuple intuition
  is exactly what the carrier's own invariant forces. (On `(PVec T)`: result
  `⟨T T⟩` — the arity is statically known, mirroring the D15 observation posture.)
- **PR-2 — the satisfying spelling for the `admins.0^` case is DOT-DESCEND, THEN
  SELECT**: `app-config.admins.0[name^ role^]` → `⟨"Alice" :super⟩`. Dots extract
  (no wrapping); the bracket selects on the extracted element. Mid-path `^`-elision
  is only needed in genuinely MIXED multi-selects. (Chaining dot-then-postfix already
  lexes: `v.a[0].b` verified at HEAD.)
- **PR-3 — names-vs-numbers asymmetry ⇒ `v.i` dynamic indexing is SOUND.** Keyword
  keys are NAMES (syntactic; `m.a` is literal, never variable `a`). Nat keys are
  NUMBERS (values). A name segment on a NAT-keyed subject cannot be a literal label
  (labels are nats), so it can only be a VARIABLE → dot on nat-keyed subjects takes an
  index EXPRESSION (`v.i`), while dot on keyword subjects stays literal. Disjoint key
  domains ⇒ no ambiguity. Consequences: the `record-project` dynamic-leg Int fix
  (§3.5) becomes REQUIRED, not just a repair; computed indices `v.[+ i 1]` collide
  with broadcast spelling — bind first or use `get` (named limit); union-typed
  subjects demand annotation.
- **PR-4 — `^_` derivation = full-path kebab-join from the bracket's root**:
  `x[server.host^_ db.host^_]` → `{:server-host … :db-host …}`;
  `admins.0.name^_` → `:admins-0-name`. Full-path (not shortest-suffix) so an
  existing key NEVER changes when a sibling selector is added; post-derivation
  collisions remain static errors (remedy: explicit `^name`).

### §5.7 Round 3 — the `*`-segment recast (Claude proposal, 2026-07-26; owner unease was the trigger)

**Trigger (owner)**: `.[…]` is at odds with the algebra — `.` means extract, `[` means
keep; iteration is neither. And the three admins targets (`@["Alice" "Bob"]` /
`{:admins @[…]}` / `{:admins @[{:name …}…]}`) were not equally easy to spell.

**PR-5 — `*` IS the iteration operator, as a PATH SEGMENT.** `admins.*.name` = "for
each entry of admins, its name" — the owner's OWN 2026-03-02 vocabulary
(`depts.*.projects`), and a compositional generalization of the SHIPPED `.*name`
broadcast (First-Class Paths 7b: `admins.*name` ≡ new `admins.*.name`). `.[…]`
broadcast is RETIRED from the design. `*` = "each entry" uniformly: per-element on
nat-keyed subjects, per-VALUE on keyword-keyed subjects (map-vals — answers Q_S12
with the same one rule). Stacking is just two segments (`matrix.*.*.x`) — the J
wrap-vs-add trap dissolves. Dynamic `v.i` (PR-3) sits beside it: `v.*` = all, `v.i`
= one, `v.0` = literal.

**PR-6 — the keying rule, refined once**: a selector's kept key = the last segment of
the path **up to the first structural operator (`*` or `[`)** — i.e. the deepest node
the selector addresses AS A WHOLE. For pure paths this coincides with the round-2
last-segment rule (`server.host` → `:host`); with iteration it names the collection
(`admins.*.name` → `:admins`), which is what reads correctly. Corollary: `^`/`^n`/`^_`
attach selector-FINAL and govern the selector's contributed key (mid-path `^` is
superseded by PR-2 dot-descend).

**The four quadrants, minimal spellings, no `^` needed:**
| want | spelling | result |
|---|---|---|
| bare leaf values | `x.admins.*.name` | `@["Alice" "Bob"]` |
| keyed leaf values | `x[admins.*.name]` | `{:admins @["Alice" "Bob"]}` |
| keyed sub-records | `x[admins.*[name]]` | `{:admins @[{:name "Alice"} …]}` |
| bare sub-records | `x.admins.*[name]` | `@[{:name "Alice"} …]` |

**PR-7 — `.[…]` is FREED and becomes the anonymous-selector literal** (Q_S9's
spelling): `.[name role]` ≡ `[fn [r] r[name role]]`; the simple section is `.name`
(`map .name admins` — heals `ERGONOMICS.org:74`'s `.:name` aspiration). Leading dot
= "subject pending", one reading everywhere.

**Named costs**: (i) the `*`-SPLAT proposal (§ round-2 reply) CONFLICTS with
`*`-iteration in final position — recommend splat is DEFERRED/re-spelled (it was
Claude's proposal, not an owner need); (ii) `.*` reader work + `.*name` migration
(already owed in P6); (iii) `*` on dyn tails stays forbidden (the wildcard gate).

**PR-8 — the mixed-`^` question (owner re-floated)**: when one selector at a level
elides, do siblings COERCE to positional (owner lean — one `^` ⇒ the level is a
tuple) or is mixing a STATIC ERROR (Claude rec — remedy: elide/rename the rest)?
Note: the owner's original draft line `[database^ features.1]` is all-positional
under EITHER rule (nat-ending selectors contribute positionally per PR-1).

**The first-principles needs basis** (owner asked for it): descend `.` · keep/assemble
`[…]` · each `*` · key disposition {keep default, `^` drop, `^n` rename, `^_` derive,
selector-final} · assembly rule (record | tuple | PR-8) · extraction (all-dots) ·
dynamic index (`v.i`, dot-only) · sections (leading-dot forms) · reserved: ranges
(future CIU track), `**`, splat respelling, nil-safe, omit-selectors
(presence-marks era), the write direction.

### §5.8 Round 4 (owner + Claude, 2026-07-26) — segment-attached `^` · the `:`-iteration variant · solve modeling

- **ADOPTED — `^`-forms attach to the KEY-GENERATING segment** (owner proposal
  `x[admins^.*[name] features^]`, soundness verified). The rule: `^`/`^name`/`^_` sit on
  the segment the keying rule selects (= the last segment before the first structural
  operator; = the final segment in pure paths). This SUPERSEDES PR-6's selector-final
  corollary — for pure paths the two coincide; with a structural tail the mark stays
  visually ON the key it governs instead of after the bracket. `^` on any OTHER segment
  = static error. Lexing verified: `admins^` glues; `admins^.…` chains.
  Owner's example under the rule: `x[admins^.:[name] features^]` → both elided → the
  TUPLE `⟨[PVec {:name String}] [PVec Keyword]⟩` (display `⟨…⟩` — heterogeneous nat row,
  not `@[…]`).
- **PR-9 — the `:`-iteration variant (owner floated; Claude assessment: workable, with
  named costs).** Owner finds `*`-as-iteration hard to read and wants `.*` as SPLAT.
  The underlying insight: `*`'s March meaning is "all the FIELDS, here" (wildcard/
  splat), NOT "for each, onward" — the two are different operations and overloading
  `*` with both is why it read badly. Division of labour:
  - **`*` = all-fields-HERE**: final-position `server.*` = SPLAT (fields spliced into
    the result level); `[*]` = identity sub-select. Closed-tail-gated. Mid-path `*` is
    ILLEGAL (its March mid-path use migrates to `:`).
  - **`:` = along-EACH-entry** (NumPy `a[:, k]` / q `::` precedent): `admins.:.name`
    (each's name) · `admins.:[name]` (each, sub-selected) · `rows.:[f c]`.
  - **Grounded lexical facts**: `.:.` / `.:[` degrade to bare `|.| :` tokens today
    (reader work needed, tokens available); ⚠ **`m.:name` ($dot-key) is LIVE** —
    probed, returns the field — so `:`-iteration creates the one-dot hazard
    `m.:name` (field) vs `m.:.name` (each's name) UNLESS dot-key is retired (migrate
    `.:name` → `.name`; census owed; ERGONOMICS.org:74's `map .:name` becomes
    `map .name`). Colon triple-duty (keyword sigil · fused `x:Int` annotations ·
    dot-key) makes this the most census-sensitive corner of the tokenizer (the 7g
    drift family). Sexp-mode divergence noted (keyword-glued paths).
- **Solve-rows modeling** (owner-anticipated consumer), with `rows : List {:c String
  :f String}` from `def rows := solve (fruit-color f c)` (or the POL.9 implicit form):
  - `rows.:.f` → `'["apple" …] : [List String]` — one column, bare.
  - `rows.:[f]` → `[List {:f String}]` — narrowed rows.
  - `rows.:[f^ c^]` → `[List ⟨String String⟩]` — per-row value tuples (zip shape).
    (PR-8's coerce-vs-error fork reappears PER-ELEMENT here.)
  - **Empty-prefix selectors = COLUMN EXTRACTION**: a selector may begin with `:`
    (no key-generating segment → keyless → positional, or renamed):
    `rows[:.f^fruits :.c^colors]` → `{:fruits [List String] :colors [List String]}`
    — the named UNZIP, one selection. Lexes today (degraded): verified.
  - `rows.0.f` → `"apple"` (extraction); `rows[0]` → `⟨row⟩` per Q_S7a.

### §5.9 THE SETTLED SURFACE (D.2 — owner-ruled across rounds 1–5, 2026-07-26)

**Rounds 1–4 = §5.4–§5.8; round 5 rulings: PR-9 ADOPTED (`:` iteration · `*` splat ·
dot-key retired) and PR-8 → STATIC ERROR.** Items marked ⊳ were adopted under the
owner's delegation ("incorporate … with your recommendations", 2026-07-26).

- **PS1 — the operator core.** `.` DESCENDS-and-drops (extraction) · `[…]` SELECTS
  (keeps/assembles; always returns a row) · `:` ITERATES ("along each entry" — the
  NumPy `a[:, k]` / q `::` reading): per-element on nat-keyed subjects, per-VALUE
  (map-vals) on keyword-keyed ones. No operator has two meanings.
- **PS2 — the uniform law**: *dot extracts the value; bracket selects a
  sub-structure.* `v[…]` ALWAYS returns a selection; `v.0` is element extraction
  (new `.N` lexing). Re-targets the shipped F1a-col degenerate case (`v[0]` →
  `⟨elem⟩`; `v[1].b` → `v.1.b`) — clean switchover + census (Q_S7a).
- **PS3 — keying**: a selector's kept key = the last segment of its path BEFORE the
  first structural operator (`:` or `[`) — the deepest node addressed AS A WHOLE.
  Pure path → last segment. Empty prefix (selector starts at `:`) → keyless
  (column extraction; renameable).
- **PS4 — key domains**: keyword keys are IDENTITIES (survive selection); nat keys
  are POSITIONS (renumber dense — the carrier's dense-prefix invariant makes
  "keeping" source indices impossible; `v[1 5]` → `⟨v.1 v.5⟩` automatically).
- **PS5 — assembly**: all-keyword → record (canonical field order; value display may
  keep selection order) · all-positional → tuple (WRITTEN selector order) · **mixed →
  STATIC ERROR** (PR-8 ruled; conservative over the coercion reading — R's lesson
  applied precisely: R's bite was shape-by-runtime-arity, coercion's would be
  shape-by-non-local-static-scan; the error keeps every selector's contribution
  locally derivable). Diagnostic names the remedies: `^` / `^name` / `^_`.
  Applies identically per-element inside `.:[…]`.
- **PS6 — the `^` family attaches to the KEY-GENERATING segment** (owner rule,
  round 4): `^` elides · `^name` renames · `^_` derives. On any other segment =
  static error. `^_` derivation = full-path kebab-join from the bracket's root
  (`server.host^_` → `:server-host`); post-derivation collisions stay errors.
- **PS7 — collision = static error** (Q_S5), diagnostic pointing at `^name`/`^_`.
  We check what the field ships unchecked (`Control.Lens.Unsound` et al.) — a named
  design goal.
- **PS8 — miss = loud** (Q_S6): closed-row miss = type error with the rich
  field-naming diagnostic; dyn-tail miss = the D19 fresh meta (D23 escape-boundary
  unchanged); PVec runtime OOB becomes LOUD (P2); tuple OOB stays static.
  Wildcards/splat only on CLOSED tails.
- **PS9 — `*` = all-fields-HERE** (the March wildcard meaning, both halves): final
  position = SPLAT (fields spliced into the result level; collisions → PS7);
  `[*]` = identity sub-select (`x[server[*]]` ≡ `x[server]`). Mid-path `*` is
  ILLEGAL — that meaning lives in `:` now.
- **PS10 — dynamism is DOT-ONLY** ⊳: brackets are 100% literal/static (what makes
  selection fully typable). `v.i` = dynamic index via the names-vs-numbers
  asymmetry (a name segment on a nat-keyed subject can only be a variable);
  requires the P2 Int-gate fix. Computed indices: bind first or `[get v e]`.
  Dynamic KEYWORD lookup stays `get`/`get-in` (Q_S1).
- **PS11 — first-class selectors = lambda sugar (v1)**: `.[sel]` ≡
  `[fn [r] r[sel]]`; `.name` = the simple section (heals ERGONOMICS `.:name` →
  `map .name users`). Works in argument/application position TODAY (bidirectional
  checking, probe-verified); standalone `def sel := .[…]` inherits the
  standalone-lambda gap (annotate) — named, not hidden. FUTURE: a dedicated
  selector node carrying the one-broadcast-propagator/one-fire/one-merge guarantee
  (NTT model required THEN; v1 adds zero propagators).
- **PS12 — retirements + migrations** (all clean-switchover, each with census):
  `.{` (Q_P5, + the 4 broken audit files) · **`$dot-key`** (`m.:name` → `m.name`;
  frees `.:`) · old broadcast **`.*name` → `.:.name`** (expr-broadcast-get surface
  superseded) · `m[:a]` flips from extraction to selection · `x[]` = static error
  (hint: `{}`) · `_[sel]` rejected (hint: `.[sel]`).
- **PS13 — reserved slots** (grammar leaves room; NOT built): ranges as nat-domain
  selectors (**future CIU track**, owner-owned designs) · `**` globstar (typed
  static-expansion story exists; deferred) · splat respellings beyond final-`*` ·
  nil-safe selection (`?.`-family) · omit-selectors (presence-marks era) · the
  WRITE direction (decided now, built later: v1 is READ-ONLY; overlap legal for
  reads; the disjointness check arrives with writes).
- **PS14 — sexp mode gets an explicit special form** for selection (postfix
  adjacency is WS-only; the paren-goals institutionalized-divergence precedent).
- **PS15 — subjects**: closed rows exact · dyn rows known-exact/unknown-meta ·
  `(Map K V)` uniform V per field · schema/selection fvars via `schema->row` (the
  F1b.7e projection; selections intersect `:requires`). Selection results are
  ordinary closed rows — sealable, validatable, def-storable (D23 applies).

---

### §5.10 D.3 critique adjudication — round 6 (owner + Claude, 2026-07-26)

**The D.3 external critique** ([record + full findings](2026-07-26_CIU_T6_PATH_SELECTION_D3_CRITIQUE.md):
2 BLOCKING · 11 SIGNIFICANT · 8 MINOR surviving; 12 refuted) **was adjudicated in full.**
Dispositions below amend PS1–PS15 as ✏ deltas (the PS text in §5.9 stands as written;
where a delta conflicts, the delta WINS). Owner rulings this round are marked **[owner]**.

**The two BLOCKING:**

- **D3-B1 → ACCEPT.** PS8 is restated: **the miss ruling is a function of the negative
  information the subject's type carries** — a closed row carries "lacks *l*" → static
  error; a dyn tail carries "unknown" → D19 meta; **`(Map K V)` carries nothing about
  presence → the result is `Option`-shaped, NEVER a bare `V`**; unbounded positional
  carriers (PVec/List — added to PS15 per D3-M5) carry no arity → runtime miss, LOUD.
  PS15 gains the sealability qualifier: *a selection result is a closed row only when
  its presence information was SOURCED, not fabricated.* P2 grows the Map-miss leg,
  the `map-get`-on-nat-row leg, and List OOB — all pinned **failing-test-first**.
  The "closed tails" wildcard gate is restated as **support-boundedness** (D3-M5).
- **D3-B2 → ACCEPT PROBLEM; solution REPLACED [owner].** The dot-sections are
  **WITHDRAWN** (`map .name users` does not lex — the fold absorbs the preceding
  token; main-session-verified). The owner's replacement: **keyword-as-projection** —
  **`map :name users`** (the Clojure idiom). Mechanism: a CHECK-mode coercion arm —
  a keyword literal checked against a concrete `A -> B` where `A`'s row/schema/Map
  carries the key elaborates to the projection lambda (+ the qtt twin; + optionally
  the application-head arm `[:name m]`). **Zero reader work**; `:name` stays an
  ordinary Keyword everywhere a Keyword is expected (`[map-get m :name]` verified
  unchanged). `.[sel]` as a selector literal moves to PS13 (reserved); multi-select
  selector values are explicit lambdas in v1. PS11's "annotate" remedy corrected:
  annotate **with a named schema** (anonymous rows are not writable types — D3-S11).

**Owner rulings on the four escalated items:**

- **D3-S5 (the two `.{` worlds) → ACCEPT [owner]**: repair the four audit files'
  mixfix `.{X}` → `.(X)`; **retire `.{` COMPLETELY from code and diagnostics** (the
  recognizer + the `$mixfix-retired` error are DELETED — the syntax simply ceases to
  exist); the sexp brace-select's 20 tests are **RE-POINTED at the P4 sexp special
  form, never deleted** — that leg sequences WITH P4, not first. P1 splits accordingly.
- **D3-S1 (`v.i`) → KEEP, as a bounded sub-phase [owner criterion: fits-a-phase].**
  The real mechanism is named and budgeted as **P4.d**: preparse emits ONE neutral
  segment node (no keyword freeze); name resolution is SOFT (unbound is not an error
  when the subject is keyword-keyed); the key-domain fact flows from the subject's
  row into the segment's resolution; qtt reads usage off the same resolved domain.
  PS10's invariant restated: *every contributed KEY is statically determined; the
  VALUES navigated to need not be.* If P4.d drags, it is cuttable (Q_S1's `get`
  hatch loses nothing).
- **D3-S3 (splat) → ACCEPT; SPLAT STAYS [owner].** One cause, three fixes:
  (a) PS3's keying is restated over **CONTRIBUTIONS** — a selector contributes one
  keyed slot, one positional slot, or (splat) **a SET of slots from the subject's own
  support**; the structural operators are `:`, `[`, **and `*`** (the round-5 swap
  dropped `*` from the list — restored). PS5/PS7 consume contributions uniformly.
  (b) The collision remedy on a splat is **`^_` = derive-ALL** (every spliced field
  gets its full-path key: `x[server.*^_ db.*^_]` → `{:server-host … :db-host …}`,
  collision-free by construction); `^` and `^name` on a splat = static error (no
  single key to govern). (c) §5.7's quadrant table is stale (mid-path `*` spelling)
  — superseded by §5.8's `:` spellings; noted, not rewritten.
- **D3-M1 (Q_S3) → RE-RULED [owner].** The redundancy basis was gone; the owner
  re-affirms on the correct basis: *a selection returns a sub-tree (or forest) — a
  collection is the expected result* — and `x.a` is the deliberate single-value
  spelling. `x[a^]` = `⟨x.a⟩` stands, now deliberately.

**The substrate bug [owner]:** **D3-S10 (the concrete-codomain lambda-adoption hole)
gets its OWN PHASE in this track** — row **PX** in §2 — "not a bug we want rolling
around unnoticed." Fix shape (from the critique, information-flow): decomplect
evidence from obligation at binder positions — the downward write flows to an
`:expected` facet; the lam's `:type` facet is written only from the body's own type;
disagreement → `type-top` → the existing top-refusal. (§3.7's `map-size` class stays
FILED SEPARATELY as before.)

**Remaining dispositions** (all ACCEPT unless noted): **S2** §3.2 narrowed to the
keyword result type; P4 gains the nat-keyed assembly path + the closed-vs-dyn seed
pin (PS15 says CLOSED; the `{}` seed is DYN — test-pinned at P4). **S4** `rows[:f]`
vs `rows[:.f]` is DISSOLVED: `m[:a]`/keyword-in-bracket does NOT flip — it **RETIRES**
(static error + hint naming `m[a]` / `get`), amending PS12; PS1 gains the `:` result
carrier: **iteration preserves the source collection kind** (List→List, PVec→PVec,
keyword-row→map-vals with keys kept; heterogeneous tuple→per-position row).
**S6** P3 grounds on the **token-registry inventory** (priorities 92/88/87/86) as the
authoritative list — the walker discipline applied to the tokenizer; `.(` is named as
P1's repair target; `$nil-dot-key` (`#.:name`) retires WITH dot-key (its `#.name`
form survives); CH-4 ruled: `.N` anchors at the DOT, numeric recognizers anchor at a
DIGIT. **S7** PS7's novelty claim corrected (result-key collision is precedented —
GraphQL `FieldsInSetCanMerge`); **source-overlap disjointness is the WRITE phase's
headline deliverable**, named in §9. **S8** §6 owes the Q4 bridge diagram with TWO
edges — keyword = Galois (D21); nat = **relabelling with NO adjoint** (dense-prefix
forbids the sparse γ) — the selector is the correspondence carrier for the nat edge;
§6 re-run lands with D.4. **S9** §9's supersession rewritten against the CIU master:
T2 items 2+4 superseded; **item 1 (`ground-expr?` `expr-union` arm — verified live,
0 arms in trait-resolution.rkt) re-homes to P2** beside its §3.6 twin (the generic
transparent-struct fallback covers both structurally); item 3 (sugar audit) is P3's
prerequisite; **T3 is RE-CHARTERED, not "kept"** (PS2/PS10 redefine its Phase-2
example and Phase-3 criterion). **S11** PS15 reframed as *where row information
enters a binder's type cell*; v1's abstraction direction rides **named schemas +
keyword-projections**; **P0 MUST carry function-typed forms** (else it proves
nothing about library usability). **M2** P4 explicitly books pipeline item 13: the
node gets a **deliberate `#f` registration** (the `expr-solve`/`expr-map-get` idiom),
never left unregistered; §7's instruction narrowed to "no propagator CLAIMS without
`net-add-propagator` calls". **M3** `#p()`/`Path` = the dynamic tier, KEPT v1, with
a DEFERRED entry for applicability/typed-Path; the PRIMARY selector representation
is the selection AST (the sexp special form); `#p` is runtime path DATA. **M4/M8**
doc fixes folded (presence+tail lattices added to §6.2's inventory; the unenforceable
§6.4 sentence deleted; coordinates re-pinned: elaborator arm :2297-2298, key-ty :565,
audit-08 count 3). **M5** folded into B1/PS15 above. **M6** P3 additionally REJECTS
`.-1` with a real diagnostic and pins selector round-trip printing. **M7**'s counts
land in the P2/P3 census rows (49+45 `v[literal]` sites, 48 test-cases, etc.).

**Out-of-scope flag (owner call recorded as CORRECTLY out of scope)**: cross-level
correlation inside iteration ("for each admin, pair its name with the app's name")
has no v1 spelling — selection is subtree extraction; the shape belongs to a future
comprehension/binding surface, noted in PS13's spirit but not reserved.

**Round 7 — P2.b RULED (owner, 2026-07-26): realization (c), stated as THE TWO-TIER
PRINCIPLE.** This ✏-amends the D3-B1 adjudication above (the census evidence revised
the realization while honoring the actual claim, *"never a bare V silently"*):

> **The assertive tier** — `map-get` / `.field` / `v[k]` — asserts presence; a FAILED
> assertion at runtime is a LOUD, counted error (panic-shaped). **The honest tier** —
> `nil-safe-get` (`V|Nil`) · library `nth` (`Option`) · the traits' `kv-get`/`idx-nth`
> (`Option`) — is the spelling for expected absence, unchanged.

Realization constraints (from the P2 mini-audit, all probe-grounded):
- The runtime miss arm is TYPE-BLIND (rows/dicts share the champ) → the loudness is
  carried by an **elaboration-time strictness mark on Map-typed subjects**; dyn-ROW
  runtime misses keep the D19 permissive display (pinned: route-soundness :196,
  records acceptance ;;77).
- The loud path is **TOP-NODE-BOUNDED** at the driver seam (a miss nested inside a
  constructed value prints the panic, counts 0) — accepted + NAMED, the D22
  seal-forcing precedent's own bound. A Racket raise would crash the file (no handler
  at the reduce seam) — not an option.
- The OOB legs join the same tier: PVec via expr-get (`<error>`) AND the divergent
  `pvec-nth` stuck leg, + the audit's two silent siblings (`pvec-update` OOB,
  `pvec-pop`-on-empty), + List OOB. `[map-get tup 1N]` on a PRESENT position
  **projects** (value agrees with the typing, which already projects); OOB = loud.
- Break set: exactly the 2 silent-miss pins (`test-map.rkt:124-127`, `:137-143`) flip
  to loud assertions; zero stdlib/corpus churn. Doc-truth rider: the map tutorial
  teaches "error if missing!" 3× — (c) makes the teaching TRUE.
- Option-wrap (a) is recorded as REJECTED-WITH-REASON: ~35-40 tests + 6 stdlib ×2
  book twins + ~24 corpus sites, hit-values change to `some v`, ergonomics ~5:1
  against (44/53 sites access provably-present keys), `kv-get` double-wraps.

**Round 6b — the standalone-def seam, widened by an owner data point (2026-07-26).**
Owner hand-use: `def add5 := [+ 5 _]` fails ("Could not infer type — hint (issue
#70) …"). Probed at HEAD, the boundary is the **def-RHS seam itself, not numerics**:
- `def add5 := [+ 5 _]` (trait-op section) — FAILS with the #70 hint;
- **`def add5c := [int+ 5 _]` — the CONCRETE-op section the #70 hint itself
  recommends — ALSO FAILS** in def position (the second
  diagnostic-recommends-an-impossible-fix instance, after the row-annotation hint);
- `def getname := [fn [r] r.name]` (the row cousin) — FAILS;
- ALL THREE work in ARGUMENT position (`map [+ 5 _] xs` → `List Int`, probed) and
  under an ANNOTATED def (`def add5b : <Int -> Int> := [+ 5 _]` → works).

So {trait sections · concrete sections · row lambdas · selector values} are ONE
family: a def-RHS binder with no expected type does not infer its param type even
when the BODY fully determines it (`int+` is monomorphic `Int Int -> Int` — that
case needs no residuation, only body-directed inference). **Owner ruling: fix this
aspect alongside the typing work — PX WIDENS to the binder-seam phase**: (a) the
D3-S10 adoption hole; (b) standalone-def inference for body-determined cases
(monomorphic sections + row lambdas whose body pins the row); honest residue: the
trait-op case (`[+ 5 _]`) may additionally need numeric defaulting or a residuated
constraint (the Num Track 2 / F-row seam) — if so, it lands annotated-only in this
track with the deep fix pointed at its owning track. P0 pins the whole family
(commented) + the working argument-position and annotated forms (markers).

**Round 8 — the P2.b mini-audit REFUTES three of round 7's premises (2026-07-27).**
Audit `wf_c89b3532-8a7` (6 read-only facets + completeness critic), every load-bearing
claim below **re-probed on the main thread** before it entered this section. Round 7's
*principle* (the two-tier split) stands unchanged and is NOT re-opened; what follows
corrects its **realization**, which was specified against facts that do not hold.

⚠ **HEAD moved during the audit**: `8d2eb340` → `6a444cba` (36 commits, fast-forward —
the concurrent `<`-mixfix task plus an issue-#58 perf arc; suite 233 s → 96 s,
`PNET_VERSION` 4→5). `reduction.rkt` / `typing-core.rkt` / `syntax.rkt` /
`elaborator.rkt` are **untouched** (all six site coordinates hold); `driver.rkt`
(+306/−94) and `pnet-serialize.rkt` (+136) churned. **Re-pinned**: the panic seam
`774-780` → **`driver.rkt:808-814`**; the D19 route-soundness pin `:196` →
**`test-route-soundness-01.rkt:200`** (test-case opens `:191`). Two round-7 site
coordinates pointed at comment lines: expr-get RRB OOB is **`:2706`** (not 2701),
List OOB **`:2717`** (not 2709); the other four (2674, 2769, 2777, 2800) are exact.

*Refuted:*

- **R1 — the stated mechanism does not exist.** "An **elaboration-time** strictness
  mark on **Map-typed** subjects" is not realizable: `elaborate`'s env is a
  name→de-Bruijn-depth alist and nothing else (`elaborator.rkt:1027`, `:89-99`).
  Elaboration cannot know a subject is Map-typed. Neither cited precedent is a mark:
  **D22 stamps nothing** (a driver-side *shape recognizer* over the already-elaborated
  body, `driver.rkt:269-278`) and **`validate` is a whole new node kind**
  (`syntax.rkt:727`). Their pipeline cost differs ≈ **11 files : 0** — D22 was nearly
  free only because `expr-panic` was already fully registered.
- **R2 — "a Racket raise would crash the file" is FALSE.** `exn:prologos-solve`
  (`relations.rkt:1627`) is already raised *from inside* `reduction.rkt:644` at three
  boundaries and converted to a counted per-command error at `driver.rkt:1545`, file
  continuing. The real (unnamed) hazard: it subtypes `exn:fail`, and **four of six
  target sites sit inside `with-handlers ([exn:fail? …])`** — a nested raise is
  swallowed into exactly the silent value P2.b removes.
- **R3 — the loud path is not "top-node-bounded"; at the def seam it is ABSENT.**
  Probed: `def d := [boom 2]` → `d : Int defined.`, **zero errors** (`driver.rkt:1907`
  has no panic check between `whnf` and `global-env-add`). P2.b's motivating case IS a
  def. Compounding: both precedents force with `nf` (`:285`, `:804`) while the def seam
  uses `whnf` and is *committed* to that (`:1893-1895`, POL.10).
- **R4 — the `[map-get tup 1N]` claim is INVERTED IN BOTH HALVES.** Probed on
  `def tp := @[1 "a" true] : ⟨Int String Bool⟩`: the **present** position returns
  `none : String` — a fabricated library value at the projected type, and
  `def m1 := [map-get tp 1N]` **commits it silently** (`m1 : String defined.`, 0
  errors); the **OOB** position is *already* loud (`ERROR: Could not infer type`).
  Mechanism: a tuple's runtime rep is `expr-rrb` and `definitely-not-map?`
  (`reduction.rkt:1707-1738`) has **no `expr-rrb?` arm**, so map-get falls to
  `:3074`'s `(expr-fvar 'none)`. **This is SITE 7** and it is worse than the six: it
  invents a legitimate `none` rather than an `<error>` sentinel. Latent-but-live — it
  detonates the moment PS2 desugars nat-keyed extraction into `map-get`.
- **R5 — the six-site enumeration under-counts by ≥3** (the recurring failure mode):
  site 7 above · `expr-tvec-update!` OOB (`:2998` — the **fifth** `with-handlers`;
  round 7's prose accounts for four) · `pvec-slice` silently **CLAMPS** out-of-range
  bounds with no guard at all (`:2807-2812` → `rrb.rkt:305-309`).
- **R6 — doc-truth miscount**: the map tutorial teaches error-on-miss **4×**, not 3×
  (`examples/map-tutorial-demo.prologos:103, :143, :246, :498`). A **fifth** doc-truth
  site points the *opposite* way: `syntax.rkt:812`'s own comment promises
  `Option Value` for `expr-get` — a node this ruling places in the ASSERTIVE tier.

*Survived (re-verified, do not re-litigate):* type-blindness is real (all three seeds
reduce to the same `expr-champ`; both type args wildcarded at `reduction.rkt:2669`) ·
both D19 pins exist, and `;;77` is a genuine automated gate
(`examples/2026-07-06-ciu-t6-f1-records.prologos:349`) · `expr-panic` is fully
pipeline-registered incl. `pnet-serialize.rkt:286`, surviving the churn · the break set
is *literally* 2 pins.

*Three qualifiers that matter more than that number:*

1. **Five of the six sites have ZERO test coverage in either direction.** Every OOB pin
   in-tree is on a CLOSED TUPLE and errors at *elaboration*, never reaching reduction
   (`tests/test-tuple-ops.rkt:188-201`; the records acceptance `;;64`); `test-pvec.rkt`
   reduction cases are 100 % in-bounds. The flip is **suite-invisible both ways** — P2.b
   must SHIP failing-test-first coverage, not flip 2 assertions.
2. **An unnamed THIRD dyn-row pin is the discriminating case**:
   `tests/test-route-soundness-01.rkt:204-215` commits a miss into
   `def x : String := [map-get m :c]`. The mark MUST key on the **subject's**
   row-openness, never on the def's annotated type — else this pin breaks.
3. **Guards insulate at REDUCTION but NOT at typing.** Probed:
   `[if [map-has-key? r :zzz] [map-get r :zzz] 0]` on a closed record **errors today**,
   from the *untaken* branch. So the strictness decision may only take effect when the
   marked node is REDUCED. (The honest tier survives this today only because its bodies
   are polymorphic — `Map K V`, `PVec A` — a type-shape accident, not a guarantee.)

**Round 8 rulings [owner]:**

- **Q_N4 — MECHANISM: the CARRIED-ALPHA pattern** (`expr-num-lit`'s, the third in-tree
  channel the design never named). Elaboration mints the node carrying a **fresh meta**
  — *type-blind, so no typing env is needed*; the **type checker solves** it from the
  subject's row (`elaborator.rkt:1493` → `typing-core.rkt:3070` → `zonk.rkt:1064` is
  the worked template); **zonk materializes** it into the term reduction sees. The
  design's intent restated correctly: not a mark *decided* at elaboration, but a
  strictness **SLOT opened** at elaboration and **resolved at type-check**. It is
  naturally guard-aware (qualifier 3) because it only bites when the node reduces.
  ⇒ **The POLARITY question DISSOLVES**: `syntax.rkt` has **zero `#:auto` fields**
  across all 344 `expr-*` structs, so there is no "unmarked" state to assign a default
  to — every construction site must declare. ~~as a compile-time arity error. Fail-loud
  by construction~~ **CORRECTED round 8b (probe-reproduced): cross-module CONSTRUCTOR
  arity mismatch compiles CLEAN (exit 0, zero diagnostic) — only `match` patterns are
  compile-loud.** A field migration is discovered by patterns at build and by
  constructors only WHEN EXECUTED. Cost is honest: `pipeline.md` § New Struct Field
  applies in full (repo-wide `struct-copy` AND direct-constructor grep;
  `pnet-serialize.rkt:307`'s `reg2! expr-get` becomes `reg3!`).
- **Q_N5 — the DEF SEAM is IN SCOPE.** P2.b is unobservable without it (R3). Must
  respect the whnf-never-nf commitment — this is not a one-liner.
- **Q_N6 — SITE 7 is IN SCOPE.** The tuple-`none` fabrication (R4). Preferred fix is
  **structural**, not a sixth exemption: `definitely-not-map?` is a hand-maintained
  NEGATIVE inclusion list patched five times by exemption, each patch's own comment
  recording a silent-value-loss bug found afterward (`:1721-1738`; P2.a added one).
  Site 7 is the sixth instance of that class — exactly the hand-armed-walker
  anti-pattern `pipeline.md` § Exhaustive Walkers says to replace with a structural
  default. Also note `grep -c expr-error driver.rkt` → **0**: no seam converts a runtime
  `expr-error`, so the silence is STRUCTURAL and any fix must add a driver-seam
  conversion or route through `expr-panic` (which already has one). ⚠ "Make
  `expr-error` loud" is WRONG — it has ~200 type-level sites plus four NaR arithmetic
  producers with their own pins (`:2074/:2145/:2286/:2357`); edit *these arms*.
- **Q_N7 — the OOB family SPLITS** (owner: the three pvec sites are not one tier).
  **IN P2.b (assertive/read):** `pvec-nth` OOB · `expr-get` PVec OOB · `expr-get` List
  OOB. **NOT in P2.b, each named with its reason** — *proposed dispositions, owner to
  confirm at the P2.b checkpoint*: `pvec-update` OOB is **write-shaped in a read-only
  v1**, and its sole stdlib caller `pvec-idx-update`
  (`lib/prologos/core/pvec.prologos:92-94`) is **UNGUARDED** while its `idx-nth`
  sibling is guarded and its List sibling's documented contract is *"if out of bounds,
  return unchanged"* (`lib/prologos/core/list.prologos:95`) — same `Indexed` dict,
  divergent behaviour, no test. Today's stuck-`e` satisfies **neither** contract, so
  the arm is **already incoherent**; that is a trait-coherence ruling, not a P2.b one.
  `expr-tvec-update!` OOB follows `pvec-update` (its transient twin). `pvec-pop`-on-empty
  is a **partial function on an empty carrier** — no key, no index, a different failure
  class. `pvec-slice`'s silent clamp is filed alongside §3.7's `map-size` class.
  ⇒ This is the one place "zero stdlib churn" was factually at risk; splitting keeps it true.
- **SRCLOC, named not solved**: a loud runtime miss would be **locationless**
  (`expr-map-get`/`expr-get` carry no srcloc; `reduction.rkt` has zero
  `current-source-loc` refs; the panic path passes `#f` at `driver.rkt:809`). The
  existing static diagnostic — *"field :zzz is not present in the record {:a Int};
  available fields: :a"* — is the **quality bar**, and for statically-known CLOSED
  records the assertive tier is **already loud with a better message than a panic can
  give**. The six sites are the **DYNAMIC RESIDUE ONLY** (`Map K V` dicts, dyn rows,
  PVec/List of non-static length); sizing P2.b as "six silent sites" overstates it.
- **Test-authoring trap (load-bearing for P2.b's own tests):** `expr-panic` is
  bottom-like in CHECK mode only — `infer` returns `(expr-error)` for it
  (`typing-core.rkt:2616` vs `:3000`; `qtt.rkt:1786` vs `:2285`). A bare top-level
  `[panic "…"]` dies at infer with *"Could not infer type"*, **not** `panic:`. Reduction-
  produced panics are unaffected. Any test that writes a bare panic will mislead.

**Round 8b — the slice-2 mini-audit (`wf_af8d65c5-a6e`, 2026-07-27; all load-bearing
claims main-session re-verified).** The Q_N4 scope hypothesis HELD, with new facts
that re-shape the slice:

- **A3/A4 need NO slot** — both rrb arms isolate the genuine range error inside a
  handler reached only after a successful literal-index extraction (a non-literal key
  exits stuck first: `reduction.rkt:2733`, `:2800`), and `expr-PVec` carries no arity
  and no tail, so there is no permissive counterpart at typing. Flipping them is local
  and type-free. Adversarial check: a nat-dyn ROW **does** exist (`map-dissoc` on a
  tuple; `record-project`'s miss is tail-gated only) but no route places an `expr-rrb`
  VALUE under one — the subject stays a stuck `expr-map-dissoc` and the open-tuple
  type has no surface spelling. **Consequence pinned deliberately: a DYNAMIC-index
  tuple OOB (types to ⋃positions, reaches reduction) becomes loud** — the static
  literal-index tuple pins are untouched (they error at elaboration).
- **The two rrb fallbacks DIFFER today** — `(expr-error)` at `:2731` vs stuck `e` at
  `:2798`: A3 and A4 are two different silences; the flip must unify them.
- **BOTH def seams are unchecked** — `driver.rkt:1907` (inferred) AND `:2112`
  (annotated). Q_N5's single-site framing was an under-count; B2's own pin is an
  annotated def. The `seal-forcing-error` guard directly above each is the template
  (the annotated path also `remove-failed-definition!`s).
- **The List leg is EXCLUDED from slice 2 (named, not silent)**: `expr-get`'s List arm
  CONFLATES "index is not a literal" with OOB — both fall to one `(expr-error)`
  (`:2742`), and a lambda body indexing a ground list is ALREADY destroyed to
  `<error>` at HEAD (a live pre-existing silent-wrong-value bug). It needs the
  literal/OOB split first; it rides the A1 decision round.
- **CARRIED-ALPHA'S COST GREW — A1 is HELD for its own ruling**: (i) six sites
  construct `expr-map-get` DURING REDUCTION (`:3123/:3144/:3157/:4175/:4192/:4205` —
  the get-in/update-in/broadcast-get lowering family), after typing is over, so their
  alpha is permanently unsolved: the "safe default" would BE that family's behaviour;
  (ii) the two nodes DELEGATE to each other in both directions (`:2704`, `:2725`), so
  the slot must go on BOTH or be dropped at the crossing; (iii) `expr-map-get`'s only
  pnet registration is `auto-cache!` — variadic, inside
  `with-handlers ([exn? void])` (`pnet-serialize.rkt:437-443`) — so a stale call is
  SWALLOWED and the node silently vanishes from the cache, unlike `expr-get`'s loud
  `reg2!`; (iv) `PNET_VERSION` 5→6 required same-commit (absent from pipeline.md's
  field checklist); (v) `qtt.rkt:1281`'s Map leg returns locally instead of
  delegating to `infer` — the infer/inferQ-twins class the adjacent arm's own comment
  records as already bitten; (vi) the elaboration mint is SIX sites, not one (five are
  compiler-synthesized get-in/update-in inlinings).
- **Slice-1 regression check CLEAN**: old exemption set (19) ∩ new positive set (20)
  = ∅, so new-#t ⊂ old-#t strictly — D22's panic guarantee preserved. Named
  side-effect (inert, conservative): `expr-float32/64` moved from fabricate-`none` to
  stuck.
- Pre-existing `expr-get` gaps inherited, filed: `expr-get?` ABSENT from the `expr?`
  predicate (`syntax.rkt:1346` — pipeline.md core item 1 unmet); ambient pipeline.md
  names `trivially-whnf?` which does not exist (the real predicate is `whnf-trivial?`,
  `reduction.rkt:1795`).

**Slice 2 scope as ruled [owner]: A3 + A4 (both rrb arms → panic, unified) + BOTH def
seams (A7 + the annotated twin). A1 (the Map fork) and the List-leg split return as
their own decision.**

## §6 SRE lattice lens — REQUIRED (the result shape IS lattice-shaped)

*Completed against the settled surface (PS1–PS15).*

1. **Classification**: STRUCTURAL. A selection result is a row (labelled product of
   per-field VALUE lattices) indexed by a support set + key-domain + tail — the *same*
   carrier as the source, which is why the retype (§3.2) is available at all.
2. **Algebraic properties**: per-slot flat type lattice; support = powerset (Boolean);
   key-domain ∈ {keyword, nat} with the **homogeneous invariant** (Q_B) — CH-1 is precisely
   a consequence of that invariant meeting a mixed selector.
3. **Bridges**: source row → result row is a **projection**, and if selection is
   subset-projection (§1.1) then it is the α of a Galois connection whose γ is width
   subsumption — the D21 erasure-mode machinery already in place.
4. **Primary vs derived**: the SOURCE row is primary; the selection result is DERIVED
   (recomputable). Consequence: a selection must never be the only carrier of a fact.
5. **Hasse / parallel decomposition**: N independent leaf selections are N
   independently-converging cells; a nested rebuild is ONE joined value. **This is §4.14
   restated in lattice terms and it is the mantra-relevant half of the result-shape
   question** — flatten and path-keyed are the all-at-once shapes; mirror is the joined shape.

## §7 NTT model — REQUIRED if propagators/cells are added

**Resolved posture (PS11)**: v1 adds **ZERO propagators and zero cells** — the selection
node is typed imperatively through the existing arms, iteration/sections are lambda
sugar riding `map`'s existing machinery. The Network Reality Check for P4/P5 is stated
in advance: no `net-add-propagator` calls, no cell writes, no trace — and the phases'
commits must say so plainly (no propagator vocabulary). **The NTT model becomes
MANDATORY at the future dedicated-selector-node upgrade**, whose whole point is the
*one broadcast propagator, one fire, one merge* guarantee — that claim must be
`net-add-broadcast-propagator`-real, not vocabulary, and it gets its own mini-design
with the NTT model before any code.

## §8 Risks

- **R1 — inventing, not borrowing** (§4.10). No principal-typing result exists for typed
  deep multi-select. Budget design time accordingly; expect the elaborator, not preparse.
- **R2 — walker gaps** (§3.6). Building broadcast on `expr-broadcast-get` inherits a live
  silent-class gap. P2 precedes P5.
- **R3 — `.` on triple duty** (§4.12). WS-reader grammar audit required, both modes.
- **R4 — a green suite is not a correctness gate** for this class (`pipeline.md`
  § Exhaustive Walkers). Failing-test-first for anything walker-shaped.
- **R5 — the `.{` retirement is a behaviour change with live users** (§3.8); P1 needs its
  own census even though the owner has ruled the disposition.

## §9 Scope (ratified with D.2 under the round-5 delegation)

- **IN**: the surface + result typing + broadcast; the §3.5 prerequisite defects (they ARE
  the degenerate case the design generalizes); P1.
- **FILE SEPARATELY**: the `map-size`/`map-has-key` constant-rule unsoundness (§3.7) — an
  on-network typing-rule issue, not selection.
- **DESIGN, PHASE BEHIND**: deep-walker descent (nested `validate` / deep `:requires`) ·
  `selection` down-cast + `selection->requires-row` · the write direction.
- **SUPERSESSION (§4 REFUSE #9 says record it now)**: CIU **T2** (⬜, chartered to build
  `.{…}`→get-in) is **superseded outright**. CIU **T3** (⬜, chartered to make `expr-get`
  vestigial with per-segment path dispatch) — this track takes the **surface** half, T3
  keeps trait-dispatched resolution. CIU **T4** (⬜, "broadcast via Seq") stays separate.
  The CIU T0 audit already posed `m.users[0].name` as Map→PVec→Map needing three different
  traits per segment, naming first-class paths as the unifying abstraction — that is this
  design's problem statement, written in March.

## §10 References

- Predecessor / record decisions: [`2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md`](2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md) §2a D1–D29
- Carrier: [`2026-07-06_CIU_T6_F1_STRUCTURAL_RECORDS_DESIGN.md`](2026-07-06_CIU_T6_F1_STRUCTURAL_RECORDS_DESIGN.md) §4.1
- PIRs: [F1b](2026-07-19_CIU_T6_F1B_PIR.md) · [Rel T1](2026-07-25_REL_T1_PIR.md)
- First-Class Paths: [`2026-03-20_FIRST_CLASS_PATHS_DESIGN.md`](2026-03-20_FIRST_CLASS_PATHS_DESIGN.md) (Phases 0–7c; Lens Phase 8 deferred)
- CIU master: [`2026-03-21_CIU_MASTER.md`](2026-03-21_CIU_MASTER.md) (Tracks 2/3/4 + the T0 open questions)
- Prior art: Morris & McKinna POPL'19 · λ⟨⟩ TyDe'23 · Tang et al. OOPSLA'23 · Dhall #771 · Julia #19169 · Clojure 1.13 `:select`
- Rules: `prologos-syntax.md` § Reader · `pipeline.md` § Exhaustive Walkers · `structural-thinking.md` · `on-network.md`

---
*Stage-3 D.1 DRAFT, opened 2026-07-26. §5 is the live conversation; everything else is
grounded and citable. Next: the surface co-design round, then D.2 folding its rulings.*
