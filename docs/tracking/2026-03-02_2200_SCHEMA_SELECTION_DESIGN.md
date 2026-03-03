# Schema + Selection: Design Document

**Status**: Design Draft (Phase 2 of Design Methodology) — Open questions resolved, critique incorporated
**Date**: 2026-03-02
**Tracking**: `docs/tracking/2026-03-02_2200_SCHEMA_SELECTION_DESIGN.md`
**Research**: `docs/research/2026-03-02_SCHEMA_TYPE_DESIGN_RESEARCH.md`, `docs/research/2026-03-02_SCHEMA_AS_PROTOCOL_RESEARCH.md`
**Prior discussion**: `docs/conversations/20260206_dependent_types_2.md` (lines 15440-15888)
**Prerequisite for**: Relational language activation, session type protocols, stdlib schema patterns

---

## Table of Contents

- [1. Motivation and Scope](#1-motivation-and-scope)
- [2. Design Principles and Rejections](#2-design-principles-and-rejections)
  - [2.1 The Hickey Insight: Three Orthogonal Concerns](#21-the-hickey-insight)
  - [2.2 Rejected: Subtyping/Subset Approach](#22-rejected-subtyping)
  - [2.3 Confirmed: Metadata-Style Selection](#23-confirmed-metadata-style)
- [3. Keyword Decisions](#3-keyword-decisions)
  - [3.1 `schema` — Shape Declaration](#31-schema)
  - [3.2 `selection` — Context Requirements](#32-selection)
  - [3.3 `:requires` / `:provides` — Directional Metadata](#33-requires-provides)
  - [3.4 `:includes` — Composition](#34-includes)
  - [3.5 `*` — Sigma Composition Operator](#35-sigma-operator)
- [4. Surface Syntax](#4-surface-syntax)
  - [4.1 Schema Declaration](#41-schema-declaration)
  - [4.2 Selection Declaration — Basic](#42-selection-basic)
  - [4.3 Deep Path Syntax](#43-deep-path-syntax)
  - [4.4 Wildcards: `*` and `**`](#44-wildcards)
  - [4.5 Brace Branching for Deep Nesting](#45-brace-branching)
  - [4.6 Indentation Alternative](#46-indentation-alternative)
  - [4.7 `:provides` Selections](#47-provides-selections)
  - [4.8 `:includes` Composition](#48-includes-composition)
  - [4.9 Bare Selection Names in Type Positions](#49-bare-selection-names)
  - [4.10 Sigma Composition with `*`](#410-sigma-composition)
  - [4.11 Inline Selection Syntax](#411-inline-selection)
  - [4.12 Schema-Level Properties](#412-schema-properties)
- [5. Comprehensive Examples](#5-comprehensive-examples)
  - [5.1 The Movie Times Example (Hickey)](#51-movie-times)
  - [5.2 Request Pipeline (Information Building)](#52-request-pipeline)
  - [5.3 Session Types with Selections](#53-session-types)
  - [5.4 Relations with Schemas](#54-relations)
  - [5.5 Deep Nesting Showcase](#55-deep-nesting)
- [6. Type-Level Encoding](#6-type-level-encoding)
  - [6.1 Schema as Record Type](#61-schema-as-record)
  - [6.2 Selection as Refinement Type](#62-selection-as-refinement)
  - [6.3 `*` as Sigma Type](#63-sigma-type)
  - [6.4 Row Polymorphism for Openness](#64-row-polymorphism)
  - [6.5 Variance and Session Duality](#65-variance)
- [7. Path Algebra](#7-path-algebra)
  - [7.1 Path Grammar](#71-path-grammar)
  - [7.2 Wildcard Semantics](#72-wildcard-semantics)
  - [7.3 Equivalences](#73-equivalences)
  - [7.4 Comparison with Specter](#74-specter-comparison)
- [8. Integration Points](#8-integration-points)
  - [8.1 The Specification Triple](#81-specification-triple)
  - [8.2 Functional: `spec`/`defn`](#82-functional)
  - [8.3 Relational: `schema`/`defr`](#83-relational)
  - [8.4 Process: `session`/`defproc`](#84-process)
  - [8.5 Schema Evolution at Session Boundaries](#85-evolution)
- [9. Resolved Questions](#9-resolved-questions)
  - [9.1 Schema-Level Properties: Confirmed](#91-schema-properties)
  - [9.2 Inline Selection Syntax: Confirmed](#92-inline-syntax)
  - [9.3 Dual `:requires` + `:provides`: Confirmed](#93-dual-direction)
  - [9.4 Linear Schema Fields: Confirmed](#94-linear-fields)
  - [9.5 `*` Operator Disambiguation: Resolved](#95-star-disambiguation)
  - [9.6 Multi-Schema Selections: Deferred](#96-multi-schema)
  - [9.7 Runtime vs Compile-Time Checking: Runtime First](#97-runtime-first)
- [10. Construction and Consumption Semantics](#10-construction-consumption)
  - [10.1 Constructing Values That Satisfy Selections](#101-construction)
  - [10.2 Consuming Selection-Typed Values](#102-consumption)
  - [10.3 Error Messages](#103-error-messages)
- [11. Design Notes from Critique](#11-critique-notes)
  - [11.1 `:requires` Is Syntactic, Not a Keyword Argument](#111-syntactic-keyword)
  - [11.2 Bare `:address` Equivalence — Rationale](#112-bare-address)
  - [11.3 `:includes` Join Precision](#113-includes-join)
  - [11.4 Schema Openness at Construction vs Consumption](#114-openness-sites)
  - [11.5 Relations Have Complete Rows](#115-complete-rows)
  - [11.6 Selections Are Structural, Not Dependent (Phase 0)](#116-structural-not-dependent)
  - [11.7 Deep Nesting as Design Smell](#117-deep-nesting-smell)
- [12. Phased Implementation Sketch](#12-implementation-sketch)
- [13. References](#13-references)

---

<a id="1-motivation-and-scope"></a>

## 1. Motivation and Scope

Prologos has three co-equal paradigms:

| Paradigm | Spec | Named | Anonymous | Delimiter |
|----------|------|-------|-----------|-----------|
| Functional | `spec` | `defn` | `fn` | `[...]` |
| Relational | `schema` | `defr` | `rel` | `(...)` |
| Process | `session` | `defproc` | `proc` | indentation |

**Schema is the lingua franca that all three paradigms speak.** A schema defines the shape of data that flows through function parameters, relation columns, and session channels. But shape alone is insufficient — different contexts need different subsets of a schema's fields. This is the **schema/selection separation** identified by Rich Hickey in "Maybe Not" (2018) and confirmed across the schema landscape.

This document consolidates all research findings and design conversations into a concrete, implementation-oriented design for Prologos's `schema` and `selection` forms.

### What This Document Covers

1. **Schema declaration** — defining what keys CAN exist and their types
2. **Selection declaration** — defining what keys MUST exist in a given context
3. **Deep path syntax** — navigating nested schemas with `.`, `{}`, `*`, `**`
4. **Composition** — combining selections via `:includes` and schemas via `*`
5. **Integration** — how schema/selection interacts with `spec`/`defn`, `defr`, and `session`/`defproc`
6. **Type-level encoding** — the Pi/Sigma/row-polymorphism underpinnings

### What This Document Does NOT Cover

- Schema extension (`:extends`) — deferred to implementation
- Schema evolution / deprecation — future design
- Computed fields / resolvers — future design

### Scope Note: `:closed`, `:default`, `:check`

Schema-level properties (`:closed`, `:default`, `:check`) are **confirmed as part of the design** (see §9 Resolved Questions). Their full syntax and semantics are specified here; detailed implementation mechanics are covered during implementation phases.

---

<a id="2-design-principles-and-rejections"></a>

## 2. Design Principles and Rejections

### 2.1 The Hickey Insight: Three Orthogonal Concerns

<a id="21-the-hickey-insight"></a>

Every schema system in the landscape (spec, Malli, JSON Schema, Protobuf, Ecto, Zod, Lean 4) confronts three orthogonal concerns:

| # | Concern | Question | Control |
|---|---------|----------|---------|
| 1 | **Shape** | What keys CAN exist? What type does each have? | `schema` |
| 2 | **Presence** | Which keys MUST be present in this context? | `selection` |
| 3 | **Openness** | Can the map contain extra keys? | `:closed` on schema |

Systems that conflate these concerns create accidental complexity:
- **Schema proliferation** ("UserForRegistration", "UserForUpdate") — from conflating shape with requirements
- **Maybe/Option wrapping** every optional field — from conflating type with presence
- **Broken composition** (JSON Schema `allOf` + `additionalProperties`) — from conflating openness with local declaration

The design principle: **orthogonal concerns deserve orthogonal syntax**. Shape is `schema`. Presence is `selection`. These are separate forms.

### 2.2 Rejected: Subtyping/Subset Approach (Variation B)

<a id="22-rejected-subtyping"></a>

One approach (Variation B from the research) would make selections into subtypes of their parent schema — `MovieTimesReq <: User` — so that any `User` function could accept a `MovieTimesReq`.

**This is rejected on principle.** Subtyping (`A <: B`) is logically equivalent to implication (`A ⊃ B`), which is logically equivalent to inheritance. The trait hierarchy research (see `docs/tracking/principles/DEVELOPMENT_LESSONS.org`) demonstrated that inheritance hierarchies create brittleness (diamond problem, Liskov violations, fragile base class). Subset ⊆ in set theory is the same relation expressed differently.

> "We should always remind ourselves whenever we see subsets being leaned on/used of this danger."

Instead, selections are **not subtypes** of their schemas. They are **refinement types** — a schema value constrained to have certain keys present. The relationship is `Σ (u : User) (HasKeys u #{...})`, not `MovieTimesReq <: User`. This is composition, not inheritance.

### 2.3 Confirmed: Metadata-Style Selection (Hybrid A+E)

<a id="23-confirmed-metadata-style"></a>

The confirmed design uses metadata-style keywords (`:requires`, `:provides`, `:includes`) on the selection form. This follows the pattern established by `spec` metadata in Prologos — keyword-value pairs that annotate a declaration.

The selection form is:

```prologos
selection Name from Schema
  :requires [field-paths...]
```

This is a hybrid of:
- **Research Approach A** (rich declaration with metadata) — the `:requires` metadata style
- **Research Approach E** (Hickey separation) — schema and selection as separate forms

Without the downsides of either: no metadata namespace collision (`:requires` is clearly not a data key), no verbose per-field `require` declarations.

---

<a id="3-keyword-decisions"></a>

## 3. Keyword Decisions

### 3.1 `schema` — Shape Declaration

<a id="31-schema"></a>

Already established. `schema` defines the universe of possible keys and their types. No `:required`/`:optional` distinction — all keys are possible, none are required at the schema level.

```prologos
schema User
  id         : UserId
  first-name : String
  last-name  : String
  email      : Email
  address    : Address

schema Address
  street : String
  city   : String
  state  : StateCode
  zip    : ZipCode
```

### 3.2 `selection` — Context Requirements

<a id="32-selection"></a>

**Keyword**: `selection` (not `select`, `view`, `project`, or `require`).

**Rationale**: Denotational naming — consistent with `spec` (returns a specification), `session` (returns a session type). `selection` returns a selection. The name describes what the form *produces*, not what it *does*. This follows the referential transparency / declarative naming preference.

```prologos
selection MovieTimesReq from User
  :requires [:id :address.zip]
```

### 3.3 `:requires` / `:provides` — Directional Metadata

<a id="33-requires-provides"></a>

Two directional metadata keys on a selection:

| Key | Direction | Variance | Meaning |
|-----|-----------|----------|---------|
| `:requires` | Input (contravariant) | Caller must provide *at least* these | "What this context needs" |
| `:provides` | Output (covariant) | Service guarantees *at least* these | "What this context guarantees" |

These keywords were freed for selection use by the `require`→`imports`, `provide`→`exports` module keyword rename (commits `6d8b6a0`–`42bd8f5`).

`:requires` is the common case. Most selections describe what a function or protocol endpoint needs from an incoming value. `:provides` is used for output types — what a function or endpoint guarantees about its return value.

### 3.4 `:includes` — Composition

<a id="34-includes"></a>

`:includes` composes selections by set union. No hierarchy, no inheritance — pure additive composition.

```prologos
selection BasicIdentity from User
  :requires [:id :first-name :last-name]

selection ContactInfo from User
  :requires [:email :address.*]

selection FullContact from User
  :includes [BasicIdentity ContactInfo]
  :requires [:address.{*}]
```

`:includes` is order-independent (set union). If two included selections require the same field, the union is idempotent. If they require different subsets of a nested schema, the union takes the *join* (both subsets required).

### 3.5 `*` — Sigma Composition Operator

<a id="35-sigma-operator"></a>

**In type positions**, `*` is the Sigma composition operator:

```prologos
spec get-times : User * MovieTimesReq -> List MovieTime
```

This reads: "a User value that satisfies the MovieTimesReq selection." Under the hood:

```
User * MovieTimesReq ≡ Σ (u : User) (Satisfies u MovieTimesReq)
```

The `*` is NOT multiplication or intersection — it is dependent pairing. A value of type `User * MovieTimesReq` is a User that carries proof (erasable) that the required keys are present.

Note: `*` already exists in Prologos for Sigma types in angle brackets: `<(x : A) * B>`. Using it here is a natural extension — schema composition IS a dependent pair.

---

<a id="4-surface-syntax"></a>

## 4. Surface Syntax

### 4.1 Schema Declaration

<a id="41-schema-declaration"></a>

```prologos
;; Basic schema — all keys possible, open (extra keys OK)
schema Point
  x : Int
  y : Int

;; Nested schema
schema User
  id         : UserId
  first-name : String
  last-name  : String
  email      : Email
  address    : Address

schema Address
  street : String
  city   : String
  state  : StateCode
  zip    : ZipCode
```

Schemas define shape only. No required/optional distinction at the schema level.

### 4.2 Selection Declaration — Basic

<a id="42-selection-basic"></a>

```prologos
;; Need just id and zip code
selection MovieTimesReq from User
  :requires [:id :address.zip]

;; Need name and full address
selection PlaceOrderReq from User
  :requires [:first-name :last-name :address]

;; Note: :address alone means :address.* (the whole Address)
```

The `:requires` value is a vector of **key paths**. Each path names a field (possibly nested) that must be present.

### 4.3 Deep Path Syntax

<a id="43-deep-path-syntax"></a>

Paths use `.` to navigate into nested schemas:

```prologos
:id                 ;; top-level key
:address.zip        ;; nested: address must exist AND zip within it
:address.street     ;; nested: address must exist AND street within it
```

A bare nested schema name (`:address`) is equivalent to requiring all its fields (`:address.*`). This is because if you say "I need the address," the natural reading is "I need the whole address."

### 4.4 Wildcards: `*` and `**`

<a id="44-wildcards"></a>

Two wildcard patterns for selecting multiple fields:

| Wildcard | Meaning | Example |
|----------|---------|---------|
| `*` | All fields at the current level | `:address.*` = all Address fields |
| `**` | All fields recursively (current level and all nested) | `:address.**` = all Address fields and all fields within any nested schemas |

`*` is the common case — "I need everything in this sub-schema." `**` is the deep variant for truly recursive structures.

**Equivalence**: `:address` and `:address.*` are equivalent — both mean "I need the whole address."

### 4.5 Brace Branching for Deep Nesting

<a id="45-brace-branching"></a>

When multiple nested paths share a common prefix, use `{}` to branch:

```prologos
;; Without branching (repetitive)
:requires [:id :address.zip :address.city]

;; With branching (compact)
:requires [:id :address.{zip city}]
```

Braces can nest arbitrarily:

```prologos
;; Deep nesting with brace branching
:requires [:id :foo.{bar baz.{zaz quaz}}]

;; Equivalent to:
:requires [:id :foo.bar :foo.baz.zaz :foo.baz.quaz]
```

**Wildcard inside braces**: `{*}` means "all fields at this level" within a branching context. This is useful when you need all fields AND want to continue a path:

```prologos
;; Select all yaz keys AND continue to taz.waz
:requires [:id :foo.{bar baz.{zaz quaz.yaz.{* taz.waz}}}]

;; The {*} inside yaz means "require all fields of yaz"
;; The taz.waz continues the path into yaz.taz.waz
;; Together: all of yaz's fields PLUS specifically yaz.taz.waz
```

This syntax handles the case where you need "everything at this level" plus additional deeper paths — something that flat path syntax can't express concisely.

### 4.6 Indentation Alternative

<a id="46-indentation-alternative"></a>

For deeply nested selections, an indentation-based alternative improves readability:

```prologos
;; Brace syntax (compact, good for simple nesting)
selection DeepReq from SomeType
  :requires [:id :foo.{bar baz.{zaz quaz.yaz.{taz}}}]

;; Indentation syntax (readable, good for deep nesting)
selection DeepReq from SomeType
  :requires
    :id
    :foo
      :bar
      :baz
        :zaz
        :quaz
          :yaz
            :taz
```

Both forms are semantically equivalent. The indentation form desugars to the vector form at parse time. Use whichever is more readable for the situation.

### 4.7 `:provides` Selections

<a id="47-provides-selections"></a>

`:provides` declares what a context guarantees about its output:

```prologos
;; Service guarantees these fields in the response
selection UserResponse from User
  :provides [:id :first-name :last-name :email :address]

;; Output type in a spec
spec get-user : UserId -> User * UserResponse
```

The `:provides` direction has covariant semantics — the provider can add more fields over time without breaking consumers.

### 4.8 `:includes` Composition

<a id="48-includes-composition"></a>

```prologos
selection BasicIdentity from User
  :requires [:id :first-name :last-name]

selection ContactInfo from User
  :requires [:email :address.*]

;; Compose via set union
selection FullContact from User
  :includes [BasicIdentity ContactInfo]

;; Include + extend with additional requirements
selection FullContactWithZip from User
  :includes [BasicIdentity ContactInfo]
  :requires [:address.zip]
```

`:includes` is pure set union. When both an `:includes` and a `:requires` are present, the result is the union of all included selections plus the additional requires.

### 4.9 Bare Selection Names in Type Positions

<a id="49-bare-selection-names"></a>

Selection names are valid types. When used alone (without `*`), they stand for the refined schema type:

```prologos
;; These are equivalent:
spec get-times : MovieTimesReq -> List MovieTime
spec get-times : User * MovieTimesReq -> List MovieTime

;; The bare name is sugar — it already knows its parent schema
;; because the selection declares `from User`
```

This is an ergonomic win. Most of the time, you just want to say "I need a MovieTimesReq" without repeating that it's a selection on User.

### 4.10 Sigma Composition with `*`

<a id="410-sigma-composition"></a>

When a function needs a value satisfying multiple selections, use `*`:

```prologos
;; Need both identity AND contact info
spec send-package : User * BasicIdentity * ContactInfo -> TrackingId

;; In session types
session OrderService
  ? req : User * PlaceOrderReq
  ! conf : OrderConfirmation
  end
```

`*` is left-associative: `A * B * C` = `(A * B) * C`. All selections must be from the same schema (or compatible schemas via `:extends`).

### 4.11 Inline Selection Syntax

<a id="411-inline-selection"></a>

For one-off selections that don't warrant a name, inline syntax is available in type positions:

```prologos
;; Named selection (primary, for reuse)
selection MovieTimesReq from User
  :requires [:id :address.zip]

spec get-times : MovieTimesReq -> List MovieTime

;; Inline selection (sugar, for one-off use)
spec get-times : User{:id :address.zip} -> List MovieTime
```

Inline syntax is `Schema{paths...}` — the schema name followed by a brace-enclosed path list. This desugars to an anonymous selection. Named selections remain the primary form for anything used more than once.

### 4.12 Schema-Level Properties

<a id="412-schema-properties"></a>

Schemas support metadata properties on the schema itself and on individual fields:

```prologos
;; Schema-level: :closed
schema Config :closed
  host  : String
  port  : Int
  debug : Bool

;; Field-level: :default, :check
schema Employee
  name    : String
  email   : String        :default ""
  salary  : Int           :check [> _ 0]
  badge   : Int           :check [> _ 0]  :default 0
```

**Grammar**: Schema-level properties follow the schema name. Field-level properties follow the field type. This is positional and unambiguous — `key Type [property*]`.

| Property | Level | Meaning |
|----------|-------|---------|
| `:closed` | Schema | No extra keys beyond declared fields |
| `:default val` | Field | Constructor uses `val` when key absent |
| `:check [pred]` | Field | Runtime validation predicate on field value |

`:default` applies at construction time — the constructor fills in the default, so the value always has the key. `:check` is a runtime assertion in Phase 0, upgradable to compile-time proof obligation later.

---

<a id="5-comprehensive-examples"></a>

## 5. Comprehensive Examples

### 5.1 The Movie Times Example (Hickey)

<a id="51-movie-times"></a>

The canonical example from Hickey's "Maybe Not" talk, in Prologos:

```prologos
;; ── Layer 1: Schema (shape only) ────────────

schema Address
  street : String
  city   : String
  state  : StateCode
  zip    : ZipCode

schema User
  id         : UserId
  first-name : String
  last-name  : String
  address    : Address

;; ── Layer 2: Selections (context requirements) ────────────

;; For getting movie times: need id and zip only
selection MovieTimesReq from User
  :requires [:id :address.zip]

;; For placing an order: need name and full address
selection PlaceOrderReq from User
  :requires [:first-name :last-name :address]

;; For user response: guarantee everything
selection UserResponse from User
  :provides [:id :first-name :last-name :address]

;; ── Layer 3: Functions (consume selections) ────────────

spec get-times : MovieTimesReq -> List MovieTime
defn get-times [user]
  lookup-times user.id user.address.zip
  ;; Type-safe: .id and .address.zip guaranteed present
  ;; Cannot access user.first-name (not in selection)

spec place-order : PlaceOrderReq -> OrderConfirmation
defn place-order [user]
  create-order user.first-name user.last-name user.address
  ;; Type-safe: .first-name, .last-name, .address.* guaranteed

;; ── Layer 4: Session protocol ────────────

session MovieService
  ? req : MovieTimesReq
  ! times : List MovieTime
  end

defproc movie-server : MovieService
  recv self req
    let times := [get-times req]
    send times self
      stop
```

### 5.2 Request Pipeline (Information Building)

<a id="52-request-pipeline"></a>

Hickey's "pipeline of information building" pattern — each stage adds fields:

```prologos
schema Request
  id          : RequestId
  timestamp   : Time
  raw-body    : Bytes
  auth-token  : AuthToken
  user        : User
  rate-limit  : RateLimit
  parsed-body : ParsedBody
  validated   : ValidationResult

;; Each stage requires input and provides output
selection AuthInput from Request
  :requires [:id :auth-token]

selection AuthOutput from Request
  :provides [:id :auth-token :user]

selection RateLimitInput from Request
  :requires [:id :user]

selection RateLimitOutput from Request
  :provides [:id :user :rate-limit]

selection ParseInput from Request
  :requires [:raw-body]

selection ParseOutput from Request
  :provides [:raw-body :parsed-body]

;; Pipeline stages
spec authenticate    : AuthInput -> AuthOutput
spec check-rate-limit : RateLimitInput -> RateLimitOutput
spec parse-body      : ParseInput -> ParseOutput
```

### 5.3 Session Types with Selections

<a id="53-session-types"></a>

```prologos
;; Schema crossing a session boundary
session EmployeeService
  ? query : EmployeeQuery              ;; client sends query (input)
  ! response : Employee * FullEmployee ;; server sends full employee (output)
  end

;; Evolution safety:
;; - Adding a field to Employee (response) is SAFE
;;   (client ignores what it doesn't select)
;; - Adding a required field to EmployeeQuery is BREAKING
;;   (existing clients don't provide it)
;; - Adding an optional field to EmployeeQuery is SAFE
;;   (existing clients work, new clients can use it)

;; Subscription-style session with selections
session EmployeeWatch
  ? filter : EmployeeFilter
  rec Loop
    +>
      | :update
          ! emp : Employee * FullEmployee
          Loop
      | :done
          end
```

### 5.4 Relations with Schemas

<a id="54-relations"></a>

```prologos
;; Schema-typed relation
schema ParentChild
  parent : String
  child  : String

defr parent-child : ParentChild
  || "Alice" "Bob"
     "Bob"   "Carol"
     "Bob"   "Dave"

;; Query with selection (future: selection as constraint)
;; "Find all parents" — project onto :parent field
selection ParentOnly from ParentChild
  :requires [:parent]
```

### 5.5 Deep Nesting Showcase

<a id="55-deep-nesting"></a>

```prologos
schema Company
  id    : CompanyId
  name  : String
  ceo   : Employee
  depts : Map DeptId Department

schema Department
  id       : DeptId
  name     : String
  head     : Employee
  budget   : Budget
  projects : List Project

schema Project
  id       : ProjectId
  name     : String
  lead     : Employee
  timeline : Timeline

schema Timeline
  start    : Date
  end      : Date
  milestones : List Milestone

schema Employee
  id    : EmployeeId
  name  : String
  email : Email
  role  : Role

;; ── Flat path syntax ────────────

selection ProjectReport from Company
  :requires [:name :depts.*.projects.{name lead.name timeline.{start end}}]

;; ── Brace branching syntax ────────────

selection BudgetOverview from Company
  :requires [:id :name :depts.*.{name budget head.name}]

;; ── Indentation syntax (equivalent) ────────────

selection BudgetOverview from Company
  :requires
    :id
    :name
    :depts.*
      :name
      :budget
      :head
        :name

;; ── Wildcard with continuation ────────────

;; "I need all of timeline PLUS drill into milestones"
selection FullProjectView from Company
  :requires [:name :depts.*.projects.{name lead timeline.{* milestones.**}}]
```

---

<a id="6-type-level-encoding"></a>

## 6. Type-Level Encoding

### 6.1 Schema as Record Type

<a id="61-schema-as-record"></a>

A `schema` declaration elaborates to a named record type (Map with field constraints):

```
schema User            ⟶  User : Type 0
  id : UserId               User ≡ { :id UserId, :first-name String, ... | r }
  first-name : String
  ...
```

The schema produces:
- A **type** (`User : Type 0`)
- A **constructor** (positional and/or dictionary-style)
- **Field accessors** (`.id`, `.first-name`, etc. via dot-access)

By default, schemas are **open** — the row variable `r` allows extra keys.

### 6.2 Selection as Refinement Type

<a id="62-selection-as-refinement"></a>

A `selection` declaration elaborates to a refinement type:

```
selection MovieTimesReq from User     ⟶  MovieTimesReq : Type 0
  :requires [:id :address.zip]             MovieTimesReq ≡ Σ (u : User) (HasKeys u #{:id, :address.zip})
```

Where `HasKeys` is a type-level predicate that asserts the specified key paths are present. The refinement is:
- **Erasable at runtime** — the proof is checked at construction time, then erased (no runtime cost)
- **Informative at compile time** — the type checker uses it to allow/disallow field access

### 6.3 `*` as Sigma Type

<a id="63-sigma-type"></a>

The `*` composition operator is a Sigma (dependent pair):

```
User * MovieTimesReq  ≡  Σ (u : User) (Satisfies u MovieTimesReq)
```

When multiple selections are composed:

```
User * A * B  ≡  Σ (u : User) (Satisfies u A × Satisfies u B)
```

Since a bare selection name already encodes its parent schema (via `from`), the bare form is sugar:

```
MovieTimesReq  ≡  User * MovieTimesReq   (when MovieTimesReq is `from User`)
```

### 6.4 Row Polymorphism for Openness

<a id="64-row-polymorphism"></a>

Open and closed schemas are distinguished by the presence of a row variable:

```
;; Open schema (default) — has row variable
User : { :id UserId, :name String, ... | r }

;; Closed schema — no row variable (`:closed` keyword)
Config : { :host String, :port Int }
```

Row polymorphism provides:
- **Open schemas** = record types with row variable (extra keys allowed)
- **Closed schemas** = record types without row variable (exact keys only)
- **Schema extension** = row concatenation
- **Selection** = row restriction (keeps the row variable, narrows the "required" subset)

### 6.5 Variance and Session Duality

<a id="65-variance"></a>

When a schema crosses a session boundary, the direction determines variance:

| Position | Direction | Variance | Safe Evolution |
|----------|-----------|----------|----------------|
| `? req : S` (receive) | Input | **Contravariant** | Can relax requirements (fewer required fields) |
| `! resp : S` (send) | Output | **Covariant** | Can strengthen provisions (more provided fields) |

This maps to `:requires` (contravariant — the caller provides at least this) and `:provides` (covariant — the service guarantees at least this).

The duality:
- **`:requires`**: Requirements can only *shrink* over time (removing a requirement is compatible)
- **`:provides`**: Provisions can only *grow* over time (adding a provision is compatible)

This is exactly GraphQL's input/output type asymmetry expressed through Prologos's type system.

---

<a id="7-path-algebra"></a>

## 7. Path Algebra

### 7.1 Path Grammar

```ebnf
field-path     = ':' , identifier , { '.' , path-segment } ;
path-segment   = identifier
               | '*'                   (* all fields at this level *)
               | '**'                  (* all fields recursively *)
               | '{' , path-list , '}' (* branch *)
               ;
path-list      = field-path , { ' ' , field-path } ;
```

Examples:

```
:id                              ;; simple field
:address.zip                     ;; nested field
:address.*                       ;; all Address fields
:address.**                      ;; all Address fields, recursively
:address.{zip city}              ;; branch: zip AND city
:foo.{bar baz.{zaz quaz}}       ;; nested branching
:foo.yaz.{* taz.waz}            ;; all yaz fields + specific deeper path
```

### 7.2 Wildcard Semantics

**`*` (star)**: Select all fields at the current schema level. Does not descend into nested schemas.

```prologos
schema Address
  street : String
  city   : String
  state  : StateCode
  zip    : ZipCode

;; :address.* expands to:
;; :address.street, :address.city, :address.state, :address.zip
```

**`**` (globstar)**: Select all fields at the current level AND recursively select all fields within any nested schemas.

```prologos
schema User
  id      : UserId
  name    : String
  address : Address

;; :user.** expands to:
;; :id, :name, :address, :address.street, :address.city, :address.state, :address.zip
```

### 7.3 Equivalences

| Expression | Equivalent To | Reason |
|------------|---------------|--------|
| `:address` | `:address.*` | Bare nested schema name = "the whole thing" |
| `:address.*` | `:address.{street city state zip}` | Star expands to all fields |
| `{* foo.bar}` | All fields at level + specifically `foo.bar` at deeper level | Star + path continuation |

### 7.4 Comparison with Specter

Specter (Clojure) provides similar navigation primitives for data transformation. The mapping:

| Prologos Path | Specter Equivalent | Meaning |
|---------------|-------------------|---------|
| `:address.zip` | `(select [:address :zip] data)` | Navigate nested key |
| `:address.*` | `(select [:address ALL] data)` | All values at level |
| `:address.{zip city}` | `(select [:address (multi-path :zip :city)] data)` | Branch |
| `:**` | `(select [(recursive-path [] p (stay-then-continue p))] data)` | Recursive descent |

Key difference: Specter operates on **data** (runtime navigation/transformation). Prologos paths operate on **types** (compile-time validation). The path algebra is the same; the interpretation differs.

---

<a id="8-integration-points"></a>

## 8. Integration Points

### 8.1 The Specification Triple

<a id="81-specification-triple"></a>

Schema + Selection completes the specification layer:

| Paradigm | Specification | Definition | Schema Role |
|----------|--------------|------------|-------------|
| Functional | `spec` | `defn` | Function parameter/return types |
| Relational | `schema` | `defr` | Relation column types |
| Process | `session` | `defproc` | Message shapes on channels |
| Cross-cutting | `selection` | — | Context-specific field requirements |

### 8.2 Functional: `spec`/`defn`

<a id="82-functional"></a>

```prologos
;; Bare selection name as parameter type
spec get-times : MovieTimesReq -> List MovieTime
defn get-times [user]
  lookup-times user.id user.address.zip

;; Explicit Sigma composition
spec process-order : User * PlaceOrderReq -> OrderResult
defn process-order [user]
  validate-address user.address
  create-order user.first-name user.last-name

;; Selection in return type (provides)
spec enrich-user : UserId -> User * UserResponse
defn enrich-user [uid]
  let base := [lookup-user uid]
  ;; Type checker verifies all :provides fields are present in result
  base
```

### 8.3 Relational: `schema`/`defr`

<a id="83-relational"></a>

```prologos
;; Schema defines the column types for a relation
schema Employee
  id     : EmployeeId
  name   : String
  dept   : Department
  salary : Int

defr employee : Employee
  || 1 "Alice" Engineering 95000
     2 "Bob"   Marketing   72000
     3 "Carol" Engineering 88000

;; Relations always have all fields (complete rows)
;; Selections can project specific columns in queries (future)
```

### 8.4 Process: `session`/`defproc`

<a id="84-process"></a>

```prologos
session UserService
  ? req : MovieTimesReq                ;; bare selection = refined User
  ! times : List MovieTime
  end

defproc user-service : UserService
  recv self req
    let times := [get-times req]
    send times self
      stop

;; Multiple selections on same channel
session OrderWorkflow
  ? user : User * PlaceOrderReq        ;; Sigma: User with order fields
  ! quote : Quote
  &>
    | :accept
        ? payment : PaymentInfo
        ! confirmation : OrderConfirmation
        end
    | :reject
        end
```

### 8.5 Schema Evolution at Session Boundaries

<a id="85-evolution"></a>

Open schemas enable safe protocol evolution:

```prologos
;; v1: Employee schema
schema Employee
  id   : EmployeeId
  name : String
  dept : Department

;; v2: Added email field
schema Employee
  id    : EmployeeId
  name  : String
  dept  : Department
  email : Email           ;; NEW — additive change

;; Selection still works — only requires what it needs
selection BasicEmployee from Employee
  :requires [:id :name]

;; v1 clients that send BasicEmployee still work
;; v2 clients can now also require :email in new selections
```

This follows Proto3's lesson and GraphQL's evolution strategy: additive changes only, never breaking removal.

---

<a id="9-resolved-questions"></a>

## 9. Resolved Questions

All open questions from the initial draft have been resolved through design discussion.

<a id="91-schema-properties"></a>

### 9.1 Schema-Level Properties: CONFIRMED

Schemas support metadata properties: `:closed`, `:default`, `:check`.

```prologos
;; Closed schema — no extra keys allowed
schema Config :closed
  host : String
  port : Int

;; Default values and value constraints
schema Employee
  name    : String
  email   : String  :default ""
  salary  : Int     :check [> _ 0]
```

These are progressive disclosure layers: bare `schema` for simple cases, add `:closed`/`:default`/`:check` when needed.

<a id="92-inline-syntax"></a>

### 9.2 Inline Selection Syntax: CONFIRMED

Both named and inline selection syntax are supported:

```prologos
;; Named (primary form)
selection MovieTimesReq from User
  :requires [:id :address.zip]

spec get-times : MovieTimesReq -> List MovieTime

;; Inline (sugar for one-off uses)
spec get-times : User{:id :address.zip} -> List MovieTime
```

Named selections are the primary form for reuse. Inline syntax is sugar for cases where a selection is used exactly once and naming it would add ceremony without value.

<a id="93-dual-direction"></a>

### 9.3 Dual `:requires` + `:provides`: CONFIRMED

A single selection can have both `:requires` and `:provides`, describing a transformer stage:

```prologos
selection EnrichmentStage from Request
  :requires [:id :auth-token]
  :provides [:id :auth-token :user]
```

The `:requires` is the precondition (what must be present in the input). The `:provides` is the postcondition (what is guaranteed in the output). Together they form a dependent function type — the pipeline stage transforms a request with certain fields into a request with (potentially more) fields.

<a id="94-linear-fields"></a>

### 9.4 Linear Schema Fields: CONFIRMED

Schema fields can carry QTT multiplicity annotations:

```prologos
schema Connection
  socket : :1 Socket      ;; linear: must use exactly once
  config : Config          ;; unrestricted (default :w)
```

Default multiplicity is `:w` (unrestricted). Linear fields (`:1`) are expressible for resource-typed schemas (e.g., database connections, file handles). This integrates with Prologos's existing QTT infrastructure.

<a id="95-star-disambiguation"></a>

### 9.5 `*` Operator Disambiguation: RESOLVED

No ambiguity. `*` in type positions is always Sigma composition (binary operator between types). `*` in path positions (after `.` inside `:requires` vectors) is always the wildcard. Different syntactic contexts, never confused.

```prologos
;; Type position: Sigma composition
spec get-times : User * MovieTimesReq -> List MovieTime

;; Path position: wildcard
:requires [:address.*]
```

The overloading is well-precedented — `*` means different things in regex vs arithmetic, in glob patterns vs multiplication. Context makes it unambiguous.

<a id="96-multi-schema"></a>

### 9.6 Multi-Schema Selections: DEFERRED

Deferred. Needs design thought, particularly around key collision when fields from different schemas share names. Single-schema selections are the initial design. Multi-schema selections may be added when relational joins create the need.

<a id="97-runtime-first"></a>

### 9.7 Runtime vs Compile-Time Checking: RUNTIME FIRST

`:check` predicates start as runtime assertions. The proof-checking infrastructure (propagator network, static analysis) is not yet built. Following the "Properties are Types in Waiting" principle, runtime checks can be upgraded to compile-time proof obligations as the infrastructure matures.

---

<a id="10-construction-consumption"></a>

## 10. Construction and Consumption Semantics

This section addresses how values satisfying selections are *created* and *used* — a gap identified in critique review.

<a id="101-construction"></a>

### 10.1 Constructing Values That Satisfy Selections

Values are constructed as normal schema values. The type checker verifies that the selection's requirements are met. No special construction syntax is needed.

```prologos
selection MovieTimesReq from User
  :requires [:id :address.zip]

spec make-req : UserId -> ZipCode -> MovieTimesReq
defn make-req [uid zip]
  ;; Construct a User value (schema constructor)
  ;; Type checker verifies :id and :address.zip are present
  User
    :id uid
    :address (Address :zip zip)
```

The key insight: **selection refinement is checked at the point where a schema value is used as a selection type**, not at construction. A `User` value is always a `User` — it becomes a `MovieTimesReq` when it flows into a position that expects `MovieTimesReq`, and the type checker verifies the required keys are present.

This is the same pattern as other refinement types in Prologos — the value is the underlying type, the refinement is checked at usage sites.

```prologos
;; Explicit coercion (optional, for clarity)
let user := User {:id 42, :address {:zip "90210"}}
let req : MovieTimesReq := user   ;; type checker verifies refinement here
```

<a id="102-consumption"></a>

### 10.2 Consuming Selection-Typed Values

When a function receives a selection-typed parameter, only the selected fields are accessible:

```prologos
spec get-times : MovieTimesReq -> List MovieTime
defn get-times [user]
  user.id           ;; OK — :id is in selection
  user.address.zip  ;; OK — :address.zip is in selection
  user.first-name   ;; TYPE ERROR — :first-name not in selection
```

The type checker uses the selection's field set to gate dot-access. This is the refinement working in reverse — the type narrows what's available.

<a id="103-error-messages"></a>

### 10.3 Error Messages

When a selection violation occurs, the error message should be precise:

```
Error E2001: Field 'first-name' is not available in selection 'MovieTimesReq'

  defn get-times [user]
    user.first-name
         ^^^^^^^^^^

  MovieTimesReq (from User) requires:
    :id
    :address.zip

  'first-name' exists in schema User but is not selected.
  To access it, add :first-name to the selection's :requires,
  or use a different selection.
```

When a value doesn't satisfy a selection:

```
Error E2002: Value does not satisfy selection 'MovieTimesReq'

  let req : MovieTimesReq := user
                              ^^^^

  MovieTimesReq requires:
    :id          — present ✓
    :address.zip — MISSING ✗

  The User value is missing the :address field (or :address.zip within it).
```

---

<a id="11-critique-notes"></a>

## 11. Design Notes from Critique

These notes address specific concerns raised during independent design review.

<a id="111-syntactic-keyword"></a>

### 11.1 `:requires` Is Syntactic, Not a Keyword Argument

**Concern**: Does `:requires [...]` depend on a general keyword-argument infrastructure that doesn't exist yet?

**Resolution**: No. `:requires`, `:provides`, and `:includes` are **syntactic keywords of the `selection` form**, parsed by the `selection` parser rule. They are not general keyword arguments in the Clojure sense. This follows the existing pattern:

- `ns foo :no-prelude` — `:no-prelude` is a syntactic keyword of `ns`, not a general keyword
- `spec f : A -> B` — the `:` is syntactic, not a general operator
- `schema Employee :closed` — `:closed` is a syntactic property of `schema`

The parser knows: `selection Name from Schema [:requires [paths]] [:provides [paths]] [:includes [sels]]`. These are positional/named sub-forms, not data-layer keywords.

<a id="112-bare-address"></a>

### 11.2 Bare `:address` Equivalence — Rationale

**Concern**: `:address` meaning `:address.*` (all fields) loses the ability to express "address exists but contents unspecified."

**Resolution**: This was an explicit design decision. The reasoning:

1. **Common case wins**: When you say "I need the address," you mean the whole address 95% of the time. Requiring `.*` for the common case penalizes the majority.

2. **"Exists but contents unspecified" is rare in typed systems**: In a dependently-typed language, saying "I need address but don't care what's in it" is unusual. If you have the address, you have its fields (they're part of the type). The unspecified-contents case is more relevant in dynamic systems.

3. **If needed later**: A `:address?` or `:address.?` syntax could express "presence without content requirements." This is a future extension, not a Phase 0 need.

The equivalence `:address` ≡ `:address.*` stands as designed.

<a id="113-includes-join"></a>

### 11.3 `:includes` Join Precision

**Concern**: What happens when included selections have overlapping paths at different depths?

**Resolution**: `:includes` takes the **join (union)** of field sets, meaning **the most demanding requirement wins** at each path:

```prologos
selection A from User
  :requires [:address.zip]       ;; needs just zip

selection B from User
  :requires [:address.*]         ;; needs all address fields

selection C from User
  :includes [A B]
;; Result: :requires [:address.*]
;; Because address.* ⊇ address.zip, the join is address.*
```

The rule: for any path prefix, if one selection requires `prefix.*` and another requires `prefix.field`, the join is `prefix.*` (the more demanding requirement). This is set union on the expanded field sets — it can never produce a *weaker* requirement than either input.

<a id="114-openness-sites"></a>

### 11.4 Schema Openness at Construction vs Consumption

**Concern**: Open-by-default means `User {:id 1, :naem "Alice"}` (typo) is silently accepted.

**Observation**: The GraphQL model (creation-site closed, consumption-site open) is worth noting. In practice:

- **Schema constructor** validates field names against the declared fields (typos caught)
- **Functions receiving schema values** are open to extra fields (allows schema evolution)

This is a reasonable refinement that can be decided during implementation. The core design (schemas open by default via row variable) is correct; whether the *constructor* is strict is an implementation-level decision that doesn't affect the type-level encoding.

**Current stance**: Note as an implementation consideration. The constructor should likely validate field names against the schema (catching typos) while the type system remains open to extra fields at consumption sites.

<a id="115-complete-rows"></a>

### 11.5 Relations Have Complete Rows

**Concern**: How do selections interact with relations?

**Clarification**: Relations (`defr`) always contain **complete rows** — every field of the schema is present in every tuple. This is fundamental to the relational model (a tuple is a function from attributes to values; every attribute must have a value).

```prologos
schema Employee
  id     : EmployeeId
  name   : String
  dept   : Department
  salary : Int

defr employee : Employee
  || 1 "Alice" Engineering 95000   ;; complete row: all 4 fields
     2 "Bob"   Marketing   72000   ;; complete row: all 4 fields
```

Selections are for **function parameters and session messages** — contexts where you want to say "I only need a subset." Relations are the *source of truth* with all fields; functions and protocols are the *consumers* that may only need a projection.

Selection-as-query-projection (e.g., "give me only the name column") is a **future extension** for the relational query language, not part of the core schema/selection design.

<a id="116-structural-not-dependent"></a>

### 11.6 Selections Are Structural, Not Dependent (Phase 0)

**Concern**: Can selections depend on values (e.g., "a Vec with exactly n elements")?

**Clarification**: In Phase 0, selections are **purely structural** — they express field presence requirements only. A selection says "these keys must exist" and the type checker verifies this structurally.

Dependent selections (where the *values* of fields are constrained, not just their presence) are a future extension. The `:check` predicate on schema fields provides runtime value validation, but it does not create a type-level dependency between fields.

```prologos
;; Phase 0: structural (field presence only)
selection MovieTimesReq from User
  :requires [:id :address.zip]

;; Future: dependent (field values constrained)
;; selection SizedVec (n : Nat) from Vec
;;   :requires [:length]
;;   :check [= length n]
```

The Sigma encoding (`Σ (u : User) (HasKeys u #{...})`) supports upgrading to dependent selections later — `HasKeys` can be replaced with a richer predicate. But Phase 0 keeps it simple.

<a id="117-deep-nesting-smell"></a>

### 11.7 Deep Nesting as Design Smell

**Note from critique**: Extremely deep selection paths like `:foo.{bar baz.{zaz quaz.yaz.{* taz.waz}}}` may indicate a need to refactor into smaller schemas or intermediate selections.

This is sound advice. The path algebra *supports* arbitrary depth, but deeply nested selections suggest:

1. **Schema refactoring opportunity**: Extract nested sub-schemas into named schemas
2. **Intermediate selection opportunity**: Compose from smaller, named selections via `:includes`
3. **Possible API design issue**: If consumers need to reach 5 levels deep, the data model may need flattening

The syntax handles depth; good design practice limits it. The indentation alternative (§4.6) helps readability when depth is genuinely needed.

---

<a id="12-implementation-sketch"></a>

## 12. Phased Implementation Sketch

### Phase 1: Schema Foundation

- Upgrade `schema` from deftype stub to genuine record type
- Schema produces: type, constructor, field accessors
- Schema values support dot-access
- Open by default (row variable)
- **Tests**: Schema declaration, construction, field access, type checking

### Phase 2: Selection Foundation

- `selection Name from Schema :requires [paths...]` syntax
- Parse key paths (`.` navigation)
- Selection elaborates to refinement type (Sigma)
- Bare selection names valid in type positions
- Type checker validates field access against selection requirements
- **Tests**: Selection declaration, refinement type checking, bare names

### Phase 3: Sigma Composition

- `*` operator in type positions for `Schema * Selection`
- Multiple selections: `Schema * A * B`
- Integration with `spec`/`defn`
- **Tests**: Sigma composition, multi-selection, function specs

### Phase 4: Deep Paths and Wildcards

- Brace branching syntax (`{zip city}`)
- `*` wildcard in path positions
- `**` recursive wildcard
- Indentation alternative parsing
- **Tests**: Deep nesting, wildcards, branching, equivalences

### Phase 5: Composition and Direction

- `:includes` for set-union composition
- `:provides` direction
- Variance checking at session boundaries
- **Tests**: Composition, provides, evolution safety

### Phase 6: Session Integration

- Selections in session type syntax (`? req : MovieTimesReq`)
- Sigma composition in session types (`? req : User * Req`)
- Duality checking with selections
- **Tests**: Session types with selections, process typing

### Phase 7: Relational Integration

- Schema-typed relations (`defr emp : Employee`)
- Selection as query projection (future)
- **Tests**: Schema-relation interaction

---

<a id="13-references"></a>

## 13. References

### Research Documents

- [Schema Type Design Research](../research/2026-03-02_SCHEMA_TYPE_DESIGN_RESEARCH.md) — 10-system landscape survey, three orthogonal concerns, approach comparison
- [Schema as Protocol Research](../research/2026-03-02_SCHEMA_AS_PROTOCOL_RESEARCH.md) — GraphQL comparison, session type mapping, row polymorphism, CUE
- [Prior conversation](../conversations/20260206_dependent_types_2.md) (lines 15440-15888) — Original schema+selection syntax exploration (Options A-D)

### Prologos Internal

- `docs/tracking/principles/RELATIONAL_LANGUAGE_VISION.org` — Schema as "The Object Language"
- `docs/tracking/principles/DESIGN_PRINCIPLES.org` — Decomplection, progressive disclosure
- `docs/tracking/principles/DEVELOPMENT_LESSONS.org` — Trait hierarchy / inheritance dangers

### External Sources

- Rich Hickey, "Maybe Not" (Clojure/conj 2018) — Schema/select separation
- Rich Hickey, "Spec-ulation" (Clojure/conj 2016) — Accretion over breakage
- [spec-alpha2 Schema and Select wiki](https://github.com/clojure/spec-alpha2/wiki/Schema-and-select)
- [GraphQL Schema and Types](https://graphql.org/learn/schema/)
- [Specter — nathanmarz/specter](https://github.com/nathanmarz/specter) — Path navigation
- Morris & McKinna, "Rows by Any Other Name" (2019) — Row polymorphism generalization
- [CUE Language](https://cuelang.org/) — Types as constraints
