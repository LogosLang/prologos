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

Cache bytes: 17.0 MB (text) → 4.5 MB (fasl; the 9.5 MB in the stream's probe was fasl of TEXT-READ bodies,
which lose the in-memory sharing).

**Suite wall** (`suite-ab151b.sh`, `--all --force-rerun --no-record`, ABAB): v11 15.8 s / 16.9 s (load 7.5 / 10.5),
v12 13.4 s / 13.5 s (load 11.8 / 11.3). One pair of runs each; the v12 legs had the higher load.

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
