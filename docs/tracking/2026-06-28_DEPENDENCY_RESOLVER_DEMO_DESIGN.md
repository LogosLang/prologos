# Dependency-Resolver Demo — Stage 3 Design (D.2)

**Status**: D.2 — independent P/R/M/S critique cycle complete (2026-06-28). 2 blocking defects caught (`Result`→`Validation`; relation-store granularity); P3 re-scoped to a slice + owned RPF track; D2 premise corrected. See §10 Critique Record, §11 Owned Tracks.
**Update 2026-06-30**: P1 (JSON numbers) spawned a **dedicated Numerics track** — owner decision: JSON decimals → real IEEE `Float` (full compute primitive), and the numeric tower reconceived as refinement-via-`trait`. **P1 now BLOCKS on it.** See §11 + [`2026-06-30_NUMERICS_TRACK_CHARTER.md`](2026-06-30_NUMERICS_TRACK_CHARTER.md). Also settled: unwrapped `solve` at top level is the correct convention (no outer parens).
**Date**: 2026-06-28
**Series/Track**: **DEMO Series, Track 1** (confirmed 2026-06-28) — a *standalone demo/dogfooding track*. The demo is the forcing function; enabling fixes are filed against the owning series (IO, Relational, Session) as we hit them.
**Tracking**: `docs/tracking/2026-06-28_DEPENDENCY_RESOLVER_DEMO_DESIGN.md`
**Methodology note**: org-mode is the methodology's stated preference for design docs; this uses `.md` to match the de-facto convention of dated design docs in `docs/tracking/` (e.g. `2026-03-05_IO_LIBRARY_DESIGN_V2.md`).

---

## §1 Purpose & Scope

Build a runnable, multi-paradigm Prologos program — a **software dependency resolver** — that exercises the **Process**, **Relational**, and **Functional** paradigms end-to-end through a single shared contract (`schema`), and use it as a **dogfooding forcing function** to surface and close real language gaps.

The demo `.prologos` program **is** the acceptance instrument (per `ACCEPTANCE_FILE_METHODOLOGY.org`): target expressions that don't run yet are committed as commented blocks and uncommented as phases land. The track is not done until the file runs at Level 3 (via `process-file`) with 0 errors.

**In scope**: pure-Prologos JSON parser; schema validation → `Result` with type coercion; runtime relational fact loading (`:from`); process-layer file IO (file-as-session-channel); recursive graph queries with subquery reuse; named session composition (a session type in another's continuation).

**Out of scope (deferred)**:
- **Channel delegation** (passing a channel of one session type over another) → its own track in a future **Process-Language (PL) Series**.
- **SQLite / larger DB ingestion** → `IO_LIBRARY_DESIGN_V2.md` Phases G/J; gated on sub-process infrastructure + deeper fact representation (owner's stated sequencing).

## §2 Grounding Inputs (verified at HEAD `d7f9daf`)

Five parallel HEAD-pinned audits + direct reads. Feasibility per ingredient:

| Ingredient | Status | Evidence |
|---|---|---|
| Read+parse **CSV** from disk | 🟢 runs | `core/csv.prologos` (FFI to `io-ffi.rkt`), `read-csv` cap-gated; `read-file` real Racket IO (`io-ffi.rkt:86`, `test-io-file-01.rkt`) |
| **`schema`** decl + typed maps + dot-access | 🟢 / 🟡 | parse+registry+type-inference solid; schema-typed `defr : Schema` shown **commented** in `relational-demo.prologos:446` — verify at L3 |
| **Relational** `defr`/`solve`/recursive/joins/`is`/NAF(ground) | 🟢 runs | `relational-demo.prologos:555` (course graph live), `tests/test-relational-e2e.rkt` |
| **Session** decl/`defproc`/send-recv/choice/`rec`/`dual` | 🟢 runs | `tests/ws-session-e2e-01..03.prologos` |
| **Functional-layer IO** at runtime | 🟢 runs | `io-ffi.rkt:86` → `file->string`, `call-with-output-file`; verified `test-io-file-01.rkt` |
| **Process-layer IO** (file-as-session-channel) | 🟢 runs | `proc-open path : FileRead` → effect-executor (`effect-executor.rkt:61`); `test-effect-executor-01.rkt`, `test-io-boundary-01.rkt` |
| schema **validation → `Result`** + coercion | 🟡 thin | check-preds **panic** (not `Result`); `:check` parses **sexp-only**; **no string→typed coercion**; no `validate : Map→Schema→Result` |
| **JSON parser** (user-facing) | 🔴 absent | `json` exists only in internal Racket trace/perf serialization |
| **Dynamic fact assertion** (`:from`/`:source`) | 🔴 designed-not-built | facts are static `||` blocks; **surfaces already specified** (below) |
| Session **named composition** (continuation = named protocol) | 🟡 partial | `parser.rkt:5269` handles sessions; gap = **elaborator integration of `surf-sess-ref` in continuation + no L3 example** (R-lens: NOT a WS-preparse issue) |
| Session **channel delegation** | 🔴 not built | multi-channel `new`/`par`/`link` incomplete → deferred |

**This is not a blank slate — the target surfaces are already designed:**
- `2026-03-06_RELATIONAL_FACT_DESIGN.md` — schema as compile-time named-key↔index bijection; flat-vector fact storage; §6.2 bulk import.
- `RELATIONAL_LANGUAGE_VISION.org:835` — **`defr R : Schema :from <data>`** and `:source "file"` surfaces (marked "deferred infrastructure").
- `IO_LIBRARY_DESIGN_V2.md` — Phase J (relational integration; **J3 bulk loading as relation facts**), `main`-as-Powerbox (§7), IO-as-session-type (§4), `to-json`/`from-json` (§5.4).
- `PROTOCOLS_AS_TYPES.org` — "protocol composition through **named continuations**" (the named-composition design).

**Key reframe (Process-IO grounding)**: IO in Prologos is **already session-typed**. A file read is `proc-open "f.json" : FileRead` then `data := ch ?`. This means *"a session type in the continuation of another session"* falls out naturally: a `FileRead` session whose continuation is the `Resolver` protocol.

## §3 Progress Tracker

| Phase | Deliverable | Resolves gap | Status | Notes |
|---|---|---|---|---|
| **P0** | Acceptance demo skeleton `.prologos` + dataset (`packages.json`, `deps.csv`); green sections run, gaps commented | look-and-feel baseline | ✅ | **runs 0 errors / ~30s at L3**; 5 gaps surfaced — §12 |
| **P1** | `prologos::core::json` pure-Prologos parser + `data Json` ADT; `parse-json : String -> Result Json` | #1 no JSON | ⛔ **BLOCKED on Numerics** | JSON decimals → `JFloat Float` (owner 2026-06-30); needs Float + exponent-lexing from the [Numerics track](2026-06-30_NUMERICS_TRACK_CHARTER.md) (N1+N3) |
| **P2a** | Stdlib `data Validation {A E}` — accumulating applicative (`Result` short-circuits) | validation defect (S-lens) | ⬜ | prereq for P2b; owned by stdlib/data (§11) |
| **P2b** | Per-schema validator consuming on-network `schema-field-*` metadata → `Validation Record [List FieldError]`; `Json → target` coercer family | #2/#4 | ⬜ | validation = **parsing, not type-check** (S-lens); pure-Prologos vs `validate` primitive = P2-time sub-fork |
| **P3** | **Scoped first slice**: per-relation `monotone-set` fact cell (reuse `merge-set-union`) + single-shot runtime `:from` load propagator | #5 (headline, sliced) | ⬜ | real on-network `:from` (one load); **NTT model required**; incremental/retraction/off-param = RPF track (§11) |
| **P4** | Process-layer ingest via file-as-session-channel at L3; `main`-as-Powerbox capability entry | Process-IO real at L3 (R-lens: unproven) | ⬜ | first L3 file IO — *prove it*, don't assume |
| **P5** | Graph queries + subquery reuse (`depends-trans`, `risky-dep`, diamonds) | the payoff | ⬜ | reachability **fixpoint** via tabling (runs today) |
| **P5b** | `explain` **provenance** for the audit — first L3 derivation-tree run | provenance showcase | ⬜ | exists in `.rkt` tests only (R-lens) → P5b = its first L3 proof |
| **P6** | `Resolver` session w/ named continuation `Audit` — **elaborator integration** of `surf-sess-ref` + L3 example | #6 | ⬜ | gap re-grounded: NOT "WS-preparse" (R-lens, D5) |
| **P-Real** | Swap synthetic → **real open dataset** (e.g. npm / deps.dev), validate at scale | make-it-real | ⬜ | the showcase goal: a real use-case, not a toy |
| **P7** | Channel delegation | #7 | 🚫 deferred | → future **PL Series** track |

Dependencies: `P0 → {P1 → P2a → P2b → P3} ; P4 wraps ingest ; P5 ← P3 ; P5b ← P5 ; P6 ← P5 + session elaborator-integration ; P-Real ← P5 ; P7` stretch. Foundational fact-representation = owned **RPF track** (§11), driven by P3's slice.

## §4 The Demo (look-and-feel centerpiece)

> Legend: ✅ = verified-working syntax today · 🎯 = target (not yet runnable) · the full file is P0's deliverable.

### §4.1 Dataset (small, self-contained, graph-shaped)

`packages.json` — a JSON **array of records** (drives P1 + validation):
```json
[ {"name":"app",    "version":"1.0.0", "license":"MIT"},
  {"name":"left",   "version":"2.1.0", "license":"MIT"},
  {"name":"right",  "version":"1.5.0", "license":"Apache-2.0"},
  {"name":"shared", "version":"3.0.0", "license":"MIT"},
  {"name":"logger", "version":"0.9.0", "license":"GPL-3.0"} ]
```
`deps.csv` — dependency **edges** (drives `read-csv`, green):
```
package,dep
app,left
app,right
left,shared
right,shared
right,logger
```
This yields a **diamond** (`app→left→shared`, `app→right→shared`) and a **GPL transitive dep** (`app→right→logger`) — ideal for the audit subquery.

### §4.2 The shared contract — `schema` (🟡 verify at L3)
```
schema Package
  :name    String
  :version String
  :license String

schema DependsOn
  :package String
  :dep     String
```

### §4.3 Ingestion pipeline (functional + process)
```
;; 🎯 P1: pure-Prologos JSON parser → Result Json
def raw     := [read-file read-cap "packages.json"]      ;; ✅ functional IO runs
def parsed  := [json::parse-json raw]                     ;; 🎯 Result (List Json)

;; 🎯 P2: validate+coerce each record against schema Package → Result Package
def packages := [validate-all Package parsed]             ;; 🎯 Result (List Package)

;; ✅ CSV edges run today
def edge-rows := [csv::read-csv read-cap "deps.csv"]      ;; ✅ List (List String)
```

### §4.4 Loading records as relational facts — `:from` (🎯 P3, the headline gap)
```
;; 🎯 facts asserted from a RUNTIME-computed list (dynamic fact assertion)
defr package    : Package   :from packages
defr depends-on : DependsOn :from edge-rows
```

### §4.5 Graph queries + subquery reuse (✅ engine green; queries 🎯 on loaded data)
```
;; transitive closure — a reusable subquery  (✅ this shape runs today, cf. `needs`)
defr depends-trans [?pkg ?dep]
  &> (depends-on pkg dep)
  &> (depends-on pkg mid) (depends-trans mid dep)

;; AUDIT: REUSE depends-trans as a subgoal + join to package licenses
defr risky-dep [?pkg ?dep ?license]
  &> (depends-trans pkg dep)
     (package dep _ license)
     (non-permissive license)

eval (solve (risky-dep "app" dep license))
;; 🎯 => [{:dep "logger" :license "GPL-3.0"}]   ;; the supply-chain finding
```
`risky-dep` reusing `depends-trans` *is* the "reuse of queries as subqueries over a more complicated graph-database-like operation."

### §4.6 Serve over a session — named composition (🎯 P6)
```
session Audit
  ? String          ;; receive a license policy
  ! String          ;; send back the audit report
  end

session Resolver
  ? String          ;; receive a package name
  +>
    | :deps  -> ! String -> end
    | :audit -> Audit          ;; 🎯 continuation IS the named Audit protocol (#1)

defproc resolver : Resolver
  pkg := self ?
  offer self
    | :deps  -> self ! [resolve-deps pkg] ; stop
    | :audit -> ...continue as Audit...    ;; 🎯 named composition
```

## §5 Key Design Decisions (for critique)

- **D1 — JSON value type (P1). REVISED 2026-06-30 → blocks on Float.** Pure-Prologos parser, recursive `data Json` ADT (precedent = `List`; gap #3 fixed so the ADT binds at L3; no SRE ctor-desc needed — plain recursive sum). **Owner decision: JSON numbers are real IEEE `Float`, not `Rat`** — `data Json := JNull | JBool Bool | JInt Int | JFloat Float | JStr String | JArr [List Json] | JObj [Map String Json]` (int-vs-decimal identity preserved by the `JInt`/`JFloat` split; decimals + exponents land in `Float`). This makes P1 **depend on the [Numerics track](2026-06-30_NUMERICS_TRACK_CHARTER.md)**: it needs (N1) exponent lexing (`1e10` doesn't tokenize today) + (N3) a usable `Float` primitive with a literal form. *Grounding correction*: `Rat` is precision-exact for JSON (`0.1`=`1/10`), so the motivation is outside-world fidelity + identity, not precision — NaN/Inf are illegal in JSON so JSON alone wouldn't force IEEE, but the owner wants `Float` as the interop numeric regardless. (~~Prior D.1: `JNum Rat`~~ superseded.)
- **D2 — validation: parsing-not-typechecking; consume on-network metadata; emit `Validation`. (premise corrected.)** ~~D.1: "metadata is compile-time-only"~~ — **WRONG**: the schema registry is **dual-written** (parameter `macros.rkt:768` + cell `macros.rkt:534`; `read-schema-registry` reads the cell first, `macros.rkt:776`), Racket-runtime-readable, with `schema-field-type-datum`/`-check-pred` accessors (`macros.rkt:183`). And (S-lens) validating a **runtime-parsed** `Map` against a schema is **boundary coercion (Json→typed) = parsing**, categorically NOT the type-checker's job (typed→typed) — so "just validate via the type-checker" (a P-lens suggestion) is a category error. **Resolution**: a validator that *consumes* the on-network `schema-field-*` metadata (single-source named↔index bijection) + a reusable `Json → target` coercer family, emitting **`Validation`** (accumulating, §P2a) not `Result`. *Sub-fork (P2-time)*: pure-Prologos validator (needs schema metadata reflected into Prologos values — dogfood-consistent) vs a generic `validate` Racket primitive reading the registry cell (consistent with CSV-via-FFI). Lean pure-Prologos; decide at P2.
- **D3 — `:from`: scoped first slice now; full fact-representation is an owned track (M+S-lens, owner "split the diff").** M-lens + S-lens (independently) showed the current relation store is **off-network**: facts are a `make-parameter` (`current-relation-store`, `relations.rkt:765`; `driver.rkt:708`) copied per-query into a fresh fork (`relations.rkt:2916`) behind a **name-grained replace** merge (`propagator.rkt:628`) — so the D.1 "monotone set-union / incremental / CALM" claim was **false at the real granularity** (re-load would overwrite, not accumulate). **The DEMO builds a scoped first slice**: a per-relation `monotone-set` fact cell (reuse the shipped `merge-set-union` + `'monotone-set` SRE domain) + a single-shot runtime `:from` write path — genuinely on-network (one load). **Decomplected** (P-lens): `:from` is *sugar* for installing a load propagator that `:reads` the source-list cell and `:writes` the fact cell (engaging the vision's "Standalone Fact Question", `RELATIONAL_LANGUAGE_VISION.org:816`). **The hard parts → owned RPF track (§11)**: incremental re-load (+ tabling memo invalidation), S(-1) fact retraction (a *new* stratum handler on the fact cell, NOT the meta-scope `process-retraction`), off-parameter migration, indexing + flat-vector storage. **NTT model required for the slice.**
- **D4 — IO path: progressive disclosure, one canonical ingestion (P-lens).** Not belt-and-suspenders, but the D.1 "compare ergonomics" framing was open-ended. Reframed: since IO IS session-typed, the functional `read-file`/`read-csv` read is the **shallow disclosure** of the same flow `proc-open : FileRead` discloses at process depth — *one lattice, two altitudes* (Progressive Disclosure). The **process-layer channel is canonical and feeds P3**; the functional read is the introductory view. `main`-as-Powerbox (`IO_LIBRARY_DESIGN_V2.md` §7) is the capability entry.
- **D5 — named composition (P6): gap re-grounded (R-lens).** D.1's "WS-preparse fix (`tree-parser.rkt:1578`)" is **misdirected** — `parser.rkt:5269` already handles sessions; the real gap is **elaborator integration of `surf-sess-ref` in continuation position + the first L3 example** (none exists). P6 = wire the elaborator path + L3 test + duality check across the composed type. (Also pin how `ws-session-e2e-*.prologos` actually parse.)
- **D6 — `explain` provenance (P5b): in scope, but L3-UNPROVEN (R-lens).** `explain` exists + has `.rkt` unit tests (`reduction.rkt:672`, `provenance.rkt`, `test-explain-provenance-01.rkt`) but **no `.prologos` L3 run**. P5b's deliverable IS the first L3 `explain` case (`explain (risky-dep "app" dep license)` → `app→right→logger[GPL-3.0]`), not a free assumption. On-network provenance = headline value-offer (owner).
- **D7 — dataset, two-stage. LOCKED.** **Stage 1: small synthetic** (§4.1) to validate query *correctness* against hand-computed expected results. **Stage 2: real open data** (P-Real) — point the same pipeline at a real ecosystem snapshot (npm registry metadata / deps.dev / libraries.io) to showcase a genuine use-case at scale. Make-it-real is explicit: demonstrate what Prologos does for real, not a toy.

## §6 On-Network / Mantra (P3 slice)

P1/P2/P4/P6 are FFI/stdlib/elaboration/parser work — not new propagators. **M-lens confirmed the user's pure-Prologos JSON parser is in-bounds**: the on-network mandate governs the *compiler's* data structures, not user programs (one sentence to add to D1). **P3's slice is the on-network work**: introduce a per-relation `monotone-set` fact cell (PRIMARY lattice = powerset-of-fact-rows under ⊆; merge `merge-set-union`; bot `(seteq)`; CALM-safe). Network Reality Check the slice MUST pass (M-lens — D.1 failed it):
- new **fact cell** created (today's `relation-store-cell-id` is a per-query *scratch copy* of the `current-relation-store` parameter — not a persistent fact cell; `relations.rkt:2916`, `propagator.rkt:627`).
- `:from` **load propagator** installed: `:reads` source-list cell → item-fn `row → (seteq row)` (broadcast, not `for/fold`) → `net-cell-write` the fact cell.
- solver `net-cell-read`s the fact cell = facts queryable. **NTT model required.**
- *Honest scope flag*: the slice writes facts on-network for the demo's relations (single-shot); full off-`current-relation-store`-parameter migration is the **RPF track (§11)** — designing against an as-yet-unbuilt persistent-fact boundary, stated per `stratification.md`.

## §7 Proportionate Methodology

| Gate | Applies? | Why |
|---|---|---|
| Acceptance file = the demo | ✅ all phases | the `.prologos` file is the instrument |
| Per-phase tests + Progress Tracker | ✅ all | standard |
| WS Impact section | ✅ P1/P3/P6 | new surface (`Json`/`parse`, `:from`, session refs) |
| On-network/Mantra audit + NTT model | ✅ **P3 only** | only P3 touches the propagator network |
| SRE / Hasse / module-theoretic lens | ✅ **the showcase** (was "light"; S-lens upgraded) | `depends-trans` = reachability **least-fixpoint** on powerset-of-edges (tabling runs it, `relational-demo.prologos:576`); `risky-dep` = **clause-coproduct over the reachability lattice** = the subquery-reuse story; P3 fact cell = `monotone-set` join-semilattice; `Validation` = applicative w/ Semigroup-E |
| Pre-0 perf micro-benchmarks | ➖ N/A | feature-*enabling*, not perf-optimizing (revisit if P3 load perf becomes material) |
| Parity test skeleton | ➖ N/A | no equivalent-path migration |

## §8 Resolved Decisions (was Open Questions; resolved 2026-06-28)

1. **D2 schema-metadata-at-runtime** → **(b) generated per-schema validator.** [§5 D2]
2. **D1 JSON numeric** → **faithful `JNum Rat`** (parse numbers as numbers; coerce at P2). [§5 D1]
3. **Dataset** → **two-stage**: synthetic for correctness, then **real open data** (P-Real). [§5 D7]
4. **`:from` semantics** → **incremental** (monotone add; retraction via S(-1) follow-on); records ground-at-load for v1. [§5 D3]
5. **`explain`/provenance** → **in scope** as first-class showcase (P5b). [§5 D6]
6. **Series placement** → **DEMO Series, Track 1** confirmed; #7 (channel delegation) seeds a future **PL Series**.

*Remaining genuinely-open (post-critique)*: exact real-dataset source + snapshot mechanism (P-Real); the D2 pure-Prologos-validator-vs-`validate`-primitive sub-fork (P2-time); incremental `:from` × tabling **memo invalidation** (RPF track — monotone fact-add ⇒ stale memo under-approximates, S-lens Challenge 5); numeric-lexing edge cases (exponents, big ints) in the pure-Prologos parser; exact parse path of `ws-session-e2e-*` (pin for P6).

## §9 References

- Prior art: `2026-03-06_RELATIONAL_FACT_DESIGN.md`, `RELATIONAL_LANGUAGE_VISION.org` (§Bulk Fact Loading), `2026-03-05_IO_LIBRARY_DESIGN_V2.md` (Phases D–J, §7 Powerbox), `principles/PROTOCOLS_AS_TYPES.org`, `2026-03-03_SESSION_TYPE_DESIGN.md`.
- Working syntax: `examples/relational-demo.prologos`, `tests/ws-session-e2e-01..03.prologos`, `tests/test-relational-e2e.rkt`.
- Runtime IO: `io-ffi.rkt`, `effect-executor.rkt`, `tests/test-io-file-01.rkt`, `tests/test-effect-executor-01.rkt`.
- Process docs: `DESIGN_METHODOLOGY.org` (Stage 3), `ACCEPTANCE_FILE_METHODOLOGY.org`, `.claude/rules/on-network.md`, `.claude/rules/prologos-syntax.md`.

## §10 Critique Record (D.1 → D.2, P/R/M/S, 2026-06-28)

Four independent HEAD-pinned (`d7f9daf`) adversarial reviewers, one per lens. Headline findings + dispositions:

- **R (reality-check)**: feasibility map broadly VERIFIED; **sharpened** that schema-typed `defr`, named composition, and `explain` are real-in-`.rkt`-tests but **NOT L3-proven** (→ P0/P5b/P6 must prove); named-composition gap re-grounded (`parser.rkt:5269` handles sessions; gap is elaborator integration, not preparse) → D5.
- **P (principles)**: D4 belt-and-suspenders → **progressive disclosure** (D4); `:from`-on-`defr` complects declaration+loading → **decomplect** via load propagator + `:from`-as-sugar (D3); **Validated≠Deployed** → owned tracks + deployment gates (§11).
- **M (mindspace)**: **P3 fails the Network Reality Check as written** — relation store is off-network parameter + per-query fork-copy + name-grained-replace merge → **re-scoped** (D3); retraction can't reuse meta-scope S(-1) (new handler needed); confirmed user's functional JSON parser is in-bounds.
- **S (structural)**: **`Result` short-circuits → `Validation` applicative** (P2a, blocking); P3 lattice granularity wrong → per-relation `monotone-set` fact cell (D3, *independently confirms M*); validation = **parsing-not-typechecking** (D2 — refutes "validate via the type-checker"); reachability-fixpoint is the structural showcase (§7); incremental-`:from` × tabling needs memo invalidation.
- **Conflict resolved by direct read**: P-lens vs R-lens disagreed on D2's premise; settled at `macros.rkt:534/768/776` — dual-written param+cell, Racket-runtime-readable, not Prologos-exposed → D2 premise corrected.

**Confirmed sound** (not rubber-stamped): D1 `JNum Rat`, D7 two-stage dataset, `Json` ADT (recursive-`data` precedent), the relational engine, IO at both layers.

## §11 Owned / Spawned Tracks (governance — Validated≠Deployed)

The DEMO track is the *driver / acceptance instrument*; each enabling fix is **owned by its series** with its own completion + deployment gate (link in `MASTER_ROADMAP.org`):

- **Numerics track** *(NEW 2026-06-30; spawned by P1; charter [`2026-06-30_NUMERICS_TRACK_CHARTER.md`](2026-06-30_NUMERICS_TRACK_CHARTER.md))*: resumes + revises the 2026-02-19 Numerics Tower roadmap — adds **`Float` (full compute primitive)**, reconceives the tower as **refinement-via-`trait`** (not subtyping), fixes Posit display + exponent lexing + ergonomics. **DEMO P1 blocks on it** (N1 exponent-lex + N3 Float). This subsumes the former §5 D1/P1 "`json::core` owns JSON numbers" framing: the *numeric* substrate is the Numerics track's; the JSON *parser* stays DEMO P1.
- **RPF — Relational Performance & Fact Representation** *(NEW; Relational/PM series; multi-track)*: persistent fact-grained cell across queries, off-`current-relation-store`-parameter migration, incremental re-load + tabling memo invalidation, S(-1) fact retraction, indexing + flat-vector storage (`2026-03-06_RELATIONAL_FACT_DESIGN.md`). **The owner's "competitive relational query + data representation" goal + the SQLite prerequisite.** DEMO P3 builds the *first slice* (single-shot `monotone-set` load) as the wedge.
- **`prologos::core::json`** (pure-Prologos) — stdlib/IO; DEMO P1. *Named divergence*: `core/json` pure-Prologos vs `core/csv` FFI = a per-format policy choice, stated not silent.
- **`prologos::data::validation`** (`Validation` accumulating applicative) — stdlib/data; DEMO P2a.
- **Schema validation→`Result`/panic gap** (`:check` panics, sexp-only) — schema series; surfaced by DEMO P2b.
- **Session named-composition elaborator integration** — session series; DEMO P6.
- **Channel delegation (#7)** → future **PL (Process-Language) Series**.

## §12 P0 Findings (L3 verification, 2026-06-29)

Acceptance file `examples/dependency-demo/dependency-resolver.prologos` runs via `tools/run-file.rkt` (`process-file`) at **0 errors / ~30s**; all results hand-verified correct. Grounded by a 6-facet syntax-grounding workflow + live `process-file` probes (no syntax assumed — every live form was probed).

**Verified runnable at L3 (the demo's core):**
- Real file IO: `[read-file "path"]` as a BARE top-level expression (first standalone `.prologos` to read a file at L3).
- Pure-Prologos CSV parse: `[map [fn [r : String] [split "," r]] [lines [read-file p]]]` (sidesteps gap #2).
- Relational: untyped `defr ||` facts, recursive transitive closure `needs`, multi-goal join `risky-dep` (subquery reuse), `solve` — results match hand-computed graph (diamond + depth-3 audit finding).
- Provenance: `explain (needs "app" "fmt")` → derivation tree `app→right→logger→fmt`. **P5b proven at L3.**
- Schema-as-maps: `schema Package` + `def p : Package := {…}` + `[map-get p :name]`.
- Process: `session`/`defproc` + `spawn` → "Protocol completed."

**Gaps surfaced (filed — the dogfooding payoff):**
1. ~~schema-typed `defr R : Schema || …` is UNWIRED at L3~~ → **FIXED 2026-06-29** (register + type-check facts). `parse-defr` now recognizes `: Schema`, derives arity + field-named params from the registered schema (`parser.rkt` `parse-defr-schema-typed`), and the driver type-checks each fact row positionally against the schema field types (`driver.rkt` `check-relation-schema-rows`, reusing `schema-field-type->expr` + `check`). The demo's `defr package : Package` is now live + type-checked and joined in the audit query; tests in `tests/test-defr-schema.rkt` (5/5). Full suite 8385 tests, 0 new failures. *(Scope: register + type-check facts; field-named result projection + schema-typed **rules** remain follow-ons.)*
2. **`require [prologos::core::csv]` fails E2001 at module load** — `read-csv`/`write-csv`'s `_cap`-prefixed param doesn't thread the capability through module elaboration → the FFI CSV module is unimportable in a standalone file. Workaround: pure-Prologos parse (on-theme). *Owner: IO/capability series.*
3. ~~**User `data` ADTs: the type binds but constructors do NOT at WS L3**~~ → **FIXED 2026-06-29** (commit `0deee838`). Corrected diagnosis (live repro + adversarial workflow): the bug is the **`:=`/`|` separator forms** — `process-data` mapped `parse-data-ctor` over the raw `(:= c1 $pipe c2 …)` / `(| c1 …)` token stream without stripping separators, so field-bearing ctors bound nullary and field types leaked as phantom ctors (`defn` normalizes via `group-defn-pipes`; `data` had no equivalent). `normalize-data-ctor-clauses` (macros.rkt) strips `:=`, canonicalizes literal `|`→`$pipe` (cell reader keeps `|` literal; merge reader emits `$pipe`), splits, and unwraps single-list segments. Validated at L3 via **BOTH** `process-file` AND `process-string-ws` (`tests/test-data-adt-forms.rkt`, 6 tests; suite 8394). **P1 can now use a real `data Json` ADT** (restores D1). *Convention:* colon ctor form lists FIELDS, return implicit; do not append the data type. Full GADT-style explicit returns deferred (indistinguishable from recursive fields like `cons : A -> List A`). *Newly surfaced (separate, pre-existing, filed):* polymorphic colon-field ctors at top level (`data Lst {A} … cns : A -> Lst A`) bind via `process-file` but fail in the **cell** pipeline ("not a valid type") — orthogonal to the separator fix (normalizer is a verified no-op for that form). *Owner: elaborator/PPN.*
4. **Top-level file IO works only as a bare expression** — `def x := [read-file p]` fails E2001 (SysCap powerbox provisions only bare top-level exprs). *Owner: IO/Powerbox.*
5. *(minor)* `solve` returns one binding per derivation PATH (the diamond → `shared`/`util` appear twice); no built-in distinct/answer-set dedup. *Owner: relational.*
6. ~~`_` in relational goal-**argument** position is treated as a constant~~ → **FIXED 2026-06-29**: `_` parses to `surf-hole`; the elaborator now elaborates a `surf-hole` to a *fresh* anonymous logic var (`gensym '_anon`) when `current-relational-fallback?` is set (relational goal context), and to `expr-hole` as before in functional context. `(package dep _ lic)` now matches; demo uses it. Test in `tests/test-defr-schema.rkt`. *(Minor cosmetic follow-on: the `_anon…` name appears in result-map keys — result projection could drop anon vars.)*
7. ~~Relative `read-file` paths resolved against ambient process CWD~~ → **FIXED 2026-06-29**: a `.prologos` program's relative resource paths (`read-file`/`read-csv`) now resolve against the **source file's directory** (location-independent, mirroring how modules resolve against an absolute lib root, `driver.rkt:143`) — not the launch CWD. Previously the demo worked under `run-file.rkt` (cwd = repo root) but the path *doubled* under the VSCode/Emacs LSP/REPL (cwd = the file's dir). `process-file` absolutizes its path then parameterizes `current-directory` to the source dir, with a `#:source-dir` override for callers that process a copy (the LSP diagnostics temp file); the REPL `loadFile` path parameterizes `current-directory` from the doc URI (`process-string-ws` carries no path). Demo uses the sibling `"deps.csv"` and runs 0 errors from any cwd. Test `tests/test-relative-path-resolution.rkt`; full suite 8387, 0 new failures. *Owner: IO/driver.* (Surfaced by the owner loading the demo in the LSP REPL — the dogfooding payoff again.)

---
*P0 CLOSED 2026-06-29 — acceptance core runs 0 errors at L3, gaps filed (§12). Gaps #1 (schema-typed `defr`), #6 (`_` wildcard), #7 (relative paths), AND **#3 (`data` ADT constructor separators, commit `0deee838`)** FIXED. D.2 critique complete 2026-06-28; P3 re-scoped, RPF track spawned (§11). Next: P1 — pure-Prologos JSON parser, now usable as a **real `data Json` ADT** (gap #3 closed) — + P2a (`Validation` applicative); then iterate demo look-and-feel.*
