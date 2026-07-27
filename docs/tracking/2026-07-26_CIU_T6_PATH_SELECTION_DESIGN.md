# CIU Track 6 — Path Selection (Stage-3 Design, D.1 DRAFT)

**Status**: **Stage-3 DRAFT.** Grounding ✅ · prior art ✅ · **the SURFACE is OPEN** (§5 —
owner co-design conversation pending, deliberately not pre-empted here).
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
| S | **Surface co-design (OWNER CONVERSATION)** | 🔄 | **§5 — THE OPEN PIECE.** Blocks every phase below except P1 |
| P1 | `.{` full retirement + audit-example repair | ⬜ | **Owner-RULED 2026-07-26**: clean switchover, NO deprecation/diagnostic path. Surface-independent — can land first |
| P2 | Prerequisite defect repairs (§3.5) | ⬜ | tuple dynamic Int index · PVec silent OOB · the walker gaps. Each needs its own census |
| P3 | The selection NODE + elaboration | ⬜ | shape pending §5 |
| P4 | Result typing (the seed retype, §3.2) | ⬜ | shape pending §5 |
| P5 | Broadcast | ⬜ | shape pending §5 |
| P6 | Migration + supersession (§9) | ⬜ | `#p(…)` · `get-in`/`update-in` · `.*` · `selection` · CIU T2/T3 |
| X.close | **MANDATORY** — bench matrix · DEFERRED triage · doc-truth sweep · memory fold · **Stage-5 PIR** | ⬜ | The track does not flip ✅ until the PIR lands |

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

---

## §6 SRE lattice lens — REQUIRED (the result shape IS lattice-shaped)

*Provisional; completes when §5 settles.*

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

Pending §5. Trigger: if broadcast lands as §4.6's *one broadcast propagator, one fire, one
merge* guarantee, it is a propagator design and the NTT model is mandatory before
implementation (`workflow.md`). Note the Network Reality Check: F1b added **zero**
propagators; a broadcast selection would be Track 6's first, and that claim must be
`net-add-broadcast-propagator`-real, not vocabulary.

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

## §9 Scope proposals (owner to ratify)

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
