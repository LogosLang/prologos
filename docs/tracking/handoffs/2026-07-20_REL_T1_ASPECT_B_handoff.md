# Handoff — Rel Track 1, resuming at Aspect B (typed solution rows)

**Date**: 2026-07-20 · **Handoff for**: a fresh session to open **Aspect B**
(typed solution rows) as a **full Stage-0→3 design process**. Per
`docs/tracking/principles/HANDOFF_PROTOCOL.org`. **ON-DISK IS AUTHORITATIVE.**

---

## §1 — Current Work State (PRECISE)

- **Series / Track**: Rel Series → **Track 1, Relational Language Usability**.
- **Design doc**: `docs/tracking/2026-07-19_REL_T1_RELATIONAL_USABILITY_DESIGN.md`
  (Aspect-A LOCKED + LANDED; **§6 Aspect B + §7 Aspect C + §11 open questions**
  are the load-bearing sections for the resume).
- **Series Master**: `docs/tracking/2026-07-19_REL_MASTER.md`.
- **HEAD**: `dc891aec` (`docs(Rel T1 A.4 + BSP-LE Track 3): capture guard DFS-routing
  + the on-network seed`) atop `6b56397d` (A.4 code). **Suite GREEN 8934 / 466 / 0.**
- **Working tree**: pre-existing OWNER WIP only (modified standups/examples, deleted
  `MASTER_ROADMAP.md`/`LANGUAGE_VISION.md`, untracked LATTICE_/LAVAMOAT_/pldi files) —
  **LEAVE ALONE; stage ONLY your files; NO Co-Authored-By** (per `CLAUDE.local.md`).
- **Aspect-A is COMPLETE** (all committed, hash-anchored):

  | Phase | Status | Commit | What |
  |---|---|---|---|
  | P0 acceptance | ✅ | `860248bf` | `examples/2026-07-19-rel-t1-acceptance.prologos` (9/9) |
  | A.1 top-level echo | ✅ | `80a2963d` | bare `not` → runs via DFS |
  | A.2-core | ✅ | `cb0fb1e4` | E-with-B per-binding belief-clear, FACT-NAF on-network |
  | A.2b | ✅ | `bcd02d6d` | DFS-route body-local-var rule NAF (Check 3) — SCAFFOLDING |
  | A.3 | ✅ | `74fa9df2`+`393bbbbf` | static PERMISSIVE floundering gate + Prolog-parity loudness |
  | SC | ✅ | `19d9f8ae`+`f07f6c54` | `process-string-ws` preparse-macro fix + wfle validation |
  | A.4 | ✅ | `6b56397d`+`dc891aec` | DFS-route guards (Check 4) — SCAFFOLDING |
  | **B.1/B.2** | ⬜ **NEXT** | — | **typed solution rows (codata + schema projection)** |
  | C.1/C.2 | ⬜ | — | schema-as-relational-facts + validation |
  | D.0/1 | ⬜ | — | efficient fact representation research (Stage 0/1) |
  | POL | ⬜ | — | dedup · drop `_anon` keys · declaration-order keys |
  | T | ⬜ | — | dedicated tests (interleaved, not deferred) |
  | X.close | ⬜ | — | bench matrix · DEFERRED triage · doc-truth · memory fold · **Stage-5 PIR** |

- **NEXT IMMEDIATE TASK**: open **Aspect B (typed solution rows)** as a full design
  process — Stage 0 (mantra audit / prior-art) → Stage 1/2 (grounding-audit over the
  `solve` typing + row-build + F1 row carrier) → Stage 3 (options-panel on the OPEN
  forks + owner co-design) → Stage 4 (implement main-session + gate). Owner
  anticipates the FULL design process. Aspect B is **not** started; §6 sketches the
  two typing sources but leaves keying + unbound-rep reconciliation OPEN.

---

## §2 — Documents to Hot-Load (ORDERED)

**Always-load** (skim if fresh): `CLAUDE.md` + `CLAUDE.local.md`; `MEMORY.md` +
[[rel-t1-relational-usability]] + [[ciu-t6-records]]; `DESIGN_METHODOLOGY.org`;
`DESIGN_PRINCIPLES.org`; `CRITIQUE_METHODOLOGY.org`; `HANDOFF_PROTOCOL.org`;
`MASTER_ROADMAP.org`; `docs/tracking/2026-07-19_REL_MASTER.md`. Rules auto-load
(internalize on-network.md, propagator-design.md, structural-thinking.md,
stratification.md, testing.md, workflow.md).

**Session-specific (READ IN FULL, in order)**:
1. **This handoff** (§1-§6).
2. `docs/tracking/2026-07-19_REL_T1_RELATIONAL_USABILITY_DESIGN.md` — the Stage-3
   design. **§6 Aspect B (typed rows) + §4 "Aspect B/C grounding" + §11 Q-B** are the
   crux. §2 Progress Tracker for current phase state. (Aspect A §5 is DONE — read for
   context/idiom, don't re-open.)
3. `docs/tracking/2026-07-19_REL_SOLVE_TYPING_NOTE.md` — the **seed's Problem 1
   (typed solution rows)** carries the load-bearing **entry gates (a)-(e)** and the
   "why hard" (labels not statically derivable). READ FIRST for Aspect B.
4. **CIU T6 F1/F1b** — typed rows reuse the F1 row carrier: design doc
   `docs/tracking/2026-07-06_CIU_T6_F1_STRUCTURAL_RECORDS_DESIGN.md` (records /
   `Map`↔schema / validate) + PIR `docs/tracking/2026-07-19_CIU_T6_F1B_PIR.md` +
   the downstream `docs/tracking/2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md` (the `^`
   dynamic key-rename that B.2's schema-projection ties to). Aspect B is "the F1
   `{:a 1}.a : Int` machinery, one layer up." Grounding for gate (d)/(e) (the two
   unbound reps + the **F1b.6 escape-boundary tightening** / D23 display posture).
5. `docs/tracking/standups/2026-07-19_dailies.md` — STATE head (current) + the LOG
   (the full Aspect-A arc, newest at bottom).
6. `docs/tracking/2026-07-20_BSP_LE_TRACK3_ONNET_SEED.md` — where the A.2b + A.4
   scaffolding retires (context, not resume work).
7. `git log --oneline -14` — the commit chain.

---

## §3 — Key Design Decisions (RATIONALE) — do NOT re-open without cause

**Aspect A (LOCKED + LANDED):**
1. **A.2-core = E-with-B** (belief-layer per-binding narrowing): `naf-per-binding-mask`
   generalizes the single-shared-naf-bit `worldview-cache` AND-NOT to per-binding
   `(OR failing) & ~(OR passing)`. Stays in the BELIEF layer (decisions-state
   untouched, coexists with dissolution). *Why:* NAF/guard have ALWAYS belief-narrowed;
   existence-narrowing (Option D) would clobber belief-subset enumeration.
2. **A.2b + A.4 = DFS-routing scaffolding** (`use-propagator?` Checks 3 + 4 in
   `stratified-eval.rkt`). Body-local-var rule generators (A.2b) and ALL guards (A.4)
   route to DFS — the correct reference solver. *Why:* the on-network ATMS engine can't
   thread body-local clause vars (A.2b) and guards live in tabled rules (A.4), so the
   on-network answer set is incomplete / the belief-narrow can't persist. **Retirement
   owner = BSP-LE Track 3** (on-network body-local threading + SLG + §9.6
   worldview-preserving tabling). Honest engine-selection, NOT off-network scaffolding.
3. **A.3 = static PERMISSIVE floundering gate + Prolog-parity loudness** (owner ruling):
   Site A (`defr` var bound by nothing) = hard error at registration; Site B (top-level
   `solve (not v)` free) = **warn to stderr + `nil`**, NOT an error. Head params count
   as binders (permissive `\+` mode).
4. **A.4 on-network guard mechanism was prototyped + verified, then reverted** for the
   simpler DFS-route, and **captured in the BSP-LE Track 3 seed**: struct-resolution fix
   (`subst-logic-vars-in-expr` — `resolve-condition-from-net` didn't recurse into struct
   condition exprs) + per-binding guard belief-clear (pure `eval-fn(subst)`, no fork) +
   a **between-round handler** (guard-pending cell + `process-guard-request` mirroring
   `process-naf-request` — required because the S0 narrow gets re-projected away, the
   `worldview-cache` being a derived projection of decisions-state).

**Aspect B (the CONSTRAINTS the design must honor — from §4 grounding + the seed):**
5. **`solve` is a bare `expr-hole` in BOTH checkers** (typing-core.rkt:2930,
   qtt.rkt:2161) — typed rows start from nothing; both checkers must be touched.
6. **Solution-row keys = query-var NAMES, not schema field names** (reduction.rkt
   ~:239-250). B.2's schema-projection needs a **rename** (query-var → field name;
   ties to Path-Selection `^`).
7. **Labels are NOT statically derivable in general** (seed "why hard"): query args are
   whnf'd before the ground/free split (which var is *free* is a runtime determination);
   anonymous `_` → gensym keys (`:_anon<gensym>`, no static name). So "read query-var
   names into a row type" fails for the general case → the **typeable-goal fragment**
   (gate a) + untyped fallback (gate e).
8. **Build the ONE shared ground/free predicate** (gate b) — the walk is currently
   reproduced 3× + the row-build loop 5× (drift-bug class). Aspect A's per-binding work
   (A.2-core) and B both want this; it must be **built**, not shared-by-accident.

**Owner framing (from the SC/Aspect-A arc):** Prolog-parity is the current aim (WFS
available for stricter semantics later); codata typing is "as first-class as schema'd"
(owner Q2); **solve typing sequenced BEFORE Path Selection**; the demo
(dependency-resolver) is the through-line.

---

## §4 — Surprises & Non-Obvious Findings (HIGHEST re-derivation risk)

1. **WS-syntax probe discipline (COST A LONG STRETCH in A.4)**: one-line multi-row fact
   literals — `defr e [?w] || 5 3` or `|| "a" "b" 3  "b" "c" 0  …` on ONE line — parse
   as a **SINGLE wrong-arity fact row**, so the relation has zero valid facts and every
   query returns spurious `nil`/empty. The A.4 investigation burned hours reading this
   as a "tabling materialization failure" / "DFS is broken" before recognizing the
   malformed probe. **Fact rows in probes MUST be multi-line** (each row indented on its
   own line under `||`). This is the single highest-value warning here.
2. **The premise-refutation cascade (now 7)** — this arc corrected 7 confident
   main-session premises, each caught by an independent probe/panel/audit:
   `&>`-inversion; B-as-reuse; uniform-leak; recursion-is-correct; body-local-only-
   boundary; tabling-flattens-worldviews-is-second-order; **F2-guard-is-a-crash**
   (refuted: `gt` goes STUCK on an unresolved var → silent-pass, NOT an FFI crash; a
   real crash needs a `foreign` primitive). **Discipline: run the independent probe/
   critique BEFORE locking any premise.** Expect Aspect B to have its own such premises.
3. **`&>` is the rule-clause separator** (Prolog `:-`), NOT a guard/negation operator —
   the seed's "`&>` inversion" was stale. Do not re-derive.
4. **Suite test-count is NONDETERMINISTIC** (8922↔8934 run-to-run, data-driven case
   generation). The real gate is **0 failures across all 466 files**, not the exact
   count. Don't chase a count delta.
5. **`worldview-cache` is a DERIVED projection of `decisions-state`**
   (`install-worldview-projection`, propagator.rkt:969) — an S0 belief-narrow is
   re-projected away; only a **between-round** narrow (NAF's S1 handler) persists. (This
   is why A.4's on-network guard needed a between-round handler, not an S0 fire-once.)

---

## §5 — Open Questions & Deferred Work

**Aspect B — the OPEN forks to co-design (design §6 + §11 Q-B + seed gates a-e):**
- **Q-B keying**: rename query-var → schema field name, vs a fresh positional Record.
  (B.2 schema-projection; ties to Path-Selection `^` dynamic key-rename.)
- **Gate (a)** the *typeable-goal fragment*: registered relation, named args, no
  anonymous `_`; everything else falls back to untyped (gate e).
- **Gate (b)** build the ONE shared ground/free predicate (BOTH reduction + typing).
- **Gate (c)** the two-context / relation-registry audit — incl. relations from cached
  `.pnet` bodies (the elaboration/module-load boundary; pipeline.md two-context audit).
- **Gate (d)** reconcile the TWO unbound representations (unresolved var → own-name
  fvar vs missing key → `(expr-fvar 'none)`; presence-`'optional` / Option candidates;
  explain's reserved keys are the first `'optional` clients).
- **Gate (e)** display posture vs D23 (untyped relations ⇒ rows of metas — must respect
  the F1b.6 escape-boundary tightening).
- **B.1 codata** vs **B.2 schema-projection** — both first-class; how they compose.

**Deferred to BSP-LE Track 3** (A.2b + A.4 scaffolding retires there; seed
`2026-07-20_BSP_LE_TRACK3_ONNET_SEED.md`): on-network body-local-var threading + SLG
completion + §9.6 worldview-preserving tabling + the prototyped on-network guard
mechanism (struct-fix + per-binding belief-clear + between-round handler). DEFERRED.md
+ BSP-LE Master logged.

**Deferred to a later UCS track**: `?v:Type` as CLP(X) domain-constraint *resolution*
(this track uses only the static-typing reading).

**After B**: Aspect C (schema-as-relational-facts + validation), Aspect D (efficient
fact-representation, Stage 0/1 research), Polish, then **X.close (Stage-5 PIR)** — the
track does NOT flip ✅ until the PIR lands (objective-PIR gate).

---

## §6 — Process Notes

- **Aspect B = a FULL design process** (owner's explicit ask): Stage 0 (mantra audit +
  prior-art / F1 reuse survey) → Stage 1/2 grounding-audit (the `solve` typing +
  row-build reduction + F1 row carrier + the two-context relation registry) → Stage 3
  options-panel on the OPEN forks (keying, unbound-reps, codata-vs-schema composition)
  + **owner co-design in PROSE with Q_N labels** (NOT AskUserQuestion chips —
  [[design-dialogue-preference]]) → Stage 4 implement main-session + per-change gate.
  Persist a Stage-3 design artifact / doc §6 expansion BEFORE implementing (the
  "cart-before-horse" correction from the A.2 arc).
- **Grounding-audit-per-phase earns its keep** — use the `grounding-audit` workflow
  (`.claude/workflows/grounding-audit.js`) for the grounding-HEAVY opening; the
  `design-options-panel` workflow for the high-stakes forks. R-lens-verify the returned
  load-bearing claims SURGICALLY before trusting. (Ultracode is on: lean on workflows.)
- **Per-change gate**: `check-parens` → `raco make driver.rkt` → **PROBE-FIRST** via
  `tools/run-file.rkt` (from `racket/prologos/`, **multi-line fact rows!**) → targeted
  `--tests` → full `--all --force-rerun` → commit (`git commit -F -`, stage ONLY your
  files, NO Co-Authored-By). Racket: `"/Applications/Racket v9.0/bin/racket"` (quoted).
- **Three-level WS validation** for any user-facing syntax B adds (sexp / WS-string /
  WS-file via `process-file`). Typed rows touch BOTH checkers (typing-core + qtt) — the
  pipeline.md exhaustiveness applies.
- **NEVER edit files with regex/`sed` scripts** — an ad-hoc `python re.sub` debug-
  removal in A.4 corrupted `relations.rkt` (ate `struct goal-desc` + a function head);
  recovery was a `git checkout` + re-apply. Use the `Edit` tool for surgical changes.
- **Conversational cadence**: checkpoint at each phase boundary (~1h max autonomous);
  the owner sets pace. **A tracked design that completes GETS a PIR** (objective gate).
- **Coordinates DRIFT** — re-grep before trusting any file:line in the design doc /
  memory / this handoff (the A.4 arc had 2-round-stale guard coordinates).
