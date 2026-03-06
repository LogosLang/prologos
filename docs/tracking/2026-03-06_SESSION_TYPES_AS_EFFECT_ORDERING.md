# Session Types as Causal Timelines for Effect Ordering

**Date**: 2026-03-06
**Context**: Effectful Propagators Research §9c — "Could session types serve as the causal context for IO effects?"
**Status**: Research document — formal exploration with novel synthesis
**Prerequisite**: `2026-03-06_EFFECTFUL_PROPAGATORS_RESEARCH.md`, `2026-02-24_LOGIC_ENGINE_DESIGN.org`

---

## 1. The Central Thesis

A session type is not merely a protocol specification — it is a **causal timeline**.
Each position in a session type (each `!A . S` or `?A . S` node) represents a
causally-ordered point in time. The session's syntactic structure *is* the
happens-before relation for effects at that channel.

If we formalize this observation, session types can serve as the causal context
that provides effect ordering on our monotone propagator substrate — not as an
external scheduling discipline layered on top, but as an *intrinsic property*
of the session lattice itself. The ordering doesn't need to be recovered; it
was always there, encoded in the session type's continuation structure.

This potentially opens a **fourth architecture** beyond the three proposed in
the effectful propagators research: one where effect ordering is derived from
the session lattice via a Galois connection to an effect lattice, rather than
imposed by timestamps, barriers, or topological scheduling.

---

## 2. Grounding: What We Have Today

### 2a. The Session Lattice

Our session lattice (`session-lattice.rkt`) orders session types by information:

```
sess-bot (⊥ — no information, fresh cell)
    ↓
sess-send(A, S) / sess-recv(A, S) / sess-choice(...) / ...
    ↓
sess-top (⊤ — contradiction, incompatible protocols)
```

The merge function (`session-lattice-merge`) is a join: it unifies two session
types if they're compatible, and produces `sess-top` if they conflict. This is
a flat lattice at the top level — `sess-bot → concrete → sess-top` — but the
internal structure of a concrete session is a *chain*:

```
!String . ?Int . end
   ↓        ↓      ↓
  pos 0   pos 1   pos 2
```

Each position in this chain is causally ordered: position 1 cannot occur until
position 0 has been performed. This ordering is enforced by the continuation
structure — to reach `?Int`, you must first decompose `!String . ?Int . end`
into `!String` + `(?Int . end)`.

### 2b. Session Advancement

In `session-runtime.rkt`, session advancement works via propagators:

```racket
(rt-add-session-advance-in-rnet rnet
  src-cell       ;; current session cell
  dst-cell       ;; next session cell
  predicate      ;; e.g., sess-send-like?
  cont-extractor ;; extracts continuation from session
)
```

This installs a propagator that watches `src-cell` and, when it matches the
predicate, extracts the continuation and writes it to `dst-cell`. The chain
of advancement propagators mirrors the session type's structure exactly:

```
cell₀: !String . ?Int . end
  → advance propagator fires, writes to cell₁
cell₁: ?Int . end
  → advance propagator fires, writes to cell₂
cell₂: end
```

Each cell corresponds to one position in the session timeline. The advancement
is monotone: `sess-bot → !String.?Int.end → end` (within each cell), and the
chain of cells moves through the session positions sequentially.

### 2c. Direct IO Execution

Today, IO effects execute inline during `compile-live-process`, which walks the
process AST recursively. The walk visits `proc-send`, `proc-recv`, `proc-open`
in syntactic order — the same order the session type dictates.

```racket
[(proc-send expr chan cont)
 ;; Direct IO: if IO channel, write to file immediately
 (when io-cell
   (write-string str-val port)
   (flush-output port))
 ;; Advance session, then recurse into continuation
 (compile-live-process rnet3 cont ...)]
```

The session type determines the process structure, the process structure
determines the AST walk order, and the walk order determines effect execution
order. Session → Process → Walk → Effects. But this chain is mediated by the
AST, not by the session lattice directly.

---

## 3. The Formal Connection: Sessions Encode Causal Order

### 3a. Curry-Howard: Propositions as Sessions

The foundational insight comes from Caires & Pfenning (2010) and Wadler (2012):
there is a Curry-Howard correspondence between linear logic and session types.

| Linear Logic | Session Types | Process Calculus |
|---|---|---|
| Proposition | Session type | Channel type |
| Proof | Process | Implementation |
| Cut | Channel composition | Communication |
| Cut reduction | Computation step | Message exchange |

In this correspondence, **cut elimination steps correspond to process reductions**.
When two processes communicate (cut), the proof simplifies (cut reduction), and
the protocol advances. The ordering of cut elimination steps IS the ordering of
communications.

*Sources*:
- [Propositions as Sessions](https://homepages.inf.ed.ac.uk/wadler/papers/propositions-as-sessions/propositions-as-sessions.pdf) — Wadler (2012)
- [Linear Logic Propositions as Session Types](https://www.cs.cmu.edu/~fp/papers/mscs13.pdf) — Caires & Pfenning (2012)
- [Session Types as Intuitionistic Linear Propositions](https://link.springer.com/chapter/10.1007/978-3-642-15375-4_16) — Caires & Pfenning (2010)

### 3b. Linear Logic's Tensor and Sequencing

In linear logic, the tensor (⊗) connective corresponds to parallel composition,
and the "of course" (!) modality to reusable resources. But the key connective
for sequencing is the **linear implication** (⊸): `A ⊸ B` means "consume A to
produce B." In session terms: receive A, then continue with B.

This is exactly our `sess-recv(A, S)` — consume an A from the channel, then
continue with protocol S. The continuation structure of session types IS linear
implication applied repeatedly:

```
?A . ?B . !C . end  ≅  A ⊸ (B ⊸ (C ⊗ 1))
```

The sequencing comes from the nesting of implications. Each "consume" must
happen before the next one is available. This is a *proof-theoretic* ordering,
not a scheduling decision.

### 3c. Causality in Linear Logic (Abramsky, Melliès)

Research on causality in linear logic (Abramsky & Melliès) formalizes the
dependency structure of proofs using event structures. In proof nets
(the graph-theoretic presentation of linear logic), some inference rules can
commute (their order doesn't matter) and some cannot. The rules that cannot
commute have a causal dependency — one must happen before the other.

These causal dependencies form a partial order, and this partial order is
exactly the partial order of events in the corresponding process. For
session-typed processes, the causal dependencies are:

- **Sequential within a session**: `send x; recv y` — the send must precede the
  recv (they're on the same channel, in continuation order)
- **Independent across sessions**: operations on channel `a` are concurrent with
  operations on channel `b` (they're in separate proof branches)
- **Synchronized at joins**: `proc-par` with shared channels creates
  synchronization points

This is precisely the happens-before relation we need for effect ordering.

*Sources*:
- [Causality in Linear Logic](https://link.springer.com/chapter/10.1007/978-3-030-17127-8_9) — Hayman & Winskel
- [Games and Full Completeness for MLL](https://arxiv.org/abs/1311.6057) — Abramsky & Jagadeesan
- [Sequentiality vs. Concurrency in Games and Logic](https://arxiv.org/pdf/1111.7159) — Melliès

### 3d. Session Fidelity = Causal Consistency

Session type systems guarantee **session fidelity**: "session communications
follow the order prescribed by the protocol." This is not just a type safety
property — it is a causal consistency guarantee. A well-typed session process
respects the happens-before relation encoded in its session type.

Combined with type preservation (if `Γ ⊢ P` and `P → Q`, then `Γ ⊢ Q`) and
progress (well-typed processes either terminate or can make a step), session
types guarantee that effects happen in causal order and that all required
effects eventually happen.

*Sources*:
- [Session Fidelity and Deadlock Freedom](https://link.springer.com/chapter/10.1007/978-3-642-15375-4_16)
- [Comparing Deadlock-Free Session Typed Processes](https://eprints.gla.ac.uk/110759/1/110759.pdf)

---

## 4. The Galois Connection: Session Lattice ↔ Effect Lattice

### 4a. What Is the Effect Lattice?

We need to define what the "effect lattice" is before we can connect it to
sessions. For IO effects, we propose:

**Effect Position Lattice (EPL)**: A lattice that tracks the causal position of
an effect within a session timeline.

```
Elements:
  eff-bot             ⊥ — no effect information
  eff-pos(session-path, depth)   — effect at a specific position in a session
  eff-top             ⊤ — conflicting position information

where:
  session-path = sequence of session operations leading to this position
  depth = Nat — position index within the session chain
```

The ordering is flat within each session (positions don't refine each other)
but the *depth* provides a total order on positions within a single session:
`eff-pos(s, 0) < eff-pos(s, 1) < eff-pos(s, 2) < ...`

For multiple sessions (concurrent channels), positions form a partial order:
positions on different session paths are incomparable (concurrent), while
positions on the same path are totally ordered.

### 4b. The Galois Connection

We propose a Galois connection `(α, γ)` between the session lattice and the
effect position lattice:

```
α : Session → EffPos      (abstraction — extract effect position)
γ : EffPos  → Session      (concretization — what session state corresponds to this position?)

Adjunction: α(s) ≤ e  ⟺  s ≤ γ(e)
```

**α (Session → Effect Position)**: Given a session type at a cell, extract the
current position in the effect timeline.

```
α(sess-bot) = eff-bot                                   (no info → no position)
α(!A . S)   = eff-pos(path, depth)  where depth = session chain depth
α(?A . S)   = eff-pos(path, depth)  where depth = session chain depth
α(end)      = eff-pos(path, max-depth)                  (terminal position)
α(sess-top) = eff-top                                   (contradiction → conflict)
```

**γ (Effect Position → Session)**: Given an effect position, reconstruct the
remaining session protocol.

```
γ(eff-bot)            = sess-bot                         (no position → no session info)
γ(eff-pos(path, d))   = tail(original-session, d)        (session from position d onward)
γ(eff-top)            = sess-top                         (conflict → contradiction)
```

### 4c. Monotonicity of α and γ

Both functions must be monotone for the Galois connection to hold:

**α is monotone**: As the session cell refines (bot → concrete → advanced → end),
the effect position increases monotonically. Session advancement never goes
backward — once you've sent at position 0, you're at position 1 forever.
This follows from the monotonicity of the session lattice merge.

**γ is monotone**: As the effect position increases, the remaining session
"shrinks" (less protocol to execute). In the session lattice, this is an
increase in information (from "full protocol remaining" to "less protocol
remaining" to "end"). The concretization respects this ordering.

**Adjunction**: Knowing that an effect is at position `d` tells us at least as
much as knowing the session is at position `d` (the session carries more
information — what type to send/receive — but the position is the common
abstraction).

### 4d. What the Galois Connection Enables

With this connection formalized, we get:

1. **Effect cells that derive ordering from session cells**: An effect cell
   doesn't need its own timestamp. Its position is computed from the session
   cell's value via α. As the session advances monotonically, the effect
   position advances monotonically.

2. **Cross-domain propagators**: A bridge propagator between the session lattice
   and the effect lattice, analogous to the existing type/session bridge.
   When the session cell advances (e.g., `!String.?Int.end → ?Int.end`), the
   bridge propagator updates the effect cell (e.g., `eff-pos(ch, 0) → eff-pos(ch, 1)`).

3. **Soundness of effect ordering**: If the session type system is sound
   (session fidelity), then the derived effect ordering is sound. Effects at
   position `d` provably happen before effects at position `d+1`, because
   session advancement is provably monotone.

4. **Parallel effects fall out naturally**: Effects on different channels get
   incomparable positions (different session paths). The effect lattice's partial
   order correctly captures that these effects are concurrent and may execute in
   either order.

---

## 5. Architecture D: Session-Derived Effect Ordering

This section proposes a fourth architecture — one that the three architectures
in the effectful propagators research don't cover, because it derives ordering
from the session structure rather than imposing it externally.

### 5a. Overview

```
  Session Lattice                    Effect Position Lattice
  (session-lattice.rkt)              (NEW: effect-position.rkt)
  ┌─────────────────┐               ┌──────────────────────┐
  │ sess-bot         │  ──── α ────→ │ eff-bot               │
  │    ↓             │               │    ↓                  │
  │ !A . ?B . end    │  ──── α ────→ │ eff-pos(ch, 0)        │
  │    ↓ (advance)   │               │    ↓                  │
  │ ?B . end         │  ──── α ────→ │ eff-pos(ch, 1)        │
  │    ↓ (advance)   │               │    ↓                  │
  │ end              │  ──── α ────→ │ eff-pos(ch, 2)        │
  │    ↓             │               │    ↓                  │
  │ sess-top         │  ──── α ────→ │ eff-top               │
  └─────────────────┘               └──────────────────────┘
          ↑                                    │
          └──────────── γ ─────────────────────┘

  Bridge propagator: watches session cell, updates effect position cell via α
  Effect handler: watches effect position cells, executes effects in position order
```

### 5b. Session Advancement as Causal Clock

The key insight: **session advancement is a causal clock**.

In distributed systems, a Lamport clock increments at each event and each
message send/receive. A vector clock maintains per-process counters. These
provide causal ordering: if `clock(A) < clock(B)`, then A causally precedes B.

Session advancement is exactly this:
- Each session operation increments the session "position" by one
- Each send/recv on a channel is an event on that channel's timeline
- The session type's continuation depth IS the Lamport timestamp for that channel
- For multiple channels, the per-channel depths form a vector clock

```
Channel a: !String . ?Int . end          → positions: [0, 1, 2]
Channel b: ?Bool . !Nat . !Nat . end     → positions: [0, 1, 2, 3]

Vector clock at any program point:
  after send(a), recv(b):  {a: 1, b: 1}
  after recv(a), send(b):  {a: 2, b: 2}
  etc.
```

This vector clock is not imposed externally — it's *derived* from the session
type itself. The session type IS the causal structure.

### 5c. Process Structure Determines the Partial Order

For a process with multiple channels:

```prologos
proc a b =
  send "hello" a
  recv x b
  send x a
  stop
```

The session types determine the causal ordering:
- `send "hello" a` is at position `{a:0}`
- `recv x b` is at position `{a:0, b:0}` — concurrent with the send on `a`
  unless sequentially composed
- `send x a` is at position `{a:1}` — causally after the first send on `a`
- `stop` is at position `{a:2, b:1}` — causally after everything

But the *process structure* (sequential composition) adds more ordering:
the `recv x b` must happen before `send x a` because `x` flows from recv
to send. This data dependency is captured by the process AST, not by the
session types alone.

**Key observation**: Session types provide the *per-channel* causal order.
The process structure provides the *cross-channel* causal order. Together,
they give the complete happens-before relation for effects.

### 5d. The Effect Handler

With effect positions derived from session advancement:

```
Effect Execution Protocol:
1. Compile process → propagator network with session cells + effect position cells
2. Run session advancement propagators to quiescence
   (session cells advance, effect positions update via α bridge)
3. After quiescence: read all effect position cells
4. Sort effects by position (total order within a channel, partial order across channels)
5. Execute effects in position order
6. For concurrent effects (incomparable positions): execute in any order
   (they're on independent channels, so any interleaving is valid)
```

Step 6 is the crucial insight: **truly concurrent effects don't need ordering**.
Effects on different channels can execute in any order because they're on
independent resources (different files, different ports). The session type
system's duality guarantee ensures that the two endpoints of a channel agree
on the ordering, and the independence of separate channels ensures no
interference.

### 5e. Comparison with Architectures A-C

| Property | A (Barriers) | B (Timestamps) | C (Topo-Sort) | D (Session-Derived) |
|---|---|---|---|---|
| Ordering source | External (walk order) | External (syntactic position) | External (DAG construction) | Intrinsic (session types) |
| Soundness proof | By construction (sequential walk) | Needs verification | Needs verification | Follows from session fidelity |
| Concurrent effects | Not supported | Via vector timestamps | Via DAG independence | Via session independence |
| Effect-computation interleaving | None (batch) | At barriers | Between topo-levels | At session advancement points |
| Modification to propagator core | None | New cell type | New scheduler | New bridge propagator only |
| Session type integration | None | None | None | Deep (effects derive from sessions) |

Architecture D's distinctive advantage: **the ordering is a theorem, not a design decision**.
Given a sound session type system with session fidelity, the derived effect ordering
is provably correct. No additional verification is needed.

---

## 6. Deeper Implications: The Parameterised Monad View

### 6a. Session Types as Indexed Pre/Post Conditions

The connection between session types and parameterised monads (Atkey 2009,
Orchard & Yoshida 2016) reveals a deeper algebraic structure.

A parameterised monad `M s₁ s₂ a` represents a computation that:
- Starts in state `s₁` (precondition)
- Ends in state `s₂` (postcondition)
- Produces a value of type `a`

Sequential composition matches postcondition to precondition:
```
bind : M s₁ s₂ a → (a → M s₂ s₃ b) → M s₁ s₃ b
```

Session types are a natural instance of this structure:
```
send : M (!A.S) (S) A      — starts with send-A session, ends with S, produces A
recv : M (?A.S) (S) A      — starts with recv-A session, ends with S, receives A
close : M (end) () ()      — starts with end session, ends with ()
```

The session type IS the pre/post state. Sequential composition of session
operations IS the bind of the parameterised monad. The ordering is enforced
by the type system — you can't bind a `recv` after a `close` because the
postcondition `()` doesn't match the precondition `?A.S`.

*Sources*:
- [Parameterised Notions of Computation](https://www.researchgate.net/publication/220676480_Parameterised_notions_of_computation) — Atkey (2009)
- [Session Types with Linearity in Haskell](https://kar.kent.ac.uk/66632/1/RP_9788793519817C10.pdf) — Orchard & Yoshida (2016)
- [Unifying Graded and Parameterised Monads](https://arxiv.org/pdf/2001.10274) — Katsumata et al.

### 6b. The Effect Quantale Connection

Graded monads generalize monads to track effects algebraically. The effect
annotation forms a monoid (with sequential composition) and a partial order
(with effect subsumption):

```
return : a → G_ε a                      (pure computation, identity effect)
bind : G_i a → (a → G_j b) → G_{i⊕j} b  (composition, effects combine)
```

When the effect monoid has a partial order that interacts well with composition,
we get an **effect quantale** — an algebraic structure where:
- Effects form a lattice (partial order with joins)
- Sequential composition (⊕) distributes over joins
- The ordering respects composition: if `i ≤ i'` and `j ≤ j'`, then `i ⊕ j ≤ i' ⊕ j'`

Session types, viewed as effect annotations, form an effect quantale:
- The session lattice provides the partial order
- Session continuation is sequential composition: `(!A.S) ⊕ (?B.T) = !A.?B.T`
  (compose the first session's operation with the second session's protocol)
- The ordering respects composition (monotonicity of session lattice merge)

**This is the formal structure underlying the Galois connection.** The session
lattice and the effect position lattice are both effect quantales, and the
Galois connection (α, γ) is a quantale morphism — it preserves both the
ordering and the sequential composition.

*Sources*:
- [Effect Systems Revisited — Control-Flow Algebra and Semantics](https://www.cs.kent.ac.uk/people/staff/dao7/publ/effects-revisited.pdf) — Katsumata (2014)
- [Polymorphic Iterable Sequential Effect Systems](https://dl.acm.org/doi/fullHtml/10.1145/3450272) — Gordon (2021)

### 6c. The Category-Graded Monad Unification

Recent work by Katsumata, Orchard et al. unifies graded monads (effect systems)
and parameterised monads (program logics, session types) into a single framework:
**category-graded monads**.

In this framework, a category-graded monad is indexed by morphisms from a small
category C. When C is a discrete category (objects only, no arrows), it degenerates
to a graded monad. When C is the category of states and transitions, it degenerates
to a parameterised monad.

Session types correspond to the case where C is the category of session states
(session types are objects, session operations are morphisms). Effect annotations
correspond to the case where C is the effect monoid.

The Galois connection between sessions and effects is, categorically, a functor
between these two indexing categories — mapping session transitions to effect
compositions while preserving the categorical structure.

*Source*:
- [Unifying Graded and Parameterised Monads](https://arxiv.org/pdf/2001.10274)

---

## 7. Interaction with Our Existing Infrastructure

### 7a. The Cross-Domain Bridge Pattern

We already have Galois connections in the propagator network:
- Type lattice ↔ Session lattice bridge (`session-propagators.rkt`, S4e)
- Type lattice ↔ Interval lattice bridge (from the Galois connections work)

Adding a Session lattice ↔ Effect Position lattice bridge follows the same
pattern:

```racket
;; effect-position-bridge.rkt (hypothetical)

;; Bridge propagator: session cell → effect position cell
(define (add-session-effect-bridge net sess-cell effect-cell channel-path)
  (net-add-propagator net
    (list sess-cell)
    (list effect-cell)
    (lambda (n)
      (define sess-val (net-cell-read n sess-cell))
      (cond
        [(sess-bot? sess-val) n]
        [else
         (define depth (session-depth sess-val))
         (net-cell-write n effect-cell
           (eff-pos channel-path depth))]))))

;; session-depth: count continuation nesting
(define (session-depth s)
  (match s
    [(sess-send _ cont) (add1 (session-depth cont))]
    [(sess-recv _ cont) (add1 (session-depth cont))]
    [(sess-dsend _ cont) (add1 (session-depth cont))]
    [(sess-drecv _ cont) (add1 (session-depth cont))]
    [(sess-end) 0]
    [(sess-mu body) (session-depth body)]
    [_ 0]))
```

### 7b. Integration with compile-live-process

Today's `compile-live-process` walks the AST sequentially and executes IO inline.
With Architecture D, it would:

1. Walk the AST as before, installing session advancement propagators
2. Additionally install session-effect bridge propagators
3. Collect effect descriptors (without executing them)
4. After quiescence, execute effects in position order

The session advancement propagators already exist. The bridge propagators are
new but follow an established pattern. The effect collection and execution
are the novel components.

### 7c. The ATMS Connection for Speculative Effects

With session-derived positions, speculative effects become well-defined:

- The ATMS tracks alternative worldviews (§5.4 of the logic engine design)
- Each worldview has its own session advancement (different choices lead to
  different session states)
- Effect positions in one worldview may differ from positions in another
- Effects are only executed for the *chosen* worldview (after consistency
  filtering)

This connects to the research question §9d from the effectful propagators
document: the ATMS enables hypothetical effects, and session-derived positions
provide the ordering within each hypothesis.

---

## 8. The Session-Effect Duality

### 8a. An Observation

The duality operator on session types (`dual`) swaps send ↔ recv, choice ↔ offer.
What happens to effect positions under duality?

```
Session:     !String . ?Int . end
Dual:        ?String . !Int . end

Positions:   [0: write, 1: read, 2: close]
Dual pos:    [0: read,  1: write, 2: close]
```

The dual session has the *same positions* but *different effects* at each
position. This is exactly right: the two endpoints of a channel perform
complementary effects at the same logical moments.

Effect duality: if endpoint A writes at position 0, endpoint B reads at
position 0. The positions are synchronized (they're the same logical clock),
but the effects are dual.

### 8b. Implications for IO

For IO channels (where one endpoint is the file system), the dual of the
process's session type is the "file's session type" — what the file expects.
If the process sends a string (write), the file receives a string (append to
file). If the process receives (read), the file sends (provide file contents).

The IO bridge propagator already implements this duality implicitly: it watches
for `sess-send` to know when to write and `sess-recv` to know when to read.
Architecture D would make this correspondence explicit through the effect
position lattice.

---

## 9. Challenges and Open Questions

### 9a. Recursive Sessions and Infinite Timelines

Recursive session types (`sess-mu`) produce potentially infinite causal
timelines. The position counter would grow without bound:

```
μt. !Nat . t       → positions: [0, 1, 2, 3, ...]
```

This doesn't break the Galois connection (positions still form a well-ordered
chain), but it means:
- Effect cells can't be allocated statically for all positions
- The bridge propagator must create fresh effect cells during unfolding
- Widening may be needed if the effect lattice has infinite ascending chains

One approach: use **modular positions** — positions modulo the recursion depth.
The recursive session `μt. !Nat . t` has period 1, so positions 0, 1, 2, ...
all have the same structure. The effect handler needs only the current and next
positions, not the entire history.

### 9b. Choice and Non-Deterministic Sessions

Session choice (`sess-choice`) introduces branching in the causal timeline:

```
⊕{left: !String . end, right: !Int . end}
```

After the choice, the timeline follows one branch. Effect positions on unchosen
branches are unreachable.

This connects to the ATMS: each choice branch is a hypothesis. Effect positions
in each branch are well-defined; the chosen branch's effects are executed;
the unchosen branch's effects are discarded (nogoods prevent their execution).

### 9c. Data Dependencies Across Channels

Session types capture per-channel ordering but not cross-channel data flow.
Consider:

```
recv x a           → position {a: 0}
send [f x] b       → position {b: 0}
```

Here `x` flows from channel `a` to channel `b`. The session types on `a` and `b`
are independent, but the data dependency creates a cross-channel ordering
constraint: `recv x a` must happen before `send [f x] b`.

This ordering is captured by the process structure (sequential composition in
the AST), not by the session types. Architecture D captures it through the
vector clock: after processing the recv, the vector clock is `{a:1, b:0}`.
After the send, it's `{a:1, b:1}`. The happens-before relation
`{a:1, b:0} < {a:1, b:1}` is correct.

But the propagator network doesn't see this data dependency unless it's
encoded explicitly. The process AST walk provides it (it processes recv before
send because they're sequentially composed). Whether the propagator network
can capture this without the walk is the key question for a fully
propagator-native implementation.

### 9d. When Sessions Don't Cover All Effects

Not all effects are associated with session channels. Top-level `eval`
expressions with `SysCap` perform IO outside of any session. These effects
have no session type to derive ordering from.

For these cases, Architecture D falls back to Architecture A (barriers) or
Architecture B (timestamps). The session-derived ordering handles session-bound
effects; unsessioned effects use the walk-order fallback.

This is acceptable — the session type system is designed for structured IO,
and unstructured IO (top-level eval with SysCap) is intentionally less
disciplined. The type system correctly reflects this: session-typed IO has
stronger guarantees than SysCap IO.

---

## 10. Relationship to the Three Existing Architectures

Architecture D doesn't replace A, B, or C — it *subsumes* B and provides a
theoretical foundation for all three:

| Architecture | Effect Ordering Source | When to Use |
|---|---|---|
| A (Barriers) | AST walk order | Top-level effects, unstructured IO, Phase 0 |
| B (Timestamps) | Syntactic position | General effects, needs external timestamp assignment |
| C (Topo-Sort) | DAG of effect dependencies | Complex effect graphs, research-level |
| D (Session-Derived) | Session type structure | Session-typed IO (the common case) |

Architecture D is strictly more informative than B for session-typed effects:
timestamps must be assigned externally, while session positions are intrinsic.
For unsessioned effects, D degenerates to A or B.

The recommended layering:

```
Layer 0: Propagator Network (monotone fixed points)         [exists]
Layer 1: Session Lattice (protocol verification)            [exists]
Layer 2: Effect Position Lattice (session-derived ordering)  [NEW]
Layer 3: Effect Handler (sequential execution in position order) [NEW]
Fallback: AST Walk (for unsessioned effects)                [exists]
```

---

## 11. Formalization Roadmap

If we pursue Architecture D, the implementation would proceed:

### Phase D1: Effect Position Lattice (Small, Self-Contained)
- Define `eff-bot`, `eff-pos(path, depth)`, `eff-top`
- Implement `eff-merge`, `eff-contradicts?`
- Tests: lattice properties (bot identity, idempotent, top absorption)

### Phase D2: Session-Effect Bridge Propagator
- Implement `α` (session → effect position) and `γ` (effect position → session)
- Bridge propagator: watches session cell, updates effect cell
- Tests: bridge fires correctly on session advancement

### Phase D3: Effect Descriptor Cells
- Define effect descriptors: `eff-write(data)`, `eff-read`, `eff-close`, `eff-open(path, mode)`
- Effect descriptor cells with position + descriptor
- Tests: descriptors accumulate monotonically

### Phase D4: Effect Handler
- Read all effect descriptor cells after quiescence
- Sort by position (total within channel, partial across channels)
- Execute in order, feeding results back
- Tests: end-to-end IO through session-derived ordering

### Phase D5: Vector Clock for Multi-Channel
- Extend positions to vectors for multi-channel processes
- Partial order for concurrent effects
- Tests: concurrent channel effects in correct order

---

## 12. Conclusions

### 12a. The Core Discovery

Session types are not just protocol specifications — they are **causal clocks**.
The continuation structure of a session type encodes a total order on effects
per channel, and the independence of separate session types encodes concurrency.
Together, they provide a vector-clock-like causal ordering that is:

1. **Intrinsic**: Derived from the session type, not imposed externally
2. **Sound**: Follows from session fidelity (a theorem, not a design choice)
3. **Compositional**: Multiple channels compose via vector clocks
4. **Compatible with monotone propagation**: Session advancement is monotone;
   effect position derivation via α is monotone; both live happily in the
   propagator network

### 12b. The Galois Connection

The Galois connection `(α, γ)` between the session lattice and the effect
position lattice formalizes this relationship:

- α extracts ordering information from session types
- γ reconstructs session context from ordering information
- The adjunction guarantees soundness: session fidelity implies effect ordering

This connection is a quantale morphism between two effect quantales, reflecting
the deep algebraic structure shared by session types and effect systems.

### 12c. Architecture D as Natural Extension

Architecture D (Session-Derived Effect Ordering) emerges as a natural
extension of our existing infrastructure:

- The session lattice already exists
- Session advancement propagators already exist
- Cross-domain bridge propagators are an established pattern
- The effect position lattice is a simple new lattice
- The bridge propagator follows the existing Galois connection pattern

The novel contribution is recognizing that session types provide what
timestamps and barriers provide externally — but with stronger guarantees
(soundness from session fidelity) and tighter integration (effect ordering
is a property of the type system, not the scheduler).

---

## References

### Prologos Internal
- Effectful Propagators Research: `docs/tracking/2026-03-06_EFFECTFUL_PROPAGATORS_RESEARCH.md`
- IO Implementation PIR: `docs/tracking/2026-03-06_IO_IMPLEMENTATION_PIR.md`
- Galois Connections & AI: `docs/tracking/2026-02-27_1026_GALOIS_CONNECTIONS_ABSTRACT_INTERPRETATION.md`
- Logic Engine Design: `docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org`
- Session Type Design: `docs/tracking/2026-03-03_SESSION_TYPE_DESIGN.md`
- Session Type PIR: `docs/tracking/2026-03-04_SESSION_TYPE_PIR.md`

### Foundational
- [Propositions as Sessions](https://homepages.inf.ed.ac.uk/wadler/papers/propositions-as-sessions/propositions-as-sessions.pdf) — Wadler (ICFP 2012)
- [Linear Logic Propositions as Session Types](https://www.cs.cmu.edu/~fp/papers/mscs13.pdf) — Caires & Pfenning (MSCS 2012)
- [Session Types as Intuitionistic Linear Propositions](https://link.springer.com/chapter/10.1007/978-3-642-15375-4_16) — Caires & Pfenning (CONCUR 2010)
- [Cut Reduction as Asynchronous Session-Typed Communication](https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.CSL.2012.228) — DeYoung, Caires, Pfenning, Toninho (CSL 2012)

### Causality and Linear Logic
- [Causality in Linear Logic](https://link.springer.com/chapter/10.1007/978-3-030-17127-8_9) — Hayman & Winskel (FoSSaCS 2019)
- [Games and Full Completeness for MLL](https://arxiv.org/abs/1311.6057) — Abramsky & Jagadeesan
- [Sequentiality vs. Concurrency in Games and Logic](https://arxiv.org/pdf/1111.7159) — Melliès

### Effect Systems and Graded Monads
- [Parameterised Notions of Computation](https://www.researchgate.net/publication/220676480_Parameterised_notions_of_computation) — Atkey (JFP 2009)
- [Session Types with Linearity in Haskell](https://kar.kent.ac.uk/66632/1/RP_9788793519817C10.pdf) — Orchard & Yoshida (2016)
- [Unifying Graded and Parameterised Monads](https://arxiv.org/pdf/2001.10274) — Katsumata, Orchard et al.
- [Effect Systems Revisited](https://www.cs.kent.ac.uk/people/staff/dao7/publ/effects-revisited.pdf) — Katsumata (2014)
- [Polymorphic Iterable Sequential Effect Systems](https://dl.acm.org/doi/fullHtml/10.1145/3450272) — Gordon (TOPLAS 2021)
- [Data-Flow Analyses as Effects and Graded Monads](https://kar.kent.ac.uk/81880/1/dataflow-effect-monads.pdf) — Orchard et al.

### Session Type Properties
- [Comparing Type Systems for Deadlock Freedom](https://eprints.gla.ac.uk/262401/1/262401.pdf) — Kokke et al.
- [Manifest Deadlock-Freedom for Shared Session Types](https://www.cs.cmu.edu/~balzers/publications/manifest_deadlock_freedom.pdf) — Balzer et al.
- [Deadlock-Free Session Types in Linear Haskell](https://arxiv.org/pdf/2103.14481) — Kokke (2021)

### Propagators and CRDTs
- [Revised Report on the Propagator Model](https://groups.csail.mit.edu/mac/users/gjs/propagators/) — Radul & Sussman
- [CRDTs (Wikipedia)](https://en.wikipedia.org/wiki/Conflict-free_replicated_data_type)
- [Vector Clocks (Wikipedia)](https://en.wikipedia.org/wiki/Vector_clock)
- [Kmett's Propagators (GitHub)](https://github.com/ekmett/propagators)
