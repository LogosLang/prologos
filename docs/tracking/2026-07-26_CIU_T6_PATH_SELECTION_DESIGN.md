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
| P2 | Prerequisite defect repairs, SPLIT at the mini-audit (`wf_2c99bc25-940`): **P2.a ✅ `ad75e57a`** — record-project Int gate (+ the pvec-nth discipline guard the audit found: widening alone would have silently flipped the Nat-only discipline, suite-invisible) · ground-expr? twins → generic transparent-struct fallback (`expr-substructs-all?` in syntax.rkt; union-of-metas defect closed; mult/level-meta posture ruled+pinned) · normalize-for-resolution union descent (the upstream capture gap) · broadcast-get whnf arm + definitely-not-map? exemption (minimal scope; bare-meta typing = P5). 14 tests failing-first; suite 9164/472/0. **P2.b ⬜ RULED (c) — the TWO-TIER PRINCIPLE (owner, round 7; spec in §5.10)**: PVec OOB (TWO divergent silent legs: expr-get→`<error>`, pvec-nth→stuck; + pvec-update/pop siblings) · List OOB · Map-miss shape (census: Option-wrap ≈ 35-40 tests + 6 stdlib×2 book twins + ~24 corpus sites, ergonomics ~5:1 against; keep-V-runtime-LOUD ≈ 2 test pins but needs the type-fork + has the top-node-only panic-counting bound; the runtime arm is TYPE-BLIND — rows/dicts share the champ) · map-get-on-nat-row (project-vs-refuse) | 🔄 | B1 legs stay failing-test-first; the map-tutorial TEACHES error-on-miss 3× (doc-truth rider) |
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
