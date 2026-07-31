# LET blocks — multi-binding `let` layout

**Status**: P0 ✅ · P1 🔄. Owner-requested language polish (2026-07-31): the
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
| P1 | All 13 `(error 'let …)` raises → per-command parse-error VALUES (`$let-error` marker) | 🔄 | the whole-file-abort class, closed for let |
| P2 | Sibling no-`:=` chains (form 3): uniform `:=` synthesis at the merge seam | ⬜ | + the tree-spine defect disposition (fix or make preparse win) |
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
