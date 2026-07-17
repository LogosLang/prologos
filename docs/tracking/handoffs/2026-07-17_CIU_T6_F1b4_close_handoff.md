# Handoff — CIU Track 6 F1b: F1b.1–.4 IMPLEMENTED (the SEAL is live, D22 done); resume at F1b.5 (VALIDATE — own mini-design)

**Date**: 2026-07-17 · **Author**: the session that ran the F1b Stage-3 co-design (D21–D26) and then implemented F1b.1 → F1b.4 (seven sub-commits for the seal alone).
**Resume target**: **F1b.5 — VALIDATE**, the Result-returning runtime tabulation face. It opens with its OWN mini-design (the D22.4 pin): the witness-strength policy (refuse vs skip non-runtime-checkable fields) and the `:check` bridge retirement decision (delegate vs assertion-sugar) are OWNER decisions; the slice inherits named debt from F1b.4 (non-literal fill/checks, nested-in-container seals, partial-view runtime misses). **Protocol: grounding mini-audit → R-lens → owner dialogue on the two decisions → implement.** Then F1b.6 (the D23 posture flip; its re-trigger pin sits in DEFERRED.md) → F1b.close.

> ⚠ On-disk is authoritative. RUN `git log --oneline -15` + `git status --short` FIRST. Re-grep every coordinate cited anywhere — they drifted heavily across F1b.1–.4 (three separate stale-coordinate incidents this arc).

---

## §0 The arc this work sits in (why — the owner's through-line)

Demo-driven dogfooding is the motivating frame. The chain, oldest → now:

1. **DEMO Series** (dependency-resolver demo, `docs/tracking/2026-06-28_DEPENDENCY_RESOLVER_DEMO_DESIGN.md`): a multi-paradigm demo forcing language fixes. P0 closed; **P1 was blocked on numerics**.
2. **Num Series** (`docs/tracking/2026-07-02_NUM_MASTER.md`): numeric usability/ergonomics — Track 1 (Float/refinement/tower/literals/ergonomics, N1–N6) ✅ COMPLETE → unblocked DEMO P1. Track 2 (generic `Num` type / constraint-as-type) PROPOSED, seed note `2026-07-02_GENERIC_NUM_TYPE_NOTE.md` — **note: D21's covariant-depth deferral names `Num`-supertype schema fields as an explicit re-trigger**.
3. **CIU Track 6 F1** (this track): anonymous record & collection typing — the owner's cornerstone ruling (2026-07-16): *getting records/`Map`↔`schema` correct IN PRINCIPLE is what Path Selection and `solve` ergonomics fall out of.* F1a-core/col/F1a.2 deleted `expr-Open` (rows everywhere); **F1b Stage-3 locked D21–D26 in one co-design day; F1b.1–.4 are now implemented** (this handoff).
4. **Path Selection** (track doc §2a OPEN note): postfix `coll[…]`, broadcast `coll.[…]`, the V4 result-shape crux — STILL an open owner design conversation; nothing built beyond the degenerate `v[i]`/`v[1].b`. The F1b.4 selection semantics (read-side VIEWS) will feed it.
5. **`solve` ergonomics**: D25 DELIVERED at F1b.1 — the bound-args echo is deleted (solutions = query-var keys only, the owner's original ask); `solve-one` returns a bare map; **typed solution rows** = an own mini-track chartered at F1b.close (entry gates in DEFERRED.md).

## §1 Current work state (precise)

- **Series/Track/Phase**: CIU Track 6, F1b. **Stage-3 ✅ (D21–D26) · F1b.1 ✅ · F1b.2 ✅ · F1b.3 ✅ · F1b.4 ✅ — the seal is LIVE.** F1b.5 ⬜ (next, own mini-design) · F1b.6 ⬜ (posture flip) · F1b.close ⬜.
- **HEAD**: `66093594` (F1b.4 close docs) atop `1a9cd0de` (4f acceptance) / `4082ec70` (4e THE FLIP) / `f77e646d` (4d tombstone) / `7269dfb9` (4c :check repairs) / `dd37efd6` (4b constructor) / `0e6901ef` (4a up-shift) / `eaf115d6` (4-pre scan-universal) / `352fc28b` (F1b.3 grid) / `1801d377`+`3153319b` (F1b.2) / `83784ef9` (F1b.1) / `aa01707d` (Stage-3 close).
- **Suite**: GREEN **8790/459/0** (~125–140s ambient-dependent). **Acceptances** (all suite-gated): MAIN **89/89** (`examples/2026-07-06-ciu-t6-f1-records.prologos`) · WIDTH **6/6** (`…f1b3-width.prologos`) · **SEAL 29/29** (`examples/2026-07-17-ciu-t6-f1b4-seal.prologos` — 29/29 on its FIRST run; read it as the seal's user-facing summary).
- **What works end-to-end (WS)**: the four seal doors through ONE engine (`[Person {…}]` / `[Person m]` / `def x : Person := {…}` / `the Person e`); fill-or-error (`def c : Cfg := {}` → `c.host` → `"localhost"` — the March-era aspiration; missing-required errors NAME the field on both error routes); `:check` forcing at def commit + the swallow-to-`none` class dead; the up-shift (`def mv : (Map Keyword <Int|String>) := p` with `p : Person`); dyn-absorb/closed-error/`:closed`-refuses-open gradual boundary; selections = partial views. `expr-schema`/`expr-schema-type`/`surf-schema` NO LONGER EXIST (tombstone at the syntax.rkt deletion site).
- **Working tree**: pre-existing OWNER WIP ONLY (~15 tracked + untracked owner files) — LEAVE ALONE, stage only your files. Racket: `"/Applications/Racket v9.0/bin/racket"` (quoted); runner from `racket/prologos/`.

## §2 Documents to hot-load (ordered)

**Always-load** (per this protocol §2a): `CLAUDE.md`+`CLAUDE.local.md`; `MEMORY.md` (memory `ciu-t6-records` — current through this close); `DESIGN_METHODOLOGY.org`; `DESIGN_PRINCIPLES.org`; `CRITIQUE_METHODOLOGY.org`; this protocol; `MASTER_ROADMAP.org`; CIU master `docs/tracking/2026-03-21_CIU_MASTER.md`. Rules auto-load — internalize `testing.md` (the failure protocol) + `workflow.md` (per-change gate, co-sign windows).

**Session-specific (read IN FULL, in order):**
1. **F1 design doc** — `docs/tracking/2026-07-06_CIU_T6_F1_STRUCTURAL_RECORDS_DESIGN.md`: **§13.6 the ladder** (per-slice commit notes = the implementation record; F1b.4's row carries all seven hashes) + **§13.2 + its ✏ close notes** (the seal as landed — THE F1b.5 SPEC seed: the named debt validate inherits) + §13.7 (the scaffolding ledger — validate's `:check`-bridge row retires THERE) + §13.1/§13.3/§13.4 (the sibling mechanics).
2. **Track doc** — `docs/tracking/2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md` §2a: **D21–D26 (round 6) + the ✏ D22 implementation amendments** (M2 fill refutation; selections-are-views; closedness-only residual — do NOT relitigate) + the OPEN Path-Selection note.
3. **Dailies** — `docs/tracking/standups/2026-07-05_dailies.md` checkpoints **14–19** (the whole F1b arc; 18–19 = F1b.4).
4. **DEFERRED.md**: the D23 re-trigger pin (F1b.6's entry) · § F-carrier (the consolidated deferral home) · the typed-solution-rows + explain-restructure charters · the WIDENED union-hang entry.
5. As needed: the Stage-3 docs `2026-07-16_CIU_T6_F1B_STAGE3_{GROUNDING,OPTIONS,PROBES}.md` (the evidence base for D21–D26) + the F1b.4 mini-audit record (dailies checkpoint 18).

## §3 Key design decisions (do NOT relitigate)

D1–D20 as before (F1a/col/F1a.2 arcs). **Round 6 (owner-locked 2026-07-16/17):**
- **D21** — width = expected-tail relaxation into C_Cons (E), equality-depth; covariant depth DEFERRED (triggers: rows-writable OR `Num`-supertype fields in expected rows); the CHECK-strength boundary invariant (the seal must never be realized as row-vs-row width).
- **D22** — the seal (8 clauses) **+ the three ✏ implementation amendments** (track doc §2a): (i) M2's non-literal runtime fill probe-REFUTED — fill is TYPE-DIRECTED, preparse type-free → non-literal seals TYPE-ONLY, fill/checks at validate; (ii) selections are read-side VIEWS (extra parent fields accepted; `:requires` = READ-CAPABILITY, not completeness) → **closedness-only selection residual**; (iii) the fill/residual mechanics as landed (preparse fill on annotation-literal routes; the map-empty blanket-#t retirement WAS the flip, co-landed).
- **D23** — tightening = escape-boundary HARD ERROR at store commits (groundwork LANDED at F1b.2; **the posture flip = F1b.6**, strictly after presence [done at F1b.3] — the DEFERRED.md re-trigger pin is the entry).
- **D24** — presence: dissoc-only `'unknown`; gated-identically gradient; landed in the ONE co-signed grid amendment (F1b.3).
- **D25** — solve-shape: echo DELETED; `solve-one` → bare map + `none` (it was Option-WRAPPED, not a list); explain clobber guard (3 reserved keys, binding-wins); typed solution rows = own mini-track at F1b.close.
- **D26** — F-carrier stub (DEFERRED § F-carrier) + route-soundness as the pre-seal slice (landed F1b.2: the post-quiescence untyped-interior scan, made UNIVERSAL at F1b.4-pre).

## §4 Surprises and non-obvious findings (highest re-derivation risk)

1. **"Dead code" claims need route-verification**: the map-empty-vs-schema arms were LIVE (the map-assoc recursion's base case + the always-on QTT gate twin) — the F1b.4 mini-audit's split verdict; the loud retirement had to CO-LAND with the replacement discharge (it did, at 4e — the retirement IS the fill-or-error flip).
2. **Probe-harness artifacts**: a probe run in a context where the guard is DISARMED proves nothing — facet 4's "fully on-network" claims came from process-string with the 5th refusal check structurally off (both arming globals #f). Fixed at the root in 4-pre: `infer-on-network/full` returns the scan net + cell id; the check reads the net typing actually ran on, EVERY context.
3. **Fill is TYPE-DIRECTED** (the M2 refutation): the if-composition fill mis-types both row classes (branch unification loses the filled field on dyn rows; closed rows get value/type mismatch). Preparse has no types → non-literal fill belongs to validate's tabulation. Do not re-attempt a syntactic fill.
4. **Existing tests are design ORACLES**: the selection semantics were corrected TWICE by suite failures (extra-parent-fields idiom; the nameaddr requires-path omission) — landing on: views / read-capability / closedness-only residual / completeness-is-the-parent's. When a new discharge breaks an old test, suspect the DESIGN READING first.
5. **The WS def datum at preparse is `(def name ($angle-type S) body)`** — not `(def name : S := body)`. Instrumentation-discovered (a temporary eprintf beat guessing); the sexp shape `(def name : S body)` ALSO exists; the fill guard handles both.
6. **Mechanical deletes: substring matches eat SHARED lines** — the 4d sweep collateral-deleted an `expr-logic-var` nf arm sharing a line with a schema arm (caught by residual grep + git diff, restored). Line-exact patterns + expected-drop counts + git diff review are the discipline.
7. Standing from earlier arcs, still load-bearing: **route-matrix probing** (inline/def-bound × annotated/unannotated); the **union-state hang discipline** (NEVER append polymorphic apps / annotated-lambda defs to the main acceptance file; new canaries go in clean-state files — the width + seal files are the precedent; **a 3rd hang strike calls the dedicated session**); the `run-ns-ws-last` fixture×speculation crash (use process-file helpers for speculating shapes — `test-schema-seal.rkt`'s `run-file-string` is the template); coordinates DRIFT.
8. `keyword->string`-vs-symbol subtleties at the selection boundary (requires-paths hold racket keywords; row labels are keyword-SYMBOLS) — conversion at comparison sites.

## §5 Open questions and deferred work

- **F1b.5 VALIDATE (NEXT — mini-design first, owner decisions in it)**: (a) surface + semantics of the Result-returning runtime tabulation (`validate` as a function/form? What Result shape — `<ok Schema | err …>`?); (b) **witness-strength policy**: REFUSE schemas with non-runtime-checkable field types vs ok-with-skipped-checks (skip = two witness strengths under one nominal type — if chosen, must be a named documented posture); (c) **the `:check` bridge retirement decision** (D22.4 pin): constructor-route checks DELEGATE to validate (seal = static-seal + validate + unwrap-or-error) vs stay as assertion sugar; (d) the inherited debt: non-literal fill + checks, nested-in-container seals (the top-node class), partial-view runtime misses. Grounding starting points: `wrap-schema-checks`/`inject-schema-defaults` (macros), `seal-application-body?`/`seal-forcing-error` (driver), `check-seal-chain`/`schema-seal-residual-ok?`/`record-seals-schema?` (typing-core), the panic exemption (reduction `definitely-not-map?`).
- **F1b.6 POSTURE FLIP**: D23 escape-boundary hard error for D19-tagged undischarged metas at the store boundaries — the DEFERRED.md re-trigger pin is the entry; presence (its prerequisite) landed at F1b.3.
- **F1b.close**: the bench matrix (D21+D22+D24 fast paths — INTERLEAVED or worktree-pinned per the standing bench lesson; the owner-WIP tree makes checkout-A/B unsafe) · PIR (16 questions, checklist-first) · the typed-solution-rows mini-track charter (D25.3 gates in DEFERRED.md) · doc-truth sweep (wfle `:dept_` stale comment; the punify-p3 aspirational uncomments — `;;264/;;267` NOW WORK) · DEFERRED triage · roadmap/CIU-master refresh.
- **Beyond F1b**: F-carrier (DEFERRED § F-carrier — covariant depth, unify-internal width, refusal-relax, annotation-derived bounds, heterogeneous key-types); F-row (the §12.5 pins); **Path Selection = the OPEN owner conversation** (the partial-view selection semantics feed it); typed solution rows + explain restructure; the union-hang dedicated session (2 strikes so far); Num Track 2 (generic `Num` — D21's covariant-depth trigger).

## §6 Process notes / gates

- **Per-change gate** (exercised ~7× this arc): `tools/check-parens.sh` per `.rkt` → `raco make driver.rkt` → **PROBE-FIRST** (scratch `.prologos` via `tools/run-file.rkt`; this arc's scorecard: the M2 refutation, the def-datum shape, the selection oracles — all pre-commit) → targeted `--tests` (scoped precompile) → full `--all --force-rerun --no-precompile` (output→FILE, read once; failures→`data/benchmarks/failures/*.log`, NEVER re-run to diagnose) → commit (`git commit -F -`, stage only your files, NO Co-Authored-By).
- **Slice-opening mini-audit** (the `grounding-audit` workflow) → R-lens the synthesis surgically → THEN implement. The F1b.4 audit re-wrote the charter twice before code (map-empty liveness; the two-context gap) — it earns its keep every time.
- **Co-signed changes land as ONE commit window** (the F1b.3 grid amendment; 4e's residual+retirement). Docs fast-follow with hashes; dailies checkpoint per slice.
- **Acceptance discipline**: marker files self-verify via `tools/run-file.rkt --check`; new canary sections go in CLEAN-STATE files (hang discipline), suite-gated by cloned marker-parsing tests.
- Owner dialogue = PROSE, spaced blocks, Q_N labels; decisions → D-numbers/✏ amendments in the track doc §2a; empirically-forced corrections get surfaced at checkpoints, not buried.

---
*Handoff for the F1b.5 opening. Resume: hot-load §2, verify §1 on-disk, then open F1b.5 as a mini-design (grounding audit → owner dialogue on witness-strength + bridge retirement → implement).*
