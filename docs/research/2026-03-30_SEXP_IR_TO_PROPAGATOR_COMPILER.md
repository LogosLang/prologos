# From S-Expression IR to Propagator Compiler: The Self-Hosting Trajectory

**Date**: 2026-03-30
**Context**: PPN Track 2B design review — examining what sexp path retirement means for the compiler architecture and self-hosting
**Series**: [PPN Master](../tracking/2026-03-26_PPN_MASTER.md)
**Cross-references**: [LANGUAGE_VISION.org](../tracking/principles/LANGUAGE_VISION.org) § Self-Hosting, [DESIGN_PRINCIPLES.org](../tracking/principles/DESIGN_PRINCIPLES.org) § Homoiconicity as Invariant

---

## 1. Three Roles of S-Expressions in Prologos

The sexp form has served three distinct roles that are easy to conflate. Each has a different trajectory under the PPN architecture.

### Role 1: Input Syntax

Users write `(def x 42)` in sexp mode or `def x := 42` in WS mode. Both produce the same `surf-*` structs. WS `.prologos` files are the design target. The sexp input syntax is becoming the bootstrap input format — used by the Phase 0 Racket prototype's test suite but not the primary user experience.

**PPN trajectory**: WS reader (parse-reader.rkt) → tree parser (tree-parser.rkt) replaces the sexp input path for all `.prologos` processing. Track 2B deploys this. Sexp input persists as the bootstrap compiler's test interface.

### Role 2: Internal IR (Datum as Compiler Intermediate Representation)

Today's pipeline:

```
WS text → [reader] → Racket datums (sexp) → [preparse] → expanded datums → [parse-datum] → surf-* → elaboration
```

Between the reader and the elaborator, forms pass through as Racket S-expressions. `preparse-expand-all` operates on datums. `parse-datum` converts datums to `surf-*` structs. The S-expression is the compiler's lingua franca — the representation that every pipeline stage consumes and produces.

**PPN trajectory**: Being eliminated. Track 2's tree parser shorts the datum layer:

```
WS text → [parse-reader] → tree nodes → [tree-parser] → surf-* → elaboration
```

Generated defs (from data/trait/impl) still flow through datums because preparse produces them as S-expressions. But the datum IR is shrinking in scope.

With the full PPN vision (Tracks 3-4):

```
WS text → [propagator reader] → tree cells → [propagator parser] → surf-* cells → [propagator elaborator] → typed cells
```

No datums anywhere in the pipeline. Every stage is cells on the propagator network. The sexp IR disappears entirely as an implementation artifact.

### Role 3: Code-as-Data (Homoiconicity)

The `Datum` type with its 8 constructors is a SEMANTIC construct of the language. Quoting produces Datum values. User macros operate on Datum values. The self-hosting compiler operates on Datum values. DESIGN_PRINCIPLES.org: "Every syntactic form has a canonical s-expression representation."

**PPN trajectory**: PRESERVED, but reframed. The `Datum` type becomes a user-facing value (for quote, macros, agent self-inspection), NOT a compiler-internal representation. The compiler doesn't need to represent its own state as S-expressions — it uses cells. But the LANGUAGE still has S-expression-shaped data as a first-class value type.

The critical distinction: sexp-as-IR (Role 2) is an implementation artifact that PPN eliminates. Sexp-as-data (Role 3) is a language feature that persists independently of how the compiler represents its own state.

---

## 2. What Shifts With Propagator-Only Architecture

### The Compiler IS a Network

Today: the compiler is a Racket program that calls functions in sequence (`read → preparse → parse → elaborate → type-check → zonk`). Each function transforms data structures and passes them to the next.

With PPN complete: the compiler is a propagator network. Source text is written to a character cell. Parsing, normalization, elaboration, type checking — all happen as propagator firings reaching fixpoint. The compilation result is read from output cells.

This is not a metaphor. PPN Track 0 defines the lattices. Track 1 implements the reader as propagators. Track 2 implements normalization as rewrite rules. Track 3 will implement parsing as grammar productions. Track 4 will implement elaboration as attribute evaluation. Each stage becomes propagators on the SAME network, connected by bridges between lattice domains.

### Homoiconicity Reframed

**Old framing**: "Code IS S-expressions that the compiler manipulates."

**New framing**: "Code IS Datum values that grammar productions and rewrite rules transform. The transformation mechanism is propagator firing, not function application. The semantic guarantee (quote roundtrips, code-as-data inspection) is unchanged."

The `Datum` type can be produced from tree nodes just as easily as from S-expressions. Track 2's quasiquote implementation already does this: tree walk → Datum constructor chain. No S-expression intermediate needed.

### User Macros Operate on Tree Nodes, Not S-Expressions

Today: macros take datums, produce datums. `(defmacro unless [test body] (list 'if test 'unit body))`.

In PPN: macros could operate on parse tree nodes, which carry structural information (indentation, brackets, tags, source locations) that S-expression datums lose. A tree-level macro is strictly more powerful than a datum-level macro — it can pattern-match on syntactic structure, not just list shape.

Track 7 (user-defined grammar extensions) decides this. Grammar extensions that register as typed rewrite rules on the parse tree are the PPN-native macro system. They compose with the compiler's own rewrite rules, participate in type-directed disambiguation (Track 5), and are visible to tooling (LSP, error recovery).

---

## 3. The Self-Hosting Trajectory

### Phase 0: Racket Prototype (Current)

The compiler is a Racket program. S-expressions serve all three roles: input syntax, internal IR, code-as-data. The Racket host provides: the reader (being replaced by PPN), the runtime (GC, continuations, ports), the module system.

### Phase 1: Propagator Compiler on Racket Host (PPN Tracks 1-4)

The compiler IS a propagator network, but the network RUNS on Racket. The Racket host provides the propagator scheduler (BSP), cell storage (CHAMP), and I/O. The compilation pipeline no longer manipulates S-expressions internally — it's cells and propagators. But the whole thing is orchestrated by Racket code.

This is where PPN delivers: the parsing pipeline (Tracks 1-3) and elaboration (Track 4) become a network that Racket orchestrates. The `process-file` function becomes: construct network, write source to input cell, run to fixpoint, read results from output cells.

### Phase 2: LLVM Lowering

A lowering pass reads the network's typed AST cells and emits LLVM IR. This is a conventional compiler backend — it reads cell values (which are `expr-*` structs) and produces LLVM IR instructions. The propagator architecture is agnostic to the output target.

The lowering pass itself could be either a Racket function (simple) or a propagator stratum (principled). As a propagator stratum, each LLVM instruction pattern is a registered rule that fires when its input cell (typed AST node) is ready. This gives incremental lowering for free — edit a function, only re-lower that function's cells.

### Phase 3: Self-Hosting (Logos)

The Logos compiler is a Prologos program that:

1. Constructs a PPN (parsing network) for Logos source
2. Constructs an elaboration network (PPN Track 4's attribute evaluation)
3. Reads typed AST from the network
4. Emits LLVM IR via the lowering stratum

This Prologos program runs on the Phase 1 infrastructure (propagator network on Racket host). It produces a native binary via LLVM. That native binary IS the Logos compiler — it can compile itself.

The bootstrap chain: Racket → Prologos (propagator compiler on Racket) → Logos (native compiler via LLVM) → Logos (self-hosted native compiler).

### Phase 4: Racket Dependency Dissolves

Once Logos self-hosts, the Racket runtime is only needed for bootstrapping (like how GCC bootstraps from a previous GCC). The native Logos runtime provides: propagator scheduling (replacing Racket's BSP scheduler), memory management (replacing Racket's GC — see RESEARCH_GC.md), I/O (replacing Racket's ports).

The Racket prototype becomes the bootstrap stage — run once to produce the first native Logos binary, then never needed again (unless bootstrapping from scratch).

---

## 4. Implications for Current Work

### The sexp `process-string` path is the bootstrap compiler

The ~350 test files using sexp syntax via `process-string` are exercising the bootstrap compiler. The ~1545 lines of sexp expanders are bootstrap compiler infrastructure. They'll persist until the propagator pipeline handles ALL compilation (PPN Track 4+), at which point they become part of the bootstrap stage.

This reframes the "sexp path retirement" discussion: we're not retiring legacy code — we're separating the bootstrap compiler from the production compiler. The production compiler is the propagator network. The bootstrap compiler is the Racket-hosted sexp pipeline.

### Track 2B correctly deploys the production compiler

Track 2B makes the tree parser (production compiler's front end) the default on all WS paths. Phase 5 parameterizes `preparse-expand-all` to skip expansion for user forms — the production compiler handles those via tree parser, while the bootstrap compiler's expanders remain available for the sexp path.

### PPN Tracks 3-4 complete the production compiler

Track 3 (parser as propagators) eliminates `parse-datum` — the last Role 2 usage of S-expressions in the production path. Track 4 (elaboration as attribute evaluation) puts the elaborator on the network. After Track 4, the production compiler IS a propagator network. The bootstrap compiler (sexp pipeline) is a separate path used only by `process-string` and the REPL sexp mode.

### The Datum type survives as a language feature

Homoiconicity is preserved. The `Datum` type (8 constructors: `DatumInt`, `DatumString`, `DatumSymbol`, `DatumList`, etc.) is a user-facing value type. Quote produces Datum values from the parse tree (not from S-expressions — the tree parser already does this). Macros consume and produce Datum values. The self-hosting compiler inspects Datum values when doing metaprogramming.

The Datum type's source shifts from "Racket datum → Prologos Datum" to "parse tree node → Prologos Datum." The semantic guarantee is unchanged; the implementation mechanism is more principled.

---

## 5. Open Questions

1. **When should the self-hosting series be created?** Prerequisites: PPN Track 4 (propagator compiler complete), LLVM lowering infrastructure, runtime design (GC, scheduling, I/O). A Master Roadmap placeholder is warranted now; a full series design requires PPN Track 4 outcomes.

2. **Does the propagator architecture affect the Datum type's design?** Currently 8 constructors for Lisp-like data. Should tree-level macros operate on a richer Datum type that preserves structural information (indentation, brackets, tags)? Or should the Datum type remain S-expression-shaped for simplicity?

3. **Is the lowering pass (typed AST → LLVM IR) a propagator stratum or a conventional function?** Propagator stratum gives incremental lowering. Conventional function is simpler to implement. The answer may depend on whether incremental compilation (PPN Track 8) is a priority for the self-hosting compiler.

4. **What is the minimal bootstrap?** Once Logos self-hosts, how small can the bootstrap compiler be? The ideal: a minimal S-expression reader + a tiny elaborator that can compile just enough Prologos to construct the propagator network. Everything else is compiled by the propagator compiler itself.
