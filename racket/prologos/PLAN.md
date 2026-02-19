# Homogeneous Varargs for Prologos

## Design Summary

Implement **Level 1: Homogeneous Varargs** — the simplest, highest-value approach from the design conversation. All varargs share a single element type `A`, collected into `List A` at the call site. This is pure sugar over the existing type system — no new core types or typing rules needed.

### User-Facing Syntax

**Defining varargs functions:**
```prologos
;; spec: use `...` before the last type to mark it variadic
spec add-all {A : Type} A ... -> A where (Add A)
;;                      ^^^^^ rest params are all A, collected into List A

;; defn: `...xs` in the parameter list binds the rest arguments
defn add-all [...xs]
  reduce add zero xs

;; Mixed fixed + varargs:
spec max-of Nat Nat ... -> Nat
defn max-of [first ...rest]
  reduce max first rest
```

**Calling varargs functions:**
```prologos
add-all 1 2 3 4 5         ;; => 15
max-of 3 1 4 1 5 9        ;; => 9
```

### Type-Level Semantics

Varargs is **pure sugar** — no new core types:

```
spec add-all Nat ... -> Nat
≡
spec add-all [List Nat] -> Nat
```

At the call site, extra arguments are collected into a list literal:
```
add-all 1 2 3
≡
add-all '[1 2 3]
```

The `...` marker in `spec` appears **immediately after the variadic element type**, before `->`. It marks the preceding type as "collect remaining args into `List <type>`".

### Implementation Layers

The implementation touches **4 layers** of the pipeline, all using existing mechanisms:

| Layer | File | Change |
|-------|------|--------|
| 1. Reader | `reader.rkt` | Tokenize `...` as `'$rest` sentinel; `...name` as `($rest-param name)` |
| 2. Macros/Spec | `macros.rkt` | Detect `...` in spec tokens → set variadic flag, desugar to `List A` param |
| 3. Macros/Defn | `macros.rkt` | Detect `...name` in defn params → mark as rest-param |
| 4. Elaborator | `elaborator.rkt` | For variadic functions, collect excess args into list literal at call site |

---

## Phase 1: Reader — Tokenize `...` and `...name`

**File:** `reader.rkt`

**Change:** In the tokenizer's main dispatch (around line 488, before the `else` error case), add a case for `.`:

```
;; ... rest/varargs operator
[(char=? c #\.)
 (let ([c2 (peek-char port 1)]
       [c3 (peek-char port 2)])
   (cond
     [(and (char? c2) (char=? c2 #\.) (char? c3) (char=? c3 #\.))
      ;; Consume three dots
      (tok-read! tok) (tok-read! tok) (tok-read! tok)
      ;; Check if followed by identifier chars → ...name (rest param)
      (define next (tok-peek tok))
      (if (and (char? next) (ident-start? next))
          ;; ...name → ($rest-param name) sentinel
          (let ([rest-name (read-ident-chars! tok)])
            (token 'rest-param (string->symbol rest-name) ln cl ps
                   (+ 3 (string-length rest-name))))
          ;; bare ... → $rest sentinel symbol
          (token 'symbol '$rest ln cl ps 3))]
     [else
      ;; Single or double dot → error (not valid Prologos)
      (tok-read! tok)
      (error 'prologos-reader "~a:~a:~a: Unexpected character: ."
             (tokenizer-source tok) ln (+ cl 1))]))]
```

**In form construction** (where tokens become datum): `rest-param` tokens produce `($rest-param name)` sentinel lists, similar to how `approx-literal` produces `($approx-literal N)`.

**Tests to add (in test-reader.rkt):**
- `"[a b ...xs]"` → `(a b ($rest-param xs))`
- `"Nat ... -> Nat"` → `(Nat $rest -> Nat)`
- `"[a b ...]"` → error (bare `...` in bracket without name)

---

## Phase 2: Macros — Spec Variadic Detection

**File:** `macros.rkt`

**In `process-spec`:** After extracting implicit binders, scan the type tokens for `$rest`. When found:

1. The token *before* `$rest` is the variadic element type (e.g., `Nat`, `A`, `[A]`)
2. Replace `<element-type> $rest` with `(List <element-type>)` in the spec tokens
3. Store a **variadic flag** in `spec-entry` (7th field: `rest-type` — the element type symbol/datum, or `#f` if not variadic)

**Example transformation:**
```
spec add-all Nat ... -> Nat
  tokens: (Nat $rest -> Nat)
  → effective tokens: ((List Nat) -> Nat)
  → spec-entry with rest-type = 'Nat
```

**With implicit binders:**
```
spec add-all {A : Type} A ... -> Nat
  tokens after extract-implicit: (A $rest -> Nat)
  → effective tokens: ((List A) -> Nat)
  → spec-entry with rest-type = 'A
```

**Mixed fixed + variadic:**
```
spec max-of Nat Nat ... -> Nat
  tokens: (Nat Nat $rest -> Nat)
  → effective tokens: (Nat (List Nat) -> Nat)
  → spec-entry with rest-type = 'Nat
```

**Struct change:** Add `rest-type` field to `spec-entry` (7th field). Update all creation sites (including 2 in test-spec.rkt).

---

## Phase 3: Macros — Defn Rest-Param Detection

**File:** `macros.rkt`

**In `inject-spec-into-defn` and `spec-bare-param-list?`:**

1. **`spec-bare-param-list?`** — extend to recognize `($rest-param name)` as a valid param element alongside bare symbols
2. **`inject-spec-into-defn`** — when building the typed bracket, if the spec has `rest-type`, the last parameter gets type `(List <rest-type>)` instead of the raw element type. The `...name` param in the defn becomes `name` with type annotation `<List A>`.

**Example:**
```
;; Input datum:
(defn add-all (($rest-param xs)) body)

;; spec-entry has rest-type = 'Nat, type-tokens = ((List Nat) -> Nat)
;; param-names extracted: (xs)  ← strip $rest-param wrapper
;; After injection:
(defn add-all [xs ($angle-type List Nat)] ($angle-type Nat) body)
```

---

## Phase 4: Elaborator — Call-Site Argument Collection

**File:** `elaborator.rkt`

**In the `surf-app` elaboration path** (lines 558-623):

When elaborating a call to a function with `rest-type` in its spec:

1. **Detect variadic call**: Look up the spec for the function. If `spec-entry-rest-type` is non-#f, this is a variadic function.
2. **Count fixed params**: The spec's decomposed params tell us how many are fixed vs. variadic. For `spec max-of Nat [List Nat] -> Nat`, there is 1 fixed param and 1 list param. The variadic position is always the **last parameter** (the one with `List <rest-type>`).
3. **Collect excess args**: If the user provides more args than the (fixed + 1) count after implicit insertion:
   - Take the first N fixed args as-is
   - Collect remaining args into a list literal: `($list-literal arg1 arg2 ...)`
   - Pass the list literal as the final argument
4. **Allow single-list arg**: If the user provides exactly the right number of args (fixed + 1), pass through unchanged — they might be passing a pre-built list.

**Example:**
```
add-all 1 2 3 4 5
  → spec has 0 fixed, 1 list param, rest-type = Nat
  → implicit binders: {A} → 1 implicit hole inserted
  → user provides 5 args, function expects 1 explicit (List A)
  → collect all 5 into list: add-all '[1 2 3 4 5]
  → elaborate as: add-all _ ($list-literal 1 2 3 4 5)
  → where _ is the implicit type hole

max-of 3 1 4 1 5
  → spec has 1 fixed (Nat), 1 list (List Nat), rest-type = Nat
  → user provides 5 args, function expects 2 explicit
  → first 1 fixed: 3
  → collect remaining 4: '[1 4 1 5]
  → elaborate as: max-of 3 ($list-literal 1 4 1 5)
```

**Key integration point:** This happens AFTER implicit insertion but BEFORE `elaborate-args`. The logic:

```racket
;; After implicit-holes-needed determines n-holes:
(when (and spec (spec-entry-rest-type spec))
  ;; Variadic function
  (define n-fixed (count-fixed-params-from-spec spec))
  (define total-explicit (+ n-fixed 1))  ;; fixed + 1 list param
  (when (> n-user-args total-explicit)
    ;; Collect excess into list literal
    (define fixed-args (take args n-fixed))
    (define rest-args (drop args n-fixed))
    (define list-literal-surf (make-surf-list-literal rest-args loc))
    (set! args (append fixed-args (list list-literal-surf)))))
```

**Arity check modification:** For variadic functions, the arity check must allow `n-user-args >= n-fixed` (any number of extra args is fine). Modify the "too many arguments" check to skip when the function is variadic.

---

## Phase 5: Tests + Example

**New test file: `test-varargs.rkt`** (~30 tests)

Test categories:
1. **Reader**: `...` and `...xs` tokenization
2. **Spec processing**: `Nat ... -> Nat` stores rest-type
3. **Spec+defn injection**: `defn add [...xs]` with spec injects List type
4. **Sexp-mode evaluation**: basic varargs calls
5. **WS-mode evaluation**: full end-to-end
6. **Mixed fixed+varargs**: `spec max-of Nat Nat ... -> Nat`
7. **With implicit binders**: `spec f {A : Type} A ... -> [List A]`
8. **Zero varargs**: `f` called with only fixed args → empty list
9. **One vararg**: `f 1` → `f '[1]`
10. **Pre-built list passthrough**: `f '[1 2 3]` still works
11. **Arity errors**: too few fixed args

**Example file: `examples/varargs.prologos`**

Demonstrates:
- `sum-all` — add all Nat args
- `max-of` — max with at least one arg
- `list-of` — build a list from args
- `count-args` — return number of varargs

---

## What This Does NOT Cover (Future Work)

- **Heterogeneous varargs** (HList) — Level 2+
- **Dependent arity** (`vec-of : (n : Nat) -> A... -> Vec n A`) — Level 3
- **Format string types** — Level 4
- **Constrained varargs** (`A... where (Show A)`) — needs constraint propagation through list elements; could be a follow-on
- **Pattern matching on rest params** — would need `match` to destructure the collected list

---

## File Change Summary

| File | Changes |
|------|---------|
| `reader.rkt` | Add `.` case to tokenizer: `...` → `$rest`, `...name` → `($rest-param name)` |
| `macros.rkt` | Add `rest-type` field to `spec-entry`; detect `$rest` in spec tokens; handle `$rest-param` in defn params |
| `elaborator.rkt` | Collect excess args into list literal for variadic functions |
| `tests/test-spec.rkt` | Update `spec-entry` constructors (add 7th field `#f`) |
| `tests/test-higher-rank.rkt` | Update `spec-entry` constructors if any |
| `tests/test-varargs.rkt` | **New** — ~30 tests |
| `lib/prologos/examples/varargs.prologos` | **New** — showcase file |

## Estimated Test Count After: ~2570 (2540 + ~30 new)
