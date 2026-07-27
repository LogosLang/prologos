# UCS — Types-as-Predicates (`?x:Int` = `Int(x)` = domain-constrained logic vars)

**Date**: 2026-07-21 · **Home**: UCS series (Master:
[`2026-03-28_UCS_MASTER.md`](2026-03-28_UCS_MASTER.md), *Universal Constraint Solving*,
Stage 0/1 research) · **Status**: Stage-0 handoff/capture note — records what the **Rel
Track 1 Aspect C** arc settled about typed logic variables so a future UCS track can pick
it up "at the appropriate time." No implementation here.

**Sibling notes (the three altitudes — see §1)**:
[`2026-06-30_TRAITS_AS_REFINEMENT_TYPING_NOTE.md`](2026-06-30_TRAITS_AS_REFINEMENT_TYPING_NOTE.md)
(refinement, altitude 3) · this note (runtime domain-constraint, altitude 2) · the
static altitude (altitude 1) is Rel T1 Aspect C, **done**. Prior art:
[`../research/2026-03-16_NEXT_GEN_LOGIC_PROGRAMMING.tex`](../research/2026-03-16_NEXT_GEN_LOGIC_PROGRAMMING.tex)
§"Domain-Constrained Logic Variables"; infinite-domain method:
[`../research/2026-04-30_WIDENING_NARROWING_INFINITE_DOMAINS_FOR_UCS.md`](../research/2026-04-30_WIDENING_NARROWING_INFINITE_DOMAINS_FOR_UCS.md).

---

## 1. The vision — one surface, three altitudes (owner, Curry-Howard)

`?x:Int` is sugar for the predicate/clause **`Int(x)`** ("x satisfies Int"). By
Curry-Howard, predicates ARE types, so that clause-constraint IS the type `x:Int`. **One
surface text, three altitudes:**

| # | Altitude | Reading | Status |
|---|---|---|---|
| 1 | **static type** | `x:Int` — a compile-time type | Rel T1 Aspect C — **DONE** (see §2) |
| 2 | **runtime domain-constraint** | `Int(x)` — a goal that PRUNES the search (CLP-style) | **THIS note → UCS** |
| 3 | **refinement** | `Int@pos` — a refined predicate | traits-refinement note → UCS Track 5 |

**The load-bearing owner clarification (2026-07-21, closing Aspect C).** A **schema** is a
checked contract on **fact relations** (fully-ground, table-like data) — that is altitude-1
static validation, and it is what Rel T1 delivered (the highest-motivation work). But
**`?x:Int` on a rule's logic variable is NOT a static output-contract** — it is a **guard /
unary domain-constraint `Int(x)`** (altitude 2). Trying to statically type a rule relation
*by* its declared `?x:Int` param types is really the guard's *static projection*, sound only
once the guard prunes at runtime. That is genuinely larger design work (constraint solving
over value domains) and is **reserved for UCS** — hence this note.

---

## 2. What Rel T1 Aspect C SHIPPED (the substrate UCS inherits — verified @ `4e3b0343`)

The C-arc built the **parse-and-store** substrate and deliberately stopped before any
runtime activation ("the lowering to the runtime `Int(x)` goal is written WHEN UCS consumes
it" — relations.rkt:503-514). What's ready:

- **The `type-pred` value** — `(struct type-pred (preds) #:transparent)`, `preds : (listof
  expr?)` (relations.rkt:515). This is the object a UCS lowering **lowers FROM**. `?x:Int` →
  `(type-pred (list (expr-Int)))`. The `preds` slot is a **list** = a predicate SET
  (conjunction `Int(x) ∧ Even(x)`), mirroring the runtime side-table's list-per-var.
- **`param-info.type`** — `(struct param-info (name mode type) …)` + smart-ctor (default
  `#f`) via the `#:name`-redirect idiom (relations.rkt:529-532). **Store-only: 0 production
  consumers** of `param-info-type` today — UCS is the intended consumer.
- **Type-preds STORED on relational params** for `?x:Int` at BOTH reader→relation sites:
  `expr-rel->relation-info` (relations.rkt:937) + `expr-variant->variant-info`
  (relations.rkt:966), each wrapping the elaborated type-EXPR into `(type-pred (list ty))`.
- **The fused `?x:Int` / `x:Int` reader** — a PARSER-ARM change (tokenizer untouched), **both
  readers (WS + sexp) and both languages** (relational `parse-rel-params` 3-list carrier;
  functional `parse-binder` fused arms). Chained `?x:C1:C2` is **rejected with "reserve for
  UCS"** (parser.rkt); `::` module paths and spaced/bare `:` are excluded (fused single-token
  only).

**⚠ The asymmetry — one fused reader, two fates.** The **functional** side (`[fn [x:Int] x]`,
`binder-info.type`) is **ACTIVATED** (it reuses the existing typed-λ elaboration → the type
is enforced now). Only the **relational** side (`?x:Int` on `param-info`) is deferred to UCS.
So "deferred to UCS" is **relational-path-only** — the fused syntax works everywhere; only
its *domain-constraint activation on logic vars* is UCS's job.

---

## 3. The runtime lowering target — a REUSABLE mechanism EXISTS (but is a NEW bridge)

The altitude-2 reading is not greenfield: a `type-guard` narrowing mechanism already exists.
But it is **completely disconnected** from the C.a/C.b substrate — `'type-guard` appears
only in `global-constraints.rkt` + `narrowing.rkt` (zero references from the param-info /
type-pred path). **A UCS `Int(x)` lowering is NEW wiring bridging the C.a/C.b `type-pred`
(a type-EXPR on a param) to this runtime `type-guard` constraint (a type-NAME symbol on a
var).** Verified coordinates @ `4e3b0343` (they DRIFT — re-grep):

- **The lowering TARGET shape** (what the bridge must produce): `narrowing.rkt:639-647` emits
  `(narrow-constraint 'type-guard (list vn) tn)` — one per `(var, type-name)` pair, read from
  `read-narrow-var-constraints`. This is the exact struct a `type-pred → Int(x)` lowering
  must construct.
- **The runtime consumer**: `check-type-guard` (global-constraints.rkt:454-469, dispatched at
  :222-232): resolves the var in the substitution → **unbound ⇒ `'active` (defer)**; **ground
  ⇒ `value-matches-type?`** → mismatch ⇒ `#f` (contradiction, prunes the branch).
- **The side-table**: `current-narrow-var-constraints` — a `make-parameter` `var-symbol →
  (listof type-name symbol)` (global-constraints.rkt:75), installed by the elaborator via a
  **SETTER (not `parameterize`)** so it persists type-check → reduce (elaborator.rkt:3285-3292,
  strip-`?` var names). Any UCS lowering must preserve this persistence contract.
- **The existing surface** (the `?var:C1:C2` chain): `narrow-var-symbol?` (parser.rkt:6418-6423,
  `?`-prefix-gated), `narrow-var-base-name`/`narrow-var-constraints` (6445-6459, string-split a
  single glued symbol on `:`), collectors `collect-narrow-vars+constraints` (sexp, 6465-6484)
  / `collect-narrow-vars-from-items` (WS tree-parser, 894-902). Fires only in the `=`/`#=`
  goal path (parser.rkt:2926-2971).

### 3.1 Two `?x:Type` surfaces UCS must RECONCILE

There are now **two** `?x:Type` surfaces with opposite properties — UCS must unify them, not
lower into a vacuum:

| Surface | Reader | Chaining | Storage |
|---|---|---|---|
| **Query narrowing** (`= ?x:Nat:Even …`, Phase 3c) | **DEAD-IN-WS**, live-in-sexp | supports `?x:Nat:Even → (Nat Even)` | side-table → `type-guard` at runtime |
| **C-arc relational param** (`defr R [?x:Int]`) | **clean in both readers** | **rejects** chained (reserve for UCS) | `type-pred` on `param-info`, store-only |

*Dead-in-WS* is empirically confirmed: the WS tokenizer splits `?x:Even` → `?x` + keyword
`:Even`, so the collector's "`:` inside one lexeme" gate never fires and the constraint is
silently dropped (design §7.0; the exact hazard the C-arc's fused reader was built to fix).
The clean-WS C-arc surface is the natural unification point.

---

## 4. Known gaps + "don't corner UCS" constraints (carry these forward)

1. **The symbol-ceiling / down-projection gap (the core lowering task).** The runtime
   `type-guard` carries a type-NAME **symbol** (`tn`), but `type-pred` stores a type-**EXPR**.
   The bridge needs an `expr → type-name-symbol` down-projection — and a decision for
   **non-atomic** type-exprs (`<Int | String>`, parameterized types, refinements) which have
   NO single-symbol form in the current `value-matches-type?` match. This is exactly why the
   C-arc carries a type-EXPR (not a symbol): a symbol can never up-project to `Int@pos`; a
   type-EXPR down-projects to the symbol the runtime wants (design §7.2 symbol-ceiling).
2. **5-symbol runtime ceiling.** `value-matches-type?` (global-constraints.rkt:475-483) has
   working checks for **only 5 built-ins** (`Nat`/`Bool`/`Int`/`String`/`Unit`); all
   user-defined types fall through to `value-has-type-tag?` (:495-505), a **`#f` stub** ("exact
   matching would require the constructor registry from macros.rkt (not imported here)"). So
   `?x:UserType` runtime pruning is **unbuilt** — a ground value under it always yields
   contradiction. UCS must implement `value-has-type-tag?` (import the ctor registry) before
   user-type domain constraints work.
3. **Non-monotone cap → S(-1), not S0 (CALM).** The declared type is an UPPER BOUND that CAPS
   the join-of-positional-contributions — a **MEET / narrowing = non-monotone** (design §7.7).
   The on-network reading therefore belongs at a **RETRACTION stratum S(-1)**, NOT S0 monotone,
   else CALM is violated. Runtime corroboration: the `current-narrow-var-constraints` cell is
   `merge-last-write-wins` (**non-monotone**, global-constraints.rkt:103-104), unlike the
   monotone `narrow-constraints` list. **Named now specifically so UCS isn't cornered.**
4. **Domain-annotation reader gap.** The research-doc CLP surface is **spaced with rich
   annotations** (`?x : FD 1..10`, `?x : Real 0.0..100.0`); the C-arc fused reader stops at a
   **single token**. UCS's domain-annotation surface needs a reader extension beyond what C.b
   shipped (research roadmap step 3 is only partially satisfied).
5. **`Int` is an INFINITE domain.** Unlike CLP(FD)'s finite integers, `?x:Int` domain-constraint
   solving needs **widening/narrowing**, not finite arc-consistency (see the widening/narrowing
   research note). Refinement (`Int@pos`) additionally needs the `@` token (not lexed yet).

---

## 5. The immediate open question (Rel T1 C.d — confirm before opening UCS work)

Rel T1's "C.d" was going to feed the declared `?x:Int` param type to `relation-column-typer`
as a static upper bound (making un-schema'd rule relations typeable). Under the guard
reframing that is the guard's static projection. **Open question**: does the `?x:Int`-rule
STATIC typing **defer entirely to UCS** (sound only once the guard prunes at runtime), or do
we want a **"trust the declared guard statically now"** version (project the declared type as
an optimistic upper bound, unsound until runtime pruning catches violations)? The owner's
2026-07-21 call leaned **defer to UCS** — Aspect C's remaining static work is likely just the
C.c facts-only gate, with the rest of the `?x:Int` story living here. Nothing is lost by
deferring: C.b already STORES the type-preds.

---

## 6. Prior art + integration seam (reference, don't re-derive)

- **CLP(X) framing** — research doc §"Domain-Constrained Logic Variables" (§194-293):
  CLP(FD/R/Q/Set/Bool/S), `[?room : FD 1..10]` syntax, **arc-consistency IS propagator-network
  computation** (an FD var = a cell whose lattice is reverse-inclusion; domain-shrink = monotone
  narrowing; arc-consistency = a 2-in/2-out propagator), lattice instances, ATMS composition,
  implementation roadmap. **The roadmap already names the C-arc seam**: step 3 "Extend `?x:Type`
  syntax in the relational parser to accept domain annotations", step 5 "Connect to the existing
  `narrowing.rkt` infrastructure."
- **UCS Master Open Question #5** (2026-03-28_UCS_MASTER.md:78) — "relationship between `#=` and
  the solve engine; are relational queries special cases of `#=`?" — is directly on-point;
  this note partly answers it (the C-arc relational surface is one of the two `?x:Type` surfaces
  to unify).
- **The mantra / on-network**: the C-arc's registration-time storage is off-network scaffolding
  at Aspect-B parity; the on-network reading (arc-consistency propagators) is UCS's to build,
  respecting the S(-1) placement (§4.3).

## 7. References
- Rel T1 Aspect C design: [`2026-07-19_REL_T1_RELATIONAL_USABILITY_DESIGN.md`](2026-07-19_REL_T1_RELATIONAL_USABILITY_DESIGN.md)
  §7.0 (vision) · §7.2 (symbol-ceiling) · §7.5 (C.d reframing) · §7.7 (deferred + non-monotone cap) ·
  §7.8-§7.11 (C.a-C.c as-built). Substrate commits: C.a `b33474aa`, C.b.1 `6d793906`, C.b.2
  `c6b8e81f`, C.c `357035d5`.
- Grounding audits (the C-arc): `wf_8083a27e-2a9` (C surface), `wf_c8b8c25b-207` (C.b reader),
  `wf_2f21daa9-252` (C.c typing surfaces), `wf_42dda0ec-b9e` (this note's gather).
- UCS Master · traits-refinement note · CLP research doc · widening/narrowing note (front matter).
