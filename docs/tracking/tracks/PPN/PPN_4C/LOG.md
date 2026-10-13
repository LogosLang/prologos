# PPN 4C — track LOG

Append-only, newest at the bottom. Entry shape and the division of labour with the dailies:
[`../../README.md`](../../README.md) § *The per-track LOG*. Track index and the three design
documents: [`../README.md`](../README.md) § *PPN 4C — three design documents, one track*.

---

### Where the history lives — PPN 4C before this LOG — no commit (2026-10-13)

**Why / decision**: The track ran 2026-04-17 → 2026-06-10, before the per-track LOG existed. Its
journal is the dailies from [`2026-04-17`](../../../standups/2026-04-17_dailies.md) through
[`2026-05-26`](../../../standups/2026-05-26_dailies.md); the last of these runs to 2026-06-10
and holds the rewind checkpoints for Phases 4A and 4B (4B from checkpoint 15 on). Decisions of
record live in the designs' ledgers — the addendum's §3 tracker and §18 (Phase 4), the tropical
addendum's tracker, the parent D.3's §2 tracker — not here.

**Position at hand-over** (2026-06-10, `82f22446`; suite then 8 380 / 0 / 121.2 s):
- Addendum ([`2026-04-21_PPN_4C_PHASE_9_DESIGN.md`](2026-04-21_PPN_4C_PHASE_9_DESIGN.md)):
  Phases 1–3 ✅ (Phase 1 closed through the tropical addendum, ATOMIC CLOSE `b8405dfb`); Phase 4A
  ✅ (2026-06-01); Phase 4B: 4B.0–4B.4 ✅, **4B.5.a ✅** (impl `2d791705`: general bodies and
  mutual functions residuate; G1 / PR #14 passes; the demand sweep amends DEF-vs-USE).
- **NEXT: 4B.5.b, narrowed** — inferred value-level cycles via an SCC pass (assumption-env =
  fresh metas; fixes inferred self-recursion, which §18.21.26 found refuted the stale §18.10.5
  claim) + the §18.11 cycle diagnostic (an unproductive residue reports "definition cycle", not
  "Unbound"). Then 4B.5.c (captures verification, redefinition edges, two-context gate audit,
  4B.5-VAG, the 4B arc close with the full G1–G4 battery), then 4C (retire the 4 sequential
  caller loops), 4D (`reset-meta-store!` → worldview-aid at form scope), 4E, 4V, capstone + PIR.
- Source of the above: §3 tracker rows 4B–V, §18.21.25–.26, and the 2026-05-26 dailies' last
  entry (*4B.5.a SHIPPED — G1 lands in .a*).

**Surprise / correction**: the addendum's §3 still shows rows 1A-iii-b, 1A-iii-c, 1B, 1C and 1V
as ⬜. All five closed inside the tropical addendum (its tracker, design lines 391 ff.; PIR,
ATOMIC CLOSE `b8405dfb`). Stale rows, not open work — to be pointed at the tropical addendum when
§3 is next edited.

**Next**: the move into this directory, then resume (entries below).

### The PPN series moves into `tracks/PPN/` — `594e6e63` `34ad559d` `71a4ab01` (2026-10-13)

**Why / decision**: Owner request: pick 4C up in its own worktree and move all PPN work into a
series directory under `tracks/` — the en-masse move [`../../README.md`](../../README.md) had left
owner-scheduled. Owner decisions (2026-10-13): every link to a moved file is rewritten, from
anywhere (docs, the owner's standups, `.rkt` comments, two benchmark banners); the single-series
PPN research documents go to the series' `research/`, symlinked back into `docs/research/` for
browsing; merge to main as soon as the resolver is clean. The filename question was left open;
**basenames are kept** as the monotone choice (a rename can follow; an un-rename after the new
names spread cannot), so 165 bare-basename citations and every commit message still find their
file.
- `594e6e63` — [`tools/check-xlinks.py`](../../../../../tools/check-xlinks.py): cross-file link
  resolution for md + org, with a self-test that plants 3 broken links among 8 candidates.
  Baseline over `docs/ .claude/ CLAUDE.md`: 3 791 relative links, 144 broken (pre-existing).
- `34ad559d` — 61 documents moved (`git mv`; renames preserved for `--follow`); 1 840 sites in
  129 files rewritten, every edit in-line (1 601 / 1 601 lines): 346 inbound links, 1 143
  outbound links (each keeps the absolute location it resolved to), 280 bare repo paths, 1 bare
  relative path, 26 repairs. Verification: 3 791 links before and after; broken 144 → 121 =
  144 − 23 repaired; the after-set equals the baseline mapped through the move (0 new, 0 missing);
  0 old repo paths left outside `racket/prologos/data/` (raw outputs, left as printed — 1 site).
- `71a4ab01` — the 5 research symlinks, in their own commit.

**Surprise / correction**:
- ⚠ **CORRECTION** (`34ad559d`'s message): it says "all 21 PPN 4C / tropical handoffs". The
  count is **20** (34 files in `PPN_4C/` = 14 documents + 20 handoffs); the reply that posed the
  move's questions said 21 too.
- 26 pre-existing defects surfaced and were repaired, all with unambiguous intent: the
  2026-05-17 dailies wrote 15 link targets as repo-root paths (`](docs/tracking/…)`), which
  resolve under `standups/`; the roadmap's Track 0 "Design" link and `bench-ppn-track0.rkt` (2
  sites) named `2026-03-26_PPN_TRACK0_DESIGN.md`, which never existed (`git log --all`); the
  kickoff handoff was a level short to `research/` (3) and two short to `.claude/rules/` (2); D.3
  had two mis-rooted code links; the addendum one repo-root research link. **Not** repaired:
  PTF_MASTER and PROPAGATOR_TAXONOMY cite `2026-03-26_LATTICE_FOUNDATIONS.md` for the
  Hyperlattice Conjecture — no such file ever existed and `LATTICE_FOUNDATIONS_PPN` never
  mentions the Conjecture, so the intent is not ours to guess.
- Adding a symlink at a path `git mv` just vacated, in the same commit, turns the rename into
  "typechange + add" and `git log --follow` loses the history. Hence the separate `71a4ab01`.
- The symlinks are for browsing only: of the 20 relative links in the 5 research documents, 1 is
  broken from the real path (`../../MEMORY.md`, pre-existing) and 19 break when resolved from
  the alias's directory — what an editor does when it keeps the alias as the buffer's directory.

**Next**: re-ground 4C in its worktree (next entry).

### PPN 4C resumed in its own worktree — no commit (2026-10-13)

**Why / decision**: Branch `ppn4c-elaboration-on-network`, nested worktree
`.claude/worktrees/ppn4c-elaboration-on-network`, created from main at `34602ded`; the chat is
bound to it. Built with `PLT_CS_COMPILE_LIMIT=1000000`; `reduction_rkt.zo` fingerprint
`7c07fd92…` equals main's. The branch name is renameable until something outside cites it.

**Baseline** (at `71a4ab01` = main `34602ded` + the three move commits, docs/comments only):

| | at 4B.5.a close (2026-06-10) | now (2026-10-13) |
|---|---|---|
| Full suite | 8 380 / 0 failures / 121.2 s | **10 350 tests / 497 files (501 units), all pass, 16.5 s** (18 workers) |
| 4C acceptance file (`examples/2026-04-17-ppn-track4c.prologos`, `tools/run-file.rkt`) | "acceptance 62/0" (2026-05-26 dailies) | **59 results, 1 error** — line 197 `eval [[int* 2] 21]` → `int* expects 2 arguments, got 1` |
| Commits on main since `82f22446` | — | 1 142 |

Drift on the 4B.5 surfaces since `82f22446` (`git diff --shortstat`, commit counts):
`driver.rkt` 42 commits, +1 005 / −327 · `elaborator.rkt` 38, +817 / −111 ·
`typing-propagators.rkt` 13, +313 / −69 · `namespace.rkt` 13, +84 / −8 · `propagator.rkt` 2,
+49 / −32 · `global-env.rkt` 1, +9 · `metavar-store.rkt` 1, +6 · `elab-network-types.rkt` and
`definition-entry.rkt` untouched. Every `file:line` in §18.21.25–.26 must be re-derived.

**Surprise / correction**: the acceptance file regressed and nothing pins it (examples are not
suite units). The arity check that fires is old (`check-arity 'int*`, since `c043b491`,
2026-02-17), so what changed is the route a WS-mode partial application of a keyword takes to
it, not the check. Candidates, unverified: the removal of the parse merge's tree leg (PPN 3
Phase 7, `2d7813ef`, 2026-08-03), keyword sections (Numerics N6e-E3, `4a3c98f7`, 2026-07-02),
the P4e-0 reader work (`bfba68d5`, 2026-08-09). A sibling checkout at the June base could not
load under Racket 9.3, so the before-state is unmeasured — a bisect with builds is the instrument.

**Next**: the 4B.5.b grounding mini-audit
(`YYYY-MM-DD_PPN_4C_4B5b_GROUNDING_AUDIT.md` here): bisect the acceptance regression first (it
may be a PPN 3 defect, or an intended surface change the file never followed); re-derive the
§18.21.25–.26 coordinates at HEAD; re-run the 4B.5.a probes (p2–p8) and the 4B.5 battery
(`test-general-body-01`, `test-forward-ref-01`, the §6 canary); then open the 4B.5.b mini-design.
