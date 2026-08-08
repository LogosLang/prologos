# Compiling Prolog onto the Prologos Post-Elaboration IR

**Date**: 2026-05-04
**Status**: Stage 1 (research / vision capture)
**Scope**: Feasibility and feature-by-feature categorization for parsing Prolog source into Prologos's post-elaboration AST and compiling it onto the BSP-LE propagator network (post-PReduce).
**Context**: Prologos already has a relational language layer (`defr` / `&>` / `||` / `solve`) implemented as `expr-defr` / `expr-defr-variant` / `expr-clause` / `expr-fact-row` / `goal-desc` records, with clause execution running on a persistent BSP-LE propagator network (fork-on-clause for disjunction, ATMS for explanation, S1 stratum for NAF, tabling on by default). This research assesses how much of standard Prolog can land on that infrastructure with no, small, medium, or large additional work.
**Branch**: `claude/prolog-ast-propagator-research-oVsBN`
**Prior art**: [Phase 7 Relational Surface](../tracking/2026-02-25_PHASE7_RELATIONAL_SURFACE.md), [Relational Language Activation](../tracking/2026-02-25_RELATIONAL_LANGUAGE_ACTIVATION.md), [PReduce Master](../tracking/2026-05-02_PREDUCE_MASTER.md), [BSP-LE Master](../tracking/2026-03-21_BSP_LE_MASTER.md), [`RELATIONAL_LANGUAGE_VISION.org`](../tracking/principles/RELATIONAL_LANGUAGE_VISION.org).

---

## Table of Contents

- [1. Summary](#1-summary)
- [2. Architectural Caveats](#2-architectural-caveats)
- [3. Frontend (Prolog Reader)](#3-frontend-prolog-reader)
- [4. Compatible AS-IS](#4-compatible-as-is)
- [5. SMALL Additional Work](#5-small-additional-work)
- [6. MEDIUM Additional Work](#6-medium-additional-work)
- [7. LARGE Additional Work](#7-large-additional-work)
- [8. Suggested Staging](#8-suggested-staging)
- [9. Open Questions](#9-open-questions)
- [10. References](#10-references)

---

<a id="1-summary"></a>

## 1. Summary

Prologos's post-elaboration IR contains a **relational sub-language** that is conceptually a strict superset of pure (Datalog-style) Prolog clauses. The structural mapping is direct:

| Prolog | Prologos IR | Citation |
|---|---|---|
| Clause `H :- B.` | `expr-clause` (list of `goal-desc`) | `syntax.rkt:794`, `relations.rkt:411` |
| Predicate (set of clauses) | `expr-defr-variant` ⊇ `relation-info` | `relations.rkt:416-428` |
| Fact `p(a,b).` | `expr-fact-row` in `expr-fact-block` | `syntax.rkt:795-796` |
| Goal call `q(X)` | `goal-desc 'app` / `expr-goal-app` | `relations.rkt:912`, `syntax.rkt:797` |
| Unification `=` | `goal-desc 'unify` / `expr-unify-goal` | `relations.rkt:917`, `syntax.rkt:799` |
| `is/2` | `goal-desc 'is` / `expr-is-goal` | `relations.rkt:920`, `syntax.rkt:800` |
| `\+` / `not` | `goal-desc 'not` / `expr-not-goal` | `relations.rkt:923`, `syntax.rkt:801` |
| `!` (cut) | `goal-desc 'cut` / `expr-cut` | `relations.rkt:925`, `syntax.rkt:831` |
| Logic var `X`, `_` | `expr-logic-var` (mode `?`) | `syntax.rkt:798` |

A Prolog → Prologos pipeline therefore decomposes into four phases:

1. **Frontend** — Prolog reader + ISO operator-precedence parser (standalone, no Prologos changes).
2. **Term lowering** — map Prolog ground/compound terms to `expr-*` IR + `goal-desc` records.
3. **Clause compilation** — head pattern → `(= Param HeadTerm)` body prefix; multiple Prolog clauses for one predicate → multiple `&>` clauses in one `variant-info`.
4. **Built-in mapping** — ISO Prolog built-ins → Prologos goal kinds + functional escapes via `is`.

**Estimate**: ~95% of pure (Datalog) Prolog lands directly on existing IR. ~70% of ISO-7 Prolog lands with the SMALL/MEDIUM items from §§5–6. The remaining ~30% (dynamic predicates, attributed variables, CHR, full CLP) is paradigm-level mismatch and belongs under §7 LARGE — naturally co-evolving with the PReduce series and constraint-cell infrastructure.

The structural conclusion: **post-elaboration relational IR + BSP-LE + ATMS + tabling provides ~80% of what a Prolog backend needs**. A Prolog frontend on Prologos is best marketed as **"pure-logic Prolog with tabling on by default"** rather than drop-in `swipl` compatibility — the architectural differences (CALM-monotone, fork-not-stack, all-at-once parallel) are intentional design choices, not gaps to paper over.

---

<a id="2-architectural-caveats"></a>

## 2. Architectural Caveats

These shape every category below and must be flagged up front because they are *intentional design choices* in Prologos that diverge from standard Prolog semantics. They are not bugs to be fixed.

### 2.1 Tabling is the default

Prologos tables relations by default (`relations.rkt:428`, `relational-demo.prologos:187-189`). Prolog's depth-first SLD with sequential clause trial is the *exception*, not the norm. Programs that depend on Prolog's left-to-right termination ordering (e.g., recursive predicates that terminate only because the first clause is tried first), or that use `findall(_, solve_with_side_effect, _)` for ordered side effects, will not behave identically. A per-relation `:no-table` opt-out directive is needed for faithful Prolog conformance.

### 2.2 CALM-monotone network

The propagator base is monotone — cells only accumulate information (`on-network.md`). Mid-solve `assert` / `retract` contradicts on-network monotonicity. Dynamic clause modification is possible *only* via the topology stratum + S(-1) retraction (`stratification.md`) at quiescence boundaries, never mid-clause. This is the single biggest semantic gap relative to ISO Prolog.

### 2.3 Backtracking ≠ Stack

Prologos forks the persistent network at clause choice (`relations.rkt:128`); backtracking is collapsed into structural sharing via CHAMP. Prolog's stack-based backtracking with explicit choice-points doesn't exist. Cut semantics (`!`) translate to *retracting sibling assumptions on the parent goal's worldview*, not popping a stack — a different operational model that needs careful semantic alignment.

### 2.4 Closed goal-kind set

The runtime goal kinds are fixed: `'app | 'unify | 'is | 'not | 'cut | 'guard` (`relations.rkt:408`). New goal kinds are an IR change touching the full pipeline (`pipeline.md` checklist). Several Prolog built-ins (`==`, `@<`, `freeze/2`, etc.) want first-class goal kinds rather than living as built-in `defr` clauses — an IR-level cost decision case-by-case.

### 2.5 Solver-domain term representation

Solver-domain terms are flat: `(list tag arg1 ... argN)` after `normalize-term-deep` (`reduction.rkt:175-193`, `relations.rkt:366-367`). Compound ground terms work natively. Building compound terms from logic-variable lists at solve time (Prolog's `=../2` in *constructive* mode) needs new runtime support for "deferred constructors" — a term shape that is structurally a compound but whose arguments contain unbound cells.

---

<a id="3-frontend-prolog-reader"></a>

## 3. Frontend (Prolog Reader)

The Prolog reader is a standalone task, independent of Prologos's IR. It produces Prologos surface forms (`surf-defr`, `surf-clause`, etc.) which then elaborate normally.

### 3.1 Reader components

- **Operator-precedence parser** for ISO operators (`xfx/xfy/yfx`, `fx/fy`, `xf/yf`). Standard implementation; ~500-1000 LoC for a competent ISO-conformant subset.
- **Static `op/3` table** for the ISO built-ins (`,/2`, `;/2`, `:-/2`, `is/2`, `=/2`, `==/2`, `+/2`, `*/2`, etc.). Trivial to encode.
- **Dynamic `:- op(...)` directives**: the parser must update its operator table mid-file. Adds state but mechanical.
- **Term ↔ s-expr lowering**: `parent(alice, foo(X, [1,2|T]))` → Prologos surface form
  `(parent alice (foo X (cons 1 (cons 2 T))))`,
  then wrapped in the appropriate `surf-goal-app` / `surf-fact-row` / `surf-clause` shells.
- **DCG `-->` translation**: a mechanical preprocessing pass — add `S0`, `S` arguments, transform `[a,b]` to `S0=[a,b|S]`, handle `{Goal}` push-back. Frontend-only; no IR changes.
- **Directive handling**: `:- module(Name, Exports).`, `:- use_module(...)`, `:- table p/2`, `:- discontiguous p/2`, `:- dynamic p/2`. Translate to Prologos namespace declarations (`ns`, `imports`) and `defr` flags.

**Estimate**: ~1-2 weeks for an engineer producing an ISO-conformant subset reader, comparable in scope to existing Racket `#lang` readers.

### 3.2 Source-location threading

Surface IR nodes carry `srcloc` as their last field (`surface-syntax.rkt:949-1005`). The reader must populate `srcloc` from Prolog source positions so error messages point back to the Prolog file. Mechanical.

---

<a id="4-compatible-as-is"></a>

## 4. Compatible AS-IS

These features land directly on existing IR + runtime with no Prologos-side changes. Only the frontend reader is new.

| Prolog | Prologos IR | Citation |
|---|---|---|
| Fact `p(a,b).` | `expr-fact-row` inside `expr-fact-block` (`||`) | `syntax.rkt:795-796` |
| Rule `H :- G1, G2.` | `expr-clause` with goal list (`&>`) | `syntax.rkt:794` |
| Multiple clauses for one pred (OR) | Multiple `expr-clause` in one `variant-info` | `relations.rkt:420` |
| Conjunction `,` | List of `goal-desc` in clause | `relations.rkt:411` |
| Unification `X = Y` | `goal-desc 'unify` / `expr-unify-goal` | `syntax.rkt:799`, `relations.rkt:917` |
| Inequality `X \= Y` | `(not (= X Y))` desugar | `expr-not-goal` |
| Variables `X`, anonymous `_` | `expr-logic-var` (mode defaults to `?` free) | `syntax.rkt:798` |
| Atoms (ground) | `expr-fvar` / `expr-symbol` | `syntax.rkt:319, 564` |
| Numbers | `expr-int`, `expr-rat`, `expr-nat-val` | `syntax.rkt:318+, 871` |
| Strings | `expr-string` | `syntax.rkt:591` |
| Lists `[H|T]`, `[1,2,3]` | `cons`/`nil` inductive (constructor fvars) | `reduction.rkt:50-82` |
| `is/2` | `goal-desc 'is` (already calls `whnf`) | `relations.rkt:106-109, 920` |
| `\+ G`, `not G` (ground args only) | `goal-desc 'not` / S1 NAF stratum | `syntax.rkt:801`, `relations.rkt:116-243` |
| Recursive predicates | Native; tabling guarantees termination | `relational-demo.prologos:187-189` |
| `true`, `fail` | Empty body / failed unification | trivial |
| Arithmetic via `is` (`+`, `-`, `*`, `/`) | `expr-generic-add` etc. behind `is` | `syntax.rkt:261-276` |
| Comparison via guard (`<`, `>`, `=<`, `>=`) | `goal-desc 'guard` calling functional `gt`/`lt`/`eq` | `syntax.rkt:832`, `relational-demo.prologos:259` |
| Module-qualified calls `mod:goal` | `prologos::mod::goal` namespace path | `namespace.rkt:1-12` |

**Datalog-fragment Prolog** — facts, rules, conjunction, disjunction-via-multi-clause, recursive predicates, arithmetic via `is` — is essentially a thin syntactic skin over `defr` + `||` + `&>`. The first useful end-to-end Prolog frontend is achievable purely from this layer.

---

<a id="5-small-additional-work"></a>

## 5. SMALL Additional Work (≈ days)

Each item is a localized addition — frontend desugaring or a small built-in registration. Most require no new IR nodes.

### 5.1 Head pattern compilation

Prolog `length([H|T], N) :- ...` has variables and compound terms in the head. Compile to a `defr-variant` with bare params `[P1 P2]`, prepend `(= P1 [cons H T])`, `(= P2 N)` to the clause body. ~30 LoC pass on the IR side; standard WAM-style head normalization. Note: Prologos's existing `|` multi-arity already accepts head patterns directly (`relational-demo.prologos:404-407`), so an alternative is one variant per clause — the runtime does the discrimination already (`relations.rkt:445-523`).

### 5.2 In-clause disjunction `(G1 ; G2)`

Prolog allows nested `;`. Translate by clause-splitting in preparse: `(A, (B;C), D)` → two clauses `(A,B,D)`, `(A,C,D)`. Already covered by `&>` semantics. ~50 LoC frontend pass.

### 5.3 If-then-else `(Cond -> Then ; Else)`

Two clauses guarded by `Cond` / `not(Cond)` with `expr-guard`. Caveat: full Prolog semantics requires *committing* to the `Cond` proof (single-solution); use `solve-one`-equivalent inside the guard. Small pattern compilation.

### 5.4 Term comparison `==`, `\==`, `@<`, `@>`, `compare/3`

Either: (a) introduce a new goal kind `'identical` (small IR pipeline change — see `pipeline.md`), or (b) implement as a built-in `defr` over the normalized solver representation. Option (b) is no IR change.

### 5.5 `functor/3`, `arg/3`, `=../2` (deconstruction)

In the *deconstruction* direction (compound is ground), these are read-only over the flat normalized term. New built-in goal-app handlers. The *constructive* direction is medium — see §6.3.

### 5.6 `copy_term/2`

Walk + alpha-rename across cells; reuse existing variable-freshening machinery from clause instantiation.

### 5.7 `findall/3`

Wrap `expr-solve` and project a single binding into a list. `bagof/3` and `setof/3` add a key-grouping/sort pass.

### 5.8 `call/N`

Meta-call. Prologos already has `expr-rel` (anonymous relations); add a goal-kind dispatch for "first arg is a relation value, append the rest". Small.

### 5.9 `between/3`, `succ/2`, `plus/3`

Write as plain `defr` clauses in a `prolog::compat` library. Pure userspace.

### 5.10 String/atom conversions

`atom_codes/2`, `number_codes/2`, `atom_chars/2`, `atom_length/2`. Wire to existing string/char ops in `syntax.rkt` (via `is`).

### 5.11 Static operator table

Hardcode the ISO Prolog operator table in the frontend reader. The dynamic `op/3` mid-file case is medium.

### 5.12 `write/1`, `nl/0`

Wire to `io-bridge.rkt`. Need a side-effecting goal kind or relational `is`-style escape. Small if we accept "side-effects emit at quiescence boundaries", which matches the propagator architecture.

### 5.13 Type tests

`number/1`, `atom/1`, `compound/1`, `var/1`, `nonvar/1`, `is_list/1`. Implement as guards calling functional predicates on the normalized term.

### 5.14 DCG `-->` translation

Frontend preparse pass. The translation is mechanical (add `S0`, `S` args, transform `[a,b]` to `S0=[a,b|S]`, handle pushback `{Goal}`). Frontend-only.

---

<a id="6-medium-additional-work"></a>

## 6. MEDIUM Additional Work (≈ weeks)

These touch the runtime, introduce new goal kinds, or require careful semantic alignment.

### 6.1 Cut (`!`) semantics on the propagator network

The `'cut` goal kind exists (`relations.rkt:925`) but its meaning under fork+ATMS needs nailing down. Prolog's cut is "commit to the choices made up to this point in the parent goal". On the fork-on-clause architecture, this means *invalidating* sibling clauses' assumption-ids on the parent worldview when the cut fires. Likely a topology-stratum action; interacts with the S(-1) retraction stratum (`stratification.md`). Validation work + correctness suite. Worth its own design doc — non-trivial because the parent-goal scope of cut must be tracked through nested calls.

### 6.2 `assert`/`retract` of *static* (compile-time) facts only

Allowed at module load, banned during solve. Frontend pass + relation-store update. (Full dynamic-during-solve is in §7.1.)

### 6.3 Dynamic compound construction `=../2` (constructive)

`T =.. [foo, X, Y]` when `T` is a logic var: requires the solver to materialize compound terms whose tag is a symbol but whose args contain unbound cells. Current normalized-term representation handles ground compounds; building them lazily out of cells needs a new term shape (or a thin "deferred constructor" wrapper that the unifier knows how to traverse).

### 6.4 Full ISO `is/2` arithmetic

`mod`, `rem`, integer floor/ceil/round/truncate, `**`, `gcd`, float conversions, `pi`, `e`, transcendentals, `atan2`, bit-ops. Surface-area work, not architectural. Wire to existing posit/quire/rat infrastructure where possible.

### 6.5 `catch/3` / `throw/1`

Prologos has elaboration-time error machinery (`errors.rkt`, `lang-error.rkt`) but runtime exceptions across a propagator network are non-trivial: an exception is non-monotone information that must invalidate a worldview without poisoning siblings. Maps to *eliminating the assumption-id of the throwing branch*. Plausibly a stratum but needs design.

### 6.6 NAF on non-ground goals (constructive negation)

Current `expr-not-goal` requires ground args (`relational-demo.prologos:23`); ISO Prolog's `\+` has the same restriction (floundering check), so this is "match Prolog's actual behaviour" for free — but full constructive negation is research-grade.

### 6.7 Tabling controls

`:- table p/1`, `:- discontiguous`, `:- multifile`. Add per-relation flags via directives. Existing `relation-info` already has a `tabled?` field (`relations.rkt:428`); plumbing the directive is small but the semantics (e.g., per-mode tabling, answer-subsumption) is medium.

### 6.8 Streams + `read_term/2` / `write_term/2`

Wire to existing IO bridge; `read_term/2` parses Prolog text at runtime — needs the frontend reader to be available as a runtime API. Medium.

### 6.9 `format/2`, `format/3`

Format-string interpreter. Standalone work.

### 6.10 Reflection: `clause/2`, `current_predicate/1`, `predicate_property/2`

Read-only views of the relation registry. The registry already exists (`relations.rkt:432-436`); exposing it as goals is medium because the surface needs to handle modes and partial bindings.

### 6.11 Coroutining: `freeze/2`, `when/2`, `dif/2`

Each maps naturally to a watcher propagator on the involved cells (set-latch pattern, `propagator-design.md`). The IR layer to express "this goal is suspended until cell X is non-bot" is new — a new goal kind plus dispatch to a propagator install. Medium because of API surface.

### 6.12 Module system bridging

SWI-style `:- use_module(library(lists))` → Prologos `imports`. Mostly path translation, but multi-file / re-export semantics differ.

---

<a id="7-large-additional-work"></a>

## 7. LARGE Additional Work (≈ months / its own design track)

These are paradigm-level mismatches. Each warrants its own series under the [Master Roadmap](../tracking/MASTER_ROADMAP.org).

### 7.1 Dynamic predicates (`assert`/`asserta`/`assertz`/`retract`/`retractall` mid-solve)

Conflicts with CALM-monotone propagator semantics (§2.2). Possible only via the topology stratum + S(-1) retraction at quiescence boundaries; requires a careful invariant that *between* quiescence rounds the relation is structurally constant. Programs that mix `assertz` with `findall` for stateful aggregation are fundamentally imperative and would behave subtly differently. **This is the single biggest semantic gap.** A faithful implementation is a research track, not an engineering task.

### 7.2 Attributed variables (`put_attr`/`get_attr`/`attr_unify_hook`)

The Prolog hook for CLP(FD), tabling implementations, and deep coroutining. Prologos's metavar-store + constraint-cell + propagators *can* express the same computational power, but the API surface and user-facing semantics are very different. A faithful Prolog-attributed-vars layer would be a significant engineering effort, plus the question of which Prolog idioms (e.g., user-defined `attr_unify_hook`) are even worth supporting given Prologos's typed-relations alternative.

### 7.3 CHR (Constraint Handling Rules)

Multi-headed forward-chaining rewrite rules. This is a good fit conceptually for the propagator network and **aligns with the PReduce series** (`MASTER_ROADMAP.org:513-520`), but it is its own implementation track. Treat as a future Prolog-compat *contribution* once PReduce lands — CHR rules are graph rewrite rules, exactly the formalism PReduce is targeting.

### 7.4 CLP(FD) / CLP(R) / CLP(Q)

Standard Prolog libraries with their own constraint algebras. Prologos has `interval-domain.rkt`, `expr-all-different`, `expr-element`, `expr-cumulative`, `expr-minimize` (`syntax.rkt:823-826`) — a starting point — but a Prolog-API-compatible CLP(FD) is a series unto itself.

### 7.5 Order-faithful SLD execution mode

A "no-tabling, depth-first, left-to-right" execution mode that matches `swipl` byte-for-byte, including non-termination on left-recursion, side-effect ordering, and `findall`/`setof`/`bagof` snapshot semantics. This is a fundamentally different scheduler — it pulls *against* the design mantra ("all-at-once, all in parallel"). Possible as a per-module backend toggle, but architecturally retrograde; better treated as "Prolog conformance test mode" rather than the production path.

### 7.6 Full ISO error system

ISO-Prolog has a closed taxonomy of error terms with strict conformance behaviour (`type_error`, `instantiation_error`, `domain_error`, etc.). Achievable but tedious; gating SWIPL test-suite passage.

### 7.7 Tabling subsumption + answer-tabling subtleties

Variant tabling vs subsumptive tabling, modes-directed tabling, abstraction operators. Out of scope of a "compile to Prologos relations" effort; part of a Prolog-grade tabling subsystem.

---

<a id="8-suggested-staging"></a>

## 8. Suggested Staging

If pursued, the natural stages are:

### Stage A: Datalog-grade frontend

No cut, no NAF, no arithmetic — just facts, rules, conjunction, disjunction, recursive predicates. Lands almost entirely on existing IR (§4). Validates the whole pipeline end-to-end. Estimated effort: 1-2 weeks (mostly the reader).

**Deliverable**: a `.pl` file containing pure Datalog (e.g., classic family/ancestor) compiles and runs via `solve`. The acceptance test is the `relational-demo.prologos` ancestor example written in Prolog syntax.

### Stage B: Pure-Prolog-grade frontend

Adds `is/2`, `=`/`\=`, NAF on ground args, basic comparisons, head pattern compilation, in-clause disjunction, if-then-else. All SMALL items (§5). Estimated effort: 2-3 additional weeks.

**Deliverable**: classic Prolog example programs (n-queens via generate-and-test, list manipulation, simple parsers) run unchanged.

### Stage C: ISO-Prolog conformance subset

Adds cut semantics, `=..`, `functor`/`arg`, `findall`/`bagof`/`setof`, full arithmetic, `catch`/`throw`, DCGs. Most MEDIUM items (§6). Estimated effort: 6-10 additional weeks. Each MEDIUM item is its own design doc + implementation pass.

**Deliverable**: substantial fragment of the ISO Prolog test suite passes; SWI-style example programs from "The Art of Prolog" (Sterling & Shapiro) run.

### Stage D: Beyond ISO

Dynamic predicates, attributed variables, CHR, CLP. Each is a separate series, naturally co-evolving with PReduce (§7.3), the constraint-cell infrastructure (§7.4), and SH (self-hosting). Each is months of work and crosses architectural boundaries.

**Recommendation**: pursue Stages A+B as a single track ("Prolog Frontend, Stage 1"), gate Stage C on validation of cut semantics on the propagator network, and treat Stage D items as opportunistic when the underlying series (PReduce, constraint engine) deliver.

---

<a id="9-open-questions"></a>

## 9. Open Questions

These are flagged for future design discussion, not decided here.

### 9.1 Cut on a fork-not-stack architecture

What is the precise semantics of `!` when clauses are forked into independent network snapshots rather than tried sequentially with a choice-point stack? The naive translation — "invalidate sibling assumption-ids of the parent goal's worldview" — is plausible but needs a small-step semantics worked out, plus a correctness proof that it agrees with ISO cut for the cases where ISO cut is well-defined. Worth its own design doc before Stage C.

### 9.2 Tabling default — opt-in or opt-out for Prolog mode?

If Prologos tables by default but Prolog's standard semantics is non-tabled, do we (a) flip the default for `prolog` modules to non-tabled, (b) keep tabling on and warn users about behavioural divergence, or (c) detect at compile time which predicates are termination-sensitive and table only those? Each has tradeoffs; (c) is the most ambitious but most aligned with Prologos's "tabling guarantees termination" pitch.

### 9.3 Side-effect ordering

Prolog programs commonly use `write/1` + `nl/0` for output ordering (e.g., printing answers as they are found in `findall`). Propagator networks fire all-at-once and reach quiescence; observable side effects must be deferred to quiescence boundaries via the effect stratum (`EFFECTFUL_COMPUTATION_ON_PROPAGATORS.org`). This is fine for batch programs but a behavioural difference for interactive or order-sensitive Prolog code.

### 9.4 Goal-kind set vs built-in `defr`

Several Prolog built-ins (`==`, `@<`, `freeze`, `dif`) want first-class goal kinds rather than living as built-in `defr` clauses. Adding a goal kind is a full pipeline-checklist change (`pipeline.md`); not adding them means slower (maybe substantially slower) execution. A cost-vs-clarity decision case-by-case.

### 9.5 Compound-term cells

Does `=../2` in constructive mode (§6.3) want a new term shape, or can it be expressed as a deferred-construction propagator that fires when the list is ground? The latter is more uniform with the propagator architecture; the former is faster.

### 9.6 Marketing

Should this be marketed as **"Prologos as a Prolog backend"** (Prolog-faithful, conformance-driven) or as **"Prolog-as-Prologos"** (typed, parallel, tabled-by-default — a *better* Prolog with surface compatibility)? The architectural honest choice is the latter; the documentation/onboarding implications differ substantially.

---

<a id="10-references"></a>

## 10. References

### Prologos source

- `racket/prologos/syntax.rkt` — Post-elaboration IR (`expr-*` structs).
  - Relational forms: lines 791-832 (`expr-defr`, `expr-defr-variant`, `expr-rel`, `expr-clause`, `expr-fact-block`, `expr-fact-row`, `expr-goal-app`, `expr-unify-goal`, `expr-is-goal`, `expr-not-goal`, `expr-cut`, `expr-guard`, `expr-logic-var`, `expr-narrow`, `expr-relation-type`, `expr-solve`, `expr-solve-with`, `expr-solve-one`, `expr-explain`, `expr-explain-with`, `expr-goal-type`, `expr-solver-type`, `expr-solver-config`).
- `racket/prologos/surface-syntax.rkt:949-1005` — Surface relational nodes (`surf-defr`, `surf-clause`, `surf-facts`, `surf-fact-row`, `surf-solve`, `surf-explain`, etc.).
- `racket/prologos/relations.rkt` — Relation registry, goal solving, propagator installation.
  - `goal-desc` struct + kinds: line 408 (`'app | 'unify | 'is | 'not | 'cut | 'guard`)
  - `clause-info`, `fact-row`, `variant-info`, `relation-info`: lines 411-428
  - `expr->goal-desc`: lines 909-945
  - Discrimination infrastructure: lines 445-523
  - S1 NAF stratum handler: lines 116-243
  - Solver-cell infrastructure (`solver-env`, `solver-unify-terms`): lines 263-394
- `racket/prologos/reduction.rkt:50-82, 175-193` — List helpers, term normalization for solver domain.
- `racket/prologos/unify.rkt` — Dependent type unification with metavariable solving.
- `racket/prologos/namespace.rkt:1-12, 89-149` — Module system, namespace contexts.

### Prologos examples

- `racket/prologos/examples/relational-demo.prologos` — Comprehensive tutorial covering facts, rules, modes, schemas, explain, multi-arity.
- `racket/prologos/examples/2026-03-14-wfle-acceptance.prologos` — Well-founded NAF semantics.

### Prologos design docs

- [Phase 7 Relational Surface](../tracking/2026-02-25_PHASE7_RELATIONAL_SURFACE.md) — 26 expr-* relational nodes, 7-phase implementation.
- [Relational Language Activation](../tracking/2026-02-25_RELATIONAL_LANGUAGE_ACTIVATION.md) — Runtime activation.
- [Relational Fact Design](../tracking/2026-03-06_1400_RELATIONAL_FACT_DESIGN.md) — Fact block design.
- [BSP-LE Master](../tracking/2026-03-21_BSP_LE_MASTER.md) — Bulk Synchronous Parallel Logic Engine.
- [PReduce Master](../tracking/2026-05-02_PREDUCE_MASTER.md) — Reduction-as-rewriting series; relevant to §7.3 (CHR).
- [Logic Engine Design](../tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org) — Architecture reference (relations.rkt §7.4 cite).
- [Master Roadmap](../tracking/MASTER_ROADMAP.org) — All series and tracks.

### Prologos rules (operational discipline)

- `.claude/rules/on-network.md` — CALM-monotone design mantra (§2.2).
- `.claude/rules/propagator-design.md` — Set-latch fan-in pattern (§6.11).
- `.claude/rules/stratification.md` — S0/S1/S(-1)/topology strata (§6.1, §7.1).
- `.claude/rules/pipeline.md` — Exhaustiveness checklist for IR additions (§2.4, §5.4, §9.4).
- `.claude/rules/structural-thinking.md` — SRE lattice lens, Hyperlattice Conjecture.

### Principles docs

- [`RELATIONAL_LANGUAGE_VISION.org`](../tracking/principles/RELATIONAL_LANGUAGE_VISION.org) — Long-form vision for the relational language.
- [`EFFECTFUL_COMPUTATION_ON_PROPAGATORS.org`](../tracking/principles/EFFECTFUL_COMPUTATION_ON_PROPAGATORS.org) — Effect ordering on the network (§9.3).
- [`GÖDEL_COMPLETENESS.org`](../tracking/principles/GÖDEL_COMPLETENESS.org) — Termination guarantees per stratum.
- [`LANGUAGE_VISION.org`](../tracking/principles/LANGUAGE_VISION.org) — Overall language vision.

### External

- ISO/IEC 13211-1:1995 — *Information technology — Programming languages — Prolog — Part 1: General core*. The conformance reference for §7.6.
- Sterling & Shapiro, *The Art of Prolog* (MIT Press, 2nd ed. 1994). Standard example-program source for Stage B/C acceptance tests.
- Warren, *An Abstract Prolog Instruction Set* (1983). WAM head-pattern compilation reference for §5.1.
- Frühwirth, *Constraint Handling Rules* (Cambridge, 2009). Reference for §7.3.
