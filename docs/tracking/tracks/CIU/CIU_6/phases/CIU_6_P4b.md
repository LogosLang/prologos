# CIU 6 — D4, §5.P4b

Part of [D4](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md), CIU 6's implementation design, split into its parts on 2026-11-06 (owner-approved). This file holds D4 as it stood at `3e76762d`, unchanged except link targets: D4 lines 6597–7337 are lines N-6590 here.

---

<a id="p4b"></a>

#### §5.P4b — The ONE selector carrier + wholesale path migration  (mini-audit folded 2026-07-31)

**The mini-audit** (`wf_1cb9d606-89c`, 5 HEAD-pinned read-only facets +
adversarial completeness critic @ `2cef148b`, 6 agents / 1.17M tokens).
**FOUR of the seven design claims did not survive**, and the critic found a
BLOCKING objection no facet connected. Every load-bearing finding below was
R-lens-verified on the main thread before folding.

**Design-claim verdicts:**

| Claim | Verdict |
|---|---|
| C1 — all four fold callers head-agnostic, `$select`/`map-get` fold identically | **REFUTED.** Head-agnostic AT THE FOLD (callers re-pinned: macros.rkt:1962, :2611, :6113, :6499), but one step downstream `preparse-expand-form` carries a DEDICATED `$select` partial-opacity arm (macros.rkt:2013-2019) that `map-get` never touches — `map-get` falls to the generic list arm and gets FULL subform recursion. Two of the four callers re-enter `preparse-expand-form` directly, so they do NOT fold identically end-to-end. Rider: a loud→silent slide — `map-get`'s parser arm has an arity ceiling of 2 (parser.rkt:2663), `$select`'s has NO count check (parser.rkt:1195-1209), so a zero-hole pipe step that errors loudly today becomes an extra BRANCH silently. |
| C2 — ZERO new typing work | **REFUTED** → withdrawn by Q_U10. Three divergent subject postures, and the walks are DELIBERATELY non-delegating (typing-core.rkt:637-639 says so in a comment). |
| C3 — one line in `select-map-exprs` | **UNDERCOUNTS BY ONE WALKER, and it fails SILENTLY.** The 6-walker funnel is real (syntax.rkt:780-782; shift/subst/zonk×3/nf all route through it), but `uses-bvar0?` (pretty-print.rkt:1042, select arm :1226) is a SEVENTH hand-armed walker OUTSIDE it: `[(expr-select subject _)` with a comment asserting "subject is the only expr slot". Correct today; the moment branches hold an expr it under-reports bvar0 usage with no error — the `pipeline.md` § Exhaustive Walkers signature exactly. Cleared as safe by construction: `occurs?` (unify.rkt:240) and `expr-subfields` (typing-errors.rkt:73-87) are generic `struct->vector` walks; `conv-nf` falls to `equal?`; `narrowing.rkt` has ZERO references. |
| C4 — no PNET_VERSION bump | **CONCLUSION CONFIRMED, REASONING REFUTED.** §8 R6's symbol-keyed/additive argument covers struct ADDITION only; P4b does an ARITY CHANGE and a TAG REMOVAL. On arity mismatch `(apply ctor fields)` raises — but driver.rkt:2892 wraps deserialization in `(with-handlers ([exn? …]) …)`, so it is SWALLOWED into silent re-elaboration. On tag REMOVAL the reader's `[else v]` (pnet-serialize.rkt:589-599) returns a RAW VECTOR with **no exception at all**, so the handler never fires and the impostor lands in the module env (the `pipeline.md` § New AST Node item-6 failure). What actually makes "no bump" true is `infrastructure-stale?` (pnet-serialize.rkt:664-671): any syntax.rkt edit rebuilds `driver_rkt.zo`, whose mtime then invalidates every `.pnet`. **Corollary — the registration ROUTE must FLIP**: `expr-select` uses `regN!` (loud on arity drift); `expr-path`/`expr-Path` use `auto-cache!` (:542), whose body SWALLOWS exceptions so a stale-arity call voids the registration silently. P4b must DELETE that line, not repoint it — the rationale is already written in-tree for the identical `expr-map-get` case (pnet-serialize.rkt:336-341). |
| C5 — Q_T2 asymmetry live | **CONFIRMED, and WIDER: it is THREE-WAY.** dyn pair (typing-core.rkt:564-567 vs :677-678) + Map pair (:2205-2213 vs :663) — and the Map pair runs the OPPOSITE direction on the hit case. |
| C6 — the ω fence | **CONFIRMED but UNDERSTATED: the fence is a REPAIR of a LIVE defect, not only a forward guard.** Multi-branch truncation is ALREADY a silent wrong answer at five `(car (expr-path-branches …))` sites (reduction.rkt:3431/:3446/:4445/:4454) plus the elaborator's static inline (:2285/:2363), and BOTH existing static guards (elaborator.rkt:2346-2347, :2349-2351) are structurally BYPASSED by the expression/dynamic route. |
| C7 — vacuous ground `Path` | **CONFIRMED** (typing-core.rkt:2050-2051 discards branches with `_`; unify.rkt:799 is unconditional `ok`). Refinement: `#p()` empty is a DIFFERENT failure class (reader-layer `Unbound variable`), so "vacuous" does not predict it. |

**⭐ THE REAL CARRIER-SHAPE DECISION IS THE SEGMENT ENCODING MISMATCH — and
none of the three candidate shapes named it.** `expr-path` branches hold
`expr-keyword`/`expr-symbol` **structs** (minted at elaborator.rkt:2257-2266);
`expr-select` branches hold bare **symbols** plus `(@key name cont)` /
`(@sub . branches)` / `(@ord N)` **s-expressions** (syntax.rkt:786-800,
classified at :860-873). The shapes were framed as ARITY questions (new field
vs branches-slot vs new struct); the actual cost is an **encoding convergence
plus a rewrite of every step consumer**, which is invisible from any
constructor-count analysis. Settle the encoding BEFORE trusting any edit-site
list. Facet 1's recommendation (shape **a′**: repurpose `expr-path` INTO the
carrier and place it in `expr-select`'s existing `branches` slot, preserving
`expr-select` arity 2 and inheriting the eight pipeline arms `expr-path`
already carries) survives only if the encoding question is answered first.
Note also facet 1's structural point: a bare `#p(a.b)` is a STANDALONE VALUE
in expression position (`def p1 := #p(name)` is live), so the unified carrier
MUST be an `expr?` with its own arms — shape (a) as literally written cannot
carry `#p(…)`, and (a)/(c) are therefore not two sizes of the same thing.

**Scope facts the design under-counted:**

- **The RED set is 25 tests across SEVEN files**, not the "4 of 6 in one file"
  §5.P4 names: test-postfix-index-02 (10) · test-implicit-map-01 (4) ·
  test-dot-access-01 (3) · test-nil-type (**3, not 4** — the other three are
  `$retired-selection` markers and a no-sentinel passthrough, all
  migration-invariant) · test-mixfix-01 (2) · test-path-selection:1501 (1) ·
  **test-dot-access-02 (2, failing by TYPE ERROR not datum shape — the file
  both fold-census facets missed).**
- **`expr-path` has a LIVE FFI SURFACE** that Q_U5's carrier round did not
  mention: `path-ops.rkt:33-121` (6 shims, each `expr-path?`-guarded) bound by
  `lib/prologos/core/path.prologos:12-17`, plus `unify.rkt:799`,
  `foreign.rkt:362` (`[(expr-Path) 'Path]` marshalling tag) and
  `union-types.rkt:102` (ordering key). Retiring `expr-path` re-points a
  FOREIGN MODULE, not just Racket call sites. `path-branch-count`
  (path-ops.rkt:83-88) is already a grade predicate in primitive form.
- **The ω fence is VACUOUS inside its own slice** unless written as a total
  `case` over `select-step-kind` terminating in `select-step-kind-unhandled`
  — the step vocabulary is a CLOSED union with **no ω member** until P4c mints
  `(@bcast step)`. Write it as the total dispatch (P4a's mechanism), so it
  becomes live the moment the kind lands.
- **`_.field` sections silently retire, unpinned.** `map-get` and `map-assoc`
  ARE in `sectionable-op-keywords` (parser.rkt:703-730); `get`,
  `nil-safe-get` and `$select` are NOT. So `_.field` currently desugars to a
  hole-domain lambda and would stop. `_[k]` IS pinned
  (tests/test-path-selection.rkt:598-599); `_.field` has **no test anywhere**.
- **`whnf-trivial?` holds `expr-Path?` (the TYPE) but not `expr-path?` (the
  VALUE)** — reduction.rkt:2010-2065. A literal is a canonical form with no
  head rule, so by the predicate's own criterion it belongs there; its absence
  means every `#p(…)` reaching whnf pays the full ~990-arm match. A live
  `pipeline.md` core-item-4 gap one line from a P4a deliverable. **P4b
  DECISION**: a reducible carrier must stay OUT, a literal carrier must go IN.
- **The `expr?` predicate gap is ASYMMETRIC and still open**: `expr-select?`
  is registered (syntax.rkt:1620); `expr-path?`, `expr-Path?`, `expr-get-in?`,
  `expr-update-in?` are NOT. §5.P1a item 8 deferred this to "P2's mini-audit"
  and it did not close. P4b closes it by construction or carries it forward.
- **A SIXTH hand-maintained sentinel enumeration**: `tools/form-deps.rkt:42`'s
  `syntax-keywords` (carries `$dot-access`/`$dot-key`/`$retired-selection`,
  not `$select`) — it EXCLUDES syntax keywords from the stdlib dependency
  graph, so an unlisted head is silently counted as a reference to an
  undefined name. Joins `pattern-var?`, `access-sentinel?`, namespace.rkt:896,
  `sectionable-op-keywords`, and `tools/reader-corpus-ab.rkt:76-80`. Note the
  RETIREMENT direction is a different surface from §Q8.5's nine MINTING sites.

**⚠ Three doc-truth defects in THIS document, found by the audit:**
1. §5.P2 audit finding 6 says `rewrite-dot-access` has **THREE** production
   callers at macros.rkt:1957/:2527/:6236; §5.P4's P4b bullet says **four**.
   The code says FOUR and **none of the three cited coordinates lands**.
2. §5.P4b's "4 of the 6 go RED" at test-nil-type is **3 of 6**.
3. §8 R6's no-bump reasoning is right by accident (see C4).

Status: ⬜ — scope re-derived; the encoding decision and the slice split are
the open items.

<a id="p4b-i"></a>

##### §5.P4b-i — Encoding convergence + the carrier repurpose

**Slice 1 — Q_U11 retirement** (`f072c115`): see §3 Q_U11.

**Slice 2 — the encoding convergence** (this slice). `expr-path`'s branches
now hold **bare symbols** — the same step vocabulary `expr-select`'s branches
use (syntax.rkt:786+). `#p(a.b)` and `x{a.b}` therefore carry ONE
representation of the selector, which is the substantive half of Q_U5.

Six consumer sites re-pointed, all of which had used a segment DIRECTLY as an
`expr-map-get` key: the `get-in`/`update-in` whnf arms + their `nf` twins
(reduction.rkt), and the two elaborator static inlines. Plus the
pretty-printer, whose `expr-keyword?`/`expr-symbol?`/`[else "?"]` cond
collapsed to a single symbol render (its `[else "?"]` was another silent
catch-all of the P4a family).

**The FFI became the MARSHALLING BOUNDARY**, which is where marshalling
belongs: `path-head` marshals a symbol OUT to a Prologos keyword value;
`path-from-segments` marshals keywords IN and **refuses** a non-keyword rather
than coercing it — coercing an unrecognized segment into a key is precisely
what made `#p(a.*)` fabricate `<error>` values (Q_U11).

**`whnf-trivial?` gained the selector carrier** — a DECISION, not an
inheritance (the audit named it as one). Verified: `whnf-impl/match` has NO
`expr-path` arm at any indent, so it already fell to `[_ e]` (identity), and
`nf`'s arm is `[(expr-path _) e]`. A literal with no head rule is exactly this
predicate's criterion. `expr-select` — the APPLICATION — is reducible
(whnf arm reduction.rkt:2967-2982) and stays OUT. Same
type-former-without-its-value-carrier gap P4a closed for champ/rrb/hset, one
line away and missed by that census too.

**Method**: this is a behaviour-preserving refactor, so the pins were written
BEFORE the change and had to stay GREEN — the pins ARE the claim. Six FFI/E2E
characterization pins (`head` · `tail` · `depth` · `branch-count` · `leaf?` ·
`get-in`/`update-in`) plus the whnf identity pin. Test delta **+7** (229 → 236).

⚠ **FILED, PRE-EXISTING, not caused by this slice** (characterized at
`f072c115` while writing the pins): `p::segments` **whole-file ABORTS** —
`path-segments` builds a Prologos cons-chain while the foreign marshaller
expects a RACKET list, so the declared `Path -> [List Keyword]` never
marshalled. `from-segments` and the `path-append` combinator built on it are
dead with it. 5 of 6 primitives work. Deliberately NOT pinned (a whole-file
abort would take the test file with it).

⚠ **b-i DOES NOT YET END SINGLE-CARRIER.** The remaining structural step is
nesting `expr-path` INTO `expr-select`'s `branches` slot so there is literally
one selector struct. Held back deliberately: that slot change makes the slot
hold an **expr**, which activates the audit's C3 finding (`uses-bvar0?`,
pretty-print.rkt:1226, recurses into the SUBJECT ONLY) and requires
`select-map-exprs` to map into the selector. Walker-shaped work, owed its own
failing-test-first pass. **This slice is "one encoding", NOT "one carrier"** —
stated so the phase headline does not outrun what shipped (the
Validated≠Deployed shape).

**Process note**: the targeted runner's 30 s default now aborts this file (the
FFI pins add `process-file` cycles) — `raco test` reported 235 passing while
the runner said `ABORTED — 0 timeouts`. Use `--timeout 180`; an abort here is
not a failure.

**Slice 3 — the SLOT NESTING (b-i now ENDS single-carrier).**
`expr-select`'s `branches` slot holds an **`expr-path`** — the reified
selector — rather than a raw list. After this there is exactly ONE way to hold
a selector, which is Q_U5's "three spellings, one representation" made
structural: `#p(…)` is a bare carrier, `x{…}` is a carrier applied to a
subject, and path position mints the same carrier.

Sites: 1 mapper (`select-map-exprs`, now mapping BOTH slots) · 4 positional
matches unwrapping (`pretty-print` · `typing-errors` · `reduction` ·
`typing-core`) · 2 constructors wrapping (elaborator, and reduction's
re-construction) · 5 test constructions. `qtt.rkt`'s match binds `_` and
needed no change.

**The audit's C3 finding, resolved rather than inherited.** C3 said
`uses-bvar0?` (pretty-print) recurses into the SUBJECT ONLY, under a comment
asserting "subject is the only expr slot" — a silent under-report the moment
the slot holds an expr. This slice is that moment. Two facts make it
tractable: (i) all six `expr-path` walker arms are `[(expr-path _) e]` — pure
identity — so mapping into the slot is a no-op; (ii) at P4 the monomorphic
ruling means a selector holds bare SYMBOLS, never exprs, so the walker could
not have under-reported anything yet. **So C3 is real as a class and INERT at
P4** — it goes genuinely live when BOUND selectors land (F-row). The walker is
corrected here anyway, because "inert today" is exactly how the silent-walker
class starts. `uses-bvar0?` is exported for the pin (a bvar inside a selector
is unconstructible from surface syntax, so the pin must call it directly —
same rationale as P4a's `select-reduce` export; zero behavioural change).

**Test delta +4** (236 → 240): the slot holds the carrier · the mapper
preserves it · `uses-bvar0?` recurses · the surface is unchanged E2E.

**On the NAME**: the design says "`expr-path` retired within P4b, never
aliased past it", which facet 1 read as a rename into the unified carrier.
The struct IS now the one selector carrier; only its NAME is legacy. That is
not an alias and not a dual path — there is one struct — but the rename is
deliberately NOT done here: it is ~30 arms of pure churn (substitution ×2,
zonk ×3, nf, pp ×2, typing-core, qtt, pnet, path-ops ×7, reduction ×8,
elaborator ×2, unify, foreign, union-types) with no semantic content, and
bundling it into a behaviour-preserving slice would make the diff unreviewable
for zero benefit. Named as cosmetic follow-up rather than left implicit.

Status: ✅ b-i COMPLETE (Q_U11 retirement ✅ · encoding ✅ · single-carrier ✅;
the carrier's NAME is a named cosmetic follow-up).

<a id="p4b-ii"></a>

#### §5.P4b-ii — The `$dot-access` fold migration (mini-audit folded 2026-07-31)

**Mini-audit** `wf_f8568392-b44` (5 HEAD-pinned facets + completeness critic
@ `2e3fc14e`, 6 agents / 1.22M tokens). Re-pinned from scratch because the
SolveCarrier merge invalidated every P4b coordinate. Load-bearing findings
R-lens-verified on the main thread.

**⭐ THE SORT AXIS IS THREE-VALUED** — see Q_U12. This is what forced the
scoping ruling; the design's "2-D (subject kind × sort)" table was itself an
under-specification.

**⭐ ASYMMETRY #3 (NEW) — SELECTION-TYPED SUBJECTS.** `.f` projects THROUGH
the view and is READ-CAPABILITY-GATED (an out-of-view field errors); `{f}`
refuses via the catch-all `'subject-other`, whose message **LIES** ("the
subject is not a record") and names no remedy. The refusal is deliberate
(DEFERRED 20); the diagnostic does not say so. Joins the dyn-row asymmetry
(Q_T2) and the Map asymmetry (Q_U10) — **three**, and the table must be
indexed by (subject kind × sort) with all three.

**⭐ `_.field` SECTIONS WORK — and wholesale minting deletes them, untested.**
Probe-verified at HEAD: `[_.a {:a 7}]` → `7 : Int`; `map _.a recs` →
`@[1 2] : [PVec Int]`; `map _{a} recs` → ERROR. Mechanism: `map-get` ∈
`sectionable-op-keywords` (parser.rkt:755) + the gate (:1355-1360), which
`$select` **cannot reach** because its arm is dispatched EARLIER in the same
cond (:1238). ⚠ **This document previously implied `_[k]` is a working
symmetric case — it is not**: `_[k]` is pinned as a guided REFUSAL
(tests/test-path-selection.rkt:598-600), because the postfix leg has a `_`
guard (macros.rkt:6039-6040) that the DOT leg deliberately lacks. The
asymmetry is intentional; the deletion would not be. **b-ii-3 owns the
rescue**; `_.field` has NO test anywhere.

**⭐ THE RED CENSUS IS STRUCTURALLY WRONG, not merely undercounted.** "25
across 7 files" is a **datum-shape** census, and the failure mode that
matters — a VALUE assertion going red by TYPE ERROR — is invisible to it.
Missing entirely:
- `tests/test-first-class-paths.rkt:88-130` — WS-mode, value-asserting
  dot-access, in the ONE file testing `#p(…)`/`get-in`/`update-in`, i.e. the
  surfaces Q_U5/Q_U6 absorb. **Highest-coupling RED file in the tree; named by
  no facet and no design census.**
- `tests/test-selection-paths.rkt` (~8 cases) — the corpus for
  `reconstitute-selection-paths`, a **SIXTH** `$dot-access` consumer.
- `tests/test-route-soundness-01.rkt:152-157` and
  `tests/test-implicit-map-02.rkt:155-162` — more Map-posture pins.
- `tests/test-dot-access-02.rkt` has **FIVE** Map value-assertions
  (:112, :121, :145, :153, :170), not the two this doc cited.
- **A FIFTH fold entry point**: the `rewrite-nil-dot-access` alias
  (macros.rkt:6086) has zero production callers but THREE direct test callers
  — on the edit surface while absent from every "four callers" framing.

**THE FOUR CALLERS ARE NOT UNIFORM** — per-caller obligations differ, and
`preparse-expand-subforms` (macros.rkt:2665) is the dangerous one: the
`$select` arm is PARTIALLY OPAQUE and skips sibling-level passes that
`map-get` gets through the generic arm, so a naive mint makes every `.field`
in the tree lose infix / implicit-map / sibling-let processing. The migration
must either route the minted head through the generic arm or widen the
`$select` arm — decided per caller, not once.

**THE MAP POSTURE APPLIES AT EVERY DESCENT LEVEL**, not just the leaf —
`outer.inner.a` through an intermediate Map is a pinned surface. Sort is a
property of the whole carrier, so threading it down suffices, but ALL THREE
per-level dispatches (`walk-to-leaf`, `select-branch-entries`,
`select-below-field`) must take the Map arm. Prior art for the shape:
`select-below-field`'s ordinal-STEP arm ("descend, contribute NO output
level", Q_U2 Reading A) generalized to keyed steps — reusing it keeps the
reduction twin together, which is where P4a's self-review already caught an
omission.

**⚠ DOC-TRUTH DEFECTS IN THIS DOCUMENT** (found by the critic):
1. **Four places disagree** on which phase owns `quests:t`/`quests:{t r}` —
   the P4c bullet claims them, the P4d bullet says they are re-fated to P4d,
   the SolveCarrier back-note says P4d, the pause summary repeats P4d.
   **RESOLVED by solve→PVec: they are P4c PVec broadcasts.**
2. **Consequence undrawn**: with solve→PVec landed, **P4d's List refusal has
   NO corpus instance** and needs a purpose-built fixture.
3. The corpus cite `:235` is stale by 3 (the lines are :232/:233).

**ADJACENT, NOT IN b-ii's BLAST RADIUS but the natural place to close it**:
the `ns` silent-segment-drop guard has **THREE UNCLOSED NEW INSTANCES** —
probe-verified, `ns foo{bar}` and `ns foo#.bar` both accept at 0 errors and
silently drop the segment, while `ns foo.bar` correctly aborts. The guard
(namespace.rkt:895-896) enumerates **2 of the 8** sentinels in
`access-sentinel?`. Exactly the bug class `b0db8f3e` fixed and the P2 audit
re-closed for `.N`; P1b/P3 minted new family members and nobody extended it.

<a id="p4b-ii-1"></a>

##### §5.P4b-ii-1 — The (subject kind × sort) semantic table  ✅

**Scope, as ruled mid-slice [owner]**: cover **ALL** asymmetries, not just
Q_U10's Map posture, **including the diagnostics**. Typing-side only — no fold
change, so the RED set stays green and the posture is pinned cell-by-cell
before anything migrates.

**The sort is a FIELD on the carrier** [owner]: `expr-path (branches sort)`,
`'path | 'block`. Rejected: a distinguished step kind (the sort is a property
of the whole carrier, not of any step) and a second struct (reopens
"ends single-carrier" one slice after b-i closed it). It cannot be DERIVED:
today a bare carrier is `#p(…)` and a nested one is a block, but after b-ii-2
`x.a` and `x{a}` are the same node shape. **`auto-cache!` DELETED in the same
slice** (ruling C4) — its body swallows exceptions, so this arity change would
have voided the registration silently; now `regN!`/`reg0!`, which error loudly.

**The Map posture takes option (b)** [owner] — a `select-uniform` marker.
Rejected: **(a)** synthesize a closed row from the requested labels (fabricates
a support the subject lacks, and it would flow into result-shape computation as
if the key set were known — this track's failure history is fabrications that
type-check); **(c)** fold Map into the dyn-row machinery (merges two postures
Q_T2 and Q_U10 separated, whose RUNTIME behaviours differ — Map miss = loud
panic, dyn miss = D19-permissive meta; the merge would be invisible later
precisely because it reads as a simplification).

**The table, as shipped** (all four asymmetries + the cells that deliberately
AGREE):

| subject | `'path` | `'block` |
|---|---|---|
| keyword record, present | field type | field type |
| **Map** (Q_U10) | `select-uniform` at V, **key type checked** | `'subject-map` |
| **dyn row**, presence `'unknown` (Q_T2) | fresh meta (D19/D24) | `'unknown-presence` |
| **dyn row**, unlisted | fresh meta | `'miss-dyn` |
| **selection view** (NEW #3) | `select-view`, capability-gated | `'subject-selection` |
| **union** (NEW #4) | `select-union`, per-component ⋃ | `'subject-other` |
| closed row, missing | `'miss-closed` | `'miss-closed` — **agree** |
| nat/ordinal | unreachable at b-ii by Q_U12 scoping | ordinal dispatch |

**Both diagnostics repaired.** The block-over-view message was reaching
`'subject-other`, whose text ("the subject is not a record") is FALSE of a
selection — it IS a record, restricted — and named no remedy; it now names the
view, explains the `:requires` bypass, and gives two remedies. **This half is
LIVE at HEAD.** The out-of-view message (`selection-not-in-view`) is written
and pinned but only reaches users at b-ii-2, since `.field` still routes
through `expr-map-get`.

**Self-review caught the sort axis was a SILENT CATCH-ALL** — `(if (eq? sort
'path) … …)` gave any other value block semantics, P4a's exact class on a fresh
axis one slice later, and load-bearing because Q_U12 already NAMES the next two
sorts (`#.field`, `[k]`). Now `select-sorts` + `select-sort-unhandled`
mirroring the step-kind machinery. Pin validated by re-introducing the defect.

#### ⚠ THE ADVERSARIAL VERIFY — 4 skeptics, and it earned its keep

Three defects in what shipped, plus three unpinned claims. **All re-verified by
main-thread probe before acting.**

1. **A LIVE CAPABILITY BYPASS.** The selection arm was placed BELOW the schema
   arm; the reference (`expr-map-get`) orders them the other way. Both
   registries accept the same name, so `schema Person` + `selection Person from
   Person` is constructible — and `u{age}` returned **`{:age 9}` at 0 errors**
   for an out-of-view field. The `'block` half was PRE-EXISTING (there was no
   selection arm at all); what this slice did was add the arm and put it where
   a colliding name could never reach it, and ship a test asserting "a block
   over a view still refuses" that was FALSE for that case. Read-capability
   cell — the bar is higher. Fixed; order is now reference-matched and
   commented as load-bearing.
2. **The Map arm dropped the KEY-TYPE check.** The reference is
   `(if (check ctx k kt) vt (expr-error))` — TWO obligations; only the miss
   half was implemented. Probe: `mi : (Map Int String)` / `mi.a` REFUSES at
   HEAD, and the first cut would have admitted it, degrading to a runtime panic
   at b-ii-2. `select-uniform` now carries the key type.
3. **MY FIXTURE WAS MALFORMED.** `requires-paths` is a list of PATHS;
   `TBL-VIEW` passed a flat `'(#:name)`, so `selection-allows-field?` returned
   `#f` for EVERY label — both selection pins passed because the gate refused
   everything, and `selection-field-type` (the ADMIT half of asymmetry #3) had
   ZERO coverage. The fixture-makes-the-pin-vacuous class, on the slice that
   had just quoted it.
4. **The sort threading was unexercised.** All `'path` pins entered at the
   LEAVES, so replacing `sort` with the literal `'block` at any of ~15
   recursive call sites still passed 260 tests. Now pinned at the top and at
   depth, as a NEGATIVE assertion (it rules no assembled shape).
5. **`whnf`'s sort-preserving reconstruction was unpinned** — the production
   comment warned about exactly the silent re-sort; the warning was written,
   the pin was not.
6. **The sort-totality pin's NAME overstated the mechanism.** The guard fires
   at the DISPATCH POINTS, not across the walk: a non-divergent cell still
   answers under an unknown sort. Reworded, and widened from one divergent cell
   to three. The fourth (selection) is documented as unreachable by direct
   call — registries live only for the duration of `process-file`.

**Then THREE more folded in on the owner's ruling** (all unreachable today, all
detonating at b-ii-2 — taking them keeps b-ii-1 the safe typing-side slice):

7. **ASYMMETRY #4 — UNION subjects**, which the mini-audit's enumeration of
   "three" missed entirely. Probe: `u : <(Map Keyword Int) | (Map Keyword
   String)>` gives `u.a` → `1 : Int | String` at 0 errors, `u{a}` refuses.
   `select-row-of` had NO union arm. Wholesale minting would have silently
   deleted a working surface — Q_U10's own failure mode, one subject kind over.
   ⚠ The arm is the OPTIMISTIC filter-on-miss polarity (correct for a single
   get); broadcast is the all-must-offer adjoint and must NOT reuse it (§3's 2b
   ruling: never "unify" them). Commented at the arm.
8. **`select-index-of` — the file's own comment calls it "the nat twin of
   `select-row-of`" — never got the sort axis**, so the ordinal column of a
   2-D table silently carried block semantics and could never raise the guard.
   The twin-drift class P4a's self-review caught, one dispatcher over. Now
   total; the two sorts AGREE there by Q_U12 scoping (`.N` reuses
   `$postfix-index`), which is recorded at the arm so it is not mistaken for
   luck.
9. **`pretty-print.rkt` hard-coded the BLOCK spelling** and discarded the sort,
   so after b-ii-2 every `x.a` would render as `x{a}` in error messages and
   `def` echoes — silent wrong output on the DIAGNOSTIC path. **Third
   consecutive slice whose census missed a `pretty-print.rkt` site.** Renders
   by sort now, and degrades to a visible marker rather than raising (the P4a
   site-13 ruling: a raise on the error path converts a diagnostic into a
   crash).

**Owed to b-ii-2, found here, NOT owed by this slice**:
- **The carrier has no STRICTNESS slot.** `expr-map-get`'s third field
  materializes P2.b slice 4's two-tier decision into reduction: `(expr-true)`
  → loud panic naming the key + available keys; anything else (unsolved meta,
  **dyn-row subjects**) → permissive `(expr-error)`. `select-reduce` panics
  unconditionally. So at b-ii-2 a Map miss gets the WRONG message and **a
  dyn-row miss PANICS where today it is permissive** — a real regression the
  D19 pins would catch. Reduction cannot consult types, which is why the slot
  exists; b-ii-2 must materialize the tier onto the carrier. This is a
  CARRIER-SHAPE question re-opened one slice after b-i settled it.
- `select-reduce`'s header asserts a runtime miss is an "INVARIANT VIOLATION
  (typing sourced every field 'present)". Under the Map/dyn postures typing
  sources nothing, so the sentence becomes FALSE at b-ii-2 — contract-truth
  fix owed in the migrating commit, same class as P4a's "evaluated ONCE".
- `select-project` has **TWO** production callers, not the one this slice's
  comment claimed: the `expr-select` infer arm AND `typing-errors`'
  `select-block-hint`. Harmless today (both pass `'block`), but at b-ii-2 the
  DIAGNOSTIC re-walk runs the `'path` column, and `selection-field-type` has
  SIDE EFFECTS (`register-selection!` + `global-env-add-type-only`) — formatting
  an error message would mutate the selection registry.
- `select-sort?` is dead code (written, exported, never wired — its natural
  home is a `#:guard` on the struct). Stale comments at `syntax.rkt` and in the
  test file still say `[(expr-path _) e]`.

Status: ✅ b-ii-1 COMPLETE.

<a id="p4b-ii-2"></a>

##### §5.P4b-ii-2 — The `$dot-access` fold migration (mini-audit folded 2026-08-01)

**Mini-audit** `wf_db6ff64a-b94` (5 HEAD-pinned facets + completeness critic
@ `7ba7bdad`, 6 agents / **1.36M tokens**). Load-bearing findings R-lens-verified
on the main thread. **It refuted the design's named danger and found the real
one**, and it refuted a claim b-ii-1 shipped.

**⭐ Q_U13 RULED — the mint uses the NEST encoding** [owner, 2026-08-01].
`x.a.b` mints `($select ($select x a) b)` — ONE CARRIER PER LEVEL — not the
GATHER shape `($select x a b)`. Rationale: **nesting is what the fold already
does** (probe-verified at HEAD: `x.a.b` → `(map-get (map-get x :a) :b)`), so
this is the minimal diff; and it **preserves per-level tier granularity BY
CONSTRUCTION**, which dissolves the objection that looked like it would
re-open the carrier shape (below). Accepted cost, eyes open: the dot spelling
and the `#p(a.b)` literal then encode the same path text with different
nesting arity — one struct either way, so this is not the two-representation
complection Q_U6 rejected, but it IS a divergence and is recorded as one.
The GATHER alternative was rejected-with-reason: it matches `#p(…)` exactly
and reads most literally as Q_U5's "three spellings, one representation", but
it forces the tier to become a list parallel to the steps and re-opens
per-step granularity as new work.

**⭐ THE TIER PROBLEM DISSOLVES UNDER NEST — and the two questions were the
SAME question, which no facet connected.** The strictness facet established
that the tier is decided PER DESCENT LEVEL (probe: in one chain shape, a
dyn-row level is permissive while a Map level panics) and concluded a scalar
tier slot is "structurally insufficient". The critic showed that holds only
for GATHER: under NEST each level is its own node with its own slot, exactly
as `expr-map-get` has today. So Q_U13 decides Q1.

**⚠ THE DESIGN'S NAMED DANGER DOES NOT REPRODUCE.** §5.P4b-ii claimed
`preparse-expand-subforms`'s partially-opaque `$select` arm would make every
`.field` lose infix / implicit-map / sibling-let processing. Refuted by five
probes: every sibling pass that arm bypasses is keyed on a HEAD a folded
access node never has (`def/defn/spec/trait/property/functor`; `$pipe`;
`let`/`racket`). `(map-get x :a)` and `($select x a)` composed identically in
all five. The `$select` arm DOES expand the subject; only the payload steps
are opaque, which is intended.

**⭐ THE REAL LOUD→SILENT SITE IS THE PIPE CALLER — and the in-tree test prose
FORGETS it.** `apply-pipe-step` appends the accumulator into any hole-free
list step. `|> m foo.bar` today yields `(map-get foo :bar m)` → LOUD
`arity-error "map-get expects 2 arguments, got 3"`, because `map-get`'s parser
arm imposes EXACT arity 2. Minted, it yields `($select foo bar m)` → a SILENT
two-branch `surf-select` (`branches=((bar) (m))`) — the piped accumulator has
become a selection branch at zero errors — because `$select`'s parser arm has
only an emptiness check and NO upper bound. **R-lens-verified both halves.**
`tests/test-path-selection.rkt:1020-1022` asserts in prose that
`rewrite-dot-access` has "THREE production callers" and names three; the
fourth, `expand-pipe-block` (macros.rkt:6294), landed at P3a AFTER that P2
test was written and is precisely the dangerous one. **Zero dot-access-in-pipe
coverage exists in the tree.** Correct the prose in the migrating commit.

**⚠ TWO PREREQUISITES NOBODY NAMED**:
1. **`select-reduce` does not receive the sort** — its signature is
   `(subj-expr branches)` and the call site passes two args, discarding the
   `sort` the whnf arm binds. Plumbing it is step ZERO for any tier decision.
2. **Neither walk has a `'path` ASSEMBLY.** Both assemble a ROW
   unconditionally under BOTH sorts; `x.a` must yield the VALUE. This is not
   a green-field question: **`cfg{server}.server.host` is PINNED GREEN**
   (`tests/test-path-selection.rkt:1280`) and becomes a `'path` selector over
   a `'block` selector, where the middle level must EXTRACT for the outer to
   find `host`.

**⚠ THE REGRESSION SET IS WIDER THAN §5.P4b-ii-1 RECORDED, AND ITS PINS ARE
THE WRONG SPELLING.** Of the four asymmetries, THREE regress permissive→panic
(dyn row · selection view · union) and the Map cell regresses in MESSAGE
QUALITY — from `map-get: key :zzz not found; available keys: …` to
`select: … (invariant violation — typing sourced it as present)`, **which is
FALSE for a Map under Q_U10's own posture**. And there is a SECOND arm nobody
framed: a definitely-non-map SUBJECT degrades to `(expr-fvar 'none)` at zero
errors today and PANICS under the carrier — reachable from a union narrowed
at runtime, with no typing counterpart, so no typing-axis enumeration
(including b-ii-1's four asymmetries) could surface it.
**⚠ CORRECTION to this document and to a claim made to the owner**: b-ii-1's
close notes said the D19 pins "would catch" the dyn-row regression. **They
would not.** All three cited pins use the BRACKET `[map-get …]` spelling,
which parses through the `map-get` PARSER KEYWORD, not the `$dot-access`
sentinel Q_U12 scopes b-ii-2 to. They stay GREEN through every regression
above, and **no test anywhere pins the DOT spelling's permissive miss.**

**⚠ SILENT-ACCEPT FLIPS, which no red-set census can see.** Migrating
LOOSENS QTT: `expr-map-get`'s `inferQ` is SUBJECT-TYPE-GATED (Map / Record /
schema-or-selection fvar, else `tu-error`) while `expr-select`'s delegates
unconditionally — and the map-get arm has NO `expr-union` case although
typing-core's `infer` arm does, so migrating also silently FIXES a live
lying-"Multiplicity violation" on union subjects. Both are accept-direction
flips: they produce no failing test, so they must be PINNED BEFORE the fold
or they land unrecorded.

**C5 is wider than recorded**: `select-block-hint` is not a targeted re-walk —
it SEARCHES every subfield of ANY failing expr (`ormap search (expr-subfields
x)`), from `infer/err`, on every inference failure. After b-ii-2 the `'path`
column opens FOUR side-effect classes inside an error formatter:
`register-selection!` + `global-env-add-type-only`, `fresh-meta` ×2, `check`
(which solves metas), and `with-speculative-rollback` (a network fork) — all
under an all-exceptions swallow that discards the raise but not the effects.

**`_.field` deletion is REAL, SILENT, and the repair is not the obvious one.**
Three working shapes, ZERO tests. "Add `$select` to `sectionable-op-keywords`"
is **INERT**: `$select`'s clause precedes the section clause in the SAME
`parse-list` cond, so it never reaches it. (b-ii-3's, but b-ii-2 must not
delete it in the meantime.)

**Q_U12's taxonomy is looser than its phrasing** (adjudicated): ordinals are
ALREADY in the step vocabulary (`'ord-step`/`'ord-branch`) and ride the
carrier from block spellings, so "`[k]` is a different sort" is not the real
reason. The structural reason is that `[k]` admits a COMPUTED key — an expr —
while the payload is declared STATIC data with no exprs inside
(`syntax.rkt:765`) and `select-step-kind` is a closed union. Stating it
structurally also says exactly when the follow-up becomes possible.

**⭐ Q_U14 RULED — b-ii-2 SPLITS: 2a (prerequisites + before-the-fold pins) →
2b+2c TOGETHER (the mint + its diagnostics)** [owner, 2026-08-01]. 2c is NOT
separable from 2b: without it a `.zz` miss gets a block-worded message whose
remedy tells the user to spell it `.zz` — and `select-block-hint` runs BEFORE
`closed-row-miss-hint`, so the bad message WINS. Not a lost hint, actively
misleading advice; "we'll fix the message next slice" is how a misleading
diagnostic becomes permanent.

###### §5.P4b-ii-2a — Prerequisites + the before-the-fold tripwires  ✅

**The two prerequisites the audit found that NOBODY had named:**
1. **`select-reduce` now RECEIVES the sort.** Its signature was
   `(subj-expr branches)` and the whnf call site DISCARDED the sort it had just
   bound — so every runtime outcome for a migrated `.field` would have been
   decided by a sort-blind function. Step zero for any tier work.
2. **BOTH walks now have a `'path` ASSEMBLY.** They assembled a ROW
   unconditionally under BOTH sorts, so the fold could not be flipped: `x.a`
   would have typed as `{:a T}` and reduced to `{:a v}` instead of `T`/`v`. A
   path EXTRACTS, a block PROJECTS. Under Q_U13's NEST encoding a `'path`
   carrier is exactly one branch of one step per level, so extraction is
   unambiguous; a 0-or->1-component path carrier REFUSES loudly rather than
   silently taking the first (the P2.b fabrication class). ⚠ This was not a
   green-field question — **`cfg{server}.server.host` is PINNED GREEN** and
   becomes a `'path` selector over a `'block` one.

**The `tier` FIELD on `expr-select`** (arity 2→3, `#f` = no claim), landed
INERT — every construction passes `#f` and nothing reads it; b-ii-2b mints the
meta at the fold and teaches `select-reduce` to read it. On `expr-select` and
not on the selector because the tier is a property of the APPLICATION
(subject × selector) — a bare `#p(…)` has no subject and so no tier — and
because it then rides `select-map-exprs`, the ONE reconstruction point for six
walkers, instead of six independent identity arms. A SCALAR suffices only
because of Q_U13: under NEST each level is its own node, exactly as each
`.field` is its own `expr-map-get` today.
⚠ **`select-map-exprs` MAPS the tier, it does not merely carry it.** A carried-
but-unmapped tier would never ZONK, `expr-true?` would never hold, and every
Map miss would go silently PERMISSIVE — a reverse regression with no signal,
and precisely the hidden cost the audit identified in the rejected
put-it-on-the-selector option. Pinned.

**THE BEFORE-THE-FOLD TRIPWIRES** — pins for behaviour b-ii-2b WILL change.
They are tripwires, not invariants: their job is to make each change VISIBLE
(a RED test at 2b, updated deliberately with the delta recorded) instead of
silent. They exist because the audit found a class **no red-set census can
see** — ACCEPT-DIRECTION flips produce no failing test.
- **the union-subject LYING DIAGNOSTIC**, live and probe-confirmed today:
  `def y := u.a` on a union reports **"Multiplicity violation"** because
  `qtt.rkt`'s `expr-map-get` arm is subject-type-gated with no `expr-union`
  case while typing-core's `infer` has one. The fold SILENTLY FIXES this.
- **the DOT spelling's permissive dyn-row miss** — `d1.zzz` → `<error>` at
  ZERO errors. **Nothing in the tree pinned this**: all three D19 pins use the
  BRACKET spelling, which never reaches the `$dot-access` sentinel.
- **`_.field` sections**, three shapes, zero prior tests.
⚠ The `_.field` tripwire FAILED ON ITS FIRST RUN for the `:no-prelude`
false-green reason this file was hardened against (`map` does not exist there,
so an Unbound-variable cascade masks the deletion the pin exists to catch).
Moved to the prelude-backed fixture, reason recorded in the pin.

⚠ **Two b-ii-1 pins went RED on the assembly change — correctly.** They
asserted `select-project` returns a ROW under `'path`, which is exactly what
2a changes. Updated to assert EXTRACTION, annotated as having caught their own
slice's change.

Test delta **269 → 276**. Suite green.

Status: ✅ 2a COMPLETE · ⬜ 2b+2c (the mint + its diagnostics).

###### §5.P4b-ii-2b/2c — THE FLIP + its diagnostics  ✅ `54d940fe`

**Q_U15 RULED — the fold mints a DISTINCT sentinel `$select-path`** [owner],
not a reused `$select`. Forced: `surf-select` had NO sort field and the
elaborator HARD-CODED `'block`, so a reused head left the elaborator unable to
tell a dot access from a brace block. The fold mints in preparse and the origin
is gone by the time a surf-select exists, so the sort had to become a CARRIED
fact and a distinct head is the channel.

**⭐ THE ARITY GATE, and why the distinct sentinel pays for itself.**
`map-get`'s parser arm imposes EXACT arity 2; `$select`'s has only an emptiness
check and NO upper bound, so every surplus arg becomes a BRANCH.
`apply-pipe-step` appends the accumulator into any hole-free step, so a reused
`$select` would have turned `|> m foo.bar` from a LOUD arity-error into a
SILENT two-branch select. The same append lives in the `>>` compose twin, so a
blacklist fix needed BOTH. Enforcing one-branch at the path arm fixes every
caller at once, structurally.

**Registration cost, MEASURED: FIVE sites, not §Q8.5's nine** — because that
surface is written for a GROUPING-minted sentinel and this one is minted by the
fold in preparse, after grouping and tree-parsing. Mirroring the sibling beat
applying the checklist. (The verify then found a SIXTH — see below.)

**2c was NOT separable** (Q_U14): probed live, `r.zzz` said "…in the select
branch `zzz` — bare field access is spelled `.zzz`", instructing the user to
write what they had just written, and `select-block-hint` runs BEFORE
`closed-row-miss-hint` so the bad message WON. The fix is SCOPED — the block
spelling keeps its teaching tail — pinned both ways.

**The RED set came in at 12 datum assertions across 4 files and NOTHING ELSE.**
No value-assertion failures, no type errors. The b-ii audit warned a
datum-shape census is blind to type-error failures; that warning was sound, and
the reason it did not bite is that b-ii-1 and 2a did the semantic work first.

#### ⚠ THE ADVERSARIAL VERIFY (4 skeptics) — a BLOCKING find and hollow pins

1. **BLOCKING, found INDEPENDENTLY BY TWO SKEPTICS** via A/B against a baseline
   tree: `.field` on a union whose runtime value is a NON-MAP component
   **PANICKED** where `[map-get u :a]` degrades to `none` at ZERO errors. The
   first cut tier-gated the keyed MISS and never looked at the SUBJECT-kind arm
   one level above. **That is the permissive→panic conversion this slice exists
   to prevent**, and the message lied twice — "the block" for a dot access, and
   "invariant violation" when typing legitimately admitted a union with a
   non-map component. Now tier-gated; both spellings agree.
2. **THE TIER PINS WERE HOLLOW**, proved by MUTATION: disabling reduction's
   assertive arm, and separately disabling typing's `solve-strict-assert!`,
   EACH left 283/283 green. 2a's tripwire pinned the PERMISSIVE half; the LOUD
   half — whose failure STORES a wrong answer — had nothing. Three pins added
   (the P2.b A1/A1b/A2 analogues) and BOTH mutations re-run to confirm they now
   fail. One is also the only test executing `assertive-miss-message`, whose
   extraction had fixed a live crash with zero coverage.
3. **A SILENT ACCEPT-FLIP nobody predicted**: the field rides as a bare SYMBOL
   now, so `segment-select-items` splits `^` out of it into a re-key
   continuation and the `'path` assembly DROPPED it — five spellings returned
   the plain field at ZERO errors where HEAD refused, while `pp-expr` rendered
   the `^` faithfully. Honest display over dishonest semantics. Now a guided
   refusal; blocks keep `^` in full.
4. **THE FOURTH CONSECUTIVE MISSED `pretty-print.rkt` SITE**: `pp-datum` had no
   arm, so `expand r.a` emitted the raw sentinel where HEAD emitted readable
   `(map-get r :a)` — a silent regression on the introspection path for the
   most common access surface in the language. b-ii-1's census fixed `pp-expr`
   and stopped 1000 lines short of its DATUM-layer twin, on a datum-layer
   migration.
5. **THREE BINARY SORT DISPATCHES**, violating the rule written one slice
   earlier: `(if (eq? sort 'path) …)` in elaborator/typing-core/typing-errors,
   when `select-sort-unhandled` exists precisely to forbid it. Concrete future
   failure: a `'nil-safe` node gets tier `#f`, which reduction reads as BLOCK,
   so a nil-safe miss whose contract is `none` would panic. All total now.
6. **Three MINORs**: `assertive-miss-message` claimed two consumers and had one
   (map-get now shares it — the anti-drift property is ESTABLISHED, not
   asserted); `uses-bvar0?` skipped the tier under a stale "subject is the only
   expr slot" comment; `select-reduce`'s `[tier #f]` default was a trap (`#f`
   means BLOCK, not "no claim") — defaults removed.

Suite **9732/478/0** · battery **280 → 289** · acceptance 52/52 + 89/89 + 29/29.

Status: ✅ 2b+2c COMPLETE.

<a id="p4b-ii-3"></a>

##### §5.P4b-ii-3 — DISSOLVED at the close (its scope was discharged at 2b)

`_.field` was RESCUED inside 2b by eta-expansion in the `$select-path` parser
arm. The design's assumed repair — "add `$select` to `sectionable-op-keywords`"
— is **INERT**: that clause is dispatched LATER in the same `parse-list` cond,
so the section path is unreachable for any select head. Re-verified at the
close: `[_.a r]` → `7`, `map _.a recs` → `@[1 2]`, `|> r _.a` → `7`, all at
zero errors. Nested `_.a.b` remains broken — verified IDENTICAL at HEAD
(`parse-keyword-section` detects only a top-level `_`), so it is pre-existing,
not a regression (DEFERRED 28).

Status: ✅ DISSOLVED — no residue of its own.

<a id="p4b-ii-close"></a>

##### §5.P4b-ii — CLOSE  ✅ (2026-08-01)

**b-ii is COMPLETE**: b-ii-1 (the (subject × sort) table, four asymmetries) →
b-ii-2a (the two unnamed prerequisites + the tripwires) → b-ii-2b/2c (the flip
+ its diagnostics) → b-ii-3 DISSOLVED. Q_U12's scoping held: the `$dot-access`
leg migrated; `#.field` and `[k]` keep their nodes as named follow-ups
(DEFERRED 30 — and the audit sharpened the REASON from a taxonomic one to a
structural one: `[k]` admits a COMPUTED KEY, and the payload is declared
static-no-exprs).

**Residue filed, DEFERRED 24–30.** The one that deserves the owner's eye is
**24**: `select-block-hint` searches every subfield of every failing expr, from
`infer/err`, under a swallow-everything handler — and the flip made the `'path`
column reachable from it, opening four side-effect classes (registry mutation,
`fresh-meta` ×2, meta-solving `check`, a speculative network fork) **inside an
error formatter**. Mechanism confirmed by reading; **observable harm NOT
demonstrated** in two close-time probes. Filed as a reachability RISK, stated
that way deliberately — "I could not trigger it twice" is not evidence of
safety for a walker that runs on every inference failure.

**What b-ii cost, and what it bought.** Four owner rulings (Q_U12 scoping,
Q_U13 NEST, Q_U14 the 2a/2b+2c split, Q_U15 the distinct sentinel), one
mini-audit (1.36M tokens, 6 agents) and one adversarial verify (4 skeptics).
The verify found a **BLOCKING** permissive→panic that two skeptics located
independently, and proved by MUTATION that the tier pins were hollow — two
independent mutations left the battery fully green.

**The transferable lesson**: *a tripwire on one side of a fork is not coverage
of the fork.* 2a's tripwire pinned the PERMISSIVE half of the two-tier miss;
the LOUD half — whose failure STORES a wrong answer — had nothing, and stayed
green under mutation. When a change introduces a FORK, both arms need pins, and
mutation is what proves it.

Suite **9732/478/0** · battery 240 → **289** · acceptance 52/52 + 89/89 + 29/29.

