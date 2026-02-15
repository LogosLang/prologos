# Prologos Maude Tutorial

A hands-on guide to understanding the Prologos formal specification: quantitative type theory meets session types.

## What You'll Learn

By the end of this tutorial, you will be able to:

- Read and write Maude specifications
- Understand dependent type theory fundamentals
- Work with de Bruijn indices and locally-nameless representation
- Explore quantitative type theory (QTT) and resource tracking
- Understand session types and process calculi
- Run and experiment with the Prologos type checker

## Prerequisites

- Basic functional programming knowledge
- Familiarity with type systems (e.g., TypeScript, Haskell)
- No prior Maude or type theory experience required

## Time Estimate

2-3 hours for complete walkthrough, 30 minutes for quick overview (sections 1-6)

## Setup

1. Install Maude: http://maude.cs.illinois.edu/
2. Clone the repository
3. Load the test suite (which loads all modules): `maude prologos-tests.maude`
4. You're ready to experiment!

---

## 0. Why Prologos? The Problems We're Solving

Before diving into syntax and rules, let's talk about *why* this language exists. Prologos addresses five categories of bugs that conventional type systems cannot catch.

### The Bug Catalog

**1. The out-of-bounds crash** *(motivates dependent types)*

You have an array of 10 elements and an index from user input. In C, Python, Java -- this is a runtime bounds check at best, a buffer overflow at worst. The type says `int[]`, which tells you nothing about length.

In Prologos: `vindex : Vec(A, n) -> Fin(n) -> A`. The vector knows its length (`n`) at the type level. The index is a `Fin(n)` -- a number *proven* to be less than `n`. Out-of-bounds access is not a runtime error; it's a type error that can't compile.

*Real-world applications*: Database column indices, API pagination offsets, buffer operations in network protocols, matrix dimensions in scientific computing.

**2. The double-free / use-after-close** *(motivates linear types, QTT `m1`)*

A file handle is opened, passed to two functions, and closed in both. Or worse: closed in one function, then written to in another. The type says `FileHandle`, which tells you nothing about its lifecycle.

In Prologos: marking the handle as `m1` (linear) means the type checker enforces that it's used exactly once. Closing it consumes the handle. A second use -- whether a second close or a read after close -- is a type error.

*Real-world applications*: File handles, database connections, network sockets, mutex locks, memory allocators, channel endpoints in concurrent systems.

**3. The leaked secret** *(motivates erasure, QTT `m0`)*

An API key is passed to a function for authentication. That function logs its arguments for debugging. The API key appears in plain text in production logs. The type says `String`, which tells you nothing about sensitivity.

In Prologos: marking the key as `m0` (erased) means it exists only during type checking and is completely absent at runtime. Any attempt to log it, serialize it, or include it in a computation is a type error.

*Real-world applications*: Passwords, encryption keys, PII (personally identifiable information), authentication tokens, any value that must never appear in logs, crash dumps, or error messages.

**4. The protocol violation** *(motivates session types)*

A client sends "withdraw $500" before sending "authenticate." A payment gateway sends a success response in a format the client doesn't expect. An API consumer calls endpoints in the wrong order, hitting a 403 that could have been prevented.

In Prologos: the communication protocol is a type. `send(Credentials, recv(AuthResult, ...))` says "first send credentials, then receive an auth result, then continue." The type checker verifies that both sides follow this protocol. Sending a withdrawal before authenticating is a type error -- it cannot compile.

*Real-world applications*: REST API call sequences, OAuth handshakes, payment processing flows, WebSocket message protocols, database transaction lifecycles, gRPC streaming contracts.

**5. The impossible state** *(motivates dependent types generally)*

A configuration struct has `mode: "production"` and `debug_logging: true` -- a combination that should never exist. A state machine is in state "completed" but has a null result field. A protocol message has `count: 3` but only 2 items in its payload.

In Prologos: dependent types let you express constraints *between* fields. The type of the payload list depends on the value of the count field. Inconsistent states don't just fail at runtime -- they're not representable in the type system at all.

*Real-world applications*: Configuration validation, state machine invariants, protocol message well-formedness, database schema constraints expressed at the type level.

### The Unifying Vision: Types as Contracts

These aren't five separate features bolted together. They're three facets of a single idea: **making invalid states unrepresentable**.

- **Dependent types** = contracts about *values* ("this list has exactly 5 elements")
- **Linear types (QTT)** = contracts about *usage* ("this handle is consumed exactly once")
- **Session types** = contracts about *communication* ("these messages arrive in this order")

Most languages give you only the first dimension, and even then only partially (`int` vs `string`, but not "list of length 5"). Prologos gives you all three dimensions in a single unified type system where they interact naturally: you can have a linear channel that carries dependent session types with erased type parameters. The combination is greater than the sum of its parts.

### Why a Formal Specification?

This Maude codebase isn't a prototype compiler -- it's a **verified design oracle**. Every typing rule, every reduction step, every duality law is an executable equation that we can test, modify, and query.

This matters because:
- The specification *is* the language. There is no ambiguity gap between a paper description and the implementation.
- You can *ask questions*: "Does this term type-check?" is a Maude `reduce` command, not a guess.
- You can *experiment safely*: Change a rule, run the test suite, instantly see what breaks.
- You can *build from it*: The Phase 1 Racket compiler will implement exactly these rules, and we'll know it's correct because the rules are already tested.

This approach is proven in industry: Amazon uses TLA+ to verify AWS service designs. Airbus uses formal methods for flight control software. The Ethereum Foundation uses formal verification for smart contract correctness. Prologos follows the same philosophy: specify first, verify the specification, then implement with confidence.

---

## 1. Reading Maude: A 10-Minute Crash Course

### Why Maude? (And Why Not Just Write a Compiler?)

Before building a language, we want to know it's *correct*. A compiler in Python or Rust gives you an implementation -- but how do you know the type checker is right? How do you know linear variables are actually tracked? How do you know the session type rules are sound?

Maude gives us an **executable specification**. Every typing rule is a rewrite equation. If the equation is wrong, we see it immediately -- we can test every rule independently. This is the same approach used in:
- **TLA+ at Amazon** -- modeling distributed systems before building them
- **Alloy at MIT** -- finding bugs in software designs before writing code
- **K Framework** -- defining programming language semantics formally

You don't need to learn Maude deeply. You need about 10 minutes of syntax (below) and then you can read every rule in Prologos as "if this pattern matches, rewrite to that result."

### What is Maude?

Maude is a rewriting logic language perfect for formal specifications. Think of it as:
- A pattern matcher on steroids
- An executable algebra system
- A term rewriter that evaluates expressions by repeatedly applying equations

### Basic Maude Syntax

```maude
fmod MY-MODULE is
  sort MyType .                    --- Declare a type
  op constructor : -> MyType .     --- Declare a constant
  op function : MyType -> MyType . --- Declare a function

  var X : MyType .                 --- Declare a variable
  eq function(constructor) = constructor .  --- Rewrite rule
endfm
```

**Key concepts:**
- `sort` = type declaration
- `op` = function/constructor declaration
- `[ctor]` = this is a constructor (data)
- `eq` = equation/rewrite rule
- `var` = pattern variable in equations

### Running Maude

```maude
red expression .    --- "reduce" - evaluates expression to normal form
```

That's 90% of what you need! Let's dive in.

---

## 2. The Big Picture: What is Prologos?

Prologos is a **dependently-typed lambda calculus** that unifies four layers of safety into a single type system. Each layer catches a different class of bugs:

### Four Layers of Safety

**Layer 1 -- Values in types (Dependent types)**
"The function returns a list of length 5. The type system *guarantees* it has exactly 5 elements."

Dependent types let types mention values. `Vec(Nat, 5)` isn't just "a list of numbers" -- it's "a list of numbers with exactly 5 elements." The type checker verifies these constraints at compile time, eliminating out-of-bounds errors, length mismatches, and impossible states.

**Layer 2 -- Resources in types (QTT)**
"The function uses the database connection exactly once. The type system *guarantees* it doesn't leak or alias it."

Quantitative Type Theory tracks how many times each variable is used: zero times (`m0`, erased), exactly once (`m1`, linear), or any number of times (`mw`, unrestricted). This catches resource leaks, double-free bugs, and accidental exposure of secrets.

**Layer 3 -- Protocols in types (Session types)**
"The client sends authentication, then a query, then receives a response. The type system *guarantees* both sides follow this protocol."

Session types describe communication protocols as types. The type checker verifies that every send has a matching receive, that messages arrive in the right order, and that all protocol branches are handled.

**Layer 4 -- Concurrency in types (Process calculus)**
"Two processes share a channel. The type system *guarantees* they don't interfere or deadlock."

Process typing ensures that concurrent programs use channels linearly and follow their session protocols. Channels are split correctly across parallel processes with no aliasing.

### When Would You Reach for Each Feature?

| Problem | Feature | Example |
|---------|---------|---------|
| "Can this index go out of bounds?" | Dependent types (`Vec`/`Fin`) | API pagination, buffer access |
| "Can this resource be used after release?" | QTT (`m1`) | DB connections, file handles |
| "Can this secret appear in logs?" | QTT (`m0`) | Passwords, API keys, PII |
| "Can these messages arrive out of order?" | Session types | Payment flows, OAuth, WebSocket |
| "Can these concurrent tasks interfere?" | Process typing | Microservice coordination |

### Module Architecture

```
prologos-prelude.maude         -- Multiplicities, universe levels
    |
prologos-syntax.maude          -- Terms and contexts
    |
prologos-substitution.maude    -- Variable substitution
    |
prologos-reduction.maude       -- Beta reduction, normalization
    |
prologos-typing-core.maude     -- Type checking
    |
prologos-inductive.maude       -- Vec, Fin families
    |
prologos-qtt.maude             -- Resource tracking
    |
prologos-sessions.maude        -- Session types
    |
prologos-processes.maude       -- Process terms
    |
prologos-typing-sessions.maude -- Process type checking
```

We'll walk through each module, understanding **what it does**, **how it works in Maude**, and **why it matters**.

---

## 3. Multiplicities: The Resource Semiring

**File:** `prologos-prelude.maude`

### Why This Matters: The Resource Bug Hall of Fame

In 2014, the Heartbleed bug in OpenSSL leaked server memory because a buffer was read beyond its allocated bounds -- a resource tracking failure that exposed passwords, private keys, and session tokens from hundreds of thousands of servers. Resource management bugs aren't exotic edge cases; they're among the most common and costly defects in production software.

Multiplicities give the type system a vocabulary for **resource discipline**:

**`m0` (erased) -- "This exists only at compile time."** Use case: type-level proofs, type parameters like `A` in `identity : (A : Type)^0 -> A -> A`. The `^0` means `A` is never inspected at runtime -- it's erased completely. This matters for cryptographic secrets that must not persist in memory, type parameters in generic code (no runtime cost for polymorphism), and proof terms that guide the type checker but vanish from compiled output.

**`m1` (linear) -- "Use this exactly once."** Use case: file handles, database connections, channel endpoints, or any resource with an acquire/release lifecycle. The `^1` annotation means the compiler rejects any code path that uses the resource zero times (leak) or more than once (aliasing). This prevents double-free, use-after-close, resource leaks, and aliased mutation.

**`mw` (unrestricted) -- "Use this however you like."** Use case: ordinary values like numbers, strings, booleans. Most variables in most programs are unrestricted. The `^w` annotation means no resource tracking -- this is the default in conventional languages. QTT's insight is that unrestricted should be *opt-in* at the type level, not an invisible assumption.

### The Concept

In quantitative type theory, every variable has a **multiplicity** annotation:

- `m0` (zero): Variable is **erased** at runtime, used only for types/proofs
- `m1` (one): Variable used **exactly once** (linear/affine)
- `mw` (omega): Variable used **unrestricted** times

This lets us track resources: ensure secrets aren't duplicated, files aren't closed twice, etc.

### The Maude Definition

```maude
sort Mult .
ops m0 m1 mw : -> Mult [ctor] .
```

Three constructors, no arguments. Simple!

### Semiring Operations

Addition (`+m`): Combines usages
```maude
op _+m_ : Mult Mult -> Mult [comm] .
eq m0 +m m0 = m0 .  eq m0 +m m1 = m1 .  eq m0 +m mw = mw .
eq m1 +m m1 = mw .  eq m1 +m mw = mw .  eq mw +m mw = mw .
```

**Intuition:** If you use a variable once in branch A and once in branch B, you've used it twice total:
- `m1 +m m1 = mw` (once + once = unrestricted)
- `m0 +m m1 = m1` (erased + once = once)

Multiplication (`*m`): Scales usage
```maude
eq m0 *m m0 = m0 .  eq m0 *m m1 = m0 .  eq m0 *m mw = m0 .
eq m1 *m m1 = m1 .  eq m1 *m mw = mw .  eq mw *m mw = mw .
```

**Intuition:** If you use variable `x` with multiplicity `π` inside a context used `ρ` times, total usage is `π * ρ`:
- `m1 *m m1 = m1` (once inside once = once)
- `m0 *m mw = m0` (erased, even if in unrestricted context)

### Try It!

```maude
red m1 +m m1 .
--- Result: mw

red m0 *m mw .
--- Result: m0
```

### Ordering and Compatibility

```maude
op _<=m_ : Mult Mult -> Bool .
eq m0 <=m m0 = true . eq m0 <=m m1 = true . eq m0 <=m mw = true .
--- ... (m0 <= everything)
```

**Ordering:** `m0 <= m1 <= mw` (you can use less than declared)

```maude
op compatible : Mult Mult -> Bool .
eq compatible(m0, m0) = true .
eq compatible(m1, m1) = true .
eq compatible(mw, m0) = true . eq compatible(mw, m1) = true . eq compatible(mw, mw) = true .
--- All others false
```

**Compatible:** Can actual usage match declared usage?
- `compatible(m1, m1) = true` ✓ (declared linear, used linear)
- `compatible(m1, mw) = false` ✗ (declared linear, used many times)
- `compatible(mw, m1) = true` ✓ (declared unrestricted, used once - OK!)

---

## 4. Universe Levels

### Why This Matters: Preventing Self-Reference Paradoxes

If `Type : Type` (a type is its own type), the entire type system becomes inconsistent -- you can prove anything, including false. This is Girard's paradox (1972), and it's not just a theoretical curiosity: it means your type checker could accept bogus programs as valid, silently destroying every guarantee the type system provides.

Universe levels are the fix: `Type(0) : Type(1) : Type(1) : Type(2) : ...` Each level contains the types of the level below, but not itself. This is the same solution used in Agda, Coq, and Lean.

**When does this matter practically?** Mostly when you write highly generic code -- functions that take types as arguments, or types that contain other types. In day-to-day Prologos programming, most terms live at level 0. Think of universe levels as "plumbing that keeps the foundation sound" -- you rarely interact with them directly, but their presence is what makes the rest of the system trustworthy.

For this tutorial, you can treat `Type(lzero)` as "the type of ordinary types" and move on.

Still in `prologos-prelude.maude`:

```maude
sort Level .
op lzero : -> Level [ctor] .
op lsuc : Level -> Level [ctor] .
```

**Why?** To avoid Girard's paradox, we have a hierarchy:
- `Type(0) : Type(1) : Type(2) : ...`
- Prevents `Type : Type` (inconsistent!)

```maude
op lmax : Level Level -> Level .
eq lmax(lzero, L) = L .
eq lmax(lsuc(L1), lsuc(L2)) = lsuc(lmax(L1, L2)) .
```

**Try it:**
```maude
red lmax(lzero, lsuc(lzero)) .
--- Result: lsuc(lzero)

red lmax(lsuc(lzero), lsuc(lzero)) .
--- Result: lsuc(lzero)
```

Most examples use `lzero` (level 0). This is foundational plumbing.

---

## 5. Terms and Variables: The Locally-Nameless Approach

**File:** `prologos-syntax.maude`

### Why This Matters: The Naming Problem

Variable names seem simple, but they're the source of subtle, persistent bugs in language implementations:

**The capture problem**: In `(lam x. lam y. x) y`, naive substitution gives `lam y. y` -- but the `y` in the body now refers to the *wrong* variable! This is called "variable capture" and it has caused bugs in real compilers, theorem provers, and symbolic math systems.

**The alpha-equivalence problem**: Are `lam x. x` and `lam y. y` the same function? Yes -- but string comparison says no. Every operation that compares terms needs to handle renaming, which means every operation is a potential bug site.

De Bruijn indices solve both problems mechanically:
- **No capture**: Variables are numbers, not names. Substitution never confuses which binder a variable refers to.
- **No alpha-equivalence**: `lam. 0` is the unique representation of the identity function. Syntactic equality IS alpha-equivalence.

The trade-off is readability -- `bvar(1)` is less clear than `x` to human readers. Prologos mitigates this with the **locally-nameless hybrid**: bound variables use indices (for correctness), free variables use names (for readability). This is the standard approach in mechanized metatheory (Charguéraud 2012, "The Locally Nameless Representation").

As you read the tutorial, when you see `bvar(0)` think "the nearest enclosing lambda's argument." When you see `bvar(1)`, think "the argument of the lambda one level out."

### The Challenge

How do we represent lambda terms in a computer?

```
λx. x          --- Named
λ. 0           --- De Bruijn indices
λ. bvar(0)     --- Locally-nameless
```

### De Bruijn Indices

Instead of names, use **numbers** indicating "how many binders out":

```
λx. x                    → λ. 0
λx. λy. x                → λ. λ. 1
λx. λy. y                → λ. λ. 0
λx. λy. x y              → λ. λ. (1 0)
λf. λx. f (f x)          → λ. λ. (1 (1 0))
```

**Key insight:** Variable refers to the **N-th enclosing binder** (counting from 0).

### Locally-Nameless Hybrid

Prologos uses:
- **Bound variables**: de Bruijn indices `bvar(N)`
- **Free variables**: named `fvar('x)`

```maude
op bvar : Nat -> Expr [ctor] .  --- Bound (de Bruijn)
op fvar : Qid -> Expr [ctor] .  --- Free (named)
```

**Why?** Best of both worlds:
- Bound vars: easy substitution, no capture
- Free vars: readable top-level definitions

### Term Constructors

```maude
sort Expr .

--- Natural numbers
op zero : -> Expr [ctor] .
op suc : Expr -> Expr [ctor] .

--- Lambda calculus
op lam : Mult Expr Expr -> Expr [ctor] .
op app : Expr Expr -> Expr [ctor] .

--- Products
op pair : Expr Expr -> Expr [ctor] .
op fst : Expr -> Expr [ctor] .
op snd : Expr -> Expr [ctor] .

--- Equality
op refl : -> Expr [ctor] .

--- Type formers
op Type : Level -> Expr [ctor] .
op Nat : -> Expr [ctor] .
op Pi : Mult Expr Expr -> Expr [ctor] .
op Sigma : Expr Expr -> Expr [ctor] .
op Eq : Expr Expr Expr -> Expr [ctor] .
```

**Examples:**

Identity function: `λx:Nat. x`
```maude
lam(mw, Nat, bvar(0))
```
- `mw`: argument used unrestricted times
- `Nat`: argument type
- `bvar(0)`: body refers to the 0th binder (the lambda itself)

Constant function: `λx:Nat. λy:Nat. x`
```maude
lam(mw, Nat, lam(mw, Nat, bvar(1)))
```
- Outer lambda is binder 1
- Inner lambda is binder 0
- Body `bvar(1)` refers to outer binding

### Dependent Function Types

```maude
op Pi : Mult Expr Expr -> Expr [ctor] .
```

`Pi(π, A, B)` represents `(x : A) →^π B` where:
- `π`: multiplicity of `x`
- `A`: domain type
- `B`: codomain type (may mention `bvar(0)` = `x`)

**Example:** `(n : Nat) → Vec Nat n`
```maude
Pi(mw, Nat, Vec(Nat, bvar(0)))
```
The result type `Vec(Nat, bvar(0))` depends on the argument `n`.

**Non-dependent shorthand:**
```maude
op _-->_ : Expr Expr -> Expr .
eq A --> B = Pi(mw, A, B) .
```

So `Nat --> Nat` expands to `Pi(mw, Nat, Nat)`.

### Try It!

```maude
red Nat --> Nat .
--- Result: Pi(mw, Nat, Nat)

red lam(mw, Nat, bvar(0)) .
--- Result: lam(mw, Nat, bvar(0))
```

---

## 6. Contexts: The Typing Environment

### Why This Matters: What the Type Checker Knows

A context is the type checker's memory -- it records what variables are in scope, what types they have, and how they may be used. In a conventional language, this is the "symbol table" that the compiler builds as it walks your code.

The key difference in Prologos: contexts also track **multiplicities**. The context doesn't just say "variable 0 has type `Nat`" -- it says "variable 0 has type `Nat` and may be used at most once (`m1`)." This is what enables the resource tracking described in Section 3. When the QTT checker (Section 11) verifies usage, it compares actual usage against the multiplicity declared in the context.

```maude
sort Context .
op empty : -> Context [ctor] .
op extend : Context Expr Mult -> Context [ctor] .
```

A context is a **stack of type bindings**:
```
Γ = empty
Γ = extend(extend(empty, Nat, mw), Bool, m1)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ inner
                                             ^^^ outer
```

Reading right-to-left (most recent first):
- Variable 0: `Bool` with multiplicity `m1`
- Variable 1: `Nat` with multiplicity `mw`

### Lookup Operations

```maude
op lookupType : Nat Context -> Expr .
eq lookupType(0, extend(G, T, M)) = T .
eq lookupType(s K, extend(G, T, M)) = lookupType(K, G) .
```

**Example:**
```maude
red lookupType(0, extend(extend(empty, Nat, mw), Bool, m1)) .
--- Result: Bool

red lookupType(1, extend(extend(empty, Nat, mw), Bool, m1)) .
--- Result: Nat
```

**Critical insight:** When we look up `bvar(K)`, we must **shift** the result by `K+1` because the type was defined in a shorter context. More on this in the next section!

---

## 7. Substitution: The Heart of Lambda Calculus

**File:** `prologos-substitution.maude`

### The Problem

Beta reduction: `(λx. body) arg` → `body[x := arg]`

But with de Bruijn indices:
```
(λ. bvar(0)) zero  →  ???
```

We need to **substitute** `bvar(0)` with `zero` in the body.

### Three Operations

1. **shift(delta, cutoff, expr)**: Increase indices ≥ cutoff by delta
2. **subst(k, replacement, expr)**: Replace `bvar(k)` with replacement
3. **open(expr, replacement)**: Shorthand for `subst(0, replacement, expr)`

### Shift: Why?

When we move a term **under binders**, indices must adjust.

**Example:**
```
Context:  x:Nat, y:Bool
Term:     y              (bvar(0) in this context)
```

Now use this term under a lambda:
```
λz:Nat. y
```

Inside the lambda, `y` is now **1 binder away**, not 0!

```maude
op shift : Nat Nat Expr -> Expr .

--- Variables
eq shift(D, C, bvar(K)) = if K < C then bvar(K) else bvar(K + D) fi .
eq shift(D, C, fvar(X)) = fvar(X) .

--- Binders increase cutoff
eq shift(D, C, lam(M, A, E)) = lam(M, shift(D, C, A), shift(D, s C, E)) .
```

**Key:** Under a binder, cutoff increases (`s C`), because the new binder shields one variable.

**Try it:**
```maude
red shift(1, 0, bvar(0)) .
--- Result: bvar(1)

red shift(1, 0, bvar(2)) .
--- Result: bvar(3)

red shift(1, 0, lam(mw, Nat, bvar(0))) .
--- Result: lam(mw, Nat, bvar(0))  --- bvar(0) not shifted (below cutoff 1)

red shift(1, 0, lam(mw, Nat, bvar(1))) .
--- Result: lam(mw, Nat, bvar(2))  --- bvar(1) shifted (≥ cutoff 1 inside)
```

### Substitution

```maude
op subst : Nat Expr Expr -> Expr .

--- Hit: replace bvar(K) with S
eq subst(K, S, bvar(K)) = S .

--- Miss (below): no change
eq subst(K, S, bvar(J)) = if J < K then bvar(J) else bvar(sd(J, 1)) fi .

--- Under binder: increment K, shift S
eq subst(K, S, lam(M, A, E)) = lam(M, subst(K, S, A), subst(s K, shift(1, 0, S), E)) .
```

**Why shift S?** When we go under a binder, the replacement `S` moves into a longer context.

**Example:** Substitute `bvar(0)` with `zero` in `bvar(0)`:
```maude
red subst(0, zero, bvar(0)) .
--- Result: zero
```

Substitute in a lambda body:
```maude
red subst(0, zero, lam(mw, Nat, suc(bvar(0)))) .
--- Result: lam(mw, Nat, suc(bvar(0)))
--- bvar(0) refers to the lambda argument, not the outer bvar(0)
```

Substitute in a lambda using an outer variable:
```maude
red subst(0, zero, lam(mw, Nat, bvar(1))) .
--- Result: lam(mw, Nat, zero)
--- bvar(1) inside the lambda = bvar(0) outside
```

### Open: Entering a Binder

```maude
op open : Expr Expr -> Expr .
eq open(E, S) = subst(0, S, E) .
```

**Use case:** Beta reduction
```
app(lam(mw, A, body), arg)  →  open(body, arg)
```

**Try it:**
```maude
red open(bvar(0), zero) .
--- Result: zero

red open(suc(bvar(0)), nat(5)) .
--- Result: suc(nat(5))
```

### Complete Beta Reduction Example

```
(λx:Nat. suc(x)) zero
```

In Prologos:
```maude
app(lam(mw, Nat, suc(bvar(0))), zero)
```

Beta reduces to:
```maude
open(suc(bvar(0)), zero)
= subst(0, zero, suc(bvar(0)))
= suc(subst(0, zero, bvar(0)))
= suc(zero)
```

---

## 8. Reduction: Computation Rules

**File:** `prologos-reduction.maude`

### Why This Matters: How Much Should We Compute?

Type checking with dependent types requires comparing types for equality. But types can contain *computation* -- the type `Vec(Nat, 1 + 1)` and `Vec(Nat, 2)` are the same type, but only after reducing `1 + 1` to `2`. This raises a design question: how much should we reduce?

**WHNF (Weak Head Normal Form)**: Reduce just enough to see the outermost constructor. `suc(1 + 1)` in WHNF is still `suc(1 + 1)` -- we see it's a `suc` but don't bother reducing the argument. This is *fast* and sufficient for most type checking decisions (we usually only need to know "is this a Pi type? A Sigma type? A Nat?").

**NF (Normal Form)**: Reduce everything, everywhere, as far as it will go. `suc(1 + 1)` in NF is `suc(2)`. This is *complete* but potentially expensive -- and for ill-formed terms, could even loop.

**conv (Conversion)**: Two terms are "the same type" if they reduce to identical normal forms. `conv(Vec(Nat, 1+1), Vec(Nat, 2))` reduces both sides to NF and compares structurally. This is the decision procedure the type checker uses whenever it needs to verify type equality.

Prologos uses WHNF for pattern decisions (efficient) and NF for conversion checks (complete). This is the standard approach in production implementations like Agda and Idris.

### Weak Head Normal Form (WHNF)

```maude
op whnf : Expr -> Expr .
```

Reduces only the **outermost** redex (enough to expose the head constructor).

**Beta reduction:**
```maude
eq whnf(app(lam(M, A, E), S)) = whnf(open(E, S)) .
```

**Try it:**
```maude
red whnf(app(lam(mw, Nat, bvar(0)), zero)) .
--- Result: zero

red whnf(app(lam(mw, Nat, suc(bvar(0))), zero)) .
--- Result: suc(zero)
```

**Application (recursive):**
```maude
eq whnf(app(E, S)) = (if whnf(E) :: Lam then whnf(app(whnf(E), S)) else app(whnf(E), S) fi) .
```

First reduce the function, then check if it's a lambda.

### Natural Number Recursion

```maude
op natrec : Expr Expr Expr Expr -> Expr [ctor] .
```

`natrec(motive, base, step, scrutinee)` = fold over Nat

```maude
eq whnf(natrec(Mot, Ez, Es, zero)) = Ez .
eq whnf(natrec(Mot, Ez, Es, suc(N))) = whnf(app(app(Es, N), natrec(Mot, Ez, Es, N))) .
```

**Example:** Addition
```
add = λm. λn. natrec(
  (λ_. Nat),           --- motive
  m,                   --- base case: 0 + m = m
  (λk. λrec. suc(rec)), --- step: (k+1) + m = suc(k + m)
  n                    --- scrutinee
)
```

### Normal Form (NF)

```maude
op nf : Expr -> Expr .
```

Reduces **everywhere** (full normalization).

```maude
eq nf(lam(M, A, E)) = lam(M, nf(A), nf(E)) .
eq nf(app(E, S)) = (if nf(E) :: Lam then nf(app(nf(E), S)) else app(nf(E), nf(S)) fi) .
```

**Try it:**
```maude
red nf(app(lam(mw, Nat, lam(mw, Nat, bvar(1))), zero)) .
--- Result: lam(mw, Nat, zero)
--- Reduced under the lambda
```

### Conversion

```maude
op conv : Expr Expr -> Bool .
eq conv(E1, E2) = (nf(E1) == nf(E2)) .
```

**Two terms are convertible** if they have the same normal form.

```maude
red conv(app(lam(mw, Nat, bvar(0)), zero), zero) .
--- Result: true

red conv(suc(zero), nat(1)) .
--- Result: true  (nat(1) expands to suc(zero))
```

---

## 9. Type Checking: Bidirectional Inference

**File:** `prologos-typing-core.maude`

### Why This Matters: Making Type Inference Tractable

Dependent type checking is *hard*. In the general case, type inference for dependently-typed languages is undecidable -- there's no algorithm that can always figure out the types from the code alone. But we still want good type inference in practice. Bidirectional type checking is the pragmatic solution:

- **When information flows DOWN (checking)**: "I know this should be a function `Nat -> Nat`, so this lambda must take a `Nat`." No guessing required -- the expected type provides the answer.
- **When information flows UP (synthesis)**: "I can see this is `x` and the context says `x : Nat`, so the type is `Nat`." No annotation required -- the context provides the answer.

The discipline is: **annotate at boundaries** (function signatures, top-level definitions), **infer everywhere else**. This is why Prologos requires `ann()` around lambdas in certain positions -- it's not a limitation, it's a design choice that makes type checking decidable and predictable.

This same bidirectional approach is used in GHC (Haskell), the Agda compiler, Idris, and increasingly in TypeScript's type narrowing system.

### Two Modes

**Synthesis (infer):** Given a term, compute its type
```maude
op infer : Context Expr -> Expr .
```

**Checking (check):** Given a term and expected type, verify
```maude
op check : Context Expr Expr -> Bool .
```

### Why Both?

Some terms are **unambiguous** (can infer):
- Variables: look up in context
- Application: infer function type, extract result

Some terms are **ambiguous** (must check):
- Lambda: cannot infer argument type without annotation
- Need to check against expected Pi type

### Variable Inference: The Shift

```maude
eq infer(G, bvar(K)) = shift(s K, 0, lookupType(K, G)) .
```

**Critical:** When we look up a type defined in a context of length `n`, and use it in a context of length `n+k+1`, we must shift by `k+1`.

**Example:**
```
Context: x:Nat, y:Bool
Looking up y (bvar(0)): type is Bool
But Bool was defined in the shorter context (just x:Nat)
In the current context, free indices in Bool must shift by 1
```

**Try it:**
```maude
red infer(extend(empty, Nat, mw), bvar(0)) .
--- Result: Nat
```

### Application Inference

```maude
eq infer(G, app(E, S)) =
  (if infer(G, E) :: Pi and check(G, S, getPiDom(infer(G, E)))
   then subst(0, S, getPiCod(infer(G, E)))
   else errorExpr fi) .
```

**Steps:**
1. Infer type of function `E`: must be `Pi(π, A, B)`
2. Check argument `S` has type `A`
3. Result type is `B[x := S]` (substitute argument into codomain)

**Example:**
```maude
--- (λx:Nat. x) zero
red infer(empty, app(ann(lam(mw, Nat, bvar(0)), Pi(mw, Nat, Nat)), zero)) .
--- Result: Nat
```

### Lambda Checking

```maude
eq check(G, lam(M, A, E), Pi(M, T, B)) =
  (isType(G, T) and conv(T, A) and check(extend(G, T, M), E, B)) .
```

**Steps:**
1. Verify annotation `A` matches expected `T`
2. Check body `E` in extended context with `x:T`
3. Multiplicity `M` must match

**Example:**
```maude
red check(empty, lam(mw, Nat, bvar(0)), Pi(mw, Nat, Nat)) .
--- Result: true
```

### Polymorphic Identity

The **type** of the polymorphic identity function:
```
∀(A : Type). A → A
```

In Prologos:
```maude
Pi(m0, Type(lzero), Pi(mw, bvar(0), bvar(1)))
```
- `m0`: type parameter erased at runtime
- `Type(lzero)`: universe of types
- `bvar(0)` in second Pi: the type parameter `A`
- `bvar(1)` in second Pi: the type parameter `A` (shifted)

The **term**:
```maude
lam(m0, Type(lzero), lam(mw, bvar(0), bvar(0)))
```

**Try it:**
```maude
red check(empty,
  lam(m0, Type(lzero), lam(mw, bvar(0), bvar(0))),
  Pi(m0, Type(lzero), Pi(mw, bvar(0), bvar(1))))
.
--- Result: true
```

---

## 10. Inductive Families: Vectors and Finite Sets

**File:** `prologos-inductive.maude`

### Length-Indexed Vectors

```maude
op Vec : Expr Expr -> Expr [ctor] .
op vnil : Expr -> Expr [ctor] .
op vcons : Expr Expr Expr Expr -> Expr [ctor] .
```

**Types:**
- `Vec(A, n)`: vector of elements of type `A` with length `n`
- `vnil(A) : Vec(A, zero)`
- `vcons(A, n, head, tail) : A → Vec(A, n) → Vec(A, suc(n))`

**Example:**
```
[0, 1, 2] : Vec(Nat, 3)
```

In Prologos:
```maude
vcons(Nat, nat(2), nat(0),
  vcons(Nat, nat(1), nat(1),
    vcons(Nat, nat(0), nat(2),
      vnil(Nat))))
```

**Try it:**
```maude
red check(empty,
  vcons(Nat, zero, zero, vnil(Nat)),
  Vec(Nat, suc(zero)))
.
--- Result: true
```

### Finite Sets

```maude
op Fin : Expr -> Expr [ctor] .
op fzero : Expr -> Expr [ctor] .
op fsuc : Expr Expr -> Expr [ctor] .
```

**`Fin(n)`**: Type with exactly `n` inhabitants
- `Fin(0)`: empty type
- `Fin(1)`: unit type (`fzero(0)`)
- `Fin(3)`: `{fzero(2), fsuc(1, fzero(1)), fsuc(2, fsuc(1, fzero(0)))}`

**Use case:** Safe array indexing
```
vindex : Vec(A, n) → Fin(n) → A
```

Can't index out of bounds! The type system guarantees the index is in range.

---

## 11. Quantitative Type Theory: Resource Tracking

**File:** `prologos-qtt.maude`

### Why This Matters: Bugs That Type Systems Usually Miss

Conventional type systems tell you "this is an integer" or "this is a string." They don't tell you "this integer has been consumed" or "this connection is still open." QTT adds this missing dimension. Here are three bug patterns it catches:

**Bug pattern 1: Resource leak**
```python
def process_data(db):
    conn = db.connect()
    data = conn.query("SELECT *")
    if data.is_empty():
        return []       # BUG: conn is never closed on this path
    conn.close()
    return data
```
In QTT, `conn` would be `m1` (linear). The early return creates a code path where `conn` is used zero times after acquisition. `compatible(m1, m0) = false` -- the type checker rejects this program.

**Bug pattern 2: Aliased mutation**
```python
def dangerous(buffer):
    alias = buffer
    buffer.write("hello")
    alias.write("world")  # BUG: two writes via aliased references
```
With `m1`, `buffer` can only be used once. Assigning to `alias` consumes it. The subsequent write to `buffer` is a type error -- the resource was already consumed.

**Bug pattern 3: Ghost data leaking into runtime**
```python
def hash_password(password, salt):
    hashed = bcrypt(password, salt)
    log(f"Hashed {password}")  # BUG: password appears in log output
```
With `m0` for `password`, any runtime use -- including logging, serialization, or string interpolation -- is a type error. The password exists only for type-level reasoning, then is erased before the program runs.

### The Problem

Can we use a linear variable twice?

```maude
λ(x : Nat)^1. (x, x)  --- Should FAIL
```

The superscript `1` means `x` must be used **exactly once**, but we use it twice in the pair.

### Usage Contexts

```maude
sort UsageCtx .
op uempty : -> UsageCtx [ctor] .
op uextend : UsageCtx Mult -> UsageCtx [ctor] .
```

Parallel to `Context`, tracks **how each variable is actually used**.

### Inference with Usage

```maude
sort TypeUsage .
op tu : Expr UsageCtx -> TypeUsage [ctor] .
op tuError : -> TypeUsage [ctor] .

op inferQ : Context Expr -> TypeUsage .
```

Returns **both** the type and the usage context.

### Variable Usage

```maude
eq inferQ(G, bvar(0)) = tu(shift(1, 0, lookupType(0, G)), uextend(uempty, lookupMult(0, G))) .
```

Using `bvar(0)` creates usage context `[M, 0, 0, ...]` where `M` is the declared multiplicity.

### Application Usage

```maude
--- Function + scaled argument usage
eq inferQ(G, app(E, S)) =
  (if inferQ(G, E) :: tu and getType(inferQ(G, E)) :: Pi
   then ... tu(..., getUsage(inferQ(G, E)) +u (getPiMult(...) *u getUsage(inferQ(G, S)))) ...
   else tuError fi)
.
```

**Key insight:** `Usage_total = Usage_func + π * Usage_arg`

If function uses variable `x` once, and argument (used π times) also uses `x` once, total is `1 + π`.

### Lambda Checking

```maude
eq checkQ(G, lam(M, A, E), Pi(M, T, B)) =
  ... compatible(M, getUsage0(checkQ(extend(G, T, M), E, B))) ...
```

After checking the body, extract **how** the bound variable (bvar(0)) was actually used, and verify it's **compatible** with the declared multiplicity `M`.

**Example (success):**
```maude
red checkQtop(empty,
  lam(m1, Nat, bvar(0)),
  Pi(m1, Nat, Nat))
.
--- Result: true
--- Variable used exactly once: compatible(m1, m1) = true
```

**Example (failure):**
```maude
red checkQtop(empty,
  lam(m1, Nat, pair(bvar(0), bvar(0))),
  Pi(m1, Nat, Sigma(Nat, Nat)))
.
--- Result: false
--- Variable used twice (m1 + m1 = mw), but declared m1
--- compatible(m1, mw) = false
```

### Erased Type Parameters

```maude
red checkQtop(empty,
  lam(m0, Type(lzero), lam(mw, bvar(0), bvar(0))),
  Pi(m0, Type(lzero), Pi(mw, bvar(0), bvar(1))))
.
--- Result: true
```

Type parameter `A` is erased (`m0`), so it doesn't matter if we don't use it in the body. The term variable is used once: `compatible(mw, m1) = true`.

---

## 12. Session Types: Communication Protocols

**File:** `prologos-sessions.maude`

### Why This Matters: Protocols Are Contracts

Every networked system implements protocols -- sequences of messages with rules about ordering, types, and who speaks when. HTTP, gRPC, WebSocket, OAuth, payment APIs, database wire protocols -- all are protocols. Most are documented in English prose or informal diagrams. What goes wrong:

**Protocol violation at runtime**: A client sends a payment request before authenticating. A server sends binary data when the client expects JSON. Neither side detects the mismatch until data is corrupted or a transaction fails silently.

**Deadlock**: Both sides wait for the other to send. Neither has a timeout. The connection hangs indefinitely. In microservice architectures, this cascades into system-wide stalls.

**Incomplete handling**: A server handles the "success" response path but not the "error" path. The error arrives and the server crashes or enters an undefined state.

Session types make protocols **checkable at compile time**. You describe the protocol as a type, and the type checker rejects programs that violate it.

**Duality** is the key insight: if you have a protocol for the client, you can *mechanically derive* the server's protocol. Prologos's `dual()` operation does this. If the client sends, the server receives. If the client chooses, the server offers. You write the protocol **once** and get both sides checked for free.

**Dependent sessions** (`dsend`/`drecv`) go even further: the protocol can depend on *values* sent during communication. "First send a number `n`, then send a vector of length `n`" -- the type of the second message depends on the value of the first. This eliminates an entire class of "wrong-length payload" bugs that are nearly impossible to catch with conventional testing.

### The Concept

Session types describe **communication protocols** between processes:

```
send(Nat, recv(Bool, endS))
```

This session type says:
1. Send a `Nat`
2. Receive a `Bool`
3. End

### Session Type Constructors

```maude
sort Session .
op endS : -> Session [ctor] .
op send : Expr Session -> Session [ctor] .
op recv : Expr Session -> Session [ctor] .
op dsend : Expr Session -> Session [ctor] .
op drecv : Expr Session -> Session [ctor] .
op choice : BranchList -> Session [ctor] .
op offer : BranchList -> Session [ctor] .
op mu : Session -> Session [ctor] .
op svar : Nat -> Session [ctor] .
```

**Variants:**
- `send` / `recv`: simple send/receive
- `dsend` / `drecv`: **dependent** send/receive (payload type depends on value)
- `choice` / `offer`: branching (select a label / offer multiple branches)
- `mu` / `svar`: recursive session types

### Dependent Sessions

```maude
dsend(Nat, send(Vec(Nat, bvar(0)), endS))
```

**Protocol:**
1. Send a `Nat` (call it `n`)
2. Send a `Vec(Nat, n)` (vector of length `n`)
3. End

The second message type **depends on** the first message value!

### Duality

```maude
op dual : Session -> Session .
eq dual(send(A, S)) = recv(A, dual(S)) .
eq dual(recv(A, S)) = send(A, dual(S)) .
eq dual(dsend(A, S)) = drecv(A, dual(S)) .
eq dual(drecv(A, S)) = dsend(A, dual(S)) .
eq dual(choice(B)) = offer(dualBranches(B)) .
eq dual(offer(B)) = choice(dualBranches(B)) .
eq dual(endS) = endS .
```

**Duality** ensures two endpoints of a channel have **opposite** roles:
- If Alice sends, Bob receives
- If Alice chooses, Bob offers

**Try it:**
```maude
red dual(send(Nat, recv(Bool, endS))) .
--- Result: recv(Nat, send(Bool, endS))
```

### Session Substitution

```maude
op substS : Nat Expr Session -> Session .
```

Substitute **expression** variables in session types (for dependent sessions).

**Example:**
```maude
red substS(0, nat(5), send(Vec(Nat, bvar(0)), endS)) .
--- Result: send(Vec(Nat, nat(5)), endS)
```

After sending the value `5`, substitute it into the continuation session type.

---

## 13. Process Calculus: Concurrent Programs

**File:** `prologos-processes.maude`

### Why This Matters: From Protocols to Programs

Session types (Section 12) describe *what* a communication protocol looks like. Process calculus describes *how* concurrent programs implement those protocols.

The relationship is:
- **Session types** = the interface contract (what messages are exchanged, in what order)
- **Processes** = the implementation (the code that actually sends, receives, and branches)

This is directly analogous to:
- Type signatures (what a function promises) vs function bodies (how it delivers)
- API schemas (what endpoints exist) vs handler code (what they do)
- Interface definitions vs class implementations

The process calculus gives us structured primitives for concurrency: `ppar` runs processes in parallel (like goroutines or async tasks), `pnew` creates fresh communication channels (like Go channels or Unix pipes), `psend`/`precv` exchange values, and `psel`/`pcase` handle branching protocols. The type checker then verifies that processes use their channels according to the declared session types.

### Process Constructors

```maude
sort Proc .
op stop : -> Proc [ctor] .
op psend : Expr Qid Proc -> Proc [ctor] .
op precv : Qid Proc -> Proc [ctor] .
op psel : Qid Qid Proc -> Proc [ctor] .
op pcase : Qid CaseList -> Proc [ctor] .
op pnew : Session Proc -> Proc [ctor] .
op ppar : Proc Proc -> Proc [ctor assoc comm] .
op plink : Qid Qid -> Proc [ctor] .
```

**Examples:**

**Send:**
```maude
psend(nat(42), 'c, stop)
```
Send `42` on channel `'c`, then stop.

**Receive:**
```maude
precv('c, psend(bvar(0), 'd, stop))
```
Receive on `'c`, bind to `bvar(0)`, then send that value on `'d`.

**New channel:**
```maude
pnew(send(Nat, endS),
  ppar(psend(zero, 'c, stop),
       precv('d, stop)))
```
Create linked channels `'c` and `'d` with dual types, run processes in parallel.

### Channel Contexts

```maude
sort ChanCtx .
op cempty : -> ChanCtx [ctor] .
op _::_ : Qid Session -> ChanCtx [ctor] .
op _,_ : ChanCtx ChanCtx -> ChanCtx [ctor assoc comm id: cempty] .
```

**Example:**
```maude
('c :: send(Nat, endS)), ('d :: recv(Nat, endS))
```

Two channels with dual types.

---

## 14. Process Typing: Putting It All Together

**File:** `prologos-typing-sessions.maude`

### Why This Matters: What Process Typing Guarantees

When `typeProc(Gamma, Delta, P)` returns `true`, you get these guarantees for free:

1. **Protocol compliance**: Every send/receive matches the session type on that channel. No "wrong type of message" errors at runtime -- the type checker has verified every communication step.

2. **Session completion**: Every channel reaches `endS`. No "connection left dangling" scenarios where one side has finished but the other is still waiting.

3. **Exhaustive handling**: Every `pcase` handles all branches the other side might select via `psel`. No "unhandled case" crashes when an unexpected branch arrives.

4. **Linear channel usage**: Channels in `Delta` (the channel context) are used linearly -- each channel belongs to exactly one process in a parallel composition. No "two processes fighting over the same channel."

5. **Dual consistency**: When `pnew` creates a channel pair, the two endpoints have dual session types. What one side sends, the other receives -- mechanically guaranteed.

These are properties that concurrent programs in Go, Erlang, or JavaScript typically lack at compile time. In those languages, you discover protocol violations through testing, timeouts, and production incidents. Session-typed process calculus catches them before the code runs.

### Typing Judgment

```maude
op typeProc : Context ChanCtx Proc -> Bool .
```

**Check:** Does process `P` use channels in `ChanCtx` according to protocols, in expression context `Γ`?

### Stop

```maude
eq typeProc(G, C, stop) = allEnded(C) .
```

Can only stop when **all channels have ended** (reached `endS`).

### Send

```maude
eq typeProc(G, (X :: send(A, S)) , C, psend(E, X, P)) =
  (check(G, E, A) and typeProc(G, (X :: S) , C, P)) .
```

**Steps:**
1. Check expression `E` has type `A`
2. Update channel type to continuation `S`
3. Check rest of process `P`

**Example:**
```maude
red typeProc(empty, ('c :: send(Nat, endS)), psend(zero, 'c, stop)) .
--- Result: true
```

### Receive

```maude
eq typeProc(G, (X :: recv(A, S)) , C, precv(X, P)) =
  typeProc(extend(G, A, mw), (X :: S) , C, P) .
```

**Steps:**
1. Extend context with received value (bound to `bvar(0)`)
2. Update channel type to continuation `S`
3. Check rest of process `P`

### New/Cut

```maude
eq typeProc(G, C, pnew(S, P)) =
  typeProc(G, ('c :: S), ('d :: dual(S)), C, P) .
```

Create **dual** channels `'c` and `'d`.

### Parallel Composition

```maude
eq typeProc(G, C1 , C2, ppar(P1, P2)) =
  (typeProc(G, C1, P1) and typeProc(G, C2, P2)) .
```

**Split** channel context between parallel processes (AC matching).

**Example:**
```maude
red typeProc(empty, cempty,
  pnew(send(Nat, endS),
    ppar(psend(zero, 'c, stop),
         precv('d, stop))))
.
--- Result: true
```

Creates channels, sends on one end, receives on the other, both stop.

### Link/Identity

```maude
eq typeProc(G, (X :: S), (Y :: dual(S)), plink(X, Y)) = true .
```

**Forwarding:** Connect two channels with dual types.

---

## 15. Running Examples: Hands-On Practice

The examples below follow the tutorial's progression and tell a story:

- **Examples 1-3**: Basic mechanics -- multiplicities, shifting, reduction. These are the building blocks that everything else rests on. *(Foundation layer)*
- **Examples 4-5**: Type checking -- the system starts saying "yes" or "no" to programs. You see the bidirectional discipline in action. *(Verification layer)*
- **Example 6**: Dependent types in action -- vectors that know their length, indices that can't go out of bounds. *(Safety layer)*
- **Examples 7-8**: Resource tracking -- the system catches real bugs: duplicate use of linear variables, use of erased variables at runtime. *(Resource layer)*
- **Examples 9-11**: Communication protocols -- types for concurrent programs, duality, channel creation. *(Concurrency layer)*

Each example is runnable. Try modifying them to see what breaks -- that's often more instructive than seeing them succeed.

### Setup

```bash
$ cd maude/
$ maude prologos-tests.maude
```

You'll see modules load in dependency order.

### Example 1: Multiplicity Arithmetic

```maude
Maude> red m1 +m m1 .
result Mult: mw

Maude> red m0 *m mw .
result Mult: m0

Maude> red compatible(m1, mw) .
result Bool: false
```

**What's happening:** Linear + linear = unrestricted. Erased * anything = erased. Linear usage not compatible with unrestricted actual.

### Example 2: Shifting

```maude
Maude> red shift(1, 0, lam(mw, Nat, bvar(1))) .
result Expr: lam(mw, Nat, bvar(2))
```

**What's happening:** Shifting all free variables by 1. `bvar(1)` is free (≥ cutoff 1 inside lambda), becomes `bvar(2)`.

### Example 3: Beta Reduction

```maude
Maude> red whnf(app(lam(mw, Nat, suc(bvar(0))), zero)) .
result Expr: suc(zero)

Maude> red conv(app(lam(mw, Nat, bvar(0)), nat(5)), nat(5)) .
result Bool: true
```

**What's happening:** Beta reduces `(λx. suc(x)) 0` to `suc(0)`. Identity function applied to 5 converts to 5.

### Example 4: Type Checking

```maude
Maude> red check(empty, lam(mw, Nat, bvar(0)), Pi(mw, Nat, Nat)) .
result Bool: true

Maude> red infer(empty, app(ann(lam(mw, Nat, suc(bvar(0))), Pi(mw, Nat, Nat)), zero)) .
result Expr: Nat
```

**What's happening:** Identity function type-checks. Successor function applied to zero infers type `Nat`.

### Example 5: Polymorphic Identity

```maude
Maude> red check(empty,
  lam(m0, Type(lzero), lam(mw, bvar(0), bvar(0))),
  Pi(m0, Type(lzero), Pi(mw, bvar(0), bvar(1))))
.
result Bool: true
```

**What's happening:** `∀A:Type. A → A` type-checks. Type parameter erased, term parameter used once.

### Example 6: Vectors

```maude
Maude> red check(empty,
  vcons(Nat, zero, nat(1), vnil(Nat)),
  Vec(Nat, suc(zero)))
.
result Bool: true
```

**What's happening:** `[1]` type-checks as `Vec(Nat, 1)`.

### Example 7: QTT Success

```maude
Maude> red checkQtop(empty,
  lam(m1, Nat, bvar(0)),
  Pi(m1, Nat, Nat))
.
result Bool: true
```

**What's happening:** Linear identity uses variable exactly once. `compatible(m1, m1) = true`.

### Example 8: QTT Failure

```maude
Maude> red checkQtop(empty,
  lam(m1, Nat, pair(bvar(0), bvar(0))),
  Pi(m1, Nat, Sigma(Nat, Nat)))
.
result Bool: false
```

**What's happening:** Linear variable used twice. `m1 + m1 = mw`, `compatible(m1, mw) = false`.

### Example 9: Session Duality

```maude
Maude> red dual(send(Nat, recv(Bool, endS))) .
result Session: recv(Nat, send(Bool, endS))
```

**What's happening:** Sender becomes receiver, receiver becomes sender.

### Example 10: Simple Process

```maude
Maude> red typeProc(empty, ('c :: send(Nat, endS)), psend(zero, 'c, stop)) .
result Bool: true
```

**What's happening:** Process sends `0` on channel expecting send, then stops when channel ends.

### Example 11: New Channel

```maude
Maude> red typeProc(empty, cempty,
  pnew(send(Nat, endS),
    ppar(psend(nat(42), 'c, stop),
         precv('d, stop))))
.
result Bool: true
```

**What's happening:** Create dual channels, send on one end, receive on other, both stop.

---

## 16. Design Patterns and Insights

The patterns below capture the practical intuitions that come from working with the Prologos specification. They answer the questions you'll actually encounter:

- "I'm confused about when indices need shifting" -- Pattern 1
- "I keep getting substitution wrong under binders" -- Pattern 2
- "Should I annotate this term or let it be inferred?" -- Pattern 3
- "How do I think about resource tracking compositionally?" -- Pattern 4
- "How does duality actually work in practice?" -- Pattern 5

Think of these as the engineering rules of thumb for working in a dependently-typed, session-typed, quantitative setting.

### Pattern 1: De Bruijn Indices are Context-Relative

**Key insight:** `bvar(K)` means "K binders out **from here**."

When you move a term to a different context depth, indices must shift.

**Rule of thumb:** When crossing N binders inward, shift cutoff by N. When crossing N binders outward, shift indices by N.

### Pattern 2: Substitution Under Binders

**Key insight:** When substituting under a binder, both the target index and the replacement must adjust.

```maude
subst(K, S, lam(M, A, E)) = lam(M, subst(K, S, A), subst(s K, shift(1, 0, S), E))
```

- Target: `s K` (binder shields one level)
- Replacement: `shift(1, 0, S)` (moved under one binder)

### Pattern 3: Bidirectional Type Checking

**Synthesis:** For terms that "know their type":
- Variables (look up)
- Annotated terms
- Application (from function type)

**Checking:** For terms that need guidance:
- Lambdas (need expected Pi type for domain)
- Constructors (need expected inductive type)

**Rule of thumb:** Check lambdas, infer applications.

### Pattern 4: Usage Tracking is Compositional

**Addition:** Combine branches (if-then-else, pattern matching)
```
if c then e1 else e2  →  U_c + U_e1 + U_e2
```

**Scaling:** Under binders or in arguments
```
λ(x:A)^π. e  →  body uses x with some ρ, verify compatible(π, ρ)
f e          →  U_total = U_f + π * U_e (where f : (x:A)^π → B)
```

### Pattern 5: Duality is Structural

Every session constructor has a dual:
- Data constructors swap: `send ↔ recv`, `dsend ↔ drecv`, `choice ↔ offer`
- Structural recursion: `dual(send(A, S)) = recv(A, dual(S))`
- Fixed points: `dual(mu(S)) = mu(dual(S))`

**Insight:** Duality is an **involution** (applying it twice is identity).

---

## 17. Common Pitfalls and Debugging

### Pitfall 1: Forgetting to Shift on Lookup

**Wrong:**
```maude
eq infer(G, bvar(K)) = lookupType(K, G) .
```

**Problem:** Type was defined in shorter context. Using it in longer context requires shifting.

**Correct:**
```maude
eq infer(G, bvar(K)) = shift(s K, 0, lookupType(K, G)) .
```

### Pitfall 2: Shifting the Replacement

**Wrong:**
```maude
eq subst(K, S, lam(M, A, E)) = lam(M, subst(K, S, A), subst(s K, S, E)) .
```

**Problem:** Replacement `S` is from outer context. Under a binder, it's in a longer context.

**Correct:**
```maude
eq subst(K, S, lam(M, A, E)) = lam(M, subst(K, S, A), subst(s K, shift(1, 0, S), E)) .
```

### Pitfall 3: Confusing Multiplicity Compatibility

**Question:** Can I use a `mw` (unrestricted) variable once?

**Answer:** Yes! `compatible(mw, m1) = true`. Unrestricted means "use any number of times, including once."

**Question:** Can I use a `m1` (linear) variable unrestricted times?

**Answer:** No! `compatible(m1, mw) = false`. Linear means "exactly once."

**Mnemonic:** Declared ≥ actual (you can use less than declared).

### Pitfall 4: Mixing Expression and Session Variables

**Expression variables:** de Bruijn indices (`bvar(K)`)
**Channel names:** quoted identifiers (`'c`, `'d`)
**Session variables:** de Bruijn indices in recursive session types (`svar(K)`)

These are **separate namespaces**. Don't confuse them!

### Debugging Strategy

1. **Simplify:** Test with smallest possible terms
2. **Trace:** Use Maude's `trace` command to see rewrite steps
3. **Check indices:** Manually verify de Bruijn indices match your intention
4. **Type first:** Before QTT, ensure the term type-checks with `check`
5. **Isolate:** Test each operation (shift, subst, whnf) independently

---

## 18. Advanced Topics: Extending Prologos

### Adding New Inductive Types

**Template:**
1. Add constructors to `Expr` sort
2. Extend `shift` for new constructors
3. Extend `subst` for new constructors
4. Add `whnf` reduction rules (eliminators)
5. Add `infer` or `check` rules for constructors and eliminators

**Example:** Adding `List(A)`:
```maude
op List : Expr -> Expr [ctor] .
op lnil : Expr -> Expr [ctor] .
op lcons : Expr Expr Expr -> Expr [ctor] .  --- lcons(A, head, tail)
```

### Adding New Session Primitives

**Template:**
1. Add constructor to `Session` sort
2. Extend `dual` operation
3. Extend `substS` for dependent sessions
4. Add corresponding process constructor
5. Add `typeProc` rule

**Example:** Adding timeout:
```maude
op timeout : Nat Session Session -> Session [ctor] .
--- timeout(n, S1, S2): wait n time units for S1, else S2
```

### Proving Properties

Maude supports formal verification! You can:
- **Search:** Find reachable states
- **Model check:** Verify temporal properties (with Maude LTL)
- **Prove:** Inductive theorems (with Maude ITP)

**Example search:**
```maude
search [1] typeProc(G, C, P) =>! false .
```
Searches for a process that fails type checking.

---

## 19. Connections to the Literature

### Quantitative Type Theory

**Papers:**
- Atkey (2018): "Syntax and Semantics of Quantitative Type Theory"
- McBride (2016): "I Got Plenty o' Nuttin'"

**Prologos contribution:** Maude formalization with full substitution and reduction.

### Session Types

**Papers:**
- Honda (1993): "Types for Dyadic Interaction"
- Wadler (2012): "Propositions as Sessions"

**Prologos contribution:** Dependent session types (types depend on communicated values).

### Dependent Types

**Systems:**
- Agda: Full dependent types with pattern matching
- Idris: Dependent types for practical programming
- Coq: Proof assistant with dependent types

**Prologos contribution:** Minimal core with explicit substitution calculus.

---

## 20. Next Steps and Resources

### Experiment!

Try modifying the examples:
1. Change multiplicities and see what breaks
2. Build longer vector examples
3. Design custom session protocols
4. Add your own inductive types

### Suggested Exercises

**Exercise 1:** Define `List(A)` and `map : (A -> B) -> List(A) -> List(B)`.
*Why this matters*: Lists are the bread and butter of functional programming. Extending Prologos with a new inductive type teaches you the full pipeline: syntax, shift, subst, whnf, typing. This is the exercise that proves you understand the module architecture end-to-end.

**Exercise 2:** Implement a session type for a **two-phase commit protocol**.
*Why this matters*: Two-phase commit is the foundation of distributed transactions (databases, payment systems, microservices). Modeling it as a session type demonstrates that Prologos can express real-world distributed systems protocols -- and that the type checker can verify coordinator/participant interactions.

**Exercise 3:** Prove (on paper) that `dual(dual(S)) = S` for all sessions `S`.
*Why this matters*: This is the involution property -- it guarantees that duality is consistent. If it failed, the dual of your server's protocol wouldn't match your client's, and the entire session typing system would be unsound. This exercise builds formal reasoning skills.

**Exercise 4:** Add **product types** `A x B` with `fst` and `snd` (different from dependent Sigma).
*Why this matters*: Product types are everywhere (structs, tuples, records). This exercise teaches how QTT multiplicities interact with elimination forms -- if a pair is linear, what happens when you project? Both components must be consumed.

**Exercise 5:** Implement **unrestricted** channels (session types with `mw` multiplicity).
*Why this matters*: Not all channels need to be linear. Unrestricted channels model broadcast, logging, or shared configuration channels. This exercise explores the boundary between linear and unrestricted resources in concurrent systems.

### Further Reading

**Type Theory:**
- "Type Theory and Formal Proof" (Nederpelt & Geuvers)
- "Programming in Martin-Löf's Type Theory" (Nordström et al.)

**Maude:**
- "Maude Manual" (http://maude.cs.illinois.edu/w/index.php/The_Maude_System)
- "All About Maude" (Clavel et al.)

**Session Types:**
- "Foundations of Session Types" (Yoshida & Vasconcelos)

**QTT:**
- "Syntax and Semantics of Quantitative Type Theory" (Atkey)

### Join the Community

- Maude mailing list: maude-help@cs.illinois.edu
- Type theory community: https://types-list.org
- Session types community: https://groups.google.com/g/session-types

---

## 21. Summary: What You've Learned and When to Use It

### The Problem-to-Feature Map

When you encounter a problem in your code, here's which Prologos feature addresses it:

| When you need to... | Use... | What it prevents |
|---------------------|--------|-----------------|
| Guarantee array indices are in bounds | Dependent types (`Vec`/`Fin`) | Out-of-bounds crashes, off-by-one errors |
| Ensure a resource is cleaned up exactly once | Linear types (`m1`) | Leaks, double-free, use-after-close |
| Prevent secrets from appearing at runtime | Erasure (`m0`) | Passwords in logs, PII in crash dumps |
| Enforce message ordering in a protocol | Session types | Protocol violations, malformed exchanges |
| Verify concurrent processes don't interfere | Process typing | Channel misuse, unhandled branches, deadlocks |
| Prove that two representations are equivalent | Equality types (`Eq`, `J`) | Incorrect casts, unsound coercions |
| Write generic code without runtime overhead | Universe levels + Pi + `m0` | Type-passing cost, monomorphization bloat |

### What Each Feature Guarantees

**Dependent types**: "If it compiles, the invariant holds." Lengths match, indices are in bounds, impossible states are unrepresentable. This is the compile-time equivalent of writing assertions everywhere -- except the assertions are proven, not tested.

**QTT (`m0`)**: "If it compiles, the secret is erased." No runtime representation, no logging, no persistence. The value exists only to guide type checking, then vanishes.

**QTT (`m1`)**: "If it compiles, the resource is used exactly once." No leaks, no double-free, no aliasing. Every code path through your program consumes the resource precisely once.

**Session types**: "If it compiles, the protocol is followed." Messages arrive in the right order, with the right types, and all branches are handled. Both sides of a communication channel are verified against complementary specifications.

**Process typing**: "If it compiles, the concurrent system is safe." No channel misuse, no dangling connections, no unhandled cases. Channels are split linearly across parallel processes.

### The Power of the Combination

These features are individually valuable but **combinatorially powerful**:

- **Dependent types + Session types = dependent sessions**: "Send a number `n`, then send a vector of length `n`." The second message's type depends on the first message's value. This eliminates an entire class of "wrong-length payload" bugs.

- **QTT + Session types = linear channels**: Channels are used exactly once in each parallel branch. No two processes can interfere on the same channel. This is structural deadlock prevention.

- **Dependent types + QTT = erased type parameters**: `identity : (A : Type)^0 -> A -> A`. Generic code with zero runtime cost for type passing. Polymorphism is free.

### The Formal Specification Advantage

Prologos demonstrates that complex type systems can be precisely specified, executable, modular, and extensible. By formalizing in Maude, we gain:

- **Confidence**: The rules are exactly as written -- no gap between specification and implementation
- **Experimentation**: Change a rule and instantly see what breaks across the entire test suite
- **Communication**: Share unambiguous specifications that ARE the language, not documentation ABOUT the language

The specification is the foundation for Prologos Phase 1: a compiler that is correct by construction because it implements exactly these verified rules. Every typing judgment, every reduction step, every duality law you've seen in this tutorial is an executable equation that the implementation must preserve.

### Going Forward

You now have the tools to:
- **Read** the full Prologos specification and understand both what it does and why
- **Experiment** with dependent types, linear types, and session types interactively
- **Diagnose** type errors by understanding the machinery behind the checker
- **Extend** the specification with new types, new session constructs, or new process forms
- **Apply** these ideas to your own systems: APIs with protocol guarantees, resource-safe libraries, concurrent services with verified channel discipline

**Happy exploring!**

---

## Appendix A: Quick Reference

### Maude Commands

```maude
red expr .                    --- Reduce expression
trace on .                    --- Enable rewrite tracing
trace off .                   --- Disable tracing
show module MODULE-NAME .     --- Show module contents
quit .                        --- Exit Maude
```

### Common Operations

```maude
--- Multiplicities
m0 +m m1        → m1
m1 +m m1        → mw
m1 *m m1        → m1
m0 *m mw        → m0
compatible(m1, m1) → true

--- Shifting
shift(delta, cutoff, expr)    --- Increase indices ≥ cutoff by delta

--- Substitution
subst(k, replacement, expr)   --- Replace bvar(k) with replacement
open(body, arg)               --- subst(0, arg, body)

--- Reduction
whnf(expr)                    --- Weak head normal form
nf(expr)                      --- Full normal form
conv(e1, e2)                  --- Convertibility check

--- Typing
infer(context, expr)          --- Type synthesis
check(context, expr, type)    --- Type checking
isType(context, expr)         --- Is this a type?

--- QTT
inferQ(context, expr)         --- Synthesis with usage
checkQ(context, expr, type)   --- Checking with usage
checkQtop(context, expr, type) --- Top-level check

--- Sessions
dual(session)                 --- Dual session type
substS(k, expr, session)      --- Substitute in session

--- Processes
typeProc(context, chanctx, proc) --- Process type checking
```

### Common Constructors

```maude
--- Terms
bvar(n)                       --- Bound variable
fvar('x)                      --- Free variable
lam(mult, type, body)         --- Lambda
app(func, arg)                --- Application
pair(fst, snd)                --- Pair
nat(n)                        --- Natural number literal

--- Types
Type(level)                   --- Universe
Nat                           --- Natural numbers
Pi(mult, domain, codomain)    --- Dependent function type
Sigma(fst, snd)               --- Dependent pair type
Vec(elemType, length)         --- Length-indexed vector
Fin(n)                        --- Finite set with n elements

--- Sessions
endS                          --- End
send(type, cont)              --- Send
recv(type, cont)              --- Receive
dsend(type, cont)             --- Dependent send
drecv(type, cont)             --- Dependent receive

--- Processes
stop                          --- Terminated
psend(value, chan, cont)      --- Send
precv(chan, cont)             --- Receive
pnew(session, proc)           --- New channel
ppar(p1, p2)                  --- Parallel composition
plink(c1, c2)                 --- Forward/link
```

### Context Patterns

```maude
empty                         --- Empty context
extend(ctx, type, mult)       --- Extended context

uempty                        --- Empty usage context
uextend(uctx, mult)           --- Extended usage

cempty                        --- Empty channel context
('c :: session)               --- Channel binding
c1 , c2                       --- Channel context join
```

## Appendix B: Example Index

Quick reference to all runnable examples in this tutorial:

1. **Multiplicity arithmetic** (Section 3)
2. **Level max** (Section 4)
3. **De Bruijn shift** (Section 5)
4. **Substitution** (Section 7)
5. **Beta reduction** (Section 8)
6. **Conversion** (Section 8)
7. **Variable inference** (Section 9)
8. **Polymorphic identity** (Section 9)
9. **Vector construction** (Section 10)
10. **QTT success** (Section 11)
11. **QTT failure** (Section 11)
12. **Session duality** (Section 12)
13. **Simple process** (Section 14)
14. **New channel** (Section 14)
15. **Complete example suite** (Section 15)

Run all examples with:
```bash
maude prologos-tests.maude
```

This runs all 33 integration tests covering every module. Individual test suites (`test-0a.maude` through `test-0g.maude`) can also be run separately.

---

**End of Tutorial**

Questions? Found a bug? Want to extend Prologos?

This is a living specification. Experiment, explore, and enjoy the precision of formal methods!
