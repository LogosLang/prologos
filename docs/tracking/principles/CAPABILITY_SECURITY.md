# Capability Security

- [The Principle](#the-principle)
- [Why Capabilities, Not Access Control](#why-capabilities)
  - [The ACL Model and Its Failures](#acl-failures)
  - [Object Capabilities: References as Authority](#ocap)
  - [The Prologos Insight: Linear Values as Capabilities](#prologos-insight)
- [QTT as Capability Discipline](#qtt-capabilities)
  - [The Three Multiplicity Modes](#three-modes)
  - [The `:w` Tension: Capabilities vs. Traits](#w-tension)
  - [Authority Checking vs. Authority Transfer](#checking-vs-transfer)
  - [Capability Attenuation](#attenuation)
- [Capabilities as Implicit Parameters](#implicit-capabilities)
  - [The Ergonomic Requirement](#ergonomic-requirement)
  - [Traits Are Ambient; Capabilities Are Not](#ambient-vs-scoped)
  - [Lexically-Scoped Implicit Resolution](#lexical-resolution)
  - [The Capability Closure](#capability-closure)
- [Capability Composition](#composition)
  - [Fine-Grained Capabilities](#fine-grained)
  - [Union Types as Composite Capabilities](#composite-union)
  - [Attenuation as Subtyping](#attenuation-subtyping)
- [The Entry Point as Authority Root](#authority-root)
- [Dependent Capabilities](#dependent-capabilities)
- [Session Types and Capability Protocols](#session-types)
- [Design Principles for Capabilities in Prologos](#design-principles)
- [Relationship to Other Principles](#relationships)
- [Inspirations](#inspirations)

---

<a id="the-principle"></a>

# The Principle

**Prologos is capability-secure by design.** Authority to perform effects — reading files, writing to the network, accessing databases, spawning processes — is expressed through fine-grained capabilities in the type system. The compiler verifies the Principle of Least Authority (POLA) statically: every function's type signature is a manifest of exactly what authority it requires, and no more.

This is not a bolted-on security layer. It is an intrinsic property of the type system, emerging from the combination of three features Prologos already has:

- **QTT (linear types)** — capabilities cannot be duplicated or forged
- **Dependent types** — capabilities can be scoped to specific resources
- **Session types** — capability delegation follows verified protocols

The goal is a security model as lightweight and pervasive as QTT itself: three symbols (`:0`, `:1`, `:w`) give you resource safety; a few capability traits give you authority safety. Low friction, high assurance.

---

<a id="why-capabilities"></a>

# Why Capabilities, Not Access Control

<a id="acl-failures"></a>

## The ACL Model and Its Failures

Traditional security uses Access Control Lists: a matrix of (subject, object, permission) triples, checked at runtime. This model has deep problems:

1. **Ambient authority** — subjects accumulate permissions over time. A function that "runs as user X" inherits all of X's permissions, even if it only needs to read one file. The confused deputy problem arises because authority flows through the identity of the caller, not through explicit delegation.

2. **TOCTOU races** — checking permissions at one moment doesn't guarantee they hold at the moment of use. The gap between check and use is a vulnerability window.

3. **No compositional reasoning** — you cannot determine a function's authority from its type signature. You must inspect the entire runtime permission state. Code review for security becomes a whole-program analysis.

<a id="ocap"></a>

## Object Capabilities: References as Authority

The object-capability (ocap) model, pioneered by Dennis and Van Horn (1966) and refined by Mark Miller's E language and the KeyKOS/EROS/seL4 lineage, inverts the model:

- **A reference IS the capability.** If you have a reference to a file handle, you can use it. If you don't, you can't. There is no separate permission check.
- **Capabilities propagate by explicit delegation.** You can only obtain a capability by being handed one — through a function parameter, a return value, or a message. No ambient authority.
- **Capabilities are unforgeable.** The runtime (or type system) ensures that capabilities cannot be constructed from nothing.
- **Attenuation is natural.** You can create a weaker capability from a stronger one (read-only from read-write) and hand out only what's needed.

This gives compositional reasoning: a function's authority is exactly the set of capabilities it receives as parameters. No more, no less.

<a id="prologos-insight"></a>

## The Prologos Insight: Linear Values as Capabilities

In the E language, capabilities are object references. In seL4, capabilities are kernel-managed tokens. In Prologos, **capabilities are linear values in the type system**:

- **Unforgeability**: A capability type has no public constructors. Only the runtime (or a trusted entry point) can mint them.
- **No duplication**: A `:1` capability cannot be copied. You cannot amplify your authority by cloning a capability.
- **Mandatory consumption**: A `:1` capability must be used. Capabilities don't silently leak — if you have one, you must either use it, delegate it, or explicitly drop it.
- **Type-level tracking**: The type checker tracks exactly which capabilities flow through every function call. Security analysis is type checking.

This is strictly stronger than runtime capability systems: violations are caught at compile time, not at runtime. And it requires no new mechanisms — it falls out of QTT, which Prologos already has.

---

<a id="qtt-capabilities"></a>

# QTT as Capability Discipline

<a id="three-modes"></a>

## The Three Multiplicity Modes

QTT's three multiplicities map precisely to three modes of capability usage:

| QTT | Symbol | Capability Mode | Meaning |
|-----|--------|-----------------|---------|
| Erased | `:0` | **Authority proof** | Compile-time evidence that you *could* use this capability. No runtime cost. The type checker verifies it exists; the compiled code never touches it. |
| Linear | `:1` | **Transferable authority** | A runtime token representing authority. Can be used, delegated, or attenuated — but exactly once. This is capability transfer in the seL4 sense. |
| Unrestricted | `:w` | **Ambient authority** | Authority available without restriction. **The compiler should warn when `:w` is used on a capability type.** Capability-bearing values should default to `:0` (erased proof) or `:1` (linear transfer). A `:w` capability is ambient authority — the very thing capability security exists to prevent. The warning is specific to capability types; `:w` on trait constraints (e.g., `{Eq A}`) is normal and triggers no warning. |

### The `:w` Tension: Capabilities vs. Traits

There is a deliberate asymmetry between capabilities and traits regarding `:w`:

- **Trait constraints at `:w` are normal.** `{Eq A}` is unrestricted — the fact that integers are equal is mathematical truth, not a scarce resource. Traits are ambient knowledge.
- **Capability constraints at `:w` should warn.** `{fs :w FsCap}` means "unrestricted filesystem authority" — this is ambient authority, which is precisely what POLA forbids.

The compiler distinguishes these by recognizing capability types as a distinct kind. When a type is declared as a capability (via `trait` with a capability marker, or by convention/annotation — an open design question), the compiler enforces:

- `:0` (erased proof) — **default for capability constraints in specs**. Zero runtime cost.
- `:1` (linear transfer) — when explicit delegation/consumption is needed.
- `:w` — triggers a **compiler warning**: "Unrestricted capability `:w` on `FsCap` — consider `:0` (authority proof) or `:1` (authority transfer)."

This preserves the ergonomics of the trait system (`:w` is normal for `Eq`, `Ord`, `Add`) while enforcing discipline on capability types. The mechanism for marking a trait as a capability type is a design question for the Capabilities as Types design doc.

<a id="checking-vs-transfer"></a>

## Authority Checking vs. Authority Transfer

Most capability usage is **authority checking** — proving you have the right to perform an operation, without consuming the capability. This should be `:0` (erased):

```prologos
;; read-file requires proof of ReadCap — but doesn't consume it.
;; You can call read-file many times with the same capability.
spec read-file {fs :0 ReadCap} : Path -> Result String IOError
```

The `{fs :0 ReadCap}` annotation says: "at compile time, verify that a `ReadCap` is available in scope." At runtime, this parameter doesn't exist — it's erased. This is the common case: invoking a capability doesn't destroy it, just as invoking a system call through an seL4 capability slot doesn't revoke the slot.

**Authority transfer** is when you hand a capability to someone else — and in doing so, give up your own access. This is `:1`:

```prologos
;; delegate-read gives away your read capability — you no longer have it.
spec delegate-read : ReadCap :1 -> ChildProcess -> Unit
```

This is seL4's capability transfer, or E's eventual-send of a capability. The linear type ensures the delegation is tracked: after calling `delegate-read`, the caller's `ReadCap` is consumed. Any subsequent attempt to use it is a type error.

<a id="attenuation"></a>

## Capability Attenuation

Attenuation — creating a weaker capability from a stronger one — is a linear operation:

```prologos
;; Attenuate: give up full filesystem access, receive read-only
spec attenuate-read : FsCap :1 -> ReadCap :1

;; The original FsCap is consumed. You cannot keep both.
;; This is irreversible capability narrowing.
```

This is a fundamental pattern: a parent process with broad capabilities can create child processes with narrowed capabilities, enforcing least privilege at every delegation boundary.

For the common case where you want to *use* your broader capability while *granting* a narrower one, the broader capability supports a splitting operation:

```prologos
;; Split: keep your FsCap, mint a read-only sub-capability
spec grant-read : FsCap :1 -> <FsCap :1 * ReadCap :1>
```

This is safe because `FsCap` subsumes `ReadCap` — the total authority hasn't increased. The linear types ensure both halves are tracked.

---

<a id="implicit-capabilities"></a>

# Capabilities as Implicit Parameters

<a id="ergonomic-requirement"></a>

## The Ergonomic Requirement

QTT achieves enormous lifting with three symbols because it's **metadata on things you're already writing**. You annotate binders you already have; the cognitive cost is marginal.

Capabilities must follow the same principle. The programmer should not have to:

- Manually thread capability tokens through every function call
- Write `ReadCap ->` in every I/O function's argument list
- Think about capabilities at all when writing pure code

The programmer *should* be able to:

- Read a function's capability requirements from its type signature (when they choose to look)
- Have the compiler infer capability requirements from the function body
- Get clear error messages when a capability is missing

This is the same bargain as trait constraints: `{Eq A}` exists in the spec, the compiler resolves it, and most users never think about it.

<a id="ambient-vs-scoped"></a>

## Traits Are Ambient; Capabilities Are Not

There is a fundamental tension between trait resolution and capability resolution:

- **Traits are ambient.** `impl Eq Int` is globally available. Any code anywhere can use `Eq Int` without being explicitly granted it. This is correct for traits — the equality of integers is a mathematical fact, not a privilege.

- **Capabilities are non-ambient.** `ReadCap` is *not* globally available. Code can only use `ReadCap` if it was explicitly granted by a caller. This is the entire point of POLA.

Therefore, capabilities cannot use the global trait instance registry. They need a different resolution mechanism.

<a id="lexical-resolution"></a>

## Lexically-Scoped Implicit Resolution

Capabilities resolve from the **lexical scope** — specifically, from the function's parameter list and module-level grants:

```prologos
;; main is the authority root — the system grants capabilities here
defn main {fs : FsCap} {net : NetCap}
  [process-data (path "/data") (path "/api")]

;; process-data inherits capabilities through the call chain
;; The compiler infers {fs : ReadCap} {net : HttpCap} from the body
defn process-data [data-path api-path]
  let csv-data = [read-file data-path]            ;; requires ReadCap
  let api-data = [http-get api-path "/endpoint"]   ;; requires HttpCap
  [build-report csv-data api-data]

;; build-report is pure — no capabilities inferred
defn build-report [csv-data api-data]
  ...
```

The resolution chain:

1. `read-file` requires `{ReadCap}` (declared in its spec)
2. `process-data` calls `read-file`, so the compiler infers `process-data` requires `{ReadCap}`
3. `main` calls `process-data`, and `main` has `{FsCap}` which subsumes `{ReadCap}`
4. The compiler resolves `ReadCap` from `FsCap` via subtyping

The programmer writes `defn process-data [data-path api-path]` — no capability parameters. The compiler infers and checks them.

**Open design question**: The exact mechanism for lexical capability resolution needs a dedicated design cycle. Options include: (a) a separate "capability environment" tracked alongside the type environment, (b) extension of the implicit argument resolver to handle lexically-scoped (not globally-registered) parameters, or (c) a new form of constraint that propagates through the call graph.

<a id="capability-closure"></a>

## The Capability Closure

The compiler computes the **capability closure** of every function — the full set of capabilities transitively required by its body. This closure is:

- **Inferred** — the programmer doesn't write it (unless they want to be explicit)
- **Visible on demand** — an IDE or REPL command can display it
- **Auditable** — a security review reduces to inspecting capability closures

```prologos
;; The compiler computes:
;;   main         requires {FsCap, NetCap}
;;   process-data requires {ReadCap, HttpCap}
;;   build-report requires {}  (pure)
;;   read-file    requires {ReadCap}
;;   http-get     requires {HttpCap}
```

This is the "compiler as capability auditor" — the type checker does the security analysis.

---

<a id="composition"></a>

# Capability Composition

<a id="fine-grained"></a>

## Fine-Grained Capabilities

Capabilities are fine-grained traits:

```prologos
trait ReadCap       ;; can read from the filesystem
trait WriteCap      ;; can write to the filesystem
trait HttpCap       ;; can make HTTP requests
trait DbCap         ;; can connect to databases
trait SpawnCap      ;; can spawn child processes
trait ClockCap      ;; can read the system clock
```

Each trait is zero-method — it's a *proof of authority*, not an interface. (Though capabilities *could* carry methods if the design calls for it — e.g., `ReadCap` could carry the `read-bytes` function itself, making the capability and the operation inseparable.)

<a id="composite-union"></a>

## Union Types as Composite Capabilities

Composite capabilities are expressed through **union types**, not bundles. This is a fundamental distinction rooted in the logical character of each mechanism:

- **Bundles are contraction** — they narrow the possibility space. `bundle Numeric = Add + Sub + Mul + Neg + Abs + FromInt` means a type must satisfy *all* of these constraints simultaneously. Bundles are conjunctive (AND).

- **Composite capabilities are weakening** — they relax constraints. A capability that grants filesystem access is *more* permissive than one that grants only read access. Composite capabilities widen the authority space; they are a set union of individual authorities.

Union types are the correct expression:

```prologos
;; A composite capability is a union of individual capabilities
;; FsCap grants either ReadCap or WriteCap authority
type FsCap    = ReadCap | WriteCap
type NetCap   = HttpCap | WsCap
type SysCap   = FsCap | NetCap | DbCap | SpawnCap | ClockCap
```

Having `FsCap` means having authority that *includes* both reading and writing — the union expands the set of permitted operations. This is the opposite direction from a bundle constraint, which narrows what a type must provide.

**Why bundles are wrong for capabilities**: A `bundle FsCap = ReadCap + WriteCap` would mean "require a type that satisfies both `ReadCap` AND `WriteCap`" — this is a demand (contraction), not a grant (weakening). A capability is something you *have*, not something you *must prove*. Union types correctly model "authority that encompasses any of these individual authorities."

<a id="attenuation-subtyping"></a>

## Attenuation as Subtyping

Union type subsumption gives natural attenuation:

- `ReadCap` is a subtype of `FsCap` — read authority is a subset of full filesystem authority
- `FsCap` is a subtype of `SysCap` — filesystem authority is a subset of full system authority

```prologos
subtype ReadCap FsCap      ;; ReadCap <: FsCap (read ⊂ read|write)
subtype WriteCap FsCap     ;; WriteCap <: FsCap (write ⊂ read|write)
subtype FsCap SysCap       ;; FsCap <: SysCap (fs ⊂ sys)
```

When a function requires `{ReadCap}` and the caller has `{fs : FsCap}`, the compiler resolves it through subtype subsumption — `ReadCap <: FsCap`, so the `FsCap` satisfies the `ReadCap` requirement. No explicit attenuation needed. This is the zero-cost common case.

Explicit attenuation (the `:1` transfer operations in §QTT) is only needed when you want to *permanently narrow* your own authority or *delegate* a restricted capability to another process.

---

<a id="authority-root"></a>

# The Entry Point as Authority Root

Every capability chain must start somewhere. In seL4, the initial thread receives capabilities from the kernel at boot. In Prologos:

```prologos
;; The system grants capabilities to main
;; This is the ONLY place where capabilities are minted from nothing
defn main {sys : SysCap}
  ...
```

`main` (or the REPL environment) is the authority root. It receives the full set of system capabilities. Every other function receives capabilities through the call chain — never from nothing.

This means:

- **Library code never has ambient authority.** A library function can only use capabilities it receives from its caller.
- **The authority boundary is visible.** The `main` function's capability parameter is the complete security policy for the program.
- **Testing is natural.** In tests, you pass mock capabilities (or no capabilities) to verify that code respects its authority boundaries.

---

<a id="dependent-capabilities"></a>

# Dependent Capabilities

Dependent types make capabilities path-sensitive — a capability can be scoped to a specific resource:

```prologos
;; A FileCap is indexed by the path it grants access to
data FileCap : Path -> Type

spec read-file : {p : Path} -> FileCap p :1 -> Result String IOError
```

A `FileCap (path "/tmp/data.csv")` grants access to exactly that file. It cannot be used to read `/etc/passwd`. The type system encodes the security policy at the value level.

This is seL4's model — capabilities name specific kernel objects — expressed in the type system. It is also the most demanding tier of capability granularity, and may be deferred to a later design phase. The non-dependent version (`{ReadCap}` without path indexing) provides substantial value on its own.

---

<a id="session-types"></a>

# Session Types and Capability Protocols

Session types govern the *protocols* of capability delegation:

```prologos
;; A session for requesting file access
session FileAccess
  !Request Path                            ;; client requests access to a path
  ?Grant (Result (FileCap p :1) DenyReason) ;; server grants or denies
  ...
```

This verifies at compile time that:

- The client requests before using
- The server responds to every request
- Capabilities are delegated according to the protocol
- The protocol terminates (no leaked capabilities)

The fusion of session types and capability types is where Prologos offers something no other language does: **compile-time verification of distributed authority delegation protocols.**

The detailed design of session type syntax and semantics is a separate effort (see note in [I/O Library Design](../2026-03-01_1200_IO_LIBRARY_DESIGN.md)). This principles document establishes that session types are the protocol layer for capability delegation.

---

<a id="design-principles"></a>

# Design Principles for Capabilities in Prologos

1. **Least Authority by Default.** Functions have no authority except what their type signatures declare. Pure functions have no capability parameters — their purity is visible in the type. Every capability requirement is explicit in the spec and inferrable from the body.

2. **Low Friction, High Assurance.** The ergonomic cost of capability security should be comparable to QTT's cost — a few annotations that the compiler can mostly infer. Capabilities must not feel like a bureaucratic burden. If the security model makes simple programs painful, the design is wrong.

3. **Capabilities Are Types, Not Annotations.** Capabilities participate in the type system — they can be dependent, they can be linear, they compose through union types, they attenuate through subtyping. They are not a separate annotation language bolted onto the type system. Capabilities on types are constraints — like trait constraints, but with different scoping rules and multiplicity defaults.

4. **The Compiler Is the Auditor.** Capability closures are computed automatically. Security review is type-checking. The compiler can answer "what authority does this function/module/program require?" without whole-program analysis beyond what type inference already does.

5. **Authority Checking Is Free (`:0`).** The common case — verifying that a capability exists in scope — has zero runtime cost. Only authority transfer (`:1`) and unrestricted sharing (`:w`) have runtime representation. This mirrors QTT's erasure: proofs are free, values have cost.

6. **Progressive Disclosure.** A beginner writing `defn hello [] "hello world"` encounters no capabilities. A user performing file I/O sees `{ReadCap}` in the inferred type if they ask. A security-conscious developer writes explicit capability parameters and uses dependent capabilities for path-level scoping. Each tier is opt-in.

7. **Composition Through Existing Mechanisms.** Capabilities use traits (for declaration), union types (for composite authority), subtyping (for attenuation), and implicit parameters (for ergonomic passing). No new language mechanisms are required — only new applications of existing ones.

---

<a id="relationships"></a>

# Relationship to Other Principles

| Document | Relationship |
|----------|-------------|
| `LANGUAGE_VISION.md` | Capability security extends "Resource correctness" (§What Problem Does Prologos Solve?) from resources to authority. QTT (§Cutting-Edge Research) provides the enforcement mechanism. |
| `DESIGN_PRINCIPLES.md` | "Correctness Through Types" subsumes capability verification. "Progressive Disclosure" governs the ergonomic layering. "Decomplection" motivates separating authority from identity. |
| `RELATIONAL_LANGUAGE_VISION.md` | External data sources (`defr :source`) require filesystem capabilities. Capability security governs which modules can access which external data. |
| `ERGONOMICS.md` | The "Low Friction, High Assurance" principle is an ergonomics constraint. Capability notation must pass the same usability bar as QTT multiplicities. |
| I/O Library Design | The I/O library is an *application* of the capability system, not a design in its own right. I/O functions require capability parameters; the library design follows from the capability model. |

---

<a id="inspirations"></a>

# Inspirations

- **Mark Miller** — E language, object-capability model, Principle of Least Authority, `eventual-send` for distributed capabilities. ECMAScript Realms and Compartments proposals. The foundational thinker in capability security.
- **seL4** — formal verification of a capability-based microkernel. Capabilities as the *only* way to name kernel objects. Deployed as SecureOS in Apple's Secure Enclave. The gold standard for capability enforcement.
- **Dennis and Van Horn (1966)** — "Programming Semantics for Multiprogrammed Computations." The original capability concept.
- **KeyKOS / EROS / CapROS** — capability operating systems demonstrating that fine-grained capabilities are practical for system-level software.
- **Pony** — reference capabilities (iso, val, ref, box, trn, tag) for data-race freedom. Demonstrates that capability annotations on types can be lightweight — though Pony's six capabilities are more complex than our three QTT multiplicities.
- **Wasm Interface Types / WASI** — capability-based system interface for WebAssembly. Demonstrates capability security for portable code.
- **Idris 2** — QTT as the enforcement mechanism for linear protocols. The closest existing language to Prologos's type system.
