# SW-24 (DEFERRED 169): the dependency graph is derived, never stored — evidence

Branch `deferred-sweep-146-149`, commit `8fbaefb8` (`tools/dep-graph.rkt`, `tools/update-deps.rkt`,
`tests/test-dep-graph.rkt`). Racket 9.3. Measured 2026-10-13.

| file | what it shows |
|---|---|
| `before-check.txt` | `update-deps.rkt --check` on main's code before the change: exit 1, 379 mismatches |
| `sw24-probe.rkt` / `.out` | warm derivation 37–43 ms CPU, full scan 520–536 ms; derived layers vs the old `--write` regeneration: 0 differing keys in all four; affected-test selection, stored vs derived, for every source and library module (22 483 of 38 004 source selections missed; 3 modules selected 0 of ~451) |
| `dryrun-before-stored-graph.txt`, `dryrun-after-derived-graph.txt` | the runner end to end, a one-line edit to `merge-fn-registry.rkt`, `--dry-run`: "No tests affected" → "Affected tests (448 of 502, 3 skipped)" |
| `mut-sw24.sh` / `.out` | five mutations of `dep-graph.rkt` (cache keyed by path only; foreign cache trusted; hidden files as modules; `#:graph` ignored; cache never written): each turns `test-dep-graph.rkt` red; restore byte-identical and green |
| `tmp-race.rkt` / `.out` | DEFERRED 170 addendum: `make-temporary-file` + `#:exists 'replace` across 3 concurrent processes fails 6–8 % with `file exists`; `'truncate` 0 of 18 000 |

Re-run the probe: `racket sw24-probe.rkt <new racket/prologos> <racket/prologos with the old --write applied> <copy of the old dep-graph.rkt>`
(the old module is `git show a15b1a9e:racket/prologos/tools/dep-graph.rkt`).
