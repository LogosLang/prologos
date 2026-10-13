# DEFERRED 151 (b): a fasl `.pnet` body, measured end to end (owner decision SW-22)

Branch `deferred-151b-pnet-fasl` @ `eab8dcf7`, off main `2792123c`. Baseline (v11, text body):
`deferred-sweep-146-149` @ `6e0cc7a8` (main + runner commits; `pnet-serialize.rkt` identical to main).
Racket 9.3, both trees built with `PLT_CS_COMPILE_LIMIT=1000000` (fingerprint `reduction_rkt.zo` 302215).
Measured 2026-10-13 by the DEFERRED-sweep session.

## Question

DEFERRED 151 (a) left warm `.pnet` loads SLOWER than no cache at all: the loader's text `read` of 16.9 MB of
bodies costs ~1.3 s. The per-process stream measured the same bodies as fasl reading in 53–56 ms and inferred a
warm load of ≈ 310 ms, below no-cache (552–571 ms) — a CONJECTURE until measured end to end. Fix (b) is either
"change the body format" or "retire the cache"; this measurement chooses between them.

## Results

**Correctness** (`pnet-diff151b.rkt`, caches written cold the same way in both trees):
- bodies **40 / 40 equal** modulo root path and hash canonicalization; the header keys differ only in the source
  file's mtime (`…core.prologos:1791875292` vs `…:1791903706`: different checkout times), as `source-hash-for-module`
  defines the key;
- what that equality cannot see, counted per kind: symbols (658 177 interned), hashes (2 248 immutable `hasheq`),
  flonums — identical; **strings 42 267 and vectors 370 777 come back immutable** (text `read` made them mutable).
  No production module calls `string-set!`; every `vector-set!` / `vector-copy!` site mutates a local `make-vector`
  (champ/rrb: fresh transient nodes — CHAMP/RRB values are rebuilt on load, `pnet-serialize.rkt:57-63`);
- full suite on v12: **10 350 tests / 497 files, all pass** (after `test-pnet-header.rkt` learned the v12 layout;
  before that it failed at load: `read: unknown escape sequence` — it read the cache with text `read`).

**Load phase** (`wcn151b.sh` under `hold-suite-lock.rkt`, harness `run152.rkt`: instantiate driver + test-support;
4 rounds ABBA; ambient load 12–16 from other sessions, so CPU is the metric):

| leg, CPU ms median [range] (n) | v11 text | v12 fasl |
|---|---|---|
| warm — cache present (the common case) | 1 450 [1 438–1 916] (8) | **285 [272–320] (8)** — 5.1× |
| no cache — control, same code in both trees | 530 [528–605] (4) | 546 [533–554] (4) |
| cold — elaborate + write | 1 028 [1 008–1 277] (4) | 732 [726–749] (4) |
| allocated, warm | 809 MB, 2 major GCs | 405 MB, 1 major GC |

Cache bytes: 17.0 MB (text) → 4.5 MB (fasl). The stream's probe saw 9.5 MB because it encoded TEXT-READ bodies;
measured (`probe-fasl-size.rkt`, `probe-fasl-strings.rkt`, 40 modules): fasl writes each distinct **string object**
once (`collects/racket/fasl.rkt:146-165` shares symbol/keyword/string/bytes/path leaves by `eq?`; pairs and vectors
are not shared). In memory, the bodies' 42 267 string occurrences are 1 703 objects (above all each module's
absolute source path, repeated in every source location); text `read` makes 42 241. String payload written:
5 279 925 bytes for text-read bodies vs 125 120 for in-memory ones — a 5 154 805-byte difference, 99.9 % of the
5 158 491-byte gap between the two fasl sizes. The fasl reader hands back the shared objects, so a v12 load holds
1 703 strings where v11 held 42 241; they are immutable, which is what makes the sharing safe.

**Suite wall** (`suite-ab151b.sh`, `--all --force-rerun --no-record`, ABAB): v11 15.8 s / 16.9 s (load 7.5 / 10.5),
v12 13.4 s / 13.5 s (load 11.8 / 11.3). One pair of runs each; the v12 legs had the higher load.

**Correction (2026-10-13, same day).** The first version of this record, DEFERRED 151 and the report to the owner
said fasl's format "follows the Racket version". That was the pre-6.90 documentation. Since 6.90.0.21 the encoding
is version-independent: "the result of `s-exp->fasl` will be valid as input to any future version of
`fasl->s-exp`" (Racket reference §13.10, Fast-Load Serialization). A Racket upgrade still regenerates every cache —
it rebuilds `driver_rkt.zo`, which `infrastructure-stale?` treats as "every cache stale" — but not because of fasl.

## Reading

The conjecture holds: warm v12 (285 ms) is below no-cache (546 ms), so the cache now pays — 1.9× over not
having one, 5.1× over today's warm load. "Retire the cache" would give up that 1.9×. **Theorem / measurement /
conjecture**: all numbers above are measurements on this machine; that the suite-wall saving comes from each batch
worker's startup load is a conjecture (18 workers × ~1.2 s CPU is the right order), not attributed.

## Re-run

```
S=<this dir>; A=<v11 racket/prologos>; B=<v12 racket/prologos>
racket $S/hold-suite-lock.rkt $A/tools/suite-lock.rkt bash $S/wcn151b.sh $A $B out.jsonl 4
racket $S/pnet-diff151b.rkt $A/data/cache/pnet $A $B/data/cache/pnet $B
bash $S/suite-ab151b.sh $A $B 2
```
`wcn151b.sh` needs `run152.rkt` (racket-performance-probing skill `scripts/`). `wcn151b-r1.jsonl` is the first,
single-round look (its first v12 "warm" leg had no cache yet, so it was a cold one).

## The reader: `tools/pnet-dump.rkt` (owner request SW-23)

A fasl body is binary, so the branch adds the human-readable reader. It uses `pnet-serialize.rkt`'s own readers
(`read-pnet-header`, `read-pnet-body`) and slot names (`PNET-BODY-SLOTS`, which the writer now checks its body
against), so it prints what the loader reads. It also reads v11 (text-body) files.

```
racket tools/pnet-dump.rkt prologos::core            # summary: layout, header, loader verdict + reason, one row per slot
racket tools/pnet-dump.rkt --slot trait-registry FILE # one slot in full (name or number 2-30; repeatable)
racket tools/pnet-dump.rkt --text FILE > core.txt     # the whole file as text; `read` gives the data back
```

`--text` on the largest cache (`prologos::core::collections`, 264 KB) prints 1.67 MB in 0.32 s; three processes
printed it byte-identically (Racket's printer sorts orderable hash keys), so dumps `diff`. Pair-keyed tables
(subtype, specialization) print in table order — stable in those runs, not guaranteed — and two separately read
pair-keyed `hasheq`s are never `equal?` (`driver.rkt:2888`), so compare data with the exported `pnet-canonical`.
Tests: `tests/test-pnet-dump.rkt` (10, synthetic v11/v12 files, the command line in-process with its exit codes
0/1/64) and two cases in `tests/test-pnet-header.rkt` (the real writer's file: fresh verdict, labels, round trip;
STALE verdicts for a source change and a version mismatch agree with `pnet-stale?`). Mutations, all red
(`mut-dump.sh`): fasl body read as text; usage exit 1 instead of 64; canonical form = identity; verdict always
fresh; one slot name dropped from `PNET-BODY-SLOTS` (the writer refuses to write).
