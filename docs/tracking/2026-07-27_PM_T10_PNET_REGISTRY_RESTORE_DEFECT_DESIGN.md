# PM Track 10 — `.pnet` Cache-Hit Registry Restore Defect (GitHub #78)

**Created**: 2026-07-27
**Status**: Stage 3 (design) — implementation pending
**Series/Track**: PM Track 10 (Module loading on network + `.pnet` cache + fork isolation) — ✅ COMPLETE with [PIR](2026-03-24_PM_TRACK10_PIR.md). This is a **post-PIR defect repair**, tracked as its own unit with its own close.
**Origin**: External contributor issue [#78](https://github.com/…/issues/78) (kumavis), written against a ~4-day-old `main` (pre-`PNET_VERSION` 3). Independently verified at HEAD `3f828bc9` (branch `musing-hodgkin-bab5c1`) by main-session repro + a 5-facet `grounding-audit` workflow + adversarial completeness critic (`wf_d304af81-82b`).
**Verification HEAD**: `3f828bc9cb4a3f83f8375511136bb5a2a0c64da8`. ⚠ `main` has DIVERGED (`3bbad429`, +7 from merge-base `1b193fb3`); see §2.6.

---

## Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| P0 | Failing-test-first: pin severities 1 + 2 + durable poisoning as tests that FAIL at HEAD | ✅ `62a1a34c` | 3 of 4 cases failed at HEAD for the right reasons; anti-masking gates asserted IN the test |
| P1 | The restore repair — **table-driven** restore (§3.2a) covering the 14, with the 3 exclusions explicit | ✅ `e74719b0` | P0 red→green; suite 472/9173/0; acceptance 21/21 + 29/29. Severity 3 confirmed STILL live after it |
| P2 | **Serialize the never-restored registries** + `PNET_VERSION` bump | ⏸️ | **Fixes severity 3** (§2.4). The bump also invalidates poisoned caches (§4.P2). AWAITING owner scope ruling — this is a `.pnet` FORMAT change, outside the Option-A envelope |
| P3 | Invariant test + `pipeline.md` checklist entry | ⬜ | Must not be theater — see §4.P3 |
| P4 | Comment truth sweep: stale header (§2.5.3), the Track 10 Phase 2d/2e prior-art note | ⬜ | Doc-truth, no behavior change |
| X.close | Bench check, DEFERRED triage, PM 12 note + master link, PIR-lite, issue reply | ⬜ | Gates in §7 |

> **Revision note (2026-07-27, post-critique)**: the phase plan grew a P2 because the adversarial critique + a controlled probe showed the issue's **severity 3 is real** and is **not** fixed by Option A (§2.4). A fix shipping only P1 would close the issue while leaving a hard module-load failure live.

---

## §1 Summary

The `.pnet` cache-hit restore path writes deserialized registries to **Racket parameters only**. The 24 registry **readers are cell-primary** and the parameter is reachable only as an `or` fallback — which, because an empty `hasheq` is truthy in Racket, is **unreachable dead code once the cells exist**. Every registry entry restored from a cache hit is therefore invisible to every reader, with no error raised.

The issue's analysis is **correct in its core mechanism and substantially correct in its consequences**. Our independent verification confirms it, corrects one central claim, deletes one severity, and adds three findings the issue does not carry.

---

## §2 Stage-2 grounding (verified, HEAD `3f828bc9`)

### 2.1 Core mechanism — CONFIRMED

| Fact | Coordinate | Status |
|---|---|---|
| Restore writes 17 parameters, **zero** cell writes | `driver.rkt:2812-2883` (`grep 'cell-write\|macros-cell\|net-cell'` over the block → nothing) | verified |
| 24 readers are cell-primary | `macros.rkt` — 24 × `(or (macros-cell-read-safe (current-X-cell-id)) (current-X))`, e.g. `:6346-6347` | verified |
| Parameter fallback is **dead** post-init (empty hasheq is truthy; `macros-cell-read-safe` has no emptiness check) | `macros.rkt:531-536` | verified |
| Normal registration **dual-writes** (which is why cache-MISS stays consistent) | `macros.rkt:6340-6343` `register-ctor!` | verified |
| The sibling in the same file **gets it right** | `driver.rkt:3145-3154` (spec-store: param **and** `macros-cell-write!`) | verified |
| Severity-2 degradation is silent | `macros.rkt:9541-9556` `normalize-pattern` `[else pat]` → constructor pattern stays a **variable** → first arm swallows all | verified |

**Root-cause timing** (contributor's attribution is right): readers went cell-primary 2026-03-18 (`7fec3751`); the restore block was written/expanded 2026-03-24 (`2ef600ba`) still parameter-only — six days after the readers stopped reading parameters. It was *demoted*, not written wrong.

### 2.2 Reproduced at HEAD (main session, this branch)

- **Severity 1 — stuck term**: `process-string` importing a cached module → `[reduce minirepro::tag::t1 | t1 -> "one" | t2 -> "two"] : String` instead of `"one" : String`.
- **Severity 2 — silent wrong answer**: production `process-file`, fresh dependent over a cache-restored dependency → `[use-name t2]` returns `"one"`. Both arms collapse.
- **NEW — durable cache poisoning**: the corrupted dependent is itself serialized (`driver.rkt:3120-3123`, guarded only by a swallowed exception handler), so a **fresh process** still answers `"one"`. This is not a warm-process hazard; it is on-disk corruption that survives restarts until the cache is invalidated.

### 2.3 CORRECTION — the issue's "nothing is lost in serialization" is FALSE for 3 registries

The issue states: *"Nothing is lost in serialization — the restore writes to the wrong place."* Verified false for the `equal?`-keyed registries.

`deep-s->v` (`pnet-serialize.rkt:159-162`) and `deep-serializable->struct` (`:541-543`) both normalize **every** hash through `for/hasheq`. `subtype` / `coercion` / `specialization` are `equal?`-keyed with **cons-pair keys** (`macros.rkt:6384`, `:6416`, `:6882`; lookups at `:6397`, `:6462`, `:6897`). Runtime-confirmed:

```
orig equal?-keyed lookup:      subtype-entry
after for/hasheq round-trip:   MISS        ← information IS lost
after folding into (hash):     subtype-entry ← the fold REPAIRS it
```

**Consequence — load-bearing for the fix**: the existing `(if (hash? reg) (hash-set reg k v) (hash k v))` fold at the three sites (`driver.rkt:2824`, `:2827`, `:2850`) is **not defensive noise; it is the repair**. Any refactor that assigns the deserialized hash wholesale — to the parameter *or* to the cell — silently breaks those three lookups. The cell side is safe for the *same* reason and only that reason: `merge-hasheq-replace` (`infra-cell.rkt:141-149`) folds `new` into `acc = old`, and `old` is the cell's value seeded from the `equal?`-based parameter (`macros.rkt:593/595/615`, seed stored verbatim at `propagator.rkt:1325`). It is **not** true that "the delta's hash type doesn't matter."

### 2.4 ~~DELETION~~ → **RETRACTED**: severity 3 is REAL, by a different mechanism (2026-07-27, adversarial critique)

**This section previously deleted the issue's severity 3. That deletion was WRONG and is retracted.** The narrow analysis below is still correct, but the *conclusion* drawn from it was not — I refuted one mechanism and concluded the symptom was unsupported, without testing the symptom itself. Recorded in full because it is the exact failure mode our own Watching list names ("a recorded repro can be a red herring" — here, in the *asserting-absence* direction).

*What remains true*: there is no **index/partiality** path to a hard failure. The version gate is exact equality (`pnet-serialize.rkt:589`, `:672`); the deserializer always returns a fixed 21-element list with defaults (`:699-722`); so every length guard on both sides is dead and cannot over-index. A deserialize exception is swallowed to `#f` and falls through to correct full elaboration (`driver.rkt:2768`).

*What is nonetheless true*: **severity 3 reproduces, with the issue's exact error string**, via the **never-serialized `schema` registry** (§2.5.2) — not via a short cache list. Measured with a cold control:

| Cache state | `def sealed : Person := {:name "x" :age 1}` in a fresh module over a cached schema module |
|---|---|
| **WARM** (hit) | `imports: Error loading module minirepro::schseal: Type mismatch` — **hard load failure** |
| **COLD** (miss) | `{:name "x", :age 1} : minirepro::sch::Person` — correct |

Mechanism: the record/schema **seal** needs the schema entry to fire; `schema-registry` is never serialized, so a cache hit provides it via neither parameter nor cell, the seal arm does not fire, and the annotation mismatches. The contributor's reported string (`imports: Error loading module <M>: Type mismatch`) matches exactly — they were most likely seeing this.

**Consequence for scope — the important one**: severity 3 is **NOT fixed by Option A**. The dual-write repairs the 14 *serialized* registries; this failure needs the never-serialized registries to be **serialized in the first place**. See the new P2 (§4).

**Re-confirmed AFTER P1 landed** (`e74719b0`), with a cold control in the same session:

| Post-P1 | Result |
|---|---|
| WARM (hit) | `imports: Error loading module minirepro::schseal: Type mismatch` — still broken |
| COLD (miss) | correct |

⚠ **A trap worth recording, because it nearly produced a false "fixed" claim.** The *first* post-P1 measurement returned the correct answer, which looked like P1 having fixed severity 3. It had not: recompiling `driver.rkt` for P1 made `compiled/driver_rkt.zo` newer than `sch.pnet`, so `infrastructure-stale?` invalidated the cache and the run silently took the **MISS** path — which produces the correct answer by construction. That run then *rewrote* the cache, so the next run hit and failed. This is exactly the hazard the grounding audit flagged ("any repro or regression test MUST control the `driver_rkt.zo`-vs-`.pnet` mtime ordering or it will silently prove nothing"), and it applies to **any** measurement taken right after a compile. **Every cache-hit measurement needs an explicit hit assertion** (`pnet-stale?` → `#f`), which is why P0 carries one; P2's tests must too.

### 2.5 Additions the issue does not carry

1. **N10 — a third silent-wrong-answer channel, now ESCALATED to a hard failure.** `known-type-name?` (`macros.rkt:6982-7000`) ORs `lookup-schema` and `lookup-selection`; **both registries are never serialized at all** (0 occurrences in `pnet-serialize.rkt`). A miss makes a concrete type name classify as a type *variable* and auto-generalize into an implicit `{A : Type}` binder. My first two probes of *this* channel came back null and I recorded "symptom unproven" — **that was under-powered probing**: I tested only the soft auto-generalization channel. The **seal** channel is the hard one, and it reproduces as a hard module-load failure (§2.4). Lesson: a null probe refutes the *probe*, not the *gap*.
2. **The never-restored 7.** 24 cells exist; 17 registry slots are serialized; 14 are cell-backed. Of the 10 cells with no slot, `spec-store` + `propagated-specs` *are* covered (spec-propagation handler dual-writes on every import, `driver.rkt:3146-3154` ← `namespace.rkt:1023-1024`), and `macro-registry` is inert (`register-macro!` has zero production callers). **Live gap = exactly 7**: schema, selection, session, strategy, process, user-precedence-groups, user-operators.
   - ⚠ **The earlier claim "Option A cannot touch these — there is nothing in the `.pnet` to write" is HALF WRONG and is corrected here.** It is right that the *restore* cannot write what was never *serialized*. But (a) the correct fix is to **serialize them** (new P2), and (b) for **user-operators** the source data is *already in the `.pnet`*: specs are serialized (`pnet-serialize.rkt:596-600`, index 3) and `:mixfix` lives in `spec-entry` metadata, from which `process-spec` derives the operator registration (`macros.rkt:3913-3915` → `maybe-register-mixfix-operator`). What a cache hit loses is only the **derived** registration, because the hit path never re-runs `process-spec` — re-derivable exactly as the spec-propagation handler already re-derives spec-store entries.
3. **The restore block's own header comment is stale**, under-counting by four: `driver.rkt:2774-2776` says trait/impl/param-impl/specialization are "serialized but NOT restored" — all four *are* restored 30-70 lines below. Any scope enumeration derived from that comment is wrong.

### 2.6 Landing-tree hazard (workflow discipline, new polarity)

`main` = `3bbad429`; this branch = `3f828bc9`; merge-base `1b193fb3`; **neither is an ancestor of the other**. The `racket/` delta includes `driver.rkt`, `pnet-serialize.rkt` **and `tools/batch-worker.rkt`** — the last being our `--no-pnet-cache` no-op fix (`9303a077`). **`--no-pnet-cache` WORKS on this branch and is a NO-OP on `main`.** Landing on `main` without that fix means any cache-off A/B arm is a lie. This is `workflow.md` § "Dynamic-workflow code-state discipline" firing in a **new polarity**: previously the worktree was stale; here the worktree *is* the pin and `main` is the divergent one. **Lesson for the rule: pin by branch or worktree path, never a bare SHA.**

---

## §3 Design

### 3.1 Option selection

| Option | Verdict |
|---|---|
| **A — dual-write at the merge** | **ADOPTED**, in the improved form §3.2. Minimal, validated, addresses 14/14 of the in-scope registries. |
| B — route through `register-*!` helpers | Rejected: not every registry has a per-entry registrar with matching semantics (subtype/coercion are `equal?`-keyed; capability/property carry extra validation), and per-entry writes are N× the CHAMP ops. |
| C — retire the parameter fallback (cells as single source of truth) | **Out of scope, correctly.** It is the only option that eliminates the bug *class*, and it is already the project's stated direction. It requires moving `init-macros-cells!` ahead of preparse and giving `process-string`/`process-string-ws` the same init — which §5.1 shows is **actively dangerous today**. Routed to **PM Track 12** via a new implementation note. |

### 3.2 The shape: one `restore-registry!` helper, not 14 duplicated pairs

The issue's Option A names its own tradeoff: *"preserves the two-writer duplication, so it needs a checklist entry … or the 15th registry regresses."* We can do better without leaving Option A's risk envelope.

```racket
;; Restore one deserialized registry delta into BOTH the parameter and its cell.
;; FOLD, never assign: the .pnet round-trip collapses every hash to hasheq
;; (pnet-serialize.rkt:159-162/:541-543), so equal?-keyed registries
;; (subtype/coercion/specialization, cons-pair keys) MUST be folded into an
;; equal?-based accumulator to restore lookup semantics. Assigning d wholesale
;; silently breaks them. cell-id #f => parameter-only (the 3 registries with
;; no cell); macros-cell-write! additionally no-ops when the net-box is #f.
(define (restore-registry! param cell-id d)
  (param (for/fold ([reg (param)]) ([(k v) (in-hash d)])
           (if (hash? reg) (hash-set reg k v) (hash k v))))
  (when cell-id (macros-cell-write! cell-id d)))
```

Why this over 14 hand-written pairs:

- **The duplication the issue flags is removed at the merge site** — one call per registry, not a param write plus a cell write that can drift apart.
- **Fold-not-assign becomes structural**, encoded once, with the §2.3 reason attached — instead of a property of 14 copies that a future refactor can quietly break.
- **The 3 exclusions become explicit and self-documenting** (`#f` cell-id) rather than an absence a reader must notice.
- The `(if (hash? reg) …)` guard is applied uniformly. It is behaviourally identical for the 11 `hasheq` registries whenever `reg` is a hash (always, today), and strictly more defensive otherwise.

**Registries covered (14)** — `preparse`, `ctor`, `type-meta`, `subtype`, `coercion`, `capability`, `trait`, `impl`, `param-impl`, `specialization`, `bundle`, `trait-laws`, `property-store`, `functor-store`. Independently derived three ways: our census, the critic's, and the contributor's diff — all three agree.

#### 3.2a Upgrade under consideration — the TABLE-DRIVEN form (verified feasible)

`pipeline.md` § "Exhaustive Walkers: prefer the STRUCTURAL answer to the checklist" says a hand-maintained N-site list *is* the failure mode, and §3.5's mantra audit already admits this design fails "structurally emergent." A table-driven restore dissolves both:

```racket
;; row = (param  cell-id  pnet-index).  cell-id #f => parameter-only, on purpose.
(define RESTORE-TABLE
  (list (list current-preparse-registry (current-preparse-registry-cell-id) 4)
        (list current-ctor-registry     (current-ctor-registry-cell-id)     5)
        …
        (list current-multi-defn-registry #f 7)))   ;; explicit: no cell exists
```

Adding a registry becomes **adding a row**, and a row cannot be added without stating its cell-id (or `#f` deliberately) — the 15th-registry regression becomes unrepresentable rather than checklist-guarded.

**Prerequisite, verified independently (twice)**: the block's nested `(when (> (length pnet-result) N) …)` and per-registry `(when d-X …)` guards are **all dead**. `deserialize-module-state` always returns a **fixed 21-element list** with `(hasheq)`/`(hash)` defaults for optional slots (`pnet-serialize.rkt:699-722`), and the version gate is **exact equality** (`:589`, `:672`), so backward compatibility with a shorter list is impossible by construction. Removing them is safe and deletes ~50 lines of vestigial scaffolding.

**Decision: ADOPTED** (2026-07-27). The critique's maintainability lens raised this as **BLOCKING** — independently of my own derivation — on exactly the `pipeline.md` grounds: the design had recorded "structurally emergent ✗" and then resolved it by pointing at out-of-scope Option C, when an in-scope structural fix exists inside Option A's envelope. Two agreeing derivations plus a rule that names this failure mode is enough. The guards are **vestigial, not scaffolding** — under an exact version gate they can never fire — so "keep them for safety" would itself be a red-flag rationalization. The table also makes P1's all-or-nothing restore and P3's non-theatrical invariant test straightforward.

**Explicitly NOT covered (3)**, parameter-only and correct as such: `multi-defn-registry`, `tycon-arity-extension`, `defn-param-names`. Verified: `git grep 'current-{multi-defn-registry,tycon-arity-extension,defn-param-names}-cell-id'` → **empty**; none appears in `init-macros-cells!`.

### 3.3 Why not cherry-pick `0befd6b5`

The contributor's code is **right** — 14 sites, matching our independent derivation. What must not be inherited: a line offset of 178 (their block header `:2629` vs ours `:2807`); three stale coordinates baked into its comment (`macros.rkt:6300` → `:6346`; `driver.rkt:2971` → `:3149`); a dangling reference to `goblin-pitfalls #43` (no such doc here); the unverified severity-3 claim (§2.4); and a **`PNET_VERSION` 2 base**, so its measured A/B (`STUCK 1308ms → VALUE 1327ms`) does not transfer. We implement fresh, credit the issue, and adopt the improved shape.

### 3.4 NTT model — assessed, NOT required (stated, not skipped)

`workflow.md` mandates an NTT model for designs that "add propagators, lattices, bridges, cells, or stratification changes." This design adds **none**: no new cell, no new propagator, no new lattice, no merge-function change, no stratum. It writes an existing delta to an **existing** cell through the **existing** `macros-cell-write!` → `merge-hasheq-replace` path — the same path `register-ctor!` already uses. The Network Reality Check questions are answered by the *existing* topology, unchanged. Recording the assessment rather than silently omitting it.

### 3.5 Mantra audit — adversarial, two columns

| Word | Catalogue (does it pass?) | **Challenge (could it be MORE aligned?)** |
|---|---|---|
| ON-NETWORK | ✓ The fix's entire point is that restored state reaches the **cell**, not just ambient parameter state. | The parameter write **remains** — we ship a *dual* writer. That is a red flag by our own rules ("belt-and-suspenders masks bugs"). Honest framing: the parameter is not a redundant safety net here, it is the **live fallback for the pre-init window** (`macros-cell-read-safe` → `#f` when cell-ids are `#f`), which is a real state in module-loading and `run-ns-last` contexts. It is **scaffolding with a named retirement plan** (§5.1 → PM 12), not defense-in-depth. |
| All-at-once | ✓ One bulk write per registry; no per-entry loop over the network. | Could all 14 be **one** write? Only by unifying the 14 cells into one compound registry cell — that is PM 12/submodule-scope territory, not this repair. Noted, not attempted. |
| All in parallel | n/a — restore is a sequential fill of independent cells; no imposed ordering between them. | No inter-registry dependency exists, so nothing to free. |
| Structurally emergent | ✗ **Fails honestly.** A human must remember to add a 15th call. | The structural answer is Option C (readers read one source). We mitigate with the §4.2 invariant test (a *test*, not discipline) and name the residual gap rather than claiming the checklist closes it. |
| Information flow | ✓ Values reach readers through cells after the fix; today they reach a dead parameter. | — |

**Verdict**: aligned for the repair; the two failures are *inherited from the architecture*, both routed to PM 12 with the retirement plan written down (§5.1), not rationalized.

---

## §4 Phases

### P0 — Failing-test-first (pin the defect before fixing it)

Three cases, all of which must **FAIL at HEAD** before P1:

1. **Severity 1** — cached `data`+`defn` module consumed via `process-string` after cells exist → asserts the value, not a stuck `[reduce …]`.
2. **Severity 2** — two modules, dependency cached + dependent fresh, driven by production `process-file`; asserts a **non-first** constructor arm (`t2` → `"two"`). The non-first arm is the whole point: a first-arm assertion passes even fully degraded.
3. **Durable poisoning** (ours, not in the issue) — after the severity-2 run, a **fresh** load must not answer from a poisoned dependent `.pnet`.

**Two masking mechanisms the test must defeat** (verified, §2.1/§4.3) — a naive test proves nothing:
- Run 1's cache-**miss** elaboration dual-writes the lib's entries into the live cells, so run 2's cells already know them.
- `process-file` re-runs `init-macros-cells!` *after* preparse, re-seeding cells from the (now lib-inclusive) parameters.

⇒ the test must reach a state where the cells **exist but are genuinely ignorant** of the module.

⚠ **Two of the three escape routes originally listed here were WRONG** (caught by the critique, confirmed by probe):
- *"`process-string` (never inits cells)"* — **backwards as a standalone route.** If cells never exist, `macros-cell-read-safe` returns `#f` and the parameter fallback is **live**, which is precisely what *masks* the defect. `process-string` is useful only *after* cells have been created and made ignorant.
- *"a fresh subprocess for the warm run"* — **maximally masked** for `process-file`. In the first `process-file` of a fresh process the net-box is `#f` for the whole preparse window in which every restore happens, so the parameter fallback carries it and the answer is correct.

The defect's actual precondition, stated plainly: **a module load that happens while the registry cell-ids are non-`#f`.**

Also: `infrastructure-stale?` (`pnet-serialize.rkt:574-578`) invalidates every `.pnet` when `driver_rkt.zo` is newer, and the runner mirrors it — so the test **must control cache freshness explicitly** or it silently proves nothing.

#### P0 recipe — VALIDATED in-process, no subprocess (2026-07-27)

A third masking mechanism was found while validating: **resetting the cells alone does NOT work**, because `init-macros-cells!` re-seeds from the *parameters*, and the parameters are polluted by the cache-hit restore itself. The working recipe needs **both** halves:

1. Capture **clean parameter snapshots** (`current-ctor-registry`, `current-type-meta`, `current-preparse-registry`) *before* any lib load.
2. Prime the cache (run 1).
3. For run 2: `parameterize` to the clean snapshots, then `(current-persistent-registry-net-box #f)` → `init-persistent-registry-network!` → re-init **all four** cell families (`init-macros-cells!`, `init-warning-cells!`, `init-narrow-cells!` [from `global-constraints.rkt`, not `narrowing.rkt`], `init-attribute-map-cell!`). Omitting any one crashes with `net-cell-reset: unknown cell`.
4. Assert the cells are genuinely ignorant (`(hash-ref (read-ctor-registry) 't1 #f)` → `#f`) — **this assertion is the anti-masking gate and must be in the test**, not just the setup.

Measured at HEAD with this recipe:

| Case | Consumer | Result at HEAD |
|---|---|---|
| Severity 1 | `process-string` | `[reduce minirepro::tag::t2 \| t1 -> "one" \| t2 -> "two"] : String` — **STUCK** |
| Severity 2 | `process-file`, fresh dependent over cached dep | `"one" : String` for `[use-name t2]` — **WRONG** |

Both are deterministic and subprocess-free, so they run under the batch worker without the spawn/timeout/collection-path hazards.

### P1 — The restore repair (severities 1 + 2)

Table-driven restore per §3.2a, covering the 14, with the 3 exclusions as explicit `#f`-cell rows. P0's severity-1 and severity-2 cases flip to green.

**Two hazards the critique surfaced, to handle here**:
- **Partial-restore swallowing.** An exception mid-restore leaves registries 1..k-1 restored and k..14 not, with the module already registered and **zero diagnostic** — because preparse wraps `process-imports` in `(with-handlers ([exn:fail? void]))` (`macros.rkt:2686`). (Note: *not* the `with-handlers` at `driver.rkt:2768`, which wraps only `deserialize-module-state` — the critique mis-cited this; the hazard is real via the preparse handler.) The table-driven form makes an all-or-nothing restore easy: build every row's new value first, then commit.
- **The `(if (hash? reg) …)` guard is NOT "strictly more defensive."** On a non-hash accumulator it **discards the parameter's entire prior content** and restarts from a one-entry hash. Correcting §3.2's claim: it is a *data-losing* fallback that happens never to fire today. Keep it only where it already exists (the 3 `equal?`-keyed sites), and do not advertise it as hardening.

### P2 — Serialize the never-restored registries + `PNET_VERSION` bump (severity 3)

Add the live never-serialized registries to `serialize-module-state` / `deserialize-module-state` and to the restore table. `schema` and `selection` are the proven-symptom pair (§2.4) and are the minimum; `session`, `strategy`, `process`, `user-precedence-groups` follow the same shape. **`user-operators` is different** — it is *derivable* from the already-serialized specs (§2.5.2), so prefer re-deriving it (mirroring the spec-propagation handler) over serializing a second copy of the same information.

**The `PNET_VERSION` bump is required, for two independent reasons**:
1. **Format change** — new fields.
2. **Poison invalidation** — §2.2 documents durable on-disk corruption, and `infrastructure-stale?` is **not** a reliable invalidator: it requires `compiled/driver_rkt.zo` to *exist* (`pnet-serialize.rkt:574-578`), so with no compiled dir it returns `#f` (not stale) and poisoned caches stay live *after* the fix ships. The version bump is the only reliable sweep.

### P3 — Anti-regression for the 15th registry (must not be theater)

The naive form — "assert param ≡ cell for the 14 pairs" — is **not a gate**: (a) it cannot catch a *15th* registry, because a hand-enumerated list in the test cannot detect an omission from a *different* hand-enumerated list in `driver.rkt`; and (b) as specified it can pass at HEAD, since after any `process-file` the re-seed makes cell ⊇ param regardless. Under the table-driven form (§3.2a) the honest version is instead: assert **every row of `RESTORE-TABLE` with a non-`#f` cell-id lands in its cell** after a cache hit, driven *from the table itself* — so a new row is covered by construction and a row added with a `#f` cell-id is a deliberate, visible choice. The `pipeline.md` entry stays as the weaker, human half.

### P4 — Comment truth sweep

Correct the stale block header (§2.5.3) and the Track 10 Phase 2d/2e prior-art note at `driver.rkt:117-127`, which already recorded this exact incompleteness class ("make cache-hit path a COMPLETE replacement for full elaboration side effects") and should not be left implying the problem is still open.

### X.close

Bench sanity (cache-hit path must still be a hit — assert no re-elaboration rather than assuming), DEFERRED triage, the PM 12 note + master link (§5.1), PIR-lite, issue #78 reply.

### 4.3 Test-infrastructure facts (verified)

- `test-record-pnet-cache.rkt:44-124` is the right harness template (temp lib dir, temp consumer, `pnet-path-for-module` cleanup, run1-writes/run2-hits) **but its fixture masks the bug in-process** (both runs use `process-file`), and its `parameterize` (`:73-77`) rebinds only 5 registries — **not** `ctor` or `type-meta`, which a `data` test needs.
- **There is no cache-dir override**: `pnet-cache-dir` is a plain `define` (`pnet-serialize.rkt:552`), not a parameter. Tests must clean up by `pnet-path-for-module`. The only knobs are `current-use-pnet-cache?` / `current-pnet-write-enabled?`.
- `test-record-pnet-cache.rkt:118-122`'s "a stray top-level `.pnet` starves the pregen heuristic" rationale is **STALE** — the heuristic was hardened 2026-07-14 (`tools/run-affected-tests.rkt:627-641`). Do not design around it.

---

## §5 Explicitly out of scope

### 5.1 Option C → PM Track 12 (new implementation note)

Retiring the parameter fallback is the only structural cure, and it is **actively dangerous to attempt today**: the accidental healing (`init-macros-cells!` re-seeding after preparse) is currently *load-bearing* — it is what masks the `process-file` case. A naive once-guard, or moving init earlier, would **remove the healing and widen #78's blast radius** before the replacement invariant exists. It also intersects the §5.2 bridge defect. Captured in a dedicated note, linked from the PM Series Master § Track 12, per the existing note pattern.

### 5.2 Adjacent defect — eager cell-id capture in the resolution bridges (file separately)

Verified: `make-pure-trait-bridge-factory` (`resolution.rkt:460-462`) and `make-pure-hasmethod-bridge-factory` (`:552-555`) capture `(current-impl-registry-cell-id)` **eagerly**, and are invoked at `driver.rkt:3623-3624` at **module level**, where those cell-ids are still `#f` — permanently. Combined with `read-persistent-registry-cell` (`resolution.rkt:408-413`), which has **no parameter fallback** and returns `(hasheq)` on a `#f` cid, the pure trait/hasmethod bridges read an **empty impl registry in every process**. Separate issue; must not ride along. It also constrains PM 12 (§5.1).

### 5.3 The never-restored 7 (§2.5.2) — separate filing

Option A cannot address these. Code-verified gap, symptom unproven — file with that confidence level stated, do not overclaim.

---

## §6 Meta: a tooling defect found by this audit

The `grounding-audit` template passed the facet spec as the literal string `undefined` to ≥3 of 5 facets, so they ran **overlapping full-surface audits instead of partitioned slices**. Consequence: "N facets agreed" was **not** independent corroboration on this run, and the shared blind spot was real — *all five* missed both the `for/hasheq` collapse and the `batch-worker.rkt` divergence; only the adversarial critic caught them. Fix the template's arg plumbing before the next use, and treat facet consensus with suspicion until then. (This is itself evidence for the completeness-critic-as-default rule.)

---

## §7 Gates

- P0 tests fail at HEAD, pass after P1 (failing-test-first, per `.claude/rules`).
- Full suite green **in this worktree** (471 files; the 6 foreign-resolver failures are fixed as of `9303a077`).
- Both acceptance files `--check` green.
- The cache-hit path is still a **hit** in the bench check (asserted, not assumed — `infrastructure-stale?` invalidation makes assumption unsafe).
- Issue #78 answered with: confirmed + what we corrected (§2.3, §2.4) + what we added (§2.2 poisoning, §2.5).
