# LET blocks — multi-binding `let` layout

**Status**: P0 ✅ `0effba9c` · P1 ✅ `49f51c14` · P2 ✅ `e8a41a9a` · P3 next. Owner-requested language polish (2026-07-31): the
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
| P3 | Aligned blocks (forms 1/5): reader-layer `$let-block` regrouping, STRICT columns | ⬜ | mis-indent = per-command error naming both columns; top-level guard extended |
| P4 | Fused `var:Type` binders (form 2): WS pair + sexp glued split | ⬜ | recognizer in reader-forms.rkt; chained-annot reject shared |
| X.close | prologos-syntax.md § let (discharges issue #21's doc obligation) + DEFERRED sweep + close notes | ⬜ | |

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
