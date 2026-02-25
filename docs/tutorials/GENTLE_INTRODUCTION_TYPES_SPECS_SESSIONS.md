- [Who This Is For](#org4f9d587)
- [Spiral 1: Just Write Functions](#org8aaf921)
  - [1.1 Your First Prologos Function](#orge84f7aa)
  - [1.2 Pattern Matching](#orgce80d72)
  - [1.3 Collections Work Like You'd Expect](#org8145317)
- [Spiral 2: Adding Type Signatures with `spec`](#org19db2a8)
  - [2.1 Why Bother?](#orgb60ba91)
  - [2.2 Level 1: Simple Types](#org1339439)
  - [2.3 Level 2: Generics (Polymorphism)](#orgf25fcc7)
  - [2.4 Level 3: Constrained Generics](#org2ebb9a0)
- [Spiral 3: `spec` as Self-Documenting Metadata](#org69cfc21)
  - [3.1 Beyond Types: Specs as Rich Descriptions](#org5347484)
  - [3.2 Why This Matters](#orgb9dac16)
  - [3.3 The Graduation Path](#org452378f)
- [Spiral 4: Higher-Kinded Types (Without the Jargon)](#org18ff835)
  - [4.1 The Problem: Writing Generic Code Over Containers](#orgcf2fc10)
  - [4.2 Prologos: Traits Over Containers](#orgf4e8192)
  - [4.3 You Already Know This Pattern](#org474cafe)
- [Spiral 5: `functor` &#x2014; Naming Complex Types](#org7d545c6)
  - [5.1 The Problem: Type Signatures Get Long](#orge943fe1)
  - [5.2 The Solution: Name It](#orgd58742d)
  - [5.3 Progressive Metadata on `functor`](#org7ed7b50)
  - [5.4 The Key Insight](#org7409596)
- [Spiral 6: Channels and Protocols (Session Types)](#org0fabf64)
  - [6.1 The Problem: Communication Goes Wrong](#orgc95bfc9)
  - [6.2 Session Types: Protocols as Types](#org5da2629)
  - [6.3 Branching Protocols: Choice and Offer](#org2edf51d)
  - [6.4 Dependent Sessions: Protocols That Depend on Values](#org6588810)
- [Spiral 7: Capabilities and the Eventual Send](#org5d10890)
  - [7.1 A Quick Grounding: What Are Capabilities?](#org936251e)
  - [7.2 Channels as Capabilities](#orge2b3ee0)
  - [7.3 Linear Types Prevent Capability Duplication](#orgfe68fd7)
  - [7.4 The Eventual Send](#orgeb4a8f0)
  - [7.5 How This Compares to OCapN](#orge0eb2af)
- [Spiral 8: Dependent Types (The Deeper Layer)](#org660b047)
  - [8.1 You've Already Used Them](#org5ab3a1f)
  - [8.2 The Full Progressive Complexity Ladder](#orgbb0c3cc)
  - [8.3 `??` : The "What Goes Here?" Hole](#org301560d)
- [Spiral 9: The Big Picture &#x2014; `spec`, `functor`, `session`](#orgbfeed49)
  - [9.1 The Keyword Symmetry](#orgad69224)
  - [9.2 They All Compose](#org4c26e21)
- [Where To Go From Here](#orge24cccb)
  - [The Progressive Complexity Promise](#orgb93c6f1)
- [Further Reading](#org19c8c85)
  - [Prologos Design Documents](#org22acb56)
  - [The Codebase](#orgc963199)
  - [Capability-Based Security](#org897a2d1)

> "The language is actually designed to be minimal in ceremony and syntax, and look friendly and inviting to any programmer generally familiar with functional programming; although there are layers of depth to unlock further expressiveness, if they choose to go there."


<a id="org4f9d587"></a>

# Who This Is For

You write JavaScript or TypeScript. You've shipped production services. You might know about capability-based security from the OCapN community, or about distributed systems from building real infrastructure. You've heard terms like "dependent types" and "session types" but they sound academic.

This tutorial shows you that Prologos's type system is *not* academic. It's a pragmatic tool for catching bugs you've been catching with tests, conventions, and code review. You can use as little or as much of it as you want &#x2014; the layers are opt-in.

**Prerequisites:** Familiarity with a typed language (TypeScript, Java, Rust) and comfort with first-class functions (`map`, `filter`, `reduce`).

**What you won't need:** Category theory, proof assistants, Greek letters, or a PhD.


<a id="org8aaf921"></a>

# Spiral 1: Just Write Functions


<a id="orge84f7aa"></a>

## 1.1 Your First Prologos Function

```prologos
defn greet [name]
  [string-append "Hello, " name]
```

That's it. No type annotations. Prologos infers that `name` is a `String` and the return value is a `String`. If you've used TypeScript with `noImplicitAny` off, this feels familiar &#x2014; write code, let the system figure out the types.

Key syntax note: `[]` is for function application. `defn greet [name]` defines a function `greet` that takes `name`. `[string-append "Hello, " name]` calls `string-append` with two arguments.


<a id="orgce80d72"></a>

## 1.2 Pattern Matching

```prologos
defn factorial
  | [0] -> 1
  | [n] -> [* n [factorial [- n 1]]]
```

The `|` arms define cases directly on the function — no separate `match` expression needed. Brackets `[...]` are for function calls. This reads naturally: "factorial of 0 is 1; factorial of n is n times factorial of (n - 1)."


<a id="org8145317"></a>

## 1.3 Collections Work Like You'd Expect

```prologos
;; List literal
def xs '[1 2 3 4 5]

;; PVec (persistent vector -- like Clojure's vectors)
def ys @[10 20 30]

;; Map (persistent hash map)
def user {:name "Alice" :age 30}

;; Set (persistent hash set)
def primes #{2 3 5 7}

;; Generic operations work on ALL of them
map inc xs                      ;; => '[2 3 4 5 6]
map inc ys                      ;; => @[11 21 31]
filter [fn [x] [> x 3]] xs      ;; => '[4 5]
reduce + 0 xs                   ;; => 15
into @[] xs                     ;; => @[1 2 3 4 5]  (List -> PVec)
```

`map`, `filter`, `reduce` work generically on Lists, PVecs, Sets &#x2014; any collection type. If you've used Clojure's seq abstraction or Rust's iterators, this is the same idea: one set of function names, all collection types, type-preserving.


<a id="org19db2a8"></a>

# Spiral 2: Adding Type Signatures with `spec`


<a id="orgb60ba91"></a>

## 2.1 Why Bother?

Type inference is great for small functions. But as code grows, explicit type signatures become *documentation that the compiler checks*. TypeScript developers know this instinct &#x2014; you *could* let TS infer everything, but `: number` on a function parameter prevents a whole class of bugs.

In Prologos, type signatures live in `spec` declarations &#x2014; separate from the function body. Think of `spec` as TypeScript's `interface` for a single function:


<a id="org1339439"></a>

## 2.2 Level 1: Simple Types

```prologos
spec add : Int Int -> Int
defn add [x y] [+ x y]
```

Read this as: "`add` takes an `Int` and an `Int` and returns an `Int`." Arrow `(->)` separates arguments from return type.

This is the equivalent of TypeScript's:

```typescript
function add(x: number, y: number): number { ... }
```


<a id="orgf25fcc7"></a>

## 2.3 Level 2: Generics (Polymorphism)

```prologos
spec id : A -> A
defn id [x] x
```

`A` is a type variable &#x2014; just like TypeScript's `<T>`. Prologos infers that `A` is a type parameter because it appears free in the signature (starts with a capital letter, not a known type). No need to write the equivalent of `<A>`.

TypeScript equivalent:

```typescript
function id<A>(x: A): A { return x; }
```


<a id="org2ebb9a0"></a>

## 2.4 Level 3: Constrained Generics

What if your generic function needs the type to support certain operations?

```prologos
spec sort : [List A] -> [List A]
  :where (Ord A)
defn sort [xs] ...
```

`:where (Ord A)` means "`A` must support ordering." This is like TypeScript's `<A extends Comparable<A>>` but more flexible &#x2014; traits (Prologos's version of interfaces) are resolved automatically.

The user writes `sort '[3 1 2]` &#x2014; the compiler sees `A = Int`, finds `Int`'s `Ord` instance, and passes it in automatically. Zero ceremony at the call site.


<a id="org69cfc21"></a>

# Spiral 3: `spec` as Self-Documenting Metadata


<a id="org5347484"></a>

## 3.1 Beyond Types: Specs as Rich Descriptions

Here's where Prologos diverges from TypeScript. A `spec` isn't *just* a type signature &#x2014; it's a structured metadata record. You can attach documentation, examples, and properties *right next to the type*:

```prologos
spec sort : [List A] -> [List A]
  :where (Ord A)
  :doc "Sort a list in ascending order using merge sort"
  :examples
    - [sort '[3 1 2]] => '[1 2 3]
    - [sort '[]] => '[]
  :properties
    - :name "preserves-length"
      :holds [eq? [length [sort xs]]
                  [length xs]]
    - :name "idempotent"
      :holds [eq? [sort [sort xs]]
                  [sort xs]]
```

Let's break this down:

| Key           | What it does                                      | Analogy                          |
|------------- |------------------------------------------------- |-------------------------------- |
| `:doc`        | Human-readable description                        | JSDoc `@description`             |
| `:examples`   | Concrete input/output pairs                       | Jest `test("should...")`         |
| `:properties` | Universal invariants (for all valid inputs)       | QuickCheck / fast-check property |
| `:where`      | Trait constraints (interfaces the type must have) | TS `extends` constraint          |


<a id="orgb9dac16"></a>

## 3.2 Why This Matters

In JavaScript, these live in *four different places*:

1.  Types: TypeScript `.d.ts` files or inline annotations
2.  Docs: JSDoc comments (often stale)
3.  Examples: Unit tests in a separate `*.test.js` file
4.  Properties: Property-based tests in a third file (if you have them at all)

In Prologos, they're *all part of the spec*. The compiler reads them. The tooling reads them. They're always in sync because they live next to the function they describe.


<a id="org452378f"></a>

## 3.3 The Graduation Path

This is the key design philosophy: **you opt in to more precision**. Each level adds information without changing the previous levels:

```prologos
;; Level 0: No types at all. Inference does the work.
defn add [x y] [+ x y]

;; Level 1: Add a type signature.
spec add : Int Int -> Int
defn add [x y] [+ x y]

;; Level 2: Add documentation.
spec add : Int Int -> Int
  :doc "Integer addition"
defn add [x y] [+ x y]

;; Level 3: Add examples.
spec add : Int Int -> Int
  :doc "Integer addition"
  :examples
    - [add 2 3] => 5
defn add [x y] [+ x y]

;; Level 4: Add properties.
spec add : Int Int -> Int
  :doc "Integer addition"
  :examples
    - [add 2 3] => 5
  :properties
    - :name "commutative"
      :holds [eq? [add x y]
                  [add y x]]
    - :name "identity"
      :holds [eq? [add x 0] x]
defn add [x y] [+ x y]
```

At no point do you need to understand dependent types, Pi types, or category theory. You're just adding metadata that the compiler checks.

**The implementation doesn't change.** Only the specification becomes richer.


<a id="org18ff835"></a>

# Spiral 4: Higher-Kinded Types (Without the Jargon)


<a id="orgcf2fc10"></a>

## 4.1 The Problem: Writing Generic Code Over Containers

You know `map` works on arrays in JavaScript. But what if you want to write a function that works on *any container* &#x2014; arrays, Sets, Maps, async iterables &#x2014; without knowing which one?

In TypeScript, this is awkward. You'd need overloads or a complex generic:

```typescript
// TypeScript: you end up with overloads
function fmap<A, B>(f: (a: A) => B, xs: Array<A>): Array<B>;
function fmap<A, B>(f: (a: A) => B, xs: Set<A>): Set<B>;
// ... one per container type
```


<a id="orgf4e8192"></a>

## 4.2 Prologos: Traits Over Containers

In Prologos, the `Functor` trait captures "any container you can map over":

```prologos
spec fmap : [A -> B] -> [F A] -> [F B]
  :where (Functor F)
  :doc "Apply a function inside any container"
```

Read `F` as "some container type." `F A` means "a container of `A` values." The `:where (Functor F)` constraint says "`F` must be a type that supports mapping."

Usage &#x2014; zero ceremony:

```prologos
fmap inc '[1 2 3]            ;; => '[2 3 4]
fmap inc @[1 2 3]           ;; => @[2 3 4]
fmap to-string '[1 2]       ;; => '["1" "2"]
```

The compiler sees `F = List` or `F = PVec`, finds the right `Functor` instance, and dispatches automatically. This is like Rust's trait system or Haskell's type classes, but with less syntax.


<a id="org474cafe"></a>

## 4.3 You Already Know This Pattern

If you've used JavaScript's `Symbol.iterator` protocol, you know this idea:

```javascript
// JS: any object with [Symbol.iterator] is iterable
for (const x of anyIterable) { ... }
```

Prologos traits are the typed version of protocols: any type that implements `Seqable` (the "can produce a sequence" trait) works with `map`, `filter`, `reduce`, etc. The compiler *proves* the implementation exists, rather than discovering at runtime that it doesn't.


<a id="org7d545c6"></a>

# Spiral 5: `functor` &#x2014; Naming Complex Types


<a id="orge943fe1"></a>

## 5.1 The Problem: Type Signatures Get Long

As your code becomes more generic, type signatures grow:

```prologos
;; This is getting hard to read...
spec compose-xf : <(S :0 Type) -> [S -> B -> S] -> S -> A -> S>
                  -> <(S :0 Type) -> [S -> C -> S] -> S -> B -> S>
                  -> <(S :0 Type) -> [S -> C -> S] -> S -> A -> S>
```

Those angle brackets `<...>` contain *dependent types* &#x2014; types that mention runtime values. We'll get to what that means later. For now, the point is: this signature is unreadable.


<a id="orgd58742d"></a>

## 5.2 The Solution: Name It

```prologos
functor Xf {A B : Type}
  :doc "A transducer: transforms A-reductions into B-reductions"
  :unfolds <(S :0 Type) -> [S -> B -> S] -> S -> A -> S>
```

Now the signature becomes:

```prologos
spec compose-xf : [Xf A B] -> [Xf B C] -> [Xf A C]
  :doc "Compose two transducers"
```

`functor` is Prologos's way of saying: "I'm naming a complex type pattern so I never have to write out the full thing." It's like TypeScript's `type` alias on steroids:

```typescript
// TypeScript equivalent (roughly)
type Xf<A, B> = <S>(step: (s: S, b: B) => S) => (s: S, a: A) => S;
```


<a id="org7ed7b50"></a>

## 5.3 Progressive Metadata on `functor`

Just like `spec`, `functor` supports progressive metadata:

```prologos
functor Xf {A B : Type}
  :doc "A transducer: transforms A-reductions into B-reductions"
  :unfolds <(S :0 Type) -> [S -> B -> S] -> S -> A -> S>
  :compose xf-compose     ;; "this type composes via xf-compose"
  :identity id-xf         ;; "the identity element is id-xf"
  :laws (transducer-laws)  ;; "it must satisfy these algebraic laws"
```

You don't need `:compose`, `:identity`, or `:laws` to use `functor`. Start with just `:unfolds`. Add algebraic structure when you need it.


<a id="org7409596"></a>

## 5.4 The Key Insight

The dependent type (`<...>`) lives in `:unfolds`, consulted only when the compiler needs it. The programmer-facing surface is just `Xf A B`.

**Dependent types are the implementation substrate. The surface language speaks in domain terms.**

This is Prologos's design philosophy in a nutshell. The deep theory is there when you need it &#x2014; but it's behind a door you never have to open unless you want to.


<a id="org0fabf64"></a>

# Spiral 6: Channels and Protocols (Session Types)


<a id="orgc95bfc9"></a>

## 6.1 The Problem: Communication Goes Wrong

If you've built distributed services, you know the pain: the client sends a JSON object, the server expects a different shape, and things silently break. Or worse: the client sends two messages when the server expects one, and the connection hangs.

These are *protocol bugs*. TypeScript can't catch them &#x2014; the type system doesn't model sequences of messages. REST API schemas (OpenAPI) are documentation, not enforcement. gRPC is closer, but still doesn't verify that your client and server agree on the *order* of messages.


<a id="org5da2629"></a>

## 6.2 Session Types: Protocols as Types

Prologos can express communication protocols *in the type system*:

```prologos
;; A session defines the shape of a conversation
session Greeter
  send name : String       ;; client sends a string
  recv greeting : String   ;; client receives a string
  end                      ;; conversation is over
```

This says: "A `Greeter` session starts with the client sending a `String` (the name), then the server responds with a `String` (the greeting), then the conversation ends."

The compiler checks *both sides*:

-   The client must send a `String` first, then receive a `String`
-   The server must receive a `String` first, then send a `String` (the *dual* &#x2014; send becomes receive, receive becomes send)

If either side violates the protocol, it's a *compile-time error*.


<a id="org2edf51d"></a>

## 6.3 Branching Protocols: Choice and Offer

Real protocols have branches. Think of an HTTP-like interaction:

```prologos
session DatabaseService
  rec Loop                  ;; recursive protocol (can repeat)
    offer                   ;; server offers these choices:
      | :query              ;; client can select :query
          recv q : Query    ;;   send a query
          send r : Result   ;;   get a result back
          Loop              ;;   and go again
      | :close              ;; or client can select :close
          end               ;;   and we're done
```

The server =offer=s branches; the client =select=s one. This is like a tagged union of possible message sequences. The compiler verifies that the server handles every branch the client might choose.


<a id="org6588810"></a>

## 6.4 Dependent Sessions: Protocols That Depend on Values

Here's where Prologos goes beyond what gRPC or OpenAPI can express:

```prologos
session VecProtocol (A : Type)
  recv n : Nat             ;; client sends a number
  send v : [Vec A n]       ;; server sends a vector of THAT length
  end
```

The type of the *second* message depends on the *value* of the first. If the client sends `3`, the server must send a vector of length 3. Not "some vector" &#x2014; *exactly* 3 elements. The compiler proves this.

This is a **dependent session type** &#x2014; the protocol shape depends on runtime values. No mainstream language can express this.


<a id="org5d10890"></a>

# Spiral 7: Capabilities and the Eventual Send


<a id="org936251e"></a>

## 7.1 A Quick Grounding: What Are Capabilities?

Object-capability security (ocap) is a model where authority comes from *possession of a reference*, not from ambient identity checks (like ACLs or ambient auth). The idea originates in Mark Miller's E language (2000s) and is being standardized for decentralized networks by the [OCapN pre-standardization group](https://ocapn.org/), with implementations in Spritely Goblins (Guile Scheme) and the [Endo](https://github.com/endojs/endo) project (JavaScript/Hardened JS).

The core principles:

-   **No ambient authority**: you can't "import" a database handle from thin air. Someone must hand you a reference.
-   **Attenuation**: you can give someone a *weaker* version of your authority (read-only view, rate-limited proxy, etc.)
-   **Transfer**: you can pass a capability to someone else — and if it's unique, passing it means *you no longer have it*.
-   **Composition**: capabilities are just references — they compose like any other value.

If you've built systems with OAuth tokens, API keys, or dependency injection, you've been *approximating* ocap informally. The difference is enforcement: in Prologos, the compiler verifies these properties.


<a id="orge2b3ee0"></a>

## 7.2 Channels as Capabilities

In Prologos, a typed channel *is* a capability. Consider:

```prologos
session ReadOnlyDB
  rec Loop
    offer
      | :query
          recv q : Query
          send r : Result
          Loop
      | :close
          end
```

If a function receives a channel of type `ReadOnlyDB`, it can *only* query and close. It cannot insert, delete, or modify data &#x2014; not because of a runtime ACL check, but because those operations don't exist in the session type. The *type itself is the attenuation boundary*.

This maps directly to the ocap principle of attenuation: the `ReadOnlyDB` session type is a *powerless facet* of a full `DatabaseService` &#x2014; same database, smaller authority surface.


<a id="orgfe68fd7"></a>

## 7.3 Linear Types Prevent Capability Duplication

Prologos's linear types (QTT &#x2014; Quantitative Type Theory) add another layer. A channel marked with multiplicity `:1` (linear) cannot be duplicated:

```prologos
;; If db-channel is linear (:1), you cannot do this:
let chan1 = db-channel
let chan2 = db-channel   ;; TYPE ERROR: db-channel already consumed
```

This means: if I give you my database channel, *I no longer have it*. That's capability transfer &#x2014; enforced by the compiler. No need for runtime wrappers or trust assumptions.


<a id="orgeb4a8f0"></a>

## 7.4 The Eventual Send

The *eventual send* is a fundamental concept from Mark Miller's E language (and now central to OCapN's CapTP &#x2014; the Capability Transport Protocol). The idea: instead of blocking on a remote call, you fire off a message and get back a *promise*. The remote side processes it asynchronously. Multiple messages can be in-flight simultaneously.

In JavaScript, this concept is making its way in via the [TC39 proposal-eventual-send](https://github.com/tc39/proposal-eventual-send), with syntax like `E(target).method(args)`.

Prologos provides this natively via `!!` (non-blocking send) and `recv!` (non-blocking receive):

```prologos
defproc db-client [queries : List Query] : List QueryResult
  let channel = [connect DatabaseService]

  ;; Fire all queries without waiting (eventual sends)
  let promises = [map [fn [q]
    select :query channel
    send q channel
    recv! channel           ;; recv! = eventual receive, returns promise
  ] queries]

  ;; Do other work while queries execute...
  [log "queries submitted, waiting..."]

  ;; Collect all results when ready
  let results = [map await promises]

  select :close channel
  results
```

The `recv!` operation returns a promise. Multiple queries fly out concurrently. `await` collects the results. The session type *still guarantees* that every query gets exactly one response &#x2014; the protocol is preserved even in the asynchronous case.

This is analogous to E's *promise pipelining*: rather than waiting for each round trip, you send all your messages and let the promises resolve in whatever order the network delivers. The key difference: Prologos's session type statically proves that the promise chain is well-formed &#x2014; every send has a matching receive, every branch is handled.


<a id="orge0eb2af"></a>

## 7.5 How This Compares to OCapN

| OCapN / E Concept           | Prologos Equivalent                             | Enforcement       |
|--------------------------- |----------------------------------------------- |----------------- |
| Object reference            | Typed channel endpoint                          | Compile-time type |
| Capability attenuation      | Session type (can only do what the type says)   | Compile-time type |
| No ambient authority        | Linear types prevent copying channels           | Compile-time QTT  |
| Eventual send (`E(x).m()`)  | `!!` / `send!` (non-blocking send)              | Compile-time type |
| Promise                     | `recv!` returns a promise; `await` resolves     | Compile-time type |
| Promise pipelining          | Multiple `recv!` in-flight; session type tracks | Compile-time type |
| Vat (isolated object graph) | Process with linear channel context             | Compile-time QTT  |
| CapTP (capability transfer) | Channel passing (linear: transfer of authority) | Compile-time QTT  |
| Sealer/Unsealer pairs       | Existential types (Sigma) — pack/unpack         | Compile-time type |

The key difference from existing ocap implementations: in Spritely's Goblins, capabilities are enforced at *runtime* by the Guile Scheme VM. In Endo/Hardened JS, they're enforced by the SES (Secure ECMAScript) sandbox. In Prologos, capabilities are enforced at *compile time* by the type checker. If your program type checks, protocol violations are *impossible*. The type system *is* the capability system.

> "Logos with session types gives you ocap where the capability protocol is enforced by the compiler, not just convention." &#x2014; from project design discussion


<a id="org660b047"></a>

# Spiral 8: Dependent Types (The Deeper Layer)


<a id="org5ab3a1f"></a>

## 8.1 You've Already Used Them

If you read the `VecProtocol` example above and understood it, you've already used dependent types. A dependent type is just a type that mentions a runtime value:

```prologos
spec replicate : <(n : Nat) -> A -> [Vec A n]>
```

"Given a number `n`, return a vector of *exactly* `n` elements." The return type depends on the argument value. That's it. That's a dependent type.

The angle brackets `<...>` mark the dependent part. Everything outside angle brackets is regular ML-style typing. This visual separator means you can *see* where dependency happens.


<a id="orgbb0c3cc"></a>

## 8.2 The Full Progressive Complexity Ladder

Let's revisit the levels, now that you have the intuition:

| Level | What You Write                        | What It Means                       | TypeScript Analogy        |
|----- |------------------------------------- |----------------------------------- |------------------------- |
| 0     | `defn add [x y] [+ x y]`              | No types (inference)                | TS with `any`             |
| 1     | `spec add : Int -> Int -> Int`        | Concrete types                      | `function add(x: number)` |
| 2     | `spec id : A -> A`                    | Generics                            | `function id<A>(x: A): A` |
| 3     | `spec sort : ... :where (Ord A)`      | Constrained generics                | `<A extends Comparable>`  |
| 4     | `spec fmap : ... :where (Functor F)`  | Higher-kinded generics              | No TS equivalent          |
| 5     | `functor Xf {A B} :unfolds ...`       | Named type abstractions             | `type Xf<A,B> = ...`      |
| 6     | `spec replicate : <(n : Nat) -> ...>` | Dependent types (Pi)                | No TS equivalent          |
| 7     | `spec filter : ... <result * proof>`  | Dependent pairs (Sigma/existential) | No TS equivalent          |

Levels 0-3 are familiar territory for any TypeScript developer. Level 4 is where Prologos starts going beyond what mainstream languages offer. Levels 5-7 are opt-in power tools.

**You never have to leave the level you're comfortable at.** Code at Level 1 and code at Level 7 coexist in the same codebase, call each other, and are type-checked together.


<a id="org301560d"></a>

## 8.3 `??` : The "What Goes Here?" Hole

When working with complex types, Prologos provides typed holes &#x2014; write `??` where you don't know what to put, and the compiler tells you what type it expects:

```prologos
defn zip-with
  | [f vnil _]             -> vnil
  | [f _ vnil]             -> ??           ;; What goes here?
  | [f (vcons x xs) (vcons y ys)]
      -> [vcons [f x y] [zip-with f xs ys]]
```

The compiler responds:

```
Hole ?? at line 3
Expected type: Vec B 0
In context:
  f  : A -> A -> B
  xs : Vec A (suc n)
  ys : Vec A 0
Hint: The only value of type Vec B 0 is vnil
```

This is *interactive type-driven development*. The types guide you toward the correct implementation. Start with holes, let the compiler fill in the blanks. It's like pair programming with the type checker.


<a id="orgbfeed49"></a>

# Spiral 9: The Big Picture &#x2014; `spec`, `functor`, `session`


<a id="orgad69224"></a>

## 9.1 The Keyword Symmetry

Prologos has a deliberate symmetry in its specification language:

| Keyword    | What It Describes                   | Analogy                          |
|---------- |----------------------------------- |-------------------------------- |
| `spec`     | Function type + metadata            | TypeScript function signature    |
| `trait`    | A method that types must implement  | TypeScript/Java interface method |
| `bundle`   | A group of traits (AND conjunction) | `extends A & B & C`              |
| `property` | A group of testable invariants      | QuickCheck property suite        |
| `functor`  | A named, reusable type pattern      | TypeScript `type` alias (richer) |
| `session`  | A communication protocol            | gRPC service definition (richer) |


<a id="org4c26e21"></a>

## 9.2 They All Compose

The keywords aren't isolated features &#x2014; they build on each other:

```prologos
;; A property group
property transducer-laws {A B C : Type}
  :holds [eq? [compose-xf id-xf xf] xf]       ;; identity law
  :holds [eq? [compose-xf [compose-xf f g] h]
               [compose-xf f [compose-xf g h]]] ;; associativity

;; A type abstraction
functor Xf {A B : Type}
  :doc "A transducer"
  :unfolds <(S :0 Type) -> [S -> B -> S] -> S -> A -> S>
  :compose xf-compose
  :identity id-xf
  :laws (transducer-laws)

;; A function spec using the above
spec map-xf : [A -> B] -> [Xf A B]
  :doc "Transducer that applies f to each element"
  :examples
    - [into-list [map-xf inc] '[1 2 3]] => '[2 3 4]

;; A trait using all of the above
trait Transducible {C : Type -> Type}
  :laws (transducer-fusion C)
  to-xf : {A B : Type} -> [A -> B] -> [Xf A B]
```

**The `functor` names the type. The `property` states its laws. The `spec` uses both. The `trait` packages it for generic dispatch. Everything is readable. The dependent types are present exactly once, in `:unfolds`, consulted only when needed.**


<a id="orge24cccb"></a>

# Where To Go From Here


<a id="orgb93c6f1"></a>

## The Progressive Complexity Promise

Prologos is designed so that:

1.  A developer who uses Level 0-2 (no types or simple generics) is productive immediately
2.  A developer who uses Level 3-4 (traits + higher-kinded types) writes highly reusable library code
3.  A developer who uses Level 5-7 (functors + dependent types) writes code with compiler-verified correctness guarantees
4.  A developer who uses session types writes distributed systems where protocol violations are compile-time errors
5.  A developer who uses linear types writes capability-secure code where authority is tracked by the compiler

All five levels coexist. Code at any level can call code at any other level. The type checker handles the complexity; you choose how much specification you want to write.

> "Dependent types are the fabric upon which everything is built &#x2014; and can be reached for in pure form if ever needed &#x2014; but otherwise use `functor`, `spec`, etc., with their implicit maps."


<a id="org19c8c85"></a>

# Further Reading


<a id="org22acb56"></a>

## Prologos Design Documents

-   `docs/tracking/2026-02-22_EXTENDED_SPEC_DESIGN.md` &#x2014; the full `spec=/=functor=/=property` design (the document that inspired this tutorial)
-   `docs/tracking/principles/LANGUAGE_VISION.md` &#x2014; the overall vision
-   `docs/otto_conversation.org` &#x2014; a conversation exploring session types, OCapN, and capabilities in depth


<a id="orgc963199"></a>

## The Codebase

-   `lib/prologos/core/` &#x2014; trait definitions and standard library
-   `lib/prologos/data/` &#x2014; collection types (List, PVec, Map, Set)
-   `tests/` &#x2014; comprehensive tests showing every feature in action
-   `docs/spec/grammar.ebnf` &#x2014; the formal grammar of the language


<a id="org897a2d1"></a>

## Capability-Based Security

-   [OCapN Pre-standardization Group](https://ocapn.org/) &#x2014; the community defining decentralized capability networking
-   [CapTP Draft Specification](https://github.com/ocapn/ocapn/blob/main/draft-specifications/CapTP%20Specification.md) &#x2014; the wire protocol for capability transfer between machines
-   [Spritely Goblins OCapN Docs](https://spritely.institute/files/docs/guile-goblins/0.10/OCapN-The-Object-Capabilities-Network.html) &#x2014; reference implementation in Guile Scheme
-   [Endo / Hardened JavaScript](https://github.com/endojs/endo) &#x2014; JavaScript-native ocap (SES, eventual send, Agoric)
-   [TC39 Proposal: Eventual Send](https://github.com/tc39/proposal-eventual-send) &#x2014; bringing E-style eventual send to JavaScript
-   [Awesome Object Capabilities](https://github.com/dckc/awesome-ocap) &#x2014; curated reading list on the ocap model
-   Mark S. Miller, *Robust Composition: Towards a Unified Approach to Access Control and Concurrency Control* (2006) &#x2014; the foundational dissertation on E and capabilities
