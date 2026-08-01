# Path Selection

**A selection algebra for key-valued trees** · Design specification v0.1 (pre-implementation seed)
Synthesized from design dialogue · 2026-07-28 · Target: Prologos / LHC

Every element below carries a status tag:

- **[ADOPTED]** — ruled in dialogue; normative for the v1 implementation pass.
- **[RECOMMENDED]** — argued and endorsed, awaiting explicit ruling.
- **[DEFERRED]** — deliberately out of v1; design direction noted.
- **[PROPOSED v2]** — concrete extension sketched, not in v1.
- **[OUTLOOK]** — long-horizon design context; shapes v1 choices but is not v1 work.
- **[OPEN]** — genuinely undecided; listed in §8.

---

## 1. Overview and design thesis

### 1.1 The key-sort thesis **[ADOPTED]**

Vectors and Maps are both *key-valued nodes*: a vector is keyed ordinally (by
position), a Map nominally (by keyword). Nested, they form a tree. Path
Selection is one algebra over both key sorts for selecting arbitrary subtrees,
renaming keys, and extracting values.

The sorts are unified but not identical. The refinement (§3.3):

> **Ordinal keys are contingent** — order carries the meaning, identity does
> not; selection *re-derives* them (a selected sub-vector is freshly indexed in
> selection order).
> **Nominal keys are essential** — identity carries the meaning; selection
> *preserves* them unless `^` says otherwise.

### 1.2 Two result disciplines, chosen per step **[ADOPTED]**

Most selection languages fix one of *extraction* (re-root at the target) or
*projection* (keep ancestry, prune siblings) globally. Path Selection makes it
a **per-step** choice via `^`:

- Inside a `{…}` block, a path **projects** by default — traversed keys and the
  leaf key are kept.
- `^` on any segment **dissolves that level**, splicing its content upward.
- A bare path in expression position (outside any block) **extracts** — the
  terminal value, unkeyed.

The idiom `ssl^.enabled^ssl` (dissolve two levels, resurrect one name) is the
canonical demonstration: real reshaping wants to keep some ancestry and
dissolve the rest *in the same query*.

### 1.3 Selection is demand **[ADOPTED — staged POST-V1 per Q_U3 (owner, 2026-07-30); chartered in D4 §5.P6, gated at X.close]**

Map leaves may be computed (`[now]`, `[env "DATABASE_URL"]`). A selection is a
*demand specification*: unselected computed leaves are never forced. In the
codata reading (§5.1) a Map is an object observed by copatterns, and a `{…}`
block is a finite set of copaths with renamings — selection is copattern
matching that also constructs. This is what ties the feature to the coinductive
anonymous-record typing that unlocked it.

---

## 2. Surface syntax

### 2.1 Operator table

| Form | Reading | Grade (§3.1) | Status |
|---|---|---|---|
| `x{…}` | select block; postfix juxtaposition, **no space** | — | **[ADOPTED]** |
| `.k` | nominal access (deeper level) | 1 | **[ADOPTED]** |
| `.N` | ordinal access (index) | 1 | **[ADOPTED]** |
| `:s` | broadcast: map one step `s` over this level, preserving its shape | ω | **[ADOPTED]** — incl. map-generic (§3.2.3, ruled 2026-07-28) |
| `k^` | key operator, continuation *empty*: dissolve/splice (mid-path) or mark keyless (leaf) | — | **[ADOPTED]** |
| `k^k'` | key operator, continuation *label*: rename `k → k'` | — | **[ADOPTED]** |
| `p^_` | key operator, continuation *synth*: key from surviving path, e.g. `a.b^_ ⇒ :a-b` | — | **[ADOPTED]** |
| `{a b}` | nominal n-ary selection (keys preserved) | — | **[ADOPTED]** |
| `{N M}` | ordinal n-ary selection (fresh indices, selection order) | — | **[ADOPTED]** |
| `.*` | row-splat: include all keys of the focus into the enclosing block | — | **[ADOPTED]** block position; path position **SUBSUMED** by map-generic `:` (ruled) |
| `*` | flatten one vector layer, postfix: `…:diags*:msg` | ω·ω→ω | **[ADOPTED]** |
| `<` | disclose/unwrap, in-step | — | **[ADOPTED v1]**, bare form only (§3.7) |
| `?φ` | filter | 0\|1 | **[DEFERRED]** (§7.1–7.2) |
| `#` | dedupe (collection → set) | — | **[DEFERRED]** (§7.1) |
| `..k` | recursive descent | — | **[DEFERRED]**, as schema-elaborated sugar (§7.4) |

### 2.2 Lexical notes **[ADOPTED, formalization OPEN]**

Three characters are juxtaposition-sensitive, i.e. whitespace decides their
reading:

1. `x{…}` (select block) vs `{…}` (map/block literal) — attachment by
   adjacency.
2. `a^b` (rename) vs `a^ b` (keyless leaf, then sibling branch `b`).
3. `x:k` (broadcast step) vs `:k` (keyword literal) — adjacency to a
   focus-bearing expression selects the broadcast reading.

This is consistent with house style but concentrates load on the tokenizer and
on error messages; a precise lexical grammar is an implementation deliverable
(§8, Q8). The mitigating fact: for `^`, the whitespace-ambiguous form and the
sort-mixing error (§3.3) coincide, so the confusing spelling is also the
ill-typed one.

---

## 3. Semantics

### 3.1 Steps and grades **[ADOPTED]**

Every step has a **multiplicity grade** — how many foci it yields per input:

- grade **1**: `.k`, `.N` — exactly one focus;
- grade **ω**: `:s` — one focus per key at this level, *shape preserved*;
- grade **0|1**: reserved for `?φ` and optional access `.k?` **[DEFERRED]**.

Grades compose by multiplication along a path (ω absorbing). The **result type
is the composition of preserved shapes applied to the focus type**: each ω step
contributes the shape of the container it traversed — `〈·〉` for a vector,
`{ρ ·}` (the row) for a Map. Corollary for all-vector paths: the number of
`〈…〉` layers in the result type equals the number of *unfused* ω steps.
Deleting a layer is only ever the explicit act `*`.

*Refinement noted for later:* grades can be sharpened to intervals
(`[1,1]`, `[0,1]`, `[0,ω]`, `[1,ω]` — the last yielding NonEmpty results),
matching Granule-style graded typing and the QTT semiring machinery already in
LHC. v1 needs only `{1, ω}`. **[OUTLOOK]**

### 3.2 Broadcast `:`

**3.2.1 Extent — one step.** **[ADOPTED]** `:` broadcasts exactly the *next*
step: a key, an index, or one block. After it, `.` operates on the whole
result; a further `:` re-enters per element.

```prologos
users:{0.userName^}.0   ;; ["Lisa"]              — .0 on the outer result
users:{0.userName^}:0   ;; @["Lisa" "John" "Mike"] — :0 per element
```

**3.2.2 Fusion (functor law).** **[ADOPTED]** Consecutive broadcasts share one
spine: semantically `fmap g ∘ fmap f = fmap (g ∘ f)`. Surface consequence:
`users:0:userName` has *one* result layer, not two — both `:`s traverse the
same outer vector. This law is the reason the layer-counting rule of §3.1
speaks of *unfused* ω steps.

**3.2.3 Map-generic broadcast.** **[ADOPTED — owner 2026-07-28 (was §8 Q1)]**
`x:s` where `x` is a Map: apply `s` to every value, preserve the keys.

```prologos
regions:host
;; {:eu "eu.example.com" :us "us.example.com" :ap "ap.example.com"}
```

Rationale: `:` is the ω operator — the load-bearing joint of the key-sort
thesis. `.k`/`.N`, `{a b}`/`{N M}`, and `^` are already sort-paired; a
vector-only `:` leaves the thesis decorative exactly where it matters. The
uniform reading is *"for every key at this level, keep the key, act on the
value."* Consequences if adopted:

- Path-position `.*` is subsumed (`.*.host` ≡ `:host`) and retires to
  block-only row-splat; bare `*` (flatten) then has no near-collision.
- Ruling B (§3.6) becomes *simpler* on the nominal side: keywise merge needs no
  spine witness — the keys are the alignment.
- Typing is a row-map (§5.3).
- Specter's `ALL` and `MAP-VALS` collapse into one operator.

### 3.3 Blocks and result sorts **[ADOPTED]**

A block's branches are either all **keyed** (result: Map) or all **keyless**
(result: PVec/tuple). Mixing is an **error**, checked level-locally (the same
rule applies inside each broadcast element).

- Keyed branches: output key = the branch's surviving head key after `^`
  processing; leaf keys are kept by default (projection).
- Keyless branches (`^`-terminated, or ordinal `{N M}`): tuple components in
  written order, ordinally re-keyed.
- **Honest nesting**: `{p₁^ … pₙ^}` denotes an n-tuple *always* — including
  n = 1 (`app-config{version^}` is the 1-tuple `["1.0.0"]`) and including
  under broadcast (`users:{0.userName^}` is `@[["Lisa"] ["John"] ["Mike"]]`).
  There is no implicit splice; the flat spellings exist (`users:0:userName`).
  Rationale: uniformity, the fusion law, and forward-compatibility with
  first-class selectors, where branch count becomes runtime-known.

### 3.4 The key operator `^` **[ADOPTED]**

One operator, three continuations. `^` consumes the key of the segment it
follows; the continuation says what happens next:

- **empty** — mid-path: dissolve the level, splice content upward; at a leaf:
  mark the material keyless (legal only in an all-keyless block, per §3.3).
- **`k'`** — that key. Legal mid-path, including *before* a broadcast:
  `admins^names:name^` renames the branch key and then traverses. **[ADOPTED]**
- **`_`** — synthesize the key from the surviving path (`a.b^_ ⇒ :a-b`).
  **Dropped means dropped**: `^`-dissolved segments do not contribute.

Collision remedies are `^k'` and `^_` (§3.6). Generalizing `^` from *replace*
to *set* (introducing a key onto keyless material) is the v2 door to pure
transposes — §7.3.

### 3.5 Flatten `*` **[ADOPTED]**

Postfix, after the step whose result it flattens; deletes exactly one vector
layer (ω·ω → ω), visibly:

```prologos
build.modules:diags*:msg    ;; @["unused import" "import cycle" "shadowed var"]
```

The algebra is a functor language that graduates to a monad only through this
explicit act — ambient flattening (jq) is the disease being avoided. Whether
`*` acts on Map layers is **[OPEN]** (§8 Q4); v1: vector layers only.

### 3.6 Merge — Ruling B **[ADOPTED]**

**Principle: merge where alignment is derivable; error where it would be
coincidental.**

Within a keyed block, group sibling branches by *output* key:

1. **Distinct output keys** coexist. (This is what keeps SoA expressible:
   `{admins^names:name^ admins^roles:role^}` never triggers a merge.)
2. **Same key, both values Map-shaped nodes**: merge keywise; recurse under
   these same rules. Alignment witness: the keys themselves — always
   derivable.
3. **Same key, both values broadcast results**: merge pointwise **iff the two
   branches have the identical source spine**; the per-element bodies then
   merge recursively. Otherwise: error. Alignment witness: both sides are
   fibers of *one* traversal, so indices correspond and lengths agree by
   construction. Zipping vectors that merely happen to be siblings has no
   witness and stays an error.
4. **Same key, at least one side a leaf**: **error**. Remedies: `^k'`, `^_`.
   The merge relation never inspects leaf *values* (naturality, §4 L5), so
   there is no "equal values merge quietly" rule.
5. **Keyless blocks**: no merging; components concatenate in written order.

**Working definition — source spine** **[ADOPTED, residuals OPEN]**: the
branch's sequence of source-directed steps (keys, indices, broadcasts) with all
`^`-continuations erased (renames are output-side and do not affect the
spine). When filters/slices arrive, they are spine content — differently
filtered traversals never pointwise-merge.

**Normalization theorem (target of proof):** `{p:a p:b} ⟶ p:{a b}` — factoring
the shared spine; every well-merged block normalizes so each ω step is shared
by all branches beneath it. This is the tree-shaped analog of nested
relational calculus query normalization. Under Ruling B the user-facing
equation `{admins:name admins:role} ≡ admins:{name role}` is a *theorem*, with
the right-hand side as normal form — not a user obligation.

**Rejected alternatives**, for the record: last-wins (GROQ `...`) corrupts
silently; cartesian product of generators (jq object construction) answers a
question nobody asked; unrestricted zip is partial under length mismatch.

**Monotone migration path:** strict-everywhere (all duplicate keys error) and
B-at-nodes/strict-at-ω are both shippable waypoints. Every error shipped today
can become a meaning later without breaking a working program — get the error
surface right first. Errors for the mergeable-but-unimplemented cases SHOULD
print the factored (normalized) spelling as the suggested rewrite.

### 3.7 Disclose `<` **[ADOPTED v1 — bare form only; owner 2026-07-28 (was §8 Q5)]**

An in-step unwrap: `users:<{0.userName^}` ≡ per element, apply the block, take
`.0`. Its virtue is positional: it lives *inside* the step and therefore never
interacts with broadcast extent (§3.2.1). The parameterized form `<(0 2)` is
rejected as redundant: depth-pick is `.0.2`, breadth-pick is `{0 2}`.

---

## 4. Equational theory

Laws the implementation should treat as normative (test-suite material) or as
proof targets:

- **L1 (Fusion / functoriality)** `x:f:g ≡ x` mapping the composite — consecutive
  broadcasts share one spine; result layers count unfused ω steps. **[ADOPTED]**
- **L2 (Factoring / normal form)** `{p:a p:b} ⟶ p:{a b}` when spines are
  identical (Ruling B case 3). Normal form: ω steps outermost-shared.
  **[ADOPTED]**
- **L3 (Node merge)** keywise Map merge is associative and commutative on
  disjoint keys; recursion well-founded on tree depth. **[ADOPTED]**
- **L4 (Sort homogeneity)** every block denotes exactly one of Map or PVec;
  checked level-locally. **[ADOPTED]**
- **L5 (Naturality)** every v1 operator is a natural transformation: it
  commutes with any transformation of leaf values. Free-theorem consequence:
  no rule of the algebra (merge included) may inspect leaf values. This is the
  formal line between the v1 core and the observational stratum (§7.1).
  **[ADOPTED]**
- **L6 (AoS/SoA)** with length-indexed vectors, the transposition
  `Vec n {a: A, b: B} ≅ {a: Vec n A, b: Vec n B}` is an isomorphism; the
  algebra spells both sides (§10.3) and the iso is the semantic content of an
  explicit `unzip` if one is ever surfaced. **[ADOPTED as fact; unzip OUTLOOK]**
- **L7 (Idempotent self-merge)** — undecided; see §8 Q6.

---

## 5. Typing

### 5.1 Blocks as copattern sets **[ADOPTED]**

A Map type is negative/codata: an object offering observations. A keyed block
typechecks by demanding each branch as an observation the (coinductive
anonymous) record type offers, recursively. This yields both the typing story
and the demand semantics (§1.3) in one move, and is why this feature waited on
codata-shaped record typing.

### 5.2 Result-type computation **[ADOPTED]**

Grades interpret as shape functors (§3.1): grade 1 contributes nothing, each
unfused ω contributes the traversed container's shape, `*` deletes one vector
shape, blocks contribute the computed row (keyed) or tuple type (keyless).
Display convention: `〈T〉` for PVec, rows as `{:k T …}`, later `?T` for
grade-0|1 results.

### 5.3 Heterogeneity: the meet rule **[ADOPTED]**

Broadcasting a nominal step over a heterogeneous vector `〈τ₁ | τ₂ | …〉`
requires the key in the **meet of the element rows** — coinductively: every
element must offer the observation.

```prologos
events:t   ;; @[:click :key :click] : 〈Keyword〉
events:x   ;; TYPE ERROR — element 1 offers no :x
```

The escape hatches (optional step `.x?`, filter-then-narrow) are both
grade-0|1 machinery — see §7.2 for why they should be designed once, together.

### 5.4 Row-map typing for map-generic `:` **[RECOMMENDED, with §3.2.3]**

`x:s` over `x : {ρ}` types as the row-map of `s`'s typing over `ρ` (precedent:
Ur/Web type-level `map`): result row = same keys, each field type pushed
through `s`; `s` must typecheck at every field type (until 0|1 exists,
failure is an error). Coinductive reading: every observation is transformed
pointwise.

---

## 6. Expressivity boundary map

Established by worked exercise (corpus in §10). **Inside the algebra**:
arbitrary reshaping with per-level dissolve; provenance keys (`^_`);
ω-aggregation that *preserves nesting*; one-axis transposes (AoS↔SoA, because
the nominal axis supplies statically-known branch keys via rename).

**The four walls**, each with its designated exit:

| # | Wall | Diagnosis | Exit | Status |
|---|---|---|---|---|
| W1 | Denormalizing joins — repeat a parent field into each child row (`@[{:module "core" :msg …} …]`) | data from two levels meeting in one output row is a *join*; nested form is expressible, flat form is comprehension territory (NRC conservativity) | none — defended as a **permanent border**; hand off to host comprehensions or a future binding form (`as`-variables), where every selection language eventually grows its comprehension organ | **[ADOPTED as border]** |
| W2 | Pure transposes — ordinal² (matrix) and nominal² (map-of-maps pivot) | branches would begin with ω and have no key to inherit; `^` replaces keys but never introduces them | generalize `^` to *set* (§7.3) + admit branch-initial `:`; alternatively free once selectors are first-class (rows/lengths statically known ⇒ elaboration) | **[PROPOSED v2]** |
| W3 | Heterogeneous projection — "the `x` of the clicks" | needs 0\|1 grade (optional access or filter-with-narrowing) | §7.2 — one 0\|1 design serving both doors | **[DEFERRED]** |
| W4 | Recursive descent | even *bounded* unrolling trips W3 (dir vs file rows differ); unbounded needs `..` | `..k` as schema-elaborated sugar expanding to a visible fold (§7.4); or user-space fixpoint over first-class selectors | **[DEFERRED]** |

---

## 7. Deferred and staged features

### 7.1 The observational stratum **[ADOPTED doctrine]**

`?φ` (filter), `#` (dedupe), and eventually sort/aggregate inspect *values*:
they break L5 naturality, need element equality/ordering, and change container
semantics. They are not wrong — they are a **different stratum**, to be added
with honestly weaker laws, never folded into the natural core. (Cautionary
precedent: PCRE bolted value-dependent features into a clean kernel and
forfeited its theory.) v1 ships the natural core only; every v1 law holds
globally with no carve-outs.

### 7.2 The 0|1 grade — one design, two doors **[DEFERRED]**

Filters (`?φ`, with prism-style narrowing on sum/kind fields) and heterogeneous
projection (`.k?` → `〈?T〉`) are the *same* grade arriving through different
doors. Design it once: interaction with broadcast (does a filtered traversal
compact? lengths become data-dependent ⇒ differently-filtered spines never
pointwise-merge — already anticipated in §3.6), interpretation functor
(Option), display (`?T`).

### 7.3 `^` as *set*; branch-initial ω **[PROPOSED v2]**

Generalize §3.4: `^` **sets** the key of the material it follows — to nothing
(bare), to `k`, or to path-synth (`_`) — *replacing* when a key exists,
*introducing* when none does. Then admit branch-initial `:`:

```prologos
m{:0^ :1^ :2^}                     ;; matrix transpose, as a tuple block
strings{:home^home :about^about}   ;; nominal pivot: by-language → by-page
```

Zero new symbols; closes W2. Both are also elaboration-closable once selectors
are first-class (the inner row / length is static).

### 7.4 Descendant `..` as schema-elaborated sugar **[DEFERRED]**

`..k` never enters the core: it elaborates against the statically known schema
into the finite set of concrete routes; on recursive schemas the
reachable-schema graph is finite, so elaboration produces a visible, costable
fold. The same schema-directed-elaboration move covers complements ("all but
`k`") and any future exotic operators: **rich surface, tiny core; soundness is
proved once, for the core.**

### 7.5 First-class selectors **[OUTLOOK, load-bearing]**

Selectors should reify as data (Datomic-pull-style), composable and storable —
homoiconicity practically demands it. Consequences already priced into v1:
juxtaposition-as-merge is the composition operator (Ruling B exists so
composed fragments touching the same region *mean* something — precedent:
GraphQL's selection-set field-merging rules, battle-tested against a decade of
fragment composition); honest nesting (§3.3) holds because branch count
becomes runtime-known; W2 and W4 gain elaboration/fixpoint exits.

### 7.6 Dynamic keys — three tiers **[OUTLOOK]**

When a rename target is a *runtime* string: (1) static labels — full row
precision; (2) runtime label + **erased freshness proof** at QTT quantity 0
(`rename : (k : String) → {0 pf : k ∉ dom ρ} → …`; Ur/Web shows such
disjointness obligations are usually inferable); (3) unknown provenance — the
output honestly degrades from `{ρ}` to `Map String T`. Tier 3 is a
positive/negative polarity shift, aligning with the existing Map/schema
polarity treatment.

### 7.7 Bidirectionality **[OUTLOOK]**

If selection is ever also update: a grade-1 path is a lens whose complement is
the one-hole context (the derivative of the schema functor), so put-back is
hole-filling; ω paths are traversals; blocks are lawful lenses iff their paths
are pairwise source-disjoint (decidable without filters — steps are
syntactic); overlapping blocks duplicate a source leaf, break PutPut, and
demote to getters. Nothing in v1 forecloses this — notably, Ruling B does not
(a last-wins merge would have).

### 7.8 The relational reading **[OUTLOOK]**

On the relational surface, `select(Tree, Path, Sub)` with modes: `(+,+,-)` is
the getter; `(+,-,+)` runs the algebra backwards ("at which paths does this
value occur"); descendant is transitive closure, essentially free; logic
variables in key position give pattern-matching-by-unification over tree
structure. An ω path denotes a producer — a session emitting foci — if
selection ever crosses into the process surface.

---

## 8. Open questions

1. **Map-generic `:`** (§3.2.3) — ✅ **RESOLVED: YES** (owner 2026-07-28;
   D4 §3). Path-position `.*` is subsumed; `.*name`'s migration target is
   `:name`; §5.4 row-map typing is in.
2. **Map output key ordering** — ✅ **RESOLVED: carrier-determined**
   (owner 2026-07-28; D4 ruling 2c). Neither source nor selection order is
   representable in the shipped carriers (type rows are canonically sorted —
   load-bearing for `equal?`-as-row-identity; values are champ-hash ordered).
   **Derived from §1.1's own key-sort thesis**: nominal key IDENTITY carries
   the meaning, order does not.
3. **Nominal → ordinal demotion order**: if a Map's keys are dropped into a
   tuple (keyless broadcast over a Map, or a future map-`^`), which element
   order? Requires a canonical key order or a prohibition.
4. **`*` on Map layers** — is there a nominal join (merge of `{ρ {ρ' ·}}`),
   or is `*` vector-only forever? v1: vector-only.
5. **`<` adoption** (§3.7) — ✅ **RESOLVED: ADOPTED in v1**, bare form,
   spelled `:<` in broadcast composition (owner 2026-07-28; D4 §3). It is
   also the designed unwrap remedy that makes honest nesting (§3.3) livable.
6. **Idempotent self-merge (L7)**: do *syntactically identical* sibling
   branches merge quietly (GraphQL merges same-name/same-args fields; the test
   is on selector syntax, not leaf values, so L5 naturality permits it), or is
   any leaf-level duplicate an error? Composition of first-class fragments
   favors yes; strictness favors no. Monotone either way (error → meaning).
7. **Spine identity, formally** (§3.6): confirm the erasure definition;
   decide α-questions as filters/slices arrive.
8. **Lexical grammar** for the three juxtaposition-sensitive characters
   (§2.2), including error-message obligations: sort-mixing and collision
   errors SHOULD print the normalized/remedied spelling.

---

## 9. Prior art and positioning

- **Specter** (Clojure) — the spiritual ancestor: composable navigators,
  select/transform symmetry. Path Selection adds per-step splice (`^`
  mid-path), in-algebra provenance keys (`^_`), and in-flight rename inside
  nesting; map-generic `:` would unify Specter's `ALL`/`MAP-VALS`. Specter's
  real superpower — first-class, user-extensible navigators — is recovered via
  §7.5.
- **Datomic pull** — tree-shaped selection *as data*, with `:as` renaming; the
  precedent for selector reification.
- **GraphQL** — output-directed selection with aliasing; its selection-set
  field-merging rules are the battle-tested analog of Ruling B. It cannot
  index vectors or compute paths.
- **JMESPath** — multiselect-hash `{alias: path}` is the rename-branch; its
  spec is worth raiding for null/absent propagation edge cases when 0|1 lands.
- **GROQ** — splat-with-override precedent; its last-wins merge is the
  cautionary tale Ruling B rejects.
- **jq** — the two cautionary tales: cartesian object construction, and
  ambient (implicit) flattening — answered here by Ruling B and explicit `*`.
- **JSONPath (RFC 9535)** — standardized, select-only: no reshaping, no
  rename. Path Selection is strictly ahead of the standard on expressiveness.
- **XPath/XQuery; XDuce/CDuce** — regular-expression tree types: the closest
  prior art for *typed* tree selection; also the "regex for trees" kernel that
  the stratification doctrine (§7.1) protects.
- **NRC / language-integrated query** (Buneman–Tannen–Wong;
  Cheney–Lindley–Wadler) — query normalization and conservativity: source of
  L2 and of W1's defense.
- **Remora / APL rank** — typed treatment of lifting; explicit `:` is the
  deliberate rejection of implicit broadcasting (NumPy's silent shape
  coercion).
- **Ur/Web** — type-level row `map` and inferred, erased disjointness proofs:
  precedent for §5.4 and §7.6.
- **Copatterns** (Abel–Pientka–Thibodeau–Setzer) — blocks as observation sets
  over codata (§5.1).
- **Bidirectional/tree lenses** (Foster et al.; one-hole contexts per
  McBride) — the §7.7 outlook.

---

## 10. Normative example corpus

Intended as executable test vectors. Fixtures in the Appendix. Computed leaves
are shown forced to indicative values.

### 10.1 Reshaping, splice, provenance — `app-config`

```prologos
app-config{server^.{ssl^.enabled^ssl port} version database^.pool-size}
;; {:ssl true :port 8080 :version "1.0.0" :pool-size 10}

app-config{database.*}          ;; {:database {:url <env> :pool-size 10}}
app-config{database^.*}         ;; {:url <env> :pool-size 10}
app-config{database^.{url pool-size}}
;; {:url <env> :pool-size 10}

app-config{version^}            ;; ["1.0.0"] : 〈String〉        (1-tuple; §3.3)
```

Negative:

```prologos
app-config{version^ server.port}     ;; ERROR — mixed keyed/keyless sorts (L4)
app-config{database^.{url port}}     ;; ERROR — :port not present under :database
app-config{server^.host database^.url^host}
;; ERROR — duplicate leaf :host (Ruling B case 4)
;; remedy: app-config{server^.host database^.url^db-host}
```

### 10.2 Broadcast, fusion, honest nesting — `users`

```prologos
users:0        ;; @[{:userName "Lisa" :age 30} {:userName "John" :age 25}
               ;;   {:userName "Mike" :age 35}] : 〈{:userName String :age Int}〉
users:0:userName        ;; @["Lisa" "John" "Mike"] : 〈String〉      (fusion, L1)
users:0:{userName}      ;; @[{:userName "Lisa"} {:userName "John"}
                        ;;   {:userName "Mike"}] : 〈{:userName String}〉
users:{0.userName^}     ;; @[["Lisa"] ["John"] ["Mike"]] : 〈〈String〉〉  (§3.3)
users:{0.userName^}:0   ;; @["Lisa" "John" "Mike"]          (per-element unwrap)
users:{0.userName^}.0   ;; ["Lisa"]                     (outer .0; extent §3.2.1)
```

### 10.3 Ruling B, factoring, AoS↔SoA — `app-config.admins`

```prologos
app-config.admins:name        ;; @["Alice" "Bob"] : 〈String〉      (extractive)
app-config{admins:name}       ;; {:admins @[{:name "Alice"} {:name "Bob"}]}

app-config{admins:name admins:role}       ;; merges: same key, same spine (B3)
app-config{admins:{name role}}            ;; ⟵ normal form (L2); both:
;; {:admins @[{:name "Alice" :role :super} {:name "Bob" :role :regular}]}

;; SoA — distinct output keys, no merge attempted (B1):
app-config{admins^names:name^ admins^roles:role^}
;; {:names @["Alice" "Bob"] :roles @[:super :regular]}
```

### 10.4 Flatten, nesting-preserving aggregation, W1 — `build`

```prologos
build.modules:diags*:msg
;; @["unused import" "import cycle" "shadowed var"] : 〈String〉

build{modules:{name diags:{sev line}}}
;; {:modules @[{:name "core" :diags @[{:sev :warn :line 12}
;;                                    {:sev :error :line 88}]}
;;             {:name "cli"  :diags @[{:sev :warn :line 7}]}]}

;; W1 (out of scope by design): @[{:module "core" :sev :warn} …]
;; requires repeating a parent field into child rows — a join; use host
;; comprehensions over the nested form above.
```

### 10.5 Map-generic broadcast — `regions`  *(conditional on §8 Q1)*

```prologos
regions:host
;; {:eu "eu.example.com" :us "us.example.com" :ap "ap.example.com"}
regions{eu us}          ;; nominal n-ary selection: {:eu {…} :us {…}}
```

### 10.6 Pure transposes — `m`, `strings`  *(v2; §7.3)*

```prologos
m.0    ;; @[1 2 3]           — a row
m:0    ;; @[1 4] : 〈Int〉    — a column
m{:0^ :1^ :2^}                     ;; v2: @[@[1 4] @[2 5] @[3 6]]
strings:home                       ;; (map-generic) {:en "Home" :de "Start"}
strings{:home^home :about^about}   ;; v2: {:home {:en "Home" :de "Start"}
                                   ;;      :about {:en "About" :de "Über"}}
```

### 10.7 Heterogeneity (W3) — `events`

```prologos
events:t     ;; @[:click :key :click] : 〈Keyword〉      (:t in the row meet)
events:x     ;; TYPE ERROR — element 1 offers no :x     (§5.3)
;; future, with 0|1: events:x?  ;; @[?10 ?nothing ?3] : 〈?Int〉
```

### 10.8 Recursion (W4) — `tree`

```prologos
tree.entries:name        ;; @["lib.pl" "core"]
tree{name entries:{name entries:name}}
;; TYPE ERROR — file entries offer no :entries (W3 compounds W4)
;; exits: schema-elaborated ..name (§7.4), or selector fixpoint (§7.5)
```

---

## Appendix — fixtures

```prologos
def app-config
  :name "MyApp"
  :date [now]                      ;; computed; forced only if selected (§1.3)
  :version "1.0.0"
  :server
    :host "localhost"
    :port 8080
    :ssl
      :enabled true
      :cert-path "/etc/ssl/cert.pem"
  :database
    :url [env "DATABASE_URL"]      ;; computed
    :pool-size 10
  :features @[:auth :logging :caching]
  :admins
    - :name "Alice"
      :role :super
    - :name "Bob"
      :role :regular

def users :=
  @[@[{:userName "Lisa" :age 30}]
    @[{:userName "John" :age 25}]
    @[{:userName "Mike" :age 35}]]

def build :=
  :modules
    - :name "core"
      :diags @[{:sev :warn  :msg "unused import" :line 12}
               {:sev :error :msg "import cycle"  :line 88}]
    - :name "cli"
      :diags @[{:sev :warn :msg "shadowed var" :line 7}]

def regions :=
  :eu {:host "eu.example.com" :port 443}
  :us {:host "us.example.com" :port 443}
  :ap {:host "ap.example.com" :port 8443}

def strings :=
  :en {:home "Home"  :about "About"}
  :de {:home "Start" :about "Über"}

def m := @[@[1 2 3]
           @[4 5 6]]

def events :=
  @[{:t :click :x 10 :y 20}
    {:t :key   :code "KeyA"}
    {:t :click :x 3  :y 9}]

def tree :=
  :name "src"
  :entries
    - :name "lib.pl" :size 4821
    - :name "core"
      :entries
        - :name "eval.pl" :size 12010
```

---

*End of v0.1. The intended first implementation increment: §2–§3 with strict
merge (the §3.6 monotone waypoint), the §10 corpus as the acceptance suite,
and §8 Q1–Q2 ruled before result equality is testable.*
