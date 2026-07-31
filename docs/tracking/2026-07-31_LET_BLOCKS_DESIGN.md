# LET blocks — multi-binding `let` layout

**Status**: **COMPLETE** — P0 ✅ `0effba9c` · P1 ✅ `49f51c14` · P2 ✅ `e8a41a9a` · P3 ✅ `940c1c16` · P4 ✅ `feb79740` · X.close ✅ (docs + sweep + PIR-lite below). Owner-requested language polish (2026-07-31): the
nested-only `let` layout "was never intended to be how they function."

**Acceptance file**: `examples/2026-07-31-let-blocks.prologos` (Phase 0; target
sections commented, uncommented per phase).

## 0. The target surface (owner examples, verbatim intent)

```prologos
;; aligned bindings, body at intermediate column     ;; fused var:Type
let x 4                                              let x:Int 4
    y 5                                                  y:Int 5
    z [+ x y]                                          body
  z

;; sibling lets form one scope                       ;; := optional throughout
let x 4                                              let x := 4
let y 5                                                  y := 5
let z [+ x y]                                          body
  z
```

## 1. Owner rulings (2026-07-31)

1. **Strict body column discipline.** Bindings must align with each other; the
   body sits STRICTLY between the `let` column and the binding column. Anything
   else is a loud per-command error naming both columns (the `&>` diagnostic
   style, Rel T1 POL.8). Rationale: the lenient alternative silently reads a
   forgotten body as "apply `y` to `5`" — this codebase's history says every
   lenient layout rule became a silent-wrong-answer factory.
2. **Mixed spellings in one block allowed** (`x 4` and `y := 5` may coexist).
3. **Sexp glued `x:Int` splits** — `(let x:Int 4 body)` becomes the annotated
   binding, matching defn's sexp path (POL.6), rather than binding a variable
   literally named `x:Int` (today's behavior — a silent WS/sexp divergence
   otherwise).

## 2. Grounding (workflow `wf_86f24cf1-4b8` at `13cce230`, 6 agents; all cruxes
independently re-verified — coordinates drift, re-grep)

**One root cause, four symptoms — inconsistent binding normalization across
three consumers:**
- `split-last-let` FABRICATES `:=` for the legacy 3-element shape
  (macros.rkt:2408) while `extract-let-binding-tokens` returns tokens verbatim
  (:2388); `parse-assign-bindings` then demands `:=` everywhere (:4878). The
  merged sibling stream is mixed by construction → the no-`:=` chain raises.
- `split-at-next-assign-binding`'s next-binding predicate requires a BARE SYMBOL
  followed by `:=`/`:` (:4952-4958); an aligned continuation group `(y := 5)` is
  a LIST → swallowed into the previous value, y silently never binds
  (accepted-then-broken).
- The aligned/fused shapes have no branch at all → `else` raise (:4791).
- **All 13 failure sites are raw `(error 'let …)` raises** = whole-file aborts
  (no handler on the preparse path; probe: even commands BEFORE the bad let
  vanish).

**Columns are PROVEN GONE at `expand-let`** — `syntax->datum` strips srclocs at
five sites (macros.rkt:2740/:2759/:2805/:2841/:2864) before dispatch, and shape
alone cannot split bindings from body (`(z (+ x y))` vs `(+ a z)` are
shape-identical; bodyless `(let x 4 (y 5))` undecidable). The reader HAS the
columns (`wrap-stx-list`, parse-reader.rkt:2469-2476). So the aligned form's
split happens at the READER/STX layer (prior art:
`flatten-with-boundaries/spec`, parse-reader.rkt:2496-2498), emitting a
loc-checked sentinel. The `:=` forms need no columns.

**Dual spine — and the "working" variant is ALREADY broken on one of them.**
`merge-form` (driver.rkt:2468-2490) picks the TREE parser for unspecced forms;
tree-parser has an independent let-chain (tree-parser.rkt:950-982) that requires
`:=` and DROPS type annotations (`binder-info name #f (surf-hole loc)`, :978).
**Probe 2026-07-31 (main session, closing the grounding's own flagged gap): in
an UNSPECCED defn, the `:=` sibling chain AND the single `:=` form BOTH FAIL**
(typing dies on the tree spine's output — the unannotated-param hint + Unbound
variable). Issue #21's "works" evidence and all facet probes were
spec-annotated. Filed in DEFERRED; every phase here validates BOTH spines, and
the acceptance file says why its defns all carry specs.

**Internal producers pin the legacy branches** (may not change meaning): the
schema `:check` wrap emits the 3-element no-`:=` shape (macros.rkt:1418 —
depends on Branch 3); `do` (:5036), transducer map step (:5802),
`with-transient` (:6460) emit Branch-2/bracket shapes. Byte-exact expansion pins:
test-defmacro.rkt:133-227, test-let-arrow-syntax.rkt:278-281,
test-let-multiline-ws.rkt:49-67 — new passes must be byte-transparent for
existing inputs.

**Other verified constraints:**
- Everything lowers onto `let-bindings->nested-fn` (macros.rkt:4855-4862), the
  single desugar point — which is what makes sequential (`let*`) scoping
  STRUCTURAL (each value nests inside prior binders; depth +1 per binding). A
  curried shape would silently produce parallel scope.
- The aligned TOP-LEVEL shape `(let x := 4 (y := 5))` BYPASSES the guided
  "use `def` instead" guard (its trigger requires exactly one token after `:=`,
  macros.rkt:4739) — the guard extends alongside the aligned work.
- Fused recognizer placement: parser.rkt requires macros.rkt (parser.rkt:16), so
  macros.rkt can NEVER import `fused-type-annot?` from parser.rkt. It lands in
  reader-forms.rkt (the zero-require leaf macros.rkt already requires) or
  macros.rkt itself; the chained-annotation reject (`x :T1 :T2` → reserve for
  UCS) becomes a SHARED predicate rather than a fourth inline copy
  (parser.rkt:3980-3987, :5025-5032 are the existing two).
- `preprocess-let-infix-eq` (macros.rkt:2306-2320) is GROUP-BLIND and runs only
  on the single-let merge branch — aligned groups reaching it with infix-`=`
  values get swallowed into the `=` rhs. Aligned normalization must run before
  it or make it group-aware.
- A new marker head owes: `pattern-var?` exclusion (macros.rkt:1157 block — the
  `$dot-brace` comment there records the whole-file-abort failure mode of
  omitting it) + a parser dispatch arm with the LOAD-BEARING `(pair? args)`
  guard (parser.rkt:920 region).
- Census: 36 live let expressions (lib+examples); sibling `:=` blocks dominate
  (21 let-lines / 11 blocks). Zero `.golden` files; tests/*.prologos have no let.

## 3. Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| P0 | Acceptance file: 5 working variants + 2 context cases pinned; P2/P3/P4 targets commented | ✅ | `examples/2026-07-31-let-blocks.prologos`, --check exit 0, 14 markers |
| P1 | All 13 `(error 'let …)` raises → per-command parse-error VALUES (`$let-error` marker) | ✅ | `49f51c14` — suite 9497/476/0; 2 check-exn pins flipped WITH the behavior; the spec-c batch collision surfaced and was renamed away (leak filed) |
| P2 | Sibling no-`:=` chains (form 3): uniform `:=` synthesis at the merge seam; tree spine defers on let heads | ✅ | `e8a41a9a` — suite 9507/476/0; acceptance §C live (20 markers); the P0-era "unspecced BROKEN" filing WITHDRAWN (it was i70 — §7) |
| P3 | Aligned blocks (forms 1/5): reader-layer `$let-block` regrouping, STRICT columns | ✅ | `940c1c16` — suite 9513/476/0; acceptance §D live (26 markers); the gate caught a PROPERTIES-DROP bug pre-commit (POL.9 paren-origin) |
| P4 | Fused `var:Type` binders (form 2): WS pair + sexp glued split; MULTI-LINE VALUES (owner add-on: the fold + the absorb) | ✅ | `feb79740` — suite 9520/476/0; acceptance §E live (34 markers); an infinite loop caught at the preparse seam (fused-type-annot? accepted bare `:`/`:=`) |
| X.close | prologos-syntax.md § let (discharges issue #21's doc obligation) + DEFERRED sweep + roadmap row + PIR-lite | ✅ | 3 residuals filed; GitHub #21 close is the OWNER's call (outward-facing) |

## 4. P1 design (mini-design)

**Mechanism**: dedicated exn struct + one conversion boundary, then the marker
precedent.

- `(struct exn:let-syntax exn:fail ())` + `(let-syntax-error fmt …)` raise
  helper; all 13 sites convert `(error 'let …)` → `(let-syntax-error …)`
  (message text preserved minus the doubled `let:` prefix).
- `expand-let` wraps its body: `exn:let-syntax?` → `($let-error "msg")` marker.
  ONE seam — the 13 sites live in recursive helpers whose return values are
  consumed as data (threading marker returns through them is ~5 functions of
  churn for no benefit). The handler catches ONLY the dedicated struct: a
  genuine Racket-level bug (list-ref etc.) still crashes loudly rather than
  masquerading as a let syntax error. Named for the VAG: this is an error
  CHANNEL at the family's single entry, not a defensive guard.
- `$let-error` marker: `pattern-var?` exclusion + parser arm → `parse-error`
  VALUE with the message, loc supplied at parse time (the retired-selection
  seat, parser.rkt:920 region, `(pair? args)` guard included).

**Drift risks named before coding**:
1. A raise site NOT under `expand-let`'s dynamic extent would escape the
   boundary — verified: all 13 are beneath it (`merge-sibling-lets` and its
   helpers raise nowhere).
2. The marker inside a NESTED position (let inside defn body) must still
   convert — the parser arm lives in the expression dispatch, any depth; pinned
   by test.
3. Containment is the point: commands before AND after the bad let must report.
   Pinned (the `f51bda2b` containment-pin pattern).
4. `check-stdout-clean` gate: the marker must never print as a struct.

## 5. P1 close notes

- Landed as designed; all four drift risks held (all 13 sites under the
  boundary; the marker converts at depth; containment pinned; stdout clean).
- **Two pre-existing pins flipped WITH the behavior** (test-defmacro "wrong
  arity", test-let-multiline-ws "no body still raises") — both check-exn'd the
  raise the phase exists to remove. Flipped to pin the marker/error-value.
- **The gate caught a batch-worker collision**: `spec c` (added by this branch's
  own 6d4e8c73) leaked across files in a worker and collided with
  test-new-lattice-cell's `def c`. Renamed to `hconsume`; the LEAK (cell-backed
  spec registry on the shared persistent net-box, not covered by the parameter
  snapshot) is filed in DEFERRED with the mechanism half-diagnosed.
- The unspecced-defn tree-spine breakage found at P0 grounding is now formally
  filed in DEFERRED and OWNED BY P2.

## 6. P2 mini-design + mini-audit

**Design reference**: §0 form (3); the DEFERRED entry "the `:=` let chain is
BROKEN in UNSPECCED defns" (owned here).

**Part 1 — the merge-seam normalization** (form 3, specced already; both spines
after Part 2): `let-bodyless?` gains the no-`:=` arm (`rest` length 2, car a
SYMBOL — the symbol check keeps bracket forms out), and
`extract-let-binding-tokens` synthesizes `name := value` for that shape while
leaving every `:=`-bearing form VERBATIM (byte-transparency for the exact-output
pins). `split-last-let` already synthesizes for the last-with-body sibling
(:2408), so the merged bracket stream becomes uniformly `:=`-marked and lowers
onto `parse-assign-bindings` unchanged.

**Part 2 — the tree-spine disposition: DEFER, not fix.** Decided by the
architecture's own words at the cell-pipeline comment (driver.rkt, above
`process-string-ws-inner-impl`): "Preparse surfs are FALLBACK for forms that
fail parse-form-tree (expression-level desugaring: cond, **let**, multi-arity
defn patterns, etc.)" — the tree spine is DESIGNED to error on let and fall
back; its half-implemented let-chain (`:=`-only, annotation-dropping, output
fails typing) contradicts that design and WINS the merge. Mechanics verified:
`tree-by-line` is built `#:when (not (prologos-error? s))`, so an erroring tree
parse → tree-match #f → merge-form's first arm → preparse. The audit also found
a THIRD latent case: a no-`:=` `let-bracket` head falls to `parse-expr-tree`,
producing a junk APPLICATION surf that would win the merge for unspecced
bracket lets. The fix therefore covers the WHOLE let-chain arm (both
`let-assign` and `let-bracket` heads → a deliberate `parse-error-result`
defer). Not option (a) (fixing the duplicate): two rival implementations of let
semantics is the belt-and-suspenders class, and full parity would mean
implementing P2/P3/P4 twice — for a spine whose let support serves ZERO working
cases today. The defer is named scaffolding: it retires when the form-cell path
grows a real let (the tree spine is the architectural destination — Phase 4 of
the form-cells plan — and this is recorded there, not silently dropped).

**Drift risks named before coding**:
1. Byte-transparency — the `:=` merge paths must be untouched (exact-output
   pins in test-defmacro).
2. The tree defer must be a parse-ERROR result (excluded from tree-by-line);
   any non-error junk surf silently WINS the merge.
3. The bodyless arm must not capture bracket forms (`(let (x 5 y 6))` has a
   LIST car — excluded by the symbol check).
4. Deferring the whole defn to preparse must not regress non-let aspects —
   safe: preparse is the strictly-more-capable spine (spec injection, POL.9b
   paren-origin, annotations kept).
5. A standalone bodiless `(let x 4)` (no following body) must stay a
   per-command ERROR, not silently become a binding of nothing.

## 7. P2 close notes — including the correction

- Part 1 landed as designed; byte-transparency held (merge-layer pin + the
  test-defmacro exact-output pins untouched). Mixed spellings fell out free.
- **The phase's own A/B refuted the phase's own mini-design rationale.** §6
  justified the tree defer with "its output fails typing" — false. A pre-P2
  worktree at `974e5cc5` shows the unspecced `:=` chain WORKED with concrete
  ops; the P0-era DEFERRED filing's repro failed for the ISSUE-#70 reason
  (generic `+` over an unannotated param), never controlled. The filing is
  WITHDRAWN in DEFERRED with the full correction; the defer ships on the
  single-implementation principle alone (the driver's own architecture comment
  names preparse as the let fallback), with NO demonstrated behavioral delta —
  and is claimed as exactly that in the commit.
- The P1 "four broken classes" pin dropped to three: the no-`:=` chain
  graduated to working — the flip-with-the-feature pattern, third instance
  this track.
- VAG note (adversarial column, honestly): the gate's real catch this phase
  was AGAINST the phase's own grounding — the disposition survived, its
  justification did not. Watching pattern reinforced: control every repro
  against the documented failure classes BEFORE filing (i70 for anything with
  a generic op over an unannotated param).

## 8. P3 mini-design + mini-audit

**Design reference**: §0 forms (1)/(5); ruling 1 (STRICT columns).

**Hook**: a recursive stx transform applied to `tree-node->stx-elements`'s
output (after `group-items`) — the layer where EVERY element, bare token or
group, still carries line/column (`make-stx` → real `datum->syntax` with loc;
verified). Nested lets at any depth are reached by the walk; sexp mode has no
columns and the aligned form is WS-only, like `&>`.

**Activation (the load-bearing design decision)** — the transform is IDENTITY
unless ALL of:
- the group's head is the identifier `let`, with BARE head-binding tokens
  (a bracket-binding head is excluded);
- ≥2 continuation LINES (elements whose `syntax-line` > the let's);
- no continuation is `$pipe`-headed — STRUCTURAL, not heuristic: `|` is
  reserved arm syntax, never a binding, so `let x := v / match x / | arm…`
  (a working multi-line body) can never be captured;
- every element carries line/col (synthesized loc-less stx deactivates).

Then the STRICT discipline (ruling 1): binding-col := the first continuation's
column; every continuation at binding-col is a binding line (a BARE token
there = guided error — "a binding line needs a name and a value"); exactly ONE
line strictly between the let column and binding-col is the body and must be
LAST; **any other column, no body line, or multiple body lines = a guided
`$let-error` naming the columns** — P1's marker seat means the reader layer
emits per-command column-precise errors with zero new machinery.

**Why signature-activation instead of activating on any ≥2-continuation let**:
the audit found the working `let x := v / match x / | arms` shape has two
same-column continuations. Pipe-exclusion handles it structurally; the
remaining same-col-no-body shapes (`let x := 4 / (f 1) / (f 2)`) are
ALREADY-BROKEN junk today (value-swallowing), so the guided no-body error is a
strict improvement, never a regression.

**Emitted shape**: `(let ($let-block (head-binding) (b1…) (b2…)) body)` — head
`let` retained so the existing preparse dispatch reaches `expand-let`, which
gains one branch: normalize each group (`name value` → synthesize `:=`;
`:=`-bearing verbatim; anything else a guided error — fused arrives at P4) via
ONE shared `normalize-let-binding-group`, then the existing
`parse-assign-bindings` → `let-bindings->nested-fn` funnel.

**Audit findings that shaped it**:
- `split-last-let` needs a `$let-block` arm sharing that SAME normalizer — a
  bodyless sibling `let a := 1` followed by an ALIGNED let hits
  `merge-let-sequence`, whose bracket arm would splice the raw `$let-block`
  into a binding stream (value-swallowing junk). One normalizer, two
  consumers.
- `let-bodyless?` needs no change: an aligned let's rest is
  `(($let-block …) body)` — car is a LIST, so the P2 arm's symbol check
  already excludes it (the check earns its keep again).
- `preprocess-let-infix-eq`'s group-blindness is DISSOLVED for aligned forms:
  binding values are structured into groups at the reader, before any merge
  processing.
- The P0-flagged top-level guard bypass closes STRUCTURALLY: the bodyless
  aligned shape at top level has no between-columns line → the guided no-body
  error, columns named.
- `$let-block` owes the `pattern-var?` exclusion (the `$dot-brace` lesson).

**Drift risks named before coding**:
1. Byte-transparency for every working form — 0/1-continuation lets, bracket
   heads, pipe-bodied lets, `:=` sibling chains: all must pass the transform
   untouched (the suite + acceptance are the oracle, plus explicit pins).
2. The walk must recurse BOTTOM-UP (a nested let inside a binding value).
3. Loc-less synthesized stx must deactivate, never crash.
4. The 2-line forgot-body case (`let x 4 / y 5`) is NOT activatable (no body
   signature) and falls to Branch 3 as `(let x 4 (y 5))` → "Unbound variable
   y" — an error, but a mediocre one; pre-existing shape, documented not fixed.
5. `check-stdout-clean` — markers must never print as structs.

## 9. P3 close notes + VAG highlights (two columns, the challenge side)

- **(a/d) The gate's catch WAS the challenge finding**: the first draft's walk
  rebuilt every stx and silently DROPPED SYNTAX PROPERTIES — POL.9's
  `'prologos-paren-origin` mark among them — degrading implicit-solve paren
  goals to applications (path-selection acceptance [27]/[28] + two Rel T1
  suites). The mini-design's drift risks named LOC hygiene (risk 3) but not
  PROPERTY hygiene — the enumeration under-counted its own hygiene class, the
  session's recurring shape. Fixed eq?-preserving by construction (untouched
  forms keep stx identity — the pipeline.md reflective-walker idiom), which is
  strictly stronger than patching the property template alone.
- **(b) Complete, with one named residual**: the 2-line forgot-body shape has
  no signature to activate on and yields Branch 3's "Unbound variable" —
  documented (risk 4), not fixed. Everything else in scope landed: all
  spellings mixed freely, guided errors carry columns, contexts covered
  (defn body, def := RHS, sibling merge via the shared normalizer).
- **(c) The top-level bypass closed at the FUNNEL, not with a second guard**:
  `:=`-reserved means a binding-shaped body is refusable at the single point
  every format converges on — one check, all branches, no column data needed.
- **Flip-with-the-feature, 3rd instance**: the P1 broken-form exemplars moved
  forward to the fused form. When P4 lands, the containment tests' bad-let
  exemplar must become the top-level let (the one PERMANENT error).

## 10. P4 close notes

- **Fused landed everywhere** (aligned, sibling, nested, `:=` and not, sexp
  glued split per ruling 3) through the one-normalizer funnel; the annotation
  is REAL (wrong type = per-command type error); multiplicities and keyword
  values structurally excluded.
- **The primitives moved, not copied**: reader-forms.rkt owns them; parser.rkt
  re-imports. The cycle (parser → macros) made this the only correct home —
  and the move HARDENED the predicate: `fused-type-annot?` accepted bare `:`
  and `:=`, which the let rewrite arm turned into an INFINITE LOOP (the defn
  consumer never fed it a bare `:`, so the hole was latent there). Found by a
  hung battery; bisected reader → preparse; the stack named the loop pair.
  Lesson, the session's recurring one: a predicate inherited by a NEW consumer
  meets inputs its old consumers never produced.
- **Multi-line values (the owner add-on)**: the fold (deeper-than-binding-col
  = value continuation — the original design rule, finally implemented) + the
  absorb (multi-line brackets end the reader's form extent; siblings taken
  back, gated on bodiless shape). All five broken shapes were A/B'd at
  pre-P3 BEFORE attribution: all pre-existing, nothing regressed.
- **Boundary stated, not hidden**: unannotated match VALUES remain the QTT
  infer-position debt (typing-side; the layout now produces the correct
  datum). Annotated they work; pinned both ways; acceptance §E2 carries the
  annotated form with a comment naming the boundary.
- The flip-with-the-feature series CLOSED: P1's exemplars now sit on the two
  PERMANENT errors (chained annotation, top-level let).

## 11. X.close — PIR-lite

Scoped as PIR-lite, flagged not defaulted: `workflow.md`'s objective gate wants
a full PIR for tracked designs; this track is one session, five phases, with
per-phase close notes + VAGs already in this doc. The owner can upgrade to a
full 16-question PIR on request.

**Delivered vs asked**: everything in the original request (aligned blocks,
fused, sibling chains, optional `:=`) plus the mid-track owner add-on
(multi-line values) plus the un-asked-for foundation that made the rest safe
(per-command let errors — the 13-raise abort class). Three rulings honored
(strict columns · mixed spellings · sexp split). One boundary shipped stated
rather than silently: unannotated match values (QTT infer-position debt,
typing-side).

**What went wrong, honestly**:
- The P0-era DEFERRED filing ("unspecced defns broken") was WRONG — issue #70
  in a let costume; withdrawn at P2 with the full correction. Filed by the
  same process that codified "a failing test is only evidence if it fails for
  the reason you claim."
- P3's first draft dropped SYNTAX PROPERTIES tree-wide (broke implicit solve);
  caught by the acceptance gate pre-commit; the fix (eq?-preserving walk) was
  stronger than the patch.
- P4's predicate move exposed a latent hole as an INFINITE LOOP (bare `:`/`:=`
  accepted by `fused-type-annot?`); the battery hang + stack bisection found
  it in minutes.

**The pattern that recurred FOUR times** (P1 exemplar flips ×3 + the final
flip to permanent errors): tests pinning "X is broken" flip WITH the feature
that fixes X. Writing the pin's exemplar on the NEXT phase's target makes the
flip an expected checkpoint instead of a surprise failure.

**What the track leaves better beyond let**: the `$let-error` marker seat
(reusable per-command error channel for preparse), the fused primitives in
reader-forms.rkt (ONE definition, hardened), the eq?-preserving stx-walk
pattern with the properties lesson recorded, and the withdrawn-filing
precedent (kept, not deleted).

**Residuals**: three, filed in DEFERRED (fn-bracket-body lets · the 2-line
forgot-body mediocre error · the unannotated-match-value boundary pointer).
