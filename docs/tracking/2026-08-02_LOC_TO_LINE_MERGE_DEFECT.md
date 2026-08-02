# `loc->line` mis-extracts the line for tree surfs — the dual-spine merge is defused by a one-line defect

**Filed** 2026-08-02 at the CIU T6 D4.P4c-4 mini-audit · **Status** ⬜ investigation +
fix, scoped for an OUT-OF-BAND worktree · **Not** CIU T6 work — it is shared
parser machinery and its blast radius is the whole dual-spine merge.

> **Why this is written down rather than fixed inline**: CIU T6's P4c-4 needs to
> know whether the merge protects a broadcast. It currently does — *by accident*,
> because of the defect below. Fixing the defect makes every latent tree surf go
> live **at once**, which is a behavioural change well outside that phase's scope.
> Discovering its blast radius mid-slice is exactly the mid-phase pivot the
> mini-audit exists to prevent.

---

## §1 — The defect

`loc->line` (`racket/prologos/driver.rkt:2442-2447`), the helper that keys the
dual-spine merge:

```racket
(define (loc->line loc)
  (cond
    [(srcloc? loc) (srcloc-line loc)]
    [(and (list? loc) (>= (length loc) 2)) (cadr loc)]  ;; (file line col span) or (line col pos span)
    [(and (pair? loc) (number? (car loc))) (car loc)]    ;; (line col pos span) as first element
    [else #f]))
```

**Arm 2's own comment claims it serves two shapes. It is correct for at most one,
and arm 3 — which handles the shape that actually flows — is UNREACHABLE**,
because arm 2 catches every list of length ≥ 2 first.

### The shapes that actually flow — verified, not assumed

| Producer | Shape | `loc->line` gives | Correct? |
|---|---|---|---|
| **preparse** — `datum-srcloc`, `parser.rkt:220-226` | `srcloc` **struct** | `(srcloc-line loc)` | ✅ real line |
| **tree, node** — `parse-tree-node` srcloc field, `parse-reader.rkt:1666` | `(list line col start-pos end-pos)` | `(cadr loc)` = **col** | ❌ |
| **tree, token** — `item-srcloc`, `tree-parser.rkt:56-57` | `(list 0 0 start-pos end-pos)` | `(cadr loc)` = **0** | ❌ (and see §4) |

`parse-tree-node`'s field comment is the authority and is unambiguous:

```racket
srcloc      ;; (list source-line source-col start-pos end-pos) | #f
```

Line **first**. Arm 3's comment says exactly this (`(line col pos span) as first
element`) and its body `(car loc)` is the correct extraction — it simply never
runs.

## §2 — Why it matters: this key IS the merge

```racket
(define tree-by-line
  (for/hasheq ([s (in-list tree-surfs)]
               #:when (not (prologos-error? s)))     ;; errors filtered OUT
    (define line (surf-source-line s))               ;; ← loc->line
    (if line (values line s) (values (gensym) s))))
```

and

```racket
(define (merge-form preparse-surf tree-surf)
  (cond
    [(not tree-surf) preparse-surf]                          ;; ← lookup MISS lands here
    [(not (same-form-type? preparse-surf tree-surf)) preparse-surf]
    …
    [else tree-surf]))                                       ;; ← the tree spine WINS
```

Preparse surfs key on a **real line**; tree surfs key on a **column or 0**. The
keys are computed on different scales, so the lookup generally misses,
`tree-surf` is `#f`, and preparse wins by default.

**That is the opposite of the designed behaviour.** `merge-form`'s last arm is
`[else tree-surf]`, commented *"Both pipelines produced valid output → tree
parser wins for user forms."* The tree spine is supposed to be authoritative for
user forms; today it effectively never is.

### The protection mechanism this defect is masking

Every sibling selection surface is protected by being deliberately **errored** on
the tree spine, so it is filtered out of `tree-by-line` and preparse becomes
authoritative — e.g. `tree-parser.rkt:147` (`select-brace-group`) and `:177`
(`dot-access`). That file states the hazard verbatim:

> a missing arm lets a garbage surf BEAT preparse's

So there are **two** independent things keeping garbage tree surfs from winning:
the per-tag error arms (designed, correct) and the broken key (accidental). Only
the first is intended. **This is a belt-and-suspenders situation where the
suspenders are a bug** — and per the project's own rule, dual mechanisms mask
defects in each other. Any tag *lacking* an error arm is protected today solely
by the broken key.

## §3 — The minimal fix, and why it is not sufficient

The two list arms are simply **in the wrong order**. The discriminator is already
written: a `(file line col span)` shape has a non-number head (a path or string);
the tree shape has a numeric head.

```racket
(define (loc->line loc)
  (cond
    [(srcloc? loc) (srcloc-line loc)]
    ;; tree shape: (line col start-pos end-pos) — LINE FIRST, all numeric
    [(and (pair? loc) (number? (car loc))) (car loc)]
    ;; file-first shape: (file line col span)
    [(and (list? loc) (>= (length loc) 2)) (cadr loc)]
    [else #f]))
```

⚠ **This alone does not make the merge correct**, and shipping it as "the fix"
would be worse than leaving it: it turns the merge on for *node*-derived surfs
while leaving *token*-derived surfs keyed on a fabricated `0` — so those would
now all collide on one key instead of missing. See §4.

## §4 — The second defect, which is the harder one

`item-srcloc` (`tree-parser.rkt:53-58`) **fabricates** the line and column for a
token entry:

```racket
[(token-entry? item) (list 0 0 (token-entry-start-pos item)
                              (token-entry-end-pos item))]
```

Positions are real; line and column are hardcoded `0`. So any surf whose srcloc
came from a token carries no line at all. Under the §3 fix these all key on `0`
and collide.

**Open question for the investigation**: does `token-entry` carry enough to
recover the real line — directly, or by mapping `start-pos` through the source
text? If yes, `item-srcloc` should compute it. If not, that path must be made to
return `#f` so those surfs fall to `(gensym)` (unmatchable) rather than collide
on `0` — the existing `(if line … (gensym))` branch already expresses that
intent, and `0` defeats it by being truthy.

## §5 — Suggested order of work

**Do not start by changing behaviour. Measure the blast radius first** — that is
the whole point of doing this out of band.

1. **Instrument, don't fix.** Add a temporary counter in `merge-form`: for each
   form, compute the key both ways (current and §3-corrected) and record whether
   a lookup that misses today would HIT under the fix, and whether that hit would
   land on `[else tree-surf]`. Emit counts only; change no behaviour.
2. **Run the corpus** (163 tracked `.prologos` files) and the suite. The output is
   the number that decides everything: *how many forms currently take preparse
   that would flip to the tree spine.* If it is small, this is a contained fix.
   If it is large, the merge has been running on preparse for so long that the
   tree spine's arms have gone stale, and correcting the key would surface a
   backlog of latent garbage surfs.
3. **Audit the tag arms.** Enumerate every tag `parse-node-tree` can dispatch and
   check which have explicit arms vs fall to the silent `else → parse-expr-tree`.
   The comment at `tree-parser.rkt:139-147` says an explicit arm is MANDATORY;
   the sweep confirms whether that has been maintained. Any tag without one is
   protected today only by the broken key.
4. **Then choose the resolution**, informed by (2) and (3):
   - *fix the key and repair the fallout* — correct per the design intent, most work;
   - *fix the key and flip the default* (`[else tree-surf]` → `preparse-surf`),
     making tree-spine adoption opt-in per form — smaller blast radius, but it
     inverts a documented design decision and should be ruled, not assumed;
   - *fix `item-srcloc` to return `#f`* for tokens and correct the arm order —
     narrowest correct step; makes node-derived merging work and leaves
     token-derived surfs honestly unmatchable.
5. **Gate**: full suite + the 163-file corpus A/B (`git archive` both legs onto one
   snapshot, worktree-pin the baseline — `bench-ab.rkt` has no `--ref`). A corpus
   A/B with **zero** diffs would mean the fix changed nothing, which for this
   defect is evidence the instrumentation in (1) was wrong, not evidence of safety.

## §6 — What CIU T6 assumes in the meantime

P4c-4's producer bridge will make `users:name` produce a **non-error** surf on the
tree spine. Unlike its siblings it mints no tag, so it has **no tag arm and cannot
be errored** — the §2 protection is structurally unavailable to it. It is therefore
protected *only* by this defect.

CIU T6 records that as an explicit assumption rather than inheriting it silently.
If this investigation lands a fix, the broadcast needs its own tree-spine
protection **in the same change** — either a tag + error arm matching the
siblings, or a `merge-form` exception arm on the POL.9b template
(`driver.rkt:2487-2497`), which already prefers preparse when the two spines
disagree in category about a `def` body.

## §7 — Coordinates (re-derive before trusting; this repo's drift regularly)

| What | Where |
|---|---|
| `loc->line` | `driver.rkt:2442-2447` |
| `surf-source-line` | `driver.rkt:2450-2458` |
| `tree-by-line` (the error filter) | `driver.rkt:2473-2477` |
| `merge-form` (`[else tree-surf]`) | `driver.rkt:2482-2503` |
| POL.9b exception arm (the template) | `driver.rkt:2487-2497` |
| `parse-tree-node` srcloc field | `parse-reader.rkt:1663-1669` |
| `item-srcloc` (the `0 0` fabrication) | `tree-parser.rkt:53-58` |
| tag error arms + the hazard comment | `tree-parser.rkt:139-147`, `:174-180` |
| `datum-srcloc` (preparse, srcloc structs) | `parser.rkt:220-226` |

All verified at `66a8e731`.
