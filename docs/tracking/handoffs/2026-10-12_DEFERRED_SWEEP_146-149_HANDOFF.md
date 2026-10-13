# Handoff — DEFERRED sweep 146–149 on branch `deferred-sweep-146-149`

**For**: a fresh session started from the Hermes desktop sidebar on the
`deferred-sweep-146-149` entry under `prologos` (a git worktree nested at
`.claude/worktrees/deferred-sweep-146-149`, the harness convention; base `7a0116ec` =
main HEAD at creation, 2026-10-12). It shares main's object store: **everything you commit on
the branch is visible from main immediately; nothing lives only in the directory.** Compiled under Racket 9.3 (`raco make -j 4` of `driver`/`champ`/`propagator`/
`decision-cell`, 19 s).

## Re-grounding (read first)

1. **Verify the base before trusting any line number**: `git rev-parse --short HEAD` must print
   `7a0116ec`. If main has moved, `git rebase main` (or re-create the worktree) and re-check
   every `file:line` below. (`workflow.md:84` — stale-worktree hazard.)
2. **The DEFERRED entries are NOT in this worktree** — they were filed in the main checkout's
   uncommitted `docs/tracking/DEFERRED.md`. Until the owner commits main's tracking docs, read them from the main checkout:
   `../../docs/tracking/DEFERRED.md` relative to this worktree is **main's** file only if you
   resolve through the repo root — use the absolute path
   `/Users/avanti/dev/projects/logos/prologos/docs/tracking/DEFERRED.md` § 146–149 (register
   NEXT FREE: 150). Once committed on main, `git rebase main` brings them onto this branch.
   Do not edit main's working tree from this session; progress is recorded by committing on
   this branch (DEFERRED status flips ride along in the branch's own `DEFERRED.md`).
3. **Tests in a worktree**: require production modules by relative path only
   (`testing.md:39`, the two-compiler-instances trap). Racket binary:
   `"/Applications/Racket v9.3/bin/racket"` (quoted; 9.3 is first on PATH in a login shell).
   Targeted run: `racket tools/run-affected-tests.rkt --tests tests/test-X.rkt` from
   `racket/prologos/`. Check `uptime` before any timing; other sessions share the machine.
4. **A/B discipline**: use the `PERF-COUNTERS` line / `(current-memory-use 'cumulative)` deltas
   for allocation claims, not wall; for wall, interleave or pin the baseline in the main tree
   (`testing.md:52`). The main checkout is the untouched baseline for every item below.

## The four items (summary; the entries carry the detail)

| # | what | site(s) | success criterion | est. |
|---|---|---|---|---|
| 146 | `champ-lookup` allocates 64 B per read | `champ.rkt:120` | 0 B for N ∈ {16, 256, 4096}; rackcheck property | 1–2 h |
| 147 | fire-protocol ceremony: `for/hasheq` output-set per fire; two `champ-fold` closures per slow-path write | `propagator.rkt:2895`, `:2041`, `:2053` | light fire < 1 KB (today 1 386 B read-only, 2 819 B read+write) | 2–4 h |
| 148 | `tagged-cell-value` never dedups entries (latent quadratic) | `decision-cell.rkt:453`, `:465` | idempotent re-write leaves `(length entries)` unchanged; property test | 1 h |
| 149 | WATCHING: `test-transducer-01.rkt` 1.35× slower under 9.3 vs 9.0 | — | a profile under both versions before any cause is claimed; 9.0 lives at `/Applications/Racket v9.0` | 1–2 h |

Order suggestion: 148 (smallest, closes a latent bug) → 146 → 147 → 149 (needs 9.0 kept
installed; coordinate with the owner, who was considering uninstalling the brew cask).

## Measurement harness that already exists

The census probe that found 146/147 is preserved at
`~/.hermes/profiles/logos-language-designer/skills/software-development/racket-performance-probing/scripts/census.rkt`
(runs against the main checkout by default — point its requires at this worktree to measure
the change). The 148 symptom reproduces with `arena-tagged.rkt` in the same directory at 100
rounds (heap baseline).

## Boundaries

- These are **sequential** wins, independent of PAR 4 (the parallel-executor design track in
  main's `docs/tracking/tracks/PAR/PAR_4/`). Do not touch the BSP loop structure or
  `specialized-cell-meta`; PAR 4 owns those seams.
- One commit per item, explicit paths, no stash (`workflow.md`). Pre-commit hooks:
  `tools/install-git-hooks.sh` once in this worktree if they are not active.
- When done: full suite (`racket tools/run-affected-tests.rkt --all`), then a short PR/merge
  note listing the four measured before/after numbers.

## Addendum 2026-10-13 — queued task: F3(a), owner decision O-7

Queue after the item in hand (147 at `674ae09b`). The owner decided (PAR 4 D.1 §14 **O-7**,
`/Users/avanti/dev/projects/logos/prologos/docs/tracking/tracks/PAR/PAR_4/2026-10-12_PAR_4_D1_DESIGN.md`)
that **F3(a) lands now, as its own commit, before PAR 4's D.2** — in this session, which found
it and holds the law-check probes.

**What**: `try-unify-pure`'s binder arms compute the unified codomain/body and return the FIRST
argument's original, using the unified result only as a success flag — Pi at
`racket/prologos/type-lattice.rkt:459` and `:471`, Sigma `:481`, lam `:502` (the comment at
`:468-470` assumes the sides are equal after unification; in pure mode metas are not assigned).
Definition and evidence: your note's §2 item 1 and §5
(`/Users/avanti/dev/projects/logos/prologos/docs/tracking/tracks/PAR/PAR_4/2026-10-13_PAR_4_P0_DOMAIN_MERGE_LAWS_NOTE.md`)
and your M1 record (`docs/tracking/2026-10-13_TAGGED_CELL_DOMAIN_MERGES_M1.md` on this branch).

**Fix shape**: return the unified result closed back over the fresh fvar. No inverse of
`open-expr` exists (`substitution.rkt:1077-1078`: `(subst 0 arg body)`; grep finds only `shift`),
so write `close-expr` (fvar x → bvar at binder depth) BESIDE `open-expr`, walking the same node
set as `subst` — a new expression walker is the exhaustive-walker hazard in `.claude/rules/pipeline.md`;
add a round-trip property `close(open(b, x), x) = b` over the expression generators the tests use.

**Out of scope**: F3(b), the meta fallback (`type-lattice.rkt:215-218`) — a PAR 4 P1 design item.

**Protocol** (TDD, one commit for the fix, measurements in the merge note):
1. Red first: pin the `aci-laws.rkt` D1c/D1d cases as rackunit tests in
   `tests/test-type-lattice.rkt` — `Pi(Nat,?m) ⊔ Pi(Nat,Unit)` must equal the swapped merge and be
   ⊒ both inputs (likewise Sigma, lam).
2. Fix; the round-trip property green.
3. Before/after: `aci-laws.rkt` at N = 3000 — **checks the note's prediction** (Pi-arm A
   violations removed, C violations from the fallback unchanged); full suite under BSP; the
   comparative corpus with `PERF-COUNTERS` (or `benchmarks/par4/p0-profile.rkt stats` from branch
   `par4-p0`). Any test whose expectation changes is information for P1 — triage and record it,
   do not revert to make it pass.
4. Record in your merge note; propose a PAR 4 LOG line there (the PAR 4 session applies it).
