# Handoff — Rel Track 1, Aspect C (typed logic vars `?x:Int`) — IMPLEMENTATION

**Date**: 2026-07-21 · **Handoff for**: a fresh session to **implement Aspect C**
(Stage-4), design already SETTLED. Per `HANDOFF_PROTOCOL.org`. **ON-DISK IS
AUTHORITATIVE.**

---

## §1 — Current Work State (PRECISE)

- **Series / Track**: Rel Series → **Track 1, Relational Language Usability**.
- **Design doc**: `docs/tracking/2026-07-19_REL_T1_RELATIONAL_USABILITY_DESIGN.md`
  — **§7 Aspect C is the resume section** (Stage-3 SETTLED). §5 (Aspect A) + §6
  (Aspect B) are DONE — read for idiom only. §2 = Progress Tracker.
- **Series Master**: `docs/tracking/2026-07-19_REL_MASTER.md`.
- **HEAD**: `613f55bc` (`docs(Rel T1 Aspect C): Stage-3 design SETTLED`) atop
  `68291d62` (Aspect B B2 = Aspect B COMPLETE). **Suite GREEN 8944 / 467 / 0**
  (the design commits change no code).
- **Working tree**: pre-existing **OWNER WIP only** (modified standups/examples,
  deleted `MASTER_ROADMAP.md`/`LANGUAGE_VISION.md`, untracked LATTICE_/LAVAMOAT_/pldi
  + `examples/today.prologos`) — **LEAVE ALONE; stage ONLY your files; NO
  Co-Authored-By** (per `CLAUDE.local.md`).
- **Aspect A (NAF/guard)** ✅ COMPLETE + landed. **Aspect B (typed solution rows)**
  ✅ COMPLETE (B0 kernel `949d3be7` + B1 schema-projection `be20e7e0` + B2 codata
  `68291d62`). **Aspect C** ⬜ Stage-3 SETTLED, implementation is the resume.

  | Phase | Status | What |
  |---|---|---|
  | **C (Stage-3)** | ✅ | design SETTLED (§7); panel `wf_09b5988d-e72` + R-lens + owner co-design |
  | **C.a** | ⬜ **NEXT** | representation substrate: the `type-pred` value + smart-ctor `param-info` field |
  | **C.b** | ⬜ | reader/parser: fused `?x:Int`/`x:Int` (both readers, both languages, after the SPIKE) — first green |
  | **C.c** | ⬜ | **BLOCKING** C.1 clause-check (driver-level 3rd sibling) |
  | **C.d** | ⬜ | C.2 activation (upper-bound feed); **C.c with-or-before C.d** |
  | **C.T** | ⬜ | dedicated tests (interleaved) |
  | Polish · Aspect D · **X.close** | ⬜ | after C — the track ✅ gates on the Stage-5 PIR |

- **NEXT IMMEDIATE TASK**: **C.a** — the representation substrate. Define the
  `type-pred` value (a type-EXPR + a predicate-SET **list** slot, **NO stub lowering
  fn**) and add the type field to `param-info` (relations.rkt:500, ~8 production /
  ~15 total sites) via a **smart-constructor default** so existing sites stay
  untouched. Pure substrate, no behavior; testable by constructing/reading a typed
  `param-info`. Then C.b (the reader/parser — the first end-user-visible green).

---

## §2 — Documents to Hot-Load (ORDERED)

**Always-load** (skim if fresh): `CLAUDE.md` + `CLAUDE.local.md`; `MEMORY.md` +
[[rel-t1-relational-usability]] + [[ciu-t6-records]]; `DESIGN_METHODOLOGY.org`;
`DESIGN_PRINCIPLES.org`; `CRITIQUE_METHODOLOGY.org`; `HANDOFF_PROTOCOL.org`;
`MASTER_ROADMAP.org`; **series master** `docs/tracking/2026-07-19_REL_MASTER.md`.
Rules auto-load (internalize `pipeline.md` — **new struct field + New AST/parameter
checklists are load-bearing for C**; `prologos-syntax.md` — **WS-vs-sexp reader
divergence is load-bearing for C.b**; `on-network.md`, `structural-thinking.md`,
`testing.md`, `workflow.md`).

**Session-specific (READ IN FULL, in order)**:
1. **This handoff** (§1–§6).
2. Design doc `2026-07-19_REL_T1_RELATIONAL_USABILITY_DESIGN.md` — **§7 Aspect C
   (the whole thing)** + §2 Progress Tracker + §11 Q-C. §6 (Aspect B) for the
   `relation-column-typer` / `solve-row-type` machinery C.2 feeds.
3. `docs/tracking/standups/2026-07-19_dailies.md` — STATE head (current) + the LOG:
   the two Aspect-C entries (design-opening + Stage-3-settled) carry the full arc
   incl. the grounding + panel findings condensed. Newest at bottom.
4. **Vision context** (the WHY behind `?x:Int` = `Int(x)`): research doc
   `docs/research/2026-03-16_NEXT_GEN_LOGIC_PROGRAMMING.tex` §"CLP(X) Family" +
   §"Proposed Prologos Syntax" (the `?x:FD 1..10` prior art, the runtime altitude);
   `docs/tracking/2026-06-30_TRAITS_AS_REFINEMENT_TYPING_NOTE.md` (the
   "traits ARE refinement typing" through-line — the refinement altitude).
5. **The grounding + panel raw outputs** (if deeper than the dailies condensation
   is needed): grounding `wf_8083a27e-2a9`, panel `wf_09b5988d-e72` — the full
   distilled results are in the workflow task outputs (transcript dirs under the
   session's subagents/workflows/). The dailies + §7 capture the load-bearing facts;
   go to the raw outputs only for a specific file:line the design doesn't cite.
6. `git log --oneline -12` — the Aspect A/B/C commit chain.

---

## §3 — Key Design Decisions (RATIONALE) — do NOT re-open without cause

1. **The vision (owner, Curry-Howard)**: `?x:Int` = the predicate/clause `Int(x)`
   ("x satisfies Int") = the type `x:Int` (predicates ARE types). ONE surface,
   three altitudes: static type (THIS slice), runtime domain-constraint (`Int(x)`
   prunes — the existing narrowing reading + CLP, → **UCS**), refinement (`Int@pos`,
   → deferred). *Why:* the owner's Prolog `integer(X)` intuition + Curry-Howard;
   unifies the static-type and (existing, dead-in-WS) narrowing readings.
2. **First slice = (A)-in-(B) with a GENERAL type-EXPR carrier** (owner-confirmed):
   parse into a SINGLE `type-pred` value that is the *general* object the runtime
   `Int(x)` lowers FROM — NOT literal reuse of the runtime node. *Why:* the runtime
   consumer `value-matches-type?` (global-constraints.rkt:475) is **symbol-bound**;
   a stored *symbol* can never recover `Int@pos`, a **type-EXPR** projects DOWN to
   the symbol. So the general carrier is *more* Curry-Howard-faithful AND is what
   keeps UCS un-cornered. **HARD CONSTRAINT: don't corner UCS.**
3. **The composed spine** (panel `wf_09b5988d-e72`): reader → generic
   `(name, type-EXPR)` pair (both readers/langs, additive; **STOPS there** — must
   NOT emit a type-pred datum, Decomplection) → **elaboration** builds the ONE
   `type-pred` value (type-EXPR + predicate-SET **list** slot, **NO stub**; Q-C1
   Option 2′) on `param-info` → **BLOCKING driver-level 3rd-sibling check** (Q-C3
   Option A; leaves `expr-logic-var` infer arm **UNTOUCHED**) + C.2 upper-bound feed
   to `relation-column-typer`.
4. **C.1 MUST BE BLOCKING** (owner-confirmed) + **C.c with-or-before C.d**: C.2's
   upper-bound feed AND the **already-shipped Aspect-B schema branch**
   (typing-core.rkt:3603-3610, no `has-clauses?` guard) are **soundness-parasitic on
   C.1** — a schema'd rule relation whose body violates the schema is typed against a
   schema it violates (unsound `solve` type). C.1 (the missing clause check) closes
   it; error routes `prologos-error` (blocking, like the two `:817` siblings), NOT a
   warn. (A.3's *permissive* was top-level *query* floundering; *registration* blocks.)
5. **Q5 correction**: schema'd rule relations are ALREADY typed (schema branch, no
   `has-clauses?` guard, upper bound) → C.1's genuinely-new typing = **un-schema'd
   rule relations' body-derived output types** (the codata path B2 deferred here).
6. **Fused syntax is ADDITIVE** (spaced `[x : T]` keeps working): only `x:Int`
   fully-fused grabs `:Int` as a keyword (recognize-keyword char-alphabetic gate,
   parse-reader.rkt:514-516); `x: T` (space after colon) already parses. Both
   readers + both languages. `parse-rel-params` (parser.rkt:5219-5232) has NO `:`
   branch → the relational companion is genuinely NEW. Chained `?x:C1:C2` → REJECT
   with a diagnostic (reserve for UCS).
7. **REJECTED**: Q-C1 literal-reuse options (desugar-to-goal `Int(x)` in the body;
   share the narrow-var side-table) — both store *symbols* → corner refinement
   (symbol-ceiling). Q-C2 ambient-flag context-gating — Decomplection +
   structurally-emergent violation. A stub `type-pred->clp-goal` no-op — the
   speculative-scaffolding red flag; the lowering is written WHEN UCS consumes it.

---

## §4 — Surprises & Non-Obvious Findings (HIGHEST re-derivation risk)

1. **`?x:Type` is ALREADY half-built — but DEAD-IN-WS.** The `?var:C1:C2` narrowing
   constraint-chain (parser.rkt:6348-6404 / elaborator.rkt:3276-3283 / narrowing.rkt
   :638-647) is the runtime altitude (`type-guard` domain constraints via a
   base-name→type side-table). VERIFIED dead in WS: `solve (num ?x:Even)` over facts
   1,2,3 → `nil` (WS splits `?x:Even` → `?x` + keyword `:Even` → 2-arg call to a
   1-arg rel); baseline `solve (num ?x)` → all 3. Works only in **sexp** (`:`
   non-special → `?x:Nat` is ONE symbol). So the WS surface currently MIS-PARSES;
   Aspect C's static reading claims it, but must reconcile the sexp-vs-WS divergence.
2. **Aspect B has a LATENT soundness hole C.1 closes.** The already-shipped schema
   branch types schema'd relations by the schema with **no clause-conformance check**
   (R-lens-confirmed typing-core.rkt:3603-3610). C.1 is that check → it retroactively
   secures Aspect B. This is *why* C.1 must be BLOCKING + ship with-or-before C.2.
3. **The symbol-ceiling** (the whole "type-EXPR not symbol" pivot): the runtime
   consumer `value-matches-type?` (global-constraints.rkt:475) pattern-matches a
   type-NAME **symbol** → down-projection only; a stored symbol can never recover
   `Int@pos`. Carry a type-EXPR on a neutral param object; a future lowering does the
   down-projection.
4. **`param-info` is ~15 sites, not 56** (the panel over-counted): 8 production (all
   in relations.rkt), ~15 incl tests. A smart-constructor default keeps them all
   untouched — the C.a substrate is cheap. **BUT `pipeline.md` New-Struct-Field is
   still MANDATORY**: grep `struct-copy` AND direct constructors project-wide (the
   PPN 4C S2.b-iv arity-mismatch class).
5. **The tokenizer is priority-first-match, not maximal-munch** (parse-reader.rkt
   :1220-1245). The fused-annotation blocker is the space AFTER the colon; the
   minimal WS fix is ONE additive priority-96 glued-colon recognizer (char[pos-1]
   ident-continue + char[pos+1] alphabetic → bare colon). But see §5 — the SPIKE may
   route convergence to the parser arm instead (tokenizer untouched).
6. **Typed rows touch BOTH checkers** (typing-core + qtt) — but Q-C3 Option A
   (driver-level check) leaves the `expr-logic-var` infer arm UNTOUCHED, so it
   uniquely AVOIDS the pipeline.md typing-core:2897 / qtt:2109 double-patch. Any
   arm-touching alternative would need both.

---

## §5 — Open Questions & Deferred Work

**The ONE implementation-time SPIKE (do FIRST in C.b, before flipping the reader)**:
does the `:Int` keyword token produced by the UNCHANGED WS tokenizer reach
`parse-rel-params` (parser.rkt:5219) and the tree-parser functional binder arm
(tree-parser.rkt:1133) **intact** after `flatten-ws-kv-pairs` / defr param-list
construction? **YES** → converge at the **parser arm** (tokenizer untouched —
additive-by-construction, no test-suite reinterpretation sweep needed). **Reshaped/
stripped** → converge at the **tokenizer** (the priority-96 recognizer) + run the
full test-suite reinterpretation sweep (reinterpretation cost measured ~zero over
lib/+examples, but the test suite was NOT swept). Highest-value single verification.

**One-object-across-both-languages** (owner co-design, minor): the `type-pred`
value-type is ONE definition; storage is the relational `param-info` AND the
functional binder site (a De-Bruijn `binder-info`, surface-syntax.rkt:432) — so
"one object" = one-in-spirit (shared value-type), potentially two storage locations.
Confirm with the owner if it becomes load-bearing.

**Latent tokenizer gap to decide in C.b**: `x:m` is a parse gap TODAY (the `:m`
multiplicity is not in the member-list at tree-parser.rkt:1150) — make an explicit
diagnostic decision for the `:w`/`:m` multiplicity-vs-annotation collision.

**Deferred to UCS/CLP** (the non-foreclosure payoff): the runtime domain-constraint
reading (lower the SAME `type-pred` object down to the `Int(x)`/`type-guard` goal —
the rejected-as-static shape, correctly relocated as the future RUNTIME LOWERING
TARGET) + refinement types (`Int@pos`; `@` isn't a token yet — WS bare symbol, sexp
`@` HARD-ERRORS on non-`[`). The non-monotone upper-bound cap → the on-network
reading belongs at a **RETRACTION stratum S(-1)**, not S0 (named now so UCS isn't
cornered).

**Deferred to BSP-LE Track 3**: A.2b + A.4 DFS-routing scaffolding + the prototyped
on-network guard mechanism (seed `2026-07-20_BSP_LE_TRACK3_ONNET_SEED.md`).
**After C**: Polish (answer-set dedup · drop `_anon` keys · declaration-order keys),
Aspect D (efficient fact-rep, Stage 0/1 research), **X.close (Stage-5 PIR)** — the
track does NOT flip ✅ until the PIR lands (objective-PIR gate).

---

## §6 — Process Notes

- **Build order is soundness-atomic** (§7.6): C.a substrate → C.b reader/parser
  (first green: `?x:Int`/`x:Int` parses in both readers/langs, **parse-and-store,
  NO typing**) → C.c BLOCKING C.1 → C.d C.2. **C.c precedes/lands-with C.d** (or fold
  them) — never C.2 with a warn-only C.1 (validated-≠-deployed / belt-and-suspenders).
- **Per-sub-phase mini-audit**: open each sub-phase (C.a/C.b/C.c/C.d) with the
  `grounding-audit` workflow over its surfaces (`DESIGN_METHODOLOGY.org` § Per-Phase
  Protocol) — coordinates DRIFT (re-grep before trusting any file:line here).
- **C.b is a new-AST-node + reader-change + pipeline event**: apply `pipeline.md`
  New-AST-node (if the `type-pred` is an AST node) / New-Struct-Field (`param-info`)
  / New-Parameter checklists in FULL; **three-level WS validation** (sexp / WS-string
  / WS-file via `process-file`) is REQUIRED — and the **WS-vs-sexp reader census** is
  load-bearing (sexp-green ≠ WS-correct, the exact hazard that made the narrowing
  constraint dead-in-WS).
- **Per-change gate**: `check-parens` → `raco make driver.rkt` → **PROBE-FIRST**
  via `tools/run-file.rkt` (from `racket/prologos/`, **multi-line fact rows** — a
  one-line `|| 5 3` parses as ONE wrong-arity row) → targeted `--tests` → full
  `--all --force-rerun` → commit (`git commit -F -`, stage ONLY your files, NO
  Co-Authored-By). Racket: `"/Applications/Racket v9.0/bin/racket"` (quoted).
- **Suite test-count is NONDETERMINISTIC** (8922↔8944 run-to-run, data-driven) — the
  gate is **0 failures across all 467 files**, not the exact count.
- **Deliberate output changes churn brace-counting test helpers**: Aspect B's typed
  solve output broke `count-answers`-style helpers (they counted the type
  annotation's `{:`). Aspect C's typed defr/clause output may do the same — 9+ test
  files carry the identical `(length (regexp-match* #rx"\\{:" s))` helper (dailies
  Watching); fix = split off the ` : <type>` suffix before counting.
- **NEVER edit files with regex/`sed`/`python re.sub`** — corrupted `relations.rkt`
  in the A.4 arc; use the `Edit` tool for surgical changes.
- **Conversational cadence**: checkpoint at each sub-phase boundary (~1h max
  autonomous); the owner sets pace + co-designs decisions in PROSE (Q_N labels, NOT
  AskUserQuestion chips — [[design-dialogue-preference]]).
- **Scaffolding naming (once, track-level)**: the imperative registration-time clause
  typing is off-network at Aspect-B parity (0 propagators, 0 cell-writes); name the
  retirement owner = on-network clause typing (PPN-successor / UCS era). Don't ship it
  as the on-network vision; don't re-import a stub lowering fn.
- **The Relay Note** (below / in the owner's paste) is the compact seed; this handoff
  is the full transfer. A tracked design that completes GETS a PIR (X.close).
