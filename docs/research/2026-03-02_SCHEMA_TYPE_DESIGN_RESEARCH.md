# Schema Type Design Research

**Date**: 2026-03-02
**Phase**: Deep Research (Phase 1 of Design Methodology)
**Topic**: Schema validation semantics — required/optional keys, open/closed maps, validation metadata, and their expression in a dependently-typed language

## Table of Contents

1. [The Design Tension](#1-the-design-tension)
2. [Landscape Survey](#2-landscape-survey)
   - [2.1 Clojure.spec](#21-clojurespec)
   - [2.2 Hickey's "Maybe Not" and spec2/select](#22-hickeys-maybe-not-and-spec2select)
   - [2.3 Malli](#23-malli)
   - [2.4 Plumatic Schema](#24-plumatic-schema)
   - [2.5 Specter](#25-specter)
   - [2.6 JSON Schema](#26-json-schema)
   - [2.7 Protocol Buffers](#27-protocol-buffers)
   - [2.8 Elixir Ecto Changesets](#28-elixir-ecto-changesets)
   - [2.9 Zod (TypeScript)](#29-zod-typescript)
   - [2.10 Dependent Type Systems (Lean 4, Agda, Idris)](#210-dependent-type-systems-lean-4-agda-idris)
3. [Essential vs. Accidental Complexity](#3-essential-vs-accidental-complexity)
4. [The Central Insight: Three Orthogonal Concerns](#4-the-central-insight-three-orthogonal-concerns)
5. [Current Prologos State](#5-current-prologos-state)
6. [Design Space for Prologos](#6-design-space-for-prologos)
   - [6.1 Approach A: Rich Schema with Inline Metadata](#61-approach-a-rich-schema-with-inline-metadata)
   - [6.2 Approach B: Schema + Select (Hickey Separation)](#62-approach-b-schema--select-hickey-separation)
   - [6.3 Approach C: Schema with Refinement Types](#63-approach-c-schema-with-refinement-types)
   - [6.4 Approach D: Layered Schema with Key Properties](#64-approach-d-layered-schema-with-key-properties)
7. [Principle Alignment Analysis](#7-principle-alignment-analysis)
8. [Recommendation](#8-recommendation)
9. [Open Questions](#9-open-questions)
10. [Bibliography](#10-bibliography)

---

## 1. The Design Tension

Prologos has open maps (`{}`) — any keys, any values, unconstrained. The `schema` form is meant to *close* them: a named map type with fixed keys and typed values. The current implementation is a stub:

```racket
;; macros.rkt — current expansion
(define expanded `(deftype ,schema-name (Map Keyword Value)))
```

This raises several design tensions:

1. **Required vs. Optional keys**: Should all declared keys be required? Should some be optional? How do we express this?
2. **Open vs. Closed**: Should a schema reject maps with *extra* keys beyond those declared? Or should it allow extension (extra keys are fine, declared keys are validated)?
3. **Context-dependent requirements**: Different consumers of the same data may need different subsets of keys. Where does this contextual requirement live?
4. **Metadata namespace collision**: If validation metadata (`:optional`, `:default`, `:validate`) lives alongside data keys in the schema, we have a confusion of concerns between "what the data looks like" and "what the schema says about the data."

These are not unique to Prologos — every schema system in the landscape has confronted them.

---

## 2. Landscape Survey

### 2.1 Clojure.spec

**Source**: [clojure.org/about/spec](https://clojure.org/about/spec), [spec Guide](https://clojure.org/guides/spec)

Clojure.spec treats specifications as *predicates over data*. Key design decisions:

**Namespaced keyword identity**: Each attribute (`::name`, `::age`) has a globally-unique identity via namespace qualification. The *spec of an attribute* is registered once, globally:

```clojure
(s/def ::name string?)
(s/def ::age pos-int?)
```

**s/keys for map specs**: `s/keys` declares which keys a map should contain:

```clojure
(s/def ::person (s/keys :req [::name ::age] :opt [::email]))
```

- `:req` — required keys (must be present)
- `:opt` — optional keys (documented, used by generators)
- `:req-un` / `:opt-un` — unqualified key variants

**Open maps by default**: This is a fundamental philosophical commitment. `s/keys` *never* rejects extra keys. A map with `{::name "Ada" ::age 36 ::favorite-color "blue"}` passes the `::person` spec even though `::favorite-color` isn't declared. As the spec rationale states: "Map checking is two-phase, required key presence then key/value conformance... vital for composition and dynamicity."

**Two-phase checking**: (1) Are required keys present? (2) For any key that *has* a registered spec, does the value conform? Phase 2 applies to *all* namespace-qualified keys, even ones not in the `s/keys` declaration.

**Conforming and destructuring**: `s/conform` validates and simultaneously extracts structural information — labeling which branch of an `s/or` matched, extracting positional elements of an `s/cat`. This is more than validation; it's *parsing*.

**Generative testing**: Every spec doubles as a generator via `test.check`. `s/fdef` specifies function argument shapes, return shapes, and the relationship between them — generators produce test cases automatically.

**Criticisms**:
- Global mutable registry (not data-driven)
- Macros make specs opaque to tooling
- Error messages are notoriously opaque
- Performance overhead for runtime validation
- Required/optional conflated with schema shape (addressed in "Maybe Not")

### 2.2 Hickey's "Maybe Not" and spec2/select

**Sources**: [Maybe Not talk transcript](https://github.com/matthiasn/talk-transcripts/blob/master/Hickey_Rich/MaybeNot.md), [DEV Community summary](https://dev.to/cjthedev/clojure-conj-2018---maybe-not----rich-hickey-1196), [spec-alpha2 Schema and select wiki](https://github.com/clojure/spec-alpha2/wiki/Schema-and-select)

This is the most important theoretical contribution in the landscape for our design. Hickey's 2018 "Maybe Not" talk identifies a **fundamental complection** in `s/keys`: it braids together *what keys a thing can have* (shape) with *what keys a context requires* (optionality).

**The core argument**: Optionality is not intrinsic to an attribute — it is *context-dependent*. A `:name` is not "maybe a string." It is a string. Whether you *need* it depends on *where you are*:

> "When something is missing from a set, leave it out! When something can be missing from a slot, make a billion dollar mistake?"

**Against Maybe/Option for map keys**: Hickey argues that `Maybe String` for a map field is categorically wrong. The string-ness of `:name` is fixed. Whether you require `:name` in *this* function call is contextual. Using `Maybe` conflates type information with presence information.

**The three-layer proposal**:

| Layer | Name | Purpose |
|-------|------|---------|
| 1 | **Attribute** | What a key *means* — `::name` is always `string?` |
| 2 | **Schema** | What keys *can* travel together — `::user` has `::id`, `::name`, `::addr` |
| 3 | **Select** | What keys *must* be present in this context |

**spec2's `s/schema`**: Declares the universe of possible keys without any required/optional distinction:

```clojure
(s/def ::user (s/schema [::id ::first ::last ::addr]))
(s/def ::addr (s/schema [::street ::city ::state ::zip]))
```

Schemas define *shape* only. All keys are *possible*; none are required.

**spec2's `s/select`**: Declares context-specific requirements drawn from a schema:

```clojure
;; For movie-times: need id and zip
(s/def ::movie-times-user
  (s/select ::user [::id ::addr {::addr [::zip]}]))

;; For order placement: need everything
(s/def ::place-order-user
  (s/select ::user [::first ::last ::addr {::addr [::street ::city ::state ::zip]}]))
```

**Deep nested requirements**: Select patterns can specify requirements at any depth:

```clojure
(s/select ::user [::id ::addr {::addr [::zip]}])
;; "User must have ::id and ::addr; within ::addr, must have ::zip"
```

**The key insight for Prologos**: Schema defines what is *possible*. Selection defines what is *required*. These are orthogonal concerns and should be expressed with orthogonal syntax.

### 2.3 Malli

**Sources**: [metosin/malli GitHub](https://github.com/metosin/malli), [Malli blog post](https://www.metosin.fi/blog/malli), [Open/Closed decision](https://github.com/metosin/malli/issues/31), [Malli data modelling](https://www.metosin.fi/blog/2024-01-16-malli-data-modelling-for-clojure-developers)

Malli is the data-driven response to spec's macro-heavy approach. Created by Metosin (the company behind many of Clojure's most popular web libraries), it addresses spec's limitations directly.

**Schemas as data**: Unlike spec's macro-based approach, Malli schemas are plain Clojure data structures that can be serialized, inspected, and composed:

```clojure
;; Malli schema — it's just data (vectors and keywords)
[:map
 [:name string?]
 [:age pos-int?]
 [:email {:optional true} string?]]
```

**Required by default, optionally optional**: Keys are required unless marked `{:optional true}`. This is the inverse of spec2's "nothing required by default."

**Open maps by default, closeable**: Following spec's philosophy (after [deliberation](https://github.com/metosin/malli/issues/31)), maps allow extra keys by default. Close with `{:closed true}`:

```clojure
;; Open (default) — extra keys OK
[:map [:name string?] [:age int?]]

;; Closed — extra keys rejected
[:map {:closed true} [:name string?] [:age int?]]
```

**Schema composition**:
- `:merge` — merge multiple map schemas (last wins for conflicts)
- `:union` — union of map schemas (first wins)
- `:multi` — dispatch-based multi-schemas
- `:and` / `:or` — logical composition

```clojure
;; Merge: Person + Employee
[:merge
 [:map [:name string?] [:age int?]]
 [:map [:dept string?] [:salary int?]]]
```

**Properties as metadata**: Schemas carry properties (metadata) that don't affect validation but provide documentation, JSON Schema titles, etc.:

```clojure
[:map {:title "Employee" :description "Company employee record"}
 [:name {:description "Full name"} string?]
 [:age {:json-schema/example 42} int?]]
```

**Transformation**: Malli provides encode/decode pipelines — coerce string `"42"` to int `42`, strip extra keys, provide defaults. This goes beyond validation into data transformation.

**Performance**: Malli compiles validators for high performance — benchmarks show 18x faster schema creation and 180x faster evaluation than spec in some cases.

**Key lesson for Prologos**: The property metadata approach is clean — properties live in a separate namespace from the keys themselves, so there's no collision. The `{:optional true}` property on a key entry is metadata *about the key*, not a data key itself.

### 2.4 Plumatic Schema

**Source**: [plumatic/schema GitHub](https://github.com/plumatic/schema)

The pre-spec schema library. Schemas are plain Clojure data values (not registered in a global registry):

```clojure
{:name s/Str
 :age s/Int
 (s/optional-key :email) s/Str}
```

**Required by default**: Keys in a map schema literal are required. Use `s/optional-key` wrapper for optionals. Simple and intuitive, but verbose for many optional keys.

**Schemas as values**: Unlike spec's global registry, Plumatic schemas are first-class values that can be passed around, composed with standard Clojure operations (merge, assoc), and inspected at runtime. This data-driven approach influenced Malli's design.

**Largely superseded** by spec and Malli, but its core insight — schemas as ordinary data — remains influential.

### 2.5 Specter

**Source**: [nathanmarz/specter GitHub](https://github.com/nathanmarz/specter)

Specter is **not** a validation library — it solves a different problem: *navigating and transforming nested data structures*. Included here because:

1. It addresses the "reaching into nested data" problem that complex schemas must also address
2. Its navigator composition model is relevant to how schemas might compose over nested structures
3. It demonstrates that data access (Specter) and data shape (spec/Malli) are orthogonal concerns

Key concepts: navigators compose to form paths; `select` retrieves; `transform` modifies in-place. Compiled paths achieve performance competitive with hand-written code.

**Lesson for Prologos**: Prologos already has dot-access (`user.name`) and map-get for data navigation. Schema validation and data navigation are separate concerns — good. But nested schema validation needs a way to express "validate this nested structure," which is what spec2's `select` pattern and Malli's nested `:map` achieve.

### 2.6 JSON Schema

**Source**: [JSON Schema reference](https://json-schema.org/understanding-json-schema/reference/object)

JSON Schema is the industry standard for describing JSON document structure. Directly relevant as a "closed-world" schema system.

**Open by default**: `additionalProperties` defaults to `true`. Extra properties are allowed.

**Closing schemas**: `"additionalProperties": false` rejects any property not in `properties`.

**Required as separate concern**: `required` is an array of property names, separate from `properties`:

```json
{
  "type": "object",
  "properties": {
    "name": { "type": "string" },
    "age": { "type": "integer" },
    "email": { "type": "string" }
  },
  "required": ["name", "age"]
}
```

This separation is significant: the *shape* of each property is defined in `properties`; the *requirement* is expressed separately in `required`. This is structurally similar to Hickey's schema/select separation.

**Composition problems**: `allOf` + `additionalProperties: false` is notoriously broken. `additionalProperties` only sees properties declared in the *same* subschema, so composing two closed schemas fails:

```json
{
  "allOf": [
    { "properties": { "name": {} }, "additionalProperties": false },
    { "properties": { "age": {} }, "additionalProperties": false }
  ]
}
// BROKEN: each subschema rejects the other's properties
```

The `unevaluatedProperties` keyword (newer drafts) fixes this by recognizing properties from composed subschemas.

**Key lesson for Prologos**: Separating `required` from `properties` is the right idea, but the composition story must be sound from the start. Don't repeat JSON Schema's `allOf` + `additionalProperties` mistake.

### 2.7 Protocol Buffers

**Source**: [Protocol Buffers docs](https://protobuf.dev/programming-guides/proto3/), [schema evolution guide](https://jsontotable.org/blog/protobuf/protobuf-schema-evolution)

Proto3 made a radical design choice: **remove `required` entirely**. All fields are optional by default. Why?

- `required` fields can never be safely removed from a schema (backwards incompatibility)
- They create brittle APIs where adding a requirement breaks all existing clients
- Schema evolution (adding/removing fields over time) is incompatible with hard requirements

Proto3's philosophy: *growth over breakage*. This directly echoes Hickey's "Spec-ulation" talk: the only safe change is accretion (adding new things). Removing or requiring is breaking.

**Relevance to Prologos**: For schema evolution in protocols (session types!), proto3's lesson is vital. A `session` that sends an `OrderRequest` schema over the wire must be able to evolve that schema without breaking the dual endpoint. This argues for open schemas at protocol boundaries and closed schemas at validation boundaries — two different use cases.

### 2.8 Elixir Ecto Changesets

**Source**: [Ecto.Changeset docs](https://hexdocs.pm/ecto/Ecto.Changeset.html), [Data mapping and validation](https://hexdocs.pm/ecto/data-mapping-and-validation.html)

Ecto's changeset pattern is a beautiful example of separating shape from validation context:

```elixir
# Schema: defines shape
defmodule User do
  use Ecto.Schema
  schema "users" do
    field :name, :string
    field :age, :integer
    field :email, :string
  end
end

# Changeset: defines validation context
def registration_changeset(user, attrs) do
  user
  |> cast(attrs, [:name, :age, :email])       # which fields to accept
  |> validate_required([:name, :email])         # which must be present
  |> validate_format(:email, ~r/@/)             # value constraints
end

def profile_update_changeset(user, attrs) do
  user
  |> cast(attrs, [:name, :age])                # different field set!
  |> validate_required([:name])                 # different requirements!
end
```

**Key insight**: The *schema* is defined once. *Changesets* define validation contexts — different functions can impose different requirements on the same schema. This is exactly Hickey's schema/select separation, realized in a different language.

**Direct applicability to Prologos**: The changeset pattern maps naturally to Prologos's trait/function system. A schema defines shape; different functions declare their requirements via type signatures or validation forms.

### 2.9 Zod (TypeScript)

**Source**: [Zod documentation](https://zod.dev/), [Designing the perfect TypeScript schema validation library](https://colinhacks.com/essays/zod)

Zod bridges compile-time types and runtime validation in TypeScript:

```typescript
const User = z.object({
  name: z.string(),
  age: z.number(),
  email: z.string().optional(),  // explicitly optional
});

type User = z.infer<typeof User>;
// { name: string; age: number; email?: string }
```

**Required by default**: All fields required unless `.optional()`.

**Three modes for extra keys**:
- `.strip()` — silently remove unknown keys (default)
- `.strict()` — reject unknown keys (error)
- `.passthrough()` — allow unknown keys through

**Rich composition**: `.extend()`, `.merge()`, `.pick()`, `.omit()`, `.partial()`, `.required()`, `.deepPartial()` — a full algebra of schema transformations.

**Discriminated unions**: `z.discriminatedUnion("type", [...])` — dispatch on a discriminant field. Similar to Malli's `:multi`.

**Static type inference**: The killer feature — `z.infer<typeof schema>` extracts a TypeScript type from a runtime schema. Prologos can do better: our schemas ARE types.

**Key lesson for Prologos**: The `.partial()` / `.required()` operations are interesting — they transform a schema's optionality in bulk. And the three-mode approach (strip/strict/passthrough) for extra keys is a clean taxonomy.

### 2.10 Dependent Type Systems (Lean 4, Agda, Idris)

**Sources**: [Lean 4 Structures and Records](https://lean-lang.org/theorem_proving_in_lean4/structures_and_records.html), [Functional Programming in Lean — Structures and Inheritance](https://leanprover.github.io/functional_programming_in_lean/functor-applicative-monad/inheritance.html)

In dependent type systems, "schema validation" can be expressed *within the type system itself*:

**Lean 4 structures**:
```lean
structure Employee where
  name : String
  dept : Department
  salary : Nat
  deriving Repr
```

- All fields required (by construction — a value of type `Employee` must provide all fields)
- Extension via `extends`: `structure Manager extends Employee where level : Nat`
- Dependent fields: field types can depend on earlier fields
- No optional fields in the type-level schema — optionality requires `Option` wrapper

**Agda/Idris records**: Similar — records are syntactic sugar for dependent pairs (Sigma types). A record with n fields is a nested Sigma: `Σ (name : String) (Σ (age : Nat) ...)`.

**Refinement types**: Dependent types can express arbitrary validation predicates:
```
-- A sorted list is a list with a proof of sortedness
SortedList : Type → Type
SortedList A = Σ (xs : List A) (IsSorted xs)
```

**Key insight for Prologos**: We have dependent types, which means we can express "a map where key `:name` has type `String`" as a genuine type, not just a runtime predicate. But we should NOT force every schema into Sigma-type encoding — that's too much ceremony for the common case. The surface `schema` keyword should hide the Pi/Sigma encoding, just as `spec` hides Pi types.

---

## 3. Essential vs. Accidental Complexity

Following our Design Methodology (Phase 1: "Identify the essential vs. accidental"), the survey reveals three **essential** concerns that every system addresses:

| # | Essential Concern | What it answers |
|---|---|---|
| 1 | **Key-value shape** | What keys can exist? What type does each key's value have? |
| 2 | **Presence requirements** | Which keys must be present? Is this intrinsic or contextual? |
| 3 | **Openness** | Can the map contain keys beyond those declared? |

And several **accidental** complexities that arise from conflating these concerns:

| Accidental Complexity | Caused by |
|---|---|
| Schema proliferation ("UserForRegistration", "UserForUpdate") | Conflating shape and requirements |
| Maybe/Option wrapping of every optional field | Conflating type with presence |
| `allOf` + `additionalProperties` broken composition | Conflating openness with local declaration |
| Global registry coupling | Not separating identity from definition |

---

## 4. The Central Insight: Three Orthogonal Concerns

Across the entire landscape, the most theoretically clean systems converge on **three orthogonal layers**:

```
┌─────────────────────────────────────────────────┐
│  Layer 1: ATTRIBUTES (key semantics)            │
│  What does :name mean? → String                 │
│  What does :age mean?  → Int                    │
│  Independent of any particular map or context   │
├─────────────────────────────────────────────────┤
│  Layer 2: SCHEMA (shape / structure)            │
│  What keys can Employee have?                   │
│  → :name, :dept, :salary                        │
│  No required/optional — just "travels together" │
├─────────────────────────────────────────────────┤
│  Layer 3: SELECTION / CONTEXT (requirements)    │
│  For this function, what do I need?             │
│  → :name required, :dept required, :salary opt  │
│  Context-dependent, varies per consumer         │
└─────────────────────────────────────────────────┘
```

This layering appears in:
- **spec2**: attributes → schema → select
- **Ecto**: schema → changeset (cast + validate_required)
- **JSON Schema**: properties → required (separate array)
- **Proto3**: message fields → (no required — context decides)

The systems that conflate layers (spec1's `s/keys`, Plumatic Schema's map literals, Zod's default-required objects) are simpler for small cases but create pain at scale.

---

## 5. Current Prologos State

**Implementation**: `schema` in `macros.rkt` expands to `(deftype Name (Map Keyword Value))` — a type alias with zero validation semantics. The field pairs in `(schema Employee :name String :dept Department :salary Int)` are parsed but discarded.

**AST**: `expr-schema` and `expr-schema-type` exist in `syntax.rkt`. The typing rule in `typing-core.rkt` is minimal:

```racket
[(expr-schema nm fs) (for-each (lambda (f) (infer ctx f)) fs) (expr-schema-type nm)]
```

**Vision documents**: The RELATIONAL_LANGUAGE_VISION describes `schema` as "named, closed, validated map" with:
- A type (`Employee : Type 0`)
- A constructor (both positional and dictionary-style)
- A validator (type checker rejects ill-formed values)
- Field accessors (dot-syntax)
- Schema composition (`:extends`)
- Schema-annotated relations (`defr employee : Employee`)

**Grammar**: `schema-def = '(' , 'schema' , identifier , { ':' , identifier , type-expr } , ')' ;`

The gap between vision and implementation is substantial. This research aims to close that gap with a well-designed approach.

---

## 6. Design Space for Prologos

### 6.1 Approach A: Rich Schema with Inline Metadata

Everything lives in the schema declaration via key-level metadata properties:

```prologos
schema Employee
  :name       String
  :dept       Department
  :salary     Int
  :email      String        :optional
  :start-date String        :optional  :default "2026-01-01"
  :badge-id   Int           :validate [> _ 0]
```

**Pros**: Single declaration site. Familiar (Malli-like). Readable.
**Cons**: Conflates shape with requirements (the Hickey critique). `:optional` is not intrinsic to `:email` — it depends on context. `:validate` is a runtime concern mixed with a type-level declaration. Metadata keywords (`:optional`, `:default`, `:validate`) collide with the key namespace.

### 6.2 Approach B: Schema + Select (Hickey Separation)

Schema defines shape only. Separate form defines contextual requirements:

```prologos
schema Employee
  :name       String
  :dept       Department
  :salary     Int
  :email      String
  :start-date String
  :badge-id   Int

;; Different contexts select different requirements
select RegistrationEmployee := Employee
  :require [:name :dept :salary]

select UpdateEmployee := Employee
  :require [:name]
  :optional [:dept :salary :email]
```

**Pros**: Clean separation. Maximum schema reuse. Different consumers declare their own requirements. Follows Hickey's insight. No metadata collision.
**Cons**: Two forms to learn. More verbose for the simple case. The `select` form needs its own type semantics.

### 6.3 Approach C: Schema with Refinement Types

Leverage Prologos's dependent types. A schema is a record type; requirements are expressed as type-level predicates:

```prologos
schema Employee
  :name       String
  :dept       Department
  :salary     Int
  :email      String?         ;; nilable = optional

;; At the type level, a "complete employee" is a refined schema
spec hire-employee : (e : Employee) -> {pf : [has-keys e #{:name :dept :salary}]} -> EmployeeId
```

**Pros**: Uses the existing type system. No new forms needed. Maximum expressiveness (any predicate).
**Cons**: Too much ceremony for the common case. Violates progressive disclosure — requiring dependent-type annotations for basic "these keys are required" semantics. The `has-keys` predicate must be built and supported.

### 6.4 Approach D: Layered Schema with Key Properties (Recommended)

A hybrid that achieves the Hickey separation while staying ergonomic. Schema declares shape with *optional key properties* (metadata about keys, not data keys themselves). A separate mechanism handles context-dependent requirements.

```prologos
;; Layer 1: Schema defines shape — what keys CAN exist, their types
schema Employee
  :name       String
  :dept       Department
  :salary     Int
  :email      String
  :start-date String
  :badge-id   Int

;; Layer 2: Require — context-dependent key requirements
;; (sugar over dependent types: produces a refinement type)
require FullEmployee := Employee [:name :dept :salary :badge-id]
require UpdatePayload := Employee [:name]

;; Usage: function specs declare which "require" they need
spec hire-employee : FullEmployee -> EmployeeId
spec update-employee : UpdatePayload -> Result

;; Layer 3: Openness is a schema-level property
schema StrictEmployee :closed
  :name   String
  :dept   Department
  :salary Int
;; Extra keys in a StrictEmployee are a type error
```

**Key properties** (metadata on individual keys) live in the schema declaration but are distinguished from data keys by their position — they're properties of the *entry*, not additional entries:

```prologos
schema Employee
  :name       String                       ;; required by default in the shape
  :email      String        :default ""    ;; has a default value
  :badge-id   Int           :check [> _ 0] ;; value constraint
```

Here `:default` and `:check` are key properties (metadata about the `:email` and `:badge-id` entries), not additional map keys. This is unambiguous because they follow the type position — the grammar is `key-name Type [key-prop*]`.

**How this avoids the collision**: The schema grammar alternates `keyword Type`, so properties that follow a Type are unambiguously metadata about the preceding key-type pair, not additional map entries.

---

## 7. Principle Alignment Analysis

Checking Approach D against our Design Principles:

| Principle | Alignment |
|---|---|
| **Correctness Through Types** | ✅ Schema produces a genuine type. `require` produces a refinement type. Type checker validates. |
| **Simplicity of Foundation** | ✅ Schema is a single form. Require is optional sugar. No new AST categories needed beyond what exists. |
| **Progressive Disclosure** | ✅ Level 0: `schema Foo :x Int` (all required, closed). Level 1: add `:default`, `:check`. Level 2: add `require` for context-dependent subsets. Level 3: use dependent types directly. |
| **Pragmatism with Rigor** | ✅ Surface is `schema` + `require`; implementation is Sigma types + refinement predicates. |
| **Decomplection** | ✅ Shape (schema) decoupled from requirements (require) decoupled from openness (:closed property). Three orthogonal concerns, three orthogonal controls. |
| **Homoiconicity** | ✅ Both `schema` and `require` desugar to standard AST forms. |
| **The Specification Triple** | ✅ `spec`/`defn`, `schema`/`defr`, `session`/`defproc` remains clean. |
| **No Trait Hierarchies** | ✅ Schema composition uses `:extends` (flat merge), not inheritance. |
| **Open Extension, Closed Verification** | ✅ Schemas are open by default (can add keys). `:closed` opts into strictness. |

---

## 8. Recommendation

**Approach D (Layered Schema with Key Properties)** is the recommended path for Prologos, for these reasons:

1. **It honors the Hickey insight** (separate shape from requirements) without requiring two forms for the simple case. A bare `schema` with no `require` means "all keys required" — the 80% case.

2. **It avoids metadata collision** by using positional grammar: `key Type [metadata*]`. The parser already handles this pattern (it's how `spec` metadata works).

3. **It composes with existing infrastructure**: `schema` produces a type; `require` produces a refinement type; both flow through the existing type-checking pipeline.

4. **It scales to session types**: A `session` that sends an `Employee` can send an open `Employee` (schema evolution safe). A function that *receives* an `Employee` can require a `FullEmployee` (closed, all-keys-present).

5. **It follows progressive disclosure**: Start with the simplest schema. Add key properties when you need defaults or value constraints. Add `require` when you need context-dependent subsets. Use dependent types directly when you need maximum expressiveness.

### Concrete Design Sketch

```prologos
;; 1. Basic schema — all keys required, open (extra keys OK)
schema Point
  :x Int
  :y Int

;; 2. Schema with key properties
schema Employee
  :name       String
  :dept       Department
  :salary     Int           :check [> _ 0]
  :email      String        :default ""
  :start-date String

;; 3. Closed schema — no extra keys allowed
schema Config :closed
  :host String
  :port Int
  :debug Bool

;; 4. Schema extension (flat merge, not inheritance)
schema Manager :extends Employee
  :reports [List Employee]
  :level   Int

;; 5. Context-dependent requirements
require NewHire := Employee [:name :dept :salary]
require ProfileUpdate := Employee [:name]

;; 6. Usage in specs
spec create-employee : NewHire -> EmployeeId
spec update-profile : EmployeeId -> ProfileUpdate -> Result

;; 7. Usage with relations
defr employee : Employee
  || "Alice" Engineering 95000 "alice@co.com" "2024-01-15"
     "Bob"   Marketing   72000 ""             "2024-03-01"

;; 8. Schema values work with dot-access
def alice : Employee
  :name "Alice"
  :dept Engineering
  :salary 95000

alice.name     ;; => "Alice"
alice.salary   ;; => 95000
```

### Default Semantics

| Property | Default | Override |
|---|---|---|
| Openness | Open (extra keys allowed) | `:closed` on schema |
| Key requirement | Required (must be present) | Via `require` subset or `:default` value |
| Key validation | Type only | `:check` predicate |
| Schema composition | Flat merge | `:extends` keyword |

### Type-Level Encoding

- `schema Employee ...` → named record type (elaborates to a Map type with field constraints)
- `require NewHire := Employee [...]` → refinement type (Sigma: `Σ (e : Employee) (HasKeys e #{...})`)
- `:closed` → the type rejects values with extra keys (strict map)
- `:check [> _ 0]` → refinement predicate on the value (Sigma on the field)
- `:default ""` → constructor uses default when key absent; type is unchanged
- `:extends` → merge parent fields into child (set union, child wins conflicts)

---

## 9. Open Questions

1. **Syntax for `require`**: Is `require` the right keyword? Alternatives: `select` (spec2), `view` (database terminology), `project` (relational algebra), `need` (plain English). Consider: `require` already used for module imports.

2. **Nested requirements**: How does `require` express deep requirements? Does it need spec2-style nested patterns like `{::addr [::zip]}`?

3. **Runtime vs. compile-time validation**: Should `:check` predicates be compile-time (proof obligations) or runtime (assertions)? Following the "Properties are Types in Waiting" principle, they should start as runtime and upgrade to compile-time as the proof infrastructure matures.

4. **Schema and QTT**: What multiplicity should schema fields have? Unrestricted (`:w`) by default? Should `:1` linear fields be expressible in schemas (for resource-typed fields)?

5. **Schema and session types**: When a schema flows over a session channel, does the receiving end validate against the schema type? How does schema evolution interact with session type duality?

6. **Default value timing**: Does `:default` apply at construction time (the constructor fills it in) or at access time (missing keys return the default)? Construction time is cleaner (the value always has the key).

7. **Keyword choice for closed**: `:closed` as a schema-level property, or a different mechanism? Consider: `schema Config :strict` (Zod terminology) or `schema Config :exact`.

---

## 10. Bibliography

### Primary Sources — Clojure Ecosystem

- Rich Hickey, "Maybe Not" (Clojure/conj 2018) — [DEV Community summary](https://dev.to/cjthedev/clojure-conj-2018---maybe-not----rich-hickey-1196), [transcript](https://github.com/matthiasn/talk-transcripts/blob/master/Hickey_Rich/MaybeNot.md)
- Rich Hickey, "Spec-ulation" (Clojure/conj 2016) — [transcript](https://github.com/matthiasn/talk-transcripts/blob/master/Hickey_Rich/Spec_ulation.md), [Hacker News discussion](https://news.ycombinator.com/item?id=13085952)
- [Clojure.spec Rationale and Overview](https://clojure.org/about/spec)
- [Clojure.spec Guide](https://clojure.org/guides/spec)
- [spec-alpha2 Schema and Select wiki](https://github.com/clojure/spec-alpha2/wiki/Schema-and-select)
- [Malli — metosin/malli](https://github.com/metosin/malli)
- [Malli Blog Post](https://www.metosin.fi/blog/malli)
- [Malli Open/Closed Decision — Issue #31](https://github.com/metosin/malli/issues/31)
- [Malli Data Modelling (2024)](https://www.metosin.fi/blog/2024-01-16-malli-data-modelling-for-clojure-developers)
- [Plumatic Schema](https://github.com/plumatic/schema)
- [Specter — nathanmarz/specter](https://github.com/nathanmarz/specter)

### Primary Sources — Other Ecosystems

- [JSON Schema — Object types](https://json-schema.org/understanding-json-schema/reference/object)
- [JSON Schema — Extending Closed Schemas with unevaluatedProperties](https://tour.json-schema.org/content/07-Miscellaneous/01-Extending-Closed-Schemas-with-unevaluatedProperties)
- [Protocol Buffers Language Guide (proto3)](https://protobuf.dev/programming-guides/proto3/)
- [Protocol Buffers Schema Evolution Guide](https://jsontotable.org/blog/protobuf/protobuf-schema-evolution)
- [Ecto.Changeset documentation](https://hexdocs.pm/ecto/Ecto.Changeset.html)
- [Ecto Data mapping and validation](https://hexdocs.pm/ecto/data-mapping-and-validation.html)
- [Zod documentation](https://zod.dev/)
- [Designing the perfect TypeScript schema validation library](https://colinhacks.com/essays/zod)
- [Lean 4 — Structures and Records](https://lean-lang.org/theorem_proving_in_lean4/structures_and_records.html)
- [Lean 4 — Structures and Inheritance](https://leanprover.github.io/functional_programming_in_lean/functor-applicative-monad/inheritance.html)

### Secondary Sources — Analysis and Commentary

- [jml's notebook — Thoughts on "Maybe Not"](https://notes.jml.io/posts/2018-12-03-15:47.html)
- [mplanchard — Thoughts on "Maybe Not"](https://blog.mplanchard.com/posts/thoughts-on-maybe-not.html)
- [ezyang — Thoughts about Spec-ulation](http://blog.ezyang.com/2016/12/thoughts-about-spec-ulation-rich-hickey/)
- [Sean Corfield — SQL NULL, nilable, optionality](https://corfield.org/blog/2018/12/06/null-nilable-optionality/)
- [Schema & Clojure Spec for the Web Developer — Metosin](https://www.metosin.fi/blog/schema-spec-web-devs)
- [Pixelated Noise — What Clojure spec is](https://pixelated-noise.com/blog/2020/09/10/what-spec-is/)
- [Inside Clojure — spec updates](https://insideclojure.org/2019/08/10/journal/)
