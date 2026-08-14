# Tree-sitter Grammar Repair — TSG Track 1

**Status**: 🔄 in progress · **Opened** 2026-08-14 · **Blocks**
[SURF T1](2026-08-14_0003_SURFER_REENGINEERING.md) · **Owner ruling**: fix the
grammar before the surfer.

`editors/tree-sitter-prologos/grammar.js` was last touched **2026-03-11**
(`899b2263c`). The language has moved considerably since — LET (2026-07-31),
ARROW (2026-08-05), Rel T1 (2026-07-25) — and the grammar has not.

---

## Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| P0 | Corpus gate + baseline | ✅ | `check-corpus.sh` — commit `321391bf`. Baseline in §1 |
| P1 | Multi-clause `defn` (`\| pat -> body`) | ⬜ | Largest single cluster — [§2](#gaps) |
| P2 | `let` (LET track, 2026-07-31) | ⬜ | |
| P3 | `fn` lambda with typed params | ⬜ | |
| P4 | `trait` body | ⬜ | |
| P5 | `defr` + relational syntax (Rel T1) | ⬜ | `defr` appears **0** times in grammar.js |
| P6 | Re-baseline, regenerate, reinstall, font-lock check | ⬜ | `install.sh`; then unblock SURF T1 |
| P7 | TSG T1.close — gate wiring, DEFERRED triage, PIR-lite | ⬜ | Consider adding the gate to pre-commit |

---

## 1. Baseline (2026-08-14, `321391bf`)

Measured by `editors/tree-sitter-prologos/check-corpus.sh` over
`racket/prologos/lib`, `racket/prologos/examples`, `editors/emacs/test`:

```
files 142 | clean 18 (13%) | dirty 124 | ERROR 8336 | MISSING 122 | lines 36231
```

Worst files: `lib/examples/foray.prologos` 1013 · `core/conversions.prologos`
498 · `examples/2026-03-18-track7-acceptance.prologos` 356.

⚠ **The lib-only figure quoted when SURF T1 was blocked (73% dirty) was
optimistic** — over the full corpus it is **87%**. Recorded because the smaller
number is the one that would be remembered.

### Why this went unnoticed for five months

A stale grammar does not error. Tree-sitter *recovers*: it emits `ERROR` nodes
and carries on, so every consumer downstream — font-lock, folding, the surfer —
degrades **silently**. There was no symptom loud enough to prompt a look. That
is the same fail-open shape as `core.hooksPath` and the audit template's false
anchor (dailies (xiv)), and the reason P0 was a measurement tool rather than a
fix.

---

<a id="gaps"></a>
## 2. The gaps are FIVE constructs, not general rot

Isolated by parsing minimal snippets (2026-08-14). This matters: the error
*clustering* attributed 779 failures to `defn`, but that counts the leading token
of the line **containing** the error, and for a multi-clause `defn` that is the
`defn` line. The construct itself is fine.

| construct | ERROR nodes | verdict |
|---|---|---|
| `def a := 1` / `def a 1` | 0 | ✅ works |
| `defn` one-line body | 0 | ✅ works |
| `defn` typed param (`[x:Int]`) | 0 | ✅ works |
| `spec` arrow + bracket types | 0 | ✅ works |
| `match` with arms | 0 | ✅ works |
| bare top-level expression | 0 | ✅ works |
| `ns` | 0 | ✅ works |
| **`defn` multi-clause (`\| pat -> body`)** | 1–2 | ❌ **P1** |
| **`let` (layout form)** | 3 | ❌ **P2** |
| **`fn` lambda, typed param** | 2 | ❌ **P3** |
| **`trait` body** | 1 | ❌ **P4** |
| **`defr` (Rel T1)** | 3 | ❌ **P5** |

So the core declaration forms parse. Five constructs account for the corpus
damage, and multi-clause `defn` is the dominant one because it is everywhere.

---

## 3. Method

Repair is gated on the number, not on impression: run `check-corpus.sh`, change
one rule, run it again. Each phase records before/after in its section below.
`--max N` lets the gate ratchet downward as phases land.

⚠ **`install.sh` must be re-run for a change to take effect** — the corpus gate
measures the *installed* dylib in `~/.emacs.d/tree-sitter/`, not `grammar.js`.
Editing the grammar and re-running the gate without reinstalling measures the
old parser and reports no change, which reads as "my fix did nothing".

---

## 4. Per-phase records

*(filled in as phases land)*
