---
title: "Prologos Tutorial: Types That Work For You"
subtitle: "A hands-on guide to dependent types, linear types, and session types in Lisp"
author: "The Prologos Project"
version: 0.2.0
date: 2026-02-07
---

# Prologos Tutorial: Types That Work For You

**A hands-on guide to dependent types, linear types, and session types in Lisp**

## What You'll Learn

By the end of this tutorial, you will be able to:

- **Write dependent types** that prevent out-of-bounds errors and encode invariants directly in the type system
- **Use linear types (QTT)** to guarantee resources are used exactly once, preventing double-free bugs and resource leaks
- **Apply erasure annotations** to ensure sensitive data is provably removed at runtime
- **Design session-typed protocols** that verify both ends of a communication channel follow the protocol correctly
- **Leverage the Prologos REPL** for interactive type-driven development
- **Read and write proofs as values** using the identity type and equality reasoning
- **Think in terms of "types as contracts"** for values, usage, and communication
- **Build safer systems** by encoding runtime constraints as compile-time guarantees

## Prerequisites

This tutorial assumes:

- **Lisp familiarity**: You've used Clojure, Common Lisp, Scheme, or another Lisp. You're comfortable with s-expressions, lambdas, and recursive functions.
- **Basic type knowledge**: You understand what types are and why they catch bugs. Experience with Haskell, OCaml, or TypeScript helps but isn't required.
- **No Racket experience needed**: We'll explain everything Racket-specific as we go.

You do NOT need prior knowledge of dependent types, linear types, or session types. We'll build these concepts from first principles.

## Time Estimate

- **Full tutorial**: 2–3 hours, working through all examples
- **Quick start**: 45 minutes for Sections 0–5 (core dependent types)
- **Deep dive**: Add another 1–2 hours for Sections 7–12 (QTT, sessions, inductive types)

## Setup

1. **Install Racket**: Download from [racket-lang.org](https://racket-lang.org/) (version 8.0 or later)
2. **Clone the repository**:
   ```
   git clone https://github.com/yourusername/prologos.git
   cd prologos
   ```
3. **Start the REPL**:
   ```
   racket racket/prologos/repl.rkt
   ```

You should see:

```
Prologos v0.2.0
Type :quit to exit, :env to see definitions, :load "file" to load a file.

> 
```

If you see this prompt, you're ready to go. Type `:quit` or `:q` to exit when you're done.

---

## Section 0: Why Prologos?

Most type systems stop at "is this a string or a number?" But the bugs that cost real money—crashes, data leaks, protocol violations—happen when your data has the *right type* but the *wrong value* or *wrong usage pattern*.

Prologos extends types to catch five categories of bugs that conventional type systems miss. Let's walk through them.

### 1. Out-of-Bounds Crashes

**The bug**: You index into an array with an integer that's too large. Your program crashes at runtime.

In Python:

```python
items = ["a", "b", "c"]
index = 5
print(items[index])  # IndexError: list index out of range
```

**The Prologos solution**: **Dependent types**. A vector of length `n` has type `Vec(A, n)`. An index into that vector has type `Fin(n)`—a type representing numbers strictly less than `n`.

The indexing function has this type:

```
vindex : Vec(A, n) → Fin(n) → A
```

Read it aloud: "Give me a vector of length `n` and an index that is *provably* less than `n`, and I'll give you an element of type `A`."

If you try to pass 5 as an index into a 3-element vector, the type checker *rejects your program before it runs*. The bug is caught at compile time.

**Real-world applications**:
- Database query builders: column indices bounded by table width
- Pagination logic: page numbers bounded by total page count
- Buffer operations: slice offsets bounded by buffer size

### 2. Double-Free and Use-After-Close

**The bug**: You close a file handle, then accidentally read from it later. Or you free memory twice. Runtime crash or worse—silent corruption.

In C-style pseudocode:

```c
File* f = open("data.txt");
close(f);
read(f);  // use-after-close: undefined behavior
```

**The Prologos solution**: **Linear types**. Mark the file handle with multiplicity `:1`, meaning it must be used *exactly once*.

```
openFile : String →:1 File
closeFile : File →:1 Unit
```

Read `:1` as "linear"—the resource flows through your program along exactly one path. If you try to use `f` twice, or forget to use it at all, the type checker rejects your program.

This is **Quantitative Type Theory (QTT)**, where every variable has a *usage multiplicity*: `:0` (erased), `:1` (linear), or `:w` (unrestricted).

**Real-world applications**:
- File handles, network connections, database transactions
- Mutex locks: acquire once, release once
- Memory management in systems programming

### 3. Leaked Secrets

**The bug**: A password or API key appears in logs, stack traces, or error messages. Your credentials are compromised.

In JavaScript:

```javascript
function authenticate(password) {
  console.log("Attempting login with:", password);  // oops, logged!
  // ...
}
```

**The Prologos solution**: **Erasure** (multiplicity `:0`). Mark the password as erased:

```
authenticate : (password :0 String) → Result
```

The type checker enforces that `password` is *never* used in runtime code—it's only available during type checking. When the program compiles, all references to `password` are removed. It *cannot* appear in logs because it doesn't exist at runtime.

**Real-world applications**:
- Passwords, API keys, auth tokens
- Personally identifiable information (PII)
- Cryptographic keys

### 4. Protocol Violations

**The bug**: You call REST endpoints in the wrong order. You send a payment request before authentication completes. The server rejects your request.

In typical async code:

```javascript
const session = initSession();
const payment = submitPayment(session);  // oops, session not authenticated yet
await authenticateSession(session);
```

**The Prologos solution**: **Session types**. The protocol is a type that describes the required message sequence. Both the client and server are checked against this protocol.

```
AuthProtocol = !Credentials . ?Token . End
```

Read this as: "Send credentials, receive a token, then end." If you try to send the payment message before receiving the token, the type checker rejects the program.

**Real-world applications**:
- REST API call sequences
- OAuth/OpenID flows
- Payment processing: quote → confirm → charge
- WebSocket protocols

### 5. Impossible States

**The bug**: Your configuration allows contradictory settings. A user can be both "active" and "deleted". Your app crashes when it hits an impossible combination.

In Ruby:

```ruby
class User
  attr_accessor :status, :deleted_at
end

user.status = "active"
user.deleted_at = Time.now  # contradiction!
```

**The Prologos solution**: **Dependent types generally**. Encode the constraint directly in the type:

```
User = Sigma (status : Status)
         (deleted_at : if status == Deleted then Timestamp else Unit)
```

Read this as: "A user has a status. If the status is `Deleted`, then `deleted_at` is a timestamp. Otherwise, it's `Unit` (nothing)."

The type system *forbids* constructing a user that's both active and deleted. The impossible state doesn't exist.

**Real-world applications**:
- Configuration validation: mutually exclusive flags
- State machines: allowed transitions encoded in types
- Invariant preservation: sorted lists, balanced trees

---

### Types as Contracts: The Unifying Vision

These five categories share a common theme: **types as contracts**.

- **Dependent types** are contracts about *values*: "This index is less than the array length."
- **Linear types** are contracts about *usage*: "This handle is used exactly once."
- **Session types** are contracts about *communication*: "These messages are sent in this order."

Prologos unifies all three in a single coherent language. You write types. The compiler enforces them. Whole classes of bugs vanish.

The rest of this tutorial teaches you how.

---

## Section 1: Prologos for Lisp Programmers

If you've used Clojure, Common Lisp, Scheme, or Racket, you already know 90% of Prologos syntax. Everything is an s-expression. Functions are defined with `lam`. Application is `(f x y z)`.

The differences are small but important.

### Syntax Differences

**1. Type annotations use `:` in binders**

In most Lisps, function parameters are just names:

```clojure
(fn [x] (+ x 1))
```

In Prologos, every binder includes a type:

```
(lam (x : Nat) (suc x))
```

Read this as: "A lambda taking `x` of type `Nat`, returning `(suc x)`."

**2. Multiplicity annotations: `:0`, `:1`, `:w`**

By default, parameters have multiplicity `:w` (unrestricted). You can override this:

```
(lam (A :0 (Type 0)) ...)   ; A is erased (multiplicity 0)
(lam (f :1 File) ...)       ; f is linear (multiplicity 1)
(lam (x :w Nat) ...)        ; x is unrestricted (multiplicity ω, the default)
```

We'll cover this in detail in Section 10. For now, just recognize the syntax.

**3. Definitions use `def` with explicit types**

```
(def name : type body)
```

Example:

```
(def increment : (-> Nat Nat)
  (lam (x : Nat) (suc x)))
```

This persists `increment` in the global environment.

### REPL Meta-Commands

The Prologos REPL supports several special commands:

- **`:quit`** or **`:q`** — Exit the REPL
- **`:env`** — Show all definitions in the current environment
- **`:load "path/to/file.prologos"`** — Load and execute a file
- **`:type expr`** — Synonym for `(infer expr)` (show the type of an expression)

All other input is Prologos code.

### Your First REPL Session

Let's verify the REPL is working. Start it:

```
$ racket racket/prologos/repl.rkt
```

You'll see:

```
Prologos v0.2.0
Type :quit to exit, :env to see definitions, :load "file" to load a file.

> 
```

Now try these commands:

```
> (check zero : Nat)
OK
```

This asks: "Does `zero` have type `Nat`?" The answer is yes.

```
> (infer (suc zero))
Nat
```

This asks: "What is the type of `(suc zero)`?" The answer is `Nat`.

```
> (eval (suc (suc zero)))
2 : Nat
```

This asks: "Reduce `(suc (suc zero))` to normal form and show the type." The answer is `2 : Nat`. (Natural number literals are syntactic sugar for repeated `suc` constructors.)

If you see these outputs, everything is working. Type `:q` to exit.

---

## Section 2: First Steps — Natural Numbers and Booleans

Prologos has two built-in base types: **Nat** (natural numbers) and **Bool** (booleans). Let's explore them interactively.

### Natural Numbers

The type `Nat` represents natural numbers (0, 1, 2, ...). It has two constructors:

- **`zero`** — represents 0
- **`(suc n)`** — the successor of `n`; represents `n + 1`

So `(suc zero)` is 1, `(suc (suc zero))` is 2, and so on.

Prologos also supports **natural number literals**: `0`, `1`, `2`, etc. These desugar to the constructor form. When you write `3`, the parser converts it to `(suc (suc (suc zero)))`.

Let's verify some natural numbers:

```
> (check zero : Nat)
OK
```

This checks that `zero` has type `Nat`. The type checker confirms it.

```
> (check (suc zero) : Nat)
OK
```

This checks that `(suc zero)` has type `Nat`. Again, confirmed.

```
> (infer zero)
Nat
```

This asks the type checker to *infer* the type of `zero`. It replies: `Nat`.

```
> (infer (suc zero))
Nat
```

Similarly, `(suc zero)` has inferred type `Nat`.

```
> (eval zero)
zero : Nat
```

The `eval` command normalizes the expression and shows the value along with its type. Here, `zero` is already in normal form, so the output is `zero : Nat`.

```
> (eval (suc (suc zero)))
2 : Nat
```

The expression `(suc (suc zero))` normalizes to the literal `2`, which is syntactic sugar. The output shows `2 : Nat`.

### Booleans

The type `Bool` represents truth values. It has two constructors:

- **`true`**
- **`false`**

Let's verify them:

```
> (check true : Bool)
OK
```

```
> (infer true)
Bool
```

```
> (eval true)
true : Bool
```

All as expected.

### The Universe Hierarchy

Every type has a type. What is the type of `Nat`?

```
> (infer Nat)
(Type 0)
```

The type `Nat` lives in **(Type 0)**, the **universe** of small types.

What about `Bool`?

```
> (infer Bool)
(Type 0)
```

Same answer. Both `Nat` and `Bool` are small types, so they live in `(Type 0)`.

What is the type of `(Type 0)` itself?

```
> (infer (Type 0))
(Type 1)
```

The type of `(Type 0)` is **(Type 1)**, a larger universe. And `(Type 1) : (Type 2)`, and so on. This is the **universe hierarchy**, which prevents paradoxes like Russell's paradox.

For most purposes, you'll only use `(Type 0)`. But when you write polymorphic functions (Section 5), you'll see `(Type 0)` and `(Type 1)` appear in signatures.

### The Three REPL Commands

Let's summarize the three main commands:

1. **`(check e : T)`** — Verify that expression `e` has type `T`. Output: `OK` or an error.
2. **`(infer e)`** — Ask the type checker to synthesize the type of `e`. Output: the type.
3. **`(eval e)`** — Normalize `e` and show the value along with its type. Output: `value : type`.

These three commands cover most interactive workflows: checking your code, exploring types, and running computations.

### Errors

What happens if you check an expression against the wrong type?

```
> (check true : Nat)
Error at <unknown>
  Type mismatch
  Expected: Nat
  Got:      Bool
  In expression: true
```

The type checker clearly reports the mismatch: you claimed `true` has type `Nat`, but it actually has type `Bool`.

Prologos errors show:
- The location (sometimes a source position like `<repl>:1:0`, or `<unknown>` when the error originates inside the type checker)
- The kind of error (`Type mismatch`)
- What was expected and what was found
- The problematic expression

This format helps you quickly pinpoint and fix type errors.

---

## Section 3: Functions — Lambdas and Application

Functions are the heart of Prologos. Let's learn how to define them, apply them, and give them types.

### Lambda Syntax

A lambda in Prologos looks like this:

```
(lam (x : T) body)
```

Read it as: "A function taking a parameter `x` of type `T` and returning `body`."

Unlike Scheme or Clojure, **you must always annotate parameter types**. Prologos doesn't infer them—you tell the type checker what you expect.

Example: a function that increments a natural number:

```
(lam (x : Nat) (suc x))
```

### Arrow Types

The type of a function is written with **`->`** (arrow):

```
(-> A B)
```

Read this as: "A function from type `A` to type `B`."

For example, the increment function has type:

```
(-> Nat Nat)
```

"A function from `Nat` to `Nat`."

### Type Annotation with `the`

To check a lambda against a type, we use **`the`**:

```
(the T e)
```

This annotates expression `e` with type `T`. The type checker verifies that `e` actually has type `T`.

Let's check our increment function:

```
> (check (the (-> Nat Nat) (lam (x : Nat) (suc x))) : (-> Nat Nat))
OK
```

This is verbose, but it works. We're saying:
1. We have a lambda `(lam (x : Nat) (suc x))`
2. We annotate it with `the (-> Nat Nat) ...`
3. We check that the whole thing has type `(-> Nat Nat)`

In practice, we'll use **definitions** to avoid this repetition.

### Definitions

A **definition** binds a name to a value with an explicit type:

```
(def name : type body)
```

The definition persists in the global environment. You can refer to `name` in later expressions.

Let's define the identity function on natural numbers:

```
> (def myid : (-> Nat Nat) (lam (x : Nat) x))
myid : (-> Nat Nat) defined.
```

The REPL confirms the definition. Now we can use `myid`:

```
> (eval (myid zero))
zero : Nat
```

The identity function returns its argument unchanged. Applying `myid` to `zero` gives `zero`.

```
> (check (myid (suc zero)) : Nat)
OK
```

We can also check that `(myid (suc zero))` has type `Nat`. It does.

### Function Application

Application is written with simple juxtaposition:

```
(f a)
```

This applies function `f` to argument `a`.

Multiple arguments are applied left-to-right:

```
(f a b c)
```

This is shorthand for `((f a) b) c)`—curried application.

Example: define a constant function:

```
> (def const : (-> Nat (-> Nat Nat)) (lam (x : Nat) (lam (y : Nat) x)))
const : (-> Nat (-> Nat Nat)) defined.
```

Read the type: "`const` takes a `Nat` and returns a function from `Nat` to `Nat`."

Apply it:

```
> (eval ((const (suc zero)) zero))
1 : Nat
```

`const (suc zero)` returns a function that ignores its argument and always returns `(suc zero)` (i.e., 1). Applying that function to `zero` gives `1`.

With multiple arguments:

```
> (eval (const (suc zero) zero))
1 : Nat
```

Same result. `(f a b)` is `((f a) b)`.

### Chained Definitions

Definitions can refer to earlier definitions:

```
> (def one : Nat (suc zero))
one : Nat defined.
```

```
> (def two : Nat (suc one))
two : Nat defined.
```

```
> (eval two)
2 : Nat
```

The definition of `two` refers to `one`, which was defined earlier. The type checker tracks the dependency and evaluates `two` to `2`.

### Viewing the Environment

To see all current definitions, use `:env`:

```
> :env
  myid : (-> Nat Nat)
  const : (-> Nat (-> Nat Nat))
  one : Nat
  two : Nat
```

This shows the name, type, and normalized body of each definition.

### Errors: Unbound Variables

What if you refer to a name that doesn't exist?

```
> (eval undefined_var)
Error at <repl>:1:6
  Unbound variable: undefined_var
```

The type checker reports that `undefined_var` is not in scope. You must define it before using it.

---

## Section 4: Pairs and Dependent Pairs

Pairs bundle two values together. In most languages, the types of the two components are independent: `(Int, String)` is an integer paired with a string, and the string doesn't care what the integer is.

Prologos supports **dependent pairs**, where the *type* of the second component can *depend on the value* of the first component.

### Pair Syntax

Construct a pair:

```
(pair a b)
```

Project the first component:

```
(fst p)
```

Project the second component:

```
(snd p)
```

Example:

```
> (eval (fst (pair zero (suc zero))))
zero : Nat
```

```
> (eval (snd (pair zero (suc zero))))
1 : Nat
```

### Sigma Types

The type of a pair is a **Sigma type**:

```
(Sigma (x : A) B)
```

Read this as: "A pair where the first component has type `A`, and the second component has type `B`, which may mention `x`."

If `B` doesn't mention `x`, this is a regular (non-dependent) pair. If `B` *does* mention `x`, the second component's type depends on the first component's value.

### Non-Dependent Pairs

Let's start simple. A pair of two natural numbers:

```
> (check (pair zero (suc zero)) : (Sigma (_ : Nat) Nat))
OK
```

Here, `_` is a wildcard—we don't use the first component's value in the second component's type. So `(Sigma (_ : Nat) Nat)` is essentially `Nat × Nat`.

### Dependent Pairs

Now for the interesting part. Let's pair a natural number with *proof* that it equals `zero`.

First, a quick preview of the equality type (we'll cover this in detail in Section 6):

```
(Eq A a b)
```

This is the type of proofs that `a` and `b` are equal at type `A`.

The constructor `refl` proves that something equals itself.

Now, the dependent pair:

```
> (check (pair zero refl) : (Sigma (x : Nat) (Eq Nat x zero)))
OK
```

Let's unpack this:

1. The first component is `zero`, which has type `Nat`.
2. The second component is `refl`, which is a proof of `(Eq Nat x zero)` where `x` is bound to the first component's value.
3. Since the first component is `zero`, `x = zero`, so we need a proof of `(Eq Nat zero zero)`.
4. `refl` is exactly such a proof.

The type of the second component **depends on the value** of the first component. This is a dependent pair.

In a static language like Haskell or Java, you can't express this. You can pair a number with a boolean or a string, but you can't pair a number with *a proof about that specific number*. Dependent types make this possible.

### Why Does This Matter?

Dependent pairs let you bundle a value with **evidence** about that value.

Examples:
- A vector paired with proof that its length is even
- A user ID paired with proof that the user exists in the database
- A sorted list paired with proof that it's actually sorted

This pattern appears everywhere in verified code. You compute a value and simultaneously prove a property about it. The type system ensures the proof matches the value.

---

## Section 5: Dependent Function Types (Pi)

We've seen simple function types `(-> A B)`. Now we'll learn **Pi types**, where the *return type* depends on the *argument value*.

### Pi Type Syntax

```
(Pi (x : A) B)
```

Read this as: "A function taking `x` of type `A` and returning a value of type `B`, where `B` may mention `x`."

If `B` doesn't mention `x`, this is the same as `(-> A B)`. In fact, **`(-> A B)` is syntactic sugar for `(Pi (_ : A) B)`**—a Pi type where the return type doesn't depend on the argument.

### Polymorphic Identity

The canonical example of a dependent function is the **polymorphic identity function**.

In Haskell, you'd write:

```haskell
id :: forall a. a -> a
id x = x
```

In Prologos:

```
> (def id : (Pi (A :0 (Type 0)) (-> A A))
    (lam (A :0 (Type 0)) (lam (x : A) x)))
id : (Pi (A :0 (Type 0)) (-> A A)) defined.
```

> **Note on REPL display**: The REPL's pretty-printer uses de Bruijn indices internally, so you may see variable names like `x` or `?bvar1` instead of the names you chose. For example, the actual REPL output for this definition is `id : (Pi (x :0  (Type 0)) (-> x ?bvar1)) defined.` Throughout this tutorial, we show the more readable version using the original names.

Let's break this down.

**The type**: `(Pi (A :0 (Type 0)) (-> A A))`

- `id` takes a type `A` (which lives in `(Type 0)`)
- The `:0` annotation means `A` is **erased** at runtime (more on this in Section 10)
- `id` returns a function `(-> A A)`—a function from `A` to `A`

**The body**: `(lam (A :0 (Type 0)) (lam (x : A) x))`

- An outer lambda taking `A` (a type)
- An inner lambda taking `x` of type `A` (the type we just received)
- The body is `x`—return the argument unchanged

**Usage**:

```
> (eval (id Nat zero))
zero : Nat
```

We apply `id` to the type `Nat` (the type argument), then to the value `zero` (the value argument). The result is `zero`.

```
> (eval (id Bool true))
true : Bool
```

Now we apply `id` to the type `Bool` and the value `true`. The result is `true`.

The same function works for *any* type. The return type (`A`) depends on the first argument (the type `A` we pass in).

### Why Is This a Dependent Type?

Look at the type again:

```
(Pi (A :0 (Type 0)) (-> A A))
```

The return type `(-> A A)` **mentions `A`**, which is the parameter. The return type depends on the argument.

When we call `(id Nat ...)`, the return type is `(-> Nat Nat)`.

When we call `(id Bool ...)`, the return type is `(-> Bool Bool)`.

The type changes based on the argument. That's dependence.

### Erasure: The `:0` Annotation

Why `:0` on the type parameter?

At runtime, we don't need the type `A`. The identity function works the same way for all types—it just returns its argument. So we mark `A` as **erased** (multiplicity `:0`), telling the compiler: "This argument is only needed during type checking. Remove it from the compiled code."

Without `:0`, the compiled code would carry around type arguments at runtime, which is wasteful. With `:0`, those arguments vanish after type checking.

We'll cover this in depth in Section 10 (Quantitative Type Theory). For now, remember: `:0` means "erased."

### The Universe Hierarchy Revisited

What is the type of `id` itself?

```
> (infer id)
(Pi (A :0 (Type 0)) (-> A A))
```

And what is the type of *that*?

We need to know the type of `(Pi (A :0 (Type 0)) (-> A A))`.

The rule: if `A : (Type n)` and `B : (Type m)`, then `(Pi (x : A) B) : (Type max(n, m))`.

Here:
- `A` is `(Type 0)`, so `A : (Type 1)`
- `B` is `(-> A A)`, which expands to `(Pi (_ : A) A)`. Since `A : (Type 0)`, we have `B : (Type 0)`.
- Therefore, `(Pi (A :0 (Type 0)) (-> A A)) : (Type 1)`.

So `id : (Type 1)`.

Most of the time, you won't think about universe levels. But when you write polymorphic functions, you'll see `(Type 0)` and `(Type 1)` appear in types.

### Multiple Pi Parameters

You can have multiple dependent parameters. They nest:

```
(Pi (A : (Type 0)) (Pi (B : (Type 0)) (-> A (-> B A))))
```

This is a function taking two types `A` and `B`, returning a function from `A` to `B` to `A`.

This is the **constant function**, generalized to all types.

You could define it like this:

```
(def const2 : (Pi (A :0 (Type 0)) (Pi (B :0 (Type 0)) (-> A (-> B A))))
  (lam (A :0 (Type 0)) (lam (B :0 (Type 0)) (lam (x : A) (lam (y : B) x)))))
```

Usage:

```
> (eval (const2 Nat Bool zero true))
zero : Nat
```

The function ignores the second argument and returns the first.

---

## Section 6: Equality and Proofs

We've seen how to write values and functions. Now we'll see how to write **proofs**.

In Prologos, proofs are values. A proof that `a` equals `b` is a value of type `(Eq A a b)`. The type checker verifies that the proof is valid.

This is the foundation of **proof-carrying code**: your program includes not just data, but also evidence that the data satisfies certain properties.

### The Identity Type

The **identity type** (also called **equality type**) is written:

```
(Eq A a b)
```

Read this as: "A proof that `a` and `b` are equal at type `A`."

The constructor for this type is **`refl`** (reflexivity). It proves that something equals itself.

Example:

```
> (check refl : (Eq Nat zero zero))
OK
```

This checks that `refl` is a valid proof of `(Eq Nat zero zero)`—that `zero` equals `zero`.

### What Does `refl` Actually Check?

When you write `(check refl : (Eq A a b))`, the type checker does the following:

1. Normalize `a` to its normal form `a'`.
2. Normalize `b` to its normal form `b'`.
3. Check whether `a'` and `b'` are syntactically identical.

If they are, `refl` is a valid proof. If they aren't, the check fails.

This is **definitional equality**—equality by reduction. Two terms are equal if they reduce to the same normal form.

Example:

```
> (check refl : (Eq Nat (suc zero) (suc zero)))
OK
```

Both sides reduce to `(suc zero)`, so they're equal.

### When `refl` Fails

What if the two sides don't reduce to the same form?

```
> (check refl : (Eq Nat zero (suc zero)))
Error at <string>:1:0
  Type mismatch
  Expected: (Eq Nat zero (suc zero))
  Got:      (Eq Nat zero zero)
  In expression: refl
```

The type checker normalizes both sides:
- `zero` normalizes to `zero`
- `(suc zero)` normalizes to `(suc zero)`

They're not the same, so `refl` fails. The error message shows what `refl` actually proves (`(Eq Nat zero zero)`) versus what you asked for.

This is important: **you can only prove equalities that hold definitionally**. You can't prove `0 = 1` because they don't reduce to the same form. The type system is sound.

### Proofs as Values

Here's the key insight: **proofs are just values**.

When you write:

```
(pair zero refl)
```

You're constructing a pair containing:
1. The value `zero`
2. A proof that `zero = zero`

The proof is a first-class value. You can pass it to functions, store it in data structures, return it from computations.

In conventional programming, you might write:

```python
def get_first_element(arr):
    assert len(arr) > 0
    return arr[0]
```

The `assert` is a *runtime check*. If it fails, the program crashes.

In Prologos, you'd write:

```
(def get_first_element : (Pi (n : Nat) (-> (Vec A (suc n)) A))
  ...)
```

The type says: "Give me a vector of length `(suc n)` (i.e., at least 1), and I'll give you an element."

There's no `assert`. The type checker *guarantees* the vector is non-empty. The check happens at compile time, not runtime.

### The J Eliminator

The `refl` constructor is how you *build* proofs. The **J eliminator** is how you *use* proofs.

The syntax is:

```
(J motive base left right proof)
```

Where:
- **`motive`**: A function describing what you want to prove or compute using the equality
- **`base`**: The value to return when the proof is `refl`
- **`left`**: The left side of the equality
- **`right`**: The right side of the equality
- **`proof`**: The equality proof itself

The J eliminator is the **elimination principle** for the identity type. It says: "If you have a proof that `left = right`, and you know what to do when they're definitionally equal (`base`), then you can compute a result."

Example (simplified):

```
(J (lam (x : Nat) (lam (p : (Eq Nat zero x)) Nat))  ; motive
   (suc zero)                                       ; base
   zero                                              ; left
   zero                                              ; right
   refl)                                             ; proof
```

This says:
- The motive is: given `x` and a proof that `zero = x`, return a `Nat`.
- When the proof is `refl` (i.e., `x` is definitionally `zero`), return `(suc zero)`.
- The left side is `zero`.
- The right side is `zero`.
- The proof is `refl`.

The result is `(suc zero)`.

In practice, J is mostly used internally by the type checker. You'll rarely write it by hand. But it's the foundation of how equality proofs are used.

### Why This Matters

The identity type lets you **prove properties** and **carry those proofs** with your data.

You can prove:
- Two functions are extensionally equal
- A list is sorted
- A number is even
- A protocol was followed correctly

And the type checker verifies those proofs automatically.

This is the bridge from "types that describe data" to "types that describe correctness properties." It's what makes dependent types powerful.

In Section 7, we'll see how to define custom inductive types and prove theorems about them. But first, you've mastered the core calculus: functions, pairs, Pi types, and equality.

You now understand the foundation of dependent type theory.

## Section 7: Recursion with natrec

Prologos has no general recursion. There's no `while` loop, no `for` loop, and no unbounded recursion keyword. This is deliberate: the language doesn't have a termination checker yet, so instead of risking non-terminating programs, all recursion happens through **eliminators**—special constructs that come with built-in termination guarantees.

For natural numbers, that eliminator is **natrec**.

### Anatomy of natrec

The `natrec` construct has four parts:

```
(natrec motive base step target)
```

- **motive**: A function of type `(-> Nat (Type 0))`. It describes what type the result should have, depending on which Nat you're recursing over.
- **base**: The value returned when the target is `zero`. Must have type `(motive zero)`.
- **step**: A function that, given a predecessor `n` and an inductive hypothesis (the result for `n`), produces the result for `(suc n)`. Type: `(-> Nat (-> (motive n) (motive (suc n))))`.
- **target**: The Nat you're actually recursing on.

This might sound abstract, so let's build something concrete: addition.

### Building Addition with natrec

We want to compute `m + n`. The idea: recurse on `m`, adding `n` to it step by step.

Here's how the pieces fit together:

**The motive**: "For any natural number, the result is a Nat."

```
(the (-> Nat (Type 0))
     (lam (n : Nat) Nat))
```

This says: no matter what Nat we're recursing over, the answer will be a Nat. Simple.

**The base case**: What's the result when the target is `zero`? Well, `0 + n = n`. So the base case is just the second argument. For demonstration, let's hard-code it as `1`:

```
(suc zero)
```

This means we're computing `target + 1`.

**The step case**: Given a predecessor `n` and the inductive hypothesis `ih` (which is the result of adding `1` to `n`), return the result for `(suc n)`.

If `ih` represents `n + 1`, then `(suc n) + 1` is just `suc (n + 1)`, i.e., `(suc ih)`.

```
(the (-> Nat (-> Nat Nat))
     (lam (n : Nat) (lam (ih : Nat) (suc ih))))
```

**Putting it together**: Let's compute `2 + 1`.

```
(natrec (the (-> Nat (Type 0)) (lam (n : Nat) Nat))
        (suc zero)  ; base: 1
        (the (-> Nat (-> Nat Nat))
             (lam (n : Nat) (lam (ih : Nat) (suc ih))))
        (suc (suc zero)))  ; target: 2
```

This is verified in test-integration.rkt (test 9a). When evaluated, it produces `3`—which is indeed `2 + 1`.

### How natrec Reduces

The reduction rules are straightforward:

- **Base case**: `(natrec motive base step zero)` reduces to `base`.
- **Step case**: `(natrec motive base step (suc n))` reduces to:

```
((step n) (natrec motive base step n))
```

In other words: recurse on `n`, then apply the step function to both `n` and the recursive result.

Let's trace through `2 + 1`:

1. `(natrec motive 1 step (suc (suc zero)))`
2. Step rule: `((step (suc zero)) (natrec motive 1 step (suc zero)))`
3. Inner natrec reduces: `((step (suc zero)) ((step zero) (natrec motive 1 step zero)))`
4. Innermost natrec hits base: `((step (suc zero)) ((step zero) 1))`
5. `step` is `(lam (n : Nat) (lam (ih : Nat) (suc ih)))`, so:
   - `((step zero) 1)` → `(suc 1)` → `2`
   - `((step (suc zero)) 2)` → `(suc 2)` → `3`

Result: `3`. Exactly what we wanted.

### Why This Guarantees Termination

Every call to `natrec` recurses on a strictly smaller Nat (the predecessor). Since Nats have a base case (`zero`), recursion must eventually stop. The eliminator enforces this structurally—you can't write an infinite loop.

This is the trade-off: you give up the convenience of general recursion, and in return you get termination by construction.

### Using natrec in the REPL

The `natrec` form is available directly in the surface syntax. You can define addition, multiplication, and other recursive functions interactively:

```
> (def plus-motive : (-> Nat (Type 0))
    (lam (n : Nat) Nat))
plus-motive : (-> Nat (Type 0)) defined.
> (def plus-step : (-> Nat (-> Nat Nat))
    (lam (n : Nat) (lam (ih : Nat) (suc ih))))
plus-step : (-> Nat (-> Nat Nat)) defined.
> (def two : Nat (suc (suc zero)))
two : Nat defined.
> (eval (natrec plus-motive (suc zero) plus-step two))
3 : Nat
```

**💡 Key insight:** In Prologos, you don't define recursive functions by calling themselves. You define them by teaching the eliminator what to do at each step. The recursion happens inside the eliminator, safely and structurally.

---

## Section 8: Vectors — Types That Know Their Length

In most languages, arrays and lists have a length, but that length lives in a separate runtime value. You can ask for it (`len(my_list)`), but the type system doesn't know about it.

Prologos has **vectors**—lists indexed by their length at the type level. The type `(Vec A n)` represents a vector of exactly `n` elements, each of type `A`.

This isn't just documentation. The compiler enforces it. You cannot construct a vector of the wrong length, and you cannot call operations that assume a non-empty vector on an empty one.

### Constructors

Vectors have two constructors:

**vnil**: The empty vector.

```
(vnil A) : (Vec A zero)
```

Note: the type argument `A` is **explicit**. Prologos doesn't have implicit arguments yet, so you must pass the element type manually.

**vcons**: Prepend an element to a vector.

```
(vcons A n hd tl) : (Vec A (suc n))
```

Given:
- `A` — the element type
- `n` — the length of the tail (a Nat)
- `hd : A` — the head element
- `tl : (Vec A n)` — the tail vector

The result is a vector of length `suc n`.

### Building Vectors Step by Step

Let's construct a vector containing `[1]` (a single element):

```
> (check (vnil Nat) : (Vec Nat zero))
OK
> (check (vcons Nat zero (suc zero) (vnil Nat)) : (Vec Nat (suc zero)))
OK
```

Breaking down the second line:
- Element type: `Nat`
- Tail length: `zero` (the tail is empty)
- Head: `(suc zero)` (the number 1)
- Tail: `(vnil Nat)` (the empty vector)
- Result type: `(Vec Nat (suc zero))` — a vector of length 1

What if we claim it's length 2?

```
> (check (vcons Nat zero (suc zero) (vnil Nat)) : (Vec Nat (suc (suc zero))))
Error: Type mismatch
  Expected: (Vec Nat 2)
  Got:      (Vec Nat 1)
  In expression: (vcons Nat zero (suc zero) (vnil Nat))
```

The type checker knows the vector has exactly one element. You can't lie about it.

### A Two-Element Vector

Let's build `[1, 2]`:

```
> (def one : Nat (suc zero))
one : Nat defined.
> (def two : Nat (suc one))
two : Nat defined.
> (def vec-1 : (Vec Nat (suc zero))
    (vcons Nat zero one (vnil Nat)))
vec-1 : (Vec Nat 1) defined.
> (def vec-2 : (Vec Nat (suc (suc zero)))
    (vcons Nat (suc zero) two vec-1))
vec-2 : (Vec Nat 2) defined.
```

The type signature `(Vec Nat (suc (suc zero)))` explicitly states: "This is a vector of length 2 containing Nats."

### Eliminators: Safe Operations

Vectors come with several eliminators, all of which enforce safety at the type level.

**vhead**: Extract the first element of a non-empty vector.

```
(vhead A n v) : A
```

Given:
- `A` — element type
- `n : Nat` — the predecessor of the vector's length
- `v : (Vec A (suc n))` — a vector of length `suc n` (guaranteed non-empty)

Returns: the head element, of type `A`.

Notice the type of `v`: `(Vec A (suc n))`. This means `v` has at least one element. You **cannot** call `vhead` on `(vnil A)`, because `(Vec A zero)` doesn't match `(Vec A (suc n))` for any `n`.

**vtail**: Extract everything after the first element.

```
(vtail A n v) : (Vec A n)
```

Same constraint: `v` must have type `(Vec A (suc n))`. The result is the tail, which has length `n`.

**vindex**: Access an element by index.

```
(vindex A n i v) : A
```

Given:
- `A` — element type
- `n : Nat` — vector length
- `i : (Fin n)` — an index guaranteed to be in bounds (more on `Fin` in Section 9)
- `v : (Vec A n)` — the vector

Returns: the element at index `i`.

The key: `i` has type `(Fin n)`, which means it's a value in the range `[0, n)`. The type system guarantees the index is valid.

### The "Aha Moment"

Here's the dependent types payoff. In Python:

```python
my_list = []
print(my_list[0])  # Runtime error: IndexError
```

In Prologos:

```
> (eval (vhead Nat zero (vnil Nat)))
Error: Type mismatch
  Expected: (Vec Nat (suc ?n))
  Got:      (Vec Nat zero)
  In expression: (vnil Nat)
```

This isn't a runtime error. It's a **compile-time** error. The type checker sees that `vhead` requires a vector of type `(Vec A (suc n))`, but you provided `(Vec Nat zero)`. The code never runs, because it's provably wrong.

The bug is caught before execution. That's the power of dependent types.

### Comparison: Runtime Safety vs. Compile-Time Safety

| Language       | Empty list head            | Detection       |
|----------------|----------------------------|-----------------|
| Python         | `[][0]`                    | Runtime error   |
| JavaScript     | `[].shift()`               | Returns `undefined` |
| Rust           | `vec![].pop()`             | Returns `Option::None` |
| Prologos       | `(vhead A zero (vnil A))`  | Compile error   |

Rust's `Option` is an improvement—it forces you to handle the empty case. But you still have to check at runtime.

Prologos eliminates the runtime check entirely. If your code type-checks, the vector is non-empty. Period.

**💡 Key insight:** Vectors shift the burden of proof from runtime (where bugs lurk) to compile-time (where the type checker catches them). The cost is more explicit types. The benefit is fewer surprises.

---

## Section 9: Finite Types and Safe Indexing

How do you represent an index into a vector of length `n`? A Nat won't do—Nats go up to infinity, but a vector of length 3 only has three valid indices: 0, 1, and 2.

Prologos has **finite types**: `(Fin n)` is the type with exactly `n` inhabitants. `(Fin 3)` has three values. `(Fin 0)` has none.

This is the key to safe indexing: if `i : (Fin n)`, then `i` is guaranteed to be a valid index into any structure of length `n`.

### Constructors

Finite types have two constructors, mirroring the structure of Nats:

**fzero**: Represents the index 0 in a set of size at least 1.

```
(fzero n) : (Fin (suc n))
```

Given `n : Nat`, `(fzero n)` is the smallest element of `(Fin (suc n))`.

Note: `fzero` requires the set to have at least one element. There is no `fzero` for `(Fin zero)`, because an empty set has no elements—not even zero.

**fsuc**: Represents the successor of an index.

```
(fsuc n i) : (Fin (suc n))
```

Given:
- `n : Nat`
- `i : (Fin n)` — an index in a set of size `n`

The result is `(suc i)`, shifted into a set of size `suc n`.

### Building Indices

Let's construct the indices 0, 1, and 2 for `(Fin 3)`:

**Index 0**: `(fzero 2)` (0 in a set of size 3)

```
> (check (fzero (suc (suc zero))) : (Fin (suc (suc (suc zero)))))
OK
```

**Index 1**: `(fsuc 2 (fzero 1))` (successor of 0, in a set of size 3)

```
> (check (fsuc (suc (suc zero)) (fzero (suc zero)))
    : (Fin (suc (suc (suc zero)))))
OK
```

**Index 2**: `(fsuc 2 (fsuc 1 (fzero 0)))` (successor of 1)

```
> (check (fsuc (suc (suc zero))
           (fsuc (suc zero)
             (fzero zero)))
    : (Fin (suc (suc (suc zero)))))
OK
```

Notice the pattern: each `fsuc` increases the index by 1, and each `fzero` represents the starting point.

### The Impossible Type: (Fin zero)

What about `(Fin 0)`? This is the type with no inhabitants. There are no valid indices into an empty vector.

Try to construct one:

```
> (check (fzero zero) : (Fin zero))
Error: Type mismatch
  Expected: (Fin zero)
  Got:      (Fin (suc zero))
  In expression: (fzero zero)
```

`(fzero zero)` has type `(Fin (suc zero))`, i.e., `(Fin 1)`. You cannot coerce it into `(Fin 0)`, because `(Fin 0)` is uninhabited.

This is exactly what we want. If you have a value of type `(Fin 0)`, you've done something impossible. The type checker prevents it.

### Safe Indexing with vindex

Now we can combine `Fin` and `Vec` to get bounds-checked indexing:

```
(vindex A n i v) : A
```

Where:
- `i : (Fin n)` — an index guaranteed to be less than `n`
- `v : (Vec A n)` — a vector of length `n`

If the types match, the index is in bounds. Always.

### Example: Indexing into a Vector

Let's build a 2-element vector and index into it:

```
> (def two-vec : (Vec Nat (suc (suc zero)))
    (vcons Nat (suc zero) (suc (suc zero))
      (vcons Nat zero (suc zero) (vnil Nat))))
two-vec : (Vec Nat 2) defined.
> (def idx-0 : (Fin (suc (suc zero)))
    (fzero (suc zero)))
idx-0 : (Fin 2) defined.
> (eval (vindex Nat (suc (suc zero)) idx-0 two-vec))
2 : Nat
```

The vector is `[2, 1]`. Index 0 retrieves the first element: `2`.

What if we try an out-of-bounds index?

```
> (def idx-3 : (Fin (suc (suc (suc (suc zero)))))
    (fsuc (suc (suc zero)) (fzero (suc (suc zero)))))
idx-3 : (Fin 4) defined.
> (check (vindex Nat (suc (suc zero)) idx-3 two-vec) : Nat)
Error: Type mismatch
  Expected: (Fin 2)
  Got:      (Fin 4)
  In expression: idx-3
```

The index `idx-3` has type `(Fin 4)`—it's valid for a vector of length 4. But `two-vec` has length 2. The type checker rejects the call.

This is the guarantee: if `(vindex A n i v)` type-checks, the index is in bounds.

### Why This Matters

In conventional languages, array indexing is a runtime operation:

```python
my_list = [10, 20]
index = 5
print(my_list[index])  # Runtime error: IndexError
```

You write the code, run it, and it crashes. Maybe your tests catch it. Maybe they don't.

In Prologos, the equivalent code doesn't type-check:

```
> (check (vindex Nat (suc (suc zero))
           (fsuc (suc (suc zero)) (fzero (suc (suc zero))))
           two-vec)
    : Nat)
Error: Type mismatch
  Expected: (Fin 2)
  Got:      (Fin 4)
```

The type checker is your test suite. It runs before anything executes, and it covers every possible input.

**💡 Key insight:** Finite types turn runtime bounds checks into compile-time proofs. If your index type matches your vector length, the access is safe. No runtime overhead, no exceptions, no undefined behavior.

---

## Section 10: Linear Types and Resource Tracking

Most type systems tell you **what** data is: this is an integer, that's a string, this is a function from A to B.

**Quantitative Type Theory (QTT)** also tells you **how much** you can use it.

Every variable in Prologos has a **multiplicity** annotation:
- **`:w`** (omega, unrestricted) — use it zero, one, or many times
- **`:1`** (linear) — use it exactly once
- **`:0`** (erased) — don't use it at runtime at all

This is checked statically. If you try to use a linear variable twice, the type checker rejects it. If you try to use an erased variable at runtime, the type checker rejects it.

### Important Limitation: QTT in Phase 2

**QTT checking is implemented at the kernel level** (`checkQ-top` in `qtt.rkt`) but **not yet wired through the surface `(check ...)` command**. The surface syntax parses multiplicity annotations (`:0`, `:1`, `:w`), but the driver currently uses standard type checking (`check/err` from `typing-core.rkt`), not QTT checking.

This means:
- You can write `:1` and `:0` annotations in your code
- The syntax is valid and will parse correctly
- **But** the surface syntax does not yet enforce linearity or erasure

Full surface integration is planned for Phase 3.

This section explains the **concepts** and shows **kernel-verified examples** from the test suite. These examples are verified at the kernel level and demonstrate what QTT enforcement looks like. When surface integration is complete, the same rules will apply to your REPL sessions.

### The Three Multiplicities

**`:w` (unrestricted, omega)**: The default. Use the variable however you like—zero times, once, ten times, doesn't matter.

```
(lam (x :w Nat) (pair x x))
```

This duplicates `x`. That's fine, because `:w` allows unlimited use.

**`:1` (linear)**: Use the variable exactly once. Not zero times, not twice—once.

```
(lam (x :1 Nat) x)
```

This uses `x` exactly once. Acceptable.

```
(lam (x :1 Nat) (pair x x))
```

This uses `x` twice. **Not acceptable**—kernel test 7b verifies this fails QTT checking.

**`:0` (erased)**: Don't use the variable at runtime. It exists only for type-checking, and will be erased during compilation.

```
(lam (x :0 Nat) zero)
```

This ignores `x`. That's fine—`:0` variables are allowed (even encouraged) to be unused.

```
(lam (x :0 Nat) x)
```

This tries to return `x`, using it at runtime. **Not acceptable**—kernel test 7d verifies this fails QTT checking.

### The Multiplicity Semiring

Multiplicities combine according to algebraic rules:

**Addition** (using a variable in different branches):
- `0 + 0 = 0`
- `0 + 1 = 1`
- `1 + 1 = ω` (using a linear thing in two branches makes it unrestricted)
- `0 + ω = ω`
- `1 + ω = ω`
- `ω + ω = ω`

**Multiplication** (using a variable inside a λ-bound context):
- `0 × anything = 0` (erased context makes everything erased)
- `1 × 1 = 1` (linear inside linear is linear)
- `1 × ω = ω` (linear inside unrestricted is unrestricted)
- `ω × ω = ω`

These rules ensure that multiplicity constraints propagate correctly through your code.

### Kernel-Verified Examples

The following examples are verified in `test-integration.rkt` (tests 7a-7h). They use `checkQ-top` from `qtt.rkt`, which performs full QTT checking at the kernel level.

**✅ Linear identity (test 7a)**

```
(lam (x :1 Nat) x)
```

Uses `x` exactly once. Passes QTT checking with context requirement `{x ↦ 1}`.

**❌ Duplicate linear (test 7b)**

```
(lam (x :1 Nat) (pair x x))
```

Uses `x` twice. Fails QTT checking because `1 + 1 = ω`, but the variable is annotated `:1`.

**❌ Unused linear (test 7c)**

```
(lam (x :1 Nat) zero)
```

Doesn't use `x` at all. Fails QTT checking because linear variables must be used exactly once, not zero times.

**❌ Erased used at runtime (test 7d)**

```
(lam (x :0 Nat) x)
```

Tries to return `x`, but `x` is marked `:0` (erased). Fails QTT checking.

**✅ Erased correctly ignored (test 7e)**

```
(lam (x :0 Nat) zero)
```

Doesn't use `x`. This is correct—erased variables should not appear in runtime code. Passes QTT checking with context requirement `{x ↦ 0}`.

**✅ Omega used multiple times (test 7f)**

```
(lam (x :w Nat) (pair x x))
```

Uses `x` twice. This is fine—`:w` allows unlimited use. Passes QTT checking.

**✅ Polymorphic identity with erased type (test 7g)**

```
(lam (A :0 (Type 0)) (lam (x :w A) x))
```

The type parameter `A` is marked `:0`—it's used for type-checking, but erased at runtime. The value parameter `x` is `:w`. This is the standard pattern for polymorphism in QTT. Passes QTT checking.

**❌ Type parameter used at runtime (test 7h)**

```
(lam (A :0 (Type 0)) A)
```

Tries to return the type `A` as a value. Fails QTT checking because `:0` variables can't be used at runtime.

### Real-World Use Cases

Why would you want to restrict how many times a variable is used?

**File handles** (`:1`):
```
(lam (file :1 FileHandle) (close file))
```

You want to ensure every file is closed exactly once. Using it twice might double-close (corruption). Not using it leaks the resource.

**Database connections** (`:1`):
```
(lam (conn :1DBConnection) (execute conn query))
```

Connections should be used and released. Linear types enforce this.

**Secrets and API keys** (`:0`):
```
(lam (api-key :0 Secret) (authenticate api-key))
```

Wait—this seems wrong. If `api-key` is `:0`, how can we use it in `authenticate`?

Answer: `authenticate` is a compile-time operation (e.g., generating a token at build time). The secret is used during type-checking, but erased from the final binary. An attacker can't extract it from the compiled code, because it's not there.

**Type parameters** (`:0`):
```
(lam (A :0 (Type 0)) (lam (x :w A) x))
```

Types are only needed for checking. At runtime, `x` is just a value. The type `A` has been erased, shrinking the binary and avoiding runtime type tags.

### The Insight

Conventional type systems answer: "What is this thing?"

QTT answers: "What is this thing, and how am I allowed to use it?"

This turns resource management from a runtime concern (close the file, or else) into a type-system concern (if it type-checks, the file will be closed).

**💡 Key insight:** Linear types enforce **protocols** at the type level. Use this exactly once. Don't use that at all. The compiler enforces it, so you can't forget.

### When Surface Integration Arrives

In Phase 3, the REPL will enforce these checks directly:

```
> (check (lam (x :1 Nat) (pair x x)) : (-> Nat (Sigma (y : Nat) Nat)))
Error: Linear variable x used multiple times
  Expected usage: exactly once
  Actual usage: 2
  In expression: (lam (x :1 Nat) (pair x x))
```

Until then, the kernel tests demonstrate that the theory is sound and the implementation works. The surface syntax is ready; the wiring is pending.

---

## Section 11: Session Types — A Forward Look

Most type systems describe data: integers, strings, functions. **Session types** describe **communication protocols**—sequences of sends and receives that must happen in a specific order.

Imagine an ATM. The protocol might be:
1. Client chooses: deposit or query balance
2. If deposit: client sends amount, session ends
3. If query: server sends balance, session ends

Session types encode this protocol as a type. If your code violates the protocol—sends when it should receive, skips a step, sends the wrong type—the type checker rejects it.

### Status: Kernel-Only

Session types are **fully implemented at the kernel level** with comprehensive test coverage (test-integration.rkt tests 4-6, 8). They are **not yet available in the surface syntax**.

This section previews the concepts using examples from the kernel tests. When surface syntax support arrives in Phase 3, you'll be able to write session-typed programs interactively.

### Session Constructors

Sessions are built from these primitives:

**send(T, S)**: Send a value of type T, then continue with session S.

```
send(Nat, end)
```

"Send a Nat, then finish."

**recv(T, S)**: Receive a value of type T, then continue with session S.

```
recv(Nat, end)
```

"Receive a Nat, then finish."

**end**: Session complete. No further communication.

**choice(branches)**: Offer a choice to the other party. The client picks a branch by label.

```
choice { deposit → send(Nat, end),
         query   → recv(Nat, end) }
```

"Client: you can choose to deposit (then send me an amount) or query (then I'll send you the balance)."

**offer(branches)**: Receive a choice from the other party. The server follows the branch the client picked.

```
offer { deposit → recv(Nat, end),
        query   → send(Nat, end) }
```

"Server: I'll wait for you to choose deposit or query, then follow the corresponding protocol."

**dsend(T, S)** / **drecv(T, S)**: Dependent send/receive. The continuation session `S` can refer to the sent/received value.

```
dsend(Nat, send(Vec(Nat, n), end))
```

"Send a Nat `n`, then send a vector of length `n`."

**mu(S)**: Recursive session. Allows repeating protocols.

```
mu(choice { continue → send(Nat, var 0),
            stop     → end })
```

"Repeatedly offer: send a Nat and loop, or stop."

### Duality: Client and Server

Session types come in pairs. The **client** and **server** have **dual** types:

- Client's `send` ↔ Server's `recv`
- Client's `recv` ↔ Server's `send`
- Client's `choice` ↔ Server's `offer`
- Client's `offer` ↔ Server's `choice`

If the client and server types are dual, they can communicate safely. If not, the type checker rejects the connection.

### Example: ATM Protocol

From kernel test 5b:

**Client session**:
```
choice { deposit → send(Nat, end),
         query   → recv(Nat, end) }
```

The client offers two options:
- `deposit`: client will send a Nat (the amount), then end
- `query`: client will receive a Nat (the balance), then end

**Server session**:
```
offer { deposit → recv(Nat, end),
        query   → send(Nat, end) }
```

The server waits for the client to choose:
- If client picks `deposit`, server receives a Nat, then ends
- If client picks `query`, server sends a Nat, then ends

These are **dual**. The client's `send` matches the server's `recv`, and vice versa. The protocol is safe.

What if we swap one branch?

**Broken server**:
```
offer { deposit → send(Nat, end),  ; WRONG: should be recv
        query   → send(Nat, end) }
```

Now both parties want to send on the `deposit` branch. Deadlock. The duality check fails, and the type checker rejects this pairing.

### Dependent Sessions: Type-Level Guarantees on Protocols

Session types can depend on values. This lets you enforce protocols like "send the length, then send a vector of exactly that length."

From kernel test 6:

**Dependent send session**:
```
dsend(Nat, send(Vec(Nat, n), end))
```

- First, send a Nat `n`
- Then, send a vector of type `Vec(Nat, n)`—a vector of exactly `n` elements

The test verifies:
- ✅ Sending `n = 2` followed by a 2-element vector: type-checks
- ❌ Sending `n = 2` followed by a 1-element vector: type error

The session type enforces that the vector length matches the sent value. The protocol can't be violated.

**Dependent receive** works the same way:
```
drecv(Nat, recv(Vec(Nat, n), end))
```

Receive a Nat `n`, then receive a vector of length `n`. The type system guarantees consistency.

### Why Session Types Matter

In conventional systems, protocols are documented in comments or external specs:

```python
# ATM protocol:
# 1. Client sends "deposit" or "query"
# 2. If deposit, client sends amount
# 3. If query, server sends balance
```

This is informal. The code can violate it:

```python
client_send("query")
client_send(100)  # BUG: should receive, not send
```

Runtime error. Or worse: silent corruption.

With session types, the protocol is **in the type**:

```
choice { deposit → send(Nat, end),
         query   → recv(Nat, end) }
```

If your code sends when it should receive, the type checker rejects it. The protocol is enforced statically.

### When Surface Syntax Arrives

In Phase 3, you'll be able to define session types and session-typed processes directly:

```
> (def atm-client : SessionType
    (choice (cons (lab "deposit") (send Nat end))
            (cons (lab "query") (recv Nat end))))
atm-client : SessionType defined.
> (def atm-server : SessionType
    (dual atm-client))
atm-server : SessionType defined.
> (check (process ...)  ; client process
    : (Process atm-client))
OK
```

Until then, the kernel tests (test-integration.rkt tests 4-6, 8) demonstrate that session types work: duality checking, dependent sessions, process typing, and reduction.

**💡 Key insight:** Session types turn communication protocols from informal documentation into compile-time guarantees. If two processes have dual session types, they will follow the protocol correctly. No race conditions, no protocol violations, no deadlocks from type mismatches.

---

## Section 12: Putting It All Together

You've seen the pieces: dependent types, vectors, finite types, `natrec`, identity types, and the foundations of QTT and session types. Now let's combine them into a complete example, using only the features available in today's surface syntax.

This section walks through a full REPL session, building several definitions that depend on each other, demonstrating how the pieces fit together.

### The Goal

We'll define:
1. Basic constants: `one`, `two`, `three`
2. A polymorphic identity function with an erased type parameter
3. A type-safe vector construction
4. A dependent pair proving a property about a Nat
5. Inspection commands to verify our environment

### Session Start

Launch the REPL:

```
$ racket racket/prologos/repl.rkt
Prologos v0.2.0
Type :quit to exit, :env to see definitions, :load "file" to load a file.

>
```

### Define Constants

```
> (def one : Nat (suc zero))
one : Nat defined.
> (def two : Nat (suc one))
two : Nat defined.
> (def three : Nat (suc two))
three : Nat defined.
```

Each definition builds on the previous. `two` refers to `one`, `three` refers to `two`. The environment accumulates.

### Polymorphic Identity Function

```
> (def id : (Pi (A :0 (Type 0)) (-> A A))
    (lam (A :0 (Type 0)) (lam (x : A) x)))
id : (Pi (A :0 (Type 0)) (-> A A)) defined.
```

Breaking this down:

- **Type**: `(Pi (A :0 (Type 0)) (-> A A))`
  - A dependent function type
  - Takes a type `A` (erased, `:0`)
  - Returns a function from `A` to `A`
- **Body**: `(lam (A :0 (Type 0)) (lam (x : A) x))`
  - Outer lambda binds `A` (the type parameter)
  - Inner lambda binds `x` (the value)
  - Returns `x`

This is polymorphic identity. Let's use it:

```
> (eval (id Nat two))
2 : Nat
> (eval (id Bool true))
true : Bool
```

We pass the type explicitly (`Nat`, `Bool`) because Prologos doesn't have implicit arguments yet. But it works: same function, different types.

### Type-Safe Vector

Let's build a vector of length 2 containing `[2, 1]`:

```
> (def vec-2 : (Vec Nat (suc (suc zero)))
    (vcons Nat (suc zero) two
      (vcons Nat zero one
        (vnil Nat))))
vec-2 : (Vec Nat 2) defined.
```

The type signature says: "This is a vector of Nats, length 2."

The body constructs it step by step:
1. `(vnil Nat)` — empty vector
2. `(vcons Nat zero one (vnil Nat))` — prepend `one` to get `[1]`
3. `(vcons Nat (suc zero) two ...)` — prepend `two` to get `[2, 1]`

Verify it type-checks:

```
> (check vec-2 : (Vec Nat (suc (suc zero))))
OK
```

What if we claim it has length 3?

```
> (check vec-2 : (Vec Nat (suc (suc (suc zero)))))
Error: Type mismatch
  Expected: (Vec Nat 3)
  Got:      (Vec Nat 2)
  In expression: vec-2
```

The type checker knows the actual length.

### Dependent Pair: A Proof

Let's construct a proof that `zero` equals `zero`:

```
> (check (pair zero refl) : (Sigma (x : Nat) (Eq Nat x zero)))
OK
```

This is a **dependent pair**:
- First component: `zero` (a Nat)
- Second component: `refl` (a proof that `zero` equals `zero`)

The type `(Sigma (x : Nat) (Eq Nat x zero))` says: "A pair of a Nat `x` and a proof that `x` equals `zero`."

The pair `(pair zero refl)` satisfies this: `x` is `zero`, and `refl` proves `zero = zero`.

What if we use a different number?

```
> (check (pair one refl) : (Sigma (x : Nat) (Eq Nat x zero)))
Error: Type mismatch
  Expected: (Eq Nat one zero)
  Got:      (Eq Nat one one)
  In expression: refl
```

`refl` proves `one = one`, but the type demands a proof of `one = zero`. Those aren't equal, so the proof fails.

**This is proof by typing.** The type checker verifies logical correctness.

### Inspect the Environment

See what we've defined:

```
> :env
  one : Nat
  two : Nat
  three : Nat
  id : (Pi (A :0 (Type 0)) (-> A A))
  vec-2 : (Vec Nat 2)
```

All our definitions are in scope.

### Infer a Type

What's the type of `(id Bool true)`?

```
> :type (id Bool true)
Bool
```

The type checker infers: applying `id` to `Bool` and `true` produces a `Bool`.

### Verify with eval

```
> (eval three)
3 : Nat
> (eval (id Nat three))
3 : Nat
> (eval (vhead Nat (suc zero) vec-2))
2 : Nat
```

Everything evaluates as expected:
- `three` is 3
- `id` applied to `three` is 3
- The head of `vec-2` is 2 (the first element)

### Summary of Techniques Used

This session demonstrated:
- **Incremental definitions**: Build on previous definitions
- **Type signatures**: Always annotate `def` with types
- **Explicit type arguments**: Pass types manually (no implicits)
- **Dependent pairs**: Combine values and proofs
- **Vectors**: Length-indexed types
- **Polymorphism**: One function, many types
- **REPL commands**: `:env`, `:type`, `eval`, `check`

**💡 Key insight:** Prologos programs are built incrementally, layer by layer. Each definition extends the environment. The type checker ensures each layer is sound before moving to the next. By the time you finish, the entire program is verified.

---

## Section 13: Design Patterns and Idioms

Learning a new language isn't just learning syntax—it's learning the **idioms**: the patterns that make the language feel natural. Here are the key patterns for writing Prologos effectively.

### Pattern 1: Annotate at Boundaries

**Always** provide type signatures for `def` and parameter annotations for `lam`.

Why? Prologos uses **bidirectional type checking**: annotations flow inward. If you annotate the boundary (the `def` or the `lam`), the type checker can infer types for the body.

**Good**:
```
> (def double : (-> Nat Nat)
    (lam (n : Nat) (natrec ...)))
```

The type signature on `def` and the parameter type on `lam` give the type checker enough information to verify the `natrec`.

**Bad**:
```
> (def double (lam (n) (natrec ...)))
Error: Cannot infer type for parameter n
```

Without annotations, the type checker doesn't know what `n` is.

**Rule of thumb**: Annotate every boundary. Let inference handle the interior.

### Pattern 2: Use `the` When Inference Fails

Sometimes the type checker needs a hint. Use `(the T expr)` to provide an inline type annotation.

Example: Constructing a motive for `natrec`:

```
(the (-> Nat (Type 0))
     (lam (n : Nat) Nat))
```

This tells the type checker: "This lambda has type `(-> Nat (Type 0))`."

Without `the`, the type checker might not infer the correct type for the lambda, especially in complex contexts.

**When to use**: When you get a "Cannot infer type" error, wrap the problematic subexpression with `the`.

### Pattern 3: Explicit Type Arguments

Prologos doesn't have implicit arguments yet. When calling a polymorphic function, you must pass the type explicitly.

```
> (eval (id Nat two))  ; Good
2 : Nat
> (eval (id two))  ; Bad: missing type argument
Error: Type mismatch
  Expected: (Type 0)
  Got:      Nat
```

This is verbose, but unambiguous. The surface syntax knows exactly which arguments are types and which are values.

**Phase 3 roadmap**: Implicit arguments will allow `(id two)` by inferring `Nat`.

### Pattern 4: Read Error Messages Bottom-Up

Prologos error messages follow this structure:

```
Error: Type mismatch
  Expected: (Vec Nat 3)
  Got:      (Vec Nat 2)
  In expression: vec-2
```

Read **bottom-up**:
1. **"In expression: vec-2"** — This is WHERE the error occurred
2. **"Expected/Got"** — This is WHAT went wrong
3. **"Type mismatch"** — This is the category of error

The "In expression" line often points to a subexpression deep inside your code. That's where the types didn't match.

**Debugging tip**: If the error points to a subexpression you didn't write explicitly (e.g., an auto-generated term), check the surrounding context. The real bug is often one level up.

### Pattern 5: Start with `check`, Then `def`

When defining something complex, first verify it type-checks:

```
> (check (vcons Nat zero one (vnil Nat)) : (Vec Nat (suc zero)))
OK
> (def vec-1 : (Vec Nat (suc zero))
    (vcons Nat zero one (vnil Nat)))
vec-1 : (Vec Nat 1) defined.
```

This two-step workflow:
1. Ensures the expression is correct before committing it to the environment
2. Gives immediate feedback if something's wrong
3. Avoids polluting the environment with broken definitions

**Workflow**: `check` → fix errors → `def`.

### Pattern 6: Use `:env` and `:type` Liberally

Forget what you've defined? Use `:env`:

```
> :env
  one : Nat
  two : Nat
  id : (Pi (A :0 (Type 0)) (-> A A))
```

Forget a type? Use `:type`:

```
> :type (id Nat two)
Nat
```

These commands are **read-only**—they don't change the environment, they just inspect it.

**Debugging tip**: If a definition fails to type-check, use `:type` on subexpressions to see where the inferred type diverges from your expectation.

### Pattern 7: Factor Complex Types into Definitions

Long types are hard to read. Factor them out:

**Hard to read**:
```
> (def foo : (Pi (A :0 (Type 0)) (-> A (Sigma (x : A) (Eq A x x))))
    ...)
```

**Easier**:
```
> (def Reflexive : (-> (Type 0) (Type 0))
    (lam (A : (Type 0)) (Sigma (x : A) (Eq A x x))))
Reflexive : (-> (Type 0) (Type 0)) defined.
> (def foo : (Pi (A :0 (Type 0)) (-> A (Reflexive A)))
    ...)
```

Now `Reflexive` is a reusable type-level function. The signature of `foo` is readable.

**When to factor**: If a type appears more than once, or if it's longer than one line, factor it out.

### Pattern 8: Match Constructor Argument Order Exactly

Vector constructors require arguments in a specific order:

```
(vcons A n hd tl)
```

- `A` (type)
- `n` (length of tail)
- `hd` (head element)
- `tl` (tail vector)

Don't guess. Check the syntax reference (Appendix A) or the error message.

**Common mistake**:
```
> (check (vcons Nat one zero (vnil Nat)) : (Vec Nat (suc zero)))
Error: Type mismatch
  Expected: Nat
  Got:      (Vec Nat zero)
```

Here, `one` and `zero` are swapped. The error says "Expected: Nat" because the third argument (head) should be a Nat, but you provided `(vnil Nat)`.

**Fix**: Match the order exactly.

### Pattern 9: Use `eval` to Normalize

When types look equivalent but the checker disagrees, normalize them:

```
> (eval (suc (suc zero)))
2 : Nat
> (eval two)
2 : Nat
```

If both normalize to the same value, they're definitionally equal.

**When to use**: Debugging type mismatches where you expect two terms to be equal.

**💡 Key insight:** Prologos idioms prioritize explicitness over brevity. Annotate boundaries. Pass types explicitly. Factor complex types. The verbosity pays off in clarity: when code type-checks, you know exactly what it does.

---

## Section 14: Limitations and Roadmap

Prologos is under active development. Phase 2 (the Racket implementation) has accomplished a lot: dependent types, QTT at the kernel level, session types at the kernel level, and a working REPL. But several features are still in progress or planned for future phases.

Here's what's **not yet available**, and when it's coming.

### No Implicit Arguments

**Limitation**: All type arguments must be passed explicitly.

Example: The polymorphic identity function requires passing the type manually:

```
> (eval (id Nat two))
2 : Nat
```

You can't omit `Nat` and write `(id two)`.

**Why**: Implicit argument resolution requires inference heuristics and unification, which are implemented but not yet integrated into the surface syntax.

**Planned**: Phase 3 will add implicit arguments. You'll write:

```
> (eval (id two))  ; Infers Nat from two
2 : Nat
```

### No Pattern Matching

**Limitation**: There are no `match` or `case` expressions. All recursion and case analysis happens through eliminators: `natrec`, `J`, `vhead`/`vtail`, etc.

Example: Instead of:

```
match n with
| zero => base
| suc n' => step n'
```

You write:

```
(natrec motive base step n)
```

**Why**: Pattern matching is syntactic sugar over eliminators. Prologos prioritizes getting the kernel right before adding syntactic conveniences.

**Planned**: Phase 3 will add pattern matching that desugars to eliminator calls.

### No Termination Checking

**Limitation**: There's no general recursion. You can't write:

```
(def loop : (-> Nat Nat)
  (lam (n : Nat) (loop n)))
```

All recursion must go through eliminators, which are structurally terminating.

**Why**: Implementing a termination checker (e.g., sized types, guardedness checks) is complex and orthogonal to the core type theory.

**Planned**: Phase 3 may add a termination checker for certain classes of recursive definitions. For now, eliminators guarantee termination.

### Session Types Not in Surface Syntax

**Limitation**: Session types exist at the kernel level (`prologos/sessions.rkt`, `prologos/typing-sessions.rkt`) with full test coverage, but the surface syntax doesn't support them yet.

You can't write:

```
> (def atm-client : SessionType
    (choice ...))
```

**Why**: Session-typed process syntax requires additional parsing and elaboration rules. The kernel is ready; the surface layer is pending.

**Planned**: Phase 3 will integrate session types into the surface syntax, allowing you to define session types, write processes, and check protocol compliance interactively.

### QTT Checking Not Wired Through Surface Commands

**Limitation**: The surface syntax parses multiplicity annotations (`:0`, `:1`, `:w`), but the `(check ...)` command uses standard type checking, not QTT checking.

You can write:

```
> (check (lam (x :1 Nat) (pair x x)) : (-> Nat (Sigma (y : Nat) Nat)))
OK
```

This **should** fail (linear variable used twice), but it doesn't—the surface driver doesn't call `checkQ-top`.

**Why**: QTT checking (`checkQ-top` in `qtt.rkt`) is implemented and tested at the kernel level, but integrating it into the driver requires plumbing multiplicity contexts through the entire elaboration pipeline.

**Planned**: Phase 3 will wire QTT checking into the surface syntax. The above example will correctly fail.

### No Logic Programming / Unification

**Limitation**: Prologos is designed to unify logic programming with dependent types, but the logic programming features (unification, relational queries, backtracking search) are not yet implemented.

**Planned**: Phase 4 will add logic programming features, allowing you to write:

```
> (query (append ?xs ?ys [1, 2, 3]))
?xs = [], ?ys = [1, 2, 3]
?xs = [1], ?ys = [2, 3]
?xs = [1, 2], ?ys = [3]
?xs = [1, 2, 3], ?ys = []
```

This will interleave with the type system, allowing dependently-typed logic programs.

### No Propagators

**Limitation**: Propagator-based constraint solving (a planned feature for incremental computation and constraint logic programming) is not yet implemented.

**Planned**: Phase 4 will add propagators, enabling declarative constraint solving:

```
> (propagator (x + y = 10) (x > 5))
x ∈ (5, 10], y ∈ [0, 5)
```

This will integrate with types and logic programming to create a unified framework.

### Roadmap Summary

| Feature                  | Phase 2 (Current) | Phase 3 (Surface) | Phase 4 (Logic) |
|--------------------------|-------------------|-------------------|-----------------|
| Dependent types          | ✅ REPL           | Implicits         | —               |
| QTT (linear/erased)      | ✅ Kernel         | ✅ Surface        | —               |
| Session types            | ✅ Kernel         | ✅ Surface        | —               |
| Pattern matching         | ❌ (use elims)    | ✅ Surface        | —               |
| Termination checking     | ❌ (use elims)    | ✅ Partial        | ✅ Full         |
| Logic programming        | ❌                | ❌                | ✅ Full         |
| Propagators              | ❌                | ❌                | ✅ Full         |

**Phase 3 focus**: Surface syntax integration—implicits, pattern matching, QTT enforcement, session types in the REPL.

**Phase 4 focus**: Logic programming, unification, propagators, and the full Prologos vision.

**💡 Key insight:** Prologos is being built in layers. Each phase solidifies one layer before moving to the next. Phase 2 delivered a verified kernel and a usable REPL. Phase 3 will make it ergonomic. Phase 4 will make it uniquely powerful.

---

## Appendix A: Syntax Quick Reference

### REPL Commands

| Command                   | Description                          |
|---------------------------|--------------------------------------|
| `(def name : type body)`  | Define a top-level constant          |
| `(check expr : type)`     | Verify `expr` has type `type`        |
| `(eval expr)`             | Evaluate `expr` and show normal form |
| `(infer expr)`            | Infer the type of `expr`             |
| `:quit` / `:q`            | Exit the REPL                        |
| `:env`                    | Show all definitions in scope        |
| `:load "path"`            | Load definitions from a file         |
| `:type expr`              | Infer and display the type of `expr` |

### Types

| Syntax                  | Description                              |
|-------------------------|------------------------------------------|
| `Nat`                   | Natural numbers (zero, suc)              |
| `Bool`                  | Booleans (true, false)                   |
| `(-> A B)`              | Non-dependent function type              |
| `(Pi (x :m A) B)`       | Dependent function type (B may use x)    |
| `(Sigma (x : A) B)`     | Dependent pair type (B may use x)        |
| `(Eq A a b)`            | Identity type: proof that a = b in A     |
| `(Vec A n)`             | Vector of n elements of type A           |
| `(Fin n)`               | Finite type with exactly n inhabitants   |
| `(Type n)`              | Universe at level n                      |

### Terms

| Syntax                         | Description                               |
|--------------------------------|-------------------------------------------|
| `zero`                         | The natural number 0                      |
| `(suc n)`                      | Successor of n                            |
| `true`                         | Boolean true                              |
| `false`                        | Boolean false                             |
| `refl`                         | Reflexivity proof: x = x                  |
| `(lam (x :m A) e)`             | Lambda abstraction                        |
| `(pair a b)`                   | Dependent pair constructor                |
| `(fst p)`                      | First projection of pair p                |
| `(snd p)`                      | Second projection of pair p               |
| `(the T e)`                    | Type annotation: e has type T             |
| `(natrec mot base step tgt)`   | Nat eliminator (recursion)                |
| `(J mot base l r prf)`         | Identity eliminator (equality reasoning)  |
| `(vnil A)`                     | Empty vector of type A                    |
| `(vcons A n hd tl)`            | Prepend hd to vector tl                   |
| `(vhead A n v)`                | Head of non-empty vector                  |
| `(vtail A n v)`                | Tail of non-empty vector                  |
| `(vindex A n i v)`             | Index into vector v at position i         |
| `(fzero n)`                    | Zero index in Fin (suc n)                 |
| `(fsuc n i)`                   | Successor index in Fin (suc n)            |

### Multiplicities

| Annotation | Meaning                                  |
|------------|------------------------------------------|
| `:w`       | Unrestricted (use zero, one, or many times) |
| `:1`       | Linear (use exactly once)                |
| `:0`       | Erased (don't use at runtime)            |

**Note**: Multiplicity checking is kernel-only in Phase 2. Surface integration planned for Phase 3.

### Operator Precedence

Prologos uses prefix notation (Lisp-style). Precedence is determined by parentheses, not operator priority.

**Examples**:
- `(suc (suc zero))` — suc applied to (suc zero)
- `(-> Nat Nat)` — function type from Nat to Nat
- `(Pi (A :0 (Type 0)) (-> A A))` — Pi type binding A, body is (-> A A)

---

## Appendix B: Glossary

**Bidirectional type checking**: A type-checking algorithm that alternates between two modes: **inference** (compute the type of an expression) and **checking** (verify an expression has a given type). Annotations guide the direction.

**Conversion**: Two terms are **convertible** (or **definitionally equal**) if they normalize to the same value. Prologos uses conversion to check type equality.

**De Bruijn index**: A variable representation using numbers instead of names. Index `0` refers to the innermost binder, `1` to the next outer, etc. Avoids name capture issues.

**Definitional equality**: See **Conversion**.

**Dependent pair (Sigma)**: A pair `(a, b)` where the type of `b` depends on the value of `a`. Written `(Sigma (x : A) B)`, where `B` may refer to `x`.

**Dependent type**: A type that depends on a value. Example: `(Vec A n)` depends on the value `n`.

**Duality**: A relationship between session types where client and server types are mirror images. Client's `send` is server's `recv`, and vice versa.

**Elaboration**: The process of translating surface syntax into kernel terms. Resolves implicits, inserts coercions, and desugars syntactic conveniences.

**Eliminator**: A construct that performs recursion or case analysis on a datatype. Examples: `natrec` for Nats, `J` for identity types, `vhead`/`vtail` for vectors.

**Erasure**: Removing parts of a term that are not needed at runtime. In QTT, variables marked `:0` are erased before execution.

**Identity type (Eq)**: The type `(Eq A a b)` represents a proof that `a` and `b` are equal in type `A`. Constructed with `refl`, eliminated with `J`.

**Linear type**: A type where values must be used exactly once. Enforced by QTT with multiplicity `:1`.

**Motive**: A type-level function used by eliminators to describe the result type. For `natrec`, the motive has type `(-> Nat (Type 0))`.

**Multiplicity**: A QTT annotation indicating how many times a variable can be used: `:0` (erased), `:1` (linear), `:w` (unrestricted).

**Normal form**: A term with no remaining computation steps. Fully reduced. Used by the conversion checker to compare terms.

**Pi type**: A dependent function type `(Pi (x :m A) B)`, where the result type `B` may depend on the argument `x`.

**QTT (Quantitative Type Theory)**: An extension of type theory that tracks **how much** a variable is used, not just **what type** it has. Enables linear types, erasure, and resource tracking.

**Session type**: A type describing a communication protocol. Specifies sequences of sends, receives, choices, and recursion. Checked for duality.

**Sigma type**: See **Dependent pair**.

**Universe level**: An index on type universes. `(Type 0)` is the universe of small types, `(Type 1)` contains `(Type 0)`, etc. Prevents paradoxes like Russell's paradox.

---

## Appendix C: Comparison with Other Systems

Prologos combines features from several language families. Here's how it compares to similar systems:

| Feature                     | Prologos         | Idris 2          | Agda             | TypeScript       |
|-----------------------------|------------------|------------------|------------------|------------------|
| **Dependent types**         | Full             | Full             | Full             | No               |
| **Linear/QTT**              | Kernel (Phase 2) | Full             | No               | No               |
| **Session types**           | Kernel (Phase 2) | No (libraries)   | No (libraries)   | No               |
| **Implicit arguments**      | Planned (Phase 3)| Yes              | Yes              | N/A              |
| **Totality checking**       | Via eliminators  | Optional         | Optional         | No               |
| **Syntax style**            | Lisp (prefix)    | Haskell-like     | Haskell-like     | C-like           |
| **Runtime**                 | Racket (interp)  | Native (compiled)| Native (compiled)| JavaScript (VM)  |
| **Logic programming**       | Planned (Phase 4)| No               | No               | No               |
| **Propagators**             | Planned (Phase 4)| No               | No               | No               |

### Detailed Comparison

**Idris 2**: A dependently-typed language with QTT, focusing on general-purpose programming. Prologos shares the QTT foundation but adds session types and (eventually) logic programming.

**Agda**: A proof assistant with full dependent types and a powerful inference engine. More academic than Idris. Prologos is more focused on practical fusion of paradigms (logic, session types, QTT).

**TypeScript**: A gradually-typed language for JavaScript. No dependent types or linearity. Included for contrast—Prologos targets correctness guarantees TypeScript can't provide.

**Unique to Prologos**:
- **Logic programming integration** (Phase 4): Dependently-typed logic programs with unification
- **Propagators** (Phase 4): Constraint solving at the type level
- **Session types as a core feature**: Built into the type system from the ground up
- **Lisp syntax**: Uniform, prefix notation—simple to parse, easy to metaprogram

### Why Prologos?

If you want:
- **Dependent types + session types**: Prologos (when Phase 3 lands)
- **Dependent types + linear types**: Idris 2 or Prologos
- **Proof-oriented development**: Agda or Prologos
- **Logic programming + types**: Prologos (Phase 4) or Mercury (less powerful types)
- **Gradual typing for JavaScript**: TypeScript

Prologos is an exploration of what happens when you combine dependent types, linearity, session types, logic programming, and propagators in one system. It's experimental, but the foundations are solid.

---

*Prologos is under active development. For the latest, see the project repository.*
