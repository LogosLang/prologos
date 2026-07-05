# Path Selection & Anonymous-Record (Map) Typing — Design (Stage 0/1)

**Status**: Stage 0/1 — vision capture + grounding. **Standalone tracking design document** (no parent series; owner, 2026-07-05).
**Date opened**: 2026-07-05
**Owner**: Zee Larson
**Motivating incident**: `m.{a.a1 b.b1}` reported a misleading "`.{ }` retired for mixfix" error (the `.{`→`.(` mixfix migration clobbered path-selection `.{`). Immediate fix landed (message reworded, [issue context](#immediate-fix)); the deeper desire is to **revisit Path Selection — gaps, ergonomics, and language-design changes** — together with **how anonymous records (`Map`) are typed**.

---

## §1 Purpose & scope

Two intertwined threads:

1. **Anonymous-record (`Map`) typing** — make `Map` behave as a first-class *anonymous record* with *structural / observational* typing (the type of `{:a 1}` is `{:a Int}`, so `{:a 1}.a : Int`), retiring the current opaque `Open` value type. `schema` remains the *closed / exact* record form; `Map` is the *open / anonymous* form.
2. **Path Selection** — a redesigned, ergonomic surface for selecting sub-trees out of nested records/collections in one line, with control over the *shape* of the result (leaves only / paths preserved / renamed / everything-at-a-level), postfix syntax, broadcast, and a possible **Array ⇄ Map** unification.

This document is the co-design home; it will grow through a grounding audit → design dialogue → phased implementation.

## §2 Owner's vision (captured 2026-07-05)

Faithful capture; reflections in §3.

- **V1 — Map = anonymous record; coinductive/observational typing.** `Map` should work like a dynamic-language record. The type of an anonymous record = the *observed* types/type-literals of the values at its keys. `Open` is "too weird" a name and, more importantly, erases the field types. `schema` already provides the closed/exact form. *Concrete goal*: `+ {:a 1}.a 1  ;; => 2 : Int` (today `:a` is typed `Open`, not the observed `Int`).
- **V2 — `_{ … }` postfix-juxtaposition selection syntax.** Replace the `.{ … }` surface with postfix juxtaposition: `{:a {:a1 1 :a2 2} :b {:b1 11}}{a.a2 b.b1}` — like postfix array indexing. Deep note: **Arrays/Vectors and Maps/Records are different perspectives on the same class of data structure** — a candidate for *unification* (indexed access over Nat-keys vs Keyword-keys).
- **V3 — broadcast selection.** Same postfix-juxtaposition syntax. Two ideas: (a) an explicit broadcast marker in first position inside the brackets — `'[{:a 1 :b 11} {:a 2 :b 22}]{+ a}  ;; => '[{:a 1} {:a 2}]`; (b) **implicit** broadcast — path-selection on a *collection of records* automatically maps over the collection (array-programming style).
- **V4 — result shape: keep the path/keys or not (owner genuinely unsure).** Selection should ergonomically preserve *any* portion of sub-trees: sometimes just leaf key/values; sometimes the *path* preserved alongside the leaf; sometimes everything at a level; sometimes a renamed key (`^`). **Open question: what syntax designates "keep the path/keys with the leaf" vs "flatten to leaves"?**
- **V5 — the typing payoff.** `{:a 1}.a` should observe `Int` (structural field projection), enabling `+ {:a 1}.a 1 => 2 : Int`. Ties V1 to a concrete, testable target.

*Background reading the owner flagged*: `haskellforall.com/2026/06/record-type-inference-for-dummies` (record type inference; row/structural records). *(Couldn't fetch — 403; anchor to it once the owner shares excerpts.)*

## §3 Initial design reflections (Claude — for dialogue, not decisions)

- **V1/V5 is structural / row-typed records.** The "observed types of the values at the keys" reading is exactly **structural record typing**, and open records are the **row-polymorphic** case (`{:a Int | ρ}`). This is well-trodden theory (the "for dummies" post is an accessible treatment), and it's the right frame: `Open` → a structural record type carrying per-key field types, with a row variable for the open tail. `schema` = a *closed* record (no row tail); `Map` = *open* (row tail). Field projection `m.a` then has the field's type, not `Open`. The design work is *how this hooks into Prologos's existing type lattice* (union types, `schema` registry, the quantale type lattice) without reintroducing the fragilities the tower avoided.
- **V2's Array⇄Map unification resonates with CIU.** Arrays are maps `Nat → v`; records are maps `Keyword → v`; both are indexed collections. A unified *indexed-selection* interface (postfix `coll{selector}`) is elegant and connects to the **CIU (Collection Interface Unification)** series' thesis. Worth checking whether the selection surface should be *one* mechanism dispatched by key-type (Nat-index vs Keyword-path) rather than two.
- **V3's explicit-vs-implicit broadcast is a real tension.** Implicit auto-broadcast (selection on a collection auto-maps) is array-programming-ergonomic (APL/J/K) but risks ambiguity (select-over-elements vs select-on-the-collection-itself). An explicit marker (`{+ a}`) is predictable but adds syntax. Prior art: jq's `.[]`, GraphQL selection sets, APL rank. Likely both are wanted (explicit as the always-available form; implicit as sugar where unambiguous).
- **V4 (result shape) is the crux, and it has rich prior art.** "Which sub-trees, and in what shape" is the same problem jq, GraphQL selection sets, XPath, and optics/lenses solve. The shape axis (flatten-to-leaves vs preserve-nesting vs preserve-path vs rename) wants a small, composable notation. One natural lever: *nesting in the selector mirrors nesting in the result* — `{a.b}` flattens the path to the leaf, `{a.{b}}` preserves one level of nesting — so the selector's shape *is* the result's shape. Rename `^` already exists. This is the piece to design most carefully.
- **The `.{`→`_{ }` move also resolves the collision** we hit: freeing `.{` from mixfix and moving selection to postfix `_{ }` removes the syntactic contention entirely.

## §4 Grounded current state (HEAD `4e56da1d`, verified)

- **Single-path dot-access works**: `m.a.a1` → `1`, `m.b` → `{:a1 1}`. But selected values are typed **`Open`** (`m.a.a1 : Open`), not the observed value type — the V1/V5 gap.
- **`.{ … }` postfix multi-select never worked**: it was *only ever* the mixfix form; the First-Class Paths example marks `app-config.{…}` with `;; ERROR ❌`. The recent `.{`→`.( )` mixfix migration then made `.{` emit a misleading "retired for mixfix" hard-`raise` (`parse-reader.rkt:2510` → `macros.rkt:5746`). **Immediate fix landed**: reworded to "`.{ … }` is not currently supported — postfix path-selection is under redesign" (`macros.rkt`), test updated (`test-mixfix-01.rkt`). <a name="immediate-fix"></a>
- **First-Class Paths** (design `2026-03-20_FIRST_CLASS_PATHS_DESIGN.md`) shipped Phases 0–7c: dot-access, broadcast `.*`, renaming `^`, `#p(…)` path literals, `get-in`/`update-in`/`selection`. Phase 8 (**Lens**) was deferred. Postfix object multi-select `expr.{…}` was left incomplete.

*(A grounding audit of the Map-typing / path-selection / records subsystem is the next step — see §6.)*

## §5 Open design questions

1. **Structural record types** — how does an anonymous-record type `{:a Int :b String}` (+ row tail for open) integrate with the existing type lattice, union types, and the `schema` registry? Is `Open` replaced by a structural type or a row variable?
2. **`schema` (closed) ⇄ `Map` (open)** — subtyping/coercion between them; can a `Map` flow where a `schema` is expected (and vice versa)?
3. **Selection surface** — `coll{selector}` postfix juxtaposition: grammar, precedence, interaction with application `[f x]` and existing `.` dot-access; does `.` single-access unify into it?
4. **Result shape (V4)** — the notation for flatten-to-leaves vs preserve-nesting vs preserve-path vs rename. **The hardest/most-open piece.**
5. **Broadcast (V3)** — explicit marker vs implicit auto-broadcast; how the selector distinguishes "over the collection" from "on the collection."
6. **Array ⇄ Map unification (V2)** — one indexed-selection mechanism dispatched by key type, or two surfaces? Relation to CIU + PVec.
7. **Field-projection typing (V5)** — how `m.a` gets the observed field type; interaction with the coercion-warning / open-world machinery that currently yields `Open`.
8. **Migration** — retire `.{` cleanly (it's now under-redesign); `#p(…)`, `selection`, `get-in`/`update-in` continuation.

## §6 Proposed approach

1. **Grounding audit** (workflow) of the current subsystem: Map/`Open` typing, First-Class Paths implementation, the reader path-grammar surfaces, PVec-vs-Map representation + CIU, and any structural-record/row-type support — to establish the baseline the design builds on.
2. **Design dialogue** (main-session, iterative) on §5, anchored by the owner's vision + the record-type-inference background.
3. **Stage-3 design doc + phased roadmap**, then implementation.

## §7 References

- First-Class Paths: `2026-03-20_FIRST_CLASS_PATHS_DESIGN.md` (Phases 0–7c; Lens Phase 8 deferred).
- CIU Series (Collection Interface Unification) — Array⇄Map unification angle: `MASTER_ROADMAP.org` § CIU.
- Record type inference background: `haskellforall.com/2026/06/record-type-inference-for-dummies` (row/structural records).
- Reader surfaces: `parse-reader.rkt` (`recognize-dot-lbrace` :748, dot-lbrace emission :2510), `macros.rkt` (`expand-mixfix-retired` :5744).

---
*Stage 0/1, opened 2026-07-05. Standalone tracking doc. Next: grounding audit of the Map-typing / path-selection subsystem, then co-design of §5.*
