# SW-25 batch (DEFERRED 170, 160 → SW-27, 81, 155) — evidence

Branch `deferred-sweep-146-149`. Racket 9.3. Measured 2026-10-13. Probes take `<checkout>/racket/prologos` as argument.

## DEFERRED 170 — temp-file race (`e7cda107`)

| file | shows |
|---|---|
| `path-selection-sharded-runs.txt` | `test-path-selection.rkt` sharded ×2: before, 2 of 3 runs FAILED (1 and 2 `file exists` errors); after, 5 of 5 pass |
| (SW-24 data) `../2026-10-13_SW24_DATA/tmp-race.*` | the mechanism with no test code: `'replace` 6–8 % per process, `'truncate` 0 of 18 000 |

Guard `tests/test-temp-file-hygiene.rkt`: red with 43 sites before the edit, green after; one `'replace` restored in
`test-support.rkt:226` → red naming that line.

## DEFERRED 160 → SW-27 — registry state scoped to the compilation unit (`51b6b1f9`, `922f6dd5`)

| file | shows |
|---|---|
| `probe160-spec-leak.rkt` | through test-support (checkpoint 3's probe) |
| `probe160-driver.rkt` | through `process-file` only, as the LSP calls it: cross-namespace spec leak |
| `probe160-user.rkt` | A: the LSP re-check of ONE document after its spec is deleted (B, the CLI, prints nothing useful: `driver.rkt`'s `main` discards results) |
| `mut-160.py` / `.out` | four mutations, each red; restore byte-identical, green |
| `probe-repl-escape.rkt` | DEFERRED 171: a REPL session's constructor escapes to the process root and into a later document check |
| `branch-suite-51a24f4f-before-922f6dd5.txt` | the first full suite after SW-27: 4 files read registrations after `process-file` returned |
| `branch-suite-922f6dd5.txt` | after migrating them to `#:before-unit-exit`: 10 385 / 501 all pass |

Probe outputs, verbatim. **Before** the fix (`e7cda107`):

```
probe160-spec-leak.rkt   3. victim again, ns t -> cannot infer the type of an unannotated parameter — it is used here in a way that requires
probe160-driver.rkt      3. victim again (ns t), same process -> cannot infer the type of an unannotated parameter — …
                         VERDICT: DRIVER-LEVEL LEAK: the spec from ns test reached ns t's defn
probe160-user.rkt        A2. version 2 (spec deleted, inline types) -> preparse: spec: defn f has both a spec and inline type annotations
                         VERDICT A: STALE SPEC: the deleted spec still applies on re-check
```

**After** (`51b6b1f9`): `3. victim again, ns t -> ok: "ok2 : Nat -> Int defined."`; driver `VERDICT: NO driver-level
leak`; `A2. … -> ok: f : Nat -> Nat defined.` / `VERDICT A: no stale spec`.

The checkpoint-3 pair replayed in ONE batch worker (`racket tools/batch-worker.rkt tests/test-defn-multiarg-patterns.rkt
tests/test-error-messages.rkt`): on `e7cda107` 3 of 3 runs `test-error-messages.rkt fail 44 cannot infer the type of
an unannotated parameter`; with the fix 3 of 3 `pass 25` / `pass 44`.

`probe-repl-escape.rkt` (after SW-27): `0. process root before any eval: Red registered? #f` → `1. … after session A's
eval: #t` → `3. inside a later document check (process-file): Red registered? #t`.

## DEFERRED 81 — count drops (`160ad2f6`)

End to end, one test case datum-commented out of `test-properties.rkt`:
`COUNT DROP: test-properties.rkt ran 7 tests; at its last recorded pass (e4e9e451) it ran 8. …`; restored → 8, no line.
`probe81-cost.rkt` against main's 202 MB `timings.jsonl` (1 936 records): first version (substring prefilter over all
records) 4 974 ms CPU for a full suite when some files were never recorded; bounded to the newest 30 records: 73 ms
(full suite), 4 ms (one recorded file), 70 ms (a never-recorded file).

## DEFERRED 155 — measurement runs (`51a24f4f`)

Both writers ran; `parallel-demo-results.json` and `parity-baseline.txt` byte-identical after; output in
`data/benchmarks/runs/` (ignored); `parity-test.rkt … --output <path>` wrote the named file.
