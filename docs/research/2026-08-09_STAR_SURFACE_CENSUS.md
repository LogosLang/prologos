# The Star-Surface Census

**Date**: 2026-08-09
**Provenance**: workflow `wf_19cd5077-15b` — 5 read-only axes + an adversarial completeness critic + a synthesis pass, ~1.39M tokens.
**Base**: every agent verified `git rev-parse HEAD` = `d0ac2a58e3a72d4279d0b0ce1b78a18f9a3beb8c` at open and (where stated) at close. That commit is the revert of CIU T6 P4e-0 attempt 1. Read-only throughout; no repo file was edited by any agent; all probes ran under `/tmp/…`; the full suite was not run.
**Recorded in**: `docs/tracking/2026-07-28_CIU_T6_PATH_SELECTION_D4.md` § `#star-census` (six summary bullets). This file is the full artifact.

## What it was commissioned to find

CIU Track 6 Path Selection phase P4e needs to mint a reader-level token for the `*` (star / layer-delete) operator. **Two attempts had already failed.** Attempt 1 shipped a grouper mint that consumed the item preceding the star — count-CHANGING at the reader — and was built, verified, and then reverted (`d0ac2a58`) because it silently mis-defined forms and broke a live Sigma spelling. Attempt 2 proposed a count-PRESERVING bare marker and was refuted on paper before being written. Both attempts modelled the mint's blast radius as **the selection surface**; the blast radius is **the whole reader**.

The owner therefore ruled that attempt 3 must open from a *measured map* rather than an intuition about where a star can safely fire. The census was commissioned to answer, by measurement and code-read only: what already claims the `*` character, what would notice a change in item counts, what the reader's own structure permits, and what positive space is left. **It proposes no mechanism and makes no recommendation** — the synthesis says so explicitly ("Eleven distinct approaches the constraint set leaves open. No recommendation." / "Not designed here, deliberately").

## Evidence tags used throughout

The synthesis established a tagging convention that this document preserves:

- **[V]** — the synthesis agent ran or read it that session.
- **[V-n]** — verified by axis *n* and not re-tested by the synthesis.
- **[critic]** — first measured by the adversarial completeness critic.
- **[I]** / INFERRED — inferred from code read, flagged by the source rather than guessed.

---

<a id="constraints"></a>
## 1. The ranked constraint set

Ranked worst-first by failure severity: **silent wrong answer > lost definition > whole-file abort > loud error**, then the grammar-preservation constraints (Tier G) and sentinel obligations (Tier O) which cut across all tiers.

**38 constraints total**: A1–A10 (10), B1–B3 (3), C1–C4 (4), D1–D4 (4), G1–G9 (9), O1–O8 (8).

> ⚠ **Naming collision inside the source artifact**: the synthesis uses `D1`–`D4` for Tier D constraints AND `D1`–`D16` for the *discriminator* inventory in a later section. They are unrelated numbering schemes. This document keeps both as the source wrote them; §5 discriminators are always cited as "discriminator D*n*".

<a id="tier-a"></a>
### TIER A — violation produces a SILENT WRONG ANSWER

| # | Constraint | Measurement | Consequence of violating |
|---|---|---|---|
| **A1** | **A bare `*` is a legal irrefutable PATTERN.** In `match` arms and `defn` clauses it is renamed to a fresh binder and matches everything. | `match q \| 2 * -> 99 \| n -> n` elaborates to `[[fn [x <_>] [reduce x \| 2 -> 99]]…]` — **one arm** **[V]**. The pattern compiler renames the star to a fresh binder; `match q \| 2 * -> 99` becomes `[reduce q \| 2 x -> 99]` **[critic]**. The datum is intact (`read-all-forms-string` gives both arms) and `split-match-arms-on-pipe` preserves both — the second arm vanishes downstream in `compile-match-tree`. | Every later arm is **silently deleted**. Green suite, zero errors, **0 corpus sites** to detect it. Named in the synthesis as *the worst failure mode in the census*. |
| **A2** | **A bare `*` in expression position is the bound value `prologos::core::arithmetic::*`** (first-class since Numerics N6e-E2), and eta-expands to two fresh metas. | 11 carriers measured: `x{a}*`, `xs:{a}*`, `[f x]*`, `(f x)*`, `.(1+2)*`, `'[1 2]*`, `@[1 2]*`, `#{1 2}*`, `{:a 1}*`, `` `[a 1]* ``, `#p(a)*` **[V-2, V-5, critic]**. Typical output: `Could not infer type [cfg{database} [prologos::core::arithmetic::* ?meta1756 ?meta1757]]`. | The line reads as **application**; the only symptom is an inference failure naming an arithmetic operator the user never wrote. **A design that assumes "a stray star is an error" is wrong.** |
| **A3** | **`select-step-kind` sorts a bare `*` as `'key`** — a nominal key literally named `*`. The closed-union totality machinery (`select-step-kind`'s raising `else`, `select-step-kind-unhandled`, `select-sort-unhandled`) protects LIST shapes and does **not** protect the symbol shape. Four `[leaf]` classifiers inherit the mis-sort. | `syntax.rkt` — `select-step-kind`, `select-step-kind/display`, and `select-key-step?` / `select-sub-step?` / `select-ord-step?` / `select-bcast-step?` **[V-2]** | The star travels through the selection vocabulary as a legitimate field name. Silent. |
| **A4** | **A count-CHANGING mint is silently absorbed by ≥15 item counters.** Restoring N makes the star invisible to every `= N` exact gate, every `>= N` gate, and every parity gate. | Axis 1's CONTROL leg *is* the count-changing simulation; it PASSES for `defmacro`, `deftype`, `bundle`, `schema`, `impl`, `specialize`, `defr`, `session` **[V-1]** | Attempt 1's actual failure, stated structurally: the validator accepts a shortened form and emits a **different program**. |
| **A5** | **A count-PRESERVING extra sibling silently mis-defines in at least 4 forms.** | Spaced legs: `data green*` → ctor arity 0→1; `trait` method type becomes `[String [* _ _]]` with the definition **still emitted**; `session` swallows the star, output identical to control; `'[1 2*]` → `⟨Int Int _ _ -> _⟩` **[V-1]** | Attempt 2's residual hazard, independent of the fold problem. |
| **A6** | **`pol8-bare-head?` accepts a bare `*` as a relational goal head.** | `defr qq [?f]` / `&> *` → `qq : _ defined.`, **0 errors** **[V-2]**, re-verified **[critic]** | A star that leaks into a `&>` clause silently becomes a goal named `*`. |
| **A7** | **`rewrite-dot-access`'s gate is `(ormap access-sentinel? datum)`.** A head that is not a member does not merely lose its own arm — **the entire fold is skipped for that datum list**, so any *sibling* `$dot-access` / `$bcast-step` stops folding too. | `macros.rkt`, the `rewrite-dot-access` gate **[V-2]**. The gate's second disjunct `ordinal-rekey-shatter?` is the existing precedent for a *sentinel-free* shape needing its own gate clause. | Collateral silent breakage of unrelated selections in the same list. |
| **A8** | **`mark-access-subject-run` uses `(andmap access-sentinel-elem? (cdr ts))` over the WHOLE tail.** A non-sentinel marker anywhere in the tail fails the andmap. | `parse-reader.rkt`, `mark-access-subject-run` **[V-4]** | Attempt 2's refutation at the marking layer: the command silently loses its implicit-solve goal marking. **Generalizes to every andmap-tail consumer.** |
| **A9** | **The two groupers must agree, and their vocabularies differ.** `group-items-to-tree` has no `'mixfix-rparen`, no `dot-lparen` / `rangle` / literal / backtick / postfix arms. | `surface-rewrite.rkt`'s `group-items-to-tree` vs `parse-reader.rkt`'s `group-items` **[V-4, V-5]** | A discriminator written once drifts (the F1b.7g class). ⚠ **Mitigating fact**: `group-items-to-tree`'s output is DISCARDED in production — `current-form-cell-map` / `current-spec-cell-map` have **2 writes and 0 reads** (`driver.rkt`) **[V-4]**. The obligation is the Q_N3 agreement guard, not correctness. |
| **A10** | **A sentinel-headed fold RESULT re-enters `preparse-expand-subforms` and swallows one LEFT sibling per pass.** | the `macros.rkt` fold contract **[V-4]** | Silently dropped `defn` clause at zero errors — recorded in-tree as a past incident. |

<a id="tier-b"></a>
### TIER B — violation LOSES A DEFINITION

| # | Constraint | Measurement | Consequence |
|---|---|---|---|
| **B1** | **An unrecognised constructor-position name becomes a catch-all variable, and the enclosing `defn` is never defined.** | `data Col := red \| green \| blue` + `defn f \| red* -> 1 \| green -> 2 \| blue -> 3` → *"unreachable match arm: arm 2 can never run… If a name there was meant as a CONSTRUCTOR, it was not recognised as one…"* plus **`Unbound variable f`** **[V, critic]**. The control (`red`) defines `f : pat2c::Col -> Int`. | The definition and every use of it are lost. The diagnostic is *guided* but never names the star; it blames spelling/imports. **`database*` "works" only because nobody put it in a pattern.** |
| **B2** | **`impl` loses the dict / the method under a star in either position.** Head position: the instance key becomes `Int*--Add--add` or `Int-*--Add--add` and **`Int--Add--dict` is LOST**; body position: **`Int--Add--add` is LOST**. The spaced-head error **names `Add`**, not the star. | Axis 1 probes `impl_*`, `impl2_*` **[V-1]** | Silent-adjacent: a definition disappears and the error points at an unrelated name. |
| **B3** | **Attempt 1's `bundle Bx := (Add Sub)*` produced NO output at 0 errors**, where the spaced form errors. | the revert record + `tests/test-path-selection.rkt` (the attempt-1 revert assertions) **[V-3]**. At HEAD both glued and spaced legs give the correct loud error (`bundle: invalid body syntax`) — reproduced-by-absence: the mint is what removed it **[V-5]**. | The historical instance of A4 + B. |

<a id="tier-c"></a>
### TIER C — violation ABORTS THE WHOLE FILE (largest tier; reachable at census HEAD)

| # | Constraint | Measurement | Consequence |
|---|---|---|---|
| **C1** | **A preparse-layer refusal ABORTS the file whenever a `data` / `trait` / `impl` succeeded in it.** `preparse-expand-all`'s per-form `with-handlers` converts any `exn:fail?` into `(list '$preparse-error msg)` — **a bare list, not a syntax object** — and `parser.rkt` turns that into a per-command error so the file continues. But later in the *same function*, the Phase-5b hoist of data/trait-generated defs runs a `partition` whose predicate calls `(syntax->datum stx)` on **every** element of `result`. The fast path is taken only when `generated-decl-names` is empty. | 5 of 8 star-carrier form refusals abort under a `data` — see the table below. **139 of 305 corpus files** contain a top-level `data`/`trait`/`impl` and are in the abort-susceptible class **[V]**. | **Zero output — not even the forms above it.** This is where the obvious design move ("refuse the star loudly in the form validator") lands. |
| **C2** | **`compile-match-tree` aborts on a multi-form literal pattern arm.** `\| 2 3 -> 99` → `list-ref: contract violation / expected: pair? / given: '()`. Reproduces in **sexp mode**, so it is an IR defect, not a reader artifact. | `macros.rkt`, `compile-match-tree` **[V, critic]** | The star-free CONTROL detonates where the starred form does not (`\| 2 * ->` is irrefutable and survives). **An A/B against a star-free control will mis-attribute.** |
| **C3** | **A raise anywhere on the reader / preparse / expansion path is a whole-file abort** (the standing `pipeline.md` class). The tell is EMPTY, not partial, output. | `pipeline.md`; `parse-reader.rkt`'s `compat-tokenize-string` raises `Unexpected character: .` — exported as `tokenize-string`, with **0 production callers** **[V-4, critic]** | Any new tokenizer/recognizer raise is a file-killer. |
| **C4** | *(stale claim — do not budget for it)* `pipeline.md`'s *"`'[1 2]` in a `defmacro` TEMPLATE is a whole-file abort TODAY"* **does not reproduce**. Commit `446070fc8` made `datum-subst` default an unbound pattern var to itself. `pattern-var?`'s residual is now **SILENT** (24 of 38), not an abort. | Axis 1 §5, Axis 2 §3 **[V-1, V-2]**, direction confirmed **[critic]** | The hazard is budgeting against a retired risk while C1/C2 are live. |

**The C1 abort seam, measured.** `data Bx := mk Nat` present in every file, layout `def before` / form / `def after`, each run through `process-file`, counting `defined.` lines and grepping for `syntax->datum: contract violation` **[V]**:

| starred form | defs printed | verdict |
|---|---|---|
| `defmacro tw [$x] [+ $x $x] *` | **0** | **ABORT** |
| `deftype Ty := Nat *` | **0** | **ABORT** |
| `bundle Bq := (Add Sub)*` | **0** | **ABORT** |
| `schema Usr / :age Int *` | **0** | **ABORT** |
| `impl Add Int where *` | **0** | **ABORT** |
| `selection Sel … *` | 5 | ok (per-command) |
| `defr dg [?d] / \|\| 0 1` | 5 | ok |
| `spec sq Int * -> Int` | 4 | ok |

Four further facts about C1, each **[V]**:

- **Order-independent** — an error before or after the `data` both abort.
- **Not star-specific** — a star-free `trait Sh A / ar : A -> Nat` plus a `data` aborts identically. It is a general latent defect that the star *reaches*.
- **The escape is accidental** — a failing trait plus a failing bundle (no successful decl) reports **both** errors cleanly, because `generated-decl-names` stayed empty.
- **The parser-layer star refusal is SAFE.** `cfg{database*}` plus a `data` prints every form plus the guided *"`*` (flatten) is not implemented yet"* parse-error. Only the **preparse** layer is affected.

⭐ **Why all five axes missed C1**: every axis used the same probe shape — `ns` / `def before` / form / `def after` — in which `generated-decl-names` is *always* empty, so the Phase-5b fast path is always taken. **The instrument was structurally blind.** Any attempt-3 gate that inherits that probe shape inherits the blindness.

The seam's own source comment records the owner ruling that made it head-agnostic *"so that a FUTURE sentinel reaching a preparse-consumed form lands here instead of taking the file down"* — i.e. C1 is a hole in the very mechanism built to prevent aborts.

<a id="tier-d"></a>
### TIER D — violation produces a LOUD ERROR (acceptable; noting the quality problems)

| # | Constraint |
|---|---|
| **D1** | The live `star-not-yet-message` refusal (`parser.rkt`, 5 call sites) is a **parse-error VALUE**, abort-safe even under a `data` **[V]**. This is the one existing star diagnostic that is structurally sound. |
| **D2** | `segment-select-items`' 24-arm `cond` has an exhaustive guided `else` — *"`~s` is not a valid selection branch — block branches are field names (e.g. `x{name server.{host}}`)"* — the **only totally-covered consumer in the census** **[V-2]**. |
| **D3** | **Existing diagnostics lie.** `m{0*}` reports *"`*` is postfix; it attaches to the END of a segment"* — the user *did* write it postfix. The message fires because `split-star-lexeme` sees `first-star = 0` on a lone `*` token **[V-1, V-5]**. |
| **D4** | `parse-list`'s head dispatch has **no catch-all**; an unknown `$`-head falls through to application → `Unbound variable $X` at every arity — loud but **misattributed** **[V-2]**. |

<a id="tier-g"></a>
### TIER G — grammar that must not break (cuts across all tiers)

| # | Constraint | Population | Evidence |
|---|---|---|---|
| **G1** | **Sigma / product type.** `star-symbol?` (`parser.rkt`) → **7 call sites**, reachable from **17 `parse-infix-type` sites** (`def :` annotations, `defn` param + return types, `fn` return, `{A : Type}` binders, `<…>`, `foreign` specs). Right-associative, binds tighter than `\|`, looser than application. | 4 in-`<>` corpus sites; **0** glued `)*` code sites | **[V]** (call count) + **[V-3]** |
| **G2** | **`*` as a first-class value.** Bare (`def m := *`), head (`* 5 6`), section (`[* _ 2]`), qualified (`base/*`), **and as a `foreign` export DECLARATION NAME** (`lib/examples/foreign.prologos` — `* : Nat Nat -> Nat`). | **76** spaced bare-`*` code sites (but see the count disagreement in §7.5) | **[V]** + **[V-3]** |
| **G3** | **Identifier fusion.** `ident-continue?` admits `*`; `int*`, `rat*`, `p64*`, `A*`, … | **170** fused trailing-star idents, 132 of them `int*` | **[V]** |
| **G4** | **`.(…)` mixfix multiplicative precedence** (`macros.rkt`'s `builtin-operators`, `(make-op '* '* 'multiplicative)`). | 21 in-mixfix sites | **[V-3]** |
| **G5** | **sexp-mode selection wildcards `'*` / `'**`** (`parser.rkt`'s `parse-path-string`; consumers `elaborator.rkt`'s `path-subsumes?` and the selection wildcard validation). LIVE in sexp; **structurally unreachable from WS** (the reader shatters `:addr.*`, and `recognize-broadcast-access` eats `:addr.**`). | — | **[V-3]** |
| **G6** | **`#p( … )` is an opaque reader region** — the ONE surface where a glued star survives *inside* (`#p(a.*)` → one symbol). It is **not** opaque outside: `#p(a)*` shatters like everything else. Semantics retired with guidance (`elaborator.rkt`'s `wildcard-seg?`). | — | **[V-3]**, outside-case **[critic]** |
| **G7** | **`.*ident` broadcast (M7)** — tokenizer claim LIVE (`recognize-broadcast-access`, priority 87, still registered), semantics retired with a guided message. **Any `.`-adjacency mint collides.** | — | **[V-3]** |
| **G8** | **`*` as a pattern (M8)** — legal today, **0 corpus sites**, and the source of A1/B1. | 0 | **[V]** |
| **G9** | **`$star` is a live, undocumented second Sigma spelling** reachable from user source in both modes (`def v : Nat $star Bool` → `[Sigma Nat Bool]`), with **zero producers** in the tree. `star-symbol?` is `(memq s '(* $star))` — it was *built* to accept a sentinel. | 0 | **[V-3]**, verified end-to-end **[critic]** |

<a id="tier-o"></a>
### TIER O — obligations a new reader sentinel incurs

| # | Obligation | Evidence |
|---|---|---|
| **O1** | A predicate in `macros.rkt`. | the sentinel-contract comment at `rewrite-dot-access` |
| **O2** | Membership in `arity2-access-sentinel-heads` (7 heads) **or** `brace-access-sentinel-heads` (2 heads) in `reader-forms.rkt`. ⭐ **These are the only two arity classes, and NOTHING declares arity — it is a property of which list you are in**, realised in two hand-written predicates (`access-sentinel?` in `macros.rkt`, `access-sentinel-elem?` in `parse-reader.rkt`). | **[V-2]** |
| **O3** | A fold arm in `rewrite-dot-access` whose result is **NOT sentinel-headed** (the fixpoint obligation — see A10). | **[V-4]** |
| **O4** | If the fold NESTS the base: an entry in `subject-preserving-access-heads` (5 heads, a deliberate subset whose complement is documented). | **[V-2]** |
| **O5** | It must not disturb the slice-7 marking invariants — INV-1 origin trichotomy, INV-3 no-descent, INV-5 4-arg property-template rebuild (see §7.4). | **[V-4]** |
| **O6** | `pattern-var?`'s denylist (`macros.rkt`) — residual **24 of 38** and now **silent**, so a miss is not self-announcing. | **[V-2]** |
| **O7** | ⭐ **THE BLOCKING ONE:** `$star-step`'s membership is **CONDITIONAL AND RECURSIVE** — base-needing iff its payload is (`m:0*` yes, `[f 1]*` no) — and *"a flat head list cannot say 'member iff its payload is a member'."* Recorded in-tree (the `access-sentinel?` post-mortem) as the reason attempt 1's sentinel could not join at all. | **[V-2, V-5]** |
| **O8** | The head-set tests in `tests/test-solve-carrier.rkt` are **data-driven loops over the head lists** — adding a head automatically imposes its class's arity contract. `($select-brace)` head-only is already `#t` for both consumers, so **a 1-element list is NOT unprecedented; it is the brace/any-arity class**, at the cost of losing the arity check. | **[V-2]** |

---

<a id="surface-map"></a>
## 2. The pipeline surface map

Production WS path: `process-file` / `process-string-ws` → `read-all-syntax-ws` (`driver.rkt`) → `preparse-expand-all` → `parse-toplevel-datum` → `merge-preparse-and-tree-parser` → `process-surfs`.

| # | Stage | Site | Available here | Consumes counts / switches on shape? | Notes for a mint |
|---|---|---|---|---|---|
| 1 | **Tokenize** (`tokenize-char-rrb`) | `parse-reader.rkt` | chars, byte positions, token types | chars → tokens | **Already owns 3 of the working bands** (`database*`, `x.a*`, `x:a*` all fuse). ⭐ **Must be touched anyway**: `recognize-dot-ordinal` and `recognize-colon-annotation` both DECLINE on a trailing `ident-continue?` char, so `x.0*` / `xs:0*` destroy their own carrier tokens. Cannot see a preceding `]` / `)`. C3 hazard: a raise here kills the file. |
| 2 | **Indent tree** (`read-to-tree` → `parse-string-to-cells`) | `parse-reader.rkt` | token-entries + line/indent | no | positions intact |
| 3 | `refine-tag` (T0) | `driver.rkt` | tags | no | form-kind dispatch only |
| 4 | **Flatten** (`flatten-with-boundaries`, + `/spec`, `/def`) | `parse-reader.rkt` | flat vector of token-entries | splices continuation lines | adjacency fully visible |
| 5 | ⭐ **`group-items`** (datum grouper) | `parse-reader.rkt` | `vec`, `i`, per-group accumulator `result`, byte positions **on both sides**, `close-type` | **YES — 24 arms**, all three count classes | **The site both attempts used.** The only stage seeing both the accumulator and raw adjacency. Also the only stage where a count change is simultaneously *necessary to express the operator* and *visible to every downstream validator* — the structural reason both attempts failed there. |
| 5′ | `group-items-to-tree` (tree grouper) | `surface-rewrite.rkt` | same vector | 13 arms, 6 arm families missing vs datum | **Output DISCARDED in production** (2 writes / 0 reads). Obligation = Q_N3 agreement guard only. |
| 6 | ⭐ **The marking layer** (`transform-let-blocks-elems` → `mark-command-goal-subject`) | `parse-reader.rkt` | **the emitted syntax ELEMENT LIST** with `pos` / `span` and `paren-origin` / `bracket-origin` properties | **no — pure list→list, same length in every arm** | **UNEXPLORED by both attempts.** Post-count, pre-preparse. Already performs a run-rewrite over a flat element list. Has the origin trichotomy (user parens vs user brackets vs layout). Never descends (INV-3). |
| 7 | `maybe-rewrite-infix-eq-stx` | `parse-reader.rkt` | element list | **yes (N→1 for `=`)** | precedent that post-grouping element rewriting is legitimate |
| 8 | `read-all-forms-from-tree` | `parse-reader.rkt` | forms | wraps | — |
| 9 | **`preparse-expand-all`** (Pass −1/0/1/2) | `macros.rkt` | **DATUMS** (`syntax->datum` / `strip-with-origin!`; compound nodes only get an index entry, so **an ATOM like `*` has no traceable syntax object**) | **YES — 24 form-level consumers** (below) | Byte adjacency is unavailable here. ⭐ **The C1 abort seam lives here**: the `$preparse-error` emit and the Phase-5b `partition`. |
| 10 | ⭐ **`rewrite-dot-access`** (the fold), 4 seats | `macros.rkt` | flat datum list, left-to-right accumulator | **YES — the fusion, N siblings → 1 nested node** | **Where every existing postfix operator actually resolves.** The four seats are the main preparse, map-literal contents, the `\|>` expander, and the `$mixfix` expander. Entry requires `access-sentinel?` membership → O2/O7. Gate is `ormap` (A7). The fold CLOSES the selection into the accumulator's head as it goes — attempt 2's grave. |
| 11 | `parse-toplevel-datum` → `segment-select-items` | `parser.rkt` | syntax (re-stamped), keyword table, `paren-goal-stx?` | segments a `$select` / `$select-path` payload | Reachable **only** from the args of a `$select` / `$select-path` node (4 call sites). Where the identifier band resolves via `split-star-lexeme`. Guided exhaustive `else`. |
| 12 | typing / elaboration | — | — | `compile-match-tree` (**C2 abort**), `select-step-kind` (**A3**) | pattern position lives here (**A1 / B1**) |

### Preparse's 24 form-level consumers

`grep "^(define (process-" macros.rkt` finds only **15**, of which **11** are top-level validators (`process-implicit-map-child`, `process-dash-child`, `process-monomorphic-impl`, `process-parametric-impl` are sub-dispatch) — **nine more consumers have no `process-*` function at all**, which is itself the capture gap. `awk` over `preparse-expand-all` finds **31 distinct dispatch heads**; `grep -cE '\((=|>=|<=|>) \(length datum\)' macros.rkt` → **46 length gates**.

| # | Handler | Head(s) | Deciding expression | Class |
|---|---|---|---|---|
| 1 | `process-defmacro` | `defmacro` | `(= (length datum) 4)` | **EXACT** |
| 2 | `process-deftype` | `deftype` | `(= (length datum) 3)` | **EXACT** |
| 3 | `process-spec` | `spec` | `(>= (length datum) 3)` + arrow-segment split | ≥ + segment |
| 4 | `process-bundle` | `bundle` | `(>= (length datum) 3)`; then `(and (= (length body-tokens) 1) (list? (car body-tokens)))` | ≥ + **EXACT inner** |
| 5 | `process-data` | `data` | `(>= (length datum) 2)`; ctors split on `\|` | ≥ + splitter |
| 6 | `process-trait` | `trait` | `(>= (length datum) 3)` | ≥ |
| 7 | `process-property` | `property` | `(>= (length datum) 3)` | ≥ |
| 8 | `process-functor` | `functor` | `(>= (length datum) 3)` | ≥ |
| 9 | `process-precedence-group` | `precedence-group` | `(>= (length datum) 2)` | ≥ |
| 10 | `process-impl` | `impl` | `(>= (length datum) 4)` + **positional remainder loop** over `(cddr datum)` splitting type-args / `where` / defns | ≥ + **positional consume** |
| 11 | `process-specialize` | `specialize` | `(>= (length datum) 4)`, then positional `for` | ≥ + positional |
| 12 | inline `schema` arm | `schema` | `(>= (length datum) 2)` then `flatten-ws-kv-pairs` → **PAIRWISE** `parse-schema-fields` | **parity** |
| 13 | inline `selection` arm | `selection` | `(>= (length datum) 4)` + `(list-tail datum 4)` | ≥ + positional |
| 14 | inline `session` arm | `session` | `(>= (length datum) 2)` → `desugar-session-ws` | ≥ |
| 15 | inline `defproc` / `proc` | `defproc`, `proc` | `(>= (length datum) 2)` → `desugar-defproc-ws` | ≥ |
| 16 | inline `strategy` | `strategy` | `(>= (length datum) 2)` | ≥ |
| 17 | inline `solver` | `solver` | `(>= (length datum) 2)` + `flatten-ws-kv-pairs (cddr datum)` | parity |
| 18 | inline `defr` | `defr` | `(>= (length datum) 2)`; body arity via the `\|\|` / `\|` row splitter | ≥ + **row arity** |
| 19 | inline `capability` | `capability` | `(>= (length datum) 2)` | ≥ |
| 20 | `spawn` / `spawn-with` | — | **pass-through, NO gate** | none |
| 21 | `exports` / `provide` | — | `process-exports` (`namespace.rkt`) | list scan |
| 22 | `imports` / `require` / `ns` | — | `process-imports-spec` (`namespace.rkt`) | per-item |
| 23 | `foreign` | — | `process-foreign` | positional |
| 24 | `defn` / `def` | — | `extract-defined-name` + `def-rhs-stx` (**exactly ONE element after `:=`**) | **EXACT-1** |

**Non-form counters beyond preparse**: `split-on-star` (`parser.rkt`, splits type atoms on `*`; empty segment ⇒ "Empty type segment"), `parse-dependent-angle` (`>= 3` parts + `star-symbol?`), `parse-shorthand-dependent-angle` (`>= 4`), map-literal even/odd parity, `flatten-ws-kv-pairs` (**changes the count of its own output**), `parse-schema-fields` (pairs), `expand-let-impl` / `expand-let-bracket-bindings` (pairs at odd indices), `mark-binding-values` (exactly one element after `:=`; bare-binding arm; odd-index pair arm), `mark-access-subject-run` (**whole-tail andmap**), `access-sentinel?` (**the two arity classes**). `grep -c '(length ' parser.rkt` → **194**.

---

<a id="carrier-table"></a>
## 3. The carrier table

Seven target carriers. Subjects used for the end-to-end probes: `cfg` a nested record, `party : [PVec {…}]`. Datums **[V-2 / V-5]**; end-to-end **[V-5]**.

**Headline arithmetic**: **1 of 7 as-spelled** (`m{0*}`) reaches the selection surface today · **5 of 7** do when rewritten in-block · **2 (`x.0*`, `xs:0*`) reach nothing under ANY spelling without a tokenizer repair.**

| Carrier | Datum at HEAD | Star's position | End-to-end today | Constraints that bear |
|---|---|---|---|---|
| **`database*`** (ident band) | `(database*)` — **ONE token** | fused into the lexeme | **guided** *"`*` (flatten) is not implemented yet"* — and **abort-safe** under a `data` **[V]** | G3 (170 sites) · **A1/B1** (in a pattern it silently eats arms and loses the defn) · D1 |
| **`x.a*` / `xs:tags*`** (ident band, extended) | `(x ($dot-access a*))` / `(xs ($bcast-step :tags*))` | fused | same guided refusal | G3 · A1/B1 · D1 |
| **`m{0*}`** (in-block, numeric) | `(m ($select-brace 0 *))` | **INSIDE** the brace, its own item | **LYING** — *"`*` is postfix; it attaches to the END of a segment"* | D3 · A3 · reaches `segment-select-items` via `split-star-lexeme`'s `first-star = 0` arm |
| **`cfg{a* b}`** | `(cfg ($select-brace a* b))` | **fused** | guided | ⭐ **A block mixes both bands**: ident steps fuse, numeric steps shatter — item count ≠ step count **[critic]** |
| **`values:{0* 1* 2*}`** — the ONE live design-intent corpus site (`lib/examples/foray.prologos`) | `(values ($bcast-step ($select-brace 0 * 1 * 2 *)))` | inside, **6 items for 3 steps** | — | A3 · the count-vs-step mismatch |
| **`x{a}*`** | `(x ($select-brace a) *)` | **OUTSIDE**, sibling, `close-type = #f` | **SILENT** — `Could not infer type [cfg{database} [prologos::core::arithmetic::* ?m ?m]]` | **A2** · preceding item HAS a distinctive sentinel head (discriminator D3 applies) |
| **`xs:{a}*`** | `(xs ($bcast-step ($select-brace a)) *)` | OUTSIDE, sibling | **SILENT**, same shape | **A2** · distinctive head |
| **`xs:0*`** | `(xs : 0 *)` — ⚠ **`$bcast-step` NEVER MINTED** | OUTSIDE; carrier destroyed | `Unbound variable :` | ⭐ **Tokenizer band.** `recognize-colon-annotation` declines on the trailing `ident-continue?` char. No grouper-level discriminator can reach it. |
| **`x.0*`** | `(x \|.\| 0 *)` — ⚠ **`$postfix-index` NEVER MINTED** | OUTSIDE; carrier destroyed | `Unbound variable .` | ⭐ Same tokenizer band (`recognize-dot-ordinal`). Also the `compat-tokenize-string` raise (C3, dead in production). |
| **`[f x]*`** | `((f x) *)` | OUTSIDE, sibling | **SILENT** arithmetic misread | **A2** · ⚠ **datum-identical to `(f x)*`** — no discriminator at the datum layer |
| **`(f x)*`** | `((f x) *)` — identical | OUTSIDE, sibling | identical | **A2** · ⚠ collides with `bundle Bx := (Add Sub)*` (**B3 / C1**) and with glued Sigma `<(x : Nat)* Nat>` (**G1**) |
| **`.(1+2)*` · `'[1 2]*` · `@[1 2]*` · `#{1 2}*` · `{:a 1}*` · `` `[a 1]* `` · `#p(a)*`** | `((<group>) *)` | OUTSIDE, sibling | **SILENT** arithmetic misread ×7 | **A2** · G4 (mixfix collision) · G6 (`#p` opaque inside, not outside) — **uncensused by all five axes** **[critic]** |
| in-block twins `cfg{X*}` for `x{a}`, `[f x]`, `(f x)` | star is an item of the `$select-brace` | **INSIDE**, `close-type = 'rbrace` | reaches `segment-select-items` | 5 of 7 carriers land inside when written in-block; **`.N*` / `:N*` stay shattered under any spelling** |

**The two bands, stated precisely** (Axis 5): `x{a}*`, `xs:{a}*`, `[f x]*`, `(f x)*` are "the star is a well-formed separate token next to an intact carrier". `xs:0*` and `x.0*` are "**the star's presence destroys the carrier's own token**" — `xs:0` alone lexes as `(colon-annotation :0)` → `($bcast-step :0)`, and `x.0` alone lexes as `(dot-ordinal 0)` → `($postfix-index 0)`; adding the star deletes both. Mechanism: the `[(and c (ident-continue? c)) #f]` clause in each recognizer, with `*` an `ident-continue?` char.

**In-block twins measured** (Axis 5, same probe):

| In-block spelling | Datum |
|---|---|
| `cfg{0*}` | `(cfg ($select-brace 0 *))` |
| `cfg{a{b}*}` | `(cfg ($select-brace a ($select-brace b) *))` |
| `cfg{a:{b}*}` | `(cfg ($select-brace a ($bcast-step ($select-brace b)) *))` |
| `cfg{[f x]*}` | `(cfg ($select-brace (f x) *))` |
| `cfg{(f x)*}` | `(cfg ($select-brace (f x) *))` |
| `cfg{a:0*}` | `(cfg ($select-brace a : 0 *))` ⚠ still shattered |
| `cfg{a.0*}` | `(cfg ($select-brace a \|.\| 0 *))` ⚠ still shattered |

**The `*_` twin** (provenance-key spelling) is uniformly worse today than the bare star: every non-identifier carrier gives `Unbound variable *_`, while the bare star silently resolves to the first-class arithmetic operator. Both are wrong; the bare `*` is the more misleading **[V-5]**.

**Population summary [V]**: 0 code sites for `)*` `]*` `}*` `>*` · 1 live design-intent site (`values:{0* 1* 2*}`) · 76 spaced arithmetic `*` · 170 fused idents · 0 bare-star pattern arms · 139/305 files abort-susceptible. (See §7.5 for a count disagreement between axes on the middle two figures.)

---

<a id="discriminators"></a>
## 4. The discriminator inventory

Everything that **exists in the code today** and could separate a selection-postfix star from the other six-plus meanings. This is the synthesis's numbering (D1–D16 + D2′); Axis 5 numbered a smaller overlapping set differently — see §7.5.

| # | Discriminator | Site | CAN distinguish | CANNOT distinguish |
|---|---|---|---|---|
| **D1** | `ident-continue?` fusion | `parse-reader.rkt` | `a*` (fused, one token) from `a *` and `3 * 4`; already carries 3 of 7 bands | any carrier not ending in an identifier char (`]* )* }* >* .0* :0*`) |
| **D2** | **`close-type`** (the grouper's recursion parameter) | 15 call sites in `parse-reader.rkt` | mixfix body (`'mixfix-rparen`) · angle body (`'rangle`) · top level (`#f`) — behaviourally confirmed by an angle-group probe across 10 contexts **[V-5]** | ⚠ **select-block vs map-literal vs set-literal vs `.{}` vs `:{}` — all `'rbrace` (5-to-1)**; bracket vs list/pvec/lseq literal — all `'rbracket` (6-to-1); top level vs paren group is `#f` vs `'rparen`, but `bundle …(Add Sub)*` and `(f x)*` are **both** `#f` |
| **D2′** | ⭐ **the group SENTINEL, computed one frame up and discarded** | `parse-reader.rkt`'s `lbrace` arm computes `$select-brace` vs `$brace-params`, then passes only `'rbrace` to the recursive call **[V]** | would give the exact select-vs-map distinction D2 lacks | nothing yet — it is thrown away. `surface-rewrite.rkt` has the identical shape (`group-tag` computed at the caller, `'rbrace` passed down) |
| **D3** | preceding item's SHAPE, `(car result)` | grouper `else` arm | `x{a}*` (`$select-brace` head) · `xs:{a}*` (`$bcast-step` head) — **distinctive sentinel heads** | `[f x]*` from `(f x)*` from `(Add Sub)*` — **byte-identical datums** |
| **D4** | syntax properties `'prologos-paren-origin` / `'prologos-bracket-origin` | `parse-reader.rkt`; consumers in `parser.rkt` and `macros.rkt` | user-written group vs pure LAYOUT group (the slice-7 trichotomy; two otherwise byte-identical datums separate here **[V-4]**) | `(f x)*` from `(Add Sub)*` — both are user parens carrying the same mark |
| **D5** | **`adjacent-to-base?`** | `parse-reader.rkt` — byte positions + `(pair? result)`, consults **no token type** | glued `x{a}*` from spaced `x{a} *`; protects the spaced-arithmetic sites | ⚠ **glued-legal hazards**: `<(x : Nat)* Nat>` and `bundle B := (Add Sub)*` are BOTH byte-glued. **This is the predicate attempt 1 used, and exactly why it failed.** |
| **D6** | the FOLLOWING token (`vec[i+1]`) | precedent: `bcast-brace-trigger?` is a shipped both-sides trigger | `*}` (star closes a block) from `* Nat>` (star followed by a type) — **separates in-block from the Sigma hazard without close-type** | `(f x)*` at EOL from `(Add Sub)*` at EOL — both followed by nothing |
| **D7** | `prev-token-not-emitted?` | `parse-reader.rkt`, 2 call sites (both bcast triggers) | the 2 cosmetic skipped tokens (`'`, `,`) | anything else. ⚠ **The older bracket/brace arms never call it**, so `x ,[0]` mints `$postfix-index` across a comma **[V-4]** — there is no single convention to inherit |
| **D8** | `reader-form-head?` | `reader-forms.rkt` | **one symbol: `racket`** | everything else — it is not a preparse-form registry |
| **D9** | `private-form-base` | `reader-forms.rkt` | the 11 `-`-suffixed private binding heads (`defn-`, `def-`, `data-`, `deftype-`, `defmacro-`, `spec-`, `trait-`, `impl-`, `bundle-`, `property-`, `functor-`) | it is a suffix normalizer; `bundle` — the actual hazard head — is reachable only as `bundle-` |
| **D10** | line-head token, `(last result)` | grouper | — | ⚠ **There is NO reader-reachable registry of preparse form heads.** Preparse dispatches by a `case` inside `macros.rkt`, which `parse-reader.rkt` structurally cannot require — that cycle is the stated reason `reader-forms.rkt` exists. A hand-copied head list here **is** the F1b.7g drift class |
| **D11** | `star-sym?` / `split-star-lexeme` | `parser.rkt` (5 call sites; but see §7.5) | a star inside a fused lexeme, with position; already routes to `star-not-yet-message` | a lone `*` token — hits the `first-star = 0` arm and lies (Tier D3) |
| **D12** | **`star-symbol?`'s `$star` slot** | `parser.rkt`, **7 call sites** | already accepts a sentinel spelling; **zero producers** | it is the *Sigma* acceptor — a sentinel named `$star` silently becomes a product separator |
| **D13** | `parse-infix-type` entry (17 sites) | `parser.rkt` | **the definitive Sigma-vs-value discriminator** | ⚠ **unavailable to the reader — it is downstream of the type/expression fork** |
| **D14** | `select-step-kind` closed union | `syntax.rkt` | LIST shapes (raising `else`) | ⚠ **the SYMBOL shape** — a bare `*` takes the `'key` arm before any totality check (A3) |
| **D15** | shape-based `$`-prefix tests | `param-group-candidate?`, `goal-head-datum?`, `pol8-sentinel-headed?`, `reconstitute-path-list`'s element test (+ `is-dict-param-name?`) | ⭐ **the only drift-immune classifiers in the census** — all key on the literal `$` character, never on a list; none has ever needed an update when a sentinel was added | — |
| **D16** | `qq-depth`, indentation / column, `source-str` | grouper params | quasiquote body; absolute line/col | nothing semantic; the two groupers carry indentation differently (`indent` is a plain param in `group-items-to-tree`, absent in `group-items`) |

**Tallies [V-2]**: ~40 classifiers answer **silently** on a bare `*`, `($X)` or `($X Y)`; ~6 answer loudly. The 6 loud ones are `segment-select-items`' arm chain + `else`, `select-step-kind`'s raising `else` + its 3 ω-transparent accessors, `select-step-kind-unhandled`, `select-sort-unhandled`, and `parse-list`'s fall-through (loud but misattributed).

**The one count-PRESERVING precedent that ships**: `bcast-step-trigger?` + its grouper arm mints `($bcast-step :name)` as a **sibling** — 1 token in, one 2-element node out, base untouched (`xs:a` → `(xs ($bcast-step :a))`, 2 items in, 2 items out) **[V-5]**. The reason it does not transfer to the star is O7, not the mint shape.

⭐ **And the structural fact underneath everything**: **no existing mint attaches to a preceding item — zero of eight** (`$dot-access`, `$postfix-index`, `$dot-key`, `$nil-dot-*`, `$broadcast-access`, bracket-postfix, `$select-brace`, `$dot-brace`, `$bcast-step`). The uniform strategy is **mark, don't fuse**; the base stays a left sibling and the join happens two stages later at the fold. `macros.rkt` says so at the fold's own site: *"Fusion is NOT a grouping-layer operation: `is-postfix?` / `adjacent-to-base?` only MARK (`xs[0]` yields two siblings), and this fold is what joins them."* **[V-4]**

---

<a id="approaches"></a>
## 5. The enumerated approaches

The synthesis enumerates **twelve** (R1–R12), plus three named composites.

> ⚠ **Internal inconsistency in the source**: the section's own header says *"Eleven distinct approaches"* while twelve are listed. The design doc's summary bullet says **twelve**. Twelve is what is written out.

<a id="r1"></a>
### R1 — Grouper mint, count-CHANGING adjacency (ATTEMPT 1)

**Satisfies**: nothing that matters.
**Violates**: A4 (≥15 counters absorb it silently), B2/B3 (impl dict, bundle definition), **G1** (breaks the glued Sigma spelling), A9 (the two groupers wrapped different items on `<` / `>`).
**Cost**: shipped and reverted at `d0ac2a58`.
**Unknown**: none — this is settled.

<a id="r2"></a>
### R2 — Grouper mint, count-PRESERVING bare marker (ATTEMPT 2)

**Satisfies**: A4 (counts preserved).
**Violates**: **A8** (`mark-access-subject-run`'s andmap-tail fails); **O2/O7** (a non-sentinel marker is left a sibling outside `$select` / `$select-path` args; registering it collides with the two arity classes and orphans subjects — `[f]*.a` folds `.a` onto the marker); **A5** (silent mis-definition in `data` / `trait` / `session` / vector-literal survives count-preservation).
**Cost**: designed only.
**Unknown**: none material.

<a id="r3"></a>
### R3 — Grouper mint gated on the group SENTINEL (propagate D2′ instead of `close-type`)

Thread the already-computed `$select-brace` / `$brace-params` sentinel into `group-items` alongside `close-type`, and mint only under `$select-brace` (± `$dot-brace`, `$bcast-step`-wrapped).
**Satisfies**: G1 (Sigma is `'rangle` — unreachable) · G4 (mixfix is `'mixfix-rparen`) · G2 (top level is `#f`) · **C1 for `bundle` / `defmacro` / `deftype` / `schema` / `impl`** (all at `#f`, never inside a select brace) · D2's 5-to-1 ambiguity is *dissolved*, not worked around.
**Violates / does not address**: covers only the **in-block spelling** — 5 of 7 carriers when rewritten in-block, **1 of 7 as the brief spells them** · `.N*` / `:N*` untouched (tokenizer band) · A1/B1 untouched (a select block can appear in a `defn` body) · A9 (the tree grouper needs the twin change).
**Cost**: one extra parameter on two grouper functions and 15 + 13 call sites; the sentinel already exists at the datum caller and a `group-tag` already exists at the tree caller.
**UNKNOWN**: whether the mint must still be count-changing *inside* the block (`0 *` → one step) and, if so, whether `segment-select-items`' 24-arm chain absorbs or rejects it; whether `$select-brace`-only is the owner's intended surface.

<a id="r4"></a>
### R4 — Tokenizer repair: make `.N*` and `:N*` fuse

Relax the two `[(and c (ident-continue? c)) #f]` decline clauses (`recognize-dot-ordinal`, `recognize-colon-annotation`) so a trailing `*` does not destroy the carrier, letting `.0*` / `:0*` reach `split-star-lexeme` the way `.a*` / `:a*` already do.
**Satisfies**: the **only** route to the `.N*` / `:N*` band (no downstream stage can reach them) · reuses the live, abort-safe D1/D11 refusal machinery.
**Violates**: nothing structural found — but the declines exist to protect `x.0N`, `x.1e3`, `:10abc` (their own comments say so), so the relaxation must be `*`-specific.
**Cost**: two guard clauses; C3 hazard (a raise here kills the file).
**UNKNOWN**: whether `*`-specific relaxation reintroduces the numeric-suffix ambiguity the guards were added for (Q_R2); whether `compat-tokenize-string`'s raise path matters — it has **0 production callers** but is exported as `tokenize-string`.

<a id="r5"></a>
### R5 — Resolve at the MARKING LAYER (stage 6) — untried by both attempts

Rewrite the flat element list after `group-items` returns, before preparse. Precedent in place: `maybe-rewrite-infix-eq-stx` already does an N→1 element rewrite there.
**Satisfies**: **A4 by construction** — it runs *after* the reader's counts are fixed and *before* preparse · not `segment-select-items`, so R2's refutation does not apply · the origin trichotomy (D4) distinguishes user groups from layout · positions survive (Axis 4 measured `[f x]*` keeping `*` at position 6 vs 7 for the spaced form, **surviving `preparse-expand-all` intact** for forms preparse does not rebuild).
**Violates / risks**: it still shortens the form *for preparse*, so **A4 returns in full** — the 24 form validators are downstream · INV-3 (no-descent) means it sees only top-level element lists, so a star inside a `defn` body or a bracket group is out of reach · INV-5 (4-arg rebuild) must be honoured or paren-origin is lost.
**Cost**: a new pass in `transform-let-blocks-elems`' chain.
**UNKNOWN**: ⭐ **The stated adjacency invariant `Q8.5 inv 2` ("adjacency is destroyed below grouping") is FALSE as written** — Axis 4 measured it surviving. What is actually true: adjacency dies at *node rebuilding* (`:=` rewrite, `datum-subst`, `flatten-ws-datum`) and is unavailable inside datum-level preparse arms (atoms get no `strip-with-origin!` index entry). **Nobody has measured which rebuilds happen between stage 6 and the specific consumers that matter.** That measurement is the gate on this option.

<a id="r6"></a>
### R6 — Resolve at the FOLD (stage 10) with a head-set entry

**Satisfies**: it is where every existing postfix operator resolves; A4 is a non-issue for the fold's own seats (preparse counts are already spent).
**Violates**: **O7 head-on** — `$star-step`'s membership is payload-conditional and a flat head list cannot express it; **A7** (the `ormap` gate breaks sibling folding if the head is not a member); **O8** (the data-driven arity tests in `test-solve-carrier.rkt` will demand an arity contract the star cannot honour).
**Escape hatches that exist but change the semantics**: join the **brace/any-arity class** (`($star-step)` head-only is already `#t` for both `access-sentinel?` and `access-sentinel-elem?` — a 1-element list is NOT unprecedented **[V-2]**) at the cost of losing the arity check entirely; or split into **two heads** (base-needing vs not) so each is unconditionally a member.
**Cost**: O1–O6 in full.
**UNKNOWN**: whether the two-head split is expressible without the payload test resurfacing at the fold arm; whether brace-class membership breaks the `($star-step a b c)` mis-arity leak the tests pin.

<a id="r7"></a>
### R7 — Parser-only: resolve at `segment-select-items`

Do nothing at the reader; teach the 24-arm chain to accept a lone `*` item as a step.
**Satisfies**: zero reader risk · the chain has an exhaustive guided `else` (Tier D2) · covers exactly the carriers that already arrive **inside** `$select` / `$select-path` args.
**Violates**: reachable **only** from those args (4 call sites) — so it covers `m{0*}` and the in-block twins and **nothing else**; A2 unaddressed for every after-the-group carrier.
**Cost**: one or two arms + the lying-message fix (Tier D3).
**UNKNOWN**: whether the item-count-≠-step-count property (`values:{0* 1* 2*}` → 6 items for 3 steps; `cfg{a* b}` → 2 items, one fused) admits a uniform segmentation rule, or whether the fused and shattered bands need separate arms.

<a id="r8"></a>
### R8 — Narrow the language: in-block spelling only

Rule that the star is written *inside* a select block (`cfg{a{b}*}`, `cfg{0*}`) and that a star after a closing delimiter is a **guided refusal**.
**Satisfies**: G1, G2, G4, G6, G7 all untouched · combines cleanly with R3 and/or R7 · the refusal population is **0 code sites** (`)*` `]*` `}*` `>*` all zero).
**Violates**: it is a language decision, not a mechanism — the owner must want it.
**Cost**: the refusal must be a **parser-layer `parse-error` value**, not a preparse raise (**C1**: the parser path is abort-safe under a `data`; the preparse path aborts 5 of 8 forms).
**UNKNOWN**: whether the intended semantics (mapcat over a vector layer vs splat over a nominal one) is even expressible in-block for `[f x]*` / `(f x)*`, whose subject is an arbitrary expression, not a select step.

<a id="r9"></a>
### R9 — Narrow the language: a different spelling

Use a character or token that no grammar claims — a `$star`-style sentinel, a keyword step (`:flatten`), `**`, `~`, etc.
**Satisfies**: everything in Tier G by construction; O7 dissolves (the spelling can be made unconditionally sentinel-shaped).
**Violates**: ⚠ **`$star` is already taken** — a live Sigma spelling with zero producers (G9) · `**` is `pow` in the mixfix table and is `Unbound variable **` outside it · a `:`-keyword spelling collides with the `$bcast-step` mint.
**Cost**: ergonomic — the star is the intended notation.
**UNKNOWN**: whether the owner will accept a non-`*` spelling at all; which characters are genuinely unclaimed (**no census exists — this document only censused `*`**).

<a id="r10"></a>
### R10 — Token-TYPE mint (no count change at any layer)

At the tokenizer, emit a **distinct token type** (say `'postfix-star`) for a `*` that is byte-adjacent to a preceding closer, instead of `'symbol`. The grouper then dispatches on the *type* rather than on adjacency.
**Satisfies**: D5's blind spot is inverted — the discriminator becomes a *type*, available to both groupers and to `bcast-step-trigger?`-style predicates, and it composes with D2/D2′ (mint the type at the tokenizer, *filter* by group at the grouper) · counts unchanged at every layer if the type simply replaces `'symbol`.
**Violates**: the type alone does **not** separate `(f x)*` from `(Add Sub)*` from glued Sigma `<(x : Nat)* Nat>` — all three are closer-adjacent. It needs a second-stage filter (D2/D2′ or D6), i.e. it is a *composite*, not a standalone.
**Cost**: one tokenizer rule; the grouper `else` arm gains a type test; both groupers must agree (A9).
**UNKNOWN**: whether the tokenizer can see "preceding closer" cheaply in its linear scan (it already does byte-position bookkeeping, but `adjacent-to-base?`'s `(pair? result)` conjunct lives at the *grouper*, not the tokenizer — so the two "adjacency" notions are not the same predicate).

<a id="r11"></a>
### R11 — Fix the abort seam first (C1), independent of any mint

Make the `$preparse-error` emit produce a syntax object (or make the Phase-5b partition predicate tolerate a non-syntax element).
**Satisfies**: removes the single largest failure tier (C1) from the design's exposure · **prerequisite for any option whose refusal lives in a preparse validator** (R8's guided refusal, any new form-level star check) · benefits 139/305 corpus files independent of the star.
**Violates**: nothing found.
**Cost**: likely one line, plus a test asserting a preparse error + a `data` yields per-command errors and full output.
**UNKNOWN**: whether the seat has other bare-datum producers besides the one emit site (the synthesis found **exactly one emit site and one consume site** in non-test code **[V]**); whether any consumer *depends* on the marker being a bare list.

<a id="r12"></a>
### R12 — Explicitly refuse the glued Sigma spelling

`<(x : Nat)* Nat>` is legal, live, elaborates to `[Sigma Nat Bool]`, and has **0 corpus sites** (the spaced form is what people write).
**Satisfies**: removes attempt 1's headline casualty from the constraint set, unblocking `close-type` / adjacency-based options in `'rangle`.
**Violates**: G1 as a *grammar* (the spelling is legal today), though not G1 as a *corpus*.
**Cost**: a guided error at one of the 7 `star-symbol?` call sites.
**UNKNOWN**: owner ruling only.

<a id="composites"></a>
### Composites the synthesis named

- **R11 + R3 + R4** — fix the abort seam, propagate the group sentinel, repair the two recognizers: covers all 7 carriers in the in-block spelling with no adjacency predicate and no Sigma exposure.
- **R10 + D2/D6** — token-type mint filtered by group kind or by the following token.
- **R11 + R8 + R7** — narrow to in-block, resolve in the parser, and make the refusal abort-safe.

<a id="subsequent-rulings"></a>
### Recorded outside the census: which options the owner subsequently ruled on

Not census content — recorded here only so a reader of this artifact is not left guessing. Per `docs/tracking/2026-07-28_CIU_T6_PATH_SELECTION_D4.md`:

- **Q_U30** (owner, 2026-08-09) — **all seven carriers are in scope, tokenizer repair included**. This is the ruling the carrier arithmetic sized: 1 of 7 as-spelled, 5 of 7 in-block, 2 unreachable without a tokenizer repair. Therefore **R8 (in-block narrowing) is REJECTED and R4 is IN**. The ruling adds a fact the census recorded separately: the two recognizers are **TWINS** — the P4e-0 attempt fixed the colon one and left the dot one untouched, which is how `x.0*` kept destroying the `$postfix-index`.
- **Q_U31** (owner, 2026-08-09) — **the glued Sigma spelling is refused; `*` at type level requires spaces**, i.e. **R12 adopted**, with the refusal required to be a parser-layer `parse-error` value rather than a preparse raise (C1).
- **C1 itself** was filed as DEFERRED 102 and fixed at `41458174`, i.e. R11 landed as a prerequisite.

---

<a id="axis-findings"></a>
## 6. Per-axis findings

<a id="axis-1"></a>
### Axis 1 — item-counting consumers

**The frame that makes every probe do double duty (VERIFIED).** At HEAD the reader **ERASES glued-vs-spaced for every non-identifier carrier**:

| input | datum |
|---|---|
| `bundle Bx := (Add Sub)*` | `(bundle Bx := (Add Sub) *)` |
| `bundle Bx := (Add Sub) *` | `(bundle Bx := (Add Sub) *)` — **identical** |
| `bundle Bx := (Add Sub)` | `(bundle Bx := (Add Sub))` |

Verified identical for `m{0*}`, `x{a}*`, `xs:0*`, `x.0*`, `[f x]*`. Only `database*` fuses. Two consequences structure the whole census:

- **The SPACED probe *is* the count-PRESERVING simulation.** A bare-marker mint leaves the form at N+1 elements with an extra sibling — arity-wise exactly today's `X *`.
- **The CONTROL probe *is* the count-CHANGING simulation.** Attempt 1 consumed the item before the star, restoring N elements — exactly the control's element count. **So wherever the control PASSES, a count-changing mint passes the same gate with the star invisible to the validator.** That is attempt 1's defect stated structurally rather than anecdotally.
- **The GLUED probe is not vacuous** — it is the identifier-fusion band, and it is the worst-behaved of the three.

**The probe triples, asserted on FULL OUTPUT.** Layout: `ns probe` / `def before := 1` / `<form>` / `def after := 2`. `before` + `after` present ⇒ no whole-file abort. **No count gate was used** — several forms produce zero results in *all three* legs.

| form | GLUED `X*` | SPACED `X *` (count-PRESERVING proxy) | CONTROL (count-CHANGING proxy) | verdict |
|---|---|---|---|---|
| `bundle` | error "invalid body syntax" | same | **OK** | (a) glued≡spaced, loud |
| `defmacro` | error `requires: (defmacro name …)` | same | **OK** | (a) |
| `deftype` | error `requires: (deftype name body)` | same | **OK** | (a) |
| **`spec`** | **NO spec error** — `Int*` fuses → becomes an implicit type param; error **displaces to the `defn`** as a Type-mismatch | parse-error "Empty type segment in arrow type" | `sq : Int -> Int` | **(b)+(d)** |
| **`data`** | **SILENT** — defines a constructor literally named `green*` | **SILENT** — `green : [* _ _] -> Col`, **ctor arity 0→1** | `green : Col` | **(b), NEITHER errors** |
| **`trait`** | unbound `String*` (×2), method undefined | **SILENT** — method type becomes `[String [* _ _]]`, definition **still emitted** | `[x -> String]` | **(b)+(c-adjacent)** |
| **`impl` (head)** | `Int*--Add--add` (wrong instance key), **`Int--Add--dict` LOST**, unbound `Int*` | `Int-*--Add--add` (star became a 2nd **type arg**), **dict LOST**, error names **`Add`** | both defs | **(b)+(c)+(d)** |
| **`impl` (body)** | **`Int--Add--add` LOST**, defn parse-error | same | both defs | **(c)** |
| **`schema`** | **SILENT — output BYTE-IDENTICAL to control** (`Usr : [Type 0]`, field type `Int*`) | error "schema field `*` is missing a type" | `Usr : [Type 0]` | **(b), glued silent** |
| **`session`** | error `Unknown session type: end*` | **SILENT — identical to control**; star swallowed | `session Ping defined.` | **(b), spaced silent** |
| **`specialize`** | **SILENT** — `idf--Int*--specialized` (wrong specialization key) | error "body must contain a defn form" | `idf--Int--specialized` | **(b), glued silent** |
| **`precedence-group`** | zero output | zero output | zero output | **all three indistinguishable — a count gate reads every leg as a pass** |
| `selection` | parse-error "unexpected token `'*`" | same | `selection Sel … registered.` | (a) |
| `defr` facts (`\|\|`) | "row has 2 terms but arity is 1" | same | `dg : _ defined.` | (a) |
| **`defr` clause goal (`&> = a b*`)** | **SILENT — identical to control**; var named `b*` | arity-error `= expects 2, got 3` | `rr : _ defined.` | **(b), glued silent** |
| `def` | inference-failed | same | `q : Int` | (a) |
| `defn` | defn parse-error | same | (control polluted) | (a) |
| `imports` / `require` | "Cannot find module: `…nat*`" | "Cannot find module: `*`" | *(timed out at 200 s, not measured)* | (b) message only |
| `exports` | zero output | zero output | zero output | indistinguishable |
| **map literal `{:a 1 :b 2*}`** | "requires an even number of elements" | same | `mp : {:a Int :b Int}` | **(a); parity gate** |
| **vector literal `'[1 2*]`** | **SILENT** `vv : ⟨Int Int _ _ -> _⟩` | **SILENT**, identical | `vv : [List Int]` | **NEITHER errors** |
| **angle Sigma `<(x : Nat)* Nat>`** | **WORKS** — `sg : [Sigma Nat Nat]` | **WORKS**, identical | **ERROR** (`Unbound variable x`) | **`*` IS ALREADY THE OPERATOR HERE** |
| angle union `<Int\|String>*` | "Empty type segment in arrow type" | same | `ag : Int \| String` | (a) |
| `defmacro` **template** `[+ $x $x*]` | unbound `$x*` | inference-failed | `useM : Int` | (b) |
| `defmacro` **template** `'[$x 2*]` | **SILENT** `⟨Int Int _ _ -> _⟩` | **SILENT**, identical | `[List Int]` | **NEITHER errors** |
| `impl … where` | "unexpected token after where: `*`" | same | — | (a) |

**Category tallies (VERIFIED)**: (a) identical across all three, loud — **9** · (b) glued ≠ spaced — **9** · (c) **LOSES A DEFINITION** — **2** · (d) **DISPLACES its error to an unrelated form** — **2** · (e) whole-file abort — **ZERO found** (⚠ **this category was subsequently REFUTED** — see §8 and C1/C2).

**Six forms accept a star SILENTLY and emit a different program**: `data` (both legs), `trait` (spaced), `schema` (glued, byte-identical output), `session` (spaced), `specialize` (glued), `defr` clause (glued) — plus the two literal carriers (`'[…]` and the defmacro template over it). None is visible to an error-count gate.

**Axis-1 summary in one line**: a **count-CHANGING** mint is silently absorbed by **at least 15** consumers (every `≥` gate, every exact gate, every parity gate) and breaks the **live Sigma spelling**; a **count-PRESERVING** mint is loudly caught by most preparse gates but **silently mis-defines** in `data` / `trait` / `session` / vector-literal and **structurally cannot be seen** by the andmap-tail and arity-class consumers.

**Three corrections to in-tree claims** (Axis 1 §5, all verified — the first two survived critic re-test, the third is superseded by A4's framing):

1. `macros.rkt`'s claim that *"a plain `'[1 2]` inside a defmacro TEMPLATE is a whole-file abort TODAY"* **does not reproduce at HEAD** — no `$list-literal` is emitted on that surface at all.
2. **The abort mechanism is far narrower than the comment implies.** `datum-subst` defaults an unbound pattern var to itself and **never raises**; the only raise is in the **SPLICE** arm (`$var ...`). So a `pattern-var?` residual aborts a file **only** when the sentinel sits immediately before `...` *and* the macro is invoked.
3. **`defmacro`'s exact-arity gate is currently *shielding* the `pattern-var?` residual** — `$bcast-step` in a template is caught by `(= (length datum) 4)` **before** reaching `pattern-var?`. **A count-CHANGING mint removes that shield**, restoring length 4 and delivering the sentinel straight to `pattern-var?`, where it is not excluded.

**Name-space facts**: `$star` IS TAKEN (`star-symbol?`). `$star-step` IS FREE at HEAD — 3 hits, all comments (`reader-forms.rkt`, `macros.rkt`, `parser.rkt`), no live code. The live refusal machinery already exists (`split-star-lexeme` + `star-not-yet-message`), and the keyword carrier `:c*` has a guided refusal today.

<a id="axis-2"></a>
### Axis 2 — every consumer that switches on shape

**Baseline datums** (`read-all-forms-string`, one command): `m{0*}` → `(m ($select-brace 0 *))` · `x{a}*` → `(x ($select-brace a) *)` · `xs:0*` → `(xs : 0 *)` (**the ω mint did not fire**) · `x.0*` → `(x |.| 0 *)` · `[f x]*` → `((f x) *)` · `database*` → `(database*)` (ONE token) · `r.a*` → `(r ($dot-access a*))` (fused) · `xs:tags*` → `(xs ($bcast-step :tags*))` (fused).

⭐ **The two bare-star-after-a-group bands are not "shattered", they are RE-INTERPRETED.** Since Numerics N6e-E2 made operators first-class values, a bare `*` in expression position is a legal, elaborable term. **Any third design must treat "bare `*` reaching the parser" as a live competing reading, not as a gap.** Nothing in this table aborted the file.

**The head sets.** `reader-forms.rkt` (a deliberate zero-project-require leaf so both `parse-reader.rkt` and `macros.rkt` can read it) defines exactly three lists: `arity2-access-sentinel-heads` (7 heads: `$dot-access $dot-key $nil-dot-access $nil-dot-key $postfix-index $broadcast-access $bcast-step`), `brace-access-sentinel-heads` (2: `$dot-brace $select-brace`), and the orthogonal `subject-preserving-access-heads` (5: `$dot-access $nil-dot-access $postfix-index $bcast-step $select-brace` — a deliberate, documented subset).

**Arity is not a property of a head.** There is no `(head . arity)` table anywhere. It is a property of *which list the head is in*, realised only inside two hand-written predicates: `access-sentinel?` (the FUSION GATE, `macros.rkt`) and `access-sentinel-elem?` (the READER's goal-subject mark, `parse-reader.rkt`). Measured on `access-sentinel?`:

| shape | answer |
|---|---|
| `($dot-access)` | `#f` |
| `($dot-access a)` | `#t` |
| `($dot-access a b)` | `#f` |
| `($select-brace)` | **`#t`** |
| `($select-brace a)` | `#t` |
| `($select-brace a b c)` | `#t` |

⭐ **A 1-element list IS expressible in the existing vocabulary — as a member of the BRACE class.** `($star-step)` head-only would be accepted by *both* consumers today with no new arity class. **Attempt 2's premise ("a bare 1-element list is a shape no consumer has ever seen") is false for the fusion gate and the reader mark** — it is true only of the *fold arms*, which are per-head and destructure with `cadr`. The cost is exact: the brace class is the **any-arity** class, so `($star-step a b c)` would be accepted too.

**What pins the arity discipline**: three test-cases in `tests/test-solve-carrier.rkt`, written as **data-driven loops over the head sets** — so adding `$star-step` to `arity2-access-sentinel-heads` automatically demands `($star-step)` be `#f`, and adding it to the brace list automatically demands `($star-step)` be `#t`. The tests cannot be satisfied by a head whose sentinel-hood is *conditional on its payload*. One of those tests carries its own origin comment: the adversarial verify found `access-sentinel-elem?` testing only the HEAD while `access-sentinel?` tested head AND arity, so a mis-arity sentinel was MARKED but never FOLDED and leaked to elaboration as `Unbound variable $dot-access`.

**The FIFTH obligation** the head sets do not cover: `rewrite-dot-access`'s own **gate** (A7). Non-membership skips the fold for the entire datum list, silently. `ordinal-rekey-shatter?` is the existing precedent for a *sentinel-free* shape needing its own gate clause — the `|.| N ^` scan — and is the closest prior art to gating on a bare `*`.

**The classifier deliverable**: ~59 numbered predicates across `parse-reader.rkt`, `macros.rkt`, `parser.rkt`, `syntax.rkt`, `reader-forms.rkt`, `elaborator.rkt`, answered for three shapes (`*`, `($star-step)`, `($star-step X)`). **Tally: ~40 silent misses vs ~6 loud.** Six sites are drift-immune shape-based tests (`param-group-candidate?`, `goal-head-datum?`, `pol8-sentinel-headed?`, `pol8-goal-pair?`, `reconstitute-path-list`'s element test, and `is-dict-param-name?`) — **all keyed on the literal `$`-prefix character, not on any list. That is the only mechanism in the codebase that has never needed an update when a sentinel was added.**

**`pattern-var?` residual, re-measured**: knows about **20** sentinels; **38** are reader-emittable; **residual = 24**. The residual list: `$bcast-step $clause-sep $compose $decimal-literal $exp-literal $facts-sep $float-literal $list-literal $list-tail $lseq-literal $mixfix $narrow-eq $nat-literal $pipe $pipe-gt $posit-literal $quasiquote $rat-literal $rest $rest-param $set-literal $typed-hole $unquote $vec-literal`. (A wider production-tree sweep yields 87 distinct `$`-symbols and a 67 residual, but that set is polluted by macro *pattern variables* in comments and examples; 38/24 is the defensible figure. `pipeline.md`'s recorded "23 of 33" is the same order — the drift is one added exclusion and a slightly different emitter census.) `(pattern-var? '$star-step)` → **`#t`**.

⭐ **CORRECTION: `pipeline.md`'s consequence claim is FALSE at HEAD.** The template-side abort is gone (commit `446070fc8`). The residual now lives in exactly two places: the `datum-match` PATTERN side (explicitly out of scope by that fix's comment) and the `$var ...` SPLICE branch. **Implication**: the `pattern-var?` obligation is real but is **no longer the whole-file-abort tripwire it is documented as being** — and correspondingly it is now **silent** everywhere except the splice branch, so a miss does not announce itself.

**Two stale in-tree comments found**: `parser.rkt` carries an Attempt-1 leftover claiming *"the ORDINAL carrier arrives as a `$star-step` wrapping this whole step"* — no such mint exists at HEAD. And `xs:0*` does NOT produce a `$bcast-step`; any design assuming the ordinal ω carrier reaches `segment-select-items` as a `$bcast-step` is wrong at HEAD.

<a id="axis-3"></a>
### Axis 3 — every grammar that already claims `*`

**The headline**: there are **SIX distinct meanings of `*` in the language, not two**. They are **fully separable by syntactic context** — but the discriminator lives **entirely in `parser.rkt`, downstream of the type/expression fork**, and there is **no token-level or reader-level discriminator whatsoever**. At the datum layer every non-fused `*` is the identical object: the bare symbol `*`. At the tree layer it is a `symbol`-typed `token-entry` with lexeme `"*"`. *That single fact is why both prior attempts modelled the blast radius wrong.*

| # | Meaning | Surface contexts | Status | Gate in code |
|---|---|---|---|---|
| M1 | **Sigma / product type** | any type position | LIVE | `star-symbol?` (`parser.rkt`) |
| M2 | **Multiplication — the bound value `prologos::core::arithmetic::*`** | any expression position: head (`* 5 6`), argument, bare (`def m := *`), section (`[* _ 2]`), qualified (`base/*`) | LIVE | the `parse-symbol` / keyword-arm path |
| M3 | **Multiplication — infix, precedence `multiplicative`** | **only inside `.( … )`** mixfix | LIVE | `macros.rkt` `(make-op '* '* 'multiplicative)` |
| M4 | **Selection-path wildcard `'*` / globstar `'**`** | `selection … :requires [:a.*]` — **SEXP MODE ONLY** | LIVE but WS-unreachable | `parser.rkt`'s `parse-path-string`, validated in `elaborator.rkt` |
| M5 | **Path-literal wildcard `*` / `**`** | `#p(a.*)`, `#p(a.**)`, `#p(*)` | **RETIRED**, guided refusal | `elaborator.rkt`'s `wildcard-seg?` |
| M6 | **Layer-delete (postfix flatten)** | `database*`, `:database*`, `x.a*` — identifier-fused band only | recognized, **NOT-YET semantics** | `parser.rkt`'s `split-star-lexeme` |
| M7 | **`.*ident` broadcast access** (a retired non-`*` meaning that TOKENIZES `*` and so competes for the character) | `r.*a` | **RETIRED**, guided refusal | reader: `recognize-broadcast-access` (priority 87); parser refusal |

*(The critic added **M8** — `*` as a legal irrefutable pattern. See §8.)*

**Sigma's exhaustive context set.** Call graph: `parse-infix-type` → `parse-arrow-type` → (`segment-has-star?` | `parse-product-type` → `split-on-star` → `parse-type-segment`). `parse-product-type` is reachable **only** from `parse-arrow-type`, reachable **only** from `parse-infix-type`. **Therefore `*` is Sigma if and only if the parser has already entered `parse-infix-type`** — 17 call sites: `{A B : Type}` implicit binders, `unwrap-angle-type`, `parse-dependent-angle`, `parse-angle-binder-group` (×2, INFERRED), `parse-shorthand-dependent-angle` (×3), `fn` return type, `defn` colon return types (×4), `defn` parameter types, `parse-single-type-element` sub-list recursion, and `foreign` capture/return specs (×3, INFERRED — not probed). Plus the `def name : TYPE := body` path.

Properties, all verified: **right-associative** (`Nat * Bool * Nat` → `[Sigma Nat [Sigma Bool Nat]]`) · **binds tighter than `|`** · **looser than application** (`List Nat * Bool` → `[Sigma [List Nat] Bool]`) · works in **every** arrow segment · **the glued spelling is legal and identical** (`<(x : Nat)* Bool>` reads to the same datum as the spaced form).

**Three holes in the Sigma grammar**, each verified: **(a)** `spec` argument positions REFUSE a bare star (`spec g1 Nat * Bool -> Nat` → "Empty type segment in arrow type"; the return segment and a paren group are both fine). **(b)** `data` constructor arg lists treat `*` as the multiply VALUE — `data Box2 := mk2 Nat * Bool` → `mk2 : Nat [prologos::core::arithmetic::* _ _] Bool -> Box2`, **silent wrong meaning, zero errors**. **(c)** `[A * B]` is polysemous by enclosing context — Sigma after `def u2 :`, application after `def h :=`.

**`$star` — a live, unclaimed second spelling.** Exactly one hit in the tree, the acceptor. **Nothing produces `$star`.** But `$` is `ident-start?`, so a user can type it and it works in both WS and sexp.

**A second, DEAD Sigma implementation**: `tree-parser.rkt`'s `parse-angle-group-tree` has its own star detection. Its only external caller is `form-cells.rkt`'s `extract-surfs-from-form-cells`, which has **zero production callers**; `merge-preparse-and-tree-parser` returns `preparse-surfs` verbatim. *Do not budget for it, but do not delete it silently either* — `tools/spine-census.rkt` and several tests still reach `parse-form-tree`.

**The wildcard vocabulary, LIVE vs RETIRED.** M4's `'*` / `'**` are minted from a **string split on `.`** of a single dotted symbol, which requires the path to arrive as ONE symbol. The WS reader shatters it: `":addr.zip"` → `((:addr ($dot-access zip)))` (reconstituted, works) but `":addr.*"` → `((:addr |.| *))` (bare dot token, no sentinel, not reconstituted) and `":addr.**"` → `((:addr ($broadcast-access *)))` (the `.*` recognizer eats it). **Sexp mode reaches it and the arm genuinely fires** — the discriminating control probe: `:addr.nope` is refused ("field :nope not found in schema"), `:addr.*` is accepted, `:nosuch.*` proves the prefix is still validated. **Verdict: M4 is LIVE in sexp, structurally unreachable from WS.**

**`#p( … )` is an opaque reader region** — the ONE non-identifier surface where the reader does not shatter a glued star: `"#p(a.*)"` → `((path :a.*))`, ONE symbol. All three star forms then produce the retirement error.

**`*` as a value — every expression position accepts it**, verified: `def m3 := *` → `m3 : _ _ -> _ defined.` · `* 5 6` → `30 : Int` · `[* 3N 4N]` · `[* _ 2N]` (section) · `.(2 * 3)` · `base/*` (qualified) · **`* : Nat Nat -> Nat`** — a `foreign` block export spec **whose NAME is `*`**. That last is a context the prior attempts almost certainly did not enumerate. **What would change if `*` became a sentinel in expression position: all seven rows.** `int*` etc. are unaffected (they fuse into one identifier token).

**Separable or ambiguous — the answer.** They are separable, and the reader already owns four lexical discriminators (identifier fusion, `.( … )` opacity, `#p( … )` opacity, `.`-adjacency). But **the one genuine ambiguity is stated precisely**: *a bare `*` token, in `[ … ]` or at line level, is M1 or M2 purely by enclosing context, and the reader cannot tell.* `[Nat * Bool]` is Sigma after `def u2 :` and is `[* _ _]` application after `def h :=` — same tokens, same tree, same datum. Restated as a constraint:

> **A reader-level star sentinel cannot be context-correct, because the type/expression fork happens in `parser.rkt`, strictly after the reader and after preparse.**

Axis 3's three structurally distinct routes (superseded by the synthesis's twelve, but the framing is load-bearing): **Route A** — mint anywhere and make `star-symbol?` accept the sentinel (a bare-symbol sentinel costs nothing at the 7 call sites; a **wrapping list** sentinel breaks all 7 — attempt 1's failure seen from the Sigma side). **Route B** — mint only where the reader has a lexical discriminator. **Route C** — do not mint at the reader at all: the shattering carriers all produce a bare `*` sibling in a **known structural neighbourhood**, every one of which is inside `segment-select-items`' input or adjacent to it, i.e. **inside the selection surface, where M1 Sigma provably cannot appear** (no `parse-infix-type` call site is reachable from a selection path). *That is a measured disjointness, not an assumption — and the observation both prior attempts appear to have needed and not had.*

**Corpus figures (Axis 3's denominator)**: 307 `.prologos` files · **71** non-comment lines with a standalone `*` token, of which 21 in `.( … )` mixfix, 4 in `<…>`, 14 at head position, 27 inside `[ … ]` · **306** identifier-glued `*` occurrences (`int*` 150, `rat*` 13, `p64*` 7, `p32*` 7, `p8*` 6, `A*` 5, …) · **1** glued star after a closing delimiter, and it is inside a trailing comment.

<a id="axis-4"></a>
### Axis 4 — the reader's own structure and its invariants

**F1 — There is NO existing mint that consumes a preceding item. Not one.** All seven adjacency/postfix mints either rewrite *themselves* 1→1 or consume *following* tokens. The base always survives as a **left sibling**; fusion happens ~two stages later at preparse's `rewrite-dot-access` fold. **Attempt 1 failed not because it got the details wrong but because it did a thing the reader has never done.**

| Mint | Where minted | Consumes PRECEDING? | Consumes FOLLOWING? | Count |
|---|---|---|---|---|
| `$dot-access` (`x.a`) | **tokenizer** → `token-entry->stx` | **NO** | no (in the lexeme) | 1→1 |
| `$postfix-index` (`x.0`) | **tokenizer** (`dot-ordinal`) | **NO** | no | 1→1 |
| `$dot-key`, `$nil-dot-access`, `$nil-dot-key`, `$broadcast-access` | tokenizer | **NO** | no | 1→1 |
| `$postfix-index` (`xs[0]`) | **grouper**, gated by `adjacent-to-base?` | **NO** | yes (`[` … `]`) | opener+body+closer → 1 |
| `$select-brace` (`x{a}`) | **grouper**, `adjacent-to-base?` | **NO** | yes (`{` … `}`) | → 1 |
| `$dot-brace` (`x.{a}`) | grouper (token-typed, no adjacency test) | **NO** | yes | → 1 |
| `$bcast-step` (`x:0`) | grouper, `bcast-step-trigger?` | **NO** | **no — wraps ITSELF** | 1→1 |
| `$bcast-step` + `$select-brace` (`x:{a}`) | grouper, `bcast-brace-trigger?` | **NO** | yes (`:` + `{` + body + `}`) | **count-CHANGING** |

Consequently **the count problem never arises for any existing mint** — the two count-preserving classes (1→1 self-wrap, delimited-region→1) are the only two the reader has ever used, and `x:{a}` is the *single* count-changing exception, which is why it needed a tree twin and a Q_N3 guard row of its own.

**F2 — Adjacency is NOT destroyed below grouping. `Q8.5 inv 2` is FALSE as stated.**

```
"[f x]*"   READER    elems: (f x) pos=2 span=3 · * pos=6 span=1
           PREPARSED identical — * pos=6
"[f x] *"  READER    elems: (f x) pos=2 span=3 · * pos=7 span=1
           PREPARSED identical — * pos=7
```

What the invariant is *actually* true of: **the pure-DATUM layer** (every `preparse-expand-form` arm runs on stripped output; `strip-with-origin!` records **compound nodes only**, so an ATOM like `*` has no index entry and cannot be traced back to its syntax object); **rebuilt nodes** (`def b := [f x]*` and the spaced form are identical *including positions* after preparse — the `:=` rewrite rebuilds the RHS as one node and the inner `*` position is gone); and **span unreliability** (group sentinels are stamped `(+ start 1) 1` — `x{a}`'s `$select-brace` element reports span=1 for a 3-char group; bracket groups report the span of their *contents*, excluding both brackets). **Accurate restatement**: *byte adjacency survives as long as syntax objects do and no rebuild intervenes; it is unavailable inside any datum-level preparse arm, and it is destroyed by node rebuilding.*

**F3 — `group-items-to-tree`'s output is DISCARDED in production.** It is reached (`merge-preparse-and-tree-parser` → `create-form-cells-from-tree` → `dispatch-form-productions` → `run-form-pipeline` → `advance-pipeline` G(0) → `group-tree-node` → `group-items-to-tree`) but the cells it fills are written to `current-form-cell-map` / `current-spec-cell-map` and **read nowhere** — 2 definitions, 2 writes, and a comment in `driver.rkt` saying exactly this. Its only live consumers are the Q_N3 agreement guard (`tests/test-parse-reader.rkt`), `tools/spine-census.rkt`, and `benchmarks/micro/bench-ppn-track3.rkt`. **A new arm in the tree grouper changes no observable production behaviour today** — a cost *and* a freedom.

**The two groupers, arm by arm**: `group-items` has **24 arms** (measured), `group-items-to-tree` has **13**. Arms the tree layer simply DOES NOT HAVE: `mixfix-lparen`, `dot-lparen`, `rangle`/`$compose`, decimal/posit/float literal, backtick/quasiquote, `$postfix-index` — **six missing arm families**. Arm ORDER is load-bearing at the `lbrace` arm (head-precedence before adjacency) and at the two bcast arms (the `:{` wrap must precede the bare `:` mint).

**Measured divergences**:

| source | datum | tree | verdict |
|---|---|---|---|
| `a < b` | `(a < b)` — **3 items**, `<` as operator | `(line "a" (angle-group "b"))` — **2** | **DIVERGE (count)** |
| `a < b > c` | `(a ($angle-type b) c)` — 3 | 3 | agree |
| `x <{a}` | `(x < ($select-brace a))` — brace is a SELECT | `(angle-group (brace-group "a"))` — plain brace | **DIVERGE (shape)** |
| `a .( b ) c` | `(a ($mixfix b) c)` — 3 | `("a" ".(" "b" "c")` — **4** | **DIVERGE** (pinned by a known-bad test) |
| `x:0` | `(x ($bcast-step :0))` | `("x" ":0")` | agree in COUNT, differ in SHAPE (by design) |
| `x:{a}` | `(x ($bcast-step ($select-brace a)))` | `("x" (bcast-brace-group "a"))` | agree |
| `'[{:a 1}]` | `($list-literal ($brace-params :a 1))` | same | agree |

**Token-level measurement of the shattering carriers** — worse than the brief stated: `x.a*` → the star **FUSES into the dot-access token**; `x:a*` → the star **FUSES** into the keyword token. But `xs:0*` lexes as `xs` + `:`(**colon**) + `0` + `*` so `bcast-step-trigger?` **cannot fire**, and `x.0*` gives a bare `.` symbol so no `$postfix-index` is minted. **Any design that assumes "the base mints normally, then a star arrives as a sibling" is wrong for two of the four bands. The recognizers must be repaired *before* any grouper arm can see a well-formed base.** Conversely the "identifier-headed band works" statement extends further than `database*`: it covers **every ident-tailed segment**.

**A live inconsistency**: `prev-token-not-emitted?` is documented as *"keyed on the PROPERTY — grouping skips this token — and any future skipped token joins by adding it HERE"*, but it is consulted **only by the two bcast triggers**. The older bracket/brace arms never call it, so `"x ,[0]"` → `((x ($postfix-index 0)))` and `"x ,{a}"` → `((x ($select-brace a)))` — postfix minted across a comma. **A new adjacency-based arm must decide *deliberately* which of the two conventions it follows; there is no single convention to inherit.**

**Slice 7's marking layer — five invariants, each measured**:

- **INV-1 — Origin trichotomy.** `paren-origin ⇒ user parens` · `bracket-origin ⇒ user brackets` · **NEITHER ⇒ the reader's own line grouping**. Two otherwise byte-identical datums separate here. `prologos-bracket-origin` has exactly **one production reader**, so any new grouper arm that builds a group node and forgets to stamp it makes that group look like "layout", and `mark-access-subject-region` will descend into it — the exact failure the mark was created to prevent.
- **INV-2 — The arity discipline is the safety property, not the head list.** A head-only test was a live defect: a mis-arity `($dot-access a b c)` got MARKED but never FOLDED, leaking `Unbound variable $dot-access`.
- **INV-3 — `mark-command-goal-subject` NEVER DESCENDS.** It inspects one top-level form's own element list and nothing inside any child group. This is what makes the Q_C scope guard structural rather than accidental.
- **INV-4 — Totality.** `transform-let-blocks-elems` wraps a non-list result because `classify-let-block`'s fail path returns a **syntax object**, and not doing so was a **whole-file abort under a green suite**.
- **INV-5 — `eq?`-preservation / property templating.** Any rebuild uses `(datum->syntax #f kids stx stx)` — the 4th argument is the **property template**. A 3-argument rebuild silently drops `prologos-paren-origin` and degrades an implicit-solve goal to an application.

Note also `mark-binding-values`: POL.9b's `def` / `let` gate requires **exactly ONE element after `:=`**, and an access is structurally two. Measured: `def b := [f x]*` reads as `(def b := (f x) *)` — **five** elements, the star a top-level sibling. That is the same shape slice 7 had to special-case, **and any bare-marker design reproduces it at every binding site.**

**Axis 4's conclusion**: the map says there are **three untried resolution sites, not one** — stage 1 (the tokenizer, which must be touched anyway), stage 6 (the marking layer, never considered by either attempt), and stage 10 (the fold, whose entry `$star-step` was measured unable to satisfy). Stage 5 — the site both attempts chose — is the **only** stage where a count change is simultaneously necessary to express the operator and visible to every downstream validator.

<a id="axis-5"></a>
### Axis 5 — where could a star safely mint (the positive space)

**Three reframing findings**:

1. **Two of the seven carriers never reach a grouper at all.** `xs:0*` and `x.0*` fail at the **TOKENIZER**: the star, being `ident-continue?`, trips the trailing guard in `recognize-colon-annotation` and `recognize-dot-ordinal`, so the whole compound token **declines** and shatters into three. **No grouper-level discriminator can reach them; the carrier is already gone.**
2. **`close-type` does NOT know which group it is inside.** It is the **closer token type**, not the group kind.
3. **The hazard population that killed attempt 1 is ZERO in live code but non-zero in LEGAL SPELLINGS.**

**The `close-type` domain, by exhaustive call-site read** — every recursive call passes a literal: entry `#f` · `indent-open` → `'indent-close` · `lbracket`/`lparen` → `'rbracket`/`'rparen` · `lparen` inside mixfix → `'mixfix-rparen` · `langle` → `'rangle` · **`lbrace` → `'rbrace`** (the sentinel `$select-brace` vs `$brace-params` is computed *immediately before* the call and **not propagated**) · `dot-lbrace` → `'rbrace` · `dot-lparen` → `'mixfix-rparen` · `quote-lbracket` / `at-lbracket` / `tilde-lbracket` → `'rbracket` · `hash-lbrace` → `'rbrace` · unquote → `'rparen`/`'rbracket` · quasiquote → `'rparen`/`'rbracket` · `:{` bcast-brace → `'rbrace`.

**Domain = {`#f`, `'indent-close`, `'rbracket`, `'rparen`, `'mixfix-rparen`, `'rangle`, `'rbrace`}** — 7 values for ~16 group kinds. **`'rbrace` is 5-to-1; `'rbracket` is 6-to-1.**

**Behavioural confirmation** (an angle group placed in each context — `<` opens an angle group under every close-type **except** `'mixfix-rparen`, so if select-brace and map-literal differed in close-type these lines would differ; they do not):

```
x{a <B> c}   -> ((x ($select-brace a ($angle-type B) c)))
{a <B> c}    -> (($brace-params  a ($angle-type B) c))
x.{a <B> c}  -> ((x ($dot-brace  a ($angle-type B) c)))
#{a <B> c}   -> (($set-literal   a ($angle-type B) c))
x:{a <B> c}  -> ((x ($bcast-step ($select-brace a ($angle-type B) c))))
[a <B> c]    -> ((a ($angle-type B) c))
'[a <B> c]   -> (($list-literal a ($angle-type B) c))
(a <B> c)    -> ((a ($angle-type B) c))
x.(a <B> c)  -> ((x ($mixfix a < B > c)))     ← the ONLY divergence
a <B> c      -> ((a ($angle-type B) c))
```

**Answer to "does the grouper know which group it is inside": NO for the distinction that matters.** It knows *mixfix vs everything else*.

**The tree grouper's close-type domain is strictly smaller** — no `'mixfix-rparen`, no `dot-lparen` arm at all — so the ONE distinction the datum grouper's close-type can make does not exist in the tree grouper. **Any close-type-based discriminator would have to be written twice with different vocabularies — the F1b.7g drift class by construction.**

**Corpus scope**: `find . -name '*.prologos' -not -path './.git/*' -not -path './.claude/worktrees/*' -not -name '.#*' | wc -l` → **305**. ⚠ **The naïve count is 961 — `.claude/worktrees/` contains 5 full copies of the tree.** An unfiltered census inflates every figure ~5×.

**Closer-adjacent star — the attempt-1 blast radius** (comments stripped with `sed 's/;;.*//'`):

| pattern | CODE | including comments |
|---|---|---|
| `)*` | **0** | 9 |
| `]*` | **0** | 0 |
| `}*` | **0** | 1 |
| `>*` | **0** | 0 |
| `.N*` / `:N*` | **0** | 0 |

All 9 `)*` comment hits are arithmetic prose (`;; => (5+1)*2 = 12`); the 1 `}*` is `p{N}*` in a numerics tutorial comment.

**…but the legal-spelling hazard is real, and measured at HEAD**: `def T1 := <(x : Nat)* Nat>` and `def T2 := <(x : Nat) * Nat>` both give `[Type 0] defined.` and are identical at the datum layer. **The glued Sigma is live, legal, and indistinguishable from the spaced one below `close-type = 'rangle`.** Meanwhile `bundle Bx := (Add Sub)*` and the spaced twin are **both loud at HEAD** — reproduced-by-absence, the mint is what removed the error.

**The population a mint must not disturb** (Axis 5's figures): spaced bare ` * ` arithmetic — **67** · fused trailing-star identifiers — **171**, of which `int*` **132**.

**Live design-intent sites: exactly ONE in the corpus, and it is the owner's own** — `racket/prologos/lib/examples/foray.prologos`, `values:{0* 1* 2*}` with the comment `;; @[@[1 4 7] @[2 5 8] @[3 6 9]]`. Verified present in HEAD via `git show`.

**Axis 5's positive space, as measured constraints**: `close-type = 'rbrace` is the widest available "inside a brace" signal and it is 5-to-1 ambiguous (it *can* still hit a map literal, a set literal, and a `.{}` sub-block) · **the enclosing sentinel IS computed, one frame up, and thrown away** · the preceding-item shape is clean for exactly the two carriers whose base is a sentinel · a count-preserving sibling mint is precedented and shipping, with its limit documented in-tree (O7) · **the `.N*` / `:N*` band is not a grouper problem** — it is two guard clauses whose comments describe them as protecting `x.0N` / `x.1e3` / `:10abc` · any discriminator must be written for BOTH groupers, whose vocabularies differ.

---

<a id="critique"></a>
## 7. The adversarial completeness critique

The critic's charter was to find what five parallel axes missed. It found five misses, re-tested nine claims (**three census claims WRONG**), adjudicated four contradictions, and made one prediction about the third design.

<a id="miss-1"></a>
### MISS 1 — Pattern position: a SEVENTH meaning of `*`

Axis 3 enumerated six meanings plus retired M7. It missed one that is **live, silent, and semantically load-bearing**:

> **M8 — `*` is a legal irrefutable (variable/wildcard) PATTERN, in both `match` arms and `defn` clause patterns, in both WS and sexp mode, today, with zero errors.**

```
def a := match q | * -> 7          → a : Int defined.
defn f | * -> 42   / [f 9]         → f : Int -> Int defined.
(match 5 (* -> 7))   [sexp]        → a : Int defined.
```

Three consequences no axis states:

**(a)** A count-PRESERVING star in a pattern **SILENTLY DELETES A LATER ARM** (constraint A1). The datum is intact and `split-match-arms-on-pipe` preserves both arms; the second vanishes downstream in `compile-match-tree`, and the only error reported is about inference. *This is precisely attempt 2's failure mode (an extra sibling) in a consumer no axis listed.* The fused spelling `2*` behaves identically.

**(b)** **The identifier-fusion band — the one the brief calls "WORKS today" — is exactly the band that silently corrupts pattern matching** (constraint B1).

**(c)** The corpus has **ZERO** bare-star pattern arms. So M8 is unexercised but grammatically live: *a design that refuses bare `*` breaks a spelling that compiles today, and a design that mints on it silently changes a wildcard into a sentinel.*

<a id="miss-2"></a>
### MISS 2 — Two whole-file aborts at HEAD (Axis 1's category (e) is FALSE, twice)

Axis 1 declared *"whole-file abort — ZERO found at HEAD"* and argued structurally that the only raise is `datum-subst`'s splice branch. **Both halves are false.** Neither abort involves a star mint and neither is on the `pattern-var?` path. **Abort A** = `compile-match-tree` on a multi-form literal pattern arm (constraint C2), reproducing in sexp mode. **Abort B** = `syntax->datum` on a `$preparse-error` datum inside the Phase-5b `partition` (constraint C1). The critic notes: *"the structural claim is the more damaging error: it would license a design to skip abort-testing entirely."*

The critic also observed that **Axis 1's own probe methodology is structurally blind to Abort B**, because the abort needs a *second* form after the erroring one — a point the synthesis then sharpened to the real precondition (a *successful* `data`/`trait`/`impl` in the same file, which is what leaves `generated-decl-names` non-empty).

<a id="miss-3"></a>
### MISS 3 — Seven more carriers in the "silent arithmetic misread" class; the population is 11, not 4

All giving `Could not infer type [<subject> [prologos::core::arithmetic::* ?m ?m]]`:

| carrier | datum |
|---|---|
| `.(1 + 2)*` | `(($mixfix 1 + 2) *)` — **a direct collision with M3, uncensused** |
| `'[1 2]*` | `(($list-literal 1 2) *)` |
| `@[1 2]*` | `(($vec-literal 1 2) *)` |
| `#{1 2}*` | `(($set-literal 1 2) *)` |
| `{:a 1}*` | `(($brace-params …) *)` |
| `` `[a 1]* `` | `(($quasiquote …) *)` |
| `#p(a)*` | `((path :a) *)` |

`#p(a)*` is the sharp one: Axis 3 established that `#p( … )` is the one surface where a glued star survives. **But a star *after the closing paren* shatters like everything else. `#p( … )` is not a uniform exception — it is opaque only *inside*.**

<a id="miss-4"></a>
### MISS 4 — A select block contains BOTH bands simultaneously

```
cfg{a* b}          => (cfg ($select-brace a* b))                         ;; 2 items, star FUSED
values:{0* 1* 2*}  => (values ($bcast-step ($select-brace 0 * 1 * 2 *))) ;; 6 items for 3 steps
```

An **ident** step fuses; a **numeric** step shatters. `segment-select-items` therefore already receives item lists whose length is not a function of the step count, and the two bands are interleavable inside one block. **No axis states this as a rule.**

<a id="miss-5"></a>
### MISS 5 — `compat-tokenize-string` is exported as `tokenize-string` and RAISES

`(error 'prologos-reader "Unexpected character: .")`, reached whenever a standalone `.` symbol token appears — **exactly what `x.0*` produces**. `grep -rn compat-tokenize-string` → **zero production callers**, tests only. Dead in production, but exported under the inviting name `tokenize-string`; any tool built on it turns `x.0*` into a hard raise.

<a id="retests"></a>
### Re-tested claims (9), and the three that were WRONG

| # | Claim | Source | Verdict |
|---|---|---|---|
| 1 | "8 `star-symbol?` call sites" | Axis 1 | ❌ **WRONG.** 8 lines = **1 definition + 7 call sites**. **Axis 3's "7" is correct.** Load-bearing: a route's cost is 7 pattern-matching sites, not 8. |
| 2 | "whole-file abort — ZERO found at HEAD" + the structural argument | Axis 1 | ❌ **WRONG, twice.** See MISS 2. |
| 3 | "Glued star after a closing delimiter — **1**, inside a trailing comment" | Axis 3 | ❌ **WRONG.** `)*` = **9** raw (all comments); `}*` = **1** raw (comment); `]*` `>*` = 0. Code-only: **0** for all four — **Axis 5's figure, and Axis 5 is right.** |
| 4 | `pattern-var?` residual = 24 of 38, exclusions = 20 | Axis 2 | ✅ **VERIFIED EXACTLY**, command re-run. (Axis 1's quoted "23 of 33" is `pipeline.md`'s stale figure, correctly flagged as drift by Axis 2.) |
| 5 | `$star` is a live, unclaimed Sigma spelling reachable from user source | Axis 3 | ✅ **VERIFIED end-to-end** in both `<…>` and bare form. |
| 6 | `pol8-bare-head?` accepts a bare star as a goal head, 0 errors | Axis 2 | ✅ **VERIFIED.** |
| 7 | `schema … :age Int*` output is byte-identical to the control | Axis 1 | ✅ **VERIFIED.** Glued → same as control; spaced → loud "schema field `*` is missing a type". |
| 8 | `current-form-cell-map` / `current-spec-cell-map` are write-only | Axis 4 | ✅ **VERIFIED.** 4 non-test hits: 2 definitions, 2 writes, plus a comment saying exactly this. |
| 9 | `process-*` handler count = 15, of which 11 are top-level validators | Axis 1 | ✅ **VERIFIED.** |

<a id="adjudications"></a>
### Contradictions adjudicated

| Contradiction | Adjudication |
|---|---|
| **Axis 4**: "`x.0*` — tokenizer **RAISES** `Unexpected character: .` on the compat path" vs **Axis 5**: "`recognize-dot-ordinal` declines cleanly; shatters into three" | **BOTH TRUE, DIFFERENT ENTRY POINTS — and Axis 5 is the production one.** `read-all-forms-string "x.0*"` → `((x \|.\| 0 *))`, **no raise**. The raise exists only inside `compat-tokenize-string`, which has zero production callers. Axis 4's hedge ("on the compat path") was accurate but under-qualified: it reads as a production hazard and is not one. |
| **Axis 3**: corpus = 307 files vs **Axis 5**: 305 | **Non-substantive.** `diff` of the two file lists → exactly 2 entries, both emacs autosave files. **Axis 5's `-not -name '.#*'` is the correct filter.** Both agree on the ~5× worktree inflation trap. |
| **Axis 1** lists `x{a}*` as producing a parse error vs **Axis 2/4/5**: silent misread as first-class arithmetic | **Axis 2/4/5 correct.** Axis 1's row appears to conflate the in-block spelling `m{0*}` (which *does* reach the guided refusal) with the after-block spelling. |
| **Axis 1 §5** vs **Axis 2 §3**: is `pipeline.md`'s "`'[1 2]` in a `defmacro` template is a whole-file abort TODAY" false? | **Both correct, and the critic confirms the direction** — with an irony: **the doc's claim is false for the reason they give, and true in spirit for a reason neither found.** `defmacro` templates no longer abort, but the file *does* abort via `compile-match-tree` and via the Phase-5b partition. **The class `pipeline.md` warns about is live; its named instance is not.** |

<a id="prediction"></a>
### What the critic predicted a third design would still get wrong

> **It will model the blast radius as "the reader plus every consumer that counts items or switches on shape" — the union of all five axes — and will still miss that `*` IS ALREADY A BINDING PATTERN, so the mint changes the meaning of code that currently compiles, in a surface where the failure is a SILENTLY DELETED CLAUSE rather than an error.**

The reasoning: every surface the census maps is an **expression-or-type** surface. **Pattern position is neither, and it is the one place in the language where an unrecognised token is not an error but a binder** — the pattern compiler's default is "this is a variable", so a star that fails to be recognised as a sentinel does not fall through to a guided refusal; it becomes an irrefutable catch-all that eats every subsequent arm and, in the `defn` case, destroys the definition with a diagnostic that names spelling and imports.

*"That is worse than either prior failure mode. Attempt 1 lost a definition and was caught by a revert; attempt 2 was refuted on paper. This one passes a green suite, passes an error-count gate, passes a full-output gate on any file that does not exercise the affected arm, and passes the acceptance battery — because the corpus has 0 bare-star pattern arms today, so nothing in the tree would move."*

The second-order form: the design will pick its verification gate from the census's own instrument — the `before` / form / `after` triple — which is structurally blind to the abort seam.

<a id="disagreements"></a>
### 7.5 Where the sources disagree (a reviewer should check these)

| Item | Axis 3 | Axis 5 | Synthesis (adjudicated) |
|---|---|---|---|
| corpus `.prologos` file count | 307 | **305** | **305** — Axis 5's `.#*` filter is correct |
| `star-symbol?` call sites | **7** (Axis 1 said 8) | — | **7 call sites + 1 definition** |
| spaced bare `*` code sites | 71 *non-comment LINES with a standalone `*` token* | **67** *(code only)* | **76** **[V]** |
| fused trailing-star idents | **306** *occurrences incl. comments, all files* (`int*` 150) | **171** *(code only; `int*` 132)* | **170** (132 `int*`) **[V]** |
| closer-adjacent glued star | **1** (in a comment) | **0** code / 9+1 raw | **0** code for all four patterns; 9 `)*` + 1 `}*` raw |
| `split-star-lexeme` call sites | routing at 3 sites | star arms at 3 sites | **5 call sites** (Axis 1 and the synthesis); **Axis 4 says 4** (3 routing + the segmentation entry) |
| discriminator numbering | — | D1–D11 (`close-type` = D1) | D1–D16 + D2′ (`close-type` = D2) — **the two schemes are not aligned** |
| number of approaches | — | — | header says "Eleven", **twelve are enumerated** |

The three count rows above are the ones to re-measure before citing: Axis 3, Axis 5 and the synthesis used **different denominators** (all-occurrences-including-comments vs code-only; 307-file vs 305-file corpus) and none of the three states a shared command. The synthesis's figures are tagged **[V]** (re-run that session) and are the most recent, but the underlying command is not recorded in the artifact.

---

<a id="method"></a>
## 8. Method findings

Lessons the census produced *about measurement*, each earned by a measurement in it. The synthesis states them as **gate obligations any attempt-3 verification must carry**; they generalize past the star.

1. **⭐ A probe you are already running may be the measurement you need, read wrongly.** The reader erases glued-vs-spaced for every non-identifier carrier, so in any probe triple the **SPACED leg IS the count-preserving simulation** and the **CONTROL leg IS the count-changing one**. Attempt 1's defect was measurable *before it was written* — by the census's own control leg. (Axis 1 §0.)
2. **Every probe file must contain a SUCCESSFUL `data` / `trait` / `impl`.** Without one, `generated-decl-names` is empty, the Phase-5b fast path is taken, and **C1 is invisible** — which is exactly how five parallel censuses all reported "zero aborts". ⭐ **A conditional gate is how a defect survives N censuses.**
3. **Assert on FULL OUTPUT, never on an error count.** `precedence-group` and `exports` produce zero output in all three legs (glued / spaced / control) — a count gate reads every leg as a pass.
4. **Probe `match` and `defn`-clause position for every carrier, asserting the ARM COUNT of the elaborated `reduce`** — not the error count. Arm deletion is silent.
5. **The star-free CONTROL can be the leg that detonates.** `| 2 3 ->` aborts where `| 2 * ->` does not. **An A/B that assumes the control is safe will mis-attribute.**
6. **Diff the two groupers on the divergence battery** (`a < b`, `x <{a}`, `a .(b) c`, `>>`, backtick, literals) — the Q_N3 guard covers only what it enumerates.
7. **Run the sexp leg** for anything touching `star-symbol?` or `select-step-kind` — C2 reproduces in sexp, and the sexp-only selection wildcards live only there.
8. **A grep-shaped enumeration under-counts when the thing being counted has no uniform shape.** `grep "^(define (process-"` finds 15 handlers where there are **24 form-level consumers** — nine have no `process-*` function at all. The earlier sweep's undercount *is* the capture gap.
9. **Exclude worktrees from every corpus count.** `.claude/worktrees/` holds 5 full copies of the tree; the naïve file count is 961 against a true 305 — an unfiltered census inflates every figure ~5×. Also filter emacs autosaves (`.#*`), which account for the 307-vs-305 discrepancy.
10. **Do not budget against a hazard HEAD has already retired.** `pipeline.md`'s documented `defmacro`-template abort does not reproduce; `pattern-var?`'s residual is now **silent**, not loud — so a miss no longer announces itself, which is a *different* and quieter hazard than the one documented.
11. **A stale in-tree comment describing a planned mechanism reads as documentation of shipped code.** `$star-step` appears only in three comments as a *planned* name with a deferred ruling attached; `parser.rkt` still carries an Attempt-1 comment asserting a mint that does not exist.
12. **Two entry points can both be right.** The `x.0*` raise/decline contradiction resolved as *both true, different entry points* — and the production one is the decline. A hedge like "on the compat path" is accurate but under-qualified if the reader will take it as a production hazard.

---

<a id="limits"></a>
## 9. What the census did NOT cover (its own stated gaps)

Each of these was flagged by the source that would have owned it, rather than guessed at.

**Scope-wide**:
- **The full test suite was not run** by any agent, and no agent measured a suite delta.
- **Only `*` was censused.** R9 ("a different spelling") notes explicitly: *"which characters are genuinely unclaimed — no census exists."*
- **No mechanism is proposed anywhere.** Axis 5: *"Not designed here, deliberately. Every row above is a measurement or a code-read."*

**Axis 3's flags**:
- The three `foreign`-block `parse-infix-type` sites are **INFERRED**-reachable for Sigma; a `foreign` capture spec with a `*` was not probed.
- `trait` / `impl` method signatures and `where` constraint bodies were **not probed** for `*`. They are not among the 17 `parse-infix-type` sites, which *suggests* they route through `spec`-style injection (so the `spec` hole would apply) — **UNVERIFIED**.
- `bundle B1 := (Add Sub)` produced **no output line at all**; Axis 3 could not tell whether `bundle` is silent-on-success or silently failing, so it has **no measurement of attempt 1's bundle casualty** beyond the prompt's account. (Axis 5 later measured the loud error at HEAD for both legs.)
- `**` outside `.( … )` is `Unbound variable **`; the mixfix `pow` entry exists in the table but has no bound implementation reachable from `.( 2 ** 3 )` either. **Not chased.**

**Axis 4's flags**:
- The F3 call chain (`dispatch-form-productions` → `group-items-to-tree`) is **[I]** from code reading — no live `process-file` was instrumented to confirm the tree grouper executes. The *"read nowhere"* half is **[V]** by grep.
- The `xs:0*` / `x.0*` recognizer behaviour is **[V]** at the token level, but Axis 4 **did not read the recognizer source** to confirm *why* `:0*` fails to classify as `colon-annotation`. (Axis 5 supplied the mechanism: the `[(and c (ident-continue? c)) #f]` trailing guard.)
- Axis 4 **did not count corpus occurrences of `*` in selection position**.

**Axis 2's flags**:
- `elaborator.rkt`'s `is-dict-param-name?` routing is **VERIFIED-by-read**; that `parse-dict-param-name` then returns `#f` is **INFERRED**.

**Axis 1's flags**:
- The `imports` / `require` CONTROL leg **timed out at 200 s and was not measured**.
- `solver` / `flatten-ws-kv-pairs`, `selection`'s positional arm, and the vector-literal count-changing case are marked **INFERRED (not probed)** in the deliverable table.

**Open at the synthesis (rulings, not derivable from measurement).** The synthesis closed with ten questions for the owner. Two were subsequently ruled (see §5's note on Q_U30 / Q_U31) and one became a DEFERRED item; the rest stand as recorded:

| # | Question |
|---|---|
| Q1 | Is the glued Sigma spelling `<(x : Nat)* Nat>` DEFENDED or REFUSED? Legal, elaborates correctly, **0 corpus sites**; attempt 1's headline casualty. *(→ ruled: refused, Q_U31.)* |
| Q2 | Is bare `*` as a **PATTERN** defended, or refused? Legal today, 0 corpus sites, source of the worst failure in the census. Refusing it converts a silent-wrong-answer into a loud error **independently of any star design**. |
| Q3 | Is bare `*` as a **VALUE** defended in every position? 76 spaced arithmetic sites say yes for expressions — but it is also a legal `foreign` export declaration name, a qualified reference (`base/*`), and a legal relational goal head. All four, or only the arithmetic value? |
| Q4 | Must all seven carriers be supported, or is the IN-BLOCK spelling the language? **This single ruling sizes every option.** *(→ ruled: all seven, Q_U30.)* |
| Q5 | Does the abort seam get fixed as a PREREQUISITE, as its own DEFERRED item, or inside this design? Star-adjacent, not star-specific; 139/305 files susceptible. *(→ DEFERRED 102, fixed at `41458174`.)* |
| Q6 | Which layer owns `.N*` / `:N*`? Repair the two recognizers, or rule these two carriers out of scope? *(→ repair, Q_U30.)* |
| Q7 | Is the tree-grouper twin REQUIRED, or is the Q_N3 agreement guard the only obligation? Its output is discarded in production and it already diverges in six arm families. |
| Q8 | `$star` is a live, undocumented, zero-producer Sigma spelling reachable from user source. Defended, retired, or repurposed? |
| Q9 | Does the design owe SEXP mode anything? The sexp-only selection wildcards are unreachable from WS but genuinely fire in sexp. |
| Q10 | Is a lying diagnostic acceptable in the interim? Fixing `m{0*}`'s message is independent of any mint. |

---

<a id="files"></a>
## Appendix — repo surfaces the census read

All read-only, all under `/Users/avanti/dev/projects/prologos/racket/prologos/` unless noted. **Anchor on the symbol names, not on coordinates — they drift.**

| File | Surfaces named by the census |
|---|---|
| `parse-reader.rkt` | `tokenize-char-rrb` · `ident-start?` / `ident-continue?` · `recognize-dot-access` · `recognize-dot-ordinal` · `recognize-colon-annotation` · `recognize-broadcast-access` · `#p(` opacity · `compat-tokenize-string` (+ its raise) · `read-to-tree` / `parse-string-to-cells` · `flatten-with-boundaries` · **`group-items`** · `adjacent-to-base?` · `bcast-step-trigger?` · `bcast-brace-trigger?` · `prev-token-not-emitted?` · `prev-token-reader-form-head?` · `is-postfix?` · `token-entry->stx` · `$goal-rhs-wrap` · `access-sentinel-elem?` · `mark-access-subject-run` / `-region` · `mark-binding-values` · `mark-command-goal-subject` · `mark-let-goal-rhs` · `transform-let-blocks-elems` · `tree-node->stx-elements` · `maybe-rewrite-infix-eq-stx` · `read-all-forms-from-tree` · `param-group-candidate?` · `bcast-step-stx?` · `stx-group?` |
| `macros.rkt` | `preparse-expand-all` (+ the `$preparse-error` emit and the Phase-5b `partition`) · the 15 `process-*` handlers + the 9 inline arms · `pattern-var?` · `datum-subst` / `datum-subst-list` · `flatten-ws-kv-pairs` · `parse-schema-fields` · `expand-let-impl` / `expand-let-bracket-bindings` · `access-sentinel?` (+ the `$star-step` post-mortem) · **`rewrite-dot-access`** + its `ormap` gate · `ordinal-rekey-shatter?` · `dot-access?` / `dot-key?` / `nil-dot-*?` / `bcast-step?` / `postfix-index?` / `broadcast-access?` / `dot-brace?` / `select-brace?` · `reconstitute-selection-paths` / `reconstitute-path-list` · `builtin-operators` (`'*` multiplicative, `'**` → pow) · `pratt-parse` / `expand-mixfix-form` · **`compile-match-tree`** · the grouped-star spec flatten |
| `parser.rkt` | **`star-symbol?`** (7 call sites) · `parse-infix-type` (17 call sites) · `parse-arrow-type` · `parse-product-type` · `split-on-star` · `parse-type-segment` · `unwrap-angle-type` · `parse-dependent-angle` · `parse-shorthand-dependent-angle` · `split-star-lexeme` · `star-sym?` · `star-mid-lexeme-message` · `star-not-yet-message` · **`segment-select-items`** (24 arms + guided `else`) · `parse-list` head dispatch · `validate-selection-paths` / `parse-path-string` · `goal-head-datum?` · `pol8-sentinel-headed?` / `pol8-goal-pair?` / **`pol8-bare-head?`** · `kw-sym?` / `re-key-sym?` / `plain-key?` / `caret-ish?` / `dissolve-step?` / `branch-problem` / `head-of` · `split-match-arms-on-pipe` · `parse-match-pattern-arm` · `parse-reduce` |
| `reader-forms.rkt` | `arity2-access-sentinel-heads` (7) · `brace-access-sentinel-heads` (2) · `subject-preserving-access-heads` (5) · the `$star-step` deferred-ruling comment · `reader-form-head?` · `private-form-base` · `colon-symbol?` / `digit-headed-colon-symbol?` / `fused-type-annot?` / `split-glued-name-datum` |
| `syntax.rkt` | `select-step-kind` (+ `/display`, `-unhandled`) · `select-key-step?` / `select-sub-step?` / `select-ord-step?` / `select-bcast-step?` · `select-step-name` / `-cont` / `-output-name` · `select-branch-keyless?` / `-collapse` / `-top-keys` · `select-sort?` / `select-sort-unhandled` |
| `surface-rewrite.rkt` | `group-items-to-tree` (13 arms) |
| `elaborator.rkt` | `wildcard-seg?` + its retirement message · `path-subsumes?` wildcard arms · selection wildcard validation · `is-dict-param-name?` |
| `driver.rkt` | `read-all-syntax-ws` · `refine-tag` · `merge-preparse-and-tree-parser` · `current-form-cell-map` / `current-spec-cell-map` (write-only) · `process-file-inner` |
| `tree-parser.rkt` | `parse-angle-group-tree` (dead Sigma implementation) · `builtin-binary-ops` |
| `form-cells.rkt` | `extract-surfs-from-form-cells` / `parse-form-tree` (zero production callers) |
| `namespace.rkt` | `process-exports` · `process-imports-spec` |
| `lib/examples/foreign.prologos` | the `* : Nat Nat -> Nat` export spec; `base/*` |
| `lib/examples/foray.prologos` | `values:{0* 1* 2*}` — the one live design-intent site |
| `tests/test-solve-carrier.rkt` | the three data-driven head-set / arity-discipline test cases |
| `tests/test-path-selection.rkt` | the attempt-1 revert record |
| `tests/test-parse-reader.rkt` | the Q_N3 grouper-agreement guard; the known-bad `.( )` divergence test |
