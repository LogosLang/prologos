# Handoff — CIU Track 6 F1: Structural Records & Collections, resume at F1a-col-3

**Date**: 2026-07-14 · **Author**: session that closed F1a-core (s3–s5) + landed F1a-col-1 (tuples) + col-2 (lists under D15).
**Resume target**: **F1a-col-3** (tuple-op dispositions across the pvec arms), then **col-4** (remaining canaries) → col closes.

> ⚠ On-disk is authoritative. RUN `git log --oneline -12` + `git status --short` FIRST. Re-verify any "broken"/"route" claim against code before trusting — this session's biggest surprise was a wrong route assumption (§4.1).

---

## §1 Current work state (precise)

- **Series/Track/Phase**: CIU Track 6, phase **F1a** — structural records DONE (core s1–s5 ✅), anonymous collections (col) 2 of 4 slices done.
- **HEAD**: `4f1a2a94` (tracker) atop **`c6c3ef3a`** (col-2 code). Suite **GREEN 8604 / 452 / 0**. Acceptance **48/48** (`examples/2026-07-06-ciu-t6-f1-records.prologos` via `tools/run-file.rkt --check`; suite-gated by `tests/test-f1-records-acceptance.rkt`).
- **Working tree**: pre-existing OWNER WIP ONLY (`.claude/settings.local.json`, `docs/standups/*.org`, `examples/*.prologos` mods, `MASTER_ROADMAP.md`/`LANGUAGE_VISION.md` deletions, untracked owner files). **LEAVE ALONE — never blind-commit; stage only your files.**
- **What works end-to-end (WS)**: `{:a 1}.a : Int` (+V5 arithmetic); heterogeneous per-field records; exact map-op surface; rich closed-row-miss diagnostic; `@[1 "a" true] : ⟨Int String Bool⟩` tuples with positional projection (`tr[1].b ⇒ 2 : Int`); `'[{:a 1} {:b 2}] : ⟨{:a Int} {:b Int}⟩` (the D.3 named regression CLOSED); Tuple→PVec/List α; homogeneous literals byte-identical to pre-F1a.
- **Progress tracker**: F1 design doc §2 (all rows current). **Next immediate task**: col-3 — Record arms for the remaining pvec ops (`nth`/`update`/`pop`/`concat`/`slice` exact-where-static; `to-list`/`fold`/`map`/`filter` via ⋃/degrade), the 11-arm whnf discipline, qtt co-migration for type-matching arms.
- Racket: `"/Applications/Racket v9.0/bin/racket"`; runner `cd racket/prologos && racket tools/run-affected-tests.rkt`.

## §2 Documents to hot-load (ordered)

**Always-load**: `CLAUDE.md`+`CLAUDE.local.md`; `MEMORY.md` (memory: `ciu-t6-records`, `design-dialogue-preference`); `DESIGN_METHODOLOGY.org`; `DESIGN_PRINCIPLES.org`; `CRITIQUE_METHODOLOGY.org`; `HANDOFF_PROTOCOL.org`; `MASTER_ROADMAP.org`; **CIU series master** `docs/tracking/2026-03-21_CIU_MASTER.md`.
**Rules** (auto-loaded; internalize): `pipeline.md` (New-AST-Node checklist — col added 2 nodes; col-3 touches typing arms only), `testing.md` (failure protocol — used 3× this session), `workflow.md`, `on-network.md`, `prologos-syntax.md`.

**Session-specific (read in full, in order)**:
1. **F1 design doc** — `docs/tracking/2026-07-06_CIU_T6_F1_STRUCTURAL_RECORDS_DESIGN.md`: §2 tracker (per-slice notes carry commit hashes + discoveries), §11a–c implementation notes, §4.3 dispositions, §10 resolved questions.
2. **Track doc** — `docs/tracking/2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md` §2a: locked **D1–D15** + the **OPEN Path-Selection surface notes** (owner direction: postfix `coll[…]` path selection, broadcast `coll.[…]`, result-shape crux — needs its own deep co-design; DO NOT build surface).
3. **D.3 critique record** — `docs/tracking/2026-07-06_CIU_T6_F1_STAGE3_CRITIQUE_D3.md` (B1–B4/S1–S12 all landed; useful for the finding→resolution map).
4. **Dailies** — `docs/tracking/standups/2026-07-05_dailies.md` (checkpoints 1–3 = the whole F1 arc).
5. Grounding audits (context): col audit ran as `wf_8c01845e` (results distilled into the tracker notes; §4 below carries the load-bearing corrections).

## §3 Key design decisions (rationale — do NOT relitigate)

- **D15 — observational literal typing** (owner, 2026-07-13; REVISES D14's flavor-B-as-union): *"the type is what the literal is observed to be."* Heterogeneous literals mint per-position `'nat` rows in BOTH bracket forms; the union-element list is the **derived α only**, never minted (the union forgets which position holds which type — it is an abstraction of the observation, not the observation). Same-label-different-type lists are rows — no union question at the literal.
- **Mechanism = literal-extent AST nodes** (`expr-pvec-literal (elems)`, `expr-list-literal (elems chain)`), typed ALL-AT-ONCE (owner-blessed Q_col-A). Rejected: seed-keyed row growth (cannot collapse homogeneous chains — no end marker on push/cons; every `@[1 2 3]` would flip type = mass regression) and in-place meta widening (blocked by `solve-meta!`'s single-solution contract at BOTH entry points, `metavar-store:2061-2064`/`:2129-2132`).
- **Homogeneity is UNIFICATION-based, rollback-probed** (success commits): `@[none [some 1]]` must still collapse to `PVec (Option Int)`; an `equal?` test would mint a spurious tuple. Test-pinned.
- Q_B mixed-key rows forbidden; Q_C v1 strictly closed tuples (variadic deferred; tail slot expr-ready); Q_D tuple-by-default (Roc-style; TS array-by-default's `as const` ceremony is the documented anti-pattern); Q_E end-state (b) — `expr-Map`/`PVec` are dyn-tailed uniform instances of the one carrier.
- **Legacy-by-design lowerings** (not gaps): empty `@[]`/`'[]`, tail-syntax `'[a b | rest]`, varargs builders (collect into DECLARED `(List A)` params — a row would immediately α back), explicit `pvec-push`/manual `cons` chains, sexp-mode… all keep meta-seeded/cons semantics.

## §4 Surprises and non-obvious findings (highest re-derivation risk)

1. **WS files route `'[…]` through the PREPARSE sentinel, not the tree route.** The col grounding audit read the tree route as the WS surface — wrong: `$list-literal` is preparse-rewritten to cons sexps before the parser ever runs. The def-route "Multiplicity violation" was diagnosed by driver instrumentation showing a raw cons-chain body (the elaborator never saw the node). Fix = `$list-literal-parse` parser handoff mirroring `$vec-literal` (both routes hooked now). **Lesson: when a literal's typing changes route-dependently, instrument the driver to see WHAT NODE actually arrives — don't trust route claims.**
2. **qtt fallback runs elements in INFER mode; operator values are CHECK-mode-only** (the issue-#76 class: `'[int+ int*]`). The literal nodes need dedicated checkQ arms checking elements against the expected element type; "rely on the delegating fallback" was wrong. Caught by `test-prim-op-firstclass`.
3. **The `.pnet` canary poisoned the suite runner**: its leftover TOP-LEVEL cache file made the pregen heuristic (`count top-level *.pnet > 0` ⇒ "ready", non-recursive) skip prelude-cache regeneration from s3 onward; caches drifted from the compiler until 10-worker startup starved at the 30s watchdog ("DEAD WORKERS", twice). Canary now deletes its artifacts; caches regenerated; **runner hardening spawned as a task chip** (pending). If DEAD WORKERS recurs: check `ls racket/prologos/data/cache/pnet/*.pnet` (top level must be 0) before anything else.
4. **KNOWN v1 LIMIT**: generic prelude folds over a ROW-typed list (`length xs`) are type-sound but the VALUE can print as a stuck term (implicit/dict resolution sees no row instance head — the S10 posture at list level). Plain `(List <union>)` args reduce fine (probed). Escape hatch: pass through the α (`(List (Map …))` spec) first. Home: **CIU Track 3/5**. Test-pinned type-only.
5. **`with-speculative-rollback` contract**: `(thunk success? label)` — `success?` is a predicate on the thunk result; truthy COMMITS (worldview bit retained), falsy rolls back. The homogeneity probes lean on success-commits.
6. **Pattern-var shadowing bug class**: an arm binding `map`/`list` shadows Racket's function inside new lambdas (col-1's `finish` bug; probe-caught). Use `for/list` inside map-op arms.
7. **The col-1 classifier is seed/literal-keyed BECAUSE of the second producer**: explicit `[pvec-push v x]` surface chains exist (`elaborator:2468-2478`) and must keep today's typing.
8. Earlier-arc surprises still load-bearing: record→Map α reaches FOUR subsumption entry points (+now PVec/List mirrors — check-subsumption, qtt fallback, `subtype?` + `structural-subtype-ground?`, unify classify); `test-mixed-map` is the superseded T-2 "Open by Design" contract file; B3's degenerate cross-command stale-meta limitation (documented in `a5c546c8`).

## §5 Open questions and deferred work

- **col-3 (NEXT)**: Record arms for `pvec-nth`/`update`/`pop`/`concat`/`slice` (exact where index/bounds are literal — closed tuples have static length; degrade to the ⋃/PVec view otherwise), `to-list`/`fold`/`map`/`filter` via the uniform view (mirror the s3 map-op decisions), the **11-arm whnf discipline** (all pvec arms use bare `(infer ctx v)` — every new Record arm needs whnf), qtt co-migration for arms that match the subject type (nth/to-list/fold/map/filter — push/update/length/pop/concat/slice are usage-only per the audit). Grounding: the col audit facet 2 enumerated the arms (typing-core `:1845-1933` region — REGREP, they drift).
- **col-4**: remaining canaries (tuple-op behaviors; col-2 list canaries live in `tests/test-record-collections.rkt` — `:no-prelude` acceptance can't see `'[…]`), doc §4-col updates (route correction), then the col close (suite + bench + tracker).
- **Then**: F1a.2 (dyn tail + `Open` relocation/deletion, D7 — own mini-design); F1b (erasure-mode width + Map↔schema seal — own Stage-3); F-row (ρ spike-first, `Concat`; UCS-5/SRE-5 junctions).
- **Path Selection = OPEN owner design conversation** (track doc §2a): postfix `coll[…]` unified path selection (supersedes braces), broadcast `coll.[…]`, k+v-vs-value result shape. Deep back-and-forth BEFORE any surface commitment. col ships only degenerate literal-index projection; `v[1.b]` waits.
- Pending chips/notes: runner pregen hardening (task chip `task_5e3ec9c2`); union-arm `with-speculative-rollback` excise-or-defer note (§8 of design doc); S7 hint on the check-path (extend only if annoying); `record-subtypes-map?`/`-pvec?` pure-α union-branch parity (typing-core's meta-aware sibling handles unions; the pure one doesn't — nested covariant positions only, F1b).

## §6 Process notes / gates

- **Per-change gate**: `../../tools/check-parens.sh <f>` per `.rkt` → `raco make driver.rkt` → probe (`tools/run-file.rkt` on a scratch `.prologos` — probe-first caught 3 bugs this arc before any test) → targeted `run-affected-tests.rkt --tests …` → full `--all --force-rerun --no-precompile` (output→FILE, keep the WHOLE file not `tail`; read once; failures → `data/benchmarks/failures/*.log`, NEVER re-run to diagnose; know the **stale-log category**: a log with no source file + absent from the run output) → commit (`git commit -F -`, stage ONLY your files, **NO Co-Authored-By**).
- **WS-first**: tests in WS `.prologos`; `:no-prelude` for language features (full prelude ≈48s under contention); prelude-needing surfaces (`'[…]`, `none`/`some`, `map-merge`) go in `tests/test-record-collections.rkt`.
- **Owner dialogue**: PROSE, options in spaced blocks, `Q_N` labels; decisions get D-numbers in the track doc §2a. Design dialogue + novel-design implementation = MAIN-SESSION; grounding audits (grounding-audit workflow) + research (parallel threads) delegable.
- **Minting is the point of no return**: changing what a literal types as forces every downstream consumer arm handled or it regresses; the suite is the gate; expect display-churn (flip) vs real-regression (fix) vs stale-log (delete) categories.
- Dailies: `docs/tracking/standups/2026-07-05_dailies.md` is the living log (checkpoints per close); owner standups in `docs/standups/` are WRITE-ONCE.

---
*Handoff for CIU T6 F1a-col-3. Resume: hot-load §2, verify §1 state on-disk, then col-3 under the Stage-4 per-phase protocol (grounding first — the col audit's facet-2 arm enumeration is the seed, but REGREP coordinates).*
