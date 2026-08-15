# `let` Aligned Block — TSG Track 2

**Status**: 🔄 design open · **Opened** 2026-08-15 · Closes the remaining half of
[DEFERRED 140](DEFERRED.md). The bracket half shipped at `c809c5d0`.

The **aligned block** is the documented canonical multi-binding layout
(`.claude/rules/prologos-syntax.md`), and the grammar binds only its first name:

```
defn f [n]
  let y 4          <- binds
      z 5          <- does NOT bind
    [+ n [+ y z]]
```

The compiler accepts it at 0 errors and evaluates it, so the grammar is wrong
relative to the compiler, per the standing rule.

---

## Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| P0 | Establish that grammar-only routes fail, and why | ✅ | Two formulations built and measured — [§2](#why-not-grammar) |
| P1 | `LET_OPEN`: capture the first binding's column | ⬜ | Zero-width, emitted after `let` |
| P2 | `LET_ALIGN`: separate a continuation binding from the body | ⬜ | Zero-width, column comparison |
| P3 | Per-`let` column stack + serialization | ⬜ | Format change — [§4.3](#serial) |
| P4 | Corpus tests + per-file A/B + seven gates | ⬜ | |

---

## 1. What the parse actually does today

The failing tree is ONE `let_binding` whose value is a single `application`
spanning lines 1–3. It swallows the second binding **and** the body:

```
(let_expr
  (let_binding
    name: … (identifier)          ; y
    value: (expression
      (application [1,8] - [3,17] ; 4 z 5 [+ n [+ y z]]  ← all of it
```

`let_binding`'s value is a full `$.expression`, and nothing stops it at the line
end.

---

<a id="why-not-grammar"></a>
## 2. (P0 ✅) Why this is NOT a grammar-only fix — measured, not assumed

The scanner already emits `INDENT` before `z 5` and `DEDENT` before the body,
because its indent logic is line-leading with a stack. That made a grammar-only
fix look plausible, so it was **tried twice before being ruled out**.

### Attempt A — one merged branch

```js
seq(repeat1($.let_binding),
    optional(seq($._indent, repeat1($.let_binding), $._dedent)))
```

Generates with no conflict, and the aligned block binds correctly. **But it
regresses two shapes that already worked:**

| shape | before | after A |
|---|---|---|
| aligned block | 1 binding | ✅ 2 |
| **sibling chain** | 2 bindings, E=0 | ❌ 2 bindings, **E=1** |
| **nested `let`** | 2 bindings | ❌ binds `"let"` **as a name** |

### Attempt B — two branches plus a declared conflict

```js
seq($.let_binding, $._indent, repeat1($.let_binding), $._dedent),
repeat1($.let_binding),
// conflicts: [$.let_expr]
```

GLR carries both and picks the wrong one. **Identical regressions**, plus a new
one: an aligned block whose value is a multi-line `match` goes to **E=2**.

### The reason both fail, stated exactly

Nested and aligned are the SAME token sequence — `let`, binding, `INDENT`. They
differ only in **how deep** the indent is, relative to the first binding:

```
let y 4              let y 4
  let z 5                z 5
  ^ indent 4             ^ indent 6 == column of `y`
  < column of `y`  →     == column of `y`  →
  therefore BODY         therefore a CONTINUATION BINDING
```

`.claude/rules/prologos-syntax.md` says this outright: the body "sits STRICTLY
between the `let` column and the binding column". **The discriminator is the
first binding's column**, the LR state does not have it, and no rule shaping can
supply it. This is the contested-shape case from
`.claude/rules/tree-sitter-grammar.md`, and its recipe is a scanner token.

⚠ Recorded because the cheap route is genuinely tempting and *looks* like it
works: attempt A's aligned probes are all green. Only the shapes it was **not**
about reveal the damage — which is the per-file-A/B lesson at the probe level.

---

## 3. What must not regress

Pinned before any change, and re-checked after each phase:

| shape | must be |
|---|---|
| sibling chain (`let y 4` / `let z 5`) | 2 bindings, E=0 |
| nested (`let y 4` / indented `let z 5`) | 2 bindings, E=0, and **`let` is never a name** |
| bracket, all four spellings | every name binds, E=0 (`test/corpus/let_bracket.txt`) |
| sexp `let [x <Nat> (inc zero)]` | one binding, `angle_param` name, M=0 |
| aligned, multi-line `match` value | E=0 |

---

## 4. Design

### 4.1 (P1) `LET_OPEN` — capture the column

A zero-width external token, valid **only** immediately after the `let` keyword
in the layout branch. When the scanner emits it, it records
`lexer->get_column()` of the next non-space character — the first binding's
column — by pushing it on a per-`let` stack.

The grammar must withhold it everywhere else. Per the recipe: *the scanner
cannot tell where in a rule the parser is; it only sees `valid_symbols`.*

### 4.2 (P2) `LET_ALIGN` — separate continuation from body

A zero-width token, valid only where a further binding could start. The scanner
emits it when the pending line's indent **equals** the column on top of the
let-stack. Otherwise it declines, the `INDENT`/`DEDENT` path runs as it does
today, and the deeper-or-shallower line becomes the body.

Then:

```js
seq($._let_open, $.let_binding, repeat(seq($._let_align, $.let_binding)))
```

⚠ The `let` stack must POP when the form ends. The cleanest trigger is the
`DEDENT` that closes the block, which the scanner already emits.

<a id="serial"></a>
### 4.3 (P3) Serialization

`Scanner` gains `int let_col_stack[N]` and `int let_depth`. The existing
`serialize` writes `pending_dedents`, `pending_newline_after_dedents`,
`stack_size`, then a **trailing variable-length** array of indent levels.

The new stack therefore appends **after** that array, with its own count byte.
`deserialize` reads it only if bytes remain, so state serialized by an older
parser deserializes as "no open lets" rather than as garbage.

---

## 5. Risks

1. **`LET_OPEN` firing outside a layout `let`.** The `_same_line_body` precedent
   records the exact failure — an optional param list let the token fire one
   position early and the real body was stranded. The grammar must make the
   layout branch structurally require it.
2. **Nested lets sharing a column.** `let a 1` whose body is another `let` at the
   same column is a sibling chain, not a continuation. The stack must be pushed
   per `let`, not per line.
3. **Error recovery churn.** Any change here can degrade files that contain no
   `let` at all. Gate with `./grammar-ab.sh diff`, per file, never netted.
